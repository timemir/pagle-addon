"""The repo's own pool types (DATA-R43, DATA-R44): data/forever/pools.toml over the committed baseline, as the
committed Catalogue.lua ships them, with each item record's pool flag (DATA-R77)."""

import csv
from pathlib import Path

from pagle_data.generate import read_layers

REPO = Path(__file__).resolve().parents[2]


def _template_names() -> dict[int, str]:
    # Straight from the committed pools.csv, not through the baseline reader.
    with (REPO / "data" / "baseline" / "pools.csv").open(encoding="utf-8", newline="") as handle:
        return {int(row["entry"]): row["name"] for row in csv.DictReader(handle)}


def test_every_baseline_template_is_in_one_of_the_13_named_pool_types_and_whimsyfin() -> None:
    # #93 and the #57 hand-off: 24 pool templates of 13 pool types at patch 1.12, each in a pool type, so no
    # warning; every template of a pool type has the same VMaNGOS name. DATA-R43: School of Whimsyfin is
    # entries = [572928], add = [251524].
    layers = read_layers(REPO)
    assert layers.ungrouped_pools() == []
    names = _template_names()
    assert len(names) == 24
    baseline_types = {key: entry for key, entry in layers.pool_types.items() if key != "schoolOfWhimsyfin"}
    assert len(baseline_types) == 13
    for pool_type, entry in baseline_types.items():
        assert len({names[gameobject] for gameobject in entry.entries}) == 1, pool_type
    assert sorted(gameobject for entry in baseline_types.values() for gameobject in entry.entries) == sorted(names)
    whimsyfin = layers.pool_types["schoolOfWhimsyfin"]
    assert (whimsyfin.entries, whimsyfin.add, whimsyfin.drop) == ((572928,), (251524,), ())


def test_school_of_whimsyfin_lists_whimsyfin_and_noise_leaves_the_pools() -> None:
    # DATA-R43: Whimsyfin's catches come from add. Noise is left out: Stranglekelp (3820) is in most pool loot and
    # Peacebloom (2447) is School of Fish's only loot, both Noise by items.toml (#90), so School of Fish ships empty.
    layers = read_layers(REPO)
    assert layers.pools["schoolOfWhimsyfin"] == [251524]
    assert layers.pools["schoolOfFish"] == []
    for catches in layers.pools.values():
        assert catches == sorted(catches)
        assert 3820 not in catches and 2447 not in catches
    # Oily Blackmouth (6358) from its own school; the Extravaganza fish (DATA-R28) from School of Tastyfish.
    assert 6358 in layers.pools["oilyBlackmouthSchool"]
    assert {19803, 19805, 19806, 19807} <= set(layers.pools["schoolOfTastyfish"])


def test_pool_is_true_exactly_for_items_in_a_pool_type_s_catches() -> None:
    # DATA-R77, LOG-R55: pool is true when the item is in any pool type's catches; Noise ships with pool = false
    # (DATA-R16).
    layers = read_layers(REPO)
    pooled = {item for catches in layers.pools.values() for item in catches}
    assert {item for item, record in layers.items.items() if record["pool"] is True} == pooled
    assert layers.items[3820]["pool"] is False
    assert layers.items[251524]["pool"] is True
