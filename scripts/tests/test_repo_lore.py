"""The repo's own lore (DATA-R111): data/lore/ledger.toml, the Ledger's first batch and its M4 titles and bindings,
and data/lore/core.toml, Core's goods, each with its lore check on (DATA-R66, LED-R162)."""

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


def test_the_ledger_s_and_core_s_lore_checks_are_on() -> None:
    # DATA-R66, LED-R162: the Ledger's lore check turns on in M3 with its first batch (DATA-R111); DATA-R107: Core's
    # in M4, with its goods.
    with (REPO / "data" / "checks.toml").open("rb") as handle:
        assert tomllib.load(handle)["lore"] == ["ledger", "core"]


def _without(lore_id: str, key: str) -> list[str]:
    """What check_lore finds over the repo's lore, with both checks on, once key is deleted from lore_id's file."""
    layers = _layers()
    files = dict(layers.lore.files)
    files[lore_id] = {name: text for name, text in files[lore_id].items() if name != key}
    ids = catalogue_ids(layers.items, layers.item_layer.families)
    problems = Problems()
    check_lore(replace(layers.lore, files=files), ["ledger", "core"], ids, problems)
    return problems.found


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
