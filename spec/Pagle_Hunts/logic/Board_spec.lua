-- The Hunts board's page router (HNT-R60, HNT-R61, HNT-R66, HNT-R67): which mode the board shows, which renderer
-- draws each page in it, and the breadcrumb trail back up. Pure logic, on the fixture Hunt list's IDs.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- A fresh router from Hunts' logic.
local function newRouter()
	return hunts.load().ns.NewBoardRouter()
end

-- A renderer that does nothing, told apart from another by identity.
local function renderer()
	return function() end
end

describe("the board's page router (HNT-R61, HNT-R66)", function()
	it("starts on the Board mode with nothing asked for (HNT-R67)", function()
		assert.are.same({ mode = "board" }, newRouter():Place())
	end)

	it("gives each mode's page the renderer registered for it, and none to a mode with none", function()
		local router = newRouter()
		local timeline, entry, setPage = renderer(), renderer(), renderer()

		router:Register("board", "left", timeline)
		router:Register("board", "right", entry)
		router:Register("set", "right", setPage)

		assert.are.equal(timeline, router:Renderer("board", "left"))
		assert.are.equal(entry, router:Renderer("board", "right"))
		assert.are.equal(setPage, router:Renderer("set", "right"))
		assert.is_nil(router:Renderer("set", "left"))
		assert.is_nil(router:Renderer("entry", "left"))
		assert.is_nil(router:Renderer("retired", "right"))
	end)

	it("lets one renderer draw several modes' pages, and a later registration replace an earlier one", function()
		local router = newRouter()
		local first, second = renderer(), renderer()

		router:Register("board", "left", first)
		router:Register("set", "left", first)
		router:Register("board", "left", second)

		assert.are.equal(second, router:Renderer("board", "left"))
		assert.are.equal(first, router:Renderer("set", "left"))
	end)

	it("refuses a mode, side or renderer it doesn't know, so a typo fails at load", function()
		local router = newRouter()

		assert.has_error(function()
			router:Register("timeline", "left", renderer())
		end, "the Hunts board has no mode timeline")
		assert.has_error(function()
			router:Register("board", "middle", renderer())
		end, "a Hunts board page is left or right, not middle")
		assert.has_error(function()
			router:Register("board", "left", nil)
		end, "a Hunts board page's renderer is a function")
	end)

	it("opens each of the five modes: the Board, a set's page, an entry, a retired entry and Pagle Wagers", function()
		local router = newRouter()

		router:Open({ mode = "wagers" })
		assert.are.same({ mode = "wagers" }, router:Place())
		router:Open({ mode = "wagers", run = "fixture_shore@100" }) -- HNT-R162: a slip chosen
		assert.are.same({ mode = "wagers", run = "fixture_shore@100" }, router:Place())
		router:Open({ mode = "set", set = "fixture_dusk" })
		assert.are.same({ mode = "set", set = "fixture_dusk" }, router:Place())
		router:Open({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" })
		assert.are.same({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }, router:Place())
		router:Open({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" })
		assert.are.same({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" }, router:Place())
		router:Open({ mode = "board", hunt = "fixture_rack" })
		assert.are.same({ mode = "board", hunt = "fixture_rack" }, router:Place())
	end)

	it("refuses a place its mode can't show: a set's page with no set, an entry with no Hunt", function()
		local router = newRouter()

		for _, case in ipairs({
			{ { mode = "timeline" }, "the Hunts board has no mode timeline" },
			{ { mode = "set" }, "a set's page needs its set" },
			{ { mode = "entry", set = "fixture_dusk" }, "an entry needs its Hunt" },
			{ { mode = "retired" }, "an entry needs its Hunt" },
		}) do
			assert.has_error(function()
				router:Open(case[1])
			end, case[2])
		end
		assert.are.same({ mode = "board" }, router:Place())
	end)

	it("keeps its own copy of a place, so the caller's table changes nothing", function()
		local router = newRouter()
		local place = { mode = "set", set = "fixture_dusk" }

		router:Open(place)
		place.set = "fixture_wagers"
		router:Place().set = "fixture_wagers"

		assert.are.same({ mode = "set", set = "fixture_dusk" }, router:Place())
	end)

	it("selects a Hunt in the mode it shows, as the timeline does when it picks one (HNT-R67)", function()
		local router = newRouter()

		router:Select("fixture_snapper")
		assert.are.same({ mode = "board", hunt = "fixture_snapper" }, router:Place())
		router:Select(nil)
		assert.are.same({ mode = "board" }, router:Place())
	end)

	it("selects a run on the Board in place of a Hunt, and a Hunt in place of a run (HNT-R161, HNT-R164)", function()
		local router = newRouter()

		router:Open({ mode = "board", run = "fixture_shore@100" })
		assert.are.same({ mode = "board", run = "fixture_shore@100" }, router:Place())
		router:Select("fixture_snapper")
		assert.are.same({ mode = "board", hunt = "fixture_snapper" }, router:Place())
		router:Select(nil, "fixture_shore@100")
		assert.are.same({ mode = "board", run = "fixture_shore@100" }, router:Place())
	end)

	describe("the breadcrumb trail (HNT-R61)", function()
		it('is "Hunts", "Pagle Wagers", then the run, with a run selected (HNT-R164)', function()
			local router = newRouter()

			router:Open({ mode = "board", run = "fixture_shore@100" })

			-- "Pagle Wagers" turns to its spread on that run (HNT-R162).
			assert.are.same({
				{ kind = "hunts", place = { mode = "board" } },
				{ kind = "wagers", id = "fixture_shore@100", place = { mode = "wagers", run = "fixture_shore@100" } },
				{ kind = "run", id = "fixture_shore@100", place = { mode = "board", run = "fixture_shore@100" } },
			}, router:Trail())
		end)

		it(
			'is "Hunts", "Pagle Wagers", then the slip chosen on the spread, "Pagle Wagers" back to the slips',
			function()
				local router = newRouter()

				router:Open({ mode = "wagers", run = "fixture_shore@100" })

				assert.are.same({
					{ kind = "hunts", place = { mode = "board" } },
					{ kind = "wagers", id = "fixture_shore@100", place = { mode = "wagers" } },
					{ kind = "run", id = "fixture_shore@100", place = { mode = "wagers", run = "fixture_shore@100" } },
				}, router:Trail())
			end
		)

		it('stops at "Pagle Wagers" on the spread with no slip chosen (HNT-R164)', function()
			local router = newRouter()

			router:Open({ mode = "wagers" })

			assert.are.same({
				{ kind = "hunts", place = { mode = "board" } },
				{ kind = "wagers", place = { mode = "wagers" } },
			}, router:Trail())
		end)

		it('is "Hunts" alone on the Board, and "Hunts", then the Hunt, once one is selected', function()
			local router = newRouter()

			assert.are.same({ { kind = "hunts", place = { mode = "board" } } }, router:Trail())
			router:Select("fixture_snapper")
			assert.are.same({
				{ kind = "hunts", place = { mode = "board" } },
				{ kind = "hunt", id = "fixture_snapper", place = { mode = "board", hunt = "fixture_snapper" } },
			}, router:Trail())
		end)

		it('is "Hunts", then the set, on a set\'s page', function()
			local router = newRouter()

			router:Open({ mode = "set", set = "fixture_dusk" })

			assert.are.same({
				{ kind = "hunts", place = { mode = "board" } },
				{ kind = "set", id = "fixture_dusk", place = { mode = "set", set = "fixture_dusk" } },
			}, router:Trail())
		end)

		it('is "Hunts", the set, then the Hunt on an entry opened from a set, each going back up (HNT-R66)', function()
			local router = newRouter()

			for _, mode in ipairs({ "entry", "retired" }) do
				router:Open({ mode = mode, set = "fixture_dusk", hunt = "fixture_snapper" })

				assert.are.same({
					{ kind = "hunts", place = { mode = "board" } },
					{ kind = "set", id = "fixture_dusk", place = { mode = "set", set = "fixture_dusk" } },
					{
						kind = "hunt",
						id = "fixture_snapper",
						place = { mode = mode, set = "fixture_dusk", hunt = "fixture_snapper" },
					},
				}, router:Trail())
			end
		end)
	end)
end)
