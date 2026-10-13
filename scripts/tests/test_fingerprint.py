"""The content fingerprint (DATA-R70)."""

from pagle_data.catalogue import Catalogue, canonical_json, fingerprint

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
