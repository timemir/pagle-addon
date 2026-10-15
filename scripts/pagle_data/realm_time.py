"""A condition spec's time-based fields in realm time (DATA-R92), read exactly as Core's MatchesConditions and
NextWindow read them (LOG-R48, LOG-R50), for the rarity cap.

Realm time here is naive: a date-time with no UTC offset and no daylight saving. A window's minutes and month-days
are realm time already, and so are a weekly rule's weekday and start (DATA-R38). Only `time`, `season` and `events`
are read; every other field is ignored, and a spec with none of them is open at every step.
scripts/tests/fixtures/time_specs.json holds the cases both languages are held to.
"""

import math
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from pagle_data.forever import WeeklyRule

MINUTES_PER_DAY = 1440
# Tunables: the rarity cap's span, 2026-01-01 00:00 to 2027-12-31 23:45 realm time, every 15 minutes.
SPAN_FIRST_DAY = date(2026, 1, 1)
SPAN_DAYS = (date(2028, 1, 1) - SPAN_FIRST_DAY).days
STEP_MINUTES = 15
STEPS_PER_DAY = MINUTES_PER_DAY // STEP_MINUTES
STEPS = SPAN_DAYS * STEPS_PER_DAY
# Tunables: the rarity cap passes a spec open at 1/7 or more of the steps, or closed at most 7 days running.
OPEN_SHARE_DENOMINATOR = 7
LONGEST_CLOSED_STEPS = 7 * STEPS_PER_DAY

# The event list's weekly rules by event ID (DATA-R38); an event without one maps to None.
Rules = Mapping[int, WeeklyRule | None]


def _weekday(day: date) -> int:
    """The weekday as the client's calendar and a weekly rule number it: 1 is Sunday (DATA-R38)."""
    return day.isoweekday() % 7 + 1


def in_time_range(minute: int, time_range: object) -> bool:
    """LOG-R48's time range: a realm minute of day in one { from, to }, from inclusive, to exclusive, crossing
    midnight when to < from. Core's MatchesConditions reads a range with from == to (invalid, LOG-R48) as crossing
    midnight, so does this."""
    assert isinstance(time_range, list)
    start, end = int(time_range[0]), int(time_range[1])
    return start <= minute < end if start < end else minute >= start or minute < end


def _month_day(value: object) -> tuple[int, int]:
    assert isinstance(value, list)
    return int(value[0]), int(value[1])


def in_season(month_day: tuple[int, int], season: object) -> bool:
    """LOG-R48's season range: a realm (month, day) in one { from, to }, both days inclusive, crossing the year's end
    when to < from. Core's MatchesConditions reads a range with from == to (invalid, LOG-R48) as crossing the year's
    end, the whole year, so does this."""
    assert isinstance(season, Mapping)
    start, end = _month_day(season["from"]), _month_day(season["to"])
    return start <= month_day <= end if start < end else month_day >= start or month_day <= end


def _time_holds(ranges: object, minute: int) -> bool:
    """LOG-R48's time: a realm minute in any of the ranges."""
    assert isinstance(ranges, list)
    return any(in_time_range(minute, time_range) for time_range in ranges)


def _season_holds(ranges: object, day: date) -> bool:
    """LOG-R48's season: a realm date in any of the ranges."""
    assert isinstance(ranges, list)
    return any(in_season((day.month, day.day), season) for season in ranges)


def _occurrences(rule: WeeklyRule, first: date, days: int) -> list[tuple[int, int]]:
    """A weekly rule's occurrences that may be open in the days from first on (LOG-R50), as [opens, closes) in
    minutes from first's midnight. One that starts before first and is still going counts, as NextWindow has it."""
    back = math.ceil(rule.duration / MINUTES_PER_DAY)
    found: list[tuple[int, int]] = []
    for offset in range(-back, days):
        if _weekday(first + timedelta(days=offset)) == rule.weekday:
            opens = offset * MINUTES_PER_DAY + rule.start
            found.append((opens, opens + rule.duration))
    return found


def _events(events: object, rules: Rules, first: date, days: int) -> list[tuple[int, int]]:
    """Every listed event's occurrences from its weekly rule (DATA-R38); an event without one is never open."""
    assert isinstance(events, list)
    found: list[tuple[int, int]] = []
    for event in events:
        rule = rules.get(event)
        if rule is not None:
            found.extend(_occurrences(rule, first, days))
    return found


def is_open(spec: Mapping[str, object], at: datetime, rules: Rules) -> bool:
    """Whether a spec's time-based fields all hold at a naive realm date-time (LOG-R48, LOG-R50)."""
    minute = at.hour * 60 + at.minute
    if "time" in spec and not _time_holds(spec["time"], minute):
        return False
    if "season" in spec and not _season_holds(spec["season"], at.date()):
        return False
    if "events" in spec:
        return any(opens <= minute < closes for opens, closes in _events(spec["events"], rules, at.date(), 1))
    return True


def open_steps(spec: Mapping[str, object], rules: Rules) -> bytearray:
    """Whether the spec is open at each step of the rarity-cap span (Tunables), 1 for open: step n is
    2026-01-01 00:00 + 15 minutes x n, read as is_open reads it, a day's slots and a year's days computed once."""
    slots = [1] * STEPS_PER_DAY
    if "time" in spec:
        slots = [int(_time_holds(spec["time"], slot * STEP_MINUTES)) for slot in range(STEPS_PER_DAY)]
    days = [1] * SPAN_DAYS
    if "season" in spec:
        days = [int(_season_holds(spec["season"], SPAN_FIRST_DAY + timedelta(days=day))) for day in range(SPAN_DAYS)]
    steps = bytearray(slots * SPAN_DAYS)
    for day, holds in enumerate(days):
        if not holds:
            steps[day * STEPS_PER_DAY : (day + 1) * STEPS_PER_DAY] = bytes(STEPS_PER_DAY)
    if "events" in spec:
        # Step n is open when opens <= 15n < closes, so from ceil(opens / 15) to before ceil(closes / 15).
        events = bytearray(STEPS)
        for opens, closes in _events(spec["events"], rules, SPAN_FIRST_DAY, SPAN_DAYS):
            first = max(0, -(-opens // STEP_MINUTES))
            last = min(STEPS, -(-closes // STEP_MINUTES))
            if first < last:
                events[first:last] = b"\x01" * (last - first)
        steps = bytearray(step & event for step, event in zip(steps, events))
    return steps


@dataclass(frozen=True)
class Openness:
    """How open a spec is over the rarity-cap span (DATA-R92): the steps it is open at, and its longest run of closed
    steps, not wrapping round the span's ends."""

    open_steps: int
    longest_closed: int

    @property
    def passes(self) -> bool:
        """DATA-R92's rarity cap, auras aside: open at 1/7 or more of the steps, or never closed more than 7 days
        running (Tunables)."""
        return self.open_steps * OPEN_SHARE_DENOMINATOR >= STEPS or self.longest_closed <= LONGEST_CLOSED_STEPS


def openness(spec: Mapping[str, object], rules: Rules) -> Openness:
    """The spec's Openness over the rarity-cap span (DATA-R92)."""
    steps = open_steps(spec, rules)
    longest = run = 0
    for step in steps:
        run = 0 if step else run + 1
        longest = max(longest, run)
    return Openness(open_steps=sum(steps), longest_closed=longest)
