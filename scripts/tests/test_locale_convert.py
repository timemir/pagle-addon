"""The one-time conversion of the hand-written enUS.lua files to TOML (DATA-R114, #517): the text it scans, the TOML
it writes, and the whole run on a small tree of six addons, proved by loading the old and the generated Lua and comparing
the `ns.L` each builds."""

import subprocess
import tomllib
from pathlib import Path

import pytest

from cli_fixture import run
from pagle_data.locale import ADDON_IDS, FILES
from pagle_data.locale_convert import (
    ConvertError,
    Json,
    convert,
    entry_lines,
    evaluate,
    main,
    scan,
    toml_string,
)
from test_item_records import write_tree as write_items
from test_lore import FAMILIES, ITEMS, OFF

REPO = Path(__file__).resolve().parents[2]
LUA = REPO / ".tools" / "bin" / "lua"

GUARD = (
    "if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)\n"
    "\treturn\n"
    "end\n\n"
)

# A hand-written enUS.lua in miniature: locals, a helper function, concatenations, a `:rep` call, comments above keys
# and after one, a blank line between groups, a long string joined across lines, and every shape of value.
BODY = r'''-- The Mini's string table (CORE-R8). Every string goes through ns.L.
-- It has two comment lines.

---@class MiniNS
local ns = select(2, ...)

local STAR = "|TInterface\\AddOns\\Mini\\star:0|t"
local function sprite(n)
	return "|TInterface\\AddOns\\Mini\\parts:" .. n .. "|t"
end
local WORD = "Caught"

---@class MiniStrings
ns.L = {
	-- A title (MIN-R1).
	TITLE = "Mini", -- the trailing note
	SAY = "He said \"hi\" -- {not a comment or a brace} 'quoted'",
	STAR_LINE = "%s: " .. STAR:rep(2),
	CAUGHT = "%s " .. WORD .. " " .. sprite(7),
	LONG = "one "
		.. "two",

	-- Counted strings (MIN-R2).
	-- Two lines of it.
	COUNT = { one = "{n} fish", other = "{n} fishes" },
	NAMES = { "A", "B" },
	PAIRS = { { "a", "b" }, { "c", "d" } },
	NOTES = {
		-- inside a table
		{ text = "x" },
		{ text = "y" },
	},
	CONT = { [0] = "East", [1] = "West" },
	RARE = { [2] = "an uncommon", [3] = "a rare" },
	TIERS = { "Plain", "Fine", curio = "Curio" },
	SLOTS = { ["core.binding"] = "Binding", ["12h"] = "12-hour" },
	DEEP = { a = { b = { one = "{n} x", other = "{n} xs" }, c = "see" } },
	SEAL = "%s\nof %s",
	EMPTY = "",
	TAB = "a\tb",
	LONGER = { "a long first element for the array to run over the line width of a hundred and twenty", "and a second one", "and a third" },
}
'''


def mini(addon: str) -> str:
    """BODY for an addon: a Module starts with the CORE-R11 guard, Core does not, and the class names differ."""
    guard = "" if addon == "Pagle" else GUARD
    return guard + BODY.replace("Mini", addon)


def tree(root: Path) -> Path:
    """A valid data/ tree with six addons' hand-written enUS.lua in it."""
    write_items(root, ITEMS, families=FAMILIES, checks=OFF)
    for addon in ADDON_IDS:
        path = root / "addons" / addon / "locale" / "enUS.lua"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(mini(addon), encoding="utf-8")
    return root


# A Lua script that loads two files into fresh namespaces and fails unless their ns.L are deeply equal.
COMPARE = r"""
local function build(path)
	Pagle = {}
	local ns = {}
	assert(loadfile(path))("addon", ns)
	return ns.L
end
local function same(a, b, where)
	if type(a) ~= type(b) then error(where .. ": " .. type(a) .. " is not " .. type(b)) end
	if type(a) ~= "table" then
		if a ~= b then error(where .. ": " .. tostring(a) .. " is not " .. tostring(b)) end
		return
	end
	for k, v in pairs(a) do same(v, b[k], where .. "." .. tostring(k)) end
	for k in pairs(b) do if a[k] == nil then error(where .. ": extra key " .. tostring(k)) end end
end
same(build(arg[1]), build(arg[2]), "ns.L")
print("same")
"""


def lua_equal(before: Path, after: Path) -> None:
    if not LUA.exists():
        pytest.skip("no .tools/bin/lua")
    done = subprocess.run(
        [str(LUA), "-", str(before), str(after)], input=COMPARE, capture_output=True, text=True, check=False
    )
    assert done.returncode == 0 and done.stdout.strip() == "same", done.stderr


# --- scanning ---------------------------------------------------------------------------------------------------------


def test_scan_reads_the_header_the_keys_in_order_and_the_comments_above_each() -> None:
    found = scan(mini("Pagle_Hunts"))
    assert found.header == [" The Pagle_Hunts's string table (CORE-R8). Every string goes through ns.L.", " It has two comment lines."]
    assert found.keys[:4] == ["TITLE", "SAY", "STAR_LINE", "CAUGHT"]
    assert found.keys[-1] == "LONGER"
    assert found.comments["TITLE"] == [" A title (MIN-R1).", " the trailing note"]
    assert found.comments["COUNT"] == [" Counted strings (MIN-R2).", " Two lines of it."]
    assert found.comments["NOTES"] == [" inside a table"]
    assert found.comments["SAY"] == []  # a `--` or a brace inside a string is no comment and no structure
    assert found.blank_before == {"COUNT"}


def test_scan_follows_the_core_file_with_no_guard() -> None:
    assert scan(mini("Pagle")).header[0].startswith(" The Pagle's string table")


@pytest.mark.parametrize("text", ["local x = 1\n", "ns.L = {\n\tA = 1,\n\tA = 2,\n}\n"])
def test_scan_refuses_a_file_it_cannot_read(text: str) -> None:
    with pytest.raises(ConvertError):
        scan(text)


# --- writing TOML -----------------------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("value", "text"),
    [
        ("plain", '"plain"'),
        ('say "hi"', '"say \\"hi\\""'),
        ("a\nb", '"a\\nb"'),
        ("a\tb", '"a\\tb"'),
        ("\\path\\to", "'\\path\\to'"),  # backslashes and nothing else: a literal string
        ("\\path's", '"\\\\path\'s"'),  # a quote ends a literal string, so it is a basic one
        ("bell\x07", '"bell\\u0007"'),
        ("naïve · café…", '"naïve · café…"'),
    ],
)
def test_strings_are_written_so_toml_reads_them_back(value: str, text: str) -> None:
    assert toml_string(value) == text
    assert tomllib.loads(f"k = {text}")["k"] == value


def test_values_are_written_as_the_shapes_the_generator_reads() -> None:
    assert entry_lines("A", "x") == ['A = "x"']
    assert entry_lines("A", ["x", "y"]) == ['A = ["x", "y"]']
    assert entry_lines("A", [["a", "b"], ["c"]]) == ['A = [["a", "b"], ["c"]]']
    assert entry_lines("A", [{"text": "x"}]) == ['A = [{ text = "x" }]']
    assert entry_lines("A", {"0": "East", "1": "West"}) == ['A.0 = "East"', 'A.1 = "West"']
    assert entry_lines("A", {"core.binding": "B", "12h": "t", "ok": "k"}) == ['A."core.binding" = "B"', 'A."12h" = "t"', 'A.ok = "k"']
    assert entry_lines("A", {"a": {"one": "1", "other": "n"}}) == ['A.a.one = "1"', 'A.a.other = "n"']
    long: Json = ["w" * 60, "x" * 60, "y"]
    assert entry_lines("A", long) == ["A = [", f'\t"{"w" * 60}",', f'\t"{"x" * 60}",', '\t"y",', "]"]


# --- the whole run ----------------------------------------------------------------------------------------------------


def test_the_converted_tree_generates_an_enus_that_builds_the_same_ns_l(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    if not LUA.exists():
        pytest.skip("no .tools/bin/lua")
    root = tree(tmp_path)
    written = convert(root)
    assert "data/locale/enUS/locale.toml" in written
    assert {f"data/locale/enUS/{file_id}.toml" for file_id in FILES} <= set(written)
    assert {f"spec/fixtures/enUS-handwritten/{addon}.lua" for addon in ADDON_IDS} <= set(written)
    assert run(root, capsys)[0] == 0
    assert run(root, capsys, "--check")[0] == 0
    for addon in ADDON_IDS:
        reference = root / "spec" / "fixtures" / "enUS-handwritten" / f"{addon}.lua"
        assert reference.read_text(encoding="utf-8") == mini(addon)
        lua_equal(reference, root / "addons" / addon / "locale" / "enUS.lua")


def test_the_toml_keeps_the_order_the_comments_and_the_exact_text(tmp_path: Path) -> None:
    root = tree(tmp_path)
    convert(root)
    text = (root / "data" / "locale" / "enUS" / "hunts.toml").read_text(encoding="utf-8")
    body = text.split("\n\n", 1)[1]
    assert body.startswith(
        '# A title (MIN-R1).\n# the trailing note\nTITLE = "Pagle_Hunts"\n'
        'SAY = "He said \\"hi\\" -- {not a comment or a brace} \'quoted\'"\n'
        "STAR_LINE = '%s: |TInterface\\AddOns\\Pagle_Hunts\\star:0|t|TInterface\\AddOns\\Pagle_Hunts\\star:0|t'\n"
    )
    assert '\n# Counted strings (MIN-R2).\n# Two lines of it.\nCOUNT.one = "{n} fish"\nCOUNT.other = "{n} fishes"\n' in body
    assert "\nCONT.0 = \"East\"\nCONT.1 = \"West\"\n" in body
    assert "\nRARE.2 = \"an uncommon\"\nRARE.3 = \"a rare\"\n" in body
    assert '\nTIERS.1 = "Plain"\nTIERS.2 = "Fine"\nTIERS.curio = "Curio"\n' in body
    assert '\nSLOTS."12h" = "12-hour"\nSLOTS."core.binding" = "Binding"\n' in body
    assert '\nSEAL = "%s\\nof %s"\n' in body
    assert '\nEMPTY = ""\n' in body
    assert "# inside a table\nNOTES = [{ text = \"x\" }, { text = \"y\" }]\n" in body
    assert text.splitlines()[0].startswith("# Pagle_Hunts's interface text in English")
    assert "# The Pagle_Hunts's string table (CORE-R8)." in text
    header = (root / "data" / "locale" / "enUS" / "locale.toml").read_text(encoding="utf-8")
    assert tomllib.loads(header) == {"name": "English", "plural": "one_other", "decimal": ".", "thousands": ","}


def snapshot(root: Path) -> dict[Path, bytes]:
    """Every file the conversion and the generator leave in locale directories, the TOML and the reference copies."""
    return {
        path: path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file() and ("locale" in path.parts or "enUS-handwritten" in path.parts) and ".partial" not in path.name
    }


def test_the_run_is_repeatable_and_leaves_the_same_bytes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path)
    convert(root)
    assert run(root, capsys)[0] == 0
    first = snapshot(root)
    # What a rebase does: the hand-written files come back, the conversion goes, and it runs again.
    for path in (root / "data" / "locale" / "enUS").iterdir():
        path.unlink()
    (root / "data" / "locale" / "enUS").rmdir()
    for addon in ADDON_IDS:
        (root / "addons" / addon / "locale" / "enUS.lua").write_text(mini(addon), encoding="utf-8")
    assert main([], root) == 0
    second = snapshot(root)
    assert first == second


def test_it_refuses_a_tree_already_converted(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = tree(tmp_path)
    convert(root)
    with pytest.raises(ConvertError, match="already exists"):
        convert(root)
    assert run(root, capsys)[0] == 0
    for path in (root / "data" / "locale" / "enUS").iterdir():
        path.unlink()
    (root / "data" / "locale" / "enUS").rmdir()
    with pytest.raises(ConvertError, match="already generated"):
        convert(root)


def test_it_names_the_file_when_lua_cannot_build_the_table(tmp_path: Path) -> None:
    bad = tmp_path / "enUS.lua"
    bad.write_text("local ns = select(2, ...)\nns.L = {\n\tA = nope(),\n}\n", encoding="utf-8")
    with pytest.raises(ConvertError, match="enUS.lua"):
        evaluate(LUA, bad)
    bad.write_text("local ns = select(2, ...)\nns.L = { A = 5 }\n", encoding="utf-8")
    with pytest.raises(ConvertError, match="not text, an array or a table"):
        evaluate(LUA, bad)
    bad.write_text('local ns = select(2, ...)\nns.L = { A = { ["7"] = "x" } }\n', encoding="utf-8")
    with pytest.raises(ConvertError, match="reads as a number"):
        evaluate(LUA, bad)


def test_main_reports_a_conversion_it_cannot_do(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert main([], tmp_path) == 1
    assert "no hand-written enUS.lua to convert" in capsys.readouterr().err
