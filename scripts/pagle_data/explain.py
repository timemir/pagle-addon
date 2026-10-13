"""--explain <itemID|areaID> (DATA-R60): every layer's value for an item or an area and which won.

For an item: its baseline loot, its items.toml entry, its DB2 identity, its observations, each fact more than one
layer can give (class, quality, Noise, category, a trophy's weight) with the layer that won, its record, its pool
types and the catch lists it was considered for. For an area: its slice row, its alias, its skill base, hasData and
its catch list with each entry's source (the baseline, areas.toml, an observed pair), gate and confirmed flags. An ID
that is both an item and an area prints both. The layers are read in DATA-R8's order: baseline, forever, db2,
observed.
"""

from collections.abc import Iterable

from pagle_data.areas import AreaLayer
from pagle_data.baseline import BASELINE, BaselineLayer
from pagle_data.db2 import AREAS, ITEMS, Db2Layer
from pagle_data.forever import ALIASES
from pagle_data.generate import Layers, catalogue_of
from pagle_data.items import NOISE_CLASSES, UNCHARTED, WEIGHT_PATTERN, ItemEntry, reference_only
from pagle_data.lua import to_lua
from pagle_data.universe import AREAS_TOML, ITEMS_TOML, POOLS_TOML

SKILL = f"{BASELINE}/skill.csv"
POOL_LOOT = f"{BASELINE}/pool_loot.csv"


def explain(layers: Layers, target: int) -> list[str]:
    """The lines --explain prints for target: its item section, its area section, or both; none when it is neither
    an item of the universe (DATA-R15) nor an area of the slice (DATA-R25)."""
    lines: list[str] = []
    if target in layers.items or target in layers.item_layer.items:
        lines += _item(layers, target)
    if target in layers.db2.areas:
        lines += _area(layers, target)
    return lines


def _lower(value: bool) -> str:
    return "true" if value else "false"


def _ids(name: str, ids: Iterable[int]) -> str:
    """'area 53' or 'areas 12, 18'."""
    found = sorted(set(ids))
    return f"{name}{'s' if len(found) > 1 else ''} {', '.join(str(one) for one in found)}"


def _wins(parts: list[str], winner: str | None, value: object) -> str:
    """A fact's values from each layer, then the layer that won and its value."""
    won = f" -> {winner} wins: {value}" if winner is not None else " -> none"
    return "; ".join(parts) + won


# An item


def _baseline_loot(baseline: BaselineLayer, item: int) -> str:
    tables = {row.ref for row in baseline.reference_loot if row.item == item}
    direct = [row.area for row in baseline.area_loot if row.item == item]
    through = [row.area for row in baseline.area_loot if row.ref in tables]
    pools = [row.entry for row in baseline.pool_loot if row.item == item or row.ref in tables]
    parts: list[str] = []
    if direct:
        parts.append(f"area loot in {_ids('area', direct)}")
    if tables:
        where = f" (in {_ids('area', through)})" if through else ""
        parts.append(f"{_ids('reference table', tables)}{where}")
    if pools:
        parts.append(f"pool loot of {', '.join(str(entry) for entry in sorted(set(pools)))}")
    return "; ".join(parts) if parts else "in no loot"


def _entry_fields(entry: ItemEntry) -> str:
    fields: list[str] = []
    if entry.category is not None:
        fields.append(f'category = "{entry.category}"')
    for key, number in (("species", entry.species), ("family", entry.family), ("weight", entry.weight)):
        if number is not None:
            fields.append(f"{key} = {number}")
    if entry.legend:
        fields.append("legend = true")
    if entry.noise is not None:
        fields.append(f"noise = {_lower(entry.noise)}")
    if entry.removed:
        fields.append(f"removed = true, removedFrom = {entry.removed_from}")
    for key, number in (("class", entry.class_id), ("quality", entry.quality)):
        if number is not None:
            fields.append(f"{key} = {number}")
    return ", ".join(fields) if fields else "no key"


def _identity(name: str, db2_value: int | None, toml_value: int | None) -> str:
    """class or quality: DB2 wins as soon as it has the item; items.toml gives it until then (DATA-R24)."""
    given = ((db2_value, ITEMS), (toml_value, ITEMS_TOML))
    parts = [f"{value} from {layer}" for value, layer in given if value is not None]
    if not parts:
        return f"  {name}: unknown (in neither {ITEMS} nor {ITEMS_TOML})"
    winner, value = (ITEMS, db2_value) if db2_value is not None else (ITEMS_TOML, toml_value)
    return f"  {name}: {_wins(parts, winner, value)}"


def _item(layers: Layers, item: int) -> list[str]:
    entry = layers.item_layer.items.get(item)
    known = layers.db2.items.get(item)
    class_id = known.class_id if known is not None else entry.class_id if entry is not None else None
    lines = [f"item {item}", f"  {BASELINE}/: {_baseline_loot(layers.baseline, item)}"]
    lines.append(f"  {entry.at}: {_entry_fields(entry)}" if entry is not None else f"  {ITEMS_TOML}: no entry")
    if known is not None:
        lines.append(
            f"  {ITEMS}: class {known.class_id}, subclass {known.subclass}, quality {known.quality},"
            f" name '{known.name}'"
        )
    else:
        lines.append(f"  {ITEMS}: no row")
    lines.append(f"  data/observed/: {_observed(layers, item)}")
    lines.append(_identity("class", known.class_id if known else None, entry.class_id if entry else None))
    lines.append(_identity("quality", known.quality if known else None, entry.quality if entry else None))

    # DATA-R16: Noise by rule (reference loot only, or a Noise class), unless items.toml says otherwise.
    rule: list[str] = []
    if item in reference_only(layers.baseline):
        rule.append(f"true by rule (only reference loot reaches it) from {BASELINE}/")
    if class_id in NOISE_CLASSES:
        source = ITEMS if known is not None else ITEMS_TOML
        rule.append(f"true by rule (DB2 class {class_id} is a Noise class) from {source}")
    noise = bool(rule)
    if not rule:
        rule.append("false by rule (DATA-R16)")
    winner = "the rule"
    if entry is not None and entry.noise is not None:
        rule.append(f"{_lower(entry.noise)} from {ITEMS_TOML}")
        winner, noise = ITEMS_TOML, entry.noise
    lines.append(f"  noise: {_wins(rule, winner, _lower(noise))}")

    # DATA-R16-R18: a Noise item is other; every other item takes items.toml's category.
    category = entry.category if entry is not None else None
    parts = [f"{category} from {ITEMS_TOML}"] if category is not None else []
    if noise:
        lines.append(f"  category: {_wins(parts + ['other for a Noise item (DATA-R16)'], 'DATA-R16', 'other')}")
    else:
        lines.append(f"  category: {_wins(parts, ITEMS_TOML, category)}")

    record = layers.items.get(item)
    if record is not None and record.get("category") == "trophy":
        named = WEIGHT_PATTERN.match(known.name) if known is not None else None
        weights = [f"{named.group(1)} from {ITEMS}'s name"] if named else []
        if entry is not None and entry.weight is not None:
            weights.append(f"{entry.weight} from {ITEMS_TOML}")
        weight_from = ITEMS_TOML if entry is not None and entry.weight is not None else f"{ITEMS}'s name"
        lines.append(f"  weight: {_wins(weights, weight_from, record.get('weight'))}")
    if record is not None:
        lines.append(f"  record: {to_lua(record)}")
    else:
        lines.append(f'  record: none: category = "{UNCHARTED}" keeps it out of the catalogue (DATA-R18)')
    lines.append(f"  pool types: {_pool_types(layers, item)}")
    lines += _lists(layers, item)
    return lines


def _observed(layers: Layers, item: int) -> str:
    seen = layers.observations()
    rows = [row for row in seen.catches if row.item == item]
    facts = [fact for fact in seen.facts if fact.item == item]
    parts: list[str] = []
    if rows:
        reporters = {row.reporter for row in rows}
        parts.append(
            f"{len(rows)} catch row(s) from {len(reporters)} reporter(s), in {_ids('area', (row.area for row in rows))}"
        )
    if facts:
        parts.append(f"{len(facts)} dev fact(s): {', '.join(fact.kind for fact in facts)}")
    return "; ".join(parts) if parts else "no observation"


def _pool_types(layers: Layers, item: int) -> str:
    tables = {row.ref for row in layers.baseline.reference_loot if row.item == item}
    found: list[str] = []
    for pool_id, pool_type in sorted(layers.pool_types.items()):
        why = [
            f"{POOL_LOOT}: entry {row.entry}"
            for row in layers.baseline.pool_loot
            if row.entry in pool_type.entries and (row.item == item or row.ref in tables)
        ]
        edits = (("add", pool_type.add), ("drop", pool_type.drop))
        why += [f"{POOLS_TOML} {edit}" for edit, items in edits if item in items]
        if why:
            shipped = "in its catches" if item in layers.pools.get(pool_id, []) else "not in its catches"
            found.append(f"{pool_id} ({', '.join(why)}) -> {shipped}")
    return "; ".join(found) if found else "none"


def _entry_result(layers: Layers, area: int, item: int) -> str:
    """The catch entry DATA-R26 ends with for item in area, and its confirmed flags (DATA-R48, DATA-R52)."""
    for catch in layers.catch_lists.lists.get(area, []):
        if catch.item == item:
            key = (area, item)
            flags = f"confirmed = {_lower(key in layers.confirmation.entries)}"
            if catch.window is None:
                return f"listed; {flags}"
            gate_confirmed = _lower(key in layers.confirmation.gates)
            return f"listed, gate {catch.window}; {flags}, gateConfirmed = {gate_confirmed}"
    return "not listed"


def _lists(layers: Layers, item: int) -> list[str]:
    areas = sorted(area for area, by_item in layers.catch_lists.history.items() if item in by_item)
    if not areas:
        return ["  catch lists: none"]
    lines = ["  catch lists (DATA-R26), each with what every layer did:"]
    for area in areas:
        steps = "; ".join(layers.catch_lists.history[area][item])
        lines.append(f"    area {area}: {steps} -> {_entry_result(layers, area, item)}")
    return lines


# An area


def _skill_base(layers: Layers, area: int) -> str:
    """DATA-R30: a zone's skill base from skill.csv, overridden by areas.toml, which alone can give a subzone one."""
    zone = layers.db2.areas[area].parent == 0
    edit = _area_edit(layers.area_layer, area)
    parts: list[str] = []
    if area in layers.baseline.skill:
        ignored = "" if zone else ", ignored: a subzone takes none from it (DATA-R30)"
        parts.append(f"{layers.baseline.skill[area]} from {SKILL}{ignored}")
    if edit is not None:
        parts.append(f"{edit[1]} from {edit[0]}")
    winner = AREAS_TOML if edit is not None else SKILL if zone and area in layers.baseline.skill else None
    confirmed = f"skillBaseConfirmed = {_lower(area in layers.confirmation.skill_bases)}"
    if not parts:
        return f"none; {confirmed}"
    return f"{_wins(parts, winner, layers.catch_lists.skill_bases.get(area))}; {confirmed}"


def _area_edit(layer: AreaLayer, area: int) -> tuple[str, int] | None:
    edit = layer.areas.get(area)
    if edit is None or edit.skill_base is None:
        return None
    return str(edit.at), edit.skill_base


def _slice_row(db2: Db2Layer, area: int) -> str:
    row = db2.areas[area]
    return f"  {AREAS}: parent {row.parent}, continent {row.continent}, name '{row.name}'"


def _area(layers: Layers, area: int) -> list[str]:
    lines = [f"area {area}", _slice_row(layers.db2, area)]
    aliases = {alias.source: alias.target for alias in layers.forever.aliases}
    if area in aliases:
        lines.append(f"  alias: {ALIASES} maps it to {aliases[area]}; it ships no catches (DATA-R31)")
    sources = [source for source, target in aliases.items() if target == area]
    if sources:
        lines.append(f"  alias: the target of {', '.join(str(one) for one in sorted(sources))} in {ALIASES}")
    lines.append(f"  skill base: {_skill_base(layers, area)}")
    record = catalogue_of(layers)["areas"][area]
    lines.append(f"  hasData = {_lower(record['hasData'] is True)}")
    history = layers.catch_lists.history.get(area, {})
    if not history:
        lines.append("  catch list: empty")
        return lines
    lines.append("  catch list (DATA-R26), each entry with its source:")
    for item, steps in sorted(history.items()):
        lines.append(f"    item {item}: {'; '.join(steps)} -> {_entry_result(layers, area, item)}")
    return lines
