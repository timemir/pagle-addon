"""The translators' credit (DATA-R114, docs/translations.md › Credits): the TRANSLATORS block printed from the Locales'
headers, the check that fails a release entry without it, and the names carried into the generated locale file."""

from pathlib import Path

import pytest

from cli_fixture import run
from locale_fixture import SPANISH_HEADER, RUSSIAN_CORE, RUSSIAN_HEADER, checked, english, spanish
from pagle_data.credits import block_lines, check_changelog, translators_block
from pagle_data.errors import Problems
from pagle_data.locale import Header, translation_lua
from test_item_records import write_tree as write_items
from test_lore import FAMILIES, ITEMS, OFF

LISTED = SPANISH_HEADER.replace("listed = false", "listed = true")
GERMAN_HEADER = 'name = "Deutsch"\ntranslators = ["Max"]\nlisted = true\nplural = "one_many_other"\ndecimal = ","\nthousands = "."\n'
UNCREDITED = 'name = "Français"\nlisted = true\nplural = "one_other"\ndecimal = ","\nthousands = " "\n'

ENTRY = """\
# Pagle

## 1.1.0 (2026-12-01)

Languages.

### TRANSLATORS

- Deutsch: Max
- Español: Ana, Luis

### Pagle

- Something.

## 1.0.0 (2026-11-05)

The first release.
"""


def headers(root: Path, **languages: str) -> dict[str, Header]:
    trees = {"enUS": english()} | {code: spanish(header=header) for code, header in languages.items()}
    return checked(root, trees)[2].headers


def test_the_block_has_a_line_for_each_listed_language_with_translators_in_the_order_of_the_codes(tmp_path: Path) -> None:
    found = headers(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    assert translators_block(found) == "### TRANSLATORS\n\n- Deutsch: Max\n- Español: Ana, Luis\n"


def test_an_unlisted_language_and_one_without_translators_are_not_credited(tmp_path: Path) -> None:
    found = headers(tmp_path, esES=SPANISH_HEADER, frFR=UNCREDITED, deDE=GERMAN_HEADER)
    assert block_lines(found) == ["- Deutsch: Max"]


def test_no_credited_language_gives_no_block(tmp_path: Path) -> None:
    assert translators_block(headers(tmp_path, esES=SPANISH_HEADER, frFR=UNCREDITED)) == ""
    assert translators_block(headers(tmp_path / "none")) == ""


def check(root: Path, text: str | None, version: str = "1.1.0", **languages: str) -> list[str]:
    if text is not None:
        (root / "CHANGELOG.md").write_text(text, encoding="utf-8")
    problems = Problems()
    check_changelog(root, headers(root, **languages), version, problems)
    return problems.found


def test_an_entry_with_the_block_passes(tmp_path: Path) -> None:
    assert check(tmp_path, ENTRY, esES=LISTED, deDE=GERMAN_HEADER) == []


def test_an_entry_without_the_block_fails(tmp_path: Path) -> None:
    text = ENTRY.replace("### TRANSLATORS\n\n- Deutsch: Max\n- Español: Ana, Luis\n\n", "")
    found = check(tmp_path, text, esES=LISTED, deDE=GERMAN_HEADER)
    assert len(found) == 1 and "CHANGELOG.md" in found[0] and "lacks a '### TRANSLATORS' block" in found[0]


def test_a_block_missing_a_language_or_a_name_fails(tmp_path: Path) -> None:
    found = check(tmp_path, ENTRY.replace("- Deutsch: Max\n", ""), esES=LISTED, deDE=GERMAN_HEADER)
    assert len(found) == 1 and "lacks '- Deutsch: Max'" in found[0]
    found = check(tmp_path, ENTRY.replace("Ana, Luis", "Ana"), esES=LISTED)
    assert len(found) == 1 and "lacks '- Español: Ana, Luis'" in found[0]


def test_a_line_in_another_section_does_not_count(tmp_path: Path) -> None:
    text = ENTRY.replace("- Deutsch: Max\n", "").replace("- Something.", "- Deutsch: Max")
    assert len(check(tmp_path, text, esES=LISTED, deDE=GERMAN_HEADER)) == 1


def test_only_the_named_entry_is_judged_and_past_ones_never(tmp_path: Path) -> None:
    assert check(tmp_path, ENTRY, "1.1.0", esES=LISTED) == []  # the 1.0.0 entry below it has no block and is not asked
    found = check(tmp_path, ENTRY, "1.2.0", esES=LISTED)
    assert len(found) == 1 and "no entry '## 1.2.0'" in found[0]


def test_an_entry_that_ships_no_credited_language_needs_no_block(tmp_path: Path) -> None:
    assert check(tmp_path, ENTRY.replace("### TRANSLATORS", "### Credits"), "1.1.0", esES=SPANISH_HEADER) == []


def test_the_version_is_matched_whole(tmp_path: Path) -> None:
    assert len(check(tmp_path, ENTRY.replace("## 1.1.0", "## 1.1.01"), "1.1.0", esES=LISTED)) == 1


def test_the_names_are_in_the_generated_locale_file_and_in_its_registration(tmp_path: Path) -> None:
    layer = checked(tmp_path, {"enUS": english(), "esES": spanish()})[2]
    text = translation_lua("Pagle", layer.headers["esES"], layer.files["esES"]["core"])
    assert "-- Translators: Ana, Luis.\n" in text
    assert '\tlisted = false,\n\ttranslators = { "Ana", "Luis" },\n' in text
    layer = checked(tmp_path / "none", {"enUS": english(), "ruRU": {"locale.toml": RUSSIAN_HEADER, "core.toml": RUSSIAN_CORE}})[2]
    assert "translators" not in translation_lua("Pagle", layer.headers["ruRU"], layer.files["ruRU"]["core"])


def test_a_translator_name_is_held_to_the_languages_glyph_range(tmp_path: Path) -> None:
    problems, _, _ = checked(tmp_path, {"enUS": english(), "esES": spanish(header=SPANISH_HEADER.replace('"Luis"', '"Лёша"'))})
    assert any("locale.toml: translators[2]" in problem and "glyph: U+041B" in problem for problem in problems)


# --- the command line ---------------------------------------------------------------------------------------------------


def tree(root: Path, **languages: str) -> Path:
    write_items(root, ITEMS, families=FAMILIES, checks=OFF)
    checked(root, {"enUS": english()} | {code: spanish(header=header) for code, header in languages.items()})
    return root


def test_translators_prints_the_block_and_nothing_else(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    code, out = run(root, capsys, "--translators")
    assert code == 0
    assert out.strip().splitlines() == ["### TRANSLATORS", "", "- Deutsch: Max", "- Español: Ana, Luis"]
    assert not list(root.glob("addons/*/locale/*"))  # writes nothing


def test_translators_with_nobody_to_credit_says_so_and_prints_no_block(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code, out = run(tree(tmp_path, esES=SPANISH_HEADER), capsys, "--translators")
    assert code == 0 and "needs no TRANSLATORS block" in out and "### TRANSLATORS" not in out


def test_check_changelog_fails_a_missing_block_and_passes_a_present_one(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    (root / "CHANGELOG.md").write_text("# Pagle\n\n## 1.1.0 (2026-12-01)\n\n### Pagle\n\n- Something.\n", encoding="utf-8")
    code, out = run(root, capsys, "--check-changelog", "1.1.0")
    assert code == 1 and "lacks a '### TRANSLATORS' block" in out
    (root / "CHANGELOG.md").write_text(ENTRY, encoding="utf-8")
    code, out = run(root, capsys, "--check-changelog", "1.1.0")
    assert code == 0 and "credits the translators" in out
