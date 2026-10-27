// The Curio crate, drawn: a fisherman's tackle crate, front on with its lid's top showing, brass corners, two leather
// straps, rope handles and a wax seal across the lid's seam. Parts are separate so they can fly apart.
window.CRATE = (() => {
  const W = 320, H = 268;
  const wood = (id, a, b, c) => `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset=".55" stop-color="${b}"/><stop offset="1" stop-color="${c}"/></linearGradient>`;
  const defs = `<defs>
    ${wood('pl', '#a8703a', '#7a4a20', '#55300f')}
    ${wood('pl2', '#9a6432', '#6e421b', '#4a2a0c')}
    ${wood('lidtop', '#c08848', '#9a6434', '#7a4a20')}
    <linearGradient id="br" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff0b8"/><stop offset=".4" stop-color="#d8a84a"/><stop offset="1" stop-color="#7a5218"/></linearGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#3a1e0c"/><stop offset=".5" stop-color="#6a3a1a"/><stop offset="1" stop-color="#3a1e0c"/></linearGradient>
    <radialGradient id="wax" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#ff8a6e"/><stop offset=".45" stop-color="#c8301c"/><stop offset="1" stop-color="#6a0e06"/></radialGradient>
    <filter id="grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.012 0.35" numOctaves="3" seed="4"/>
      <feColorMatrix values="0 0 0 0 .2  0 0 0 0 .1  0 0 0 0 .03  0 0 0 .55 -.12"/><feComposite in2="SourceGraphic" operator="in"/></filter>
    <filter id="ds" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="10" stdDeviation="9" flood-color="#000" flood-opacity=".6"/></filter>
  </defs>`;

  const plank = (x, y, w, h, g) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="url(#${g})"/>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#000" filter="url(#grain)"/>
    <path d="M${x} ${y + .8} H${x + w}" stroke="#e8b878" stroke-width="1" opacity=".35"/>
    <path d="M${x} ${y + h - .8} H${x + w}" stroke="#1a0c02" stroke-width="1.6" opacity=".7"/>`;
  const rivet = (x, y, r = 3) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#6a4a14"/><circle cx="${x - .7}" cy="${y - .7}" r="${r * .55}" fill="#fff0c0"/>`;
  const corner = (x, y, sx, sy) => `<g transform="translate(${x} ${y}) scale(${sx} ${sy})">
    <path d="M0 0 H34 V11 H11 V34 H0Z" fill="url(#br)" stroke="#4a3008" stroke-width="1.2"/>${rivet(6, 6)}${rivet(25, 6, 2.4)}${rivet(6, 25, 2.4)}</g>`;
  const handle = (x, flip) => `<path d="M${x} 150 q${flip * 30} 6 ${flip * 30} 34 q0 28 ${-flip * 30} 34" fill="none" stroke="#5a3a14" stroke-width="9" stroke-linecap="round"/>
    <path d="M${x} 150 q${flip * 30} 6 ${flip * 30} 34 q0 28 ${-flip * 30} 34" fill="none" stroke="#d8b878" stroke-width="5.5" stroke-dasharray="3 3" stroke-linecap="round"/>`;
  const strap = (x) => `<rect x="${x}" y="70" width="26" height="182" fill="url(#st)"/><path d="M${x + 3} 70 V252 M${x + 23} 70 V252" stroke="#d8a868" stroke-width=".8" stroke-dasharray="3 3" opacity=".7"/>
    <rect x="${x - 3}" y="198" width="32" height="22" rx="3" fill="none" stroke="url(#br)" stroke-width="4"/><path d="M${x + 13} 198 V220" stroke="url(#br)" stroke-width="3"/>`;

  // the box: three planks behind brass, straps, handles, the stencil
  const body = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" overflow="visible">${defs}
    <g filter="url(#ds)">
      ${handle(22, -1)}${handle(298, 1)}
      <rect x="20" y="96" width="280" height="160" rx="4" fill="#2a1406"/>
      ${plank(22, 98, 276, 52, 'pl')}${plank(22, 151, 276, 52, 'pl2')}${plank(22, 204, 276, 50, 'pl')}
      <path d="M22 151 H298 M22 204 H298" stroke="#140802" stroke-width="2.4"/>
      <g opacity=".78" fill="#1e0e04">
        <text x="160" y="183" text-anchor="middle" font-family="Marcellus, serif" font-size="34" letter-spacing="7">CURIO</text>
        <path d="M128 216 c8 -9 22 -10 30 -3 l8 -6 v18 l-8 -6 c-8 7 -22 6 -30 -3z"/>
        <text x="160" y="241" text-anchor="middle" font-family="Marcellus, serif" font-size="11" letter-spacing="4">PAGLE · FRAGILE</text>
      </g>
      ${strap(70)}${strap(224)}
      ${corner(20, 96, 1, 1)}${corner(300, 96, -1, 1)}${corner(20, 256, 1, -1)}${corner(300, 256, -1, -1)}
    </g></svg>`;

  // the lid: its top face in perspective and its front edge, with the straps over it
  const lid = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" overflow="visible">${defs}
    <g filter="url(#ds)">
      <path d="M44 34 H276 L306 70 H14Z" fill="url(#lidtop)"/>
      <path d="M44 34 H276 L306 70 H14Z" fill="#000" filter="url(#grain)"/>
      <path d="M90 34 L76 70 M160 34 V70 M230 34 L244 70" stroke="#3a1e08" stroke-width="2" opacity=".75"/>
      <path d="M44 34 H276" stroke="#f0c888" stroke-width="1.2" opacity=".6"/>
      ${plank(12, 70, 296, 30, 'pl')}
      <path d="M12 100 H308" stroke="#140802" stroke-width="2.6"/>
      <path d="M74 36 L70 70 H96 L96 36Z M228 36 L224 70 H250 L252 36Z" fill="url(#st)" opacity=".95"/>
      <rect x="70" y="70" width="26" height="30" fill="url(#st)"/><rect x="224" y="70" width="26" height="30" fill="url(#st)"/>
      ${corner(12, 70, 1, 1)}${corner(308, 70, -1, 1)}
    </g></svg>`;

  // the wax seal across the seam, in two halves that crack apart
  const sealHalf = (side) => {
    const clip = side < 0 ? 'M0 0 H34 L30 18 L36 30 L31 44 L34 70 H0Z' : 'M70 0 H34 L30 18 L36 30 L31 44 L34 70 H70Z';
    return `<svg viewBox="0 0 70 70" width="70" height="70" overflow="visible"><defs>
      <radialGradient id="wax" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#ff8a6e"/><stop offset=".45" stop-color="#c8301c"/><stop offset="1" stop-color="#6a0e06"/></radialGradient>
      <clipPath id="c${side}"><path d="${clip}"/></clipPath></defs>
      <g clip-path="url(#c${side})">
        <path d="M35 4 C48 2 64 12 66 28 C69 44 60 64 40 66 C22 69 6 58 4 40 C2 22 18 5 35 4Z" fill="url(#wax)" stroke="#5a0a04" stroke-width="1"/>
        <circle cx="35" cy="35" r="20" fill="none" stroke="#7a1208" stroke-width="2.4" opacity=".7"/>
        <path d="M22 35 c6 -7 16 -8 22 -2 l6 -5 v14 l-6 -5 c-6 6 -16 5 -22 -2z" fill="#7a1208" opacity=".85"/>
        <ellipse cx="27" cy="20" rx="9" ry="5" fill="#ffb8a0" opacity=".35"/>
      </g>
      <path d="${side < 0 ? 'M34 0 L30 18 L36 30 L31 44 L34 70' : 'M34 0 L30 18 L36 30 L31 44 L34 70'}" fill="none" stroke="#2a0402" stroke-width="1.4" class="crack"/>
    </svg>`;
  };
  const ribbon = `<svg viewBox="0 0 70 60" width="70" height="60"><path d="M24 0 L16 54 L26 46 L32 58 L34 0Z" fill="#a8241a" stroke="#5a0a04" stroke-width=".6"/>
    <path d="M36 0 L40 56 L48 46 L58 52 L46 0Z" fill="#c8302a" stroke="#5a0a04" stroke-width=".6"/></svg>`;
  return { W, H, body, lid, sealL: sealHalf(-1), sealR: sealHalf(1), ribbon };
})();
