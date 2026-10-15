#!/usr/bin/env python3
"""Encodes the announcements art's TGA atlases as BLP2 textures with DXT5 compression, the format the client loads
in a quarter of a TGA's memory (announcements.md › UI, ANN-R80).

    python3 scripts/encode-blp.py <out_dir> <atlas.tga>...

Each <name>.tga becomes <out_dir>/<name>.blp: one level (UI art is drawn near its own size, so no mipmaps), the
DXT5 blocks from Pillow's DDS encoder behind a BLP2 header. Each is read back with Pillow's BLP decoder and drawn
over black, as the client blends it: 999 in 1000 channel values must land within DXT5's usual error of the source's.
The atlases come from the announcements art kit (art/announce/generate.py), which bleeds colour into transparent
texels so the blocks keep clean edges. Needs Pillow 11.2 or later; it is a one-off tool for new art, not part of
scripts/check.sh.
"""

import io
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops

DDS_HEADER = 128  # "DDS " and the 124-byte header Pillow writes before the blocks
BLP_HEADER = 1172  # magic, type, four encoding bytes, size, 16 mip offsets and sizes, the 256-entry palette
MAX_ERROR = 32  # the 99.9th percentile per-channel difference DXT5 may leave on this art, drawn over black


def encode(tga: Path, out: Path) -> None:
    image = Image.open(tga).convert("RGBA")
    width, height = image.size
    if width & (width - 1) or height & (height - 1):
        raise SystemExit(f"{tga}: {width}x{height} is not a power of two")
    dds = io.BytesIO()
    image.save(dds, "DDS", pixel_format="DXT5")
    blocks = dds.getvalue()[DDS_HEADER:]
    if len(blocks) != width * height:  # DXT5 is a byte per texel
        raise SystemExit(f"{tga}: {len(blocks)} bytes of DXT5 blocks, expected {width * height}")
    offsets = [BLP_HEADER] + [0] * 15
    sizes = [len(blocks)] + [0] * 15
    header = b"BLP2" + struct.pack("<IBBBBII", 1, 2, 8, 7, 0, width, height)
    header += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + bytes(1024)
    assert len(header) == BLP_HEADER
    out.write_bytes(header + blocks)

    black = Image.new("RGBA", image.size, (0, 0, 0, 255))
    drawn = Image.alpha_composite(black, image).convert("RGB")
    back = Image.alpha_composite(black, Image.open(out).convert("RGBA")).convert("RGB")
    histogram = ImageChops.difference(drawn, back).histogram()
    counts = [sum(histogram[c * 256 : c * 256 + i + 1]) for c in range(3) for i in range(256)]
    total = width * height
    error = max(next(i for i in range(256) if counts[c * 256 + i] >= total * 0.999) for c in range(3))
    if error > MAX_ERROR:
        raise SystemExit(f"{out}: reads back {error} off the source at the 99.9th percentile, over {MAX_ERROR}")
    print(f"{out}: {width}x{height}, {out.stat().st_size} bytes, 99.9th percentile error {error}")


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    out_dir = Path(sys.argv[1])
    for name in sys.argv[2:]:
        tga = Path(name)
        encode(tga, out_dir / (tga.stem + ".blp"))


if __name__ == "__main__":
    main()
