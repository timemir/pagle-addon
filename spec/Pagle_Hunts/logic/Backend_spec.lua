-- Hunts' projection for Pagle's backend (#223): ns.BindProjections and ns.CoinsEarned (logic/Projection.lua), on
-- FakePagle over the fixture Hunt list and catalogue. The backend's driver folds the Catch log through logic/ alone
-- (spec/logic_alone_spec.lua), so the binding must fold the Hunts as the client's projection does.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local NIGHT, DAY, DUSK, JUNE_1 = hunts.NIGHT, hunts.DAY, hunts.DUSK, hunts.JUN_1
local cast, append, login = hunts.cast, hunts.append, hunts.login

local AUBERDINE = { zone = C.DARKSHORE, subzone = C.AUBERDINE }
local DARKSHORE = { zone = C.DARKSHORE }
local WESTFALL = { zone = C.WESTFALL }

-- Three Hunts completed (a night Nightfin, a Deviate Fish at dusk, uncommon items under the Rack's aura), the Rack's
-- second tier reached with five of them, and the fixture_dusk set's title.
---@param fake table
local function history(fake)
	append(fake, {
		cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }),
		cast(0, NIGHT + 30, AUBERDINE),
		cast(1, DAY, DARKSHORE, { C.NIGHTFIN }),
		cast(1, NIGHT + 60, WESTFALL),
		cast(2, DUSK, DARKSHORE, { C.DEVIATE }),
		cast(2, DUSK + 30, DARKSHORE, { C.UNCOMMON }, { C.RACK_AURA }),
		cast(3, DAY, WESTFALL, { C.UNCOMMON, C.UNCOMMON }, { C.RACK_AURA }),
		cast(3, DAY + 1, WESTFALL, { C.UNCOMMON, C.UNCOMMON }, { C.RACK_AURA }),
	})
end

-- Hunts logged in over `history`, its OnInitialize replaced by what the backend's driver does: register, then
-- ns.BindProjections. `prepare(loaded)` runs first, before Hunts' ADDON_LOADED.
---@param prepare fun(loaded: LoadedAddon)?
---@return PagleProjection bound
---@return PagleHuntsNS ns
local function boundByBackend(prepare)
	local bound
	local loaded = login(history, {
		prepare = function(loaded)
			if prepare then
				prepare(loaded)
			end
			local ns = loaded.ns
			ns.Hunts.OnInitialize = function()
				local fake = loaded.env.Pagle
				bound = ns.BindProjections(fake.RegisterModule(ns.ModuleDef(function() end)))
			end
		end,
	})
	return bound, loaded.ns
end

local FIXTURE_LIST = "spec/Pagle_Hunts/fixtures/HuntList.lua"
local FIXTURE_EVENTS = "spec/Pagle_Hunts/fixtures/EventList.lua"
local RUN_START = hunts.at(10, 0)
local RUN_KEY = "fixture_shore@" .. RUN_START

-- A pool event's run, fixture_shore over Darkshore, logged at its start and fished through to completion: a Deviate
-- Fish at dusk (its Timed oddity, and its Haul's first fish), then a Nightfin that night (its Named fish and its
-- Haul's tier 1, completing the run), and one more the next night.
---@param fake table
local function poolRun(fake)
	append(fake, {
		hunts.record("run", hunts.runPayload("fixture_shore", RUN_START, RUN_START + 3 * 86400), RUN_START),
		cast(10, DUSK, DARKSHORE, { C.DEVIATE }),
		cast(10, NIGHT, DARKSHORE, { C.NIGHTFIN }),
		cast(11, NIGHT, DARKSHORE, { C.NIGHTFIN }),
	})
end

-- Hunts as the backend's driver hosts it (LOG-R79), with no login and no OnInitialize: its logic/ files and its data
-- files in TOC order, the fixture Hunt list and event pool in place of data/HuntList.lua and data/EventList.lua (with
-- `noEvents`, data/EventList.lua left out, as the driver's load list had it), never adapter/ or locale/, over
-- `fake`'s Pagle API and the fold's GetServerTime. ns.BindProjections binds it over a handle that keeps the def and
-- reads the log back for M:IterateCatches as Core's does, Hunts' own Module records included (LOG-R41, LOG-R42);
-- then every record so read is folded from reset, and done runs as a first build.
---@param fake table a FakePagle with its catalogue and log set, never logged in
---@param noEvents boolean?
---@return HuntsState state
---@return PagleHuntsNS ns
local function foldByDriver(fake, noEvents)
	-- What a Module's files see of FakePagle (its Pagle API, and pairs, ipairs, next and unpack that read through the
	-- read-only proxies it hands out), and the fold's time.
	local env = setmetatable({
		GetServerTime = function()
			return SERVER_TIME
		end,
	}, { __index = _G })
	for name, value in pairs(fake.globals) do
		env[name] = value
	end
	local data = { ["data/HuntList.lua"] = FIXTURE_LIST, ["data/EventList.lua"] = not noEvents and FIXTURE_EVENTS }
	local ns = {}
	for _, file in ipairs(addonFiles("Pagle_Hunts")) do
		local path = file:find("^logic/") and "addons/Pagle_Hunts/" .. file or data[file]
		if path then
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile(path))
			setfenv(chunk, env)
			chunk("Pagle_Hunts", ns)
		end
	end
	local def
	ns.BindProjections({
		NewProjection = function(_, bound)
			def = bound
			return {}
		end,
		IterateCatches = function(_, afterSeq)
			return fake.catchLog:Iterate(afterSeq, "Hunts")
		end,
	})
	local state, casts = def.reset() or {}, 0
	for record in fake.catchLog:Iterate(0, "Hunts") do
		def.apply(state, record, "rebuild")
		casts = casts + (record.kind == "cast" and 1 or 0)
	end
	def.done(state, { firstBuild = casts > 0, rebuilt = true, replayed = 0 })
	return state, ns
end

-- A FakePagle over the fixture catalogue with `records(fake)` appended, never logged in: the log the driver folds and
-- the Pagle API it hosts.
---@param records fun(fake: table)
---@return table
local function driverFake(records)
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	records(fake)
	return fake
end

describe("Hunts' projection for the backend (#223)", function()
	it("folds the Hunts to the state the client's projection holds", function()
		local client = login(history)
		local bound = boundByBackend()

		assert.are.same(client.ns.State(), bound:GetState())
	end)

	it("gives the lifetime Coins earned: 30 per completion, 15 per further tier, 100 per title (HNT-R110)", function()
		local bound, ns = boundByBackend()

		assert.are.equal(3 * 30 + 15 + 100, ns.CoinsEarned(bound:GetState() --[[@as HuntsState]]))
	end)

	it("counts a title a retirement completed by the server time, as the client's done does (HNT-R23)", function()
		-- From 2026-06-01, fixture_dusk's only Hunt is fixture_snapper, which is done: its title a second time is no
		-- new title, so only fixture_hefty_blackmouth's retirement can change the set.
		local function retire(loaded)
			loaded.ns.huntList.hunts[4].retired = JUNE_1
		end
		local client = login(history, { prepare = retire })
		local bound = boundByBackend(retire)

		assert.are.same(client.ns.State(), bound:GetState())
		assert.is_true(bound:GetState().sets.fixture_dusk.fromRetirement)
	end)

	describe("Journal values at the server time, 11 October 2026 (ANG Journal values)", function()
		local journal
		setup(function()
			local bound, ns = boundByBackend()
			journal = ns.JournalValues(bound:GetState() --[[@as HuntsState]], 20)
		end)

		-- The `hunts` entry of `id`.
		local function hunt(id)
			for _, entry in ipairs(journal.hunts) do
				if entry.id == id then
					return entry
				end
			end
		end

		it("lists every Hunt that exists now, in list order: not the retired or unborn ones nothing reached", function()
			local ids = {}
			for i, entry in ipairs(journal.hunts) do
				ids[i] = entry.id
			end

			assert.are.same({
				"fixture_snapper",
				"fixture_oddity",
				"fixture_rack",
				"fixture_hefty_blackmouth",
				"fixture_eel",
				"fixture_bass",
				"fixture_squid",
				"fixture_tide_late",
			}, ids)
		end)

		it("gives a Species Hunt its set, state, tiers, trim and target (HNT-R2, HNT-R3, HNT-R18)", function()
			assert.are.same({
				id = "fixture_snapper",
				set = "fixture_dusk",
				current = true,
				retired = false,
				tiers = { 1, 10, 40 },
				trim = 1,
				target = { kind = "species", items = { C.NIGHTFIN } },
			}, hunt("fixture_snapper"))
		end)

		it("names a fixed class's members, ascending, and none for a generated class; silver for tier 2", function()
			assert.are.same({ kind = "fixed", items = { 6522, 251524 } }, hunt("fixture_oddity").target)
			assert.are.same({ kind = "quality.uncommon", items = {} }, hunt("fixture_rack").target)
			assert.are.equal(2, hunt("fixture_rack").trim)
		end)

		it("gives a Hunt's minBand and 0 for a Hunt with no tier reached", function()
			assert.are.same(
				{ kind = "species", items = { 6358 }, minBand = 3 },
				hunt("fixture_hefty_blackmouth").target
			)
			assert.are.equal(0, hunt("fixture_hefty_blackmouth").trim)
		end)

		it("counts each set's current Hunts and those done (HNT-R17, HNT-R20)", function()
			assert.are.same({
				{ id = "fixture_dusk", hunts = 2, done = 1 },
				{ id = "fixture_wagers", hunts = 2, done = 2 },
				{ id = "fixture_pair", hunts = 2, done = 0 },
				{ id = "fixture_tide", hunts = 2, done = 0 },
			}, journal.sets)
		end)
	end)

	describe("the event pool (LOG-R79, DATA-R98)", function()
		it("lists every pool event as plain data, in event-ID order, after BindProjections", function()
			local _, ns = boundByBackend()

			assert.are.same({
				{ id = "fixture_shore", tags = { "coast", "low" }, skill = { 75, 150 }, band = "low", rotation = true },
				{ id = "fixture_vale", tags = { "lake", "low" }, skill = { 25, 150 }, band = "low", rotation = true },
			}, ns.EventPool())
		end)

		it("includes a retired event with its retired time, and a pool event kept out of the rotation", function()
			local _, ns = boundByBackend(function(loaded)
				loaded.ns.eventList.events[1].retired = JUNE_1
				loaded.ns.eventList.events[2].rotation = false
			end)

			local pool = ns.EventPool()
			assert.are.equal(JUNE_1, pool[1].retired)
			assert.is_false(pool[2].rotation)
		end)

		it("hands out copies: changing one leaves the pool as it was", function()
			local _, ns = boundByBackend()

			local pool = ns.EventPool()
			pool[1].tags[1], pool[1].skill[1], pool[1].id = "changed", 1, "changed"

			assert.are.same({ "coast", "low" }, ns.events:Event("fixture_shore").tags)
			assert.are.same({ 75, 150 }, ns.events:Event("fixture_shore").skill)
			assert.are.equal("fixture_shore", ns.EventPool()[1].id)
		end)
	end)

	describe("a pool event's run, as the driver loads Hunts (LOG-R79)", function()
		it("is credited, the fold reaching the state the client's projection holds", function()
			local client = login(poolRun)
			local state, ns = foldByDriver(driverFake(poolRun))

			assert.are.same({ "fixture_shore", "fixture_vale" }, { ns.EventPool()[1].id, ns.EventPool()[2].id })
			assert.are.same(client.ns.State(), state)
			local run = state.runs[RUN_KEY]
			assert.is_truthy(run)
			assert.are.equal(2, run.hunts.fixture_shore_snapper.count)
			assert.are.equal(1, run.hunts.fixture_shore_oddity.count)
			assert.are.equal(3, run.hunts.fixture_shore_haul.count)
			assert.are.equal(hunts.at(10, NIGHT), run.completedAt)
		end)

		it(
			"is ignored without data/EventList.lua, the load list LOG-R79 had before: no pool, so no known event",
			function()
				local state = foldByDriver(driverFake(poolRun), true)

				assert.is_nil(state.runs[RUN_KEY])
			end
		)
	end)
end)
