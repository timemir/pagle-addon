"""Item records (DATA-R16-R24, DATA-R77): data/forever/items.toml, species.toml and families.toml, and the record
each item of the universe (DATA-R15) ships with in the catalogue's items.

Keys and types are the Data section's in docs/spec/content-data.md. Identity facts (class, quality, the enUS name)
come from the DB2 layer, or from items.toml for an item items.csv lacks (DATA-R13, DATA-R24).
"""

import re
from collections.abc import Collection, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.baseline import BaselineLayer
from pagle_data.checks import Checks
from pagle_data.db2 import ITEMS, Db2Layer
from pagle_data.errors import At, Problems
from pagle_data.toml_reader import (
    check_keys,
    describe,
    expect_int,
    expect_table,
    expect_why,
    parse_id,
    read_toml,
)

ITEMS_TOML = "data/forever/items.toml"
SPECIES_TOML = "data/forever/species.toml"
FAMILIES_TOML = "data/forever/families.toml"

# DATA-R17's categories, and DATA-R18's, which never ships.
CATEGORIES = ("fish", "questFish", "trophy", "container", "treasure", "junk", "other")
UNCHARTED = "uncharted"
# DATA-R19: a non-Noise item of these categories is a Species item.
SPECIES_CATEGORIES = frozenset({"fish", "questFish"})

# Tunables: "Noise DB2 classes" (DATA-R16): 0 Consumable, 2 Weapon, 4 Armor, 9 Recipe.
NOISE_CLASSES = frozenset({0, 2, 4, 9})
# Tunables: "Trophy weight pattern (enUS name)", the Lua pattern ^(%d+) Pound  (DATA-R21).
WEIGHT_PATTERN = re.compile(r"([0-9]+) Pound ")
# DATA-R77: quality 0 poor ... 5 legendary.
MAX_QUALITY = 5

_KEYS = (
    "category",
    "species",
    "family",
    "weight",
    "legend",
    "noise",
    "removed",
    "removedFrom",
    "class",
    "quality",
    "why",
)

Record = dict[str, object]


@dataclass(frozen=True)
class ItemEntry:
    """An [item.<itemID>] table of items.toml. noise is None when the entry doesn't override the rule."""

    at: At
    category: str | None = None
    species: int | None = None
    family: int | None = None
    weight: int | None = None
    legend: bool = False
    noise: bool | None = None
    removed: bool = False
    removed_from: int | None = None
    class_id: int | None = None
    quality: int | None = None


@dataclass
class ItemLayer:
    """items.toml's entries by item ID, species.toml's typical lengths by Species ID, families.toml's family IDs."""

    items: dict[int, ItemEntry] = field(default_factory=dict)
    typical_lengths: dict[int, int] = field(default_factory=dict)
    families: set[int] = field(default_factory=set)


def _expect_bool(value: object, at: At, problems: Problems) -> bool | None:
    if isinstance(value, bool):
        return value
    problems.add(at, f"expected a boolean, got {describe(value)}")
    return None


def _read_entry(entry: object, at: At, problems: Problems) -> ItemEntry | None:
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=(), optional=_KEYS)
    found: dict[str, object] = {}
    if "category" in table:
        category = table["category"]
        if isinstance(category, str) and (category in CATEGORIES or category == UNCHARTED):
            found["category"] = category
        else:
            shown = f"'{category}'" if isinstance(category, str) else describe(category)
            problems.add(at / "category", f"expected one of {', '.join(CATEGORIES)} or {UNCHARTED}, got {shown}")
    for key in ("species", "family", "weight", "removedFrom"):
        if key in table:
            found[key] = expect_int(table[key], at / key, problems, minimum=1)
    if "class" in table:
        found["class_id"] = expect_int(table["class"], at / "class", problems, minimum=0)
    if "quality" in table:
        found["quality"] = expect_int(table["quality"], at / "quality", problems, minimum=0, maximum=MAX_QUALITY)
    for key in ("legend", "noise", "removed"):
        if key in table:
            found[key] = _expect_bool(table[key], at / key, problems)

    # DATA-R23: removed = true marks an item proven gone, with removedFrom; DATA-R10: a why goes with removed,
    # uncharted and noise.
    if found.get("removed") is False:
        problems.add(at / "removed", "only removed = true has a meaning; leave it out for an item that isn't removed")
    if "removed" in table and "removedFrom" not in table:
        problems.add(at, "removed needs removedFrom, the first build the item is proven gone on (DATA-R23)")
    if "removedFrom" in table and "removed" not in table:
        problems.add(at / "removedFrom", "removedFrom goes with removed = true (DATA-R23)")
    needs_why = [key for key in ("removed", "noise") if key in table]
    if found.get("category") == UNCHARTED:
        needs_why.append('category = "uncharted"')
    if needs_why and "why" not in table:
        verb = "needs" if len(needs_why) == 1 else "need"
        problems.add(at, f"missing key 'why': {' and '.join(needs_why)} {verb} the evidence (DATA-R10)")
    expect_why(table, at, problems)

    # confirmed.check_removed checks removedFrom against observations of the item (DATA-R23).
    category, noise = found.get("category"), found.get("noise")
    return ItemEntry(
        at,
        category=category if isinstance(category, str) else None,
        species=_int(found.get("species")),
        family=_int(found.get("family")),
        weight=_int(found.get("weight")),
        legend=found.get("legend") is True,
        noise=noise if isinstance(noise, bool) else None,
        removed=found.get("removed") is True,
        removed_from=_int(found.get("removedFrom")),
        class_id=_int(found.get("class_id")),
        quality=_int(found.get("quality")),
    )


def _int(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _id_tables(root: Path, file: str, kind: str, problems: Problems) -> dict[int, tuple[object, At]]:
    """The [<kind>.<ID>] tables of root/file by ID, the file's only key being kind."""
    document = read_toml(root, file, problems)
    if document is None:
        return {}
    at = At(file)
    check_keys(document, at, problems, required=(), optional=(kind,))
    tables = expect_table(document.get(kind, {}), at / kind, problems)
    found: dict[int, tuple[object, At]] = {}
    for key, entry in (tables or {}).items():
        entry_at = at / kind / key
        found_id = parse_id(key, entry_at, problems)
        if found_id is not None:
            found[found_id] = (entry, entry_at)
    return found


def read_item_layer(root: Path, problems: Problems) -> ItemLayer:
    """items.toml, species.toml and families.toml under root/data/forever/. Each problem found goes into problems;
    what was read is returned either way, and the caller must not use it while there are problems."""
    layer = ItemLayer()
    for item, (entry, at) in _id_tables(root, ITEMS_TOML, "item", problems).items():
        read = _read_entry(entry, at, problems)
        if read is not None:
            layer.items[item] = read
    for species, (entry, at) in _id_tables(root, SPECIES_TOML, "species", problems).items():
        table = expect_table(entry, at, problems)
        if table is None:
            continue
        check_keys(table, at, problems, required=("typicalLength",), optional=())
        if "typicalLength" in table:
            length = expect_int(table["typicalLength"], at / "typicalLength", problems, minimum=1)
            if length is not None:
                layer.typical_lengths[species] = length
    for family, (entry, at) in _id_tables(root, FAMILIES_TOML, "family", problems).items():
        table = expect_table(entry, at, problems)
        if table is not None:
            check_keys(table, at, problems, required=(), optional=())  # a family table only declares its ID
            layer.families.add(family)
    return layer


def reference_only(baseline: BaselineLayer) -> set[int]:
    """The items the baseline reaches only through reference loot tables (DATA-R16)."""
    direct = {row.item for row in baseline.area_loot if row.item is not None}
    direct.update(row.item for row in baseline.pool_loot if row.item is not None)
    return {row.item for row in baseline.reference_loot} - direct


@dataclass(frozen=True)
class Identity:
    """An item's class and quality, each None when unknown, and the layer they came from (DATA-R13, DATA-R24):
    data/db2/items.csv as soon as DB2 has the item, items.toml until then, None when neither gives either."""

    class_id: int | None = None
    quality: int | None = None
    layer: str | None = None


def identity(db2: Db2Layer, entry: ItemEntry | None, item: int) -> Identity:
    """The item's class and quality as the catalogue takes them: DB2 wins as soon as it has the item; items.toml
    gives them until then (DATA-R24)."""
    known = db2.items.get(item)
    if known is not None:
        return Identity(known.class_id, known.quality, ITEMS)
    if entry is not None and (entry.class_id is not None or entry.quality is not None):
        return Identity(entry.class_id, entry.quality, ITEMS_TOML)
    return Identity()


def _name(db2: Db2Layer, item: int) -> str:
    """The item's enUS DB2 name, for a problem message (it never ships, DATA-R3)."""
    known = db2.items.get(item)
    return f": {known.name}" if known is not None and known.name else ""


def item_records(
    universe: Collection[int],
    baseline: BaselineLayer,
    layer: ItemLayer,
    db2: Db2Layer,
    checks: Checks,
    problems: Problems,
) -> dict[int, Record]:
    """The record of every item of the universe that ships (DATA-R65, DATA-R77), by item ID: Noise items as other
    (DATA-R16), nothing uncharted (DATA-R18). Each item that breaks DATA-R16-R21 is a problem."""
    by_reference = reference_only(baseline)
    records: dict[int, Record] = {}
    for item in sorted(universe):
        entry = layer.items.get(item) or ItemEntry(At(ITEMS_TOML, f"item.{item}"))
        known = db2.items.get(item)
        found = identity(db2, entry, item)  # DATA-R24
        class_id, quality = found.class_id, found.quality

        noise = entry.noise
        if noise is None:
            noise = item in by_reference or class_id in NOISE_CLASSES
        record: Record = {"legend": entry.legend, "noise": noise, "removed": entry.removed, "pool": False}
        if quality is not None:
            record["quality"] = quality

        if noise:
            # DATA-R16: a Noise item counts toward nothing; to count it as something, set noise = false.
            if entry.category not in (None, "other"):
                problems.add(
                    entry.at / "category",
                    f"item {item} is Noise, so its category can only be other; set noise = false to count it"
                    f" as {entry.category} (DATA-R16)",
                )
            if entry.legend:
                problems.add(entry.at / "legend", f"item {item} is Noise and can't be a Legend (DATA-R16)")
            category = "other"
        elif entry.category is None:
            problems.add(
                entry.at,
                "no category; every item of the universe that isn't Noise needs one (DATA-R17)" + _name(db2, item),
            )
            continue
        else:
            category = entry.category
        if category == UNCHARTED:
            continue  # DATA-R18: kept out on purpose
        record["category"] = category

        if entry.species is not None and category not in SPECIES_CATEGORIES:
            problems.add(entry.at / "species", f"item {item} isn't a Species item (fish or questFish), DATA-R19")
        if category in SPECIES_CATEGORIES:
            record["species"] = entry.species if entry.species is not None else item

        for key, value in (("family", entry.family), ("weight", entry.weight)):
            if value is not None and category != "trophy":
                problems.add(entry.at / key, f"item {item} isn't a trophy, so it has no {key} (DATA-R21)")
        if category == "trophy":
            _trophy(item, entry, known.name if known is not None else "", layer, record, problems)
        records[item] = record

    _check_species(records, layer, checks, problems)
    return records


def _trophy(item: int, entry: ItemEntry, name: str, layer: ItemLayer, record: Record, problems: Problems) -> None:
    """DATA-R21: a trophy's family, declared in families.toml, and its weight, from items.toml or the enUS name."""
    if entry.family is None:
        problems.add(entry.at, f"item {item} is a trophy and needs a family (DATA-R21)")
    elif entry.family not in layer.families:
        problems.add(entry.at / "family", f"family {entry.family} isn't declared in {FAMILIES_TOML} (DATA-R21)")
    else:
        record["family"] = entry.family
    weight = entry.weight
    if weight is None:
        match = WEIGHT_PATTERN.match(name)
        weight = int(match.group(1)) if match else None
    if weight is None:
        problems.add(
            entry.at,
            f"item {item} is a trophy and needs a weight: its enUS DB2 name"
            f" ('{name}') doesn't start with '<pounds> Pound ', so set weight (DATA-R21)",
        )
    else:
        record["weight"] = weight


def _check_species(records: Mapping[int, Record], layer: ItemLayer, checks: Checks, problems: Problems) -> None:
    """DATA-R19: a species fold targets a Species item whose own species is itself. DATA-R20: typical lengths are
    keyed by Species ID and emitted on every item of the Species; with the check on, every Species needs one."""
    species_ids = {item for item, record in records.items() if record.get("species") == item}
    for item, record in records.items():
        target = record.get("species")
        if target is None or target == item:
            continue
        entry_at = layer.items[item].at / "species"
        target_record = records.get(target) if isinstance(target, int) else None
        if target_record is None or "species" not in target_record:
            problems.add(entry_at, f"{target} isn't a Species item, so item {item} can't fold into it (DATA-R19)")
        elif target not in species_ids:
            problems.add(
                entry_at,
                f"{target} folds into {target_record['species']} itself, so it isn't a Species ID; fold item {item}"
                f" into {target_record['species']} (DATA-R19)",
            )
    for species in sorted(layer.typical_lengths):
        if species not in species_ids:
            problems.add(At(SPECIES_TOML, f"species.{species}"), f"{species} isn't a Species ID (DATA-R19, DATA-R20)")
    for record in records.values():
        of = record.get("species")
        if isinstance(of, int) and of in layer.typical_lengths:
            record["typicalLength"] = layer.typical_lengths[of]
    if checks.typical_length:
        for species in sorted(species_ids - layer.typical_lengths.keys()):
            problems.add(
                At(SPECIES_TOML), f"Species {species} has no typicalLength, and the check is on (DATA-R20, DATA-R66)"
            )
