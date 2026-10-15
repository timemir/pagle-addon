---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The previews of Core's own goods on the Curio Shop's stage (wallet-and-shop.md › UI, the preview stage), by slot:
-- logic/CoreGoods.lua's goods draw with these, looked up when the shop draws one. A sound set shows its swatch and
-- » Toast / » Banner / » Legend buttons playing its sounds on the SFX channel (ANN-R73); a crest, a small bookplate
-- with the crest on it, as prototypes/curio-shop/ (variant B) draws them. The toast styles add the toast style's.
local L = ns.L

-- Each stage's panels, one per slot drawn on it, reused at the next drawing. Weak, so a stage the shop drops goes.
---@type table<Frame, table<string, Frame>>
local panels = setmetatable({}, { __mode = "k" })

--- The panel for `slotID` on `stage`, built by `build` the first time, shown, with Core's other panels on that stage
--- hidden: a stage shows one good at a time. The toast styles' preview draws on one too (adapter/ToastStyles.lua).
---@param stage Frame
---@param slotID string
---@param build fun(panel: Frame)
---@return Frame
function ns.CorePreviewPanel(stage, slotID, build)
	local own = panels[stage]
	if not own then
		own = {}
		panels[stage] = own
	end
	for _, panel in pairs(own) do
		panel:Hide()
	end
	local panel = own[slotID]
	if not panel then
		panel = CreateFrame("Frame", nil, stage)
		panel:SetAllPoints(stage)
		build(panel)
		own[slotID] = panel
	end
	panel:Show()
	return panel
end

---@class PagleSoundSetPanel: Frame
---@field swatch Texture
---@field set PagleSoundSet
---@field turn integer  -- toast sounds played since it was drawn, for the next variant (ANN-R72)

-- A button on `panel` labelled `label` that runs `onClick`.
---@param panel Frame
---@param label string
---@param onClick fun()
---@return Button
local function soundButton(panel, label, onClick)
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate") --[[@as Button]]
	button:SetSize(90, 22)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	return button
end

-- A sound set's panel: its swatch, a button per sound, and a note that the Legend sting is shared (ANN-R72).
---@param panel PagleSoundSetPanel
local function buildSoundSet(panel)
	panel.swatch = panel:CreateTexture(nil, "ARTWORK")
	panel.swatch:SetSize(72, 72)
	panel.swatch:SetPoint("TOP", 0, -24)
	local toast = soundButton(panel, L.PREVIEW_TOAST, function()
		local set = panel.set
		PlaySoundFile(set.toast[panel.turn % #set.toast + 1], "SFX")
		panel.turn = panel.turn + 1
	end)
	local banner = soundButton(panel, L.PREVIEW_BANNER, function()
		PlaySoundFile(panel.set.banner, "SFX")
	end)
	local legend = soundButton(panel, L.PREVIEW_LEGEND, function()
		PlaySoundFile(ns.LEGEND_STING, "SFX")
	end)
	banner:SetPoint("TOP", panel.swatch, "BOTTOM", 0, -14)
	toast:SetPoint("RIGHT", banner, "LEFT", -6, 0)
	legend:SetPoint("LEFT", banner, "RIGHT", 6, 0)
	local note = ns.Text(panel, "GameFontDisableSmall")
	note:SetPoint("TOP", banner, "BOTTOM", 0, -10)
	note:SetText(L.PREVIEW_STING_SHARED)
end

---@class PagleCrestPanel: Frame
---@field crest Texture
---@field name FontString

-- A crest's bookplate's size, as the prototype's; it is drawn in ns.TIMBER's parchment and ink.
local PLATE_WIDTH, PLATE_HEIGHT = 150, 170

-- A crest's panel: a small bookplate, "Ex Libris", the crest, the Angler's name, then where it shows (LED-R112).
---@param panel PagleCrestPanel
local function buildCrest(panel)
	local TIMBER = ns.TIMBER
	local plate = CreateFrame("Frame", nil, panel)
	plate:SetSize(PLATE_WIDTH, PLATE_HEIGHT)
	plate:SetPoint("TOP", 0, -16)
	ns.Framed(plate, TIMBER.parchment, TIMBER.parchmentEdge, 2)
	local exLibris = ns.Text(plate, "GameFontNormalSmall", TIMBER.ink)
	exLibris:SetPoint("TOP", 0, -12)
	exLibris:SetText(L.PREVIEW_EX_LIBRIS)
	panel.crest = plate:CreateTexture(nil, "ARTWORK")
	panel.crest:SetSize(70, 70)
	panel.crest:SetPoint("TOP", exLibris, "BOTTOM", 0, -8)
	panel.crest:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- the icon's own border off
	panel.name = ns.Text(plate, "GameFontNormalLarge", TIMBER.ink)
	panel.name:SetPoint("TOP", panel.crest, "BOTTOM", 0, -10)
	local note = ns.Text(panel, "GameFontDisableSmall")
	note:SetPoint("TOP", plate, "BOTTOM", 0, -10)
	note:SetText(L.PREVIEW_CREST_NOTE)
end

--- Each of Core's slots' preview drawer, by slot ID (logic/CoreGoods.lua). The toast styles add theirs for
--- "core.toaststyle" (ANN-R80).
---@type table<string, PagleCorePreview>
ns.CORE_PREVIEWS = {
	[ns.SOUND_SET_SLOT] = function(stage, good)
		local panel = ns.CorePreviewPanel(stage, ns.SOUND_SET_SLOT, buildSoundSet) --[[@as PagleSoundSetPanel]]
		panel.swatch:SetTexture(good.icon)
		panel.set = ns.SoundSetOf(good.id)
		panel.turn = 0
	end,
	[ns.CREST_SLOT] = function(stage, good)
		local panel = ns.CorePreviewPanel(stage, ns.CREST_SLOT, buildCrest) --[[@as PagleCrestPanel]]
		panel.crest:SetTexture(good.icon)
		panel.name:SetText((UnitName("player")))
	end,
}
