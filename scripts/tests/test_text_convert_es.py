"""The esES mode of the text converter (#519): a small Spanish file, read as PR #510's are, converted to the 1.1 shape."""

import shutil
import tomllib
from pathlib import Path

from pagle_data.text_convert import convert
from pagle_data.text_convert_es import EsEntry, convert_es, parse_es_lua
from test_text_convert import apply, build

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

    entries = parse_es_lua(source)

    assert entries == [
        EsEntry("A", "uno dos", "one two"),
        EsEntry("T", {"x": {"one": "a\nb", "other": "c"}, "2": "list"}, {"x": {"one": "a", "other": "c"}}),
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

    report = convert_es(root, before, files.get, list(files))

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
    assert report.files["data/lore/esES/stats.toml"] == LORE
    assert report.refreshed == ["Pagle_Stats HI", "Pagle_Stats CATCHES", "Pagle_Stats COUNTS", "Pagle_Stats FANCY"]
    assert report.stale == ["Pagle_Stats BOOK"]
    assert report.many == ["Pagle_Stats CATCHES", "Pagle_Stats COUNTS"]
    assert report.worklist == ["Pagle_Stats ORPHAN: no such key in English now (orphan)"]
