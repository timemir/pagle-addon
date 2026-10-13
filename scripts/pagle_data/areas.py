"""Catch lists, gates, skill bases and hasData (DATA-R26–R31): data/forever/areas.toml (DATA-R10), and the record
each area of the DB2 slice ships with in the catalogue's areas (DATA-R78).

An area's catch list is built per area, never inherited (DATA-R26): the baseline's area loot without Noise, then
areas.toml's edits, then observed pairs (step 3, ticket #95's), then removed, Noise and uncharted items leave. Keys
and types are the Data section's in docs/spec/content-data.md.
"""

from collections.abc import Collection, Iterator, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.baseline import BASELINE, BaselineLayer
from pagle_data.db2 import Area
from pagle_data.items import Record
from pagle_data.toml_reader import (
    At,
    Problems,
    check_keys,
    describe,
    expect_int,
    expect_table,
    expect_why,
    read_toml,
)
from pagle_data.universe import AREAS_TOML
from pagle_data.windows import window_of_event

AREA_LOOT = f"{BASELINE}/area_loot.csv"
# DATA-R29: `gate = "none"` on an add removes the item's gate.
NO_GATE = "none"
OPS = ("add", "drop")
# A bound on the walk up an area's parents, so a parent cycle in bad data can't hang the generator (Core's
# zoneOf has the same).
_MAX_DEPTH = 16


@dataclass(frozen=True)
class AreaEdit:
    """An [[area]] entry: clearBaseline empties the area's baseline list (DATA-R26 step 2); skillBase overrides its
    skill base (DATA-R30)."""

    area: int
    clear_baseline: bool
    skill_base: int | None
    at: At


@dataclass(frozen=True)
class CatchEdit:
    """A [[catch]] entry (DATA-R26 step 2): op is add or drop; gate is a window ID, NO_GATE, or None when not
    given (an add only)."""

    area: int
    item: int
    op: str
    gate: str | None
    at: At


@dataclass
class AreaLayer:
    """areas.toml's [[area]] entries by area ID and its [[catch]] entries in file order."""

    areas: dict[int, AreaEdit] = field(default_factory=dict)
    catches: list[CatchEdit] = field(default_factory=list)

    def items(self) -> set[int]:
        """The item IDs the [[catch]] entries name, added or dropped (DATA-R15)."""
        return {edit.item for edit in self.catches}


def _entries(document: Mapping[str, object], key: str, at: At, problems: Problems) -> Iterator[tuple[object, At]]:
    entries = document.get(key, [])
    if not isinstance(entries, list):
        problems.add(at / key, f"expected an array of tables ([[{key}]]), got {describe(entries)}")
        return
    for index, entry in enumerate(entries):
        yield entry, At(at.file, f"{key}[{index}]")


def _read_area(entry: object, at: At, problems: Problems) -> AreaEdit | None:
    before = len(problems.found)
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=("id", "why"), optional=("clearBaseline", "skillBase"))
    area = expect_int(table["id"], at / "id", problems, minimum=1) if "id" in table else None
    clear = table.get("clearBaseline", False)
    if not isinstance(clear, bool):
        problems.add(at / "clearBaseline", f"expected a boolean, got {describe(clear)}")
    skill_base = table.get("skillBase")
    if skill_base is not None and (isinstance(skill_base, bool) or not isinstance(skill_base, int)):
        problems.add(at / "skillBase", f"expected an integer, got {describe(skill_base)}")
    if clear is not True and "skillBase" not in table:
        problems.add(at, "sets neither clearBaseline = true nor skillBase")
    expect_why(table, at, problems)
    if area is None or len(problems.found) != before:
        return None
    return AreaEdit(area, clear is True, skill_base if isinstance(skill_base, int) else None, at)


def _read_catch(entry: object, at: At, problems: Problems) -> CatchEdit | None:
    before = len(problems.found)
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=("area", "item", "op", "why"), optional=("gate",))
    area = expect_int(table["area"], at / "area", problems, minimum=1) if "area" in table else None
    item = expect_int(table["item"], at / "item", problems, minimum=1) if "item" in table else None
    op = table.get("op")
    if "op" in table and op not in OPS:
        shown = f"'{op}'" if isinstance(op, str) else describe(op)
        problems.add(at / "op", f"expected add or drop, got {shown}")
    gate = table.get("gate")
    if gate is not None and not isinstance(gate, str):
        problems.add(at / "gate", f"expected a window ID or \"{NO_GATE}\", got {describe(gate)}")
    if op == "drop" and "gate" in table:
        problems.add(at / "gate", "a drop takes no gate: it removes the item (DATA-R26)")
    expect_why(table, at, problems)
    if area is None or item is None or not isinstance(op, str) or len(problems.found) != before:
        return None
    return CatchEdit(area, item, op, gate if isinstance(gate, str) else None, at)


def read_areas_toml(root: Path, problems: Problems) -> AreaLayer:
    """areas.toml under root/data/forever/ (DATA-R10). Each problem found goes into problems; a bad entry is left
    out, and the caller must not use the layer while there are problems."""
    layer = AreaLayer()
    document = read_toml(root, AREAS_TOML, problems)
    if document is None:
        return layer
    at = At(AREAS_TOML)
    check_keys(document, at, problems, required=(), optional=("area", "catch"))
    for entry, entry_at in _entries(document, "area", at, problems):
        area = _read_area(entry, entry_at, problems)
        if area is None:
            continue
        if area.area in layer.areas:
            problems.add(entry_at / "id", f"area {area.area} is listed twice")
            continue
        layer.areas[area.area] = area
    listed: set[tuple[int, int]] = set()
    for entry, entry_at in _entries(document, "catch", at, problems):
        catch = _read_catch(entry, entry_at, problems)
        if catch is None:
            continue
        if (catch.area, catch.item) in listed:
            problems.add(entry_at, f"item {catch.item} in area {catch.area} is listed twice")
            continue
        listed.add((catch.area, catch.item))
        layer.catches.append(catch)
    return layer


@dataclass(frozen=True)
class Catch:
    """A catch-list entry: the item and its gate's window ID, None when ungated (DATA-R29)."""

    item: int
    window: str | None


@dataclass(frozen=True)
class CatchLists:
    """Every non-empty catch list by area, each sorted by item ID (DATA-R26), and the skill bases (DATA-R30)."""

    lists: dict[int, list[Catch]] = field(default_factory=dict)
    skill_bases: dict[int, int] = field(default_factory=dict)

    def fishing_areas(self) -> set[int]:
        """The areas with a catch list: DATA-R32's baseline fishing areas."""
        return set(self.lists)


def _baseline_rows(baseline: BaselineLayer) -> dict[int, dict[int, list[int | None]]]:
    """Each area's items and the event of each area-loot row that gives it, a reference row giving every item of
    its table (DATA-R26 step 1)."""
    tables: dict[int, list[int]] = {}
    for reference in baseline.reference_loot:
        tables.setdefault(reference.ref, []).append(reference.item)
    rows: dict[int, dict[int, list[int | None]]] = {}
    for row in baseline.area_loot:
        items = [row.item] if row.item is not None else tables.get(row.ref, []) if row.ref is not None else []
        for item in items:
            rows.setdefault(row.area, {}).setdefault(item, []).append(row.event)
    return rows


def condition_warnings(baseline: BaselineLayer) -> list[str]:
    """DATA-R64's warning for each area-loot row whose condition isn't a single event: it has no event, so it is
    ungated, and the dev decides its gate in areas.toml (DATA-R9)."""
    warnings: list[str] = []
    for row in baseline.area_loot:
        if row.condition:
            what = f"item {row.item}" if row.item is not None else f"reference table {row.ref}"
            warnings.append(
                f"{AREA_LOOT}: {what} in area {row.area} has the condition '{row.condition}', not a single event,"
                f" so it is ungated; set its gate in {AREAS_TOML} (DATA-R9)"
            )
    return warnings


def _noise(items: Mapping[int, Record], item: int) -> bool:
    record = items.get(item)
    return record is not None and record.get("noise") is True


def build_catch_lists(
    baseline: BaselineLayer,
    layer: AreaLayer,
    items: Mapping[int, Record],
    windows: Collection[str],
    areas: Mapping[int, Area],
    problems: Problems,
) -> CatchLists:
    """DATA-R26's catch lists and DATA-R30's skill bases, from the baseline, areas.toml, the item records that ship
    (items, DATA-R77), the window IDs (DATA-R35) and the DB2 slice's areas. Each problem found goes into
    problems."""
    lists: dict[int, dict[int, str | None]] = {}
    conflicts: dict[tuple[int, int], list[str]] = {}
    # Step 1: the baseline's area loot, Noise left out. DATA-R29: a gate when every row maps to one window.
    for area, by_item in _baseline_rows(baseline).items():
        for item, events in by_item.items():
            if _noise(items, item):
                continue
            gate: str | None = None
            if all(event is not None for event in events):
                found = set()
                for event in events:
                    window = window_of_event(event) if event is not None else None
                    if window is None:
                        problems.add(At(AREA_LOOT), f"item {item} in area {area}: event {event} maps to no window")
                    else:
                        found.add(window)
                if len(found) > 1:
                    conflicts[(area, item)] = sorted(found)
                gate = found.pop() if len(found) == 1 else None
            lists.setdefault(area, {})[item] = gate

    # Step 2: areas.toml's edits.
    for edit in layer.areas.values():
        if edit.area not in areas:
            problems.add(edit.at / "id", f"area {edit.area} isn't in data/db2/areas.csv")
        if edit.clear_baseline:
            lists.pop(edit.area, None)
            conflicts = {key: found for key, found in conflicts.items() if key[0] != edit.area}
    for catch in layer.catches:
        if catch.area not in areas:
            problems.add(catch.at / "area", f"area {catch.area} isn't in data/db2/areas.csv")
        if catch.gate is not None and catch.gate != NO_GATE and catch.gate not in windows:
            problems.add(catch.at / "gate", f"'{catch.gate}' isn't a window ID (DATA-R35)")
        listed = lists.setdefault(catch.area, {})
        if catch.op == "drop":
            listed.pop(catch.item, None)
            conflicts.pop((catch.area, catch.item), None)
        elif catch.gate is not None:
            listed[catch.item] = None if catch.gate == NO_GATE else catch.gate
            conflicts.pop((catch.area, catch.item), None)
        else:
            listed.setdefault(catch.item, None)
    for (area, item), conflicting in sorted(conflicts.items()):
        problems.add(
            At(AREA_LOOT),
            f"item {item} in area {area}: its rows map to different windows ({', '.join(conflicting)}); set its gate"
            " with an areas.toml add (DATA-R29)",
        )

    # Step 3, observed pairs (DATA-R47), is #95's.

    # Step 4: removed, Noise and uncharted items leave; an item outside the shipped records is uncharted.
    built: dict[int, list[Catch]] = {}
    for area, listed in sorted(lists.items()):
        kept = [
            Catch(item, window)
            for item, window in sorted(listed.items())
            if (record := items.get(item)) is not None and record.get("removed") is not True and not _noise(items, item)
        ]
        if kept:
            built[area] = kept

    # DATA-R30: a zone's skill base from skill.csv, then areas.toml's, which alone can give a subzone one.
    skill_bases = {area: base for area, base in baseline.skill.items() if area in areas and areas[area].parent == 0}
    for edit in layer.areas.values():
        if edit.skill_base is not None:
            skill_bases[edit.area] = edit.skill_base
    return CatchLists(built, skill_bases)


def _zone_of(areas: Mapping[int, Area], area_id: int) -> int | None:
    """The zone an area belongs to, up its parents; None when the chain leaves the slice."""
    for _ in range(_MAX_DEPTH):
        area = areas.get(area_id)
        if area is None:
            return None
        if area.parent == 0:
            return area_id
        area_id = area.parent
    return None


def area_records(
    areas: Mapping[int, Area],
    catch_lists: CatchLists,
    alias_sources: Collection[int],
    windows: Mapping[str, Mapping[str, object]],
) -> dict[int, Record]:
    """Every DB2 area's record (DATA-R25, DATA-R78). windows are the catalogue's, so a gate is its window's shared
    spec (Contracts). Nothing is confirmed yet (DATA-R56, #95)."""
    with_data = {_zone_of(areas, area) for area in catch_lists.lists if area not in alias_sources}
    records: dict[int, Record] = {}
    for area_id, area in areas.items():
        alias = area_id in alias_sources
        catches: list[Record] = []
        for catch in [] if alias else catch_lists.lists.get(area_id, []):
            entry: Record = {"itemID": catch.item, "confirmed": False}
            if catch.window is not None:
                entry.update(window=catch.window, gate=windows[catch.window]["spec"], gateConfirmed=False)
            catches.append(entry)
        zone = _zone_of(areas, area_id)
        # DATA-R31: a zone has data when it or a subzone has a list, and a subzone takes its zone's value.
        has_data = not alias and (zone in with_data if zone is not None else bool(catches))
        record: Record = {
            "parent": area.parent,
            "continent": area.continent,
            "hasData": has_data,
            "skillBaseConfirmed": False,
            "catches": catches,
        }
        if area_id in catch_lists.skill_bases:
            record["skillBase"] = catch_lists.skill_bases[area_id]
        records[area_id] = record
    return records
