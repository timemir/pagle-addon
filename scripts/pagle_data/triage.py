"""scripts/triage-field-report.py's command line, the triage Action's body builder (DATA-R117): from one Field report
issue, the comment .github/workflows/field-report-triage.yml posts on it, or edits in place on later runs.

The workflow fetches what GitHub holds (the event payload, the open field-report issues, the issue's comments) and
hands it over as files; this module parses the paste (pagle_data.report, the one parser, DATA-R116) and writes the
comment and what the workflow should do with it. It lists parse errors (and asks for needs-info), the parts
present of a multi-part report, earlier issues this paste supersedes, a stale addon, the Uncharted items by enUS
name (wago.tools' ItemSparse of data/db2/build.toml's build), what importing it would change in the catalogue (the
importer's upsert and change list, run in memory, DATA-R119–R121) and the P row texts pooltext.toml doesn't map yet
(DATA-R118). It reads data/ and never writes there.
"""

import argparse
import json
import re
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path

from pagle_data.db2 import Row, parse_table, read_db2
from pagle_data.db2_update import Fetch, download, download_tables, fail
from pagle_data.db2_watch import md_text
from pagle_data.errors import At, DataError, Problems
from pagle_data.files import write_atomic
from pagle_data.generate import CATALOGUE_LUA, Layers, read_layers
from pagle_data.importer import catalogue_changes, imported
from pagle_data.observed import POOLTEXT, REPORTS, ObservedLayer, PoolTextRow, read_observed
from pagle_data.report import FieldReport, Part, join, parse_part, report_field, toml_string

PROG = "triage-field-report"
POSTED_NOTHING = "posted nothing"

# The hidden marker the comment starts with; the workflow edits the Action's comment that carries it (DATA-R117).
MARKER = "<!-- pagle-field-report-triage -->"
# The account GITHUB_TOKEN comments as: only its comment with the marker is edited, never one a person wrote.
BOT_LOGIN = "github-actions[bot]"

# What the run writes into --out for the workflow.
COMMENT_FILE = "comment.md"
RESULT_FILE = "result.json"

# GitHub refuses a comment over 65,536 characters; the comment is cut below that, and the run's log keeps all of it.
COMMENT_LIMIT = 60_000
CUT_NOTE = "**The comment is cut here: it's longer than a comment holds. The Action's run log has all of it.**"

# A generated Catalogue.lua's fingerprint line (DATA-R70, DATA-R76).
_FINGERPRINT = re.compile(r'^\tfingerprint = "([0-9a-f]{16})",$', re.MULTILINE)

_FENCE = re.compile(r"`{3,}")


@dataclass(frozen=True)
class Issue:
    """An issue as GitHub gives it: its number and its body (the issue form's rendering, DATA-R115)."""

    number: int
    body: str


@dataclass(frozen=True)
class Triage:
    """The comment for one issue, and whether the paste needs the reporter's attention (needs-info)."""

    comment: str
    needs_info: bool


# GitHub's answers


def _issue(value: object) -> Issue | None:
    if not isinstance(value, dict) or not isinstance(value.get("number"), int):
        return None
    body = value.get("body")
    return Issue(value["number"], body if isinstance(body, str) else "")


def _load(path: Path, problems: Problems) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        problems.add(At(str(path)), f"can't read: {error}")
        return None


def read_event(path: Path, problems: Problems) -> Issue | None:
    """The issue an `issues` event is about ($GITHUB_EVENT_PATH's issue: number and body)."""
    document = _load(path, problems)
    issue = _issue(document.get("issue")) if isinstance(document, dict) else None
    if issue is None and not problems:
        problems.add(At(str(path)), "expected an issues event payload, with the issue's number")
    return issue


def read_issues(path: Path, problems: Problems) -> list[Issue]:
    """The issues `gh issue list --json number,body` printed."""
    document = _load(path, problems)
    issues = [_issue(value) for value in document] if isinstance(document, list) else [None]
    if any(issue is None for issue in issues):
        if not problems:
            problems.add(At(str(path)), "expected a JSON array of issues with a number and a body")
        return []
    return [issue for issue in issues if issue is not None]


def _comments(document: object) -> list[object]:
    """The comments of `gh api --paginate --slurp` (a list of pages) or of one page."""
    if not isinstance(document, list):
        return []
    if all(isinstance(page, list) for page in document):
        return [comment for page in document for comment in page]
    return document


def read_comment(path: Path, problems: Problems) -> int | None:
    """The ID of the comment the Action posted on an earlier run (the bot's, starting with the marker), to edit in
    place (DATA-R117); None when there's none yet. A comment someone else wrote is never the Action's, marker or not."""
    document = _load(path, problems)
    if document is not None and not isinstance(document, list):
        problems.add(At(str(path)), "expected the issue's comments as a JSON array")
    for comment in _comments(document):
        if not isinstance(comment, dict):
            continue
        user, body, number = comment.get("user"), comment.get("body"), comment.get("id")
        login = user.get("login") if isinstance(user, dict) else None
        if login == BOT_LOGIN and isinstance(body, str) and body.startswith(MARKER) and isinstance(number, int):
            return number
    return None


# The comment's parts


def _bullets(lines: Iterable[str]) -> list[str]:
    return [f"- {line}" for line in lines]


def _fenced(language: str, lines: Sequence[str]) -> list[str]:
    """lines in a code block whose fence is longer than any backtick run inside."""
    longest = max((len(run) for line in lines for run in _FENCE.findall(line)), default=0)
    fence = "`" * max(3, longest + 1)
    return [f"{fence}{language}", *lines, fence]


def _parse_errors(found: Sequence[str], number: int) -> list[str]:
    own = f"#{number}: "
    lines = ["#### Parse errors", ""]
    lines += _bullets(md_text(problem.removeprefix(own)) for problem in found)
    lines += [
        "",
        "The paste can't be read as it is, so nothing else is judged. Copy the report again in game (`/pagle report`,"
        " Ctrl+C) and edit this issue to paste it whole, from `PAGLE-REPORT 1` to `END`. A report in several parts"
        " goes in one issue per part. This comment updates when the issue is edited.",
    ]
    return lines


def default_fingerprint(root: Path) -> str | None:
    """The content fingerprint in the checked-out (default) branch's Catalogue.lua (DATA-R70), or None."""
    try:
        text = (root / CATALOGUE_LUA).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    found = _FINGERPRINT.search(text)
    return found[1] if found else None


def _stale(data: str, fingerprint: str | None) -> list[str]:
    """DATA-R117: "stale addon" when data isn't the first 8 characters of the default branch's fingerprint."""
    if fingerprint is None:
        return ["#### Stale addon?", "", f"Can't tell: the default branch's `{CATALOGUE_LUA}` has no fingerprint line."]
    if data == fingerprint[:8]:
        return []
    return [
        "#### Stale addon",
        "",
        f"**Stale addon:** the report's data `{data}` isn't `{fingerprint[:8]}`, the default branch's content"
        f" fingerprint (`{fingerprint}`). The reporter's addon was built from other content data than the default"
        " branch: an older release, or a build not from it. Its rows are still evidence, judged below against the"
        " default branch.",
    ]


def _parts(report: FieldReport, number: int) -> list[str]:
    """For a multi-part report, which parts are present, across the open issues with its identity (DATA-R117)."""
    total = report.identity.parts
    if total == 1:
        return []
    present = [
        f"part {part.header.part} of {total}: {'this issue' if part.source == f'#{number}' else part.source}"
        for part in report.parts
    ]
    lines = ["#### Parts", "", *_bullets(present)]
    if report.missing:
        missing = ", ".join(str(n) for n in report.missing)
        lines += [
            "",
            f"Missing: part {missing} of {total}. File each as its own issue with the form; until then the report is"
            " incomplete, and what importing would change (below) is judged on the parts present.",
        ]
    else:
        lines += ["", "Every part is present."]
    return lines


def _superseded(
    part: Part, number: int, others: Sequence[tuple[int, Part]], observed: ObservedLayer | None
) -> list[str]:
    """DATA-R117: the earlier issues with this reporter key and another report identity, open or already imported
    per data/observed/reports/<key>.toml's issues, which this paste supersedes. An imported issue's identity is
    known only as the file's latest header (addon, data, locale), so it differs when that header does."""
    header = part.header
    found: dict[int, str] = {}
    for other_number, other in others:
        was_open = other.header
        if other_number < number and was_open.reporter == header.reporter and was_open.identity != header.identity:
            found[other_number] = f"open, addon {md_text(was_open.addon)}, data `{was_open.data}`"
    stored = observed.reports.get(header.reporter) if observed is not None else None
    if stored is not None and stored.header is not None:
        was = stored.header
        if (was.addon, was.data, was.locale) != (header.addon, header.data, header.locale):
            file = f"{REPORTS}/{header.reporter}.toml"
            for imported_number in stored.issues:
                if imported_number < number and imported_number not in found:
                    found[imported_number] = f"already imported into `{file}`, data `{was.data}`"
    if not found:
        return []
    lines = ["#### Supersedes", "", "This paste supersedes these earlier issues with the same reporter key:", ""]
    return lines + _bullets(f"#{issue} ({about})" for issue, about in sorted(found.items()))


def _item_names(items: Sequence[int], root: Path, fetch: Fetch, notes: list[str]) -> dict[int, Row]:
    """The enUS names of items from the ItemSparse table of data/db2/build.toml's build on wago.tools (DATA-R117).
    What goes wrong becomes a note: the comment is posted either way."""
    if not items:
        return {}
    problems = Problems()
    db2 = read_db2(root, problems)
    if problems:
        notes.append("No names: data/db2/ can't be read on the default branch.")
        return {}
    build = f"{db2.version}.{db2.build}"
    tables = download_tables([("ItemSparse", build)], fetch, problems)
    names: dict[int, Row] = {}
    if not problems:
        text = tables["ItemSparse", build]
        names = parse_table(
            text, f"ItemSparse {build}", problems, integers=("ID",), name="Display_lang", other_columns=True
        )
    if problems:
        notes.append(f"No names: wago.tools' ItemSparse of {build} can't be had: {md_text('; '.join(problems.found))}")
        return {}
    return names


def _uncharted(
    report: FieldReport, before: Layers, needing: Sequence[int], root: Path, fetch: Fetch
) -> list[str]:
    """The report's items the default branch's catalogue doesn't ship, so Core counts them Uncharted (DATA-R15,
    DATA-R18), with their enUS names."""
    items = sorted({row.item for row in report.catches} - before.items.keys())
    if not items:
        return []
    notes: list[str] = []
    names = _item_names(items, root, fetch, notes)
    entries: list[str] = []
    for item in items:
        named = f"{item} {md_text(names[item].name)}" if item in names else f"{item}"
        if item in needing:
            entries.append(
                f"{named}: new to the item universe, so it needs a category (DATA-R17), or category = \"uncharted\""
                " with a why to defer it (DATA-R18), before the import's PR generates"
            )
        elif item in before.item_layer.items:
            entries.append(f'{named}: deferred, category = "uncharted" in items.toml (DATA-R18)')
        else:
            entries.append(f"{named}: Noise by its DB2 class (DATA-R16)")
    return ["#### Uncharted items", "", *_bullets(entries), *(["", *notes] if notes else [])]


def _changes(lines: Sequence[str]) -> list[str]:
    heading = ["#### What importing would change", ""]
    if not lines:
        return heading + ["Nothing in the catalogue would change."]
    return heading + _bullets(lines)


def _catalogue(report: FieldReport, issues: Sequence[int], root: Path, fetch: Fetch) -> list[str]:
    """The Uncharted items, and what importing the report would change in the catalogue: the importer's upsert and
    change list, run in memory over the default branch's data/ (DATA-R117, DATA-R119)."""
    try:
        before = read_layers(root)
    except DataError as error:
        return [
            "#### What importing would change",
            "",
            "Can't tell: data/ doesn't generate on the default branch (DATA-R63):",
            "",
            *_bullets(md_text(problem) for problem in error.problems),
        ]
    found = catalogue_changes(before, imported(before.observed, [report.observed(issues)]), root)
    lines = _uncharted(report, before, found.needing, root, fetch)
    if found.problems:
        return lines + [
            *([""] if lines else []),
            "#### What importing would change",
            "",
            "Can't tell: with this report imported, the generator fails for more than items needing a category"
            " (DATA-R63):",
            "",
            *_bullets(md_text(problem) for problem in found.problems),
        ]
    return lines + [*([""] if lines else []), *_changes(found.lines)]


def _pool_texts(rows: Iterable[PoolTextRow], observed: ObservedLayer | None) -> list[str]:
    """The P row texts pooltext.toml doesn't map yet (DATA-R118), each as an entry ready to copy, pool left empty."""
    known = {(entry.locale, entry.text) for entry in observed.pooltext} if observed is not None else set()
    new: dict[tuple[str, str], list[PoolTextRow]] = {}
    for row in rows:
        if (row.locale, row.text) not in known:
            new.setdefault((row.locale, row.text), []).append(row)
    if not new:
        return []
    entries: list[str] = []
    for (locale, text), seen in new.items():
        for row in seen:
            caught = " ".join(f"{item}x{count}" for item, count in row.items) or "nothing caught"
            entries.append(f"# area {row.area}, {row.casts} cast(s): {caught}")
        entries += ["[[text]]", f"locale = {toml_string(locale)}", f"text = {toml_string(text)}", 'pool = ""', ""]
    return [
        "#### New pool texts",
        "",
        f"Texts `{POOLTEXT}` doesn't map yet. Copy each entry there and set its pool: a pool type ID from"
        " `data/forever/pools.toml`, `bobber` or `other` (DATA-R118).",
        "",
        *_fenced("toml", entries[:-1]),
    ]


def _cut(lines: list[str], limit: int) -> str:
    """The comment, cut at a line when it's over limit characters, closing an open code block, with a note."""
    body = "\n".join(lines) + "\n"
    if len(body) <= limit:
        return body
    budget = limit - len(CUT_NOTE) - 16
    kept: list[str] = []
    fence: str | None = None
    for line in lines:
        budget -= len(line) + 1
        if budget < 0:
            break
        kept.append(line)
        opened = _FENCE.match(line)
        if opened is not None:
            fence = None if fence is not None and line == fence else (fence or opened[0])
    if fence is not None:
        kept.append(fence)
    return "\n".join([*kept, "", CUT_NOTE]) + "\n"


def triage(
    issue: Issue, open_issues: Sequence[Issue], root: Path, fetch: Fetch, limit: int = COMMENT_LIMIT
) -> Triage:
    """The comment for issue (DATA-R117), given the repo's open field-report issues and the default branch at root."""
    intro = [
        MARKER,
        "### Field report triage",
        "",
    ]
    footer = [
        "",
        "---",
        "_The triage Action (DATA-R117) wrote this from the paste and the default branch, and changed nothing: the dev"
        " imports reports with `scripts/import-field-report.py`. It updates this comment when the issue is edited._",
    ]
    problems = Problems()
    text = report_field(issue.body)
    part: Part | None = None
    if text is None:
        problems.add(At(f"#{issue.number}"), 'no "### Report" field: file reports with the Field report form')
    else:
        part = parse_part(text, f"#{issue.number}", problems)
    if part is None:
        return Triage(_cut(intro + _parse_errors(problems.found, issue.number) + footer, limit), True)

    others: list[tuple[int, Part]] = []
    for other in open_issues:
        if other.number == issue.number:
            continue
        other_text = report_field(other.body)
        other_part = parse_part(other_text, f"#{other.number}", Problems()) if other_text is not None else None
        if other_part is not None:
            others.append((other.number, other_part))
    same = [(number, other) for number, other in others if other.header.identity == part.header.identity]
    (report,) = join([part, *(other for _, other in same)], problems)
    if problems:  # a part filed twice with other rows, or a row two parts share (DATA-R121)
        return Triage(_cut(intro + _parse_errors(problems.found, issue.number) + footer, limit), True)

    header = part.header
    observed_problems = Problems()
    observed = read_observed(root, observed_problems)
    lines = intro + [
        f"Reporter `{header.reporter}`, addon {md_text(header.addon)}, data `{header.data}`, locale {header.locale},"
        f" part {header.part} of {header.parts}.",
    ]
    issues = sorted({issue.number, *(number for number, _ in same)})
    for section in (
        _stale(header.data, default_fingerprint(root)),
        _parts(report, issue.number),
        _superseded(part, issue.number, others, None if observed_problems else observed),
        _catalogue(report, issues, root, fetch),
        _pool_texts(report.pool_texts, None if observed_problems else observed),
    ):
        if section:
            lines += ["", *section]
    return Triage(_cut(lines + footer, limit), False)


# The command line


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/triage-field-report.py",
        description="Write the triage comment for a Field report issue (DATA-R117).",
    )
    parser.add_argument("--event", required=True, type=Path, help="the issues event payload ($GITHUB_EVENT_PATH)")
    parser.add_argument(
        "--open-issues",
        required=True,
        type=Path,
        help="the open field-report issues, as `gh issue list --label field-report --json number,body` prints them",
    )
    parser.add_argument(
        "--comments",
        required=True,
        type=Path,
        help="the issue's comments, as `gh api --paginate --slurp repos/<repo>/issues/<n>/comments` prints them",
    )
    parser.add_argument("--out", required=True, type=Path, help="the folder to write comment.md and result.json into")
    return parser


def main(argv: Sequence[str], root: Path, fetch: Fetch = download) -> int:
    """Runs the command line on the repo at root (the default branch's checkout), downloading with fetch; returns
    the exit code. Writes --out/comment.md, the comment, and --out/result.json: {"comment": the ID of the Action's
    earlier comment to edit, or null to post one; "needsInfo": whether to add the needs-info label}."""
    args = _parser().parse_args(argv)
    out: Path = args.out
    problems = Problems()
    if out.resolve().is_relative_to((root / "data").resolve()):
        problems.add(At("--out"), "must be outside data/: the triage writes nothing there (DATA-R117)")
        return fail(PROG, problems, POSTED_NOTHING)
    issue = read_event(args.event, problems)
    open_issues = read_issues(args.open_issues, problems)
    comment = read_comment(args.comments, problems)
    if problems or issue is None:
        return fail(PROG, problems, POSTED_NOTHING)

    found = triage(issue, open_issues, root, fetch)
    result = {"comment": comment, "needsInfo": found.needs_info}
    write_atomic(out / COMMENT_FILE, found.comment.encode("utf-8"))
    write_atomic(out / RESULT_FILE, (json.dumps(result) + "\n").encode("utf-8"))
    action = f"edit comment {comment}" if comment is not None else "post a comment"
    print(f"{PROG}: #{issue.number}: {action}{', add needs-info' if found.needs_info else ''}; the comment:\n")
    print(found.comment)
    return 0
