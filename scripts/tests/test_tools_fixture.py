"""How a test finds the pinned tools (tools_fixture, DATA-R61's gate): where scripts/check.sh finds them, a fresh
worktree's from its main checkout, and a missing one skipped locally but failed in CI."""

import subprocess
from pathlib import Path

import pytest

from tools_fixture import REPO, tool, tools_dir


def git(cwd: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True)


def test_data_r61_tools_are_where_pagle_tools_names(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("PAGLE_TOOLS", str(tmp_path))
    assert tools_dir() == tmp_path


def test_data_r61_a_worktree_with_no_tools_runs_its_main_checkouts(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.delenv("PAGLE_TOOLS", raising=False)
    main = tmp_path / "main"
    (main / "scripts" / "lib").mkdir(parents=True)
    (main / "scripts" / "lib" / "tools.sh").write_text((REPO / "scripts" / "lib" / "tools.sh").read_text())
    git(main, "init", "-q", "-b", "main")
    git(main, "add", ".")
    git(main, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "tools.sh")
    (main / ".tools").mkdir()
    (main / ".tools" / "tools.env").write_text("")
    git(main, "worktree", "add", "-q", str(tmp_path / "fresh"))

    assert tools_dir(tmp_path / "fresh").resolve() == (main / ".tools").resolve()
    assert tools_dir(main).resolve() == (main / ".tools").resolve()


def test_data_r61_a_missing_tool_skips_with_where_it_looked(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.delenv("CI", raising=False)
    with pytest.raises(pytest.skip.Exception, match=f"no {tmp_path}/bin/lua: run scripts/setup.sh"):
        tool("bin/lua", tmp_path)


def test_data_r61_a_missing_tool_fails_in_ci(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("CI", "true")
    with pytest.raises(pytest.fail.Exception, match="CI installs every tool"):
        tool("bin/lua", tmp_path)


def test_data_r61_a_tool_that_is_there_is_its_path(tmp_path: Path) -> None:
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin" / "lua").write_text("")
    assert tool("bin/lua", tmp_path) == tmp_path / "bin" / "lua"
