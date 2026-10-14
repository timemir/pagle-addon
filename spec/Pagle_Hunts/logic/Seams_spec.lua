-- The seams later Hunts tickets meet at (M5 graph, open question 5): the board's entry points, the projection's state
-- and updating flag, and the redraw bus (HNT-R42's redraws), as they stand before those tickets fill them in.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

describe("Hunts' seams", function()
	describe("the board's entry points (HNT-R68)", function()
		it("are the board's own once its file loads: each opens the notebook (adapter/Board_spec)", function()
			local ns = hunts.load().ns

			ns.ToggleBoard()
			assert.is_true(ns.board:IsShown())
			ns.ToggleBoard()
			ns.OpenBoard("fixture_snapper")
			assert.is_true(ns.board:IsShown())
		end)
	end)

	describe("a view's showing and hiding (HNT-R42's refresh, until the grouping's ticket)", function()
		it("is told to nobody yet, and raises no error", function()
			local ns = hunts.load().ns

			assert.has_no_error(function()
				ns.ViewShown("board", true)
				ns.ViewShown("tracker", false)
			end)
		end)
	end)

	describe("the projection's state (HNT-R136, until the projection's ticket)", function()
		it(
			"is an empty HuntsState: no Casts, no Coins, no Hunt progress and no set titles (hunts.md › Data)",
			function()
				local ns = hunts.load().ns

				assert.are.same({ casts = 0, coins = 0, hunts = {}, sets = {} }, ns.State())
			end
		)

		it("is a new table each time, so a view that changes one changes no other", function()
			local ns = hunts.load().ns

			ns.State().hunts.fixture_snapper = { count = 1 }

			assert.are.same({}, ns.State().hunts)
		end)

		it("is never updating (LOG-R74)", function()
			assert.is_false(hunts.load().ns.IsUpdating())
		end)
	end)

	describe("the redraw bus (HNT-R42)", function()
		it("calls every view that subscribed, in the order they did, with the reason", function()
			local ns = hunts.load().ns
			local calls = {}
			ns.OnRedraw(function(reason)
				calls[#calls + 1] = "board " .. reason
			end)
			ns.OnRedraw(function(reason)
				calls[#calls + 1] = "tracker " .. reason
			end)

			ns.Redraw("groups")
			ns.Redraw("projection")

			assert.are.same({ "board groups", "tracker groups", "board projection", "tracker projection" }, calls)
		end)

		it("redraws nothing, and raises no error, with no view subscribed", function()
			assert.has_no_error(function()
				hunts.load().ns.Redraw("names")
			end)
		end)

		it("belongs to one load of Hunts: another load's views aren't called", function()
			local first, second = hunts.load().ns, hunts.load().ns
			local called = false
			first.OnRedraw(function()
				called = true
			end)

			second.Redraw("groups")

			assert.is_false(called)
		end)
	end)
end)
