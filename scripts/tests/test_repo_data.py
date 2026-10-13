"""The repo's own data/forever/ holds the seeded lists the spec names."""

from pathlib import Path

from pagle_data.forever import WeeklyRule, read_forever
from pagle_data.toml_reader import Problems

REPO = Path(__file__).resolve().parents[2]


def test_the_event_list_is_the_extravaganza_on_sundays_at_14_00_for_120_minutes() -> None:
    # DATA-R38: "The v1 list is the Extravaganza, 301, Sundays 14:00 for 120 minutes."
    problems = Problems()
    layer = read_forever(REPO, problems)
    assert problems.found == []
    assert layer.events == {301: WeeklyRule(weekday=1, start=14 * 60, duration=120)}


def test_the_aura_and_fishing_spell_lists_hold_their_seeds() -> None:
    # DATA-R39: the beta probe's four auras, and the Classic and Forever rank spells.
    problems = Problems()
    layer = read_forever(REPO, problems)
    assert problems.found == []
    assert sorted(layer.auras) == [1265220, 1280341, 1280342, 1299323]
    assert sorted(layer.fishing_spells) == [7620, 7731, 7732, 18248, 1240948, 1240959, 1240970, 1240983]
