-- Set titles (HNT-R20–R23, HNT-R197): when a set's title is earned, from a Catch or from a retirement, checked over
-- hand-made projection states in hunts.md › Projection state's shape and the fixture Hunt list's two title sets:
-- fixture_pair (fixture_eel and fixture_bass, both from 2026-01-01) and fixture_tide (fixture_squid from 2026-01-01,
-- fixture_tide_retired from 2026-01-01 until 2026-06-01, fixture_tide_late from 2026-04-01).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- Server times (DATA-R87): 00:00 UTC on the first of each month of 2026.
local FEB_1, MAR_1, APR_1 = 1769904000, 1772323200, 1775001600
local MAY_1, JUN_1, JUL_1 = 1777593600, 1780272000, 1782864000
local HOUR = 3600

-- A new, empty projection state (hunts.md › Projection state).
---@return HuntsState
local function newState()
	return { casts = 0, coins = 0, hunts = {}, sets = {} }
end

-- Gives `huntID` in `state` one reached tier per entry of `tiers`, each `{ time, date }`: the Cast's server time and
-- its realm date (HNT-R15).
---@param state HuntsState
---@param huntID string
---@param tiers { [1]: integer, [2]: { year: integer, month: integer, day: integer } }[]
local function reach(state, huntID, tiers)
	local reached = {}
	for k, tier in ipairs(tiers) do
		reached[k] = { time = tier[1], catchId = huntID .. k, itemID = 13755, zone = 0, date = tier[2] }
	end
	state.hunts[huntID] = { count = #tiers, effort = #tiers, sinceLast = 0, caught = true, reached = reached }
end

-- A realm date.
local function day(year, month, dayOfMonth)
	return { year = year, month = month, day = dayOfMonth }
end

describe("Set titles", function()
	local ns = hunts.load().ns

	describe("from a Catch (HNT-R20, HNT-R23)", function()
		it("are earned at the later of a two-Hunt set's tier-1 times, with that tier's realm date", function()
			local state = newState()
			-- The realm's day still read 31 January three hours into 1 February UTC.
			reach(state, "fixture_eel", { { FEB_1 + 3 * HOUR, day(2026, 1, 31) } })
			reach(state, "fixture_bass", { { MAR_1 + 2 * HOUR, day(2026, 2, 28) } })

			local earned = ns.CheckTitles(state, MAR_1 + 2 * HOUR, MAR_1 + 2 * HOUR)

			assert.are.same({ "fixture_pair" }, earned)
			assert.are.same(
				{ earnedAt = MAR_1 + 2 * HOUR, date = day(2026, 2, 28), fromRetirement = false },
				state.sets.fixture_pair
			)
		end)

		it("aren't earned while one of the set's Hunts isn't done, however late the check", function()
			local state = newState()
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })

			assert.are.same({}, ns.CheckTitles(state, JUL_1, JUL_1))
			assert.are.same({}, ns.CheckTitles(state, JUL_1))
			assert.is_nil(state.sets.fixture_pair)
		end)

		it("are found by the check after the Cast that completes the set, as apply runs it, and not before", function()
			local state = newState()
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })
			assert.are.same({}, ns.CheckTitles(state, FEB_1, FEB_1))

			reach(state, "fixture_bass", { { MAR_1, day(2026, 3, 1) } })
			assert.are.same({ "fixture_pair" }, ns.CheckTitles(state, MAR_1, MAR_1))
			assert.are.same(
				{ earnedAt = MAR_1, date = day(2026, 3, 1), fromRetirement = false },
				state.sets.fixture_pair
			)
		end)

		it("aren't found by a check before the earned time: candidates run only up to the time checked", function()
			local state = newState()
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_bass", { { MAR_1, day(2026, 3, 1) } })

			assert.are.same({}, ns.CheckTitles(state, MAR_1 - 1, MAR_1 - 1))
			assert.is_nil(state.sets.fixture_pair)
		end)

		it(
			"are from a Catch only when the Cast just applied earned them; done's check marks one it finds late",
			function()
				-- Never met when apply checks after every Cast; were it met, the title keeps its tier's time and date
				-- but rides on no Cast, so it's raised as a retirement's is: summary-only, from done (HNT-R87).
				local state = newState()
				reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })
				reach(state, "fixture_bass", { { MAR_1, day(2026, 3, 1) } })

				assert.are.same({ "fixture_pair" }, ns.CheckTitles(state, JUL_1))
				assert.are.same(
					{ earnedAt = MAR_1, date = day(2026, 3, 1), fromRetirement = true },
					state.sets.fixture_pair
				)
			end
		)

		it("count a Retired Hunt done before it retired", function()
			local state = newState()
			reach(state, "fixture_squid", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_tide_retired", { { MAR_1, day(2026, 3, 1) } })

			assert.are.same({ "fixture_tide" }, ns.CheckTitles(state, MAR_1, MAR_1))
			assert.are.same(
				{ earnedAt = MAR_1, date = day(2026, 3, 1), fromRetirement = false },
				state.sets.fixture_tide
			)
		end)

		it("are given in the list's set order when one check earns several", function()
			local state = newState()
			reach(state, "fixture_squid", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_tide_retired", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_bass", { { FEB_1, day(2026, 2, 1) } })

			assert.are.same({ "fixture_pair", "fixture_tide" }, ns.CheckTitles(state, FEB_1, FEB_1))
		end)
	end)

	describe("tier 1 only (HNT-R21)", function()
		it("need only tier 1 of each Hunt, and later tiers never move the earned time", function()
			local state = newState()
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) }, { APR_1, day(2026, 4, 1) } })
			reach(state, "fixture_bass", { { MAR_1, day(2026, 3, 1) } }) -- 1 of its 3 tiers

			assert.are.same({ "fixture_pair" }, ns.CheckTitles(state, MAR_1, MAR_1))
			assert.are.same(MAR_1, state.sets.fixture_pair.earnedAt)
		end)
	end)

	describe("from a retirement (HNT-R20, HNT-R23, HNT-R197)", function()
		local function tideAllButRetired()
			local state = newState()
			reach(state, "fixture_squid", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_tide_late", { { MAY_1, day(2026, 5, 1) } })
			return state
		end

		it("are earned at the retired date of the set's last undone Hunt, dated that UTC day", function()
			local state = tideAllButRetired()

			assert.are.same({ "fixture_tide" }, ns.CheckTitles(state, JUN_1))
			assert.are.same(
				{ earnedAt = JUN_1, date = day(2026, 6, 1), fromRetirement = true },
				state.sets.fixture_tide
			)
		end)

		it("aren't found by a check before the retired date", function()
			local state = tideAllButRetired()

			assert.are.same({}, ns.CheckTitles(state, JUN_1 - 1, JUN_1 - 1))
			assert.is_nil(state.sets.fixture_tide)
		end)

		it("are found at the next Cast after the retired date, still at that date and from the retirement", function()
			local state = tideAllButRetired()

			assert.are.same({ "fixture_tide" }, ns.CheckTitles(state, JUL_1, JUL_1))
			assert.are.same(
				{ earnedAt = JUN_1, date = day(2026, 6, 1), fromRetirement = true },
				state.sets.fixture_tide
			)
		end)

		it("need at least one Hunt of the set to exist: a set whose every Hunt retired undone earns nothing", function()
			-- A list of its own (hunts.md › Data: tests inject their own Hunt list): one set, both Hunts retired.
			local own = hunts.load().ns
			own.hunts = own.NewHuntList({
				sets = { { id = "gone" } },
				hunts = {
					{ id = "gone_a", set = "gone", kind = "natural", since = FEB_1, retired = APR_1, tiers = { 1 } },
					{ id = "gone_b", set = "gone", kind = "natural", since = FEB_1, retired = MAY_1, tiers = { 1 } },
				},
				classes = {},
			}, own.L)

			assert.are.same({}, own.CheckTitles(newState(), JUL_1))
		end)
	end)

	describe("Hunts added to a set (HNT-R20, HNT-R197)", function()
		it("never take away a title earned before they existed", function()
			local state = newState()
			reach(state, "fixture_squid", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_tide_retired", { { MAR_1, day(2026, 3, 1) } })
			ns.CheckTitles(state, MAR_1, MAR_1)
			local earned = state.sets.fixture_tide

			-- fixture_tide_late counts from 2026-04-01 and isn't done.
			assert.are.same({}, ns.CheckTitles(state, JUL_1, JUL_1))
			assert.are.same({}, ns.CheckTitles(state, JUL_1))
			assert.are.equal(earned, state.sets.fixture_tide)
			assert.are.same(
				{ earnedAt = MAR_1, date = day(2026, 3, 1), fromRetirement = false },
				state.sets.fixture_tide
			)
		end)

		it("delay a title not yet earned until they're done too", function()
			local state = newState()
			reach(state, "fixture_squid", { { FEB_1, day(2026, 2, 1) } })
			-- fixture_tide_retired leaves on 2026-06-01 undone, but fixture_tide_late exists from 2026-04-01.
			assert.are.same({}, ns.CheckTitles(state, JUN_1))

			reach(state, "fixture_tide_late", { { JUL_1, day(2026, 6, 30) } })
			assert.are.same({ "fixture_tide" }, ns.CheckTitles(state, JUL_1, JUL_1))
			assert.are.same(
				{ earnedAt = JUL_1, date = day(2026, 6, 30), fromRetirement = false },
				state.sets.fixture_tide
			)
		end)
	end)

	describe("the state they write (hunts.md › Projection state)", function()
		it("writes only the sets newly earned, and leaves the rest of the state alone", function()
			local state = newState()
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_bass", { { MAR_1, day(2026, 3, 1) } })
			state.casts, state.coins = 7, 3

			ns.CheckTitles(state, MAR_1, MAR_1)

			local setIDs = {}
			for id in pairs(state.sets) do
				setIDs[#setIDs + 1] = id
			end
			assert.are.same({ "fixture_pair" }, setIDs)
			assert.are.same({ 7, 3 }, { state.casts, state.coins })
			assert.are.equal(1, state.hunts.fixture_bass.count)
		end)

		it("dates a title with its own copy of the tier's date", function()
			local state = newState()
			reach(state, "fixture_eel", { { FEB_1, day(2026, 2, 1) } })
			reach(state, "fixture_bass", { { MAR_1, day(2026, 3, 1) } })

			ns.CheckTitles(state, MAR_1, MAR_1)

			assert.are_not.equal(state.hunts.fixture_bass.reached[1].date, state.sets.fixture_pair.date)
		end)
	end)
end)
