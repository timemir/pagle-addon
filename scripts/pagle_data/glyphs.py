"""The characters each Locale's files may draw (CORE-R9, DATA-R107, DATA-R114), read from data/glyphs.toml.

That file is the one table: spec/glyphs_spec.lua reads it too, through spec/support/helpers.lua. A Locale's range is
the base set (ASCII, Latin-1, the en and em dashes, curly quotes, the bullet and the ellipsis) plus the ranges of the
scripts the file lists for it; the English lore check is the base set alone."""

import re
import tomllib
from dataclasses import dataclass
from functools import cache
from pathlib import Path

GLYPHS_TOML = Path(__file__).resolve().parents[2] / "data" / "glyphs.toml"
FILE = "data/glyphs.toml"
ENGLISH = "enUS"

# What the base set is, in a failure's words (CORE-R9).
BASE_DESCRIPTION = "ASCII, Latin-1, the en and em dashes, curly quotes, the bullet and the ellipsis"

_RANGE = re.compile(r"U\+([0-9A-F]{4,6})(?:-U\+([0-9A-F]{4,6}))?")

Range = tuple[int, int]


@dataclass(frozen=True)
class Glyphs:
    """One Locale's range: the code points it may draw, and a description of the set for a message."""

    locale: str
    ranges: tuple[Range, ...]
    scripts: tuple[str, ...]

    def has(self, char: str) -> bool:
        """Whether the client's fonts have char for this Locale."""
        point = ord(char)
        return any(low <= point <= high for low, high in self.ranges)

    @property
    def description(self) -> str:
        """The set in words: the base set, then the scripts added to it."""
        if not self.scripts:
            return BASE_DESCRIPTION
        return f"{BASE_DESCRIPTION}, plus {', '.join(self.scripts)}"


def _ranges(value: object, where: str) -> tuple[Range, ...]:
    if not isinstance(value, list):
        raise ValueError(f"{FILE}: {where}: expected an array of ranges")
    found: list[Range] = []
    for item in value:
        match = _RANGE.fullmatch(item) if isinstance(item, str) else None
        if match is None:
            raise ValueError(f"{FILE}: {where}: expected 'U+XXXX' or 'U+XXXX-U+YYYY', got {item!r}")
        low = int(match.group(1), 16)
        high = int(match.group(2) or match.group(1), 16)
        if high < low:
            raise ValueError(f"{FILE}: {where}: {item} ends before it starts")
        found.append((low, high))
    return tuple(found)


def _table(document: dict[str, object], name: str) -> dict[str, object]:
    table = document.get(name)
    if not isinstance(table, dict):
        raise ValueError(f"{FILE}: [{name}] is missing")
    return table


@cache
def read_glyphs(path: Path = GLYPHS_TOML) -> dict[str, Glyphs]:
    """Every Locale's range by client code, from the table at path. Raises ValueError for a table that is wrong."""
    with path.open("rb") as handle:
        document = tomllib.load(handle)
    base = _ranges(_table(document, "base").get("ranges"), "[base] ranges")
    scripts = {
        name: _ranges(table.get("ranges") if isinstance(table, dict) else None, f"[script.{name}] ranges")
        for name, table in _table(document, "script").items()
    }
    result: dict[str, Glyphs] = {}
    for code, names in _table(document, "locale").items():
        if not isinstance(names, list) or not all(isinstance(name, str) and name in scripts for name in names):
            raise ValueError(f"{FILE}: [locale] {code}: expected a list of the names in [script.*]")
        ranges = base + tuple(item for name in names for item in scripts[name])
        result[code] = Glyphs(code, ranges, tuple(names))
    return result


def glyphs_for(locale: str, path: Path = GLYPHS_TOML) -> Glyphs:
    """locale's range (CORE-R9). A code the table lacks is an error: a new Locale starts with its line."""
    table = read_glyphs(path)
    if locale not in table:
        raise ValueError(f"{FILE}: no range for the Locale '{locale}' (CORE-R9, DATA-R114): add it to [locale]")
    return table[locale]
