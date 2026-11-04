"""The translators' credit in a release's CHANGELOG entry (DATA-R114, docs/translations.md › Credits).

Each release entry that ships a listed language has a `### TRANSLATORS` block: one line per language, `- <name>: <names>`,
by the language's own name and in the order of its client code. `--translators` prints the block from the TOML headers
for the release author to paste, and `--check-changelog <version>` fails an entry that lacks it. The Settings root's
Translations line (SET-R10 row 13) credits the same people at run time, from what the generator wrote into the locale
files."""

import re
from collections.abc import Mapping
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.glyphs import ENGLISH
from pagle_data.locale import Header

CHANGELOG = "CHANGELOG.md"
HEADING = "### TRANSLATORS"


def credited(headers: Mapping[str, Header]) -> list[Header]:
    """The listed Locales that have translators, by client code. English is built in and never credited here, and a
    Locale that is not listed has not shipped."""
    return [headers[code] for code in sorted(headers) if code != ENGLISH and headers[code].listed and headers[code].translators]


def block_lines(headers: Mapping[str, Header]) -> list[str]:
    """The block's lines, one for each credited Locale."""
    return [f"- {header.name}: {', '.join(header.translators)}" for header in credited(headers)]


def translators_block(headers: Mapping[str, Header]) -> str:
    """The block to paste into a release entry, or "" when no listed Locale has translators."""
    lines = block_lines(headers)
    return f"{HEADING}\n\n" + "\n".join(lines) + "\n" if lines else ""


def _entry(text: str, version: str) -> list[str] | None:
    """The lines of the entry headed `## <version>` (a date may follow), up to the next entry; None without it."""
    lines = text.splitlines()
    heading = re.compile(rf"##\s+{re.escape(version)}(\s.*)?$")
    for start, line in enumerate(lines):
        if heading.fullmatch(line.rstrip()):
            entry = []
            for following in lines[start + 1 :]:
                if following.startswith("## "):
                    break
                entry.append(following.rstrip())
            return entry
    return None


def check_changelog(root: Path, headers: Mapping[str, Header], version: str, problems: Problems) -> None:
    """Adds a problem for a release entry that ships a listed Locale with translators and lacks the block, or lacks a
    Locale's line in it. An entry that ships none needs no block, and one it has is not judged. Past entries are never
    checked: the version names the one entry."""
    wanted = block_lines(headers)
    at = At(CHANGELOG)
    path = root / CHANGELOG
    if not wanted:
        return
    if not path.is_file():
        problems.add(at, "translators: no CHANGELOG.md to hold the TRANSLATORS block (DATA-R114)")
        return
    entry = _entry(path.read_text(encoding="utf-8"), version)
    if entry is None:
        problems.add(at, f"translators: no entry '## {version}' (DATA-R114)")
        return
    if HEADING not in entry:
        problems.add(at / version, f"translators: the entry lacks a '{HEADING}' block; --translators prints it (DATA-R114)")
        return
    block: list[str] = []
    for line in entry[entry.index(HEADING) + 1 :]:
        if line.startswith("#"):
            break
        block.append(line)
    for line in wanted:
        if line not in block:
            problems.add(at / version, f"translators: the {HEADING} block lacks '{line}'; --translators prints it (DATA-R114)")
