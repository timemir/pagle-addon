"""The esES mode of the text converter (#519): a small Spanish file, read as PR #510's are, converted to the 1.1 shape."""

import shutil
import tomllib
from pathlib import Path

from pagle_data.text_convert import convert
from pagle_data.text_convert_es import EsEntry, _same, convert_es, evaluate_es, parse_es_lua
from test_text_convert import apply, build
from tools_fixture import tool

STATS = (
    'HI = "Hi %s"\n'
    'BOOK = "Stats"\n'
    'CATCHES_ONE = "%s Catch"\n'
    'CATCHES_OTHER = "%s Catches"\n'
    'COUNTS.Casts.one = "%s Cast"\n'
    'COUNTS.Casts.other = "%s Casts"\n'
    'FANCY = "{a} then {b}"\n'
)
LUA = (
    "local ns = select(2, ...)\n"
    "local L = ns.L\n"
    "function ns.Say(name, n, noun, amount)\n"
    "\treturn L.HI:format(name), (n == 1 and L.CATCHES_ONE or L.CATCHES_OTHER):format(ns.Number(n)),"
    " L.COUNTS[noun]:format(amount)\n"
    "end\n"
)
SPANISH = (
    'if not Pagle then return end\nlocal ns = select(2, ...)\nlocal L = ns.L\n\n'
    'L.HI = "Hola %s"\n-- EN: Hi %s\n'
    'L.BOOK = "Libro"\n-- EN: Stats book\n'
    'L.CATCHES_ONE = "%s Captura"\n-- EN: %s Catch\n'
    'L.CATCHES_OTHER = "%s Capturas"\n-- EN: %s Catches\n'
    'L.COUNTS = {\n\tCasts = { one = "%s Lance", other = "%s Lances" },\n}\n'
    '-- EN: { Casts = { one = "%s Cast", other = "%s Casts" } }\n'
    'L.FANCY = "%s luego %d"\n-- EN: {a} then {b}\n'
    'L.ORPHAN = "x"\n-- EN: y\n'
)
LORE = '[statsgood."stats.trackerframe.none"]\nname = "Sin marco"\n# EN: No Frame\n'




def test_a_spanish_file_is_read_with_its_english_comments() -> None:
    source = (
        'L.A = "uno " .. "dos"\n-- EN: one two\n'
        'L.T = {\n\tx = { one = "a\\nb", other = "c" },\n\t"list",\n}\n-- EN: { x = { one = "a", other = "c" } }\n'
    )

    entries = parse_es_lua(source, evaluate_es(tool("bin/lua"), 'local ns = select(2, ...)\nlocal L = ns.L\n' + source))

    assert entries == [
        EsEntry("A", "uno dos", "one two"),
        EsEntry("T", {"1": "list", "x": {"one": "a\nb", "other": "c"}}, {"x": {"one": "a", "other": "c"}}),
    ]


def test_the_spanish_strings_become_fields_counted_strings_and_snapshots(tmp_path: Path) -> None:
    root = tmp_path / "now"
    build(root, {"Pagle_Stats": STATS}, {"addons/Pagle_Stats/logic/Say.lua": LUA})
    before = tmp_path / "before"
    shutil.copytree(root, before)
    apply(root, convert(root))
    files = {
        "addons/Pagle_Stats/locale/esES.lua": SPANISH,
        "data/lore/es/stats.toml": LORE,
    }

    report = convert_es(root, before, files.get, list(files), tool("bin/lua"))

    parsed = tomllib.loads(report.files["data/locale/esES/stats.toml"])
    assert parsed["HI"] == {"value": "Hola {name}", "en": "Hi {name}"}
    assert parsed["BOOK"] == {"value": "Libro", "en": "Stats book"}
    assert parsed["CATCHES"] == {
        "value": {"one": "{count:n} Captura", "many": "{count:n} Capturas", "other": "{count:n} Capturas"},
        "en": {"one": "{count:n} Catch", "other": "{count:n} Catches"},
    }
    assert parsed["COUNTS"]["value"]["Casts"] == {"one": "{amount} Lance", "many": "{amount} Lances", "other": "{amount} Lances"}
    assert parsed["FANCY"] == {"value": "{a} luego {b:0}", "en": "{a} then {b}"}
    assert "ORPHAN" not in parsed
    assert tomllib.loads(report.files["data/locale/esES/locale.toml"])["plural"] == "one_many_other"
    assert report.files["data/lore/esES/stats.toml"] == (
        '[statsgood."stats.trackerframe.none"]\nname.value = "Sin marco"\nname.en = "No Frame"\n'
    )
    assert report.refreshed == ["Pagle_Stats HI", "Pagle_Stats CATCHES", "Pagle_Stats COUNTS", "Pagle_Stats FANCY"]
    assert report.stale == ["Pagle_Stats BOOK"]
    assert report.many == ["Pagle_Stats CATCHES", "Pagle_Stats COUNTS"]
    assert report.worklist == ["Pagle_Stats ORPHAN: no such key in English now (orphan)"]


def test_a_comment_written_with_the_lua_escapes_is_the_english_it_quotes() -> None:
    # #510's own comments (Pagle CARD_COINS, GUIDE_LIST_AND, ENTRY_ALL_DONE, XP_BAR_FRESH): a backslash doubled, a quote escaped,
    # a text with a space at its ends quoted.
    icon = "Pagle Coins +%s |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
    assert _same(icon.replace("\\", "\\\\"), icon)
    assert _same('" and "', " and ")
    assert _same('Tick \\"show completed\\" to see them again.', 'Tick "show completed" to see them again.')
    assert _same({"one": '" Fresh Water for %d more Catch."', "other": "c"}, {"one": " Fresh Water for %d more Catch.", "other": "c"})
    # What is not the English stays different: a changed wording, a comment that quotes only part, a missing key.
    assert not _same("Pagle dev: /pagle dev on | off", "Pagle dev: /pagle dev on | off | fonts")
    assert not _same('" and', " and ")
    assert not _same({"one": "a"}, {"one": "a", "other": "b"})
    assert not _same(None, "x")


def test_a_translation_with_an_escaped_comment_is_refreshed_not_kept_stale(tmp_path: Path) -> None:
    root = tmp_path / "now"
    build(
        root,
        {"Pagle_Stats": 'ICON = "Got %s \\\\Media\\\\a.blp"\n'},
        {"addons/Pagle_Stats/logic/Say.lua": "local ns = select(2, ...)\nlocal L = ns.L\nfunction ns.Say(n)\n\treturn L.ICON:format(n)\nend\n"},
    )
    before = tmp_path / "before"
    shutil.copytree(root, before)
    apply(root, convert(root))
    spanish = 'local ns = select(2, ...)\nlocal L = ns.L\nL.ICON = "Tiene %s \\\\Media\\\\a.blp"\n-- EN: Got %s \\\\Media\\\\a.blp\n'
    files = {"addons/Pagle_Stats/locale/esES.lua": spanish}

    report = convert_es(root, before, files.get, list(files), tool("bin/lua"))

    parsed = tomllib.loads(report.files["data/locale/esES/stats.toml"])
    assert parsed["ICON"] == {"value": "Tiene {icon} \\Media\\a.blp", "en": "Got {icon} \\Media\\a.blp"}
    assert report.refreshed == ["Pagle_Stats ICON"]
    assert report.stale == []
