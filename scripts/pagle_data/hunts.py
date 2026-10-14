"""The Hunt list (DATA-R85-R94): data/hunts/hunts.toml, its checks, the fixed and generated classes, HuntList.lua,
each Hunt's hash and the Hunt list's fingerprint.

What each field means is hunts.md's; this module fixes the format, the checks and the emitted shape. A Hunt's and a
set's text (name, title, note) is lore (DATA-R105): the format requires it, and it is never in a record, a hash or
the fingerprint. Admission and the rarity cap (DATA-R92) and the release lock (DATA-R91, DATA-R95, DATA-R96) build
on the layer, the classes and hunt_hash here.
"""

import calendar
import re
from collections.abc import Collection, Mapping
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import TypedDict

from pagle_data.catalogue import FINGERPRINT_LENGTH, canonical, sha256_hex
from pagle_data.conditions import check_spec
from pagle_data.errors import At, Problems
from pagle_data.items import Record
from pagle_data.lore import CORE_GUARD
from pagle_data.lua import to_lua
from pagle_data.toml_reader import check_keys, describe, expect_ids, expect_table, read_toml
from pagle_data.universe import HUNTS_TOML

HUNT_LIST_LUA = "addons/Pagle_Hunts/data/HuntList.lua"

# DATA-R92: a Hunt or set ID matches Lua's [%w_]+; DATA-R90: a fixed class ID is fixed.<name>, <name> the same.
_ID = re.compile(r"[A-Za-z0-9_]+")
_FIXED_CLASS = re.compile(r"fixed\.[A-Za-z0-9_]+")
# DATA-R91: the generated classes, in DATA-R91's order.
QUALITY_UNCOMMON = "quality.uncommon"
QUALITY_RARE = "quality.rare"
SPECIES_ANY = "species.any"
GENERATED_CLASSES = (QUALITY_UNCOMMON, QUALITY_RARE, SPECIES_ANY)
# DATA-R86: a Hunt's kinds.
NATURAL = "natural"
IMPOSED = "imposed"
# Tunables: the minBand range (DATA-R89).
MIN_BAND = 2
MAX_BAND = 4

# The keys of each table (Data: `data/hunts/hunts.toml` keys). The lore keys are read for their shape only.
_SET_REQUIRED = ("id", "name", "title")
_SET_OPTIONAL = ("note",)
_CLASS_REQUIRED = ("id", "members")
_HUNT_REQUIRED = ("id", "set", "kind", "since", "tiers", "name")
_HUNT_OPTIONAL = ("retired", "species", "class", "minBand", "window", "conditions", "note")
# A Hunt record's fields that come straight from the file (DATA-R93); since and retired become server times.
_RECORD_STRINGS = ("set", "kind", "class", "window")

# A Hunt's emitted record (DATA-R93): id, set, kind, since, retired?, species?, class?, minBand?, window?,
# conditions?, tiers.
HuntRecord = dict[str, object]


@dataclass(frozen=True)
class HuntSet:
    """A [[set]] (DATA-R85): its ID, and where it sits for a message."""

    id: str
    at: At


@dataclass(frozen=True)
class FixedClass:
    """A [[class]] (DATA-R90): fixed.<name> and its members, in file order."""

    id: str
    members: tuple[int, ...]
    at: At


@dataclass(frozen=True)
class Hunt:
    """A [[hunt]] (DATA-R85-R89): its emitted record (DATA-R93), lore left out, and where it sits for a message."""

    id: str
    record: HuntRecord
    at: At

    def get(self, key: str) -> object:
        return self.record.get(key)


@dataclass
class HuntLayer:
    """data/hunts/hunts.toml as read: sets, fixed classes and Hunts in file order (DATA-R93)."""

    sets: list[HuntSet] = field(default_factory=list)
    classes: list[FixedClass] = field(default_factory=list)
    hunts: list[Hunt] = field(default_factory=list)

    def members(self) -> set[int]:
        """Every fixed class's members: they join the item universe (DATA-R15)."""
        return {member for fixed in self.classes for member in fixed.members}


class HuntList(TypedDict):
    """ns.huntList (DATA-R93): sets as { id } and Hunts in file order, classes as { [classID] = { [itemID] = true } }."""

    fingerprint: str
    sets: list[dict[str, object]]
    hunts: list[HuntRecord]
    classes: dict[str, dict[int, bool]]


def _at(kind: str, table: Mapping[str, object], index: int) -> At:
    """Where a [[set]], [[class]] or [[hunt]] sits: by its ID when it has a string one, else by its position, so a
    message names the set, class or Hunt."""
    entry_id = table.get("id")
    if not isinstance(entry_id, str):
        return At(HUNTS_TOML, f"{kind}[{index}]")
    if kind == "class":
        return At(HUNTS_TOML, f'class."{entry_id}"')
    return At(HUNTS_TOML, f"{kind}.{entry_id}")


def _string(table: Mapping[str, object], key: str, at: At, problems: Problems) -> str | None:
    """table[key] as a string, or None: absent (check_keys' problem) or not a string (a problem here)."""
    if key not in table:
        return None
    value = table[key]
    if isinstance(value, str):
        return value
    problems.add(at / key, f"expected a string, got {describe(value)}")
    return None


def _date(table: Mapping[str, object], key: str, at: At, problems: Problems) -> int | None:
    """DATA-R87: a TOML date (YYYY-MM-DD), meaning 00:00 UTC on that day, as a server time (Unix seconds)."""
    if key not in table:
        return None
    value = table[key]
    if isinstance(value, datetime) or not isinstance(value, date):
        problems.add(at / key, f"expected a date (YYYY-MM-DD), got {describe(value)}")
        return None
    return calendar.timegm(value.timetuple())


def _integer(table: Mapping[str, object], key: str, at: At, problems: Problems) -> int | None:
    if key not in table:
        return None
    value = table[key]
    if isinstance(value, bool) or not isinstance(value, int):
        problems.add(at / key, f"expected an integer, got {describe(value)}")
        return None
    return value


def _entries(document: Mapping[str, object], kind: str, problems: Problems) -> list[tuple[Mapping[str, object], At]]:
    """The [[<kind>]] tables of the document, each with where it sits."""
    if kind not in document:
        return []
    value = document[kind]
    if not isinstance(value, list):
        problems.add(At(HUNTS_TOML, kind), f"expected an array of tables ([[{kind}]]), got {describe(value)}")
        return []
    found: list[tuple[Mapping[str, object], At]] = []
    for index, entry in enumerate(value):
        table = expect_table(entry, At(HUNTS_TOML, f"{kind}[{index}]"), problems)
        if table is not None:
            found.append((table, _at(kind, table, index)))
    return found


def _id(table: Mapping[str, object], at: At, pattern: re.Pattern[str], shape: str, problems: Problems) -> str | None:
    """An entry's ID, checked against its pattern (DATA-R90, DATA-R92)."""
    entry_id = _string(table, "id", at, problems)
    if entry_id is not None and not pattern.fullmatch(entry_id):
        problems.add(at / "id", f"'{entry_id}' doesn't match {shape} (DATA-R92)")
    return entry_id


def _check_unique(kind: str, ids: list[tuple[str, At]], problems: Problems) -> None:
    """DATA-R92: an ID repeats among Hunts, among sets or among classes."""
    seen: set[str] = set()
    for entry_id, at in ids:
        if entry_id in seen:
            problems.add(at, f"the {kind} ID '{entry_id}' is used twice (DATA-R92)")
        seen.add(entry_id)


def _read_set(table: Mapping[str, object], at: At, problems: Problems) -> HuntSet | None:
    check_keys(table, at, problems, required=_SET_REQUIRED, optional=_SET_OPTIONAL)
    for key in ("name", "title", "note"):
        _string(table, key, at, problems)  # DATA-R105: lore, required in its shape
    set_id = _id(table, at, _ID, "[%w_]+", problems)
    return None if set_id is None else HuntSet(set_id, at)


def _read_class(table: Mapping[str, object], at: At, problems: Problems) -> FixedClass | None:
    check_keys(table, at, problems, required=_CLASS_REQUIRED, optional=())
    class_id = _id(table, at, _FIXED_CLASS, "fixed.<name>, <name> matching [%w_]+ (DATA-R90)", problems)
    members = expect_ids(table["members"], at / "members", problems) if "members" in table else None
    if class_id is None or members is None:
        return None
    return FixedClass(class_id, tuple(members), at)


def _conditions(table: Mapping[str, object], at: At, problems: Problems) -> dict[str, object] | None:
    """An imposed Hunt's conditions (DATA-R86): an inline table holding a condition spec (LOG-R48), checked as Core's
    MatchesConditions checks it (pagle_data.conditions)."""
    if "conditions" not in table:
        return None
    spec = expect_table(table["conditions"], at / "conditions", problems)
    if spec is None:
        return None
    seasons = spec.get("season")
    if isinstance(seasons, list):
        for index, season in enumerate(seasons):
            if isinstance(season, Mapping):
                season_at = At(at.file, f"{at.path}.conditions.season[{index}]")
                check_keys(season, season_at, problems, required=(), optional=("from", "to"))
    problem = check_spec(spec)
    if problem is not None:
        problems.add(at / "conditions", f"{problem} (LOG-R48, DATA-R92)")
        return None
    return dict(spec)


def _tiers(table: Mapping[str, object], at: At, problems: Problems) -> list[int] | None:
    """DATA-R88: tiers is a list of strictly ascending positive integers; the first is completion."""
    if "tiers" not in table:
        return None
    tiers = table["tiers"]
    if (
        not isinstance(tiers, list)
        or not tiers
        or not all(isinstance(tier, int) and not isinstance(tier, bool) and tier >= 1 for tier in tiers)
        or any(later <= earlier for earlier, later in zip(tiers, tiers[1:]))
    ):
        problems.add(at / "tiers", f"expected strictly ascending positive integers, got {tiers!r} (DATA-R88)")
        return None
    return list(tiers)


def _read_hunt(table: Mapping[str, object], at: At, problems: Problems) -> Hunt | None:
    """A [[hunt]]'s record (DATA-R93), with every check that needs nothing but the file (DATA-R86-R89, DATA-R92)."""
    check_keys(table, at, problems, required=_HUNT_REQUIRED, optional=_HUNT_OPTIONAL)
    for key in ("name", "note"):
        _string(table, key, at, problems)  # DATA-R105: lore, required in its shape
    hunt_id = _id(table, at, _ID, "[%w_]+", problems)
    record: HuntRecord = {}
    if hunt_id is not None:
        record["id"] = hunt_id
    for key in _RECORD_STRINGS:
        value = _string(table, key, at, problems)
        if value is not None:
            record[key] = value
    for key in ("since", "retired"):
        server_time = _date(table, key, at, problems)
        if server_time is not None:
            record[key] = server_time
    species = _integer(table, "species", at, problems)
    if species is not None:
        record["species"] = species
    min_band = _integer(table, "minBand", at, problems)
    if min_band is not None:
        record["minBand"] = min_band
    conditions = _conditions(table, at, problems)
    if conditions is not None:
        record["conditions"] = conditions
    tiers = _tiers(table, at, problems)
    if tiers is not None:
        record["tiers"] = tiers

    kind = record.get("kind")
    if "kind" in record and kind not in (NATURAL, IMPOSED):
        problems.add(at / "kind", f"expected '{NATURAL}' or '{IMPOSED}', got '{kind}' (DATA-R86)")
    if "species" in table and "class" in table:
        problems.add(at, "has both a species and a class target; give one (DATA-R86)")
    elif "species" not in table and "class" not in table:
        problems.add(at, "has no target; give a species or a class (DATA-R86)")
    if min_band is not None and not MIN_BAND <= min_band <= MAX_BAND:
        problems.add(at / "minBand", f"expected {MIN_BAND} to {MAX_BAND}, got {min_band} (DATA-R89)")
    if "minBand" in table and "class" in table:
        problems.add(at / "minBand", "only a species target can have a minBand (DATA-R89)")
    if kind == NATURAL:
        if "window" not in table:
            problems.add(at, "is natural and has no window (DATA-R86, DATA-R92)")
        if "conditions" in table:
            problems.add(at / "conditions", "a natural Hunt has a window, not conditions (DATA-R86, DATA-R92)")
        if "class" in table:
            problems.add(at / "class", "a natural Hunt targets a species, not a class (DATA-R86, DATA-R92)")
    elif kind == IMPOSED:
        if "conditions" not in table:
            problems.add(at, "is imposed and has no conditions (DATA-R86, DATA-R92)")
        if "window" in table:
            problems.add(at / "window", "an imposed Hunt has conditions, not a window (DATA-R86, DATA-R92)")
    since, retired = record.get("since"), record.get("retired")
    if isinstance(since, int) and isinstance(retired, int) and retired < since:
        problems.add(at / "retired", "is before since (DATA-R92)")
    return None if hunt_id is None else Hunt(hunt_id, record, at)


def read_hunts(root: Path, problems: Problems) -> HuntLayer:
    """root/data/hunts/hunts.toml, required (DATA-R85). The format (an unknown key or a wrong type, DATA-R63, and a
    missing name or title, DATA-R105) and every DATA-R92 check that needs nothing but the file go into problems:
    IDs and their patterns, repeats, unknown sets and classes, kinds, targets, minBand, tiers and dates. The checks
    that need the catalogue are check_hunts'."""
    layer = HuntLayer()
    document = read_toml(root, HUNTS_TOML, problems)
    if document is None:
        return layer
    check_keys(document, At(HUNTS_TOML), problems, required=(), optional=("set", "class", "hunt"))
    for table, at in _entries(document, "set", problems):
        hunt_set = _read_set(table, at, problems)
        if hunt_set is not None:
            layer.sets.append(hunt_set)
    for table, at in _entries(document, "class", problems):
        fixed = _read_class(table, at, problems)
        if fixed is not None:
            layer.classes.append(fixed)
    for table, at in _entries(document, "hunt", problems):
        hunt = _read_hunt(table, at, problems)
        if hunt is not None:
            layer.hunts.append(hunt)
    _check_unique("set", [(entry.id, entry.at) for entry in layer.sets], problems)
    _check_unique("class", [(entry.id, entry.at) for entry in layer.classes], problems)
    _check_unique("Hunt", [(entry.id, entry.at) for entry in layer.hunts], problems)
    set_ids = {entry.id for entry in layer.sets}
    class_ids = {entry.id for entry in layer.classes} | set(GENERATED_CLASSES)
    for hunt in layer.hunts:
        set_id, class_id = hunt.get("set"), hunt.get("class")
        if isinstance(set_id, str) and set_id not in set_ids:
            problems.add(hunt.at / "set", f"'{set_id}' isn't a set in {HUNTS_TOML} (DATA-R92)")
        if isinstance(class_id, str) and class_id not in class_ids:
            known = ", ".join(GENERATED_CLASSES)
            message = f"'{class_id}' is neither a [[class]] in {HUNTS_TOML} nor a generated class ({known})"
            problems.add(hunt.at / "class", f"{message} (DATA-R92)")
    return layer


def check_hunts(
    layer: HuntLayer,
    items: Mapping[int, Record],
    windows: Collection[str],
    auras: Collection[int],
    events: Collection[int],
    problems: Problems,
) -> None:
    """DATA-R92's checks that need the catalogue: a species target that isn't a Species ID (DATA-R19), a window that
    isn't one (DATA-R35), conditions naming an aura or event not on the lists (DATA-R38, DATA-R39), and a fixed
    class member that doesn't ship (DATA-R18, DATA-R90). items are the records that ship (DATA-R77)."""
    for fixed in layer.classes:
        for member in fixed.members:
            if member not in items:
                message = f"item {member} doesn't ship (it's uncharted or not in the catalogue), so no class can hold it"
                problems.add(fixed.at / "members", f"{message} (DATA-R18, DATA-R90)")
    for hunt in layer.hunts:
        species = hunt.get("species")
        if isinstance(species, int):
            record = items.get(species)
            of = record.get("species") if record is not None else None
            if of is None:
                problems.add(hunt.at / "species", f"{species} isn't a Species item (DATA-R19, DATA-R92)")
            elif of != species:
                problems.add(
                    hunt.at / "species", f"{species} is an item of Species {of}; target {of} (DATA-R19, DATA-R92)"
                )
        window = hunt.get("window")
        if isinstance(window, str) and window not in windows:
            problems.add(hunt.at / "window", f"'{window}' isn't a window ID (DATA-R35, DATA-R92)")
        conditions = hunt.get("conditions")
        if isinstance(conditions, Mapping):
            for field_name, listed, rule in (("auras", auras, "DATA-R39"), ("events", events, "DATA-R38")):
                values = conditions.get(field_name)
                for value in values if isinstance(values, list) else []:
                    if value not in listed:
                        what = "aura list" if field_name == "auras" else "event list"
                        problems.add(hunt.at / "conditions", f"{field_name}: {value} isn't on the {what} ({rule})")


def hunt_classes(layer: HuntLayer, items: Mapping[int, Record]) -> dict[str, dict[int, bool]]:
    """Every class as an item ID set (DATA-R90, DATA-R91): each fixed class as given, and the generated classes over
    every catalogue item that isn't Noise, removed items included. All are emitted, targeted or not."""
    counted = {item: record for item, record in items.items() if record.get("noise") is not True}

    def quality_at_least(least: int) -> dict[int, bool]:
        members: dict[int, bool] = {}
        for item, record in counted.items():
            quality = record.get("quality")  # an item with no known quality is in no quality class (DATA-R24)
            if isinstance(quality, int) and quality >= least:
                members[item] = True
        return members

    classes: dict[str, dict[int, bool]] = {
        QUALITY_UNCOMMON: quality_at_least(2),
        QUALITY_RARE: quality_at_least(3),
        SPECIES_ANY: {item: True for item, record in counted.items() if "species" in record},
    }
    for fixed in layer.classes:
        classes[fixed.id] = {member: True for member in fixed.members}
    return classes


def hunt_hash(record: Mapping[str, object]) -> str:
    """A Hunt's hash (DATA-R94): the lowercase hex SHA-256 of the canonical JSON (DATA-R70) of its emitted record
    without retired. Absent optional fields are absent from the record, and lore is never in it."""
    return sha256_hex(canonical({key: value for key, value in record.items() if key != "retired"}))


def build_hunt_list(layer: HuntLayer, items: Mapping[int, Record]) -> HuntList:
    """ns.huntList (DATA-R93) with its fingerprint (DATA-R72): the first 16 hex characters of the SHA-256 of the
    canonical JSON of the list without its fingerprint. Lore is never in it, so a wording change changes nothing."""
    sets: list[dict[str, object]] = [{"id": entry.id} for entry in layer.sets]
    hunts = [dict(hunt.record) for hunt in layer.hunts]
    classes = hunt_classes(layer, items)
    fingerprint = sha256_hex(canonical({"sets": sets, "hunts": hunts, "classes": classes}))[:FINGERPRINT_LENGTH]
    return {"fingerprint": fingerprint, "sets": sets, "hunts": hunts, "classes": classes}


def hunt_list_lua(hunt_list: HuntList, header: str) -> str:
    """HuntList.lua (DATA-R75, DATA-R93): the header (DATA-R6), Core's guard (CORE-R11, as in every Module file),
    then ns.huntList. Pagle_Hunts' TOC lists it after locale\\enUS.lua."""
    return f"{header}\n{CORE_GUARD}\n---@class PagleHuntsNS\nlocal ns = select(2, ...)\n\nns.huntList = {to_lua(hunt_list)}\n"
