"""The "translations stale" workflow (DATA-R114, docs/agents/translations-stale.md) runs on a schedule or by hand and on
nothing else, may only write issues, and never creates a label: those are the maintainer's calls."""

from pathlib import Path

from pagle_data.drift import issue_title

WORKFLOW = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "translations-stale.yml"


def code_lines() -> list[str]:
    """The workflow's lines without comments."""
    return [line.split(" #", 1)[0].rstrip() for line in WORKFLOW.read_text(encoding="utf-8").splitlines() if not line.lstrip().startswith("#")]


def test_it_runs_on_a_schedule_or_by_hand_and_on_no_event() -> None:
    lines = code_lines()
    start = lines.index("on:")
    block = lines[start + 1 : lines.index("permissions:")]
    assert [line for line in block if line.startswith("  ") and not line.startswith("   ")] == [
        "  schedule:",
        "  workflow_dispatch:",
    ]


def test_it_may_write_issues_and_read_the_code_and_nothing_else() -> None:
    lines = code_lines()
    start = lines.index("permissions:")
    assert lines[start + 1 : start + 3] == ["  contents: read", "  issues: write"]
    assert lines[start + 3].strip() == ""


def test_it_never_creates_a_label() -> None:
    text = "\n".join(code_lines())
    assert "gh label create" not in text and "gh label" in text  # it lists labels, to put one on only if it exists
    assert "--label translations-stale" in text


def test_it_finds_an_issue_by_the_title_the_generator_gives() -> None:
    assert issue_title("esES") == "Translations stale: esES"
    assert "jq -r .title" in "\n".join(code_lines())  # the title comes from `--stale-issue CODE --json`, not from here
