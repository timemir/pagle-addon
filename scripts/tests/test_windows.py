"""The named windows (DATA-R35–R38): the baseline seeds, windows.toml and the event windows."""

from pathlib import Path

import pytest

from areas_fixture import write_areas
from baseline_fixture import CSVS, EVENTS_CSV_HEADER, SEED_EVENTS, write_baseline
from item_fixture import write_item_layer
from observed_fixture import write_observed
from pagle_data.baseline import BaselineEvent
from pagle_data.errors import DataError
from pagle_data.generate import read_layers
from pagle_data.windows import seed_spec, window_of_event
from pools_fixture import write_pools
from windows_fixture import WINDOWS, write_windows

# The Extravaganza with its weekly rule, and an event without one (DATA-R38).
EVENTS = "[event.301]\nweekday = 1\nstart = 840\nduration = 120\n\n[event.7]\n"


def write_tree(root: Path, windows: str = WINDOWS, events_csv: str | None = None) -> Path:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "events.toml").write_text(EVENTS, encoding="utf-8")
    (forever / "lists.toml").write_text("auras = []\nfishingSpells = [7620]\n", encoding="utf-8")
    (forever / "aliases.toml").write_text("", encoding="utf-8")
    write_windows(root, windows)
    write_areas(root)  # test_catch_lists.py covers areas.toml
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text('build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n', encoding="utf-8")
    (db2 / "areas.csv").write_text("ID,ParentAreaID,ContinentID,AreaName_lang\n", encoding="utf-8")
    (db2 / "items.csv").write_text("ID,ClassID,SubclassID,OverallQualityID,Display_lang\n", encoding="utf-8")
    write_baseline(root, CSVS if events_csv is None else {**CSVS, "events.csv": events_csv})
    write_observed(root)  # dev.toml with no facts; test_observed.py covers the layer
    write_item_layer(root)  # test_item_records.py covers the item layer
    write_pools(root)  # test_pools.py covers pool types
    return root


def problems(root: Path) -> list[str]:
    """What the generator reports for root/data/; none when it reads cleanly."""
    try:
        read_layers(root)
    except DataError as error:
        return error.problems
    return []


def test_every_named_window_and_each_ruled_event_has_a_window(tmp_path: Path) -> None:
    # DATA-R35: day, night, spring, summer, autumn, winter, and event.<id> for each event with a weekly rule.
    # DATA-R36: day, night, summer and winter from the baseline seeds 47, 48, 45, 46; spring and autumn from
    # windows.toml. DATA-R37: event.301 is { events = { 301 } }; event 7 has no weekly rule, so no window.
    windows = read_layers(write_tree(tmp_path)).windows
    assert windows == {
        "day": {"time": [[360, 0]]},  # event 47: 06:00 for 1080 minutes, ending at midnight
        "night": {"time": [[1080, 720]]},  # event 48: 18:00 for 1080 minutes, wrapping to 12:00
        "summer": {"season": [{"from": [3, 20], "to": [9, 18]}]},  # event 45: 20 Mar 10:00 for 182.5 days
        "winter": {"season": [{"from": [9, 23], "to": [3, 24]}]},  # event 46: 23 Sep 09:00 for 182.5 days
        "spring": {"season": [{"from": [3, 20], "to": [6, 20]}]},
        "autumn": {"season": [{"from": [9, 23], "to": [12, 20]}]},
        "event.301": {"events": [301]},
    }


REPO = Path(__file__).resolve().parents[2]


def test_the_committed_baseline_seeds_day_and_night_as_time_ranges() -> None:
    # DATA-R36 over data/baseline/events.csv. Event 47 (Sunscale Cycle) starts 06:00 for 1080 minutes: 360 to
    # (360 + 1080) % 1440 = 0. Event 48 (Nightfin Cycle) starts 18:00 for 1080 minutes: 1080 to 720, wrapping.
    windows = read_layers(REPO).windows
    assert windows["day"] == {"time": [[360, 0]]}
    assert windows["night"] == {"time": [[1080, 720]]}


def test_the_committed_baseline_seeds_summer_and_winter_as_season_ranges() -> None:
    # DATA-R36 over data/baseline/events.csv. Event 45 starts 20 Mar 10:00 for 262800 minutes (182.5 days); in a
    # non-leap year it ends 18 Sep 22:00, so to is 18 Sep. Event 46 starts 23 Sep 09:00 for 182.5 days and ends
    # 24 Mar 21:00, so to is 24 Mar, wrapping the year.
    windows = read_layers(REPO).windows
    assert windows["summer"] == {"season": [{"from": [3, 20], "to": [9, 18]}]}
    assert windows["winter"] == {"season": [{"from": [9, 23], "to": [3, 24]}]}


def test_the_committed_windows_toml_defines_spring_and_autumn_at_their_tunables() -> None:
    # DATA-R36, Tunables: spring 20 Mar - 20 Jun, autumn 23 Sep - 20 Dec. DATA-R37, DATA-R38: event.301.
    windows = read_layers(REPO).windows
    assert windows["spring"] == {"season": [{"from": [3, 20], "to": [6, 20]}]}
    assert windows["autumn"] == {"season": [{"from": [9, 23], "to": [12, 20]}]}
    assert windows["event.301"] == {"events": [301]}
    assert sorted(windows) == ["autumn", "day", "event.301", "night", "spring", "summer", "winter"]


def test_each_vmangos_event_maps_to_its_window() -> None:
    # DATA-R36: the seeds, and the Extravaganza's events 14, 15 and 40 map to event.301. Other events map to none.
    assert {event: window_of_event(event) for event in (14, 15, 40, 45, 46, 47, 48, 12)} == {
        14: "event.301",
        15: "event.301",
        40: "event.301",
        45: "summer",
        46: "winter",
        47: "day",
        48: "night",
        12: None,
    }


def test_windows_toml_overrides_a_seed(tmp_path: Path) -> None:
    # DATA-R36: "windows.toml overrides any of these"; the entry replaces the seed's spec whole.
    night = '[window.night]\ntime = [[1200, 300], [0, 60]]\nevents = [301]\nwhy = "#91 test"\n'
    windows = read_layers(write_tree(tmp_path, WINDOWS + night)).windows
    assert windows["night"] == {"time": [[1200, 300], [0, 60]], "events": [301]}


def test_dropping_a_seed_with_nothing_to_replace_it_fails_as_a_missing_window(tmp_path: Path) -> None:
    # DATA-R35: the generator fails if any of the six is missing after the merge. Without event 47 nothing seeds day.
    events_csv = EVENTS_CSV_HEADER + SEED_EVENTS[45] + SEED_EVENTS[46] + SEED_EVENTS[48]
    assert problems(write_tree(tmp_path, events_csv=events_csv)) == [
        "data/forever/windows.toml: window 'day' is missing: neither a baseline event (47) nor windows.toml gives it"
    ]


def test_windows_toml_can_replace_a_dropped_seed(tmp_path: Path) -> None:
    # DATA-R35, DATA-R36: the six must exist after the merge, from either source.
    events_csv = EVENTS_CSV_HEADER + SEED_EVENTS[45] + SEED_EVENTS[46] + SEED_EVENTS[48]
    day = '[window.day]\ntime = [[360, 1080]]\nwhy = "#91 test"\n'
    assert read_layers(write_tree(tmp_path, WINDOWS + day, events_csv)).windows["day"] == {"time": [[360, 1080]]}


@pytest.mark.parametrize(
    ("entry", "problem"),
    [
        # DATA-R35: windows.toml defines no other ID, event windows included.
        (
            '[window.dusk]\ntime = [[1080, 1200]]\nwhy = "x"\n',
            "data/forever/windows.toml: window.dusk: not a window ID windows.toml may define"
            " (day, night, spring, summer, autumn, winter)",
        ),
        (
            '[window."event.301"]\nevents = [301]\nwhy = "x"\n',
            "data/forever/windows.toml: window.event.301: not a window ID windows.toml may define"
            " (day, night, spring, summer, autumn, winter)",
        ),
        # DATA-R10: why is required on every windows.toml entry.
        ("[window.night]\ntime = [[1080, 720]]\n", "data/forever/windows.toml: window.night: missing key 'why'"),
        # LOG-R48: an empty list, or a range with from == to, is invalid.
        (
            '[window.night]\ntime = []\nwhy = "x"\n',
            "data/forever/windows.toml: window.night: invalid condition spec: time is an empty list",
        ),
        (
            '[window.night]\nseason = [{ from = [3, 1], to = [3, 1] }]\nwhy = "x"\n',
            "data/forever/windows.toml: window.night: invalid condition spec: season[1] has from == to",
        ),
        (
            '[window.night]\ntime = [[1080, 1440]]\nwhy = "x"\n',
            "data/forever/windows.toml: window.night: invalid condition spec:"
            " time[1] must be { from, to } realm minutes of day",
        ),
        # DATA-R35: a window uses only time, season and events (the Data section's windows.toml keys).
        ('[window.night]\nareas = [33]\nwhy = "x"\n', "data/forever/windows.toml: window.night: unknown key 'areas'"),
        (
            '[window.night]\nseason = [{ from = [3, 1], to = [3, 9], until = [3, 9] }]\nwhy = "x"\n',
            "data/forever/windows.toml: window.night.season[0]: unknown key 'until'",
        ),
        ('[window.night]\nwhy = "x"\n', "data/forever/windows.toml: window.night: sets none of time, season, events"),
    ],
)
def test_a_bad_windows_toml_entry_fails(tmp_path: Path, entry: str, problem: str) -> None:
    # DATA-R63: the generator fails, listing the problem.
    assert problems(write_tree(tmp_path, WINDOWS + entry)) == [problem]


def test_an_unknown_top_level_key_in_windows_toml_fails(tmp_path: Path) -> None:
    # DATA-R63: an unknown key in any TOML file under data/ fails; windows.toml holds only [window.<id>] tables
    # (#96's audit found its top level untested).
    assert problems(write_tree(tmp_path, 'colour = "red"\n' + WINDOWS)) == [
        "data/forever/windows.toml: unknown key 'colour'"
    ]


def daily(start: str, length: int) -> BaselineEvent:
    return BaselineEvent(48, start, 1440, length, "a daily event")


def test_a_daily_event_that_crosses_midnight_becomes_a_wrapping_time_range() -> None:
    # DATA-R36: daily from minute M for L minutes is time = {{ M, (M + L) % 1440 }}. 22:00 for 4 hours is
    # 1320 to 120, which wraps past midnight (LOG-R48: to < from).
    assert seed_spec(daily("2017-01-01 22:00", 240)) == {"time": [[1320, 120]]}


def yearly(start: str, length: int) -> BaselineEvent:
    return BaselineEvent(45, start, 525600, length, "a yearly event")


def test_a_yearly_event_ends_the_day_before_its_end_in_a_non_leap_year() -> None:
    # DATA-R36: yearly from month/day S for L minutes is season = {{ from = S, to = the month/day of the minute
    # before S + L, in a non-leap year }}. 20 Feb for 10 days ends at the start of 2 Mar in a non-leap year, so to is
    # 1 Mar; in VMaNGOS's leap year 2020 it would have been 29 Feb.
    assert seed_spec(yearly("2020-02-20 00:00", 10 * 1440)) == {"season": [{"from": [2, 20], "to": [3, 1]}]}


def test_a_yearly_event_that_crosses_new_year_wraps() -> None:
    # DATA-R36, LOG-R48 (to < from wraps the year): 20 Dec for 20 days ends at the start of 9 Jan, so to is 8 Jan.
    assert seed_spec(yearly("2016-12-20 00:00", 20 * 1440)) == {"season": [{"from": [12, 20], "to": [1, 8]}]}
