-- Hunts' seams (logic/Seams.lua): the projection's state and updating flag before its first build (HNT-R136, LOG-R74),
-- and the redraw bus (HNT-R42). The board's entry points (HNT-R68) are adapter/Board_spec's and adapter/Hunts_spec's.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

describe("Hunts' seams", function()
	-- The projection (logic/Projection.lua) binds both; adapter/Projection_spec.lua follows them through its builds.
	describe("the projection's state before its first build (HNT-R136, LOG-R74)", function()
		it(
			"is an empty HuntsState: no Casts, Coins, XP, runs, Hunt progress or set titles (hunts.md › Data)",
			function()
				local ns = hunts.load().ns

				assert.are.same({
					casts = 0,
					coins = 0,
					xp = 0,
					runs = {},
					defs = {},
					settled = 0,
					ladder = {},
					hunts = {},
					sets = {},
					hours = {},
				}, ns.State())
			end
		)

		it("is a new table each time, so a view that changes one changes no other", function()
			local ns = hunts.load().ns

			ns.State().hunts.fixture_snapper = { count = 1 }

			assert.are.same({}, ns.State().hunts)
		end)

		it("is updating until login starts the projection (LOG-R74)", function()
			assert.is_true(hunts.load().ns.IsUpdating())
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
