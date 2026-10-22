"""Fish varieties in content data (VAR-R2, VAR-R4, VAR-R5) over small fixture data/ trees: data/forever/varieties.toml
emitted on each Species item as varieties, its checks once the varieties switch is on (DATA-R66), and
data/forever/varieties.lock, which --lock writes and the generator checks the keys against."""

from pathlib import Path

import pytest

from cli_fixture import run
from test_item_records import FISH, fails, fish, records, write_tree

VARIETIES = "data/forever/varieties.toml"
VARIETIES_LOCK = "data/forever/varieties.lock"
HUNTS_LOCK = "data/hunts/released.lock"

# The three fixture Species, each sized (DATA-R20), so each needs its ten once the switch is on.
LENGTHS = (
    "[species.6303]\ntypicalLength = 300\n\n[species.13759]\ntypicalLength = 550\n\n"
    "[species.19807]\ntypicalLength = 400\n"
)
ON = "typicalLength = true\nlore = []\nvarieties = true\n"
TEN = ["plain", "blue", "green", "spotted", "barred", "red", "glass", "golden", "ink", "starlit"]


def _keys(keys: list[str]) -> str:
    return "keys = [" + ", ".join(f'"{key}"' for key in keys) + "]"


def _table(species: int, keys: list[str] = TEN) -> str:
    return f"[varieties.{species}]\n{_keys(keys)}\n"


ALL_THREE = "\n".join(_table(species) for species in (6303, 13759, 19807))
TEN_LUA = 'varieties = { "plain", "blue", "green", "spotted", "barred", "red", "glass", "golden", "ink", "starlit" }'


def _tree(root: Path, varieties: str | None, items: str = FISH, checks: str = ON, lock: str | None = None) -> Path:
    write_tree(root, items, species=LENGTHS, checks=checks)
    if varieties is not None:
        (root / VARIETIES).write_text(varieties, encoding="utf-8")
    if lock is not None:
        (root / VARIETIES_LOCK).write_text(lock, encoding="utf-8")
    return root


def test_each_species_item_ships_its_ten_keys_in_order(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # VAR-R4: the catalogue carries each Species item's ten keys in order as varieties, on every item of the Species
    # as its typical length is (DATA-R20): 13759 folds into 6303 and ships 6303's ten.
    items = FISH.replace('[item.13759]\ncategory = "fish"', '[item.13759]\ncategory = "fish"\nspecies = 6303')
    lengths = "[species.6303]\ntypicalLength = 300\n\n[species.19807]\ntypicalLength = 400\n"
    write_tree(tmp_path, items, species=lengths, checks=ON)
    (tmp_path / VARIETIES).write_text(_table(6303) + "\n" + _table(19807), encoding="utf-8")
    found = records(tmp_path, capsys)
    assert found[6303] == fish(6303).replace("species = 6303", f"species = 6303, typicalLength = 300, {TEN_LUA}")
    assert found[13759] == fish(13759).replace("species = 13759", f"species = 6303, typicalLength = 300, {TEN_LUA}")
    assert found[19807] == fish(19807).replace("species = 19807", f"species = 19807, typicalLength = 400, {TEN_LUA}")


def test_a_sized_species_without_an_entry_fails_once_the_switch_is_on(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # VAR-R2, DATA-R66: a sized, non-Legend Species with no entry fails, naming it, only with varieties = true.
    only_two = _table(6303) + "\n" + _table(19807)
    fails(
        _tree(tmp_path, only_two),
        capsys,
        f"{VARIETIES}: Species 13759 is sized and not a Legend, so it needs its ten varieties (VAR-R2, DATA-R132)",
    )
    assert records(_tree(tmp_path, only_two, checks="typicalLength = true\nlore = []\n"), capsys)[13759] == fish(
        13759
    ).replace("species = 13759", "species = 13759, typicalLength = 550")


def test_an_unsized_species_or_a_legend_needs_none(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # VAR-R1: a Catch has a variety only with a Simulated Size (a typical length, LOG-R65) and a non-Legend item.
    items = FISH.replace('[item.19807]\ncategory = "fish"', '[item.19807]\ncategory = "fish"\nlegend = true')
    unsized = "typicalLength = false\nlore = []\nvarieties = true\n"
    write_tree(tmp_path, items, species="[species.6303]\ntypicalLength = 300\n", checks=unsized)
    (tmp_path / VARIETIES).write_text(_table(6303), encoding="utf-8")
    found = records(tmp_path, capsys)
    assert "varieties" not in found[13759] and "varieties" not in found[19807]


@pytest.mark.parametrize(
    ("varieties", "problem"),
    [
        # An entry for anything but a sized, non-Legend Species: a Noise item, an unknown item, an unsized one.
        (ALL_THREE + _table(6358), "varieties.6358: 6358 isn't a sized, non-Legend Species, so it has no varieties"),
        (ALL_THREE + _table(4000), "varieties.4000: 4000 isn't a sized, non-Legend Species, so it has no varieties"),
        (
            ALL_THREE.replace(_keys(TEN), _keys(TEN[:9]), 1),
            "varieties.6303.keys: 9 keys; a Species has exactly ten varieties (VAR-R2)",
        ),
        (
            ALL_THREE.replace(_keys(TEN), _keys([*TEN[:9], "plain"]), 1),
            "varieties.6303.keys: 'plain' is listed twice; each of a Species' ten keys is its own (VAR-R2)",
        ),
        (
            ALL_THREE.replace('"blue"', '"Blue Cheek"', 1),
            "varieties.6303.keys[1]: a key is lowercase letters and digits joined by hyphens (VAR-R2), got 'Blue Cheek'",
        ),
        (ALL_THREE.replace("keys =", "names =", 1), "varieties.6303: unknown key 'names'"),
        (ALL_THREE.replace(_keys(TEN), "keys = 10", 1), "varieties.6303.keys: expected an array of keys, got an integer"),
    ],
)
def test_a_bad_entry_fails_naming_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], varieties: str, problem: str
) -> None:
    # VAR-R2: ten keys, none repeated, each a key a variety's ID (<speciesID>.<key>) can hold; DATA-R63: an unknown
    # key or a wrong type fails.
    fails(_tree(tmp_path, varieties), capsys, f"{VARIETIES}: {problem}")


def test_the_lock_is_checked_by_key_and_position(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # VAR-R5: a shipped Species' keys never change, move or go; a key's name and art may (VAR-R11), its key not.
    locked = "# header\n\n" + ALL_THREE
    assert run(_tree(tmp_path, ALL_THREE, lock=locked), capsys)[0] == 0
    renamed = ALL_THREE.replace('"blue"', '"azure"', 1)
    fails(
        _tree(tmp_path, renamed, lock=locked),
        capsys,
        f"{VARIETIES}: varieties.6303.keys: position 2 is 'azure', but 'blue' shipped there ({VARIETIES_LOCK});"
        " a shipped variety's key and position never change (VAR-R5)",
    )
    swapped = ALL_THREE.replace('"blue", "green"', '"green", "blue"', 1)
    fails(_tree(tmp_path, swapped, lock=locked), capsys, "position 2 is 'green', but 'blue'", "position 3 is 'blue'")
    gone = _table(13759) + "\n" + _table(19807)
    fails(
        _tree(tmp_path, gone, lock=locked, checks="typicalLength = true\nlore = []\n"),
        capsys,
        f"{VARIETIES_LOCK}: varieties.6303: the shipped Species' varieties are gone from {VARIETIES}; a Species keeps"
        " its ten, removed or not (VAR-R5)",
    )


def test_lock_writes_the_varieties_lock_beside_the_release_lock(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R95, VAR-R5: --lock writes every Species' ten keys, by ascending Species ID, after the header comment.
    _tree(tmp_path, _table(19807) + "\n" + _table(6303) + "\n" + _table(13759))
    code, output = run(tmp_path, capsys, "--lock")
    assert code == 0, output
    assert (tmp_path / HUNTS_LOCK).is_file()
    text = (tmp_path / VARIETIES_LOCK).read_text(encoding="utf-8")
    assert text.startswith("# ")
    assert "".join(line for line in text.splitlines(keepends=True) if not line.startswith("#")).lstrip("\n") == (
        ALL_THREE
    )
    # The lock written is the lock the data keeps.
    assert run(tmp_path, capsys)[0] == 0
