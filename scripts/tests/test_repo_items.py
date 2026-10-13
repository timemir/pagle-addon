"""The repo's own item universe (DATA-R15) and data/db2/items.csv (DATA-R11, DATA-R12)."""

import csv
from pathlib import Path

from pagle_data.baseline import read_baseline
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


def test_the_universe_is_the_baseline_s_258_loot_items_while_data_forever_names_none() -> None:
    # DATA-R15; the #57 hand-off counts 252 area-loot items, 258 with pools. data/forever/ has no items.toml,
    # areas.toml or pools.toml yet, so it adds none.
    for name in ("items.toml", "areas.toml", "pools.toml"):
        assert not (REPO / "data" / "forever" / name).exists(), f"{name} exists: this test's count is stale"
    universe = _universe()
    assert len(universe) == 258
    assert universe == _loot_items()
