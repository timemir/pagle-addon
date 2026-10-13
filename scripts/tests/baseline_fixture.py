"""A small data/baseline/ layer for the generator's tests (DATA-R9), written as scripts/extract-baseline.py would."""

from datetime import date
from pathlib import Path

from pagle_data.extract_baseline import Snapshot, source_toml

SNAPSHOT = Snapshot("db_latest@1234567", date(2026, 9, 28), "https://example.invalid/db.zip", "ab" * 32)

# One row of each kind, with chances no other value in the tests uses (DATA-R4: they never leave data/baseline/).
CSVS = {
    "area_loot.csv": (
        "area,item,chance,ref,event,condition\n"
        "33,13759,31.415,,48,\n"
        "33,,27.18,500,,\n"
        '40,6303,61.8,,,"and(event(45), not(event(47)))"\n'
    ),
    "reference_loot.csv": "ref,item,chance\n500,6358,14.14\n",
    "pools.csv": "entry,name,event\n180248,School of Tastyfish,15\n",
    "pool_loot.csv": "entry,item,chance,ref\n180248,19807,0.0271,\n",
    "skill.csv": "area,skillBase\n1,-70\n33,130\n",
    "events.csv": (
        "event,start,occurrence,length,description\n"
        "48,2017-01-01 18:00,1440,1080,Fishing: Nightfin Cycle\n"
    ),
}


def write_baseline(root: Path, csvs: dict[str, str] | None = None, source: str | None = None) -> None:
    """Writes root/data/baseline/: the CSVs, and source.toml with their hashes unless source is given."""
    csvs = CSVS if csvs is None else csvs
    baseline = root / "data" / "baseline"
    baseline.mkdir(parents=True, exist_ok=True)
    for name, text in csvs.items():
        (baseline / name).write_bytes(text.encode("utf-8"))
    (baseline / "source.toml").write_text(source_toml(SNAPSHOT, csvs) if source is None else source, encoding="utf-8")
