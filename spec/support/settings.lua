-- The fake client's Settings API and panel, for Core's Settings category (CORE-R40–R44, settings.md).
-- spec/support/addon.lua adds these stubs to every load.
--
--   loaded.client.settings.category("Fishing")          -- a registered category, as the panel lists it
--   loaded.client.settings.show(category)               -- its rows, drawn as the panel draws them
--   loaded.client.settings.textsOf(row.frame)           -- the texts a drawn row shows
--   loaded.client.settings.defaults(category)           -- presses the page's Defaults button
--   loaded.client.settings.page("Trackers")             -- category(name), or an error
--   loaded.client.settings.rowNamed(rows, "Toast style") -- a shown row by label; dropdownOf(row), optionValues(row)
--                                                          and notesOf(row) read a slot dropdown row

---@class FakeClient
---@field settings FakeSettings The Settings panel.
---@field bindings string[] The key binding actions the client knows (Bindings.xml names), in binding index order,
--- as C_KeyBindings.GetBindingIndex reads them. loadAddon adds each loaded addon's Bindings.xml names. Specs add
--- to it.

--- Blizzard's Settings panel, as far as specs need it: what Core registered, and the pages it opened.
---@class FakeSettings
---@field categories table[] Every category registered with Settings.RegisterVerticalLayout*, in order. Each has
--- `name`, `parent` (nil for a top-level one), `layout.initializers` and `GetID()`.
---@field addOnCategories table[] The categories passed to Settings.RegisterAddOnCategory, in order.
---@field variables table<string, table> Each Settings.RegisterProxySetting setting by its variable name, with its
--- `category`: what a page's Defaults button restores (SET-R60).
---@field opened table[] The category each Settings.OpenToCategory call opened (nil for an unknown ID), in order.
---@field panel table SettingsPanel: shown by OpenToCategory, hidden by HideUIPanel. Showing it while hidden runs its
--- OnShow script, as the client does.
---@field category fun(name: string): table? The registered category with that name, if its top-level category is
--- registered under AddOns, as the panel lists it.
---@field show fun(category: table): { initializer: table, frame: table }[] Shows a page as the panel does: the panel,
--- then a fresh frame per row, through its initializer's InitFrame, so a row reads its value or label then. A value
--- row's frame has `value`, a slider's `valueLabel` (its Right label formatter's text, nil with none), a dropdown's
--- `valueLabel` (the label of the option holding its value), and every frame `enabled`. Until the next show, a
--- setting's change through its own row updates these frames as the panel's controls do (valueChanged).
---@field defaults fun(category: table) The page's Defaults button (SettingsPanelMixin:
--- SetCurrentCategorySettingsToDefaults): sets each setting registered on that page to its default value.
---@field shown { initializer: table, frame: table }[]? The rows show returned last.
---@field valueChanged fun(setting: table) What the panel does when a setting's value changes.
---@field textsOf fun(frame: table): string[] The text of every shown widget in a row's frame, depth first.
---@field buttonsOf fun(frame: table): table[] The shown buttons in a row's frame, depth first.
---@field page fun(name: string): table The registered category named `name`, as category reads it; an error if none.
---@field rowNamed fun(rows: { initializer: table, frame: table }[], label: string): { initializer: table, frame: table }
--- The shown row whose label is `label`; an error if none.
---@field dropdownOf fun(row: { initializer: table, frame: table }): table A slot dropdown row's dropdown (the fake's
--- DropdownButton, spec/support/widgets.lua); an error if it has none.
---@field optionValues fun(row: { initializer: table, frame: table }): string[] A slot dropdown's choices as
--- "<value>=<label>", read as the dropdown opens.
---@field notesOf fun(row: { initializer: table, frame: table }): string[] The texts a slot dropdown row shows under its
--- label and dropdown: its note while shown.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newWidget = dofile("spec/support/widgets.lua").newWidget

-- A Settings list row initializer, as Blizzard_Settings_Shared's SettingsListElementInitializer behaves for what
-- Core calls. Its default InitFrame reads the row's setting value, as a control does when shown.
---@param template string
---@param data table?
local function newInitializer(template, data)
	local initializer = { template = template, data = data or {}, searchTags = {}, modifyPredicates = {} }
	function initializer:GetData()
		return self.data
	end
	function initializer:GetName()
		return self.data.setting and self.data.setting:GetName() or self.data.name
	end
	function initializer:GetTooltip()
		return self.data.tooltip
	end
	function initializer:GetSetting()
		return self.data.setting
	end
	function initializer:GetOptions()
		return self.data.options
	end
	function initializer:SetParentInitializer(parent, modifyPredicate)
		assert(parent and parent ~= self, "SetParentInitializer needs another initializer")
		self.parentInitializer = parent
		if modifyPredicate then
			self:AddModifyPredicate(modifyPredicate)
		end
	end
	function initializer:GetParentInitializer()
		return self.parentInitializer
	end
	function initializer:AddModifyPredicate(fn)
		self.modifyPredicates[#self.modifyPredicates + 1] = fn
	end
	function initializer:EvaluateModifyPredicates()
		for _, predicate in ipairs(self.modifyPredicates) do
			if not predicate() then
				return false
			end
		end
		return true
	end
	-- A setting variable whose change re-evaluates the shown row's state (SettingsListElementMixin:Init).
	function initializer:AddEvaluateStateCVar(variable)
		self.evaluateStateVariables = self.evaluateStateVariables or {}
		self.evaluateStateVariables[#self.evaluateStateVariables + 1] = variable
	end
	function initializer:AddSearchTags(...)
		for i = 1, select("#", ...) do
			local tag = select(i, ...)
			if type(tag) == "string" and tag ~= "" then
				self.searchTags[#self.searchTags + 1] = tag:upper()
			end
		end
	end
	-- A slider shows its value through its options' Right label formatter, as MinimalSliderWithSteppersMixin's
	-- FormatValue does; with none, it shows no value label. A dropdown, whose options are a function returning the
	-- control text container's data, shows the label of the option holding its value (nil if none does).
	function initializer:FormatValue(frame)
		local options = self.data.options
		if type(options) == "function" then
			frame.valueLabel = nil
			for _, option in ipairs(options()) do
				if option.value == frame.value then
					frame.valueLabel = option.label
				end
			end
			return
		end
		local formatters = options and options.formatters
		local formatter = formatters and formatters[2] -- MinimalSliderWithSteppersMixin.Label.Right
		frame.valueLabel = formatter and formatter(frame.value) or nil
	end
	-- The fields the Settings list reads in its own update (Blizzard_SettingsList.lua: Factory, InitFrame, Resetter,
	-- GetExtent, GetTemplate), from ScrollBoxFactoryInitializerMixin (ScrollUtil.lua). They live in the metatable,
	-- and writing one from outside raises an error: a field Pagle wrote there taints the list (SET-R6, #246).
	local listReads = {}
	-- As ScrollBoxFactoryInitializerMixin:InitFrame, a frame of a template with an Init (Core's own rows) draws
	-- itself with frame:Init(initializer). A native control reads its value and greying instead.
	function listReads:InitFrame(frame)
		frame.initializer = self
		if self.data.setting then
			frame.value = self.data.setting:GetValue()
			self:FormatValue(frame)
		end
		frame.enabled = self:EvaluateModifyPredicates()
		if frame.Init then
			frame:Init(self)
		end
	end
	-- As ScrollBoxFactoryInitializerMixin:Resetter.
	function listReads:Resetter(frame)
		if frame.Release then
			frame:Release(self)
		end
	end
	function listReads.GetExtent()
		return nil
	end
	function listReads:GetTemplate()
		return self.template
	end
	function listReads.Factory() end
	return setmetatable(initializer, {
		__index = listReads,
		__newindex = function(self, key, value)
			if listReads[key] then
				error(("SET-R6: wrote %s onto an initializer, which the Settings list reads"):format(key), 2)
			end
			rawset(self, key, value)
		end,
	})
end

-- The Settings API and panel (Blizzard_Settings_Shared at the forever 1.60.1 commit, see .luacheckrc), recording
-- into client.settings.
---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	local settings = { categories = {}, addOnCategories = {}, opened = {}, variables = {}, shown = {} }
	client.settings = settings
	settings.panel = newWidget("Frame")
	settings.panel.shown = false
	-- As the client's Show: OnShow runs when a hidden frame shows.
	local showPanel = settings.panel.Show
	function settings.panel:Show()
		local wasShown = self.shown
		showPanel(self)
		local onShow = self.scripts.OnShow
		if not wasShown and onShow then
			onShow(self)
		end
	end

	local function register(name, parent)
		local category = { name = name, parent = parent, id = #settings.categories + 1 }
		category.layout = {
			initializers = {},
			AddInitializer = function(self, initializer)
				self.initializers[#self.initializers + 1] = initializer
				return initializer
			end,
		}
		function category:GetID()
			return self.id
		end
		function category:GetName()
			return self.name
		end
		settings.categories[#settings.categories + 1] = category
		return category, category.layout
	end

	local function addControl(template, category, setting, options, tooltip)
		local initializer = newInitializer(template, {
			setting = setting,
			name = setting:GetName(),
			options = options or {},
			tooltip = tooltip,
		})
		category.layout:AddInitializer(initializer)
		return initializer
	end

	stubs.Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function(name)
			return register(name, nil)
		end,
		RegisterVerticalLayoutSubcategory = function(parent, name)
			return register(name, parent)
		end,
		RegisterAddOnCategory = function(category)
			settings.addOnCategories[#settings.addOnCategories + 1] = category
		end,
		OpenToCategory = function(id)
			settings.opened[#settings.opened + 1] = settings.categories[id] or false
			settings.panel:Show()
		end,
		-- As the client's: a variable can be registered once.
		RegisterProxySetting = function(category, variable, varType, name, default, get, set)
			if settings.variables[variable] then
				error(("Setting variable '%s' was previously registered."):format(variable))
			end
			local setting = {
				category = category,
				name = name,
				variable = variable,
				varType = varType,
				default = default,
				get = get,
				set = set,
			}
			settings.variables[variable] = setting
			function setting:GetName()
				return self.name
			end
			function setting:GetVariable()
				return self.variable
			end
			function setting:GetVariableType()
				return self.varType
			end
			function setting:GetDefaultValue()
				return self.default
			end
			function setting:GetValue()
				return self.get()
			end
			-- As SettingMixin:ApplyValue: sets it, then tells the shown rows (TriggerValueChanged).
			function setting:SetValue(value)
				self.set(value)
				settings.valueChanged(self)
			end
			-- As SettingMixin:NotifyUpdate: reads the value again and tells the shown rows it changed.
			function setting:NotifyUpdate()
				settings.valueChanged(self)
			end
			return setting
		end,
		CreateCheckbox = function(category, setting, tooltip)
			assert(setting:GetVariableType() == "boolean")
			return addControl("SettingsCheckboxControlTemplate", category, setting, nil, tooltip)
		end,
		CreateSliderOptions = function(minValue, maxValue, rate)
			local options = { minValue = minValue, maxValue = maxValue, steps = (maxValue - minValue) / rate }
			-- SettingsSliderOptionsMixin:SetLabelFormatter, for a function formatter.
			function options:SetLabelFormatter(labelType, formatter)
				assert(type(formatter) == "function")
				self.formatters = self.formatters or {}
				self.formatters[labelType] = formatter
			end
			return options
		end,
		CreateSlider = function(category, setting, options, tooltip)
			assert(setting:GetVariableType() == "number" and options ~= nil)
			return addControl("SettingsSliderControlTemplate", category, setting, options, tooltip)
		end,
		CreateDropdown = function(category, setting, options, tooltip)
			assert(options ~= nil)
			return addControl("SettingsDropdownControlTemplate", category, setting, options, tooltip)
		end,
		CreateControlTextContainer = function()
			local container = { data = {} }
			function container:Add(value, label, tooltip)
				local option = { value = value, label = label, text = label, tooltip = tooltip }
				self.data[#self.data + 1] = option
				return option
			end
			function container:GetData()
				return self.data
			end
			return container
		end,
		CreateElementInitializer = newInitializer,
	}
	stubs.CreateSettingsListSectionHeaderInitializer = function(name, tooltip)
		return newInitializer("SettingsListSectionHeaderTemplate", { name = name, tooltip = tooltip })
	end
	stubs.CreateSettingsButtonInitializer = function(name, buttonText, buttonClick, tooltip, addSearchTags)
		assert(addSearchTags ~= nil)
		local initializer = newInitializer(
			"SettingButtonControlTemplate",
			{ name = name, buttonText = buttonText, buttonClick = buttonClick, tooltip = tooltip }
		)
		if addSearchTags then
			initializer:AddSearchTags(name, buttonText)
		end
		-- As SettingButtonControlMixin:Init draws the row: its label (`name`, "" for none) in Text, through
		-- SettingsListElementMixin:Init, and `buttonText` on a button that runs `buttonClick`; a function `buttonText`
		-- is called each time the row is drawn (EvaluateName) (Blizzard_Settings_Shared/Blizzard_SettingControls.lua at
		-- the forever 1.60.1 commit). Blizzard's own template does this, so the fake sets it raw, past the guard
		-- against Pagle's writes.
		local initFrame = initializer.InitFrame
		rawset(initializer, "InitFrame", function(self, frame)
			initFrame(self, frame)
			frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			frame.Text:SetText(self.data.name)
			frame.Button = newWidget("Button", frame)
			local caption = self.data.buttonText
			frame.Button:SetText(type(caption) == "function" and caption() or caption)
			frame.Button:SetScript("OnClick", self.data.buttonClick)
		end)
		return initializer
	end
	stubs.CreateKeybindingEntryInitializer = function(bindingIndex, search)
		return newInitializer("KeyBindingFrameBindingTemplate", { bindingIndex = bindingIndex, search = search })
	end
	stubs.C_KeyBindings = {
		GetBindingIndex = function(action)
			for index, known in ipairs(client.bindings) do
				if known == action then
					return index
				end
			end
			return nil
		end,
	}
	-- EnumUtil.MakeEnum("Left", "Right", "Top", "Min", "Max") in MinimalSlider.lua.
	stubs.MinimalSliderWithSteppersMixin = { Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } }
	stubs.SettingsPanel = settings.panel
	stubs.HideUIPanel = function(frame)
		frame:Hide()
	end

	function settings.category(name)
		for _, category in ipairs(settings.categories) do
			local top = category
			while top.parent do
				top = top.parent
			end
			local listed = false
			for _, addOn in ipairs(settings.addOnCategories) do
				listed = listed or addOn == top
			end
			if category.name == name and listed then
				return category
			end
		end
		return nil
	end

	-- A fresh list frame for `initializer`: one of a template a loaded addon's XML defines gets that template's mixin,
	-- as the client's CreateFrame applies it.
	local function newFrame(initializer)
		local frame = newWidget("Frame")
		local template = client.templates[initializer:GetTemplate()]
		if template and template.mixin then
			for key, value in pairs(assert(stubs[template.mixin], "no mixin " .. template.mixin)) do
				frame[key] = value
			end
		end
		return frame
	end

	function settings.show(category)
		settings.panel:Show()
		local rows = {}
		for _, initializer in ipairs(category.layout.initializers) do
			local frame = newFrame(initializer)
			initializer:InitFrame(frame)
			rows[#rows + 1] = { initializer = initializer, frame = frame }
		end
		settings.shown = rows
		return rows
	end

	function settings.defaults(category)
		local variables = {}
		for variable, setting in pairs(settings.variables) do
			if setting.category == category then
				variables[#variables + 1] = variable
			end
		end
		table.sort(variables)
		for _, variable in ipairs(variables) do
			local setting = settings.variables[variable]
			setting:SetValue(setting:GetDefaultValue())
		end
	end

	-- What a value change does to the rows shown last (SettingMixin:TriggerValueChanged, Blizzard_SettingControls.lua
	-- at the forever 1.60.1 commit): a control shows its own setting's new value and re-evaluates its state
	-- (SettingsControlMixin:OnSettingValueChanged); a row re-evaluates its state when its parent's setting changes
	-- (OnParentSettingValueChanged) or a variable it added with AddEvaluateStateCVar does. A keybinding row isn't a
	-- SettingsListElementMixin (Blizzard_Keybindings.lua), so it hears none of these.
	function settings.valueChanged(setting)
		local variable = setting:GetVariable()
		for _, shown in ipairs(settings.shown or {}) do
			local initializer, frame = shown.initializer, shown.frame
			local parent = initializer:GetParentInitializer()
			local watched = parent and parent:GetSetting() == setting
			for _, name in ipairs(initializer.evaluateStateVariables or {}) do
				watched = watched or name == variable
			end
			if initializer:GetSetting() == setting then
				frame.value = setting:GetValue()
				initializer:FormatValue(frame)
				watched = true
			end
			if watched and initializer.template ~= "KeyBindingFrameBindingTemplate" then
				frame.enabled = initializer:EvaluateModifyPredicates()
			end
		end
	end

	local function walk(widget, visit)
		for _, child in ipairs(widget.children) do
			if child.shown then
				visit(child)
				walk(child, visit)
			end
		end
	end
	function settings.textsOf(frame)
		local texts = {}
		walk(frame, function(widget)
			if widget.text ~= nil then
				texts[#texts + 1] = widget.text
			end
		end)
		return texts
	end
	function settings.buttonsOf(frame)
		local buttons = {}
		walk(frame, function(widget)
			if widget.kind == "Button" then
				buttons[#buttons + 1] = widget
			end
		end)
		return buttons
	end

	function settings.page(name)
		return assert(settings.category(name), "no page " .. name)
	end
	function settings.rowNamed(rows, label)
		for _, row in ipairs(rows) do
			if row.initializer:GetName() == label then
				return row
			end
		end
		error("no row " .. label)
	end
	function settings.dropdownOf(row)
		for _, child in ipairs(row.frame.children) do
			if child.kind == "DropdownButton" then
				return child
			end
		end
		error("no dropdown on " .. row.initializer:GetName())
	end
	function settings.optionValues(row)
		return settings.dropdownOf(row):choices()
	end
	function settings.notesOf(row)
		return { select(3, unpack(settings.textsOf(row.frame))) }
	end
end
