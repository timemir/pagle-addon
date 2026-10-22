"""scripts/propose-events.py's command line (DATA-R99): drafts candidate Hunt Event files from one zone, or two zones of
one band, for people to curate (hunts.md › The 1.0 event pool, #281). It reads the committed data, writes the drafts
outside data/ and never commits; nothing it writes ships until people have curated it and written its lore.

Each draft is built around one of the zones' top Species and combines 3-4 of the four Hunt shapes (hunts.md › The
1.0 event pool): a Haul (species.any), a Named fish (the draft's Species), Quality (quality.uncommon, when the zones
list an uncommon item) and a Timed one (a Haul or the Named fish, open at night, by day or in a 3-hour span at dusk),
never more than one Timed. No draft has a minBand: a Size band needs the Reach (#337), so a size Hunt is authored by
hand, for a fish its players will have caught a lot of (HNT-R14). Each tier is the count that fishing there takes about
45 minutes, 2 hours and 4 hours to reach at the draft catch rate (Tunables), rounded to a friendly number.

The loot shares come from the baseline's chances (DATA-R9), read here and nowhere else in the generator: they only
suggest tiers that people curate, and no chance reaches a generated file (DATA-R4). Defaults chosen in #298, where
DATA-R99 is silent:
- an area's shares follow VMaNGOS's loot rules: a positive chance is a percentage of Catches, the rows at 0 split
  what the positive ones leave, a negative (quest) chance never counts, and a reference row's share is split among
  its table's items the same way; only items on the area's catch list count (DATA-R26);
- a gated catch counts its share times its window's least open share of a 72-hour run, and a season-gated one not at
  all, since a run's dates aren't known (as DATA-R99's closed-stretch check reads conditions);
- a Hunt's share is its mean over the zones' areas (each zone and subzone with a loot table, alike): fishing round
  the zones, since a one-row subzone table would otherwise set the pace;
- the top 3 Species with a 45-minute tier of at least 1 get a draft each; a Legend is never a Named fish;
- a Timed span is the night or day window's, or 18:00-21:00 (dusk); a tier below 20 rounds to a whole number, above
  to the nearest 5; drafts go to a dated folder under the system temp directory unless --out says otherwise.
"""

import argparse
import csv
import math
import re
import sys
import tempfile
import unicodedata
from collections.abc import Collection, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from pagle_data.baseline import AREA_LOOT, BASELINE
from pagle_data.confirmed import zone_of
from pagle_data.db2 import AREAS
from pagle_data.errors import DataError
from pagle_data.events import (
    BAND_KIND,
    MAX_ZONES,
    MIN_HUNTS,
    MIN_ZONES,
    PUSHED_PREFIX,
    RUN_MINUTES,
    band_of,
    run_openness,
)
from pagle_data.files import write_atomic
from pagle_data.generate import Layers, read_layers
from pagle_data.hunts import QUALITY_UNCOMMON, SPECIES_ANY, hunt_classes

PROG = "propose-events"
REFERENCE_LOOT = f"{BASELINE}/reference_loot.csv"

# Tunables (DATA-R99): the draft tier times in minutes, and the draft catch rate (#279's baseline).
TIER_MINUTES = (45, 120, 240)
CATCHES_PER_HOUR = 180
# Defaults chosen in #298: drafts per call (one per top Species), the rounding, the Timed spans, the folder.
TOP_SPECIES = 3
WHOLE_BELOW = 20
ROUND_TO = 5
DUSK = [[1080, 1260]]  # 18:00-21:00 realm time, a 3-hour span
SPAN_WINDOWS = ("night", "day")
DRAFTS_FOLDER = "pagle-event-drafts-{:%Y-%m-%d-%H%M%S}"
# The lore a draft leaves for people to write: a { or } fails the Hunts lore check (DATA-R105, DATA-R107) until then.
TODO_EVENT_NAME = "{TODO event name}"
TODO_EVENT_NOTE = "{TODO event note}"
TODO_HUNT_NAME = "{TODO Hunt name}"


def friendly(need: float) -> int:
    """A tier from a need: below 20 a whole number, at least 1, else the nearest 5, halves up (#298)."""
    if need < WHOLE_BELOW:
        return max(1, math.floor(need + 0.5))
    return ROUND_TO * math.floor(need / ROUND_TO + 0.5)


def _split(rows: Sequence[tuple[object, float]]) -> dict[object, float]:
    """One loot table's shares of Catches by key, as VMaNGOS rolls it: a positive chance is a percentage, the rows at
    0 split what the positive ones leave, a negative (quest) chance never counts."""
    given = sum(chance for _, chance in rows if chance > 0)
    zeros = sum(1 for _, chance in rows if chance == 0)
    rest = max(0.0, 100 - given) / zeros if zeros else 0.0
    shares: dict[object, float] = {}
    for key, chance in rows:
        if chance >= 0:
            shares[key] = shares.get(key, 0.0) + (chance if chance > 0 else rest) / 100
    return shares


def _csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def loot_shares(root: Path) -> dict[int, dict[int, float]]:
    """Each baseline area's items' shares of Catches (DATA-R9's area_loot.csv and reference_loot.csv chances), every
    row counted whatever its event: the catch list's gate applies it (_area_shares)."""
    tables: dict[int, list[tuple[object, float]]] = {}
    for row in _csv_rows(root / REFERENCE_LOOT):
        tables.setdefault(int(row["ref"]), []).append((int(row["item"]), float(row["chance"])))
    references = {ref: _split(rows) for ref, rows in tables.items()}
    areas: dict[int, list[tuple[object, float]]] = {}
    for row in _csv_rows(root / AREA_LOOT):
        key: object = ("ref", int(row["ref"])) if row["item"] == "" else int(row["item"])
        areas.setdefault(int(row["area"]), []).append((key, float(row["chance"])))
    shares: dict[int, dict[int, float]] = {}
    for area, rows in areas.items():
        found: dict[int, float] = {}
        for key, share in _split(rows).items():
            if isinstance(key, tuple):
                for item, inner in references.get(int(key[1]), {}).items():
                    assert isinstance(item, int)
                    found[item] = found.get(item, 0.0) + share * inner
            else:
                assert isinstance(key, int)
                found[key] = found.get(key, 0.0) + share
        shares[area] = found
    return shares


def _open_share(spec: Mapping[str, object], layers: Layers) -> float:
    """A condition spec's least open share of a 72-hour run (DATA-R99's reading: time and weekly events); 0 for a
    season, which a run's unknown dates can't promise."""
    if "season" in spec:
        return 0.0
    return run_openness(spec, layers.forever.events).least_open / RUN_MINUTES


@dataclass(frozen=True)
class Waters:
    """The zones asked for: the shares of Catches by item of each of their areas with a loot share, each gated catch
    times its window's open share, only the items each catch list holds, and which items are gated somewhere there."""

    zones: tuple[int, ...]
    shares: dict[int, dict[int, float]]
    gated: frozenset[int]

    def share(self, members: Collection[int]) -> float:
        """The share of Catches that are members, its mean over the areas (fishing round the zones)."""
        totals = [sum(share for item, share in found.items() if item in members) for found in self.shares.values()]
        return sum(totals) / len(totals) if totals else 0.0


def _waters(layers: Layers, zones: Sequence[int], base: Mapping[int, Mapping[int, float]]) -> Waters:
    areas = layers.db2.areas
    shares: dict[int, dict[int, float]] = {}
    gated: set[int] = set()
    for area, catches in layers.catch_lists.lists.items():
        if zone_of(areas, area) not in zones:
            continue
        found: dict[int, float] = {}
        for catch in catches:
            share = base.get(area, {}).get(catch.item, 0.0)
            if catch.window is not None:
                gated.add(catch.item)
                share *= _open_share(layers.windows.get(catch.window, {"season": []}), layers)
            if share > 0:
                found[catch.item] = share
        if found:
            shares[area] = found
    return Waters(tuple(zones), shares, frozenset(gated))


@dataclass(frozen=True)
class Target:
    """What a draft Hunt counts: a class, or a Species with its items; its name for the curator."""

    label: str
    members: frozenset[int]
    species: int | None = None
    class_id: str | None = None


@dataclass(frozen=True)
class DraftHunt:
    """A draft [[hunt]]: its ID, shape, target, share of Catches, tiers, Timed span and open share."""

    id: str
    shape: str
    target: Target
    share: float
    tiers: tuple[int, ...]
    span: str | None = None
    time: list[list[int]] | None = None
    open_share: float = 1.0

    @property
    def rate(self) -> float:
        """Its Catches a minute, fishing there at the draft catch rate."""
        return CATCHES_PER_HOUR / 60 * self.share * self.open_share

    def minutes(self) -> list[int]:
        """Each tier's expected minutes of fishing."""
        return [round(tier / self.rate) for tier in self.tiers]


@dataclass
class Draft:
    id: str
    zones: tuple[int, ...]
    tags: list[str]
    hunts: list[DraftHunt] = field(default_factory=list)


def tiers_for(rate: float) -> tuple[int, ...]:
    """The tiers that take about TIER_MINUTES at rate Catches a minute, friendly and strictly ascending (DATA-R88)."""
    tiers: list[int] = []
    for minutes in TIER_MINUTES:
        tier = friendly(rate * minutes)
        tiers.append(tier if not tiers or tier > tiers[-1] else tiers[-1] + 1)
    return tuple(tiers)


def _reachable(share: float) -> bool:
    """Whether a share gives a 45-minute tier of at least 1 at the draft catch rate."""
    return CATCHES_PER_HOUR / 60 * share * TIER_MINUTES[0] >= 1


def _slug(name: str, fallback: str) -> str:
    """An ID part from an enUS name: lowercase letters and digits joined by _ ([%w_]+, DATA-R97)."""
    plain = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii").lower()
    slug = "_".join(re.findall(r"[a-z0-9]+", plain))
    return slug or fallback


def _hunt(
    draft_id: str,
    shape: str,
    target: Target,
    share: float,
    *,
    span: str | None = None,
    time: list[list[int]] | None = None,
    open_share: float = 1.0,
) -> DraftHunt:
    tiers = tiers_for(CATCHES_PER_HOUR / 60 * share * open_share)
    return DraftHunt(f"{draft_id}_{shape}", shape, target, share, tiers, span, time, open_share)


def _spans(layers: Layers) -> list[tuple[str, list[list[int]]]]:
    """The Timed spans in turn: the night and day windows' time, then dusk, each with its tag (DATA-R97)."""
    spans: list[tuple[str, list[list[int]]]] = []
    for window in SPAN_WINDOWS:
        time = layers.windows.get(window, {}).get("time")
        if isinstance(time, list):
            spans.append((window, [list(span) for span in time]))
    spans.append(("dusk", DUSK))
    return spans


def propose(
    layers: Layers, zones: Sequence[int], base: Mapping[int, Mapping[int, float]]
) -> tuple[list[Draft], list[str]]:
    """The drafts for zones (already checked): one per top Species, each of 3-4 Hunts (DATA-R99); and a note for each
    shape the zones list but left out of every draft, too rare for a 45-minute tier."""
    waters = _waters(layers, zones, base)
    items = layers.items
    names = {item: row.name for item, row in layers.db2.items.items()}
    classes = hunt_classes(layers.hunts, items, layers.lock.classes)
    listed = {item for found in waters.shares.values() for item in found}
    by_species: dict[int, set[int]] = {}
    for item, record in items.items():
        species = record.get("species")
        if isinstance(species, int) and record.get("legend") is not True:
            by_species.setdefault(species, set()).add(item)
    species_targets = [
        Target(f"species {species} ({names.get(species, 'unnamed')})", frozenset(members), species=species)
        for species, members in sorted(by_species.items())
        if members & listed
    ]
    ranked = sorted(species_targets, key=lambda target: (-waters.share(target.members), target.species or 0))
    haul = Target(SPECIES_ANY, frozenset(classes.get(SPECIES_ANY, {})), class_id=SPECIES_ANY)
    quality = Target(QUALITY_UNCOMMON, frozenset(classes.get(QUALITY_UNCOMMON, {})), class_id=QUALITY_UNCOMMON)
    zone_part = "_".join(_slug(layers.db2.areas[zone].name, f"zone{zone}") for zone in zones)
    if zone_part.startswith(PUSHED_PREFIX):
        zone_part = f"z{zone_part}"  # DATA-R97: p_ is kept for pushed events
    spans = _spans(layers)
    tags = layers.events.tags
    drafts: list[Draft] = []
    named = [target for target in ranked if _reachable(waters.share(target.members))][:TOP_SPECIES]
    for index, target in enumerate(named):
        assert target.species is not None
        species_name = re.sub(r"^raw_", "", _slug(names.get(target.species, ""), f"species{target.species}"))
        draft_id = f"{zone_part}_{species_name}"
        draft = Draft(draft_id, tuple(zones), [])
        draft.hunts.append(_hunt(draft_id, "haul", haul, waters.share(haul.members)))
        draft.hunts.append(_hunt(draft_id, "named", target, waters.share(target.members)))
        if _reachable(waters.share(quality.members)):
            draft.hunts.append(_hunt(draft_id, "quality", quality, waters.share(quality.members)))
        span, time = spans[index % len(spans)]
        timed_target = target if index % 2 == 1 and not target.members & waters.gated else haul
        open_share = _open_share({"time": time}, layers)
        share = waters.share(timed_target.members)
        if _reachable(share * open_share):
            draft.hunts.append(
                _hunt(draft_id, "timed", timed_target, share, span=span, time=time, open_share=open_share)
            )
            if span in tags and tags[span] != BAND_KIND:
                draft.tags.append(span)
        if len(draft.hunts) >= MIN_HUNTS:
            drafts.append(draft)
    notes: list[str] = []
    rare = waters.share(quality.members)
    if 0 < rare and not _reachable(rare):
        what = f"{QUALITY_UNCOMMON} is {rare * 100:.1f}% of Catches there, too few for a 45-minute tier"
        notes.append(f"no Quality Hunt: {what} at {CATCHES_PER_HOUR} Catches an hour")
    return drafts, notes


def _toml_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _toml_list(values: Sequence[object]) -> str:
    return "[" + ", ".join(_toml_list(value) if isinstance(value, list) else str(value) for value in values) + "]"


def _shape(hunt: DraftHunt) -> str:
    names = {"haul": "Haul", "named": "Named fish", "quality": "Quality"}
    return f"Timed ({hunt.span})" if hunt.shape == "timed" else names[hunt.shape]


def hunt_line(hunt: DraftHunt) -> str:
    """A draft Hunt's line for the curator: its shape, target, share, tiers and each tier's expected minutes."""
    opened = f", open {round(hunt.open_share * 100)}% of a run" if hunt.span is not None else ""
    tiers = " / ".join(str(tier) for tier in hunt.tiers)
    minutes = " / ".join(str(minutes) for minutes in hunt.minutes())
    share = f"{hunt.share * 100:.1f}% of Catches"
    return f"{hunt.id}: {_shape(hunt)}, {hunt.target.label}, {share}{opened}: tiers {tiers}, {minutes} min"


def draft_toml(draft: Draft, where: str) -> str:
    """A draft as an <event-id>.toml (DATA-R97): skill left out for the generator to work out, the lore TODO."""
    lines = [
        f"# A draft Hunt Event from scripts/propose-events.py (DATA-R99) for {where}; not curated yet.",
        "# Curate it before it ships (hunts.md › The 1.0 event pool): keep 3-5 Hunts, adjust the tiers, add tags, and",
        "# write the name, the note and each Hunt's name over the {TODO ...} text, which fails the Hunts lore check",
        "# (DATA-R107) until then. Check it with scripts/check-event.py, then copy it to data/hunts/events/.",
        f"# Each Hunt's expected minutes per tier at {CATCHES_PER_HOUR} Catches an hour (Tunables):",
        *(f"#   {hunt_line(hunt)}" for hunt in draft.hunts),
        "",
        "[event]",
        f"id = {_toml_string(draft.id)}",
        f"zones = {_toml_list(list(draft.zones))}",
        "tags = [" + ", ".join(_toml_string(tag) for tag in draft.tags) + "]",
        f"name = {_toml_string(TODO_EVENT_NAME)}",
        f"note = {_toml_string(TODO_EVENT_NOTE)}",
    ]
    for hunt in draft.hunts:
        lines += ["", "[[hunt]]", f"id = {_toml_string(hunt.id)}"]
        if hunt.target.class_id is not None:
            lines.append(f"class = {_toml_string(hunt.target.class_id)}")
        else:
            lines.append(f"species = {hunt.target.species}")
        if hunt.time is not None:
            lines.append(f"conditions = {{ time = {_toml_list(hunt.time)} }}")
        lines += [f"tiers = {_toml_list(list(hunt.tiers))}", f"name = {_toml_string(TODO_HUNT_NAME)}"]
    return "\n".join(lines) + "\n"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/propose-events.py",
        description="Draft candidate Hunt Event files from a zone's loot for people to curate (DATA-R99).",
    )
    parser.add_argument(
        "--zone", type=int, action="append", required=True, metavar="AREAID", help="a zone areaID; give two of one band"
    )
    parser.add_argument(
        "--out", type=Path, help="the folder to write the drafts to (default: a dated folder in the temp directory)"
    )
    return parser


def _error(message: str) -> int:
    print(f"{PROG}: {message}", file=sys.stderr)
    return 1


def _zone_name(layers: Layers, zone: int) -> str:
    return f"zone {zone} ({layers.db2.areas[zone].name})"


def _check_zones(layers: Layers, zones: Sequence[int]) -> list[str]:
    """DATA-R97, DATA-R99: 1-2 zones, none twice, each a zone of the slice with a skill base, both of one band."""
    if not MIN_ZONES <= len(zones) <= MAX_ZONES:
        return [f"an event has {MIN_ZONES} or {MAX_ZONES} zones (DATA-R97); {len(zones)} were given"]
    problems: list[str] = []
    areas, bases = layers.db2.areas, layers.catch_lists.skill_bases
    for index, zone in enumerate(zones):
        if zone in zones[:index]:
            problems.append(f"zone {zone} is given twice")
        elif zone not in areas:
            problems.append(f"area {zone} isn't in {AREAS}")
        elif areas[zone].parent != 0:
            problems.append(f"area {zone} ({areas[zone].name}) isn't a zone (parent 0) in {AREAS} (DATA-R97)")
        elif zone not in bases:
            reason = "has no skill base, so its band can't be worked out (DATA-R97, LOG-R55)"
            problems.append(f"{_zone_name(layers, zone)} {reason}")
    if not problems and len(zones) == MAX_ZONES:
        first, second = zones
        bands = band_of(bases[first]), band_of(bases[second])
        if bands[0] != bands[1]:
            message = (
                f"{_zone_name(layers, first)} is in the {bands[0]} band and {_zone_name(layers, second)} in the"
                f" {bands[1]} band; an event's two zones are of one band (DATA-R99)"
            )
            problems.append(message)
    return problems


def main(argv: Sequence[str], root: Path, *, temp: Path | None = None, now: datetime | None = None) -> int:
    """Runs the command line on the repo at root; returns the exit code. temp and now stand in for the system temp
    directory and the clock that name the default folder."""
    args = _parser().parse_args(argv)
    zones: list[int] = args.zone
    try:
        layers = read_layers(root)
    except DataError as error:
        for problem in error.problems:
            print(f"{PROG}: {problem}", file=sys.stderr)
        return _error(f"{len(error.problems)} problem(s) in data/; drafted nothing")
    problems = _check_zones(layers, zones)
    for problem in problems:
        _error(problem)
    if problems:
        return 1
    out: Path = args.out or (temp or Path(tempfile.gettempdir())) / DRAFTS_FOLDER.format(now or datetime.now())
    if out.resolve().is_relative_to((root / "data").resolve()):
        return _error(f"{out}: drafts are never written under data/ (DATA-R99); give --out a folder elsewhere")
    where = " and ".join(_zone_name(layers, zone) for zone in zones)
    drafts, notes = propose(layers, zones, loot_shares(root))
    if not drafts:
        subzones = "its subzones" if len(zones) == 1 else "their subzones"
        return _error(f"{where} and {subzones} list no Species with a loot share to draft from (DATA-R99)")
    band = band_of(min(layers.catch_lists.skill_bases[zone] for zone in zones))
    out.mkdir(parents=True, exist_ok=True)
    print(
        f"{PROG}: {len(drafts)} draft(s) for {where}, {band} band, in {out}; each Hunt's expected minutes per tier at"
        f" {CATCHES_PER_HOUR} Catches an hour (Tunables):"
    )
    for draft in drafts:
        write_atomic(out / f"{draft.id}.toml", draft_toml(draft, where).encode("utf-8"))
        print(f"{draft.id}.toml")
        for hunt in draft.hunts:
            print(f"  {hunt_line(hunt)}")
    for note in notes:
        print(f"{PROG}: {note}")
    print(
        f"{PROG}: curate each draft: write its {{TODO ...}} text, check it with scripts/check-event.py <file> and"
        " copy it to data/hunts/events/"
    )
    return 0
