"""The Prestige frames, Prestige emblems and Legend crests as web art for the website (pagle-backend).

Reads the kit's lossless sources in data/art/prestige/: art.json (every sprite's atlas rect, its place in the
260 x 280 unit box, z order, blend and motion), the 32-bit TGA atlases under tga/, and wells/<legend>.svg. Writes,
under one output folder, at 2 pixels per unit:

- `<key>.webp` for every frame and crest: all its layers composited at rest (each layer unmoved, at the opacity of its
  first keyframe; ADD layers added, as plus-lighter does), clipped to the box: 520 x 560.
- `<key>/` for every frame or crest that moves: one transparent WebP per layer at 2x its drawn size, `manifest.json`
  (the layers in z order with their rect in units, blend, rest opacity and keyframes name) and `<key>.css` (the
  `@keyframes`, transform and opacity only, plus one class per moving layer with its timing and transform-origin).
- `prestige-emblem-<1..10|master>-<64|34|22>.webp`, numerals baked in, at 128, 68 and 44 px.
- `index.json`: every piece written, with its name, label and well.

No Blizzard texture, icon or other game art goes into any output (pagle-backend ANG-R54). Every pixel comes from the
Pagle-drawn atlases in data/art/prestige/tga/ or from wells/*.svg: where the client draws a Legend's item icon in its
crest's well, the export draws a Pagle-drawn sepia fish instead (the kit's own stand-ins, f_legend.py's SEPIA), and
the Unwritten crest keeps its own dark fish, which is in its atlas.

Needs Pillow built with WebP: the pinned one in .tools/ (PYTHON_PACKAGES in scripts/tools.env) is.
"""

from __future__ import annotations

import io
import json
import math
import re
import xml.etree.ElementTree as ET
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter

from pagle_data.files import write_atomic

ART_DIR = Path("data/art/prestige")
PX = 2  # output pixels per unit
EMBLEM_SIZES = (64, 34, 22)
ROMAN = ("i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x")
WEBP_QUALITY = 90  # lossy colour, lossless alpha

# A Legend crest's well, as the kit's legends.css draws it round the item icon (f_legend.py, WELL_CSS): a disc of
# radius R under the ring (z 3), `radial-gradient(circle at 40% 30%, #e8d8b0, #b89a68 60%, #6a4a24)`, an inset shadow
# `0 0 16px rgba(40,20,4,.8)`, and the picture at 82% of the disc's box, centred.
WELL_Z = 3
WELL_STOPS = ((0.0, (0xE8, 0xD8, 0xB0)), (0.6, (0xB8, 0x9A, 0x68)), (1.0, (0x6A, 0x4A, 0x24)))
WELL_SHADOW = ((40, 20, 4), 0.8, 8.0)  # colour, alpha, Gaussian sigma in units (CSS blur 16px)
WELL_GLYPH = 0.82
LABEL_LETTER_SPACING_EM = 0.12  # pfcore.py's .lt, the same for every frame and crest

Json = dict[str, Any]


@dataclass(frozen=True)
class Piece:
    """One frame or crest: its output key, CSS namespace and layers (a crest's drawn well included)."""

    key: str
    ns: str
    kind: str
    entry: Json
    atlas: Path
    layers: tuple[Json, ...]

    @property
    def animated(self) -> bool:
        return any(layer.get("motion") for layer in self.layers)


# ------------------------------------------------------------------------------------------------- reading the kit

def load_art(art_dir: Path) -> Json:
    art: Json = json.loads((art_dir / "art.json").read_text(encoding="utf-8"))
    return art


def atlas_path(art_dir: Path, atlas: str) -> Path:
    """`Interface\\AddOns\\Pagle\\media\\legends\\LegendRacer` -> <art_dir>/tga/legends/LegendRacer.tga."""
    parts = atlas.split("\\")
    return art_dir / "tga" / parts[-2] / (parts[-1] + ".tga")


def frame_suffix(rank: int) -> str:
    return "none" if rank == 0 else "master" if rank == 11 else str(rank)


def pieces(art: Json, art_dir: Path) -> list[Piece]:
    out = []
    for frame in art["frames"]:
        suffix = frame_suffix(frame["rank"])
        out.append(Piece(f"prestige-frame-{suffix}", f"pg-frame-{suffix}", "prestige-frame", frame,
                         atlas_path(art_dir, frame["atlas"]), tuple(by_z(frame["layers"]))))
    for legend in art["legends"]:
        suffix = str(legend["item"]) if legend["item"] else "unwritten"
        layers = list(legend["layers"])
        if not any(layer["name"] == "well" for layer in layers):
            glyph = art_dir / "wells" / f"{legend['key']}.svg"
            if not glyph.is_file():
                raise ValueError(f"legend-crest-{suffix}: no well in its atlas and no {glyph.as_posix()}")
            well = art["well"]
            r = well["r"]
            layers.append({"name": "well", "x": well["cx"] - r, "y": well["cy"] - r, "w": 2 * r, "h": 2 * r,
                           "z": WELL_Z, "blend": "BLEND", "glyph": glyph})
        out.append(Piece(f"legend-crest-{suffix}", f"pg-crest-{suffix}", "legend-crest", legend,
                         atlas_path(art_dir, legend["atlas"]), tuple(by_z(layers))))
    return out


def by_z(layers: Iterable[Json]) -> list[Json]:
    """Bottom first. Equal z keep art.json's order, as the kit's DOM order does."""
    return sorted(layers, key=lambda layer: layer["z"])


def emblem_keys() -> list[tuple[str, str]]:
    """(output key, atlas sprite) for ranks I..X and Master."""
    keys = [(f"prestige-emblem-{rank}", f"emblem-{numeral}") for rank, numeral in enumerate(ROMAN, start=1)]
    return keys + [("prestige-emblem-master", "emblem-master")]


# ------------------------------------------------------------------------------------------------- pixels

def premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    if image.size == size:
        return image
    return image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def px(value: float) -> int:
    return round(value * PX)


def layer_size(layer: Json) -> tuple[int, int]:
    return px(layer["w"]), px(layer["h"])


def layer_image(layer: Json, atlas: Image.Image) -> Image.Image:
    if "glyph" in layer:
        return draw_well(layer["glyph"], layer_size(layer)[0])
    r = layer["rect"]
    sprite = atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
    return premultiplied_resize(sprite, layer_size(layer))


def with_opacity(image: Image.Image, opacity: float) -> Image.Image:
    if opacity >= 1:
        return image
    out = image.copy()
    out.putalpha(image.getchannel("A").point(lambda v: round(v * opacity)))
    return out


def plus_lighter(below: Image.Image, above: Image.Image) -> Image.Image:
    """CSS mix-blend-mode plus-lighter, the game's ADD: premultiplied colour and alpha summed, clamped."""
    a = below.convert("RGBa").split()
    b = above.convert("RGBa").split()
    return Image.merge("RGBa", [ImageChops.add(x, y) for x, y in zip(a, b)]).convert("RGBA")


def compose_rest(piece: Piece, images: dict[str, Image.Image], box: Sequence[int]) -> Image.Image:
    canvas = Image.new("RGBA", (box[0] * PX, box[1] * PX), (0, 0, 0, 0))
    for layer in piece.layers:
        opacity = rest_opacity(layer)
        if opacity <= 0:
            continue
        placed = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        placed.paste(with_opacity(images[layer["name"]], opacity), (px(layer["x"]), px(layer["y"])))
        canvas = plus_lighter(canvas, placed) if layer["blend"] == "ADD" else Image.alpha_composite(canvas, placed)
    return canvas


def webp_bytes(image: Image.Image) -> bytes:
    out = io.BytesIO()
    image.save(out, "WEBP", quality=WEBP_QUALITY, method=4)
    return out.getvalue()


# ------------------------------------------------------------------------------------------------- the crest's well

def draw_well(glyph: Path, size: int) -> Image.Image:
    """The well as the kit draws it round the item icon, holding a Pagle-drawn fish instead of the icon."""
    unit = size / 112
    cx, cy = 0.4 * size, 0.3 * size
    reach = math.hypot(size - cx, size - cy)  # `circle` sizes to the farthest corner
    ground = Image.new("RGB", (size, size))
    ground.putdata([gradient(math.hypot(x + 0.5 - cx, y + 0.5 - cy) / reach) for y in range(size) for x in range(size)])
    well = ground.convert("RGBA")

    colour, alpha, sigma = WELL_SHADOW
    margin = math.ceil(sigma * unit * 3)
    outside = Image.new("L", (size + 2 * margin, size + 2 * margin), 255)
    outside.paste(0, (margin, margin, margin + size, margin + size), disc(size))
    blurred = outside.filter(ImageFilter.GaussianBlur(sigma * unit)).crop((margin, margin, margin + size, margin + size))
    shadow = Image.new("RGBA", (size, size), (*colour, 0))
    shadow.putalpha(blurred.point(lambda v: round(v * alpha)))
    well = Image.alpha_composite(well, shadow)

    inset = (1 - WELL_GLYPH) / 2 * 112
    well = Image.alpha_composite(well, render_svg(glyph, size, scale=unit * WELL_GLYPH, offset=inset * unit))
    well.putalpha(ImageChops.multiply(well.getchannel("A"), disc(size)))
    return well


def gradient(t: float) -> tuple[int, int, int]:
    t = min(max(t, 0.0), 1.0)
    for (t0, c0), (t1, c1) in zip(WELL_STOPS, WELL_STOPS[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return (round(c0[0] + (c1[0] - c0[0]) * f), round(c0[1] + (c1[1] - c0[1]) * f),
                    round(c0[2] + (c1[2] - c0[2]) * f))
    return WELL_STOPS[-1][1]


SUPERSAMPLE = 4


def disc(size: int) -> Image.Image:
    big = Image.new("L", (size * SUPERSAMPLE, size * SUPERSAMPLE), 0)
    ImageDraw.Draw(big).ellipse((0, 0, size * SUPERSAMPLE - 1, size * SUPERSAMPLE - 1), fill=255)
    return big.reduce(SUPERSAMPLE)


def render_svg(path: Path, size: int, scale: float, offset: float) -> Image.Image:
    """The few SVG shapes the wells use: <path> (absolute M L H V C Q Z) and <circle>, with fill, stroke,
    stroke-width and opacity. Anything else is refused, so nothing is dropped silently."""
    big = size * SUPERSAMPLE
    k = scale * SUPERSAMPLE
    o = offset * SUPERSAMPLE
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    for element in ET.parse(path).getroot().iter():
        tag = element.tag.rsplit("}", 1)[-1]
        if tag == "svg":
            continue
        layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        fill = paint(element.get("fill", "#000"))
        stroke = paint(element.get("stroke", "none"))
        width = max(1, round(float(element.get("stroke-width", "1")) * k))
        if tag == "path":
            for points, closed in subpaths(element.get("d", "")):
                pts = [(o + x * k, o + y * k) for x, y in points]
                if fill and len(pts) >= 3:
                    draw.polygon(pts, fill=fill)
                if stroke:
                    draw.line(pts + pts[:1] if closed else pts, fill=stroke, width=width, joint="curve")
        elif tag == "circle":
            cx, cy, r = (float(element.get(a, "0")) for a in ("cx", "cy", "r"))
            box = (o + (cx - r) * k, o + (cy - r) * k, o + (cx + r) * k, o + (cy + r) * k)
            draw.ellipse(box, fill=fill, outline=stroke, width=width if stroke else 0)
        else:
            raise ValueError(f"{path.as_posix()}: <{tag}> is not drawn by the well renderer")
        out = Image.alpha_composite(out, with_opacity(layer, float(element.get("opacity", "1"))))
    return out.convert("RGBa").reduce(SUPERSAMPLE).convert("RGBA")


def paint(value: str) -> tuple[int, int, int] | None:
    return None if value == "none" else ImageColor.getrgb(value)[:3]


def subpaths(d: str) -> list[tuple[list[tuple[float, float]], bool]]:
    tokens = re.findall(r"[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:[eE]-?\d+)?", d)
    out: list[tuple[list[tuple[float, float]], bool]] = []
    points: list[tuple[float, float]] = []
    i = 0
    command = ""

    def nums(n: int) -> list[float]:
        nonlocal i
        values = [float(t) for t in tokens[i:i + n]]
        i += n
        return values

    while i < len(tokens):
        if tokens[i].isalpha():
            command = tokens[i]
            i += 1
        if command not in {"M", "L", "H", "V", "C", "Q", "Z"}:
            raise ValueError(f"path command {command!r} is not drawn by the well renderer (absolute M L H V C Q Z)")
        if command == "M":
            if len(points) > 1:
                out.append((points, False))
            x, y = nums(2)
            points = [(x, y)]
            command = "L"
        elif command == "L":
            x, y = nums(2)
            points.append((x, y))
        elif command == "H":
            points.append((nums(1)[0], points[-1][1]))
        elif command == "V":
            points.append((points[-1][0], nums(1)[0]))
        elif command == "C":
            x1, y1, x2, y2, x, y = nums(6)
            points += bezier(points[-1], (x1, y1), (x2, y2), (x, y))
        elif command == "Q":
            x1, y1, x, y = nums(4)
            p0 = points[-1]
            points += bezier(p0, (p0[0] + 2 / 3 * (x1 - p0[0]), p0[1] + 2 / 3 * (y1 - p0[1])),
                             (x + 2 / 3 * (x1 - x), y + 2 / 3 * (y1 - y)), (x, y))
        else:  # Z
            out.append((points, True))
            points = [points[0]]
            command = ""
    if len(points) > 1:
        out.append((points, False))
    return out


def bezier(p0: tuple[float, float], p1: tuple[float, float], p2: tuple[float, float], p3: tuple[float, float],
           steps: int = 24) -> list[tuple[float, float]]:
    pts = []
    for n in range(1, steps + 1):
        t = n / steps
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return pts


# ------------------------------------------------------------------------------------------------- motion

def rest_opacity(layer: Json) -> float:
    """The opacity a layer rests at: its first keyframe's, or art.json's restAlpha, or 1."""
    motion = layer.get("motion")
    if not motion:
        return 1.0
    for frame in motion["frames"]:
        if 0.0 in frame["at"] and "alpha" in frame:
            return float(frame["alpha"])
    return float(motion.get("restAlpha", 1.0))


def num(value: float) -> str:
    text = f"{round(value, 3):g}"
    return "0" if text == "-0" else text


def keyframes_base(name: str) -> str:
    """`pf-glow` -> `glow`, `lc-wingL` -> `wing-l`."""
    base = name.split("-", 1)[1] if "-" in name else name
    return re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", base).lower()


def components(frames: Sequence[Json]) -> list[str]:
    seen = {k for f in frames for k in f.get("transform", {})}
    return [c for c, keys in (("translate", ("x", "y")), ("rotate", ("rotate",)), ("scale", ("scale",)))
            if seen.intersection(keys)]


def transform_css(t: Json, comps: Sequence[str], layer: Json) -> str:
    """One keyframe's transform. Every keyframe lists the same functions, so they interpolate function by function.
    Translations are percentages of the layer's own box, so they scale with whatever size the site draws it at."""
    parts = []
    for c in comps:
        if c == "translate":
            parts.append(f"translate({num(t.get('x', 0.0) / layer['w'] * 100)}%, {num(t.get('y', 0.0) / layer['h'] * 100)}%)")
        elif c == "rotate":
            parts.append(f"rotate({num(t.get('rotate', 0.0))}deg)")
        else:
            sx, sy = t.get("scale", (1.0, 1.0))
            parts.append(f"scale({num(sx)}, {num(sy)})")
    return " ".join(parts)


def keyframes_name(piece: Piece, layer: Json) -> str:
    motion = layer["motion"]
    name = f"{piece.ns}-{keyframes_base(motion['keyframes'])}"
    # a translation is in the layer's own percentages, so two layers sharing one only share it at the same size
    return f"{name}-{layer['name']}" if "translate" in components(motion["frames"]) else name


def keyframes_css(name: str, layer: Json) -> str:
    frames = sorted(layer["motion"]["frames"], key=lambda f: min(f["at"]))
    comps = components(frames)
    lines = [f"@keyframes {name} {{"]
    for frame in frames:
        decls = []
        if "transform" in frame:
            decls.append(f"transform: {transform_css(frame['transform'], comps, layer)};")
        if "alpha" in frame:
            decls.append(f"opacity: {num(frame['alpha'])};")
        stops = ", ".join(f"{num(at * 100)}%" for at in sorted(frame["at"]))
        lines.append(f"  {stops} {{ {' '.join(decls)} }}")
    lines.append("}")
    return "\n".join(lines) + "\n"


def origin(layer: Json) -> tuple[float, float]:
    """art.json's transform origin (units in the box) as percentages of the layer's own box."""
    ox, oy = layer["motion"]["origin"]
    return (ox - layer["x"]) / layer["w"] * 100, (oy - layer["y"]) / layer["h"] * 100


def timing(layer: Json) -> Json:
    motion = layer["motion"]
    return {"duration": motion["duration"], "easing": motion["easing"], "delay": motion["delay"],
            "iterations": "infinite" if motion["loop"] else 1}


def piece_css(piece: Piece) -> str:
    title = piece.entry["name"]
    out = [f"/* {piece.key}: {title}. Written by scripts/export-web-art.py from data/art/prestige/art.json. */\n"]
    written: dict[str, str] = {}
    for layer in piece.layers:
        if not layer.get("motion"):
            continue
        name = keyframes_name(piece, layer)
        css = keyframes_css(name, layer)
        if written.setdefault(name, css) != css:
            raise ValueError(f"{piece.key}: two different @keyframes would both be {name}")
    out += written.values()
    for layer in piece.layers:
        if not layer.get("motion"):
            continue
        t = timing(layer)
        ox, oy = origin(layer)
        out.append(f".{piece.ns}-{layer['name']} {{ animation: {keyframes_name(piece, layer)} {num(t['duration'])}s "
                   f"{t['easing']} {num(t['delay'])}s {t['iterations']} both; transform-origin: {num(ox)}% {num(oy)}%; }}\n")
    return "\n".join(out)


# ------------------------------------------------------------------------------------------------- the files

def label(entry: Json) -> Json | None:
    lb = entry.get("label")
    return None if lb is None else {**lb, "letterSpacingEm": LABEL_LETTER_SPACING_EM}


def well_info(art: Json, piece: Piece) -> Json:
    return {**art["well"], "z": WELL_Z, "drawn": piece.kind == "legend-crest"}


def rect(layer: Json) -> Json:
    return {k: layer[k] for k in ("x", "y", "w", "h")}


def manifest(art: Json, piece: Piece) -> Json:
    layers = []
    for layer in piece.layers:
        motion = layer.get("motion")
        layers.append({
            "name": layer["name"], "file": f"{layer['name']}.webp", "rect": rect(layer), "z": layer["z"],
            "blend": "add" if layer["blend"] == "ADD" else "normal", "opacity": rest_opacity(layer),
            "animation": keyframes_name(piece, layer) if motion else None,
            "class": f"{piece.ns}-{layer['name']}" if motion else None,
            "timing": timing(layer) if motion else None,
        })
    box_w, box_h = art["box"]
    return {"key": piece.key, "kind": piece.kind, "name": piece.entry["name"], "box": {"w": box_w, "h": box_h},
            "scale": PX, "rest": f"{piece.key}.webp", "css": f"{piece.key}.css", "well": well_info(art, piece),
            "label": label(piece.entry), "layers": layers}


def json_bytes(data: Json) -> bytes:
    return (json.dumps(data, indent=1, ensure_ascii=False) + "\n").encode("utf-8")


def export(art_dir: Path, out_dir: Path, only: Iterable[str] | None = None) -> list[Path]:
    """Writes the web art for every piece and emblem (or only those keyed in `only`); returns the files written."""
    art = load_art(art_dir)
    wanted = set(only) if only is not None else None
    all_pieces = pieces(art, art_dir)
    known = {p.key for p in all_pieces} | {k for k, _ in emblem_keys()}
    if wanted is not None and wanted - known:
        raise ValueError(f"no such piece: {', '.join(sorted(wanted - known))}")
    written: list[Path] = []

    def write(path: Path, content: bytes) -> None:
        write_atomic(path, content)
        written.append(path)

    index: Json = {"source": "data/art/prestige/art.json", "box": {"w": art["box"][0], "h": art["box"][1]},
                   "scale": PX, "pieces": [], "emblems": []}
    for piece in all_pieces:
        if wanted is not None and piece.key not in wanted:
            continue
        with Image.open(piece.atlas) as opened:
            atlas = opened.convert("RGBA")
        images = {layer["name"]: layer_image(layer, atlas) for layer in piece.layers}
        if len(images) != len(piece.layers):
            raise ValueError(f"{piece.key}: two layers share a name")
        write(out_dir / f"{piece.key}.webp", webp_bytes(compose_rest(piece, images, art["box"])))
        if piece.animated:
            folder = out_dir / piece.key
            for layer in piece.layers:
                write(folder / f"{layer['name']}.webp", webp_bytes(images[layer["name"]]))
            write(folder / "manifest.json", json_bytes(manifest(art, piece)))
            write(folder / f"{piece.key}.css", piece_css(piece).encode("utf-8"))
        entry = piece.entry
        index["pieces"].append({
            "key": piece.key, "kind": piece.kind, "name": entry["name"], "description": entry["description"],
            "motionSummary": entry["motionSummary"], "rank": entry.get("rank"), "item": entry.get("item"),
            "rest": f"{piece.key}.webp", "animated": f"{piece.key}/" if piece.animated else None,
            "well": well_info(art, piece), "label": label(entry),
        })

    emblems = art["emblems"]
    with Image.open(atlas_path(art_dir, emblems["atlas"])) as opened:
        atlas = opened.convert("RGBA")
    for key, sprite in emblem_keys():
        if wanted is not None and key not in wanted:
            continue
        r = emblems["sprites"][sprite]
        image = atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        files = {}
        for size in EMBLEM_SIZES:
            name = f"{key}-{size}.webp"
            write(out_dir / name, webp_bytes(premultiplied_resize(image, (size * PX, size * PX))))
            files[str(size)] = name
        index["emblems"].append({"key": key, "files": files})

    write(out_dir / "index.json", json_bytes(index))
    return written
