"""The data/baseline/ layer (DATA-R8 order 1, DATA-R9): the VMaNGOS snapshot's CSVs and source.toml."""

BASELINE = "data/baseline"
SOURCE = f"{BASELINE}/source.toml"

# Each CSV and its columns, in DATA-R9's order.
COLUMNS: dict[str, tuple[str, ...]] = {
    "area_loot.csv": ("area", "item", "chance", "ref", "event", "condition"),
    "reference_loot.csv": ("ref", "item", "chance"),
    "pools.csv": ("entry", "name", "event"),
    "pool_loot.csv": ("entry", "item", "chance", "ref"),
    "skill.csv": ("area", "skillBase"),
    "events.csv": ("event", "start", "occurrence", "length", "description"),
}
