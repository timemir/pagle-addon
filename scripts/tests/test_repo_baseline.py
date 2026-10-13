"""The repo's own data/baseline/: the VMaNGOS snapshot #57 decided on, extracted once (DATA-R9)."""

import tomllib
from pathlib import Path

from pagle_data.baseline import SOURCE, read_baseline
from pagle_data.generate import generate
from pagle_data.toml_reader import Problems

REPO = Path(__file__).resolve().parents[2]


def test_source_toml_names_the_decided_dump() -> None:
    # DATA-R9 and the #57 decision: db_latest of 2026-09-28 at 4641790, the SQLite asset and its SHA-256.
    with (REPO / SOURCE).open("rb") as handle:
        source = tomllib.load(handle)
    assert source["tag"] == "db_latest@4641790"
    assert str(source["date"]) == "2026-09-28"
    assert source["url"] == "https://github.com/vmangos/core/releases/download/db_latest/db-sqlite-4641790.zip"
    assert source["dumpSha256"] == "bb2f1dd69171043a52657574f54948fd30941530fdc6eec12bce62c655428501"


def test_the_committed_baseline_matches_its_hashes_and_the_research_counts() -> None:
    # DATA-R9: every CSV's hash matches source.toml. docs/research/forever-content-data.md: 360 area entries,
    # 56 skill zones, 13 Classic pool types; the 7 events DATA-R9 lists.
    problems = Problems()
    layer = read_baseline(REPO, problems)
    assert problems.found == []
    assert len({row.area for row in layer.area_loot}) == 360
    assert len(layer.skill) == 56
    assert len({pool.name for pool in layer.pools}) == 13
    assert [event.event for event in layer.events] == [14, 15, 40, 45, 46, 47, 48]


def test_no_baseline_chance_reaches_a_generated_file() -> None:
    # DATA-R4: the baseline's chances stay in data/baseline/. A chance with a decimal point (the dump's own
    # spelling, e.g. 38.747) appears in no generated file, as generated or as committed.
    chances: set[str] = set()
    for name, column in (("area_loot.csv", 2), ("reference_loot.csv", 2), ("pool_loot.csv", 2)):
        lines = (REPO / "data" / "baseline" / name).read_text(encoding="utf-8").splitlines()[1:]
        chances |= {line.split(",")[column] for line in lines}
    decimals = {chance for chance in chances if "." in chance}
    assert len(decimals) > 100
    for path, text in generate(REPO).items():
        for content in (text, (REPO / path).read_text(encoding="utf-8")):
            leaked = sorted(chance for chance in decimals if chance in content)
            assert leaked == [], f"{path} holds baseline chances {leaked}"
