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
local OWNER = "Pagle settings"
local L = ns.L

-- The status list's row height and Core's text rows' height, in pixels.
local STATUS_ROW_HEIGHT = 26
local TEXT_ROW_HEIGHT = 26

-- The rows Modules add, until ModulesChanged (CORE-R42).
local rows = ns.NewSettingsRows()

---@type SettingsCategory? the root, once registered
local root
---@type table<string, SettingsCategory> the registered topic pages, by topic
local pages = {}

--- Core's own rows on a topic page, by topic, filled by the file that owns them (adapter/AnnouncementSettings.lua).
--- Each builds its rows on the page, before the Modules' rows (SET-R3); a topic Core has rows on is always
--- registered (SET-R1).
---@type table<string, fun(page: SettingsCategory, layout: SettingsLayout)>
ns.CoreSettingsRows = {}

---@class PagleModuleHandle
local ModuleHandle = ns.ModuleHandle

--- Adds a row to a topic page (CORE-R42): see ns.AddSettingMethod. A late call goes to `geterrorhandler()`.
ModuleHandle.AddSetting = ns.AddSettingMethod(ns.Modules, rows, function(problem)
	geterrorhandler()(problem)
end)

-- Each value row's native setting, by the Module's PagleSetting, once its page is built.
---@type table<PagleSetting, SettingsProxySetting>
local nativeOf = {}

--- Makes a value row's native control re-read `get`, and the rows under it their greying (CORE-R42): see
--- ns.RefreshSettingMethod. Nothing before the page is built, which reads `get` when shown. NotifyUpdate re-reads
--- the value and fires the setting's value-changed callback: the shown control re-reads (SettingsControlMixin:
--- OnSettingValueChanged) and each row under it re-evaluates its modify predicates (SettingsListElementMixin:
--- OnParentSettingValueChanged). Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
--- ("1.60.1 (70338)"), Blizzard_Settings_Shared/Blizzard_Setting.lua (SettingMixin:NotifyUpdate) and
--- Blizzard_SettingControls.lua.
ModuleHandle.RefreshSetting = ns.RefreshSettingMethod(ns.Modules, rows, function(_, setting)
	local native = nativeOf[setting]
	if native then
		securecallfunction(native.NotifyUpdate, native)
	end
end)

-- Core's own widgets on a pooled list frame, by frame. Weak, as the panel owns the frames.
---@type table<Frame, { text: FontString, status: { name: FontString, version: FontString, state: FontString, button: Button }[] }>
local widgetsOf = setmetatable({}, { __mode = "k" })

-- Lays out a font string at `x` in the status row at `y`.
---@param frame Frame
---@param x number
---@param y number
---@return FontString
local function fontString(frame, x, y)
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", x, y)
	text:SetJustifyH("LEFT")
	return text
end

-- Core's widgets on `frame`, all hidden, made the first time Core draws on it. The template's own label is hidden
-- until the frame is released (Resetter), since the panel reuses frames across rows.
---@param frame SettingsListElementFrame
local function widgets(frame)
	local own = widgetsOf[frame]
	if not own then
		local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 37, 0)
		text:SetPoint("RIGHT", -20, 0)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(true)
		own = { text = text, status = {} }
		for i = 1, #ns.MODULE_ROSTER do
			local y = -(i - 1) * STATUS_ROW_HEIGHT
			local row = { name = fontString(frame, 37, y), version = fontString(frame, 180, y) }
			row.state = fontString(frame, 250, y)
			row.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			row.button:SetPoint("TOPLEFT", 380, y + 3)
			row.button:SetSize(160, 22)
			own.status[i] = row
		end
		widgetsOf[frame] = own
	end
	own.text:Hide()
	for _, row in ipairs(own.status) do
		row.name:Hide()
		row.version:Hide()
		row.state:Hide()
		row.button:Hide()
	end
	if frame.Text then
		frame.Text:Hide()
	end
	return own
end

-- Gives a released frame back as the panel expects it: Core's widgets hidden, the template's label shown.
---@param frame SettingsListElementFrame
local function release(frame)
	widgets(frame)
	if frame.Text then
		frame.Text:Show()
	end
end

-- A row Core draws itself (SET-R5): `draw` fills it each time the panel shows it.
---@param extent number its height
---@param draw fun(frame: SettingsListElementFrame)
---@param searchLabel string? the label Blizzard's settings search finds it by; none for a paragraph or note
---@return SettingsInitializer
local function customRow(extent, draw, searchLabel)
	local initializer = Settings.CreateElementInitializer("SettingsListElementTemplate", {})
	initializer.GetExtent = function()
		return extent
	end
	initializer.InitFrame = function(_, frame)
		draw(frame)
	end
	initializer.Resetter = function(_, frame)
		release(frame)
	end
	if searchLabel then
		initializer:AddSearchTags(searchLabel)
	end
	return initializer
end

-- A paragraph or note (SET-R5, SET-R10).
---@param text string
---@return SettingsInitializer
local function textRow(text)
	return customRow(TEXT_ROW_HEIGHT, function(frame)
		local own = widgets(frame)
		own.text:SetText(text)
		own.text:Show()
	end)
end

--- Each roster Module's line in the status list, read now (CORE-R41, CORE-R44, SET-R11): its name, its TOC
--- version, its state and, while On, its button.
---@return { name: string, version: string, state: string, button: PagleStatusButton? }[]
local function statusLines()
	local registered = {}
	for _, module in ipairs(ns.Modules:Modules()) do
		registered[module.def.name] = module
	end
	local lines = {}
	for i, entry in ipairs(ns.ModuleStates()) do
		local module = registered[entry.name]
		lines[i] = {
			name = L.MODULE_NAMES[entry.name],
			version = C_AddOns.GetAddOnMetadata(ns.ModuleAddOn(entry.name), "Version") or "",
			state = L.MODULE_STATES[entry.state],
			button = module and ns.StatusButton(module.def, securecallfunction),
		}
	end
	return lines
end

-- Pressing a status button (SET-R12): a Module with a view closes the panel first; QoL's moves it to Fishing.
---@param button PagleStatusButton
local function press(button)
	if button.closesPanel then
		HideUIPanel(SettingsPanel)
	end
	button.onClick()
end

-- The status list (SET-R11). Its labels are read each time the root is shown (SET-R12).
---@return SettingsInitializer
local function statusList()
	return customRow(#ns.MODULE_ROSTER * STATUS_ROW_HEIGHT, function(frame)
		local own = widgets(frame)
		for i, line in ipairs(statusLines()) do
			local row = own.status[i]
			row.name:SetText(line.name)
			row.version:SetText(line.version)
			row.state:SetText(line.state)
			row.name:Show()
			row.version:Show()
			row.state:Show()
			local button = line.button
			if button then
				row.button:SetText(button.label)
				row.button:SetScript("OnClick", function()
					press(button)
				end)
				row.button:Show()
			end
		end
	end, L.SETTINGS_MODULES)
end

-- The root's rows (SET-R10): the paragraph while no Module is On, the status list under "Modules", the note, then
-- Saving's reminder checkbox, whose default the root's Defaults button restores (SET-R13).
---@param category SettingsCategory
---@param layout SettingsLayout
---@param anyModuleOn boolean
local function buildRoot(category, layout, anyModuleOn)
	if not anyModuleOn then
		layout:AddInitializer(textRow(L.SETTINGS_NO_MODULE))
	end
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_MODULES))
	layout:AddInitializer(statusList())
	layout:AddInitializer(textRow(L.SETTINGS_MODULES_NOTE))
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
-- the page shows (SET-R60, SET-R62).
---@param page SettingsCategory
---@param variable string
---@param varType string
---@param setting PagleSetting
---@return SettingsProxySetting
local function valueSetting(page, variable, varType, setting)
	local native =
		Settings.RegisterProxySetting(page, variable, varType, setting.label, setting.default, setting.get, setting.set)
	nativeOf[setting] = native
	return native
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

-- A topic page's rows (CORE-R42, SET-R2, SET-R3). A row that fails to build goes to geterrorhandler(); the rest
-- of the page is still built.
---@param topic string
---@param page SettingsCategory
---@param layout SettingsLayout
---@param entries PagleSettingsEntry[]
local function buildPage(topic, page, layout, entries)
	---@type table<PagleSettingsEntry, SettingsInitializer>
	local built = {}
	for i, entry in ipairs(entries) do
		local setting = entry.setting
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

-- Registers the root and every topic page that has rows, Core's or a Module's (CORE-R40, CORE-R42, SET-R1). Runs
-- once, outside restriction (CORE-R32).
local function register()
	local modules = ns.Modules:Modules()
	local category, layout = Settings.RegisterVerticalLayoutCategory(L.SETTINGS_CATEGORY)
	buildRoot(category, layout, #modules > 0)
	for _, topic in ipairs(ns.SETTINGS_TOPICS) do
		local entries = rows:Page(topic, modules)
		local coreRows = ns.CoreSettingsRows[topic]
		if coreRows or #entries > 0 then
			local page, pageLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.SETTINGS_PAGES[topic])
			if coreRows then
				coreRows(page, pageLayout)
			end
			buildPage(topic, page, pageLayout, entries)
			pages[topic] = page
		end
	end
	Settings.RegisterAddOnCategory(category)
	root = category
end

-- Every enabled Module has registered, so the rows are final: Core builds the tree, at once or, while restricted,
-- at RestrictionChanged(false) (CORE-R32, CORE-R42).
Pagle.RegisterCallback(OWNER, "ModulesChanged", function()
	rows:Close()
	ns.RunWhenUnrestricted(register)
end)

--- Opens Settings at the root, or at the topic page `topic`: `"fishing"`, `"announcements"`, `"trackers"` or
--- `"look"` (CORE-R43). An unknown topic, or one whose page isn't registered, opens the root. While restricted it
--- prints "Pagle: settings open after combat." instead (CORE-R33).
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
