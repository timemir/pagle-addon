"""Every call of the text helper fills the fields its template names, no more and no fewer (CORE-R8, DATA-R114, #512).

The helper leaves a field with no value as written (`{count}` on the screen) and ignores a field the template lacks, so
a renamed or dropped field fails silently. This reads the tree for it: every call of `ns.RenderText` (Core), `ns.Text`
(a Module's wrapper) or `Pagle.Text` whose string is a literal `L.KEY` and whose fields are a table constructor, against
the `{fields}` of that key in `data/locale/enUS/`. A call whose string or fields are computed (`L.CARD_NEEDS[source]`,
`fields` built elsewhere) is out of its reach, and the spec/shipped_text_spec.lua renders the counted strings."""

import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

from pagle_data.locale import ADDON_IDS, locale_file
from pagle_data.lua_scan import Tok, match_close, split_args, tokenize
from pagle_data.text_convert import addon_of, lua_files

ROOT = Path(__file__).resolve().parents[2]

# Who calls the helper: Core's `ns.RenderText`, a Module's `ns.Text` wrapper and `Pagle.Text` itself (Core's adapter
# `ns.Text(frame, template)` is a different function; it never has an `L.KEY` for its first argument).
_RECEIVERS = {"Text": {"ns", "pagle", "Pagle"}, "RenderText": {"ns"}}
_CATEGORIES = frozenset({"zero", "one", "two", "few", "many", "other"})
_FIELD = re.compile(r"\{([A-Za-z0-9_]+)(?::[A-Za-z0-9]+)?\}")
_BRACES = re.compile(r"\{\{|\}\}")

type Json = str | list[Json] | dict[str, Json]


def is_counted(value: Json) -> bool:
    return isinstance(value, dict) and "other" in value and set(value) <= _CATEGORIES


def template_fields(value: Json) -> set[str] | None:
    """The `{fields}` a string or a counted string names, forms together; None for what is neither."""
    if isinstance(value, str):
        return set(_FIELD.findall(_BRACES.sub("", value)))
    if is_counted(value) and isinstance(value, dict):
        found: set[str] = set()
        for form in value.values():
            if not isinstance(form, str):
                return None
            found |= set(_FIELD.findall(_BRACES.sub("", form)))
        return found
    return None


@dataclass(frozen=True)
class Call:
    path: str
    line: int
    addon: str
    key: tuple[str, ...]  # the key and the dotted names after it: L.LENGTH.mm is ("LENGTH", "mm")
    fields: frozenset[str] | None  # None where the fields are not a table constructor of `name = value` entries

    @property
    def where(self) -> str:
        return f"{self.path}:{self.line}"


def _key_of(toks: list[Tok], first: int, end: int) -> tuple[str, ...] | None:
    """The key a first argument names when it is exactly `L.KEY` or `ns.L.KEY`, dotted names after it allowed."""
    at = first
    if end - at >= 2 and toks[at].is_name("ns") and toks[at + 1].is_op("."):
        at += 2
    if end - at < 3 or not toks[at].is_name("L") or not toks[at + 1].is_op("."):
        return None
    names: list[str] = []
    at += 1
    while at < end:
        if not toks[at].is_op(".") or at + 1 >= end or toks[at + 1].kind != "name":
            return None
        names.append(toks[at + 1].text)
        at += 2
    return tuple(names)


def _fields_of(toks: list[Tok], first: int, end: int) -> frozenset[str] | None:
    """The names a table constructor sets, None for anything else (a variable, a call, an entry that is not `name = …`)."""
    if not toks[first].is_op("{") or match_close(toks, first) != end - 1:
        return None
    names: set[str] = set()
    for a, b in split_args(toks, first, end - 1):
        if a == b:  # a trailing comma
            continue
        if b - a < 3 or toks[a].kind != "name" or not toks[a + 1].is_op("="):
            return None
        names.add(toks[a].text)
    return frozenset(names)


def calls_in(path: str, source: str) -> list[Call]:
    """Every call of the helper in a file whose first argument is a literal `L.KEY`."""
    addon = addon_of(path)
    assert addon is not None
    toks = tokenize(source)
    found: list[Call] = []
    for i, tok in enumerate(toks):
        if tok.kind != "name" or tok.text not in _RECEIVERS or i < 2 or not toks[i - 1].is_op("."):
            continue
        if toks[i - 2].text not in _RECEIVERS[tok.text] or i + 1 >= len(toks) or not toks[i + 1].is_op("("):
            continue
        close = match_close(toks, i + 1)
        args = split_args(toks, i + 1, close)
        if not args:
            continue
        key = _key_of(toks, *args[0])
        if key is None:
            continue
        if len(args) == 1:
            fields: frozenset[str] | None = frozenset()
        elif len(args) == 2:
            fields = _fields_of(toks, *args[1])
        else:
            continue
        line = source.count("\n", 0, tok.start) + 1
        found.append(Call(path, line, addon, key, fields))
    return found


def english(addon: str) -> dict[str, Json]:
    path = ROOT / locale_file("enUS", ADDON_IDS[addon])
    return tomllib.loads(path.read_text(encoding="utf-8"))


def shipped_calls() -> list[Call]:
    calls: list[Call] = []
    for path in lua_files(ROOT):
        rel = path.relative_to(ROOT).as_posix()
        calls += calls_in(rel, path.read_text(encoding="utf-8"))
    return calls


def lookup(table: dict[str, Json], key: tuple[str, ...]) -> Json | None:
    value: Json | None = table
    for name in key:
        if not isinstance(value, dict) or name not in value:
            return None
        value = value[name]
    return value


def problems(call: Call, strings: dict[str, dict[str, Json]]) -> list[str]:
    """What is wrong with one call against its template, in words; nothing when they agree."""
    value = lookup(strings[call.addon], call.key)
    name = ".".join(call.key)
    if value is None:
        return [f"{call.where}: L.{name} is not in {call.addon}'s English"]
    wanted = template_fields(value)
    if wanted is None:
        return [f"{call.where}: L.{name} is neither a string nor a counted string"]
    if call.fields is None:
        return []
    given = set(call.fields)
    # A counted string picks its form by `count`, which a form that writes no number does not need to name.
    if is_counted(value):
        given.discard("count")
        wanted.discard("count")
        if "count" not in call.fields:
            return [f"{call.where}: L.{name} is counted and the call gives no count"]
    out = []
    if wanted - given:
        out.append(f"{call.where}: L.{name} names {sorted(wanted - given)} and the call does not fill it")
    if given - wanted:
        out.append(f"{call.where}: the call fills {sorted(given - wanted)}, which L.{name} does not name")
    return out


def test_every_literal_key_call_fills_the_fields_its_template_names() -> None:
    strings = {addon: english(addon) for addon in ADDON_IDS}
    wrong = [text for call in shipped_calls() for text in problems(call, strings)]

    assert wrong == []


def test_the_scan_reaches_the_calls_of_every_addon() -> None:
    """A scan that stopped finding calls would pass the test above for nothing."""
    calls = shipped_calls()

    assert {call.addon for call in calls} == set(ADDON_IDS)
    assert len(calls) > 400


_STRINGS: dict[str, dict[str, Json]] = {
    "Pagle": {
        "PLAIN": "{fish} at {zone:0}",
        "BRACES": "{{fish}} {zone}",
        "COUNTED": {"one": "A fish", "other": "{count} fish in {zone}"},
        "NO_NUMBER": {"one": "One in {zone}", "other": "Some in {zone}"},
        "NESTED": {"unit": "{length}"},
        "LIST": ["a", "b"],
    }
}


def _problems(source: str) -> list[str]:
    calls = calls_in("addons/Pagle/logic/Fake.lua", source)
    return [text for call in calls for text in problems(call, _STRINGS)]


def test_a_call_that_fills_what_the_template_names_is_fine() -> None:
    assert _problems("ns.RenderText(L.PLAIN, { fish = a, zone = b })") == []
    assert _problems("return ns.Text(ns.L.PLAIN, {\n\tfish = a,\n\tzone = b,\n})") == []
    assert _problems("Pagle.Text(L.NESTED.unit, { length = 1 })") == []
    assert _problems("ns.Text(L.COUNTED, { count = n, zone = z })") == []


def test_fields_shared_by_the_forms_of_a_counted_string_are_not_extra() -> None:
    assert _problems("ns.Text(L.NO_NUMBER, { count = n, zone = z })") == []
    assert _problems("ns.Text(L.COUNTED, { count = n, zone = z })") == []


def test_a_field_the_template_names_and_the_call_lacks_fails() -> None:
    wrong = _problems("ns.RenderText(L.PLAIN, { fish = a })")

    assert len(wrong) == 1 and "['zone']" in wrong[0] and "does not fill" in wrong[0]
    assert len(_problems("ns.Text(L.PLAIN)")) == 1
    assert len(_problems("ns.Text(L.COUNTED, { count = n })")) == 1


def test_a_field_the_call_fills_and_the_template_lacks_fails() -> None:
    wrong = _problems("ns.Text(L.PLAIN, { fish = a, zone = b, count = n })")

    assert len(wrong) == 1 and "['count']" in wrong[0] and "does not name" in wrong[0]
    assert len(_problems("ns.Text(L.BRACES, { zone = b, fish = a })")) == 1


def test_a_counted_string_needs_a_count() -> None:
    assert len(_problems("ns.Text(L.NO_NUMBER, { zone = z })")) == 1


def test_a_key_that_is_not_in_the_english_or_is_not_a_string_fails() -> None:
    assert "not in Pagle's English" in _problems("ns.Text(L.MISSING, {})")[0]
    assert "neither a string" in _problems("ns.Text(L.LIST, {})")[0]


def test_a_computed_key_or_computed_fields_are_left_alone() -> None:
    assert calls_in("addons/Pagle/logic/Fake.lua", "ns.Text(L.PLAIN[unit], { x = 1 })") == []
    assert calls_in("addons/Pagle/logic/Fake.lua", "ns.Text(key, { x = 1 })") == []
    assert calls_in("addons/Pagle/logic/Fake.lua", "ns.Text(frame, 'GameFontNormal')") == []
    assert _problems("ns.Text(L.PLAIN, fields)") == []
    assert _problems("ns.Text(L.PLAIN, { fish = a, [k] = 1 })") == []
