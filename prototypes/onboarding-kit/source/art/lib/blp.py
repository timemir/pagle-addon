#!/usr/bin/env python3
"""TGA -> BLP2 (DXT5, with mipmaps) for the Pagle art kits.

Run:  python3 art/lib/blp.py <file.tga or dir> ...   (writes <name>.blp next to each .tga)
      python3 art/lib/blp.py --raw <file.tga> ...    (uncompressed BGRA, encoding 3, instead of DXT5: 4x the size, no
                                                      block artefacts. Pillow cannot read it back, so --check skips it.)
      python3 art/lib/blp.py --check <file.blp> ...  (decodes it again and compares with the .tga)

The client loads `Interface\\AddOns\\X\\Textures\\Name` as Name.blp when it exists, so the probes' texture paths
(no extension) need no change. Layout written (the BLP2 header the client and Pillow read):
  'BLP2', type 1 (colour), encoding 2 (DXT), alphaDepth 8, alphaEncoding 7 (DXT5), hasMips 1, width, height,
  16 mip offsets, 16 mip sizes, a 256-entry palette (unused, zero), then the mips from full size down to 1 x 1.
Mips are box-filtered on premultiplied alpha, so transparent texels don't darken edges. DXT5 via etcpak
(pip install etcpak); the check decodes with Pillow's own BLP reader, independently of the encoder.
"""
import os, struct, sys
import numpy as np
from PIL import Image
import etcpak


def mips(rgba):
    a = rgba.astype(np.float32) / 255.0
    pre = a.copy(); pre[..., :3] *= pre[..., 3:4]
    out = [rgba]
    while pre.shape[0] > 1 or pre.shape[1] > 1:
        h, w = pre.shape[:2]
        h2, w2 = max(1, h // 2), max(1, w // 2)
        p = pre[:h2 * (h // h2), :w2 * (w // w2)].reshape(h2, h // h2, w2, w // w2, 4).mean(axis=(1, 3))
        pre = p
        un = p.copy()
        al = un[..., 3:4]
        un[..., :3] = np.where(al > 1e-6, un[..., :3] / np.maximum(al, 1e-6), 0)
        out.append(np.clip(un * 255.0 + 0.5, 0, 255).astype(np.uint8))
    return out


def dxt5(img):
    h, w = img.shape[:2]
    if h < 4 or w < 4:  # a block is 4 x 4: pad the smallest mips by repeating the edge
        pad = np.zeros((max(4, h), max(4, w), 4), np.uint8)
        pad[:h, :w] = img
        pad[h:, :w] = img[h - 1:h, :]
        pad[:, w:] = pad[:, w - 1:w]
        img = pad
    return etcpak.compress_bc3(np.ascontiguousarray(img).tobytes(), img.shape[1], img.shape[0])


def raw(img):
    return np.ascontiguousarray(img[..., [2, 1, 0, 3]]).tobytes()  # BGRA


def convert(tga, uncompressed=False):
    im = Image.open(tga).convert('RGBA')
    w, h = im.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, f'{tga}: {w}x{h} is not a power of two'
    levels = [(raw if uncompressed else dxt5)(m) for m in mips(np.array(im))][:16]
    header = 4 + 4 + 4 + 8 + 64 + 64 + 1024
    offs, sizes, pos = [], [], header
    for d in levels:
        offs.append(pos); sizes.append(len(d)); pos += len(d)
    offs += [0] * (16 - len(offs)); sizes += [0] * (16 - len(sizes))
    enc, aenc = (3, 0) if uncompressed else (2, 7)  # encoding 3 = raw BGRA; 2 = DXT with alphaEncoding 7 = DXT5
    blob = b'BLP2' + struct.pack('<I4B2I', 1, enc, 8, aenc, 1, w, h) + struct.pack('<16I', *offs) + struct.pack('<16I', *sizes) + bytes(1024)
    assert len(blob) == header
    out = os.path.splitext(tga)[0] + '.blp'
    with open(out, 'wb') as f:
        f.write(blob)
        for d in levels: f.write(d)
    return out


def check(blp):
    tga = os.path.splitext(blp)[0] + '.tga'
    a = np.array(Image.open(blp).convert('RGBA')).astype(np.float32)
    b = np.array(Image.open(tga).convert('RGBA')).astype(np.float32)
    assert a.shape == b.shape, (a.shape, b.shape)
    # colour error where the art is visible (alpha-weighted), and alpha error
    wgt = b[..., 3:4] / 255.0
    mse_c = float((((a[..., :3] - b[..., :3]) ** 2) * wgt).sum() / max(1.0, wgt.sum() * 3))
    mse_a = float(((a[..., 3] - b[..., 3]) ** 2).mean())
    psnr = lambda m: 99.0 if m == 0 else 10 * np.log10(255 ** 2 / m)
    return psnr(mse_c), psnr(mse_a)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args and args[0] == '--check':
        for p in args[1:]:
            if open(p, 'rb').read(9)[8] == 3: print(f'{p}: uncompressed, not checked'); continue
            c, al = check(p)
            print(f'{p}: colour {c:.1f} dB, alpha {al:.1f} dB')
        sys.exit()
    files, unc = [], False
    if args and args[0] == '--raw': unc, args = True, args[1:]
    for p in args:
        if os.path.isdir(p): files += sorted(os.path.join(p, f) for f in os.listdir(p) if f.lower().endswith('.tga'))
        else: files.append(p)
    for t in files:
        o = convert(t, unc)
        print(o, os.path.getsize(o) // 1024, 'KB')
