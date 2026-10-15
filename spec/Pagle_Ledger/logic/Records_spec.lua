-- Simulated Size records (LED-R80–R85): each Species' and each Legend item's longest Catch by Pagle's own measure,
-- the `sizeRecord` a strictly longer Catch earns, and the size text. Hand-made records carrying `size` (LOG-R65) over
-- a fixture catalogue, folded by the Ledger's fold (LED-R3); ledger.md › Data and Tunables.

-- The fixture catalogue (LOG-R55). Spotted Yellowtail's two items share one Species (4603), as the catalogue folds them.
local MACKEREL, YELLOWTAIL, YELLOWTAIL_2, LEGEND = 6303, 4603, 6887, 19803
local TROPHY, JUNK = 13901, 6309
local ITEMS = {
	[MACKEREL] = { category = "fish", species = MACKEREL, legend = false, noise = false, removed = false, pool = false },
	[YELLOWTAIL] = {
		category = "fish",
		species = YELLOWTAIL,
		legend = false,
		noise = false,
		removed = false,
		pool = false,
	},
	[YELLOWTAIL_2] = {
		category = "fish",
		species = YELLOWTAIL,
		legend = false,
		noise = false,
		removed = false,
		pool = false,
	},
	[LEGEND] = { category = "fish", species = LEGEND, legend = true, noise = false, removed = false, pool = false },
	[TROPHY] = {
		category = "trophy",
		family = 1,
		weight = 19,
		legend = false,
		noise = false,
		removed = false,
		pool = false,
	},
	[JUNK] = { category = "junk", legend = false, noise = false, removed = false, pool = false },
}

local ELWYNN, WESTFALL = 12, 40
local T0 = 1791731000
local DAY = 86400
-- The Size bands (LOG-R67): 3 Hefty, 5 Monster.
local HEFTY, MONSTER = 3, 5

---@param itemID integer
---@return PagleItem?
local function getItem(itemID)
	return ITEMS[itemID]
end

-- Records the way the Catch log hands them out (LOG-R42), with seq, entry IDs and Catch IDs in order (LOG-R13).
local function newLog()
	local seq = 0
	local log = {}

	--- A caught Cast at `time` in `zone` by character `char` (1 by default): one Catch per `{ itemID, length?, band? }`,
	--- quantity 1, carrying `size` when it has a length (LOG-R65).
	---@param time integer
	---@param zone integer
	---@param catches { [1]: integer, [2]: integer?, [3]: integer? }[]
	---@param char integer?
	---@return PagleCast
	function log.cast(time, zone, catches, char)
		seq = seq + 1
		local id = "Player-4618-0A1B2C3D-" .. time .. "-" .. seq
		local items = {}
		for n, catch in ipairs(catches) do
			items[n] = { n = n, itemID = catch[1], quantity = 1, catchId = id .. ":" .. n }
			if catch[2] then
				items[n].size = { length = catch[2], band = catch[3] or HEFTY }
			end
		end
		return {
			seq = seq,
			id = id,
			kind = "cast",
			char = char or 1,
			time = time,
			outcome = "caught",
			session = "s",
			conditions = {
				time = time,
				zone = zone,
				subzone = 0,
				minute = 0,
				date = { year = 2026, month = 10, day = 1, weekday = 5 },
				events = {},
				auras = {},
			},
			items = items,
		}
	end

	return log
end

describe("Simulated Size records", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local world = ns.NewWorld({
		GetItem = getItem,
		GetZones = function()
			return {}
		end,
		GetArea = function()
			return { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = true, catches = {} }
		end,
		GetZoneCatches = function()
			return {}
		end,
	})

	local fold, log
	before_each(function()
		fold = ns.NewLedgerFold({
			GetItem = getItem,
			MatchesConditions = function()
				return false
			end,
			world = world,
		})
		log = newLog()
	end)

	-- A fresh state (or `state`) with every record applied live; returns it and every achievement, in order.
	local function applyAll(records, state)
		state = state or fold.reset()
		local earned = {}
		for _, record in ipairs(records) do
			fold.apply(state, record, "live", earned)
		end
		return state, earned
	end

	-- The achievements of `kind` in `earned`, in order.
	local function ofKind(earned, kind)
		local list = {}
		for _, achievement in ipairs(earned) do
			if achievement.kind == kind then
				list[#list + 1] = achievement
			end
		end
		return list
	end

	-- `n` Casts of one sized Catch of `itemID` each, a minute apart from `time`, all `length` long.
	local function casts(n, time, itemID, length)
		local records = {}
		for i = 1, n do
			records[i] = log.cast(time + i * 60, ELWYNN, { { itemID, length } })
		end
		return records
	end

	describe("the record (LED-R80, LED-R81)", function()
		it("sets a Species' record at its first sized Catch, silently, with since 0 (LED-R80, LED-R81)", function()
			local first = log.cast(T0, ELWYNN, { { MACKEREL, 342, HEFTY } }, 2)
			local state, earned = applyAll({ first })

			assert.are.same({
				length = 342,
				band = HEFTY,
				catchId = first.id .. ":1",
				time = T0,
				char = 2,
				zone = ELWYNN,
			}, state.species[MACKEREL].record)
			assert.are.equal(0, state.species[MACKEREL].since)
			assert.are.same({}, ofKind(earned, "sizeRecord"))
		end)
	end)

	describe("beating it (LED-R82)", function()
		it(
			"gives a strictly longer Catch one sizeRecord with old and new in millimetres and its size, and the record",
			function()
				local longer = log.cast(T0 + 120, WESTFALL, { { MACKEREL, 343, HEFTY } })
				local state, earned = applyAll({ log.cast(T0, ELWYNN, { { MACKEREL, 342 } }), longer })

				assert.are.same({
					{
						kind = "sizeRecord",
						cast = longer.id,
						coins = 0,
						itemID = MACKEREL,
						old = 342,
						new = 343,
						flair = false,
						size = { length = 343, band = HEFTY },
					},
				}, ofKind(earned, "sizeRecord"))
				assert.are.same({
					length = 343,
					band = HEFTY,
					catchId = longer.id .. ":1",
					time = T0 + 120,
					char = 1,
					zone = WESTFALL,
				}, state.species[MACKEREL].record)
				assert.are.equal(0, state.species[MACKEREL].since)
			end
		)

		it(
			"gives an equal Catch nothing and keeps the earlier Catch as the record, one more since (LED-R80)",
			function()
				local first = log.cast(T0, ELWYNN, { { MACKEREL, 342 } })
				local state, earned = applyAll({ first, log.cast(T0 + 60, ELWYNN, { { MACKEREL, 342 } }) })

				assert.are.same({}, ofKind(earned, "sizeRecord"))
				assert.are.equal(first.id .. ":1", state.species[MACKEREL].record.catchId)
				assert.are.equal(1, state.species[MACKEREL].since)
			end
		)

		it("carries the rare-record flair when 50 Catches of the Species came between the two (Tunables)", function()
			local records = { log.cast(T0, ELWYNN, { { MACKEREL, 342 } }) }
			for _, record in ipairs(casts(50, T0, MACKEREL, 300)) do
				records[#records + 1] = record
			end
			records[#records + 1] = log.cast(T0 + DAY, ELWYNN, { { MACKEREL, 400 } })
			local state, earned = applyAll(records)

			local beaten = ofKind(earned, "sizeRecord")
			assert.are.equal(1, #beaten)
			assert.is_true(beaten[1].flair)
			assert.are.same({ 342, 400 }, { beaten[1].old, beaten[1].new })
			assert.are.equal(0, state.species[MACKEREL].since)
		end)

		it("counts unsized Catches toward the flair's 50 too (LED-R80, LED-R82)", function()
			local records = { log.cast(T0, ELWYNN, { { MACKEREL, 342 } }) }
			for i = 1, 50 do
				records[#records + 1] = log.cast(T0 + i * 60, ELWYNN, { { MACKEREL } })
			end
			records[#records + 1] = log.cast(T0 + DAY, ELWYNN, { { MACKEREL, 400 } })
			local _, earned = applyAll(records)

			assert.is_true(ofKind(earned, "sizeRecord")[1].flair)
		end)

		it("carries no flair when 49 Catches came between the two (LED-R82)", function()
			local records = { log.cast(T0, ELWYNN, { { MACKEREL, 342 } }) }
			for _, record in ipairs(casts(49, T0, MACKEREL, 300)) do
				records[#records + 1] = record
			end
			local state = applyAll(records)
			assert.are.equal(49, state.species[MACKEREL].since)
			local _, earned = applyAll({ log.cast(T0 + DAY, ELWYNN, { { MACKEREL, 400 } }) }, state)

			assert.are.same({
				{
					kind = "sizeRecord",
					cast = earned[1].cast,
					coins = 0,
					itemID = MACKEREL,
					old = 342,
					new = 400,
					flair = false,
					size = { length = 400, band = HEFTY },
				},
			}, ofKind(earned, "sizeRecord"))
		end)

		it("keeps one record per Species across its items, naming the item caught (LED-R80)", function()
			local state, earned = applyAll({
				log.cast(T0, ELWYNN, { { YELLOWTAIL, 600 } }),
				log.cast(T0 + 60, ELWYNN, { { YELLOWTAIL_2, 650 } }),
			})

			assert.are.equal(650, state.species[YELLOWTAIL].record.length)
			assert.is_nil(state.species[YELLOWTAIL_2])
			assert.are.same({ YELLOWTAIL_2 }, { ofKind(earned, "sizeRecord")[1].itemID })
		end)

		it("compares two Catches of one Cast in item order (LED-R80)", function()
			local both = log.cast(T0, ELWYNN, { { MACKEREL, 300 }, { MACKEREL, 350 } })
			local state, earned = applyAll({ both })

			assert.are.same(
				{ both.id .. ":2", 0 },
				{ state.species[MACKEREL].record.catchId, state.species[MACKEREL].since }
			)
			assert.are.same({ 300, 350 }, { ofKind(earned, "sizeRecord")[1].old, ofKind(earned, "sizeRecord")[1].new })
		end)
	end)

	describe("which Catches count (LED-R80, LOG-R65)", function()
		it("keeps a Legend's record on its items entry, never as a Species (LED-R80, ledger.md › Data)", function()
			local first = log.cast(T0, ELWYNN, { { LEGEND, 2100, HEFTY } })
			local longer = log.cast(T0 + 60, ELWYNN, { { LEGEND, 2300, HEFTY } })
			local state, earned = applyAll({ first, log.cast(T0 + 30, ELWYNN, { { LEGEND, 2000 } }), longer })

			assert.are.same({ 2300, longer.id .. ":1", 0 }, {
				state.items[LEGEND].record.length,
				state.items[LEGEND].record.catchId,
				state.items[LEGEND].since,
			})
			assert.are.same({}, state.species)
			assert.are.same({
				{
					kind = "sizeRecord",
					cast = longer.id,
					coins = 0,
					itemID = LEGEND,
					old = 2100,
					new = 2300,
					flair = false,
					size = { length = 2300, band = HEFTY },
				},
			}, ofKind(earned, "sizeRecord"))
		end)

		it("never makes a record from a trophy or junk Catch, even one carrying a size (LED-R80, LOG-R65)", function()
			local state, earned = applyAll({
				log.cast(T0, ELWYNN, { { TROPHY, 500 }, { JUNK, 200 } }),
				log.cast(T0 + 60, ELWYNN, { { TROPHY, 900 }, { JUNK, 900 } }),
			})

			assert.is_nil(state.items[TROPHY].record)
			assert.is_nil(state.items[JUNK].record)
			assert.is_nil(state.items[TROPHY].since)
			assert.are.same({}, ofKind(earned, "sizeRecord"))
		end)

		it("counts a Catch without a size in since once a record exists, never setting one (LED-R80)", function()
			local state = applyAll({
				log.cast(T0, ELWYNN, { { MACKEREL } }),
				log.cast(T0 + 60, ELWYNN, { { MACKEREL, 342 } }),
				log.cast(T0 + 120, ELWYNN, { { MACKEREL } }),
			})

			assert.are.same({ 342, 1, 3 }, {
				state.species[MACKEREL].record.length,
				state.species[MACKEREL].since,
				state.species[MACKEREL].n,
			})
			local unsized = applyAll({ log.cast(T0, ELWYNN, { { MACKEREL } }) })
			assert.is_nil(unsized.species[MACKEREL].record)
			assert.is_nil(unsized.species[MACKEREL].since)
		end)
	end)

	describe("nothing else (LED-R83, LED-R85)", function()
		it("gives a Monster band Catch that isn't longer nothing (LED-R83)", function()
			local state, earned = applyAll({
				log.cast(T0, ELWYNN, { { MACKEREL, 540, MONSTER } }),
				log.cast(T0 + 60, ELWYNN, { { MACKEREL, 530, MONSTER } }),
			})

			assert.are.same({}, ofKind(earned, "sizeRecord"))
			assert.are.same({ 540, 1 }, { state.species[MACKEREL].record.length, state.species[MACKEREL].since })
		end)

		it("adds no XP, Coins or achievement beyond the sizeRecord (LED-R83, LED-R46)", function()
			-- The same two Casts with and without sizes: the only difference is the record and its sizeRecord.
			local plain, plainEarned = applyAll({
				log.cast(T0, ELWYNN, { { MACKEREL } }),
				log.cast(T0 + 60, ELWYNN, { { MACKEREL } }),
			})
			local sized, earned = applyAll({
				log.cast(T0, ELWYNN, { { MACKEREL, 300, 2 } }),
				log.cast(T0 + 60, ELWYNN, { { MACKEREL, 540, MONSTER } }),
			})

			assert.are.same({ plain.xp, plain.coins, plain.catches }, { sized.xp, sized.coins, sized.catches })
			assert.are.equal(#plainEarned + 1, #earned)
			-- Stars count from Catches only (LED-R46): the records change none.
			assert.are.same(ns.SpeciesStars(world, plain, MACKEREL), ns.SpeciesStars(world, sized, MACKEREL))
		end)

		it("compares millimetres, whatever band the Catches fall in (LED-R85)", function()
			-- A longer Catch in a lower band (a retuned typical length can do it) still beats the record.
			local _, earned = applyAll({
				log.cast(T0, ELWYNN, { { MACKEREL, 340, MONSTER } }),
				log.cast(T0 + 60, ELWYNN, { { MACKEREL, 341, 1 } }),
			})

			assert.are.same({ 340, 341 }, { ofKind(earned, "sizeRecord")[1].old, ofKind(earned, "sizeRecord")[1].new })
		end)
	end)

	describe("the size text (LED-R81, LOG-R69)", function()
		local fake = newFakePagle()

		it('reads "Hefty · 13.5 in" with inches set (LED-R81)', function()
			fake.profile.lengthUnit = "in"
			assert.are.equal(
				"Hefty · 13.5 in",
				ns.SizeText({ length = 342, band = HEFTY }, fake.Pagle.SIZE_BANDS, fake.Pagle.FormatLength)
			)
		end)

		it("reads the length in the Angler's unit, and the band's name (LOG-R69, LOG-R67)", function()
			fake.profile.lengthUnit = "cm"
			assert.are.equal(
				"Monster · 54.0 cm",
				ns.SizeText({ length = 540, band = MONSTER }, fake.Pagle.SIZE_BANDS, fake.Pagle.FormatLength)
			)
		end)

		it("is nil for a Catch without a size (LED-R81)", function()
			assert.is_nil(ns.SizeText(nil, fake.Pagle.SIZE_BANDS, fake.Pagle.FormatLength))
		end)
	end)
end)
