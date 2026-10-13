-- The fake client's Settings API and panel, for Core's Settings category (CORE-R40–R44, settings.md).
-- spec/support/addon.lua adds these stubs to every load.
--
--   loaded.client.settings.category("Fishing")          -- a registered category, as the panel lists it
--   loaded.client.settings.show(category)               -- its rows, drawn as the panel draws them
--   loaded.client.settings.textsOf(row.frame)           -- the texts a drawn row shows

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
---@field panel table SettingsPanel: shown by OpenToCategory, hidden by HideUIPanel.
---@field category fun(name: string): table? The registered category with that name, if its top-level category is
--- registered under AddOns, as the panel lists it.
---@field show fun(category: table): { initializer: table, frame: table }[] Shows a page as the panel does: a fresh
--- frame per row, through its initializer's InitFrame, so a row reads its value or label then.
---@field textsOf fun(frame: table): string[] The text of every shown widget in a row's frame, depth first.
---@field buttonsOf fun(frame: table): table[] The shown buttons in a row's frame, depth first.

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
	function initializer:AddSearchTags(...)
		for i = 1, select("#", ...) do
			local tag = select(i, ...)
			if type(tag) == "string" and tag ~= "" then
				self.searchTags[#self.searchTags + 1] = tag:upper()
			end
		end
	end
	function initializer:InitFrame(frame)
		frame.initializer = self
		if self.data.setting then
			frame.value = self.data.setting:GetValue()
		end
		frame.enabled = self:EvaluateModifyPredicates()
	end
	initializer.Resetter = function() end
	initializer.GetExtent = function()
		return nil
	end
	return initializer
end

-- The Settings API and panel (Blizzard_Settings_Shared at the forever 1.60.1 commit, see .luacheckrc), recording
-- into client.settings.
---@param client FakeClient
---@param stubs table<string, any> The fake client's stubs, which this adds to.
return function(client, stubs)
	local settings = { categories = {}, addOnCategories = {}, opened = {}, variables = {} }
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
			function setting:SetValue(value)
				self.set(value)
			end
			return setting
		end,
		CreateCheckbox = function(category, setting, tooltip)
			assert(setting:GetVariableType() == "boolean")
			return addControl("SettingsCheckboxControlTemplate", category, setting, nil, tooltip)
		end,
		CreateSliderOptions = function(minValue, maxValue, rate)
			return { minValue = minValue, maxValue = maxValue, steps = (maxValue - minValue) / rate }
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
		-- SettingsListElementMixin:Init, and `buttonText` on a button that runs `buttonClick` (Blizzard_Settings_Shared/
		-- Blizzard_SettingControls.lua at the forever 1.60.1 commit).
		local initFrame = initializer.InitFrame
		function initializer:InitFrame(frame)
			initFrame(self, frame)
			frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			frame.Text:SetText(self.data.name)
			frame.Button = newWidget("Button", frame)
			frame.Button:SetText(self.data.buttonText)
			frame.Button:SetScript("OnClick", self.data.buttonClick)
		end
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

	function settings.show(category)
		local rows = {}
		for _, initializer in ipairs(category.layout.initializers) do
			local frame = newWidget("Frame")
			initializer:InitFrame(frame)
			rows[#rows + 1] = { initializer = initializer, frame = frame }
		end
		return rows
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
end
