"""data/observed/pooltext.toml (DATA-R118): the dev's hand-kept map from (locale, hovered text) to a pool type ID,
bobber or other. It isn't an observation: it feeds only the triage Action (DATA-R117), and the observed layer reads
it strictly (DATA-R63), over test_catch_lists.py's tree (pools_fixture's one pool type, extravaganza)."""

from pathlib import Path

import pytest

from cli_fixture import run
from pagle_data.errors import Problems
from pagle_data.observed import PoolTextEntry, read_observed
from test_catch_lists import CATALOGUE, write_tree

POOLTEXT = "data/observed/pooltext.toml"


def entry(locale: str, text: str, pool: str) -> str:
    return f'\n[[text]]\nlocale = "{locale}"\ntext = "{text}"\npool = "{pool}"\n'


def write_pooltext(root: Path, text: str) -> None:
    (root / POOLTEXT).write_text(text, encoding="utf-8")


def problems_of(root: Path, text: str) -> list[str]:
    write_pooltext(root, text)
    problems = Problems()
    read_observed(root, problems)
    return problems.found


def test_the_entries_read_as_locale_text_and_pool(tmp_path: Path) -> None:
    # DATA-R118 and the Data section's data/observed/ table: [[text]] with locale, text and pool.
    root = write_tree(tmp_path)
    write_pooltext(root, entry("deDE", "Angelköder", "bobber") + entry("enUS", 'School of \\"Fish\\"', "extravaganza"))
    problems = Problems()
    layer = read_observed(root, problems)
    assert problems.found == []
    assert [(known.locale, known.text, known.pool) for known in layer.pooltext] == [
        ("deDE", "Angelköder", "bobber"),
        ("enUS", 'School of "Fish"', "extravaganza"),
    ]
    assert all(isinstance(known, PoolTextEntry) for known in layer.pooltext)


def test_a_missing_pooltext_toml_is_no_entries(tmp_path: Path) -> None:
    # DATA-R118: the file is kept by hand and committed empty; a tree without it (every older fixture) has no entries.
    problems = Problems()
    layer = read_observed(write_tree(tmp_path), problems)
    assert problems.found == []
    assert layer.pooltext == ()


def test_a_blank_hovered_text_can_be_mapped(tmp_path: Path) -> None:
    # DATA-R118 maps the hovered texts of P rows, and REP-R22 sends every text Core doesn't drop as empty: a blank one
    # too, so the dev can map it.
    problems = Problems()
    write_tree(tmp_path)
    (tmp_path / POOLTEXT).write_text(entry("deDE", " ", "other"), encoding="utf-8")
    layer = read_observed(tmp_path, problems)
    assert problems.found == []
    assert [(known.locale, known.text, known.pool) for known in layer.pooltext] == [("deDE", " ", "other")]


@pytest.mark.parametrize(
    ("text", "problem"),
    [
        ("texts = []\n", "unknown key 'texts'"),
        ("text = 1\n", "text: expected an array of tables ([[text]]), got an integer"),
        ('[[text]]\nlocale = "deDE"\ntext = "x"\n', "text[0]: missing key 'pool'"),
        (entry("deDE", "x", "bobber") + "area = 12\n", "text[0]: unknown key 'area'"),
        (entry("german", "x", "bobber"), "text[0].locale: expected [a-z]{2}[A-Z]{2}, got 'german'"),
        (entry("deDE", "", "bobber"), "text[0].text: expected a non-empty string"),
        ('[[text]]\nlocale = "deDE"\ntext = "x"\npool = 3\n', "text[0].pool: expected a string, got an integer"),
        (entry("deDE", "x", "bobber") + entry("deDE", "x", "other"), "text[1]: (deDE, 'x') is already mapped"),
    ],
)
def test_an_unknown_key_or_a_wrong_type_in_pooltext_toml_is_a_problem(tmp_path: Path, text: str, problem: str) -> None:
    # DATA-R63: an unknown key or a wrong type in any TOML file under data/, naming the file and the key. DATA-R118
    # maps each (locale, text) to one pool, so a text listed twice for a locale is a problem too.
    found = problems_of(write_tree(tmp_path), text)
    assert any(line.startswith(f"{POOLTEXT}: {problem}") for line in found), found


def test_an_entry_naming_an_unknown_pool_type_fails_the_generator(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R118: pool is a pool type ID from pools.toml, bobber or other; anything else fails the generator, which
    # writes nothing (DATA-R63).
    root = write_tree(tmp_path)
    write_pooltext(root, entry("deDE", "Angelköder", "bobber") + entry("deDE", "Schwarm", "schoolOfFish"))
    code, output = run(root, capsys)
    assert code == 1
    assert (
        f"generate-data: {POOLTEXT}: text[1].pool: 'schoolOfFish' is no pool type in data/forever/pools.toml, nor"
        " bobber or other (DATA-R118)" in output
    )
    assert not (root / CATALOGUE).exists()


def test_entries_naming_a_pool_type_bobber_or_other_generate_and_change_no_catalogue(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R118: the map isn't an observation, and DATA-R44: no pool text ships, so the catalogue is the same with it.
    root = write_tree(tmp_path)
    assert run(root, capsys)[0] == 0
    without = (root / CATALOGUE).read_text(encoding="utf-8")
    write_pooltext(
        root,
        entry("deDE", "Angelköder", "bobber") + entry("enUS", "Floating Wreckage", "other")
        + entry("enUS", "Tastyfish", "extravaganza"),
    )
    code, output = run(root, capsys)
    assert code == 0, output
    assert (root / CATALOGUE).read_text(encoding="utf-8") == without
