---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- `/pagle dev glyphs` (#248, CORE-R9): the glyph probe line once in each font Pagle draws with, so the dev can see in
-- the game which characters each font has. A plain dark panel, centred over everything; a click or Esc hides it.

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleDevGlyphs"
local WIDTH, ROW_HEIGHT, PAD, SIZE = 760, 40, 16, 16

---@class PagleDevGlyphsFrame: Button
---@field rows FontString[]

-- The font object a row draws with: the named one, or for a font file a font object of its own on that file
-- (PagleDevGlyphsFont<row>), as the Journal makes its faces.
---@param font PagleDevGlyphFont
---@param index integer
---@return string
local function fontObject(font, index)
	if font.object then
		return font.object
	end
	local name = "PagleDevGlyphsFont" .. index
	CreateFont(name):SetFont(font.file, SIZE, "")
	return name
end

-- Builds the panel with one row per font.
---@param fonts PagleDevGlyphFont[]
---@return PagleDevGlyphsFrame
local function build(fonts)
	local frame = CreateFrame("Button", FRAME_NAME, UIParent) --[[@as PagleDevGlyphsFrame]]
	frame:SetSize(WIDTH, PAD * 2 + ROW_HEIGHT * #fonts)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.85)
	frame.rows = {}
	for i, font in ipairs(fonts) do
		local row = frame:CreateFontString(nil, "OVERLAY", fontObject(font, i))
		row:SetPoint("TOPLEFT", PAD, -PAD - ROW_HEIGHT * (i - 1))
		row:SetWidth(WIDTH - PAD * 2)
		row:SetJustifyH("LEFT")
		frame.rows[i] = row
	end
	frame:SetScript("OnClick", function(self)
		self:Hide()
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	return frame
end

--- Shows `probe` once in each of `fonts`, each row labelled with its font and what uses it. One panel, built on first
--- use and reused.
---@param fonts PagleDevGlyphFont[]
---@param probe string
function ns.ShowGlyphProbe(fonts, probe)
	local frame = ns.glyphProbeFrame or build(fonts)
	ns.glyphProbeFrame = frame
	for i, font in ipairs(fonts) do
		frame.rows[i]:SetText(ns.L.DEV_GLYPHS_ROW:format(font.object or font.file, font.usedBy, probe))
	end
	frame:Show()
end
