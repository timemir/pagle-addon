"""The rarity cap's reading of time (DATA-R92): a condition spec's time-based fields at a naive realm date-time, as
Core's MatchesConditions and NextWindow read them (LOG-R48, LOG-R50), and a spec's openness over the rarity-cap span
(Tunables)."""

import json
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from pagle_data.confirmed import side
from pagle_data.errors import At
from pagle_data.forever import WeeklyRule
from pagle_data.observed import CatchRow
from pagle_data.realm_time import Openness, in_season, in_time_range, is_open, open_steps, openness

# The shared fixture, read by spec/Pagle/logic/TimeSpecs_spec.lua too, so the two readings can't drift.
FIXTURE = Path(__file__).parent / "fixtures" / "time_specs.json"
_DOCUMENT = json.loads(FIXTURE.read_text(encoding="utf-8"))
RULES = {int(event): WeeklyRule(**rule) for event, rule in _DOCUMENT["rules"].items()}
CASES = _DOCUMENT["cases"]

SUNDAY = 1  # DATA-R38: weekday 1 is Sunday
STEPS = 730 * 96  # Tunables: every 15 minutes of 2026 and 2027
WEEK_STEPS = 7 * 96


@pytest.mark.parametrize("case", CASES, ids=[case["why"] for case in CASES])
def test_the_shared_time_fixture(case: dict[str, object]) -> None:
    # DATA-R92, LOG-R48, LOG-R50: time ranges whose from is above to cross midnight, seasons are inclusive and may
    # cross New Year, 29 February is a real day, an event is open per its weekly rule (and may cross midnight), and an
    # event without one never is; fields combine with AND, values with OR.
    at = datetime.strptime(str(case["at"]), "%Y-%m-%d %H:%M")
    spec = case["spec"]
    assert isinstance(spec, dict)
    assert is_open(spec, at, RULES) is case["open"]


def test_a_one_hour_weekly_window_passes_the_cap_as_data_r92_words_it() -> None:
    # DATA-R92: open 1 hour a week is under 1/7 of the steps, but its longest closed run is
    # 6 days 23 hours, at most 7 days, so it passes. 2026 and 2027 have 52 Sundays each, 4 steps every one. The run
    # doesn't wrap round the span's ends: the 5 days 9 hours after the last Sunday (2027-12-26 15:00 on) and the 3
    # days 14 hours before the first (2026-01-04 14:00) would make 8 days 23 hours running.
    weekly = openness({"events": [400]}, {400: WeeklyRule(weekday=SUNDAY, start=840, duration=60)})
    assert weekly == Openness(open_steps=104 * 4, longest_closed=WEEK_STEPS - 4)
    assert weekly.open_steps * 7 < STEPS
    assert weekly.passes


def test_a_window_open_one_hour_a_year_fails_the_cap() -> None:
    # DATA-R92: a two-day season with half an hour a day is open 8 steps in two years, and closed from 2026-06-02 12:30
    # to 2027-06-01 12:00, 364 days less half an hour, running. (A one-day season can't be written: from == to is
    # invalid, LOG-R48.)
    yearly = openness({"season": [{"from": [6, 1], "to": [6, 2]}], "time": [[720, 750]]}, {})
    assert yearly == Openness(open_steps=8, longest_closed=364 * 96 - 2)
    assert not yearly.passes


def test_a_window_closed_8_days_running_and_open_under_a_seventh_fails() -> None:
    # DATA-R92: 3 hours a day (1/8) from 9 January to New Year's Eve is open 357 days x 12 steps a year, and closed
    # from 2026-12-31 03:00 to 2027-01-09 00:00, 8 days 21 hours, running.
    shut = openness({"season": [{"from": [1, 9], "to": [12, 31]}], "time": [[0, 180]]}, {})
    assert shut == Openness(open_steps=2 * 357 * 12, longest_closed=8 * 96 + 21 * 4)
    assert not shut.passes
    # Open at 1/7 or more passes though closed 8 days running (the weekly hour above passes the other way).
    assert openness({"season": [{"from": [1, 9], "to": [12, 31]}]}, {}).passes


def test_an_event_without_a_weekly_rule_is_never_open() -> None:
    # DATA-R92: an event without a weekly rule counts as never open, so it is closed for the whole span.
    never = openness({"events": [303]}, RULES)
    assert never == Openness(open_steps=0, longest_closed=STEPS)
    assert not never.passes


def test_a_spec_with_no_time_field_is_open_at_every_step() -> None:
    # DATA-R92: every field but time, season and events is ignored.
    assert openness({"areas": [148], "skill": {"min": 1}}, {}) == Openness(open_steps=STEPS, longest_closed=0)


def test_every_step_reads_as_is_open_does() -> None:
    # DATA-R92: the cap's steps are the fixture's reading of time at 2026-01-01 00:00 + 15 minutes x n (Tunables), an
    # event under way at the span's start included.
    start = datetime(2026, 1, 1)
    # Wednesdays 23:00 for 2 hours: 2025-12-31's occurrence runs into the span's first hour.
    rules = {**RULES, 304: WeeklyRule(weekday=4, start=1380, duration=120)}
    for spec in (
        {"events": [302, 301]},
        {"events": [304]},
        {"time": [[1380, 60]], "season": [{"from": [12, 15], "to": [1, 15]}]},
    ):
        steps = open_steps(spec, rules)
        assert len(steps) == STEPS
        assert [bool(step) for step in steps] == [
            is_open(spec, start + timedelta(minutes=15 * index), rules) for index in range(STEPS)
        ]


def _row(t: int, m: int) -> CatchRow:
    """A catch row (REP-R20) in bucket t of realm month m, for confirmed.side."""
    return CatchRow(
        item=6303, area=33, build=70338, count=1, auras=(), events=(), t=t, m=m, rejected=None, reporter="", at=At("x")
    )


def test_the_cap_and_confirmation_read_a_season_with_from_equal_to_to_as_core_does() -> None:
    # LOG-R48, DATA-R51: a season with from == to is invalid (the generator rejects it), but read anyway, the rarity
    # cap and gate confirmation (confirmed.side) read it as Core's MatchesConditions does: not from < to, so it
    # crosses the year's end and holds every day. Confirmation used to read it as the one day.
    season = {"from": [3, 1], "to": [3, 1]}
    assert in_season((3, 1), season)
    assert in_season((7, 15), season)
    assert is_open({"season": [season]}, datetime(2026, 7, 15, 12, 0), RULES)
    assert side(_row(720, 7), {"season": [season]}) == "inside"


def test_confirmation_reads_ranges_as_the_shared_fixture_does() -> None:
    # DATA-R51, LOG-R48: confirmed.side judges a row by realm_time's in_time_range and in_season, the reading the
    # shared fixture holds to Core's: 23:00 to 02:00 crosses midnight, December to February crosses New Year.
    assert in_time_range(60, [1380, 120])
    assert not in_time_range(120, [1380, 120])
    assert side(_row(60, 1), {"time": [[1380, 120]]}) == "inside"
    assert side(_row(60, 1), {"season": [{"from": [12, 1], "to": [2, 28]}]}) == "inside"
