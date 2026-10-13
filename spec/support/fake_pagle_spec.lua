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
end)
