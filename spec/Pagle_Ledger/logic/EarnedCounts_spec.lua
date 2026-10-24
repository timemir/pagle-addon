-- The Curio Shop's second round's earned goods (LED-R118, LED-R119, SHOP-R28): the counts the fold keeps for every
-- Cast, each good's rule at its mark over the state and the celebrated set, the goods kept once noted, and the seven
-- toast styles as registered, through ns.NewLedgerFold, ns.EarnedGoodOwned, ns.EarnedCount, ns.NoteEarnedGoods and
-- ns.CountedToastStyles. Hand-made records over a fixture catalogue; no Core.

-- The fixture catalogue: two Species, a Legend, the Big-mouth Clam (a container) and a junk item. Unlisted IDs are
-- Uncharted.
local MACKEREL, SMALLFISH, LEGEND, CLAM, JUNK = 6303, 6291, 19803, 7973, 6309
local ITEMS = {
	[MACKEREL] = fishRecord(MACKEREL),
	[SMALLFISH] = fishRecord(SMALLFISH),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
	[CLAM] = itemRecord("container"),
	[JUNK] = itemRecord("junk"),
}
local getItem = itemLookup(ITEMS)

-- Zones: two ordinary ones, an ice zone (Winterspring), and an open-sea zone and subzone (The Great Sea's 2317 under
-- Stranglethorn, 33).
local ELWYNN, WESTFALL, WINTERSPRING, STRANGLETHORN, GREAT_SEA, VEILED_SEA = 12, 40, 618, 33, 2317, 214

-- The log's characters (LOG-R25), by index: a Human and a Gnome of the Alliance, an Orc of the Horde.
local CHARACTERS = {
	{ raceID = 1, faction = "Alliance" },
	{ raceID = 2, faction = "Horde" },
	{ raceID = 7, faction = "Alliance" },
}

local T0 = SERVER_TIME - 700
local DAY = 86400

-- A realm date `day` days after 1 October 2026 (LOG-R49).
---@param day integer
local function dateAfter(day)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
	local time = os.time({ year = 2026, month = 10, day = 1 + day, hour = 12 })
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
	local t = os.date("*t", time)
	return { year = t.year, month = t.month, day = t.day, weekday = t.wday }
end

-- Builds Casts the way the Catch log hands them out (LOG-R42), with seq and entry IDs in order: `fields` as
-- castRecord's, `day` the realm date's days after 1 October 2026 (0 by default; false for none), `lure` the lure,
-- `sizes` a size per Catch.
local function newLog()
	local seq = 0
	local log = {}

	---@param fields table
	---@return PagleCast
	function log.cast(fields)
		seq = seq + 1
		local day = fields.day == nil and 0 or fields.day
		local record = castRecord({
			seq = seq,
			time = T0 + seq,
			zone = fields.zone or ELWYNN,
			subzone = fields.subzone,
			minute = fields.minute or 600,
			date = day and dateAfter(day) or nil,
			items = fields.items or { MACKEREL },
			outcome = fields.outcome,
			char = fields.char,
		})
		record.conditions.lure = fields.lure
		for n, size in pairs(fields.sizes or {}) do
			record.items[n].size = { length = size, band = 3 }
		end
		return record
	end

	--- A got-away Cast (LOG-R7).
	function log.gotAway(fields)
		fields = fields or {}
		fields.items, fields.outcome = {}, "gotAway"
		return log.cast(fields)
	end

	return log
end

describe("the second round's earned goods", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns

	-- The world index (LED-R10): Mackerel and Smallfish in Elwynn and Westfall.
	local world = ns.NewWorld({
		GetItem = getItem,
		GetZones = function()
			return { ELWYNN, WESTFALL }
		end,
		GetArea = function()
			return { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = true, catches = {} }
		end,
		GetZoneCatches = function()
			return { { itemID = MACKEREL, confirmed = true }, { itemID = SMALLFISH, confirmed = true } }
		end,
	})

	local fold, log
	before_each(function()
		fold = ns.NewLedgerFold({
			GetItem = getItem,
			MatchesConditions = loaded.env.Pagle.MatchesConditions,
			world = world,
			GetCharacter = function(index)
				return CHARACTERS[index]
			end,
		})
		log = newLog()
	end)

	-- The counts after folding `records` into a fresh state, in "rebuild" mode: the same in every mode (LED-R3).
	---@param records table[]
	---@return LedgerCounts, LedgerState
	local function countsOf(records)
		local state = applyLive(fold, records, nil, "rebuild")
		return state.counts, state
	end

	-- The good of LED-R118 with ID `goodID`.
	---@param goodID string
	---@return LedgerCountedGood
	local function good(goodID)
		for _, counted in ipairs(ns.COUNTED_GOODS) do
			if counted.id == goodID then
				return counted
			end
		end
		error("no good " .. goodID)
	end

	-- What the rules read: `state`, `celebrated` and the fixture world.
	---@param state LedgerState?
	---@param celebrated table?
	---@return LedgerEarnedView
	local function view(state, celebrated)
		return { state = state, celebrated = celebrated or {}, world = world, sizeBands = 5 }
	end

	describe("counted by the fold", function()
		it("start at nothing in a fresh state (LED-R3, ledger.md › Data)", function()
			local counts = fold.reset().counts
			assert.are.same({ 0, 0, 0, 0, 0, 0, 0, false }, {
				counts.shards,
				counts.deep,
				counts.pairs,
				counts.records,
				counts.ice,
				counts.sea,
				counts.clams,
				counts.afterRun,
			})
		end)

		describe("glass shards (LED-R119)", function()
			it("give one for a zone's first caught Cast ever, none for its others that day", function()
				local counts = countsOf({
					log.cast({ zone = ELWYNN }),
					log.cast({ zone = ELWYNN }),
					log.cast({ zone = WESTFALL }),
				})
				assert.are.equal(2, counts.shards)
			end)

			it("give one only when the zone had no caught Cast on any of the six realm dates before", function()
				local counts = countsOf({
					log.cast({ day = 0 }),
					log.cast({ day = 6 }), -- six dates after: still within the six before it
					log.cast({ day = 13 }), -- seven after day 6: a shard
					log.cast({ day = 14 }),
				})
				assert.are.equal(2, counts.shards)
			end)

			it("ignore got-away Casts, zone 0 and a Cast stored without its realm date", function()
				local counts = countsOf({
					log.gotAway({ zone = WESTFALL }),
					log.cast({ zone = 0 }),
					log.cast({ zone = WESTFALL, day = false }),
				})
				assert.are.equal(0, counts.shards)
				-- the got-away Cast didn't rest the zone either: its first caught Cast with a date is a shard
				assert.are.equal(
					1,
					countsOf({ log.gotAway({ zone = WESTFALL }), log.cast({ zone = WESTFALL }) }).shards
				)
			end)

			it(
				"never go back: a Cast on an earlier date than the zone's latest neither earns one nor moves it",
				function()
					local counts = countsOf({ log.cast({ day = 10 }), log.cast({ day = 2 }), log.cast({ day = 17 }) })
					assert.are.equal(2, counts.shards)
					assert.are.equal(ns.DayNumber(dateAfter(17)), counts.lastDay[ELWYNN])
				end
			)
		end)

		it("count caught Casts between 00:00 and 03:59 realm time for The Deep Lure (LED-R118)", function()
			local counts = countsOf({
				log.cast({ minute = 0 }),
				log.cast({ minute = 239 }),
				log.cast({ minute = 240 }),
				log.cast({ minute = 1439 }),
				log.gotAway({ minute = 10 }),
			})
			assert.are.equal(2, counts.deep)
		end)

		describe("pairs (Ink and Koi, LED-R118)", function()
			it("count a caught Cast sharing a Species with the caught Cast before it; a run of three is two", function()
				local counts = countsOf({
					log.cast({ items = { MACKEREL } }),
					log.cast({ items = { MACKEREL } }),
					log.cast({ items = { SMALLFISH, MACKEREL } }),
					log.cast({ items = { SMALLFISH } }),
				})
				assert.are.equal(3, counts.pairs)
			end)

			it("aren't broken by got-away Casts between, but are by a caught Cast with no Species", function()
				local counts = countsOf({
					log.cast({ items = { MACKEREL } }),
					log.gotAway(),
					log.gotAway(),
					log.cast({ items = { MACKEREL } }),
					log.cast({ items = { JUNK } }),
					log.cast({ items = { MACKEREL } }),
				})
				assert.are.equal(1, counts.pairs)
			end)

			it("count a Cast with two Catches of one Species once, and never a Legend", function()
				local counts = countsOf({
					log.cast({ items = { MACKEREL, MACKEREL } }),
					log.cast({ items = { LEGEND } }),
					log.cast({ items = { LEGEND } }),
				})
				assert.are.equal(0, counts.pairs)
				assert.are.equal(1, countsOf({ log.cast({}), log.cast({ items = { MACKEREL, MACKEREL } }) }).pairs)
			end)
		end)

		it("count the size records beaten, never the first sized Catch that sets one (LED-R118, LED-R82)", function()
			local counts = countsOf({
				log.cast({ sizes = { 300 } }),
				log.cast({ sizes = { 310 } }),
				log.cast({ sizes = { 310 } }),
				log.cast({ items = { MACKEREL, SMALLFISH }, sizes = { 320, 200 } }),
				log.cast({ items = { MACKEREL, SMALLFISH }, sizes = { 330, 210 } }),
			})
			assert.are.equal(4, counts.records)
		end)

		it("count caught Casts in the ice zones and at sea, by zone or subzone (LED-R118)", function()
			local counts = countsOf({
				log.cast({ zone = WINTERSPRING }),
				log.cast({ zone = 1 }),
				log.cast({ zone = 36 }),
				log.cast({ zone = STRANGLETHORN, subzone = GREAT_SEA }),
				log.cast({ zone = VEILED_SEA }),
				log.cast({ zone = STRANGLETHORN, subzone = 0 }),
				log.gotAway({ zone = WINTERSPRING }),
				log.gotAway({ zone = VEILED_SEA }),
			})
			assert.are.same({ 3, 2 }, { counts.ice, counts.sea })
		end)

		describe("the fish of each race and faction (LED-R164)", function()
			it(
				"counts a Species, a Legend and a trophy fish for the race and faction of the character who caught it",
				function()
					local counts = countsOf({
						log.cast({ char = 1, items = { MACKEREL, LEGEND } }),
						log.cast({ char = 2, items = { SMALLFISH } }),
						log.cast({ char = 3, items = { MACKEREL, SMALLFISH, MACKEREL } }),
					})

					assert.are.same({ [1] = 2, [2] = 1, [7] = 3 }, counts.races)
					assert.are.same({ Alliance = 5, Horde = 1 }, counts.factions)
				end
			)

			it("counts neither junk, a chest, an item the catalogue lacks nor a got-away Cast", function()
				local counts = countsOf({
					log.cast({ char = 1, items = { JUNK, CLAM, 999999 } }),
					log.gotAway({ char = 1 }),
				})

				assert.are.same({}, counts.races)
				assert.are.same({}, counts.factions)
			end)

			it("counts nothing for a character the log doesn't have, and none of its fish toward another", function()
				local counts = countsOf({
					log.cast({ char = 9, items = { MACKEREL } }),
					log.cast({ char = 1, items = { MACKEREL } }),
				})

				assert.are.same({ [1] = 1 }, counts.races)
				assert.are.same({ Alliance = 1 }, counts.factions)
			end)

			it("counts the same in every mode, a rebuild or a live Cast (LED-R3)", function()
				local records = {
					log.cast({ char = 1, items = { MACKEREL } }),
					log.cast({ char = 2, items = { SMALLFISH, LEGEND } }),
				}
				local live = applyLive(fold, records, nil, "live").counts

				assert.are.same(live, (countsOf(records)))
			end)

			it("earns a race style at 100 fish of that race and not one short, whatever another race caught", function()
				local records = {}
				for i = 1, 99 do
					records[i] = log.cast({ char = 3, items = { MACKEREL } })
				end
				records[100] = log.cast({ char = 1, items = { MACKEREL, MACKEREL } })
				local _, state = countsOf(records)

				assert.is_false(ns.EarnedGoodOwned("ledger.toaststyle.blueprint", "blueprint", view(state)))
				assert.are.equal(99, ns.EarnedCount(good("ledger.toaststyle.blueprint"), view(state)))
				assert.are.equal(2, ns.EarnedCount(good("ledger.toaststyle.crier"), view(state)))
				assert.is_false(ns.EarnedGoodOwned("ledger.toaststyle.crier", "crier", view(state)))
				records[#records + 1] = log.cast({ char = 3, items = { MACKEREL } })
				local _, more = countsOf(records)
				assert.is_true(ns.EarnedGoodOwned("ledger.toaststyle.blueprint", "blueprint", view(more)))
			end)

			it("earns a faction style at 300 fish over every race of it, the other faction's none", function()
				local records = {}
				for _ = 1, 150 do
					records[#records + 1] = log.cast({ char = 1, items = { MACKEREL } })
					records[#records + 1] = log.cast({ char = 3, items = { MACKEREL } })
					records[#records + 1] = log.cast({ char = 2, items = { MACKEREL } })
				end
				local _, state = countsOf(records)

				assert.are.equal(300, ns.EarnedCount(good("ledger.toaststyle.lion"), view(state)))
				assert.is_true(ns.EarnedGoodOwned("ledger.toaststyle.lion", "lion", view(state)))
				assert.are.equal(150, ns.EarnedCount(good("ledger.toaststyle.warband"), view(state)))
				assert.is_false(ns.EarnedGoodOwned("ledger.toaststyle.warband", "warband", view(state)))
			end)

			it("reads 0 from a state saved before the fish were counted, until it rebuilds", function()
				local state = fold.reset()
				state.counts.races, state.counts.factions = nil, nil

				assert.are.equal(0, ns.EarnedCount(good("ledger.toaststyle.crier"), view(state)))
				assert.are.equal(0, ns.EarnedCount(good("ledger.toaststyle.lion"), view(state)))
			end)

			it("says what each style asks for, and how far along it is", function()
				local function tag(goodID, n)
					return (ns.EarnedCountTexts(good(goodID), n, tostring))
				end

				assert.are.equal("42 of 100 fish", tag("ledger.toaststyle.blueprint", 42))
				assert.are.equal("300 of 300 fish", tag("ledger.toaststyle.warband", 400))
				assert.are.equal("Catch 100 fish as a Gnome", ns.L.EARNED_TEXT.blueprint)
				assert.are.equal("Catch 300 fish on Horde characters", ns.L.EARNED_TEXT.warband)
			end)
		end)

		describe("the run Carved Heartwood waits for (LED-R118)", function()
			it("is met by a caught Cast right after 10 got-away Casts in a row", function()
				local records = {}
				for _ = 1, 10 do
					records[#records + 1] = log.gotAway()
				end
				records[#records + 1] = log.cast({})
				assert.is_true(countsOf(records).afterRun)
			end)

			it("isn't by 9, nor by 10 a caught Cast broke", function()
				local records = {}
				for i = 1, 10 do
					records[#records + 1] = i == 6 and log.cast({}) or log.gotAway()
				end
				records[#records + 1] = log.cast({})
				local counts = countsOf(records)
				assert.is_false(counts.afterRun)
				assert.are.equal(0, counts.gotAwayRun)
			end)
		end)

		it("keep the realm dates fished, the lures on caught Casts and the Big-mouth Clams (LED-R118)", function()
			local counts = countsOf({
				log.cast({ day = 0, lure = 263, items = { CLAM, CLAM } }),
				log.cast({ day = 0, lure = 264, items = { CLAM } }),
				log.cast({ day = 3, lure = 0 }),
				log.cast({ day = false }),
				log.gotAway({ day = 9, lure = 265 }),
			})
			assert.are.same({
				[ns.DayNumber(dateAfter(0))] = true,
				[ns.DayNumber(dateAfter(3))] = true,
			}, counts.days)
			assert.are.same({ [263] = true, [264] = true }, counts.lures)
			assert.are.equal(3, counts.clams)
		end)

		it("number realm dates in days, so they subtract across months and years (LED-R119)", function()
			assert.are.equal(0, ns.DayNumber({ year = 1970, month = 1, day = 1 }))
			assert.are.equal(1, ns.DayNumber({ year = 2026, month = 11, day = 1 }) - ns.DayNumber(dateAfter(30)))
			assert.are.equal(
				1,
				ns.DayNumber({ year = 2027, month = 1, day = 1 }) - ns.DayNumber({ year = 2026, month = 12, day = 31 })
			)
		end)

		it("are the same in a live apply as in a rebuild (LED-R3)", function()
			local records = { log.cast({ minute = 5 }), log.gotAway(), log.cast({ minute = 5, lure = 263 }) }
			local live = applyLive(fold, records, nil, "live")
			assert.are.same(countsOf(records), live.counts)
		end)
	end)

	describe("each earned at its mark (LED-R118)", function()
		-- A state with `counts` over a fresh one, and `fields` over the state.
		---@param counts table?
		---@param fields table?
		---@return LedgerState
		local function stateWith(counts, fields)
			local state = fold.reset()
			for key, value in pairs(counts or {}) do
				state.counts[key] = value
			end
			for key, value in pairs(fields or {}) do
				state[key] = value
			end
			return state
		end

		-- Whether `goodID` is owned over `v`, by its rule or the celebrated set.
		local function owned(goodID, v)
			return ns.EarnedGoodOwned(goodID, good(goodID).earn, v)
		end

		it("are the twenty-six goods in LED-R118's and LED-R164's order, after LED-R116's and LED-R117's", function()
			local ids = {}
			for _, earnedGood in ipairs(ns.EarnedGoods()) do
				ids[#ids + 1] = earnedGood.id
			end
			assert.are.same({
				"ledger.binding.legend",
				"ledger.binding.monster",
				"ledger.binding.abyssal",
				"ledger.binding.keeper",
				"ledger.binding.iridescent",
				"ledger.toaststyle.legend",
				"ledger.toaststyle.prestige",
				"ledger.soundset.concertina",
				"ledger.soundset.choir",
				"ledger.toaststyle.glass",
				"ledger.toaststyle.deep",
				"ledger.toaststyle.koi",
				"ledger.toaststyle.trophy",
				"ledger.toaststyle.slate",
				"ledger.toaststyle.ice",
				"ledger.toaststyle.stitch",
				"ledger.toaststyle.crier",
				"ledger.toaststyle.hall",
				"ledger.toaststyle.glade",
				"ledger.toaststyle.blueprint",
				"ledger.toaststyle.drum",
				"ledger.toaststyle.shroud",
				"ledger.toaststyle.totem",
				"ledger.toaststyle.hex",
				"ledger.toaststyle.lion",
				"ledger.toaststyle.warband",
				"ledger.binding.wave",
				"ledger.binding.logbook",
				"ledger.binding.heartwood",
				"ledger.binding.stormglass",
				"ledger.binding.lacquer",
				"ledger.binding.knit",
				"ledger.binding.flywallet",
				"ledger.binding.carapace",
				"ledger.binding.ember",
			}, ids)
		end)

		it("hold the marks of ledger.md's Tunables", function()
			local marks = {}
			for _, counted in ipairs(ns.COUNTED_GOODS) do
				marks[#marks + 1] = counted.mark
			end
			assert.are.same({
				12,
				100,
				25,
				25,
				30,
				100,
				20,
				100,
				100,
				100,
				100,
				100,
				100,
				100,
				100,
				300,
				300,
				300,
				25,
				1,
				10,
				30,
				10000,
				5,
				50,
				7,
			}, marks)
		end)

		it("earn each count kept in the state's counts at its mark, not one short", function()
			for goodID, count in pairs({
				["ledger.toaststyle.glass"] = { shards = 12 },
				["ledger.toaststyle.deep"] = { deep = 100 },
				["ledger.toaststyle.koi"] = { pairs = 25 },
				["ledger.toaststyle.trophy"] = { records = 25 },
				["ledger.toaststyle.ice"] = { ice = 100 },
				["ledger.binding.wave"] = { sea = 300 },
				["ledger.binding.carapace"] = { clams = 50 },
			}) do
				local key, mark = next(count)
				assert(owned(goodID, view(stateWith({ [key] = mark }))), goodID)
				assert(not owned(goodID, view(stateWith({ [key] = mark - 1 }))), goodID)
			end
		end)

		it("earn Carved Heartwood once the run was met", function()
			assert.is_true(owned("ledger.binding.heartwood", view(stateWith({ afterRun = true }))))
			assert.is_false(owned("ledger.binding.heartwood", view(stateWith({ gotAwayRun = 12 }))))
		end)

		it("earn Black Lacquer Koi at 30 realm dates fished and Fly Wallet at 5 different lures", function()
			local days, lures = {}, {}
			for day = 1, 29 do
				days[day] = true
			end
			for lure = 1, 4 do
				lures[lure] = true
			end
			assert.is_false(owned("ledger.binding.lacquer", view(stateWith({ days = days }))))
			assert.is_false(owned("ledger.binding.flywallet", view(stateWith({ lures = lures }))))
			days[30], lures[5] = true, true
			assert.is_true(owned("ledger.binding.lacquer", view(stateWith({ days = days }))))
			assert.is_true(owned("ledger.binding.flywallet", view(stateWith({ lures = lures }))))
		end)

		it("earn Fishmonger's Slate at 30 Species and Captain's Logbook at 25 zones fished (LED-R5, LED-R6)", function()
			local species, zones = {}, {}
			for id = 1, 30 do
				species[id] = { n = 1 }
			end
			for zone = 1, 25 do
				zones[zone] = { rank = 0 }
			end
			assert.is_true(owned("ledger.toaststyle.slate", view(stateWith(nil, { species = species }))))
			assert.is_true(owned("ledger.binding.logbook", view(stateWith(nil, { zones = zones }))))
			species[30], zones[25] = nil, nil
			assert.is_false(owned("ledger.toaststyle.slate", view(stateWith(nil, { species = species }))))
			assert.is_false(owned("ledger.binding.logbook", view(stateWith(nil, { zones = zones }))))
		end)

		it("earn the Cross-Stitch Sampler with a Catch of each of its twenty Species, no other", function()
			local species = {}
			for i, id in ipairs(ns.SAMPLER_SPECIES) do
				if i > 1 then
					species[id] = { n = 1 }
				end
			end
			for id = 1, 40 do
				species[id] = { n = 1 }
			end
			assert.is_false(owned("ledger.toaststyle.stitch", view(stateWith(nil, { species = species }))))
			species[ns.SAMPLER_SPECIES[1]] = { n = 1 }
			assert.is_true(owned("ledger.toaststyle.stitch", view(stateWith(nil, { species = species }))))
		end)

		it("earn Cable Knit at 10,000 Casts, caught and got away (LED-R93)", function()
			assert.is_false(owned("ledger.binding.knit", view(stateWith(nil, { casts = 9999 }))))
			assert.is_true(owned("ledger.binding.knit", view(stateWith(nil, { casts = 10000 }))))
		end)

		it(
			"earn Stormglass Reliquary at 10 zones at Master, the computed or the celebrated rank (LED-R52, LED-R114)",
			function()
				local zones, celebratedZones = {}, {}
				for zone = 1, 6 do
					zones[zone] = { rank = 5 }
				end
				zones[7] = { rank = 4 }
				-- six computed, the seventh celebrated at Master over its computed Expert, the eighth celebrated only
				celebratedZones[7], celebratedZones[8], celebratedZones[9] = 5, 5, 4
				local state = stateWith(nil, { zones = zones })
				assert.is_false(owned("ledger.binding.stormglass", view(state, { zones = celebratedZones })))
				celebratedZones[9], celebratedZones[10] = 5, 5
				assert.is_true(owned("ledger.binding.stormglass", view(state, { zones = celebratedZones })))
			end
		)

		it("earn Ember Scale at Prestige VII, by the state or the highest celebrated rank (LED-R34)", function()
			assert.is_false(owned("ledger.binding.ember", view(stateWith(nil, { prestige = 6 }))))
			assert.is_true(owned("ledger.binding.ember", view(stateWith(nil, { prestige = 7 }))))
			assert.is_true(owned("ledger.binding.ember", view(nil, { prestige = 8 })))
		end)

		it("earn nothing without a state, nor from a state saved before the counts were kept", function()
			local old = stateWith()
			old.counts = nil
			for _, counted in ipairs(ns.COUNTED_GOODS) do
				assert(not owned(counted.id, view(nil)), counted.id)
				assert(not owned(counted.id, view(old)), counted.id)
			end
		end)

		it(
			"are noted in the celebrated set once reached and kept after, the bindings too (LED-R118, LED-R90)",
			function()
				local celebrated = {}
				local made = stateWith({ shards = 12, clams = 50 })

				assert.is_true(ns.NoteEarnedGoods(celebrated, view(made, celebrated)))
				assert.are.same({
					["ledger.toaststyle.glass"] = true,
					["ledger.binding.carapace"] = true,
				}, celebrated.goods)
				assert.is_false(ns.NoteEarnedGoods(celebrated, view(made, celebrated)))

				-- A rebuild that counts lower (a retuned catalogue): both kept.
				local rebuilt = stateWith({ shards = 3 })
				assert.is_false(ns.EarnedRuleHolds("glass", view(rebuilt, celebrated)))
				assert.is_true(owned("ledger.toaststyle.glass", view(rebuilt, celebrated)))
				assert.is_true(owned("ledger.binding.carapace", view(nil, celebrated)))
			end
		)
	end)

	describe("registered in Core's toast style and binding slots (LED-R118, LED-R110, SHOP-R23, SHOP-R25)", function()
		local counts

		-- The sixteen goods over hooks whose earnedBy names goods earned in `earned`, and whose count reads `counts`
		-- (nil while updating).
		local function register(earned)
			return ns.CountedGoods({
				earnedBy = function(goodID)
					return earned[goodID] == true
				end,
				count = function(counted)
					return counts and counts[counted.id]
				end,
				formatNumber = function(n)
					return "<" .. n .. ">"
				end,
			})
		end

		before_each(function()
			counts = {}
		end)

		it(
			"are the seventeen toast styles then the nine bindings, named and described by lore, with an icon and no preview (LED-R160)",
			function()
				local rows = {}
				for i, registered in
					ipairs(register({ ["ledger.toaststyle.koi"] = true, ["ledger.binding.carapace"] = true }))
				do
					rows[i] =
						{ registered.id, registered.slot, registered.name, registered.isEarned(), registered.preview }
					assert.are.equal(ns.L["ledgergood." .. registered.id .. ".description"], registered.description)
					assert.matches("^Interface\\Icons\\", registered.icon)
				end
				assert.are.same({
					{ "ledger.toaststyle.glass", "core.toaststyle", "Chapel Glass", false },
					{ "ledger.toaststyle.deep", "core.toaststyle", "The Deep Lure", false },
					{ "ledger.toaststyle.koi", "core.toaststyle", "Ink and Koi", true },
					{ "ledger.toaststyle.trophy", "core.toaststyle", "Mounted Trophy", false },
					{ "ledger.toaststyle.slate", "core.toaststyle", "Fishmonger's Slate", false },
					{ "ledger.toaststyle.ice", "core.toaststyle", "Through the Ice", false },
					{ "ledger.toaststyle.stitch", "core.toaststyle", "Cross-Stitch Sampler", false },
					{ "ledger.toaststyle.crier", "core.toaststyle", "Town Crier's Proclamation", false },
					{ "ledger.toaststyle.hall", "core.toaststyle", "Mountain Hall", false },
					{ "ledger.toaststyle.glade", "core.toaststyle", "Starlit Glade", false },
					{ "ledger.toaststyle.blueprint", "core.toaststyle", "Tinker's Blueprint", false },
					{ "ledger.toaststyle.drum", "core.toaststyle", "Clan Drum", false },
					{ "ledger.toaststyle.shroud", "core.toaststyle", "Grave Shroud", false },
					{ "ledger.toaststyle.totem", "core.toaststyle", "Plains Totem", false },
					{ "ledger.toaststyle.hex", "core.toaststyle", "Jungle Hex", false },
					{ "ledger.toaststyle.lion", "core.toaststyle", "Lion's Charter", false },
					{ "ledger.toaststyle.warband", "core.toaststyle", "Iron Warband", false },
					{ "ledger.binding.wave", "core.binding", "Breaking Wave", false },
					{ "ledger.binding.logbook", "core.binding", "Captain's Logbook", false },
					{ "ledger.binding.heartwood", "core.binding", "Carved Heartwood", false },
					{ "ledger.binding.stormglass", "core.binding", "Stormglass Reliquary", false },
					{ "ledger.binding.lacquer", "core.binding", "Black Lacquer Koi", false },
					{ "ledger.binding.knit", "core.binding", "Cable Knit", false },
					{ "ledger.binding.flywallet", "core.binding", "Fly Wallet", false },
					{ "ledger.binding.carapace", "core.binding", "Crab Carapace", true },
					{ "ledger.binding.ember", "core.binding", "Ember Scale", false },
				}, rows)
			end
		)

		it("earn each binding by its rule and the celebrated set, through earnedBy (LED-R118)", function()
			local asked = {}
			local goods = ns.CountedGoods({
				earnedBy = function(goodID, rule)
					asked[#asked + 1] = { goodID, rule }
					return rule == "ember"
				end,
				count = function()
					return nil
				end,
				formatNumber = tostring,
			})
			assert.are.same({ false, true }, { goods[18].isEarned(), goods[26].isEarned() })
			assert.are.same({ { "ledger.binding.wave", "wave" }, { "ledger.binding.ember", "ember" } }, asked)
		end)

		it("tag a binding with its count of its mark, the one-step ones with their earned text (SHOP-R22)", function()
			local goods = register({})
			counts["ledger.binding.logbook"], counts["ledger.binding.knit"] = 12, 2500
			assert.are.same({ "<12> of <25> zones", "25 zones fished" }, { goods[19].earnedText() })
			assert.are.same({ "<2500> of <10000> Casts", "10,000 Casts" }, { goods[23].earnedText() })
			counts["ledger.binding.heartwood"] = 0
			assert.are.same({ "A catch after 10 got away", "A catch after 10 got away" }, { goods[20].earnedText() })
		end)

		it("tag each with its count of its mark, and note the earned text in full (SHOP-R22)", function()
			local goods = register({})
			counts["ledger.toaststyle.glass"], counts["ledger.toaststyle.stitch"] = 7, 25
			assert.are.same({ "<7> of <12> shards", "12 glass shards" }, { goods[1].earnedText() })
			assert.are.same({ "<20> of <20> fish", "The sampler's 20 fish" }, { goods[7].earnedText() })
		end)

		it("keep the tag they gave last while the projection updates, the plain text before any", function()
			local goods = register({})
			counts = nil
			assert.are.same({ "100 catches after midnight", "100 catches after midnight" }, { goods[2].earnedText() })
			counts = { ["ledger.toaststyle.deep"] = 40 }
			assert.are.same({ "<40> of <100> catches", "100 catches after midnight" }, { goods[2].earnedText() })
			counts = nil
			assert.are.same({ "<40> of <100> catches", "100 catches after midnight" }, { goods[2].earnedText() })
		end)

		it("give one-step goods their earned text as the tag (LED-R118)", function()
			assert.are.same(
				{ "Prestige VII", "Prestige VII" },
				{ ns.EarnedCountTexts(good("ledger.binding.ember"), 3, tostring) }
			)
			assert.are.same(
				{ "A catch after 10 got away", "A catch after 10 got away" },
				{ ns.EarnedCountTexts(good("ledger.binding.heartwood"), 0, tostring) }
			)
		end)

		describe("the fallback price (SHOP-R28)", function()
			after_each(function()
				ns.ROUND_TWO_RELEASE = nil
			end)

			it("is none while the release time is unset", function()
				assert.is_nil(ns.ROUND_TWO_RELEASE)
				for _, registered in ipairs(register({})) do
					assert.is_nil(registered.fallbackTier)
					assert.is_nil(registered.fallbackFrom)
				end
			end)

			it("is tier 5 from 90 days after the release that sets its time", function()
				ns.ROUND_TWO_RELEASE = T0
				for _, registered in ipairs(register({})) do
					assert.are.same({ 5, T0 + 90 * DAY }, { registered.fallbackTier, registered.fallbackFrom })
				end
			end)
		end)
	end)
end)
