"""Drift (DATA-R114, ADR 0019 "Coverage, `listed` and drift", docs/translations.md › Drift and the stale issue): the
translations whose English has changed, listed, dropped and tracked.

A translated string carries an `en` field, the EN snapshot of the English it was translated from. When the English
changes the snapshot no longer matches it, and the string is **stale**, of one of two kinds:

- **same fields**: the `{field}` set is unchanged, so the old translation still reads right and keeps showing;
- **fields changed**: the `{field}` set differs, so the translation would not fit (the placeholder check fails it). The
  maintainer's PR drops it by `--drop-stale`, the string falls back to English, and CI never waits for a translator.

A translation also counts as fields changed when the English change leaves it failing the line-break or shape check
(`locale.DRIFT_CHECKS`): the gate would fail it just the same, and the drop is what keeps an English change from
blocking on a translator.

Everything here reads only, but `drop_stale`. The listing reads the TOML directly rather than through the generator's
checks: a tree with a fields-changed string fails those checks, and this is what lists and drops it.
"""

import json
from collections import Counter
from collections.abc import Mapping
from dataclasses import dataclass, replace
from pathlib import Path

from pagle_data.errors import Problems
from pagle_data.events import read_events
from pagle_data.files import write_atomic
from pagle_data.glyphs import ENGLISH
from pagle_data.hunts import read_hunts
from pagle_data.locale import (
    FILES,
    Header,
    LocaleLayer,
    Value,
    broken_by_english,
    effective,
    fallback_chain,
    fields_of,
    leaves,
    locale_file,
    read_locale,
)
from pagle_data.lore import ADDONS, LoreLayer, english_texts, placeholders, read_lore, translation_file
from pagle_data.plural import CATEGORIES, RULES
from pagle_data.toml_edit import EditError, KeyPath, drop_entries

SAME_FIELDS = "same_fields"
FIELDS_CHANGED = "fields_changed"
KINDS = (FIELDS_CHANGED, SAME_FIELDS)
INTERFACE = "interface"
LORE = "lore"

# Where a key sits in its TOML file: an interface key is a table of its own, a Lore field is `kind.id.field`.
DEPTH = {INTERFACE: 1, LORE: 3}

# GitHub refuses an issue body over 65536 characters; the body leaves itself room under it.
BODY_LIMIT = 60000
LIST_LIMIT = 300  # the longest list of keys with nothing to say beside them
TITLE = "Translations stale: {code}"


@dataclass(frozen=True)
class Stale:
    """One translated string whose EN snapshot is not today's English."""

    code: str
    layer: str  # INTERFACE or LORE
    file: str  # the Locale's TOML file, relative to the repo root
    key: str  # an interface key (FISH_COUNT), or a Lore field's (species.6362.blurb)
    parts: KeyPath  # the key's path in the file, as DEPTH[layer] components
    kind: str  # SAME_FIELDS or FIELDS_CHANGED
    reason: str | None  # why the fields changed: "fields", "newline" or "shape"; None for same fields
    old: Value  # the EN snapshot
    new: Value  # today's English

    def sort_key(self) -> tuple[str, int, str, str, bytes]:
        return (self.code, KINDS.index(self.kind), self.layer, self.file, self.key.encode("utf-8"))


@dataclass
class Sources:
    """What the drift tooling reads: the interface and Lore layers as written, and the problems reading them found."""

    locale: LocaleLayer
    lore: LoreLayer
    problems: Problems


def read_sources(root: Path) -> Sources:
    """data/locale/ and data/lore/ as written, the Hunt and event text English Lore keeps beside its definitions
    included. Only the shape is read: the checks that a stale string fails are not run (that is what this lists)."""
    problems = Problems()
    lore = read_lore(root, problems)
    hunts = read_hunts(root, problems)
    events = read_events(root, problems)
    lore = replace(lore, hunts=hunts.texts(), events=events.texts())
    return Sources(read_locale(root, problems), lore, problems)


def _fields(value: Value) -> set[str]:
    return {name for _, text in leaves(value) for name in fields_of(text)}


def _interface(locale: LocaleLayer) -> list[Stale]:
    found: list[Stale] = []
    english = locale.files.get(ENGLISH, {})
    for code in sorted(locale.files):
        if code == ENGLISH:
            continue
        rule = RULES.get(effective(code, locale.headers).plural or "")
        categories = frozenset(rule.categories if rule else CATEGORIES)
        for file_id in FILES:
            for key, entry in sorted(locale.files[code].get(file_id, {}).items(), key=lambda pair: pair[0]):
                source = english.get(file_id, {}).get(key)  # no such key is an orphan, which is not drift
                if source is None or entry.en is None or entry.en == source.value:
                    continue
                reason: str | None = None
                if _fields(entry.en) != _fields(source.value):
                    reason = "fields"
                elif rule is not None:
                    broken = broken_by_english(code, categories, source.value, entry.value)
                    reason = None if not broken else "fields" if broken[0] == "placeholder" else broken[0]
                kind = SAME_FIELDS if reason is None else FIELDS_CHANGED
                found.append(
                    Stale(code, INTERFACE, locale_file(code, file_id), key, (key,), kind, reason, entry.en, source.value)
                )
    return found


def _lore(lore: LoreLayer) -> list[Stale]:
    found: list[Stale] = []
    for code in sorted(lore.translations):
        for lore_id in ADDONS:
            translation = lore.translations[code].get(lore_id)
            if translation is None:
                continue
            english = english_texts(lore, lore_id)
            for key, text in sorted(translation.texts.items(), key=lambda pair: pair[0]):
                source = english.get(key)
                snapshot = translation.snapshots[key]
                if source is None or snapshot == source.value:
                    continue
                wanted = placeholders(source.value)
                changed = placeholders(snapshot) != wanted or placeholders(text.value) != wanted
                parts = (text.kind, text.id, text.field)
                found.append(
                    Stale(
                        code,
                        LORE,
                        translation_file(code, lore_id),
                        key,
                        parts,
                        FIELDS_CHANGED if changed else SAME_FIELDS,
                        "fields" if changed else None,
                        snapshot,
                        source.value,
                    )
                )
    return found


def find_stale(sources: Sources) -> list[Stale]:
    """Every stale string of every Locale, interface and Lore, in a fixed order: by Locale, then fields changed before
    same fields, interface before Lore, then by file and key."""
    return sorted([*_interface(sources.locale), *_lore(sources.lore)], key=Stale.sort_key)


def stale_warning(item: Stale) -> str:
    """One line for a stale string, for the specs that warn about it (DATA-R114): never an error."""
    keeps = "keeps showing" if item.kind == SAME_FIELDS else "will be dropped to English by --drop-stale"
    return f"{item.file}: {item.key}: the EN snapshot is not the English text now ({item.code}); {keeps}"


# --- the listing ------------------------------------------------------------------------------------------------------


def _one_line(value: Value, limit: int | None = None) -> str:
    """A value on one line: a text as it is with its line breaks written out, an array or table as JSON."""
    text = value.replace("\r", "\\r").replace("\n", "\\n") if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    return text if limit is None or len(text) <= limit else text[: limit - 1] + "…"


_KIND_NAMES = {SAME_FIELDS: "same fields (keeps showing)", FIELDS_CHANGED: "fields changed (dropped by --drop-stale)"}


def stale_text(stale: list[Stale], headers: Mapping[str, Header]) -> str:
    """The listing `--stale` prints: per Locale, per kind, each key with the English it was translated from and the
    English now."""
    if not stale:
        return "no translation is stale: every EN snapshot is today's English (DATA-R114)\n"
    lines = [f"{len(stale)} stale translation(s) in {len({item.code for item in stale})} Locale(s) (DATA-R114)"]
    for code in sorted({item.code for item in stale}):
        mine = [item for item in stale if item.code == code]
        header = headers.get(code)
        lines += ["", f"{code}{f' ({header.name})' if header else ''}: {len(mine)} stale"]
        for kind in KINDS:
            of_kind = [item for item in mine if item.kind == kind]
            if not of_kind:
                continue
            lines.append(f"  {_KIND_NAMES[kind]}: {len(of_kind)}")
            for item in of_kind:
                note = {"newline": " (its line breaks)", "shape": " (its shape)"}.get(item.reason or "", "")
                lines += [f"    {item.file}: {item.key}{note}", f"      was: {_one_line(item.old)}", f"      now: {_one_line(item.new)}"]
    return "\n".join(lines) + "\n"


def _record(item: Stale) -> dict[str, object]:
    return {
        "layer": item.layer,
        "file": item.file,
        "key": item.key,
        "kind": item.kind,
        "reason": item.reason,
        "old": item.old,
        "new": item.new,
    }


def stale_json(stale: list[Stale], headers: Mapping[str, Header]) -> str:
    """`--stale --json`: every Locale of data/locale/ other than English (a Locale with nothing stale has an empty list),
    with its name and `listed`, and its stale strings in the listing's order."""
    locales = {
        code: {
            "name": headers[code].name,
            "listed": headers[code].listed,
            "stale": [_record(item) for item in stale if item.code == code],
        }
        for code in sorted(headers)
        if code != ENGLISH
    }
    return json.dumps({"locales": locales}, ensure_ascii=False, indent=2) + "\n"


# --- the per-locale issue -----------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Gaps:
    """What a Locale has no text for, so English shows."""

    interface: list[str]  # file id and key: core.NEW_KEY
    interface_total: int
    lore: dict[str, tuple[int, int]]  # lore ID -> (keys without text, English's keys), for the lore files the Locale has


def find_gaps(sources: Sources, code: str) -> Gaps:
    """The interface keys code lacks, counting its fallback chain's text (the coverage rule, DATA-R114), and, for each
    Lore file it has, how many of English's keys it lacks (Lore is optional: it falls back per key)."""
    chain = fallback_chain(code, sources.locale.headers)
    english = sources.locale.files.get(ENGLISH, {})
    missing: list[str] = []
    total = 0
    for file_id in FILES:
        for key in sorted(english.get(file_id, {}), key=lambda name: name.encode("utf-8")):
            total += 1
            if not any(key in sources.locale.files.get(link, {}).get(file_id, {}) for link in chain):
                missing.append(f"{file_id}.{key}")
    lore: dict[str, tuple[int, int]] = {}
    for lore_id, translation in sorted(sources.lore.translations.get(code, {}).items(), key=lambda pair: pair[0]):
        keys = english_texts(sources.lore, lore_id)
        lore[lore_id] = (len(keys.keys() - translation.texts.keys()), len(keys))
    return Gaps(missing, total, lore)


def issue_title(code: str) -> str:
    return TITLE.format(code=code)


def _code(text: str) -> str:
    """text as inline code: a backtick in it needs a longer fence."""
    return f"`` {text} ``" if "`" in text else f"`{text}`"


def _checklist(items: list[str], box: bool = True) -> list[str]:
    shown = items[:LIST_LIMIT]
    lines = [f"- [ ] {item}" if box else f"- {item}" for item in shown]
    if len(items) > len(shown):
        lines.append(f"- … and {len(items) - len(shown)} more; `scripts/generate-data.py --stale-issue` lists them all")
    return lines


def issue_body(code: str, header: Header, stale: list[Stale], gaps: Gaps) -> str:
    """The body of a Locale's "translations stale" issue (ADR 0019): the counts, the stale keys by kind and the missing
    keys, as checklists. Deterministic: the same files give the same body, so an unchanged issue is not edited. A body
    that would not fit a GitHub issue is written again without the English text beside each key."""
    mine = [item for item in stale if item.code == code]
    for detail in (True, False):
        body = _issue_body(code, header, mine, gaps, detail)
        if len(body) <= BODY_LIMIT:
            return body
    return body[:BODY_LIMIT].rsplit("\n", 1)[0] + "\n\n(The list was cut to fit an issue; `--stale-issue` prints all of it.)\n"


def _issue_body(code: str, header: Header, mine: list[Stale], gaps: Gaps, detail: bool) -> str:
    counts = Counter(item.kind for item in mine)
    lore_missing = sum(missing for missing, _ in gaps.lore.values())
    state = "a listed language" if header.listed else "not listed yet"
    intro = (
        f"English has changed since some of {header.name}'s ({_code(code)}, {state}) strings were translated, or has"
        " strings this language has no text for yet. Update a stale string's `value` and its `en` snapshot together,"
        " in the file named beside it. The list is written by"
        f" `scripts/generate-data.py --stale-issue {code}` and rewritten from the files, so a string leaves it when it"
        " is fixed (docs/translations.md, docs/agents/translations-stale.md)."
    )
    lines = [
        f"<!-- translations-stale: {code} -->",
        intro,
        "",
        "| | Strings |",
        "|---|---|",
        f"| Stale, fields changed (English shows until retranslated) | {counts[FIELDS_CHANGED]} |",
        f"| Stale, same fields (the old translation still shows) | {counts[SAME_FIELDS]} |",
        f"| Interface keys with no translation (English shows) | {len(gaps.interface)} of {gaps.interface_total} |",
        f"| Lore keys with no translation, in the Lore files it has (English shows) | {lore_missing} |",
    ]
    if not mine and not gaps.interface and not lore_missing:
        lines += ["", "Nothing is stale or missing now."]
    sections = [
        (FIELDS_CHANGED, "Stale: fields changed", "The `{fields}` of the English text changed (or its line breaks or shape), so the translation no longer fits and cannot stay. The maintainer's `--drop-stale` removes it and English shows until it is translated again."),
        (SAME_FIELDS, "Stale: same fields", "The English wording changed and the `{fields}` did not, so the old translation keeps showing. Check it still says what the English now says."),
    ]
    for kind, title, intro in sections:
        items = [item for item in mine if item.kind == kind]
        if not items:
            continue
        lines += ["", f"## {title} ({len(items)})", "", intro, ""]
        lines += _checklist([_stale_item(item, detail) for item in items])
    if gaps.interface:
        lines += ["", f"## Interface keys with no translation ({len(gaps.interface)})", "", "These show English. Add each to its addon's file.", ""]
        lines += _checklist([_code(key) for key in gaps.interface])
    if lore_missing:
        lines += ["", "## Lore", "", "Lore is optional: a key with no translation shows English. How many keys each Lore file has no translation for:", ""]
        lines += _checklist([f"{_code(f'data/lore/{code}/{lore_id}.toml')}: {missing} of {total}" for lore_id, (missing, total) in gaps.lore.items() if missing], box=False)
    return "\n".join(lines) + "\n"


def _stale_item(item: Stale, detail: bool) -> str:
    where = f"{_code(item.file)} {_code(item.key)}"
    if not detail:
        return where
    return f"{where}: now {_code(_one_line(item.new, 120))}, was {_code(_one_line(item.old, 120))}"


def issue_json(code: str, header: Header, stale: list[Stale], gaps: Gaps) -> str:
    """`--stale-issue CODE --json`: the title and body of the issue, and the counts a caller decides on."""
    mine = [item for item in stale if item.code == code]
    lore_missing = sum(missing for missing, _ in gaps.lore.values())
    record = {
        "code": code,
        "listed": header.listed,
        "title": issue_title(code),
        "body": issue_body(code, header, stale, gaps),
        "fields_changed": sum(1 for item in mine if item.kind == FIELDS_CHANGED),
        "same_fields": sum(1 for item in mine if item.kind == SAME_FIELDS),
        "missing_interface": len(gaps.interface),
        "missing_lore": lore_missing,
    }
    return json.dumps(record, ensure_ascii=False, indent=2) + "\n"


# --- the drop -----------------------------------------------------------------------------------------------------------


def drop_stale(root: Path, stale: list[Stale]) -> list[Stale]:
    """Removes every FIELDS_CHANGED string from the TOML of its Locale, so English shows for it, and returns what it
    removed. All or nothing: every file is edited in memory first, and a file the edit cannot be proved safe on
    (toml_edit.EditError) stops the run before any is written. Comments and everything else stay."""
    doomed = [item for item in stale if item.kind == FIELDS_CHANGED]
    by_file: dict[str, list[Stale]] = {}
    for item in doomed:
        by_file.setdefault(item.file, []).append(item)
    edited: dict[str, bytes] = {}
    for file, items in sorted(by_file.items()):
        text = (root / file).read_bytes().decode("utf-8")
        try:
            edited[file] = drop_entries(text, DEPTH[items[0].layer], [item.parts for item in items]).encode("utf-8")
        except EditError as error:
            raise EditError(f"{file}: {error}") from error
    for file, content in edited.items():
        write_atomic(root / file, content)
    return doomed

