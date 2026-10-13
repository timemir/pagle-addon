"""Writing values as Lua (DATA-R62's determinism, for the shapes later catalogue fields need)."""

import pytest

from pagle_data.lua import to_lua


def test_map_keys_ascend_numbers_numerically_then_strings_by_byte() -> None:
    # DATA-R62: "Map keys are written in ascending order (numbers numerically, strings by byte)".
    assert to_lua({10: 1, 9: 2, "b": 3, "B": 4}) == "{ [9] = 2, [10] = 1, B = 4, b = 3 }"


def test_lists_keep_their_order_and_nested_tables_go_one_entry_per_line() -> None:
    # DATA-R62: lists in the order the spec states (the caller sorts those that must ascend).
    expected = "{\n\tpools = {\n\t\tschool = { 3, 1 },\n\t},\n\tx = {},\n}"
    assert to_lua({"pools": {"school": [3, 1]}, "x": []}) == expected


def test_strings_are_escaped_and_keys_that_are_not_names_are_bracketed() -> None:
    # Lua 5.1 syntax: keywords and non-identifiers can't be bare keys.
    expected = '{ ["end"] = "a\\"b\\\\c\\nd\\009e", ["two words"] = "é" }'
    assert to_lua({"end": "a\"b\\c\nd\te", "two words": "é"}) == expected


@pytest.mark.parametrize("value", [1.5, None, {True: 1}])
def test_values_with_no_place_in_the_catalogue_are_a_bug(value: object) -> None:
    # DATA-R62: integers without decimals; the catalogue holds no floats or nils.
    with pytest.raises(TypeError):
        to_lua(value)
