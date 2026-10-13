"""The repo's own item records (DATA-R15-R24, DATA-R77): data/forever/items.toml over the committed baseline and DB2
slice, as the committed Catalogue.lua ships them."""

import re
import tomllib
from pathlib import Path

from pagle_data.baseline import read_baseline
from pagle_data.db2 import read_db2
from pagle_data.generate import CATALOGUE_LUA, generate
from pagle_data.toml_reader import Problems
from pagle_data.universe import item_universe

REPO = Path(__file__).resolve().parents[2]

# DATA-R22: the three Extravaganza rares, by hand from items.csv's enUS names (Brownell's Blue Striped Racer,
# Keefer's Angelfish, Dezian Queenfish).
EXTRAVAGANZA_RARES = {19803, 19805, 19806}


def _committed_items() -> dict[int, str]:
    """Each item record's Lua in the committed Catalogue.lua, by item ID."""
    text = (REPO / CATALOGUE_LUA).read_text(encoding="utf-8")
    assert text == generate(REPO)[CATALOGUE_LUA]  # DATA-R61: the committed file is what data/ gives
    block = re.search(r"^\titems = \{\n(.*?)^\t\},$", text, flags=re.MULTILINE | re.DOTALL)
    assert block is not None
    return {int(i): record for i, record in re.findall(r"^\t\t\[(\d+)\] = (\{.*\}),$", block.group(1), re.M)}


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
