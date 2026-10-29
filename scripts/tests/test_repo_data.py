"""The repo's own data/: data/forever/ holds the seeded lists the spec names, and data/db2/ the committed slice."""

import re
from collections.abc import Mapping
import tomllib
from pathlib import Path

from pagle_data.db2 import Db2Layer, read_db2
from pagle_data.errors import Problems
from pagle_data.forever import WeeklyRule, read_forever
from pagle_data.generate import CATALOGUE_LUA

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
    # seeded with wow_classic_beta (DATA-R128). #56 took the beta's 1.60.1.70338; #312 refreshed it to 1.60.1.70450, #439 to 1.60.1.70532, then to 1.60.1.70685 with the live product wowf watched too.
    layer = _slice()
    assert (layer.version, layer.build) == ("1.60.1", 70685)
    assert layer.products == ["wow_classic_beta", "wowf"]
    # Forever's own zones are in the slice (DATA-R31 names them): Riverglades and Shen'dralas, for example.
    assert layer.areas[16591].name == "Riverglades"
    assert layer.areas[16651].name == "Shen'dralas"


def test_the_committed_catalogue_holds_one_area_per_areas_csv_row() -> None:
    # DATA-R25: the catalogue's areas are every row of areas.csv; DATA-R61: the committed file is what data/ gives.
    layer = _slice()
    committed = (REPO / CATALOGUE_LUA).read_text(encoding="utf-8")
    # Each area record opens at the areas table's depth, on one line or with its catches below (DATA-R78).
    start = committed.index("\n\tareas = {\n")
    block = committed[start : committed.index("\n\t},\n", start)]
    rows = re.findall(r"^\t\t\[(\d+)\] = \{", block, flags=re.MULTILINE)
    assert [int(area_id) for area_id in rows] == sorted(layer.areas)


# DATA-R3: "Everything Pagle ships is IDs, numbers and Pagle's own text." Pagle's own lore that happens to spell an
# area's name, by the generated file it is in, with the lore that does: plain English words some subzone also uses,
# not a name taken from the game.
OWN_TEXT = {
    "addons/Pagle_Hunts/data/Lore.lua": {
        "Camp": "the set Camp Hours (set.camp_hours.name, DATA-R105), for the Rack and the Hut",
        "Night Run": "the Hunt Night Run (hunt.night_run.name, DATA-R105), a night window's run",
    },
}


# DATA-R3: Pagle's own lore that is an area's name, excused for one lore key alone, by the generated file it is in:
# that key's line is left out of the match, so the same name anywhere else in the file still fails. Each is the
# dev's pick, reviewed, and names none of the game's places.
OWN_LORE = {
    "addons/Pagle_Ledger/data/Lore.lua": {
        # Rank III's Prestige frame (LED-R154) is a lighthouse on a point, and the dev kept "The Lighthouse" for it
        # over the kit's "The Lamp Room": a plain English word for the frame's own building, which some of the
        # game's subzones also happen to be called.
        "prestigeframe.lighthouse.name": "Lighthouse",
    },
}


def _without_own_lore(path: str, content: str) -> str:
    """`content` without the lines of OWN_LORE's keys for `path` (a generated Lore.lua's `L["<key>"] = "…"` lines)."""
    keys = OWN_LORE.get(path, {})
    return "\n".join(line for line in content.split("\n") if not any(line.startswith(f'L["{k}"] = ') for k in keys))


def test_no_name_from_areas_csv_appears_in_any_generated_file(repo_outputs: Mapping[str, str]) -> None:
    # DATA-R3: no area name from the game ships; the source layer keeps the enUS names, the generator never emits
    # them. Every generated file, as generated and as committed, apart from OWN_TEXT's reviewed coincidences and
    # OWN_LORE's keys.
    names = {area.name for area in _slice().areas.values() if area.name}
    assert len(names) > 1000
    for path, text in repo_outputs.items():
        allowed = OWN_TEXT.get(path, {})
        for content in (text, (REPO / path).read_text(encoding="utf-8")):
            content = _without_own_lore(path, content)
            leaked = sorted(name for name in names if name in content and name not in allowed)
            assert leaked == [], f"{path} holds area names {leaked}"


def test_own_lore_excuses_only_its_key_and_still_names_an_area() -> None:
    # DATA-R3: an OWN_LORE key's line is in its file and holds the area name it is excused for, so a stale entry can't
    # hide a later leak; and the name in any other line of the file is still caught.
    names = {area.name for area in _slice().areas.values() if area.name}
    for path, keys in OWN_LORE.items():
        content = (REPO / path).read_text(encoding="utf-8")
        for key, name in keys.items():
            assert name in names, name
            line = next(line for line in content.split("\n") if line.startswith(f'L["{key}"] = '))
            assert name in line, key
            leak = content + f'\nL["prestigeframe.other.name"] = "{name}"\n'
            assert name in _without_own_lore(path, leak)
            assert name not in _without_own_lore(path, content)


def test_every_area_name_allowed_as_own_text_is_still_an_area_s_name_and_in_its_file() -> None:
    # DATA-R3: OWN_TEXT only excuses a coincidence that is really there, so a stale entry can't hide a later leak.
    names = {area.name for area in _slice().areas.values() if area.name}
    for path, allowed in OWN_TEXT.items():
        content = (REPO / path).read_text(encoding="utf-8")
        for name in allowed:
            assert name in names, name
            assert name in content, name


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


def test_every_committed_generated_file_matches_the_repository_data(repo_outputs: Mapping[str, str]) -> None:
    for path, expected in repo_outputs.items():
        assert (REPO / path).read_text(encoding="utf-8") == expected, path
