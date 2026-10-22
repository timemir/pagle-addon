-- Generating a goal (tackle-board.md › Generating a goal, TKB-R30–R35): candidate zones, eligible Species, the kind,
-- the target, need, tier and pay, over the fixture catalogue (spec/Pagle_TackleBoard/fixtures/Catalogue.lua) with a
-- scripted or seeded random source.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DAY = 86400

-- The fixture's zones (spec/Pagle_TackleBoard/fixtures/Catalogue.lua).
local DUROTAR, TELDRASSIL, DARKSHORE, BARRENS = 14, 141, 148, 17
local NEEDLES, ASHENVALE, ELWYNN, WESTFALL = 400, 331, 12, 40

describe("generating a goal", function()
	local loaded, fake = board.load()
	local ns = loaded.ns
	local pagle = fake.globals.Pagle

	-- A generation context over the fixture catalogue: the fixture Angler's skill, nothing fished or caught, no goal
	-- open, a seeded random source; `fields` overrides any of it.
	local function context(fields)
		local ctx = {
			pagle = pagle,
			bestBaseSkill = board.SKILL,
			now = SERVER_TIME,
			zones = {},
			caught = {},
			open = {},
			random = board.random(1),
		}
		for key, value in pairs(fields or {}) do
			ctx[key] = value
		end
		return ctx
	end

	-- A random source like math.random that returns `values` in turn (and each range's lowest number once they run
	-- out), and records every call's { m, n } in `.calls`.
	local function scripted(values)
		local calls, i = {}, 0
		return setmetatable({ calls = calls }, {
			__call = function(_, m, n)
				i = i + 1
				calls[i] = { m, n }
				local value = values[i] or m
				assert(value >= m and value <= n, ("draw %d: %d is outside %d..%d"):format(i, value, m, n))
				return value
			end,
		})
	end

	-- Core's catalogue calls, with GetZones listing only `zones`.
	local function zonesOnly(zones)
		return setmetatable({
			GetZones = function()
				return zones
			end,
		}, { __index = pagle })
	end

	describe("candidate zones (TKB-R30)", function()
		local function zoneIDs(candidates)
			local ids = {}
			for i, candidate in ipairs(candidates) do
				ids[i] = candidate.zone
			end
			return ids
		end

		it("are the zones with data and a skillBase at or below the Angler's best base skill, ascending", function()
			-- Feralas (205) is above 150, Moonglade has no skillBase, Stormwind has no data; Ashenvale (150) is in.
			assert.are.same(
				{ ELWYNN, DUROTAR, BARRENS, WESTFALL, TELDRASSIL, DARKSHORE, ASHENVALE, NEEDLES },
				zoneIDs(ns.CandidateZones(context()))
			)
		end)

		it("leave out a zone whose skillBase is above the Angler's skill", function()
			assert.are.same(
				{ ELWYNN, DUROTAR, BARRENS, WESTFALL, TELDRASSIL, DARKSHORE },
				zoneIDs(ns.CandidateZones(context({ bestBaseSkill = 75 })))
			)
		end)

		it("weigh 8 for a zone with a Cast 3 days ago and 1 for one 20 days ago or never fished", function()
			local candidates = ns.CandidateZones(context({
				zones = { [DUROTAR] = SERVER_TIME - 3 * DAY, [BARRENS] = SERVER_TIME - 20 * DAY },
			}))
			local weights = {}
			for _, candidate in ipairs(candidates) do
				weights[candidate.zone] = candidate.weight
			end
			assert.are.same({ 8, 1, 1 }, { weights[DUROTAR], weights[BARRENS], weights[ELWYNN] })
		end)

		it("weigh 8 for a Cast exactly 14 days ago and 1 for one a second before that", function()
			local candidates = ns.CandidateZones(context({
				zones = { [DUROTAR] = SERVER_TIME - 14 * DAY, [BARRENS] = SERVER_TIME - 14 * DAY - 1 },
			}))
			local weights = {}
			for _, candidate in ipairs(candidates) do
				weights[candidate.zone] = candidate.weight
			end
			assert.are.same({ 8, 1 }, { weights[DUROTAR], weights[BARRENS] })
		end)
	end)

	describe("eligible Species (TKB-R31)", function()
		it("are a zone's ungated fish, one per Species, by representative item ascending", function()
			-- Durotar: the gated bass, the Noise potion, the junk and the quest fish are left out.
			assert.are.same({
				{ species = 6289, item = 6289 },
				{ species = 6291, item = 6291 },
				{ species = 6303, item = 6303 },
			}, ns.EligibleSpecies(pagle, DUROTAR))
		end)

		it("name a Species by its lowest eligible item in the zone and its subzones, once", function()
			-- Darkshore: Mightfish as 13893 in Darkshore and 13754 in Auberdine; smallfish only in Auberdine. The gated
			-- Nightfin and Firefin, the Legend and the removed fish are never eligible.
			assert.are.same({
				{ species = 6291, item = 6291 },
				{ species = 6303, item = 6303 },
				{ species = 6358, item = 6358 },
				{ species = 12238, item = 12238 },
				{ species = 13754, item = 13754 },
			}, ns.EligibleSpecies(pagle, DARKSHORE))
		end)

		it("are none in a zone whose only fish is gated", function()
			assert.are.same({}, ns.EligibleSpecies(pagle, NEEDLES))
		end)
	end)

	-- Every kind ns.GenerateGoal draws for `goalType` over `runs` seeds, as a set, with `fields` in the context.
	-- `runs` goals ns.GenerateGoal draws for `goalType` (rerolling `dropKind`) one after another from one seeded random
	-- source, with `fields` in the context.
	local function goalsDrawn(fields, goalType, dropKind, runs)
		local random = board.random(7)
		local goals = {}
		for i = 1, runs or 300 do
			local ctx = context(fields)
			ctx.random = random
			goals[i] = ns.GenerateGoal(ctx, goalType, dropKind)
		end
		return goals
	end

	local function kindsDrawn(fields, goalType, dropKind, runs)
		local kinds = {}
		for _, goal in ipairs(goalsDrawn(fields, goalType, dropKind, runs)) do
			kinds[goal.kind] = true
		end
		return kinds
	end

	-- An open goal of `goalType` and `kind` (only what generation reads of it).
	local function openGoal(goalType, kind, target, items)
		return { type = goalType, kind = kind, target = target, items = items }
	end

	describe("the kind (TKB-R32)", function()
		it("is drawn by the Notice weights, haul 2, variety 2 and 1 for the rest, in the table's order", function()
			local drawn = {}
			for value = 1, 9 do
				local random = scripted({ value })
				drawn[value] = ns.GenerateGoal(context({ random = random }), "n").kind
				assert.are.same({ 1, 9 }, random.calls[1])
			end
			assert.are.same({
				"haul",
				"haul",
				"variety",
				"variety",
				"wanderer",
				"quality",
				"collector",
				"lure",
				"species",
			}, drawn)
		end)

		it("is drawn from the five Expedition kinds, 1 each, never lure or species", function()
			local drawn = {}
			for value = 1, 5 do
				local random = scripted({ value })
				drawn[value] = ns.GenerateGoal(context({ random = random }), "e").kind
				assert.are.same({ 1, 5 }, random.calls[1])
			end
			assert.are.same({ "haul", "variety", "wanderer", "quality", "collector" }, drawn)
		end)

		it("never draws a size goal, for either type, issued or rerolled (ADR 0014)", function()
			for _, goalType in ipairs({ "n", "e" }) do
				assert.is_nil(kindsDrawn({}, goalType, nil, 1000).size)
				assert.is_nil(kindsDrawn({}, goalType, "quality", 1000).size)
			end
		end)

		it("leaves out the kinds already open in the same type, and only those", function()
			local open = {
				openGoal("n", "haul", ELWYNN),
				openGoal("n", "quality", 2),
				openGoal("e", "variety", WESTFALL), -- an Expedition: no bearing on a Notice's kind
			}
			assert.are.same(
				{ variety = true, wanderer = true, collector = true, lure = true, species = true },
				kindsDrawn({ open = open }, "n")
			)
		end)

		it("is drawn from every kind again when every kind is open in the type", function()
			local open = {}
			for _, kind in ipairs({ "haul", "variety", "wanderer", "quality", "collector" }) do
				open[#open + 1] = openGoal("e", kind)
			end
			assert.are.same({
				haul = true,
				variety = true,
				wanderer = true,
				quality = true,
				collector = true,
			}, kindsDrawn({ open = open }, "e"))
		end)

		it("never draws the old goal's kind on a reroll, even when every other kind is open", function()
			local open = {}
			for _, kind in ipairs({ "haul", "variety", "wanderer", "quality" }) do
				open[#open + 1] = openGoal("e", kind)
			end
			assert.are.same(
				{ haul = true, variety = true, wanderer = true, quality = true },
				kindsDrawn({ open = open }, "e", "collector")
			)
			assert.is_nil(kindsDrawn({}, "n", "haul").haul)
		end)

		it("draws a Wanderer Expedition with 5 candidate zones on Kalimdor, never with 4", function()
			-- Skill 130: Ashenvale (150) drops out, 5 Kalimdor zones stay; skill 129: Thousand Needles (130) too.
			assert.is_true(kindsDrawn({ bestBaseSkill = 130 }, "e").wanderer)
			assert.is_nil(kindsDrawn({ bestBaseSkill = 129 }, "e").wanderer)
		end)

		it("draws a Collector Expedition with 6 uncaught Sub-collection items in candidate zones, never 5", function()
			-- 7 in candidate zones (the gated container in Thousand Needles included; the Feralas trophy, the Noise
			-- junk and the removed container never count).
			assert.is_true(kindsDrawn({ caught = { [92011] = true } }, "e").collector)
			assert.is_nil(kindsDrawn({ caught = { [92011] = true, [92022] = true } }, "e").collector)
			assert.is_nil(kindsDrawn({ caught = { [92011] = true }, bestBaseSkill = 129 }, "e").collector)
		end)

		it("draws a Variety Notice only with a candidate zone of 3 or more eligible Species", function()
			-- Teldrassil has 2 eligible Species and Thousand Needles none; Durotar has 3.
			assert.is_nil(kindsDrawn({ pagle = zonesOnly({ TELDRASSIL, NEEDLES }) }, "n").variety)
			assert.is_true(kindsDrawn({ pagle = zonesOnly({ TELDRASSIL, DUROTAR }) }, "n").variety)
		end)

		it("draws a Variety Expedition only with a candidate zone of 4 to 12 eligible Species", function()
			-- Durotar has 3, The Barrens 13, Westfall 4.
			assert.is_nil(kindsDrawn({ pagle = zonesOnly({ DUROTAR, BARRENS }) }, "e").variety)
			assert.is_true(kindsDrawn({ pagle = zonesOnly({ BARRENS, WESTFALL }) }, "e").variety)
		end)

		it("draws no haul, variety or species with no candidate zone, and every always-eligible kind", function()
			assert.are.same(
				{ wanderer = true, quality = true, collector = true, lure = true },
				kindsDrawn({ bestBaseSkill = 24 }, "n")
			)
			assert.are.same({ quality = true }, kindsDrawn({ bestBaseSkill = 24 }, "e"))
		end)
	end)

	-- Every Notice kind open once, so the kind is drawn from all of them by the Notice weights (TKB-R32): the draw's
	-- values are haul 1–2, variety 3–4, wanderer 5, quality 6, collector 7, lure 8, species 9.
	local function everyNoticeKindOpen(extra)
		local open = {}
		for _, kind in ipairs({ "haul", "variety", "wanderer", "quality", "collector", "lure", "species" }) do
			open[#open + 1] = openGoal("n", kind)
		end
		for _, goal in ipairs(extra) do
			open[#open + 1] = goal
		end
		return open
	end

	describe("the target (TKB-R33)", function()
		it("is a candidate zone drawn by weight", function()
			-- Weights in zone order: Elwynn 1, Durotar 8 (fished yesterday), then 1 each for the other six: 15 in all.
			local zones = { [DUROTAR] = SERVER_TIME - DAY }
			local random = scripted({ 1, 2 })
			assert.are.equal(DUROTAR, ns.GenerateGoal(context({ zones = zones, random = random }), "n").target)
			assert.are.same({ 1, 15 }, random.calls[2])
			assert.are.equal(
				BARRENS,
				ns.GenerateGoal(context({ zones = zones, random = scripted({ 1, 10 }) }), "n").target
			)
		end)

		it("avoids a zone an open goal of the same type and kind targets while another exists", function()
			local open =
				{ openGoal("n", "haul", ELWYNN), openGoal("n", "variety", DUROTAR), openGoal("e", "haul", BARRENS) }
			local random = scripted({ 1, 1 })
			local goal = ns.GenerateGoal(context({ open = everyNoticeKindOpen(open), random = random }), "n")
			-- Elwynn left out; Durotar (a Variety Notice's) and The Barrens (an Expedition's) stay: 7 zones of weight 1.
			assert.are.same({ "haul", DUROTAR }, { goal.kind, goal.target })
			assert.are.same({ 1, 7 }, random.calls[2])
		end)

		it("puts every zone back when open goals of the same type and kind target them all", function()
			local open = { openGoal("n", "haul", TELDRASSIL), openGoal("n", "haul", DUROTAR) }
			local random = scripted({ 1, 2 })
			local ctx = context({
				pagle = zonesOnly({ DUROTAR, TELDRASSIL }),
				open = everyNoticeKindOpen(open),
				random = random,
			})
			assert.are.equal(TELDRASSIL, ns.GenerateGoal(ctx, "n").target)
			assert.are.same({ 1, 2 }, random.calls[2])
		end)

		it("is a Species goal's representative item, avoiding open Species goals' Species, not their items", function()
			-- An open Species Notice for Large Raw Mightfish (13893) names the Mightfish Species (13754): Darkshore's
			-- other 4 Species are left, the highest of them Sagefish's 12238.
			local open = everyNoticeKindOpen({ openGoal("n", "species", 13893) })
			local random = scripted({ 9, 1, 4 })
			local goal =
				ns.GenerateGoal(context({ pagle = zonesOnly({ DARKSHORE }), open = open, random = random }), "n")
			assert.are.same({ "species", 12238 }, { goal.kind, goal.target })
			assert.are.same({ { 1, 9 }, { 1, 1 }, { 1, 4 } }, { random.calls[1], random.calls[2], random.calls[3] })
		end)

		it("draws a Species goal's zone among those with a Species no open Species goal names", function()
			-- Durotar's 3 Species are all named, so only Westfall is drawn, then one of its 2 Species no goal names.
			local open = everyNoticeKindOpen({
				openGoal("n", "species", 6289),
				openGoal("n", "species", 6291),
				openGoal("n", "species", 6303),
			})
			local random = scripted({ 9, 1, 1 })
			local ctx = context({ pagle = zonesOnly({ DUROTAR, WESTFALL }), open = open, random = random })
			assert.are.equal(6308, ns.GenerateGoal(ctx, "n").target)
			assert.are.same({ { 1, 1 }, { 1, 2 } }, { random.calls[2], random.calls[3] })
		end)

		it("puts every Species back when open Species goals name them all", function()
			local open = everyNoticeKindOpen({})
			for _, item in ipairs({ 6289, 6291, 6303 }) do
				open[#open + 1] = openGoal("n", "species", item)
			end
			local random = scripted({ 9, 1, 2 })
			local goal = ns.GenerateGoal(context({ pagle = zonesOnly({ DUROTAR }), open = open, random = random }), "n")
			assert.are.equal(6291, goal.target)
			assert.are.same({ 1, 3 }, random.calls[3])
		end)

		it("stores a Variety Expedition's zone and its representative items, ascending", function()
			-- Darkshore's Mightfish is 13754 (Auberdine's), the lowest of its two items.
			local goal =
				ns.GenerateGoal(context({ pagle = zonesOnly({ DARKSHORE }), random = scripted({ 2, 1 }) }), "e")
			assert.are.same({
				type = "e",
				kind = "variety",
				tier = 0,
				pay = 60,
				need = 5,
				target = DARKSHORE,
				items = { 6291, 6303, 6358, 12238, 13754 },
			}, goal)
		end)

		it("draws a Wanderer Expedition's continent uniformly among those named in the continent map", function()
			local random = scripted({ 3, 1 })
			assert.are.equal(1, ns.GenerateGoal(context({ random = random }), "e").target)
			assert.are.same({ 1, 1 }, random.calls[2])
			-- Kalimdor unnamed in the map: no continent left, so no Wanderer Expedition.
			local maps = ns.CONTINENT_MAPS
			ns.CONTINENT_MAPS = { [0] = 1415 }
			local kinds = kindsDrawn({}, "e")
			ns.CONTINENT_MAPS = maps
			assert.is_nil(kinds.wanderer)
		end)
	end)

	describe("need, tier and pay (TKB-R34)", function()
		-- The Notice ns.GenerateGoal draws in The Barrens alone (13 Species) with the kind's draw `kindValue`, then
		-- the target's draws (`targetDraws` of them) and the tier `tier`.
		local function notice(kindValue, targetDraws, tier)
			local values = { kindValue }
			for i = 1, targetDraws do
				values[i + 1] = 1
			end
			values[#values + 1] = tier
			return ns.GenerateGoal(context({ pagle = zonesOnly({ BARRENS }), random = scripted(values) }), "n")
		end

		local function definition(goal)
			return { goal.kind, goal.tier, goal.need, goal.pay, goal.target }
		end

		it("draws a Notice's tier 1–3 and pays 10, 15 or 20, with each kind's need for it", function()
			local cases = {
				{ 1, 1, "haul", { 20, 30, 40 }, BARRENS },
				{ 3, 1, "variety", { 3, 4, 5 }, BARRENS },
				{ 6, 0, "quality", { 3, 5, 8 }, 2 },
				{ 8, 0, "lure", { 15, 20, 25 }, nil },
				{ 9, 2, "species", { 5, 10, 15 }, 4603 }, -- Yellowtail, The Barrens' lowest
			}
			for _, case in ipairs(cases) do
				local kindValue, draws, kind, needs, target = case[1], case[2], case[3], case[4], case[5]
				for tier, pay in ipairs({ 10, 15, 20 }) do
					assert.are.same(
						{ kind, tier, needs[tier], pay, target },
						definition(notice(kindValue, draws, tier))
					)
				end
			end
		end)

		it(
			"fixes a Wanderer Notice at tier 3, need 3, and a Collector Notice at tier 2, need 2, drawing no tier",
			function()
				local random = scripted({ 5 })
				local wanderer = ns.GenerateGoal(context({ random = random }), "n")
				assert.are.same({ type = "n", kind = "wanderer", tier = 3, need = 3, pay = 20 }, wanderer)
				assert.are.equal(1, #random.calls)
				random = scripted({ 7 })
				local collector = ns.GenerateGoal(context({ random = random }), "n")
				assert.are.same({ type = "n", kind = "collector", tier = 2, need = 2, pay = 15 }, collector)
				assert.are.equal(1, #random.calls)
			end
		)

		it("caps a Variety Notice's need at its zone's Species, its tier following the need", function()
			-- Durotar has 3 eligible Species, Westfall 4.
			for drawn = 1, 3 do
				local ctx = context({ pagle = zonesOnly({ DUROTAR }), random = scripted({ 3, 1, drawn }) })
				assert.are.same({ "variety", 1, 3, 10, DUROTAR }, definition(ns.GenerateGoal(ctx, "n")))
			end
			local ctx = context({ pagle = zonesOnly({ WESTFALL }), random = scripted({ 3, 1, 3 }) })
			assert.are.same({ "variety", 2, 4, 15, WESTFALL }, definition(ns.GenerateGoal(ctx, "n")))
		end)

		it("gives every Expedition tier 0 and pay 60, with each kind's need and target", function()
			local cases = {
				{ 1, "haul", 150, ELWYNN },
				{ 2, "variety", 4, WESTFALL },
				{ 3, "wanderer", 5, 1 },
				{ 4, "quality", 3, 3 },
				{ 5, "collector", 3, nil },
			}
			for _, case in ipairs(cases) do
				local goal = ns.GenerateGoal(context({ random = scripted({ case[1], 1 }) }), "e")
				assert.are.same({ case[2], 0, case[3], 60, case[4] }, definition(goal))
			end
		end)
	end)

	describe("what a goal never targets (TKB-R35)", function()
		it("is a Legend, a time of day, season, event or Hunt, for any kind of either type", function()
			for _, goalType in ipairs({ "n", "e" }) do
				local kinds = {}
				for _, goal in ipairs(goalsDrawn({}, goalType, nil, 1000)) do
					kinds[goal.kind] = true
					for field in pairs(goal) do
						assert.is_truthy(
							({ type = 1, kind = 1, tier = 1, pay = 1, need = 1, target = 1, items = 1 })[field]
						)
					end
					local named = goal.items or (goal.kind == "species" and { goal.target }) or {}
					for _, item in ipairs(named) do
						assert.is_false(pagle.GetItem(item).legend)
					end
				end
				local expected = goalType == "n" and 7 or 5
				local count = 0
				for _ in pairs(kinds) do
					count = count + 1
				end
				assert.are.equal(expected, count)
			end
		end)
	end)
end)
