-- The seams later Stats tickets meet at (M6 graph, open question 3): the projection's state and updating flag, and the
-- redraw bus the book and the tracker subscribe to, as they stand before those tickets fill them in. The book's entry
-- points are adapter/Book.lua's own (spec/Pagle_Stats/adapter/Book_spec.lua).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

describe("Stats' seams", function()
	describe("the projection's state before its first build (STA-R20, LOG-R74)", function()
		it("is an empty StatsState: no Casts anywhere, no hits, no Sessions (stats.md › Projection state)", function()
			local ns = stats.load().ns

			local function counts()
				return { casts = 0, catches = 0, gotAway = 0 }
			end
			assert.are.same({
				totals = counts(),
				places = {},
				chars = {},
				scopes = {},
				hits = {},
				items = {},
				margins = {
					lo50 = { casts = 0, gotAway = 0 },
					lo1 = { casts = 0, gotAway = 0 },
					hi0 = { casts = 0, gotAway = 0 },
					hi25 = { casts = 0, gotAway = 0 },
				},
				lastRank = {},
				sessions = {},
			}, ns.State())
		end)

		it("is a new table each time, so a view that changes one changes no other", function()
			local ns = stats.load().ns

			ns.State().totals.casts = 5
			ns.State().places[148] = { zone = 148, casts = 1, catches = 1, gotAway = 0, items = {} }

			assert.are.equal(0, ns.State().totals.casts)
			assert.are.same({}, ns.State().places)
		end)

		it("reads as updating until login starts the projection (LOG-R74, STA-R92)", function()
			assert.is_true(stats.load().ns.IsUpdating())
		end)
	end)

	describe("the redraw bus", function()
		it("calls every view that subscribed, in the order they did, with the reason", function()
			local ns = stats.load().ns
			local calls = {}
			ns.OnRedraw(function(reason)
				calls[#calls + 1] = "book " .. reason
			end)
			ns.OnRedraw(function(reason)
				calls[#calls + 1] = "tracker " .. reason
			end)

			ns.Redraw("projection")
			ns.Redraw("watches")

			assert.are.same({ "book projection", "tracker projection", "book watches", "tracker watches" }, calls)
		end)

		it("redraws nothing, and raises no error, with no view subscribed", function()
			assert.has_no_error(function()
				stats.load().ns.Redraw("projection")
			end)
		end)

		it("belongs to one load of Stats: another load's views aren't called", function()
			local first, second = stats.load().ns, stats.load().ns
			local called = false
			first.OnRedraw(function()
				called = true
			end)

			second.Redraw("projection")

			assert.is_false(called)
		end)
	end)
end)
