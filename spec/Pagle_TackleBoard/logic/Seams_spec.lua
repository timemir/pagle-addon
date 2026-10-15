-- The seams later Tackle Board tickets meet at (M7 graph, conventions): the board's entry points, the projection's
-- state and flags, taking down, the Coins hook and the redraw bus, as they stand before those tickets
-- fill them in. Start, the live step and the login window are in adapter/LiveStep_spec, the outlets in
-- adapter/Moments_spec.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local GOAL = "Player-4618-0A1B2C3D-1791731747-0"

describe("the Tackle Board's seams", function()
	describe("the board's entry points and actions (until the reroll's and completions' tickets)", function()
		it("toggle and open the board, and take down and report nothing yet, with no error", function()
			local loaded, fake = board.load()
			local ns = loaded.ns
			fake.login()
			fake.enterWorld()

			assert.has_no_error(function()
				ns.ToggleBoard()
				ns.OpenBoard()
				ns.OpenBoard(GOAL)
				ns.TakeDown(GOAL)
				ns.ReportCoins()
			end)
			fake.nextFrame()
			for _ in fake.Pagle.IterateCatches(0) do
				error("a stand-in appended a record (TKB-R80)")
			end
			assert.are.same({}, fake.coinReports)
		end)

		it("let no goal be taken down (TKB-R55)", function()
			assert.is_false(board.load().ns.CanTakeDown(GOAL))
		end)
	end)

	describe("the projection's state (TKB-R81, before its first build)", function()
		it(
			"is an empty TackleBoardState: not started, nothing owed, every pin empty, no fire (tackle-board.md › Data)",
			function()
				assert.are.same({
					day = 0,
					week = 0,
					owed = { notices = 0, expeditions = 0 },
					pins = { expeditions = { false, false }, notices = { false, false, false, false, false, false } },
					goals = {},
					tally = { notices = 0, expeditions = 0 },
					coins = 0,
					flies = {},
					titles = {},
					fire = { count = 0, kindling = 0, longest = 0, milestones = {}, log = {} },
					zones = {},
					caught = {},
				}, board.load().ns.State())
			end
		)

		it("is a new table each time, so a view that changes one changes no other", function()
			local ns = board.load().ns

			ns.State().coins = 60
			ns.State().pins.notices[1] = GOAL

			assert.are.equal(0, ns.State().coins)
			assert.is_false(ns.State().pins.notices[1])
		end)

		it("reads as updating and not started until the first build ends (LOG-R74, TKB-R6)", function()
			local loaded, fake = board.load()
			local ns = loaded.ns
			local before = { ns.IsUpdating(), ns.IsStarted() }

			fake.login()
			fake.enterWorld()

			assert.are.same({ true, false }, before)
			assert.are.same({ false, false }, { ns.IsUpdating(), ns.IsStarted() })
		end)
	end)

	describe("the redraw bus", function()
		it("calls every view that subscribed, in the order they did, with the reason and detail", function()
			local ns = board.load().ns
			local calls = {}
			ns.OnRedraw(function(reason, detail)
				calls[#calls + 1] = "board " .. reason .. " " .. tostring(detail)
			end)
			ns.OnRedraw(function(reason, detail)
				calls[#calls + 1] = "tracker " .. reason .. " " .. tostring(detail)
			end)

			ns.Redraw("projection")
			ns.Redraw("completed", GOAL)

			assert.are.same({
				"board projection nil",
				"tracker projection nil",
				"board completed " .. GOAL,
				"tracker completed " .. GOAL,
			}, calls)
		end)

		it("redraws nothing, and raises no error, with no view subscribed", function()
			assert.has_no_error(function()
				board.load().ns.Redraw("projection")
			end)
		end)

		it("belongs to one load of the Tackle Board: another load's views aren't called", function()
			local first, second = board.load().ns, board.load().ns
			local called = false
			first.OnRedraw(function()
				called = true
			end)

			second.Redraw("projection")

			assert.is_false(called)
		end)
	end)

	describe("the reset API and random source the adapter hands logic/", function()
		it("are the client's own calls and math.random, until a spec injects others", function()
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			local env, api = loaded.env, loaded.ns.api

			assert.are.same(
				{ env.GetServerTime, env.C_DateAndTime, env.GetGameTime, env.GetCurrentRegion },
				{ api.GetServerTime, api.C_DateAndTime, api.GetGameTime, api.GetCurrentRegion }
			)
			assert.are.equal(math.random, loaded.ns.random)
		end)
	end)
end)
