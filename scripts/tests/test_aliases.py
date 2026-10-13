"""The alias table (DATA-R10, DATA-R32, DATA-R63, DATA-R64): data/forever/aliases.toml, its checks, the proposals
--propose-aliases prints, and the catalogue's aliases."""

from pathlib import Path

import pytest

from areas_fixture import write_areas
from baseline_fixture import CSVS, write_baseline
from item_fixture import write_item_layer
from observed_fixture import write_observed
from pagle_data.cli import main
from pools_fixture import write_pools
from windows_fixture import write_windows

CATALOGUE = "addons/Pagle/data/Catalogue.lua"

# An AreaTable slice (DATA-R11) with a baseline zone and subzone on continent 0, and a copy of them on continent
# 2940, as Forever has (docs/research/localized-identity.md).
AREAS = """\
ID,ParentAreaID,ContinentID,AreaName_lang
12,0,0,Elwynn Forest
18,12,0,Crystal Lake
19,16510,2940,Crystal Lake
40,0,0,Westfall
300,0,0,Westfall
16510,0,2940,Elwynn Forest
16521,16510,2940,Crystal Lake
16522,16510,2940,Stone Cairn Lake
16530,16531,2940,Crystal Lake
16531,0,2940,Westfall
"""

# 6291 is a fish, so 12, 18, 19 and 40 each have a catch list (DATA-R26); test_catch_lists.py covers the lists.
AREA_LOOT = """\
area,item,chance,ref,event,condition
12,6291,55.5,,,
18,6291,44.4,,,
19,6291,33.3,,,
40,6291,22.2,,,
"""


def write_tree(root: Path, aliases: str = "") -> Path:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "events.toml").write_text("", encoding="utf-8")
    (forever / "lists.toml").write_text("auras = []\nfishingSpells = [7620]\n", encoding="utf-8")
    (forever / "aliases.toml").write_text(aliases, encoding="utf-8")
    write_windows(root)  # test_windows.py covers windows
    write_areas(root)  # test_catch_lists.py covers areas.toml
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text('build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n', encoding="utf-8")
    (db2 / "areas.csv").write_text(AREAS, encoding="utf-8")
    (db2 / "items.csv").write_text("ID,ClassID,SubclassID,OverallQualityID,Display_lang\n", encoding="utf-8")
    write_baseline(root, {**CSVS, "area_loot.csv": AREA_LOOT})
    write_observed(root)  # dev.toml with no facts; test_observed.py covers the layer
    # 6291 is this tree's area loot; test_item_records.py covers the item layer.
    write_item_layer(root, '[item.6291]\ncategory = "fish"\n\n[item.19807]\ncategory = "fish"\n')
    write_pools(root)  # test_pools.py covers pool types
    return root


def alias(source: int, target: int, why: str | None = "the map 2940 copy") -> str:
    entry = f"[[alias]]\nfrom = {source}\nto = {target}\n"
    return entry + (f'why = "{why}"\n' if why is not None else "")


def run(root: Path, capsys: pytest.CaptureFixture[str], *args: str) -> tuple[int, str]:
    code = main(list(args), root)
    out, err = capsys.readouterr()
    return code, out + err


def test_the_catalogue_s_aliases_are_aliases_toml_s(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R76 and the Contracts section: `aliases = { [16521] = 18 }`, areaID → baseline areaID, from aliases.toml.
    write_tree(tmp_path, alias(16521, 18) + alias(16510, 12))
    code, _ = run(tmp_path, capsys)
    assert code == 0
    text = (tmp_path / CATALOGUE).read_text(encoding="utf-8")
    assert "\taliases = { [16510] = 12, [16521] = 18 },\n" in text


@pytest.mark.parametrize("mode", [[], ["--check"]])
@pytest.mark.parametrize(
    ("entry", "problem"),
    [
        (alias(16521, 18, why=None), "data/forever/aliases.toml: alias[1]: missing key 'why'"),
        (alias(16521, 18, why=" "), "data/forever/aliases.toml: alias[1].why: empty"),
    ],
)
def test_an_alias_without_a_why_fails_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], entry: str, problem: str, mode: list[str]
) -> None:
    # DATA-R10: a why is required on every entry of aliases.toml, and the generator fails on one without it;
    # DATA-R63: writing nothing.
    write_tree(tmp_path, alias(16510, 12) + entry)
    code, output = run(tmp_path, capsys, *mode)
    assert code == 1
    assert problem in output
    assert not (tmp_path / CATALOGUE).exists()


def test_aliases_toml_s_keys_and_types_are_checked(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: an unknown key or a wrong type in any TOML file under data/; aliases.toml's keys are the Data
    # section's (`[[alias]]` with from, to, why). An area aliased twice can't be emitted, so it fails too.
    write_tree(tmp_path, 'note = 1\n[[alias]]\nfrom = "16521"\nto = 18\nwhy = 3\nmap = 2940\n' + alias(16510, 12) * 2)
    code, output = run(tmp_path, capsys)
    assert code == 1
    for problem in [
        "data/forever/aliases.toml: unknown key 'note'",
        "data/forever/aliases.toml: alias[0]: unknown key 'map'",
        "data/forever/aliases.toml: alias[0].from: expected an integer, got a string",
        "data/forever/aliases.toml: alias[0].why: expected a string, got an integer",
        "data/forever/aliases.toml: alias[2].from: area 16510 is aliased twice",
    ]:
        assert problem in output


@pytest.mark.parametrize("mode", [[], ["--check"]])
@pytest.mark.parametrize(
    ("entries", "problem"),
    [
        # 16510 is a copy of Elwynn Forest with no catch list of its own: no area stands for it.
        (alias(16522, 16510), "alias[0].to: area 16510 has no baseline catch list"),
        # 19 has its own area_loot.csv rows, so it can't stand for 18.
        (alias(19, 18), "alias[0].from: area 19 has a catch list of its own"),
        # 16521 is an alias source, so it can't be a target.
        (alias(16521, 18) + alias(16530, 16521), "alias[1].to: area 16521 is itself an alias source"),
        (alias(16521, 16521), "alias[0]: from and to are both 16521"),
    ],
    ids=["target-without-catch-list", "source-with-catch-list", "target-is-a-source", "source-is-target"],
)
def test_a_bad_alias_fails_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], entries: str, problem: str, mode: list[str]
) -> None:
    # DATA-R32: "The generator fails if an alias's target has no baseline catch list, its source has a catch list of
    # its own, a target is itself an alias source, or source equals target." DATA-R63: writing nothing. In M1 a
    # catch list is the area's area_loot.csv rows (roadmap M1).
    write_tree(tmp_path, entries)
    code, output = run(tmp_path, capsys, *mode)
    assert code == 1
    assert f"data/forever/aliases.toml: {problem}" in output
    assert not (tmp_path / CATALOGUE).exists()


def test_propose_aliases_prints_each_candidate_ready_to_commit_and_writes_nothing(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R32: a candidate is an area with no catch list whose enUS name and parent's enUS name equal a baseline
    # fishing area's, on a different ContinentID. In AREAS those are 16510 (→ 12), 16521 (→ 18) and 16531 (→ 40, two
    # zones, so neither has a parent). Not 19 (its own catch list), 300 (on 40's continent), 16522 (no fishing area
    # has its name) or 16530 (a Crystal Lake, but in Westfall). The output is aliases.toml's shape, with an empty
    # why the dev must fill before the generator accepts it (DATA-R10).
    write_tree(tmp_path)
    code, output = run(tmp_path, capsys, "--propose-aliases")
    assert code == 0
    blocks = [
        "[[alias]]\nfrom = 16510  # Elwynn Forest, continent 2940\nto = 12  # Elwynn Forest, continent 0\nwhy = \"\"\n",
        "[[alias]]\nfrom = 16521  # Crystal Lake (Elwynn Forest), continent 2940\n"
        "to = 18  # Crystal Lake (Elwynn Forest), continent 0\nwhy = \"\"\n",
        "[[alias]]\nfrom = 16531  # Westfall, continent 2940\nto = 40  # Westfall, continent 0\nwhy = \"\"\n",
    ]
    assert "\n".join(blocks) in output
    assert output.count("[[alias]]") == 3
    assert not (tmp_path / CATALOGUE).exists()


def test_a_committed_alias_is_no_longer_proposed(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R32: "A proposal takes effect only when committed to aliases.toml"; once it is, it is not a candidate.
    write_tree(tmp_path, alias(16521, 18))
    code, output = run(tmp_path, capsys, "--propose-aliases")
    assert code == 0
    assert "from = 16521" not in output
    assert output.count("[[alias]]") == 2


@pytest.mark.parametrize("mode", [[], ["--check"]])
def test_every_run_sums_up_the_uncommitted_proposals_in_one_warning_until_they_are_committed(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], mode: list[str]
) -> None:
    # DATA-R64: uncommitted alias proposals are one warning, printed, not failing, on every run: their count and
    # where to list them (--propose-aliases lists each, DATA-R32). DATA-R32: once committed to aliases.toml, a
    # proposal is no longer one; with none left, no warning.
    summary = "uncommitted alias proposals; run scripts/generate-data.py --propose-aliases to list them"
    write_tree(tmp_path)
    run(tmp_path, capsys)
    code, output = run(tmp_path, capsys, *mode)
    assert code == 0
    assert f"generate-data: warning: 3 {summary}\n" in output
    assert output.count("warning") == 1, output

    write_tree(tmp_path, alias(16521, 18))
    run(tmp_path, capsys)
    code, output = run(tmp_path, capsys, *mode)
    assert code == 0
    assert f"generate-data: warning: 2 {summary}\n" in output
    assert output.count("warning") == 1, output

    write_tree(tmp_path, alias(16510, 12) + alias(16521, 18) + alias(16531, 40))
    run(tmp_path, capsys)
    code, output = run(tmp_path, capsys, *mode)
    assert code == 0
    assert "warning" not in output, output
