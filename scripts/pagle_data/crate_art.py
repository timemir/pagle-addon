"""The Curio crate's art kit (wallet-and-shop.md › Motion, "A crate opens"), drawn into one Core atlas from the
prototype's vector art: the crate in parts, the plaque, the reel, the cards, the kinds' emblems, the Curio card, the coin
card and the effects.

The sources are the SVGs in data/art/crate/src/: the prototype's own drawings, verbatim where it draws in SVG
(prototypes/curio-crate/crate-svg.js, the emblems and glyphs in crate.js, the bobber and hook in index.html), and its CSS
(the reel's frame, the cards, the light, the dust) written out as SVG with the CSS's own numbers, in px. The fans of rays,
which SVG can't draw, are drawn here from the CSS's repeating-conic-gradient and its radial mask. Everything is rasterised
by resvg (the resvg-py wheel pinned in scripts/tools.env), drawn at 1 prototype px = 0.8 UI units, the unit the spec's
Motion row gives the crate in (256 x 214 for the prototype's 320 x 268), and stored at 1.5 texels a UI unit; the pieces a
card turns over to (the cards, the emblems) at 1.5 times that, so the hero card at 1.5 x is as sharp as the reel's, and the
smooth ones (light, glows, rays) at a fraction of it.

A tinted piece is white or grey, for SetVertexColor to give the tier's colour: a card's glow and ring and foot (card-tint)
are white, and an emblem is its grey metal (a gradient from 1 to .55, its engraving at .28, exactly the prototype's
light, tier and dark metal once multiplied by the tier's colour) with its highlight (the lighter part of the metal, a white
layer, `-hi`) over it. A piece whose peak alpha is under 1 in the prototype (the rays, the sheen, the light) is stored at
full alpha and its sprite says what to draw it at (`alpha`).

Each sprite in data/CrateArt.lua has its texels (x, y, w, h), `box` (the drawn element inside it, in UI units, from its
top left, the rest being shadow or glow), `size` (its designed size in UI units: w / 1.5 for the standard pieces, but not
for the ones stored at another density), `at` (where its top left lies in UI units from the piece's `anchor`: the crate's,
the reel's, the card's top left, a marker's top left, or the middle of an effect), `use` (what it is for: "tint" for
SetVertexColor, "add" for additive blending, "fixed" for its own colours, "cap" and "slice" for the two ends of a
stretched strip, "mirror" for one that is flipped for the other end), and `alpha` where it is to be drawn at less than full.

The command line is scripts/crate-art.py. The atlas is committed lossless (data/art/crate/tga/Crate.tga), its BLP
(addons/Pagle/media/crate/Crate.blp, DXT5 with its mipmaps, by scripts/encode-blp.py --mips) and its sprite table.
"""

import importlib.util
import io
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import numpy.typing as npt
from PIL import Image, ImageDraw
from scipy import ndimage

Pixels = npt.NDArray[np.float32]  # rows of RGBA texels, straight alpha, 0 to 1

ART_DIR = Path("data/art/crate")
SRC_DIR = ART_DIR / "src"
ATLAS_TGA = ART_DIR / "tga" / "Crate.tga"
MEDIA_DIR = Path("addons/Pagle/media/crate")
ATLAS_BLP = MEDIA_DIR / "Crate.blp"
ART_LUA = Path("addons/Pagle/data/CrateArt.lua")
FONT = Path("addons/Pagle/media/fonts/Marcellus-Regular.ttf")

UI = 0.8  # UI units to a prototype px: the spec's crate is 256 x 214 units for the prototype's 320 x 268 px
SCALE = 1.5  # texels to a UI unit in the atlas
STD = SCALE * UI  # texels to a prototype px
BIG = 1.5 * STD  # the cards, emblems and Curio card, drawn for the hero card at 1.5 times
GUTTER = 2  # clear texels round each sprite, as the shop's atlases leave
ATLAS_SIZES = [(1024, 1024), (2048, 512), (2048, 1024)]  # the smallest that holds the sprites is used
ALPHA_MIN = 3 / 255  # a texel under this is clear, and trimmed from a sprite's edge

Bounds = tuple[float, float, float, float]


@dataclass
class Sprite:
    name: str
    pixels: Pixels
    at: tuple[float, float]  # UI units from the anchor
    box: tuple[float, float, float, float]  # UI units, from the sprite's top left
    anchor: str
    use: str
    alpha: float | None = None
    tint: tuple[int, int, int] | None = None
    size: tuple[float, float] = (0.0, 0.0)  # UI units
    note: str = ""
    x: int = 0
    y: int = 0

    @property
    def w(self) -> int:
        return int(self.pixels.shape[1])

    @property
    def h(self) -> int:
        return int(self.pixels.shape[0])


# ---------- rasterising ----------


def _resvg() -> Any:
    try:
        import resvg_py  # noqa: PLC0415 (only drawing needs it: the pack, the tests and the checks read the committed atlas)
    except ImportError as error:
        raise SystemExit(
            "crate-art: needs resvg-py (PYTHON_PACKAGES in scripts/tools.env); run scripts/setup.sh, then "
            ".tools/bin/python scripts/crate-art.py"
        ) from error
    return resvg_py


def rasterise(svg: str, bounds: Bounds, density: float, root: Path) -> Pixels:
    """`svg` drawn over `bounds` (source px, x0, y0, x1, y1) at `density` texels a px, with the repo's Marcellus for any
    text; its own width, height and viewBox are replaced."""
    x0, y0, x1, y1 = bounds
    w, h = round((x1 - x0) * density), round((y1 - y0) * density)
    root_tag = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:g} {y0:g} {x1 - x0:g} {y1 - y0:g}" '
        f'width="{w}" height="{h}" preserveAspectRatio="none">'
    )
    svg = re.sub(r"<svg\b[^>]*>", root_tag, svg, count=1)
    png = _resvg().svg_to_bytes(
        svg_string=svg, font_files=[str(root / FONT)], skip_system_fonts=True, font_family="Marcellus"
    )
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    return np.asarray(image, dtype=np.float32) / 255.0


def _source(root: Path, name: str) -> str:
    return (root / SRC_DIR / f"{name}.svg").read_text(encoding="utf-8")


def _view_box(svg: str) -> Bounds:
    match = re.search(r'viewBox="([-\d.\s]+)"', svg)
    assert match, "no viewBox"
    x, y, w, h = (float(v) for v in match.group(1).split())
    return x, y, x + w, y + h


def _alpha_box(pixels: Pixels, threshold: float) -> tuple[int, int, int, int] | None:
    """The rows and columns the alpha reaches `threshold` in: top, bottom, left, right (exclusive), or None."""
    solid = pixels[:, :, 3] >= threshold
    if not solid.any():
        return None
    rows, cols = np.where(solid.any(axis=1))[0], np.where(solid.any(axis=0))[0]
    return int(rows[0]), int(rows[-1]) + 1, int(cols[0]), int(cols[-1]) + 1


def _round(value: float) -> float:
    return round(value + 0.0, 2)


def piece(
    name: str,
    pixels: Pixels,
    bounds: Bounds,
    density: float,
    anchor: str,
    use: str,
    *,
    core: Pixels | None = None,
    trim: bool = True,
    normalise: bool = False,
    draw_at: float | None = None,
    rect: tuple[float, float, float, float] | None = None,
    tint: tuple[int, int, int] | None = None,
    note: str = "",
) -> Sprite:
    """A sprite from `pixels` drawn over `bounds` at `density`, trimmed of clear edges (unless `trim` is off) with the
    position it keeps, and its `box` found in `core` (the same drawing without its shadow) or in itself, or given as
    `rect` (x, y, w, h in px from the anchor: what a glow or a shadow is round). `normalise` stores a piece at full alpha
    and records the alpha it peaks at; such a soft piece is all glow, so its box is all of it unless `rect` says. `draw_at`
    records an alpha a piece drawn at full strength is for."""
    x0, y0, _, _ = bounds
    alpha: float | None = None
    if normalise:
        peak = float(pixels[:, :, 3].max())
        pixels = pixels.copy()
        pixels[:, :, 3] /= peak
        alpha = _round(peak)
    if draw_at is not None:
        alpha = draw_at
    top, left = 0, 0
    if trim:
        found = _alpha_box(pixels, ALPHA_MIN)
        assert found, f"{name} is clear"
        t, b, l, r = found
        top, left = max(t - 1, 0), max(l - 1, 0)
        pixels = pixels[top : min(b + 1, pixels.shape[0]), left : min(r + 1, pixels.shape[1])]
        if core is not None:
            core = core[top : top + pixels.shape[0], left : left + pixels.shape[1]]
    source = pixels if core is None else core
    solid = _alpha_box(source, 0.5)
    if solid is None or (normalise and core is None):
        solid = (0, source.shape[0], 0, source.shape[1])
    box = (
        _round(solid[2] / density * UI),
        _round(solid[0] / density * UI),
        _round((solid[3] - solid[2]) / density * UI),
        _round((solid[1] - solid[0]) / density * UI),
    )
    at = (_round((x0 + left / density) * UI), _round((y0 + top / density) * UI))
    if rect is not None:
        box = (_round(rect[0] * UI - at[0]), _round(rect[1] * UI - at[1]), _round(rect[2] * UI), _round(rect[3] * UI))
    size = (_round(pixels.shape[1] / density * UI), _round(pixels.shape[0] / density * UI))
    return Sprite(name, pixels, at, box, anchor, use, alpha, tint, size, note)


def _plain(root: Path, name: str, stem: str, density: float, anchor: str, use: str, **kwargs: Any) -> Sprite:
    """A sprite from the source `stem`, drawn over its viewBox (or `bounds`, in the source's units); `place` is where
    those bounds' top left lies from the anchor, in px, where it isn't at the anchor itself."""
    svg = _source(root, stem)
    view: Bounds = kwargs.pop("bounds", None) or _view_box(svg)
    place: tuple[float, float] | None = kwargs.pop("place", None)
    lay = view if place is None else (place[0], place[1], place[0] + view[2] - view[0], place[1] + view[3] - view[1])
    return piece(name, rasterise(svg, view, density, root), lay, density, anchor, use, **kwargs)


# ---------- the crate ----------

CRATE_BOUNDS: dict[str, Bounds] = {
    "crate-body": (-50, 40, 370, 310),
    "crate-lid": (-30, 0, 350, 150),
    "crate-seal-left": (-20, -20, 90, 90),
    "crate-seal-right": (-20, -20, 90, 90),
    "crate-ribbon": (-5, -5, 75, 65),
}
# The seal's halves and the ribbon sit on the crate where the prototype puts them (#crate .seal, .ribbon): the offsets of
# their own 70 px boxes from the crate's top left, which `at` is measured from.
CRATE_OFFSET: dict[str, tuple[float, float]] = {
    "crate-seal-left": (125, 62),
    "crate-seal-right": (125, 62),
    "crate-ribbon": (125, 108),
}


def crate_parts(root: Path) -> list[Sprite]:
    sprites = []
    for stem, bounds in CRATE_BOUNDS.items():
        svg = _source(root, stem)
        dx, dy = CRATE_OFFSET.get(stem, (0, 0))
        placed = (bounds[0] + dx, bounds[1] + dy, bounds[2] + dx, bounds[3] + dy)
        shadowed = rasterise(svg, bounds, STD, root)
        flat = rasterise(svg.replace('filter="url(#ds)"', ""), bounds, STD, root)
        sprites.append(piece(stem, shadowed, placed, STD, "crate", "fixed", core=flat))
    return sprites


# ---------- the plaque and the reel ----------


def _slices(name: str, pixels: Pixels, bounds: Bounds, density: float, anchor: str, cap_px: float, mid_px: float,
            mid_at: float) -> list[Sprite]:
    """A strip's left cap (the first `cap_px` of it) and a slice of its middle, `mid_px` wide from `mid_at`, both its full
    height: the cap is flipped for the right end, the slice stretched."""
    x0, y0, x1, y1 = bounds
    cap = round(cap_px * density)
    mid = round((mid_at - x0) * density)
    width = max(1, round(mid_px * density))
    return [
        piece(f"{name}-cap", pixels[:, :cap], (x0, y0, x0 + cap_px, y1), density, anchor, "cap mirror", trim=False),
        piece(f"{name}-mid", pixels[:, mid : mid + width], (mid_at, y0, mid_at + width / density, y1), density, anchor,
              "slice", trim=False),
    ]


def reel_parts(root: Path) -> list[Sprite]:
    svg = _source(root, "reel-frame")
    bounds = (-40.0, -24.0, 440.0, 272.0)
    frame = rasterise(svg, bounds, STD, root)
    sprites = _slices("reel-frame", frame, bounds, STD, "reel", 80, 8 / STD, 196)
    # The drawn frame, not its shadow, is the box: 0,0 of the reel, 212 px tall.
    for sprite in sprites:
        sprite.box = (0.0, _round(24 * UI), sprite.box[2], _round(212 * UI))
    sprites[0].box = (_round(40 * UI), _round(24 * UI), _round(40 * UI), _round(212 * UI))
    fade = rasterise(_source(root, "reel-fade"), (0, 0, 150, 8), 0.5, root)
    sprites.append(piece("reel-fade", fade, (0, 0, 150, 8), 0.5, "reel", "fixed mirror", trim=False,
                         note="stretch it down the window; flipped for the right end"))
    sprites.append(_plain(root, "reel-line", "reel-marker", STD, "line", "fixed", bounds=(-14, -14, 16, 234)))
    sprites.append(_plain(root, "reel-line-glow", "reel-line-glow", 0.5, "line", "tint add", normalise=True,
                          trim=False, rect=(-1, 0, 2, 220)))
    sprites.append(_plain(root, "reel-bobber", "reel-bobber", STD, "bobber", "fixed", bounds=(-4, -4, 30, 44)))
    sprites.append(_plain(root, "reel-hook", "reel-hook", STD, "hook", "fixed", bounds=(-4, -4, 26, 42)))
    sprites.append(_plain(root, "reel-light", "reel-light", 0.5, "reel", "tint add", normalise=True, trim=False))
    return sprites


def plaque_parts(root: Path) -> list[Sprite]:
    svg = _source(root, "plaque")
    bounds = (-6.0, -6.0, 246.0, 47.0)
    plaque = rasterise(svg, bounds, STD, root)
    sprites = _slices("plaque", plaque, bounds, STD, "plaque", 20, 5 / STD, 100)
    return sprites


# ---------- the cards ----------

CARD = (0.0, 0.0, 150.0, 172.0)


def card_parts(root: Path) -> list[Sprite]:
    def whole(name: str, stem: str, density: float, use: str, **kwargs: Any) -> Sprite:
        return _plain(root, name, stem, density, "card", use, bounds=kwargs.pop("bounds", CARD), **kwargs)

    return [
        whole("card-base", "card-base", BIG, "fixed", trim=False),
        whole("card-shadow", "card-shadow", 0.6, "fixed", bounds=(-20, -14, 170, 196), rect=(0, 0, 150, 172)),
        whole("card-tint", "card-tint", BIG, "tint", trim=False),
        whole("card-hatch", "card-hatch", 0.9, "tint", trim=False, draw_at=0.06,
              note="over card-base: for a card that shows a kind, not the good"),
        whole("card-sheen", "card-sheen", 0.6, "fixed", trim=False, draw_at=0.1,
              note="the Curio card's shimmer is this band at up to .65, moving across"),
        whole("card-glow", "card-glow", 0.6, "tint add", bounds=(-40, -40, 190, 212), normalise=True, trim=False,
              rect=(0, 0, 150, 172)),
        whole("card-curio", "card-curio", BIG, "fixed", trim=False),
        whole("card-coin", "card-coin", BIG, "fixed", trim=False,
              note="new: what a crate that pays Coins back turns over to; not in the prototype"),
    ]


# ---------- the emblems ----------

EMBLEMS = ("toast", "book", "sound", "tracker", "coin")
HL_ELEMENT = re.compile(r"<[a-z]+\b[^>]*\bclass=\"hl\"[^>]*/>")
# The prototype paints each emblem's metal with one gradient per element (x1 0, y1 0, x2 .6, y2 1) from the tier's light
# (mix(c, 255, .75)) at 0 through the tier (c) at .45 to its dark (mix(c, 0, .45)) at 1, and its engraving in mix(c, 0, .72).
# Multiplied by the tier's colour, a grey of 1 to .55 is the tier to its dark and .28 is the engraving, and the light is
# the tier's colour lightened by a white's alpha of .75 falling to 0 at .45: so the emblem is two drawings, the grey metal
# and the glint, the second drawn as greys (its level at a texel is the alpha) and read as alpha.
METAL = '<stop offset="0" stop-color="#fff"/><stop offset=".45" stop-color="#fff"/><stop offset="1" stop-color="#8c8c8c"/>'
GLINT = '<stop offset="0" stop-color="#bfbfbf"/><stop offset=".45" stop-color="#000"/><stop offset="1" stop-color="#000"/>'
ENGRAVING = "#474747"
SHADOW = '<filter id="ds" filterUnits="userSpaceOnUse" x="-10" y="-10" width="120" height="120"><feDropShadow dx="0" dy="3.85" stdDeviation="1.92" flood-color="#000" flood-opacity=".6"/></filter>'
EMBLEM_VIEW: Bounds = (-8.0, -8.0, 108.0, 112.0)  # in the emblem's own 100 units
EMBLEM_PX = 1.04  # a card draws those 100 units at 104 px
EMBLEM_AT = (23.0, 14.0)  # and puts its top left 23 px in and 14 down


def _emblem_svg(template: str, fill: str, dark: str, stops: str, glint: bool, shadow: bool) -> str:
    body = re.sub(r"<svg\b[^>]*>|</svg>", "", template)
    body = HL_ELEMENT.sub(lambda m: m.group(0) if glint else "", body)
    body = body.replace("FILL", fill).replace("DARK", dark)
    if shadow:
        body = f'<g filter="url(#ds)">{body}</g>'
    defs = f'<defs><linearGradient id="m" x1="0" y1="0" x2=".6" y2="1">{stops}</linearGradient>{SHADOW}</defs>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">{defs}{body}</svg>'


def emblem_parts(root: Path) -> list[Sprite]:
    x0, y0, x1, y1 = EMBLEM_VIEW
    # Where the drawn view lies on a card, in card px, for `at`.
    on_card: Bounds = (
        EMBLEM_AT[0] + x0 * EMBLEM_PX,
        EMBLEM_AT[1] + y0 * EMBLEM_PX,
        EMBLEM_AT[0] + x1 * EMBLEM_PX,
        EMBLEM_AT[1] + y1 * EMBLEM_PX,
    )
    sprites = []
    for kind in EMBLEMS:
        template = _source(root, f"emblem-{kind}")

        def draw(fill: str, dark: str, stops: str, glint: bool, shadow: bool) -> Pixels:
            return rasterise(_emblem_svg(template, fill, dark, stops, glint, shadow), EMBLEM_VIEW, BIG * EMBLEM_PX, root)

        metal = draw("url(#m)", ENGRAVING, METAL, False, True)
        flat = draw("url(#m)", ENGRAVING, METAL, False, False)
        lit = draw("url(#m)", "#000", GLINT, True, False)
        hi = np.ones_like(lit)
        hi[:, :, 3] = lit[:, :, 3] * lit[:, :, :3].mean(axis=2)
        sprites.append(piece(f"emblem-{kind}", metal, on_card, BIG, "card", "tint", core=flat))
        sprites.append(piece(f"emblem-{kind}-hi", hi, on_card, BIG, "card", "fixed"))
    return sprites


def glyph_parts(root: Path) -> list[Sprite]:
    return [
        _plain(root, f"kind-{kind}", "kind-glyphs", BIG, "card", "fixed", bounds=(20.0 * i, 0.0, 20.0 * i + 18, 18.0),
               place=(8.0, 8.0), note="draw at alpha .55")
        for i, kind in enumerate(("toast", "book", "sound"))
    ]


# ---------- the effects ----------


def _conic(period: float, on: float, start: float, stops: list[tuple[float, float]], box: float, extent: float,
           density: float, base: float) -> Pixels:
    """A repeating conic gradient (`on` degrees of `base` alpha every `period`, from `start` degrees clockwise of
    the top) under a radial mask (alpha by distance, from `stops` as fractions of the farthest corner of a `box` px square),
    over the `extent` px square round its centre. White; the colour is the tint's."""
    n = round(extent * density)
    sub = 4  # texels an edge is averaged from, a side
    axis = (np.arange(n * sub, dtype=np.float64) + 0.5) / (n * sub) * extent - extent / 2
    x, y = np.meshgrid(axis, axis)
    angle = (np.degrees(np.arctan2(x, -y)) - start) % 360.0
    stripe = ((angle % period) < on).astype(np.float64)
    reach = np.hypot(x, y) / (box / 2 * math.sqrt(2))
    mask = np.interp(reach, [s for s, _ in stops], [a for _, a in stops])
    alpha = (stripe * mask * base).reshape(n, sub, n, sub).mean(axis=(1, 3))
    out = np.ones((n, n, 4), dtype=np.float32)
    out[:, :, 3] = alpha.astype(np.float32)
    return out


def ray_parts(root: Path) -> list[Sprite]:
    del root
    sprites = []
    # The crate's rays (.rays): 5 degrees of rgba(255,214,120,.16) in every 15, from the top, over a 1300 px square,
    # masked radial-gradient(circle, #000, rgba(0,0,0,.6) 24%, transparent 55%); the reveal's two (.rays2 a and b):
    # tier/.3, 4 degrees in 12, over 1100 px, mask 18% / 50%; and tier/.16, 2 in 9 from 3 degrees, mask .5 at 26%, 56%.
    for name, args, tint, note in (
        ("rays-crate", (15, 5, 0, [(0, 1.0), (0.24, 0.6), (0.55, 0.0)], 1300, 1012, 0.3, 0.16), (255, 214, 120),
         "behind the crate and the reel; one turn in 40 s"),
        ("rays-a", (12, 4, 0, [(0, 1.0), (0.18, 0.6), (0.5, 0.0)], 1100, 780, 0.3, 0.3), None,
         "the reveal's first fan: tint to the tier; one turn in 14 s"),
        ("rays-b", (9, 2, 3, [(0, 1.0), (0.26, 0.5), (0.56, 0.0)], 1100, 874, 0.3, 0.16), None,
         "the reveal's second fan, turning the other way: tint to the tier; one turn in 22 s"),
    ):
        period, on, start, stops, box, extent, density, base = args
        pixels = _conic(period, on, start, stops, box, extent, density, base)
        half = extent / 2
        sprites.append(piece(name, pixels, (-half, -half, half, half), density, "centre", "tint add", trim=False,
                             normalise=True, tint=tint, note=note))
    return sprites


def effect_parts(root: Path) -> list[Sprite]:
    def fx(name: str, stem: str, density: float, use: str, anchor: str = "box", **kwargs: Any) -> Sprite:
        return _plain(root, name, stem, density, anchor, use, **kwargs)

    return [
        fx("fx-dust", "fx-dust", STD, "fixed", normalise=True, note="a 90 x 40 px puff: draw at alpha .55"),
        fx("fx-straw", "fx-straw", BIG, "fixed"),
        fx("fx-spark", "fx-spark", BIG, "tint add", note="a 6 px dot with its glow: tint to the tier"),
        fx("fx-ember", "fx-ember", BIG, "tint add", note="a 6 px dot with a softer glow: tint to the tier"),
        fx("fx-burst", "fx-burst", 0.4, "add", normalise=True, trim=False),
        fx("fx-beam", "fx-beam", 0.5, "add", normalise=True, trim=False),
        fx("fx-halo", "fx-halo", 0.25, "tint add", anchor="centre", normalise=True, trim=False),
        fx("fx-seal-glow", "fx-seal-glow", 1.0, "add", normalise=True, trim=False),
        fx("fx-flash", "fx-flash", 1.0, "add", trim=False, note="stretch it over the case; the flash is .7 to .8"),
        fx("fx-coin", "fx-coin", BIG, "fixed"),
    ]


# ---------- the atlas ----------


def all_sprites(root: Path) -> list[Sprite]:
    sprites = [
        *crate_parts(root),
        *plaque_parts(root),
        *reel_parts(root),
        *card_parts(root),
        *emblem_parts(root),
        *glyph_parts(root),
        *ray_parts(root),
        *effect_parts(root),
    ]
    names = [s.name for s in sprites]
    assert len(names) == len(set(names)), "a sprite is named twice"
    return sprites


def pack(sprites: list[Sprite]) -> tuple[int, int]:
    """Places each sprite (its x, y) on shelves, tallest first, with GUTTER clear texels between and round them, in the
    smallest of ATLAS_SIZES that holds them, and returns that size."""
    for width, height in sorted(ATLAS_SIZES, key=lambda s: (s[0] * s[1], -s[0])):
        x = y = shelf = GUTTER
        ok = True
        for sprite in sorted(sprites, key=lambda s: (-s.h, -s.w, s.name)):
            if x + sprite.w + GUTTER > width:
                x, y = GUTTER, y + shelf + GUTTER
                shelf = 0
            if sprite.w + 2 * GUTTER > width or y + sprite.h + GUTTER > height:
                ok = False
                break
            sprite.x, sprite.y = x, y
            x += sprite.w + GUTTER
            shelf = max(shelf, sprite.h)
        if ok:
            return width, height
    raise SystemExit("crate-art: the sprites don't fit in 2048 x 1024")


def bleed(rgba: npt.NDArray[np.uint8]) -> npt.NDArray[np.uint8]:
    """Colour in the clear texels from the nearest texel with some, so DXT5's blocks and the mipmaps keep clean edges."""
    out = rgba.copy()
    clear = out[:, :, 3] == 0
    if clear.any() and not clear.all():
        _, (iy, ix) = ndimage.distance_transform_edt(clear, return_indices=True)
        out[:, :, :3] = out[iy, ix, :3]
    return out


def atlas_image(sprites: list[Sprite], width: int, height: int) -> Image.Image:
    canvas = np.zeros((height, width, 4), dtype=np.uint8)
    for s in sprites:
        canvas[s.y : s.y + s.h, s.x : s.x + s.w] = np.clip(np.rint(s.pixels * 255.0), 0, 255).astype(np.uint8)
    return Image.fromarray(bleed(canvas), "RGBA")


# ---------- the sprite table ----------


def _number(value: float) -> str:
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return text if text not in ("-0", "") else "0"


def _list(values: tuple[float, ...]) -> str:
    return "{ " + ", ".join(_number(v) for v in values) + " }"


LUA_HEADER = '''---@class PagleNS
local ns = select(2, ...)

-- The Curio crate's art kit (wallet-and-shop.md › Motion, "A crate opens"), added to ns.ATLASES as "Crate": where each
-- sprite sits in its texture under media/crate/. Generated by scripts/crate-art.py from the prototype's art in
-- data/art/crate/src/ (prototypes/curio-crate/); don't edit by hand. Rectangles are in texels, `scale` texels per UI unit
-- (the prototype's px are 0.8 UI units, the unit the spec's Motion row gives the crate in). `box` is the drawn element
-- inside its sprite in UI units (x, y from the sprite's top left, then w, h), the rest being its shadow or glow; `size` is
-- the sprite's designed size in UI units, which is w and h over `scale` for all but the cards, emblems and Curio card (kept
-- at 1.5 times that, for the hero card at 1.5 x) and the smooth effects (kept at a fraction, so stretched); `at` is where its
-- top left lies in UI units from its `anchor`, the top left of the crate (the 256 x 214 box its parts are drawn in), of
-- the reel, of a card (120 x 138), of the plaque, of the line, the bobber or the hook, or the middle of an
-- effect that centres on a point; `use` says what it is for: "tint" (white or grey, SetVertexColor gives it the tier's
-- colour), "add" (additive blending), "fixed" (its own colours), "cap" (a strip's left end, "mirror"ed for its right) and
-- "slice" (the strip's middle, to stretch); `alpha` is the opacity to draw a sprite stored at full alpha at, and `tint`
-- the colour it is drawn in when not a tier's. The texture is a BLP (BLP2, DXT5, with its full mip chain) made from
-- data/art/crate/tga/Crate.tga by scripts/encode-blp.py --mips.
--   rays-crate, rays-a, rays-b: the fans, one turn in 40, 14 and 22 s; each is square, centred on its anchor.
--   emblem-<kind>: the kind's metal in grey, with emblem-<kind>-hi, its lighter part, in white over it: tint the first
--     only (the highlight is the white that lightens the tier's colour).
--   card-base, card-tint, card-hatch, card-sheen: a card is the base, the tier's glow, ring and foot (tinted), and for a
--     card showing only its kind the hatching at .06, the emblem over it, and the sheen at .1.

local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\crate\\\\"

ns.ATLASES = ns.ATLASES or {}

---@type PagleAtlas
ns.ATLASES.Crate = {
	file = DIR .. "Crate",
	width = %(width)d,
	height = %(height)d,
	scale = %(scale)s,
	sprites = {
'''


def lua_table(sprites: list[Sprite], width: int, height: int) -> str:
    lines = [LUA_HEADER % {"width": width, "height": height, "scale": _number(SCALE)}]
    for s in sorted(sprites, key=lambda s: s.name):
        fields = [f"x = {s.x}", f"y = {s.y}", f"w = {s.w}", f"h = {s.h}", f"box = {_list(s.box)}",
                  f"size = {_list(s.size)}", f"at = {_list(s.at)}", f'anchor = "{s.anchor}"', f'use = "{s.use}"']
        if s.alpha is not None:
            fields.append(f"alpha = {_number(s.alpha)}")
        if s.tint:
            fields.append(f"tint = {_list(tuple(float(c) for c in s.tint))}")
        lines.append(f'\t\t["{s.name}"] = {{ {", ".join(fields)} }},\n')
    lines.append("\t},\n}\n")
    return "".join(lines)


# ---------- the commands ----------


def _blp_encoder(root: Path) -> Any:
    spec = importlib.util.spec_from_file_location("encode_blp", root / "scripts" / "encode-blp.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build(root: Path) -> list[Path]:
    """Draws the kit and writes data/art/crate/tga/Crate.tga, addons/Pagle/media/crate/Crate.blp and
    addons/Pagle/data/CrateArt.lua (not yet through StyLua), returning them."""
    sprites = all_sprites(root)
    width, height = pack(sprites)
    image = atlas_image(sprites, width, height)
    tga = root / ATLAS_TGA
    tga.parent.mkdir(parents=True, exist_ok=True)
    image.save(tga, compression="tga_rle")
    blp = root / ATLAS_BLP
    blp.parent.mkdir(parents=True, exist_ok=True)
    _blp_encoder(root).encode_mipped(tga, blp)
    lua = root / ART_LUA
    lua.write_text(lua_table(sprites, width, height), encoding="utf-8", newline="\n")
    return [tga, blp, lua]


TIER_COLOURS = [(233, 230, 223), (62, 211, 90), (59, 134, 255), (176, 92, 255), (236, 58, 63), (255, 138, 28),
                (255, 208, 74)]  # the Tunables' crate tiers 1 to 6, then Curio


class Stage:
    """A canvas the sprites are put on as the prototype puts them, to see them together: positions in UI units (a sprite's
    `at` from where its anchor is put), drawn at `scale` texels a unit."""

    def __init__(self, width: float, height: float, scale: float, back: tuple[int, int, int] = (22, 18, 14)) -> None:
        self.scale = scale
        self.image = Image.new("RGBA", (round(width * scale), round(height * scale)), (*back, 255))

    def put(self, sprite: Sprite, x: float, y: float, *, tint: tuple[int, int, int] | None = None, alpha: float | None = None,
            add: bool = False, mirror: float | None = None, size: tuple[float, float] | None = None,
            grow: float = 1.0, place: tuple[float, float] | None = None) -> None:
        px = sprite.pixels.copy()
        colour = tint or sprite.tint
        if colour:
            px[:, :, :3] *= np.array(colour, dtype=np.float32) / 255.0
        px[:, :, 3] *= sprite.alpha if alpha is None and sprite.alpha is not None else (1.0 if alpha is None else alpha)
        art = Image.fromarray(np.clip(np.rint(px * 255), 0, 255).astype(np.uint8), "RGBA")
        w, h = size or (sprite.size[0] * grow, sprite.size[1] * grow)
        art = art.resize((max(1, round(w * self.scale)), max(1, round(h * self.scale))), Image.Resampling.LANCZOS)
        left, top = x + sprite.at[0] * grow, y + sprite.at[1] * grow
        if mirror is not None:
            art = art.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            left = mirror - sprite.at[0] - w
        if place is not None:
            left, top = place
        at = (round(left * self.scale), round(top * self.scale))
        if add:
            under = np.asarray(self.image, dtype=np.float32).copy()
            layer = np.asarray(Image.new("RGBA", self.image.size).copy(), dtype=np.float32)
            layer[:] = 0
            box = art.crop((max(0, -at[0]), max(0, -at[1]), art.width, art.height))
            x0, y0 = max(at[0], 0), max(at[1], 0)
            part = np.asarray(box, dtype=np.float32)[: self.image.height - y0, : self.image.width - x0]
            under[y0 : y0 + part.shape[0], x0 : x0 + part.shape[1], :3] += part[:, :, :3] * part[:, :, 3:] / 255.0
            self.image = Image.fromarray(np.clip(under, 0, 255).astype(np.uint8), "RGBA")
        else:
            self.image.alpha_composite(art, at) if at[0] >= 0 and at[1] >= 0 else self._clipped(art, at)

    def _clipped(self, art: Image.Image, at: tuple[int, int]) -> None:
        x, y = max(at[0], 0), max(at[1], 0)
        self.image.alpha_composite(art.crop((x - at[0], y - at[1], art.width, art.height)), (x, y))


def preview(kit: dict[str, Sprite]) -> Image.Image:
    """The kit put together: the crate shut and open, the reel with a card of each tier, the plaque, a card of each kind, the
    coin card and the Curio card, and two reveals. As the prototype's board draws it, to the eye, not to the pixel."""
    k = kit
    sheet = Stage(1280 / 1.5, 1480 / 1.5, 1.5)
    for name in ("crate-body", "crate-seal-left", "crate-seal-right", "crate-ribbon"):
        sheet.put(k[name], 20, 40)
    sheet.put(k["crate-lid"], 20, 40)
    sheet.put(k["fx-seal-glow"], 20 + 125 - 8, 40 + 62 - 8 + 0, add=True, alpha=0.6)
    # open: its rays, light and beam behind the body
    sheet.put(k["rays-crate"], 450, 120, add=True)
    sheet.put(k["fx-burst"], 450 - 100, 60, add=True, alpha=0.9)
    sheet.put(k["fx-beam"], 450 - 60, -30, add=True, alpha=0.85)
    sheet.put(k["crate-body"], 330, 40)
    # the plaque
    plaque_x, plaque_y, plaque_w = 640.0, 20.0, 190.0
    cap, mid = k["plaque-cap"], k["plaque-mid"]
    sheet.put(cap, plaque_x, plaque_y)
    sheet.put(cap, plaque_x, plaque_y, mirror=plaque_x + plaque_w)
    inner = cap.at[0] + cap.size[0]
    sheet.put(mid, 0, 0, size=(plaque_w - 2 * inner, mid.size[1]), place=(plaque_x + inner, plaque_y + mid.at[1]))
    # the reel, 848 units wide
    ox, oy, reel_w = 16.0, 250.0, 848.0
    sheet.put(k["rays-crate"], ox + reel_w / 2, oy + 85, add=True)
    cap, mid = k["reel-frame-cap"], k["reel-frame-mid"]
    sheet.put(cap, ox, oy)
    sheet.put(cap, ox, oy, mirror=ox + reel_w)
    inner = cap.at[0] + cap.size[0]
    sheet.put(mid, 0, 0, size=(reel_w - 2 * inner, mid.size[1]), place=(ox + inner, oy + mid.at[1]))
    for n in range(7):
        _card(sheet, k, ox + 11.2 + 4 + n * 118, oy + 16.0, kind=("toast", "book", "sound", "tracker")[n % 4], tier=n)
    fade = k["reel-fade"]
    sheet.put(fade, ox + 11.2, oy + 11.2, size=(120, 147.2))
    sheet.put(fade, 0, 0, size=(120, 147.2), mirror=ox + reel_w - 11.2, place=(ox + reel_w - 11.2 - 120, oy + 11.2))
    sheet.put(k["reel-light"], ox + reel_w / 2 - 88, oy + 11.2, tint=TIER_COLOURS[3], add=True, size=(176, 169.6))
    sheet.put(k["reel-line-glow"], ox + reel_w / 2, oy - 3.2, tint=TIER_COLOURS[3], add=True)
    sheet.put(k["reel-line"], ox + reel_w / 2, oy - 3.2)
    sheet.put(k["reel-bobber"], ox + reel_w / 2 - 10.4, oy - 28.8)
    sheet.put(k["reel-hook"], ox + reel_w / 2 - 8.8, oy + 161.6)
    # a card of each kind, the coin card and the Curio card
    row = oy + 215
    for n, kind in enumerate(("toast", "book", "sound", "tracker", "coin")):
        _card(sheet, k, 30 + n * 130, row, kind=kind, tier=n + 1)
    _card(sheet, k, 30 + 5 * 130, row, kind="coin-card", tier=6)
    _card(sheet, k, 30 + 6 * 130, row, kind=None, tier=6)
    # two reveals: an Epic sound set, and Curio
    top = row + 160
    for n, tier in enumerate((3, 6)):
        cx, cy = 230 + n * 420, top + 100
        colour = TIER_COLOURS[tier]
        sheet.put(k["fx-halo"], cx, cy, tint=colour, add=True)
        sheet.put(k["rays-a"], cx, cy, tint=colour, add=True)
        sheet.put(k["rays-b"], cx, cy, tint=colour, add=True)
        _card(sheet, k, cx - 90, cy - 103, kind=None if tier == 6 else "sound", tier=tier, grow=1.5)
    return sheet.image.convert("RGB")


def _card(stage: Stage, k: dict[str, Sprite], x: float, y: float, *, kind: str | None, tier: int, grow: float = 1.0) -> None:
    """A card as the prototype builds it: shadow, body, the tier's glow, ring and foot, the kind's emblem and hatching (or the
    Curio card, or the coin card), and the sheen."""
    c = TIER_COLOURS[tier]
    stage.put(k["card-shadow"], x, y, grow=grow)
    if kind == "coin-card":
        stage.put(k["card-coin"], x, y, grow=grow)
    elif kind is None and tier == 6:
        stage.put(k["card-glow"], x, y, tint=c, alpha=0.6, grow=grow)
        stage.put(k["card-curio"], x, y, grow=grow)
    else:
        assert kind is not None
        stage.put(k["card-base"], x, y, grow=grow)
        stage.put(k["card-tint"], x, y, tint=c, grow=grow)
        stage.put(k["card-hatch"], x, y, tint=c, alpha=0.06, grow=grow)
        stage.put(k[f"emblem-{kind}"], x, y, tint=c, grow=grow)
        stage.put(k[f"emblem-{kind}-hi"], x, y, grow=grow)
        stage.put(k["card-sheen"], x, y, alpha=0.1, grow=grow)


def contact_sheet(root: Path, out: Path) -> None:
    """A contact sheet of the kit: the pieces put together (preview), then each sprite on a checkerboard, named, at its
    texel size (a sprite stored at less than full alpha at its own alpha, a tinted one in its colour), in a PNG. Not
    committed."""
    sprites = sorted(all_sprites(root), key=lambda s: s.name)
    columns, gap, label = 1800, 14, 16
    assembled = preview({s.name: s for s in sprites})
    placed: list[tuple[Sprite, int, int]] = []
    x = y = gap
    row = 0
    for s in sprites:
        w = max(s.w, 60)
        if x + w + gap > columns:
            x, y, row = gap, y + row + gap + label, 0
        placed.append((s, x, y))
        x += w + gap
        row = max(row, s.h)
    top = assembled.height + gap
    sheet = Image.new("RGBA", (columns, top + y + row + gap + label), (34, 30, 26, 255))
    sheet.paste(assembled, (gap, 0))
    draw = ImageDraw.Draw(sheet)
    for s, px, py in placed:
        w = max(s.w, 60)
        rows, cols = np.indices((s.h, w))
        grey = np.where((rows // 8 + cols // 8) % 2 == 0, 62, 84).astype(np.uint8)
        tile = Image.fromarray(np.dstack([grey, grey, grey, np.full_like(grey, 255)]), "RGBA")
        shown = s.pixels.copy()
        if s.alpha is not None:
            shown[:, :, 3] *= s.alpha
        if s.tint:
            shown[:, :, :3] *= np.array(s.tint, dtype=np.float32) / 255.0
        tile.alpha_composite(Image.fromarray(np.clip(np.rint(shown * 255), 0, 255).astype(np.uint8), "RGBA"), (0, 0))
        sheet.alpha_composite(tile, (px, top + py + label))
        draw.text((px, top + py), f"{s.name} {s.w}x{s.h}", fill=(240, 220, 160, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)
