-- When the Ledger's leaderboard measures last rose (LED-R158) and the Angler Level read alone (LED-R159), for Pagle's
-- backend (#364, #76 item 16; logic/Derived.lua). The fold keeps Ledger completion's counts and each measure's rise
-- time, so the backend's driver needn't read Measures after every record. The oracle is what the driver did before:
-- Measures read after every record, a measure rising when it is greater than it was just before (Ledger completion by
-- its percentage; pagle-backend's PRJ-R8). Hand-made records over a fixture catalogue. No Core.

-- Lake lists two Species (FISH with ten varieties, PLAIN with none), a junk item, a trophy weight and a Legend; River
-- lists PLAIN_2 alone, so its one Catch masters it (LED-R50). On no list: STRAY (a Species with ten varieties), a junk
-- item, a Legend, and a removed Species and Legend, which count on neither side (LED-R12).
local FISH, PLAIN, PLAIN_2, STRAY, REMOVED = 6359, 6291, 6303, 6361, 6362
local JUNK, LOOSE_JUNK, TROPHY = 6309, 6310, 13901
local LEGEND, LEGEND_2, GONE_LEGEND = 19803, 19805, 19806
local LAKE, RIVER = 12, 40
local T0 = SERVER_TIME - 90000

local KEYS = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
local RARITIES = { "common", "common", "common", "common", "uncommon", "uncommon", "uncommon", "rare", "rare", "epic" }

local ITEMS = {
	[FISH] = fishRecord(FISH, { varieties = KEYS }),
	[PLAIN] = fishRecord(PLAIN),
	[PLAIN_2] = fishRecord(PLAIN_2),
	[STRAY] = fishRecord(STRAY, { varieties = KEYS }),
	[REMOVED] = fishRecord(REMOVED, { varieties = KEYS, removed = true }),
	[JUNK] = itemRecord("junk"),
	[LOOSE_JUNK] = itemRecord("junk"),
	[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
	[LEGEND_2] = fishRecord(LEGEND_2, { legend = true }),
	[GONE_LEGEND] = fishRecord(GONE_LEGEND, { legend = true, removed = true }),
}
local getItem = itemLookup(ITEMS)

local function worldLookups()
	return {
		GetItem = getItem,
		GetZones = function()
			return { LAKE, RIVER }
		end,
		GetArea = function()
			return areaRecord(0)
		end,
		GetZoneCatches = function(zone)
			if zone == RIVER then
				return { catchEntry(PLAIN_2) }
			end
			return { catchEntry(FISH), catchEntry(PLAIN), catchEntry(JUNK), catchEntry(TROPHY), catchEntry(LEGEND) }
		end,
	}
end

-- Records the way the Catch log hands them out (LOG-R42), seq and entry IDs in order, each a second after the last.
local function newLog()
	local seq = 0
	local log = {}

	-- The next seq and time.
	local function next()
		seq = seq + 1
		return seq, T0 + seq
	end

	--- A caught Cast in `zone`, one Catch per { itemID, index } pair (index nil: no variety, VAR-R4).
	---@param zone integer
	---@param catches { [1]: integer, [2]: integer? }[]
	function log.cast(zone, catches)
		local s, time = next()
		local itemIDs = {}
		for i, catch in ipairs(catches) do
			itemIDs[i] = catch[1]
		end
		local record = castRecord({ seq = s, time = time, zone = zone, items = itemIDs })
		for i, catch in ipairs(catches) do
			local index = catch[2]
			if index then
				record.items[i].variety =
					{ id = getItem(catch[1]).species .. "." .. KEYS[index], index = index, rarity = RARITIES[index] }
			end
		end
		return record
	end

	--- A got-away Cast in `zone`.
	function log.gotAway(zone)
		local s, time = next()
		return castRecord({ seq = s, time = time, zone = zone, outcome = "gotAway" })
	end

	--- A Skill Reading at `rank` (LED-R40).
	function log.skill(rank)
		local s, time = next()
		return { kind = "skill", seq = s, id = "s" .. s, char = 1, time = time, rank = rank, max = 300, mod = 0 }
	end

	--- The Ledger's crest record (LED-R156).
	function log.crest(good)
		local s, time = next()
		return {
			kind = "module",
			seq = s,
			id = "m" .. s,
			char = 1,
			time = time,
			module = "Ledger",
			recordKind = "crest",
			payload = good,
		}
	end

	--- The time the next record will have.
	function log.nextTime()
		return T0 + seq + 1
	end

	return log
end

-- Casts of `species`' varieties `from` to `to` in Lake, one Catch each.
local function varietyCasts(log, species, from, to, into)
	for index = from, to do
		into[#into + 1] = log.cast(LAKE, { { species, index } })
	end
	return into
end

describe("the measures' rise times (LED-R158)", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns
	local world = ns.NewWorld(worldLookups())
	local lookups = { GetItem = getItem, MatchesConditions = loaded.env.Pagle.MatchesConditions, world = world }
	-- Measures and the other backend reads take the world the projection is bound with (logic/Derived.lua).
	ns.world = world

	local MEASURED = { "ledgerCompletion", "speciesCaught", "legendsCaught" }

	-- Whether a measure read after a record is greater than the one read just before it (pagle-backend's PRJ-R8):
	-- Ledger completion by its percentage, the counts by their value.
	local function rose(measure, before, after)
		if measure == "ledgerCompletion" then
			return after.percent > before.percent
		end
		return after > before
	end

	-- Folds `records` in `mode` as the backend's driver did before LED-R158: Measures read after every record, each
	-- measure's `at` the time of the last record after which it was greater than just before. Checks after every record
	-- that the counts the fold keeps are Measures' own. Returns the state, the oracle's `at`, every reading, and the
	-- backend's `ledgerComplete` (its PRJ-R9): the first record after which Ledger completion is 100, as
	-- { seq, char, time }, nil if none.
	local function foldWithOracle(records, mode)
		local fold = ns.NewLedgerFold(lookups)
		local state = fold.reset()
		local current, at, readings, first = ns.Measures(state, 0), {}, {}, nil
		for _, record in ipairs(records) do
			fold.apply(state, record, mode or "rebuild")
			local measures = ns.Measures(state, 0)
			if not first and measures.ledgerCompletion.percent >= 100 then
				first = { seq = record.seq, char = record.char, time = record.time }
			end
			for _, measure in ipairs(MEASURED) do
				if rose(measure, current[measure], measures[measure]) then
					at[measure] = record.time
				end
			end
			current = measures
			readings[#readings + 1] = measures
			local completion, rises = measures.ledgerCompletion, state.rises
			assert.are.same(
				{ completion.done, completion.total, measures.speciesCaught, measures.legendsCaught },
				{ rises.done, rises.total, rises.species, rises.legends },
				"the counts the fold keeps after seq " .. tostring(record.seq)
			)
		end
		return state, at, readings, first
	end

	-- The fixture's story, with the time of each record a measure rises on.
	local function story()
		local log = newLog()
		local records, times = {}, {}
		local function add(record, name)
			records[#records + 1] = record
			if name then
				times[name] = record.time
			end
			return record
		end
		add(log.skill(150))
		add(log.gotAway(LAKE))
		add(log.cast(LAKE, { { PLAIN } }), "plain") -- 1 of 8: 12%
		add(log.cast(LAKE, { { PLAIN } }))
		add(log.cast(LAKE, { { LEGEND } }), "legend")
		add(log.cast(RIVER, { { PLAIN_2 } }), "river") -- PLAIN_2 and River mastered: 3 of 8, 37%
		add(log.cast(LAKE, { { REMOVED, 1 } })) -- removed: neither side (LED-R12)
		add(log.cast(LAKE, { { GONE_LEGEND } }))
		add(log.crest("ledger.crest.elwynn"))
		add(log.cast(LAKE, { { JUNK }, { TROPHY } }), "items") -- 5 of 8: 62%
		-- FISH's first Catch masters Lake too: 7 of 8, 87%. Its tenth variety completes it: 8 of 8, 100%.
		varietyCasts(log, FISH, 1, 10, records)
		times.fish, times.fishComplete = records[#records - 9].time, records[#records].time
		records[#records].char = 2 -- the second character's Cast completes the Ledger
		times.fishCompleteSeq = records[#records].seq
		add(log.cast(LAKE, { { LOOSE_JUNK } }), "looseJunk") -- 9 of 9: still 100%, no rise
		add(log.cast(LAKE, { { STRAY, 1 } }), "stray") -- a Species and a varieties part more in total: 10 of 11, 90%
		varietyCasts(log, STRAY, 2, 10, records)
		times.strayComplete = records[#records].time -- 11 of 11: 100% again, a rise from 90%
		add(log.cast(LAKE, { { LEGEND_2 } }), "legend2")
		add(log.cast(LAKE, { { LEGEND }, { PLAIN } }))
		add(log.skill(300))
		return records, times
	end

	it("starts with nothing done, none risen, of the world's total before any Catch", function()
		local state = ns.NewLedgerFold(lookups).reset()

		-- Species FISH, PLAIN and PLAIN_2, FISH's varieties, the junk item, the trophy weight, Lake and River.
		assert.are.same({ done = 0, total = 8, species = 0, legends = 0, at = {} }, state.rises)
		assert.are.equal(ns.Measures(state, 0).ledgerCompletion.total, state.rises.total)
		assert.are.same({}, ns.MeasureRises(state))
	end)

	it("gives each rise time as the backend read it from Measures after every record", function()
		local records = story()
		local state, at = foldWithOracle(records)

		assert.are.same(at, ns.MeasureRises(state))
	end)

	it("times each measure by the Cast that last raised it", function()
		local records, times = story()
		local state = foldWithOracle(records)

		assert.are.same({
			ledgerCompletion = times.strayComplete,
			speciesCaught = times.stray,
			legendsCaught = times.legend2,
		}, ns.MeasureRises(state))
	end)

	it("raises Ledger completion on each Cast that raised its percentage, and on no other record", function()
		local records = story()
		local _, _, readings = foldWithOracle(records)
		local percents = {}
		for i, measures in ipairs(readings) do
			percents[i] = measures.ledgerCompletion.percent
		end

		-- The skill, the got-away Cast, PLAIN (12), PLAIN again, the Legend, River (37), the removed Species and
		-- Legend, the crest record, the junk and trophy (62), FISH's ten varieties (87, then 100), the loose junk (100),
		-- STRAY (90) and its other nine (100 at the last), the second Legend, the last Cast and the skill.
		assert.are.equal(
			"0 0 12 12 12 37 37 37 37 62 87 87 87 87 87 87 87 87 87 100 100 90 90 90 90 90 90 90 90 90 100 100 100 100",
			table.concat(percents, " ")
		)
	end)

	it("keeps a rise across a fall: 100% fell to 90% on a new Species on no list, then rose again", function()
		local records, times = story()
		local cut = {}
		for _, record in ipairs(records) do
			cut[#cut + 1] = record
			if record.time == times.stray then
				break
			end
		end
		local state, at = foldWithOracle(cut)

		-- 100% first at FISH's tenth variety; the loose junk kept it at 100 and STRAY lowered it, neither a rise.
		assert.are.equal(times.fishComplete, ns.MeasureRises(state).ledgerCompletion)
		assert.are.same(at, ns.MeasureRises(state))
		assert.are.equal(90, ns.Measures(state, 0).ledgerCompletion.percent)
	end)

	it("keeps the record after which Ledger completion first stood at 100%, as the backend found it", function()
		local records, times = story()
		local state, _, _, first = foldWithOracle(records)

		assert.are.same(first, ns.FirstComplete(state))
		assert.are.same({ seq = times.fishCompleteSeq, char = 2, time = times.fishComplete }, ns.FirstComplete(state))
	end)

	it("keeps it through a fall below 100% and the rise back, which isn't a first", function()
		local records, times = story()
		local cut = {}
		for _, record in ipairs(records) do
			cut[#cut + 1] = record
			if record.time == times.stray then
				break
			end
		end
		local fallen, _, _, firstFallen = foldWithOracle(cut)
		local risen, _, _, firstRisen = foldWithOracle(records)

		-- At 90% after STRAY, and at 100% again after its tenth variety: the first stays FISH's tenth.
		assert.are.equal(90, ns.Measures(fallen, 0).ledgerCompletion.percent)
		assert.are.same(firstFallen, ns.FirstComplete(fallen))
		assert.are.equal(times.fishComplete, ns.FirstComplete(fallen).time)
		assert.are.equal(times.strayComplete, ns.MeasureRises(risen).ledgerCompletion)
		assert.are.same(firstRisen, ns.FirstComplete(risen))
		assert.are.equal(times.fishComplete, ns.FirstComplete(risen).time)
	end)

	it("has no first completion while Ledger completion stays below 100%", function()
		local records, times = story()
		local cut = {}
		for _, record in ipairs(records) do
			if record.time == times.fishComplete then
				break
			end
			cut[#cut + 1] = record
		end
		local state, _, _, first = foldWithOracle(cut)

		assert.is_nil(first)
		assert.is_nil(ns.FirstComplete(state))
		assert.are.equal(87, ns.Measures(state, 0).ledgerCompletion.percent)
	end)

	it("leaves every rise nil while nothing counted is caught", function()
		local log = newLog()
		local records = {
			log.skill(75),
			log.gotAway(LAKE),
			log.cast(LAKE, { { REMOVED, 3 }, { GONE_LEGEND } }),
			log.crest(""),
		}
		local state, at = foldWithOracle(records)

		assert.are.same({}, at)
		assert.are.same({}, ns.MeasureRises(state))
		assert.is_nil(ns.FirstComplete(state))
	end)

	it("folds to the same rises in every mode (LED-R3)", function()
		local records = story()
		local rebuilt = foldWithOracle(records, "rebuild")
		local live = foldWithOracle(records, "live")

		assert.are.same(rebuilt.rises, live.rises)
	end)

	it("matches the oracle over a long pseudo-random log, Catch by Catch", function()
		local pool = { FISH, PLAIN, PLAIN_2, STRAY, REMOVED, JUNK, LOOSE_JUNK, TROPHY, LEGEND, LEGEND_2, GONE_LEGEND }
		-- Park and Miller's generator, exact in a double: the same log every run.
		local seed = 12345
		local function random(n)
			seed = seed * 16807 % 2147483647
			return seed % n + 1
		end
		local log = newLog()
		local records = {}
		for _ = 1, 400 do
			if random(10) == 1 then
				records[#records + 1] = log.gotAway(LAKE)
			else
				local catches = {}
				for n = 1, random(3) do
					local itemID = pool[random(#pool)]
					local varieties = getItem(itemID).varieties
					catches[n] = { itemID, varieties and random(10) or nil }
				end
				records[#records + 1] = log.cast(random(3) == 1 and RIVER or LAKE, catches)
			end
		end
		local state, at, _, first = foldWithOracle(records)

		assert.are.same(at, ns.MeasureRises(state))
		assert.are.same(first, ns.FirstComplete(state))
		assert.is_number(at.ledgerCompletion)
		assert.is_number(at.speciesCaught)
		assert.is_number(at.legendsCaught)
	end)
end)

describe("the Angler Level read alone (LED-R159)", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns
	local world = ns.NewWorld(worldLookups())
	ns.world = world
	local lookups = { GetItem = getItem, MatchesConditions = loaded.env.Pagle.MatchesConditions, world = world }
	local fold = ns.NewLedgerFold(lookups)

	-- A state with XP of its own: the Skill Milestones up to 300 and a few first Catches.
	local function climbed()
		local log = newLog()
		local state = fold.reset()
		for _, record in ipairs({
			log.skill(300),
			log.cast(LAKE, { { PLAIN }, { JUNK } }),
			log.cast(RIVER, { { PLAIN_2 } }),
			log.cast(LAKE, { { LEGEND } }),
		}) do
			fold.apply(state, record, "rebuild")
		end
		return state
	end

	for _, total in ipairs({ 0, 1500, 250000 }) do
		it("equals Measures' Angler Level for the same state and Activity XP total " .. total, function()
			local state = climbed()

			assert.are.same(ns.Measures(state, total).anglerLevel, ns.AnglerLevel(state, total))
		end)
	end

	it("counts the total's Activity XP in the climb (LED-R37), and starts at level 1 with nothing", function()
		local state = climbed()

		assert.are.equal(ns.AnglerLevel(state, 0).xp + 1500, ns.AnglerLevel(state, 1500).xp)
		assert.is_true(ns.AnglerLevel(state, 1500).level > 1)
		assert.are.same({ prestige = 0, level = 1, xp = 0 }, ns.AnglerLevel(fold.reset(), 0))
	end)

	it("equals Measures' after a Prestige, its snapshot taken off the total (LED-R32, LED-R37)", function()
		local state = climbed()
		state.prestige, state.prestigeActivityXP = 1, 1000

		for _, total in ipairs({ 0, 900, 4000 }) do
			assert.are.same(ns.Measures(state, total).anglerLevel, ns.AnglerLevel(state, total))
		end
		assert.are.equal(1, ns.AnglerLevel(state, 4000).prestige)
	end)
end)
