"""The repo's own lore (DATA-R111): data/lore/ledger.toml, the Ledger's first batch and its M4 titles and bindings,
data/lore/core.toml, Core's goods, Hunts' M5 batch, its goods in data/lore/hunts.toml and its Hunts' and sets' text in
data/hunts/hunts.toml, Hunts' M8 batch, the event pool's text in data/hunts/events/ and the ladder titles in
data/lore/hunts.toml, Stats' M6 batch, its tracker frames in data/lore/stats.toml, and the Tackle Board's M7 batch,
its fly patterns, titles and tracker frames in data/lore/tackleboard.toml, each with its lore check on (DATA-R66,
LED-R162, HNT-R130, STA-R88, TKB-R130)."""

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
from pagle_data.errors import Problems
from pagle_data.events import event_hunt_hashes
from pagle_data.generate import Layers, event_list_of, hunt_list_of, read_layers
from pagle_data.hunts import hunt_hash
from pagle_data.lore import Text, catalogue_ids, check_lore

REPO = Path(__file__).resolve().parents[2]
LEDGER_TOML = REPO / "data" / "lore" / "ledger.toml"


# SHOP-R25: Core's goods, by slot, the Curio Shop expansion's after the first six; its crest slot's zone crests are the Ledger's (LED-R113).
CORE_GOODS = [
    "core.toaststyle.page",
    "core.toaststyle.ripple",
    "core.toaststyle.lanternglow",
    "core.soundset.driftwood",
    "core.soundset.gilded",
    "core.crest.plain",
    "core.toaststyle.ship",
    "core.toaststyle.birch",
    "core.toaststyle.tidepool",
    "core.toaststyle.chart",
    "core.toaststyle.frost",
    "core.toaststyle.goblin",
    "core.toaststyle.kelp",
    "core.toaststyle.moon",
    "core.toaststyle.leaf",
    "core.toaststyle.bottle",
    "core.toaststyle.rune",
    "core.toaststyle.folio",
    "core.soundset.rain",
    "core.soundset.marimba",
    "core.soundset.shipbell",
    "core.soundset.kalimba",
    "core.soundset.musicbox",
    "core.soundset.glass",
    "core.soundset.steelpan",
    "core.soundset.dulcimer",
    "core.soundset.frost",
    "core.soundset.harp",
    "core.soundset.gizmo",
    "core.soundset.wardrums",
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
    "complete.varieties",
]
# DATA-R107: every lore check, built and on by M7.
ALL_CHECKS = ["ledger", "core", "hunts", "stats", "tackleboard"]
# LED-R113: the zone crests without their ledger.crest. prefix, in the manifest's order.
ZONE_CRESTS = [
    "alterac",
    "arathi",
    "badlands",
    "blackrock",
    "blastedlands",
    "burningsteppes",
    "deadwind",
    "dunmorogh",
    "duskwood",
    "easternplague",
    "elwynn",
    "hillsbrad",
    "hinterlands",
    "ironforge",
    "lochmodan",
    "lordamere",
    "redridge",
    "riverglades",
    "searinggorge",
    "silverpine",
    "stormwind",
    "stranglethorn",
    "swampofsorrows",
    "tirisfal",
    "undercity",
    "westernplague",
    "westfall",
    "wetlands",
    "ashenvale",
    "azshara",
    "barrens",
    "darkshore",
    "darnassus",
    "desolace",
    "durotar",
    "dustwallow",
    "felwood",
    "feralas",
    "moonglade",
    "hyjal",
    "mulgore",
    "orgrimmar",
    "shendralas",
    "silithus",
    "stonetalon",
    "tanaris",
    "teldrassil",
    "thousandneedles",
    "thunderbluff",
    "ungoro",
    "veiledsea",
    "winterspring",
    "zephras",
]
BINDINGS = [
    "field",
    "level10",
    "level20",
    "level30",
    "level40",
    "level50",
    "level60",
    "birch",
    "buckram",
    "sharkskin",
    "chartlinen",
    "sailcloth",
    "oilskin",
    "moss",
    "driftwood",
    "eelskin",
    "kodo",
    "frosthide",
    "netcork",
    "copper",
    "velvet",
    "turtle",
    "morocco",
    "coral",
    "pearl",
    "legend",
    "monster",
    "abyssal",
    "keeper",
    "iridescent",
]


def _replacing(old: str, new: str) -> Callable[[str], str]:
    """An edit that replaces `old`, which the text must hold exactly once, with `new`."""

    def edit(text: str) -> str:
        assert text.count(old) == 1, old
        return text.replace(old, new)

    return edit


def _generator_fails_on(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], path: str, edit: Callable[[str], str], problem: str
) -> None:
    """DATA-R63: the generator run on a copy of data/ whose file `path` (from the repo's root) `edit` changed exits 1,
    names `problem` and writes nothing."""
    shutil.copytree(REPO / "data", tmp_path / "data")
    changed = tmp_path / path
    changed.write_text(edit(changed.read_text(encoding="utf-8")), encoding="utf-8")
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert problem in output
    assert not (tmp_path / "addons").exists()


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


def test_every_lore_check_is_on() -> None:
    # DATA-R66, LED-R162: the Ledger's lore check turns on in M3 with its first batch (DATA-R111); DATA-R107: Core's
    # in M4, with its goods; HNT-R130: Hunts' in M5, after Core's; DATA-R107, STA-R88: Stats' in M6, when it first
    # registers its goods, after Hunts'; TKB-R130: the Tackle Board's in M7, with its batch, after Stats'.
    with (REPO / "data" / "checks.toml").open("rb") as handle:
        assert tomllib.load(handle)["lore"] == ["ledger", "core", "hunts", "stats", "tackleboard"]


def _problems_with(
    lore_id: str, edit: Callable[[dict[str, Text]], dict[str, Text]], checks: tuple[str, ...] = tuple(ALL_CHECKS)
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


def _without(lore_id: str, key: str, checks: tuple[str, ...] = tuple(ALL_CHECKS)) -> list[str]:
    """_problems_with key deleted from lore_id's texts."""
    return _problems_with(lore_id, lambda texts: {name: text for name, text in texts.items() if name != key}, checks)


def test_the_manifest_lists_core_s_goods_then_its_fish_crests() -> None:
    # DATA-R106, SHOP-R25: [core.good] with fields name and description and Core's thirty good IDs, none with a
    # placeholder, then the fish crests (VAR-R12), each allowing {fish} (DATA-R108); [core.variety] is the varieties'
    # (test_repo_varieties.py).
    manifest = _layers().lore.manifest["core"]
    assert sorted(manifest) == ["good", "variety"]
    assert manifest["good"].fields == ("name", "description")
    ids = list(manifest["good"].ids)
    assert ids[: len(CORE_GOODS)] == CORE_GOODS
    assert all(id_.startswith("core.crest.fish.") for id_ in ids[len(CORE_GOODS) :])
    assert all(not manifest["good"].ids[good] for good in CORE_GOODS)


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
    assert sorted(manifest) == ["binding", "crest", "ledgergood", "line", "title"]
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


def test_the_generator_fails_on_a_deleted_riddle_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R107 through the generator itself (DATA-R63): a copy of data/ with one riddle deleted writes nothing.
    def without_riddle(text: str) -> str:
        riddle = re.search(r"^\[species\.6289\].*\n(?:.*\n)*?(riddle = .*\n)", text, flags=re.MULTILINE)
        assert riddle is not None
        return text[: riddle.start(1)] + text[riddle.end(1) :]

    _generator_fails_on(
        tmp_path, capsys, "data/lore/ledger.toml", without_riddle, "data/lore/ledger.toml: species.6289.riddle: missing"
    )


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
    _generator_fails_on(
        tmp_path,
        capsys,
        "data/lore/core.toml",
        _replacing('name = "Ripple"\n', ""),
        "data/lore/core.toml: good.core.toaststyle.ripple.name: missing",
    )


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
    # DATA-R107 passes (read_layers raises on any problem); LED-R160: a text for each of the 16 titles, a name and a
    # description for each of the 10 bindings.
    for title in TITLES:
        assert _ledger_text(f"title.{title}.text").strip()
    for binding in BINDINGS:
        assert _ledger_text(f"binding.{binding}.name").strip()
        assert _ledger_text(f"binding.{binding}.description").strip()


def test_the_manifest_lists_the_ledger_s_fifty_three_zone_crests() -> None:
    # DATA-R106, LED-R113, LED-R162: [ledger.crest] with a name and a description for each zone crest, none with a
    # placeholder, and the lore has both for each (DATA-R107 passes: read_layers raises on any problem).
    manifest = _layers().lore.manifest["ledger"]
    assert manifest["crest"].fields == ("name", "description")
    assert list(manifest["crest"].ids) == ZONE_CRESTS
    assert all(not allowed for allowed in manifest["crest"].ids.values())
    for crest in ZONE_CRESTS:
        assert _ledger_text(f"crest.{crest}.name").strip()
        assert _ledger_text(f"crest.{crest}.description").strip()


@pytest.mark.parametrize("crest", ["elwynn", "zephras"])
def test_deleting_a_zone_crest_s_name_fails_the_lore_check_naming_its_key(crest: str) -> None:
    # DATA-R107's missing: the manifest lists every zone crest (DATA-R106, LED-R113).
    key = f"crest.{crest}.name"
    assert _without("ledger", key) == [
        f"data/lore/ledger.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


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
    "hunts.soundset.nightwatch",
    "hunts.notebookcover.canvas",
    "hunts.notebookcover.kraft",
    "hunts.notebookcover.tartan",
    "hunts.notebookcover.maplinen",
    "hunts.notebookcover.planks",
    "hunts.notebookcover.snakeskin",
    "hunts.notebookcover.shagreen",
    "hunts.notebookcover.lacquer",
    "hunts.notebookcover.bone",
    "hunts.notebookcover.brasscase",
    "hunts.notebookcover.scrimshaw",
    "hunts.notebookcover.trophycase",
    "hunts.notebookcover.pathfinder",
    "hunts.notebookcover.fiveseal",
    "hunts.notebookcover.wagersilk",
    "hunts.trackerframe.slate",
    "hunts.trackerframe.mapscrap",
    "hunts.trackerframe.bounty",
    "hunts.trackerframe.spyglass",
    "hunts.trackerframe.wagerribbon",
]


def _event_text() -> dict[str, str]:
    """Every line of the event pool's lore by key (DATA-R97): each event's name and note and its Hunts' names."""
    return {key: text.value for texts in _layers().lore.events.values() for key, text in texts.items()}


def _hunts_text() -> dict[str, str]:
    """Every line of Hunts' lore by key: its goods' and ladder titles (data/lore/hunts.toml), its Hunts' and sets'
    (DATA-R105) and its events' (DATA-R97)."""
    lore = _layers().lore
    return {key: text.value for key, text in (lore.files["hunts"] | lore.hunts).items()} | _event_text()


def test_the_manifest_lists_hunts_seven_goods() -> None:
    # HNT-R130, DATA-R106: [hunts.huntgood] with fields name and description and HNT-R121's seven good IDs, none with
    # a placeholder; huntgood is Hunts' own kind, as Core owns good (DATA-R102).
    manifest = _layers().lore.manifest["hunts"]
    assert sorted(manifest) == ["huntgood", "ladder"]
    assert manifest["huntgood"].fields == ("name", "description")
    assert list(manifest["huntgood"].ids) == HUNT_GOODS
    assert all(not allowed for allowed in manifest["huntgood"].ids.values())


LADDER_STEPS = ["25", "50", "100"]  # hunts.md › Tunables, Ladder steps (HNT-R148)


def test_the_manifest_lists_the_ladder_titles_at_25_50_and_100_and_bookmakers_bane_is_25_s() -> None:
    # HNT-R130, HNT-R148, DATA-R106: [hunts.ladder] with fields title and IDs 25, 50 and 100 (50 and 100 from the
    # pool's lore batch, #307), none with a placeholder, and 25's title is "Bookmaker's Bane".
    ladder = _layers().lore.manifest["hunts"]["ladder"]
    assert ladder.fields == ("title",) and list(ladder.ids) == LADDER_STEPS
    assert all(not allowed for allowed in ladder.ids.values())
    assert _hunts_text()["ladder.25.title"] == "Bookmaker's Bane"


@pytest.mark.parametrize("step", LADDER_STEPS)
def test_deleting_any_one_ladder_title_fails_the_hunts_lore_check_naming_its_key(step: str) -> None:
    # DATA-R107's missing, for the hunts lore ID: the manifest lists every ladder step (DATA-R106, HNT-R130).
    key = f"ladder.{step}.title"
    assert _without("hunts", key) == [
        f"data/lore/hunts.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


def test_every_ladder_title_is_its_own_bare_epithet() -> None:
    # HNT-R148: a title the Angler signs with, earned once at its step, so no two share a text; VOICE.md choice 6
    # (approved): bare epithets, capitalised, with no "the" or "of" in front; never "Master Angler" (LED-R75).
    titles = [_hunts_text()[f"ladder.{step}.title"] for step in LADDER_STEPS]
    assert len(set(titles)) == len(titles)
    for title in titles:
        assert title[0].isupper(), title
        assert not re.match(r"(the|of)\b", title, re.IGNORECASE), title
        assert "master angler" not in title.lower()


def _ladder_title(step: str, value: str) -> Callable[[dict[str, Text]], dict[str, Text]]:
    """An edit to the hunts lore file's texts that sets ladder.<step>.title to value, adding it when it isn't there."""
    return lambda texts: texts | {f"ladder.{step}.title": Text("ladder", step, "title", value)}


@pytest.mark.parametrize(
    ("step", "value", "problem"),
    [
        ("100", "B" * 33, "ladder.100.title: length: 33 code points, over title's limit of 32 (DATA-R107)"),
        ("50", "B" * 32, None),
        (
            "50",
            "Bookmaker's {zone}",
            "ladder.50.title: placeholder: { or } outside an allowed placeholder (manifest.toml allows none here)"
            " (DATA-R107, DATA-R108)",
        ),
        (
            "75",
            "Bookmaker's Bother",
            "ladder.75.title: orphan: 75 isn't in manifest.toml's [hunts.ladder] ids (DATA-R106, DATA-R107)",
        ),
    ],
    ids=["a 33-code-point title", "a 32-code-point title", "a { in a title", "a step the manifest doesn't list"],
)
def test_the_hunts_lore_check_judges_a_ladder_title(step: str, value: str, problem: str | None) -> None:
    # DATA-R107 on [ladder."<n>"] in data/lore/hunts.toml: a title has the title limit of 32 code points (Tunables ›
    # Lore limits), allows no placeholder (the manifest gives it none, DATA-R108), and a step manifest.toml doesn't
    # list is an orphan (DATA-R106).
    found = _problems_with("hunts", _ladder_title(step, value))
    assert found == ([] if problem is None else [f"data/lore/hunts.toml: {problem}"])


# The 1.0 event pool (hunts.md › Data): every event in data/hunts/events/, read through the generator's layers.
def _events() -> list[dict[str, object]]:
    events = event_list_of(_layers())["events"]
    assert isinstance(events, list)
    return events


def _event_hunt_ids(event: dict[str, object]) -> list[str]:
    hunts = event["hunts"]
    assert isinstance(hunts, list)
    return [str(hunt["id"]) for hunt in hunts]


def test_every_pool_event_has_a_name_a_note_and_named_hunts_and_nothing_else() -> None:
    # HNT-R130, DATA-R97: each of the pool's 24 events has its name and note, and each of its Hunts its name, in its
    # own file, all passing the Hunts lore check (read_layers raises on any problem); the M8 batch (DATA-R111, #307).
    events = _events()
    assert len(events) == 24
    keys = set()
    for event in events:
        keys |= {f"event.{event['id']}.name", f"event.{event['id']}.note"}
        keys |= {f"hunt.{hunt}.name" for hunt in _event_hunt_ids(event)}
    text = _event_text()
    assert set(text) == keys
    assert all(text[key].strip() for key in keys)


def test_no_two_event_hunts_share_a_name() -> None:
    # HNT-R86: an event Hunt's first mark is announced as "{Hunt name} · first mark" with no event beside it, and the
    # tracker shows "{Hunt}: {count} / {next threshold}" (HNT-R175), so each name tells its Hunt apart on its own.
    names = [_event_text()[f"hunt.{hunt}.name"] for event in _events() for hunt in _event_hunt_ids(event)]
    assert len(set(names)) == len(names)


# HNT-R27: Pagle Wagers is a bet between anglers and Nat Pagle, never odds, a fish being due or a chance to win
# (#284); "only" with a time word would also misstate a window (#175). Whole words, ignoring case.
NO_ODDS = r"\b(odds|due|overdue|chances?|likely|luck|lucky|sure|certain|guaranteed?|bound to|long shot|only)\b"


@pytest.mark.parametrize("key", sorted(_event_text()))
def test_no_line_of_event_lore_claims_odds_a_due_fish_or_a_chance(key: str) -> None:
    text = _event_text()[key]
    assert not re.search(NO_ODDS, text, re.IGNORECASE), text


def _event_file(event_id: str) -> str:
    return f"data/hunts/events/{event_id}.toml"


def test_the_generator_fails_on_a_deleted_event_note_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R97, DATA-R63: an event's note is a key its file must have (Data: data/hunts/events/<event-id>.toml keys),
    # so a copy of data/ with one deleted writes nothing.
    note = _event_text()["event.feralas_redgill.note"]
    _generator_fails_on(
        tmp_path,
        capsys,
        _event_file("feralas_redgill"),
        _replacing(f'note = "{note}"\n', ""),
        f"{_event_file('feralas_redgill')}: event: missing key 'note'",
    )


def test_the_generator_fails_on_a_29_code_point_event_hunt_name_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, DATA-R107 through the generator itself (DATA-R63): an event Hunt's name has the name limit of 28
    # code points (Tunables › Lore limits).
    name = _event_text()["hunt.feralas_redgill_trout.name"]
    _generator_fails_on(
        tmp_path,
        capsys,
        _event_file("feralas_redgill"),
        _replacing(f'name = "{name}"\n', f'name = "{"T" * 29}"\n'),
        f"{_event_file('feralas_redgill')}: hunt.feralas_redgill_trout.name: length: 29 code points, over name's"
        " limit of 28 (DATA-R107)",
    )


def test_the_generator_fails_on_a_brace_in_an_event_note_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, DATA-R107's placeholder: an event's text allows no { or } at all, {zone} included (DATA-R105).
    note = _event_text()["event.feralas_redgill.note"]
    _generator_fails_on(
        tmp_path,
        capsys,
        _event_file("feralas_redgill"),
        _replacing(f'note = "{note}"\n', 'note = "Rain over {zone}."\n'),
        f"{_event_file('feralas_redgill')}: event.feralas_redgill.note: placeholder: "
        "{ or } in a Hunt's or set's text, which allows none (DATA-R105, DATA-R107)",
    )


def test_renaming_an_event_and_its_hunts_changes_no_hash_and_not_the_event_list_fingerprint(tmp_path: Path) -> None:
    # DATA-R109, DATA-R98, DATA-R94: lore is never in an event Hunt's hash or the event list's fingerprint, so a
    # wording fix rebuilds nothing.
    shutil.copytree(REPO / "data", tmp_path / "data")
    path = tmp_path / _event_file("feralas_redgill")
    text = path.read_text(encoding="utf-8")
    keys = ("event.feralas_redgill.name", "event.feralas_redgill.note", "hunt.feralas_redgill_trout.name")
    for n, key in enumerate(keys):
        old = _event_text()[key]
        assert text.count(f'"{old}"') == 1, old
        text = text.replace(f'"{old}"', f'"Renamed {n}"')
    path.write_text(text, encoding="utf-8")
    renamed = read_layers(tmp_path)
    texts = renamed.lore.events[_event_file("feralas_redgill")]
    assert [texts[key].value for key in keys] == ["Renamed 0", "Renamed 1", "Renamed 2"]
    before, after = event_list_of(_layers()), event_list_of(renamed)
    assert after["fingerprint"] == before["fingerprint"]
    assert event_hunt_hashes(after) == event_hunt_hashes(before)


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
    # HNT-R130, DATA-R105: a name for each of the 12 Standing Hunts, a name and a title for each of the 4 sets
    # (hunts.md › Data), all passing the Hunts lore check (read_layers raises on any problem).
    hunts = _layers().hunts
    text = _hunts_text()
    assert len(hunts.hunts) == 12 and len(hunts.sets) == 4
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


@pytest.mark.parametrize("key", sorted(_hunts_text()))
def test_no_line_of_hunts_lore_names_the_addon_its_terms_or_shouts(key: str) -> None:
    # VOICE.md: "Not the addon talking" (choice 12): no Pagle and none of its capitalised terms; no "I" (choice 3);
    # no exclamation marks (choice 13); no | (WoW's escape codes).
    text = _hunts_text()[key]
    terms = r"\b(Pagle|Pagle's|Hunts?|Ledger|Coins?|Sessions?|Notices?|Catch(es)?|Casts?|Angler|XP|I)\b"
    assert not re.search(terms, text), text
    assert "!" not in text and "|" not in text, text


SETS = ["round_the_clock", "turn_of_the_year", "sunday_showdown", "camp_hours"]  # hunts.md › Data


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
    _generator_fails_on(
        tmp_path,
        capsys,
        "data/hunts/hunts.toml",
        _replacing('name = "Night Run"\n', 'name = "Night Run ★"\n'),
        "data/hunts/hunts.toml: hunt.night_run.name: glyph: U+2605 outside CORE-R9's set",
    )


def test_the_generator_fails_on_a_29_code_point_hunt_name_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R105, DATA-R107 through the generator itself (DATA-R63): a copy of data/ with Night Run's name one code
    # point over the 28 writes nothing.
    _generator_fails_on(
        tmp_path,
        capsys,
        "data/hunts/hunts.toml",
        _replacing('name = "Night Run"\n', f'name = "{"N" * 29}"\n'),
        "data/hunts/hunts.toml: hunt.night_run.name: length: 29 code points",
    )


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


# STA-R88: Stats' three goods, in its table's order: its tracker frames.
STATS_GOODS = [
    "stats.trackerframe.none",
    "stats.trackerframe.logbook",
    "stats.trackerframe.brass",
    "stats.trackerframe.greenbar",
    "stats.trackerframe.chalkboard",
    "stats.trackerframe.tidegauge",
    "stats.trackerframe.abacus",
    "stats.trackerframe.astrolabe",
]


def _stats_text() -> dict[str, str]:
    """Every line of Stats' lore by key (data/lore/stats.toml)."""
    return {key: text.value for key, text in _layers().lore.files["stats"].items()}


def test_the_manifest_lists_stats_three_goods() -> None:
    # STA-R88, DATA-R106: [stats.statsgood] with fields name and description and STA-R88's three good IDs, none with a
    # placeholder; statsgood is Stats' own kind, as Core owns good (DATA-R102).
    manifest = _layers().lore.manifest["stats"]
    assert sorted(manifest) == ["statsgood"]
    assert manifest["statsgood"].fields == ("name", "description")
    assert list(manifest["statsgood"].ids) == STATS_GOODS
    assert all(not allowed for allowed in manifest["statsgood"].ids.values())


def test_stats_lore_is_a_name_and_a_description_for_every_good_and_nothing_else() -> None:
    # DATA-R107 passes (read_layers raises on any problem), and STA-R88: every good's name and description is lore,
    # the M6 batch's only lines (DATA-R111).
    text = _stats_text()
    keys = {f"statsgood.{good}.{field}" for good in STATS_GOODS for field in ("name", "description")}
    assert set(text) == keys
    assert all(text[key].strip() for key in keys)


@pytest.mark.parametrize("good", STATS_GOODS)
def test_deleting_any_one_good_s_description_fails_the_stats_lore_check_naming_its_key(good: str) -> None:
    # DATA-R107's missing, for the stats lore ID: the manifest lists every good (DATA-R106, STA-R88).
    key = f"statsgood.{good}.description"
    assert _without("stats", key) == [
        f"data/lore/stats.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


@pytest.mark.parametrize("key", sorted(_stats_text()))
def test_no_line_of_stats_lore_names_the_shop_the_addon_its_terms_or_shouts(key: str) -> None:
    # #210: a description says what the frame looks like, never "shop", "Stats" or the addon, since the shop prints
    # the slot and the Module itself. VOICE.md: "Not the addon talking" (choice 12): no Pagle and none of its
    # capitalised terms, nor "ledger" in any case (the Module's name); no "I" (choice 3); no exclamation marks
    # (choice 13); no | (WoW's escape codes).
    text = _stats_text()[key]
    terms = r"\b(Pagle|Pagle's|Stats|Hunts?|Coins?|Sessions?|Notices?|Catch(es)?|Casts?|Angler|XP|I)\b"
    assert not re.search(terms, text), text
    assert not re.search(r"\b(shop|curio|ledger)\b", text, re.IGNORECASE), text
    assert "!" not in text and "|" not in text, text


def test_the_generator_fails_on_a_29_code_point_frame_name_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R107 for the stats lore ID, through the generator itself (DATA-R63): a copy of data/ with the Logbook's
    # name one code point over the 28 (Tunables › Lore limits) writes nothing.
    name = _stats_text()["statsgood.stats.trackerframe.logbook.name"]
    _generator_fails_on(
        tmp_path,
        capsys,
        "data/lore/stats.toml",
        _replacing(f'name = "{name}"\n', f'name = "{"L" * 29}"\n'),
        "data/lore/stats.toml: statsgood.stats.trackerframe.logbook.name: length: 29 code points",
    )


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
        if not key.startswith(("title.", "binding.", "crest."))
        and timed.search(text)
        and re.search(r"\bonly\b", text, re.IGNORECASE)
    ]
    assert found == []
# tackle-board.md › Data: the Fly Box's 30 patterns in pattern order (TKB-R62: 24 common, then 6 rare), the 8 titles in
# their table's order, and the three tracker frames (TKB-R125).
FLY_PATTERNS = [
    "murloc_nymph",
    "westfall_wheatwing",
    "goldshire_gnat",
    "duskwood_shadow",
    "redridge_ember",
    "barrens_dun",
    "mudsnout_woolly",
    "gnomish_whirligig",
    "tarnished_spoon",
    "ashenvale_olive",
    "kodo_hair_caddis",
    "elwynn_royal",
    "swamp_midge",
    "raptor_quill",
    "silverpine_spinner",
    "lakeshire_coachman",
    "bloodsail_streamer",
    "booty_bay_bucktail",
    "desolace_drifter",
    "grimtotem_hackle",
    "needles_ant",
    "feralas_fern",
    "tanaris_sandfly",
    "darkshore_dun",
    "nats_golden_doctor",
    "kraken_ink_streamer",
    "phoenix_hackle",
    "moonwell_silverwing",
    "thunderhead_tiger",
    "deepwater_duchess",
]
BOARD_TITLES = [
    "tally_25",
    "tally_100",
    "tally_500",
    "campfire_7",
    "campfire_30",
    "campfire_100",
    "campfire_365",
    "flybox",
]
BOARD_GOODS = [
    "tackleboard.trackerframe.none",
    "tackleboard.trackerframe.corkboard",
    "tackleboard.trackerframe.driftwood",
    "tackleboard.toaststyle.ember",
    "tackleboard.trackerframe.net",
    "tackleboard.trackerframe.bamboo",
    "tackleboard.trackerframe.tin",
    "tackleboard.trackerframe.bobber",
    "tackleboard.trackerframe.embers",
]
BOARD_KEYS = (
    [f"fly.{pattern}.name" for pattern in FLY_PATTERNS]
    + [f"boardtitle.{title}.text" for title in BOARD_TITLES]
    + [f"boardgood.{good}.{field}" for good in BOARD_GOODS for field in ("name", "description")]
)


def _board_text() -> dict[str, str]:
    """Every line of the Tackle Board's lore by key (data/lore/tackleboard.toml)."""
    return {key: text.value for key, text in _layers().lore.files["tackleboard"].items()}


def test_the_manifest_lists_the_tackle_board_s_patterns_titles_and_goods() -> None:
    # TKB-R130, DATA-R106: [tackleboard.fly] (name), [tackleboard.boardtitle] (text) and [tackleboard.boardgood] (name
    # and description), with tackle-board.md › Data's IDs in its order, none with a placeholder.
    manifest = _layers().lore.manifest["tackleboard"]
    assert sorted(manifest) == ["boardgood", "boardtitle", "fly"]
    assert manifest["fly"].fields == ("name",)
    assert manifest["boardtitle"].fields == ("text",)
    assert manifest["boardgood"].fields == ("name", "description")
    assert list(manifest["fly"].ids) == FLY_PATTERNS
    assert list(manifest["boardtitle"].ids) == BOARD_TITLES
    assert list(manifest["boardgood"].ids) == BOARD_GOODS
    assert all(not allowed for kind in manifest.values() for allowed in kind.ids.values())


def test_the_tackle_board_s_lore_is_its_56_lines_and_nothing_else() -> None:
    # DATA-R107 passes (read_layers raises on any problem), and TKB-R130: every pattern's name, title's text and good's
    # name and description, the M7 batch's 44 lines and the Curio Shop expansion's 12 (DATA-R111).
    text = _board_text()
    assert len(BOARD_KEYS) == 56
    assert set(text) == set(BOARD_KEYS)
    assert all(text[key].strip() for key in BOARD_KEYS)


def test_every_fly_name_and_every_title_is_its_own() -> None:
    # TKB-R62: each pattern is tied once and named in its moment, and each title is earned once (TKB-R64), so no two
    # share a name.
    text = _board_text()
    flies = [text[f"fly.{pattern}.name"] for pattern in FLY_PATTERNS]
    titles = [text[f"boardtitle.{title}.text"] for title in BOARD_TITLES]
    assert len(set(flies)) == len(flies)
    assert len(set(titles)) == len(titles)


@pytest.mark.parametrize("key", ["fly.murloc_nymph.name", "boardtitle.flybox.text", f"boardgood.{BOARD_GOODS[1]}.name"])
def test_deleting_a_tackle_board_line_fails_its_lore_check_naming_its_key(key: str) -> None:
    # DATA-R107's missing, for the tackleboard lore ID: the manifest lists every pattern, title and good (DATA-R106).
    assert _without("tackleboard", key) == [
        f"data/lore/tackleboard.toml: {key}: missing: manifest.toml lists it (DATA-R106, DATA-R107)"
    ]


@pytest.mark.parametrize("title", BOARD_TITLES)
def test_every_board_title_is_a_bare_epithet(title: str) -> None:
    # "Title: {title}" (TKB-R86) and the Campfire card read a title bare; VOICE.md choice 6 (approved): bare epithets,
    # capitalised, with no "the" or "of" in front; never "Master Angler" or plain "Angler" (LED-R75).
    text = _board_text()[f"boardtitle.{title}.text"]
    assert text[0].isupper(), text
    assert not re.match(r"(the|of)\b", text, re.IGNORECASE), text
    assert "master angler" not in text.lower() and text.lower() != "angler"


@pytest.mark.parametrize("key", BOARD_KEYS)
def test_no_line_of_tackle_board_lore_names_the_addon_its_terms_or_shouts(key: str) -> None:
    # #237: a frame's description says what it looks like, never "shop", "Tackle Board" or the addon. VOICE.md: "Not
    # the addon talking" (choice 12): no Pagle and none of its capitalised terms (the board's own among them: Notice,
    # Expedition, Campfire, Kindling, Fly Box), nor "board" or "ledger" in any case; no "I" (choice 3); no
    # exclamation marks (choice 13); no | (WoW's escape codes).
    text = _board_text()[key]
    terms = (
        r"\b(Pagle|Pagle's|Stats|Hunts?|Coins?|Sessions?|Notices?|Expeditions?|Campfire|Kindling|Catch(es)?|Casts?"
        r"|Angler|XP|I)\b"
    )
    assert not re.search(terms, text), text
    assert not re.search(r"\b(shop|curio|ledger|board|fly box|tracker)\b", text, re.IGNORECASE), text
    assert "!" not in text and "|" not in text, text


def test_the_generator_fails_on_a_29_code_point_fly_name_and_names_the_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R107 for the tackleboard lore ID, through the generator itself (DATA-R63): a copy of data/ with the Murloc
    # Nymph's name one code point over the 28 (Tunables › Lore limits) writes nothing.
    name = _board_text()["fly.murloc_nymph.name"]
    _generator_fails_on(
        tmp_path,
        capsys,
        "data/lore/tackleboard.toml",
        _replacing(f'name = "{name}"\n', f'name = "{"M" * 29}"\n'),
        "data/lore/tackleboard.toml: fly.murloc_nymph.name: length: 29 code points",
    )


LEDGER_GOODS = [
    "ledger.toaststyle.legend",
    "ledger.toaststyle.prestige",
    "ledger.soundset.concertina",
    "ledger.soundset.choir",
]


def test_the_manifest_lists_the_ledger_s_earned_goods_in_core_s_slots() -> None:
    # DATA-R106, LED-R117: [ledger.ledgergood] with a name and a description for each of the Ledger's earned toast
    # styles and sound sets, and the lore has both (DATA-R107 passes: read_layers raises on any problem).
    manifest = _layers().lore.manifest["ledger"]
    assert manifest["ledgergood"].fields == ("name", "description")
    assert list(manifest["ledgergood"].ids) == LEDGER_GOODS
    for good in LEDGER_GOODS:
        assert _ledger_text(f"ledgergood.{good}.name").strip()
        assert _ledger_text(f"ledgergood.{good}.description").strip()
