"""scripts/check-event.py (DATA-R99): DATA-R97's and DATA-R99's checks on one event file or one pushed huntEvent item
(hunts.md › Contracts), against the committed catalogue and Hunt list, over event_scripts_fixture's tree."""

from pathlib import Path

import pytest

from cli_fixture import run, run_split
from event_scripts_fixture import PUSHED, data_files, pushed, write_json, write_tree
from events_fixture import SHALLOWS, event
from pagle_data.check_event import main as check_event
from pagle_data.events import event_file


def _check(root: Path, capsys: pytest.CaptureFixture[str], path: Path) -> tuple[int, str]:
    return run(root, capsys, str(path), main=check_event)


def _write(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def _hunt(index: int, **changes: object) -> list[dict[str, object]]:
    """PUSHED's Hunts, a copy, with changes made to the one at index."""
    hunts = PUSHED["hunts"]
    assert isinstance(hunts, list)
    changed: list[dict[str, object]] = [dict(hunt) for hunt in hunts]
    changed[index].update(changes)
    return changed


# --- A file (DATA-R97, DATA-R99) ---


def test_a_good_event_file_passes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: every check passes, so it exits 0, saying so.
    root = write_tree(tmp_path)
    path = _write(tmp_path / "drafts" / "stv_shallows.toml", SHALLOWS)
    code, out, err = run_split(root, capsys, str(path), main=check_event)
    assert code == 0, out + err
    assert out == f"check-event: {path} passes DATA-R97's and DATA-R99's checks\n"


def test_a_bad_event_file_names_each_problem_in_the_generator_s_words(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R99, DATA-R63: each failure on its own line, as the generator words it, naming the file and the event or
    # Hunt; it exits non-zero.
    root = write_tree(tmp_path)
    text = SHALLOWS.replace('tags = ["coast"]', 'tags = ["coast", "foggy"]').replace("species = 13760", "species = 6291")
    path = _write(tmp_path / "drafts" / "stv_shallows.toml", text)
    code, out, err = run_split(root, capsys, str(path), main=check_event)
    assert code == 1
    assert out.splitlines() == [
        f"check-event: {path}: event.tags: 'foggy' isn't a tag in data/hunts/tags.toml (DATA-R97)",
        f"check-event: {path}: hunt.stv_sunscale.species: Species 6291 isn't listed in zones 33 and 14 or their"
        " subzones, so the Hunt can't complete there (DATA-R99)",
    ]
    assert f"2 problem(s) in {path}" in err


def test_a_file_starting_p_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97: a file's event never starts p_, which is kept for pushed events.
    root = write_tree(tmp_path)
    path = _write(tmp_path / "drafts" / "p_shallows.toml", SHALLOWS.replace('"stv_shallows"', '"p_shallows"'))
    code, output = _check(root, capsys, path)
    assert code == 1
    assert f"{path}: event.id: 'p_shallows' starts with p_, which is kept for pushed events (DATA-R97)" in output


def test_a_file_whose_ids_are_already_in_the_pool_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R97, DATA-R92, DATA-R99: the event's ID and each Hunt's are unique across the pool and hunts.toml; the
    # problem is the checked file's, never the committed one's.
    root = write_tree(tmp_path, {"stv_shallows": SHALLOWS})
    path = _write(tmp_path / "drafts" / "stv_shallows.toml", SHALLOWS)
    code, output = _check(root, capsys, path)
    assert code == 1
    assert f"{path}: event.id: the event ID 'stv_shallows' is already in data/hunts/events/ (DATA-R97)" in output
    assert f"{path}: hunt.stv_sunscale: the Hunt ID 'stv_sunscale' is used twice (DATA-R92, DATA-R99)" in output
    assert event_file("stv_shallows") not in output


def test_a_committed_event_file_is_checked_in_place(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: a file in data/hunts/events/ is checked as the generator checks it, and only its problems are named.
    root = write_tree(tmp_path, {"stv_shallows": SHALLOWS, "other": event("other")})
    assert _check(root, capsys, root / event_file("stv_shallows"))[0] == 0
    (root / event_file("other")).write_text(event("other", 2), encoding="utf-8")
    code, output = _check(root, capsys, root / event_file("other"))
    assert code == 1
    assert f"check-event: {event_file('other')}: has 2 Hunts; an event has 3 to 5 (DATA-R99)" in output
    assert _check(root, capsys, root / event_file("stv_shallows"))[0] == 2  # the pool has a problem elsewhere


def test_problems_in_the_committed_data_are_named_apart(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: the committed data must read cleanly to check against; its problems are printed and it exits 2.
    root = write_tree(tmp_path, {"two": event("two", 2)})
    path = _write(tmp_path / "drafts" / "stv_shallows.toml", SHALLOWS)
    code, output = _check(root, capsys, path)
    assert code == 2
    assert "data/hunts/events/two.toml: has 2 Hunts" in output
    assert "the committed data has 1 problem(s); fix them and run scripts/generate-data.py" in output


# --- A pushed huntEvent item (hunts.md › Contracts, DATA-R99) ---


def test_a_good_pushed_item_passes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # hunts.md › Contracts: the huntEvent fields, an id starting p_ and rotation = false; DATA-R99's checks pass.
    root = write_tree(tmp_path)
    path = write_json(tmp_path / "pushed.json", PUSHED)
    code, output = _check(root, capsys, path)
    assert code == 0, output
    assert f"{path} passes" in output


def test_a_bad_pushed_item_names_each_problem(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99 on a pushed item: an areas condition of its own, a 40-character Hunt name (DATA-R107's name limit, 28,
    # whatever data/checks.toml says), an unknown tag and a Species not in its zones, all in one run.
    root = write_tree(tmp_path)
    (root / "data" / "checks.toml").write_text("typicalLength = false\nlore = []\n", encoding="utf-8")
    hunts = _hunt(0, name="A" * 40, conditions={"areas": [33]})
    hunts[1] = {**hunts[1], "species": 6291}
    path = write_json(tmp_path / "pushed.json", pushed(tags=["coast", "foggy"], hunts=hunts))
    code, output = _check(root, capsys, path)
    assert code == 1
    for problem in (
        f"{path}: hunts.p_stv_moon_tide_haul.conditions: has an areas condition of its own; the event's zones supply"
        " it (HNT-R141, DATA-R99)",
        f"{path}: hunt.p_stv_moon_tide_haul.name: length: 40 code points, over name's limit of 28 (DATA-R107)",
        f"{path}: tags: 'foggy' isn't a tag in data/hunts/tags.toml (DATA-R97)",
        f"{path}: hunts.p_stv_moon_tide_nightfin.species: Species 6291 isn't listed in zone 33 or its subzones, so the"
        " Hunt can't complete there (DATA-R99)",
    ):
        assert problem in output


@pytest.mark.parametrize(
    ("item", "problem"),
    [
        (pushed(id="stv_moon_tide"), "id: 'stv_moon_tide' doesn't start with p_; a pushed event's does (HNT-R140)"),
        (pushed(id="p_moon-tide"), "id: 'p_moon-tide' doesn't match [%w_]+ (DATA-R97)"),
        (pushed(rotation=True), "rotation: true; a pushed event never enters the fallback rotation (hunts.md › Contracts)"),
        (pushed(kind="huntRun"), "kind: expected \"huntEvent\", got 'huntRun' (PUSH-R21)"),
        (pushed(v=2), "v: expected 1, the huntEvent version Hunts knows, got 2 (PUSH-R21)"),
        ({k: v for k, v in PUSHED.items() if k != "skill"}, "missing key 'skill'"),
        (pushed(retired="2027-01-01"), "unknown key 'retired'"),
        (pushed(zones=[33, 14, 12]), "zones: has 3 zones; an event has 1 or 2 (DATA-R97)"),
        (pushed(tags=["mid"]), "tags: 'mid' is a band tag, and the event's band is low; the generator adds the band"),
        (pushed(hunts=_hunt(1, tiers=[15, 5])), "hunts.p_stv_moon_tide_nightfin.tiers: expected strictly ascending"),
        (pushed(hunts=_hunt(1, id="p_stv_moon_tide_haul")), "the Hunt ID 'p_stv_moon_tide_haul' is used twice"),
        (pushed(hunts=_hunt(2, minBand=3)), "hunts.p_stv_moon_tide_late.minBand"),
        (pushed(hunts=_hunt(0, tiers=[1.5])), "hunts.p_stv_moon_tide_haul.tiers"),
        (pushed(name="{zone} tide"), "event.p_stv_moon_tide.name: placeholder"),
        (pushed(hunts=_hunt(0)[:2]), "has 2 Hunts; an event has 3 to 5 (DATA-R99)"),
    ],
)
def test_each_pushed_item_check_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], item: dict[str, object], problem: str
) -> None:
    # hunts.md › Contracts, PUSH-R21, DATA-R97, DATA-R99: the pushed item's fields and versions, and DATA-R99's
    # checks as on a file, but its id must start p_ (a file's must not) and it never rotates.
    root = write_tree(tmp_path)
    path = write_json(tmp_path / "pushed.json", item)
    code, output = _check(root, capsys, path)
    assert code == 1, output
    assert problem in output


def test_a_file_that_isn_t_json_or_toml_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63: a file that doesn't parse is named, and so is one of neither kind.
    root = write_tree(tmp_path)
    bad = _write(tmp_path / "pushed.json", "{ not json")
    code, output = _check(root, capsys, bad)
    assert code == 1 and f"{bad}: not valid JSON" in output
    other = _write(tmp_path / "event.txt", SHALLOWS)
    code, output = _check(root, capsys, other)
    assert code == 1 and "expected an event file (.toml) or a pushed huntEvent item (.json)" in output
    code, output = _check(root, capsys, tmp_path / "missing.toml")
    assert code == 1 and "missing.toml: missing" in output


def test_nothing_under_data_changes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R99: check-event.py only reads.
    root = write_tree(tmp_path, {"stv_shallows": SHALLOWS})
    before = data_files(root)
    _check(root, capsys, write_json(tmp_path / "pushed.json", PUSHED))
    _check(root, capsys, root / event_file("stv_shallows"))
    assert data_files(root) == before
