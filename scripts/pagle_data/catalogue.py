"""The catalogue Core ships as ns.catalogue (DATA-R76), and its content fingerprint (DATA-R70)."""

import hashlib
import json
from collections.abc import Mapping
from typing import TypedDict

FINGERPRINT_LENGTH = 16  # Tunables: "Fingerprint length"


class Event(TypedDict, total=False):
    """An event-list entry (DATA-R38): its weekly rule and whether it is confirmed, or no fields without a rule."""

    weekday: int
    start: int
    duration: int
    confirmed: bool


class Catalogue(TypedDict):
    """ns.catalogue (DATA-R76), shaped as the Contracts section of docs/spec/content-data.md shows it.

    Item records are DATA-R77's (pagle_data.items) and area records DATA-R78's (pagle_data.areas); a catch entry's
    gate is its window's shared spec (pagle_data.lua.Shared), which the canonical JSON writes in full.
    """

    fingerprint: str
    items: dict[int, Mapping[str, object]]
    areas: dict[int, Mapping[str, object]]
    aliases: dict[int, int]
    pools: dict[str, list[int]]
    windows: dict[str, Mapping[str, object]]
    events: dict[int, Event]
    fishingSpells: list[int]
    auras: list[int]


def _canonical(value: object) -> object:
    # DATA-R70: integer map keys become decimal strings; lists stay lists (JSON arrays) and every other table stays
    # a mapping (a JSON object), even when empty.
    if isinstance(value, Mapping):
        return {str(key): _canonical(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_canonical(item) for item in value]
    return value


def canonical_json(catalogue: Catalogue) -> str:
    """The catalogue's canonical JSON (DATA-R70): the catalogue without its fingerprint field."""
    body = {key: value for key, value in catalogue.items() if key != "fingerprint"}
    return json.dumps(_canonical(body), sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def fingerprint(catalogue: Catalogue) -> str:
    """CONTENT_FINGERPRINT (DATA-R70): the first 16 lowercase hex characters of the canonical JSON's SHA-256."""
    digest = hashlib.sha256(canonical_json(catalogue).encode("utf-8")).hexdigest()
    return digest[:FINGERPRINT_LENGTH]
