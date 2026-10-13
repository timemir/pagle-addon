"""The repo's own data/observed/ (DATA-R8 order 4): in M2 the dev's dev.toml is the only file, with no facts (#94)."""

import re
import tomllib
from pathlib import Path

from pagle_data.errors import Problems
from pagle_data.observed import read_observed, reporter_key

REPO = Path(__file__).resolve().parents[2]

# The dev's current log: Kukli-Vail's PagleLog.logId, read from the dev's SavedVariables on 2026-10-13 (#94).
DEV_LOG_ID = "314ca8bd2fb83d86"


def test_the_reporter_key_hash_gives_the_spec_test_vector() -> None:
    # REP-R36's test vector: logId 3f9a2c1e7b0d4a65 gives f38e76b0.
    assert reporter_key("3f9a2c1e7b0d4a65") == "f38e76b0"


def test_the_reporter_key_is_zero_padded_to_8_hex() -> None:
    # REP-R36: 8 lowercase hex characters, zero-padded. FNV-1a 32-bit of "" is its offset basis 811c9dc5; of "a" it
    # is e40c292c (the published FNV test vectors).
    assert reporter_key("") == "811c9dc5"
    assert reporter_key("a") == "e40c292c"


def test_the_committed_dev_toml_has_the_shape_data_r122_gives_it() -> None:
    # DATA-R122: dev.toml holds keys (the reporter keys of the dev's logs, REP-R36's 8 lowercase hex) and [[fact]]
    # entries, each with kind, build, note and exactly the IDs its kind needs. Read here without the observed
    # layer's reader, so the rule is checked on the file itself.
    document = tomllib.loads((REPO / "data" / "observed" / "dev.toml").read_text(encoding="utf-8"))
    assert set(document) <= {"keys", "fact"}
    keys = document["keys"]
    assert isinstance(keys, list) and len(keys) == len(set(keys))
    assert all(isinstance(key, str) and re.fullmatch(r"[0-9a-f]{8}", key) for key in keys)
    needs = {"pair": {"item", "area"}, "gate": {"item", "window"}, "window": {"window"}, "weekly": {"event"}}
    needs["skillBase"] = {"area"}
    for fact in document.get("fact", []):
        assert fact["kind"] in needs
        assert set(fact) == {"kind", "build", "note"} | needs[fact["kind"]]


def test_the_committed_dev_toml_lists_the_reporter_key_of_the_devs_current_log() -> None:
    # #94 / DATA-R46: dev.toml's keys hold the reporter key (REP-R36) of the dev's current log, so the dev's own
    # report rows count as reporter dev.
    problems = Problems()
    layer = read_observed(REPO, problems)
    assert problems.found == []
    assert reporter_key(DEV_LOG_ID) == "38d9e978"
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
