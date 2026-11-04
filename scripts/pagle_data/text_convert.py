"""The conversion of Pagle's interface text to the text helper (CORE-R8, DATA-R114, ADR 0019, #519).

`scripts/convert-text.py` rewrites two things in one pass, from one plan, so that they cannot disagree:

* the English strings in `data/locale/enUS/*.toml`: `%s`, `%d`, `%.1f` and `%%` become `{name}`, `{name:0}`, `{name:1}`
  and `%`, and a `KEY_ONE`/`KEY_OTHER` pair becomes one counted string, `KEY.one` and `KEY.other`;
* the call sites in `addons/*/` (outside `libs/` and the generated `locale/`): `L.KEY:format(…)`, `string.format(L.KEY,
  …)`, `ns.Fill`, `ns.Plural` and the `n == 1 and L.KEY_ONE or L.KEY_OTHER` ternaries become one call of the helper,
  `ns.RenderText` in Core and `ns.Text` (a Module's wrapper of `Pagle.Text`) in a Module.

A field's name comes from the argument at the call site where that is a plain name, a field of a table or a call of a
helper around one of those; otherwise from the key. A key is converted whole or not at all: if any use of it is one the
script cannot place, the key and all its call sites stay as they are and the use goes to the worklist, which the caller
converts by hand. Only the `L` values are touched: a `string.format` whose template is a literal (an ID, a key, a
texture string, an error for a developer) is left alone.

The plan is read from the tree, so the script is deterministic, and a tree it has converted has nothing left to plan,
so it is idempotent.
"""

import re
import tomllib
from collections import Counter
from functools import partial
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

from pagle_data.locale import ADDON_IDS, locale_file
from pagle_data.locale_convert import entry_lines
from pagle_data.lua import KEYWORDS
from pagle_data.lua_scan import (
    ScanError,
    Tok,
    match_close,
    match_open,
    prefix_start,
    span_text,
    split_args,
    string_value,
    tokenize,
)

type Json = str | list[Json] | dict[str, Json]

CORE = "Pagle"
RENDER_CORE = "ns.RenderText"
RENDER_MODULE = "ns.Text"

# A field named like one of these is an identifier, not a quantity: `%d` of it is written as it is, never grouped.
_PLAIN_NUMBER = re.compile(r"(?:^|[a-z])(?:ID|Id)$|^(?:id|key|seq|version|index|year|v)$")
# Calls that only change how a value is written: the field is named after what they are given.
_WRAPPERS = frozenset(
    "tostring shown decimal formatNumber breakUpLargeNumbers BreakUpLargeNumbers Number Round floor ceil listed "
    "capitalised tonumber abs lower upper concat join".split()
)
# Wrappers that put a count in digits as it is: `{count}`, not `{count:n}`.
_PLAIN_WRAPPERS = frozenset({"tostring", "tonumber", "floor", "ceil", "abs"})
_NOT_A_NAME = frozenset(
    "format self ns L Pagle string math table lower upper rep sub gsub unpack select pairs ipairs next type".split()
)
_BINARY = frozenset({"+", "-", "*", "/", "%", "..", "==", "~=", "<", ">", "<=", ">="})

_DIRECTIVE = re.compile(r"%([-+ #0]*)(\d*)(?:\.(\d+))?([A-Za-z%])")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_CONVERTED_PARAGRAPH = re.compile(
    r"^# Converted from the hand-written enUS\.lua by scripts/convert-enus-locale\.py:.*?\(docs/spec/content-data\.md\)\.$",
    re.MULTILINE | re.DOTALL,
)
_NEW_PARAGRAPH = (
    "# Converted from the hand-written enUS.lua by scripts/convert-enus-locale.py, then rewritten to the text helper's\n"
    "# named fields by scripts/convert-text.py (CORE-R8): `%s` and `%d` became `{name}` and `{name:0}`, and a\n"
    '# `_ONE`/`_OTHER` pair one counted string. A key is `KEY = "text"`; an array is `KEY = [...]`; a table is dotted keys\n'
    '# (`KEY.sub = "text"`), a whole-number key being the Lua integer key (`CONTINENT_NAMES.0`), and a table of plural\n'
    "# categories is a counted string. The shape is in DATA-R114 (docs/spec/content-data.md)."
)


class ConvertError(Exception):
    """The tree cannot be converted at all (a missing file, TOML that does not read)."""


# --- the TOML files ----------------------------------------------------------------------------------------------------


@dataclass
class Group:
    """One top-level key of an addon's English file with the comment lines above it and its own lines."""

    key: str
    trivia: list[str]
    lines: list[str]
    value: Json


@dataclass
class StringsFile:
    """An addon's English TOML: the lines before the first key, its groups in order, and the lines after the last."""

    head: list[str]
    groups: list[Group]
    foot: list[str]

    def render(self) -> str:
        out = list(self.head)
        for group in self.groups:
            out += group.trivia
            out += group.lines
        out += self.foot
        return "\n".join(out) + "\n"

    def by_key(self) -> dict[str, Group]:
        return {group.key: group for group in self.groups}


def _top_key(line: str) -> str:
    match = re.match(r'([A-Za-z0-9_]+|"[^"]*")', line)
    if match is None:
        raise ConvertError(f"cannot read the key of the TOML line {line!r}")
    return match.group(1)


def parse_strings(text: str) -> StringsFile:
    """The groups of an English file. A group is every consecutive line of one top-level key, a multi-line array whole."""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    head: list[str] = []
    groups: list[Group] = []
    trivia: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.startswith("#"):
            trivia.append(line)
            i += 1
            continue
        block = [line]
        if line.rstrip().endswith("["):
            i += 1
            while lines[i].rstrip() != "]":
                block.append(lines[i])
                i += 1
            block.append(lines[i])
        i += 1
        key = _top_key(line)
        if groups and groups[-1].key == key and not trivia:
            groups[-1].lines += block
        else:
            if not groups:
                head, trivia = trivia, []
            groups.append(Group(key, trivia, block, ""))
        trivia = []
    for group in groups:
        parsed = tomllib.loads("\n".join(group.lines))
        if len(parsed) != 1:
            raise ConvertError(f"the key {group.key} is written in two places")
        group.value = next(iter(parsed.values()))
    return StringsFile(head, groups, trivia)


# --- format directives -------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Spec:
    """What one `%` directive writes: its kind and, for a number, the places after the point. `pad` is `%02d`, which the
    helper cannot write, so the call site writes it and the field is a plain string."""

    kind: Literal["s", "d", "f", "pad"]
    places: int = 0

    def suffix(self, name: str) -> str:
        """The spec `{name…}` takes in the helper."""
        if self.kind == "d":
            return "" if _PLAIN_NUMBER.search(name) else ":0"
        if self.kind == "f":
            return f":{self.places}"
        return ""


def directives(template: str) -> list[tuple[re.Match[str], Spec | None]]:
    """Each `%` directive of a template, in order, with the Spec it becomes; None for one the helper cannot write
    (`%x`, `%5.2f`, `% o`). A `%%` is not a directive and is not listed."""
    found: list[tuple[re.Match[str], Spec | None]] = []
    for match in _DIRECTIVE.finditer(template):
        flags, width, places, conversion = match.groups()
        spec: Spec | None
        if match.group(0) == "%%":
            continue
        if conversion == "s" and not flags and not width and places is None:
            spec = Spec("s")
        elif conversion in "di" and not flags and not width and places is None:
            spec = Spec("d")
        elif conversion in "di" and flags == "0" and width == "2" and places is None:
            spec = Spec("pad")
        elif conversion == "f" and not flags and not width and places is not None:
            spec = Spec("f", int(places))
        else:
            spec = None
        found.append((match, spec))
    return found


def leaves(value: Json, path: tuple[str, ...] = ()) -> Iterator[tuple[tuple[str, ...], str]]:
    """Every string of a value with the keys (or 1-based positions) that reach it."""
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, list):
        for position, item in enumerate(value, 1):
            yield from leaves(item, (*path, str(position)))
    else:
        for name, item in value.items():
            yield from leaves(item, (*path, name))


def map_leaves(value: Json, change: Callable[[str], str]) -> Json:
    """The value with `change` applied to every string in it."""
    if isinstance(value, str):
        return change(value)
    if isinstance(value, list):
        return [map_leaves(item, change) for item in value]
    return {name: map_leaves(item, change) for name, item in value.items()}


# --- Lua call sites ----------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class LRef:
    """A string of `ns.L` read by name: `L.KEY`, `ns.L.KEY`, with the subscripts after it (`L.KEY[action]`)."""

    first: int  # token range [first, end)
    end: int
    key_at: int
    key: str
    tail: bool  # subscripts follow the key


def lref_at(toks: list[Tok], i: int) -> LRef | None:
    """The read `L.KEY` whose `L` is token `i`, or None where `L` is something else."""
    if i + 2 >= len(toks) or not toks[i].is_name("L") or not toks[i + 1].is_op(".") or toks[i + 2].kind != "name":
        return None
    first = i
    if i > 0 and toks[i - 1].is_op("."):
        if i > 1 and toks[i - 2].is_name("ns"):
            first = i - 2
        else:
            return None
    end = i + 3
    tail = False
    while end < len(toks):
        if toks[end].is_op("["):
            end = match_close(toks, end) + 1
            tail = True
        elif (
            toks[end].is_op(".")
            and end + 1 < len(toks)
            and toks[end + 1].kind == "name"
            and not (end + 2 < len(toks) and toks[end + 2].is_op("("))
        ):
            end += 2
            tail = True
        else:
            break
    return LRef(first, end, i + 2, toks[i + 2].text, tail)


Kind = Literal["format", "pair", "tern", "plural", "fill"]


@dataclass
class Site:
    """One place to rewrite: the characters [start, end) of a file become a call of the helper."""

    kind: Kind
    path: str
    addon: str
    line: int
    start: int
    end: int
    keys: tuple[str, ...]  # the strings of ns.L it uses; a pair as its base key
    template: str  # the source text of the template argument
    args: list[str] = field(default_factory=list)  # the format arguments, as written
    count: str | None = None  # a pair's count expression, or Plural's first argument
    inner: str | None = None  # Plural's field table: the text between its braces
    count_at: int | None = None  # a CountText call: the directive that writes the count (its first)
    formatted: bool = False  # a CountText call that gave its own number formatter


@dataclass
class FileScan:
    path: str
    addon: str
    source: str
    toks: list[Tok]
    sites: list[Site] = field(default_factory=list)
    unplaced: list[tuple[int, str]] = field(default_factory=list)  # a :format on something other than a literal or L
    covered: list[tuple[int, int]] = field(default_factory=list)  # character ranges of every recognised use
    refs: list[tuple[LRef, int]] = field(default_factory=list)  # every read of a string of ns.L, with its line
    loose: list[tuple[int, str]] = field(default_factory=list)  # something the script cannot place


def _line_of(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def plural_base(key: str) -> str | None:
    """The base of a `KEY_ONE` key."""
    return key[: -len("_ONE")] if key.endswith("_ONE") and len(key) > len("_ONE") else None


def _is_pair(one: str, other: str) -> bool:
    base = plural_base(one)
    return base is not None and other in (base, base + "_OTHER")


def _format_call(toks: list[Tok], at: int) -> tuple[int, int] | None:
    """For `: format (` at token `at`, the indexes of the brackets of its arguments."""
    if (
        at + 2 < len(toks)
        and toks[at].is_op(":")
        and toks[at + 1].is_name("format")
        and toks[at + 2].is_op("(")
    ):
        return at + 2, match_close(toks, at + 2)
    return None


def scan_file(path: str, addon: str, source: str) -> FileScan:
    """Every use of a string of `ns.L` in a Lua file that the converter rewrites, and every one it reads."""
    toks = tokenize(source)
    scan = FileScan(path, addon, source, toks)
    taken: set[int] = set()  # token indexes already inside a site

    def take(first: int, end: int, hole: tuple[int, int] | None = None) -> None:
        """Marks tokens [first, end) as a site, except the arguments in `hole`, which may hold sites of their own."""
        _cover(scan, taken, first, end, hole)

    def arg_texts(opener: int, closer: int) -> list[str]:
        return [span_text(source, toks, a, b) for a, b in split_args(toks, opener, closer)]

    for i, tok in enumerate(toks):
        lref = lref_at(toks, i) if tok.is_name("L") else None
        if lref is not None:
            scan.refs.append((lref, _line_of(source, toks[lref.first].start)))

    # n == 1 and L.KEY_ONE[:format(…)] or L.KEY[_OTHER][:format(…)]: a count that picks its singular.
    for lref, line in list(scan.refs):
        base = plural_base(lref.key)
        a = lref.first
        if base is None or lref.tail or a < 4 or not toks[a - 1].is_name("and"):
            continue
        if toks[a - 2].text != "1" or not toks[a - 3].is_op("=="):
            continue
        cstart = prefix_start(toks, a - 4)
        if cstart > 0 and toks[cstart - 1].is_op("#"):
            cstart -= 1
        count = span_text(source, toks, cstart, a - 3)
        end = lref.end
        args: list[str] = []
        hole: tuple[int, int] | None = None
        call = _format_call(toks, end)
        if call is not None:
            args = arg_texts(*call)
            hole = (call[0] + 1, call[1])
            end = call[1] + 1
        if end + 1 >= len(toks) or not toks[end].is_name("or"):
            continue
        other = next((r for r, _ in scan.refs if r.first == end + 1), None)
        if other is None or other.tail or not _is_pair(lref.key, other.key):
            continue
        end = other.end
        call = _format_call(toks, end)
        if call is not None:
            args = arg_texts(*call)
            hole = (call[0] + 1, call[1])
            end = call[1] + 1
        first = cstart
        # (n == 1 and L.A or L.B):format(…): the parentheses go with it.
        if cstart > 0 and toks[cstart - 1].is_op("(") and end < len(toks) and toks[end].is_op(")"):
            after = _format_call(toks, end + 1)
            if after is not None and match_close(toks, cstart - 1) == end:
                args = arg_texts(*after)
                hole = (after[0] + 1, after[1])
                first, end = cstart - 1, after[1] + 1
        prefix = source[toks[other.first].start : toks[other.key_at].start]
        scan.sites.append(
            Site("pair", path, addon, line, toks[first].start, toks[end - 1].end, (base,), prefix + base, args, count)
        )
        take(first, end, hole)

    for i, tok in enumerate(toks):
        if i in taken:
            continue
        call = _format_call(toks, i)
        if call is not None:
            site = _format_site(scan, i, call, taken)
            if site is not None:
                scan.sites.append(site)
            else:
                receiver = prefix_start(toks, i - 1)
                if not toks[receiver].kind == "str" and not (
                    toks[receiver].is_op("(") and toks[receiver + 1].kind == "str" and match_close(toks, receiver) == i - 1
                ):
                    scan.unplaced.append((_line_of(source, toks[i].start), span_text(source, toks, receiver, i)))
            continue
        if tok.is_name("string") and not (i > 0 and toks[i - 1].is_op(".", ":")):
            site = _string_format_site(scan, i, taken)
            if site is not None:
                scan.sites.append(site)
            continue
        if tok.is_name("ns") and i + 3 < len(toks) and toks[i + 2].is_name("CountText") and toks[i + 3].is_op("("):
            counted = _count_text_site(scan, i)
            if counted is not None:
                scan.sites.append(counted)
                take(i, match_close(toks, i + 3) + 1)
            continue
        if (
            tok.is_name("ns")
            and i + 3 < len(toks)
            and toks[i + 1].is_op(".")
            and toks[i + 2].is_name("Fill", "Plural")
            and toks[i + 3].is_op("(")
            and not (i > 0 and toks[i - 1].is_name("function"))
        ):
            _fill_or_plural(scan, i)
            take(i, match_close(toks, i + 3) + 1, (i + 4, match_close(toks, i + 3)))
    return scan


def _cover(scan: FileScan, taken: set[int], first: int, end: int, hole: tuple[int, int] | None) -> None:
    """Tokens [first, end) are one site; the arguments in `hole` (token indexes) are not part of it."""
    toks = scan.toks
    if hole is None or hole[0] >= hole[1]:
        taken.update(range(first, end))
        scan.covered.append((toks[first].start, toks[end - 1].end))
        return
    taken.update(range(first, hole[0]))
    taken.update(range(hole[1], end))
    scan.covered.append((toks[first].start, toks[hole[0] - 1].end))
    scan.covered.append((toks[hole[1]].start, toks[end - 1].end))


def _lref_before(scan: FileScan, first: int, end: int) -> LRef | None:
    """The read of an L string that is exactly tokens [first, end)."""
    return next((r for r, _ in scan.refs if r.first == first and r.end == end), None)


def _format_site(scan: FileScan, colon: int, call: tuple[int, int], taken: set[int]) -> Site | None:
    toks, source = scan.toks, scan.source
    first = prefix_start(toks, colon - 1)
    if any(index in taken for index in range(first, call[0] + 1)):
        return None
    line = _line_of(source, toks[colon].start)
    args = [span_text(source, toks, a, b) for a, b in split_args(toks, *call)]
    lref = _lref_before(scan, first, colon)
    start, end = toks[first].start, toks[call[1]].end
    if lref is not None:
        site = Site("format", scan.path, scan.addon, line, start, end, (lref.key,), span_text(source, toks, first, colon), args)
    elif toks[first].is_op("(") and match_close(toks, first) == colon - 1:
        refs = [r for r, _ in scan.refs if first < r.first < colon]
        inner = toks[first + 1 : colon - 1]
        if not refs or not any(t.is_name("and", "or") for t in inner):
            return None
        keys = tuple(r.key for r in refs)
        site = Site("tern", scan.path, scan.addon, line, start, end, keys, span_text(source, toks, first + 1, colon - 1), args)
    else:
        return None
    _cover(scan, taken, first, call[1] + 1, (call[0] + 1, call[1]))
    return site


def _string_format_site(scan: FileScan, i: int, taken: set[int]) -> Site | None:
    toks, source = scan.toks, scan.source
    if not (i + 3 < len(toks) and toks[i + 1].is_op(".") and toks[i + 2].is_name("format") and toks[i + 3].is_op("(")):
        return None
    closer = match_close(toks, i + 3)
    ranges = split_args(toks, i + 3, closer)
    if not ranges:
        return None
    lref = _lref_before(scan, ranges[0][0], ranges[0][1])
    if lref is None:
        return None
    texts = [span_text(source, toks, a, b) for a, b in ranges]
    _cover(scan, taken, i, closer + 1, (ranges[0][1] + 1, closer))
    return Site("format", scan.path, scan.addon, _line_of(source, toks[i].start), toks[i].start, toks[closer].end, (lref.key,), texts[0], texts[1:])


def _count_text_site(scan: FileScan, i: int) -> Site | None:
    """`ns.CountText(n, L.KEY_ONE, L.KEY_OTHER[, format])` (Ledger) or `ns.CountText(n, "KEY"[, format])` (Hunts): a
    count written in its singular or plural string, with the number written by `format` or as it is."""
    toks, source = scan.toks, scan.source
    if not toks[i + 1].is_op("."):
        return None
    closer = match_close(toks, i + 3)
    ranges = split_args(toks, i + 3, closer)
    texts = [span_text(source, toks, a, b) for a, b in ranges]
    line = _line_of(source, toks[i].start)
    start, end = toks[i].start, toks[closer].end
    if len(ranges) >= 3 and _lref_before(scan, *ranges[1]) is not None:
        one = _lref_before(scan, *ranges[1])
        other = _lref_before(scan, *ranges[2])
        if one is not None and other is not None and not one.tail and not other.tail and _is_pair(one.key, other.key):
            base = plural_base(one.key)
            assert base is not None
            prefix = source[toks[other.first].start : toks[other.key_at].start]
            if len(ranges) > 4:
                return None
            return Site("pair", scan.path, scan.addon, line, start, end, (base,), prefix + base, [], texts[0], None, 0, len(ranges) == 4)
        return None
    if len(ranges) in (2, 3):
        key = string_value(texts[1])
        if key is not None:
            return Site("pair", scan.path, scan.addon, line, start, end, (key,), "ns.L." + key, [], texts[0], None, 0, len(ranges) == 3)
    return None


def _fill_or_plural(scan: FileScan, i: int) -> None:
    toks, source = scan.toks, scan.source
    opener = i + 3
    closer = match_close(toks, opener)
    line = _line_of(source, toks[i].start)
    if toks[i + 2].text == "Fill":
        scan.sites.append(Site("fill", scan.path, scan.addon, line, toks[i].start, toks[i + 2].end, (), ""))
        return
    ranges = split_args(toks, opener, closer)
    texts = [span_text(source, toks, a, b) for a, b in ranges]
    key = string_value(texts[1]) if len(texts) >= 2 else None
    inner: str | None = None
    if len(ranges) == 3:
        a, b = ranges[2]
        if toks[a].is_op("{") and match_close(toks, a) == b - 1:
            inner = source[toks[a].end : toks[b - 1].start].strip()
        else:
            key = None
    if key is None or len(texts) not in (2, 3):
        scan.loose.append((line, "ns.Plural with a key or fields that are not literals"))
        return
    scan.sites.append(
        Site("plural", scan.path, scan.addon, line, toks[i].start, toks[closer].end, (key,), "", [], texts[0], inner)
    )


# --- naming ------------------------------------------------------------------------------------------------------------


def _camel(word: str) -> str:
    if "_" in word and word.upper() == word:
        head, *rest = word.lower().split("_")
        return head + "".join(part.capitalize() for part in rest)
    if word.upper() == word:
        return word.lower()
    return word[:1].lower() + word[1:]


def _valid(name: str | None) -> str | None:
    if name is None or name in KEYWORDS or name in _NOT_A_NAME or not _NAME.fullmatch(name) or not 2 < len(name) <= 24:
        return None
    return name


def name_of(expr: str) -> str | None:
    """A field name for a call argument: a plain name, the last field of a table, the table indexed, what a wrapper
    such as tostring or a number formatter is given, the left side of a sum, the list a `#` counts; else None."""
    try:
        toks = tokenize(expr)
    except ScanError:
        return None
    try:
        return _valid(_name_of(toks))
    except ScanError:
        return None


def _name_of(toks: list[Tok]) -> str | None:
    if not toks:
        return None
    while len(toks) > 2 and toks[0].is_op("(") and match_close(toks, 0) == len(toks) - 1:
        toks = toks[1:-1]
    depth = 0
    for i, tok in enumerate(toks):
        if tok.is_op("(", "[", "{"):
            depth += 1
        elif tok.is_op(")", "]", "}"):
            depth -= 1
        elif depth == 0 and i > 0 and tok.is_name("and", "or"):
            return _name_of(toks[:i])
        elif depth == 0 and i > 0 and tok.is_op(*_BINARY):
            return None  # a sum, a product or a comparison is not what its first operand is called
    if toks[0].is_op("#") or toks[0].is_name("not"):
        return _name_of(toks[1:])
    last = toks[-1]
    if last.is_op(")"):
        opener = match_open(toks, len(toks) - 1)
        callee = toks[opener - 1] if opener > 0 else None
        if callee is None or callee.kind != "name":
            return None
        ranges = split_args(toks, opener, len(toks) - 1)
        inner = toks[ranges[0][0] : ranges[0][1]] if ranges else []
        if callee.text in _WRAPPERS:
            return _name_of(inner)
        return _camel(re.sub(r"^(Get|Format|Set)(?=[A-Z])", "", callee.text))
    if last.is_op("]"):
        return _name_of(toks[: match_open(toks, len(toks) - 1)])
    if last.kind == "name" and last.text not in ("nil", "true", "false"):
        return _camel(last.text)
    return None


def wrapper_of(arg: str, count: str) -> str | None:
    """How a call argument writes the count of a pair: "" for the count itself, the wrapper's name for `W(count)`,
    else None."""
    if arg.strip() == count.strip():
        return ""
    try:
        toks = tokenize(arg)
    except ScanError:
        return None
    if len(toks) < 4 or not toks[-1].is_op(")") or prefix_start(toks, len(toks) - 1) != 0:
        return None
    opener = match_open(toks, len(toks) - 1)
    callee = toks[opener - 1]
    inner = span_text(arg, toks, opener + 1, len(toks) - 1) if opener + 1 < len(toks) - 1 else ""
    return callee.text if callee.kind == "name" and inner.strip() == count.strip() else None


# --- the plan ----------------------------------------------------------------------------------------------------------


@dataclass
class KeyPlan:
    """What one string of ns.L becomes: a field name and a Spec for each directive, in order; which directive writes the
    count of a counted string, and whether a number formatter fed it, so that its field writes `:n`."""

    key: str
    names: list[str]
    specs: list[Spec]
    count_at: int | None = None
    wrapped: bool = False


@dataclass
class Plan:
    root: Path
    strings: dict[str, StringsFile]
    scans: list[FileScan]
    merges: dict[str, dict[str, str]] = field(default_factory=dict)  # addon -> {base key: its KEY_ONE key}
    keys: dict[tuple[str, str], KeyPlan] = field(default_factory=dict)  # (addon, key) -> plan, a merged key as its base
    counted: dict[str, set[str]] = field(default_factory=dict)  # addon -> keys of ns.Plural, whose {n} becomes {count}
    worklist: list[str] = field(default_factory=list)


def addon_of(path: str) -> str | None:
    parts = path.split("/")
    return parts[1] if len(parts) > 2 and parts[0] == "addons" and parts[1] in ADDON_IDS else None


def lua_files(root: Path) -> list[Path]:
    """The Lua files of the addons that are neither vendored nor generated, in path order."""
    return [
        path
        for path in sorted((root / "addons").glob("*/**/*.lua"))
        if not {"libs", "locale"} & set(path.relative_to(root).parts)
    ]


def _fallback_name(family: str, position: int, total: int) -> str:
    base = family.lower()
    return base if total == 1 else f"{base}_{position + 1}"


def build_plan(root: Path) -> Plan:
    strings: dict[str, StringsFile] = {}
    for addon, file_id in ADDON_IDS.items():
        path = root / locale_file("enUS", file_id)
        if not path.is_file():
            raise ConvertError(f"{path}: no English file; run scripts/convert-enus-locale.py first")
        strings[addon] = parse_strings(path.read_text(encoding="utf-8"))
    scans: list[FileScan] = []
    for path in lua_files(root):
        rel = path.relative_to(root).as_posix()
        owner_addon = addon_of(rel)
        assert owner_addon is not None
        try:
            scans.append(scan_file(rel, owner_addon, path.read_text(encoding="utf-8")))
        except ScanError as error:
            raise ConvertError(f"{rel}: {error}") from error
    plan = Plan(root, strings, scans)
    for addon in strings:
        _plan_addon(plan, addon)
    return plan


def merged_view(plan: Plan, addon: str) -> dict[str, Json]:
    """The addon's strings with the merged pairs as counted strings, in file order (a pair where its first key was)."""
    file = plan.strings[addon]
    pairs = plan.merges.get(addon, {})
    by_key = file.by_key()
    owner: dict[str, str] = {}
    for base, one in pairs.items():
        for key in (one, base + "_OTHER", base):
            if key in by_key:
                owner[key] = base
    view: dict[str, Json] = {}
    for group in file.groups:
        pair_base = owner.get(group.key)
        if pair_base is None:
            view[group.key] = group.value
        elif pair_base not in view:
            other = by_key.get(pair_base + "_OTHER") or by_key[pair_base]
            view[pair_base] = {"one": by_key[pairs[pair_base]].value, "other": other.value}
    return view


def _uncovered(scan: FileScan, lref: LRef) -> bool:
    start, end = scan.toks[lref.first].start, scan.toks[lref.end - 1].end
    return not any(a <= start and end <= b for a, b in scan.covered)


def _plan_addon(plan: Plan, addon: str) -> None:
    file = plan.strings[addon]
    by_key = file.by_key()
    scans = [scan for scan in plan.scans if scan.addon == addon]
    # Pairs: a KEY_ONE with a KEY_OTHER beside it, or with a KEY that a pair site reads.
    pair_sites = {site.keys[0] for scan in scans for site in scan.sites if site.kind == "pair"}
    pairs: dict[str, str] = {}
    for key, group in by_key.items():
        base = plural_base(key)
        if base is None or not isinstance(group.value, str):
            continue
        other = by_key.get(base + "_OTHER")
        if other is None:
            other = by_key.get(base) if base in pair_sites else None
        elif base in by_key:
            plan.worklist.append(f"{addon} {base}: {base}, {key} and {base}_OTHER are all written, so they are not merged")
            continue
        if other is not None and isinstance(other.value, str):
            pairs[base] = key
    # A pair that anything but a pair site reads is left as it is for the worklist.
    for base, one in list(pairs.items()):
        names = {one, base + "_OTHER", base}
        loose = [
            f"{scan.path}:{line}: {lref.key} is read outside a pair site, so its pair {base} is not merged"
            for scan in scans
            for lref, line in scan.refs
            if lref.key in names and _uncovered(scan, lref)
        ]
        loose += [
            f"{scan.path}: the string {tok.text} names {base}, so its pair is not merged"
            for scan in scans
            for tok in scan.toks
            if tok.kind == "str"
            and string_value(tok.text) in (base, base + "_ONE", base + "_OTHER")
            and not any(a <= tok.start and tok.end <= b for a, b in scan.covered)
        ]
        if loose:
            plan.worklist += loose
            del pairs[base]
    plan.merges[addon] = pairs
    view = merged_view(plan, addon)
    # Ternaries and parenthesised choices share one set of field names: keys of one site form a family.
    families: dict[str, set[str]] = {}
    for scan in scans:
        for site in scan.sites:
            if site.kind == "tern":
                joined = set(site.keys)
                for key in site.keys:
                    joined |= families.get(key, {key})
                for key in joined:
                    families[key] = joined
    sites_of: dict[str, list[Site]] = {}
    for scan in scans:
        for site in scan.sites:
            for key in dict.fromkeys(site.keys):
                sites_of.setdefault(key, []).append(site)
    done: set[str] = set()
    for key, value in view.items():
        if key in done:
            continue
        family = sorted(families.get(key, {key}))
        done.update(family)
        _plan_family(plan, addon, scans, family, {k: view[k] for k in family if k in view}, sites_of)
    for base in list(pairs):
        if (addon, base) not in plan.keys and any("%" in text for _, text in leaves(view[base])):
            plan.worklist.append(f"{addon} {base}: not merged, since its directives are not planned")
            del pairs[base]
    for scan in scans:
        for site in scan.sites:
            if site.kind == "plural":
                plan.counted.setdefault(addon, set()).add(site.keys[0])


def _plan_family(
    plan: Plan,
    addon: str,
    scans: list[FileScan],
    family: list[str],
    values: dict[str, Json],
    sites_of: dict[str, list[Site]],
) -> None:
    where = f"{addon} {', '.join(family)}"
    members = {key: [directives(text) for _, text in leaves(value)] for key, value in values.items()}
    members = {key: found for key, found in members.items() if any("%" in text for _, text in leaves(values[key]))}
    # A `%` that no call formats and no directive explains ("50% off", a converted "{rate:1}% of") is just text.
    members = {
        key: found
        for key, found in members.items()
        if sites_of.get(key) or any(spec is not None for lists in found for _, spec in lists)
    }
    if not members:
        return
    for key, found_lists in members.items():
        for found in found_lists:
            if any(spec is None for _, spec in found):
                plan.worklist.append(f"{addon} {key}: a directive the helper cannot write")
                return
    for key in members:
        if any(re.search(r"[{}]", text) for _, text in leaves(values[key])):
            plan.worklist.append(f"{addon} {key}: a string with a directive and a brace")
            return
    totals = {key: max((len(found) for found in found_lists), default=0) for key, found_lists in members.items()}
    specs: dict[str, list[Spec]] = {}
    for key, found_lists in members.items():
        chosen: list[Spec] = []
        for position in range(totals[key]):
            wanted = {found[position][1] for found in found_lists if len(found) > position}
            if len(wanted) != 1:
                plan.worklist.append(f"{addon} {key}: its strings disagree on directive {position + 1}")
                return
            spec = next(iter(wanted))
            assert spec is not None
            chosen.append(spec)
        specs[key] = chosen
    for position in range(max(totals.values())):
        if len({spec[position].kind == "pad" for spec in specs.values() if len(spec) > position}) > 1:
            plan.worklist.append(f"{where}: its strings disagree on whether directive {position + 1} is %02d")
            return
    sites: list[Site] = []
    for key in family:
        for site in sites_of.get(key, []):
            if site not in sites and site.kind in ("format", "pair", "tern"):
                sites.append(site)
    total = max(totals.values())
    if total == 0:
        # Only `%%`: the string is rewritten and its calls lose their arguments.
        for key in members:
            plan.keys[(addon, key)] = KeyPlan(key, [], [])
        return
    if not sites:
        plan.worklist.append(f"{where}: has directives and no call that formats it")
        return
    for key in members:
        for scan in scans:
            for lref, line in scan.refs:
                if lref.key in (key, key + "_ONE", key + "_OTHER") and _uncovered(scan, lref):
                    plan.worklist.append(f"{scan.path}:{line}: {lref.key} is read where the script cannot rewrite it")
                    return
    for site in sites:
        needed = max(totals.get(key, 0) for key in site.keys)
        have = len(site.args) + (1 if site.count_at is not None else 0)
        if have < needed:
            plan.worklist.append(f"{site.path}:{site.line}: {where} has {needed} directive(s) and the call gives {have}")
            return
        if any(arg.strip().endswith("...") for arg in site.args):
            plan.worklist.append(f"{site.path}:{site.line}: the arguments of {where} are a vararg")
            return
    count_at = _count_position(plan, where, sites)
    if count_at == -1:
        return
    names: list[str] = []
    for position in range(total):
        if position == count_at:
            names.append("count")
            continue
        votes: Counter[str] = Counter()
        first_seen: dict[str, int] = {}
        for index, site in enumerate(sites):
            candidate = name_of(site.args[position]) if position < len(site.args) else None
            if candidate is not None and candidate != "count":
                votes[candidate] += 1
                first_seen.setdefault(candidate, index)
        chosen_name = min(votes, key=lambda name: (-votes[name], first_seen[name])) if votes else None
        if chosen_name is None or chosen_name in names:
            chosen_name = _fallback_name(family[0], position, total)
        names.append(chosen_name)
    if len(set(names)) != total:
        names = ["count" if i == count_at else _fallback_name(family[0], i, total) for i in range(total)]
    wrapped = False
    if count_at is not None:
        wrappers = {_count_wrapper(site, count_at) for site in sites if site.kind == "pair" and site.count_at is None}
        wrapped = any(w not in ("", None) and w not in _PLAIN_WRAPPERS for w in wrappers) or any(
            site.formatted for site in sites
        )
    for key in members:
        plan.keys[(addon, key)] = KeyPlan(key, names, specs[key], count_at, wrapped)


def _count_wrapper(site: Site, position: int) -> str | None:
    if site.count is None or position >= len(site.args):
        return None
    return wrapper_of(site.args[position], site.count)


def _count_position(plan: Plan, where: str, sites: list[Site]) -> int | None:
    """Which directive writes the count of a pair, None for a key that is not a pair; -1, with a worklist entry, when
    the sites disagree or the count is not among the arguments."""
    pair_sites = [site for site in sites if site.kind == "pair"]
    if not pair_sites:
        return None
    found: set[int] = set()
    for site in pair_sites:
        assert site.count is not None
        if site.count_at is not None:
            found.add(site.count_at)
            continue
        for i, arg in enumerate(site.args):
            if wrapper_of(arg, site.count) is not None:
                found.add(i)
                break
    if not found:
        return None
    if len(found) != 1:
        plan.worklist.append(f"{where}: the count {pair_sites[0].count!r} is among the arguments at different places")
        return -1
    return found.pop()


# --- applying the plan -------------------------------------------------------------------------------------------------


def _renderer(addon: str) -> str:
    return RENDER_CORE if addon == CORE else RENDER_MODULE


def _count_field(text: str) -> str:
    """The count of a string that `ns.Plural` filled is `{count}`, not `{n}`."""
    return text.replace("{n}", "{count}")


def convert_text(text: str, plan: KeyPlan) -> str:
    """One string with its directives written as fields."""
    names = iter(range(len(plan.names)))
    out: list[str] = []
    last = 0
    for match in _DIRECTIVE.finditer(text):
        out.append(text[last : match.start()].replace("{", "{{").replace("}", "}}"))
        last = match.end()
        if match.group(0) == "%%":
            out.append("%")
            continue
        position = next(names)
        spec = plan.specs[position]
        name = plan.names[position]
        if position == plan.count_at:
            suffix = ":n" if plan.wrapped else (":0" if spec.kind == "d" else spec.suffix(name))
        else:
            suffix = spec.suffix(name)
        out.append("{" + name + suffix + "}")
    out.append(text[last:].replace("{", "{{").replace("}", "}}"))
    return "".join(out)


def new_strings(plan: Plan, addon: str) -> str:
    """An addon's English file after the conversion."""
    file = plan.strings[addon]
    pairs = plan.merges.get(addon, {})
    view = merged_view(plan, addon)
    by_key = file.by_key()
    owner: dict[str, str] = {}
    for base, one in pairs.items():
        for key in (one, base + "_OTHER", base):
            if key in by_key:
                owner[key] = base
    counted = plan.counted.get(addon, set())
    groups: list[Group] = []
    emitted: dict[str, Group] = {}
    for group in file.groups:
        pair_base = owner.get(group.key)
        if pair_base is not None and pair_base in emitted:
            emitted[pair_base].trivia += [line for line in group.trivia if line.startswith("#")]
            continue
        key = pair_base if pair_base is not None else group.key
        value = view[key]
        key_plan = plan.keys.get((addon, key))
        if key_plan is not None:
            value = map_leaves(value, partial(convert_text, plan=key_plan))
        if key in counted:
            value = map_leaves(value, _count_field)
        if pair_base is None and value == group.value:
            groups.append(group)
            continue
        merged = Group(key, list(group.trivia), entry_lines(key, value), value)
        groups.append(merged)
        if pair_base is not None:
            emitted[pair_base] = merged
    text = StringsFile(file.head, groups, file.foot).render()
    return _CONVERTED_PARAGRAPH.sub(lambda _: _NEW_PARAGRAPH, text)


def _render_site(plan: Plan, site: Site, has_local_l: bool) -> str | None:
    """The call of the helper a site becomes, or None when its key is not planned (the site stays)."""
    render = _renderer(site.addon)
    addon = site.addon
    if site.kind == "fill":
        return render
    if site.kind == "plural":
        key = site.keys[0]
        if key not in merged_view(plan, addon) or (site.inner and re.search(r"(?:^|[,\s])n\s*=", site.inner)):
            return None
        fields = [f"count = {site.count}"]
        if site.inner:
            fields.append(site.inner.rstrip(","))
        return f"{render}({'ns.L.' if not has_local_l else 'L.'}{key}, {{ {', '.join(fields)} }})"
    if site.kind == "pair":
        base = site.keys[0]
        if base not in plan.merges.get(addon, {}):
            return None
        key_plan = plan.keys.get((addon, base))
        fields = [f"count = {site.count}"]
        if key_plan is not None:
            for position, name in enumerate(key_plan.names):
                if position != key_plan.count_at and position < len(site.args):
                    fields.append(f"{name} = {_field_value(key_plan, position, site.args[position])}")
        return f"{render}({site.template}, {{ {', '.join(fields)} }})"
    plans = [plan.keys.get((addon, key)) for key in site.keys]
    if any(key in plan.merges.get(addon, {}) for key in site.keys):
        return None  # a counted string is read by its pair sites, never by a plain format call
    if any(p is None for p in plans):
        return None
    key_plans = [p for p in plans if p is not None]
    names = key_plans[0].names
    limit = max(len(p.specs) for p in key_plans)
    if limit == 0:
        return f"{render}({site.template})"
    fields = [
        f"{names[position]} = {_field_value(next(p for p in key_plans if len(p.specs) > position), position, site.args[position])}"
        for position in range(min(limit, len(site.args)))
    ]
    return f"{render}({site.template}, {{ {', '.join(fields)} }})"


def _field_value(key_plan: KeyPlan, position: int, arg: str) -> str:
    return f'("%02d"):format({arg})' if key_plan.specs[position].kind == "pad" else arg


def rewrite_source(plan: Plan, path: str, addon: str, source: str) -> str:
    """The Lua file with every site the plan covers rewritten, innermost first, until none is left."""
    has_local_l = re.search(r"^local L = ns\.L\b", source, re.MULTILINE) is not None
    for _ in range(12):
        scan = scan_file(path, addon, source)
        candidates: list[tuple[Site, str]] = []
        for site in scan.sites:
            text = _render_site(plan, site, has_local_l)
            if text is not None:
                candidates.append((site, text))
        inner = [
            (site, text)
            for site, text in candidates
            if not any(other is not site and site.start <= other.start and other.end <= site.end for other, _ in candidates)
        ]
        if not inner:
            return source
        for site, text in sorted(inner, key=lambda pair: pair[0].start, reverse=True):
            source = source[: site.start] + text + source[site.end :]
    raise ConvertError(f"{path}: the rewrite did not settle")


@dataclass
class Result:
    files: dict[str, str] = field(default_factory=dict)  # path relative to the root -> new text; only files that change
    worklist: list[str] = field(default_factory=list)
    report: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)  # :format calls on something that is not an L string, for a look


def convert(root: Path) -> Result:
    """Plans the conversion of the tree at `root` and returns what would change, without writing anything."""
    plan = build_plan(root)
    result = Result(worklist=list(plan.worklist))
    for addon, file_id in ADDON_IDS.items():
        path = locale_file("enUS", file_id)
        text = new_strings(plan, addon)
        if text != (root / path).read_text(encoding="utf-8"):
            result.files[path] = text
    for scan in plan.scans:
        rewritten = rewrite_source(plan, scan.path, scan.addon, scan.source)
        if rewritten != scan.source:
            result.files[scan.path] = rewritten
    _remove_helpers(plan, result)
    _verify(plan, result)
    _check_specs(plan, result)
    for (addon, key), key_plan in sorted(plan.keys.items()):
        fields = ", ".join(f"{name}{key_plan.specs[i].suffix(name)}" for i, name in enumerate(key_plan.names[: len(key_plan.specs)]))
        result.report.append(f"{addon} {key}: {fields}")
    return result


def _verify(plan: Plan, result: Result) -> None:
    """What is still to do by hand once the plan is applied: the sites it left and the strings still in `%` form."""
    for scan in plan.scans:
        source = result.files.get(scan.path, scan.source)
        after = scan_file(scan.path, scan.addon, source)
        for site in after.sites:
            if site.kind in ("format", "pair", "tern", "plural") or site.kind == "fill":
                what = {"fill": "ns.Fill", "plural": "ns.Plural"}.get(site.kind, f"{site.template}:format")
                result.worklist.append(f"{scan.path}:{site.line}: {what} stays: its string is not planned")
        for line, message in after.loose:
            result.worklist.append(f"{scan.path}:{line}: {message}")
        for line, receiver in after.unplaced:
            result.notes.append(f"{scan.path}:{line}: {receiver[:60]}:format is on neither an L string nor a literal")
    for addon, file_id in ADDON_IDS.items():
        file_text = result.files.get(locale_file("enUS", file_id))
        if file_text is None:
            file_text = (plan.root / locale_file("enUS", file_id)).read_text(encoding="utf-8")
        for number, row in enumerate(file_text.splitlines(), 1):
            if not row.startswith("#") and re.search(r"%[0-9.]*[sdif]", row):
                result.worklist.append(f"{locale_file('enUS', file_id)}:{number}: still has a `%` directive: {row[:90]}")
            if re.match(r"[A-Za-z_0-9]+_(ONE|OTHER) =", row):
                result.worklist.append(f"{locale_file('enUS', file_id)}:{number}: a _ONE/_OTHER key remains: {row[:60]}")



def _definition(name: str, local: bool) -> re.Pattern[str]:
    head = rf"local function {name}\(" if local else rf"function ns\.{name}\("
    return re.compile(rf"(?:^--[^\n]*\n)*^{head}.*?\n^end\n\n?", re.MULTILINE | re.DOTALL)


def _uses(source: str, name: str) -> int:
    """How many times code (not a comment) says `ns.<name>` other than to define it."""
    toks = tokenize(source)
    return sum(
        1
        for i in range(len(toks) - 2)
        if toks[i].is_name("ns")
        and toks[i + 1].is_op(".")
        and toks[i + 2].is_name(name)
        and not (i > 0 and toks[i - 1].is_name("function"))
    )


def _remove_helpers(plan: Plan, result: Result) -> None:
    """Deletes `ns.Fill`, `ns.Plural` and the `ns.CountText` helpers once nothing calls them, and the `pick` that only
    Plural used."""
    sources = {scan.path: result.files.get(scan.path, scan.source) for scan in plan.scans}
    spec_text = "\n".join(path.read_text(encoding="utf-8") for path in _spec_files(plan.root))
    for name in ("Fill", "Plural", "CountText"):
        pattern = _definition(name, False)
        owners = [path for path, source in sources.items() if pattern.search(source)]
        if not owners or sum(_uses(source, name) for source in [*sources.values(), spec_text]) > 0:
            continue
        for path in owners:
            sources[path] = pattern.sub("", sources[path])
            if not _uses(sources[path], "pick") and "pick(" not in _definition("pick", True).sub("", sources[path]):
                sources[path] = _definition("pick", True).sub("", sources[path], count=1)
            result.files[path] = sources[path]


def _spec_files(root: Path) -> list[Path]:
    return [
        path
        for path in sorted((root / "spec").glob("**/*.lua"))
        if "fixtures" not in path.relative_to(root).parts and "scripts" not in path.relative_to(root).parts[1:2]
    ]


def _check_specs(plan: Plan, result: Result) -> None:
    """The specs are converted by hand: report any that still read a converted string as a template."""
    converted = {key for _, key in plan.keys}
    converted |= {base for pairs in plan.merges.values() for base in pairs}
    for path in _spec_files(plan.root):
        rel = path.relative_to(plan.root).as_posix()
        scan = scan_file(rel, "", path.read_text(encoding="utf-8"))
        for site in scan.sites:
            if site.kind in ("fill", "plural") or set(site.keys) & converted:
                result.worklist.append(f"{rel}:{site.line}: a spec still uses {site.template or 'ns.Fill/ns.Plural'}")


def main(argv: list[str], root: Path) -> int:
    import argparse
    import shutil
    import subprocess
    import sys

    if argv[:1] == ["es"]:
        from pagle_data.text_convert_es import main as convert_es_main

        return convert_es_main(argv[1:], root)
    parser = argparse.ArgumentParser(
        prog="scripts/convert-text.py",
        description="Rewrite Pagle's English interface text and its call sites to the text helper (CORE-R8, #519).",
    )
    parser.add_argument("--dry-run", action="store_true", help="plan and report, write nothing")
    parser.add_argument("--report", action="store_true", help="print every converted string's fields")
    parser.add_argument("--notes", action="store_true", help="print the :format calls on something that is not an L string")
    parser.add_argument("--no-format", action="store_true", help="do not run StyLua on the Lua files it changed")
    parser.add_argument("--no-generate", action="store_true", help="do not run the generator afterwards")
    args = parser.parse_args(argv)
    try:
        result = convert(root)
    except ConvertError as error:
        print(f"convert-text: {error}", file=sys.stderr)
        return 1
    if args.report:
        for line in result.report:
            print(line)
    if args.notes:
        for line in result.notes:
            print("note:", line)
    for line in result.worklist:
        print("worklist:", line)
    print(f"convert-text: {len(result.files)} file(s) change, {len(result.worklist)} worklist item(s)")
    if args.dry_run:
        return 1 if result.worklist else 0
    for path, text in result.files.items():
        (root / path).write_text(text, encoding="utf-8")
    lua_changed = sorted(path for path in result.files if path.endswith(".lua"))
    if lua_changed and not args.no_format:
        here = Path(__file__).resolve().parents[2]
        candidates = [root / ".tools" / "bin" / "stylua", here / ".tools" / "bin" / "stylua"]
        stylua = next((str(path) for path in candidates if path.exists()), None) or shutil.which("stylua")
        if stylua is None:
            print(f"convert-text: no StyLua at {candidates[0]}; run scripts/setup.sh", file=sys.stderr)
            return 1
        # StyLua settles a nested call in two passes, so the second makes the first stable.
        for _ in range(2):
            subprocess.run([stylua, *lua_changed], cwd=root, check=True)
    if result.files and not args.no_generate:
        from pagle_data.cli import main as generate

        if generate([], root) != 0:
            return 1
    return 1 if result.worklist else 0
