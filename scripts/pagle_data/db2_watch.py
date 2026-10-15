"""scripts/db2-watch.py's command line, the DB2 watch (DATA-R128 to DATA-R130): looks on wago.tools for a Forever
build newer than the one data/db2/ describes and, when there is one, writes the issue that lists what changed in the
DB2 tables Pagle cares about. .github/workflows/db2-watch.yml runs it weekly and opens the issue with gh; the watch
itself never edits data/ (DATA-R130).
"""

import argparse
import json
import re
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from pagle_data.db2 import Area, Db2Layer, Item, Row, parse_areas, parse_table, read_db2
from pagle_data.db2_update import Fetch, download, download_tables, repo_universe
from pagle_data.errors import At, Problems, fail
from pagle_data.files import write_atomic
from pagle_data.markdown import md_text

PROG = "db2-watch"
OPENED_NOTHING = "opened nothing"

BUILDS_URL = "https://wago.tools/api/builds"

# What the watch writes into --out for the workflow: the issue's title and its body.
TITLE_FILE = "title.txt"
BODY_FILE = "body.md"

# GitHub refuses an issue body over 65,536 characters; the watch cuts its lists below that, and the run's log keeps
# the whole body.
BODY_LIMIT = 60_000
CUT_NOTE = "**The list is cut here: it's longer than an issue holds. The watch's run log has all of it.**"

# The watch keywords (Tunables, DATA-R129): each matches a whole word of an enUS name, ignoring case.
WATCH_KEYWORDS = ("Fish", "Fishing", "Lure", "Bait", "Angler", "Pool", "School", "Extravaganza")
_KEYWORD = re.compile(r"\b(?:" + "|".join(WATCH_KEYWORDS) + r")\b", re.IGNORECASE)

# A build as wago.tools names it: major.minor.patch, then the build number.
_BUILD = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)\.([1-9][0-9]*)")

# The tables the watch downloads: the new build's (DATA-R128), and the recorded build's for what data/db2/ doesn't
# keep (DATA-R129): SpellName and HolidayNames, and ItemSparse, for which items are new to DB2 outside the universe.
NEW_TABLES = ("AreaTable", "ItemSparse", "Item", "SpellName", "HolidayNames")
RECORDED_TABLES = ("ItemSparse", "SpellName", "HolidayNames")

# One part of the issue body: a heading, then its lists, each a lead line and its entries.
Section = tuple[str, list[tuple[str, list[str]]]]


@dataclass(frozen=True)
class Build:
    """One build in the builds API: its full name (e.g. "1.60.1.70338"), its version line ("1.60", the major and
    minor), its build number and the product that lists it."""

    name: str
    line: str
    number: int
    product: str


def parse_build(name: str, product: str) -> Build | None:
    match = _BUILD.fullmatch(name)
    if match is None:
        return None
    major, minor, _, number = match.groups()
    return Build(name, f"{int(major)}.{int(minor)}", int(number), product)


def has_keyword(name: str) -> bool:
    """Whether an enUS name holds a watch keyword as a whole word, ignoring case (DATA-R129)."""
    return _KEYWORD.search(name) is not None


def listed_builds(answer: bytes, products: Sequence[str], problems: Problems) -> list[Build]:
    """The builds the API lists under products. A product the answer lacks, or an answer that isn't the API's
    shape, is a problem; an entry whose version isn't a build name is skipped."""
    at = At(BUILDS_URL)
    try:
        document = json.loads(answer.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        problems.add(at, f"not JSON: {error}")
        return []
    if not isinstance(document, dict):
        problems.add(at, "expected an object of products")
        return []
    builds: list[Build] = []
    for product in products:
        entries = document.get(product)
        if not isinstance(entries, list):
            problems.add(at, f"lists no product '{product}' (data/db2/build.toml's products)")
            continue
        for entry in entries:
            version = entry.get("version") if isinstance(entry, dict) else None
            build = parse_build(version, product) if isinstance(version, str) else None
            if build is not None:
                builds.append(build)
    return builds


def newer_build(builds: Sequence[Build], recorded: Build) -> Build | None:
    """The newest build on the recorded build's version line with a higher build number, or None (DATA-R128)."""
    newer = [build for build in builds if build.line == recorded.line and build.number > recorded.number]
    return max(newer, key=lambda build: build.number, default=None)


def issue_title(build: Build) -> str:
    """The watch issue's title (DATA-R128)."""
    return f"Forever build {build.name}: DB2 changes"


def item_changes(
    recorded: dict[int, Item],
    universe: frozenset[int],
    old_names: dict[int, Row],
    new_names: dict[int, Row],
    new_classes: dict[int, Row],
) -> Section:
    """The items part of the diff (DATA-R129). recorded is items.csv; old_names and new_names are ItemSparse rows
    (quality, then the enUS name) of the recorded and the new build, and new_classes the new build's Item rows
    (ClassID, SubclassID)."""
    joined = {
        item_id: (new_classes[item_id].numbers[0], new_names[item_id].numbers[0], new_names[item_id].name)
        for item_id in universe
        if item_id in new_names and item_id in new_classes
    }
    joining = [f"{item_id} {md_text(joined[item_id][2])}" for item_id in sorted(joined) if item_id not in recorded]
    keyword = [
        f"{item_id} {md_text(new_names[item_id].name)}"
        for item_id in sorted(new_names)
        if item_id not in old_names and item_id not in joined and has_keyword(new_names[item_id].name)
    ]
    renamed: list[str] = []
    changed: list[str] = []
    for item_id in sorted(joined.keys() & recorded.keys()):
        class_id, quality, name = joined[item_id]
        old = recorded[item_id]
        if name != old.name:
            renamed.append(f"{item_id} {md_text(old.name)} → {md_text(name)}")
        moves = []
        if class_id != old.class_id:
            moves.append(f"class {old.class_id} → {class_id}")
        if quality != old.quality:
            moves.append(f"quality {old.quality} → {quality}")
        if moves:
            changed.append(f"{item_id} {md_text(name)}: {', '.join(moves)}")
    return (
        "Items",
        [
            ("New in the item universe:", joining),
            ("New in DB2, with a watch keyword in the name:", keyword),
            ("Renamed, in the universe:", renamed),
            ("Class or quality changed, in the universe:", changed),
        ],
    )


def area_changes(recorded: dict[int, Area], new: dict[int, Area]) -> Section:
    """The areas part of the diff (DATA-R129): areas.csv against the new build's AreaTable."""
    added: list[str] = []
    renamed: list[str] = []
    moved: list[str] = []
    for area_id in sorted(new):
        area = new[area_id]
        old = recorded.get(area_id)
        if old is None:
            added.append(f"{area_id} {md_text(area.name)} (parent {area.parent}, continent {area.continent})")
            continue
        if area.name != old.name:
            renamed.append(f"{area_id} {md_text(old.name)} → {md_text(area.name)}")
        moves = []
        if area.parent != old.parent:
            moves.append(f"parent {old.parent} → {area.parent}")
        if area.continent != old.continent:
            moves.append(f"continent {old.continent} → {area.continent}")
        if moves:
            moved.append(f"{area_id} {md_text(area.name)}: {', '.join(moves)}")
    return "Areas", [("New:", added), ("Renamed:", renamed), ("Moved:", moved)]


def new_with_keyword(old: dict[int, Row], new: dict[int, Row]) -> list[str]:
    """The rows new has and old hasn't whose enUS name holds a watch keyword (DATA-R129)."""
    added = sorted(new.keys() - old.keys())
    return [f"{row_id} {md_text(new[row_id].name)}" for row_id in added if has_keyword(new[row_id].name)]


def issue_body(build: Build, recorded: Build, sections: Sequence[Section], limit: int = BODY_LIMIT) -> str:
    """The watch issue's body (DATA-R129): the diff's sections, each list shown only when it has entries. A body
    over limit characters is cut at a line, keeping its last section, with a note pointing at the run's log."""
    lines = [
        f"wago.tools lists Forever build {build.name} ({build.product}), newer than the {recorded.name} that"
        " `data/db2/` describes. This is what changed in the DB2 tables Pagle watches (DATA-R129). Watch keywords,"
        f" matched as whole words in enUS names: {', '.join(WATCH_KEYWORDS)}.",
    ]
    for heading, lists in sections:
        lines += ["", f"## {heading}"]
        shown = [(lead, entries) for lead, entries in lists if entries]
        if not shown:
            lines += ["", "Nothing changed."]
        for lead, entries in shown:
            lines += ["", lead, *(f"- {entry}" for entry in entries)]
    tail = [
        "",
        "## Next",
        "",
        f"Refresh the slice in a PR with `.tools/bin/python scripts/update-db2.py {build.name}` (DATA-R12), then"
        " regenerate with `scripts/generate-data.py`. Edits that follow from this list, such as a spell for"
        " `lists.toml` or an event for `events.toml` (DATA-R40), are made by hand: the watch never edits `data/`"
        " (DATA-R130).",
    ]
    body = "\n".join(lines + tail) + "\n"
    if len(body) <= limit:
        return body
    budget = limit - len("\n".join(tail) + "\n") - len(CUT_NOTE) - 2
    kept: list[str] = []
    for line in lines:
        budget -= len(line) + 1
        if budget < 0:
            break
        kept.append(line)
    return "\n".join([*kept, "", CUT_NOTE, *tail]) + "\n"


def _sections(
    tables: dict[tuple[str, str], str],
    build: str,
    recorded: str,
    current: Db2Layer,
    universe: frozenset[int],
    problems: Problems,
) -> list[Section]:
    """The diff's sections from the downloaded tables, keyed by (table, build); each table's problems go into
    problems."""

    def rows(table: str, at: str, integers: tuple[str, ...], name: str | None) -> dict[int, Row]:
        text = tables[table, at]
        return parse_table(text, f"{table} {at}", problems, integers=integers, name=name, other_columns=True)

    def names(table: str, at: str) -> dict[int, Row]:
        return rows(table, at, ("ID",), "Name_lang")

    def sparse(at: str) -> dict[int, Row]:
        return rows("ItemSparse", at, ("ID", "OverallQualityID"), "Display_lang")

    new_classes = rows("Item", build, ("ID", "ClassID", "SubclassID"), None)
    items = item_changes(current.items, universe, sparse(recorded), sparse(build), new_classes)
    areas = parse_areas(tables["AreaTable", build], f"AreaTable {build}", problems, other_columns=True)
    spells = new_with_keyword(names("SpellName", recorded), names("SpellName", build))
    events = new_with_keyword(names("HolidayNames", recorded), names("HolidayNames", build))
    return [
        items,
        area_changes(current.areas, areas),
        (
            "Spells and calendar events",
            [
                ("New spells with a watch keyword in the name:", spells),
                ("New calendar events with a watch keyword in the name:", events),
            ],
        ),
    ]


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/db2-watch.py",
        description="Look for a Forever build newer than data/db2/'s and write the DB2 watch issue (DATA-R128).",
    )
    parser.add_argument("--out", required=True, type=Path, help="the folder to write title.txt and body.md into")
    parser.add_argument(
        "--issues",
        type=Path,
        help="the repo's issues as `gh issue list --state all --json number,title` prints them; none if left out",
    )
    return parser


def read_issues(path: Path, problems: Problems) -> dict[str, int]:
    """The issues listed in path, by title: a JSON array of objects with "number" and "title"."""
    try:
        listed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        problems.add(At(str(path)), f"can't read: {error}")
        return {}
    if not isinstance(listed, list) or not all(
        isinstance(issue, dict) and isinstance(issue.get("title"), str) and isinstance(issue.get("number"), int)
        for issue in listed
    ):
        problems.add(At(str(path)), "expected a JSON array of issues with a number and a title")
        return {}
    return {issue["title"]: issue["number"] for issue in listed}


def main(argv: Sequence[str], root: Path, fetch: Fetch = download) -> int:
    """Runs the command line on the repo at root, downloading with fetch; returns the exit code."""
    args = _parser().parse_args(argv)
    out: Path = args.out
    problems = Problems()
    if out.resolve().is_relative_to((root / "data").resolve()):
        problems.add(At("--out"), "must be outside data/ (DATA-R130)")
        return fail(PROG, problems, OPENED_NOTHING)
    current = read_db2(root, problems)
    if problems:
        return fail(PROG, problems, OPENED_NOTHING)
    recorded = parse_build(f"{current.version}.{current.build}", "data/db2/build.toml")
    assert recorded is not None  # read_build checked the version string and the build number

    issues = read_issues(args.issues, problems) if args.issues is not None else {}
    if problems:
        return fail(PROG, problems, OPENED_NOTHING)
    try:
        answer = fetch(BUILDS_URL)
    except OSError as error:
        problems.add(At(BUILDS_URL), f"can't download: {error}")
        return fail(PROG, problems, OPENED_NOTHING)
    builds = listed_builds(answer, current.products, problems)
    if problems:
        return fail(PROG, problems, OPENED_NOTHING)
    passed_over = sorted(
        {build.name: build.number for build in builds if build.line != recorded.line and build.number > recorded.number}
        .items(),
        key=lambda named: -named[1],
    )
    if passed_over:
        # Only the run's log: Forever moving to a new line (1.61) shows up here, and the dev decides.
        names = ", ".join(name for name, _ in passed_over[:5])
        print(f"{PROG}: passed over newer builds on other lines: {names}{', ...' if len(passed_over) > 5 else ''}")
    build = newer_build(builds, recorded)
    if build is None:
        print(
            f"{PROG}: no build on the {recorded.line} line newer than {recorded.name} in"
            f" {', '.join(current.products)}; nothing to open"
        )
        return 0
    title = issue_title(build)
    if title in issues:
        print(f'{PROG}: issue #{issues[title]} "{title}" exists; nothing to open')
        return 0

    universe = repo_universe(root, problems)
    if problems:
        return fail(PROG, problems, OPENED_NOTHING)
    wanted = [(table, build.name) for table in NEW_TABLES] + [(table, recorded.name) for table in RECORDED_TABLES]
    tables = download_tables(wanted, fetch, problems)
    if problems:
        return fail(PROG, problems, OPENED_NOTHING)
    sections = _sections(tables, build.name, recorded.name, current, universe, problems)
    if problems:
        return fail(PROG, problems, OPENED_NOTHING)

    write_atomic(out / TITLE_FILE, f"{title}\n".encode("utf-8"))
    write_atomic(out / BODY_FILE, issue_body(build, recorded, sections).encode("utf-8"))
    print(f'{PROG}: wrote the issue "{title}" to {out}; its whole body:\n')
    print(issue_body(build, recorded, sections, limit=sys.maxsize))
    return 0
