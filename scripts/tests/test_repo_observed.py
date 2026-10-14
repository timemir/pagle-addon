"""The repo's own data/observed/ (DATA-R8 order 4): in M2 the dev's dev.toml is the only file, with no facts (#94)."""

import re
import tomllib
from pathlib import Path

import pytest

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


# DATA-R122: the IDs each fact kind needs, restated from the rule so the committed file is checked without the
# observed layer's reader.
NEEDS = {
    "pair": {"item", "area"},
    "gate": {"item", "window"},
    "window": {"window"},
    "weekly": {"event"},
    "skillBase": {"area"},
}


def _positive(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def dev_toml_shape(document: dict[str, object]) -> list[str]:
    """What's wrong with a dev.toml against DATA-R122, by key: keys a list of distinct reporter keys (REP-R36's 8
    lowercase hex), each [[fact]] a kind with a positive int build, a non-empty note and exactly the IDs its kind
    needs, item, area and event positive ints and window a string."""
    wrong = [f"unknown key {key}" for key in sorted(set(document) - {"keys", "fact"})]
    keys = document.get("keys")
    if not isinstance(keys, list):
        wrong.append("keys: missing, or not a list")
    else:
        wrong += [f"keys: {key!r} isn't 8 lowercase hex" for key in keys if not re.fullmatch(r"[0-9a-f]{8}", str(key))]
        wrong += ["keys: a key is listed twice"] if len(keys) != len(set(map(str, keys))) else []
    facts = document.get("fact", [])
    for index, entry in enumerate(facts if isinstance(facts, list) else [facts]):
        at = f"fact[{index}]"
        if not isinstance(entry, dict) or entry.get("kind") not in NEEDS:
            wrong.append(f"{at}: kind isn't one of {', '.join(NEEDS)}")
            continue
        expected = {"kind", "build", "note"} | NEEDS[entry["kind"]]
        wrong += [f"{at}: missing {key}" for key in sorted(expected - set(entry))]
        wrong += [f"{at}: unknown key {key}" for key in sorted(set(entry) - expected)]
        note = entry.get("note")
        if "note" in entry and not (isinstance(note, str) and note.strip()):
            wrong.append(f"{at}.note: not a non-empty string")
        for key in ("build", "item", "area", "event"):
            if key in entry and not _positive(entry[key]):
                wrong.append(f"{at}.{key}: not a positive int")
        if "window" in entry and not isinstance(entry["window"], str):
            wrong.append(f"{at}.window: not a string")
    return wrong


def test_the_committed_dev_toml_has_the_shape_data_r122_gives_it() -> None:
    # DATA-R122: dev.toml holds keys (the reporter keys of the dev's logs, REP-R36's 8 lowercase hex) and [[fact]]
    # entries, each with kind, build, note and exactly the IDs its kind needs. Read here without the observed
    # layer's reader, so the rule is checked on the file itself.
    document = tomllib.loads((REPO / "data" / "observed" / "dev.toml").read_text(encoding="utf-8"))
    assert dev_toml_shape(document) == []


def fact(kind: str, **fields: str) -> str:
    """A dev.toml with no keys and one [[fact]] of kind, its other fields given as TOML values."""
    lines = ["keys = []", "[[fact]]", f'kind = "{kind}"', *(f"{key} = {value}" for key, value in fields.items())]
    return "\n".join(lines) + "\n"


@pytest.mark.parametrize(
    ("text", "wrong"),
    [
        ("", "keys: missing, or not a list"),
        ('keys = ["38D9E978"]', "keys: '38D9E978' isn't 8 lowercase hex"),
        (fact("window", build='"70338"', note='"x"', window='"night"'), "fact[0].build: not a positive int"),
        (fact("window", build="70338", note='""', window='"night"'), "fact[0].note: not a non-empty string"),
        (fact("pair", build="70338", note='"x"', item='"6303"', area="12"), "fact[0].item: not a positive int"),
        (fact("weekly", build="70338", note='"x"'), "fact[0]: missing event"),
    ],
)
def test_the_dev_toml_shape_check_names_each_wrong_value(text: str, wrong: str) -> None:
    # DATA-R122: the shape check above fails on a wrong value's type, not only on wrong key names, and names what is
    # wrong rather than raising.
    assert any(found.startswith(wrong) for found in dev_toml_shape(tomllib.loads(text)))


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


def test_the_committed_pooltext_toml_is_empty_and_says_how_the_dev_fills_it() -> None:
    # DATA-R118: pooltext.toml is kept by hand from the triage comments' P row texts; #127 commits it with no
    # entries and a comment saying how to fill it.
    text = (REPO / "data" / "observed" / "pooltext.toml").read_text(encoding="utf-8")
    assert tomllib.loads(text) == {}
    assert "triage comment" in text and "pools.toml" in text and "bobber" in text and "other" in text
    problems = Problems()
    assert read_observed(REPO, problems).pooltext == ()
    assert problems.found == []


def test_the_committed_catalogue_confirms_nothing_while_no_observation_is_committed() -> None:
    # DATA-R56: before any observation every confirmed, gateConfirmed and skillBaseConfirmed is false (#95: the
    # committed flags stay false while dev.toml has no facts).
    text = (REPO / "addons" / "Pagle" / "data" / "Catalogue.lua").read_text(encoding="utf-8")
    assert "onfirmed = true" not in text
    assert "onfirmed = false" in text
