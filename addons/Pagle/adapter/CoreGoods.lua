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
	return ns.PanelButton(panel, label, 90, nil, onClick)
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

-- A crest's bookplate's size, as the prototype's, and its parchment, edge and ink, each { r, g, b[, a] }. It is drawn
-- at PLATE_SCALE so it and the note under it fit the Curio Shop's 190-high stage (wallet-and-shop.md › UI).
local PLATE_WIDTH, PLATE_HEIGHT, PLATE_SCALE = 150, 170, 0.85
local PLATE = { parchment = { 0.93, 0.87, 0.72, 1 }, edge = { 0.54, 0.35, 0.10, 1 }, ink = { 0.23, 0.15, 0.06 } }

-- A crest's panel: a small bookplate, "Ex Libris", the crest, the Angler's name, then where it shows (LED-R112).
---@param panel PagleCrestPanel
local function buildCrest(panel)
	local plate = CreateFrame("Frame", nil, panel)
	plate:SetSize(PLATE_WIDTH, PLATE_HEIGHT)
	plate:SetScale(PLATE_SCALE)
	plate:SetPoint("TOP", 0, -16)
	ns.Framed(plate, PLATE.parchment, PLATE.edge, 2)
	local exLibris = ns.Text(plate, "GameFontNormalSmall", PLATE.ink)
	exLibris:SetPoint("TOP", 0, -12)
	exLibris:SetText(L.PREVIEW_EX_LIBRIS)
	panel.crest = plate:CreateTexture(nil, "ARTWORK")
	panel.crest:SetSize(60, 70) -- the shield, where a 70 x 70 icon stood (SHOP-R25)
	panel.crest:SetPoint("TOP", exLibris, "BOTTOM", 0, -8)
	ns.CropShield(panel.crest)
	panel.name = ns.Text(plate, "GameFontNormalLarge", PLATE.ink)
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

-- The owner of the GET_ITEM_INFO_RECEIVED registration: a fish crest's fish arriving (VAR-R12).
local OWNER = "Pagle fish crests"

--- Login step 1, once the catalogue is built and before the variety projection starts: registers Core's fish crests
--- (VAR-R12) over the client's item names. A fish an enUS client names "Raw …" is named without it (the locale's
--- FISH_CREST_DROP_PREFIX, never another locale's names). Each fish the client hasn't cached is requested, and its
--- GET_ITEM_INFO_RECEIVED renames its crest (SHOP-R26); the registration is dropped once every fish is named.
function ns.StartFishCrests()
	local hooks = {
		species = ns.Catalogue.GetVarietySpecies(),
		caught = Pagle.GetVarietiesCaught,
		itemName = function(itemID)
			return ns.UnlessSecret(issecretvalue, (C_Item.GetItemNameByID(itemID)))
		end,
		dropPrefix = GetLocale() == "enUS" and L.FISH_CREST_DROP_PREFIX or nil,
		owned = Pagle.IsOwned,
	}
	local renamed = ns.RegisterFishCrests(hooks)
	---@type table<integer, true>
	local pending, waiting = {}, 0
	for _, speciesID in ipairs(hooks.species) do
		if not ns.FishCrestFish(hooks, speciesID) then
			pending[speciesID], waiting = true, waiting + 1
		end
	end
	if waiting == 0 then
		return
	end
	Pagle.RegisterEvent(OWNER, "GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
		if success and pending[itemID] and ns.FishCrestFish(hooks, itemID) then
			pending[itemID], waiting = nil, waiting - 1
			renamed(itemID)
			if waiting == 0 then
				Pagle.UnregisterEvent(OWNER, "GET_ITEM_INFO_RECEIVED")
			end
		end
	end)
	for speciesID in pairs(pending) do
		C_Item.RequestLoadItemDataByID(speciesID)
	end
end
