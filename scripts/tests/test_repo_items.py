"""The repo's own item universe (DATA-R15) and data/db2/items.csv (DATA-R11, DATA-R12)."""

import csv
from pathlib import Path

from pagle_data.baseline import read_baseline
from pagle_data.db2 import ITEMS, Item, read_db2
from pagle_data.toml_reader import Problems
from pagle_data.universe import item_universe

REPO = Path(__file__).resolve().parents[2]


def _universe() -> frozenset[int]:
    problems = Problems()
    universe = item_universe(REPO, read_baseline(REPO, problems), problems)
    assert problems.found == []
    return universe


def _loot_items() -> set[int]:
    # Straight from the committed CSVs, not through the baseline reader: the item column of each loot file.
    items: set[int] = set()
    for name in ("area_loot.csv", "reference_loot.csv", "pool_loot.csv"):
        with (REPO / "data" / "baseline" / name).open(encoding="utf-8", newline="") as handle:
            items |= {int(row["item"]) for row in csv.DictReader(handle) if row["item"]}
    return items


def test_the_universe_is_the_baseline_s_258_loot_items_and_whimsyfin() -> None:
    # DATA-R15; the #57 hand-off counts 252 area-loot items, 258 with pools. items.toml adds Whimsyfin (251524, a
    # Forever pool fish the baseline lacks, #90), which pools.toml also adds (#93); areas.toml doesn't exist yet.
    assert not (REPO / "data" / "forever" / "areas.toml").exists(), "areas.toml exists: this test's count is stale"
    universe = _universe()
    assert len(universe) == 259
    assert universe == _loot_items() | {251524}


def test_items_csv_holds_universe_items_only_sorted_by_id_for_the_slice_s_build() -> None:
    # DATA-R11: items.csv covers the item universe, under wago.tools' column names, sorted by ID, for the one build
    # build.toml names (1.60.1.70338, as areas.csv). Spot checks by hand from wago.tools' ItemSparse and Item for
    # that build: Raw Slitherskin Mackerel and Speckled Tastyfish.
    problems = Problems()
    layer = read_db2(REPO, problems)
    assert problems.found == []
    assert (layer.version, layer.build) == ("1.60.1", 70338)
    lines = (REPO / ITEMS).read_text(encoding="utf-8").splitlines()
    assert lines[0] == "ID,ClassID,SubclassID,OverallQualityID,Display_lang"
    ids = [int(line.split(",")[0]) for line in lines[1:]]
    assert ids == sorted(ids) == sorted(layer.items)
    assert set(ids) <= _universe()
    assert layer.items[6303] == Item(class_id=7, subclass=8, quality=1, name="Raw Slitherskin Mackerel")
    assert layer.items[19807] == Item(class_id=15, subclass=4, quality=1, name="Speckled Tastyfish")
