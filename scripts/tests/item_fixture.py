"""A small item layer for the generator's tests: data/forever/items.toml, species.toml and families.toml
(DATA-R10) and data/checks.toml (DATA-R66), as a fixture tree needs them to generate."""

from pathlib import Path

# Categories for baseline_fixture.CSVS' items (DATA-R17): 13759 and 6303 are area loot and 19807 pool loot. 6358 is
# reachable only through reference table 500, so it is Noise by rule (DATA-R16) and needs none.
ITEMS = """\
[item.6303]
category = "fish"

[item.13759]
category = "fish"

[item.19807]
category = "fish"
"""

# The records ITEMS gives with an empty items.csv (no quality known), written by hand from DATA-R16, DATA-R19 and
# DATA-R77: as the canonical JSON writes them (DATA-R70), for a fingerprint worked out by hand, and in Catalogue.lua.
ITEMS_JSON = (
    '"items":{"13759":{"category":"fish","legend":false,"noise":false,"pool":false,"removed":false,"species":13759},'
    '"19807":{"category":"fish","legend":false,"noise":false,"pool":false,"removed":false,"species":19807},'
    '"6303":{"category":"fish","legend":false,"noise":false,"pool":false,"removed":false,"species":6303},'
    '"6358":{"category":"other","legend":false,"noise":true,"pool":false,"removed":false}}'
)
ITEMS_LUA = """\
\titems = {
\t\t[6303] = { category = "fish", legend = false, noise = false, pool = false, removed = false, species = 6303 },
\t\t[6358] = { category = "other", legend = false, noise = true, pool = false, removed = false },
\t\t[13759] = { category = "fish", legend = false, noise = false, pool = false, removed = false, species = 13759 },
\t\t[19807] = { category = "fish", legend = false, noise = false, pool = false, removed = false, species = 19807 },
\t},
"""

# Both switches off, as in M2 (DATA-R66).
CHECKS = "typicalLength = false\nlore = []\n"


def write_item_layer(
    root: Path, items: str = ITEMS, species: str = "", families: str = "", checks: str = CHECKS
) -> Path:
    """Writes root/data/forever/items.toml, species.toml and families.toml, and root/data/checks.toml."""
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "items.toml").write_text(items, encoding="utf-8")
    (forever / "species.toml").write_text(species, encoding="utf-8")
    (forever / "families.toml").write_text(families, encoding="utf-8")
    (root / "data" / "checks.toml").write_text(checks, encoding="utf-8")
    return root
