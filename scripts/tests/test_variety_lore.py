"""The varieties' and fish crests' lore (VAR-R11, VAR-R12, DATA-R134, DATA-R135) over small fixture data/ trees: Core's
variety kind and its limits, the manifest covering exactly varieties.toml, the one "{fish} Crest" name pattern, and
no game name (DATA-R3) in any of it."""

from pathlib import Path

import pytest

from cli_fixture import run
from test_lore import LEDGER, MANIFEST, fails, write_lore_tree

CORE_FILE = "data/lore/core.toml"
CORE_LUA = "addons/Pagle/data/Lore.lua"
KEYS = ["plain", "blue", "green", "spotted", "barred", "red", "glass", "golden", "ink", "starlit"]
CHECKS = 'typicalLength = false\nlore = ["ledger", "core"]\nvarieties = true\n'
# 13759 (Raw Nightfin Snapper in the fixture's items.csv) is the one sized, non-Legend Species: 6303 has no typical
# length and 19807 is a Legend.
SPECIES = "[species.13759]\ntypicalLength = 550\n"
VARIETIES = "[varieties.13759]\nkeys = [" + ", ".join(f'"{key}"' for key in KEYS) + "]\n"
AREAS = "ID,ParentAreaID,ContinentID,AreaName_lang\n1,0,0,Dun Morogh\n2,1,0,The Mine Shaft\n3,0,0,Everlook\n"

CORE_MANIFEST = (
    MANIFEST
    + '\n[core.good]\nfields = ["name", "description"]\nids = [{ id = "core.crest.fish.13759", placeholders = ["fish"] }]\n'
    + '\n[core.variety]\nfields = ["name", "description"]\nids = ['
    + ", ".join(f'"13759.{key}"' for key in KEYS)
    + "]\n"
)
CREST = '[good."core.crest.fish.13759"]\nname = "{fish} Crest"\ndescription = "A snapper on dark water, for a full set."\n'
CORE = (
    CREST
    + "\n"
    + "\n".join(f'[variety."13759.{key}"]\nname = "{key.title()}"\ndescription = "A {key} one."\n' for key in KEYS)
)


def _tree(
    root: Path, core: str = CORE, manifest: str = CORE_MANIFEST, varieties: str = VARIETIES, areas: str = AREAS
) -> Path:
    write_lore_tree(root, LEDGER, manifest, checks=CHECKS, core=core)
    (root / "data" / "forever" / "species.toml").write_text(SPECIES, encoding="utf-8")
    (root / "data" / "forever" / "varieties.toml").write_text(varieties, encoding="utf-8")
    (root / "data" / "db2" / "areas.csv").write_text(areas, encoding="utf-8")
    return root


def test_variety_and_fish_crest_lore_passes_and_is_emitted(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # VAR-R11: each variety's name and description are Core's lore; VAR-R12: a fish crest's name is "{fish} Crest",
    # its {fish} filled at runtime with the Species' item name, so the pattern ships as it is.
    code, output = run(_tree(tmp_path), capsys)
    assert code == 0, output
    lua = (tmp_path / CORE_LUA).read_text(encoding="utf-8")
    assert 'L["good.core.crest.fish.13759.name"] = "{fish} Crest"\n' in lua
    assert 'L["variety.13759.golden.name"] = "Golden"\n' in lua
    assert 'L["variety.13759.golden.description"] = "A golden one."\n' in lua


def test_a_variety_s_name_and_description_have_their_limits(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R134, Tunables › Lore limits: a variety's name 28 code points (every name's) and its description 200.
    exact = CORE.replace('description = "A plain one."', f'description = "{"x" * 200}"')
    assert run(_tree(tmp_path / "exact", exact), capsys)[0] == 0
    fails(
        _tree(tmp_path / "over", CORE.replace('description = "A plain one."', f'description = "{"x" * 201}"')),
        capsys,
        f"{CORE_FILE}: variety.13759.plain.description: length: 201 code points, over description's limit of 200",
    )
    fails(
        _tree(tmp_path / "name", CORE.replace('name = "Plain"', f'name = "{"x" * 29}"')),
        capsys,
        f"{CORE_FILE}: variety.13759.plain.name: length: 29 code points, over name's limit of 28",
    )


@pytest.mark.parametrize(
    ("manifest", "problem"),
    [
        (
            CORE_MANIFEST.replace('"13759.blue", ', ""),
            "manifest.toml: core.variety.ids: '13759.blue' is a variety in data/forever/varieties.toml but isn't"
            " listed (VAR-R11, DATA-R134)",
        ),
        (
            CORE_MANIFEST.replace('"13759.blue"', '"13759.blue", "13759.azure"'),
            "manifest.toml: core.variety.ids: '13759.azure' isn't a variety in data/forever/varieties.toml",
        ),
        (
            CORE_MANIFEST.replace('{ id = "core.crest.fish.13759", placeholders = ["fish"] }', '"core.a.x"'),
            "manifest.toml: core.good.ids: 'core.crest.fish.13759' is missing: each Species with varieties has a fish"
            " crest (VAR-R12, DATA-R134)",
        ),
        (
            CORE_MANIFEST.replace('placeholders = ["fish"] }', 'placeholders = ["fish"] }, "core.crest.fish.6303"'),
            "manifest.toml: core.good.ids: 'core.crest.fish.6303' isn't a fish crest of a Species in",
        ),
        (
            CORE_MANIFEST.replace('placeholders = ["fish"]', "placeholders = []"),
            "manifest.toml: core.good.ids: 'core.crest.fish.13759' must allow {fish} and only it",
        ),
        (
            CORE_MANIFEST.replace('id = "zonemaster", placeholders = ["zone"]', 'id = "zonemaster", placeholders = ["fish"]'),
            "manifest.toml: ledger.title.ids: 'zonemaster': only a fish crest's entry allows {fish} (VAR-R12, DATA-R108)",
        ),
    ],
)
def test_the_manifest_covers_exactly_the_varieties_and_their_crests(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], manifest: str, problem: str
) -> None:
    # DATA-R134: [core.variety] lists exactly varieties.toml's IDs, and [core.good] a fish crest for exactly its
    # Species, each allowing {fish}, which nothing else allows.
    fails(_tree(tmp_path, manifest=manifest), capsys, problem)


@pytest.mark.parametrize(
    ("core", "problem"),
    [
        (
            CORE.replace('name = "{fish} Crest"', 'name = "Snapper Crest"'),
            f"{CORE_FILE}: good.core.crest.fish.13759.name: a fish crest's name is the one pattern \"{{fish}} Crest\","
            " got 'Snapper Crest' (VAR-R12, DATA-R134)",
        ),
        (
            CORE.replace("A snapper on dark water", "A {fish} on dark water"),
            f"{CORE_FILE}: good.core.crest.fish.13759.description: {{fish}} in it; a fish crest's description never"
            " names the fish (VAR-R12, DATA-R134)",
        ),
    ],
)
def test_a_fish_crest_s_name_is_the_one_pattern_and_its_description_never_names_the_fish(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], core: str, problem: str
) -> None:
    fails(_tree(tmp_path, core), capsys, problem)


@pytest.mark.parametrize(
    ("old", "new", "key", "name"),
    [
        # An area's name, a zone's or a subzone's, matched with its capitals.
        ('name = "Golden"', 'name = "Everlook Gold"', "variety.13759.golden.name", "Everlook"),
        ('"A red one."', '"Caught off Dun Morogh."', "variety.13759.red.description", "Dun Morogh"),
        ('"A red one."', '"Lives in The Mine Shaft."', "variety.13759.red.description", "The Mine Shaft"),
        # A Species item's name, ignoring case, with and without its leading "Raw ".
        ('"A red one."', '"The reddest nightfin snapper."', "variety.13759.red.description", "nightfin snapper"),
        ('"A red one."', '"Like a raw nightfin snapper."', "variety.13759.red.description", "raw nightfin snapper"),
        ('"A red one."', '"Kin to the Slitherskin Mackerel."', "variety.13759.red.description", "Slitherskin Mackerel"),
        ("A snapper on dark water", "A Nightfin Snapper on dark water", "good.core.crest.fish.13759.description",
         "Nightfin Snapper"),
    ],
)
def test_variety_or_crest_lore_that_names_a_game_place_or_fish_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], old: str, new: str, key: str, name: str
) -> None:
    # DATA-R135 (DATA-R3): no game name ships through variety or fish crest lore.
    fails(
        _tree(tmp_path, CORE.replace(old, new)),
        capsys,
        f"{CORE_FILE}: {key}: holds the game name '{name}'; no game name ships (DATA-R3, DATA-R135)",
    )


@pytest.mark.parametrize(
    "description",
    [
        "Found down a mine shaft.",  # an area's name in plain lower case is plain English
        "Everlooking, ever hungry.",  # inside a longer word
        "A snapper that bites at night.",  # a word of a fish's name alone
    ],
)
def test_plain_words_pass_the_game_name_check(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], description: str
) -> None:
    # DATA-R135: areas match as whole words with their capitals; fish names as whole names.
    code, output = run(_tree(tmp_path, CORE.replace('"A red one."', f'"{description}"')), capsys)
    assert code == 0, output


def test_the_game_name_check_runs_with_core_s_lore_check_off(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R3 holds whatever data/checks.toml says.
    root = _tree(tmp_path, CORE.replace('"A red one."', '"Caught off Dun Morogh."'))
    (root / "data" / "checks.toml").write_text('typicalLength = false\nlore = ["ledger"]\n', encoding="utf-8")
    fails(root, capsys, f"{CORE_FILE}: variety.13759.red.description: holds the game name 'Dun Morogh'")
