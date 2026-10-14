"""scripts/triage-field-report.py, the triage Action's body builder (DATA-R117): from a Field report issue, the one
comment the Action posts or edits, and whether the issue needs needs-info. The issues and comments are recorded as
GitHub's API and event payload give them, the issue bodies as the issue form renders them (fixtures/issues/), and
wago.tools' ItemSparse is a cut of the real 1.60.1.70338 CSV (fixtures/wago/). Nothing here touches the network: the
download goes through a canned fetch. The trees are test_catch_lists.py's; every row is a fixture row.
"""

import hashlib
import json
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest

from pagle_data.triage import CUT_NOTE, MARKER, Issue, main
from pagle_data.triage import triage as build
from report_fixture import issue_body
from report_fixture import part as report_part
from test_catch_lists import write_tree

FIXTURES = Path(__file__).resolve().parent / "fixtures"
CLEAN = (FIXTURES / "issues" / "triage-clean.md").read_text(encoding="utf-8")
TRUNCATED = (FIXTURES / "issues" / "truncated.md").read_text(encoding="utf-8")
ITEM_SPARSE_URL = "https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70338"
ITEM_SPARSE = (FIXTURES / "wago" / "ItemSparse-1.60.1.70338.csv").read_bytes()

# The default branch's content fingerprint (DATA-R70) in the stub Catalogue.lua; the fixture reports' data is its first
# 8 characters (REP-R30).
FINGERPRINT = "3f9a2c1e5d6b7a80"
CATALOGUE = "addons/Pagle/data/Catalogue.lua"

# The fixture reports' reporter key (REP-R36).
CAROL = "cccccccc"


class Canned:
    """A fetch that answers from a table of URLs and records what was asked."""

    def __init__(self, responses: Mapping[str, bytes]) -> None:
        self.responses = responses
        self.asked: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.asked.append(url)
        if url not in self.responses:
            raise OSError(f"no canned response for {url}")
        return self.responses[url]


def tree(root: Path, pooltext: str = "", reports: dict[str, str] | None = None) -> Path:
    """test_catch_lists' tree, with the default branch's Catalogue.lua (only its fingerprint line matters here) and
    pooltext.toml."""
    write_tree(root, reports=reports)
    (root / "data" / "observed" / "pooltext.toml").write_text(pooltext, encoding="utf-8")
    catalogue = root / CATALOGUE
    catalogue.parent.mkdir(parents=True, exist_ok=True)
    catalogue.write_text(f"ns.catalogue = {{\n\tfingerprint = \"{FINGERPRINT}\",\n}}\n", encoding="utf-8")
    return root


def part(rows: str, n: int = 1, m: int = 1, data: str = "3f9a2c1e", reporter: str = CAROL) -> str:
    """An issue body as the form renders it (DATA-R115), holding one PAGLE-REPORT part (REP-R30) with these rows."""
    report = report_part(rows, n, m, data=data, locale="deDE", reporter=reporter)
    return issue_body(report.removesuffix("\n"))


def bot_comment(number: int, body: str) -> dict[str, object]:
    return {"id": number, "body": body, "user": {"login": "github-actions[bot]", "type": "Bot"}}


class Run:
    """One triage run: its exit code, everything it printed, the comment it wrote and its result."""

    def __init__(self, code: int, output: str, out: Path) -> None:
        self.code, self.output = code, output
        self.comment = (out / "comment.md").read_text(encoding="utf-8") if (out / "comment.md").exists() else ""
        self.result = json.loads((out / "result.json").read_text(encoding="utf-8")) if code == 0 else {}
        self.lines = self.comment.splitlines()


def triage(
    root: Path,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
    body: str | None,
    *,
    number: int = 50,
    open_issues: Sequence[tuple[int, str]] = (),
    comments: object = (),
    fetch: Canned | None = None,
) -> Run:
    """The triage on the tree at root for issue number with body, as the workflow hands it over: the event payload,
    the open field-report issues (`gh issue list --json number,body`, this one among them) and the issue's comments
    (`gh api --paginate --slurp`, a list of pages)."""
    work = tmp_path / "work"
    work.mkdir(exist_ok=True)
    event = {"action": "opened", "issue": {"number": number, "body": body, "labels": [{"name": "field-report"}]}}
    (work / "event.json").write_text(json.dumps(event), encoding="utf-8")
    listed = [{"number": number, "body": body}, *({"number": n, "body": b} for n, b in open_issues)]
    (work / "open.json").write_text(json.dumps(listed), encoding="utf-8")
    (work / "comments.json").write_text(json.dumps(comments if comments else [[]]), encoding="utf-8")
    out = tmp_path / "out"
    argv = ["--event", str(work / "event.json"), "--open-issues", str(work / "open.json")]
    argv += ["--comments", str(work / "comments.json"), "--out", str(out)]
    code = main(argv, root, fetch if fetch is not None else Canned({ITEM_SPARSE_URL: ITEM_SPARSE}))
    captured = capsys.readouterr()
    return Run(code, captured.out + captured.err, out)


def digest(directory: Path) -> dict[str, str]:
    """Every file under directory with its SHA-256: what a run must leave as it was."""
    return {
        str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(directory.rglob("*"))
        if path.is_file()
    }


BOBBER = '[[text]]\nlocale = "deDE"\ntext = "Angelköder"\npool = "bobber"\n'


def test_a_clean_one_part_issue_lists_an_uncharted_item_by_name_a_pair_it_would_add_and_a_new_pool_text(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117 over test_catch_lists' tree, whose pooltext.toml maps the bobber's deDE text (DATA-R118):
    # - 13888 is in no layer, so it is Uncharted (DATA-R15), named from build.toml's build's ItemSparse
    # - 6308 is in neither Echo Isles' (368) nor Durotar's list, so the row would add it as an observed pair (DATA-R47)
    # - of the two P row texts, only the one pooltext.toml lacks is new; the bobber's drops out (DATA-R118)
    # The paste parses and its data is the default branch's, so no needs-info and no stale addon.
    root = tree(tmp_path / "repo", BOBBER)
    fetch = Canned({ITEM_SPARSE_URL: ITEM_SPARSE})
    run = triage(root, tmp_path, capsys, CLEAN, fetch=fetch)
    assert run.code == 0, run.output
    assert run.lines[0] == MARKER
    assert "- 13888 Darkclaw Lobster: new to the item universe, so it needs a category (DATA-R17)" in run.comment
    assert "- new pair: item 6308 in area 368 (confirmed)" in run.lines
    assert 'text = "Schwarm öliger Schwarzmaulfische"' in run.lines
    assert "Angelköder" not in run.comment
    assert "tale addon" not in run.comment
    assert "Parse errors" not in run.comment
    assert run.result == {"comment": None, "needsInfo": False}
    assert fetch.asked == [ITEM_SPARSE_URL]


def test_editing_the_issue_edits_the_actions_comment_instead_of_adding_one(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117: one comment, found by its hidden marker and edited in place on later runs. The comments come a page
    # at a time (gh api --paginate --slurp); the Action's is the bot's with the marker, never a person's quoting it.
    root = tree(tmp_path / "repo", BOBBER)
    quoted = {"id": 7, "body": f"{MARKER}\nquoting the bot", "user": {"login": "carol", "type": "User"}}
    pages = [[quoted, bot_comment(8, "an unrelated bot comment")], [bot_comment(9, f"{MARKER}\n### Field report")]]
    run = triage(root, tmp_path, capsys, CLEAN, comments=pages)
    assert run.code == 0, run.output
    assert run.result == {"comment": 9, "needsInfo": False}
    assert "edit comment 9" in run.output
    # An edit that changes nothing gives the same comment, so editing it in place shows no change.
    assert triage(root, tmp_path, capsys, CLEAN, comments=pages).comment == run.comment


def test_a_truncated_paste_gets_the_parse_error_and_needs_info(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117: parse errors, if any, and then needs-info. DATA-R116: a missing END is a truncated paste. Nothing
    # else is judged, so nothing is downloaded.
    root = tree(tmp_path / "repo", BOBBER)
    fetch = Canned({})
    run = triage(root, tmp_path, capsys, TRUNCATED, fetch=fetch)
    assert run.code == 0, run.output
    assert run.result == {"comment": None, "needsInfo": True}
    assert run.lines[0] == MARKER
    assert "- line 4: no END after this line: the paste is truncated (REP-R30)" in run.lines, run.comment
    assert "What importing would change" not in run.comment
    assert fetch.asked == []


def test_an_issue_without_a_report_field_needs_info(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R115: the paste is the form's report field; an issue without one (or with no body) can't be triaged.
    root = tree(tmp_path / "repo")
    for body in ("I caught a fish!", None):
        run = triage(root, tmp_path, capsys, body)
        assert run.code == 0, run.output
        assert run.result["needsInfo"] is True
        assert '- no "### Report" field: file reports with the Field report form' in run.lines, run.comment


def test_an_earlier_issue_with_the_same_reporter_and_an_older_data_is_superseded(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117: an earlier issue with the same reporter key and another report identity, open (#30) or already
    # imported per data/observed/reports/<key>.toml's issues (#12, whose file's header has an older data), is named
    # as superseded. A later issue (#60) and another reporter's (#31) are not.
    stored = 'issues = [12]\n\n[header]\naddon = "0.8.0"\ndata = "01dda7a0"\nlocale = "deDE"\n'
    root = tree(tmp_path / "repo", reports={CAROL: stored})
    older = part("I 6291 12 70338 1\n", data="0badf00d")
    others = [(30, older), (60, older), (31, part("I 6291 12 70338 1\n", data="0badf00d", reporter="dddddddd"))]
    run = triage(root, tmp_path, capsys, CLEAN, open_issues=others)
    assert run.code == 0, run.output
    assert "#### Supersedes" in run.lines
    assert "- #12 (already imported into `data/observed/reports/cccccccc.toml`, data `01dda7a0`)" in run.lines
    assert "- #30 (open, addon 0.9.0, data `0badf00d`)" in run.lines
    assert "#60" not in run.comment and "#31" not in run.comment


def test_an_import_with_the_same_header_supersedes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R117: an imported issue's identity is known as its file's latest header; the same addon, data and locale
    # is this report, which the paste doesn't supersede.
    stored = 'issues = [12]\n\n[header]\naddon = "0.9.0"\ndata = "3f9a2c1e"\nlocale = "deDE"\n'
    run = triage(tree(tmp_path / "repo", reports={CAROL: stored}), tmp_path, capsys, CLEAN)
    assert run.code == 0, run.output
    assert "Supersedes" not in run.comment


def test_an_open_issue_with_the_same_identity_counts_as_another_part(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117: for a multi-part report, which parts are present, counting the open issues with its identity
    # (DATA-R116: parts share the header but part). #50 is part 1 of 3, #45 part 2; part 3 isn't filed. The parts
    # present are judged together: #45's 6308 row in Echo Isles is the pair it would add. #44, part 2 of another
    # identity of the same reporter, is no part of it.
    root = tree(tmp_path / "repo")
    first = part('P 368 deDE "Angelköder" casts=4 6308x1\n', n=1, m=3)
    second = part("I 6308 368 70338 1\n", n=2, m=3)
    other_report = part("I 6291 12 70338 1\n", n=2, m=3, data="0badf00d")
    run = triage(root, tmp_path, capsys, first, open_issues=[(45, second), (44, other_report)])
    assert run.code == 0, run.output
    assert "- part 1 of 3: this issue" in run.lines
    assert "- part 2 of 3: #45" in run.lines
    assert any(line.startswith("Missing: part 3 of 3.") for line in run.lines), run.comment
    assert "- #44 (open, addon 0.9.0, data `0badf00d`)" in run.lines
    assert "- new pair: item 6308 in area 368 (confirmed)" in run.lines


def test_a_part_filed_twice_with_other_rows_needs_info(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R116: parts of one report are joined; the same part again with other rows can't be (pagle_data.report).
    root = tree(tmp_path / "repo")
    twice = [(45, part("I 6308 368 70338 2\n", n=1, m=2))]
    run = triage(root, tmp_path, capsys, part("I 6308 368 70338 1\n", n=1, m=2), open_issues=twice)
    assert run.code == 0, run.output
    assert run.result["needsInfo"] is True
    assert any("part 1/2 again, with other rows than in" in line for line in run.lines), run.comment


def test_a_header_whose_data_differs_from_the_default_branch_fingerprint_is_flagged_stale_addon(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117: "stale addon" when the header's data differs from the first 8 characters of the fingerprint in the
    # default branch's Catalogue.lua (DATA-R70); the rows are still judged.
    root = tree(tmp_path / "repo")
    run = triage(root, tmp_path, capsys, CLEAN.replace("data 3f9a2c1e", "data 0badf00d"))
    assert run.code == 0, run.output
    assert run.result["needsInfo"] is False
    assert any(line.startswith("**Stale addon:** the report's data `0badf00d` isn't `3f9a2c1e`") for line in run.lines)
    assert "- new pair: item 6308 in area 368 (confirmed)" in run.lines


def test_a_known_pool_text_drops_out_and_one_known_only_in_another_locale_stays(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R118: pooltext.toml maps (locale, hovered text); the triage lists only texts not in it. Mapping both deDE
    # texts leaves no new pool text; the same text mapped for enUS only doesn't map deDE's.
    school = '\n[[text]]\nlocale = "{}"\ntext = "Schwarm öliger Schwarzmaulfische"\npool = "extravaganza"\n'
    run = triage(tree(tmp_path / "repo", BOBBER + school.format("deDE")), tmp_path, capsys, CLEAN)
    assert run.code == 0, run.output
    assert "New pool texts" not in run.comment
    run = triage(tree(tmp_path / "repo2", BOBBER + school.format("enUS")), tmp_path, capsys, CLEAN)
    assert 'text = "Schwarm öliger Schwarzmaulfische"' in run.lines


def test_nothing_under_data_is_written_during_a_run(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R117: the Action computes the upsert and the changes in memory, "without writing": data/ (and the
    # generated files) are byte for byte as they were, and --out may not point into data/.
    root = tree(tmp_path / "repo", BOBBER)
    before = digest(root)
    run = triage(root, tmp_path, capsys, CLEAN)
    assert run.code == 0, run.output
    assert digest(root) == before
    work = tmp_path / "work"
    argv = ["--event", str(work / "event.json"), "--open-issues", str(work / "open.json")]
    argv += ["--comments", str(work / "comments.json"), "--out", str(root / "data" / "triage")]
    assert main(argv, root, Canned({})) == 1
    assert "--out: must be outside data/" in capsys.readouterr().err
    assert digest(root) == before


def test_an_itemsparse_that_cant_be_had_leaves_the_items_unnamed(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R117: names come from wago.tools; when it can't serve them (down, or a fresh build's unnamed columns,
    # #97's finding), the comment still goes up, with the item IDs and a note.
    root = tree(tmp_path / "repo")
    run = triage(root, tmp_path, capsys, CLEAN, fetch=Canned({}))
    assert run.code == 0, run.output
    assert any(line.startswith("- 13888: new to the item universe") for line in run.lines), run.comment
    assert any(line.startswith("No names: wago.tools' ItemSparse of 1.60.1.70338 can't be had") for line in run.lines)
    unnamed = b"ID,Field_1_60_1_70338_005_lang\n13888,Darkclaw Lobster\n"
    run = triage(root, tmp_path, capsys, CLEAN, fetch=Canned({ITEM_SPARSE_URL: unnamed}))
    assert "missing column 'Display\\_lang'" in run.comment


def test_a_default_branch_whose_data_doesnt_generate_says_so(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R63: the catalogue can't be judged over data/ that doesn't generate; the comment says so and still lists
    # the rest (the pool texts here).
    root = tree(tmp_path / "repo")
    (root / "data" / "forever" / "lists.toml").write_text("auras = []\n", encoding="utf-8")
    run = triage(root, tmp_path, capsys, CLEAN)
    assert run.code == 0, run.output
    assert "Can't tell: data/ doesn't generate on the default branch (DATA-R63):" in run.lines
    assert 'text = "Schwarm öliger Schwarzmaulfische"' in run.lines


def test_a_comment_over_githubs_limit_is_cut_with_a_note_and_its_code_block_closed(tmp_path: Path) -> None:
    # GitHub refuses a comment over 65,536 characters: the comment is cut at a line, an open code block closed, with
    # a note pointing at the run's log, which prints all of it.
    rows = "".join(f'P 368 deDE "Text {n}" casts=1\n' for n in range(400))
    found = build(Issue(50, part(rows)), [], tree(tmp_path), Canned({}), limit=4000)
    assert len(found.comment) <= 4000
    assert found.comment.rstrip().endswith(CUT_NOTE)
    assert found.comment.count("```") % 2 == 0
