"""The data/db2/ layer (DATA-R8 order 3, DATA-R11): the Forever client's DB2 slice for one build, written only by
scripts/update-db2.py (DATA-R12): build.toml, areas.csv and items.csv.

The layer holds identity facts only (DATA-R2, DATA-R13): which areas exist, their parent and continent, and each
item's class, subclass and quality. Its enUS names are kept for review and never reach a generated file (DATA-R3).
"""

import csv
import io
import re
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.toml_reader import check_keys, describe, expect_int, read_toml

DB2 = "data/db2/"
BUILD = "data/db2/build.toml"
AREAS = "data/db2/areas.csv"
ITEMS = "data/db2/items.csv"

# areas.csv's columns, in order (DATA-R11): named as wago.tools names AreaTable's, the last being the enUS name.
AREA_COLUMNS = ("ID", "ParentAreaID", "ContinentID", "AreaName_lang")

# items.csv's columns, in order (DATA-R11): ID, ClassID and SubclassID as wago.tools names Item's, then the quality
# and the enUS name as it names ItemSparse's (DATA-R12).
ITEM_COLUMNS = ("ID", "ClassID", "SubclassID", "OverallQualityID", "Display_lang")

_COUNT = re.compile(r"0|[1-9][0-9]*")


@dataclass(frozen=True)
class Area:
    """One AreaTable row (DATA-R25): parent is 0 for a zone; name is enUS, for review only (DATA-R3)."""

    parent: int
    continent: int
    name: str


@dataclass(frozen=True)
class Item:
    """One items.csv row: DB2's ClassID, SubclassID and quality (0 poor to 5 legendary, DATA-R77). name is enUS,
    for review and the trophy weight pattern (DATA-R21) only; it never ships (DATA-R3)."""

    class_id: int
    subclass: int
    quality: int
    name: str


@dataclass
class Db2Layer:
    build: int = 0
    version: str = ""
    products: list[str] = field(default_factory=list)
    areas: dict[int, Area] = field(default_factory=dict)
    items: dict[int, Item] = field(default_factory=dict)


@dataclass(frozen=True)
class Row:
    """A DB2 CSV row as parse_table reads it: the integer columns after ID, in the order asked for, and the name
    column ("" when none was asked for)."""

    numbers: tuple[int, ...]
    name: str


def parse_table(
    text: str, file: str, problems: Problems, *, integers: tuple[str, ...], name: str | None, other_columns: bool
) -> dict[int, Row]:
    """The rows of a DB2 CSV by ID: a header row naming the columns, then one row per record. integers are the
    integer columns, the first being ID (a positive integer) and the rest integers of 0 or more; name is the text
    column, if any. With other_columns, columns beyond those are ignored (wago.tools' full tables); without, they
    are problems (the slice's own files). Each bad row is a problem naming its line; the rows returned leave the
    bad rows out."""
    at = At(file)
    columns = integers + ((name,) if name is not None else ())
    reader = csv.reader(io.StringIO(text, newline=""), strict=True)
    try:
        header = next(reader, None)
    except csv.Error as error:
        problems.add(at, f"not a valid CSV: {error}")
        return {}
    if header is None:
        problems.add(at, "empty: expected a header row")
        return {}
    missing = [column for column in columns if column not in header]
    for column in missing:
        problems.add(at, f"missing column '{column}'")
    if not other_columns:
        for column in header:
            if column not in columns:
                problems.add(at, f"unknown column '{column}'")
    if missing:
        return {}
    index = {column: header.index(column) for column in columns}

    rows: dict[int, Row] = {}
    try:
        for cells in reader:
            line = At(file, f"line {reader.line_num}")
            if len(cells) != len(header):
                problems.add(line, f"expected {len(header)} fields, got {len(cells)}: {','.join(cells)}")
                continue
            numbers: list[int] = []
            for column in integers:
                value = cells[index[column]]
                if _COUNT.fullmatch(value) and (column != "ID" or value != "0"):
                    numbers.append(int(value))
                else:
                    kind = "a positive integer" if column == "ID" else "an integer of 0 or more"
                    problems.add(line, f"{column}: expected {kind}, got '{value}'")
            if len(numbers) < len(integers):
                continue
            row_id = numbers[0]
            if row_id in rows:
                problems.add(line, f"ID {row_id} is listed twice")
                continue
            rows[row_id] = Row(tuple(numbers[1:]), cells[index[name]] if name is not None else "")
    except csv.Error as error:
        problems.add(At(file, f"line {reader.line_num}"), f"not a valid CSV row: {error}")
    return rows


def parse_areas(text: str, file: str, problems: Problems, *, other_columns: bool) -> dict[int, Area]:
    """The areas in an AreaTable CSV: AREA_COLUMNS, as parse_table reads them."""
    rows = parse_table(
        text, file, problems, integers=AREA_COLUMNS[:3], name=AREA_COLUMNS[3], other_columns=other_columns
    )
    return {area_id: Area(row.numbers[0], row.numbers[1], row.name) for area_id, row in rows.items()}


def parse_items(text: str, file: str, problems: Problems) -> dict[int, Item]:
    """The items in an items.csv: ITEM_COLUMNS and no other, as parse_table reads them."""
    rows = parse_table(text, file, problems, integers=ITEM_COLUMNS[:4], name=ITEM_COLUMNS[4], other_columns=False)
    return {
        item_id: Item(row.numbers[0], row.numbers[1], row.numbers[2], row.name) for item_id, row in rows.items()
    }


def read_build(root: Path, layer: Db2Layer, problems: Problems) -> None:
    """build.toml's build, version and products (DATA-R11), into layer."""
    document = read_toml(root, BUILD, problems)
    if document is None:
        return
    at = At(BUILD)
    check_keys(document, at, problems, required=("build", "version", "products"), optional=())
    if "build" in document:
        layer.build = expect_int(document["build"], at / "build", problems, minimum=1) or 0
    if "version" in document:
        version = document["version"]
        if isinstance(version, str) and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
            layer.version = version
        else:
            got = f"'{version}'" if isinstance(version, str) else describe(version)
            problems.add(at / "version", f"expected a version string such as \"1.60.1\", got {got}")
    if "products" in document:
        products = document["products"]
        if isinstance(products, list) and products and all(isinstance(item, str) and item for item in products):
            layer.products = [str(item) for item in products]
        else:
            problems.add(at / "products", "expected a non-empty array of wago.tools product names")


def _read_text(root: Path, file: str, problems: Problems) -> str | None:
    try:
        return (root / file).read_text(encoding="utf-8")
    except FileNotFoundError:
        problems.add(At(file), "missing")
    except UnicodeDecodeError as error:
        problems.add(At(file), f"not UTF-8: {error}")
    return None


def read_db2(root: Path, problems: Problems) -> Db2Layer:
    """The layer under root/data/db2/. Each problem found goes into problems; what was read is returned either way,
    and the caller must not use it while there are problems."""
    layer = Db2Layer()
    read_build(root, layer, problems)
    areas = _read_text(root, AREAS, problems)
    if areas is not None:
        layer.areas = parse_areas(areas, AREAS, problems, other_columns=False)
    items = _read_text(root, ITEMS, problems)
    if items is not None:
        layer.items = parse_items(items, ITEMS, problems)
    return layer
