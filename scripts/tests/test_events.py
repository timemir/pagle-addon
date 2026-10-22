"""Hunt Events in content data (DATA-R97-R99, ADR 0012) over small fixture data/ trees: data/hunts/tags.toml,
data/hunts/events/<event-id>.toml, their checks, EventList.lua, the event Hunts' hashes and the release lock, and the
event lore in Pagle_Hunts' Lore.lua."""

import hashlib
from collections.abc import Mapping
from pathlib import Path

import pytest

from cli_fixture import run
from events_fixture import (
    EVENT_LIST,
    FINGERPRINT,
    FINGERPRINT_JSON,
    SHALLOWS,
    SUNSCALE_HASH,
    SUNSCALE_JSON,
    TAGS,
    event,
    write_event,
    write_tags,
    write_tree,
)
from hunts_fixture import write_hunts
from pagle_data.events import (
    EVENT_LIST_LUA,
    LEAST_OPEN_MINUTES,
    EventList,
    RunOpenness,
    band_of,
    event_file,
    event_hunt_hashes,
    run_openness,
)
from pagle_data.forever import WeeklyRule
from pagle_data.generate import CATALOGUE_LUA, event_list_of, read_layers
from pagle_data.hunts import HUNT_LIST_LUA

HUNTS_LORE_LUA = "addons/Pagle_Hunts/data/Lore.lua"
REPO = Path(__file__).resolve().parents[2]
LOCK = "data/hunts/released.lock"
LORE_ON = 'typicalLength = false\nlore = ["hunts"]\n'


def _event_list(root: Path) -> EventList:
    return event_list_of(read_layers(root))


def _generated(root: Path) -> dict[str, bytes | None]:
    paths = (EVENT_LIST_LUA, CATALOGUE_LUA, HUNTS_LORE_LUA)
    return {path: (root / path).read_bytes() if (root / path).exists() else None for path in paths}


def _fails(root: Path, capsys: pytest.CaptureFixture[str], *problems: str) -> str:
    """The generator fails naming every one of problems and writes nothing (DATA-R63)."""
    before = _generated(root)
    code, output = run(root, capsys)
    assert code == 1, output
    for problem in problems:
        assert problem in output
    assert _generated(root) == before
    return output


# --- The emitted list (DATA-R98) ---


def test_the_fixture_event_emits_data_r98_s_shape(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R98: ns.eventList = { fingerprint, events }, each event { id, zones, tags, skill, band, rotation, hunts },
    # each Hunt { id, species? or class?, minBand?, conditions?, tiers } with its own conditions only (HNT-R141).
    # DATA-R97: the skill left out is the lowest and highest skill base among the zones (33's 130, 14's 160), and
    # its band (low, 130 being up to 150) is added to the tags. DATA-R75: written to Pagle_Hunts' data/, guarded.
    write_tree(tmp_path)
    code, output = run(tmp_path, capsys)
    assert code == 0, output
    assert (tmp_path / EVENT_LIST_LUA).read_text(encoding="utf-8") == EVENT_LIST
    # DATA-R72, DATA-R98: the fingerprint is the first 16 hex characters of the list's canonical JSON's SHA-256.
    assert FINGERPRINT == hashlib.sha256(FINGERPRINT_JSON.encode("utf-8")).hexdigest()[:16]


def test_no_lore_is_in_event_list_lua_and_the_event_lore_lands_in_lore_lua(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R98: no lore in the list. DATA-R97, HNT-R130: event.<id>.name, event.<id>.note and hunt.<id>.name go
    # into Pagle_Hunts' one Lore.lua (DATA-R104), beside hunts.toml's keys, whether or not the check is on.
    write_tree(tmp_path)
    assert run(tmp_path, capsys)[0] == 0
    listed = (tmp_path / EVENT_LIST_LUA).read_text(encoding="utf-8")
    for lore in ("Shallow Bets", "Two coasts", "By Moonlight", "name =", "note ="):
        assert lore not in listed
    lore_lua = (tmp_path / HUNTS_LORE_LUA).read_text(encoding="utf-8")
    for line in (
        'L["event.stv_shallows.name"] = "Shallow Bets"\n',
        'L["event.stv_shallows.note"] = "Two coasts, one wager."\n',
        'L["hunt.stv_haul.name"] = "Haul"\n',
        'L["hunt.stv_moonlight.name"] = "By Moonlight"\n',
    ):
        assert line in lore_lua
    assert "data/hunts/events/" in lore_lua.splitlines()[0]  # DATA-R6: the header names the source


def test_an_empty_pool_emits_an_empty_list(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R98: with no event file (a README beside them is ignored) the list is { events = {}, fingerprint }, the
    # fingerprint over {"events":[]}.
    write_tree(tmp_path, {})
    (tmp_path / "data" / "hunts" / "events").mkdir()
    (tmp_path / "data" / "hunts" / "events" / "README.md").write_text("# The pool\n", encoding="utf-8")
    assert run(tmp_path, capsys)[0] == 0
    empty = hashlib.sha256(b'{"events":[]}').hexdigest()[:16]
    text = (tmp_path / EVENT_LIST_LUA).read_text(encoding="utf-8")
    assert text.endswith(f'ns.eventList = {{ events = {{}}, fingerprint = "{empty}" }}\n')


def test_events_are_in_event_id_order(tmp_path: Path) -> None:
    # DATA-R98: events in event-ID order (by byte, DATA-R62), whatever order the files are read in.
    write_tree(tmp_path, {"b_two": event("b_two"), "a_one": event("a_one"), "B_three": event("B_three")})
    assert [entry["id"] for entry in _event_list(tmp_path)["events"]] == ["B_three", "a_one", "b_two"]


def test_check_mode_covers_event_list_lua(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R60, DATA-R61: --check fails on a stale EventList.lua and passes once it is regenerated; an event change
    # leaves the catalogue and the Hunt list alone.
    write_tree(tmp_path)
    assert run(tmp_path, capsys)[0] == 0
    write_event(tmp_path, "stv_shallows", SHALLOWS.replace("tiers = [5, 15]", "tiers = [5, 16]"))
    code, output = run(tmp_path, capsys, "--check")
    assert code == 1
    assert f"{EVENT_LIST_LUA} is out of date with data/" in output
    assert CATALOGUE_LUA not in output and HUNT_LIST_LUA not in output
    assert run(tmp_path, capsys)[0] == 0
    assert run(tmp_path, capsys, "--check")[0] == 0


def test_a_given_skill_is_kept_and_rotation_and_retired_are_emitted(tmp_path: Path) -> None:
    # DATA-R97: a skill given is emitted as given, its band from its low end; rotation defaults to true, and
    # DATA-R98's retired date (00:00 UTC, DATA-R87) is emitted as a server time with rotation = false.
    retired = 'skill = [200, 290]\nrotation = false\nretired = 2027-01-01\n'
    write_tree(tmp_path, {"old_one": event("old_one", extra=retired)})
    (entry,) = _event_list(tmp_path)["events"]
    assert entry["skill"] == [200, 290] and entry["band"] == "mid" and entry["tags"] == ["mid"]
    assert entry["rotation"] is False and entry["retired"] == 1798761600


@pytest.mark.parametrize(
    ("low", "band"), [(-70, "low"), (150, "low"), (151, "mid"), (275, "mid"), (276, "high"), (300, "high")]
)
def test_the_band_follows_from_the_skill_s_low_end(low: int, band: str) -> None:
    # DATA-R97, HNT-R156, Tunables: low up to 150, mid 151-275, high above 275.
    assert band_of(low) == band


def test_a_band_tag_given_that_matches_is_kept_once(tmp_path: Path) -> None:
    # DATA-R97: the band is added to the tags; one already there isn't added twice.
    write_tree(tmp_path, {"one": event("one", tags='["low", "night"]')})
    assert _event_list(tmp_path)["events"][0]["tags"] == ["low", "night"]


# --- The tags (DATA-R97) ---


@pytest.mark.parametrize(
    ("tags", "problem"),
    [
        (
            TAGS + '[[tag]]\nid = "foggy"\nkind = "time"\ncolour = "grey"\n',
            "data/hunts/tags.toml: tag[17]: unknown key 'colour'",
        ),
        (
            TAGS + '[[tag]]\nid = "night"\nkind = "time"\n',
            "data/hunts/tags.toml: tag[17]: the tag ID 'night' is used twice (DATA-R97)",
        ),
        (
            TAGS + '[[tag]]\nid = "foggy"\nkind = "weather"\n',
            "data/hunts/tags.toml: tag[17].kind: expected holiday, time, water or band, got 'weather' (DATA-R97)",
        ),
        (TAGS.replace('id = "high"', 'id = "top"'), "'top' is a band tag the generator never works out"),
    ],
)
def test_a_bad_tag_list_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str], tags: str, problem: str) -> None:
    # DATA-R97: one [[tag]] per tag with id and kind; an unknown key, a repeated ID or an unknown kind fails, and the
    # band tags are the three the generator works out (low, mid, high).
    write_tree(tmp_path)
    write_tags(tmp_path, tags)
    _fails(tmp_path, capsys, problem)


# --- The event checks (DATA-R99) ---


def _shallows(old: str, new: str) -> dict[str, str]:
    assert old in SHALLOWS
    return {"stv_shallows": SHALLOWS.replace(old, new)}


SHALLOWS_FILE = event_file("stv_shallows")


@pytest.mark.parametrize(
    ("events", "problem"),
    [
        # DATA-R97: the id is the file name, matches [%w_]+ and never starts p_ (kept for pushed events).
        (
            {"p_shallows": SHALLOWS.replace('"stv_shallows"', '"p_shallows"')},
            "data/hunts/events/p_shallows.toml: event.id: 'p_shallows' starts with p_, which is kept for pushed"
            " events (DATA-R97)",
        ),
        (
            {"shallows": SHALLOWS},
            "data/hunts/events/shallows.toml: event.id: 'stv_shallows' isn't the file's name, 'shallows' (DATA-R97)",
        ),
        (
            {"stv-shallows": SHALLOWS.replace('"stv_shallows"', '"stv-shallows"')},
            "event.id: 'stv-shallows' doesn't match [%w_]+ (DATA-R97)",
        ),
        # DATA-R97: 1-2 zones, each a zone (parent 0) of the slice.
        (
            _shallows("zones = [33, 14]", "zones = [33, 14, 12]"),
            f"{SHALLOWS_FILE}: event.zones: has 3 zones; an event has 1 or 2 (DATA-R97)",
        ),
        (
            _shallows("zones = [33, 14]", "zones = []"),
            f"{SHALLOWS_FILE}: event.zones: has 0 zones; an event has 1 or 2 (DATA-R97)",
        ),
        (
            _shallows("zones = [33, 14]", "zones = [33, 297]"),
            "event.zones: area 297 isn't a zone (parent 0) in data/db2/areas.csv (DATA-R97)",
        ),
        # DATA-R97: tags from tags.toml's closed list; DATA-R63: an unknown key.
        (
            _shallows('tags = ["coast"]', 'tags = ["coast", "foggy"]'),
            f"{SHALLOWS_FILE}: event.tags: 'foggy' isn't a tag in data/hunts/tags.toml (DATA-R97)",
        ),
        (
            _shallows('tags = ["coast"]', 'tags = ["mid"]'),
            "event.tags: 'mid' is a band tag, and the event's band is low; the generator adds the band (DATA-R97)",
        ),
        (
            _shallows('name = "Shallow Bets"', 'name = "Shallow Bets"\ncolour = "blue"'),
            f"{SHALLOWS_FILE}: event: unknown key 'colour'",
        ),
        (_shallows('name = "Shallow Bets"\n', ""), f"{SHALLOWS_FILE}: event: missing key 'name'"),
        (
            _shallows("zones = [33, 14]", "zones = [33, 14]\nskill = [160, 130]"),
            "event.skill: expected [low, high], two integers with low <= high (DATA-R97)",
        ),
        # DATA-R99: 3 to 5 Hunts.
        ({"two": event("two", 2)}, "data/hunts/events/two.toml: has 2 Hunts; an event has 3 to 5 (DATA-R99)"),
        ({"six": event("six", 6)}, "data/hunts/events/six.toml: has 6 Hunts; an event has 3 to 5 (DATA-R99)"),
        # DATA-R99, HNT-R141: an areas condition of its own; DATA-R92's Hunt checks.
        (
            _shallows("conditions = { time = [[1320, 240]] }", "conditions = { areas = [33], time = [[1320, 240]] }"),
            f"{SHALLOWS_FILE}: hunt.stv_moonlight.conditions: has an areas condition of its own; the event's zones"
            " supply it (HNT-R141, DATA-R99)",
        ),
        (_shallows("minBand = 3", "minBand = 5"), "hunt.stv_big_nightfin.minBand: expected 2 to 4, got 5 (DATA-R89)"),
        (
            _shallows("tiers = [5, 15]", "tiers = [15, 5]"),
            "hunt.stv_sunscale.tiers: expected strictly ascending positive integers",
        ),
        (
            _shallows('id = "stv_haul"', 'id = "stv haul"'),
            "hunt.stv haul.id: 'stv haul' doesn't match [%w_]+ (DATA-R92)",
        ),
        (
            _shallows('class = "species.any"\ntiers = [20', 'class = "fixed.nothing"\ntiers = [20'),
            "hunt.stv_haul.class: 'fixed.nothing' is neither a [[class]] in data/hunts/hunts.toml nor a generated"
            " class",
        ),
        (
            _shallows("species = 13760", "species = 13760\nclass = \"species.any\""),
            "hunt.stv_sunscale: has both a species and a class target; give one (DATA-R86)",
        ),
        (
            _shallows("species = 13760", "species = 6358"),
            "hunt.stv_sunscale.species: 6358 isn't a Species item (DATA-R19, DATA-R92)",
        ),
        (
            _shallows("conditions = { time", "conditions = { auras = [7], time"),
            "hunt.stv_moonlight.conditions: auras: 7 isn't on the aura list (DATA-R39)",
        ),
        # DATA-R99: a Hunt that can't complete in the event's zones and their subzones.
        (
            _shallows("species = 13760", "species = 6291"),
            f"{SHALLOWS_FILE}: hunt.stv_sunscale.species: Species 6291 isn't listed in zones 33 and 14 or their"
            " subzones, so the Hunt can't complete there (DATA-R99)",
        ),
        (
            {"elwynn": event("elwynn", zones="[12]", hunt_body='class = "quality.uncommon"\n')},
            "data/hunts/events/elwynn.toml: hunt.elwynn_1.class: no item of quality.uncommon is listed in zone 12 or"
            " its subzones, so the Hunt can't complete there (DATA-R99)",
        ),
    ],
)
def test_each_event_check_fails_naming_the_event_or_hunt(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], events: dict[str, str], problem: str
) -> None:
    # DATA-R99, DATA-R63: each check fails the generator, naming the event's file and the event or Hunt, and writes
    # nothing.
    write_tree(tmp_path, events)
    _fails(tmp_path, capsys, problem)


def test_a_fixed_class_needs_one_member_listed_in_the_zones(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: a fixed.* target fails only when every member is unlisted there: 6291 is listed in Elwynn Forest (12,
    # with Crystal Lake 18), 13760 isn't; in Durotar (14) neither is.
    write_tree(tmp_path, {"elwynn": event("elwynn", zones="[12]", hunt_body='class = "fixed.pair"\n')})
    write_hunts(tmp_path, '[[class]]\nid = "fixed.pair"\nmembers = [6291, 6303]\n')
    assert run(tmp_path, capsys)[0] == 0
    write_event(tmp_path, "elwynn", event("elwynn", zones="[14]", hunt_body='class = "fixed.pair"\n'))
    output = _fails(
        tmp_path,
        capsys,
        "data/hunts/events/elwynn.toml: hunt.elwynn_1.class: no member of fixed.pair is listed in zone 14 or its"
        " subzones, so the Hunt can't complete there (DATA-R99)",
    )
    assert "hunt.elwynn_3.class: no member" in output


def test_a_species_listed_only_in_a_subzone_completes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99, HNT-R141, LOG-R48: the event's zones and their subzones: 13759 is listed in Echo Isles (368), a
    # subzone of Durotar (14), and nowhere in Durotar itself.
    write_tree(tmp_path, {"durotar": event("durotar", zones="[14]", hunt_body="species = 13759\n")})
    assert run(tmp_path, capsys)[0] == 0


def test_a_zone_without_a_skill_base_needs_a_given_skill(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97, LOG-R55: Riverglades (16591) has no skill base, so the skill can't be worked out; given, it's kept.
    hunt_body = 'class = "species.any"\nconditions = { time = [[0, 1380]] }\n'
    write_tree(tmp_path, {"glades": event("glades", zones="[33, 16591]", hunt_body=hunt_body)})
    _fails(
        tmp_path,
        capsys,
        "data/hunts/events/glades.toml: event.zones: zone 16591 has no skill base, so the skill can't be worked out;"
        " give skill = [low, high] (DATA-R97, LOG-R55)",
    )
    given = event("glades", zones="[33, 16591]", extra="skill = [130, 140]\n", hunt_body=hunt_body)
    write_event(tmp_path, "glades", given)
    assert run(tmp_path, capsys)[0] == 0


def test_hunt_ids_are_unique_across_the_hunt_list_and_every_event(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, DATA-R92: an event Hunt's ID repeats one in hunts.toml, or another event's.
    two = SHALLOWS.replace("stv_shallows", "two").replace("stv_haul", "one_1")
    write_tree(tmp_path, {"one": event("one"), "two": two})
    standing = (
        '[[set]]\nid = "s"\nname = "S"\ntitle = "the S"\n\n[[hunt]]\nid = "stv_sunscale"\nset = "s"\n'
        'kind = "imposed"\nsince = 2026-11-04\nclass = "species.any"\nconditions = { auras = [1] }\ntiers = [1]\n'
        'name = "X"\n'
    )
    write_hunts(tmp_path, standing)
    (tmp_path / "data" / "forever" / "lists.toml").write_text("auras = [1]\nfishingSpells = [7620]\n", encoding="utf-8")
    _fails(
        tmp_path,
        capsys,
        "data/hunts/events/two.toml: hunt.one_1: the Hunt ID 'one_1' is used twice (DATA-R92, DATA-R99)",
        "data/hunts/events/two.toml: hunt.stv_sunscale: the Hunt ID 'stv_sunscale' is used twice (DATA-R92, DATA-R99)",
    )


def test_several_problems_are_all_listed_in_one_run(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: every problem found, in every event file, before the generator fails writing nothing.
    events = {
        "p_one": event("p_one", zones="[33, 14, 12]"),
        "two": event("two", 2, tags='["foggy"]'),
        "stv_shallows": SHALLOWS.replace("species = 13760", "species = 6291"),
    }
    write_tree(tmp_path, events)
    _fails(
        tmp_path,
        capsys,
        "p_one.toml: event.id: 'p_one' starts with p_",
        "p_one.toml: event.zones: has 3 zones",
        "two.toml: has 2 Hunts",
        "two.toml: event.tags: 'foggy' isn't a tag",
        "stv_shallows.toml: hunt.stv_sunscale.species: Species 6291 isn't listed",
    )


def test_a_retired_event_is_held_to_its_format_but_not_to_completing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R98, DATA-R99, ADR 0005: a retired event never runs again and its definition never changes, so data that
    # no longer lists its Species doesn't fail it (as a retired Hunt needs no admission, DATA-R92).
    retired = SHALLOWS.replace("species = 13760", "species = 6291").replace(
        'tags = ["coast"]', 'tags = ["coast"]\nrotation = false\nretired = 2027-01-01'
    )
    write_tree(tmp_path, {"stv_shallows": retired})
    assert run(tmp_path, capsys)[0] == 0


# --- The closed-stretch check for Timed Hunts (DATA-R99, Tunables) ---

HOUR = 60


@pytest.mark.parametrize(
    ("spec", "closed", "least_open"),
    [
        # hunts.md › The 1.0 event pool, the four seed Timed Hunts: open 3-6 hours a day.
        ({"time": [[1320, 240]]}, 18 * HOUR, 18 * HOUR),  # darkshore_moonlight, 22:00-04:00
        ({"time": [[0, 180]]}, 21 * HOUR, 9 * HOUR),  # duskwood_witching, 00:00-03:00
        ({"time": [[1080, 1260]]}, 21 * HOUR, 9 * HOUR),  # barrens_oddities, 18:00-21:00
        ({"time": [[300, 480]]}, 21 * HOUR, 9 * HOUR),  # alterac_dawn_trout, 05:00-08:00
        # Open on one weekday only: event 302's weekly rule, Wednesdays 10:00 for 3 hours.
        ({"events": [302]}, 7 * 24 * HOUR - 3 * HOUR, 0),
        # No time-based field: never closed.
        ({"auras": [1280341]}, 0, 72 * HOUR),
    ],
)
def test_a_timed_hunt_s_longest_closed_stretch_and_open_time_per_run(
    spec: dict[str, object], closed: int, least_open: int
) -> None:
    # DATA-R99: the longest closed stretch over the week's time and events, wrapping across realm midnight and the
    # week's end, and the least time open in any 72-hour run (both in minutes), computed for #297's decision.
    found = run_openness(spec, {301: WeeklyRule(1, 840, 120), 302: WeeklyRule(4, 600, 180)})
    assert (found.longest_closed, found.least_open) == (closed, least_open)


def test_a_hunt_open_3_hours_on_one_weekday_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99, Tunables: a time-based condition that keeps the Hunt closed for more than half of a 72-hour run
    # (36 hours) fails, naming the Hunt; the seed shape, 3 hours every day, passes.
    weekly = 'class = "species.any"\nconditions = { events = [302] }\n'
    write_tree(tmp_path, {"weekly": event("weekly", hunt_body=weekly)})
    events_toml = tmp_path / "data" / "forever" / "events.toml"
    events_toml.write_text(
        events_toml.read_text(encoding="utf-8") + "[event.302]\nweekday = 4\nstart = 600\nduration = 180\n",
        encoding="utf-8",
    )
    _fails(
        tmp_path,
        capsys,
        "data/hunts/events/weekly.toml: hunt.weekly_1.conditions: closed 6 days 21 hours running, more than half of"
        " a 72-hour run (36 hours); a run can have it open as little as 0 minutes (DATA-R99)",
    )
    daily = 'class = "species.any"\nconditions = { time = [[0, 180]] }\n'
    write_event(tmp_path, "weekly", event("weekly", hunt_body=daily))
    assert run(tmp_path, capsys)[0] == 0


def test_a_hunt_open_15_minutes_a_day_fails_the_floor(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99, Tunables: open 00:00-00:15 every day, the Hunt is closed only 23 hours 45 minutes at a stretch, but a
    # run has it open 45 minutes, less than the 3 hours every run needs (the dev's decision, 22 Oct); it fails,
    # naming the event's file, the Hunt and its least open time per run.
    brief = 'class = "species.any"\nconditions = { time = [[0, 15]] }\n'
    write_tree(tmp_path, {"brief": event("brief", hunt_body=brief)})
    _fails(
        tmp_path,
        capsys,
        "data/hunts/events/brief.toml: hunt.brief_1.conditions: a run can have it open as little as 45 minutes, less"
        " than the 3 hours every 72-hour run needs (DATA-R99)",
    )


def test_a_hunt_open_1_hour_a_day_meets_the_floor(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99, Tunables: open 00:00-01:00 every day, a run has it open exactly 3 hours, the floor, so it passes.
    hourly = 'class = "species.any"\nconditions = { time = [[0, 60]] }\n'
    write_tree(tmp_path, {"hourly": event("hourly", hunt_body=hourly)})
    assert run_openness({"time": [[0, 60]]}, {}).least_open == LEAST_OPEN_MINUTES
    code, output = run(tmp_path, capsys)
    assert code == 0, output


def test_every_timed_hunt_in_the_shipped_pool_meets_the_floor() -> None:
    # DATA-R99, Tunables: the 1.0 pool's Timed Hunts are each open at least 9 hours in every run, over the floor of 3
    # and closed no more than 36 hours at a stretch.
    layers = read_layers(REPO)
    timed: dict[str, RunOpenness] = {}
    for found_event in layers.events.events:
        for hunt in found_event.hunts:
            conditions = hunt.get("conditions")
            if isinstance(conditions, Mapping) and {"time", "events"} & set(conditions):
                timed[hunt.id] = run_openness(conditions, layers.forever.events)
    assert timed
    assert all(found.fits for found in timed.values()), timed
    assert min(found.least_open for found in timed.values()) >= 9 * HOUR


# --- The pool minimum (DATA-R99, DATA-R66) ---

SKILLS = {"low": "[100, 150]", "mid": "[200, 250]", "high": "[300, 325]"}


def _pool(counts: dict[str, int], extra: dict[str, str] | None = None) -> dict[str, str]:
    events: dict[str, str] = {}
    for band, count in counts.items():
        for index in range(count):
            event_id = f"{band}_{index}"
            events[event_id] = event(event_id, extra=f"skill = {SKILLS[band]}\n" + (extra or {}).get(event_id, ""))
    return events


def _checks(root: Path, event_pool: bool) -> None:
    (root / "data" / "checks.toml").write_text(
        f"typicalLength = false\nlore = []\neventPool = {str(event_pool).lower()}\n", encoding="utf-8"
    )


def test_with_the_event_pool_check_on_a_band_with_7_rotating_events_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, Tunables: a band with fewer rotating events than the minimum per band (8) fails the pool.
    write_tree(tmp_path, _pool({"low": 8, "mid": 8, "high": 7}))
    _checks(tmp_path, True)
    output = _fails(
        tmp_path,
        capsys,
        "data/hunts/events: the high band has 7 rotating events (rotation = true, not retired); the pool needs at"
        " least 8 per band (DATA-R99)",
    )
    assert "the low band" not in output and "the mid band" not in output


@pytest.mark.parametrize("eighth", ["rotation = false\n", "retired = 2027-01-01\n"])
def test_a_retired_or_non_rotating_event_doesn_t_count(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], eighth: str
) -> None:
    # DATA-R99, HNT-R152: only rotating events count: rotation = true and no retired date.
    write_tree(tmp_path, _pool({"low": 8, "mid": 8, "high": 8}, {"high_7": eighth}))
    _checks(tmp_path, True)
    _fails(tmp_path, capsys, "the high band has 7 rotating events")


def test_eight_rotating_events_a_band_pass(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: 8 a band pass.
    write_tree(tmp_path, _pool({"low": 8, "mid": 8, "high": 8}))
    _checks(tmp_path, True)
    assert run(tmp_path, capsys)[0] == 0


@pytest.mark.parametrize("event_pool", [False, None])
def test_the_pool_minimum_is_off_until_switched_on(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], event_pool: bool | None
) -> None:
    # DATA-R66: before eventPool is on (false, or left out), the check is skipped and the data is still emitted.
    write_tree(tmp_path, _pool({"low": 1}))
    if event_pool is not None:
        _checks(tmp_path, event_pool)
    assert run(tmp_path, capsys)[0] == 0
    assert len(_event_list(tmp_path)["events"]) == 1


def test_a_non_boolean_event_pool_switch_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R66, DATA-R63: a wrong type in checks.toml.
    write_tree(tmp_path)
    checks = "typicalLength = false\nlore = []\neventPool = 1\n"
    (tmp_path / "data" / "checks.toml").write_text(checks, encoding="utf-8")
    _fails(tmp_path, capsys, "data/checks.toml: eventPool: expected a boolean, got an integer")


# --- Hashes, the fingerprint and the lock (DATA-R94-R96, DATA-R98) ---


def _hashes(root: Path) -> tuple[dict[str, str], str]:
    event_list = _event_list(root)
    return event_hunt_hashes(event_list), event_list["fingerprint"]


def test_an_event_hunt_s_hash_is_over_its_record_and_its_event_s_id_and_zones(tmp_path: Path) -> None:
    # DATA-R98, DATA-R94: the lowercase hex SHA-256 of the canonical JSON of the emitted record with its event's id
    # (as event) and zones; events_fixture works it out by hand with sha256sum.
    hashes, fingerprint = _hashes(write_tree(tmp_path))
    assert hashes["stv_sunscale"] == SUNSCALE_HASH == hashlib.sha256(SUNSCALE_JSON.encode("utf-8")).hexdigest()
    assert fingerprint == FINGERPRINT


@pytest.mark.parametrize(
    ("old", "new"),
    [("tiers = [5, 15]", "tiers = [5, 16]"), ("zones = [33, 14]", "zones = [33]")],
)
def test_changing_tiers_or_zones_changes_the_hash_and_the_fingerprint(tmp_path: Path, old: str, new: str) -> None:
    # DATA-R98: tiers are in the record, the event's zones in the hash; both are in the list, so in the fingerprint.
    before, fingerprint = _hashes(write_tree(tmp_path))
    after, changed = _hashes(write_tree(tmp_path, {"stv_shallows": SHALLOWS.replace(old, new)}))
    assert after["stv_sunscale"] != before["stv_sunscale"]
    assert changed != fingerprint


def test_changing_a_name_or_note_changes_neither(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97, DATA-R98, DATA-R109: lore is never in a record, a hash or the fingerprint, but it lands in Lore.lua.
    before = _hashes(write_tree(tmp_path))
    reworded = SHALLOWS.replace("Shallow Bets", "Shallow Odds").replace("one wager", "two wagers")
    reworded = reworded.replace('name = "Sunscale"', 'name = "Salmon Run"')
    assert _hashes(write_tree(tmp_path, {"stv_shallows": reworded})) == before
    assert run(tmp_path, capsys)[0] == 0
    lore_lua = (tmp_path / HUNTS_LORE_LUA).read_text(encoding="utf-8")
    assert '"Shallow Odds"' in lore_lua and '"Two coasts, two wagers."' in lore_lua and '"Salmon Run"' in lore_lua


def test_lock_writes_the_event_hunts_hashes_and_their_classes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R95, DATA-R98: --lock records each event Hunt under [hunt.<id>] beside the Standing Hunts, by ascending
    # ID, and the members of each class an event Hunt targets.
    write_tree(tmp_path)
    code, output = run(tmp_path, capsys, "--lock")
    assert code == 0, output
    lock = (tmp_path / LOCK).read_text(encoding="utf-8")
    assert f'[hunt.stv_sunscale]\nhash = "{SUNSCALE_HASH}"\n' in lock
    assert lock.index("[hunt.stv_big_nightfin]") < lock.index("[hunt.stv_haul]") < lock.index("[hunt.stv_moonlight]")
    assert '[class."species.any"]\nmembers = [6291, 6303, 6309, 13759, 13760, 19803, 19807]\n' in lock


def test_against_the_lock_a_changed_or_deleted_event_hunt_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R98, DATA-R96, ADR 0005: a locked event Hunt whose hash differs, or that is missing (its file deleted),
    # fails; a wording change doesn't.
    write_tree(tmp_path)
    assert run(tmp_path, capsys, "--lock")[0] == 0
    write_event(tmp_path, "stv_shallows", SHALLOWS.replace("Shallow Bets", "Shallow Odds"))
    assert run(tmp_path, capsys)[0] == 0
    write_event(tmp_path, "stv_shallows", SHALLOWS.replace("zones = [33, 14]", "zones = [33]"))
    _fails(
        tmp_path,
        capsys,
        f"{SHALLOWS_FILE}: hunt.stv_sunscale: differs from the released Hunt (its hash, over its record and its"
        f" event's id and zones, isn't the one in {LOCK}); a released event never changes: ship the fix as a new"
        " event and retire this one (DATA-R96, DATA-R98, ADR 0005)",
    )
    (tmp_path / SHALLOWS_FILE).unlink()
    _fails(
        tmp_path,
        capsys,
        f"{LOCK}: hunt.stv_sunscale: the released Hunt is gone from data/hunts/hunts.toml and data/hunts/events/;"
        " retire a Standing Hunt with a retired date instead, and an event leaves the pool by rotation = false and a"
        " retired date, never by deleting it (DATA-R96, DATA-R98, ADR 0005)",
    )


# --- The event lore (DATA-R97, DATA-R107, HNT-R130) ---


def _lore_on(root: Path) -> None:
    (root / "data" / "checks.toml").write_text(LORE_ON, encoding="utf-8")
    lore = root / "data" / "lore"
    lore.mkdir(parents=True, exist_ok=True)
    (lore / "hunts.toml").write_text("", encoding="utf-8")


@pytest.mark.parametrize(
    ("old", "new", "problem"),
    [
        (
            'name = "Shallow Bets"',
            'name = "Shallow Bets on the Long Coast"',
            f"{SHALLOWS_FILE}: event.stv_shallows.name: length: 30 code points, over name's limit of 28 (DATA-R107)",
        ),
        ('name = "Haul"', 'name = "  "', f"{SHALLOWS_FILE}: hunt.stv_haul.name: missing: empty (DATA-R105, DATA-R107)"),
        ('note = "Two coasts, one wager."', 'note = "Two {zone} coasts"', "event.stv_shallows.note: placeholder"),
    ],
)
def test_the_hunts_lore_check_covers_the_event_lore(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], old: str, new: str, problem: str
) -> None:
    # DATA-R99, DATA-R107: with the hunts lore check on, event and Hunt names have the name limit (28), the note none,
    # and an empty name is missing; the check is off in the other fixtures, where this text still passes.
    write_tree(tmp_path, _shallows(old, new))
    assert run(tmp_path, capsys)[0] == 0
    _lore_on(tmp_path)
    _fails(tmp_path, capsys, problem)


def test_a_long_note_passes_the_lore_check(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: no limit for the note.
    write_tree(tmp_path, _shallows('note = "Two coasts, one wager."', f'note = "{"A long note. " * 30}"'))
    _lore_on(tmp_path)
    assert run(tmp_path, capsys)[0] == 0


def test_a_glyph_in_event_lore_fails_whatever_the_check(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R107's glyph, CORE-R9: every lore text, its check on or off.
    write_tree(tmp_path, _shallows('name = "Haul"', 'name = "Haul ✓"'))
    _fails(tmp_path, capsys, f"{SHALLOWS_FILE}: hunt.stv_haul.name: glyph: U+2713 outside CORE-R9's set")


def test_event_text_in_the_hunts_lore_file_is_an_orphan(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97, DATA-R107: an event's text stays in its own file; event is Hunts' kind, never in data/lore/.
    write_tree(tmp_path)
    _lore_on(tmp_path)
    elsewhere = '[event.stv_shallows]\nname = "Elsewhere"\n'
    (tmp_path / "data" / "lore" / "hunts.toml").write_text(elsewhere, encoding="utf-8")
    _fails(
        tmp_path,
        capsys,
        "data/lore/hunts.toml: event.stv_shallows.name: orphan: an event's text stays in its file in"
        " data/hunts/events/ (DATA-R97, DATA-R107)",
    )
