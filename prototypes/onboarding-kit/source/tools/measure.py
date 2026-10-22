"""Dump the layout of canvas boards (rendered by ob_render.py into ob/out/<name>.html): every leaf text box and
every element with a class, with its rect relative to its page (.j-page) or the board, and its font.
Usage: python3 ob/measure.py Welcome TackleBox ...   -> ob/out/<name>.layout.txt"""
import sys, os, json
from playwright.sync_api import sync_playwright
JS = r'''() => {
  const out = [];
  const pageOf = el => el.closest('.j-page') || document.querySelector('.g-world, .g-stage') || document.body;
  for (const el of document.querySelectorAll('body *')) {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || el.tagName === 'STYLE' || el.tagName === 'path' || el.tagName === 'circle') continue;
    const r = el.getBoundingClientRect(); if (!r.width && !r.height) continue;
    const own = [...el.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent).join('').replace(/\s+/g, ' ').trim();
    if (!own && !el.className) continue;
    const pg = pageOf(el); const pr = pg.getBoundingClientRect();
    const pk = pg.classList.contains('j-page') ? (pg.classList.contains('l') ? 'L' : 'R') : 'W';
    let lines = 0;
    if (own) { const rg = document.createRange(); rg.selectNodeContents(el); const rs = [...rg.getClientRects()]; const ys = new Set(rs.map(q => Math.round(q.top))); lines = ys.size; }
    out.push({ pg: pk, cls: (typeof el.className === 'string' ? el.className : '') , tag: el.tagName.toLowerCase(),
      x: +(r.left - pr.left).toFixed(1), y: +(r.top - pr.top).toFixed(1), w: +r.width.toFixed(1), h: +r.height.toFixed(1),
      text: own.slice(0, 70), font: own ? cs.fontFamily.split(',')[0].replace(/['"]/g, '') + ' ' + cs.fontStyle[0] + ' ' + cs.fontWeight + ' ' + cs.fontSize + '/' + cs.lineHeight + ' ' + cs.color : '', lines });
  }
  return out;
}'''
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1440, 'height': 1100})
    for n in sys.argv[1:]:
        pg.goto('file://' + os.path.abspath(f'ob/out/{n}.html')); pg.wait_for_timeout(400)
        rows = pg.evaluate(JS)
        with open(f'ob/out/{n}.layout.txt', 'w') as f:
            for r in rows:
                f.write(f"{r['pg']} {r['x']:7.1f} {r['y']:7.1f} {r['w']:6.1f}x{r['h']:<6.1f} {r['tag']}.{r['cls'][:28]:<28} {('L'+str(r['lines'])) if r['text'] else ''} {r['font']} | {r['text']}\n")
        json.dump(rows, open(f'ob/out/{n}.layout.json', 'w'))
        print(n, len(rows))
    b.close()
