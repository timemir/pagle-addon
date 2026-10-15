"""The repo's own lore (DATA-R111): data/lore/ledger.toml, the Ledger's first batch and its M4 titles and bindings,
data/lore/core.toml, Core's goods, and Hunts' M5 batch, its goods in data/lore/hunts.toml and its Hunts' and sets' text
in data/hunts/hunts.toml, each with its lore check on (DATA-R66, LED-R162, HNT-R130)."""

import csv
import re
import shutil
import tomllib
from collections.abc import Callable
from dataclasses import replace
from functools import cache
from pathlib import Path

import pytest

from cli_fixture import run
from pagle_data.checks import BUILT_LORE_CHECKS
from pagle_data.errors import Problems
from pagle_data.generate import Layers, hunt_list_of, read_layers
from pagle_data.hunts import hunt_hash
from pagle_data.lore import Text, catalogue_ids, check_lore

REPO = Path(__file__).resolve().parents[2]
LEDGER_TOML = REPO / "data" / "lore" / "ledger.toml"

# SHOP-R25: Core's nine goods at M4, by slot.
CORE_GOODS = [
    "core.toaststyle.timber",
    "core.toaststyle.ripple",
    "core.toaststyle.lanternglow",
    "core.soundset.driftwood",
    "core.soundset.gilded",
    "core.crest.plain",
    "core.crest.crest1",
    "core.crest.crest2",
    "core.crest.crest3",
]
# LED-R75: the title IDs, in its table's order; LED-R110: the bindings without their ledger.binding. prefix.
LEVEL_TITLES = ["level1", "level10", "level20", "level30", "level40", "level50", "level60"]
TITLES = [
    *LEVEL_TITLES,
    "prestige1",
    "prestige5",
    "prestige10",
    "zonemaster",
    "complete.ledger",
    "complete.junk",
    "complete.treasure",
    "complete.trophy",
]
BINDINGS = ["field", "level10", "level20", "level30", "level40", "level50", "level60", "birch", "buckram", "sharkskin"]


@cache
def _layers() -> Layers:
    return read_layers(REPO)


def _riddles() -> dict[int, str]:
    with LEDGER_TOML.open("rb") as handle:
        species = tomllib.load(handle).get("species", {})
    return {int(species_id): table["riddle"] for species_id, table in species.items() if "riddle" in table}


def _zone_names() -> list[str]:
    # A zone is an areas.csv row with ParentAreaID 0 (DATA-R25); its enUS name is for review only (DATA-R3).
    with (REPO / "data" / "db2" / "areas.csv").open(encoding="utf-8", newline="") as handle:
        return sorted({row["AreaName_lang"] for row in csv.DictReader(handle) if row["ParentAreaID"] == "0"})


def test_the_ledger_s_core_s_and_hunts_lore_checks_are_on() -> None:
    # DATA-R66, LED-R162: the Ledger's lore check turns on in M3 with its first batch (DATA-R111); DATA-R107: Core's
    # in M4, with its goods; HNT-R130: Hunts' in M5, after Core's. Every check built so far is on.
    with (REPO / "data" / "checks.toml").open("rb") as handle:
        assert tomllib.load(handle)["lore"] == list(BUILT_LORE_CHECKS) == ["ledger", "core", "hunts"]


def _problems_with(
    lore_id: str, edit: Callable[[dict[str, Text]], dict[str, Text]], checks: tuple[str, ...] = BUILT_LORE_CHECKS
) -> list[str]:
    """What check_lore finds over the repo's lore, with `checks` on (every built one by default), once `edit` has
    changed lore_id's texts."""
    layers = _layers()
    files = dict(layers.lore.files)
    files[lore_id] = edit(files[lore_id])
    ids = catalogue_ids(layers.items, layers.item_layer.families)
    problems = Problems()
    check_lore(replace(layers.lore, files=files), list(checks), ids, problems)
    return problems.found


def _without(lore_id: str, key: str, checks: tuple[str, ...] = BUILT_LORE_CHECKS) -> list[str]:
    """_problems_with key deleted from lore_id's texts."""
    return _problems_with(lore_id, lambda texts: {name: text for name, text in texts.items() if name != key}, checks)


def test_the_manifest_lists_core_s_nine_goods() -> None:
    # DATA-R106, SHOP-R25: [core.good] with fields name and description and the nine good IDs, none with a placeholder.
    manifest = _layers().lore.manifest["core"]
    assert sorted(manifest) == ["good"]
    assert manifest["good"].fields == ("name", "description")
    assert list(manifest["good"].ids) == CORE_GOODS
    assert all(not allowed for allowed in manifest["good"].ids.values())


def test_core_s_lore_has_a_name_and_a_description_for_every_good() -> None:
    # DATA-R107 passes (read_layers raises on any problem), and SHOP-R25: every good's name and description is lore.
    core = _layers().lore.files["core"]
    for good in CORE_GOODS:
        assert core[f"good.{good}.name"].value.strip()
        assert core[f"good.{good}.description"].value.strip()


@pytest.mark.parametrize("good", CORE_GOODS)
def test_deleting_any_one_good_s_name_fails_the_lore_check_naming_its_key(good: str) -> None:
    # DATA-R107's missing, for the core lore ID: the manifest lists every good (DATA-R106).
    key = f"good.{good}.name"
    assert _without("core", key) == [
        f"data/lore/core.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


def test_the_ledger_s_lore_passes_its_check() -> None:
    # DATA-R107: no missing, orphan, length, newline or placeholder problem; read_layers raises on any.
    layers = _layers()
    ledger = layers.lore.files["ledger"]
    ids = catalogue_ids(layers.items, layers.item_layer.families)
    # DATA-R103: every Species (removed ones included), Legend, Sub-collection item and family has its text.
    assert {f"species.{species}.riddle" for species in ids.species} <= ledger.keys()
    assert {f"legend.{legend}.title" for legend in ids.legends} <= ledger.keys()
    assert {f"sub.{item}.plaque" for item in ids.subs} <= ledger.keys()
    assert {f"family.{family}.name" for family in ids.families} <= ledger.keys()


def test_the_manifest_lists_the_ledger_s_four_shared_lines() -> None:
    # LED-R160, LED-R162 (its M3 part): [ledger.line] with fields ["text"] and the four line IDs.
    manifest = _layers().lore.manifest["ledger"]
    assert sorted(manifest) == ["binding", "line", "title"]
    assert manifest["line"].fields == ("text",)
    assert sorted(manifest["line"].ids) == ["uncaughtjunk", "uncaughtlegend", "uncaughttreasure", "unchartedwaters"]
    assert all(not allowed for allowed in manifest["line"].ids.values())  # no placeholder (DATA-R108)


@pytest.mark.parametrize("species", sorted(_riddles()))
def test_deleting_any_one_riddle_fails_the_lore_check_naming_its_key(species: int) -> None:
    # DATA-R107's missing: with the Ledger's check on, every Species needs a riddle (DATA-R103).
    key = f"species.{species}.riddle"
    assert _without("ledger", key, ("ledger",)) == [
        f"data/lore/ledger.toml: {key}: missing: every Species needs it (DATA-R103, DATA-R107)"
    ]


def _generator_fails_with(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], data_file: str, edit: Callable[[str], str], expected: str
) -> None:
    """DATA-R107 through the generator itself (DATA-R63): over a copy of data/ whose data/<data_file> has `edit`
    applied, the generator exits 1, names `expected`, and writes nothing."""
    shutil.copytree(REPO / "data", tmp_path / "data")
    path = tmp_path / "data" / data_file
    path.write_text(edit(path.read_text(encoding="utf-8")), encoding="utf-8")
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert expected in output
    assert not (tmp_path / "addons").exists()


def test_the_generator_fails_on_a_deleted_riddle_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R107 through the generator itself (DATA-R63): a copy of data/ with one riddle deleted writes nothing.
    def cut(text: str) -> str:
        riddle = re.search(r"^\[species\.6289\].*\n(?:.*\n)*?(riddle = .*\n)", text, flags=re.MULTILINE)
        assert riddle is not None
        return text[: riddle.start(1)] + text[riddle.end(1) :]

    expected = "data/lore/ledger.toml: species.6289.riddle: missing"
    _generator_fails_with(tmp_path, capsys, "lore/ledger.toml", cut, expected)


@pytest.mark.parametrize("species", sorted(_riddles()))
def test_no_riddle_holds_a_digit_or_a_zone_s_name(species: int) -> None:
    # DATA-R110: a riddle hints at a kind of place or time, never an exact zone, hour or skill. A zone is an
    # areas.csv row with ParentAreaID 0; names match as whole words, ignoring case.
    riddle = _riddles()[species]
    assert not re.search(r"\d", riddle), riddle
    named = [name for name in _zone_names() if re.search(rf"(?<!\w){re.escape(name)}(?!\w)", riddle, re.IGNORECASE)]
    assert named == [], riddle


def test_the_generator_fails_on_a_deleted_good_name_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R107 for the core lore ID, through the generator itself (DATA-R63): nothing is written.
    def cut(text: str) -> str:
        name = 'name = "Ripple"\n'
        assert name in text
        return text.replace(name, "")

    expected = "data/lore/core.toml: good.core.toaststyle.ripple.name: missing"
    _generator_fails_with(tmp_path, capsys, "lore/core.toml", cut, expected)


def test_the_manifest_lists_the_ledger_s_titles_and_bindings() -> None:
    # LED-R160, LED-R162 (its M4 part): [ledger.title] with a text for each of LED-R75's title IDs, only zonemaster
    # allowing {zone} (DATA-R108), and [ledger.binding] with a name and a description for each of LED-R110's goods.
    manifest = _layers().lore.manifest["ledger"]
    assert manifest["title"].fields == ("text",)
    assert list(manifest["title"].ids) == TITLES
    assert {id_: allowed for id_, allowed in manifest["title"].ids.items() if allowed} == {"zonemaster": {"zone"}}
    assert manifest["binding"].fields == ("name", "description")
    assert list(manifest["binding"].ids) == BINDINGS
    assert all(not allowed for allowed in manifest["binding"].ids.values())


def _ledger_text(key: str) -> str:
    return _layers().lore.files["ledger"][key].value


def test_the_ledger_s_lore_has_every_title_and_binding() -> None:
    # DATA-R107 passes (read_layers raises on any problem); LED-R160: a text for each of the 15 titles, a name and a
    # description for each of the 10 bindings.
    for title in TITLES:
        assert _ledger_text(f"title.{title}.text").strip()
    for binding in BINDINGS:
        assert _ledger_text(f"binding.{binding}.name").strip()
        assert _ledger_text(f"binding.{binding}.description").strip()


@pytest.mark.parametrize("title", TITLES)
def test_deleting_any_one_title_s_text_fails_the_lore_check_naming_its_key(title: str) -> None:
    # DATA-R107's missing: the manifest lists every title ID (DATA-R106, LED-R162).
    key = f"title.{title}.text"
    assert _without("ledger", key) == [
        f"data/lore/ledger.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


def test_zone_in_a_title_other_than_zonemaster_is_a_placeholder_problem() -> None:
    # DATA-R107's placeholder, DATA-R108: only zonemaster's manifest entry allows {zone}.
    def zoned(texts: dict[str, Text]) -> dict[str, Text]:
        level10 = texts["title.level10.text"]
        return texts | {level10.key: replace(level10, value="Warden of {zone}")}

    assert _problems_with("ledger", zoned) == [
        "data/lore/ledger.toml: title.level10.text: placeholder: { or } outside an allowed placeholder"
        " (manifest.toml allows none here) (DATA-R107, DATA-R108)"
    ]


def test_the_zonemaster_title_keeps_its_zone_placeholder() -> None:
    # DATA-R108, LED-R161: {zone} is filled with the zone's name at runtime.
    assert "{zone}" in _ledger_text("title.zonemaster.text")


@pytest.mark.parametrize("title", TITLES)
def test_no_title_is_master_angler_and_no_level_title_is_angler(title: str) -> None:
    # LED-R75: a title is never "Master Angler" (Forever's own Extravaganza title), and "Angler" is never a ladder
    # rung.
    text = _ledger_text(f"title.{title}.text")
    assert "master angler" not in text.lower()
    if title in LEVEL_TITLES:
        assert not re.search(r"\bangler\b", text, re.IGNORECASE), text


# HNT-R121: Hunts' seven goods, in its table's order: four notebook covers, then three tracker frames.
HUNT_GOODS = [
    "hunts.notebookcover.leather",
    "hunts.notebookcover.oilcloth",
    "hunts.notebookcover.tooled",
    "hunts.notebookcover.verdigris",
    "hunts.trackerframe.none",
    "hunts.trackerframe.inkwash",
    "hunts.trackerframe.waxseal",
]


def _hunts_text() -> dict[str, str]:
    """Every line of Hunts' lore by key: its goods' (data/lore/hunts.toml) and its Hunts' and sets' (DATA-R105)."""
    lore = _layers().lore
    return {key: text.value for key, text in (lore.files["hunts"] | lore.hunts).items()}


def test_the_manifest_lists_hunts_seven_goods() -> None:
    # HNT-R130, DATA-R106: [hunts.huntgood] with fields name and description and HNT-R121's seven good IDs, none with
    # a placeholder; huntgood is Hunts' own kind, as Core owns good (DATA-R102).
    manifest = _layers().lore.manifest["hunts"]
    assert sorted(manifest) == ["huntgood"]
    assert manifest["huntgood"].fields == ("name", "description")
    assert list(manifest["huntgood"].ids) == HUNT_GOODS
    assert all(not allowed for allowed in manifest["huntgood"].ids.values())


def test_hunts_lore_has_a_name_and_a_description_for_every_good() -> None:
    # DATA-R107 passes (read_layers raises on any problem), and HNT-R130: every good's name and description is lore.
    text = _hunts_text()
    for good in HUNT_GOODS:
        assert text[f"huntgood.{good}.name"].strip()
        assert text[f"huntgood.{good}.description"].strip()


@pytest.mark.parametrize("good", HUNT_GOODS)
def test_deleting_any_one_good_s_description_fails_the_hunts_lore_check_naming_its_key(good: str) -> None:
    # DATA-R107's missing, for the hunts lore ID: the manifest lists every good (DATA-R106, HNT-R130).
    key = f"huntgood.{good}.description"
    assert _without("hunts", key) == [
        f"data/lore/hunts.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


def test_every_v1_hunt_and_set_has_its_text() -> None:
    # HNT-R130, DATA-R105: a name for each of the 16 v1 Hunts, a name and a title for each of the 5 sets (hunts.md ›
    # Data), all passing the Hunts lore check (read_layers raises on any problem).
    hunts = _layers().hunts
    text = _hunts_text()
    assert len(hunts.hunts) == 16 and len(hunts.sets) == 5
    for hunt in hunts.hunts:
        assert text[f"hunt.{hunt.id}.name"].strip()
    for hunt_set in hunts.sets:
        assert text[f"set.{hunt_set.id}.name"].strip()
        assert text[f"set.{hunt_set.id}.title"].strip()


def test_sunday_showdown_s_note_says_it_is_the_extravaganza_and_needs_level_60() -> None:
    # hunts.md › Data: Sunday Showdown's set note says it's the Extravaganza and requires level 60.
    note = _hunts_text()["set.sunday_showdown.note"]
    assert "Extravaganza" in note
    assert re.search(r"\blevel 60\b", note), note


def test_the_wagers_set_s_note_calls_them_pagle_s_own_without_quoting_him() -> None:
    # hunts.md › Data: the set note says these are Pagle's own wagers (#183, restored in #184: Nat Pagle the angler,
    # VOICE.md's one exception to choice 12). DATA-R110: no words in Nat Pagle's mouth, so nothing is quoted.
    note = _hunts_text()["set.pagles_wagers.note"]
    assert "Pagle's own wagers" in note
    assert '"' not in note, note


@pytest.mark.parametrize("key", sorted(_hunts_text()))
def test_no_line_of_hunts_lore_names_the_addon_its_terms_or_shouts(key: str) -> None:
    # VOICE.md: "Not the addon talking" (choice 12): no Pagle and none of its capitalised terms; no "I" (choice 3);
    # no exclamation marks (choice 13); no | (WoW's escape codes). VOICE.md's one exception (#184): the wagers set's
    # note names Nat Pagle the angler, so Pagle is allowed there and nowhere else.
    text = _hunts_text()[key]
    pagle = "" if key == "set.pagles_wagers.note" else "Pagle|Pagle's|"
    terms = rf"\b({pagle}Hunts?|Ledger|Coins?|Sessions?|Notices?|Catch(es)?|Casts?|Angler|XP|I)\b"
    assert not re.search(terms, text), text
    assert "!" not in text and "|" not in text, text


SETS = ["round_the_clock", "turn_of_the_year", "sunday_showdown", "camp_hours", "pagles_wagers"]  # hunts.md › Data


@pytest.mark.parametrize("hunt_set", SETS)
def test_every_set_title_is_a_bare_epithet(hunt_set: str) -> None:
    # HNT-R22: a title reads after "Title:", "Earns the title" and on the nameplate; VOICE.md choice 6 (approved):
    # titles are bare epithets, capitalised, with no "the" or "of" in front; never "Master Angler" (LED-R75).
    title = _hunts_text()[f"set.{hunt_set}.title"]
    assert title[0].isupper(), title
    assert not re.match(r"(the|of)\b", title, re.IGNORECASE), title
    assert "master angler" not in title.lower()


def test_the_glyph_check_covers_a_hunt_s_name(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # CORE-R9, DATA-R107's glyph: hunts.toml's text is Pagle_Hunts' lore (DATA-R105), so a character the fonts draw
    # as a box fails the generator there too.
    expected = "data/hunts/hunts.toml: hunt.night_run.name: glyph: U+2605 outside CORE-R9's set"
    _generator_fails_with(tmp_path, capsys, "hunts/hunts.toml", _night_run_named("Night Run ★"), expected)


def _night_run_named(name: str) -> Callable[[str], str]:
    """An edit of hunts.toml that renames Night Run, its one name line."""

    def edit(text: str) -> str:
        assert text.count('name = "Night Run"\n') == 1
        return text.replace('name = "Night Run"\n', f'name = "{name}"\n')

    return edit


def test_the_generator_fails_on_a_29_code_point_hunt_name_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R105, DATA-R107 through the generator itself (DATA-R63): a copy of data/ with Night Run's name one code
    # point over the 28 writes nothing.
    expected = "data/hunts/hunts.toml: hunt.night_run.name: length: 29 code points"
    _generator_fails_with(tmp_path, capsys, "hunts/hunts.toml", _night_run_named("N" * 29), expected)


def test_renaming_a_hunt_changes_neither_its_hash_nor_the_hunt_list_fingerprint(tmp_path: Path) -> None:
    # DATA-R105, DATA-R94: a Hunt's text is out of its hash and the Hunt list's fingerprint, so a wording fix needs no
    # new Hunt and rebuilds nothing.
    shutil.copytree(REPO / "data", tmp_path / "data")
    hunts = tmp_path / "data" / "hunts" / "hunts.toml"
    text = hunts.read_text(encoding="utf-8")
    hunts.write_text(text.replace('name = "Night Run"\n', 'name = "Nightfall Run"\n'), encoding="utf-8")
    renamed = read_layers(tmp_path)
    assert renamed.lore.hunts["hunt.night_run.name"].value == "Nightfall Run"
    before, after = hunt_list_of(_layers()), hunt_list_of(renamed)
    assert after["fingerprint"] == before["fingerprint"]
    assert [hunt_hash(hunt) for hunt in after["hunts"]] == [hunt_hash(hunt) for hunt in before["hunts"]]
# Words that pin one zone through a landmark or a translated name, each with what it points to: the ones the M3
# reviews found in riddles (VOICE.md open choice 15). A word matches whole, ignoring case, plurals included.
LANDMARKS = {
    "red hills": "Redridge Mountains, its name translated",
    "gnoll": "Redridge's gnolls",
    "giant": "Feralas' giants",
    "centaur": "Desolace's centaur clans",
    "troll ruin": "Zul'Gurub",
    "drowned ruin": "Azshara's drowned ruins",
    "dam": "Loch Modan's dam",
    "cave": "the Wailing Caverns",
}


@pytest.mark.parametrize("species", sorted(_riddles()))
def test_no_riddle_pins_a_zone_by_a_landmark_or_a_translated_name(species: int) -> None:
    # DATA-R110: "never an exact zone", which a landmark or a zone's name in plain words breaks as surely as the
    # name itself.
    riddle = _riddles()[species]
    pinned = [
        f"{word} ({place})"
        for word, place in LANDMARKS.items()
        if re.search(rf"(?<!\w){re.escape(word)}s?(?!\w)", riddle, re.IGNORECASE)
    ]
    assert pinned == [], riddle


def _lines() -> dict[str, str]:
    # Every text in the batch, by its key ("species.13760.blurb").
    with LEDGER_TOML.open("rb") as handle:
        lore = tomllib.load(handle)
    return {
        f"{kind}.{lore_id}.{field}": text
        for kind, tables in lore.items()
        for lore_id, fields in tables.items()
        for field, text in fields.items()
    }


# Pagle's capitalised terms (CONTEXT.md), which lore never uses, even to start a sentence: it writes "fish", "catch",
# "angler" (VOICE.md › The voice, "Not the addon talking").
PAGLE_TERMS = ("Catch", "Catches", "XP", "Coin", "Coins", "Ledger", "Hunt", "Hunts", "Notice", "Notices", "Session")


def test_no_lore_line_uses_one_of_pagle_s_terms() -> None:
    # DATA-R110, VOICE.md: lore isn't the addon talking.
    found = [
        f"{key}: {text}"
        for key, text in sorted(_lines().items())
        if any(re.search(rf"(?<!\w){term}(?!\w)", text) for term in PAGLE_TERMS)
    ]
    assert found == []


def test_no_day_or_night_line_says_only() -> None:
    # #175: the day (06:00–24:00) and night (18:00–12:00) windows overlap by twelve hours, so a day fish also bites
    # after dark and a night fish in the morning; a line can't say one bites only by day or only at night. M4's titles
    # and bindings (LED-R75, LED-R110) name the Angler and the book, never when a fish bites, so they're left out
    # ("dark flecks" on Birch Bark is its colour).
    timed = re.compile(r"\b(sun|daylight|day|night|dark|dawn|dusk)\b", re.IGNORECASE)
    found = [
        f"{key}: {text}"
        for key, text in sorted(_lines().items())
        if not key.startswith(("title.", "binding."))
        and timed.search(text)
        and re.search(r"\bonly\b", text, re.IGNORECASE)
    ]
    assert found == []
