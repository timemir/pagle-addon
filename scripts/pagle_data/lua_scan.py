"""A small Lua 5.1 tokenizer and the expression helpers the text converter (scripts/convert-text.py) needs.

It is not a parser. It splits source into tokens with their offsets (comments dropped, strings and long strings whole)
and walks brackets, which is all it takes to find a call, the expression a method is called on and the arguments it is
given. Nothing here rewrites a file: the callers cut and splice the source text by the offsets.
"""

import re
from dataclasses import dataclass
from typing import Literal

from pagle_data.lua import KEYWORDS

type Kind = Literal["name", "str", "num", "op"]

_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
_LONG_OPEN = re.compile(r"\[(=*)\[")
_COMMENT_LONG = re.compile(r"--\[(=*)\[")
_OPERATORS = ("...", "..", "==", "~=", "<=", ">=")


@dataclass(frozen=True)
class Tok:
    """One token: its kind, its text as written and where it starts and ends in the source."""

    kind: Kind
    text: str
    start: int
    end: int

    def is_op(self, *texts: str) -> bool:
        return self.kind == "op" and self.text in texts

    def is_name(self, *texts: str) -> bool:
        return self.kind == "name" and (not texts or self.text in texts)


class ScanError(Exception):
    """The source is not Lua this scanner can read (unbalanced brackets)."""


def tokenize(source: str) -> list[Tok]:
    """The tokens of a Lua file, comments left out. A string token holds its quotes."""
    toks: list[Tok] = []
    i, length = 0, len(source)
    while i < length:
        char = source[i]
        if char in " \t\r\n":
            i += 1
        elif source.startswith("--", i):
            long = _COMMENT_LONG.match(source, i)
            if long:
                close = source.find("]" + long.group(1) + "]", i)
                i = length if close < 0 else close + len(long.group(1)) + 2
            else:
                newline = source.find("\n", i)
                i = length if newline < 0 else newline
        elif char in "\"'":
            j = i + 1
            while j < length and source[j] != char:
                j += 2 if source[j] == "\\" else 1
            toks.append(Tok("str", source[i : j + 1], i, j + 1))
            i = j + 1
        elif char == "[" and (long := _LONG_OPEN.match(source, i)):
            close = source.find("]" + long.group(1) + "]", i)
            j = length if close < 0 else close + len(long.group(1)) + 2
            toks.append(Tok("str", source[i:j], i, j))
            i = j
        elif char.isalpha() or char == "_":
            name = _NAME.match(source, i)
            assert name is not None
            toks.append(Tok("name", name.group(0), i, name.end()))
            i = name.end()
        elif char.isdigit() or (char == "." and i + 1 < length and source[i + 1].isdigit()):
            number = _NUMBER.match(source, i)
            assert number is not None
            toks.append(Tok("num", number.group(0), i, number.end()))
            i = number.end()
        else:
            op = next((o for o in _OPERATORS if source.startswith(o, i)), char)
            toks.append(Tok("op", op, i, i + len(op)))
            i += len(op)
    return toks


def match_close(toks: list[Tok], opener: int) -> int:
    """The index of the bracket that closes the one at `opener`."""
    depth = 0
    for j in range(opener, len(toks)):
        tok = toks[j]
        if tok.kind != "op":
            continue
        if tok.text in "([{":
            depth += 1
        elif tok.text in ")]}":
            depth -= 1
            if depth == 0:
                return j
    raise ScanError("unbalanced brackets")


def match_open(toks: list[Tok], closer: int) -> int:
    """The index of the bracket that opens the one at `closer`."""
    depth = 0
    for i in range(closer, -1, -1):
        tok = toks[i]
        if tok.kind != "op":
            continue
        if tok.text in ")]}":
            depth += 1
        elif tok.text in "([{":
            depth -= 1
            if depth == 0:
                return i
    raise ScanError("unbalanced brackets")


def _is_callable_end(tok: Tok) -> bool:
    """Whether a `(` right after this token is a call (`f(`, `a.b(`, `f(x)(`), not a parenthesized expression."""
    return (tok.kind == "name" and tok.text not in KEYWORDS) or tok.is_op(")", "]")


def prefix_start(toks: list[Tok], last: int) -> int:
    """The index where the prefix expression (a name, field accesses, calls, indexes, a string or a parenthesized
    expression) that ends at token `last` begins."""
    j = last
    while True:
        tok = toks[j]
        if tok.kind == "name":
            if j > 0 and toks[j - 1].is_op(".", ":"):
                j -= 2
                continue
            return j
        if tok.kind == "str":
            return j
        if tok.is_op("]"):
            j = match_open(toks, j) - 1
            continue
        if tok.is_op(")"):
            opener = match_open(toks, j)
            if opener > 0 and _is_callable_end(toks[opener - 1]):
                j = opener - 1
                continue
            return opener
        return j


def split_args(toks: list[Tok], opener: int, closer: int) -> list[tuple[int, int]]:
    """The arguments of the call whose brackets are at `opener` and `closer`, each as the half-open token range
    [first, end)."""
    if closer == opener + 1:
        return []
    args: list[tuple[int, int]] = []
    start, depth = opener + 1, 0
    for j in range(opener + 1, closer):
        tok = toks[j]
        if tok.kind != "op":
            continue
        if tok.text in "([{":
            depth += 1
        elif tok.text in ")]}":
            depth -= 1
        elif tok.text == "," and depth == 0:
            args.append((start, j))
            start = j + 1
    args.append((start, closer))
    return args


def span_text(source: str, toks: list[Tok], first: int, end: int) -> str:
    """The source text of tokens [first, end), as written."""
    return source[toks[first].start : toks[end - 1].end]


def string_value(token: str) -> str | None:
    """The text of a plain `"…"` or `'…'` string token with no escapes in it, else None."""
    if len(token) >= 2 and token[0] in "\"'" and token[-1] == token[0] and "\\" not in token:
        return token[1:-1]
    return None
