"""data/checks.toml (DATA-R66): the switches that turn milestone-gated checks on. Before a switch is on its check is
skipped and the data is still emitted."""

from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path

from pagle_data.errors import At, Problems
from pagle_data.toml_reader import check_keys, describe, read_toml

CHECKS = "data/checks.toml"

# The lore IDs (DATA-R100), one per addon with lore. Each one's lore check is built (DATA-R107): the Ledger's from M3,
# Core's from M4, Hunts' from M5, Stats' from M6 and the Tackle Board's from M7.
LORE_IDS = ("core", "ledger", "hunts", "stats", "tackleboard")


@dataclass(frozen=True)
class Checks:
    """typical_length: DATA-R20's check that every Species has a typical length. lore: the lore IDs whose lore check
    is on (DATA-R107). event_pool: DATA-R99's minimum of rotating events per band, on once the 1.0 pool is authored
    (#306); left out, it is off. varieties: DATA-R132's check that every sized, non-Legend Species has its ten
    varieties (VAR-R2), on from the varieties release; left out, it is off."""

    typical_length: bool = False
    lore: tuple[str, ...] = field(default_factory=tuple)
    event_pool: bool = False
    varieties: bool = False


def _switch(document: Mapping[str, object], key: str, at: At, problems: Problems) -> bool:
    """A boolean switch, off when left out (or, with a problem, of the wrong type)."""
    value = document.get(key, False)
    if isinstance(value, bool):
        return value
    problems.add(at / key, f"expected a boolean, got {describe(value)}")
    return False


def read_checks(root: Path, problems: Problems) -> Checks:
    """root/data/checks.toml. Each problem found goes into problems; the switches read are returned either way."""
    document = read_toml(root, CHECKS, problems)
    if document is None:
        return Checks()
    at = At(CHECKS)
    check_keys(document, at, problems, required=("typicalLength", "lore"), optional=("eventPool", "varieties"))
    typical_length = _switch(document, "typicalLength", at, problems)
    event_pool = _switch(document, "eventPool", at, problems)
    varieties = _switch(document, "varieties", at, problems)
    lore: list[str] = []
    if "lore" in document:
        value = document["lore"]
        if not isinstance(value, list):
            problems.add(at / "lore", f"expected an array of lore IDs, got {describe(value)}")
            value = []
        for index, item in enumerate(value):
            item_at = At(CHECKS, f"lore[{index}]")
            if not isinstance(item, str) or item not in LORE_IDS:
                shown = f"'{item}'" if isinstance(item, str) else describe(item)
                problems.add(item_at, f"expected a lore ID ({', '.join(LORE_IDS)}), got {shown}")
            elif item in lore:
                problems.add(item_at, f"'{item}' is listed twice")
            else:
                lore.append(item)
    return Checks(typical_length, tuple(lore), event_pool, varieties)
