"""Writes Python values as Lua 5.1 table constructors, deterministically (DATA-R62).

Map keys come out in ascending order: numbers numerically, then strings by byte. Lists keep their order. A table
whose values are all scalars or empty tables goes on one line; any other table puts each entry on its own line,
indented by tabs.
Only booleans, integers, strings, lists, mappings with integer or string keys and Shared references are written;
anything else (a float, None) is a generator bug and raises TypeError.
"""

import re
from collections.abc import Iterator, Mapping

_IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_KEYWORDS = frozenset(
    "and break do else elseif end false for function if in local nil not or repeat return then true until while".split()
)


def _string(value: str) -> str:
    # Non-ASCII characters stay as they are: the file is UTF-8, and Lua 5.1 strings are its bytes.
    out = ['"']
    for char in value:
        if char in '"\\':
            out.append("\\" + char)
        elif char == "\n":
            out.append("\\n")
        elif ord(char) < 0x20 or ord(char) == 0x7F:
            out.append(f"\\{ord(char):03d}")
        else:
            out.append(char)
    out.append('"')
    return "".join(out)


class Shared(Mapping[str, object]):
    """A table written once, as the field `key` of a Lua local, and referred to wherever else it appears: the Lua
    writer writes the reference (`W.night`, `W["event.301"]`), and anything else that reads it as a mapping (the
    canonical JSON, DATA-R70) sees the table in full. The Contracts section's W, the window specs, is one."""

    def __init__(self, local: str, key: str, table: Mapping[str, object]) -> None:
        self.local = local
        self.key = key
        self.table = table

    def reference(self) -> str:
        key = _key(self.key)
        return f"{self.local}{key}" if key.startswith("[") else f"{self.local}.{key}"

    def __getitem__(self, key: str) -> object:
        return self.table[key]

    def __iter__(self) -> Iterator[str]:
        return iter(self.table)

    def __len__(self) -> int:
        return len(self.table)


def _scalar(value: object) -> str | None:
    if isinstance(value, Shared):
        return value.reference()
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return _string(value)
    return None


def _empty(value: object) -> bool:
    return isinstance(value, list | Mapping) and not value


def _key(key: object) -> str:
    if isinstance(key, bool) or not isinstance(key, int | str):
        raise TypeError(f"a Lua map key must be an integer or a string, not {key!r}")
    if isinstance(key, int):
        return f"[{key}]"
    if _IDENTIFIER.fullmatch(key) and key not in _KEYWORDS:
        return key
    return f"[{_string(key)}]"


def _sort_key(key: object) -> tuple[int, int, bytes]:
    if isinstance(key, int) and not isinstance(key, bool):
        return (0, key, b"")
    if isinstance(key, str):
        return (1, 0, key.encode("utf-8"))
    raise TypeError(f"a Lua map key must be an integer or a string, not {key!r}")


def _entries(value: Mapping[object, object] | list[object]) -> list[tuple[str | None, object]]:
    if isinstance(value, list):
        return [(None, item) for item in value]
    return [(_key(key), value[key]) for key in sorted(value, key=_sort_key)]


def to_lua(value: object, indent: int = 0) -> str:
    """The Lua expression for value, as it appears at the given indent depth (in tabs)."""
    scalar = _scalar(value)
    if scalar is not None:
        return scalar
    if not isinstance(value, list | Mapping):
        raise TypeError(f"can't write {type(value).__name__} as Lua: {value!r}")
    entries = _entries(value)
    if not entries:
        return "{}"
    if all(_scalar(item) is not None or _empty(item) for _, item in entries):
        parts = [f"{key} = {to_lua(item)}" if key else to_lua(item) for key, item in entries]
        return "{ " + ", ".join(parts) + " }"
    inner = "\t" * (indent + 1)
    lines = []
    for key, item in entries:
        prefix = f"{key} = " if key else ""
        lines.append(f"{inner}{prefix}{to_lua(item, indent + 1)},\n")
    return "{\n" + "".join(lines) + "\t" * indent + "}"
