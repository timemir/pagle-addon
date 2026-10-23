"""The Prestige frames kit's frames the repo names otherwise (pagle_data/prestige_kit.py), which the addon's art
(scripts/prestige-art.py) and the website's (pagle_data/web_art.py) share: each is a frame of the kit's, and its new
key and name are the Ledger's lore (LED-R154)."""

import json
import tomllib
from pathlib import Path
from typing import Any

from pagle_data.prestige_kit import FRAME_KEYS, FRAME_NAMES, frame_key, frame_name

REPO = Path(__file__).resolve().parents[2]


def kit_frames() -> dict[str, Any]:
    art = json.loads((REPO / "data/art/prestige/art.json").read_text(encoding="utf-8"))
    return {frame["key"]: frame for frame in art["frames"]}


def test_rank_iii_is_the_lighthouse_and_the_rest_keep_the_kit_s_names() -> None:
    frames = kit_frames()
    assert (frame_key("lamproom"), frame_name(frames["lamproom"])) == ("lighthouse", "The Lighthouse")
    assert (frame_key("storm"), frame_name(frames["storm"])) == ("storm", "The Storm")


def test_each_renamed_frame_is_the_kit_s_and_named_as_its_lore() -> None:
    frames = kit_frames()
    lore = tomllib.loads((REPO / "data/lore/ledger.toml").read_text(encoding="utf-8"))["prestigeframe"]
    assert set(FRAME_NAMES) == set(FRAME_KEYS)
    for kit_key, key in FRAME_KEYS.items():
        assert frames[kit_key]["key"] == kit_key
        assert lore[key]["name"] == FRAME_NAMES[kit_key]
