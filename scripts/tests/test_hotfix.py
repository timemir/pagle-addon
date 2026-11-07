"""scripts/hotfix.sh step 6 (#612): what pagle-backend's local pin bump did, said as it happened. The script is sourced
and its backend_bump run against a fake pagle-backend checkout whose ci/local-pin-bump.sh prints a recorded transcript
and exits as the real one would, so no test calls GitHub or runs the backend's CI."""

import os
from pathlib import Path
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[2]
HOTFIX = ROOT / "scripts/hotfix.sh"
VERSION = "1.3.0"
COMMIT = "dfd64d4f936d791fee555dc0158e49615ee7c80a"

# What the backend prints since its outcome line (pagle-backend PRJ-R66).
GREEN = """\
pin-bump: opened a pull request for 1.3.0
pin-bump: outcome=bumped release=1.3.0
local-pin-bump: testing pull request #430 (abc) with ci/local.sh
local-pin-bump: GREEN: pull request #430 (abc) passed local CI; review and merge it by hand
local-pin-bump: outcome=green pr=430
"""
RED = """\
local-pin-bump: RED: pull request #430 (abc) failed local CI
local-pin-bump: outcome=red pr=430
"""
UP_TO_DATE = """\
pin-bump: timemir/pagle-addon's latest Release 1.3.0 is not newer than the pinned 1.3.0; nothing to do
pin-bump: outcome=up-to-date pin=1.3.0
local-pin-bump: no bump pull request is open; nothing to test
local-pin-bump: outcome=up-to-date pin=1.3.0
"""
COMMIT_PIN = f"""\
pin-bump: outcome=commit-pin pin={COMMIT} release=1.3.0
local-pin-bump: no bump pull request is open; nothing to test
local-pin-bump: outcome=commit-pin pin={COMMIT} release=1.3.0
"""
POLICY_NEEDED = f"""\
pin-bump: outcome=policy-needed pin={COMMIT} release=1.3.0
local-pin-bump: the pin stays; add the new ranked policy first (OPS-R131, TRU-R72)
local-pin-bump: outcome=policy-needed pin={COMMIT} release=1.3.0
"""
FAILED = """\
local-pin-bump: the pin bump failed (above)
local-pin-bump: outcome=failed
"""

# What a backend checkout from before its outcome line printed: the 1.3.0 release's own transcript (#612) among them.
LEGACY_COMMIT_PIN = """\
pin-bump: the pin names a wow-fish commit, so bumps are made by hand before L (OPS-R131); nothing to do
local-pin-bump: no bump pull request is open; nothing to test
"""
LEGACY_GREEN = """\
local-pin-bump: testing pull request #417 (abc) with ci/local.sh
local-pin-bump: GREEN: pull request #417 (abc) passed local CI; review and merge it by hand
"""
LEGACY_RED = "local-pin-bump: RED: pull request #417 (abc) failed local CI\n"
LEGACY_UP_TO_DATE = """\
pin-bump: timemir/pagle-addon's latest Release 1.3.0 is not newer than the pinned 1.3.0; nothing to do
local-pin-bump: no bump pull request is open; nothing to test
"""
LEGACY_FAILED = "local-pin-bump: the pin bump failed (above)\n"


def step6(tmp_path: Path, transcript: str, status: int) -> subprocess.CompletedProcess[str]:
    """backend_bump 1.3.0 against a fake pagle-backend checkout whose ci/local-pin-bump.sh prints transcript."""
    backend = tmp_path / "pagle-backend"
    (backend / "ci").mkdir(parents=True)
    (backend / "transcript").write_text(transcript)
    bump = backend / "ci/local-pin-bump.sh"
    bump.write_text(f'#!/usr/bin/env bash\ncat "$(dirname "$0")/../transcript"\nexit {status}\n')
    bump.chmod(0o755)
    return subprocess.run(
        ["bash", "-c", 'source "$1" && backend_bump "$2"', "hotfix", str(HOTFIX), VERSION],
        env={"PATH": os.environ["PATH"], "HOTFIX_BACKEND_DIR": str(backend)},
        capture_output=True,
        text=True,
        check=False,
    )


def hotfix_lines(run: subprocess.CompletedProcess[str]) -> list[str]:
    return [line for line in (run.stdout + run.stderr).splitlines() if line.startswith("hotfix: ")]


@pytest.mark.parametrize("transcript", [GREEN, LEGACY_GREEN], ids=["outcome", "legacy"])
def test_green_names_the_pull_request_that_passed(tmp_path: Path, transcript: str) -> None:
    run = step6(tmp_path, transcript, 0)

    number = "430" if transcript == GREEN else "417"
    assert run.returncode == 0, run.stderr
    assert hotfix_lines(run)[1:] == [
        f"hotfix: 1.3.0 is released and pagle-backend's bump pull request #{number} passed its local CI",
        f"hotfix: next, the Operator's: review and merge #{number} by hand, then in {tmp_path / 'pagle-backend'} "
        "run ci/local-promote.sh <merge commit>",
    ]
    # The backend's own lines are shown as they come.
    assert "local-pin-bump: GREEN" in run.stdout


@pytest.mark.parametrize("transcript", [RED, LEGACY_RED], ids=["outcome", "legacy"])
def test_red_stops_red_and_names_the_pull_request(tmp_path: Path, transcript: str) -> None:
    run = step6(tmp_path, transcript, 1)

    number = "430" if transcript == RED else "417"
    assert run.returncode == 1
    assert hotfix_lines(run)[1:] == [
        f"hotfix: 1.3.0 is released, but pagle-backend's bump pull request #{number} failed its local CI (above); "
        "fix it there, then run ci/local-pin-bump.sh again"
    ]


@pytest.mark.parametrize("transcript", [UP_TO_DATE, LEGACY_UP_TO_DATE], ids=["outcome", "legacy"])
def test_a_pin_at_this_version_already_has_nothing_to_bump(tmp_path: Path, transcript: str) -> None:
    run = step6(tmp_path, transcript, 0)

    assert run.returncode == 0, run.stderr
    assert hotfix_lines(run)[1:] == [
        "hotfix: 1.3.0 is released; pagle-backend's pin is at 1.3.0 already, so there is no bump to make"
    ]


def test_a_commit_pin_the_release_does_not_hold_stays_and_nothing_is_bumped(tmp_path: Path) -> None:
    run = step6(tmp_path, COMMIT_PIN, 0)

    assert run.returncode == 0, run.stderr
    assert hotfix_lines(run)[1:] == [
        f"hotfix: 1.3.0 is released; pagle-backend's pin stays on the wow-fish commit {COMMIT}, which 1.3.0 doesn't "
        "hold (its OPS-R131), so no bump pull request was opened",
        "hotfix: a commit pin moves to the tag of the release that holds it; until then there is nothing to bump",
    ]


def test_a_commit_pin_an_older_backend_does_not_move_is_left_to_the_operator_and_never_called_green(
    tmp_path: Path,
) -> None:
    # The 1.3.0 release (#612): no bump pull request, so nothing passed local CI.
    run = step6(tmp_path, LEGACY_COMMIT_PIN, 0)

    assert run.returncode == 0, run.stderr
    lines = hotfix_lines(run)[1:]
    assert lines == [
        "hotfix: 1.3.0 is released, but pagle-backend's pin is in commit form and this checkout's "
        "ci/local-pin-bump.sh doesn't move it, so no bump pull request was opened",
        "hotfix: next, the Operator's: make the tag-form pin by hand (as pagle-backend#417 and #429 were), or run "
        "ci/local-pin-bump.sh from a pagle-backend checkout of main that has pagle-backend#430, which writes it",
    ]
    assert not any("passed" in line for line in lines)


def test_a_release_that_needs_a_new_ranked_policy_stops_red(tmp_path: Path) -> None:
    run = step6(tmp_path, POLICY_NEEDED, 1)

    assert run.returncode == 1
    assert hotfix_lines(run)[1:] == [
        "hotfix: 1.3.0 is released, but it changes a file pagle-backend's ranked policy hashes after the pinned "
        f"commit {COMMIT}, so the pin stays: a new ranked policy is needed first (its OPS-R131, TRU-R72)"
    ]


@pytest.mark.parametrize("transcript", [FAILED, LEGACY_FAILED], ids=["outcome", "legacy"])
def test_a_failed_bump_stops_red(tmp_path: Path, transcript: str) -> None:
    run = step6(tmp_path, transcript, 1)

    assert run.returncode == 1
    assert hotfix_lines(run)[1:] == [
        "hotfix: the backend's local pin bump failed (above); 1.3.0 is released, so run ci/local-pin-bump.sh there "
        "again once fixed"
    ]


def test_a_bump_that_says_nothing_known_is_not_called_green(tmp_path: Path) -> None:
    run = step6(tmp_path, "local-pin-bump: something new\n", 0)

    assert run.returncode == 0, run.stderr
    assert hotfix_lines(run)[1:] == [
        "hotfix: 1.3.0 is released; pagle-backend's local pin bump finished without saying what it did (above): "
        "check its bump pull request by hand"
    ]


def test_without_a_backend_checkout_it_prints_the_operators_commands(tmp_path: Path) -> None:
    run = subprocess.run(
        ["bash", "-c", 'source "$1" && backend_bump "$2"', "hotfix", str(HOTFIX), VERSION],
        env={"PATH": os.environ["PATH"]},
        capture_output=True,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert hotfix_lines(run)[0].startswith("hotfix: 1.3.0 is released. pagle-backend's CI runs locally")
    assert "hotfix:   ci/local-pin-bump.sh" in run.stdout
