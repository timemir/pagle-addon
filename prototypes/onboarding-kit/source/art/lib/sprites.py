"""Pagle art kit: render sprites straight from the approved canvas CSS/SVG, then pack them into atlases.

Each sprite is a small HTML snippet laid out in a box of w x h UI units, plus a margin for shadows and glows.
Chromium renders it at 2 device pixels per CSS px with a transparent background, so the in-game art is the
canvas art at 2 texels per UI unit. Packing is a shelf packer into power-of-two pages; output is 32-bit TGA
plus Atlas.lua (texel rectangles and each sprite's design box inside its margin) and atlas.json.
"""
import json, os, re
from PIL import Image
from playwright.sync_api import sync_playwright

SCALE = 2

class Sprite:
    def __init__(self, name, html, w, h, margin=0, cls='', note=''):
        self.name, self.html, self.w, self.h = name, html, w, h
        self.m = margin if isinstance(margin, (tuple, list)) else (margin,) * 4  # top right bottom left
        self.cls, self.note = cls, note
        self.img = None

def render(sprites, css, fonts_css, blob_map, extra_head=''):
    """Render every sprite. css: the canvas stylesheet text; blob_map: /_blob/<id> -> local file."""
    def fix(s):
        for k, v in blob_map.items():
            s = s.replace('/_blob/' + k, 'file://' + os.path.abspath(v))
        return s
    css = fix(css)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={'width': 1600, 'height': 1200}, device_scale_factor=SCALE, reduced_motion='reduce')
        for s in sprites:
            t, r, bt, l = s.m
            W, H = s.w + l + r, s.h + t + bt
            doc = (f'<!doctype html><html><head><meta charset="utf-8"><style>{fonts_css}\n{css}\n'
                   f'html,body{{margin:0;background:transparent}} #box{{position:relative;width:{W}px;height:{H}px;overflow:hidden}}'
                   f' #in{{position:absolute;left:{l}px;top:{t}px;width:{s.w}px;height:{s.h}px}}</style>{extra_head}</head>'
                   f'<body><div id="box" class="{s.cls}"><div id="in">{fix(s.html)}</div></div></body></html>')
            path = os.path.abspath('/tmp/_sprite.html')
            open(path, 'w').write(doc)
            pg.goto('file://' + path); pg.wait_for_timeout(120)
            out = '/tmp/_sprite.png'
            pg.locator('#box').screenshot(path=out, omit_background=True)
            s.img = Image.open(out).convert('RGBA').copy()
        b.close()
    return sprites

def _pow2(n):
    p = 1
    while p < n: p *= 2
    return p

def _maxrects(sizes, W, H):
    """MaxRects, best-short-side-fit. sizes: list of (key, w, h). Returns {key: (x, y)} or None."""
    free = [(0, 0, W, H)]; out = {}
    for key, w, h in sizes:
        best = None
        for fx, fy, fw, fh in free:
            if w <= fw and h <= fh:
                score = (min(fw - w, fh - h), max(fw - w, fh - h))
                if best is None or score < best[0]: best = (score, fx, fy)
        if best is None: return None
        _, x, y = best; out[key] = (x, y)
        nf = []
        for fx, fy, fw, fh in free:
            if x >= fx + fw or x + w <= fx or y >= fy + fh or y + h <= fy:
                nf.append((fx, fy, fw, fh)); continue
            if x > fx: nf.append((fx, fy, x - fx, fh))
            if x + w < fx + fw: nf.append((x + w, fy, fx + fw - x - w, fh))
            if y > fy: nf.append((fx, fy, fw, y - fy))
            if y + h < fy + fh: nf.append((fx, y + h, fw, fy + fh - y - h))
        free = [r for r in nf if not any(r != o and r[0] >= o[0] and r[1] >= o[1] and r[0] + r[2] <= o[0] + o[2] and r[1] + r[3] <= o[1] + o[3] for o in nf)]
    return out

def pack(sprites, max_w=2048, pad=2):
    """Pack into the smallest power-of-two page that fits (MaxRects). Returns (atlas image, rects)."""
    sizes = sorted(((s.name, s.img.width + pad * 2, s.img.height + pad * 2) for s in sprites), key=lambda t: -t[1] * t[2])
    area = sum(w * h for _, w, h in sizes)
    cands = sorted({(W, H) for W in (256, 512, 1024, 2048) for H in (256, 512, 1024, 2048, 4096) if W * H >= area and H <= 2 * W and W <= max_w}, key=lambda t: (t[0] * t[1], t[0]))
    for W, H in cands:
        if max(w for _, w, _ in sizes) > W: continue
        pos = _maxrects(sizes, W, H)
        if pos: break
    else:
        raise SystemExit('atlas does not fit 2048 x 4096')
    by = {s.name: s for s in sprites}
    rects = {k: (x + pad, y + pad, by[k].img.width, by[k].img.height) for k, (x, y) in pos.items()}
    atlas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for k, (x, y, w, h) in rects.items():
        atlas.paste(by[k].img, (x, y))
    return bleed(atlas), rects

def bleed(img, steps=6):
    """Spread colour into fully transparent texels so bilinear filtering never pulls in black fringes."""
    import numpy as np
    a = np.asarray(img).astype(np.float32)
    rgb, al = a[..., :3].copy(), a[..., 3]
    known = al > 0
    for _ in range(steps):
        acc = np.zeros_like(rgb); cnt = np.zeros(al.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            k = np.roll(known, (dy, dx), (0, 1)); c = np.roll(rgb, (dy, dx), (0, 1))
            acc += c * k[..., None]; cnt += k
        fill = (~known) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        known = known | fill
    out = np.dstack([rgb, al]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

def write(out_dir, atlas_name, addon_tex_path, atlas, rects, sprites, ns='P', scale=None):
    scale = scale or SCALE
    os.makedirs(out_dir, exist_ok=True)
    atlas.save(os.path.join(out_dir, atlas_name + '.tga'))
    bg = Image.new('RGBA', atlas.size, (40, 30, 22, 255)); bg.alpha_composite(atlas)
    bg.convert('RGB').save(os.path.join(out_dir, atlas_name + '-preview.png'))
    by = {s.name: s for s in sprites}
    meta = {}
    lines = [f'-- Generated by art/lib/sprites.py. Do not edit.',
             f'-- Texel rectangles in {atlas_name}.tga ({atlas.width}x{atlas.height}), {scale} texels per UI unit.',
             f'-- box = the design box inside the sprite (UI units): x, y from the sprite\'s top left, then w, h.',
             f'local _, {ns} = ...', f'{ns}.Atlases = {ns}.Atlases or {{}}',
             f'{ns}.Atlases["{atlas_name}"] = {{',
             f'  file = [[{addon_tex_path}{atlas_name}]], width = {atlas.width}, height = {atlas.height}, scale = {scale},', '  sprites = {']
    for name in sorted(rects):
        x, y, w, h = rects[name]; s = by[name]; t, r, b, l = s.m
        meta[name] = dict(x=x, y=y, w=w, h=h, box=[l, t, s.w, s.h])
        lines.append(f'    ["{name}"] = {{ x = {x}, y = {y}, w = {w}, h = {h}, box = {{ {l}, {t}, {s.w}, {s.h} }} }},')
    lines += ['  },', '}']
    open(os.path.join(out_dir, atlas_name + '.lua'), 'w').write('\n'.join(lines) + '\n')
    json.dump(meta, open(os.path.join(out_dir, atlas_name + '.json'), 'w'), indent=1)
    return meta

def fonts_css(font_dir):
    F = os.path.abspath(font_dir) + '/'
    return (f"@font-face{{font-family:'IM Fell English';src:url(file://{F}IMFeENrm28P.ttf)}}"
            f"@font-face{{font-family:'IM Fell English';font-style:italic;src:url(file://{F}IMFeENit28P.ttf)}}"
            f"@font-face{{font-family:'IM Fell English SC';src:url(file://{F}IMFeENsc28P.ttf)}}"
            f"@font-face{{font-family:'Caveat';font-weight:400 700;src:url(file://{F}Caveat[wght].ttf)}}"
            f"@font-face{{font-family:'Marcellus';src:url(file://{F}Marcellus-Regular.ttf)}}")
