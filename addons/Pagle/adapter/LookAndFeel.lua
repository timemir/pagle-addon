---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Look and Feel page and the slot dropdowns (settings.md SET-R50–R53, SET-R30, SET-R5, SET-R6; CORE-R42;
-- wallet-and-shop.md › UI). A slot dropdown is a row Core draws itself on its own template (adapter/Settings.xml,
-- PagleSettingsSlotRowTemplate): the slot's label, a dropdown of its owned goods that reads ns.goods:GetEquipped and
-- writes ns.goods:SetEquipped, and "{N} more in the Curio Shop" under it. Its frames are Core's, so Core redraws them at
-- once on AppearanceChanged; it writes nothing onto Blizzard's initializers or settings (SET-R6). A proxy setting
-- per page carries the slot's default good, so the page's Defaults button restores it (SET-R60). adapter/Settings.lua
-- registers the page and calls ns.BuildLookAndFeel, and ends each Module's section on Trackers with ns.SlotDropdown
-- (SET-R44); adapter/AnnouncementSettings.lua ends Core's Announcements rows with it. Its own owner on Core's bus.
local OWNER = "Pagle look and feel"
local L = ns.L

-- The template of a slot dropdown's row (adapter/Settings.xml): 46 pixels, the dropdown's line and the note's.
local SLOT_ROW_TEMPLATE = "PagleSettingsSlotRowTemplate"

-- Every slot dropdown's proxy setting by its variable: a variable is registered once (Settings.RegisterProxySetting).
---@type table<string, SettingsProxySetting>
local registered = {}

---@class PagleSlotRowWidgets
---@field label FontString
---@field dropdown DropdownButton
---@field note FontString
---@field measure FontString hidden, measuring the goods' names

-- Core's widgets on a slot row's frame, by frame, and the slot each frame shows now (nil once released). Weak, as the
-- panel's list owns the frames.
---@type table<Frame, PagleSlotRowWidgets>
local widgetsOf = setmetatable({}, { __mode = "k" })
---@type table<Frame, string>
local slotOf = setmetatable({}, { __mode = "k" })

-- Where the dropdown starts, from the row's top centre, and the gap the label keeps before it.
local DROPDOWN_X, LABEL_GAP = -80, 8
-- The dropdown's width: 220, wider for a longer good's name (German's "Wappen: Longjaw Mud Snapper"), its words and
-- the room its text keeps from the edges and the arrow, up to 300, so it still ends short of where a row's button
-- does (SET-R11); past that the client cuts the name with "...".
local DROPDOWN_W, DROPDOWN_MAX, DROPDOWN_PAD = 220, 300, 44

-- The widgets on `frame`, made the first time a slot row draws on it: the label at the left as a native row's, the
-- dropdown beside it, and the note under the dropdown.
---@param frame Frame
---@return PagleSlotRowWidgets
local function widgets(frame)
	local own = widgetsOf[frame]
	if not own then
		-- The label ends a gap short of the dropdown and wraps onto a second line under itself, within the row's
		-- height: unbounded, a long one ran under the dropdown ("Marco del rastreador de Estadísticas").
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", 37, -6)
		label:SetPoint("RIGHT", frame, "TOP", DROPDOWN_X - LABEL_GAP, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(true)
		label:SetMaxLines(2)
		local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
		dropdown:SetPoint("TOPLEFT", frame, "TOP", DROPDOWN_X, -2)
		dropdown:SetWidth(220)
		local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		note:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 2, -2)
		note:SetJustifyH("LEFT")
		-- Measures the goods' names in the dropdown's font (its template's Text's, else the small highlight font it
		-- inherits), hidden, so the dropdown's own text is never changed.
		local measure = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		local shown = (dropdown --[[@as table]]).Text --[[@as FontString?]]
		if shown and shown.GetFontObject and shown:GetFontObject() then
			measure:SetFontObject(shown:GetFontObject())
		end
		measure:SetWordWrap(false)
		measure:Hide()
		own = { label = label, dropdown = dropdown, note = note, measure = measure }
		widgetsOf[frame] = own
	end
	return own
end

-- The dropdown's menu for `slotID` (SET-R51): one choice per owned good by name, in registration order, read each
-- time it opens; the equipped one is selected, and picking one equips it (SHOP-R32).
---@param slotID string
---@return fun(owner: DropdownButton, root: RootMenuDescriptionProxy)
local function menu(slotID)
	local function isSelected(goodID)
		return ns.goods:GetEquipped(slotID) == goodID
	end
	local function setSelected(goodID)
		ns.goods:SetEquipped(slotID, goodID)
	end
	return function(_, root)
		for _, choice in ipairs(ns.SlotChoices(ns.goods, slotID)) do
			root:CreateRadio(choice.label, isSelected, setSelected, choice.value)
		end
	end
end

-- Draws slot `slot` on `frame`: its label, its dropdown showing the equipped good, and "{N} more in the Curio Shop"
-- while N, the slot's for-sale goods not owned, is above 0, read now (SET-R51).
---@param frame Frame
---@param slot PagleRegisteredSlot
local function draw(frame, slot)
	local own = widgets(frame)
	slotOf[frame] = slot.id
	own.label:SetText(slot.label)
	local widest = 0
	for _, choice in ipairs(ns.SlotChoices(ns.goods, slot.id)) do
		own.measure:SetText(choice.label)
		widest = math.max(widest, own.measure:GetStringWidth())
	end
	own.dropdown:SetWidth(math.max(DROPDOWN_W, math.min(widest + DROPDOWN_PAD, DROPDOWN_MAX)))
	own.dropdown:SetupMenu(menu(slot.id))
	local more = ns.SlotMoreInShop(ns.goods, slot.id)
	own.note:SetText(ns.RenderText(L.SETTINGS_SLOT_MORE, { more = more }))
	own.note:SetShown(more > 0)
end

--- The mixin of a slot dropdown's row frames (adapter/Settings.xml, SET-R5, SET-R6). The panel's list draws one
--- through Blizzard's stock InitFrame, which calls its Init, and releases it through the stock Resetter, which calls
--- its Release.
---@class PagleSettingsSlotRowMixin : Frame
PagleSettingsSlotRowMixin = {}

--- Draws the slot Core put in its initializer's data.
---@param initializer SettingsInitializer
function PagleSettingsSlotRowMixin:Init(initializer)
	draw(self, initializer:GetData().slot)
end

--- The frame shows no slot any more, so AppearanceChanged leaves it alone.
function PagleSettingsSlotRowMixin:Release()
	slotOf[self] = nil
end

-- The slot's proxy setting on `page` under `variable`, registered the first time: no row shows it, but its default,
-- which the page's Defaults button restores, is the slot's default good (SET-R60), and restoring it equips that.
---@param page SettingsCategory
---@param slot PagleRegisteredSlot
---@param variable string
local function defaultsSetting(page, slot, variable)
	if registered[variable] then
		return
	end
	local slotID = slot.id
	registered[variable] = Settings.RegisterProxySetting(
		page,
		variable,
		Settings.VarType.String,
		slot.label,
		ns.goods:DefaultOf(slotID),
		function()
			return ns.goods:GetEquipped(slotID)
		end,
		function(goodID)
			ns.goods:SetEquipped(slotID, goodID)
		end
	)
end

--- Adds a slot dropdown (SET-R51) to `page`'s `layout`, the same row on every page: labelled and found in the
--- settings search by the slot's label, never greyed out. Its setting, which its page's Defaults restores, is
--- Pagle_Core_<topic>_<slotID>: `topic` is the page's, "look", "announcements" or a topic page's (SET-R60).
---@param page SettingsCategory
---@param layout SettingsLayout
---@param slot PagleRegisteredSlot
---@param topic string
---@return SettingsInitializer
function ns.SlotDropdown(page, layout, slot, topic)
	local variable = ("Pagle_Core_%s_%s"):format(topic, slot.id)
	defaultsSetting(page, slot, variable)
	local initializer = Settings.CreateElementInitializer(SLOT_ROW_TEMPLATE, { name = slot.label, slot = slot })
	initializer:AddSearchTags(slot.label)
	layout:AddInitializer(initializer)
	return initializer
end

-- A slot dropdown redraws at once wherever it shows when its look changes, whatever changed it (SET-R51, SET-R62,
-- SHOP-R33): its own frames, which are Core's (SET-R6).
Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slotID)
	for frame, shown in pairs(slotOf) do
		if shown == slotID then
			widgetsOf[frame].dropdown:GenerateMenu()
		end
	end
end)

-- The Curio Shop row (SET-R50 item 3), drawn by Core (adapter/Settings.lua's ns.SettingsButtonRow, #606): pressing it
-- closes the panel first, as the shop would open behind it, then opens the shop, which prints SHOP-R41's line while
-- restricted (SET-R12).
---@return SettingsInitializer
local function shopRow()
	return ns.SettingsButtonRow({
		label = L.SETTINGS_SHOP_ROW,
		caption = L.SETTINGS_SHOP_BUTTON,
		onClick = function()
			HideUIPanel(SettingsPanel)
			Pagle.OpenShop()
		end,
	})
end

-- The Collection row (SET-R50 item 3), drawn by Core as the Curio Shop row is: pressing it closes the panel first, then
-- opens the Collection through the first On Module's def.collection (CORE-R45); left out when no On Module offers one.
---@return SettingsInitializer
local function collectionRow()
	return ns.SettingsButtonRow({
		label = L.SETTINGS_COLLECTION_ROW,
		caption = L.SETTINGS_COLLECTION_BUTTON,
		onClick = function()
			HideUIPanel(SettingsPanel)
			ns.OpenCollection()
		end,
	})
end

--- Builds Look and Feel (SET-R50) on its registered page, once, when Core registers its Settings (every enabled
--- Module has registered by then): the paragraph, a header and the slot dropdowns for each slot category with a slot
--- of Core or of a Module On, then "More looks" with the Collection row, when a Module On offers one, and the Curio
--- Shop row. Modules add no rows (CORE-R42).
---@param page SettingsCategory
---@param layout SettingsLayout
function ns.BuildLookAndFeel(page, layout)
	layout:AddInitializer(ns.SettingsTextRow(L.SETTINGS_LOOK_PARAGRAPH))
	for _, section in ipairs(ns.LookAndFeelSections(ns.goods)) do
		layout:AddInitializer(ns.CreateSettingsListSectionHeaderInitializer(L.SHOP_CATEGORIES[section.category]))
		for _, slot in ipairs(section.slots) do
			ns.SlotDropdown(page, layout, slot, "look")
		end
	end
	layout:AddInitializer(ns.CreateSettingsListSectionHeaderInitializer(L.SETTINGS_MORE_LOOKS))
	if ns.CollectionOffered() then
		layout:AddInitializer(collectionRow())
	end
	layout:AddInitializer(shopRow())
end
