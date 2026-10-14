-- The Hunts tracker's lines as data (HNT-R76, HNT-R78): a Hunt's tier progress, and the short-of-skill label and the
-- "+N more" count over hand-made rows. The block on FakePagle is spec/Pagle_Hunts/adapter/Tracker_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- A Hunt with three tiers, as the fixture's fixture_snapper (tiers 1, 10 and 40).
local SNAPPER = { id = "fixture_snapper", tiers = { 1, 10, 40 } }

-- A HuntProgress at `count` qualifying Catches with `reached` tiers reached.
---@param count integer
---@param reached integer
---@return HuntProgress
local function progress(count, reached)
	local tiers = {}
	for k = 1, reached do
		tiers[k] =
			{ time = 0, catchId = "c" .. k, itemID = 13759, zone = 0, date = { year = 2026, month = 3, day = k } }
	end
	return { count = count, effort = 0, sinceLast = 0, caught = count > 0, reached = tiers }
end

describe("the Hunts tracker's lines", function()
	local ns = hunts.load().ns

	describe("a Hunt's progress (HNT-R76, HNT-R78)", function()
		it('reads "0 / 1" before completion, nothing caught', function()
			assert.are.equal("0 / 1", ns.TrackerProgress(SNAPPER, nil, false))
		end)

		it("reads the count over the next unreached threshold, past completion and past tier 2", function()
			assert.are.equal("1 / 10", ns.TrackerProgress(SNAPPER, progress(1, 1), false))
			assert.are.equal("9 / 10", ns.TrackerProgress(SNAPPER, progress(9, 1), false))
			assert.are.equal("12 / 40", ns.TrackerProgress(SNAPPER, progress(12, 2), false))
		end)

		it('reads "all tiers" once every tier is reached (HNT-R17)', function()
			assert.are.equal("all tiers", ns.TrackerProgress(SNAPPER, progress(41, 3), false))
		end)

		it('reads "updating…" while the projection is updating, whatever the state says', function()
			assert.are.equal("updating…", ns.TrackerProgress(SNAPPER, progress(41, 3), true))
			assert.are.equal("updating…", ns.TrackerProgress(SNAPPER, nil, true))
		end)
	end)

	describe("the lines of pinned rows (HNT-R76, HNT-R51)", function()
		-- A pinned row of `id`, Later with no window known, short of skill or not.
		local function row(id, short)
			local hunt = ns.hunts:Hunt(id)
			return { id = id, hunt = hunt, group = "later", pinned = true, short = short, order = 1, auraUp = false }
		end
		local function input(rows, where)
			return {
				rows = rows,
				time = SERVER_TIME,
				snapshot = {
					time = SERVER_TIME,
					minute = 495,
					date = { year = 2026, month = 10, day = 11, weekday = 1 },
				},
				updating = false,
				state = { casts = 0, coins = 0, hunts = {}, sets = {} },
				list = ns.hunts,
				where = where,
				sources = { ItemName = function() end, BandName = function() end },
			}
		end
		local where = { zones = {}, skillNeed = 225 }

		it('labels a row short of skill "needs 225", and one that isn\'t by its group alone', function()
			local lines = ns.TrackerLines(input({ row("fixture_snapper", true), row("fixture_eel", false) }, {
				fixture_snapper = where,
				fixture_eel = where,
			}))

			assert.are.equal("Snapper Run · needs 225", lines.hunts[1].first)
			assert.are.equal("later", lines.hunts[1].dot)
			assert.matches(" · no date known$", lines.hunts[2].first)
		end)

		it("keeps none before the first grouping, not even the empty line", function()
			assert.are.same({ hunts = {}, more = 0, empty = false }, ns.TrackerLines(input(nil, {})))
		end)

		it('counts the pinned rows past six for "+N more", and the empty line with none (Tunables)', function()
			local rows, whereOf = {}, {}
			for i = 1, 8 do
				rows[i] = row("fixture_snapper", false)
				whereOf.fixture_snapper = where
			end

			local lines = ns.TrackerLines(input(rows, whereOf))

			assert.are.same({ 6, 2, false }, { #lines.hunts, lines.more, lines.empty })
			assert.are.same({ hunts = {}, more = 0, empty = true }, ns.TrackerLines(input({}, {})))
		end)

		it('dots an On demand row in the board\'s blue "demand" colour', function()
			local onDemand = row("fixture_rack", false)
			onDemand.group = "onDemand"

			local lines = ns.TrackerLines(input({ onDemand }, { fixture_rack = { zones = {} } }))

			assert.are.same({ "demand", "fixture_rack · on demand" }, { lines.hunts[1].dot, lines.hunts[1].first })
		end)
	end)
end)
