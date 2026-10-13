"""The repo's own catch lists (DATA-R26–R31): data/forever/areas.toml's v1 edits as the committed catalogue ships
them (DATA-R78). spec/Pagle/data/Areas_spec.lua checks the same through Core's accessors."""

import re
from pathlib import Path

from pagle_data.generate import CATALOGUE_LUA, read_layers

REPO = Path(__file__).resolve().parents[2]
COMMITTED = (REPO / CATALOGUE_LUA).read_text(encoding="utf-8")

# Brownell's Blue Striped Racer, Keefer's Angelfish, Dezian Queenfish (the Legends, DATA-R22) and Speckled
# Tastyfish: pool-only in the baseline (DATA-R28).
EXTRAVAGANZA = (19803, 19805, 19806, 19807)


def record(area: int) -> str:
    """The area's record in the committed Catalogue.lua, from its key to the next area's."""
    start = COMMITTED.index(f"\n\t\t[{area}] = {{")
    return COMMITTED[start : COMMITTED.index("\n\t\t[", start + 1)]


def test_thieves_camp_and_echo_isles_have_empty_lists() -> None:
    # DATA-R27: both carry other zones' tables in VMaNGOS and get clearBaseline = true. Each still has data, as a
    # subzone of a zone with data (DATA-R31).
    assert record(53) == (
        "\n\t\t[53] = { catches = {}, continent = 0, hasData = true, parent = 12, skillBaseConfirmed = false },"
    )
    assert record(368) == (
        "\n\t\t[368] = { catches = {}, continent = 1, hasData = true, parent = 14, skillBaseConfirmed = false },"
    )


def test_stranglethorn_vale_lists_the_extravaganza_fish_gated_by_event_301() -> None:
    # DATA-R28, DATA-R29: each added with gate = "event.301"; DATA-R78: the gate is the W entry windows["event.301"]
    # points at (Contracts), so all share one spec table.
    for item in EXTRAVAGANZA:
        entry = (
            f'{{ confirmed = false, gate = W["event.301"], gateConfirmed = false, itemID = {item},'
            ' window = "event.301" }'
        )
        assert entry in record(33)
    assert '\t\t["event.301"] = { confirmed = false, spec = W["event.301"] },\n' in COMMITTED


def test_no_noise_or_removed_item_is_listed_and_each_item_is_once_per_area() -> None:
    # DATA-R26 step 4, and "an item appears at most once per area", sorted by item ID.
    layers = read_layers(REPO)
    for area, catches in layers.catch_lists.lists.items():
        items = [catch.item for catch in catches]
        assert items == sorted(set(items)), area
        for item in items:
            shipped = layers.items[item]
            assert shipped["noise"] is False and shipped["removed"] is False, (area, item)


def test_alias_sources_and_the_new_forever_zones_have_no_data() -> None:
    # DATA-R31: an alias source ships with hasData = false and no catches; Riverglades (16591), Shen'dralas
    # (16651), Gilneas (17065) and Mount Hyjal (616, and its continent 2832 copy 16004) have no list yet.
    layers = read_layers(REPO)
    sources = [alias.source for alias in layers.forever.aliases]
    assert 16521 in sources
    for area in [*sources, 616, 16004, 16591, 16651, 17065]:
        assert re.search(r"\[\d+\] = \{ catches = \{\}, continent = \d+, hasData = false,", record(area)), area


def test_a_subzone_of_a_zone_with_data_has_data() -> None:
    # DATA-R31: "a subzone takes its zone's value". 16005 has no list of its own; its zone 618 (Winterspring) has.
    assert "\t\t\thasData = true," in record(618)
    assert "[16005] = { catches = {}, continent = 1, hasData = true, parent = 618," in record(16005)
