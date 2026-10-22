#!/usr/bin/env python3
"""Run a Pagle art probe addon offline against wowmock.lua and paint what it built.

  python3 sim.py <AddonDir> <out.png> "<slash command>" [--bg world.jpg] [--size 1440x810] [--uiscale 0.8]

Anchors, sizes, scales, frame strata and levels, draw layers, texcoords, colour textures, masks, clipping
and font strings (the bundled fonts, measured with Pillow) are emulated; game icons and portraits are
drawn as placeholders. It is a layout check, not a renderer of record."""
import os, re, sys, math
from functools import lru_cache
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import lupa.lua51 as lupa

ADDON = os.path.abspath(sys.argv[1]); OUT = sys.argv[2]; CMDS = sys.argv[3].split(';')
args = sys.argv[4:]
BG = args[args.index('--bg') + 1] if '--bg' in args else None
SW, SH = (1440, 810)
if '--size' in args: SW, SH = map(int, args[args.index('--size') + 1].split('x'))
UIS = float(args[args.index('--uiscale') + 1]) if '--uiscale' in args else 1.0  # the client's UI scale
NAME = os.path.basename(ADDON)
SS = 2  # paint at 2x, downsample at the end

def local_path(p):
    if not isinstance(p, str): return None
    q = p.replace('\\', '/')
    m = re.match(r'(?i)interface/addons/([^/]+)/(.*)', q)
    if m: return os.path.join(os.path.dirname(ADDON), m.group(1), m.group(2))
    return None

@lru_cache(None)
def font(path, size):
    return ImageFont.truetype(path, max(1, int(round(size))))
CODE = re.compile(r'\|c[0-9a-fA-F]{8}|\|r')
def strip_codes(t): return CODE.sub('', t or '')
def measure(file, size, text):
    lp = local_path(file)
    if not lp or not os.path.exists(lp): lp = os.path.join(ADDON, 'Fonts', 'IMFeENrm28P.ttf')
    return font(lp, size * SS).getlength(strip_codes(text)) / SS
def wrap_lines(file, size, text, width):
    """WoW-style word wrap; colour codes are carried into the line they open in."""
    out, cur = [], ''
    for para in (text or '').split('\n'):
        cur = ''
        for word in para.split(' '):
            trial = word if not cur else cur + ' ' + word
            if cur and measure(file, size, trial) > width + 0.5:
                out.append(cur); cur = word
            else: cur = trial
        out.append(cur)
    return out
def nlines(file, size, text, width): return len(wrap_lines(file, size, text, width))

L = lupa.LuaRuntime(unpack_returned_tuples=True)
g = L.globals()
g._SCREEN_W, g._SCREEN_H = SW / UIS, SH / UIS  # UIParent's size in UI units
g._MEASURE = measure
g._NLINES = nlines
logs = []
g._PRINT = lambda s: logs.append(s)
L.execute('_TEMPLATES = {}')
L.execute(open(os.path.join(os.path.dirname(__file__), 'wowmock.lua')).read())
g.UIParent.scale = UIS
P = L.table()
toc = open(os.path.join(ADDON, NAME + '.toc')).read().splitlines()
loadstring = L.eval('loadstring')
import xml.etree.ElementTree as ET
def load_xml(path):
    root = ET.parse(path).getroot()
    for el in root.iter():
        tag = el.tag.split('}')[-1]
        if el.get('virtual') == 'true' and el.get('name'):
            t = L.table(); t.mixin = el.get('mixin'); t.kind = tag; t.strata = el.get('frameStrata')
            sc = L.table(); t.scripts = sc
            for c in el.iter():
                ct = c.tag.split('}')[-1]
                if ct == 'Size' and c.get('x'): t.w, t.h = float(c.get('x')), float(c.get('y'))
                if ct in ('OnLoad', 'OnSizeChanged', 'OnShow') and c.get('method'): sc[ct] = c.get('method')
            g._TEMPLATES[el.get('name')] = t
for line in toc:
    line = line.strip()
    if not line or line.startswith('#'): continue
    path = os.path.join(ADDON, line.replace('\\', '/'))
    if path.endswith('.xml'):
        load_xml(path); continue
    fn = loadstring(open(path).read(), '@' + line)
    if fn is None: raise SystemExit('syntax error in ' + line)
    fn(NAME, P)
for cmd in CMDS:
    slash, _, rest = cmd.strip().partition(' ')
    key = None
    for k, v in g.items():
        if isinstance(k, str) and k.startswith('SLASH_') and v == slash: key = re.sub(r'\d+$', '', k[6:])
    g.SlashCmdList[key](rest)
for s in logs: print('chat:', re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', s))

# ------------------------------------------------------------------ layout
REG = list(g._MOCK.REG.values())
def eff_scale(r):
    s = 1.0
    while r is not None:
        s *= (r.scale or 1) if r.objectType not in ('Texture', 'FontString', 'MaskTexture') else 1
        r = r.parent
    return s
FS = g._MOCK.FontString
def fget(r, k):
    v = r['_' + k]
    if v is None and r.font is not None: v = r.font[k]
    return v
memo = {}
def size_of(r):
    sc = eff_scale(r)
    if r.objectType == 'FontString':
        w = r.w if r.w else measure(fget(r, 'file'), fget(r, 'size') or 12, r.text) + 1
        h = r.h if r.h else (fget(r, "size") or 12) * 1.0
        if not r.h and r.wrap and r.w:
            n = nlines(fget(r, 'file'), fget(r, 'size') or 12, r.text, r.w); h = h * n + (r.spacing or 0) * (n - 1)
        return w * sc, h * sc
    return (r.w or 0) * sc, (r.h or 0) * sc
def rect(r):
    """(left, bottom, right, top) in screen units, y up. None if unanchored."""
    if r.id in memo: return memo[r.id]
    memo[r.id] = None
    if r.root:
        memo[r.id] = (0, 0, SW, SH); return memo[r.id]
    pts = list(r.points.values()) if r.points else []
    if not pts: return None
    sc = eff_scale(r)
    w, h = size_of(r)
    L_ = R_ = T_ = B_ = CX = CY = None
    for p in pts:
        rr = rect(p.rel) if p.rel is not None else None
        if rr is None: continue
        l, b, ri, t = rr
        rp = p.relPoint.upper()
        ax = l if 'LEFT' in rp else ri if 'RIGHT' in rp else (l + ri) / 2
        ay = t if 'TOP' in rp else b if 'BOTTOM' in rp else (b + t) / 2
        x, y = ax + p.x * sc, ay + p.y * sc
        pp = p.point.upper()
        if 'LEFT' in pp: L_ = x
        elif 'RIGHT' in pp: R_ = x
        else: CX = x
        if 'TOP' in pp: T_ = y
        elif 'BOTTOM' in pp: B_ = y
        else: CY = y
    if L_ is None and R_ is None and CX is None: return None
    if L_ is not None and R_ is not None: pass
    elif L_ is not None: R_ = L_ + w
    elif R_ is not None: L_ = R_ - w
    else: L_, R_ = CX - w / 2, CX + w / 2
    if T_ is not None and B_ is not None: pass
    elif T_ is not None: B_ = T_ - h
    elif B_ is not None: T_ = B_ + h
    elif CY is not None: B_, T_ = CY - h / 2, CY + h / 2
    else: return None
    memo[r.id] = (L_, B_, R_, T_)
    return memo[r.id]

STRATA = ['BACKGROUND', 'LOW', 'MEDIUM', 'HIGH', 'DIALOG', 'FULLSCREEN', 'FULLSCREEN_DIALOG', 'TOOLTIP']
LAYERS = ['BACKGROUND', 'BORDER', 'ARTWORK', 'OVERLAY']
def visible(r):
    while r is not None:
        if not r.shown: return False
        r = r.parent
    return True
def alpha(r):
    a = 1.0
    while r is not None:
        a *= r.alpha if r.alpha is not None else 1
        r = r.parent
    return a
def clip(r):
    c = None; f = r.parent
    while f is not None:
        if f.clips:
            fr = rect(f)
            if fr:
                c = fr if c is None else (max(c[0], fr[0]), max(c[1], fr[1]), min(c[2], fr[2]), min(c[3], fr[3]))
        f = f.parent
    return c

@lru_cache(None)
def tex(path):
    lp = local_path(path)
    if lp:
        for ext in ('', '.tga', '.blp', '.png'):
            if os.path.exists(lp + ext): return Image.open(lp + ext).convert('RGBA')
    return None
def placeholder(w, h, kind):
    im = Image.new('RGBA', (max(1, w), max(1, h)), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if kind == 'portrait':
        d.rectangle((0, 0, w, h), fill=(40, 60, 70, 255)); d.ellipse((w * .3, h * .15, w * .7, h * .55), fill=(200, 170, 130, 255))
        d.ellipse((w * .15, h * .55, w * .85, h * 1.2), fill=(90, 50, 30, 255))
    else:
        for i in range(20):
            k = i / 20; c = (int(60 + 120 * (1 - k)), int(110 + 90 * (1 - k)), int(120 + 80 * (1 - k)), 255)
            d.ellipse((w * k / 2, h * k / 2, w - w * k / 2, h - h * k / 2), fill=c)
        d.polygon([(w * .2, h * .5), (w * .55, h * .32), (w * .75, h * .45), (w * .9, h * .3), (w * .9, h * .7), (w * .75, h * .55), (w * .55, h * .68)], fill=(235, 240, 238, 255))
    return im

def paint(OUT):
    global REG
    REG = list(g._MOCK.REG.values())
    memo.clear()
    canvas = Image.new('RGBA', (SW * SS, SH * SS), (20, 18, 16, 255))
    if BG:
        canvas.alpha_composite(Image.open(BG).convert('RGBA').resize((SW * SS, SH * SS)))
    draws = []
    for r in REG:
        if r.objectType not in ('Texture', 'FontString', 'Line') or r.layer == 'HIGHLIGHT' or r.highlight: continue
        if not visible(r): continue
        fr = r.parent
        key = (STRATA.index(fr.strata) if fr.strata in STRATA else 2, fr.level or 0, LAYERS.index(r.layer) if r.layer in LAYERS else 2, r.sub or 0, r.id)
        draws.append((key, r))
    draws.sort(key=lambda x: x[0])
    def to_px(rc):
        l, b, ri, t = rc
        return (l * SS, (SH - t) * SS, ri * SS, (SH - b) * SS)
    problems = []
    def line_pt(p):
        rr = rect(p[2]) if p[2] is not None else None
        if rr is None: return None
        l, b, ri, t = rr; rp = str(p[1]).upper(); sc = eff_scale(p[2])
        ax = l if 'LEFT' in rp else ri if 'RIGHT' in rp else (l + ri) / 2
        ay = t if 'TOP' in rp else b if 'BOTTOM' in rp else (b + t) / 2
        return ((ax + p[3] * sc) * SS, (SH - (ay + p[4] * sc)) * SS)
    for _, r in draws:
        if r.objectType == 'Line':
            if r.p0 is None or r.p1 is None or r.color is None: continue
            a0, a1 = line_pt(r.p0), line_pt(r.p1)
            if a0 is None or a1 is None: continue
            c = r.color; a = alpha(r)
            layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
            ImageDraw.Draw(layer).line([a0, a1], fill=tuple(int(v * 255) for v in (c[1], c[2], c[3])) + (int(c[4] * 255 * a),), width=max(1, int(round((r.thick or 1) * eff_scale(r.parent) * SS))))
            canvas.alpha_composite(layer)
            continue
        rc = rect(r)
        if rc is None: continue
        x0, y0, x1, y1 = to_px(rc)
        W, H = int(round(x1 - x0)), int(round(y1 - y0))
        if W <= 0 or H <= 0: continue
        a = alpha(r)
        if r.objectType == 'Texture':
            if r.color is not None:
                c = r.color
                im = Image.new('RGBA', (W, H), tuple(int(v * 255) for v in (c[1], c[2], c[3])) + (int(c[4] * 255),))
            elif r.portrait:
                im = placeholder(W, H, 'portrait')
            else:
                src = tex(r.file)
                if src is None:
                    im = placeholder(W, H, 'icon')
                    if r.file and 'Icons' not in str(r.file): problems.append('missing texture ' + str(r.file))
                else:
                    cl, cr, ct, cb = (r.coord[i] for i in (1, 2, 3, 4))
                    if max(cl, cr, ct, cb) > 1.001 or min(cl, cr, ct, cb) < -0.001:
                        nx = int(math.ceil(max(abs(cl), abs(cr)))) + 1; ny = int(math.ceil(max(abs(ct), abs(cb)))) + 1
                        big = Image.new('RGBA', (src.width * nx, src.height * ny))
                        for ix in range(nx):
                            for iy in range(ny): big.paste(src, (ix * src.width, iy * src.height))
                        src = big; cl, cr, ct, cb = cl / nx, cr / nx, ct / ny, cb / ny
                    sx0, sx1 = sorted((cl * src.width, cr * src.width)); sy0, sy1 = sorted((ct * src.height, cb * src.height))
                    crop = src.crop((int(round(sx0)), int(round(sy0)), max(int(round(sx0)) + 1, int(round(sx1))), max(int(round(sy0)) + 1, int(round(sy1)))))
                    if cl > cr: crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
                    if ct > cb: crop = crop.transpose(Image.FLIP_TOP_BOTTOM)
                    im = crop.resize((W, H), Image.BILINEAR)
            if r.vertex is not None:
                v = r.vertex; px = im.split()
                im = Image.merge('RGBA', [px[i].point(lambda q, k=v[i + 1]: q * k) for i in range(3)] + [px[3]])
            if r.gradient is not None:
                o, g0, g1 = r.gradient[1], r.gradient[2], r.gradient[3]
                horiz = str(o).upper() == 'HORIZONTAL'
                n = W if horiz else H
                ramp = Image.new('RGBA', (n, 1))
                for i in range(n):
                    t = i / max(1, n - 1)
                    if not horiz: t = 1 - t  # vertical: min colour at the bottom
                    ramp.putpixel((i, 0), tuple(int(255 * (g0[k] + (g1[k] - g0[k]) * t)) for k in (1, 2, 3, 4)))
                ramp = ramp.resize((W, H)) if horiz else ramp.transpose(Image.ROTATE_270).resize((W, H))
                from PIL import ImageChops
                im = ImageChops.multiply(im, ramp)
            if r.mask is not None:
                m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).ellipse((0, 0, W - 1, H - 1), fill=255)
                im.putalpha(Image.composite(im.split()[3], Image.new('L', (W, H), 0), m))
            if r.rotation:
                im2 = im.rotate(math.degrees(r.rotation), resample=Image.BICUBIC, expand=True)
                x0 -= (im2.width - im.width) / 2; y0 -= (im2.height - im.height) / 2
                im = im2
            if a < 1:
                im.putalpha(im.split()[3].point(lambda q: q * a))
        else:
            fpath = local_path(fget(r, 'file')) or os.path.join(ADDON, 'Fonts', 'IMFeENrm28P.ttf')
            size = (fget(r, 'size') or 12) * eff_scale(r) * SS
            fnt = font(fpath, size)
            col = fget(r, 'color') or {1: 1, 2: 1, 3: 1, 4: 1}
            col = tuple(int(col[i] * 255) for i in (1, 2, 3)) + (int(col[4] * 255 * a),)
            raw = r.text or ''
            base = col
            lines = wrap_lines(fget(r, 'file'), fget(r, 'size') or 12, raw, r.w) if (r.wrap and r.w) else [raw]
            if not (r.wrap and r.w) and r.w and fnt.getlength(strip_codes(raw)) > W + 1:
                t = strip_codes(raw)
                while t and fnt.getlength(t + '…') > W: t = t[:-1]
                lines = [t + '…']
            im = Image.new('RGBA', (W + 40, H + 40), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            j = (fget(r, 'justify') or 'CENTER').upper()
            asc, desc = fnt.getmetrics()
            lh = size + (r.spacing or 0) * eff_scale(r) * SS
            sh = fget(r, 'shadow')
            if sh is not None and (sh[1] or sh[2]):
                shc = fget(r, 'shadowColor') or {1: 0, 2: 0, 3: 0, 4: 1}
                shcol = tuple(int(shc[i] * 255) for i in (1, 2, 3)) + (int(shc[4] * 255 * a),)
            cur = base
            top = 20 + (H - (lh * len(lines) - (r.spacing or 0) * eff_scale(r) * SS)) / 2
            for li, line in enumerate(lines):
                tw = fnt.getlength(strip_codes(line))
                tx = 20 + (0 if j == 'LEFT' else (W - tw) if j == 'RIGHT' else (W - tw) / 2)
                ty = top + li * lh + (lh - (asc + desc)) / 2
                pos = 0
                for m in list(CODE.finditer(line)) + [None]:
                    seg = line[pos:m.start()] if m else line[pos:]
                    if seg:
                        if sh is not None and (sh[1] or sh[2]):
                            d.text((tx + sh[1] * SS, ty - sh[2] * SS), seg, font=fnt, fill=shcol)
                        d.text((tx, ty), seg, font=fnt, fill=cur)
                        tx += fnt.getlength(seg)
                    if m:
                        c = m.group(0)
                        cur = base if c in ('|r', '|R') else (int(c[4:6], 16), int(c[6:8], 16), int(c[8:10], 16), base[3])
                        pos = m.end()
            x0 -= 20; y0 -= 20
            if r.rotation:
                im2 = im.rotate(math.degrees(r.rotation), resample=Image.BICUBIC, expand=True)
                x0 -= (im2.width - im.width) / 2; y0 -= (im2.height - im.height) / 2
                im = im2
        layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
        additive = r.objectType == 'Texture' and r.blend == 'ADD'
        layer.paste(im, (int(round(x0)), int(round(y0))))
        c = clip(r)
        if c:
            if c[2] <= c[0] or c[3] <= c[1]: continue  # clipped away entirely
            m = Image.new('L', canvas.size, 0); ImageDraw.Draw(m).rectangle(to_px(c), fill=255)
            layer.putalpha(Image.composite(layer.split()[3], Image.new('L', canvas.size, 0), m))
        if additive:
            from PIL import ImageChops
            la = layer.split()[3]
            rgb = Image.merge('RGB', [ImageChops.multiply(ch, la) for ch in layer.split()[:3]])
            base = canvas.convert('RGB')
            out = ImageChops.add(base, rgb)
            canvas.paste(out.convert('RGBA'))
        else:
            canvas.alpha_composite(layer)
    canvas.convert('RGB').resize((SW, SH), Image.LANCZOS).save(OUT)
    for p in sorted(set(problems)): print('!!', p)
    print('painted', len(draws), 'regions ->', OUT)

def advance(dt):
    """Run every visible frame's OnUpdate once with elapsed = dt (the kits' motion is time-based)."""
    g._NOW = (g._NOW or 0) + dt
    for r in list(g._MOCK.REG.values()):
        if r.objectType in ('Texture', 'FontString', 'MaskTexture'): continue
        sc = r.scripts
        if sc is None or not visible(r): continue
        fn = sc['OnUpdate']
        if fn is not None: fn(r, dt)

if '--frames' in args:
    # --frames 0,0.2,0.4 ... : paint one PNG per time (OUT must contain %d or %03d)
    ts = [float(x) for x in args[args.index('--frames') + 1].split(',')]
    now = 0.0
    for i, t in enumerate(ts):
        steps = max(1, int(round((t - now) * 30)))
        if t > now:
            for _ in range(steps): advance((t - now) / steps)
        now = t
        paint(OUT % i)
else:
    nlog = len(logs)
    if '--t' in args:
        T = float(args[args.index('--t') + 1])
        n = max(1, int(T * 30))
        for _ in range(n): advance(T / n)
        for s_ in logs[nlog:]: print('chat (t):', re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', s_))
    paint(OUT)
