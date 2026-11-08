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
--   loaded.client.settings.menuTemplatesOf(row)         -- the element templates a native dropdown's options draw on

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
--- `valueLabel` (the label of the option holding its value), and a native control's frame `enabled` (a native
--- keybinding row, a header or a custom row gets none: it never greys by its modify predicates). Until the next show, a
--- setting's change through its own row updates these frames as the panel's controls do (valueChanged).
---@field defaults fun(category: table) The page's Defaults button (SettingsPanelMixin:
--- SetCurrentCategorySettingsToDefaults): sets each setting registered on that page to its default value, skipping
--- one with no default.
---@field shown { initializer: table, frame: table }[]? The rows show returned last.
---@field valueChanged fun(setting: table) What the panel does when a setting's value changes.
---@field textsOf fun(frame: table): string[] The text of every shown widget in a row's frame, depth first.
---@field buttonsOf fun(frame: table): table[] The shown buttons in a row's frame, depth first.
---@field menuTemplatesOf fun(row: { initializer: table, frame: table }): string[] The element templates a shown
--- native dropdown row's options draw on when its menu opens, in order.
---@field statusList fun(): string[], table[] Shows the Settings root ("Pagle") and returns the texts and the shown
--- buttons of its status list, a row per roster Module, in order (SET-R11).
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

-- The native templates whose frames grey out by their initializer's modify predicates: the controls built on
-- SettingsControlMixin and the button row (Blizzard_Settings_Shared/Blizzard_SettingControls.lua at the forever
-- 1.60.1 commit: SettingsControlMixin:IsEnabled and SettingsButtonControlMixin:EvaluateState read
-- EvaluateModifyPredicates). KeyBindingFrameBindingTemplateMixin (Blizzard_Keybindings.lua) never reads them, nor
-- does a section header, and a custom template's Init draws its own state, so none of those gets `enabled` (#120).
-- Nor does SettingsCheckboxSliderControlMixin: a SettingsListElementMixin, whose IsEnabled reads only Kiosk; it greys
-- only its slider, while its checkbox is unticked (`sliderEnabled`).
local GREYING_TEMPLATES = {
	SettingsCheckboxControlTemplate = true,
	SettingsSliderControlTemplate = true,
	SettingsDropdownControlTemplate = true,
	SettingButtonControlTemplate = true,
}

-- The Blizzard template `template` is, or inherits from through the loaded addons' XML (a Pagle control template
-- inherits Blizzard's whole, SET-R7): what its frames do is that template's. Set by the returned function below,
-- once the client is known.
---@type fun(template: string?): string?
local nativeOf = function(template)
	return template
end

-- A Settings list row initializer, as Blizzard_Settings_Shared's SettingsListElementInitializer behaves for what
-- Core calls. Its default InitFrame reads the row's setting value, as a control does when shown. `native` is the
-- Blizzard template its frames behave as (nativeOf).
---@param template string
---@param data table?
local function newInitializer(template, data)
	local initializer = {
		template = template,
		native = nativeOf(template),
		data = data or {},
		searchTags = {},
		modifyPredicates = {},
		shownPredicates = {},
	}
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
	-- SettingsSearchableElementMixin:AddShownPredicate and ShouldShow: the list shows the row only while each returns
	-- true, laid out again after each value change (SettingsListMixin:RepairDisplay).
	function initializer:AddShownPredicate(fn)
		self.shownPredicates[#self.shownPredicates + 1] = fn
	end
	function initializer:ShouldShow()
		for _, predicate in ipairs(self.shownPredicates) do
			if not predicate() then
				return false
			end
		end
		return true
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
	-- itself with frame:Init(initializer). A native control reads its value and greying instead; a native keybinding
	-- row or a section header never greys (see GREYING_TEMPLATES).
	function listReads:InitFrame(frame)
		frame.initializer = self
		if self.data.setting then
			frame.value = self.data.setting:GetValue()
			self:FormatValue(frame)
		elseif self.data.cbSetting then
			-- SettingsCheckboxSliderControlMixin:Init and EvaluateState: the checkbox's value, the slider's value and
			-- its Right label, and the slider live only while the box is ticked.
			frame.value = self.data.cbSetting:GetValue()
			frame.sliderValue = self.data.sliderSetting:GetValue()
			local formatter = self.data.sliderOptions.formatters and self.data.sliderOptions.formatters[2]
			frame.valueLabel = formatter and formatter(frame.sliderValue) or nil
			frame.sliderEnabled = frame.value == true
		end
		if GREYING_TEMPLATES[self.native] then
			frame.enabled = self:EvaluateModifyPredicates()
		end
		if self.native == "SettingButtonControlTemplate" then
			-- As SettingButtonControlMixin:Init draws the row: its label (`name`, "" for none) in Text, through
			-- SettingsListElementMixin:Init, and `buttonText` on a button that runs `buttonClick`; a function
			-- `buttonText` is called each time the row is drawn (EvaluateName) (Blizzard_Settings_Shared/
			-- Blizzard_SettingControls.lua at the forever 1.60.1 commit).
			frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			frame.Text:SetText(self.data.name)
			frame.Button = newWidget("Button", frame)
			local caption = self.data.buttonText
			frame.Button:SetText(type(caption) == "function" and caption() or caption)
			frame.Button:SetScript("OnClick", self.data.buttonClick)
		end
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
	nativeOf = function(template)
		local seen = 0
		while client.templates[template] and client.templates[template].inherits and seen < 10 do
			template = client.templates[template].inherits
			seen = seen + 1
		end
		return template
	end
	local settings = { categories = {}, addOnCategories = {}, opened = {}, variables = {}, shown = {} }
	client.settings = settings
	settings.panel = newWidget("Frame")
	settings.panel.shown = false

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
		-- Settings.CreateSettingInitializer: SettingsInbound's initializer, tagged for search with its setting's name.
		CreateSettingInitializer = function(template, data)
			local initializer = newInitializer(template, data)
			if data.setting then
				initializer:AddSearchTags(data.setting:GetName())
			end
			return initializer
		end,
		-- Settings.CreateControlInitializer: CreateSettingInitializerData's data on `template`, not added to a layout.
		CreateControlInitializer = function(template, setting, options, tooltip)
			return stubs.Settings.CreateSettingInitializer(
				template,
				{ setting = setting, name = setting:GetName(), options = options or {}, tooltip = tooltip }
			)
		end,
		-- Settings.CreateDropdownOptionInserter: a highlight radio per option, on Blizzard's shared element template
		-- (MenuTemplates.CreateHighlightRadio), each picking its value through the setting (SetSelected).
		CreateDropdownOptionInserter = function(setting, optionsFunc)
			return function(_, rootDescription)
				for _, option in ipairs(optionsFunc()) do
					rootDescription:CreateHighlightRadio(option.label, function(data)
						return setting:GetValue() == data.value
					end, function(data)
						setting:SetValue(data.value)
					end, option)
				end
			end
		end,
		-- Settings.InitDropdown: the dropdown's menu generator, which lays the menu out and inserts the options.
		InitDropdown = function(dropdown, setting, elementInserter)
			dropdown.menuGenerator = function(_, rootDescription)
				rootDescription:SetGridMode(1)
				elementInserter(setting, rootDescription)
			end
		end,
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
		return initializer
	end
	-- CreateSettingsCheckboxSliderInitializer (Blizzard_SettingControls.lua at the forever 1.60.1 commit): the data
	-- carries both settings and no `setting`, so GetSetting is nil, and the search tags are both labels.
	stubs.CreateSettingsCheckboxSliderInitializer = function(
		cbSetting,
		cbLabel,
		cbTooltip,
		sliderSetting,
		sliderOptions,
		sliderLabel,
		sliderTooltip
	)
		assert(cbSetting:GetVariableType() == "boolean" and sliderSetting:GetVariableType() == "number")
		local initializer = newInitializer("SettingsCheckboxSliderControlTemplate", {
			name = cbLabel,
			tooltip = cbTooltip,
			cbSetting = cbSetting,
			cbLabel = cbLabel,
			cbTooltip = cbTooltip,
			sliderSetting = sliderSetting,
			sliderOptions = sliderOptions,
			sliderLabel = sliderLabel,
			sliderTooltip = sliderTooltip,
		})
		initializer:AddSearchTags(cbLabel, sliderLabel)
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
			-- SettingsListMixin:Display lists only the rows whose ShouldShow is true.
			if initializer:ShouldShow() then
				local frame = newFrame(initializer)
				initializer:InitFrame(frame)
				rows[#rows + 1] = { initializer = initializer, frame = frame }
			end
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
		-- SettingMixin:SetValueToDefault skips a setting whose default is nil, as QoL's fishing set (SET-R21)
		-- (Blizzard_Settings_Shared/Blizzard_Setting.lua at the forever 1.60.1 commit).
		for _, variable in ipairs(variables) do
			local setting = settings.variables[variable]
			if setting:GetDefaultValue() ~= nil then
				setting:SetValue(setting:GetDefaultValue())
			end
		end
	end

	-- What a value change does to the rows shown last (SettingMixin:TriggerValueChanged, Blizzard_SettingControls.lua
	-- at the forever 1.60.1 commit): a control shows its own setting's new value and re-evaluates its state
	-- (SettingsControlMixin:OnSettingValueChanged); a row re-evaluates its state when its parent's setting changes
	-- (OnParentSettingValueChanged) or a variable it added with AddEvaluateStateCVar does. A keybinding row isn't a
	-- SettingsListElementMixin (Blizzard_Keybindings.lua), so it hears none of these, and a custom row's frame is its
	-- owner's to redraw.
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
			-- SettingsCheckboxSliderControlMixin hears both its settings: the box re-evaluates the slider's state.
			local data = initializer:GetData()
			if data.cbSetting == setting or data.sliderSetting == setting then
				initializer:InitFrame(frame)
			end
			if watched and GREYING_TEMPLATES[initializer.native] then
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
	function settings.statusList()
		local texts, buttons = {}, {}
		for _, row in ipairs(settings.show(assert(settings.category("Pagle"), "no Pagle category"))) do
			if row.initializer.searchTags[1] == "MODULES" then
				for _, text in ipairs(settings.textsOf(row.frame)) do
					texts[#texts + 1] = text
				end
				for _, button in ipairs(settings.buttonsOf(row.frame)) do
					buttons[#buttons + 1] = button
				end
			end
		end
		return texts, buttons
	end

	-- A root menu description as Blizzard_Menu's, as far as a Settings dropdown's options use one: each highlight
	-- radio's element factory draws it on Blizzard's shared option template until one is set (MenuTemplates.lua's
	-- CreateMenuElementDescription and CreateHighlightRadio; Menu.lua's SetElementFactory and
	-- EnumerateElementDescriptions).
	local function newRootDescription()
		local root = { elements = {} }
		function root.SetGridMode() end
		function root:CreateHighlightRadio(text, isSelected, setSelected, data)
			local element = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
			local factory = function(make)
				make("WowMenuDropdownHighlightButtonTemplate")
			end
			function element.SetElementFactory(_, elementFactory)
				factory = elementFactory
			end
			function element.CallFactory(_, make)
				factory(make)
			end
			self.elements[#self.elements + 1] = element
			return element
		end
		function root:EnumerateElementDescriptions()
			return ipairs(self.elements)
		end
		return root
	end

	-- SettingsDropdownControlMixin:SetupDropdownMenu, which a template's own mixin may replace.
	local function setupDropdownMenu(_, dropdown, setting, options, initTooltip, initializer)
		local inserter = stubs.Settings.CreateDropdownOptionInserter(setting, options, initializer)
		stubs.Settings.InitDropdown(dropdown, setting, inserter, initTooltip, initializer)
	end

	--- The element templates a shown native dropdown row's options draw on when its menu opens, in order, as
	--- SettingsDropdownControlMixin:InitDropdown sets up its dropdown (through the frame's own SetupDropdownMenu when
	--- its template's mixin gives one) and Blizzard_Menu's MenuMixin:SetMenuDescription calls each element's factory.
	---@param row { initializer: table, frame: table }
	---@return string[]
	function settings.menuTemplatesOf(row)
		local frame, initializer = row.frame, row.initializer
		local dropdown = newWidget("Frame", frame)
		local setup = frame.SetupDropdownMenu or setupDropdownMenu
		setup(frame, dropdown, initializer:GetSetting(), initializer:GetOptions(), function() end, initializer)
		local root = newRootDescription()
		dropdown.menuGenerator(dropdown, root)
		local templates = {}
		for _, element in root:EnumerateElementDescriptions() do
			element:CallFactory(function(template)
				templates[#templates + 1] = template
			end)
		end
		return templates
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
