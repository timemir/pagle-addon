"""scripts/update-db2.py's command line (DATA-R12): downloads one Forever build's DB2 tables from wago.tools and
rewrites data/db2/ (DATA-R11): AreaTable gives areas.csv; ItemSparse joined with Item, cut to the item universe
(DATA-R15), gives items.csv; and build.toml. It is run by hand, in a PR; data edits that follow from the diff are made
by hand.
"""

import argparse
import csv
import io
import os
import re
import sys
import urllib.request
from collections.abc import Callable, Sequence
from pathlib import Path

from pagle_data.baseline import read_baseline
from pagle_data.db2 import (
    AREA_COLUMNS,
    AREAS,
    BUILD,
    ITEM_COLUMNS,
    ITEMS,
    Area,
    Db2Layer,
    Item,
    parse_areas,
    parse_table,
    read_build,
)
from pagle_data.toml_reader import Problems
from pagle_data.universe import item_universe

PROG = "update-db2"

# A Forever build as wago.tools names it: the version string, then the build number.
_BUILD = re.compile(r"([0-9]+\.[0-9]+\.[0-9]+)\.([1-9][0-9]*)")

# The products build.toml starts with (DATA-R128): Forever's beta builds sit under wow_classic_beta. After that,
# the dev keeps the list by hand and a run keeps it.
SEED_PRODUCTS = ["wow_classic_beta"]

Fetch = Callable[[str], bytes]


def table_url(table: str, build: str) -> str:
    """Where wago.tools serves one DB2 table of one build as CSV (DATA-R12)."""
    return f"https://wago.tools/db2/{table}/csv?build={build}"


def download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Pagle scripts/update-db2.py"})
    with urllib.request.urlopen(request, timeout=120) as response:
        body: bytes = response.read()
        return body


def areas_csv(areas: dict[int, Area]) -> str:
    """areas.csv (DATA-R11): the header, then one row per area sorted by ID."""
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(AREA_COLUMNS)
    for area_id in sorted(areas):
        area = areas[area_id]
        writer.writerow([area_id, area.parent, area.continent, area.name])
    return out.getvalue()


def items_csv(items: dict[int, Item]) -> str:
    """items.csv (DATA-R11): the header, then one row per item sorted by ID."""
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(ITEM_COLUMNS)
    for item_id in sorted(items):
        item = items[item_id]
        writer.writerow([item_id, item.class_id, item.subclass, item.quality, item.name])
    return out.getvalue()


def join_items(sparse: str, item: str, build: str, universe: frozenset[int], problems: Problems) -> dict[int, Item]:
    """The universe's items (DATA-R15) that both tables have (DATA-R12): the enUS name and quality from the
    ItemSparse CSV, ClassID and SubclassID from the Item CSV. Each table's problems go into problems."""
    sparse_at, item_at = f"ItemSparse {build}", f"Item {build}"
    names = parse_table(
        sparse, sparse_at, problems, integers=("ID", "OverallQualityID"), name="Display_lang", other_columns=True
    )
    classes = parse_table(
        item, item_at, problems, integers=("ID", "ClassID", "SubclassID"), name=None, other_columns=True
    )
    items: dict[int, Item] = {}
    for item_id in universe:
        if item_id in names and item_id in classes:
            (quality,), (class_id, subclass) = names[item_id].numbers, classes[item_id].numbers
            items[item_id] = Item(class_id, subclass, quality, names[item_id].name)
    return items


def build_toml(build: int, version: str, products: list[str]) -> str:
    """build.toml (DATA-R11)."""
    listed = ", ".join(f'"{product}"' for product in products)
    return (
        "# Written by scripts/update-db2.py (DATA-R11, DATA-R12): the Forever build data/db2/ describes.\n"
        f"build = {build}\n"
        f'version = "{version}"\n'
        f"products = [{listed}]\n"
    )


def _replace(path: Path, content: str) -> None:
    # Through a temporary file, so an interrupted run never leaves half a file.
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(path.name + ".partial")
    partial.write_bytes(content.encode("utf-8"))
    os.replace(partial, path)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/update-db2.py",
        description="Rewrite data/db2/ from one Forever build's DB2 tables on wago.tools (DATA-R11, DATA-R12).",
    )
    parser.add_argument("build", help="the build as wago.tools names it, e.g. 1.60.1.70338")
    return parser


def _fail(problems: list[str]) -> int:
    for problem in problems:
        print(f"{PROG}: {problem}", file=sys.stderr)
    print(f"{PROG}: {len(problems)} problem(s); wrote nothing", file=sys.stderr)
    return 1


def _universe(root: Path, problems: Problems) -> frozenset[int]:
    """The item universe of the repo at root (DATA-R15); empty, with problems, when its sources can't be read."""
    baseline = read_baseline(root, problems)
    if problems:
        return frozenset()
    return item_universe(root, baseline, problems)


def _tables(build: str, fetch: Fetch, failed: list[str]) -> dict[str, str]:
    """AreaTable, ItemSparse and Item as text, by table name; each one that can't be had is a line in failed."""
    tables: dict[str, str] = {}
    for table in ("AreaTable", "ItemSparse", "Item"):
        url = table_url(table, build)
        try:
            body = fetch(url)
        except OSError as error:
            failed.append(f"can't download {url}: {error}")
            continue
        try:
            tables[table] = body.decode("utf-8-sig")
        except UnicodeDecodeError as error:
            failed.append(f"can't read {url}: not UTF-8: {error}")
    return tables


def main(argv: Sequence[str], root: Path, fetch: Fetch = download) -> int:
    """Runs the command line on the repo at root, downloading with fetch; returns the exit code."""
    args = _parser().parse_args(argv)
    match = _BUILD.fullmatch(args.build)
    if match is None:
        return _fail([f"expected a build such as 1.60.1.70338 (version, then build number), got '{args.build}'"])
    version, build = match.group(1), int(match.group(2))

    problems = Problems()
    products = SEED_PRODUCTS
    if (root / BUILD).exists():
        current = Db2Layer()
        read_build(root, current, problems)
        products = current.products
    universe = _universe(root, problems)
    if problems:
        return _fail(problems.found)  # before downloading: without the universe, items.csv can't be cut

    failed: list[str] = []
    tables = _tables(args.build, fetch, failed)
    if failed:
        return _fail(failed)
    areas = parse_areas(tables["AreaTable"], f"AreaTable {args.build}", problems, other_columns=True)
    items = join_items(tables["ItemSparse"], tables["Item"], args.build, universe, problems)
    if problems:
        return _fail(problems.found)

    _replace(root / AREAS, areas_csv(areas))
    _replace(root / ITEMS, items_csv(items))
    _replace(root / BUILD, build_toml(build, version, products))
    print(f"{PROG}: wrote {AREAS} ({len(areas)} areas), {ITEMS} ({len(items)} items) and {BUILD} for {args.build}")
    missing = sorted(universe - items.keys())
    if missing:
        print(
            f"{PROG}: {len(missing)} item(s) of the universe not in DB2 (DATA-R24): {', '.join(map(str, missing))};"
            " items.toml may give their class and quality"
        )
    print(f"{PROG}: now run scripts/generate-data.py and commit data/db2/ with the regenerated files (DATA-R61)")
    return 0
