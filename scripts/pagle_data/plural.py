"""CLDR plural rules as data (DATA-R114): the table of named rules a Locale's header picks from, and the Lua function the
generator writes from the one it names.

A Locale's TOML header says `plural = "one_many_other"`; it never holds code. The table below holds each rule's
categories and the body of its Lua function, so a new language needs a name here at most, and touches no `logic/` file.
A rule is the CLDR cardinal rule of the languages listed beside it, over the count's absolute value, which is all the
text helper hands over (`n`, with the integer part taken as `math.floor(n)` where the rule needs it, and `v = 0` read as
"`n` is a whole number"). The functions use Lua 5.1's operators and `math` only, as `logic/` does.
"""

from dataclasses import dataclass

# CLDR's cardinal categories, in the order a rule lists them.
CATEGORIES = ("zero", "one", "two", "few", "many", "other")


@dataclass(frozen=True)
class Rule:
    """One named rule: the categories it can answer and the Lua body of `function(n)`, one string per line, tabs
    for the nesting inside the body."""

    categories: tuple[str, ...]
    languages: str
    body: tuple[str, ...]


RULES: dict[str, Rule] = {
    # CLDR: no plural forms at all (Chinese, Japanese, Korean, Vietnamese).
    "other": Rule(("other",), "ja, ko, zh, vi", ('return "other"',)),
    # CLDR: one is exactly 1 (English, German, Dutch, Swedish and the like).
    "one_other": Rule(
        ("one", "other"),
        "en, de, nl, sv",
        ("if n == 1 then", '\treturn "one"', "end", 'return "other"'),
    ),
    # CLDR: one is exactly 1, many a non-zero whole multiple of a million (Spanish, Italian).
    "one_many_other": Rule(
        ("one", "many", "other"),
        "es, it",
        (
            "if n == 1 then",
            '\treturn "one"',
            "end",
            "if n ~= 0 and n == math.floor(n) and n % 1000000 == 0 then",
            '\treturn "many"',
            "end",
            'return "other"',
        ),
    ),
    # CLDR: one is an integer part of 0 or 1, many a non-zero whole multiple of a million (French, Portuguese).
    "one_many_other_01": Rule(
        ("one", "many", "other"),
        "fr, pt",
        (
            "local i = math.floor(n)",
            "if i == 0 or i == 1 then",
            '\treturn "one"',
            "end",
            "if n == i and i % 1000000 == 0 then",
            '\treturn "many"',
            "end",
            'return "other"',
        ),
    ),
    # CLDR: one ends in 1 but not 11, few in 2 to 4 but not 12 to 14, many is the rest of the whole numbers; a
    # fraction is other (Russian, Ukrainian).
    "one_few_many_other": Rule(
        ("one", "few", "many", "other"),
        "ru, uk",
        (
            "if n ~= math.floor(n) then",
            '\treturn "other"',
            "end",
            "local ten, hundred = n % 10, n % 100",
            "if ten == 1 and hundred ~= 11 then",
            '\treturn "one"',
            "end",
            "if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then",
            '\treturn "few"',
            "end",
            'return "many"',
        ),
    ),
}


def plural_lua(name: str, depth: int) -> str:
    """The Lua `function(n) … end` for the rule `name`, as it appears as a value at `depth` tabs of nesting. The
    caller has checked the name is in RULES."""
    inner = "\t" * (depth + 1)
    lines = [f"{inner}{line}" for line in RULES[name].body]
    return "function(n)\n" + "\n".join(lines) + "\n" + "\t" * depth + "end"
