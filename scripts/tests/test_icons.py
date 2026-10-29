"""Every game icon Pagle names is on the pinned, checked list (data/icons.txt), and every name on the list is still used.

A texture path that is not in the client draws nothing: the Pirate Parrot's sound set showed an empty ring in the Collection
because `INV_Misc_Bird_01` is not a file in the game. The list holds only the names Pagle uses, each checked once against the
community listfile (https://github.com/wowdev/wow-listfile, the `interface/icons/<name>.blp` rows). The gate never touches the
network, so this test only compares the code against that list.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ICON_LIST = ROOT / "data" / "icons.txt"
SOURCES = ("addons", "data")
SUFFIXES = {".lua", ".toml", ".json"}

# How the code names an icon: after `Interface\\Icons\\` (a whole path or the `ICONS` prefix), as the argument of a local
# `icon("<Name>")` helper or of `ICONS .. "<Name>"`, or as any quoted name that starts like a game icon.
ICON_PREFIXES = "INV|Ability|Spell|Trade|Achievement|Racial|Temp|Classic|Creature|Pet|Mount|Garrison"
PATTERNS = [
    re.compile(r"Icons\\\\([A-Za-z0-9_]+)"),
    re.compile(r"\bicon\(\s*\"([A-Za-z0-9_]+)\""),
    re.compile(r"\bICONS\s*\.\.\s*\"([A-Za-z0-9_]+)\""),
    re.compile(r"\"((?:" + ICON_PREFIXES + r")_[A-Za-z0-9_]+)\""),
]


def used_icons() -> dict[str, set[str]]:
    """Each icon name the code names, lowercased, with the files that name it."""
    found: dict[str, set[str]] = {}
    for top in SOURCES:
        for path in sorted((ROOT / top).rglob("*")):
            if path.suffix not in SUFFIXES or not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            for pattern in PATTERNS:
                for match in pattern.finditer(text):
                    found.setdefault(match.group(1).lower(), set()).add(str(path.relative_to(ROOT)))
    return found


def listed_icons() -> list[str]:
    lines = (line.strip() for line in ICON_LIST.read_text(encoding="utf-8").splitlines())
    return [line for line in lines if line and not line.startswith("#")]


def test_every_icon_the_code_names_is_on_the_checked_list() -> None:
    """Adding an icon means adding it to data/icons.txt on purpose, after checking that `interface/icons/<name>.blp` is in the
    current community listfile (and, as far as the old `INV_*`, `Ability_*` and `Spell_*` names go, in the Forever client).
    A name the listfile lacks draws an empty ring in game."""
    listed = {name.lower() for name in listed_icons()}
    missing = {name: sorted(files) for name, files in used_icons().items() if name not in listed}
    assert not missing, f"icons not on data/icons.txt (check each against the listfile, then add it): {missing}"


def test_the_checked_list_holds_only_icons_the_code_names() -> None:
    """Drop a name from data/icons.txt when the last use of it goes, so the list stays the set Pagle uses."""
    used = used_icons()
    stale = [name for name in listed_icons() if name.lower() not in used]
    assert not stale, f"icons on data/icons.txt that no file names: {stale}"


def test_the_checked_list_is_sorted_and_free_of_repeats() -> None:
    names = listed_icons()
    assert names == sorted(names, key=str.lower), "keep data/icons.txt sorted, ignoring case"
    assert len({name.lower() for name in names}) == len(names), "a name is listed twice"
