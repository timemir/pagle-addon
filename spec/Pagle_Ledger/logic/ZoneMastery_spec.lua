-- Zone Mastery (LED-R50–R54, LED-R134): ranks earned in the fold, with their XP, Coins and `zoneRank` achievements,
-- and the shown rank, new to find, zone completion and the next requirement, over a fixture catalogue and hand-made
-- records. ledger.md › Zone Mastery, The Ledger's world, XP and Fresh Water, Pagle Coins, Home, Data, Tunables.

-- Lake: three ungated Species (ANY_2 also reached through a second item, ANY_2B), two gated ones (night and an
-- event), a junk item, a treasure (a container) and two trophy families.
local ANY_1, ANY_2, ANY_2B, ANY_3 = 6303, 6291, 6292, 6289
local NIGHT, EVENT = 13759, 13760
local JUNK, CHEST, TREASURE, OTHER = 6309, 6307, 6308, 4592
local TROPHY_1, TROPHY_1B, TROPHY_2 = 13901, 13902, 13910
-- Cove lists one gated Species and one family and no ungated Species. Far lists STRAY. A Legend is on no list.
local GATED, STRAY = 13761, 6290

local LAKE, COVE, FAR, MARSH, BLANK = 12, 40, 44, 10, 14

local ITEMS = {
	[ANY_1] = fishRecord(ANY_1),
	[ANY_2] = fishRecord(ANY_2),
	[ANY_2B] = fishRecord(ANY_2),
	[ANY_3] = fishRecord(ANY_3),
	[NIGHT] = fishRecord(NIGHT),
	[EVENT] = fishRecord(EVENT),
	[GATED] = fishRecord(GATED),
	[STRAY] = fishRecord(STRAY),
	[JUNK] = itemRecord("junk"),
	[CHEST] = itemRecord("container"),
	[TREASURE] = itemRecord("treasure"),
	[OTHER] = itemRecord("other"),
	[TROPHY_1] = itemRecord("trophy", { family = 1, weight = 19 }),
	[TROPHY_1B] = itemRecord("trophy", { family = 1, weight = 22 }),
	[TROPHY_2] = itemRecord("trophy", { family = 2, weight = 8 }),
}

local NIGHT_SPEC = NIGHT_WINDOW
local EVENT_SPEC = { events = { 301 } }

-- The fixture's zones, each a zone with no subzones: `hasData` and its catches (LOG-R55). Marsh has a list but no
-- data, so it isn't charted (LED-R10); Blank has data but nothing the Ledger lists.
local function areas()
	return {
		[LAKE] = {
			hasData = true,
			skillBase = 25,
			catches = {
				catchEntry(ANY_1),
				catchEntry(ANY_2),
				catchEntry(ANY_2B),
				catchEntry(ANY_3),
				catchEntry(NIGHT, "night", NIGHT_SPEC),
				catchEntry(EVENT, "event.301", EVENT_SPEC),
				catchEntry(JUNK),
				catchEntry(CHEST),
				catchEntry(TROPHY_1),
				catchEntry(TROPHY_2),
			},
		},
		[COVE] = { hasData = true, catches = { catchEntry(GATED, "night", NIGHT_SPEC), catchEntry(TROPHY_1B) } },
		[FAR] = { hasData = true, catches = { catchEntry(STRAY) } },
		[MARSH] = { hasData = false, catches = { catchEntry(ANY_1) } },
		[BLANK] = { hasData = true, catches = { catchEntry(OTHER) } },
	}
end

local getItem = itemLookup(ITEMS)

-- Core's lookups over `areaTable` (LOG-R55): zones ascending, each catch with its areaID.
local function lookups(areaTable)
	local zones = {}
	for zone in pairs(areaTable) do
		zones[#zones + 1] = zone
	end
	table.sort(zones)
	return {
		GetItem = getItem,
		GetZones = function()
			return zones
		end,
		GetArea = function(zone)
			return areaTable[zone]
		end,
		GetZoneCatches = function(zone)
			local list = {}
			for i, catch in ipairs(areaTable[zone].catches) do
				list[i] = { areaID = zone }
				for key, value in pairs(catch) do
					list[i][key] = value
				end
			end
			return list
		end,
	}
end

local T0 = SERVER_TIME - 700

-- Records the way the Catch log hands them out (LOG-R42): one caught Cast per call, a minute apart.
local function newLog()
	local seq = 0
	---@param zone integer
	---@param itemIDs integer[]
	---@return PagleCast
	return function(zone, itemIDs)
		seq = seq + 1
		return castRecord({ seq = seq, time = T0 + 60 * seq, zone = zone, minute = 0, items = itemIDs })
	end
end

describe("Zone Mastery", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns

	-- The fold's lookups (LED-R3) over the fixture, Core's MatchesConditions and `fixtureWorld`.
	local function foldLookups(fixtureWorld)
		return { GetItem = getItem, MatchesConditions = loaded.env.Pagle.MatchesConditions, world = fixtureWorld }
	end

	local world, fold, cast
	before_each(function()
		world = ns.NewWorld(lookups(areas()))
		fold = ns.NewLedgerFold(foldLookups(world))
		cast = newLog()
	end)

	-- Applies each record live to `state` (a fresh one if nil); returns it and every achievement earned, in order.
	local function applyAll(records, state)
		return applyLive(fold, records, state)
	end

	-- The `zoneRank` achievements among `earned`.
	local function zoneRanks(earned)
		local list = {}
		for _, achievement in ipairs(earned) do
			if achievement.kind == "zoneRank" then
				list[#list + 1] = achievement
			end
		end
		return list
	end

	describe("ranks in the fold (LED-R50, LED-R51)", function()
		it("climbs Lake from Visitor to Master as Catches arrive, each rank paid once (LED-R50, LED-R51)", function()
			local steps = {
				{ { JUNK }, 1 }, -- any Catch: Visitor; the junk counts only at Expert
				{ { ANY_1 }, 1 }, -- 1 of ceil(3 / 2) = 2 ungated Species
				{ { ANY_2B }, 2 }, -- ANY_2 through its second item: Regular
				{ { ANY_1, ANY_2 }, 2 }, -- nothing new
				{ { ANY_3 }, 3 }, -- every ungated Species: Local
				{ { NIGHT, EVENT }, 3 }, -- every gated Species, but no treasure yet
				{ { CHEST }, 4 }, -- the treasure requirement: Expert
				{ { TROPHY_1 }, 4 }, -- one family of two
				{ { TROPHY_2 }, 5 }, -- every family: Master
				{ { TROPHY_2, JUNK, ANY_3 }, 5 },
			}
			local state = fold.reset()
			local passed = {}
			for _, step in ipairs(steps) do
				local record = cast(LAKE, step[1])
				local _, earned = applyAll({ record }, state)
				assert.are.equal(step[2], state.zones[LAKE].rank)
				for _, achievement in ipairs(zoneRanks(earned)) do
					assert.are.equal(record.id, achievement.cast)
					passed[#passed + 1] = { ranks = achievement.ranks, coins = achievement.coins }
				end
			end

			assert.are.same({
				{ ranks = { 1 }, coins = 2 },
				{ ranks = { 2 }, coins = 4 },
				{ ranks = { 3 }, coins = 6 },
				{ ranks = { 4 }, coins = 8 },
				{ ranks = { 5 }, coins = 10 },
			}, passed)
		end)

		it(
			"pays 250 × rank XP and 2 × rank Coins for each rank, after the Cast's other rows (LED-R20, LED-R88)",
			function()
				local record = cast(LAKE, { JUNK })
				local state, earned = applyAll({ record })

				-- Catch XP doubled by Fresh Water, the curio item, the zone's first Catch, then Visitor.
				assert.are.equal(20 + 150 + 200 + 250, state.xp)
				assert.are.equal(5 + 2, state.coins)
				assert.are.same({
					{ kind = "newCurio", cast = record.id, coins = 5, itemID = JUNK },
					{ kind = "zoneRank", cast = record.id, coins = 2, zone = LAKE, ranks = { 1 } },
				}, earned)
			end
		)

		it(
			"adds 250 × (1 + 2 + 3 + 4 + 5) XP over the whole climb, and nothing for any Catch after it (LED-R20)",
			function()
				local records = {}
				for i, items in ipairs({ { JUNK }, { ANY_1, ANY_2 }, { ANY_3, NIGHT }, { EVENT, CHEST }, { TROPHY_1 } }) do
					records[i] = cast(LAKE, items)
				end
				records[#records + 1] = cast(LAKE, { TROPHY_2 })
				records[#records + 1] = cast(LAKE, { TROPHY_1, ANY_2B, JUNK })
				-- The same records over a world that charts nothing earn every row but the ranks.
				local uncharted = areas()
				uncharted[LAKE].hasData = false
				local plain = ns.NewLedgerFold(foldLookups(ns.NewWorld(lookups(uncharted))))
				local plainState = plain.reset()
				for _, record in ipairs(records) do
					plain.apply(plainState, record, "live")
				end

				local state = applyAll(records)

				assert.are.equal(3750, state.xp - plainState.xp)
				assert.are.equal(5, state.zones[LAKE].rank)
				assert.are.equal(0, plainState.zones[LAKE].rank)
			end
		)

		it(
			"passes Visitor, Regular and Local at once where no Species is ungated: one zoneRank (LED-R50, LED-R51)",
			function()
				local first = cast(COVE, { TROPHY_1B })
				local state, earned = applyAll({ first })

				assert.are.same(
					{ { kind = "zoneRank", cast = first.id, coins = 12, zone = COVE, ranks = { 1, 2, 3 } } },
					zoneRanks(earned)
				)
				assert.are.equal(3, state.zones[COVE].rank)

				-- Its one gated Species, with its one family already landed: Expert and Master together.
				local second = cast(COVE, { GATED })
				local _, more = applyAll({ second }, state)
				assert.are.same(
					{ { kind = "zoneRank", cast = second.id, coins = 18, zone = COVE, ranks = { 4, 5 } } },
					zoneRanks(more)
				)
			end
		)

		it(
			"gives one zoneRank per Cast, however many of its Catches pass ranks, before its levelUp (LED-R51)",
			function()
				local record = cast(LAKE, { ANY_1, ANY_2, ANY_3 })
				local state, earned = applyAll({ record })

				-- One zoneRank, after every Catch's achievements (and their stars), then the levelUp.
				assert.are.equal(1, #zoneRanks(earned))
				local rank, levelUp = earned[#earned - 1], earned[#earned]
				assert.are.same({ "zoneRank", "levelUp" }, { rank.kind, levelUp.kind })
				assert.are.same({ 1, 2, 3 }, rank.ranks)
				assert.are.equal(12, rank.coins)
				-- 3 × 20 Catch XP, 3 × 600 discovery, 200 for the zone and 1,500 for the ranks: 3,560, past
				-- level 4 (3,480).
				assert.are.equal(60 + 1800 + 200 + 1500, state.xp)
				assert.are.same({ 2, 3, 4 }, levelUp.levels)
				assert.are.equal(3 * 10 + 12 + 3 * 40, state.coins)
			end
		)

		it("counts a Species not on the zone's list for nothing there (LED-R50)", function()
			local state, earned = applyAll({ cast(LAKE, { JUNK }), cast(LAKE, { STRAY, ANY_1 }) })

			assert.is_true(state.zones[LAKE].species[STRAY])
			assert.are.equal(1, state.zones[LAKE].rank)
			assert.are.equal(1, #zoneRanks(earned))
			-- Two of Lake's nine parts: ANY_1 and its junk requirement.
			assert.are.equal(22, ns.ZoneCompletion(world, state, LAKE))
		end)

		it("gives zone 0 no zone credit: no zone, no rank, no rank XP (LED-R6)", function()
			local state, earned = applyAll({ cast(0, { ANY_1, ANY_2, ANY_3, JUNK }) })

			assert.are.same({}, state.zones)
			assert.are.same({}, zoneRanks(earned))
			assert.are.equal(4 * 20 + 3 * 500 + 150, state.xp)
		end)

		it("keeps a fished zone that isn't charted at rank 0, with its zone XP, in state.zones (LED-R54)", function()
			local state, earned = applyAll({ cast(MARSH, { ANY_1 }), cast(BLANK, { OTHER }) })

			assert.are.same(
				{ species = { [ANY_1] = true }, families = {}, items = {}, junk = false, treasure = false, rank = 0 },
				state.zones[MARSH]
			)
			assert.are.equal(0, state.zones[BLANK].rank)
			assert.are.same({}, zoneRanks(earned))
			-- Catch XP, the new Species, the Species in a zone and each zone's first Catch.
			assert.are.equal(20 + 500 + 100 + 200 + 20 + 200, state.xp)
		end)

		it(
			"notes the families, trophy and curio items, junk and treasure caught in a zone (LED-R50, LED-R138)",
			function()
				local state = applyAll({ cast(COVE, { TROPHY_1, JUNK, TREASURE, OTHER, 99999, ANY_1 }) })

				assert.are.same({
					species = { [ANY_1] = true },
					families = { [1] = true },
					items = { [TROPHY_1] = true, [JUNK] = true, [TREASURE] = true },
					junk = true,
					treasure = true,
					rank = 3,
				}, state.zones[COVE])
			end
		)

		it("folds the same ranks in live, replay and rebuild mode (LED-R3)", function()
			local function records()
				local log = newLog()
				return { log(LAKE, { JUNK, ANY_1 }), log(COVE, { TROPHY_1B }), log(LAKE, { ANY_2, ANY_3, CHEST }) }
			end
			local results = {}
			for _, mode in ipairs({ "live", "replay", "rebuild" }) do
				local state, earned = fold.reset(), {}
				for _, record in ipairs(records()) do
					fold.apply(state, record, mode, earned)
				end
				results[#results + 1] = { state, earned }
			end

			assert.are.same(results[1], results[2])
			assert.are.same(results[1], results[3])
		end)
	end)

	-- A celebrated set (LED-R90) with `zones`: zone -> the celebrated shown rank.
	local function celebratedWith(zones)
		return { levels = {}, species = {}, speciesZones = {}, zones = zones or {}, skill = {}, coins = 0 }
	end

	describe("zone completion (LED-R53)", function()
		it(
			"counts Lake's 5 listed Species, 2 families, junk and treasure: 9 parts, 100 only at Master (LED-R53)",
			function()
				local state = fold.reset()
				assert.are.equal(0, ns.ZoneCompletion(world, state, LAKE))

				local seen = {}
				for _, items in ipairs({
					{ ANY_1 },
					{ JUNK },
					{ NIGHT },
					{ ANY_2B },
					{ EVENT },
					{ ANY_3, CHEST },
					{ TROPHY_1 },
					{ TROPHY_2 },
				}) do
					applyAll({ cast(LAKE, items) }, state)
					local completion = ns.ZoneCompletion(world, state, LAKE)
					seen[#seen + 1] = completion
					assert.are.equal(state.zones[LAKE].rank == 5, completion == 100)
				end

				assert.are.same({ 11, 22, 33, 44, 55, 77, 88, 100 }, seen)
			end
		)

		it("is nil for a zone that isn't charted, fished or not (LED-R54)", function()
			local state = applyAll({ cast(MARSH, { ANY_1 }) })

			assert.is_nil(ns.ZoneCompletion(world, state, MARSH))
			assert.is_nil(ns.ZoneCompletion(world, state, BLANK))
		end)
	end)

	describe("the shown rank and new to find (LED-R52)", function()
		-- Lake at computed Local: every ungated Species and the junk, no gated Species, no treasure, no trophy.
		local function lakeAtLocal()
			return applyAll({ cast(LAKE, { ANY_1, ANY_2, ANY_3, JUNK }) })
		end

		it(
			"shows Expert for a celebrated 4 over a computed 3, with 2 gated Species and the treasure to find (LED-R52)",
			function()
				local state = lakeAtLocal()
				local celebrated = celebratedWith({ [LAKE] = 4 })

				assert.are.equal(3, state.zones[LAKE].rank)
				assert.are.equal(4, ns.ShownZoneRank(world, state, celebrated, LAKE))
				assert.are.equal(3, ns.NewToFind(world, state, celebrated, LAKE))
			end
		)

		it("sums every rank's shortfall up to a celebrated Master over a computed Visitor (LED-R52)", function()
			local state = applyAll({ cast(LAKE, { ANY_1 }) })
			local celebrated = celebratedWith({ [LAKE] = 5 })

			-- Regular 1 (to 2 of 3), Local 1, Expert 2 gated + junk + treasure, Master 2 families.
			assert.are.equal(5, ns.ShownZoneRank(world, state, celebrated, LAKE))
			assert.are.equal(1 + 1 + 4 + 2, ns.NewToFind(world, state, celebrated, LAKE))
		end)

		it(
			"shows the computed rank, with nothing new to find, when the celebrated one isn't higher (LED-R52)",
			function()
				local state = lakeAtLocal()

				for _, celebrated in ipairs({
					celebratedWith(),
					celebratedWith({ [LAKE] = 0 }),
					celebratedWith({ [LAKE] = 3 }),
				}) do
					assert.are.equal(3, ns.ShownZoneRank(world, state, celebrated, LAKE))
					assert.are.equal(0, ns.NewToFind(world, state, celebrated, LAKE))
				end
			end
		)

		it("shows no rank for a zone that isn't charted, its celebrated rank kept but unused (LED-R54)", function()
			local state = applyAll({ cast(MARSH, { ANY_1 }) })
			local celebrated = celebratedWith({ [MARSH] = 3 })

			assert.are.equal(0, ns.ShownZoneRank(world, state, celebrated, MARSH))
			assert.are.equal(0, ns.NewToFind(world, state, celebrated, MARSH))
			assert.is_nil(ns.NextRequirement(world, state, celebrated, MARSH))
		end)
	end)

	describe("the next requirement (LED-R134)", function()
		-- The next requirement for Lake after `casts` (each a list of item IDs), with Lake celebrated at `rank`.
		local function nextFor(casts, rank)
			local state = fold.reset()
			for _, items in ipairs(casts) do
				applyAll({ cast(LAKE, items) }, state)
			end
			return ns.NextRequirement(world, state, celebratedWith({ [LAKE] = rank }), LAKE)
		end

		it("reads from the shown rank, rank by rank up Lake's climb (LED-R134)", function()
			assert.are.equal("Catch anything here to become a Visitor", nextFor({}))
			assert.are.equal("Regular: 2 more any-time Species", nextFor({ { JUNK } }))
			assert.are.equal("Regular: 1 more any-time Species", nextFor({ { ANY_1 } }))
			assert.are.equal("Local: 1 more any-time Species", nextFor({ { ANY_1, ANY_2 } }))
			assert.are.equal(
				"Expert: 2 more day, night, seasonal or event catches, a piece of junk",
				nextFor({ { ANY_1, ANY_2, ANY_3, CHEST } })
			)
			assert.are.equal(
				"Expert: 1 more day, night, seasonal or event catch, a piece of junk, a treasure",
				nextFor({ { ANY_1, ANY_2, ANY_3, NIGHT } })
			)
			assert.are.equal("Expert: a treasure", nextFor({ { ANY_1, ANY_2, ANY_3, NIGHT, EVENT, JUNK } }))
			assert.are.equal(
				"Master: a trophy from 2 more families",
				nextFor({ { ANY_1, ANY_2, ANY_3, NIGHT, EVENT, JUNK, CHEST } })
			)
			assert.are.equal(
				"Master: a trophy from 1 more family",
				nextFor({ { ANY_1, ANY_2, ANY_3, NIGHT, EVENT, JUNK, CHEST, TROPHY_2 } })
			)
			assert.are.equal(
				"Master of these waters",
				nextFor({ { ANY_1, ANY_2, ANY_3, NIGHT, EVENT, JUNK, CHEST, TROPHY_2, TROPHY_1 } })
			)
		end)

		it("appends new to find, counting from the shown rank's next one (LED-R52)", function()
			-- Shown Expert over a computed Local: the families next, 2 gated Species and the treasure to find.
			assert.are.equal(
				"Master: a trophy from 2 more families · 3 new to find: the data grew, and your seal stays",
				nextFor({ { ANY_1, ANY_2, ANY_3, JUNK } }, 4)
			)
			-- Shown Regular over a computed Visitor: Local's own shortfall next, Regular's to find.
			assert.are.equal(
				"Local: 1 more any-time Species · 1 new to find: the data grew, and your seal stays",
				nextFor({ { ANY_1 } }, 2)
			)
		end)

		it("puts new to find in place of Master of these waters at a celebrated Master (LED-R134)", function()
			assert.are.equal("8 new to find: the data grew, and your seal stays", nextFor({ { ANY_1 } }, 5))
		end)

		it("is new to find alone when the rank above the shown one needs nothing more of its own (LED-R134)", function()
			-- Shown Local over a computed Visitor, with Expert's own parts all met.
			assert.are.equal(
				"2 new to find: the data grew, and your seal stays",
				nextFor({ { ANY_1, NIGHT, EVENT, JUNK, CHEST } }, 3)
			)
		end)
	end)
end)
