"""Interface text in more than one language (DATA-R114, ADR 0019): data/locale/<code>/*.toml, the generated
addons/<Addon>/locale/<code>.lua and the `<Script>` list of locale/Locales.xml.

A Locale is a directory named by its full client code. `locale.toml` is its header (its own name, translators, `listed`,
plural rule, separators and fallback) and `<id>.toml` holds one addon's strings, the ids being FILES' keys. enUS is the
source: its files hold `KEY = "text"`. Another Locale's files hold, for each key it translates,
`[KEY]` with `value` (the translation) and `en` (the EN snapshot, the English it was translated from); both have
English's shape.

A value is a string, an array of values, or a table of values (whose keys are any text, or whole numbers, which TOML
writes as the bare keys `0`, `2`). A table whose keys are all plural categories is a counted string. An entry replaces
English's whole at runtime, so a translation has English's shape: the same array length, the same keys.

The layer is inert while data/locale/ does not exist: every addon keeps its hand-written locale/enUS.lua.
"""

import re
import subprocess
import tomllib
from collections.abc import Collection, Iterator, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.glyphs import ENGLISH, glyphs_for
from pagle_data.lore import CORE_GUARD, check_text_glyphs
from pagle_data.lua import KEYWORDS, to_lua
from pagle_data.plural import CATEGORIES, RULES, plural_lua
from pagle_data.toml_reader import check_keys, describe, read_toml

type Value = str | list[Value] | dict[str | int, Value]

LOCALE_DIR = "data/locale"
HEADER_FILE = "locale.toml"

# DATA-R114: each addon's file id (data/locale/<code>/<id>.toml, named like data/lore/*.toml) and its folder.
FILES = {
    "core": "Pagle",
    "hunts": "Pagle_Hunts",
    "ledger": "Pagle_Ledger",
    "qol": "Pagle_QoL",
    "stats": "Pagle_Stats",
    "tackleboard": "Pagle_TackleBoard",
}
ADDON_IDS = {addon: file_id for file_id, addon in FILES.items()}

# What English is built in as (Core's logic/Text.lua): the header of enUS must say the same, so the default stays data.
BUILT_IN = {"plural": "one_other", "decimal": ".", "thousands": ","}

_CODE = re.compile(r"[a-z]{2}[A-Z]{2}")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"0|[1-9][0-9]*")
_FIELD = re.compile(r"\{([A-Za-z0-9_]+)(?::[A-Za-z0-9]+)?\}")

HEADER_KEYS = ("name", "translators", "listed", "plural", "decimal", "thousands", "fallback")


def locale_file(code: str, file_id: str) -> str:
    return f"{LOCALE_DIR}/{code}/{file_id}.toml"


def header_file(code: str) -> str:
    return f"{LOCALE_DIR}/{code}/{HEADER_FILE}"


def locale_lua(addon: str, code: str) -> str:
    """The locale file an addon's Locale becomes (DATA-R75)."""
    return f"addons/{addon}/locale/{code}.lua"


def locales_xml(addon: str) -> str:
    return f"addons/{addon}/locale/Locales.xml"


@dataclass(frozen=True)
class Header:
    """A Locale's header as locale.toml gives it (DATA-R114). `plural`, `decimal` and `thousands` may be None only
    where a `fallback` gives them."""

    code: str
    name: str
    translators: tuple[str, ...]
    listed: bool
    plural: str | None
    decimal: str | None
    thousands: str | None
    fallback: str | None


@dataclass(frozen=True)
class Entry:
    """One key of a Locale's file: its value, and for a translation the EN snapshot beside it."""

    value: Value
    en: Value | None = None


@dataclass
class LocaleLayer:
    """data/locale/ as read. present is false when the directory is not there at all (the layer is then inert)."""

    present: bool = False
    headers: dict[str, Header] = field(default_factory=dict)
    files: dict[str, dict[str, dict[str, Entry]]] = field(default_factory=dict)  # code -> file id -> key -> entry
    warnings: list[str] = field(default_factory=list)


def _sub(at: At, name: str | int) -> At:
    return at / str(name)


def _item(at: At, index: int) -> At:
    return At(at.file, f"{at.path}[{index}]")


def _value(raw: object, at: At, problems: Problems) -> Value | None:
    """raw as a Value, or None with a problem: strings, arrays and tables of them, nothing else."""
    if isinstance(raw, str):
        return raw
    if isinstance(raw, list):
        if not raw:
            problems.add(at, "shape: an empty array (DATA-R114)")
            return None
        items = [_value(item, _item(at, index), problems) for index, item in enumerate(raw, 1)]
        return None if any(item is None for item in items) else [item for item in items if item is not None]
    if isinstance(raw, dict):
        if not raw:
            problems.add(at, "shape: an empty table (DATA-R114)")
            return None
        table: dict[str | int, Value] = {}
        ok = True
        for name, item in raw.items():
            key: str | int
            if _NUMBER.fullmatch(name):
                key = int(name)
            elif name:
                key = name
            else:
                problems.add(at, "shape: an empty key (DATA-R114)")
                ok = False
                continue
            value = _value(item, _sub(at, name), problems)
            if value is None:
                ok = False
            else:
                table[key] = value
        return table if ok else None
    problems.add(at, f"shape: expected text, an array or a table, got {describe(raw)} (DATA-R114)")
    return None


def _read_entries(root: Path, code: str, file_id: str, problems: Problems) -> dict[str, Entry] | None:
    file = locale_file(code, file_id)
    document = read_toml(root, file, problems)
    if document is None:
        return None
    entries: dict[str, Entry] = {}
    for key, raw in document.items():
        at = At(file, key)
        if not _NAME.fullmatch(key) or key in KEYWORDS:
            problems.add(
                at, "shape: a key is a Lua name: letters, digits and _, not starting with a digit, not a keyword (DATA-R114)"
            )
            continue
        if code == ENGLISH:
            value = _value(raw, at, problems)
            if value is not None:
                entries[key] = Entry(value)
            continue
        if not isinstance(raw, dict) or set(raw) != {"value", "en"}:
            problems.add(at, "shape: a translated key is a table with `value` and `en` (the EN snapshot) (DATA-R114)")
            continue
        value = _value(raw["value"], at / "value", problems)
        snapshot = _value(raw["en"], at / "en", problems)
        if value is not None and snapshot is not None:
            entries[key] = Entry(value, snapshot)
    return entries


def _string(table: Mapping[str, object], name: str, at: At, problems: Problems, *, empty: bool = False) -> str | None:
    value = table.get(name)
    if value is None:
        return None
    if not isinstance(value, str):
        problems.add(at / name, f"header: expected a string, got {describe(value)} (DATA-R114)")
        return None
    if not value and not empty:
        problems.add(at / name, "header: empty (DATA-R114)")
        return None
    return value


def _read_header(root: Path, code: str, problems: Problems) -> Header | None:
    file = header_file(code)
    table = read_toml(root, file, problems)
    if table is None:
        return None
    at = At(file)
    english = code == ENGLISH
    # English is always listed and falls back to nothing; a fallback Locale takes its fallback's rule and separators.
    required = ["name", "plural", "decimal", "thousands"] if english else ["name", "listed"]
    optional = ["translators"] if english else [name for name in HEADER_KEYS if name not in required]
    fallback = table.get("fallback")
    if not english and fallback is None:
        required += ["plural", "decimal", "thousands"]
        optional = [name for name in optional if name not in required]
    before = len(problems.found)
    check_keys(table, at, problems, required=required, optional=optional)
    name = _string(table, "name", at, problems)
    plural = _string(table, "plural", at, problems)
    if plural is not None and plural not in RULES:
        problems.add(at / "plural", f"header: '{plural}' is not a plural rule; the rules are {', '.join(RULES)} (DATA-R114)")
    decimal = _string(table, "decimal", at, problems)
    thousands = _string(table, "thousands", at, problems, empty=True)
    if decimal is not None and decimal == thousands:
        problems.add(at / "thousands", f"header: the same separator as the decimal, '{decimal}' (DATA-R114)")
    listed = table.get("listed", english)
    if not isinstance(listed, bool):
        problems.add(at / "listed", f"header: expected true or false, got {describe(listed)} (DATA-R114)")
    translators = table.get("translators", [])
    if not isinstance(translators, list) or not all(isinstance(item, str) and item for item in translators):
        problems.add(at / "translators", "header: expected an array of names (DATA-R114)")
        translators = []
    fallback_code = _string(table, "fallback", at, problems)
    if len(problems.found) > before or name is None or not isinstance(listed, bool):
        return None
    return Header(code, name, tuple(translators), listed, plural, decimal, thousands, fallback_code)


def read_locale(root: Path, problems: Problems) -> LocaleLayer:
    """Every Locale under root/data/locale/, its header and its files as written. Only the shape is checked here;
    what the text says is check_locale's. The layer is not present when data/locale/ is not there."""
    base = root / LOCALE_DIR
    if not base.is_dir():
        return LocaleLayer()
    layer = LocaleLayer(present=True)
    for directory in sorted(path for path in base.iterdir() if path.is_dir()):
        code = directory.name
        at = At(f"{LOCALE_DIR}/{code}")
        if not _CODE.fullmatch(code):
            problems.add(at, "a Locale's directory is its full client code, like esES (DATA-R114)")
            continue
        try:
            glyphs_for(code)
        except ValueError as error:
            problems.add(at, f"no range for the Locale (CORE-R9, DATA-R114): {error}")
            continue
        header = _read_header(root, code, problems)
        if header is not None:
            layer.headers[code] = header
        found = {path.name for path in directory.iterdir()}
        for name in sorted(found):
            if name != HEADER_FILE and not (name.endswith(".toml") and name[:-5] in FILES):
                known = ", ".join(f"{file_id}.toml" for file_id in FILES)
                problems.add(At(f"{LOCALE_DIR}/{code}/{name}"), f"not a file of a Locale: {HEADER_FILE} or one of {known} (DATA-R114)")
        for file_id in FILES:
            if code == ENGLISH and f"{file_id}.toml" not in found:
                problems.add(At(locale_file(code, file_id)), "missing: English has a file for every addon (DATA-R114)")
            if f"{file_id}.toml" in found:
                entries = _read_entries(root, code, file_id, problems)
                if entries is not None:
                    layer.files.setdefault(code, {})[file_id] = entries
    return layer


# --- checks ---------------------------------------------------------------------------------------------------------


def leaves(value: Value, path: str = "") -> Iterator[tuple[str, str]]:
    """Each string in value with its path below the key, as `.name` and `[n]` (arrays count from 1, as Lua does)."""
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, list):
        for index, item in enumerate(value, 1):
            yield from leaves(item, f"{path}[{index}]")
    else:
        for name, item in value.items():
            yield from leaves(item, f"{path}.{name}")


def is_counted(value: Value) -> bool:
    """A counted string (CORE-R8): a table whose keys are all plural categories."""
    return isinstance(value, dict) and all(isinstance(name, str) and name in CATEGORIES for name in value)


def fields_of(text: str) -> set[str]:
    """The `{field}` names in a template: `{{` and `}}` are literal braces, a spec after a colon is not part of the
    name (DATA-R114)."""
    return set(_FIELD.findall(text.replace("{{", "").replace("}}", "")))


def _lines(text: str) -> int:
    return text.count("\n") + text.count("\r")


@dataclass(frozen=True)
class Rules:
    """What a Locale's chain gives the checks: the categories its plural rule uses, if it has one."""

    plural: str | None
    decimal: str | None
    thousands: str | None


def effective(code: str, headers: Mapping[str, Header]) -> Rules:
    """The rule and separators a Locale ends up with: its own, field by field, over its fallback's (the merge
    ns.ApplyLocale does, DATA-R114)."""
    chain: list[Header] = []
    at: str | None = code
    while at is not None and at in headers and at not in {header.code for header in chain}:
        chain.append(headers[at])
        at = headers[at].fallback
    plural = decimal = thousands = None
    for header in reversed(chain):
        plural = header.plural or plural
        decimal = header.decimal or decimal
        thousands = header.thousands if header.thousands is not None else thousands
    return Rules(plural, decimal, thousands)


def _check_headers(layer: LocaleLayer, problems: Problems) -> None:
    for code, header in layer.headers.items():
        at = At(header_file(code))
        if code == ENGLISH:
            for name, expected in BUILT_IN.items():
                if getattr(header, name) != expected:
                    message = f"header: English is built in as {expected!r} here (logic/Text.lua), got {getattr(header, name)!r}"
                    problems.add(at / name, f"{message} (DATA-R114)")
        check_text_glyphs(at / "name", header.name, code, problems, "DATA-R114")
        for index, translator in enumerate(header.translators, 1):
            check_text_glyphs(_item(at / "translators", index), translator, code, problems, "DATA-R114")
        fallback = header.fallback
        if fallback is None:
            continue
        if fallback == code or fallback == ENGLISH:
            problems.add(at / "fallback", f"header: a fallback is another Locale, never its own or {ENGLISH} (DATA-R114)")
        elif fallback not in layer.headers:
            problems.add(at / "fallback", f"header: no Locale {fallback} in {LOCALE_DIR}/ (DATA-R114)")
        else:
            seen = {code}
            at_code: str | None = fallback
            while at_code is not None and at_code in layer.headers:
                if at_code in seen:
                    problems.add(at / "fallback", f"header: the fallback chain loops through {at_code} (DATA-R114)")
                    break
                seen.add(at_code)
                at_code = layer.headers[at_code].fallback
        rules = effective(code, layer.headers)
        if None in (rules.plural, rules.decimal, rules.thousands):
            problems.add(at, f"header: no plural rule or separators for {code}, nor from its fallback (DATA-R114)")


def _check_english(layer: LocaleLayer, problems: Problems) -> None:
    """The checks of English itself: it is the source, so only what makes a file unusable."""
    header = layer.headers.get(ENGLISH)
    if header is None:
        problems.add(At(f"{LOCALE_DIR}/{ENGLISH}"), f"missing: English is the source of every Locale ({HEADER_FILE}, DATA-R114)")
        return
    rule = RULES.get(header.plural or "")
    categories = rule.categories if rule else ("one", "other")
    for file_id in FILES:
        file = locale_file(ENGLISH, file_id)
        entries = layer.files.get(ENGLISH, {}).get(file_id)
        if entries is None:
            continue
        for key, entry in entries.items():
            for path, text in leaves(entry.value):
                check_text_glyphs(At(file, key + path), text, ENGLISH, problems, "DATA-R114")
            for path, table in _counted(entry.value, ""):
                names = {name for name in table if isinstance(name, str)}
                if "other" not in names or not names <= set(categories):
                    detail = f"has {sorted(names)}; English needs other and may have {', '.join(categories)}"
                    problems.add(At(file, key + path), f"plural: a counted string {detail} ({ENGLISH}, DATA-R114)")


def _counted(value: Value, path: str) -> Iterator[tuple[str, dict[str | int, Value]]]:
    """Each counted string inside value, with its path."""
    if isinstance(value, dict):
        if is_counted(value):
            yield path, value
        else:
            for name, item in value.items():
                yield from _counted(item, f"{path}.{name}")
    elif isinstance(value, list):
        for index, item in enumerate(value, 1):
            yield from _counted(item, f"{path}[{index}]")


class _Judge:
    """The comparison of one translated entry against English's, collecting its problems under the Locale's name."""

    def __init__(self, code: str, categories: frozenset[str], problems: Problems) -> None:
        self.code = code
        self.categories = categories
        self.problems = problems
        self.top = ""  # the key of the entry being judged
        self.empty: set[tuple[str, str]] = set()  # (file, key) of each entry with an empty text English fills

    def fail(self, file: str, key: str, check: str, detail: str) -> None:
        self.problems.add(At(file, key), f"{check}: {detail} ({self.code}, DATA-R114)")

    def text(self, file: str, key: str, english: str, translated: str) -> None:
        if not translated.strip():
            if english.strip():  # English's own empty text (a separator) may be empty here too
                self.fail(file, key, "missing", "the text is empty")
                self.empty.add((file, self.top))
            return
        wanted, found = fields_of(english), fields_of(translated)
        if wanted != found:
            lacks = ", ".join("{" + name + "}" for name in sorted(wanted - found))
            extra = ", ".join("{" + name + "}" for name in sorted(found - wanted))
            detail = "; ".join(part for part in (f"lacks {lacks}" if lacks else "", f"adds {extra}" if extra else "") if part)
            self.fail(file, key, "placeholder", f"the {{field}} set differs from the English text's: {detail}")
        if _lines(english) != _lines(translated):
            self.fail(file, key, "newline", f"{_lines(translated)} line break(s), the English text has {_lines(english)}")
        check_text_glyphs(At(file, key), translated, self.code, self.problems, "DATA-R114")

    def value(self, file: str, key: str, english: Value, translated: Value) -> None:
        """translated against english at one path; a different shape stops the descent."""
        if isinstance(english, str):
            if isinstance(translated, str):
                self.text(file, key, english, translated)
            else:
                self.fail(file, key, "shape", "English has text here")
        elif isinstance(english, list):
            if not isinstance(translated, list) or len(translated) != len(english):
                self.fail(file, key, "shape", f"English has an array of {len(english)} here")
                return
            for index, (one, other) in enumerate(zip(english, translated, strict=True), 1):
                self.value(file, f"{key}[{index}]", one, other)
        elif is_counted(english):
            self.counted(file, key, english, translated)
        else:
            if not isinstance(translated, dict) or set(translated) != set(english):
                names = ", ".join(str(name) for name in english)
                self.fail(file, key, "shape", f"English has a table with {names} here, and an entry replaces it whole")
                return
            for name, one in english.items():
                self.value(file, f"{key}.{name}", one, translated[name])

    def counted(self, file: str, key: str, english: dict[str | int, Value], translated: Value) -> None:
        if not isinstance(translated, dict) or not is_counted(translated):
            self.fail(file, key, "shape", "English has a counted string here, a table of plural categories")
            return
        names = {name for name in translated if isinstance(name, str)}
        problems = []
        if "other" not in names:
            problems.append("lacks other")
        if self.categories - names - {"other"}:
            problems.append("lacks " + ", ".join(sorted(self.categories - names)))
        if names - self.categories:
            problems.append("has " + ", ".join(sorted(names - self.categories)) + ", which its rule never gives")
        if problems:
            rule = ", ".join(category for category in CATEGORIES if category in self.categories)
            self.fail(file, key, "plural", f"{'; '.join(problems)}; its rule uses {rule}")
        for name in CATEGORIES:
            form = translated.get(name)
            if isinstance(form, str):
                twin = english.get(name, english.get("other"))
                if isinstance(twin, str):
                    self.text(file, f"{key}.{name}", twin, form)


def _drift(code: str, file: str, key: str, english: Value, entry: Entry, warnings: list[str]) -> None:
    """DATA-R114's drift: an EN snapshot that is not the English now. It warns and never fails."""
    if entry.en == english:
        return
    old = {name for _, text in leaves(entry.en or "") for name in fields_of(text)}
    new = {name for _, text in leaves(english) for name in fields_of(text)}
    if old == new:
        detail = "the {fields} are the same, so it keeps showing"
    else:
        detail = "the {fields} changed, so it is dropped to English by the maintainer's script"
    warnings.append(f"{file}: {key}: drift: the EN snapshot is not the English text now ({code}); {detail}")


def judge_coverage(
    code: str,
    listed: bool,
    listed_before: bool | None,
    covered: int,
    total: int,
    gaps: list[str],
    problems: Problems,
    warnings: list[str],
) -> None:
    """DATA-R114's coverage rule (the dev's decision, 4 Nov: 100% to enter, stays listed). A Locale below 100% of the
    interface fails only where it is listed now and was not at the merge base (listed_before False: absent counts as
    False). Where it was already listed (True), or the base is not known (None), the gap is a warning: an English
    change never fails on a translator."""
    if not listed or covered >= total:
        return
    sample = ", ".join(gaps[:5]) + (" …" if len(gaps) > 5 else "")
    detail = f"{code} covers {covered} of {total} keys of the interface; the gaps are {sample}"
    if listed_before is False:
        problems.add(At(header_file(code), "listed"), f"coverage: {detail}; a Locale is listed only at 100% (DATA-R114)")
    else:
        warnings.append(f"{header_file(code)}: listed: coverage: {detail}; they show English (DATA-R114)")


def check_locale(layer: LocaleLayer, problems: Problems, listed_before: Mapping[str, bool] | None = None) -> None:
    """Every DATA-R114 check over the layer: missing, orphan, placeholder, newline, glyph, plural, coverage and the
    header, each naming the key, the check and the Locale. Drift and the gaps of an already listed Locale go to
    layer.warnings. listed_before is each Locale's `listed` at the merge base (absent there counts as False), or None
    where no base is known."""
    if not layer.present:
        return
    _check_headers(layer, problems)
    _check_english(layer, problems)
    english = layer.files.get(ENGLISH, {})
    english_keys = {
        file_id: {key: entry.value for key, entry in entries.items()} for file_id, entries in english.items()
    }
    total = sum(len(keys) for keys in english_keys.values())
    empties: dict[str, set[tuple[str, str]]] = {}
    for code in sorted(layer.headers):
        if code == ENGLISH:
            continue
        rules = effective(code, layer.headers)
        rule = RULES.get(rules.plural or "")
        judge = _Judge(code, frozenset(rule.categories if rule else CATEGORIES), problems)
        for file_id, entries in layer.files.get(code, {}).items():
            file = locale_file(code, file_id)
            for key, entry in entries.items():
                judge.top = key
                if key not in english_keys.get(file_id, {}):
                    elsewhere = [other for other, keys in english_keys.items() if key in keys]
                    detail = f"belongs to {elsewhere[0]}.toml, not {file_id}.toml" if elsewhere else "English has no such key"
                    problems.add(At(file, key), f"orphan: {detail} ({code}, DATA-R114)")
                    continue
                if rule is not None:
                    judge.value(file, key, english_keys[file_id][key], entry.value)
                if entry.en is not None:
                    _drift(code, file, key, english_keys[file_id][key], entry, layer.warnings)
        empties[code] = judge.empty
    for code in sorted(layer.headers):
        if code == ENGLISH:
            continue
        covered, gaps = 0, []
        chain = _chain(code, layer.headers)
        for file_id, keys in english_keys.items():
            for key in keys:
                have = any(
                    key in layer.files.get(link, {}).get(file_id, {})
                    and (locale_file(link, file_id), key) not in empties.get(link, set())
                    for link in chain
                )
                if have:
                    covered += 1
                else:
                    gaps.append(f"{file_id}.{key}")
        before = None if listed_before is None else listed_before.get(code, False)
        judge_coverage(code, layer.headers[code].listed, before, covered, total, gaps, problems, layer.warnings)


def _chain(code: str, headers: Mapping[str, Header]) -> list[str]:
    """code, then its fallback, and so on."""
    chain: list[str] = []
    at: str | None = code
    while at is not None and at in headers and at not in chain:
        chain.append(at)
        at = headers[at].fallback
    return chain


def fallback_chain(code: str, headers: Mapping[str, Header]) -> list[str]:
    """code, then its fallback, and so on: the Locales whose text counts toward code's coverage (DATA-R114)."""
    return _chain(code, headers)


class _Probe(_Judge):
    """A _Judge that keeps the names of the checks a value fails, and nothing else."""

    def __init__(self, code: str, categories: frozenset[str]) -> None:
        super().__init__(code, categories, Problems())
        self.checks: list[str] = []

    def fail(self, file: str, key: str, check: str, detail: str) -> None:
        self.checks.append(check)


# The checks an English change can break in a translation that was fine before it (DATA-R114's drift): the {field} set,
# the line breaks and the shape. missing, glyph and plural depend on the translation and its Locale alone.
DRIFT_CHECKS = ("placeholder", "newline", "shape")


def broken_by_english(code: str, categories: frozenset[str], english: Value, translated: Value) -> list[str]:
    """The names, among DRIFT_CHECKS, of the checks that `translated` fails against `english` as it is now, each once and
    in the order found. Empty when the translation still fits the English text it stands beside (DATA-R114)."""
    probe = _Probe(code, categories)
    probe.value("", "", english, translated)
    return [check for check in DRIFT_CHECKS if check in probe.checks]


# --- the merge base --------------------------------------------------------------------------------------------------


def _git(root: Path, *args: str) -> str:
    done = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=False)
    if done.returncode != 0:
        raise LookupError(done.stderr.strip() or f"git {' '.join(args)} failed")
    return done.stdout


def listed_at_base(root: Path, ref: str) -> dict[str, bool]:
    """Each Locale's `listed` at the merge base of HEAD and `ref` (the pull request's base branch), absent files
    left out (DATA-R114's coverage rule). Raises LookupError where git cannot say."""
    base = _git(root, "merge-base", "HEAD", ref).strip()
    listed: dict[str, bool] = {}
    for path in _git(root, "ls-tree", "-r", "--name-only", base, "--", LOCALE_DIR).splitlines():
        parts = path.split("/")
        if len(parts) == 4 and parts[3] == HEADER_FILE:
            try:
                header = tomllib.loads(_git(root, "show", f"{base}:{path}"))
            except tomllib.TOMLDecodeError:
                continue
            listed[parts[2]] = header.get("listed") is True
    return listed


# --- output ----------------------------------------------------------------------------------------------------------


def _header_comment(source: str, translators: tuple[str, ...] = ()) -> str:
    lines = [
        f"-- Generated by scripts/generate-data.py from {source}. Do not edit by hand: edit data/ and run the generator.",
        "-- GPL-3.0-or-later.",
    ]
    if translators:
        lines.append(f"-- Translators: {', '.join(translators)}.")
    return "\n".join(lines) + "\n"


def _classes(addon: str) -> tuple[str, str]:
    namespace = addon.replace("_", "") + "NS"
    return namespace, namespace[:-2] + "Strings"


def _prelude(addon: str, source: str, translators: tuple[str, ...] = ()) -> str:
    """The guard of a Module (CORE-R11; it must be a Module's first lines), the header and the namespace. Core's file
    has no guard: `Pagle` does not exist while Core loads."""
    guard = "" if addon == "Pagle" else CORE_GUARD + "\n"
    return f"{guard}{_header_comment(source, translators)}\n---@class {_classes(addon)[0]}\nlocal ns = select(2, ...)\n\n"


def english_lua(addon: str, entries: Mapping[str, Entry]) -> str:
    """enUS.lua: the addon's string table filled at load, so a bare client and the specs need no registration
    (DATA-R114). English is built in and never registered."""
    file_id = ADDON_IDS[addon]
    lines = "".join(
        f"\t{key} = {to_lua(entries[key].value, 1)},\n" for key in sorted(entries, key=lambda name: name.encode("utf-8"))
    )
    strings = _classes(addon)[1]
    return f"{_prelude(addon, locale_file(ENGLISH, file_id))}---@class {strings}\nns.L = {{\n{lines}}}\n"


def translation_lua(addon: str, header: Header, entries: Mapping[str, Entry]) -> str:
    """<code>.lua: one `ns.Locale` call with the Locale's strings, its name, `listed`, fallback, plural rule and
    separators (DATA-R114). A field the Locale leaves to its fallback is left out."""
    file_id = ADDON_IDS[addon]
    prelude = _prelude(addon, locale_file(header.code, file_id), header.translators)
    keys = sorted(entries, key=lambda name: name.encode("utf-8"))
    body = "".join(f"\tL.{key} = {to_lua(entries[key].value, 1)}\n" for key in keys)
    options = [f"\tname = {to_lua(header.name)},", f"\tlisted = {to_lua(header.listed)},"]
    if header.translators:
        options.append(f"\ttranslators = {to_lua(list(header.translators))},")
    if header.fallback is not None:
        options.append(f"\tfallback = {to_lua(header.fallback)},")
    if header.plural is not None:
        options.append(f"\tplural = {plural_lua(header.plural, 1)},")
    if header.decimal is not None:
        options.append(f"\tdecimal = {to_lua(header.decimal)},")
    if header.thousands is not None:
        options.append(f"\tthousands = {to_lua(header.thousands)},")
    argument = "L" if body else ""
    return (
        f"{prelude}ns.Locale({to_lua(header.code)}, function({argument})\n{body}end, {{\n" + "\n".join(options) + "\n})\n"
    )


# locale/Locales.xml, written whole (DATA-R114): the stable first and last entries around one `<Script>` per language.
_XML_HEAD = """\
<Ui xmlns="http://www.blizzard.com/wow/ui/">
	<!-- Every addon's one locale line (ADR 0019, DATA-R114): the TOC names this file once, after locale\\enUS.lua and
	data\\Lore.lua, and never a language. The scripts run in this order: the registration call, then one generated file
	for each language this addon has, each followed by that language's Lore file when it has one (the generator writes
	that list), then the step that applies the Language. Paths are relative to this file. A new language adds a line
	here and none in the TOC. -->
	<Script file="Registry.lua"/>
"""
_XML_TAIL = """\
	<Script file="Apply.lua"/>
</Ui>
"""


def locales_xml_text(codes: list[str], lore: Collection[str] = ()) -> str:
    """Locales.xml for an addon whose interface languages (never enUS, which the TOC loads) are `codes`, already in
    the order they load. A language in `lore` has a Lore file (DATA-R104), listed right after its interface file: the
    file sits in data/, a folder up from this XML, and registers as a second function for the code."""
    lines = ""
    for code in codes:
        lines += f'\t<Script file="{code}.lua"/>\n'
        if code in lore:
            lines += f'\t<Script file="..\\data\\Lore.{code}.lua"/>\n'
    return _XML_HEAD + lines + _XML_TAIL


def _load_order(layer: LocaleLayer, codes: list[str]) -> list[str]:
    """codes with a fallback ahead of the Locales that fall back to it (esES before esMX), then by code."""
    return sorted(codes, key=lambda code: (len(_chain(code, layer.headers)), code))


def locale_outputs(layer: LocaleLayer, lore: Mapping[str, Collection[str]] | None = None) -> dict[str, str]:
    """Every locale file and Locales.xml by path, for a layer that is present (empty otherwise). A file of an addon
    whose Locale has no header is not written; the problem was reported on the way in. lore is the codes that have a
    Lore.<code>.lua, by addon folder, which Locales.xml lists after the interface file of the same code."""
    if not layer.present:
        return {}
    outputs: dict[str, str] = {}
    for addon, file_id in ADDON_IDS.items():
        languages: list[str] = []
        for code, files in sorted(layer.files.items()):
            header = layer.headers.get(code)
            if header is None or file_id not in files:
                continue
            if code == ENGLISH:
                outputs[locale_lua(addon, code)] = english_lua(addon, files[file_id])
            else:
                outputs[locale_lua(addon, code)] = translation_lua(addon, header, files[file_id])
                languages.append(code)
        outputs[locales_xml(addon)] = locales_xml_text(_load_order(layer, languages), (lore or {}).get(addon, ()))
    return outputs


def retired_locale(root: Path, outputs: Collection[str], layer: LocaleLayer) -> dict[str, str]:
    """Each generated locale file present that outputs does not give, by path, with the directory it came from: its
    Locale's TOML is gone, so the file is stale (DATA-R60) and the generator removes it. enUS.lua is hand-written
    until data/locale/enUS/ exists, and is never retired."""
    retired: dict[str, str] = {}
    for addon in ADDON_IDS:
        for path in sorted((root / "addons" / addon / "locale").glob("[a-z][a-z][A-Z][A-Z].lua")):
            code = path.stem
            relative = locale_lua(addon, code)
            if relative in outputs:
                continue
            if code == ENGLISH and not layer.present:
                continue
            retired[relative] = f"{LOCALE_DIR}/{code}/"
    return retired
