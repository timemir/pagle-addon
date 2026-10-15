"""Catch lists, gates, skill bases and hasData (DATA-R26–R31) from data/forever/areas.toml (DATA-R10) and the
baseline, as the catalogue's area records (DATA-R78), over small fixture data/ trees."""

from pathlib import Path

import pytest

from areas_fixture import write_areas
from baseline_fixture import CSVS, write_baseline
from cli_fixture import run
from item_fixture import write_item_layer
from observed_fixture import NO_FACTS, write_observed
from hunts_fixture import write_hunts
from pools_fixture import write_pools
from windows_fixture import write_windows

CATALOGUE = "addons/Pagle/data/Catalogue.lua"

# An AreaTable slice (DATA-R11): Elwynn Forest (12) with Crystal Lake (18) and Thieves Camp (53), Durotar (14) with
# Echo Isles (368), Stranglethorn Vale (33) with Jaguero Isle (297); map 2940's copies of Elwynn Forest and Crystal
# Lake (16510, 16521), aliased; and Riverglades (16591), a Forever zone the baseline lacks (DATA-R31).
AREAS_CSV = """\
ID,ParentAreaID,ContinentID,AreaName_lang
12,0,0,Elwynn Forest
14,0,1,Durotar
18,12,0,Crystal Lake
33,0,0,Stranglethorn Vale
53,12,0,Thieves Camp
297,33,0,Jaguero Isle
368,14,1,Echo Isles
16510,0,2940,Elwynn Forest
16521,16510,2940,Crystal Lake
16591,0,2940,Riverglades
"""

ALIASES = """\
[[alias]]
from = 16510
to = 12
why = "the map 2940 copy"

[[alias]]
from = 16521
to = 18
why = "the map 2940 copy"
"""

# The baseline's area loot (DATA-R9). In 33, 13760's two rows are both event 47 (day), 13759's is 48 (night), and
# reference table 500 comes in under event 45 (summer); 6358 is Noise (items.toml). In 368, 13760 has one row with
# no event, so it is ungated. In 297, 6309 is removed and 6310 uncharted.
AREA_LOOT = """\
area,item,chance,ref,event,condition
12,6291,1.5,,,
18,6291,2.5,,,
33,6358,3.5,,,
33,13760,4.5,,47,
33,13760,5.5,,47,
33,13759,6.5,,48,
33,,7.5,500,45,
53,6303,8.5,,,
53,6308,9.5,,,
297,6303,10.5,,,
297,6309,11.5,,,
297,6310,12.5,,,
368,13759,13.5,,48,
368,13760,14.5,,,
368,13760,15.5,,47,
"""
# Table 500: 6303 is also direct loot elsewhere, so it isn't Noise; 6359 is reachable only through it, so it is
# Noise by rule (DATA-R16).
REFERENCE_LOOT = "ref,item,chance\n500,6303,16.5\n500,6359,17.5\n"
# A zone (33), a zone overridden in areas.toml (12), a subzone (297), and an area outside the slice (1).
SKILL = "area,skillBase\n1,-70\n12,-20\n14,-70\n33,130\n297,205\n"

ITEMS = """\
[item.6291]
category = "fish"

[item.6303]
category = "fish"

[item.6308]
category = "junk"

[item.6309]
category = "fish"
removed = true
removedFrom = 70338
why = "proven gone"

[item.6310]
category = "uncharted"
why = "not classified yet"

[item.6358]
noise = true
why = "oily"

[item.13759]
category = "fish"

[item.13760]
category = "fish"

[item.19803]
category = "fish"
legend = true

[item.19807]
category = "fish"
"""

# The v1 edits in small (DATA-R27, DATA-R28), and a skill base override (DATA-R30).
AREAS_TOML = """\
[[area]]
id = 53
clearBaseline = true
why = "VMaNGOS gives Thieves Camp another zone's table"

[[area]]
id = 12
skillBase = -25
why = "observed"

[[catch]]
area = 33
item = 19807
op = "add"
gate = "event.301"
why = "the Extravaganza"

[[catch]]
area = 33
item = 19803
op = "add"
gate = "event.301"
why = "the Extravaganza"
"""

# The catalogue's areas for the tree above, by hand from DATA-R26 (lists by area, never inherited, sorted, Noise,
# removed and uncharted items out), DATA-R29 (gates), DATA-R30 (zone skill bases; 297 has none of its own),
# DATA-R31 (hasData) and DATA-R78 (the record; a gate is its window's W entry, Contracts).
EXPECTED_AREAS = """\
\tareas = {
\t\t[12] = {
\t\t\tcatches = {
\t\t\t\t{ confirmed = false, itemID = 6291 },
\t\t\t},
\t\t\tcontinent = 0,
\t\t\thasData = true,
\t\t\tparent = 0,
\t\t\tskillBase = -25,
\t\t\tskillBaseConfirmed = false,
\t\t},
\t\t[14] = { catches = {}, continent = 1, hasData = true, parent = 0, skillBase = -70, skillBaseConfirmed = false },
\t\t[18] = {
\t\t\tcatches = {
\t\t\t\t{ confirmed = false, itemID = 6291 },
\t\t\t},
\t\t\tcontinent = 0,
\t\t\thasData = true,
\t\t\tparent = 12,
\t\t\tskillBaseConfirmed = false,
\t\t},
\t\t[33] = {
\t\t\tcatches = {
\t\t\t\t{ confirmed = false, gate = W.summer, gateConfirmed = false, itemID = 6303, window = "summer" },
\t\t\t\t{ confirmed = false, gate = W.night, gateConfirmed = false, itemID = 13759, window = "night" },
\t\t\t\t{ confirmed = false, gate = W.day, gateConfirmed = false, itemID = 13760, window = "day" },
\t\t\t\t{ confirmed = false, gate = W["event.301"], gateConfirmed = false, itemID = 19803, window = "event.301" },
\t\t\t\t{ confirmed = false, gate = W["event.301"], gateConfirmed = false, itemID = 19807, window = "event.301" },
\t\t\t},
\t\t\tcontinent = 0,
\t\t\thasData = true,
\t\t\tparent = 0,
\t\t\tskillBase = 130,
\t\t\tskillBaseConfirmed = false,
\t\t},
\t\t[53] = { catches = {}, continent = 0, hasData = true, parent = 12, skillBaseConfirmed = false },
\t\t[297] = {
\t\t\tcatches = {
\t\t\t\t{ confirmed = false, itemID = 6303 },
\t\t\t},
\t\t\tcontinent = 0,
\t\t\thasData = true,
\t\t\tparent = 33,
\t\t\tskillBaseConfirmed = false,
\t\t},
\t\t[368] = {
\t\t\tcatches = {
\t\t\t\t{ confirmed = false, gate = W.night, gateConfirmed = false, itemID = 13759, window = "night" },
\t\t\t\t{ confirmed = false, itemID = 13760 },
\t\t\t},
\t\t\tcontinent = 1,
\t\t\thasData = true,
\t\t\tparent = 14,
\t\t\tskillBaseConfirmed = false,
\t\t},
\t\t[16510] = { catches = {}, continent = 2940, hasData = false, parent = 0, skillBaseConfirmed = false },
\t\t[16521] = { catches = {}, continent = 2940, hasData = false, parent = 16510, skillBaseConfirmed = false },
\t\t[16591] = { catches = {}, continent = 2940, hasData = false, parent = 0, skillBaseConfirmed = false },
\t},
"""


def write_tree(
    root: Path,
    areas: str = AREAS_TOML,
    *,
    area_loot: str = AREA_LOOT,
    aliases: str = ALIASES,
    items: str = ITEMS,
    dev: str = NO_FACTS,
    reports: dict[str, str] | None = None,
) -> Path:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "events.toml").write_text(
        "[event.301]\nweekday = 1\nstart = 840\nduration = 120\n", encoding="utf-8"
    )
    (forever / "lists.toml").write_text("auras = []\nfishingSpells = [7620]\n", encoding="utf-8")
    (forever / "aliases.toml").write_text(aliases, encoding="utf-8")
    write_areas(root, areas)
    write_windows(root)  # test_windows.py covers windows
    write_pools(root)  # test_pools.py covers pool types
    write_hunts(root)  # test_hunts.py covers the Hunt list
    write_baseline(
        root, {**CSVS, "area_loot.csv": area_loot, "reference_loot.csv": REFERENCE_LOOT, "skill.csv": SKILL}
    )
    write_observed(root, dev, reports)  # test_observed.py covers the layer, test_confirmed.py what it implies
    write_item_layer(root, items)
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    (db2 / "build.toml").write_text('build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n', encoding="utf-8")
    (db2 / "areas.csv").write_text(AREAS_CSV, encoding="utf-8")
    (db2 / "items.csv").write_text("ID,ClassID,SubclassID,OverallQualityID,Display_lang\n", encoding="utf-8")
    return root


def generated(root: Path, capsys: pytest.CaptureFixture[str]) -> str:
    code, output = run(root, capsys)
    assert code == 0, output
    return (root / CATALOGUE).read_text(encoding="utf-8")


def test_each_area_ships_its_own_catch_list_skill_base_and_has_data(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R26: a list per area, never inherited, sorted by item ID, one entry per item; Noise (6358, and 6359
    # reachable only through a reference table), removed (6309) and uncharted (6310) items leave. DATA-R27: a
    # cleared area (53) has an empty list. DATA-R28: an add joins a pool-only catch. DATA-R29: gates from the
    # baseline's events and the adds. DATA-R30: zone skill bases from skill.csv, overridden by areas.toml; a
    # subzone has none of its own. DATA-R31: hasData. DATA-R78: the record's fields, every confirmed false.
    assert EXPECTED_AREAS in generated(write_tree(tmp_path), capsys)


def catch(area: int, item: int, op: str = "add", gate: str | None = None, why: str | None = "x") -> str:
    """A [[catch]] entry, after a blank line."""
    entry = f'\n[[catch]]\narea = {area}\nitem = {item}\nop = "{op}"\n'
    entry += f'gate = "{gate}"\n' if gate is not None else ""
    return entry + (f'why = "{why}"\n' if why is not None else "")


def area_record(text: str, area: int) -> str:
    """The area's record in Catalogue.lua's areas, from its key to the next area's."""
    start = text.index(f"\t\t[{area}] = {{")
    return text[start : text.index("\n\t\t[", start + 1)]


# In area 33, 13759 has a night row; this adds a day row for it there.
CONFLICTING = AREA_LOOT + "33,13759,18.5,,47,\n"


def test_an_item_whose_rows_in_an_area_map_to_two_windows_fails_naming_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R29: "if they map to different windows, the generator fails until an areas.toml add for that item sets
    # its gate"; DATA-R63 lists it, writing nothing.
    code, output = run(write_tree(tmp_path, area_loot=CONFLICTING), capsys)
    assert code == 1
    assert "data/baseline/area_loot.csv: item 13759 in area 33: its rows map to different windows (day, night)" in (
        output
    )
    assert not (tmp_path / CATALOGUE).exists()


def test_an_add_without_a_gate_leaves_the_conflict(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R29: only an add that sets the gate settles it.
    code, output = run(write_tree(tmp_path, AREAS_TOML + catch(33, 13759), area_loot=CONFLICTING), capsys)
    assert code == 1
    assert "item 13759 in area 33" in output


@pytest.mark.parametrize(
    ("gate", "entry"),
    [
        ("night", '{ confirmed = false, gate = W.night, gateConfirmed = false, itemID = 13759, window = "night" }'),
        ("none", "{ confirmed = false, itemID = 13759 }"),
    ],
)
def test_an_add_that_sets_the_gate_settles_the_conflict(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], gate: str, entry: str
) -> None:
    # DATA-R29: an add sets the gate of an item already listed, or removes it with gate = "none".
    text = generated(write_tree(tmp_path, AREAS_TOML + catch(33, 13759, gate=gate), area_loot=CONFLICTING), capsys)
    assert entry in area_record(text, 33)


def test_gate_none_removes_a_baseline_gate_and_an_add_without_one_keeps_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R26 step 2: an add of a listed item keeps it, setting its gate only when gate is given; DATA-R29:
    # gate = "none" removes one.
    text = generated(write_tree(tmp_path, AREAS_TOML + catch(368, 13759, gate="none") + catch(33, 13760)), capsys)
    assert "{ confirmed = false, itemID = 13759 }" in area_record(text, 368)
    assert '{ confirmed = false, gate = W.day, gateConfirmed = false, itemID = 13760, window = "day" }' in (
        area_record(text, 33)
    )


def test_a_drop_removes_the_item_from_that_area_only(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R26: op = "drop" removes it; each area's list is its own, never inherited.
    text = generated(write_tree(tmp_path, AREAS_TOML + catch(368, 13759, "drop")), capsys)
    assert "itemID = 13759" not in area_record(text, 368)
    assert "itemID = 13760" in area_record(text, 368)
    assert "itemID = 13759" in area_record(text, 33)


@pytest.mark.parametrize(
    ("edit", "problem"),
    [
        # DATA-R26: a drop takes no gate.
        (catch(33, 13759, "drop", gate="night"), "catch[2].gate: a drop takes no gate"),
        # DATA-R35: a gate naming an unknown window fails; an event without a weekly rule has none.
        (catch(33, 13759, gate="dusk"), "catch[2].gate: 'dusk' isn't a window ID (DATA-R35)"),
        (catch(33, 13759, gate="event.14"), "catch[2].gate: 'event.14' isn't a window ID (DATA-R35)"),
        # DATA-R10: a why on every entry of areas.toml.
        (catch(33, 13759, why=None), "catch[2]: missing key 'why'"),
        (catch(33, 13759, why=" "), "catch[2].why: empty"),
        ("\n[[area]]\nid = 368\nclearBaseline = true\n", "area[2]: missing key 'why'"),
        # The Data section's areas.toml keys and types (DATA-R63).
        (catch(33, 13759, "remove"), "catch[2].op: expected add or drop, got 'remove'"),
        ('\n[[catch]]\narea = 33\nitem = 13759\nop = "add"\nwhy = "x"\nnote = 1\n', "catch[2]: unknown key 'note'"),
        ('\n[[catch]]\narea = "33"\nitem = 13759\nop = "add"\nwhy = "x"\n', "catch[2].area: expected an integer"),
        ('\n[[catch]]\narea = 33\nop = "add"\nwhy = "x"\n', "catch[2]: missing key 'item'"),
        ('\n[[catch]]\narea = 33\nitem = 13759\nop = "add"\ngate = 1\nwhy = "x"\n', "catch[2].gate: expected a window"),
        ('\n[[area]]\nid = 368\nclearBaseline = 1\nwhy = "x"\n', "area[2].clearBaseline: expected a boolean"),
        ('\n[[area]]\nid = 368\nskillBase = "x"\nwhy = "x"\n', "area[2].skillBase: expected an integer"),
        ('\n[[area]]\nid = 368\nwhy = "x"\n', "area[2]: sets neither clearBaseline = true nor skillBase"),
        ('\n[[area]]\nid = 368\nmap = 1\nclearBaseline = true\nwhy = "x"\n', "area[2]: unknown key 'map'"),
        # Each area and each (area, item) once.
        ('\n[[area]]\nid = 53\nskillBase = 5\nwhy = "x"\n', "area[2].id: area 53 is listed twice"),
        (catch(33, 19807, "drop"), "catch[2]: item 19807 in area 33 is listed twice"),
        # DATA-R25: the catalogue's areas are areas.csv's rows, so an edit elsewhere would be lost.
        (catch(40, 13759), "catch[2].area: area 40 isn't in data/db2/areas.csv"),
        ('\n[[area]]\nid = 40\nclearBaseline = true\nwhy = "x"\n', "area[2].id: area 40 isn't in data/db2/areas.csv"),
    ],
)
def test_a_bad_areas_toml_entry_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], edit: str, problem: str
) -> None:
    # DATA-R63: the generator fails, writing nothing.
    code, output = run(write_tree(tmp_path, AREAS_TOML + edit), capsys)
    assert code == 1
    assert f"data/forever/areas.toml: {problem}" in output
    assert not (tmp_path / CATALOGUE).exists()


def test_an_unknown_top_level_key_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R63; the Data section: areas.toml holds [[area]] and [[catch]].
    code, output = run(write_tree(tmp_path, "note = 1\n" + AREAS_TOML), capsys)
    assert code == 1
    assert "data/forever/areas.toml: unknown key 'note'" in output


def test_a_missing_areas_toml_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R10: areas.toml is one of data/forever/'s files; without it the VMaNGOS fixes (DATA-R27) would be lost.
    write_tree(tmp_path)
    (tmp_path / "data" / "forever" / "areas.toml").unlink()
    code, output = run(tmp_path, capsys)
    assert code == 1
    assert "data/forever/areas.toml: missing" in output


def test_noise_removed_and_uncharted_items_never_join_a_list(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R26 step 4: removed (6309), Noise (6358 by items.toml, 6359 by rule) and uncharted (6310) items leave,
    # even when an add names them.
    edits = "".join(catch(18, item) for item in (6309, 6310, 6358, 6359))
    text = generated(write_tree(tmp_path, AREAS_TOML + edits), capsys)
    for item in (6309, 6310, 6358, 6359):
        assert f"itemID = {item}," not in text


def test_a_skill_base_set_in_areas_toml_ships_even_on_a_subzone(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R30: subzones have none of their own unless areas.toml sets one; values may be negative.
    text = generated(write_tree(tmp_path, AREAS_TOML + '\n[[area]]\nid = 297\nskillBase = -5\nwhy = "x"\n'), capsys)
    assert "\t\t\tskillBase = -5,\n" in area_record(text, 297)


def test_clearing_an_area_clears_its_conflicts(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R26 step 2: clearBaseline empties step 1, so its baseline gates no longer conflict (DATA-R29); adds
    # still join.
    edit = '\n[[area]]\nid = 33\nclearBaseline = true\nwhy = "x"\n'
    text = generated(write_tree(tmp_path, AREAS_TOML + edit, area_loot=CONFLICTING), capsys)
    assert "itemID = 13759" not in area_record(text, 33)
    assert "itemID = 19807" in area_record(text, 33)


def test_an_alias_target_that_lists_only_noise_has_no_catch_list(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R32: the alias checks read the catch lists (DATA-R26), so an area whose baseline rows are all Noise has
    # none. Here Crystal Lake's one row is 6358.
    loot = AREA_LOOT.replace("18,6291,2.5,,,", "18,6358,2.5,,,")
    code, output = run(write_tree(tmp_path, area_loot=loot), capsys)
    assert code == 1
    assert "data/forever/aliases.toml: alias[1].to: area 18 has no baseline catch list" in output


def test_an_alias_source_whose_rows_are_cleared_ships_without_data(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R32: a source whose baseline rows areas.toml clears has no catch list, so it may be aliased; DATA-R31:
    # it ships with hasData = false and no catches, though its zone has data.
    aliases = ALIASES + '\n[[alias]]\nfrom = 53\nto = 18\nwhy = "x"\n'
    text = generated(write_tree(tmp_path, aliases=aliases), capsys)
    assert "[53] = { catches = {}, continent = 0, hasData = false, parent = 12, skillBaseConfirmed = false }" in text


def test_a_row_with_a_condition_text_is_ungated_with_a_warning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R9: a row whose condition isn't a single event has no event; the generator treats it as ungated and
    # prints it as a warning (DATA-R64), so the dev decides its gate in areas.toml.
    loot = AREA_LOOT.replace("33,13759,6.5,,48,", '33,13759,6.5,,,"and(event(48), not(event(45)))"')
    code, output = run(write_tree(tmp_path, area_loot=loot), capsys)
    assert code == 0
    assert (
        "generate-data: warning: data/baseline/area_loot.csv: area 33 item 13759 has the condition"
        " and(event(48), not(event(45))), not a single event; it is treated as ungated"
    ) in output
    assert "{ confirmed = false, itemID = 13759 }" in area_record((tmp_path / CATALOGUE).read_text("utf-8"), 33)


def test_alias_proposals_read_the_catch_lists(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    # DATA-R32: a candidate is an area with no catch list matching a baseline fishing area. With both map 2940
    # aliases taken out, both copies are proposed; once Crystal Lake's one row is Noise and Elwynn's dropped,
    # neither is a fishing area and nothing is.
    code, output = run(write_tree(tmp_path, aliases=""), capsys, "--propose-aliases")
    assert code == 0
    assert "# 2 alias candidate(s)" in output
    loot = AREA_LOOT.replace("18,6291,2.5,,,", "18,6358,2.5,,,")
    code, output = run(write_tree(tmp_path, AREAS_TOML + catch(12, 6291, "drop"), area_loot=loot, aliases=""), capsys, "--propose-aliases")
    assert code == 0
    assert "# 0 alias candidate(s)" in output
