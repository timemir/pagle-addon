"""Observed pairs and confirmation (DATA-R47–R56): what data/observed/ implies for the catalogue, over
test_catch_lists.py's fixture tree with hand-made rows in data/observed/ (#94's fixture layer). Every row here is a
fixture row; none is a committed report.

The tree's lists after DATA-R26 steps 1 and 2: Elwynn Forest 12 and its Crystal Lake 18 list 6291; Stranglethorn
Vale 33 lists 6303 (summer), 13759 (night), 13760 (day), 19803 and 19807 (event.301); its Jaguero Isle 297 lists
6303; Echo Isles 368 lists 13759 (night) and 13760; Durotar 14 and Riverglades 16591 list nothing.
"""

from pathlib import Path

import pytest

from observed_fixture import i_row, report
from test_catch_lists import AREAS_TOML, CATALOGUE, ITEMS, area_record, run, write_tree

# Reporter keys (REP-R36). DEV_KEY is listed in dev.toml's keys, so it reports as dev (DATA-R46).
ALICE = "aaaaaaaa"
BOB = "bbbbbbbb"
DEV_KEY = "dddddddd"
DEV = f'keys = ["{DEV_KEY}"]\n'

# 30001 is a Species item no baseline loot holds: a new Species (DATA-R49).
NEW_SPECIES = 30001
ITEMS_WITH_NEW_SPECIES = ITEMS + f'\n[item.{NEW_SPECIES}]\ncategory = "fish"\n'


def generate(
    root: Path,
    capsys: pytest.CaptureFixture[str],
    reports: dict[str, str] | None = None,
    dev: str = DEV,
    areas: str = AREAS_TOML,
) -> tuple[str, str]:
    """Catalogue.lua and the generator's output for the tree with these observations."""
    code, output = run(write_tree(root, areas, items=ITEMS_WITH_NEW_SPECIES, dev=dev, reports=reports), capsys)
    assert code == 0, output
    return (root / CATALOGUE).read_text(encoding="utf-8"), output


def fact(kind: str, ids: str, build: int = 70338) -> str:
    """A dev.toml [[fact]] (DATA-R122), after a blank line."""
    return f'\n[[fact]]\nkind = "{kind}"\nbuild = {build}\nnote = "seen"\n{ids}'


def test_an_unlisted_pair_joins_its_area_confirmed_after_one_reporter(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R47: 6308 (junk) is in neither Echo Isles' (368) nor Durotar's (14) list, ships and isn't Noise, so the
    # row is an observed pair at 368. DATA-R49: one reporter is enough for an ordinary pair; DATA-R48: it joins
    # confirmed (DATA-R26 step 3). Its zone's list stays as it is: lists are never inherited.
    text, _ = generate(tmp_path, capsys, {ALICE: report(i_row(6308, 368))})
    assert "{ confirmed = true, itemID = 6308 }" in area_record(text, 368)
    assert "itemID = 6308" not in area_record(text, 14)


@pytest.mark.parametrize(
    ("item", "entry"),
    [
        (NEW_SPECIES, f"{{ confirmed = true, itemID = {NEW_SPECIES} }}"),
        # 19803 is listed only in 33, gated by event.301, so its pair takes that gate (DATA-R47).
        (
            19803,
            '{ confirmed = true, gate = W["event.301"], gateConfirmed = false, itemID = 19803, window = "event.301" }',
        ),
    ],
)
def test_a_new_species_or_a_legend_joins_only_after_two_reporters_the_dev_counting_as_one(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], item: int, entry: str
) -> None:
    # DATA-R49: any pair of a new Species (30001, in no baseline loot) or of a Legend (19803) is a big fact, so it
    # needs two reporters. DATA-R46: the dev's keys and the dev's facts are one reporter, dev; DATA-R45: a pair
    # fact counts exactly like a catch row from dev.
    pair_fact = fact("pair", f"item = {item}\narea = 368\n")
    text, _ = generate(tmp_path / "one", capsys, {ALICE: report(i_row(item, 368))})
    assert f"itemID = {item}" not in area_record(text, 368)
    text, _ = generate(tmp_path / "dev", capsys, {DEV_KEY: report(i_row(item, 368))}, dev=DEV + pair_fact)
    assert f"itemID = {item}" not in area_record(text, 368)
    text, _ = generate(tmp_path / "two", capsys, {ALICE: report(i_row(item, 368))}, dev=DEV + pair_fact)
    assert entry in area_record(text, 368)


def test_an_observed_pair_wins_over_a_drop(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R26 step 3: observed pairs win over a drop. DATA-R47: the lists are taken after step 2, so the dropped
    # 13760 is in neither Echo Isles' nor Durotar's list, and comes back; the only other area listing it (33)
    # gates it by day, so it takes that gate.
    drop = '\n[[catch]]\narea = 368\nitem = 13760\nop = "drop"\nwhy = "x"\n'
    text, _ = generate(tmp_path, capsys, {ALICE: report(i_row(13760, 368))}, areas=AREAS_TOML + drop)
    assert '{ confirmed = true, gate = W.day, gateConfirmed = false, itemID = 13760, window = "day" }' in (
        area_record(text, 368)
    )


def test_a_subzone_row_evidences_its_zone_s_entry_when_the_subzone_s_list_lacks_the_item(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R47 (REP-R10): Jaguero Isle (297) doesn't list 13759, its zone Stranglethorn Vale (33) does, so a row at
    # 297 evidences 33's entry (DATA-R48) and makes no observed pair.
    text, _ = generate(tmp_path, capsys, {ALICE: report(i_row(13759, 297))})
    assert '{ confirmed = true, gate = W.night, gateConfirmed = false, itemID = 13759, window = "night" }' in (
        area_record(text, 33)
    )
    assert "itemID = 13759" not in area_record(text, 297)


def test_a_subzone_row_does_not_evidence_an_observed_pair_its_zone_joined(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R47: evidence is judged against the lists after DATA-R26 steps 1 and 2. The Legend 19803 (a big fact,
    # DATA-R49) is listed only in 33, gated by event.301; ALICE's row and a dev pair fact make it an observed pair
    # that joins Durotar (14) with that gate. BOB's row at Echo Isles (368, Durotar's subzone) is outside
    # event.301, but neither 368's nor 14's step-2 list has 19803, so it evidences no entry: it's an observed pair
    # at 368 from one reporter, which joins nothing and judges no gate (DATA-R52). The dev's gate fact confirms
    # the gate, and nothing contradicts it.
    dev = DEV + fact("pair", "item = 19803\narea = 14\n") + fact("gate", 'item = 19803\nwindow = "event.301"\n')
    reports = {ALICE: report(i_row(19803, 14, extra="event = [301]\n")), BOB: report(i_row(19803, 368))}
    text, _ = generate(tmp_path, capsys, reports, dev=dev)
    joined = '{ confirmed = true, gate = W["event.301"], gateConfirmed = true, itemID = 19803, window = "event.301" }'
    assert joined in area_record(text, 14)
    assert "gateConfirmed = true" in entry_of(text, 33, 19803)
    assert "itemID = 19803" not in area_record(text, 368)


def test_an_observed_pair_takes_a_gate_only_when_every_other_area_listing_the_item_has_the_same_one(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R47: 13759 is gated by night in both 33 and 368, so its pair at Crystal Lake (18) takes night. 13760 is
    # gated by day in 33 but not in 368, so its pair is ungated, with a warning (DATA-R64). 6291 is ungated
    # wherever it is listed, so its pair in 368 is ungated without one.
    rows = report(i_row(13759, 18), i_row(13760, 18), i_row(6291, 368))
    text, output = generate(tmp_path, capsys, {ALICE: rows})
    assert '{ confirmed = true, gate = W.night, gateConfirmed = false, itemID = 13759, window = "night" }' in (
        area_record(text, 18)
    )
    assert "{ confirmed = true, itemID = 13760 }" in area_record(text, 18)
    assert "{ confirmed = true, itemID = 6291 }" in area_record(text, 368)
    assert (
        "generate-data: warning: the observed pair item 13760 in area 18 joins ungated, but the item is gated"
        " elsewhere (area 33 by day)"
    ) in output
    assert "item 6291" not in output


def entry_of(text: str, area: int, item: int) -> str:
    """The catch entry for item in area's record, from its { to its }."""
    record = area_record(text, area)
    start = record.index(f"itemID = {item},")
    return record[record.rindex("{", 0, start) : record.index("}", start) + 1]


def window_entry(text: str, window: str) -> str:
    """The catalogue's windows entry for window (Contracts), as one line."""
    key = f'["{window}"]' if "." in window else window
    start = text.index(f"\t\t{key} = {{ confirmed = ")
    return text[start : text.index("\n", start)]


INSIDE_DAY = 't = "10:00"\nm = 5\n'
OUTSIDE_DAY = 't = "03:00"\nm = 5\n'


def test_a_gate_is_confirmed_by_inside_rows_and_demoted_by_any_outside_row_until_it_is_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R52: Stranglethorn Vale's 13760 is gated by day, which the baseline gives it (an ordinary fact,
    # DATA-R49), so one reporter's inside row confirms it; DATA-R53: so is the day window. One outside row from any
    # reporter contradicts it, so gateConfirmed is false and the window unconfirmed; DATA-R50: rejecting that row
    # confirms them again.
    inside = {ALICE: report(i_row(13760, 33, extra=INSIDE_DAY))}
    text, _ = generate(tmp_path / "inside", capsys, inside)
    assert "gateConfirmed = true" in entry_of(text, 33, 13760)
    assert "confirmed = true" in window_entry(text, "day")

    outside = {**inside, BOB: report(i_row(13760, 33, extra=OUTSIDE_DAY))}
    text, _ = generate(tmp_path / "outside", capsys, outside)
    assert "gateConfirmed = false" in entry_of(text, 33, 13760)
    assert "confirmed = false" in window_entry(text, "day")

    rejected = {**inside, BOB: report(i_row(13760, 33, extra=OUTSIDE_DAY + 'rejected = "a client bug"\n'))}
    text, _ = generate(tmp_path / "rejected", capsys, rejected)
    assert "gateConfirmed = true" in entry_of(text, 33, 13760)
    assert "confirmed = true" in window_entry(text, "day")


# Stranglethorn Vale's gates, each given by the baseline (so one reporter confirms, DATA-R49), and a row inside each.
WINDOW_OF = {13760: "day", 13759: "night", 6303: "summer", 19807: "event.301"}
INSIDE = {13760: INSIDE_DAY, 13759: OUTSIDE_DAY, 6303: INSIDE_DAY, 19807: "event = [301]\n"}


@pytest.mark.parametrize(
    ("item", "extra", "side"),
    [
        # time: day is [06:00, 24:00); the span is the bucket [t, t+15).
        (13760, 't = "10:00"\nm = 5\n', "inside"),
        (13760, 't = "23:45"\nm = 5\n', "inside"),
        (13760, 't = "05:45"\nm = 5\n', "outside"),
        (13760, "", "neither"),
        # time wrapping midnight: night is [18:00, 12:00).
        (13759, 't = "11:45"\nm = 5\n', "inside"),
        (13759, 't = "12:00"\nm = 5\n', "outside"),
        # season: summer is 20 Mar to 18 Sep, both inclusive; the span is the whole realm month.
        (6303, 't = "03:00"\nm = 5\n', "inside"),
        (6303, 't = "03:00"\nm = 11\n', "outside"),
        (6303, 't = "03:00"\nm = 3\n', "neither"),
        (6303, 't = "03:00"\nm = 9\n', "neither"),
        (6303, "", "neither"),
        # events: event.301 is { events = { 301 } }; no event= means no listed event was active.
        (19807, "event = [301]\n", "inside"),
        (19807, 'event = [301]\nt = "03:00"\nm = 11\n', "inside"),
        (19807, "", "outside"),
    ],
)
def test_a_row_is_inside_outside_or_neither_by_its_bucket_month_and_events(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], item: int, extra: str, side: str
) -> None:
    # DATA-R51, seen through DATA-R52: an inside row alone confirms the gate; an outside row contradicts it even
    # beside another reporter's inside row; a row that is neither does neither.
    text, _ = generate(tmp_path / "alone", capsys, {ALICE: report(i_row(item, 33, extra=extra))})
    alone = "gateConfirmed = true" in entry_of(text, 33, item)
    rows = {ALICE: report(i_row(item, 33, extra=extra)), BOB: report(i_row(item, 33, extra=INSIDE[item]))}
    text, _ = generate(tmp_path / "beside", capsys, rows)
    beside = "gateConfirmed = true" in entry_of(text, 33, item)
    assert f"window = \"{WINDOW_OF[item]}\"" in entry_of(text, 33, item)
    assert (alone, beside) == {"inside": (True, True), "neither": (False, True), "outside": (False, False)}[side]


def test_a_new_window_needs_two_reporters(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R49: the baseline never gives 13760 the night window, so the gate an areas.toml add sets in Echo Isles
    # (368) is a new window, confirmed only by inside rows from two reporters (DATA-R52).
    add = '\n[[catch]]\narea = 368\nitem = 13760\nop = "add"\ngate = "night"\nwhy = "x"\n'
    one = {ALICE: report(i_row(13760, 368, extra=OUTSIDE_DAY))}
    text, _ = generate(tmp_path / "one", capsys, one, areas=AREAS_TOML + add)
    assert "gateConfirmed = false" in entry_of(text, 368, 13760)
    two = {**one, BOB: report(i_row(13760, 368, extra=OUTSIDE_DAY))}
    text, _ = generate(tmp_path / "two", capsys, two, areas=AREAS_TOML + add)
    assert "gateConfirmed = true" in entry_of(text, 368, 13760)


def test_dev_facts_confirm_a_gate_in_every_area_and_a_named_window(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R122: a gate fact confirms that gate in every area (DATA-R52), but not the pair (DATA-R48). DATA-R53: a
    # window fact confirms its window, and a confirmed gate with none contradicted confirms the gate's window.
    dev = DEV + fact("gate", 'item = 13759\nwindow = "night"\n') + fact("window", 'window = "winter"\n')
    text, _ = generate(tmp_path, capsys, dev=dev)
    entry = '{ confirmed = false, gate = W.night, gateConfirmed = true, itemID = 13759, window = "night" }'
    assert entry in area_record(text, 33)
    assert entry in area_record(text, 368)
    assert "confirmed = true" in window_entry(text, "night")
    assert "confirmed = true" in window_entry(text, "winter")
    assert "confirmed = false" in window_entry(text, "summer")


def test_a_dev_weekly_fact_confirms_the_rule_and_its_event_window_until_a_row_lies_outside_its_span(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R54: a weekly rule is confirmed only by a dev fact; DATA-R53: event.301 takes its rule's confirmation.
    # A row with event 301 bucketed 10:00 lies wholly outside Sunday 14:00 for 120 minutes, so it contradicts the
    # rule; a row without t can't.
    weekly = DEV + fact("weekly", "event = 301\n")
    rule = "[301] = { confirmed = true, duration = 120, start = 840, weekday = 1 }"
    text, _ = generate(tmp_path / "fact", capsys, dev=weekly)
    assert rule in text
    assert "confirmed = true" in window_entry(text, "event.301")

    no_t = {ALICE: report(i_row(19807, 33, extra="event = [301]\n"))}
    text, _ = generate(tmp_path / "no_t", capsys, no_t, dev=weekly)
    assert rule in text

    ten = {ALICE: report(i_row(19807, 33, extra='event = [301]\nt = "10:00"\nm = 6\n'))}
    text, _ = generate(tmp_path / "ten", capsys, ten, dev=weekly)
    assert rule.replace("true", "false") in text
    assert "confirmed = false" in window_entry(text, "event.301")


def skill_row(area: int, land: str = "") -> str:
    """A [[k]] row (REP-R21), with land = <n> when given."""
    return f"[[k]]\narea = {area}\nbuild = 70338\ncasts = 10\naway = 2\n{land}"


@pytest.mark.parametrize(
    ("reports", "dev", "confirmed"),
    [
        ({ALICE: report(skill_row(33, "land = 120\n"))}, DEV, False),
        ({ALICE: report(skill_row(33, "land = 130\n"))}, DEV, True),
        ({ALICE: report(skill_row(33, "land = 200\n")), BOB: report(skill_row(33, "land = 129\n"))}, DEV, False),
        ({ALICE: report(skill_row(33))}, DEV, False),
        ({}, DEV + fact("skillBase", "area = 33\n"), True),
        ({ALICE: report(skill_row(33, "land = 100\n"))}, DEV + fact("skillBase", "area = 33\n"), False),
        # A row is judged against its own area's base only: one for Jaguero Isle (297) says nothing about 33.
        ({ALICE: report(skill_row(297, "land = 100\n"))}, DEV, False),
    ],
)
def test_a_skill_base_is_contradicted_by_a_land_below_it_and_otherwise_confirmed_by_any_land_or_a_dev_fact(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], reports: dict[str, str], dev: str, confirmed: bool
) -> None:
    # DATA-R55 on Stranglethorn Vale's skill base 130 (skill.csv, DATA-R30).
    text, _ = generate(tmp_path, capsys, reports, dev=dev)
    assert f"skillBaseConfirmed = {str(confirmed).lower()}" in area_record(text, 33)


@pytest.mark.parametrize(
    ("build", "extra", "fails"),
    [(70338, "", True), (70400, "", True), (70337, "", False), (70338, 'rejected = "a fluke"\n', False)],
)
def test_an_observation_of_a_removed_item_from_its_removed_from_build_on_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], build: int, extra: str, fails: bool
) -> None:
    # DATA-R23: 6309 is removed from build 70338. A non-rejected observation on that build or later fails the
    # generator (DATA-R63), writing nothing; one from an earlier build, or a rejected one (DATA-R50), is fine.
    rows = {ALICE: report(i_row(6309, 368, build=build, extra=extra))}
    code, output = run(write_tree(tmp_path, items=ITEMS_WITH_NEW_SPECIES, dev=DEV, reports=rows), capsys)
    assert (code == 1) == fails, output
    message = (
        f"data/observed/reports/{ALICE}.toml: i[0]: item 6309 is observed on build {build}, but items.toml has it"
        " removed from build 70338; un-remove it or reject the observation (DATA-R23)"
    )
    assert (message in output) == fails
    assert (tmp_path / CATALOGUE).exists() != fails


@pytest.mark.parametrize(
    ("facts", "problem"),
    [
        (fact("gate", 'item = 13759\nwindow = "event.14"\n'), "fact[0].window: 'event.14' isn't a window ID"),
        (fact("gate", 'item = 13759\nwindow = "day"\n'), "fact[0]: no catch entry gates item 13759 by 'day'"),
        (fact("window", 'window = "event.301"\n'), "fact[0].window: an event window takes its weekly rule's"),
        (fact("weekly", "event = 14\n"), "fact[0].event: event 14 has no weekly rule in data/forever/events.toml"),
        (fact("skillBase", "area = 297\n"), "fact[0].area: area 297 has no skill base (DATA-R55)"),
    ],
)
def test_a_dev_fact_that_can_confirm_nothing_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], facts: str, problem: str
) -> None:
    # DATA-R122: each fact asserts one catalogue fact; one naming a gate, window, weekly rule or skill base the
    # catalogue lacks would confirm nothing, so it fails (DATA-R63).
    code, output = run(write_tree(tmp_path, dev=DEV + facts), capsys)
    assert code == 1
    assert f"data/observed/dev.toml: {problem}" in output


def test_rows_in_an_area_missing_from_the_slice_neither_join_nor_confirm(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R33: an area missing from data/db2/areas.csv is left out of the catalogue, so its rows make no observed
    # pair and confirm nothing; the generator only warns.
    rows = {ALICE: report(i_row(6308, 99999), i_row(13760, 99999, extra=INSIDE_DAY))}
    text, output = generate(tmp_path, capsys, rows)
    assert "itemID = 6308" not in text
    assert "gateConfirmed = true" not in text
    assert "area 99999 seen in data/observed/ is not in data/db2/areas.csv" in output
