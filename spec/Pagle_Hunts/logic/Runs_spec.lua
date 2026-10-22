-- Hunt Events' seams for the run log, the board, the tracker and the moments (#300–#304): ns.RunsKnown, ns.RunOn
-- and ns.RunProgress (logic/Runs.lua, HNT-R143, HNT-R146, HNT-R150, HNT-R160, HNT-R161), over hand-made states and
-- the fixture event pool.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

describe("Hunt Events' seams", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local ns = hunts.load(fake).ns

	-- A state with these runs (`{ event, start, end_ }`), each with no progress.
	local function stateWith(runs)
		local state = ns.NewHuntsState()
		for _, run in ipairs(runs) do
			state.runs[ns.RunKey(run[1], run[2])] =
				{ event = run[1], start = run[2], end_ = run[3], source = "r", hunts = {} }
		end
		return state
	end

	local function keys(list)
		local out = {}
		for i, on in ipairs(list) do
			out[i] = on.key
		end
		return out
	end

	it("keys a run <eventID>@<start> (HNT-R142)", function()
		assert.are.equal("fixture_shore@1772323200", ns.RunKey("fixture_shore", 1772323200))
	end)

	it("RunsKnown lists every known run by end, then start, then event ID (HNT-R150)", function()
		local state =
			stateWith({ { "fixture_vale", 100, 300 }, { "fixture_shore", 0, 300 }, { "fixture_shore", 300, 400 } })
		state.runs["fixture_aaa@200"] = { event = "fixture_aaa", start = 200, end_ = 300, source = "p", hunts = {} }

		assert.are.same(
			{ "fixture_shore@0", "fixture_vale@100", "fixture_aaa@200", "fixture_shore@300" },
			keys(ns.RunsKnown(state))
		)
		-- A state stored before Hunt Events, while it rebuilds, has none.
		assert.are.same({}, ns.RunsKnown({ casts = 0 }))
	end)

	it("RunOn lists the runs with start <= t < end, by end (HNT-R143, HNT-R160)", function()
		local state =
			stateWith({ { "fixture_shore", 0, 100 }, { "fixture_shore", 100, 200 }, { "fixture_vale", 50, 150 } })

		assert.are.same({ "fixture_shore@0" }, keys(ns.RunOn(state, 0)))
		assert.are.same({ "fixture_shore@0", "fixture_vale@50" }, keys(ns.RunOn(state, 99)))
		-- At a shared boundary only the run starting there is on (HNT-R199).
		assert.are.same({ "fixture_vale@50", "fixture_shore@100" }, keys(ns.RunOn(state, 100)))
		assert.are.same({}, keys(ns.RunOn(state, 200)))
		assert.are.same({}, ns.RunOn({ casts = 0 }, 0))
	end)

	it("RunProgress counts first marks and finds the closest unfinished Hunt (HNT-R146, HNT-R161)", function()
		local state = stateWith({ { "fixture_shore", 0, 100 } })
		local run = state.runs["fixture_shore@0"]
		-- The Haul (tier 1 at 2) has 1 of 2; the Named fish is done; the oddity has none.
		run.hunts.fixture_shore_haul = hunts.progress({ count = 1 })
		run.hunts.fixture_shore_snapper = hunts.progress({ tiers = 1 })

		local progress = ns.RunProgress(run, state)

		assert.are.same(
			{ 1, 3, "fixture_shore_haul", 1, 2, "fixture_shore" },
			{ progress.done, progress.total, progress.closest.id, progress.count, progress.of, progress.event.id }
		)
	end)

	it("RunProgress names no closest Hunt once every first mark is in, and none for an unknown event", function()
		local state = stateWith({ { "fixture_vale", 0, 100 }, { "fixture_gone", 0, 100 } })
		local run = state.runs["fixture_vale@0"]
		for _, id in ipairs({ "fixture_vale_haul", "fixture_vale_blackmouth", "fixture_vale_uncommon" }) do
			run.hunts[id] = hunts.progress({ tiers = 1 })
		end

		local progress = ns.RunProgress(run, state)
		assert.are.same({ 3, 3 }, { progress.done, progress.total })
		assert.is_nil(progress.closest)
		assert.are.same({ done = 0, total = 0 }, ns.RunProgress(state.runs["fixture_gone@0"], state))
	end)
end)
