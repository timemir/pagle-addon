"""Lore (DATA-R100-R109): data/lore/<lore ID>.toml and manifest.toml, each addon's Lore.lua, and the lore check.

Lore is display text only. It is never in the catalogue or its fingerprint and changes no count (DATA-R109), so
nothing here feeds the catalogue: the lore check reads the item records and the families, never the other way round.
"""

import re
from collections.abc import Callable, Collection, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.items import Record
from pagle_data.lua import to_lua
from pagle_data.toml_reader import check_keys, describe, expect_table, read_toml

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

# DATA-R103: the kinds keyed by catalogue IDs, all the Ledger's, with their fields.
CATALOGUE_KINDS: dict[str, tuple[str, ...]] = {
    "species": ("blurb", "riddle"),
    "legend": ("blurb", "title"),
    "sub": ("plaque",),
    "family": ("name",),
}
CATALOGUE_OWNER = "ledger"
# DATA-R105: the text of Hunts and Hunt sets, Pagle_Hunts' kinds, kept in data/hunts/hunts.toml and never in the
# manifest.
HUNTS_KINDS = ("hunt", "set")
HUNTS_OWNER = "hunts"

# DATA-R101: a kind is lowercase letters; a field is the last dot-separated segment of a key.
_KIND = re.compile(r"[a-z]+")
_FIELD = re.compile(r"[a-z][A-Za-z0-9]*")
# DATA-R108: the one placeholder in 1.0.
PLACEHOLDERS = ("zone",)


def lore_file(lore_id: str) -> str:
    return f"{LORE}/{lore_id}.toml"


def lore_lua(lore_id: str) -> str:
    """The Lore.lua a lore ID's text is emitted into (DATA-R75)."""
    return f"addons/{ADDONS[lore_id]}/data/Lore.lua"


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
class LoreLayer:
    """data/lore/ as read: each lore file present, by lore ID, with its texts by key, and the manifest's kinds by
    lore ID and kind."""

    files: dict[str, dict[str, Text]] = field(default_factory=dict)
    manifest: dict[str, dict[str, ManifestKind]] = field(default_factory=dict)
    unreadable: set[str] = field(default_factory=set)  # lore IDs whose file isn't valid TOML


def _read_texts(root: Path, lore_id: str, problems: Problems) -> dict[str, Text] | None:
    """A lore file's tables, one per <kind>.<id>, each holding its fields as strings (DATA-R101), or None when it
    isn't valid TOML. Only the shape is checked here; what the text says is the lore check's (DATA-R107)."""
    file = lore_file(lore_id)
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
                    problems.add(item_at / "placeholders", f"{{zone}} is the only placeholder (DATA-R108), got {shown}")
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


def read_lore(root: Path, problems: Problems) -> LoreLayer:
    """root/data/lore/: each lore ID's file that exists, and the manifest. Each problem in a file's shape goes into
    problems (DATA-R63); the layer read is returned either way. A .toml file there that is neither a lore ID's nor
    the manifest is a problem too."""
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
            texts = _read_texts(root, lore_id, problems)
            if texts is None:
                layer.unreadable.add(lore_id)
            else:
                layer.files[lore_id] = texts
    return layer


def has_text(value: str) -> bool:
    """A value that is text, not empty (DATA-R107's missing)."""
    return bool(value.strip())


@dataclass(frozen=True)
class CatalogueIds:
    """What the catalogue-keyed kinds are keyed by (DATA-R103), from the item records and families.toml."""

    species: frozenset[int] = frozenset()  # Species IDs whose item isn't a Legend (LED-R4 in M3)
    legends: frozenset[int] = frozenset()
    subs: frozenset[int] = frozenset()  # non-Noise junk, container and treasure items
    families: frozenset[int] = frozenset()


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


# Tunables › Lore limits (DATA-R107), in Unicode code points, by field; a title's text has a limit of its own.
LIMITS = {"riddle": 80, "blurb": 200, "plaque": 100, "name": 28, "title": 32}
TITLE_TEXT_LIMIT = 32
_MISSING = {
    "species": "every Species needs it (DATA-R103, DATA-R107)",
    "legend": "every Legend needs it (DATA-R103, DATA-R107)",
    "sub": "every non-Noise junk, container and treasure item needs it (DATA-R103, DATA-R107)",
    "family": "every family in data/forever/families.toml needs it (DATA-R103, DATA-R107)",
}


def limit(kind: str, name: str) -> int | None:
    """A field's length limit (Tunables), or None for an unlimited one."""
    if kind == "title" and name == "text":
        return TITLE_TEXT_LIMIT
    return LIMITS.get(name)


def _catalogue_orphan(kind: str, id_: str, ids: CatalogueIds) -> str | None:
    """Why a catalogue-keyed text's ID is no such thing, or None when it is one (DATA-R107's orphan)."""
    item = _catalogue_id(id_)
    if kind == "species":
        if item in ids.legends:
            return f"{id_} is a Legend, which needs legend text only (LED-R4, DATA-R107)"
        return None if item in ids.species else f"{id_} isn't a Species ID (DATA-R19, DATA-R107)"
    if kind == "legend":
        return None if item in ids.legends else f"{id_} isn't a Legend (DATA-R22, DATA-R107)"
    if kind == "sub":
        if item in ids.subs:
            return None
        return f"{id_} isn't a non-Noise junk, container or treasure item (DATA-R103, DATA-R107)"
    return None if item in ids.families else f"{id_} isn't a family in data/forever/families.toml (DATA-R21, DATA-R107)"


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
    entry = layer.manifest.get(lore_id, {}).get(text.kind)
    fields = CATALOGUE_KINDS[text.kind] if entry is None else entry.fields
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

    value = text.value
    if not has_text(value):
        problems.add(at, "missing: empty (DATA-R107)")
        return
    most = limit(text.kind, text.field)
    if most is not None and len(value) > most:
        over = f"over {_possessive(text.field)} limit of {most}"
        problems.add(at, f"length: {len(value)} code points, {over} (DATA-R107)")
    if value.splitlines() != [value]:
        problems.add(at, "newline: a line break (DATA-R107)")
    bare = value
    for name in allowed:
        bare = bare.replace("{" + name + "}", "")
    if "{" in bare or "}" in bare:
        shown = ", ".join("{" + name + "}" for name in sorted(allowed)) or "none here"
        outside = f"outside an allowed placeholder (manifest.toml allows {shown})"
        problems.add(at, f"placeholder: {{ or }} {outside} (DATA-R107, DATA-R108)")


def _needed(lore_id: str, layer: LoreLayer, ids: CatalogueIds) -> list[tuple[str, str]]:
    """Every key lore_id's file needs (DATA-R103, DATA-R106), with why, in key order."""
    needed: list[tuple[str, str]] = []
    if lore_id == CATALOGUE_OWNER:
        kinds = (("species", ids.species), ("legend", ids.legends), ("sub", ids.subs), ("family", ids.families))
        for kind, of in kinds:
            fields = CATALOGUE_KINDS[kind]
            needed.extend((f"{kind}.{item}.{name}", _MISSING[kind]) for item in sorted(of) for name in fields)
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


def lore_outputs(layer: LoreLayer, header_of: Callable[[str], str]) -> dict[str, str]:
    """Each Lore.lua by path: one for every lore ID with a lore file, emitted whether or not its check is on
    (DATA-R104). header_of gives DATA-R6's header for a file's sources."""
    return {
        lore_lua(lore_id): lore_lua_text(lore_id, texts, header_of(lore_file(lore_id)))
        for lore_id, texts in layer.files.items()
    }

