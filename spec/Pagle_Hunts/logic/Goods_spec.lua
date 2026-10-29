-- Hunts' earned goods (HNT-R122, HNT-R123): when each is owned, read from the projection's state and the celebrated
-- set (HNT-R90) together, over hand-made states in hunts.md › Projection state's shape and the fixture Hunt list's
-- four sets (fixture_dusk, fixture_wagers, fixture_pair and fixture_tide).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local SETS = { "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide" }

-- The goods earned with every set's title (HNT-R122): Five-Set Seal, and Night Watch in Core's sound set slot (HNT-R123).
local EVERY_SET = { "hunts.binding.fiveseal", "hunts.soundset.nightwatch" }

-- A set title's record in state.sets (HuntsSetTitle).
local TITLE = { earnedAt = hunts.JAN_1, date = { year = 2026, month = 1, day = 1 }, fromRetirement = false }

-- A celebrated set with `fields` over an empty one.
---@param fields table?
---@return HuntsCelebrated
local function celebrated(fields)
	local set = { tiers = {}, sets = {}, runs = {}, ladder = {} }
	for key, value in pairs(fields or {}) do
		set[key] = value
	end
	return set
end

-- A state whose set titles are `sets` (setID list) and whose completed-run count is `settled`.
---@param ns table
---@param sets string[]?
---@param settled integer?
---@return HuntsState
local function stateWith(ns, sets, settled)
	local state = ns.NewHuntsState()
	for _, setID in ipairs(sets or {}) do
		state.sets[setID] = TITLE
	end
	state.settled = settled or 0
	return state
end

-- `n` celebrated run entries, the first `completed` of them with their completion shown (HNT-R90, HNT-R92).
---@param n integer
---@param completed integer
---@return table<string, HuntsCelebratedRun>
local function celebratedRuns(n, completed)
	local runs = {}
	for i = 1, n do
		runs["fixture_vale@" .. i] = { tiers = {}, settled = i <= completed or nil, endsAt = hunts.JAN_1 + i }
	end
	return runs
end

describe("Hunts' earned goods", function()
	local ns = hunts.load().ns
	local list = ns.huntList.sets

	-- Whether `goodID`'s rule holds over `state` and `set`.
	local function earned(goodID, state, set)
		return ns.HuntsGoodEarned(ns.HuntsGoodRule(goodID), state, set, list)
	end

	it("give each earned good its rule, and no other good one (HNT-R122, HNT-R123)", function()
		assert.are.same({
			"anySetTitle",
			"everySetTitle",
			"wagerRuns",
			"wagerRuns",
			"everySetTitle",
			"nightTide",
			"deepTrench",
			"wagerCentury",
		}, {
			ns.HuntsGoodRule("hunts.binding.pathfinder"),
			ns.HuntsGoodRule("hunts.binding.fiveseal"),
			ns.HuntsGoodRule("hunts.binding.wagersilk"),
			ns.HuntsGoodRule("hunts.trackerframe.wagerribbon"),
			ns.HuntsGoodRule("hunts.soundset.nightwatch"),
			ns.HuntsGoodRule("hunts.toaststyle.nightfin"),
			ns.HuntsGoodRule("hunts.toaststyle.trench"),
			ns.HuntsGoodRule("hunts.toaststyle.study"),
		})
		assert.is_nil(ns.HuntsGoodRule("core.binding.trophycase"))
		assert.is_nil(ns.HuntsGoodRule("core.binding.field"))
	end)

	describe("Pathfinder's Calf", function()
		local ID = "hunts.binding.pathfinder"

		it("is earned with any set's title in the projection (HNT-R122, HNT-R20)", function()
			assert.is_false(earned(ID, stateWith(ns), celebrated()))
			assert.is_true(earned(ID, stateWith(ns, { "fixture_pair" }), celebrated()))
		end)

		it(
			"is earned with a set title the celebrated set holds, the projection without it: never lost (HNT-R122, HNT-R90)",
			function()
				-- A rebuild over changed definitions (before 1.0) no longer finds the title; it was shown, so it stays.
				assert.is_true(earned(ID, stateWith(ns), celebrated({ sets = { fixture_tide = true } })))
			end
		)

		it("reads the celebrated set alone while there is no state to read (HNT-R122, SHOP-R31)", function()
			assert.is_false(earned(ID, nil, celebrated()))
			assert.is_true(earned(ID, nil, celebrated({ sets = { fixture_dusk = true } })))
			assert.is_false(earned(ID, nil, {})) -- a celebrated set saved bare, before its defaults are filled in
		end)
	end)

	describe("Five-Set Seal and Night Watch", function()
		it(
			"are earned with every set's title, each in the projection or the celebrated set (HNT-R122, HNT-R123, HNT-R20)",
			function()
				for _, id in ipairs(EVERY_SET) do
					assert.are.equal(true, earned(id, stateWith(ns, SETS), celebrated()), id)
					assert.are.equal(
						true,
						earned(
							id,
							stateWith(ns, { "fixture_dusk", "fixture_wagers" }),
							celebrated({ sets = { fixture_pair = true, fixture_tide = true } })
						),
						id
					)
					assert.are.equal(
						true,
						earned(
							id,
							nil,
							celebrated({
								sets = {
									fixture_dusk = true,
									fixture_wagers = true,
									fixture_pair = true,
									fixture_tide = true,
								},
							})
						),
						id
					)
				end
			end
		)

		it("aren't earned while one set's title is missing from both (HNT-R122, HNT-R123)", function()
			for _, id in ipairs(EVERY_SET) do
				local state = stateWith(ns, { "fixture_dusk", "fixture_wagers" })
				assert.are.equal(false, earned(id, state, celebrated({ sets = { fixture_pair = true } })), id)
				assert.are.equal(false, earned(id, nil, celebrated()), id)
			end
		end)

		it("aren't earned over a Hunt list with no sets (HNT-R122)", function()
			assert.is_false(ns.HuntsGoodEarned("everySetTitle", stateWith(ns, SETS), celebrated(), {}))
		end)
	end)

	describe("Winner's Brocade and Winner's Ribbon", function()
		local IDS = { "hunts.binding.wagersilk", "hunts.trackerframe.wagerribbon" }

		it("are earned at ten completed runs, the projection's completed-run count (HNT-R122, HNT-R148)", function()
			assert.are.equal(10, ns.WAGER_GOODS_RUNS)
			for _, id in ipairs(IDS) do
				assert.are.equal(false, earned(id, stateWith(ns, nil, 9), celebrated()), id)
				assert.are.equal(true, earned(id, stateWith(ns, nil, 10), celebrated()), id)
				assert.are.equal(true, earned(id, stateWith(ns, nil, 31), celebrated()), id)
			end
		end)

		it("count a run only once completed, not merely joined (HNT-R122, HNT-R146)", function()
			-- Twelve runs shown, nine of them completed.
			for _, id in ipairs(IDS) do
				assert.are.equal(false, earned(id, nil, celebrated({ runs = celebratedRuns(12, 9) })), id)
				assert.are.equal(true, earned(id, nil, celebrated({ runs = celebratedRuns(12, 10) })), id)
			end
		end)

		it(
			"are never lost: the celebrated set's completed runs or a ladder title shown stand when the projection has fewer (HNT-R122, HNT-R90, HNT-R148)",
			function()
				for _, id in ipairs(IDS) do
					assert.are.equal(
						true,
						earned(id, stateWith(ns, nil, 4), celebrated({ runs = celebratedRuns(10, 10) })),
						id
					)
					-- The run entries dropped 30 days after their runs (HNT-R92): Bookmaker's Bane at 25 still shows it.
					assert.are.equal(
						true,
						earned(id, stateWith(ns, nil, 0), celebrated({ ladder = { [25] = true } })),
						id
					)
				end
			end
		)
	end)

	describe("Nat's Study (ANN-R85, HNT-R148)", function()
		local ID = "hunts.toaststyle.study"

		it("is earned at 100 completed runs, not 99, as the ladder counts them", function()
			assert.are.equal(100, ns.WAGER_STUDY_RUNS)
			assert.are.equal(false, earned(ID, stateWith(ns, nil, 99), celebrated()))
			assert.are.equal(true, earned(ID, stateWith(ns, nil, 100), celebrated()))
			assert.are.equal(true, earned(ID, stateWith(ns, nil, 140), celebrated()))
		end)

		it("counts the runs the celebrated set shows and the ladder title at 100, so a prune never loses it", function()
			assert.are.equal(false, earned(ID, nil, celebrated({ runs = celebratedRuns(120, 99) })))
			assert.are.equal(true, earned(ID, nil, celebrated({ runs = celebratedRuns(120, 100) })))
			assert.are.equal(false, earned(ID, nil, celebrated({ ladder = { [25] = true, [50] = true } })))
			assert.are.equal(true, earned(ID, nil, celebrated({ ladder = { [100] = true } })))
		end)

		it("says what earns it with its own count, as the Winner's goods say theirs", function()
			assert.are.same({ "10 Wager runs completed", "100 Wager runs completed" }, {
				ns.HuntsEarnedText("wagerRuns"),
				ns.HuntsEarnedText("wagerCentury"),
			})
		end)
	end)

	-- A run of `event` in a state, with each of its Hunts `reached` tiers deep (hunts.md › Projection state).
	---@param state HuntsState
	---@param event string
	---@param start integer
	---@param tiers table<string, integer>
	local function addRun(state, event, start, tiers)
		local progress = {}
		for huntID, count in pairs(tiers) do
			local reached = {}
			for tier = 1, count do
				reached[tier] = { time = start + tier, catchId = "c", itemID = 1, zone = 1 }
			end
			progress[huntID] = { count = count, effort = 0, sinceLast = 0, caught = true, reached = reached }
		end
		state.runs[ns.RunKey(event, start)] =
			{ event = event, start = start, end_ = start + 100, source = "r", hunts = progress }
	end
	local HUNTS_OF = {
		azshara_lobster = {
			"azshara_lobster_haul",
			"azshara_lobster_lobster",
			"azshara_lobster_yellowtail",
			"azshara_lobster_night",
		},
	}
	local function huntsOf(eventID)
		return HUNTS_OF[eventID]
	end
	local function holds(rule, state, set)
		return ns.HuntsGoodEarned(rule, state, set or celebrated(), list, huntsOf)
	end

	describe("Nightfin Tide (ANN-R85, HNT-R122)", function()
		it("is earned with three different night-event Hunts at tier 3, not two", function()
			local state = stateWith(ns)
			addRun(
				state,
				"darkshore_moonlight",
				1000,
				{ darkshore_moonlight_haul = 3, darkshore_moonlight_grouper = 3 }
			)
			assert.is_false(holds("nightTide", state))

			addRun(state, "felwood_moonglade", 2000, { felwood_moonglade_haul = 3 })
			assert.is_true(holds("nightTide", state))
		end)

		it("takes two from one event, and counts a Hunt that reached tier 3 in two runs once", function()
			local state = stateWith(ns)
			addRun(state, "darkshore_moonlight", 1000, { darkshore_moonlight_haul = 3 })
			addRun(state, "darkshore_moonlight", 5000, { darkshore_moonlight_haul = 3 })
			assert.is_false(holds("nightTide", state))

			addRun(
				state,
				"darkshore_moonlight",
				9000,
				{ darkshore_moonlight_snapper = 3, darkshore_moonlight_grouper = 3 }
			)
			assert.is_true(holds("nightTide", state))
		end)

		it("needs tier 3 itself, not tier 2, and an event of the six, not any other", function()
			local state = stateWith(ns)
			addRun(
				state,
				"darkshore_moonlight",
				1000,
				{ darkshore_moonlight_haul = 3, darkshore_moonlight_snapper = 3, darkshore_moonlight_grouper = 2 }
			)
			assert.is_false(holds("nightTide", state))
			-- A daylight event's Hunt at tier 3 is no night Hunt.
			addRun(state, "winterspring_daylight", 2000, { winterspring_daylight_haul = 3 })
			addRun(state, "azshara_lobster", 3000, { azshara_lobster_haul = 3 })
			assert.is_false(holds("nightTide", state))

			for _, event in ipairs({
				"felwood_moonglade",
				"dustwallow_marsh_night",
				"deadwind_pass_night",
				"eastern_plaguelands_night",
				"tirisfal_silverpine_dusk",
			}) do
				local one = stateWith(ns)
				addRun(one, event, 1000, { [event .. "_a"] = 3, [event .. "_b"] = 3, [event .. "_c"] = 3 })
				assert(holds("nightTide", one), event)
			end
		end)

		it(
			"counts the tiers the celebrated set shows for a run, so a pruned or rebuilt run never loses them",
			function()
				local set = celebrated({
					runs = {
						["darkshore_moonlight@1000"] = { tiers = { a = 3, b = 3 }, endsAt = 1 },
						["tirisfal_silverpine_dusk@2000"] = { tiers = { c = 2 }, endsAt = 1 },
					},
				})
				assert.is_false(holds("nightTide", nil, set))
				set.runs["tirisfal_silverpine_dusk@2000"].tiers.c = 3
				assert.is_true(holds("nightTide", nil, set))
				-- The projection's lower tier doesn't lower the shown one.
				local state = stateWith(ns)
				addRun(state, "tirisfal_silverpine_dusk", 2000, { c = 1 })
				assert.is_true(holds("nightTide", state, set))
			end
		)
	end)

	describe("The Deep Trench (ANN-R85, HNT-R122)", function()
		local ALL = {
			azshara_lobster_haul = 3,
			azshara_lobster_lobster = 3,
			azshara_lobster_yellowtail = 3,
			azshara_lobster_night = 3,
		}

		it("is earned by one lobster run with every Hunt at tier 3", function()
			local state = stateWith(ns)
			addRun(state, "azshara_lobster", 1000, ALL)
			assert.is_true(holds("deepTrench", state))
		end)

		it("isn't earned with one Hunt at tier 2, or one Hunt not reached", function()
			local state = stateWith(ns)
			addRun(state, "azshara_lobster", 1000, {
				azshara_lobster_haul = 3,
				azshara_lobster_lobster = 3,
				azshara_lobster_yellowtail = 3,
				azshara_lobster_night = 2,
			})
			assert.is_false(holds("deepTrench", state))
			local fewer = stateWith(ns)
			addRun(
				fewer,
				"azshara_lobster",
				1000,
				{ azshara_lobster_haul = 3, azshara_lobster_lobster = 3, azshara_lobster_yellowtail = 3 }
			)
			assert.is_false(holds("deepTrench", fewer))
		end)

		it("takes its Hunts from one run: two runs each short of a Hunt don't add up", function()
			local state = stateWith(ns)
			addRun(state, "azshara_lobster", 1000, { azshara_lobster_haul = 3, azshara_lobster_lobster = 3 })
			addRun(state, "azshara_lobster", 5000, { azshara_lobster_yellowtail = 3, azshara_lobster_night = 3 })
			assert.is_false(holds("deepTrench", state))
			-- Another event's run, however deep, is no lobster run.
			addRun(state, "darkshore_moonlight", 9000, ALL)
			assert.is_false(holds("deepTrench", state))
		end)

		it(
			"reads the celebrated run when the projection is short, and isn't earned over an event the pool lacks",
			function()
				local set = celebrated({ runs = { ["azshara_lobster@1000"] = { tiers = ALL, endsAt = 1 } } })
				assert.is_true(holds("deepTrench", nil, set))
				assert.is_false(ns.HuntsGoodEarned("deepTrench", nil, set, list, function()
					return nil
				end))
				assert.is_false(ns.HuntsGoodEarned("deepTrench", nil, set, list, function()
					return {}
				end))
			end
		)

		it("reads the pool's event by default: its Hunts in file order", function()
			assert.is_nil(ns.EventHuntIDs("azshara_lobster")) -- the fixture pool has no such event
			assert.are.same(
				{ "fixture_vale_haul", "fixture_vale_blackmouth", "fixture_vale_uncommon" },
				ns.EventHuntIDs("fixture_vale")
			)
		end)
	end)

	describe("kept once earned, in the celebrated set's goods", function()
		local ALL = {
			"hunts.binding.pathfinder",
			"hunts.binding.fiveseal",
			"hunts.binding.wagersilk",
			"hunts.trackerframe.wagerribbon",
			"hunts.soundset.nightwatch",
			"hunts.toaststyle.nightfin",
			"hunts.toaststyle.trench",
			"hunts.toaststyle.study",
		}

		-- Whether `goodID` is owned over `state`, `set` and the Hunt list's sets `sets` (the fixture's by default).
		local function owned(goodID, state, set, sets)
			return ns.HuntsGoodOwned(goodID, ns.HuntsGoodRule(goodID), state, set, sets or list)
		end

		it("list all eight earned goods, each with its rule (HNT-R122)", function()
			local ids = {}
			for _, good in ipairs(ns.HuntsEarnedGoods()) do
				ids[#ids + 1] = good.id
				assert.are.equal(ns.HuntsGoodRule(good.id), good.earned, good.id)
			end
			table.sort(ids)
			local want = { unpack(ALL) }
			table.sort(want)
			assert.are.same(want, ids)
		end)

		it(
			"own each of the five from the celebrated set's goods alone, with nothing else earning it (HNT-R122)",
			function()
				for _, id in ipairs(ALL) do
					assert.are.equal(false, owned(id, stateWith(ns), celebrated()), id)
					assert.are.equal(true, owned(id, stateWith(ns), celebrated({ goods = { [id] = true } })), id)
					assert.are.equal(true, owned(id, nil, { goods = { [id] = true } }), id) -- saved bare, before AceDB
				end
				-- Another good noted owns only that one.
				local set = celebrated({ goods = { ["hunts.binding.wagersilk"] = true } })
				assert.is_false(owned("hunts.trackerframe.wagerribbon", nil, set))
			end
		)

		it("own each while its rule holds, noted or not (HNT-R122)", function()
			assert.is_true(owned("hunts.binding.pathfinder", stateWith(ns, { "fixture_pair" }), celebrated()))
			assert.is_true(owned("hunts.binding.fiveseal", stateWith(ns, SETS), celebrated()))
			assert.is_true(owned("hunts.binding.wagersilk", stateWith(ns, nil, 10), celebrated()))
		end)

		it(
			"keep Five-Set Seal and Night Watch once noted when a release adds a set not yet titled (HNT-R122, HNT-R20)",
			function()
				local more = { unpack(list) }
				more[#more + 1] = { id = "fixture_later" }
				local set = celebrated({ sets = { fixture_dusk = true } })
				assert.is_true(ns.NoteHuntsGoods(set, stateWith(ns, SETS), list))
				for _, id in ipairs(EVERY_SET) do
					-- The rule no longer holds over the longer list; the note keeps the good.
					assert.are.equal(false, ns.HuntsGoodEarned("everySetTitle", stateWith(ns, SETS), set, more), id)
					assert.are.equal(true, owned(id, stateWith(ns, SETS), set, more), id)
					assert.are.equal(true, owned(id, nil, set, more), id)
				end
			end
		)

		it("note a good the first time its rule holds, and only then (HNT-R122, HNT-R90)", function()
			local set = celebrated()
			assert.is_false(ns.NoteHuntsGoods(set, stateWith(ns), list))
			assert.is_nil(set.goods) -- made with the first good noted

			assert.is_true(ns.NoteHuntsGoods(set, stateWith(ns, { "fixture_pair" }), list))
			assert.are.same({ ["hunts.binding.pathfinder"] = true }, set.goods)
			assert.is_false(ns.NoteHuntsGoods(set, stateWith(ns, { "fixture_pair" }), list)) -- noted already

			assert.is_true(ns.NoteHuntsGoods(set, stateWith(ns, SETS, 10), list))
			assert.are.same({
				["hunts.binding.pathfinder"] = true,
				["hunts.binding.fiveseal"] = true,
				["hunts.binding.wagersilk"] = true,
				["hunts.trackerframe.wagerribbon"] = true,
				["hunts.soundset.nightwatch"] = true,
			}, set.goods)

			-- The epic styles (ANN-R85) wait for their own rules: 100 runs for Nat's Study.
			assert.is_true(ns.NoteHuntsGoods(set, stateWith(ns, SETS, 100), list))
			assert.is_true(set.goods["hunts.toaststyle.study"])
			assert.is_nil(set.goods["hunts.toaststyle.nightfin"])
		end)

		it("note nothing over a bare celebrated set while no rule holds (HNT-R122, SHOP-R31)", function()
			local set = {}
			assert.is_false(ns.NoteHuntsGoods(set, nil, list))
			assert.are.same({}, set)
		end)
	end)

	it("counts completed runs as the most any of the three shows (HNT-R148, HNT-R90)", function()
		assert.are.same({ 0, 7, 3, 25, 50 }, {
			ns.CompletedRunCount(nil, {}),
			ns.CompletedRunCount(stateWith(ns, nil, 7), celebrated({ runs = celebratedRuns(5, 3) })),
			ns.CompletedRunCount(stateWith(ns, nil, 1), celebrated({ runs = celebratedRuns(5, 3) })),
			ns.CompletedRunCount(stateWith(ns, nil, 2), celebrated({ ladder = { [25] = true } })),
			ns.CompletedRunCount(nil, celebrated({ ladder = { [25] = true, [50] = true } })),
		})
	end)
end)
