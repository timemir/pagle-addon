-- The Ledger's fold (LED-R3): one record at a time into the Ledger's state, and the achievements each earns. Hand-made
-- records over a fixture catalogue; ledger.md › Classifying a Catch, XP and Fresh Water, Angler Level, Skill and Catch
-- Milestones, Pagle Coins, Data › Projection, Tunables.

-- The fixture catalogue: what GetItem returns for each item ID (LOG-R55). Unlisted IDs are Uncharted.
local MACKEREL, SMALLFISH, LEGEND, NOISE = 6303, 6291, 19803, 6358
-- Two more Legends: one listed beside LEGEND, and a removed one, on no list (LED-R10, LED-R12, DATA-R26).
local LEGEND_2, REMOVED_LEGEND = 19805, 19806
-- A Legend flagged on a trophy item of family 2, heavier than its weights: still a Legend (LED-R5).
local TROPHY_LEGEND = 19807
local TROPHY, JUNK, CHEST, TREASURE, OTHER, UNCHARTED = 13901, 6309, 6307, 6308, 4592, 99999
-- One trophy family's three weights, in pounds (LED-R61).
local TROPHY40, TROPHY60, TROPHY50 = 13876, 13877, 13878
local ITEMS = {
	[MACKEREL] = fishRecord(MACKEREL),
	[SMALLFISH] = fishRecord(SMALLFISH, { category = "questFish", pool = true }),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
	[LEGEND_2] = fishRecord(LEGEND_2, { legend = true }),
	[REMOVED_LEGEND] = fishRecord(REMOVED_LEGEND, { legend = true, removed = true }),
	[TROPHY_LEGEND] = itemRecord("trophy", { family = 2, weight = 90, legend = true }),
	[NOISE] = fishRecord(NOISE, { noise = true }),
	[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
	[TROPHY40] = itemRecord("trophy", { family = 2, weight = 40 }),
	[TROPHY60] = itemRecord("trophy", { family = 2, weight = 60 }),
	[TROPHY50] = itemRecord("trophy", { family = 2, weight = 50 }),
	[JUNK] = itemRecord("junk"),
	[CHEST] = itemRecord("container"),
	[TREASURE] = itemRecord("treasure"),
	[OTHER] = itemRecord("other"),
}

local ELWYNN, WESTFALL = 12, 40
local T0 = SERVER_TIME - 700
local HOUR = 3600

local getItem = itemLookup(ITEMS)

local DAY = 86400

-- A Cast's realm date (LOG-R49), made up for the fixture: T0 falls on 1 October 2026, one day later each 24 hours.
---@param time integer
local function dateOf(time)
	local day = 1 + math.floor((time - T0) / DAY)
	return { year = 2026, month = 10, day = day, weekday = 1 + (day + 3) % 7 }
end

-- Builds records the way the Catch log hands them out (LOG-R42), with seq and entry IDs in order.
local function newLog()
	local seq = 0
	local log = {}

	---@return integer, string
	local function header(time)
		seq = seq + 1
		return seq, "Player-4618-0A1B2C3D-" .. time .. "-" .. seq
	end

	--- A caught Cast at `time` in `zone`, one Catch per item ID (quantity 1), in item order.
	---@param time integer
	---@param zone integer
	---@param itemIDs integer[]
	---@param char integer?
	---@return PagleCast
	function log.cast(time, zone, itemIDs, char)
		local s = header(time)
		return castRecord({
			seq = s,
			time = time,
			zone = zone,
			items = itemIDs,
			char = char,
			minute = 0,
			date = dateOf(time),
		})
	end

	--- A got-away Cast (LOG-R7).
	function log.gotAway(time, zone)
		local record = log.cast(time, zone, {})
		record.outcome = "gotAway"
		return record
	end

	--- A Skill Reading (LOG-R31).
	---@param time integer
	---@param rank integer
	---@param char integer?
	---@return PagleSkillReading
	function log.skill(time, rank, char)
		local s, id = header(time)
		return { seq = s, id = id, kind = "skill", char = char or 1, time = time, rank = rank, max = 300, mod = 0 }
	end

	--- Any other kind of entry (LED-R2 ignores it).
	function log.other(time, kind)
		local s, id = header(time)
		return { seq = s, id = id, kind = kind, char = 1, time = time }
	end

	return log
end

describe("The Ledger's fold", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns

	-- The world index (LED-R10) over the fixture: Mackerel and Smallfish ungated in three zones, so a spec here
	-- reaches ★★ only with three zones (LED-R45; logic/Stars_spec.lua covers the stars). None of them is a zone the
	-- specs here fish in, so no Catch here earns a Zone Mastery rank (LED-R50; logic/ZoneMastery_spec.lua has those).
	-- LEGEND and LEGEND_2 are listed there too, which keeps them off the zone lists but in the Legends' world (LED-R10).
	local world = ns.NewWorld({
		GetItem = getItem,
		GetZones = function()
			return { 1, 3, 10 }
		end,
		GetArea = function()
			return { parent = 0, continent = 0, hasData = true, skillBaseConfirmed = true, catches = {} }
		end,
		GetZoneCatches = function()
			return {
				{ itemID = MACKEREL, confirmed = true },
				{ itemID = SMALLFISH, confirmed = true },
				{ itemID = LEGEND, confirmed = true },
				{ itemID = LEGEND_2, confirmed = true },
			}
		end,
	})

	-- The fold's lookups over `get` (the fixture's GetItem by default), Core's MatchesConditions and the world.
	local function lookups(get)
		return { GetItem = get or getItem, MatchesConditions = loaded.env.Pagle.MatchesConditions, world = world }
	end

	local fold, log
	before_each(function()
		fold = ns.NewLedgerFold(lookups())
		log = newLog()
	end)

	-- A fresh state with every record applied in "live" mode; returns it and every achievement, in order.
	local function applyAll(records, mode, state)
		return applyLive(fold, records, state, mode)
	end

	-- The kinds of a list of achievements, in order.
	---@param earned LedgerAchievement[]
	---@return string[]
	local function kinds(earned)
		local list = {}
		for i, achievement in ipairs(earned) do
			list[i] = achievement.kind
		end
		return list
	end

	describe("classifying a Catch (LED-R5)", function()
		it(
			"never counts a Legend as a Species, though its item is a fish with a Species ID (LED-R4, LED-R5)",
			function()
				local state, earned = applyAll({ log.cast(T0, ELWYNN, { LEGEND }) })

				assert.are.same({}, state.species)
				assert.are.same({}, state.zones[ELWYNN].species)
				assert.are.same({ "legend", "levelUp" }, kinds(earned))
			end
		)

		it("gives Noise, other and item 0 the base only (LED-R5, LED-R196)", function()
			local state, earned = applyAll({ log.cast(T0, ELWYNN, { NOISE, OTHER, 0 }) })

			assert.are.equal(3, state.catches)
			assert.are.same({}, state.species)
			assert.are.same({}, state.items)
			assert.are.same({}, state.uncharted)
			assert.are.same({}, earned)
			-- Catch XP for each, doubled under Fresh Water, and the first Catch in the zone (LED-R20, LED-R22).
			assert.are.equal(3 * 20 + 200, state.xp)
			assert.is_truthy(state.zones[ELWYNN])
		end)

		it(
			"classifies first match wins: item 0, Uncharted, Noise, Legend, Species, trophy, curio, other (LED-R5)",
			function()
				assert.are.equal("zero", ns.ClassifyCatch(0, nil))
				assert.are.equal("uncharted", ns.ClassifyCatch(UNCHARTED, nil))
				assert.are.equal("noise", ns.ClassifyCatch(NOISE, ITEMS[NOISE]))
				-- Noise comes first, even for an item flagged both (DATA-R16 forbids it in the data).
				local both = { category = "other", legend = true, noise = true, removed = false, pool = false }
				assert.are.equal("noise", ns.ClassifyCatch(NOISE, both))
				assert.are.equal("legend", ns.ClassifyCatch(LEGEND, ITEMS[LEGEND]))
				assert.are.equal("legend", ns.ClassifyCatch(REMOVED_LEGEND, ITEMS[REMOVED_LEGEND]))
				-- Before every category: a Legend flagged on a trophy item is still a Legend.
				assert.are.equal("legend", ns.ClassifyCatch(TROPHY_LEGEND, ITEMS[TROPHY_LEGEND]))
				assert.are.equal("species", ns.ClassifyCatch(MACKEREL, ITEMS[MACKEREL]))
				assert.are.equal("species", ns.ClassifyCatch(SMALLFISH, ITEMS[SMALLFISH]))
				assert.are.equal("trophy", ns.ClassifyCatch(TROPHY, ITEMS[TROPHY]))
				assert.are.equal("curio", ns.ClassifyCatch(JUNK, ITEMS[JUNK]))
				assert.are.equal("curio", ns.ClassifyCatch(CHEST, ITEMS[CHEST]))
				assert.are.equal("curio", ns.ClassifyCatch(TREASURE, ITEMS[TREASURE]))
				assert.are.equal("other", ns.ClassifyCatch(OTHER, ITEMS[OTHER]))
			end
		)
	end)

	describe("the Uncharted list (LED-R64, LED-R196)", function()
		it("lists an Uncharted item by Catches, first Catch and Catches per zone, zone 0 left out (LED-R64)", function()
			local first = log.cast(T0, ELWYNN, { UNCHARTED }, 2)
			local state, earned = applyAll({
				first,
				log.cast(T0 + DAY, WESTFALL, { UNCHARTED }),
				log.cast(T0 + 2 * DAY, 0, { UNCHARTED }),
				log.cast(T0 + 3 * DAY, ELWYNN, { UNCHARTED }),
			})

			assert.are.same({
				[UNCHARTED] = {
					n = 4,
					time = T0,
					char = 2,
					zone = ELWYNN,
					date = { year = 2026, month = 10, day = 1 },
					zones = { [ELWYNN] = 2, [WESTFALL] = 1 },
				},
			}, state.uncharted)
			-- One Nod's achievement, at its first Catch (LED-R64, LED-R97), paying no Coins (LED-R88).
			assert.are.same({ { kind = "uncharted", cast = first.id, coins = 0, itemID = UNCHARTED } }, earned)
			assert.are.equal(0, state.coins)
		end)

		it("gives an Uncharted Catch the base and nothing else (LED-R5, LED-R196)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { UNCHARTED }) })

			assert.are.equal(1, state.catches)
			assert.are.equal(20 + 200, state.xp)
			assert.are.same({}, state.species)
			assert.are.same({}, state.items)
		end)

		it("credits every earlier Catch as its class once a release classifies it, on a rebuild (LED-R196)", function()
			local records = {
				log.cast(T0, ELWYNN, { UNCHARTED }),
				log.cast(T0 + DAY, WESTFALL, { UNCHARTED, UNCHARTED }),
			}
			local _, before = applyAll(records, "rebuild")
			assert.are.same({ "uncharted" }, kinds(before))

			-- The next release knows the item: a junk item (LOG-R96). The rebuild runs over the new catalogue.
			local released = ns.NewLedgerFold(lookups(function(itemID)
				if itemID == UNCHARTED then
					return itemRecord("junk")
				end
				return getItem(itemID)
			end))
			local state, scratch = released.reset(), {}
			for _, record in ipairs(records) do
				released.apply(state, record, "rebuild", scratch)
			end

			assert.are.same({}, state.uncharted)
			assert.are.same(
				{ n = 3, time = T0, char = 1, zone = ELWYNN, date = { year = 2026, month = 10, day = 1 } },
				state.items[UNCHARTED]
			)
			-- Its achievements go to the scratch list, with the Cast that earned them (LED-R98).
			assert.are.same({ kind = "newCurio", cast = records[1].id, coins = 5, itemID = UNCHARTED }, scratch[1])
			assert.are.same({ "newCurio" }, kinds(scratch))
			assert.are.equal(5, state.coins)
		end)

		it("never lists item 0 (LED-R64, LED-R196, LOG-R96)", function()
			local state, earned = applyAll({ log.cast(T0, ELWYNN, { 0 }), log.cast(T0 + 60, 0, { 0 }) })

			assert.are.same({}, state.uncharted)
			assert.are.same({}, earned)
			assert.are.equal(2, state.catches)
		end)
	end)

	describe("collections (LED-R60, LED-R61)", function()
		it(
			"gives a junk item's first Catch 150 XP, 5 Coins and newCurio, its second the base only (LED-R20, LED-R88)",
			function()
				local first = log.cast(T0, 0, { JUNK })
				local state, earned = applyAll({ first })

				assert.are.equal(20 + 150, state.xp)
				assert.are.equal(5, state.coins)
				assert.are.same({ { kind = "newCurio", cast = first.id, coins = 5, itemID = JUNK } }, earned)

				local xp = state.xp
				local _, again = applyAll({ log.cast(T0 + 60, 0, { JUNK }) }, "live", state)
				assert.are.equal(xp + 20, state.xp)
				assert.are.equal(5, state.coins)
				assert.are.same({}, again)
			end
		)

		it("collects container and treasure items as curios too, by item ID (LED-R60, LED-R20)", function()
			local cast = log.cast(T0, 0, { CHEST, TREASURE, CHEST })
			local state, earned = applyAll({ cast })

			assert.are.equal(3 * 20 + 2 * 150, state.xp)
			assert.are.equal(10, state.coins)
			assert.are.same({ "newCurio", "newCurio" }, kinds(earned))
			assert.are.same({ CHEST, TREASURE }, { earned[1].itemID, earned[2].itemID })
			assert.are.same({ 2, 1 }, { state.items[CHEST].n, state.items[TREASURE].n })
		end)

		it("keeps each trophy and curio item's Catches and first Catch (LED-R60, ledger.md › Data)", function()
			local state = applyAll({
				log.cast(T0, ELWYNN, { TROPHY }, 2),
				log.cast(T0 + DAY, WESTFALL, { TROPHY, JUNK }),
			})

			assert.are.same({
				[TROPHY] = { n = 2, time = T0, char = 2, zone = ELWYNN, date = { year = 2026, month = 10, day = 1 } },
				[JUNK] = {
					n = 1,
					time = T0 + DAY,
					char = 1,
					zone = WESTFALL,
					date = { year = 2026, month = 10, day = 2 },
				},
			}, state.items)
		end)

		it(
			"rules a family's heavier weight from the heaviest landed: 40 none, 60 from 40, 50 none (LED-R61)",
			function()
				local c40 = log.cast(T0, ELWYNN, { TROPHY40 })
				local c60 = log.cast(T0 + 60, ELWYNN, { TROPHY60 })
				local c50 = log.cast(T0 + 120, ELWYNN, { TROPHY50 })
				local state, earned = applyAll({ c40, c60, c50 })

				assert.are.same({
					{ kind = "trophyWeight", cast = c40.id, coins = 5, itemID = TROPHY40, family = 2 },
					{
						kind = "trophyWeight",
						cast = c60.id,
						coins = 5,
						itemID = TROPHY60,
						family = 2,
						old = 40,
						new = 60,
					},
					{ kind = "trophyWeight", cast = c50.id, coins = 5, itemID = TROPHY50, family = 2 },
				}, earned)
				-- Each a new trophy weight: 100 XP and 5 Coins (LED-R20, LED-R88), with the zone's first Catch.
				assert.are.equal(3 * 20 + 3 * 100 + 200, state.xp)
				assert.are.equal(15, state.coins)
			end
		)

		it("rules no weight against another family's, nor a weight landed again (LED-R61)", function()
			local state, earned = applyAll({ log.cast(T0, 0, { TROPHY, TROPHY40, TROPHY }) })

			assert.are.same({ "trophyWeight", "trophyWeight" }, kinds(earned))
			assert.is_nil(earned[2].old)
			assert.are.equal(2, state.items[TROPHY].n)
		end)
	end)

	describe("Legends (LED-R63)", function()
		it(
			"gives a Legend's first Catch Catch XP, 2,000 XP, 100 Coins and a legend achievement (LED-R20, LED-R88)",
			function()
				local first = log.cast(T0, ELWYNN, { LEGEND }, 2)
				local state, earned = applyAll({ first })

				-- Catch XP doubled under Fresh Water, the zone's first Catch, and the Legend's 2,000 (LED-R20, LED-R22):
				-- 2,220 XP, past level 2 (1,080) and short of 3 (2,240).
				assert.are.equal(20 + 200 + 2000, state.xp)
				assert.are.same({
					{ kind = "legend", cast = first.id, coins = 100, itemID = LEGEND },
					{ kind = "levelUp", cast = first.id, coins = 20, levels = { 2 } },
				}, earned)
				assert.are.equal(100 + 20, state.coins)
			end
		)

		it("keeps the Legend in items as a LedgerFirst, never as a Species (LED-R5, ledger.md › Data)", function()
			local state = applyAll({
				log.cast(T0, ELWYNN, { LEGEND }, 2),
				log.cast(T0 + DAY, WESTFALL, { LEGEND }),
			})

			assert.are.same({
				[LEGEND] = { n = 2, time = T0, char = 2, zone = ELWYNN, date = { year = 2026, month = 10, day = 1 } },
			}, state.items)
			assert.are.same({}, state.species)
			-- Its zones are fished (LED-R6), but no Species, item or family of theirs is a Legend (LED-R63).
			for _, zone in ipairs({ ELWYNN, WESTFALL }) do
				assert.are.same(
					{ species = {}, families = {}, items = {}, junk = false, treasure = false, rank = 0 },
					state.zones[zone]
				)
			end
		end)

		it("gives its second Catch only Catch XP, and no achievement (LED-R20, LED-R63)", function()
			local state = applyAll({ log.cast(T0, 0, { LEGEND }) })
			local xp, coins = state.xp, state.coins
			local _, earned = applyAll({ log.cast(T0 + 60, 0, { LEGEND }) }, "live", state)

			assert.are.equal(xp + 20, state.xp)
			assert.are.equal(coins, state.coins)
			assert.are.same({}, earned)
		end)

		it("earns no star for a Legend, even after 50 Catches in three zones (LED-R63, LED-R45)", function()
			local records = {}
			for i = 1, 50 do
				-- Three zones the world doesn't chart, so no Zone Mastery rank joins in (LED-R54).
				records[i] = log.cast(T0 + i * 60, ({ ELWYNN, WESTFALL, 33 })[i % 3 + 1], { LEGEND })
			end
			local state, earned = applyAll(records)

			local seen = {}
			for _, achievement in ipairs(earned) do
				seen[achievement.kind] = true
			end
			assert.are.same({ legend = true, levelUp = true }, seen)
			assert.are.same({}, ns.SpeciesStars(world, state, LEGEND))
		end)

		it("never counts a Legend on a trophy item as its family's weight (LED-R5, LED-R61, LED-R47)", function()
			local state, earned = applyAll({ log.cast(T0, 0, { TROPHY_LEGEND }), log.cast(T0 + 60, 0, { TROPHY40 }) })

			assert.are.same({}, ns.FamilyStars(world, applyAll({ log.cast(T0, 0, { TROPHY_LEGEND }) }), 2))
			-- The family's first weight: no ruler from the Legend's 90 (LED-R61). The Legend's 2,020 XP reach level 2.
			assert.are.same({ "legend", "levelUp", "trophyWeight" }, kinds(earned))
			assert.is_nil(earned[3].old)
			assert.are.equal(100 + 20 + 5, state.coins)
		end)

		it(
			"leaves completion and its Species part as they were, and counts Legends 1 of 2 (LED-R63, LED-R70)",
			function()
				local without = applyAll({ log.cast(T0, ELWYNN, { MACKEREL }) })
				local with = applyAll({
					log.cast(T0, ELWYNN, { MACKEREL }),
					log.cast(T0 + 60, ELWYNN, { LEGEND, REMOVED_LEGEND }),
				})
				local before = ns.LedgerCompletion(world, without)
				local after = ns.LedgerCompletion(world, with)

				assert.are.same(
					{ before.percent, before.done, before.total, before.species },
					{ after.percent, after.done, after.total, after.species }
				)
				-- Mackerel of the two listed Species; LEGEND of the two listed Legends, the removed one in neither side.
				assert.are.same({ done = 1, total = 2 }, after.species)
				assert.are.same({ done = 0, total = 2 }, before.legends)
				assert.are.same({ done = 1, total = 2 }, after.legends)
				assert.are.same({ LEGEND, LEGEND_2, REMOVED_LEGEND }, ns.CollectionWorlds(world, with).legends)
			end
		)
	end)

	describe("Catch Milestones (LED-R42)", function()
		-- A state `catches` Catches in, as a log would leave it: every milestone up to there credited, at T0 - DAY.
		local function stateAt(catches)
			local state = fold.reset()
			state.catches = catches
			for _, n in ipairs({ 1000, 5000, 10000, 25000, 50000 }) do
				if n <= catches then
					state.milestones[n] = T0 - DAY
				end
			end
			return state
		end

		it("credits the 1,000th lifetime Catch with no XP or Coins, and the 1,001st with nothing (LED-R42)", function()
			local state = stateAt(999)
			state.fresh = 0
			local thousandth = log.cast(T0, 0, { OTHER })
			local _, earned = applyAll({ thousandth }, "live", state)

			assert.are.same({ [1000] = T0 }, state.milestones)
			assert.are.same({ { kind = "catchMilestone", cast = thousandth.id, coins = 0, n = 1000 } }, earned)
			-- Catch XP alone, undoubled with no Fresh Water (LED-R20, LED-R88).
			assert.are.same({ 10, 0 }, { state.xp, state.coins })

			local _, later = applyAll({ log.cast(T0 + 60, 0, { OTHER }) }, "live", state)
			assert.are.same({}, later)
			assert.are.same({ [1000] = T0 }, state.milestones)
		end)

		it("credits a milestone at the Catch that reaches it, in a Cast's item order (LED-R42, LED-R3)", function()
			local state = stateAt(4998)
			local cast = log.cast(T0, 0, { OTHER, MACKEREL, JUNK })
			local _, earned = applyAll({ cast }, "live", state)

			-- The second Catch is the 5,000th: after the first's nothing, before the Mackerel's and junk's own.
			assert.are.same({ "catchMilestone", "newSpecies", "newCurio" }, kinds(earned))
			assert.are.equal(5000, earned[1].n)
			assert.are.same({ [1000] = T0 - DAY, [5000] = T0 }, state.milestones)
		end)

		it("is at 1,000, 5,000, 10,000, 25,000 and 50,000, and at nothing past them (LED-R42, Tunables)", function()
			local credited = {}
			for _, before in ipairs({ 999, 4999, 9999, 24999, 49999, 99999 }) do
				local state = stateAt(before)
				local _, earned = applyAll({ log.cast(T0, 0, { OTHER }) }, "live", state)
				for _, achievement in ipairs(earned) do
					credited[#credited + 1] = achievement.n
				end
			end

			assert.are.same({ 1000, 5000, 10000, 25000, 50000 }, credited)
		end)

		it("credits each one reached and not yet credited, a stride over two crediting both (LED-R42)", function()
			-- A hand-made state 4,999 Catches in with none credited: a stride no log makes, one Catch at a time.
			local state = fold.reset()
			state.catches = 4999
			local _, earned = applyAll({ log.cast(T0, 0, { OTHER }) }, "live", state)

			assert.are.same({ 1000, 5000 }, { earned[1].n, earned[2].n })
			assert.are.same({ [1000] = T0, [5000] = T0 }, state.milestones)
		end)

		it("counts every class toward them, item 0 and Uncharted too (LED-R42, LED-R5)", function()
			local state = stateAt(997)
			local _, earned = applyAll({ log.cast(T0, 0, { 0, UNCHARTED, NOISE }) }, "live", state)

			assert.are.same({ "uncharted", "catchMilestone" }, kinds(earned))
			assert.are.same({ [1000] = T0 }, state.milestones)
		end)
	end)

	describe("first Catches (LED-R140, LED-R146)", function()
		it("keeps the realm date of the first Catch of any class, item 0 too (LED-R146)", function()
			local state = applyAll({ log.gotAway(T0, ELWYNN), log.cast(T0 + DAY, 0, { 0 }) })
			assert.are.same({ year = 2026, month = 10, day = 2 }, state.firstDate)

			applyAll({ log.cast(T0 + 2 * DAY, ELWYNN, { MACKEREL }) }, "live", state)
			assert.are.same({ year = 2026, month = 10, day = 2 }, state.firstDate)
		end)

		it("has no first date before the first Catch (LED-R146)", function()
			assert.is_nil(applyAll({ log.gotAway(T0, ELWYNN) }).firstDate)
		end)

		it(
			"keeps a Species' first Catch: time, character, zone and realm date, by any of its items (LED-R140)",
			function()
				local state = applyAll({
					log.cast(T0, 0, { OTHER }),
					log.cast(T0 + DAY, WESTFALL, { MACKEREL }, 2),
					log.cast(T0 + 3 * DAY, ELWYNN, { MACKEREL }),
				})

				assert.are.same({
					n = 2,
					time = T0 + DAY,
					char = 2,
					zone = WESTFALL,
					date = { year = 2026, month = 10, day = 2 },
					zones = { [WESTFALL] = true, [ELWYNN] = true },
					windowsMet = {}, -- Mackerel has no element windows (LED-R45)
				}, state.species[MACKEREL])
			end
		)
	end)

	describe("zones (LED-R6)", function()
		it("makes a zone fished at any Catch there, earning 200 XP once (LED-R6, LED-R20, LED-R21)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { NOISE }), log.cast(T0 + 60, ELWYNN, { OTHER }) })

			assert.are.same(
				{ [ELWYNN] = { species = {}, families = {}, items = {}, junk = false, treasure = false, rank = 0 } },
				state.zones
			)
			assert.are.equal(20 + 200 + 20, state.xp)
		end)

		it("gives zone 0 no zone credit, and takes nothing else away (LED-R6)", function()
			local state, earned = applyAll({ log.cast(T0, 0, { MACKEREL }) })

			assert.are.same({}, state.zones)
			assert.are.same({}, state.species[MACKEREL].zones)
			assert.are.equal(20 + 500, state.xp)
			assert.are.same({ "newSpecies" }, { earned[1].kind })
			assert.are.equal(1, #earned)
		end)
	end)

	describe("XP (LED-R20, LED-R21)", function()
		it("gives a new Species in a new zone 10 + 500 + 100 + 200, only the 10 doubled (LED-R20)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { MACKEREL }) })

			assert.are.equal(20 + 500 + 100 + 200, state.xp)
		end)

		it("gives a second Catch of it there its Catch XP alone: 20 or 10 (LED-R20, LED-R22)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { MACKEREL }) })
			local xp = state.xp
			applyAll({ log.cast(T0 + 60, ELWYNN, { MACKEREL }) }, "live", state)
			assert.are.equal(xp + 20, state.xp)

			state.fresh = 0
			xp = state.xp
			applyAll({ log.cast(T0 + 60, ELWYNN, { MACKEREL }) }, "live", state)
			assert.are.equal(xp + 10, state.xp)
		end)

		it("gives a known Species in a new zone 100 + 200 and a newInZone with its Cast (LED-R20, LED-R97)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { MACKEREL }) })
			local xp = state.xp
			local westfall = log.cast(T0 + 60, WESTFALL, { MACKEREL })
			local _, earned = applyAll({ westfall }, "live", state)

			assert.are.equal(xp + 20 + 100 + 200, state.xp)
			assert.are.same({
				kind = "newInZone",
				cast = westfall.id,
				coins = 0,
				species = MACKEREL,
				itemID = MACKEREL,
				zone = WESTFALL,
			}, earned[1])
			assert.are.same({ "newInZone", "levelUp" }, { earned[1].kind, earned[2].kind }) -- 1,140 XP: level 2
		end)

		it("raises newSpecies with 10 Coins, and no newInZone, at a first Catch ever (LED-R97, LED-R88)", function()
			local cast = log.cast(T0, ELWYNN, { MACKEREL })
			local state, earned = applyAll({ cast })

			assert.are.same({
				{
					kind = "newSpecies",
					cast = cast.id,
					coins = 10,
					species = MACKEREL,
					itemID = MACKEREL,
					zone = ELWYNN,
				},
			}, earned)
			assert.are.equal(10, state.coins)
		end)

		it("counts firsts across characters: another's first Catch of a Species is no first (LED-R21)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { MACKEREL }, 1) })
			local xp = state.xp
			local _, earned = applyAll({ log.cast(T0 + 60, ELWYNN, { MACKEREL }, 2) }, "live", state)

			assert.are.equal(xp + 20, state.xp)
			assert.are.same({}, earned)
			assert.are.equal(2, state.species[MACKEREL].n)
		end)

		it("credits a Cast's Catches in item order: two new Species, one zone first (LED-R3, LED-R20)", function()
			local cast = log.cast(T0, ELWYNN, { SMALLFISH, MACKEREL, SMALLFISH })
			local state, earned = applyAll({ cast })

			assert.are.equal(3 * 20 + 2 * 500 + 2 * 100 + 200, state.xp)
			assert.are.same(
				{ "newSpecies", "newSpecies", "levelUp" },
				{ earned[1].kind, earned[2].kind, earned[3].kind }
			)
			assert.are.same({ SMALLFISH, MACKEREL }, { earned[1].species, earned[2].species })
			assert.are.equal(2, state.species[SMALLFISH].n)
			assert.are.same({ [SMALLFISH] = true, [MACKEREL] = true }, state.zones[ELWYNN].species)
		end)
	end)

	describe("Fresh Water (LED-R22, LED-R23)", function()
		it("starts at the cap, 300, and a 3-item Cast spends 3 (LED-R22, Tunables)", function()
			local state = fold.reset()
			assert.are.equal(300, state.fresh)

			applyAll({ log.cast(T0, ELWYNN, { OTHER, OTHER, OTHER }) }, "live", state)
			assert.are.equal(297, state.fresh)
		end)

		it("refills 10 an hour between Catches, back at the cap after a 30-hour gap (LED-R22)", function()
			local state = fold.reset()
			state.fresh = 0
			applyAll({ log.cast(T0, ELWYNN, { OTHER }) }, "live", state)
			assert.are.equal(0, state.fresh)

			applyAll({ log.cast(T0 + HOUR, ELWYNN, { OTHER }) }, "live", state)
			assert.are.equal(9, state.fresh)

			applyAll({ log.cast(T0 + 31 * HOUR, ELWYNN, { OTHER }) }, "live", state)
			assert.are.equal(299, state.fresh)
		end)

		it("doubles no Catch while F is below 1, as at 0.5 (LED-R22)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { OTHER }) })
			state.fresh = 0.5
			local xp = state.xp
			applyAll({ log.cast(T0, ELWYNN, { OTHER, OTHER }) }, "live", state)

			assert.are.equal(xp + 10 + 10, state.xp)
			assert.are.equal(0.5, state.fresh)
		end)

		it("shows floor(min(cap, F + rate × elapsed / 3,600)) now, the cap with no Catch yet (LED-R23)", function()
			local state = fold.reset()
			assert.are.equal(300, ns.FreshWaterShown(state, T0))

			state.fresh = 0
			applyAll({ log.cast(T0, ELWYNN, { OTHER }) }, "live", state)
			assert.are.equal(0, ns.FreshWaterShown(state, T0 + 359))
			assert.are.equal(1, ns.FreshWaterShown(state, T0 + 360))
			assert.are.equal(25, ns.FreshWaterShown(state, T0 + 2.5 * HOUR))
			assert.are.equal(300, ns.FreshWaterShown(state, T0 + 100 * HOUR))
			-- A server time before the last Catch adds nothing.
			assert.are.equal(0, ns.FreshWaterShown(state, T0 - HOUR))
		end)
	end)

	describe("the climb (LED-R30, LED-R31, LED-R35)", function()
		-- What reaching level 60 costs: the steps from 1 to 59, at 1,000 + 80 × L each (LED-R30).
		local TO_60 = 59 * 1000 + 80 * (59 * 60 / 2)

		it("is level 1 at 1,079 XP and 2 at 1,080: the step from level 1 costs 1,000 + 80 (LED-R30)", function()
			assert.are.same({ 1, 0, 1080 }, { ns.ClimbOf(0, 0) })
			assert.are.same({ 1, 1079, 1080 }, { ns.ClimbOf(1079, 0) })
			assert.are.same({ 2, 0, 1160 }, { ns.ClimbOf(1080, 0) })
			assert.are.same({ 3, 5, 1240 }, { ns.ClimbOf(1080 + 1160 + 5, 0) })
		end)

		it("stops at 60 and keeps the carried XP past it, unused until Prestige (LED-R30, LED-R31)", function()
			assert.are.equal(200600, TO_60)
			assert.are.same({ 59, 1000 + 80 * 59 - 1, 1000 + 80 * 59 }, { ns.ClimbOf(TO_60 - 1, 0) })
			-- At 60 there is no next step; the second value is the carried XP.
			assert.are.same({ 60, 0 }, { ns.ClimbOf(TO_60, 0) })
			assert.are.same({ 60, 12345 }, { ns.ClimbOf(TO_60 + 12345, 0) })
		end)

		it(
			"climbs as the steps taken one at a time do, at and either side of every level's first XP (LED-R30)",
			function()
				-- The climb walked step by step, each step's cost read as it is reached.
				local function walked(xp)
					local level = 1
					while level < ns.LEVEL_CAP and xp >= ns.StepCost(level) do
						xp = xp - ns.StepCost(level)
						level = level + 1
					end
					return { level, xp, level < ns.LEVEL_CAP and ns.StepCost(level) or nil }
				end
				local reach = 0
				for level = 1, ns.LEVEL_CAP do
					for _, xp in ipairs({ reach - 1, reach, reach + 1 }) do
						assert.are.same(walked(xp), { ns.ClimbOf(xp) }, ("at %d XP"):format(xp))
					end
					reach = reach + (level < ns.LEVEL_CAP and ns.StepCost(level) or 0)
				end
			end
		)

		it("reads the level and the peak level, the level at prestige rank 0, from the state (LED-R35)", function()
			local state = fold.reset()
			assert.are.same({ 1, 1 }, { ns.Level(state), ns.PeakLevel(state) })

			state.xp = 1080 + 1160
			assert.are.same({ 3, 3 }, { ns.Level(state), ns.PeakLevel(state) })
		end)

		it("raises one levelUp per entry, with every level it raised and 20 Coins each (LED-R97, LED-R88)", function()
			local state = fold.reset()
			state.xp = 1080 - 1
			local cast = log.cast(T0, ELWYNN, { MACKEREL }) -- 820 XP: level 1 → 2, not yet 3 (2,240)
			local _, earned = applyAll({ cast }, "live", state)

			assert.are.equal(2, ns.Level(state))
			assert.are.same({ kind = "levelUp", cast = cast.id, coins = 20, levels = { 2 } }, earned[2])
			assert.are.equal(2, #earned)
			assert.are.equal(10 + 20, state.coins)
		end)

		it("raises one levelUp for two levels, after the entry's other achievements (LED-R97)", function()
			local state = fold.reset()
			state.xp = 1080 + 1160 - 1 -- 1 XP short of level 3
			-- A first Skill Reading at 160: 75 and 150, 2,000 XP, past 3 and the 1,240 step to 4 (LED-R40).
			local _, earned = applyAll({ log.skill(T0, 160) }, "live", state)

			assert.are.equal(4, ns.Level(state))
			assert.are.same({ kind = "levelUp", coins = 40, levels = { 3, 4 } }, earned[3])
			assert.are.equal(3, #earned)
			assert.are.equal(40, state.coins)
		end)

		it("stops raising levels at 60 while the carried XP grows (LED-R30)", function()
			local state = fold.reset()
			state.xp = TO_60 - 1
			local _, earned = applyAll({ log.skill(T0, 300) }, "live", state)

			assert.are.equal(60, ns.Level(state))
			assert.are.same({ kind = "levelUp", coins = 20, levels = { 60 } }, earned[5])
			assert.are.equal(TO_60 - 1 + 4000, state.xp)
			assert.are.same({ 60, 3999 }, { ns.ClimbOf(state.xp, 0) })
		end)
	end)

	describe("Skill Milestones (LED-R40)", function()
		it("credits 75 and 150 at a first 160, then 225 and 300 at a later 300, 1,000 XP each (LED-R40)", function()
			local state, earned = applyAll({ log.skill(T0, 160) })

			assert.are.same({
				{ kind = "skillMilestone", coins = 0, threshold = 75 },
				{ kind = "skillMilestone", coins = 0, threshold = 150 },
			}, { earned[1], earned[2] })
			assert.are.same({ [75] = T0, [150] = T0 }, state.skill)
			assert.are.equal(2000, state.xp)

			local _, later = applyAll({ log.skill(T0 + HOUR, 300) }, "live", state)
			assert.are.same({
				{ kind = "skillMilestone", coins = 0, threshold = 225 },
				{ kind = "skillMilestone", coins = 0, threshold = 300 },
			}, { later[1], later[2] })
			assert.are.same({ [75] = T0, [150] = T0, [225] = T0 + HOUR, [300] = T0 + HOUR }, state.skill)
			assert.are.equal(4000, state.xp)
		end)

		it("credits each once per Angler: a second character never re-credits them (LED-R40, LED-R21)", function()
			local state = applyAll({ log.skill(T0, 160, 1) })
			local xp = state.xp
			local _, earned = applyAll({ log.skill(T0 + 60, 200, 2), log.skill(T0 + 120, 160, 1) }, "live", state)

			assert.are.same({}, earned)
			assert.are.equal(xp, state.xp)
		end)

		it("credits nothing below 75, and a reading touches nothing else (LED-R40)", function()
			local state, earned = applyAll({ log.skill(T0, 74) })

			assert.are.same(fold.reset(), state)
			assert.are.same({}, earned)
		end)
	end)

	describe("purity (LED-R3)", function()
		-- A log touching every rule above, over two characters and three zones.
		local function history()
			local l = newLog()
			return {
				l.cast(T0, ELWYNN, { MACKEREL, NOISE }),
				l.skill(T0 + 30, 160),
				l.gotAway(T0 + 60, ELWYNN),
				l.cast(T0 + 90, 0, { SMALLFISH, 0, UNCHARTED }),
				l.other(T0 + 100, "build"),
				l.cast(T0 + 5 * HOUR, WESTFALL, { MACKEREL, SMALLFISH, TROPHY }, 2),
				l.skill(T0 + 6 * HOUR, 300, 2),
				l.cast(T0 + 40 * HOUR, WESTFALL, { LEGEND, JUNK, OTHER }),
				l.cast(T0 + 41 * HOUR, ELWYNN, { TROPHY40, UNCHARTED, CHEST, JUNK }),
				l.cast(T0 + 42 * HOUR, 0, { TROPHY60, TROPHY50, UNCHARTED }),
			}
		end

		it("gives the same state and achievements in live, replay and rebuild mode (LED-R3, LOG-R75)", function()
			local liveState, live = applyAll(history(), "live")
			local replayState, replay = applyAll(history(), "replay")
			local rebuildState, rebuild = applyAll(history(), "rebuild")

			assert.are.same(liveState, replayState)
			assert.are.same(liveState, rebuildState)
			assert.are.same(live, replay)
			assert.are.same(live, rebuild)
			assert.is_true(#live > 0)
		end)

		it("returns what each apply earned, appended to the caller's list or to a new one (LED-R98)", function()
			local records = history()
			local state = fold.reset()
			local list = { "earlier" }

			assert.are.equal(list, fold.apply(state, records[1], "rebuild", list))
			assert.are.same({ "earlier", "newSpecies" }, { list[1], list[2].kind })
			assert.are.equal(2, #list)
			local skill = fold.apply(state, records[2], "rebuild")
			assert.are.same({ "skillMilestone", "skillMilestone", "levelUp" }, kinds(skill))
		end)

		it("never writes to a record, and keeps none of its tables in the state (CORE-R18)", function()
			local records = history()
			local state = applyAll(records)

			assert.are.same(history(), records)
			local seen = {}
			for _, record in ipairs(records) do
				seen[record] = true
				seen[record.conditions or seen] = true
				for _, item in ipairs(record.items or {}) do
					seen[item] = true
				end
			end
			local function check(value)
				if type(value) == "table" then
					assert.is_nil(seen[value])
					for _, inner in pairs(value) do
						check(inner)
					end
				end
			end
			check(state)
		end)

		it("starts each reset from a fresh, empty state (LED-R3, LOG-R72)", function()
			local a, b = fold.reset(), fold.reset()

			assert.are_not.equal(a, b)
			assert.are.same({
				casts = 0,
				catches = 0,
				xp = 0,
				lifetimeXP = 0,
				prestigeActivityXP = 0,
				prestige = 0,
				fresh = 300,
				coins = 0,
				skill = {},
				milestones = {},
				species = {},
				items = {},
				uncharted = {},
				zones = {},
				varieties = {},
				counts = {
					shards = 0,
					lastDay = {},
					deep = 0,
					pairs = 0,
					lastSpecies = {},
					records = 0,
					ice = 0,
					sea = 0,
					gotAwayRun = 0,
					afterRun = false,
					days = {},
					lures = {},
					races = {},
					factions = {},
					clams = 0,
				},
				-- Nothing done or risen of the world's 2 Species and 3 charted zones (LED-R70, LED-R158).
				rises = { done = 0, total = 5, species = 0, legends = 0, at = {} },
			}, a)
			assert.are_not.equal(a.counts, b.counts)
			assert.are_not.equal(a.rises.at, b.rises.at)
		end)

		it(
			"is LEDGER_RULES_VERSION 10: 4 when ★ moved to the 5th Catch, 5 for the full Prestige cost and Activity XP in the climb, 6 for the varieties caught, 7 for the second round's counts, 8 for the crest times and record, 9 for the measures' rise times, 10 for the fish of each race and faction (LED-R4, LED-R30, LED-R37, VAR-R20, LED-R118, LED-R155, LED-R156, LED-R158, LED-R164, Tunables)",
			function()
				assert.are.equal(10, ns.LEDGER_RULES_VERSION)
			end
		)
	end)

	describe("Casts (LED-R7, LED-R2)", function()
		it("counts a got-away Cast toward the Casts total only, leaving Fresh Water alone (LED-R7)", function()
			local state = applyAll({ log.cast(T0, ELWYNN, { MACKEREL }) })
			local before = state.fresh
			local _, earned = applyAll({ log.gotAway(T0 + 10 * HOUR, WESTFALL) }, "live", state)

			assert.are.equal(2, state.casts)
			assert.are.equal(1, state.catches)
			assert.are.equal(before, state.fresh)
			assert.are.equal(T0, state.lastCatch)
			assert.is_nil(state.zones[WESTFALL])
			assert.are.same({}, earned)
		end)

		it("ignores build, purchase and Module records (LED-R2, LED-R4)", function()
			local records = {}
			for i, kind in ipairs({ "build", "purchase", "module" }) do
				records[i] = log.other(T0 + i, kind)
			end
			local state, earned = applyAll(records)

			assert.are.same(fold.reset(), state)
			assert.are.same({}, earned)
		end)
	end)
end)
