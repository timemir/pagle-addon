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
---@type table<Frame, { text: FontString, name: FontString, version: FontString, state: FontString, button: Button, check: CheckButton, line: FontString }>
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

-- Where a row's label starts (the status list's name column), and where Getting started's checkbox and line sit
-- after it at the least (SET-R10 rows 4–6): a longer label pushes them right, measured, so none draws over it.
local NAME_X, CHECK_X = 37, 150
-- The gap between a row's label, checkbox, line and button, and the checkbox's width.
local GAP, CHECK_W = 8, 26
-- The least width of the Field guide row's line, between its label and its button: a longer label or caption (a
-- longer language's, CORE-R8) cuts the label short before the line goes under this, so the line never shrinks to "…".
local LINE_MIN = 120
-- Where a row's button ends, and its least width: a longer caption widens it leftwards, measured, so its words stay
-- on it (SET-R11).
local BUTTON_RIGHT, BUTTON_W, BUTTON_PAD = 540, 160, 24
-- Where a native row's control starts, from the row's top centre, and a native button's width: a Module's button row
-- with no caption, drawn by Core, starts there and is never narrower.
local CONTROL_X, NATIVE_BUTTON_W = -40, 200
-- The room a button has from there (#593): to 10 short of the row's right edge, as Blizzard's right-aligned buttons
-- end, since the list clips what passes it. A row is 635 wide: the panel's 920, less its category list (199 at 18)
-- and the container's 16 and 22 beside it, the scroll box 15 wider on the left and 20 short on the right, and the
-- rows padded 25 on the left (Blizzard_SettingsPanel.xml, Blizzard_SettingsList.xml and .lua at the forever 1.60.1
-- commit). The panel isn't resizable; a frame's own width can't be read instead, as the list may draw a row before it
-- lays the frame out at the row's width.
local ROW_W = 635
local CONTROL_ROOM = ROW_W / 2 - CONTROL_X - 10
-- A button's faces, its state's each: the template's, and the small ones a caption too wide for its room is set in.
local BUTTON_FACES = { normal = "GameFontNormal", highlight = "GameFontHighlight", disabled = "GameFontDisable" }
local SMALL_FACES = {
	normal = "GameFontNormalSmall",
	highlight = "GameFontHighlightSmall",
	disabled = "GameFontDisableSmall",
}

-- The status list's version and state columns (SET-R11).
local VERSION_X, STATE_X = 180, 250

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
		own = { text = text, name = fontString(frame, NAME_X), version = fontString(frame, VERSION_X) }
		-- One line that ends 6 pixels short of the state, cut with "..." by the client: unbounded, a long version
		-- ran under the state ("On" drawn over "@project-version@", SET-R11).
		own.version:SetWidth(STATE_X - VERSION_X - 6)
		own.version:SetWordWrap(false)
		own.state = fontString(frame, STATE_X)
		own.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
		own.button:SetSize(BUTTON_W, 22)
		own.button:GetFontString():SetWordWrap(false)
		-- Getting started's checkbox and line (SET-R10 rows 4–6)
		own.check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate") --[[@as CheckButton]]
		own.check:SetSize(CHECK_W, CHECK_W)
		own.line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		own.line:SetJustifyH("LEFT")
		widgetsOf[frame] = own
	end
	own.text:Hide()
	own.name:Hide()
	own.name:SetWidth(0) -- a Getting started row may have cut its label short (rowLabel)
	own.name:SetFontObject("GameFontHighlight") -- the Field report row's is a native row's
	own.version:Hide()
	own.state:Hide()
	own.button:Hide()
	own.button:SetScript("OnClick", nil)
	own.button:SetScript("OnEnter", nil)
	own.button:SetScript("OnLeave", nil)
	-- a button row may have set its caption small or cut it (controlButton)
	own.button:SetNormalFontObject(BUTTON_FACES.normal)
	own.button:SetHighlightFontObject(BUTTON_FACES.highlight)
	own.button:SetDisabledFontObject(BUTTON_FACES.disabled)
	own.button:GetFontString():SetWidth(0)
	own.check:Hide()
	own.check:SetScript("OnClick", nil)
	own.line:Hide()
	frame:SetScript("OnEnter", nil)
	frame:SetScript("OnLeave", nil)
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

-- A row's label, at the status list's name column, on one line. Returns where its words end, measured; with `room`,
-- held to that much, cut short by the client past it.
---@param own table
---@param label string
---@param room number?
---@return number
local function rowLabel(own, label, room)
	own.name:SetWidth(0) -- measured unbounded
	own.name:SetWordWrap(false)
	own.name:SetText(label)
	own.name:Show()
	local width = own.name:GetStringWidth()
	if room and width > room then
		width = math.max(1, room)
		own.name:SetWidth(width)
	end
	return NAME_X + width
end

-- A row's line, at `x`, wrapping within `width` when given (it then sits before a button), else one line.
---@param own table
---@param x number
---@param text string
---@param width number?
local function rowLine(own, x, text, width)
	own.line:ClearAllPoints()
	own.line:SetPoint("TOPLEFT", x, -1)
	own.line:SetWordWrap(width ~= nil)
	own.line:SetMaxLines(width and 2 or 0) -- two lines fill the row
	own.line:SetWidth(width or 0)
	own.line:SetText(text)
	own.line:Show()
end

-- A row's button, ending at the status list's button column's right edge, as wide as its caption needs and never
-- narrower than BUTTON_W. Returns its left edge.
---@param own table
---@param caption string
---@param onClick fun()
---@return number
local function rowButton(own, caption, onClick)
	local button = own.button
	button:SetText(caption)
	local width = math.max(BUTTON_W, math.ceil(button:GetTextWidth()) + BUTTON_PAD)
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", button:GetParent(), "TOPLEFT", BUTTON_RIGHT, 3)
	button:SetWidth(width)
	button:SetEnabled(true)
	button:SetScript("OnClick", onClick)
	button:Show()
	return BUTTON_RIGHT - width
end

-- A row's button where a native row's control starts, as a native button row draws it (SET-R5, #593): as wide as its
-- caption needs and never narrower than a native button, within CONTROL_ROOM. A caption too wide for that is set in
-- the small faces, and one too wide even so is cut by the client with "...", so nothing passes the row's right edge,
-- where the list clips it.
---@param own table
---@param frame Frame
---@param caption string
---@param onClick fun()
local function controlButton(own, frame, caption, onClick)
	local button = own.button
	button:SetText(caption)
	local width = math.ceil(button:GetTextWidth()) + BUTTON_PAD
	if width > CONTROL_ROOM then
		button:SetNormalFontObject(SMALL_FACES.normal)
		button:SetHighlightFontObject(SMALL_FACES.highlight)
		button:SetDisabledFontObject(SMALL_FACES.disabled)
		width = math.ceil(button:GetTextWidth()) + BUTTON_PAD
		if width > CONTROL_ROOM then
			width = CONTROL_ROOM
			button:GetFontString():SetWidth(width - BUTTON_PAD)
		end
	end
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", frame, "TOP", CONTROL_X, 3)
	button:SetWidth(math.max(NATIVE_BUTTON_W, width))
	button:SetScript("OnClick", onClick)
	button:Show()
end

-- Where Getting started's checkboxes sit: CHECK_X, or `GAP` past the longer of the checkbox rows' labels, measured
-- on `own`'s label, so a long label pushes both and they stay in one column (SET-R10 rows 5 and 6). The First evening
-- list's label counts only while its row is offered (`evening`), so it never pushes Margin notes' alone.
---@param own table
---@param evening boolean
---@return number
local function checkColumn(own, evening)
	local widest = rowLabel(own, L.SETTINGS_MARGIN_NOTES)
	if evening then
		widest = math.max(widest, rowLabel(own, L.SETTINGS_EVENING))
	end
	return math.max(CHECK_X, widest + GAP)
end

-- A row's checkbox, `checked` as it is now, at `x`; a click hands `onClick` the state it toggled to. Returns its right
-- edge.
---@param own table
---@param x number
---@param checked boolean
---@param onClick fun(checked: boolean)
---@return number
local function rowCheck(own, x, checked, onClick)
	own.check:ClearAllPoints()
	own.check:SetPoint("TOPLEFT", x, 5)
	own.check:SetChecked(checked)
	own.check:SetScript("OnClick", function(check)
		onClick(check:GetChecked() == true)
	end)
	own.check:Show()
	return x + CHECK_W
end

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
	-- "dev" for the packager's unfilled token, none when not installed (CORE-R41).
	local version = C_AddOns.GetAddOnMetadata(ns.ModuleAddOn(entry.name), "Version")
	return {
		name = L.MODULE_NAMES[entry.name],
		version = ns.ShownVersion(version, L.MODULE_VERSION_DEV) or "",
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
				rowButton(own, button.label, function()
					press(button)
				end)
			end
		end, L.SETTINGS_MODULES)
	end
	return list
end

--- A button row Core draws, as ns.SettingsButtonRow takes it.
---@class PagleSettingsButtonRow
---@field label string
---@field caption string|fun(): string
---@field search string? the caption the search finds it by, when `caption` is a function
---@field tooltip string?
---@field onClick fun()

--- A button row Core draws itself as a native button row looks (SET-R5), since a native button is a fixed 200 wide and
--- a longer caption ran past both its sides (#593, #606): the label in the native face, cut short before the button,
--- and the button as controlButton draws it, its caption read each time the row is drawn when it is a function
--- (SET-R12). Over the row and its button, the label and the tooltip's line, as a native button row shows them (the
--- label alone with no tooltip). Named by its label, with its tooltip, as a native row is, for the tree's readers; the
--- search finds it by its label and `search`, its caption when that is a string.
---@param row PagleSettingsButtonRow
---@return SettingsInitializer
local function buttonRow(row)
	local function draw(frame)
		local own = widgets(frame)
		own.name:SetFontObject("GameFontNormal")
		rowLabel(own, row.label, ROW_W / 2 + CONTROL_X - GAP - NAME_X)
		local caption = row.caption
		controlButton(own, frame, type(caption) == "function" and caption() or caption --[[@as string]], row.onClick)
		own.button:SetEnabled(true)
		local function showTooltip(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip:SetText(row.label)
			if row.tooltip then
				GameTooltip:AddLine(row.tooltip, 1, 1, 1, true)
			end
			GameTooltip:Show()
		end
		local function hideTooltip()
			GameTooltip:Hide()
		end
		for _, region in ipairs({ frame, own.button }) do
			region:SetScript("OnEnter", showTooltip)
			region:SetScript("OnLeave", hideTooltip)
		end
	end
	local initializer =
		Settings.CreateElementInitializer(ROW_TEMPLATE, { draw = draw, name = row.label, tooltip = row.tooltip })
	initializer:AddSearchTags(row.label, row.search or row.caption)
	return initializer
end
ns.SettingsButtonRow = buttonRow

-- The Field report row (CORE-R40, SET-R10 row 7): "Field report" with the button "Open Field report", "Open Field
-- report (3)" while the count is above 0, read each time the row is drawn (SET-R12), drawn by Core (buttonRow, #593).
-- Its tooltip is SET-R10's. Pressing it closes the panel first, since the box would open behind it; while restricted
-- Pagle.OpenFieldReport then prints REP-R44's line (SET-R12).
---@return SettingsInitializer
local function fieldReportRow()
	return buttonRow({
		label = L.SETTINGS_FIELD_REPORT_ROW,
		caption = function()
			return ns.FieldReportButtonText(Pagle.GetFieldReportCount())
		end,
		search = L.SETTINGS_FIELD_REPORT_BUTTON,
		tooltip = L.SETTINGS_FIELD_REPORT_TOOLTIP,
		onClick = function()
			HideUIPanel(SettingsPanel)
			Pagle.OpenFieldReport()
		end,
	})
end

-- The Units section (CORE-R40, SET-R10 row 9): the length unit's dropdown, showing the unit in use (LOG-R69), then
-- the Clock row (adapter/Clock.lua) and the Language row (adapter/LanguageRow.lua). The length unit's default, which
-- the root's Defaults button restores (SET-R13), is the region's unit, and picking the region's unit stores none: so
-- Defaults leaves PagleDB.profile.lengthUnit nil, following the region.
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
	ns.ClockRow(category)
	ns.LanguageRow(category)
end

-- The Pagle menu section (CORE-R40, SET-R10 rows 10–10c): Show the minimap icon, on unless
-- PagleDB.global.minimap.hide (CORE-R56), and under it its children: from 1.5, Detach from the minimap
-- (PagleDB.global.minimap.detached, CORE-R53), and from 1.5.1 the button's style and size (`style` and `scale`), each
-- greyed while the icon is hidden as the Announcements page greys a row whose parent is off (SET-R31), keeping its
-- value. None has a default, so the root's Defaults button leaves them, restoring only the reminder, the length unit
-- and the Clock (SET-R13): where the icon is, whether it shows and how it looks are the player's account-wide
-- choices, not a profile's.
---@param category SettingsCategory
---@param layout SettingsLayout
local function pagleMenuSection(category, layout)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_PAGLE_MENU))
	local shown = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_minimapIcon",
		Settings.VarType.Boolean,
		L.SETTINGS_MINIMAP_ICON,
		nil,
		ns.IsMinimapIconShown,
		ns.SetMinimapIconShown
	)
	local shownRow = Settings.CreateCheckbox(category, shown, L.SETTINGS_MINIMAP_ICON_TOOLTIP)
	local detached = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_minimapDetach",
		Settings.VarType.Boolean,
		L.SETTINGS_MINIMAP_DETACH,
		nil,
		ns.IsMinimapIconDetached,
		ns.SetMinimapIconDetached
	)
	local detachRow = Settings.CreateCheckbox(category, detached, L.SETTINGS_MINIMAP_DETACH_TOOLTIP)
	-- From 1.5.1, the button's style and its size (CORE-R53), its last two children: a dropdown of the styles and a
	-- native slider showing its value on the right, as Game › Sound's do (SET-R5).
	local style = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_minimapStyle",
		Settings.VarType.String,
		L.SETTINGS_MINIMAP_STYLE,
		nil,
		ns.MinimapIconStyle,
		ns.SetMinimapIconStyle
	)
	local styleRow = Settings.CreateDropdown(category, style, function()
		local container = Settings.CreateControlTextContainer()
		for _, choice in ipairs(ns.MINIMAP_ICON_STYLES) do
			container:Add(choice, L.SETTINGS_MINIMAP_STYLES[choice])
		end
		return container:GetData()
	end, L.SETTINGS_MINIMAP_STYLE_TOOLTIP)
	local size = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_minimapSize",
		Settings.VarType.Number,
		L.SETTINGS_MINIMAP_SIZE,
		nil,
		ns.MinimapIconSize,
		ns.SetMinimapIconSize
	)
	local sizeOptions =
		Settings.CreateSliderOptions(ns.MINIMAP_ICON_SIZE_MIN, ns.MINIMAP_ICON_SIZE_MAX, ns.MINIMAP_ICON_SIZE_STEP)
	sizeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return ns.RenderText(L.SETTINGS_MINIMAP_SIZE_VALUE, { value = value })
	end)
	local sizeRow = Settings.CreateSlider(category, size, sizeOptions, L.SETTINGS_MINIMAP_SIZE_TOOLTIP)
	for _, row in ipairs({ detachRow, styleRow, sizeRow }) do
		row:SetParentInitializer(shownRow)
		row:AddModifyPredicate(ns.IsMinimapIconShown)
		row:AddEvaluateStateCVar("Pagle_Core_minimapIcon")
	end
end

-- The Pagle website section (SET-R10 row 11, VIEW-R30): Show other Anglers on player tooltips, bound to
-- PagleDB.profile.anglerTooltips, on by default (logic/Migrations.lua). Off, there's no Pagle block and Pagle_Anglers
-- never loads; turned on mid-session, the next hover outside restriction loads it (adapter/AnglersInGame.lua, VIEW-R3).
-- Like Show the minimap icon it has no default: the root's Defaults button restores only the reminder and the length
-- unit (SET-R13).
---@param category SettingsCategory
---@param layout SettingsLayout
local function pagleWebsiteSection(category, layout)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_PAGLE_WEBSITE))
	local tooltips = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_anglerTooltips",
		Settings.VarType.Boolean,
		L.SETTINGS_ANGLER_TOOLTIPS,
		nil,
		function()
			return ns.db.profile.anglerTooltips == true
		end,
		function(value)
			ns.db.profile.anglerTooltips = value
		end
	)
	Settings.CreateCheckbox(category, tooltips, L.SETTINGS_ANGLER_TOOLTIPS_TOOLTIP)
	-- SET-R10 row 12 (PST-R50): "Catch log" with the button "Copy for the website", which opens the export window,
	-- drawn by Core (buttonRow, #606). Pressing it closes the panel first, since the window would open behind it;
	-- while restricted Pagle.OpenPasteExport then prints its line (SET-R12).
	layout:AddInitializer(buttonRow({
		label = L.SETTINGS_PASTE_ROW,
		caption = L.SETTINGS_PASTE_BUTTON,
		tooltip = L.SETTINGS_PASTE_TOOLTIP,
		onClick = function()
			HideUIPanel(SettingsPanel)
			Pagle.OpenPasteExport()
		end,
	}))
	-- SET-R10 row 13: the Translations line, only while a listed language the client can render has translators.
	local credits = ns.TranslatorCredits(GetLocale())
	if credits then
		layout:AddInitializer(textRow(credits))
	end
end

-- The Getting started section (CORE-R40, SET-R10 rows 4–6, ONB-R81), Core's own rows, drawn by Core on its frames
-- (SET-R5, SET-R6): "Field guide" with its line and Show me around again, which closes the panel as the status list's
-- buttons do (SET-R12) and opens the guide (ONB-R22); Margin notes' checkbox (notesOn, with its tooltip) and Show
-- them again (as /pagle guide notes, ONB-R80); and, only while the list is offered (an item isn't done, and the Angler
-- isn't returning), the First evening list's checkbox, which shows or closes the list (ONB-R63) with "{done} of
-- {total} done". The last row is left out when it isn't offered as the tree is built, and draws nothing should the
-- list finish meanwhile. None registers a setting, so the root's Defaults button leaves them (SET-R13).
---@param layout SettingsLayout
local function gettingStarted(layout)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_GETTING_STARTED))
	layout:AddInitializer(customRow(function(frame)
		local own = widgets(frame)
		local buttonLeft = rowButton(own, L.SETTINGS_SHOW_ME_AROUND, function()
			HideUIPanel(SettingsPanel)
			ns.guide:Open()
		end)
		-- The line wraps between the label and the button, so it never runs under either, and keeps LINE_MIN: the
		-- label is cut short first.
		local labelEnd = rowLabel(own, L.SETTINGS_FIELD_GUIDE, buttonLeft - GAP - LINE_MIN - GAP - NAME_X)
		local x = math.max(CHECK_X, labelEnd + GAP)
		rowLine(own, x, L.SETTINGS_FIELD_GUIDE_LINE, math.max(LINE_MIN, buttonLeft - GAP - x))
	end, L.SETTINGS_FIELD_GUIDE))
	local evening = ns.evening
	-- whether the First evening list's row is offered, as the tree is built: both checkbox rows read it, so they share
	-- one column
	local offered = evening:IsOffered()
	layout:AddInitializer(customRow(function(frame)
		local own = widgets(frame)
		local onboarding = ns.onboarding
		local column = checkColumn(own, offered)
		rowLabel(own, L.SETTINGS_MARGIN_NOTES)
		rowCheck(own, column, onboarding:AreNotesOn(), function(checked)
			onboarding:SetNotesOn(checked)
		end)
		rowButton(own, L.SETTINGS_SHOW_NOTES_AGAIN, function()
			onboarding:Guide("notes")
		end)
		frame:SetScript("OnEnter", function(row)
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.SETTINGS_MARGIN_NOTES)
			GameTooltip:AddLine(L.SETTINGS_MARGIN_NOTES_TOOLTIP, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end, L.SETTINGS_MARGIN_NOTES))
	if not offered then
		return
	end
	layout:AddInitializer(customRow(function(frame)
		local own = widgets(frame)
		if not evening:IsOffered() then
			return
		end
		local column = checkColumn(own, true)
		rowLabel(own, L.SETTINGS_EVENING)
		local checkEnd = rowCheck(own, column, evening:IsShowing(), function(checked)
			evening:SetShown(checked)
		end)
		local done, total = evening:Count()
		-- the count within the row, wrapping before its right edge (the button column's)
		local x = checkEnd + 4
		rowLine(own, x, ns.RenderText(L.SETTINGS_EVENING_LINE, { done = done, total = total }), BUTTON_RIGHT - x)
	end, L.SETTINGS_EVENING))
end

-- The root's rows (SET-R10): the paragraph while no Module is On, the status list under "Modules", the note, the
-- Getting started section, the Field report section, then Saving's reminder checkbox and the Units section, whose
-- defaults the root's Defaults button restores (SET-R13), the Pagle menu section and last the Pagle website section, which ends with the Translations line (row 13) when there is one.
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
	gettingStarted(layout)
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
	Settings.CreateCheckbox(
		category,
		reminder,
		ns.RenderText(L.SETTINGS_RELOAD_REMINDER_TOOLTIP, { reloadReminderStep = ns.RELOAD_REMINDER_STEP })
	)
	unitsSection(category, layout)
	pagleMenuSection(category, layout)
	pagleWebsiteSection(category, layout)
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

-- A Module's `set` or `onClick` that then redraws the keybinding rows shown, Core's own frames, so a row greyed out
-- by what changed shows it at once (SET-R61, adapter/KeyBindingRow.lua). Blizzard's native rows re-read on their own.
---@param fn fun(...)
---@return fun(...)
local function thenRedrawKeys(fn)
	return function(...)
		fn(...)
		ns.RedrawKeyRows()
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
		thenRedrawKeys(setting.set)
	)
end

-- A slider's native options: its range and step, and its value's text on the right through `format`, as Game ›
-- Sound's volume sliders show theirs; with no `format`, no text (SET-R5).
---@param slider PagleSetting|PagleSettingSlider
---@return SettingsSliderOptions
local function sliderOptions(slider)
	local options = Settings.CreateSliderOptions(slider.min, slider.max, slider.step)
	if slider.format then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, slider.format)
	end
	return options
end

-- A Module's button row with no caption (SET-R2): its label on the button and no label beside it, on Core's own row,
-- the button as wide as its words, measured, from where a native row's control starts (controlButton). A native
-- button is a fixed 200 wide, and a long label ran past both its sides ("Guardar lo que llevo como conjunto de
-- pesca"); with no bound, a longer one ran past the row's edge (#593). It reads `isEnabled` each time it is drawn, as
-- a keybinding row does, and is found by its label.
---@param setting PagleSetting
---@param onClick fun()
---@return SettingsInitializer
local function labelButtonRow(setting, onClick)
	local function draw(frame)
		local own = widgets(frame)
		controlButton(own, frame, setting.label, onClick)
		own.button:SetEnabled(setting.isEnabled == nil or setting.isEnabled() ~= false)
		if setting.tooltip then
			frame:SetScript("OnEnter", function(row)
				GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
				GameTooltip:SetText(setting.label)
				GameTooltip:AddLine(setting.tooltip, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			frame:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
	end
	-- Named by its label, as a native row is, for the tree's readers; found by it in the search.
	local initializer = Settings.CreateElementInitializer(ROW_TEMPLATE, { draw = draw, name = setting.label })
	initializer:AddSearchTags(setting.label)
	return initializer
end

--- Whether Core draws a Module row on its own frames rather than natively, so it reads `isEnabled` as it draws: a
--- keybinding row (SET-R20), and a button row with no caption.
---@param setting PagleSetting
---@return boolean
local function drawnByCore(setting)
	return setting.kind == "keybinding" or (setting.kind == "button" and setting.caption == nil)
end

-- One Module row as an initializer on `page`: a native one (SET-R5), or Core's own for a keybinding (SET-R20).
---@param page SettingsCategory
---@param layout SettingsLayout
---@param setting PagleSetting
---@param variable string a variable name no other row uses
---@param indented boolean whether it hangs under a parent row
---@return SettingsInitializer
local function moduleRow(page, layout, setting, variable, indented)
	local kind = setting.kind
	if kind == "checkbox" then
		return Settings.CreateCheckbox(
			page,
			valueSetting(page, variable, Settings.VarType.Boolean, setting),
			setting.tooltip
		)
	elseif kind == "slider" then
		return Settings.CreateSlider(
			page,
			valueSetting(page, variable, Settings.VarType.Number, setting),
			sliderOptions(setting),
			setting.tooltip
		)
	elseif kind == "checkboxSlider" then
		-- The native checkbox with a slider beside it, as Game › Sound's and Controls' rows (SET-R5): two settings,
		-- each restored by Defaults; the control greys the slider while the box is unticked.
		local slider = setting.slider --[[@as PagleSettingSlider]]
		local sliderSetting = valueSetting(page, variable .. "_slider", Settings.VarType.Number, {
			kind = "slider",
			label = setting.label,
			default = slider.default,
			get = slider.get,
			set = slider.set,
		})
		local initializer = CreateSettingsCheckboxSliderInitializer(
			valueSetting(page, variable, Settings.VarType.Boolean, setting),
			setting.label,
			setting.tooltip,
			sliderSetting,
			sliderOptions(slider),
			setting.label,
			setting.tooltip
		)
		layout:AddInitializer(initializer)
		return initializer
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
		local onClick = thenRedrawKeys(setting.onClick)
		if setting.caption then
			initializer =
				CreateSettingsButtonInitializer(setting.label, setting.caption, onClick, setting.tooltip, true)
		else
			initializer = labelButtonRow(setting, onClick)
		end
	elseif kind == "keybinding" then
		if not C_KeyBindings.GetBindingIndex(setting.binding) then
			error(("Pagle: no key binding %s for the setting %s"):format(setting.binding, setting.label))
		end
		-- Core's own row: Blizzard's KeyBindingFrameBindingTemplate never greys out (SET-R20, #120).
		initializer = ns.KeyBindingRow(setting, indented)
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
			local parent = entry.parent and built[entry.parent]
			local initializer = securecallfunction(moduleRow, page, layout, setting, variable, parent ~= nil)
			if initializer then
				built[entry] = initializer
				if parent then
					initializer:SetParentInitializer(parent)
				end
				-- A row Core draws reads its isEnabled as it draws (adapter/KeyBindingRow.lua, labelButtonRow). A
				-- checkboxSlider's native control never reads modify predicates (SettingsCheckboxSliderControlMixin is a
				-- SettingsListElementMixin, whose IsEnabled reads only Kiosk), so it stays shown and live, as Game ›
				-- Sound's volume rows do with Enable Sound off (SET-R31). It isn't hidden with a shown predicate:
				-- SettingsListMixin:Display calls those outside securecallfunction, so Pagle's would taint the panel's
				-- open, and Settings.OpenToCategory's FocusContainer then has SmartNavigation:EnterFocusGroup print
				-- "Interface action failed because of an AddOn" (#598, SET-R6).
				if setting.isEnabled and setting.kind ~= "checkboxSlider" and not drawnByCore(setting) then
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
		local label =
			ns.RenderText(L.DEV_TOUR_SETTINGS, { topic = topic and L.SETTINGS_PAGES[topic] or L.SETTINGS_CATEGORY })
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
