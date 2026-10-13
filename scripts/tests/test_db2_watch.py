"""scripts/db2-watch.py against recorded wago.tools responses (DATA-R128 to DATA-R130). Nothing here touches the
network: every download goes through a canned fetch."""

import json
from pathlib import Path

import pytest

from baseline_fixture import write_baseline
from observed_fixture import write_observed
from pagle_data.db2_watch import has_keyword, main

BUILDS_URL = "https://wago.tools/api/builds"

# data/db2/ as update-db2.py would leave it for 1.60.1.70338. The fixture baseline's item universe (DATA-R15) is 6303,
# 6358, 13759 and 19807 (test_universe.py); 13759 isn't in items.csv (the client streams item records, #89).
BUILD_TOML = """\
build = 70338
version = "1.60.1"
products = ["wow_classic_beta"]
"""

AREAS_CSV = """\
ID,ParentAreaID,ContinentID,AreaName_lang
12,0,0,Elwynn Forest
148,0,1,Darkshore
16591,0,2940,Riverglades
"""

ITEMS_CSV = """\
ID,ClassID,SubclassID,OverallQualityID,Display_lang
6303,0,5,1,Raw Slitherskin Mackerel
6358,7,8,1,Oily Blackmouth
19807,15,0,2,Speckled Tastyfish
"""


def builds_json(*versions: str, product: str = "wow_classic_beta") -> bytes:
    """The builds API's answer as wago.tools gives it: products as keys, each a list of builds, newest first by
    date, with the other products alongside."""
    entry = {
        "created_at": "2026-10-10 05:05:05",
        "build_config": "0" * 32,
        "product_config": "0" * 32,
        "cdn_config": "0" * 32,
        "is_bgdl": False,
    }
    answer = {
        "wow": [{"product": "wow", "version": "12.1.5.70340", **entry}],
        product: [{"product": product, "version": version, **entry} for version in versions],
        "wow_classic_era": [{"product": "wow_classic_era", "version": "1.15.8.70500", **entry}],
    }
    return json.dumps(answer).encode("utf-8")


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


def tree(root: Path) -> Path:
    write_baseline(root)
    write_observed(root)  # dev.toml with no facts; test_observed.py covers the layer
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text(BUILD_TOML, encoding="utf-8")
    (db2 / "areas.csv").write_text(AREAS_CSV, encoding="utf-8")
    (db2 / "items.csv").write_text(ITEMS_CSV, encoding="utf-8")
    return root


def snapshot(root: Path) -> dict[str, bytes]:
    data = root / "data"
    return {str(path.relative_to(data)): path.read_bytes() for path in sorted(data.rglob("*")) if path.is_file()}


def run(
    root: Path, out: Path, capsys: pytest.CaptureFixture[str], fetch: Canned, *args: str
) -> tuple[int, str]:
    code = main(["--out", str(out), *args], root, fetch)
    printed, err = capsys.readouterr()
    return code, printed + err


def test_a_newer_build_on_another_version_line_opens_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R128 and #97: wow_classic_beta also lists MoP Classic 5.5.0 builds, so only builds on Forever's line (the
    # major and minor of build.toml's version, 1.60) count. The newest 1.60 build is the recorded one.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    fetch = Canned({BUILDS_URL: builds_json("5.5.0.70400", "1.60.1.70338", "1.60.1.70334", "5.5.0.62071")})
    before = snapshot(root)
    code, output = run(root, out, capsys, fetch)
    assert code == 0, output
    assert fetch.asked == [BUILDS_URL]
    assert not out.exists() or not any(out.iterdir())
    assert "no build on the 1.60 line newer than 1.60.1.70338 in wow_classic_beta" in output
    assert snapshot(root) == before  # DATA-R130
    # The run's log names what it passed over, so a Forever move to a new line (1.61) shows up there.
    assert "passed over newer builds on other lines: 5.5.0.70400" in output


NEW = "1.60.1.70400"
OLD = "1.60.1.70338"


def table(name: str, build: str) -> str:
    return f"https://wago.tools/db2/{name}/csv?build={build}"


# The recorded build's tables the watch downloads for what data/db2/ doesn't keep (DATA-R129): ItemSparse, for which
# items are new to DB2, and SpellName and HolidayNames. 50000 already matches a keyword, so it isn't new.
OLD_SPARSE = (
    "﻿ID,Description_lang,Display_lang,OverallQualityID,ItemLevel\n"
    "6303,,Raw Slitherskin Mackerel,1,5\n"
    "6358,,Oily Blackmouth,1,15\n"
    "19807,,Speckled Tastyfish,2,40\n"
    "50000,,Stale Fishing Hat,1,10\n"
)
OLD_SPELLS = '﻿ID,Name_lang\n7620,Fishing\n133,"Fireball"\n'
OLD_HOLIDAYS = '﻿ID,Name_lang\n1,"Darkmoon Faire"\n'

# The new build's tables, as wago.tools serves them (more columns than the watch reads, a byte order mark, rows in
# no order). Against the recorded slice: 13759 joins the slice (it was missing from ItemSparse); 6358 is renamed;
# 6303's class and 19807's quality change; 70001 is new and has a keyword; 70002 is new, and "Whirlpool" isn't the
# keyword "Pool". Darkshore is renamed, Riverglades moves under a new parent and 16700 is new.
NEW_SPARSE = (
    "﻿ID,Description_lang,Display_lang,OverallQualityID,ItemLevel\n"
    "70002,,Whirlpool Shard,2,30\n"
    "6303,,Raw Slitherskin Mackerel,1,5\n"
    "6358,,Oily Blackmouth Fillet,1,15\n"
    "13759,,Raw Nightfin Snapper,1,35\n"
    "19807,,Speckled Tastyfish,3,40\n"
    "50000,,Stale Fishing Hat,1,10\n"
    "70001,,Glimmering Lure,1,20\n"
)
NEW_ITEM = (
    "﻿ID,ClassID,SubclassID,Material,InventoryType\n"
    "6303,15,0,0,0\n"
    "6358,7,8,0,0\n"
    "13759,0,5,0,0\n"
    "19807,15,0,0,0\n"
    "50000,4,1,7,1\n"
    "70001,0,8,0,0\n"
    "70002,15,0,0,0\n"
)
NEW_AREAS = (
    "﻿ID,ZoneName,AreaName_lang,ContinentID,ParentAreaID,AreaBit\n"
    "16700,AnglersWharf,\"Angler's Wharf\",2940,16591,9100\n"
    "12,ElwynnForest,Elwynn Forest,0,0,126\n"
    "148,Darkshore,Darkshore Coast,1,0,128\n"
    "16591,Riverglades,Riverglades,2940,16590,9002\n"
)
NEW_SPELLS = "﻿ID,Name_lang\n7620,Fishing\n133,Fireball\n1300001,Fishing\n1300002,Whirlpool\n1300003,Frostbolt\n"
NEW_HOLIDAYS = '﻿ID,Name_lang\n1,"Darkmoon Faire"\n400,"Forever Fishing Extravaganza"\n'


def newer(**changes: bytes) -> dict[str, bytes]:
    """The answers for a run that finds 1.60.1.70400; changes replaces some, keyed by URL."""
    responses = {
        BUILDS_URL: builds_json("5.5.0.70500", NEW, OLD, "1.60.1.70334"),
        table("ItemSparse", OLD): OLD_SPARSE.encode("utf-8"),
        table("SpellName", OLD): OLD_SPELLS.encode("utf-8"),
        table("HolidayNames", OLD): OLD_HOLIDAYS.encode("utf-8"),
        table("AreaTable", NEW): NEW_AREAS.encode("utf-8"),
        table("ItemSparse", NEW): NEW_SPARSE.encode("utf-8"),
        table("Item", NEW): NEW_ITEM.encode("utf-8"),
        table("SpellName", NEW): NEW_SPELLS.encode("utf-8"),
        table("HolidayNames", NEW): NEW_HOLIDAYS.encode("utf-8"),
    }
    responses.update(changes)
    return responses


# By hand from DATA-R129 and the tables above.
BODY = """\
wago.tools lists Forever build 1.60.1.70400 (wow_classic_beta), newer than the 1.60.1.70338 that `data/db2/` \
describes. This is what changed in the DB2 tables Pagle watches (DATA-R129). Watch keywords, matched as whole words \
in enUS names: Fish, Fishing, Lure, Bait, Angler, Pool, School, Extravaganza.

## Items

New in the item universe:
- 13759 Raw Nightfin Snapper

New in DB2, with a watch keyword in the name:
- 70001 Glimmering Lure

Renamed, in the universe:
- 6358 Oily Blackmouth → Oily Blackmouth Fillet

Class or quality changed, in the universe:
- 6303 Raw Slitherskin Mackerel: class 0 → 15
- 19807 Speckled Tastyfish: quality 2 → 3

## Areas

New:
- 16700 Angler's Wharf (parent 16591, continent 2940)

Renamed:
- 148 Darkshore → Darkshore Coast

Moved:
- 16591 Riverglades: parent 0 → 16590

## Spells and calendar events

New spells with a watch keyword in the name:
- 1300001 Fishing

New calendar events with a watch keyword in the name:
- 400 Forever Fishing Extravaganza

## Next

Refresh the slice in a PR with `.tools/bin/python scripts/update-db2.py 1.60.1.70400` (DATA-R12), then regenerate \
with `scripts/generate-data.py`. Edits that follow from this list, such as a spell for `lists.toml` or an event for \
`events.toml` (DATA-R40), are made by hand: the watch never edits `data/` (DATA-R130).
"""


def test_a_newer_forever_build_writes_the_issue_listing_its_changes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R128: the newest build on the 1.60 line beats the recorded one (5.5.0.70500 is on another line), so the
    # watch downloads its tables and writes one issue titled "Forever build <version>: DB2 changes". DATA-R129: the
    # body lists a new keyword item, a renamed universe item, a moved area and a new "Fishing" spell, and not
    # "Whirlpool"; SpellName and HolidayNames come for both builds.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    fetch = Canned(newer())
    before = snapshot(root)
    code, output = run(root, out, capsys, fetch)
    assert code == 0, output
    assert (out / "title.txt").read_text(encoding="utf-8") == "Forever build 1.60.1.70400: DB2 changes\n"
    assert (out / "body.md").read_text(encoding="utf-8") == BODY
    assert "Whirlpool" not in BODY
    assert sorted(fetch.asked) == sorted(newer())
    assert snapshot(root) == before  # DATA-R130


def test_an_existing_issue_with_the_title_means_nothing_new_is_opened(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R128: one issue per build, unless an issue with that title exists (open or closed: gh issue list --state
    # all, as the workflow lists them). The watch stops before downloading any table.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    issues = tmp_path / "issues.json"
    listed = [
        {"number": 140, "title": "Forever build 1.60.1.70400: DB2 changes"},
        {"number": 120, "title": "Forever build 1.60.1.70338: DB2 changes"},
    ]
    issues.write_text(json.dumps(listed), encoding="utf-8")
    fetch = Canned(newer())
    code, output = run(root, out, capsys, fetch, "--issues", str(issues))
    assert code == 0, output
    assert fetch.asked == [BUILDS_URL]
    assert not out.exists() or not any(out.iterdir())
    assert 'issue #140 "Forever build 1.60.1.70400: DB2 changes" exists; nothing to open' in output


def test_an_issue_list_without_the_title_still_opens_one(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R128: only the same title stops the watch; an older build's issue doesn't.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    issues = tmp_path / "issues.json"
    issues.write_text(json.dumps([{"number": 120, "title": "Forever build 1.60.1.70338: DB2 changes"}]), "utf-8")
    code, output = run(root, out, capsys, Canned(newer()), "--issues", str(issues))
    assert code == 0, output
    assert (out / "body.md").read_text(encoding="utf-8") == BODY


def test_a_body_too_long_for_an_issue_is_cut_and_the_log_keeps_it_all(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R128: one issue per build, which GitHub caps at 65,536 characters. A diff over that (here 3,000 new areas)
    # still opens it, cut at a line with a note, keeping "## Next"; the run's log prints the whole body.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    many = "".join(f"{20000 + n},Z,Somewhere Quite Far Away Number {n},2940,0,{n}\n" for n in range(3000))
    code, output = run(root, out, capsys, Canned(newer(**{table("AreaTable", NEW): (NEW_AREAS + many).encode()})))
    assert code == 0, output
    body = (out / "body.md").read_text(encoding="utf-8")
    assert len(body) <= 65536
    assert "- 20000 Somewhere Quite Far Away Number 0 (parent 0, continent 2940)\n" in body
    assert "Number 2999" not in body
    assert "The list is cut here" in body
    assert body.endswith("the watch never edits `data/` (DATA-R130).\n")
    assert "- 22999 Somewhere Quite Far Away Number 2999 (parent 0, continent 2940)\n" in output


def test_the_watch_refuses_to_write_under_data(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R130: the watch never edits data/, so it won't even put its issue files there.
    root = tree(tmp_path / "repo")
    before = snapshot(root)
    code, output = run(root, root / "data" / "watch", capsys, Canned(newer()))
    assert code == 1
    assert "--out must be outside data/ (DATA-R130)" in output
    assert snapshot(root) == before


@pytest.mark.parametrize(
    ("name", "matches"),
    [
        ("Fishing", True),
        ("Apprentice fishing", True),  # ignoring case
        ("Stranglethorn Fishing Extravaganza", True),
        ("Angler's Wharf", True),  # an apostrophe ends the word
        ("Sagefish School", True),
        ("Whirlpool", False),  # "Pool" doesn't match "Whirlpool" (DATA-R129)
        ("Sagefish", False),
        ("Schooling Lures", False),  # "Lures" isn't "Lure"
        ("Frostbolt", False),
    ],
)
def test_a_watch_keyword_matches_a_whole_word_ignoring_case(name: str, matches: bool) -> None:
    # DATA-R129 and the watch keywords (Tunables): Fish, Fishing, Lure, Bait, Angler, Pool, School, Extravaganza.
    assert has_keyword(name) is matches


def test_a_failed_download_fails_the_run_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R128: the diff needs every table; a table wago.tools can't serve fails the run (the workflow run goes
    # red) rather than opening a partial issue.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    responses = newer()
    del responses[table("SpellName", OLD)]
    code, output = run(root, out, capsys, Canned(responses))
    assert code == 1
    assert f"can't download {table('SpellName', OLD)}" in output
    assert not out.exists() or not any(out.iterdir())


def test_a_bad_table_fails_the_run_naming_the_line(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R128: a table that can't be read is reported as update-db2.py reports it (DATA-R12), not diffed.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    broken = NEW_AREAS.replace("12,ElwynnForest", "x12,ElwynnForest").encode("utf-8")
    code, output = run(root, out, capsys, Canned(newer(**{table("AreaTable", NEW): broken})))
    assert code == 1
    assert "AreaTable 1.60.1.70400: line 3: ID: expected a positive integer, got 'x12'" in output
    assert not out.exists() or not any(out.iterdir())


def test_a_product_wago_does_not_list_fails_the_run(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R128: the watch reads the builds of build.toml's products; one the API lacks is the dev's to fix.
    root, out = tree(tmp_path / "repo"), tmp_path / "out"
    code, output = run(root, out, capsys, Canned({BUILDS_URL: builds_json(NEW, product="wow_forever")}))
    assert code == 1
    assert "lists no product 'wow_classic_beta'" in output
