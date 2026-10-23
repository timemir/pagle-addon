-- The Standing Hunts' Cast index (HNT-R139, #365): ns.NewCastIndex, ns.CastHunts and ns.HuntsToTest
-- (logic/Projection.lua). The index is no rule: over a long generated log, across zones, subzones, items, Species,
-- sizes, auras, lures and runs, the fold with it holds exactly what the fold testing every Hunt holds, on the fixture
-- Hunt list and on one with a Hunt of each kind the index files differently, while it calls Pagle.MatchesConditions
-- far less. Folded as the backend's driver folds Hunts (logic/ alone, spec/Pagle_Hunts/logic/Backend_spec.lua).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

local FIXTURE_LIST = "spec/Pagle_Hunts/fixtures/HuntList.lua"
local FIXTURE_EVENTS = "spec/Pagle_Hunts/fixtures/EventList.lua"
local SHIPPED_LIST = "addons/Pagle_Hunts/data/HuntList.lua"
local SHIPPED_EVENTS = "addons/Pagle_Hunts/data/EventList.lua"

-- Hunts of every shape the index files differently that the fixture list lacks (HNT-R139), after it as set
-- fixture_extra: `areas` with a repeat (filed by them), a class with `areas`, a Species no catch entry has under a lure
-- condition and a class no list defines (both tested on every Cast), a natural Hunt whose window gates none of its
-- Species' entries (no waters: Catches only), and an imposed Species Hunt with waters under an aura.
local EXTRA = {
	{
		id = "extra_areas",
		set = "fixture_extra",
		kind = "imposed",
		since = hunts.JAN_1,
		species = C.SMALLFISH,
		conditions = { areas = { C.WESTFALL, C.PIER, C.WESTFALL } },
		tiers = { 1, 10, 40 },
	},
	{
		id = "extra_areas_class",
		set = "fixture_extra",
		kind = "imposed",
		since = hunts.JAN_1,
		class = "fixed.oddity",
		conditions = { areas = { C.ELWYNN, C.DARKSHORE }, time = { { 360, 1200 } } },
		tiers = { 1, 5 },
	},
	{
		id = "extra_lure",
		set = "fixture_extra",
		kind = "imposed",
		since = hunts.JAN_1,
		species = 13755,
		conditions = { lure = true },
		tiers = { 1 },
	},
	{
		id = "extra_no_class",
		set = "fixture_extra",
		kind = "imposed",
		since = hunts.JAN_1,
		class = "fixed.nothing",
		conditions = { time = { { 0, 720 } } },
		tiers = { 1 },
	},
	{
		id = "extra_night_smallfish",
		set = "fixture_extra",
		kind = "natural",
		since = hunts.JAN_1,
		species = C.SMALLFISH,
		window = "night",
		tiers = { 1, 10 },
	},
	{
		id = "extra_aura_nightfin",
		set = "fixture_extra",
		kind = "imposed",
		since = hunts.JAN_1,
		retired = hunts.JUN_1 + 30 * 86400,
		species = C.NIGHTFIN,
		conditions = { auras = { C.RACK_AURA } },
		tiers = { 1, 3, 9 },
	},
}

-- The fixture Hunt list with the EXTRA Hunts after it.
---@param fixture HuntListData
---@return HuntListData
local function extended(fixture)
	return hunts.withExtra(fixture, { { id = "fixture_extra" } }, EXTRA)
end

-- Where a generated Cast is fished: every area of the fixture catalogue, nested subzones, a zone with no data, and an
-- unresolved one (zone 0).
local PLACES = {
	{ zone = C.DARKSHORE, subzone = 0 },
	{ zone = C.DARKSHORE, subzone = C.AUBERDINE },
	{ zone = C.DARKSHORE, subzone = C.PIER },
	{ zone = C.ASHENVALE, subzone = 0 },
	{ zone = C.ELWYNN, subzone = 0 },
	{ zone = C.WESTFALL, subzone = 0 },
	{ zone = C.STORMWIND, subzone = 0 },
	{ zone = 0, subzone = 0 },
}

-- What a generated Cast may catch: every item of the fixture catalogue, a Forever item folded into its Species, items
-- of no Species, and an Uncharted one.
local ITEMS = {
	C.NIGHTFIN,
	C.NIGHTFIN_FOREVER,
	C.BLACKMOUTH,
	C.SUNSCALE,
	C.GROUPER,
	C.SMALLFISH,
	C.DEVIATE,
	C.ODDITY_2,
	C.UNCOMMON,
	C.UNCOMMON_2,
	99999,
}

-- A run of each pool event, as Hunts logs them (HNT-R150), so the event Hunts fold beside the Standing ones.
local RUNS = {
	{ event = "fixture_shore", day = 10 },
	{ event = "fixture_vale", day = 40 },
	{ event = "fixture_shore", day = 120 },
}

-- `n` Casts from 2026-01-01 to early October 2026 (the fold's server time is 11 October), each drawn from a fixed
-- linear congruential sequence, so every run of the spec folds the same log: a quarter got away, the rest catch one to
-- three items; a third under the Rack's aura, some with a lure or the Extravaganza on; at any realm minute. The pool
-- runs are logged among them at their start.
---@param fake table
---@param n integer
local function generatedLog(fake, n)
	local seed = 365
	local function draw(m)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return math.floor(seed / 65536) % m + 1
	end
	local records, runAt = {}, 1
	for i = 1, n do
		local day = -59 + math.floor((i - 1) * 279 / n)
		local run = RUNS[runAt]
		if run and day >= run.day then
			local start = hunts.at(run.day, 0)
			records[#records + 1] = hunts.record("run", hunts.runPayload(run.event, start, start + 3 * 86400), start)
			runAt = runAt + 1
		end
		local minute = draw(1440) - 1
		local place = PLACES[draw(#PLACES)]
		local items = {}
		if draw(4) > 1 then
			for slot = 1, draw(3) do
				items[slot] = { itemID = ITEMS[draw(#ITEMS)], quantity = 1 }
			end
		end
		records[#records + 1] = {
			kind = "cast",
			char = 1,
			time = hunts.at(day, minute) + i % 60,
			outcome = #items > 0 and "caught" or "gotAway",
			conditions = {
				minute = minute,
				zone = place.zone,
				subzone = place.subzone,
				skillRank = 150,
				skillMod = 0,
				lure = draw(5) == 1 and 263 or nil,
				events = draw(10) == 1 and { 301 } or {},
				auras = draw(3) == 1 and { C.RACK_AURA } or {},
			},
			items = items,
		}
	end
	hunts.append(fake, records)
end

-- `n` Casts over the shipped catalogue, from 2026-01-01 to early October 2026 and drawn as generatedLog draws them:
-- each fished where one of the catalogue's catch entries is listed (its area, as the subzone of its zone), a quarter
-- got away, the rest catching one or two items listed there and now and then one listed anywhere; a sixth under the
-- Rack's aura and a sixth under the Hut's, some with a lure or the Extravaganza on; at any realm minute.
---@param fake table
---@param n integer
local function shippedLog(fake, n)
	local pagle, each = fake.globals.Pagle, fake.globals.ipairs
	local entries = {}
	for _, zone in each(pagle.GetZones()) do
		for _, entry in each(pagle.GetZoneCatches(zone) or {}) do
			entries[#entries + 1] = { areaID = entry.areaID, itemID = entry.itemID }
		end
	end
	local listed = {}
	for _, entry in ipairs(entries) do
		listed[entry.areaID] = listed[entry.areaID] or {}
		table.insert(listed[entry.areaID], entry.itemID)
	end
	local seed = 365
	local function draw(m)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return math.floor(seed / 65536) % m + 1
	end
	local records = {}
	for i = 1, n do
		local day = -59 + math.floor((i - 1) * 279 / n)
		local minute = draw(1440) - 1
		local at = entries[draw(#entries)]
		local zone = pagle.GetZoneOf(at.areaID) or at.areaID
		local here = listed[at.areaID]
		local items = {}
		if draw(4) > 1 then
			for slot = 1, draw(2) do
				local itemID = draw(5) == 1 and entries[draw(#entries)].itemID or here[draw(#here)]
				items[slot] = { itemID = itemID, quantity = 1 }
			end
		end
		local aura = draw(6)
		records[#records + 1] = {
			kind = "cast",
			char = 1,
			time = hunts.at(day, minute) + i % 60,
			outcome = #items > 0 and "caught" or "gotAway",
			conditions = {
				minute = minute,
				zone = zone,
				subzone = zone == at.areaID and 0 or at.areaID,
				skillRank = 225,
				skillMod = 0,
				lure = draw(5) == 1 and 263 or nil,
				events = draw(10) == 1 and { 301 } or {},
				auras = aura == 1 and { 1280341 } or aura == 2 and { 1280342 } or {},
			},
			items = items,
		}
	end
	hunts.append(fake, records)
end

-- A FakePagle over the fixture catalogue with the generated log of `n` Casts, never logged in.
---@param n integer
---@return table
local function logOf(n)
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	generatedLog(fake, n)
	return fake
end

--- What foldByDriver found.
---@class CastIndexFold
---@field state HuntsState
---@field calls integer   -- Pagle.MatchesConditions calls the fold made, from its first record to its done
---@field ns PagleHuntsNS

-- Hunts as the backend's driver hosts it (LOG-R79): its logic/ files and the fixture data files (with `shipped`, its
-- own data/HuntList.lua and data/EventList.lua) in TOC order over `fake`'s Pagle API, the Hunt list `list(loaded, ns)`
-- if given, bound with ns.BindProjections, then every record of the log folded from reset and done run as a first
-- build. `unindexed` tests every Standing Hunt on every Cast, as before the index (HNT-R139).
---@param fake table
---@param options { list: (fun(loaded: HuntListData, ns: PagleHuntsNS): HuntListData)?, unindexed: boolean?, shipped: boolean? }?
---@return CastIndexFold
local function foldByDriver(fake, options)
	options = options or {}
	local env = setmetatable({
		GetServerTime = function()
			return SERVER_TIME
		end,
	}, { __index = _G })
	for name, value in pairs(fake.globals) do
		env[name] = value
	end
	local data = { ["data/HuntList.lua"] = FIXTURE_LIST, ["data/EventList.lua"] = FIXTURE_EVENTS }
	if options.shipped then
		data = { ["data/HuntList.lua"] = SHIPPED_LIST, ["data/EventList.lua"] = SHIPPED_EVENTS }
	end
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
	if options.list then
		ns.huntList = options.list(ns.huntList, ns)
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
	if options.unindexed then
		ns.HuntsToTest = function()
			return ns.hunts:Hunts()
		end
	end
	-- Every call the fold makes reads the lookups ns.BindProjections handed its def, at call time.
	local calls, matches = 0, ns.lookups.MatchesConditions
	ns.lookups.MatchesConditions = function(spec, snapshot)
		calls = calls + 1
		return matches(spec, snapshot)
	end
	local state, casts = def.reset(), 0
	for record in fake.catchLog:Iterate(0, "Hunts") do
		def.apply(state, record, "rebuild")
		casts = casts + (record.kind == "cast" and 1 or 0)
	end
	def.done(state, { firstBuild = casts > 0, rebuilt = true, replayed = 0 })
	return { state = state, calls = calls, ns = ns }
end

describe("the Standing Hunts' Cast index (HNT-R139)", function()
	local fake, log
	setup(function()
		fake = logOf(3000)
		log = {}
		for record in fake.catchLog:Iterate(0, "Hunts") do
			if record.kind == "cast" then
				log[#log + 1] = record
			end
		end
	end)

	it("leaves every Hunt a Cast can change among those it tests, Cast by Cast", function()
		local ns = foldByDriver(fake, { list = extended }).ns
		local lookups, index = ns.lookups, ns.NewCastIndex(ns.hunts, ns.where, ns.lookups)
		local skipped, changing, missed = 0, 0, {}
		for _, cast in ipairs(log) do
			local tested = {}
			for _, hunt in ipairs(ns.CastHunts(index, cast, lookups)) do
				tested[hunt.id] = true
			end
			for _, hunt in ipairs(ns.hunts:Hunts()) do
				local spec = ns.where[hunt.id].boardSpec
				local effort = spec ~= nil
					and lookups.MatchesConditions(spec, cast.conditions)
					and ns.InWaters(hunt, cast)
				local catches = #ns.MatchingCatches(hunt, cast, lookups)
				if effort or catches > 0 then
					changing = changing + 1
					if not tested[hunt.id] then
						missed[#missed + 1] = hunt.id .. " at seq " .. cast.seq
					end
				elseif not tested[hunt.id] then
					skipped = skipped + 1
				end
			end
		end
		assert.are.same({}, missed)
		-- The log exercises both: many Hunts a Cast changes, and many more it skips.
		assert.is_true(changing > 1000)
		assert.is_true(skipped > 10 * 1000)
	end)

	it("hands back the tested Hunts in Hunt-list order, each once", function()
		local ns = foldByDriver(fake, { list = extended }).ns
		local position = {}
		for i, hunt in ipairs(ns.hunts:Hunts()) do
			position[hunt.id] = i
		end
		-- A Nightfin, a Forever Nightfin and a Deviate Fish in Auberdine Pier under the Rack's aura.
		local cast = {
			outcome = "caught",
			conditions = { zone = C.DARKSHORE, subzone = C.PIER, auras = { C.RACK_AURA }, events = {} },
			items = { { itemID = C.DEVIATE }, { itemID = C.NIGHTFIN_FOREVER }, { itemID = C.NIGHTFIN } },
		}
		local positions = {}
		for i, hunt in ipairs(ns.HuntsToTest(cast, ns.lookups)) do
			positions[i] = position[hunt.id]
		end
		local ascending = { unpack(positions) }
		table.sort(ascending)
		assert.are.same(ascending, positions)
		for i = 2, #positions do
			assert.are_not.equal(positions[i - 1], positions[i])
		end
		-- By Darkshore and the Pier's waters and areas, the Rack's aura, the Deviate Fish's class and the Nightfin's
		-- Species, and the two always tested.
		assert.are.same({
			"fixture_snapper",
			"fixture_oddity",
			"fixture_rack",
			"fixture_hefty_blackmouth",
			"fixture_grouper",
			"fixture_tide_late",
			"extra_areas",
			"extra_areas_class",
			"extra_lure",
			"extra_no_class",
			"extra_aura_nightfin",
		}, hunts.ids(ns.HuntsToTest(cast, ns.lookups)))
	end)

	it("files Hunts by auras, waters, areas, Species and class members, and the rest as always tested", function()
		local ns = foldByDriver(fake, { list = extended }).ns
		local index = ns.NewCastIndex(ns.hunts, ns.where, ns.lookups)
		local function ids(bucket)
			local out = {}
			for _, i in ipairs(bucket or {}) do
				out[#out + 1] = index.hunts[i].id
			end
			return out
		end

		-- An imposed Hunt under an aura changes only a Cast under it, its effort and its Catches alike, whatever its
		-- target or waters.
		assert.are.same({ "fixture_rack", "extra_aura_nightfin" }, ids(index.byAura[C.RACK_AURA]))
		-- With no waters (a Species no catch entry lists, an unknown class), effort bound to no area is tested always.
		assert.are.same({ "extra_lure", "extra_no_class" }, ids(index.always))
		-- Westfall: fixture_hefty_blackmouth's waters (its Blackmouth) and extra_areas's areas, once though listed twice.
		assert.are.same({ "fixture_hefty_blackmouth", "extra_areas" }, ids(index.byArea[C.WESTFALL]))
		-- Elwynn: the night-gated Nightfin is ungated here, so no natural night Hunt's waters; its day Sunscale's are.
		assert.are.same(
			{ "fixture_sunscale", "fixture_tide_retired", "extra_areas_class" },
			ids(index.byArea[C.ELWYNN])
		)
		-- A class target by its members, a Species target by its Species; a Hunt with `areas` by those alone.
		assert.are.same({ "fixture_oddity" }, ids(index.byItem[C.ODDITY_2]))
		assert.are.same({ "fixture_snapper", "fixture_tide_late" }, ids(index.bySpecies[C.NIGHTFIN]))
		assert.are.same({ "extra_night_smallfish" }, ids(index.bySpecies[C.SMALLFISH]))
	end)

	for _, case in ipairs({
		{ name = "the fixture Hunt list" },
		{ name = "a Hunt list with a Hunt of every shape the index files", list = extended },
	}) do
		it("folds to exactly the state testing every Hunt folds to, over " .. case.name, function()
			local indexed = foldByDriver(fake, { list = case.list })
			local unindexed = foldByDriver(fake, { list = case.list, unindexed = true })

			assert.are.same(unindexed.state, indexed.state)
			-- A fold with something in it: every Cast counted, Hunts with effort, tiers and titles, and runs settled.
			assert.are.equal(#log, indexed.state.casts)
			assert.is_true(indexed.state.coins > 0)
			assert.is_true(next(indexed.state.sets) ~= nil)
			assert.is_true(next(indexed.state.runs) ~= nil)
		end)
	end

	it("gives every Hunt of every shape effort or Catches over the generated log", function()
		local fold = foldByDriver(fake, { list = extended })
		local state = fold.state
		-- The Hunts with no effort or no Catch here. fixture_grouper is out only from 4 November; the natural Hunts on
		-- windows the catalogue lacks have no effort, nor their Species an item; minBand needs sizes the fixture
		-- catalogue doesn't give; a natural Hunt with no waters has no effort; and extra_lure and extra_no_class target
		-- no item the log catches.
		local noEffort, noCatch = {}, {}
		for _, hunt in ipairs(fold.ns.hunts:Hunts()) do
			local progress = state.hunts[hunt.id]
			if not (progress and progress.effort > 0) then
				noEffort[#noEffort + 1] = hunt.id
			end
			if not (progress and progress.count > 0) then
				noCatch[#noCatch + 1] = hunt.id
			end
		end
		assert.are.same({
			"fixture_grouper",
			"fixture_eel",
			"fixture_bass",
			"fixture_squid",
			"extra_night_smallfish",
		}, noEffort)
		assert.are.same({
			"fixture_hefty_blackmouth",
			"fixture_grouper",
			"fixture_eel",
			"fixture_bass",
			"fixture_squid",
			"extra_lure",
			"extra_no_class",
		}, noCatch)
	end)

	it("calls Pagle.MatchesConditions less than testing every Hunt, for the same state", function()
		local indexed = foldByDriver(fake, { list = extended })
		local unindexed = foldByDriver(fake, { list = extended, unindexed = true })

		assert.are.same(unindexed.state, indexed.state)
		-- Every Standing Hunt with a board spec, on every Cast, and an imposed Hunt's conditions again on a caught one,
		-- against only the Hunts filed for the Cast. The fixture catalogue's few areas hold most Hunts' waters, and
		-- the event Hunts' calls are the same in both, so the shipped list below shows the saving better.
		assert.is_true(unindexed.calls > 3000 * 15)
		assert.is_true(indexed.calls * 3 < unindexed.calls * 2)
	end)

	it("builds the index again when the Hunt list is replaced, as the tour's sample replaces it", function()
		local ns = foldByDriver(fake).ns
		local cast = {
			outcome = "caught",
			conditions = { zone = C.DARKSHORE, subzone = C.AUBERDINE, auras = {}, events = {} },
			items = { { itemID = C.NIGHTFIN } },
		}
		local before = ns.HuntsToTest(cast, ns.lookups)
		assert.are.equal("fixture_snapper", before[1].id)

		local fixture = ns.huntList --[[@as HuntListData]]
		ns.hunts = ns.NewHuntList({
			fingerprint = "sample",
			sets = fixture.sets,
			hunts = { fixture.hunts[2], fixture.hunts[3] },
			classes = fixture.classes,
		}, {})
		-- fixture_oddity bites in Darkshore (its Deviate Fish); the Rack's Hunt only under its aura.
		assert.are.same({ "fixture_oddity" }, hunts.ids(ns.HuntsToTest(cast, ns.lookups)))
		cast.conditions.auras = { C.RACK_AURA }
		assert.are.same({ "fixture_oddity", "fixture_rack" }, hunts.ids(ns.HuntsToTest(cast, ns.lookups)))
	end)
end)

describe("the Cast index over the shipped Hunt list and catalogue (HNT-R139)", function()
	-- The shipped list with every Hunt out from 2026-01-01, as a test log's release date has it (HNT-R136), so the
	-- generated Casts fall in their lifetimes.
	local function outEarly(loaded, ns)
		return ns.HuntListFrom(loaded, hunts.JAN_1)
	end

	local indexed, unindexed
	setup(function()
		local fake = newFakePagle()
		shippedLog(fake, 3000)
		indexed = foldByDriver(fake, { shipped = true, list = outEarly })
		unindexed = foldByDriver(fake, { shipped = true, list = outEarly, unindexed = true })
	end)

	it("folds to exactly the state testing every Hunt folds to", function()
		assert.are.same(unindexed.state, indexed.state)
		assert.are.equal(3000, indexed.state.casts)
		assert.is_true(next(indexed.state.hunts) ~= nil)
	end)

	it("calls Pagle.MatchesConditions for a small part of the Hunts", function()
		-- No run is logged, so every call is a Standing Hunt's: before the index, each with a board spec on every Cast.
		assert.is_true(unindexed.calls >= 3000 * 10)
		assert.is_true(indexed.calls * 4 < unindexed.calls)
	end)
end)
