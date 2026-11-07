"""The translators' credit in a release's CHANGELOG entry (DATA-R114, docs/translations.md › Credits).

A release entry has a `### TRANSLATORS` block only when the release changes a listed language's translations: any file
under that language's data/locale/<code>/ or data/lore/<code>/ that differs from the previous release tag. The block
has one line per such language with translators, `- <name>: <names>`, by the language's own name and in the order of
its client code. `--translators` prints the block from the TOML headers for the release author to paste (`--since
<tag>` only the changed languages), and `--check-changelog <version>` fails an entry that lacks a changed language's
line or credits one whose translations did not change. Without a previous release tag every listed language with
translators is credited, as before 1.2.4. The Settings root's Translations line (SET-R10 row 13) credits everyone at
run time, from what the generator wrote into the locale files."""

import re
from collections.abc import Collection, Mapping
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.glyphs import ENGLISH
from pagle_data.locale import LOCALE_DIR, Header, _git
from pagle_data.lore import LORE

CHANGELOG = "CHANGELOG.md"
HEADING = "### TRANSLATORS"


def credited(headers: Mapping[str, Header]) -> list[Header]:
    """The listed Locales that have translators, by client code. English is built in and never credited here, and a
    Locale that is not listed has not shipped."""
    return [headers[code] for code in sorted(headers) if code != ENGLISH and headers[code].listed and headers[code].translators]


def _line(header: Header) -> str:
    return f"- {header.name}: {', '.join(header.translators)}"


def block_lines(headers: Mapping[str, Header], changed: Collection[str] | None = None) -> list[str]:
    """The block's lines, one for each credited Locale, or only for those among `changed` (client codes) when given."""
    return [_line(header) for header in credited(headers) if changed is None or header.code in changed]


def translators_block(headers: Mapping[str, Header], changed: Collection[str] | None = None) -> str:
    """The block to paste into a release entry, or "" when no listed Locale (among `changed`, when given) has
    translators."""
    lines = block_lines(headers, changed)
    return f"{HEADING}\n\n" + "\n".join(lines) + "\n" if lines else ""


# --- what changed since the previous release -------------------------------------------------------------------------

_RELEASE_TAG = re.compile(r"(\d+)\.(\d+)\.(\d+)")


def _release(name: str) -> tuple[int, int, int] | None:
    match = _RELEASE_TAG.fullmatch(name)
    return (int(match[1]), int(match[2]), int(match[3])) if match else None


def previous_tag(root: Path, version: str) -> str | None:
    """The release tag before `version`: the greatest `<major>.<minor>.<patch>` tag below it, in number order. None
    when there is none, when `version` is not such a version, or when root is not a git checkout. Other tags (a `v`
    prefix, a pre-release) are not releases."""
    wanted = _release(version)
    if wanted is None:
        return None
    try:
        names = _git(root, "tag", "--list").splitlines()
    except LookupError:
        return None
    releases = [(number, name) for name in names if (number := _release(name)) is not None and number < wanted]
    return max(releases)[1] if releases else None


def changed_locales(root: Path, since: str) -> set[str]:
    """The client codes whose interface or Lore translations (any file under data/locale/<code>/ or
    data/lore/<code>/) differ between `since` and the working tree, new untracked files included. English is among
    them when its files changed; it is never credited. Raises LookupError where git cannot say."""
    _git(root, "rev-parse", "--verify", "--quiet", f"{since}^{{commit}}")
    paths = [
        *_git(root, "diff", "--name-only", "--no-renames", since, "--", LOCALE_DIR, LORE).splitlines(),
        *_git(root, "ls-files", "--others", "--exclude-standard", "--", LOCALE_DIR, LORE).splitlines(),
    ]
    roots = {tuple(LOCALE_DIR.split("/")), tuple(LORE.split("/"))}
    return {parts[2] for path in paths if len(parts := path.split("/")) > 3 and tuple(parts[:2]) in roots}


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


def check_changelog(
    root: Path,
    headers: Mapping[str, Header],
    version: str,
    problems: Problems,
    changed: Collection[str] | None = None,
    since: str | None = None,
) -> None:
    """Adds a problem for a release entry that lacks the block, or a line of it, for a listed Locale with translators
    whose translations changed (`changed`, client codes, since the release tag `since`), and for one that credits such
    a Locale whose translations did not change, or has the block when none changed. With `changed` None (no previous
    release tag) every listed Locale with translators is wanted and an extra line is not judged. An entry that wants no
    line needs no block. Past entries are never checked: the version names the one entry."""
    wanted = block_lines(headers, changed)
    unchanged = [] if changed is None else [header for header in credited(headers) if header.code not in changed]
    printed = "--translators" if since is None else f"--translators --since {since}"
    at = At(CHANGELOG)
    path = root / CHANGELOG
    if not path.is_file():
        if wanted:
            problems.add(at, "translators: no CHANGELOG.md to hold the TRANSLATORS block (DATA-R114)")
        return
    entry = _entry(path.read_text(encoding="utf-8"), version)
    if entry is None:
        if wanted:
            problems.add(at, f"translators: no entry '## {version}' (DATA-R114)")
        return
    if HEADING not in entry:
        if wanted:
            problems.add(at / version, f"translators: the entry lacks a '{HEADING}' block; {printed} prints it (DATA-R114)")
        return
    block: list[str] = []
    for line in entry[entry.index(HEADING) + 1 :]:
        if line.startswith("#"):
            break
        block.append(line)
    if changed is not None and not wanted:
        problems.add(
            at / version,
            f"translators: the entry has a {HEADING} block, but no listed language's translations changed since"
            f" {since or 'the previous release'}; remove it (DATA-R114)",
        )
    for line in wanted:
        if line not in block:
            problems.add(at / version, f"translators: the {HEADING} block lacks '{line}'; {printed} prints it (DATA-R114)")
    for header in unchanged:
        for line in block:
            if line.startswith(f"- {header.name}:"):
                problems.add(
                    at / version,
                    f"translators: the {HEADING} block credits '{line}', but {header.name}'s translations did not"
                    f" change since {since or 'the previous release'}; remove the line (DATA-R114)",
                )
