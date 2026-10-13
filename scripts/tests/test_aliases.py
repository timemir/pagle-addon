"""The alias table (DATA-R10, DATA-R32, DATA-R63, DATA-R64): data/forever/aliases.toml, its checks, the proposals
--propose-aliases prints, and the catalogue's aliases."""

from pathlib import Path

import pytest

from baseline_fixture import CSVS, write_baseline
from pagle_data.cli import main

CATALOGUE = "addons/Pagle/data/Catalogue.lua"

# An AreaTable slice (DATA-R11) with a baseline zone and subzone on continent 0, and a copy of them on continent
# 2940, as Forever has (docs/research/localized-identity.md).
AREAS = """\
ID,ParentAreaID,ContinentID,AreaName_lang
12,0,0,Elwynn Forest
18,12,0,Crystal Lake
19,16510,2940,Crystal Lake
40,0,0,Westfall
300,12,0,Crystal Lake
16510,0,2940,Elwynn Forest
16521,16510,2940,Crystal Lake
16522,16510,2940,Stone Cairn Lake
16530,16531,2940,Crystal Lake
16531,0,2940,Westfall
"""

# In M1 an area's catch list is its rows in area_loot.csv (roadmap M1). 12, 18, 19 and 40 have one.
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
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text('build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n', encoding="utf-8")
    (db2 / "areas.csv").write_text(AREAS, encoding="utf-8")
    write_baseline(root, {**CSVS, "area_loot.csv": AREA_LOOT})
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
