-- The Announcements page: Core's rows for how Announcements behave, Cozy mode, the Interruption budget, Show every
-- catch and Animations, then its two slot rows, driven through the fake client's Settings panel (settings.md SET-R1, SET-R30, SET-R31, SET-R33,
-- SET-R60, SET-R61; core/announcements.md › Settings, Data; CORE-R32, CORE-R40, CORE-R43). The slot rows themselves:
-- spec/Pagle/adapter/LookAndFeel_spec.lua.

local COZY = "Cozy mode"
local BUDGET = "Interruption budget"
local COUNT = "Interruptions"
local WINDOW = "Per"
local EVERY_CATCH = "Show every catch"
local MOTION = "Animations"
local TOAST_STYLE = "Toast style"
local SOUND_SET = "Sound set"

-- Core, logged in on the fake client, its Settings registered. `modules` installs roster Modules by name, as
-- Settings_spec's loadWith does; `extra` adds globals.
local function core(modules, extra)
	local loaded = loadAddon("Pagle", foreverWith(extra))
	for name, addon in pairs(modules or {}) do
		addon.metadata = addon.metadata or { ["X-Pagle-API"] = "1", Version = "1.2.3" }
		loaded.client.addons["Pagle_" .. name] = addon
	end
	return loaded
end

local function login(loaded)
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The registered Announcements page.
local function page(loaded)
	return assert(loaded.client.settings.category("Announcements"), "no Announcements page")
end

-- The page's row named `label`.
local function row(loaded, label)
	for _, initializer in ipairs(page(loaded).layout.initializers) do
		if initializer:GetName() == label then
			return initializer
		end
	end
	error("no row " .. label)
end

-- PagleDB.profile.announcements, as the rows read and write it.
local function stored(loaded)
	return loaded.ns.db.profile.announcements
end

describe("The Announcements page", function()
	it("registers with no Module On, under the root, after it (SET-R1, CORE-R40)", function()
		local loaded = login(core())

		local names = {}
		for i, category in ipairs(loaded.client.settings.categories) do
			names[i] = category.name
		end
		assert.are.same({ "Pagle", "Announcements", "Look and Feel" }, names)
		assert.are.equal(loaded.client.settings.category("Pagle"), page(loaded).parent)
	end)

	it("comes after Fishing while QoL is On (SET-R1)", function()
		local loaded = core({ QoL = {} })
		loaded.client.bindings = { "PAGLE_FISHING_KEY" }
		local M = loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
		M:AddSetting("fishing", { kind = "keybinding", label = "Fishing key", binding = "PAGLE_FISHING_KEY" })
		login(loaded)

		local names = {}
		for i, category in ipairs(loaded.client.settings.categories) do
			names[i] = category.name
		end
		assert.are.same({ "Pagle", "Fishing", "Announcements", "Look and Feel" }, names)
	end)

	it(
		"holds Core's eight rows in SET-R30's order, each found by its label, ending with the slot rows (SET-R30, SET-R5)",
		function()
			local loaded = login(core())

			local names = {}
			for i, initializer in ipairs(page(loaded).layout.initializers) do
				names[i] = initializer:GetName()
			end
			assert.are.same({ COZY, BUDGET, COUNT, WINDOW, EVERY_CATCH, MOTION, TOAST_STYLE, SOUND_SET }, names)
		end
	)

	it(
		"gives Cozy mode, Interruption budget and Show every catch SET-R30's tooltips, the sliders none (SET-R30)",
		function()
			local loaded = login(core())

			assert.are.equal(
				"Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, silently.",
				row(loaded, COZY):GetTooltip()
			)
			assert.are.equal(
				"When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their "
					.. "ruler. Greyed out in Cozy mode, which holds everything anyway.",
				row(loaded, BUDGET):GetTooltip()
			)
			assert.are.equal(
				"A quiet line for each catch: its name, size band and length. A toast or banner for the same catch shows "
					.. "instead. Greyed out in Cozy mode, which shows nothing.",
				row(loaded, EVERY_CATCH):GetTooltip()
			)
			assert.is_nil(row(loaded, COUNT):GetTooltip())
			assert.is_nil(row(loaded, WINDOW):GetTooltip())
		end
	)

	it("makes Animations a checkbox with its tooltip, never greyed (SET-R30, announcements.md › Motion)", function()
		local loaded = login(core())
		row(loaded, COZY):GetSetting():SetValue(true)

		local motion = row(loaded, MOTION)
		assert.are.same({
			"SettingsCheckboxControlTemplate",
			"Toasts slide in and stamp themselves, banners drop their seal, and the Legend's rays turn. Off, each appears "
				.. "as it settles.",
			true,
		}, { motion.template, motion:GetTooltip(), loaded.client.settings.show(page(loaded))[6].frame.enabled })
	end)

	it(
		"makes Cozy mode, the budget and Show every catch checkboxes, and Interruptions and Per sliders under the budget"
			.. " (SET-R30, SET-R2)",
		function()
			local loaded = login(core())
			local budget = row(loaded, BUDGET)

			assert.are.same({
				"SettingsCheckboxControlTemplate",
				"SettingsCheckboxControlTemplate",
				"SettingsSliderControlTemplate",
				"SettingsSliderControlTemplate",
				"SettingsCheckboxControlTemplate",
			}, {
				row(loaded, COZY).template,
				budget.template,
				row(loaded, COUNT).template,
				row(loaded, WINDOW).template,
				row(loaded, EVERY_CATCH).template,
			})
			assert.is_nil(row(loaded, EVERY_CATCH):GetParentInitializer())
			assert.is_nil(row(loaded, COZY):GetParentInitializer())
			assert.is_nil(budget:GetParentInitializer())
			assert.are.equal(budget, row(loaded, COUNT):GetParentInitializer())
			assert.are.equal(budget, row(loaded, WINDOW):GetParentInitializer())
		end
	)

	it(
		"ranges Interruptions over 1–30 and Per over 1–15 min, each in steps of 1 (SET-R30, settings.md Tunables)",
		function()
			local loaded = login(core())

			local count, window = row(loaded, COUNT).data.options, row(loaded, WINDOW).data.options
			assert.are.same({ 1, 30, 29 }, { count.minValue, count.maxValue, count.steps })
			assert.are.same({ 1, 15, 14 }, { window.minValue, window.maxValue, window.steps })
		end
	)

	it('opens on Pagle.OpenSettings("announcements") (CORE-R43)', function()
		local loaded = login(core())

		loaded.env.Pagle.OpenSettings("announcements")

		assert.are.same({ "Announcements" }, openedNames(loaded))
	end)

	it("registers at RestrictionChanged(false) when it falls due while restricted (CORE-R32, SET-R93)", function()
		local loaded = core(nil, {
			InCombatLockdown = function()
				return true
			end,
		})
		login(loaded)
		assert.is_nil(loaded.client.settings.category("Announcements"))

		setCombat(loaded, false)

		assert.are.equal(8, #page(loaded).layout.initializers)
	end)
end)

describe("Core's Announcements rows", function()
	it(
		"start from the defaults: Cozy off, the budget on, 20 per 5 min, every catch shown, animations on, Torn Page and"
			.. " Driftwood"
			.. " (announcements.md Data, ANN-R13)",
		function()
			local loaded = login(core())

			-- A native row's value, or a slot dropdown's selected good (Core's own row, SET-R51).
			local values = {}
			for i, shown in ipairs(loaded.client.settings.show(page(loaded))) do
				values[i] = shown.frame.value
				for _, child in ipairs(shown.frame.children) do
					if child.kind == "DropdownButton" then
						values[i] = child.selected
					end
				end
			end
			assert.are.same(
				{ false, true, 20, 5, true, true, "core.toaststyle.page", "core.soundset.driftwood" },
				values
			)
			assert.are.same(
				{ cozy = false, everyCatch = true, motion = true, budget = { on = true, count = 20, window = 300 } },
				stored(loaded)
			)
		end
	)

	it("write profile.announcements, Per storing seconds (SET-R30, announcements.md Data)", function()
		local loaded = login(core())

		row(loaded, COZY):GetSetting():SetValue(true)
		row(loaded, BUDGET):GetSetting():SetValue(false)
		row(loaded, COUNT):GetSetting():SetValue(7)
		row(loaded, WINDOW):GetSetting():SetValue(12)
		row(loaded, EVERY_CATCH):GetSetting():SetValue(false)
		row(loaded, MOTION):GetSetting():SetValue(false)

		assert.are.same(
			{ cozy = true, everyCatch = false, motion = false, budget = { on = false, count = 7, window = 720 } },
			stored(loaded)
		)
	end)

	it("read the stored values each time the page is shown, Per in minutes (SET-R62)", function()
		local loaded = login(core())
		stored(loaded).budget.count = 2
		stored(loaded).budget.window = 600
		stored(loaded).everyCatch = false

		local shown = loaded.client.settings.show(page(loaded))

		assert.are.same({ 2, 10, false }, { shown[3].frame.value, shown[4].frame.value, shown[5].frame.value })
	end)

	it("show Per's value as \"{n} min\", and Interruptions' as its number (SET-R30)", function()
		local loaded = login(core())
		local shown = loaded.client.settings.show(page(loaded))

		assert.are.same({ "20", "5 min" }, { shown[3].frame.valueLabel, shown[4].frame.valueLabel })
		row(loaded, WINDOW):GetSetting():SetValue(1)
		assert.are.equal("1 min", shown[4].frame.valueLabel)
	end)
end)

-- Whether each of the five greyable rows is live, as the page shown last draws it: Cozy mode, Interruption budget,
-- Interruptions, Per, Show every catch. The slot rows are never greyed out (SET-R51).
local function live(shown)
	local enabled = {}
	for i = 1, 5 do
		enabled[i] = shown[i].frame.enabled
	end
	return enabled
end

describe("Greying on the Announcements page", function()
	it("greys the other four rows when Cozy mode is turned on, keeping their values (SET-R31)", function()
		local loaded = login(core())
		local shown = loaded.client.settings.show(page(loaded))
		assert.are.same({ true, true, true, true, true }, live(shown))

		row(loaded, COZY):GetSetting():SetValue(true)

		assert.are.same({ true, false, false, false, false }, live(shown))
		assert.are.same(
			{ true, 20, 5, true },
			{ shown[2].frame.value, shown[3].frame.value, shown[4].frame.value, shown[5].frame.value }
		)
		assert.are.same({ on = true, count = 20, window = 300 }, stored(loaded).budget)
	end)

	it(
		"brings the budget, its sliders and Show every catch back when Cozy mode is turned off (SET-R31, SET-R61)",
		function()
			local loaded = login(core())
			row(loaded, COZY):GetSetting():SetValue(true)
			local shown = loaded.client.settings.show(page(loaded))
			assert.are.same({ true, false, false, false, false }, live(shown))

			row(loaded, COZY):GetSetting():SetValue(false)

			assert.are.same({ true, true, true, true, true }, live(shown))
		end
	)

	it("keeps the sliders greyed when Cozy mode is turned off while the budget is off (SET-R31, SET-R61)", function()
		local loaded = login(core())
		local shown = loaded.client.settings.show(page(loaded))
		row(loaded, BUDGET):GetSetting():SetValue(false)
		assert.are.same({ true, true, false, false, true }, live(shown))
		row(loaded, COZY):GetSetting():SetValue(true)

		row(loaded, COZY):GetSetting():SetValue(false)

		assert.are.same({ true, true, false, false, true }, live(shown))
		row(loaded, BUDGET):GetSetting():SetValue(true)
		assert.are.same({ true, true, true, true, true }, live(shown))
	end)

	it("is re-evaluated each time the page is shown (SET-R61)", function()
		local loaded = login(core())
		stored(loaded).cozy = true -- changed outside Settings

		assert.are.same({ true, false, false, false, false }, live(loaded.client.settings.show(page(loaded))))
	end)
end)

describe("The Announcements page's Defaults button", function()
	it(
		"restores Cozy off, the budget on, 20 and 5 min, every catch shown, animations on, greyed rows included (SET-R33,"
			.. " SET-R60)",
		function()
			local loaded = login(core())
			row(loaded, EVERY_CATCH):GetSetting():SetValue(false)
			row(loaded, MOTION):GetSetting():SetValue(false)
			row(loaded, BUDGET):GetSetting():SetValue(false)
			row(loaded, COUNT):GetSetting():SetValue(9)
			row(loaded, WINDOW):GetSetting():SetValue(15)
			row(loaded, COZY):GetSetting():SetValue(true)

			loaded.client.settings.defaults(page(loaded))

			assert.are.same(
				{ cozy = false, everyCatch = true, motion = true, budget = { on = true, count = 20, window = 300 } },
				stored(loaded)
			)
		end
	)

	it("leaves the root's reminder alone (SET-R60)", function()
		local loaded = login(core())
		loaded.ns.db.profile.reloadReminder = true

		loaded.client.settings.defaults(page(loaded))

		assert.is_true(loaded.ns.db.profile.reloadReminder)
	end)
end)
