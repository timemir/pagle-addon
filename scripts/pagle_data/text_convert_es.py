"""The esES mode of the text converter (#519): PR #510's Spanish files, converted to the 1.1 shape (DATA-R114).

#510 holds `addons/*/locale/esES.lua` (`L.KEY = "…"` with the English it was translated from in a `-- EN:` comment) and
`data/lore/es/*.toml`. This reads them from a git ref without touching the branch, and writes `data/locale/esES/` and
`data/lore/esES/`:

* a translation's `%s` and `%d` become the named `{fields}` of the English key, one to one by position (the plan the
  English conversion made, so the two cannot disagree);
* a `KEY_ONE`/`KEY_OTHER` pair becomes one counted string, and Spanish needs a `many` form too: it is a copy of `other`,
  and every key that has one is listed for the translator;
* the `en` field is the converted English now, but only where the old `-- EN:` comment equalled the old English text.
  Where it did not, the translation was already stale: the old snapshot stays and the key is listed;
* Lore only moves from `es` to `esES` (DATA-R104 gives a Lore translation no `en` field; its `# EN:` comments stay).

The TOC edits, the generator and the spec changes #510 carries are not read: #528 lands the result.
"""

import json
import re
import subprocess
import tempfile
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.locale import ADDON_IDS, locale_file
from pagle_data.locale_convert import LUA_DUMP, entry_lines, toml_string
from pagle_data.lua_scan import ScanError, Tok, match_close, tokenize
from pagle_data.text_convert import (
    Json,
    KeyPlan,
    Plan,
    build_plan,
    convert_text,
    directives,
    leaves,
    map_leaves,
    merged_view,
    parse_strings,
)

CODE = "esES"
HEADER = 'name = "Español"\nplural = "one_many_other"\ndecimal = ","\nthousands = "."\nlisted = false\n'
_ASSIGN = re.compile(r"^L\.([A-Za-z_][A-Za-z0-9_]*) = (.*)$")
_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}


class EsError(Exception):
    """The Spanish files cannot be read at all."""


@dataclass
class EsEntry:
    """One `L.KEY = …` of a Spanish locale file with the English it was translated from."""

    key: str
    value: Json
    en: Json | None  # None when the entry has no `-- EN:` comment


@dataclass
class EsReport:
    files: dict[str, str] = field(default_factory=dict)  # path under the output root -> text
    refreshed: list[str] = field(default_factory=list)
    stale: list[str] = field(default_factory=list)
    many: list[str] = field(default_factory=list)
    worklist: list[str] = field(default_factory=list)

    def lines(self) -> list[str]:
        out = [f"esES: {len(self.files)} file(s); {len(self.refreshed)} snapshot(s) refreshed"]
        for title, items in (
            ("kept-stale snapshots", self.stale),
            ("`many` forms to fill (a copy of `other`)", self.many),
            ("worklist", self.worklist),
        ):
            out.append(f"{title}: {len(items)}")
            out += [f"  {item}" for item in items]
        return out


# --- reading the Lua -------------------------------------------------------------------------------------------------


def _decode(token: str) -> str:
    """The text of a quoted Lua string token."""
    body, out, i = token[1:-1], [], 0
    while i < len(body):
        if body[i] == "\\" and i + 1 < len(body):
            nxt = body[i + 1]
            if nxt.isdigit():
                digits = re.match(r"\d{1,3}", body[i + 1 :])
                assert digits is not None
                out.append(chr(int(digits.group(0))))
                i += 1 + len(digits.group(0))
                continue
            out.append(_ESCAPES.get(nxt, nxt))
            i += 2
        else:
            out.append(body[i])
            i += 1
    return "".join(out)


def parse_value(toks: list[Tok], at: int = 0) -> tuple[Json, int]:
    """A Lua string (joined with `..`) or table constructor of strings, from token `at`; with the next index. It reads
    the `-- EN:` comments, which are quoted English; the translations themselves are built by running the file."""
    if toks[at].kind == "str":
        parts = [_decode(toks[at].text)]
        at += 1
        while at + 1 < len(toks) and toks[at].is_op("..") and toks[at + 1].kind == "str":
            parts.append(_decode(toks[at + 1].text))
            at += 2
        return "".join(parts), at
    if not toks[at].is_op("{"):
        raise EsError(f"not a string or a table: {toks[at].text!r}")
    close = match_close(toks, at)
    at += 1
    items: list[tuple[str | int | None, Json]] = []
    while at < close:
        key: str | int | None = None
        if toks[at].is_op("[") and toks[at + 2].is_op("]"):
            key = int(toks[at + 1].text) if toks[at + 1].kind == "num" else _decode(toks[at + 1].text)
            at += 4
        elif toks[at].kind == "name" and toks[at + 1].is_op("="):
            key = toks[at].text
            at += 2
        value, at = parse_value(toks, at)
        items.append((key, value))
        if toks[at].is_op(",", ";"):
            at += 1
    if all(key is None for key, _ in items):
        return [value for _, value in items], close + 1
    out: dict[str, Json] = {}
    for position, (key, value) in enumerate(items, 1):
        out[str(position if key is None else key)] = value
    return out, close + 1


def evaluate_es(lua: Path, source: str) -> dict[str, Json]:
    """The `ns.L` a Spanish locale file builds when it runs on a bare `ns`, read back through JSON. The file's locals
    and helper calls (`sprite(…)`, concatenations) are code, so only running it gives the strings."""
    dump = LUA_DUMP.replace("local ns = {}", "local ns = { L = {} }").replace(
        "Pagle = {}", 'Pagle = {}\nGetLocale = function() return "esES" end'
    )
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "esES.lua"
        path.write_text(source, encoding="utf-8")
        done = subprocess.run([str(lua), "-", str(path)], input=dump.encode(), capture_output=True, check=False)
    if done.returncode != 0:
        raise EsError(f"esES.lua: Lua could not build ns.L: {done.stderr.decode('utf-8', 'replace').strip()}")
    loaded = json.loads(done.stdout.decode("utf-8", "replace"))
    if not isinstance(loaded, dict):
        raise EsError("esES.lua: ns.L is not a table of keys")
    return loaded


def parse_es_lua(source: str, values: dict[str, Json]) -> list[EsEntry]:
    """The `L.KEY = …` assignments of a Spanish locale file, in order, with the value each built (`values`, from
    evaluate_es) and the `-- EN:` comment that follows it."""
    lines = source.split("\n")
    entries: dict[str, EsEntry] = {}
    i = 0
    while i < len(lines):
        match = _ASSIGN.match(lines[i])
        i += 1
        if match is None:
            continue
        while i < len(lines) and not lines[i].startswith(("-- EN:", "L.")) and lines[i].strip():
            i += 1
        en: Json | None = None
        if i < len(lines) and lines[i].startswith("-- EN:"):
            text = lines[i][len("-- EN:") :].removeprefix(" ")
            i += 1
            en = _english_comment(text)
        key = match.group(1)
        if key not in values:
            raise EsError(f"L.{key}: the file builds no such string")
        entries[key] = EsEntry(key, values[key], en)
    return list(entries.values())


def _english_comment(text: str) -> Json:
    """The English a comment holds: a table when it reads as one, else the text as it is."""
    if text.startswith("{"):
        try:
            return parse_value(tokenize(text))[0]
        except (ScanError, IndexError, EsError, ValueError):
            return text
    return text


def _unescaped(text: str) -> list[str]:
    """The readings of an `-- EN:` comment's text: as it stands, as the body of a Lua string (the translator wrote the
    comment with the escapes the source file had, `\\\\` for a backslash and `\\"` for a quote), and, when the whole is quoted
    (a text with a space at its ends was written `" and "`), the quoted text."""
    readings = [text]
    quoted = len(text) >= 2 and text.startswith('"') and text.endswith('"')
    readings.append(_decode(text if quoted else f'"{text}"'))
    return readings


def _same(comment: Json | None, english: Json) -> bool:
    """Whether the old `-- EN:` comment is the old English text. The comment is the English as the translator wrote it
    into a Lua comment: a newline may be written `\\n`, and a backslash, a quote or the quotes around a text with a space
    at its ends are escaped as in a Lua string (so `\\\\` in the comment is one backslash of the English)."""
    if comment is None:
        return False
    if isinstance(comment, str) and isinstance(english, str):
        return english in _unescaped(comment) or comment == english.replace("\n", "\\n")
    if isinstance(comment, dict) and isinstance(english, dict):
        return comment.keys() == english.keys() and all(_same(comment[key], english[key]) for key in english)
    return comment == english


# --- converting ------------------------------------------------------------------------------------------------------


def _with_many(value: Json) -> tuple[Json, bool]:
    """Spanish counts `one`, `many` and `other`: every counted table in `value` gets a `many`, a copy of its `other`."""
    if isinstance(value, dict):
        if "other" in value and "many" not in value and set(value) <= {"zero", "one", "two", "few", "other"}:
            return {**{k: v for k, v in value.items() if k != "other"}, "many": value["other"], "other": value["other"]}, True
        changed = False
        out: dict[str, Json] = {}
        for name, item in value.items():
            out[name], flag = _with_many(item)
            changed = changed or flag
        return out, changed
    return value, False


def _by_english_order(english: str, text: str) -> str | None:
    """A translation's directives named after the fields of an already-converted English text, in order of first
    appearance; None when the two do not agree on how many there are."""
    names = list(dict.fromkeys(re.findall(r"\{([A-Za-z0-9_]+)(?::[A-Za-z0-9]+)?\}", english)))
    found = directives(text)
    if len(found) != len(names) or any(spec is None for _, spec in found):
        return None
    out: list[str] = []
    last = 0
    for (match, spec), name in zip(found, names, strict=True):
        assert spec is not None
        out.append(text[last : match.start()].replace("{", "{{").replace("}", "}}"))
        out.append("{" + name + (":0" if spec.kind == "d" else f":{spec.places}" if spec.kind == "f" else "") + "}")
        last = match.end()
    out.append(text[last:].replace("{", "{{").replace("}", "}}"))
    return re.sub(r"%%", "%", "".join(out))


def convert_es(
    root: Path, before: Path, read: Callable[[str], str | None], listing: list[str], lua: Path
) -> EsReport:
    """Converts the Spanish files. `root` is the converted tree (the English now), `before` the tree before the English
    conversion (its plan names the fields), `read(path)` a file of the PR head, `listing` the paths in it."""
    plan = build_plan(before)
    report = EsReport()
    for addon, file_id in ADDON_IDS.items():
        source = read(f"addons/{addon}/locale/esES.lua")
        if source is None:
            continue
        english_now = parse_strings((root / locale_file("enUS", file_id)).read_text(encoding="utf-8")).by_key()
        text = _addon(plan, addon, parse_es_lua(source, evaluate_es(lua, source)), {k: g.value for k, g in english_now.items()}, report)
        report.files[locale_file(CODE, file_id)] = text
    if report.files:
        report.files[f"data/locale/{CODE}/locale.toml"] = HEADER
    for path in listing:
        match = re.fullmatch(r"data/lore/es/([A-Za-z_0-9]+\.toml)", path)
        content = read(path) if match else None
        if match and content is not None:
            report.files[f"data/lore/{CODE}/{match.group(1)}"] = _lore(content, path, report)
    return report


_FIELD = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*) = (.+)$")


def _lore(text: str, path: str, report: EsReport) -> str:
    """A Lore translation in the shape the generator reads: each field a table of `value` and `en`, the English being
    the `# EN:` comment that follows the field. A field with no such comment has no snapshot, so it is left out (its
    English shows) and listed."""
    lines = text.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        match = _FIELD.match(lines[i])
        if match is None:
            out.append(lines[i])
            i += 1
            continue
        block = [lines[i]]
        i += 1
        if block[0].rstrip().endswith("["):
            while block[-1].strip() != "]":
                block.append(lines[i])
                i += 1
        if i < len(lines) and lines[i].startswith("# EN:"):
            snapshot = lines[i][len("# EN:") :].removeprefix(" ")
            i += 1
            out.append(f"{match.group(1)}.value = " + "\n".join([match.group(2), *block[1:]]))
            out.append(f"{match.group(1)}.en = {toml_string(snapshot)}")
        else:
            report.worklist.append(f"{path}: {match.group(1)} has no `# EN:` snapshot, so it is left out")
    return "\n".join(out)


def _addon(plan: Plan, addon: str, entries: list[EsEntry], now: dict[str, Json], report: EsReport) -> str:
    old = merged_view(plan, addon)
    pairs = plan.merges.get(addon, {})
    counted = plan.counted.get(addon, set())
    by_key = {entry.key: entry for entry in entries}
    skip: set[str] = set()
    out = [
        f"# {addon}'s interface text in Spanish (Spain), converted from PR #510 by scripts/convert-text.py (DATA-R114).",
        "# `value` is the translation, `en` the English it was translated from.",
        "",
    ]
    for entry in entries:
        key = entry.key
        if key in skip:
            continue
        where = f"{addon} {key}"
        base = next((b for b, one in pairs.items() if key in (one, b + "_OTHER", b)), None)
        value: Json
        snapshot: Json | None
        if base is not None and key != base and key == pairs[base]:
            other = by_key.get(base + "_OTHER") or by_key.get(base)
            if other is None:
                report.worklist.append(f"{where}: its pair has no {base}_OTHER in the Spanish file")
                continue
            skip.add(other.key)
            key = base
            where = f"{addon} {key}"
            value = {"one": entry.value, "other": other.value}
            snapshot = {"one": entry.en, "other": other.en} if entry.en is not None and other.en is not None else None
            comment_is_old = _same(snapshot, old.get(key, ""))
        elif base is not None:
            continue
        else:
            value, snapshot = entry.value, entry.en
            comment_is_old = _same(snapshot, old.get(key, ""))
        if key not in now:
            report.worklist.append(f"{where}: no such key in English now (orphan)")
            continue
        converted = _convert_value(plan, addon, key, value, now[key], counted, report)
        if converted is None:
            continue
        if comment_is_old:
            en: Json = now[key]
            report.refreshed.append(where)
        else:
            en = snapshot if snapshot is not None else now[key]
            report.stale.append(where)
        if isinstance(now[key], dict) != isinstance(converted, dict):
            report.worklist.append(f"{where}: English now has a different shape (a counted string?): translate it by hand")
            continue
        counted_value, added = _with_many(converted)
        if added:
            report.many.append(where)
        out.append(f"[{key}]")
        out += entry_lines("value", counted_value)
        out += entry_lines("en", en)
        out.append("")
    return "\n".join(out)


_POSITIONAL = re.compile(r"%(\d)\$([sd])")


def _positional(text: str, key_plan: KeyPlan) -> str:
    """`%2$s ×%1$d` written with the key's names: a translator reordered the directives."""

    def field(match: re.Match[str]) -> str:
        position = int(match.group(1)) - 1
        return "{" + key_plan.names[position] + key_plan.specs[position].suffix(key_plan.names[position]) + "}"

    return _POSITIONAL.sub(field, text)


def _fields(text: str, key_plan: KeyPlan) -> str:
    """One translation's directives as fields: by position, or by the number a translator gave them (`%2$s`)."""
    if not _POSITIONAL.search(text):
        return convert_text(text, key_plan)
    out, last = [], 0
    for match in _POSITIONAL.finditer(text):
        out.append(convert_text(text[last : match.start()], KeyPlan(key_plan.key, [], [])))
        out.append(_positional(match.group(0), key_plan))
        last = match.end()
    out.append(convert_text(text[last:], KeyPlan(key_plan.key, [], [])))
    return "".join(out)


def _count_field(value: Json, english: Json) -> Json:
    """A translation that still says `{n}` where the English now says `{count}` (the English moved with ns.Plural)."""
    fields = {name for _, text in leaves(english) for name in re.findall(r"\{([A-Za-z0-9_]+)(?::[A-Za-z0-9]+)?\}", text)}
    if "n" in fields or "count" not in fields:
        return value
    return map_leaves(value, lambda text: re.sub(r"\{n(:[A-Za-z0-9]+)?\}", r"{count\1}", text))


def _convert_value(
    plan: Plan, addon: str, key: str, value: Json, english: Json, counted: set[str], report: EsReport
) -> Json | None:
    """The translation with its directives written as the fields of English's key."""
    key_plan = plan.keys.get((addon, key))
    where = f"{addon} {key}"
    if key_plan is not None:
        if any(len(directives(text)) > len(key_plan.specs) for _, text in leaves(value)):
            report.worklist.append(f"{where}: the translation has more directives than the English key")
            return None
        planned = map_leaves(value, lambda text: _fields(text, key_plan))
        if _field_names(planned) == _field_names(english):
            return planned
        # The English was changed by hand before the script ran, and its fields are not the plan's: follow the English.
        return _by_order(value, english, where, report)
    if key in counted:
        return map_leaves(value, lambda text: text.replace("{n}", "{count}"))
    if not any("%" in text for _, text in leaves(value)):
        return _count_field(value, english)
    return _by_order(value, english, where, report)


def _by_order(value: Json, english: Json, where: str, report: EsReport) -> Json | None:
    """A key converted by hand before the script ran: the translation's directives take the fields of the English text,
    in order of first appearance."""
    english_text = dict(leaves(english))
    result: dict[tuple[str, ...], str] = {}
    for path, text in leaves(value):
        reference = english_text.get(path) or english_text.get((*path[:-1], "other")) or next(iter(english_text.values()), "")
        converted = _by_english_order(reference, text)
        if converted is None:
            report.worklist.append(f"{where}: cannot match the translation's directives to the English fields")
            return None
        result[path] = converted
    return map_by_path(value, result)


def _field_names(value: Json) -> set[str]:
    return {name for _, text in leaves(value) for name in re.findall(r"\{([A-Za-z0-9_]+)(?::[A-Za-z0-9]+)?\}", text)}


def map_by_path(value: Json, texts: dict[tuple[str, ...], str], path: tuple[str, ...] = ()) -> Json:
    if isinstance(value, str):
        return texts[path]
    if isinstance(value, list):
        return [map_by_path(item, texts, (*path, str(i))) for i, item in enumerate(value, 1)]
    return {name: map_by_path(item, texts, (*path, name)) for name, item in value.items()}


# --- reading a git ref -----------------------------------------------------------------------------------------------


def git_reader(repo: Path, ref: str) -> tuple[Callable[[str], str | None], list[str]]:
    """`read(path)` and the listing of the files of `ref`, read without touching any branch."""
    listing = subprocess.run(
        ["git", "-C", str(repo), "ls-tree", "-r", "--name-only", ref], capture_output=True, check=True, text=True
    ).stdout.split("\n")

    def read(path: str) -> str | None:
        if path not in listing:
            return None
        return subprocess.run(
            ["git", "-C", str(repo), "show", f"{ref}:{path}"], capture_output=True, check=True
        ).stdout.decode("utf-8")

    return read, [path for path in listing if path]


def archive(repo: Path, ref: str, target: Path) -> None:
    """The tree of `ref` unpacked into `target` (an empty directory)."""
    packed = subprocess.run(["git", "-C", str(repo), "archive", ref], capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=packed, check=True)



def main(argv: list[str], root: Path) -> int:
    """`convert-text.py es --pr REF --before REF [--out DIR]`: the Spanish files of REF, converted."""
    import argparse
    import sys
    import tempfile

    parser = argparse.ArgumentParser(
        prog="scripts/convert-text.py es",
        description="Convert PR #510's Spanish files (read from a git ref) to data/locale/esES and data/lore/esES.",
    )
    parser.add_argument("--pr", required=True, help="the ref of the Spanish files, e.g. refs/remotes/pr510")
    parser.add_argument("--before", required=True, help="the commit the English was converted from (its plan names the fields)")
    parser.add_argument("--out", type=Path, default=None, help="where to write (default: this tree; nothing is committed)")
    args = parser.parse_args(argv)
    out = args.out or root
    try:
        read, listing = git_reader(root, args.pr)
        lua = root / ".tools" / "bin" / "lua"
        if not lua.exists():
            lua = Path(__file__).resolve().parents[2] / ".tools" / "bin" / "lua"
        with tempfile.TemporaryDirectory() as before:
            archive(root, args.before, Path(before))
            report = convert_es(root, Path(before), read, listing, lua)
    except (EsError, subprocess.CalledProcessError) as error:
        print(f"convert-text es: {error}", file=sys.stderr)
        return 1
    for path, text in report.files.items():
        target = out / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    print("\n".join(report.lines()))
    return 1 if report.worklist else 0
