"""Item records (DATA-R15-R24, DATA-R77) over small fixture data/ trees: items.toml, species.toml, families.toml and
checks.toml, and the record each item of the universe ships with in Catalogue.lua."""

import re
from pathlib import Path

import pytest

from baseline_fixture import write_baseline
from item_fixture import CHECKS, write_item_layer
from observed_fixture import write_observed
from pagle_data.cli import main
from windows_fixture import write_windows

CATALOGUE = "addons/Pagle/data/Catalogue.lua"
HEADER = "ID,ClassID,SubclassID,OverallQualityID,Display_lang\n"

# DB2 rows for the fixture baseline's items (baseline_fixture.CSVS: 13759 and 6303 in area loot, 6358 only in
# reference table 500, 19807 in pool loot), written as update-db2.py would (DATA-R11).
DB2_ITEMS = HEADER + "6303,7,8,1,Raw Slitherskin Mackerel\n13759,7,8,1,Raw Nightfin Snapper\n19807,15,4,1,Speckled Tastyfish\n"


def write_tree(
    root: Path,
    items: str,
    db2_items: str = DB2_ITEMS,
    species: str = "",
    families: str = "",
    checks: str = CHECKS,
) -> Path:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "events.toml").write_text("", encoding="utf-8")
    (forever / "lists.toml").write_text("auras = []\nfishingSpells = [7620]\n", encoding="utf-8")
    (forever / "aliases.toml").write_text("", encoding="utf-8")
    write_baseline(root)
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text('build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n', encoding="utf-8")
    (db2 / "areas.csv").write_text("ID,ParentAreaID,ContinentID,AreaName_lang\n", encoding="utf-8")
    (db2 / "items.csv").write_text(db2_items, encoding="utf-8")
    write_windows(root)  # test_windows.py covers windows
    write_observed(root)  # dev.toml with no facts; test_observed.py covers the layer
    return write_item_layer(root, items, species, families, checks)


def run(root: Path, capsys: pytest.CaptureFixture[str]) -> tuple[int, str]:
    code = main([], root)
    out, err = capsys.readouterr()
    return code, out + err


def records(root: Path, capsys: pytest.CaptureFixture[str]) -> dict[int, str]:
    """Each emitted item record's Lua, by item ID, from the Catalogue.lua the generator wrote."""
    code, output = run(root, capsys)
    assert code == 0, output
    text = (root / CATALOGUE).read_text(encoding="utf-8")
    block = re.search(r"^\titems = \{\n(.*?)^\t\},$", text, flags=re.MULTILINE | re.DOTALL)
    assert block is not None, text
    return {int(item): record for item, record in re.findall(r"^\t\t\[(\d+)\] = (\{.*\}),$", block.group(1), re.M)}


def fails(root: Path, capsys: pytest.CaptureFixture[str], *problems: str) -> None:
    """The generator fails naming every one of problems, and writes nothing (DATA-R63)."""
    path = root / CATALOGUE
    before = path.read_bytes() if path.exists() else None
    code, output = run(root, capsys)
    assert code == 1
    for problem in problems:
        assert problem in output
    assert (path.read_bytes() if path.exists() else None) == before


FISH = '[item.6303]\ncategory = "fish"\n\n[item.13759]\ncategory = "fish"\n\n[item.19807]\ncategory = "fish"\n'


def fish(item: int, quality: int | None = 1) -> str:
    """The record of a Species item that is its own Species (DATA-R19), with nothing else set."""
    known = f"quality = {quality}, " if quality is not None else ""
    return f"{{ category = \"fish\", legend = false, noise = false, pool = false, {known}removed = false, species = {item} }}"


NOISE_6358 = "{ category = \"other\", legend = false, noise = true, pool = false, removed = false }"


def test_every_item_of_the_universe_ships_with_exactly_get_item_s_fields(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R77: category, legend, noise, removed and pool always (pool false until pool types arrive, #93); quality
    # when known (here from items.csv); species for a Species item. DATA-R16: 6358 is reachable only through
    # reference loot, so it is Noise and ships as other.
    assert records(write_tree(tmp_path, FISH), capsys) == {
        6303: fish(6303),
        6358: NOISE_6358,
        13759: fish(13759),
        19807: fish(19807),
    }


def test_a_non_noise_item_without_a_category_fails_listing_each_one(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R17: every non-Noise item of the universe needs a category; the generator fails listing them all.
    fails(
        write_tree(tmp_path, '[item.19807]\ncategory = "fish"\n'),
        capsys,
        "data/forever/items.toml: item.6303: no category; every item of the universe that isn't Noise needs one"
        " (DATA-R17): Raw Slitherskin Mackerel",
        "data/forever/items.toml: item.13759: no category;",
    )


def test_an_item_that_names_no_category_but_is_uncharted_stays_out_with_its_why(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R18: category = "uncharted" keeps an item out of the catalogue on purpose, with a why (DATA-R10).
    items = FISH.replace('[item.6303]\ncategory = "fish"', '[item.6303]\ncategory = "uncharted"\nwhy = "#90: unsure"')
    found = records(write_tree(tmp_path, items), capsys)
    assert 6303 not in found
    assert 13759 in found


def test_uncharted_noise_and_removed_need_a_why(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R10: a why is required on an items.toml entry that sets removed, category = "uncharted" or noise.
    items = (
        '[item.6303]\ncategory = "uncharted"\n\n'
        '[item.13759]\ncategory = "fish"\nremoved = true\nremovedFrom = 70338\n\n'
        '[item.19807]\ncategory = "fish"\nnoise = false\n\n'
        '[item.6358]\nnoise = true\nwhy = " "\n'
    )
    fails(
        write_tree(tmp_path, items),
        capsys,
        "items.toml: item.6303: missing key 'why': category = \"uncharted\" need",
        "items.toml: item.13759: missing key 'why': removed need",
        "items.toml: item.19807: missing key 'why': noise need",
        "items.toml: item.6358.why: empty",
    )


def test_a_consumable_is_noise_by_its_db2_class_and_noise_false_brings_it_back(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R16: ClassID 0 (Consumable) is a Noise class (Tunables), so a Consumable baseline item is Noise and ships
    # as other, with no category needed; its quality is still known (DATA-R77).
    db2_items = DB2_ITEMS.replace("6303,7,8,1,", "6303,0,5,1,")
    noise = '[item.13759]\ncategory = "fish"\n\n[item.19807]\ncategory = "fish"\n'
    found = records(write_tree(tmp_path, noise, db2_items), capsys)
    assert found[6303] == "{ category = \"other\", legend = false, noise = true, pool = false, quality = 1, removed = false }"
    # DATA-R16: items.toml may still write category = "other" for it.
    found = records(write_tree(tmp_path, noise + '\n[item.6303]\ncategory = "other"\n', db2_items), capsys)
    assert found[6303] == "{ category = \"other\", legend = false, noise = true, pool = false, quality = 1, removed = false }"
    # noise = false overrides the rule, and the item counts as its own category again.
    back = noise + '\n[item.6303]\ncategory = "fish"\nnoise = false\nwhy = "a fished food fish"\n'
    assert records(write_tree(tmp_path, back, db2_items), capsys)[6303] == fish(6303)


@pytest.mark.parametrize("class_id", [0, 2, 4, 9])
def test_each_noise_class_makes_an_item_noise(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], class_id: int
) -> None:
    # Tunables: Noise DB2 classes 0 Consumable, 2 Weapon, 4 Armor, 9 Recipe (DATA-R16).
    db2_items = DB2_ITEMS.replace("6303,7,8,1,", f"6303,{class_id},0,2,")
    items = '[item.13759]\ncategory = "fish"\n\n[item.19807]\ncategory = "fish"\n'
    assert '"other", legend = false, noise = true' in records(write_tree(tmp_path, items, db2_items), capsys)[6303]


def test_noise_true_overrides_the_rule_and_a_reference_item_with_noise_false_needs_a_category(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R16: noise = true makes any item Noise; noise = false on a reference-only item takes it out of Noise, so
    # DATA-R17 asks for its category.
    items = FISH.replace('[item.6303]\ncategory = "fish"', '[item.6303]\nnoise = true\nwhy = "a world drop"')
    assert records(write_tree(tmp_path, items), capsys)[6303] == (
        "{ category = \"other\", legend = false, noise = true, pool = false, quality = 1, removed = false }"
    )
    fails(
        write_tree(tmp_path, FISH + '\n[item.6358]\nnoise = false\nwhy = "fished"\n'),
        capsys,
        "items.toml: item.6358: no category; every item of the universe that isn't Noise needs one (DATA-R17)",
    )


def test_a_noise_item_with_another_category_or_a_legend_flag_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R16: the generator fails if a Noise item is given any other category or legend = true.
    items = FISH + '\n[item.6358]\ncategory = "junk"\nlegend = true\n'
    fails(
        write_tree(tmp_path, items),
        capsys,
        "items.toml: item.6358.category: item 6358 is Noise, so its category can only be other; set noise = false",
        "items.toml: item.6358.legend: item 6358 is Noise and can't be a Legend (DATA-R16)",
    )


def test_an_items_toml_entry_brings_an_item_into_the_universe(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R15: an items.toml entry puts an item in the universe though the baseline lacks it (Whimsyfin, 251524).
    db2_items = DB2_ITEMS + "251524,7,11,1,Whimsyfin\n"
    found = records(write_tree(tmp_path, FISH + '\n[item.251524]\ncategory = "fish"\n', db2_items), capsys)
    assert found[251524] == fish(251524)


def test_a_species_item_folds_into_a_representative_species_item(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R19: fish and questFish items are Species items; species = <id> folds one into another's Species. Other
    # categories carry no species.
    items = (
        '[item.6303]\ncategory = "questFish"\n\n[item.13759]\ncategory = "fish"\nspecies = 6303\n\n'
        '[item.19807]\ncategory = "junk"\n'
    )
    found = records(write_tree(tmp_path, items), capsys)
    assert found[6303] == fish(6303).replace('"fish"', '"questFish"')
    assert found[13759] == fish(13759).replace("species = 13759", "species = 6303")
    assert found[19807] == "{ category = \"junk\", legend = false, noise = false, pool = false, quality = 1, removed = false }"


@pytest.mark.parametrize(
    ("items", "problem"),
    [
        # The target is a Noise item (6358, reference-only), not a Species item.
        (FISH.replace('[item.13759]\ncategory = "fish"', '[item.13759]\ncategory = "fish"\nspecies = 6358'),
         "items.toml: item.13759.species: 6358 isn't a Species item, so item 13759 can't fold into it (DATA-R19)"),
        # The target is a junk item.
        (FISH.replace('[item.6303]\ncategory = "fish"', '[item.6303]\ncategory = "junk"')
         .replace('[item.13759]\ncategory = "fish"', '[item.13759]\ncategory = "fish"\nspecies = 6303'),
         "items.toml: item.13759.species: 6303 isn't a Species item"),
        # The target folds into another Species itself, so it isn't a representative (a Species ID).
        (FISH.replace('[item.6303]\ncategory = "fish"', '[item.6303]\ncategory = "fish"\nspecies = 19807')
         .replace('[item.13759]\ncategory = "fish"', '[item.13759]\ncategory = "fish"\nspecies = 6303'),
         "items.toml: item.13759.species: 6303 folds into 19807 itself, so it isn't a Species ID"),
        # An item outside the universe.
        (FISH.replace('[item.13759]\ncategory = "fish"', '[item.13759]\ncategory = "fish"\nspecies = 99999'),
         "99999 isn't a Species item"),
        # Only a Species item has a species.
        (FISH.replace('[item.6303]\ncategory = "fish"', '[item.6303]\ncategory = "junk"\nspecies = 13759'),
         "items.toml: item.6303.species: item 6303 isn't a Species item (fish or questFish), DATA-R19"),
    ],
)
def test_a_bad_species_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str], items: str, problem: str) -> None:
    # DATA-R19, DATA-R63: the target must be a Species item whose own species is itself.
    fails(write_tree(tmp_path, items), capsys, problem)


GROUPER = DB2_ITEMS + "13876,15,0,1,40 Pound Grouper\n"


def test_a_trophy_takes_its_weight_from_its_enus_name_and_ships_its_family(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R21: weight from the enUS DB2 name by the pattern ^(%d+) Pound  (Tunables), family declared in
    # families.toml; DATA-R77: family and weight on the record.
    items = FISH + '\n[item.13876]\ncategory = "trophy"\nfamily = 3\n'
    found = records(write_tree(tmp_path, items, GROUPER, families="[family.3]\n"), capsys)
    assert found[13876] == (
        "{ category = \"trophy\", family = 3, legend = false, noise = false, pool = false, quality = 1,"
        " removed = false, weight = 40 }"
    )
    # items.toml's weight wins over the name's.
    found = records(write_tree(tmp_path, items + "weight = 41\n", GROUPER, families="[family.3]\n"), capsys)
    assert "weight = 41" in found[13876]


@pytest.mark.parametrize(
    ("items", "db2_items", "families", "problem"),
    [
        ('[item.13876]\ncategory = "trophy"\n', GROUPER, "[family.3]\n",
         "items.toml: item.13876: item 13876 is a trophy and needs a family (DATA-R21)"),
        ('[item.13876]\ncategory = "trophy"\nfamily = 4\n', GROUPER, "[family.3]\n",
         "items.toml: item.13876.family: family 4 isn't declared in data/forever/families.toml (DATA-R21)"),
        ('[item.13876]\ncategory = "trophy"\nfamily = 3\n', DB2_ITEMS + "13876,15,0,1,Pound Grouper\n", "[family.3]\n",
         "items.toml: item.13876: item 13876 is a trophy and needs a weight"),
        # An item items.csv lacks has no enUS name to read a weight from.
        ('[item.13876]\ncategory = "trophy"\nfamily = 3\n', DB2_ITEMS, "[family.3]\n",
         "item 13876 is a trophy and needs a weight"),
        ('[item.13876]\ncategory = "fish"\nfamily = 3\nweight = 2\n', GROUPER, "[family.3]\n",
         "items.toml: item.13876.family: item 13876 isn't a trophy, so it has no family (DATA-R21)"),
        ('[item.13876]\ncategory = "trophy"\nfamily = 3\n', GROUPER, "[family.3]\nname = 'x'\n",
         "families.toml: family.3: unknown key 'name'"),
    ],
)
def test_a_bad_trophy_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], items: str, db2_items: str, families: str, problem: str
) -> None:
    # DATA-R21, DATA-R63: a bad family or weight fails.
    fails(write_tree(tmp_path, FISH + "\n" + items, db2_items, families=families), capsys, problem)


def test_legend_and_removed_ship_on_the_record(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R22: legend = true makes an item a Legend. DATA-R23: a removed item keeps its record, removed = true.
    items = (
        '[item.6303]\ncategory = "fish"\nremoved = true\nremovedFrom = 70338\nwhy = "#90 fixture"\n\n'
        '[item.13759]\ncategory = "fish"\n\n[item.19807]\ncategory = "fish"\nlegend = true\n'
    )
    found = records(write_tree(tmp_path, items), capsys)
    assert found[6303] == fish(6303).replace("removed = false", "removed = true")
    assert found[19807] == fish(19807).replace("legend = false", "legend = true")


@pytest.mark.parametrize(
    ("entry", "problem"),
    [
        ('removed = true\nwhy = "x"\n', "items.toml: item.6303: removed needs removedFrom, the first build"),
        ('removedFrom = 70338\nwhy = "x"\n', "items.toml: item.6303.removedFrom: removedFrom goes with removed = true"),
        ('removed = false\nremovedFrom = 1\nwhy = "x"\n', "item.6303.removed: only removed = true has a meaning"),
        ("removed = true\nremovedFrom = 0\nwhy = \"x\"\n", "item.6303.removedFrom: expected an integer at least 1"),
        ('legend = "yes"\n', "items.toml: item.6303.legend: expected a boolean, got a string"),
        ('quality = 6\n', "items.toml: item.6303.quality: expected an integer from 0 to 5, got 6"),
        ('class = -1\n', "items.toml: item.6303.class: expected an integer at least 0, got -1"),
        ('colour = "red"\n', "items.toml: item.6303: unknown key 'colour'"),
    ],
)
def test_a_malformed_items_toml_entry_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], entry: str, problem: str
) -> None:
    # DATA-R23 (removed with why and removedFrom), DATA-R63 (unknown keys, wrong types), DATA-R77 (quality 0-5).
    items = FISH.replace('[item.6303]\ncategory = "fish"', '[item.6303]\ncategory = "fish"\n' + entry.rstrip("\n"))
    fails(write_tree(tmp_path, items), capsys, problem)


@pytest.mark.parametrize(
    ("items", "problem"),
    [
        ('[item.x6303]\ncategory = "fish"\n', "items.toml: item.x6303: expected a positive integer ID as the key"),
        ('[item.6303]\ncategory = "fishy"\n', "items.toml: item.6303.category: expected one of fish, questFish,"),
        ("item = 1\n", "items.toml: item: expected a table, got an integer"),
        ('[things]\n', "items.toml: unknown key 'things'"),
    ],
)
def test_a_malformed_items_toml_fails_once_per_problem(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], items: str, problem: str
) -> None:
    # DATA-R63; #89's hand-off: the universe takes items.toml's IDs from its strict reader, so a bad key is reported
    # once, not again by the universe.
    write_tree(tmp_path, items)
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert output.count(problem) == 1, output


def test_class_and_quality_from_items_toml_count_until_db2_has_the_item(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R24: for an item items.csv lacks, items.toml may give class and quality; DB2 wins once it has the item.
    # DATA-R16: that class decides Noise by rule. DATA-R77: quality ships only when known.
    items = (
        FISH + '\n[item.2075]\nclass = 2\nquality = 2\n\n[item.6292]\ncategory = "junk"\n\n'
        '[item.6360]\ncategory = "fish"\nclass = 2\nquality = 3\nnoise = false\nwhy = "x"\n'
    )
    found = records(write_tree(tmp_path, items), capsys)
    assert found[2075] == "{ category = \"other\", legend = false, noise = true, pool = false, quality = 2, removed = false }"
    assert found[6292] == "{ category = \"junk\", legend = false, noise = false, pool = false, removed = false }"
    assert found[6360] == fish(6360, quality=3)
    # Once items.csv has 2075, its class (7, Trade Goods, not a Noise class) and quality (1) win.
    db2_items = DB2_ITEMS + "2075,7,0,1,Priest's Mace\n"
    with_db2 = items.replace("[item.2075]\nclass = 2\nquality = 2", '[item.2075]\ncategory = "other"\nclass = 2\nquality = 2')
    assert records(write_tree(tmp_path, with_db2, db2_items), capsys)[2075] == (
        "{ category = \"other\", legend = false, noise = false, pool = false, quality = 1, removed = false }"
    )


def test_typical_lengths_ship_on_every_item_of_the_species_and_need_a_species_id(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R20 (data emitted while its check is off, DATA-R66): species.toml's typicalLength, keyed by Species ID,
    # is emitted on every item of the Species.
    items = FISH.replace('[item.13759]\ncategory = "fish"', '[item.13759]\ncategory = "fish"\nspecies = 6303')
    found = records(write_tree(tmp_path, items, species="[species.6303]\ntypicalLength = 300\n"), capsys)
    assert found[6303] == fish(6303).replace("species = 6303", "species = 6303, typicalLength = 300")
    assert found[13759] == fish(13759).replace("species = 13759", "species = 6303, typicalLength = 300")
    fails(
        write_tree(tmp_path, items, species="[species.13759]\ntypicalLength = 300\n"),
        capsys,
        "species.toml: species.13759: 13759 isn't a Species ID",
    )
    fails(
        write_tree(tmp_path, items, species="[species.6303]\ntypicalLength = 0\n"),
        capsys,
        "species.toml: species.6303.typicalLength: expected an integer at least 1, got 0",
    )


def test_the_typical_length_check_runs_only_when_switched_on(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R66: typicalLength = false skips DATA-R20's check (the records above ship without one); true turns it on.
    fails(
        write_tree(tmp_path, FISH, species="[species.6303]\ntypicalLength = 300\n", checks="typicalLength = true\nlore = []\n"),
        capsys,
        "data/forever/species.toml: Species 13759 has no typicalLength, and the check is on (DATA-R20, DATA-R66)",
        "Species 19807 has no typicalLength",
    )


@pytest.mark.parametrize(
    ("checks", "problem"),
    [
        ("typicalLength = false\n", "data/checks.toml: missing key 'lore'"),
        ("typicalLength = 0\nlore = []\n", "data/checks.toml: typicalLength: expected a boolean, got an integer"),
        ('typicalLength = false\nlore = ["fishing"]\n', "data/checks.toml: lore[0]: expected a lore ID"),
        # No lore check is built before M3 (DATA-R107): switching one on fails instead of passing unchecked.
        ('typicalLength = false\nlore = ["ledger"]\n', "data/checks.toml: lore[0]: the ledger lore check isn't built"),
        (None, "data/checks.toml: missing"),
    ],
)
def test_checks_toml_holds_both_switches(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], checks: str | None, problem: str
) -> None:
    # DATA-R66 and the Data section: data/checks.toml holds typicalLength (boolean) and lore (lore IDs).
    write_tree(tmp_path, FISH, checks=checks or "")
    if checks is None:
        (tmp_path / "data" / "checks.toml").unlink()
    fails(tmp_path, capsys, problem)


@pytest.mark.parametrize("name", ["items.toml", "species.toml", "families.toml"])
def test_the_item_layer_s_files_are_required(tmp_path: Path, capsys: pytest.CaptureFixture[str], name: str) -> None:
    # DATA-R10: data/forever/ holds one file per table, items.toml, species.toml and families.toml among them.
    write_tree(tmp_path, FISH)
    (tmp_path / "data" / "forever" / name).unlink()
    fails(tmp_path, capsys, f"data/forever/{name}: missing")


def test_no_item_name_reaches_the_catalogue(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R3: the enUS names in items.csv never ship, though the trophy weight is read from one.
    items = FISH + '\n[item.13876]\ncategory = "trophy"\nfamily = 3\n'
    write_tree(tmp_path, items, GROUPER, families="[family.3]\n")
    run(tmp_path, capsys)
    text = (tmp_path / CATALOGUE).read_text(encoding="utf-8")
    for name in ("Slitherskin", "Nightfin", "Tastyfish", "Grouper"):
        assert name not in text
