-- Prestige in the Ledger's fold and its pure rules (LED-R30–R35, LED-R88, LED-R97's `prestigeReady` and `prestige`):
-- the climb's step costs and carried XP, applying a Prestige entry, Prestige ready, the emblems and when Prestige is
-- allowed. Hand-made records with no catalogue: every Catch here is Uncharted (LED-R5), worth its Catch XP only.

local T0 = SERVER_TIME - 700
local ELWYNN = 12

-- What reaching level 60 costs at prestige rank 0: the steps from 1 to 59, at 1,000 + 80 × L each (LED-R30).
local TO_60 = 200600
-- And after any Prestige, at half that (LED-R30, Tunables: Prestige climb cost factor 0.5).
local TO_60_HALF = 100300

-- Builds records the way the Catch log hands them out (LOG-R42), with seq and entry IDs in order.
local function newLog()
	local seq = 0
	local log = {}

	local function header(time)
		seq = seq + 1
		return seq, ("%s-%d-%d"):format(PLAYER_GUID, time, seq)
	end

	--- A caught Cast of one Uncharted item at `time` in Elwynn.
	function log.cast(time)
		return castRecord({ seq = header(time), time = time, zone = ELWYNN, minute = 0, items = { 99999 } })
	end

	--- A Skill Reading at `rank` (LOG-R31).
	function log.skill(time, rank)
		local s, id = header(time)
		return { seq = s, id = id, kind = "skill", char = 1, time = time, rank = rank, max = 300, mod = 0 }
	end

	--- A Prestige entry to `rank` (LOG-R38).
	function log.prestige(time, rank)
		local s, id = header(time)
		return { seq = s, id = id, kind = "prestige", char = 1, time = time, rank = rank }
	end

	return log
end

describe("Prestige", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns

	local world = ns.NewWorld({
		GetItem = function() end,
		GetZones = function()
			return {}
		end,
		GetArea = function() end,
		GetZoneCatches = function()
			return {}
		end,
	})

	local fold, log
	before_each(function()
		fold = ns.NewLedgerFold({
			GetItem = function() end,
			MatchesConditions = loaded.env.Pagle.MatchesConditions,
			world = world,
		})
		log = newLog()
	end)

	-- `state` (a fresh one by default) with every record applied in `mode` ("live" by default); returns it and every
	-- achievement, in order.
	local function applyAll(records, mode, state)
		return applyLive(fold, records, state, mode)
	end

	-- A fresh state at prestige rank `rank` with the climb's XP at `xp`.
	local function stateAt(xp, rank)
		local state = fold.reset()
		state.xp, state.prestige = xp, rank or 0
		return state
	end

	describe("the climb (LED-R30, LED-R31)", function()
		it("costs 1,000 + 80 × L a step at rank 0 and half that after any Prestige (LED-R30)", function()
			assert.are.same({ 1080, 5720 }, { ns.StepCost(1, 0), ns.StepCost(59, 0) })
			assert.are.same({ 540, 2860 }, { ns.StepCost(1, 1), ns.StepCost(59, 1) })
			assert.are.equal(540, ns.StepCost(1, 12))
		end)

		it(
			"reaches 60 at 200,600 XP at rank 0 and at 100,300 after a Prestige, carrying what's past it (LED-R30)",
			function()
				assert.are.same({ 59, 2859, 2860 }, { ns.ClimbOf(TO_60_HALF - 1, 1) })
				assert.are.same({ 60, 0 }, { ns.ClimbOf(TO_60_HALF, 1) })
				assert.are.same({ 60, 4321 }, { ns.ClimbOf(TO_60_HALF + 4321, 2) })
				-- The same XP at rank 0 is level 39: steps 1 to 38 cost 97,280 there, and 39's costs 4,120.
				assert.are.same({ 39, 3020, 4120 }, { ns.ClimbOf(TO_60_HALF, 0) })
				assert.are.same({ 60, 0 }, { ns.ClimbOf(TO_60, 0) })
			end
		)

		it("reads the level from the state's XP and rank (LED-R30)", function()
			assert.are.equal(3, ns.Level(stateAt(540 + 580, 1)))
			assert.are.equal(2, ns.Level(stateAt(540 + 580, 0)))
		end)
	end)

	describe("applying a Prestige entry (LED-R32)", function()
		it(
			"at 60 with 3,000 carried XP: rank 1, the climb at the level 3,000 XP buys at half cost, one prestige and one cast-less levelUp (LED-R32, LED-R88, LED-R97)",
			function()
				local state = stateAt(TO_60 + 3000)
				local coins = state.coins
				local _, earned = applyAll({ log.prestige(T0, 1) }, "live", state)

				assert.are.equal(1, state.prestige)
				-- Half-cost steps 540 + 580 + 620 + 660 = 2,400: level 5, 600 into its 700 step (LED-R30).
				assert.are.equal(3000, state.xp)
				assert.are.same({ 5, 600, 700 }, { ns.ClimbOf(state.xp, state.prestige) })
				assert.are.same({
					{ kind = "prestige", coins = 100, rank = 1 },
					{ kind = "levelUp", coins = 80, levels = { 2, 3, 4, 5 } },
				}, earned)
				assert.are.equal(coins + 100 + 80, state.coins)
			end
		)

		it("starts the new climb at level 1 with no carried XP when the climb hadn't reached 60 (LED-R32)", function()
			local state = stateAt(TO_60 - 1)
			local _, earned = applyAll({ log.prestige(T0, 1) }, "live", state)

			assert.are.same({ 1, 0, 1 }, { ns.Level(state), state.xp, state.prestige })
			assert.are.same({ { kind = "prestige", coins = 100, rank = 1 } }, earned)
		end)

		it("climbs on from the carried XP: the climb's XP is what's earned since, plus it (LED-R31)", function()
			local state = stateAt(TO_60 + 3000)
			-- A first Skill Reading at 160 after the Prestige: 75 and 150, 2,000 XP, so 5,000 in the climb. Half-cost
			-- steps to 8 take 2,400 + 700 + 740 + 780 = 4,620, and 380 goes into the 820 step (LED-R30, LED-R40).
			local _, earned = applyAll({ log.prestige(T0, 1), log.skill(T0 + 60, 160) }, "live", state)

			assert.are.same({ 8, 380, 820 }, { ns.ClimbOf(state.xp, state.prestige) })
			assert.are.same({ kind = "levelUp", coins = 60, levels = { 6, 7, 8 } }, earned[#earned])
		end)

		it("carries XP from a half-cost climb into the next Prestige's (LED-R30, LED-R32)", function()
			local state = stateAt(TO_60_HALF + 1000, 1)
			applyAll({ log.prestige(T0, 2) }, "live", state)

			assert.are.same({ 2, 1000, 2 }, { ns.Level(state), state.xp, state.prestige })
		end)

		it(
			"may start the new climb at 60 when the carried XP has no cap: its levels and Prestige ready belong to the entry (LED-R32)",
			function()
				local state = stateAt(TO_60 + TO_60_HALF + 7)
				local _, earned = applyAll({ log.prestige(T0, 1) }, "live", state)

				assert.are.same({ 60, 7 }, { ns.ClimbOf(state.xp, state.prestige) })
				assert.are.same({ "prestige", "levelUp", "prestigeReady" }, {
					earned[1].kind,
					earned[2].kind,
					earned[3].kind,
				})
				assert.are.equal(59, #earned[2].levels)
				assert.is_nil(earned[2].cast)
				assert.are.same({ kind = "prestigeReady", coins = 0, rank = 1 }, earned[3])
			end
		)

		it(
			"takes the entry's rank, and keeps every discovery: nothing earned is taken away (LED-R32, LED-R92)",
			function()
				local state = applyAll({ log.skill(T0, 300), log.cast(T0 + 60) })
				state.xp = TO_60
				local coins = state.coins
				applyAll({ log.prestige(T0 + 120, 3) }, "live", state)

				assert.are.equal(3, state.prestige)
				assert.are.same({ [75] = T0, [150] = T0, [225] = T0, [300] = T0 }, state.skill)
				assert.are.same({ 1, 1, 1, { [ELWYNN] = 1 } }, {
					state.casts,
					state.catches,
					state.uncharted[99999].n,
					state.uncharted[99999].zones,
				})
				assert.are.equal(coins + 100, state.coins)
			end
		)

		it("is the same in live, replay and rebuild mode (LED-R3, LED-R32: any mode)", function()
			local function history()
				local l = newLog()
				return { l.skill(T0, 300), l.cast(T0 + 60), l.prestige(T0 + 120, 1), l.cast(T0 + 180) }
			end
			local function from(mode)
				local state = stateAt(TO_60 - 4000)
				local _, earned = applyAll(history(), mode, state)
				return { state = state, earned = earned }
			end

			assert.are.same(from("live"), from("replay"))
			assert.are.same(from("live"), from("rebuild"))
			assert.are.equal(1, from("rebuild").state.prestige)
		end)
	end)

	describe("Prestige ready (LED-R97, LED-R90)", function()
		it("is earned when the climb's computed level reaches 60, after its levelUp, with the climb's rank", function()
			local state = stateAt(TO_60 - 1)
			local _, earned = applyAll({ log.skill(T0, 300) }, "live", state)

			assert.are.same({ kind = "levelUp", coins = 20, levels = { 60 } }, earned[5])
			assert.are.same({ kind = "prestigeReady", coins = 0, rank = 0 }, earned[6])
			assert.are.equal(6, #earned)
		end)

		it("carries the Cast that reached 60, and comes once per climb (LED-R97)", function()
			local state = stateAt(TO_60_HALF - 10, 1)
			local first, later = log.cast(T0), log.cast(T0 + 60)
			local _, earned = applyAll({ first, later, log.skill(T0 + 120, 300) }, "live", state)

			local ready = {}
			for _, achievement in ipairs(earned) do
				if achievement.kind == "prestigeReady" then
					ready[#ready + 1] = achievement
				end
			end
			assert.are.same({ { kind = "prestigeReady", cast = first.id, coins = 0, rank = 1 } }, ready)
		end)

		it("comes again for the next climb, with its rank (LED-R97)", function()
			local state = stateAt(TO_60)
			applyAll({ log.prestige(T0, 1) }, "live", state)
			state.xp = TO_60_HALF - 1
			local cast = log.cast(T0 + 60)
			local _, earned = applyAll({ cast }, "live", state)

			assert.are.same({ kind = "prestigeReady", cast = cast.id, coins = 0, rank = 1 }, earned[#earned])
		end)
	end)

	describe("the peak level (LED-R35)", function()
		it("is the level at rank 0 and stays 60 after a Prestige, whatever the new climb's level", function()
			local state = stateAt(TO_60 + 3000)
			assert.are.equal(60, ns.PeakLevel(state))

			applyAll({ log.prestige(T0, 1) }, "live", state)

			assert.are.same({ 5, 60 }, { ns.Level(state), ns.PeakLevel(state) })
			assert.are.equal(3, ns.PeakLevel(stateAt(1080 + 1160)))
		end)
	end)

	describe("emblems (LED-R34)", function()
		it("gives emblem I at rank 1 and X at 10, with no stars, and none at rank 0", function()
			assert.are.same({ stars = 0 }, ns.PrestigeMark(0))
			assert.are.same({ emblem = "I", stars = 0 }, ns.PrestigeMark(1))
			assert.are.same({ emblem = "IV", stars = 0 }, ns.PrestigeMark(4))
			assert.are.same({ emblem = "IX", stars = 0 }, ns.PrestigeMark(9))
			assert.are.same({ emblem = "X", stars = 0 }, ns.PrestigeMark(10))
		end)

		it("gives X with rank − 10 stars from rank 11, the Master Prestiges", function()
			assert.are.same({ emblem = "X", stars = 1 }, ns.PrestigeMark(11))
			assert.are.same({ emblem = "X", stars = 2 }, ns.PrestigeMark(12))
			assert.are.same({ emblem = "X", stars = 15 }, ns.PrestigeMark(25))
		end)
	end)

	describe("when Prestige is allowed (LED-R33)", function()
		it("only while the climb's computed level is 60 and the projection isn't updating", function()
			assert.is_false(ns.PrestigeAllowed(stateAt(TO_60 - 1), false))
			assert.is_true(ns.PrestigeAllowed(stateAt(TO_60), false))
			assert.is_false(ns.PrestigeAllowed(stateAt(TO_60), true))
			assert.is_true(ns.PrestigeAllowed(stateAt(TO_60_HALF, 4), false))
			assert.is_false(ns.PrestigeAllowed(stateAt(TO_60_HALF, 0), false))
			assert.is_false(ns.PrestigeAllowed(nil, false))
		end)
	end)
end)
