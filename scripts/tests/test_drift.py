"""Drift tooling (DATA-R114, docs/translations.md › Drift and the stale issue): the stale-string listing, the drop of the
strings whose {fields} changed, and the body of a Locale's "translations stale" issue, over fixture trees that are never
shipped. English moves from the fixtures' first state to a second, and the Spanish translations stay as they were."""

import json
from pathlib import Path

import pytest

from cli_fixture import run, run_split
from locale_fixture import CORE, SPANISH_CORE
from lore_locale_fixture import ES_LEDGER, LEDGER_LORE, read, write_tree
from pagle_data import drift
from pagle_data.drift import (
    BODY_LIMIT,
    FIELDS_CHANGED,
    SAME_FIELDS,
    Gaps,
    Sources,
    Stale,
    drop_stale,
    find_gaps,
    find_stale,
    issue_body,
    issue_json,
    issue_title,
    read_sources,
    stale_json,
    stale_text,
)
from pagle_data.errors import Problems
from pagle_data.locale import Header, read_locale
from pagle_data.toml_edit import EditError, drop_entries
from test_lore import LEDGER

GOLDEN = Path(__file__).parent / "fixtures" / "stale"
ES_CORE = "data/locale/esES/core.toml"
EN_CORE = "data/locale/enUS/core.toml"
EN_LEDGER = "data/lore/ledger.toml"

# English moves: GREETING is reworded and keeps {name}; FISH_COUNT.other gains a field; SEAL gains a line break; the
# Lore riddle is reworded and keeps its fields; the zonemaster title gains {fish}. TITLE, BANDS, CONTINENTS, WEIGHT and
# the other Lore fields are not touched, and COLOUR is new.
CORE_NOW = (
    CORE.replace('"Hello, {name}"', '"Hi, {name}"')
    .replace('"{count} fishes"', '"{count} fishes in {zone}"')
    .replace('SEAL = "%s\\nof %s"', 'SEAL = "%s\\nof\\n%s"')
    + 'COLOUR = "Colour"\n'
)
LEDGER_NOW = LEDGER.replace("Bites where the water runs lazy.", "Bites where the water runs slow.").replace(
    "Master of {zone}", "Master of {zone}, {fish}"
)

# The Spanish files with a comment on each entry, as a translator writes them, and every Spanish string in sync.
ES_CORE_COMMENTED = SPANISH_CORE.replace("[GREETING]", "# said at login\n[GREETING]").replace(
    "[FISH_COUNT]", "# counted; keep {count}\n[FISH_COUNT]"
)


def tree(root: Path, core: str = CORE_NOW, ledger: str = LEDGER_NOW, es_core: str = ES_CORE_COMMENTED) -> Path:
    """English as it is now over the Spanish translations of before."""
    write_tree(root, {"esES": {"ledger": ES_LEDGER}}, ledger=LEDGER)
    (root / EN_CORE).write_text(core, encoding="utf-8")
    (root / ES_CORE).write_text(es_core, encoding="utf-8")
    (root / EN_LEDGER).write_text(ledger, encoding="utf-8")
    return root


def listing(root: Path) -> list[Stale]:
    sources = read_sources(root)
    assert not sources.problems, sources.problems.found
    return find_stale(sources)


def by_key(stale: list[Stale]) -> dict[str, Stale]:
    return {f"{item.layer}:{item.key}": item for item in stale}


# --- the listing ------------------------------------------------------------------------------------------------------


def test_each_stale_string_is_one_of_two_kinds_and_a_fresh_one_is_not_listed(tmp_path: Path) -> None:
    found = by_key(listing(tree(tmp_path)))

    assert {key: item.kind for key, item in found.items()} == {
        "interface:GREETING": SAME_FIELDS,
        "interface:FISH_COUNT": FIELDS_CHANGED,
        "interface:SEAL": FIELDS_CHANGED,
        "lore:species.13759.riddle": SAME_FIELDS,
        "lore:title.zonemaster.text": FIELDS_CHANGED,
    }
    # TITLE, BANDS, CONTINENTS and WEIGHT are fresh; the rest of the Lore is too; COLOUR is a gap, not drift.


def test_a_listing_names_the_file_the_snapshot_and_todays_english(tmp_path: Path) -> None:
    found = by_key(listing(tree(tmp_path)))

    greeting = found["interface:GREETING"]
    assert (greeting.code, greeting.file, greeting.old, greeting.new) == ("esES", ES_CORE, "Hello, {name}", "Hi, {name}")
    counted = found["interface:FISH_COUNT"]
    assert counted.old == {"one": "{count} fish", "other": "{count} fishes"}
    assert counted.new == {"one": "{count} fish", "other": "{count} fishes in {zone}"}
    riddle = found["lore:species.13759.riddle"]
    assert (riddle.file, riddle.old, riddle.new) == (LEDGER_LORE, "Bites where the water runs lazy.", "Bites where the water runs slow.")
    assert riddle.parts == ("species", "13759", "riddle")


def test_a_change_that_leaves_the_fields_but_breaks_the_line_breaks_is_fields_changed(tmp_path: Path) -> None:
    """The gate would fail the Spanish SEAL on its newline check, so the drop has to take it, or an English change would
    wait for a translator."""
    seal = by_key(listing(tree(tmp_path)))["interface:SEAL"]

    assert (seal.kind, seal.reason) == (FIELDS_CHANGED, "newline")
    assert by_key(listing(tree(tmp_path)))["interface:FISH_COUNT"].reason == "fields"


def test_a_counted_string_whose_one_form_loses_its_field_is_fields_changed_though_the_union_is_the_same(tmp_path: Path) -> None:
    core = CORE.replace('FISH_COUNT.one = "{count} fish"', 'FISH_COUNT.one = "one fish"')
    found = by_key(listing(tree(tmp_path, core=core)))

    assert found["interface:FISH_COUNT"].kind == FIELDS_CHANGED  # the Spanish `one` still has {count}


def test_nothing_is_stale_while_every_snapshot_is_todays_english(tmp_path: Path) -> None:
    root = tree(tmp_path, core=CORE, ledger=LEDGER, es_core=SPANISH_CORE)

    assert listing(root) == []
    assert stale_text([], {}) == "no translation is stale: every EN snapshot is today's English (DATA-R114)\n"


def test_a_missing_en_is_a_problem_of_reading_not_a_stale_string(tmp_path: Path) -> None:
    root = tree(tmp_path, es_core='[GREETING]\nvalue = "Hola, {name}"\n')

    sources = read_sources(root)

    assert [problem for problem in sources.problems if "GREETING" in problem and "`value` and `en`" in problem]
    assert "GREETING" not in {item.key for item in find_stale(sources)}


def test_an_orphan_and_a_key_with_no_translation_are_not_drift(tmp_path: Path) -> None:
    root = tree(tmp_path, es_core='[GONE]\nvalue = "x"\nen = "y"\n' + SPANISH_CORE)

    assert "GONE" not in {item.key for item in listing(root)}


def test_hunt_text_beside_its_definition_is_drift_like_any_other_lore(tmp_path: Path) -> None:
    translations = {"esES": {"hunts": '[hunt.1.name]\nvalue = "Pesca"\nen = "Old Name"\n'}}
    layer, _ = read(tmp_path, translations, hunts={"hunt.1.name": "New Name"})
    locale = read_locale(tmp_path, Problems())

    found = find_stale(Sources(locale, layer, Problems()))

    assert [(item.key, item.kind, item.old, item.new) for item in found] == [("hunt.1.name", SAME_FIELDS, "Old Name", "New Name")]


def test_the_listing_is_deterministic_and_does_not_depend_on_the_order_of_the_files(tmp_path: Path) -> None:
    first = listing(tree(tmp_path / "a"))
    reordered = "\n\n".join(reversed(ES_CORE_COMMENTED.strip().split("\n\n"))) + "\n"
    second = listing(tree(tmp_path / "b", es_core=reordered))

    assert first == listing(tree(tmp_path / "c")) == second
    assert [(item.kind, item.layer, item.key) for item in first] == [
        (FIELDS_CHANGED, "interface", "FISH_COUNT"),
        (FIELDS_CHANGED, "interface", "SEAL"),
        (FIELDS_CHANGED, "lore", "title.zonemaster.text"),
        (SAME_FIELDS, "interface", "GREETING"),
        (SAME_FIELDS, "lore", "species.13759.riddle"),
    ]


def test_the_text_listing_groups_by_locale_and_kind(tmp_path: Path) -> None:
    root = tree(tmp_path)
    sources = read_sources(root)

    text = stale_text(find_stale(sources), sources.locale.headers)

    assert text.splitlines()[:5] == [
        "5 stale translation(s) in 1 Locale(s) (DATA-R114)",
        "",
        "esES (Español): 5 stale",
        "  fields changed (dropped by --drop-stale): 3",
        f"    {ES_CORE}: FISH_COUNT",
    ]
    assert "      was: Hello, {name}\n      now: Hi, {name}\n" in text
    assert f"    {ES_CORE}: SEAL (its line breaks)\n      was: %s\\nof %s\n      now: %s\\nof\\n%s\n" in text


def test_the_json_listing_has_every_locale_and_each_stale_string(tmp_path: Path) -> None:
    sources = read_sources(tree(tmp_path))

    data = json.loads(stale_json(find_stale(sources), sources.locale.headers))

    assert list(data) == ["locales"] and list(data["locales"]) == ["esES"]
    es = data["locales"]["esES"]
    assert (es["name"], es["listed"]) == ("Español", False)
    assert es["stale"][0] == {
        "layer": "interface",
        "file": ES_CORE,
        "key": "FISH_COUNT",
        "kind": "fields_changed",
        "reason": "fields",
        "old": {"one": "{count} fish", "other": "{count} fishes"},
        "new": {"one": "{count} fish", "other": "{count} fishes in {zone}"},
    }
    assert [item["kind"] for item in es["stale"]] == ["fields_changed"] * 3 + ["same_fields"] * 2
    assert stale_json([], {}) == '{\n  "locales": {}\n}\n'


# --- the command line: --stale ------------------------------------------------------------------------------------------


def snapshot(root: Path) -> dict[str, bytes]:
    return {str(path.relative_to(root)): path.read_bytes() for path in sorted(root.rglob("*")) if path.is_file()}


def test_stale_lists_and_exits_0_whatever_it_finds_and_writes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path)
    before = snapshot(root)

    code, out, err = run_split(root, capsys, "--stale")

    assert (code, err) == (0, "")
    assert out.startswith("5 stale translation(s) in 1 Locale(s)")
    assert snapshot(root) == before


def test_stale_json_is_machine_readable(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code, out, err = run_split(tree(tmp_path), capsys, "--stale", "--json")

    assert (code, err) == (0, "")
    assert len(json.loads(out)["locales"]["esES"]["stale"]) == 5


def test_stale_reads_a_tree_the_generator_would_fail(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path)

    assert run(root, capsys)[0] == 1  # the placeholder and newline checks
    assert run(root, capsys, "--stale")[0] == 0


def test_stale_fails_when_a_translation_cannot_be_read(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path, es_core='[GREETING]\nvalue = "Hola"\n')

    code, out = run(root, capsys, "--stale")

    assert code == 1 and "GREETING" in out and "wrote nothing" in out


def test_json_goes_with_stale_or_stale_issue_only(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit):
        run(tree(tmp_path), capsys, "--check", "--json")
    assert "--json goes with --stale or --stale-issue" in capsys.readouterr().err


def test_a_failed_run_says_to_drop_the_strings_whose_fields_changed(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code, out = run(tree(tmp_path), capsys, "--check")

    assert code == 1
    assert "placeholder: the {field} set differs from the English text's" in out
    assert "3 translation(s) are stale with changed {fields}" in out and "scripts/generate-data.py --drop-stale" in out


def test_a_failed_run_with_nothing_stale_does_not_mention_the_drop(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path, core=CORE, ledger=LEDGER, es_core=SPANISH_CORE.replace('value = "Pagle"', 'value = ""'))

    code, out = run(root, capsys, "--check")

    assert code == 1 and "--drop-stale" not in out


# --- the drop -----------------------------------------------------------------------------------------------------------


def dropped_tree(root: Path, capsys: pytest.CaptureFixture[str]) -> str:
    """The generator run on the Spanish translations in sync with English, English then moved, and --drop-stale run."""
    tree(root, core=CORE, ledger=LEDGER, es_core=ES_CORE_COMMENTED)
    assert run(root, capsys)[0] == 0
    tree(root, es_core=ES_CORE_COMMENTED)
    return run(root, capsys, "--drop-stale")[1]


def test_drop_stale_removes_exactly_the_strings_whose_fields_changed(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    out = dropped_tree(tmp_path, capsys)

    es_core = (tmp_path / ES_CORE).read_text(encoding="utf-8")
    assert "[FISH_COUNT]" not in es_core and "[SEAL]" not in es_core and "pez" not in es_core
    assert 'value = "Hola, {name}"' in es_core and 'en = "Hello, {name}"' in es_core  # same fields: kept, stale
    for kept in ("[TITLE]", "[BANDS]", "[CONTINENTS]", "[WEIGHT]"):
        assert kept in es_core
    lore = (tmp_path / LEDGER_LORE).read_text(encoding="utf-8")
    assert "[title.zonemaster.text]" not in lore and "Maestro" not in lore
    assert "[species.13759.riddle]" in lore and "[title.level1.text]" in lore
    assert "dropped FISH_COUNT from data/locale/esES/core.toml" in out
    assert "dropped title.zonemaster.text from data/lore/esES/ledger.toml" in out
    assert "dropped 3 translation(s) whose {fields} changed; 2 stale string(s) with the same {fields} keep showing" in out


def test_drop_stale_keeps_the_comments(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    dropped_tree(tmp_path, capsys)

    es_core = (tmp_path / ES_CORE).read_text(encoding="utf-8")
    assert "# said at login\n[GREETING]" in es_core  # the comment of a string that stays
    assert "# counted; keep {count}" in es_core  # the comment of a dropped one stays too, where it was


def test_after_a_drop_the_generator_passes_check_and_the_strings_fall_back_to_english(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    dropped_tree(tmp_path, capsys)

    code, out = run(tmp_path, capsys, "--check")

    assert code == 0, out
    assert "generated file(s) up to date" in out
    generated = (tmp_path / "addons/Pagle/locale/esES.lua").read_text(encoding="utf-8")
    assert "L.FISH_COUNT" not in generated and "L.SEAL" not in generated and "L.GREETING" in generated
    lore = (tmp_path / "addons/Pagle_Ledger/data/Lore.esES.lua").read_text(encoding="utf-8")
    assert "title.zonemaster.text" not in lore and "species.13759.riddle" in lore
    assert "warning:" in out and "drift:" in out  # the same-fields ones still warn


def test_a_second_drop_changes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    dropped_tree(tmp_path, capsys)
    before = snapshot(tmp_path)

    code, out = run(tmp_path, capsys, "--drop-stale")

    assert code == 0, out
    assert "dropped 0 translation(s)" in out and "wrote" not in out
    assert snapshot(tmp_path) == before


def test_drop_stale_with_nothing_stale_runs_the_generator_as_a_plain_run_does(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path, core=CORE, ledger=LEDGER, es_core=SPANISH_CORE)

    code, out = run(root, capsys, "--drop-stale")

    assert code == 0, out
    assert "dropped 0 translation(s)" in out
    assert (root / "addons/Pagle/locale/esES.lua").is_file()


def test_the_listing_after_a_drop_has_only_the_strings_that_keep_showing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    dropped_tree(tmp_path, capsys)

    assert [(item.key, item.kind) for item in listing(tmp_path)] == [
        ("GREETING", SAME_FIELDS),
        ("species.13759.riddle", SAME_FIELDS),
    ]


def test_a_drop_that_cannot_be_proved_safe_writes_no_file(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tree(tmp_path)
    before = snapshot(root)
    real = drop_entries

    def second_file_fails(text: str, depth: int, entries: list[tuple[str, ...]]) -> str:
        if depth == 3:
            raise EditError("the edit would change something beside the entries to remove")
        return real(text, depth, entries)

    monkeypatch.setattr(drift, "drop_entries", second_file_fails)

    code, out = run(root, capsys, "--drop-stale")

    assert code == 1
    assert f"{LEDGER_LORE}: the edit would change something beside the entries to remove; wrote nothing" in out
    assert snapshot(root) == before  # the Core file, edited first, was not written


def test_drop_stale_is_one_mode_with_the_others(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit):
        run(tree(tmp_path), capsys, "--drop-stale", "--check")


def test_drop_stale_function_returns_what_it_removed_and_only_that(tmp_path: Path) -> None:
    root = tree(tmp_path)

    removed = drop_stale(root, listing(root))

    assert sorted(item.key for item in removed) == ["FISH_COUNT", "SEAL", "title.zonemaster.text"]
    assert all(item.kind == FIELDS_CHANGED for item in removed)


# --- the issue ------------------------------------------------------------------------------------------------------------


def issue(root: Path, code: str = "esES") -> str:
    sources = read_sources(root)
    return issue_body(code, sources.locale.headers[code], find_stale(sources), find_gaps(sources, code))


def test_the_issue_body_is_the_golden_one(tmp_path: Path) -> None:
    assert issue(tree(tmp_path)) == (GOLDEN / "issue-esES.md").read_text(encoding="utf-8")


def test_the_issue_body_is_the_same_each_time_so_an_unchanged_issue_is_not_edited(tmp_path: Path) -> None:
    assert issue(tree(tmp_path / "a")) == issue(tree(tmp_path / "b"))


def test_the_gaps_count_the_fallback_chain_and_the_lore_files_the_locale_has(tmp_path: Path) -> None:
    root = tree(tmp_path)
    sources = read_sources(root)

    gaps = find_gaps(sources, "esES")

    assert gaps.interface == ["core.COLOUR", "hunts.HUNTS_ONLY"]
    assert gaps.interface_total == 9
    assert gaps.lore == {"ledger": (7, 11)}


def test_a_locale_that_falls_back_does_not_miss_what_its_fallback_has(tmp_path: Path) -> None:
    root = tree(tmp_path)
    (root / "data/locale/esMX").mkdir()
    (root / "data/locale/esMX/locale.toml").write_text('name = "Español (México)"\nlisted = false\nfallback = "esES"\ndecimal = "."\n', encoding="utf-8")
    (root / "data/locale/esMX/core.toml").write_text('[COLOUR]\nvalue = "Color"\nen = "Colour"\n', encoding="utf-8")

    gaps = find_gaps(read_sources(root), "esMX")

    assert gaps.interface == ["hunts.HUNTS_ONLY"]  # core.COLOUR is its own, the rest of Core is esES's


def test_the_issue_json_has_the_title_the_body_and_the_counts(tmp_path: Path) -> None:
    sources = read_sources(tree(tmp_path))

    data = json.loads(issue_json("esES", sources.locale.headers["esES"], find_stale(sources), find_gaps(sources, "esES")))

    assert data["title"] == issue_title("esES") == "Translations stale: esES"
    assert data["body"] == issue(tmp_path)
    assert {key: data[key] for key in ("listed", "fields_changed", "same_fields", "missing_interface", "missing_lore")} == {
        "listed": False,
        "fields_changed": 3,
        "same_fields": 2,
        "missing_interface": 2,
        "missing_lore": 7,
    }


def test_stale_issue_prints_the_body_and_nothing_else(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path)
    before = snapshot(root)

    code, out, err = run_split(root, capsys, "--stale-issue", "esES")

    assert (code, err) == (0, "")
    assert out == (GOLDEN / "issue-esES.md").read_text(encoding="utf-8")
    assert snapshot(root) == before
    assert json.loads(run_split(root, capsys, "--stale-issue", "esES", "--json")[1])["body"] == out


def test_stale_issue_for_a_locale_that_does_not_exist_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    for code in ("deDE", "enUS"):
        result, _, err = run_split(tree(tmp_path), capsys, "--stale-issue", code)
        assert result == 1 and f"no Locale {code}" in err


def test_a_locale_with_nothing_to_track_says_so(tmp_path: Path) -> None:
    root = tree(tmp_path, core=CORE, ledger=LEDGER, es_core=SPANISH_CORE)
    (root / "data/locale/esES/hunts.toml").write_text('[HUNTS_ONLY]\nvalue = "Cacerías"\nen = "Hunts"\n', encoding="utf-8")
    (root / LEDGER_LORE).write_text("", encoding="utf-8")
    (root / "data/lore/ledger.toml").write_text("", encoding="utf-8")

    body = issue(root)

    assert "Nothing is stale or missing now." in body
    assert "## " not in body


def header() -> Header:
    return Header("esES", "Español", (), True, None, None, None, None)


def test_a_listed_locale_is_called_listed_and_an_unlisted_one_not_yet() -> None:
    gaps = Gaps([], 0, {})

    assert "a listed language" in issue_body("esES", header(), [], gaps)
    assert "not listed yet" in issue_body("esES", Header("esES", "Español", (), False, None, None, None, None), [], gaps)


def many(count: int) -> list[Stale]:
    return [
        Stale("esES", "interface", ES_CORE, f"KEY_{index:05d}", (f"KEY_{index:05d}",), FIELDS_CHANGED, "fields", "x" * 100, "y" * 100)
        for index in range(count)
    ]


def test_a_body_too_long_for_an_issue_drops_the_english_beside_each_key_and_then_the_tail() -> None:
    gaps = Gaps([], 0, {})
    short = issue_body("esES", header(), many(40), gaps)
    assert "now `" in short  # with the English beside each key
    middle = issue_body("esES", header(), many(250), gaps)
    assert len(middle) <= BODY_LIMIT and "now `" not in middle and "KEY_00249" in middle
    long = issue_body("esES", header(), many(5000), gaps)
    assert len(long) <= BODY_LIMIT and "and 4700 more" in long


def test_a_backtick_in_the_english_does_not_end_the_code_span() -> None:
    item = Stale("esES", "interface", ES_CORE, "K", ("K",), SAME_FIELDS, None, "a `b` c", "a `d` c")

    body = issue_body("esES", header(), [item], Gaps([], 0, {}))

    assert "now `` a `d` c ``, was `` a `b` c ``" in body
