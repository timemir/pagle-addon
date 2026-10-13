"""The item universe (DATA-R15) over small fixture data/ trees: the baseline's loot items, then the item IDs in
whichever data/forever/ files name items exist."""

from pathlib import Path

import pytest

from baseline_fixture import write_baseline
from observed_fixture import write_observed
from pagle_data.baseline import read_baseline
from pagle_data.errors import Problems
from pagle_data.universe import item_universe

# The fixture baseline's loot items, by hand from baseline_fixture.CSVS: 13759 and 6303 in area loot, 6358 in
# reference table 500, 19807 in pool 180248. 500 is a reference, 33 and 40 are areas and 180248 a pool entry: none
# of those is an item.
BASELINE_ITEMS = {6303, 6358, 13759, 19807}


def universe(root: Path, forever: dict[str, str] | None = None) -> tuple[set[int], list[str]]:
    write_baseline(root)
    write_observed(root)  # no facts and no reports: test_observed.py covers observed items
    directory = root / "data" / "forever"
    directory.mkdir(parents=True, exist_ok=True)
    for name, text in (forever or {}).items():
        (directory / name).write_text(text, encoding="utf-8")
    problems = Problems()
    baseline = read_baseline(root, problems)
    assert problems.found == []
    found = item_universe(root, baseline, problems)
    return set(found), problems.found


def test_the_universe_is_the_baseline_s_area_reference_and_pool_loot_items(tmp_path: Path) -> None:
    # DATA-R15: every item ID in the baseline's area, reference or pool loot, and nothing else while data/forever/
    # names no item (events.toml, lists.toml and aliases.toml name none).
    found, problems = universe(
        tmp_path,
        {
            "events.toml": "[event.301]\n",
            "lists.toml": "auras = [1280342]\nfishingSpells = [7620]\n",
            "aliases.toml": '[[alias]]\nfrom = 16521\nto = 33\nwhy = "x"\n',
        },
    )
    assert problems == []
    assert found == BASELINE_ITEMS


@pytest.mark.parametrize(
    ("name", "text", "added"),
    [
        # DATA-R15 "in any file under data/forever/ (items, catch edits, pool edits)", in the shapes of the Data
        # section's data/forever/ keys table.
        ("items.toml", '[item.251524]\ncategory = "fish"\n\n[item.6303]\ncategory = "fish"\n', {251524}),
        (
            "areas.toml",
            '[[area]]\nid = 53\nclearBaseline = true\nwhy = "x"\n\n'
            '[[catch]]\narea = 33\nitem = 19803\nop = "add"\ngate = "event.301"\nwhy = "x"\n\n'
            '[[catch]]\narea = 40\nitem = 6522\nop = "drop"\nwhy = "x"\n',
            {19803, 6522},
        ),
        (
            "pools.toml",
            '[pool.whimsyfin]\nentries = [572928]\nadd = [251524]\nwhy = "x"\n\n'
            '[pool.tastyfish]\nentries = [180248]\ndrop = [19807, 6359]\nwhy = "x"\n',
            {251524, 6359},
        ),
    ],
)
def test_an_item_named_in_a_forever_file_joins_the_universe(
    tmp_path: Path, name: str, text: str, added: set[int]
) -> None:
    # DATA-R15: area IDs (53, 33, 40) and pool entries (572928, 180248) aren't items; a dropped item is still named.
    found, problems = universe(tmp_path, {name: text})
    assert problems == []
    assert found == BASELINE_ITEMS | added


@pytest.mark.parametrize(
    ("name", "text", "problem"),
    [
        ("items.toml", "[item.x12]\n", "data/forever/items.toml: item.x12: expected a positive integer ID"),
        ("items.toml", "item = 3\n", "data/forever/items.toml: item: expected a table, got an integer"),
        ("areas.toml", '[[catch]]\nitem = "6303"\n', "data/forever/areas.toml: catch[0].item: expected an integer"),
        ("areas.toml", "catch = 1\n", "data/forever/areas.toml: catch: expected an array of tables"),
        ("pools.toml", "[pool.a]\nadd = [0]\n", "data/forever/pools.toml: pool.a.add[0]: expected an integer at least 1"),
        ("pools.toml", "[pool.a]\ndrop = 5\n", "data/forever/pools.toml: pool.a.drop: expected an array of IDs"),
        ("pools.toml", "pool = [\n", "data/forever/pools.toml: not valid TOML"),
    ],
)
def test_an_unreadable_item_id_in_a_forever_file_is_a_problem(
    tmp_path: Path, name: str, text: str, problem: str
) -> None:
    # DATA-R63: the universe can't be known while a file that names items can't be read, so it's a problem.
    _, problems = universe(tmp_path, {name: text})
    assert any(found.startswith(problem) for found in problems), problems
