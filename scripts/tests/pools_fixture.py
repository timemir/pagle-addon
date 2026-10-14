"""data/forever/pools.toml for the generator's tests (DATA-R10, DATA-R43): one pool type over baseline_fixture's one
pool template, 180248, whose loot is 19807. With item_fixture's item layer it gives the pools below. Its ID names
no game text, so a test can check that no item name ships (DATA-R3)."""

from pathlib import Path

POOLS = """\
[pool.extravaganza]
entries = [180248]
why = "baseline_fixture's one pool template"
"""

# The pools POOLS gives, as the canonical JSON (DATA-R70) and Catalogue.lua (DATA-R44, DATA-R62) write them, for
# expected catalogues written by hand.
POOLS_JSON = '"pools":{"extravaganza":[19807]}'
POOLS_LUA = """\
\tpools = {
\t\textravaganza = { 19807 },
\t},
"""


def write_pools(root: Path, text: str = POOLS) -> None:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "pools.toml").write_text(text, encoding="utf-8")
