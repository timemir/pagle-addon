-- PagleArtGuide / (forked from PagleArtBook) Book.lua
-- PagleGuideBookMixin: the book language as a frame. Leather binding (tiled grain under a rounded 9-slice band),
-- two parchment pages with spine shading, a gilt strip with breadcrumbs and search, ribbons, a brass
-- nameplate and a round wax close button. Also the wax seal widget.
-- Texture art is authored at 2 texels per UI unit (art/book/generate.py); sizes below are UI units.

local ADDON, P = ...
local A = P.BookAtlas
local TEX = [[Interface\AddOns\PagleArtGuide\Textures\]]
local LEATHER = TEX .. "Leather"
local PARCHMENT = TEX .. "Parchment"

local BAND = 16        -- binding band shown size (32 texels)
local FILL_INSET = 7   -- the tiled leather starts under the band's opaque lines
local STRIP_H = 38     -- gilt strip above the pages
local PAD_X, PAD_B = 18, 16
local LEATHER_TILE = 128 -- Leather.tga is 256 texels = 128 units

local C = P.Colors

-- ---------------------------------------------------------------- helpers
local function crisp(tex)
  -- Stretched art: no pixel snapping, or it shimmers when the frame moves.
  if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
  if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
  return tex
end

-- Texcoords for a texel rectangle inside a sprite. sx/sy/sw/sh are relative to the sprite's origin.
local function atlasCoords(name, sx, sy, sw, sh)
  local s = A.sprites[name]
  sx, sy = sx or 0, sy or 0
  sw, sh = sw or s.w, sh or s.h
  local x0, y0 = s.x + sx, s.y + sy
  return x0 / A.width, (x0 + sw) / A.width, y0 / A.height, (y0 + sh) / A.height
end
P.atlasCoords = atlasCoords

local function atlasTexture(parent, layer, sub, name, sx, sy, sw, sh)
  local t = crisp(parent:CreateTexture(nil, layer, nil, sub or 0))
  t:SetTexture(A.file)
  t:SetTexCoord(atlasCoords(name, sx, sy, sw, sh))
  return t
end
P.atlasTexture = atlasTexture

-- ---------------------------------------------------------------- the binding
local function buildBinding(f)
  -- tiled grain, darkened toward leather-dark by vertex colour and the vignette
  local fill = crisp(f:CreateTexture(nil, "BACKGROUND", nil, 0))
  fill:SetTexture(LEATHER, "REPEAT", "REPEAT")
  fill:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
  fill:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
  fill:SetGradient("VERTICAL", CreateColor(0.80, 0.80, 0.80, 1), CreateColor(1, 1, 1, 1)) -- (min = bottom, max = top)
  f.LeatherFill = fill

  local vig = atlasTexture(f, "BACKGROUND", 1, "vignette", 1, 1, 126, 126)
  vig:SetAllPoints(fill)
  f.LeatherVignette = vig

  -- 9-slice band from the 96x96 "binding" sprite: 32-texel corners, edges stretched from a 2-texel slice.
  -- The band lives on its own child frame, above the ribbons, so a ribbon's tucked end hides under it.
  local bf = CreateFrame("Frame", nil, f)
  bf:SetAllPoints()
  bf:SetFrameLevel(f:GetFrameLevel() + 6)
  f.BandFrame = bf
  local pieces = {
    TL = { 0, 0 }, T = { 32, 0 }, TR = { 64, 0 },
    L = { 0, 32 },                R = { 64, 32 },
    BL = { 0, 64 }, B = { 32, 64 }, BR = { 64, 64 },
  }
  local band = {}
  for key, o in pairs(pieces) do
    local t = atlasTexture(bf, "BORDER", 0, "binding", o[1], o[2], 32, 32)
    band[key] = t
  end
  for _, k in ipairs({ "TL", "TR", "BL", "BR" }) do band[k]:SetSize(BAND, BAND) end
  band.TL:SetPoint("TOPLEFT")
  band.TR:SetPoint("TOPRIGHT")
  band.BL:SetPoint("BOTTOMLEFT")
  band.BR:SetPoint("BOTTOMRIGHT")
  band.T:SetPoint("TOPLEFT", band.TL, "TOPRIGHT"); band.T:SetPoint("BOTTOMRIGHT", band.TR, "BOTTOMLEFT")
  band.B:SetPoint("TOPLEFT", band.BL, "TOPRIGHT"); band.B:SetPoint("BOTTOMRIGHT", band.BR, "BOTTOMLEFT")
  band.L:SetPoint("TOPLEFT", band.TL, "BOTTOMLEFT"); band.L:SetPoint("BOTTOMRIGHT", band.BL, "TOPRIGHT")
  band.R:SetPoint("TOPLEFT", band.TR, "BOTTOMLEFT"); band.R:SetPoint("BOTTOMRIGHT", band.BR, "TOPRIGHT")
  -- edges stretch along their length: the band is constant along an edge, so stretching costs nothing
  band.T:SetTexCoord(atlasCoords("binding", 47, 0, 2, 32))
  band.B:SetTexCoord(atlasCoords("binding", 47, 64, 2, 32))
  band.L:SetTexCoord(atlasCoords("binding", 0, 47, 32, 2))
  band.R:SetTexCoord(atlasCoords("binding", 64, 47, 32, 2))
  f.Band = band
end

-- ---------------------------------------------------------------- pages
local function buildPage(f, side)
  local page = CreateFrame("Frame", nil, f.Pages)
  page:EnableMouse(true) -- dragging the parchment doesn't move the book; the leather does
  local bg = crisp(page:CreateTexture(nil, "BACKGROUND"))
  bg:SetTexture(PARCHMENT)
  bg:SetAllPoints()
  if side == "right" then bg:SetTexCoord(1, 0, 0, 1) end -- mirror, so the two pages don't match exactly
  page.Parchment = bg

  local g = atlasTexture(page, "BORDER", 0, "gutter", 1, 1, 62, 6)
  g:SetWidth(40)
  if side == "left" then
    g:SetPoint("TOPRIGHT"); g:SetPoint("BOTTOMRIGHT")
  else
    local l, r, t, b = atlasCoords("gutter", 1, 1, 62, 6)
    g:SetTexCoord(r, l, t, b)
    g:SetPoint("TOPLEFT"); g:SetPoint("BOTTOMLEFT")
  end
  page.Gutter = g
  return page
end

-- ---------------------------------------------------------------- strip: crumbs and search
local function buildStrip(f)
  local strip = CreateFrame("Frame", nil, f)
  strip:SetPoint("TOPLEFT", PAD_X + 6, 0)
  strip:SetPoint("TOPRIGHT", -PAD_X - 6, 0)
  strip:SetHeight(STRIP_H)
  f.Strip = strip
  f.crumbs = {}

  local search = CreateFrame("EditBox", nil, strip)
  search:SetSize(250, 22)
  search:SetPoint("RIGHT")
  search:SetAutoFocus(false)
  search:SetFontObject(P.Fonts.Field)
  search:SetTextInsets(8, 8, 0, 0)
  local sbg = search:CreateTexture(nil, "BACKGROUND", nil, 1)
  sbg:SetColorTexture(C["parchment-field"]:GetRGBA())
  sbg:SetPoint("TOPLEFT", 1, -1); sbg:SetPoint("BOTTOMRIGHT", -1, 1)
  local sbd = search:CreateTexture(nil, "BACKGROUND", nil, 0)
  sbd:SetColorTexture(C["leather-trim"]:GetRGBA())
  sbd:SetAllPoints()
  local ph = search:CreateFontString(nil, "ARTWORK")
  ph:SetFontObject(P.Fonts.FieldPlaceholder)
  ph:SetPoint("LEFT", 8, 0)
  search.Placeholder = ph
  search:SetScript("OnEscapePressed", search.ClearFocus)
  search:SetScript("OnEnterPressed", search.ClearFocus)
  search:SetScript("OnTextChanged", function(self)
    ph:SetShown(self:GetText() == "")
    if f.onSearch then f.onSearch(self:GetText()) end
  end)
  f.Search = search
end

-- ---------------------------------------------------------------- ribbons
local RIBBON_W, RIBBON_TUCK, RIBBON_CAP = 24, 6, 8

local function ribbonTint(kind, selected)
  if kind == "here" then
    return selected and C["ribbon-here-on"] or C["ribbon-here"]
  end
  return selected and C["wax"] or C["ribbon"]
end

local function newRibbon(f, label, kind, onClick)
  local b = CreateFrame("Button", nil, f)
  b:SetFrameLevel(f:GetFrameLevel() + 1) -- below BandFrame: the tucked end hides beneath the band
  b.kind = kind
  local function slice(sy, sh)
    return atlasTexture(b, "ARTWORK", 0, "ribbon", 0, sy, 48, sh)
  end
  b.Top, b.Mid, b.Bot = slice(0, 16), slice(16, 32), slice(48, 16)
  b.Top:SetPoint("TOPLEFT"); b.Top:SetPoint("TOPRIGHT"); b.Top:SetHeight(RIBBON_CAP)
  b.Bot:SetPoint("BOTTOMLEFT"); b.Bot:SetPoint("BOTTOMRIGHT"); b.Bot:SetHeight(RIBBON_CAP)
  b.Mid:SetPoint("TOPLEFT", b.Top, "BOTTOMLEFT"); b.Mid:SetPoint("BOTTOMRIGHT", b.Bot, "TOPRIGHT")
  b.Mid:SetTexCoord(atlasCoords("ribbon", 0, 31, 48, 2))

  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(P.Fonts.Ribbon)
  fs:SetText(label)
  local tw = fs:GetStringWidth()
  if fs.SetRotation then
    fs:SetRotation(-math.pi / 2)  -- reads top to bottom, like the prototype's vertical-rl
    fs:SetPoint("CENTER", RIBBON_TUCK / 2, 0)
  else
    fs:SetText(label:gsub("(.)", "%1\n"))  -- fallback: stacked letters
    fs:SetPoint("CENTER", RIBBON_TUCK / 2, 0)
    tw = fs:GetStringHeight()
  end
  b.Label = fs
  b:SetSize(RIBBON_W + RIBBON_TUCK, math.max(56, tw + 26))
  b:SetScript("OnClick", function() f:SetRibbonSelected(b); if onClick then onClick(b) end end)
  return b
end

-- ---------------------------------------------------------------- mixin
PagleGuideBookMixin = {}

function PagleGuideBookMixin:OnLoad()
  self:SetClampedToScreen(true)
  self:SetMovable(true)
  self:EnableMouse(true)
  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart", self.StartMoving)
  self:SetScript("OnDragStop", self.StopMovingOrSizing)
  self.leftWeight = 1

  buildBinding(self)
  buildStrip(self)

  self.Pages = CreateFrame("Frame", nil, self)
  self.Pages:SetPoint("TOPLEFT", PAD_X, -STRIP_H)
  self.Pages:SetPoint("BOTTOMRIGHT", -PAD_X, PAD_B)
  self.LeftPage = buildPage(self, "left")
  self.RightPage = buildPage(self, "right")

  local close = CreateFrame("Button", nil, self, "PagleGuideWaxCloseButtonTemplate")
  close:SetPoint("CENTER", self, "TOPRIGHT", -3, -3)
  close:SetScript("OnClick", function() if P.CloseBook then P.CloseBook(self) else self:Hide() end end)
  self.CloseButton = close

  self.Nameplate = CreateFrame("Frame", nil, self, "PagleGuideBrassPlateTemplate")
  self.Nameplate:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -12, -14)
  self.Nameplate:SetFrameLevel(self:GetFrameLevel() + 10)
  close:SetFrameLevel(self:GetFrameLevel() + 10)
  self.Nameplate:Hide()

  self.ribbons = {}
  self:SetBookSize(920, 600)
end

function PagleGuideBookMixin:OnSizeChanged(w, h)
  -- tile the grain at its authored density: 128 units per repeat
  if self.flatCover then self.LeatherFill:SetTexCoord(0, 1, 0, 1) -- a cover drawn to the book's size (Covers.lua)
  else local tile = self.tileSize or LEATHER_TILE; self.LeatherFill:SetTexCoord(0, (w - 2 * FILL_INSET) / tile, 0, (h - 2 * FILL_INSET) / tile) end
  self:LayoutPages()
end

function PagleGuideBookMixin:SetBookSize(w, h)
  self:SetSize(w, h)
  self:OnSizeChanged(w, h)
end

-- Left page width : right page width. Hunts uses 1.45.
function PagleGuideBookMixin:SetLeftPageWeight(weight)
  self.leftWeight = weight or 1
  self:LayoutPages()
end

function PagleGuideBookMixin:LayoutPages()
  local w = self.Pages:GetWidth()
  if not w or w <= 0 then w = self:GetWidth() - 2 * PAD_X end
  local lw = math.floor(w * self.leftWeight / (1 + self.leftWeight) + 0.5)
  self.LeftPage:ClearAllPoints()
  self.LeftPage:SetPoint("TOPLEFT"); self.LeftPage:SetPoint("BOTTOMLEFT")
  self.LeftPage:SetWidth(lw)
  self.RightPage:ClearAllPoints()
  self.RightPage:SetPoint("TOPLEFT", self.LeftPage, "TOPRIGHT")
  self.RightPage:SetPoint("BOTTOMRIGHT")
  self.leftW, self.rightW = lw, w - lw -- the page turn needs both widths (Views.lua)
end

-- crumbs: list of strings; onClick(index) for each but the last
function PagleGuideBookMixin:SetCrumbs(list, onClick)
  for _, c in ipairs(self.crumbs) do c:Hide(); if c.Fleuron then c.Fleuron:Hide() end end
  local prev
  for i, text in ipairs(list) do
    local c = self.crumbs[i]
    if not c then
      c = CreateFrame("Button", nil, self.Strip)
      local fs = c:CreateFontString(nil, "OVERLAY"); fs:SetFontObject(P.Fonts.Crumb); fs:SetPoint("LEFT")
      c:SetFontString(fs)
      c:SetNormalFontObject(P.Fonts.Crumb); c:SetHighlightFontObject(P.Fonts.CrumbHover)
      c.Fleuron = atlasTexture(self.Strip, "OVERLAY", 0, "fleuron")
      c.Fleuron:SetSize(16, 16)
      self.crumbs[i] = c
    end
    c:SetText(text)
    c:SetSize(c:GetFontString():GetStringWidth(), 20)
    c:ClearAllPoints()
    if prev then
      c.Fleuron:ClearAllPoints()
      c.Fleuron:SetPoint("LEFT", prev, "RIGHT", 8, 0)
      c.Fleuron:Show()
      c:SetPoint("LEFT", c.Fleuron, "RIGHT", 8, 0)
    else
      c.Fleuron:Hide()
      c:SetPoint("LEFT", self.Strip, "LEFT", 0, 0)
    end
    c:SetScript("OnClick", (i < #list and onClick) and function() onClick(i) end or nil)
    c:Show()
    prev = c
  end
end

-- Stats keeps a leather foot band under the pages for its nameplate and live line: raise the pages' bottom
function PagleGuideBookMixin:SetPagesBottom(inset)
  self.Pages:SetPoint("BOTTOMRIGHT", -PAD_X, inset or PAD_B)
  self:LayoutPages()
end

function PagleGuideBookMixin:SetSearchShown(shown) self.Search:SetShown(shown) end

function PagleGuideBookMixin:SetSearchPlaceholder(text, onSearch)
  self.Search.Placeholder:SetText(text)
  self.onSearch = onSearch
end

function PagleGuideBookMixin:SetNameplate(text)
  if not text or text == "" then self.Nameplate:Hide(); return end
  self.Nameplate:SetText(text)
  self.Nameplate:Show()
end

-- kind: "red" (default) or "here" (the green Where I am ribbon)
function PagleGuideBookMixin:AddRibbon(label, kind, onClick)
  local b = newRibbon(self, label, kind or "red", onClick)
  local prev = self.ribbons[#self.ribbons]
  if prev then
    b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
  else
    b:SetPoint("TOPLEFT", self, "TOPRIGHT", -RIBBON_TUCK, -50)
  end
  self.ribbons[#self.ribbons + 1] = b
  self:SetRibbonSelected(self.selectedRibbon)
  return b
end

function PagleGuideBookMixin:SetRibbonSelected(ribbon)
  self.selectedRibbon = ribbon
  for i, b in ipairs(self.ribbons) do
    local on = (b == ribbon)
    local c = ribbonTint(b.kind, on)
    for _, t in ipairs({ b.Top, b.Mid, b.Bot }) do t:SetVertexColor(c:GetRGB()) end
    b.Top:SetPoint("TOPLEFT", on and 5 or 0, 0); b.Top:SetPoint("TOPRIGHT", on and 5 or 0, 0)
    b.Bot:SetPoint("BOTTOMLEFT", on and 5 or 0, 0); b.Bot:SetPoint("BOTTOMRIGHT", on and 5 or 0, 0)
    b.Label:SetPoint("CENTER", RIBBON_TUCK / 2 + (on and 5 or 0), 0)
    b.Label:SetAlpha(on and 1 or 0.85)
  end
end

-- ---------------------------------------------------------------- close button, nameplate, seal
PagleGuideWaxCloseMixin = {}
function PagleGuideWaxCloseMixin:OnLoad()
  self:SetSize(26, 26)
  self:SetNormalTexture(A.file);    crisp(self:GetNormalTexture()):SetTexCoord(atlasCoords("close"))
  self:SetPushedTexture(A.file);    crisp(self:GetPushedTexture()):SetTexCoord(atlasCoords("close-pushed"))
  self:SetHighlightTexture(A.file, "ADD"); crisp(self:GetHighlightTexture()):SetTexCoord(atlasCoords("close-highlight"))
  self:SetDisabledTexture(A.file);  crisp(self:GetDisabledTexture()):SetTexCoord(atlasCoords("close"))
  self:GetDisabledTexture():SetDesaturated(true)
end

PagleGuideBrassPlateMixin = {}
function PagleGuideBrassPlateMixin:OnLoad()
  -- 3-slice from the 128x64 "plate" sprite: 16-texel caps (8 units); 32 units tall incl. the sprite's padding
  self:SetHeight(32)
  self.L = atlasTexture(self, "ARTWORK", 0, "plate", 0, 0, 16, 64)
  self.M = atlasTexture(self, "ARTWORK", 0, "plate", 63, 0, 2, 64)
  self.R = atlasTexture(self, "ARTWORK", 0, "plate", 112, 0, 16, 64)
  self.L:SetPoint("TOPLEFT"); self.L:SetPoint("BOTTOMLEFT"); self.L:SetWidth(8)
  self.R:SetPoint("TOPRIGHT"); self.R:SetPoint("BOTTOMRIGHT"); self.R:SetWidth(8)
  self.M:SetPoint("TOPLEFT", self.L, "TOPRIGHT"); self.M:SetPoint("BOTTOMRIGHT", self.R, "BOTTOMLEFT")
  self.Text = self:CreateFontString(nil, "OVERLAY")
  self.Text:SetFontObject(P.Fonts.Plate)
  self.Text:SetPoint("CENTER", 0, 1)
end
function PagleGuideBrassPlateMixin:SetText(text)
  self.Text:SetText(text)
  self:SetWidth(math.ceil(self.Text:GetStringWidth()) + 22)
end

PagleGuideWaxSealMixin = {}
function PagleGuideWaxSealMixin:OnLoad()
  self.Wax = atlasTexture(self, "ARTWORK", 0, "seal")
  self.Wax:SetAllPoints()
  self.Empty = atlasTexture(self, "ARTWORK", 0, "seal-empty")
  self.Empty:SetAllPoints()
  self.Text = self:CreateFontString(nil, "OVERLAY")
  self.Text:SetPoint("CENTER", 0, 1)
  self:SetTilt(-8)
  self:SetEarned(true)
end
function PagleGuideWaxSealMixin:SetTilt(deg)
  local r = math.rad(deg)
  self.Wax:SetRotation(r); self.Empty:SetRotation(r)
  if self.Text.SetRotation then self.Text:SetRotation(r) end
end
function PagleGuideWaxSealMixin:SetEarned(earned)
  self.earned = earned
  self.Wax:SetShown(earned); self.Empty:SetShown(not earned)
  self.Text:SetFontObject(earned and P.Fonts.Seal or P.Fonts.SealEmpty)
end
function PagleGuideWaxSealMixin:SetText(text) self.Text:SetText(text) end
