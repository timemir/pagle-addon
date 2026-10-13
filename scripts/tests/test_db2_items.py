"""data/db2/items.csv as the generator reads it into the DB2 layer (DATA-R11, DATA-R63), over small fixture trees."""

from pathlib import Path

import pytest

from pagle_data.cli import main
from pagle_data.db2 import Item, read_db2
from pagle_data.toml_reader import Problems
from test_db2_layer import CATALOGUE, EXPECTED, write_tree

# DATA-R11: ID, ClassID, SubclassID, Quality and the enUS name, under wago.tools' column names, sorted by ID. Names
# chosen so that no other text in a generated file could hold them.
ITEMS = """\
ID,ClassID,SubclassID,OverallQualityID,Display_lang
6303,7,8,1,Raw Quillfin Sample
6358,12,0,1,"Oily Brackenfish, Large"
19807,15,0,2,Speckled Zephyrine
"""


def write_items(root: Path, items: str | None) -> Path:
    write_tree(root)
    path = root / "data" / "db2" / "items.csv"
    if items is None:
        path.unlink()
    else:
        path.write_text(items, encoding="utf-8")
    return root


def run(root: Path, capsys: pytest.CaptureFixture[str], *args: str) -> tuple[int, str]:
    code = main(list(args), root)
    out, err = capsys.readouterr()
    return code, out + err


def test_every_items_csv_row_is_read_into_the_db2_layer(tmp_path: Path) -> None:
    # DATA-R11: items.csv gives each item's class, subclass, quality and enUS name, keyed by ID.
    problems = Problems()
    layer = read_db2(write_items(tmp_path, ITEMS), problems)
    assert problems.found == []
    assert layer.items == {
        6303: Item(class_id=7, subclass=8, quality=1, name="Raw Quillfin Sample"),
        6358: Item(class_id=12, subclass=0, quality=1, name="Oily Brackenfish, Large"),
        19807: Item(class_id=15, subclass=0, quality=2, name="Speckled Zephyrine"),
    }


def test_items_csv_gives_the_records_their_quality_and_no_item_name_ships(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R77: an item record carries its DB2 quality when known; DATA-R16: 6358's ClassID 12 isn't a Noise class,
    # but it is reachable only through reference loot, so it stays Noise. DATA-R3: names never reach a generated file.
    code, output = run(write_items(tmp_path, ITEMS), capsys)
    assert code == 0, output
    generated = (tmp_path / CATALOGUE).read_text(encoding="utf-8")
    assert generated != EXPECTED
    for line in [
        "[6303] = { category = \"fish\", legend = false, noise = false, pool = false, quality = 1, removed = false,"
        " species = 6303 },",
        "[6358] = { category = \"other\", legend = false, noise = true, pool = false, quality = 1, removed = false },",
        "[19807] = { category = \"fish\", legend = false, noise = false, pool = false, quality = 2, removed = false,"
        " species = 19807 },",
    ]:
        assert line in generated
    for name in ["Quillfin", "Brackenfish", "Zephyrine"]:
        assert name not in generated


def test_a_bad_items_csv_fails_listing_every_bad_row_and_writing_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R63 (as #89 asks of items.csv, the same reporting as areas.csv): each bad row fails the generator,
    # named by file and line, and nothing is written.
    items = (
        "ID,ClassID,SubclassID,OverallQualityID,Display_lang\n"
        "6303,7,8,1,Raw Quillfin Sample\n"
        "x6358,12,0,1,Bad Id\n"
        "6359,12\n"
        "6360,12,0,poor,Bad Quality\n"
        "6361,-1,0,1,Below\n"
        "6303,7,8,2,Again\n"
    )
    code, output = run(write_items(tmp_path, items), capsys)
    assert code == 1
    for problem in [
        "data/db2/items.csv: line 3: ID: expected a positive integer, got 'x6358'",
        "data/db2/items.csv: line 4: expected 5 fields, got 2: 6359,12",
        "data/db2/items.csv: line 5: OverallQualityID: expected an integer of 0 or more, got 'poor'",
        "data/db2/items.csv: line 6: ClassID: expected an integer of 0 or more, got '-1'",
        "data/db2/items.csv: line 7: ID 6303 is listed twice",
        "5 problem(s) in data/; wrote nothing",
    ]:
        assert problem in output
    assert not (tmp_path / CATALOGUE).exists()


@pytest.mark.parametrize(
    ("items", "problem"),
    [
        # DATA-R11: items.csv has the five columns ID, ClassID, SubclassID, Quality and the enUS name.
        ("ID,ClassID,SubclassID,Display_lang\n6303,7,8,Raw\n", "items.csv: missing column 'OverallQualityID'"),
        (
            "ID,ClassID,SubclassID,OverallQualityID,Display_lang,SellPrice\n6303,7,8,1,Raw,4\n",
            "items.csv: unknown column 'SellPrice'",
        ),
        ("", "items.csv: empty: expected a header row"),
        ('ID,ClassID,SubclassID,OverallQualityID,Display_lang\n6303,7,8,1,"Open\n', "items.csv: line 2: not a valid"),
        (None, "data/db2/items.csv: missing"),
    ],
)
def test_a_malformed_items_csv_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], items: str | None, problem: str
) -> None:
    code, output = run(write_items(tmp_path, items), capsys)
    assert code == 1
    assert problem in output
    assert not (tmp_path / CATALOGUE).exists()


def test_an_item_name_may_span_lines(tmp_path: Path) -> None:
    # wago.tools' CSVs quote a field holding a line break; the row after it keeps its own line number.
    items = 'ID,ClassID,SubclassID,OverallQualityID,Display_lang\n6303,7,8,1,"Two\nLines"\nx1,0,0,0,Bad\n'
    problems = Problems()
    layer = read_db2(write_items(tmp_path, items), problems)
    assert layer.items[6303].name == "Two\nLines"
    assert problems.found == ["data/db2/items.csv: line 4: ID: expected a positive integer, got 'x1'"]
