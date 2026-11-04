"""Removing entries from a TOML file without rewriting it (DATA-R114's drop, docs/translations.md › Drift): the one place
the generator edits a source file that people write by hand.

Nothing else in the repo round-trips TOML: the generator reads it (tomllib), and the files it writes are generated whole.
A translator's file has comments and an order that are theirs, so the drop cannot be `tomllib` then a dumper. This
module works on lines instead. It finds each entry's lines with a small scanner (comments, strings, multi-line strings
and arrays, `[table]` headers, dotted keys and inline tables) and deletes exactly those, keeping every comment, the
order, the line endings and everything else byte for byte.

An entry is the first `depth` components of a key's full path: one for an interface key (`[FISH_COUNT]`), three for a
Lore field (`[species.6362.blurb]`). The edit is checked before it is returned: the result must parse, and must hold
every value the original held except those under the entries removed. A file the scanner cannot place, or an edit that
fails this check, raises EditError and nothing is written.
"""

import tomllib
from collections.abc import Collection, Mapping
from dataclasses import dataclass

type KeyPath = tuple[str, ...]


class EditError(ValueError):
    """The file could not be edited safely; the message says why."""


@dataclass(frozen=True)
class _Item:
    kind: str  # "blank", "comment", "header" or "statement"
    first: int  # its first line, 0-based
    last: int  # its last line (a statement's value may run over several)
    path: KeyPath  # a header's table, or a statement's full key path; () for blank and comment


def _quoted_end(text: str, start: int) -> int:
    """The index just past the quoted key that begins at text[start], a basic ("...") or literal ('...') string."""
    quote = text[start]
    at = start + 1
    while at < len(text):
        if quote == '"' and text[at] == "\\":
            at += 2
            continue
        if text[at] == quote:
            return at + 1
        at += 1
    raise EditError(f"an unterminated quoted key in {text!r}")


def _split_key(line: str) -> tuple[str, int]:
    """A statement's key text, and the column just past its `=`."""
    at = 0
    while at < len(line):
        if line[at] in "\"'":
            at = _quoted_end(line, at)
        elif line[at] == "=":
            return line[:at], at + 1
        else:
            at += 1
    raise EditError(f"no `=` in the statement {line.strip()!r}")


def _key_path(text: str) -> KeyPath:
    """The components of a (dotted, perhaps quoted) key, read by tomllib itself so quoting and escapes are its."""
    try:
        node: object = tomllib.loads(f"{text} = 0")
    except tomllib.TOMLDecodeError as error:
        raise EditError(f"cannot read the key {text.strip()!r}: {error}") from error
    parts: list[str] = []
    while isinstance(node, dict):
        (name, node), *rest = node.items()
        if rest:
            raise EditError(f"cannot read the key {text.strip()!r}")
        parts.append(name)
    return tuple(parts)


def _header_path(line: str) -> KeyPath:
    stripped = line.strip()
    if stripped.startswith("[["):
        raise EditError(f"an array of tables, {stripped!r}, is not a place a translation sits")
    at = 1
    while at < len(stripped):
        if stripped[at] in "\"'":
            at = _quoted_end(stripped, at)
        elif stripped[at] == "]":
            return _key_path(stripped[1:at])
        else:
            at += 1
    raise EditError(f"an unterminated table header {stripped!r}")


def _statement_end(lines: list[str], start: int, column: int) -> int:
    """The last line of the statement whose value begins at lines[start][column:]: the line on which every string,
    array and inline table the value opened has closed."""
    depth = 0
    quote = ""  # the string being read: ", ', \"\"\" or ''', or "" outside one
    index, at = start, column
    while index < len(lines):
        line = lines[index]
        while at < len(line):
            rest = line[at:]
            if not quote:
                char = line[at]
                if char == "#":
                    break
                if rest.startswith(('"""', "'''")):
                    quote = rest[:3]
                    at += 3
                    continue
                if char in "\"'":
                    quote = char
                elif char in "[{":
                    depth += 1
                elif char in "]}":
                    depth -= 1
                at += 1
            elif quote in ('"', "'"):
                if quote == '"' and line[at] == "\\":
                    at += 2
                    continue
                if line[at] == quote:
                    quote = ""
                at += 1
            else:
                if quote == '"""' and line[at] == "\\":
                    at += 2
                    continue
                if rest.startswith(quote):
                    while at < len(line) and line[at] == quote[0]:  # up to two more quotes belong to the text
                        at += 1
                    quote = ""
                    continue
                at += 1
        if not quote and depth <= 0:
            return index
        index += 1
        at = 0
    raise EditError("a value that never closes")


def _items(lines: list[str]) -> list[_Item]:
    items: list[_Item] = []
    table: KeyPath = ()
    index = 0
    while index < len(lines):
        stripped = lines[index].strip()
        if not stripped:
            items.append(_Item("blank", index, index, ()))
        elif stripped.startswith("#"):
            items.append(_Item("comment", index, index, ()))
        elif stripped.startswith("["):
            table = _header_path(lines[index])
            items.append(_Item("header", index, index, table))
        else:
            key, column = _split_key(lines[index])
            last = _statement_end(lines, index, column)
            items.append(_Item("statement", index, last, (*table, *_key_path(key))))
            index = last
        index += 1
    return items


def _leaves(node: object, path: KeyPath = ()) -> dict[KeyPath, object]:
    """Every value below node by its key path; an empty table has no value, so holds nothing."""
    if isinstance(node, Mapping):
        found: dict[KeyPath, object] = {}
        for name, item in node.items():
            found |= _leaves(item, (*path, name))
        return found
    return {path: node}


def _parse(text: str) -> dict[str, object]:
    try:
        return tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise EditError(f"not valid TOML: {error}") from error


def drop_entries(text: str, depth: int, entries: Collection[KeyPath]) -> str:
    """text without the entries (each the first `depth` components of a key path), whole tables and dotted or inline
    forms alike. Comments, blank lines (but the one a removal would double), order and line endings stay as they were.
    Raises EditError rather than return a file that does not hold exactly what the original held beside them."""
    wanted = {path for path in entries if len(path) == depth}
    if len(wanted) != len(set(entries)):
        raise EditError(f"every entry is {depth} component(s) long")
    before = _leaves(_parse(text))
    if not wanted:
        return text
    trailing = text.endswith("\n")
    lines = text.split("\n")
    if trailing:
        lines.pop()
    drop = [False] * len(lines)
    table_dropped = False
    for item in _items(lines):
        if item.kind == "header":
            table_dropped = len(item.path) >= depth and item.path[:depth] in wanted
            doomed = table_dropped
        elif item.kind == "statement":
            doomed = table_dropped or (len(item.path) >= depth and item.path[:depth] in wanted)
        else:
            continue
        for index in range(item.first, item.last + 1):
            drop[index] = doomed or drop[index]
    if not any(drop):
        return text
    kept: list[str] = []
    removed = False  # the last line dealt with was one removed, or a blank skipped after one
    for index, line in enumerate(lines):
        if drop[index]:
            removed = True
        elif removed and not line.strip() and (not kept or not kept[-1].strip()):
            continue  # the removal would leave two blank lines in a row
        else:
            removed = False
            kept.append(line)
    if kept and not any(line.strip() for line in lines[max(index for index, gone in enumerate(drop) if gone) + 1 :]):
        while kept and not kept[-1].strip():  # the removal reached the end of the file
            kept.pop()
        if kept and not trailing:
            kept[-1] = kept[-1].rstrip("\r")  # a CRLF file with no final newline ends on its last line's text
    result = "\n".join(kept) + ("\n" if kept and trailing else "")
    after = _leaves(_parse(result))
    expected = {path: value for path, value in before.items() if path[:depth] not in wanted}
    if after != expected:
        raise EditError("the edit would change something beside the entries to remove; edit the file by hand")
    return result
