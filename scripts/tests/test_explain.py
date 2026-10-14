"""scripts/generate-data.py --explain <itemID|areaID> (DATA-R60): every layer's value for an item or an area and
which won, written nowhere. Over test_catch_lists.py's fixture tree, with hand-made data/observed/ rows (#94's
fixture layer) as in test_confirmed.py."""

from pathlib import Path

import pytest

from cli_fixture import run
from observed_fixture import i_row, report
from test_catch_lists import CATALOGUE, ITEMS, write_tree
from test_confirmed import ALICE

# 6308 is junk. items.csv gives it class 2 (Weapon), a Noise class, so it is Noise by DATA-R16's rule; items.toml
# overrides the rule with noise = false.
ITEMS_CSV = "ID,ClassID,SubclassID,OverallQualityID,Display_lang\n6308,2,0,1,Planted Junk\n"
OVERRIDDEN = ITEMS.replace('[item.6308]\ncategory = "junk"\n', '[item.6308]\ncategory = "junk"\nnoise = false\nwhy = "x"\n')


def explain(root: Path, capsys: pytest.CaptureFixture[str], target: int) -> str:
    code, output = run(root, capsys, "--explain", str(target))
    assert code == 0, output
    assert not (root / CATALOGUE).exists()
    return output


def tree(root: Path, reports: dict[str, str] | None = None) -> Path:
    write_tree(root, items=OVERRIDDEN, reports=reports)
    (root / "data" / "db2" / "items.csv").write_text(ITEMS_CSV, encoding="utf-8")
    return root


def test_explain_an_item_shows_the_db2_value_the_override_and_the_override_winning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R60: every layer's value for the fact and which won. DATA-R16: DB2's class 2 makes 6308 Noise by rule;
    # items.toml's noise = false overrides it. DATA-R24: DB2 gives class and quality.
    output = explain(tree(tmp_path), capsys, 6308)
    for line in [
        "item 6308",
        "  data/baseline/: area loot in area 53",
        '  data/forever/items.toml: item.6308: category = "junk", noise = false',
        "  data/db2/items.csv: class 2, subclass 0, quality 1, name 'Planted Junk'",
        "  data/observed/: no observation",
        "  class: 2 from data/db2/items.csv -> data/db2/items.csv wins: 2",
        "  noise: true by rule (DB2 class 2 is a Noise class) from data/db2/items.csv; false from"
        " data/forever/items.toml -> data/forever/items.toml wins: false",
        "  category: junk from data/forever/items.toml -> data/forever/items.toml wins: junk",
        '  record: { category = "junk", legend = false, noise = false, pool = false, quality = 1, removed = false }',
        "  pool types: none",
        # DATA-R27: Thieves Camp's baseline list is cleared.
        "    area 53: data/baseline/area_loot.csv lists it; data/forever/areas.toml: area[0]: clearBaseline empties"
        " the baseline list -> not listed",
    ]:
        assert f"{line}\n" in output, output


def test_explain_an_item_names_its_pool_types_lists_and_observations(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R60: an item's pool types (DATA-R43) and the lists it is on (DATA-R26), with each list's gate.
    output = explain(tree(tmp_path, {ALICE: report(i_row(19807, 33, extra="event = [301]\n"))}), capsys, 19807)
    for line in [
        "  data/baseline/: pool loot of 180248",
        "  data/observed/: 1 catch row(s) from 1 reporter(s), in area 33",
        "  pool types: extravaganza (data/baseline/pool_loot.csv: entry 180248) -> in its catches",
        "    area 33: data/forever/areas.toml: catch[0]: add, gate event.301 -> listed, gate event.301;"
        " confirmed = true, gateConfirmed = true",
    ]:
        assert f"{line}\n" in output, output


def test_explain_an_area_shows_each_entry_s_source(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R60: an area's slice row, skill base, catch list with each entry's source (the baseline, areas.toml, an
    # observed pair), gates and confirmed flags. 6291 is in no list in or above Stranglethorn Vale (33), so one row
    # makes it an observed pair there (DATA-R47).
    output = explain(tree(tmp_path, {ALICE: report(i_row(6291, 33))}), capsys, 33)
    for line in [
        "area 33",
        "  data/db2/areas.csv: parent 0, continent 0, name 'Stranglethorn Vale'",
        "  skill base: 130 from data/baseline/skill.csv -> data/baseline/skill.csv wins: 130; skillBaseConfirmed = false",
        "  hasData = true",
        "    item 6291: observed pair (DATA-R47), ungated -> listed; confirmed = true",
        "    item 6303: data/baseline/area_loot.csv lists it through reference table 500, gated by summer"
        " -> listed, gate summer; confirmed = false, gateConfirmed = false",
        "    item 6358: data/baseline/area_loot.csv lists it; Noise, left out -> not listed",
        "    item 6359: data/baseline/area_loot.csv lists it through reference table 500; Noise, left out -> not listed",
        "    item 13760: data/baseline/area_loot.csv lists it, gated by day -> listed, gate day; confirmed = false,"
        " gateConfirmed = false",
        "    item 19803: data/forever/areas.toml: catch[1]: add, gate event.301 -> listed, gate event.301;"
        " confirmed = false, gateConfirmed = false",
    ]:
        assert f"{line}\n" in output, output


def test_explain_an_area_shows_a_skill_base_override_drops_and_removals(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R30: areas.toml's skillBase wins over skill.csv's. DATA-R26: a drop removes an item (step 2); a removed or
    # uncharted item leaves the list (step 4). Jaguero Isle (297) lists the removed 6309 and the uncharted 6310.
    output = explain(tree(tmp_path), capsys, 12)
    assert (
        "  skill base: -20 from data/baseline/skill.csv; -25 from data/forever/areas.toml: area[1] ->"
        " data/forever/areas.toml wins: -25; skillBaseConfirmed = false\n"
    ) in output
    output = explain(tree(tmp_path), capsys, 297)
    assert (
        "  skill base: 205 from data/baseline/skill.csv, ignored: a subzone takes none from it (DATA-R30) -> none;"
        " skillBaseConfirmed = false\n"
    ) in output
    assert "    item 6309: data/baseline/area_loot.csv lists it; removed, left out -> not listed\n" in output
    assert "    item 6310: data/baseline/area_loot.csv lists it; uncharted, left out -> not listed\n" in output


def test_explain_an_alias_source_says_it_ships_no_catches(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R31, DATA-R32: an alias source ships hasData = false and no catches.
    output = explain(tree(tmp_path), capsys, 16521)
    assert "  alias: data/forever/aliases.toml maps it to 18; it ships no catches (DATA-R31)\n" in output
    assert "  hasData = false\n" in output
    output = explain(tree(tmp_path), capsys, 18)
    assert "  alias: the target of 16521 in data/forever/aliases.toml\n" in output


def test_an_id_that_is_both_an_item_and_an_area_explains_both(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R60: --explain <itemID|areaID>; an ID that is both prints both (graph.md decision).
    root = tree(tmp_path)
    areas_csv = root / "data" / "db2" / "areas.csv"
    areas_csv.write_text(areas_csv.read_text(encoding="utf-8") + "6308,0,0,Planted Zone\n", encoding="utf-8")
    output = explain(root, capsys, 6308)
    assert "item 6308\n" in output
    assert "area 6308\n" in output
    assert "  data/db2/areas.csv: parent 0, continent 0, name 'Planted Zone'\n" in output


def test_an_id_in_no_layer_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R15: an item outside the universe is Uncharted at runtime; DATA-R25: the catalogue's areas are areas.csv's.
    code, output = run(tree(tmp_path), capsys, "--explain", "424242")
    assert code == 1
    assert "generate-data: 424242 is neither an item of the universe (DATA-R15) nor an area of data/db2/areas.csv" in (
        output
    )


def test_explain_is_a_read_only_mode_that_prints_no_warning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R64: the warnings print on every run except the read-only modes; a row in an area missing from the slice
    # would be one (DATA-R33).
    root = tree(tmp_path, {ALICE: report(i_row(6308, 99999))})
    assert "warning" not in explain(root, capsys, 6308)
