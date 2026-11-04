---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- `/pagle dev glyphs` (#248, CORE-R9): the glyph probe line once in each font Pagle draws with, so the dev can see in
-- the game which characters each font has. A plain dark panel, centred over everything; a click or Esc hides it.
-- `/pagle dev fonts` (#522) shows its sample line once in each client font that loads in a panel of the same kind.

---@class PagleNS
---@field glyphProbeFrame PagleDevGlyphsFrame? `/pagle dev glyphs`' panel, once built
---@field fontProbeFrame PagleDevGlyphsFrame? `/pagle dev fonts`' panel, once built

local ROW_HEIGHT, PAD, SIZE = 40, 16, 16

--- One panel: the frame's global name (UISpecialFrames takes names, and Esc hides the frames it lists), the prefix of
--- its rows' font objects, the field of `ns` that keeps its frame, and its width.
---@class PagleDevGlyphsPanel
---@field frameName string
---@field fontPrefix string
---@field slot string
---@field width number

---@type PagleDevGlyphsPanel
local GLYPHS =
	{ frameName = "PagleDevGlyphs", fontPrefix = "PagleDevGlyphsFont", slot = "glyphProbeFrame", width = 760 }
---@type PagleDevGlyphsPanel
local FONTS = { frameName = "PagleDevFonts", fontPrefix = "PagleDevFontsFont", slot = "fontProbeFrame", width = 960 }

---@class PagleDevGlyphsFrame: Button
---@field rows FontString[]

-- The file a row names and draws with, when it has no font object: a client font file as it is, or a bundled face as
-- the Pagle language applied draws it (CORE-R9).
---@param font PagleDevGlyphFont
---@return string
local function fileOf(font)
	return font.file or ns.faces:File(font.face)
end

-- The font object a row draws with: the named one, or for a font file a font object of its own on that file
-- (<prefix><row>), as the Journal makes its faces. A face that won't load draws in the client's FRIZQT__.
---@param panel PagleDevGlyphsPanel
---@param font PagleDevGlyphFont
---@param index integer
---@return string
local function fontObject(panel, font, index)
	if font.object then
		return font.object
	end
	local name = panel.fontPrefix .. index
	local made = CreateFont(name)
	if font.file then
		made:SetFont(font.file, SIZE, "")
	else
		ns.faces:Set(made, font.face, SIZE)
	end
	return name
end

-- Builds the panel with one row per font.
---@param panel PagleDevGlyphsPanel
---@param fonts PagleDevGlyphFont[]
---@return PagleDevGlyphsFrame
local function build(panel, fonts)
	local frame = CreateFrame("Button", panel.frameName, UIParent) --[[@as PagleDevGlyphsFrame]]
	frame:SetSize(panel.width, PAD * 2 + ROW_HEIGHT * #fonts)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.85)
	frame.rows = {}
	for i, font in ipairs(fonts) do
		local row = frame:CreateFontString(nil, "OVERLAY", fontObject(panel, font, i))
		row:SetPoint("TOPLEFT", PAD, -PAD - ROW_HEIGHT * (i - 1))
		row:SetWidth(panel.width - PAD * 2)
		row:SetJustifyH("LEFT")
		frame.rows[i] = row
	end
	frame:SetScript("OnClick", function(self)
		self:Hide()
	end)
	table.insert(UISpecialFrames, panel.frameName)
	return frame
end

-- Shows `probe` once in each of `fonts` in `panel`, each row labelled with its font and what uses it. One frame per
-- panel, built on first use and reused.
---@param panel PagleDevGlyphsPanel
---@param fonts PagleDevGlyphFont[]
---@param probe string
local function show(panel, fonts, probe)
	local frame = ns[panel.slot] or build(panel, fonts)
	ns[panel.slot] = frame
	for i, font in ipairs(fonts) do
		local row = frame.rows[i]
		if row then
			row:SetText(ns.L.DEV_GLYPHS_ROW:format(font.object or fileOf(font), font.usedBy, probe))
		end
	end
	frame:Show()
end

--- Shows `probe` once in each of `fonts`, each row labelled with its font and what uses it. One panel, built on first
--- use and reused.
---@param fonts PagleDevGlyphFont[]
---@param probe string
function ns.ShowGlyphProbe(fonts, probe)
	show(GLYPHS, fonts, probe)
end

--- `/pagle dev fonts`' panel (#522): `probe` once in each client font that loaded, in a panel of its own. The panel is
--- built for the first call's fonts, which the same client's later calls repeat.
---@param fonts PagleDevGlyphFont[]
---@param probe string
function ns.ShowFontProbe(fonts, probe)
	show(FONTS, fonts, probe)
end
