"""Pool types (DATA-R43, DATA-R44) and each item record's pool flag (DATA-R77, LOG-R55) over small fixture data/
trees: data/forever/pools.toml over the baseline's pools.csv, pool_loot.csv and reference_loot.csv."""

import re
from pathlib import Path

import pytest

from areas_fixture import write_areas
from baseline_fixture import CSVS, write_baseline
from cli_fixture import run
from item_fixture import write_item_layer
from observed_fixture import write_observed
from hunts_fixture import write_hunts
from pools_fixture import write_pools
from windows_fixture import write_windows

CATALOGUE = "addons/Pagle/data/Catalogue.lua"

# Four pool templates of three kinds (DATA-R9's pools.csv), and their loot. Oily Blackmouth's two templates give
# 6359 and 21071, 3820 (Noise by items.toml) and, through reference table 501, 13422 (reachable only through
# reference tables, so Noise by rule) and 21071. 20708 comes from Floating Debris.
POOL_CSVS = {
    **CSVS,
    "pools.csv": (
        "entry,name,event\n"
        "180248,School of Tastyfish,15\n"
        "180582,Oily Blackmouth School,\n"
        "180655,Floating Debris,\n"
        "180664,Oily Blackmouth School,\n"
    ),
    "pool_loot.csv": (
        "entry,item,chance,ref\n"
        "180248,19807,0.0271,\n"
        "180582,6359,85,\n"
        "180582,3820,0,\n"
        "180655,20708,60,\n"
        "180664,6359,85,\n"
        "180664,,1,501\n"
    ),
    "reference_loot.csv": "ref,item,chance\n500,6358,14.14\n501,13422,5\n501,21071,5\n",
}

# Categories for every item of the universe (DATA-R17): the fixture's area loot (6303, 13759), the pool loot above,
# and Whimsyfin (251524), which only a pool edit names. 21071 is reachable only through table 501, but noise = false
# counts it (DATA-R16).
ITEMS = """\
[item.3820]
noise = true
why = "a herb"

[item.6303]
category = "fish"

[item.6359]
category = "fish"

[item.13759]
category = "fish"

[item.19807]
category = "fish"

[item.20708]
category = "container"

[item.21071]
category = "fish"
noise = false
why = "a fish"

[item.251524]
category = "fish"
"""

POOLS = """\
[pool.schoolOfTastyfish]
entries = [180248]
why = "VMaNGOS"

[pool.oilyBlackmouthSchool]
entries = [180582, 180664]
why = "VMaNGOS"

[pool.floatingDebris]
entries = [180655]
why = "VMaNGOS"

[pool.schoolOfWhimsyfin]
entries = [572928]
add = [251524]
why = "Forever's new pool"
"""


def write_tree(root: Path, pools: str = POOLS, items: str = ITEMS, csvs: dict[str, str] | None = None) -> Path:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "events.toml").write_text("", encoding="utf-8")
    (forever / "lists.toml").write_text("auras = []\nfishingSpells = [7620]\n", encoding="utf-8")
    (forever / "aliases.toml").write_text("", encoding="utf-8")
    write_baseline(root, POOL_CSVS if csvs is None else csvs)
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text('build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n', encoding="utf-8")
    (db2 / "areas.csv").write_text("ID,ParentAreaID,ContinentID,AreaName_lang\n", encoding="utf-8")
    (db2 / "items.csv").write_text("ID,ClassID,SubclassID,OverallQualityID,Display_lang\n", encoding="utf-8")
    write_areas(root)  # test_catch_lists.py covers areas.toml
    write_windows(root)  # test_windows.py covers windows
    write_observed(root)  # dev.toml with no facts; test_observed.py covers the layer
    write_item_layer(root, items)  # test_item_records.py covers the item layer
    write_pools(root, pools)
    write_hunts(root)  # test_hunts.py covers the Hunt list
    return root


def catalogue(root: Path, capsys: pytest.CaptureFixture[str]) -> str:
    code, output = run(root, capsys)
    assert code == 0, output
    return (root / CATALOGUE).read_text(encoding="utf-8")


def pools(root: Path, capsys: pytest.CaptureFixture[str]) -> str:
    """The pools field of the Catalogue.lua the generator wrote."""
    block = re.search(r"^\tpools = \{\},$|^\tpools = \{\n.*?^\t\},$", catalogue(root, capsys), re.M | re.S)
    assert block is not None
    return block.group(0)


def pool_flags(root: Path, capsys: pytest.CaptureFixture[str]) -> dict[int, bool]:
    """Each emitted item record's pool flag, by item ID."""
    text = catalogue(root, capsys)
    return {int(item): flag == "true" for item, flag in re.findall(r"^\t\t\[(\d+)\] = \{.*pool = (\w+)", text, re.M)}


def fails(root: Path, capsys: pytest.CaptureFixture[str], *problems: str) -> None:
    """The generator fails naming every one of problems, and writes nothing (DATA-R63)."""
    code, output = run(root, capsys)
    assert code == 1
    for problem in problems:
        assert problem in output
    assert not (root / CATALOGUE).exists()


def test_each_pool_type_ships_its_catches_ascending(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R43: a pool type's catches are its entries' pool loot, references flattened, then the edits, with Noise
    # left out (3820 by items.toml, 13422 by rule; 21071 has noise = false), ascending. School of Whimsyfin's entry
    # has no baseline loot and gets its catches from add. DATA-R44: poolType -> catches, and no entry map.
    assert pools(write_tree(tmp_path), capsys) == (
        "\tpools = {\n"
        "\t\tfloatingDebris = { 20708 },\n"
        "\t\toilyBlackmouthSchool = { 6359, 21071 },\n"
        "\t\tschoolOfTastyfish = { 19807 },\n"
        "\t\tschoolOfWhimsyfin = { 251524 },\n"
        "\t},"
    )


def test_an_item_is_pool_when_in_any_pool_type_s_catches(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R77, LOG-R55: pool is true for an item in any pool type's catches and false otherwise: area-loot items
    # (6303, 13759), and Noise items, which ship with pool = false though pool loot holds them (3820, 13422, DATA-R16).
    flags = pool_flags(write_tree(tmp_path), capsys)
    assert {item for item, flag in flags.items() if flag} == {6359, 19807, 20708, 21071, 251524}
    assert {item for item, flag in flags.items() if not flag} == {3820, 6303, 6358, 13422, 13759}


def test_add_and_drop_edit_a_pool_type_s_catches(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R43: the baseline's loot, then the edits. Dropping 6359 leaves 21071; adding 6303, an area-loot fish, puts
    # it in. The pool flag follows (DATA-R77): 6359 is in no pool type now, 6303 is.
    edited = POOLS.replace("entries = [180582, 180664]\n", "entries = [180582, 180664]\nadd = [6303]\ndrop = [6359]\n")
    root = write_tree(tmp_path, edited)
    assert "\t\toilyBlackmouthSchool = { 6303, 21071 },\n" in pools(root, capsys)
    flags = pool_flags(root, capsys)
    assert flags[6303] is True
    assert flags[6359] is False


def test_removed_and_uncharted_items_leave_pool_lists(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R23: a removed item keeps its record but leaves every pool list, so it isn't pool (DATA-R77). DATA-R18:
    # an uncharted item never ships, so it leaves every pool list too.
    removed = '[item.6359]\ncategory = "fish"\nremoved = true\nremovedFrom = 70338\nwhy = "gone"\n'
    uncharted = '[item.20708]\ncategory = "uncharted"\nwhy = "unsure"\n'
    items = ITEMS.replace('[item.6359]\ncategory = "fish"\n', removed).replace(
        '[item.20708]\ncategory = "container"\n', uncharted
    )
    root = write_tree(tmp_path, items=items)
    text = pools(root, capsys)
    assert "\t\toilyBlackmouthSchool = { 21071 },\n" in text
    assert "\t\tfloatingDebris = {},\n" in text
    flags = pool_flags(root, capsys)
    assert flags[6359] is False
    assert 20708 not in flags


def test_a_noise_item_added_to_a_pool_type_is_left_out(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R43: Noise is left out after the edits too; 6358 is reachable only through reference table 500 (DATA-R16).
    root = write_tree(tmp_path, POOLS.replace("add = [251524]", "add = [251524, 6358]"))
    assert "\t\tschoolOfWhimsyfin = { 251524 },\n" in pools(root, capsys)


def test_the_fingerprint_changes_with_the_pool_flag(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R70: every catalogue value counts. Dropping Whimsyfin from its pool type changes its pool flag and the
    # pool's catches, so the fingerprint changes.
    def fingerprint(root: Path) -> str:
        found = re.search(r'^\tfingerprint = "([0-9a-f]{16})",$', catalogue(root, capsys), re.M)
        assert found is not None
        return found.group(1)

    pooled = fingerprint(write_tree(tmp_path / "pooled"))
    dropped = fingerprint(write_tree(tmp_path / "dropped", POOLS.replace("add = [251524]", "drop = [251524]")))
    assert pooled != dropped


def test_a_baseline_template_in_no_pool_type_is_a_warning(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # #93: a pools.csv entry in no pool type is warned about (DATA-R64 style: printed, not failing), so a new baseline
    # template isn't silently dropped. Its loot is in no pool type, so 20708 isn't pool.
    root = write_tree(tmp_path, POOLS.replace("[pool.floatingDebris]\nentries = [180655]\nwhy = \"VMaNGOS\"\n", ""))
    code, output = run(root, capsys)
    assert code == 0, output
    assert (
        "generate-data: warning: pool template 180655 (Floating Debris) in pools.csv is in no pool type in"
        " data/forever/pools.toml; add it to one (DATA-R43)"
    ) in output
    assert "pool template 180582" not in output
    flags = pool_flags(root, capsys)
    assert flags[20708] is False


def test_every_template_in_a_pool_type_warns_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # #93: with every pools.csv entry grouped there is no pool warning; Whimsyfin's 572928, with no baseline loot or
    # pools.csv row, is no problem (DATA-R43).
    code, output = run(write_tree(tmp_path), capsys)
    assert code == 0, output
    assert "pool template" not in output


def test_a_pool_type_without_a_why_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R10: a why is required on every pools.toml entry; the generator fails without one and writes nothing.
    root = write_tree(tmp_path, POOLS.replace('why = "Forever\'s new pool"\n', ""))
    fails(root, capsys, "data/forever/pools.toml: pool.schoolOfWhimsyfin: missing key 'why'")


@pytest.mark.parametrize(
    ("pools", "problem"),
    [
        # DATA-R63: an unknown key or a wrong type in any TOML file under data/.
        ('[pool.a]\nentries = [180248]\nwhy = "x"\nitems = [1]\n', "pool.a: unknown key 'items'"),
        ('[pool.a]\nwhy = "x"\n', "pool.a: missing key 'entries'"),
        ('[pool.a]\nentries = 180248\nwhy = "x"\n', "pool.a.entries: expected an array of IDs"),
        ('[pool.a]\nentries = [180248]\nadd = ["x"]\nwhy = "x"\n', "pool.a.add[0]: expected an integer"),
        ('[pool.a]\nentries = [180248]\nwhy = ""\n', "pool.a.why: empty"),
        ("pools = 1\n", "unknown key 'pools'"),
        # DATA-R43: entries name at least one GameObject entry, and a pool type ID is [%w_]+.
        ('[pool.a]\nentries = []\nwhy = "x"\n', "pool.a.entries: empty"),
        ('[pool."a-b"]\nentries = [180248]\nwhy = "x"\n', "pool.a-b: a pool type ID is letters, digits and underscores"),
        # #93: one entry grouped by two pool types is ambiguous.
        (
            '[pool.a]\nentries = [180248]\nwhy = "x"\n\n[pool.b]\nentries = [180248]\nwhy = "x"\n',
            "pool.b.entries: entry 180248 is already in pool type a",
        ),
    ],
)
def test_a_bad_pools_toml_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str], pools: str, problem: str) -> None:
    fails(write_tree(tmp_path, pools), capsys, f"data/forever/pools.toml: {problem}")


def test_a_missing_pools_toml_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R10: pools.toml is one of data/forever/'s files; without it every pool template would drop out.
    root = write_tree(tmp_path)
    (root / "data" / "forever" / "pools.toml").unlink()
    fails(root, capsys, "data/forever/pools.toml: missing")
