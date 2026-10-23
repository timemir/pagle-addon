"""The Prestige frames kit's frames the repo names otherwise, shared by the addon's art (scripts/prestige-art.py, which
writes addons/Pagle/data/PrestigeArt.lua) and the website's (pagle_data/web_art.py), so the addon and pagle-backend
name each frame alike.

Rank III keeps the name the dev chose, The Lighthouse (ledger.md LED-R154): its key is `lighthouse`, not the kit's
`lamproom`, and its name "The Lighthouse", not the kit's "The Lamp Room". Both are its lore, `prestigeframe.lighthouse`.
"""

from typing import Any

# The kit's key -> the repo's.
FRAME_KEYS: dict[str, str] = {"lamproom": "lighthouse"}
# The kit's key -> the repo's name for the frame.
FRAME_NAMES: dict[str, str] = {"lamproom": "The Lighthouse"}


def frame_key(kit_key: str) -> str:
    """The repo's key for the kit's frame `kit_key`."""
    return FRAME_KEYS.get(kit_key, kit_key)


def frame_name(frame: dict[str, Any]) -> str:
    """The repo's name for a frame of the kit's art.json."""
    name: str = FRAME_NAMES.get(frame["key"], frame["name"])
    return name
