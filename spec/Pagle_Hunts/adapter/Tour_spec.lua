-- Hunts' tour stops on FakePagle (CORE-R65, CORE-R68), over the fixture Hunt list, event pool and catalogue: the board
-- on a Hunt of each group, the Board with the wager strip, the WAGERS group and a run's entry, the Pagle Wagers spread,
-- a set's page, an entry from it and a retired entry, the tracker in the dock, and each good Hunts sells or gives
-- worn; each shown on the tour's sample (logic/Tour.lua) and put back as it was, nothing saved. FakePagle's clock is
-- before the rotation's starting point, so no run is on, and the sample's runs come from the fixture pool. The tour
-- runs on FakePagle's clock (fake.wait); Hunts' own timers on the client's, which stands still here.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local C = catalogue
-- Realm 17:30, when the fixture Hunts fill every group: Lightning Eel's day window is open (Now), the night Hunts and
-- fixture_oddity's 18:00 open within 3 hours (Soon), fixture_hefty_blackmouth's 22:00 and the out-of-season ones are
-- Later, and fixture_rack waits on its aura (On demand) (HNT-R40).
local FROM = hunts.untilRealm(17, 30)
-- One stop's span on the tour's clock: shown, shot 2.8 s in, hidden 0.5 s later, the next 0.3 s after that.
local STOP = 2.8 + 0.5 + 0.3
-- The eleven stops before the goods, then each cover and tracker frame but the defaults (HNT-R121).
local COVERS, FRAMES = {}, {}
for _, row in ipairs(hunts.GOODS["hunts.notebookcover"]) do
	if row[2] ~= "default" then
		COVERS[#COVERS + 1] = row[1]
	end
end
for _, row in ipairs(hunts.GOODS["hunts.trackerframe"]) do
	if row[2] ~= "default" then
		FRAMES[#FRAMES + 1] = row[1]
	end
end
local GOODS_FROM = 11
local STOPS = GOODS_FROM + #COVERS + #FRAMES

-- Hunts' Session summary line as Core holds it, or nil (HNT-R89).
local function summaryLine(fake)
	local lines = fake.global.summary.lines.Hunts
	return lines and lines.lines.hunts
end

--- Hunts on a FakePagle at realm 17:30 (support.start), logged in, caught up and grouped, the fixture items' names
--- loaded and Fishing read at 150; `options.profile` as PagleHuntsDB's profile; with `options.fresh`, for a new Angler:
--- the onboarding state as login step 1 makes it with no Cast yet (ONB-R1, ONB-R2: `letter = "waiting"`), nothing seen
--- and no First evening item done; dev on.
---@param options { profile: table?, fresh: boolean? }?
---@return HuntsRun
local function start(options)
	options = options or {}
	local run = hunts.start({
		saved = options.profile
			and { profileKeys = { ["Angler - Testrealm"] = "Default" }, profiles = { Default = options.profile } },
		from = FROM,
		names = true,
		beforeLogin = function(run)
			if options.fresh then
				run.fake.global.onboarding = run.fake.ns.NewOnboardingState("waiting")
			end
			-- the two the board shows that catalogue.NAMES leaves out
			run.loaded.client.loadItem(C.SUNSCALE, "Sunscale Salmon")
			run.loaded.client.loadItem(C.GROUPER, "Darkshore Grouper")
		end,
	})
	run.fake.slash("dev on")
	run.fake.printed = {}
	return run
end

-- What stop `i` shows at its shot: the board's place, the group of the Hunt it shows, its entry's name, whether the
-- set's seal shows and its cover; or the tracker's lines and frame.
---@param run HuntsRun
local function seen(run)
	local ns = run.ns
	local board, tracker = ns.board, ns.tracker
	local out = { board = board:IsShown(), tracker = tracker.frame:IsShown() }
	if out.board then
		local place = board.router:Place()
		out.place = place
		local row = place.hunt and ns.groups:Row(place.hunt)
		out.group = row and row.group
		local right = board:Page(place, "right")
		if right and right.entry then
			out.name = right.entry.name:IsShown() and right.entry.name:GetText() or nil
		end
		if right and right.view then
			out.seal = right.view.seal:IsShown()
		end
		out.left = shownTexts(board:Page(place, "left"))
		out.right = right and shownTexts(right) or {}
		out.cover = board.cover
	end
	out.grouper = ns.groups:Row("fixture_grouper") ~= nil
	local lines = 0
	for _, line in ipairs(tracker.lines) do
		lines = lines + (line:IsShown() and 1 or 0)
	end
	out.lines, out.wearing = lines, tracker.wearing
	return out
end

-- Runs Hunts' tour, returning what each stop showed at its shot; `during(i)` runs at stop `i`'s shot, if given.
---@param run HuntsRun
---@param during fun(i: integer)?
---@return table[]
local function tour(run, during)
	local shown = {}
	run.fake.slash("dev tour hunts")
	run.fake.wait(1.6)
	for i = 1, STOPS do
		shown[i] = seen(run)
		if during then
			during(i)
		end
		run.fake.wait(STOP)
	end
	run.fake.wait(60)
	return shown
end

describe("Hunts' tour stops (CORE-R65, CORE-R68)", function()
	it("are the board's groups, Pagle Wagers, a set, its entries, the tracker and each good, in tour order", function()
		local run = start()

		run.fake.slash("dev tour list hunts")

		assert.are.same({
			"Pagle dev: " .. STOPS .. " tour stops:",
			"  hunts.board.home: the Hunts board: the Board, on the Hunt it picks",
			"  hunts.board.now: the Hunts board: a Hunt in Now",
			"  hunts.board.soon: the Hunts board: a Hunt in Soon",
			"  hunts.board.later: the Hunts board: a Hunt in Later",
			"  hunts.board.ondemand: the Hunts board: a Hunt in On demand",
			"  hunts.board.wagers: the Hunts board: the wager strip and the WAGERS group, a run's entry",
			"  hunts.wagers: the Hunts board: the Pagle Wagers spread, its slips and ladder",
			"  hunts.set.page: the Hunts board: a set's page, its title earned",
			"  hunts.set.entry: the Hunts board: an entry opened from its set's page",
			"  hunts.set.retired: the Hunts board: a Retired Hunt's entry",
			"  hunts.tracker: the Hunts tracker in the dock, with three pins",
			"  hunts.cover.oilcloth: the Hunts board in the Oilcloth cover",
			"  hunts.cover.tooled: the Hunts board in the Tooled Leather cover",
			"  hunts.cover.verdigris: the Hunts board in the Verdigris cover",
			"  hunts.cover.canvas: the Hunts board in the Canvas Field Pad cover",
			"  hunts.cover.kraft: the Hunts board in the Waxed Kraft cover",
			"  hunts.cover.tartan: the Hunts board in the Tartan Wool cover",
			"  hunts.cover.maplinen: the Hunts board in the Map Linen cover",
			"  hunts.cover.planks: the Hunts board in the Bound Planks cover",
			"  hunts.cover.snakeskin: the Hunts board in the Snakeskin cover",
			"  hunts.cover.shagreen: the Hunts board in the Stingray Shagreen cover",
			"  hunts.cover.lacquer: the Hunts board in the Lacquered Red cover",
			"  hunts.cover.bone: the Hunts board in the Bone & Rawhide cover",
			"  hunts.cover.brasscase: the Hunts board in the Brass Hunter's Case cover",
			"  hunts.cover.scrimshaw: the Hunts board in the Scrimshaw Panel cover",
			"  hunts.cover.trophycase: the Hunts board in the Gilded Trophy Case cover",
			"  hunts.cover.pathfinder: the Hunts board in the Pathfinder's Calf cover",
			"  hunts.cover.fiveseal: the Hunts board in the Five-Set Seal cover",
			"  hunts.cover.wagersilk: the Hunts board in the Winner's Brocade cover",
			"  hunts.trackerframe.inkwash: the Hunts tracker in the Ink Wash frame",
			"  hunts.trackerframe.waxseal: the Hunts tracker in the Wax Seal frame",
			"  hunts.trackerframe.slate: the Hunts tracker in the Chalk Slate frame",
			"  hunts.trackerframe.mapscrap: the Hunts tracker in the Map Scrap frame",
			"  hunts.trackerframe.bounty: the Hunts tracker in the Bounty Poster frame",
			"  hunts.trackerframe.spyglass: the Hunts tracker in the Spyglass Rim frame",
			"  hunts.trackerframe.wagerribbon: the Hunts tracker in the Winner's Ribbon frame",
		}, run.fake.printed)
	end)

	it("show the board on a Hunt of each group, on the sample, before a real Hunt is out (HNT-R40)", function()
		local run = start()

		local shown = tour(run)

		assert.is_true(shown[1].board)
		assert.are.equal("board", shown[1].place.mode)
		assert.is_string(shown[1].name)
		for i, group in ipairs({ "now", "soon", "later", "onDemand" }) do
			local stop = shown[1 + i]
			assert.are.equal("board", stop.place.mode, group)
			assert.are.equal(group, stop.group)
			assert.are.equal("string", type(stop.name), group)
		end
		-- fixture_grouper isn't out until 2026-11-04 (HNT-R2): only the sample groups it.
		assert.is_nil(run.ns.groups:Row("fixture_grouper"))
		assert.is_true(shown[1].grouper)
	end)

	it("show the wager strip, the WAGERS group and a run's entry on sample runs from the pool (HNT-R161)", function()
		local run = start()
		-- Before the rotation's starting point, with no pushed run: nothing is on (HNT-R204).
		assert.are.same({}, run.ns.RunsShown(run.ns.State(), run.loaded.env.GetServerTime()))

		local shown = tour(run)

		local stop = shown[6]
		assert.are.equal("board", stop.place.mode)
		assert.matches("^fixture_%a+@%d+$", stop.place.run)
		for _, text in ipairs({ "PAGLE WAGERS", "Shore Wager · Darkshore", "+1 more on the table", "WAGERS" }) do
			assert(hunts.has(stop.left, text), "the Board lacks " .. text)
		end
		assert.is_true(hunts.has(stop.right, "FROM THE ROTATION · LOW WATERS"))
		-- Nothing of the sample's runs stays after the tour.
		assert.are.same({}, run.ns.RunsShown(run.ns.State(), run.loaded.env.GetServerTime()))
	end)

	it("show the Pagle Wagers spread with a slip per sample run, one settled, and the ladder (HNT-R162)", function()
		local run = start()

		local shown = tour(run)

		local stop = shown[7]
		assert.are.same({ mode = "wagers" }, stop.place)
		for _, text in ipairs({
			"On the table",
			"Shore Wager",
			"fixture_vale",
			"SETTLED",
			"7 wagers settled · 18 more for Bookmaker's Bane",
		}) do
			assert(hunts.has(stop.left, text), "the spread lacks " .. text)
		end
		assert.is_true(hunts.has(stop.right, "Shore Wager"))
	end)

	it("show a set's page with its title earned, an entry from it and a retired entry (HNT-R3, HNT-R66)", function()
		local run = start()

		local shown = tour(run)

		assert.are.same({ mode = "set", set = "fixture_dusk" }, shown[8].place)
		assert.is_true(shown[8].seal)
		assert.are.same({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }, shown[9].place)
		assert.is_string(shown[9].name)
		assert.are.same({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" }, shown[10].place)
		assert.is_string(shown[10].name)
	end)

	it("show the tracker in the dock with the sample's three pins, the board closed (HNT-R75, HNT-R76)", function()
		local run = start()

		local shown = tour(run)

		assert.is_false(shown[11].board)
		assert.is_true(shown[11].tracker)
		assert.are.equal(3, shown[11].lines)
		assert.is_nil(shown[11].wearing)
	end)

	it(
		"wear each notebook cover on the board and each tracker frame on the tracker, earned ones too (HNT-R121, HNT-R122)",
		function()
			local run = start()
			local ns = run.ns

			local shown = tour(run)

			for i, id in ipairs(COVERS) do
				assert.are.equal(ns.COVERS[id], shown[GOODS_FROM + i].cover)
				assert.are.same(
					{ mode = "board", hunt = shown[GOODS_FROM + i].place.hunt },
					shown[GOODS_FROM + i].place
				)
			end
			for i, id in ipairs(FRAMES) do
				assert.are.equal(id, shown[GOODS_FROM + #COVERS + i].wearing)
				assert.are.equal(3, shown[GOODS_FROM + #COVERS + i].lines)
			end
			assert.are.equal(STOPS, #run.fake.tourShots)
		end
	)

	it("leave Hunts as they found it: board closed, the real list, state, grouping, pins; nothing saved", function()
		local run = start({ profile = { pins = {}, tracker = { shown = true, collapsed = true } } })
		local ns = run.ns
		local before = {
			hunts = ns.hunts,
			projection = ns.projection,
			grouping = ns.groups:Grouping(),
			pins = ns.db.profile.pins,
			cover = ns.board.cover,
			applyCast = ns.ApplyCast,
			reached = ns.outlets.Reached,
			db = hunts.deepCopy(run.loaded.env.PagleHuntsDB),
			line = summaryLine(run.fake),
		}
		local lines = {}

		tour(run, function(i)
			lines[i] = summaryLine(run.fake) or false
		end)

		assert.is_false(ns.board:IsShown())
		assert.are.same({ mode = "board" }, ns.board.router:Place())
		assert.are.equal(before.cover, ns.board.cover)
		assert.are.equal(before.hunts, ns.hunts)
		assert.are.equal(before.projection, ns.projection)
		assert.are.equal(before.grouping, ns.groups:Grouping())
		assert.is_false(ns.groups:IsPaused())
		assert.are.equal(before.pins, ns.db.profile.pins)
		assert.are.equal(before.applyCast, ns.ApplyCast)
		assert.are.equal(before.reached, ns.outlets.Reached)
		assert.is_nil(ns.tracker.wearing)
		assert.is_true(ns.tracker.frame:IsShown())
		assert.are.same(before.db, run.loaded.env.PagleHuntsDB)
		-- The sample's summary line never reaches the Session summary (HNT-R89).
		for i = 1, STOPS do
			assert.are.equal(before.line or false, lines[i], "stop " .. i)
		end
	end)

	it("write nothing of a new Angler's onboarding: no hunts item, no First look seen (CORE-R68, ONB-R84)", function()
		local run = start({ fresh = true })
		local fake = run.fake
		-- Core's adapter gives each First look its tour stop, core.onboarding.look.hunts.board (ONB-R84).
		fake.ns.AddFirstLookTourStops()
		local before = hunts.deepCopy(fake.global.onboarding)

		tour(run)
		fake.slash("dev tour core")
		fake.wait(1.6)
		local showing = fake.firstLooks:Showing()
		fake.wait(60)

		assert.are.equal(STOPS + 1, #fake.tourShots)
		assert.are.same(before, fake.global.onboarding)
		assert.is_false(fake.onboarding:IsEveningItemDone("hunts"))
		assert.are.same({}, fake.notesShown)
		-- The First look's own stop still shows the set, marking nothing (ONB-R84).
		assert.are.equal("hunts.board", showing and showing.id)
		assert.is_false(run.ns.board:IsShown())
	end)

	it("tick the hunts item and show the First look as the Angler opens the board after (ONB-R55, ONB-R61)", function()
		local run = start({ fresh = true })
		tour(run)

		run.ns.board:Open({ mode = "board" })

		assert.is_true(run.fake.onboarding:IsEveningItemDone("hunts"))
		assert.is_true(run.fake.onboarding:IsLookSeen("hunts.board"))
	end)

	it("leave the board open on the place it was on, and a hidden tracker hidden", function()
		local run = start({ profile = { tracker = { shown = false, collapsed = false } } })
		local ns = run.ns
		ns.board:Open({ mode = "set", set = "fixture_wagers" })

		tour(run)

		assert.is_true(ns.board:IsShown())
		assert.are.same({ mode = "set", set = "fixture_wagers" }, ns.board.router:Place())
		assert.is_false(ns.tracker.frame:IsShown())
	end)

	it("apply a live Cast during a stop to the real list, and regroup on it after (HNT-R2, HNT-R42)", function()
		local run = start()
		local ns = run.ns
		local casts, grouping = ns.State().casts, ns.groups:Grouping()

		tour(run, function(i)
			if i == 2 then
				-- Darkshore Grouper at night on Auberdine Pier: under the sample fixture_grouper is out and would
				-- count it; really it isn't out until 2026-11-04.
				hunts.fishAt(run.fake, hunts.NIGHT, { zone = C.DARKSHORE, subzone = C.PIER })
				run.fake.playCast("caught", { { itemID = C.GROUPER, quantity = 1 } })
			end
		end)

		assert.are.equal(casts + 1, ns.State().casts)
		assert.is_nil(ns.State().hunts.fixture_grouper)
		-- The move to the Pier asked for a regroup, which waited for the stop's hide and ran on the real list.
		assert.are_not.equal(grouping, ns.groups:Grouping())
		assert.is_nil(ns.groups:Row("fixture_grouper"))
		assert.is_not_nil(ns.groups:Row("fixture_snapper"))
	end)

	it("aren't registered on a Core without M:RegisterTourStop, and Hunts still starts", function()
		local fake = newFakePagle()
		fake.ns.ModuleHandle.RegisterTourStop = nil

		local loaded = hunts.load(fake)

		assert.is_not_nil(loaded.ns.Module)
		assert.are.same({}, fake.ns.tourStops:List(fake.registry:Modules(), "hunts"))
	end)
end)
