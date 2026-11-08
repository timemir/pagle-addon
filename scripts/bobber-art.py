"""Draws the minimap icon's Bobber style (CORE-R53): the Pagle Companion's app icon, a red and cream bobber with a gilt
band, brought down to a minimap button in the Ledger's three-texture contract.

    .tools/bin/python scripts/bobber-art.py              # write the three BLPs below
    .tools/bin/python scripts/bobber-art.py --png <dir>  # also keep the 512 masters and the textures as PNG there

Writes addons/Pagle/media/minimap/Bobber-Frame.blp (the disc of night water with its ripples, in a thin gilt ring,
BACKGROUND), Bobber-Emblem.blp (the bobber, ARTWORK, the layer a press pushes in), both 128 x 128, and Bobber-Glow.blp
(64 x 64, HIGHLIGHT, drawn ADD). Each layer is drawn at 512 on one square, the button's 34-unit square, so they line up
when the button stacks them centred; the ring's outside is 33 of its 34 units across, as the Ledger's is. The
bobber's antenna runs up into the ring. Each layer is brought down with Lanczos, its colour bled into the clear texels
round it so the mip levels never pull in a dark fringe, then encoded lossless with its mip chain
(scripts/encode-blp.py --raw). Commit the BLPs it writes.

The bobber is the app icon's (pagle-companion's src-tauri/icons/icon.svg, a 1024 viewBox): its gradients and colours,
its stem, cap, body, band and gloss, without the square leather tile and the sound arcs, scaled up to fill the disc.
The band's gilt line is drawn thicker than the icon's, so it still shows at 34 px. Rasterising is resvg's (the
resvg-py wheel in PYTHON_PACKAGES, scripts/setup.sh installs it). This is a first pass; a designer may redraw the art
under the same file names and the same three-layer contract.
"""

import argparse
import importlib.util
import io
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "addons" / "Pagle" / "media" / "minimap"

N, C = 512, 256  # the masters' side, and their centre
RO, RI = 248, 224  # the gilt ring's outer and inner radius: thin, its outside 33 of the button's 34 units
BALL = 158  # the bobber's radius, outline included
BALL_Y = 292  # its centre, below the disc's, so the antenna has room above it
STEM_TOP = 12  # where the antenna ends, inside the ring

DEFS = """
<radialGradient id="water" cx=".5" cy=".42" r=".62"><stop offset="0" stop-color="#2f6f74"/><stop offset=".55"
 stop-color="#173f47"/><stop offset="1" stop-color="#07171c"/></radialGradient>
<radialGradient id="lantern" cx=".5" cy=".36" r=".5"><stop offset="0" stop-color="#ffd98a" stop-opacity=".30"/><stop
 offset="1" stop-color="#ffd98a" stop-opacity="0"/></radialGradient>
<linearGradient id="gilt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff0b0"/><stop offset=".45"
 stop-color="#e8c96a"/><stop offset="1" stop-color="#9a7420"/></linearGradient>
<linearGradient id="ringgilt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff0b0"/><stop offset=".3"
 stop-color="#e2bd5c"/><stop offset=".62" stop-color="#9a6e1e"/><stop offset=".8" stop-color="#c79a3c"/><stop offset="1"
 stop-color="#5a3c0c"/></linearGradient>
<radialGradient id="cap" cx=".38" cy=".3" r=".8"><stop offset="0" stop-color="#ef7656"/><stop offset=".5"
 stop-color="#c8432a"/><stop offset="1" stop-color="#7a1810"/></radialGradient>
<radialGradient id="body" cx=".4" cy=".1" r=".95"><stop offset="0" stop-color="#fffaf0"/><stop offset=".6"
 stop-color="#f3e5c3"/><stop offset="1" stop-color="#bfa477"/></radialGradient>
<linearGradient id="stem" x1="0" x2="1"><stop offset="0" stop-color="#7a1810"/><stop offset=".4" stop-color="#e05a3c"/><stop
 offset="1" stop-color="#8a2414"/></linearGradient>
<radialGradient id="glow" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#ffd98a" stop-opacity=".08"/><stop
 offset=".7" stop-color="#ffcf6a" stop-opacity=".07"/><stop offset=".84" stop-color="#ffd46a" stop-opacity=".5"/><stop
 offset=".92" stop-color="#fff0b8" stop-opacity=".66"/><stop offset=".975" stop-color="#ffd46a" stop-opacity=".3"/><stop
 offset="1" stop-color="#ffd46a" stop-opacity="0"/></radialGradient>
<filter id="bevel" x="-5%" y="-5%" width="110%" height="110%" color-interpolation-filters="sRGB">
 <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="b"/>
 <feDiffuseLighting in="b" surfaceScale="5" diffuseConstant="1.15" lighting-color="#fff" result="d"><feDistantLight
  azimuth="235" elevation="45"/></feDiffuseLighting>
 <feComposite in="SourceGraphic" in2="d" operator="arithmetic" k1="1.15" result="lit"/>
 <feSpecularLighting in="b" surfaceScale="5" specularConstant="1" specularExponent="22" lighting-color="#fff7da"
  result="s"><feDistantLight azimuth="235" elevation="45"/></feSpecularLighting>
 <feComposite in="s" in2="SourceAlpha" operator="in" result="si"/>
 <feComposite in="lit" in2="si" operator="arithmetic" k2="1" k3=".9"/>
 <feComposite in2="SourceAlpha" operator="in"/></filter>
<filter id="innerdisc" x="0" y="0" width="100%" height="100%"><feGaussianBlur in="SourceAlpha" stdDeviation="14"/><feOffset
 dy="8"/><feComposite in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="sh"/><feFlood flood-color="#000"
 flood-opacity=".7"/><feComposite in2="sh" operator="in"/></filter>
<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="10"/></filter>
"""


def annulus(outer: float, inner: float) -> str:
    """A ring's path, filled even-odd."""

    def circle(r: float, sweep: int) -> str:
        return f"M{C - r} {C} A{r} {r} 0 1 {sweep} {C + r} {C} A{r} {r} 0 1 {sweep} {C - r} {C}Z "

    return circle(outer, 0) + circle(inner, 1)


def frame() -> str:
    """Night water in the thin gilt ring, with ripples round where the bobber floats."""
    ripples = "".join(
        f'<ellipse cx="{C}" cy="{BALL_Y + BALL * 0.72:.0f}" rx="{rx}" ry="{rx * 0.22:.0f}" fill="none" stroke="#e8c96a"'
        f' stroke-width="{w}" opacity="{o}"/>'
        for rx, w, o in ((176, 5, 0.5), (204, 4, 0.3))
    )
    disc = (
        f'<clipPath id="dc"><circle cx="{C}" cy="{C}" r="{RI + 3}"/></clipPath><g clip-path="url(#dc)">'
        f'<circle cx="{C}" cy="{C}" r="{RI + 3}" fill="url(#water)"/>'
        f'<circle cx="{C}" cy="{C}" r="{RI + 3}" fill="url(#lantern)"/>'
        + ripples
        + f'<circle cx="{C}" cy="{C}" r="{RI + 3}" fill="#000" filter="url(#innerdisc)"/></g>'
    )
    ring = (
        f'<circle cx="{C}" cy="{C}" r="{RO + 2}" fill="none" stroke="#120a03" stroke-width="5"/>'
        f'<path d="{annulus(RO, RI)}" fill="#1c1004" fill-rule="evenodd"/>'
        f'<path d="{annulus(RO - 3, RI + 3)}" fill="url(#ringgilt)" fill-rule="evenodd" filter="url(#bevel)"/>'
        f'<circle cx="{C}" cy="{C}" r="{(RO + RI) / 2:.1f}" fill="none" stroke="#fff3c4" stroke-width="1.5" opacity=".4"/>'
        f'<circle cx="{C}" cy="{C}" r="{RI + 1}" fill="none" stroke="#1a0c02" stroke-width="4"/>'
    )
    return disc + ring


def bobber() -> str:
    """The app icon's bobber, its 1024 drawing moved and scaled so its ball is BALL across at (C, BALL_Y)."""
    s = BALL / 240  # the icon's ball, outline included, is 240 across its radius
    stem_w = 48 * s * 1.15  # a little stouter than the icon's, so it reads at 34 px
    ball_top = BALL_Y - BALL
    stem = (
        f'<rect x="{C - stem_w / 2:.1f}" y="{STEM_TOP}" width="{stem_w:.1f}" height="{ball_top - STEM_TOP + 40:.1f}"'
        f' rx="{stem_w / 2:.1f}" fill="url(#stem)" stroke="#2a1608" stroke-width="{10 * s:.1f}"/>'
    )
    r = 230 * s  # the cap's and the body's radius, inside the outline
    x0, x1 = C - r, C + r
    band_h, gilt_h = 32 * s * 1.2, 11
    gloss = (
        f'<ellipse cx="{C - 92 * s:.1f}" cy="{BALL_Y - 130 * s:.1f}" rx="{70 * s:.1f}" ry="{44 * s:.1f}"'
        f' transform="rotate(-32 {C - 92 * s:.1f} {BALL_Y - 130 * s:.1f})" fill="#fff" opacity=".34"/>'
    )
    shadow = (
        f'<ellipse cx="{C + 4}" cy="{BALL_Y + 16}" rx="{BALL + 2}" ry="{BALL}" fill="#05100f" opacity=".6"'
        ' filter="url(#shadow)"/>'
    )
    return (
        shadow
        + stem
        + f'<circle cx="{C}" cy="{BALL_Y}" r="{BALL}" fill="#2a1608"/>'
        + f'<path d="M{x0:.1f} {BALL_Y}a{r:.1f} {r:.1f} 0 0 1 {2 * r:.1f} 0z" fill="url(#cap)"/>'
        + f'<path d="M{x0:.1f} {BALL_Y}a{r:.1f} {r:.1f} 0 0 0 {2 * r:.1f} 0z" fill="url(#body)"/>'
        + f'<rect x="{x0:.1f}" y="{BALL_Y - band_h / 2:.1f}" width="{x1 - x0:.1f}" height="{band_h:.1f}" fill="#2a1608"/>'
        + f'<rect x="{x0 + 2:.1f}" y="{BALL_Y - gilt_h / 2:.1f}" width="{x1 - x0 - 4:.1f}" height="{gilt_h}"'
        ' fill="url(#gilt)"/>'
        + gloss
    )


def glow() -> str:
    """The hover light, added on: the ring lights up gold, the water only a little, so the bobber keeps its colour."""
    return f'<circle cx="{C}" cy="{C}" r="{RO + 4}" fill="url(#glow)"/>'


def rasterise(body: str) -> Image.Image:
    try:
        import resvg_py  # noqa: PLC0415
    except ImportError as error:
        raise SystemExit("bobber-art: needs resvg-py; run scripts/setup.sh, then .tools/bin/python scripts/bobber-art.py") from error
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{N}" height="{N}" viewBox="0 0 {N} {N}"><defs>{DEFS}</defs>{body}</svg>'
    png = resvg_py.svg_to_bytes(svg_string=svg, skip_system_fonts=True)
    image = Image.open(io.BytesIO(bytes(png))).convert("RGBA")
    assert image.size == (N, N), image.size
    return image


def bleed(image: Image.Image) -> Image.Image:
    """`image` with each clear texel given its nearest drawn texel's colour, its alpha left clear."""
    texels = np.asarray(image).astype(np.float64)
    solid = texels[..., 3] > 0
    if solid.all() or not solid.any():
        return image
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    out = texels.copy()
    out[..., :3] = np.where(solid[..., None], texels[..., :3], texels[..., :3][iy, ix])
    return Image.fromarray(out.round().astype("uint8"), "RGBA")


def encoder():
    spec = importlib.util.spec_from_file_location("encode_blp", ROOT / "scripts" / "encode-blp.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Draw the minimap icon's Bobber style.")
    parser.add_argument("--png", type=Path, help="also keep the 512 masters and the textures as PNG here (not committed)")
    args = parser.parse_args(argv)
    encode_raw = encoder().encode_raw
    layers = {"Bobber-Frame": (frame(), 128), "Bobber-Emblem": (bobber(), 128), "Bobber-Glow": (glow(), 64)}
    with tempfile.TemporaryDirectory() as scratch:
        for name, (body, size) in layers.items():
            master = rasterise(body)
            texture = bleed(master.resize((size, size), Image.Resampling.LANCZOS))
            png = Path(scratch) / f"{name}.png"
            texture.save(png)
            encode_raw(png, MEDIA / f"{name}.blp")
            if args.png:
                args.png.mkdir(parents=True, exist_ok=True)
                master.save(args.png / f"{name}-512.png")
                texture.save(args.png / f"{name}.png")
    return 0


if __name__ == "__main__":
    if sys.version_info < (3, 12):
        sys.exit("bobber-art: needs Python 3.12; run it as .tools/bin/python scripts/bobber-art.py")
    sys.exit(main())
