-- The Hunts tracker (HNT-R75–R79, CORE-R70–R73, SET-R41, SET-R44) on FakePagle, over the fixture Hunt list and
-- catalogue: the block Hunts docks in Core's dock, its lines, clicks, states and frame, and its setting on the
-- Trackers page. The server time runs on the client's clock (fake.globals.GetServerTime), so the client's C_Timer and
-- the grouping's "now" move together, as in adapter/Groups_spec.lua. The lines' pure parts are in
-- spec/Pagle_Hunts/logic/Tracker_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local FRAME_SLOT = "hunts.trackerframe"
local INKWASH = "hunts.trackerframe.inkwash"
local REALM_START, untilRealm, wait = hunts.REALM_START, hunts.untilRealm, hunts.wait

---@class TrackerRun: HuntsRun

--- Hunts on a FakePagle through its first PLAYER_ENTERING_WORLD, so the first grouping has run (HNT-R42): the fixture
--- catalogue with the fixture items' names loaded, `options.saved` as PagleHuntsDB, `options.history(fake)` appended
--- before login, Fishing read at 150, and the projection caught up unless `options.caughtUp` is false (it then stays
--- updating, HNT-R78). The server time starts `options.from` seconds after SERVER_TIME (realm 08:15), so the realm
--- clock does too: the live conditions' realm minute is read against their own time (HNT-R50). With
--- `options.grouped` false, the first PLAYER_ENTERING_WORLD hasn't come yet.
---@param options { saved: table?, history: fun(fake: table)?, caughtUp: boolean?, from: integer?, grouped: boolean? }?
---@return TrackerRun
local function start(options)
	options = options or {}
	return hunts.start({
		saved = options.saved,
		history = options.history,
		from = options.from,
		names = true,
		caughtUp = options.caughtUp,
		world = options.grouped,
	}) --[[@as TrackerRun]]
end

--- The tracker as the player reads it: the header, then each shown Hunt's two lines with its dot's group, then the
--- "+N more" line or the empty line, whichever shows.
---@param run TrackerRun
---@return { header: string, hunts: { dot: string, first: string, second: string }[], more: string?, empty: string? }
local function read(run)
	local view = run.ns.tracker
	local out = { header = view.title:GetText(), hunts = {} }
	for _, line in ipairs(view.lines) do
		if line:IsShown() then
			out.hunts[#out.hunts + 1] =
				{ dot = line.dot.group, first = line.first:GetText(), second = line.second:GetText() }
		end
	end
	if view.more:IsShown() then
		out.more = view.more.text:GetText()
	end
	if view.empty:IsShown() then
		out.empty = view.empty:GetText()
	end
	return out
end

--- The ids of the trackers the dock shows, top to bottom (CORE-R70).
---@param run TrackerRun
---@return string[]
local function docked(run)
	local ids = {}
	for i, tracker in ipairs(run.fake.dock.stack()) do
		ids[i] = tracker.id
	end
	return ids
end

describe("the Hunts tracker", function()
	describe("in the dock (HNT-R75, CORE-R70, CORE-R72)", function()
		it('docks once at order 10 and, with nothing pinned, reads "Pin a Hunt to keep it here."', function()
			local run = start()

			assert.are.same({ "hunts" }, docked(run))
			local trackers = run.fake.ns.dock:Trackers()
			assert.are.same({ { "hunts", 10, "Hunts" } }, { { trackers[1].id, trackers[1].order, trackers[1].module } })
			assert.are.equal(run.ns.tracker.frame, run.fake.dock.stack()[1].frame)
			assert.are.same({ header = "Hunts", hunts = {}, empty = "Pin a Hunt to keep it here." }, read(run))
		end)

		it('reads "Pin a Hunt to keep it here." before the first grouping too (HNT-R76)', function()
			local run = start({ grouped = false })

			assert.is_nil(run.ns.groups:Grouping())
			assert.are.same({ header = "Hunts", hunts = {}, empty = "Pin a Hunt to keep it here." }, read(run))
		end)

		it(
			"hides when its setting is turned off, so the dock stacks nothing, and shows again when on (SET-R41)",
			function()
				local run = start()
				local checkbox = run.fake.settingsPage("trackers")[2].setting

				checkbox.set(false)

				assert.is_false(checkbox.get())
				assert.is_false(run.ns.db.profile.tracker.shown)
				assert.are.same({}, docked(run))

				checkbox.set(true)

				assert.are.same({ "hunts" }, docked(run))
				assert.are.same({ header = "Hunts", hunts = {}, empty = "Pin a Hunt to keep it here." }, read(run))
			end
		)

		it("stays off at login when an earlier session turned it off (hunts.md › Data)", function()
			local run = start({
				saved = {
					profileKeys = { ["Angler - Testrealm"] = "Default" },
					profiles = { Default = { tracker = { shown = false, collapsed = false } } },
				},
			})

			assert.are.same({}, docked(run))
		end)

		it("resizes with its lines, so the dock reflows below it (HNT-R75, CORE-R70)", function()
			local run = start()
			local empty = run.ns.tracker.frame:GetHeight()

			run.ns.SetPinned("fixture_snapper", true)
			run.ns.SetPinned("fixture_oddity", true)

			assert.is_true(run.ns.tracker.frame:GetHeight() > empty)
		end)

		it("hands a Shift-drag on its lines to the docked block, which Core moves the dock by (CORE-R71)", function()
			local run = start()
			run.ns.SetPinned("fixture_snapper", true)
			local block = run.ns.tracker.frame
			local started = {}
			block:SetScript("OnDragStart", function(frame, button)
				started[#started + 1] = { frame, button }
			end)

			run.ns.tracker.lines[1]:GetScript("OnDragStart")(run.ns.tracker.lines[1], "LeftButton")
			run.ns.tracker.header:GetScript("OnDragStart")(run.ns.tracker.header, "LeftButton")

			assert.are.same({ { block, "LeftButton" }, { block, "LeftButton" } }, started)
		end)
	end)

	describe("its setting (SET-R41, SET-R44, CORE-R42)", function()
		it('is "Show the Hunts tracker" under a "Hunts" header on Trackers, before the frame\'s dropdown', function()
			local run = start()

			local rows = {}
			for i, row in ipairs(run.fake.settingsPage("trackers")) do
				rows[i] = { row.module, row.kind, row.label, row.slot }
			end
			assert.are.same({
				{ "Hunts", "header", "Hunts" },
				{ "Hunts", "checkbox", "Show the Hunts tracker" },
				{ "Hunts", "slot", "Hunts tracker frame", FRAME_SLOT },
			}, rows)
			local checkbox = run.fake.settingsPage("trackers")[2].setting
			assert.are.equal(
				"A small tracker under the minimap with the Hunts you've pinned on the board.",
				checkbox.tooltip
			)
			assert.is_true(checkbox.default)
			assert.is_true(checkbox.get())
		end)
	end)

	describe("its lines (HNT-R76)", function()
		it("list two pinned Hunts in board order, each with its dot, name, label, target line and progress", function()
			local run = start()

			-- Realm 08:15: both Later, Snapper Run opening at 20:00 and Hefty Blackmouth at 22:00 (HNT-R44).
			run.ns.SetPinned("fixture_hefty_blackmouth", true)
			run.ns.SetPinned("fixture_snapper", true)

			assert.are.same({
				{
					dot = "later",
					first = "Snapper Run · 20:00",
					second = "Raw Nightfin Snapper · you're here · 0 / 1",
				},
				{
					dot = "later",
					first = "Hefty Blackmouth · 22:00",
					second = "Oily Blackmouth, Hefty or better · you're here · 0 / 1",
				},
			}, read(run).hunts)
			assert.is_nil(read(run).empty)
			assert.is_nil(read(run).more)
		end)

		it("reads \"you're here\" only while the live zone is one of the Hunt's zones (HNT-R76, HNT-R31)", function()
			local run = start()
			run.ns.SetPinned("fixture_hefty_blackmouth", true)
			run.ns.SetPinned("fixture_snapper", true)

			-- Westfall has Blackmouth and no Nightfin; Stormwind neither.
			hunts.fishAt(run.fake, REALM_START, { zone = C.WESTFALL })
			assert.are.same({
				"Raw Nightfin Snapper · 0 / 1",
				"Oily Blackmouth, Hefty or better · you're here · 0 / 1",
			}, { read(run).hunts[1].second, read(run).hunts[2].second })

			hunts.fishAt(run.fake, REALM_START, { zone = C.STORMWIND })
			assert.are.same({
				"Raw Nightfin Snapper · 0 / 1",
				"Oily Blackmouth, Hefty or better · 0 / 1",
			}, { read(run).hunts[1].second, read(run).hunts[2].second })
		end)

		it('reads "1 / 10" after a qualifying Catch, the next unreached threshold (HNT-R76, HNT-R11)', function()
			local run = start()
			run.ns.SetPinned("fixture_snapper", true)
			hunts.fishAt(run.fake, hunts.NIGHT, { zone = C.DARKSHORE })

			run.fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })

			assert.are.equal("Raw Nightfin Snapper · you're here · 1 / 10", read(run).hunts[1].second)
		end)

		it(
			'reads "all tiers" for a finished Hunt, and the count toward the next tier for one with tiers left',
			function()
				-- Five Nightfin at night in April: fixture_tide_late (tiers 1 and 5) finished, fixture_snapper at 5 of 10.
				local run = start({
					history = function(fake)
						local casts = {}
						for day = 40, 44 do
							casts[#casts + 1] = hunts.cast(day, hunts.NIGHT, { zone = C.ELWYNN }, { C.NIGHTFIN })
						end
						hunts.append(fake, casts)
					end,
				})
				run.ns.SetPinned("fixture_snapper", true)
				run.ns.SetPinned("fixture_tide_late", true)

				local lines = read(run).hunts
				assert.are.same({ "Raw Nightfin Snapper · you're here · 5 / 10" }, { lines[1].second })
				assert.matches(" · all tiers$", lines[2].second)
				assert.matches("^fixture_tide_late · ", lines[2].first) -- no name in the fixture lore: its ID (HNT-R1)
			end
		)

		it('show 6 of 7 pinned Hunts, then "+1 more" (HNT-R76, Tunables)', function()
			local run = start()
			for _, id in ipairs({
				"fixture_snapper",
				"fixture_oddity",
				"fixture_rack",
				"fixture_hefty_blackmouth",
				"fixture_eel",
				"fixture_bass",
				"fixture_squid",
			}) do
				run.ns.SetPinned(id, true)
			end

			local tracker = read(run)
			assert.are.equal(6, #tracker.hunts)
			assert.are.equal("+1 more", tracker.more)
			assert.is_nil(tracker.empty)
		end)
	end)

	describe("its clicks (HNT-R77)", function()
		it('open the board on a Hunt from its lines, and on the Board from "+1 more"', function()
			local run = start()
			for _, id in ipairs({
				"fixture_snapper",
				"fixture_oddity",
				"fixture_rack",
				"fixture_hefty_blackmouth",
				"fixture_eel",
				"fixture_bass",
				"fixture_squid",
			}) do
				run.ns.SetPinned(id, true)
			end
			local board = run.ns.board
			local second = run.ns.tracker.lines[2]

			second:Click()

			assert.is_true(board:IsShown())
			assert.are.same({ mode = "board", hunt = second.huntID }, board.router:Place())
			assert.is_not_nil(second.huntID)

			board:Hide()
			run.ns.tracker.more:Click()

			-- On the Board, with no Hunt asked for: the timeline selects HNT-R67's own (#193).
			assert.is_true(board:IsShown())
			assert.are.equal("board", board.router:Place().mode)
		end)

		it("collapse and expand the block from its header, saved, and still collapsed after a reload", function()
			local run = start()
			run.ns.SetPinned("fixture_snapper", true)
			local expanded = run.ns.tracker.frame:GetHeight()

			run.ns.tracker.header:Click()

			assert.are.same({ header = "Hunts", hunts = {} }, read(run))
			assert.is_true(run.ns.db.profile.tracker.collapsed)
			assert.is_true(run.ns.tracker.frame:GetHeight() < expanded)
			assert.are.same({ "hunts" }, docked(run)) -- the header stays in the dock

			-- The next session, over what this one saved.
			local next = start({ saved = run.loaded.env.PagleHuntsDB })
			assert.are.same({ header = "Hunts", hunts = {} }, read(next))

			next.ns.tracker.header:Click()

			assert.is_false(next.ns.db.profile.tracker.collapsed)
			assert.are.equal("Snapper Run · 20:00", read(next).hunts[1].first)
		end)
	end)

	describe("its states (HNT-R78, HNT-R43)", function()
		it('reads "updating…" for progress while the projection is updating, then the count', function()
			local run = start({ caughtUp = false })
			run.ns.SetPinned("fixture_snapper", true)

			assert.are.equal("Raw Nightfin Snapper · you're here · updating…", read(run).hunts[1].second)

			run.fake.enterWorld() -- login step 3 catches the projection up (LOG-R71)

			assert.are.equal("Raw Nightfin Snapper · you're here · 0 / 1", read(run).hunts[1].second)
		end)

		it("counts down every 60 s while shown, and keeps its last grouping's labels while restricted", function()
			local run = start({ from = untilRealm(15, 30) })
			run.ns.SetPinned("fixture_oddity", true) -- 18:00 to 21:00 realm time
			assert.are.equal("Oddity Hour · in 2h 30m", read(run).hunts[1].first)

			wait(run, 120) -- two refreshes (HNT-R42)
			assert.are.equal("Oddity Hour · in 2h 28m", read(run).hunts[1].first)

			run.fake.setRestricted(true)
			wait(run, 600)
			run.ns.Redraw("names") -- a redraw while restricted draws the grouping kept (HNT-R43)
			assert.are.equal("Oddity Hour · in 2h 28m", read(run).hunts[1].first)

			run.fake.setRestricted(false) -- regroups at once (HNT-R43)
			assert.are.equal("Oddity Hour · in 2h 18m", read(run).hunts[1].first)
		end)

		it("stops the 60 s refresh while collapsed or hidden: nothing to count down (HNT-R42)", function()
			local run = start({ from = untilRealm(15, 30) })
			run.ns.SetPinned("fixture_oddity", true)
			run.ns.tracker.header:Click()
			local grouped = run.ns.groups:Time()

			wait(run, 120)

			assert.are.equal(grouped, run.ns.groups:Time())
		end)

		it("counts down from now on expanding, however long it was collapsed (HNT-R42, HNT-R43)", function()
			local run = start({ from = untilRealm(15, 30) })
			run.ns.SetPinned("fixture_oddity", true) -- 18:00 to 21:00 realm time
			run.ns.tracker.header:Click()
			local grouped = run.ns.groups:Time()
			wait(run, 3600)
			assert.are.equal(grouped, run.ns.groups:Time()) -- no regroup while collapsed

			run.ns.tracker.header:Click()

			assert.are.equal("Oddity Hour · in 1h 30m", read(run).hunts[1].first)
		end)
	end)

	describe("its frame (HNT-R79, CORE-R73)", function()
		it("is the plain native block with no frame equipped, and redraws in Ink Wash when it is equipped", function()
			local run = start()
			local look = run.ns.tracker.look
			assert.is_false(look.backdrop:IsShown())

			run.fake.setPurchased({ [INKWASH] = true }) -- bought (SHOP-R11)
			assert.is_true(run.fake.Pagle.SetEquipped(FRAME_SLOT, INKWASH))

			local inkwash = run.ns.TRACKER_FRAMES[INKWASH]
			assert.is_true(look.backdrop:IsShown())
			assert.are.equal(inkwash.backdrop, look.backdrop.texture)
			local tint = look.backdrop.vertexColor
			assert.are.same(inkwash.tint, { tint[1], tint[2], tint[3] })
			for _, line in ipairs(look.border) do
				assert.is_true(line:IsShown())
			end
		end)

		it("wears the frame equipped in an earlier session from login (HNT-R79, SHOP-R32)", function()
			local fake = newFakePagle()
			fake.setPurchased({ ["hunts.trackerframe.waxseal"] = true })
			fake.profile.appearance[FRAME_SLOT] = "hunts.trackerframe.waxseal"
			local loaded = hunts.load(fake)
			fake.login()

			local view = loaded.ns.tracker
			local waxseal = loaded.ns.TRACKER_FRAMES["hunts.trackerframe.waxseal"]
			assert.are.equal(waxseal.backdrop, view.look.backdrop.texture)
			assert.is_true(view.look.seal:IsShown())
			local ink = view.title.textColor
			assert.are.same(waxseal.ink, { ink[1], ink[2], ink[3] }) -- dark words on the parchment
		end)
	end)
end)
