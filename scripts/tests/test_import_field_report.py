"""scripts/import-field-report.py (DATA-R119–R122): Field report issues into data/observed/reports/<key>.toml, and
what they change in the catalogue. The issues come from an injected fetch in place of gh, their bodies recorded as
the issue form renders them (fixtures/issues/); the trees are test_catch_lists.py's (#94's observed fixture layer).
Every row here is a fixture row; none is a committed report.
"""

from collections.abc import Mapping
from dataclasses import replace
from pathlib import Path

import pytest

from pagle_data.errors import Problems
from pagle_data.importer import FetchError, main, upsert
from pagle_data.observed import Header, Report
from pagle_data.report import join, observed_toml, parse_part
from test_catch_lists import CATALOGUE, write_tree

FIXTURES = Path(__file__).resolve().parent / "fixtures"

# Reporter keys (REP-R36) of the fixture reports.
ALICE = "aaaaaaaa"
BOB = "bbbbbbbb"
REPORTS = "data/observed/reports"

# Recorded issues (DATA-R115's form rendering), by number: Alice's two-part report as #41 and #42 (#42 with CRLF
# line ends, as the API returns a pasted textarea), and Bob's one-part report of an item no layer knows as #43.
ISSUES = {
    41: (FIXTURES / "issues" / "two-part-1.md").read_text(encoding="utf-8"),
    42: (FIXTURES / "issues" / "two-part-2.md").read_text(encoding="utf-8").replace("\n", "\r\n"),
    43: (FIXTURES / "issues" / "uncharted.md").read_text(encoding="utf-8"),
}


class Fetched:
    """An injected fetch in place of gh: each issue's body, by number; an unknown number fails as gh would."""

    def __init__(self, issues: Mapping[int, str]) -> None:
        self.issues = issues

    def __call__(self, number: int) -> str:
        if number not in self.issues:
            raise FetchError("HTTP 404: Not Found")
        return self.issues[number]


def run(
    root: Path, capsys: pytest.CaptureFixture[str], *issues: int, bodies: Mapping[int, str] = ISSUES
) -> tuple[int, str]:
    """The importer on the tree at root for these issues: its exit code and everything it printed."""
    code = main([str(number) for number in issues], root, Fetched(bodies))
    out, err = capsys.readouterr()
    return code, out + err


def part(rows: str, n: int = 1, m: int = 1, data: str = "3f9a2c1e", reporter: str = ALICE) -> str:
    """A PAGLE-REPORT part (REP-R30) with these rows, as Core writes it."""
    header = f"addon 0.9.0 data {data} locale enUS reporter {reporter} part {n}/{m}"
    return f"PAGLE-REPORT 1\n{header}\n{rows}END\n"


def parsed(text: str, issues: tuple[int, ...]) -> Report:
    """One whole report parsed from text, as data/observed/ holds it after importing issues."""
    problems = Problems()
    found = parse_part(text, "test", problems)
    assert found is not None, problems.found
    (field_report,) = join([found], problems)
    assert problems.found == []
    return field_report.observed(issues)


def test_an_upsert_replaces_rows_by_key_keeps_their_rejected_marks_and_keeps_rows_the_report_lacks() -> None:
    # DATA-R121: one row per row key. A new row replaces the stored row with its key and keeps its rejected mark
    # (DATA-R50); stored rows the new report lacks are kept (reports leave out what a release confirmed, REP-R2). The
    # file records every imported issue and the latest header, and is written sorted: rows by key, issues ascending.
    stored = parsed(part("I 6303 297 70338 1\nI 6291 12 70338 2\nK 33 70338 casts=9 away=1\n"), (101,))
    flagged = replace(stored.catches[1], rejected="a client bug")
    stored = replace(stored, catches=(stored.catches[0], flagged))
    new = parsed(part("I 13760 368 70338 1\nI 6291 12 70338 5\n", data="0badf00d"), (206, 205))

    assert observed_toml(upsert(stored, new)) == """\
issues = [101, 205, 206]

[header]
addon = "0.9.0"
data = "0badf00d"
locale = "enUS"

[[i]]
item = 6291
area = 12
build = 70338
count = 5
rejected = "a client bug"

[[i]]
item = 6303
area = 297
build = 70338
count = 1

[[i]]
item = 13760
area = 368
build = 70338
count = 1

[[k]]
area = 33
build = 70338
casts = 9
away = 1
"""


def test_an_upsert_into_no_stored_file_is_the_report_sorted() -> None:
    # DATA-R121: the first import of a reporter writes its report, rows sorted by key (an I row without t and m
    # before one with them) so a re-import's diff shows only what changed.
    new = parsed(
        part(
            'P 12 enUS "School of Fish" casts=2 6291x2\nI 6291 12 70338 1 t=21:15 m=11\nI 6291 12 70338 1\n'
            "K 33 70338 casts=4 away=0 land=140\nK 12 70338 casts=1 away=1\n"
        ),
        (7,),
    )
    assert observed_toml(upsert(None, new)) == """\
issues = [7]

[header]
addon = "0.9.0"
data = "3f9a2c1e"
locale = "enUS"

[[i]]
item = 6291
area = 12
build = 70338
count = 1

[[i]]
item = 6291
area = 12
build = 70338
count = 1
t = "21:15"
m = 11

[[k]]
area = 12
build = 70338
casts = 1
away = 1

[[k]]
area = 33
build = 70338
casts = 4
away = 0
land = 140

[[p]]
area = 12
locale = "enUS"
text = "School of Fish"
casts = 2
items = { 6291 = 2 }
"""
    assert upsert(None, new).header == Header("0.9.0", "3f9a2c1e", "enUS")


# Alice's file after importing #41 and #42, by hand from DATA-R121: both parts' rows sorted by key, both issues.
ALICE_TOML = """\
issues = [41, 42]

[header]
addon = "0.9.0"
data = "3f9a2c1e"
locale = "enUS"

[[i]]
item = 6291
area = 12
build = 70338
count = 2

[[i]]
item = 6308
area = 368
build = 70338
count = 1

[[i]]
item = 13759
area = 33
build = 70338
count = 1
t = "13:00"
m = 6

[[k]]
area = 33
build = 70338
casts = 10
away = 2
land = 125
"""


def test_a_two_part_report_from_two_issues_writes_one_file_with_both_parts(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R119: every part of the report among the issues given; DATA-R121: one file per reporter key with both
    # parts' rows, both issue numbers and the header. The generator then runs (DATA-R60), and Catalogue.lua
    # carries what the rows confirm (DATA-R47: 6308 joins Echo Isles as an observed pair).
    root = write_tree(tmp_path)
    code, output = run(root, capsys, 42, 41)
    assert code == 0, output
    assert (root / REPORTS / f"{ALICE}.toml").read_text(encoding="utf-8") == ALICE_TOML
    assert "{ confirmed = true, itemID = 6308 }" in (root / CATALOGUE).read_text(encoding="utf-8")
    # DATA-R120: the line for the PR's message, a Closes for each issue (GitHub links only the number right after
    # the keyword), and what to commit with the observed file.
    assert "Closes #41, Closes #42" in output
    assert "data/forever/" in output and "regenerated" in output


def test_a_report_with_a_part_missing_writes_nothing_and_names_the_part(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R119: a report needs every part among the issues given (REP-R33); a missing part writes nothing.
    root = write_tree(tmp_path)
    code, output = run(root, capsys, 41)
    assert code == 1
    assert "part 2/2" in output and "missing" in output
    assert not (root / REPORTS).exists()
    assert not (root / CATALOGUE).exists()


def test_an_issue_gh_cant_fetch_or_without_a_report_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R119: each issue is fetched and its report field taken (DATA-R115); one that can't be is named, and
    # nothing is written.
    root = write_tree(tmp_path)
    code, output = run(root, capsys, 41, 42, 99)
    assert code == 1
    assert "#99" in output and "404" in output
    assert not (root / REPORTS).exists()
    code, output = run(root, capsys, 41, 42, bodies={41: ISSUES[41], 42: "### Anything you noticed?\n\nno report"})
    assert code == 1
    assert "#42" in output and "Report" in output
    assert not (root / REPORTS).exists()


def test_the_changes_list_new_and_confirmed_pairs_contradictions_and_an_item_needing_a_category(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R119: the importer prints what changed in the catalogue. Over test_catch_lists' tree:
    # - DATA-R47/R48: 6308 is in neither Echo Isles' (368) nor Durotar's list, so Alice's row is an observed pair
    #   that joins confirmed; her 6291 row confirms Elwynn Forest's (12) entry.
    # - DATA-R51/R52: 13:00 lies wholly outside night [18:00, 12:00), so her 13759 row in 33 contradicts the gate
    #   (13759, night), which 33 and 368 carry.
    # - DATA-R55: her land of 125 in 33 is below its skill base 130, so the skill base is contradicted.
    # - DATA-R15/R17: Bob's 30500 is in no layer, so it joins the universe with no category: it is printed as needing
    #   one, the generator fails (DATA-R63) and the exit code is non-zero, and the written files stay.
    root = write_tree(tmp_path)
    code, output = run(root, capsys, 41, 42, 43)
    assert code == 1
    lines = output.splitlines()
    for expected in (
        "  new pair: item 6308 in area 368 (confirmed)",
        "  confirmed pair: item 6291 in area 12",
        "  contradicted gate: item 13759 by night (areas 33, 368)",
        "  contradicted skill base: area 33 (130)",
        "  needs a category: item 30500 (DATA-R17), or category = \"uncharted\" with a why to defer it (DATA-R18)",
    ):
        assert expected in lines, output
    assert "no category; every item of the universe that isn't Noise needs one (DATA-R17)" in output
    assert (root / REPORTS / f"{ALICE}.toml").read_text(encoding="utf-8") == ALICE_TOML
    assert (root / REPORTS / f"{BOB}.toml").exists()
    assert "Closes #41, Closes #42, Closes #43" in output


def test_a_contradiction_demotes_what_was_confirmed(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R52: a gate is contradicted when any reporter has an outside row, whatever confirmed it before; DATA-R53:
    # a window with a contradicted gate isn't confirmed. Bob's stored row at 22:00 in June confirmed (13759, night)
    # and with it the night window; Alice's 13:00 row takes both away again.
    stored = "issues = [7]\n\n[header]\naddon = \"0.9.0\"\ndata = \"3f9a2c1e\"\nlocale = \"enUS\"\n\n"
    stored += '[[i]]\nitem = 13759\narea = 33\nbuild = 70338\ncount = 1\nt = "22:00"\nm = 6\n'
    root = write_tree(tmp_path, reports={BOB: stored})
    code, output = run(root, capsys, 41, 42)
    assert code == 0, output
    lines = output.splitlines()
    assert "  contradicted gate: item 13759 by night (areas 33, 368)" in lines
    assert "  no longer confirmed: gate: item 13759 in area 33 by night" in lines
    assert "  no longer confirmed: window: night" in lines


def test_an_import_that_changes_nothing_says_so(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R48: a pair already confirmed stays as it was, so re-importing the same report changes nothing.
    root = write_tree(tmp_path)
    assert run(root, capsys, 41, 42)[0] == 0
    code, output = run(root, capsys, 41, 42)
    assert code == 0
    assert "nothing changed in the catalogue" in output


def test_a_reimport_of_the_same_issues_leaves_the_file_byte_identical(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R121: the file is written deterministically, so a re-import's diff shows only what changed: none here.
    root = write_tree(tmp_path)
    assert run(root, capsys, 41, 42)[0] == 0
    assert run(root, capsys, 42, 41)[0] == 0
    assert (root / REPORTS / f"{ALICE}.toml").read_text(encoding="utf-8") == ALICE_TOML


def test_an_i_row_without_t_and_m_imports_and_is_no_time_gated_evidence(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # REP-R20: a Cast with no realm minute (read while the realm clock was secret) gives even a gated item's row
    # neither t nor m. The parser and the importer take the row as it is (DATA-R116, DATA-R121), and it is neither
    # inside nor outside a time gate (DATA-R51): Bob's 13759 row in Stranglethorn Vale (33) leaves (13759, night) as
    # it was, where a row at 22:00 in June confirms it.
    def body(row: str) -> str:
        return ISSUES[43].replace("I 30500 33 70338 1", row)

    root = write_tree(tmp_path / "unknown")
    code, output = run(root, capsys, 43, bodies={43: body("I 13759 33 70338 4")})
    assert code == 0, output
    stored = (root / REPORTS / f"{BOB}.toml").read_text(encoding="utf-8")
    assert stored.endswith("[[i]]\nitem = 13759\narea = 33\nbuild = 70338\ncount = 4\n"), stored
    assert not [line for line in output.splitlines() if "gate" in line], output

    root = write_tree(tmp_path / "inside")
    code, output = run(root, capsys, 43, bodies={43: body("I 13759 33 70338 4 t=22:00 m=6")})
    assert code == 0, output
    assert [line for line in output.splitlines() if "gate" in line and "13759" in line], output
