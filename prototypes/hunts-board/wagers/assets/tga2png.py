"""Minimal TGA -> PNG converter (uncompressed or RLE truecolour, 24/32-bit). Usage: tga2png.py in.tga out.png"""
import struct, sys, zlib


def read_tga(path):
    data = open(path, "rb").read()
    idlen, cmtype, itype = data[0], data[1], data[2]
    w, h = struct.unpack_from("<HH", data, 12)
    bpp, desc = data[16], data[17]
    if cmtype != 0 or itype not in (2, 10) or bpp not in (24, 32):
        raise SystemExit(f"unsupported TGA: type={itype} cmap={cmtype} bpp={bpp}")
    px = bpp // 8
    pos = 18 + idlen
    n = w * h
    out = bytearray(n * 4)
    i = 0

    def put(i, b):
        o = i * 4
        out[o] = b[2]
        out[o + 1] = b[1]
        out[o + 2] = b[0]
        out[o + 3] = b[3] if px == 4 else 255

    if itype == 2:
        for i in range(n):
            put(i, data[pos + i * px: pos + i * px + px])
    else:
        while i < n:
            hdr = data[pos]
            pos += 1
            count = (hdr & 0x7F) + 1
            if hdr & 0x80:
                b = data[pos: pos + px]
                pos += px
                for _ in range(count):
                    put(i, b)
                    i += 1
            else:
                for _ in range(count):
                    put(i, data[pos: pos + px])
                    pos += px
                    i += 1
    top_origin = bool(desc & 0x20)
    rows = [bytes(out[r * w * 4:(r + 1) * w * 4]) for r in range(h)]
    if not top_origin:
        rows.reverse()
    return w, h, rows


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


if __name__ == "__main__":
    w, h, rows = read_tga(sys.argv[1])
    write_png(sys.argv[2], w, h, rows)
    print(sys.argv[2], w, h)
