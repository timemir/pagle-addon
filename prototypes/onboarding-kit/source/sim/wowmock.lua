-- A small, strict mock of the WoW UI API, enough to run the Pagle art probes offline.
-- Regions record what the addon asks for; sim.py resolves anchors and paints the result.
-- Unknown methods raise errors, so a misspelt or missing API shows up here instead of in game.

local REG = {}           -- every region, in creation order
local nextId = 0
local measure = _MEASURE -- python: measure(file, size, text) -> width

local function newId() nextId = nextId + 1; return nextId end

local Region = {}
Region.__index = function(t, k)
  local m = rawget(Region, k)
  if m then return m end
  local cls = rawget(t, "__class")
  local cm = cls and cls[k]
  if cm then return cm end
  if type(k) == "string" and k:match("^[A-Z]") then
    error(("mock: %s has no method '%s'"):format(rawget(t, "objectType") or "?", tostring(k)), 2)
  end
  return nil
end

local function region(objectType, parent, cls)
  local r = setmetatable({ __class = cls, objectType = objectType, id = newId(), parent = parent, points = {},
    shown = true, alpha = 1, scale = 1, children = {}, level = parent and parent.level and parent.level + 1 or 0,
    strata = parent and parent.strata or "MEDIUM" }, Region)
  if parent then table.insert(parent.children, r) end
  REG[#REG + 1] = r
  return r
end

local Common = {}
function Common:SetPoint(point, rel, relPoint, x, y)
  if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
  if type(rel) == "string" then rel = _G[rel] end
  if rel == nil then rel = self.parent end
  if type(relPoint) == "number" then x, y, relPoint = relPoint, x, nil end
  self.points[#self.points + 1] = { point = point, rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
function Common:ClearAllPoints() self.points = {} end
function Common:SetAllPoints(rel)
  rel = rel or self.parent
  self.points = {}
  self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
end
function Common:SetSize(w, h) if type(h) ~= "number" or type(w) ~= "number" then error("SetSize " .. type(w) .. type(h)) end self.w = w; self.h = h end
function Common:SetClampedToScreen() end
function Common:SetWidth(w) self.w = w end
function Common:SetHeight(h) if type(h) ~= "number" then error("SetHeight " .. type(h)) end self.h = h end
function Common:GetWidth() return self.w or 0 end
function Common:GetHeight() return self.h or 0 end
function Common:GetSize() return self.w or 0, self.h or 0 end
function Common:Show() local was = self.shown; self.shown = true; if not was and self.scripts and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Common:Hide() self.shown = false end
function Common:SetShown(s) self.shown = not not s end
function Common:IsShown() return self.shown end
function Common:SetAlpha(a) self.alpha = a end
function Common:GetAlpha() return self.alpha or 1 end
function Common:GetParent() return self.parent end
function Common:SetParent(p)
  if self.parent then for i, c in ipairs(self.parent.children) do if c == self then table.remove(self.parent.children, i) break end end end
  self.parent = p; table.insert(p.children, self)
end

local Frame = setmetatable({}, { __index = Common })
function Frame:SetFrameLevel(l) self.level = l end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameStrata(s)
  self.strata = s; self.explicitStrata = true
  local function down(f) for _, c in ipairs(f.children) do if not c.explicitStrata then c.strata = s; down(c) end end end
  down(self)
end
function Frame:SetScale(s) self.scale = s end
function Frame:GetScale() return self.scale end
function Frame:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function Frame:GetScript(name) return self.scripts and self.scripts[name] end
function Frame:HookScript() end
function Frame:EnableMouseWheel() end
function Common:IsVisible() local r = self; while r do if not r.shown then return false end; r = r.parent end; return true end
function Frame:EnableMouse() end
function Frame:RegisterEvent() end
function Frame:SetClipsChildren(c) self.clips = c end
function Frame:SetMovable() end
function Frame:RegisterForDrag() end
local Texture, FontString, Mask
function Frame:CreateTexture(name, layer, template, sub)
  local t = region("Texture", self, Texture); t.layer = layer or "ARTWORK"; t.sub = sub or 0; t.coord = { 0, 1, 0, 1 }
  return t
end
local Line
function Frame:CreateLine(name, layer, template, sub)
  local t = region("Line", self, Line); t.layer = layer or "ARTWORK"; t.sub = sub or 0; t.thick = 1
  return t
end
function Frame:CreateMaskTexture()
  local t = region("MaskTexture", self, Mask); t.layer = "ARTWORK"; t.sub = 0
  return t
end
function Frame:CreateFontString(name, layer)
  local t = region("FontString", self, FontString); t.layer = layer or "ARTWORK"; t.sub = 0; t.text = ""
  return t
end
function Frame:SetClampedToScreen() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:SetAutoFocus() end
function Frame:SetTextInsets() end
function Frame:ClearFocus() end
function Frame:SetMaxLetters() end
function Frame:SetFontObject(o) self.font = o end
function Frame:SetFontString(fs) self.fs = fs end
function Frame:GetFontString()
  if not self.fs then self.fs = self:CreateFontString(nil, "OVERLAY"); self.fs:SetPoint("CENTER") end
  return self.fs
end
function Frame:SetNormalFontObject(o) self:GetFontString():SetFontObject(o) end
function Frame:SetHighlightFontObject() end
function Frame:SetDisabledFontObject() end
function Frame:SetText(t) if self.objectType == "EditBox" then self.etext = t else self:GetFontString():SetText(t) end end
function Frame:GetText() if self.objectType == "EditBox" then return self.etext or "" end return self:GetFontString():GetText() end
function Frame:SetEnabled() end
function Frame:Enable() end
function Frame:Disable() end
function Frame:SetChecked(c) self.checked = c end
function Frame:GetChecked() return self.checked end
function Frame:SetHighlightTexture(tex, blend)
  local t = self:CreateTexture(nil, "HIGHLIGHT"); t.file = tex; t.highlight = true
  self.hl = t
end
function Frame:GetHighlightTexture() return self.hl end
local function stateTex(self, key, tex, layer)
  if type(tex) == "table" then self[key] = tex; return end
  local t = self[key] or self:CreateTexture(nil, layer); t:SetAllPoints(self)
  if tex then t:SetTexture(tex) end
  self[key] = t
end
function Frame:SetNormalTexture(tex) stateTex(self, "nt", tex, "ARTWORK") end
function Frame:GetNormalTexture() if not self.nt then stateTex(self, "nt", nil, "ARTWORK") end return self.nt end
function Frame:SetPushedTexture(tex) stateTex(self, "pt", tex, "ARTWORK"); self.pt.shown = false end
function Frame:GetPushedTexture() if not self.pt then self:SetPushedTexture() end return self.pt end
function Frame:SetDisabledTexture(tex) stateTex(self, "dt", tex, "ARTWORK"); self.dt.shown = false end
function Frame:GetDisabledTexture() if not self.dt then self:SetDisabledTexture() end return self.dt end
function Frame:SetCheckedTexture(tex) stateTex(self, "ct", tex, "ARTWORK"); self.ct.shown = false end
function Frame:SetPushedTextOffset() end
function Frame:SetHitRectInsets() end
function Frame:SetToplevel() end
function Frame:SetResizable() end
function Frame:SetPropagateKeyboardInput() end
function Frame:EnableKeyboard() end
function Frame:SetIgnoreParentScale() end
function Frame:SetDontSavePosition() end
function Frame:IsMouseOver() return false end
function Frame:GetLeft() return 0 end

Texture = setmetatable({}, { __index = Common })
function Texture:SetTexture(f) self.file = f; self.color = nil end
function Texture:GetTexture() return self.file end
function Texture:SetColorTexture(r, g, b, a) self.color = { r, g, b, a or 1 }; self.file = nil end
function Texture:SetTexCoord(l, r, t, b) self.coord = { l, r, t, b } end
function Texture:GetTexCoord() return self.coord[1], self.coord[2], self.coord[3], self.coord[4] end
function Texture:SetSnapToPixelGrid() end
function Texture:SetTexelSnappingBias() end
function Texture:SetRotation(r) self.rotation = r end
function Texture:AddMaskTexture(m) self.mask = m end
function Texture:SetDrawLayer(l, s) self.layer = l; self.sub = s or self.sub end
function Texture:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a or 1 } end
function Texture:SetGradient(o, a, b) self.gradient = { o, { a.r, a.g, a.b, a.a or 1 }, { b.r, b.g, b.b, b.a or 1 } } end
function Texture:SetBlendMode(m) self.blend = m end
function Texture:SetDesaturated() end
function Texture:SetDesaturation() end

Line = setmetatable({}, { __index = Common })
function Line:SetStartPoint(p, rel, x, y) self.p0 = { p, rel, x or 0, y or 0 } end
function Line:SetEndPoint(p, rel, x, y) self.p1 = { p, rel, x or 0, y or 0 } end
function Line:SetThickness(t) self.thick = t end
function Line:SetColorTexture(r, g, b, a) self.color = { r, g, b, a or 1 } end
function Line:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a or 1 } end
function Line:SetTexture(f) self.file = f end

Mask = setmetatable({}, { __index = Common })
function Mask:SetTexture(f) self.file = f end

local FontObj = {}
FontObj.__index = function(t, k)
  local m = rawget(FontObj, k); if m then return m end
  error("mock: Font has no method '" .. tostring(k) .. "'", 2)
end
function FontObj:SetFont(file, size) self.file = file; self.size = size; return true end
function FontObj:GetFont() return self.file, self.size, "" end
function FontObj:SetTextColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function FontObj:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a or 1 } end
function FontObj:SetShadowOffset(x, y) self.shadow = { x, y } end
function FontObj:SetJustifyH(j) self.justify = j end
function FontObj:SetFontObject(o) for k, v in pairs(o) do self[k] = v end end
function CreateFont(name) local f = setmetatable({ size = 12, color = { 1, 1, 1, 1 }, shadow = { 0, 0 }, justify = "CENTER" }, FontObj); _G[name] = f; return f end
GameFontNormal = CreateFont("GameFontNormal"); GameFontNormal:SetFont("Fonts\\FRIZQT__.TTF", 12)

FontString = setmetatable({}, { __index = Common })
function FontString:SetFontObject(o) self.font = o end
local function fget(self, k) return self["_" .. k] or (self.font and self.font[k]) end
function FontString:SetText(s) self.text = tostring(s or "") end
function FontString:GetText() return self.text end
function FontString:SetWordWrap(w) self.wrap = w end
function FontString:SetNonSpaceWrap() end
function FontString:SetSpacing(n) self.spacing = n end
function FontString:SetMaxLines() end
function FontString:SetTextColor(r, g, b, a) self._color = { r, g, b, a or 1 } end
function FontString:SetShadowColor(r, g, b, a) self._shadowColor = { r, g, b, a or 1 } end
function FontString:SetShadowOffset(x, y) self._shadow = { x, y } end
function FontString:SetJustifyH(j) self._justify = j end
function FontString:SetJustifyV() end
function FontString:SetDrawLayer(l, s) self.layer = l; self.sub = s or self.sub end
function FontString:SetRotation(r) self.rotation = r end
function FontString:SetFont(file, size) self._file = file; self._size = size end
function FontString:GetStringWidth() return measure(fget(self, "file"), fget(self, "size"), self.text) end
function FontString:GetStringHeight()
  if self.wrap and self.w then local n = _NLINES(fget(self, "file"), fget(self, "size"), self.text, self.w); return fget(self, "size") * n + (self.spacing or 0) * (n - 1) end
  return fget(self, "size")
end
function FontString:GetFont() return fget(self, "file"), fget(self, "size"), "" end
function FontString:GetWidth() return self.w or self:GetStringWidth() end
function FontString:GetHeight() return self.h or self:GetStringHeight() end
FontString._get = fget

_TEMPLATES = _TEMPLATES or {}
function Mixin(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
function CreateFrame(kind, name, parent, template)
  local f = region(kind or "Frame", parent, Frame)
  f.w, f.h = 0, 0
  if name then _G[name] = f end
  local scripts = {}
  for tname in tostring(template or ""):gmatch("[^,%s]+") do
    local t = _TEMPLATES[tname]
    if not t then error("mock: unknown template " .. tname, 2) end
    if t.mixin then Mixin(f, _G[t.mixin]) end
    if t.w then f.w, f.h = t.w, t.h end
    if t.strata then f.strata = t.strata end
    for k, v in pairs(t.scripts or {}) do scripts[k] = v end
  end
  local onload = scripts.OnLoad
  if onload then f[onload](f) end
  if scripts.OnSizeChanged and f.w then f[scripts.OnSizeChanged](f, f.w, f.h) end
  return f
end

UIParent = region("Frame", nil, Frame); UIParent.w, UIParent.h = _SCREEN_W, _SCREEN_H; UIParent.root = true
UISpecialFrames = {}
SlashCmdList = {}
function CreateColorFromHexString(h)
  local a, r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), tonumber(h:sub(7, 8), 16)
  return { r = r / 255, g = g / 255, b = b / 255, a = a / 255, GetRGB = function(c) return c.r, c.g, c.b end, GetRGBA = function(c) return c.r, c.g, c.b, c.a end }
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a or 1, GetRGB = function(c) return c.r, c.g, c.b end, GetRGBA = function(c) return c.r, c.g, c.b, c.a end } end
function SetPortraitTexture(t) t.portrait = true end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s)
  local out = {}
  for p in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = p end
  return unpack(out)
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function print(...) _PRINT(table.concat({ ... }, " ")) end

_MOCK = { REG = REG, FontString = FontString }

_NOW = 0
function GetTime() return _NOW end
function PlaySound(id, channel) _PRINT("[sound " .. tostring(id) .. "]") end
SOUNDKIT = {}
