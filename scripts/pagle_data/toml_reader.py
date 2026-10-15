"""Strict TOML reading for data/ (DATA-R63): an unknown key or a wrong type is a problem, and every problem found is
collected, so one run lists them all before the generator fails without writing anything.
"""

import calendar
import tomllib
from collections.abc import Collection, Mapping
from datetime import UTC, date, datetime
from pathlib import Path

from pagle_data.errors import At, Problems


def describe(value: object) -> str:
    """A TOML value's type, for a message."""
    if isinstance(value, bool):
        return "a boolean"
    if isinstance(value, int):
        return "an integer"
    if isinstance(value, float):
        return "a float"
    if isinstance(value, str):
        return "a string"
    if isinstance(value, list):
        return "an array"
    if isinstance(value, dict):
        return "a table"
    return "a date or time"


def read_toml(root: Path, file: str, problems: Problems) -> dict[str, object] | None:
    """The top-level table of root/file, or None (with a problem) when it's missing or isn't valid TOML."""
    at = At(file)
    try:
        with (root / file).open("rb") as handle:
            return tomllib.load(handle)
    except FileNotFoundError:
        problems.add(at, "missing")
    except tomllib.TOMLDecodeError as error:
        problems.add(at, f"not valid TOML: {error}")
    return None


def check_keys(
    table: Mapping[str, object], at: At, problems: Problems, *, required: Collection[str], optional: Collection[str]
) -> None:
    """Adds a problem for each key of table that isn't allowed and each required key it lacks."""
    for key in table:
        if key not in required and key not in optional:
            problems.add(at, f"unknown key '{key}'")
    for key in required:
        if key not in table:
            problems.add(at, f"missing key '{key}'")


def expect_table(value: object, at: At, problems: Problems) -> Mapping[str, object] | None:
    if isinstance(value, dict):
        return value
    problems.add(at, f"expected a table, got {describe(value)}")
    return None


def broken_bounds(value: int, minimum: int | None, maximum: int | None = None) -> str | None:
    """The bounds value breaks, as "at least 1" or "from 1 to 12", or None when it keeps them. A minimum of None
    bounds nothing."""
    if minimum is not None and (value < minimum or (maximum is not None and value > maximum)):
        return f"from {minimum} to {maximum}" if maximum is not None else f"at least {minimum}"
    return None


def expect_int(
    value: object, at: At, problems: Problems, *, minimum: int | None, maximum: int | None = None
) -> int | None:
    """value as an integer in [minimum, maximum], or None with a problem. A minimum of None bounds nothing."""
    if isinstance(value, bool) or not isinstance(value, int):
        problems.add(at, f"expected an integer, got {describe(value)}")
        return None
    bounds = broken_bounds(value, minimum, maximum)
    if bounds is not None:
        problems.add(at, f"expected an integer {bounds}, got {value}")
        return None
    return value


def expect_date(value: object, at: At, problems: Problems) -> int | None:
    """value as a TOML date (YYYY-MM-DD, not a date-time), meaning 00:00 UTC on that day, as a server time (Unix
    seconds), or None with a problem (DATA-R87)."""
    if isinstance(value, datetime) or not isinstance(value, date):
        problems.add(at, f"expected a date (YYYY-MM-DD), got {describe(value)}")
        return None
    return calendar.timegm(value.timetuple())


def date_text(server_time: int) -> str:
    """A server time's UTC date as TOML writes a date, YYYY-MM-DD: expect_date's inverse."""
    return datetime.fromtimestamp(server_time, UTC).date().isoformat()


def expect_ids(value: object, at: At, problems: Problems) -> list[int] | None:
    """value as an array of distinct positive integer IDs, or None with a problem for each bad element."""
    if not isinstance(value, list):
        problems.add(at, f"expected an array of IDs, got {describe(value)}")
        return None
    ids: list[int] = []
    ok = True
    for index, item in enumerate(value):
        item_at = At(at.file, f"{at.path}[{index}]")
        number = expect_int(item, item_at, problems, minimum=1)
        if number is None:
            ok = False
        elif number in ids:
            problems.add(item_at, f"{number} is listed twice")
            ok = False
        else:
            ids.append(number)
    return ids if ok else None


def expect_why(table: Mapping[str, object], at: At, problems: Problems) -> str | None:
    """An entry's required why (DATA-R10): the evidence, an issue number, or the VMaNGOS error it fixes. A missing
    one is check_keys' problem; an empty one is a problem here."""
    if "why" not in table:
        return None
    why = table["why"]
    if not isinstance(why, str):
        problems.add(at / "why", f"expected a string, got {describe(why)}")
        return None
    if not why.strip():
        problems.add(at / "why", "empty: say why (the evidence, an issue number, or the VMaNGOS error it fixes)")
        return None
    return why


def parse_id(key: str, at: At, problems: Problems) -> int | None:
    """A table key that names an ID, such as the 301 of [event.301], as an integer."""
    if key.isascii() and key.isdecimal() and not key.startswith("0"):
        return int(key)
    problems.add(at, f"expected a positive integer ID as the key, got '{key}'")
    return None
