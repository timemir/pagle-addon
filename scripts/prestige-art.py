"""Writes addons/Pagle/data/PrestigeArt.lua from the Prestige frames kit's art.json (LED-R154, LED-R152, ANN-R83):
each rank's Prestige frame (its atlas and its layers, drawn by logic/LayeredArt.lua) and the Prestige emblems' atlas.

    .tools/bin/python scripts/prestige-art.py <kit>/art.json addons/Pagle/data/PrestigeArt.lua

then StyLua the file. The kit's data is copied as it is, with these changes made here once rather than in the client:
each layer's CSS keyframes become the motion tracks scripts/toast-styles2.py makes for the composed toast styles (one
renderer draws both); layers are put in draw order and on the host they draw on, "back" (the kit's z under 4, behind
the likeness) or "front" (the frame and what crosses over it); a label's CSS text-shadow becomes an ink's shadow with
an offset (a glow alone, none). Rank III keeps the name the dev chose, The Lighthouse, so its key and texture are
`lighthouse`, not the kit's `lamproom` (pagle_data/prestige_kit.py, which the web art export shares).
"""

import importlib.util
import json
import re
import sys
from pathlib import Path

from pagle_data.prestige_kit import frame_key, frame_name

_spec = importlib.util.spec_from_file_location("toast_styles2", Path(__file__).with_name("toast-styles2.py"))
assert _spec is not None and _spec.loader is not None
styles = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(styles)

# The kit's z of the frame's own body: below it, behind the likeness.
BODY_Z = 4
FACES = {"Marcellus": "gilt"}
# The emblems' sprites by rank: I to X, then the Master's.
NUMERALS = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"]


def colour_of(css):
    """'#rrggbb' or 'rgba(r, g, b, a)' as ('RRGGBB', alpha)."""
    css = css.strip()
    if css.startswith("#"):
        return css[1:].upper(), 1.0
    return styles.hex_of(css)


def shadow_of(css):
    """A label's text-shadow ('x y blur colour') as { colour, alpha, x, y }; the client has no blur, so a glow alone
    (no offset) is none."""
    if not css:
        return None
    match = re.match(r"\s*([-\d.]+)(?:px)?\s+([-\d.]+)(?:px)?\s+([-\d.]+)(?:px)?\s+(.+)$", css)
    if not match:
        raise ValueError(f"unread text-shadow {css}")
    x, y = float(match.group(1)), float(match.group(2))
    if not (x or y):
        return None
    rgb, alpha = colour_of(match.group(4))
    return {"color": rgb, "alpha": alpha, "x": x, "y": y}


def label_of(label):
    if not label:
        return None
    rgb, _ = colour_of(label["ink"])
    ink = {"face": FACES[label["face"]], "size": label["size"], "color": rgb}
    if label.get("caps"):
        ink["caps"] = True
    shadow = shadow_of(label.get("shadow"))
    if shadow:
        ink["shadow"] = shadow
    return {"top": label["textTop"], "ink": ink}


def frame_art(frame):
    key = frame_key(frame["key"])
    atlas = "Prestige" + key.capitalize()
    width, height = frame["atlasSize"]
    sprites = {}
    layers = []
    for _, layer in sorted(enumerate(frame["layers"]), key=lambda p: (float(p[1]["z"]), p[0])):
        rect = layer["rect"]
        sprites[layer["sprite"]] = {"x": rect["x"], "y": rect["y"], "w": rect["w"], "h": rect["h"]}
        entry = {
            "name": layer["name"],
            "sprite": layer["sprite"],
            "x": layer["x"],
            "y": layer["y"],
            "w": layer["w"],
            "h": layer["h"],
        }
        if layer["blend"] not in ("ADD", "BLEND"):
            raise ValueError(f"unknown blend {layer['blend']}")
        if layer["blend"] == "ADD":
            entry["blend"] = "ADD"
        if "motion" in layer:
            entry["motion"] = styles.motion_of(layer, layer["x"], layer["y"])
        entry["host"] = "back" if float(layer["z"]) < BODY_Z else "front"
        layers.append(entry)
    pin = frame["pin"]
    art = {
        "key": key,
        "atlas": atlas,
        "label": label_of(frame["label"]),
        "pin": {"x": pin["x"], "y": pin["y"], "w": pin["shieldWidth"]},
        "layers": layers,
    }
    file = "Frame" + key.capitalize()
    return atlas, file, {"width": width, "height": height, "sprites": sprites}, art


HEADER = """---@class PagleNS
local ns = select(2, ...)

-- The Prestige frames and Prestige emblems (ledger.md › LED-R154, LED-R152; announcements.md › ANN-R83), as the
-- Prestige frames kit's art.json has them: written by scripts/prestige-art.py, so change the kit and run it, not this
-- file. Core's, since the Ledger's bookplate and Core's Prestige banner both draw them. Each frame's atlas joins
-- ns.ATLASES by name (its sprites' boxes are the whole sprite, at 1.5 texels a unit); its art, by prestige rank in
-- ns.PRESTIGE_FRAME_ART (0 is No Prestige's, 11 the Master's), has its key, its label (the text's top and its ink:
-- face, size, "RRGGBB" colour, capitals, a shadow with an offset), the point its bookplate crest is pinned at with
-- the shield's width, and its layers in draw order, each on the host it draws on (logic/LayeredArt.lua): "back"
-- behind the likeness, "front" over it. A layer's `motion` is the composed toast styles' (data/ToastStyleArt2.lua).
-- Every unit is the kit's 260 × 280 box's, the likeness's well a circle in it (ns.PRESTIGE_WELL).

local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\prestige\\\\"

ns.ATLASES = ns.ATLASES or {}
"""


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: prestige-art.py <art.json> <PrestigeArt.lua>")
    data = json.load(open(argv[0], encoding="utf-8"))
    scale = data["scale"]
    out = HEADER
    box_w, box_h = data["box"]
    well = data["well"]
    out += f"\n--- The kit's box, in UI units, and the likeness's well in it.\nns.PRESTIGE_BOX = {styles.lua({'w': box_w, 'h': box_h})}\n"
    out += f"ns.PRESTIGE_WELL = {styles.lua({'cx': well['cx'], 'cy': well['cy'], 'r': well['r']})}\n"
    out += "\n---@type table<integer, PaglePrestigeFrameArt>\nns.PRESTIGE_FRAME_ART = {}\n\n"
    for frame in data["frames"]:
        atlas, file, entry, art = frame_art(frame)
        for sprite in entry["sprites"].values():
            sprite["box"] = [0, 0, sprite["w"] / scale, sprite["h"] / scale]
        entry["scale"] = scale
        body = styles.lua(entry).replace("{\n", "{\n\tfile = DIR .. " + json.dumps(file) + ",\n", 1)
        out += f"-- {frame_name(frame)} (rank {frame['rank']})\n"
        out += f"ns.ATLASES[{json.dumps(atlas)}] = {body}\n"
        out += f"ns.PRESTIGE_FRAME_ART[{frame['rank']}] = {styles.lua(art)}\n\n"
    emblems = data["emblems"]
    width, height = emblems["atlasSize"]
    emblem_scale = 128 / emblems["design"]
    sprites = {}
    for name, rect in emblems["sprites"].items():
        sprites[name] = {
            "x": rect["x"],
            "y": rect["y"],
            "w": rect["w"],
            "h": rect["h"],
            "box": [0, 0, rect["w"] / emblem_scale, rect["h"] / emblem_scale],
        }
    entry = {"width": width, "height": height, "scale": emblem_scale, "sprites": sprites}
    body = styles.lua(entry).replace("{\n", '{\n\tfile = DIR .. "Emblems",\n', 1)
    out += "-- The Prestige emblems: one per rank I to X and the Master's, each its frame in miniature with its numeral.\n"
    out += f"ns.ATLASES[\"PrestigeEmblems\"] = {body}\n"
    names = ", ".join(json.dumps(f"emblem-{n}") for n in NUMERALS)
    out += f"\n--- The emblems' sprites by rank, I to X; past X, `emblem-master`.\nns.PRESTIGE_EMBLEMS = {{ {names} }}\n"
    open(argv[1], "w", encoding="utf-8", newline="\n").write(out.rstrip("\n") + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
