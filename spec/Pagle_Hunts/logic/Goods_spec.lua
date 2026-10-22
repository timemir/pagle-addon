-- Hunts' earned goods (HNT-R122, HNT-R123): when each is owned, read from the projection's state and the celebrated
-- set (HNT-R90) together, over hand-made states in hunts.md › Projection state's shape and the fixture Hunt list's
-- four sets (fixture_dusk, fixture_wagers, fixture_pair and fixture_tide).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local SETS = { "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide" }

-- The goods earned with every set's title (HNT-R122): Four-Set Seal, and Night Watch in Core's sound set slot (HNT-R123).
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
		assert.are.same({ "anySetTitle", "everySetTitle", "wagerRuns", "wagerRuns", "everySetTitle" }, {
			ns.HuntsGoodRule("hunts.binding.pathfinder"),
			ns.HuntsGoodRule("hunts.binding.fiveseal"),
			ns.HuntsGoodRule("hunts.binding.wagersilk"),
			ns.HuntsGoodRule("hunts.trackerframe.wagerribbon"),
			ns.HuntsGoodRule("hunts.soundset.nightwatch"),
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

	describe("Four-Set Seal and Night Watch", function()
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

	describe("kept once earned, in the celebrated set's goods", function()
		local ALL = {
			"hunts.binding.pathfinder",
			"hunts.binding.fiveseal",
			"hunts.binding.wagersilk",
			"hunts.trackerframe.wagerribbon",
			"hunts.soundset.nightwatch",
		}

		-- Whether `goodID` is owned over `state`, `set` and the Hunt list's sets `sets` (the fixture's by default).
		local function owned(goodID, state, set, sets)
			return ns.HuntsGoodOwned(goodID, ns.HuntsGoodRule(goodID), state, set, sets or list)
		end

		it("list all five earned goods, each with its rule (HNT-R122)", function()
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
			"keep Four-Set Seal and Night Watch once noted when a release adds a set not yet titled (HNT-R122, HNT-R20)",
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
