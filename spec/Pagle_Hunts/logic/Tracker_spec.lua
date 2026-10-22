-- The Hunts tracker's lines as data (HNT-R76, HNT-R78, HNT-R175): a Hunt's tier progress, and the short-of-skill label
-- and the "+N more" count over hand-made rows; the Pagle Wagers block's runs over hand-made runs of the fixture event
-- pool's fixture_shore. The block on FakePagle is spec/Pagle_Hunts/adapter/Tracker_spec.lua, and the Pagle Wagers
-- block's spec/Pagle_Hunts/adapter/TrackerWagers_spec.lua.

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
				snapshot = hunts.SUNDAY,
				updating = false,
				state = ns.NewHuntsState(),
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

		it("lists none before the first grouping, and with nothing pinned reads the empty line (HNT-R76)", function()
			local nothing = input(nil, {})
			nothing.anyPinned = false
			assert.are.same({ hunts = {}, more = 0, empty = true }, ns.TrackerLines(nothing))

			local pinned = input(nil, {})
			pinned.anyPinned = true -- its rows come with the first grouping
			assert.are.same({ hunts = {}, more = 0, empty = false }, ns.TrackerLines(pinned))
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

		it("dots a row by its group, On demand's in the board's blue (HNT-R76)", function()
			local onDemand = row("fixture_rack", false)
			onDemand.group = "onDemand"

			local lines = ns.TrackerLines(input({ onDemand }, { fixture_rack = { zones = {} } }))

			assert.are.same({ "onDemand", "fixture_rack · on demand" }, { lines.hunts[1].dot, lines.hunts[1].first })
		end)
	end)

	describe("the Pagle Wagers block's runs (HNT-R175, HNT-R51, HNT-R78)", function()
		-- fixture_shore ("Shore Wager"): a Haul of any fish (tiers 2 / 4), Shore Snapper (1) and a Timed oddity (1).
		local NOW, HOUR = SERVER_TIME, hunts.HOUR
		local state = ns.NewHuntsState()

		-- The `n`th HuntsShownRun of fixture_shore, ending `left` seconds after NOW, on unless `on` is false, its Hunts'
		-- progress `progresses`.
		local function shown(n, left, progresses, on)
			local start = NOW - 2 * 86400 + n
			return {
				key = "fixture_shore@" .. start,
				run = {
					event = "fixture_shore",
					start = start,
					end_ = NOW + left,
					source = "r",
					hunts = progresses or {},
				},
				event = ns.events:Event("fixture_shore"),
				on = on ~= false,
			}
		end
		local function input(runs, updating)
			return { runs = runs, now = NOW, updating = updating or false }
		end

		it("are none with no run on, a run ahead or not: the block is gone (HNT-R175)", function()
			assert.is_nil(ns.TrackerWagerLines(input({}), state))
			assert.is_nil(ns.TrackerWagerLines(input({ shown(1, 30 * HOUR, nil, false) }), state))
		end)

		it('read each run on as its name, "ends in 1d 4h", its first marks and its closest Hunt, in order', function()
			local first =
				shown(1, 28 * HOUR, { fixture_shore_snapper = progress(1, 1), fixture_shore_haul = progress(1, 0) })
			local second = shown(2, 50 * HOUR)

			local lines = ns.TrackerWagerLines(input({ first, second, shown(3, 70 * HOUR, nil, false) }), state)

			assert.are.same({
				runs = {
					{
						key = first.key,
						name = "Shore Wager",
						label = "ends in 1d 4h",
						second = "1 of 3 first marks · fixture_shore_haul: 1 / 2",
					},
					{
						key = second.key,
						name = "Shore Wager",
						label = "ends in 2d 2h",
						second = "0 of 3 first marks · fixture_shore_haul: 0 / 2", -- a tie: the first in file order
					},
				},
				more = 0,
			}, lines)
		end)

		it(
			'shows 3 of 4 runs on, then counts the one past them for "+1 more wagers on the table" (Tunables)',
			function()
				local runs = {}
				for i = 1, 4 do
					runs[i] = shown(i, i * HOUR)
				end
				runs[5] = shown(5, 90 * HOUR, nil, false) -- a run ahead isn't counted

				local lines = ns.TrackerWagerLines(input(runs), state)

				assert.are.equal(3, ns.TRACKER_RUNS)
				assert.are.same(
					{ runs[1].key, runs[2].key, runs[3].key, 1 },
					{ lines.runs[1].key, lines.runs[2].key, lines.runs[3].key, lines.more }
				)
				assert.are.equal("+1 more wagers on the table", ns.TrackerWagersMore(lines.more))
			end
		)

		it('reads "settled" for a completed run, every first mark landed and no closest Hunt (HNT-R146)', function()
			local done = shown(1, 28 * HOUR, {
				fixture_shore_haul = progress(2, 1),
				fixture_shore_snapper = progress(1, 1),
				fixture_shore_oddity = progress(1, 1),
			})
			done.run.completedAt = NOW - HOUR

			local line = ns.TrackerWagerLines(input({ done }), state).runs[1]

			assert.are.same({ "settled", "3 of 3 first marks" }, { line.label, line.second })
		end)

		it('reads "updating…" for progress while the projection updates, its countdown still running', function()
			local done = shown(1, 37 * 60, { fixture_shore_snapper = progress(1, 1) })
			done.run.completedAt = NOW - HOUR

			local line = ns.TrackerWagerLines(input({ done }, true), state).runs[1]

			assert.are.same({ "ends in 37m", "updating…" }, { line.label, line.second })
		end)

		it("claim no odds, chance or due fish (HNT-R27)", function()
			local settled = shown(3, HOUR)
			settled.run.completedAt = NOW
			local runs = { shown(1, 28 * HOUR), shown(2, HOUR), settled, shown(4, HOUR) }
			local lines = ns.TrackerWagerLines(input(runs), state)
			local texts = { ns.L.WAGERS_KICKER, ns.TrackerWagersMore(lines.more) }
			for _, line in ipairs(lines.runs) do
				texts[#texts + 1] = line.label
				texts[#texts + 1] = line.second
			end

			for _, text in ipairs(texts) do
				for _, word in ipairs({ "odds", "chance", "due", "likely", "%%" }) do
					assert.is_nil(text:lower():find(word))
				end
			end
		end)
	end)

	describe("the block's height (HNT-R76, HNT-R79, HNT-R123)", function()
		-- The native look, a frame's paper, and an expansion frame's paper with its top and foot.
		local NATIVE = { foot = 6 }
		local PAPER = { frame = "paper", foot = 10 }
		local SLICED = { frame = "slate", foot = 10, slice = { top = 60, foot = 50 } }

		it("ends its look's foot under the last line (HNT-R76)", function()
			assert.are.equal(86, ns.TrackerBlockHeight(NATIVE, 30, 80))
			assert.are.equal(90, ns.TrackerBlockHeight(PAPER, 30, 80))
		end)

		it("gives a header alone the foot only in a frame (HNT-R79)", function()
			assert.are.equal(30, ns.TrackerBlockHeight(NATIVE, 30, 30))
			assert.are.equal(40, ns.TrackerBlockHeight(PAPER, 30, 30))
		end)

		it("keeps an expansion frame no shorter than its paper's top and foot (HNT-R123, HNT-R77)", function()
			assert.are.equal(110, ns.TrackerBlockHeight(SLICED, 30, 30))
			assert.are.equal(130, ns.TrackerBlockHeight(SLICED, 30, 120))
		end)
	end)
end)
