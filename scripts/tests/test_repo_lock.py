"""The repo's own release lock (DATA-R73, DATA-R95): the 1.0 release commit wrote data/hunts/released.lock."""

import tomllib
from pathlib import Path

from pagle_data.lock import LOCK

REPO = Path(__file__).resolve().parents[2]


def test_the_committed_lock_holds_every_standing_hunt_of_1_0() -> None:
    # DATA-R73: the 1.0 release commit ran --lock last, so the committed lock holds a hash for each Standing Hunt in
    # hunts.toml; DATA-R96 (the generator's own check, in --check) fails when one of them changes afterwards. Which
    # Hunts the lock holds beyond these (the event pool's, DATA-R98) is the generator's to say, not this test's.
    locked = tomllib.loads((REPO / LOCK).read_text(encoding="utf-8"))["hunt"]
    hunts = tomllib.loads((REPO / "data/hunts/hunts.toml").read_text(encoding="utf-8"))["hunt"]
    assert len(hunts) == 16
    assert {hunt["id"] for hunt in hunts} <= set(locked)
    assert all(len(table["hash"]) == 64 for table in locked.values())
