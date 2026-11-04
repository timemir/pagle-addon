"""A Locale's Lore (DATA-R104, DATA-R107, DATA-R114): data/lore/<code>/<lore ID>.toml, its checks, and the
addons/<Addon>/data/Lore.<code>.lua it becomes, over fixture trees. The repository ships no translation."""

from pathlib import Path

import pytest

from cli_fixture import run
from locale_fixture import write_locales
from lore_locale_fixture import (
    ES_LEDGER,
    LEDGER_LORE,
    LORE_ES_LUA,
    entry,
    judged,
    read,
    registering_locales,
    write_translations,
    write_tree,
)
from pagle_data.lore import translated_limit
from test_hunts_lore import write_tree as write_hunts_tree
from test_lore import BLANK_RIDDLE, LEDGER, LORE_LUA, ON, SPEC_FIXTURE

REPO = Path(__file__).resolve().parents[2]
RIDDLE = "species.13759.riddle"
FAMILY = "family.1.name"
ZONEMASTER = "title.zonemaster.text"


def only(problems: list[str]) -> str:
    assert len(problems) == 1, problems
    return problems[0]


# --- the shape: every translated field is a table of value and en ---------------------------------------------------


def test_a_translated_field_is_its_own_table_of_the_translation_and_its_snapshot(tmp_path: Path) -> None:
    layer, problems = read(tmp_path, {"esES": {"ledger": ES_LEDGER}})

    assert problems.found == []
    translation = layer.translations["esES"]["ledger"]
    assert translation.texts[RIDDLE].value == "Pica donde el agua corre perezosa."
    assert translation.snapshots[RIDDLE] == "Bites where the water runs lazy."
    assert translation.texts["legend.19807.title"].field == "title"
    assert sorted(translation.texts) == sorted(translation.snapshots)
    # The translation is in no English source: none of the English checks or files can see it.
    assert layer.files["ledger"][RIDDLE].value == "Bites where the water runs lazy."


@pytest.mark.parametrize(
    ("text", "detail"),
    [
        ('[species.13759]\nriddle = "Pica."\n', "species.13759.riddle: shape: a translated field is a table with `value`"),
        ('[species.13759.riddle]\nvalue = "Pica."\n', "species.13759.riddle: shape: a translated field is a table with `value`"),
        ('[species.13759.riddle]\nen = "Bites."\n', "species.13759.riddle: shape: a translated field is a table with"),
        (
            '[species.13759.riddle]\nvalue = "Pica."\nen = "Bites."\nnote = "x"\n',
            "species.13759.riddle: shape: a translated field is a table with",
        ),
        ('[species.13759.riddle]\nvalue = 3\nen = "Bites."\n', "species.13759.riddle.value: shape: expected a string, got an integer"),
        ('[species.13759.riddle]\nvalue = "Pica."\nen = ["Bites."]\n', "species.13759.riddle.en: shape: expected a string, got an array"),
    ],
)
def test_a_field_that_is_not_value_and_en_is_a_shape_problem(tmp_path: Path, text: str, detail: str) -> None:
    problems = judged(tmp_path, text)

    assert len(problems) == 1, problems
    assert f"{LEDGER_LORE}: {detail}" in problems[0]
    assert "(DATA-R114)" in problems[0]


def test_a_file_that_is_not_toml_is_one_problem_naming_it(tmp_path: Path) -> None:
    assert "data/lore/esES/ledger.toml: not valid TOML" in only(judged(tmp_path, "[species\n"))


def test_a_directory_that_is_not_a_locale_a_file_that_is_not_a_lore_id_or_a_code_with_no_range_is_a_problem(
    tmp_path: Path,
) -> None:
    layer, problems = read(
        tmp_path,
        {"enUS": {"ledger": ""}, "es": {"ledger": ""}, "xxXX": {"ledger": ""}, "esES": {"qol": "", "ledger": ES_LEDGER}},
    )

    found = problems.found
    assert len(found) == 4, found
    assert "data/lore/enUS: English Lore is data/lore/*.toml, never a directory of its own (DATA-R104, DATA-R114)" in found
    assert "data/lore/es: a Locale's directory is its full client code, like esES (DATA-R114)" in found
    assert any(line.startswith("data/lore/xxXX: no range for the Locale (CORE-R9, DATA-R114)") for line in found)
    assert (
        "data/lore/esES/qol.toml: not a lore file; a Locale's lore files are named by lore ID"
        " (core, ledger, hunts, stats, tackleboard) (DATA-R114)"
    ) in found
    assert list(layer.translations) == ["esES"]


# --- the checks: each names the file, the key and the Locale --------------------------------------------------------


def test_an_orphan_is_a_key_english_lacks_and_names_the_locale(tmp_path: Path) -> None:
    text = entry("species.99999.riddle", "Pica.", "x") + entry("species.13759.moral", "Pica.", "x")

    problems = judged(tmp_path, text)

    assert problems == [
        f"{LEDGER_LORE}: species.13759.moral: orphan: English has no such key (esES, DATA-R114)",
        f"{LEDGER_LORE}: species.99999.riddle: orphan: English has no such key (esES, DATA-R114)",
    ]


def test_a_key_that_english_has_in_another_addon_s_file_is_an_orphan_naming_that_file(tmp_path: Path) -> None:
    layer_problems = read(
        tmp_path,
        {"esES": {"ledger": entry('good."core.a".name', "Madera", "Timber")}},
        {"ledger": LEDGER, "core": '[good."core.a"]\nname = "Timber"\n'},
    )[1]

    assert only(layer_problems.found) == (
        f"{LEDGER_LORE}: good.core.a.name: orphan: belongs to core.toml, not ledger.toml (esES, DATA-R114)"
    )


def test_a_missing_key_is_never_an_error_and_an_empty_file_is_fine(tmp_path: Path) -> None:
    layer, problems = read(tmp_path, {"esES": {"ledger": entry(RIDDLE, "Pica.", "Bites where the water runs lazy.")}})

    assert problems.found == []
    assert list(layer.translations["esES"]["ledger"].texts) == [RIDDLE]
    assert read(tmp_path / "empty", {"esES": {"ledger": "# nothing yet\n"}})[1].found == []


def test_an_empty_value_is_missing_and_names_the_key(tmp_path: Path) -> None:
    problem = only(judged(tmp_path, entry(RIDDLE, " ", "Bites where the water runs lazy.")))

    assert problem.startswith(f"{LEDGER_LORE}: {RIDDLE}: missing: empty")
    assert "(esES, DATA-R107, DATA-R114)" in problem


def test_a_newline_fails(tmp_path: Path) -> None:
    text = '[species.13759.riddle]\nvalue = "Pica\\ndonde."\nen = "Bites where the water runs lazy."\n'

    problem = only(judged(tmp_path, text))

    assert problem == f"{LEDGER_LORE}: {RIDDLE}: newline: a line break (esES, DATA-R107, DATA-R114)"


@pytest.mark.parametrize(
    ("english", "expected"),
    [(28, 36), (32, 41), (80, 104), (100, 130), (200, 260)],
)
def test_the_limit_is_the_english_one_plus_thirty_percent_dropping_the_fraction(english: int, expected: int) -> None:
    assert translated_limit(english) == expected


@pytest.mark.parametrize(
    ("key", "unit", "most"),
    [
        (RIDDLE, "riddle", 104),  # riddle 80
        (FAMILY, "name", 36),  # name 28
        (ZONEMASTER, "text", 41),  # a title's text 32
        ("legend.19807.title", "title", 41),  # a Legend's title field 32
        ("sub.4000.plaque", "plaque", 130),  # plaque 100
        ("species.13759.blurb", "blurb", 260),  # blurb 200
    ],
)
def test_a_field_at_the_limit_plus_thirty_percent_passes_and_one_over_fails_counting_code_points(
    tmp_path: Path, key: str, unit: str, most: int
) -> None:
    # "ñ" is one code point and two bytes: counting bytes would fail the first at half the length.
    at, over = "ñ" * most, "ñ" * (most + 1)
    english = {"ledger": LEDGER}
    snapshot = "x"
    # A placeholder field keeps its {zone}, which the title.zonemaster.text fixture has.
    suffix = " {zone}" if key == ZONEMASTER else ""
    kind_id, name = key.rsplit(".", 1)
    ok = f"[{kind_id}.{name}]\nvalue = \"{at[: len(at) - len(suffix)] + suffix}\"\nen = \"{snapshot}\"\n"
    bad = f"[{kind_id}.{name}]\nvalue = \"{over[: len(over) - len(suffix)] + suffix}\"\nen = \"{snapshot}\"\n"

    assert read(tmp_path / "at", {"esES": {"ledger": ok}}, english)[1].found == []
    problem = only(read(tmp_path / "over", {"esES": {"ledger": bad}}, english)[1].found)
    assert problem.startswith(f"{LEDGER_LORE}: {key}: length: {most + 1} code points, over {unit}'s limit of ")
    assert f"plus 30%, {most}" in problem
    assert problem.endswith("(esES, DATA-R107, DATA-R114)")


def test_a_field_with_no_english_limit_has_none_in_a_translation(tmp_path: Path) -> None:
    english = {"core": '[good."core.a"]\nname = "Timber"\ndescription = "A fresh page."\n'}
    long_text = "ñ" * 5000

    problems = read(
        tmp_path, {"esES": {"core": entry('good."core.a".description', long_text, "A fresh page.")}}, english
    )[1].found

    assert problems == []


@pytest.mark.parametrize(
    ("value", "detail"),
    [
        ("Maestro", "lacks {zone}"),
        ("Maestro de {zone} y {fish}", "adds {fish}"),
        ("Maestro de {fish}", "lacks {zone}; adds {fish}"),
    ],
)
def test_the_placeholder_set_must_match_the_english_text(tmp_path: Path, value: str, detail: str) -> None:
    text = entry(ZONEMASTER, value, "Master of {zone}")

    problem = only(judged(tmp_path, text))

    assert problem == (
        f"{LEDGER_LORE}: {ZONEMASTER}: placeholder: the placeholders differ from the English text's: {detail}"
        " (esES, DATA-R107, DATA-R114)"
    )


def test_a_brace_outside_zone_and_fish_is_a_placeholder_problem_even_when_the_set_matches(tmp_path: Path) -> None:
    problem = only(judged(tmp_path, entry(ZONEMASTER, "Maestro de {zone} {zona}", "Master of {zone}")))

    assert problem == (
        f"{LEDGER_LORE}: {ZONEMASTER}: placeholder: { '{ or } outside {zone} and {fish}' } (esES, DATA-R107, DATA-R114)"
    )


def test_a_text_without_placeholders_may_not_gain_one(tmp_path: Path) -> None:
    problem = only(judged(tmp_path, entry(RIDDLE, "Pica en {zone}.", "Bites where the water runs lazy.")))

    assert "placeholder: the placeholders differ from the English text's: adds {zone}" in problem


def test_the_glyph_check_uses_the_locale_s_range_and_names_the_code_point_the_key_and_the_locale(tmp_path: Path) -> None:
    russian = entry(RIDDLE, "Клюёт там, где вода ленива.", "Bites where the water runs lazy.")
    spanish_with_cyrillic = entry(RIDDLE, "Pica Ж aquí.", "Bites where the water runs lazy.")

    assert read(tmp_path / "ru", {"ruRU": {"ledger": russian}})[1].found == []
    problem = only(judged(tmp_path / "es", spanish_with_cyrillic))
    assert problem.startswith(f"{LEDGER_LORE}: {RIDDLE}: glyph: U+0416 outside CORE-R9's range for esES: ")
    assert problem.endswith("(CORE-R9, DATA-R114)")


def test_the_snapshot_is_english_and_is_not_held_to_the_locale_s_glyphs_or_limits(tmp_path: Path) -> None:
    text = entry(RIDDLE, "Pica.", "Bites where the water runs lazy → and more " + "x" * 200)

    assert judged(tmp_path, text) == []


def test_drift_is_a_warning_and_never_a_problem(tmp_path: Path) -> None:
    layer, problems = read(
        tmp_path,
        {
            "esES": {
                "ledger": entry(RIDDLE, "Pica.", "Bites where the water ran lazy.")  # English now says "runs"
                + entry(ZONEMASTER, "Maestro de {zone}", "Lord of {zone}")
                + entry("title.level1.text", "Novato", "Greenhorn")
                + entry("line.uncaughtlegend.text", "Hay peces que son cuentos.", "Some fish are stories.")
            }
        },
    )

    assert problems.found == []
    assert layer.warnings == [
        f"{LEDGER_LORE}: line.uncaughtlegend.text: drift: the EN snapshot is not the English text now (esES);"
        " the placeholders are the same, so it keeps showing",
        f"{LEDGER_LORE}: {RIDDLE}: drift: the EN snapshot is not the English text now (esES);"
        " the placeholders are the same, so it keeps showing",
        f"{LEDGER_LORE}: {ZONEMASTER}: drift: the EN snapshot is not the English text now (esES);"
        " the placeholders are the same, so it keeps showing",
    ]


def test_drift_that_changes_the_placeholders_says_so_and_still_only_warns(tmp_path: Path) -> None:
    layer, problems = read(
        tmp_path,
        {"esES": {"ledger": entry(ZONEMASTER, "Maestro de {zone}", "Master of {fish}")}},
    )

    assert problems.found == []
    assert only(layer.warnings).endswith("the placeholders changed")


# --- Hunts: the text beside the definitions is addressed by key, and an orphan is a key in neither source -----------


HUNT_TEXT = {"hunt.night_run.name": "Night Run", "set.camp_hours.title": "the Hut Keeper"}
EVENT_TEXT = {"event.stv_shallows.name": "Shallows", "event.stv_shallows.note": "A note.", "hunt.stv_shallows_1.name": "H"}
GOODS = '[huntgood."hunts.frame.none"]\nname = "No Frame"\ndescription = "Nothing around the lines."\n'


def test_hunt_set_event_and_good_text_are_translated_in_hunts_toml_under_the_lore_keys(tmp_path: Path) -> None:
    translation = (
        entry("hunt.night_run.name", "Carrera nocturna", "Night Run")
        + entry("set.camp_hours.title", "el Guardián", "the Hut Keeper")
        + entry("event.stv_shallows.note", "Una nota.", "A note.")
        + entry("hunt.stv_shallows_1.name", "H", "H")
        + entry('huntgood."hunts.frame.none".name', "Sin marco", "No Frame")
    )

    layer, problems = read(
        tmp_path,
        {"esES": {"hunts": translation}},
        {"hunts": GOODS},
        hunts=HUNT_TEXT,
        events={"data/hunts/events/stv_shallows.toml": EVENT_TEXT},
    )

    assert problems.found == []
    assert len(layer.translations["esES"]["hunts"].texts) == 5


def test_a_hunts_key_in_neither_source_is_an_orphan_and_the_hunt_limits_apply(tmp_path: Path) -> None:
    translation = (
        entry("hunt.no_such_hunt.name", "x", "x")
        + entry("set.camp_hours.note", "x", "x")  # the set has no note in this fixture
        + entry("hunt.night_run.name", "ñ" * 37, "Night Run")  # name 28 plus 30% is 36
        + entry("hunt.night_run.note", "x", "x")
    )

    problems = read(
        tmp_path, {"esES": {"hunts": translation}}, {"hunts": GOODS}, hunts=HUNT_TEXT, events={}
    )[1].found

    hunts = "data/lore/esES/hunts.toml"
    assert sorted(problems) == sorted(
        [
            f"{hunts}: hunt.no_such_hunt.name: orphan: English has no such key (esES, DATA-R114)",
            f"{hunts}: set.camp_hours.note: orphan: English has no such key (esES, DATA-R114)",
            f"{hunts}: hunt.night_run.note: orphan: English has no such key (esES, DATA-R114)",
            f"{hunts}: hunt.night_run.name: length: 37 code points, over name's limit of 28 plus 30%, 36"
            " (esES, DATA-R107, DATA-R114)",
        ]
    )


def test_a_hunt_text_with_a_brace_fails_since_english_allows_none(tmp_path: Path) -> None:
    problem = only(
        read(
            tmp_path,
            {"esES": {"hunts": entry("hunt.night_run.name", "Carrera {zone}", "Night Run")}},
            {"hunts": GOODS},
            hunts=HUNT_TEXT,
        )[1].found
    )

    assert "hunt.night_run.name: placeholder: the placeholders differ" in problem


def test_a_hunt_key_in_the_ledger_file_is_an_orphan_naming_hunts_toml(tmp_path: Path) -> None:
    problem = only(
        read(
            tmp_path,
            {"esES": {"ledger": entry("hunt.night_run.name", "Carrera", "Night Run")}},
            hunts=HUNT_TEXT,
        )[1].found
    )

    assert problem.endswith("orphan: belongs to hunts.toml, not ledger.toml (esES, DATA-R114)")


# --- the English checks never see a translation ---------------------------------------------------------------------


def test_every_english_check_ignores_the_translation_files(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # The English ledger check is on and passes. The translation holds a key English lacks: only the translation's
    # checks report it, and none names an English file.
    text = ES_LEDGER + entry("species.99999.riddle", "Pica.", "x")
    root = write_tree(tmp_path, {"esES": {"ledger": text}}, checks=ON)
    code, output = run(root, capsys)

    assert code == 1
    assert f"{LEDGER_LORE}: species.99999.riddle: orphan: English has no such key (esES, DATA-R114)" in output
    assert "data/lore/ledger.toml:" not in output
    assert "1 problem(s)" in output


# --- generation -------------------------------------------------------------------------------------------------------


GUARD = (
    "if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)\n"
    "\treturn\n"
    "end\n\n"
)

LEDGER_ES_LUA = (
    GUARD
    + "-- Generated by scripts/generate-data.py from data/lore/esES/ledger.toml. Do not edit by hand: edit data/ and"
    " run the generator.\n-- GPL-3.0-or-later.\n-- Translators: Ana, Luis.\n\n"
    "---@class PagleLedgerNS\nlocal ns = select(2, ...)\n\n"
    'ns.Locale("esES", function(L)\n'
    '\tL["legend.19807.title"] = "El Sabrosón"\n'
    '\tL["species.13759.riddle"] = "Pica donde el agua corre perezosa."\n'
    '\tL["title.level1.text"] = "Novato"\n'
    '\tL["title.zonemaster.text"] = "Maestro de {zone}"\n'
    "end)\n"
)


def test_a_translation_is_one_locale_call_with_no_opts_keys_sorted_by_byte(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_tree(tmp_path)
    code, output = run(root, capsys)

    assert code == 0, output
    assert (root / LORE_ES_LUA).read_text(encoding="utf-8") == LEDGER_ES_LUA


def test_a_core_translation_has_no_guard(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = write_tree(
        tmp_path,
        {"esES": {"core": entry('good."core.a".name', "Madera", "Timber")}},
        ledger="# none\n",
        addons=("core",),
        core='[good."core.a"]\nname = "Timber"\n',
        manifest='[core.good]\nfields = ["name"]\nids = ["core.a"]\n',
    )

    code, output = run(root, capsys)

    assert code == 0, output
    text = (root / "addons/Pagle/data/Lore.esES.lua").read_text(encoding="utf-8")
    assert text.startswith("-- Generated by scripts/generate-data.py from data/lore/esES/core.toml.")
    assert "---@class PagleNS\n" in text
    assert 'L["good.core.a.name"] = "Madera"\n' in text


def test_generating_with_a_translation_leaves_the_english_lore_lua_byte_identical(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # PRJ-R18: data/Lore.lua keeps its name, path and English content, whatever translations exist.
    with_translation = write_tree(tmp_path / "with")
    without = write_tree(tmp_path / "without", {})
    run(with_translation, capsys)
    run(without, capsys)

    assert (with_translation / LORE_LUA).read_bytes() == (without / LORE_LUA).read_bytes()
    assert not (without / LORE_ES_LUA).exists()
    # The English file stays self-contained: it names no Locale and no registration.
    english = (with_translation / LORE_LUA).read_text(encoding="utf-8")
    assert "ns.Locale" not in english
    assert "esES" not in english


def test_locales_xml_lists_the_lore_file_after_the_interface_file_of_the_same_code(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_tree(tmp_path, {"esES": {"ledger": ES_LEDGER}, "esMX": {"ledger": ES_LEDGER}})
    code, output = run(root, capsys)

    assert code == 0, output
    ledger = (root / "addons/Pagle_Ledger/locale/Locales.xml").read_text(encoding="utf-8")
    scripts = [line.split('"')[1] for line in ledger.splitlines() if "<Script" in line]
    assert scripts == [
        "Registry.lua",
        "esES.lua",
        "..\\data\\Lore.esES.lua",
        "esMX.lua",
        "..\\data\\Lore.esMX.lua",
        "Apply.lua",
    ]
    # An addon with no Lore translation lists its interface file alone.
    core = (root / "addons/Pagle/locale/Locales.xml").read_text(encoding="utf-8")
    assert [line.split('"')[1] for line in core.splitlines() if "<Script" in line] == [
        "Registry.lua",
        "esES.lua",
        "esMX.lua",
        "Apply.lua",
    ]


def test_a_translation_file_with_no_text_writes_no_lore_file_and_no_xml_line(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_tree(tmp_path, {"esES": {"ledger": "# nothing yet\n"}})
    code, output = run(root, capsys)

    assert code == 0, output
    assert not (root / LORE_ES_LUA).exists()
    assert "Lore.esES" not in (root / "addons/Pagle_Ledger/locale/Locales.xml").read_text(encoding="utf-8")


def test_a_translation_needs_the_locale_that_registers_the_code_for_that_addon(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # No data/locale/esES/: nothing would register esES, and Registry.lua never applies a code only Lore registered.
    root = write_tree(tmp_path, registering=())
    code, output = run(root, capsys)

    assert code == 1
    assert (
        f"{LEDGER_LORE}: registration: {LEDGER_LORE} needs data/locale/esES/locale.toml and"
        " data/locale/esES/ledger.toml, which register esES for this addon with ns.Locale (DATA-R114)"
    ) in output
    assert not (root / LORE_ES_LUA).exists()

    # A Locale that has a header but no interface file for this addon is the same problem.
    trees = registering_locales("esES")
    del trees["esES"]["ledger.toml"]
    root = write_tree(tmp_path / "other", registering=())
    write_locales(root, trees)
    assert "registration:" in run(root, capsys)[1]


def test_generating_fails_on_a_bad_translation_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_tree(tmp_path, {"esES": {"ledger": entry(ZONEMASTER, "Maestro", "Master of {zone}")}})
    code, output = run(root, capsys)

    assert code == 1
    assert "title.zonemaster.text: placeholder:" in output
    assert not (root / LORE_ES_LUA).exists()
    assert not (root / LORE_LUA).exists()


def test_drift_is_printed_as_a_warning_and_the_run_still_succeeds(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_tree(tmp_path, {"esES": {"ledger": entry("title.level1.text", "Novato", "Rookie")}})
    code, output = run(root, capsys)

    assert code == 0, output
    assert "generate-data: warning: data/lore/esES/ledger.toml: title.level1.text: drift:" in output
    assert (root / LORE_ES_LUA).exists()


def test_check_fails_for_a_stale_translation_file_and_a_removed_source_retires_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_tree(tmp_path)
    assert run(root, capsys)[0] == 0
    assert run(root, capsys, "--check")[0] == 0

    (root / LEDGER_LORE).write_text(ES_LEDGER.replace("Novato", "Aprendiz"), encoding="utf-8")
    code, output = run(root, capsys, "--check")
    assert code == 1
    assert f"{LORE_ES_LUA} is out of date with data/" in output

    (root / LEDGER_LORE).unlink()
    code, output = run(root, capsys, "--check")
    assert code == 1
    assert f"{LORE_ES_LUA} is out of date with data/: {LEDGER_LORE} is gone" in output
    code, output = run(root, capsys)
    assert code == 0, output
    assert f"removed {LORE_ES_LUA}, as {LEDGER_LORE} is gone" in output
    assert not (root / LORE_ES_LUA).exists()
    assert run(root, capsys, "--check")[0] == 0


def test_the_busted_fixture_lore_eses_lua_is_what_the_generator_emits(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # spec/lore_locale_spec.lua loads this file under the real Registry.lua and Apply.lua, over the English fixture
    # (spec/Pagle_Ledger/fixtures/Lore.lua, which test_lore.py pins to BLANK_RIDDLE): pinned to the generator here.
    root = write_tree(tmp_path, ledger=BLANK_RIDDLE)
    assert run(root, capsys)[0] == 0

    fixture = (REPO / "spec/fixtures/lore-locale/Lore.esES.lua").read_text(encoding="utf-8")
    assert (root / LORE_ES_LUA).read_text(encoding="utf-8") == fixture
    assert (root / LORE_LUA).read_text(encoding="utf-8") == (REPO / SPEC_FIXTURE).read_text(encoding="utf-8")


# --- Pagle_Hunts end to end -------------------------------------------------------------------------------------------


def test_hunts_text_translated_in_hunts_toml_becomes_pagle_hunts_lore_esES(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    root = write_hunts_tree(tmp_path)
    write_locales(root, registering_locales("esES", addons=("hunts",)))
    write_translations(
        root,
        {
            "esES": {
                "hunts": entry("hunt.night_run.name", "Carrera nocturna", "Night Run")
                + entry("set.camp_hours.title", "el Guardián", "the Hut Keeper")
                + entry('huntgood."hunts.frame.none".name', "Sin marco", "No Frame")
            }
        },
    )
    code, output = run(root, capsys)

    assert code == 0, output
    text = (root / "addons/Pagle_Hunts/data/Lore.esES.lua").read_text(encoding="utf-8")
    assert text.startswith(GUARD)
    assert text.endswith(
        'ns.Locale("esES", function(L)\n'
        '\tL["hunt.night_run.name"] = "Carrera nocturna"\n'
        '\tL["huntgood.hunts.frame.none.name"] = "Sin marco"\n'
        '\tL["set.camp_hours.title"] = "el Guardián"\n'
        "end)\n"
    )
    assert "Lore.esES" in (root / "addons/Pagle_Hunts/locale/Locales.xml").read_text(encoding="utf-8")
