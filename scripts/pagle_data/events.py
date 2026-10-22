"""Hunt Events in content data (DATA-R97-R99, ADR 0012): data/hunts/tags.toml, data/hunts/events/<event-id>.toml,
their checks, EventList.lua, each event Hunt's hash and the event list's fingerprint.

A Hunt Event is a definition without dates (ADR 0012): one or two zones, its tags, a skill range, whether the
fallback rotation may pick it, and 3-5 Hunts. An event Hunt is always imposed (HNT-R141): it has no set, kind, since
or retired, and its own conditions, which the event's zones narrow at runtime, so a Hunt may not name areas itself.
What each field means is hunts.md's; this module fixes the format, the checks and the emitted shape. An event's name
and note and each of its Hunts' names are lore that stays in the file (DATA-R97): never in a record, a hash or the
fingerprint. The fixed classes event Hunts target stay in hunts.toml (DATA-R98).
"""

from collections.abc import Collection, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import TypedDict

from pagle_data.areas import CatchLists
from pagle_data.catalogue import FINGERPRINT_LENGTH, canonical, sha256_hex
from pagle_data.confirmed import zone_of
from pagle_data.db2 import AREAS, Area
from pagle_data.errors import At, Problems
from pagle_data.hunts import (
    FIXED_CLASS,
    GENERATED_CLASSES,
    HUNT_ID,
    HuntLayer,
    HuntRecord,
    check_record,
    read_date,
    read_id,
    read_string,
    read_target,
    read_texts,
)
from pagle_data.items import Record
from pagle_data.lore import CORE_GUARD, Text
from pagle_data.lua import to_lua
from pagle_data.realm_time import STEP_MINUTES, Rules, is_open
from pagle_data.toml_reader import check_keys, describe, expect_ids, expect_table, read_toml
from pagle_data.universe import EVENTS_DIR, HUNTS_TOML, TAGS_TOML

EVENT_LIST_LUA = "addons/Pagle_Hunts/data/EventList.lua"

# DATA-R97: the kinds of tag, and the band tags the generator works out from the skill range.
TAG_KINDS = ("holiday", "time", "water", "band")
BAND_KIND = "band"
BANDS = ("low", "mid", "high")
# Tunables: the event skill bands, low up to 150, mid 151-275, high above 275 (DATA-R97, HNT-R156).
LOW_BAND_TOP = 150
MID_BAND_TOP = 275
# DATA-R97: 1-2 zones; IDs starting p_ are kept for pushed events (HNT-R140).
MIN_ZONES = 1
MAX_ZONES = 2
PUSHED_PREFIX = "p_"
# Tunables: event Hunts per event (DATA-R99).
MIN_HUNTS = 3
MAX_HUNTS = 5
# Tunables: rotating events per band, minimum (DATA-R99), checked once data/checks.toml's eventPool is on (DATA-R66).
ROTATING_PER_BAND = 8
# Tunables: an event Hunt's longest closed share of a run, half of 72 hours (DATA-R99, HNT-R142's default run).
RUN_MINUTES = 72 * 60
LONGEST_CLOSED_MINUTES = RUN_MINUTES // 2
# The fields the closed-stretch check reads (DATA-R99): time, and events forecast from their weekly rules (DATA-R38).
_RUN_FIELDS = ("time", "events")
# Any week will do: the time and events fields repeat weekly. 2026-01-04 is a Sunday, 00:00 realm time.
_WEEK_START = datetime(2026, 1, 4)
_WEEK_STEPS = 7 * 24 * 60 // STEP_MINUTES
_RUN_STEPS = RUN_MINUTES // STEP_MINUTES

# The keys of each table (Data: `data/hunts/events/<event-id>.toml` keys). The lore keys are read for their shape only.
_EVENT_REQUIRED = ("id", "zones", "tags", "name", "note")
_EVENT_OPTIONAL = ("skill", "rotation", "retired")
_HUNT_REQUIRED = ("id", "tiers", "name")
_HUNT_OPTIONAL = ("species", "class", "minBand", "conditions")
# A pushed huntEvent item's fields (hunts.md › Contracts: Pushed Hunt Events and runs), its kind and the version Hunts
# knows (PUSH-R21, Tunables); its Hunts' fields are an event file's [[hunt]] keys.
PUSHED_KIND = "huntEvent"
PUSHED_VERSION = 1
_PUSHED_REQUIRED = ("id", "zones", "tags", "skill", "rotation", "name", "note")

# An event's emitted record (DATA-R98): id, zones, tags, skill, band, rotation, retired?, hunts.
EventRecord = dict[str, object]


@dataclass(frozen=True)
class EventHunt:
    """An event's [[hunt]]: its emitted record (DATA-R98: id, species? or class?, minBand?, conditions? of its own,
    tiers), lore left out, and where it sits for a message."""

    id: str
    record: HuntRecord
    at: At

    def get(self, key: str) -> object:
        return self.record.get(key)


@dataclass(frozen=True)
class HuntEvent:
    """One event file as read (DATA-R97): its ID (the file name when the file's own isn't a string), zones, tags as
    given, skill as given (None when left out), rotation, retired date as a server time, Hunts in file order and the
    event's and its Hunts' text (lore)."""

    id: str
    file: str
    zones: tuple[int, ...]
    tags: tuple[str, ...]
    skill: tuple[int, int] | None
    rotation: bool
    retired: int | None
    hunts: tuple[EventHunt, ...]
    texts: tuple[Text, ...] = ()
    path: str = "event"  # where its fields sit in file: an event file's [event], a pushed item's top level ("")

    @property
    def at(self) -> At:
        return At(self.file, self.path)

    @property
    def rotating(self) -> bool:
        """Whether the fallback rotation may pick it: rotation = true and no retired date (DATA-R99, HNT-R152)."""
        return self.rotation and self.retired is None


@dataclass
class EventLayer:
    """data/hunts/tags.toml and data/hunts/events/ as read: the tags by ID with their kind, and the events in
    event-ID order (DATA-R98)."""

    tags: dict[str, str] = field(default_factory=dict)
    events: list[HuntEvent] = field(default_factory=list)

    def texts(self) -> dict[str, dict[str, Text]]:
        """Each event file's text by lore key, event.<id>.name, event.<id>.note and hunt.<id>.name (DATA-R97):
        Pagle_Hunts' lore that stays beside the definitions, by the file it sits in."""
        return {event.file: {text.key: text for text in event.texts} for event in self.events if event.texts}


class EventList(TypedDict):
    """ns.eventList (DATA-R98): the events in event-ID order, each with its Hunts."""

    fingerprint: str
    events: list[EventRecord]


def event_file(event_id: str) -> str:
    """An event's file, data/hunts/events/<event-id>.toml (DATA-R97)."""
    return f"{EVENTS_DIR}/{event_id}.toml"


def band_of(low: int) -> str:
    """An event's skill band from its skill range's lower end (DATA-R97, HNT-R156, Tunables)."""
    if low <= LOW_BAND_TOP:
        return "low"
    return "mid" if low <= MID_BAND_TOP else "high"


def read_tags(root: Path, problems: Problems, needed: bool) -> dict[str, str]:
    """root/data/hunts/tags.toml (DATA-R97): one [[tag]] per tag with id and kind, by ID. An unknown key, a repeated
    ID or an unknown kind is a problem, and the band tags are exactly the ones the generator works out. The file is
    required when needed (an event file exists); an absent one otherwise defines no tag."""
    tags: dict[str, str] = {}
    if not needed and not (root / TAGS_TOML).is_file():
        return tags
    document = read_toml(root, TAGS_TOML, problems)
    if document is None:
        return tags
    check_keys(document, At(TAGS_TOML), problems, required=(), optional=("tag",))
    entries = document.get("tag", [])
    if not isinstance(entries, list):
        problems.add(At(TAGS_TOML, "tag"), f"expected an array of tables ([[tag]]), got {describe(entries)}")
        return tags
    for index, entry in enumerate(entries):
        at = At(TAGS_TOML, f"tag[{index}]")
        table = expect_table(entry, at, problems)
        if table is None:
            continue
        check_keys(table, at, problems, required=("id", "kind"), optional=())
        tag_id = read_id(table, at, HUNT_ID, "[%w_]+", problems)
        kind = read_string(table, "kind", at, problems)
        if kind is not None and kind not in TAG_KINDS:
            kinds = f"{', '.join(TAG_KINDS[:-1])} or {TAG_KINDS[-1]}"
            problems.add(at / "kind", f"expected {kinds}, got '{kind}' (DATA-R97)")
            continue
        if tag_id is None or kind is None:
            continue
        if tag_id in tags:
            problems.add(at, f"the tag ID '{tag_id}' is used twice (DATA-R97)")
            continue
        if kind == BAND_KIND and tag_id not in BANDS:
            message = f"'{tag_id}' is a band tag the generator never works out; band tags are {', '.join(BANDS)}"
            problems.add(at, f"{message} (DATA-R97)")
            continue
        tags[tag_id] = kind
    for band in BANDS:
        if tags.get(band) != BAND_KIND:
            problems.add(At(TAGS_TOML), f"has no band tag '{band}', which the generator adds to events (DATA-R97)")
    return tags


def _skill(table: Mapping[str, object], at: At, problems: Problems) -> tuple[int, int] | None:
    """DATA-R97: skill = [low, high], two integers with low <= high, or None when left out or bad."""
    if "skill" not in table:
        return None
    value = table["skill"]
    if (
        isinstance(value, list)
        and len(value) == 2
        and all(isinstance(end, int) and not isinstance(end, bool) for end in value)
        and value[0] <= value[1]
    ):
        return (value[0], value[1])
    problems.add(at / "skill", f"expected [low, high], two integers with low <= high (DATA-R97), got {value!r}")
    return None


def _zones(table: Mapping[str, object], at: At, problems: Problems) -> tuple[int, ...]:
    """DATA-R97: zones are 1-2 areaIDs, none twice; whether each is a zone is check_events'."""
    if "zones" not in table:
        return ()
    value = table["zones"]
    zones = expect_ids(value, at / "zones", problems) or []
    if isinstance(value, list) and not MIN_ZONES <= len(value) <= MAX_ZONES:
        problems.add(at / "zones", f"has {len(value)} zones; an event has {MIN_ZONES} or {MAX_ZONES} (DATA-R97)")
    return tuple(zones)


def _tags(table: Mapping[str, object], at: At, tags: Mapping[str, str], problems: Problems) -> tuple[str, ...]:
    """DATA-R97: tags from tags.toml's closed list, none twice. A band tag that isn't the event's band is
    check_events'."""
    if "tags" not in table:
        return ()
    value = table["tags"]
    if not isinstance(value, list):
        problems.add(at / "tags", f"expected an array of tags, got {describe(value)}")
        return ()
    found: list[str] = []
    for tag in value:
        if not isinstance(tag, str):
            problems.add(at / "tags", f"expected a tag ID, got {describe(tag)}")
        elif tag not in tags:
            problems.add(at / "tags", f"'{tag}' isn't a tag in {TAGS_TOML} (DATA-R97)")
        elif tag in found:
            problems.add(at / "tags", f"'{tag}' is listed twice")
        else:
            found.append(tag)
    return tuple(found)


def _read_hunt(table: Mapping[str, object], at: At, problems: Problems) -> tuple[EventHunt | None, tuple[Text, ...]]:
    """An event's [[hunt]] (DATA-R97, DATA-R99): DATA-R92's Hunt checks that need nothing but the file, and no areas
    of its own (HNT-R141). Its name is lore, hunt.<id>.name."""
    check_keys(table, at, problems, required=_HUNT_REQUIRED, optional=_HUNT_OPTIONAL)
    hunt_id = read_id(table, at, HUNT_ID, "[%w_]+", problems)
    texts = read_texts("hunt", hunt_id, table, ("name",), at, problems)
    record: HuntRecord = {}
    if hunt_id is not None:
        record["id"] = hunt_id
    class_id = read_string(table, "class", at, problems)
    if class_id is not None:
        record["class"] = class_id
    read_target(table, record, at, problems)
    conditions = table.get("conditions")
    if isinstance(conditions, Mapping) and "areas" in conditions:
        message = "has an areas condition of its own; the event's zones supply it (HNT-R141, DATA-R99)"
        problems.add(at / "conditions", message)
    return (None if hunt_id is None else EventHunt(hunt_id, record, at)), texts


def _hunt_at(file: str, key: str, table: Mapping[str, object], index: int) -> At:
    """Where an event's Hunt sits, under key (an event file's [[hunt]], a pushed item's hunts): by its ID when it has a
    string one, else by its position."""
    hunt_id = table.get("id")
    return At(file, f"{key}.{hunt_id}" if isinstance(hunt_id, str) else f"{key}[{index}]")


def _event_id(table: Mapping[str, object], at: At, stem: str | None, problems: Problems) -> str | None:
    """DATA-R97: an event file's id matches its file name (stem) and [%w_]+, never starting p_; a pushed item's
    (stem None) matches [%w_]+ and starts p_ (HNT-R140). A non-string one is a problem, and the file name stands in
    for it."""
    event_id = read_string(table, "id", at, problems)
    if event_id is None:
        return stem
    if not HUNT_ID.fullmatch(event_id):
        problems.add(at / "id", f"'{event_id}' doesn't match [%w_]+ (DATA-R97)")
    if stem is None:
        if not event_id.startswith(PUSHED_PREFIX):
            message = f"'{event_id}' doesn't start with {PUSHED_PREFIX}; a pushed event's does (HNT-R140)"
            problems.add(at / "id", message)
        return event_id
    if event_id.startswith(PUSHED_PREFIX):
        problems.add(at / "id", f"'{event_id}' starts with {PUSHED_PREFIX}, which is kept for pushed events (DATA-R97)")
    if event_id != stem:
        problems.add(at / "id", f"'{event_id}' isn't the file's name, '{stem}' (DATA-R97)")
    return event_id


def _read_definition(
    table: Mapping[str, object],
    entries: object,
    at: At,
    hunts_key: str,
    stem: str | None,
    tags: Mapping[str, str],
    problems: Problems,
) -> HuntEvent | None:
    """An event's fields (table, sitting at at) and its Hunts (entries, under hunts_key), with every DATA-R97 and
    DATA-R99 check that needs nothing but the definition and the tag list: an event file's (stem its file name) or a
    pushed item's (stem None; which fields it may have is the caller's)."""
    file = at.file
    event_id = _event_id(table, at, stem, problems)
    texts = list(read_texts("event", event_id, table, ("name", "note"), at, problems))
    rotation = table.get("rotation", True)
    if not isinstance(rotation, bool):
        problems.add(at / "rotation", f"expected a boolean, got {describe(rotation)}")
        rotation = True
    retired = read_date(table, "retired", at, problems)

    if not isinstance(entries, list):
        problems.add(At(file, hunts_key), f"expected an array of tables ([[hunt]]), got {describe(entries)}")
        entries = []
    if not MIN_HUNTS <= len(entries) <= MAX_HUNTS:
        problems.add(At(file), f"has {len(entries)} Hunts; an event has {MIN_HUNTS} to {MAX_HUNTS} (DATA-R99)")
    hunts: list[EventHunt] = []
    for index, entry in enumerate(entries):
        hunt_table = expect_table(entry, At(file, f"{hunts_key}[{index}]"), problems)
        if hunt_table is None:
            continue
        hunt, hunt_texts = _read_hunt(hunt_table, _hunt_at(file, hunts_key, hunt_table, index), problems)
        texts.extend(hunt_texts)
        if hunt is not None:
            hunts.append(hunt)
    zones, event_tags, skill = _zones(table, at, problems), _tags(table, at, tags, problems), _skill(table, at, problems)
    if event_id is None:
        return None
    return HuntEvent(event_id, file, zones, event_tags, skill, rotation, retired, tuple(hunts), tuple(texts), at.path)


def _read_document(
    document: Mapping[str, object], file: str, stem: str, tags: Mapping[str, str], problems: Problems
) -> HuntEvent | None:
    """An <event-id>.toml's top-level table (DATA-R97): its [event] and [[hunt]] tables."""
    check_keys(document, At(file), problems, required=("event",), optional=("hunt",))
    at = At(file, "event")
    table = expect_table(document["event"], at, problems) if "event" in document else None
    if table is None:
        return None
    check_keys(table, at, problems, required=_EVENT_REQUIRED, optional=_EVENT_OPTIONAL)
    return _read_definition(table, document.get("hunt", []), at, "hunt", stem, tags, problems)


def _read_event(root: Path, path: Path, tags: Mapping[str, str], problems: Problems) -> HuntEvent | None:
    """One root/data/hunts/events/<event-id>.toml (DATA-R97), with every check that needs nothing but the file and
    the tag list."""
    file = f"{EVENTS_DIR}/{path.name}"
    document = read_toml(root, file, problems)
    return None if document is None else _read_document(document, file, path.stem, tags, problems)


def read_event_file(path: Path, tags: Mapping[str, str], problems: Problems) -> HuntEvent | None:
    """An <event-id>.toml anywhere (scripts/check-event.py, DATA-R99), named in problems by its path as given, with
    every check that needs nothing but the file and the tag list."""
    document = read_toml(Path(), str(path), problems)
    return None if document is None else _read_document(document, str(path), path.stem, tags, problems)


def read_pushed_event(item: object, file: str, tags: Mapping[str, str], problems: Problems) -> HuntEvent | None:
    """A pushed huntEvent item (hunts.md › Contracts) as data, from file: kind huntEvent at version 1 (PUSH-R21),
    exactly the Contracts fields (an id starting p_, a skill, rotation = false, hunts), then every check an event
    file gets that needs nothing but the definition and the tag list (DATA-R97, DATA-R99). Its fields are named from
    the item's top level, its Hunts as hunts.<id>."""
    at = At(file)
    table = expect_table(item, at, problems)
    if table is None:
        return None
    kind = table.get("kind")
    if kind != PUSHED_KIND:
        shown = f"'{kind}'" if isinstance(kind, str) else describe(kind)
        problems.add(at / "kind", f'expected "{PUSHED_KIND}", got {shown} (PUSH-R21)')
    version = table.get("v")
    if version != PUSHED_VERSION or isinstance(version, bool):
        known = f"the {PUSHED_KIND} version Hunts knows"
        problems.add(at / "v", f"expected {PUSHED_VERSION}, {known}, got {version!r} (PUSH-R21)")
    fields = {key: value for key, value in table.items() if key not in ("kind", "v", "hunts")}
    check_keys(fields, at, problems, required=_PUSHED_REQUIRED, optional=())
    if "hunts" not in table:
        problems.add(at, "missing key 'hunts'")
    if fields.get("rotation") is True:
        problems.add(at / "rotation", "true; a pushed event never enters the fallback rotation (hunts.md › Contracts)")
    return _read_definition(fields, table.get("hunts", []), at, "hunts", None, tags, problems)


def read_events(root: Path, problems: Problems) -> EventLayer:
    """root/data/hunts/tags.toml and every root/data/hunts/events/*.toml (DATA-R97); anything else there (a README)
    is ignored, and an absent directory is an empty pool. The format (an unknown key or a wrong type, DATA-R63) and
    every DATA-R97 and DATA-R99 check that needs nothing but the files go into problems; the checks that need the
    Hunt list are check_event_hunts', and those that need the catalogue check_events'."""
    directory = root / EVENTS_DIR
    paths = sorted(directory.glob("*.toml")) if directory.is_dir() else []
    layer = EventLayer(read_tags(root, problems, needed=bool(paths)))
    for path in paths:
        event = _read_event(root, path, layer.tags, problems)
        if event is not None:
            layer.events.append(event)
    layer.events.sort(key=lambda event: event.id.encode("utf-8"))  # DATA-R98: event-ID order, by byte (DATA-R62)
    return layer


def check_event_hunts(layer: EventLayer, hunts: HuntLayer, problems: Problems) -> None:
    """DATA-R99's Hunt checks that need the Hunt list (DATA-R92): every Hunt ID unique across hunts.toml and every
    event, and a class target that is a [[class]] in hunts.toml or a generated class (DATA-R98)."""
    ids = [(hunt.id, hunt.at) for hunt in hunts.hunts]
    ids += [(hunt.id, hunt.at) for event in layer.events for hunt in event.hunts]
    seen: set[str] = set()
    for hunt_id, at in ids:
        if hunt_id in seen and at.file != HUNTS_TOML:
            problems.add(at, f"the Hunt ID '{hunt_id}' is used twice (DATA-R92, DATA-R99)")
        seen.add(hunt_id)
    class_ids = {entry.id for entry in hunts.classes} | set(GENERATED_CLASSES)
    for event in layer.events:
        for hunt in event.hunts:
            class_id = hunt.get("class")
            if isinstance(class_id, str) and class_id not in class_ids:
                known = ", ".join(GENERATED_CLASSES)
                message = f"'{class_id}' is neither a [[class]] in {HUNTS_TOML} nor a generated class ({known})"
                problems.add(hunt.at / "class", f"{message} (DATA-R92, DATA-R98)")


def event_skill(event: HuntEvent, skill_bases: Mapping[int, int]) -> tuple[int, int] | None:
    """An event's skill (DATA-R97): as given, or the lowest and highest skill base among its zones (LOG-R55); None
    when a zone has none."""
    if event.skill is not None:
        return event.skill
    bases = [skill_bases.get(zone) for zone in event.zones]
    found = [base for base in bases if base is not None]
    if not event.zones or len(found) != len(bases):
        return None
    return (min(found), max(found))


@dataclass(frozen=True)
class RunOpenness:
    """How a condition spec's time-based fields fall across runs (DATA-R99), in minutes: the longest stretch it is
    closed, wrapping across realm midnight and the week's end, and the least time it is open in any 72-hour run."""

    longest_closed: int
    least_open: int


def run_openness(spec: Mapping[str, object], rules: Rules) -> RunOpenness:
    """A spec's RunOpenness over one week at the step (Tunables), read as Core's MatchesConditions reads it (LOG-R48,
    LOG-R50): its time, and its events forecast from their weekly rules (DATA-R38), an event without one never
    open. A run's dates aren't known, so season is left out, and so is every other field."""
    fields = {name: spec[name] for name in _RUN_FIELDS if name in spec}
    if not fields:
        return RunOpenness(0, RUN_MINUTES)
    steps = [
        int(is_open(fields, _WEEK_START + timedelta(minutes=STEP_MINUTES * step), rules)) for step in range(_WEEK_STEPS)
    ]
    longest = _WEEK_STEPS if not any(steps) else 0
    run = 0
    for step in steps + steps:  # twice round, so a closed stretch across the week's end counts whole
        run = 0 if step else run + 1
        longest = max(longest, min(run, _WEEK_STEPS))
    totals = [0]
    for step in steps + steps:
        totals.append(totals[-1] + step)
    least = min(totals[start + _RUN_STEPS] - totals[start] for start in range(_WEEK_STEPS))
    return RunOpenness(longest * STEP_MINUTES, least * STEP_MINUTES)


def _minutes_text(minutes: int) -> str:
    """Minutes as days, hours and minutes, the parts that aren't 0."""
    days, minutes = divmod(minutes, 24 * 60)
    hours, minutes = divmod(minutes, 60)
    parts = [(days, "day"), (hours, "hour"), (minutes, "minute")]
    return " ".join(f"{count} {unit}{'' if count == 1 else 's'}" for count, unit in parts if count) or "0 minutes"


def _where(zones: Sequence[int]) -> str:
    if len(zones) == 1:
        return f"zone {zones[0]} or its subzones"
    return f"zones {' and '.join(str(zone) for zone in zones)} or their subzones"


def _check_completes(
    event: HuntEvent,
    classes: Mapping[str, Mapping[int, bool]],
    items: Mapping[int, Record],
    listed: Collection[int],
    rules: Rules,
    problems: Problems,
) -> None:
    """DATA-R99: each Hunt can complete in the event's zones and their subzones (listed, the items their catch lists
    hold), and no time-based condition keeps it closed for more than half of a 72-hour run (Tunables)."""
    cannot = "so the Hunt can't complete there (DATA-R99)"
    for hunt in event.hunts:
        species, class_id = hunt.get("species"), hunt.get("class")
        if isinstance(species, int) and items.get(species, {}).get("species") == species:
            if not any(items.get(item, {}).get("species") == species for item in listed):
                problems.add(hunt.at / "species", f"Species {species} isn't listed in {_where(event.zones)}, {cannot}")
        if isinstance(class_id, str) and class_id in classes:
            if not set(classes[class_id]) & set(listed):
                what = "member" if FIXED_CLASS.fullmatch(class_id) else "item"
                message = f"no {what} of {class_id} is listed in {_where(event.zones)}, {cannot}"
                problems.add(hunt.at / "class", message)
        conditions = hunt.get("conditions")
        if not isinstance(conditions, Mapping):
            continue
        events = conditions.get("events")
        if isinstance(events, list) and any(entry not in rules for entry in events):
            continue  # an event not on the list is check_record's problem alone
        found = run_openness(conditions, rules)
        if found.longest_closed > LONGEST_CLOSED_MINUTES:
            message = (
                f"closed {_minutes_text(found.longest_closed)} running, more than half of a 72-hour run"
                f" ({LONGEST_CLOSED_MINUTES // 60} hours); a run can have it open as little as"
                f" {_minutes_text(found.least_open)} (DATA-R99)"
            )
            problems.add(hunt.at / "conditions", message)


def check_events(
    layer: EventLayer,
    classes: Mapping[str, Mapping[int, bool]],
    items: Mapping[int, Record],
    catch_lists: CatchLists,
    areas: Mapping[int, Area],
    auras: Collection[int],
    rules: Rules,
    event_pool: bool,
    problems: Problems,
) -> None:
    """DATA-R97's and DATA-R99's checks that need the catalogue: each zone a zone of the slice with a skill base when
    the skill is left out (LOG-R55), a band tag only the event's own, each Hunt's species and conditions (DATA-R92),
    and, for an event that isn't retired, each Hunt able to complete in its zones (a retired event never runs again
    and never changes, ADR 0005). With eventPool on (DATA-R66), each band needs the minimum of rotating events.
    classes are the Hunt list's (DATA-R91), items the records that ship (DATA-R77)."""
    rotating = dict.fromkeys(BANDS, 0)
    for event in layer.events:
        zones = [zone for zone in event.zones if zone in areas and areas[zone].parent == 0]
        for zone in event.zones:
            if zone not in zones:
                problems.add(event.at / "zones", f"area {zone} isn't a zone (parent 0) in {AREAS} (DATA-R97)")
        skill = event_skill(event, catch_lists.skill_bases)
        if event.skill is None:
            for zone in zones:
                if zone not in catch_lists.skill_bases:
                    message = f"zone {zone} has no skill base, so the skill can't be worked out"
                    problems.add(event.at / "zones", f"{message}; give skill = [low, high] (DATA-R97, LOG-R55)")
        if skill is not None:
            band = band_of(skill[0])
            for tag in event.tags:
                if layer.tags.get(tag) == BAND_KIND and tag != band:
                    message = f"'{tag}' is a band tag, and the event's band is {band}; the generator adds the band"
                    problems.add(event.at / "tags", f"{message} (DATA-R97)")
            if event.rotating:
                rotating[band] += 1
        for hunt in event.hunts:
            check_record(hunt.record, hunt.at, items, auras, rules.keys(), problems)
        if event.retired is None and len(zones) == len(event.zones):
            listed = {
                catch.item
                for area, catches in catch_lists.lists.items()
                if zone_of(areas, area) in zones
                for catch in catches
            }
            _check_completes(event, classes, items, listed, rules, problems)
    if event_pool:
        for band, count in rotating.items():
            if count < ROTATING_PER_BAND:
                message = (
                    f"the {band} band has {count} rotating events (rotation = true, not retired); the pool needs at"
                    f" least {ROTATING_PER_BAND} per band (DATA-R99)"
                )
                problems.add(At(EVENTS_DIR), message)


def event_hunt_hash(record: Mapping[str, object], event_id: str, zones: Sequence[int]) -> str:
    """An event Hunt's hash (DATA-R98, DATA-R94): the lowercase hex SHA-256 of the canonical JSON (DATA-R70) of its
    emitted record with its event's id, as event, and zones added. Lore is never in it."""
    return sha256_hex(canonical({**record, "event": event_id, "zones": list(zones)}))


def build_event_list(layer: EventLayer, skill_bases: Mapping[int, int]) -> EventList:
    """ns.eventList (DATA-R98) with its fingerprint (DATA-R72's, over the list without its fingerprint): each event's
    skill as given or worked out (DATA-R97), its band, and its tags with the band added. Lore is never in it. The
    layer must have passed every check, so each event has a skill."""
    events: list[EventRecord] = []
    for event in layer.events:
        skill = event_skill(event, skill_bases)
        if skill is None:
            raise ValueError(f"{event.file}: no skill; check_events reports it")
        band = band_of(skill[0])
        record: EventRecord = {
            "id": event.id,
            "zones": list(event.zones),
            "tags": [*event.tags, *([] if band in event.tags else [band])],
            "skill": list(skill),
            "band": band,
            "rotation": event.rotation,
            "hunts": [dict(hunt.record) for hunt in event.hunts],
        }
        if event.retired is not None:
            record["retired"] = event.retired
        events.append(record)
    fingerprint = sha256_hex(canonical({"events": events}))[:FINGERPRINT_LENGTH]
    return {"fingerprint": fingerprint, "events": events}


def event_hunt_hashes(event_list: EventList) -> dict[str, str]:
    """Every event Hunt's hash in the list by Hunt ID (DATA-R98)."""
    hashes: dict[str, str] = {}
    for event in event_list["events"]:
        zones, hunts = event["zones"], event["hunts"]
        assert isinstance(zones, list) and isinstance(hunts, list)
        for hunt in hunts:
            assert isinstance(hunt, Mapping)
            hashes[str(hunt["id"])] = event_hunt_hash(hunt, str(event["id"]), zones)
    return hashes


def event_list_lua(event_list: EventList, header: str) -> str:
    """EventList.lua (DATA-R75, DATA-R98): the header (DATA-R6), Core's guard (CORE-R11, as in every Module file),
    then ns.eventList. Pagle_Hunts' TOC lists it after data\\HuntList.lua."""
    return f"{header}\n{CORE_GUARD}\n---@class PagleHuntsNS\nlocal ns = select(2, ...)\n\nns.eventList = {to_lua(event_list)}\n"
