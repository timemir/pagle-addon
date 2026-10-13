"""The data/observed/ layer (DATA-R8 order 4) and its observations (DATA-R45, DATA-R46, DATA-R50, DATA-R34), over
hand-made fixture trees in the shapes of the Data section's data/observed/ table (#94: M2 builds and tests the Field
report row rules on fixture rows; M3 adds the importer that writes them)."""

from pathlib import Path

import pytest

from baseline_fixture import write_baseline
from item_fixture import write_item_layer
from observed_fixture import i_row, report, write_observed
from pagle_data.baseline import read_baseline
from pagle_data.cli import main
from pagle_data.errors import Problems
from pagle_data.generate import read_layers
from pagle_data.observed import Observations, observations, read_observed
from pagle_data.universe import item_universe
from windows_fixture import write_windows

DEV_KEY = "aaaaaaaa"
OTHER_KEY = "bbbbbbbb"


def observe(root: Path, dev: str, reports: dict[str, str], aliases: dict[int, int] | None = None) -> Observations:
    write_observed(root, dev, reports)
    problems = Problems()
    layer = read_observed(root, problems)
    assert problems.found == []
    return observations(layer, aliases or {})


def problems_of(root: Path, dev: str, reports: dict[str, str] | None = None) -> list[str]:
    write_observed(root, dev, reports)
    problems = Problems()
    read_observed(root, problems)
    return problems.found


def test_the_dev_s_keys_and_facts_are_one_reporter_and_every_other_key_its_own(tmp_path: Path) -> None:
    # DATA-R46: each observation's reporter is its report's reporter key, except that every key in dev.toml's keys,
    # and every dev fact, count as one reporter, dev. Two report files, dev.toml listing one: two reporters.
    found = observe(
        tmp_path,
        f'keys = ["{DEV_KEY}"]\n',
        {DEV_KEY: report(i_row(6303, 40)), OTHER_KEY: report(i_row(6303, 40), i_row(6358, 40))},
    )
    assert sorted(row.reporter for row in found.catches) == ["bbbbbbbb", "bbbbbbbb", "dev"]
    assert found.reporters() == {"dev", OTHER_KEY}


def test_a_row_below_a_raised_minimum_build_brings_its_item_but_doesn_t_count_for_confirming(tmp_path: Path) -> None:
    # DATA-R46: only observations on builds at or above the minimum confirming build count for confirming;
    # observations from every build bring items into the universe (DATA-R15). The minimum raised to 70339 (as
    # DATA-R57's --min-build would): the 70338 row of 99001 drops out, the 70339 row of 99002 stays.
    write_baseline(tmp_path)
    reports = {OTHER_KEY: report(i_row(99001, 40, build=70338), i_row(99002, 40, build=70339))}
    found = observe(tmp_path, "keys = []\n", reports)
    assert [row.item for row in found.confirming(70339).catches] == [99002]
    assert [row.item for row in found.confirming().catches] == [99001, 99002]  # Tunables: 0, every build counts
    problems = Problems()
    universe = item_universe(tmp_path, read_baseline(tmp_path, problems), problems)
    assert problems.found == []
    assert {99001, 99002} <= universe


def test_a_rejected_row_is_ignored(tmp_path: Path) -> None:
    # DATA-R50: a row with rejected = "<why>" is ignored by the generator, whatever its kind; DATA-R15: a rejected
    # I row brings no item into the universe. The P row observes nothing either way (DATA-R45) but is kept.
    rejected = 'rejected = "a client bug"\n'
    rows = report(
        i_row(6303, 40),
        i_row(99003, 40, extra=rejected),
        "[[k]]\narea = 40\nbuild = 70338\ncasts = 9\naway = 1\nland = 55\n",
        "[[k]]\narea = 40\nbuild = 70339\ncasts = 3\naway = 0\nland = 20\n" + rejected,
        '[[p]]\narea = 40\nlocale = "deDE"\ntext = "Schwarm"\ncasts = 2\nitems = { 6358 = 2 }\n',
    )
    write_observed(tmp_path, "keys = []\n", {OTHER_KEY: rows})
    problems = Problems()
    layer = read_observed(tmp_path, problems)
    assert problems.found == []
    found = observations(layer, {})
    assert [row.item for row in found.catches] == [6303]
    assert [row.build for row in found.skills] == [70338]
    assert found.items() == {6303}
    # Kept in the sources: the importer keeps the mark when it updates the row (DATA-R121).
    assert layer.reports is not None
    stored = layer.reports[OTHER_KEY]
    assert [row.rejected for row in stored.catches] == [None, "a client bug"]
    assert [(row.text, row.items) for row in stored.pool_texts] == [("Schwarm", ((6358, 2),))]


def test_the_rows_carry_rep_r20_to_r22_s_fields(tmp_path: Path) -> None:
    # REP-R20's example row `I 13755 331 70338 6 event=301 t=14:30 m=5`, and one with an aura; REP-R21's
    # `K 1519 70338 casts=40 away=6 land=75 lost=60`; dev facts of each kind (DATA-R122).
    rows = report(
        i_row(13755, 331, count=6, extra='event = [301]\nt = "14:30"\nm = 5\n'),
        i_row(6362, 33, count=2, extra="aura = [1280342, 1280341]\n"),
        "[[k]]\narea = 1519\nbuild = 70338\ncasts = 40\naway = 6\nland = 75\nlost = 60\n",
    )
    dev = (
        'keys = []\n\n[[fact]]\nkind = "pair"\nbuild = 70338\nnote = "caught it"\nitem = 6303\narea = 40\n\n'
        '[[fact]]\nkind = "gate"\nbuild = 70338\nnote = "only at night"\nitem = 13759\nwindow = "night"\n\n'
        '[[fact]]\nkind = "window"\nbuild = 70338\nnote = "x"\nwindow = "event.301"\n\n'
        '[[fact]]\nkind = "weekly"\nbuild = 70338\nnote = "x"\nevent = 301\n\n'
        '[[fact]]\nkind = "skillBase"\nbuild = 70338\nnote = "x"\narea = 1519\n'
    )
    found = observe(tmp_path, dev, {OTHER_KEY: rows})
    squid, yellowtail = found.catches
    assert (squid.item, squid.area, squid.build, squid.count) == (13755, 331, 70338, 6)
    assert (squid.events, squid.auras, squid.t, squid.m) == ((301,), (), 14 * 60 + 30, 5)
    assert (yellowtail.auras, yellowtail.t, yellowtail.m) == ((1280341, 1280342), None, None)
    (skill,) = found.skills
    assert (skill.area, skill.build, skill.casts, skill.away, skill.land, skill.lost) == (1519, 70338, 40, 6, 75, 60)
    assert [(f.kind, f.item, f.area, f.window, f.event) for f in found.facts] == [
        ("pair", 6303, 40, None, None),
        ("gate", 13759, None, "night", None),
        ("window", None, None, "event.301", None),
        ("weekly", None, None, None, 301),
        ("skillBase", None, 1519, None, None),
    ]
    # DATA-R46: every dev fact counts as the reporter dev; DATA-R15: pair and gate facts bring their items.
    assert {fact.reporter for fact in found.facts} == {"dev"}
    assert found.items() == {13755, 6362, 6303, 13759}


REPORT_FILE = f"data/observed/reports/{OTHER_KEY}.toml"
FACT = "keys = []\n[[fact]]\n"

ALIASES = '[[alias]]\nfrom = 16521\nto = 33\nwhy = "the map 2940 copy"\n'

# AreaTable rows for the generator tree: the fixture baseline's fishing areas 33 and 40, and 16521, aliased to 33.
AREAS = "ID,ParentAreaID,ContinentID,AreaName_lang\n33,0,0,Vale\n40,0,0,Fields\n16521,0,2940,Vale\n"


def write_tree(root: Path, dev: str = "keys = []\n", reports: dict[str, str] | None = None) -> Path:
    """A whole data/ tree, so the generator reads the observed layer with the others."""
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "events.toml").write_text("[event.301]\n", encoding="utf-8")
    (forever / "lists.toml").write_text("auras = [1280342]\nfishingSpells = [7620]\n", encoding="utf-8")
    (forever / "aliases.toml").write_text(ALIASES, encoding="utf-8")
    write_windows(root)  # test_windows.py covers windows
    write_baseline(root)
    db2 = root / "data" / "db2"
    db2.mkdir(parents=True, exist_ok=True)
    build = 'build = 70338\nversion = "1.60.1"\nproducts = ["wow_classic_beta"]\n'
    (db2 / "build.toml").write_text(build, encoding="utf-8")
    (db2 / "areas.csv").write_text(AREAS, encoding="utf-8")
    (db2 / "items.csv").write_text("ID,ClassID,SubclassID,OverallQualityID,Display_lang\n", encoding="utf-8")
    write_observed(root, dev, reports)
    write_item_layer(root)  # test_item_records.py covers the item layer
    return root


def run(root: Path, capsys: pytest.CaptureFixture[str], *args: str) -> tuple[int, str, str]:
    code = main(list(args), root)
    out, err = capsys.readouterr()
    return code, out, err


def test_an_observed_row_in_an_aliased_area_counts_for_its_target(tmp_path: Path) -> None:
    # DATA-R34: every area ID in data/observed/ goes through the alias table before it is used, so a row from
    # 16521 lands on 33; so do K rows and dev facts' areas.
    rows = report(i_row(6303, 16521), "[[k]]\narea = 16521\nbuild = 70338\ncasts = 4\naway = 0\n")
    dev = 'keys = []\n[[fact]]\nkind = "skillBase"\nbuild = 70338\nnote = "x"\narea = 16521\n'
    found = read_layers(write_tree(tmp_path, dev, {OTHER_KEY: rows})).observations()
    assert [row.area for row in found.catches] == [33]
    assert [row.area for row in found.skills] == [33]
    assert [fact.area for fact in found.facts] == [33]


def test_an_area_missing_from_the_slice_is_a_warning_and_stays_out_of_the_catalogue(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R33: an area seen in data/observed/ but missing from areas.csv is kept in the sources, left out of the
    # catalogue and printed as a warning, "update the DB2 slice"; DATA-R64: printed, not failing.
    write_tree(tmp_path, reports={OTHER_KEY: report(i_row(6303, 99999), i_row(6358, 99999), i_row(6303, 40))})
    code, out, err = run(tmp_path, capsys)
    assert code == 0, err
    assert (
        "generate-data: warning: area 99999 seen in data/observed/ is not in data/db2/areas.csv; update the DB2"
        f" slice ({REPORT_FILE}: i[0].area, {REPORT_FILE}: i[1].area)"
    ) in err.splitlines()
    assert "40 seen" not in err
    catalogue = (tmp_path / "addons/Pagle/data/Catalogue.lua").read_text(encoding="utf-8")
    assert "[99999]" not in catalogue
    assert "[40] = {" in catalogue
    # Kept in the sources: the row is still read and still an observation.
    assert [row.area for row in read_layers(tmp_path).observations().catches] == [99999, 99999, 40]


def test_a_bad_data_observed_file_fails_the_generator_naming_file_and_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R63: the generator fails, writing nothing and listing every problem, on an unknown key or a wrong type in
    # any TOML file under data/. A missing dev.toml is one: without it the dev's keys would count as separate
    # reporters (DATA-R46).
    bad_row = report(i_row(6303, 40, extra="zone = 1\n"))
    write_tree(tmp_path, dev="keys = []\nfact = 1\n", reports={OTHER_KEY: bad_row})
    code, _, err = run(tmp_path, capsys)
    assert code == 1
    assert "generate-data: data/observed/dev.toml: fact: expected an array of tables ([[fact]]), got an integer" in err
    assert f"generate-data: {REPORT_FILE}: i[0]: unknown key 'zone'" in err
    assert not (tmp_path / "addons").exists()
    (tmp_path / "data" / "observed" / "dev.toml").unlink()
    code, _, err = run(tmp_path, capsys)
    assert code == 1
    assert "generate-data: data/observed/dev.toml: missing" in err


def test_the_header_names_data_observed_as_the_fourth_layer(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R6: every generated file names the source layers; DATA-R8: data/observed/ is the fourth, after
    # data/baseline/, data/forever/ and data/db2/.
    code, _, err = run(write_tree(tmp_path), capsys)
    assert code == 0, err
    text = (tmp_path / "addons/Pagle/data/Catalogue.lua").read_text(encoding="utf-8")
    assert text.startswith(
        "-- Generated by scripts/generate-data.py from data/baseline/, data/forever/, data/db2/, data/observed/."
    )


@pytest.mark.parametrize(
    ("dev", "problem"),
    [
        ("keys = []\nfacts = []\n", "data/observed/dev.toml: unknown key 'facts'"),
        ("", "data/observed/dev.toml: missing key 'keys'"),
        ('keys = "aaaaaaaa"\n', "data/observed/dev.toml: keys: expected an array of reporter keys"),
        ('keys = ["F38E76B0"]\n', "data/observed/dev.toml: keys[0]: expected [0-9a-f]{8}, got 'F38E76B0'"),
        ('keys = ["aaaaaaaa", "aaaaaaaa"]\n', "data/observed/dev.toml: keys[1]: 'aaaaaaaa' is listed twice"),
        (FACT + 'kind = "pair"\nbuild = 1\nnote = "x"\nitem = 6303\n', "fact[0]: missing key 'area'"),
        (FACT + 'kind = "weekly"\nbuild = 1\nnote = "x"\nevent = 3\narea = 40\n', "fact[0]: unknown key 'area'"),
        (FACT + 'kind = "rumour"\nbuild = 1\nnote = "x"\n', "fact[0].kind: expected one of pair, gate, window"),
        (FACT + 'kind = "window"\nbuild = "1"\nnote = "x"\nwindow = "day"\n', "fact[0].build: expected an integer"),
        (FACT + 'kind = "window"\nbuild = 1\nnote = ""\nwindow = "day"\n', "fact[0].note: expected a non-empty"),
        (FACT + 'kind = "window"\nbuild = 1\nnote = "x"\nwindow = "dusk"\n', "fact[0].window: expected day|night|"),
    ],
)
def test_an_unknown_key_or_a_wrong_type_in_dev_toml_is_a_problem(tmp_path: Path, dev: str, problem: str) -> None:
    # DATA-R63: an unknown key or a wrong type in any TOML file under data/, naming the file and the key; dev.toml's
    # keys are DATA-R122's (a reporter key is REP-R36's 8 lowercase hex, a window ID DATA-R35's).
    found = problems_of(tmp_path, dev)
    problem = problem if problem.startswith("data/") else f"data/observed/dev.toml: {problem}"
    assert any(line.startswith(problem) for line in found), found


@pytest.mark.parametrize(
    ("rows", "problem"),
    [
        (report(i_row(6303, 40, extra="zone = 40\n")), "i[0]: unknown key 'zone'"),
        (report(i_row(6303, 40, extra='aura = "1280341"\n')), "i[0].aura: expected an array"),
        (report(i_row(6303, 40, extra='t = "14:20"\nm = 5\n')), "i[0].t: expected"),
        (report(i_row(6303, 40, extra='t = "14:30"\n')), "i[0]: t and m go together"),
        (report(i_row(6303, 40, extra='m = 13\nt = "14:30"\n')), "i[0].m: expected an integer from 1 to 12"),
        (report(i_row(6303, 40, extra="rejected = true\n")), "i[0].rejected: expected a string"),
        (report(i_row(6303, 40), i_row(6303, 40, count=3)), "i[1]: the same row key as i[0]"),
        (report("[[k]]\narea = 40\nbuild = 1\ncasts = 0\naway = 0\n"), "k[0].casts: expected an integer at least 1"),
        (report("[[k]]\narea = 40\nbuild = 1\ncasts = 2\n"), "k[0]: missing key 'away'"),
        (report('[[p]]\narea = 40\nlocale = "deDE"\ntext = "x"\ncasts = 1\nitems = { 6358 = "2" }\n'), "p[0].items"),
        (report(header='addon = "0.9.0"\ndata = "3f9a2c1e"\n'), "header: missing key 'locale'"),
        ("issues = [1]\nheader = {}\nnotes = 1\n", "unknown key 'notes'"),
        ("header = 3\n", "header: expected a table, got an integer"),
    ],
)
def test_an_unknown_key_or_a_wrong_type_in_a_report_file_is_a_problem(tmp_path: Path, rows: str, problem: str) -> None:
    # DATA-R63, naming the file and the key; the Data section's reports/<reporterKey>.toml (issues, header, then
    # [[i]], [[k]] and [[p]] rows with REP-R20–R22's fields and an optional rejected), one row per row key (DATA-R121).
    found = problems_of(tmp_path, "keys = []\n", {OTHER_KEY: rows})
    assert any(line.startswith(f"{REPORT_FILE}: {problem}") for line in found), found


def test_a_report_file_must_be_named_by_a_reporter_key(tmp_path: Path) -> None:
    # The Data section: reports/<reporterKey>.toml, the key 8 lowercase hex characters (REP-R36).
    found = problems_of(tmp_path, "keys = []\n", {"Bob": report()})
    assert found == [
        "data/observed/reports/Bob.toml: not a report file: expected <reporterKey>.toml, the key 8 lowercase hex"
        " (REP-R36)"
    ]
