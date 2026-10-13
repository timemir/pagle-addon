"""The named windows (DATA-R35–R38): condition specs (LOG-R48) using only time, season and events.

The six named windows come from the baseline's seed events and data/forever/windows.toml, which overrides a seed
and alone defines spring and autumn (DATA-R36). Each event on the event list with a weekly rule gets the window
event.<eventID>, whose spec is its event alone (DATA-R37).
"""

from collections.abc import Mapping
from datetime import datetime, timedelta
from pathlib import Path

from pagle_data.baseline import BASELINE, BaselineEvent
from pagle_data.conditions import check_spec
from pagle_data.forever import WeeklyRule
from pagle_data.lua import Shared, to_lua
from pagle_data.toml_reader import At, Problems, check_keys, expect_table, expect_why, read_toml

WINDOWS_TOML = "data/forever/windows.toml"
# The Lua local that holds the window specs in Catalogue.lua (Contracts).
LOCAL = "W"
EVENTS_CSV = f"{BASELINE}/events.csv"

# The window IDs windows.toml may define (DATA-R35), in DATA-R35's order.
NAMED = ("day", "night", "spring", "summer", "autumn", "winter")
# The fields a window uses (DATA-R35), as windows.toml's keys besides why.
FIELDS = ("time", "season", "events")

# Which window each VMaNGOS event maps to (DATA-R36): the four seeds, and the Extravaganza's events (14, 15, 40),
# which all map to event.301. An area-loot row's or pool's event gates by this window (DATA-R29); ticket #92 reads
# it for gates and #95 for the baseline's own gates (DATA-R47).
BASELINE_EVENT_WINDOWS: Mapping[int, str] = {
    14: "event.301",
    15: "event.301",
    40: "event.301",
    45: "summer",
    46: "winter",
    47: "day",
    48: "night",
}
# The baseline event that seeds each named window (DATA-R36); spring and autumn have none.
SEEDS: Mapping[str, int] = {window: event for event, window in BASELINE_EVENT_WINDOWS.items() if window in NAMED}

# VMaNGOS's occurrence of a daily and of a yearly event, in minutes (DATA-R36).
DAILY = 1440
YEARLY = 525600
MINUTES_PER_DAY = 1440
# Any non-leap year: a yearly event's end is counted in one (DATA-R36).
NON_LEAP_YEAR = 2001

# A condition spec as the Lua writer takes it (pagle_data.conditions).
Spec = dict[str, object]


def catalogue_windows(windows: Mapping[str, Spec]) -> dict[str, Mapping[str, object]]:
    """The catalogue's windows (Contracts): { spec = W.<id>, confirmed = false } per window. Each spec is the W
    entry Shared by every gate on that window (#92); nothing confirms a window yet (DATA-R56, #95)."""
    return {
        window_id: {"spec": Shared(LOCAL, window_id, spec), "confirmed": False} for window_id, spec in windows.items()
    }


def local_lua(windows: Mapping[str, Mapping[str, object]]) -> str:
    """`local W = { … }`: the specs the catalogue's windows point at, emitted once before ns.catalogue (Contracts)."""
    specs: dict[str, Mapping[str, object]] = {}
    for entry in windows.values():
        spec = entry["spec"]
        if not isinstance(spec, Shared):
            raise TypeError(f"a catalogue window's spec must be a W entry, not {spec!r}")
        specs[spec.key] = spec.table
    return f"local {LOCAL} = {to_lua(specs)}\n"


def window_of_event(event_id: int) -> str | None:
    """The window a VMaNGOS event maps to (DATA-R36), or None for an event that maps to none."""
    return BASELINE_EVENT_WINDOWS.get(event_id)


def event_window(event_id: int) -> str:
    """The window ID of an event on the event list (DATA-R35): event.<eventID>."""
    return f"event.{event_id}"


def seed_spec(event: BaselineEvent) -> Spec:
    """A baseline event as a window spec (DATA-R36): a daily event becomes a time range, a yearly one a season
    range. Raises ValueError for an event that is neither, or whose start can't be read."""
    try:
        start = datetime.strptime(event.start, "%Y-%m-%d %H:%M")
    except ValueError:
        raise ValueError(f"event {event.event}'s start '{event.start}' isn't YYYY-MM-DD HH:MM") from None
    if event.occurrence == DAILY:
        minute = start.hour * 60 + start.minute
        return {"time": [[minute, (minute + event.length) % MINUTES_PER_DAY]]}
    if event.occurrence == YEARLY:
        if (start.month, start.day) == (2, 29):
            raise ValueError(f"event {event.event} starts on 29 Feb, which a non-leap year lacks")
        # The start instant, moved into a non-leap year; to is the day of the minute before the event ends.
        first = start.replace(year=NON_LEAP_YEAR)
        last = first + timedelta(minutes=event.length - 1)
        return {"season": [{"from": [first.month, first.day], "to": [last.month, last.day]}]}
    raise ValueError(f"event {event.event} is neither daily nor yearly (occurrence {event.occurrence})")


def _read_entry(entry: object, at: At, problems: Problems) -> Spec | None:
    """A [window.<id>] entry's spec, or None (with each problem found) when the entry is bad."""
    before = len(problems.found)
    table = expect_table(entry, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=("why",), optional=FIELDS)
    expect_why(table, at, problems)
    spec: Spec = {field: table[field] for field in FIELDS if field in table}
    seasons = spec.get("season")
    if isinstance(seasons, list):
        for index, season in enumerate(seasons):
            if isinstance(season, Mapping):
                check_keys(season, At(at.file, f"{at.path}.season[{index}]"), problems, required=(), optional=("from", "to"))
    if not spec:
        if set(table) <= {"why"}:  # an unknown key is check_keys' problem already
            problems.add(at, f"sets none of {', '.join(FIELDS)}")
    else:
        problem = check_spec(spec)
        if problem is not None:
            problems.add(at, f"invalid condition spec: {problem}")
    return spec if len(problems.found) == before else None


def read_windows_toml(root: Path, problems: Problems) -> dict[str, Spec]:
    """windows.toml's specs by window ID (DATA-R10, DATA-R36). Each problem found goes into problems; a bad entry
    is left out."""
    document = read_toml(root, WINDOWS_TOML, problems)
    if document is None:
        return {}
    at = At(WINDOWS_TOML)
    check_keys(document, at, problems, required=(), optional=("window",))
    table = expect_table(document.get("window", {}), at / "window", problems)
    windows: dict[str, Spec] = {}
    for window_id, entry in (table or {}).items():
        entry_at = at / "window" / window_id
        if window_id not in NAMED:
            problems.add(entry_at, f"not a window ID windows.toml may define ({', '.join(NAMED)})")
            continue
        spec = _read_entry(entry, entry_at, problems)
        if spec is not None:
            windows[window_id] = spec
    return windows


def build_windows(
    baseline_events: list[BaselineEvent],
    overrides: Mapping[str, Spec],
    events: Mapping[int, WeeklyRule | None],
    problems: Problems,
) -> dict[str, Spec]:
    """Every window by ID (DATA-R35): the seeds with windows.toml's overrides, then one window per event with a
    weekly rule. A missing named window, or a seed that isn't a valid spec, goes into problems."""
    windows: dict[str, Spec] = {}
    for event in baseline_events:
        window_id = window_of_event(event.event)
        if window_id not in NAMED or window_id in overrides:
            continue  # not a seed, or windows.toml overrides it (DATA-R36)
        at = At(EVENTS_CSV, f"event {event.event}")
        try:
            spec = seed_spec(event)
        except ValueError as error:
            problems.add(at, f"can't seed window '{window_id}': {error}")
            continue
        problem = check_spec(spec)
        if problem is not None:
            problems.add(at, f"window '{window_id}' from it: invalid condition spec: {problem}")
            continue
        windows[window_id] = spec
    windows.update(overrides)
    for window_id in NAMED:
        if window_id in windows:
            continue
        seed = SEEDS.get(window_id)
        source = f"neither a baseline event ({seed}) nor windows.toml gives it" if seed else "windows.toml must define it"
        problems.add(At(WINDOWS_TOML), f"window '{window_id}' is missing: {source}")
    for event_id, rule in sorted(events.items()):
        if rule is not None:
            windows[event_window(event_id)] = {"events": [event_id]}  # DATA-R37
    return windows
