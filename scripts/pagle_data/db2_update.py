"""scripts/update-db2.py's command line (DATA-R12): downloads one Forever build's DB2 tables from wago.tools and
rewrites data/db2/ (DATA-R11). So far that is AreaTable, giving areas.csv, and build.toml; items.csv comes with items
in M2. It is run by hand, in a PR; data edits that follow from the diff are made by hand.
"""

import argparse
import re
import sys
import urllib.request
from collections.abc import Callable, Sequence
from pathlib import Path

from pagle_data.db2 import AREA_COLUMNS, AREAS, BUILD, Area, Db2Layer, parse_areas, read_build
from pagle_data.errors import Problems
from pagle_data.files import csv_text, write_atomic

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
    rows = [(area_id, area.parent, area.continent, area.name) for area_id, area in sorted(areas.items())]
    return csv_text(AREA_COLUMNS, rows)


def build_toml(build: int, version: str, products: list[str]) -> str:
    """build.toml (DATA-R11)."""
    listed = ", ".join(f'"{product}"' for product in products)
    return (
        "# Written by scripts/update-db2.py (DATA-R11, DATA-R12): the Forever build data/db2/ describes.\n"
        f"build = {build}\n"
        f'version = "{version}"\n'
        f"products = [{listed}]\n"
    )


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

    url = table_url("AreaTable", args.build)
    try:
        text = fetch(url).decode("utf-8-sig")
    except (OSError, UnicodeDecodeError) as error:
        return _fail([*problems.found, f"can't download {url}: {error}"])
    areas = parse_areas(text, f"AreaTable {args.build}", problems, other_columns=True)
    if problems:
        return _fail(problems.found)

    write_atomic(root / AREAS, areas_csv(areas).encode("utf-8"))
    write_atomic(root / BUILD, build_toml(build, version, products).encode("utf-8"))
    print(f"{PROG}: wrote {AREAS} ({len(areas)} areas) and {BUILD} for {args.build}")
    print(f"{PROG}: now run scripts/generate-data.py and commit data/db2/ with the regenerated files (DATA-R61)")
    return 0
