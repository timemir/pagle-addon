"""Exercise the Check workflow's change detector against real Git history, and hold the Release workflow (and
the Check workflow's release-zip step) to what they may publish (CORE-R74)."""

import os
from pathlib import Path
import subprocess
import textwrap

import pytest

ROOT = Path(__file__).resolve().parents[2]


def workflow_text(name: str) -> str:
    return (ROOT / ".github/workflows" / name).read_text()


def mapping(text: str, header: str) -> dict[str, str]:
    """The `key: value` lines indented one level under the first line that is exactly `header`, comments dropped."""
    lines = text.splitlines()
    indent = len(header) - len(header.lstrip())
    found: dict[str, str] = {}
    for line in lines[lines.index(header) + 1:]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if len(line) - len(line.lstrip()) <= indent:
            break
        key, _, value = stripped.partition(":")
        found[key] = value.split(" #", 1)[0].strip()
    return found


def packager_step(text: str) -> str:
    return text.split("      - uses: BigWigsMods/packager@", 1)[1].split("\n      - ", 1)[0]


def test_release_runs_on_tag_pushes_only() -> None:
    text = workflow_text("release.yml")
    assert text.split("\non:\n", 1)[1].split("\n\n", 1)[0] == '  push:\n    tags:\n      - "*"'


def test_release_may_write_contents_and_nothing_else() -> None:
    # contents: write lets the workflow's own GITHUB_TOKEN create the tag's GitHub Release and upload its zip.
    text = workflow_text("release.yml")
    assert mapping(text, "permissions:") == {"contents": "write"}
    assert text.count("permissions:") == 1


def test_release_passes_the_workflows_own_token_and_the_two_site_tokens() -> None:
    # GITHUB_OAUTH is the first name the pinned release.sh reads its GitHub token from; GITHUB_API_TOKEN, a
    # personal token, is never passed. CurseForge and Wago keep their own secrets.
    step = packager_step(workflow_text("release.yml"))
    assert mapping(step, "        env:") == {
        "CF_API_TOKEN": "${{ secrets.CF_API_TOKEN }}",
        "WAGO_API_TOKEN": "${{ secrets.WAGO_API_TOKEN }}",
        "GITHUB_OAUTH": "${{ secrets.GITHUB_TOKEN }}",
    }


def test_release_never_uploads_to_wowinterface() -> None:
    step = packager_step(workflow_text("release.yml"))
    assert mapping(step, "        with:") == {"args": "-w 0", "pandoc": "false"}


def test_check_workflow_packages_the_zip_without_publishing_it() -> None:
    # The Check workflow builds the same zip, with every upload skipped (-d) and no token to publish with.
    text = workflow_text("check.yml")
    assert mapping(text, "permissions:") == {"contents": "read"}
    assert "secrets." not in text
    step = text.split("      - name: Package and check the release zip\n", 1)[1].split("\n  test-check:", 1)[0]
    assert "env:" not in step
    assert step.rstrip().endswith("bash scripts/package.sh")
    package = (ROOT / "scripts/package.sh").read_text()
    assert 'env -u GITHUB_ACTIONS bash "$packager" -d -t "$src" -r "$releasedir"' in package


@pytest.fixture
def detector() -> str:
    step = workflow_text("check.yml").split("      - name: Find whether the gate's machinery changed\n", 1)[1]
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
