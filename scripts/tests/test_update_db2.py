"""scripts/update-db2.py against canned wago.tools responses (DATA-R11, DATA-R12). Nothing here touches the network."""

from pathlib import Path

import pytest

from baseline_fixture import write_baseline
from cli_fixture import Canned, run
from observed_fixture import i_row, report, write_observed
from pagle_data.db2_update import main

AREA_URL = "https://wago.tools/db2/AreaTable/csv?build=1.60.1.70338"
SPARSE_URL = "https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70338"
ITEM_URL = "https://wago.tools/db2/Item/csv?build=1.60.1.70338"

# A cut-down AreaTable as wago.tools serves it: more columns than the slice keeps, in wago's order, rows not sorted
# by ID, a name quoted for its space and one for its comma, and a UTF-8 byte order mark.
CANNED_AREAS = (
    "﻿ID,ZoneName,AreaName_lang,ContinentID,ParentAreaID,AreaBit,Ambient_multiplier\n"
    '148,Darkshore,"Darkshore",1,0,128,0\n'
    '12,ElwynnForest,"Elwynn Forest",0,0,126,0\n'
    "9,NorthshireValley,\"Northshire Valley\",0,12,125,0.80000001192\n"
    '16521,Duplicate,"Coast, North",2940,16520,9001,0\n'
)

# By hand from DATA-R11: the four columns ID, ParentAreaID, ContinentID, enUS name, one row per AreaTable row,
# sorted by ID (#56).
AREAS = """\
ID,ParentAreaID,ContinentID,AreaName_lang
9,12,0,Northshire Valley
12,0,0,Elwynn Forest
148,0,1,Darkshore
16521,16520,2940,"Coast, North"
"""

# The fixture baseline's item universe (DATA-R15) is 6303, 6358, 13759 and 19807 (test_universe.py). A cut-down
# ItemSparse as wago.tools serves it, columns in wago's order with others between them: 99999 is outside the
# universe, 13759 is missing (the client streams item records), one description spans two lines and one name is
# quoted for its comma.
CANNED_SPARSE = (
    "﻿ID,Description_lang,Display3_lang,Display_lang,ExpansionID,SellPrice,OverallQualityID,ItemLevel\n"
    '19807,"Smells of the\nsea.",,Speckled Tastyfish,0,1,2,40\n'
    "99999,,,Copper Shortsword,0,10,1,5\n"
    "6303,,,Raw Slitherskin Mackerel,0,1,1,5\n"
    '6358,,,"Oily Blackmouth, Large",0,4,1,15\n'
)

# A cut-down Item, rows in another order: 13759 is in Item but not ItemSparse, and 99999 is outside the universe.
CANNED_ITEM = (
    "﻿ID,ClassID,SubclassID,Material,InventoryType,IconFileDataID\n"
    "6358,7,8,0,0,134300\n"
    "13759,0,5,0,0,133890\n"
    "99999,2,7,1,21,135274\n"
    "6303,0,5,0,0,133918\n"
    "19807,15,0,0,0,133916\n"
)

# By hand from DATA-R11 and DATA-R12: ID, ClassID and SubclassID from Item, quality and the enUS name from
# ItemSparse, for the universe's items that both tables have, sorted by ID.
ITEMS = """\
ID,ClassID,SubclassID,OverallQualityID,Display_lang
6303,0,5,1,Raw Slitherskin Mackerel
6358,7,8,1,"Oily Blackmouth, Large"
19807,15,0,2,Speckled Tastyfish
"""

BUILD = """\
# Written by scripts/update-db2.py (DATA-R11, DATA-R12): the Forever build data/db2/ describes.
build = 70338
version = "1.60.1"
products = ["wow_classic_beta"]
"""


def canned(**changes: bytes) -> dict[str, bytes]:
    responses = {
        AREA_URL: CANNED_AREAS.encode("utf-8"),
        SPARSE_URL: CANNED_SPARSE.encode("utf-8"),
        ITEM_URL: CANNED_ITEM.encode("utf-8"),
    }
    urls = {"areas": AREA_URL, "sparse": SPARSE_URL, "item": ITEM_URL}
    for key, body in changes.items():
        responses[urls[key]] = body
    return responses


def tree(root: Path) -> Path:
    write_baseline(root)
    write_observed(root)  # dev.toml with no facts; test_observed.py covers the layer
    return root


def read(root: Path, name: str) -> str:
    return (root / "data" / "db2" / name).read_text(encoding="utf-8")


def test_writes_the_slice_and_a_matching_build_toml(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R12: downloads AreaTable, ItemSparse and Item for the build from wago.tools and rewrites areas.csv and
    # items.csv; DATA-R11: build.toml holds the build number, the version string and the products, seeded as
    # ["wow_classic_beta"] (DATA-R128).
    fetch = Canned(canned())
    code, output = run(tree(tmp_path), capsys, "1.60.1.70338", main=main, fetch=fetch)
    assert code == 0, output
    assert sorted(fetch.asked) == sorted([AREA_URL, SPARSE_URL, ITEM_URL])
    assert read(tmp_path, "areas.csv") == AREAS
    assert read(tmp_path, "items.csv") == ITEMS
    assert read(tmp_path, "build.toml") == BUILD


def test_lists_the_universe_s_items_db2_lacks(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R23, DATA-R24 and #89: an item DB2 lacks isn't a failure (the client streams item records, and items.toml
    # may give its class and quality), but the run names it for the PR.
    code, output = run(tree(tmp_path), capsys, "1.60.1.70338", main=main, fetch=Canned(canned()))
    assert code == 0, output
    assert "1 item(s) of the universe not in DB2 (DATA-R24): 13759" in output


def test_an_item_named_in_data_forever_gets_its_row(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R11: items.csv covers the whole universe (DATA-R15), forever files included: 99999 joins through items.toml.
    forever = tree(tmp_path) / "data" / "forever"
    forever.mkdir(parents=True)
    (forever / "items.toml").write_text('[item.99999]\ncategory = "other"\n', encoding="utf-8")
    code, output = run(tmp_path, capsys, "1.60.1.70338", main=main, fetch=Canned(canned()))
    assert code == 0, output
    assert read(tmp_path, "items.csv") == ITEMS + "99999,2,7,1,Copper Shortsword\n"


def test_an_item_seen_in_data_observed_gets_its_row(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R11, DATA-R15: a non-rejected I row in data/observed/ brings its item into the universe, so 99999 gets its
    # items.csv row; a rejected row brings nothing (DATA-R50), so 13759 stays the one item DB2 lacks.
    rows = report(i_row(99999, 40), i_row(88888, 40, extra='rejected = "a client bug"\n'))
    write_observed(tree(tmp_path), reports={"bbbbbbbb": rows})
    code, output = run(tmp_path, capsys, "1.60.1.70338", main=main, fetch=Canned(canned()))
    assert code == 0, output
    assert read(tmp_path, "items.csv") == ITEMS + "99999,2,7,1,Copper Shortsword\n"
    assert "1 item(s) of the universe not in DB2 (DATA-R24): 13759" in output


def test_rewrites_the_slice_keeping_the_products_the_dev_listed(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R11: the slice describes exactly one build, so a run replaces areas.csv and items.csv; DATA-R128: the dev
    # updates the products list by hand, so a run keeps it.
    db2 = tree(tmp_path) / "data" / "db2"
    db2.mkdir(parents=True)
    (db2 / "areas.csv").write_text("ID,ParentAreaID,ContinentID,AreaName_lang\n7,0,0,Gone\n", encoding="utf-8")
    (db2 / "items.csv").write_text("ID,ClassID,SubclassID,OverallQualityID,Display_lang\n7,0,0,0,Gone\n", encoding="utf-8")
    (db2 / "build.toml").write_text(
        'build = 1\nversion = "1.0.0"\nproducts = ["wow_classic_beta", "wow_classic"]\n', encoding="utf-8"
    )
    code, output = run(tmp_path, capsys, "1.60.1.70338", main=main, fetch=Canned(canned()))
    assert code == 0, output
    assert read(tmp_path, "areas.csv") == AREAS
    assert read(tmp_path, "items.csv") == ITEMS
    assert read(tmp_path, "build.toml") == BUILD.replace('["wow_classic_beta"]', '["wow_classic_beta", "wow_classic"]')


@pytest.mark.parametrize("build", ["70338", "1.60.1", "1.60.1.70338x", "latest"])
def test_a_build_that_is_not_a_full_build_string_fails_before_downloading(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], build: str
) -> None:
    # DATA-R11: build.toml needs both the build number and the version string, so the argument carries both.
    fetch = Canned({})
    code, output = run(tree(tmp_path), capsys, build, main=main, fetch=fetch)
    assert code == 1
    assert "expected a build such as 1.60.1.70338" in output
    assert fetch.asked == []
    assert not (tmp_path / "data" / "db2").exists()


def test_an_unknown_universe_fails_before_downloading(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R11: items.csv is cut to the item universe (DATA-R15), so without a readable baseline there is nothing
    # to cut it to.
    fetch = Canned(canned())
    code, output = run(tmp_path, capsys, "1.60.1.70338", main=main, fetch=fetch)
    assert code == 1
    assert "data/baseline/source.toml: missing" in output
    assert "wrote nothing" in output
    assert fetch.asked == []


@pytest.mark.parametrize(
    ("changes", "problem"),
    [
        # DATA-R11: the four AreaTable columns must be there; an error page served instead of a CSV has none.
        ({"areas": b"<!DOCTYPE html><html>No such build</html>\n"}, "missing column 'ParentAreaID'"),
        (
            {"areas": b"ID,ZoneName,AreaName_lang,ParentAreaID\n1,DunMorogh,Dun Morogh,0\n"},
            "AreaTable 1.60.1.70338: missing column 'ContinentID'",
        ),
        (
            {"areas": b"ID,AreaName_lang,ContinentID,ParentAreaID\n1,Dun Morogh,0,0\nfoo,Bad,0,0\n"},
            "line 3: ID: expected a positive integer, got 'foo'",
        ),
        # DATA-R12: ItemSparse gives the enUS name and the quality, Item the ClassID and SubclassID.
        ({"sparse": b"<!DOCTYPE html>\n"}, "ItemSparse 1.60.1.70338: missing column 'Display_lang'"),
        ({"sparse": b"ID,Display_lang\n6303,Raw\n"}, "ItemSparse 1.60.1.70338: missing column 'OverallQualityID'"),
        (
            {"sparse": b"ID,Display_lang,OverallQualityID\n6303,Raw,common\n"},
            "ItemSparse 1.60.1.70338: line 2: OverallQualityID: expected an integer of 0 or more, got 'common'",
        ),
        ({"item": b"ID,ClassID\n6303,0\n"}, "Item 1.60.1.70338: missing column 'SubclassID'"),
        (
            {"item": b"ID,ClassID,SubclassID\n6303,0,5\n6303,0,6\n"},
            "Item 1.60.1.70338: line 3: ID 6303 is listed twice",
        ),
        ({"item": b"\xff\xfeID\n"}, f"{ITEM_URL}: not UTF-8"),
    ],
)
def test_a_bad_response_fails_listing_the_problems_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], changes: dict[str, bytes], problem: str
) -> None:
    db2 = tree(tmp_path) / "data" / "db2"
    db2.mkdir(parents=True)
    for name in ("areas.csv", "items.csv"):
        (db2 / name).write_text("kept\n", encoding="utf-8")
    code, output = run(tmp_path, capsys, "1.60.1.70338", main=main, fetch=Canned(canned(**changes)))
    assert code == 1
    assert problem in output
    assert "wrote nothing" in output
    assert read(tmp_path, "areas.csv") == "kept\n"
    assert read(tmp_path, "items.csv") == "kept\n"
    assert not (db2 / "build.toml").exists()


@pytest.mark.parametrize("url", [AREA_URL, SPARSE_URL, ITEM_URL])
def test_a_failed_download_fails_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], url: str
) -> None:
    # DATA-R12, #89: the slice describes one build, so when any table can't be downloaded nothing is rewritten.
    responses = canned()
    del responses[url]
    code, output = run(tree(tmp_path), capsys, "1.60.1.70338", main=main, fetch=Canned(responses))
    assert code == 1
    # DATA-R63: every problem is reported where it sits, here the URL.
    assert f"update-db2: {url}: can't download" in output
    assert not (tmp_path / "data" / "db2").exists()
