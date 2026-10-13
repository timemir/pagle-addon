"""Pool types (DATA-R43, DATA-R44): data/forever/pools.toml over the baseline's pools.csv, pool_loot.csv and
reference_loot.csv, the catalogue's poolType -> catches, and each item record's pool flag (DATA-R77, LOG-R55).

Pools have no runtime ID, so only the catches ship, for display; no entry-to-type map does (DATA-R44).
"""

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path

from pagle_data.baseline import BaselineLayer, Pool
from pagle_data.errors import At, Problems
from pagle_data.toml_reader import check_keys, expect_ids, expect_table, expect_why, read_toml

POOLS_TOML = "data/forever/pools.toml"

# DATA-R43: a pool type ID is Lua's [%w_]+ (ASCII letters, digits and underscores).
POOL_TYPE_ID = re.compile(r"[A-Za-z0-9_]+")

# A record as pagle_data.items builds it (DATA-R77).
Record = dict[str, object]


@dataclass(frozen=True)
class PoolType:
    """A [pool.<poolType>] table of pools.toml: the GameObject entries it groups and its item edits."""

    at: At
    entries: tuple[int, ...]
    add: tuple[int, ...] = ()
    drop: tuple[int, ...] = ()


def _read_entry(entry: object, at: At, problems: Problems) -> PoolType | None:
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=("entries", "why"), optional=("add", "drop"))
    expect_why(table, at, problems)
    entries = expect_ids(table["entries"], at / "entries", problems) if "entries" in table else None
    if entries == []:
        problems.add(at / "entries", "empty: a pool type groups at least one GameObject entry (DATA-R43)")
    edits = {
        edit: tuple(expect_ids(table[edit], at / edit, problems) or []) if edit in table else ()
        for edit in ("add", "drop")
    }
    if not entries:
        return None
    return PoolType(at, tuple(entries), edits["add"], edits["drop"])


def read_pools_toml(root: Path, problems: Problems) -> dict[str, PoolType]:
    """pools.toml's pool types by ID (DATA-R10, DATA-R43). Each problem found goes into problems, including an entry
    grouped by two pool types; a bad pool type is left out."""
    document = read_toml(root, POOLS_TOML, problems)
    if document is None:
        return {}
    at = At(POOLS_TOML)
    check_keys(document, at, problems, required=(), optional=("pool",))
    table = expect_table(document.get("pool", {}), at / "pool", problems)
    pool_types: dict[str, PoolType] = {}
    grouped: dict[int, str] = {}
    for pool_type, entry in (table or {}).items():
        entry_at = at / "pool" / pool_type
        if not POOL_TYPE_ID.fullmatch(pool_type):
            problems.add(entry_at, "a pool type ID is letters, digits and underscores ([%w_]+, DATA-R43)")
            continue
        read = _read_entry(entry, entry_at, problems)
        if read is None:
            continue
        for gameobject in read.entries:
            if gameobject in grouped:
                problems.add(entry_at / "entries", f"entry {gameobject} is already in pool type {grouped[gameobject]}")
            grouped.setdefault(gameobject, pool_type)
        pool_types[pool_type] = read
    return pool_types


def pool_items(pool_types: Mapping[str, PoolType]) -> set[int]:
    """The items pools.toml's add and drop lists name (DATA-R15's pool edits)."""
    return {item for pool_type in pool_types.values() for item in (*pool_type.add, *pool_type.drop)}


def _loot(baseline: BaselineLayer, entries: Iterable[int]) -> set[int]:
    """The baseline's pool loot for entries, reference tables flattened (reference_loot.csv is flat, DATA-R9)."""
    wanted = set(entries)
    items: set[int] = set()
    refs: set[int] = set()
    for row in baseline.pool_loot:
        if row.entry in wanted:
            if row.item is not None:
                items.add(row.item)
            if row.ref is not None:
                refs.add(row.ref)
    items.update(row.item for row in baseline.reference_loot if row.ref in refs)
    return items


def build_pools(
    pool_types: Mapping[str, PoolType], baseline: BaselineLayer, records: Mapping[int, Record]
) -> dict[str, list[int]]:
    """Each pool type's catches (DATA-R43): its entries' pool loot, then add, then drop, leaving out Noise, removed
    items and every item that doesn't ship (uncharted, DATA-R18), ascending."""
    pools: dict[str, list[int]] = {}
    for pool_type_id, pool_type in pool_types.items():
        items = (_loot(baseline, pool_type.entries) | set(pool_type.add)) - set(pool_type.drop)
        pools[pool_type_id] = sorted(item for item in items if _ships_in_lists(records.get(item)))
    return pools


def _ships_in_lists(record: Record | None) -> bool:
    return record is not None and record["noise"] is False and record["removed"] is False


def with_pool_flags(records: Mapping[int, Record], pools: Mapping[str, list[int]]) -> dict[int, Record]:
    """records with each pool flag set (DATA-R77): true for an item in any pool type's catches."""
    pooled = {item for catches in pools.values() for item in catches}
    return {item: {**record, "pool": item in pooled} for item, record in records.items()}


def ungrouped(pool_types: Mapping[str, PoolType], baseline: BaselineLayer) -> list[Pool]:
    """The pools.csv templates in no pool type: a warning, so a new baseline template isn't silently dropped."""
    grouped = {gameobject for pool_type in pool_types.values() for gameobject in pool_type.entries}
    return [pool for pool in baseline.pools if pool.entry not in grouped]
