"""The release lock (DATA-R91, DATA-R95, DATA-R96, ADR 0005) over small fixture data/ trees: --lock writes
data/hunts/released.lock from the Hunt list, and the generator fails when the data breaks it."""

from pathlib import Path

import pytest

from cli_fixture import run
from hunts_fixture import HUNTS, ITEMS, NIGHT_RUN_HASH, ODDITY_HASH, write_hunts
from pagle_data.generate import hunt_list_of, read_layers
from pagle_data.hunts import HUNT_LIST_LUA
from test_hunts import write_tree

LOCK = "data/hunts/released.lock"
VARIETIES_LOCK = "data/forever/varieties.lock"

# The fixture list plus an imposed Hunt on the generated class quality.uncommon, so the lock records a generated class
# beside the fixed one. Its hash, by hand: printf '%s' '{"class":"quality.uncommon","conditions":{"areas":[148]},
# "id":"any_green","kind":"imposed","set":"camp_hours","since":1793750400,"tiers":[5]}' | sha256sum
LOCKED_HUNTS = (
    HUNTS
    + """
[[hunt]]
id = "any_green"
set = "camp_hours"
kind = "imposed"
since = 2026-11-04
class = "quality.uncommon"
conditions = { areas = [148] }
tiers = [5]
name = "Any Green"
"""
)
ANY_GREEN_HASH = "bcbcc20b2b7cfbf48bdd023d094b95d63693e4b7bbaacf7b922b19d018557dcd"

# What --lock writes for LOCKED_HUNTS (DATA-R95, DATA-R62): Hunts then classes, each by ascending ID; oddity_at_dusk's
# retired date; the members of the two targeted classes ascending (night_run targets a Species, not a class).
LOCKED = f"""\
[hunt.any_green]
hash = "{ANY_GREEN_HASH}"

[hunt.night_run]
hash = "{NIGHT_RUN_HASH}"

[hunt.oddity_at_dusk]
hash = "{ODDITY_HASH}"
retired = 2027-01-01

[class."fixed.oddity"]
members = [4000, 13759]

[class."quality.uncommon"]
members = [4000, 4001, 19807]
"""


def _files(root: Path) -> dict[str, bytes]:
    return {path.relative_to(root).as_posix(): path.read_bytes() for path in root.rglob("*") if path.is_file()}


def _entries(text: str) -> str:
    """The lock without its header comment."""
    return "".join(line for line in text.splitlines(keepends=True) if not line.startswith("#")).lstrip("\n")


def test_lock_writes_each_hunt_s_hash_retired_date_and_targeted_class_and_nothing_else(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R95: [hunt.<id>] with hash (DATA-R94) and, if retired, retired (a date); [class."<classID>"] with members
    # (ascending item IDs) for each class a released Hunt targets, fixed or generated. DATA-R60: --lock rewrites the
    # lock from the current data, every Hunt in the list counting as released, and writes nothing else.
    write_tree(tmp_path, LOCKED_HUNTS)
    before = _files(tmp_path)
    code, output = run(tmp_path, capsys, "--lock")
    assert code == 0, output
    after = _files(tmp_path)
    # DATA-R133: --lock writes the varieties lock beside it (test_varieties.py covers it).
    assert set(after) - set(before) == {LOCK, VARIETIES_LOCK}
    assert {path: content for path, content in after.items() if path not in (LOCK, VARIETIES_LOCK)} == before
    assert _entries((tmp_path / LOCK).read_text(encoding="utf-8")) == LOCKED


def _locked(root: Path, capsys: pytest.CaptureFixture[str], hunts: str = LOCKED_HUNTS) -> Path:
    """A fixture tree whose Hunt list is locked as it stands, as at a release tag."""
    write_tree(root, hunts)
    code, output = run(root, capsys, "--lock")
    assert code == 0, output
    return root


def _fails(root: Path, capsys: pytest.CaptureFixture[str], hunts: str, problem: str) -> None:
    """With hunts.toml rewritten to hunts, the generator fails on the lock, listing problem, and writes nothing
    (DATA-R63)."""
    write_hunts(root, hunts)
    code, output = run(root, capsys)
    assert code == 1
    assert problem in output
    assert "wrote nothing" in output


def _without_hunt(hunts: str, hunt_id: str) -> str:
    """hunts with the [[hunt]] table of hunt_id deleted."""
    tables = hunts.split("\n[[")
    return "\n[[".join(table for table in tables if not table.startswith(f'hunt]]\nid = "{hunt_id}"'))


def test_a_locked_hunt_deleted_instead_of_retired_fails_naming_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R96: a locked Hunt is missing (deleted instead of retired); ADR 0005: a released Hunt stays forever.
    _locked(tmp_path, capsys)
    assert 'id = "night_run"' not in _without_hunt(LOCKED_HUNTS, "night_run")
    _fails(
        tmp_path,
        capsys,
        _without_hunt(LOCKED_HUNTS, "night_run"),
        f"{LOCK}: hunt.night_run: the released Hunt is gone from data/hunts/hunts.toml",
    )


def test_changing_a_locked_hunt_s_tiers_fails_naming_it(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R96: a locked Hunt's hash (DATA-R94) differs; ADR 0005: a fix ships as a new Hunt plus a retired date.
    _locked(tmp_path, capsys)
    changed = LOCKED_HUNTS.replace("tiers = [1, 10, 40]", "tiers = [1, 10, 50]")
    assert changed != LOCKED_HUNTS
    _fails(tmp_path, capsys, changed, "data/hunts/hunts.toml: hunt.night_run: differs from the released Hunt")


@pytest.mark.parametrize(
    "retired",
    [
        pytest.param("", id="removed"),
        pytest.param("retired = 2027-02-01\n", id="moved"),
    ],
)
def test_removing_or_moving_a_locked_retired_date_fails_naming_the_hunt(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], retired: str
) -> None:
    # DATA-R96: a locked retired date changed or was removed. The hash leaves retired out (DATA-R94), so only this
    # check catches it.
    _locked(tmp_path, capsys)
    changed = LOCKED_HUNTS.replace("retired = 2027-01-01\n", retired)
    assert changed != LOCKED_HUNTS
    problem = "data/hunts/hunts.toml: hunt.oddity_at_dusk.retired: the released Hunt was retired on 2027-01-01"
    _fails(tmp_path, capsys, changed, problem)


def test_dropping_a_locked_fixed_class_member_fails_naming_the_class(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R96: a locked fixed class lost a member; ADR 0005: a class a shipped Hunt targets can only gain members.
    _locked(tmp_path, capsys)
    changed = LOCKED_HUNTS.replace("members = [13759, 4000]", "members = [4000]")
    assert changed != LOCKED_HUNTS
    _fails(
        tmp_path,
        capsys,
        changed,
        'data/hunts/hunts.toml: class."fixed.oddity".members: lost 13759, a member locked in ' + LOCK,
    )


def test_a_locked_fixed_class_deleted_whole_fails_naming_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R96: deleting the class loses every member. The retired Hunt that targeted it goes too here, so the
    # missing class is named on its own beside the missing Hunt.
    _locked(tmp_path, capsys)
    changed = _without_hunt(LOCKED_HUNTS, "oddity_at_dusk").replace(
        '[[class]]\nid = "fixed.oddity"\nmembers = [13759, 4000]\n\n', ""
    )
    assert "fixed.oddity" not in changed
    _fails(tmp_path, capsys, changed, f'{LOCK}: class."fixed.oddity": the locked fixed class is gone')


NEW_HUNT = """
[[hunt]]
id = "night_run_2"
set = "round_the_clock"
kind = "natural"
since = 2027-03-01
species = 13759
window = "night"
tiers = [1, 10, 50]
name = "Night Run"
"""


def test_retiring_a_locked_hunt_and_adding_its_fix_as_a_new_one_pass(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R96, ADR 0005: a fix ships as a new Hunt plus a retired date on the old one. Adding the retired date
    # leaves the hash alone (DATA-R94); a new Hunt and a new fixed-class member are no loss.
    _locked(tmp_path, capsys)
    fixed = (
        LOCKED_HUNTS.replace('window = "night"\ntiers', 'window = "night"\nretired = 2027-03-01\ntiers')
        .replace("members = [13759, 4000]", "members = [13759, 4000, 4001]")
        + NEW_HUNT
    )
    assert "retired = 2027-03-01" in fixed
    write_hunts(tmp_path, fixed)
    code, output = run(tmp_path, capsys)
    assert code == 0, output
    # Locking again (the next release) records the retired date and the new Hunt.
    assert run(tmp_path, capsys, "--lock")[0] == 0
    lock = (tmp_path / LOCK).read_text(encoding="utf-8")
    assert f'[hunt.night_run]\nhash = "{NIGHT_RUN_HASH}"\nretired = 2027-03-01\n' in lock
    assert "[hunt.night_run_2]" in lock


def test_an_empty_or_absent_lock_checks_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R96: an empty or absent lock checks nothing, so before 1.0 the data changes freely (DATA-R73).
    write_tree(tmp_path, LOCKED_HUNTS)
    changed = _without_hunt(LOCKED_HUNTS, "night_run").replace("tiers = [5]", "tiers = [6]")
    for lock in ("# A header comment only.\n", None):
        if lock is None:
            (tmp_path / LOCK).unlink()
        else:
            (tmp_path / LOCK).write_text(lock, encoding="utf-8")
        write_hunts(tmp_path, changed)
        code, output = run(tmp_path, capsys)
        assert code == 0, output


# 4000 (quality 2, so in quality.uncommon) turned Noise, and 4001 (quality 3) lowered to quality 1.
NOISE_4000 = ITEMS.replace(
    '[item.4000]\ncategory = "junk"\nclass = 15\nquality = 2\n',
    '[item.4000]\ncategory = "other"\nnoise = true\nwhy = "fixture"\nclass = 15\nquality = 2\n',
).replace("class = 15\nquality = 3\n", "class = 15\nquality = 1\n")


def test_a_locked_generated_class_keeps_a_member_that_turned_noise_or_lost_quality(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R91: a generated class a released Hunt targets keeps every member the lock records for it, whatever has
    # changed since (a new Noise flag, a quality change), so it never loses one (ADR 0005).
    assert NOISE_4000.count("noise = true") == 1 and "quality = 3" not in NOISE_4000
    write_tree(tmp_path, LOCKED_HUNTS, NOISE_4000)
    unlocked = hunt_list_of(read_layers(tmp_path))["classes"]["quality.uncommon"]
    assert unlocked == {19807: True}  # without the lock, both drop out
    write_tree(tmp_path, LOCKED_HUNTS)
    assert run(tmp_path, capsys, "--lock")[0] == 0
    write_tree(tmp_path, LOCKED_HUNTS, NOISE_4000)  # the lock stays
    code, output = run(tmp_path, capsys)
    assert code == 0, output
    classes = hunt_list_of(read_layers(tmp_path))["classes"]
    assert classes["quality.uncommon"] == {4000: True, 4001: True, 19807: True}
    assert "[4000] = true, [4001] = true, [19807] = true" in (tmp_path / HUNT_LIST_LUA).read_text(encoding="utf-8")
    # quality.rare isn't locked (no Hunt targets it), so 4001 leaves it.
    assert classes["quality.rare"] == {19807: True}


def test_a_locked_generated_class_member_that_no_longer_ships_fails_naming_the_class(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R91: a locked generated class keeps its locked members, and like a fixed class member (DATA-R90) each must
    # ship (DATA-R18). 4001 is only in the universe through items.toml; with its entry gone it doesn't ship.
    _locked(tmp_path, capsys)
    without_4001 = ITEMS.replace('\n[item.4001]\ncategory = "junk"\nclass = 15\nquality = 3\n', "")
    assert "4001" not in without_4001
    write_tree(tmp_path, LOCKED_HUNTS, without_4001)
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert f'{LOCK}: class."quality.uncommon".members: item 4001 is a locked member but doesn\'t ship' in output


def test_lock_fails_and_writes_nothing_when_the_data_breaks_the_lock(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R63, DATA-R96: --lock reads the data like every mode, so data that breaks the lock fails and the lock
    # isn't rewritten over the change it should catch.
    _locked(tmp_path, capsys)
    locked = (tmp_path / LOCK).read_bytes()
    write_hunts(tmp_path, LOCKED_HUNTS.replace("tiers = [5]", "tiers = [6]"))
    code, output = run(tmp_path, capsys, "--lock")
    assert code == 1
    assert "hunt.any_green: differs from the released Hunt" in output
    assert (tmp_path / LOCK).read_bytes() == locked


def test_a_lock_of_the_wrong_shape_fails_naming_the_entry(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: an unknown key or a wrong type in any TOML file under data/; DATA-R95: the lock's keys and types.
    write_tree(tmp_path, LOCKED_HUNTS)
    (tmp_path / LOCK).write_text(
        '[hunt.night_run]\nhash = "F00"\nnote = "x"\n\n[hunt.any_green]\nhash = "' + ANY_GREEN_HASH + '"\n'
        'retired = "2027-01-01"\n\n[class."quality.epic"]\nmembers = [1]\n\n[class."fixed.oddity"]\nmembers = 4000\n',
        encoding="utf-8",
    )
    code, output = run(tmp_path, capsys)
    assert code == 1
    for problem in (
        f"{LOCK}: hunt.night_run: unknown key 'note'",
        f"{LOCK}: hunt.night_run.hash: expected 64 lowercase hex characters",
        f"{LOCK}: hunt.any_green.retired: expected a date (YYYY-MM-DD), got a string",
        f"{LOCK}: class.\"quality.epic\": 'quality.epic' is neither a fixed class ID nor a generated class",
        f'{LOCK}: class."fixed.oddity".members: expected an array of IDs, got an integer',
    ):
        assert problem in output
