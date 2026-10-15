-- Hunts' tour stops on FakePagle (CORE-R65, CORE-R68), over the fixture Hunt list and catalogue: the board on a Hunt
-- of each group, a set's page, an entry from it and a retired entry, the tracker in the dock, and each good Hunts
-- sells worn; each shown on the tour's sample (logic/Tour.lua) and put back as it was, nothing saved. The tour runs
-- on FakePagle's clock (fake.wait); Hunts' own timers on the client's, which stands still here.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local C = catalogue
local REALM_START = 8 * 60 + 15 -- FakePagle's realm clock at SERVER_TIME: 08:15 on Sunday 11 October 2026
-- Realm 17:30, when the fixture Hunts fill every group: Lightning Eel's day window is open (Now), the night Hunts and
-- fixture_oddity's 18:00 open within 3 hours (Soon), fixture_hefty_blackmouth's 22:00 and the out-of-season ones are
-- Later, and fixture_rack waits on its aura (On demand) (HNT-R40).
local FROM = (17 * 60 + 30 - REALM_START) * 60
-- One stop's span on the tour's clock: shown, shot 1.5 s in, hidden 0.5 s later, the next 0.3 s after that.
local STOP = 1.5 + 0.5 + 0.3
local STOPS = 14

-- A deep copy of `value`, for comparing saved data before and after.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, field in pairs(value) do
		out[key] = copy(field)
	end
	return out
end

-- Hunts' Session summary line as Core holds it, or nil (HNT-R89).
local function summaryLine(fake)
	local lines = fake.global.summary.lines.Hunts
	return lines and lines.lines.hunts
end

---@class TourRun
---@field ns table
---@field fake table
---@field loaded LoadedAddon

--- Hunts on a FakePagle at realm 17:30, logged in, caught up and grouped, the fixture items' names loaded and
--- Fishing read at 150; `options.profile` as PagleHuntsDB's profile; dev on.
---@param options { profile: table? }?
---@return TourRun
local function start(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue.base())
	local clock
	fake.globals.GetServerTime = function()
		return SERVER_TIME + FROM + math.floor(clock and clock() or 0)
	end
	fake.globals.PagleHuntsDB = options.profile
		and { profileKeys = { ["Angler - Testrealm"] = "Default" }, profiles = { Default = options.profile } }
	local loaded = hunts.load(fake)
	clock = loaded.client.time
	for itemID, name in pairs({
		[C.NIGHTFIN] = "Raw Nightfin Snapper",
		[C.BLACKMOUTH] = "Oily Blackmouth",
		[C.SUNSCALE] = "Sunscale Salmon",
		[C.GROUPER] = "Darkshore Grouper",
		[C.DEVIATE] = "Deviate Fish",
		[13757] = "Lightning Eel",
		[13756] = "Raw Summer Bass",
		[13755] = "Winter Squid",
	}) do
		loaded.client.loadItem(itemID, name)
	end
	fake.login()
	fake.readSkill(150, 300, 0)
	fake.enterWorld()
	fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
	fake.slash("dev on")
	fake.printed = {}
	return { ns = loaded.ns, fake = fake, loaded = loaded }
end

-- What stop `i` shows at its shot: the board's place, the group of the Hunt it shows, its entry's name, whether the
-- set's seal shows and its cover; or the tracker's lines and frame.
---@param run TourRun
local function seen(run)
	local ns = run.ns
	local board, tracker = ns.board, ns.tracker
	local out = { board = board:IsShown(), tracker = tracker.frame:IsShown() }
	if out.board then
		local place = board.router:Place()
		out.place = place
		local row = place.hunt and ns.groups:Row(place.hunt)
		out.group = row and row.group
		local right = board.pages[place.mode .. ":right"]
		if right and right.entry then
			out.name = right.entry.name:IsShown() and right.entry.name:GetText() or nil
		end
		if right and right.view then
			out.seal = right.view.seal:IsShown()
		end
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
---@param run TourRun
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
	it("are the board's groups, a set, its entry, a retired entry, the tracker and each good, in tour order", function()
		local run = start()

		run.fake.slash("dev tour list hunts")

		assert.are.same({
			"Pagle dev: " .. STOPS .. " tour stops:",
			"  hunts.board.home: the Hunts board: the Board, on the Hunt it picks",
			"  hunts.board.now: the Hunts board: a Hunt in Now",
			"  hunts.board.soon: the Hunts board: a Hunt in Soon",
			"  hunts.board.later: the Hunts board: a Hunt in Later",
			"  hunts.board.ondemand: the Hunts board: a Hunt in On demand",
			"  hunts.set.page: the Hunts board: a set's page, its title earned",
			"  hunts.set.entry: the Hunts board: an entry opened from its set's page",
			"  hunts.set.retired: the Hunts board: a Retired Hunt's entry",
			"  hunts.tracker: the Hunts tracker in the dock, with three pins",
			"  hunts.cover.oilcloth: the Hunts board in the Oilcloth cover",
			"  hunts.cover.tooled: the Hunts board in the Tooled Leather cover",
			"  hunts.cover.verdigris: the Hunts board in the Verdigris cover",
			"  hunts.trackerframe.inkwash: the Hunts tracker in the Ink Wash frame",
			"  hunts.trackerframe.waxseal: the Hunts tracker in the Wax Seal frame",
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
			assert.is_string(stop.name, group)
		end
		-- fixture_grouper isn't out until 2026-11-04 (HNT-R2): only the sample groups it.
		assert.is_nil(run.ns.groups:Row("fixture_grouper"))
		assert.is_true(shown[1].grouper)
	end)

	it("show a set's page with its title earned, an entry from it and a retired entry (HNT-R3, HNT-R66)", function()
		local run = start()

		local shown = tour(run)

		assert.are.same({ mode = "set", set = "fixture_dusk" }, shown[6].place)
		assert.is_true(shown[6].seal)
		assert.are.same({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }, shown[7].place)
		assert.is_string(shown[7].name)
		assert.are.same({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" }, shown[8].place)
		assert.is_string(shown[8].name)
	end)

	it("show the tracker in the dock with the sample's three pins, the board closed (HNT-R75, HNT-R76)", function()
		local run = start()

		local shown = tour(run)

		assert.is_false(shown[9].board)
		assert.is_true(shown[9].tracker)
		assert.are.equal(3, shown[9].lines)
		assert.is_nil(shown[9].wearing)
	end)

	it("wear each notebook cover on the board and each tracker frame on the tracker (HNT-R121)", function()
		local run = start()
		local ns = run.ns

		local shown = tour(run)

		for i, id in ipairs({ "oilcloth", "tooled", "verdigris" }) do
			assert.are.equal(ns.COVERS["hunts.notebookcover." .. id], shown[9 + i].cover)
			assert.are.same({ mode = "board", hunt = shown[9 + i].place.hunt }, shown[9 + i].place)
		end
		for i, id in ipairs({ "inkwash", "waxseal" }) do
			assert.are.equal("hunts.trackerframe." .. id, shown[12 + i].wearing)
			assert.are.equal(3, shown[12 + i].lines)
		end
		assert.are.equal(STOPS, #run.fake.tourShots)
	end)

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
			db = copy(run.loaded.env.PagleHuntsDB),
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
