"""Fish varieties (VAR-R2, VAR-R4, VAR-R5, DATA-R131-R135): data/forever/varieties.toml, each sized, non-Legend
Species' ten variety keys in frozen order, emitted on each Species item as varieties; data/forever/varieties.lock,
the shipped keys the generator checks them against; and the checks on the varieties' and fish crests' lore: that it
covers exactly these varieties and Species, and that it names no game place or fish (DATA-R3).

A variety's ID is <speciesID>.<key>; its rarity is its position (VAR-R2), so a key and its position never change once
shipped (VAR-R5), while its name, description and art may.
"""

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.db2 import Db2Layer
from pagle_data.errors import At, Problems
from pagle_data.items import Record
from pagle_data.lore import MANIFEST, LoreLayer, Text, lore_file
from pagle_data.toml_reader import check_keys, describe, expect_table, parse_id, read_toml

VARIETIES_TOML = "data/forever/varieties.toml"
VARIETIES_LOCK = "data/forever/varieties.lock"

# Tunables: varieties per Species (VAR-R2, frozen).
VARIETY_COUNT = 10
# VAR-R2: a key is lowercase letters and digits joined by single hyphens, so <speciesID>.<key> is one lore ID.
_KEY = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")

# The lock's header comment, the top of the committed file (DATA-R73), as released.lock's.
LOCK_HEADER = f"""\
# The varieties lock (VAR-R5, DATA-R133): each shipped Species' ten variety keys, in their frozen order. Written by
# scripts/generate-data.py --lock beside data/hunts/released.lock; don't edit it by hand.
# Run --lock only when a release is tagged, from 1.0 on, and never before: the 1.0 release commit wrote the first
# (DATA-R73). The generator fails when {VARIETIES_TOML} changes, moves or drops a key it holds.
"""

# Core's lore kinds the varieties need (DATA-R134): each variety's name and description, and the fish crests, Core's
# goods core.crest.fish.<speciesID>, whose one name pattern fills {fish} with the Species' item name at runtime.
VARIETY_KIND = "variety"
GOOD_KIND = "good"
FISH_CREST = "core.crest.fish."
FISH = "fish"
FISH_CREST_NAME = "{fish} Crest"


@dataclass(frozen=True)
class Varieties:
    """One [varieties.<speciesID>] table: its keys as read, in order, and where it is."""

    keys: tuple[str, ...]
    at: At


@dataclass
class VarietyLayer:
    """varieties.toml's tables by Species ID, and varieties.lock's (empty when absent)."""

    species: dict[int, Varieties] = field(default_factory=dict)
    locked: dict[int, Varieties] = field(default_factory=dict)

    def ids(self) -> list[str]:
        """Every variety ID, <speciesID>.<key>, by Species ID then position."""
        return [f"{species}.{key}" for species, entry in sorted(self.species.items()) for key in entry.keys]


def _read_file(root: Path, file: str, problems: Problems) -> dict[int, Varieties]:
    """The [varieties.<speciesID>] tables of root/file by Species ID, each with keys = [...] (DATA-R63: an unknown
    key or a wrong type fails). A key's shape is checked here; the count and repeats are check_varieties'."""
    document = read_toml(root, file, problems)
    if document is None:
        return {}
    at = At(file)
    check_keys(document, at, problems, required=(), optional=("varieties",))
    tables = expect_table(document.get("varieties", {}), at / "varieties", problems)
    found: dict[int, Varieties] = {}
    for name, entry in (tables or {}).items():
        entry_at = At(file, f"varieties.{name}")
        species = parse_id(name, entry_at, problems)
        table = expect_table(entry, entry_at, problems)
        if species is None or table is None:
            continue
        check_keys(table, entry_at, problems, required=("keys",), optional=())
        value = table.get("keys", [])
        if not isinstance(value, list):
            problems.add(entry_at / "keys", f"expected an array of keys, got {describe(value)}")
            continue
        keys: list[str] = []
        for index, key in enumerate(value):
            if not isinstance(key, str) or not _KEY.fullmatch(key):
                shown = f"'{key}'" if isinstance(key, str) else describe(key)
                joined = "lowercase letters and digits joined by hyphens"
                problems.add(At(file, f"varieties.{name}.keys[{index}]"), f"a key is {joined} (VAR-R2), got {shown}")
            else:
                keys.append(key)
        found[species] = Varieties(tuple(keys), entry_at)
    return found


def read_varieties(root: Path, problems: Problems) -> VarietyLayer:
    """root/data/forever/varieties.toml and varieties.lock, each read as empty when absent: no varieties, and a lock
    that checks nothing (DATA-R73)."""
    layer = VarietyLayer()
    if (root / VARIETIES_TOML).is_file():
        layer.species = _read_file(root, VARIETIES_TOML, problems)
    if (root / VARIETIES_LOCK).is_file():
        layer.locked = _read_file(root, VARIETIES_LOCK, problems)
    return layer


def variety_species(items: Mapping[int, Record]) -> set[int]:
    """The Species that have varieties (VAR-R1): each sized (a typical length, DATA-R20) Species ID whose item isn't a
    Legend. A Noise item is never a Species item (DATA-R16, DATA-R19)."""
    return {
        item
        for item, record in items.items()
        if record.get("species") == item and record.get("legend") is not True and "typicalLength" in record
    }


def check_varieties(layer: VarietyLayer, items: Mapping[int, Record], required: bool, problems: Problems) -> None:
    """VAR-R2: an entry for anything but a sized, non-Legend Species, other than ten keys, or a key repeated within a
    Species; with the varieties switch on (DATA-R66, required), a sized non-Legend Species with no entry. VAR-R5:
    against the lock, a shipped Species gone or a key changed or moved."""
    needed = variety_species(items)
    for species, entry in sorted(layer.species.items()):
        if species not in needed:
            none = "isn't a sized, non-Legend Species, so it has no varieties"
            problems.add(entry.at, f"{species} {none} (VAR-R1, VAR-R2)")
        if len(entry.keys) != VARIETY_COUNT:
            problems.add(entry.at / "keys", f"{len(entry.keys)} keys; a Species has exactly ten varieties (VAR-R2)")
        seen: set[str] = set()
        for key in entry.keys:
            if key in seen:
                own = "each of a Species' ten keys is its own"
                problems.add(entry.at / "keys", f"'{key}' is listed twice; {own} (VAR-R2)")
            seen.add(key)
    if required:
        for species in sorted(needed - layer.species.keys()):
            message = f"Species {species} is sized and not a Legend, so it needs its ten varieties (VAR-R2, DATA-R132)"
            problems.add(At(VARIETIES_TOML), message)
    for species, locked in sorted(layer.locked.items()):
        current = layer.species.get(species)
        if current is None:
            gone = f"the shipped Species' varieties are gone from {VARIETIES_TOML}"
            problems.add(locked.at, f"{gone}; a Species keeps its ten, removed or not (VAR-R5)")
            continue
        for index, key in enumerate(locked.keys):
            now = current.keys[index] if index < len(current.keys) else None
            if now != key:
                shown = f"is '{now}'" if now is not None else "is gone"
                shipped = f"but '{key}' shipped there ({VARIETIES_LOCK})"
                never = "a shipped variety's key and position never change (VAR-R5)"
                problems.add(current.at / "keys", f"position {index + 1} {shown}, {shipped}; {never}")


def with_varieties(items: Mapping[int, Record], layer: VarietyLayer) -> dict[int, Record]:
    """The records with varieties (VAR-R4), each Species' keys in order, on every item of a Species that has an entry,
    as its typical length is (DATA-R20)."""
    out: dict[int, Record] = {}
    for item, record in items.items():
        species = record.get("species")
        entry = layer.species.get(species) if isinstance(species, int) else None
        out[item] = record if entry is None else {**record, "varieties": list(entry.keys)}
    return out


def varieties_lock_toml(layer: VarietyLayer) -> str:
    """varieties.lock for varieties.toml, every Species in it counting as shipped (VAR-R5): [varieties.<speciesID>]
    with its keys in order, by ascending Species ID (DATA-R62), after the header."""
    tables = [
        f"[varieties.{species}]\nkeys = [{', '.join(f'"{key}"' for key in entry.keys)}]\n"
        for species, entry in sorted(layer.species.items())
    ]
    return LOCK_HEADER + "".join(f"\n{table}" for table in tables)


def check_variety_lore(layer: VarietyLayer, lore: LoreLayer, problems: Problems) -> None:
    """DATA-R134, with Core's lore check on: manifest.toml's [core.variety] lists exactly varieties.toml's IDs, and
    [core.good] a fish crest core.crest.fish.<speciesID> for exactly its Species (VAR-R12), each allowing {fish}, which
    no other entry allows (DATA-R108). Each fish crest's name is the one pattern "{fish} Crest", and its description
    never has {fish}: it never names the fish."""
    kinds = lore.manifest.get("core", {})
    variety = kinds.get(VARIETY_KIND)
    listed = list(variety.ids) if variety is not None else []
    wanted = layer.ids()
    at = At(MANIFEST, f"core.{VARIETY_KIND}") / "ids"
    for id_ in sorted(set(wanted) - set(listed)):
        problems.add(at, f"'{id_}' is a variety in {VARIETIES_TOML} but isn't listed (VAR-R11, DATA-R134)")
    for id_ in sorted(set(listed) - set(wanted)):
        problems.add(at, f"'{id_}' isn't a variety in {VARIETIES_TOML} (VAR-R11, DATA-R134)")
    good = kinds.get(GOOD_KIND)
    goods = good.ids if good is not None else {}
    crests = {id_: allowed for id_, allowed in goods.items() if id_.startswith(FISH_CREST)}
    good_at = At(MANIFEST, f"core.{GOOD_KIND}") / "ids"
    species = {f"{FISH_CREST}{species}" for species in layer.species}
    for id_ in sorted(species - crests.keys()):
        problems.add(good_at, f"'{id_}' is missing: each Species with varieties has a fish crest (VAR-R12, DATA-R134)")
    for id_ in sorted(crests.keys() - species):
        problems.add(good_at, f"'{id_}' isn't a fish crest of a Species in {VARIETIES_TOML} (VAR-R12, DATA-R134)")
    for id_, allowed in sorted(crests.items()):
        if allowed != {FISH}:
            problems.add(good_at, f"'{id_}' must allow {{fish}} and only it, for its name (VAR-R12, DATA-R108)")
    for lore_id, by_kind in sorted(lore.manifest.items()):
        for kind, entry in sorted(by_kind.items()):
            for id_, allowed in entry.ids.items():
                if FISH in allowed and not (lore_id == "core" and kind == GOOD_KIND and id_.startswith(FISH_CREST)):
                    only = "only a fish crest's entry allows {fish} (VAR-R12, DATA-R108)"
                    problems.add(At(MANIFEST, f"{lore_id}.{kind}") / "ids", f"'{id_}': {only}")
    texts = lore.files.get("core", {})
    file = lore_file("core")
    for id_ in sorted(crests.keys() & species):
        name = texts.get(f"{GOOD_KIND}.{id_}.name")
        if name is not None and name.value != FISH_CREST_NAME:
            pattern = f'a fish crest\'s name is the one pattern "{FISH_CREST_NAME}"'
            problems.add(At(file, name.key), f"{pattern}, got '{name.value}' (VAR-R12, DATA-R134)")
        description = texts.get(f"{GOOD_KIND}.{id_}.description")
        if description is not None and "{" + FISH + "}" in description.value:
            never = "a fish crest's description never names the fish"
            problems.add(At(file, description.key), f"{{fish}} in it; {never} (VAR-R12, DATA-R134)")


def _phrases(names: Iterable[str], flags: int) -> re.Pattern[str] | None:
    """Any of names as whole words (not inside a longer word on either side), the longest first, or None for none."""
    ordered = sorted(set(names), key=lambda name: (-len(name), name))
    if not ordered:
        return None
    return re.compile(rf"(?<!\w)(?:{'|'.join(re.escape(name) for name in ordered)})(?!\w)", flags)


@dataclass(frozen=True)
class GameNames:
    """The names no variety or fish crest lore may hold (DATA-R3, DATA-R135): every area's enUS name, matched with its
    capitals, so plain words like "mine shaft" pass, and every Species item's enUS name and that name without a
    leading "Raw ", matched ignoring case."""

    areas: tuple[str, ...]
    fish: tuple[str, ...]
    _areas: re.Pattern[str] | None = field(init=False, repr=False, compare=False)
    _fish: re.Pattern[str] | None = field(init=False, repr=False, compare=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "_areas", _phrases(self.areas, 0))
        object.__setattr__(self, "_fish", _phrases(self.fish, re.IGNORECASE))

    def found(self, text: str) -> list[str]:
        """The names text holds, areas first, each once, as the text writes them."""
        named: list[str] = []
        for pattern in (self._areas, self._fish):
            for match in pattern.finditer(text) if pattern is not None else ():
                if match.group(0) not in named:
                    named.append(match.group(0))
        return named


def game_names(db2: Db2Layer, items: Mapping[int, Record]) -> GameNames:
    """The names lore may not hold: every areas.csv row's (zones and subzones alike, DATA-R25) and each Species item's
    from items.csv, legends and folded items too (DATA-R19)."""
    areas = sorted({area.name for area in db2.areas.values() if area.name.strip()})
    fish: set[str] = set()
    for item, record in items.items():
        known = db2.items.get(item)
        if "species" in record and known is not None and known.name:
            fish.add(known.name)
            if known.name.startswith("Raw "):
                fish.add(known.name.removeprefix("Raw "))
    return GameNames(tuple(areas), tuple(sorted(fish)))


def _variety_texts(texts: Iterable[Text]) -> list[Text]:
    """Core's texts DATA-R135's name check reads: each variety's, and each fish crest's."""
    return [
        text
        for text in texts
        if text.kind == VARIETY_KIND or (text.kind == GOOD_KIND and text.id.startswith(FISH_CREST))
    ]


def check_game_names(lore: LoreLayer, names: GameNames, problems: Problems) -> None:
    """DATA-R135 (DATA-R3): a variety's or a fish crest's text that holds an area's name or a Species item's name
    fails, naming the key and the name. {fish}, filled at runtime, is left out of the match."""
    texts = lore.files.get("core", {})
    file = lore_file("core")
    for text in sorted(_variety_texts(texts.values()), key=lambda text: text.key.encode("utf-8")):
        value = text.value.replace("{" + FISH + "}", "")
        for name in names.found(value):
            problems.add(At(file, text.key), f"holds the game name '{name}'; no game name ships (DATA-R3, DATA-R135)")

