"""scripts/import-field-report.py (DATA-R119–R121): the dev's way to turn Field report issues into
data/observed/reports/<reporterKey>.toml and see what they change in the catalogue.

It fetches each issue with gh, takes the report field and parses it (pagle_data.report), and requires every part
of each report among the issues given. It then upserts each report into its reporter's file (DATA-R121), runs the
generator, and prints what changed in the catalogue between the layers read before and after.

upsert() and catalogue_changes() run in memory over layers already read, so the triage Action (#127) can run them
too.
"""

import argparse
import subprocess
import sys
from collections.abc import Callable, Collection, Iterable, Sequence
from dataclasses import dataclass, replace
from pathlib import Path
from typing import TypeVar

from pagle_data import cli
from pagle_data.db2_update import fail
from pagle_data.errors import At, DataError, Problems
from pagle_data.files import write_atomic
from pagle_data.generate import Layers, read_layers
from pagle_data.items import NOISE_CLASSES, identity
from pagle_data.min_build import lost
from pagle_data.observed import (
    REPORTS,
    CatchRow,
    ObservedLayer,
    PoolTextRow,
    Report,
    SkillRow,
    observations,
    row_key,
)
from pagle_data.report import REPORT_LABEL, Identity, Part, join, observed_toml, parse_part, report_field

PROG = "import-field-report"
WROTE_NOTHING = "wrote nothing"

# The repo whose issues the form files (DATA-R115); gh's token is scoped to it (docs/agents/issue-tracker.md).
REPO = "timemir/wow-fish"

_Row = TypeVar("_Row", CatchRow, SkillRow, PoolTextRow)


class FetchError(Exception):
    """An issue that can't be fetched."""


# An issue's body by its number.
Fetch = Callable[[int], str]


def gh_issue_body(number: int) -> str:
    """The issue's body as GitHub renders the issue form, fetched with gh (it runs from WSL)."""
    command = ["gh", "api", f"repos/{REPO}/issues/{number}", "--jq", ".body"]
    try:
        done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", check=False)
    except OSError as error:
        raise FetchError(f"can't run gh ({error}); run this from WSL (docs/agents/issue-tracker.md)") from error
    if done.returncode != 0:
        raise FetchError(done.stderr.strip() or f"gh exited with {done.returncode}")
    return done.stdout


# The upsert (DATA-R121)


def _sort_key(row: CatchRow | SkillRow | PoolTextRow) -> tuple[tuple[int, object], ...]:
    """DATA-R121's row key in an order Python can sort: an absent t or m (None) before any value."""
    return tuple((0, 0) if value is None else (1, value) for value in row_key(row))


def _merged(stored: Sequence[_Row], new: Iterable[_Row]) -> tuple[_Row, ...]:
    """stored's rows with new's upserted: each new row replaces the stored row with its key, keeping its rejected
    mark (DATA-R50); stored rows new lacks stay. Sorted by row key."""
    rows = {row_key(row): row for row in stored}
    for row in new:
        old = rows.get(row_key(row))
        rows[row_key(row)] = row if old is None else replace(row, rejected=old.rejected)
    return tuple(sorted(rows.values(), key=_sort_key))


def upsert(stored: Report | None, report: Report) -> Report:
    """The reporter's file after importing report (DATA-R121): one row per row key, report's rows replacing stored
    ones with the same key (keeping their rejected marks) and stored rows report lacks kept; every imported issue,
    ascending; report's header as the latest. Rows are sorted by key, so the file is written deterministically."""
    if stored is None:
        stored = Report(report.key, (), None, (), (), ())
    return Report(
        report.key,
        tuple(sorted(set(stored.issues) | set(report.issues))),
        report.header if report.header is not None else stored.header,
        _merged(stored.catches, report.catches),
        _merged(stored.skills, report.skills),
        _merged(stored.pool_texts, report.pool_texts),
    )


def imported(layer: ObservedLayer, reports: Iterable[Report]) -> ObservedLayer:
    """The observed layer with each report upserted into its reporter's file (DATA-R121), in ascending order of
    their lowest issue number whatever order they come in, so a reporter's newer report replaces the older one's
    rows and header."""
    files = dict(layer.reports)
    for report in sorted(reports, key=lambda report: min(report.issues, default=0)):
        files[report.key] = upsert(files.get(report.key), report)
    return replace(layer, reports=files)


# What changed in the catalogue (DATA-R119)


def needing_category(before: Layers, observed: ObservedLayer) -> list[int]:
    """The items observed brings into the universe (DATA-R15) that aren't Noise by their DB2 class (DATA-R16): each
    needs a category in items.toml, or category = "uncharted" to defer it, and fails the generator until then
    (DATA-R17, DATA-R18). Before's universe is its shipped records and items.toml's entries (uncharted ones too)."""
    known = before.items.keys() | before.item_layer.items.keys()
    seen = observations(observed, {}).items()  # every build (DATA-R46), through no alias (DATA-R34 maps areas)
    return sorted(
        item for item in seen - known if identity(before.db2, None, item).class_id not in NOISE_CLASSES
    )


def without_items(observed: ObservedLayer, items: Collection[int]) -> ObservedLayer:
    """observed without the I rows of items. For an item outside the universe that's the catalogue it gives once
    the item is deferred (DATA-R18): an uncharted item leaves every list and evidences nothing."""
    reports = {
        key: replace(report, catches=tuple(row for row in report.catches if row.item not in items))
        for key, report in observed.reports.items()
    }
    return replace(observed, reports=reports)


def _gate(window: str | None) -> str:
    return f", gated by {window}" if window is not None else ""


def changes(before: Layers, after: Layers) -> list[str]:
    """What the catalogue gains and loses from before's layers to after's (DATA-R119): new pairs (DATA-R47) and
    newly confirmed pairs, gates, windows, weekly rules and skill bases (DATA-R48–R55), new contradictions
    (DATA-R52, DATA-R54, DATA-R55), and what is no longer confirmed (a contradiction demotes a fact)."""
    was, now = before.confirmation, after.confirmation
    lists_before, lists_after = before.catch_lists.windows(), after.catch_lists.windows()
    lines: list[str] = []
    for area, listed in sorted(lists_after.items()):
        for item, window in sorted(listed.items()):
            if item not in lists_before.get(area, {}):
                confirmed = " (confirmed)" if (area, item) in now.entries else ""
                lines.append(f"new pair: item {item} in area {area}{_gate(window)}{confirmed}")
    for area, item in sorted(now.entries - was.entries):
        if item in lists_before.get(area, {}):
            lines.append(f"confirmed pair: item {item} in area {area}")
    for area, item in sorted(now.gates - was.gates):
        lines.append(f"confirmed gate: item {item} in area {area} by {lists_after[area][item]}")
    lines += [f"confirmed window: {window}" for window in sorted(now.windows - was.windows)]
    lines += [f"confirmed weekly rule: event {event}" for event in sorted(now.weekly - was.weekly)]
    lines += [f"confirmed skill base: area {area}" for area in sorted(now.skill_bases - was.skill_bases)]
    for item, window in sorted(now.contradicted_gates - was.contradicted_gates):
        areas = sorted(area for area, listed in lists_after.items() if listed.get(item) == window)
        lines.append(f"contradicted gate: item {item} by {window} (areas {', '.join(map(str, areas))})")
    for event in sorted(now.contradicted_weekly - was.contradicted_weekly):
        lines.append(f"contradicted weekly rule: event {event}")
    for area in sorted(now.contradicted_skill_bases - was.contradicted_skill_bases):
        lines.append(f"contradicted skill base: area {area} ({after.catch_lists.skill_bases[area]})")
    lines += [f"no longer confirmed: {line}" for line in lost(before, after)]
    return lines


@dataclass(frozen=True)
class CatalogueChanges:
    """What importing changes in the catalogue (DATA-R119): the items now needing a category, and changes() with
    them deferred; or, when data/ fails to generate for more than those items, its problems in place of changes."""

    needing: tuple[int, ...]
    lines: tuple[str, ...] = ()
    problems: tuple[str, ...] = ()


def catalogue_changes(before: Layers, observed: ObservedLayer, root: Path) -> CatalogueChanges:
    """The change list of importing into before's layers, giving the observed layer: the items needing a category
    (needing_category), and changes() from before to the layers read from root with observed in place of
    data/observed/ and those items left out, as if deferred (DATA-R18), so the rest shows while the generator would
    fail on them. It writes and prints nothing."""
    needing = tuple(needing_category(before, observed))
    try:
        after = read_layers(root, observed=without_items(observed, needing))
    except DataError as error:
        return CatalogueChanges(needing, problems=tuple(error.problems))
    return CatalogueChanges(needing, tuple(changes(before, after)))


# The issues


def read_reports(numbers: Sequence[int], fetch: Fetch, problems: Problems) -> list[Report]:
    """The whole reports the issues hold, each as data/observed/ holds it with the issues it came from (DATA-R119):
    each issue fetched, its report field taken (DATA-R115) and parsed as one part (DATA-R116). A report with a part
    missing among the issues is a problem naming the part."""
    parts: list[Part] = []
    issues: dict[Identity, list[int]] = {}
    for number in numbers:
        at = At(f"#{number}")
        try:
            body = fetch(number)
        except FetchError as error:
            problems.add(at, f"can't fetch the issue: {error}")
            continue
        text = report_field(body)
        if text is None:
            problems.add(at, f'no "### {REPORT_LABEL}" field: not a Field report issue (DATA-R115)')
            continue
        part = parse_part(text, str(at), problems)
        if part is not None:
            parts.append(part)
            issues.setdefault(part.header.identity, []).append(number)
    found: list[Report] = []
    for report in join(parts, problems):
        identity = report.identity
        for missing in report.missing:
            given = ", ".join(part.source for part in report.parts)
            message = (
                f"part {missing}/{identity.parts} of reporter {identity.reporter}'s report (data {identity.data}) is"
                " missing: give its issue too (DATA-R119)"
            )
            problems.add(At(given), message)
        found.append(report.observed(issues[identity]))
    return found


# The command line


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/import-field-report.py",
        description="Import Field report issues into data/observed/reports/ and print what they change in the"
        " catalogue (DATA-R119).",
    )
    parser.add_argument("issues", type=int, nargs="+", metavar="ISSUE", help="a Field report issue's number")
    return parser


def _print_changes(before: Layers, observed: ObservedLayer, root: Path) -> None:
    """Prints what the import changes in the catalogue (catalogue_changes, DATA-R119): the changes, then the items
    needing a category."""
    found = catalogue_changes(before, observed, root)
    lines = list(found.lines)
    for problem in found.problems:
        print(f"{PROG}: {problem}", file=sys.stderr)
    if found.problems:
        message = "the generator fails for more than items needing a category: fix the rest to see the changes"
        print(f"{PROG}: {message}", file=sys.stderr)
    for item in found.needing:
        known = before.db2.items.get(item)
        name = f" ({known.name})" if known is not None and known.name else ""
        lines.append(
            f'needs a category: item {item}{name} (DATA-R17), or category = "uncharted" with a why to defer it'
            " (DATA-R18)"
        )
    if not lines:
        print(f"{PROG}: nothing changed in the catalogue")
        return
    print(f"{PROG}: what changed in the catalogue:")
    for line in lines:
        print(f"  {line}")


def main(argv: Sequence[str], root: Path, fetch: Fetch = gh_issue_body) -> int:
    """Runs the command line on the repo at root, fetching issues with fetch; returns the exit code."""
    args = _parser().parse_args(argv)
    numbers = list(dict.fromkeys(args.issues))
    problems = Problems()
    reports = read_reports(numbers, fetch, problems)
    if problems:
        return fail(PROG, problems, WROTE_NOTHING)
    try:
        before = read_layers(root)
    except DataError as error:
        return fail(PROG, error.problems, f"data/ must generate cleanly before an import; {WROTE_NOTHING}")

    after = imported(before.observed, reports)
    for key in sorted({report.key for report in reports}):
        file = f"{REPORTS}/{key}.toml"
        write_atomic(root / file, observed_toml(after.reports[key]).encode("utf-8"))
        print(f"{PROG}: wrote {file}")
    code = cli.main([], root)  # the generator: regenerates the files, or fails listing every problem (DATA-R63)
    _print_changes(before, after, root)
    if code != 0:
        print(
            f"{PROG}: the generator fails (its problems are above) until they're fixed: categorise or defer each item"
            " that needs a category (DATA-R17, DATA-R18), then run scripts/generate-data.py; the report files are kept",
            file=sys.stderr,
        )

    # One keyword per issue: GitHub links only the number right after "Closes".
    closes = ", ".join(f"Closes #{number}" for number in sorted(numbers))
    print(f"{PROG}: for the PR's message (DATA-R120): {closes}")
    print(
        f"{PROG}: commit the observed file, any data/forever/ and lore edits and the regenerated files together, in"
        " one PR (DATA-R120)"
    )
    return 0 if code == 0 else 1
