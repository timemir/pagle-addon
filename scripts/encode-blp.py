#!/usr/bin/env python3
"""Encodes the announcements art's TGA atlases as BLP2 textures with DXT5 compression, the format the client loads
in a quarter of a TGA's memory (announcements.md › UI, ANN-R80).

    python3 scripts/encode-blp.py <out_dir> <atlas.tga>...
    python3 scripts/encode-blp.py --raw <out_dir> <image>...

Each <name>.tga becomes <out_dir>/<name>.blp: one level (UI art is drawn near its own size, so no mipmaps), the
DXT5 blocks from Pillow's DDS encoder behind a BLP2 header. Each is read back with Pillow's BLP decoder and drawn
over black, as the client blends it: 999 in 1000 channel values must land within DXT5's usual error of the source's.
The atlases come from the announcements art kit (art/announce/generate.py), which bleeds colour into transparent
texels so the blocks keep clean edges. Needs Pillow 11.2 or later; it is a one-off tool for new art, not part of
scripts/check.sh.

--raw is for small art with fine detail that DXT5's 4x4 blocks smear, drawn well below its own size: the minimap
icon (CORE-R53), 64 x 64 and shown at 18 px. Its texels are stored as they are (BLP2's uncompressed BGRA, colour
encoding 3), with a mipmap chain down to 1 x 1 so the client draws it small without aliasing. Pillow can't decode
that encoding, so each level is read back from the file's bytes and must equal its source exactly.
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


def encode_raw(source: Path, out: Path) -> None:
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    if width & (width - 1) or height & (height - 1):
        raise SystemExit(f"{source}: {width}x{height} is not a power of two")
    # Each level halves the one above (Lanczos), down to 1 x 1 on the longer side, at most 16 levels.
    levels = [image]
    while max(levels[-1].size) > 1 and len(levels) < 16:
        w, h = levels[-1].size
        levels.append(image.resize((max(1, w // 2), max(1, h // 2)), Image.Resampling.LANCZOS))
    # BGRA, a texel at a time, rows top to bottom, as the client reads colour encoding 3.
    blobs = [level.tobytes("raw", "BGRA") for level in levels]
    offsets, sizes, at = [], [], BLP_HEADER
    for blob in blobs:
        offsets.append(at)
        sizes.append(len(blob))
        at += len(blob)
    offsets += [0] * (16 - len(blobs))
    sizes += [0] * (16 - len(blobs))
    # Type 1, colour encoding 3 (uncompressed BGRA), 8 bits of alpha, alpha encoding 8, mipmaps present.
    header = b"BLP2" + struct.pack("<IBBBBII", 1, 3, 8, 8, 1, width, height)
    header += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + bytes(1024)
    assert len(header) == BLP_HEADER
    out.write_bytes(header + b"".join(blobs))

    data = out.read_bytes()
    if data[:4] != b"BLP2" or struct.unpack_from("<IBBBBII", data, 4) != (1, 3, 8, 8, 1, width, height):
        raise SystemExit(f"{out}: its header doesn't read back")
    read_offsets = struct.unpack_from("<16I", data, 20)
    read_sizes = struct.unpack_from("<16I", data, 84)
    for i, level in enumerate(levels):
        texels = data[read_offsets[i] : read_offsets[i] + read_sizes[i]]
        if Image.frombytes("RGBA", level.size, texels, "raw", "BGRA").tobytes() != level.tobytes():
            raise SystemExit(f"{out}: level {i} doesn't read back as its source")
    print(f"{out}: {width}x{height}, {len(levels)} levels, {out.stat().st_size} bytes, lossless")


def main() -> None:
    args = sys.argv[1:]
    raw = bool(args) and args[0] == "--raw"
    if raw:
        args = args[1:]
    if len(args) < 2:
        raise SystemExit(__doc__)
    out_dir = Path(args[0])
    for name in args[1:]:
        source = Path(name)
        (encode_raw if raw else encode)(source, out_dir / (source.stem + ".blp"))


if __name__ == "__main__":
    main()
