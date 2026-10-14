"""The Hunt list (DATA-R85-R94) over small fixture data/ trees: data/hunts/hunts.toml, its checks, the fixed and
generated classes, HuntList.lua, each Hunt's hash and the Hunt list's fingerprint."""

import hashlib
from pathlib import Path

import pytest

from cli_fixture import run
from hunts_fixture import (
    DB2_ITEMS,
    EVENTS,
    FINGERPRINT,
    FINGERPRINT_JSON,
    HUNT_LIST,
    HUNT_LIST_LUA,
    HUNTS,
    ITEMS,
    LISTS,
    NIGHT_RUN_HASH,
    ODDITY_HASH,
    write_hunts,
)
from pagle_data.generate import CATALOGUE_LUA, hunt_list_of, read_layers
from pagle_data.hunts import HuntList, hunt_hash
from test_item_records import write_tree as write_item_tree


def write_tree(root: Path, hunts: str = HUNTS, items: str = ITEMS) -> Path:
    write_item_tree(root, items, DB2_ITEMS)
    forever = root / "data" / "forever"
    (forever / "events.toml").write_text(EVENTS, encoding="utf-8")
    (forever / "lists.toml").write_text(LISTS, encoding="utf-8")
    write_hunts(root, hunts)
    return root


def _hunt_list(root: Path) -> HuntList:
    return hunt_list_of(read_layers(root))


def test_the_fixture_list_emits_data_r93_s_shape_in_file_order(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R93: ns.huntList = { fingerprint, sets, hunts, classes }, sets and Hunts in file order, no lore (DATA-R105);
    # DATA-R87: since and retired as server times; DATA-R86: the imposed Hunt's conditions as the same Lua spec;
    # DATA-R75: written to addons/Pagle_Hunts/data/HuntList.lua, with Core's guard (CORE-R11).
    write_tree(tmp_path)
    code, output = run(tmp_path, capsys)
    assert code == 0, output
    assert (tmp_path / HUNT_LIST_LUA).read_text(encoding="utf-8") == HUNT_LIST


def test_no_lore_is_in_hunt_list_lua(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R93, DATA-R105: names, titles and notes stay out of HuntList.lua (ticket #183 emits them into Lore.lua).
    write_tree(tmp_path)
    assert run(tmp_path, capsys)[0] == 0
    text = (tmp_path / HUNT_LIST_LUA).read_text(encoding="utf-8")
    for lore in ("Night Run", "Oddity at Dusk", "Round the Clock", "the Clockwatcher", "Somewhere warm", "name ="):
        assert lore not in text


def test_check_mode_covers_hunt_list_lua(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R60, DATA-R61: --check fails on a stale HuntList.lua and passes once it is regenerated.
    write_tree(tmp_path)
    assert run(tmp_path, capsys)[0] == 0
    write_hunts(tmp_path, HUNTS.replace("tiers = [1, 10, 40]", "tiers = [1, 10, 50]"))
    code, output = run(tmp_path, capsys, "--check")
    assert code == 1
    assert f"{HUNT_LIST_LUA} is out of date with data/" in output
    assert CATALOGUE_LUA not in output  # DATA-R72: a Hunt list change leaves the catalogue alone
    assert run(tmp_path, capsys)[0] == 0
    assert run(tmp_path, capsys, "--check")[0] == 0


def test_the_generated_classes_hold_every_non_noise_item_by_quality_and_species(tmp_path: Path) -> None:
    # DATA-R91: over every catalogue item that isn't Noise, removed ones included: quality.uncommon is quality 2 or
    # more, quality.rare 3 or more, species.any every Species item; DATA-R90: a fixed class as given. 4000 (quality 2)
    # is uncommon only; 6358 is Noise (DB2 quality 4) and in none; 6303 is a removed Species, still in species.any.
    classes = _hunt_list(write_tree(tmp_path))["classes"]
    assert classes == {
        "fixed.oddity": {4000: True, 13759: True},
        "quality.uncommon": {4000: True, 4001: True, 19807: True},
        "quality.rare": {4001: True, 19807: True},
        "species.any": {6303: True, 13759: True, 19807: True},
    }
    generated = ("quality.uncommon", "quality.rare", "species.any")
    assert [name for name in generated if 4000 in classes[name]] == ["quality.uncommon"]
    assert all(6358 not in members for members in classes.values())


def test_every_class_is_emitted_whether_a_hunt_targets_it_or_not(tmp_path: Path) -> None:
    # DATA-R91 (graph.md's drafted default): a list with no Hunts still emits the three generated classes, and a
    # fixed class no Hunt targets is emitted too.
    hunt_list = _hunt_list(write_tree(tmp_path, '[[class]]\nid = "fixed.spare"\nmembers = [6303]\n'))
    assert hunt_list["sets"] == [] and hunt_list["hunts"] == []
    assert sorted(hunt_list["classes"]) == ["fixed.spare", "quality.rare", "quality.uncommon", "species.any"]


def test_a_fixed_class_s_members_join_the_item_universe(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R15: the item universe takes in every fixed class's members, so a member nothing else names still needs
    # a category (DATA-R17), and with one it ships.
    fixed = '[[class]]\nid = "fixed.new"\nmembers = [4100]\n'
    write_tree(tmp_path, fixed)
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert "data/forever/items.toml: item.4100: no category" in output
    write_tree(tmp_path, fixed, ITEMS + '\n[item.4100]\ncategory = "junk"\n')
    assert _hunt_list(tmp_path)["classes"]["fixed.new"] == {4100: True}


def _hashes(root: Path) -> tuple[dict[str, str], str]:
    hunt_list = _hunt_list(root)
    return {str(record["id"]): hunt_hash(record) for record in hunt_list["hunts"]}, hunt_list["fingerprint"]


def test_a_hunt_s_hash_is_the_sha256_of_its_record_without_retired(tmp_path: Path) -> None:
    # DATA-R94: the lowercase hex SHA-256 of the canonical JSON (DATA-R70) of the emitted record without retired,
    # absent optional fields left out, no lore; hunts_fixture works both out by hand with sha256sum.
    hashes, fingerprint = _hashes(write_tree(tmp_path))
    assert hashes == {"night_run": NIGHT_RUN_HASH, "oddity_at_dusk": ODDITY_HASH}
    # DATA-R72: the fingerprint is the first 16 hex characters of the SHA-256 of the list's canonical JSON.
    assert fingerprint == FINGERPRINT == hashlib.sha256(FINGERPRINT_JSON.encode("utf-8")).hexdigest()[:16]


def test_tiers_change_the_hash_and_the_fingerprint(tmp_path: Path) -> None:
    # DATA-R94, DATA-R72: tiers are in the record, so in the hash and the list.
    hashes, fingerprint = _hashes(write_tree(tmp_path, HUNTS.replace("tiers = [1, 10, 40]", "tiers = [1, 10, 50]")))
    assert hashes["night_run"] != NIGHT_RUN_HASH
    assert hashes["oddity_at_dusk"] == ODDITY_HASH
    assert fingerprint != FINGERPRINT


def test_a_retired_date_changes_the_fingerprint_but_not_the_hash(tmp_path: Path) -> None:
    # DATA-R94: the hash leaves retired out, so retiring a Hunt keeps it; DATA-R72: the list holds it, so the
    # fingerprint changes and Hunts rebuilds.
    retired = HUNTS.replace("species = 13759\n", "species = 13759\nretired = 2027-06-01\n")
    hashes, fingerprint = _hashes(write_tree(tmp_path, retired))
    assert hashes == {"night_run": NIGHT_RUN_HASH, "oddity_at_dusk": ODDITY_HASH}
    assert fingerprint != FINGERPRINT


def test_a_name_title_or_note_changes_neither_the_hash_nor_the_fingerprint(tmp_path: Path) -> None:
    # DATA-R105: a Hunt's and a set's name, title and note are lore, out of the hash and the fingerprint.
    reworded = (
        HUNTS.replace('name = "Night Run"', 'name = "Nightfall Run"\nnote = "New note."')
        .replace('note = "Anything odd."', 'note = "Anything at all odd."')
        .replace('title = "the Clockwatcher"', 'title = "the Night Owl"')
    )
    hashes, fingerprint = _hashes(write_tree(tmp_path, reworded))
    assert hashes == {"night_run": NIGHT_RUN_HASH, "oddity_at_dusk": ODDITY_HASH}
    assert fingerprint == FINGERPRINT


def _night_run(old: str, new: str) -> str:
    """HUNTS with one line of the night_run Hunt (the last table) replaced."""
    head, hunt = HUNTS.split('id = "night_run"')
    assert old in hunt
    return head + 'id = "night_run"' + hunt.replace(old, new)


def _oddity(old: str, new: str) -> str:
    """HUNTS with one line of the oddity_at_dusk Hunt (the first) replaced."""
    head, hunt = HUNTS.split('id = "oddity_at_dusk"')
    hunt, tail = hunt.split("[[hunt]]")
    assert old in hunt
    return head + 'id = "oddity_at_dusk"' + hunt.replace(old, new) + "[[hunt]]" + tail


UNCHARTED = ITEMS + '\n[item.4002]\ncategory = "uncharted"\nwhy = "fixture"\n'
F = "data/hunts/hunts.toml: "

# Each DATA-R92 check (all but admission and the rarity cap), and DATA-R63's format problems for hunts.toml: the
# list it breaks, the items.toml it runs over, and the problem, which names the Hunt, set or class.
CASES = {
    "a Hunt ID breaking [%w_]+": (
        HUNTS.replace('id = "night_run"', 'id = "night-run"'),
        ITEMS,
        F + "hunt.night-run.id: 'night-run' doesn't match [%w_]+",
    ),
    "a set ID breaking [%w_]+": (
        HUNTS.replace('id = "camp_hours"', 'id = "camp.hours"').replace('"camp_hours"', '"camp.hours"'),
        ITEMS,
        F + "set.camp.hours.id: 'camp.hours' doesn't match [%w_]+",
    ),
    "a class ID breaking DATA-R90": (
        HUNTS.replace('"fixed.oddity"', '"fixed.odd-ity"'),
        ITEMS,
        F + 'class."fixed.odd-ity".id: \'fixed.odd-ity\' doesn\'t match fixed.<name>',
    ),
    "a repeated Hunt ID": (
        HUNTS.replace('id = "oddity_at_dusk"', 'id = "night_run"'),
        ITEMS,
        F + "hunt.night_run: the Hunt ID 'night_run' is used twice",
    ),
    "a repeated set ID": (
        HUNTS.replace('id = "camp_hours"', 'id = "round_the_clock"'),
        ITEMS,
        F + "set.round_the_clock: the set ID 'round_the_clock' is used twice",
    ),
    "a repeated class ID": (
        HUNTS.replace("[[hunt]]", '[[class]]\nid = "fixed.oddity"\nmembers = [6303]\n\n[[hunt]]', 1),
        ITEMS,
        F + "class.\"fixed.oddity\": the class ID 'fixed.oddity' is used twice",
    ),
    "an unknown set": (
        _night_run('set = "round_the_clock"', 'set = "nowhere"'),
        ITEMS,
        F + "hunt.night_run.set: 'nowhere' isn't a set",
    ),
    "an unknown class": (
        _oddity('class = "fixed.oddity"', 'class = "quality.epic"'),
        ITEMS,
        F + "hunt.oddity_at_dusk.class: 'quality.epic' is neither a [[class]]",
    ),
    "a species target that isn't a Species item": (
        _night_run("species = 13759", "species = 4000"),
        ITEMS,
        F + "hunt.night_run.species: 4000 isn't a Species item (DATA-R19",
    ),
    "a minBand outside 2-4": (
        _night_run("minBand = 3", "minBand = 5"),
        ITEMS,
        F + "hunt.night_run.minBand: expected 2 to 4, got 5 (DATA-R89)",
    ),
    "a minBand on a class target": (
        _oddity("tiers = [1, 10, 25]", "tiers = [1, 10, 25]\nminBand = 2"),
        ITEMS,
        F + "hunt.oddity_at_dusk.minBand: only a species target can have a minBand (DATA-R89)",
    ),
    "a natural Hunt without a window": (
        _night_run('window = "night"\n', ""),
        ITEMS,
        F + "hunt.night_run: is natural and has no window",
    ),
    "a natural Hunt with conditions": (
        _night_run('window = "night"', 'window = "night"\nconditions = { time = [[0, 60]] }'),
        ITEMS,
        F + "hunt.night_run.conditions: a natural Hunt has a window, not conditions",
    ),
    "a natural Hunt with a class target": (
        _night_run("species = 13759\nminBand = 3", 'class = "species.any"'),
        ITEMS,
        F + "hunt.night_run.class: a natural Hunt targets a species, not a class",
    ),
    "an imposed Hunt without conditions": (
        _oddity("conditions = {", "# conditions = {"),
        ITEMS,
        F + "hunt.oddity_at_dusk: is imposed and has no conditions",
    ),
    "an imposed Hunt with a window": (
        _oddity("tiers = [1, 10, 25]", 'tiers = [1, 10, 25]\nwindow = "night"'),
        ITEMS,
        F + "hunt.oddity_at_dusk.window: an imposed Hunt has conditions, not a window",
    ),
    "an invalid conditions spec": (
        _oddity("time = [[1080, 1260]]", "time = [[1080, 1080]]"),
        ITEMS,
        F + "hunt.oddity_at_dusk.conditions: time[1] has from == to (LOG-R48",
    ),
    "a conditions spec naming an aura not on the list": (
        _oddity("areas = [148]", "areas = [148], auras = [1280341, 999]"),
        ITEMS,
        F + "hunt.oddity_at_dusk.conditions: auras: 999 isn't on the aura list (DATA-R39)",
    ),
    "a conditions spec naming an event not on the list": (
        _oddity("areas = [148]", "areas = [148], events = [7]"),
        ITEMS,
        F + "hunt.oddity_at_dusk.conditions: events: 7 isn't on the event list (DATA-R38)",
    ),
    "an unknown window": (
        _night_run('window = "night"', 'window = "dusk"'),
        ITEMS,
        F + "hunt.night_run.window: 'dusk' isn't a window ID (DATA-R35",
    ),
    "tiers not strictly ascending": (
        _night_run("tiers = [1, 10, 40]", "tiers = [1, 10, 10]"),
        ITEMS,
        F + "hunt.night_run.tiers: expected strictly ascending positive integers, got [1, 10, 10] (DATA-R88)",
    ),
    "a tier that isn't positive": (
        _night_run("tiers = [1, 10, 40]", "tiers = [0, 10]"),
        ITEMS,
        F + "hunt.night_run.tiers: expected strictly ascending positive integers, got [0, 10] (DATA-R88)",
    ),
    "retired before since": (
        _oddity("retired = 2027-01-01", "retired = 2026-11-03"),
        ITEMS,
        F + "hunt.oddity_at_dusk.retired: is before since",
    ),
    "a fixed class member that doesn't ship": (
        HUNTS.replace("members = [13759, 4000]", "members = [13759, 4002]"),
        UNCHARTED,
        F + 'class."fixed.oddity".members: item 4002 doesn\'t ship',
    ),
    "an unknown key": (
        _night_run("minBand = 3", "minBand = 3\nbonus = 1"),
        ITEMS,
        F + "hunt.night_run: unknown key 'bonus'",
    ),
    "a wrong type": (
        _night_run("since = 2026-11-04", 'since = "2026-11-04"'),
        ITEMS,
        F + "hunt.night_run.since: expected a date (YYYY-MM-DD), got a string",
    ),
    "a Hunt without a name": (
        _night_run('name = "Night Run"\n', ""),
        ITEMS,
        F + "hunt.night_run: missing key 'name'",
    ),
    "a set without a title": (
        HUNTS.replace('title = "the Hut Keeper"\n', ""),
        ITEMS,
        F + "set.camp_hours: missing key 'title'",
    ),
}


@pytest.mark.parametrize("case", CASES)
def test_each_hunt_check_fails_the_generator_naming_the_hunt_set_or_class(
    case: str, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R92 (all but admission and the rarity cap) and DATA-R63's format problems, each failing the generator
    # with a message naming the Hunt, set or class; DATA-R63: it writes nothing.
    hunts, items, problem = CASES[case]
    write_tree(tmp_path, hunts, items)
    code, output = run(tmp_path, capsys)
    assert code == 1, output
    assert problem in output
    assert "wrote nothing" in output
    assert not (tmp_path / HUNT_LIST_LUA).exists()


def test_several_hunt_problems_are_all_listed_in_one_run(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: the generator lists every problem found, from the file's own checks and the catalogue's, and writes
    # nothing, not even the files that would have been fine.
    broken = (
        HUNTS.replace('id = "camp_hours"', 'id = "round_the_clock"')
        .replace("members = [13759, 4000]", "members = [13759, 4002]")
        .replace("tiers = [1, 10, 40]", "tiers = [10, 1]")
        .replace('window = "night"', 'window = "dusk"')
        .replace("retired = 2027-01-01", "retired = 2026-01-01")
    )
    write_tree(tmp_path, broken, UNCHARTED)
    code, output = run(tmp_path, capsys)
    assert code == 1
    for problem in (
        "set.round_the_clock: the set ID 'round_the_clock' is used twice",
        "hunt.oddity_at_dusk.set: 'camp_hours' isn't a set",
        'class."fixed.oddity".members: item 4002 doesn\'t ship',
        "hunt.night_run.tiers: expected strictly ascending positive integers, got [10, 1]",
        "hunt.night_run.window: 'dusk' isn't a window ID",
        "hunt.oddity_at_dusk.retired: is before since",
    ):
        assert F + problem in output
    assert "6 problem(s) in data/; wrote nothing" in output
    assert not (tmp_path / HUNT_LIST_LUA).exists()
    assert not (tmp_path / CATALOGUE_LUA).exists()


def test_hunts_toml_is_required(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R85: the Hunt definitions live in data/hunts/hunts.toml; without it the generator fails (DATA-R63).
    write_tree(tmp_path)
    (tmp_path / "data" / "hunts" / "hunts.toml").unlink()
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert "data/hunts/hunts.toml: missing" in output
