---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Look and Feel page and the slot dropdowns (settings.md SET-R50–R53, SET-R30; CORE-R42; wallet-and-shop.md › UI).
-- A slot dropdown is the native dropdown over a proxy setting that reads Pagle.GetEquipped and writes
-- Pagle.SetEquipped, with "{N} more in the Curio Shop" drawn under it. adapter/Settings.lua registers the page and
-- calls ns.BuildLookAndFeel, and ends each Module's section on Trackers with ns.SlotDropdown (SET-R44);
-- adapter/AnnouncementSettings.lua ends Core's Announcements rows with it.
-- Its own owner on Core's bus.
local OWNER = "Pagle look and feel"
local L = ns.L

-- A slot dropdown's height while its note shows: the native row's 26 pixels, and the note's line under it.
local ROW_WITH_NOTE_HEIGHT = 46

-- Each slot's proxy settings, one per page it shows on, by slot ID: what AppearanceChanged redraws (SET-R51).
---@type table<string, SettingsProxySetting[]>
local settingsOf = {}
-- Every slot dropdown's proxy setting by its variable: a variable is registered once (Settings.RegisterProxySetting).
---@type table<string, SettingsProxySetting>
local registered = {}
-- The note under a slot dropdown, on a pooled dropdown row's frame. Weak, as the panel owns the frames.
---@type table<Frame, FontString>
local noteOf = setmetatable({}, { __mode = "k" })

-- The note's font string on `frame`, a dropdown row's, made the first time a slot dropdown draws on it, under the
-- dropdown.
---@param frame SettingsListElementFrame
---@return FontString
local function note(frame)
	local text = noteOf[frame]
	if not text then
		text = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		text:SetPoint("TOPLEFT", assert(frame.Control).Dropdown, "BOTTOMLEFT", 2, -2)
		text:SetJustifyH("LEFT")
		noteOf[frame] = text
	end
	return text
end

-- The slot's proxy setting on `page` under `variable`, registered the first time (SET-R51): its value is the
-- equipped good, picking one equips it, and its default, which the page's Defaults button restores, is the slot's
-- default good (SET-R60).
---@param page SettingsCategory
---@param slot PagleRegisteredSlot
---@param variable string
---@return SettingsProxySetting
local function slotSetting(page, slot, variable)
	local setting = registered[variable]
	if not setting then
		local slotID = slot.id
		setting = Settings.RegisterProxySetting(
			page,
			variable,
			Settings.VarType.String,
			slot.label,
			ns.goods:DefaultOf(slotID),
			function()
				return Pagle.GetEquipped(slotID)
			end,
			function(goodID)
				Pagle.SetEquipped(slotID, goodID)
			end
		)
		registered[variable] = setting
		settingsOf[slotID] = settingsOf[slotID] or {}
		table.insert(settingsOf[slotID], setting)
	end
	return setting
end

--- Adds a slot dropdown (SET-R51) to `page`, the same row on every page: labelled with the slot's label, found by it in
--- the settings search, never greyed out, its options the slot's owned goods read each time it opens, and under it
--- "{N} more in the Curio Shop" while N, the slot's for-sale goods not owned, is above 0, read each time it is drawn.
--- `variable` names its setting on that page.
---@param page SettingsCategory
---@param slot PagleRegisteredSlot
---@param variable string
---@return SettingsInitializer
function ns.SlotDropdown(page, slot, variable)
	local slotID = slot.id
	local initializer = Settings.CreateDropdown(page, slotSetting(page, slot, variable), function()
		local container = Settings.CreateControlTextContainer()
		for _, choice in ipairs(ns.SlotChoices(ns.goods, slotID)) do
			container:Add(choice.value, choice.label)
		end
		return container:GetData()
	end)
	initializer.GetExtent = function()
		return ns.SlotMoreInShop(ns.goods, slotID) > 0 and ROW_WITH_NOTE_HEIGHT or nil
	end
	local initFrame, resetter = initializer.InitFrame, initializer.Resetter
	initializer.InitFrame = function(self, frame)
		initFrame(self, frame)
		local more = ns.SlotMoreInShop(ns.goods, slotID)
		local text = note(frame)
		text:SetText(L.SETTINGS_SLOT_MORE:format(more))
		text:SetShown(more > 0)
	end
	initializer.Resetter = function(self, frame)
		note(frame):Hide()
		resetter(self, frame)
	end
	return initializer
end

-- A slot dropdown's value redraws at once wherever it shows when its look changes, whatever changed it (SET-R51,
-- SET-R62, SHOP-R33).
Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slotID)
	for _, setting in ipairs(settingsOf[slotID] or {}) do
		setting:NotifyUpdate()
	end
end)

-- The Curio Shop row (SET-R50 item 3): pressing it closes the panel first, as the shop would open behind it, then
-- opens the shop, which prints SHOP-R41's line while restricted (SET-R12).
---@return SettingsInitializer
local function shopRow()
	return CreateSettingsButtonInitializer(L.SETTINGS_SHOP_ROW, L.SETTINGS_SHOP_BUTTON, function()
		HideUIPanel(SettingsPanel)
		Pagle.OpenShop()
	end, nil, true)
end

--- Builds Look and Feel (SET-R50) on its registered page: the paragraph, a header and the slot dropdowns for each slot
--- category with a slot of Core or of a Module On, then the Curio Shop row. Modules add no rows (CORE-R42). The page
--- is built now, and built again whenever the Settings panel shows with slots registered since, so a late
--- registration appears; a slot's Defaults setting is registered once (SET-R52).
---@param page SettingsCategory
---@param layout SettingsLayout
function ns.BuildLookAndFeel(page, layout)
	local built
	local function build()
		local sections = ns.LookAndFeelSections(ns.goods)
		local count = 0
		for _, section in ipairs(sections) do
			count = count + #section.slots
		end
		if count == built then
			return
		end
		built = count
		local initializers = layout:GetInitializers()
		for i = #initializers, 1, -1 do
			initializers[i] = nil
		end
		layout:AddInitializer(ns.SettingsTextRow(L.SETTINGS_LOOK_PARAGRAPH))
		for _, section in ipairs(sections) do
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SHOP_CATEGORIES[section.category]))
			for _, slot in ipairs(section.slots) do
				ns.SlotDropdown(page, slot, "Pagle_Core_look_" .. slot.id)
			end
		end
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_SHOP))
		layout:AddInitializer(shopRow())
	end
	build()
	SettingsPanel:HookScript("OnShow", build)
end
