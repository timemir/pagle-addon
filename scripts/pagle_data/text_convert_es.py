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

import re
import subprocess
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.locale import ADDON_IDS, locale_file
from pagle_data.locale_convert import entry_lines
from pagle_data.lua_scan import ScanError, Tok, match_close, tokenize
from pagle_data.text_convert import (
    Json,
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
    """A Lua string (joined with `..`) or table constructor of strings, from token `at`; with the next index."""
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


def parse_es_lua(source: str) -> list[EsEntry]:
    """The `L.KEY = value` assignments of a Spanish locale file, in order, each with its `-- EN:` comment."""
    lines = source.split("\n")
    entries: list[EsEntry] = []
    i = 0
    while i < len(lines):
        match = _ASSIGN.match(lines[i])
        if match is None:
            i += 1
            continue
        body = [match.group(2)]
        i += 1
        while i < len(lines) and not lines[i].startswith(("-- EN:", "L.")) and lines[i].strip():
            body.append(lines[i])
            i += 1
        en: Json | None = None
        if i < len(lines) and lines[i].startswith("-- EN:"):
            text = lines[i][len("-- EN:") :].removeprefix(" ")
            i += 1
            while i < len(lines) and lines[i].startswith("--") and not lines[i].startswith("-- EN:"):
                text += "\n" + lines[i][2:].removeprefix(" ")
                i += 1
            en = _english_comment(text)
        try:
            value, _ = parse_value(tokenize("\n".join(body)))
        except (ScanError, IndexError, EsError, ValueError) as error:
            raise EsError(f"L.{match.group(1)}: {error}") from error
        entries.append(EsEntry(match.group(1), value, en))
    return entries


def _english_comment(text: str) -> Json:
    """The English a comment holds: a table when it reads as one, else the text as it is."""
    if text.startswith("{"):
        try:
            return parse_value(tokenize(text))[0]
        except (ScanError, IndexError, EsError, ValueError):
            return text
    return text


def _same(comment: Json | None, english: Json) -> bool:
    """Whether the old `-- EN:` comment is the old English text (a newline may be written `\\n`)."""
    if comment is None:
        return False
    if isinstance(comment, str) and isinstance(english, str):
        return comment == english or comment == english.replace("\n", "\\n")
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
    root: Path, before: Path, read: Callable[[str], str | None], listing: list[str]
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
        text = _addon(plan, addon, parse_es_lua(source), {k: g.value for k, g in english_now.items()}, report)
        report.files[locale_file(CODE, file_id)] = text
    if report.files:
        report.files[f"data/locale/{CODE}/locale.toml"] = HEADER
    for path in listing:
        match = re.fullmatch(r"data/lore/es/([A-Za-z_0-9]+\.toml)", path)
        content = read(path)
        if match and content is not None:
            report.files[f"data/lore/{CODE}/{match.group(1)}"] = content
    return report


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
        counted_value, added = _with_many(converted)
        if added:
            report.many.append(where)
        out.append(f"[{key}]")
        out += entry_lines("value", counted_value)
        out += entry_lines("en", en)
        out.append("")
    return "\n".join(out)


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
        return map_leaves(value, lambda text: convert_text(text, key_plan))
    if key in counted:
        return map_leaves(value, lambda text: text.replace("{n}", "{count}"))
    if not any("%" in text for _, text in leaves(value)):
        return value
    # A key converted by hand before the script ran: its fields are those of the English text, in order.
    english_text = dict(leaves(english))
    result: dict[tuple[str, ...], str] = {}
    for path, text in leaves(value):
        reference = english_text.get(path) or next(iter(english_text.values()), "")
        converted = _by_english_order(reference, text)
        if converted is None:
            report.worklist.append(f"{where}: cannot match the translation's directives to the English fields")
            return None
        result[path] = converted
    return map_by_path(value, result)


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
        with tempfile.TemporaryDirectory() as before:
            archive(root, args.before, Path(before))
            report = convert_es(root, Path(before), read, listing)
    except (EsError, subprocess.CalledProcessError) as error:
        print(f"convert-text es: {error}", file=sys.stderr)
        return 1
    for path, text in report.files.items():
        target = out / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    print("\n".join(report.lines()))
    return 1 if report.worklist else 0
