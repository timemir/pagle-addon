"""The translators' credit (DATA-R114, docs/translations.md › Credits): the TRANSLATORS block printed from the Locales'
headers, the check that fails a release entry without it, and the names carried into the generated locale file. From
1.2.4 the block credits only the languages whose translations changed since the previous release tag."""

import subprocess
from pathlib import Path

import pytest

from cli_fixture import run
from locale_fixture import SPANISH_HEADER, RUSSIAN_CORE, RUSSIAN_HEADER, checked, english, spanish
from pagle_data.credits import block_lines, changed_locales, check_changelog, previous_tag, translators_block
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


def check(
    root: Path, text: str | None, version: str = "1.1.0", changed: set[str] | None = None, **languages: str
) -> list[str]:
    if text is not None:
        (root / "CHANGELOG.md").write_text(text, encoding="utf-8")
    problems = Problems()
    check_changelog(root, headers(root, **languages), version, problems, changed)
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


# --- only the languages whose translations changed since the previous release (the dev, 7 Nov 2026) ----------------------


def test_the_block_can_be_narrowed_to_the_changed_languages(tmp_path: Path) -> None:
    found = headers(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    assert block_lines(found, {"esES"}) == ["- Español: Ana, Luis"]
    assert translators_block(found, {"enUS", "ruRU"}) == ""  # English is never credited; ruRU is not here
    assert translators_block(found, None) == "### TRANSLATORS\n\n- Deutsch: Max\n- Español: Ana, Luis\n"


def test_an_entry_crediting_just_the_changed_languages_passes(tmp_path: Path) -> None:
    text = ENTRY.replace("- Deutsch: Max\n", "")
    assert check(tmp_path, text, changed={"esES"}, esES=LISTED, deDE=GERMAN_HEADER) == []


def test_a_changed_language_missing_from_the_block_fails(tmp_path: Path) -> None:
    text = ENTRY.replace("- Español: Ana, Luis\n", "")
    found = check(tmp_path, text, changed={"esES", "deDE"}, esES=LISTED, deDE=GERMAN_HEADER)
    assert len(found) == 1 and "lacks '- Español: Ana, Luis'" in found[0]
    found = check(tmp_path, ENTRY.replace("### TRANSLATORS", "### Credits"), changed={"deDE"}, deDE=GERMAN_HEADER)
    assert len(found) == 1 and "lacks a '### TRANSLATORS' block" in found[0]


def test_an_entry_crediting_a_language_whose_translations_did_not_change_fails(tmp_path: Path) -> None:
    found = check(tmp_path, ENTRY, changed={"esES"}, esES=LISTED, deDE=GERMAN_HEADER)
    assert len(found) == 1 and "credits '- Deutsch: Max'" in found[0] and "Deutsch's translations did not change" in found[0]


def test_an_entry_with_a_block_when_no_translations_changed_fails(tmp_path: Path) -> None:
    found = check(tmp_path, ENTRY, changed=set(), esES=LISTED, deDE=GERMAN_HEADER)
    assert len(found) == 3
    assert "no listed language's translations changed" in found[0]
    assert any("credits '- Deutsch: Max'" in problem for problem in found)
    assert any("credits '- Español: Ana, Luis'" in problem for problem in found)


def test_an_entry_without_a_block_when_no_translations_changed_passes(tmp_path: Path) -> None:
    text = ENTRY.replace("### TRANSLATORS\n\n- Deutsch: Max\n- Español: Ana, Luis\n\n", "")
    assert check(tmp_path, text, changed=set(), esES=LISTED, deDE=GERMAN_HEADER) == []
    assert check(tmp_path / "none", None, changed=set(), esES=LISTED) == []  # no CHANGELOG.md: nothing to judge


def test_a_changed_language_that_is_unlisted_or_has_no_translators_needs_no_line(tmp_path: Path) -> None:
    text = ENTRY.replace("### TRANSLATORS\n\n- Deutsch: Max\n- Español: Ana, Luis\n\n", "")
    assert check(tmp_path, text, changed={"esES", "frFR"}, esES=SPANISH_HEADER, frFR=UNCREDITED) == []


def git(root: Path, *args: str) -> str:
    identity = ["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false"]
    done = subprocess.run(["git", "-C", str(root), *identity, *args], check=True, capture_output=True, text=True)
    return done.stdout


def released(root: Path, *tags: str) -> None:
    """Commits the tree and tags the commit with each tag."""
    if not (root / ".git").exists():
        git(root, "init", "-q", "-b", "main")
    git(root, "add", "-A")
    git(root, "commit", "-q", "--allow-empty", "-m", "release")
    for tag in tags:
        git(root, "tag", tag)


def test_the_previous_tag_is_the_greatest_release_tag_below_the_version_in_number_order(tmp_path: Path) -> None:
    (tmp_path / "a").write_text("a", encoding="utf-8")
    released(tmp_path, "1.9.0", "1.10.0", "1.2.3", "v2.0.0", "nightly", "1.10.1-beta")
    assert previous_tag(tmp_path, "1.10.1") == "1.10.0"  # not 1.9.0, which sorts after it as text
    assert previous_tag(tmp_path, "1.10.0") == "1.9.0"  # its own tag, already made, is not the previous one
    assert previous_tag(tmp_path, "3.0.0") == "1.10.0"  # v2.0.0, nightly and a pre-release are not release tags
    assert previous_tag(tmp_path, "1.2.3") is None
    assert previous_tag(tmp_path, "not-a-version") is None


def test_no_checkout_has_no_previous_tag(tmp_path: Path) -> None:
    assert previous_tag(tmp_path, "1.2.4") is None


def test_the_changed_locales_are_those_with_a_changed_interface_or_lore_file(tmp_path: Path) -> None:
    for path in ("data/locale/esES/core.toml", "data/locale/deDE/core.toml", "data/lore/ruRU/core.toml", "data/lore/core.toml"):
        (tmp_path / path).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / path).write_text("x = 1\n", encoding="utf-8")
    (tmp_path / "data/locale/enUS").mkdir(parents=True)
    (tmp_path / "data/locale/enUS/core.toml").write_text("x = 1\n", encoding="utf-8")
    released(tmp_path, "1.0.0")
    assert changed_locales(tmp_path, "1.0.0") == set()
    (tmp_path / "data/lore/ruRU/core.toml").write_text("x = 2\n", encoding="utf-8")  # Lore counts, uncommitted too
    (tmp_path / "data/lore/core.toml").write_text("x = 2\n", encoding="utf-8")  # English Lore is no Locale's
    (tmp_path / "data/locale/enUS/core.toml").write_text("x = 2\n", encoding="utf-8")
    (tmp_path / "data/locale/frFR").mkdir()
    (tmp_path / "data/locale/frFR/locale.toml").write_text("x = 1\n", encoding="utf-8")  # new and untracked
    assert changed_locales(tmp_path, "1.0.0") == {"enUS", "frFR", "ruRU"}
    released(tmp_path, "1.0.1")
    (tmp_path / "data/locale/esES/core.toml").unlink()  # a removed file is a change
    assert changed_locales(tmp_path, "1.0.1") == {"esES"}
    with pytest.raises(LookupError):
        changed_locales(tmp_path, "9.9.9")


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


def test_check_changelog_judges_against_the_previous_release_tag(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = tree(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    (root / "CHANGELOG.md").write_text(ENTRY, encoding="utf-8")
    released(root, "1.0.0")
    code, out = run(root, capsys, "--check-changelog", "1.1.0")  # nothing changed since 1.0.0: no block wanted
    assert code == 1 and "since 1.0.0" in out and "credits '- Deutsch: Max'" in out
    text = ENTRY.replace("### TRANSLATORS\n\n- Deutsch: Max\n- Español: Ana, Luis\n\n", "")
    (root / "CHANGELOG.md").write_text(text, encoding="utf-8")
    code, out = run(root, capsys, "--check-changelog", "1.1.0")
    assert code == 0 and "1.0.0" in out
    header = root / "data/locale/esES/locale.toml"
    header.write_text(header.read_text(encoding="utf-8") + "# a comment\n", encoding="utf-8")  # any file counts
    code, out = run(root, capsys, "--check-changelog", "1.1.0")
    assert code == 1 and "lacks a '### TRANSLATORS' block" in out
    (root / "CHANGELOG.md").write_text(ENTRY.replace("- Deutsch: Max\n", ""), encoding="utf-8")
    code, out = run(root, capsys, "--check-changelog", "1.1.0")
    assert code == 0 and "since 1.0.0" in out
    code, out = run(root, capsys, "--check-changelog", "1.0.0")  # no tag before 1.0.0: every language, as before 1.2.4
    assert code == 1 and "no release tag before 1.0.0" in out and "lacks a '### TRANSLATORS' block" in out


def test_check_changelog_since_names_the_tag_and_an_unknown_one_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = tree(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    (root / "CHANGELOG.md").write_text(ENTRY.replace("- Deutsch: Max\n", ""), encoding="utf-8")
    released(root, "0.9.0")
    (root / "data/lore/esES").mkdir(parents=True, exist_ok=True)
    (root / "data/lore/esES/core.toml").write_text("", encoding="utf-8")
    released(root, "1.0.0")
    code, out = run(root, capsys, "--check-changelog", "1.1.0")
    assert code == 1 and "credits '- Español: Ana, Luis'" in out
    code, out = run(root, capsys, "--check-changelog", "1.1.0", "--since", "0.9.0")
    assert code == 0 and "since 0.9.0" in out
    code, out = run(root, capsys, "--check-changelog", "1.1.0", "--since", "no-such-tag")
    assert code == 1 and "no-such-tag" in out


def test_translators_since_prints_only_the_changed_languages(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path, esES=LISTED, deDE=GERMAN_HEADER)
    released(root, "1.0.0")
    code, out = run(root, capsys, "--translators", "--since", "1.0.0")
    assert code == 0 and "### TRANSLATORS" not in out and "no listed language's translations changed since 1.0.0" in out
    header = root / "data/locale/deDE/locale.toml"
    header.write_text(header.read_text(encoding="utf-8").replace('["Max"]', '["Max", "Eva"]'), encoding="utf-8")
    code, out = run(root, capsys, "--translators", "--since", "1.0.0")
    assert code == 0 and out.strip().splitlines() == ["### TRANSLATORS", "", "- Deutsch: Max, Eva"]
    code, out = run(root, capsys, "--translators")  # without --since, every credited language, as before
    assert out.strip().splitlines() == ["### TRANSLATORS", "", "- Deutsch: Max, Eva", "- Español: Ana, Luis"]
    code, out = run(root, capsys, "--translators", "--since", "no-such-tag")
    assert code == 1 and "no-such-tag" in out


def test_since_goes_with_translators_or_check_changelog(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit):
        run(tree(tmp_path, esES=LISTED), capsys, "--since", "1.0.0")
