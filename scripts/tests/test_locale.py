"""The interface-text layer (DATA-R114) over fixture data/locale/ trees: the header, and each check failing with the key,
the check name and the Locale, and passing. A fixture Locale (never shipped) exercises Spanish and Russian plural rules.
Coverage is DATA-R114's rule as the dev decided it on 4 Nov: 100% to enter, stays listed."""

from pathlib import Path

import pytest

from locale_fixture import (
    CORE,
    ENGLISH_HEADER,
    RUSSIAN_CORE,
    RUSSIAN_HEADER,
    SPANISH_CORE,
    SPANISH_HEADER,
    checked,
    english,
    spanish,
    with_spanish,
)
from pagle_data.errors import Problems
from pagle_data.locale import judge_coverage, read_locale

ES_CORE = "data/locale/esES/core.toml"


def swap(text: str, old: str, new: str) -> str:
    assert old in text
    return text.replace(old, new)


def only(found: list[str]) -> str:
    assert len(found) == 1, found
    return found[0]


def test_a_whole_translation_passes_with_nothing_to_say(tmp_path: Path) -> None:
    found, warnings, _ = with_spanish(tmp_path)
    assert found == []
    assert warnings == []


def test_an_absent_data_locale_leaves_the_layer_inert(tmp_path: Path) -> None:
    problems = Problems()
    layer = read_locale(tmp_path, problems)
    assert not layer.present
    assert problems.found == []


# --- missing ----------------------------------------------------------------------------------------------------------


def test_missing_fails_on_an_empty_value_naming_the_key_and_the_locale(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value = "Hola, {name}"', 'value = ""'))
    message = only(found)
    assert message.startswith(f"{ES_CORE}: GREETING: missing:")
    assert "esES" in message


def test_missing_looks_into_arrays_and_counted_forms(tmp_path: Path) -> None:
    core = swap(SPANISH_CORE, 'value = ["Pequeño", "Grande"]', 'value = ["Pequeño", " "]')
    core = swap(core, 'value.many = "{count} de peces"', 'value.many = ""')
    found, _, _ = with_spanish(tmp_path, core)
    assert any(f"{ES_CORE}: BANDS[2]: missing:" in message for message in found)
    assert any(f"{ES_CORE}: FISH_COUNT.many: missing:" in message for message in found)


def test_a_key_with_no_entry_at_all_is_a_gap_and_not_a_failure(tmp_path: Path) -> None:
    core = SPANISH_CORE[: SPANISH_CORE.index("[SEAL]")]
    found, _, _ = with_spanish(tmp_path, core)
    assert found == []


# --- orphan -----------------------------------------------------------------------------------------------------------


def test_orphan_fails_on_a_key_english_does_not_have(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, SPANISH_CORE + '\n[EXTRA]\nvalue = "x"\nen = "x"\n')
    message = only(found)
    assert message.startswith(f"{ES_CORE}: EXTRA: orphan:")
    assert "esES" in message and "English has no such key" in message


def test_orphan_names_the_addon_whose_key_it_is(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, SPANISH_CORE + '\n[HUNTS_ONLY]\nvalue = "x"\nen = "x"\n')
    message = only(found)
    assert f"{ES_CORE}: HUNTS_ONLY: orphan:" in message
    assert "hunts.toml" in message


# --- placeholder ------------------------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("old", "new", "detail"),
    [
        ('value = "Hola, {name}"', 'value = "Hola"', "lacks {name}"),
        ('value = "Hola, {name}"', 'value = "Hola, {nombre}"', "adds {nombre}"),
        ('value = "{weight:1} kg, {{literal}}"', 'value = "{weight} kg, {{literal}}"', ""),  # a spec may change
    ],
)
def test_placeholder_compares_the_field_names_and_never_the_spec(tmp_path: Path, old: str, new: str, detail: str) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, old, new))
    if not detail:
        assert found == []
        return
    message = only(found)
    assert ": placeholder:" in message and "esES" in message and detail in message
    assert message.startswith(f"{ES_CORE}: GREETING: placeholder:")


def test_a_doubled_brace_is_not_a_field(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, "{{literal}}\"\nen", "{literal}\"\nen"))
    assert ": WEIGHT: placeholder:" in only(found) and "adds {literal}" in only(found)


def test_a_counted_form_is_compared_with_its_own_english_form_or_other(tmp_path: Path) -> None:
    english_core = CORE.replace('FISH_COUNT.one = "{count} fish"', 'FISH_COUNT.one = "one fish"')
    core = swap(SPANISH_CORE, 'value.one = "{count} pez"', 'value.one = "un pez"')
    core = swap(core, 'en.one = "{count} fish"', 'en.one = "one fish"')
    found, _, _ = checked(tmp_path, {"enUS": english(english_core), "esES": spanish(core)})
    assert found == []  # `one` has no {count} in English, and `many` is read against English's `other`
    found, _, _ = checked(tmp_path / "again", {"enUS": english(english_core), "esES": spanish(SPANISH_CORE)})
    assert ": FISH_COUNT.one: placeholder:" in only(found)  # "{count} pez" adds {count} to "one fish"


# --- newline ----------------------------------------------------------------------------------------------------------


def test_newline_fails_when_the_line_breaks_differ_from_englishs(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value = "%s\\nde %s"', 'value = "%s de %s"'))
    message = only(found)
    assert message.startswith(f"{ES_CORE}: SEAL: newline:") and "esES" in message


def test_newline_passes_where_english_has_the_same_break(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path)  # SEAL has one \n in both
    assert found == []


def test_a_break_english_does_not_have_fails(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value = "Pagle"', 'value = "Pa\\ngle"'))
    assert ": TITLE: newline:" in only(found)


# --- glyph ------------------------------------------------------------------------------------------------------------


def test_glyph_fails_on_a_character_outside_the_locales_range(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value = "Hola, {name}"', 'value = "Hola, Ж {name}"'))
    message = only(found)
    assert message.startswith(f"{ES_CORE}: GREETING: glyph: U+0416")
    assert "range for esES" in message


def test_glyph_passes_the_locales_own_script_and_checks_english_against_the_base_set(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english(), "ruRU": {"locale.toml": RUSSIAN_HEADER, "core.toml": RUSSIAN_CORE}})
    assert found == []
    found, _, _ = checked(tmp_path / "en", {"enUS": english(CORE + 'ARROW = "go → there"\n')})
    message = only(found)
    assert "data/locale/enUS/core.toml: ARROW: glyph: U+2192" in message


def test_the_name_in_the_header_is_held_to_the_locales_range(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, header=swap(SPANISH_HEADER, "Español", "Ж"))
    assert "locale.toml: name: glyph: U+0416" in only(found)


# --- plural -----------------------------------------------------------------------------------------------------------


def test_plural_fails_when_a_category_the_rule_uses_is_missing(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value.many = "{count} de peces"\n', ""))
    message = only(found)
    assert message.startswith(f"{ES_CORE}: FISH_COUNT: plural:") and "lacks many" in message and "esES" in message


def test_plural_fails_when_a_category_the_rule_never_gives_is_there(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value.other = "{count} peces"\n', 'value.other = "{count} peces"\nvalue.few = "{count} pocos"\n'))
    message = only(found)
    assert ": FISH_COUNT: plural:" in message and "has few" in message


def test_plural_fails_without_other(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, swap(SPANISH_CORE, 'value.other = "{count} peces"\n', ""))
    assert "lacks other" in only(found)


def test_russian_needs_one_few_many_and_other(tmp_path: Path) -> None:
    trees = {"enUS": english(), "ruRU": {"locale.toml": RUSSIAN_HEADER, "core.toml": RUSSIAN_CORE}}
    found, _, _ = checked(tmp_path, trees)
    assert found == []
    trees["ruRU"] = {"locale.toml": RUSSIAN_HEADER, "core.toml": swap(RUSSIAN_CORE, 'value.few = "{count} рыбы"\n', "")}
    found, _, _ = checked(tmp_path / "short", trees)
    message = only(found)
    assert "data/locale/ruRU/core.toml: FISH_COUNT: plural:" in message and "lacks few" in message and "ruRU" in message


def test_english_counted_strings_need_other_and_only_categories_english_uses(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english(CORE + "ONLY.other = \"{count} things\"\n")})
    assert found == []  # a count that is never 1 may have no `one`
    found, _, _ = checked(tmp_path / "many", {"enUS": english(CORE + "BAD.one = \"{count} thing\"\nBAD.many = \"{count} things\"\n")})
    assert "data/locale/enUS/core.toml: BAD: plural:" in only(found) and "enUS" in only(found)


# --- shape ------------------------------------------------------------------------------------------------------------


def test_a_translation_has_englishs_shape_because_an_entry_replaces_it_whole(tmp_path: Path) -> None:
    core = swap(SPANISH_CORE, 'value = ["Pequeño", "Grande"]', 'value = ["Pequeño"]')
    assert ": BANDS: shape:" in only(with_spanish(tmp_path / "a", core)[0])
    core = swap(SPANISH_CORE, 'value.1 = "Kalimdor"\n', "")
    assert ": CONTINENTS: shape:" in only(with_spanish(tmp_path / "b", core)[0])
    core = swap(SPANISH_CORE, '[TITLE]\nvalue = "Pagle"\nen = "Pagle"', '[TITLE]\nvalue.one = "Pagle"\nen = "Pagle"')
    assert ": TITLE: shape:" in only(with_spanish(tmp_path / "c", core)[0])


def test_a_translated_key_without_its_en_snapshot_is_a_shape_problem(tmp_path: Path) -> None:
    found, _, _ = with_spanish(tmp_path, SPANISH_CORE.replace('[TITLE]\nvalue = "Pagle"\nen = "Pagle"', 'TITLE_X = "Pagle"\n[TITLE]\nvalue = "Pagle"'))
    assert any(": TITLE: shape:" in message for message in found)


# --- drift ------------------------------------------------------------------------------------------------------------


def test_drift_warns_and_never_fails(tmp_path: Path) -> None:
    changed = CORE.replace('TITLE = "Pagle"', 'TITLE = "Pagle!"')
    found, warnings, _ = checked(tmp_path, {"enUS": english(changed), "esES": spanish()})
    assert found == []
    message = only(warnings)
    assert f"{ES_CORE}: TITLE: drift:" in message and "esES" in message and "keeps showing" in message


def test_drift_that_changes_the_fields_says_it_will_be_dropped(tmp_path: Path) -> None:
    changed = CORE.replace('GREETING = "Hello, {name}"', 'GREETING = "Hello, {who}"')
    found, warnings, _ = checked(tmp_path, {"enUS": english(changed), "esES": spanish()})
    assert ": GREETING: placeholder:" in only(found)  # the stale translation no longer fits until the script drops it
    assert "dropped to English" in only(warnings)


# --- coverage (the dev's decision of 4 Nov: 100% to enter, stays listed) --------------------------------------------------


LISTED = swap(SPANISH_HEADER, "listed = false", "listed = true")
GAPPED = SPANISH_CORE[: SPANISH_CORE.index("[SEAL]")]  # lacks SEAL and WEIGHT


def test_a_locale_entering_listing_below_100_percent_fails(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english(), "esES": spanish(GAPPED, LISTED)}, listed_before={"esES": False})
    message = only(found)
    assert message.startswith("data/locale/esES/locale.toml: listed: coverage:")
    assert "esES" in message and "core.SEAL" in message and "core.WEIGHT" in message


def test_a_locale_absent_at_the_merge_base_counts_as_not_listed(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english(), "esES": spanish(GAPPED, LISTED)}, listed_before={})
    assert ": coverage:" in only(found)


def test_a_locale_already_listed_with_gaps_only_warns(tmp_path: Path) -> None:
    found, warnings, _ = checked(
        tmp_path, {"enUS": english(), "esES": spanish(GAPPED, LISTED)}, listed_before={"esES": True}
    )
    assert found == []
    assert ": coverage:" in only(warnings) and "esES" in only(warnings) and "show English" in only(warnings)


def test_with_no_base_known_a_gap_only_warns(tmp_path: Path) -> None:
    found, warnings, _ = checked(tmp_path, {"enUS": english(), "esES": spanish(GAPPED, LISTED)}, listed_before=None)
    assert found == [] and ": coverage:" in only(warnings)


def test_a_new_english_key_never_fails_a_listed_locale(tmp_path: Path) -> None:
    grown = english(CORE + 'NEWER = "A new string"\n')
    found, warnings, _ = checked(tmp_path, {"enUS": grown, "esES": spanish(SPANISH_CORE, LISTED)}, listed_before={"esES": True})
    assert found == []
    assert "core.NEWER" in only(warnings)


def test_a_listed_locale_at_100_percent_passes_and_an_unlisted_gap_is_silent(tmp_path: Path) -> None:
    found, warnings, _ = checked(tmp_path, {"enUS": english(), "esES": spanish(SPANISH_CORE, LISTED)}, listed_before={"esES": False})
    assert found == [] and warnings == []
    found, warnings, _ = checked(tmp_path / "unlisted", {"enUS": english(), "esES": spanish(GAPPED)}, listed_before={"esES": False})
    assert found == [] and warnings == []


def test_a_fallback_locale_is_covered_by_its_fallbacks_strings(tmp_path: Path) -> None:
    mx = {"locale.toml": 'name = "Español de México"\nlisted = true\nfallback = "esES"\ndecimal = "."\n'}
    trees = {"enUS": english(), "esES": spanish(), "esMX": mx}
    found, warnings, _ = checked(tmp_path, trees, listed_before={"esES": True, "esMX": False})
    assert found == [] and warnings == []  # esMX has no strings of its own, and esES has every key


def test_judge_coverage_is_a_pure_rule() -> None:
    cases = [
        (True, False, 3, 5, "fail"),
        (True, None, 3, 5, "warn"),
        (True, True, 3, 5, "warn"),
        (True, False, 5, 5, "ok"),
        (False, False, 3, 5, "ok"),
        (False, True, 3, 5, "ok"),
    ]
    for listed, before, covered, total, expected in cases:
        problems = Problems()
        warnings: list[str] = []
        judge_coverage("esES", listed, before, covered, total, ["core.A"], problems, warnings)
        got = "fail" if problems else "warn" if warnings else "ok"
        assert got == expected, (listed, before, covered, total)


# --- the header -------------------------------------------------------------------------------------------------------


def test_the_header_of_english_is_the_helpers_built_in(tmp_path: Path) -> None:
    trees = {"enUS": english() | {"locale.toml": ENGLISH_HEADER.replace('thousands = ","', 'thousands = " "')}}
    found, _, _ = checked(tmp_path, trees)
    assert "locale.toml: thousands: header:" in only(found) and "built in" in only(found)


@pytest.mark.parametrize(
    ("old", "new", "detail"),
    [
        ('plural = "one_many_other"', 'plural = "dual"', "not a plural rule"),
        ('decimal = ","', 'decimal = ""', "empty"),
        ('thousands = "."', 'thousands = ","', "same separator"),
        ('listed = false', 'listed = "no"', "true or false"),
        ('listed = false\n', "", "missing key 'listed'"),
        ('plural = "one_many_other"\n', "", "missing key 'plural'"),
        ('name = "Español"', 'name = ""', "empty"),
        ('translators = ["Ana", "Luis"]', 'translators = [1]', "array of names"),
        ('decimal = ","\n', 'decimal = ","\nfallback = "fiFI"\n', "no Locale fiFI"),
        ('decimal = ","\n', 'decimal = ","\nfallback = "enUS"\n', "never its own or enUS"),
        ('decimal = ","\n', 'decimal = ","\nfallback = "esES"\n', "never its own or enUS"),
        ('decimal = ","\n', 'decimal = ","\nbogus = 1\n', "unknown key 'bogus'"),
    ],
)
def test_a_bad_header_fails_with_the_file_and_the_field(tmp_path: Path, old: str, new: str, detail: str) -> None:
    found, _, _ = with_spanish(tmp_path, header=swap(SPANISH_HEADER, old, new))
    assert any("data/locale/esES/locale.toml" in message and detail in message for message in found), found


def test_a_fallback_locale_gives_only_what_it_changes(tmp_path: Path) -> None:
    mx = {"locale.toml": 'name = "Español de México"\nlisted = false\nfallback = "esES"\ndecimal = "."\n'}
    found, _, layer = checked(tmp_path, {"enUS": english(), "esES": spanish(), "esMX": mx})
    assert found == []
    assert layer.headers["esMX"].plural is None and layer.headers["esMX"].decimal == "."


def test_a_fallback_chain_that_loops_fails(tmp_path: Path) -> None:
    a = {"locale.toml": 'name = "A"\nlisted = false\nfallback = "esMX"\ndecimal = "."\n'}
    b = {"locale.toml": 'name = "B"\nlisted = false\nfallback = "esES"\ndecimal = "."\n'}
    found, _, _ = checked(tmp_path, {"enUS": english(), "esES": a, "esMX": b})
    assert any("loops" in message for message in found)


def test_a_locale_with_no_glyph_range_or_a_bad_directory_name_fails(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english(), "xxXX": spanish(), "spanish": spanish()})
    assert any("data/locale/xxXX" in message and "no range" in message for message in found)
    assert any("data/locale/spanish" in message and "client code" in message for message in found)


def test_english_must_exist_with_a_file_for_every_addon(tmp_path: Path) -> None:
    files = english()
    del files["qol.toml"]
    found, _, _ = checked(tmp_path, {"enUS": files})
    assert any("data/locale/enUS/qol.toml: missing:" in message for message in found)
    found, _, _ = checked(tmp_path / "none", {"esES": spanish()})
    assert any("English is the source" in message for message in found)


def test_an_unknown_file_in_a_locale_directory_fails(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english() | {"extra.toml": ""}})
    assert any("data/locale/enUS/extra.toml" in message for message in found)


def test_a_key_is_a_lua_name_and_a_nested_key_any_text_or_a_whole_number(tmp_path: Path) -> None:
    found, _, _ = checked(tmp_path, {"enUS": english(CORE + '"bad-key" = "x"\n')})
    assert any("bad-key" in message and "shape" in message for message in found)
    found, _, _ = checked(tmp_path / "kw", {"enUS": english(CORE + 'end = "x"\n')})
    assert any(": end: shape:" in message and "keyword" in message for message in found)
    found, _, layer = checked(tmp_path / "n", {"enUS": english(CORE + 'T."core.binding" = "x"\nT."12h" = "y"\nT.5 = "z"\n')})
    assert found == []
    assert layer.files["enUS"]["core"]["T"].value == {"core.binding": "x", "12h": "y", 5: "z"}
    found, _, _ = checked(tmp_path / "e", {"enUS": english(CORE + 'T."" = "x"\n')})
    assert any("empty key" in message for message in found)
    found, _, _ = checked(tmp_path / "a", {"enUS": english(CORE + "T = []\n")})
    assert any("empty array" in message for message in found)
    found, _, _ = checked(tmp_path / "t", {"enUS": english(CORE + "T = 5\n")})
    assert any("expected text, an array or a table, got an integer" in message for message in found)


def test_an_empty_text_english_has_may_be_empty_in_a_translation(tmp_path: Path) -> None:
    """A separator that is "" in English (ANGLER_MILESTONE_SEPARATOR) is not missing when a translation keeps it empty."""
    english_core = english(CORE + 'JOIN = ""\n')
    found, _, _ = checked(tmp_path, {"enUS": english_core, "esES": spanish(SPANISH_CORE + '\n[JOIN]\nvalue = ""\nen = ""\n')})
    assert found == []
    found, _, _ = checked(tmp_path / "x", {"enUS": english_core, "esES": spanish(SPANISH_CORE + '\n[JOIN]\nvalue = "y"\nen = ""\n')})
    assert found == []  # a translation may add a word to a blank, and the snapshot is what warns
