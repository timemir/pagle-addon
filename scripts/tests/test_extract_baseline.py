"""scripts/extract-baseline.py over a tiny VMaNGOS database (DATA-R9)."""

import hashlib
import tomllib
import zipfile
from datetime import date
from pathlib import Path

import pytest

from pagle_data.baseline import COLUMNS
from pagle_data.extract_baseline import ExtractError, Snapshot, extract, main
from vmangos_fixture import Row, build

# The baseline events (DATA-R9's events.csv: game_event rows 14, 15, 40, 45, 46, 47, 48), as the dump has them.
EVENTS: list[Row] = [
    {"entry": 15, "start_time": "2017-01-08 14:00:00", "end_time": "2037-01-01 00:00:00", "occurence": 10080,
     "length": 120, "description": "Stranglethorn Fishing Extravaganza: Tournament", "patch_min": 5},
    {"entry": 45, "start_time": "2020-03-20 10:00:00", "end_time": "2037-01-01 05:00:00", "occurence": 525600,
     "length": 262800, "description": "Fishing: summer period (for Raw Summer Bass)"},
    {"entry": 47, "start_time": "2017-01-01 06:00:00", "end_time": "2037-12-31 01:00:00", "occurence": 1440,
     "length": 1080, "description": "Fishing: Sunscale Cycle"},
]


def csvs(tmp_path: Path, **tables: list[Row]) -> dict[str, str]:
    return extract(build(tmp_path / "mangos.sqlite", {"game_event": EVENTS, **tables}))


def test_area_loot_keeps_only_rows_valid_for_the_baseline_patch(tmp_path: Path) -> None:
    # DATA-R9: "only rows valid for the baseline patch (Tunables)", 1.12, VMaNGOS's highest patch index (10).
    out = csvs(
        tmp_path,
        fishing_loot_template=[
            {"entry": 1, "item": 100, "ChanceOrQuestChance": 55.5},
            {"entry": 1, "item": 101, "ChanceOrQuestChance": 2, "patch_min": 7},
            {"entry": 1, "item": 102, "ChanceOrQuestChance": 3, "patch_max": 8},
        ],
    )
    assert out["area_loot.csv"] == (
        "area,item,chance,ref,event,condition\n"
        "1,100,55.5,,,\n"
        "1,101,2,,,\n"
    )


def test_a_condition_that_is_exactly_one_listed_event_becomes_event_and_any_other_keeps_its_text(
    tmp_path: Path,
) -> None:
    # DATA-R9: "A loot row's condition is extracted as event = E when it is exactly 'game event E is active' for one
    # of the events in events.csv. Any other condition, compound or negated, leaves event empty and puts the
    # condition's text in condition." VMaNGOS condition types: 12 game event active (value1 the event), -1 and,
    # -2 or, -3 not (value1–value4 condition IDs); flag 1 reverses the result.
    out = csvs(
        tmp_path,
        game_event=[
            *EVENTS,
            {"entry": 46, "start_time": "2020-09-23 09:00:00", "end_time": "2037-01-01 05:00:00",
             "occurence": 525600, "length": 262800, "description": "winter, but not in patch 1.12", "patch_max": 9},
            {"entry": 99, "start_time": "2017-01-01 00:00:00", "end_time": "2037-01-01 00:00:00",
             "occurence": 1440, "length": 60, "description": "not a baseline event"},
        ],
        conditions=[
            {"condition_entry": 1, "type": 12, "value1": 45},
            {"condition_entry": 2, "type": 12, "value1": 47, "flags": 1},
            {"condition_entry": 3, "type": -1, "value1": 1, "value2": 2},
            {"condition_entry": 4, "type": 12, "value1": 99},
            {"condition_entry": 5, "type": 12, "value1": 46},
            {"condition_entry": 6, "type": -2, "value1": 7, "value2": 1},
            {"condition_entry": 7, "type": -3, "value1": 8},
            {"condition_entry": 8, "type": 9, "value1": 7, "value2": 2},
        ],
        fishing_loot_template=[
            {"entry": 1, "item": 100, "condition_id": 1},
            {"entry": 1, "item": 101, "condition_id": 2},
            {"entry": 1, "item": 102, "condition_id": 3},
            {"entry": 1, "item": 103, "condition_id": 4},
            {"entry": 1, "item": 104, "condition_id": 5},
            {"entry": 1, "item": 105, "condition_id": 6},
        ],
    )
    assert out["area_loot.csv"] == (
        "area,item,chance,ref,event,condition\n"
        "1,100,100,,45,\n"
        "1,101,100,,,not(event(47))\n"
        '1,102,100,,,"and(event(45), not(event(47)))"\n'
        "1,103,100,,,event(99)\n"
        "1,104,100,,,event(46)\n"
        '1,105,100,,,"or(not(type9(7, 2, 0, 0)), event(45))"\n'
    )
    # DATA-R9: events.csv holds game_event rows 14, 15, 40, 45, 46, 47, 48 valid for the baseline patch, start as
    # YYYY-MM-DD HH:MM, occurrence and length in minutes (as VMaNGOS stores them).
    assert out["events.csv"] == (
        "event,start,occurrence,length,description\n"
        "15,2017-01-08 14:00,10080,120,Stranglethorn Fishing Extravaganza: Tournament\n"
        "45,2020-03-20 10:00,525600,262800,Fishing: summer period (for Raw Summer Bass)\n"
        "47,2017-01-01 06:00,1440,1080,Fishing: Sunscale Cycle\n"
    )


def test_references_are_flattened_and_only_referenced_tables_are_extracted(tmp_path: Path) -> None:
    # DATA-R9: a reference row (VMaNGOS: mincountOrRef = -table) has ref and no item; reference_loot.csv holds
    # every table area_loot.csv references, flattened through nested references, and no other table. A flattened
    # row keeps the chance it has in its own table.
    out = csvs(
        tmp_path,
        fishing_loot_template=[
            {"entry": 2, "item": 500, "ChanceOrQuestChance": 10, "mincountOrRef": -500},
            {"entry": 2, "item": 106, "ChanceOrQuestChance": -100},
        ],
        reference_loot_template=[
            {"entry": 500, "item": 200, "ChanceOrQuestChance": 30},
            {"entry": 500, "item": 501, "mincountOrRef": -501},
            {"entry": 500, "item": 203, "patch_max": 8},
            {"entry": 501, "item": 201, "ChanceOrQuestChance": 0},
            {"entry": 501, "item": 502, "mincountOrRef": -502},
            {"entry": 502, "item": 202, "ChanceOrQuestChance": 0.02},
            {"entry": 600, "item": 300},
        ],
    )
    # Rows keep the dump's key order (entry, then its item column, which holds the table for a reference row).
    assert out["area_loot.csv"] == (
        "area,item,chance,ref,event,condition\n"
        "2,106,-100,,,\n"
        "2,,10,500,,\n"
    )
    assert out["reference_loot.csv"] == (
        "ref,item,chance\n"
        "500,200,30\n"
        "500,201,0\n"
        "500,202,0.02\n"
    )


POOLS: dict[str, list[Row]] = {
    # VMaNGOS keeps one gameobject_template row per patch that changed it; the baseline takes the latest at or
    # below the baseline patch. A fishing pool is type 25; data1 is its loot table.
    "gameobject_template": [
        {"entry": 1000, "type": 25, "name": "School of Fish", "data1": 2000},
        {"entry": 1001, "type": 25, "name": "Old Name", "data1": 2009},
        {"entry": 1001, "patch": 7, "type": 25, "name": "School of Tastyfish", "data1": 2001},
        {"entry": 1002, "type": 3, "name": "Chest", "data1": 2002},
        {"entry": 1003, "type": 25, "name": "Shares, a loot table", "data1": 2000},
    ],
    "gameobject": [
        {"guid": 1, "id": 1000},
        {"guid": 2, "id": 1001},
        {"guid": 3, "id": 1001},
        {"guid": 4, "id": 1001, "patch_max": 8},
    ],
    "game_event_gameobject": [{"guid": 2, "event": 15}, {"guid": 3, "event": 15}, {"guid": 4, "event": 40}],
    "gameobject_loot_template": [
        {"entry": 2000, "item": 400, "ChanceOrQuestChance": 85},
        {"entry": 2000, "item": 700, "ChanceOrQuestChance": 10, "mincountOrRef": -700, "patch_min": 7,
         "patch_max": 8},
        {"entry": 2001, "item": 401, "ChanceOrQuestChance": 0},
        {"entry": 2001, "item": 501, "ChanceOrQuestChance": 10, "mincountOrRef": -501},
        {"entry": 2002, "item": 999},
        {"entry": 2009, "item": 998},
    ],
    "reference_loot_template": [
        {"entry": 501, "item": 201},
        {"entry": 700, "item": 701},
    ],
}


def test_pools_are_the_fishing_pool_templates_with_their_loot_and_spawn_event(tmp_path: Path) -> None:
    # DATA-R9: pools.csv is gameobject_template rows of type 25, event the game_event_gameobject event their spawns
    # belong to; pool_loot.csv is gameobject_loot_template for those pools, keyed by the pool's entry; a table
    # pool_loot.csv references is in reference_loot.csv.
    out = csvs(tmp_path, **POOLS)
    assert out["pools.csv"] == (
        "entry,name,event\n"
        "1000,School of Fish,\n"
        "1001,School of Tastyfish,15\n"
        '1003,"Shares, a loot table",\n'
    )
    assert out["pool_loot.csv"] == (
        "entry,item,chance,ref\n"
        "1000,400,85,\n"
        "1001,401,0,\n"
        "1001,,10,501\n"
        "1003,400,85,\n"
    )
    assert out["reference_loot.csv"] == "ref,item,chance\n501,201,100\n"


def test_skill_is_the_fishing_base_level_of_each_area(tmp_path: Path) -> None:
    # DATA-R9: skill.csv is skill_fishing_base_level; values may be negative (DATA-R30).
    out = csvs(tmp_path, skill_fishing_base_level=[{"entry": 33, "skill": 130}, {"entry": 1, "skill": -70}])
    assert out["skill.csv"] == "area,skillBase\n1,-70\n33,130\n"


@pytest.mark.parametrize(
    ("tables", "problem"),
    [
        # pools.csv has one event per pool.
        ({**POOLS, "game_event_gameobject": [{"guid": 2, "event": 15}]}, "spawns belong to different events"),
        ({**POOLS, "game_event_gameobject": [{"guid": 2, "event": -15}, {"guid": 3, "event": -15}]},
         "despawn during event 15"),
        # pool_loot.csv and reference_loot.csv have no condition column.
        ({**POOLS, "gameobject_loot_template": [{"entry": 2000, "item": 400, "condition_id": 1}],
          "conditions": [{"condition_entry": 1, "type": 12, "value1": 15}]}, "gameobject_loot_template 2000"),
        ({"fishing_loot_template": [{"entry": 1, "item": 7, "mincountOrRef": -7}],
          "reference_loot_template": [{"entry": 7, "item": 8, "condition_id": 1}],
          "conditions": [{"condition_entry": 1, "type": 12, "value1": 15}]}, "reference_loot_template 7"),
        # A reference loop or a missing condition is a broken dump.
        ({"fishing_loot_template": [{"entry": 1, "item": 7, "mincountOrRef": -7}],
          "reference_loot_template": [{"entry": 7, "item": 7, "mincountOrRef": -7}]}, "refers to itself"),
        ({"fishing_loot_template": [{"entry": 1, "item": 7, "condition_id": 3}]}, "condition 3 is not in"),
    ],
)
def test_what_the_csvs_cant_say_faithfully_stops_the_extraction(
    tmp_path: Path, tables: dict[str, list[Row]], problem: str
) -> None:
    # DATA-R9: the baseline is exactly the dump's data; the extractor never guesses.
    with pytest.raises(ExtractError, match=problem):
        csvs(tmp_path, **tables)


def dump(tmp_path: Path) -> tuple[Path, Snapshot]:
    """A zipped fixture database laid out as VMaNGOS's SQLite asset is, and a snapshot naming it."""
    database = build(tmp_path / "mangos.sqlite", {"game_event": EVENTS, **POOLS})
    archive = tmp_path / "db-sqlite-1234567.zip"
    with zipfile.ZipFile(archive, "w") as handle:
        handle.write(database, "sqlite-dump/mangos.sqlite")
    sha256 = hashlib.sha256(archive.read_bytes()).hexdigest()
    return archive, Snapshot("db_latest@1234567", date(2026, 9, 28), "https://example.invalid/db.zip", sha256)


def run(argv: list[str], root: Path, snapshot: Snapshot, capsys: pytest.CaptureFixture[str]) -> tuple[int, str]:
    code = main(argv, root, snapshot)
    out, err = capsys.readouterr()
    return code, out + err


def test_the_command_writes_the_csvs_and_source_toml_from_the_dump(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R9: scripts/extract-baseline.py <dump> writes data/baseline/: the six CSVs and source.toml with the
    # snapshot's tag and date, the dump's URL and SHA-256 (the #57 spec edit), and each CSV's SHA-256.
    archive, snapshot = dump(tmp_path)
    root = tmp_path / "repo"
    code, _ = run([str(archive)], root, snapshot, capsys)
    assert code == 0
    baseline = root / "data" / "baseline"
    assert (baseline / "pools.csv").read_text(encoding="utf-8").startswith("entry,name,event\n1000,School of Fish,\n")
    with (baseline / "source.toml").open("rb") as handle:
        source = tomllib.load(handle)
    assert source["tag"] == "db_latest@1234567"
    assert source["date"] == date(2026, 9, 28)
    assert source["url"] == "https://example.invalid/db.zip"
    assert source["dumpSha256"] == snapshot.sha256
    csv_files = sorted(path.name for path in baseline.glob("*.csv"))
    assert csv_files == sorted(COLUMNS)
    assert source["sha256"] == {
        name: hashlib.sha256((baseline / name).read_bytes()).hexdigest() for name in csv_files
    }


def test_a_dump_whose_hash_differs_from_the_snapshot_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # The #57 decision: verify the archived dump's SHA-256 before extracting anything.
    archive, snapshot = dump(tmp_path)
    root = tmp_path / "repo"
    code, output = run([str(archive)], root, Snapshot(snapshot.tag, snapshot.date, snapshot.url, "0" * 64), capsys)
    assert code == 1
    assert f"{archive}: SHA-256 is {snapshot.sha256}, not {'0' * 64}" in output
    assert not (root / "data").exists()


def test_the_baseline_is_extracted_once(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R9: extracted once, frozen; a second run changes nothing.
    archive, snapshot = dump(tmp_path)
    root = tmp_path / "repo"
    run([str(archive)], root, snapshot, capsys)
    (root / "data" / "baseline" / "skill.csv").write_text("kept\n", encoding="utf-8")
    code, output = run([str(archive)], root, snapshot, capsys)
    assert code == 1
    assert "data/baseline/ exists" in output
    assert (root / "data" / "baseline" / "skill.csv").read_text(encoding="utf-8") == "kept\n"
