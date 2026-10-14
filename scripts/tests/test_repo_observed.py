"""The repo's own data/observed/ (DATA-R8 order 4): in M2 the dev's dev.toml is the only file, with no facts (#94)."""

from pathlib import Path

from pagle_data.errors import Problems
from pagle_data.observed import read_observed

REPO = Path(__file__).resolve().parents[2]

# The dev's current log: Kukli-Vail's PagleLog.logId, read from the dev's SavedVariables on 2026-10-13 (#94).
DEV_LOG_ID = "314ca8bd2fb83d86"


def _reporter_key(log_id: str) -> str:
    # REP-R36: FNV-1a 32-bit of the logId's bytes, 8 lowercase hex characters, zero-padded.
    hashed = 0x811C9DC5
    for byte in log_id.encode("ascii"):
        hashed = ((hashed ^ byte) * 0x01000193) & 0xFFFFFFFF
    return f"{hashed:08x}"


def test_the_reporter_key_hash_gives_the_spec_test_vector() -> None:
    # REP-R36's test vector: logId 3f9a2c1e7b0d4a65 gives f38e76b0.
    assert _reporter_key("3f9a2c1e7b0d4a65") == "f38e76b0"


def test_the_committed_dev_toml_lists_the_reporter_key_of_the_devs_current_log() -> None:
    # #94 / DATA-R46: dev.toml's keys hold the reporter key (REP-R36) of the dev's current log, so the dev's own
    # report rows count as reporter dev.
    problems = Problems()
    layer = read_observed(REPO, problems)
    assert problems.found == []
    assert _reporter_key(DEV_LOG_ID) == "38d9e978"
    assert layer.keys == ("38d9e978",)


def test_the_committed_dev_toml_reads_clean_with_no_facts_and_no_report_is_committed() -> None:
    # DATA-R122: dev.toml holds keys and [[fact]]s; M2 commits it with no facts and commits no report (#94). Fixture
    # rows live in the tests (observed_fixture.py), never here.
    problems = Problems()
    layer = read_observed(REPO, problems)
    assert problems.found == []
    assert layer.facts == ()
    assert layer.reports == {}
    assert not (REPO / "data" / "observed" / "reports").exists()


def test_the_committed_catalogue_confirms_nothing_while_no_observation_is_committed() -> None:
    # DATA-R56: before any observation every confirmed, gateConfirmed and skillBaseConfirmed is false (#95: the
    # committed flags stay false while dev.toml has no facts).
    text = (REPO / "addons" / "Pagle" / "data" / "Catalogue.lua").read_text(encoding="utf-8")
    assert "onfirmed = true" not in text
    assert "onfirmed = false" in text
