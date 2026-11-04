"""The line-based TOML edit behind --drop-stale (DATA-R114): it removes exactly the entries it is given, in whatever form
TOML lets a translator write them, and keeps every comment and everything else byte for byte."""

import tomllib

import pytest

from pagle_data.toml_edit import EditError, drop_entries

SPANISH = """\
# Core's Spanish. Keep the tone informal.

# --- Titles ---
[TITLE]
value = "Pagle"
en = "Pagle"

[GREETING]  # said at login
# the comma is deliberate
value = "Hola, {name}"
en = "Hello, {name}"

# --- Counts ---
[FISH_COUNT]
value.one = "{count} pez"
value.many = "{count} de peces"
value.other = "{count} peces"
en.one = "{count} fish"
en.other = "{count} fishes"

[BANDS]
value = [
  "Pequeño",  # small
  "Grande",
]
en = ["Small", "Big"]
"""


def keys(text: str) -> list[str]:
    return list(tomllib.loads(text))


def test_a_table_goes_with_its_own_lines() -> None:
    result = drop_entries(SPANISH, 1, [("GREETING",)])
    assert result == SPANISH.replace(
        '[GREETING]  # said at login\n# the comma is deliberate\nvalue = "Hola, {name}"\nen = "Hello, {name}"\n',
        "# the comma is deliberate\n",
    )
    assert keys(result) == ["TITLE", "FISH_COUNT", "BANDS"]


def test_comments_stay_where_they_were() -> None:
    result = drop_entries(SPANISH, 1, [("GREETING",), ("FISH_COUNT",)])
    for comment in ("# Core's Spanish", "# --- Titles ---", "# the comma is deliberate", "# --- Counts ---", "# small"):
        assert comment in result  # the last is inside BANDS, which stays
    assert "# said at login" not in result  # on the header line of a dropped table: it went with the line
    assert result.index("# --- Titles ---") < result.index("# the comma") < result.index("# --- Counts ---")


def test_the_first_the_middle_and_the_last_entry() -> None:
    assert keys(drop_entries(SPANISH, 1, [("TITLE",)])) == ["GREETING", "FISH_COUNT", "BANDS"]
    assert keys(drop_entries(SPANISH, 1, [("FISH_COUNT",)])) == ["TITLE", "GREETING", "BANDS"]
    last = drop_entries(SPANISH, 1, [("BANDS",)])
    assert keys(last) == ["TITLE", "GREETING", "FISH_COUNT"]
    assert last.endswith('en.other = "{count} fishes"\n')  # no blank line left at the end


def test_a_multi_line_array_goes_whole() -> None:
    result = drop_entries(SPANISH, 1, [("BANDS",)])
    assert "Pequeño" not in result and "Grande" not in result and "Small" not in result


def test_everything_dropped_leaves_the_comments_and_no_stray_blank_lines() -> None:
    result = drop_entries(SPANISH, 1, [("TITLE",), ("GREETING",), ("FISH_COUNT",), ("BANDS",)])
    assert tomllib.loads(result) == {}
    assert result == "# Core's Spanish. Keep the tone informal.\n\n# --- Titles ---\n\n# the comma is deliberate\n\n# --- Counts ---\n"


def test_nothing_to_drop_returns_the_text_itself() -> None:
    assert drop_entries(SPANISH, 1, []) == SPANISH
    assert drop_entries(SPANISH, 1, [("NOT_THERE",)]) == SPANISH


def test_a_second_drop_changes_nothing() -> None:
    once = drop_entries(SPANISH, 1, [("GREETING",), ("BANDS",)])
    assert drop_entries(once, 1, [("GREETING",), ("BANDS",)]) == once


def test_a_name_that_is_a_prefix_of_another_is_not_dropped_with_it() -> None:
    text = '[FISH]\nvalue = "a"\nen = "b"\n\n[FISH_COUNT]\nvalue = "c"\nen = "d"\n'
    assert keys(drop_entries(text, 1, [("FISH",)])) == ["FISH_COUNT"]


def test_the_subtable_forms_and_a_dotted_header() -> None:
    text = '[A.value]\none = "x"\nother = "y"\n\n[A.en]\none = "p"\nother = "q"\n\n[B]\nvalue = "k"\nen = "l"\n'
    assert drop_entries(text, 1, [("A",)]) == '[B]\nvalue = "k"\nen = "l"\n'


def test_dotted_keys_and_inline_tables_without_a_header() -> None:
    text = 'A.value = "x"\nA.en = "y"\nB = { value = "k", en = "l" }\nC.value = "m"\nC.en = "n"\n'
    assert drop_entries(text, 1, [("A",)]) == 'B = { value = "k", en = "l" }\nC.value = "m"\nC.en = "n"\n'
    assert drop_entries(text, 1, [("B",)]) == 'A.value = "x"\nA.en = "y"\nC.value = "m"\nC.en = "n"\n'


def test_a_quoted_key_and_a_header_with_spaces() -> None:
    text = '[ "A B" ]\nvalue = "x"\nen = "y"\n\n[\'C\']\nvalue = "m"\nen = "n"\n'
    assert drop_entries(text, 1, [("A B",)]) == '[\'C\']\nvalue = "m"\nen = "n"\n'
    assert drop_entries(text, 1, [("C",)]) == '[ "A B" ]\nvalue = "x"\nen = "y"\n'


def test_multi_line_strings_with_lookalike_lines_are_not_taken_for_headers_or_comments() -> None:
    text = (
        '[A]\nvalue = """\n[B]\n# not a comment\nkey = 1\n"""\nen = \'\'\'\n[C]\n\'\'\'\n\n'
        '[D]\nvalue = "d"\nen = "e"\n'
    )
    assert drop_entries(text, 1, [("A",)]) == '[D]\nvalue = "d"\nen = "e"\n'
    assert keys(drop_entries(text, 1, [("D",)])) == ["A"]


def test_a_multi_line_string_with_quotes_and_an_escaped_end() -> None:
    text = '[A]\nvalue = """a "quoted" b""\\\n  c\\""""\nen = "x"\n\n[B]\nvalue = "v"\nen = "w"\n'
    assert drop_entries(text, 1, [("A",)]) == '[B]\nvalue = "v"\nen = "w"\n'


def test_brackets_and_hashes_inside_strings_do_not_confuse_the_scan() -> None:
    text = '[A]\nvalue = ["# [x]", \'}\', "a # b"]  # c ]\nen = "[B]"\n\n[B]\nvalue = "b"\nen = "b"\n'
    assert drop_entries(text, 1, [("A",)]) == '[B]\nvalue = "b"\nen = "b"\n'


def test_a_lore_field_is_three_components_deep() -> None:
    text = (
        "# Fixture\n"
        '[species.6362.blurb]\nvalue = "a"\nen = "b"\n\n'
        '[species.6362.riddle]\nvalue = "c"\nen = "d"\n\n'
        '[good."core.toaststyle.page".name]\nvalue = "e"\nen = "f"\n'
    )
    result = drop_entries(text, 3, [("species", "6362", "blurb")])
    assert tomllib.loads(result) == {
        "species": {"6362": {"riddle": {"value": "c", "en": "d"}}},
        "good": {"core.toaststyle.page": {"name": {"value": "e", "en": "f"}}},
    }
    assert result.startswith("# Fixture\n\n[species.6362.riddle]\n")
    gone = drop_entries(text, 3, [("good", "core.toaststyle.page", "name")])
    assert "good" not in tomllib.loads(gone) and gone.endswith('en = "d"\n')


def test_a_lore_field_inside_a_shared_table_goes_alone() -> None:
    text = '[species.6362]\nblurb = { value = "a", en = "b" }\nriddle.value = "c"\nriddle.en = "d"\n'
    result = drop_entries(text, 3, [("species", "6362", "blurb")])
    assert result == '[species.6362]\nriddle.value = "c"\nriddle.en = "d"\n'


def test_line_endings_and_a_missing_final_newline_are_kept() -> None:
    text = '[A]\r\nvalue = "x"\r\nen = "y"\r\n\r\n[B]\r\nvalue = "k"\r\nen = "l"'
    assert drop_entries(text, 1, [("A",)]) == '[B]\r\nvalue = "k"\r\nen = "l"'
    assert drop_entries(text, 1, [("B",)]) == '[A]\r\nvalue = "x"\r\nen = "y"'


def test_a_file_with_one_entry_dropped_is_empty() -> None:
    assert drop_entries('[A]\nvalue = "x"\nen = "y"\n', 1, [("A",)]) == ""


def test_an_array_of_tables_is_refused() -> None:
    with pytest.raises(EditError, match="array of tables"):
        drop_entries('[[A]]\nvalue = "x"\n', 1, [("A",)])


def test_a_file_that_is_not_toml_is_refused() -> None:
    with pytest.raises(EditError, match="not valid TOML"):
        drop_entries("[A\nvalue = 1\n", 1, [("A",)])


def test_an_entry_of_the_wrong_depth_is_refused() -> None:
    with pytest.raises(EditError, match="1 component"):
        drop_entries('[A]\nvalue = "x"\n', 1, [("A", "value")])


def test_the_edit_is_proved_against_the_original(monkeypatch: pytest.MonkeyPatch) -> None:
    """If the scan ever dropped a line it should not have, the check on the result raises instead of returning it."""
    import pagle_data.toml_edit as edit

    real = edit._items

    def wrong(lines: list[str]) -> list[edit._Item]:
        return [edit._Item("statement", item.first, item.last, ("A",)) if item.kind == "statement" else item for item in real(lines)]

    monkeypatch.setattr(edit, "_items", wrong)
    with pytest.raises(EditError, match="beside the entries"):
        drop_entries('[A]\nvalue = "x"\n\n[B]\nvalue = "y"\n', 1, [("A",)])


@pytest.mark.parametrize("mask", range(1, 16))
def test_every_choice_of_entries_leaves_exactly_the_others_and_all_the_comments(mask: int) -> None:
    names = ["TITLE", "GREETING", "FISH_COUNT", "BANDS"]
    chosen = [(name,) for bit, name in enumerate(names) if mask & (1 << bit)]

    result = drop_entries(SPANISH, 1, chosen)

    assert list(tomllib.loads(result)) == [name for name in names if (name,) not in chosen]
    assert drop_entries(result, 1, chosen) == result
    comments = [line for line in SPANISH.splitlines() if line.startswith("#")]
    assert [line for line in result.splitlines() if line.startswith("#")] == comments
    assert "\n\n\n" not in result and result.endswith("\n") and not result.endswith("\n\n")
