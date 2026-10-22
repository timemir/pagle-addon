"""The repo's own event pool (DATA-R97, DATA-R98): data/hunts/tags.toml, data/hunts/events/ and the EventList.lua
they generate."""

from collections.abc import Mapping
from pathlib import Path

from pagle_data.events import EVENT_LIST_LUA
from pagle_data.generate import event_list_of, read_layers

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
