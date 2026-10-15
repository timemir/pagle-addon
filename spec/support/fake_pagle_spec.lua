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

		it("stacks shown trackers by order, 8 px apart, ties by Module name, reflowing as read (CORE-R70)", function()
			local fake = newFakePagle()
			dock(fake, "Stats", 20, 60)
			local hunts = dock(fake, "Hunts", 10, 40)
			dock(fake, "TackleBoard", 20, 30, "board")
			fake.login()

			assert.are.same({ { "hunts", 0 }, { "stats", -48 }, { "board", -116 } }, stack(fake))
			local top = fake.dock.stack()[1]
			assert.are.same(
				{ "Hunts", hunts, "TOPRIGHT", "dock", "TOPRIGHT", 0 },
				{ top.module, top.frame, top.point, top.relativeTo, top.relativePoint, top.x }
			)

			hunts:Hide()
			assert.are.same({ { "stats", 0 }, { "board", -68 } }, stack(fake))
			hunts:Show()
			hunts:SetHeight(10)
			assert.are.same({ { "hunts", 0 }, { "stats", -18 }, { "board", -86 } }, stack(fake))
		end)

		it("is empty with no tracker shown (CORE-R72)", function()
			local fake = newFakePagle()
			dock(fake, "Hunts", 10, 40):Hide()

			assert.are.same({}, fake.dock.stack())
		end)

		it("raises an error at the caller for each RegisterTracker mistake, docking nothing (CORE-R70)", function()
			local fake = newFakePagle()
			local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			hunts:RegisterTracker({ id = "hunts", order = 10, frame = newWidget("Frame") })

			for _, tracker in ipairs({
				{ order = 10, frame = newWidget("Frame") },
				{ id = 4, order = 10, frame = newWidget("Frame") },
				{ id = "pins", order = "10", frame = newWidget("Frame") },
				{ id = "pins", order = 10 },
				{ id = "hunts", order = 10, frame = newWidget("Frame") },
			}) do
				local ok, err = pcall(function()
					hunts:RegisterTracker(tracker)
				end)
				assert.is_false(ok)
				assert.matches("fake_pagle_spec%.lua:%d+: M:RegisterTracker: ", tostring(err))
			end
			assert.are.same({ { "hunts", 0 } }, stack(fake))
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
				assert.is_true(fake.goods["hunts.cover.gold"].earned)
			end
		)

		it("caches each good in fake.goods, which is fake.global.goods (SHOP-R26)", function()
			local fake = newFakePagle()
			huntsCovers(fake, { value = false })

			assert.are.equal(fake.global.goods, fake.goods)
			assert.are.same({
				name = "Velvet",
				slot = "hunts.cover",
				slotLabel = "Notebook cover",
				category = "Hunts",
				module = "Hunts",
				icon = 134939,
				tier = 2,
			}, fake.goods["hunts.cover.velvet"])
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
				fake.goods["hunts.cover.plain"] =
					{ name = "Plain", slot = "hunts.cover", module = "Hunts", default = true }
				fake.goods["hunts.cover.velvet"] = { name = "Velvet", slot = "hunts.cover", module = "Hunts", tier = 2 }
				fake.profile.appearance["hunts.cover"] = "hunts.cover.velvet"
				fake.setPurchased({ ["hunts.cover.velvet"] = true })
				fake.login()

				assert.are.same(
					{ "hunts.cover.plain", true },
					{ fake.Pagle.GetEquipped("hunts.cover"), fake.Pagle.IsOwned("hunts.cover.velvet") }
				)
			end
		)

		it("reads a good's cached look with Pagle.GetGood, read-only (graph.md question 2, CORE-R18)", function()
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

			assert.are.same({ "core.toaststyle.timber", "core.soundset.driftwood", "core.crest.plain" }, {
				Pagle.GetEquipped("core.toaststyle"),
				Pagle.GetEquipped("core.soundset"),
				Pagle.GetEquipped("core.crest"),
			})
			-- Named from Core's committed lore, as Core names it (DATA-R104, SHOP-R25).
			assert.are.same({ "Water Spirit", "Interface\\Icons\\Spell_Frost_SummonWaterElemental", "Core" }, {
				Pagle.GetGood("core.crest.crest3").name,
				Pagle.GetGood("core.crest.crest3").icon,
				fake.goods["core.crest.crest3"].module,
			})
			assert.is_nil(fake.ns.goods:Good("core.crest.plain").preview)
			fake.setPurchased({ ["core.crest.crest3"] = true })
			assert.is_true(Pagle.SetEquipped("core.crest", "core.crest.crest3"))
		end)

		it("selects an owned good of a Module off under Put away, from the cache (SHOP-R40, SHOP-R35)", function()
			local fake = newFakePagle()
			fake.goods["hunts.cover.velvet"] = {
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

		it("toggles the shop with /pagle shop (CORE-R61, SHOP-R40)", function()
			local fake = newFakePagle()
			fake.login()

			fake.slash("shop")
			assert.is_true(fake.shopOpen)
			fake.slash(" SHOP ")
			assert.is_false(fake.shopOpen)
			assert.are.same({ {} }, fake.shopsOpened)
		end)

		it("prints SHOP-R41's line while restricted, and closes the shop when restriction starts (SHOP-R41)", function()
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
		end)
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
			assert.are.equal("/pagle qol: cycle Input", fake.printed[6])
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

				assert.are.same({ "P1|1|1791731700|0|1", "P1|1|1791731700|1|2" }, fake.catchLog.data.entries)
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
			fake.catchLog:Append({ kind = "prestige", char = 1, time = 1791731000, rank = 1 })
			fake.catchLog:Append({
				kind = "purchase",
				char = 1,
				time = 1791731001,
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

			assert.are.same({ "U1|1|1791731700|0|core.toaststyle.ripple|150" }, fake.catchLog.data.entries)
			assert.are.same({ "1 purchase live" }, seen)
			assert.is_nil(fake.Pagle.RecordPurchase)
		end)
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
					time = 1791731000 + i,
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
end)
