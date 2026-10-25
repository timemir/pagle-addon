// Curio crate opening: a design prototype. The result is chosen first (as the addon's log hash chooses it); the
// animation only shows it. Odds and the tier given to each good are placeholders.
(() => {
  'use strict';
  const $ = (s, r = document) => r.querySelector(s);

  // ---------- tiers and odds ----------
  const TIERS = [
    { n: 'Common', c: '233 230 223', p: 40 },
    { n: 'Uncommon', c: '62 211 90', p: 26 },
    { n: 'Rare', c: '59 134 255', p: 16 },
    { n: 'Epic', c: '176 92 255', p: 10 },
    { n: 'Mythic', c: '236 58 63', p: 5 },
    { n: 'Legendary', c: '255 138 28', p: 2.5 },
    { n: 'Curio', c: '255 208 74', p: 0.5 },
  ];

  // ---------- the pool: goods for sale, given demo tiers ----------
  const T = (k, n, t) => ({ kind: 'toast', key: k, name: n, tier: t, art: `img/toast-${k}.webp` });
  const B = (k, n, t) => ({ kind: 'book', key: k, name: n, tier: t, art: `img/books/${k}.webp` });
  const S = (n, t) => ({ kind: 'sound', key: n, name: n, tier: t });
  const GOODS = [
    B('birch-bark', 'Birch Bark', 0), B('canvas', 'Canvas Field Pad', 0), B('kraft', 'Waxed Kraft', 0), B('field-leather', 'Field Leather', 0),
    B('sailcloth', 'Tarred Sailcloth', 0), B('oilskin', 'Oilskin Yellow', 0), B('chartlinen', 'Tide-Chart Linen', 0),
    S('Rain on the Lake', 0), S('Marimba Shore', 0), S("Ship's Bell", 0), S('Squeaky', 0), S('Bubbleworks', 0),
    B('tartan', 'Tartan Wool', 1), B('sea-green-buckram', 'Sea-Green Buckram', 1), B('moss', 'Mossbound', 1), B('driftwood', 'Driftwood Boards', 1),
    B('eelskin', 'Eelskin', 1), B('kodo', 'Kodo Hide', 1), B('frosthide', 'Frost-Tanned Hide', 1), B('netcork', 'Net over Cork', 1),
    S('Kalimba Creek', 1), S('Music Box', 1), S('Glass Floats', 1), S('Steel Pan Lagoon', 1), S('Kazoo Parade', 1), S('Boing!', 1), S('Slime Time', 1),
    B('maplinen', 'Map Linen', 2), B('planks', 'Bound Planks', 2), B('sharkskin', 'Sharkskin', 2), B('copper', 'Riveted Copper', 2),
    S('Frost Chimes', 2), S('Harp of the Glade', 2), S('Gnomish Gizmo', 2), S('Mrglglgl', 2), S('Pirate Parrot', 2), S('Gnomish Laser', 2),
    T('ooze', 'Ooze', 3), T('robot', 'Mechanical Angler', 3), T('spider', "Widow's Web", 3), T('pirate', 'Black Flag', 3),
    B('velvet', 'Night Velvet', 3), B('turtle', 'Turtle Shell', 3), B('morocco', 'Gilded Morocco', 3), B('snakeskin', 'Snakeskin', 3),
    B('lacquer', 'Lacquered Red', 3), S('Silithid Swarm', 3), S("Succubus' Whisper", 3),
    T('hive', 'Hive Chitin', 4), T('glacier', 'Glacier Heart', 4), T('magma', 'Magma Flow', 4),
    B('shagreen', 'Stingray Shagreen', 4), B('bone', 'Bone & Rawhide', 4), B('coral', 'Coral Inlay', 4), B('scrimshaw', 'Scrimshaw Panel', 4),
    S('War Drums', 4), S("Dragon's Roost", 4),
    T('arcane', 'Arcane Sigil', 5), T('storm', 'Storm Front', 5), B('shagreenbone', 'Shagreen and Bone', 5), B('pearl', 'Mother-of-Pearl', 5),
    B('brasscase', "Brass Hunter's Case", 5), B('trophycase', 'Gilded Trophy Case', 5),
    T('foil', 'Prize Foil', 6),
  ];
  const KIND = { toast: 'Toast style', book: 'Journal binding', sound: 'Sound set' };
  const owned = new Set();
  const left = (t) => GOODS.filter((g) => g.tier === t && !owned.has(g));
  const pick = (a) => a[Math.floor(Math.random() * a.length)];

  // Tier first, then a good of that tier the player doesn't own. A tier with nothing left drops out and the others'
  // odds are scaled up to fill (a decision for the spec, flagged in the notes).
  function rollTier(exclude) {
    const live = TIERS.map((t, i) => ({ i, p: t.p })).filter((x) => left(x.i).length && x.i !== exclude);
    let r = Math.random() * live.reduce((s, x) => s + x.p, 0);
    for (const x of live) if ((r -= x.p) < 0) return x.i;
    return live.length ? live[live.length - 1].i : 0;
  }
  // Filler cards are rolled exactly as the result is, from what the player could still win: nothing placed.

  // ---------- small art ----------
  const glyph = {
    toast: '<svg class="kind" viewBox="0 0 18 18"><rect x="1" y="4" width="16" height="10" rx="2" fill="none" stroke="#fff" stroke-width="1.5"/><circle cx="5.5" cy="9" r="2.2" fill="#fff"/></svg>',
    book: '<svg class="kind" viewBox="0 0 18 18"><path d="M3 2 H14 V16 H3Z M5 2 V16" fill="none" stroke="#fff" stroke-width="1.5"/></svg>',
    sound: '<svg class="kind" viewBox="0 0 18 18"><path d="M7 13 V3 L15 1.5 V11" fill="none" stroke="#fff" stroke-width="1.5"/><circle cx="5" cy="13.5" r="2.4" fill="#fff"/><circle cx="13" cy="11.5" r="2.4" fill="#fff"/></svg>',
  };
  // sound sets have no picture of their own: one of five brass instruments, chosen by name, with the tier's sound rings
  function soundArt(c, name = '') {
    const id = 'sb' + c.replace(/ /g, ''), h = [...name].reduce((x, ch) => (x * 31 + ch.charCodeAt(0)) >>> 0, 7) % 5;
    const brass = `fill="url(#${id})" stroke="#3a2406" stroke-width="2"`;
    const shapes = [
      `<path d="M36 92 h46 l-6 -10 c-3 -6 -4 -14 -4 -26 c0 -10 -6 -18 -13 -20 v-6 c0 -3 -6 -3 -6 0 v6 c-7 2 -13 10 -13 20 c0 12 -1 20 -4 26z" ${brass}/><circle cx="59" cy="97" r="6" fill="#c89838" stroke="#3a2406" stroke-width="2"/>`,
      `<ellipse cx="59" cy="50" rx="26" ry="9" ${brass}/><path d="M33 50 v34 c0 6 52 6 52 0 v-34" ${brass}/><path d="M33 58 l13 22 l13 -22 l13 22 l13 -22" fill="none" stroke="#7a1a10" stroke-width="2.5"/><ellipse cx="59" cy="50" rx="22" ry="6" fill="#f4e4c0" opacity=".85"/><path d="M40 28 l14 18 M80 26 l-12 20" stroke="#5a3a14" stroke-width="4" stroke-linecap="round"/>`,
      `<path d="M28 74 c10 0 24 -8 34 -20 l10 -12 c4 -6 14 -14 20 -12 l0 44 c-6 2 -16 -6 -20 -12 l-10 -2 c-10 -4 -24 4 -34 4z" ${brass}/><circle cx="28" cy="78" r="5" fill="#c89838" stroke="#3a2406" stroke-width="2"/>`,
      `<path d="M48 88 V34 L84 26 V80" fill="none" stroke="url(#${id})" stroke-width="7" stroke-linejoin="round"/><path d="M48 34 L84 26 V38 L48 46Z" ${brass}/><ellipse cx="40" cy="88" rx="12" ry="9" ${brass}/><ellipse cx="76" cy="80" rx="12" ry="9" ${brass}/>`,
      `<path d="M38 96 C34 70 40 40 70 24 C76 34 74 44 82 48 C70 60 66 80 70 96Z" ${brass}/><path d="M46 92 L60 34 M54 92 L66 40 M62 92 L71 46" stroke="#3a2406" stroke-width="1.5" opacity=".8"/><path d="M34 96 H74" stroke="#3a2406" stroke-width="4" stroke-linecap="round"/>`,
    ];
    return `<svg class="art" width="118" height="118" viewBox="0 0 118 118">
      <defs><radialGradient id="${id}" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#fff2c4"/><stop offset=".45" stop-color="#d4a548"/><stop offset="1" stop-color="#6a4410"/></radialGradient></defs>
      ${shapes[h]}
      <g fill="none" stroke="rgb(${c})" stroke-width="4" stroke-linecap="round" opacity=".9">
        <path d="M98 46 a18 18 0 0 1 0 26"/><path d="M106 38 a30 30 0 0 1 0 42" opacity=".55"/>
        <path d="M20 46 a18 18 0 0 0 0 26"/><path d="M12 38 a30 30 0 0 0 0 42" opacity=".55"/></g></svg>`;
  }
  // ---------- the reel's cards: one emblem per kind of good, struck in the tier's metal ----------
  // A new good needs nothing here; a new kind of good needs one emblem.
  const KIND_LABEL = { toast: 'Toast style', book: 'Binding', sound: 'Sound set', tracker: 'Tracker frame' };
  const mix = (c, to, k) => c.split(' ').map(Number).map((v) => Math.round(v + (to - v) * k)).join(',');
  const EMBLEM = {
    toast: (f, d) => `<path d="M30 30 H86 a6 6 0 0 1 6 6 V40 L98 46 L92 52 V64 a6 6 0 0 1 -6 6 H30Z" fill="${f}" stroke="${d}" stroke-width="2.5"/>
      <path d="M44 42 H82 M44 50 H76 M44 58 H80" stroke="${d}" stroke-width="2.5" stroke-linecap="round" opacity=".55"/>
      <circle cx="30" cy="50" r="24" fill="${f}" stroke="${d}" stroke-width="2.5"/><circle cx="30" cy="50" r="17" fill="none" stroke="${d}" stroke-width="2" opacity=".6"/>
      <path d="M18 50 c5 -7 15 -8 21 -2 l6 -5 v14 l-6 -5 c-6 6 -16 5 -21 -2z" fill="${d}"/>`,
    book: (f, d) => `<path d="M24 16 H76 a6 6 0 0 1 6 6 V84 a6 6 0 0 1 -6 6 H24Z" fill="${f}" stroke="${d}" stroke-width="2.5"/>
      <path d="M24 16 V90 M33 16 V90" stroke="${d}" stroke-width="2.5"/><path d="M82 26 H90 V42 H82 M82 64 H90 V80 H82" fill="${f}" stroke="${d}" stroke-width="2.5"/>
      <rect x="42" y="36" width="30" height="28" rx="3" fill="none" stroke="${d}" stroke-width="2.5" opacity=".7"/>
      <path d="M47 50 c4 -5 11 -6 15 -2 l5 -4 v12 l-5 -4 c-4 4 -11 3 -15 -2z" fill="${d}"/><path d="M38 90 V98 L42 95 L46 98 V90" fill="${d}"/>`,
    tracker: (f, d) => `<rect x="14" y="20" width="72" height="62" rx="5" fill="${f}" stroke="${d}" stroke-width="2.5"/>
      <rect x="22" y="30" width="56" height="44" rx="2" fill="${d}" opacity=".55"/>
      <path d="M30 42 H70 M30 52 H62 M30 62 H66" stroke="${f}" stroke-width="3.5" stroke-linecap="round"/>
      <circle cx="50" cy="20" r="6" fill="${f}" stroke="${d}" stroke-width="2.5"/><path d="M14 30 H8 M14 72 H8 M86 30 H92 M86 72 H92" stroke="${d}" stroke-width="2.5"/>`,
    sound: (f, d) => `<path d="M28 78 h44 l-6 -9 c-3 -5 -4 -12 -4 -22 c0 -9 -5 -15 -11 -17 v-5 c0 -3 -6 -3 -6 0 v5 c-6 2 -11 8 -11 17 c0 10 -1 17 -4 22z" fill="${f}" stroke="${d}" stroke-width="2.5"/>
      <circle cx="50" cy="83" r="5.5" fill="${f}" stroke="${d}" stroke-width="2.5"/><path d="M40 70 c0 -10 2 -22 6 -30" stroke="#fff" stroke-width="3" opacity=".35" fill="none" stroke-linecap="round"/>
      <g fill="none" stroke="${f}" stroke-width="4" stroke-linecap="round"><path d="M80 40 a16 16 0 0 1 0 24"/><path d="M89 32 a28 28 0 0 1 0 40" opacity=".55"/>
      <path d="M20 40 a16 16 0 0 0 0 24"/><path d="M11 32 a28 28 0 0 0 0 40" opacity=".55"/></g>`,
  };
  let emblemN = 0;
  function typeCard(kind, ti, attrs = '', css = '') {
    const t = TIERS[ti];
    if (ti === 6) return `<div class="card t7" ${attrs} style="--tc:${t.c};${css}"><div class="q">?</div></div>`;
    const id = 'em' + emblemN++, f = `url(#${id})`, d = `rgb(${mix(t.c, 0, 0.72)})`;
    return `<div class="card type" ${attrs} style="--tc:${t.c};${css}">
      <svg class="emblem" viewBox="0 0 100 100" width="104" height="104" aria-hidden="true"><defs><linearGradient id="${id}" x1="0" y1="0" x2=".6" y2="1">
        <stop offset="0" stop-color="rgb(${mix(t.c, 255, 0.75)})"/><stop offset=".45" stop-color="rgb(${t.c})"/><stop offset="1" stop-color="rgb(${mix(t.c, 0, 0.45)})"/></linearGradient></defs>
        ${EMBLEM[kind](f, d)}</svg>
      <span class="klabel">${KIND_LABEL[kind]}</span><div class="sheen"></div></div>`;
  }
  function cardHTML(g, ti, attrs = '', css = '') {
    const t = TIERS[ti];
    if (ti === 6 && !g) return `<div class="card t7" ${attrs} style="--tc:${t.c};${css}"><div class="q">?</div></div>`;
    const art = g.kind === 'sound' ? soundArt(t.c, g.name) : `<img class="art ${g.kind}" src="${g.art}" alt="">`;
    return `<div class="card${ti === 6 ? ' gilt' : ''}" ${attrs} style="--tc:${t.c};${css}">${glyph[g.kind]}${art}<div class="sheen"></div></div>`;
  }

  // ---------- timing (half speed doubles every duration) ----------
  let slow = false, animOn = !matchMedia('(prefers-reduced-motion: reduce)').matches, soundOn = true;
  const SP = () => (slow ? 2 : 1);
  let timers = [], raf = 0, phase = 'idle';
  const at = (ms, fn) => timers.push(setTimeout(fn, ms * SP()));
  const clearTimers = () => { timers.forEach(clearTimeout); timers = []; cancelAnimationFrame(raf); };
  const A = (el, kf, o) => el.animate(kf, { fill: 'both', easing: 'ease-out', ...o, duration: o.duration * SP(), delay: (o.delay || 0) * SP() });

  // ---------- sound (WebAudio, synthesised; the addon would use the client's own sound kits) ----------
  let ac, master, verb;
  function audio() {
    if (ac) return ac;
    ac = new (window.AudioContext || window.webkitAudioContext)();
    master = ac.createGain(); master.gain.value = 0.55; master.connect(ac.destination);
    // a short room: two feedback delays
    verb = ac.createGain(); verb.gain.value = 0.22;
    [0.043, 0.071].forEach((d) => {
      const dl = ac.createDelay(); dl.delayTime.value = d; const fb = ac.createGain(); fb.gain.value = 0.42;
      const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2600;
      verb.connect(dl); dl.connect(lp); lp.connect(fb); fb.connect(dl); lp.connect(master);
    });
    return ac;
  }
  function out(node, wet = 0.5) { node.connect(master); if (wet) { const g = ac.createGain(); g.gain.value = wet; node.connect(g); g.connect(verb); } }
  let noiseBuf;
  function noise(dur, type, f, q, vol, t0 = 0, f2) {
    if (!soundOn || !ac) return;
    if (!noiseBuf) { noiseBuf = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate); const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; }
    const t = ac.currentTime + t0, s = ac.createBufferSource(); s.buffer = noiseBuf;
    const b = ac.createBiquadFilter(); b.type = type; b.frequency.setValueAtTime(f, t); b.Q.value = q;
    if (f2) b.frequency.exponentialRampToValueAtTime(f2, t + dur);
    const g = ac.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + Math.min(0.01, dur / 4)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(b); b.connect(g); out(g, 0.3); s.start(t, Math.random()); s.stop(t + dur + 0.05);
  }
  function tone(f, dur, type = 'sine', vol = 0.2, t0 = 0, f2, wet = 0.5, atk = 0.005) {
    if (!soundOn || !ac) return;
    const t = ac.currentTime + t0, o = ac.createOscillator(); o.type = type; o.frequency.setValueAtTime(f, t);
    if (f2) o.frequency.exponentialRampToValueAtTime(f2, t + dur);
    const g = ac.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + atk); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); out(g, wet); o.start(t); o.stop(t + dur + 0.05);
  }
  const sfx = {
    coin: (t0 = 0) => { tone(2350, 0.12, 'triangle', 0.08, t0, 0, 0.3); tone(3520, 0.18, 'sine', 0.05, t0 + 0.03); },
    thud: () => { tone(90, 0.35, 'sine', 0.7, 0, 38, 0.2); noise(0.25, 'lowpass', 500, 0.7, 0.5); noise(0.08, 'bandpass', 1400, 2, 0.15); },
    knock: (n) => { const v = 0.3 + n * 0.12; tone(170 + n * 14, 0.12, 'triangle', v, 0, 120, 0.2); noise(0.07, 'bandpass', 900, 3, v * 0.8); tone(175 + n * 14, 0.1, 'triangle', v * 0.7, 0.09, 130, 0.2); noise(0.06, 'bandpass', 1000, 3, v * 0.6, 0.09); },
    crack: () => { noise(0.18, 'highpass', 2500, 0.8, 0.5); noise(0.06, 'bandpass', 5000, 1, 0.4, 0.03); tone(300, 0.08, 'square', 0.06, 0, 120, 0.1); },
    snap: (t0) => { noise(0.05, 'bandpass', 3200, 4, 0.35, t0); tone(900, 0.05, 'triangle', 0.08, t0, 300, 0.1); },
    whoosh: () => { noise(0.55, 'bandpass', 350, 1.2, 0.45, 0, 2600); tone(220, 0.9, 'sine', 0.12, 0.05, 660, 0.8, 0.2); tone(330, 0.9, 'sine', 0.08, 0.1, 990, 0.8, 0.25); },
    tick: (v = 1) => { noise(0.025, 'bandpass', 3800 + Math.random() * 600, 6, 0.22 * v); tone(1900, 0.03, 'triangle', 0.05 * v, 0, 0, 0.05); },
    unfurl: () => { noise(0.35, 'bandpass', 600, 1, 0.25, 0, 1800); tone(523, 0.3, 'triangle', 0.06, 0.15); },
    stamp: () => { tone(110, 0.2, 'sine', 0.5, 0, 50, 0.1); noise(0.1, 'lowpass', 900, 0.8, 0.4); },
    land: () => { tone(1320, 0.4, 'sine', 0.08, 0); tone(1760, 0.5, 'sine', 0.05, 0.05); },
    reveal(ti) {
      const sets = [[523, 659], [523, 659, 784], [440, 554, 659, 880], [392, 494, 587, 784, 988], [349, 440, 523, 698, 880, 1047], [392, 494, 587, 784, 988, 1175, 1568], [523, 659, 784, 1047, 1319, 1568, 2093]];
      const notes = sets[ti], step = ti >= 4 ? 0.075 : 0.1;
      notes.forEach((f, i) => { tone(f, 1.6 + ti * 0.25, 'triangle', 0.09, i * step, 0, 0.7, 0.01); tone(f * 2, 1.2, 'sine', 0.025, i * step, 0, 0.8); });
      if (ti >= 3) tone(notes[0] / 2, 2.2, 'sawtooth', 0.035, 0, 0, 0.6, 0.15);
      if (ti >= 4) { noise(1.4, 'highpass', 6000, 0.5, 0.06, 0.1); tone(notes[0] / 4, 1.6, 'sine', 0.35, 0, notes[0] / 6, 0.2); }
      if (ti >= 5) { for (let i = 0; i < 10; i++) tone(2000 + Math.random() * 2400, 0.4, 'sine', 0.03, 0.4 + i * 0.07); }
      if (ti === 6) { [1, 2.76, 5.4, 8.9].forEach((m, i) => tone(660 * m, 2.6 / (i + 1), 'sine', 0.12 / (i + 1), 0)); for (let i = 0; i < 14; i++) sfx.coin(0.3 + i * 0.06 + Math.random() * 0.04); }
    },
    flip: (t0) => noise(0.12, 'bandpass', 1800, 2, 0.15, t0, 900),
  };

  // ---------- elements ----------
  const ov = $('#ov'), stage = $('#stage'), crate = $('#crate'), reel = $('#reel'), track = $('#track'), bob = $('#marker .bob');
  const bill = $('#bill'), purse = $('#purse');
  crate.querySelector('.body').innerHTML = CRATE.body;
  crate.querySelector('.lid').innerHTML = CRATE.lid;
  crate.querySelector('.sl').innerHTML = CRATE.sealL;
  crate.querySelector('.sr').innerHTML = CRATE.sealR;
  crate.querySelector('.ribbon').innerHTML = CRATE.ribbon;
  $('#odds').innerHTML = TIERS.map((t) => `<span style="--tc:${t.c}"><i></i>${t.n} ${t.p}%</span>`).join('');

  // the outcome picker
  let forced = -1;
  const oc = $('#outcomes');
  [['By the odds', -1, '200 180 140'], ...TIERS.map((t, i) => [t.n, i, t.c])].forEach(([n, i, c]) => {
    const b = document.createElement('button'); b.className = 'chip'; b.innerHTML = `<i style="--c:rgb(${c})"></i>${n}`;
    b.setAttribute('aria-pressed', String(i === forced)); b.onclick = () => { forced = i; oc.querySelectorAll('.chip').forEach((x) => x.setAttribute('aria-pressed', String(x === b))); };
    oc.appendChild(b);
  });
  const toggle = (id, get, set) => { const b = $(id); const sync = () => { b.setAttribute('aria-pressed', String(get())); if (id !== '#slow') b.textContent = get() ? 'On' : 'Off'; }; b.onclick = () => { set(!get()); sync(); }; sync(); };
  toggle('#snd', () => soundOn, (v) => (soundOn = v));
  toggle('#anim', () => animOn, (v) => (animOn = v));
  toggle('#slow', () => slow, (v) => (slow = v));

  // ---------- purse ----------
  let coins = 49905;
  const fmt = (n) => n.toLocaleString('en-US');
  function countPurse(from, to, ms) {
    const t0 = performance.now(), D = ms * SP(); purse.classList.add('counting');
    let last = from;
    (function f(now) {
      const k = Math.min(1, (now - t0) / D), v = Math.round(from + (to - from) * (1 - Math.pow(1 - k, 2)));
      purse.textContent = fmt(v); if (Math.floor(v / 150) !== Math.floor(last / 150)) sfx.coin(); last = v;
      if (k < 1) requestAnimationFrame(f); else purse.classList.remove('counting');
    })(t0);
  }

  // ---------- particles ----------
  function particle(cls, x, y, kf, dur, delay = 0, style = '') {
    const p = document.createElement('div'); p.className = cls + ' fx'; p.style.cssText = `left:${x}px;top:${y}px;${style}`;
    stage.appendChild(p);
    const a = A(p, kf, { duration: dur, delay, easing: 'cubic-bezier(.2,.7,.4,1)' }); a.onfinish = () => p.remove();
    return p;
  }
  function dust(cx, cy) {
    [-1, 1].forEach((s) => [0, 1].forEach((j) => particle('dust', cx + s * (120 + j * 40) - 45, cy - 20,
      [{ opacity: 0.9, transform: 'translate(0,0) scale(.4)' }, { opacity: 0, transform: `translate(${s * (70 + j * 40)}px,-14px) scale(${1.6 + j * 0.5})` }], 700 + j * 200, j * 40)));
  }
  function straw(cx, cy, n) {
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + (Math.random() - 0.5) * 2.2, v = 200 + Math.random() * 260, dx = Math.cos(a) * v, dy = Math.sin(a) * v, r = Math.random() * 720 - 360;
      particle('straw', cx + (Math.random() - 0.5) * 140, cy, [
        { opacity: 1, transform: 'translate(0,0) rotate(0)' },
        { opacity: 1, transform: `translate(${dx * 0.7}px,${dy * 0.8}px) rotate(${r * 0.6}deg)`, offset: 0.45 },
        { opacity: 0, transform: `translate(${dx}px,${dy * 0.3 + 260}px) rotate(${r}deg)` }], 1300 + Math.random() * 700, Math.random() * 120);
    }
  }
  function sparks(cx, cy, n, c, spread = 320) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, d = 90 + Math.random() * spread, s = 0.5 + Math.random() * 1.3;
      particle('spark', cx - 3, cy - 3, [
        { opacity: 1, transform: `translate(0,0) scale(${s})` },
        { opacity: 1, transform: `translate(${Math.cos(a) * d * 0.8}px,${Math.sin(a) * d * 0.8}px) scale(${s})`, offset: 0.6 },
        { opacity: 0, transform: `translate(${Math.cos(a) * d}px,${Math.sin(a) * d + 40}px) scale(0)` }], 900 + Math.random() * 700, Math.random() * 100,
      `--sc:rgb(${c});background:rgb(${c} / 1);box-shadow:0 0 10px rgb(${c}),0 0 2px #fff`);
    }
  }
  function embers(c, ms) {
    const end = performance.now() + ms * SP();
    (function f() {
      if (performance.now() > end || phase !== 'reveal') return;
      const x = 200 + Math.random() * 726, s = 0.4 + Math.random() * 0.9;
      particle('spark', x, 640, [{ opacity: 0, transform: `translate(0,0) scale(${s})` }, { opacity: 1, transform: `translate(${(Math.random() - 0.5) * 60}px,-180px) scale(${s})`, offset: 0.3 },
        { opacity: 0, transform: `translate(${(Math.random() - 0.5) * 160}px,-${380 + Math.random() * 200}px) scale(0)` }], 2200 + Math.random() * 1200, 0,
      `background:rgb(${c});box-shadow:0 0 8px rgb(${c})`);
      timers.push(setTimeout(f, 70 * SP()));
    })();
  }
  function coinsBurst(cx, cy, n) {
    for (let i = 0; i < n; i++) {
      const dx = (Math.random() - 0.5) * 700, up = 160 + Math.random() * 220;
      particle('goldcoin', cx - 9, cy - 9, [
        { opacity: 1, transform: 'translate(0,0) scaleX(1)' },
        { opacity: 1, transform: `translate(${dx * 0.5}px,${-up}px) scaleX(-1)`, offset: 0.4 },
        { opacity: 1, transform: `translate(${dx * 0.8}px,${-up * 0.4}px) scaleX(1)`, offset: 0.65 },
        { opacity: 0, transform: `translate(${dx}px,${380}px) scaleX(-1)` }], 1500 + Math.random() * 700, Math.random() * 200, '', );
    }
  }
  function shake(px, ms) {
    if (!animOn) return;
    const kf = []; for (let i = 0; i < 10; i++) kf.push({ transform: `translate(${(Math.random() - 0.5) * px * 2 * (1 - i / 10)}px,${(Math.random() - 0.5) * px * 2 * (1 - i / 10)}px)` });
    kf.push({ transform: 'translate(0,0)' }); A(stage, kf, { duration: ms, easing: 'linear', fill: 'none' });
  }

  // ---------- the reel ----------
  const PITCH = 162, N = 60, WIN = 52, CENTER = 516;
  let plan = null;
  function buildReel(winTier, winGood) {
    let html = '';
    for (let i = 0; i < N; i++) {
      let ti, g;
      if (i === WIN) { ti = winTier; g = winGood; }
      else { ti = rollTier(); g = pick(left(ti)); }
      // the reel shows only the tier and the kind; the good itself stays hidden until it lands
      html += typeCard(g.kind, ti, `data-i="${i}" data-t="${ti}"`, `left:${i * PITCH}px`);
    }
    track.innerHTML = html;
    track.style.width = N * PITCH + 'px';
    track.classList.remove('settled');
  }
  const xFor = (i, jit = 0) => CENTER - (i * PITCH + 75 + jit);
  function spin(onDone) {
    const x0 = xFor(3), x1 = xFor(WIN, plan.jit), D = 6400 * SP(), t0 = performance.now();
    let lastIdx = -1, lastTick = 0;
    const ease = (k) => 1 - Math.pow(1 - k, 4.6);
    (function f(now) {
      const k = Math.min(1, (now - t0) / D), x = x0 + (x1 - x0) * ease(k);
      track.style.transform = `translateX(${x}px)`;
      const idx = Math.floor((CENTER - x + 6) / PITCH);
      if (idx !== lastIdx) {
        lastIdx = idx;
        const c = track.children[idx]; if (c) reel.style.setProperty('--cur', TIERS[+c.dataset.t].c);
        if (now - lastTick > 28) { sfx.tick(k > 0.8 ? 1.4 : 1); lastTick = now; }
        bob.animate([{ transform: 'rotate(-16deg) translateY(3px)' }, { transform: 'rotate(0) translateY(0)' }], { duration: 140 });
      }
      if (k < 1) raf = requestAnimationFrame(f); else onDone();
    })(t0);
  }

  // ---------- the run ----------
  function open() {
    if (phase !== 'idle') return;
    audio(); if (ac.state === 'suspended') ac.resume();
    if (coins < 2000) coins = 49905;
    // decide first
    let ti = forced >= 0 ? forced : rollTier();
    if (!left(ti).length) ti = rollTier();
    const good = pick(left(ti)) || pick(GOODS.filter((g) => g.tier === ti));
    plan = { ti, good, jit: Math.round((Math.random() - 0.5) * 120) };
    owned.add(good);
    buildReel(ti, good);

    phase = 'crate';
    bill.classList.add('gone');
    ov.classList.add('on');
    if (animOn) countPurse(coins, coins - 2000, 900); else purse.textContent = fmt(coins - 2000);
    coins -= 2000;
    if (!animOn) { ov.classList.add('instant'); return reveal(true); }

    const cx = 563, cy = 92 + 254;
    // drop, squash, settle
    A(crate, [
      { opacity: 1, transform: 'translateY(-560px) rotate(-6deg)' },
      { opacity: 1, transform: 'translateY(0) scale(1,1) rotate(0)', offset: 0.6, easing: 'ease-out' },
      { transform: 'translateY(0) scale(1.1,.86)', offset: 0.72 },
      { transform: 'translateY(-26px) scale(.96,1.05)', offset: 0.84 },
      { opacity: 1, transform: 'translateY(0) scale(1,1)' }], { duration: 760, delay: 250, easing: 'cubic-bezier(.55,0,1,.45)' });
    at(250 + 456, () => { sfx.thud(); dust(cx, cy); shake(5, 260); });
    at(1000, () => { $('#plaque').classList.add('in'); $('#odds').classList.add('in'); $('#skip').classList.add('in'); });
    // three rattles, each harder, the seal warming
    [[1250, 3], [1600, 5], [1900, 8]].forEach(([t, a], n) => at(t, () => {
      sfx.knock(n);
      A(crate, [{ transform: 'rotate(0)' }, { transform: `rotate(${-a}deg) translateY(-${a}px)` }, { transform: `rotate(${a * 0.7}deg) translateY(-${a * 0.5}px)` }, { transform: 'rotate(0)' }],
        { duration: 240, easing: 'ease-in-out', fill: 'none', composite: 'add' });
      A(crate.querySelector('.glowseal'), [{ opacity: 0.25 + n * 0.3, transform: 'scale(.8)' }, { opacity: 0.12 + n * 0.25, transform: `scale(${1 + n * 0.2})` }], { duration: 300 });
    }));
    // seal cracks, straps snap, lid off
    at(2200, () => {
      sfx.crack(); sfx.snap(0.05); sfx.snap(0.11);
      A(crate.querySelector('.glowseal'), [{ opacity: 1, transform: 'scale(1.6)' }, { opacity: 0, transform: 'scale(2.4)' }], { duration: 400 });
      A(crate.querySelector('.sl'), [{ transform: 'none' }, { transform: 'translate(-34px,-20px) rotate(-30deg)', offset: 0.3 }, { opacity: 0, transform: 'translate(-80px,170px) rotate(-120deg)' }], { duration: 900, easing: 'cubic-bezier(.3,.6,.6,1)' });
      A(crate.querySelector('.sr'), [{ transform: 'none' }, { transform: 'translate(34px,-24px) rotate(30deg)', offset: 0.3 }, { opacity: 0, transform: 'translate(90px,170px) rotate(140deg)' }], { duration: 900, easing: 'cubic-bezier(.3,.6,.6,1)' });
      A(crate.querySelector('.ribbon'), [{ transform: 'none' }, { opacity: 0, transform: 'translateY(120px) rotate(14deg)' }], { duration: 700, easing: 'ease-in' });
    });
    at(2380, () => {
      phase = 'crate';
      sfx.whoosh();
      A(crate.querySelector('.lid'), [{ transform: 'none' }, { transform: 'translate(40px,-150px) rotate(14deg) scale(1.06)', offset: 0.35 }, { opacity: 0, transform: 'translate(170px,-460px) rotate(48deg) scale(1.15)' }],
        { duration: 900, easing: 'cubic-bezier(.2,.8,.4,1)' });
      A($('#burst'), [{ opacity: 0, transform: 'scale(.3)' }, { opacity: 1, transform: 'scale(1.1)', offset: 0.2 }, { opacity: 0.45, transform: 'scale(1.4)' }], { duration: 900 });
      A($('#beam'), [{ opacity: 0, transform: 'scaleY(.2)' }, { opacity: 1, transform: 'scaleY(1)', offset: 0.25 }, { opacity: 0.55, transform: 'scaleY(1)' }], { duration: 900 });
      A($('#rays'), [{ opacity: 0 }, { opacity: 1 }], { duration: 600 });
      straw(cx, 92 + 96, 34);
      A(crate, [{ transform: 'none' }, { transform: 'translateY(8px) scale(1.03,.95)', offset: 0.3 }, { transform: 'none' }], { duration: 360, fill: 'none', composite: 'add' });
    });
    // the reel unfurls out of the light; the crate sinks away
    at(2900, () => {
      phase = 'reel'; sfx.unfurl();
      A(crate, [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'translateY(90px) scale(.82)' }], { duration: 500, easing: 'ease-in', composite: 'add' });
      A($('#beam'), [{ opacity: 0.55 }, { opacity: 0 }], { duration: 500 });
      A($('#burst'), [{ opacity: 0.45 }, { opacity: 0 }], { duration: 600 });
      A($('#rays'), [{ opacity: 1 }, { opacity: 0.35 }], { duration: 800 });
      A(reel, [{ opacity: 0, transform: 'scaleX(0) scaleY(.4)' }, { opacity: 1, transform: 'scaleX(1.03) scaleY(1)', offset: 0.7 }, { opacity: 1, transform: 'scaleX(1) scaleY(1)' }],
        { duration: 520, easing: 'cubic-bezier(.2,.9,.3,1)' });
    });
    at(3300, () => spin(() => {
      phase = 'landed';
      sfx.land();
      const w = track.querySelector(`[data-i="${WIN}"]`); w.classList.add('win');
      track.classList.add('settled');
      A(w, [{ boxShadow: `0 0 0 0 rgb(${TIERS[ti].c} / .9)` }, { boxShadow: `0 0 0 6px rgb(${TIERS[ti].c} / .9), 0 0 40px rgb(${TIERS[ti].c})` }], { duration: 300 });
      at(650, () => reveal(false));
    }));
  }

  function skip() {
    if (phase !== 'crate' && phase !== 'reel') return;
    clearTimers();
    ov.getAnimations({ subtree: true }).forEach((a) => a.cancel());
    stage.querySelectorAll('.fx').forEach((p) => p.remove());
    reveal(true);
  }

  function reveal(direct) {
    phase = 'reveal';
    const { ti, good } = plan, t = TIERS[ti], C = t.c;
    const hero = $('#hero'), spinEl = $('#spin');
    ov.style.setProperty('--tc', C);
    $('#heroFront').innerHTML = cardHTML(good, ti);
    $('#heroBack').innerHTML = typeCard(good.kind, ti);
    $('#tierName').textContent = ti === 6 ? 'CURIO · CRATE ONLY' : t.n.toUpperCase();
    $('#itemName').textContent = good.name;
    $('#itemSub').textContent = KIND[good.kind] + (ti === 6 ? ' · found only in the crate' : ' · yours to keep');
    track.style.transform = `translateX(${xFor(WIN, plan.jit)}px)`;
    track.classList.add('settled');
    const wc = track.querySelector(`[data-i="${WIN}"]`); if (wc) wc.style.visibility = 'hidden';
    // put away what came before
    ['#plaque', '#odds', '#skip'].forEach((s) => $(s).classList.remove('in'));
    crate.style.opacity = 0;
    const calm = !animOn;
    if (!calm) {
      A($('#rays'), [{ opacity: direct ? 0.35 : 0.35 }, { opacity: 0 }], { duration: 500 });
      A(reel, [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: 'translateY(60px) scale(.96)' }], { duration: 500, delay: 150, easing: 'ease-in' });
    } else { reel.style.opacity = 0; }

    // the card lifts out of the reel to the centre
    const dx = -plan.jit, dy = 322 - 210;
    if (calm) {
      hero.style.opacity = 1; hero.style.transform = 'scale(1.5)';
      [$('#halo'), $('#rays2')].forEach((e) => (e.style.opacity = 0.7));
    } else {
      A(hero, [{ opacity: 1, transform: `translate(${dx}px,${dy}px) scale(1)` }, { opacity: 1, transform: 'translate(0,-14px) scale(1.62)', offset: 0.7 }, { opacity: 1, transform: 'translate(0,0) scale(1.5)' }],
        { duration: 700, easing: 'cubic-bezier(.2,.8,.3,1)' });
      A($('#halo'), [{ opacity: 0, transform: 'scale(.4)' }, { opacity: 1, transform: 'scale(1)' }], { duration: 900, delay: 300 });
      A($('#rays2'), [{ opacity: 0 }, { opacity: ti >= 5 ? 1 : 0.4 + ti * 0.1 }], { duration: 900, delay: 300 });
    }
    // Every card lifts out showing its kind, then turns over to the good. Higher tiers wait longer and turn more.
    if (calm) { spinEl.style.transform = 'rotateY(360deg)'; sfx.reveal(ti); return afterReveal(ti, 0); }
    spinEl.style.transform = 'rotateY(180deg)';
    const hold = 760 + ti * 110, turns = ti === 6 ? 900 : ti >= 3 ? 540 : 180, dur = ti === 6 ? 1500 : ti >= 3 ? 900 : 480;
    if (ti >= 3) {
      // anticipation: the card trembles and its light swells before it turns
      A(hero, [{ transform: 'translate(0,0)' }, ...Array.from({ length: 8 }, (_, i) => ({ transform: `translate(${(i % 2 ? 1 : -1) * (1 + ti * 0.4)}px,${(i % 3) - 1}px)` })), { transform: 'translate(0,0)' }],
        { duration: hold - 700, delay: 700, easing: 'linear', fill: 'none', composite: 'add' });
      A($('#halo'), [{ opacity: 0.6, transform: 'scale(.8)' }, { opacity: 1, transform: 'scale(1.15)' }], { duration: hold - 700, delay: 700 });
    }
    A(spinEl, [{ transform: 'rotateY(180deg)' }, { transform: `rotateY(${180 + turns}deg)` }], { duration: dur, delay: hold, easing: 'cubic-bezier(.45,0,.2,1)' });
    const turnsN = Math.round(turns / 180); for (let i = 0; i < turnsN; i++) sfx.flip((hold + (i + 0.5) * (dur / turnsN)) / 1000 * SP());
    const face = hold + dur * 0.8;
    at(face, () => {
      sfx.reveal(ti);
      if (ti === 6) { flash(0.8); shake(10, 600); coinsBurst(563, 210, 46); sparks(563, 210, 70, t.c, 380); embers(t.c, 6000); return; }
      A(hero, [{ transform: 'scale(1.12)' }, { transform: 'scale(1)' }], { duration: 300, fill: 'none', composite: 'add' });
      if (ti >= 3) sparks(563, 210, 20 + ti * 12, C, 240 + ti * 30);
      if (ti >= 4) { embers(C, 5000); shake(ti >= 5 ? 9 : 5, ti >= 5 ? 600 : 380); }
      if (ti >= 5) flash(0.7);
    });
    afterReveal(ti, face);
  }
  function flash(v) { A($('#flash'), [{ opacity: v }, { opacity: 0 }], { duration: 500, easing: 'ease-out', fill: 'none' }); }
  function afterReveal(ti, d) {
    const calm = !animOn, show = (sel, delay, kf) => calm ? ($(sel).style.opacity = 1) : A($(sel), kf || [{ opacity: 0, transform: 'translateY(10px)' }, { opacity: 1, transform: 'none' }], { duration: 450, delay: d + delay });
    show('#tierName', 200, [{ opacity: 0, letterSpacing: '1.2em' }, { opacity: 1, letterSpacing: '.42em' }]);
    show('#itemName', 320);
    show('#itemSub', 450);
    // the stamp slams
    const st = $('#stamp');
    if (calm) { st.style.opacity = 0.92; st.style.transform = 'rotate(12deg) scale(1)'; }
    else {
      A(st, [{ opacity: 0, transform: 'rotate(12deg) scale(2.6)' }, { opacity: 1, transform: 'rotate(12deg) scale(.92)', offset: 0.7 }, { opacity: 0.92, transform: 'rotate(12deg) scale(1)' }],
        { duration: 260, delay: d + 650, easing: 'cubic-bezier(.6,0,.9,.4)' });
      at(d + 650 + 180, () => { sfx.stamp(); shake(3, 160); });
    }
    const after = $('#after');
    if (calm) { after.style.opacity = 1; after.classList.add('in'); }
    else { A(after, [{ opacity: 0, transform: 'translateY(12px)' }, { opacity: 1, transform: 'none' }], { duration: 400, delay: d + 950 }); at(d + 950, () => after.classList.add('in')); }
    at(d + 950, () => { phase = 'done'; $('#use').focus({ preventScroll: true }); });
    if (calm) phase = 'done';
  }

  function close(equip) {
    clearTimers();
    phase = 'closing';
    const done = () => {
      ov.getAnimations({ subtree: true }).forEach((a) => a.cancel());
      stage.querySelectorAll('.fx').forEach((p) => p.remove());
      ['#hero', '#halo', '#rays2', '#tierName', '#itemName', '#itemSub', '#after', '#stamp', '#spin'].forEach((s) => $(s).removeAttribute('style'));
      reel.removeAttribute('style'); crate.removeAttribute('style'); track.removeAttribute('style');
      $('#after').classList.remove('in'); ov.classList.remove('on', 'instant');
      bill.classList.remove('gone');
      $('#note').textContent = equip ? `Now wearing: ${plan.good.name}` : `Added to your collection: ${plan.good.name}`;
      A($('#note'), [{ opacity: 0, transform: 'translateY(8px)' }, { opacity: 1, transform: 'none', offset: 0.1 }, { opacity: 1, offset: 0.85 }, { opacity: 0 }], { duration: 3200, fill: 'none' });
      phase = 'idle';
      $('#open').focus({ preventScroll: true });
    };
    if (!animOn) return done();
    A(stage, [{ opacity: 1 }, { opacity: 0 }], { duration: 300, fill: 'none' }).onfinish = done;
    A(ov.querySelector('.dim'), [{ opacity: 1 }, { opacity: 0 }], { duration: 350 });
  }

  $('#open').onclick = open;
  $('#notnow').onclick = () => { A(bill, [{ transform: 'rotate(-.6deg)' }, { transform: 'rotate(-.6deg) translateX(-8px)' }, { transform: 'rotate(-.6deg) translateX(6px)' }, { transform: 'rotate(-.6deg)' }], { duration: 300, fill: 'none' }); };
  $('#use').onclick = (e) => { e.stopPropagation(); close(true); };
  $('#back').onclick = (e) => { e.stopPropagation(); close(false); };
  ov.addEventListener('click', skip);
  addEventListener('keydown', (e) => { if (e.key === 'Escape') { if (phase === 'done') close(false); else skip(); } });

  // ---------- fit the 1225px window to the screen ----------
  const fit = $('#fit');
  function doFit() {
    const box = $('#fitbox'), s = Math.min(1, box.clientWidth / 1225);
    fit.style.transform = s < 1 ? `scale(${s})` : '';
    box.style.height = fit.offsetHeight * s + 'px';
  }
  addEventListener('resize', doFit); doFit();

  // for the board captures
  window.CRATE_DEMO = { open, skip, close, set: (o) => { if ('forced' in o) forced = o.forced; if ('anim' in o) animOn = o.anim; if ('sound' in o) soundOn = o.sound; }, phase: () => phase, TIERS, GOODS, cardHTML, typeCard };
})();
