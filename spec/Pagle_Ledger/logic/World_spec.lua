-- The Ledger's world (LED-R10–R12): the world index over a fixture catalogue, each collection's world, and Ledger
-- completion (LED-R70–R72) over hand-made states. ledger.md › The Ledger's world, Ledger completion, Data; LOG-R55;
-- DATA-R19, DATA-R26, DATA-R78. Hand-made lookups, no Core.

-- Items (LOG-R55): Species items, a Legend, Noise, `other`, trophies in two families, curios, and a removed Species.
local MACKEREL, SMALLFISH, NIGHTFISH, MIXED, CLUB = 6303, 6291, 13759, 13760, 13761
local LEGEND, LEGEND_2, NOISE, OTHER, UNKNOWN, REMOVED = 19803, 19805, 6358, 4592, 99999, 6299
local TROPHY_A, TROPHY_B, TROPHY_C, TROPHY_D = 13901, 13902, 13903, 13910
local JUNK, CHEST, TREASURE = 6309, 6307, 6308
-- On no list: a fish (only ever caught from pools, DATA-R28), a trophy, a treasure and a Legend.
local STRAY, TROPHY_E, TREASURE_2, LEGEND_3 = 6290, 13911, 6310, 19806

local function items()
	return {
		[MACKEREL] = fishRecord(MACKEREL),
		[SMALLFISH] = fishRecord(SMALLFISH, { category = "questFish", pool = true }),
		[NIGHTFISH] = fishRecord(NIGHTFISH),
		[MIXED] = fishRecord(MIXED),
		-- CLUB folds into MACKEREL's Species (DATA-R19).
		[CLUB] = fishRecord(MACKEREL, { pool = true }),
		[LEGEND] = fishRecord(LEGEND, { legend = true }),
		[LEGEND_2] = fishRecord(LEGEND_2, { legend = true }),
		[NOISE] = fishRecord(NOISE, { noise = true }),
		[REMOVED] = fishRecord(REMOVED, { removed = true }),
		[OTHER] = itemRecord("other"),
		[TROPHY_A] = itemRecord("trophy", { family = 1, weight = 19 }),
		[TROPHY_B] = itemRecord("trophy", { family = 1, weight = 22 }),
		[TROPHY_C] = itemRecord("trophy", { family = 1, weight = 22 }),
		[TROPHY_D] = itemRecord("trophy", { family = 2, weight = 8 }),
		[JUNK] = itemRecord("junk"),
		[CHEST] = itemRecord("container"),
		[TREASURE] = itemRecord("treasure"),
		[STRAY] = fishRecord(STRAY, { pool = true }),
		[TROPHY_E] = itemRecord("trophy", { family = 2, weight = 9 }),
		[TREASURE_2] = itemRecord("treasure"),
		[LEGEND_3] = fishRecord(LEGEND_3, { legend = true }),
	}
end

-- Hand-made projection states in ledger.md › Data's shape (LedgerState), with only what the world reads.
local T0 = SERVER_TIME - 700
local DATE = { year = 2026, month = 10, day = 11 }

local function emptyState()
	return { species = {}, items = {}, zones = {} }
end

-- A Species with `n` Catches (LedgerSpecies).
local function species(n)
	return { n = n, time = T0, char = 1, zone = 12, date = DATE, zones = { [12] = true }, windowsMet = {}, since = 0 }
end

-- A trophy, curio or Legend item's first Catch and count (LedgerFirst).
local function first(n)
	return { n = n, time = T0, char = 1, zone = 12, date = DATE }
end

-- A fished zone with its computed rank (LedgerZone; ticket #136 fills `rank`).
local function zoneState(rank)
	return { species = {}, families = {}, items = {}, junk = false, treasure = false, rank = rank }
end

-- Zones and subzones (LOG-R55): Elwynn with Goldshire, Westfall, Duskwood (no catch data) and Durotar (a list with
-- nothing the Ledger lists).
local ELWYNN, GOLDSHIRE, WESTFALL, DUSKWOOD, DUROTAR = 12, 87, 40, 10, 14

-- The night window's spec, shared by every entry it gates (DATA-R78), and the Extravaganza's.
local NIGHT = { time = { { 1260, 360 } } }
local EXTRAVAGANZA = { events = { 301 } }

-- The fixture's areas, in the shape of ns.catalogue.areas (DATA-R78).
local function areas()
	return {
		[ELWYNN] = areaRecord(0, {
			skillBase = 25,
			catches = {
				catchEntry(MACKEREL),
				catchEntry(NIGHTFISH, "night", NIGHT),
				catchEntry(MIXED, "night", NIGHT),
				catchEntry(LEGEND),
				catchEntry(NOISE),
				catchEntry(OTHER),
				catchEntry(UNKNOWN),
				catchEntry(TROPHY_A),
				catchEntry(JUNK),
			},
		}),
		[GOLDSHIRE] = areaRecord(ELWYNN, {
			catches = {
				catchEntry(MACKEREL),
				catchEntry(SMALLFISH, "night", NIGHT),
				catchEntry(CHEST),
				catchEntry(TROPHY_B),
			},
		}),
		[WESTFALL] = areaRecord(0, {
			skillBase = 55,
			catches = {
				catchEntry(SMALLFISH),
				catchEntry(NIGHTFISH, "night", NIGHT),
				catchEntry(MIXED),
				catchEntry(CLUB, "event.301", EXTRAVAGANZA),
				catchEntry(TROPHY_C),
				catchEntry(TROPHY_D),
			},
		}),
		[DUSKWOOD] = areaRecord(
			0,
			{ hasData = false, skillBase = 150, catches = { catchEntry(MACKEREL), catchEntry(LEGEND_2) } }
		),
		[DUROTAR] = areaRecord(0, { catches = { catchEntry(NOISE), catchEntry(OTHER), catchEntry(UNKNOWN) } }),
	}
end

-- Core's lookups over a catalogue's items and areas, as LOG-R55 hands them out: zones ascending, a zone's catches the
-- zone's then each subzone's, in areaID order, each with its areaID.
local function lookups(itemTable, areaTable)
	local zones = {}
	for areaID, record in pairs(areaTable) do
		if record.parent == 0 then
			zones[#zones + 1] = areaID
		end
	end
	table.sort(zones)
	local ids = {}
	for areaID in pairs(areaTable) do
		ids[#ids + 1] = areaID
	end
	table.sort(ids)
	local zoneCatches = {}
	for _, zone in ipairs(zones) do
		zoneCatches[zone] = {}
	end
	for _, areaID in ipairs(ids) do
		local zone = areaTable[areaID].parent == 0 and areaID or areaTable[areaID].parent
		for _, catch in ipairs(areaTable[areaID].catches) do
			local copy = { areaID = areaID }
			for key, value in pairs(catch) do
				copy[key] = value
			end
			table.insert(zoneCatches[zone], copy)
		end
	end
	return {
		GetItem = function(itemID)
			assert(itemID ~= 0, "item 0 is never looked up (LED-R5)")
			return itemTable[itemID]
		end,
		GetZones = function()
			return zones
		end,
		GetArea = function(areaID)
			return areaTable[areaID]
		end,
		GetZoneCatches = function(zone)
			return zoneCatches[zone]
		end,
	}
end

-- The item IDs of a zone list's entries, in order, as "<itemID>@<areaID>".
local function listed(list)
	local out = {}
	for i, catch in ipairs(list) do
		out[i] = catch.itemID .. "@" .. catch.areaID
	end
	return out
end

describe("The Ledger's world", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	describe("the world index (LED-R10)", function()
		local world
		before_each(function()
			world = ns.NewWorld(lookups(items(), areas()))
		end)

		it(
			"unions a zone's and its subzones' lists, keeping Species, trophy and curio entries only (LED-R10)",
			function()
				assert.are.same({
					MACKEREL .. "@" .. ELWYNN,
					NIGHTFISH .. "@" .. ELWYNN,
					MIXED .. "@" .. ELWYNN,
					TROPHY_A .. "@" .. ELWYNN,
					JUNK .. "@" .. ELWYNN,
					MACKEREL .. "@" .. GOLDSHIRE,
					SMALLFISH .. "@" .. GOLDSHIRE,
					CHEST .. "@" .. GOLDSHIRE,
					TROPHY_B .. "@" .. GOLDSHIRE,
				}, listed(world.zones[ELWYNN].list))
			end
		)

		it("charts the zones with catch data and a non-empty list, ascending (LED-R10)", function()
			-- Duskwood has a list but hasData false; Durotar has data but nothing the Ledger lists.
			assert.are.same({ ELWYNN, WESTFALL }, world.charted)
			assert.is_nil(world.zones[DUSKWOOD])
			assert.is_nil(world.zones[DUROTAR])
		end)

		it("lists the Legends of any zone's catches, charted or not, outside every zone list (LED-R10)", function()
			assert.are.same({ [LEGEND] = true, [LEGEND_2] = true }, world.legends)
		end)

		-- Each Species on a zone's list: "gated" or "ungated" there, with its windows there by ID.
		local function onLists(id)
			local out = {}
			for _, zone in ipairs(world.charted) do
				local here = world.zones[zone].species[id]
				if here then
					local windows = {}
					for window in pairs(here.windows) do
						windows[#windows + 1] = window
					end
					table.sort(windows)
					out[zone] = { here.gated and "gated" or "ungated", windows }
				end
			end
			return out
		end

		it("gives a Species night-gated in every zone the element window night, with its spec (LED-R10)", function()
			assert.are.same(
				{ [ELWYNN] = { "gated", { "night" } }, [WESTFALL] = { "gated", { "night" } } },
				onLists(NIGHTFISH)
			)
			assert.are.same(
				{ "night" },
				(function()
					local ids = {}
					for window in pairs(world.species[NIGHTFISH].elements) do
						ids[#ids + 1] = window
					end
					return ids
				end)()
			)
			-- The window's spec is the entries' shared gate (DATA-R78).
			assert.are.equal(NIGHT, world.species[NIGHTFISH].elements.night)
		end)

		it("gives a Species with one ungated entry anywhere no element window (LED-R10)", function()
			assert.are.same({ [ELWYNN] = { "gated", { "night" } }, [WESTFALL] = { "ungated", {} } }, onLists(MIXED))
			assert.is_nil(world.species[MIXED].elements)
		end)

		it("keeps a Species gated in one zone and ungated in another gated in the first only (LED-R10)", function()
			-- Small fish is night-gated in Goldshire, so in Elwynn, and ungated in Westfall.
			assert.are.same({ [ELWYNN] = { "gated", { "night" } }, [WESTFALL] = { "ungated", {} } }, onLists(SMALLFISH))
			assert.is_nil(world.species[SMALLFISH].elements)
		end)

		it("judges a Species by all of its items' entries, under its Species ID (LED-R10, DATA-R19)", function()
			-- Mackerel is ungated in Elwynn (twice); in Westfall only its folded item is listed, Extravaganza-gated.
			assert.are.same(
				{ [ELWYNN] = { "ungated", {} }, [WESTFALL] = { "gated", { "event.301" } } },
				onLists(MACKEREL)
			)
			assert.is_nil(world.zones[ELWYNN].species[CLUB])
			assert.is_nil(world.species[MACKEREL].elements)
		end)

		it("lists a Species' listed zones: the charted zones whose list it is on, ascending (LED-R10)", function()
			assert.are.same({ ELWYNN, WESTFALL }, world.species[MACKEREL].zones)
			assert.are.same({ ELWYNN, WESTFALL }, world.species[SMALLFISH].zones)
			-- Duskwood's Mackerel isn't charted, and no Legend, Noise or removed Species is in the index.
			assert.is_nil(world.species[LEGEND])
			assert.is_nil(world.species[NOISE])
			assert.is_nil(world.species[REMOVED])
		end)

		it(
			"marks a Species pool-associated where any of its items listed there is pooled (LED-R10, LED-R135)",
			function()
				assert.is_false(world.zones[ELWYNN].species[MACKEREL].pool)
				assert.is_true(world.zones[WESTFALL].species[MACKEREL].pool)
				assert.is_true(world.zones[ELWYNN].species[SMALLFISH].pool)
				assert.is_false(world.zones[WESTFALL].species[NIGHTFISH].pool)
			end
		)

		it("gives each family its listed weights and its heaviest, the lowest item ID on a tie (LED-R10)", function()
			-- Family 1: 19 lb in Elwynn, 22 lb in Goldshire and 22 lb in Westfall.
			assert.are.same({
				[1] = { weights = { TROPHY_A, TROPHY_B, TROPHY_C }, heaviest = TROPHY_B },
				[2] = { weights = { TROPHY_D }, heaviest = TROPHY_D },
			}, world.families)
		end)

		it("notes the families on each zone's list (LED-R10, LED-R50)", function()
			assert.are.same({ [1] = true }, world.zones[ELWYNN].families)
			assert.are.same({ [1] = true, [2] = true }, world.zones[WESTFALL].families)
		end)

		it("gives a zone its junk requirement, and its treasure one for a container or treasure (LED-R10)", function()
			assert.are.same({ true, true }, { world.zones[ELWYNN].junk, world.zones[ELWYNN].treasure })
			assert.are.same({ false, false }, { world.zones[WESTFALL].junk, world.zones[WESTFALL].treasure })
		end)

		it("keeps each zone's skill base, charted or not (LED-R10, LED-R131)", function()
			assert.are.same({ [ELWYNN] = 25, [WESTFALL] = 55, [DUSKWOOD] = 150 }, world.skillBase)
		end)

		it("lists the trophy and curio items of every charted zone list (LED-R10, LED-R11)", function()
			assert.are.same({
				[TROPHY_A] = true,
				[TROPHY_B] = true,
				[TROPHY_C] = true,
				[TROPHY_D] = true,
				[JUNK] = true,
				[CHEST] = true,
			}, world.items)
		end)
	end)

	describe("each collection's world (LED-R11, LED-R12)", function()
		local lookup, world
		before_each(function()
			lookup = lookups(items(), areas())
			world = ns.NewWorld(lookup)
		end)

		it("is what is listed when nothing is caught (LED-R11)", function()
			assert.are.same({
				species = { SMALLFISH, MACKEREL, NIGHTFISH, MIXED },
				junk = { JUNK },
				treasure = { CHEST },
				trophy = { TROPHY_A, TROPHY_B, TROPHY_C, TROPHY_D },
				legends = { LEGEND, LEGEND_2 },
			}, ns.CollectionWorlds(world, emptyState()))
		end)

		it("adds what was caught on no list, and never an uncaught unlisted item (LED-R11)", function()
			local state = emptyState()
			state.species[STRAY] = species(2)
			state.items[TROPHY_E] = first(1)
			state.items[TREASURE_2] = first(1)
			state.items[LEGEND_3] = first(1)

			local worlds = ns.CollectionWorlds(world, state)

			assert.are.same({ STRAY, SMALLFISH, MACKEREL, NIGHTFISH, MIXED }, worlds.species)
			-- The unlisted trophy joins the Trophy Room; the unlisted, uncaught TREASURE is nowhere.
			assert.are.same({ TROPHY_A, TROPHY_B, TROPHY_C, TROPHY_D, TROPHY_E }, worlds.trophy)
			assert.are.same({ CHEST, TREASURE_2 }, worlds.treasure)
			assert.are.same({ LEGEND, LEGEND_2, LEGEND_3 }, worlds.legends)
		end)

		it("keeps a caught removed Species in its world, for its page (LED-R12)", function()
			local state = emptyState()
			state.species[REMOVED] = species(4)

			assert.are.same(
				{ SMALLFISH, REMOVED, MACKEREL, NIGHTFISH, MIXED },
				ns.CollectionWorlds(world, state).species
			)
		end)
	end)

	describe("Ledger completion (LED-R70–R72)", function()
		local lookup, world
		before_each(function()
			lookup = lookups(items(), areas())
			world = ns.NewWorld(lookup)
		end)

		it("is 0 for an empty world, with nothing in total (LED-R70)", function()
			local empty = lookups(items(), {})

			assert.are.same({
				percent = 0,
				done = 0,
				total = 0,
				species = { done = 0, total = 0 },
				junk = { done = 0, total = 0 },
				treasure = { done = 0, total = 0 },
				trophy = { done = 0, total = 0 },
				zones = { done = 0, total = 0 },
				legends = { done = 0, total = 0 },
			}, ns.LedgerCompletion(ns.NewWorld(empty), emptyState()))
		end)

		it("matches the parts worked out by hand (LED-R70, LED-R71)", function()
			local state = emptyState()
			-- Species: 4 listed, the unlisted STRAY caught, REMOVED caught but removed: 3 of 5.
			state.species[MACKEREL] = species(12)
			state.species[NIGHTFISH] = species(1)
			state.species[STRAY] = species(1)
			state.species[REMOVED] = species(3)
			-- Trophy Room: 4 listed weights and the unlisted TROPHY_E caught: 2 of 5. Junk 1 of 1, Treasures 0 of 1.
			state.items[TROPHY_A] = first(2)
			state.items[TROPHY_E] = first(1)
			state.items[JUNK] = first(5)
			-- Zones: Elwynn Master, Westfall Local, Duskwood fished but uncharted (outside it): 1 of 2.
			state.zones[ELWYNN] = zoneState(5)
			state.zones[WESTFALL] = zoneState(3)
			state.zones[DUSKWOOD] = zoneState(0)
			-- Legends are outside it (LED-R63): one caught of two listed.
			state.items[LEGEND] = first(1)

			-- (3 + 2 + 1 + 0 + 1) of (5 + 5 + 1 + 1 + 2) = 7 of 14.
			assert.are.same({
				percent = 50,
				done = 7,
				total = 14,
				species = { done = 3, total = 5 },
				junk = { done = 1, total = 1 },
				treasure = { done = 0, total = 1 },
				trophy = { done = 2, total = 5 },
				zones = { done = 1, total = 2 },
				legends = { done = 1, total = 2 },
			}, ns.LedgerCompletion(world, state))
		end)

		-- A state with every Species, curio and trophy in the fixture's world caught and every charted zone Master.
		local function everything()
			local state = emptyState()
			for _, id in ipairs({ MACKEREL, SMALLFISH, NIGHTFISH, MIXED }) do
				state.species[id] = species(50)
			end
			for _, itemID in ipairs({ TROPHY_A, TROPHY_B, TROPHY_C, TROPHY_D, JUNK, CHEST }) do
				state.items[itemID] = first(1)
			end
			state.zones[ELWYNN] = zoneState(5)
			state.zones[WESTFALL] = zoneState(5)
			return state
		end

		it("reads 100 when every Species, curio, trophy and zone is done (LED-R70)", function()
			local completion = ns.LedgerCompletion(world, everything())

			assert.are.same({ 100, 12, 12 }, { completion.percent, completion.done, completion.total })
		end)

		it("reads below 100 while any one of them isn't done (LED-R70)", function()
			local missing = {
				function(state)
					state.species[MIXED] = nil
				end,
				function(state)
					state.items[CHEST] = nil
				end,
				function(state)
					state.items[TROPHY_C] = nil
				end,
				function(state)
					state.zones[WESTFALL].rank = 4
				end,
			}
			for _, remove in ipairs(missing) do
				local state = everything()
				remove(state)

				assert.are.equal(91, ns.LedgerCompletion(world, state).percent)
			end
		end)

		it("leaves a caught removed Species out of both sides of every count (LED-R12, LED-R71)", function()
			local state = everything()
			state.species[REMOVED] = species(9)

			local completion = ns.LedgerCompletion(world, state)

			assert.are.same({ done = 4, total = 4 }, completion.species)
			assert.are.equal(100, completion.percent)
		end)
	end)

	it("changes nothing when every catalogue confirmed flag flips (LED-R128)", function()
		-- Every confirmed, gateConfirmed and skillBaseConfirmed in the fixture, flipped.
		local flipped = areas()
		for _, record in pairs(flipped) do
			record.skillBaseConfirmed = not record.skillBaseConfirmed
			for _, catch in ipairs(record.catches) do
				catch.confirmed = not catch.confirmed
				if catch.window then
					catch.gateConfirmed = not catch.gateConfirmed
				end
			end
		end
		local lookup, flippedLookup = lookups(items(), areas()), lookups(items(), flipped)
		-- Only the areas differ: both worlds keep the one GetItem.
		flippedLookup.GetItem = lookup.GetItem
		local state = emptyState()
		state.species[MACKEREL] = species(1)
		state.zones[ELWYNN] = zoneState(5)

		local world, flippedWorld = ns.NewWorld(lookup), ns.NewWorld(flippedLookup)

		assert.are.same(world, flippedWorld)
		assert.are.same(ns.LedgerCompletion(world, state), ns.LedgerCompletion(flippedWorld, state))
	end)
end)
