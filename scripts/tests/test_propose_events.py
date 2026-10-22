"""scripts/propose-events.py (DATA-R99): drafting candidate Hunt Events from a zone's loot, over event_scripts_fixture's
tree, whose Elwynn Forest (12) has five Species and an uncommon item at known loot shares."""

import tomllib
from datetime import datetime
from pathlib import Path

import pytest

from cli_fixture import run
from event_scripts_fixture import HAUL_SHARE, PROPOSE_LOOT, SHARES, UNCOMMON_SHARE, data_files, write_tree
from events_fixture import SKILL_14
from pagle_data.check_event import main as check_event
from pagle_data.events import event_file
from pagle_data.propose_events import CATCHES_PER_HOUR, TIER_MINUTES, friendly
from pagle_data.propose_events import main as propose
from test_catch_lists import AREAS_TOML

NOW = datetime(2026, 10, 22, 9, 30, 5)
# The fixture's windows (windows_fixture): night 18:00-12:00 and day 06:00-24:00, both open 18 hours a day, and
# the dusk span 18:00-21:00, 3.
SPANS = {"night": [[1080, 720]], "day": [[360, 0]], "dusk": [[1080, 1260]]}
OPEN = {"night": 0.75, "day": 0.75, "dusk": 0.125}


def _propose(root: Path, capsys: pytest.CaptureFixture[str], *args: str) -> tuple[int, str]:
    return run(root, capsys, *args, main=propose, temp=root / "tmp", now=NOW)


def _drafts(folder: Path) -> dict[str, dict[str, object]]:
    return {path.stem: tomllib.loads(path.read_text(encoding="utf-8")) for path in sorted(folder.glob("*.toml"))}


def _hunts(draft: dict[str, object]) -> list[dict[str, object]]:
    hunts = draft["hunt"]
    assert isinstance(hunts, list)
    return hunts


def _event(draft: dict[str, object]) -> dict[str, object]:
    table = draft["event"]
    assert isinstance(table, dict)
    return table


def _share(hunt: dict[str, object]) -> float:
    """The share of Catches a draft Hunt counts, worked out from the fixture's loot by hand, times its open share."""
    if hunt.get("class") == "species.any":
        share = HAUL_SHARE
    elif hunt.get("class") == "quality.uncommon":
        share = UNCOMMON_SHARE
    else:
        species = hunt["species"]
        assert isinstance(species, int)
        share = SHARES[species]
    conditions = hunt.get("conditions")
    if isinstance(conditions, dict):
        (span,) = [name for name, time in SPANS.items() if conditions == {"time": time}]
        share *= OPEN[span]
    return share


def test_the_tunables() -> None:
    # Tunables: draft tier times 45 min / 2 h / 4 h, the draft catch rate 180 Catches an hour.
    assert TIER_MINUTES == (45, 120, 240)
    assert CATCHES_PER_HOUR == 180


@pytest.mark.parametrize(
    ("need", "tier"),
    [(0.2, 1), (1.4, 1), (6.75, 7), (8.5, 9), (19.4, 19), (19.6, 20), (21.6, 20), (22.5, 25), (108, 110), (576, 575)],
)
def test_tiers_are_rounded_to_friendly_numbers(need: float, tier: int) -> None:
    # DATA-R99, a default chosen in #298: a tier below 20 rounds to a whole number (at least 1), above to the
    # nearest 5, halves up.
    assert friendly(need) == tier


def test_one_zone_drafts_events_of_3_to_5_hunts_with_tiers_of_about_45_120_and_240_minutes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, hunts.md › The 1.0 event pool: one draft per Species in the zone's top shares, each of 3-5 Hunts in
    # the four shapes (Haul, Named fish, Quality, Timed; no size Hunt, #337), at most one Timed; each tier's
    # expected time at 180 Catches an hour is about 45 min, 2 h and 4 h (Tunables).
    root = write_tree(tmp_path)
    out = tmp_path / "drafts"
    code, output = _propose(root, capsys, "--zone", "12", "--out", str(out))
    assert code == 0, output
    drafts = _drafts(out)
    assert sorted(drafts) == [
        "elwynn_forest_brilliant_smallfish",
        "elwynn_forest_rainbow_fin_albacore",
        "elwynn_forest_slitherskin_mackerel",
    ]
    for draft in drafts.values():
        hunts = _hunts(draft)
        assert 3 <= len(hunts) <= 5
        assert sum(1 for hunt in hunts if "conditions" in hunt) <= 1
        shapes = {str(hunt["id"]).rsplit("_", 1)[1] for hunt in hunts}
        assert {"haul", "named", "quality", "timed"} == shapes  # the zone lists an uncommon item
        assert all("minBand" not in hunt for hunt in hunts)
        for hunt in hunts:
            tiers = hunt["tiers"]
            assert isinstance(tiers, list) and len(tiers) == 3
            rate = CATCHES_PER_HOUR / 60 * _share(hunt)
            for tier, minutes in zip(tiers, TIER_MINUTES):
                assert tier / rate == pytest.approx(minutes, rel=0.12), (hunt["id"], tiers)
    # By hand: the Haul counts 80% of Catches, 2.4 a minute: 108, 288 and 576, rounded to 110, 290 and 575.
    haul = _hunts(drafts["elwynn_forest_brilliant_smallfish"])[0]
    assert haul == {
        "id": "elwynn_forest_brilliant_smallfish_haul",
        "class": "species.any",
        "tiers": [110, 290, 575],
        "name": "{TODO Hunt name}",
    }


def test_a_draft_s_shapes_and_text(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97, DATA-R99: the event file's format, its id from the zone's and the Species' names ([%w_]+, never p_),
    # zones as asked, skill left out for the generator to work out, a Timed Hunt's tag (night, day or dusk), and
    # TODO lore. The Named fish is the draft's Species.
    root = write_tree(tmp_path)
    out = tmp_path / "drafts"
    assert _propose(root, capsys, "--zone", "12", "--out", str(out))[0] == 0
    draft = _drafts(out)["elwynn_forest_brilliant_smallfish"]
    assert draft["event"] == {
        "id": "elwynn_forest_brilliant_smallfish",
        "zones": [12],
        "tags": ["night"],
        "name": "{TODO event name}",
        "note": "{TODO event note}",
    }
    by_shape = {str(hunt["id"]).rsplit("_", 1)[1]: hunt for hunt in _hunts(draft)}
    assert by_shape["named"]["species"] == 6291
    assert by_shape["quality"]["class"] == "quality.uncommon"
    assert by_shape["timed"]["class"] == "species.any"
    assert by_shape["timed"]["conditions"] == {"time": SPANS["night"]}
    # The next drafts take the other spans in turn, the second on its Named fish.
    second = {str(hunt["id"]).rsplit("_", 1)[1]: hunt for hunt in _hunts(_drafts(out)["elwynn_forest_slitherskin_mackerel"])}
    assert second["timed"]["species"] == 6303 and second["timed"]["conditions"] == {"time": SPANS["day"]}
    third = _drafts(out)["elwynn_forest_rainbow_fin_albacore"]
    assert _event(third)["tags"] == ["dusk"]


def test_it_prints_each_hunt_s_expected_minutes_per_tier(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: per draft, each Hunt's expected minutes per tier, so curators can compare.
    root = write_tree(tmp_path)
    code, output = _propose(root, capsys, "--zone", "12", "--out", str(tmp_path / "drafts"))
    assert code == 0
    assert "elwynn_forest_brilliant_smallfish.toml" in output
    assert "elwynn_forest_brilliant_smallfish_haul: Haul, species.any, 80.0% of Catches: tiers 110 / 290 / 575," in output
    assert "46 / 121 / 240 min" in output
    timed = "elwynn_forest_brilliant_smallfish_timed: Timed (night), species.any, 80.0% of Catches, open 75% of a run"
    assert timed in output


def test_two_zones_of_one_band_draft_one_event_over_both(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97, DATA-R99: two zones of the same band (Elwynn Forest, -25, and Stranglethorn Vale, 130, both low);
    # the event lists both, and a Hunt's share is its mean over their areas with a loot share (#298). By hand, the
    # Haul: Elwynn Forest 80%; Stranglethorn Vale 13760 10% and 13759 6.5%, each gated by day or night (open 75%),
    # and 6303 under the summer window (a season, so 0); Jaguero Isle 6303 10.5%: (0.80 + 0.12375 + 0.105) / 3.
    root = write_tree(tmp_path)
    out = tmp_path / "drafts"
    code, output = _propose(root, capsys, "--zone", "12", "--zone", "33", "--out", str(out))
    assert code == 0, output
    drafts = _drafts(out)
    assert drafts
    assert "_haul: Haul, species.any, 34.3% of Catches" in output
    for name, draft in drafts.items():
        assert name.startswith("elwynn_forest_stranglethorn_vale_")
        assert _event(draft)["zones"] == [12, 33]


def test_an_uncommon_item_too_rare_for_a_45_minute_tier_gets_no_quality_hunt(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, Tunables: at 0.5% of Catches, 1.5 an hour, quality.uncommon can't fill a 45-minute tier, so no draft
    # has a Quality Hunt, and the script says why.
    root = write_tree(tmp_path, area_loot=PROPOSE_LOOT.replace("12,6351,5,,,", "12,6351,0.5,,,"))
    out = tmp_path / "drafts"
    code, output = _propose(root, capsys, "--zone", "12", "--out", str(out))
    assert code == 0, output
    for draft in _drafts(out).values():
        assert all(hunt.get("class") != "quality.uncommon" for hunt in _hunts(draft))
    note = "no Quality Hunt: quality.uncommon is 0.5% of Catches there, too few for a 45-minute tier at 180 Catches"
    assert note in output


def test_two_zones_of_different_bands_are_refused(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: two zones of one band only; Durotar (14) has a skill base of 160, mid, and Elwynn Forest low.
    root = write_tree(tmp_path)
    out = tmp_path / "drafts"
    code, output = _propose(root, capsys, "--zone", "12", "--zone", "14", "--out", str(out))
    assert code == 1
    assert "zone 12 (Elwynn Forest) is in the low band and zone 14 (Durotar) in the mid band" in output
    assert not out.exists()


@pytest.mark.parametrize(
    ("zones", "problem"),
    [
        (["18"], "area 18 (Crystal Lake) isn't a zone (parent 0) in data/db2/areas.csv (DATA-R97)"),
        (["999"], "area 999 isn't in data/db2/areas.csv"),
        (["16591"], "zone 16591 (Riverglades) has no skill base, so its band can't be worked out (DATA-R97, LOG-R55)"),
        (["12", "12"], "zone 12 is given twice"),
        (["12", "33", "14"], "an event has 1 or 2 zones (DATA-R97); 3 were given"),
    ],
)
def test_bad_zones_are_refused(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], zones: list[str], problem: str
) -> None:
    # DATA-R97: 1-2 zones, each a zone of the slice with a skill base.
    root = write_tree(tmp_path)
    args = [arg for zone in zones for arg in ("--zone", zone)]
    code, output = _propose(root, capsys, *args, "--out", str(tmp_path / "drafts"))
    assert code == 1
    assert problem in output


def test_a_zone_without_species_drafts_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: Riverglades (16591), given a skill base here, has no catch list, so there is nothing to draft from.
    areas = AREAS_TOML + SKILL_14 + '\n[[area]]\nid = 16591\nskillBase = 100\nwhy = "fixture"\n'
    root = write_tree(tmp_path, areas=areas)
    code, output = _propose(root, capsys, "--zone", "16591", "--out", str(tmp_path / "drafts"))
    assert code == 1
    assert "zone 16591 (Riverglades) and its subzones list no Species with a loot share" in output


def test_drafts_go_to_a_dated_folder_under_the_temp_directory(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, a default chosen in #298: without --out, a dated folder under the system temp directory.
    root = write_tree(tmp_path)
    code, output = _propose(root, capsys, "--zone", "12")
    assert code == 0, output
    folder = tmp_path / "tmp" / "pagle-event-drafts-2026-10-22-093005"
    assert len(_drafts(folder)) == 3
    assert str(folder) in output


def test_drafts_never_go_under_data_and_nothing_under_data_changes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99: drafts are written outside data/, and the script never commits or changes data/.
    root = write_tree(tmp_path)
    before = data_files(root)
    code, output = _propose(root, capsys, "--zone", "12", "--out", str(root / "data" / "hunts" / "events"))
    assert code == 1
    assert "drafts are never written under data/" in output
    assert _propose(root, capsys, "--zone", "12", "--out", str(tmp_path / "drafts"))[0] == 0
    assert data_files(root) == before


def test_a_draft_fails_the_lore_check_until_its_todo_text_is_written(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, DATA-R107: a draft's TODO name and note fail the hunts lore check (placeholder) in check-event.py and
    # in the generator; written, the draft passes both.
    root = write_tree(tmp_path)
    out = tmp_path / "drafts"
    assert _propose(root, capsys, "--zone", "12", "--out", str(out))[0] == 0
    path = out / "elwynn_forest_brilliant_smallfish.toml"
    code, output = run(root, capsys, str(path), main=check_event)
    assert code == 1
    assert f"{path}: event.elwynn_forest_brilliant_smallfish.name: placeholder" in output
    assert f"{path}: event.elwynn_forest_brilliant_smallfish.note: placeholder" in output
    assert f"{path}: hunt.elwynn_forest_brilliant_smallfish_haul.name: placeholder" in output

    committed = root / event_file("elwynn_forest_brilliant_smallfish")
    committed.parent.mkdir(parents=True, exist_ok=True)
    committed.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
    code, output = run(root, capsys)
    assert code == 1 and "event.elwynn_forest_brilliant_smallfish.name: placeholder" in output
    committed.unlink()

    written = path.read_text(encoding="utf-8")
    written = written.replace("{TODO event name}", "Smallfish Season").replace("{TODO event note}", "Small fry.")
    written = written.replace("{TODO Hunt name}", "A Hunt")
    path.write_text(written, encoding="utf-8")
    code, output = run(root, capsys, str(path), main=check_event)
    assert code == 0, output
    committed.write_text(written, encoding="utf-8")
    assert run(root, capsys)[0] == 0
