"""The pages behind a variety's name (scripts/measure-name-pages.py, pagle_data/name_pages.py, #582): the committed
NAME_PAGES block in adapter/Art.lua reads back whole, the block round-trips, the check names what disagrees, and the
contrast arithmetic is WCAG's. scripts/check.sh's generator stage measures the art itself (--check)."""

from pathlib import Path

import pytest

from pagle_data import name_pages

REPO = Path(__file__).resolve().parents[2]


def test_relative_luminance_and_contrast_are_wcags() -> None:
    assert name_pages.relative_luminance((1, 1, 1)) == pytest.approx(1)
    assert name_pages.relative_luminance((0, 0, 0)) == 0
    assert name_pages.contrast(1, 0) == pytest.approx(21)
    assert name_pages.contrast(0.18, 0.18) == 1


def test_the_committed_block_has_every_page_of_every_style() -> None:
    pages = name_pages.read_block((REPO / name_pages.ART_LUA).read_text(encoding="utf-8"))
    assert len(pages) >= 51
    for style, measured in pages.items():
        assert set(measured) == set(name_pages.PAGES), style
        assert all(0 <= value <= 1 for value in measured.values()), style


def test_the_block_round_trips_and_replaces_in_place() -> None:
    pages = {"core.toaststyle.moon": {"toast": 0.027, "toast-ruled": 0.04, "high": 0.028, "nod": 0.034}}
    block = name_pages.lua_block(pages)
    text = f"before\n{name_pages.BEGIN}\nold\n{name_pages.END}\nafter\n"
    replaced = name_pages.replace_block(text, block)
    assert replaced.startswith("before\n") and replaced.endswith("\nafter\n")
    assert name_pages.read_block(replaced) == pages


def test_the_check_names_a_page_the_art_moved_and_one_missing() -> None:
    old = {"a": {"toast": 0.1, "toast-ruled": 0.2, "high": 0.1, "nod": 0.1}}
    new = {"a": {"toast": 0.1, "toast-ruled": 0.21, "high": 0.101, "nod": 0.1},
           "b": {"toast": 0.5, "toast-ruled": 0.5, "high": 0.5, "nod": 0.5}}
    wrong = name_pages.differences(old, new)
    assert any(line.startswith("a toast-ruled") for line in wrong)
    assert not any(line.startswith("a high") for line in wrong)
    assert sum(line.startswith("b ") for line in wrong) == 4
