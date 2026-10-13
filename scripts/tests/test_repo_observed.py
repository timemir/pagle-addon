"""The repo's own data/observed/ (DATA-R8 order 4): in M2 the dev's dev.toml is the only file, with no facts (#94)."""

from pathlib import Path

from pagle_data.errors import Problems
from pagle_data.observed import read_observed

REPO = Path(__file__).resolve().parents[2]


def test_the_committed_dev_toml_reads_clean_with_no_facts_and_no_report_is_committed() -> None:
    # DATA-R122: dev.toml holds keys and [[fact]]s; M2 commits it with no facts and commits no report (#94). Fixture
    # rows live in the tests (observed_fixture.py), never here.
    problems = Problems()
    layer = read_observed(REPO, problems)
    assert problems.found == []
    assert layer.facts == ()
    assert layer.reports == {}
    assert not (REPO / "data" / "observed" / "reports").exists()
