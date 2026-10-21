"""The repo's own release lock (DATA-R73, DATA-R95): data/hunts/released.lock stays empty until the 1.0 tag."""

import tomllib
from pathlib import Path

from pagle_data.lock import LOCK

REPO = Path(__file__).resolve().parents[2]


def test_the_committed_lock_holds_no_entries_before_1_0() -> None:
    # DATA-R73: before 1.0 the data changes freely and released.lock is empty; DATA-R95: --lock is run when a release
    # is tagged, from 1.0 on, and never before (ADR 0005), so nobody locks pre-1.0 data by accident. The 1.0 tag's
    # commit is the one that drops this test.
    text = (REPO / LOCK).read_text(encoding="utf-8")
    assert tomllib.loads(text) == {}
