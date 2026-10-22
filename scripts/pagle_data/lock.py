"""The release lock (DATA-R95, ADR 0005): data/hunts/released.lock records each released Hunt's hash and retired
date, Standing Hunts' and event Hunts' alike (DATA-R98), and the members of each class a released Hunt targets.
scripts/generate-data.py --lock rewrites it when a release is tagged, from 1.0 on, and never before (DATA-R73): until
the 1.0 tag the committed lock stays empty.
"""

import re
from collections.abc import Collection, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.events import EventLayer, EventList, event_hunt_hash, event_hunt_hashes
from pagle_data.hunts import FIXED_CLASS, GENERATED_CLASSES, HuntLayer, HuntList, class_key, hunt_hash
from pagle_data.toml_reader import (
    check_keys,
    date_text,
    describe,
    expect_date,
    expect_ids,
    expect_table,
    read_toml,
)
from pagle_data.universe import EVENTS_DIR, HUNTS_TOML

LOCK = "data/hunts/released.lock"

# The lock's header comment, the whole of the committed file until the 1.0 tag (DATA-R73).
LOCK_HEADER = """\
# The release lock (DATA-R95, ADR 0005): each released Hunt's hash and retired date, and the members of each class a
# released Hunt targets. Written by scripts/generate-data.py --lock; don't edit it by hand.
# Run --lock only when a release is tagged, from 1.0 on, and never before: this file stays empty until the 1.0 tag
# (DATA-R73). The generator fails when data/hunts/hunts.toml breaks it (DATA-R96).
"""
_HASH = re.compile(r"[0-9a-f]{64}")


@dataclass(frozen=True)
class LockedHunt:
    """A [hunt.<id>] of the lock: the released Hunt's hash (DATA-R94) and its retired date as a server time."""

    hash: str
    retired: int | None
    at: At


@dataclass
class Lock:
    """released.lock as read (DATA-R95): the released Hunts by ID, and each locked class's members by class ID."""

    hunts: dict[str, LockedHunt] = field(default_factory=dict)
    classes: dict[str, tuple[int, ...]] = field(default_factory=dict)


def _tables(document: Mapping[str, object], key: str, problems: Problems) -> dict[str, Mapping[str, object]]:
    """The [<key>.<id>] tables of the lock by ID."""
    if key not in document:
        return {}
    outer = expect_table(document[key], At(LOCK, key), problems)
    found: dict[str, Mapping[str, object]] = {}
    for entry_id, value in (outer or {}).items():
        shown = f'"{entry_id}"' if key == "class" else entry_id
        table = expect_table(value, At(LOCK, f"{key}.{shown}"), problems)
        if table is not None:
            found[entry_id] = table
    return found


def _locked_hunt(table: Mapping[str, object], at: At, problems: Problems) -> LockedHunt | None:
    check_keys(table, at, problems, required=("hash",), optional=("retired",))
    value = table.get("hash")
    if "hash" in table and not (isinstance(value, str) and _HASH.fullmatch(value)):
        problems.add(at / "hash", f"expected 64 lowercase hex characters (DATA-R94), got {describe(value)}")
    retired = None
    if "retired" in table:
        retired = expect_date(table["retired"], at / "retired", problems)
        if retired is None:
            return None
    if not isinstance(value, str) or not _HASH.fullmatch(value):
        return None
    return LockedHunt(value, retired, at)


def read_lock(root: Path, problems: Problems) -> Lock:
    """root/data/hunts/released.lock (DATA-R95), or an empty lock when it's absent: an absent or empty lock checks
    nothing. An unknown key or a wrong type is a problem (DATA-R63)."""
    lock = Lock()
    if not (root / LOCK).is_file():
        return lock
    document = read_toml(root, LOCK, problems)
    if document is None:
        return lock
    check_keys(document, At(LOCK), problems, required=(), optional=("hunt", "class"))
    for hunt_id, table in _tables(document, "hunt", problems).items():
        locked = _locked_hunt(table, At(LOCK, f"hunt.{hunt_id}"), problems)
        if locked is not None:
            lock.hunts[hunt_id] = locked
    for class_id, table in _tables(document, "class", problems).items():
        at = At(LOCK, class_key(class_id))
        if class_id not in GENERATED_CLASSES and not FIXED_CLASS.fullmatch(class_id):
            problems.add(at, f"'{class_id}' is neither a fixed class ID nor a generated class (DATA-R90, DATA-R91)")
            continue
        check_keys(table, at, problems, required=("members",), optional=())
        members = expect_ids(table["members"], at / "members", problems) if "members" in table else None
        if members is not None:
            lock.classes[class_id] = tuple(members)
    return lock


def check_lock(lock: Lock, layer: HuntLayer, events: EventLayer, problems: Problems) -> None:
    """DATA-R96 (ADR 0005): against the lock, a locked Hunt is missing (deleted instead of retired), its hash differs,
    its locked retired date changed or was removed, or a locked fixed class lost a member. Generated classes can't
    lose one (DATA-R91, build_hunt_list). An event Hunt's hash is over its record and its event's id and zones, and
    a locked one missing or differing fails the same way (DATA-R98). An empty lock checks nothing."""
    hunts = {hunt.id: hunt for hunt in layer.hunts}
    event_hunts = {hunt.id: (event, hunt) for event in events.events for hunt in event.hunts}
    for hunt_id, locked in lock.hunts.items():
        if hunt_id in event_hunts and hunt_id not in hunts:
            event, event_hunt = event_hunts[hunt_id]
            if event_hunt_hash(event_hunt.record, event.id, event.zones) != locked.hash:
                message = (
                    "differs from the released Hunt (its hash, over its record and its event's id and zones, isn't the"
                    f" one in {LOCK}); a released event never changes: ship the fix as a new event and retire this one"
                )
                problems.add(event_hunt.at, f"{message} (DATA-R96, DATA-R98, ADR 0005)")
            continue
        hunt = hunts.get(hunt_id)
        if hunt is None:
            message = (
                f"the released Hunt is gone from {HUNTS_TOML} and {EVENTS_DIR}/; retire a Standing Hunt with a retired"
                " date instead, and an event leaves the pool by rotation = false and a retired date, never by"
                " deleting it"
            )
            problems.add(locked.at, f"{message} (DATA-R96, DATA-R98, ADR 0005)")
            continue
        if hunt_hash(hunt.record) != locked.hash:
            message = (
                f"differs from the released Hunt (its hash isn't the one in {LOCK}); a released Hunt never changes:"
                " ship the fix as a new Hunt and give this one a retired date"
            )
            problems.add(hunt.at, f"{message} (DATA-R96, ADR 0005)")
        retired = hunt.get("retired")
        if locked.retired is not None and retired != locked.retired:
            now = f"is {date_text(retired)}" if isinstance(retired, int) else "is gone"
            message = f"the released Hunt was retired on {date_text(locked.retired)} in {LOCK}, and the date {now}"
            problems.add(hunt.at / "retired", f"{message}; a locked retired date never changes (DATA-R96)")
    fixed = {entry.id: entry for entry in layer.classes}
    for class_id, members in lock.classes.items():
        if class_id in GENERATED_CLASSES:
            continue
        entry = fixed.get(class_id)
        if entry is None:
            message = f"the locked fixed class is gone from {HUNTS_TOML}; a class a released Hunt targets only grows"
            problems.add(At(LOCK, class_key(class_id)), f"{message} (DATA-R96, ADR 0005)")
            continue
        lost = [member for member in members if member not in entry.members]
        if lost:
            listed = ", ".join(str(member) for member in lost)
            message = f"lost {listed}, a member locked in {LOCK}; a class a released Hunt targets only grows"
            problems.add(entry.at / "members", f"{message} (DATA-R96, ADR 0005)")


def check_locked_members(lock: Lock, items: Collection[int], problems: Problems) -> None:
    """DATA-R91: a generated class keeps every member the lock records for it, so each must still ship, as a fixed
    class member must (DATA-R18, DATA-R90). items are the item IDs that ship."""
    for class_id, members in lock.classes.items():
        if class_id not in GENERATED_CLASSES:
            continue  # a fixed class's members are check_hunts' (DATA-R90)
        for member in members:
            if member not in items:
                message = f"item {member} is a locked member but doesn't ship (it's uncharted or not in the catalogue)"
                problems.add(At(LOCK, class_key(class_id)) / "members", f"{message}; keep it shipping (DATA-R91)")


def lock_toml(hunt_list: HuntList, event_list: EventList) -> str:
    """released.lock for the Hunt list and the event list, every Hunt in them counting as released (DATA-R95,
    DATA-R98): [hunt.<id>] with its hash (DATA-R94; an event Hunt's over its event's id and zones too) and a Standing
    Hunt's retired date if it has one, then [class."<classID>"] with the members (ascending) of each class a Hunt
    targets, fixed or generated, as emitted. Hunts and classes by ascending ID (DATA-R62)."""
    released = {str(record["id"]): (hunt_hash(record), record) for record in hunt_list["hunts"]}
    event_hashes = event_hunt_hashes(event_list)
    for event in event_list["events"]:
        hunts = event["hunts"]
        assert isinstance(hunts, list)
        for hunt in hunts:
            assert isinstance(hunt, dict)
            released[str(hunt["id"])] = (event_hashes[str(hunt["id"])], hunt)
    tables: list[str] = []
    targeted: set[str] = set()
    for hunt_id, (hunt_hash_, record) in sorted(released.items()):
        lines = [f"[hunt.{hunt_id}]", f'hash = "{hunt_hash_}"']
        retired = record.get("retired")
        if isinstance(retired, int):
            lines.append(f"retired = {date_text(retired)}")
        tables.append("\n".join(lines) + "\n")
        target = record.get("class")
        if isinstance(target, str):
            targeted.add(target)
    for class_id in sorted(targeted):
        members = ", ".join(str(member) for member in sorted(hunt_list["classes"].get(class_id, {})))
        tables.append(f"[{class_key(class_id)}]\nmembers = [{members}]\n")
    return LOCK_HEADER + "".join(f"\n{table}" for table in tables)
