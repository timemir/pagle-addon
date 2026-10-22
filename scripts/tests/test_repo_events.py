"""The repo's own event pool (DATA-R97, DATA-R98): data/hunts/tags.toml, data/hunts/events/ and the EventList.lua
they generate."""

from collections.abc import Mapping
from pathlib import Path

from pagle_data.events import EVENT_LIST_LUA
from pagle_data.generate import event_list_of, hunt_list_of, read_layers

REPO = Path(__file__).resolve().parents[2]

# DATA-R97's closed tag list, by kind, written from the rule rather than from tags.toml.
DATA_R97_TAGS = {
    "holiday": [
        "hallows_end",
        "winter_veil",
        "lunar_festival",
        "noblegarden",
        "midsummer",
        "harvest_festival",
        "stv_extravaganza",
    ],
    "time": ["night", "day", "dusk"],
    "water": ["coast", "lake", "river", "pool"],
    "band": ["low", "mid", "high"],
}


def test_the_committed_tag_list_is_data_r97_s() -> None:
    # DATA-R97: tags.toml holds exactly the rule's list, each tag of its kind.
    tags = read_layers(REPO).events.tags
    assert {tag: kind for kind, listed in DATA_R97_TAGS.items() for tag in listed} == tags


def test_the_committed_event_list_is_what_the_pool_gives(repo_outputs: Mapping[str, str]) -> None:
    # DATA-R98, DATA-R61: EventList.lua is generated from data/hunts/events/ (the README there is ignored) and
    # committed with it.
    committed = (REPO / EVENT_LIST_LUA).read_text(encoding="utf-8")
    assert committed == repo_outputs[EVENT_LIST_LUA]
    event_list = event_list_of(read_layers(REPO))
    assert f'fingerprint = "{event_list["fingerprint"]}"' in committed
    assert sorted(path.name for path in (REPO / "data" / "hunts" / "events").iterdir() if path.suffix != ".toml") == [
        "README.md"
    ]


# hunts.md › Data, The 1.0 event pool: the four seed events, each as (id, zones, its Timed Hunt's target as (key,
# value), and its time). Written from the table, not from the event files, so the pool can't drift from the spec.
SEED_EVENTS: list[tuple[str, list[int], tuple[str, object], list[list[int]]]] = [
    ("darkshore_moonlight", [148], ("species", 12238), [[1320, 240]]),
    ("duskwood_witching", [10], ("class", "species.any"), [[0, 180]]),
    ("barrens_oddities", [17], ("class", "fixed.oddity"), [[1080, 1260]]),
    ("alterac_dawn_trout", [36], ("species", 8365), [[300, 480]]),
]


def _hunts(event: Mapping[str, object]) -> list[dict[str, object]]:
    hunts = event["hunts"]
    assert isinstance(hunts, list)
    return hunts


def test_the_committed_pool_has_8_rotating_events_per_band_of_3_to_5_hunts() -> None:
    # hunts.md › The 1.0 event pool, DATA-R99, HNT-R156: 24 rotating events, 8 in each skill band, each of 3-5 Hunts.
    events = event_list_of(read_layers(REPO))["events"]
    rotating = [event for event in events if event["rotation"] is True and "retired" not in event]
    assert len(rotating) == 24
    by_band: dict[object, int] = {}
    for event in rotating:
        by_band[event["band"]] = by_band.get(event["band"], 0) + 1
    assert by_band == {"low": 8, "mid": 8, "high": 8}
    for event in events:
        assert 3 <= len(_hunts(event)) <= 5, event["id"]


def test_no_two_committed_events_share_an_id_or_a_hunt_id() -> None:
    # DATA-R97, DATA-R92: event IDs are unique, and so is every Hunt ID, across the events and the Standing Hunts.
    layers = read_layers(REPO)
    events = event_list_of(layers)["events"]
    event_ids = [event["id"] for event in events]
    assert len(event_ids) == len(set(event_ids))
    hunt_ids = [hunt["id"] for event in events for hunt in _hunts(event)]
    assert len(hunt_ids) == len(set(hunt_ids))
    assert not set(hunt_ids) & {hunt["id"] for hunt in hunt_list_of(layers)["hunts"]}


def test_the_four_seed_events_have_their_timed_hunts_as_hunts_md_gives_them() -> None:
    # hunts.md › The 1.0 event pool: each seed event is in its fish's waters, rotating in the low band, with that Timed
    # Hunt as its only Hunt with a time condition (at most one Timed, DATA-R99).
    events = {event["id"]: event for event in event_list_of(read_layers(REPO))["events"]}
    for event_id, zones, (key, target), time in SEED_EVENTS:
        event = events[event_id]
        assert (event["zones"], event["band"], event["rotation"]) == (zones, "low", True)
        timed = [hunt for hunt in _hunts(event) if isinstance(spec := hunt.get("conditions"), dict) and "time" in spec]
        assert len(timed) == 1, event_id
        assert timed[0][key] == target
        assert timed[0]["conditions"] == {"time": time}
