-- The Hunts tracker's Pagle Wagers block (HNT-R43, HNT-R51, HNT-R75, HNT-R78, HNT-R79, HNT-R143, HNT-R164,
-- HNT-R175, HNT-R177, CORE-R70) on FakePagle: the block above "Hunts" while a run is on, its lines, clicks and
-- collapsed state, its frame, and its leaving when the last run ends. The lines' pure parts are in
-- spec/Pagle_Hunts/logic/Tracker_spec.lua; the Hunts block's own in spec/Pagle_Hunts/adapter/Tracker_spec.lua.
--
-- The event pool is the banded one (spec/Pagle_Hunts/fixtures/BandedEventList.lua): every event has a Haul of any fish
-- (tiers 1 / 3) and two Named fish (Raw Nightfin Snapper, then Oily Blackmouth, 1 each). Only fixture_shore has a name
-- ("Shore Wager") and its Snapper Hunt one ("Shore Snapper"), so the others read their IDs (HNT-R140). The rotation's
-- starting point is put far ahead, so no fallback run is logged or ahead (HNT-R204): the runs on are the `run`
-- records each spec logs. The clock is fixed, at FakePagle's SERVER_TIME.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local NOW = SERVER_TIME
local INKWASH = "hunts.trackerframe.inkwash"

--- A run of `event` on from 3 days before it ends, ending `left` seconds after NOW, as its `run` record.
---@param event string
---@param left integer
---@return table record
---@return string key
local function runOn(event, left)
	local start, end_ = NOW + left - 3 * DAY, NOW + left
	return hunts.record("run", hunts.runPayload(event, start, end_), start), event .. "@" .. start
end

--- A Cast an hour into a run (`record`'s start) in `zone`, catching `itemIDs`.
local function castIn(record, zone, itemIDs)
	local entry = hunts.cast(0, hunts.NIGHT, { zone = zone }, itemIDs)
	entry.time = record.time + HOUR
	return entry
end

--- Hunts logged in at NOW over the banded pool, `history` (records) in the Catch log, names loaded, the run log's
--- step run; `options.saved` as PagleHuntsDB, `options.caughtUp` false to keep the projection updating. The companion
--- hint's switch is off unless `options.hint`, so the block with no run on is the runs' alone (HNT-R172, HNT-R176);
--- with it on, as at 1.0, FakePagle's companion reads "missing".
---@param history table[]
---@param options { saved: table?, caughtUp: boolean?, hint: boolean? }?
---@return HuntsRun
local function start(history, options)
	options = options or {}
	local r = hunts.start({
		names = true,
		events = hunts.bandedEvents(),
		saved = options.saved,
		caughtUp = options.caughtUp,
		prepare = function(loaded)
			loaded.ns.ROTATION_ORIGIN = NOW + 365 * DAY
			loaded.ns.COMPANION_HINT_ON = options.hint == true
		end,
		history = function(fake)
			hunts.append(fake, history)
		end,
	})
	r.fake.nextFrame()
	r.loaded.client.runTimers()
	return r
end

--- Two runs on, both ending in 1d 4h, each with a Deviate Fish in its waters: the Haul's first mark.
local SHORE, SHORE_KEY = runOn("fixture_shore", DAY + 4 * HOUR)
local VALE, VALE_KEY = runOn("fixture_vale", DAY + 4 * HOUR)
local function twoOn()
	return { SHORE, VALE, castIn(SHORE, C.DARKSHORE, { C.DEVIATE }), castIn(VALE, C.ASHENVALE, { C.DEVIATE }) }
end

-- A widget's top, down from its block's: SetPoint("TOPLEFT", x, y)'s y, negated.
local function topOf(widget)
	local anchor = widget.points[1]
	return -(type(anchor[2]) == "number" and anchor[3] or anchor[5] or 0)
end

--- The Pagle Wagers block as the player reads it, or nil when it doesn't show: its header, each run's two lines with
--- its dot's group, and "+{n} more" when it shows.
---@param r HuntsRun
---@return { header: string, runs: { dot: string, first: string, second: string }[], more: string? }?
local function read(r)
	local wagers = r.ns.tracker.wagers
	if not wagers.header:IsShown() then
		return nil
	end
	local out = { header = wagers.title:GetText(), runs = {} }
	for _, line in ipairs(wagers.lines) do
		if line:IsShown() then
			out.runs[#out.runs + 1] = {
				dot = line.dot.group,
				first = line.first:GetText() .. " · " .. line.label:GetText(),
				second = line.second:GetText(),
			}
		end
	end
	if wagers.more:IsShown() then
		out.more = wagers.more.text:GetText()
	end
	return out
end

--- The Hunts block's shown Hunts' first lines.
local function huntsShown(r)
	local out = {}
	for _, line in ipairs(r.ns.tracker.lines) do
		if line:IsShown() then
			out[#out + 1] = line.first:GetText()
		end
	end
	return out
end

local TWO_ON = {
	header = "Pagle Wagers",
	runs = {
		{
			dot = "wagers",
			first = "Shore Wager · ends in 1d 4h",
			second = "1 of 3 first marks · Shore Snapper: 0 / 1",
		},
		{
			dot = "wagers",
			first = "fixture_vale · ends in 1d 4h",
			second = "1 of 3 first marks · fixture_vale_snapper: 0 / 1",
		},
	},
}

describe("the tracker's Pagle Wagers block", function()
	describe("its runs (HNT-R175, HNT-R51)", function()
		it(
			'shows above "Hunts" with two runs on, two lines each: name, "ends in 1d 4h", first marks, closest Hunt',
			function()
				local r = start(twoOn())
				local view = r.ns.tracker

				assert.are.same(TWO_ON, read(r))
				-- Above the Hunts block, in the one docked frame, which sizes to both (HNT-R75, CORE-R70).
				assert.are.equal(0, topOf(view.wagers.header))
				assert.is_true(topOf(view.header) > topOf(view.wagers.lines[2]))
				assert.are.equal("Hunts", view.title:GetText())
				local none = start({})
				assert.is_true(view.frame:GetHeight() > none.ns.tracker.frame:GetHeight())
				assert.are.equal(1, #r.fake.dock.stack())
			end
		)

		it('shows 3 of 4 runs on, ordered as the board orders them, then "+1 more wagers on the table"', function()
			local brook = runOn("fixture_brook", 2 * DAY)
			local cove = runOn("fixture_cove", 2 * DAY + HOUR)
			local history = twoOn()
			history[#history + 1], history[#history + 2] = brook, cove

			local block = assert(read(start(history)))

			assert.are.same({
				"Shore Wager · ends in 1d 4h",
				"fixture_vale · ends in 1d 4h",
				"fixture_brook · ends in 2d",
			}, { block.runs[1].first, block.runs[2].first, block.runs[3].first })
			assert.are.equal("+1 more wagers on the table", block.more)
		end)

		it('reads "settled" for a completed run (HNT-R146)', function()
			local history = twoOn()
			history[#history + 1] = castIn(SHORE, C.DARKSHORE, { C.NIGHTFIN, C.BLACKMOUTH })

			local block = assert(read(start(history)))

			assert.are.same(
				{ dot = "wagers", first = "Shore Wager · settled", second = "3 of 3 first marks" },
				block.runs[1]
			)
		end)

		it("is gone with no run on: the Hunts block alone, at the top (HNT-R175)", function()
			local r = start({})

			assert.is_nil(read(r))
			for _, line in ipairs(r.ns.tracker.wagers.lines) do
				assert.is_false(line:IsShown())
			end
			assert.is_false(r.ns.tracker.wagers.more:IsShown())
			assert.are.equal(0, topOf(r.ns.tracker.header))
		end)

		it("shows with no run on as the companion hint's block alone, its switch on as at 1.0 (HNT-R176)", function()
			local r = start({}, { hint = true })

			assert.are.same({ header = "Pagle Wagers", runs = {} }, read(r))
			assert.is_true(r.ns.tracker.wagers.hint:IsShown())
			assert.is_false(r.ns.tracker.wagers.more:IsShown())
		end)

		it(
			"loses a run that ends at the regroup the run's end sets, and goes with the last (HNT-R143, HNT-R42)",
			function()
				local history = twoOn()
				history[#history + 1] = runOn("fixture_brook", 30 * 60 + 30)
				local r = start(history)
				assert.are.equal("fixture_brook · ends in 30m", read(r).runs[1].first)

				hunts.wait(r, 30 * 60) -- the 60 s refreshes regroup meanwhile; 30 s before its end it is still on
				r.loaded.client.runTimers()
				assert.are.equal(3, #read(r).runs)

				hunts.wait(r, 30) -- its end: the runs timer regroups (HNT-R42)
				r.loaded.client.runTimers()

				local block = assert(read(r))
				assert.are.same(
					{ "Shore Wager · ends in 1d 3h", "fixture_vale · ends in 1d 3h" },
					{ block.runs[1].first, block.runs[2].first }
				)
				assert.are.equal(2, #block.runs)

				-- Both blocks collapsed, nothing refreshes every 60 s: the runs timer alone regroups as the last two end.
				r.ns.tracker.header:Click()
				r.ns.tracker.wagers.header:Click()
				hunts.wait(r, DAY + 4 * HOUR - 30 * 60 - 30)
				r.loaded.client.runTimers()

				assert.is_nil(read(r))
				assert.are.equal(SHORE.time + 3 * DAY, r.ns.groups:Time())
			end
		)
	end)

	describe("its clicks (HNT-R164, HNT-R175)", function()
		it("open the board with a run selected from its lines", function()
			local r = start(twoOn())
			local second = r.ns.tracker.wagers.lines[2]

			second:Click()

			assert.is_true(r.ns.board:IsShown())
			local place = r.ns.board.router:Place()
			assert.are.same({ "board", VALE_KEY }, { place.mode, place.run })

			r.ns.tracker.wagers.lines[1]:Click() -- open, it turns to the other run

			assert.are.same({ "board", SHORE_KEY }, { r.ns.board.router:Place().mode, r.ns.board.router:Place().run })
		end)

		it('open the Pagle Wagers spread from "+1 more"', function()
			local history = twoOn()
			history[#history + 1] = runOn("fixture_brook", 2 * DAY)
			history[#history + 1] = runOn("fixture_cove", 2 * DAY + HOUR)
			local r = start(history)
			local opened = {}
			r.ns.OpenWagers = function(runKey)
				opened[#opened + 1] = runKey or "spread"
			end

			r.ns.tracker.wagers.more:Click()

			assert.are.same({ "spread" }, opened)
		end)

		it('turn the board to the Pagle Wagers spread from "+1 more", a ticket per run on (HNT-R162)', function()
			local history = twoOn()
			history[#history + 1] = runOn("fixture_brook", 2 * DAY)
			history[#history + 1] = runOn("fixture_cove", 2 * DAY + HOUR)
			local r = start(history)

			r.ns.tracker.wagers.more:Click()

			assert.is_true(r.ns.board:IsShown())
			assert.are.same({ mode = "wagers" }, r.ns.board.router:Place())
			assert.are.equal(4, #r.ns.BoardWagersSpread().tickets)
		end)
	end)

	describe("its own collapsed state (HNT-R177)", function()
		it(
			"collapses from its header, saved apart from the Hunts block's, and stays collapsed after a reload",
			function()
				local r = start(twoOn())
				r.ns.SetPinned("fixture_snapper", true)
				local expanded = r.ns.tracker.frame:GetHeight()

				r.ns.tracker.wagers.header:Click()

				assert.are.same({ header = "Pagle Wagers", runs = {} }, read(r))
				assert.are.same({ true, false }, {
					r.ns.db.profile.tracker.wagersCollapsed,
					r.ns.db.profile.tracker.collapsed,
				})
				assert.are.same({ "Snapper Run" }, huntsShown(r)) -- the Hunts block stays open
				assert.is_true(r.ns.tracker.frame:GetHeight() < expanded)

				-- The next session, over what this one saved.
				local next = start(twoOn(), { saved = r.loaded.env.PagleHuntsDB })
				assert.are.same({ header = "Pagle Wagers", runs = {} }, read(next))
				assert.are.same({ "Snapper Run" }, huntsShown(next))

				next.ns.tracker.wagers.header:Click()

				assert.is_false(next.ns.db.profile.tracker.wagersCollapsed)
				assert.are.same(TWO_ON, read(next))
			end
		)

		it("stays open while the Hunts block collapses, and keeps counting down every 60 s (HNT-R42)", function()
			local r = start(twoOn())

			r.ns.tracker.header:Click()
			hunts.wait(r, 120)
			r.loaded.client.runTimers()

			assert.are.equal("Shore Wager · ends in 1d 3h", read(r).runs[1].first) -- 1d 3h 58m, minutes dropped
			assert.are.same({}, huntsShown(r))
			assert.are.equal(NOW + 120, r.ns.groups:Time())

			r.ns.tracker.wagers.header:Click() -- both collapsed: nothing counts down
			local grouped = r.ns.groups:Time()
			hunts.wait(r, 120)
			r.loaded.client.runTimers()

			assert.are.equal(grouped, r.ns.groups:Time())
		end)

		it("defaults to expanded (hunts.md › Data)", function()
			local r = start({})

			assert.are.same({ shown = true, collapsed = false, wagersCollapsed = false }, r.ns.db.profile.tracker)
		end)
	end)

	describe("its setting and frame (HNT-R177, HNT-R79)", function()
		it('hides with the Hunts block when "Show the Hunts tracker" is off, and shows again when on', function()
			local r = start(twoOn())
			local checkbox = r.fake.settingsPage("trackers")[2].setting

			checkbox.set(false)

			assert.is_false(r.ns.tracker.frame:IsShown())
			assert.are.same({}, r.fake.dock.stack())

			checkbox.set(true)

			assert.are.same(TWO_ON, read(r))
			assert.are.equal(1, #r.fake.dock.stack())
		end)

		it("wears the equipped frame's paper under both blocks, its dots in paper ink", function()
			local r = start(twoOn())
			local view = r.ns.tracker

			r.fake.setPurchased({ [INKWASH] = true })
			assert.is_true(r.fake.Pagle.SetEquipped("hunts.trackerframe", INKWASH))

			assert.is_true(view.paper:IsShown())
			assert.are.same({ 268, view.frame.height }, { view.paper.width, view.paper.height })
			assert.are.equal("PAGLE WAGERS", view.wagers.title:GetText()) -- small caps on the paper, as "HUNTS"
			assert.are.equal("HUNTS", view.title:GetText())
			local ink, dot = r.ns.BOARD_LOOK.paperGroups.wagers, view.wagers.lines[1].dot
			assert.are.same({ "wagers", ink[1], ink[2], ink[3] }, {
				dot.group,
				dot.face.vertexColor[1],
				dot.face.vertexColor[2],
				dot.face.vertexColor[3],
			})
		end)
	end)

	describe("its states (HNT-R78, HNT-R43)", function()
		it('reads "updating…" for progress while the projection updates, then the counts', function()
			local r = start(twoOn())
			local projection, updating = r.ns.projection, true
			-- The projection's state as it stands, updating (a catch-up over a state that knows the runs, LOG-R74).
			r.ns.projection = {
				GetState = function()
					return projection:GetState()
				end,
				IsUpdating = function()
					return updating
				end,
			}

			r.ns.Redraw("projection")

			assert.are.same({ "updating…", "updating…" }, { read(r).runs[1].second, read(r).runs[2].second })
			assert.are.equal("Shore Wager · ends in 1d 4h", read(r).runs[1].first)

			updating = false
			r.ns.Redraw("projection")

			assert.are.same(TWO_ON, read(r))
		end)

		it("keeps its countdowns frozen with the board's while restricted, then counts on", function()
			local r = start(twoOn())

			r.fake.setRestricted(true)
			hunts.wait(r, 3 * HOUR)
			r.loaded.client.runTimers()
			r.ns.Redraw("names")

			assert.are.equal("Shore Wager · ends in 1d 4h", read(r).runs[1].first)

			r.fake.setRestricted(false)

			assert.are.equal("Shore Wager · ends in 1d 1h", read(r).runs[1].first)
		end)
	end)
end)
