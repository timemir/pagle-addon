"""The repo's own Hunt list (DATA-R85-R94): data/hunts/hunts.toml and the HuntList.lua it generates."""

from pathlib import Path

from pagle_data.generate import generate, hunt_list_of, read_layers
from pagle_data.hunts import HUNT_LIST_LUA

REPO = Path(__file__).resolve().parents[2]


def test_the_committed_hunt_list_lua_is_what_hunts_toml_gives() -> None:
    # DATA-R61, DATA-R75: addons/Pagle_Hunts/data/HuntList.lua is generated from the committed data/hunts/hunts.toml
    # and committed with it, so --check stays green.
    committed = (REPO / HUNT_LIST_LUA).read_text(encoding="utf-8")
    assert committed == generate(REPO)[HUNT_LIST_LUA]
    assert "ns.huntList = {" in committed


def test_the_committed_list_emits_the_three_generated_classes_over_the_catalogue() -> None:
    # DATA-R91: quality.uncommon, quality.rare and species.any are always emitted, each holding only items that ship.
    # species.any holds hunts.md's v1 Species targets (by their enUS names in items.csv: Raw Nightfin Snapper, Raw
    # Sunscale Salmon, Brownell's Blue Striped Racer, Raw Mithril Head Trout), Whimsyfin, and 6887 Spotted Yellowtail,
    # an item folded into Species 4603 (DATA-R19), which is still a Species item.
    layers = read_layers(REPO)
    classes = hunt_list_of(layers)["classes"]
    assert {"quality.uncommon", "quality.rare", "species.any"} <= classes.keys()
    assert {13759, 13760, 19803, 8365, 251524, 6887, 4603} <= classes["species.any"].keys()
    for members in classes.values():
        assert set(members) <= layers.items.keys()
