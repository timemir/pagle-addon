"""The repo's own fish varieties (VAR-R2, VAR-R4, VAR-R11, VAR-R12, DATA-R131-R135): data/forever/varieties.toml, its
lock, the varieties' and fish crests' lore in data/lore/core.toml, and the art table addons/Pagle/data/VarietyArt.lua,
as the committed Catalogue.lua ships them."""

import re
import tomllib
from functools import cache
from pathlib import Path

from pagle_data.generate import Layers, read_layers
from pagle_data.varieties import VARIETY_COUNT, variety_species

REPO = Path(__file__).resolve().parents[2]
VARIETY_ART = REPO / "addons" / "Pagle" / "data" / "VarietyArt.lua"


@cache
def _layers() -> Layers:
    return read_layers(REPO)


def _varieties() -> dict[int, list[str]]:
    with (REPO / "data" / "forever" / "varieties.toml").open("rb") as handle:
        return {int(species): table["keys"] for species, table in tomllib.load(handle)["varieties"].items()}


def test_the_37_sized_non_legend_species_each_have_ten_varieties() -> None:
    # VAR-R2, varieties.md › Data: 37 Species at release, exactly the sized, non-Legend Species of the catalogue
    # (Gaffer Jack and Electropeller are junk, so not among them), each with ten keys none repeated.
    varieties = _varieties()
    assert len(varieties) == 37
    assert set(varieties) == variety_species(_layers().items)
    assert not {6717, 6718} & set(varieties)
    for species, keys in varieties.items():
        assert len(keys) == VARIETY_COUNT and len(set(keys)) == VARIETY_COUNT, species


def test_the_varieties_switch_is_on() -> None:
    # DATA-R66, DATA-R132: on from the varieties release.
    with (REPO / "data" / "checks.toml").open("rb") as handle:
        assert tomllib.load(handle)["varieties"] is True


def test_every_item_of_a_species_ships_its_ten_keys() -> None:
    # VAR-R4: Pagle.GetItem(itemID).varieties, on every item of the Species, the folded Spotted Yellowtail (6887) too.
    items, varieties = _layers().items, _varieties()
    for item, record in items.items():
        species = record.get("species")
        if isinstance(species, int) and species in varieties:
            assert record.get("varieties") == varieties[species], item
        else:
            assert "varieties" not in record, item
    assert items[6887]["varieties"] == varieties[4603]


def test_the_committed_lock_holds_every_variety_key_of_1_0() -> None:
    # DATA-R73, DATA-R133: the 1.0 release commit ran --lock, so varieties.lock holds each Species' ten keys in
    # varieties.toml's order; the generator's own check fails when one later moves or goes.
    text = (REPO / "data" / "forever" / "varieties.lock").read_text(encoding="utf-8")
    locked = {int(species): table["keys"] for species, table in tomllib.loads(text)["varieties"].items()}
    assert locked == _varieties()


def test_the_manifest_lists_all_370_varieties_and_37_fish_crests() -> None:
    # DATA-R134 passes (read_layers raises on any problem): [core.variety] lists every variety, by Species then
    # position; [core.good] a fish crest per Species, each allowing {fish}.
    core = _layers().lore.manifest["core"]
    assert core["variety"].fields == ("name", "description")
    assert list(core["variety"].ids) == [f"{s}.{key}" for s, keys in sorted(_varieties().items()) for key in keys]
    assert len(core["variety"].ids) == 370
    crests = {id_: allowed for id_, allowed in core["good"].ids.items() if id_.startswith("core.crest.fish.")}
    assert crests == {f"core.crest.fish.{species}": {"fish"} for species in _varieties()}


def test_each_fish_crest_is_named_by_the_one_pattern_and_described_in_its_own_words() -> None:
    # VAR-R12: the name is "{fish} Crest", {fish} the Species' item name at runtime; the description never names it.
    core = _layers().lore.files["core"]
    for species in _varieties():
        assert core[f"good.core.crest.fish.{species}.name"].value == "{fish} Crest"
        assert "{" not in core[f"good.core.crest.fish.{species}.description"].value


def test_no_variety_keeps_a_name_from_a_game_place_or_fish() -> None:
    # DATA-R135 passes (read_layers raises), and #338's renames: the kit's keys and names that came from a game place
    # or item are gone, partial ones the check can't see included.
    gone = {
        "1467.lakeshire-spotted",
        "1467.everstill-sunburst",
        "6317.thunderbrew",
        "6359.firefin",
        "8365.mithril-headed",
        "8365.truesilver",
        "16967.dreamgrove",
        "16969.windrider",
    }
    ids = set(_layers().lore.manifest["core"]["variety"].ids)
    assert not gone & ids
    names = " ".join(text.value for text in _layers().lore.files["core"].values() if text.kind == "variety")
    for word in ("Lakeshire", "Everstill", "Thunderbrew", "Mithril", "Truesilver", "Darkshore", "Dreamgrove"):
        assert word.lower() not in names.lower(), word


def test_the_variety_art_has_ten_rectangles_for_each_species_inside_its_atlas() -> None:
    # varieties.md › Data, UI: VarietyArt.lua's [speciesID] = { { atlas, x, y } x 10 }, 192 x 96 texels each, inside
    # one of the two 2048 x 2048 atlases, no two overlapping.
    text = VARIETY_ART.read_text(encoding="utf-8")
    assert "ns.VARIETY_ART_SIZE = { w = 192, h = 96, atlas = 2048 }" in text
    art = {
        int(species): [tuple(int(n) for n in cell) for cell in re.findall(r"\{ (\d+), (\d+), (\d+) \}", body)]
        for species, body in re.findall(r"^\t\[(\d+)\] = \{\n(.*?)^\t\},$", text, re.MULTILINE | re.DOTALL)
    }
    assert set(art) == set(_varieties())
    seen: set[tuple[int, int, int]] = set()
    for species, cells in art.items():
        assert len(cells) == VARIETY_COUNT, species
        for atlas, x, y in cells:
            assert atlas in (1, 2) and x % 192 == 0 and y % 96 == 0, species
            assert x + 192 <= 2048 and y + 96 <= 2048, species
            assert (atlas, x, y) not in seen, species
            seen.add((atlas, x, y))


def test_the_rarest_title_is_keeper_of_every_colour() -> None:
    # VAR-R22: the Ledger's complete.varieties title, listed in manifest.toml's [ledger.title].
    assert "complete.varieties" in _layers().lore.manifest["ledger"]["title"].ids
    assert _layers().lore.files["ledger"]["title.complete.varieties.text"].value == "Keeper of Every Colour"
