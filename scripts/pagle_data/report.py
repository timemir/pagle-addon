"""The Field report parser (DATA-R116): the repo's one reader of the PAGLE-REPORT format, exactly as REP-R30–R33
define it and Core writes it. The importer, the triage Action and the generator all read reports through it.

A part is line 1 "PAGLE-REPORT 1", the header line, I, K and P rows (REP-R20–R22) and END. " # " outside double
quotes starts a comment (REP-R31); inside quotes, a backslash escapes ", \\ and n (REP-R32). Unknown key=value keys
and unknown row letters are ignored (REP-R31). A part fails, each problem naming its line, on DATA-R116's list: a
first line other than PAGLE-REPORT 1, a malformed header, a missing END (a truncated paste) or text after it, a row
with missing, extra or non-integer fields, a known key given twice, a value out of its bounds, t and m not together,
a t off its bucket, a P row's unquoted or empty text, bad locale or repeated item, a bad quote escape and two rows
with the same key (DATA-R121's, shared with pagle_data.observed).

Rows come out as pagle_data.observed's rows, so what the importer writes (observed_toml) is what the observed layer
reads. The parts of one report share its identity (DATA-R117: the header without part) and are joined in order; a
report with a part missing is incomplete (REP-R33, DATA-R116). report_field() takes the paste out of an issue body as
GitHub renders the issue form (DATA-R115).
"""

import re
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, replace

from pagle_data.errors import At, Problems
from pagle_data.observed import (
    DATA,
    FIELD_BOUNDS,
    LOCALE,
    REPORTER_KEY,
    CatchRow,
    Header,
    PoolTextRow,
    Report,
    Row,
    SkillRow,
    bucket_minute,
    bucket_text,
    duplicate_rows,
    rows_of,
)
from pagle_data.toml_reader import broken_bounds

_NOWHERE = At("")

# REP-R30: line 1 of every part. A changed meaning of anything existing bumps it (REP-R31).
FORMAT = "PAGLE-REPORT 1"
END = "END"

# The issue form's report field label (DATA-R115): GitHub renders the field under "### <label>".
REPORT_LABEL = "Report"

_PART = re.compile(r"([1-9][0-9]*)/([1-9][0-9]*)")
_INTEGER = re.compile(r"-?[0-9]+")
_ITEM_COUNT = re.compile(r"([0-9]+)x([0-9]+)")
# Each row's known key=value keys (REP-R20–R22); any other is ignored (REP-R31).
_I_KNOWN_KEYS = ("aura", "event", "t", "m")
_K_KNOWN_KEYS = ("casts", "away", "land", "lost")
_P_KNOWN_KEYS = ("casts",)
# An unknown row letter (REP-R31): one capital letter other than I, K and P.
_ROW_LETTER = re.compile(r"[A-Z]")
_ESCAPES = {'"': '"', "\\": "\\", "n": "\n"}


@dataclass(frozen=True)
class Identity:
    """A report's identity (DATA-R117): its header without part. The parts of one report share it."""

    addon: str
    data: str
    locale: str
    reporter: str
    parts: int

    @property
    def observed_header(self) -> Header:
        """The header reports/<reporter>.toml keeps for this identity: its addon, data and locale (DATA-R121)."""
        return Header(self.addon, self.data, self.locale)


@dataclass(frozen=True)
class PartHeader:
    """A part's header line (REP-R30): addon version, data (the content fingerprint's first 8 hex), locale, reporter
    key (REP-R36) and part n of parts."""

    addon: str
    data: str
    locale: str
    reporter: str
    part: int
    parts: int

    @property
    def identity(self) -> Identity:
        return Identity(self.addon, self.data, self.locale, self.reporter, self.parts)


@dataclass(frozen=True)
class Part:
    """One part as parsed from source (an issue, a file: what the problems name), its rows in the order written."""

    source: str
    header: PartHeader
    catches: tuple[CatchRow, ...]
    skills: tuple[SkillRow, ...]
    pool_texts: tuple[PoolTextRow, ...]

    @property
    def rows(self) -> tuple[Row, ...]:
        return rows_of(self)


@dataclass(frozen=True)
class FieldReport:
    """The parts found of one report, by identity, in part order. Its rows are the parts' joined in order."""

    identity: Identity
    parts: tuple[Part, ...]

    @property
    def missing(self) -> tuple[int, ...]:
        """The part numbers not found."""
        found = {part.header.part for part in self.parts}
        return tuple(n for n in range(1, self.identity.parts + 1) if n not in found)

    @property
    def complete(self) -> bool:
        """Every part was found (DATA-R116: a report with a part missing is incomplete)."""
        return not self.missing

    @property
    def catches(self) -> tuple[CatchRow, ...]:
        return tuple(row for part in self.parts for row in part.catches)

    @property
    def skills(self) -> tuple[SkillRow, ...]:
        return tuple(row for part in self.parts for row in part.skills)

    @property
    def pool_texts(self) -> tuple[PoolTextRow, ...]:
        return tuple(row for part in self.parts for row in part.pool_texts)

    @property
    def rows(self) -> tuple[Row, ...]:
        return rows_of(self)

    def observed(self, issues: Iterable[int]) -> Report:
        """The report as data/observed/reports/<reporter>.toml holds it (DATA-R121), imported from issues."""
        identity = self.identity
        return Report(
            identity.reporter, tuple(issues), identity.observed_header, self.catches, self.skills, self.pool_texts
        )


# Lines


class _LineError(Exception):
    """A line that can't be split into tokens: a bad quote escape or an unclosed quote (REP-R32)."""


@dataclass(frozen=True)
class _Token:
    text: str
    quoted: bool  # the whole token is one quoted string


def _tokens(line: str) -> list[_Token]:
    """The line's tokens, split on whitespace, up to a comment: " # " outside double quotes (REP-R31). Inside quotes,
    \\ escapes ", \\ and n (REP-R32)."""
    tokens: list[_Token] = []
    i, end = 0, len(line)
    while True:
        while i < end and line[i] in " \t":
            i += 1
        if i == end or (line[i] == "#" and (i + 1 == end or line[i + 1] in " \t")):
            return tokens
        text: list[str] = []
        starts_quoted, first_close = line[i] == '"', -1
        while i < end and line[i] not in " \t":
            if line[i] != '"':
                text.append(line[i])
                i += 1
                continue
            i += 1
            while True:
                if i == end:
                    raise _LineError("a quote isn't closed (REP-R32)")
                char = line[i]
                if char == '"':
                    i += 1
                    break
                if char == "\\":
                    escaped = line[i + 1] if i + 1 < end else ""
                    if escaped not in _ESCAPES:
                        raise _LineError(f"a bad quote escape '\\{escaped}': \\ escapes only \", \\ and n (REP-R32)")
                    text.append(_ESCAPES[escaped])
                    i += 2
                    continue
                text.append(char)
                i += 1
            first_close = i if first_close < 0 else first_close
        # Quoted: the token is one quoted string, its first closing quote ending it.
        tokens.append(_Token("".join(text), starts_quoted and first_close == i))


class _Row:
    """One row's tokens: its positional fields and its key=value keys, read with their problems at the row's line.
    Only a known key given twice is a problem: an unknown one is ignored however often it comes (REP-R31)."""

    def __init__(self, tokens: list[_Token], at: At, problems: Problems, known: Sequence[str]) -> None:
        self.at, self.problems, self.ok = at, problems, True
        self.fields: list[_Token] = []
        self.keys: dict[str, str] = {}
        for token in tokens[1:]:
            key, equals, value = token.text.partition("=")
            if token.quoted or not equals:
                self.fields.append(token)
            elif key in self.keys and key in known:
                self.fail(f"{key}= is given twice")
            else:
                self.keys[key] = value

    def fail(self, message: str) -> None:
        self.problems.add(self.at, message)
        self.ok = False

    def integer(self, name: str, text: str, field: str) -> int:
        """text as the integer field `field`, within its FIELD_BOUNDS; `name` is how a problem names it."""
        if not _INTEGER.fullmatch(text):
            self.fail(f"{name}: expected an integer, got '{text}'")
            return 0
        value = int(text)
        bounds = broken_bounds(value, *FIELD_BOUNDS[field])
        if bounds is not None:
            self.fail(f"{name}: expected an integer {bounds}, got {value}")
        return value

    def positional(self, shape: str, names: Sequence[str]) -> list[int] | None:
        """The leading integer fields, or None with a problem when one is missing."""
        if len(self.fields) < len(names):
            self.fail(f"missing fields: expected {shape} (REP-R20–R22)")
            return None
        return [self.integer(name, field.text, name) for name, field in zip(names, self.fields)]

    def no_more_fields(self, used: int) -> None:
        for token in self.fields[used:]:
            self.fail(f"unexpected field '{token.text}'")

    def key(self, name: str) -> int | None:
        if name not in self.keys:
            return None
        return self.integer(f"{name}=", self.keys[name], name)

    def required(self, name: str) -> int:
        if name not in self.keys:
            self.fail(f"missing field {name}= (REP-R21, REP-R22)")
            return 0
        return self.integer(f"{name}=", self.keys[name], name)

    def ids(self, name: str) -> tuple[int, ...]:
        if name not in self.keys:
            return ()
        return tuple(sorted(self.integer(f"{name}=", part, name) for part in self.keys[name].split(",")))


def _catch(row: _Row, reporter: str) -> CatchRow | None:
    """I <itemID> <areaID> <build> <count> [aura=…] [event=…] [t=HH:MM m=<month>] (REP-R20)."""
    numbers = row.positional("I <itemID> <areaID> <build> <count>", ("item", "area", "build", "count"))
    row.no_more_fields(4)
    auras, events = row.ids("aura"), row.ids("event")
    t: int | None = None
    if "t" in row.keys:
        t = bucket_minute(row.keys["t"])
        if t is None:
            row.fail(f"t=: expected the start of a 15-minute bucket, HH:MM, got '{row.keys['t']}' (REP-R20)")
    m = row.key("m")
    if ("t" in row.keys) != ("m" in row.keys):
        row.fail("t= and m= go together (REP-R20)")
    if numbers is None or not row.ok:
        return None
    item, area, build, count = numbers
    return CatchRow(item, area, build, count, auras, events, t, m, None, reporter, row.at)


def _skill(row: _Row, reporter: str) -> SkillRow | None:
    """K <areaID> <build> casts=<n> away=<n> [land=<skill>] [lost=<skill>] (REP-R21)."""
    numbers = row.positional("K <areaID> <build>", ("area", "build"))
    row.no_more_fields(2)
    casts, away = row.required("casts"), row.required("away")
    land, lost = row.key("land"), row.key("lost")
    if numbers is None or not row.ok:
        return None
    area, build = numbers
    return SkillRow(area, build, casts, away, land, lost, None, reporter, row.at)


def _pool_text(row: _Row) -> PoolTextRow | None:
    """P <areaID> <locale> "<text>" casts=<n> <itemID>x<count> … (REP-R22)."""
    shape = 'P <areaID> <locale> "<text>"'
    if len(row.fields) < 3:
        row.fail(f"missing fields: expected {shape} (REP-R22)")
        return None
    area = row.integer("area", row.fields[0].text, "area")
    locale, text = row.fields[1].text, row.fields[2]
    if not LOCALE.fullmatch(locale):
        row.fail(f"locale: expected a client locale such as enUS, got '{locale}'")
    if not text.quoted:
        row.fail(f"text: expected a quoted text, got '{text.text}' (REP-R22)")
    elif not text.text:
        row.fail("text: expected a non-empty text")  # Core drops only "": a blank text is a text (REP-R22)
    casts = row.required("casts")
    items: dict[int, int] = {}
    for token in row.fields[3:]:
        pair = _ITEM_COUNT.fullmatch(token.text)
        if pair is None:
            row.fail(f"expected <itemID>x<count>, got '{token.text}' (REP-R22)")
            continue
        item, count = row.integer("item", pair[1], "item"), row.integer("count", pair[2], "count")
        if item in items:
            row.fail(f"item {item} is listed twice")
        items[item] = count
    if not row.ok:
        return None
    return PoolTextRow(area, locale, text.text, casts, tuple(sorted(items.items())), None, row.at)


def _header(tokens: list[_Token]) -> PartHeader | str:
    """The header line's fields (REP-R30), or what's wrong with it."""
    shape = "addon <version> data <8 hex> locale <locale> reporter <8 hex> part <n>/<m>"
    tokens = [token for token in tokens if token.quoted or "=" not in token.text]  # unknown keys (REP-R31)
    names = [token.text for token in tokens[0::2]]
    if len(tokens) != 10 or names != ["addon", "data", "locale", "reporter", "part"]:
        return f"expected {shape}"
    addon, data, locale, reporter, part = (token.text for token in tokens[1::2])
    if not DATA.fullmatch(data):
        return f"data: expected 8 lowercase hex characters, got '{data}'"
    if not LOCALE.fullmatch(locale):
        return f"locale: expected a client locale such as enUS, got '{locale}'"
    if not REPORTER_KEY.fullmatch(reporter):
        return f"reporter: expected 8 lowercase hex characters, got '{reporter}' (REP-R36)"
    numbers = _PART.fullmatch(part)
    if numbers is None or int(numbers[1]) > int(numbers[2]):
        return f"part: expected <n>/<m> with n from 1 to m, got '{part}' (REP-R33)"
    return PartHeader(addon, data, locale, reporter, int(numbers[1]), int(numbers[2]))


def _lines(text: str) -> list[str]:
    """text's lines, CRLF or LF."""
    return [line.removesuffix("\r") for line in text.split("\n")]


def parse_part(text: str, source: str, problems: Problems) -> Part | None:
    """One part of a Field report (DATA-R116), or None with every problem found, each at its line of source. Blank
    lines are skipped, so "line 1" and the header are the first two lines with text; problems name the line as
    pasted."""
    start = len(problems.found)
    lines = [(number, line) for number, line in enumerate(_lines(text), 1) if line.strip()]

    def at(number: int) -> At:
        return At(source, f"line {number}")

    def tokens(number: int, line: str) -> list[_Token] | None:
        try:
            return _tokens(line)
        except _LineError as error:
            problems.add(at(number), str(error))
            return None

    number, line = lines[0] if lines else (1, "")
    first = tokens(number, line)
    if first is None:
        return None
    if [token.text for token in first] != FORMAT.split():
        problems.add(at(number), f"expected '{FORMAT}', got '{line.strip()}' (REP-R30)")
        return None
    number, line = lines[1] if len(lines) > 1 else (number + 1, "")
    second = tokens(number, line)
    header = _header(second) if second is not None else None
    if isinstance(header, str):
        problems.add(at(number), f"a malformed header: {header} (REP-R30)")
    reporter = header.reporter if isinstance(header, PartHeader) else ""

    catches: list[CatchRow] = []
    skills: list[SkillRow] = []
    pool_texts: list[PoolTextRow] = []
    ended = 0
    for number, line in lines[2:]:
        words = tokens(number, line)
        if not words:
            continue
        kind = words[0].text
        if ended:
            problems.add(at(number), f"text after END (line {ended}): paste each part into its own issue")
            break
        if kind == END and not words[0].quoted:
            if len(words) > 1:
                problems.add(at(number), "expected END alone (REP-R30)")
            ended = number
            continue
        if kind == "I":
            catch = _catch(_Row(words, at(number), problems, _I_KNOWN_KEYS), reporter)
            catches += [catch] if catch is not None else []
        elif kind == "K":
            skill = _skill(_Row(words, at(number), problems, _K_KNOWN_KEYS), reporter)
            skills += [skill] if skill is not None else []
        elif kind == "P":
            pool_text = _pool_text(_Row(words, at(number), problems, _P_KNOWN_KEYS))
            pool_texts += [pool_text] if pool_text is not None else []
        elif not _ROW_LETTER.fullmatch(kind):
            problems.add(at(number), f"expected a row (I, K or P) or END, got '{kind}'")
    if not ended:
        problems.add(at(lines[-1][0]), "no END after this line: the paste is truncated (REP-R30)")
    duplicate_rows((*catches, *skills, *pool_texts), problems)
    if len(problems.found) > start or not isinstance(header, PartHeader):
        return None
    return Part(source, header, tuple(catches), tuple(skills), tuple(pool_texts))


def join(parts: Iterable[Part], problems: Problems) -> list[FieldReport]:
    """The parts as reports, one per identity in the order first found, each with its parts in part order (REP-R33).
    A part found twice counts once when its rows are the same, and is a problem otherwise; so is a row key two parts
    share (DATA-R121)."""
    found: dict[Identity, dict[int, Part]] = {}
    for part in parts:
        numbered = found.setdefault(part.header.identity, {})
        earlier = numbered.get(part.header.part)
        if earlier is None:
            numbered[part.header.part] = part
        elif _rows(earlier) != _rows(part):
            number = f"{part.header.part}/{part.header.parts}"
            problems.add(At(part.source), f"part {number} again, with other rows than in {earlier.source}")
    reports = [
        FieldReport(identity, tuple(numbered[number] for number in sorted(numbered)))
        for identity, numbered in found.items()
    ]
    for report in reports:
        duplicate_rows(report.rows, problems)
    return reports


def _rows(part: Part) -> tuple[Row, ...]:
    """A part's rows, wherever they were read."""
    return tuple(replace(row, at=_NOWHERE) for row in part.rows)


# data/observed/reports/<reporter>.toml


def toml_string(text: str) -> str:
    """text as a TOML basic string."""
    escaped = []
    for char in text:
        if char in '"\\':
            escaped.append("\\" + char)
        elif char == "\n":
            escaped.append("\\n")
        elif char == "\t":
            escaped.append("\\t")
        elif ord(char) < 0x20 or ord(char) == 0x7F:
            escaped.append(f"\\u{ord(char):04x}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def _ints(values: Iterable[int]) -> str:
    return "[" + ", ".join(str(value) for value in values) + "]"


def observed_toml(report: Report) -> str:
    """report as data/observed/reports/<key>.toml (DATA-R121, the Data section's data/observed/ table): issues, the
    header, then [[i]], [[k]] and [[p]] rows in the order given, with REP-R20–R22's fields and any rejected mark.
    pagle_data.observed reads it back as the same rows."""
    lines = [f"issues = {_ints(report.issues)}"]
    if report.header is not None:
        header = report.header
        lines += ["", "[header]", f"addon = {toml_string(header.addon)}", f"data = {toml_string(header.data)}"]
        lines.append(f"locale = {toml_string(header.locale)}")
    for catch in report.catches:
        lines += ["", "[[i]]", f"item = {catch.item}", f"area = {catch.area}", f"build = {catch.build}"]
        lines.append(f"count = {catch.count}")
        lines += [f"aura = {_ints(catch.auras)}"] if catch.auras else []
        lines += [f"event = {_ints(catch.events)}"] if catch.events else []
        lines += [f"t = {toml_string(bucket_text(catch.t))}"] if catch.t is not None else []
        lines += [f"m = {catch.m}"] if catch.m is not None else []
        lines += [f"rejected = {toml_string(catch.rejected)}"] if catch.rejected is not None else []
    for skill in report.skills:
        lines += ["", "[[k]]", f"area = {skill.area}", f"build = {skill.build}", f"casts = {skill.casts}"]
        lines.append(f"away = {skill.away}")
        lines += [f"land = {skill.land}"] if skill.land is not None else []
        lines += [f"lost = {skill.lost}"] if skill.lost is not None else []
        lines += [f"rejected = {toml_string(skill.rejected)}"] if skill.rejected is not None else []
    for pool in report.pool_texts:
        lines += ["", "[[p]]", f"area = {pool.area}", f"locale = {toml_string(pool.locale)}"]
        lines += [f"text = {toml_string(pool.text)}", f"casts = {pool.casts}"]
        if pool.items:
            lines.append("items = { " + ", ".join(f"{item} = {count}" for item, count in pool.items) + " }")
        lines += [f"rejected = {toml_string(pool.rejected)}"] if pool.rejected is not None else []
    return "\n".join(lines) + "\n"


# The issue form


def report_field(body: str, label: str = REPORT_LABEL) -> str | None:
    """The report field's text in an issue body as GitHub renders the issue form (DATA-R115): the lines under
    "### <label>" up to the next field, without the code fence the form renders it in, blank lines around it
    dropped, LF line ends. None when the body has no such field."""
    lines = _lines(body)
    try:
        start = [line.strip() for line in lines].index(f"### {label}") + 1
    except ValueError:
        return None
    field: list[str] = []
    fenced = False
    for line in lines[start:]:
        if line.startswith("```"):
            fenced = not fenced
        elif line.startswith("### ") and not fenced:
            break
        field.append(line)
    while field and not field[0].strip():
        field.pop(0)
    while field and not field[-1].strip():
        field.pop()
    if field and field[0].startswith("```"):
        field.pop(0)
        if field and field[-1].strip() == "```":
            field.pop()
    while field and not field[0].strip():
        field.pop(0)
    while field and not field[-1].strip():
        field.pop()
    return "\n".join(field)
