"""The alias table's rules (DATA-R32): the checks on aliases.toml's entries, and the candidates
scripts/generate-data.py --propose-aliases prints and every run warns about until they are committed (DATA-R64).

An alias maps an area on another map to the baseline fishing area it stands for (Forever's map 2940 duplicates,
e.g. 16521 → 18). In M1 an area's catch list is its rows in the baseline's area_loot.csv (roadmap M1), until real
catch lists exist in M2.
"""

from collections.abc import Collection, Iterable
from dataclasses import dataclass

from pagle_data.baseline import BaselineLayer
from pagle_data.db2 import Db2Layer
from pagle_data.forever import Alias
from pagle_data.toml_reader import Problems


def fishing_areas(baseline: BaselineLayer) -> set[int]:
    """The baseline fishing areas: every area with a catch list, which in M1 is a row in area_loot.csv."""
    return {row.area for row in baseline.area_loot}


def check_aliases(aliases: Iterable[Alias], fishing: Collection[int], problems: Problems) -> None:
    """DATA-R32's four bad aliases, each a problem (DATA-R63)."""
    aliases = list(aliases)
    sources = {alias.source for alias in aliases}
    for alias in aliases:
        if alias.source == alias.target:
            problems.add(alias.at, f"from and to are both {alias.source}")
        if alias.target not in fishing:
            problems.add(alias.at / "to", f"area {alias.target} has no baseline catch list")
        if alias.source in fishing:
            problems.add(alias.at / "from", f"area {alias.source} has a catch list of its own")
        if alias.target in sources:
            problems.add(alias.at / "to", f"area {alias.target} is itself an alias source")


@dataclass(frozen=True)
class Proposal:
    """A candidate alias (DATA-R32): source looks like a copy of the baseline fishing area target."""

    source: int
    target: int


def _identity(db2: Db2Layer, area_id: int) -> tuple[str, str] | None:
    """An area's enUS name and its parent's ("" for a zone); None when the parent is outside the slice."""
    area = db2.areas[area_id]
    if area.parent == 0:
        return area.name, ""
    parent = db2.areas.get(area.parent)
    return (area.name, parent.name) if parent is not None else None


def propose(db2: Db2Layer, fishing: Collection[int], committed: Iterable[Alias]) -> list[Proposal]:
    """DATA-R32's candidates not yet committed: each area with no catch list whose enUS name and parent's enUS name
    equal a baseline fishing area's, on a different ContinentID. By source, then target."""
    targets: dict[tuple[str, str], list[int]] = {}
    for target in sorted(fishing):
        if target in db2.areas and (identity := _identity(db2, target)) is not None:
            targets.setdefault(identity, []).append(target)
    sources = {alias.source for alias in committed}
    proposals: list[Proposal] = []
    for source, area in sorted(db2.areas.items()):
        if source in fishing or source in sources or (identity := _identity(db2, source)) is None:
            continue
        for target in targets.get(identity, []):
            if db2.areas[target].continent != area.continent:
                proposals.append(Proposal(source, target))
    return proposals


def _name(db2: Db2Layer, area_id: int) -> str:
    """An area's enUS name and its parent's, for the dev's review (never emitted, DATA-R3)."""
    area = db2.areas[area_id]
    parent = db2.areas.get(area.parent)
    return f"{area.name} ({parent.name})" if area.parent and parent is not None else area.name


def _label(db2: Db2Layer, area_id: int) -> str:
    return f"{_name(db2, area_id)}, continent {db2.areas[area_id].continent}"


def proposal_line(db2: Db2Layer, proposal: Proposal) -> str:
    """A proposal on one line, for DATA-R64's warning. Source and target share their names, by DATA-R32."""
    source, target = db2.areas[proposal.source], db2.areas[proposal.target]
    return (
        f"{proposal.source} -> {proposal.target}"
        f" ({_name(db2, proposal.source)}, continent {source.continent} -> {target.continent})"
    )


def proposal_toml(db2: Db2Layer, proposal: Proposal) -> str:
    """A proposal as an aliases.toml entry, its why left empty for the dev to fill (DATA-R10)."""
    return (
        "[[alias]]\n"
        f"from = {proposal.source}  # {_label(db2, proposal.source)}\n"
        f"to = {proposal.target}  # {_label(db2, proposal.target)}\n"
        'why = ""\n'
    )
