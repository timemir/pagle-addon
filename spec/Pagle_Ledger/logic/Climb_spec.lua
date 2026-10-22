-- The Ledger's climb at 1.0 (LED-R30–R32, LED-R37–R39, LED-R88, AXP-R4, AXP-R8, ADR 0011) through its logic/ with no
-- Core: the full Prestige cost, the climb's Activity XP read from Core's total and never stored, the level and Coins
-- worked out from both, the Prestige entries' snapshots, and the level-ups the Activity XP brings, from the fold, the
-- projection's done and ActivityXPChanged. Hand-made records with no catalogue, worth only their Skill Milestone XP.

local T0 = SERVER_TIME - 700
-- What reaching level 60 costs, in every climb (LED-R30): the steps from 1 to 59, at 1,000 + 80 × L each.
local TO_60 = 200600

-- A deep copy of `value`, to compare a state with itself as it was.
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, field in pairs(value) do
		copy[key] = deepCopy(field)
	end
	return copy
end

describe("the climb at 1.0", function()
	local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
	local ns = loaded.ns
	local lookups = {
		GetItem = function() end,
		MatchesConditions = loaded.env.Pagle.MatchesConditions,
		world = ns.NewWorld({
			GetItem = function() end,
			GetZones = function()
				return {}
			end,
			GetArea = function() end,
			GetZoneCatches = function()
				return {}
			end,
		}),
	}

	local fold, seq
	-- Core's Activity XP total, as ns.ActivityXPTotal reads it in these specs (the adapter's source reads Core).
	local total
	before_each(function()
		fold = ns.NewLedgerFold(lookups)
		seq = 0
		total = 0
		ns.SetActivityXPSource(function()
			return total
		end)
	end)
	after_each(function()
		ns.SetActivityXPSource(nil)
	end)

	-- A Skill Reading at `rank` (LOG-R31): 1,000 XP for each Skill Milestone it credits (LED-R40).
	local function skill(rank)
		seq = seq + 1
		return {
			seq = seq,
			id = ("%s-%d-%d"):format(PLAYER_GUID, T0 + seq, seq),
			kind = "skill",
			char = 1,
			time = T0 + seq,
			rank = rank,
			max = 300,
			mod = 0,
		}
	end

	-- A Prestige entry to `rank` (LOG-R38), with Core's Activity XP snapshot `activityXP` (AXP-R5; none for an old P1).
	local function prestige(rank, activityXP)
		seq = seq + 1
		return {
			seq = seq,
			id = ("%s-%d-%d"):format(PLAYER_GUID, T0 + seq, seq),
			kind = "prestige",
			char = 1,
			time = T0 + seq,
			rank = rank,
			activityXP = activityXP,
		}
	end

	-- A fresh state at prestige rank `rank` with the climb's own XP at `xp` and the latest Prestige snapshot `snapshot`.
	local function stateAt(xp, rank, snapshot)
		local state = fold.reset()
		state.xp, state.prestige, state.prestigeActivityXP = xp, rank or 0, snapshot or 0
		return state
	end

	describe("the full Prestige cost (LED-R30)", function()
		it("costs 1,000 + 80 × L a step in every climb: after a Prestige, level 1 to 2 costs 1,080", function()
			assert.are.same({ 1080, 5720 }, { ns.StepCost(1), ns.StepCost(59) })
			assert.are.same({ 1, 0, 1080 }, { ns.Climb(stateAt(0, 1), 0) })
			assert.are.same({ 2, 0, 1160 }, { ns.Climb(stateAt(1080, 12), 0) })
		end)

		it("reaches 60 at 200,600 XP after a Prestige too, carrying what's past it", function()
			assert.are.same({ 59, 5719, 5720 }, { ns.Climb(stateAt(TO_60 - 1, 1), 0) })
			assert.are.same({ 60, 4321 }, { ns.Climb(stateAt(TO_60 + 4321, 2), 0) })
		end)
	end)

	describe("the current climb's Activity XP (LED-R37)", function()
		it("is Core's whole total before the first Prestige", function()
			assert.are.equal(2000, ns.ClimbActivityXP(stateAt(0), 2000))
		end)

		it("is the total less the latest Prestige entry's snapshot: 5,600 after 5,000 gives 600 (AXP-R5)", function()
			assert.are.equal(600, ns.ClimbActivityXP(stateAt(0, 1, 5000), 5600))
		end)

		it("is never below 0 when a total is recounted lower (AXP-R4)", function()
			assert.are.equal(0, ns.ClimbActivityXP(stateAt(0, 1, 5000), 4000))
		end)

		it("reads Core's total through ns.ActivityXPTotal when none is passed, 0 in logic/ alone", function()
			total = 750
			assert.are.same({ 750, 1250 }, { ns.ClimbActivityXP(stateAt(500)), ns.ClimbXP(stateAt(500)) })
			ns.SetActivityXPSource(nil)
			assert.are.same({ 0, 0 }, { ns.ActivityXPTotal(), ns.ClimbActivityXP(stateAt(500)) })
		end)

		it("is read, never stored: working out the level leaves the state as it was (LED-R37, ADR 0011)", function()
			local state = applyLive(fold, { skill(80) })
			local before = deepCopy(state)
			total = 5000

			assert.are.equal(5, ns.Level(state))
			assert.are.same(before, state)
		end)
	end)

	describe("the level from both (LED-R38)", function()
		it(
			"rises with 2,000 Activity XP as 2,000 more of the Ledger's own XP would, never doubled (LED-R22)",
			function()
				local state = stateAt(0)

				assert.are.same({ ns.Climb(stateAt(2000), 0) }, { ns.Climb(state, 2000) })
				assert.are.same({ 2, 920, 1160 }, { ns.Climb(state, 2000) })
				assert.are.equal(ns.FRESH_WATER_CAP, state.fresh)
			end
		)

		it("falls back with a lower recount: the computed level follows the total (LED-R38, AXP-R4)", function()
			local state = stateAt(0)

			assert.are.same({ 2, 1 }, { ns.Level(state, 2000), ns.Level(state, 0) })
		end)

		it("makes the peak level and Prestige allowed with it (LED-R35, LED-R33)", function()
			local state = stateAt(TO_60 - 300)
			total = 300

			assert.are.same({ 60, 59 }, { ns.PeakLevel(state), ns.OwnLevel(state) })
			assert.is_true(ns.PrestigeAllowed(state, false))
			total = 299
			assert.is_false(ns.PrestigeAllowed(state, false))
		end)
	end)

	describe("Coins for levels (LED-R38, LED-R88)", function()
		it("pay 20 for each level the Activity XP adds above the climb's own, in the lifetime total", function()
			-- 1,000 own XP from a Skill Milestone, which pays no Coins: level 1. With 1,240 Activity XP the climb is
			-- 2,240, level 3 (LED-R30).
			local state = applyLive(fold, { skill(80) })

			assert.are.same({ 0, 0 }, { state.coins, ns.CoinsEarned(state, 0) })
			assert.are.equal(40, ns.CoinsEarned(state, 1240))
			total = 1240
			assert.are.equal(40, ns.CoinsEarned(state))
			-- A total recounted lower takes its levels' Coins back out of the total (SHOP-R4).
			assert.are.equal(20, ns.CoinsEarned(state, 1000))
		end)
	end)

	describe("the fold (LED-R3, LED-R31)", function()
		it(
			"raises a live entry's levelUp from the climb with the Activity XP passed in, its state the same as without it",
			function()
				local live, rebuilt = fold.reset(), fold.reset()
				local record = skill(80)
				local earned = fold.apply(live, record, "live", nil, 100)
				local without = fold.apply(rebuilt, record, "rebuild")

				-- 1,000 own XP and 100 Activity XP reach level 2 (LED-R30): its 20 Coins ride on the moment, and stay
				-- out of the state, which holds only the own level's (LED-R88).
				assert.are.same({
					{ kind = "skillMilestone", coins = 0, threshold = 75 },
					{ kind = "levelUp", coins = 20, levels = { 2 } },
				}, earned)
				assert.are.same({ { kind = "skillMilestone", coins = 0, threshold = 75 } }, without)
				assert.are.same(rebuilt, live)
				assert.are.same({ 0, 20 }, { live.coins, ns.CoinsEarned(live, 100) })
			end
		)

		it(
			"keeps the Ledger's own lifetime XP across a Prestige, apart from the climb's (LED-R150's All told)",
			function()
				local state = applyLive(fold, { skill(160), prestige(1, 0), skill(300) })

				assert.are.same({ 4000, 2000 }, { state.lifetimeXP, state.xp })
			end
		)
	end)

	describe("applying a Prestige entry (LED-R32, LED-R37)", function()
		it(
			"ends the climb with its own XP and the Activity XP since the last snapshot, carrying what passes 60",
			function()
				-- Own XP 2,000 short of 60 (level 59); the entry's 5,000 Activity XP takes the ending climb 3,000 past
				-- it. The new climb starts there: 1,080 + 1,160 to level 3, 760 into its 1,240 step (LED-R30).
				local state = stateAt(TO_60 - 2000)
				total = 5000
				local _, earned = applyLive(fold, { prestige(1, 5000) }, state)

				assert.are.same({ 1, 3000, 5000 }, { state.prestige, state.xp, state.prestigeActivityXP })
				assert.are.same({ 3, 760, 1240 }, { ns.Climb(state) })
				assert.are.same({
					{ kind = "prestige", coins = 100, rank = 1 },
					{ kind = "levelUp", coins = 40, levels = { 2, 3 } },
				}, earned)
				-- The ending climb's level 60, which its Activity XP brought (20), the Prestige (100) and the new climb's
				-- levels 2 and 3 (40), kept in the state now the snapshot fixes them (LED-R88).
				assert.are.same({ 160, 160 }, { state.coins, ns.CoinsEarned(state) })
			end
		)

		it("gives an earlier climb the gap between its two snapshots, never below 0", function()
			local rose = stateAt(TO_60 - 100, 1, 5000)
			applyLive(fold, { prestige(2, 5300) }, rose)
			local fell = stateAt(TO_60 - 100, 1, 5000)
			applyLive(fold, { prestige(2, 4000) }, fell)

			-- 300 Activity XP in the climb carries 200 past 60; a lower snapshot gives it none, and it hadn't reached 60.
			assert.are.same({ 200, 5300 }, { rose.xp, rose.prestigeActivityXP })
			assert.are.same({ 0, 4000 }, { fell.xp, fell.prestigeActivityXP })
			total = 4600
			assert.are.equal(600, ns.ClimbActivityXP(fell))
		end)

		it(
			"starts the new climb above level 1 when Activity XP had passed 60, its level-ups the Prestige entry's",
			function()
				local state = stateAt(TO_60 - 1000)
				local _, earned = applyLive(fold, { prestige(1, 3240) }, state, "rebuild")

				assert.are.same({ 3, 0, 1240 }, { ns.Climb(state, 3240) })
				assert.are.same({ kind = "levelUp", coins = 40, levels = { 2, 3 } }, earned[2])
				assert.is_nil(earned[2].cast)
			end
		)

		it("takes an old P1's missing snapshot as 0 (AXP-R5)", function()
			local state = stateAt(TO_60, 0, 0)
			applyLive(fold, { prestige(1) }, state)

			assert.are.same({ 0, 1 }, { state.prestigeActivityXP, ns.Level(state, 0) })
		end)

		it("is the same state in live, replay and rebuild mode, whatever Core's total (LED-R3, ADR 0011)", function()
			local function from(mode, activity)
				seq = 0
				local state = stateAt(TO_60 - 2000)
				for _, record in ipairs({ skill(300), prestige(1, 5000), skill(300) }) do
					fold.apply(state, record, mode, nil, activity)
				end
				return state
			end

			assert.are.same(from("rebuild"), from("live", 9000))
			assert.are.same(from("rebuild"), from("replay"))
		end)
	end)

	describe("the level-ups Activity XP brings (LED-R39)", function()
		it("are one levelUp for the levels above the climb's own, with its rank and the Cast it rides on", function()
			assert.are.same(
				{ { kind = "levelUp", cast = "c-1", coins = 20, levels = { 2 }, rank = 1 } },
				ns.ActivityLevelUps(stateAt(0, 1), 2000, "c-1")
			)
		end)

		it("add Prestige ready when they reach 60 (LED-R97)", function()
			assert.are.same({
				{ kind = "levelUp", coins = 20, levels = { 60 }, rank = 0 },
				{ kind = "prestigeReady", coins = 0, rank = 0 },
			}, ns.ActivityLevelUps(stateAt(TO_60 - 10), 10))
		end)

		it("are none when the Activity XP adds no level", function()
			assert.are.same({}, ns.ActivityLevelUps(stateAt(0), 1000))
		end)
	end)

	describe("the projection def (LED-R39, LED-R93)", function()
		-- Outlets that keep every moment raised, Coins reported, summary line set and Write-up raised, in order.
		local function keeping()
			local kept = { moments = {}, coins = {}, lines = {}, writeUps = {}, goods = 0 }
			return kept,
				{
					RaiseMoment = function(moment)
						table.insert(kept.moments, moment)
					end,
					ReportCoinsEarned = function(coins)
						table.insert(kept.coins, coins)
					end,
					SetSummaryLine = function(text)
						table.insert(kept.lines, text)
					end,
					ItemName = function() end,
					AreaName = function() end,
					RaiseWriteUp = function(section)
						table.insert(kept.writeUps, { section.heading, unpack(section.lines) })
					end,
					LogId = function()
						return "log"
					end,
					FormatNumber = tostring,
					RefreshGoods = function()
						kept.goods = kept.goods + 1
					end,
					SizeText = function() end,
					ZoneCrest = function() end,
				}
		end

		-- A def over a fresh PagleLedgerDB.global with a first build done over `records` (none by default), and its
		-- ActivityXPChanged handler.
		local function built(records)
			local kept, outlets = keeping()
			local global = {}
			local def, changed = ns.ProjectionDef(global, lookups, outlets)
			local state = def.reset()
			for _, record in ipairs(records or {}) do
				def.apply(state, record, "rebuild")
			end
			def.done(state, { firstBuild = true, rebuilt = true, replayed = 0 })
			kept.moments, kept.coins, kept.lines, kept.goods = {}, {}, {}, 0
			return def, changed, state, kept, global
		end

		it(
			"on ActivityXPChanged from a live Cast raises the levelUp with its ID, then reports Coins and the line",
			function()
				local _, changed, state, kept, global = built({ skill(80) })
				total = 100

				changed(state, { kind = "cast", id = "cast-7" })

				assert.are.equal(1, #kept.moments)
				local moment = kept.moments[1]
				assert.are.same(
					{ "levelUp", "Angler Level 2", "cast-7", 20 },
					{ moment.kind, moment.title, moment.cast, moment.coins }
				)
				assert.is_nil(moment.summaryOnly)
				assert.are.same({ 20 }, kept.coins)
				assert.are.same({ "Ledger: Angler Level 2 · 0% complete" }, kept.lines)
				assert.are.same({ 2, 20 }, { global.celebrated.levels[0], global.celebrated.coins })
			end
		)

		it("raises it summary-only with no entry, a report from another Module's done (ANN-R63)", function()
			local _, changed, state, kept = built({ skill(80) })
			total = 100

			changed(state, nil)

			assert.are.same({ "levelUp", true }, { kept.moments[1].kind, kept.moments[1].summaryOnly })
			assert.is_nil(kept.moments[1].cast)
		end)

		it("raises it summary-only, without `cast`, for a Module record's live apply", function()
			local _, changed, state, kept = built({ skill(80) })
			total = 100

			changed(state, { kind = "module", id = "rec-3", module = "TackleBoard" })

			assert.are.same({ true }, { kept.moments[1].summaryOnly })
			assert.is_nil(kept.moments[1].cast)
		end)

		it("never lowers the shown level for a lower recount, and takes its Coins back (LED-R38, LED-R36)", function()
			local _, changed, state, kept, global = built({ skill(80) })
			total = 100
			changed(state, nil)
			kept.moments, kept.coins = {}, {}

			total = 0
			changed(state, nil)

			assert.are.same({}, kept.moments)
			assert.are.same({ 0 }, kept.coins)
			assert.are.same({ 2, 2 }, { global.celebrated.levels[0], ns.ShownLevel(state, global.celebrated) })
			local bar = ns.InkXpBar(state, global.celebrated, SERVER_TIME, tostring)
			assert.are.equal("0 of 1160.", bar.text)
		end)

		it("raises nothing again for a level already celebrated, and reports no unchanged Coins (LED-R91)", function()
			local _, changed, state, kept = built({ skill(80) })
			total = 100
			changed(state, nil)
			kept.moments, kept.coins = {}, {}

			total = 150
			changed(state, nil)

			assert.are.same({}, kept.moments)
			assert.are.same({}, kept.coins)
		end)

		it("refreshes the goods when the peak level passes a multiple of 10 (LED-R111)", function()
			-- 4 Skill Milestones, 4,000 own XP: level 4. Reaching 10 takes 12,600 in all, and 9 takes 10,880 (LED-R30).
			local _, changed, state, kept = built({ skill(300) })
			total = 7000
			changed(state, nil)
			assert.are.equal(0, kept.goods)

			total = 8600
			changed(state, nil)
			assert.are.equal(1, kept.goods)
		end)

		it("celebrates a rebuild's Activity XP levels in its done, summary-only (LED-R93, LED-R191)", function()
			local def, _, _, kept, global = built({ skill(80) })
			local state = def.reset()
			def.apply(state, skill(80), "rebuild")
			total = 1240

			def.done(state, { rebuilt = true, replayed = 0 })

			local moment = kept.moments[1]
			assert.are.same({ "Angler Level 3", true, 40 }, { moment.title, moment.summaryOnly, moment.coins })
			assert.are.same({ 3, 40 }, { global.celebrated.levels[0], global.celebrated.coins })
			assert.are.same({ 40 }, kept.coins)
		end)

		it("celebrates in its done the Activity XP that rose while it was updating, summary-only (LED-R39)", function()
			local def, _, state, kept = built({ skill(80) })
			total = 100

			def.done(state, { replayed = 0 })

			assert.are.same({ "levelUp", true }, { kept.moments[1].kind, kept.moments[1].summaryOnly })
			assert.are.same({ 20 }, kept.coins)
		end)

		it("counts a catch-up's Activity XP levels in its Write-up (LED-R93, LED-R94)", function()
			local def, _, state, kept = built({ skill(80) })
			def.apply(state, skill(160), "replay")
			total = 300

			def.done(state, { replayed = 1 })

			-- 2,000 own XP and 300 Activity XP: level 3 (LED-R30).
			assert.are.same({}, kept.moments)
			assert.are.same({
				{ "While the Ledger was off", "Angler Level 1 to 3", "1 Skill Milestone", "Pagle Coins +40" },
			}, kept.writeUps)
		end)

		it("marks a first build's level from both celebrated, with no moment (LED-R93)", function()
			total = 1240
			local _, _, _, _, global = built({ skill(80) })

			assert.are.same({ 3, 40 }, { global.celebrated.levels[0], global.celebrated.coins })
		end)

		it("reports the live entry's Coins with the Activity XP's levels (LED-R89)", function()
			local def, _, state, kept = built()
			total = 100

			def.apply(state, skill(80), "live")

			assert.are.same({ "skillMilestone", "levelUp" }, { kept.moments[1].kind, kept.moments[2].kind })
			assert.are.same({ 20 }, kept.coins)
		end)
	end)
end)
