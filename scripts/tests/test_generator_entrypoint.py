"""Real CLI failures preserve the input snapshot and committed generated files."""

import re
import shutil
import subprocess
import sys
from collections.abc import Mapping
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
HUNT = '''
[[set]]
id = "planted"
name = "Planted"
title = "the Planter"

[[hunt]]
id = "planted"
set = "planted"
since = 2026-11-04
tiers = [1]
name = "Planted"
species = 13759
'''
# A missing pattern appends the replacement; otherwise the mutation must match exactly once.
CASES = [
    (
        "db2/areas.csv",
        None,
        "x1,0,0,Planted\n",
        "ID: expected a positive integer, got 'x1'",
    ),
    (
        "baseline/skill.csv",
        r"(?m)^1,",
        "2,",
        "its SHA-256 differs from data/baseline/source.toml",
    ),
    (
        "forever/aliases.toml",
        None,
        "\n[[alias]]\nfrom = 16562\nto = 267\n",
        "alias[10]: missing key 'why'",
    ),
    (
        "forever/items.toml",
        r"(?m)(^\[item\.13759\]\n)[^\n]+\n",
        r"\1",
        "item.13759: no category",
    ),
    (
        "forever/windows.toml",
        r"(?m)(^\[window\.spring\]\n[^\n]+\n)[^\n]+\n",
        r"\1",
        "window.spring: missing key 'why'",
    ),
    (
        "forever/areas.toml",
        None,
        "\n[[catch]]\narea = 33\nitem = 6303\nop = \"add\"\ngate = \"dusk\"\nwhy = \"planted\"\n",
        "gate: 'dusk' isn't a window ID (DATA-R35)",
    ),
    (
        "forever/pools.toml",
        None,
        "\n[pool.planted]\nentries = [999999]\n",
        "pool.planted: missing key 'why'",
    ),
    (
        "observed/dev.toml",
        r"\A",
        "colour = \"red\"\n",
        "unknown key 'colour'",
    ),
    (
        "lore/ledger.toml",
        r"(?m)(^\[species\.13759\][^\n]*\n(?:[^\n]+\n)*?)riddle = [^\n]+",
        r'\1riddle = "' + "x" * 81 + '"',
        "species.13759.riddle: length: 81 code points, over riddle's limit of 80",
    ),
    (
        "forever/species.toml",
        r"(?m)^\[species\.13759\]\n[^\n]+\n",
        "",
        "Species 13759 has no typicalLength, and the check is on (DATA-R20, DATA-R66)",
    ),
    (
        "hunts/hunts.toml",
        None,
        HUNT + "kind = \"natural\"\nwindow = \"day\"\n",
        "hunt.planted: admission: no catch entry of Species 13759's items, in any area, has the gate 'day'",
    ),
    (
        "hunts/hunts.toml",
        None,
        HUNT + "kind = \"imposed\"\nconditions = { season = [{ from = [6, 1], to = [6, 2] }], time = [[720, 750]] }\n",
        "hunt.planted: rarity cap: open at 8 of 70080 steps",
    ),
]


@pytest.fixture
def cli_tree(tmp_path: Path, repo_outputs: Mapping[str, str]) -> Path:
    shutil.copytree(REPO / "data", tmp_path / "data")
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    shutil.copy2(REPO / "scripts/generate-data.py", scripts / "generate-data.py")
    (scripts / "pagle_data").symlink_to(REPO / "scripts/pagle_data", target_is_directory=True)
    for name in repo_outputs:
        destination = tmp_path / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / name, destination)
    return tmp_path


def snapshot(root: Path) -> dict[str, bytes]:
    return {
        str(path.relative_to(root)): path.read_bytes()
        for directory in (root / "data", root / "addons")
        for path in directory.rglob("*")
        if path.is_file()
    }


def run_check(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(root / "scripts/generate-data.py"), "--check"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )


def test_valid_repository_passes_the_real_cli_without_writes(cli_tree: Path) -> None:
    before = snapshot(cli_tree)
    result = run_check(cli_tree)
    assert result.returncode == 0, result.stdout + result.stderr
    assert snapshot(cli_tree) == before


@pytest.mark.parametrize(
    ("name", "pattern", "replacement", "diagnostic"),
    CASES,
    ids=[
        "noninteger-area",
        "baseline-hash",
        "alias-why",
        "item-category",
        "window-why",
        "unknown-catch-window",
        "pool-why",
        "unknown-observation-key",
        "riddle-length",
        "missing-typical-length",
        "natural-hunt-admission",
        "imposed-hunt-rarity",
    ],
)
def test_invalid_data_fails_the_real_cli_without_writes(
    cli_tree: Path, name: str, pattern: str | None, replacement: str, diagnostic: str
) -> None:
    path = cli_tree / "data" / name
    original = path.read_text(encoding="utf-8")
    if pattern is None:
        changed = original + replacement
    else:
        changed, count = re.subn(pattern, replacement, original)
        assert count == 1, name
    path.write_text(changed, encoding="utf-8")
    before = snapshot(cli_tree)
    result = run_check(cli_tree)
    assert result.returncode != 0, result.stdout + result.stderr
    assert diagnostic in result.stdout + result.stderr
    assert snapshot(cli_tree) == before
