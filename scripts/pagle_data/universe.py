"""The item universe (DATA-R15): every item ID Pagle cares about. data/db2/items.csv holds DB2's rows for exactly
these items (DATA-R11), and every one either ships in the catalogue or is deliberately deferred.

So far its sources are the baseline's area, reference and pool loot, and the data/forever/ files that name items:
items.toml's [item.<itemID>] tables, areas.toml's [[catch]] items and pools.toml's add and drop lists (the Data
section's keys). Each forever file is read only when it exists, and only for its item IDs: the file's own reader
checks the rest. Fixed Hunt classes (DATA-R90) and data/observed/ (dev facts, non-rejected I rows) join here too,
through item_universe, when their layers arrive.
"""

from collections.abc import Callable, Mapping
from pathlib import Path

from pagle_data.baseline import BaselineLayer
from pagle_data.toml_reader import At, Problems, describe, expect_ids, expect_int, expect_table, parse_id, read_toml

ITEMS_TOML = "data/forever/items.toml"
AREAS_TOML = "data/forever/areas.toml"
POOLS_TOML = "data/forever/pools.toml"


def _items_toml(document: Mapping[str, object], at: At, problems: Problems) -> set[int]:
    """items.toml's [item.<itemID>] keys."""
    if "item" not in document:
        return set()
    table = expect_table(document["item"], at / "item", problems)
    found: set[int] = set()
    for key in table or {}:
        item = parse_id(key, at / "item" / key, problems)
        if item is not None:
            found.add(item)
    return found


def _areas_toml(document: Mapping[str, object], at: At, problems: Problems) -> set[int]:
    """areas.toml's [[catch]] items, added or dropped."""
    entries = document.get("catch", [])
    if not isinstance(entries, list):
        problems.add(at / "catch", f"expected an array of tables ([[catch]]), got {describe(entries)}")
        return set()
    found: set[int] = set()
    for index, entry in enumerate(entries):
        entry_at = At(at.file, f"catch[{index}]")
        table = expect_table(entry, entry_at, problems)
        if table is None or "item" not in table:
            continue
        item = expect_int(table["item"], entry_at / "item", problems, minimum=1)
        if item is not None:
            found.add(item)
    return found


def _pools_toml(document: Mapping[str, object], at: At, problems: Problems) -> set[int]:
    """pools.toml's add and drop items, of every pool type."""
    if "pool" not in document:
        return set()
    pools = expect_table(document["pool"], at / "pool", problems)
    found: set[int] = set()
    for key, entry in (pools or {}).items():
        pool_at = at / "pool" / key
        table = expect_table(entry, pool_at, problems)
        for edit in ("add", "drop"):
            if table is not None and edit in table:
                found.update(expect_ids(table[edit], pool_at / edit, problems) or [])
    return found


_FOREVER: dict[str, Callable[[Mapping[str, object], At, Problems], set[int]]] = {
    ITEMS_TOML: _items_toml,
    AREAS_TOML: _areas_toml,
    POOLS_TOML: _pools_toml,
}


def _baseline_items(baseline: BaselineLayer) -> set[int]:
    found = {row.item for row in baseline.area_loot if row.item is not None}
    found.update(row.item for row in baseline.reference_loot)
    found.update(row.item for row in baseline.pool_loot if row.item is not None)
    return found


def forever_items(root: Path, problems: Problems) -> set[int]:
    """The item IDs named in root/data/forever/'s files that name items, reading only those that exist. An item ID
    that can't be read is a problem: until it's fixed the universe isn't known."""
    found: set[int] = set()
    for file, read in _FOREVER.items():
        if not (root / file).is_file():
            continue
        document = read_toml(root, file, problems)
        if document is not None:
            found |= read(document, At(file), problems)
    return found


def item_universe(root: Path, baseline: BaselineLayer, problems: Problems) -> frozenset[int]:
    """The item universe (DATA-R15) of the data/ tree at root, given its baseline layer, which must have been read
    without problems. Each problem found goes into problems; the caller must not use the universe while there are
    any."""
    return frozenset(_baseline_items(baseline) | forever_items(root, problems))
