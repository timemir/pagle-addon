"""Lore (DATA-R100-R109): data/lore/<lore ID>.toml and manifest.toml, each addon's Lore.lua, and the lore check.

Lore is display text only. It is never in the catalogue or its fingerprint and changes no count (DATA-R109), so
nothing here feeds the catalogue: the lore check reads the item records and the families, never the other way round.

From 1.1 a translation of Lore (DATA-R104, DATA-R114) is data/lore/<code>/<lore ID>.toml, read into LoreLayer.translations
and nowhere else: no English check, no English Lore.lua and no catalogue ever sees it. Each translated field is a table
of `value` and `en` (the EN snapshot), and the generator writes it as addons/<Addon>/data/Lore.<code>.lua.
"""

import re
from collections.abc import Callable, Collection, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.glyphs import ENGLISH, glyphs_for
from pagle_data.items import Record
from pagle_data.lua import to_lua
from pagle_data.toml_reader import check_keys, describe, expect_table, read_toml
from pagle_data.universe import EVENTS_DIR, HUNTS_TOML

LORE = "data/lore"
MANIFEST = f"{LORE}/manifest.toml"

# DATA-R100: each lore ID's file and the addon whose Lore.lua it becomes (DATA-R75).
ADDONS = {
    "core": "Pagle",
    "ledger": "Pagle_Ledger",
    "hunts": "Pagle_Hunts",
    "stats": "Pagle_Stats",
    "tackleboard": "Pagle_TackleBoard",
}


@dataclass(frozen=True)
class CatalogueIds:
    """What the catalogue-keyed kinds are keyed by (DATA-R103), from the item records and families.toml."""

    species: frozenset[int] = frozenset()  # Species IDs whose item isn't a Legend (LED-R4 in M3)
    legends: frozenset[int] = frozenset()
    subs: frozenset[int] = frozenset()  # non-Noise junk, container and treasure items
    families: frozenset[int] = frozenset()


@dataclass(frozen=True)
class CatalogueKind:
    """A kind keyed by catalogue IDs (DATA-R103): its fields, the IDs that need them, why each of those does
    (DATA-R107's missing), and what an ID outside them isn't (DATA-R107's orphan)."""

    fields: tuple[str, ...]
    ids: Callable[[CatalogueIds], frozenset[int]]
    missing: str
    orphan: str


# DATA-R103: the kinds keyed by catalogue IDs, all the Ledger's, one entry each.
CATALOGUE_KINDS: dict[str, CatalogueKind] = {
    "species": CatalogueKind(
        ("blurb", "riddle"),
        lambda ids: ids.species,
        "every Species needs it (DATA-R103, DATA-R107)",
        "isn't a Species ID (DATA-R19, DATA-R107)",
    ),
    "legend": CatalogueKind(
        ("blurb", "title"),
        lambda ids: ids.legends,
        "every Legend needs it (DATA-R103, DATA-R107)",
        "isn't a Legend (DATA-R22, DATA-R107)",
    ),
    "sub": CatalogueKind(
        ("plaque",),
        lambda ids: ids.subs,
        "every non-Noise junk, container and treasure item needs it (DATA-R103, DATA-R107)",
        "isn't a non-Noise junk, container or treasure item (DATA-R103, DATA-R107)",
    ),
    "family": CatalogueKind(
        ("name",),
        lambda ids: ids.families,
        "every family in data/forever/families.toml needs it (DATA-R103, DATA-R107)",
        "isn't a family in data/forever/families.toml (DATA-R21, DATA-R107)",
    ),
}
CATALOGUE_OWNER = "ledger"
# DATA-R105, DATA-R97: the text of Hunts, Hunt sets and Hunt Events, Pagle_Hunts' kinds, kept beside their
# definitions in data/hunts/hunts.toml and data/hunts/events/, and never in the manifest.
HUNTS_KINDS = ("hunt", "set", "event")
HUNTS_OWNER = "hunts"

# DATA-R101: a kind is lowercase letters; a field is the last dot-separated segment of a key.
_KIND = re.compile(r"[a-z]+")
_FIELD = re.compile(r"[a-z][A-Za-z0-9]*")
# DATA-R108: the placeholders: {zone}, and {fish} in a fish crest's name (VAR-R12, DATA-R134).
PLACEHOLDERS = ("zone", "fish")
_PLACEHOLDER = re.compile("|".join(re.escape("{" + name + "}") for name in PLACEHOLDERS))
# DATA-R114: a Locale's code is the client's full one, and English Lore is data/lore/*.toml, not a directory.
_CODE = re.compile(r"[a-z]{2}[A-Z]{2}")
ENGLISH_CODE = "enUS"


def lore_file(lore_id: str) -> str:
    return f"{LORE}/{lore_id}.toml"


def lore_lua(lore_id: str) -> str:
    """The Lore.lua a lore ID's text is emitted into (DATA-R75)."""
    return f"addons/{ADDONS[lore_id]}/data/Lore.lua"


def translation_file(code: str, lore_id: str) -> str:
    """A Locale's translation of a lore ID's file (DATA-R114)."""
    return f"{LORE}/{code}/{lore_id}.toml"


def translation_lua(code: str, lore_id: str) -> str:
    """The Lore.<code>.lua a translated lore file is emitted into (DATA-R75, DATA-R114)."""
    return f"addons/{ADDONS[lore_id]}/data/Lore.{code}.lua"


@dataclass(frozen=True)
class Text:
    """One lore key's text as a lore file writes it: [<kind>.<id>] <field> = "<value>" (DATA-R101)."""

    kind: str
    id: str
    field: str
    value: str

    @property
    def key(self) -> str:
        return f"{self.kind}.{self.id}.{self.field}"


@dataclass(frozen=True)
class ManifestKind:
    """A Module-defined kind in manifest.toml (DATA-R106): its required fields, and each ID that needs them with the
    placeholders that ID allows."""

    fields: tuple[str, ...]
    ids: dict[str, frozenset[str]]


@dataclass
class Translation:
    """One translated lore file, data/lore/<code>/<lore ID>.toml (DATA-R114): the translated texts by key, and beside
    each the EN snapshot, the English it was translated from."""

    texts: dict[str, Text] = field(default_factory=dict)
    snapshots: dict[str, str] = field(default_factory=dict)


@dataclass
class LoreLayer:
    """data/lore/ as read: each lore file present, by lore ID, with its texts by key, and the manifest's kinds by
    lore ID and kind. hunts holds the Hunt and set text of data/hunts/hunts.toml by key (DATA-R105), and events each
    event file's text by file and key (DATA-R97): Pagle_Hunts' lore that stays beside its definitions; the generator
    sets them from the Hunt and event layers."""

    files: dict[str, dict[str, Text]] = field(default_factory=dict)
    manifest: dict[str, dict[str, ManifestKind]] = field(default_factory=dict)
    unreadable: set[str] = field(default_factory=set)  # lore IDs whose file isn't valid TOML
    hunts: dict[str, Text] = field(default_factory=dict)
    events: dict[str, dict[str, Text]] = field(default_factory=dict)
    translations: dict[str, dict[str, Translation]] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)

    def hunts_sources(self) -> list[tuple[str, dict[str, Text]]]:
        """Pagle_Hunts' lore kept beside its definitions, by file: hunts.toml's, then each event file's in order."""
        return [(HUNTS_TOML, self.hunts), *sorted(self.events.items())]


def _translated(value: object, at: At, problems: Problems) -> tuple[str, str] | None:
    """A translated field (DATA-R114): a table of exactly `value`, the translation, and `en`, the EN snapshot, both
    strings; or None with a problem."""
    if not isinstance(value, dict) or set(value) != {"value", "en"}:
        shown = describe(value) if not isinstance(value, dict) else "a table with " + ", ".join(sorted(value))
        want = "a translated field is a table with `value` and `en` (the EN snapshot)"
        problems.add(at, f"shape: {want}, got {shown} (DATA-R114)")
        return None
    for name in ("value", "en"):
        if not isinstance(value[name], str):
            problems.add(at / name, f"shape: expected a string, got {describe(value[name])} (DATA-R114)")
            return None
    return value["value"], value["en"]


def _read_texts(
    root: Path, file: str, problems: Problems, snapshots: dict[str, str] | None = None
) -> dict[str, Text] | None:
    """A lore file's tables, one per <kind>.<id>, each holding its fields as strings (DATA-R101), or None when it
    isn't valid TOML. Only the shape is checked here; what the text says is the lore check's (DATA-R107). With
    snapshots, the file is a Locale's (DATA-R114): each field is a table of `value` and `en`, and the EN snapshots are
    put into snapshots by key."""
    document = read_toml(root, file, problems)
    if document is None:
        return None
    texts: dict[str, Text] = {}
    for kind, ids in document.items():
        kind_at = At(file, kind)
        if not _KIND.fullmatch(kind):
            problems.add(kind_at, f"a kind is lowercase letters (DATA-R101), got '{kind}'")
            continue
        table = expect_table(ids, kind_at, problems)
        for id_, fields in (table or {}).items():
            id_at = At(file, f"{kind}.{id_}")
            if not id_:
                problems.add(id_at, "an empty ID (DATA-R101)")
                continue
            entry = expect_table(fields, id_at, problems)
            for name, value in (entry or {}).items():
                at = At(file, f"{kind}.{id_}.{name}")
                if not _FIELD.fullmatch(name):
                    problems.add(at, f"a field is a lowercase name without dots (DATA-R101), got '{name}'")
                elif snapshots is not None:
                    pair = _translated(value, at, problems)
                    if pair is not None:
                        text = Text(kind, id_, name, pair[0])
                        texts[text.key] = text
                        snapshots[text.key] = pair[1]
                elif not isinstance(value, str):
                    problems.add(at, f"expected a string, got {describe(value)}")
                else:
                    text = Text(kind, id_, name, value)
                    texts[text.key] = text
    return texts


def _read_ids(value: object, at: At, problems: Problems) -> dict[str, frozenset[str]]:
    """A manifest kind's ids: each an ID string, or { id = "<ID>", placeholders = [...] } (DATA-R106)."""
    ids: dict[str, frozenset[str]] = {}
    if not isinstance(value, list):
        problems.add(at, f"expected an array of IDs, got {describe(value)}")
        return ids
    for index, item in enumerate(value):
        item_at = At(at.file, f"{at.path}[{index}]")
        allowed: list[str] = []
        if isinstance(item, dict):
            check_keys(item, item_at, problems, required=("id",), optional=("placeholders",))
            id_ = item.get("id")
            placeholders = item.get("placeholders", [])
            if not isinstance(placeholders, list):
                problems.add(item_at / "placeholders", f"expected an array, got {describe(placeholders)}")
                placeholders = []
            for name in placeholders:
                if name not in PLACEHOLDERS:
                    shown = f"'{name}'" if isinstance(name, str) else describe(name)
                    only = "{zone} and {fish} are the only placeholders (DATA-R108)"
                    problems.add(item_at / "placeholders", f"{only}, got {shown}")
                else:
                    allowed.append(name)
        else:
            id_ = item
        if not isinstance(id_, str) or not id_:
            shown = "an empty string" if id_ == "" else describe(id_)
            problems.add(item_at, f"expected an ID string, or a table with one as id, got {shown}")
        elif id_ in ids:
            problems.add(item_at, f"'{id_}' is listed twice")
        else:
            ids[id_] = frozenset(allowed)
    return ids


def _read_fields(value: object, at: At, problems: Problems) -> tuple[str, ...]:
    if not isinstance(value, list) or not value:
        problems.add(at, f"expected a non-empty array of field names, got {describe(value)}")
        return ()
    fields: list[str] = []
    for index, name in enumerate(value):
        item_at = At(at.file, f"{at.path}[{index}]")
        if not isinstance(name, str) or not _FIELD.fullmatch(name):
            shown = f"'{name}'" if isinstance(name, str) else describe(name)
            problems.add(item_at, f"expected a field name without dots (DATA-R101), got {shown}")
        elif name in fields:
            problems.add(item_at, f"'{name}' is listed twice")
        else:
            fields.append(name)
    return tuple(fields)


def _read_manifest(root: Path, problems: Problems) -> dict[str, dict[str, ManifestKind]]:
    """manifest.toml (DATA-R106): [<lore ID>.<kind>] with fields and ids. Each kind belongs to one addon
    (DATA-R102), and the catalogue-keyed kinds and Hunts' own are never listed (DATA-R103, DATA-R105). A missing
    manifest defines no kind."""
    manifest: dict[str, dict[str, ManifestKind]] = {}
    if not (root / MANIFEST).exists():
        return manifest
    document = read_toml(root, MANIFEST, problems)
    owners: dict[str, str] = {}
    for lore_id, kinds in (document or {}).items():
        lore_at = At(MANIFEST, lore_id)
        if lore_id not in ADDONS:
            problems.add(lore_at, f"expected a lore ID ({', '.join(ADDONS)}), got '{lore_id}'")
            continue
        for kind, entry in (expect_table(kinds, lore_at, problems) or {}).items():
            at = lore_at / kind
            if not _KIND.fullmatch(kind):
                problems.add(at, f"a kind is lowercase letters (DATA-R101), got '{kind}'")
                continue
            if kind in CATALOGUE_KINDS or kind in HUNTS_KINDS:
                rule = "DATA-R103" if kind in CATALOGUE_KINDS else "DATA-R105"
                problems.add(at, f"{kind} is a kind the spec defines, never listed in the manifest ({rule})")
                continue
            if kind in owners:
                one = "each kind belongs to one addon (DATA-R102)"
                problems.add(at, f"{kind} already belongs to {owners[kind]}; {one}")
                continue
            table = expect_table(entry, at, problems)
            if table is None:
                continue
            check_keys(table, at, problems, required=("fields", "ids"), optional=())
            owners[kind] = lore_id
            # A missing key is check_keys' problem; only one that is there is read.
            fields = _read_fields(table["fields"], at / "fields", problems) if "fields" in table else ()
            ids = _read_ids(table["ids"], at / "ids", problems) if "ids" in table else {}
            manifest.setdefault(lore_id, {})[kind] = ManifestKind(fields, ids)
    return manifest


def _read_translations(root: Path, layer: LoreLayer, problems: Problems) -> None:
    """root/data/lore/<code>/<lore ID>.toml for each Locale directory (DATA-R114) into layer.translations. A directory
    that is not a Locale's code, English's, one with no glyph range, or a file in it that is not a lore ID's, is a
    problem."""
    for directory in sorted(path for path in (root / LORE).iterdir() if path.is_dir()):
        code = directory.name
        at = At(f"{LORE}/{code}")
        if code == ENGLISH_CODE:
            problems.add(at, f"English Lore is {LORE}/*.toml, never a directory of its own (DATA-R104, DATA-R114)")
            continue
        if not _CODE.fullmatch(code):
            problems.add(at, "a Locale's directory is its full client code, like esES (DATA-R114)")
            continue
        try:
            glyphs_for(code)
        except ValueError as error:
            problems.add(at, f"no range for the Locale (CORE-R9, DATA-R114): {error}")
            continue
        known = {f"{lore_id}.toml" for lore_id in ADDONS}
        for path in sorted(directory.iterdir()):
            if path.name not in known:
                named = f"a Locale's lore files are named by lore ID ({', '.join(ADDONS)})"
                problems.add(At(f"{LORE}/{code}/{path.name}"), f"not a lore file; {named} (DATA-R114)")
        for lore_id in ADDONS:
            file = translation_file(code, lore_id)
            if (root / file).is_file():
                translation = Translation()
                texts = _read_texts(root, file, problems, translation.snapshots)
                if texts is not None:
                    translation.texts = texts
                    layer.translations.setdefault(code, {})[lore_id] = translation


def read_lore(root: Path, problems: Problems) -> LoreLayer:
    """root/data/lore/: each lore ID's file that exists, and the manifest. Each problem in a file's shape goes into
    problems (DATA-R63); the layer read is returned either way. A .toml file there that is neither a lore ID's nor
    the manifest is a problem too. A directory there is a Locale's translation (DATA-R114)."""
    layer = LoreLayer(manifest=_read_manifest(root, problems))
    directory = root / LORE
    if not directory.is_dir():
        return layer
    known = {f"{lore_id}.toml" for lore_id in ADDONS} | {Path(MANIFEST).name}
    for path in sorted(directory.glob("*.toml")):
        if path.name not in known:
            named = f"lore files are named by lore ID ({', '.join(ADDONS)})"
            problems.add(At(f"{LORE}/{path.name}"), f"not a lore file; {named}")
    for lore_id in ADDONS:
        if (root / lore_file(lore_id)).exists():
            texts = _read_texts(root, lore_file(lore_id), problems)
            if texts is None:
                layer.unreadable.add(lore_id)
            else:
                layer.files[lore_id] = texts
    _read_translations(root, layer, problems)
    return layer


def has_text(value: str) -> bool:
    """A value that is text, not empty (DATA-R107's missing)."""
    return bool(value.strip())


SUB_CATEGORIES = frozenset({"junk", "container", "treasure"})


def catalogue_ids(items: Mapping[int, Record], families: Collection[int]) -> CatalogueIds:
    """The IDs DATA-R103's kinds need text for, removed items included. In M3 a Legend is still its category's item
    (LED-R4), so a Legend fish is a Species item; for lore it needs legend text only, so it isn't counted as a
    Species here. A Noise item ships as other (DATA-R16), so it is never a junk, container or treasure item."""
    legends = frozenset(item for item, record in items.items() if record.get("legend") is True)
    species = frozenset(item for item, record in items.items() if record.get("species") == item) - legends
    subs = frozenset(item for item, record in items.items() if record.get("category") in SUB_CATEGORIES)
    return CatalogueIds(species, legends, subs, frozenset(families))


def _owner(layer: LoreLayer, kind: str) -> str | None:
    """The lore ID that owns kind (DATA-R102): the Ledger the catalogue-keyed kinds, Hunts its Hunts and sets, and
    the manifest every other kind."""
    if kind in CATALOGUE_KINDS:
        return CATALOGUE_OWNER
    if kind in HUNTS_KINDS:
        return HUNTS_OWNER
    for lore_id, kinds in layer.manifest.items():
        if kind in kinds:
            return lore_id
    return None


def _possessive(name: str) -> str:
    return f"{name}'" if name.endswith("s") else f"{name}'s"


def _catalogue_id(id_: str) -> int | None:
    return int(id_) if id_.isascii() and id_.isdecimal() and not id_.startswith("0") else None


# Tunables › Lore limits (DATA-R107), in Unicode code points. By field name, in whatever kind: "title" here is a
# Legend's title field (DATA-R103), and "name" every kind's name field.
FIELD_LIMITS = {"riddle": 80, "blurb": 200, "plaque": 100, "name": 28, "title": 32}
# By (kind, field), for one kind's field only: the text of a title, the Ledger's Module-defined title kind and the
# Tackle Board's boardtitle (DATA-R106, TKB-R130), and a fish variety's description (VAR-R11, DATA-R134).
KIND_FIELD_LIMITS = {("title", "text"): 32, ("boardtitle", "text"): 32, ("variety", "description"): 200}


def limit(kind: str, name: str) -> int | None:
    """A field's length limit (Tunables), or None for an unlimited one."""
    return KIND_FIELD_LIMITS.get((kind, name), FIELD_LIMITS.get(name))


def translated_limit(english: int) -> int:
    """The most a translated field may be (DATA-R107, DATA-R114): the English limit plus 30%, in whole code points, the
    fraction dropped. Integer arithmetic, so the rounding is the same everywhere: 28 gives 36, 32 gives 41, 80 gives
    104, 100 gives 130, 200 gives 260."""
    return english * 13 // 10


def _catalogue_orphan(kind: str, id_: str, ids: CatalogueIds) -> str | None:
    """Why a catalogue-keyed text's ID is no such thing, or None when it is one (DATA-R107's orphan)."""
    item = _catalogue_id(id_)
    if kind == "species" and item in ids.legends:
        return f"{id_} is a Legend, which needs legend text only (LED-R4, DATA-R107)"
    entry = CATALOGUE_KINDS[kind]
    return None if item in entry.ids(ids) else f"{id_} {entry.orphan}"


def _check_text(lore_id: str, text: Text, layer: LoreLayer, ids: CatalogueIds, problems: Problems) -> None:
    """DATA-R107's orphan, missing (an empty value), length, newline and placeholder checks on one text."""
    at = At(lore_file(lore_id), text.key)
    owner = _owner(layer, text.kind)
    if owner is None:
        problems.add(at, f"orphan: no addon defines the kind {text.kind} (DATA-R102, DATA-R106, DATA-R107)")
        return
    if owner != lore_id:
        problems.add(at, f"orphan: the kind {text.kind} is {_possessive(owner)} (DATA-R102, DATA-R107)")
        return
    if text.kind == "event":
        problems.add(at, f"orphan: an event's text stays in its file in {EVENTS_DIR}/ (DATA-R97, DATA-R107)")
        return
    if text.kind in HUNTS_KINDS:
        stays = f"a Hunt's and a set's text stays in {HUNTS_TOML}"
        problems.add(at, f"orphan: {stays} (DATA-R100, DATA-R105, DATA-R107)")
        return
    entry = layer.manifest.get(lore_id, {}).get(text.kind)
    fields = CATALOGUE_KINDS[text.kind].fields if entry is None else entry.fields
    if text.field not in fields:
        shown = ", ".join(fields)
        problems.add(at, f"orphan: {text.field} isn't one of {_possessive(text.kind)} fields ({shown}) (DATA-R107)")
        return
    if entry is None:
        why = _catalogue_orphan(text.kind, text.id, ids)
        allowed: frozenset[str] = frozenset()
    else:
        why = None
        if text.id not in entry.ids:
            why = f"{text.id} isn't in manifest.toml's [{lore_id}.{text.kind}] ids (DATA-R106, DATA-R107)"
        allowed = entry.ids.get(text.id, frozenset())
    if why is not None:
        problems.add(at, f"orphan: {why}")
        return

    if not has_text(text.value):
        problems.add(at, "missing: empty (DATA-R107)")
        return
    _check_value(at, text, problems)
    bare = text.value
    for name in allowed:
        bare = bare.replace("{" + name + "}", "")
    if "{" in bare or "}" in bare:
        shown = ", ".join("{" + name + "}" for name in sorted(allowed)) or "none here"
        outside = f"outside an allowed placeholder (manifest.toml allows {shown})"
        problems.add(at, f"placeholder: {{ or }} {outside} (DATA-R107, DATA-R108)")


def _check_value(at: At, text: Text, problems: Problems) -> None:
    """DATA-R107's length and newline checks on one text."""
    value = text.value
    most = limit(text.kind, text.field)
    if most is not None and len(value) > most:
        over = f"over {_possessive(text.field)} limit of {most}"
        problems.add(at, f"length: {len(value)} code points, {over} (DATA-R107)")
    if value.splitlines() != [value]:
        problems.add(at, "newline: a line break (DATA-R107)")


def _check_hunt_text(file: str, text: Text, problems: Problems) -> None:
    """DATA-R105's checks on a Hunt's or a set's text in hunts.toml, and on an event's or its Hunts' in its event file
    (DATA-R99): empty, length (a name 28, a set's title 32, a note none), newline, and any { or } at all, since the
    manifest allows these keys no placeholder. They aren't in the manifest, so there is no orphan or missing key: the
    format already requires every name and title (and an event's note)."""
    at = At(file, text.key)
    if not has_text(text.value):
        problems.add(at, "missing: empty (DATA-R105, DATA-R107)")
        return
    _check_value(at, text, problems)
    if "{" in text.value or "}" in text.value:
        problems.add(at, "placeholder: { or } in a Hunt's or set's text, which allows none (DATA-R105, DATA-R107)")


def _needed(lore_id: str, layer: LoreLayer, ids: CatalogueIds) -> list[tuple[str, str]]:
    """Every key lore_id's file needs (DATA-R103, DATA-R106), with why, in key order."""
    needed: list[tuple[str, str]] = []
    if lore_id == CATALOGUE_OWNER:
        for kind, catalogue_kind in CATALOGUE_KINDS.items():
            of, fields = catalogue_kind.ids(ids), catalogue_kind.fields
            needed.extend((f"{kind}.{item}.{name}", catalogue_kind.missing) for item in sorted(of) for name in fields)
    for kind, entry in sorted(layer.manifest.get(lore_id, {}).items()):
        why = "manifest.toml lists it (DATA-R106, DATA-R107)"
        needed.extend((f"{kind}.{id_}.{name}", why) for id_ in entry.ids for name in entry.fields)
    return needed


def check_lore(layer: LoreLayer, lore_ids: Collection[str], ids: CatalogueIds, problems: Problems) -> None:
    """DATA-R107's lore check for each lore ID switched on (DATA-R66), every problem naming the file and the key."""
    for lore_id in lore_ids:
        if lore_id in layer.unreadable:
            continue  # its TOML problem is reported already, and every key would look missing
        file = lore_file(lore_id)
        texts = layer.files.get(lore_id)
        if texts is None:
            problems.add(At(file), f"missing, and the {lore_id} lore check is on (DATA-R107)")
            texts = {}
        for key in sorted(texts, key=lambda key: key.encode("utf-8")):
            _check_text(lore_id, texts[key], layer, ids, problems)
        for key, why in _needed(lore_id, layer, ids):
            if key not in texts:
                problems.add(At(file, key), f"missing: {why}")
        if lore_id == HUNTS_OWNER:
            for source, hunt_texts in layer.hunts_sources():
                check_hunts_texts(source, hunt_texts, problems)


def check_hunts_texts(file: str, texts: Mapping[str, Text], problems: Problems) -> None:
    """The Hunts lore check (DATA-R105, DATA-R107) on the text kept beside one source of definitions, by key: what
    check_lore runs on hunts.toml and each event file once the hunts check is on, and scripts/check-event.py on the
    event it checks (DATA-R99)."""
    for key in sorted(texts, key=lambda key: key.encode("utf-8")):
        _check_hunt_text(file, texts[key], problems)


def check_text_glyphs(at: At, text: str, locale: str, problems: Problems, reference: str = "DATA-R107") -> None:
    """The glyph check of one text: each character outside CORE-R9's range for locale, named by its code point once
    per text, since the client's fonts draw it as a box. The one loop lore and the interface text (DATA-R114) share;
    the range is data/glyphs.toml's (pagle_data/glyphs.py), English getting the base set."""
    glyphs = glyphs_for(locale)
    seen: set[str] = set()
    for char in text:
        if not glyphs.has(char) and char not in seen:
            seen.add(char)
            where = "set" if locale == ENGLISH else f"range for {locale}"
            problems.add(
                at,
                f"glyph: U+{ord(char):04X} outside CORE-R9's {where}: {glyphs.description} (CORE-R9, {reference})",
            )


def check_glyphs(layer: LoreLayer, problems: Problems, locale: str = ENGLISH) -> None:
    """DATA-R107's glyph check over every lore file read, whether or not its check is on: each character outside
    CORE-R9's range for locale, named by its code point once per text, since the client's fonts draw it as a box.
    The range is data/glyphs.toml's (pagle_data/glyphs.py): English lore, the default, gets the base set. The Hunt
    and set text of hunts.toml (DATA-R105) and each event file's text (DATA-R97) are Pagle_Hunts' lore, so they are
    checked too. A Locale's translations (DATA-R114) are each held to their own Locale's range, whatever locale is:
    the translated value is checked, never its EN snapshot, which is English."""
    sources = [(lore_file(lore_id), texts) for lore_id, texts in sorted(layer.files.items())]
    sources.extend(layer.hunts_sources())
    for file, texts in sources:
        for key in sorted(texts, key=lambda key: key.encode("utf-8")):
            check_text_glyphs(At(file, key), texts[key].value, locale, problems)
    for code, files in sorted(layer.translations.items()):
        for lore_id, translation in sorted(files.items()):
            for key in sorted(translation.texts, key=lambda key: key.encode("utf-8")):
                at = At(translation_file(code, lore_id), key)
                check_text_glyphs(at, translation.texts[key].value, code, problems, "DATA-R114")


def _english(layer: LoreLayer, lore_id: str) -> dict[str, Text]:
    """Every key English has for a lore ID, whatever its check says (DATA-R114's orphan): its lore file's, and for
    Pagle_Hunts the Hunt, set and event text beside the definitions (DATA-R105, DATA-R97)."""
    texts = dict(layer.files.get(lore_id, {}))
    if lore_id == HUNTS_OWNER:
        texts |= layer.hunts
        for event_texts in layer.events.values():
            texts |= event_texts
    return texts


def _placeholders(text: str) -> set[str]:
    return {found[1:-1] for found in _PLACEHOLDER.findall(text)}


def _check_translated(
    code: str, lore_id: str, key: str, text: Text, english: Text, snapshot: str, layer: LoreLayer, problems: Problems
) -> None:
    """DATA-R114's missing, length, newline and placeholder checks on one translated text, and its drift."""
    file = translation_file(code, lore_id)

    def fail(check: str, detail: str) -> None:
        problems.add(At(file, key), f"{check}: {detail} ({code}, DATA-R107, DATA-R114)")

    if not has_text(text.value):
        fail("missing", "empty; leave a key you have not translated out, and it shows English")
    else:
        most = limit(english.kind, english.field)
        if most is not None and len(text.value) > translated_limit(most):
            allowed = translated_limit(most)
            over = f"over {_possessive(english.field)} limit of {most} plus 30%, {allowed}"
            fail("length", f"{len(text.value)} code points, {over}")
        if text.value.splitlines() != [text.value]:
            fail("newline", "a line break")
        wanted, found = _placeholders(english.value), _placeholders(text.value)
        if wanted != found:
            lacks = ", ".join("{" + name + "}" for name in sorted(wanted - found))
            extra = ", ".join("{" + name + "}" for name in sorted(found - wanted))
            detail = "; ".join(part for part in (f"lacks {lacks}" if lacks else "", f"adds {extra}" if extra else "") if part)
            fail("placeholder", f"the placeholders differ from the English text's: {detail}")
        bare = _PLACEHOLDER.sub("", text.value)
        if "{" in bare or "}" in bare:
            fail("placeholder", "{ or } outside {zone} and {fish}")
    if snapshot != english.value:
        old, new = _placeholders(snapshot), _placeholders(english.value)
        detail = "the placeholders are the same, so it keeps showing" if old == new else "the placeholders changed"
        layer.warnings.append(
            f"{file}: {key}: drift: the EN snapshot is not the English text now ({code}); {detail}"
        )


def english_texts(layer: LoreLayer, lore_id: str) -> dict[str, Text]:
    """Every key English has for a lore ID, by key: the keys a translation of that lore ID may use (DATA-R114)."""
    return _english(layer, lore_id)


def placeholders(text: str) -> set[str]:
    """The Lore placeholders ({zone}, {fish}) a text uses (DATA-R107)."""
    return _placeholders(text)


def check_translations(layer: LoreLayer, problems: Problems) -> None:
    """DATA-R114's checks on every Locale's lore file, each problem naming the file, the key, the check and the Locale:
    orphan (a key English lacks, or has in another addon's file), missing (an empty value), length, newline and
    placeholder; glyph is check_glyphs'. A key a translation lacks is no problem: it shows English. Drift (an EN
    snapshot that is not today's English) goes to layer.warnings and never fails."""
    for code in sorted(layer.translations):
        for lore_id, translation in sorted(layer.translations[code].items()):
            english = _english(layer, lore_id)
            for key in sorted(translation.texts, key=lambda key: key.encode("utf-8")):
                source = english.get(key)
                if source is None:
                    elsewhere = [other for other in ADDONS if other != lore_id and key in _english(layer, other)]
                    detail = f"belongs to {elsewhere[0]}.toml, not {lore_id}.toml" if elsewhere else "English has no such key"
                    problems.add(At(translation_file(code, lore_id), key), f"orphan: {detail} ({code}, DATA-R114)")
                    continue
                _check_translated(
                    code, lore_id, key, translation.texts[key], source, translation.snapshots[key], layer, problems
                )


def check_registration(layer: LoreLayer, registered: Mapping[str, Collection[str]], problems: Problems) -> None:
    """DATA-R114's registration check: a Locale's lore file is a second function for its code, which the interface file
    of the same addon registers with `opts` (Registry.lua never applies a code that only Lore registered). registered
    is, by lore ID, the codes whose Locale has a header and an interface file for that addon."""
    for code in sorted(layer.translations):
        for lore_id in sorted(layer.translations[code]):
            if code not in registered.get(lore_id, ()):
                why = (
                    f"{translation_file(code, lore_id)} needs data/locale/{code}/locale.toml and"
                    f" data/locale/{code}/{lore_id}.toml, which register {code} for this addon with ns.Locale"
                )
                problems.add(At(translation_file(code, lore_id)), f"registration: {why} (DATA-R114)")


# CORE-R11: every file of a Module starts with Core's guard, as the hand-written ones do, so a broken install without
# Pagle loads none of it.
CORE_GUARD = (
    "if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)\n"
    "\treturn\n"
    "end\n"
)


def lore_lua_text(lore_id: str, texts: Mapping[str, Text], header: str) -> str:
    """A lore ID's Lore.lua (DATA-R104): plain assignments to the addon's ns.L by key, sorted by byte (DATA-R62),
    after the header (DATA-R6) and, in a Module, Core's guard (CORE-R11). The TOC lists it after the file that
    creates ns.L (DATA-R75). A key with no text is left out: it shows nothing, as a missing one does (LED-R161)."""
    parts = [header]
    if lore_id != "core":
        parts.append(CORE_GUARD)
    keys = sorted((key for key, text in texts.items() if has_text(text.value)), key=lambda key: key.encode("utf-8"))
    if keys:
        lines = [f"L[{to_lua(key)}] = {to_lua(texts[key].value)}\n" for key in keys]
        parts.append("local L = select(2, ...).L\n\n" + "".join(lines))
    return "\n".join(parts)


def retired_lore(present: Callable[[str], bool], outputs: Collection[str]) -> dict[str, str]:
    """Each Lore.lua present (by present(path)) that outputs doesn't give, by path, with the lore file it was
    generated from: that file is gone, so the Lore.lua is stale (DATA-R60) and the generator removes it."""
    return {
        lore_lua(lore_id): lore_file(lore_id)
        for lore_id in ADDONS
        if lore_lua(lore_id) not in outputs and present(lore_lua(lore_id))
    }


def retired_translations(root: Path, outputs: Collection[str]) -> dict[str, str]:
    """Each Lore.<code>.lua present under root that outputs doesn't give, by path, with the lore file it was generated
    from (DATA-R114): that file is gone, so the Lore.<code>.lua is stale (DATA-R60) and the generator removes it."""
    retired: dict[str, str] = {}
    for lore_id, addon in ADDONS.items():
        for path in sorted((root / "addons" / addon / "data").glob("Lore.[a-z][a-z][A-Z][A-Z].lua")):
            code = path.name.split(".")[1]
            relative = translation_lua(code, lore_id)
            if relative not in outputs:
                retired[relative] = translation_file(code, lore_id)
    return retired


def lore_outputs(
    layer: LoreLayer, header_of: Callable[[str], str], translators: Mapping[str, tuple[str, ...]] | None = None
) -> dict[str, str]:
    """Each Lore.lua by path: one for every lore ID with a lore file, and Pagle_Hunts' too when hunts.toml has Hunt or
    set text (DATA-R105) or an event file has text (DATA-R97), emitted whether or not its check is on (DATA-R104).
    Pagle_Hunts' one Lore.lua holds all its sources. header_of gives DATA-R6's header for a file's sources. Each
    Locale's lore file with text is a Lore.<code>.lua beside them (DATA-R114); translators gives each Locale's names,
    carried into a comment. The English Lore.lua never reads a translation."""
    outputs: dict[str, str] = {}
    events = {key: text for texts in layer.events.values() for key, text in texts.items()}
    for lore_id in ADDONS:
        texts = layer.files.get(lore_id)
        hunts = layer.hunts | events if lore_id == HUNTS_OWNER else {}
        if texts is None and not hunts:
            continue
        sources = [HUNTS_TOML] if lore_id == HUNTS_OWNER and layer.hunts else []
        sources += [f"{EVENTS_DIR}/"] if lore_id == HUNTS_OWNER and events else []
        sources += [lore_file(lore_id)] if texts is not None else []
        outputs[lore_lua(lore_id)] = lore_lua_text(lore_id, (texts or {}) | hunts, header_of(", ".join(sources)))
    for code, lore_id, texts in emitted_translations(layer):
        names = () if translators is None else translators.get(code, ())
        outputs[translation_lua(code, lore_id)] = translation_lua_text(code, lore_id, texts, names)
    return outputs


def emitted_translations(layer: LoreLayer) -> list[tuple[str, str, dict[str, Text]]]:
    """Each Locale's lore file that writes a Lore.<code>.lua (DATA-R114), as (code, lore ID, its texts that have text),
    in code and lore ID order. A file with no text writes none: there is nothing for a second function to say."""
    emitted: list[tuple[str, str, dict[str, Text]]] = []
    for code in sorted(layer.translations):
        for lore_id in ADDONS:
            translation = layer.translations[code].get(lore_id)
            texts = {key: text for key, text in (translation.texts if translation else {}).items() if has_text(text.value)}
            if texts:
                emitted.append((code, lore_id, texts))
    return emitted


def translated_codes(layer: LoreLayer) -> dict[str, list[str]]:
    """The Locales that have a Lore.<code>.lua, by addon folder, in code order: what locale/Locales.xml lists after the
    interface file of the same code (DATA-R114)."""
    codes: dict[str, list[str]] = {}
    for code, lore_id, _ in emitted_translations(layer):
        codes.setdefault(ADDONS[lore_id], []).append(code)
    return codes


def translation_lua_text(code: str, lore_id: str, texts: Mapping[str, Text], translators: tuple[str, ...] = ()) -> str:
    """A Locale's Lore.<code>.lua (DATA-R114): one `ns.Locale` call with no `opts`, a second function for the code,
    which the interface file registered, whose plain assignments to L go by key, sorted by byte (DATA-R62). A Module's
    starts with Core's guard (CORE-R11), and the file has the header comment, the translators' names and the addon's
    `ns` class, as the interface's locale file does."""
    source = translation_file(code, lore_id)
    comment = [
        f"-- Generated by scripts/generate-data.py from {source}. Do not edit by hand: edit data/ and run the generator.",
        "-- GPL-3.0-or-later.",
    ]
    if translators:
        comment.append(f"-- Translators: {', '.join(translators)}.")
    guard = "" if lore_id == "core" else CORE_GUARD + "\n"
    namespace = ADDONS[lore_id].replace("_", "") + "NS"
    keys = sorted(texts, key=lambda key: key.encode("utf-8"))
    body = "".join(f"\tL[{to_lua(key)}] = {to_lua(texts[key].value)}\n" for key in keys)
    header = "\n".join(comment)
    return (
        f"{guard}{header}\n\n---@class {namespace}\nlocal ns = select(2, ...)\n\n"
        f"ns.Locale({to_lua(code)}, function(L)\n{body}end)\n"
    )
