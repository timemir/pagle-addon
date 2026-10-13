-- busted's helper (.busted). It defines loadAddon, which loads an addon the way the WoW client does, so specs
-- exercise the real load order (roadmap M0 › Toolchain): every file addons/<Addon>/<Addon>.toc lists, vendored libs
-- included, in TOC order, each called with (addonName, ns) and one ns shared by all of them. A file missing from the
-- TOC, or listed after a file that needs it, fails the specs that load the addon.
--
--   local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
--   loaded.env.Pagle, loaded.ns.IsForever, loaded.printed
--   loaded.client.fire("PLAYER_REGEN_DISABLED")
--
-- The addon runs against a fake client: frames that keep the events they register, so loaded.client.fire reaches
-- them, and stubs for the WoW API the addon calls (clientStubs below). loadAddon fires ADDON_LOADED after the last
-- file, as the client does. An addon's `## Dependencies` load first, into the same globals and client, so
-- loadAddon("Pagle_QoL", FOREVER_GLOBALS) runs Core and then QoL; loaded.namespaces.Pagle is Core's ns. The client's
-- Settings panel (loaded.client.settings) records the categories and rows an addon registers and can show a page, as
-- the panel would draw it.
--
-- Each load gets its own globals table, so nothing an addon defines (LibStub, Pagle) leaks into the next load.
-- Names not in it fall back to the Lua 5.1 globals busted runs with.
--
-- It also defines the Forever fixtures, PROJECT_IDS and FOREVER_GLOBALS, so every spec agrees on them, and loads
-- spec/support/fake_pagle.lua, which defines newFakePagle (FakePagle, CORE-R18) for Module specs.
--
-- Globals rather than a module: the types stage checks spec/ against the WoW client's Lua, which has no require.

--- Project IDs as the clients set WOW_PROJECT_ID. Forever's is WOW_PROJECT_CAMELOT, 18 (BIR forever README at
--- BIR_COMMIT, scripts/tools.env).
PROJECT_IDS = { CAMELOT = 18, MAINLINE = 1 }

--- The globals a Forever client defines, for loadAddon. loadAddon copies them, so specs share this one table.
FOREVER_GLOBALS = { WOW_PROJECT_ID = PROJECT_IDS.CAMELOT, WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT }

---@class LoadedAddon
---@field ns table The addon's private table, shared by every file it loads.
---@field namespaces table<string, table> The private table of each addon loaded, its dependencies too, by folder
--- name: `namespaces.Pagle` is Core's when a Module was loaded.
---@field env table<string, any> The globals the files saw and set; `env.Pagle` is the Pagle global.
---@field printed string[] Each line the addon printed to chat, in order.
---@field client FakeClient The fake client the addon runs against.

--- The client's event system and addon list, as far as specs need them.
---@class FakeClient
---@field missingEvents table<string, true> Events this client doesn't know: registering one raises an error, as the
--- client does. Specs add to it.
---@field frames table[] Every frame CreateFrame made, in order.
---@field fire fun(event: string, ...) Fires a WoW event at each frame registered for it, in creation order, calling
--- its OnEvent script with (frame, event, ...). A unit event reaches a frame only for the units it registered.
---@field addons table<string, FakeAddOn> The addons installed, by folder name ("Pagle_QoL"), as C_AddOns reports
--- them. loadAddon lists each addon it loads, with its TOC fields as metadata. One not listed is missing. Specs add
--- to it.
---@field bindings string[] The key binding actions the client knows (Bindings.xml names), in binding index order,
--- as C_KeyBindings.GetBindingIndex reads them. loadAddon adds each loaded addon's Bindings.xml names. Specs add
--- to it.
---@field settings FakeSettings The Settings panel.
---@field tickers { period: number, due: number, callback: fun(ticker: table), cancelled: boolean }[] Every
--- C_Timer.NewTicker, in creation order.
---@field advance fun(seconds: number) Moves the client's clock on, running each ticker every time its period
--- passes, in time order.
---@field newTicker fun(period: number, callback: fun(ticker: table)): table What C_Timer.NewTicker(period, callback)
--- does: a ticker, with Cancel and IsCancelled, that runs callback every period seconds of advance.
---@field menus table[] Every context menu MenuUtil.CreateContextMenu opened, in order. Each has `buttons`
--- ({ text, callback }), `texts()` and `click(text)`.
---@field timers { seconds: number, callback: fun(), ticker: table }[] The C_Timer.After callbacks not yet run, in
--- order. Each also runs once advance has moved the clock `seconds` on.
---@field runTimers fun() Runs every queued timer, as the next frames would.
---@field time fun(): number The client's clock, in seconds since the load, as GetTime() returns it; advance moves it.
---@field loot FakeLoot The loot window, as the loot API reads it.

--- The loot window the loot API reads: whether it's fishing loot (`IsFishingLoot()`) and its slots, in order.
--- Specs set both before firing LOOT_READY.
---@class FakeLoot
---@field fishing any What IsFishingLoot() returns. Default false.
---@field slots { link: any, quantity: any, currencyID: integer?, isCoin: boolean? }[] Each slot as GetLootSlotLink
--- and GetLootSlotInfo (3rd, 4th and 10th returns) read it. Default none.

--- An installed addon, as the fake client's C_AddOns reports it.
---@class FakeAddOn
---@field enabled boolean? Enabled for the player's character in the AddOns list. Default true.
---@field loaded boolean? Loaded this session. Default: whether it's enabled.
---@field metadata table<string, string>? Its TOC fields, e.g. ["X-Pagle-API"] = "1".

--- The player's character GUID, as UnitGUID("player") returns it.
PLAYER_GUID = "Player-1-00000001"

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

---@return FakeClient
local function newClient()
	local client = {
		missingEvents = {},
		frames = {},
		addons = {},
		bindings = {},
		tickers = {},
		loot = { fishing = false, slots = {} },
	}
	local now = 0

	function client.advance(seconds)
		local target = now + seconds
		while true do
			local nextTicker
			for _, ticker in ipairs(client.tickers) do
				if
					not ticker.cancelled
					and ticker.due <= target
					and (not nextTicker or ticker.due < nextTicker.due)
				then
					nextTicker = ticker
				end
			end
			if not nextTicker then
				break
			end
			now = nextTicker.due
			nextTicker.due = now + nextTicker.period
			nextTicker.callback(nextTicker)
		end
		now = target
	end

	function client.time()
		return now
	end

	-- C_Timer.NewTicker(seconds, callback) without iterations: runs until cancelled.
	function client.newTicker(period, callback)
		local ticker = { period = period, due = now + period, callback = callback, cancelled = false }
		function ticker:Cancel()
			self.cancelled = true
		end
		function ticker:IsCancelled()
			return self.cancelled
		end
		client.tickers[#client.tickers + 1] = ticker
		return ticker
	end

	function client.fire(event, ...)
		local unit = ...
		for _, frame in ipairs({ unpack(client.frames) }) do
			local registered = frame.events[event]
			local onEvent = frame.scripts.OnEvent
			if registered and onEvent and (registered == true or registered[unit]) then
				onEvent(frame, event, ...)
			end
		end
	end

	return client
end

-- Widget methods that only lay out or colour: nothing for a spec to read back.
local LAYOUT_METHODS = {
	"SetPoint",
	"ClearAllPoints",
	"SetAllPoints",
	"SetSize",
	"SetWidth",
	"SetHeight",
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetTextColor",
	"SetFontObject",
	"SetEnabled",
}

-- A widget (frame, button or font string) that keeps what specs read back: its text, whether it's shown, its
-- scripts and the widgets created on it.
---@param kind string "Frame", "Button", "FontString", …
---@param parent table?
local function newWidget(kind, parent)
	---@type table<string, any>
	local widget = { kind = kind, shown = true, scripts = {}, children = {} }
	function widget:SetText(text)
		self.text = text
	end
	function widget:GetText()
		return self.text
	end
	function widget:Show()
		self.shown = true
	end
	function widget:Hide()
		self.shown = false
	end
	function widget:SetShown(shown)
		self.shown = not not shown
	end
	function widget:IsShown()
		return self.shown
	end
	function widget:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function widget:GetScript(script)
		return self.scripts[script]
	end
	-- As a mouse click does: OnClick with the button, not down.
	function widget:Click()
		local onClick = self.scripts.OnClick
		if onClick then
			onClick(self, "LeftButton", false)
		end
	end
	function widget:CreateFontString()
		return newWidget("FontString", self)
	end
	for _, method in ipairs(LAYOUT_METHODS) do
		widget[method] = function() end
	end
	if parent then
		parent.children[#parent.children + 1] = widget
	end
	return widget
end

-- A frame that records the events it registers and its scripts, so client.fire can reach it.
---@param client FakeClient
---@param kind string?
---@param parent table?
local function newFrame(client, kind, parent)
	local frame = newWidget(kind or "Frame", parent)
	frame.events = {}
	local function known(event)
		if client.missingEvents[event] then
			error(('Frame:RegisterEvent(): Attempt to register unknown event "%s"'):format(event), 3)
		end
	end
	function frame:RegisterEvent(event)
		known(event)
		self.events[event] = true
	end
	function frame:RegisterUnitEvent(event, ...)
		known(event)
		local units = {}
		for i = 1, select("#", ...) do
			units[(select(i, ...))] = true
		end
		self.events[event] = units
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:UnregisterAllEvents()
		self.events = {}
	end
	client.frames[#client.frames + 1] = frame
	return frame
end

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
---@param stubs table<string, any>
local function settingsStubs(client, stubs)
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

-- Slash commands, context menus and next-frame timers (Blizzard_ChatFrameBase and Blizzard_Menu at the forever
-- 1.60.1 commit, see .luacheckrc), recording into client.menus and client.timers.
---@param client FakeClient
---@param stubs table<string, any>
local function menuStubs(client, stubs)
	stubs.SlashCmdList = {}
	client.menus = {}
	client.timers = {}

	-- As MenuUtil.CreateContextMenu: the generator fills a root description now, and the menu opens at the cursor.
	stubs.MenuUtil = {
		CreateContextMenu = function(owner, generator, ...)
			local menu = { owner = owner, buttons = {} }
			local root = {}
			function root.CreateButton(_, text, callback, data)
				local button = { text = text, callback = callback, data = data }
				menu.buttons[#menu.buttons + 1] = button
				return button
			end
			generator(owner, root, ...)
			-- The texts of its buttons, in order.
			function menu.texts()
				local texts = {}
				for i, button in ipairs(menu.buttons) do
					texts[i] = button.text
				end
				return texts
			end
			-- Clicks the button with this text, as a mouse click does.
			function menu.click(text)
				for _, button in ipairs(menu.buttons) do
					if button.text == text then
						return button.callback(button.data, { buttonName = "LeftButton" }, menu)
					end
				end
				error("no menu button " .. tostring(text))
			end
			client.menus[#client.menus + 1] = menu
			return menu
		end,
	}

	-- Beside C_Timer.NewTicker, which clientStubs already stubs for the conditions' polls. Each timer runs once: at
	-- client.runTimers, or when client.advance has moved the clock `seconds` on (the fishing grace time), whichever
	-- comes first.
	stubs.C_Timer.After = function(seconds, callback)
		local timer = { seconds = seconds, callback = callback }
		timer.ticker = client.newTicker(seconds, function(ticker)
			ticker:Cancel()
			for i, queued in ipairs(client.timers) do
				if queued == timer then
					table.remove(client.timers, i)
					break
				end
			end
			callback()
		end)
		client.timers[#client.timers + 1] = timer
	end
	-- Runs every timer queued so far, as the next frames would, in order.
	function client.runTimers()
		local due = client.timers
		client.timers = {}
		for _, timer in ipairs(due) do
			timer.ticker:Cancel()
			timer.callback()
		end
	end
end

-- The WoW API the addons call, answering as one fixed character on a US realm, out of combat, with no addon
-- restriction active and no secret values.
---@param client FakeClient
---@return table<string, any>
local function clientStubs(client)
	local stubs
	stubs = {
		CreateFrame = function(frameType, _, parent)
			return newFrame(client, frameType, parent)
		end,
		IsLoggedIn = function()
			return false
		end,
		-- The client's default handler reports an error and carries on; here it fails the spec instead.
		geterrorhandler = function()
			return function(err)
				error(err, 0)
			end
		end,
		-- As the client's: an error goes to whatever geterrorhandler() returns at the time, and the caller carries on.
		securecallfunction = function(fn, ...)
			local results = { pcall(fn, ...) }
			if not results[1] then
				stubs.geterrorhandler()(results[2])
				return
			end
			return unpack(results, 2, table.maxn(results))
		end,
		issecretvalue = function()
			return false
		end,
		InCombatLockdown = function()
			return false
		end,
		C_RestrictedActions = {
			GetAddOnRestrictionState = function()
				return 0 -- Enum.AddOnRestrictionState.Inactive
			end,
		},
		-- The forever dump's LuaEnum.lua at BIR_COMMIT (scripts/tools.env).
		Enum = {
			AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
			AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
			AddOnEnableState = { None = 0, Some = 1, All = 2 },
		},
		-- No area has a name, so the area index Core builds at PLAYER_LOGIN is empty.
		C_Map = {
			GetAreaInfo = function()
				return nil
			end,
			GetBestMapForUnit = function()
				return nil
			end,
		},
		-- The conditions service's reads (LOG-R20, LOG-R45–R47): realm 08:15 on Sunday 11 October 2026 (a US Pacific
		-- realm, GetServerTime's 15:15 UTC), no zone text, no lure, no calendar event, no aura; Fishing is below.
		GetRealZoneText = function()
			return ""
		end,
		GetSubZoneText = function()
			return ""
		end,
		GetInstanceInfo = function()
			return "Kalimdor", "none", 0, "", 0, 0, false, 1, 0, nil, false
		end,
		GetGameTime = function()
			return 8, 15
		end,
		GetWeaponEnchantInfo = function()
			return false, nil, nil, nil, false, nil, nil, nil, false, nil, nil, nil
		end,
		C_DateAndTime = {
			GetCurrentCalendarTime = function()
				return { year = 2026, month = 10, monthDay = 11, weekday = 1, hour = 8, minute = 15 }
			end,
		},
		C_Calendar = {
			OpenCalendar = function() end,
			GetMonthInfo = function()
				return { year = 2026, month = 10, numDays = 31, firstWeekday = 5 }
			end,
			GetNumDayEvents = function()
				return 0
			end,
			GetDayEvent = function()
				return nil
			end,
		},
		C_UnitAuras = {
			GetPlayerAuraBySpellID = function()
				return nil
			end,
		},
		C_Timer = {
			NewTicker = function(seconds, callback)
				return client.newTicker(seconds, callback)
			end,
			-- C_Timer.After is with the menu stubs, which queue it for client.runTimers too.
		},
		GetTime = function()
			return client.time()
		end,
		-- The loot window (LOG-R3), from client.loot.
		IsFishingLoot = function()
			return client.loot.fishing
		end,
		GetNumLootItems = function()
			return #client.loot.slots
		end,
		GetLootSlotLink = function(slot)
			local entry = client.loot.slots[slot]
			return entry and entry.link
		end,
		-- icon, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive, isCoin
		GetLootSlotInfo = function(slot)
			local entry = client.loot.slots[slot]
			if entry then
				return 136245, "", entry.quantity, entry.currencyID, 1, false, false, nil, false, entry.isCoin == true
			end
		end,
		-- GlobalStrings/enUS.lua at BIR_COMMIT (scripts/tools.env).
		ERR_FISH_ESCAPED = "Your fish got away!",
		-- Reads client.addons. Folder names as the client takes them; an addon not listed is missing.
		C_AddOns = {
			GetAddOnInfo = function(name)
				if client.addons[name] then
					return name, name, "", true, nil
				end
				return name, nil, nil, false, "MISSING"
			end,
			-- Enum.AddOnEnableState: None 0, All 2. Enabled only for the player's own character.
			GetAddOnEnableState = function(name, character)
				local addon = client.addons[name]
				return (addon and addon.enabled ~= false and character == PLAYER_GUID) and 2 or 0
			end,
			IsAddOnLoaded = function(name)
				local addon = client.addons[name]
				local loaded = addon ~= nil and (addon.loaded or (addon.loaded == nil and addon.enabled ~= false))
				return loaded, loaded
			end,
			GetAddOnMetadata = function(name, field)
				local addon = client.addons[name]
				return addon and addon.metadata and addon.metadata[field]
			end,
		},
		UnitGUID = function(unit)
			return unit == "player" and PLAYER_GUID or nil
		end,
		GetLocale = function()
			return "enUS"
		end,
		UnitFactionGroup = function()
			return "Alliance", "Alliance"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitRace = function()
			return "Human", "Human", 1
		end,
		GetServerTime = function()
			return 1791731700 -- 2026-10-11 15:15:00 UTC
		end,
		UnitNameUnmodified = function()
			return "Angler"
		end,
		-- Forever answers with the first name and the surname (probes/fishing-signals/results/2026-10-11-build70338-report.md).
		UnitName = function()
			return "Angler", "Tester"
		end,
		-- The probe's build, and a character whose one profession is Fishing (skill line 356) at 75/150.
		GetBuildInfo = function()
			return "1.60.1", "70338", "Oct  9 2026", 16001, "", " "
		end,
		GetProfessions = function()
			return nil, nil, nil, 8, nil
		end,
		GetProfessionInfo = function(index)
			if index == 8 then
				return "Fishing", 136245, 75, 150, 2, 34, 356, 0, -1, 0, "Fishing"
			end
		end,
		GetRealmName = function()
			return "Testrealm"
		end,
		GetCurrentRegion = function()
			return 1
		end,
		GetCurrentRegionName = function()
			return "US"
		end,
	}
	settingsStubs(client, stubs)
	menuStubs(client, stubs)
	return stubs
end

-- The game side QoL reads and binds: bindings, held keys, casts, the main hand, the frame loop.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local addGameStubs = dofile("spec/support/fake_game.lua")
-- Popups and addon switches, for QoL's conflict popup.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local addPopupStubs = dofile("spec/support/fake_popup.lua")
-- Tooltip data hooks, for the diagnostics buffer's hovers.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local addTooltipStubs = dofile("spec/support/fake_tooltip.lua")

--- A TOC: the files it lists, in order, as paths relative to the addon folder with forward slashes, and its
--- `## Field: value` lines by field.
---@param tocPath string
---@return string[] files
---@return table<string, string> fields
local function readToc(tocPath)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local toc = assert(io.open(tocPath, "r"))
	local files, fields = {}, {}
	for line in toc:lines() do
		line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
		local field, value = line:match("^##%s*([^:]-)%s*:%s*(.-)$")
		if field then
			fields[field] = value
		elseif line ~= "" and line:sub(1, 1) ~= "#" then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	toc:close()
	return files, fields
end

--- The files addons/<name>/<name>.toc lists, in order, relative to the addon folder with forward slashes
--- ("logic/Modules.lua").
---@param name string
---@return string[]
function addonFiles(name)
	return (readToc("addons/" .. name .. "/" .. name .. ".toc"))
end

--- Loads addons/<name>/<name>.toc and every file it lists, in order, as the client does, then fires
--- ADDON_LOADED(name). Each addon its `## Dependencies` names is loaded first, the same way and into the same
--- globals and fake client, as the client loads them: `loadAddon("Pagle_QoL")` runs Core, then QoL.
--- Each addon loaded is listed in client.addons, enabled and loaded, with its TOC fields as its metadata, and the
--- bindings its Bindings.xml names are added to client.bindings.
--- Raises an error naming the TOC and the file if a listed file is missing or fails while loading.
---@param name string The addon's folder under addons/, which is also its TOC's name.
---@param globals table<string, any>? Globals the client defines for this load, e.g. WOW_PROJECT_ID. They replace
--- the fake client's stubs of the same name, e.g. InCombatLockdown for a load in combat.
---@param options { holdAddonLoaded: boolean?, dependencyLibsOnly: boolean? }? holdAddonLoaded: don't fire
--- ADDON_LOADED(name); the spec fires it with loaded.client.fire, e.g. after adding a listener that must be there
--- before it. dependencyLibsOnly: load only the libs/ files of each dependency, for a stand-in that provides the
--- rest (FakePagle's fake.load).
---@return LoadedAddon
function loadAddon(name, globals, options)
	options = options or {}
	local printed = {}

	local client = newClient()
	local env = clientStubs(client)
	addGameStubs(client, env)
	addPopupStubs(client, env)
	addTooltipStubs(client, env)
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		printed[#printed + 1] = table.concat(parts, " ")
	end
	for key, value in pairs(globals or {}) do
		env[key] = value
	end
	env._G = env
	setmetatable(env, { __index = _G })

	local namespaces = {}
	-- Loads one addon after its dependencies; returns why it failed, or nil.
	local function load(addon, isDependency)
		local dir = "addons/" .. addon .. "/"
		local toc = dir .. addon .. ".toc"
		local files, fields = readToc(toc)
		for dependency in (fields.Dependencies or ""):gmatch("[^%s,]+") do
			if not namespaces[dependency] then
				local err = load(dependency, true)
				if err then
					return err
				end
			end
		end

		client.addons[addon] = { enabled = true, loaded = true, metadata = fields }
		-- The client reads an addon's Bindings.xml by name, not from its TOC.
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local bindingsXml = io.open(dir .. "Bindings.xml", "r")
		if bindingsXml then
			for binding in bindingsXml:read("*a"):gsub("<!%-%-.-%-%->", ""):gmatch('<Binding%s[^>]*name="([^"]+)"') do
				client.bindings[#client.bindings + 1] = binding
			end
			bindingsXml:close()
		end
		local ns = {}
		namespaces[addon] = ns
		for _, file in ipairs(files) do
			if not (isDependency and options.dependencyLibsOnly) or file:match("^libs/") then
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
				local chunk, loadErr = loadfile(dir .. file)
				if not chunk then
					return ("%s lists %s, which doesn't load: %s"):format(toc, file, loadErr)
				end
				setfenv(chunk, env)
				local ok, runErr = pcall(chunk, addon, ns)
				if not ok then
					return ("%s: %s failed while loading: %s"):format(toc, file, tostring(runErr))
				end
			end
		end
		if isDependency or not options.holdAddonLoaded then
			client.fire("ADDON_LOADED", addon)
		end
		return nil
	end
	local err = load(name, false)
	if err then
		error(err, 2)
	end

	return { ns = namespaces[name], namespaces = namespaces, env = env, printed = printed, client = client }
end

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
dofile("spec/support/fake_pagle.lua")
