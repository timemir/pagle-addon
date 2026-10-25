#!/usr/bin/env python3
"""Coin economy research, ticket #402 (map #393): calibrate payout constants and prices to the locked pacing table.

Builds on #396's combine model (research/coin-unlock-timeline): one cumulative Pagle Coins curve per player =
    the one-time / Ledger model (#394, Lua, the repo's own fold)        priced here from its COUNTS,
  + the repeatable board / Hunt Event model (#395, python, with #401 rarity goals and #398 refresh tickets)  priced from
    its COUNTS (and re-run whenever the player's behaviour can change: supply, tickets, pay),
  + the Campfire milestones,
then the shop's price list (tiers 1-6, the Curio crate) with a cheapest-first buy order gives the milestone hours.

Why counts: no coin constant changes the XP path, so a level-up, a Species, a Zone Mastery rank or a Prestige is the same
event whatever it pays; only its price moves. The same holds for a Notice, an Expedition or an Event tier unless the
planner's choice of zone changes with the relative pay (the finals are re-run with the real pays, `exact`).

    python -I docs/research/coin-calibration/calibrate.py                 # validation against #396 + candidate tables

Files: inputs/lua_base, inputs/lua_act (the Lua counts, 180 Catches/h), inputs/goods.csv, results/rep/*.json (the
repeatable runs, cached by the constants that change behaviour), tables/*.md|csv.
"""
from __future__ import annotations

import bisect
import csv
import hashlib
import itertools
import json
import math
import os
import sys
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass, field, replace
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rep_driver  # noqa: E402

INP = HERE / "inputs"
RES = HERE / "results"
(RES / "rep").mkdir(parents=True, exist_ok=True)

# ------------------------------------------------------------------------------------------------------------------
# constants (the OLD values are what is on origin/main 72f82efc; file:line in the deliverable table)
# ------------------------------------------------------------------------------------------------------------------
OLD_UNITS = dict(species=10, curio=5, trophy=5, zone=2, legend=100)  # to turn #394's coins back into counts
STANDING_POT_OLD = 1000  # 12 Hunts x 30 + 16 further tiers x 15 + 4 sets x 100 (data/hunts/hunts.toml)
HUNT_MIX = (12, 16, 4)  # completed, further tiers, set titles
ACT_XP0 = {"casual": 877.04, "dedicated": 1044.97, "minmax15": 943.98, "minmax4": 1055.94}  # XP/day fed to lua_act
LUA_PROFILE = {"casual": "casual", "dedicated": "dedicated", "minmax15": "minmax_1.5h", "minmax4": "minmax_4h"}


@dataclass(frozen=True)
class K:
    """One full constants set."""

    name: str = "old"
    # Ledger
    level_up: int = 20
    prestige: int = 100
    species: int = 10
    curio: int = 5
    trophy: int = 5
    zone_rank: int = 2
    legend: int = 100
    # Hunts
    standing: tuple = (30, 15, 100)  # COINS_COMPLETED, COINS_TIER, COINS_TITLE
    event: tuple = (15, 10, 50)  # COINS_EVENT[1], COINS_EVENT[2], COINS_RUN
    # Tackle Board
    notice: tuple = (10, 15, 20)
    expedition: int = 60
    campfire: tuple = ((7, 25), (30, 75), (100, 200), (365, 500))
    notices_per_day: int = 3
    expeditions_per_week: int = 1
    # refresh tickets (#398)
    tickets_run: int = 0
    tickets_t3: int = 0
    tickets_max: int = 5
    ticket_hold: int = 5
    ticket_pref: str = "expedition"
    rarity: bool = True  # #401
    # shop
    prices: tuple = (150, 400, 900, 2000, 5000)  # tiers 1-5
    tier6_price: int = 0
    tier6_goods: int = 0
    tier6_carve: bool = False  # True: the tier-6 goods are the direct tier-5 goods re-tiered, False: added to the 101
    crate: int = 0  # 0 = tier 4's price (CRATE_TIER = 4)
    exact: bool = False  # re-run the repeatable model with these pays (planner can change)
    catches: int = 180

    @property
    def crate_price(self) -> int:
        return self.crate or self.prices[3]

    def rep_kwargs(self) -> dict:
        kw = dict(RARITY=self.rarity, NOTICES_PER_RESET=self.notices_per_day, EXPEDITIONS_PER_WEEK=self.expeditions_per_week,
                  TICKETS_PER_RUN=self.tickets_run, TICKETS_PER_TIER3_HUNT=self.tickets_t3, TICKETS_RUN_MAX=self.tickets_max,
                  TICKET_HOLD=self.ticket_hold)
        if self.ticket_pref != "expedition":
            kw["TICKET_PREF"] = self.ticket_pref
        if self.exact:
            kw.update(NOTICE_PAY=tuple(self.notice), EXPEDITION_PAY=self.expedition, EVENT_TIER1_PAY=self.event[0],
                      EVENT_TIER_PAY=self.event[1], EVENT_RUN_PAY=self.event[2],
                      STOP_VALUE_SCALE=sum(self.notice) / 45.0)
        return kw


# ------------------------------------------------------------------------------------------------------------------
# inputs
# ------------------------------------------------------------------------------------------------------------------
def read_lua(path: Path) -> dict:
    by: dict[str, list] = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            by.setdefault(r["profile"], []).append(r)
    out = {}
    for prof, rows in by.items():
        hs = [0.0] + [float(r["hours"]) for r in rows]
        col = lambda k: [0.0] + [float(r[k]) for r in rows]  # noqa: E731
        out[prof] = {
            "hs": hs,
            "levels": col("levels_total"),
            "prestiges": col("prestiges_n"),
            "species": [v / OLD_UNITS["species"] for v in col("species")],
            "curio": [v / OLD_UNITS["curio"] for v in col("curio")],
            "trophy": [v / OLD_UNITS["trophy"] for v in col("trophy")],
            "zone": [v / OLD_UNITS["zone"] for v in col("zone")],  # rank-units: coins = zone_rank x units
            "legend": [v / OLD_UNITS["legend"] for v in col("legend")],
            "hunts": col("hunts"),  # coins at the OLD standing-hunt pay
        }
    return out


def interp(xs, ys, x):
    if x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        if len(xs) < 2:
            return ys[-1]
        slope = (ys[-1] - ys[-2]) / (xs[-1] - xs[-2])
        return ys[-1] + slope * (x - xs[-1])
    i = bisect.bisect_right(xs, x)
    x0, x1, y0, y1 = xs[i - 1], xs[i], ys[i - 1], ys[i]
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


# ------------------------------------------------------------------------------------------------------------------
# the repeatable model: run (cached) and price
# ------------------------------------------------------------------------------------------------------------------
def _sig(kw: dict, seeds: int, days: int, catches: int) -> str:
    blob = json.dumps([sorted(kw.items()), seeds, days, catches], default=str)
    return hashlib.sha1(blob.encode()).hexdigest()[:12]


def _run_player(args):
    kw, key, seeds, days, sweep_seeds, catches = args
    import repeatable as R

    R.CATCHES_PER_HOUR = catches
    R.MIN_PER_CATCH = 60.0 / catches
    res = rep_driver.run_config(kw, seeds=seeds, days=days, sweep_seeds=sweep_seeds, players=[key])
    return key, res["players"][key], res["constants"]


def rep_run(k: K, seeds: int = 24, days: int = 240, sweep_seeds: int = 10) -> dict:
    kw = k.rep_kwargs()
    sig = _sig(kw, seeds, days, k.catches)
    path = RES / "rep" / f"{sig}.json"
    if path.exists():
        return json.loads(path.read_text())
    jobs = [(kw, key, seeds, days, sweep_seeds, k.catches) for key in rep_driver.PLAYERS]
    with ProcessPoolExecutor(max_workers=len(jobs)) as ex:
        results = list(ex.map(_run_player, jobs))
    out = {"kwargs": {a: (b if not isinstance(b, tuple) else list(b)) for a, b in kw.items()}, "catches": k.catches,
           "seeds": seeds, "days": days, "players": {key: rec for key, rec, _ in results}}
    path.write_text(json.dumps(out, indent=1))
    return out


class Repeatable:
    """Counts of one player (cumulative by day anchors, steady per day, intra-day shape), priced with k's pays."""

    def __init__(self, rec: dict, k: K, hpd: float):
        self.hpd = hpd
        self.k = k

        def price(c: dict) -> dict:
            n = k.notice
            return {
                "notices": c["n1_n"] * n[0] + c["n2_n"] * n[1] + c["n3_n"] * n[2],
                "expeditions": c["exp_n"] * k.expedition,
                "events": c["ev1_n"] * k.event[0] + c["evk_n"] * k.event[1] + c["runs_done"] * k.event[2],
            }

        anchors = sorted(int(d) for d in rec["cum"])
        self.xs = [0] + anchors
        self.parts_cum = {"notices": [0.0], "expeditions": [0.0], "events": [0.0]}
        for d in anchors:
            p = price(rec["cum"][str(d)])
            for s in self.parts_cum:
                self.parts_cum[s].append(p[s])
        st = price(rec["steady"])
        self.steady = st
        self.per_day = sum(st.values())
        tot = self.per_day or 1.0
        self.share = {s: v / tot for s, v in st.items()}
        self.ys = [sum(self.parts_cum[s][i] for s in self.parts_cum) for i in range(len(self.xs))]
        sw = sorted((r["hours"], sum(price(r).values())) for r in rec["sweep"])
        self.sh = [0.0] + [h for h, _ in sw]
        self.sc = [0.0] + [c for _, c in sw]
        self.norm = interp(self.sh, self.sc, hpd) or 1.0
        self.xp_per_day = rec["steady"]["xp_board"] + rec["steady"]["xp_event"]
        self.tickets = {f: rec["steady"][f] for f in ("tickets_earned", "tickets_used", "tickets_lost")}

    def day_cum(self, d: float) -> float:
        if d <= self.xs[-1]:
            return interp(self.xs, self.ys, d)
        return self.ys[-1] + self.per_day * (d - self.xs[-1])

    def coins(self, h: float) -> float:
        d = h / self.hpd
        n = int(d + 1e-12)
        t = (d - n) * self.hpd
        base = self.day_cum(n)
        step = self.day_cum(n + 1) - base
        within = interp(self.sh, self.sc, t) / self.norm if t > 0 else 0.0
        return base + step * min(within, 1.0)


# ------------------------------------------------------------------------------------------------------------------
# the curve
# ------------------------------------------------------------------------------------------------------------------
SRC = [
    ("levels_first", "Level-ups, first climb"),
    ("levels_repeat", "Level-ups, repeat climbs"),
    ("prestige", "Prestige coins"),
    ("discovery", "Discovery (Species, curios, trophy, Zone Mastery, Legends)"),
    ("standing", "Standing Hunts"),
    ("notices", "Notices"),
    ("expeditions", "Expeditions"),
    ("events", "Hunt Event runs"),
    ("campfire", "Campfire"),
]


class Curve:
    def __init__(self, key: str, k: K, lua_base: dict, lua_act: dict, rep_rec: dict):
        label, hpd, *_ = rep_driver.PLAYERS[key]
        self.key, self.label, self.hpd, self.k = key, label, hpd, k
        self.rep = Repeatable(rep_rec, k, hpd)
        prof = LUA_PROFILE[key]
        b, a = lua_base[prof], lua_act[prof]
        # Activity XP: lua_act was run with ACT_XP0 per day, lua_base with none; interpolate (extrapolate) in the XP
        # this constants set's repeatable run produces
        r = self.rep.xp_per_day / ACT_XP0[key]
        self.hs = b["hs"]
        self.one = {f: [bv + (av - bv) * r for bv, av in zip(b[f], a[f])] for f in ("levels", "prestiges", "species", "curio", "trophy", "zone", "legend", "hunts")}
        self.xp_ratio = r
        hunt_factor = (HUNT_MIX[0] * k.standing[0] + HUNT_MIX[1] * k.standing[1] + HUNT_MIX[2] * k.standing[2]) / STANDING_POT_OLD
        self.hunt_factor = hunt_factor

    def campfire(self, h: float) -> float:
        d = int(h / self.hpd + 1e-12)
        return sum(c for days, c in self.k.campfire if d >= days)

    def parts(self, h: float) -> dict:
        k, o = self.k, self.one
        g = lambda f: interp(self.hs, o[f], h)  # noqa: E731
        lv = g("levels")
        first = min(lv, 59.0)
        p = {
            "levels_first": k.level_up * first,
            "levels_repeat": k.level_up * (lv - first),
            "prestige": k.prestige * g("prestiges"),
            "discovery": k.species * g("species") + k.curio * g("curio") + k.trophy * g("trophy") + k.zone_rank * g("zone") + k.legend * g("legend"),
            "standing": self.hunt_factor * g("hunts"),
        }
        r = self.rep.coins(h)
        for s, sh in self.rep.share.items():
            p[s] = r * sh
        p["campfire"] = self.campfire(h)
        return p

    def total(self, h: float) -> float:
        return sum(self.parts(h).values())


# non-uniform hour grid: fine at the start, coarse in the tail
GRID = [i * 0.05 for i in range(0, 101)] + [5 + i * 0.25 for i in range(1, 381)] + [100 + i * 1.0 for i in range(1, 2901)]


def grid_totals(curve: Curve) -> list:
    ys = [curve.total(h) for h in GRID]
    for i in range(1, len(ys)):
        if ys[i] < ys[i - 1]:
            ys[i] = ys[i - 1]
    return ys


def hours_to(ys: list, coins: float):
    if coins <= 0:
        return 0.0
    i = bisect.bisect_left(ys, coins)
    if i >= len(ys):
        return None
    if i == 0:
        return GRID[0]
    y0, y1 = ys[i - 1], ys[i]
    if y1 == y0:
        return GRID[i]
    return GRID[i - 1] + (GRID[i] - GRID[i - 1]) * (coins - y0) / (y1 - y0)


# ------------------------------------------------------------------------------------------------------------------
# the shop
# ------------------------------------------------------------------------------------------------------------------
CRATE_POOL = [("core.toaststyle.foil", 1), ("core.toaststyle.storm", 2), ("core.binding.shagreenbone", 2), ("core.toaststyle.arcane", 2)]


def read_goods() -> list:
    with open(INP / "goods.csv", newline="") as f:
        return [dict(id=r["id"], tier=int(r["tier"])) for r in csv.DictReader(f)]


@dataclass
class Step:
    cost: int
    good: str | None  # id of the for-sale good this purchase gives (None: Prize Foil, a duplicate)


def goods_for(k: K) -> list:
    goods = read_goods()
    pool_ids = {g for g, _ in CRATE_POOL}
    if k.tier6_carve:
        direct5 = [g for g in goods if g["tier"] == 5 and g["id"] not in pool_ids]
        for g in direct5[: k.tier6_goods]:
            g["tier"] = 6
    else:
        for i in range(k.tier6_goods):
            goods.append(dict(id=f"tier6.{i + 1}", tier=6))
    return goods


def price_of(k: K, tier: int) -> int:
    return k.prices[tier - 1] if tier <= 5 else k.tier6_price


def sequences(k: K):
    """Cheapest-first purchase sequences, one per ordering of the crate pool, with their probabilities. A crate step gives
    the next pool good in that order (Prize Foil: no for-sale good); crates stop once the 3 for-sale pool goods are owned."""
    goods = goods_for(k)
    pool_ids = {g for g, _ in CRATE_POOL}
    direct = [g for g in goods if g["id"] not in pool_ids]
    perms = []
    for perm in itertools.permutations(CRATE_POOL):
        rem, p = list(CRATE_POOL), 1.0
        for good, _ in perm:
            tot = sum(w for _, w in rem)
            p *= dict(rem)[good] / tot
            rem = [(g, w) for g, w in rem if g != good]
        perms.append((p, [g for g, _ in perm]))
    out = []
    for p, order in perms:
        items = [(price_of(k, g["tier"]), 1 if g["tier"] >= 0 else 0, g["id"]) for g in direct]
        crate_steps, owned = [], 0
        for good in order:
            if owned == 3:
                break
            if good in {g["id"] for g in goods}:
                crate_steps.append((k.crate_price, 0, good))
                owned += 1
            else:
                crate_steps.append((k.crate_price, 0, None))
        allsteps = [(pr, 1, gid) for pr, _, gid in items] + [(pr, 0, gid) for pr, _, gid in crate_steps]
        allsteps.sort(key=lambda s: (s[0], s[1]))  # equal price: crates (flag 0) before direct goods
        out.append((p, [Step(pr, gid) for pr, _, gid in allsteps]))
    return goods, out


def milestone_coins(k: K):
    """Expected (over crate order) coins spent when each milestone is met; also per-order for hours expectation."""
    goods, seqs = sequences(k)
    tier = {g["id"]: g["tier"] for g in goods}
    n = len(goods)
    results = []  # list of (p, {milestone: coins})
    for p, seq in seqs:
        owned: set = set()
        spent = 0
        m: dict = {}
        tiers_all = {t: {g for g, tt in tier.items() if tt <= t} for t in (3, 4, 5, 6)}
        t6 = sorted(g for g, tt in tier.items() if tt == 6)
        for st in seq:
            spent += st.cost
            m.setdefault("first", spent)
            if st.good:
                owned.add(st.good)
            cnt = len(owned)
            for f in (0.25, 0.5, 0.75, 1.0):
                key = f"items{int(f * 100)}"
                if key not in m and cnt >= math.ceil(f * n - 1e-9):
                    m[key] = spent
            for t, ids in tiers_all.items():
                key = f"tier{t}"
                if key not in m and ids <= owned:
                    m[key] = spent
            n6 = len([x for x in t6 if x in owned])
            for j in range(len(t6)):
                key = f"t6_{j + 1}"
                if key not in m and n6 >= j + 1:
                    m[key] = spent
        results.append((p, m))
    return n, goods, results


MILES = [("first", "First purchase"), ("items25", "25% of items"), ("items50", "50% of items"), ("items75", "75% of items"),
         ("tier3", "Tiers 1-3 complete"), ("tier4", "Tiers 1-4 complete"), ("tier5", "Tiers 1-5 complete"),
         ("t6_1", "First tier-6 good"), ("t6_2", "Second tier-6 good"), ("items100", "Everything")]
TARGETS = {"first": "< 1", "items25": "~40", "items50": "~100", "items75": "~200", "tier4": "~430", "tier5": "~720", "t6_1": "~870", "t6_2": "~1,015"}
TARGET_H = {"first": 1.0, "items25": 40.0, "items50": 100.0, "items75": 200.0, "tier4": 430.0, "tier5": 720.0, "t6_1": 870.0, "t6_2": 1015.0}


def milestone_hours(k: K, grid_ys: list) -> dict:
    n, goods, results = milestone_coins(k)
    out = {}
    keys = set().union(*[set(m) for _, m in results])
    for key in keys:
        coins = hrs = 0.0
        ok = True
        for p, m in results:
            if key not in m:
                continue
            h = hours_to(grid_ys, m[key])
            coins += p * m[key]
            if h is None:
                ok = False
            else:
                hrs += p * h
        out[key] = (coins, hrs if ok else None)
    return out


# ------------------------------------------------------------------------------------------------------------------
# evaluate a constants set
# ------------------------------------------------------------------------------------------------------------------
_LUA = {}
SEEDS180 = "_30"  # the 180 Catches/h inputs are 30 seeds of the Lua model ("" = #396's 10-seed files); 120/240 use 10 seeds


def lua_sets(catches: int = 180):
    sfx = SEEDS180 if catches == 180 else f"_{catches}"
    if (catches, sfx) not in _LUA:
        _LUA[(catches, sfx)] = (read_lua(INP / f"lua_base{sfx}" / "by_hour.csv"), read_lua(INP / f"lua_act{sfx}" / "by_hour.csv"))
    return _LUA[(catches, sfx)]


def evaluate(k: K, seeds: int = 24, players=None) -> dict:
    rep = rep_run(k, seeds=seeds)
    lb, la = lua_sets(k.catches)
    curves, grids, miles = {}, {}, {}
    for key in rep_driver.PLAYERS:
        if players and key not in players:
            continue
        curves[key] = Curve(key, k, lb, la, rep["players"][key])
        grids[key] = grid_totals(curves[key])
        miles[key] = milestone_hours(k, grids[key])
    return dict(k=k, rep=rep, curves=curves, grids=grids, miles=miles)


PHASES = [(0, 1), (1, 20), (20, 100), (100, 300), (300, 500), (500, 1000)]


def fmt_h(h):
    if h is None:
        return ">4000"
    return f"{h:.1f}" if h < 10 else f"{h:,.0f}"


def md_table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "|".join("---" if i == 0 else "---:" for i in range(len(header))) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out) + "\n"


def milestone_table(ev: dict, keys=None) -> str:
    keys = keys or [m for m, _ in MILES]
    rows = []
    for key, label in MILES:
        if key not in keys:
            continue
        row = [label, TARGETS.get(key, "-")]
        for pk, c in ev["curves"].items():
            h = ev["miles"][pk].get(key, (0, None))[1]
            row.append(f"{fmt_h(h)} h (d{fmt_h(h / c.hpd) if h is not None else '-'})")
        rows.append(row)
    return md_table(["Milestone", "Target casual h"] + [c.label for c in ev["curves"].values()], rows)


def phase_table(ev: dict) -> str:
    rows = []
    for pk, c in ev["curves"].items():
        row = [c.label]
        for a, b in PHASES:
            row.append(f"{(c.total(b) - c.total(a)) / (b - a):,.0f}")
        row.append(f"{c.total(100) / 100:,.0f}")
        row.append(f"{(c.total(500) - c.total(100)) / 400:,.0f}")
        row.append(f"{c.total(1000) / 1000:,.0f}")
        rows.append(row)
    return md_table(["Player"] + [f"{a}-{b} h" for a, b in PHASES] + ["0-100 h", "100-500 h", "0-1000 h"], rows)


def mix_table(ev: dict, key: str) -> str:
    c = ev["curves"][key]
    rows = []
    for a, b in PHASES:
        pa, pb = c.parts(a), c.parts(b)
        diff = {s: pb[s] - pa[s] for s, _ in SRC}
        tot = sum(diff.values())
        rows.append([f"{a}-{b} h", f"{tot / (b - a):,.0f}"] + [f"{100 * diff[s] / tot:.0f}%" for s, _ in SRC])
    return md_table(["Phase", "Coins/h"] + [n for _, n in SRC], rows)


if __name__ == "__main__":
    print("see run_all.py")
