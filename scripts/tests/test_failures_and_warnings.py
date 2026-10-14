"""DATA-R63 and DATA-R64 across every layer M2 adds: one run lists every problem and writes nothing; every warning
prints on every run but the read-only modes, and none fails. Over test_catch_lists.py's fixture tree, with
hand-made data/observed/ rows (#94's fixture layer) as in test_confirmed.py. Each failure and warning also has its
own test next to its layer's rule."""

from pathlib import Path

import pytest

from observed_fixture import i_row, report
from pools_fixture import POOLS
from test_catch_lists import AREA_LOOT, AREAS_TOML, CATALOGUE, ITEMS, catch, run, write_tree
from test_confirmed import ALICE, INSIDE_DAY
from windows_fixture import WINDOWS


def test_a_tree_breaking_one_rule_in_every_m2_layer_fails_once_listing_them_all(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R63: the generator fails, writing nothing and listing every problem found. One problem per layer M2
    # adds: items.toml (DATA-R17), items.csv (DATA-R11), windows.toml (DATA-R10), areas.toml (DATA-R35),
    # pools.toml (DATA-R10) and data/observed/ (DATA-R23, 6309 is removed from build 70338).
    root = write_tree(
        tmp_path,
        AREAS_TOML + catch(33, 13759, gate="dusk"),
        items=ITEMS.replace('[item.13760]\ncategory = "fish"\n', "[item.13760]\n"),
        reports={ALICE: report(i_row(6309, 368))},
    )
    forever = root / "data" / "forever"
    (forever / "windows.toml").write_text(WINDOWS + "\n[window.night]\ntime = [[1080, 720]]\n", encoding="utf-8")
    (forever / "pools.toml").write_text(POOLS.replace('why = "baseline_fixture\'s one pool template"\n', ""), "utf-8")
    items_csv = root / "data" / "db2" / "items.csv"
    items_csv.write_text(items_csv.read_text(encoding="utf-8") + "x6303,7,8,1,Raw\n", encoding="utf-8")
    code, output = run(root, capsys)
    assert code == 1
    problems = [
        "generate-data: data/forever/items.toml: item.13760: no category",
        "generate-data: data/db2/items.csv: line 2: ID: expected a positive integer, got 'x6303'",
        "generate-data: data/forever/windows.toml: window.night: missing key 'why'",
        "generate-data: data/forever/areas.toml: catch[2].gate: 'dusk' isn't a window ID (DATA-R35)",
        "generate-data: data/forever/pools.toml: pool.extravaganza: missing key 'why'",
        f"generate-data: data/observed/reports/{ALICE}.toml: i[0]: item 6309 is observed on build 70338",
    ]
    for problem in problems:
        assert output.count(problem) == 1, output
    assert f"generate-data: {len(problems)} problem(s) in data/; wrote nothing" in output
    assert not (root / CATALOGUE).exists()


# DATA-R64's four warnings, from one tree: a baseline row whose condition isn't a single event (DATA-R9), a row in an
# area missing from the slice (DATA-R33), an observed pair without a consistent gate (DATA-R47: 13760 is gated by
# day in 33 and ungated in 368, so its pair at Crystal Lake, 18, joins ungated) and, with aliases.toml empty, the map
# 2940 copies proposed as aliases (DATA-R32): 16510 -> 12 and 16521 -> 18, counted in one line.
WARNINGS = [
    "generate-data: warning: data/baseline/area_loot.csv: area 33 item 6291 has the condition"
    " and(event(48), not(event(45))), not a single event; it is treated as ungated",
    "generate-data: warning: area 99999 seen in data/observed/ is not in data/db2/areas.csv; update the DB2 slice",
    "generate-data: warning: the observed pair item 13760 in area 18 joins ungated, but the item is gated elsewhere"
    " (area 33 by day)",
    "generate-data: warning: 2 uncommitted alias proposals; run scripts/generate-data.py --propose-aliases to list"
    " them",
]


def warning_tree(root: Path) -> Path:
    loot = AREA_LOOT + '33,6291,1.5,,,"and(event(48), not(event(45)))"\n'
    rows = report(i_row(6308, 99999), i_row(13760, 18, extra=INSIDE_DAY))
    return write_tree(root, area_loot=loot, aliases="", reports={ALICE: rows})


@pytest.mark.parametrize("mode", [[], ["--check"]])
def test_every_data_r64_warning_prints_and_the_run_succeeds(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], mode: list[str]
) -> None:
    # DATA-R64: warnings are printed, not failing, on every run, --check's included.
    root = warning_tree(tmp_path)
    run(root, capsys)
    code, output = run(root, capsys, *mode)
    assert code == 0, output
    for warning in WARNINGS:
        assert warning in output, output
    assert (root / CATALOGUE).exists()


@pytest.mark.parametrize("mode", [["--propose-aliases"], ["--min-build", "1"], ["--explain", "33"]])
def test_the_read_only_modes_print_no_warning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], mode: list[str]
) -> None:
    # DATA-R64 as #96 asks: the warnings print on every run except the read-only modes, which write nothing.
    root = warning_tree(tmp_path)
    code, output = run(root, capsys, *mode)
    assert code == 0, output
    assert "warning:" not in output
    assert not (root / CATALOGUE).exists()
