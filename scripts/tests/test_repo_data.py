"""The repo's own data/: data/forever/ holds the seeded lists the spec names, and data/db2/ the committed slice."""

import re
import tomllib
from pathlib import Path

from pagle_data.db2 import Db2Layer, read_db2
from pagle_data.forever import WeeklyRule, read_forever
from pagle_data.generate import CATALOGUE_LUA, generate
from pagle_data.toml_reader import Problems

REPO = Path(__file__).resolve().parents[2]


def test_the_event_list_is_the_extravaganza_on_sundays_at_14_00_for_120_minutes() -> None:
    # DATA-R38: "The v1 list is the Extravaganza, 301, Sundays 14:00 for 120 minutes."
    problems = Problems()
    layer = read_forever(REPO, problems)
    assert problems.found == []
    assert layer.events == {301: WeeklyRule(weekday=1, start=14 * 60, duration=120)}


def test_the_aura_and_fishing_spell_lists_hold_their_seeds() -> None:
    # DATA-R39: the beta probe's four auras, and the Classic and Forever rank spells.
    problems = Problems()
    layer = read_forever(REPO, problems)
    assert problems.found == []
    assert sorted(layer.auras) == [1265220, 1280341, 1280342, 1299323]
    assert sorted(layer.fishing_spells) == [7620, 7731, 7732, 18248, 1240948, 1240959, 1240970, 1240983]


def _slice() -> Db2Layer:
    problems = Problems()
    layer = read_db2(REPO, problems)
    assert problems.found == []
    return layer


def test_the_db2_slice_is_from_wago_tools_for_a_named_forever_build() -> None:
    # DATA-R11, DATA-R12: build.toml names the one Forever build the slice describes, and the products searched,
    # seeded with wow_classic_beta (DATA-R128). #56: the beta's 1.60.1.70338.
    layer = _slice()
    assert (layer.version, layer.build) == ("1.60.1", 70338)
    assert layer.products == ["wow_classic_beta"]
    # Forever's own zones are in the slice (DATA-R31 names them): Riverglades and Shen'dralas, for example.
    assert layer.areas[16591].name == "Riverglades"
    assert layer.areas[16651].name == "Shen'dralas"


def test_the_committed_catalogue_holds_one_area_per_areas_csv_row() -> None:
    # DATA-R25: the catalogue's areas are every row of areas.csv; DATA-R61: the committed file is what data/ gives.
    layer = _slice()
    outputs = generate(REPO)
    committed = (REPO / CATALOGUE_LUA).read_text(encoding="utf-8")
    assert committed == outputs[CATALOGUE_LUA]
    # Each area record opens at the areas table's depth, on one line or with its catches below (DATA-R78).
    start = committed.index("\n\tareas = {\n")
    block = committed[start : committed.index("\n\t},\n", start)]
    rows = re.findall(r"^\t\t\[(\d+)\] = \{", block, flags=re.MULTILINE)
    assert [int(area_id) for area_id in rows] == sorted(layer.areas)


def test_no_name_from_areas_csv_appears_in_any_generated_file() -> None:
    # DATA-R3: no area name from the game ships; the source layer keeps the enUS names, the generator never emits
    # them. Every generated file, as generated and as committed.
    names = {area.name for area in _slice().areas.values() if area.name}
    assert len(names) > 1000
    for path, text in generate(REPO).items():
        for content in (text, (REPO / path).read_text(encoding="utf-8")):
            leaked = sorted(name for name in names if name in content)
            assert leaked == [], f"{path} holds area names {leaked}"


def test_the_committed_catalogue_s_aliases_are_aliases_toml_s() -> None:
    # DATA-R76: Catalogue.lua's aliases (areaID → baseline areaID) are the alias table; DATA-R32's example,
    # 16521 → 18, is in it. Read straight from the two committed files.
    with (REPO / "data" / "forever" / "aliases.toml").open("rb") as handle:
        table = {entry["from"]: entry["to"] for entry in tomllib.load(handle)["alias"]}
    committed = (REPO / CATALOGUE_LUA).read_text(encoding="utf-8")
    line = re.search(r"^\taliases = \{(.*)\},$", committed, flags=re.MULTILINE)
    assert line is not None
    emitted = {int(source): int(target) for source, target in re.findall(r"\[(\d+)\] = (\d+)", line.group(1))}
    assert emitted == table
    assert emitted[16521] == 18
