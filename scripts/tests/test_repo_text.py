"""The shipped interface text is in the text helper's form, and the converter that put it there has nothing left to do
(CORE-R8, DATA-R114, #519). These replace the byte-for-byte comparison with the hand-written enUS.lua, which pinned the
English the conversion deliberately changed."""

import re
from pathlib import Path

from pagle_data.locale import ADDON_IDS, locale_file
from pagle_data.text_convert import convert, lua_files, scan_file

ROOT = Path(__file__).resolve().parents[2]


def test_a_second_run_of_the_converter_changes_nothing() -> None:
    result = convert(ROOT)

    assert sorted(result.files) == []
    assert result.worklist == []


def test_no_percent_directive_and_no_one_other_key_remains_in_the_english() -> None:
    left = []
    for file_id in ADDON_IDS.values():
        path = locale_file("enUS", file_id)
        for number, line in enumerate((ROOT / path).read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith("#"):
                continue
            if re.search(r"%[0-9.]*[sdif]", line) or re.match(r"[A-Za-z_0-9.]*_(ONE|OTHER)(\.| =)", line):
                left.append(f"{path}:{number}: {line[:80]}")

    assert left == []


def test_no_call_of_the_old_helpers_or_a_format_on_an_l_value_remains_in_the_addons() -> None:
    left = []
    for path in lua_files(ROOT):
        rel = path.relative_to(ROOT).as_posix()
        scan = scan_file(rel, "", path.read_text(encoding="utf-8"))
        for site in scan.sites:
            left.append(f"{rel}:{site.line}: {site.kind} {site.template or site.keys}")
        left += [f"{rel}:{line}: {why}" for line, why in scan.loose]

    assert left == []
