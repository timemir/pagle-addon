"""The data/db2/ layer (DATA-R8 order 3, DATA-R11): the Forever client's DB2 slice for one build, written only by
scripts/update-db2.py (DATA-R12). So far that is build.toml and areas.csv; items.csv comes with items in M2.

The layer holds identity facts only (DATA-R2, DATA-R13): which areas exist, their parent and continent. Its enUS
names are kept for review and never reach a generated file (DATA-R3).
"""

import csv
import re
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.toml_reader import check_keys, describe, expect_int, read_toml

DB2 = "data/db2/"
BUILD = "data/db2/build.toml"
AREAS = "data/db2/areas.csv"

# areas.csv's columns, in order (DATA-R11): named as wago.tools names AreaTable's, the last being the enUS name.
AREA_COLUMNS = ("ID", "ParentAreaID", "ContinentID", "AreaName_lang")

_COUNT = re.compile(r"0|[1-9][0-9]*")


@dataclass(frozen=True)
class Area:
    """One AreaTable row (DATA-R25): parent is 0 for a zone; name is enUS, for review only (DATA-R3)."""

    parent: int
    continent: int
    name: str


@dataclass
class Db2Layer:
    build: int = 0
    version: str = ""
    products: list[str] = field(default_factory=list)
    areas: dict[int, Area] = field(default_factory=dict)


def parse_areas(text: str, file: str, problems: Problems, *, other_columns: bool) -> dict[int, Area]:
    """The areas in an AreaTable CSV: a header row naming AREA_COLUMNS, then one row per area. With other_columns,
    columns beyond those are ignored (wago.tools' full AreaTable); without, they are problems (areas.csv). Each bad
    row is a problem naming its line; the areas returned leave the bad rows out."""
    at = At(file)
    reader = csv.reader(text.splitlines(keepends=True), strict=True)
    try:
        header = next(reader, None)
    except csv.Error as error:
        problems.add(at, f"not a valid CSV: {error}")
        return {}
    if header is None:
        problems.add(at, "empty: expected a header row")
        return {}
    missing = [column for column in AREA_COLUMNS if column not in header]
    for column in missing:
        problems.add(at, f"missing column '{column}'")
    if not other_columns:
        for column in header:
            if column not in AREA_COLUMNS:
                problems.add(at, f"unknown column '{column}'")
    if missing:
        return {}
    index = {column: header.index(column) for column in AREA_COLUMNS}

    areas: dict[int, Area] = {}
    try:
        for row in reader:
            line = At(file, f"line {reader.line_num}")
            if len(row) != len(header):
                problems.add(line, f"expected {len(header)} fields, got {len(row)}: {','.join(row)}")
                continue
            numbers: dict[str, int] = {}
            for column in AREA_COLUMNS[:3]:
                value = row[index[column]]
                if _COUNT.fullmatch(value) and (column != "ID" or value != "0"):
                    numbers[column] = int(value)
                else:
                    kind = "a positive integer" if column == "ID" else "an integer of 0 or more"
                    problems.add(line, f"{column}: expected {kind}, got '{value}'")
            if len(numbers) < 3:
                continue
            area_id = numbers["ID"]
            if area_id in areas:
                problems.add(line, f"ID {area_id} is listed twice")
                continue
            areas[area_id] = Area(numbers["ParentAreaID"], numbers["ContinentID"], row[index["AreaName_lang"]])
    except csv.Error as error:
        problems.add(At(file, f"line {reader.line_num}"), f"not a valid CSV row: {error}")
    return areas


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


def _read_areas(root: Path, layer: Db2Layer, problems: Problems) -> None:
    try:
        text = (root / AREAS).read_text(encoding="utf-8")
    except FileNotFoundError:
        problems.add(At(AREAS), "missing")
        return
    except UnicodeDecodeError as error:
        problems.add(At(AREAS), f"not UTF-8: {error}")
        return
    layer.areas = parse_areas(text, AREAS, problems, other_columns=False)


def read_db2(root: Path, problems: Problems) -> Db2Layer:
    """The layer under root/data/db2/. Each problem found goes into problems; what was read is returned either way,
    and the caller must not use it while there are problems."""
    layer = Db2Layer()
    read_build(root, layer, problems)
    _read_areas(root, layer, problems)
    return layer
