"""scripts/update-db2.py against canned wago.tools responses (DATA-R11, DATA-R12). Nothing here touches the network."""

from pathlib import Path

import pytest

from pagle_data.db2_update import main

URL = "https://wago.tools/db2/AreaTable/csv?build=1.60.1.70338"

# A cut-down AreaTable as wago.tools serves it: more columns than the slice keeps, in wago's order, rows not sorted
# by ID, a name quoted for its space and one for its comma, and a UTF-8 byte order mark.
CANNED = (
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

BUILD = """\
# Written by scripts/update-db2.py (DATA-R11, DATA-R12): the Forever build data/db2/ describes.
build = 70338
version = "1.60.1"
products = ["wow_classic_beta"]
"""


class Canned:
    """A fetch that answers from a table of URLs and records what was asked."""

    def __init__(self, responses: dict[str, bytes]) -> None:
        self.responses = responses
        self.asked: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.asked.append(url)
        if url not in self.responses:
            raise OSError(f"no canned response for {url}")
        return self.responses[url]


def run(root: Path, capsys: pytest.CaptureFixture[str], fetch: Canned, *args: str) -> tuple[int, str]:
    code = main(list(args), root, fetch)
    out, err = capsys.readouterr()
    return code, out + err


def read(root: Path, name: str) -> str:
    return (root / "data" / "db2" / name).read_text(encoding="utf-8")


def test_writes_the_four_columns_sorted_by_id_and_a_matching_build_toml(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R12: downloads AreaTable for the build from wago.tools and rewrites areas.csv; DATA-R11: build.toml holds
    # the build number, the version string and the products, seeded as ["wow_classic_beta"] (DATA-R128).
    fetch = Canned({URL: CANNED.encode("utf-8")})
    code, output = run(tmp_path, capsys, fetch, "1.60.1.70338")
    assert code == 0, output
    assert fetch.asked == [URL]
    assert read(tmp_path, "areas.csv") == AREAS
    assert read(tmp_path, "build.toml") == BUILD


def test_rewrites_the_slice_keeping_the_products_the_dev_listed(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R11: the slice describes exactly one build, so a run replaces areas.csv; DATA-R128: the dev updates the
    # products list by hand, so a run keeps it.
    db2 = tmp_path / "data" / "db2"
    db2.mkdir(parents=True)
    (db2 / "areas.csv").write_text("ID,ParentAreaID,ContinentID,AreaName_lang\n7,0,0,Gone\n", encoding="utf-8")
    (db2 / "build.toml").write_text(
        'build = 1\nversion = "1.0.0"\nproducts = ["wow_classic_beta", "wow_classic"]\n', encoding="utf-8"
    )
    code, output = run(tmp_path, capsys, Canned({URL: CANNED.encode("utf-8")}), "1.60.1.70338")
    assert code == 0, output
    assert read(tmp_path, "areas.csv") == AREAS
    assert read(tmp_path, "build.toml") == BUILD.replace('["wow_classic_beta"]', '["wow_classic_beta", "wow_classic"]')


@pytest.mark.parametrize("build", ["70338", "1.60.1", "1.60.1.70338x", "latest"])
def test_a_build_that_is_not_a_full_build_string_fails_before_downloading(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], build: str
) -> None:
    # DATA-R11: build.toml needs both the build number and the version string, so the argument carries both.
    fetch = Canned({})
    code, output = run(tmp_path, capsys, fetch, build)
    assert code == 1
    assert "expected a build such as 1.60.1.70338" in output
    assert fetch.asked == []
    assert not (tmp_path / "data" / "db2").exists()


@pytest.mark.parametrize(
    ("response", "problem"),
    [
        # DATA-R11: the four columns must be there; an error page served instead of a CSV has none of them.
        (b"<!DOCTYPE html><html>No such build</html>\n", "missing column 'ParentAreaID'"),
        (b"ID,ZoneName,AreaName_lang,ParentAreaID\n1,DunMorogh,Dun Morogh,0\n", "missing column 'ContinentID'"),
        (
            b"ID,AreaName_lang,ContinentID,ParentAreaID\n1,Dun Morogh,0,0\nfoo,Bad,0,0\n",
            "line 3: ID: expected a positive integer, got 'foo'",
        ),
    ],
)
def test_a_bad_response_fails_listing_the_problems_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], response: bytes, problem: str
) -> None:
    db2 = tmp_path / "data" / "db2"
    db2.mkdir(parents=True)
    (db2 / "areas.csv").write_text("kept\n", encoding="utf-8")
    code, output = run(tmp_path, capsys, Canned({URL: response}), "1.60.1.70338")
    assert code == 1
    assert problem in output
    assert "wrote nothing" in output
    assert read(tmp_path, "areas.csv") == "kept\n"
    assert not (db2 / "build.toml").exists()


def test_a_failed_download_fails_and_writes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code, output = run(tmp_path, capsys, Canned({}), "1.60.1.70338")
    assert code == 1
    assert f"can't download {URL}" in output
    assert not (tmp_path / "data" / "db2").exists()
