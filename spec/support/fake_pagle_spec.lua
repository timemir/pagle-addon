-- FakePagle, the Core test double Modules are specced against (CORE-R18). It must behave as Core does for every
-- call it fakes, so each spec here checks it against the rule Core follows.

describe("FakePagle", function()
	it("serves the same API_VERSION as Core (CORE-R13, CORE-R15)", function()
		assert.are.equal(loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle.API_VERSION, newFakePagle().Pagle.API_VERSION)
	end)

	describe("RegisterModule", function()
		it("returns a Module handle, and the Module reads On (CORE-R12, CORE-R41)", function()
			local fake = newFakePagle()

			local handle = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })

			assert.are.equal("QoL", fake.registry:ModuleOf(handle).def.name)
			assert.are.equal("on", fake.moduleState("QoL"))
		end)

		it("raises an error at the caller for a def Core refuses, registering nothing (CORE-R14)", function()
			local fake = newFakePagle()

			local ok, err = pcall(function()
				fake.Pagle.RegisterModule({ name = "QoL", order = 50 })
			end)

			assert.is_false(ok)
			assert.matches("fake_pagle_spec%.lua:%d+: .*title", tostring(err))
			assert.are.equal("failedToStart", fake.moduleState("QoL"))
		end)

		it("leaves a Module with an incompatible X-Pagle-API inert, with Core's chat line (CORE-R13)", function()
			local fake = newFakePagle()
			fake.addons.Pagle_Hunts.metadata["X-Pagle-API"] = "2"

			assert.is_nil(fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 }))
			assert.are.same({ "Pagle: Pagle Hunts needs a newer Pagle." }, fake.printed)
			assert.are.equal("needsNewerPagle", fake.moduleState("Hunts"))
		end)

		it("reads Off and Not installed from fake.addons (CORE-R41)", function()
			local fake = newFakePagle()
			fake.addons.Pagle_Stats.enabled = false
			fake.addons.Pagle_Ledger = nil

			assert.are.equal("off", fake.moduleState("Stats"))
			assert.are.equal("notInstalled", fake.moduleState("Ledger"))
		end)
	end)

	it("fires ModulesChanged once at login (CORE-R19)", function()
		local fake = newFakePagle()
		local fired = 0
		fake.Pagle.RegisterCallback("Spec", "ModulesChanged", function()
			fired = fired + 1
		end)

		fake.login()

		assert.are.equal(1, fired)
		assert.has_error(fake.login)
	end)

	describe("records it hands out", function()
		-- Fires a Core event carrying `record` and returns what the listener received.
		local function handOut(fake, record)
			local got
			fake.Pagle.RegisterCallback("Spec", "TestEvent", function(_, received)
				got = received
			end)
			fake.fire("TestEvent", record)
			return got
		end

		it("raise an error on any write, nested tables included (CORE-R18)", function()
			local fake = newFakePagle()
			local record = { item = 6358, conditions = { events = { 301 } } }
			local got = handOut(fake, record)
			local function writeError(write)
				local ok, err = pcall(write)
				return ok and "" or tostring(err)
			end

			assert.are.equal(6358, got.item)
			assert.matches(
				"item written to a record .*immutable",
				writeError(function()
					got.item = 1
				end)
			)
			assert.matches(
				"size written",
				writeError(function()
					got.size = 1
				end)
			)
			assert.matches(
				"1 written",
				writeError(function()
					got.conditions.events[1] = 2
				end)
			)
			assert.are.same({ item = 6358, conditions = { events = { 301 } } }, record)
		end)

		it("read like the record, through FakePagle's globals for a Module (CORE-R18)", function()
			local fake = newFakePagle()
			local got = handOut(fake, { item = 6358, events = { 301, 302 } })
			local g = fake.globals

			local keys, events = {}, {}
			for key in g.pairs(got) do
				keys[#keys + 1] = key
			end
			table.sort(keys)
			for i, id in g.ipairs(got.events) do
				events[i] = id
			end

			assert.are.equal(6358, got.item)
			assert.are.same({ "events", "item" }, keys)
			assert.are.same({ 301, 302 }, events)
			assert.are.same({ 301, 302 }, { g.unpack(got.events) })
			assert.are.equal(got, handOut(fake, fake.readOnly(got)))
		end)
	end)

	it("leaves a Module's own tables writable through its globals (CORE-R18)", function()
		local g = newFakePagle().globals
		local own = { { count = 1 } }

		for _, entry in g.ipairs(own) do
			entry.count = 2
		end
		for _, entry in g.pairs(own) do
			entry.count = entry.count + 1
		end
		local first = g.unpack(own)
		first.count = first.count + 1

		assert.are.same({ { count = 4 } }, own)
	end)

	it("hands Modules a read-only Pagle global (CORE-R18)", function()
		local fake = newFakePagle()

		assert.has_error(function()
			fake.globals.Pagle.RegisterModule = nil
		end)
		assert.are.equal(fake.Pagle.RegisterModule, fake.globals.Pagle.RegisterModule)
	end)

	it("sets the restriction state, firing RestrictionChanged on each change (CORE-R30)", function()
		local fake = newFakePagle()
		local fired = {}
		fake.Pagle.RegisterCallback("Spec", "RestrictionChanged", function(_, isRestricted)
			fired[#fired + 1] = isRestricted
		end)

		fake.setRestricted(true)
		local during = fake.Pagle.IsRestricted()
		fake.setRestricted(true)
		fake.setRestricted(false)

		assert.is_true(during)
		assert.is_false(fake.Pagle.IsRestricted())
		assert.are.same({ true, false }, fired)
	end)

	it(
		"answers Pagle.IsAnimationsOn from the profile's Animations setting, on by default (announcements.md"
			.. " › Contracts)",
		function()
			local fake = newFakePagle()
			local before = fake.Pagle.IsAnimationsOn()

			fake.profile.announcements.motion = false

			assert.are.same({ true, false }, { before, fake.Pagle.IsAnimationsOn() })
		end
	)

	it(
		"plays Pagle.Animate on the loaded Module's client, settling a hidden owner and resting after, as Core's"
			.. " driver (announcements.md › Contracts)",
		function()
			local fake = newFakePagle()
			local loaded = fake.load("Pagle_QoL")
			local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
			local hidden = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
			local function fade(target)
				return {
					dur = 1,
					ease = fake.Pagle.EASE.linear,
					keys = { { 0, { 0 } }, { 1, { 1 } } },
					apply = function(v)
						target:SetAlpha(v[1])
					end,
				}
			end
			local done = {}
			fake.Pagle.Animate(frame, { fade(frame) })
			fake.Pagle.Animate(hidden, { fade(hidden) }, function()
				done[#done + 1] = "hidden"
			end)

			loaded.client.update(0.5)
			local half = frame.alpha
			hidden:Hide()
			loaded.client.update(0.1)
			fake.Pagle.StopMotion(frame)
			fake.profile.announcements.motion = false
			local off = loaded.env.CreateFrame("Frame")
			fake.Pagle.Animate(off, { fade(off) })

			assert.are.same({ 0.5, 0.6, 1, { "hidden" }, 1 }, { half, frame.alpha, hidden.alpha, done, off.alpha })
		end
	)

	it("fits a window to the loaded Module's screen with Pagle.FitToScreen, again on a UI scale change", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		local frame = loaded.env.CreateFrame("Frame")

		local scale = fake.Pagle.FitToScreen(frame, { width = 800, height = 2064, lift = 10 })
		loaded.env.UIParent:SetSize(1920, 2112)
		loaded.client.fireGameEvent("UI_SCALE_CHANGED")
		local _, relativeTo, _, x, y = frame:GetPoint(1)

		assert.are.same({ 0.5, 1, loaded.env.UIParent, 0, 10 }, { scale, frame:GetScale(), relativeTo, x, y })
	end)

	it("passes WoW events to the handlers Modules registered through Pagle (CORE-R23)", function()
		local fake = newFakePagle()
		local got = {}
		fake.Pagle.RegisterEvent("QoL", "LOOT_OPENED", function(...)
			got[#got + 1] = { ... }
		end)
		fake.Pagle.RegisterUnitEvent("QoL", "UNIT_SPELLCAST_CHANNEL_STOP", "player", function(...)
			got[#got + 1] = { ... }
		end)

		fake.fireGameEvent("LOOT_OPENED", false)
		fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")
		fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
		fake.Pagle.UnregisterEvent("QoL", "LOOT_OPENED")
		fake.fireGameEvent("LOOT_OPENED", false)

		assert.are.same({ { "LOOT_OPENED", false }, { "UNIT_SPELLCAST_CHANNEL_STOP", "player" } }, got)
	end)

	describe("M:AddSetting", function()
		-- A fake with QoL registered; returns the fake and QoL's handle.
		local function withQoL()
			local fake = newFakePagle()
			return fake, fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
		end

		it("builds the page Core would at ModulesChanged, with Core's header rule (CORE-R42, SET-R3)", function()
			local fake, M = withQoL()
			local stats = fake.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
			M:AddSetting("fishing", { kind = "header", label = "Casting" })
			M:AddSetting(
				"fishing",
				{ kind = "keybinding", id = "key", label = "Fishing key", binding = "PAGLE_FISHING_KEY" }
			)
			M:AddSetting("fishing", { kind = "button", parent = "key", label = "Reset", onClick = function() end })
			stats:AddSetting("fishing", { kind = "button", label = "Stats'", onClick = function() end })
			assert.is_nil(fake.settingsPage("fishing"))

			fake.login()

			local page = {}
			for i, row in ipairs(assert(fake.settingsPage("fishing"))) do
				page[i] = { row.module, row.kind, row.label, row.indented }
			end
			assert.are.same({
				{ "Stats", "header", "Stats", false },
				{ "Stats", "button", "Stats'", false },
				{ "QoL", "header", "Casting", false },
				{ "QoL", "keybinding", "Fishing key", false },
				{ "QoL", "button", "Reset", true },
			}, page)
			assert.is_nil(fake.settingsPage("trackers"))
		end)

		it("ends a Module's Trackers section with its Trackers slot, as Core does (SET-R44, CORE-R42)", function()
			local fake = newFakePagle()
			local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			local stats = fake.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
			local function checkbox(label)
				return { kind = "checkbox", label = label, get = function() end, set = function() end }
			end
			hunts:AddSetting("trackers", checkbox("Show the Hunts tracker"))
			hunts:RegisterSlot({ id = "hunts.trackerframe", label = "Hunts tracker frame", category = "Trackers" })
			hunts:RegisterGood({
				id = "hunts.trackerframe.none",
				slot = "hunts.trackerframe",
				name = "None",
				default = true,
			})
			stats:AddSetting("trackers", checkbox("Show the live tracker"))

			fake.login()

			local page = {}
			for i, row in ipairs(assert(fake.settingsPage("trackers"))) do
				page[i] = { row.module, row.kind, row.label, row.indented, row.slot }
			end
			assert.are.same({
				{ "Hunts", "header", "Hunts", false },
				{ "Hunts", "checkbox", "Show the Hunts tracker", false },
				{ "Hunts", "slot", "Hunts tracker frame", false, "hunts.trackerframe" },
				{ "Stats", "header", "Stats", false },
				{ "Stats", "checkbox", "Show the live tracker", false },
			}, page)
		end)

		it("gives a button row its caption, nil without one, as Core draws them (CORE-R42, SET-R2)", function()
			local fake, M = withQoL()
			M:AddSetting("fishing", { kind = "header", label = "Casting" })
			M:AddSetting(
				"fishing",
				{ kind = "button", label = "Position", caption = "Reset", onClick = function() end }
			)
			M:AddSetting("fishing", { kind = "button", label = "Save", onClick = function() end })
			fake.login()

			local page = assert(fake.settingsPage("fishing"))
			assert.are.same({ "Position", "Reset" }, { page[2].label, page[2].caption })
			assert.are.same({ "Save" }, { page[3].label, page[3].caption })
		end)

		it("raises an error at the caller for a row Core refuses (CORE-R42)", function()
			local _, M = withQoL()
			M:AddSetting("fishing", { kind = "header", id = "casting", label = "Casting" })

			for _, call in ipairs({
				{ "look", { kind = "header", label = "Casting" } },
				{ "fishing", { kind = "toggle", label = "Casting" } },
				{ "fishing", { kind = "header", id = "casting", label = "Again" } },
				{ "fishing", { kind = "header", parent = "gear", label = "Swap" } },
				{ "fishing", { kind = "button", label = "Position", caption = true, onClick = function() end } },
			}) do
				local ok, err = pcall(function()
					M:AddSetting(call[1], call[2])
				end)
				assert.is_false(ok)
				assert.matches("fake_pagle_spec%.lua:%d+: QoL's AddSetting", tostring(err))
			end
		end)

		it("reports a call after ModulesChanged and drops it (CORE-R42)", function()
			local fake, M = withQoL()
			fake.login()

			M:AddSetting("fishing", { kind = "header", label = "Casting" })

			assert.are.equal(1, #fake.reported)
			assert.matches("after ModulesChanged", fake.reported[1])
			assert.is_nil(fake.settingsPage("fishing"))
		end)
	end)

	describe("the tracker dock", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local newWidget = dofile("spec/support/widgets.lua").newWidget

		-- Registers a Module and docks a plain frame, 200 wide and `height` tall, as tracker `id` at `order`. Returns
		-- the frame.
		local function dock(fake, name, order, height, id)
			local handle = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
			local frame = newWidget("Frame")
			frame:SetSize(200, height)
			handle:RegisterTracker({ id = id or name:lower(), order = order, frame = frame })
			return frame
		end

		-- The stack as { id, y } pairs, top to bottom.
		local function stack(fake)
			local list = {}
			for i, entry in ipairs(fake.dock.stack()) do
				list[i] = { entry.id, entry.y }
			end
			return list
		end

		-- Core's stacking rules and RegisterTracker's checks are Core's specs' (spec/Pagle/logic/Dock_spec.lua,
		-- spec/Pagle/adapter/Dock_spec.lua), on the same ns.WireDock; these test the fake's own surface.
		it("reads the stack as Core lays it out, each frame as it is when read (CORE-R70, CORE-R72)", function()
			local fake = newFakePagle()
			dock(fake, "Stats", 20, 60)
			local hunts = dock(fake, "Hunts", 10, 40)
			fake.login()

			assert.are.same({ { "hunts", 0 }, { "stats", -48 } }, stack(fake))
			local top = fake.dock.stack()[1]
			assert.are.same(
				{ "Hunts", hunts, "TOPRIGHT", "dock", "TOPRIGHT", 0 },
				{ top.module, top.frame, top.point, top.relativeTo, top.relativePoint, top.x }
			)

			hunts:SetHeight(10)
			assert.are.same({ { "hunts", 0 }, { "stats", -18 } }, stack(fake))
			hunts:Hide()
			assert.are.same({ { "stats", 0 } }, stack(fake))
		end)

		it(
			"sits under the minimap until a Shift-drag saves dock.point; Reset puts it back (CORE-R71, SET-R40)",
			function()
				local fake = newFakePagle()
				dock(fake, "Hunts", 10, 40)
				fake.login()
				local default = fake.dock.point()
				assert.are.same(
					{ point = "TOPRIGHT", relativeTo = "MinimapCluster", relativePoint = "BOTTOMRIGHT", x = 0, y = -10 },
					default
				)
				local moved =
					{ point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 812, y = 640 }

				assert.is_true(fake.dock.drag(moved))

				assert.are.same(moved, fake.profile.dock.point)
				assert.are.same(moved, fake.dock.point())

				assert.is_true(fake.dock.reset())

				assert.is_nil(fake.profile.dock.point)
				assert.are.same(default, fake.dock.point())
			end
		)

		it("never moves while restricted: a drag or Reset does nothing (CORE-R71, SET-R40)", function()
			local fake = newFakePagle()
			dock(fake, "Hunts", 10, 40)
			fake.login()
			local moved =
				{ point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 812, y = 640 }
			fake.dock.drag(moved)
			fake.setRestricted(true)

			local corner = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 1, y = 1 }
			assert.is_false(fake.dock.drag(corner))
			assert.is_false(fake.dock.reset())

			assert.are.same(moved, fake.profile.dock.point)
		end)
	end)

	describe("OpenSettings", function()
		it(
			"opens the root, or a registered topic page; while restricted prints Core's line (CORE-R33, CORE-R43)",
			function()
				local fake = newFakePagle()
				local M = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
				M:AddSetting("fishing", { kind = "header", label = "Casting" })
				fake.login()

				fake.Pagle.OpenSettings("fishing")
				fake.Pagle.OpenSettings("trackers")
				fake.Pagle.OpenSettings()
				fake.setRestricted(true)
				fake.Pagle.OpenSettings("fishing")

				assert.are.same({ "fishing", "root", "root" }, fake.openedSettings)
				assert.are.same({ "Pagle: settings open after combat." }, fake.printed)
			end
		)
	end)

	describe("the compartment menu", function()
		it(
			"lists each Module's views then menu entries by def.order, then the Curio Shop and Settings, reading labels each time (CORE-R50, CORE-R52)",
			function()
				local fake = newFakePagle()
				local reads = 0
				fake.Pagle.RegisterModule({
					name = "QoL",
					title = "QoL",
					order = 50,
					menu = {
						{
							label = function()
								reads = reads + 1
								return "Input: Both"
							end,
							onClick = function() end,
						},
					},
				})
				fake.Pagle.RegisterModule({
					name = "Hunts",
					title = "Hunts",
					order = 20,
					views = { { id = "board", label = "Hunts", open = function() end } },
				})
				fake.login()

				local labels = {}
				for i, entry in ipairs(fake.menu()) do
					labels[i] = entry.label
				end
				fake.menu()

				assert.are.same({
					"Hunts",
					"Input: Both",
					"Curio Shop  0 |TInterface\\MoneyFrame\\UI-GoldIcon:0|t",
					"Help chart the waters",
					"Settings",
				}, labels)
				assert.are.equal(2, reads)
			end
		)

		it(
			"leaves out an entry whose label raises and reports it, as Core's securecallfunction does (CORE-R52)",
			function()
				local fake = newFakePagle()
				fake.Pagle.RegisterModule({
					name = "QoL",
					title = "QoL",
					order = 50,
					menu = {
						{
							label = function()
								error("no input yet")
							end,
							onClick = function() end,
						},
						{ label = "Input: Both", onClick = function() end },
					},
				})
				fake.login()

				local labels = {}
				for i, entry in ipairs(fake.menu()) do
					labels[i] = entry.label
				end

				assert.are.same({
					"Input: Both",
					"Curio Shop  0 |TInterface\\MoneyFrame\\UI-GoldIcon:0|t",
					"Help chart the waters",
					"Settings",
				}, labels)
				assert.are.equal(1, #fake.reported)
				assert.matches("no input yet", fake.reported[1], 1, true)
			end
		)

		it("opens the root from Settings, or prints Core's line while restricted (CORE-R33, SET-R75)", function()
			local fake = newFakePagle()
			fake.login()

			local menu = fake.menu()
			menu[#menu].onClick()
			fake.setRestricted(true)
			menu[#menu].onClick()

			assert.are.same({ "root" }, fake.openedSettings)
			assert.are.same({ "Pagle: settings open after combat." }, fake.printed)
		end)

		it(
			"shows the Curio Shop entry with the balance as BreakUpLargeNumbers writes it, opening the shop (CORE-R50,"
				.. " SHOP-R40)",
			function()
				local fake = newFakePagle()
				local ledger = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
				fake.login()
				ledger:ReportCoinsEarned(1950)

				local menu = fake.menu()
				menu[1].onClick()

				assert.are.equal("Curio Shop  1,950 |TInterface\\MoneyFrame\\UI-GoldIcon:0|t", menu[1].label)
				assert.are.same({ {} }, fake.shopsOpened)
				assert.is_true(fake.shopOpen)
			end
		)

		it("prints SHOP-R41's line for the Curio Shop entry while restricted (SHOP-R41, CORE-R33)", function()
			local fake = newFakePagle()
			fake.login()
			fake.setRestricted(true)

			fake.menu()[1].onClick()

			assert.are.same({}, fake.shopsOpened)
			assert.are.same({ "Pagle: the Curio Shop opens after combat." }, fake.printed)
		end)
	end)

	describe("the wallet", function()
		it(
			"adds Modules' reports in Pagle.GetBalance, by def.name, stored in fake.global.coins (SHOP-R3, SHOP-R12)",
			function()
				local fake = newFakePagle()
				local ledger = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
				local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })

				ledger:ReportCoinsEarned(120)
				hunts:ReportCoinsEarned(30)
				ledger:ReportCoinsEarned(100)

				local balance = fake.Pagle.GetBalance()
				assert.are.same({ 100, false, 30, 100 }, {
					balance.earned.Ledger,
					balance.held,
					balance.earned.Hunts,
					fake.global.coins.earned.Ledger,
				})
				assert.are.equal(130, balance.balance)
			end
		)

		it("records every report, an unchanged one too, and fires BalanceChanged only on a change (SHOP-R2)", function()
			local fake = newFakePagle()
			local ledger = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local balances = {}
			fake.Pagle.RegisterCallback("spec", "BalanceChanged", function(_, balance)
				balances[#balances + 1] = balance.balance
			end)

			ledger:ReportCoinsEarned(40)
			ledger:ReportCoinsEarned(40)

			assert.are.same({ { module = "Ledger", total = 40 }, { module = "Ledger", total = 40 } }, fake.coinReports)
			assert.are.same({ 40 }, balances)
		end)

		it("raises an error for a negative, fractional or string total, recording nothing (SHOP-R2)", function()
			local fake = newFakePagle()
			local ledger = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

			for _, total in ipairs({ -1, 0.5, "10" }) do
				assert.has_error(function()
					ledger:ReportCoinsEarned(total)
				end)
			end

			assert.are.same({}, fake.coinReports)
		end)

		it("counts a stored total with no report, and holds at 0 below spent (SHOP-R3, SHOP-R12)", function()
			local fake = newFakePagle()
			fake.global.coins.earned.Hunts = 300

			assert.are.equal(300, fake.Pagle.GetBalance().balance)
			fake.setSpent(500)
			assert.are.same({ 0, true }, { fake.Pagle.GetBalance().balance, fake.Pagle.GetBalance().held })
		end)

		it("hands out a read-only Balance (CORE-R18)", function()
			local fake = newFakePagle()

			assert.has_error(function()
				fake.Pagle.GetBalance().balance = 5
			end)
		end)
	end)

	describe("Activity XP", function()
		-- A Module's handle on `fake`, with the order the roster gives it.
		local function register(fake, name)
			local order = { Ledger = 10, Hunts = 20, TackleBoard = 40 }
			return fake.Pagle.RegisterModule({ name = name, title = name, order = order[name] })
		end

		-- Each ActivityXPChanged from now on, as the entry it carried ("none" for nil) and the total then.
		local function listen(fake)
			local fired = {}
			fake.Pagle.RegisterCallback("spec", "ActivityXPChanged", function(_, entry)
				fired[#fired + 1] = { entry = entry or "none", total = fake.Pagle.GetActivityXP().total }
			end)
			return fired
		end

		it(
			"stores 150 under def.name in fake.global.activityXP, fires once, nothing for 150 again, and takes a lower"
				.. " 100 (AXP-R3, AXP-R4, AXP-R7)",
			function()
				local fake = newFakePagle()
				local hunts = register(fake, "Hunts")
				fake.login()
				local fired = listen(fake)

				hunts:ReportXPEarned(150)
				hunts:ReportXPEarned(150)
				hunts:ReportXPEarned(100)

				assert.are.same({ { entry = "none", total = 150 }, { entry = "none", total = 100 } }, fired)
				assert.are.same({ Hunts = 100 }, fake.global.activityXP.earned)
				assert.are.equal(fake.catchLog.data.logId, fake.global.activityXP.logId)
				assert.are.same({
					{ module = "Hunts", total = 150 },
					{ module = "Hunts", total = 150 },
					{ module = "Hunts", total = 100 },
				}, fake.xpReports)
			end
		)

		it('raises an error at the Module\'s call for -1, 1.5 or "10", recording nothing (AXP-R2)', function()
			local fake = newFakePagle()
			local hunts = register(fake, "Hunts")
			local fired = listen(fake)

			for _, total in ipairs({ -1, 1.5, "10" }) do
				local ok, err = pcall(function()
					hunts:ReportXPEarned(total)
				end)
				assert.is_false(ok)
				assert.matches("fake_pagle_spec.lua:%d+: M:ReportXPEarned takes a whole number", tostring(err))
			end

			assert.are.same({}, fake.xpReports)
			assert.are.same({}, fake.global.activityXP.earned)
			assert.are.same({}, fired)
		end)

		it("passes ActivityXPChanged the live entry from a live apply, and none from done (AXP-R7, LOG-R73)", function()
			local fake = newFakePagle()
			local board = register(fake, "TackleBoard")
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			fake.catchLog:Append({
				kind = "module",
				char = 1,
				time = SERVER_TIME - 600,
				module = "TackleBoard",
				recordKind = "notice",
				payload = "a",
			})
			board:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return { xp = 0 }
				end,
				apply = function(state, record, mode)
					if record.kind == "module" then
						state.xp = state.xp + 100
						if mode == "live" then
							board:ReportXPEarned(state.xp)
						end
					end
				end,
				done = function(state)
					board:ReportXPEarned(state.xp)
				end,
			})
			local fired = listen(fake)
			fake.login()
			fake.enterWorld()

			local record = board:AppendRecord("notice", "b")

			assert.are.same({ "none", record.id }, { fired[1].entry, fired[2].entry.id })
			assert.are.same({ 100, 200 }, { fired[1].total, fired[2].total })
			assert.are.equal(fake.xpReports[2].entry.seq, record.seq)
		end)

		it("raises an error from a rebuild apply, storing nothing (AXP-R2)", function()
			local fake = newFakePagle()
			local board = register(fake, "TackleBoard")
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			fake.catchLog:Append({ kind = "skill", char = 1, time = SERVER_TIME - 600, rank = 80, max = 150, mod = 0 })
			local raised = {}
			board:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, _, mode)
					raised[#raised + 1] = { mode, (pcall(board.ReportXPEarned, board, 50)) }
				end,
			})
			fake.login()

			fake.enterWorld()

			assert.are.same({ { "rebuild", false } }, raised)
			assert.are.same({}, fake.xpReports)
		end)

		it(
			"lists a disabled Module's stored total, from fake.setActivityXP, with enabled false (AXP-R6, AXP-R90)",
			function()
				local fake = newFakePagle()
				fake.addons.Pagle_Hunts.enabled = false
				fake.setActivityXP("Hunts", 600)
				local board = register(fake, "TackleBoard")
				fake.login()

				board:ReportXPEarned(250)

				local xp = fake.Pagle.GetActivityXP()
				assert.are.same({ 850, 600, false, 250, true }, {
					xp.total,
					xp.bySource.Hunts.total,
					xp.bySource.Hunts.enabled,
					xp.bySource.TackleBoard.total,
					xp.bySource.TackleBoard.enabled,
				})
				assert.is_nil(xp.bySource.Ledger)
				assert.has_error(function()
					fake.setActivityXP("Hunts", -5)
				end)
			end
		)

		it("hands out a read-only ActivityXP (CORE-R18)", function()
			local fake = newFakePagle()

			assert.has_error(function()
				fake.Pagle.GetActivityXP().total = 5
			end)
		end)

		it("snapshots the sum into the P1 that M:RecordPrestige or fake.prestige appends (AXP-R5, LOG-R38)", function()
			local fake = newFakePagle()
			fake.setActivityXP("Hunts", 600)
			local ledger, board = register(fake, "Ledger"), register(fake, "TackleBoard")
			fake.login()
			board:ReportXPEarned(250)

			local first = ledger:RecordPrestige()
			board:ReportXPEarned(400)
			local second = fake.prestige()

			assert.are.same({ 850, 1000 }, { first.activityXP, second.activityXP })
			assert.are.same(
				{ prestigeEntry(SERVER_TIME, 1, 0, 1, 850), prestigeEntry(SERVER_TIME, 2, 1, 1, 1000) },
				fake.catchLog.data.entries
			)
		end)
	end)

	describe("pushed content", function()
		---@class FakePagleListening: FakePagle
		---@field fired PagleCompanionState[] each PushedContentReady's state, in order

		-- A fake whose every PushedContentReady lands in `fired`.
		---@return FakePagleListening
		local function listening()
			local fake = newFakePagle() --[[@as FakePagleListening]]
			fake.fired = {}
			fake.Pagle.RegisterCallback("spec", "PushedContentReady", function(_, state)
				fake.fired[#fake.fired + 1] = state
			end)
			return fake
		end

		it(
			"reads missing from login with no Pagle_Content set, firing PushedContentReady at once (PUSH-R15, PUSH-R16, PUSH-R90)",
			function()
				local fake = listening()
				assert.are.equal("checking", fake.Pagle.GetCompanionState())

				fake.login()

				assert.are.equal("missing", fake.Pagle.GetCompanionState())
				assert.are.same({ "missing" }, fake.fired)
				assert.are.same({}, fake.Pagle.GetPushedContent("huntRun"))
			end
		)

		it(
			"ends the check with a set state and items on the frame after login, keeping the known kinds (PUSH-R10, PUSH-R21, PUSH-R22)",
			function()
				local fake = listening()
				local run = { kind = "huntRun", v = 1, event = "p_test_tide", start = 1, ["end"] = 2 }
				fake.setPushedContent({ state = "notRunning", items = { run, { kind = "notice", v = 1 } } })

				fake.login()
				assert.are.equal("checking", fake.Pagle.GetCompanionState())
				assert.are.same({}, fake.Pagle.GetPushedContent("huntRun"))
				assert.are.same({}, fake.fired)
				fake.nextFrame()

				assert.are.equal("notRunning", fake.Pagle.GetCompanionState())
				assert.are.same({ "notRunning" }, fake.fired)
				local runs = fake.Pagle.GetPushedContent("huntRun")
				assert.are.same({ run }, runs)
				runs[1].event = "changed"
				assert.are.equal("p_test_tide", fake.Pagle.GetPushedContent("huntRun")[1].event)
				assert.are.same({}, fake.Pagle.GetPushedContent("notice"))
			end
		)

		it("keeps checking for good with a set state of checking (PUSH-R93)", function()
			local fake = listening()
			fake.setPushedContent({ state = "checking" })

			fake.login()
			fake.nextFrame()

			assert.are.equal("checking", fake.Pagle.GetCompanionState())
			assert.are.same({}, fake.fired)
		end)

		it(
			"checks a raw PagleContentData with Core's real check, the test key registered by the spec (PUSH-R13)",
			function()
				local fixtures = pushedContentFixtures()
				local fake = listening()
				fake.ns.PUSHED_KEYS.testKey = fixtures.testKey
				fake.setPushedContent({ data = fixtures.good })

				fake.login()
				assert.are.equal("checking", fake.Pagle.GetCompanionState())
				fake.nextFrame()

				assert.are.equal("connected", fake.Pagle.GetCompanionState())
				assert.are.same({ "connected" }, fake.fired)
				assert.are.equal(1, #fake.Pagle.GetPushedContent("huntRun"))
				assert.are.equal(42, fake.global.pushed.seq)
				fake.slash("dev on")
				fake.slash("dev content")
				assert.are.equal(
					"Pagle dev: kinds handed out: huntEvent 1, huntRun 1.",
					fake.printed[#fake.printed - 2]
				)
			end
		)

		it("reads a raw file that fails the check missing, as Core does (PUSH-R13)", function()
			local fixtures = pushedContentFixtures()
			local fake = listening()
			fake.setPushedContent({ data = fixtures.good })

			fake.login()
			fake.nextFrame()

			assert.are.equal("missing", fake.Pagle.GetCompanionState())
			assert.are.same({ "missing" }, fake.fired)
		end)

		it("refuses a set after login: Core reads Pagle_Content once (PUSH-R1)", function()
			local fake = newFakePagle()
			fake.login()

			assert.has_error(function()
				fake.setPushedContent({ state = "connected", items = {} })
			end)
		end)
	end)

	describe("goods", function()
		-- Hunts registered on `fake`, with its notebook cover slot: a default, a tier-2 good and an earned good whose
		-- isEarned() returns `earned.value`.
		local function huntsCovers(fake, earned)
			local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Hunts" })
			hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
			hunts:RegisterGood({
				id = "hunts.cover.velvet",
				slot = "hunts.cover",
				name = "Velvet",
				tier = 2,
				icon = 134939,
			})
			hunts:RegisterGood({
				id = "hunts.cover.gold",
				slot = "hunts.cover",
				name = "Gold",
				isEarned = function()
					return earned.value
				end,
			})
			return hunts
		end

		it(
			"owns the default, a tier-2 good once fake.setPurchased has it, and an earned good by its cache (SHOP-R30, SHOP-R31)",
			function()
				local fake = newFakePagle()
				local earned = { value = false }
				local hunts = huntsCovers(fake, earned)
				fake.login()
				local Pagle = fake.Pagle

				assert.are.same({ true, false, false }, {
					Pagle.IsOwned("hunts.cover.plain"),
					Pagle.IsOwned("hunts.cover.velvet"),
					Pagle.IsOwned("hunts.cover.gold"),
				})
				fake.setPurchased({ ["hunts.cover.velvet"] = true })
				earned.value = true
				assert.are.same(
					{ true, false },
					{ Pagle.IsOwned("hunts.cover.velvet"), Pagle.IsOwned("hunts.cover.gold") }
				)
				hunts:RefreshGoods()
				assert.is_true(Pagle.IsOwned("hunts.cover.gold"))
				assert.is_true(fake.global.goods["hunts.cover.gold"].earned)
			end
		)

		it("caches each good in fake.global.goods (SHOP-R26)", function()
			local fake = newFakePagle()
			huntsCovers(fake, { value = false })

			assert.are.same({
				name = "Velvet",
				slot = "hunts.cover",
				slotLabel = "Notebook cover",
				category = "Hunts",
				module = "Hunts",
				icon = 134939,
				tier = 2,
			}, fake.global.goods["hunts.cover.velvet"])
		end)

		it("raises a SHOP-R23 mistake at the Module's call and reports a slot with no default at login", function()
			local fake = newFakePagle()
			local hunts = huntsCovers(fake, { value = false })
			hunts:RegisterSlot({ id = "hunts.frame", label = "Tracker frame", category = "Trackers" })

			assert.has_error(function()
				hunts:RegisterGood({ id = "hunts.cover.tide", slot = "hunts.cover", name = "Tide", default = true })
			end, "M:RegisterGood: hunts.cover already has a default, hunts.cover.plain")
			fake.login()

			assert.are.same({ "Pagle: the slot hunts.frame has no default good" }, fake.reported)
		end)

		it(
			"equips an owned pick in fake.profile.appearance and fires AppearanceChanged once per change (SHOP-R32, SHOP-R33)",
			function()
				local fake = newFakePagle()
				local earned = { value = true }
				local hunts = huntsCovers(fake, earned)
				fake.login()
				local fired = {}
				fake.Pagle.RegisterCallback("spec", "AppearanceChanged", function(_, slot, goodID)
					fired[#fired + 1] = slot .. " " .. goodID
				end)

				assert.is_false(fake.Pagle.SetEquipped("hunts.cover", "hunts.cover.velvet"))
				assert.is_true(fake.Pagle.SetEquipped("hunts.cover", "hunts.cover.gold"))
				earned.value = false
				hunts:RefreshGoods()

				assert.are.same({ "hunts.cover hunts.cover.gold", "hunts.cover hunts.cover.plain" }, fired)
				assert.are.equal("hunts.cover.plain", fake.Pagle.GetEquipped("hunts.cover"))
				assert.are.equal("hunts.cover.gold", fake.profile.appearance["hunts.cover"])
			end
		)

		it(
			"falls back to the cached default for a Module that isn't loaded, keeping its goods owned (SHOP-R90)",
			function()
				local fake = newFakePagle()
				fake.global.goods["hunts.cover.plain"] =
					{ name = "Plain", slot = "hunts.cover", module = "Hunts", default = true }
				fake.global.goods["hunts.cover.velvet"] =
					{ name = "Velvet", slot = "hunts.cover", module = "Hunts", tier = 2 }
				fake.profile.appearance["hunts.cover"] = "hunts.cover.velvet"
				fake.setPurchased({ ["hunts.cover.velvet"] = true })
				fake.login()

				assert.are.same(
					{ "hunts.cover.plain", true },
					{ fake.Pagle.GetEquipped("hunts.cover"), fake.Pagle.IsOwned("hunts.cover.velvet") }
				)
			end
		)

		it("reads a good's cached look with Pagle.GetGood, read-only (SHOP-R26, CORE-R18)", function()
			local fake = newFakePagle()
			huntsCovers(fake, { value = false })

			local good = fake.Pagle.GetGood("hunts.cover.velvet")

			assert.are.same(
				{ "Velvet", "hunts.cover", 134939, "Hunts" },
				{ good.name, good.slot, good.icon, good.module }
			)
			assert.has_error(function()
				good.name = "Changed"
			end)
			assert.is_nil(fake.Pagle.GetGood("hunts.cover.none"))
		end)

		it(
			"records each Pagle.OpenShop in fake.shopsOpened, with the good asked for and the one selected (SHOP-R40)",
			function()
				local fake = newFakePagle()
				local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
				hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Hunts" })
				hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
				hunts:RegisterGood({ id = "hunts.cover.velvet", slot = "hunts.cover", name = "Velvet", tier = 2 })
				fake.login()

				fake.Pagle.OpenShop("hunts.cover.velvet")
				fake.Pagle.OpenShop("hunts.cover.none")
				fake.Pagle.OpenShop()

				assert.are.same({
					{ goodID = "hunts.cover.velvet", selected = "hunts.cover.velvet" },
					{ goodID = "hunts.cover.none" },
					{},
				}, fake.shopsOpened)
				assert.is_true(fake.shopOpen)
			end
		)

		it("has Core's own slots and goods, as Core registers them at login, with no previews (SHOP-R25)", function()
			local fake = newFakePagle()
			fake.login()
			local Pagle = fake.Pagle

			assert.are.same({ "core.toaststyle.page", "core.soundset.driftwood", "core.crest.plain" }, {
				Pagle.GetEquipped("core.toaststyle"),
				Pagle.GetEquipped("core.soundset"),
				Pagle.GetEquipped("core.crest"),
			})
			-- Named from Core's committed lore, as Core names it (DATA-R104, SHOP-R25).
			assert.are.same({ "The Falls", "Interface\\AddOns\\Pagle\\media\\crests\\feralas", "Core" }, {
				Pagle.GetGood("core.crest.feralas").name,
				Pagle.GetGood("core.crest.feralas").icon,
				fake.global.goods["core.crest.feralas"].module,
			})
			assert.is_nil(fake.ns.goods:Good("core.crest.plain").preview)
			fake.setPurchased({ ["core.crest.feralas"] = true })
			assert.is_true(Pagle.SetEquipped("core.crest", "core.crest.feralas"))
		end)

		it("selects an owned good of a Module off under Put away, from the cache (SHOP-R40, SHOP-R35)", function()
			local fake = newFakePagle()
			fake.global.goods["hunts.cover.velvet"] = {
				name = "Velvet",
				slot = "hunts.cover",
				slotLabel = "Notebook cover",
				category = "Hunts",
				module = "Hunts",
				tier = 2,
			}
			fake.login()
			fake.setPurchased({ ["hunts.cover.velvet"] = true })

			fake.Pagle.OpenShop("hunts.cover.velvet")

			assert.are.same({ { goodID = "hunts.cover.velvet", selected = "hunts.cover.velvet" } }, fake.shopsOpened)
		end)

		it("toggles the Curio Shop with /pagle shop (CORE-R61, SHOP-R40)", function()
			local fake = newFakePagle()
			fake.login()

			fake.slash("shop")
			assert.is_true(fake.shopOpen)
			fake.slash(" SHOP ")
			assert.is_false(fake.shopOpen)
			assert.are.same({ {} }, fake.shopsOpened)
		end)

		it(
			"prints SHOP-R41's line while restricted, and closes the Curio Shop when restriction starts (SHOP-R41)",
			function()
				local fake = newFakePagle()
				fake.login()
				fake.Pagle.OpenShop()

				fake.setRestricted(true)
				assert.is_false(fake.shopOpen)
				fake.Pagle.OpenShop()
				fake.slash("shop")

				assert.are.same({ {} }, fake.shopsOpened)
				assert.is_false(fake.shopOpen)
				assert.are.same(
					{ "Pagle: the Curio Shop opens after combat.", "Pagle: the Curio Shop opens after combat." },
					fake.printed
				)
			end
		)
	end)

	describe("moments", function()
		-- A Module registered on `fake` whose projection raises `raise(record, mode)`'s moment, if any, for each Cast it
		-- applies, and `done(info)`'s from its done.
		local function raising(fake, name, order, raise, done)
			local M = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
			M:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record, mode)
					local moment = record.kind == "cast" and raise(record, mode)
					if moment then
						M:RaiseMoment(moment)
					end
				end,
				done = done and function(_, info)
					M:RaiseMoment(done(info))
				end,
			})
			return M
		end

		-- fake.catchLog with the player's character and `casts` Casts in it, as history before login.
		local function withHistory(fake, casts)
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for i = 1, casts do
				fake.catchLog:Append({
					kind = "cast",
					char = 1,
					time = 1791731000 + i,
					outcome = "caught",
					conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
					items = { { itemID = 6358, quantity = 1 } },
				})
			end
		end

		it(
			"make two Modules' moments for a played Cast one Announcement on the next frame, coins apart (ANN-R10,"
				.. " ANN-R11, ANN-R23)",
			function()
				local fake = newFakePagle()
				raising(fake, "Hunts", 20, function(record)
					return { rung = "toast.high", kind = "hunt", title = "Hunt completed", cast = record.id, coins = 15 }
				end)
				raising(fake, "Ledger", 10, function(record)
					return {
						rung = "toast",
						kind = "newSpecies",
						title = "New Species",
						stamp = "New!",
						cast = record.id,
					}
				end)
				fake.login()
				fake.enterWorld()

				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				assert.are.same({}, fake.announcements)
				fake.nextFrame()

				assert.are.equal(1, #fake.announcements)
				local shown = fake.announcements[1]
				assert.are.same({ "Hunt completed", "toast.high", { "New!" }, 15 }, {
					shown.headline.title,
					shown.rung,
					shown.stamps,
					shown.coins,
				})
			end
		)

		it("refuses a moment as Core does: an unknown rung, or no kind or title (ANN-R1)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

			for _, moment in ipairs({
				{ rung = "fanfare", kind = "k", title = "t" },
				{ rung = "toast", title = "t" },
				{ rung = "toast", kind = "k" },
			}) do
				assert.has_error(function()
					M:RaiseMoment(moment)
				end)
			end
			assert.are.same({}, fake.summarized)
		end)

		it(
			"drop a rebuild's moments, reported once, and keep a summaryOnly one from done, never shown (ANN-R4,"
				.. " ANN-R63)",
			function()
				local fake = newFakePagle()
				withHistory(fake, 2)
				raising(fake, "Ledger", 10, function(record, mode)
					return { rung = "toast", kind = mode, title = "Cast " .. record.seq, cast = record.id }
				end, function()
					return { rung = "toast", kind = "reclassified", title = "Reclassified", summaryOnly = true }
				end)

				fake.login()
				fake.enterWorld()
				fake.nextFrame()

				assert.are.same({}, fake.announcements)
				assert.are.equal(1, #fake.reported)
				assert.are.same({ "Reclassified" }, { fake.summarized[1].title })
				assert.are.equal(1, #fake.summarized)
			end
		)

		it(
			"hold a Cast played before enterWorld until the frame after every projection caught up (ANN-R10,"
				.. " LOG-R74)",
			function()
				local fake = newFakePagle()
				raising(fake, "Ledger", 10, function(record)
					return { rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id }
				end)
				fake.login()

				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				fake.nextFrame()
				assert.are.same({}, fake.announcements)
				fake.enterWorld()
				assert.are.same({}, fake.announcements)
				fake.nextFrame()

				assert.are.same({ "New Species" }, { fake.announcements[1].headline.title })
			end
		)

		it("flush a moment without a Cast on the next frame, as its own Announcement (ANN-R12)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

			M:RaiseMoment({ rung = "nod", kind = "login", title = "Welcome back" })
			fake.nextFrame()

			assert.are.same(
				{ "Welcome back", "nod" },
				{ fake.announcements[1].headline.title, fake.announcements[1].rung }
			)
		end)

		it(
			"show Core's catch Nod for a played caught Cast in fake.catchNods, apart from fake.announcements and"
				.. " never summarized (ANN-R13, ANN-R25)",
			function()
				local fake = newFakePagle()
				fake.itemNames[6358] = "Oily Blackmouth"
				fake.login()
				fake.enterWorld()

				local cast = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))
				assert.are.same({}, fake.catchNods)
				fake.nextFrame()

				assert.are.equal(1, #fake.catchNods)
				local nod = fake.catchNods[1]
				assert.are.same({ "nod", cast.id, 6358 }, { nod.rung, nod.cast, nod.headline.icon })
				-- Oily Blackmouth has varieties, so the Nod names its Catch's (VAR-R26).
				local variety = nod.headline.variety
				assert.are.same(cast.items[1].variety.rarity, variety.rarity)
				assert.are.equal(variety.before .. " " .. variety.name .. " " .. variety.after, nod.headline.title)
				assert.matches("^Oily Blackmouth · [%a%- ]+ · %a+ · %d+%.%d in$", nod.headline.title)
				assert.are.same({}, fake.announcements)
				assert.are.same({}, fake.summarized)
			end
		)

		it("drop the catch Nod when a Module raises a moment for the Cast (ANN-R13)", function()
			local fake = newFakePagle()
			raising(fake, "Ledger", 10, function(record)
				return { rung = "nod", kind = "newInZone", title = "New in this zone", cast = record.id }
			end)
			fake.login()
			fake.enterWorld()

			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
			fake.nextFrame()

			assert.are.same({}, fake.catchNods)
			assert.are.same({ "New in this zone" }, { fake.announcements[1].headline.title })
			assert.are.same({}, fake.announcements[1].stamps)
		end)

		it(
			'raise no catch Nod for a got-away Cast, a replayed one, or with "Show every catch" off (ANN-R13, ANN-R4,'
				.. " SET-R30)",
			function()
				local fake = newFakePagle()
				withHistory(fake, 2)
				fake.login()
				fake.enterWorld()
				fake.nextFrame()

				fake.playCast("gotAway")
				fake.nextFrame()
				fake.profile.announcements.everyCatch = false
				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				fake.nextFrame()

				assert.are.same({}, fake.catchNods)
			end
		)
	end)

	describe("/pagle dev", function()
		it("ends the open Session now, as Core does, once dev is on (#247, LOG-R62)", function()
			local fake = newFakePagle()
			local ended = {}
			fake.Pagle.RegisterCallback(ended, "SessionEnded", function(_, session)
				ended[#ended + 1] = session.id
			end)
			fake.login()
			fake.enterWorld()
			local cast = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))

			fake.slash("dev endsession")
			fake.slash("dev on")
			fake.slash("dev endsession")

			assert.are.same({ cast.id }, ended)
			assert.is_nil(fake.Pagle.GetSession())
			assert.are.same({
				"Pagle dev: dev commands are off; /pagle dev on turns them on.",
				"Pagle dev: dev commands are on.",
				"Pagle dev: the Session ended, as if its gap had passed.",
			}, fake.printed)
		end)

		it("has the next Cast after endsession start a new Session, as Core does (#258, LOG-R99)", function()
			local fake = newFakePagle()
			fake.login()
			fake.enterWorld()
			local first = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))
			fake.slash("dev on")
			fake.slash("dev endsession")

			fake.wait(10)
			local second = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))

			assert.are.same({ first.id, second.id }, { first.session, second.session })
			assert.are.equal(second.id, fake.Pagle.GetSession().id)
		end)

		it("hands the glyph probe and Core's fonts to fake.glyphProbes, as Core shows them (#248, CORE-R9)", function()
			local fake = newFakePagle()
			fake.login()
			fake.enterWorld()

			fake.slash("dev on")
			fake.slash("dev glyphs")

			assert.are.equal(1, #fake.glyphProbes)
			local shown = fake.glyphProbes[1]
			assert.are.equal(fake.ns.DEV_GLYPH_FONTS, shown.fonts)
			assert.are.equal("2013 –", shown.probe:sub(1, #"2013 –"))
			assert.are.equal("Pagle dev: the glyph probe in the chat font: " .. shown.probe, fake.printed[2])
		end)

		it(
			"records a caught Cast in the area given on a test log, with Catch, CastEnded and live projections; on a"
				.. " real log refuses (#247, LOG-R9)",
			function()
				local fake = newFakePagle()
				local events = {}
				for _, event in ipairs({ "CastStarted", "Catch", "CastEnded" }) do
					fake.Pagle.RegisterCallback(events, event, function()
						events[#events + 1] = event
					end)
				end
				fake.login()
				fake.enterWorld()
				fake.slash("dev on")

				fake.slash("dev catch 6358")
				local refused = #fake.catchLog.data.entries
				fake.catchLog.data.test = true
				fake.slash("dev catch 6358 453")

				assert.are.equal(0, refused)
				local record = assert(fake.catchLog:Iterate()())
				---@cast record PagleCast
				assert.are.same(
					{ 6358, 148, 453, "caught" },
					{ record.items[1].itemID, record.conditions.zone, record.conditions.subzone, record.outcome }
				)
				assert.are.same({ "Catch", "CastEnded" }, events)
				assert.are.equal(record.session, assert(fake.Pagle.GetSession()).id)
			end
		)

		it("hands a preview's sample to the display and its card to the cards, as Core does (#247)", function()
			local fake = newFakePagle()
			fake.login()
			fake.enterWorld()
			fake.slash("dev on")

			fake.slash("dev preview banner")
			fake.slash("dev preview card")

			assert.are.same({ "banner", "Angler Level 12" }, {
				fake.announcements[1].rung,
				fake.announcements[1].headline.title,
			})
			assert.are.equal(1, #fake.cardsShown)
			assert.is_true(fake.cardsShown[1].preview)
			assert.are.same({}, fake.global.cards)
		end)
	end)

	describe("/pagle", function()
		it(
			"runs a Module's subcommand case-insensitively with the rest of the line, trimmed, from login (CORE-R62)",
			function()
				local fake = newFakePagle()
				local got = {}
				fake.Pagle.RegisterModule({
					name = "QoL",
					title = "QoL",
					order = 50,
					slash = {
						{
							name = "qol",
							fn = function(args)
								got[#got + 1] = args
							end,
							help = "cycle Input",
						},
					},
				})
				fake.login()

				fake.slash(" QOL  input ")
				fake.slash("")
				fake.slash("help")

				assert.are.same({ "input" }, got)
				assert.are.same({ "root" }, fake.openedSettings)
				assert.are.same({
					"Pagle commands:",
					"/pagle settings: open Pagle's settings (also /pagle on its own)",
					"/pagle shop: open or close the Curio Shop",
					"/pagle report: open the Field report, to help chart the waters",
					"/pagle guide: open the Field guide; /pagle guide notes shows the margin notes again",
					"/pagle help: list these commands",
					"/pagle qol: cycle Input",
				}, fake.printed)
			end
		)

		it("reports a subcommand that raises, and carries on, as Core's securecallfunction does (CORE-R62)", function()
			local fake = newFakePagle()
			fake.Pagle.RegisterModule({
				name = "QoL",
				title = "QoL",
				order = 50,
				slash = {
					{
						name = "qol",
						fn = function()
							error("cycle failed")
						end,
						help = "cycle Input",
					},
				},
			})
			fake.login()

			fake.slash("qol")
			fake.slash("qol")

			assert.are.equal(2, #fake.reported)
			assert.matches("cycle failed", fake.reported[2], 1, true)
		end)

		it("reports a subcommand that collides with a reserved one, and keeps the rest (CORE-R62)", function()
			local fake = newFakePagle()
			fake.Pagle.RegisterModule({
				name = "QoL",
				title = "QoL",
				order = 50,
				slash = {
					{ name = "Report", fn = function() end, help = "x" },
					{ name = "qol", fn = function() end, help = "cycle Input" },
				},
			})
			fake.login()
			fake.slash("help")

			assert.are.same({ "Pagle: QoL's /pagle Report is skipped: Pagle reserves report" }, fake.reported)
			assert.are.equal("/pagle qol: cycle Input", fake.printed[7])
		end)
	end)

	it("loads a Module with Core's libs but not Core, so it registers with the fake (CORE-R6, CORE-R18)", function()
		local fake = newFakePagle()

		local loaded = fake.load("Pagle_QoL")

		assert.are.equal(fake.globals.Pagle, loaded.env.Pagle)
		assert.is_table(loaded.env.LibStub:GetLibrary("AceDB-3.0", true))
		assert.is_nil(loaded.namespaces.Pagle.Modules)
		assert.are.equal("on", fake.moduleState("QoL"))
	end)

	it("passes the WoW events a Module's client raises on its own to its Pagle handlers (CORE-R23)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		local got = 0
		fake.Pagle.RegisterEvent("Spec", "UPDATE_BINDINGS", function()
			got = got + 1
		end)

		loaded.env.ClearOverrideBindings({})

		assert.are.equal(1, got)
	end)

	it("keeps Core's libraries to itself, so no later load shares them through the real globals", function()
		newFakePagle()

		assert.is_nil(rawget(_G, "LibStub"))
	end)

	it("matches conditions with Core's real logic (LOG-R48)", function()
		local Pagle = newFakePagle().Pagle

		assert.is_true(Pagle.MatchesConditions({ areas = { 40 } }, { zone = 40, subzone = 0, events = {}, auras = {} }))
		assert.has_error(function()
			Pagle.MatchesConditions({ pools = { 1 } }, { zone = 40 })
		end)
	end)

	it("matches a window spec and conditions it handed out read-only, as Core takes its own (LOG-R48)", function()
		local fake = newFakePagle()
		-- What a Module sees: read-only proxies (CORE-R18).
		local Pagle = fake.globals.Pagle
		local night = Pagle.GetWindowSpec("night")

		fake.conditions.minute = 800 -- 13:20, outside the generated night (18:00–12:00)
		assert.is_false(Pagle.MatchesConditions(night, Pagle.GetConditions()))
		fake.conditions.minute = 1300
		assert.is_true(Pagle.MatchesConditions(night, Pagle.GetConditions()))
	end)

	it("iterates its Catch log with Core's real codec, handing out read-only records (LOG-R42, CORE-R18)", function()
		local fake = newFakePagle()
		fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
		fake.catchLog:Append({ kind = "skill", char = 1, time = 1791731680, rank = 86, max = 150, mod = 0 })
		fake.catchLog:Append({ kind = "build", char = 1, time = 1791731681, build = 70338, version = "1.60.1" })

		local records = {}
		for record in fake.Pagle.IterateCatches(1) do
			records[#records + 1] = record
		end

		assert.are.equal(1, #records)
		assert.are.equal("build", records[1].kind)
		assert.are.equal(PLAYER_GUID .. "-1791731681-0", records[1].id)
		assert.has_error(function()
			records[1].build = 1
		end)
	end)

	describe("Prestige and purchase entries", function()
		-- The Ledger registered on `fake`, its projection noting each apply ("<seq> <kind> <mode>") and each Prestige
		-- event ("Prestige <rank>, writable <bool>") in `seen`, in order.
		local function ledger(fake)
			local seen = {}
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			M:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record, mode)
					seen[#seen + 1] = record.seq .. " " .. record.kind .. " " .. mode
				end,
			})
			fake.Pagle.RegisterCallback("Spec", "Prestige", function(_, record)
				local writable = pcall(function()
					record.rank = 9
				end)
				seen[#seen + 1] = ("Prestige %d, writable %s"):format(record.rank, tostring(writable))
			end)
			return M, seen
		end

		it(
			"append a real P1 for M:RecordPrestige, rank 1 then 2, live before a read-only Prestige (LOG-R38, LOG-R73,"
				.. " CORE-R18)",
			function()
				local fake = newFakePagle()
				local M, seen = ledger(fake)
				fake.login()
				fake.enterWorld()

				local first = M:RecordPrestige()
				fake.prestige()

				assert.are.same(
					{ prestigeEntry(SERVER_TIME, 1), prestigeEntry(SERVER_TIME, 2, 1) },
					fake.catchLog.data.entries
				)
				assert.are.same(
					{ "1 prestige live", "Prestige 1, writable false", "2 prestige live", "Prestige 2, writable false" },
					seen
				)
				assert.are.equal(1, first.rank)
				assert.has_error(function()
					first.rank = 3
				end)
			end
		)

		it("count the Prestiges in a history, as Core does (LOG-R38)", function()
			local fake = newFakePagle()
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			fake.catchLog:Append({ kind = "prestige", char = 1, time = SERVER_TIME - 700, rank = 1 })
			fake.catchLog:Append({
				kind = "purchase",
				char = 1,
				time = SERVER_TIME - 699,
				good = "core.crest.otter",
				price = 300,
			})
			fake.login()
			fake.enterWorld()

			assert.are.equal(2, fake.prestige().rank)
		end)

		it("raise an error for M:RecordPrestige before login, appending nothing (LOG-R38)", function()
			local fake = newFakePagle()
			local M = ledger(fake)

			assert.has_error(function()
				M:RecordPrestige()
			end)
			assert.are.same({}, fake.catchLog.data.entries)
		end)

		it("append a purchase only through Core's own ns.RecordPurchase, applied live (LOG-R39)", function()
			local fake = newFakePagle()
			local _, seen = ledger(fake)
			fake.login()
			fake.enterWorld()

			fake.ns.RecordPurchase("core.toaststyle.ripple", 150)

			assert.are.same({ purchaseEntry(SERVER_TIME, "core.toaststyle.ripple", 150) }, fake.catchLog.data.entries)
			assert.are.same({ "1 purchase live" }, seen)
			assert.is_nil(fake.Pagle.RecordPurchase)
		end)
	end)

	describe("Module records", function()
		-- `name` registered on `fake`, its projection over `db` noting each apply ("<seq> <kind> <mode>", a Module
		-- record's kind as its recordKind) and each done ("done") in `seen`. `onApply(record, mode)` runs after the note.
		local function module(fake, name, db, onApply)
			local seen = {}
			local M = fake.Pagle.RegisterModule({ name = name, title = name, order = 10 })
			M:NewProjection({
				db = db,
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record, mode)
					seen[#seen + 1] = ("%d %s %s"):format(record.seq, record.recordKind or record.kind, mode)
					if onApply then
						onApply(record, mode)
					end
				end,
				done = function()
					seen[#seen + 1] = "done"
				end,
			})
			return M, seen
		end

		it(
			"append a real A1 for M:AppendRecord, read-only, live to its own Module only, every other projection"
				.. " still reaching the log's end (LOG-R40, LOG-R41, LOG-R73, CORE-R18)",
			function()
				local fake = newFakePagle()
				local ledgerDb = {}
				local board, boardSeen = module(fake, "TackleBoard", {})
				local _, ledgerSeen = module(fake, "Ledger", ledgerDb)
				fake.login()
				fake.enterWorld()

				local record = board:AppendRecord("issue", "n|haul;30")

				assert.are.same({ "A1|1|1791731700|0|TackleBoard|issue|n|haul;30" }, fake.catchLog.data.entries)
				assert.are.same({ "done", "1 issue live" }, boardSeen)
				assert.are.same({ "done" }, ledgerSeen)
				assert.are.equal(1, ledgerDb.lastSeq)
				assert.are.same(
					{ 1, PLAYER_GUID .. "-1791731700-0", "module", "TackleBoard", "issue", "n|haul;30" },
					{ record.seq, record.id, record.kind, record.module, record.recordKind, record.payload }
				)
				assert.has_error(function()
					record.payload = "x"
				end)
			end
		)

		it("replay through M:IterateCatches to the Module that wrote them only (LOG-R41, LOG-R42)", function()
			local fake = newFakePagle()
			local board = module(fake, "TackleBoard", {})
			local ledger = module(fake, "Ledger", {})
			fake.login()
			fake.enterWorld()
			board:AppendRecord("start", "")
			ledger:AppendRecord("note", "x")

			local function walk(iterate)
				local seqs = {}
				for record in iterate do
					seqs[#seqs + 1] = record.seq .. " " .. (record.module or record.kind)
				end
				return seqs
			end
			assert.are.same({ "1 TackleBoard" }, walk(board:IterateCatches(0)))
			assert.are.same({ "2 Ledger" }, walk(ledger:IterateCatches(0)))
			assert.are.same({}, walk(fake.Pagle.IterateCatches(0)))
		end)

		it("from login code reach the projection as live, never replay (LOG-R1, LOG-R74)", function()
			local fake = newFakePagle()
			local board, seen = module(fake, "TackleBoard", {})
			fake.login()

			board:AppendRecord("start", "")
			fake.enterWorld()

			assert.are.same({ "done", "1 start live" }, seen)
		end)

		it(
			"raise an error at the caller, appending nothing, for a bad payload or from a rebuild apply (LOG-R40)",
			function()
				local fake = newFakePagle()
				fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
				fake.catchLog:Append({ kind = "prestige", char = 1, time = 1791731000, rank = 1 })
				local raised = {}
				local board
				board = module(fake, "TackleBoard", {}, function(_, mode)
					raised[#raised + 1] = mode .. " " .. tostring(not pcall(board.AppendRecord, board, "day", ""))
				end)
				fake.login()
				fake.enterWorld()

				local ok, err = pcall(function()
					board:AppendRecord("day", ("x"):rep(201))
				end)

				assert.is_false(ok)
				assert.matches("fake_pagle_spec.lua:%d+:", tostring(err))
				assert.are.same({ "rebuild true" }, raised)
				assert.are.equal(1, #fake.catchLog.data.entries)
			end
		)
	end)

	describe("the Angler", function()
		it("has the logged-in character current from login, before ModulesChanged (LOG-R1, LOG-R27)", function()
			local fake = newFakePagle()
			local current
			fake.Pagle.RegisterCallback("Spec", "ModulesChanged", function()
				current = fake.Pagle.GetAngler().current
			end)
			assert.is_nil(fake.Pagle.GetAngler().current)

			fake.login()

			local angler = fake.globals.Pagle.GetAngler()
			assert.are.equal(1, current)
			assert.are.equal(PLAYER_GUID, angler.characters[1].guid)
			assert.are.equal(0, angler.bestBaseSkill)
			assert.has_error(function()
				angler.characters[1].name = "Bram"
			end)
		end)

		it(
			"reads skill as Core does: an S1, SkillChanged after it, then ConditionsChanged (LOG-R31, LOG-R32)",
			function()
				local fake = newFakePagle()
				fake.login()
				local fired = {}
				fake.Pagle.RegisterCallback("Spec", "SkillChanged", function(_, reading)
					fired[#fired + 1] = "SkillChanged " .. reading.rank .. ", entries " .. #fake.catchLog.data.entries
				end)
				fake.Pagle.RegisterCallback("Spec", "ConditionsChanged", function(_, changedKeys)
					fired[#fired + 1] = "ConditionsChanged " .. changedKeys[1]
				end)

				fake.readSkill(86, 150, 0)
				fake.readSkill(86, 150, 25)
				fake.readSkill(86, 150, 25)

				assert.are.same(
					{ "SkillChanged 86, entries 1", "ConditionsChanged skill", "ConditionsChanged skill" },
					fired
				)
				assert.are.equal(86, fake.Pagle.GetAngler().bestBaseSkill)
				assert.are.equal(25, fake.Pagle.GetConditions().skillMod)
			end
		)
	end)

	describe("the catalogue", function()
		-- A catalogue in the M1 shape (DATA-R79): Darkshore (148) with The Long Wash (453).
		local function fixture()
			local function area(parent)
				return areaRecord(parent, { continent = 1, hasData = false })
			end
			return catalogueWith({
				areas = { [148] = area(0), [453] = area(148) },
			})
		end

		it("serves the generated catalogue, as Core does (LOG-R55)", function()
			local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle

			assert.are.equal(Pagle.CONTENT_FINGERPRINT, newFakePagle().Pagle.CONTENT_FINGERPRINT)
			assert.are.same(Pagle.GetZones(), newFakePagle().Pagle.GetZones())
		end)

		it("serves a spec's own catalogue on Core's accessors (LOG-R55)", function()
			local fake = newFakePagle()
			fake.setCatalogue(fixture())
			local Pagle = fake.globals.Pagle

			assert.are.equal(148, Pagle.GetZoneOf(453))
			assert.are.equal(1, Pagle.GetArea(453).continent)
			assert.are.equal("0123456789abcdef", Pagle.CONTENT_FINGERPRINT)
		end)

		it("serves a spec's own fishing-spell list to the Cast state machine (LOG-R2, LOG-R55)", function()
			local fake = newFakePagle()
			local data = fixture()
			data.fishingSpells = { 689 }
			fake.setCatalogue(data)
			fake.login()

			fake.channel(7731)
			assert.are.equal("idle", fake.globals.Pagle.GetFishingState())
			fake.channel(689)
			assert.are.equal("channeling", fake.globals.Pagle.GetFishingState())
		end)

		it("hands out records that raise an error on any write (CORE-R18, DATA-R80)", function()
			local fake = newFakePagle()
			fake.setCatalogue(fixture())
			local Pagle = fake.globals.Pagle
			local area, zones, catches = Pagle.GetArea(453), Pagle.GetZones(), Pagle.GetZoneCatches(148)

			assert.has_error(function()
				area.parent = 0
			end)
			assert.has_error(function()
				area.catches[1] = { itemID = 6358, confirmed = true }
			end)
			assert.has_error(function()
				zones[2] = 453
			end)
			assert.has_error(function()
				catches[1] = { itemID = 6358, confirmed = true, areaID = 148 }
			end)
			assert.has_error(function()
				Pagle.CONTENT_FINGERPRINT = "changed"
			end)
		end)
	end)

	describe("Simulated Size", function()
		it("serves Pagle.SIZE_BANDS and Pagle.SIZE_RULES_VERSION as Core does (LOG-R67, LOG-R68)", function()
			local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle
			local fake = newFakePagle()

			assert.are.same(Pagle.SIZE_BANDS, fake.Pagle.SIZE_BANDS)
			assert.are.equal(Pagle.SIZE_RULES_VERSION, fake.Pagle.SIZE_RULES_VERSION)
		end)

		it("hands out Pagle.SIZE_BANDS read-only, leaving Core's own bands as they are (CORE-R18, LOG-R67)", function()
			local fake = newFakePagle()

			assert.has_error(function()
				fake.Pagle.SIZE_BANDS[1].name = "Minnow"
			end)
			assert.are.equal("Tiddler", fake.ns.SIZE_BANDS[1].name)
		end)

		it(
			"puts Core's size on the played Cast, its Catch event and the records IterateCatches yields, over the"
				.. " catalogue served now (LOG-R43, LOG-R65, LOG-R96)",
			function()
				local fake = newFakePagle()
				fake.login()
				local catches = {}
				fake.Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
					catches[#catches + 1] = catch
				end)
				-- A size handed out read-only, as a plain table.
				local function plain(size)
					return size and { length = size.length, band = size.band }
				end
				local core = loadAddon("Pagle", FOREVER_GLOBALS).ns
				-- Oily Blackmouth's typical length in the generated catalogue (DATA-R20, #160).
				local shipped = assert(fake.ns.catalogue.items[6358].typicalLength)
				local first = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))
				assert.are.same(core.SimulatedSize(first.items[1].catchId, shipped), plain(first.items[1].size))
				assert.are.same(plain(first.items[1].size), plain(catches[1].size))

				local retuned = shipped * 2 -- a release retunes the Species' typical length (LOG-R68)
				fake.ns.catalogue.items[6358].typicalLength = retuned
				local second = assert(fake.playCast("caught", { { itemID = 6358, quantity = 2 } }))

				local expected = {
					core.SimulatedSize(first.items[1].catchId, retuned),
					core.SimulatedSize(second.items[1].catchId, retuned),
				}
				assert.are.same(expected[2], plain(second.items[1].size))
				assert.are.same(expected[2], plain(catches[2].size))
				local read = {}
				for record in fake.Pagle.IterateCatches(0) do
					read[#read + 1] = plain(record.items[1].size)
				end
				assert.are.same(expected, read) -- the first Cast too, re-sized over the catalogue served now
			end
		)
	end)

	describe("varieties", function()
		local KEYS = { "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k10" }

		it("serves Pagle.VARIETY_RARITIES as Core does, read-only (VAR-R11, CORE-R18)", function()
			local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle
			local fake = newFakePagle()

			assert.are.same(Pagle.VARIETY_RARITIES, fake.Pagle.VARIETY_RARITIES)
			assert.has_error(function()
				fake.Pagle.VARIETY_RARITIES[1].name = "Plain"
			end)
			assert.are.equal("Common", fake.ns.VARIETY_RARITIES[1].name)
		end)

		it(
			"serves Pagle.GetVarieties and puts Core's variety on the played Cast and its Catch event, over the"
				.. " catalogue served now (VAR-R4, VAR-R11)",
			function()
				local fake = newFakePagle()
				fake.ns.catalogue.items[6358].varieties = KEYS
				fake.setCatalogue(fake.ns.catalogue)
				fake.login()
				local catches = {}
				fake.Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
					catches[#catches + 1] = catch
				end)
				local species = fake.ns.catalogue.items[6358].species

				assert.are.equal(species .. ".k10", fake.Pagle.GetVarieties(species)[10].id)
				local cast = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))
				local expected = fake.ns.VarietyOf(cast.items[1].catchId, fake.ns.catalogue.items[6358])
				assert.is_table(expected)
				assert.are.same(expected.id, cast.items[1].variety.id)
				assert.are.same(expected.id, catches[1].variety.id)
			end
		)
	end)

	describe("the length unit", function()
		it("reads Pagle.FormatLength in inches by default, as Core does on region 1 (LOG-R69)", function()
			local fake = newFakePagle()

			assert.is_nil(fake.profile.lengthUnit)
			assert.are.same({ "13.5 in", 1 }, { fake.Pagle.FormatLength(342), fake.region })
		end)

		it("follows fake.profile.lengthUnit, and fake.region with none stored (LOG-R69)", function()
			local fake = newFakePagle()
			fake.login()

			fake.profile.lengthUnit = "cm"
			local cm = fake.Pagle.FormatLength(342)
			fake.profile.lengthUnit, fake.region = nil, 3
			local europe = fake.Pagle.FormatLength(342)
			fake.region = nil
			local none = fake.Pagle.FormatLength(342)

			assert.are.same({ "34.2 cm", "34.2 cm", "34.2 cm" }, { cm, europe, none })
		end)
	end)

	describe("the Field report (REP-R25, REP-R26)", function()
		-- Darkshore (148) with The Long Wash (453), neither with a skill base, and no items: every item is Uncharted.
		local function fixture()
			local function area(parent)
				return areaRecord(parent, { continent = 1, hasData = false })
			end
			return catalogueWith({
				areas = { [148] = area(0), [453] = area(148) },
				fishingSpells = { 7731 },
			})
		end

		it(
			"counts a live Uncharted Catch's I row, and the P rows of fake.global.diagnostics (REP-R10, REP-R22,"
				.. " REP-R26)",
			function()
				local fake = newFakePagle()
				fake.setCatalogue(fixture())
				fake.login()
				fake.enterWorld()
				assert.are.equal(0, fake.Pagle.GetFieldReportCount())

				local cast = assert(fake.playCast("caught", { { itemID = 9999, quantity = 1 } }))
				fake.playCast("caught", { { itemID = 9999, quantity = 1 } })
				assert.are.equal(1, fake.Pagle.GetFieldReportCount(), "two Catches on one key make one row")

				fake.global.diagnostics[1] =
					{ id = cast.id, zone = 148, subzone = 453, locale = "enUS", texts = { "A", "B" } }
				assert.are.equal(3, fake.Pagle.GetFieldReportCount())
			end
		)

		it(
			"catches up on the Casts already in the log at enterWorld, read-only as any projection (REP-R25, LOG-R71)",
			function()
				local fake = newFakePagle()
				fake.setCatalogue(fixture())
				fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
				for i = 1, 2 do
					fake.catchLog:Append({
						kind = "cast",
						char = 1,
						time = SERVER_TIME - 1000 + i,
						outcome = "caught",
						conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
						items = { { itemID = 9998 + i, quantity = 1 } },
					})
				end
				fake.login()
				fake.enterWorld()

				assert.are.equal(2, fake.Pagle.GetFieldReportCount(), "one I row per item")
				assert.is_table(fake.global.projections.fieldReport.projection) -- stored in fake.global
			end
		)

		it("gives the last stored count while the projection updates (REP-R26)", function()
			local fake = newFakePagle()
			fake.global.projections.fieldReport.projection = { build = 0, count = 5, I = {}, K = {} }

			assert.are.equal(5, fake.Pagle.GetFieldReportCount())
		end)

		it("returns the count a spec sets, until it sets nil (REP-R26)", function()
			local fake = newFakePagle()
			fake.login()
			fake.enterWorld()

			fake.setFieldReportCount(3)
			assert.are.equal(3, fake.Pagle.GetFieldReportCount())
			fake.setFieldReportCount(nil)
			assert.are.equal(0, fake.Pagle.GetFieldReportCount())
		end)

		it("shows on the compartment menu's entry, read as the menu opens (CORE-R50)", function()
			local fake = newFakePagle()
			fake.login()

			fake.setFieldReportCount(3)
			local menu = fake.menu()
			assert.are.equal("Help chart the waters (3)", menu[#menu - 1].label)
			fake.setFieldReportCount(0)
			menu = fake.menu()
			assert.are.equal("Help chart the waters", menu[#menu - 1].label)
		end)

		describe("the Field report box (REP-R40–R44)", function()
			it(
				"records each Pagle.OpenFieldReport a Module makes, with the report's parts and the URL (REP-R40, REP-R43)",
				function()
					local fake = newFakePagle()
					fake.setCatalogue(fixture())
					local loaded = fake.load("Pagle_QoL")
					fake.login()
					fake.enterWorld()
					fake.playCast("caught", { { itemID = 9999, quantity = 1 } })

					-- A Module reaches it through the read-only Pagle its globals hold.
					loaded.env.Pagle.OpenFieldReport()

					assert.are.equal(1, #fake.fieldReportsOpened)
					local view = fake.fieldReportsOpened[1]
					assert.is_nil(view.message)
					assert.are.equal(1, #view.parts)
					assert.truthy(view.parts[1]:find("^PAGLE%-REPORT 1\naddon test "))
					assert.truthy(view.parts[1]:find("\nI 9999 453 ", 1, true))
					assert.are.equal(
						"https://github.com/timemir/wow-fish/issues/new?template=field-report.yml",
						view.url
					)
					assert.are.same({}, fake.printed)
				end
			)

			it(
				"records REP-R41's line with no row, and REP-R42's while the projection updates (REP-R41, REP-R42)",
				function()
					local fake = newFakePagle()
					fake.login()
					fake.Pagle.OpenFieldReport()
					fake.enterWorld()
					fake.Pagle.OpenFieldReport()

					assert.are.same({
						{ message = "Updating... try again in a moment.", parts = {} },
						{ message = "Nothing to report. Thanks for checking!", parts = {} },
					}, fake.fieldReportsOpened)
				end
			)

			it("opens from /pagle report and the compartment entry (CORE-R61, REP-R43)", function()
				local fake = newFakePagle()
				fake.login()
				fake.enterWorld()

				fake.slash("report")
				local menu = fake.menu()
				menu[#menu - 1].onClick()

				assert.are.equal(2, #fake.fieldReportsOpened)
			end)

			it("prints REP-R44's line while restricted and records nothing (REP-R44, CORE-R33)", function()
				local fake = newFakePagle()
				fake.login()
				fake.enterWorld()
				fake.setRestricted(true)

				fake.Pagle.OpenFieldReport()
				fake.slash("report")

				assert.are.same({}, fake.fieldReportsOpened)
				assert.are.same({
					"Pagle: the Field report opens after combat.",
					"Pagle: the Field report opens after combat.",
				}, fake.printed)
			end)
		end)
	end)

	describe("the wallet projection", function()
		-- A fake whose history holds purchases of two Hunts covers at 150 and 400, and the first one again, with 600
		-- Coins earned, logged in.
		local function withPurchases()
			local fake = newFakePagle()
			fake.global.coins.earned.Ledger = 600
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for i, purchase in ipairs({
				{ "hunts.cover.velvet", 150 },
				{ "hunts.cover.silk", 400 },
				{ "hunts.cover.velvet", 150 },
			}) do
				fake.catchLog:Append({
					kind = "purchase",
					char = 1,
					time = SERVER_TIME - 700 + i,
					good = purchase[1],
					price = purchase[2],
				})
			end
			fake.login()
			return fake
		end

		it(
			"gives the spent total, the purchased set and the balance from the U1 entries in a history (SHOP-R11,"
				.. " SHOP-R12, LOG-R78)",
			function()
				local fake = withPurchases()

				fake.enterWorld()

				assert.are.same(
					{ spent = 550, purchased = { ["hunts.cover.velvet"] = true, ["hunts.cover.silk"] = true } },
					fake.global.projections.wallet.projection
				)
				assert.are.equal(50, fake.Pagle.GetBalance().balance)
				assert.are.same(
					{ true, true },
					{ fake.Pagle.IsOwned("hunts.cover.velvet"), fake.Pagle.IsOwned("hunts.cover.silk") }
				)
			end
		)

		it("takes a live ns.RecordPurchase, firing BalanceChanged once (SHOP-R10, SHOP-R11)", function()
			local fake = withPurchases()
			fake.enterWorld()
			local balances = {}
			fake.Pagle.RegisterCallback("spec", "BalanceChanged", function(_, balance)
				balances[#balances + 1] = balance.balance
			end)

			fake.ns.RecordPurchase("hunts.cover.gilt", 30)

			assert.are.same({ 20 }, balances)
			assert.is_true(fake.Pagle.IsOwned("hunts.cover.gilt"))
		end)

		it(
			"leaves fake.setSpent and fake.setPurchased in place until the projection hands over its own (SHOP-R11)",
			function()
				local fake = withPurchases()

				fake.setSpent(100)
				fake.setPurchased({ ["hunts.cover.gilt"] = true })
				assert.are.same(
					{ 500, true },
					{ fake.Pagle.GetBalance().balance, fake.Pagle.IsOwned("hunts.cover.gilt") }
				)

				fake.enterWorld()
				assert.are.same(
					{ 50, false },
					{ fake.Pagle.GetBalance().balance, fake.Pagle.IsOwned("hunts.cover.gilt") }
				)
			end
		)
	end)

	describe("the live conditions", function()
		-- fake.conditions with `fields` changed.
		local function changed(fake, fields)
			local snapshot = {}
			for key, value in pairs(fake.conditions) do
				snapshot[key] = value
			end
			for key, value in pairs(fields) do
				snapshot[key] = value
			end
			return snapshot
		end

		it("hands out fake.conditions, read-only, with the restriction flag (LOG-R45, CORE-R18)", function()
			local fake = newFakePagle()
			local conditions = fake.globals.Pagle.GetConditions()

			assert.are.equal(fake.conditions.zone, conditions.zone)
			assert.is_false(conditions.restricted)
			assert.has_error(function()
				conditions.zone = 0
			end)
			fake.setRestricted(true)
			assert.is_true(fake.globals.Pagle.GetConditions().restricted)
		end)

		it("fires ConditionsChanged with exactly the keys a new snapshot changed (LOG-R47)", function()
			local fake = newFakePagle()
			local fired = {}
			fake.Pagle.RegisterCallback("Spec", "ConditionsChanged", function(_, changedKeys)
				fired[#fired + 1] = { fake.globals.unpack(changedKeys) }
			end)

			fake.setConditions(changed(fake, { lure = 264, subzone = 0, minute = 600 }))
			fake.setConditions(changed(fake, { minute = 601 }))

			assert.are.same({ { "area", "lure" } }, fired)
			assert.are.equal(264, fake.globals.Pagle.GetConditions().lure)
		end)
	end)

	describe("window forecasts", function()
		local MINUTE = 60
		local DAY = { time = { { 360, 1260 } } } -- 06:00–21:00

		-- A catalogue in the M1 shape (DATA-R79) whose event list holds the Extravaganza (301) on Sundays from 14:00
		-- for 2 hours, confirmed.
		local function fixture()
			return catalogueWith({
				events = { [301] = { weekday = 1, start = 840, duration = 120, confirmed = true } },
			})
		end

		-- fake.conditions moved on to the realm clock time `minute`, later the same realm day.
		local function laterToday(fake, minute)
			local snapshot = {}
			for key, value in pairs(fake.conditions) do
				snapshot[key] = value
			end
			snapshot.time = snapshot.time + (minute - snapshot.minute) * MINUTE
			snapshot.minute = minute
			return snapshot
		end

		it("forecasts at the realm clock of fake.conditions, following setConditions (LOG-R49, LOG-R50)", function()
			local fake = newFakePagle()
			local Pagle = fake.globals.Pagle

			-- Realm 08:15: open until 21:00.
			local window = Pagle.NextWindow(DAY, fake.conditions.time)
			assert.is_true(window.openNow)
			assert.are.equal(SERVER_TIME + 765 * MINUTE, window.closesAt)

			-- Realm 22:00: back at 06:00 the next morning, until 21:00.
			fake.setConditions(laterToday(fake, 1320))
			window = Pagle.NextWindow(DAY, fake.conditions.time)
			assert.is_nil(window.openNow)
			assert.are.equal(SERVER_TIME + 1305 * MINUTE, window.opensAt)
			assert.are.equal(SERVER_TIME + 2205 * MINUTE, window.closesAt)
		end)

		it(
			"forecasts events from the fake's catalogue, open now when fake.conditions.events holds them (LOG-R50)",
			function()
				local fake = newFakePagle()
				fake.setCatalogue(fixture())
				local Pagle = fake.globals.Pagle

				-- Sunday 08:15: the Extravaganza opens at 14:00, for 2 hours.
				local window = Pagle.NextWindow({ events = { 301 } }, fake.conditions.time)
				assert.are.equal(SERVER_TIME + 345 * MINUTE, window.opensAt)
				assert.are.equal(SERVER_TIME + 465 * MINUTE, window.closesAt)
				assert.is_true(window.confirmed)

				local active = laterToday(fake, fake.conditions.minute)
				active.events = { 301 }
				fake.setConditions(active)
				assert.is_true(Pagle.NextWindow({ events = { 301 } }, fake.conditions.time).openNow)
			end
		)

		it(
			"forecasts only specs without time-based fields while the realm clock is secret (LOG-R49, LOG-R50)",
			function()
				local fake = newFakePagle()
				local Pagle = fake.globals.Pagle
				local secret = laterToday(fake, fake.conditions.minute)
				secret.minute = nil
				fake.setConditions(secret)
				assert.is_nil(Pagle.NextWindow(DAY, fake.conditions.time))
				assert.is_true(Pagle.NextWindow({ auras = { 1265220 } }, fake.conditions.time).onDemand)
				assert.is_true(Pagle.NextWindow({}, fake.conditions.time).always)
			end
		)

		it("forecasts a window spec Pagle.GetWindowSpec handed out, as Core does (LOG-R50, LOG-R55)", function()
			local Pagle = newFakePagle().globals.Pagle

			-- The generated day runs from 06:00 to midnight: open at realm 08:15.
			assert.is_true(Pagle.NextWindow(Pagle.GetWindowSpec("day"), SERVER_TIME).openNow)
		end)

		it("hands out a read-only Window (CORE-R18)", function()
			local window = newFakePagle().globals.Pagle.NextWindow(DAY, SERVER_TIME)
			assert.has_error(function()
				window.openNow = false
			end)
		end)
	end)

	describe("fishing", function()
		local FISHING_EVENTS = { "CastStarted", "Catch", "CastEnded", "FishingStateChanged" }

		-- Every fishing event a Module would get, in order, as { event, ... }.
		local function listen(fake)
			local fired = {}
			for _, event in ipairs(FISHING_EVENTS) do
				fake.Pagle.RegisterCallback("Spec " .. event, event, function(...)
					fired[#fired + 1] = { ... }
				end)
			end
			return fired
		end

		local function names(fired)
			local out = {}
			for i, step in ipairs(fired) do
				out[i] = step[1]
			end
			return out
		end

		it("plays a caught Cast to a Module, recorded first and in LOG-R9's order (LOG-R3, LOG-R9)", function()
			local fake = newFakePagle()
			fake.login()
			local fired = listen(fake)

			local cast = fake.playCast("caught", { { itemID = 6358, quantity = 1 }, { itemID = 6303, quantity = 2 } })

			assert.are.same({
				"CastStarted",
				"FishingStateChanged",
				"Catch",
				"Catch",
				"CastEnded",
				"FishingStateChanged",
				"FishingStateChanged",
			}, names(fired))
			assert.are.same({ "channeling", "looting", "idle" }, { fired[2][2], fired[6][2], fired[7][2] })
			assert.are.same(
				{ "C1|1|1791731700|0|c|495|1439|1|148|453|86|25|263|||6358x1,6303x2" },
				fake.catchLog.data.entries
			)
			assert.are.equal(PLAYER_GUID .. "-1791731700-0:2", fired[4][2].catchId)
			assert.are.equal(2, fired[4][2].quantity)
			assert.are.equal(cast, fired[5][3])
		end)

		it("hands out the record IterateCatches yields, read-only (LOG-R43, CORE-R18)", function()
			local fake = newFakePagle()
			fake.login()
			local fired = listen(fake)

			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })

			local record = fake.globals.Pagle.IterateCatches(0)()
			local catch = fired[3][2]
			-- Proxies hide their fields from busted's deep compare, so the fields are compared one by one.
			for _, cast in ipairs({ catch.cast, fired[4][3] }) do
				assert.are.same(
					{ record.seq, record.id, record.outcome, record.conditions.zone, record.items[1].catchId },
					{ cast.seq, cast.id, cast.outcome, cast.conditions.zone, cast.items[1].catchId }
				)
			end
			assert.are.equal(fired[4][3], catch.cast)
			assert.are.equal(record.items[1].catchId, catch.catchId)
			assert.has_error(function()
				catch.itemID = 0
			end)
			assert.has_error(function()
				catch.cast.outcome = "gotAway"
			end)
		end)

		it(
			"plays a got-away Cast with no items, and an interrupted one that writes nothing (LOG-R6, LOG-R7)",
			function()
				local fake = newFakePagle()
				fake.login()
				local fired = listen(fake)

				fake.playCast("gotAway")
				fake.playCast("interrupted")

				assert.are.same({ "C1|1|1791731700|0|g|495|1439|1|148|453|86|25|263|||" }, fake.catchLog.data.entries)
				assert.are.same({
					"CastStarted",
					"FishingStateChanged",
					"CastEnded",
					"FishingStateChanged",
					"CastStarted",
					"FishingStateChanged",
					"CastEnded",
					"FishingStateChanged",
				}, names(fired))
				assert.are.same({ "gotAway", "interrupted" }, { fired[3][2], fired[7][2] })
				assert.is_nil(fired[7][3])
			end
		)

		it("plays single signals on Core's real state machine: a recast within the grace time (LOG-R7)", function()
			local fake = newFakePagle()
			fake.login()
			local fired = listen(fake)

			fake.channel()
			fake.stopChannel()
			fake.wait(1)
			fake.channel()
			fake.wait(5)

			assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "CastStarted" }, names(fired))
			assert.are.equal("channeling", fake.globals.Pagle.GetFishingState())
		end)

		it("ends a stopped channel's Cast interrupted once the grace time has passed (LOG-R7)", function()
			local fake = newFakePagle()
			fake.login()
			local fired = listen(fake)
			fake.channel()
			fake.stopChannel()

			fake.wait(1.5)
			assert.are.equal(2, #fired)
			fake.wait(0.5)

			assert.are.same({ "CastEnded", "interrupted" }, fired[3])
			assert.are.equal("idle", fake.globals.Pagle.GetFishingState())
		end)

		it("records each Cast with fake.conditions at the fake's server time, which wait moves (LOG-R20)", function()
			local fake = newFakePagle()
			fake.login()
			fake.setConditions({
				time = 1791731700,
				minute = 600,
				date = { year = 2026, month = 10, day = 11, weekday = 1 },
				zone = 148,
				subzone = 0,
				events = {},
				auras = {},
			})

			fake.wait(30)
			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })

			assert.are.same({ "C1|1|1791731730|0|c|600|||148|0||||||6358x1" }, fake.catchLog.data.entries)
		end)

		it("ignores a channel whose spell isn't on the fishing-spell list (LOG-R2)", function()
			local fake = newFakePagle()
			fake.login()
			local fired = listen(fake)

			fake.channel(689)

			assert.are.same({}, fired)
			assert.are.equal("idle", fake.globals.Pagle.GetFishingState())
		end)
	end)

	describe("projections", function()
		-- The Ledger registered on `fake`, its projection over `db` noting each apply ("<seq> <kind> <mode>"), each
		-- done ("done") and the Cast and skill events, in order, in `seen`.
		local function ledger(fake, db)
			local seen = {}
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local projection = M:NewProjection({
				db = db,
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(state, record, mode)
					seen[#seen + 1] = record.seq .. " " .. record.kind .. " " .. mode
					seen.writable = pcall(function()
						record.seq = 0
					end)
					state.last = record.seq
				end,
				done = function(_, info)
					seen[#seen + 1] = "done"
					seen.info = info
				end,
			})
			for _, event in ipairs({ "Catch", "CastEnded", "SkillChanged" }) do
				fake.Pagle.RegisterCallback("Spec " .. event, event, function()
					seen[#seen + 1] = event
				end)
			end
			return M, projection, seen
		end

		-- fake.catchLog with the player's character and `casts` Casts in it, as history before login.
		local function withHistory(fake, casts)
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for i = 1, casts do
				fake.catchLog:Append({
					kind = "cast",
					char = 1,
					time = 1791731000 + i,
					outcome = "caught",
					conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
					items = { { itemID = 6358, quantity = 1 } },
				})
			end
		end

		it(
			"rebuild a fresh projection at enterWorld, at once, over the log as it was at login (LOG-R1, LOG-R72,"
				.. " LOG-R76)",
			function()
				local fake = newFakePagle()
				withHistory(fake, 600)
				local db = {}
				local _, projection, seen = ledger(fake, db)

				fake.login()
				fake.enterWorld()

				assert.are.equal(601, #seen)
				assert.are.same({ "600 cast rebuild", "done" }, { seen[600], seen[601] })
				assert.are.same({ firstBuild = true, rebuilt = true, replayed = 0 }, seen.info)
				assert.are.same({ 600, fake.catchLog.data.logId, 1 }, { db.lastSeq, db.logId, db.rulesVersion })
				assert.are.equal(fake.Pagle.CONTENT_FINGERPRINT, db.fingerprint)
				assert.is_false(projection:IsUpdating())
				assert.is_false(seen.writable)
			end
		)

		it("catch a stored projection up in replay mode (LOG-R71)", function()
			local fake = newFakePagle()
			withHistory(fake, 3)
			fake.login() -- the logId
			local db = {
				projection = {},
				lastSeq = 1,
				logId = fake.catchLog.data.logId,
				fingerprint = fake.Pagle.CONTENT_FINGERPRINT,
				rulesVersion = 1,
			}
			local _, _, seen = ledger(fake, db)

			fake.enterWorld()

			assert.are.same({ "2 cast replay", "3 cast replay", "done" }, { unpack(seen) })
			assert.are.same({ firstBuild = false, rebuilt = false, replayed = 2 }, seen.info)
		end)

		it("hand a Cast to the projection live, before Catch and CastEnded fire (LOG-R9, LOG-R73)", function()
			local fake = newFakePagle()
			local _, projection, seen = ledger(fake, {})
			fake.login()
			fake.enterWorld()

			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })

			assert.are.same({ "done", "1 cast live", "Catch", "CastEnded" }, { unpack(seen) })
			assert.are.equal(1, projection:GetState().last)
		end)

		it(
			"hand a Skill Reading over live before SkillChanged, and queue it before enterWorld (LOG-R1, LOG-R74)",
			function()
				local fake = newFakePagle()
				local _, _, seen = ledger(fake, {})
				fake.login()

				fake.readSkill(86, 150, 0)
				fake.enterWorld()
				fake.readSkill(87, 150, 0)

				assert.are.same(
					{ "SkillChanged", "done", "1 skill live", "2 skill live", "SkillChanged" },
					{ unpack(seen) }
				)
			end
		)

		it("serve the machinery's seams on fake.projections (LOG-R74, LOG-R75)", function()
			local fake = newFakePagle()
			local idle = false
			fake.projections:WhenIdle(function()
				idle = true
			end)
			fake.login()
			assert.is_true(fake.projections:IsUpdating())

			fake.enterWorld()

			assert.is_true(idle)
			assert.is_nil(fake.projections:Mode())
			assert.has_error(fake.enterWorld)
		end)
	end)

	describe("Sessions", function()
		-- Each Session event and each apply, in order, as "<event> <session id> [whileAway]" and "<seq> <mode>".
		local function listen(fake)
			local seen = {}
			for _, event in ipairs({ "SessionStarted", "SessionEnded", "Catch" }) do
				fake.Pagle.RegisterCallback("Spec " .. event, event, function(_, payload)
					local id = event == "Catch" and payload.cast.session or payload.id
					seen[#seen + 1] = event .. " " .. id .. (payload.whileAway and " whileAway" or "")
				end)
			end
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			M:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record, mode)
					seen[#seen + 1] = record.seq .. " " .. mode
				end,
			})
			return seen
		end

		-- The player's entry ID at the fake's server time SERVER_TIME + `offset` (LOG-R13).
		local function id(offset)
			return ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME + offset)
		end

		it("serve Pagle.SESSION_RULES_VERSION as Core does (LOG-R61)", function()
			assert.are.equal(
				loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle.SESSION_RULES_VERSION,
				newFakePagle().Pagle.SESSION_RULES_VERSION
			)
		end)

		it("serve Pagle.SESSION_GAP as Core does (LOG-R60, LOG-R61)", function()
			assert.are.same(
				{ 300, loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle.SESSION_GAP },
				{ newFakePagle().Pagle.SESSION_GAP, 300 }
			)
		end)

		it(
			"start with a played Cast, after its append and before its live apply, tagging it (LOG-R9, LOG-R62,"
				.. " LOG-R98)",
			function()
				local fake = newFakePagle()
				local seen = listen(fake)
				fake.login()
				fake.enterWorld()

				local cast = assert(fake.playCast("caught", { { itemID = 6358, quantity = 1 } }))

				assert.are.same({ "SessionStarted " .. id(0), "1 live", "Catch " .. id(0) }, seen)
				assert.are.equal(id(0), cast.session)
				assert.are.same({ id(0), 1 }, { fake.Pagle.GetSession().id, fake.Pagle.GetSession().casts })
			end
		)

		it("end when fake.wait(300) passes with no Cast, then GetSession is nil (LOG-R62, LOG-R64)", function()
			local fake = newFakePagle()
			local seen = listen(fake)
			fake.login()
			fake.enterWorld()
			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })

			fake.wait(299)
			assert.is_not_nil(fake.Pagle.GetSession())
			fake.wait(1)

			assert.are.equal("SessionEnded " .. id(0), seen[#seen])
			assert.is_nil(fake.Pagle.GetSession())
			fake.playCast("gotAway")
			assert.are.equal("SessionStarted " .. id(300), seen[#seen - 1])
		end)

		it("end a Session that ended before login with whileAway, once no projection is updating (LOG-R63)", function()
			local fake = newFakePagle()
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			fake.catchLog:Append({
				kind = "cast",
				char = 1,
				time = SERVER_TIME - 300,
				outcome = "caught",
				conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
				items = { { itemID = 6358, quantity = 1 } },
			})
			local seen = listen(fake)

			fake.login()
			assert.are.same({}, seen)
			fake.enterWorld()

			assert.are.same({ "1 rebuild", "SessionEnded " .. id(-300) .. " whileAway" }, seen)
			assert.are.equal(id(-300), fake.global.lastEndedSession)
		end)

		it("fire no SessionEnded at login for the Session a seeded global.lastEndedSession names (LOG-R63)", function()
			local fake = newFakePagle()
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			fake.catchLog:Append({
				kind = "cast",
				char = 1,
				time = SERVER_TIME - 300,
				outcome = "caught",
				conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
				items = { { itemID = 6358, quantity = 1 } },
			})
			fake.global.lastEndedSession = id(-300)
			local seen = listen(fake)

			fake.login()
			fake.enterWorld()

			assert.are.same({ "1 rebuild" }, seen)
		end)
	end)

	describe("the Session summary", function()
		-- A Module registered on `fake` whose projection raises `raise(record)`'s moment for each live Cast.
		local function raising(fake, name, order, raise)
			local M = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
			M:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function(_, record, mode)
					if record.kind == "cast" and mode == "live" then
						M:RaiseMoment(raise(record))
					end
				end,
			})
			return M
		end

		it(
			"make a card when a Session with moments ends, with Core's numbers, the Coins sum, the lines and the"
				.. " moments by Module order (ANN-R25, ANN-R51, ANN-R53)",
			function()
				local fake = newFakePagle()
				raising(fake, "Hunts", 20, function(record)
					return { rung = "toast.high", kind = "hunt", title = "Hunt completed", cast = record.id, coins = 15 }
				end)
				local ledger = raising(fake, "Ledger", 10, function(record)
					return { rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id }
				end)
				ledger:SetSummaryLine("level", "Angler Level 12")
				fake.login()
				fake.enterWorld()

				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				-- In the order raised: Hunts' projection was added first, so it applied the Cast first.
				assert.are.same({ "Hunt completed", "New Species" }, {
					fake.global.summary.moments[1].title,
					fake.global.summary.moments[2].title,
				})
				fake.wait(300)

				local card = fake.global.cards[1]
				assert.are.same({ casts = 1, catches = 1, gotAway = 0, seconds = 0 }, card.numbers)
				assert.are.equal(15, card.coins)
				assert.are.same({ { module = "Ledger", title = "Ledger", lines = { "Angler Level 12" } } }, card.lines)
				assert.are.same({ "Ledger", "Hunts" }, { card.moments[1].module, card.moments[2].module })
				assert.are.same({}, fake.global.summary.moments)
			end
		)

		it("make no card for a Session without moments, lines or not (ANN-R53)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			M:SetSummaryLine("level", "Angler Level 12")
			fake.login()
			fake.enterWorld()
			fake.playCast("gotAway")

			fake.wait(300)

			assert.are.same({}, fake.global.cards)
		end)

		it("keep a moment raised with no Session open for the next Session's card (ANN-R52)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			fake.login()
			fake.enterWorld()
			M:RaiseMoment({ rung = "nod", kind = "loginNod", title = "Welcome back" })
			assert.are.equal("Welcome back", fake.global.pending[1].title)

			fake.playCast("gotAway")
			fake.wait(300)

			assert.are.equal("Welcome back", fake.global.cards[1].moments[1].moments[1].title)
		end)

		it("raise an error for M:SetSummaryLine with a bad key, as Core does (ANN-R51)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

			assert.has_error(function()
				M:SetSummaryLine(nil, "text")
			end)
		end)

		it(
			"count the moments kept in Cozy mode on the compartment's label until the Session's card shows"
				.. " (CORE-R51, ANN-R42)",
			function()
				local fake = newFakePagle()
				raising(fake, "Ledger", 10, function(record)
					return { rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id }
				end)
				fake.profile.announcements.cozy = true
				fake.login()
				fake.enterWorld()
				fake.nextFrame()
				fake.nextFrame()
				assert.are.equal("Pagle", fake.compartmentText())

				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
				assert.are.equal("Pagle · 2 waiting", fake.compartmentText())
				fake.wait(300)

				assert.are.equal("Fishing session", fake.cardsShown[1].title)
				assert.are.equal("Pagle", fake.compartmentText())
			end
		)

		it("mark a moment expired by the Session's end, so its card shows its pastText (ANN-R45)", function()
			local fake = newFakePagle()
			raising(fake, "Hunts", 20, function(record)
				return {
					rung = "nod",
					kind = "window",
					title = "Window open",
					cast = record.id,
					expiresAt = SERVER_TIME + 200,
					pastText = "Window opened 21:00–06:00",
				}
			end)
			fake.login()
			fake.enterWorld()

			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
			fake.wait(300)

			local moment = fake.global.cards[1].moments[1].moments[1]
			assert.is_true(moment.expired)
			assert.are.same(
				{ { kind = "heading", text = "Hunts" }, { kind = "moment", text = "Window opened 21:00–06:00" } },
				fake.ns.CardRows(fake.global.cards[1], tostring)
			)
		end)
	end)

	describe("the cards", function()
		-- `casts` caught Casts in fake.catchLog, of a Session still open at login.
		local function withHistory(fake, casts)
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for i = 1, casts do
				fake.catchLog:Append({
					kind = "cast",
					char = 1,
					time = SERVER_TIME - 100 + i,
					outcome = "caught",
					conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
					items = { { itemID = 6358, quantity = 1 } },
				})
			end
		end

		-- A Module registered on `fake` whose projection raises a Write-up section from its done on a first build.
		local function writingUp(fake, name, order)
			local M = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
			M:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function(_, info)
					if info.firstBuild then
						M:RaiseWriteUp({ heading = name .. " written up", lines = { "3 Species" } })
					end
				end,
			})
			return M
		end

		it(
			"record each Write-up section raised, and show one Write-up card by Module order on the frame after the"
				.. " held Announcements' (ANN-R21, ANN-R60, ANN-R61)",
			function()
				local fake = newFakePagle()
				withHistory(fake, 2)
				writingUp(fake, "Hunts", 20)
				writingUp(fake, "Ledger", 10)
				fake.login()
				fake.enterWorld()

				assert.are.same({ "Hunts", "Ledger" }, { fake.writeUps[1].module, fake.writeUps[2].module })
				assert.are.same(
					{ "Hunts written up", { "3 Species" } },
					{ fake.writeUps[1].heading, fake.writeUps[1].lines }
				)
				fake.nextFrame()
				assert.are.same({}, fake.cardsShown)
				fake.nextFrame()

				assert.are.equal(1, #fake.cardsShown)
				local card = fake.cardsShown[1]
				assert.are.same({ "Write-up", "Ledger written up", "Hunts written up" }, {
					card.title,
					card.writeUp[1].heading,
					card.writeUp[2].heading,
				})
				fake.closeCard()
				assert.are.same({}, fake.global.writeUp)
			end
		)

		it("raise an error for M:RaiseWriteUp outside a projection's done, as Core does (ANN-R60)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			fake.login()
			fake.enterWorld()

			assert.has_error(function()
				M:RaiseWriteUp({ heading = "Written up", lines = {} })
			end)
			assert.are.same({}, fake.writeUps)
		end)

		it(
			"in Cozy mode show no Write-up card, and put its section on the next Session's card, which shows although"
				.. " that Session raised nothing (ANN-R54, ANN-R62)",
			function()
				local fake = newFakePagle()
				withHistory(fake, 2)
				writingUp(fake, "Ledger", 10)
				fake.profile.announcements.cozy = true
				fake.login()
				fake.enterWorld()
				fake.nextFrame()
				fake.nextFrame()
				assert.are.same({}, fake.cardsShown)

				fake.playCast("gotAway")
				fake.wait(300)

				assert.are.same({ "Fishing session", "Ledger written up" }, {
					fake.cardsShown[1].title,
					fake.cardsShown[1].writeUp[1].heading,
				})
				fake.closeCard()
				assert.are.same({}, fake.global.cards)
			end
		)
	end)

	describe("onboarding", function()
		-- `casts` of the fake character's caught Casts in fake.catchLog's history, long before login.
		local function withHistory(fake, casts)
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for i = 1, casts do
				fake.catchLog:Append({
					kind = "cast",
					char = 1,
					time = 1791731000 + i,
					outcome = "caught",
					conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
					items = { { itemID = 6358, quantity = 1 } },
				})
			end
		end

		it("adds the state at login, waiting for a new Angler, with the character in it (ONB-R1–R3)", function()
			local fake = newFakePagle()
			assert.is_nil(fake.global.onboarding)

			fake.login()

			local expected = fake.ns.NewOnboardingState("waiting")
			expected.characters[PLAYER_GUID] = true
			assert.are.same(expected, fake.global.onboarding)
			assert.is_false(fake.onboarding:IsReturning())
		end)

		it("is returning when the history holds a Cast, and raises the welcome hook once (ONB-R2)", function()
			local fake = newFakePagle()
			withHistory(fake, 2)
			local raised = 0
			fake.onboarding:SetHook("welcome", function()
				raised = raised + 1
			end)
			fake.login()
			fake.enterWorld()

			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
			fake.wait(20)

			assert.are.equal("returning", fake.global.onboarding.letter)
			assert.are.equal(1, raised)
		end)

		it("raises the character hook for a second character while QoL is registered (ONB-R3)", function()
			local fake = newFakePagle()
			local seeded = fake.ns.NewOnboardingState("opened")
			seeded.characters["Player-4618-0A1B2C3D"] = true
			fake.global.onboarding = seeded
			fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
			local raised = 0
			fake.onboarding:SetHook("character", function()
				raised = raised + 1
			end)

			fake.login()

			assert.are.equal(1, raised)
			assert.are.equal(seeded, fake.global.onboarding)
			assert.is_true(seeded.characters[PLAYER_GUID])
		end)

		it("runs /pagle guide notes and /pagle dev onboarding reset as Core does (ONB-R80, ONB-R83)", function()
			local fake = newFakePagle()
			withHistory(fake, 3)
			fake.login()
			fake.onboarding:MarkNoteSeen("core.nod")

			fake.slash("guide notes")
			fake.slash("dev on")
			fake.slash("dev onboarding reset")

			local expected = fake.ns.NewOnboardingState("waiting")
			expected.characters[PLAYER_GUID] = true
			assert.are.same(expected, fake.global.onboarding)
			assert.are.same({
				"Pagle: margin notes will show again, once each.",
				"Pagle dev: dev commands are on.",
				"Pagle dev: onboarding is back as a new Angler's, with the Letter waiting; /reload to start from there.",
			}, fake.printed)
		end)
	end)

	describe("Margin notes", function()
		-- A stand-in target region, shown until `hidden` is set.
		local function region()
			local made = { hidden = false }
			function made:IsVisible()
				return not self.hidden
			end
			return made
		end

		-- QoL registered and logged in; returns its handle.
		local function withQoL(fake)
			local M = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
			fake.login()
			return M
		end

		-- The ids of the notes fake.notesShown holds, in order.
		local function shownIds(fake)
			local ids = {}
			for i, note in ipairs(fake.notesShown) do
				ids[i] = note.id
			end
			return ids
		end

		local LURE = "Your pole has no lure on. |cff9a2a1aOnly that|r; then you cast."

		it(
			"shows a Module's note once per account, marking notesSeen, through M:ShowMarginNote (ONB-R50, ONB-R92)",
			function()
				local fake = newFakePagle()
				local M = withQoL(fake)
				local button = region()

				M:ShowMarginNote({ id = "qol.lure", text = LURE, target = button })
				fake.wait(12)
				M:ShowMarginNote({ id = "qol.lure", text = LURE, target = button })

				assert.are.same({ "qol.lure" }, shownIds(fake))
				assert.are.equal(button, fake.notesShown[1].target)
				assert.is_true(fake.global.onboarding.notesSeen["qol.lure"])
			end
		)

		it("shows nothing with Margin notes off (ONB-R50, ONB-R81)", function()
			local fake = newFakePagle()
			local M = withQoL(fake)
			fake.global.onboarding.notesOn = false

			M:ShowMarginNote({ id = "qol.lure", text = LURE, target = region() })

			assert.are.same({}, fake.notesShown)
		end)

		it("raises an error at the Module's call for a missing or mistyped field, showing nothing (ONB-R90)", function()
			local fake = newFakePagle()
			local M = withQoL(fake)

			local ok, err = pcall(function()
				M:ShowMarginNote({ id = "ledger.fresh", text = LURE, target = region() })
			end)

			assert.is_false(ok)
			assert.matches("fake_pagle_spec%.lua:%d+: ShowMarginNote: a note's id is qol%.<name>", tostring(err))
			assert.are.same({}, fake.notesShown)
		end)

		it("holds a note raised in combat until after it, and drops one whose target hid (ONB-R51)", function()
			local fake = newFakePagle()
			local M = withQoL(fake)
			local stays, goes = region(), region()

			fake.setRestricted(true)
			M:ShowMarginNote({ id = "qol.lure", text = LURE, target = stays })
			M:ShowMarginNote({ id = "qol.bare", text = LURE, target = goes })
			goes.hidden = true
			assert.are.same({}, fake.notesShown)
			fake.setRestricted(false)

			assert.are.same({ "qol.lure" }, shownIds(fake))
			assert.is_nil(fake.global.onboarding.notesSeen["qol.bare"])
		end)

		it("takes a note away after 12 s (ONB-R51)", function()
			local fake = newFakePagle()
			local M = withQoL(fake)
			M:ShowMarginNote({ id = "qol.lure", text = LURE, target = region() })

			fake.wait(11.5)
			assert.are.equal(1, #fake.marginNotes:Showing())
			fake.wait(0.5)

			assert.are.same({}, fake.marginNotes:Showing())
		end)

		it(
			"shows core.welcome on Pagle's menu button for a returning Angler at the first SessionStarted (ONB-R2)",
			function()
				local fake = newFakePagle()
				fake.global.onboarding = fake.ns.NewOnboardingState("returning")
				fake.login()
				fake.enterWorld()

				fake.playCast("caught", { { itemID = 6358, quantity = 1 } })

				assert.are.same({ "core.welcome" }, shownIds(fake))
				assert.are.equal(fake.menuButton, fake.notesShown[1].target())
				assert.are.equal(
					"Welcome back. |cff9a2a1a/pagle guide|r shows you around, if you want the tour.",
					fake.notesShown[1].text
				)
			end
		)

		it(
			"shows core.character on another character while QoL is registered, and not without QoL (ONB-R3, ONB-R101)",
			function()
				local fake = newFakePagle()
				fake.global.onboarding = fake.ns.NewOnboardingState("opened")
				fake.global.onboarding.characters["Player-4618-0A1B2C3D"] = true
				withQoL(fake)
				assert.are.same({ "core.character" }, shownIds(fake))

				local without = newFakePagle()
				without.global.onboarding = without.ns.NewOnboardingState("opened")
				without.global.onboarding.characters["Player-4618-0A1B2C3D"] = true
				without.login()
				assert.are.same({}, without.notesShown)
			end
		)

		it("shows a note seen before with /pagle dev onboarding note <id>, marking nothing (ONB-R83)", function()
			local fake = newFakePagle()
			local M = withQoL(fake)
			M:ShowMarginNote({ id = "qol.lure", text = LURE, target = region() })
			fake.wait(12)
			fake.slash("dev on")

			fake.slash("dev onboarding note qol.lure")
			fake.slash("dev onboarding note core.welcome")
			fake.slash("dev onboarding note core.nod")
			fake.slash("dev onboarding note qol.nothing")

			assert.are.same({ "qol.lure", "qol.lure", "core.welcome" }, shownIds(fake))
			assert.is_nil(fake.global.onboarding.notesSeen["core.welcome"])
			assert.are.same({
				"Pagle dev: dev commands are on.",
				"Pagle dev: margin note core.nod has nothing on screen to point at now.",
				"Pagle dev: no margin note qol.nothing; the notes are core.character, core.nod, core.summary,"
					.. " core.toast, core.uncharted, core.welcome, qol.lure.",
			}, fake.printed)
		end)
	end)

	describe("First looks", function()
		-- A stand-in region, shown until `hidden` is set.
		local function region()
			local made = { hidden = false }
			function made:IsVisible()
				return not self.hidden
			end
			return made
		end

		-- A stand-in window as a client frame behaves: Show and Hide, and OnHide's hooks run as it hides.
		local function window()
			local made = { shown = false, hooks = {} }
			function made:IsShown()
				return self.shown
			end
			function made:Show()
				self.shown = true
			end
			function made:Hide()
				self.shown = false
				for _, hook in ipairs(self.hooks.OnHide or {}) do
					hook(self)
				end
			end
			function made:HookScript(script, fn)
				self.hooks[script] = self.hooks[script] or {}
				table.insert(self.hooks[script], fn)
			end
			return made
		end

		-- The Ledger registered and logged in; returns its handle.
		local function withLedger(fake)
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			fake.login()
			return M
		end

		-- The Fish Journal's set: three notes on `targets`, the second's text with its red term.
		local function journal(frame, targets)
			local notes = {}
			for i, target in ipairs(targets) do
				notes[i] = {
					text = i == 2 and "The *blue* stretch is Fresh Water." or "Note " .. i .. ".",
					target = function()
						return target
					end,
					x = -214,
					y = 100 * i,
					w = 200,
				}
			end
			return { id = "ledger.journal", window = frame, title = "the Fish Journal", notes = notes }
		end

		-- Each note fake.looksShown[i] holds, as "n. text".
		local function notesOf(fake, i)
			local read = {}
			for j, note in ipairs(fake.looksShown[i].notes) do
				read[j] = note.n .. ". " .. note.text
			end
			return read
		end

		it(
			"shows a Module's set the first time its window opens, marking looksSeen, and never again (ONB-R55)",
			function()
				local fake = newFakePagle()
				local M = withLedger(fake)
				local frame = window()
				M:RegisterFirstLook(journal(frame, { region(), region(), region() }))

				frame:Show()
				assert.is_true(M:ShowFirstLook("ledger.journal"))
				frame:Hide()
				frame:Show()
				assert.is_false(M:ShowFirstLook("ledger.journal"))

				assert.are.equal(1, #fake.looksShown)
				assert.are.equal("the Fish Journal", fake.looksShown[1].title)
				assert.are.same(
					{ "1. Note 1.", "2. The *blue* stretch is Fresh Water.", "3. Note 3." },
					notesOf(fake, 1)
				)
				assert.is_true(fake.global.onboarding.looksSeen["ledger.journal"])
				assert.is_nil(fake.firstLooks:Showing())
			end
		)

		it("drops a note whose target is hidden, numbering the rest 1 to n (ONB-R56)", function()
			local fake = newFakePagle()
			local M = withLedger(fake)
			local hidden = region()
			hidden.hidden = true
			M:RegisterFirstLook(journal(window(), { region(), hidden, region() }))

			M:ShowFirstLook("ledger.journal")

			assert.are.same({ "1. Note 1.", "2. Note 3." }, notesOf(fake, 1))
		end)

		it('shows it again on the "?", with Margin notes off too, and hides it on a second press (ONB-R59)', function()
			local fake = newFakePagle()
			local M = withLedger(fake)
			fake.global.onboarding.notesOn = false
			M:RegisterFirstLook(journal(window(), { region() }))

			assert.is_false(M:ShowFirstLook("ledger.journal"))
			assert.is_true(M:ShowFirstLook("ledger.journal", true))
			assert.is_true(fake.global.onboarding.looksSeen["ledger.journal"])
			assert.is_false(M:ShowFirstLook("ledger.journal", true))

			assert.are.equal(1, #fake.looksShown)
			assert.is_nil(fake.firstLooks:Showing())
		end)

		it("raises an error at the Module's call for a missing or mistyped field, adding nothing (ONB-R90)", function()
			local fake = newFakePagle()
			local M = withLedger(fake)
			local set = journal(window(), { region() })
			set.title = nil

			local ok, err = pcall(function()
				M:RegisterFirstLook(set)
			end)
			assert.is_false(ok)
			assert.matches(
				"fake_pagle_spec%.lua:%d+: RegisterFirstLook: set ledger%.journal needs a title",
				tostring(err)
			)
			assert.are.same({}, fake.firstLooks:List())

			ok, err = pcall(function()
				M:ShowFirstLook("hunts.board")
			end)
			assert.is_false(ok)
			assert.matches(
				"fake_pagle_spec%.lua:%d+: ShowFirstLook: hunts%.board is not one of Ledger's",
				tostring(err)
			)
		end)
	end)

	describe("the Field guide", function()
		-- The fixture Modules' steps at their orders (ONB-R21), each Module but `without` registered: QoL's two, the
		-- Ledger's and the Tackle Board's, with Core's four at 10, 20, 50 and 90. Returns the handles by name.
		local function withSteps(fake, without)
			local handles = {}
			for _, fixture in ipairs({
				{ "QoL", 50, { { "casting", 30 }, { "clothes", 40 } } },
				{ "Ledger", 10, { { "ledger", 60 } } },
				{ "TackleBoard", 40, { { "board", 70 } } },
			}) do
				if fixture[1] ~= without then
					local M = fake.Pagle.RegisterModule({ name = fixture[1], title = fixture[1], order = fixture[2] })
					for _, step in ipairs(fixture[3]) do
						M:RegisterGuideStep({ id = step[1], order = step[2], ribbon = step[1], build = function() end })
					end
					handles[fixture[1]] = M
				end
			end
			return handles
		end

		-- The guide opened at its first step, then Next to the end: each page shown's id and its "n of m".
		local function walk(fake)
			fake.guide:Open()
			for _ = 1, fake.guideSteps:Count() do
				fake.guide:Next()
			end
			local walked = {}
			for i, page in ipairs(fake.guideShown) do
				walked[i] = ("%s %d of %d"):format(page.id, page.index, page.count)
			end
			return walked
		end

		it("shows Core's steps and the fixture Modules' in order, n of 8 (ONB-R20, ONB-R21)", function()
			local fake = newFakePagle()
			withSteps(fake)
			fake.login()

			assert.are.same({
				"welcome 1 of 8",
				"box 2 of 8",
				"casting 3 of 8",
				"clothes 4 of 8",
				"moments 5 of 8",
				"ledger 6 of 8",
				"board 7 of 8",
				"off 8 of 8",
			}, walk(fake))
			assert.is_true(fake.guideHeld)
		end)

		it("drops a Module's steps when it never registered, so the count drops: n of 7 (ONB-R21)", function()
			local fake = newFakePagle()
			withSteps(fake, "TackleBoard")
			fake.login()

			local walked = walk(fake)

			assert.are.equal(7, #walked)
			assert.are.equal("ledger 6 of 7", walked[6])
			assert.are.equal("off 7 of 7", walked[7])
		end)

		it("raises an error at the Module's call for a step with no build, adding nothing (ONB-R90)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

			local ok, problem = pcall(function()
				M:RegisterGuideStep({ id = "ledger", order = 60, ribbon = "Your Ledger" })
			end)

			assert.is_false(ok)
			assert.matches("fake_pagle_spec%.lua:%d+: RegisterGuideStep: step ledger needs build", tostring(problem))
			assert.are.equal(4, fake.guideSteps:Count())
		end)

		it("reports a step registered after ModulesChanged through geterrorhandler(), dropping it (ONB-R21)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			fake.login()

			M:RegisterGuideStep({ id = "ledger", order = 60, ribbon = "Your Ledger", build = function() end })

			assert.are.equal(1, #fake.reported)
			assert.matches("after ModulesChanged", tostring(fake.reported[1]))
			assert.is_nil(fake.guideSteps:Index("ledger"))
		end)

		it(
			"opens with /pagle guide and resumes at guideStep, holding Announcements while open (ONB-R22, ONB-R80)",
			function()
				local fake = newFakePagle()
				withSteps(fake)
				fake.login()
				fake.slash("guide")
				fake.guide:GoTo("ledger")
				fake.guide:Close()
				assert.is_false(fake.guideHeld)

				fake.slash("guide")

				assert.are.equal("ledger", fake.global.onboarding.guideStep)
				assert.are.same({ id = "ledger", how = "open", index = 6, count = 8 }, fake.guideShown[3])
				assert.is_true(fake.guideHeld)
			end
		)

		it("closes for a restriction and reopens after at the same step (ONB-R25)", function()
			local fake = newFakePagle()
			withSteps(fake)
			fake.login()
			fake.guide:Open("clothes")

			fake.setRestricted(true)
			assert.is_false(fake.guide:IsOpen())
			assert.is_true(fake.global.onboarding.reopen)
			fake.setRestricted(false)

			assert.is_true(fake.guide:IsOpen())
			assert.are.equal("clothes", fake.guide:Current().step.id)
			assert.is_false(fake.global.onboarding.reopen)
		end)

		it(
			"runs a step's build once, at its first showing, on the Module's client with Core's nav (Contracts)",
			function()
				local fake = newFakePagle()
				fake.load("Pagle_Stats")
				local M = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
				local built = {}
				M:RegisterGuideStep({
					id = "ledger",
					order = 60,
					ribbon = "Your Ledger",
					build = function(left, right, nav)
						built[#built + 1] = { left:GetWidth(), right:GetHeight() }
						nav.ChoiceCard(right, "Lively", "Every Catch gets its Nod.", "as it comes")
						nav.Next()
					end,
				})
				fake.login()

				fake.guide:Open("ledger")
				fake.guide:Back()
				fake.guide:Next()

				assert.are.same({ { 442, 546 } }, built)
				assert.are.equal("Lively", fake.guidePages.ledger.right.children[1].title)
				assert.are.equal("off", fake.guideShown[2].id)
			end
		)

		it("hands a build a binding field that keeps SetGreyed and counts Refresh (ONB-R32, ONB-R44)", function()
			local fake = newFakePagle()
			fake.load("Pagle_Stats")
			local M = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
			M:RegisterGuideStep({
				id = "casting",
				order = 30,
				ribbon = "Casting",
				build = function(_, right, nav)
					local field = nav.BindingField(right, "PAGLE_FISHING_KEY", "Fishing key")
					field:SetGreyed(true)
					field:Refresh()
				end,
			})
			fake.login()

			fake.guide:Open("casting")

			local field = fake.guidePages.casting.right.children[1]
			assert.are.same(
				{ "PAGLE_FISHING_KEY", "Fishing key", true, 1 },
				{ field.action, field.label, field.greyed, field.refreshed }
			)
		end)

		it(
			"gives each step a tour stop with Core's ns.AddGuideTourStops, leaving the state as it was (ONB-R84)",
			function()
				local fake = newFakePagle()
				withSteps(fake)
				fake.login()
				assert.are.same({}, fake.ns.tourStops:List(fake.registry:Modules(), "core"))
				fake.ns.AddGuideTourStops()
				local stop
				for _, listed in ipairs(fake.ns.tourStops:List(fake.registry:Modules(), "core")) do
					if listed.name == "core.onboarding.step.board" then
						stop = listed
					end
				end

				stop.show()
				assert.is_true(fake.guide:IsOpen())
				stop.hide()

				assert.is_false(fake.guide:IsOpen())
				assert.is_nil(fake.global.onboarding.guideStep)
				assert.are.same({}, fake.global.onboarding.stepsSeen)
				assert.is_false(fake.guideHeld)
			end
		)
	end)

	describe("the Letter", function()
		-- A new Angler's fake, logged in with QoL registered, past PLAYER_ENTERING_WORLD's delay and the cards'
		-- settling. Returns the fake and QoL's handle.
		local function arrived()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
			fake.login()
			fake.enterWorld()
			fake.letter:EnteredWorld()
			fake.wait(fake.ns.LETTER_DELAY)
			fake.nextFrame()
			fake.nextFrame()
			return fake, M
		end

		it("shows for a new Angler once the delay has passed and the cards have settled (ONB-R10)", function()
			local fake = arrived()

			assert.is_true(fake.letterOnScreen)
			assert.is_true(fake.letter:IsShowing())
		end)

		it("waits while a Module says its dialog is open, and shows as it closes (ONB-R10, ONB-R100)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
			fake.login()
			M:SetDialogOpen(true)
			fake.enterWorld()
			fake.letter:EnteredWorld()
			fake.wait(fake.ns.LETTER_DELAY)
			fake.nextFrame()
			fake.nextFrame()
			assert.is_true(fake.letter:IsDialogOpen())
			assert.is_false(fake.letterOnScreen)

			M:SetDialogOpen(false)

			assert.is_true(fake.letterOnScreen)
		end)

		it("raises an error at the Module's call for an open that isn't a boolean (ONB-R90's sense)", function()
			local fake = newFakePagle()
			local M = fake.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })

			local ok, problem = pcall(function()
				M:SetDialogOpen("yes")
			end)
			local okSelf, problemSelf = pcall(function()
				M.SetDialogOpen({}, true)
			end)

			assert.is_false(ok)
			assert.matches("fake_pagle_spec%.lua:%d+: SetDialogOpen: open must be true or false", tostring(problem))
			assert.is_false(okSelf)
			assert.matches("call M:SetDialogOpen%(open%)", tostring(problemSelf))
			assert.is_false(fake.letter:IsDialogOpen())
		end)

		it("hides as a restriction starts and shows again as it ends (ONB-R14)", function()
			local fake = arrived()

			fake.setRestricted(true)
			assert.is_false(fake.letterOnScreen)
			fake.setRestricted(false)

			assert.is_true(fake.letterOnScreen)
		end)

		it("opens the guide at its first step from Open the letter, setting opened (ONB-R12)", function()
			local fake = arrived()

			fake.letter:Open()

			assert.is_false(fake.letterOnScreen)
			assert.are.equal("opened", fake.global.onboarding.letter)
			assert.are.same({ id = "welcome", how = "open", index = 1, count = 4 }, fake.guideShown[1])
		end)

		it("shows from /pagle dev onboarding letter with dev mode on (ONB-R83)", function()
			local fake = newFakePagle()
			fake.global.onboarding = fake.ns.NewOnboardingState("declined")
			fake.login()

			fake.slash("dev on")
			fake.slash("dev onboarding letter")

			assert.is_true(fake.letterOnScreen)
		end)
	end)

	describe("the First evening list", function()
		-- A fixture Hunts with a docked tracker 40 px tall, and a fixture Ledger, registered; then login, a new Angler's
		-- with the Letter opened. Returns the two handles and Hunts' frame.
		local function withList(fake)
			fake.global.onboarding = fake.ns.NewOnboardingState("opened")
			local ledger = fake.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			local frame = {
				IsShown = function()
					return true
				end,
				GetWidth = function()
					return 200
				end,
				GetHeight = function()
					return 40
				end,
			}
			hunts:RegisterTracker({ id = "hunts", order = 10, frame = frame })
			fake.login()
			return ledger, hunts, frame
		end

		-- Off to the water, on a guide open at its last step.
		local function offToTheWater(fake)
			fake.guide:Open("off")
			fake.guide:Finish()
		end

		-- The ids of the stack's trackers, top to bottom.
		local function stacked(fake)
			local ids = {}
			for i, tracker in ipairs(fake.dock.stack()) do
				ids[i] = tracker.module .. "." .. tracker.id
			end
			return ids
		end

		it("docks after Off to the water as Core's own tracker, above Hunts' (ONB-R60, CORE-R70)", function()
			local fake = newFakePagle()
			withList(fake)
			assert.are.same({ "Hunts.hunts" }, stacked(fake))

			offToTheWater(fake)

			assert.are.same({ "Core.evening", "Hunts.hunts" }, stacked(fake))
			assert.are.same({ 0, -168 }, { fake.dock.stack()[1].y, fake.dock.stack()[2].y })
			assert.is_true(fake.global.onboarding.evening.shown)
			assert.are.same({ 0, 6 }, { fake.eveningList.done, fake.eveningList.total })
		end)

		it("ticks a Cast, a Catch, a Session ending without a card and the shop opening (ONB-R61)", function()
			local fake = newFakePagle()
			withList(fake)
			fake.enterWorld()
			offToTheWater(fake)

			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
			fake.wait(300) -- an ordinary Catch raises no moment, so its Session ends with no card (ANN-R53)
			fake.Pagle.OpenShop()

			local done = {}
			for _, line in ipairs(fake.eveningList.lines) do
				done[#done + 1] = line.id .. (line.done and " done" or "")
			end
			assert.are.same({ "cast done", "catch done", "journal", "hunts", "session done", "shop done" }, done)
			assert.are.same({ "tick", "tick", "tick", "tick" }, fake.eveningSounds)
			assert.are.same({}, fake.cardsShown)
		end)

		it(
			"ticks a fixture Module's own item through M:CompleteEveningItem, and refuses another's (ONB-R61)",
			function()
				local fake = newFakePagle()
				local ledger, hunts = withList(fake)
				offToTheWater(fake)

				ledger:CompleteEveningItem("journal")

				assert.is_true(fake.onboarding:IsEveningItemDone("journal"))
				assert.are.same({ "tick" }, fake.eveningSounds)
				assert.has_error(function()
					hunts:CompleteEveningItem("journal")
				end, "M:CompleteEveningItem: journal is not one of Hunts's First evening items")
				assert.has_error(function()
					ledger.CompleteEveningItem({}, "journal")
				end, "CompleteEveningItem is a Module handle method: call M:CompleteEveningItem(id)")
			end
		)

		it("plays listDone at the last tick and folds 2.5 s later, paying nothing (ONB-R62, ONB-R64)", function()
			local fake = newFakePagle()
			local ledger, hunts = withList(fake)
			fake.enterWorld()
			offToTheWater(fake)
			ledger:CompleteEveningItem("journal")
			hunts:CompleteEveningItem("hunts")
			fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
			fake.Pagle.OpenShop()
			fake.wait(300)

			assert.are.equal("listDone", fake.eveningSounds[#fake.eveningSounds])
			assert.is_false(fake.global.onboarding.evening.closed)
			fake.wait(2.5)

			assert.is_nil(fake.eveningList)
			assert.is_true(fake.global.onboarding.evening.closed)
			assert.are.same({ "Hunts.hunts" }, stacked(fake))
			assert.are.same({}, fake.coinReports)
			assert.are.same({}, fake.announcements)
		end)

		it("never docks for a returning Angler (ONB-R60, ONB-R2)", function()
			local fake = newFakePagle()
			withList(fake)
			fake.global.onboarding.letter = "returning"

			offToTheWater(fake)

			assert.is_nil(fake.eveningList)
		end)

		it("shows again at the next login while unfinished (ONB-R60)", function()
			local fake = newFakePagle()
			local seeded = fake.ns.NewOnboardingState("opened")
			seeded.evening.shown, seeded.evening.done.cast = true, true
			fake.global.onboarding = seeded

			fake.login()

			assert.are.same({ 1, 4 }, { fake.eveningList.done, fake.eveningList.total })
		end)

		it("docks with /pagle dev onboarding evening (ONB-R83)", function()
			local fake = newFakePagle()
			withList(fake)

			fake.slash("dev on")
			fake.slash("dev onboarding evening")

			assert.are.same({ "Core.evening", "Hunts.hunts" }, stacked(fake))
		end)
	end)
end)
