"""The interface text the repository ships (DATA-R114): data/locale/enUS/ holds every addon's English, the generated
enUS.lua is what it gives, and English's header is the text helper's built-in English."""

import re
from collections.abc import Mapping
from pathlib import Path

import pytest

from pagle_data.errors import Problems
from pagle_data.glyphs import ENGLISH
from pagle_data.locale import ADDON_IDS, BUILT_IN, FILES, check_locale, locale_lua, read_locale

REPO = Path(__file__).resolve().parents[2]

# The conversion is a commit of its own, which is dropped and re-run after a rebase: without it nothing here applies.
CONVERTED = (REPO / "data" / "locale" / "enUS").is_dir()
needs_conversion = pytest.mark.skipif(not CONVERTED, reason="data/locale/enUS/ is not converted yet")


@needs_conversion
def test_english_is_all_six_addons_and_passes_every_check() -> None:
    problems = Problems()
    layer = read_locale(REPO, problems)
    check_locale(layer, problems)
    assert problems.found == []
    assert layer.present
    assert set(layer.files[ENGLISH]) == set(FILES)
    assert str(layer.files[ENGLISH]["core"]["NOT_FOREVER"].value).startswith("Pagle: this isn't World of Warcraft")


def test_the_headers_built_in_english_is_what_the_helper_holds() -> None:
    """BUILT_IN is the one copy the generator checks English's header against; logic/Text.lua is the other."""
    text = (REPO / "addons" / "Pagle" / "logic" / "Text.lua").read_text(encoding="utf-8")
    english = text.split("local ENGLISH", 1)[1].split("\n}\n", 1)[0]
    assert re.search(r'return n == 1 and "one" or "other"', english)
    assert BUILT_IN["plural"] == "one_other"
    assert re.search(r'decimal = "(.)"', english)
    assert re.search(r'decimal = "(.)"', english).group(1) == BUILT_IN["decimal"]  # type: ignore[union-attr]
    assert re.search(r'thousands = "(.*?)"', english).group(1) == BUILT_IN["thousands"]  # type: ignore[union-attr]


@needs_conversion
def test_each_enus_lua_is_the_generated_file(repo_outputs: Mapping[str, str]) -> None:
    for addon in ADDON_IDS:
        path = locale_lua(addon, ENGLISH)
        committed = (REPO / path).read_text(encoding="utf-8")
        assert committed == repo_outputs[path]
        assert f"from data/locale/enUS/{ADDON_IDS[addon]}.toml. Do not edit by hand" in committed
