"""Admission and the rarity cap (DATA-R92): the Hunt checks that read what a Hunt's window means, over
test_catch_lists.py's tree, whose Stranglethorn Vale (33) lists 6303 (summer), 13759 (night), 13760 (day), 19803 and
19807 (event.301), and Echo Isles (368) 13759 (night) and 13760, with a Hunt list written over it."""

from pathlib import Path

import pytest

from cli_fixture import run
from hunts_fixture import write_hunts
from observed_fixture import i_row, report
from pagle_data.generate import read_layers
from pagle_data.realm_time import openness
from test_catch_lists import AREAS_TOML, write_tree
from test_confirmed import DEV

REPO = Path(__file__).resolve().parents[2]
SET = '[[set]]\nid = "clock"\nname = "Clock"\ntitle = "the Clockwatcher"\n'


def hunt(hunt_id: str, body: str, retired: str = "") -> str:
    """A [[hunt]] in the set clock, since the pre-1.0 placeholder, with body's kind, target and window or
    conditions."""
    retired_line = f"retired = {retired}\n" if retired else ""
    return (
        f'\n[[hunt]]\nid = "{hunt_id}"\nset = "clock"\nsince = 2026-11-04\n{retired_line}'
        f'tiers = [1]\nname = "{hunt_id}"\n{body}'
    )


def natural(hunt_id: str, species: int, window: str, retired: str = "") -> str:
    return hunt(hunt_id, f'kind = "natural"\nspecies = {species}\nwindow = "{window}"\n', retired)


def imposed(hunt_id: str, conditions: str, retired: str = "") -> str:
    return hunt(hunt_id, f'kind = "imposed"\nspecies = 13760\nconditions = {conditions}\n', retired)


def generate(
    root: Path,
    capsys: pytest.CaptureFixture[str],
    hunts: str,
    areas: str = AREAS_TOML,
    reports: dict[str, str] | None = None,
) -> tuple[int, str]:
    """The generator's exit code and output on the tree with these Hunts (after SET), areas.toml and reports."""
    write_tree(root, areas, dev=DEV, reports=reports)
    write_hunts(root, SET + hunts)
    return run(root, capsys)


# Removes Stranglethorn Vale's day gate from 13760, its only one (DATA-R29).
UNGATE_13760 = '\n[[catch]]\narea = 33\nitem = 13760\nop = "add"\ngate = "none"\nwhy = "planted"\n'


def test_a_natural_hunt_whose_window_gates_its_species_in_one_area_is_admitted(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R92: Stranglethorn Vale's day gate on 13760 admits a natural day Hunt on Species 13760.
    code, output = generate(tmp_path, capsys, natural("sunscale", 13760, "day"))
    assert code == 0, output


def test_with_that_gate_removed_the_hunt_fails_admission_naming_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R92, DATA-R63: no catch entry of 13760 carries day once the gate is gone, so the generator fails, naming the
    # Hunt and the check. A gate on another window (13759's night) doesn't admit a Hunt on day.
    code, output = generate(tmp_path, capsys, natural("sunscale", 13760, "day"), AREAS_TOML + UNGATE_13760)
    assert code == 1
    assert (
        "data/hunts/hunts.toml: hunt.sunscale: admission: no catch entry of Species 13760's items, in any area, has the"
        " gate 'day'; gate one, or retire the Hunt (DATA-R92)"
    ) in output
    code, output = generate(tmp_path, capsys, natural("nightfin", 13759, "day"))
    assert code == 1
    assert "hunt.nightfin: admission: no catch entry of Species 13759's items" in output


def test_a_retired_natural_hunt_needs_no_admission(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R92: "a Hunt whose gating is dropped from the data must be retired", and then it passes.
    code, output = generate(
        tmp_path, capsys, natural("sunscale", 13760, "day", retired="2027-01-01"), AREAS_TOML + UNGATE_13760
    )
    assert code == 0, output


def test_a_contradicted_gate_still_admits(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R92: contradicted gates still count. A row at 03:00, outside day, contradicts 13760's day gate in
    # Stranglethorn Vale (DATA-R52), and the day Hunt is still admitted.
    outside = {"bbbbbbbb": report(i_row(13760, 33, extra='t = "03:00"\nm = 5\n'))}
    code, output = generate(tmp_path, capsys, natural("sunscale", 13760, "day"), reports=outside)
    assert code == 0, output
    assert "gateConfirmed = false" in (tmp_path / "addons/Pagle/data/Catalogue.lua").read_text(encoding="utf-8")


# A Hunt open one hour a year: a two-day season with half an hour a day (a one-day season can't be written, LOG-R48).
ONE_HOUR_A_YEAR = "{ season = [{ from = [6, 1], to = [6, 2] }], time = [[720, 750]] }"


def test_an_imposed_hunt_open_one_hour_a_year_fails_the_rarity_cap_with_its_numbers(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R92, DATA-R63: open at 8 of the span's 70080 steps, and closed 364 days less half an hour running.
    code, output = generate(tmp_path, capsys, imposed("yearly", ONE_HOUR_A_YEAR))
    assert code == 1
    assert (
        "data/hunts/hunts.toml: hunt.yearly: rarity cap: open at 8 of 70080 steps (0.01%; needs 1/7, 14.29%), and"
        " closed 363 days 23 hours 30 minutes running (needs at most 7 days) (DATA-R92)"
    ) in output


def test_auras_pass_the_cap_and_every_other_field_is_ignored(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R92: a spec with auras passes whatever its time; areas, lure and skill never narrow the steps.
    with_auras = "{ auras = [1280341], season = [{ from = [6, 1], to = [6, 2] }], time = [[720, 750]] }"
    others = "{ areas = [33], lure = true, skill = { min = 300 } }"
    write_tree(tmp_path, dev=DEV)
    (tmp_path / "data/forever/lists.toml").write_text("auras = [1280341]\nfishingSpells = [7620]\n", encoding="utf-8")
    write_hunts(tmp_path, SET + imposed("buffed", with_auras) + imposed("anywhere", others))
    code, output = run(tmp_path, capsys)
    assert code == 0, output


def test_an_event_without_a_weekly_rule_fails_the_cap(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R92: an event on the event list with no weekly rule counts as never open.
    write_tree(tmp_path)
    (tmp_path / "data/forever/events.toml").write_text(
        "[event.301]\nweekday = 1\nstart = 840\nduration = 120\n\n[event.302]\n", encoding="utf-8"
    )
    write_hunts(tmp_path, SET + imposed("someday", "{ events = [302] }") + imposed("sundays", "{ events = [301] }"))
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert (
        "hunt.someday: rarity cap: open at 0 of 70080 steps (0.00%; needs 1/7, 14.29%), and closed 730 days running"
        " (needs at most 7 days) (DATA-R92)"
    ) in output
    assert "hunt.sundays" not in output  # DATA-R38: the Extravaganza, Sundays 14:00 for 2 hours, passes


def test_a_retired_hunt_needs_no_rarity_cap(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R92: only a Hunt that isn't retired is held to the cap.
    code, output = generate(tmp_path, capsys, imposed("yearly", ONE_HOUR_A_YEAR, retired="2027-01-01"))
    assert code == 0, output


def test_a_natural_hunt_is_held_to_its_window_s_spec(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R92: a natural Hunt's time is its window's spec. The fixture's day ({ time = [[360, 0]] }) passes; a
    # windows.toml that makes day one hour a year fails the Hunt on it (the windows file is test_windows.py's).
    code, output = generate(tmp_path, capsys, natural("sunscale", 13760, "day"))
    assert code == 0, output
    windows = tmp_path / "data/forever/windows.toml"
    windows.write_text(
        windows.read_text(encoding="utf-8")
        + '\n[window.day]\nseason = [{ from = [6, 1], to = [6, 2] }]\ntime = [[720, 750]]\nwhy = "planted"\n',
        encoding="utf-8",
    )
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert "hunt.sunscale: rarity cap: open at 8 of 70080 steps" in output


def test_both_checks_are_listed_with_every_other_problem(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: admission and the rarity cap fail in the same run as another Hunt problem, all listed, nothing written.
    # A Hunt on a window that isn't one gets that problem alone (DATA-R35), not admission or the cap too.
    hunts = (
        natural("nightfin", 13759, "day")
        + imposed("yearly", ONE_HOUR_A_YEAR)
        + natural("dusky", 13759, "dusk")
    )
    code, output = generate(tmp_path, capsys, hunts)
    assert code == 1
    assert "hunt.nightfin: admission:" in output
    assert "hunt.yearly: rarity cap:" in output
    assert "hunt.dusky.window: 'dusk' isn't a window ID (DATA-R35, DATA-R92)" in output
    assert "3 problem(s) in data/; wrote nothing" in output


def test_the_repo_s_windows_pass_the_cap() -> None:
    # DATA-R92 against the committed data: night, day, the four seasons and event.301 with its weekly rule (DATA-R38)
    # all pass, so a natural Hunt on any of them can't fail the cap.
    layers = read_layers(REPO)
    windows = ("day", "night", "spring", "summer", "autumn", "winter", "event.301")
    assert [window for window in windows if not openness(layers.windows[window], layers.forever.events).passes] == []
