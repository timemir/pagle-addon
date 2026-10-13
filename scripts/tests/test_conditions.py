"""The condition-spec check (LOG-R48), ported from addons/Pagle/logic/Conditions.lua so that the generator rejects
exactly the specs Pagle.MatchesConditions raises for. The cases and messages are spec/Pagle/logic/Conditions_spec.lua's.
"""

import pytest

from pagle_data.conditions import check_spec


@pytest.mark.parametrize(
    "spec",
    [
        {},
        {"areas": [148, 453], "events": [301], "auras": [1265220], "lure": True, "skill": {"min": 0}},
        {"time": [[1080, 360], [600, 660]]},  # wrapping past midnight (LOG-R48)
        {"season": [{"from": [12, 1], "to": [2, 29]}]},  # wrapping the year; 29 Feb is a month/day
        {"lure": [263, 264]},
    ],
)
def test_accepts_a_valid_spec(spec: object) -> None:
    # LOG-R48: every field it defines, with ranges that wrap.
    assert check_spec(spec) is None


@pytest.mark.parametrize(
    ("spec", "why"),
    [
        *[({field: []}, f"{field} is an empty list") for field in ("areas", "time", "season", "events", "auras", "lure")],
        ({"time": [[360, 1080], [600, 600]]}, "time[2] has from == to"),
        ({"season": [{"from": [3, 1], "to": [3, 1]}]}, "season[1] has from == to"),
        ({"weather": [1]}, "weather is not a condition field"),
        ({"pools": [1]}, "pools is not a condition field"),
        ({"areas": 148}, "areas must be a list of IDs"),
        ({"areas": [148, "453"]}, "areas must be a list of IDs"),
        ({"events": [0]}, "events must be a list of IDs"),
        ({"events": [True]}, "events must be a list of IDs"),
        ({"lure": False}, "lure must be true or a list of IDs"),
        ({"time": [[360]]}, "time[1] must be { from, to } realm minutes of day"),
        ({"time": [[360, 1440]]}, "time[1] must be { from, to } realm minutes of day"),
        ({"time": [[-1, 60]]}, "time[1] must be { from, to } realm minutes of day"),
        ({"season": [{"from": [13, 1], "to": [1, 1]}]}, "season[1] must be { from = { month, day }, to = { month, day } }"),
        ({"season": [{"from": [2, 30], "to": [3, 1]}]}, "season[1] must be { from = { month, day }, to = { month, day } }"),
        ({"season": [{"from": [2, 1]}]}, "season[1] must be { from = { month, day }, to = { month, day } }"),
        ({"skill": 100}, "skill must be { min = n }"),
        ({"skill": {"min": "100"}}, "skill must be { min = n }"),
        ({"skill": {"min": 100, "max": 200}}, "skill must be { min = n }"),
        ("night", "it must be a table"),
    ],
)
def test_names_what_is_wrong_with_an_invalid_spec(spec: object, why: str) -> None:
    # LOG-R48: an empty list, a range with from == to, a field it doesn't define, or a value of the wrong shape.
    assert check_spec(spec) == why
