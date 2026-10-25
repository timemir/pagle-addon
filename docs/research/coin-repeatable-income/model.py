#!/usr/bin/env python3
"""Repeatable, calendar-gated Pagle Coin income model (issue #395, child of map #393).

Run (stdlib only, Python 3.12+; reads the committed data layers through scripts/pagle_data):

    python docs/research/coin-repeatable-income/model.py            # everything, writes tables/ and results.json
    python docs/research/coin-repeatable-income/model.py --quick    # fewer seeds, for a smoke test

What it models (all constants are quoted from the code or spec, see the CONSTANTS block):
  * the Tackle Board: Notices (3 per daily reset, cap 6 open), Expeditions (1 per weekly reset, cap 2 open), goal
    generation as TKB-R30..R36 say (kind weights, tiers, needs, recent-zone weight 8), progress as TKB-R40..R46 say
    (every Catch is evaluated against every open goal), the Campfire (TKB-R70..R74) and its milestones;
  * Hunt Events: the 24 rotating events in data/hunts/events/*.toml, run back to back in 72 h slots
    (low -> mid -> high bands), paying 15 / 10 / 10 per Hunt plus 50 for a completed run (HNT-R110);
  * Activity XP these sources add (TKB-R65, HNT-R114) and its marginal value in level-up coins (LED-R88, LED-R30);
  * a Catch-by-Catch Monte Carlo of a player fishing 180 Catches an hour who always works the zone with the best
    expected coins-per-chunk (a greedy planner). Loot comes from data/baseline (VMaNGOS chances, the same shares
    scripts/propose-events.py uses for the event tiers) and item facts from the generated catalogue layer.

Every modelling assumption is in ASSUMPTIONS below; nothing here changes economy code or data. report.py renders the
markdown tables in tables/ from results.json.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import json
import math
import random
import statistics
import sys
import tomllib
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(HERE))

from pagle_data.confirmed import zone_of  # noqa: E402
from pagle_data.events import band_of  # noqa: E402
from pagle_data.generate import read_layers  # noqa: E402
from pagle_data.hunts import hunt_classes  # noqa: E402
from pagle_data.propose_events import loot_shares  # noqa: E402

# --------------------------------------------------------------------------------------------------------------
# CONSTANTS (quoted from code / spec; the file and rule that owns each is named)
# --------------------------------------------------------------------------------------------------------------
CATCHES_PER_HOUR = 180  # design assumption, issue #279 / map #393 Notes (not measured)
MIN_PER_CATCH = 60.0 / CATCHES_PER_HOUR

NOTICE_PAY = (10, 15, 20)  # addons/Pagle_TackleBoard/logic/Rewards.lua:200, TKB-R34
EXPEDITION_PAY = 60  # Rewards.lua:203
NOTICE_XP = (100, 150, 200)  # TKB-R65
EXPEDITION_XP = 600
NOTICES_PER_RESET = 3  # TKB-R20
NOTICE_CAP = 6
EXPEDITIONS_PER_WEEK = 1
EXPEDITION_CAP = 2
START_OWED = (3, 1)  # TKB-R20: the start record sets owedNotices = 3, owedExpeditions = 1
RECENT_WEIGHT, RECENT_DAYS = 8, 14  # TKB-R30 / Tunables
CAMPFIRE_MILESTONES = ((7, 25), (30, 75), (100, 200), (365, 500))  # Rewards.lua:207-212
KINDLING_START, KINDLING_CAP, KINDLING_EVERY = 2, 3, 7  # Rewards.lua:217-222

NOTICE_KIND_WEIGHT = {"haul": 2, "variety": 2, "wanderer": 1, "quality": 1, "collector": 1, "lure": 1, "species": 1}
EXPEDITION_KIND_WEIGHT = {"haul": 1, "variety": 1, "wanderer": 1, "quality": 1, "collector": 1}  # TKB-R32
HAUL_NEED = (20, 30, 40)  # TKB-R34
QUALITY_NEED = (3, 5, 8)
LURE_NEED = (15, 20, 25)
SPECIES_NEED = (5, 10, 15)

EVENT_TIER1_PAY, EVENT_TIER_PAY, EVENT_RUN_PAY = 15, 10, 50  # HNT-R110
EVENT_TIER1_XP, EVENT_TIER_XP, EVENT_RUN_XP = 150, 100, 250  # HNT-R114
EVENT_SLOT_DAYS = 3  # 72 h runs, HNT-R152
LURE_REACH = 100  # HNT-R33 Tunables

LEVEL_UP_COINS, PRESTIGE_COINS = 20, 100  # Fold.lua:166, LED-R88
LEVEL_COST = lambda level: 1000 + 80 * level  # LED-R30: cost of going from `level` to `level + 1`  # noqa: E731
LEVEL_CAP = 60
CATCH_XP = 10  # LED-R20
FRESH_RATE_PER_H, FRESH_CAP = 10, 300  # LED-R22 Tunables

STANDING_HUNT_POT = 1000  # data/hunts/hunts.toml: 12 Hunts, 28 tiers -> 12*30 + 16*15 = 600, 4 sets * 100 = 400

CITIES = {1519, 1537, 1637, 1638, 1657}  # Stormwind, Ironforge, Orgrimmar, Thunder Bluff, Darnassus (areas.csv)
OPEN_CONTINENTS = (0, 1)  # TKB-R36 continent name map: 0 Eastern Kingdoms, 1 Kalimdor

# --------------------------------------------------------------------------------------------------------------
# ASSUMPTIONS (modelling choices; each is a parameter of Params below)
# --------------------------------------------------------------------------------------------------------------
ASSUMPTIONS = """
A1  180 Catches per fishing hour, every Cast a Catch (a design figure, #279). One Catch = 1/3 minute.
A2  Loot per zone = the mean over the zone's areas that have a loot table (the propose-events 'fishing round the
    zones' rule). Gated catch entries are weighted by the average open share of their window (time of day, season);
    event-gated ones count 0. Catches not on the area's catch list are an unlisted remainder: they count for Haul,
    Lure and Wanderer only (like item 0).
A3  Skill: the reference player has base skill 300 (every zone with a skill base up to 205 is a Notice candidate;
    the base-330 zones are not, TKB-R30) and a lure within reach (HNT-R33), so all 24 events can be fished.
    Sensitivities run skill 75 and 150.
A4  Travel: changing zone costs hop_min minutes (casual and dedicated 5, min-maxed 2); instances cost 10 more,
    cities 0 more. Zones are the Notice targets; the generator draws instance 'zones' (Wailing Caverns, Deadmines,
    ...) like any other zone, and so does this model.
A5  Lures: a player puts a lure on whenever a Lure Notice is open (it only needs 15-25 lured Catches).
A6  Play policy: a greedy planner. Every 30 Catches it picks the zone with the highest expected coins of goal
    progress over the next ~90 Catches (30 min), net of the hop cost, counting every open goal and the current
    event's Hunts at once (a Catch counts toward all of them). It quits for the day when the best chunk is worth
    under 1 coin. Goals are never taken down, except for the min-maxed player (see A8).
A7  Hunt Events: one run per 72 h slot, bands cycle low, mid, high, picks inside a band are shuffled passes
    (HNT-R152 without the FNV seed). A timed Hunt counts only Catches inside its daily window: the casual and
    dedicated player fish at random clock times (counts with probability window/24 h); the min-maxed player starts
    each day's event fishing at the window.
A8  Min-maxed player: takes down (rerolls, once) any new goal whose standalone value is under 0.6 coins per minute
    of expected work, hops in 2 minutes, aligns timed Hunts. Same 180 Catches per hour.
A9  The player plays on a given day with probability p_play (1.0 headline). A day is lit when a goal completes.
A10 Activity XP converts to coins only through level-ups: marginal value (59*20 + 100) / 200,600 XP per Prestige
    loop (LED-R30, LED-R88), computed in the output, not simulated.
"""


# --------------------------------------------------------------------------------------------------------------
# WORLD: zones, items, events
# --------------------------------------------------------------------------------------------------------------
def _season_fraction(spec) -> float:
    def doy(m, d):
        return sum((31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[: m - 1]) + d

    total = 0
    for r in spec:
        a, b = doy(*r["from"]), doy(*r["to"])
        total += (b - a + 1) % 365 or 365
    return min(1.0, total / 365)


def open_fraction(spec: dict) -> float:
    """Average open share of a window over a year / a day (time + season factors; event-gated windows count 0)."""
    if "events" in spec:
        return 0.0
    frac = 1.0
    if "time" in spec:
        frac *= min(1.0, sum(((e - s) % 1440 or 1440) for s, e in spec["time"]) / 1440)
    if "season" in spec:
        frac *= _season_fraction(spec["season"])
    return frac


@dataclass
class Item:
    id: int
    noise: bool
    category: str
    quality: int | None
    species: int | None
    legend: bool
    removed: bool

    @property
    def sub(self) -> bool:  # TKB-R46 Sub-collection item
        return self.category in ("junk", "container", "treasure", "trophy") and not self.noise and not self.removed


@dataclass
class Zone:
    id: int
    name: str
    continent: int
    skill: int
    kind: str  # open | city | instance
    items: list = field(default_factory=list)  # item ids (0 = unlisted remainder)
    cum: list = field(default_factory=list)
    share: dict = field(default_factory=dict)  # item -> probability per Catch
    eligible_species: dict = field(default_factory=dict)  # species -> representative item (TKB-R31)
    species_share: dict = field(default_factory=dict)  # species -> probability per Catch (any entry, gated incl.)
    catch_items: set = field(default_factory=set)  # every item on the zone's catch lists (gated included)
    q2: float = 0.0
    q3: float = 0.0
    junk: float = 0.0
    container: float = 0.0
    sub_share: dict = field(default_factory=dict)  # sub-collection item -> probability


@dataclass
class Hunt:
    id: str
    members: frozenset
    tiers: tuple
    window_min: int | None  # daily window length in minutes (timed Hunts), else None


@dataclass
class Event:
    id: str
    zones: tuple
    hunts: list
    need: int
    band: str


class World:
    def __init__(self) -> None:
        layers = read_layers(ROOT)
        self.layers = layers
        areas = layers.db2.areas
        base = loot_shares(ROOT)
        wopen = {w: open_fraction(spec) for w, spec in layers.windows.items()}
        self.items = {
            i: Item(i, r.get("noise") is True, r.get("category", "other"), r.get("quality"), r.get("species"),
                    r.get("legend") is True, r.get("removed") is True)
            for i, r in layers.items.items()
        }
        skills = layers.catch_lists.skill_bases
        by_zone: dict[int, list[int]] = defaultdict(list)
        for a in layers.catch_lists.lists:
            z = zone_of(areas, a)
            if z is not None:
                by_zone[z].append(a)
        self.zones: dict[int, Zone] = {}
        for zid, sk in skills.items():
            if areas[zid].parent != 0 or zid not in by_zone:
                continue
            kind = "city" if zid in CITIES else ("open" if areas[zid].continent in OPEN_CONTINENTS else "instance")
            z = Zone(zid, areas[zid].name, areas[zid].continent, sk, kind)
            per_area = []
            for a in by_zone[zid]:
                found: dict[int, float] = {}
                for c in layers.catch_lists.lists[a]:
                    z.catch_items.add(c.item)
                    sh = base.get(a, {}).get(c.item, 0.0)
                    if c.window is not None:
                        sh *= wopen.get(c.window, 0.0)
                    if sh > 0:
                        found[c.item] = found.get(c.item, 0.0) + sh
                if found:
                    per_area.append(found)
                for c in layers.catch_lists.lists[a]:
                    it = self.items.get(c.item)
                    if (c.window is None and it and it.category == "fish" and not it.legend and not it.noise
                            and not it.removed and it.species is not None):
                        rep = z.eligible_species.get(it.species)
                        if rep is None or c.item < rep:
                            z.eligible_species[it.species] = c.item
            if not per_area:
                continue
            n = len(per_area)
            for found in per_area:
                for item, sh in found.items():
                    z.share[item] = z.share.get(item, 0.0) + sh / n
            total = sum(z.share.values())
            if total > 1:
                z.share = {k: v / total for k, v in z.share.items()}
                total = 1.0
            z.share[0] = max(0.0, 1.0 - total)
            z.items = list(z.share)
            acc = 0.0
            for item in z.items:
                acc += z.share[item]
                z.cum.append(acc)
            for item, p in z.share.items():
                it = self.items.get(item)
                if not it or it.noise:
                    continue
                if it.species is not None:
                    z.species_share[it.species] = z.species_share.get(it.species, 0.0) + p
                if it.quality is not None and it.quality >= 2:
                    z.q2 += p
                if it.quality is not None and it.quality >= 3:
                    z.q3 += p
                if it.category == "junk":
                    z.junk += p
                if it.category == "container":
                    z.container += p
                if it.sub:
                    z.sub_share[item] = p
            self.zones[zid] = z
        # events
        classes = hunt_classes(layers.hunts, layers.items, layers.lock.classes)
        by_species: dict[int, set] = defaultdict(set)
        for i, r in layers.items.items():
            if r.get("species") is not None:
                by_species[r["species"]].add(i)
        self.events: list[Event] = []
        for path in sorted((ROOT / "data/hunts/events").glob("*.toml")):
            d = tomllib.loads(path.read_text(encoding="utf-8"))
            hunts = []
            for h in d["hunt"]:
                members = frozenset(classes[h["class"]]) if "class" in h else frozenset(by_species[h["species"]])
                wm = None
                if "conditions" in h and "time" in h["conditions"]:
                    wm = sum(((e - s) % 1440 or 1440) for s, e in h["conditions"]["time"])
                hunts.append(Hunt(h["id"], members, tuple(h["tiers"]), wm))
            zs = tuple(d["event"]["zones"])
            need = min(self.zones[z].skill for z in zs)
            self.events.append(Event(d["event"]["id"], zs, hunts, need, band_of(need)))
        self.bands = {b: [e for e in self.events if e.band == b] for b in ("low", "mid", "high")}


# --------------------------------------------------------------------------------------------------------------
# PARAMETERS
# --------------------------------------------------------------------------------------------------------------
@dataclass
class Params:
    name: str = "casual"
    hours: float = 1.5
    hop_min: float = 5.0
    instance_extra_min: float = 10.0
    skill: int = 300
    reroll_max_min: float | None = 240.0  # take a new goal down once if it would take longer than this to finish alone
    reroll_floor: float = 0.0  # ... or pays under this many coins per expected minute (min-maxed: 0.6)
    align_timed: bool = False
    events_on: bool = True
    board_on: bool = True
    p_play: float = 1.0
    stop_value: float = 1.0  # coins per 90-Catch chunk below which the player stops for the day
    chunk: int = 30
    horizon: int = 90


# --------------------------------------------------------------------------------------------------------------
# SIMULATION
# --------------------------------------------------------------------------------------------------------------
class Goal:
    __slots__ = ("type", "kind", "tier", "pay", "need", "zone", "species", "stored", "progress", "seen", "pday",
                 "reposted", "cost")

    def __init__(self, type_, kind, tier, pay, need, zone=None, species=None, stored=None):
        self.type, self.kind, self.tier, self.pay, self.need = type_, kind, tier, pay, need
        self.zone, self.species, self.stored = zone, species, stored
        self.progress = 0
        self.seen: set = set()
        self.pday = -1
        self.reposted = False
        self.cost = 0.0


class Sim:
    def __init__(self, world: World, p: Params, rng: random.Random, days: int):
        self.w, self.p, self.rng, self.days = world, p, rng, days
        self.cand = [z for z in world.zones.values() if z.skill <= p.skill]
        self.fishable = [z for z in world.zones.values() if z.skill <= p.skill + LURE_REACH]
        self.cand_ids = {z.id for z in self.cand}
        self.open: list[Goal] = []
        self.owed = [0, 0]
        self.recent: dict[int, int] = {}
        self.caught: set = set()
        self.cur = None
        self.fire = {"count": 0, "kindling": KINDLING_START, "milestones": set(), "log": {}}
        self.day = 0
        self.lit = False
        # event state
        self.run = None
        self.pass_order: dict[str, list] = {}
        self.pass_pos: dict[str, int] = defaultdict(int)
        self.ev_min_today = 0.0
        # day record
        self.rec: dict = {}
        # continents with >= 5 candidate zones (TKB-R32 Wanderer Expedition)
        cnt = Counter(z.continent for z in self.cand if z.continent in OPEN_CONTINENTS)
        self.wander_conts = [c for c, n in cnt.items() if n >= 5]

    # ----- goal generation (TKB-R30..R36) -----------------------------------------------------------------
    def _zone_weight(self, z: Zone) -> int:
        last = self.recent.get(z.id)
        return RECENT_WEIGHT if last is not None and self.day - last <= RECENT_DAYS else 1

    def _eligible(self, typ: str, kind: str) -> bool:
        c = self.cand
        if kind == "haul":
            return bool(c)
        if kind == "variety":
            lo, hi = (3, 10**9) if typ == "n" else (4, 12)
            return any(lo <= len(z.eligible_species) <= hi for z in c)
        if kind == "wanderer":
            return True if typ == "n" else bool(self.wander_conts)
        if kind == "quality":
            return True
        if kind == "collector":
            if typ == "n":
                return True
            pool = set()
            for z in c:
                pool |= {i for i in z.catch_items if (it := self.w.items.get(i)) and it.sub}
            return len(pool - self.caught) >= 6
        if kind == "lure":
            return typ == "n"
        if kind == "species":
            return typ == "n" and any(z.eligible_species for z in c)
        return False

    def gen_goal(self, typ: str, exclude_kind: str | None = None, force_kind: str | None = None) -> Goal:
        weights = NOTICE_KIND_WEIGHT if typ == "n" else EXPEDITION_KIND_WEIGHT
        openk = {g.kind for g in self.open if g.type == typ}
        kinds = [k for k in weights if k != exclude_kind and self._eligible(typ, k)]
        pick = [k for k in kinds if k not in openk] or kinds
        kind = force_kind or self.rng.choices(pick, [weights[k] for k in pick])[0]
        rng = self.rng
        tier = rng.randint(1, 3) if typ == "n" else 0

        def draw_zone(ok):
            zs = [z for z in self.cand if ok(z)]
            taken = {g.zone for g in self.open if g.type == typ and g.kind == kind}
            free = [z for z in zs if z.id not in taken]
            zs = free or zs
            return rng.choices(zs, [self._zone_weight(z) for z in zs])[0]

        if kind == "haul":
            z = draw_zone(lambda z: True)
            need = HAUL_NEED[tier - 1] if typ == "n" else 150
            g = Goal(typ, kind, tier, 0, need, zone=z.id)
        elif kind == "variety":
            if typ == "n":
                z = draw_zone(lambda z: len(z.eligible_species) >= 3)
                need = min(2 + tier, len(z.eligible_species))
                tier = need - 2
                g = Goal(typ, kind, tier, 0, need, zone=z.id)
            else:
                z = draw_zone(lambda z: 4 <= len(z.eligible_species) <= 12)
                stored = frozenset(z.eligible_species)
                g = Goal(typ, kind, 0, 0, len(stored), zone=z.id, stored=stored)
        elif kind == "wanderer":
            if typ == "n":
                tier = 3
                g = Goal(typ, kind, 3, 0, 3)
            else:
                taken = {x.zone for x in self.open if x.type == "e" and x.kind == "wanderer"}
                cs = [c for c in self.wander_conts if c not in taken] or self.wander_conts
                g = Goal(typ, kind, 0, 0, 5, zone=rng.choice(cs))  # zone field holds the continent
        elif kind == "quality":
            need = QUALITY_NEED[tier - 1] if typ == "n" else 3
            g = Goal(typ, kind, tier, 0, need, species=2 if typ == "n" else 3)  # species field holds min quality
        elif kind == "collector":
            if typ == "n":
                tier = 2
                g = Goal(typ, kind, 2, 0, 2)
            else:
                g = Goal(typ, kind, 0, 0, 3)
        elif kind == "lure":
            g = Goal(typ, kind, tier, 0, LURE_NEED[tier - 1])
        else:  # species
            z = draw_zone(lambda z: bool(z.eligible_species))
            takenspecies = {x.species for x in self.open if x.kind == "species"}
            sp = [s for s in z.eligible_species if s not in takenspecies] or list(z.eligible_species)
            g = Goal(typ, kind, tier, 0, SPECIES_NEED[tier - 1], species=rng.choice(sorted(sp)))
        g.pay = NOTICE_PAY[g.tier - 1] if typ == "n" else EXPEDITION_PAY
        return g

    # ----- rates and planning -----------------------------------------------------------------------------
    def _remaining(self, g: Goal) -> int:
        if g.kind in ("wanderer", "collector") and g.type == "n" and g.pday != self.day:
            return g.need
        return max(1, g.need - g.progress)

    def goal_rate(self, g: Goal, z: Zone) -> float:
        """Expected progress per Catch in zone z (0 if the Catch can't count)."""
        k = g.kind
        if k == "haul":
            return 1.0 if z.id == g.zone else 0.0
        if k == "variety":
            if z.id != g.zone:
                return 0.0
            if g.type == "n":
                return sum(p for s, p in z.species_share.items() if s not in g.seen)
            return sum(z.species_share.get(s, 0.0) for s in g.stored if s not in g.seen)
        if k == "quality":
            return z.q2 if g.species == 2 else z.q3
        if k == "lure":
            return 1.0
        if k == "species":
            return z.species_share.get(g.species, 0.0)
        if k == "collector":
            if g.type == "n":
                seen = g.seen if g.pday == self.day else set()
                return (z.junk if "junk" not in seen else 0.0) + (z.container if "container" not in seen else 0.0)
            return sum(p for i, p in z.sub_share.items() if i not in self.caught and i not in g.seen)
        return 0.0

    def goal_value(self, g: Goal, z: Zone, eff: float) -> float:
        rem = self._remaining(g)
        if g.kind == "wanderer":
            seen = g.seen if (g.type == "e" or g.pday == self.day) else set()
            if z.id in seen:
                return 0.0
            if g.type == "e" and z.continent != g.zone:
                return 0.0
            return g.pay * min(1.0, 1.0 / rem)
        if g.kind == "collector" and g.type == "n" and g.pday != self.day:
            pass
        return g.pay * min(1.0, self.goal_rate(g, z) * eff / rem)

    def event_active_for(self, z: Zone) -> bool:
        return self.run is not None and z.id in self.run["event"].zones

    def event_value(self, z: Zone, eff: float) -> float:
        if not self.event_active_for(z):
            return 0.0
        run = self.run
        zero = sum(1 for h in run["state"] if h["tier"] == 0)
        v = 0.0
        for h, s in zip(run["event"].hunts, run["state"]):
            k = s["tier"]
            if k >= len(h.tiers):
                continue
            rate = sum(p for i, p in z.share.items() if i in h.members)
            if h.window_min is not None:
                if self.p.align_timed:
                    rate *= 1.0 if self.ev_min_today < h.window_min else 0.0
                else:
                    rate *= h.window_min / 1440
            rem = max(1, h.tiers[k] - s["count"])
            pay = EVENT_TIER1_PAY if k == 0 else EVENT_TIER_PAY
            if k == 0 and zero:
                pay += EVENT_RUN_PAY / zero
            v += pay * min(1.0, rate * eff / rem)
        return v

    def hop_catches(self, z: Zone) -> float:
        if self.cur is not None and z.id == self.cur:
            return 0.0
        minutes = self.p.hop_min + (self.p.instance_extra_min if z.kind == "instance" else 0.0)
        return minutes / MIN_PER_CATCH

    def plan(self, budget_catches: float | None = None):
        """The zone with the most expected goal progress (in coins) over the next chunk of fishing, net of the hop,
        and that value; the chunk is the planning horizon, or what is left of today's time if that is shorter."""
        best, bz = 0.0, None
        horizon = self.p.horizon if budget_catches is None else min(self.p.horizon, budget_catches)
        goals = self.open
        for z in self.fishable:
            eff = horizon - self.hop_catches(z)
            if eff <= 0:
                continue
            v = sum(self.goal_value(g, z, eff) for g in goals)
            v += self.event_value(z, eff)
            if v > best:
                best, bz = v, z
        return bz, best

    # ----- catching -----------------------------------------------------------------------------------------
    def fish(self, z: Zone, n: int) -> None:
        self.cur = z.id
        self.recent[z.id] = self.day
        picks = self.rng.choices(z.items, cum_weights=z.cum, k=n)
        lure_on = any(g.kind == "lure" for g in self.open)
        ev_here = self.event_active_for(z)
        for item in picks:
            self.catch(z, item, lure_on)
            if ev_here:
                self.event_catch(item)
                self.ev_min_today += MIN_PER_CATCH
            self.caught.add(item)

    def catch(self, z: Zone, item: int, lure_on: bool) -> None:
        it = self.w.items.get(item)
        known = it is not None
        done = []
        for g in self.open:
            k = g.kind
            if k == "haul":
                if z.id == g.zone:
                    g.progress += 1
            elif k == "lure":
                if lure_on:
                    g.progress += 1
            elif k == "wanderer":
                if g.type == "n":
                    if g.pday != self.day:
                        g.pday, g.seen = self.day, set()
                    g.seen.add(z.id)
                    g.progress = len(g.seen)
                elif z.continent == g.zone:
                    g.seen.add(z.id)
                    g.progress = len(g.seen)
            elif not known:
                continue
            elif k == "variety":
                if z.id == g.zone and it.species is not None and not it.noise:
                    if g.type == "n":
                        g.seen.add(it.species)
                    elif it.species in g.stored:
                        g.seen.add(it.species)
                    g.progress = len(g.seen)
            elif k == "quality":
                if not it.noise and it.quality is not None and it.quality >= g.species:
                    g.progress += 1
            elif k == "collector":
                if g.type == "n":
                    if g.pday != self.day:
                        g.pday, g.seen = self.day, set()
                    if not it.noise and it.category in ("junk", "container"):
                        g.seen.add(it.category)
                        g.progress = len(g.seen)
                elif it.sub and item not in self.caught:
                    g.seen.add(item)
                    g.progress = len(g.seen)
            elif k == "species":
                if it.species is not None and it.species == g.species and not it.noise:
                    g.progress += 1
            if g.progress >= g.need:
                done.append(g)
        for g in done:
            self.open.remove(g)
            key = "notice" if g.type == "n" else "expedition"
            self.rec[key + "_coins"] += g.pay
            self.rec[key + "_n"] += 1
            self.rec["xp_board"] += NOTICE_XP[g.tier - 1] if g.type == "n" else EXPEDITION_XP
            self.lit = True

    def event_catch(self, item: int) -> None:
        run = self.run
        for h, s in zip(run["event"].hunts, run["state"]):
            if item not in h.members:
                continue
            if h.window_min is not None:
                if self.p.align_timed:
                    if self.ev_min_today >= h.window_min:
                        continue
                elif self.rng.random() >= h.window_min / 1440:
                    continue
            s["count"] += 1
            while s["tier"] < len(h.tiers) and s["count"] >= h.tiers[s["tier"]]:
                first = s["tier"] == 0
                s["tier"] += 1
                self.rec["event_coins"] += EVENT_TIER1_PAY if first else EVENT_TIER_PAY
                self.rec["xp_event"] += EVENT_TIER1_XP if first else EVENT_TIER_XP
        if not run["done"] and all(s["tier"] >= 1 for s in run["state"]):
            run["done"] = True
            self.rec["event_coins"] += EVENT_RUN_PAY
            self.rec["event_run_coins"] += EVENT_RUN_PAY
            self.rec["xp_event"] += EVENT_RUN_XP
            self.rec["runs_done"] += 1

    # ----- days ---------------------------------------------------------------------------------------------
    def _accessible(self, e: Event) -> bool:
        return e.need <= self.p.skill + LURE_REACH

    def _next_event(self, slot: int):
        band = ("low", "mid", "high")[slot % 3]
        visit = slot // 3
        pool = sorted(self.w.bands[band], key=lambda e: e.id)
        passno, pos = divmod(visit, len(pool))
        if passno not in self.pass_order.setdefault(band, {}):
            order = pool[:]
            self.rng.shuffle(order)
            self.pass_order[band][passno] = order
        return self.pass_order[band][passno][pos]

    def start_day(self, d: int) -> None:
        self.day = d
        self.lit = False
        self.ev_min_today = 0.0
        self.rec = defaultdict(float)
        if self.p.board_on:
            if d == 0:
                self.owed = list(START_OWED)
            else:
                self.owed[0] += max(0, min(NOTICES_PER_RESET, NOTICE_CAP - sum(1 for g in self.open if g.type == "n") - self.owed[0]))
                if d % 7 == 0:
                    self.owed[1] += max(0, min(EXPEDITIONS_PER_WEEK, EXPEDITION_CAP - sum(1 for g in self.open if g.type == "e") - self.owed[1]))
            while self.owed[1] > 0:
                self.open.append(self._issue("e"))
                self.owed[1] -= 1
            while self.owed[0] > 0:
                self.open.append(self._issue("n"))
                self.owed[0] -= 1
        if self.p.events_on and d % EVENT_SLOT_DAYS == 0:
            e = self._next_event(d // EVENT_SLOT_DAYS)
            if self._accessible(e):
                self.run = {"event": e, "state": [{"count": 0, "tier": 0} for _ in e.hunts], "done": False}
            else:
                self.run = None

    def standalone_cost_min(self, g: Goal) -> float:
        """Expected minutes to finish g alone in its best fishable zone (used by the reroll rule only)."""
        best = math.inf
        if g.kind == "wanderer":
            return g.need * (self.p.hop_min + MIN_PER_CATCH)
        for z in self.fishable:
            r = self.goal_rate(g, z)
            if r <= 0:
                continue
            extra = (self.p.hop_min + (self.p.instance_extra_min if z.kind == "instance" else 0)) if z.id != self.cur else 0
            need = g.need
            if g.kind == "variety" and g.type == "e":
                need = len(g.stored)
                ps = [z.species_share.get(s, 0.0) for s in g.stored]
                cat = 0.0
                n = len(ps)
                for mask in range(1, 1 << n):
                    s = sum(ps[i] for i in range(n) if mask >> i & 1)
                    cat += (-1) ** (bin(mask).count("1") + 1) / s if s > 0 else 0
                best = min(best, cat * MIN_PER_CATCH + extra)
                continue
            if g.kind == "variety":
                ps = sorted(z.species_share.values(), reverse=True)
                tot, cat, seen = sum(ps), 0.0, 0.0
                for j in range(min(need, len(ps))):
                    left = tot - seen
                    cat += 1.0 / left if left > 0 else 1e9
                    seen += ps[j]
                best = min(best, cat * MIN_PER_CATCH + extra)
                continue
            if g.kind == "collector":
                if g.type == "n":
                    cat = (1 / z.junk if z.junk > 0 else 1e9) + (1 / z.container if z.container > 0 else 1e9)
                    best = min(best, cat * MIN_PER_CATCH + extra)
                    continue
            best = min(best, g.need / r * MIN_PER_CATCH + extra)
        return best

    def _issue(self, typ: str) -> Goal:
        g = self.gen_goal(typ)
        if self.p.reroll_max_min is not None or self.p.reroll_floor > 0:
            cost = self.standalone_cost_min(g)
            too_long = self.p.reroll_max_min is not None and cost > self.p.reroll_max_min
            too_poor = self.p.reroll_floor > 0 and g.pay / max(cost, 0.01) < self.p.reroll_floor
            if too_long or too_poor:
                g = self.gen_goal(typ, exclude_kind=g.kind)
                g.reposted = True  # the new goal can't be taken down (TKB-R55)
        return g

    def session(self) -> None:
        minutes = self.p.hours * 60.0
        used = 0.0
        while minutes - used > MIN_PER_CATCH * 3:
            z, v = self.plan((minutes - used) / MIN_PER_CATCH)
            if z is None or v < self.p.stop_value:
                break
            hop = self.hop_catches(z) * MIN_PER_CATCH
            if hop > 0:
                if minutes - used < hop + MIN_PER_CATCH * 3:
                    break
                used += hop
            n = min(self.p.chunk, int((minutes - used) / MIN_PER_CATCH))
            if n <= 0:
                break
            self.fish(z, n)
            used += n * MIN_PER_CATCH
        self.rec["hours_used"] = used / 60.0

    def close_day(self) -> None:
        f = self.fire
        if self.lit:
            f["count"] += 1
            if f["count"] % KINDLING_EVERY == 0:
                f["kindling"] = min(KINDLING_CAP, f["kindling"] + 1)
            for days, coins in CAMPFIRE_MILESTONES:
                if f["count"] == days and days not in f["milestones"]:
                    f["milestones"].add(days)
                    self.rec["campfire_coins"] += coins
        elif f["count"] > 0:
            if f["kindling"] > 0:
                f["kindling"] -= 1
            else:
                f["count"], f["kindling"] = 0, KINDLING_START
        self.rec["fire_count"] = f["count"]
        self.rec["lit"] = 1.0 if self.lit else 0.0
        self.rec["open_n"] = sum(1 for g in self.open if g.type == "n")
        self.rec["open_e"] = sum(1 for g in self.open if g.type == "e")

    def run_days(self) -> list[dict]:
        out = []
        for d in range(self.days):
            self.start_day(d)
            if self.rng.random() < self.p.p_play:
                self.session()
            self.close_day()
            out.append({f: self.rec.get(f, 0.0) for f in FIELDS} | {"fire_count": self.rec.get("fire_count", 0)})
        return out


# --------------------------------------------------------------------------------------------------------------
# ANALYSES
# --------------------------------------------------------------------------------------------------------------
FIELDS = ["notice_coins", "expedition_coins", "event_coins", "campfire_coins", "xp_board", "xp_event", "hours_used",
          "notice_n", "expedition_n", "runs_done", "event_run_coins", "open_n", "open_e", "lit"]


def run_many(world: World, p: Params, seeds: int, days: int, base_seed: int = 1000):
    runs = []
    for s in range(seeds):
        sim = Sim(world, p, random.Random(base_seed + s), days)
        runs.append(sim.run_days())
    return runs


def steady(runs, lo: int, hi: int) -> dict:
    """Mean per-day values over days [lo, hi) averaged over runs, with the across-run p10/p90 of the total."""
    out = {}
    for f in FIELDS:
        per_run = [sum(r.get(f, 0.0) for r in run[lo:hi]) / (hi - lo) for run in runs]
        out[f] = statistics.fmean(per_run)
        out[f + "_sd"] = statistics.pstdev(per_run) if len(per_run) > 1 else 0.0
    out["coins"] = out["notice_coins"] + out["expedition_coins"] + out["event_coins"]
    out["coins_total"] = out["coins"] + out["campfire_coins"]
    tot = sorted(sum(r["notice_coins"] + r["expedition_coins"] + r["event_coins"] for r in run[lo:hi]) / (hi - lo)
                 for run in runs)
    out["coins_p10"], out["coins_p90"] = tot[int(0.1 * (len(tot) - 1))], tot[int(0.9 * (len(tot) - 1))]
    return out


def first_days(runs, n: int) -> dict:
    out = {}
    for f in FIELDS:
        out[f] = statistics.fmean(sum(r.get(f, 0.0) for r in run[:n]) for run in runs)
    return out


def campfire_sim(p_play: float, seeds: int, days: int = 730, base_seed: int = 5000) -> dict:
    """Campfire only (TKB-R70..R74): a played day is lit (a goal is always open and done), an unplayed day is not."""
    reach = {m: [] for m, _ in CAMPFIRE_MILESTONES}
    for s in range(seeds):
        rng = random.Random(base_seed + s)
        count, kind, got = 0, KINDLING_START, set()
        for d in range(days):
            if rng.random() < p_play:
                count += 1
                if count % KINDLING_EVERY == 0:
                    kind = min(KINDLING_CAP, kind + 1)
                for m, _ in CAMPFIRE_MILESTONES:
                    if count == m and m not in got:
                        got.add(m)
                        reach[m].append(d + 1)
            elif count > 0:
                if kind > 0:
                    kind -= 1
                else:
                    count, kind = 0, KINDLING_START
    res = {}
    for m, coins in CAMPFIRE_MILESTONES:
        r = reach[m]
        res[m] = {"coins": coins, "p_by_730d": len(r) / seeds, "median_day": statistics.median(r) if r else None}
    return res


def solo_costs(world: World, n_notice: int = 1400, n_exp: int = 300, seed: int = 77) -> list[dict]:
    """Per (type, kind, tier): stand-alone cost to finish one goal in its best zone (greedy planner, 5-min hops),
    fresh board, no other goals. Minutes of fishing + hops. Caps at 600 minutes (reported as capped)."""
    rows = defaultdict(list)
    p = Params(name="solo", hours=24, hop_min=5.0, events_on=False)
    rng = random.Random(seed)
    for typ, count in (("n", n_notice), ("e", n_exp)):
        kinds = NOTICE_KIND_WEIGHT if typ == "n" else EXPEDITION_KIND_WEIGHT
        for kind in kinds:
            per = max(1, int(count * kinds[kind] / sum(kinds.values())))
            for _ in range(per):
                sim = Sim(world, p, random.Random(rng.random()), 1)
                sim.start_day(0)
                sim.open = []
                sim.owed = [0, 0]
                # a typical board has recent zones: fish a random zone for a day first so the weights are realistic
                for _ in range(rng.randint(0, 3)):
                    z = rng.choice(sim.cand)
                    sim.recent[z.id] = 0
                if not sim._eligible(typ, kind):
                    continue
                g = sim.gen_goal(typ, force_kind=kind)
                sim.open = [g]
                sim.rec = defaultdict(float)
                used = 0.0
                cap = 600.0
                while sim.open and used < cap:
                    z, v = sim.plan()
                    if z is None:
                        used = cap
                        break
                    hop = sim.hop_catches(z) * MIN_PER_CATCH
                    used += hop
                    sim.fish(z, 10)
                    used += 10 * MIN_PER_CATCH
                rows[(typ, kind, g.tier)].append((used, g.pay, g.need, sim.rec["notice_coins" if typ == "n" else "expedition_coins"] > 0))
    out = []
    for (typ, kind, tier), vals in sorted(rows.items()):
        mins = [v[0] for v in vals]
        done = [v[3] for v in vals]
        out.append({
            "type": "Notice" if typ == "n" else "Expedition", "kind": kind, "tier": tier, "n": len(vals),
            "pay": statistics.fmean(v[1] for v in vals), "need": statistics.fmean(v[2] for v in vals),
            "minutes_mean": statistics.fmean(mins), "minutes_median": statistics.median(mins),
            "minutes_p90": sorted(mins)[int(0.9 * (len(mins) - 1))],
            "capped": 1.0 - sum(done) / len(done),
        })
    return out


def event_table(world: World) -> list[dict]:
    """Per event: hunts, run max pay, and the expected hours to reach tier 1/2/3 of the slowest Hunt (all Hunts at
    once, fishing the best zone, random clock times and aligned)."""
    rows = []
    for e in world.events:
        z = max((world.zones[z] for z in e.zones), key=lambda z: sum(p for i, p in z.share.items() if i in e.hunts[0].members))
        row = {"event": e.id, "band": e.band, "zones": "+".join(world.zones[x].name for x in e.zones), "hunts": len(e.hunts),
               "max_pay": EVENT_RUN_PAY + len(e.hunts) * (EVENT_TIER1_PAY + 2 * EVENT_TIER_PAY),
               "tier1_pay": EVENT_RUN_PAY + len(e.hunts) * EVENT_TIER1_PAY}
        for label, aligned in (("random", False), ("aligned", True)):
            for k in range(3):
                worst = 0.0
                for h in e.hunts:
                    share = sum(p for i, p in z.share.items() if i in h.members)
                    if h.window_min is not None:
                        share *= 1.0 if aligned else h.window_min / 1440
                    t = h.tiers[k] / (share * CATCHES_PER_HOUR) if share > 0 else math.inf
                    if aligned and h.window_min is not None:
                        pass
                    worst = max(worst, t)
                row[f"h_tier{k + 1}_{label}"] = worst
        rows.append(row)
    return rows


def xp_value_per_coin() -> dict:
    """Marginal coins per Activity XP (a full climb pays 59 level-ups, then a Prestige 100)."""
    climb_xp = sum(LEVEL_COST(l) for l in range(1, LEVEL_CAP))
    coins = (LEVEL_CAP - 1) * LEVEL_UP_COINS + PRESTIGE_COINS
    return {"climb_xp": climb_xp, "coins_per_climb": coins, "coins_per_xp": coins / climb_xp,
            "level1_coins_per_xp": LEVEL_UP_COINS / LEVEL_COST(1), "level59_coins_per_xp": LEVEL_UP_COINS / LEVEL_COST(59)}


def catch_xp_per_day(hours: float, sessions_gap_h: float | None = None) -> float:
    """Ledger Catch XP per day with Fresh Water (LED-R22): +10 F per real hour since the last Catch, cap 300, spent
    one per Catch. One session a day -> the gap is 24 - hours."""
    catches = hours * CATCHES_PER_HOUR
    gap = (24 - hours) if sessions_gap_h is None else sessions_gap_h
    fresh = min(FRESH_CAP, FRESH_RATE_PER_H * gap)
    return (catches + min(catches, fresh)) * CATCH_XP


def level_coins_by_day(xp_per_day: float, days: int) -> list[float]:
    """Cumulative level-up + Prestige coins by day for a flat XP income, following the climb cost (LED-R30)."""
    out, level, prog, coins = [], 1, 0.0, 0.0
    for _ in range(days):
        prog += xp_per_day
        while prog >= LEVEL_COST(level):
            prog -= LEVEL_COST(level)
            level += 1
            coins += LEVEL_UP_COINS
            if level == LEVEL_CAP:
                coins += PRESTIGE_COINS  # the player prestiges at once; carried XP ignored
                level = 1
        out.append(coins)
    return out


# --------------------------------------------------------------------------------------------------------------
# DRIVER
# --------------------------------------------------------------------------------------------------------------
def generator_mix(world: World, trials: int = 6000, seed: int = 31) -> dict:
    """The long-run kind mix and mean pay of issued goals (TKB-R32..R34): fresh boards with 0-2 other goals of the
    type open and 0-4 recently fished zones."""
    rng = random.Random(seed)
    p = Params(name="gen", events_on=False)
    mixc, paysum, cnt = Counter(), {"n": 0.0, "e": 0.0}, {"n": 0, "e": 0}
    sim = Sim(world, p, random.Random(seed + 1), 1)
    sim.start_day(0)
    for _ in range(trials):
        typ = "n" if rng.random() < 0.9 else "e"
        sim.recent = {rng.choice(sim.cand).id: 0 for _ in range(rng.randint(0, 4))}
        sim.open = []
        for _k in range(rng.randint(0, 2 if typ == "n" else 1)):
            sim.open.append(sim.gen_goal(typ))
        g = sim.gen_goal(typ)
        mixc[(typ, g.kind)] += 1
        paysum[typ] += g.pay
        cnt[typ] += 1
    return {"mean_pay": {"notice": paysum["n"] / cnt["n"], "expedition": paysum["e"] / cnt["e"]},
            "kind_mix": {f"{t}:{k}": c / cnt[t] for (t, k), c in sorted(mixc.items())}}


def fmt(x, nd=1):
    return f"{x:,.{nd}f}"


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        for r in rows:
            w.writerow({k: (round(v, 3) if isinstance(v, float) else v) for k, v in r.items()})


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--seeds", type=int, default=24)
    ap.add_argument("--days", type=int, default=210)
    args = ap.parse_args(argv)
    seeds = 4 if args.quick else args.seeds
    days = 90 if args.quick else args.days
    lo = 30 if not args.quick else 20
    world = World()
    tables = HERE / "tables"
    tables.mkdir(exist_ok=True)
    res: dict = {"assumptions": ASSUMPTIONS.strip()}

    # sanity: the event tier minutes the authors wrote (45 / 120 / 240 at 180 Catches/h) against this loot model
    ev_rows = event_table(world)
    write_csv(tables / "events.csv", ev_rows)
    res["events"] = ev_rows

    # zone facts
    zrows = []
    for z in sorted(world.zones.values(), key=lambda z: (z.skill, z.id)):
        zrows.append({"zone": z.id, "name": z.name, "kind": z.kind, "continent": z.continent, "skill_base": z.skill,
                      "eligible_species": len(z.eligible_species), "q_uncommon_plus": z.q2, "q_rare_plus": z.q3,
                      "junk": z.junk, "container": z.container, "unlisted_remainder": z.share.get(0, 0.0)})
    write_csv(tables / "zones.csv", zrows)

    # goal generator long-run mix (pay per issued goal), skill 300
    mix = generator_mix(world)
    res["mean_pay"], res["kind_mix"] = mix["mean_pay"], mix["kind_mix"]

    # stand-alone goal costs
    solo = solo_costs(world, 700 if args.quick else 1400, 150 if args.quick else 300)
    write_csv(tables / "goal_costs.csv", solo)
    res["solo"] = solo


    # scenarios: the three archetypes, plus a casual-hours min-maxer to show what play skill alone is worth
    scen = {
        "casual": Params(name="casual (1.5 h/day)", hours=1.5),
        "casual_minmax": Params(name="min-maxed play at 1.5 h/day", hours=1.5, hop_min=2.0, reroll_floor=0.6, align_timed=True),
        "dedicated": Params(name="dedicated (4 h/day)", hours=4.0),
        "minmax": Params(name="min-maxed (4 h/day)", hours=4.0, hop_min=2.0, reroll_floor=0.6, align_timed=True),
        # a new Angler who has not yet earned the skill: Notice zones up to skill+0, event zones up to skill+100 (A3)
        "casual_skill150": Params(name="casual, skill 150", hours=1.5, skill=150),
        "casual_skill75": Params(name="casual, skill 75", hours=1.5, skill=75),
    }
    checkpoints = [d for d in (1, 3, 7, 14, 30, 60, 90, 180) if d <= days]
    out = {}
    for key, p in scen.items():
        runs = run_many(world, p, seeds, days)
        cum = {}
        for d in checkpoints:
            cum[d] = statistics.fmean(
                sum(r["notice_coins"] + r["expedition_coins"] + r["event_coins"] + r["campfire_coins"] for r in run[:d])
                for run in runs)
        out[key] = {"steady": steady(runs, lo, days), "first90": first_days(runs, min(90, days)), "cum": cum,
                    "params": p.__dict__}
        print(key, "steady coins/day", fmt(out[key]["steady"]["coins"]), flush=True)
    res["scenarios"] = out

    # hours sweep (income vs hours/day), typical and min-maxed policy; board only / events only / both
    sweep = []
    hours_grid = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0]
    if args.quick:
        hours_grid = [0.5, 1.5, 4.0, 12.0]
    half = max(4, seeds // 2)
    for pol, base_p in (("typical", scen["casual"]), ("minmax", scen["minmax"])):
        for h in hours_grid:
            for mode, (bo, eo) in (("both", (True, True)), ("board", (True, False)), ("events", (False, True))):
                if pol == "minmax" and mode != "both":
                    continue
                p = Params(**{**base_p.__dict__, "hours": h, "board_on": bo, "events_on": eo})
                st = steady(run_many(world, p, half, days), lo, days)
                sweep.append({"policy": pol, "mode": mode, "hours": h, "coins_per_day": st["coins"],
                              "notice": st["notice_coins"], "expedition": st["expedition_coins"], "event": st["event_coins"],
                              "hours_used": st["hours_used"], "open_notices": st["open_n"], "open_exp": st["open_e"],
                              "xp_board": st["xp_board"], "xp_event": st["xp_event"]})
        print("sweep", pol, flush=True)
    write_csv(tables / "hours_sweep.csv", sweep)
    res["sweep"] = sweep

    # sensitivities
    sens = []

    def add(axis, value, hours, p, label=None):
        st = steady(run_many(world, p, half, days), lo, days)
        sens.append({"axis": axis, "value": value, "hours": hours, "coins_per_day": st["coins"],
                     "notice": st["notice_coins"], "expedition": st["expedition_coins"], "event": st["event_coins"],
                     "hours_used": st["hours_used"]})

    for skill in (75, 150, 300):
        for h in (1.5, 4.0):
            add("skill", skill, h, Params(hours=h, skill=skill))
    for hop in (2, 5, 10):
        add("hop_min", hop, 1.5, Params(hours=1.5, hop_min=hop))
    add("reroll", "never", 1.5, Params(hours=1.5, reroll_max_min=None))
    add("reroll", "only if >4h alone", 1.5, Params(hours=1.5))
    add("reroll", "also <0.6 coin/min", 1.5, Params(hours=1.5, reroll_floor=0.6))
    for al in (False, True):
        add("align_timed", int(al), 1.5, Params(hours=1.5, align_timed=al))
    for pp in (1.0, 6 / 7, 5 / 7, 4 / 7, 3 / 7, 2 / 7):
        add("p_play", round(pp, 3), 1.5, Params(hours=1.5, p_play=pp))
    for sv in (0.25, 1.0, 4.0):
        add("stop_value(12h budget)", sv, 12.0, Params(hours=12.0, stop_value=sv))
    add("instances_free", "instance hop = normal hop", 1.5, Params(hours=1.5, instance_extra_min=0.0))
    write_csv(tables / "sensitivity.csv", sens)
    res["sensitivity"] = sens

    # campfire alone
    cf = {}
    for pp in (1.0, 6 / 7, 5 / 7, 4 / 7):
        cf[f"{pp:.3f}"] = campfire_sim(pp, 400 if not args.quick else 60)
    res["campfire"] = cf

    # XP and the Ledger side
    res["xp"] = xp_value_per_coin()
    species = {it.species for it in world.items.values() if it.species is not None and not it.noise}
    curio = [it for it in world.items.values() if it.category in ("junk", "container", "treasure") and not it.noise]
    trophy = [it for it in world.items.values() if it.category == "trophy" and not it.noise]
    legends = [it for it in world.items.values() if it.legend]
    discovery = {"species": len(species), "curio_items": len(curio), "trophy_weights": len(trophy), "legends": len(legends),
                 "zones": len(world.zones)}
    discovery["pot_coins"] = (len(species) * 10 + len(curio) * 5 + len(trophy) * 5 + 100 * 3 + 30 * len(world.zones))
    res["discovery"] = discovery
    ledger = {}
    for key, rec in out.items():
        hrs = rec["params"]["hours"]
        st = rec["steady"]
        xp_catch = catch_xp_per_day(hrs)
        xp_act = st["xp_board"] + st["xp_event"]
        ledger[key] = {
            "catch_xp_per_day": xp_catch, "activity_xp_per_day": xp_act, "activity_xp_board": st["xp_board"],
            "activity_xp_event": st["xp_event"],
            "level_coins_90d_with": level_coins_by_day(xp_catch + xp_act, 90)[-1],
            "level_coins_90d_without": level_coins_by_day(xp_catch, 90)[-1],
            "level_coins_365d_with": level_coins_by_day(xp_catch + xp_act, 365)[-1],
            "level_coins_365d_without": level_coins_by_day(xp_catch, 365)[-1],
        }
    res["ledger"] = ledger
    res["level_coins_per_hour"] = {
        "level_1": CATCHES_PER_HOUR * CATCH_XP * LEVEL_UP_COINS / LEVEL_COST(1),
        "level_30": CATCHES_PER_HOUR * CATCH_XP * LEVEL_UP_COINS / LEVEL_COST(30),
        "level_59": CATCHES_PER_HOUR * CATCH_XP * LEVEL_UP_COINS / LEVEL_COST(59),
        "climb_average": CATCHES_PER_HOUR * CATCH_XP * res["xp"]["coins_per_xp"],
    }

    # analytic ceilings
    mean_notice = res["mean_pay"]["notice"]
    board_day = NOTICES_PER_RESET * mean_notice + EXPEDITION_PAY / 7
    ev_max = {b: statistics.fmean(r["max_pay"] for r in ev_rows if r["band"] == b) for b in ("low", "mid", "high")}
    ev_all = statistics.fmean(r["max_pay"] for r in ev_rows)
    ceilings = {"notice_mean_pay": mean_notice, "board_per_day": board_day, "board_per_week": board_day * 7,
                "event_max_by_band": ev_max, "event_max_all": ev_all, "event_per_day_all_bands": ev_all / EVENT_SLOT_DAYS,
                "event_per_week_all_bands": ev_all * 7 / EVENT_SLOT_DAYS,
                "event_per_day_low_only": ev_max["low"] / EVENT_SLOT_DAYS / 3,
                "event_per_day_low_mid": (ev_max["low"] + ev_max["mid"]) / EVENT_SLOT_DAYS / 3,
                "total_per_day": board_day + ev_all / EVENT_SLOT_DAYS,
                "total_per_week": (board_day + ev_all / EVENT_SLOT_DAYS) * 7,
                "campfire_year_one": sum(c for _, c in CAMPFIRE_MILESTONES),
                "standing_hunt_pot": STANDING_HUNT_POT}
    res["ceilings"] = ceilings

    # event value by hours invested (mean over the 24 events)
    evh = {}
    for label in ("random", "aligned"):
        evh[label] = {}
        for k in (1, 2, 3):
            pay = statistics.fmean(
                EVENT_RUN_PAY + r["hunts"] * (EVENT_TIER1_PAY + (k - 1) * EVENT_TIER_PAY) for r in ev_rows)
            hrs = statistics.fmean(r[f"h_tier{k}_{label}"] for r in ev_rows)
            evh[label][k] = {"pay": pay, "hours": hrs, "coins_per_hour": pay / hrs}
    res["event_by_tier"] = evh

    # 90-day income mix against the spec target (Tackle Board 55 / Ledger 35 / Hunts 10)
    mixes = {}
    for key, rec in out.items():
        f90 = rec["first90"]
        tb = f90["notice_coins"] + f90["expedition_coins"] + f90["campfire_coins"]
        hunts = f90["event_coins"]
        led = ledger[key]["level_coins_90d_with"]
        row = {"tb": tb, "hunts_events": hunts, "ledger_levels": led}
        for tag, extra_h, extra_l in (("levels_and_events_only", 0, 0),
                                      ("plus_pots", STANDING_HUNT_POT, discovery["pot_coins"])):
            t = tb + hunts + led + extra_h + extra_l
            row[tag] = {"tb": 100 * tb / t, "ledger": 100 * (led + extra_l) / t, "hunts": 100 * (hunts + extra_h) / t,
                        "total": t}
        mixes[key] = row
    res["mix90"] = mixes
    (HERE / "results.json").write_text(json.dumps(res, indent=1, default=str), encoding="utf-8")
    from report import render  # noqa: E402 (sibling module)

    render(res, tables)
    print("wrote results.json and tables/*.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
