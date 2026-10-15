-- spec/Pagle_TackleBoard/support.lua: the Tackle Board's specs run on FakePagle over the fixture catalogue, never the
-- shipped one, with the reset API and random source injected (M7 graph, conventions), and the fixture holds each case
-- its header promises, read through Core's own accessors (LOG-R55) as the board reads them (TKB-R30, TKB-R31,
-- TKB-R46).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DUROTAR, TELDRASSIL, DARKSHORE, AUBERDINE, BARRENS = 14, 141, 148, 442, 17
local NEEDLES, ASHENVALE, FERALAS, MOONGLADE = 400, 331, 357, 493
local ELWYNN, WESTFALL, STORMWIND = 12, 40, 1519
local MIGHTFISH, LARGE_MIGHTFISH = 13754, 13893

local SUB_COLLECTION = { junk = true, container = true, treasure = true, trophy = true }

-- The zones `fake` serves that are candidates for an Angler of `skill` (TKB-R30), by continent, ascending.
local function candidates(fake, skill)
	local Pagle, byContinent = fake.Pagle, {}
	for _, zone in fake.globals.ipairs(Pagle.GetZones()) do
		local area = Pagle.GetArea(zone)
		if area.hasData and area.skillBase and area.skillBase <= skill then
			byContinent[area.continent] = byContinent[area.continent] or {}
			table.insert(byContinent[area.continent], zone)
		end
	end
	return byContinent
end

-- A zone's eligible Species (TKB-R31), each with its representative item: { [species] = lowest itemID }.
local function eligibleSpecies(fake, zone)
	local Pagle, species = fake.Pagle, {}
	for _, entry in fake.globals.ipairs(Pagle.GetZoneCatches(zone)) do
		local item = Pagle.GetItem(entry.itemID)
		if
			not entry.gate
			and item
			and item.category == "fish"
			and not item.legend
			and not item.noise
			and not item.removed
		then
			species[item.species] = math.min(species[item.species] or math.huge, entry.itemID)
		end
	end
	return species
end

local function count(map)
	local n = 0
	for _ in pairs(map) do
		n = n + 1
	end
	return n
end

describe("the Tackle Board's spec support", function()
	it(
		"serves the fixture catalogue to Core's accessors before the board loads, and the board registers (DATA-R76, LOG-R55)",
		function()
			local loaded, fake = board.load()

			assert.are.equal("7ac7b0a47ac7b0a4", fake.Pagle.CONTENT_FINGERPRINT)
			assert.is_not_nil(loaded.ns.Module)
		end
	)

	it("serves a spec's own catalogue instead when given one (DATA-R76)", function()
		local catalogue = board.catalogue()
		catalogue.fingerprint = "0000000000000001"

		local _, fake = board.load(nil, { catalogue = catalogue })

		assert.are.equal("0000000000000001", fake.Pagle.CONTENT_FINGERPRINT)
	end)

	it("hands out a new fixture each time, so a spec's change stays its own (DATA-R76)", function()
		board.catalogue().areas[DUROTAR].skillBase = 300

		assert.are.equal(25, board.catalogue().areas[DUROTAR].skillBase)
	end)

	it(
		"puts the reset API and the random source at ns.api and ns.random before OnInitialize (TKB-R10, TKB-R30)",
		function()
			local api, random = board.resetAPI(), board.random(3)
			local seen
			local loaded = board.load(nil, {
				api = api,
				random = random,
				prepare = function(at)
					seen = { at.ns.api, at.ns.random, at.ns.Module }
				end,
			})

			assert.are.same({ api, random }, { seen[1], seen[2] })
			assert.is_nil(seen[3]) -- OnInitialize hadn't run yet
			assert.are.same({ api, random }, { loaded.ns.api, loaded.ns.random })
		end
	)

	it("leaves the shipped lore out of ns.L unless asked for it, so names read as IDs (TKB-R130)", function()
		-- M7 graph, open question 7: a name with no lore reads as its ID; the batch's text is the dev's to change (#244).
		local without = board.load().ns.L
		local with = board.load(nil, { lore = true }).ns.L

		assert.is_nil(rawget(without, "fly.murloc_nymph.name"))
		assert.is_nil(rawget(without, "boardtitle.flybox.text"))
		assert.is_nil(rawget(without, "boardgood.tackleboard.trackerframe.none.name"))
		assert.is_string(rawget(with, "fly.murloc_nymph.name"))
		assert.are.equal("Tackle Board", without.TITLE)
	end)

	it("reads the fixture Angler's skill, 150, after login (LOG-R27)", function()
		local _, fake = board.load()
		fake.login()

		board.readSkill(fake)

		assert.are.equal(150, fake.Pagle.GetAngler().bestBaseSkill)
	end)

	describe("the reset API (TKB-R10, TKB-R11)", function()
		it("puts the daily reset 15 minutes back and the weekly one on Tuesday 15:00 UTC, on a US realm", function()
			local _, fake = board.load()
			local api = board.resetAPI(fake)

			assert.are.equal(SERVER_TIME, api.GetServerTime())
			assert.are.equal(86400 - 900, api.C_DateAndTime.GetSecondsUntilDailyReset())
			assert.are.equal(2 * 86400 - 900, api.C_DateAndTime.GetSecondsUntilWeeklyReset())
			assert.are.same({ 8, 15 }, { api.GetGameTime() })
			assert.are.same(
				{ year = 2026, month = 10, monthDay = 11, weekday = 1, hour = 8, minute = 15 },
				api.C_DateAndTime.GetCurrentCalendarTime()
			)
			assert.are.equal(1, api.GetCurrentRegion())
		end)

		it("follows the fake's clock", function()
			local _, fake = board.load()
			local api = board.resetAPI(fake)

			fake.wait(86400 - 900)

			assert.are.equal(SERVER_TIME + 86400 - 900, api.GetServerTime())
			assert.are.equal(86400, api.C_DateAndTime.GetSecondsUntilDailyReset())
			assert.are.equal(86400, api.C_DateAndTime.GetSecondsUntilWeeklyReset())
			assert.are.same({ 8, 0 }, { api.GetGameTime() })
			assert.are.equal(2, api.C_DateAndTime.GetCurrentCalendarTime().weekday) -- Monday
		end)

		it("leaves out the calls a spec says are missing, for the fallback", function()
			local api = board.resetAPI(nil, {
				daily = false,
				weekly = function()
					return nil
				end,
				region = false,
			})

			assert.is_nil(api.C_DateAndTime.GetSecondsUntilDailyReset)
			assert.is_nil(api.C_DateAndTime.GetSecondsUntilWeeklyReset())
			assert.is_nil(api.GetCurrentRegion)
		end)
	end)

	describe("the random source (TKB-R30)", function()
		it("draws like math.random, in range", function()
			local random = board.random(42)
			for _ = 1, 200 do
				local r, m, mn = random(), random(3), random(5, 7)
				assert.is_true(r >= 0 and r < 1)
				assert.is_true(m >= 1 and m <= 3 and m == math.floor(m))
				assert.is_true(mn >= 5 and mn <= 7 and mn == math.floor(mn))
			end
		end)

		it("draws the same numbers from the same seed", function()
			local a, b = board.random(9), board.random(9)
			for _ = 1, 20 do
				assert.are.equal(a(1, 1000), b(1, 1000))
			end
		end)
	end)

	describe("the fixture", function()
		local fake = select(2, board.load())
		local Pagle = fake.Pagle

		it(
			"has 6 candidate zones on Kalimdor and 2 on the Eastern Kingdoms for the Angler (TKB-R30, TKB-R32)",
			function()
				local byContinent = candidates(fake, board.SKILL)

				assert.are.same({ DUROTAR, BARRENS, TELDRASSIL, DARKSHORE, ASHENVALE, NEEDLES }, byContinent[1])
				assert.are.same({ ELWYNN, WESTFALL }, byContinent[0])
			end
		)

		it("has a zone above the Angler, one without skillBase and one without data (TKB-R30)", function()
			assert.are.equal(205, Pagle.GetArea(FERALAS).skillBase)
			assert.is_nil(Pagle.GetArea(MOONGLADE).skillBase)
			assert.are.same({ 25, false }, { Pagle.GetArea(STORMWIND).skillBase, Pagle.GetArea(STORMWIND).hasData })
		end)

		it(
			"has zones with 2, exactly 3, 4–12 and 13 or more eligible Species, and one with none (TKB-R31, TKB-R32)",
			function()
				assert.are.equal(2, count(eligibleSpecies(fake, TELDRASSIL)))
				assert.are.equal(3, count(eligibleSpecies(fake, DUROTAR)))
				assert.are.equal(5, count(eligibleSpecies(fake, DARKSHORE)))
				assert.are.equal(4, count(eligibleSpecies(fake, WESTFALL)))
				assert.are.equal(13, count(eligibleSpecies(fake, BARRENS)))
				assert.are.equal(0, count(eligibleSpecies(fake, NEEDLES)))
			end
		)

		it("has a Species with entries under two item IDs, the lower listed second, in a subzone (TKB-R31)", function()
			assert.are.equal(MIGHTFISH, Pagle.GetItem(LARGE_MIGHTFISH).species)
			local order = {}
			for _, entry in fake.globals.ipairs(Pagle.GetZoneCatches(DARKSHORE)) do
				if entry.itemID == MIGHTFISH or entry.itemID == LARGE_MIGHTFISH then
					order[#order + 1] = { entry.itemID, entry.areaID }
				end
			end
			assert.are.same({ { LARGE_MIGHTFISH, DARKSHORE }, { MIGHTFISH, AUBERDINE } }, order)
			assert.are.equal(MIGHTFISH, eligibleSpecies(fake, DARKSHORE)[MIGHTFISH])
		end)

		it("has gated entries, a Legend, a Noise item, a removed item and a quest fish (TKB-R31, TKB-R35)", function()
			local gates = 0
			for _, zone in fake.globals.ipairs(Pagle.GetZones()) do
				for _, entry in fake.globals.ipairs(Pagle.GetZoneCatches(zone)) do
					gates = gates + (entry.gate and 1 or 0)
				end
			end
			assert.is_true(gates >= 3)
			assert.is_true(Pagle.GetItem(92001).legend)
			assert.is_true(Pagle.GetItem(2455).noise)
			assert.is_true(Pagle.GetItem(92003).removed)
			assert.are.equal("questFish", Pagle.GetItem(92002).category)
		end)

		it("has items of quality 2 and 3 (TKB-R34, TKB-R42)", function()
			assert.are.same({ 2, 2 }, { Pagle.GetItem(13757).quality, Pagle.GetItem(92031).quality })
			assert.are.same({ 3, 3 }, { Pagle.GetItem(92032).quality, Pagle.GetItem(92042).quality })
		end)

		it(
			"has at least 6 Sub-collection items across candidate zones, gated entries included (TKB-R32, TKB-R46)",
			function()
				local found, categories = {}, {}
				for _, zones in pairs(candidates(fake, board.SKILL)) do
					for _, zone in ipairs(zones) do
						for _, entry in fake.globals.ipairs(Pagle.GetZoneCatches(zone)) do
							local item = Pagle.GetItem(entry.itemID)
							if item and SUB_COLLECTION[item.category] and not item.noise and not item.removed then
								found[entry.itemID] = true
								categories[item.category] = true
							end
						end
					end
				end

				assert.are.equal(7, count(found))
				assert.are.same({ junk = true, container = true, treasure = true, trophy = true }, categories)
				assert.is_true(found[92022]) -- gated by night in Thousand Needles
				assert.is_nil(found[92042]) -- Feralas only, above the Angler
				assert.is_nil(found[92013]) -- Noise
				assert.is_nil(found[92023]) -- removed
			end
		)
	end)
end)
