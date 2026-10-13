"""The data/baseline/ layer (DATA-R8 order 1, DATA-R9): the VMaNGOS snapshot's CSVs and source.toml.

scripts/extract-baseline.py writes it once; after that nobody edits it, and the generator fails if any CSV's
SHA-256 differs from source.toml (DATA-R63). The chance column is never read here, so no chance can reach a
generated file (DATA-R4).
"""

import csv
import hashlib
import io
import re
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path

from pagle_data.toml_reader import At, Problems, check_keys, describe, read_toml

BASELINE = "data/baseline"
SOURCE = f"{BASELINE}/source.toml"
AREA_LOOT = f"{BASELINE}/area_loot.csv"

# Each CSV and its columns, in DATA-R9's order.
COLUMNS: dict[str, tuple[str, ...]] = {
    "area_loot.csv": ("area", "item", "chance", "ref", "event", "condition"),
    "reference_loot.csv": ("ref", "item", "chance"),
    "pools.csv": ("entry", "name", "event"),
    "pool_loot.csv": ("entry", "item", "chance", "ref"),
    "skill.csv": ("area", "skillBase"),
    "events.csv": ("event", "start", "occurrence", "length", "description"),
}

_SHA256 = re.compile(r"[0-9a-f]{64}")
_INTEGER = re.compile(r"-?(0|[1-9][0-9]*)")


@dataclass(frozen=True)
class AreaLoot:
    """An area_loot.csv row: an item, or a reference table (ref), gated by event or ungated with condition text."""

    area: int
    item: int | None
    ref: int | None
    event: int | None
    condition: str


@dataclass(frozen=True)
class ReferenceLoot:
    ref: int
    item: int


@dataclass(frozen=True)
class Pool:
    entry: int
    name: str
    event: int | None


@dataclass(frozen=True)
class PoolLoot:
    entry: int
    item: int | None
    ref: int | None


@dataclass(frozen=True)
class BaselineEvent:
    event: int
    start: str  # YYYY-MM-DD HH:MM, as VMaNGOS has it
    occurrence: int  # minutes
    length: int  # minutes
    description: str


@dataclass
class BaselineLayer:
    """data/baseline/ as the generator reads it: every column but chance."""

    area_loot: list[AreaLoot] = field(default_factory=list)
    reference_loot: list[ReferenceLoot] = field(default_factory=list)
    pools: list[Pool] = field(default_factory=list)
    pool_loot: list[PoolLoot] = field(default_factory=list)
    skill: dict[int, int] = field(default_factory=dict)  # area → skill base
    events: list[BaselineEvent] = field(default_factory=list)


def conditional_rows(layer: BaselineLayer) -> list[AreaLoot]:
    """The area_loot.csv rows with a condition that isn't a single event (DATA-R9). Their `event` is empty, so
    nothing gates them: they are treated as ungated, and the generator prints each one as a warning (DATA-R64)."""
    return [row for row in layer.area_loot if row.condition != ""]


class _Row:
    """One CSV line's cells by column, reporting a bad cell as a problem at its line."""

    def __init__(self, cells: dict[str, str], at: At, problems: Problems) -> None:
        self.cells = cells
        self.at = at
        self.problems = problems
        self.ok = True

    def text(self, column: str) -> str:
        return self.cells[column]

    def optional_integer(self, column: str) -> int | None:
        value = self.cells[column]
        if value == "":
            return None
        if not _INTEGER.fullmatch(value):
            self.problems.add(self.at, f"{column}: expected an integer, got '{value}'")
            self.ok = False
            return None
        return int(value)

    def integer(self, column: str) -> int:
        value = self.optional_integer(column)
        if value is None:
            if self.ok:
                self.problems.add(self.at, f"{column}: expected an integer, got nothing")
                self.ok = False
            return 0
        return value

    def item_or_ref(self) -> tuple[int | None, int | None]:
        item, ref = self.optional_integer("item"), self.optional_integer("ref")
        if self.ok and (item is None) == (ref is None):
            self.problems.add(self.at, "expected an item or a ref, not both or neither")
            self.ok = False
        return item, ref


def _rows(name: str, text: str, problems: Problems) -> Iterator[_Row]:
    """The rows of a baseline CSV under DATA-R9's header for it."""
    file = f"{BASELINE}/{name}"
    columns = COLUMNS[name]
    lines = csv.reader(io.StringIO(text, newline=""))
    header = next(lines, None)
    if header is None or tuple(header) != columns:
        problems.add(At(file, "line 1"), f"expected the columns {','.join(columns)}")
        return
    for number, cells in enumerate(lines, start=2):
        at = At(file, f"line {number}")
        if len(cells) != len(columns):
            problems.add(at, f"expected {len(columns)} cells, got {len(cells)}")
            continue
        yield _Row(dict(zip(columns, cells, strict=True)), at, problems)


def _area_loot(row: _Row, layer: BaselineLayer) -> None:
    area = row.integer("area")
    item, ref = row.item_or_ref()
    event = row.optional_integer("event")
    if row.ok:
        layer.area_loot.append(AreaLoot(area, item, ref, event, row.text("condition")))


def _reference_loot(row: _Row, layer: BaselineLayer) -> None:
    ref, item = row.integer("ref"), row.integer("item")
    if row.ok:
        layer.reference_loot.append(ReferenceLoot(ref, item))


def _pool(row: _Row, layer: BaselineLayer) -> None:
    entry, event = row.integer("entry"), row.optional_integer("event")
    if row.ok:
        layer.pools.append(Pool(entry, row.text("name"), event))


def _pool_loot(row: _Row, layer: BaselineLayer) -> None:
    entry = row.integer("entry")
    item, ref = row.item_or_ref()
    if row.ok:
        layer.pool_loot.append(PoolLoot(entry, item, ref))


def _skill(row: _Row, layer: BaselineLayer) -> None:
    area, skill_base = row.integer("area"), row.integer("skillBase")
    if row.ok:
        layer.skill[area] = skill_base


def _event(row: _Row, layer: BaselineLayer) -> None:
    event, occurrence, length = row.integer("event"), row.integer("occurrence"), row.integer("length")
    if row.ok:
        layer.events.append(BaselineEvent(event, row.text("start"), occurrence, length, row.text("description")))


_READERS: dict[str, Callable[[_Row, BaselineLayer], None]] = {
    "area_loot.csv": _area_loot,
    "reference_loot.csv": _reference_loot,
    "pools.csv": _pool,
    "pool_loot.csv": _pool_loot,
    "skill.csv": _skill,
    "events.csv": _event,
}


def _expect_sha256(value: object, at: At, problems: Problems) -> str | None:
    if isinstance(value, str) and _SHA256.fullmatch(value):
        return value
    shown = f"'{value}'" if isinstance(value, str) else describe(value)
    problems.add(at, f"expected 64 lowercase hex characters, got {shown}")
    return None


def _read_source(root: Path, problems: Problems) -> dict[str, str] | None:
    """source.toml's CSV hashes by file name, checking its keys and types (DATA-R9, DATA-R63); None if unreadable."""
    document = read_toml(root, SOURCE, problems)
    if document is None:
        return None
    at = At(SOURCE)
    check_keys(document, at, problems, required=("tag", "date", "url", "dumpSha256", "sha256"), optional=())
    for key in ("tag", "url"):
        if key in document and not isinstance(document[key], str):
            problems.add(at / key, f"expected a string, got {describe(document[key])}")
    if "date" in document:
        value = document["date"]
        if not isinstance(value, date) or isinstance(value, datetime):
            problems.add(at / "date", f"expected a date, got {describe(value)}")
    if "dumpSha256" in document:
        _expect_sha256(document["dumpSha256"], at / "dumpSha256", problems)
    hashes: dict[str, str] = {}
    table = document.get("sha256", {})
    if not isinstance(table, Mapping):
        problems.add(at / "sha256", f"expected a table, got {describe(table)}")
        return hashes
    check_keys(table, at / "sha256", problems, required=tuple(COLUMNS), optional=())
    for name in COLUMNS:
        if name in table:
            value = _expect_sha256(table[name], At(SOURCE, f'sha256."{name}"'), problems)
            if value is not None:
                hashes[name] = value
    return hashes


def read_baseline(root: Path, problems: Problems) -> BaselineLayer:
    """The layer under root/data/baseline/. A CSV whose SHA-256 differs from source.toml is a problem and isn't
    read (DATA-R9). Each problem found goes into problems; the caller must not use the layer while there are any."""
    layer = BaselineLayer()
    hashes = _read_source(root, problems)
    directory = root / BASELINE
    if directory.is_dir():
        for path in sorted(directory.iterdir()):
            if path.name not in COLUMNS and path.name != "source.toml":
                problems.add(At(f"{BASELINE}/{path.name}"), "not a baseline file (DATA-R9)")
    for name, reader in _READERS.items():
        file = f"{BASELINE}/{name}"
        try:
            data = (root / file).read_bytes()
        except FileNotFoundError:
            problems.add(At(file), "missing")
            continue
        if hashes is None or name not in hashes:
            continue  # source.toml's problem is reported already; without its hash the file can't be trusted
        if hashlib.sha256(data).hexdigest() != hashes[name]:
            problems.add(
                At(file),
                f"its SHA-256 differs from {SOURCE}; the baseline is never edited (DATA-R9), so fix VMaNGOS"
                " errors in data/forever/",
            )
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError as error:
            problems.add(At(file), f"not UTF-8: {error}")
            continue
        for row in _rows(name, text, problems):
            reader(row, layer)
    return layer
