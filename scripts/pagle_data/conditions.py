"""Condition specs (LOG-R48), checked as addons/Pagle/logic/Conditions.lua checks them, so the generator rejects
exactly the specs Pagle.MatchesConditions would raise for (DATA-R35, DATA-R63).

A spec is written as the Lua writer (pagle_data.lua) takes it: a mapping from field to value, Lua lists as Python
lists, and a season range as a mapping with "from" and "to". Keep the two checks and their messages in step.
"""

from collections.abc import Callable, Mapping

# Days in each month, 29 Feb included: a month/day names a day in any year (LOG-R48).
_DAYS_IN_MONTH = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)


def _integer_in(value: object, minimum: int, maximum: int | None = None) -> bool:
    if isinstance(value, bool) or not isinstance(value, int):
        return False
    return value >= minimum and (maximum is None or value <= maximum)


def _is_id(value: object) -> bool:
    return _integer_in(value, 1)


def _is_minute_of_day(value: object) -> bool:
    return _integer_in(value, 0, 1439)


def _is_month_day(value: object) -> bool:
    if not isinstance(value, list) or len(value) != 2 or not _integer_in(value[0], 1, 12):
        return False
    month: int = value[0]
    return _integer_in(value[1], 1, _DAYS_IN_MONTH[month - 1])


def _check_list(field: str, values: object, is_item: Callable[[object], bool], shape: str) -> str | None:
    """What's wrong with a list field's value, or None: it must be a non-empty list whose items pass is_item."""
    if isinstance(values, list | Mapping) and not values:
        return f"{field} is an empty list"
    if not isinstance(values, list) or not all(is_item(item) for item in values):
        return f"{field} must be {shape}"
    return None


def _check_ranges(
    field: str,
    ranges: object,
    is_range: Callable[[object], bool],
    from_equals_to: Callable[[object], bool],
    shape: str,
) -> str | None:
    """What's wrong with a list of ranges, or None: each passes is_range, and its from differs from its to."""
    problem = _check_list(field, ranges, lambda _: True, "a list of ranges")
    if problem is not None:
        return problem
    assert isinstance(ranges, list)
    for index, item in enumerate(ranges, start=1):
        if not is_range(item):
            return f"{field}[{index}] must be {shape}"
        if from_equals_to(item):
            return f"{field}[{index}] has from == to"
    return None


def _is_time_range(value: object) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(_is_minute_of_day(item) for item in value)


def _is_season_range(value: object) -> bool:
    return isinstance(value, Mapping) and _is_month_day(value.get("from")) and _is_month_day(value.get("to"))


def _same_ends(value: object) -> bool:
    if isinstance(value, Mapping):
        return bool(value["from"] == value["to"])
    return isinstance(value, list) and value[0] == value[1]


def _check_lure(lure: object) -> str | None:
    if lure is True:
        return None
    return _check_list("lure", lure, _is_id, "true or a list of IDs")


def _check_skill(skill: object) -> str | None:
    if not isinstance(skill, Mapping) or set(skill) != {"min"} or not _integer_in(skill["min"], 0):
        return "skill must be { min = n }"
    return None


# One checker per spec field (LOG-R48): what's wrong with the field's value, or None.
_CHECKERS: dict[str, Callable[[object], str | None]] = {
    "areas": lambda areas: _check_list("areas", areas, _is_id, "a list of IDs"),
    "time": lambda ranges: _check_ranges("time", ranges, _is_time_range, _same_ends, "{ from, to } realm minutes of day"),
    "season": lambda ranges: _check_ranges(
        "season", ranges, _is_season_range, _same_ends, "{ from = { month, day }, to = { month, day } }"
    ),
    "events": lambda events: _check_list("events", events, _is_id, "a list of IDs"),
    "auras": lambda auras: _check_list("auras", auras, _is_id, "a list of IDs"),
    "lure": _check_lure,
    "skill": _check_skill,
}

FIELDS = tuple(_CHECKERS)


def check_spec(spec: object) -> str | None:
    """What's wrong with a condition spec, or None if nothing (LOG-R48): an empty list, a range with from == to, a
    field LOG-R48 doesn't define, or a value of the wrong shape."""
    if not isinstance(spec, Mapping):
        return "it must be a table"
    for field, values in spec.items():
        checker = _CHECKERS.get(field)
        if checker is None:
            return f"{field} is not a condition field"
        problem = checker(values)
        if problem is not None:
            return problem
    return None
