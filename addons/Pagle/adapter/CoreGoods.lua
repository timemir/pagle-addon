---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The previews of Core's own goods on the Curio Shop's stage (wallet-and-shop.md › UI, the preview stage), by slot:
-- logic/CoreGoods.lua's goods draw with these, looked up when the shop draws one. A sound set shows its swatch and
-- » Toast / » Banner / » Legend buttons playing its sounds on the SFX channel (ANN-R73); a crest, a small bookplate
-- with the crest on it, as prototypes/curio-shop/ (variant B) draws them; a binding, its closed book. The toast styles
-- add the toast style's.
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

-- A sound set's panel: its swatch, a button per sound, the first Legend's sting for » Legend, and a note that the
-- Legend stings are the same in every set (ANN-R72).
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
		PlaySoundFile(ns.LegendSting(), "SFX")
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

---@class PagleBindingPanel: Frame
---@field book PagleSprite         -- the closed book, the binding's swatch
---@field live Frame               -- a live closed book, where no kit drew one: the binding drawn by the renderer
---@field binding PagleBookBinding? -- the live book's binding, pinned to the good shown, made at its first showing
---@field note FontString

-- The closed book's top on the stage, as the crest's bookplate sits, and the width its drawn book is drawn at: the
-- Ledger art kit's books', which the shop expansion's larger ones are drawn down to, so every binding shows the same
-- size and, with the note under it, fits the stage's 190. A binding no kit drew closed is drawn live at that size, as
-- tall as the Ledger kit's swatches (104 × 134), its corner pieces and gilt corner drawn down by LIVE_SCALE from the
-- open books' (the Fish Journal's 600 high).
local BOOK_TOP, BOOK_WIDTH, LIVE_HEIGHT = 16, 104, 134
local LIVE_SCALE = LIVE_HEIGHT / 600
local LIVE_CORNER, LIVE_GILT_CORNER = math.floor(44 * LIVE_SCALE + 0.5), math.floor(40 * LIVE_SCALE + 0.5)

-- A binding's panel: its closed book, the swatch or a live one, then that every book wears it (ADR 0015).
---@param panel PagleBindingPanel
local function buildBinding(panel)
	panel.book = ns.ArtSprite(panel, "Bindings", "binding-field-leather")
	panel.live = CreateFrame("Frame", nil, panel)
	panel.live:SetSize(BOOK_WIDTH, LIVE_HEIGHT)
	panel.live:SetPoint("TOP", 0, -BOOK_TOP)
	panel.live:Hide()
	panel.note = ns.Text(panel, "GameFontDisableSmall")
	panel.note:SetText(L.PREVIEW_BINDING_NOTE)
end

-- Draws binding `goodID` as a live closed book on `panel`, the renderer pinned to it (BIND-R1, BIND-R2). Returns how
-- far down its foot is.
---@param panel PagleBindingPanel
---@param goodID string
---@return number
local function drawLiveBook(panel, goodID)
	panel.live:Show()
	if panel.binding then
		panel.binding:SetLook(goodID)
	else
		panel.binding = Pagle.NewBookBinding(
			panel.live,
			{ pinned = goodID, cornerSize = LIVE_CORNER, giltCornerSize = LIVE_GILT_CORNER }
		)
	end
	return BOOK_TOP + LIVE_HEIGHT
end

-- Draws `look`'s closed book from its swatch, its drawn book BOOK_WIDTH wide, its top BOOK_TOP down the panel and
-- centred across it. Returns how far down its foot is.
---@param panel PagleBindingPanel
---@param look PagleBindingLook
---@return number
local function drawClosedBook(panel, look)
	local book = ns.SetSprite(panel.book, look.swatchAtlas --[[@as string]], look.swatch --[[@as string]])
	local box = book.box
	local scale = BOOK_WIDTH / box[3]
	local width, height = book:GetSize()
	book:SetSize(width * scale, height * scale)
	book.box = { box[1] * scale, box[2] * scale, BOOK_WIDTH, box[4] * scale }
	book:ClearAllPoints()
	book:SetPoint("TOP", panel, "TOP", width * scale / 2 - (book.box[1] + BOOK_WIDTH / 2), book.box[2] - BOOK_TOP)
	return BOOK_TOP + book.box[4]
end

--- Each of Core's slots' preview drawer, by slot ID (logic/CoreGoods.lua). The toast styles add theirs for
--- "core.toaststyle" (ANN-R80).
---@type table<string, PagleCorePreview>
ns.CORE_PREVIEWS = {
	-- A binding's closed book (ADR 0015), the kits' swatch of it, Core's art for a Module's earned one too (SHOP-R25);
	-- for the three no kit drew closed (Oilcloth, Tooled Leather, Verdigris), a live one the renderer draws.
	[ns.BINDING_SLOT] = function(stage, good)
		local panel = ns.CorePreviewPanel(stage, ns.BINDING_SLOT, buildBinding) --[[@as PagleBindingPanel]]
		local look = ns.BindingLook(good.id)
		local foot
		panel.book:SetShown(look.swatch ~= nil)
		if look.swatch then
			panel.live:Hide()
			foot = drawClosedBook(panel, look)
		else
			foot = drawLiveBook(panel, good.id)
		end
		panel.note:ClearAllPoints()
		panel.note:SetPoint("TOP", panel, "TOP", 0, -(foot + 10))
	end,
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
