---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's Settings category (CORE-R40–R44): the root with the Module status list, and the topic pages built from the
-- rows Modules add with M:AddSetting. Layout and texts: docs/spec/settings.md. Its own owner on Core's bus.
--
-- Core only builds the tree through Blizzard's public Settings API and hands it data and callbacks; it never writes a
-- field onto anything Blizzard's Settings code made or reads, and never calls into a setting, control, the list or the
-- panel itself (SET-R6, #246). Blizzard's code runs the callbacks under securecallfunction, but a field Core wrote,
-- or Blizzard's code run from Core's, taints the Settings list, and a Blizzard row drawn after it (Audio's Discord
-- checkbox) then calls a protected function as Pagle's (ADDON_ACTION_FORBIDDEN).
local OWNER = "Pagle settings"
local L = ns.L

-- The rows Modules add, until ModulesChanged (CORE-R42).
local rows = ns.NewSettingsRows()

---@type SettingsCategory? the root, once registered
local root
---@type table<string, SettingsCategory> the registered topic pages, by topic
local pages = {}

--- Core's own rows on a topic page, by topic, filled by the file that owns them (adapter/AnnouncementSettings.lua,
--- adapter/Dock.lua). Each builds its rows on the page, before the Modules' rows (SET-R3); whether they register the
--- page alone is ns.IsPageRegistered's (SET-R1).
---@type table<string, fun(page: SettingsCategory, layout: SettingsLayout)>
ns.CoreSettingsRows = {}

---@class PagleModuleHandle
local ModuleHandle = ns.ModuleHandle

--- Adds a row to a topic page (CORE-R42): see ns.AddSettingMethod. A late call goes to `geterrorhandler()`.
ModuleHandle.AddSetting = ns.AddSettingMethod(ns.Modules, rows, function(problem)
	geterrorhandler()(problem)
end)

-- The template of the rows Core draws itself (adapter/Settings.xml), 26 pixels high.
local ROW_TEMPLATE = "PagleSettingsRowTemplate"

-- Core's widgets on one of its own row frames, by frame. Weak, as the panel owns the frames.
---@type table<Frame, { text: FontString, name: FontString, version: FontString, state: FontString, button: Button }>
local widgetsOf = setmetatable({}, { __mode = "k" })

-- Lays out a font string at `x` in a status row.
---@param frame Frame
---@param x number
---@return FontString
local function fontString(frame, x)
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", x, 0)
	text:SetJustifyH("LEFT")
	return text
end

-- Core's widgets on `frame`, all hidden, made the first time Core draws on it.
---@param frame Frame
local function widgets(frame)
	local own = widgetsOf[frame]
	if not own then
		local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 37, 0)
		text:SetPoint("RIGHT", -20, 0)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(true)
		own = { text = text, name = fontString(frame, 37), version = fontString(frame, 180) }
		own.state = fontString(frame, 250)
		own.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
		own.button:SetPoint("TOPLEFT", 380, 3)
		own.button:SetSize(160, 22)
		widgetsOf[frame] = own
	end
	own.text:Hide()
	own.name:Hide()
	own.version:Hide()
	own.state:Hide()
	own.button:Hide()
	return own
end

--- The mixin of Core's own row frames (adapter/Settings.xml, SET-R5, SET-R6). The panel's list draws such a row
--- through Blizzard's stock InitFrame, which calls the frame's Init, and releases it through the stock Resetter,
--- which calls its Release, each under securecallfunction. Its frames are Core's alone: their template has its own
--- pool in the list.
---@class PagleSettingsRowMixin : Frame
PagleSettingsRowMixin = {}

--- Draws the row with the `draw` Core put in its initializer's data.
---@param initializer SettingsInitializer
function PagleSettingsRowMixin:Init(initializer)
	initializer:GetData().draw(self)
end

--- Hides Core's widgets, so the frame comes back empty for the next row.
function PagleSettingsRowMixin:Release()
	widgets(self)
end

-- A row Core draws itself (SET-R5): `draw` fills it each time the panel shows it.
---@param draw fun(frame: Frame)
---@param searchLabel string? the label Blizzard's settings search finds it by; none for a paragraph or note
---@return SettingsInitializer
local function customRow(draw, searchLabel)
	local initializer = Settings.CreateElementInitializer(ROW_TEMPLATE, { draw = draw })
	if searchLabel then
		initializer:AddSearchTags(searchLabel)
	end
	return initializer
end

--- A paragraph or note (SET-R5, SET-R10, SET-R50): a row Core draws itself, with no search label.
---@param text string
---@return SettingsInitializer
local function textRow(text)
	return customRow(function(frame)
		local own = widgets(frame)
		own.text:SetText(text)
		own.text:Show()
	end)
end
ns.SettingsTextRow = textRow

--- The status list's line for the roster Module at `index`, read now (CORE-R41, CORE-R44, SET-R11): its name, its
--- TOC version, its state and, while On, its button.
---@param index integer
---@return { name: string, version: string, state: string, button: PagleStatusButton? }
local function statusLine(index)
	local entry = ns.ModuleStates()[index]
	local module
	for _, registered in ipairs(ns.Modules:Modules()) do
		if registered.def.name == entry.name then
			module = registered
		end
	end
	return {
		name = L.MODULE_NAMES[entry.name],
		version = C_AddOns.GetAddOnMetadata(ns.ModuleAddOn(entry.name), "Version") or "",
		state = L.MODULE_STATES[entry.state],
		button = module and ns.StatusButton(module.def, securecallfunction),
	}
end

-- Pressing a status button (SET-R12): a Module with a view closes the panel first; QoL's moves it to Fishing.
-- HideUIPanel closes it through Blizzard's own secure path (UIParentPanelManager's forbidden delegate).
---@param button PagleStatusButton
local function press(button)
	if button.closesPanel then
		HideUIPanel(SettingsPanel)
	end
	button.onClick()
end

-- The status list (SET-R11): a row per roster Module, in roster order, each read each time it is shown (SET-R12)
-- and found by the list's search label.
---@return SettingsInitializer[]
local function statusList()
	local list = {}
	for index = 1, #ns.MODULE_ROSTER do
		list[index] = customRow(function(frame)
			local own = widgets(frame)
			local line = statusLine(index)
			own.name:SetText(line.name)
			own.version:SetText(line.version)
			own.state:SetText(line.state)
			own.name:Show()
			own.version:Show()
			own.state:Show()
			local button = line.button
			if button then
				own.button:SetText(button.label)
				own.button:SetScript("OnClick", function()
					press(button)
				end)
				own.button:Show()
			end
		end, L.SETTINGS_MODULES)
	end
	return list
end

-- The Field report row (CORE-R40, SET-R10 row 4): "Field report" with the button "Open Field report", "Open Field
-- report (3)" while the count is above 0. The native button control calls a function caption each time the row is
-- shown, so the count is read then (SET-R12). Its search tags are added here, as the native ones take strings only.
-- Pressing it closes the panel first, since the box would open behind it; while restricted Pagle.OpenFieldReport then
-- prints REP-R44's line (SET-R12).
---@return SettingsInitializer
local function fieldReportRow()
	local initializer = CreateSettingsButtonInitializer(L.SETTINGS_FIELD_REPORT_ROW, function()
		return ns.FieldReportButtonText(Pagle.GetFieldReportCount())
	end, function()
		HideUIPanel(SettingsPanel)
		Pagle.OpenFieldReport()
	end, L.SETTINGS_FIELD_REPORT_TOOLTIP, false)
	initializer:AddSearchTags(L.SETTINGS_FIELD_REPORT_ROW, L.SETTINGS_FIELD_REPORT_BUTTON)
	return initializer
end

-- The Units section (CORE-R40, SET-R10 row 6): the length unit's dropdown, showing the unit in use (LOG-R69). Its
-- default, which the root's Defaults button restores (SET-R13), is the region's unit, and picking the region's unit
-- stores none: so Defaults leaves PagleDB.profile.lengthUnit nil, following the region.
---@param category SettingsCategory
---@param layout SettingsLayout
local function unitsSection(category, layout)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_UNITS))
	local regionUnit = ns.LengthUnitOf(nil, ns.host.region())
	local lengthUnit = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_lengthUnit",
		Settings.VarType.String,
		L.SETTINGS_LENGTH_UNIT,
		regionUnit,
		ns.LengthUnit,
		function(value)
			ns.db.profile.lengthUnit = value ~= regionUnit and value or nil
		end
	)
	Settings.CreateDropdown(category, lengthUnit, function()
		local container = Settings.CreateControlTextContainer()
		for _, unit in ipairs(ns.LENGTH_UNITS) do
			container:Add(unit, L.SETTINGS_LENGTH_UNITS[unit])
		end
		return container:GetData()
	end, L.SETTINGS_LENGTH_UNIT_TOOLTIP)
end

-- The root's rows (SET-R10): the paragraph while no Module is On, the status list under "Modules", the note, the
-- Field report section, then Saving's reminder checkbox and the Units section, whose defaults the root's Defaults
-- button restores (SET-R13).
---@param category SettingsCategory
---@param layout SettingsLayout
---@param anyModuleOn boolean
local function buildRoot(category, layout, anyModuleOn)
	if not anyModuleOn then
		layout:AddInitializer(textRow(L.SETTINGS_NO_MODULE))
	end
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_MODULES))
	for _, line in ipairs(statusList()) do
		layout:AddInitializer(line)
	end
	layout:AddInitializer(textRow(L.SETTINGS_MODULES_NOTE))
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.HELP_CHART))
	layout:AddInitializer(fieldReportRow())
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_SAVING))
	local reminder = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_reloadReminder",
		Settings.VarType.Boolean,
		L.SETTINGS_RELOAD_REMINDER,
		false,
		function()
			return ns.db.profile.reloadReminder
		end,
		function(value)
			ns.db.profile.reloadReminder = value
		end
	)
	Settings.CreateCheckbox(category, reminder, L.SETTINGS_RELOAD_REMINDER_TOOLTIP:format(ns.RELOAD_REMINDER_STEP))
	unitsSection(category, layout)
end

-- A dropdown's options as the native control takes them, read each time it opens.
---@param setting PagleSetting
---@return fun(): table[]
local function dropdownOptions(setting)
	return function()
		local container = Settings.CreateControlTextContainer()
		for _, option in ipairs(setting.options()) do
			container:Add(option.value, option.label)
		end
		return container:GetData()
	end
end

-- A value row's native setting: Blizzard's Defaults button restores `default`, and the panel reads `get` each time
-- the row is drawn and after each change through the row (SET-R60, SET-R62).
---@param page SettingsCategory
---@param variable string
---@param varType string
---@param setting PagleSetting
---@return SettingsProxySetting
local function valueSetting(page, variable, varType, setting)
	return Settings.RegisterProxySetting(
		page,
		variable,
		varType,
		setting.label,
		setting.default,
		setting.get,
		setting.set
	)
end

-- One Module row as a native initializer on `page` (SET-R5).
---@param page SettingsCategory
---@param layout SettingsLayout
---@param setting PagleSetting
---@param variable string a variable name no other row uses
---@return SettingsInitializer
local function nativeRow(page, layout, setting, variable)
	local kind = setting.kind
	if kind == "checkbox" then
		return Settings.CreateCheckbox(
			page,
			valueSetting(page, variable, Settings.VarType.Boolean, setting),
			setting.tooltip
		)
	elseif kind == "slider" then
		local options = Settings.CreateSliderOptions(setting.min, setting.max, setting.step)
		return Settings.CreateSlider(
			page,
			valueSetting(page, variable, Settings.VarType.Number, setting),
			options,
			setting.tooltip
		)
	elseif kind == "dropdown" then
		local value = setting.default
		if value == nil then
			value = setting.get()
		end
		return Settings.CreateDropdown(
			page,
			valueSetting(page, variable, type(value), setting),
			dropdownOptions(setting),
			setting.tooltip
		)
	end
	local initializer
	if kind == "header" then
		initializer = CreateSettingsListSectionHeaderInitializer(setting.label, setting.tooltip)
	elseif kind == "button" then
		-- A button row's label sits beside the button and its caption is on it. Without a caption, the label is the
		-- caption and the row has no label (SET-R2).
		if setting.caption then
			initializer =
				CreateSettingsButtonInitializer(setting.label, setting.caption, setting.onClick, setting.tooltip, true)
		else
			initializer = CreateSettingsButtonInitializer("", setting.label, setting.onClick, setting.tooltip, true)
		end
	elseif kind == "keybinding" then
		local index = C_KeyBindings.GetBindingIndex(setting.binding)
		if not index then
			error(("Pagle: no key binding %s for the setting %s"):format(setting.binding, setting.label))
		end
		-- The native row takes only the binding index and a search flag, and shows the binding's own name
		-- (GetBindingName) with no tooltip: Blizzard_Keybindings.lua at the forever 1.60.1 commit (types/settings.lua).
		-- So `setting.label` serves as a search tag only, and `setting.tooltip` isn't shown (SET-R20).
		initializer = CreateKeybindingEntryInitializer(index, true)
		initializer:AddSearchTags(setting.label)
	else
		initializer = setting.init()
	end
	layout:AddInitializer(initializer)
	return initializer
end

-- A topic page's rows (CORE-R42, SET-R2, SET-R3, SET-R44). A Module row that fails to build goes to
-- geterrorhandler(); the rest of the page is still built. A slot row ending a Module's section is Core's: the same
-- slot dropdown as on Look and Feel, with no parent and never greyed out, which the page's Defaults button restores to
-- the slot's default good (SET-R44, SET-R45, SET-R51).
---@param topic string
---@param page SettingsCategory
---@param layout SettingsLayout
---@param entries PagleSettingsEntry[]
local function buildPage(topic, page, layout, entries)
	---@type table<PagleSettingsEntry, SettingsInitializer>
	local built = {}
	for i, entry in ipairs(entries) do
		local setting = entry.setting
		if entry.slot then
			ns.SlotDropdown(page, layout, entry.slot, topic)
		elseif setting then
			local variable = ("Pagle_%s_%s_%d"):format(entry.module.def.name, topic, i)
			local initializer = securecallfunction(nativeRow, page, layout, setting, variable)
			if initializer then
				built[entry] = initializer
				local parent = entry.parent and built[entry.parent]
				if parent then
					initializer:SetParentInitializer(parent)
				end
				if setting.isEnabled then
					initializer:AddModifyPredicate(setting.isEnabled)
				end
			end
		end
	end
end

-- The root and each page registered, in the panel's order, as Core's tour stops (CORE-R68): each opens through
-- Pagle.OpenSettings, and its hide closes the panel through Blizzard's own path (HideUIPanel, SET-R12).
local function addTourStops()
	local topics = { false } ---@type (string|false)[]
	for _, topic in ipairs(ns.SETTINGS_TOPICS) do
		if pages[topic] then
			topics[#topics + 1] = topic
		end
	end
	topics[#topics + 1] = "look"
	for _, topic in ipairs(topics) do
		local id = topic and "settings." .. topic or "settings"
		local label = L.DEV_TOUR_SETTINGS:format(topic and L.SETTINGS_PAGES[topic] or L.SETTINGS_CATEGORY)
		ns.tourStops:Add(ns.TOUR_CORE, id, label, function()
			Pagle.OpenSettings(topic or nil)
		end, function()
			HideUIPanel(SettingsPanel)
		end)
	end
end

-- Registers the root and every topic page that has rows, Core's or a Module's (CORE-R40, CORE-R42, SET-R1). Runs
-- once, outside restriction (CORE-R32).
local function register()
	local modules = ns.Modules:Modules()
	local category, layout = Settings.RegisterVerticalLayoutCategory(L.SETTINGS_CATEGORY)
	buildRoot(category, layout, #modules > 0)
	for _, topic in ipairs(ns.SETTINGS_TOPICS) do
		local entries = rows:Page(topic, modules, ns.SectionSlots(ns.goods, topic))
		local coreRows = ns.CoreSettingsRows[topic]
		if ns.IsPageRegistered(topic, coreRows ~= nil, #entries) then
			local page, pageLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.SETTINGS_PAGES[topic])
			if coreRows then
				coreRows(page, pageLayout)
			end
			buildPage(topic, page, pageLayout, entries)
			pages[topic] = page
		end
	end
	-- Look and Feel, the last topic page, always registered from M4: Core builds it from the goods registry and takes
	-- no rows for it (SET-R1, SET-R50, CORE-R42).
	local look, lookLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.SETTINGS_PAGES.look)
	ns.BuildLookAndFeel(look, lookLayout)
	pages.look = look
	Settings.RegisterAddOnCategory(category)
	root = category
	addTourStops()
end

-- Every enabled Module has registered, so the rows are final: Core builds the tree, at once or, while restricted,
-- at RestrictionChanged(false) (CORE-R32, CORE-R42).
Pagle.RegisterCallback(OWNER, "ModulesChanged", function()
	rows:Close()
	ns.RunWhenUnrestricted(register)
end)

--- Opens Settings at the root, or at the topic page `topic`: `"fishing"`, `"announcements"`, `"trackers"` or
--- `"look"` (CORE-R43). An unknown topic, or one whose page isn't registered, opens the root. While restricted it
--- prints "Pagle: settings open after combat." instead (CORE-R33). Settings.OpenToCategory opens the panel through
--- the client's SETTINGS_PANEL_OPEN event, Blizzard's own secure path (SET-R6).
---@param topic string?
function Pagle.OpenSettings(topic)
	if Pagle.IsRestricted() then
		print(L.SETTINGS_AFTER_COMBAT)
		return
	end
	local category = (topic and pages[topic]) or root
	if category then
		Settings.OpenToCategory(category:GetID())
	end
end
