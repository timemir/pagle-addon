"""The event scripts' fixture tree (DATA-R99): events_fixture's tree, with Elwynn Forest (12, skill base -25, low)
given five Species and an uncommon item at known loot shares, the hunts lore check on, and no event file committed
unless asked. test_propose_events.py and test_check_event.py run the scripts over it."""

import json
from pathlib import Path

from events_fixture import SKILL_14, write_tree as write_events_tree
from pagle_data.lore import HUNTS_OWNER
from test_catch_lists import AREA_LOOT, AREAS_TOML, ITEMS, write_tree as write_areas_tree

# Elwynn Forest's loot (DATA-R9's chances, which only propose-events.py reads): five rows at a set chance, two at 0
# that split what is left (100 - 70 = 30, so 15 each), and a quest chance (negative) that never counts. Its Species
# shares: 6291 30%, 6303 20%, 6361 15%, 6289 10%, 6317 5%, so species.any 80%; 6351 is the uncommon item, 5%.
# Crystal Lake (18), its subzone, lists 6291 only through a quest chance, so it has no loot share, and Elwynn
# Forest's own table is the zone's only one.
ELWYNN_LOOT = (
    "12,6289,10,,,\n"
    "12,6291,30,,,\n"
    "12,6303,20,,,\n"
    "12,6308,0,,,\n"
    "12,6317,5,,,\n"
    "12,6351,5,,,\n"
    "12,6358,-4,,,\n"
    "12,6361,0,,,\n"
)
SHARES = {6291: 0.30, 6303: 0.20, 6361: 0.15, 6289: 0.10, 6317: 0.05}
HAUL_SHARE = 0.80
UNCOMMON_SHARE = 0.05
PROPOSE_LOOT = AREA_LOOT.replace("12,6291,1.5,,,\n", ELWYNN_LOOT).replace("18,6291,2.5,,,\n", "18,6291,-2.5,,,\n")
PROPOSE_ITEMS = ITEMS + "".join(
    f'\n[item.{item}]\ncategory = "{category}"\n'
    for item, category in ((6289, "fish"), (6317, "fish"), (6351, "junk"), (6361, "fish"))
)
# DB2's rows (DATA-R11): the names the drafts' IDs come from, and 6351 and 13760 uncommon (quality 2).
PROPOSE_DB2_ITEMS = (
    "ID,ClassID,SubclassID,OverallQualityID,Display_lang\n"
    "6289,7,8,1,Raw Longjaw Mud Snapper\n"
    "6291,7,8,1,Raw Brilliant Smallfish\n"
    "6303,7,8,1,Raw Slitherskin Mackerel\n"
    "6308,7,8,1,Raw Bristle Whisker Catfish\n"
    "6317,7,8,1,Raw Loch Frenzy\n"
    "6351,15,0,2,Dented Crate\n"
    "6361,7,8,1,Raw Rainbow Fin Albacore\n"
    "13759,7,8,1,Raw Nightfin Snapper\n"
    "13760,7,8,2,Raw Sunscale Salmon\n"
)
LORE_ON = f'typicalLength = false\nlore = ["{HUNTS_OWNER}"]\n'


def write_tree(
    root: Path,
    events: dict[str, str] | None = None,
    *,
    areas: str = AREAS_TOML + SKILL_14,
    area_loot: str = PROPOSE_LOOT,
) -> Path:
    """The fixture tree: no event committed unless events are given, the hunts lore check on (DATA-R66) with an
    empty data/lore/hunts.toml."""
    write_events_tree(root, events or {}, areas)
    write_areas_tree(root, areas, area_loot=area_loot, items=PROPOSE_ITEMS)  # the same tree, Elwynn's loot added
    (root / "data" / "db2" / "items.csv").write_text(PROPOSE_DB2_ITEMS, encoding="utf-8")
    (root / "data" / "checks.toml").write_text(LORE_ON, encoding="utf-8")
    lore = root / "data" / "lore"
    lore.mkdir(parents=True, exist_ok=True)
    (lore / "hunts.toml").write_text("", encoding="utf-8")
    return root


def data_files(root: Path) -> dict[str, bytes]:
    """Every file under root/data/ by path, to show a script changed none (DATA-R99)."""
    return {str(path.relative_to(root)): path.read_bytes() for path in sorted((root / "data").rglob("*")) if path.is_file()}


# A pushed huntEvent item as JSON (hunts.md › Contracts: Pushed Hunt Events and runs): Stranglethorn Vale (33) lists
# 13759 (gated by night) and 6303 by its subzone Jaguero Isle (297).
PUSHED: dict[str, object] = {
    "kind": "huntEvent",
    "v": 1,
    "id": "p_stv_moon_tide",
    "zones": [33],
    "tags": ["coast", "night"],
    "skill": [100, 150],
    "rotation": False,
    "name": "Moon Tide",
    "note": "Pushed for a week of high water.",
    "hunts": [
        {"id": "p_stv_moon_tide_haul", "name": "Tide Haul", "class": "species.any", "tiers": [20, 50, 100]},
        {"id": "p_stv_moon_tide_nightfin", "name": "Nightfin", "species": 13759, "tiers": [5, 15]},
        {
            "id": "p_stv_moon_tide_late",
            "name": "Late Lines",
            "class": "species.any",
            "conditions": {"time": [[1320, 240]]},
            "tiers": [5],
        },
    ],
}


def pushed(**changes: object) -> dict[str, object]:
    return {**PUSHED, **changes}


def write_json(path: Path, value: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")
    return path
