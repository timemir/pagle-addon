#!/usr/bin/env python3
"""Guide kit: everything onboarding adds to the Ledger's book shell, rendered straight from its canvas
(https://claude.ai/artifact/9XAA1KiZtiaHmc9FDGoQq3, "Onboarding redesign").

Run:  python3 art/guide/generate.py <canvas_project_dir> <assets_dir> <screens_dir> <out_dir>
  GuideParts.tga (2 texels per unit): step ribbons (three states), the letter's seal and slip, margin-note paper,
    its number badge and the target ring, key caps (small, big, waiting, listening), choice cards (three states)
    and radios, checkboxes, the binding field and the conflict box, the coach bar, the next-action bezel and its
    slip, promise discs, the part icons, the compartment-menu box and coin, the swap arrows, equipment-slot rings,
    the bookplate and its portrait ring, the lacquer box (Nudges, tooltips), the sample frame, the tracker paper
    and its boxes.
  Samples.tga (1 texel per unit): stand-ins cut from the other kits' renders, for the pages that show a sample
    (a Nod, a toast, a banner, the summary card, board Notices, the Campfire, the Fly Box, the ink bar).
    In the addon these are the real frames.
  Screen-<name>.tga (1024 x 1024): stand-ins for the first-look windows (Journal, Hunts, Stats, Tackle Board,
    Curio Shop), scaled to 1024 wide; the addon puts first looks on the real windows.
"""
import os, re, sys
from bs4 import BeautifulSoup
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lib'))
import sprites as S
from sprites import Sprite, render, pack, write, fonts_css

CP, AS, SC, OUT = sys.argv[1:5]
HERE = os.path.dirname(os.path.abspath(__file__))
SCRATCH = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
TEX = 'Interface\\AddOns\\PagleArtGuide\\Textures\\'
FONTS = fonts_css(os.path.join(SCRATCH, 'fonts'))
BLOB = {'081a6fe281f30628a15e311442baf270': 'leather.png', '4caec75107b7a3201e560d6772fc88a7': 'parchment.jpg',
        '91657af4f63e99c722883ddfcc07459f': 'binding.png', 'b40ffd542cc12d0417b4dfc0263d54b2': 'seal.png',
        '8fc72a4698d01d449073618a4879fcef': 'seal-empty.png', 'f659942c0ce7384867876460efd8c946': 'close.png',
        'd74b36394bca7c35ab283b41b5cf0ccb': 'plate.png', 'd2ccb06d100cbc2122b8ffe5369e6fa1': 'fleuron.png',
        '8add3a9b6a338889e7625f17a98a10e5': 'ribbon.png'}
BLOB = {k: os.path.join(AS, v) for k, v in BLOB.items()}
SEAL = '/_blob/b40ffd542cc12d0417b4dfc0263d54b2'

def board(n): return BeautifulSoup(open(os.path.join(CP, n + '.dc.html')).read(), 'html.parser')
def style(n):
    m = re.search(r'<style>(.*?)</style>', open(os.path.join(CP, n + '.dc.html')).read(), re.S)
    return m.group(1).replace('body{margin:0}', '') if m else ''
css = (open(os.path.join(CP, 'journal.css')).read() + open(os.path.join(CP, 'guide.css')).read()
       + ''.join(style(n) for n in ('TackleBox', 'Casting', 'Gear', 'Ledger', 'Board', 'Moments', 'Parts')))
# boards' own rules that would fight a sprite's box
css += '#in > * { margin: 0 !important; }'

def fit(sp):
    bb = sp.img.getbbox(); sp.img = sp.img.crop(bb)
    sp.m = (0, 0, 0, 0); sp.w, sp.h = sp.img.width / S.SCALE, sp.img.height / S.SCALE
def loose(name, html, w=240, h=60):
    return Sprite(name, f'<div style="position:absolute;left:8px;top:8px;white-space:nowrap">{html}</div>', w, h, cls='loose')

tb = board('TackleBox')
icons = {k: str(sv) for k, sv in zip(['journal', 'hunts', 'stats', 'board', 'qol', 'shop'], tb.select('.part .ic svg'))}
arr_svg = str(board('Gear').select_one('.arr svg'))

STATIC = 'position:relative !important;left:0;top:0;transform:none'
parts = [
  # step ribbons, label drawn as text in game (ONB-R24)
  Sprite('rib', '<a class="g-rib" style="display:block"></a>', 98, 92),
  Sprite('rib-done', '<a class="g-rib done" style="display:block"></a>', 98, 92),
  Sprite('rib-on', '<a class="g-rib on" style="display:block"></a>', 98, 110),
  # the letter: the seal (tilted, shadowed) and the torn slip at its canvas size
  Sprite('letter-seal', f'<div class="g-letter" style="position:relative"><div class="seal"><img src="{SEAL}" alt=""></div></div>', 82, 82, margin=16),
  Sprite('letter-slip', '<div class="g-letter" style="position:relative"><div class="slip" style="width:470px;height:132px"></div></div>', 470, 132, margin=(10, 16, 22, 16)),
  # margin notes: paper (nine-sliced in game), the red-pencil badge and the target ring
  Sprite('note', f'<div class="g-note" style="{STATIC};width:120px;height:70px;max-width:none"></div>', 120, 70, margin=(10, 16, 22, 16)),
  Sprite('note-badge', '<div class="g-note" style="position:relative;transform:none;background:none;box-shadow:none;padding:0;width:26px;height:26px"><span class="n" style="left:0;top:0"></span></div>', 26, 26, margin=4),
  Sprite('ring', '<span style="display:block;width:12px;height:12px;box-sizing:border-box;border-radius:50%;border:2px solid #9a2a1a;background:rgba(154,42,26,.25);box-shadow:0 0 0 3px rgba(255,240,220,.35)"></span>', 12, 12, margin=4),
  # key caps: the small one three-sliced; big ones at their sizes
  Sprite('key', '<span class="g-key" style="display:block;width:40px;vertical-align:0"></span>', 40, 24, margin=(1, 1, 3, 1)),
  Sprite('key-big', '<span class="g-key big" style="display:block;width:64px;vertical-align:0"></span>', 64, 40, margin=(1, 1, 4, 1)),
  Sprite('key-wait', '<span class="g-key big wait" style="display:block;width:128px;vertical-align:0"></span>', 128, 40, margin=1),
  Sprite('key-listen', '<span class="g-key big wait" style="display:block;width:128px;vertical-align:0;border-color:#9a2a1a"></span>', 128, 40, margin=1),
  # choice cards (nine-sliced) and their radios
  Sprite('opt', '<a class="g-opt" style="display:block;width:120px;height:60px"></a>', 120, 60, margin=(1, 3, 4, 1)),
  Sprite('opt-hover', '<a class="g-opt" style="display:block;width:120px;height:60px;border-color:#9a2a1a;background:rgba(255,248,228,.55)"></a>', 120, 60, margin=(1, 3, 4, 1)),
  Sprite('opt-on', '<a class="g-opt on" style="display:block;width:120px;height:60px"></a>', 120, 60, margin=(1, 3, 4, 1)),
  Sprite('radio', '<a class="g-opt" style="display:block;border:0;background:none;box-shadow:none;padding:0;width:12px;height:12px"><span class="r" style="margin:0;display:block"></span></a>', 12, 12, margin=1),
  Sprite('radio-on', '<a class="g-opt on" style="display:block;border:0;background:none;box-shadow:none;padding:0;width:12px;height:12px"><span class="r" style="margin:0;display:block"></span></a>', 12, 12, margin=1),
  # checkboxes: the page's (Casting) and the tracker's
  Sprite('check', '<div class="chk" style="margin:0"><span class="bx" style="margin:0"></span></div>', 15, 15, margin=1),
  Sprite('check-off', '<span style="display:block;width:15px;height:15px;border:1.5px solid #6a4a20;border-radius:2px;box-sizing:border-box;background:rgba(255,248,228,.5)"></span>', 15, 15, margin=1),
  Sprite('li-box', '<div class="g-li" style="padding:0"><span class="b" style="margin:0"></span></div>', 12, 12, margin=2),
  Sprite('li-done', '<div class="g-li done" style="padding:0"><span class="b" style="margin:0"></span></div>', 12, 12, margin=(4, 2, 2, 2)),
  # boxes (nine-sliced in game)
  Sprite('bind', '<div class="g-bind" style="width:140px;height:56px;box-sizing:border-box;background:rgba(255,248,228,.35)"></div>', 140, 56, margin=1),
  Sprite('conf', '<div class="conf" style="width:160px;height:76px;box-sizing:border-box"></div>', 160, 76, margin=1),
  Sprite('field', '<span class="dd" style="display:block;width:100px;height:30px;box-sizing:border-box"></span>', 100, 30, margin=1),
  Sprite('coachbar', '<div class="g-coachbar" style="position:relative;width:160px"></div>', 160, 40, margin=(10, 16, 22, 16)),
  Sprite('lacquer', '<div class="nudge" style="width:100px;height:40px;box-sizing:border-box;margin:0"></div>', 100, 40, margin=(4, 6, 12, 6)),
  Sprite('win', '<div class="win" style="width:100px;height:40px;background-color:transparent;background-image:none"></div>', 100, 40, margin=5),
  Sprite('menu', '<div class="menu" style="height:80px"></div>', 214, 80, margin=(4, 6, 18, 6)),
  Sprite('card', '<div class="kit" style="width:100px;height:80px"></div>', 100, 80, margin=(1, 3, 4, 1)),
  # the next-action button (QOL-R70's look) and its slip
  Sprite('nab', '<div class="g-nab"></div>', 52, 52, margin=(6, 6, 10, 6)),
  Sprite('nab-lab', '<div class="g-nab-lab" style="margin:0;width:56px;height:22px;box-sizing:border-box"></div>', 56, 22, margin=1),
  # promise discs (the seal, tilted)
  Sprite('disc', f'<div class="g-disc"><img src="{SEAL}" alt=""></div>', 46, 46, margin=6),
  # bookplate (Your Ledger), untilted so its text sits straight, and the portrait's gilt ring
  Sprite('plate', '<div class="plate" style="transform:none;width:250px;height:236px;margin:0"></div>', 250, 236, margin=10),
  Sprite('face', '<div class="plate" style="border:0;outline:0;background:none;box-shadow:none;padding:0;width:64px;height:64px;transform:none"><div class="face" style="margin:0;background:none"></div></div>', 64, 64, margin=6),
  Sprite('slot', '<span class="sl" style="display:block;background:none"></span>', 34, 34, margin=1),
  Sprite('coin', '<span class="coin" style="display:block"></span>', 11, 11, margin=1),
  Sprite('arrows', f'<div style="width:46px;height:30px">{arr_svg}</div>', 46, 30),
  Sprite('trk', '<div class="g-trk" style="position:relative;height:140px"></div>', 274, 140, margin=(4, 8, 12, 8)),
  # page buttons (the Ledger kit's, three-sliced with 10-unit caps)
  Sprite('button', '<a class="j-button" style="width:160px;height:34px;box-sizing:border-box"></a>', 160, 34, margin=(1, 2, 5, 2)),
  Sprite('button-hover', '<a class="j-button" style="width:160px;height:34px;box-sizing:border-box;filter:brightness(1.15)"></a>', 160, 34, margin=(1, 2, 5, 2)),
  Sprite('button-light', '<a class="j-button" style="width:160px;height:34px;box-sizing:border-box;background:linear-gradient(#efe0bb,#d8c08a);border-color:#6a4a20"></a>', 160, 34, margin=(1, 2, 5, 2)),
  Sprite('button-off', '<a class="j-button" style="width:160px;height:34px;box-sizing:border-box;filter:grayscale(.7) brightness(.8)"></a>', 160, 34, margin=(1, 2, 5, 2)),
] + [Sprite('ic-' + k, f'<span class="ic">{sv}</span>', 36, 36, margin=5) for k, sv in icons.items()]

# ------------------------------------------------------------------ samples: stand-ins cut from the other kits' renders
CROPS = {  # name: (file, left, top, right, bottom) in the render's pixels (1 per UI unit)
  'nod-new': ('nods.png', 58, 164, 418, 200), 'nod-elem': ('nods.png', 58, 220, 482, 256), 'nod-unk': ('nods.png', 58, 385, 450, 425),
  'toast': ('announce.png', 490, 595, 955, 690), 'banner': ('announce.png', 365, 85, 1060, 375),
  'summary': ('session.png', 430, 95, 1010, 420), 'notices': ('board.png', 130, 315, 625, 450),
  'campfire': ('board.png', 110, 600, 390, 740), 'flybox': ('board.png', 400, 600, 680, 740), 'fresh': ('journal.png', 540, 188, 940, 242),
}
samples = []
for name, (f, l, t, r, b) in CROPS.items():
    sp = Sprite(name, '', (r - l), (b - t))
    sp.img = Image.open(os.path.join(SC, f)).convert('RGBA').crop((l, t, r, b))
    samples.append(sp)

# ------------------------------------------------------------------ render
os.makedirs(OUT, exist_ok=True)
S.SCALE = 2
marks = [loose('tick-red', '<span style="font:700 20px Caveat, serif;color:#9a2a1a">✓</span>'),
         loose('ring-ghost', '<span style="font:700 20px Caveat, serif;color:#b0a080">○</span>'),
         loose('caret', '<span style="font:14.5px serif;color:#3e220c">▾</span>')]
render(parts + marks, css, FONTS, BLOB, extra_head='<style>#box.loose{overflow:visible}</style>')
for m in marks: fit(m)
parts = parts + marks
atlas, rects = pack(parts)
write(OUT, 'GuideParts', TEX, atlas, rects, parts, scale=2)
print('GuideParts', atlas.size, len(parts))
S.SCALE = 1
atlas, rects = pack(samples, pad=1)
write(OUT, 'Samples', TEX, atlas, rects, samples, scale=1)
print('Samples', atlas.size, len(samples))
for n in ('journal', 'hunts', 'stats', 'board', 'shop'):
    im = Image.open(os.path.join(SC, n + '.png')).convert('RGBA')
    k = 1024 / im.width
    im = im.resize((1024, round(im.height * k)), Image.LANCZOS)
    page = Image.new('RGBA', (1024, 1024), (0, 0, 0, 255)); page.paste(im, (0, 0))
    page.save(os.path.join(OUT, f'Screen-{n}.tga'))
    print('Screen', n, im.size)
