"""The data/observed/ layer (DATA-R8 order 4): what was seen in-game. dev.toml holds the dev's reporter keys and own
facts (DATA-R122); reports/<reporterKey>.toml holds one reporter's imported Field report rows (DATA-R121), written
by M3's importer. Keys and types are the Data section's in docs/spec/content-data.md, the rows' fields REP-R20–R22's.
pooltext.toml is the dev's hand-kept map of hovered texts to pool types (DATA-R118): read here, strictly, but not an
observation; only the triage Action uses it.

observations() turns the layer into DATA-R45's observations: non-rejected I and K rows (DATA-R50) and dev facts,
each with its reporter (DATA-R46) and its areas mapped through the alias table (DATA-R34). P rows are kept here but
observe nothing. Nothing from this layer ships but the catalogue facts it implies (DATA-R65): pagle_data.confirmed
computes the observed pairs and confirmed flags (DATA-R47–R55).
"""

import re
from collections.abc import Collection, Iterable, Mapping
from dataclasses import dataclass, field, replace
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.toml_reader import (
    check_keys,
    describe,
    expect_ids,
    expect_int,
    expect_table,
    parse_id,
    read_toml,
)

OBSERVED = "data/observed/"
DEV = "data/observed/dev.toml"
REPORTS = "data/observed/reports"
POOLTEXT = "data/observed/pooltext.toml"

# What a pooltext.toml entry may map a text to besides a pool type ID (DATA-R118).
POOLTEXT_KINDS = ("bobber", "other")

# The one reporter every dev key and every dev fact counts as (DATA-R46).
DEV_REPORTER = "dev"

# Tunables: the minimum confirming build (DATA-R46, DATA-R57). 0 counts every Forever build.
MINIMUM_CONFIRMING_BUILD = 0

# A reporter key (REP-R36): FNV-1a 32-bit as 8 lowercase hex characters.
_REPORTER_KEY = re.compile(r"[0-9a-f]{8}")
# The header's data (REP-R30): the first 8 characters of the content fingerprint, lowercase hex.
_DATA = re.compile(r"[0-9a-f]{8}")
# A client locale as GetLocale() gives it, such as enUS or deDE.
_LOCALE = re.compile(r"[a-z]{2}[A-Z]{2}")
# t (REP-R20): the start of a 15-minute realm-time bucket, HH:MM.
_BUCKET = re.compile(r"([01][0-9]|2[0-3]):(00|15|30|45)")
# A window ID (DATA-R35): the six named windows, or event.<eventID>.
_WINDOW = re.compile(r"day|night|spring|summer|autumn|winter|event\.[1-9][0-9]*")

# A dev fact's kinds and the IDs each needs (DATA-R122).
FACT_IDS: dict[str, tuple[str, ...]] = {
    "pair": ("item", "area"),
    "gate": ("item", "window"),
    "window": ("window",),
    "weekly": ("event",),
    "skillBase": ("area",),
}
_FACT_ID_KEYS = ("item", "area", "window", "event")

# FNV-1a 32-bit (REP-R36): the offset basis and the prime.
_FNV_BASIS = 0x811C9DC5
_FNV_PRIME = 0x01000193


def reporter_key(log_id: str) -> str:
    """The reporter key of a log (REP-R36): FNV-1a 32-bit of PagleLog.logId's bytes, 8 lowercase hex characters,
    zero-padded. The key dev.toml's keys list for the dev's own logs (DATA-R122)."""
    hashed = _FNV_BASIS
    for byte in log_id.encode("utf-8"):
        hashed = ((hashed ^ byte) * _FNV_PRIME) & 0xFFFFFFFF
    return f"{hashed:08x}"


@dataclass(frozen=True)
class CatchRow:
    """An I row (REP-R20): count Catches of item in area on build, with the active listed auras and events
    (ascending) and, together or not at all, the 15-minute bucket's start t (minute of the realm day) and the realm
    month m. reporter is the file's reporter key as read, and DATA-R46's reporter once observations() has it."""

    item: int
    area: int
    build: int
    count: int
    auras: tuple[int, ...]
    events: tuple[int, ...]
    t: int | None
    m: int | None
    rejected: str | None
    reporter: str
    at: At


@dataclass(frozen=True)
class SkillRow:
    """A K row (REP-R21): Casts in area on build, those that got away, and the lowest landing and highest losing
    effective skill when there were such Casts. reporter as for CatchRow."""

    area: int
    build: int
    casts: int
    away: int
    land: int | None
    lost: int | None
    rejected: str | None
    reporter: str
    at: At


@dataclass(frozen=True)
class PoolTextRow:
    """A P row (REP-R22): a hovered text in area for a locale, the Casts it was hovered on, and the items caught on
    them as (itemID, total quantity), ascending. Kept (DATA-R118), never an observation (DATA-R45)."""

    area: int
    locale: str
    text: str
    casts: int
    items: tuple[tuple[int, int], ...]
    rejected: str | None
    at: At


@dataclass(frozen=True)
class Header:
    """A report file's latest header (DATA-R121): the addon version, data (REP-R30) and the locale."""

    addon: str
    data: str
    locale: str


@dataclass(frozen=True)
class Report:
    """reports/<key>.toml: one reporter's imported issues, latest header and rows (DATA-R121)."""

    key: str
    issues: tuple[int, ...]
    header: Header | None
    catches: tuple[CatchRow, ...]
    skills: tuple[SkillRow, ...]
    pool_texts: tuple[PoolTextRow, ...]


@dataclass(frozen=True)
class DevFact:
    """A [[fact]] in dev.toml (DATA-R122): one catalogue fact of kind on build, with the IDs its kind needs (the
    others None) and the dev's note."""

    kind: str
    build: int
    note: str
    item: int | None
    area: int | None
    window: str | None
    event: int | None
    at: At

    reporter = DEV_REPORTER


@dataclass(frozen=True)
class PoolTextEntry:
    """A [[text]] in pooltext.toml (DATA-R118): a hovered text in a locale, mapped to a pool type ID, bobber or
    other."""

    locale: str
    text: str
    pool: str
    at: At


@dataclass
class ObservedLayer:
    """data/observed/ as read: dev.toml's keys and facts, the report files by reporter key, and pooltext.toml's
    entries."""

    keys: tuple[str, ...] = ()
    facts: tuple[DevFact, ...] = ()
    reports: Mapping[str, Report] = field(default_factory=dict)
    pooltext: tuple[PoolTextEntry, ...] = ()


@dataclass(frozen=True)
class Observations:
    """DATA-R45's observations, each with its reporter (DATA-R46) and its areas through the alias table
    (DATA-R34), on every build. Rejected rows are left out (DATA-R50)."""

    catches: tuple[CatchRow, ...]
    skills: tuple[SkillRow, ...]
    facts: tuple[DevFact, ...]

    def confirming(self, minimum_build: int = MINIMUM_CONFIRMING_BUILD) -> "Observations":
        """Only the observations that count for confirming, for contradicting and for an observed pair joining a
        list: those on builds at or above the minimum confirming build (DATA-R46)."""
        return Observations(
            tuple(row for row in self.catches if row.build >= minimum_build),
            tuple(row for row in self.skills if row.build >= minimum_build),
            tuple(fact for fact in self.facts if fact.build >= minimum_build),
        )

    def within(self, known: Collection[int]) -> "Observations":
        """Only the observations whose area is in known (data/db2/areas.csv's IDs), or that name no area: an area
        missing from the slice stays out of the catalogue (DATA-R33)."""
        return Observations(
            tuple(row for row in self.catches if row.area in known),
            tuple(row for row in self.skills if row.area in known),
            tuple(fact for fact in self.facts if fact.area is None or fact.area in known),
        )

    def reporters(self) -> set[str]:
        """Every reporter of these observations (DATA-R46)."""
        found = {row.reporter for row in self.catches} | {row.reporter for row in self.skills}
        return found | {fact.reporter for fact in self.facts}

    def items(self) -> set[int]:
        """The items these observations bring into the item universe (DATA-R15): catch rows' and dev facts'."""
        found = {row.item for row in self.catches}
        return found | {fact.item for fact in self.facts if fact.item is not None}

    def missing_areas(self, known: Collection[int]) -> dict[int, list[At]]:
        """Each observed area not in known (data/db2/areas.csv's IDs), with where it was seen (DATA-R33)."""
        seen: list[tuple[int, At]] = [(row.area, row.at / "area") for row in self.catches + self.skills]
        seen += [(fact.area, fact.at / "area") for fact in self.facts if fact.area is not None]
        missing: dict[int, list[At]] = {}
        for area, at in seen:
            if area not in known:
                missing.setdefault(area, []).append(at)
        return dict(sorted(missing.items()))


def observations(layer: ObservedLayer, aliases: Mapping[int, int]) -> Observations:
    """The layer's observations (DATA-R45): non-rejected I and K rows (DATA-R50) and the dev facts. A row's reporter
    is its file's key, or dev for a key in dev.toml's keys (DATA-R46); every area goes through aliases, area →
    baseline area (DATA-R34)."""

    def reporter(key: str) -> str:
        return DEV_REPORTER if key in layer.keys else key

    def area(area_id: int) -> int:
        return aliases.get(area_id, area_id)

    catches: list[CatchRow] = []
    skills: list[SkillRow] = []
    for report in layer.reports.values():
        for row in report.catches:
            if row.rejected is None:
                catches.append(replace(row, area=area(row.area), reporter=reporter(row.reporter)))
        for skill in report.skills:
            if skill.rejected is None:
                skills.append(replace(skill, area=area(skill.area), reporter=reporter(skill.reporter)))
    facts = tuple(fact if fact.area is None else replace(fact, area=area(fact.area)) for fact in layer.facts)
    return Observations(tuple(catches), tuple(skills), facts)


# Reading


def _expect_string(
    value: object, at: At, problems: Problems, pattern: re.Pattern[str] | None = None, *, blank: bool = False
) -> str | None:
    """value as a non-empty string (matching pattern, when given), or None with a problem. A blank one (only
    whitespace) is a problem unless blank is set."""
    if not isinstance(value, str):
        problems.add(at, f"expected a string, got {describe(value)}")
        return None
    if not (value if blank else value.strip()):
        problems.add(at, "expected a non-empty string")
        return None
    if pattern is not None and not pattern.fullmatch(value):
        problems.add(at, f"expected {pattern.pattern}, got '{value}'")
        return None
    return value


def _tables(
    document: Mapping[str, object], key: str, at: At, problems: Problems
) -> list[tuple[At, Mapping[str, object]]]:
    """document's [[key]] array of tables, each with its At (key[i])."""
    entries = document.get(key, [])
    if not isinstance(entries, list):
        problems.add(at / key, f"expected an array of tables ([[{key}]]), got {describe(entries)}")
        return []
    found: list[tuple[At, Mapping[str, object]]] = []
    for index, entry in enumerate(entries):
        entry_at = At(at.file, f"{at.path + '.' if at.path else ''}{key}[{index}]")
        table = expect_table(entry, entry_at, problems)
        if table is not None:
            found.append((entry_at, table))
    return found


class _Fields:
    """One table's fields, read with their problems; ok is False once any field was bad."""

    def __init__(self, table: Mapping[str, object], at: At, problems: Problems) -> None:
        self.table, self.at, self.problems, self.ok = table, at, problems, True

    def number(self, key: str, minimum: int | None, maximum: int | None = None) -> int | None:
        if key not in self.table:
            return None  # check_keys reports a missing required key
        value = expect_int(self.table[key], self.at / key, self.problems, minimum=minimum, maximum=maximum)
        self.ok = self.ok and value is not None
        return value

    def text(self, key: str, pattern: re.Pattern[str] | None = None, *, blank: bool = False) -> str | None:
        if key not in self.table:
            return None
        value = _expect_string(self.table[key], self.at / key, self.problems, pattern, blank=blank)
        self.ok = self.ok and value is not None
        return value

    def ids(self, key: str) -> tuple[int, ...]:
        if key not in self.table:
            return ()
        value = expect_ids(self.table[key], self.at / key, self.problems)
        self.ok = self.ok and value is not None
        return tuple(sorted(value or []))

    def has(self, *keys: str) -> bool:
        return self.ok and all(key in self.table for key in keys)


_I_KEYS = ("item", "area", "build", "count")
_K_KEYS = ("area", "build", "casts", "away")
_P_KEYS = ("area", "locale", "text", "casts")


def _catch_row(table: Mapping[str, object], at: At, key: str, problems: Problems) -> CatchRow | None:
    check_keys(table, at, problems, required=_I_KEYS, optional=("aura", "event", "t", "m", "rejected"))
    fields = _Fields(table, at, problems)
    item, area = fields.number("item", 1), fields.number("area", 1)
    build, count = fields.number("build", 0), fields.number("count", 1)
    auras, events = fields.ids("aura"), fields.ids("event")
    bucket, month = fields.text("t", _BUCKET), fields.number("m", 1, 12)
    rejected = fields.text("rejected")
    if ("t" in table) != ("m" in table):
        problems.add(at, "t and m go together (REP-R20)")
        return None
    if not fields.has(*_I_KEYS) or item is None or area is None or build is None or count is None:
        return None
    t = None if bucket is None else int(bucket[:2]) * 60 + int(bucket[3:])
    return CatchRow(item, area, build, count, auras, events, t, month, rejected, key, at)


def _skill_row(table: Mapping[str, object], at: At, key: str, problems: Problems) -> SkillRow | None:
    check_keys(table, at, problems, required=_K_KEYS, optional=("land", "lost", "rejected"))
    fields = _Fields(table, at, problems)
    area, build = fields.number("area", 1), fields.number("build", 0)
    casts, away = fields.number("casts", 1), fields.number("away", 0)
    land, lost = fields.number("land", None), fields.number("lost", None)  # effective skill, maybe < 0 (REP-R21)
    rejected = fields.text("rejected")
    if not fields.has(*_K_KEYS) or area is None or build is None or casts is None or away is None:
        return None
    return SkillRow(area, build, casts, away, land, lost, rejected, key, at)


def _pool_items(value: object, at: At, problems: Problems) -> tuple[tuple[int, int], ...] | None:
    """A P row's items: an inline table of itemID = total quantity."""
    table = expect_table(value, at, problems)
    if table is None:
        return None
    items: list[tuple[int, int]] = []
    ok = True
    for key, count in table.items():
        item = parse_id(key, at / key, problems)
        quantity = expect_int(count, at / key, problems, minimum=1)
        if item is None or quantity is None:
            ok = False
        else:
            items.append((item, quantity))
    return tuple(sorted(items)) if ok else None


def _pool_text_row(table: Mapping[str, object], at: At, problems: Problems) -> PoolTextRow | None:
    check_keys(table, at, problems, required=_P_KEYS, optional=("items", "rejected"))
    fields = _Fields(table, at, problems)
    area, casts = fields.number("area", 1), fields.number("casts", 1)
    locale, text = fields.text("locale", _LOCALE), fields.text("text", blank=True)  # a hovered text (REP-R22)
    rejected = fields.text("rejected")
    items = _pool_items(table["items"], at / "items", problems) if "items" in table else ()
    if not fields.has(*_P_KEYS) or items is None or area is None or casts is None or locale is None or text is None:
        return None
    return PoolTextRow(area, locale, text, casts, items, rejected, at)


def _header(value: object, at: At, problems: Problems) -> Header | None:
    table = expect_table(value, at, problems)
    if table is None:
        return None
    check_keys(table, at, problems, required=("addon", "data", "locale"), optional=())
    fields = _Fields(table, at, problems)
    addon, data, locale = fields.text("addon"), fields.text("data", _DATA), fields.text("locale", _LOCALE)
    if addon is None or data is None or locale is None:
        return None
    return Header(addon, data, locale)


def row_key(row: CatchRow | SkillRow | PoolTextRow) -> tuple[object, ...]:
    """A row's key (DATA-R121), led by its kind: I by (item, area, build, auras, events, t, m), K by (area, build), P
    by (area, locale, text). The one definition of a duplicate row, shared by this reader and the Field report
    parser (DATA-R116), so the generator, the importer and the triage Action agree on it."""
    if isinstance(row, CatchRow):
        return ("I", row.item, row.area, row.build, row.auras, row.events, row.t, row.m)
    if isinstance(row, SkillRow):
        return ("K", row.area, row.build)
    return ("P", row.area, row.locale, row.text)


def duplicate_rows(rows: Iterable[CatchRow | SkillRow | PoolTextRow], problems: Problems) -> None:
    """DATA-R121: one row per row key. Each row whose key an earlier row has is a problem at the later row, naming
    the earlier one's place, and its file (or issue) when that is another."""
    first: dict[tuple[object, ...], At] = {}
    for row in rows:
        key = row_key(row)
        if key in first:
            earlier = first[key].path if first[key].file == row.at.file else str(first[key])
            problems.add(row.at, f"the same row key as {earlier} (DATA-R121)")
        else:
            first[key] = row.at


def _read_report(root: Path, file: str, key: str, problems: Problems) -> Report | None:
    document = read_toml(root, file, problems)
    if document is None:
        return None
    at = At(file)
    check_keys(document, at, problems, required=("issues", "header"), optional=("i", "k", "p"))
    issues = expect_ids(document["issues"], at / "issues", problems) if "issues" in document else []
    header = _header(document["header"], at / "header", problems) if "header" in document else None
    catches = [_catch_row(table, row_at, key, problems) for row_at, table in _tables(document, "i", at, problems)]
    skills = [_skill_row(table, row_at, key, problems) for row_at, table in _tables(document, "k", at, problems)]
    pool_texts = [_pool_text_row(table, row_at, problems) for row_at, table in _tables(document, "p", at, problems)]
    return _report(key, issues or [], header, catches, skills, pool_texts, problems)


def _report(
    key: str,
    issues: list[int],
    header: Header | None,
    catches: list[CatchRow | None],
    skills: list[SkillRow | None],
    pool_texts: list[PoolTextRow | None],
    problems: Problems,
) -> Report:
    """The rows read, each kept once per row key (DATA-R121)."""
    i_rows = tuple(row for row in catches if row is not None)
    k_rows = tuple(row for row in skills if row is not None)
    p_rows = tuple(row for row in pool_texts if row is not None)
    duplicate_rows((*i_rows, *k_rows, *p_rows), problems)
    return Report(key, tuple(issues), header, i_rows, k_rows, p_rows)


def _read_reports(root: Path, problems: Problems) -> dict[str, Report]:
    """reports/<reporterKey>.toml, each file named by its reporter key (REP-R36). The directory may be missing: M2
    commits no report."""
    directory = root / REPORTS
    if not directory.is_dir():
        return {}
    reports: dict[str, Report] = {}
    for path in sorted(directory.iterdir()):
        file = f"{REPORTS}/{path.name}"
        if not (path.is_file() and path.suffix == ".toml" and _REPORTER_KEY.fullmatch(path.stem)):
            problems.add(At(file), "not a report file: expected <reporterKey>.toml, the key 8 lowercase hex (REP-R36)")
            continue
        report = _read_report(root, file, path.stem, problems)
        if report is not None:
            reports[path.stem] = report
    return reports


def _read_fact(table: Mapping[str, object], at: At, problems: Problems) -> DevFact | None:
    kind = _expect_string(table["kind"], at / "kind", problems) if "kind" in table else None
    if kind is not None and kind not in FACT_IDS:
        problems.add(at / "kind", f"expected one of {', '.join(FACT_IDS)}, got '{kind}'")
        kind = None
    needed = FACT_IDS[kind] if kind is not None else ()
    optional = needed if kind is not None else _FACT_ID_KEYS  # an unknown kind: its ID keys can't be judged
    check_keys(table, at, problems, required=("kind", "build", "note", *needed), optional=optional)
    fields = _Fields(table, at, problems)
    build, note = fields.number("build", 1), fields.text("note")
    item, area, event = fields.number("item", 1), fields.number("area", 1), fields.number("event", 1)
    window = fields.text("window", _WINDOW)
    if kind is None or build is None or note is None or not fields.has(*needed):
        return None
    return DevFact(kind, build, note, item, area, window, event, at)


def _read_dev(root: Path, layer: ObservedLayer, problems: Problems) -> None:
    document = read_toml(root, DEV, problems)
    if document is None:
        return
    at = At(DEV)
    check_keys(document, at, problems, required=("keys",), optional=("fact",))
    keys: list[str] = []
    value = document.get("keys", [])
    if not isinstance(value, list):
        problems.add(at / "keys", f"expected an array of reporter keys, got {describe(value)}")
    else:
        for index, key in enumerate(value):
            key_at = At(DEV, f"keys[{index}]")
            read = _expect_string(key, key_at, problems, _REPORTER_KEY)
            if read is not None and read in keys:
                problems.add(key_at, f"'{read}' is listed twice")
            elif read is not None:
                keys.append(read)
    facts = [_read_fact(table, fact_at, problems) for fact_at, table in _tables(document, "fact", at, problems)]
    layer.keys, layer.facts = tuple(keys), tuple(fact for fact in facts if fact is not None)


def _read_pooltext(root: Path, problems: Problems) -> tuple[PoolTextEntry, ...]:
    """pooltext.toml's entries (DATA-R118), each (locale, text) once. A missing file has none: the dev keeps it by
    hand. Which pool types exist is pools.toml's, so check_pooltext judges pool once both are read."""
    if not (root / POOLTEXT).is_file():
        return ()
    document = read_toml(root, POOLTEXT, problems)
    if document is None:
        return ()
    at = At(POOLTEXT)
    check_keys(document, at, problems, required=(), optional=("text",))
    entries: list[PoolTextEntry] = []
    seen: set[tuple[str, str]] = set()
    for entry_at, table in _tables(document, "text", at, problems):
        check_keys(table, entry_at, problems, required=("locale", "text", "pool"), optional=())
        fields = _Fields(table, entry_at, problems)
        locale, text, pool = fields.text("locale", _LOCALE), fields.text("text", blank=True), fields.text("pool")
        if locale is None or text is None or pool is None:
            continue
        if (locale, text) in seen:
            problems.add(entry_at, f"({locale}, '{text}') is already mapped: one pool per text and locale (DATA-R118)")
            continue
        seen.add((locale, text))
        entries.append(PoolTextEntry(locale, text, pool, entry_at))
    return tuple(entries)


def check_pooltext(entries: Iterable[PoolTextEntry], pool_types: Collection[str], problems: Problems) -> None:
    """DATA-R118: each entry's pool is a pool type ID of pools.toml, bobber or other."""
    for entry in entries:
        if entry.pool not in pool_types and entry.pool not in POOLTEXT_KINDS:
            problems.add(
                entry.at / "pool",
                f"'{entry.pool}' is no pool type in data/forever/pools.toml, nor bobber or other (DATA-R118)",
            )


def read_observed(root: Path, problems: Problems) -> ObservedLayer:
    """The layer under root/data/observed/: dev.toml (required), any report files and pooltext.toml, if any. Each
    problem found goes into problems; what was read is returned either way, and the caller must not use it while
    there are problems."""
    layer = ObservedLayer()
    _read_dev(root, layer, problems)
    layer.reports = _read_reports(root, problems)
    layer.pooltext = _read_pooltext(root, problems)
    return layer
