-- PagleArtGuide / LedgerKit.lua
-- The Ledger's widgets, one function each, as the canvas's journal.css draws them (sizes are CSS px = UI units).
-- Positions passed in are the canvas's: a text's (x, y) is the top left of its CSS line box and lh that box's
-- height, so the glyphs sit where the browser put them.

local ADDON, P = ...
local LP = "GuideParts"

P.C = { kicker = "8A5A2A", title = "3E220C", body = "3A2614", small = "5A4028", note = "7A5A30", noteLight = "8A6A40",
  hand = "23407A", red = "9A2A1A", green = "2A6A2A", brown = "7A3A10", rule = "C4A874", ghost = "B8A080", tileInk = "6A4A20" }

-- text in a CSS line box. opts as P.Txt, plus right = x is the right edge, center = x is the centre
function P.T(parent, file, size, hex, text, x, y, lh, opts)
  opts = opts or {}
  if opts.wrap and not opts.spacing and lh then opts.spacing = math.max(0, lh - size) end
  local fs = P.Txt(parent, file, size, hex, text, opts)
  local off = ((lh or size) - size) / 2
  fs:ClearAllPoints()
  if opts.right then fs:SetJustifyH("RIGHT"); fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, -(y + off))
  elseif opts.center then fs:SetJustifyH("CENTER"); fs:SetPoint("TOP", parent, "TOPLEFT", x, -(y + off))
  else fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + off)) end
  return fs
end

-- a sprite scaled so its design box is w wide (h tall, or in proportion)
function P.SpriteBox(parent, atlas, name, layer, sub, w, h)
  local t = P.Sprite(parent, atlas, name, layer, sub)
  if w then
    local kx = w / t.box[3]; local ky = h and h / t.box[4] or kx
    local tw, th = t:GetSize()
    t:SetSize(tw * kx, th * ky)
    t.box = { t.box[1] * kx, t.box[2] * ky, t.box[3] * kx, t.box[4] * ky }
  end
  return t
end

function P.Kicker(page, text, x, y, size) return P.T(page, "sc", size or 14, P.C.kicker, text, x, y, size or 14) end
function P.Title(page, text, x, y, size, opts) return P.T(page, "print", size or 29, P.C.title, text, x, y, (size or 29) * 1.05, opts) end

-- a group heading: small caps over a rule, an italic note at the right
function P.Group(page, x, y, w, title, small)
  local t = P.T(page, "sc", 15, P.C.kicker, title, x, y, 19)
  local sm
  if small then sm = P.T(page, "italic", 13, P.C.noteLight, small, x + w, y + 2, 17, { right = true }) end
  local r = P.Solid(page, P.C.rule, 1); r:SetSize(w, 1); P.At(r, page, x, y + 21)
  return t, sm
end

-- the fleuron rule: the BookAtlas fleuron between two lines that fade out toward the edges
function P.Rule(page, x, y, w)
  local cx = x + w / 2
  local fl = P.atlasTexture(page, "ARTWORK", 0, "fleuron"); fl:SetSize(14, 14); fl:SetAlpha(0.8); P.At(fl, page, cx - 7, y)
  local c0, c1 = CreateColor(0.77, 0.66, 0.45, 0), CreateColor(0.77, 0.66, 0.45, 1)
  local a = P.Solid(page, "FFFFFF", 1); a:SetSize(math.max(1, w / 2 - 17), 1); P.At(a, page, x, y + 7); a:SetGradient("HORIZONTAL", c0, c1)
  local b = P.Solid(page, "FFFFFF", 1); b:SetSize(math.max(1, w / 2 - 17), 1); P.At(b, page, cx + 17, y + 7); b:SetGradient("HORIZONTAL", c1, c0)
end

-- a round medallion: the game's icon masked round, desaturated toward sepia, in the double ink ring.
-- icon nil draws the unknown fish (one outline for every unknown, so it never hints which fish).
local RING = { [26] = "medal", [44] = "medal-44", [60] = "medal-lg" }
local UNK = { [26] = "medal-unk", [44] = "medal-unk-44", [60] = "medal-unk-lg", [88] = "medal-unk-lg" }
function P.LMedal(parent, size, icon)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  if not icon then
    local t = P.SpriteBox(f, LP, UNK[size] or "medal-unk", "ARTWORK", 0, size); P.Place(t, f, 0, 0)
    f.ring = t
    return f
  end
  local ic = P.crisp(f:CreateTexture(nil, "ARTWORK", nil, 0))
  local b = size >= 44 and 2 or 1.5
  ic:SetSize(size - 2 * b, size - 2 * b); ic:SetPoint("CENTER"); ic:SetTexture(icon)
  if ic.SetDesaturation then ic:SetDesaturation(0.6) end -- the canvas's "desaturated about 60%"
  ic:SetVertexColor(1, 0.94, 0.82)                       -- and warmed toward sepia
  local mask = f:CreateMaskTexture()
  mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(ic); ic:AddMaskTexture(mask)
  local r = P.SpriteBox(f, LP, RING[size] or "medal-lg", "ARTWORK", 1, size); P.Place(r, f, 0, 0)
  f.icon, f.ring = ic, r
  return f
end

-- a zone tile. t = { name, rank, pct, un (charted but never fished), sel, seal (Master), new ("2 new!"), onClick }
function P.Tile(parent, x, y, w, t)
  local b = CreateFrame("Button", nil, parent); b:SetSize(w, 76); P.At(b, parent, x, y)
  if t.un then
    P.DashRect(b, 0, 0, w, 76, P.C.tileInk, 0.45, "BACKGROUND")
  else
    b.bg = P.ThreeSlice(b, LP, t.sel and "tile-sel" or "tile", w, 6, "BACKGROUND"); b.bg:SetPoint("TOPLEFT")
    b.hov = P.ThreeSlice(b, LP, "tile-hover", w, 6, "BACKGROUND"); b.hov:SetPoint("TOPLEFT"); b.hov:Hide()
    b:SetScript("OnEnter", function() b.hov:Show(); b.bg:Hide() end)
    b:SetScript("OnLeave", function() b.hov:Hide(); b.bg:Show() end)
  end
  local mark = t.seal or t.new or t.ok
  b.name = P.T(b, "print", 15.5, t.un and P.C.tileInk or P.C.title, t.name, 10, 8, 16.3, { wrap = true, width = w - 20 - (mark and 30 or 0), spacing = 0.8 })
  b.rank = P.T(b, "italic", 13, t.un and P.C.noteLight or P.C.tileInk, t.rank, 10, t.un and 49 or 42, 17)
  if not t.un then
    local bar = P.ThreeSlice(b, LP, "tbar", w - 20, 3, "ARTWORK"); P.At(bar, b, 10, 62)
    b.fill = P.Solid(b, "5A3A14", 1, "ARTWORK", 1); b.fill:SetSize(math.max(0.01, (w - 22) * (t.pct or 0)), 4); P.At(b.fill, b, 11, 63)
  end
  if t.seal then
    local s = P.atlasTexture(b, "ARTWORK", 2, "seal"); s:SetSize(32, 32); s:SetPoint("CENTER", b, "TOPLEFT", w - 4 - 16, -(3 + 16)); s:SetRotation(math.rad(10))
    b.seal = s
  elseif t.ok then
    local tk = P.SpriteBox(b, LP, "tick", "ARTWORK", 0, 11); tk:SetVertexColor(CreateColorFromHexString("FF2A6A2A"):GetRGB())
    P.Place(tk, b, w - 21, 7)
    local c = P.T(b, "hand", 17, P.C.green, t.ok, w - 24, 3, 25, { right = true }); if c.SetRotation then c:SetRotation(math.rad(3)) end
  elseif t.new then
    local n = P.T(b, "hand", 18, P.C.red, t.new, w - 7, 4, 25, { right = true }); if n.SetRotation then n:SetRotation(math.rad(5)) end
  end
  if t.onClick then b:SetScript("OnClick", t.onClick) end
  return b
end

-- the ink bar: an empty case and a striped fill cut to length; fresh = the blue "Fresh Water" ahead of the fill
function P.InkBar(parent, x, y, w, pct, fresh)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(w, 12); P.At(f, parent, x, y)
  local e = P.ThreeSlice(f, LP, "ink-empty", w, 7, "ARTWORK"); e:SetPoint("TOPLEFT")
  local fill = P.Crop(f, LP, "ink-full", 1, "ARTWORK", 1); P.At(fill, f, 0, -1)
  local fr = P.Solid(f, "23407A", 0.58, "ARTWORK", 2); fr:SetHeight(9)
  local edge = P.Solid(f, "23407A", 1, "ARTWORK", 3); edge:SetSize(1, 9)
  function f.Set(p, fw)
    local inner = w - 3
    local fx = 1.5 + inner * math.max(0, math.min(1, p))
    P.SetCropW(fill, LP, "ink-full", fx)
    local fwid = inner * (fw or 0)
    fr:SetShown(fwid > 0.5); edge:SetShown(fwid > 0.5)
    fr:SetWidth(math.max(0.01, math.min(fwid, w - 1.5 - fx))); P.At(fr, f, fx, 1.5); P.At(edge, f, fx, 1.5)
    f.pct, f.fresh = p, fw
  end
  f.Set(pct, fresh)
  return f
end

-- an inked stamp (Caught, In its element, Regular, Whopper, Any weight, Half the weights, The heaviest),
-- red when earned and ghost ink when not. Placed by its visible box.
local function slug(s) return (s:lower():gsub("[^a-z0-9]+", "-"):gsub("^-", ""):gsub("-$", "")) end
P.slug = slug
function P.Stamp(parent, word, on, x, y)
  local t = P.Sprite(parent, LP, "stamp-" .. slug(word) .. (on and "" or "-off"), "ARTWORK")
  P.Place(t, parent, x, y)
  return t
end

-- stars are a texture (the client's fonts have no star). n of `of`, size = the glyph's font size
function P.Stars(parent, n, of, x, y, size)
  size = size or 12
  local k, step = size / 13, 12.5 * size / 12
  local out = {}
  for i = 1, of or 3 do
    local s = P.SpriteBox(parent, LP, i <= n and "star" or "star-off", "ARTWORK", 0)
    s:SetSize(s:GetWidth() * k, s:GetHeight() * k)
    P.At(s, parent, x + (i - 1) * step + 0.5, y + 2.5 * k)
    out[i] = s
  end
  return out
end

-- the rank ladder: Visitor · Regular · Local · Expert · Master. Ranks reached are inked, the shown rank circled.
P.RANKS = { "Visitor", "Regular", "Local", "Expert", "Master" }
function P.Ladder(parent, x, y, cur)
  local cx = x
  local out = {}
  for i, r in ipairs(P.RANKS) do
    if i > 1 then
      local d = P.T(parent, "sc", 15, P.C.rule, "·", cx + 6, y + 2, 19); cx = cx + 6 + 3.4 + 6
    end
    if i == cur then
      local ring = P.Sprite(parent, LP, "rank-" .. slug(r), "ARTWORK"); P.Place(ring, parent, cx, y)
      local t = P.T(parent, "sc", 15, P.C.red, r, cx + ring.box[3] / 2, y + 2, 19, { center = true })
      out[i] = { text = t, ring = ring, x = cx }
      cx = cx + ring.box[3]
    else
      local t = P.T(parent, "sc", 15, i < cur and P.C.title or P.C.ghost, r, cx, y + 2, 19)
      out[i] = { text = t, x = cx }
      cx = cx + t:GetStringWidth()
    end
  end
  return out
end

-- a list row (fish, families, Legends): r = { icon / unk, name, em, mg, mgHex, stars, of, right, sel, onClick, h }
function P.Row(parent, x, y, w, r)
  local h = r.h or 32
  local b = CreateFrame("Button", nil, parent); b:SetSize(w, h); P.At(b, parent, x, y)
  b.selBg = P.Solid(b, "784614", 0.13, "BACKGROUND", 1); b.selBg:SetAllPoints()
  b.dash = CreateFrame("Frame", nil, b); b.dash:SetAllPoints(); P.DashRect(b.dash, 0, 0, w, h, P.C.kicker, 1)
  b.hov = P.Solid(b, "784614", 0.08, "BACKGROUND", 0); b.hov:SetAllPoints(); b.hov:Hide()
  function b.SetSel(on) b.selBg:SetShown(on); b.dash:SetShown(on) end
  b.SetSel(r.sel)
  b:SetScript("OnEnter", function() b.hov:Show() end)
  b:SetScript("OnLeave", function() b.hov:Hide() end)
  local tx = 5
  if r.icon ~= false then
    local m = P.LMedal(b, 26, r.icon); P.At(m, b, 5, (h - 26) / 2); b.medal = m
    tx = 40
  end
  local right = w - 5
  if r.right then b.right = P.T(b, "print", 13.5, P.C.small, r.right, w - 5, (h - 18.2) / 2, 18.2, { right = true }); right = w - 5 - 40 - 9 end
  if r.stars then b.stars = P.Stars(b, r.stars, r.of or 3, right - 37.6, (h - 16) / 2, 12); right = right - 37.6 - 9 end
  if r.mg then
    b.mg = P.T(b, "hand", 17, r.mgHex or "7A5A30", r.mg, right, (h - 22) / 2, 22, { right = true })
    if b.mg.SetRotation then b.mg:SetRotation(math.rad(2)) end
  end
  local unk = r.unk
  b.name = P.T(b, unk and "italic" or "print", 15, unk and P.C.noteLight or P.C.body, r.name, tx, (h - 19) / 2, 19)
  if r.em then
    local e = P.T(b, "italic", 13, P.C.noteLight, r.em, 0, (h - 17) / 2 + 1, 17); e:ClearAllPoints(); e:SetPoint("LEFT", b.name, "RIGHT", 4, -1)
  end
  if r.onClick then b:SetScript("OnClick", r.onClick) end
  return b
end

-- a page button. look: nil (leather), "light", "off". h: 34 (the canvas's 30 + its borders), or as asked
function P.LButton(parent, text, x, y, w, look, h, onClick)
  h = h or 34
  local b = CreateFrame("Button", nil, parent)
  local light = look == "light"
  local fs = P.Txt(b, "gilt", 15, light and P.C.body or "F4DFA8", text, { shadow = not light, justify = "CENTER" })
  w = w or math.ceil(fs:GetStringWidth()) + 36
  b:SetSize(w, h); P.At(b, parent, x, y)
  local name = look == "light" and "button-light" or (look == "off" and "button-off" or "button")
  b.bg = P.ThreeSlice(b, LP, name, w, 10, "BACKGROUND"); b.bg:SetPoint("TOPLEFT")
  if h ~= 34 then for _, t in ipairs({ b.bg.Left, b.bg.Middle, b.bg.Right }) do t:SetHeight(t:GetHeight() * h / 34) end end
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  if look ~= "off" then
    b.hov = P.ThreeSlice(b, LP, light and "button-light" or "button-hover", w, 10, "BACKGROUND"); b.hov:SetPoint("TOPLEFT"); b.hov:Hide()
    if light then for _, t in ipairs({ b.hov.Left, b.hov.Middle, b.hov.Right }) do t:SetVertexColor(1.08, 1.08, 1.08) end end
    b:SetScript("OnEnter", function() b.hov:Show(); b.bg:Hide() end)
    b:SetScript("OnLeave", function() b.hov:Hide(); b.bg:Show() end)
    b:SetScript("OnClick", function() P.Sound("click"); if onClick then onClick() end end)
  end
  b.label = fs
  return b
end

-- checks and radios (textures, 13 and 10 units)
function P.Check(parent, on, x, y, size)
  local t = P.SpriteBox(parent, LP, on and "check-on" or "check-off", "ARTWORK", 0, size or 14); P.Place(t, parent, x, y); return t
end
function P.Radio(parent, on, x, y)
  local t = P.Sprite(parent, LP, on and "radio-on" or "radio-off", "ARTWORK"); P.Place(t, parent, x, y); return t
end

-- a Prestige emblem: the gilt shield with its rank in small caps
function P.Emblem(parent, numeral, x, y, w)
  w = w or 34
  local t = P.SpriteBox(parent, LP, "emblem", "ARTWORK", 0, w); P.Place(t, parent, x, y)
  local k = w / 34
  local fs = P.Txt(parent, "sc", 15 * k, "2A1A04", numeral, { justify = "CENTER" }); fs:SetPoint("CENTER", t, "CENTER", 0, 1 * k)
  return t, fs
end

-- a crest: the Prestige frames (none, i ... x, master) hold the portrait; "legend" holds its fish already
function P.Crest(parent, key, x, y, w)
  local f = CreateFrame("Frame", nil, parent)
  if key == "legend" then
    local h = w * 220 / 200
    f:SetSize(w, h); P.At(f, parent, x, y)
    local t = P.SpriteBox(f, "Crests", "crest-legend", "ARTWORK", 1, w, h); P.Place(t, f, 0, 0); f.frame = t
    return f
  end
  local h = w * 230 / 200
  f:SetSize(w, h); P.At(f, parent, x, y)
  -- the portrait over the frame's dark well (as the canvas stacks them): the silhouette here; in game
  -- SetPortraitTexture(unit) masked round
  local pw = w * 0.58
  local t = P.SpriteBox(f, "Crests", "crest-" .. key, "ARTWORK", 0, w, h); P.Place(t, f, 0, 0)
  local p = P.SpriteBox(f, "Crests", "crest-portrait", "ARTWORK", 1, pw); P.Place(p, f, w * 0.21, h * 0.1826)
  f.frame, f.portrait = t, p
  return f
end

-- the contents line: numeral, title, dotted leader, value
function P.TocRow(page, x, y, w, num, label, val, onClick)
  local b = CreateFrame("Button", nil, page); b:SetSize(w, 26); P.At(b, page, x, y - 3)
  P.T(b, "sc", 14, P.C.kicker, num, 0, 4, 18)
  local l = P.T(b, "print", 16, P.C.body, label, 28, 3, 20)
  local v = P.T(b, "print", 16, P.C.small, val, w, 3, 20, { right = true })
  local x0, x1 = 28 + l:GetStringWidth() + 6, w - v:GetStringWidth() - 6
  P.Dots(b, x0, 15, x1 - x0, P.C.noteLight, 1)
  b:SetScript("OnEnter", function() l:SetTextColor(CreateColorFromHexString("FF7A2A14"):GetRGB()) end)
  b:SetScript("OnLeave", function() l:SetTextColor(CreateColorFromHexString("FF3A2614"):GetRGB()) end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- a note to self: the blue pencil, then the line in the Angler's hand. Returns its height.
function P.NoteLine(page, x, y, w, text, onClick)
  local b = CreateFrame("Button", nil, page); P.At(b, page, x, y)
  local pen = P.Sprite(b, LP, "pen", "ARTWORK"); P.Place(pen, b, 0, 5)
  local t = P.T(b, "hand", 21, P.C.hand, text, 24, 0, 23.1, { wrap = true, width = w - 24 })
  local h = math.max(23, t:GetStringHeight() + 2)
  b:SetSize(w, h)
  b:SetScript("OnEnter", function() t:SetTextColor(CreateColorFromHexString("FF9A2A1A"):GetRGB()) end)
  b:SetScript("OnLeave", function() t:SetTextColor(CreateColorFromHexString("FF23407A"):GetRGB()) end)
  if onClick then b:SetScript("OnClick", onClick) end
  b.text = t
  return b, h
end

-- "« back", bottom left of a left page
function P.Back(page, onClick)
  local b = CreateFrame("Button", nil, page); b:SetSize(48, 24); P.At(b, page, 30, 508)
  local t = P.T(b, "hand", 19, P.C.brown, "« back", 0, 0, 24)
  b:SetScript("OnEnter", function() t:SetTextColor(CreateColorFromHexString("FF9A2A1A"):GetRGB()) end)
  b:SetScript("OnLeave", function() t:SetTextColor(CreateColorFromHexString("FF7A3A10"):GetRGB()) end)
  b:SetScript("OnClick", onClick)
  return b
end

-- a scrolling list: a clipped area whose content the mouse wheel moves (26 units a notch, 0.12 s), with the
-- ink scrollbar in the margin. Returns the content frame (draw into it at list coordinates).
function P.ScrollList(page, x, y, w, h, contentH, barX)
  local clip = CreateFrame("Frame", nil, page); clip:SetSize(w, h); P.At(clip, page, x, y); clip:SetClipsChildren(true)
  local c = CreateFrame("Frame", nil, clip); c:SetSize(w, contentH); P.At(c, clip, 0, 0)
  local rail = P.Solid(page, "6A4A20", 0.15); rail:SetSize(4, h); P.At(rail, page, barX, y)
  local th = math.max(20, h * math.min(1, h / contentH))
  local thumb = P.Solid(page, "8A5A2A", 1); thumb:SetSize(4, th); P.At(thumb, page, barX, y)
  rail:SetShown(contentH > h); thumb:SetShown(contentH > h)
  c.off = 0
  local function place(o)
    c.off = o; P.At(c, clip, 0, -o)
    P.At(thumb, page, barX, y + (contentH > h and o / (contentH - h) * (h - th) or 0))
  end
  clip:EnableMouseWheel(true)
  clip:SetScript("OnMouseWheel", function(_, d)
    local to = math.max(0, math.min(contentH - h, c.off - d * 26))
    P.StopMotion(c)
    P.Animate(c, { { dur = 0.12, ease = P.Ease.out, keys = { { 0, { c.off } }, { 1, { to } } }, apply = function(v) place(v[1]) end } })
  end)
  c.clip = clip
  return c
end
