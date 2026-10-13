"""scripts/generate-data.py --min-build <n> (DATA-R57, DATA-R60): which facts would lose confirmation if only builds
>= n counted, written nowhere. Over test_catch_lists.py's fixture tree with hand-made data/observed/ rows (#94's
fixture layer), as in test_confirmed.py."""

from pathlib import Path

import pytest

from observed_fixture import i_row, report
from test_catch_lists import CATALOGUE, run, write_tree
from test_confirmed import ALICE, DEV, INSIDE_DAY, fact, skill_row

# Every kind of fact DATA-R57 names, each confirmed by one observation on build 100 alone:
# - a pair: 6308 is in neither Echo Isles' (368) nor Durotar's list, so the row is an observed pair (DATA-R47) that
#   joins confirmed (DATA-R48)
# - a pair, a gate and a window: an inside row confirms Stranglethorn Vale's (33) 13760 entry (DATA-R48), its gate
#   by day and so day (DATA-R52, DATA-R53)
# - a skill base: a land at 33's base confirms it (DATA-R55)
# - a weekly rule: a dev fact confirms event 301's (DATA-R54), and with it the event.301 window (DATA-R53)
# 6291 in Elwynn Forest (12) is confirmed by a build-101 row too, so it never loses confirmation.
ROWS = {
    ALICE: report(
        i_row(6308, 368, build=100),
        i_row(13760, 33, build=100, extra=INSIDE_DAY),
        i_row(6291, 12, build=101),
        skill_row(33, "land = 130\n").replace("build = 70338", "build = 100"),
    )
}
DEV_FACTS = DEV + fact("weekly", "event = 301\n", build=100)

LOSSES = [
    "pair: item 13760 in area 33",
    "pair: item 6308 in area 368 (an observed pair: it would leave the list)",
    "gate: item 13760 in area 33 by day",
    "window: day",
    "window: event.301",
    "weekly rule: event 301",
    "skill base: area 33",
]


def min_build(root: Path, capsys: pytest.CaptureFixture[str], build: int) -> str:
    code, output = run(root, capsys, "--min-build", str(build))
    assert code == 0, output
    return output


def test_min_build_lists_each_fact_confirmed_only_below_it_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R57: --min-build <n> reports, without writing anything, which facts would lose confirmation if only
    # builds >= n counted: pairs, gates, windows, weekly rules and skill bases.
    root = write_tree(tmp_path, dev=DEV_FACTS, reports=ROWS)
    output = min_build(root, capsys, 101)
    assert "generate-data: 7 fact(s) would lose confirmation if only builds >= 101 counted (DATA-R57)" in output
    for loss in LOSSES:
        assert f"\n{loss}\n" in output
    assert "6291" not in output
    assert not (root / CATALOGUE).exists()


def test_min_build_at_the_lowest_confirming_build_lists_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R57: every fact above rests on a build-100 observation, which still counts with n = 100.
    root = write_tree(tmp_path, dev=DEV_FACTS, reports=ROWS)
    output = min_build(root, capsys, 100)
    assert "generate-data: no fact would lose confirmation if only builds >= 100 counted (DATA-R57)" in output
    for loss in LOSSES:
        assert loss not in output
    assert not (root / CATALOGUE).exists()


def test_min_build_is_a_read_only_mode_that_prints_no_warning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R64: the warnings print on every run except the read-only modes. The tree's map 2940 copy of Westfall
    # isn't there, but a row in an area missing from the slice is (DATA-R33).
    reports = {ALICE: report(i_row(6308, 99999))}
    code, output = run(write_tree(tmp_path, reports=reports), capsys)
    assert code == 0
    assert "warning" in output
    output = min_build(tmp_path, capsys, 1)
    assert "warning" not in output


def test_min_build_needs_a_whole_number(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R57: n is a build number.
    with pytest.raises(SystemExit):
        run(write_tree(tmp_path), capsys, "--min-build", "x")
    assert "invalid int value: 'x'" in capsys.readouterr().err


def test_min_build_fails_on_any_problem_in_data(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: the generator reads every layer first, so a problem fails every mode.
    code, output = run(write_tree(tmp_path, dev=DEV + fact("skillBase", "area = 297\n")), capsys, "--min-build", "1")
    assert code == 1
    assert "area 297 has no skill base" in output
