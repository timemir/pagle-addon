"""Observed pairs and confirmation (DATA-R47–R56): what data/observed/'s observations imply for the catalogue.

A catch row (or a dev pair fact) evidences the catch entry REP-R10 would pick for it: its item in its area's list,
else in its zone's (DATA-R47). A row that finds no entry is an observed pair, which joins its area's list once
enough reporters saw it (DATA-R26 step 3). Every confirmed flag the catalogue ships (an entry's confirmed and
gateConfirmed, an area's skillBaseConfirmed, a window's and a weekly rule's confirmed) is computed here from the
observations that count (DATA-R46); nothing is confirmed by default (DATA-R56).

This module works on plain lists, {area: {item: window or None}}, so pagle_data.areas can use it for step 3.
"""

from collections.abc import Collection, Iterable, Mapping
from dataclasses import dataclass, field

from pagle_data.baseline import BaselineLayer
from pagle_data.db2 import Area
from pagle_data.errors import At, Problems
from pagle_data.forever import WeeklyRule
from pagle_data.items import ItemEntry, Record
from pagle_data.observed import DEV_REPORTER, FACT_IDS, CatchRow, DevFact, Observations
from pagle_data.windows import NAMED, Spec, event_window, window_of_event

# Tunables: the required reporters for an ordinary fact and for a big one (DATA-R49).
ORDINARY = 1
BIG = 2

# A catch row's time bucket, in minutes (REP-R20).
BUCKET = 15
MINUTES_PER_DAY = 1440
# Days in each month, 29 Feb included: a realm month is judged over every day it can have (DATA-R51, LOG-R48).
_DAYS_IN_MONTH = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
# A bound on the walk up an area's parents, so a parent cycle in bad data can't hang the generator (Core's
# zoneOf has the same).
_MAX_DEPTH = 16

# Catch lists as DATA-R26 builds them: each area's items and their gate's window ID, None when ungated.
Lists = Mapping[int, Mapping[int, str | None]]


def zone_of(areas: Mapping[int, Area], area_id: int) -> int | None:
    """The zone an area belongs to, up its parents; None when the chain leaves the slice."""
    for _ in range(_MAX_DEPTH):
        area = areas.get(area_id)
        if area is None:
            return None
        if area.parent == 0:
            return area_id
        area_id = area.parent
    return None


def evidenced_area(lists: Lists, areas: Mapping[int, Area], area: int, item: int) -> int | None:
    """The area whose entry a row of item in area evidences (DATA-R47, as REP-R10 picks it): area when its list has
    the item, else its zone when the zone's list has it, else None."""
    if item in lists.get(area, {}):
        return area
    zone = zone_of(areas, area)
    if zone is not None and item in lists.get(zone, {}):
        return zone
    return None


@dataclass(frozen=True)
class Evidence:
    """What a row evidences (DATA-R47): the lists after DATA-R26 steps 1 and 2, and the observed pairs that joined
    in step 3. A row evidences the entry evidenced_area picks in those lists; a row that picks none evidences its
    own observed pair once that pair joined, at its own area only, so a subzone row never evidences a pair its zone
    joined."""

    lists: Lists = field(default_factory=dict)
    joins: Collection[tuple[int, int]] = frozenset()

    def area(self, areas: Mapping[int, Area], area: int, item: int) -> int | None:
        found = evidenced_area(self.lists, areas, area, item)
        if found is None and (area, item) in self.joins:
            return area
        return found


@dataclass(frozen=True)
class Required:
    """The required reporters for each fact (DATA-R49): BIG for any pair or gate of a Legend, any pair of a new
    Species (a Species item absent from the baseline's loot), and a new window (a gate the baseline never gives that
    item, through its area-loot rows or the event of a pool whose loot holds it); ORDINARY otherwise."""

    legends: frozenset[int] = frozenset()
    new_species: frozenset[int] = frozenset()
    baseline_gates: frozenset[tuple[int, str]] = frozenset()

    def pair(self, item: int) -> int:
        return BIG if item in self.legends or item in self.new_species else ORDINARY

    def gate(self, item: int, window: str) -> int:
        return BIG if item in self.legends or (item, window) not in self.baseline_gates else ORDINARY


def required_reporters(baseline: BaselineLayer, items: Mapping[int, Record]) -> Required:
    """DATA-R49's big facts for these item records (DATA-R77) over the baseline."""
    tables: dict[int, set[int]] = {}
    for reference in baseline.reference_loot:
        tables.setdefault(reference.ref, set()).add(reference.item)

    def loot(item: int | None, ref: int | None) -> set[int]:
        return ({item} if item is not None else set()) | (tables.get(ref, set()) if ref is not None else set())

    looted: set[int] = set()
    gates: set[tuple[int, str]] = set()
    for row in baseline.area_loot:
        found = loot(row.item, row.ref)
        looted |= found
        window = window_of_event(row.event) if row.event is not None else None
        gates |= {(item, window) for item in found if window is not None}
    pool_windows = {pool.entry: window_of_event(pool.event) for pool in baseline.pools if pool.event is not None}
    for pool_row in baseline.pool_loot:
        found = loot(pool_row.item, pool_row.ref)
        looted |= found
        window = pool_windows.get(pool_row.entry)
        gates |= {(item, window) for item in found if window is not None}
    legends = {item for item, record in items.items() if record.get("legend") is True}
    species = {item for item, record in items.items() if "species" in record}
    return Required(frozenset(legends), frozenset(species - looted), frozenset(gates))


@dataclass(frozen=True)
class Sighting:
    """Pair evidence: a catch row, or a dev pair fact, which counts exactly like a catch row from dev (DATA-R45)."""

    item: int
    area: int
    reporter: str


def sightings(observations: Observations) -> list[Sighting]:
    found = [Sighting(row.item, row.area, row.reporter) for row in observations.catches]
    for fact in observations.facts:
        if fact.kind == "pair" and fact.item is not None and fact.area is not None:
            found.append(Sighting(fact.item, fact.area, DEV_REPORTER))
    return found


@dataclass(frozen=True)
class UngatedPair:
    """An observed pair that joined with no gate while its item is gated elsewhere: a warning (DATA-R47, DATA-R64)."""

    area: int
    item: int
    gated: tuple[tuple[int, str], ...]  # (area, window) for every other area that gates the item


@dataclass(frozen=True)
class ObservedPairs:
    """DATA-R26 step 3: the observed pairs that join a list, each with its gate (None when ungated), and those that
    joined ungated though their item is gated somewhere."""

    joins: dict[tuple[int, int], str | None] = field(default_factory=dict)
    ungated: list[UngatedPair] = field(default_factory=list)


def observed_pairs(
    lists: Lists, areas: Mapping[int, Area], observations: Observations, items: Mapping[int, Record], required: Required
) -> ObservedPairs:
    """The observed pairs (DATA-R47) among observations that count (DATA-R46), over the lists after DATA-R26 steps 1
    and 2: a row whose item is in neither its area's nor its zone's list, ships and isn't Noise. One joins once
    rows from the required reporters (DATA-R49) saw it, with a gate only when every other area listing the item
    gates it by one window."""
    reporters: dict[tuple[int, int], set[str]] = {}
    for sighting in sightings(observations):
        record = items.get(sighting.item)
        if record is None or record.get("noise") is True:
            continue
        if evidenced_area(lists, areas, sighting.area, sighting.item) is None:
            reporters.setdefault((sighting.area, sighting.item), set()).add(sighting.reporter)
    found = ObservedPairs()
    for (area, item), who in sorted(reporters.items()):
        if len(who) < required.pair(item):
            continue
        elsewhere = {other: listed[item] for other, listed in sorted(lists.items()) if item in listed}
        windows = set(elsewhere.values())
        gate = windows.pop() if len(windows) == 1 else None
        found.joins[(area, item)] = gate
        gated = tuple((other, window) for other, window in elsewhere.items() if window is not None)
        if gate is None and gated:
            found.ungated.append(UngatedPair(area, item, gated))
    return found


# DATA-R51: a row is inside a window, outside it, or neither.
INSIDE = "inside"
OUTSIDE = "outside"
NEITHER = "neither"


def _all_or_none(holds: Iterable[bool]) -> str:
    found = set(holds)
    return INSIDE if found == {True} else OUTSIDE if found == {False} else NEITHER


def _in_time(minute: int, time_range: object) -> bool:
    """minute in a LOG-R48 time range: from inclusive, to exclusive, wrapping past midnight when to < from."""
    assert isinstance(time_range, list)
    start, end = int(time_range[0]), int(time_range[1])
    return start <= minute < end if start < end else minute >= start or minute < end


def _month_day(value: object) -> tuple[int, int]:
    assert isinstance(value, list)
    return int(value[0]), int(value[1])


def _in_season(day: tuple[int, int], season: object) -> bool:
    """(month, day) in a LOG-R48 season range: both days inclusive, wrapping the year when to < from."""
    assert isinstance(season, Mapping)
    start, end = _month_day(season["from"]), _month_day(season["to"])
    return start <= day <= end if start <= end else day >= start or day <= end


def side(row: CatchRow, spec: Spec) -> str:
    """Whether row is inside spec, outside it or neither (DATA-R51): each time-based field judged over the row's
    span (its 15-minute bucket for time, its realm month for season, its event= list for events); a row without t
    and m is neither for time and season."""
    sides: list[str] = []
    times, seasons, events = spec.get("time"), spec.get("season"), spec.get("events")
    if isinstance(times, list):
        if row.t is None:
            sides.append(NEITHER)
        else:
            minutes = ((row.t + offset) % MINUTES_PER_DAY for offset in range(BUCKET))
            sides.append(_all_or_none(any(_in_time(minute, r) for r in times) for minute in minutes))
    if isinstance(seasons, list):
        if row.m is None:
            sides.append(NEITHER)
        else:
            days = ((row.m, day) for day in range(1, _DAYS_IN_MONTH[row.m - 1] + 1))
            sides.append(_all_or_none(any(_in_season(day, s) for s in seasons) for day in days))
    if isinstance(events, list):
        sides.append(INSIDE if set(row.events) & set(events) else OUTSIDE)
    if OUTSIDE in sides:
        return OUTSIDE
    return INSIDE if sides and all(found == INSIDE for found in sides) else NEITHER


def _outside_weekly(row: CatchRow, rule: WeeklyRule) -> bool:
    """Whether row's bucket lies wholly outside the rule's daily span [start, start + duration) (DATA-R54)."""
    if row.t is None or rule.duration >= MINUTES_PER_DAY:
        return False
    span = (rule.start, (rule.start + rule.duration) % MINUTES_PER_DAY)
    return not any(_in_time((row.t + offset) % MINUTES_PER_DAY, list(span)) for offset in range(BUCKET))


@dataclass(frozen=True)
class Confirmation:
    """Every confirmed flag the catalogue ships (DATA-R48–R56): the confirmed entries and the entries whose
    gateConfirmed is true, as (area, item); the areas whose skill base is confirmed; the confirmed windows; the
    events whose weekly rule is confirmed. Empty: nothing confirmed (DATA-R56)."""

    entries: frozenset[tuple[int, int]] = frozenset()
    gates: frozenset[tuple[int, int]] = frozenset()
    skill_bases: frozenset[int] = frozenset()
    windows: frozenset[str] = frozenset()
    weekly: frozenset[int] = frozenset()


def confirm(
    lists: Lists,
    evidence: Evidence,
    skill_bases: Mapping[int, int],
    areas: Mapping[int, Area],
    observations: Observations,
    required: Required,
    windows: Mapping[str, Spec],
    events: Mapping[int, WeeklyRule | None],
    problems: Problems,
) -> Confirmation:
    """The confirmed flags (DATA-R48, DATA-R52–R55) for the built catch lists (DATA-R26) and skill bases
    (DATA-R30), from the observations that count (DATA-R46) in areas of the slice (DATA-R33), each row evidencing
    what evidence says (DATA-R47). A dev fact that names nothing it could confirm goes into problems."""
    facts = {kind: [fact for fact in observations.facts if fact.kind == kind] for kind in FACT_IDS}
    _check_facts(lists, skill_bases, windows, events, facts, problems)

    def evidenced(area: int, item: int) -> int | None:
        """The area of the built entry a row of item in area evidences; None when it evidences none, or an entry
        DATA-R26 step 4 took out."""
        found = evidence.area(areas, area, item)
        return found if found is not None and item in lists.get(found, {}) else None

    # DATA-R48: an entry is confirmed by pair evidence from the required reporters.
    pair_reporters: dict[tuple[int, int], set[str]] = {}
    for sighting in sightings(observations):
        area = evidenced(sighting.area, sighting.item)
        if area is not None:
            pair_reporters.setdefault((area, sighting.item), set()).add(sighting.reporter)
    entries = {key for key, who in pair_reporters.items() if len(who) >= required.pair(key[1])}

    # DATA-R52: a gate (item, window) is judged over every row evidencing an entry that carries it.
    gated: dict[tuple[int, str], set[int]] = {}
    for area, listed in lists.items():
        for item, window in listed.items():
            if window is not None:
                gated.setdefault((item, window), set()).add(area)
    inside: dict[tuple[int, str], set[str]] = {}
    contradicted: set[tuple[int, str]] = set()
    for row in observations.catches:
        area = evidenced(row.area, row.item)
        window = lists[area][row.item] if area is not None else None
        if window is None:
            continue
        found = side(row, windows[window])
        if found == OUTSIDE:
            contradicted.add((row.item, window))
        elif found == INSIDE:
            inside.setdefault((row.item, window), set()).add(row.reporter)
    gate_facts = {(fact.item, fact.window) for fact in facts["gate"]}
    confirmed_gates = {
        gate
        for gate in gated
        if gate not in contradicted
        and (len(inside.get(gate, ())) >= required.gate(*gate) or gate in gate_facts)
    }
    gates = {(area, item) for item, window in confirmed_gates for area in gated[(item, window)]}

    # DATA-R54: a weekly rule is confirmed by a dev fact, unless a row with its event lies wholly outside its span.
    weekly: set[int] = set()
    for event_id in {fact.event for fact in facts["weekly"]}:
        rule = events.get(event_id) if event_id is not None else None
        if rule is None or event_id is None:
            continue
        if not any(event_id in row.events and _outside_weekly(row, rule) for row in observations.catches):
            weekly.add(event_id)

    # DATA-R53: a window by a dev fact, or by a confirmed gate on it with none contradicted; an event window by its
    # weekly rule.
    event_windows = {event_window(event_id): event_id for event_id, rule in events.items() if rule is not None}
    window_facts = {fact.window for fact in facts["window"]}
    confirmed_windows: set[str] = set()
    for window_id in windows:
        if window_id in event_windows:
            if event_windows[window_id] in weekly:
                confirmed_windows.add(window_id)
            continue
        on_it = {gate for gate in gated if gate[1] == window_id}
        if window_id in window_facts or (on_it & confirmed_gates and not on_it & contradicted):
            confirmed_windows.add(window_id)

    # DATA-R55: a skill base is contradicted by a land below it, else confirmed by any land or a dev fact.
    lands: dict[int, list[int]] = {}
    for skill in observations.skills:
        if skill.land is not None:
            lands.setdefault(skill.area, []).append(skill.land)
    skill_facts = {fact.area for fact in facts["skillBase"]}
    confirmed_bases = {
        area
        for area, base in skill_bases.items()
        if all(land >= base for land in lands.get(area, [])) and (area in lands or area in skill_facts)
    }
    return Confirmation(
        frozenset(entries),
        frozenset(gates),
        frozenset(confirmed_bases),
        frozenset(confirmed_windows),
        frozenset(weekly),
    )


def _check_facts(
    lists: Lists,
    skill_bases: Mapping[int, int],
    windows: Mapping[str, Spec],
    events: Mapping[int, WeeklyRule | None],
    facts: Mapping[str, list[DevFact]],
    problems: Problems,
) -> None:
    """A dev fact must name something it can confirm (DATA-R122): a gate a catch entry carries, a known window (an
    event window takes its weekly rule's confirmation, DATA-R53), an event with a weekly rule, an area with a skill
    base."""
    gated = {(item, window) for listed in lists.values() for item, window in listed.items() if window is not None}
    for fact in facts["gate"]:
        if fact.window not in windows:
            problems.add(fact.at / "window", f"'{fact.window}' isn't a window ID (DATA-R35)")
        elif (fact.item, fact.window) not in gated:
            problems.add(fact.at, f"no catch entry gates item {fact.item} by '{fact.window}' (DATA-R52)")
    for fact in facts["window"]:
        if fact.window not in windows:
            problems.add(fact.at / "window", f"'{fact.window}' isn't a window ID (DATA-R35)")
        elif fact.window not in NAMED:
            message = "an event window takes its weekly rule's confirmation: use a weekly fact (DATA-R53)"
            problems.add(fact.at / "window", message)
    for fact in facts["weekly"]:
        if fact.event is None or events.get(fact.event) is None:
            message = f"event {fact.event} has no weekly rule in data/forever/events.toml (DATA-R54)"
            problems.add(fact.at / "event", message)
    for fact in facts["skillBase"]:
        if fact.area not in skill_bases:
            problems.add(fact.at / "area", f"area {fact.area} has no skill base (DATA-R55)")


def check_removed(observations: Observations, entries: Mapping[int, ItemEntry], problems: Problems) -> None:
    """DATA-R23: a non-rejected observation of a removed item on a build at or above its removedFrom is a problem,
    so the dev un-removes the item or rejects the row. Observations from earlier builds are fine."""
    seen: list[tuple[int, int, At]] = [(row.item, row.build, row.at) for row in observations.catches]
    seen += [(fact.item, fact.build, fact.at) for fact in observations.facts if fact.item is not None]
    for item, build, at in seen:
        entry = entries.get(item)
        if entry is None or entry.removed_from is None or build < entry.removed_from:
            continue
        problems.add(
            at,
            f"item {item} is observed on build {build}, but items.toml has it removed from build"
            f" {entry.removed_from}; un-remove it or reject the observation (DATA-R23)",
        )
