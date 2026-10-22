"""The repo's own item records (DATA-R15-R24, DATA-R77): data/forever/items.toml over the committed baseline and DB2
slice, as the committed Catalogue.lua ships them."""

import re
import tomllib
from collections.abc import Mapping
from functools import cache
from pathlib import Path
from types import MappingProxyType

from item_fixture import item_records_lua
from pagle_data.baseline import read_baseline
from pagle_data.db2 import read_db2
from pagle_data.errors import Problems
from pagle_data.generate import CATALOGUE_LUA
from pagle_data.universe import item_universe

REPO = Path(__file__).resolve().parents[2]

# DATA-R22: the three Extravaganza rares, by hand from items.csv's enUS names (Brownell's Blue Striped Racer,
# Keefer's Angelfish, Dezian Queenfish).
EXTRAVAGANZA_RARES = {19803, 19805, 19806}


@cache
def _committed_items() -> Mapping[int, str]:
    """Each item record's Lua in the committed Catalogue.lua, by item ID."""
    return MappingProxyType(item_records_lua((REPO / CATALOGUE_LUA).read_text(encoding="utf-8")))


def _items_toml() -> dict[int, dict[str, object]]:
    with (REPO / "data" / "forever" / "items.toml").open("rb") as handle:
        return {int(key): value for key, value in tomllib.load(handle)["item"].items()}


def test_every_universe_item_ships_or_is_deliberately_uncharted() -> None:
    # DATA-R15, DATA-R17, DATA-R18: every item of the universe either ships or is uncharted with a why.
    problems = Problems()
    universe = item_universe(REPO, read_baseline(REPO, problems), problems)
    assert problems.found == []
    shipped = _committed_items()
    uncharted = {item for item, entry in _items_toml().items() if entry.get("category") == "uncharted"}
    assert universe == shipped.keys() | uncharted
    assert not shipped.keys() & uncharted


def test_the_three_extravaganza_rares_are_the_legends() -> None:
    # DATA-R22: the first Legend list is the three Extravaganza rares; nothing else is a Legend yet.
    legends = {item for item, record in _committed_items().items() if "legend = true" in record}
    assert legends == EXTRAVAGANZA_RARES


def test_the_extravaganza_fish_and_whimsyfin_are_categorised() -> None:
    # #90: the items tickets #92 and #93 add to catch and pool lists ship with a category: Speckled Tastyfish (19807)
    # and the three rares (DATA-R28), and Whimsyfin (251524, DATA-R43).
    items = _committed_items()
    for item in EXTRAVAGANZA_RARES | {19807, 251524}:
        assert 'category = "fish"' in items[item], items[item]
        assert "noise = false" in items[item]


def test_the_two_lost_gadgets_are_junk_with_no_species_or_length() -> None:
    # varieties.md › Data: Gaffer Jack (6717) and Electropeller (6718) are a lost gadget's parts fished up for a quest,
    # not fish, so they ship as junk: no Species, no typical length (so no Simulated Size, LOG-R65) and no varieties.
    items = _committed_items()
    for item in (6717, 6718):
        assert 'category = "junk"' in items[item], items[item]
        assert "species =" not in items[item] and "typicalLength" not in items[item] and "varieties" not in items[item]
    with (REPO / "data" / "lore" / "ledger.toml").open("rb") as handle:
        ledger = tomllib.load(handle)
    # LED-R144: each has a Junk Museum plaque, and neither keeps a Species' blurb or riddle (DATA-R107's orphan).
    assert {"6717", "6718"} <= ledger["sub"].keys()
    assert not {"6717", "6718"} & ledger["species"].keys()


def test_items_db2_lacks_take_their_class_from_items_toml_and_ship_without_a_quality() -> None:
    # DATA-R24: for an item items.csv lacks, items.toml gives its class (the #89 hand-off: all 90 are in Item.db2 but
    # not ItemSparse, so no DB2 table gives a quality). DATA-R77: quality ships only when known.
    problems = Problems()
    db2 = read_db2(REPO, problems)
    assert problems.found == []
    entries, items = _items_toml(), _committed_items()
    lacking = {item for item in items if item not in db2.items}
    assert len(lacking) == 90
    for item in lacking:
        assert "class" in entries[item] and "quality" not in entries[item], item
        assert "quality =" not in items[item]


def test_a_trophy_ships_its_weight_from_its_enus_name() -> None:
    # DATA-R21: 13876's enUS DB2 name is "40 Pound Yellowtail" (items.csv), so its weight is 40.
    assert re.search(r"family = \d+, .*weight = 40 \}", _committed_items()[13876])


def _species_lengths() -> dict[int, tuple[int, int | None]]:
    """Each Species item's (Species ID, typicalLength or None), by item ID, from the committed Catalogue.lua."""
    found: dict[int, tuple[int, int | None]] = {}
    for item, record in _committed_items().items():
        species = re.search(r"\bspecies = (\d+)", record)
        if species is not None:
            length = re.search(r"\btypicalLength = (\d+)", record)
            found[item] = (int(species.group(1)), int(length.group(1)) if length else None)
    return found


def test_every_species_item_ships_a_typical_length_with_the_check_on() -> None:
    # DATA-R20, DATA-R66: from M4 the typicalLength check is on, so every Species (removed ones and the Legends
    # included) has a typical length of at least 1 mm on each of its items: LOG-R65's Simulated Size input.
    with (REPO / "data" / "checks.toml").open("rb") as handle:
        assert tomllib.load(handle)["typicalLength"] is True
    lengths = _species_lengths()
    # 40 Species IDs, plus Spotted Yellowtail (6887) folded into 4603 (DATA-R19); Gaffer Jack and Electropeller are junk.
    assert len(lengths) == 41
    assert EXTRAVAGANZA_RARES <= lengths.keys()
    for item, (_, length) in lengths.items():
        assert length is not None and length >= 1, item
    # DATA-R20: a folded item carries its Species' typical length.
    assert lengths[6887] == lengths[4603]


def test_every_legend_is_longer_than_every_ordinary_species() -> None:
    # #160 (the drafted values, M4 open question 5): Legends read visibly bigger than ordinary fish, so DATA-R22's
    # three Extravaganza rares each outmeasure every other Species.
    lengths = {item: length or 0 for item, (_, length) in _species_lengths().items()}
    ordinary = max(length for item, length in lengths.items() if item not in EXTRAVAGANZA_RARES)
    assert min(lengths[item] for item in EXTRAVAGANZA_RARES) > ordinary
