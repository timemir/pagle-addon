"""The data/forever/ layer (DATA-R8 order 2, DATA-R10), as far as the generator reads it so far: the event list
(events.toml, DATA-R38), the fishing-aura and fishing-spell lists (lists.toml, DATA-R39) and the alias table
(aliases.toml, DATA-R32). Keys and types are the Data section's in docs/spec/content-data.md.
"""

from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.toml_reader import (
    At,
    Problems,
    check_keys,
    describe,
    expect_ids,
    expect_int,
    expect_table,
    expect_why,
    parse_id,
    read_toml,
)

EVENTS = "data/forever/events.toml"
LISTS = "data/forever/lists.toml"
ALIASES = "data/forever/aliases.toml"

# A weekly rule's keys (DATA-R38) and the range of each: weekday 1 (Sunday) to 7, start a minute of the day,
# duration at least a minute.
_RULE_BOUNDS: dict[str, tuple[int, int | None]] = {"weekday": (1, 7), "start": (0, 1439), "duration": (1, None)}
_RULE_KEYS = tuple(_RULE_BOUNDS)


@dataclass(frozen=True)
class WeeklyRule:
    """An event's weekly rule (DATA-R38), in realm time."""

    weekday: int  # 1 = Sunday
    start: int  # minute of the day
    duration: int  # minutes


@dataclass(frozen=True)
class Alias:
    """An [[alias]] entry (DATA-R32): area source stands for the baseline fishing area target; why is the evidence
    (DATA-R10). at names the entry, for a problem found later."""

    source: int
    target: int
    why: str
    at: At


@dataclass
class ForeverLayer:
    events: dict[int, WeeklyRule | None] = field(default_factory=dict)
    auras: list[int] = field(default_factory=list)
    fishing_spells: list[int] = field(default_factory=list)
    aliases: list[Alias] = field(default_factory=list)


def _read_rule(entry: object, at: At, problems: Problems) -> WeeklyRule | None:
    """An [event.<eventID>] table's weekly rule: all three keys or none (DATA-R10's Data section)."""
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=(), optional=_RULE_KEYS)
    values: dict[str, int] = {}
    for key, (minimum, maximum) in _RULE_BOUNDS.items():
        if key in table:
            value = expect_int(table[key], at / key, problems, minimum=minimum, maximum=maximum)
            if value is not None:
                values[key] = value
    missing = [key for key in _RULE_KEYS if key not in table]
    if missing and len(missing) < len(_RULE_KEYS):
        problems.add(at, f"a weekly rule sets weekday, start and duration together; missing {', '.join(missing)}")
    if len(values) < len(_RULE_KEYS):
        return None
    return WeeklyRule(values["weekday"], values["start"], values["duration"])


def _read_events(root: Path, layer: ForeverLayer, problems: Problems) -> None:
    document = read_toml(root, EVENTS, problems)
    if document is None:
        return
    at = At(EVENTS)
    check_keys(document, at, problems, required=(), optional=("event",))
    events = expect_table(document.get("event", {}), at / "event", problems)
    for key, entry in (events or {}).items():
        event_at = at / "event" / key
        event_id = parse_id(key, event_at, problems)
        rule = _read_rule(entry, event_at, problems)
        if event_id is not None:
            layer.events[event_id] = rule


def _read_lists(root: Path, layer: ForeverLayer, problems: Problems) -> None:
    document = read_toml(root, LISTS, problems)
    if document is None:
        return
    at = At(LISTS)
    check_keys(document, at, problems, required=("auras", "fishingSpells"), optional=())
    if "auras" in document:
        layer.auras = expect_ids(document["auras"], at / "auras", problems) or []
    if "fishingSpells" in document:
        layer.fishing_spells = expect_ids(document["fishingSpells"], at / "fishingSpells", problems) or []


def _read_alias(entry: object, at: At, problems: Problems) -> Alias | None:
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=("from", "to", "why"), optional=())
    source = expect_int(table["from"], at / "from", problems, minimum=1) if "from" in table else None
    target = expect_int(table["to"], at / "to", problems, minimum=1) if "to" in table else None
    why = expect_why(table, at, problems)
    if source is None or target is None or why is None:
        return None
    return Alias(source, target, why, at)


def _read_aliases(root: Path, layer: ForeverLayer, problems: Problems) -> None:
    document = read_toml(root, ALIASES, problems)
    if document is None:
        return
    at = At(ALIASES)
    check_keys(document, at, problems, required=(), optional=("alias",))
    entries = document.get("alias", [])
    if not isinstance(entries, list):
        problems.add(at / "alias", f"expected an array of tables ([[alias]]), got {describe(entries)}")
        return
    sources: set[int] = set()
    for index, entry in enumerate(entries):
        read = _read_alias(entry, At(ALIASES, f"alias[{index}]"), problems)
        if read is None:
            continue
        if read.source in sources:
            problems.add(read.at / "from", f"area {read.source} is aliased twice")
            continue
        sources.add(read.source)
        layer.aliases.append(read)


def read_forever(root: Path, problems: Problems) -> ForeverLayer:
    """The layer under root/data/forever/. Each problem found goes into problems; what was read is returned
    either way, and the caller must not use it while there are problems."""
    layer = ForeverLayer()
    _read_events(root, layer, problems)
    _read_lists(root, layer, problems)
    _read_aliases(root, layer, problems)
    return layer
