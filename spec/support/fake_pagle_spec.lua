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

		it("raises an error at the caller for a row Core refuses (CORE-R42)", function()
			local _, M = withQoL()
			M:AddSetting("fishing", { kind = "header", id = "casting", label = "Casting" })

			for _, call in ipairs({
				{ "look", { kind = "header", label = "Casting" } },
				{ "fishing", { kind = "toggle", label = "Casting" } },
				{ "fishing", { kind = "header", id = "casting", label = "Again" } },
				{ "fishing", { kind = "header", parent = "gear", label = "Swap" } },
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
			"lists each Module's views then menu entries by def.order, then Settings, reading labels each time (CORE-R50, CORE-R52)",
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

				assert.are.same({ "Hunts", "Input: Both", "Settings" }, labels)
				assert.are.equal(2, reads)
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
					"/pagle help: list these commands",
					"/pagle qol: cycle Input",
				}, fake.printed)
			end
		)

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
			assert.are.equal("/pagle qol: cycle Input", fake.printed[4])
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

	describe("the catalogue", function()
		-- A catalogue in the M1 shape (DATA-R79): Darkshore (148) with The Long Wash (453).
		local function fixture()
			local function area(parent)
				return { parent = parent, continent = 1, hasData = false, skillBaseConfirmed = false, catches = {} }
			end
			return {
				fingerprint = "0123456789abcdef",
				items = {},
				areas = { [148] = area(0), [453] = area(148) },
				aliases = {},
				pools = {},
				windows = {},
				events = {},
				fishingSpells = {},
				auras = {},
			}
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
end)
