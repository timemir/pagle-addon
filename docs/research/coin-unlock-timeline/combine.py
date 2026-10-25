#!/usr/bin/env python3
"""Coin economy research, ticket #396 (map #393): the unlock timeline of the current catalogue.

Combines the two input models into one cumulative Pagle Coins curve per player, applies the real price list
(origin/main 72f82efc: 101 goods, 86,050 coins, Curio crate 2,000) with two buy orders, and writes the tables.

    python docs/research/coin-unlock-timeline/combine.py            # from the repo root; ~20 s, no dependencies

INPUTS (all committed under inputs/, so nothing is re-simulated here):
  inputs/onetime_activity_by_hour.csv   #394's model.lua (luajit, the repo's own Ledger fold and Hunts projection),
                                        run with a denser HOUR_MARKS and with the Tackle Board / Hunt Event Activity XP
                                        of #395 fed to the Ledger (onetime_model.lua --activity-xp). Base curve.
  inputs/onetime_base_by_hour.csv       The same run without that Activity XP (the #394 assumption), for the delta.
  inputs/repeatable_subset.json         #395's results.json (model.py): Notices, Expeditions, Event runs, Campfire.
  inputs/goods.csv                      The 101 goods for sale and their tiers, read from the repo's goods files.

HOW THE TWO TIME AXES ARE RECONCILED
  * #394 is indexed by hours fished, #395 by calendar day. A player is (hours per day h, play profile), so day =
    hours / h; #394 reports days_mean = hours / h for every mark, which confirms it. Everything is combined on hours
    fished and every table also gives the day (hours / h).
  * Coins by source, never summed twice:
      Ledger level-ups (first climb + every repeat Prestige climb), Species / curios / trophy weights / Zone Mastery /
      Legends, Standing Hunts            -> #394 only. #395's "Ledger" share (its mix check) is NOT used.
      Notices, Expeditions, Hunt Event runs, Campfire  -> #395 only (Campfire as its four milestones, see below).
      Tackle Board coins and Event run coins are not in #394 (it excluded them); Standing Hunts are not in #395.
  * Activity XP: #394 assumed no Tackle Board XP and counted Hunts' Standing Hunt XP only. #395 measured the Board
    goals' and the Event runs' Activity XP per day (877 / 944 / 1,045 / 1,056 XP). Those XP feed the Ledger's climb,
    so level-up coins rise. Instead of a flat percentage, the #394 model is re-run with that XP per day fed to the
    Ledger (--activity-xp), so the extra XP moves levels and Prestige climbs through the real fold. The delta against
    the no-Activity-XP run is reported.
  * #395 is steady state per calendar day, saturating at about 3 hours of play a day. For a player at h hours/day
    its cumulative curve R(day) is used at days 1..180 (its own anchors, ramp included), and its steady coins per day
    after day 180. Its Campfire is subtracted from the anchors and re-added as milestones 25 / 75 / 200 / 500 at days
    7 / 30 / 100 / 365 (daily play, its p=1.0 case). A dedicated 4 h/day player earns nothing more from the board
    after about 3 h of the day, but the same Catches still earn XP, Species and Zone Mastery in #394: both axes
    are consumed by the same fishing hours, no extra hours are added for the repeatable sources.
  * Inside a day (the first hours matter for "hour 0-1"), the repeatable coins follow #395's hours-per-day sweep:
    the day's coins as a function of the hours played that day, normalised to the player's day total.
"""
import bisect
import csv
import itertools
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
INP = os.path.join(HERE, "inputs")
OUT = os.path.join(HERE, "tables")
os.makedirs(OUT, exist_ok=True)

TIER_PRICES = {1: 150, 2: 400, 3: 900, 4: 2000, 5: 5000}
CRATE_PRICE = 2000
CRATE_POOL = [("core.toaststyle.foil", 1), ("core.toaststyle.storm", 2), ("core.binding.shagreenbone", 2), ("core.toaststyle.arcane", 2)]
CAMPFIRE = [(7, 25), (30, 75), (100, 200), (365, 500)]  # day reached, coins (daily play)

# player -> (label, hours/day, #394 profile, #395 scenario, #395 sweep policy)
PLAYERS = {
    "casual": ("Casual 1.5 h/day", 1.5, "casual", "casual", "typical"),
    "dedicated": ("Dedicated 4 h/day", 4.0, "dedicated", "dedicated", "typical"),
    "minmax15": ("Min-max 1.5 h/day", 1.5, "minmax_1.5h", "casual_minmax", "minmax"),
    "minmax4": ("Min-max 4 h/day", 4.0, "minmax_4h", "minmax", "minmax"),
}
HORIZON = 4000.0  # hours
STEP = 0.05


# ------------------------------------------------------------------------------------------------------ helpers
def interp(xs, ys, x):
    """Piecewise linear, flat extension below xs[0], last slope above xs[-1]."""
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


def read_onetime(path):
    by = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            by.setdefault(r["profile"], []).append(r)
    return by


def onetime_curves(rows):
    """Components of #394 by hours: first climb, repeat Prestige loop, discovery, standing hunts (origin 0)."""
    hs = [0.0] + [float(r["hours"]) for r in rows]

    def col(f):
        return [0.0] + [f(r) for r in rows]

    fl = lambda r, k: float(r[k])
    return hs, {
        "first_climb": col(lambda r: fl(r, "levels_first_climb")),
        "prestige_loop": col(lambda r: fl(r, "prestige_loop")),
        "discovery": col(lambda r: sum(fl(r, k) for k in ("species", "curio", "trophy", "zone", "legend"))),
        "standing_hunts": col(lambda r: fl(r, "hunts")),
    }


def campfire_at(day):
    return sum(c for d, c in CAMPFIRE if day >= d)


class Repeatable:
    """#395's cumulative coins by calendar day for one scenario, split into Notices / Expeditions / Event runs."""

    def __init__(self, rep, scenario, policy, hpd):
        sc = rep["scenarios"][scenario]
        self.hpd = hpd
        cum = {int(k): v for k, v in sc["cum"].items()}
        days = sorted(cum)
        steady = sc["steady"]
        parts = {k: steady[k + "_coins"] for k in ("notice", "expedition", "event")}
        tot = sum(parts.values())
        self.share = {k: v / tot for k, v in parts.items()}
        self.per_day = steady["coins"]  # excl. Campfire
        self.xs = [0] + days
        # anchors without the Campfire milestones that fall inside them
        self.ys = [0.0] + [cum[d] - campfire_at(d) for d in days]
        # intra-day shape: day's coins vs hours played that day (the sweep, 'both' mode)
        sw = sorted((r["hours"], r["coins_per_day"]) for r in rep["sweep"] if r["policy"] == policy and r["mode"] == "both")
        if policy == "minmax":
            pass
        self.sh = [0.0] + [h for h, _ in sw]
        self.sc = [0.0] + [c for _, c in sw]
        self.norm = interp(self.sh, self.sc, hpd)

    def day_cum(self, d):
        return interp(self.xs, self.ys, d) if d <= self.xs[-1] else self.ys[-1] + self.per_day * (d - self.xs[-1])

    def coins(self, h):
        """Repeatable coins (excl. Campfire) after h cumulative hours fished."""
        d = h / self.hpd
        n = int(d + 1e-12)
        t = (d - n) * self.hpd
        base = self.day_cum(n)
        step = self.day_cum(n + 1) - base
        within = interp(self.sh, self.sc, t) / self.norm if t > 0 else 0.0
        return base + step * min(within, 1.0)

    def campfire(self, h):
        return campfire_at(int(h / self.hpd + 1e-12))


# ------------------------------------------------------------------------------------------------------ combine
class Curve:
    """Cumulative coins by source for one player, as functions of hours fished."""

    def __init__(self, key, rep, one_rows, activity=True):
        label, hpd, prof, scen, policy = PLAYERS[key]
        self.key, self.label, self.hpd = key, label, hpd
        self.hs, self.one = onetime_curves(one_rows[prof])
        self.rep = Repeatable(rep, scen, policy, hpd)

    def parts(self, h):
        p = {k: interp(self.hs, v, h) for k, v in self.one.items()}
        r = self.rep.coins(h)
        for k, s in self.rep.share.items():
            p[k + "s" if k != "event" else "events"] = r * s
        p["campfire"] = self.rep.campfire(h)
        return p

    def total(self, h):
        return sum(self.parts(h).values())


GRID = [i * STEP for i in range(int(HORIZON / STEP) + 1)]


def build_grid(curve):
    ys = [curve.total(h) for h in GRID]
    # guard against a non-monotone join (a campfire step is monotone; interpolation is)
    for i in range(1, len(ys)):
        if ys[i] < ys[i - 1]:
            ys[i] = ys[i - 1]
    return ys


def hours_to(grid_ys, coins):
    """First hour at which cumulative coins reach `coins` (linear within a grid step); None past the horizon."""
    if coins <= 0:
        return 0.0
    i = bisect.bisect_left(grid_ys, coins)
    if i >= len(grid_ys):
        return None
    if i == 0:
        return GRID[0]
    y0, y1 = grid_ys[i - 1], grid_ys[i]
    if y1 == y0:
        return GRID[i]
    return GRID[i - 1] + STEP * (coins - y0) / (y1 - y0)


# ------------------------------------------------------------------------------------------------------ catalogue
def read_goods():
    with open(os.path.join(INP, "goods.csv"), newline="") as f:
        return [dict(slot=r["slot"], id=r["id"], tier=int(r["tier"])) for r in csv.DictReader(f)]


def buy_sequences(goods):
    """The two buy orders as lists of purchase steps, for each ordering of the crate pool.

    A step is (cost, count_delta, value_delta). The 3 for-sale pool goods (Storm Front, Arcane Sigil, Shagreen and
    Bone) are bought through the Curio crate (2,000; the pool is 4 goods and every crate gives one not yet owned, so 4
    crates give all 4). The crate-only Prize Foil is not part of the 101, and counts 0 items / 0 value. Which good a
    crate gives is random (weights 1/2/2/2): all 24 orders are enumerated with their probabilities. A player stops
    buying crates once the three for-sale pool goods are owned.
    """
    pool_ids = {g for g, _ in CRATE_POOL}
    price = {g["id"]: TIER_PRICES[g["tier"]] for g in goods}
    direct = [g for g in goods if g["id"] not in pool_ids]
    perms = []
    for perm in itertools.permutations(CRATE_POOL):
        remaining = list(CRATE_POOL)
        p = 1.0
        for good, _ in perm:
            tot = sum(w for _, w in remaining)
            w = dict(remaining)[good]
            p *= w / tot
            remaining = [(g, ww) for g, ww in remaining if g != good]
        perms.append((p, [g for g, _ in perm]))

    def crate_steps(order):
        steps, owned_for_sale = [], 0
        for good in order:
            if owned_for_sale == 3:
                break
            if good in price:
                steps.append((CRATE_PRICE, 1, price[good]))
                owned_for_sale += 1
            else:
                steps.append((CRATE_PRICE, 0, 0))
        return steps

    def tier_sorted(tiers):
        out = []
        for t in tiers:
            out += [(TIER_PRICES[g["tier"]], 1, TIER_PRICES[g["tier"]]) for g in direct if g["tier"] == t]
        return out

    seqs = {"cheapest-first": [], "prestige-first": []}
    for p, order in perms:
        cs = crate_steps(order)
        # cheapest-first: tiers 1..3, then the crates (2,000, ahead of the tier-4 goods at the same price: they
        # return more list value per coin), then tier 4 and 5 direct buys
        seqs["cheapest-first"].append((p, tier_sorted([1, 2, 3]) + cs + tier_sorted([4, 5])))
        # prestige-first: the crates first (the cheapest road to a tier-5 good), then tier 5, 4, 3, 2, 1 direct
        seqs["prestige-first"].append((p, cs + tier_sorted([5, 4, 3, 2, 1])))
    return seqs


MILESTONES = [("first purchase", None), ("25%", 0.25), ("50%", 0.50), ("75%", 0.75), ("100%", 1.00)]


def milestone_costs(seq, total_count, total_value):
    """For one purchase sequence: cumulative coins spent when each milestone is first met, by count and by value."""
    spent = cnt = val = 0
    reach = {"count": {}, "value": {}}
    first = None
    need = {}
    for name, f in MILESTONES[1:]:
        import math
        need[("count", name)] = math.ceil(f * total_count - 1e-9)
        need[("value", name)] = f * total_value - 1e-9
    for cost, dc, dv in seq:
        spent += cost
        if first is None:
            first = spent
        cnt += dc
        val += dv
        for (kind, name), n in need.items():
            if name not in reach[kind] and (cnt if kind == "count" else val) >= n:
                reach[kind][name] = spent
    return first, reach


def milestone_hours(grid_ys, seqs, total_count, total_value):
    """Expected (over the crate order) hours to each milestone; also the coins spent."""
    out = {}
    for order, plist in seqs.items():
        acc = {}
        for p, seq in plist:
            first, reach = milestone_costs(seq, total_count, total_value)
            acc.setdefault("first", []).append((p, first))
            for kind in ("count", "value"):
                for name, c in reach[kind].items():
                    acc.setdefault((kind, name), []).append((p, c))
        res = {}
        for k, lst in acc.items():
            coins = sum(p * c for p, c in lst)
            hrs = [(p, hours_to(grid_ys, c)) for p, c in lst]
            hours = None if any(h is None for _, h in hrs) else sum(p * h for p, h in hrs)
            res[k] = (coins, hours)
        out[order] = res
    return out


# ------------------------------------------------------------------------------------------------------ output
def fmt_h(h):
    if h is None:
        return "> %d" % HORIZON
    if h < 10:
        return "%.1f" % h
    return "%d" % round(h)


def fmt_hd(h, hpd):
    if h is None:
        return "> %d h" % HORIZON
    return "%s h (day %s)" % (fmt_h(h), fmt_h(h / hpd) if h / hpd >= 10 else "%.1f" % (h / hpd))


def write(name, text):
    with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "|".join("---" if i == 0 else "---:" for i in range(len(header))) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out) + "\n"


PHASES = [(0, 1), (1, 20), (20, 100), (100, 300), (300, 500), (500, 1000)]
SRC_ORDER = [
    ("first_climb", "level-ups, first climb"),
    ("prestige_loop", "level-ups, repeat Prestige climbs"),
    ("discovery", "discovery (Species, curios, trophy, Zone Mastery, Legends)"),
    ("standing_hunts", "Standing Hunts"),
    ("notices", "Notices"),
    ("expeditions", "Expeditions"),
    ("events", "Hunt Event runs"),
    ("campfire", "Campfire"),
]


def main():
    rep = json.load(open(os.path.join(INP, "repeatable_subset.json")))
    one_act = read_onetime(os.path.join(INP, "onetime_activity_by_hour.csv"))
    one_base = read_onetime(os.path.join(INP, "onetime_base_by_hour.csv"))
    goods = read_goods()
    total_count = len(goods)
    total_value = sum(TIER_PRICES[g["tier"]] for g in goods)
    assert total_count == 101 and total_value == 86050, (total_count, total_value)
    seqs = buy_sequences(goods)

    curves = {k: Curve(k, rep, one_act) for k in PLAYERS}
    base_curves = {k: Curve(k, rep, one_base) for k in PLAYERS}
    grids = {k: build_grid(c) for k, c in curves.items()}
    grids_base = {k: build_grid(c) for k, c in base_curves.items()}

    md = []

    # --- 0. catalogue ------------------------------------------------------------------------------------------
    by_tier = {t: sum(1 for g in goods if g["tier"] == t) for t in TIER_PRICES}
    cat_rows = [(f"Tier {t} ({TIER_PRICES[t]:,})", by_tier[t], f"{by_tier[t] * TIER_PRICES[t]:,}") for t in TIER_PRICES]
    cat_rows.append(("All", total_count, f"{total_value:,}"))
    md.append("## Catalogue (origin/main 72f82efc)\n\n" + table(["Tier (price)", "Goods", "Coins"], cat_rows))
    exp_costs = {}
    for order in seqs:
        tot = sum(p * sum(c for c, _, _ in seq) for p, seq in seqs[order])
        exp_costs[order] = tot
    md.append(
        "Coins to own all 101: cheapest-first %s on average (crate order random; 82,050 if all 4 crates are bought, 80,050 if the "
        "Prize Foil comes last and the 4th crate is skipped), prestige-first %s.\n"
        % (f"{exp_costs['cheapest-first']:,.0f}", f"{exp_costs['prestige-first']:,.0f}")
    )

    # --- 1. cumulative curve -----------------------------------------------------------------------------------
    marks = [1, 5, 10, 20, 50, 100, 200, 300, 500, 750, 1000, 1500, 2000]
    rows = []
    for k, c in curves.items():
        rows.append([c.label] + ["{:,.0f}".format(c.total(h)) for h in marks])
    md.append("## Cumulative coins by hours fished (all sources)\n\n" + table(["Player"] + ["%d h" % m for m in marks], rows))
    dmarks = [1, 3, 7, 14, 30, 60, 90, 180, 365, 540, 730]
    rows = []
    for k, c in curves.items():
        rows.append([c.label] + ["{:,.0f}".format(c.total(d * c.hpd)) for d in dmarks])
    md.append("## Cumulative coins by calendar day (all sources)\n\n" + table(["Player"] + ["day %d" % d for d in dmarks], rows))

    # activity XP delta
    rows = []
    for k in PLAYERS:
        rows.append(
            [PLAYERS[k][0]]
            + [
                "{:,.0f} ({:+.1f}%)".format(
                    curves[k].total(h) - base_curves[k].total(h), 100 * (curves[k].total(h) / base_curves[k].total(h) - 1)
                )
                for h in (20, 100, 300, 500)
            ]
        )
    md.append(
        "## What the Activity XP of the Board goals and Event runs adds (all-source coins, vs the same curve without it)\n\n"
        + table(["Player", "20 h", "100 h", "300 h", "500 h"], rows)
    )

    # --- 2. milestones ------------------------------------------------------------------------------------------
    for order in ("cheapest-first", "prestige-first"):
        rows = []
        for k, c in curves.items():
            res = milestone_hours(grids[k], {order: seqs[order]}, total_count, total_value)[order]
            row = [c.label, "{:,.0f}".format(res["first"][0]), fmt_hd(res["first"][1], c.hpd)]
            for kind in ("count", "value"):
                for name in ("25%", "50%", "75%", "100%"):
                    row.append(fmt_hd(res[(kind, name)][1], c.hpd))
            rows.append(row)
        md.append(
            "## Unlock milestones, %s: hours fished (calendar day)\n\n" % order
            + table(
                ["Player", "First buy (coins)", "First purchase"]
                + ["%s items" % n for n in ("25%", "50%", "75%", "100%")]
                + ["%s value" % n for n in ("25%", "50%", "75%", "100%")],
                rows,
            )
        )
    # coins needed per milestone (cheapest-first and prestige-first), independent of the player
    rows = []
    for order in seqs:
        accum = {}
        for p, seq in seqs[order]:
            first, reach = milestone_costs(seq, total_count, total_value)
            accum.setdefault("first", 0)
            accum["first"] += p * first
            for kind in ("count", "value"):
                for name, cst in reach[kind].items():
                    accum[(kind, name)] = accum.get((kind, name), 0) + p * cst
        rows.append(
            [order, "{:,.0f}".format(accum["first"])]
            + ["{:,.0f}".format(accum[("count", n)]) for n in ("25%", "50%", "75%", "100%")]
            + ["{:,.0f}".format(accum[("value", n)]) for n in ("25%", "50%", "75%", "100%")]
        )
    md.append(
        "## Coins spent to reach each milestone (expected, over the crate order)\n\n"
        + table(["Buy order", "First"] + ["%s items" % n for n in ("25%", "50%", "75%", "100%")] + ["%s value" % n for n in ("25%", "50%", "75%", "100%")], rows)
    )

    # --- 3. coins per hour by phase -----------------------------------------------------------------------------
    rows = []
    for k, c in curves.items():
        row = [c.label]
        for a, b in PHASES:
            row.append("{:,.0f}".format((c.total(b) - c.total(a)) / (b - a)))
        row.append("{:,.0f}".format(c.total(100) / 100))
        row.append("{:,.0f}".format((c.total(500) - c.total(100)) / 400))
        rows.append(row)
    md.append(
        "## Average coins per fishing hour by phase\n\n"
        + table(["Player"] + ["%d-%d h" % pr for pr in PHASES] + ["0-100 h", "100-500 h"], rows)
    )
    rows = []
    for k, c in base_curves.items():
        row = [c.label]
        for a, b in PHASES:
            row.append("{:,.0f}".format((c.total(b) - c.total(a)) / (b - a)))
        row.append("{:,.0f}".format(c.total(100) / 100))
        row.append("{:,.0f}".format((c.total(500) - c.total(100)) / 400))
        rows.append(row)
    md.append(
        "### Same, without the Activity XP (the #394 assumption)\n\n"
        + table(["Player"] + ["%d-%d h" % pr for pr in PHASES] + ["0-100 h", "100-500 h"], rows)
    )

    # coins per calendar day by phase
    rows = []
    for k, c in curves.items():
        row = [c.label]
        for a, b in PHASES:
            row.append("{:,.0f}".format((c.total(b) - c.total(a)) / ((b - a) / c.hpd)))
        rows.append(row)
    md.append("### Coins per calendar day in those phases\n\n" + table(["Player"] + ["%d-%d h" % pr for pr in PHASES], rows))

    # --- 4. dominant sources by phase -----------------------------------------------------------------------------
    for k, c in curves.items():
        rows = []
        for a, b in PHASES:
            pa, pb = c.parts(a), c.parts(b)
            diff = {s: pb.get(s, 0) - pa.get(s, 0) for s, _ in SRC_ORDER}
            tot = sum(diff.values())
            rows.append(["%d-%d h" % (a, b), "{:,.0f}".format(tot)] + ["%.0f%%" % (100 * diff[s] / tot) for s, _ in SRC_ORDER])
        md.append(
            "## Source mix by phase: %s (share of the phase's coins)\n\n" % c.label
            + table(["Phase", "Coins"] + [n for _, n in SRC_ORDER], rows)
        )

    # --- 5. where the curve is flat ----------------------------------------------------------------------------------
    rows = []
    for k, c in curves.items():
        samp = [(c.total(h + 5) - c.total(h)) / 5 for h in (0, 10, 30, 100, 300, 1000)]
        # first 50 h window whose average falls below 100 coins/h, and below 1.1 x the 300-1000 h plateau
        plateau = (c.total(1000) - c.total(300)) / 700
        under100 = under_plateau = None
        for start in [i * 5.0 for i in range(0, 300)]:
            rate = (c.total(start + 50) - c.total(start)) / 50
            if under100 is None and rate < 100:
                under100 = start
            if under_plateau is None and rate < 1.1 * plateau:
                under_plateau = start
        rows.append(
            [c.label]
            + ["{:,.0f}".format(s) for s in samp]
            + ["{:,.0f}".format(plateau), "%s h" % (under100 if under100 is not None else "-"), "%s h" % (under_plateau if under_plateau is not None else "-")]
        )
    md.append(
        "## Where the curve flattens (coins per fishing hour over the 5 h starting at ...; the plateau is the 300-1000 h average)\n\n"
        + table(["Player", "0 h", "10 h", "30 h", "100 h", "300 h", "1000 h", "Plateau", "50 h rate under 100 from", "within 10% of plateau from"], rows)
    )

    # tier blocks of the cheapest-first buy order: when each block is complete and the hours per purchase in it
    blocks = [("Tier 1 (25 x 150)", 25, 3750), ("Tier 2 (33 x 400)", 33, 13200), ("Tier 3 (29 x 900)", 29, 26100), ("Tier 4 + 4 crates (8 x 2,000 + 4 x 2,000)", 12, 24000), ("Tier 5 (3 x 5,000)", 3, 15000)]
    rows = []
    for k, c in curves.items():
        spent, t_prev, row = 0, 0.0, [c.label]
        for name, n, cost in blocks:
            spent += cost
            t = hours_to(grids[k], spent)
            row.append("%s h (%s h each)" % (fmt_h(t), "%.1f" % ((t - t_prev) / n) if t is not None else "-"))
            t_prev = t if t is not None else t_prev
        rows.append(row)
    md.append(
        "## Cheapest-first: hours fished when each block of the buy order is finished (and the average hours per purchase inside it; all 4 crates bought, 82,050 coins in all)\n\n"
        + table(["Player"] + [b[0] for b in blocks], rows)
    )

    # how much of the catalogue is owned after N hours (cheapest-first and prestige-first)
    own_marks = [1, 5, 10, 20, 50, 100, 200, 300, 500, 1000]
    for order in ("cheapest-first", "prestige-first"):
        rows = []
        for k, c in curves.items():
            row = [c.label]
            for h in own_marks:
                e = c.total(h)
                cnt = val = 0.0
                for p, seq in seqs[order]:
                    spent = n_items = v = 0
                    for cost, dc, dv in seq:
                        if spent + cost > e + 1e-9:
                            break
                        spent += cost
                        n_items += dc
                        v += dv
                    cnt += p * n_items
                    val += p * v
                row.append("%.0f / %.0f%%" % (100 * cnt / total_count, 100 * val / total_value))
            rows.append(row)
        md.append(
            "## Share of the catalogue owned after N hours of fishing, %s (items / value)\n\n" % order
            + table(["Player"] + ["%d h" % h for h in own_marks], rows)
        )

    # --- 6. targets ------------------------------------------------------------------------------------------------------
    t_rows = []
    for k, c in curves.items():
        r = milestone_hours(grids[k], seqs, total_count, total_value)
        cf = r["cheapest-first"]
        t_rows.append(
            [
                c.label,
                fmt_h(cf["first"][1]),
                fmt_h(cf[("count", "25%")][1]),
                fmt_h(cf[("count", "75%")][1]),
                fmt_h(cf[("count", "100%")][1]),
                fmt_h(cf[("value", "25%")][1]),
                fmt_h(cf[("value", "75%")][1]),
                fmt_h(cf[("value", "100%")][1]),
            ]
        )
    t_rows.append(["Dev target", "~1", "~20", "~100", "300-500", "-", "-", "-"])
    md.append(
        "## Against the dev's targets (cheapest-first; hours fished)\n\n"
        + table(["Player", "First", "25% items", "75% items", "100% items", "25% value", "75% value", "100% value"], t_rows)
    )

    # the income the targets would need
    cost_by = {}
    for p, seq in seqs["cheapest-first"]:
        first, reach = milestone_costs(seq, total_count, total_value)
        for kind in ("count", "value"):
            for nme, cst in reach[kind].items():
                cost_by[(kind, nme)] = cost_by.get((kind, nme), 0) + p * cst
    targets = [("25% of items at 20 h", cost_by[("count", "25%")], 20), ("75% of items at 100 h", cost_by[("count", "75%")], 100), ("everything at 300 h", cost_by[("count", "100%")], 300), ("everything at 500 h", cost_by[("count", "100%")], 500)]
    rows = []
    for label, coins, h in targets:
        row = [label, "{:,.0f}".format(coins), "{:,.0f}".format(coins / h)]
        for k, c in curves.items():
            row.append("{:,.0f} ({:,.0f})".format(c.total(h) / h, c.total(h)))
        rows.append(row)
    md.append(
        "## Income the dev's targets need vs what the model gives (average coins per fishing hour over 0 to the target hour; cumulative coins in brackets)\n\n"
        + table(["Target", "Coins to spend", "Needed coins/h"] + [c.label for c in curves.values()], rows)
    )

    # --- 7. sensitivity: no repeat Prestige climbs (SHOP-R1 / ADR 0009) -------------------------------------
    sens_rows = []
    for k, c in curves.items():
        # without the repeat Prestige climbs (SHOP-R1 / ADR 0009): subtract that source from the total
        def no_loop(h, c=c):
            return c.total(h) - c.parts(h)["prestige_loop"]

        ys = [no_loop(h) for h in GRID]
        for i in range(1, len(ys)):
            ys[i] = max(ys[i], ys[i - 1])
        r = milestone_hours(ys, {"cheapest-first": seqs["cheapest-first"]}, total_count, total_value)["cheapest-first"]
        sens_rows.append(
            [c.label + ", no repeat Prestige climbs"]
            + [fmt_h(r["first"][1])]
            + [fmt_h(r[("count", n)][1]) for n in ("25%", "50%", "75%", "100%")]
            + [fmt_h(r[("value", n)][1]) for n in ("25%", "50%", "75%", "100%")]
        )
    for k, c in curves.items():
        r = milestone_hours(grids[k], {"cheapest-first": seqs["cheapest-first"]}, total_count, total_value)["cheapest-first"]
        sens_rows.append(
            [c.label + ", base"]
            + [fmt_h(r["first"][1])]
            + [fmt_h(r[("count", n)][1]) for n in ("25%", "50%", "75%", "100%")]
            + [fmt_h(r[("value", n)][1]) for n in ("25%", "50%", "75%", "100%")]
        )
    md.append(
        "## Sensitivity: without the repeat Prestige climbs (hours fished, cheapest-first)\n\n"
        + table(["Player", "First", "25% items", "50%", "75%", "100%", "25% value", "50%", "75%", "100%"], sens_rows)
    )

    # --- machine readable: curves and milestones --------------------------------------------------------------------------------
    hrs_out = [0.25, 0.5, 1, 2, 3, 5, 7.5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500, 750, 1000, 1500, 2000, 3000]
    with open(os.path.join(OUT, "curve_by_hour.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["player", "hours", "day", "total", "no_activity_xp_total"] + [s for s, _ in SRC_ORDER])
        for k, c in curves.items():
            for h in hrs_out:
                p = c.parts(h)
                w.writerow([k, h, round(h / c.hpd, 2), round(c.total(h)), round(base_curves[k].total(h))] + [round(p[s]) for s, _ in SRC_ORDER])
    with open(os.path.join(OUT, "milestones.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["player", "order", "milestone", "basis", "coins_spent", "hours", "day"])
        for k, c in curves.items():
            r = milestone_hours(grids[k], seqs, total_count, total_value)
            for order, res in r.items():
                for key, (coins, hours) in res.items():
                    basis, name = ("any", "first purchase") if key == "first" else key
                    w.writerow([k, order, name, basis, round(coins), "" if hours is None else round(hours, 1), "" if hours is None else round(hours / c.hpd, 1)])

    write("tables.md", "\n".join(md))
    print("\n".join(md))


if __name__ == "__main__":
    main()
