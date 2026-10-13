"""The content fingerprint (DATA-R70)."""

from collections.abc import Mapping

from pagle_data.catalogue import Catalogue, canonical_json, fingerprint
from pagle_data.lua import Shared

# A catalogue in its pre-M2 shape (DATA-R79), with an empty list (auras), empty tables (items, an event without a
# weekly rule) and integer keys that sort differently as numbers and as strings (7 and 301).
FIXTURE: Catalogue = {
    "fingerprint": "left out of its own hash",
    "items": {},
    "areas": {},
    "aliases": {},
    "pools": {},
    "windows": {},
    "events": {
        7: {},
        301: {"weekday": 1, "start": 840, "duration": 120, "confirmed": False},
    },
    "fishingSpells": [7620, 18248],
    "auras": [],
}

# Written by hand from DATA-R70: no fingerprint, keys sorted as strings, integer keys as decimal strings, lists as
# arrays and every other table as an object, even when empty.
CANONICAL = (
    '{"aliases":{},"areas":{},"auras":[],'
    '"events":{"301":{"confirmed":false,"duration":120,"start":840,"weekday":1},"7":{}},'
    '"fishingSpells":[7620,18248],"items":{},"pools":{},"windows":{}}'
)


def test_canonical_json_follows_data_r70() -> None:
    assert canonical_json(FIXTURE) == CANONICAL


def test_fingerprint_is_the_first_16_hex_of_the_sha256_of_the_canonical_json() -> None:
    # DATA-R70: `printf '%s' "$CANONICAL" | sha256sum` gives e6e8f974ff0970c03492c5f8d6544c62…
    assert fingerprint(FIXTURE) == "e6e8f974ff0970c0"


def test_the_fingerprint_field_never_counts() -> None:
    # DATA-R70: "the catalogue table without its fingerprint field".
    assert fingerprint({**FIXTURE, "fingerprint": "0123456789abcdef"}) == "e6e8f974ff0970c0"


def gated(night: Mapping[str, object]) -> Catalogue:
    """A catalogue whose area 148 has a night-gated entry and whose subzone 453 has an empty list (DATA-R78): the
    gate is the W entry windows["night"] points at, as Catalogue.lua shares it (Contracts)."""
    spec = Shared("W", "night", night)
    return {
        **FIXTURE,
        "areas": {
            148: {
                "parent": 0,
                "continent": 1,
                "hasData": True,
                "skillBaseConfirmed": False,
                "catches": [
                    {"itemID": 13759, "confirmed": False, "window": "night", "gate": spec, "gateConfirmed": False}
                ],
            },
            453: {"parent": 148, "continent": 1, "hasData": True, "skillBaseConfirmed": False, "catches": []},
        },
        "windows": {"night": {"spec": spec, "confirmed": False}},
    }


NIGHT = {"time": [[1080, 720]]}


def test_an_empty_catch_list_is_an_array_and_a_shared_gate_spec_is_written_in_full() -> None:
    # DATA-R70: "Fields that are lists (catches, …, the lists inside a condition spec) are JSON arrays, even when
    # empty", and "A gate's shared window spec is written out in full wherever it is used". By hand:
    areas = (
        '"areas":{"148":{"catches":[{"confirmed":false,"gate":{"time":[[1080,720]]},"gateConfirmed":false,'
        '"itemID":13759,"window":"night"}],"continent":1,"hasData":true,"parent":0,"skillBaseConfirmed":false},'
        '"453":{"catches":[],"continent":1,"hasData":true,"parent":148,"skillBaseConfirmed":false}}'
    )
    windows = '"windows":{"night":{"confirmed":false,"spec":{"time":[[1080,720]]}}}'
    expected = CANONICAL.replace('"areas":{}', areas).replace('"windows":{}', windows)
    assert canonical_json(gated(NIGHT)) == expected


def test_the_fingerprint_changes_when_a_gate_s_spec_changes() -> None:
    # DATA-R70: every catalogue value counts, so correcting a window's spec changes CONTENT_FINGERPRINT (and with it
    # every projection, DATA-R71). `printf '%s' '<canonical JSON above>' | sha256sum` gives 2ed818156ca744de…
    assert fingerprint(gated(NIGHT)) == "2ed818156ca744de"
    assert fingerprint(gated({"time": [[1080, 360]]})) != "2ed818156ca744de"
