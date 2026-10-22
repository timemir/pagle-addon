"""Exercise the workflow's change detector against real Git history."""

import os
from pathlib import Path
import subprocess
import textwrap

import pytest


@pytest.fixture
def detector() -> str:
    workflow = Path(__file__).resolve().parents[2] / ".github/workflows/check.yml"
    step = workflow.read_text().split("      - name: Find whether the gate's machinery changed\n", 1)[1]
    lines = step.split("        run: |\n", 1)[1].splitlines()
    body: list[str] = []
    for line in lines:
        if line and not line.startswith("          "):
            break
        body.append(line)
    return textwrap.dedent("\n".join(body))


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "-C", str(repo), *args],
        text=True,
    ).strip()


@pytest.fixture
def history(tmp_path: Path) -> tuple[Path, str]:
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "ci@example.test")
    git(tmp_path, "config", "user.name", "CI test")
    git(tmp_path, "commit", "-qm", "base", "--allow-empty")
    return tmp_path, git(tmp_path, "rev-parse", "HEAD")


def run_detector(detector: str, repo: Path, event: str, before: str = "", pr_base: str = "") -> bool:
    output = repo / "output"
    subprocess.run(
        ["bash", "-e", "-o", "pipefail", "-c", detector], cwd=repo, check=True,
        env={**os.environ, "EVENT": event, "BEFORE": before, "PR_BASE": pr_base,
             "GITHUB_OUTPUT": str(output)}, capture_output=True, text=True,
    )
    result = output.read_text().strip()
    assert result in {"run=true", "run=false"}
    return result == "run=true"


@pytest.mark.parametrize("event", ["push", "pull_request"])
@pytest.mark.parametrize("path,expected", [
    *[(path, True) for path in (
        "scripts/check.sh", "scripts/test-check.sh", "scripts/setup.sh", "scripts/tools.env",
        "scripts/generate-data.py", "scripts/pyproject.toml", "scripts/ace3.sha256",
        "scripts/api-presence.lua", "scripts/api-inventory.lua", "scripts/pagle_data/generate.py",
        "spec/support/wow.lua", "spec/Pagle/adapter/Core_spec.lua", "spec/Pagle/Pagle_toc_spec.lua",
        "spec/Pagle_QoL/Pagle_QoL_toc_spec.lua", "types/wow.lua", ".luacheckrc", ".luarc.json",
        ".stylua.toml", ".styluaignore", ".luacov", ".busted",
        ".github/workflows/check.yml", ".github/workflows/release.yml",
    )],
    *[(path, False) for path in (
        "docs/guide.md", "scripts/tests/test_files.py", "scripts/render-sounds.py",
        "scripts/import-field-report.py", ".github/workflows/other.yml", "spec/Pagle/Catch_spec.lua",
    )],
])
def test_changed_path(detector: str, history: tuple[Path, str], event: str, path: str, expected: bool) -> None:
    repo, base = history
    changed = repo / path
    changed.parent.mkdir(parents=True, exist_ok=True)
    changed.write_text("changed\n")
    git(repo, "add", path)
    git(repo, "commit", "-qm", "change")
    assert run_detector(detector, repo, event, before=base, pr_base=base) is expected


@pytest.mark.parametrize("event,before,pr_base", [
    ("workflow_dispatch", "", ""), ("push", "", ""), ("push", "0" * 40, ""),
    ("push", "f" * 40, ""), ("pull_request", "", ""), ("pull_request", "", "f" * 40),
])
def test_missing_base_runs_conservatively(
    detector: str, history: tuple[Path, str], event: str, before: str, pr_base: str,
) -> None:
    repo, _ = history
    assert run_detector(detector, repo, event, before, pr_base)


def test_new_push_uses_available_main_base(detector: str, history: tuple[Path, str]) -> None:
    repo, base = history
    git(repo, "update-ref", "refs/remotes/origin/main", base)
    assert not run_detector(detector, repo, "push", before="0" * 40)


def commit_file(repo: Path, path: str) -> str:
    changed = repo / path
    changed.parent.mkdir(parents=True, exist_ok=True)
    changed.write_text("changed\n")
    git(repo, "add", path)
    git(repo, "commit", "-qm", path)
    return git(repo, "rev-parse", "HEAD")


def test_push_checks_every_commit_since_before(detector: str, history: tuple[Path, str]) -> None:
    repo, base = history
    commit_file(repo, "scripts/check.sh")
    commit_file(repo, "docs/guide.md")
    assert run_detector(detector, repo, "push", before=base)


@pytest.mark.parametrize("before_is_head", [False, True])
def test_pull_request_uses_its_base_without_a_push_before(
    detector: str, history: tuple[Path, str], before_is_head: bool,
) -> None:
    repo, base = history
    head = commit_file(repo, "scripts/check.sh")
    assert run_detector(detector, repo, "pull_request", before=head if before_is_head else "", pr_base=base)


def test_pull_request_excludes_machinery_already_in_its_base(detector: str, history: tuple[Path, str]) -> None:
    repo, before = history
    base = commit_file(repo, "scripts/check.sh")
    commit_file(repo, "docs/guide.md")
    assert not run_detector(detector, repo, "pull_request", before=before, pr_base=base)
