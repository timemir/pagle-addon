"""The Spanish translation of lore (DATA-R113): data/lore/es/<lore ID>.toml, the Lore.esES.lua each addon with a
translation gets, and the checks the generator runs on a translation."""

from pathlib import Path

import pytest

from cli_fixture import run
from test_item_records import write_tree
from test_lore import FAMILIES, HEADER, ITEMS, LEDGER, MANIFEST, OFF

ES_LUA = "addons/Pagle_Ledger/data/Lore.esES.lua"

# Some of LEDGER's keys in Spanish, out of order on purpose; the rest show in English.
SPANISH = """\
[title.zonemaster]
text = "Maestro de {zone}"

[family.1]
name = "Meros"

[line.uncaughtlegend]
text = "Algunos peces son solo cuentos, de momento."
"""

ES_LUA_TEXT = (
    HEADER.replace("data/lore/ledger.toml", "data/lore/es/ledger.toml")
    + """
if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

if not GetLocale or GetLocale() ~= "esES" then
	return
end

local L = select(2, ...).L

L["family.1.name"] = "Meros"
L["line.uncaughtlegend.text"] = "Algunos peces son solo cuentos, de momento."
L["title.zonemaster.text"] = "Maestro de {zone}"
"""
)


def write_es_tree(root: Path, spanish: str | None = SPANISH, english: str = LEDGER) -> Path:
    """The lore fixture tree (test_lore's ITEMS, english as ledger.toml, and MANIFEST) plus data/lore/es/ledger.toml
    when given."""
    write_tree(root, ITEMS, families=FAMILIES, checks=OFF)
    directory = root / "data" / "lore"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "ledger.toml").write_text(english, encoding="utf-8")
    (directory / "manifest.toml").write_text(MANIFEST, encoding="utf-8")
    if spanish is not None:
        (directory / "es").mkdir()
        (directory / "es" / "ledger.toml").write_text(spanish, encoding="utf-8")
    return root


def fails(root: Path, capsys: pytest.CaptureFixture[str], *problems: str) -> None:
    code, output = run(root, capsys)
    assert code == 1, output
    for problem in problems:
        assert problem in output


def test_a_translation_is_emitted_sorted_into_lore_es_es_lua_behind_a_locale_guard(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    code, output = run(write_es_tree(tmp_path), capsys)
    assert code == 0, output
    assert (tmp_path / ES_LUA).read_text(encoding="utf-8") == ES_LUA_TEXT


def test_no_translation_gives_no_lore_es_es_lua(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code, output = run(write_es_tree(tmp_path, None), capsys)
    assert code == 0, output
    assert not (tmp_path / ES_LUA).exists()


@pytest.mark.parametrize(
    ("spanish", "problem"),
    [
        ('[family.99]\nname = "Meros"\n', "data/lore/es/ledger.toml: family.99.name: orphan: no English text"),
        ('[family.1]\nname = " "\n', "family.1.name: missing: empty"),
        ('[family.1]\nname = "Meros de los arrecifes más hondos"\n', "family.1.name: length: 33 code points"),
        ('[family.1]\nname = "Me\\nros"\n', "family.1.name: newline"),
        ('[title.zonemaster]\ntext = "Maestro de {lugar}"\n', "title.zonemaster.text: placeholder"),
        ('[title.zonemaster]\ntext = "Maestro"\n', "title.zonemaster.text: placeholder"),
        ('[family.1]\nname = "Meros {zone}"\n', "family.1.name: placeholder"),
        ('[family.1]\nname = "Meros ★"\n', "family.1.name: glyph: U+2605"),
    ],
)
def test_a_bad_translation_fails_naming_its_file_and_key(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], spanish: str, problem: str
) -> None:
    fails(write_es_tree(tmp_path, spanish), capsys, problem)


def test_a_translation_of_an_empty_english_text_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    english = LEDGER.replace('name = "Groupers"', 'name = ""')
    fails(write_es_tree(tmp_path, english=english), capsys, "family.1.name: orphan: no English text")


def test_a_translation_file_that_is_no_lore_id_s_fails(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = write_es_tree(tmp_path)
    (root / "data" / "lore" / "es" / "nonsense.toml").write_text("", encoding="utf-8")
    fails(root, capsys, "data/lore/es/nonsense.toml: not a translation")
