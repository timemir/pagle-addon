"""CORE-R9's range for each Locale (DATA-R107, DATA-R114): data/glyphs.toml, which spec/glyphs_spec.lua reads too, and
the glyph check that takes a Locale's range."""

import pytest

from pagle_data.errors import Problems
from pagle_data.glyphs import ENGLISH, glyphs_for, read_glyphs
from pagle_data.lore import LoreLayer, Text, check_glyphs

SPANISH = "El pez de río, ¿dónde pica? Año nuevo: señor, ¡qué vida!"  # Latin-1 accents only
LATIN_A = "Œuvre de Łódź, ő, ž, ā"  # Latin Extended-A, which the bundled faces draw
RUSSIAN = "Жёлтая рыба — «Ёрш»"  # Cyrillic, with the em dash and the guillemets of the base set


def layer(value: str) -> LoreLayer:
    text = Text("species", "13759", "riddle", value)
    return LoreLayer(files={"ledger": {text.key: text}})


def found(value: str, locale: str) -> list[str]:
    problems = Problems()
    check_glyphs(layer(value), problems, locale)
    return problems.found


def test_every_locale_the_client_has_is_in_the_table() -> None:
    assert set(read_glyphs()) == {
        "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW",
    }  # fmt: skip


def test_english_lore_keeps_the_base_set_and_its_message() -> None:
    assert found("Fresh — née · 2× “Green” …", ENGLISH) == []
    assert found("Green → horn", ENGLISH) == [
        "data/lore/ledger.toml: species.13759.riddle: glyph: U+2192 outside CORE-R9's set: ASCII, Latin-1, the en and"
        " em dashes, curly quotes, the bullet and the ellipsis (CORE-R9, DATA-R107)"
    ]
    assert found(LATIN_A, ENGLISH) != []  # Latin Extended-A is a translation's, not English lore's


def test_a_spanish_file_with_accents_passes() -> None:
    assert found(SPANISH, "esES") == []
    assert found(SPANISH, "esMX") == []
    assert found(LATIN_A, "frFR") == []


def test_the_same_file_with_a_cyrillic_letter_fails_naming_the_character_the_file_and_the_locale() -> None:
    assert found(SPANISH + " Ж", "esES") == [
        "data/lore/ledger.toml: species.13759.riddle: glyph: U+0416 outside CORE-R9's range for esES: ASCII, Latin-1,"
        " the en and em dashes, curly quotes, the bullet and the ellipsis, plus latin (CORE-R9, DATA-R107)"
    ]


def test_a_russian_file_with_cyrillic_passes_and_a_latin_extended_a_letter_does_not() -> None:
    assert found(RUSSIAN, "ruRU") == []
    assert [problem.split(" outside")[0] for problem in found(RUSSIAN + " ő", "ruRU")] == [
        "data/lore/ledger.toml: species.13759.riddle: glyph: U+0151"
    ]


@pytest.mark.parametrize(
    ("locale", "text"),
    [("koKR", "붉은 물고기, 안녕"), ("zhCN", "红色的鱼，「你好」。"), ("zhTW", "紅色的魚　《你好》")],
)
def test_the_other_scripts_pass_in_their_own_locale_and_fail_in_a_latin_one(locale: str, text: str) -> None:
    assert found(text, locale) == []
    assert found(text, "deDE") != []
    assert found(text, "ruRU") != []


def test_a_locale_the_table_lacks_is_an_error() -> None:
    with pytest.raises(ValueError, match="no range for the Locale 'xxXX'"):
        glyphs_for("xxXX")
