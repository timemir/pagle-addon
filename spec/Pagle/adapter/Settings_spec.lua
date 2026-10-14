-- Core's Settings category: the root, the Module status list, topic pages built from M:AddSetting rows, and
-- Pagle.OpenSettings (CORE-R32, CORE-R33, CORE-R40–R44; settings.md SET-R1–R5, SET-R10–R12, SET-R60–R62,
-- SET-R70, SET-R90–R96).

-- Loads Core with the given roster Modules installed on the fake client, by roster name: { QoL = {} } puts
-- Pagle_QoL in client.addons, enabled and loaded unless it says otherwise, with X-Pagle-API 1 and version 1.2.3.
local function loadWith(modules, extra)
	local loaded = loadAddon("Pagle", foreverWith(extra))
	for name, addon in pairs(modules or {}) do
		addon.metadata = addon.metadata or { ["X-Pagle-API"] = "1", Version = "1.2.3" }
		loaded.client.addons["Pagle_" .. name] = addon
	end
	return loaded
end

-- Every text a shown page's rows display, in order: row names for native rows, the widgets' texts for Core's own.
local function pageTexts(loaded, category)
	local texts = {}
	for _, row in ipairs(loaded.client.settings.show(category)) do
		local own = loaded.client.settings.textsOf(row.frame)
		if #own > 0 then
			for _, text in ipairs(own) do
				texts[#texts + 1] = text
			end
		elseif row.initializer:GetName() then
			texts[#texts + 1] = row.initializer:GetName()
		end
	end
	return texts
end

-- Whether `list` holds `value`.
local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

describe("The Settings root with no Module On", function()
	it(
		"registers one Pagle category under AddOns at ModulesChanged, with only Core's Announcements page (CORE-R40, SET-R1)",
		function()
			local loaded = loadWith()
			assert.is_nil(loaded.client.settings.category("Pagle"))

			loaded.client.fire("PLAYER_LOGIN")

			local settings = loaded.client.settings
			assert.are.equal(1, #settings.addOnCategories)
			assert.are.equal("Pagle", settings.addOnCategories[1].name)
			-- The Announcements page: spec/Pagle/adapter/AnnouncementSettings_spec.lua.
			assert.are.same({ "Pagle", "Announcements" }, { settings.categories[1].name, settings.categories[2].name })
			assert.are.equal(2, #settings.categories)
		end
	)

	it("draws its own rows from Core's template, each through its frame's Init (SET-R5, SET-R6)", function()
		local loaded = loadWith()
		loaded.client.fire("PLAYER_LOGIN")

		local own = {}
		for _, row in ipairs(loaded.client.settings.show(assert(loaded.client.settings.category("Pagle")))) do
			if row.initializer:GetTemplate() == "PagleSettingsRowTemplate" then
				own[#own + 1] = loaded.client.settings.textsOf(row.frame)[1]
			end
		end

		-- The paragraph, the five status rows and the note: the fake panel draws a row of a template only through
		-- its XML mixin's Init, and raises an error if Core writes InitFrame, Resetter or GetExtent onto an
		-- initializer (spec/support/settings.lua).
		local template = assert(loaded.client.templates.PagleSettingsRowTemplate, "Core's XML defines the template")
		assert.are.equal("PagleSettingsRowMixin", template.mixin)
		assert.are.same({
			"Recording your Catches. Enable a Module to see them.",
			"Ledger",
			"Hunts",
			"Stats",
			"Tackle Board",
			"QoL",
			"Turn Modules on or off in the AddOns list.",
		}, own)
	end)

	it(
		"shows the paragraph, the Modules header, the five roster names Not installed and the note (SET-R10, SET-R11, CORE-R41)",
		function()
			local loaded = loadWith()
			loaded.client.fire("PLAYER_LOGIN")

			local texts = pageTexts(loaded, loaded.client.settings.category("Pagle"))

			assert.are.equal("Recording your Catches. Enable a Module to see them.", texts[1])
			assert.are.equal("Modules", texts[2])
			-- The note, then Saving's header and row (spec/Pagle/adapter/ReloadReminder_spec.lua).
			assert.are.same({
				"Turn Modules on or off in the AddOns list.",
				"Saving",
				"Remind me to /reload when Casts are unsaved",
			}, { texts[#texts - 2], texts[#texts - 1], texts[#texts] })
			for _, name in ipairs({ "Ledger", "Hunts", "Stats", "Tackle Board", "QoL" }) do
				assert.is_true(contains(texts, name))
			end
			local notInstalled = 0
			for _, text in ipairs(texts) do
				notInstalled = notInstalled + (text == "Not installed" and 1 or 0)
			end
			assert.are.equal(5, notInstalled)
		end
	)
end)

-- Registers a fake QoL (def.order 50) and returns its handle. `def` overrides its def fields.
local function registerQoL(loaded, def)
	local full = { name = "QoL", title = "QoL", order = 50 }
	for key, value in pairs(def or {}) do
		full[key] = value
	end
	return loaded.env.Pagle.RegisterModule(full)
end

-- QoL's Fishing rows as SET-R20 starts them in M1: its Casting header and the Fishing key.
local function addFishingRows(M)
	M:AddSetting("fishing", { kind = "header", label = "Casting" })
	M:AddSetting("fishing", { kind = "keybinding", label = "Fishing key", binding = "PAGLE_FISHING_KEY" })
end

-- Loads Core with QoL installed and its Fishing key binding known to the client.
local function loadWithQoL(extra)
	local loaded = loadWith({ QoL = {} }, extra)
	loaded.client.bindings = { "MOVEFORWARD", "PAGLE_FISHING_KEY" }
	return loaded
end

-- The names of a page's rows, as initializers carry them, in order; a keybinding row by its search label.
local function rowNames(category)
	local names = {}
	for i, initializer in ipairs(category.layout.initializers) do
		names[i] = initializer:GetName() or initializer.searchTags[1]
	end
	return names
end

-- The error `fn` raises, or "" if it raises none.
local function errorOf(fn)
	local ok, err = pcall(fn)
	return ok and "" or tostring(err)
end

describe("A topic page", function()
	it("registers under the root once a Module adds rows to it (CORE-R42, SET-R1)", function()
		local loaded = loadWithQoL()
		addFishingRows(registerQoL(loaded))

		loaded.client.fire("PLAYER_LOGIN")

		local fishing = assert(loaded.client.settings.category("Fishing"))
		assert.is_table(fishing)
		assert.are.equal(loaded.client.settings.category("Pagle"), fishing.parent)
		assert.are.equal(3, #loaded.client.settings.categories) -- the root, Fishing and Announcements
	end)

	it("isn't registered while the Module that has its rows isn't On (CORE-R42, SET-R4, SET-R90)", function()
		local loaded = loadWith({ QoL = { enabled = false, loaded = false } })

		loaded.client.fire("PLAYER_LOGIN")

		assert.is_nil(loaded.client.settings.category("Fishing"))
	end)

	it("leaves out the Module's header when its first row is a header (CORE-R42, SET-R3, SET-R20)", function()
		local loaded = loadWithQoL()
		addFishingRows(registerQoL(loaded))
		loaded.client.fire("PLAYER_LOGIN")

		local fishing = assert(loaded.client.settings.category("Fishing"))

		assert.are.same({ "Casting", "FISHING KEY" }, rowNames(fishing))
		assert.are.equal(2, fishing.layout.initializers[2].data.bindingIndex)
	end)

	it("puts each Module's rows under a header with its title, in def.order (CORE-R42, SET-R3)", function()
		local loaded = loadWith({ QoL = {}, Stats = {} })
		local qol = registerQoL(loaded)
		local stats = loaded.env.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
		local function checkbox(label)
			return { kind = "checkbox", id = "tracker", label = label, get = function() end, set = function() end }
		end
		-- QoL adds first; Stats still comes first by def.order. Both use the id "tracker": ids are per Module.
		qol:AddSetting("trackers", checkbox("QoL's"))
		stats:AddSetting("trackers", checkbox("Stats'"))
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({ "Stats", "Stats'", "QoL", "QoL's" }, rowNames(loaded.client.settings.category("Trackers")))
	end)

	it("indents a row under its parent, a row of the same Module (CORE-R42, SET-R2)", function()
		local loaded = loadWith({ QoL = {}, Stats = {} })
		local qol = registerQoL(loaded)
		local stats = loaded.env.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
		local function row(id, parent)
			return { kind = "button", id = id, parent = parent, label = id, onClick = function() end }
		end
		stats:AddSetting("trackers", row("tracker"))
		qol:AddSetting("trackers", row("tracker"))
		qol:AddSetting("trackers", row("child", "tracker"))
		loaded.client.fire("PLAYER_LOGIN")

		local initializers = loaded.client.settings.category("Trackers").layout.initializers
		-- Stats header, Stats' tracker, QoL header, QoL's tracker, QoL's child.
		assert.are.equal(initializers[4], initializers[5]:GetParentInitializer())
		assert.is_nil(initializers[4]:GetParentInitializer())
	end)
end)

describe("M:AddSetting", function()
	it("raises an error at the caller for an unknown topic or kind, registering nothing (CORE-R42)", function()
		local loaded = loadWithQoL()
		local M = registerQoL(loaded)

		assert.matches(
			"Settings_spec%.lua:%d+: .*unknown topic look",
			errorOf(function()
				M:AddSetting("look", { kind = "header", label = "Casting" })
			end)
		)
		assert.matches(
			"Settings_spec%.lua:%d+: .*unknown kind toggle",
			errorOf(function()
				M:AddSetting("fishing", { kind = "toggle", label = "Casting" })
			end)
		)
		loaded.client.fire("PLAYER_LOGIN")
		assert.is_nil(loaded.client.settings.category("Fishing"))
	end)

	it("raises an error at the caller for a missing label or a field its kind requires (CORE-R42)", function()
		local loaded = loadWithQoL()
		local M = registerQoL(loaded)

		assert.matches(
			"Settings_spec%.lua:%d+: .*a setting needs a label",
			errorOf(function()
				M:AddSetting("fishing", { kind = "header" })
			end)
		)
		assert.matches(
			"Settings_spec%.lua:%d+: .*a slider setting needs step, a number",
			errorOf(function()
				M:AddSetting("fishing", {
					kind = "slider",
					label = "Volume",
					get = function() end,
					set = function() end,
					min = 0,
					max = 1,
				})
			end)
		)
		assert.matches(
			"Settings_spec%.lua:%d+: .*a keybinding setting needs binding, a string",
			errorOf(function()
				M:AddSetting("fishing", { kind = "keybinding", label = "Fishing key" })
			end)
		)
	end)

	it("raises an error at the caller for an id the Module already used on that page (CORE-R42)", function()
		local loaded = loadWithQoL()
		local M = registerQoL(loaded)
		M:AddSetting("fishing", { kind = "header", id = "casting", label = "Casting" })
		-- The same id on another page is fine.
		M:AddSetting("trackers", { kind = "header", id = "casting", label = "Casting" })

		assert.matches(
			"Settings_spec%.lua:%d+: .*id casting is already used on fishing",
			errorOf(function()
				M:AddSetting("fishing", { kind = "header", id = "casting", label = "Again" })
			end)
		)
	end)

	it(
		"raises an error at the caller for a parent naming none of the Module's earlier rows there (CORE-R42)",
		function()
			local loaded = loadWith({ QoL = {}, Stats = {} })
			local qol = registerQoL(loaded)
			local stats = loaded.env.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
			stats:AddSetting("fishing", { kind = "header", id = "casting", label = "Stats' row" })
			qol:AddSetting("trackers", { kind = "header", id = "casting", label = "On another page" })

			assert.matches(
				"Settings_spec%.lua:%d+: .*parent casting names none",
				errorOf(function()
					qol:AddSetting("fishing", { kind = "header", parent = "casting", label = "Fishing key" })
				end)
			)
		end
	)

	it("reports a late call through geterrorhandler(), in ns.L's words, and drops it (CORE-R42, CORE-R8)", function()
		local loaded = loadWithQoL()
		local M = registerQoL(loaded)
		addFishingRows(M)
		loaded.client.fire("PLAYER_LOGIN")
		local reported = {}
		loaded.env.geterrorhandler = function()
			return function(err)
				reported[#reported + 1] = err
			end
		end

		M:AddSetting("fishing", { kind = "header", label = "Late" })
		-- Even a call that would raise is only reported once late.
		M:AddSetting("look", { kind = "toggle" })

		assert.are.equal(2, #reported)
		local late = loaded.ns.L.SETTING_TOO_LATE:format("QoL")
		assert.are.same({ late, late }, reported)
		assert.are.equal("Pagle: QoL's AddSetting came after ModulesChanged, so the row is dropped", late)
		assert.are.same({ "Casting", "FISHING KEY" }, rowNames(loaded.client.settings.category("Fishing")))
	end)
end)

describe("Pagle.OpenSettings", function()
	it("opens the root, and a topic page once it is registered (CORE-R43, SET-R75)", function()
		local loaded = loadWithQoL()
		addFishingRows(registerQoL(loaded))
		loaded.client.fire("PLAYER_LOGIN")

		loaded.env.Pagle.OpenSettings()
		loaded.env.Pagle.OpenSettings("fishing")

		assert.are.same({ "Pagle", "Fishing" }, openedNames(loaded))
	end)

	it("opens the root for an unknown topic or one whose page isn't registered (CORE-R43)", function()
		local loaded = loadWithQoL()
		registerQoL(loaded)
		loaded.client.fire("PLAYER_LOGIN")

		for _, topic in ipairs({ "fishing", "look", "trackers", "Fishing", 5 }) do
			loaded.env.Pagle.OpenSettings(topic)
		end

		assert.are.same({ "Pagle", "Pagle", "Pagle", "Pagle", "Pagle" }, openedNames(loaded))
	end)

	it("prints CORE-R33's line while restricted and opens nothing (CORE-R33, SET-R75)", function()
		local loaded = loadWithQoL()
		addFishingRows(registerQoL(loaded))
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)

		loaded.env.Pagle.OpenSettings()
		loaded.env.Pagle.OpenSettings("fishing")

		assert.are.same({}, openedNames(loaded))
		assert.are.same({ "Pagle: settings open after combat.", "Pagle: settings open after combat." }, loaded.printed)
	end)
end)

-- Shows the root and returns its status list's frames, a row per roster Module, each found by "Modules".
local function showStatusList(loaded)
	local settings = loaded.client.settings
	local frames = {}
	for _, row in ipairs(settings.show(settings.category("Pagle"))) do
		if row.initializer.searchTags[1] == "MODULES" then
			frames[#frames + 1] = row.frame
		end
	end
	return frames
end

-- The texts of the status list, read by showing the root now, in order.
local function statusTexts(loaded)
	local texts = {}
	for _, frame in ipairs(showStatusList(loaded)) do
		for _, text in ipairs(loaded.client.settings.textsOf(frame)) do
			texts[#texts + 1] = text
		end
	end
	return texts
end

-- The shown buttons of the status list, read by showing the root now.
local function statusButtons(loaded)
	local buttons = {}
	for _, frame in ipairs(showStatusList(loaded)) do
		for _, button in ipairs(loaded.client.settings.buttonsOf(frame)) do
			buttons[#buttons + 1] = button
		end
	end
	return buttons
end

describe("The status list with a Module On", function()
	it("shows no paragraph, and each Module's name, TOC version and state (SET-R10, SET-R11, CORE-R41)", function()
		local loaded = loadWith({ QoL = {}, Stats = { enabled = false, loaded = false } })
		registerQoL(loaded, { settingsAction = { label = "Fishing settings ›", onClick = function() end } })
		loaded.client.fire("PLAYER_LOGIN")

		local texts = pageTexts(loaded, loaded.client.settings.category("Pagle"))
		local list = statusTexts(loaded)

		assert.are.equal("Modules", texts[1])
		assert.are.same({
			"Ledger",
			"",
			"Not installed",
			"Hunts",
			"",
			"Not installed",
			"Stats",
			"1.2.3",
			"Off",
			"Tackle Board",
			"",
			"Not installed",
			"QoL",
			"1.2.3",
			"On",
			"Fishing settings ›",
		}, list)
	end)

	it("reads a button's label each time the root is shown (CORE-R44, SET-R12)", function()
		local loaded = loadWithQoL()
		local shown = 0
		registerQoL(loaded, {
			settingsAction = {
				label = function()
					shown = shown + 1
					return "Shown " .. shown
				end,
				onClick = function() end,
			},
		})
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.equal("Shown 1", statusButtons(loaded)[1]:GetText())
		assert.are.equal("Shown 2", statusButtons(loaded)[1]:GetText())
	end)

	it("leaves out a button whose label fails, reporting it; the line stays (CORE-R44, SET-R12)", function()
		local loaded = loadWithQoL()
		local reported = {}
		loaded.env.geterrorhandler = function()
			return function(err)
				reported[#reported + 1] = err
			end
		end
		registerQoL(loaded, {
			settingsAction = {
				label = function()
					error("no label yet")
				end,
				onClick = function() end,
			},
		})
		loaded.client.fire("PLAYER_LOGIN")

		local list = statusTexts(loaded)

		assert.are.same({}, statusButtons(loaded))
		assert.are.same({ "QoL", "1.2.3", "On" }, { unpack(list, #list - 2) })
		assert.are.equal(2, #reported) -- the label is read each time the root is shown
		assert.matches("no label yet", reported[1], 1, true)
	end)

	it("labels a Module's button Open {label} for its first view, without settingsAction (CORE-R44)", function()
		local loaded = loadWith({ Hunts = {} })
		loaded.env.Pagle.RegisterModule({
			name = "Hunts",
			title = "Hunts",
			order = 20,
			views = { { id = "board", label = "Hunts", open = function() end } },
		})
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.equal("Open Hunts", statusButtons(loaded)[1]:GetText())
	end)

	it("moves the panel to Fishing on QoL's button, without closing it (SET-R11, SET-R12)", function()
		local loaded = loadWithQoL()
		local Pagle = loaded.env.Pagle
		local M = registerQoL(loaded, {
			settingsAction = {
				label = "Fishing settings ›",
				onClick = function()
					Pagle.OpenSettings("fishing")
				end,
			},
		})
		addFishingRows(M)
		loaded.client.fire("PLAYER_LOGIN")
		Pagle.OpenSettings()

		statusButtons(loaded)[1]:Click()

		assert.are.same({ "Pagle", "Fishing" }, openedNames(loaded))
		assert.is_true(loaded.client.settings.panel:IsShown())
	end)

	it("prints CORE-R33's line on QoL's button while restricted, the panel staying on the root (SET-R12)", function()
		local loaded = loadWithQoL()
		local Pagle = loaded.env.Pagle
		addFishingRows(registerQoL(loaded, {
			settingsAction = {
				label = "Fishing settings ›",
				onClick = function()
					Pagle.OpenSettings("fishing")
				end,
			},
		}))
		loaded.client.fire("PLAYER_LOGIN")
		Pagle.OpenSettings()
		local button = statusButtons(loaded)[1]
		setCombat(loaded, true)

		button:Click()

		assert.are.same({ "Pagle" }, openedNames(loaded))
		assert.is_true(loaded.client.settings.panel:IsShown())
		assert.are.same({ "Pagle: settings open after combat." }, loaded.printed)
	end)

	it("closes the panel before opening a Module's view (SET-R12)", function()
		local loaded = loadWith({ Hunts = {} })
		local panelShownAtOpen
		loaded.env.Pagle.RegisterModule({
			name = "Hunts",
			title = "Hunts",
			order = 20,
			views = {
				{
					id = "board",
					label = "Hunts",
					open = function()
						panelShownAtOpen = loaded.client.settings.panel:IsShown()
					end,
				},
			},
		})
		loaded.client.fire("PLAYER_LOGIN")
		loaded.env.Pagle.OpenSettings()

		statusButtons(loaded)[1]:Click()

		assert.is_false(panelShownAtOpen)
	end)

	it("shows no button for a Module that isn't On (SET-R11)", function()
		local loaded = loadWith({ QoL = { enabled = false, loaded = false }, Ledger = {} })
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({}, statusButtons(loaded))
	end)
end)

describe("A Module's value rows", function()
	-- Loads Core with QoL On and `settings` added to Trackers, and returns the page once registered.
	local function trackersWith(settings)
		local loaded = loadWithQoL()
		local M = registerQoL(loaded)
		for _, setting in ipairs(settings) do
			M:AddSetting("trackers", setting)
		end
		loaded.client.fire("PLAYER_LOGIN")
		return loaded, loaded.client.settings.category("Trackers")
	end

	it("give the page's Defaults button each row's default (SET-R60)", function()
		local _, page = trackersWith({
			{ kind = "checkbox", label = "Show", default = true, get = function() end, set = function() end },
			{
				kind = "slider",
				label = "Per",
				default = 5,
				min = 1,
				max = 15,
				step = 1,
				get = function() end,
				set = function() end,
			},
			{
				kind = "dropdown",
				label = "Lures",
				default = "best",
				options = function()
					return { { value = "best", label = "Best" } }
				end,
				get = function() end,
				set = function() end,
			},
		})

		local defaults = {}
		for i = 2, 4 do -- after the QoL header
			defaults[#defaults + 1] = page.layout.initializers[i]:GetSetting():GetDefaultValue()
		end
		assert.are.same({ true, 5, "best" }, defaults)
	end)

	it("read get each time the page is shown, and write through set (SET-R62)", function()
		local value = false
		local loaded, page = trackersWith({
			{
				kind = "checkbox",
				label = "Show",
				default = false,
				get = function()
					return value
				end,
				set = function(new)
					value = new
				end,
			},
		})
		value = true -- changed outside Settings

		local rows = loaded.client.settings.show(page)
		assert.is_true(rows[2].frame.value)
		rows[2].initializer:GetSetting():SetValue(false)

		assert.is_false(value)
		assert.is_false(loaded.client.settings.show(page)[2].frame.value)
	end)

	it("re-evaluate isEnabled each time the page is shown (SET-R61)", function()
		local live = false
		local loaded, page = trackersWith({
			{
				kind = "button",
				label = "Reset",
				onClick = function() end,
				isEnabled = function()
					return live
				end,
			},
		})

		assert.is_false(loaded.client.settings.show(page)[2].frame.enabled)
		live = true
		assert.is_true(loaded.client.settings.show(page)[2].frame.enabled)
	end)

	it("offer a dropdown's options read each time it opens (SET-R62)", function()
		local options = { { value = 1, label = "One" } }
		local _, page = trackersWith({
			{
				kind = "dropdown",
				label = "Lure",
				get = function()
					return 1
				end,
				set = function() end,
				options = function()
					return options
				end,
			},
		})
		local read = page.layout.initializers[2].data.options

		options = { { value = 1, label = "One" }, { value = 2, label = "Two" } }

		assert.are.same({ "number", 2 }, { page.layout.initializers[2]:GetSetting():GetVariableType(), #read() })
	end)

	it("build without one that fails, reporting it through geterrorhandler() (SET-R5)", function()
		local loaded = loadWithQoL()
		local reported = {}
		loaded.env.geterrorhandler = function()
			return function(err)
				reported[#reported + 1] = err
			end
		end
		local M = registerQoL(loaded)
		M:AddSetting("fishing", { kind = "keybinding", label = "Swap gear", binding = "PAGLE_SWAP_GEAR" })
		addFishingRows(M)
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({ "QoL", "Casting", "FISHING KEY" }, rowNames(loaded.client.settings.category("Fishing")))
		assert.are.equal(1, #reported)
		assert.matches("no key binding PAGLE_SWAP_GEAR", reported[1])
	end)
end)

describe("A Module's button row", function()
	-- Loads Core with QoL On and `button` added to Trackers; returns the row's initializer and the frame the panel
	-- draws for it.
	local function shown(button)
		local loaded = loadWithQoL()
		registerQoL(loaded):AddSetting("trackers", button)
		loaded.client.fire("PLAYER_LOGIN")
		local row = loaded.client.settings.show(assert(loaded.client.settings.category("Trackers")))[2] -- after the QoL header
		return row.initializer, row.frame, loaded.client.settings
	end

	it("with a caption, shows its label beside a button with the caption (CORE-R42, SET-R2)", function()
		local clicked = 0
		local initializer, frame, settings = shown({
			kind = "button",
			label = "Button position",
			caption = "Reset",
			onClick = function()
				clicked = clicked + 1
			end,
		})

		assert.are.equal("SettingButtonControlTemplate", initializer.template)
		assert.are.same({ "Button position", "Reset" }, settings.textsOf(frame))
		assert.are.same({ "BUTTON POSITION", "RESET" }, initializer.searchTags)
		settings.buttonsOf(frame)[1]:Click()
		assert.are.equal(1, clicked)
	end)

	it("without a caption, puts its label on the button and shows no label, as before (CORE-R42, SET-R2)", function()
		local initializer, frame, settings = shown({
			kind = "button",
			label = "Save what I'm wearing as my fishing set",
			onClick = function() end,
		})

		assert.are.same({ "", "Save what I'm wearing as my fishing set" }, settings.textsOf(frame))
		assert.are.same({ "SAVE WHAT I'M WEARING AS MY FISHING SET" }, initializer.searchTags)
	end)

	it("raises an error at the caller for a caption that isn't a string (CORE-R42)", function()
		local loaded = loadWithQoL()
		local M = registerQoL(loaded)

		assert.matches(
			"Settings_spec%.lua:%d+: .*a button setting's caption is a string",
			errorOf(function()
				M:AddSetting("trackers", { kind = "button", label = "Position", caption = 5, onClick = function() end })
			end)
		)
	end)
end)

describe("Settings registration while restricted", function()
	it("waits for RestrictionChanged(false), then registers with every Module's rows (CORE-R32, SET-R93)", function()
		local loaded = loadWithQoL({
			InCombatLockdown = function()
				return true
			end,
		})
		addFishingRows(registerQoL(loaded))
		loaded.client.fire("PLAYER_LOGIN")
		assert.are.same({}, loaded.client.settings.categories)

		setCombat(loaded, false)

		assert.is_table(loaded.client.settings.category("Pagle"))
		assert.are.same({ "Casting", "FISHING KEY" }, rowNames(loaded.client.settings.category("Fishing")))
	end)
end)
