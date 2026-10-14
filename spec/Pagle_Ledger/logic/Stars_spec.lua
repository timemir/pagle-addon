-- Species Mastery and trophy family stars (LED-R45–R48): earned in the fold from Catches and the world index, and
-- shown as the union with the celebrated ones. Hand-made records over a fixture catalogue, whose world index ns.NewWorld
-- builds; window specs judged by Core's own Pagle.MatchesConditions (LOG-R48, LOG-R49). ledger.md › Species Mastery,
-- The Ledger's world, Celebrating, Data, Tunables.

-- Species items (LOG-R55, DATA-R19).
local NIGHTFISH, SEASONFISH, WIDEFISH, LONEFISH, STRAY, MIXED = 13759, 13755, 6303, 6291, 6290, 13760
-- A Legend item: kept off every zone list (LED-R10).
local LEGEND = 19803
-- One trophy family's four listed weights, in pounds, and a fifth weight on no list (LED-R10, LED-R47).
local W40, W60, W50, W45, W70 = 13876, 13877, 13878, 13879, 13880
-- A family with no listed weight: its one weight is on no list.
local LOOSE = 13881
local FAMILY, LOOSE_FAMILY = 2, 3

local ELWYNN, WESTFALL, DUSKWOOD, REDRIDGE, STRANGLETHORN, DARKSHORE = 12, 40, 10, 44, 33, 148

-- Window specs (DATA-R78): night 21:00–06:00, summer and winter by realm date.
local NIGHT = { time = { { 1260, 360 } } }
local SUMMER = { season = { { from = { 3, 20 }, to = { 9, 18 } } } }
local WINTER = { season = { { from = { 9, 23 }, to = { 3, 24 } } } }

local function trophy(family, weight)
	return itemRecord("trophy", { family = family, weight = weight })
end

local ITEMS = {
	[NIGHTFISH] = fishRecord(NIGHTFISH),
	[SEASONFISH] = fishRecord(SEASONFISH),
	[WIDEFISH] = fishRecord(WIDEFISH),
	[LONEFISH] = fishRecord(LONEFISH),
	[STRAY] = fishRecord(STRAY),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
	[MIXED] = fishRecord(MIXED),
	[W40] = trophy(FAMILY, 40),
	[W60] = trophy(FAMILY, 60),
	[W50] = trophy(FAMILY, 50),
	[W45] = trophy(FAMILY, 45),
	[W70] = trophy(FAMILY, 70),
	[LOOSE] = trophy(LOOSE_FAMILY, 12),
}

-- Six charted zones. NIGHTFISH is gated by night wherever it is listed; SEASONFISH by summer in Elwynn and winter in
-- Westfall; WIDEFISH is ungated in five zones, LONEFISH in one; MIXED is gated in Elwynn but not in Westfall; STRAY is
-- on no list. The family's four listed weights spread over three zones.
local CATCHES = {
	[ELWYNN] = {
		catchEntry(NIGHTFISH, "night", NIGHT),
		catchEntry(SEASONFISH, "summer", SUMMER),
		catchEntry(WIDEFISH),
		catchEntry(MIXED, "night", NIGHT),
		catchEntry(W40),
		catchEntry(W60),
	},
	[WESTFALL] = {
		catchEntry(NIGHTFISH, "night", NIGHT),
		catchEntry(SEASONFISH, "winter", WINTER),
		catchEntry(WIDEFISH),
		catchEntry(MIXED),
		catchEntry(W50),
	},
	[DUSKWOOD] = { catchEntry(WIDEFISH), catchEntry(LONEFISH), catchEntry(W45) },
	[REDRIDGE] = { catchEntry(WIDEFISH) },
	[STRANGLETHORN] = { catchEntry(WIDEFISH) },
	[DARKSHORE] = { catchEntry(W40) },
}

local function getItem(itemID)
	assert(itemID ~= 0, "item 0 is never looked up (LED-R5)")
	return ITEMS[itemID]
end

local T0 = SERVER_TIME - 700
local MIDNIGHT, NOON = 0, 720
local OCTOBER, JULY = { 10, 14 }, { 7, 1 }

describe("Stars", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns
	local world = ns.NewWorld({
		GetItem = getItem,
		GetZones = function()
			return { ELWYNN, WESTFALL, DUSKWOOD, REDRIDGE, STRANGLETHORN, DARKSHORE }
		end,
		GetArea = function(zone)
			return { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = true, catches = CATCHES[zone] }
		end,
		GetZoneCatches = function(zone)
			return CATCHES[zone]
		end,
	})

	local fold, seq
	before_each(function()
		fold = ns.NewLedgerFold({
			GetItem = getItem,
			MatchesConditions = loaded.env.Pagle.MatchesConditions,
			world = world,
		})
		seq = 0
	end)

	-- A caught Cast in `zone` at realm `minute` on realm `date` ({ month, day }, October by default), one Catch per item.
	---@param zone integer
	---@param itemIDs integer[]
	---@param minute integer?
	---@param date integer[]?
	---@return PagleCast
	local function cast(zone, itemIDs, minute, date)
		seq = seq + 1
		date = date or OCTOBER
		return castRecord({
			seq = seq,
			time = T0 + seq * 60,
			zone = zone,
			minute = minute or NOON,
			date = { year = 2026, month = date[1], day = date[2], weekday = 1 },
			items = itemIDs,
		})
	end

	-- Applies each record live to `state` (a fresh one by default); returns the state and the star achievements.
	local function applyAll(records, state)
		state = state or fold.reset()
		local earned = {}
		for _, record in ipairs(records) do
			fold.apply(state, record, "live", earned)
		end
		local stars = {}
		for _, achievement in ipairs(earned) do
			local kind = achievement.kind
			if kind == "elementStar" or kind == "regularStar" or kind == "familyStar" then
				stars[#stars + 1] = achievement
			end
		end
		return state, stars
	end

	describe("In its element, with element windows (LED-R45)", function()
		it("gives a night-only Species ★★ and an elementStar at its first night Catch (LED-R45)", function()
			local day = cast(ELWYNN, { NIGHTFISH }, NOON)
			local night = cast(WESTFALL, { NIGHTFISH }, MIDNIGHT)

			local state, stars = applyAll({ day, night })

			assert.are.same({
				{ kind = "elementStar", cast = night.id, coins = 0, species = NIGHTFISH, itemID = NIGHTFISH },
			}, stars)
			assert.are.same({ night = true }, state.species[NIGHTFISH].windowsMet)
			assert.are.same({ [1] = true, [2] = true }, ns.SpeciesStars(world, state, NIGHTFISH))
		end)

		it("needs a Catch under each of summer and winter, in any zone (LED-R45)", function()
			-- Summer is met in Westfall, whose list gates it by winter: the window is judged wherever the Catch is.
			local summer = cast(WESTFALL, { SEASONFISH }, NOON, JULY)
			local again = cast(ELWYNN, { SEASONFISH }, NOON, JULY)
			local winter = cast(DUSKWOOD, { SEASONFISH }, NOON, { 12, 24 })

			local state, stars = applyAll({ summer, again })
			assert.are.same({}, stars)
			assert.are.same({ summer = true }, state.species[SEASONFISH].windowsMet)
			assert.is_nil(ns.SpeciesStars(world, state, SEASONFISH)[2])

			local _, later = applyAll({ winter }, state)
			assert.are.same({
				{ kind = "elementStar", cast = winter.id, coins = 0, species = SEASONFISH, itemID = SEASONFISH },
			}, later)
			assert.are.same({ summer = true, winter = true }, state.species[SEASONFISH].windowsMet)
		end)

		it(
			"keeps the windows met and earns ★★ once: later night Catches earn nothing (LED-R45, LED-R97)",
			function()
				local _, stars = applyAll({
					cast(ELWYNN, { NIGHTFISH }, MIDNIGHT),
					cast(WESTFALL, { NIGHTFISH }, MIDNIGHT),
					cast(ELWYNN, { NIGHTFISH }, 1300),
				})

				assert.are.equal(1, #stars)
			end
		)
	end)

	describe("In its element, by zones (LED-R45, LED-R6)", function()
		-- The zones a run of Catches of `itemID` earns elementStar at, in order.
		local function starredAt(itemID, zones)
			local records = {}
			for i, zone in ipairs(zones) do
				records[i] = cast(zone, { itemID })
			end
			local _, stars = applyAll(records)
			local at = {}
			for _, achievement in ipairs(stars) do
				for i, record in ipairs(records) do
					if record.id == achievement.cast then
						at[#at + 1] = zones[i]
					end
				end
			end
			return at
		end

		it(
			"needs 3 distinct zones for an ungated Species listed in five, any zone counting (LED-R45, Tunables)",
			function()
				-- A zone off its list counts, and a zone caught in again doesn't count twice.
				assert.are.same({ DARKSHORE }, starredAt(WIDEFISH, { ELWYNN, ELWYNN, WESTFALL, DARKSHORE, REDRIDGE }))
			end
		)

		it("needs 1 zone for a Species listed in one, and for one on no list (LED-R45)", function()
			assert.are.same({ WESTFALL }, starredAt(LONEFISH, { WESTFALL, DUSKWOOD }))
			assert.are.same({ ELWYNN }, starredAt(STRAY, { ELWYNN, WESTFALL }))
		end)

		it(
			"needs 2 zones for one gated in one zone but not in another: it has no element windows (LED-R10, LED-R45)",
			function()
				assert.are.same({ WESTFALL }, starredAt(MIXED, { ELWYNN, ELWYNN, WESTFALL }))
			end
		)

		it("never counts zone 0 (LED-R6, LED-R45)", function()
			assert.are.same({ ELWYNN }, starredAt(STRAY, { 0, 0, ELWYNN }))
		end)

		it("gives a Legend a Species' stars until M4's Legend class: on no list, one zone (LED-R4, LED-R45)", function()
			assert.are.same({ WESTFALL }, starredAt(LEGEND, { WESTFALL, ELWYNN }))
		end)
	end)

	describe("Regular (LED-R45)", function()
		it(
			"earns regularStar at the 50th Catch of a Species, once, and nothing at the 51st (LED-R45, Tunables)",
			function()
				-- Two Catches per Cast, from the first Cast at midnight (★★ there) on, then the 51st alone.
				local records = {}
				for i = 1, 25 do
					records[i] = cast(ELWYNN, { NIGHTFISH, NIGHTFISH }, MIDNIGHT)
				end
				local state, stars = applyAll(records)
				local _, later = applyAll({ cast(ELWYNN, { NIGHTFISH }, MIDNIGHT) }, state)

				assert.are.same({ "elementStar", "regularStar" }, { stars[1].kind, stars[2].kind })
				assert.are.same(
					{ kind = "regularStar", cast = records[25].id, coins = 0, species = NIGHTFISH, itemID = NIGHTFISH },
					stars[2]
				)
				assert.are.equal(2, #stars)
				assert.are.same({}, later)
				assert.are.same({ [1] = true, [2] = true, [3] = true }, ns.SpeciesStars(world, state, NIGHTFISH))
			end
		)

		it("can stand without ★★: 50 daytime Catches of a night-only Species (LED-R45, LED-R48)", function()
			local records = {}
			for i = 1, 50 do
				records[i] = cast(ELWYNN, { NIGHTFISH }, NOON)
			end
			local state, stars = applyAll(records)

			assert.are.same({ "regularStar" }, { stars[1].kind })
			assert.are.same({ [1] = true, [3] = true }, ns.SpeciesStars(world, state, NIGHTFISH))
		end)
	end)

	describe("Catches only (LED-R46)", function()
		it("counts Catches alone: got-away Casts and Skill Readings earn no star (LED-R46)", function()
			local gotAway = cast(ELWYNN, {}, MIDNIGHT)
			gotAway.outcome = "gotAway"
			local reading = { seq = 99, id = "x", kind = "skill", char = 1, time = T0, rank = 300, max = 300, mod = 0 }

			local state, stars = applyAll({ gotAway, reading })

			assert.are.same({}, stars)
			assert.are.same({}, ns.SpeciesStars(world, state, NIGHTFISH))
		end)
	end)

	describe("trophy family stars (LED-R47)", function()
		it("gives ★ at any weight and ★★ at two of four listed weights landed (LED-R47)", function()
			local first = cast(ELWYNN, { W40 })
			local second = cast(DUSKWOOD, { W45 })

			local state, stars = applyAll({ first, second })

			assert.are.same({
				{ kind = "familyStar", cast = second.id, coins = 0, family = FAMILY, stars = { 2 } },
			}, stars)
			assert.are.same({ [1] = true, [2] = true }, ns.FamilyStars(world, state, FAMILY))
		end)

		it(
			"gives ★★★ on the heaviest listed weight even without ★★, and ★★ later (LED-R47, LED-R48)",
			function()
				local heaviest = cast(ELWYNN, { W60 })
				local again = cast(ELWYNN, { W60 })
				local second = cast(WESTFALL, { W50 })

				local state, stars = applyAll({ heaviest, again })
				assert.are.same({
					{ kind = "familyStar", cast = heaviest.id, coins = 0, family = FAMILY, stars = { 3 } },
				}, stars)
				assert.are.same({ [1] = true, [3] = true }, ns.FamilyStars(world, state, FAMILY))

				local _, later = applyAll({ second }, state)
				assert.are.same(
					{ { kind = "familyStar", cast = second.id, coins = 0, family = FAMILY, stars = { 2 } } },
					later
				)
			end
		)

		it("gives an unlisted weight only ★, though heavier than every listed one (LED-R47)", function()
			local state, stars = applyAll({ cast(ELWYNN, { W70 }), cast(ELWYNN, { LOOSE }) })

			assert.are.same({}, stars)
			assert.are.same({ [1] = true }, ns.FamilyStars(world, state, FAMILY))
			assert.are.same({ [1] = true }, ns.FamilyStars(world, state, LOOSE_FAMILY))
		end)

		it(
			"follows the weight's trophyWeight with one familyStar for ★★ and ★★★ together (LED-R47, LED-R97)",
			function()
				local earned = fold.apply(fold.reset(), cast(ELWYNN, { W40, W60 }), "live")
				local kinds = {}
				for i, achievement in ipairs(earned) do
					kinds[i] = achievement.kind
				end

				-- Then the Cast's Zone Mastery rank in Elwynn, after every Catch's achievements (LED-R51).
				assert.are.same({ "trophyWeight", "trophyWeight", "familyStar", "zoneRank" }, kinds)
				assert.are.same({ 2, 3 }, earned[3].stars)
			end
		)

		it("has no stars before a weight is landed (LED-R47)", function()
			assert.are.same({}, ns.FamilyStars(world, fold.reset(), FAMILY, getItem))
		end)
	end)

	describe("shown stars (LED-R48, LED-R92)", function()
		it("shows the union of computed and celebrated Species stars, each on its own (LED-R48)", function()
			local state = applyAll({ cast(ELWYNN, { NIGHTFISH }, NOON) })
			local celebrated = { stars = { [NIGHTFISH] = { [3] = true }, [STRAY] = { [2] = true } } }

			assert.are.same({ [1] = true, [3] = true }, ns.ShownSpeciesStars(world, state, celebrated, NIGHTFISH))
			assert.are.same({ [2] = true }, ns.ShownSpeciesStars(world, state, celebrated, STRAY))
			assert.are.same({}, ns.ShownSpeciesStars(world, state, celebrated, LONEFISH))
		end)

		it("shows the union of computed and celebrated family stars (LED-R48, LED-R92)", function()
			local state = applyAll({ cast(ELWYNN, { W40 }) })
			local celebrated = { familyStars = { [FAMILY] = { [2] = true } } }

			assert.are.same({ [1] = true, [2] = true }, ns.ShownFamilyStars(world, state, celebrated, FAMILY))
		end)

		it("shows the computed stars alone while the celebrated set has no star keys (LED-R48)", function()
			local state = applyAll({ cast(ELWYNN, { W40 }), cast(ELWYNN, { NIGHTFISH }, MIDNIGHT) })

			assert.are.same({ [1] = true, [2] = true }, ns.ShownSpeciesStars(world, state, {}, NIGHTFISH))
			assert.are.same({ [1] = true }, ns.ShownFamilyStars(world, state, {}, FAMILY))
		end)
	end)
end)
