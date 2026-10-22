-- PagleArtGuide / GuideKit.lua
-- The guide's widgets, one function each, as guide.css draws them (sizes are CSS px = UI units). Positions are
-- the canvas's: a text's (x, y) is the top left of its CSS line box (P.T, LedgerKit.lua).

local ADDON, P = ...
local GP = "GuideParts"
local C = P.C
C.gilt, C.giltOn, C.wax, C.hand, C.note = "EFD286", "FFF0BC", "F4DFA8", "23407A", "7A5A30"

local function hexc(h) return CreateColorFromHexString("FF" .. h) end

-- ---------------------------------------------------------------- nine-slice
-- A sprite cut into nine: corners keep their size (cap units of the design box plus the margin), edges and
-- centre stretch. Returns a frame whose size is the design box; the margin (shadow) hangs outside it.
function P.Nine(parent, name, w, h, cap, layer, atlas)
  local A = P.Atlases[atlas or GP]; local s = A.sprites[name]
  local sc = A.scale
  local bx, by, bw, bh = s.box[1], s.box[2], s.box[3], s.box[4]
  local mL, mT, mR, mB = bx, by, s.w / sc - bx - bw, s.h / sc - by - bh
  local cx, cy = type(cap) == "table" and cap[1] or cap, type(cap) == "table" and cap[2] or cap
  local f = CreateFrame("Frame", nil, parent)
  f:SetFrameLevel(parent:GetFrameLevel())
  f:SetSize(w, h)
  local Lw, Rw, Th, Bh = mL + cx, cx + mR, mT + cy, cy + mB  -- UI units taken from each edge of the sprite
  local SW, SH = s.w / sc, s.h / sc
  local cols = { { 0, Lw }, { Lw, SW - Lw - Rw }, { SW - Rw, Rw } }
  local rows = { { 0, Th }, { Th, SH - Th - Bh }, { SH - Bh, Bh } }
  local outW = { Lw, w + mL + mR - Lw - Rw, Rw }
  local outH = { Th, h + mT + mB - Th - Bh, Bh }
  local y = -(-mT)
  local yy = mT
  for r = 1, 3 do
    local xx = -mL
    for c = 1, 3 do
      local t = P.crisp(f:CreateTexture(nil, layer or "BACKGROUND"))
      t:SetTexture(A.file)
      local u0, uw, v0, vh = cols[c][1], cols[c][2], rows[r][1], rows[r][2]
      t:SetTexCoord((s.x + u0 * sc) / A.width, (s.x + (u0 + uw) * sc) / A.width, (s.y + v0 * sc) / A.height, (s.y + (v0 + vh) * sc) / A.height)
      t:SetSize(math.max(0.01, outW[c]), math.max(0.01, outH[r]))
      t:SetPoint("TOPLEFT", f, "TOPLEFT", xx, yy)
      xx = xx + outW[c]
    end
    yy = yy - outH[r]
  end
  return f
end

-- red words inside a hand-written line: *word* in the source becomes the red pencil
function P.Red(text) return (text:gsub("%*(.-)%*", "|cff9a2a1a%1|r")) end

-- ---------------------------------------------------------------- margin notes
-- A slip of paper with the Angler's pencil: w wide, its height from the text. n: the red-pencil number (or nil).
-- Returns the frame (its top left at x, y of rel) and its height.
function P.Note(rel, text, x, y, w, n, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, rel)
  f:SetFrameLevel(rel:GetFrameLevel() + (opts.level or 20))
  local t = P.Txt(f, "hand", 19, C.hand, P.Red(text), { wrap = true, width = w - 28, spacing = 2.3 })
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -10)
  local h = math.floor(t:GetStringHeight() + 21 + 0.5)
  f:SetSize(w, h); P.At(f, rel, x, y)
  local paper = P.Nine(f, "note", w, h, 6, "BACKGROUND"); paper:SetPoint("TOPLEFT")
  if n then
    local b = P.Sprite(f, GP, "note-badge", "OVERLAY", 1); P.Place(b, f, -12, -12)
    local d = P.Txt(f, "handBold", 17, "9A2A1A", tostring(n), { layer = "OVERLAY", justify = "CENTER" })
    d:SetPoint("CENTER", f, "TOPLEFT", 1, -1); d:SetDrawLayer("OVERLAY", 3)
  end
  if opts.dim then f:SetAlpha(0.45) end
  f.text, f.h = t, h
  return f, h
end

-- A pencil arrow from (x0, y0) to (x1, y1) of rel, bowed by `bend` (fraction of its length, + to the left of
-- travel), with a two-stroke head and a red ring at the target. Drawn with Lines (14 segments).
function P.Arrow(rel, x0, y0, x1, y1, bend, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, rel)
  f:SetAllPoints(rel); f:SetFrameLevel(rel:GetFrameLevel() + (opts.level or 19))
  local mx, my = (x0 + x1) / 2, (y0 + y1) / 2
  local dx, dy = x1 - x0, y1 - y0
  bend = bend or 0.2
  local cx, cy = mx - dy * bend, my + dx * bend
  local function at(s) local u = 1 - s; return u * u * x0 + 2 * u * s * cx + s * s * x1, u * u * y0 + 2 * u * s * cy + s * s * y1 end
  local col = hexc("23407A")
  f.lines = {}
  local function line(ax, ay, bx, by)
    local l = f:CreateLine(nil, "OVERLAY")
    l:SetThickness(2)
    l:SetColorTexture(col.r, col.g, col.b, 0.92)
    l:SetStartPoint("TOPLEFT", rel, ax, -ay); l:SetEndPoint("TOPLEFT", rel, bx, -by)
    f.lines[#f.lines + 1] = l
    return l
  end
  local N = 14
  local px, py = x0, y0
  for i = 1, N do local qx, qy = at(i / N); line(px, py, qx, qy); px, py = qx, qy end
  -- the head: along the tangent at the end
  local ux, uy = x1 - cx, y1 - cy; local ul = math.sqrt(ux * ux + uy * uy); ux, uy = ux / ul, uy / ul
  for _, a in ipairs({ 0.5, -0.5 }) do
    local c, s = math.cos(a), math.sin(a)
    line(x1 - 9 * (ux * c - uy * s), y1 - 9 * (ux * s + uy * c), x1, y1)
  end
  if opts.ring ~= false then
    local r = P.Sprite(f, GP, "ring", "OVERLAY", 2); P.Place(r, rel, x1 - 6, y1 - 6); f.ring = r
  end
  return f
end

-- A note that points: the note at (x, y, w), its arrow from the edge nearest the target (tx, ty).
function P.Pointed(rel, text, x, y, w, n, tx, ty, opts)
  local note, h = P.Note(rel, text, x, y, w, n, opts)
  local sx, sy
  local side = opts and opts.side
  if side == "top" then sx, sy = x + w / 2, y
  elseif side == "bottom" then sx, sy = x + w / 2, y + h
  elseif tx < x then sx, sy = x, y + math.min(h - 10, 30)
  elseif tx > x + w then sx, sy = x + w, y + math.min(h - 10, 30)
  else sx, sy = x + w / 2, (ty < y) and y or y + h end
  local arrow = P.Arrow(rel, sx, sy, tx, ty, (n or 1) % 2 == 1 and 0.2 or -0.2, opts)
  note.arrow = arrow
  return note, arrow
end

-- ---------------------------------------------------------------- small pieces
-- a key cap with its key; big = 40 tall
function P.KeyCap(rel, key, x, y, big)
  local fs = P.Txt(rel, "gilt", big and 20 or 14, "2A1A04", key, { layer = "OVERLAY", justify = "CENTER" })
  local w = big and math.max(44, math.ceil(fs:GetStringWidth()) + 20) or math.max(24, math.ceil(fs:GetStringWidth()) + 12)
  local f = P.ThreeSlice(rel, GP, big and "key-big" or "key", w, big and 8 or 6, "ARTWORK")
  f:SetFrameLevel(rel:GetFrameLevel() + 2)
  P.At(f, rel, x, y)
  fs:SetParent(f); fs:ClearAllPoints(); fs:SetPoint("CENTER", f, "CENTER", 0, big and 1 or 0.5)
  f.w = w
  return f
end

-- the dashed cap waiting for a key (listen = the red outline while listening)
function P.WaitCap(rel, text, x, y, listen)
  local t = P.Sprite(rel, GP, listen and "key-listen" or "key-wait", "ARTWORK", 1); P.Place(t, rel, x, y)
  local fs = P.T(rel, "italic", 14, "8A6A40", text, x + 64, y + 11, 18, { center = true })
  return t, fs
end

-- a choice card (g-opt): radio, title, line, an optional pencilled tag. Returns the button.
function P.Choice(rel, x, y, w, h, title, line, on, tag, onClick)
  local b = CreateFrame("Button", nil, rel); b:SetSize(w, h); P.At(b, rel, x, y)
  b.rest = P.Nine(b, "opt", w, h, 6); b.rest:SetPoint("TOPLEFT")
  b.hover = P.Nine(b, "opt-hover", w, h, 6); b.hover:SetPoint("TOPLEFT"); b.hover:Hide()
  b.on = P.Nine(b, "opt-on", w, h, 6); b.on:SetPoint("TOPLEFT")
  b.radio = P.Sprite(b, GP, "radio", "ARTWORK"); P.Place(b.radio, b, 13, 15)
  b.radioOn = P.Sprite(b, GP, "radio-on", "ARTWORK", 1); P.Place(b.radioOn, b, 13, 15)
  P.T(b, "print", 17, C.title, title, 37, 11, 19.55)
  if line then P.T(b, "italic", 13.5, "6A4A28", line, 37, 32.5, 18.2, { wrap = true, width = w - 49 - (tag and 40 or 0) }) end
  if tag then P.T(b, "hand", 16, C.green, tag, w - 9, 5.7, 22.5, { right = true }) end
  function b.SetOn(_, v) b.isOn = v; b.on:SetShown(v); b.radioOn:SetShown(v); b.rest:SetShown(not v) end
  b:SetOn(on)
  b:SetScript("OnEnter", function() if not b.isOn then b.hover:Show(); b.rest:Hide() end end)
  b:SetScript("OnLeave", function() b.hover:Hide(); if not b.isOn then b.rest:Show() end end)
  b:SetScript("OnClick", function() P.Sound("click"); if onClick then onClick(b) end end)
  return b
end

-- a group of choice cards: picking one clears the others
function P.ChoiceGroup(cards, onPick)
  for _, c in ipairs(cards) do
    c:SetScript("OnClick", function()
      P.Sound("check")
      for _, o in ipairs(cards) do o:SetOn(o == c) end
      c.hover:Hide()
      if onPick then onPick(c) end
    end)
  end
end

-- the next-action button: bezel, icon round inside, the key cap over its top left, the label slip under it
function P.NAB(rel, x, y, icon, label, key, off)
  local f = CreateFrame("Frame", nil, rel); f:SetSize(52, 52); P.At(f, rel, x, y)
  f:SetFrameLevel(rel:GetFrameLevel() + 3)
  local bz = P.Sprite(f, GP, "nab", "ARTWORK", 0); P.Place(bz, f, 0, 0)
  local ic = P.crisp(f:CreateTexture(nil, "ARTWORK", nil, 1)); ic:SetSize(36, 36); ic:SetPoint("CENTER")
  ic:SetTexture(icon)
  local m = f:CreateMaskTexture()
  m:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(ic); ic:AddMaskTexture(m)
  if off then ic:SetDesaturated(true); bz:SetVertexColor(0.55, 0.55, 0.55); ic:SetVertexColor(0.7, 0.7, 0.7) end
  if key then P.KeyCap(f, key, -8, -8) end
  if label then
    local fs = P.Txt(f, "hand", 15, C.body, label, { layer = "OVERLAY", justify = "CENTER" })
    local w = math.ceil(fs:GetStringWidth()) + 20
    local s = P.ThreeSlice(f, GP, "nab-lab", w, 6, "ARTWORK"); s:SetFrameLevel(f:GetFrameLevel() + 1)
    s:SetPoint("TOP", f, "BOTTOM", 0, -10)
    fs:SetParent(s); fs:ClearAllPoints(); fs:SetPoint("CENTER", s, "CENTER", 0, 0)
  end
  f.icon = ic
  return f
end

-- the lacquer box (a Nudge, a tooltip): dark, a gilt hairline; text inside
function P.Lacquer(rel, x, y, w, h)
  local f = CreateFrame("Frame", nil, rel); f:SetSize(w, h); P.At(f, rel, x, y)
  f:SetFrameLevel(rel:GetFrameLevel() + 3)
  local bg = P.Nine(f, "lacquer", w, h, 6); bg:SetPoint("TOPLEFT")
  return f
end

-- a sample cut from another kit (Samples atlas), scaled into w x h, in the sample frame when framed
function P.Sample(rel, name, x, y, w, h, framed)
  local A = P.Atlases.Samples; local s = A.sprites[name]
  local f = CreateFrame("Frame", nil, rel); f:SetSize(w, h); P.At(f, rel, x, y)
  f:SetFrameLevel(rel:GetFrameLevel() + 1)
  local t = P.crisp(f:CreateTexture(nil, "ARTWORK"))
  t:SetTexture(A.file)
  t:SetTexCoord(s.x / A.width, (s.x + s.w) / A.width, s.y / A.height, (s.y + s.h) / A.height)
  t:SetAllPoints()
  if framed then local fr = P.Nine(f, "win", w, h, 6, "OVERLAY"); fr:SetPoint("TOPLEFT") end
  f.tex = t
  return f
end
-- part of a sample: (sx, sy, sw, sh) in the sample's own units, drawn at w x h
function P.SampleCut(rel, name, sx, sy, sw, sh, x, y, w, h, framed)
  local f = P.Sample(rel, name, x, y, w, h, framed)
  local A = P.Atlases.Samples; local s = A.sprites[name]
  f.tex:SetTexCoord((s.x + sx) / A.width, (s.x + sx + sw) / A.width, (s.y + sy) / A.height, (s.y + sy + sh) / A.height)
  return f
end

-- the foot of a right page: the skip link and the leather button
function P.Foot(page, skip, nextText, onSkip, onNext, nextW)
  local s = CreateFrame("Button", nil, page)
  local fs = P.T(s, "italic", 14, C.note, skip, 0, 0, 19)
  s:SetSize(math.ceil(fs:GetStringWidth()), 19); P.At(s, page, 30, 497.5)
  P.Dots(s, 0, 18, math.ceil(fs:GetStringWidth()), C.note, 0.6, 2)
  s:SetScript("OnEnter", function() fs:SetTextColor(hexc("9A2A1A"):GetRGB()) end)
  s:SetScript("OnLeave", function() fs:SetTextColor(hexc(C.note):GetRGB()) end)
  s:SetScript("OnClick", function() P.Sound("click"); if onSkip then onSkip() end end)
  local w = nextW or 77
  local b = nextText and P.LButton(page, nextText, 412 - w, 490, w, nil, 34, onNext)
  return s, b
end

-- a checkbox with a title and a line (the Casting page's)
function P.CheckRow(rel, x, y, on, title, line)
  local t = P.Sprite(rel, GP, on and "check" or "check-off", "ARTWORK"); P.Place(t, rel, x, y + 2)
  P.T(rel, "print", 15.5, C.title, title, x + 25, y, 18.6)
  if line then P.T(rel, "italic", 13, "6A4A28", line, x + 25, y + 18.6, 16.9) end
  return t
end

-- the leather coach bar: label | n notes, shown once | Got it, put the notes away
function P.CoachBar(rel, label, n, onGot)
  local f = CreateFrame("Frame", nil, rel); f:SetFrameLevel(rel:GetFrameLevel() + 30)
  local a = P.Txt(f, "gilt", 14, "E8C96A", label, { shadow = true })
  local b = P.Txt(f, "gilt", 14, "C9B27A", n .. " notes, shown once", { shadow = true })
  local got = CreateFrame("Button", nil, f)
  local c = P.Txt(got, "italic", 14, "E8D6A8", "Got it, put the notes away", { shadow = true })
  local wa, wb, wc = math.ceil(a:GetStringWidth()), math.ceil(b:GetStringWidth()), math.ceil(c:GetStringWidth())
  local w = 16 + wa + 16 + 1 + 16 + wb + 16 + 1 + 16 + wc + 16
  f:SetSize(w, 40)
  local bg = P.ThreeSlice(f, GP, "coachbar", w, 12, "BACKGROUND"); bg:SetPoint("TOPLEFT")
  a:SetPoint("LEFT", f, "LEFT", 16, 0)
  local s1 = P.Solid(f, "E8C96A", 0.35, "ARTWORK"); s1:SetSize(1, 18); s1:SetPoint("LEFT", f, "LEFT", 16 + wa + 16, 0)
  b:SetPoint("LEFT", s1, "RIGHT", 16, 0)
  local s2 = P.Solid(f, "E8C96A", 0.35, "ARTWORK"); s2:SetSize(1, 18); s2:SetPoint("LEFT", b, "RIGHT", 16, 0)
  got:SetSize(wc, 20); got:SetPoint("LEFT", s2, "RIGHT", 16, 0); c:SetPoint("LEFT", got, "LEFT")
  got:SetScript("OnEnter", function() c:SetTextColor(hexc("FFF4C8"):GetRGB()) end)
  got:SetScript("OnLeave", function() c:SetTextColor(hexc("E8D6A8"):GetRGB()) end)
  got:SetScript("OnClick", function() P.Sound("click"); if onGot then onGot() end end)
  return f
end

-- ---------------------------------------------------------------- the First evening list (tracker)
P.EVENING = {
  { id = "cast", t = "Make a Cast", hint = "press your Fishing key, or double right-click" },
  { id = "catch", t = "Land a Catch and see its Nod" },
  { id = "journal", t = "Open the Fish Journal", hint = "Pagle menu by the minimap › Fish Journal" },
  { id = "hunts", t = "See what’s biting on Hunts", hint = "Pagle menu › Hunts" },
  { id = "session", t = "Finish a Session", hint = "step away 5 minutes for your summary" },
  { id = "shop", t = "Peek into the Curio Shop", hint = "Pagle menu › Curio Shop" },
}

-- items: list as P.EVENING; done: set of ids; opts.hints: "now" (only the next one's, the default), "all", or a set
-- of ids; opts.now = false draws no next line (the guide's preview)
function P.Tracker(rel, x, y, items, done, opts)
  opts = opts or {}
  local hints = opts.hints or "now"
  local w = opts.w or 274
  local f = CreateFrame("Frame", nil, rel); f:SetFrameLevel(rel:GetFrameLevel() + 2); P.At(f, rel, x, y)
  f.rows = {}
  local function draw()
    for _, r in ipairs(f.rows) do r:Hide() end
    local n = 0; for _, it in ipairs(items) do if done[it.id] then n = n + 1 end end
    local nowId; if opts.now ~= false then for _, it in ipairs(items) do if not done[it.id] then nowId = it.id break end end end
    local yy = 8 + 22
    local list = CreateFrame("Frame", nil, f); list:SetAllPoints(); f.rows[#f.rows + 1] = list
    f.head = f.head or P.T(f, "sc", 15, C.title, "First evening", 24, 8, 20)
    if f.count then f.count:SetText(n .. " of " .. #items) else f.count = P.T(f, "italic", 12.5, "8A5A2A", n .. " of " .. #items, w - 8, 10, 17, { right = true }) end
    for _, it in ipairs(items) do
      local isDone, isNow = done[it.id], it.id == nowId
      local hint = (hints == "all" or (hints == "now" and isNow) or (type(hints) == "table" and hints[it.id])) and it.hint
      local rowH = hint and 34.6 or 17.6 + 4
      if isNow then
        local wash = P.Solid(list, "3DA03D", 1, "BACKGROUND", 2); wash:SetSize(w - 24 + 8 - 6, rowH); P.At(wash, list, 18, yy)
        wash:SetGradient("HORIZONTAL", CreateColor(0.24, 0.63, 0.24, 0.28), CreateColor(0.24, 0.63, 0.24, 0))
      end
      local box = P.Sprite(list, GP, isDone and "li-done" or "li-box", "ARTWORK", 1); P.Place(box, list, 24, yy + 4)
      local col = isDone and "6A5A48" or (isNow and "1E5A1E" or "2E1C0C")
      local t = P.T(list, "print", 13.5, col, it.t, 43, yy + 2, 17.6)
      if isDone then local st = P.Solid(list, "2A6A2A", 0.6, "OVERLAY"); st:SetSize(math.ceil(t:GetStringWidth()), 1); P.At(st, list, 43, yy + 11) end
      if hint then P.T(list, "italic", 12.5, "5A4028", hint, 43, yy + 19.6, 16.3) end
      yy = yy + rowH
      it.y = yy
    end
    local h = yy + 12
    if f.paper then f.paper:Hide() end
    f.paper = P.VSlice(f, GP, "trk", h, 8, 8, "BACKGROUND", 20); f.paper:SetPoint("TOPLEFT")
    f:SetSize(w, h)
  end
  f.Redraw = draw
  draw()
  return f
end

-- ---------------------------------------------------------------- step ribbons (ONB-R24)
-- Under the book's bottom edge: done, current (longer), to come (dimmed). Returns { Set(cur, visited) }.
function P.StepRibbons(book, steps, onPick)
  local R = { items = {} }
  for i, s in ipairs(steps) do
    local b = CreateFrame("Button", nil, book)
    b:SetFrameLevel(book:GetFrameLevel() + 1) -- under the band (+6): the top 14 units hide beneath the book's edge
    b:SetSize(98, 110)
    b:SetPoint("TOPLEFT", book, "TOPLEFT", 40 + (i - 1) * 106, -586)
    b.plain = P.Sprite(b, GP, "rib", "ARTWORK", 0); P.Place(b.plain, b, 0, 0)
    b.done = P.Sprite(b, GP, "rib-done", "ARTWORK", 0); P.Place(b.done, b, 0, 0)
    b.on = P.Sprite(b, GP, "rib-on", "ARTWORK", 0); P.Place(b.on, b, 0, 0)
    b.label = P.Txt(b, "gilt", 12, C.gilt, s.ribbon, { shadow = true, wrap = true, width = 82, justify = "CENTER", spacing = 1.8 })
    b.label:SetPoint("BOTTOM", b, "TOPLEFT", 49, -(92 - 28))
    b:SetScript("OnClick", function() if onPick then onPick(i) end end)
    b:SetScript("OnEnter", function() b.hover = true; if not b.isOn then b.plain:SetVertexColor(1.15, 1.15, 1.15); b.done:SetVertexColor(1.12, 1.12, 1.12) end end)
    b:SetScript("OnLeave", function() b.hover = false; b.plain:SetVertexColor(1, 1, 1); b.done:SetVertexColor(1, 1, 1) end)
    R.items[i] = b
  end
  -- the hanging length of each: 92, the current 110 (its label 18 lower, as the canvas's flex end puts it)
  local function place(b, len)
    b.len = len
    local cut = 110 - len
    for _, t in ipairs({ b.plain, b.done, b.on }) do t:ClearAllPoints(); t:SetPoint("TOPLEFT", b, "TOPLEFT", -t.box[1], t.box[2] + (t == b.on and cut or 0)) end
    b.label:ClearAllPoints(); b.label:SetPoint("BOTTOM", b, "TOPLEFT", 49, -(len - 28))
  end
  function R.Set(cur, visited, animate)
    for i, b in ipairs(R.items) do
      local on = (i == cur)
      b.isOn = on
      b.plain:SetShown(not on and not visited[i]); b.done:SetShown(not on and visited[i]); b.on:SetShown(on)
      b.label:SetTextColor(hexc(on and C.giltOn or C.gilt):GetRGB())
      local to = on and 110 or 92
      if animate and P.motion and b.len and b.len ~= to then
        local from = b.len
        P.Animate(b, { { dur = 0.2, ease = P.Ease.out, keys = { { 0, { from } }, { 1, { to } } }, apply = function(v) place(b, v[1]) end } })
      else place(b, to) end
      -- the to-come ones are drawn at 82% brightness by the sprite itself (rib); the label follows
      b.label:SetAlpha((on or visited[i]) and 1 or 0.85)
    end
  end
  return R
end
