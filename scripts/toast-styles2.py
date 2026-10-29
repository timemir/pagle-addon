"""Writes addons/Pagle/data/ToastStyleArt2.lua from the Curio Shop round two kit's goods.json (ANN-R82): the ten
composed toast styles' atlases and art data, keyed by good ID, for adapter/ToastLayers.lua to draw; and, with `--round
3`, addons/Pagle/data/ToastStyleArt3.lua from the round three kit's (ANN-R84), the eighteen more in the same format;
and, with `--round 4`, addons/Pagle/data/ToastStyleArt4.lua from the epic five's kit (ANN-R85), keyed by the IDs the
kit gives them.

    .tools/bin/python scripts/toast-styles2.py <kit>/goods.json addons/Pagle/data/ToastStyleArt2.lua
    .tools/bin/python scripts/toast-styles2.py --round 3 <kit3>/goods.json addons/Pagle/data/ToastStyleArt3.lua
    .tools/bin/python scripts/toast-styles2.py --round 4 <kit4>/goods.json addons/Pagle/data/ToastStyleArt4.lua

then StyLua the file. The kit's data is copied as it is, with three changes made here once rather than in the client:
each layer's CSS transform list is folded into one translate, rotation and scale (CSS applies a list right to left,
so `scaleX(-1) translateX(-120px)` moves the fish right); a stamp's tilt matrix becomes its angle; and a sweep's window
(the element its strip scrolls through) gets its size: its mask's, or the strip's over the canvas's background-size,
which the kit doesn't record. Layers are put in draw order and on the host they draw on: "under" the medallion's icon
(the canvas's z-index below 4, and the medallion's own back), "front" over the icon (the medallion's front) or "over"
the words (z-index 6 and up); the stamp is the rung's `stamp`, drawn per stamp word.
"""

import json
import math
import re
import sys

# The canvas's background-size for a sweep with no mask, as the strip over its window (s_trophy.py, s_sonar.py).
WINDOW_FACTORS = {"trophy-glint": (3.2, 1.0), "sonar-scan": (1.0, 3.0)}
# The canvas's z-index of the medallion (t2core.py): its back under its icon, its front over it.
MEDALLION_Z = 4
FACES = {
    ("IM Fell English SC", "normal"): "sc",
    ("IM Fell English", "normal"): "print",
    ("IM Fell English", "italic"): "italic",
    ("Marcellus", "normal"): "gilt",
    ("Cutive Mono", "normal"): "mono",
}
CAVEAT = {"400": "hand", "500": "hand", "600": "handSemi", "700": "handBold"}
EASINGS = {
    "linear": "linear",
    "ease-in-out": "inOut",
    "ease-out": "out",
    "ease-in": "in",
    "ease": "ease",
    "steps(1)": "steps1",
}
INKS = ("what", "name", "small", "amt", "stamp")


def num(value):
    """A number as Lua writes it: an integer when it is one, else at most 3 decimals."""
    value = round(float(value), 3)
    if value == int(value):
        return str(int(value))
    return repr(value)


def hex_of(css):
    """'rgb(1, 2, 3)' or 'rgba(1, 2, 3, a)' as ('010203', a)."""
    parts = [p.strip() for p in re.match(r"rgba?\(([^)]*)\)", css).group(1).split(",")]
    rgb = "".join(f"{int(float(p)):02X}" for p in parts[:3])
    return rgb, float(parts[3]) if len(parts) > 3 else 1.0


def shadow_of(css):
    """The first text-shadow with an offset, as { colour, alpha, x, y }; the client has no blur, so a glow alone
    (no offset) is none."""
    if not css or css == "none":
        return None
    for part in re.findall(r"rgba?\([^)]*\)\s+[-\d.]+px\s+[-\d.]+px(?:\s+[-\d.]+px)?", css):
        colour = re.match(r"rgba?\([^)]*\)", part).group(0)
        x, y = (float(v) for v in re.findall(r"([-\d.]+)px", part[len(colour) :])[:2])
        if x or y:
            rgb, alpha = hex_of(colour)
            return {"color": rgb, "alpha": alpha, "x": x, "y": y}
    return None


def ink_of(ink):
    if not ink:
        return None
    family, weight = ink["family"], ink["weight"]
    face = CAVEAT[weight] if family == "Caveat" else FACES[(family, ink["style"])]
    rgb, _ = hex_of(ink["color"])
    out = {"face": face, "size": ink["size"], "color": rgb}
    if ink["transform"] == "uppercase":
        out["caps"] = True
    shadow = shadow_of(ink["shadow"])
    if shadow:
        out["shadow"] = shadow
    return out


def px(value):
    return float(value.strip().rstrip("px").rstrip("deg") or 0)


def matrix_of(css):
    """A CSS transform list as the matrix (a, b, c, d, e, f) it composes to, left to right as CSS does."""
    a, b, c, d, e, f = 1.0, 0.0, 0.0, 1.0, 0.0, 0.0
    for name, args in re.findall(r"(\w+)\(([^)]*)\)", css or ""):
        vals = [v for v in re.split(r"[,\s]+", args.strip()) if v]
        if name in ("translate", "translateX", "translateY"):
            tx = px(vals[0]) if name != "translateY" else 0.0
            ty = px(vals[1]) if name == "translate" and len(vals) > 1 else (px(vals[0]) if name == "translateY" else 0.0)
            m = (1, 0, 0, 1, tx, ty)
        elif name == "rotate":
            r = math.radians(px(vals[0]))
            m = (math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0)
        elif name in ("scale", "scaleX", "scaleY"):
            s1 = float(vals[0])
            if name == "scaleX":
                m = (s1, 0, 0, 1, 0, 0)
            elif name == "scaleY":
                m = (1, 0, 0, s1, 0, 0)
            else:
                m = (s1, 0, 0, float(vals[1]) if len(vals) > 1 else s1, 0, 0)
        elif name == "skewX":
            m = (1, 0, math.tan(math.radians(px(vals[0]))), 1, 0, 0)
        elif name == "skewY":
            m = (1, math.tan(math.radians(px(vals[0]))), 0, 1, 0, 0)
        else:
            raise ValueError(f"unknown transform {name}")
        # this matrix times m, as CSS composes a list left to right
        a, b, c, d, e, f = (
            a * m[0] + c * m[1],
            b * m[0] + d * m[1],
            a * m[2] + c * m[3],
            b * m[2] + d * m[3],
            a * m[4] + c * m[5] + e,
            b * m[4] + d * m[5] + f,
        )
    return a, b, c, d, e, f


def fold(css):
    """A CSS transform list folded to (x, y, rotate, sx, sy, kx, ky): its matrix's translation, then its 2 x 2 part as
    a rotation of a skew of a scale (the client draws R . K . S, ANN-R82). The skew angles kx and ky are in degrees,
    0 for a list with none. A list with a skew must be rotations, then the skews, then scales, as the kit's three are;
    anything else is an error rather than a guess."""
    a, b, c, d, e, f = matrix_of(css)
    functions = re.findall(r"(\w+)\(([^)]*)\)", css or "")
    first = next((i for i, (name, _) in enumerate(functions) if name.startswith("skew")), None)
    if first is not None:
        text = lambda items: " ".join(f"{name}({args})" for name, args in items)  # noqa: E731
        last = max(i for i, (name, _) in enumerate(functions) if name.startswith("skew"))
        head, skews, tail = functions[:first], functions[first : last + 1], functions[last + 1 :]
        if any(not name.startswith("skew") for name, _ in skews) or any(name != "rotate" for name, _ in head) or any(
            name not in ("scale", "scaleX", "scaleY") for name, _ in tail
        ):
            raise ValueError(f"a skew must sit between rotations and scales: {css}")
        kx = sum(px(args) for name, args in skews if name == "skewX")
        ky = sum(px(args) for name, args in skews if name == "skewY")
        rot = sum(px(args) for _, args in head)
        scale = matrix_of(text(tail))
        sx, sy = scale[0], scale[3]
        skewed = matrix_of(f"rotate({rot}deg) skewX({kx}deg) skewY({ky}deg) scale({sx}, {sy})")
        if any(abs(u - v) > 1e-6 for u, v in zip(skewed[:4], (a, b, c, d))):
            raise ValueError(f"a skew list that is not rotate, skewX, skewY, scale: {css}")
        return e, f, rot, sx, sy, kx, ky
    det = a * d - b * c
    if det < 0:
        sx = -math.hypot(a, b)
        rot = math.atan2(-b, -a)
    else:
        sx = math.hypot(a, b)
        rot = math.atan2(b, a)
    sy = det / sx if sx else 1.0
    return e, f, unwound(math.degrees(rot), functions), sx, sy, 0.0, 0.0


def unwound(angle, functions):
    """The matrix's angle (-180 to 180) as the whole turns the list's rotate() arguments add up to: a spin from
    rotate(0) to rotate(360deg) is the same matrix at both ends, but the client turns a layer by interpolating the
    angle linearly between keys, so the 360 must survive (a 0 to 0 spin does not move). An angle that is not the
    rotate() sum modulo a turn (a mirror before the rotation reverses it) is left as the matrix has it."""
    turns = sum(px(args) for name, args in functions if name == "rotate")
    whole = round((turns - angle) / 360)
    return angle + 360 * whole if abs(turns - angle - 360 * whole) < 1e-6 else angle


def tilt_of(matrix):
    if not matrix or matrix == "none":
        return 0.0
    a, b = (float(v) for v in re.match(r"matrix\(([^)]*)\)", matrix).group(1).split(",")[:2])
    return math.degrees(math.atan2(b, a))


def tracks(motion):
    """The motion's keyframes per property, as CSS animates each: alpha, transform (one list), scroll. A property a
    keyframe leaves out is interpolated between the keyframes that set it, from its base value at 0% or 100% when
    neither sets it."""
    out = {}
    for kind in ("alpha", "transform", "scroll"):
        keys = []
        for frame in motion["frames"]:
            if kind == "alpha" and "alpha" in frame:
                value = [frame["alpha"]]
            elif kind == "transform" and "transform" in frame.get("css", {}):
                value = list(fold(frame["css"]["transform"]))
            elif kind == "scroll" and "scroll" in frame:
                value = list(frame["scroll"])
            else:
                continue
            for at in frame["at"]:
                keys.append([at] + value)
        if not keys:
            continue
        if kind == "transform":
            # Skew angles (kx, ky) are kept only for a motion that has one: the others stay the five values.
            skewed = any(key[6] or key[7] for key in keys)
            if not skewed:
                keys = [key[:6] for key in keys]
        base = {
            "alpha": [1.0],
            "transform": [0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0] if kind == "transform" and skewed else [0.0, 0.0, 0.0, 1.0, 1.0],
            "scroll": [0.0, 0.0],
        }[kind]
        keys.sort(key=lambda k: k[0])
        if keys[0][0] > 0:
            keys.insert(0, [0.0] + base)
        if keys[-1][0] < 1:
            keys.append([1.0] + base)
        out[kind] = keys
    return out


def motion_of(layer, x0, y0):
    m = layer["motion"]
    out = {
        "keyframes": m["keyframes"],
        "dur": m["duration"],
        "ease": EASINGS[m["easing"]],
        "loop": m["loop"],
        "origin": {"x": m["origin"][0], "y": m["origin"][1]},
    }
    if m["delay"]:
        out["delay"] = m["delay"]
    out.update(tracks(m))
    if "window" in m:
        if "mask" in layer:
            ww, wh = layer["mask"]["w"], layer["mask"]["h"]
        else:
            fx, fy = WINDOW_FACTORS[m["keyframes"]]
            ww, wh = layer["w"] / fx, layer["h"] / fy
        out["window"] = {"x": m["window"]["x"], "y": m["window"]["y"], "w": ww, "h": wh}
    return out


def order_of(layer):
    z = float(layer["z"])
    if layer["name"] == "mback":
        return MEDALLION_Z, "under"
    if layer["name"] == "mfront":
        return MEDALLION_Z + 0.2, "front"
    return z, "under" if z < MEDALLION_Z else "over"


def box(values):
    return {"x": values[0], "y": values[1], "w": values[2], "h": values[3]} if values else None


# The kit's rungs left out: its toast.low, a slim toast. Every toast is drawn full size, on the toast rung (ANN-R80), so
# the rung and the sprites only it draws (named `low-*`) are not written.
SKIPPED_RUNGS = ("low",)


def style_art(good):
    art = good["art"]
    atlas = art["atlas"].split("\\")[-1]
    width, height = art["atlasSize"]
    sprites = {}
    rungs = {}

    def sprite(name, rect):
        sprites[name] = {"x": rect["x"], "y": rect["y"], "w": rect["w"], "h": rect["h"]}
        return name

    for rung_name, rung in art["rungs"].items():
        if rung_name in SKIPPED_RUNGS:
            continue
        layers, stamp = [], None
        ordered = sorted(enumerate(rung["layers"]), key=lambda p: (order_of(p[1])[0], p[0]))
        for _, layer in ordered:
            entry = {
                "name": layer["name"],
                "sprite": sprite(layer["sprite"], layer["rect"]),
                "x": layer["x"],
                "y": layer["y"],
                "w": layer["w"],
                "h": layer["h"],
            }
            blend = {"ADD": "ADD", "MOD": "MOD"}.get(layer["blend"])
            if layer["blend"] not in ("ADD", "MOD", "BLEND", "overlay"):
                raise ValueError(f"unknown blend {layer['blend']}")
            if blend:
                entry["blend"] = blend
            if "mask" in layer:
                mask = layer["mask"]
                entry["mask"] = {
                    "sprite": sprite(mask["sprite"], mask["rect"]),
                    "x": mask["x"],
                    "y": mask["y"],
                    "w": mask["w"],
                    "h": mask["h"],
                }
            if "motion" in layer:
                entry["motion"] = motion_of(layer, layer["x"], layer["y"])
            if layer["name"] == "stamp":
                entry["slice"] = {"left": layer["slice"]["left"], "right": layer["slice"]["right"]}
                entry["tilt"] = tilt_of(layer.get("tilt"))
                stamp = entry
                continue
            entry["host"] = order_of(layer)[1]
            layers.append(entry)
        out = {
            "w": rung["w"],
            "h": rung["h"],
            "med": box(rung["med"]),
            "icon": box(rung["icon"]),
            "text": box(rung["text"]),
            "coin": box(rung["coin"]),
            "amt": box(rung["amt"]),
            "inks": {k: ink_of(rung["inks"].get(k)) for k in INKS if rung["inks"].get(k)},
            "layers": layers,
        }
        if stamp:
            out["stamp"] = stamp
        if rung.get("slice"):
            out["slice"] = {"left": rung["slice"]["left"], "right": rung["slice"]["right"]}
        rungs[rung_name] = out
    atlas_entry = {"file": atlas, "width": width, "height": height, "scale": art["scale"], "sprites": sprites}
    return atlas, atlas_entry, rungs


def stage_art(good, sprites):
    """A style's chart stages (the Cartographer's Folio, ANN-R85), or None for a style without: in order, each stage's
    lowest count and, for toast and toast.high, the deco sprite it draws and that sprite's box (UI units from the rung's
    top left). A stage's sprite is the rung's own deco (stage 4's) or one of the kit's stage sprites, added to `sprites`;
    the Nod has no stages."""
    art = good["art"]
    if "stages" not in art:
        return None
    extra = art.get("stageSprites", {})
    out = []
    for stage in art["stages"]:
        entry = {"min": stage["min"]}
        for rung in ("toast", "high"):
            name = stage[rung]
            if name in extra:
                found = extra[name]
                rect = found["rect"]
                sprites[name] = {"x": rect["x"], "y": rect["y"], "w": rect["w"], "h": rect["h"]}
            else:
                found = next(layer for layer in art["rungs"][rung]["layers"] if layer["sprite"] == name)
            entry[rung] = {"sprite": name, "x": found["x"], "y": found["y"], "w": found["w"], "h": found["h"]}
        out.append(entry)
    return out


KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua(value, indent=0):
    tab = "\t" * (indent + 1)
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return num(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        if all(isinstance(v, (int, float)) for v in value):
            return "{ " + ", ".join(num(v) for v in value) + " }"
        return "{\n" + "".join(f"{tab}{lua(v, indent + 1)},\n" for v in value) + "\t" * indent + "}"
    items = []
    for k, v in value.items():
        if v is None:
            continue
        key = k if KEY.match(k) else f"[{json.dumps(k)}]"
        items.append((key, lua(v, indent + 1)))
    flat = "{ " + ", ".join(f"{k} = {v}" for k, v in items) + " }"
    if "\n" not in flat and len(flat) + indent * 4 < 100:
        return flat
    return "{\n" + "".join(f"{tab}{k} = {v},\n" for k, v in items) + "\t" * indent + "}"


HEADER = '''---@class PagleNS
local ns = select(2, ...)

-- The Curio Shop round two's ten composed toast styles (announcements.md › Toast styles, ANN-R82), as the round two
-- kit's goods.json has them: written by scripts/toast-styles2.py, so change the kit and run it, not this file. Each
-- style's atlas joins ns.ATLASES by name (its sprites' boxes are the whole sprite, at 1.5 texels a unit); its art, by
-- good ID in ns.TOAST_STYLE_ART2, has a rung for toast, toast.high and the Nod (the kit's toast.low rung is left out:
-- every toast is drawn full size, on the toast rung, ANN-R80): its box, the medallion, icon, text, coin and Coins boxes
-- (UI units from the rung's top left), its inks (face, size, "RRGGBB" colour, capitals, a shadow with an offset), its
-- stamp (a sprite three-sliced at `slice` and tilted `tilt` degrees clockwise) and its layers in draw order, each on
-- the host it draws on (adapter/ToastLayers.lua). A layer's `motion` is its CSS animation per property: `alpha` keys
-- { at, alpha }, `transform` keys { at, x, y, rotate, sx, sy } about `origin` (rung units), `scroll` keys { at, u, v }
-- of a strip through its `window`; logic/ToastStyles.lua decides what loops.
-- Seven are the Ledger's (registered in Core's slot, LED-R118), three Core's.

local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\announce\\\\"

ns.ATLASES = ns.ATLASES or {}
---@type table<string, PagleToastArt2>
ns.TOAST_STYLE_ART2 = {}

'''


HEADER3 = '''---@class PagleNS
local ns = select(2, ...)

-- The Curio Shop round three's eighteen composed toast styles (announcements.md › Toast styles, ANN-R84), as the round
-- three kit's goods.json has them: written by scripts/toast-styles2.py --round 3, so change the kit and run it, not this
-- file. The same format as data/ToastStyleArt2.lua (ANN-R82), which loads first and owns the tables. Eight are Core's,
-- for sale; the ten race and faction styles are the Ledger's earned goods (LED-R164), keyed by their ledger.* IDs.

local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\announce\\\\"

ns.ATLASES = ns.ATLASES or {}
ns.TOAST_STYLE_ART2 = ns.TOAST_STYLE_ART2 or {}

'''


HEADER4 = '''---@class PagleNS
local ns = select(2, ...)

-- The epic five composed toast styles (announcements.md › Toast styles, ANN-R85), as their kit's goods.json has them:
-- written by scripts/toast-styles2.py --round 4, so change the kit and run it, not this file. The same format as
-- data/ToastStyleArt2.lua (ANN-R82), which loads first and owns the tables. Every one is an earned good in Core's slot,
-- keyed by its owner's ID: Hunts' three (hunts.*) and the Ledger's two (ledger.*). The Cartographer's Folio's art also
-- has `stages`: its chart by zones at Master, each stage's lowest count and its deco sprite and box per rung.

local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\announce\\\\"

ns.ATLASES = ns.ATLASES or {}
ns.TOAST_STYLE_ART2 = ns.TOAST_STYLE_ART2 or {}

'''


# Round three's ten race and faction styles, which the kit has as Core's: the Ledger earns them (LED-R164), so their
# goods are the Ledger's, and the art is keyed by their IDs.
ROUND3_LEDGER = {
    f"core.toaststyle.{key}"
    for key in ("crier", "hall", "glade", "blueprint", "drum", "shroud", "totem", "hex", "lion", "warband")
}


# The kit's names that Pagle's lore can't keep: "Notice" is one of Pagle's capitalised terms, which lore never uses
# (DATA-R110), and the Ledger's lore is held to that.
ROUND3_NAMES = {"core.toaststyle.crier": "Town Crier's Proclamation"}


def main(argv):
    header, ledger = HEADER, set()
    if argv[:2] == ["--round", "3"]:
        header, ledger, argv = HEADER3, ROUND3_LEDGER, argv[2:]
    elif argv[:2] == ["--round", "4"]:
        header, argv = HEADER4, argv[2:]
    if len(argv) != 2:
        sys.exit("usage: toast-styles2.py [--round 3|4] <goods.json> <ToastStyleArt2.lua>")
    data = json.load(open(argv[0], encoding="utf-8"))
    out = header
    for good in data["goods"]:
        if good["slot"] != "core.toaststyle":
            continue
        if good["id"] in ledger:
            good = {**good, "id": good["id"].replace("core.", "ledger.", 1), "name": ROUND3_NAMES.get(good["id"], good["name"])}
        atlas, entry, rungs = style_art(good)
        stages = stage_art(good, entry["sprites"])
        for sprite in entry["sprites"].values():
            scale = entry["scale"]
            sprite["box"] = [0, 0, sprite["w"] / scale, sprite["h"] / scale]
        file = entry.pop("file")
        body = lua(entry).replace("{\n", "{\n\tfile = DIR .. " + json.dumps(file) + ",\n", 1)
        out += f"-- {good['name']} ({good['id']})\n"
        out += f"ns.ATLASES[{json.dumps(atlas)}] = {body}\n"
        art = {"atlas": atlas, "rungs": rungs}
        if stages:
            art["stages"] = stages
        out += f"ns.TOAST_STYLE_ART2[{json.dumps(good['id'])}] = {lua(art)}\n\n"
    open(argv[1], "w", encoding="utf-8", newline="\n").write(out.rstrip("\n") + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
