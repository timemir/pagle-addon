"""The repo's own lore: data/lore/ledger.toml, the Ledger's first batch (DATA-R111), with its lore check on
(DATA-R66, LED-R162)."""

import csv
import re
import shutil
import tomllib
from dataclasses import replace
from functools import cache
from pathlib import Path

import pytest

from pagle_data.cli import main
from pagle_data.errors import Problems
from pagle_data.generate import Layers, read_layers
from pagle_data.lore import catalogue_ids, check_lore

REPO = Path(__file__).resolve().parents[2]
LEDGER_TOML = REPO / "data" / "lore" / "ledger.toml"


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


def test_the_ledger_s_lore_check_is_on() -> None:
    # DATA-R66, LED-R162: the Ledger's lore check turns on in M3 with its first batch (DATA-R111).
    with (REPO / "data" / "checks.toml").open("rb") as handle:
        assert tomllib.load(handle)["lore"] == ["ledger"]


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
    # LED-R160, LED-R162 (its M3 part): [ledger.line] with fields ["text"] and the four line IDs; title and binding
    # enter in M4.
    manifest = _layers().lore.manifest["ledger"]
    assert sorted(manifest) == ["line"]
    assert manifest["line"].fields == ("text",)
    assert sorted(manifest["line"].ids) == ["uncaughtjunk", "uncaughtlegend", "uncaughttreasure", "unchartedwaters"]
    assert all(not allowed for allowed in manifest["line"].ids.values())  # no placeholder (DATA-R108)


@pytest.mark.parametrize("species", sorted(_riddles()))
def test_deleting_any_one_riddle_fails_the_lore_check_naming_its_key(species: int) -> None:
    # DATA-R107's missing: with the Ledger's check on, every Species needs a riddle (DATA-R103).
    layers = _layers()
    key = f"species.{species}.riddle"
    files = dict(layers.lore.files)
    files["ledger"] = {name: text for name, text in files["ledger"].items() if name != key}
    ids = catalogue_ids(layers.items, layers.item_layer.families)
    problems = Problems()
    check_lore(replace(layers.lore, files=files), ["ledger"], ids, problems)
    assert problems.found == [
        f"data/lore/ledger.toml: {key}: missing: every Species needs it (DATA-R103, DATA-R107)"
    ]


def test_the_generator_fails_on_a_deleted_riddle_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R107 through the generator itself (DATA-R63): a copy of data/ with one riddle deleted writes nothing.
    shutil.copytree(REPO / "data", tmp_path / "data")
    ledger = tmp_path / "data" / "lore" / "ledger.toml"
    text = ledger.read_text(encoding="utf-8")
    riddle = re.search(r"^\[species\.6289\].*\n(?:.*\n)*?(riddle = .*\n)", text, flags=re.MULTILINE)
    assert riddle is not None
    ledger.write_text(text[: riddle.start(1)] + text[riddle.end(1) :], encoding="utf-8")
    code = main([], tmp_path)
    out, err = capsys.readouterr()
    assert code == 1
    assert "data/lore/ledger.toml: species.6289.riddle: missing" in out + err
    assert not (tmp_path / "addons").exists()


@pytest.mark.parametrize("species", sorted(_riddles()))
def test_no_riddle_holds_a_digit_or_a_zone_s_name(species: int) -> None:
    # DATA-R110: a riddle hints at a kind of place or time, never an exact zone, hour or skill. A zone is an
    # areas.csv row with ParentAreaID 0; names match as whole words, ignoring case.
    riddle = _riddles()[species]
    assert not re.search(r"\d", riddle), riddle
    named = [name for name in _zone_names() if re.search(rf"(?<!\w){re.escape(name)}(?!\w)", riddle, re.IGNORECASE)]
    assert named == [], riddle


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
    # after dark and a night fish in the morning; a line can't say one bites only by day or only at night.
    timed = re.compile(r"\b(sun|daylight|day|night|dark|dawn|dusk)\b", re.IGNORECASE)
    found = [
        f"{key}: {text}"
        for key, text in sorted(_lines().items())
        if timed.search(text) and re.search(r"\bonly\b", text, re.IGNORECASE)
    ]
    assert found == []
