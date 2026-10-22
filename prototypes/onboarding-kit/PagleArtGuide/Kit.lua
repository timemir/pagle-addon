-- PagleArtGuide / Kit.lua (the same core as the other art probes, plus an ad-hoc font helper)
-- Helpers over the generated atlases (Atlases/*.lua). A sprite is rendered from the canvas with a margin
-- for its shadow or glow; `box` is where the designed element sits inside it, so code positions the box,
-- not the sprite, and every size below is the canvas's CSS px = UI units.

local ADDON, P = ...


local function crisp(t)
  if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
  if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
  return t
end
P.crisp = crisp

local function spriteOf(atlasName, name)
  local A = P.Atlases[atlasName]
  local s = A and A.sprites[name]
  if not s then error(("Pagle art: no sprite %s in %s"):format(tostring(name), tostring(atlasName))) end
  return A, s
end

-- Texture showing a whole sprite at its designed size. t.box = { x, y, w, h } in UI units.
function P.Sprite(parent, atlasName, name, layer, sub)
  local A, s = spriteOf(atlasName, name)
  local t = crisp(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
  t:SetTexture(A.file)
  t:SetTexCoord(s.x / A.width, (s.x + s.w) / A.width, s.y / A.height, (s.y + s.h) / A.height)
  t:SetSize(s.w / A.scale, s.h / A.scale)
  t.box = s.box
  return t
end

-- Anchor a sprite so its design box's top left lands at (x, y) from `rel`'s top left (y grows downward).
function P.Place(t, rel, x, y)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", rel, "TOPLEFT", x - t.box[1], -(y - t.box[2]))
end

-- Centre a sprite's design box on `rel`'s centre, offset by (dx, dy) (dy grows downward).
function P.Center(t, rel, dx, dy)
  local b = t.box
  local w, h = t:GetSize()
  local ox = (b[1] + b[3] / 2) - w / 2
  local oy = (b[2] + b[4] / 2) - h / 2
  t:ClearAllPoints()
  t:SetPoint("CENTER", rel, "CENTER", (dx or 0) - ox, -((dy or 0) - oy))
end

-- Three-slice a sprite horizontally: the end caps keep their size (cap = UI units of design box kept at
-- each end, plus the margin), the middle stretches. Returns a frame of the requested design width.
function P.ThreeSlice(parent, atlasName, name, width, cap, layer)
  local A, s = spriteOf(atlasName, name)
  local sc = A.scale
  local bx, by, bw, bh = s.box[1], s.box[2], s.box[3], s.box[4]
  local f = CreateFrame("Frame", nil, parent)
  f:SetFrameLevel(parent:GetFrameLevel()) -- sit level with the parent so its own text draws over the slices
  f:SetSize(width, bh)
  local mL, mR = bx, s.w / sc - bx - bw
  local Lw, Rw = mL + cap, cap + mR -- UI units taken from each end of the sprite
  local function piece(u0, uw)
    local t = crisp(f:CreateTexture(nil, layer or "BACKGROUND"))
    t:SetTexture(A.file)
    local x0 = s.x + u0 * sc
    t:SetTexCoord(x0 / A.width, (x0 + uw * sc) / A.width, s.y / A.height, (s.y + s.h) / A.height)
    t:SetHeight(s.h / sc)
    return t
  end
  local l = piece(0, Lw); l:SetWidth(Lw)
  local r = piece(s.w / sc - Rw, Rw); r:SetWidth(Rw)
  local m = piece(Lw, s.w / sc - Lw - Rw)
  l:SetPoint("TOPLEFT", f, "TOPLEFT", -mL, by)
  r:SetPoint("TOPRIGHT", f, "TOPRIGHT", mR, by)
  m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
  f.Left, f.Middle, f.Right = l, m, r
  return f
end


-- Text with an ad-hoc font: file is "print", "italic", "gilt", "hand", "handSemi" or "handBold".
local DIR = [[Interface\AddOns\]] .. ADDON .. [[\Fonts\]]
local FILES = { print = DIR .. "IMFeENrm28P.ttf", italic = DIR .. "IMFeENit28P.ttf", sc = DIR .. "IMFeENsc28P.ttf", gilt = DIR .. "Marcellus-Regular.ttf",
  hand = DIR .. "Caveat-Medium.ttf", handSemi = DIR .. "Caveat-SemiBold.ttf", handBold = DIR .. "Caveat-Bold.ttf" }
local cache, n = {}, 0
function P.Font(file, size, hex, shadow)
  local key = table.concat({ file, size, hex, shadow and 1 or 0 }, ":")
  local f = cache[key]
  if f then return f end
  n = n + 1
  f = CreateFont("PagleArtGuideAdHoc" .. n)
  if f:SetFont(FILES[file], size, "") == false then f:SetFont((GameFontNormal:GetFont()), size, "") end
  local c = CreateColorFromHexString("FF" .. hex)
  f:SetTextColor(c:GetRGB())
  if shadow then f:SetShadowColor(0, 0, 0, 0.95); f:SetShadowOffset(0, -1) else f:SetShadowOffset(0, 0) end
  f:SetJustifyH("LEFT")
  cache[key] = f
  return f
end
function P.Txt(parent, file, size, hex, text, opts)
  opts = opts or {}
  local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
  fs:SetFontObject(P.Font(file, size, hex, opts.shadow))
  fs:SetText(text or "")
  fs:SetWordWrap(opts.wrap and true or false)
  if opts.width then fs:SetWidth(opts.width) end
  -- wrapped lines: the canvas's line heights (Caveat ~1.1, IM Fell ~1.35)
  if opts.wrap then fs:SetSpacing(opts.spacing or (file:sub(1, 4) == "hand" and 2 or math.floor(size * 0.33 + 0.5))) end
  if opts.justify then fs:SetJustifyH(opts.justify) end
  return fs
end
-- place a region's top left at (x, y) from rel's top left, y down
function P.At(region, rel, x, y) region:ClearAllPoints(); region:SetPoint("TOPLEFT", rel, "TOPLEFT", x, -y) return region end
function P.Solid(parent, hex, a, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  local c = CreateColorFromHexString("FF" .. hex)
  t:SetColorTexture(c.r, c.g, c.b, a or 1)
  return t
end
-- the first `w` units of a sprite, unstretched (bars and ink fills are cut to length, not squeezed)
function P.Crop(parent, atlasName, name, w, layer, sub)
  local A = P.Atlases[atlasName]; local s = A.sprites[name]
  local t = crisp(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
  t:SetTexture(A.file)
  local x0 = s.x + s.box[1] * A.scale
  t:SetTexCoord(x0 / A.width, (x0 + w * A.scale) / A.width, s.y / A.height, (s.y + s.h) / A.height)
  t:SetSize(w, s.h / A.scale)
  t.box = { 0, s.box[2], w, s.box[4] }
  return t
end
-- the top `h` units of a sprite (tracker frames grow downward)
function P.CropH(parent, atlasName, name, h, layer, sub)
  local A = P.Atlases[atlasName]; local s = A.sprites[name]
  local t = crisp(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
  t:SetTexture(A.file)
  local hh = math.min(s.h / A.scale, s.box[2] + h)
  t:SetTexCoord(s.x / A.width, (s.x + s.w) / A.width, s.y / A.height, (s.y + hh * A.scale) / A.height)
  t:SetSize(s.w / A.scale, hh)
  t.box = s.box
  return t
end
-- the item's icon, round, in a ring sprite
function P.Medal(parent, size, ringName, icon, ringSize)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  local ic = crisp(f:CreateTexture(nil, "ARTWORK", nil, 0)); ic:SetSize(size - 2, size - 2); ic:SetPoint("CENTER")
  ic:SetTexture(icon or [[Interface\Icons\INV_Misc_Fish_02]])
  local mask = f:CreateMaskTexture()
  mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(ic); ic:AddMaskTexture(mask)
  if ringName then
    local r = P.Sprite(f, "BookParts", ringName, "ARTWORK", 1)
    if ringSize and ringSize ~= r.box[3] then
      local k = ringSize / r.box[3]; r:SetSize(r:GetWidth() * k, r:GetHeight() * k); r.box = { r.box[1] * k, r.box[2] * k, ringSize, ringSize }
    end
    P.Center(r, f)
  end
  f.Icon = ic
  return f
end

-- a 1-unit dashed outline (the canvas's `outline: 1px dashed`), drawn as short solid dashes
function P.DashRect(parent, x, y, w, h, hex, a, layer)
  local c = CreateColorFromHexString("FF" .. hex)
  local function dash(dx, dy, dw, dh)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, 2)
    t:SetColorTexture(c.r, c.g, c.b, a or 1)
    t:SetSize(dw, dh); P.At(t, parent, dx, dy)
  end
  local D, G = 3, 2
  for i = 0, w - 1, D + G do dash(x + i, y, math.min(D, w - i), 1); dash(x + i, y + h - 1, math.min(D, w - i), 1) end
  for i = 0, h - 1, D + G do dash(x, y + i, 1, math.min(D, h - i)); dash(x + w - 1, y + i, 1, math.min(D, h - i)) end
end

-- a timeline bar of any width: the sprite's left part cut to length plus its own right end, so both ends stay square-on
function P.Bar(parent, kind, w, layer)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(w, 12)
  local name = "bar-" .. kind
  if w <= 8 then
    local t = P.Crop(f, "BookParts", name, w, layer); t:SetPoint("TOPLEFT")
    return f
  end
  local A = P.Atlases.BookParts; local s = A.sprites[name]
  local l = P.Crop(f, "BookParts", name, w - 4, layer); l:SetPoint("TOPLEFT")
  local r = crisp(f:CreateTexture(nil, layer or "ARTWORK"))
  r:SetTexture(A.file)
  local x1 = s.x + s.w
  r:SetTexCoord((x1 - 4 * A.scale) / A.width, x1 / A.width, s.y / A.height, (s.y + s.h) / A.height)
  r:SetSize(4, s.h / A.scale); r:SetPoint("TOPRIGHT")
  return f
end

-- vertical three-slice of a frame sprite: top and bottom caps keep their size, the middle stretches
-- period: repeat the middle in steps of `period` units instead of stretching it (ruled paper keeps its line pitch)
function P.VSlice(parent, atlasName, name, height, capT, capB, layer, period)
  local A, s = spriteOf(atlasName, name)
  local sc = A.scale
  local bx, by, bw, bh = s.box[1], s.box[2], s.box[3], s.box[4]
  local f = CreateFrame("Frame", nil, parent)
  f:SetFrameLevel(parent:GetFrameLevel())
  f:SetSize(bw, height)
  local mT, mB = by, s.h / sc - by - bh
  local Th, Bh = mT + capT, capB + mB
  local function piece(v0, vh)
    local t = crisp(f:CreateTexture(nil, layer or "BACKGROUND"))
    t:SetTexture(A.file)
    local y0 = s.y + v0 * sc
    t:SetTexCoord(s.x / A.width, (s.x + s.w) / A.width, y0 / A.height, (y0 + vh * sc) / A.height)
    t:SetWidth(s.w / sc)
    return t
  end
  local top = piece(0, Th); top:SetHeight(Th)
  local bot = piece(s.h / sc - Bh, Bh); bot:SetHeight(Bh)
  top:SetPoint("TOPLEFT", f, "TOPLEFT", -bx, mT)
  bot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -bx, -mB)
  if not period then
    local mid = piece(Th, s.h / sc - Th - Bh)
    mid:SetPoint("TOPLEFT", top, "BOTTOMLEFT"); mid:SetPoint("BOTTOMRIGHT", bot, "TOPRIGHT")
    return f
  end
  local need, y = height - capT - capB, 0
  while need - y > 0.01 do
    local h = math.min(period, need - y)
    local m = piece(Th, h); m:SetHeight(h)
    m:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -y)
    y = y + h
  end
  return f
end

-- a round dot (the group and tracker bullets): a solid colour through the round portrait mask
function P.Dot(parent, size, hex, layer)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  local edge = P.Solid(f, "281405", 0.55, layer or "ARTWORK", 0); edge:SetAllPoints()
  local t = P.Solid(f, hex, 1, layer or "ARTWORK", 1); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1)
  for _, tex in ipairs({ edge, t }) do
    local m = f:CreateMaskTexture()
    m:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(tex); tex:AddMaskTexture(m)
  end
  return f
end

-- small capitals: the client has none, so they are set in capitals a size down
function P.Caps(s) return (s:upper()) end

-- a dotted leader or underline: 1-unit dots every `step` units (the canvas's `1px dotted`)
function P.Dots(parent, x, y, w, hex, a, step)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(math.max(1, w), 1); P.At(f, parent, x, y)
  step = step or 3
  for i = 0, math.floor((w - 1) / step) do
    local d = P.Solid(f, hex, a or 1); d:SetSize(1, 1); P.At(d, f, i * step, 0)
  end
  return f
end

-- a 1-unit outline (the canvas's `border: 1px solid`)
function P.Outline(parent, x, y, w, h, hex, a, layer, t)
  t = t or 1
  local out = {}
  for i, r in ipairs({ { x, y, w, t }, { x, y + h - t, w, t }, { x, y, t, h }, { x + w - t, y, t, h } }) do
    local s = P.Solid(parent, hex, a, layer); s:SetSize(r[3], r[4]); P.At(s, parent, r[1], r[2]); out[i] = s
  end
  return out
end

-- re-cut a P.Crop texture to a new length (an ink fill running on)
function P.SetCropW(t, atlasName, name, w)
  local A = P.Atlases[atlasName]; local s = A.sprites[name]
  if w < 0.5 then t:Hide(); return end
  t:Show()
  local x0 = s.x + s.box[1] * A.scale
  t:SetTexCoord(x0 / A.width, (x0 + w * A.scale) / A.width, s.y / A.height, (s.y + s.h) / A.height)
  t:SetWidth(w)
end

-- a timeline bar that can change length (the live timeline): left part cut to length, plus its own right end
function P.LiveBar(parent, kind, layer)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(1, 12)
  local A = P.Atlases.BookParts; local s = A.sprites["bar-" .. kind]
  local hpx = s.h / A.scale
  local l = crisp(f:CreateTexture(nil, layer or "ARTWORK")); l:SetTexture(A.file)
  local r = crisp(f:CreateTexture(nil, layer or "ARTWORK")); r:SetTexture(A.file)
  l:SetPoint("TOPLEFT", f, "TOPLEFT"); r:SetPoint("TOPRIGHT", f, "TOPRIGHT")
  local x0, x1 = s.x + s.box[1] * A.scale, s.x + s.w
  function f.SetBar(_, x, w)
    if w < 0.5 then f:Hide(); return end
    f:Show(); f:SetWidth(w); P.At(f, parent, x, f.y or 0)
    local e = math.min(4, w / 2)
    l:SetTexCoord(x0 / A.width, (x0 + (w - e) * A.scale) / A.width, s.y / A.height, (s.y + s.h) / A.height); l:SetSize(w - e, hpx)
    r:SetTexCoord((x1 - e * A.scale) / A.width, x1 / A.width, s.y / A.height, (s.y + s.h) / A.height); r:SetSize(e, hpx)
  end
  return f
end
