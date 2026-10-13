"""scripts/extract-baseline.py (DATA-R9): the one-time extraction of VMaNGOS's fishing data into data/baseline/.

Reads the world database (mangos.sqlite) of the SQLite dump with the standard library alone. Only rows valid for
the baseline patch are kept (Tunables: 1.12, VMaNGOS's highest patch index).
"""

import argparse
import csv
import hashlib
import io
import json
import sqlite3
import sys
import tempfile
import zipfile
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from pagle_data.baseline import BASELINE, COLUMNS

PROG = "extract-baseline"
BASELINE_PATCH = 10  # Tunables: "Baseline patch", 1.12, VMaNGOS's patch index 10

Cell = int | float | str | None


class ExtractError(Exception):
    """The dump holds something the baseline's CSVs can't say faithfully; nothing is written."""


def _in_patch(alias: str = "") -> str:
    prefix = f"{alias}." if alias else ""
    return f"{prefix}patch_min <= {BASELINE_PATCH} AND {prefix}patch_max >= {BASELINE_PATCH}"


def _number(value: int | float) -> str:
    # A chance as the dump holds it, without a trailing ".0": 100.0 is "100", 0.02 is "0.02".
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return repr(value)


def _cell(value: Cell) -> str:
    if value is None:
        return ""
    if isinstance(value, int | float):
        return _number(value)
    return value


def _csv(name: str, rows: Iterable[Sequence[Cell]]) -> str:
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(COLUMNS[name])
    writer.writerows([_cell(value) for value in row] for row in rows)
    return out.getvalue()


class _Conditions:
    """VMaNGOS's conditions table, read as DATA-R9 needs it: a loot row's condition is either exactly "game event
    E is active" for a baseline event, or text."""

    # VMaNGOS ConditionType values: -3 not, -2 or, -1 and (value1–value4 are condition IDs, 0 for none) and 12 game
    # event active (value1 the event). Flag 1 (CONDITION_FLAG_REVERSE_RESULT) negates any condition.
    _NOT, _OR, _AND, _EVENT = -3, -2, -1, 12
    _REVERSE = 1

    def __init__(self, db: sqlite3.Connection, events: Iterable[int]) -> None:
        self._rows: dict[int, tuple[int, int, int, int, int, int]] = {
            entry: (kind, v1, v2, v3, v4, flags)
            for entry, kind, v1, v2, v3, v4, flags in db.execute(
                "SELECT condition_entry, type, value1, value2, value3, value4, flags FROM conditions"
            )
        }
        self._events = frozenset(events)

    def event(self, condition: int) -> int | None:
        """E when the condition is exactly "game event E is active" for a baseline event, else None."""
        kind, event, *_, flags = self._row(condition)
        if kind == self._EVENT and flags == 0 and event in self._events:
            return event
        return None

    def text(self, condition: int, seen: frozenset[int] = frozenset()) -> str:
        """The condition written out: event(E), not(…), and(…, …), or(…, …), or typeT(v1, v2, v3, v4)."""
        if condition in seen:
            raise ExtractError(f"condition {condition} refers to itself")
        seen = seen | {condition}
        kind, v1, v2, v3, v4, flags = self._row(condition)
        if kind in (self._AND, self._OR, self._NOT):
            parts = [self.text(part, seen) for part in (v1, v2, v3, v4) if part != 0]
            name = {self._AND: "and", self._OR: "or", self._NOT: "not"}[kind]
            text = f"{name}({', '.join(parts)})"
        elif kind == self._EVENT:
            text = f"event({v1})"
        else:
            text = f"type{kind}({v1}, {v2}, {v3}, {v4})"
        if flags & self._REVERSE:
            text = f"not({text})"
        if flags & ~self._REVERSE:
            text = f"{text}[flags {flags}]"
        return text

    def _row(self, condition: int) -> tuple[int, int, int, int, int, int]:
        if condition not in self._rows:
            raise ExtractError(f"condition {condition} is not in the conditions table")
        return self._rows[condition]


# DATA-R9's events.csv: the day/night, season and Extravaganza game events.
EVENTS = (14, 15, 40, 45, 46, 47, 48)


def _events(db: sqlite3.Connection) -> list[tuple[int, str, int, int, str]]:
    listed = ", ".join(str(event) for event in EVENTS)
    out: list[tuple[int, str, int, int, str]] = []
    for event, start, occurrence, length, description in db.execute(
        "SELECT entry, start_time, occurence, length, description FROM game_event"
        f" WHERE entry IN ({listed}) AND {_in_patch()} ORDER BY entry"
    ):
        try:
            when = datetime.strptime(start, "%Y-%m-%d %H:%M:%S")
        except (TypeError, ValueError) as error:
            raise ExtractError(f"game_event {event}: start_time {start!r} is not YYYY-MM-DD HH:MM:SS") from error
        out.append((event, when.strftime("%Y-%m-%d %H:%M"), occurrence, length, description or ""))
    return out


@dataclass(frozen=True)
class _Loot:
    """A *_loot_template row valid for the baseline patch: an item, or a reference to another table."""

    entry: int
    item: int | None  # None for a reference row
    chance: float
    ref: int | None  # the referenced reference_loot_template entry
    condition: int  # 0 for none


def _loot(db: sqlite3.Connection, table: str) -> dict[int, list[_Loot]]:
    """A loot table's rows by entry, in item order. A reference row is VMaNGOS's mincountOrRef = -table."""
    out: dict[int, list[_Loot]] = {}
    for entry, item, chance, count_or_ref, condition in db.execute(
        f"SELECT entry, item, ChanceOrQuestChance, mincountOrRef, condition_id FROM {table}"
        f" WHERE {_in_patch()} ORDER BY entry, item"
    ):
        if count_or_ref < 0:
            row = _Loot(entry, None, chance, -count_or_ref, condition)
        else:
            row = _Loot(entry, item, chance, None, condition)
        out.setdefault(entry, []).append(row)
    return out


def _area_loot(loot: dict[int, list[_Loot]], conditions: _Conditions) -> list[tuple[Cell, ...]]:
    out: list[tuple[Cell, ...]] = []
    for rows in loot.values():
        for row in rows:
            event = conditions.event(row.condition) if row.condition else None
            text = conditions.text(row.condition) if row.condition and event is None else None
            out.append((row.entry, row.item, row.chance, row.ref, event, text))
    return out


def _flatten(references: dict[int, list[_Loot]], ref: int, path: tuple[int, ...] = ()) -> set[tuple[int, float]]:
    """The (item, chance) rows reference table ref holds, through nested references."""
    if ref in path:
        raise ExtractError(f"reference_loot_template {ref} refers to itself through {path}")
    found: set[tuple[int, float]] = set()
    for row in references.get(ref, []):
        if row.condition:
            # reference_loot.csv has no condition column (DATA-R9), so such a row can't be said faithfully.
            raise ExtractError(f"reference_loot_template {ref}: a row has condition {row.condition}")
        if row.ref is not None:
            found |= _flatten(references, row.ref, (*path, ref))
        elif row.item is not None:
            found.add((row.item, row.chance))
    return found


FISHING_POOL = 25  # gameobject_template type GAMEOBJECT_TYPE_FISHINGHOLE


@dataclass(frozen=True)
class _Pool:
    entry: int
    name: str
    loot: int  # data1, its gameobject_loot_template entry
    event: int | None


def _pools(db: sqlite3.Connection) -> list[_Pool]:
    """Fishing pools (DATA-R9): each type 25 template as of the baseline patch, with the event its spawns belong to."""
    templates: dict[int, tuple[int, str, int]] = {}
    for entry, kind, name, loot in db.execute(
        "SELECT entry, type, name, data1 FROM gameobject_template"
        f" WHERE patch <= {BASELINE_PATCH} ORDER BY entry, patch"
    ):
        templates[entry] = (kind, name, loot)  # the latest patch's row wins
    spawn_events: dict[int, set[int | None]] = {}
    for entry, event in db.execute(
        "SELECT g.id, e.event FROM gameobject g LEFT JOIN game_event_gameobject e ON e.guid = g.guid"
        f" WHERE {_in_patch('g')}"
    ):
        spawn_events.setdefault(entry, set()).add(event)
    pools: list[_Pool] = []
    for entry, (kind, name, loot) in sorted(templates.items()):
        if kind != FISHING_POOL:
            continue
        events = spawn_events.get(entry, {None})
        if len(events) > 1:
            # pools.csv has one event per pool; spawns split across events can't be said faithfully.
            listed = ", ".join("none" if event is None else str(event) for event in sorted(events, key=str))
            raise ExtractError(f"gameobject_template {entry}: its spawns belong to different events ({listed})")
        (event,) = events
        if event is not None and event < 0:
            raise ExtractError(f"gameobject_template {entry}: its spawns despawn during event {-event}")
        pools.append(_Pool(entry, name, loot, event))
    return pools


def _pool_loot(pools: list[_Pool], loot: dict[int, list[_Loot]]) -> dict[int, list[_Loot]]:
    """Each pool's loot rows, keyed by the pool's entry (DATA-R9's pool_loot.csv)."""
    out: dict[int, list[_Loot]] = {}
    for pool in pools:
        for row in loot.get(pool.loot, []):
            if row.condition:
                # pool_loot.csv has no event or condition column (DATA-R9).
                raise ExtractError(f"gameobject_loot_template {pool.loot}: a row has condition {row.condition}")
            out.setdefault(pool.entry, []).append(_Loot(pool.entry, row.item, row.chance, row.ref, 0))
    return out


def _reference_loot(references: dict[int, list[_Loot]], *tables: dict[int, list[_Loot]]) -> list[tuple[Cell, ...]]:
    """Every reference table the given loot tables refer to, flattened (DATA-R9)."""
    refs = sorted({row.ref for table in tables for rows in table.values() for row in rows if row.ref is not None})
    return [(ref, item, chance) for ref in refs for item, chance in sorted(_flatten(references, ref))]


def extract(database: Path) -> dict[str, str]:
    """The baseline's CSVs (DATA-R9), by file name, from the VMaNGOS world database at database (read only)."""
    db = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    try:
        events = _events(db)
        conditions = _Conditions(db, (row[0] for row in events))
        area_loot = _loot(db, "fishing_loot_template")
        references = _loot(db, "reference_loot_template")
        pools = _pools(db)
        pool_loot = _pool_loot(pools, _loot(db, "gameobject_loot_template"))
        return {
            "area_loot.csv": _csv("area_loot.csv", _area_loot(area_loot, conditions)),
            "reference_loot.csv": _csv("reference_loot.csv", _reference_loot(references, area_loot, pool_loot)),
            "pools.csv": _csv("pools.csv", [(pool.entry, pool.name, pool.event) for pool in pools]),
            "pool_loot.csv": _csv(
                "pool_loot.csv",
                [(row.entry, row.item, row.chance, row.ref) for rows in pool_loot.values() for row in rows],
            ),
            "skill.csv": _csv(
                "skill.csv", db.execute("SELECT entry, skill FROM skill_fishing_base_level ORDER BY entry")
            ),
            "events.csv": _csv("events.csv", events),
        }
    finally:
        db.close()


@dataclass(frozen=True)
class Snapshot:
    """The VMaNGOS release asset the baseline comes from (DATA-R9, Tunables: "Baseline snapshot")."""

    tag: str
    date: date
    url: str
    sha256: str  # of the asset, the zip the dump is in
    database: str = "sqlite-dump/mangos.sqlite"  # the world database, inside the zip


# The #57 decision: VMaNGOS db_latest of 2026-09-28 at commit 4641790, SQLite variant. The dev's audit archive keeps
# the asset (G:\dev\pagle-archive\vmangos\db_latest-4641790\); its SHA-256 matches GitHub's asset digest.
SNAPSHOT = Snapshot(
    tag="db_latest@4641790",
    date=date(2026, 9, 28),
    url="https://github.com/vmangos/core/releases/download/db_latest/db-sqlite-4641790.zip",
    sha256="bb2f1dd69171043a52657574f54948fd30941530fdc6eec12bce62c655428501",
)


def source_toml(snapshot: Snapshot, csvs: dict[str, str]) -> str:
    """data/baseline/source.toml (DATA-R9; keys under Data in docs/spec/content-data.md)."""
    lines = [
        "# The VMaNGOS snapshot data/baseline/ was extracted from, by scripts/extract-baseline.py (DATA-R9), and the",
        "# SHA-256 of each CSV. Never edited: the generator fails if a CSV's hash differs from this file (DATA-R63).",
        f"tag = {json.dumps(snapshot.tag)}",
        f"date = {snapshot.date.isoformat()}",
        f"url = {json.dumps(snapshot.url)}",
        f"dumpSha256 = {json.dumps(snapshot.sha256)}",
        "",
        "[sha256]",
    ]
    for name, text in sorted(csvs.items()):
        lines.append(f"{json.dumps(name)} = {json.dumps(hashlib.sha256(text.encode('utf-8')).hexdigest())}")
    return "\n".join(lines) + "\n"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(dump: Path, root: Path, snapshot: Snapshot) -> list[str]:
    """Extracts the dump into root/data/baseline/; returns the files written, relative to root. Writes nothing and
    raises ExtractError if the dump isn't the snapshot's or the baseline already exists."""
    baseline = root / BASELINE
    if baseline.exists():
        raise ExtractError(f"{BASELINE}/ exists; the baseline is extracted once and never edited (DATA-R9)")
    actual = _sha256(dump)
    if actual != snapshot.sha256:
        raise ExtractError(f"{dump}: SHA-256 is {actual}, not {snapshot.sha256} ({snapshot.tag})")
    # The dump is read only: its database is unzipped into a temporary directory, never next to the dump.
    with tempfile.TemporaryDirectory(prefix="extract-baseline-") as scratch:
        try:
            with zipfile.ZipFile(dump) as archive:
                database = Path(archive.extract(snapshot.database, scratch))
        except (zipfile.BadZipFile, KeyError) as error:
            raise ExtractError(f"{dump}: no {snapshot.database} in it ({error})") from error
        csvs = extract(database)
    files = {**csvs, "source.toml": source_toml(snapshot, csvs)}
    baseline.mkdir(parents=True)
    for name, text in sorted(files.items()):
        (baseline / name).write_bytes(text.encode("utf-8"))
    return [f"{BASELINE}/{name}" for name in sorted(files)]


def main(argv: Sequence[str], root: Path, snapshot: Snapshot = SNAPSHOT) -> int:
    """Runs the command line on the repo at root; returns the exit code."""
    parser = argparse.ArgumentParser(
        prog="scripts/extract-baseline.py",
        description=f"Extract data/baseline/ from the VMaNGOS dump {snapshot.tag} (DATA-R9). Run once.",
    )
    parser.add_argument("dump", type=Path, help=f"the release asset, {snapshot.url.rsplit('/', 1)[-1]}")
    args = parser.parse_args(argv)
    try:
        written = run(args.dump, root, snapshot)
    except ExtractError as error:
        print(f"{PROG}: {error}; wrote nothing", file=sys.stderr)
        return 1
    for path in written:
        print(f"{PROG}: wrote {path}")
    return 0
