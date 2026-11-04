"""The converter that rewrites Pagle's English strings and their call sites to the text helper (CORE-R8, DATA-R114, #519):
one golden case per pattern on a small tree, the all-or-nothing rule, the worklist, and that a second run changes nothing."""

from pathlib import Path

import pytest

from pagle_data.locale import FILES
from pagle_data.lua_scan import prefix_start, split_args, tokenize
from pagle_data.text_convert import (
    Result,
    convert,
    directives,
    main,
    name_of,
    parse_strings,
    scan_file,
)

CORE_FILE = "addons/Pagle/logic/Say.lua"
MODULE_FILE = "addons/Pagle_Stats/logic/Say.lua"


def build(root: Path, strings: dict[str, str], lua: dict[str, str]) -> None:
    """A tree of six addons' English files (`strings` by addon, a placeholder for the rest) and Lua files by path."""
    (root / "data/locale/enUS").mkdir(parents=True)
    for file_id, addon in FILES.items():
        (root / f"data/locale/enUS/{file_id}.toml").write_text(strings.get(addon, 'PLACEHOLDER = "x"\n'), encoding="utf-8")
    for path, source in lua.items():
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source, encoding="utf-8")


def apply(root: Path, result: Result) -> None:
    for path, text in result.files.items():
        (root / path).write_text(text, encoding="utf-8")


def converted(tmp_path: Path, strings: dict[str, str], lua: dict[str, str]) -> tuple[Result, Path]:
    """Builds the tree, converts it, writes the result and returns it with the root."""
    build(tmp_path, strings, lua)
    result = convert(tmp_path)
    apply(tmp_path, result)
    return result, tmp_path


def assert_settled(root: Path) -> None:
    """A second run changes nothing and has nothing left for the worklist."""
    again = convert(root)
    assert again.files == {}
    assert again.worklist == []


# --- directives, names and the scanner ---------------------------------------------------------------------------------


def test_directives_read_the_supported_forms_and_flag_the_rest() -> None:
    found = directives("%s %d %i %.1f %02d %%  %5.2f %x % o")
    kinds = [(match.group(0), spec and (spec.kind, spec.places)) for match, spec in found]

    assert kinds == [
        ("%s", ("s", 0)),
        ("%d", ("d", 0)),
        ("%i", ("d", 0)),
        ("%.1f", ("f", 1)),
        ("%02d", ("pad", 0)),
        ("%5.2f", None),
        ("%x", None),
        ("% o", None),
    ]


@pytest.mark.parametrize(
    ("expression", "name"),
    [
        ("fish", "fish"),
        ("card.coins", "coins"),
        ("self.state.zone", "zone"),
        ("#list.rows", "rows"),
        ("tostring(owner)", "owner"),
        ("ns.Number(card.total)", "total"),
        ("table.concat(parts, ', ')", "parts"),
        ("presence.reason or '?'", "reason"),
        ("counts[rarity.key]", "counts"),
        ("ns.FormatDuration(a - b)", "duration"),
        ("GetBindingText(pending.key)", "bindingText"),
        ("RULER_AFTER", "rulerAfter"),
        ("minutes % 60", None),
        ("math.floor(minutes / 60)", None),
        ("n", None),
        ('"QoL"', None),
        ("12", None),
    ],
)
def test_a_field_is_named_after_its_argument_where_that_says_something(expression: str, name: str | None) -> None:
    assert name_of(expression) == name


def test_the_tokenizer_skips_comments_and_keeps_strings_whole() -> None:
    source = 'local s = "a -- b" --[[ L.X:format(1) ]] -- L.Y:format(2)\nlocal t = [[long ]] .. s'

    texts = [tok.text for tok in tokenize(source)]

    assert texts == ["local", "s", "=", '"a -- b"', "local", "t", "=", "[[long ]]", "..", "s"]


def test_a_prefix_expression_and_its_arguments_are_found_by_brackets() -> None:
    source = "x = f(a.b[c](d)):format(g(1, 2), {3, 4}, h)"
    toks = tokenize(source)
    colon = next(i for i, tok in enumerate(toks) if tok.text == ":")

    start = prefix_start(toks, colon - 1)
    arguments = split_args(toks, colon + 2, len(toks) - 1)

    assert source[toks[start].start : toks[colon - 1].end] == "f(a.b[c](d))"
    assert [source[toks[a].start : toks[b - 1].end] for a, b in arguments] == ["g(1, 2)", "{3, 4}", "h"]


def test_scanning_finds_each_pattern_and_leaves_other_formats_alone() -> None:
    source = (
        "local L = ns.L\n"
        "a = L.A:format(x)\n"
        "b = ns.L.B[k]:format(x, y)\n"
        "c = string.format(L.C, x)\n"
        '        d = ns.Fill(L.D, { n = 1 }) .. ns.Plural(n, "E", { z = 1 })\n'
        'e = ("%d"):format(n) .. string.format("%04x", n) .. s:format(n)\n'
        "f = (n == 1 and L.F_ONE or L.F_OTHER):format(n)\n"
        "g = ns.CountText(n, L.G_ONE, L.G_OTHER, format) .. ns.CountText(n, 'H')\n"
    )

    scan = scan_file("addons/Pagle/logic/X.lua", "Pagle", source)

    found = [(site.kind, site.keys, site.args or site.count) for site in scan.sites]
    assert found == [
        ("pair", ("F",), ["n"]),
        ("format", ("A",), ["x"]),
        ("format", ("B",), ["x", "y"]),
        ("format", ("C",), ["x"]),
        ("fill", (), None),
        ("plural", ("E",), "n"),
        ("pair", ("G",), "n"),
        ("pair", ("H",), "n"),
    ]
    assert [receiver for _, receiver in scan.unplaced] == ["s"]


# --- the strings and the call sites ------------------------------------------------------------------------------------


def test_directives_become_named_fields_and_the_call_passes_them(tmp_path: Path) -> None:
    core = (
        "# The Core's text.\n"
        "\n"
        "# A catch: fish, how many, the rate.\n"
        'SAY = "%s caught %d at %.1f%% of 100%%"\n'
        'PLAIN = "Nothing to fill"\n'
    )
    lua = (
        "local ns = select(2, ...)\n"
        "local L = ns.L\n"
        "function ns.Say(fish, tally, rate)\n"
        "\treturn L.SAY:format(fish, tally.total, rate), string.format(ns.L.SAY, fish, tally.total, rate)\n"
        "end\n"
    )

    result, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8") == (
        "# The Core's text.\n"
        "\n"
        "# A catch: fish, how many, the rate.\n"
        'SAY = "{fish} caught {total:0} at {rate:1}% of 100%"\n'
        'PLAIN = "Nothing to fill"\n'
    )
    assert (root / CORE_FILE).read_text(encoding="utf-8") == (
        "local ns = select(2, ...)\n"
        "local L = ns.L\n"
        "function ns.Say(fish, tally, rate)\n"
        "\treturn ns.RenderText(L.SAY, { fish = fish, total = tally.total, rate = rate }),"
        " ns.RenderText(ns.L.SAY, { fish = fish, total = tally.total, rate = rate })\n"
        "end\n"
    )
    assert result.worklist == []
    assert_settled(root)


def test_a_module_calls_its_own_wrapper_of_pagle_text(tmp_path: Path) -> None:
    stats = 'HI = "Hi %s"\n'
    lua = "local ns = select(2, ...)\nreturn ns.L.HI:format(name)\n"

    _, root = converted(tmp_path, {"Pagle_Stats": stats}, {MODULE_FILE: lua})

    assert (root / MODULE_FILE).read_text(encoding="utf-8") == (
        "local ns = select(2, ...)\nreturn ns.Text(ns.L.HI, { name = name })\n"
    )


def test_a_template_used_in_two_places_gets_one_set_of_names(tmp_path: Path) -> None:
    core = 'TOLD = "%s saw %s"\n'
    lua = (
        "local ns = select(2, ...)\nlocal L = ns.L\n"
        "a = L.TOLD:format(angler, species)\n"
        "b = L.TOLD:format(angler, species.name)\n"
        "c = L.TOLD:format(who, fish())\n"
    )

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert 'TOLD = "{angler} saw {species}"' in (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8")
    assert (root / CORE_FILE).read_text(encoding="utf-8").splitlines()[2:] == [
        "a = ns.RenderText(L.TOLD, { angler = angler, species = species })",
        "b = ns.RenderText(L.TOLD, { angler = angler, species = species.name })",
        "c = ns.RenderText(L.TOLD, { angler = who, species = fish() })",
    ]
    assert_settled(root)


def test_a_zero_padded_number_is_written_at_the_call(tmp_path: Path) -> None:
    core = 'CLOCK = "%d:%02d"\nSTOPWATCH = "%02d"\n'
    lua = "local ns = select(2, ...)\nreturn ns.L.CLOCK:format(hour, minute), ns.L.STOPWATCH:format(seconds)\n"

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8") == (
        'CLOCK = "{hour:0}:{minute}"\nSTOPWATCH = "{seconds}"\n'
    )
    assert (root / CORE_FILE).read_text(encoding="utf-8") == (
        "local ns = select(2, ...)\n"
        'return ns.RenderText(ns.L.CLOCK, { hour = hour, minute = ("%02d"):format(minute) }),'
        ' ns.RenderText(ns.L.STOPWATCH, { seconds = ("%02d"):format(seconds) })\n'
    )


def test_an_identifier_is_written_as_it_is_and_a_quantity_is_grouped(tmp_path: Path) -> None:
    core = 'ITEM = "Item %d"\nTOTAL = "%d Catches"\n'
    lua = "local ns = select(2, ...)\nreturn ns.L.ITEM:format(itemID), ns.L.TOTAL:format(caught)\n"

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8") == (
        'ITEM = "Item {itemID}"\nTOTAL = "{caught:0} Catches"\n'
    )


def test_a_pair_of_one_and_other_keys_becomes_one_counted_string(tmp_path: Path) -> None:
    core = (
        "# Catches.\n"
        'CATCHES_ONE = "%s Catch"\n'
        'CATCHES_OTHER = "%s Catches"\n'
        'PITY = "A Curio within %d more crates"\n'
        'PITY_ONE = "A Curio in the next crate"\n'
        'LONG_ONE = "One thing"\n'
        'LONG_OTHER = "Things"\n'
    )
    lua = (
        "local ns = select(2, ...)\nlocal L = ns.L\n"
        "a = (n == 1 and L.CATCHES_ONE or L.CATCHES_OTHER):format(ns.Number(n))\n"
        "b = left == 1 and L.PITY_ONE or L.PITY:format(left)\n"
        "c = #stops == 1 and L.LONG_ONE or L.LONG_OTHER\n"
    )

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8") == (
        "# Catches.\n"
        'CATCHES.one = "{count:n} Catch"\n'
        'CATCHES.other = "{count:n} Catches"\n'
        'PITY.one = "A Curio in the next crate"\n'
        'PITY.other = "A Curio within {count:0} more crates"\n'
        'LONG.one = "One thing"\n'
        'LONG.other = "Things"\n'
    )
    assert (root / CORE_FILE).read_text(encoding="utf-8").splitlines()[2:] == [
        "a = ns.RenderText(L.CATCHES, { count = n })",
        "b = ns.RenderText(L.PITY, { count = left })",
        "c = ns.RenderText(L.LONG, { count = #stops })",
    ]
    assert_settled(root)


def test_a_count_helper_call_becomes_the_counted_string(tmp_path: Path) -> None:
    hunts = 'SETTLED_ONE = "%s wager settled"\nSETTLED_OTHER = "%s wagers settled"\n'
    ledger = 'FRESH_ONE = " Fresh Water for %d more Catch."\nFRESH_OTHER = " Fresh Water for %d more Catches."\n'
    lua = {
        "addons/Pagle_Hunts/logic/Say.lua": 'local ns = select(2, ...)\nreturn ns.CountText(n, "SETTLED", format)\n',
        "addons/Pagle_Ledger/logic/Say.lua": (
            "local ns = select(2, ...)\nlocal L = ns.L\nreturn ns.CountText(fresh, L.FRESH_ONE, L.FRESH_OTHER)\n"
        ),
    }

    _, root = converted(tmp_path, {"Pagle_Hunts": hunts, "Pagle_Ledger": ledger}, lua)

    assert 'SETTLED.other = "{count:n} wagers settled"' in (root / "data/locale/enUS/hunts.toml").read_text(encoding="utf-8")
    assert 'FRESH.other = " Fresh Water for {count:0} more Catches."' in (
        root / "data/locale/enUS/ledger.toml"
    ).read_text(encoding="utf-8")
    assert (root / "addons/Pagle_Hunts/logic/Say.lua").read_text(encoding="utf-8").endswith(
        "return ns.Text(ns.L.SETTLED, { count = n })\n"
    )
    assert (root / "addons/Pagle_Ledger/logic/Say.lua").read_text(encoding="utf-8").endswith(
        "return ns.Text(L.FRESH, { count = fresh })\n"
    )
    assert_settled(root)


def test_fill_and_plural_move_to_the_helper_and_their_definitions_go(tmp_path: Path) -> None:
    board = (
        'FILLED = "{who} waves"\n'
        'COUNTED.one = "{n} Catch in {zone}"\n'
        'COUNTED.other = "{n} Catches in {zone}"\n'
        'DAYS = "{n} days"\n'
    )
    lua = (
        "local ns = select(2, ...)\n"
        "\n"
        "--- Fills a template.\n"
        "function ns.Fill(template, fields)\n"
        "\treturn template\n"
        "end\n"
        "\n"
        "local function pick(forms, n)\n"
        "\treturn forms\n"
        "end\n"
        "\n"
        "--- A count in words.\n"
        "function ns.Plural(n, key, fields)\n"
        "\treturn ns.Fill(pick(ns.L[key], n), fields)\n"
        "end\n"
        "\n"
        "function ns.Use(n, who)\n"
        '\treturn ns.Fill(ns.L.FILLED, { who = who }), ns.Plural(n, "COUNTED", { zone = "Feralas" }), ns.Plural(n, "DAYS")\n'
        "end\n"
    )

    result, root = converted(tmp_path, {"Pagle_TackleBoard": board}, {"addons/Pagle_TackleBoard/logic/Words.lua": lua})

    assert (root / "data/locale/enUS/tackleboard.toml").read_text(encoding="utf-8") == (
        'FILLED = "{who} waves"\n'
        'COUNTED.one = "{count} Catch in {zone}"\n'
        'COUNTED.other = "{count} Catches in {zone}"\n'
        'DAYS = "{count} days"\n'
    )
    assert (root / "addons/Pagle_TackleBoard/logic/Words.lua").read_text(encoding="utf-8") == (
        "local ns = select(2, ...)\n"
        "\n"
        "function ns.Use(n, who)\n"
        "\treturn ns.Text(ns.L.FILLED, { who = who }),"
        ' ns.Text(ns.L.COUNTED, { count = n, zone = "Feralas" }), ns.Text(ns.L.DAYS, { count = n })\n'
        "end\n"
    )
    assert result.worklist == []
    assert_settled(root)


def test_a_call_inside_the_arguments_of_another_is_converted_too(tmp_path: Path) -> None:
    core = 'LINE = "%s of %s"\nSIZE = "%d KB"\n'
    lua = "local ns = select(2, ...)\nlocal L = ns.L\nreturn L.LINE:format(entries, L.SIZE:format(math.ceil(length / 1024)))\n"

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / CORE_FILE).read_text(encoding="utf-8").splitlines()[2] == (
        "return ns.RenderText(L.LINE, { entries = entries, line_2 = ns.RenderText(L.SIZE,"
        " { size = math.ceil(length / 1024) }) })"
    )
    assert_settled(root)


def test_a_string_that_is_not_an_l_value_is_left_alone(tmp_path: Path) -> None:
    core = 'SAY = "%s"\n'
    lua = (
        "local ns = select(2, ...)\n"
        'local id = ("%d items"):format(n) .. string.format("%04x", n) .. ("%s_%s"):format(a, b)\n'
        "local red = RED:format(text) .. other.L.SAY:format(x)\n"
        "return ns.L.SAY:format(id)\n"
    )

    result, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / CORE_FILE).read_text(encoding="utf-8").splitlines()[1:3] == lua.splitlines()[1:3]
    assert [receiver for _, receiver in scan_file(CORE_FILE, "Pagle", lua).unplaced] == ["RED", "other.L.SAY"]
    assert result.worklist == []


def test_a_string_used_outside_a_format_call_stays_whole_and_goes_to_the_worklist(tmp_path: Path) -> None:
    core = 'SAY = "%s now"\nOTHER = "%d left"\n'
    lua = "local ns = select(2, ...)\nlocal L = ns.L\nhelper(L.SAY)\nreturn L.SAY:format(lines), L.OTHER:format(items)\n"

    result, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    text = (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8")
    assert 'SAY = "%s now"' in text
    assert 'OTHER = "{items:0} left"' in text
    assert any("SAY is read where the script cannot rewrite it" in line for line in result.worklist)


def test_a_call_that_gives_too_few_arguments_is_not_guessed(tmp_path: Path) -> None:
    core = 'TWO = "%s and %s"\n'
    lua = "local ns = select(2, ...)\nreturn ns.L.TWO:format(pair())\n"

    result, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert 'TWO = "%s and %s"' in (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8")
    assert any("has 2 directive(s) and the call gives 1" in line for line in result.worklist)
    assert (root / CORE_FILE).read_text(encoding="utf-8") == lua


def test_a_string_with_a_directive_the_helper_cannot_write_goes_to_the_worklist(tmp_path: Path) -> None:
    core = 'HEX = "%x"\n'
    lua = "local ns = select(2, ...)\nreturn ns.L.HEX:format(n)\n"

    result, _ = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert any("a directive the helper cannot write" in line for line in result.worklist)


def test_a_dynamic_key_is_reported_and_its_template_kept(tmp_path: Path) -> None:
    core = 'FIRST = "%s"\n'
    lua = 'local ns = select(2, ...)\nreturn ns.L[key]:format(x)\n'

    result, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / CORE_FILE).read_text(encoding="utf-8") == lua
    assert any("FIRST: has directives and no call that formats it" in line for line in result.worklist)


def test_a_header_that_says_the_strings_were_as_they_were_is_brought_up_to_date(tmp_path: Path) -> None:
    core = (
        "# Core's interface text.\n"
        "#\n"
        "# Converted from the hand-written enUS.lua by scripts/convert-enus-locale.py: the strings are as they were,\n"
        "# `%s`, `_ONE`/`_OTHER` pairs and all. A key is `KEY = \"text\"`; an array is `KEY = [...]`; a table is dotted keys\n"
        "# (`KEY.sub = \"text\"`), a whole-number key being the Lua integer key (`CONTINENT_NAMES.0`), and a table of plural\n"
        "# categories is a counted string. The shape is in DATA-R114 (docs/spec/content-data.md).\n"
        "\n"
        'SAY = "%s"\n'
    )
    lua = "local ns = select(2, ...)\nreturn ns.L.SAY:format(value)\n"

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    text = (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8")
    assert "then rewritten to the text helper's" in text
    assert "the strings are as they were" not in text
    assert text.endswith('SAY = "{value}"\n')
    assert_settled(root)


def test_multi_line_arrays_and_nested_tables_are_kept(tmp_path: Path) -> None:
    core = (
        'NAMES = ["A", "B"]\n'
        "WIDE = [\n"
        '\t"one",\n'
        '\t"two",\n'
        "]\n"
        'KINDS.haul = "Haul"\n'
        'KINDS."a.b" = "AB"\n'
        'SAY = "%s"\n'
    )
    lua = "local ns = select(2, ...)\nreturn ns.L.SAY:format(value)\n"

    _, root = converted(tmp_path, {"Pagle": core}, {CORE_FILE: lua})

    assert (root / "data/locale/enUS/core.toml").read_text(encoding="utf-8") == core.replace('"%s"', '"{value}"')


def test_parsing_and_rendering_a_file_gives_it_back_byte_for_byte() -> None:
    text = '# head\n\n# note\nA = "x"\nB.one = "y"\nB.other = "z"\n\n# tail\n'

    assert parse_strings(text).render() == text


def test_the_command_reports_the_worklist_and_writes_nothing_on_a_dry_run(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    build(tmp_path, {"Pagle": 'SAY = "%s"\nSTUCK = "%s"\n'}, {CORE_FILE: "local ns = select(2, ...)\nreturn ns.L.SAY:format(value)\n"})

    code = main(["--dry-run", "--report"], tmp_path)

    out = capsys.readouterr().out
    assert code == 1
    assert "Pagle SAY: value" in out
    assert "STUCK: has directives and no call that formats it" in out
    assert (tmp_path / CORE_FILE).read_text(encoding="utf-8").endswith("ns.L.SAY:format(value)\n")
