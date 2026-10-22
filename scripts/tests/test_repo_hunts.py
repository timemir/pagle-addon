"""The repo's own Hunt list (DATA-R85-R94): data/hunts/hunts.toml and the HuntList.lua it generates."""

from collections.abc import Mapping
from pathlib import Path

from pagle_data.generate import Layers, hunt_list_of, read_layers
from pagle_data.hunts import HUNT_LIST_LUA, HuntList
from pagle_data.realm_time import open_steps

REPO = Path(__file__).resolve().parents[2]


def test_the_committed_hunt_list_defines_the_addon_registry() -> None:
    committed = (REPO / HUNT_LIST_LUA).read_text(encoding="utf-8")
    assert "ns.huntList = {" in committed


def test_the_committed_list_emits_the_three_generated_classes_over_the_catalogue() -> None:
    # DATA-R91: quality.uncommon, quality.rare and species.any are always emitted, each holding only items that ship.
    # species.any holds hunts.md's v1 Species targets (by their enUS names in items.csv: Raw Nightfin Snapper, Raw
    # Sunscale Salmon, Brownell's Blue Striped Racer, Raw Mithril Head Trout), Whimsyfin, and 6887 Spotted Yellowtail,
    # an item folded into Species 4603 (DATA-R19), which is still a Species item.
    layers = read_layers(REPO)
    classes = hunt_list_of(layers)["classes"]
    assert {"quality.uncommon", "quality.rare", "species.any"} <= classes.keys()
    assert {13759, 13760, 19803, 8365, 251524, 6887, 4603} <= classes["species.any"].keys()
    for members in classes.values():
        assert set(members) <= layers.items.keys()


# hunts.md › Data, "The Standing Hunt list": the four sets and the 12 Hunts in table order, each as (id, set, kind,
# target, window or conditions, tiers). Written from the table, not from hunts.toml, so the file can't drift from the
# spec. House Wagers left the list and its four Hunts became pool events (#286).
V1_SETS = ["round_the_clock", "turn_of_the_year", "sunday_showdown", "camp_hours"]
V1_HUNTS: list[tuple[str, str, str, tuple[str, object], tuple[str, object], list[int]]] = [
    ("night_run", "round_the_clock", "natural", ("species", 13759), ("window", "night"), [1, 10, 40]),
    ("first_light", "round_the_clock", "natural", ("species", 13760), ("window", "day"), [1, 10, 40]),
    ("live_wire", "round_the_clock", "natural", ("species", 13757), ("window", "day"), [1, 10]),
    ("armoured_after_dark", "round_the_clock", "natural", ("species", 13890), ("window", "night"), [1, 5]),
    ("summers_bass", "turn_of_the_year", "natural", ("species", 13756), ("window", "summer"), [1, 10, 40]),
    ("winters_squid", "turn_of_the_year", "natural", ("species", 13755), ("window", "winter"), [1, 10, 40]),
    ("tastyfish_haul", "sunday_showdown", "natural", ("species", 19807), ("window", "event.301"), [1, 10, 40]),
    ("riggles_angelfish", "sunday_showdown", "natural", ("species", 19805), ("window", "event.301"), [1]),
    ("riggles_queenfish", "sunday_showdown", "natural", ("species", 19806), ("window", "event.301"), [1]),
    ("riggles_racer", "sunday_showdown", "natural", ("species", 19803), ("window", "event.301"), [1]),
    (
        "rack_hour",
        "camp_hours",
        "imposed",
        ("class", "quality.uncommon"),
        ("conditions", {"auras": [1280341]}),
        [1, 10, 25],
    ),
    ("hut_hour", "camp_hours", "imposed", ("class", "species.any"), ("conditions", {"auras": [1280342]}), [1, 5, 15]),
]
# DATA-R87, Tunables: every v1 `since` is the pre-1.0 placeholder 2026-11-04, 00:00 UTC (`date -u -d 2026-11-04 +%s`).
PLACEHOLDER_SINCE = 1793750400


def test_the_committed_list_is_hunts_md_v1_table_in_order() -> None:
    # hunts.md › Data (the Standing Hunt list), HNT-R1 (display order is file order), DATA-R87 and DATA-R93: the four
    # sets and the 12 Hunts in table order, every since the pre-1.0 placeholder, none retired and none with a minBand.
    hunt_list = hunt_list_of(read_layers(REPO))
    assert [entry["id"] for entry in hunt_list["sets"]] == V1_SETS
    expected = [
        {"id": hunt_id, "set": set_id, "kind": kind, "since": PLACEHOLDER_SINCE, target[0]: target[1], spec[0]: spec[1]}
        | {"tiers": tiers}
        for hunt_id, set_id, kind, target, spec, tiers in V1_HUNTS
    ]
    assert hunt_list["hunts"] == expected


def test_the_committed_list_has_the_one_fixed_class_and_the_generated_classes() -> None:
    # hunts.md › Data: "The one fixed class: fixed.oddity, members 6522 (Deviate Fish) and 251524 (Whimsyfin)";
    # DATA-R91: quality.uncommon and species.any hold the catalogue's uncommon-or-better and Species items.
    classes = hunt_list_of(read_layers(REPO))["classes"]
    assert [class_id for class_id in classes if class_id.startswith("fixed.")] == ["fixed.oddity"]
    assert classes["fixed.oddity"] == {6522: True, 251524: True}
    assert classes["quality.uncommon"] and classes["species.any"]


# hunts.md › Data: "The M5 build ticket checks every item and area ID above against data/db2/ by its enUS name". Each
# ID with its name as data/db2/ gives it (items.csv's Display_lang, areas.csv's AreaName_lang); hunts.md's bracketed
# names are the intent. No Standing Hunt names an area since House Wagers left the list (#286).
V1_ITEM_NAMES = {
    13759: "Raw Nightfin Snapper",
    13760: "Raw Sunscale Salmon",
    13757: "Lightning Eel",
    13890: "Raw Plated Armorfish",
    13756: "Raw Summer Bass",
    13755: "Raw Winter Squid",
    19807: "Speckled Tastyfish",
    19805: "Keefer's Angelfish",
    19806: "Dezian Queenfish",
    19803: "Brownell's Blue Striped Racer",
    6522: "Deviate Fish",
    251524: "Whimsyfin",
}
V1_AREA_NAMES: dict[int, str] = {}
# DATA-R39's aura list, as data/forever/lists.toml's comment names them, and DATA-R38's event list.
V1_AURAS = {1280341: "Rack", 1280342: "Hut"}
V1_EVENTS = {301}


def _v1_ids(hunt_list: HuntList) -> tuple[set[int], set[int], set[int], set[int]]:
    """Every item, area, aura and event ID the emitted list names: Species targets and fixed class members, and the
    conditions' areas, auras and events (the event of an event.<eventID> window too)."""
    items: set[int] = set()
    areas: set[int] = set()
    auras: set[int] = set()
    events: set[int] = set()
    for class_id, members in hunt_list["classes"].items():
        if class_id.startswith("fixed."):
            items |= members.keys()
    for record in hunt_list["hunts"]:
        species = record.get("species")
        if isinstance(species, int):
            items.add(species)
        window = record.get("window")
        if isinstance(window, str) and window.startswith("event."):
            events.add(int(window.removeprefix("event.")))
        conditions = record.get("conditions", {})
        assert isinstance(conditions, dict)
        areas |= set(conditions.get("areas", []))
        auras |= set(conditions.get("auras", []))
        events |= set(conditions.get("events", []))
    return items, areas, auras, events


def test_every_v1_id_is_the_item_area_aura_or_event_hunts_md_names() -> None:
    # hunts.md › Data (each ID checked by its enUS name, so a DB2 refresh that renames one fails here), DATA-R38 and
    # DATA-R39 (a condition's events and auras are on the lists), DATA-R86 and DATA-R19 (a species target is a
    # Species item: its own record's species is itself).
    layers = read_layers(REPO)
    items, areas, auras, events = _v1_ids(hunt_list_of(layers))
    assert (items, areas, auras, events) == (set(V1_ITEM_NAMES), set(V1_AREA_NAMES), set(V1_AURAS), V1_EVENTS)
    assert {item: layers.db2.items[item].name for item in items} == V1_ITEM_NAMES
    assert {area: layers.db2.areas[area].name for area in areas} == V1_AREA_NAMES
    assert auras <= set(layers.forever.auras)
    assert events <= layers.forever.events.keys()
    for record in hunt_list_of(layers)["hunts"]:
        species = record.get("species")
        if isinstance(species, int):
            assert layers.items[species]["species"] == species, record["id"]


def _time_fields(spec: Mapping[str, object]) -> dict[str, object]:
    """A spec's time fields (HNT-R6): time, season and events."""
    return {key: spec[key] for key in ("time", "season", "events") if key in spec}


def _reachable(record: Mapping[str, object], layers: Layers, classes: Mapping[str, Mapping[int, bool]]) -> list[int]:
    """The items that can qualify for the Hunt in today's catalogue: its target's items (HNT-R10) with a catch entry
    somewhere that it can bite at. A natural Hunt needs a catch entry gated by its window (DATA-R92's admission). An
    imposed Hunt needs a catch entry in one of its conditions' areas, the area itself or a subzone of it (LOG-R48), at
    a realm time when both the entry's gate (ungated: always) and its conditions' time fields are open."""
    if "species" in record:
        targets = {item for item, fields in layers.items.items() if fields.get("species") == record["species"]}
    else:
        targets = set(classes[str(record["class"])])
    conditions = record.get("conditions")
    if not isinstance(conditions, dict):  # natural
        return sorted(
            {
                catch.item
                for catches in layers.catch_lists.lists.values()
                for catch in catches
                if catch.item in targets and catch.window == record["window"]
            }
        )
    rules = layers.forever.events
    wanted = open_steps(_time_fields(conditions), rules)
    overlaps: dict[str | None, bool] = {}  # by gate: whether it is open at a step the conditions are

    def bites(gate: str | None) -> bool:
        if gate not in overlaps:
            steps = open_steps(_time_fields(layers.windows[gate]), rules) if gate else bytearray(b"\x01" * len(wanted))
            overlaps[gate] = any(want and step for want, step in zip(wanted, steps))
        return overlaps[gate]

    areas = set(conditions.get("areas", []))
    reachable = set()
    for area, catches in layers.catch_lists.lists.items():
        if areas and not {area, layers.db2.areas[area].parent} & areas:
            continue
        reachable |= {catch.item for catch in catches if catch.item in targets and bites(catch.window)}
    return sorted(reachable)


def test_every_v1_hunt_can_be_completed_in_todays_catalogue() -> None:
    # HNT-R10 and HNT-R17 (a Hunt is done at its first qualifying Catch), DATA-R92 (admission: a natural Hunt's window
    # gates its Species somewhere). A target whose items no catch list holds where and when its window or conditions
    # are open could never be done: hunts.md's Hut Hour on quality.rare was one, as no non-Noise item is rare today.
    layers = read_layers(REPO)
    hunt_list = hunt_list_of(layers)
    hunts = hunt_list["hunts"]
    assert [record["id"] for record in hunts if not _reachable(record, layers, hunt_list["classes"])] == []
