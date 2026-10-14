-- Grouping at runtime (HNT-R40–R44, HNT-R80–R82, HNT-R193, HNT-R195): Hunts on FakePagle over the fixture Hunt list
-- and catalogue, with the live conditions, the restriction state, and a server time that runs on the client's clock
-- (fake.globals.GetServerTime), so the client's C_Timer and the grouping's "now" move together. The rules' pure parts
-- are in spec/Pagle_Hunts/logic/Groups_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local C = catalogue
local JAN_1 = 1767225600 -- 2026-01-01, the fixture Hunts' since
local RACK_AURA = 1280341 -- fixture_rack's aura, on the catalogue's list
local REALM_START = 8 * 60 + 15 -- FakePagle's realm clock at SERVER_TIME: 08:15 on Sunday 11 October 2026

--- Seconds from FakePagle's start (realm 08:15) to realm `hour`:`minute` the same day.
---@param hour integer
---@param minute integer?
---@return integer
local function untilRealm(hour, minute)
	return (hour * 60 + (minute or 0) - REALM_START) * 60
end

--- The server time at realm `hour`:`minute` that day.
local function realm(hour, minute)
	return SERVER_TIME + untilRealm(hour, minute)
end

--- Hunts the fixture list lacks, made over an imposed Hunt of set fixture_extra (DATA-R93), as one list with the
--- fixture's classes.
---@param huntFields table[]
---@return HuntListData
local function extraList(huntFields)
	local list = { fingerprint = "e", sets = { { id = "fixture_extra" } }, hunts = {}, classes = {} }
	for i, fields in ipairs(huntFields) do
		local hunt = { id = "extra_" .. i, set = "fixture_extra", kind = "imposed", since = JAN_1, tiers = { 1 } }
		for key, value in pairs(fields) do
			hunt[key] = value
		end
		list.hunts[i] = hunt
	end
	return list
end

---@class GroupsRun
---@field loaded LoadedAddon
---@field fake table
---@field ns table
---@field regroups { previous: HuntsGrouping?, current: HuntsGrouping }[]   -- each regroup, in order
---@field redraws string[]   -- each ns.Redraw's reason, in order

--- Hunts on a FakePagle up to its first PLAYER_ENTERING_WORLD: loaded with `options.saved` as PagleHuntsDB and
--- `options.list` (if given) as the Hunt list, logged in, Fishing read at `options.skill` (150 by default; false for
--- none, so every Hunt with a skill need is short), restricted first if `options.restricted`.
---@param options { saved: table?, list: HuntListData?, skill: integer|false|nil, restricted: boolean?, world: boolean? }?
---@return GroupsRun
local function start(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue.base())
	local clock
	fake.globals.GetServerTime = function()
		return SERVER_TIME + math.floor(clock and clock() or 0)
	end
	fake.globals.PagleHuntsDB = options.saved
	local loaded = hunts.load(fake)
	clock = loaded.client.time
	local ns = loaded.ns
	if options.list then
		ns.hunts = ns.NewHuntList(options.list, ns.L)
		ns.where = ns.NewWhere(ns.hunts, fake.globals.Pagle)
	end
	local run = { loaded = loaded, fake = fake, ns = ns, regroups = {}, redraws = {} }
	ns.OnRegroup(function(previous, current)
		run.regroups[#run.regroups + 1] = { previous = previous, current = current }
	end)
	ns.OnRedraw(function(reason)
		run.redraws[#run.redraws + 1] = reason
	end)
	fake.login()
	if options.skill ~= false then
		fake.readSkill(options.skill or 150, 300, 0)
	end
	if options.restricted then
		fake.setRestricted(true)
	end
	fake.enterWorld()
	if options.world ~= false then
		fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
	end
	return run
end

--- Moves the client's clock (and so the server time) on, running each C_Timer that comes due.
---@param run GroupsRun
---@param seconds integer
local function wait(run, seconds)
	run.loaded.client.advance(seconds)
end

--- A Hunt's row as the board reads it now.
---@param run GroupsRun
---@param huntID string
---@return HuntRow?
local function rowOf(run, huntID)
	return run.ns.groups:Row(huntID)
end

--- The group a Hunt is in now.
local function groupOf(run, huntID)
	local row = rowOf(run, huntID)
	return row and row.group
end

--- The server time of each regroup since `from` (an index into run.regroups), in order.
local function regroupTimes(run, from)
	local times = {}
	for i = from + 1, #run.regroups do
		times[#times + 1] = run.regroups[i].current.time
	end
	return times
end

local function ids(rows)
	local out = {}
	for i, r in ipairs(rows) do
		out[i] = r.id
	end
	return out
end

describe("The first grouping (HNT-R42)", function()
	it("runs at the first PLAYER_ENTERING_WORLD, not before, and asks for a redraw", function()
		local run = start({ world = false })
		assert.are.same({}, run.ns.groups:Rows())
		assert.are.same({}, run.regroups) -- SkillChanged and ConditionsChanged came before it

		run.fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)

		assert.are.equal(1, #run.regroups)
		assert.is_nil(run.regroups[1].previous)
		assert.are.equal(SERVER_TIME, run.regroups[1].current.time)
		assert.are.same({ "groups" }, run.redraws)
		assert.is_false(run.ns.groups:IsPaused())
	end)

	it("holds every current Hunt, and no Retired Hunt or Hunt not yet out (HNT-R2, HNT-R3)", function()
		local run = start()
		assert.are.same(
			{ "fixture_snapper", "fixture_oddity", "fixture_rack", "fixture_hefty_blackmouth" },
			ids(run.regroups[1].current.rows)
		)
		assert.is_nil(rowOf(run, "fixture_sunscale"))
		assert.is_nil(rowOf(run, "fixture_grouper"))
	end)

	it("runs once: a later PLAYER_ENTERING_WORLD (a loading screen) doesn't regroup", function()
		local run = start()
		run.fake.fireGameEvent("PLAYER_ENTERING_WORLD", false, false)
		assert.are.equal(1, #run.regroups)
	end)
end)

describe("Groups at realm times (HNT-R40, HNT-R41)", function()
	it("has a night Hunt Later at 14:00, Soon 2 hours before its window and Now at 23:00", function()
		local run = start()
		wait(run, untilRealm(14))
		assert.are.equal("later", groupOf(run, "fixture_snapper"))
		wait(run, untilRealm(18) - untilRealm(14))
		assert.are.equal("soon", groupOf(run, "fixture_snapper"))
		wait(run, untilRealm(23) - untilRealm(18))
		assert.are.equal("now", groupOf(run, "fixture_snapper"))
		assert.are.equal(realm(23), run.fake.globals.GetServerTime())
		-- Its forecast is from the grouping's time: open now, closing at realm 06:00 the next day (HNT-R195).
		assert.are.equal(realm(30), rowOf(run, "fixture_snapper").window.closesAt)
	end)

	it("has a short-of-skill Hunt in Later while its window is open (HNT-R33)", function()
		local run = start({ skill = false })
		wait(run, untilRealm(23))
		assert.are.equal("later", groupOf(run, "fixture_snapper"))
		assert.is_true(rowOf(run, "fixture_snapper").short)
		assert.is_true(rowOf(run, "fixture_snapper").lureGetsThere) -- 75 needed, 0 known: within the lure's 100
	end)

	it("has a Hunt without a board spec in Later (HNT-R7)", function()
		local list = extraList({ { kind = "natural", species = C.NIGHTFIN, window = "nowhere" } })
		local run = start({ list = list })
		assert.are.equal("later", groupOf(run, "extra_1"))
		assert.is_nil(rowOf(run, "extra_1").window)
	end)

	it("has an aura-only Hunt On demand, and Now with its aura up while the aura is live", function()
		local run = start()
		assert.are.same({ "onDemand", false }, { groupOf(run, "fixture_rack"), rowOf(run, "fixture_rack").auraUp })

		local conditions = {}
		for key, value in pairs(run.fake.conditions) do
			conditions[key] = value
		end
		conditions.auras = { RACK_AURA }
		run.fake.setConditions(conditions) -- ConditionsChanged({ "auras" })

		assert.are.same({ "now", true }, { groupOf(run, "fixture_rack"), rowOf(run, "fixture_rack").auraUp })
	end)

	it("has an always-open Hunt in Now", function()
		local run = start({ list = extraList({ { class = "fixed.oddity", conditions = { areas = { C.ELWYNN } } } }) })
		assert.are.equal("now", groupOf(run, "extra_1"))
		assert.is_true(rowOf(run, "extra_1").window.always)
	end)

	it("reads an event open now from the live calendar, through NextWindow (HNT-R41)", function()
		local list = extraList({ { class = "fixed.oddity", conditions = { events = { 301 } } } })
		local run = start({ list = list })
		-- Sunday 08:15: the Extravaganza's weekly rule opens it at 14:00, beyond the Soon horizon.
		assert.are.equal("later", groupOf(run, "extra_1"))

		local conditions = {}
		for key, value in pairs(run.fake.conditions) do
			conditions[key] = value
		end
		conditions.events = { 301 }
		run.fake.setConditions(conditions) -- the calendar says it's on now: ConditionsChanged({ "events" })

		assert.are.equal("now", groupOf(run, "extra_1"))
	end)
end)

describe("Rows (HNT-R44)", function()
	it("sort pinned first, short of skill last among the unpinned, then by time, then list order", function()
		-- At 19:30 with skill 150: oddity is open until 21:00 (Now), snapper opens at 20:00 and hefty at 22:00
		-- (Soon), and rack waits for its aura (On demand).
		local run = start()
		wait(run, untilRealm(19, 30))
		assert.are.same(
			{ "fixture_oddity", "fixture_snapper", "fixture_hefty_blackmouth", "fixture_rack" },
			ids(run.ns.groups:Rows())
		)

		assert.is_true(run.ns.SetPinned("fixture_hefty_blackmouth", true))
		assert.are.same(
			{ "fixture_oddity", "fixture_hefty_blackmouth", "fixture_snapper", "fixture_rack" },
			ids(run.ns.groups:Rows())
		)
	end)

	it("put a short-of-skill Hunt last among the unpinned of its group, and a pinned one first", function()
		local list = extraList({
			{ class = "fixed.oddity", conditions = { time = { { 1320, 240 } }, skill = { min = 300 } } },
			{ class = "fixed.oddity", conditions = { time = { { 1260, 240 } } } },
			{ class = "fixed.oddity", conditions = { time = { { 1200, 240 } } } },
		})
		local run = start({ list = list })
		-- All three open later tonight: extra_1 is short, so last though it isn't the latest.
		assert.are.same({ "extra_3", "extra_2", "extra_1" }, ids(run.ns.groups:Rows()))

		run.ns.SetPinned("extra_1", true)
		run.ns.SetPinned("extra_2", true)
		assert.are.same({ "extra_2", "extra_1", "extra_3" }, ids(run.ns.groups:Rows()))
	end)
end)

describe("Regrouping (HNT-R42)", function()
	it("runs at each window edge among current Hunts: openings, closings and Soon crossings", function()
		local run = start()
		wait(run, untilRealm(18))
		-- oddity enters Soon at 15:00, snapper at 17:00, oddity opens at 18:00.
		assert.are.same({ realm(15), realm(17), realm(18) }, regroupTimes(run, 1))
		wait(run, untilRealm(22) - untilRealm(18))
		-- hefty enters Soon at 19:00, snapper opens at 20:00, oddity closes at 21:00, hefty opens at 22:00.
		assert.are.same({ realm(19), realm(20), realm(21), realm(22) }, regroupTimes(run, 4))
	end)

	it("runs on ConditionsChanged and on SkillChanged, and asks for a redraw each time", function()
		local run = start()
		local conditions = {}
		for key, value in pairs(run.fake.conditions) do
			conditions[key] = value
		end
		conditions.subzone = 442
		run.fake.setConditions(conditions) -- ConditionsChanged({ "area" })
		assert.are.equal(2, #run.regroups)

		run.fake.fire("SkillChanged", {})
		assert.are.equal(3, #run.regroups)
		assert.are.same({ "groups", "groups", "groups" }, run.redraws)
		assert.are.equal(run.regroups[2].current, run.regroups[3].previous)
	end)

	it("puts a Hunt short of skill in its group once the Angler's skill gets there", function()
		local run = start({ skill = false })
		wait(run, untilRealm(23))
		assert.are.equal("later", groupOf(run, "fixture_snapper"))

		run.fake.readSkill(75, 150, 0) -- SkillChanged, then ConditionsChanged({ "skill" })

		assert.are.equal("now", groupOf(run, "fixture_snapper"))
	end)

	it("runs every 60 s only while the board or the tracker is shown", function()
		local run = start()
		wait(run, 300)
		assert.are.equal(1, #run.regroups)

		run.ns.SetViewShown("board", true)
		wait(run, 60)
		assert.are.same({ SERVER_TIME + 360 }, regroupTimes(run, 1))
		run.ns.SetViewShown("tracker", true)
		run.ns.SetViewShown("board", false)
		wait(run, 120)
		assert.are.same({ SERVER_TIME + 360, SERVER_TIME + 420, SERVER_TIME + 480 }, regroupTimes(run, 1))

		run.ns.SetViewShown("tracker", false)
		wait(run, 600)
		assert.are.equal(4, #run.regroups)
	end)

	it("runs when a Hunt's since or retired passes, adding or dropping it", function()
		local list = extraList({
			{ class = "fixed.oddity", since = SERVER_TIME + 1800 },
			{ class = "fixed.oddity", retired = SERVER_TIME + 3600 },
		})
		local run = start({ list = list })
		assert.are.same({ "extra_2" }, ids(run.ns.groups:Rows()))

		wait(run, 1800)
		assert.are.same({ SERVER_TIME + 1800 }, regroupTimes(run, 1))
		assert.are.same({ "extra_1", "extra_2" }, ids(run.ns.groups:Rows()))

		wait(run, 1800)
		assert.are.same({ "extra_1" }, ids(run.ns.groups:Rows()))
	end)

	it("sets one timer per edge: a regroup between edges leaves no stray regroup behind", function()
		local run = start()
		for _ = 1, 3 do
			run.fake.fire("SkillChanged", {}) -- each regroup cancels and re-sets the timers
		end
		wait(run, untilRealm(15))
		assert.are.same({ SERVER_TIME, SERVER_TIME, SERVER_TIME, realm(15) }, regroupTimes(run, 1))
	end)
end)

describe("In combat (HNT-R43, HNT-R193)", function()
	it("keeps the grouping while restricted, marked paused, and regroups at RestrictionChanged(false)", function()
		local run = start()
		run.fake.setRestricted(true)
		assert.is_true(run.ns.groups:IsPaused())
		assert.are.same({ "groups", "groups" }, run.redraws) -- the clock reads "(paused in combat)" at once

		run.fake.fire("SkillChanged", {})
		run.ns.SetViewShown("board", true)
		wait(run, untilRealm(18)) -- three window edges and many refreshes pass
		assert.are.equal(1, #run.regroups)
		assert.are.equal("later", groupOf(run, "fixture_snapper"))

		run.fake.setRestricted(false)
		assert.are.same({ realm(18) }, regroupTimes(run, 1))
		assert.is_false(run.ns.groups:IsPaused())
		assert.are.equal("soon", groupOf(run, "fixture_snapper"))
		-- The timers are set again from there: the next edge, snapper's opening at 20:00, regroups.
		run.ns.SetViewShown("board", false)
		wait(run, untilRealm(20) - untilRealm(18))
		assert.are.same({ realm(18), realm(19), realm(20) }, regroupTimes(run, 1))
	end)

	it("runs a first grouping that falls while restricted, marked paused, and redoes it after", function()
		local run = start({ restricted = true })
		assert.are.equal(1, #run.regroups)
		assert.is_true(run.ns.groups:IsPaused())
		assert.are.equal(4, #run.ns.groups:Rows())

		wait(run, 120)
		run.fake.setRestricted(false)

		assert.are.same({ SERVER_TIME, SERVER_TIME + 120 }, regroupTimes(run, 0))
		assert.is_false(run.ns.groups:IsPaused())
	end)

	it("still asks for redraws for other reasons while restricted", function()
		local run = start()
		run.fake.setRestricted(true)
		run.ns.Redraw("projection")
		assert.are.same({ "groups", "groups", "projection" }, run.redraws)
	end)
end)

describe("Pins (HNT-R80, HNT-R81)", function()
	local saved = {
		profileKeys = { ["Angler - Testrealm"] = "Default" },
		profiles = {
			Default = {
				pins = { fixture_snapper = true, fixture_sunscale = true, gone_hunt = true, fixture_grouper = true },
			},
		},
	}

	it("drops pins on a Retired Hunt, a Hunt not yet out or one no longer in the list at load", function()
		local run = start({ saved = saved, world = false })
		assert.are.same({ fixture_snapper = true }, run.ns.db.profile.pins)
	end)

	it("pins any current Hunt with no limit, saved in the profile, and asks for a redraw", function()
		local run = start()
		for _, id in ipairs({ "fixture_snapper", "fixture_oddity", "fixture_rack", "fixture_hefty_blackmouth" }) do
			assert.is_true(run.ns.SetPinned(id, true))
		end
		assert.are.same({
			fixture_snapper = true,
			fixture_oddity = true,
			fixture_rack = true,
			fixture_hefty_blackmouth = true,
		}, run.ns.db.profile.pins)
		assert.is_true(run.ns.IsPinned("fixture_rack"))
		assert.are.equal(5, #run.redraws)

		assert.is_true(run.ns.SetPinned("fixture_rack", false))
		assert.is_false(run.ns.IsPinned("fixture_rack"))
		assert.is_nil(run.ns.db.profile.pins.fixture_rack)
	end)

	it("refuses to pin a Hunt not yet out, a Retired Hunt or an unknown one", function()
		local run = start()
		assert.is_false(run.ns.SetPinned("fixture_grouper", true))
		assert.is_false(run.ns.SetPinned("fixture_sunscale", true))
		assert.is_false(run.ns.SetPinned("gone_hunt", true))
		assert.are.same({}, run.ns.db.profile.pins)
		assert.are.equal(1, #run.redraws)
	end)

	it("drops a pin at the regroup that finds its Hunt retired (HNT-R3, HNT-R197)", function()
		local run = start({ list = extraList({ { class = "fixed.oddity", retired = SERVER_TIME + 3600 } }) })
		run.ns.SetPinned("extra_1", true)
		wait(run, 3600)
		assert.are.same({}, run.ns.db.profile.pins)
		assert.are.same({}, run.ns.groups:Rows())
	end)
end)

describe('The "show completed" filter (HNT-R82)', function()
	-- Every tier of snapper (3) and of oddity (2) reached.
	local function finished(tiers)
		local reached = {}
		for k = 1, tiers do
			reached[k] = {}
		end
		return { count = 40, effort = 0, sinceLast = 0, caught = true, reached = reached }
	end

	it("is off by default and saved; with it off the board leaves out finished, unpinned Hunts", function()
		local run = start()
		run.ns.State = function()
			return {
				casts = 0,
				coins = 0,
				hunts = { fixture_snapper = finished(3), fixture_oddity = finished(2) },
				sets = {},
			}
		end
		assert.is_false(run.ns.db.profile.showCompleted)
		assert.are.same({ "fixture_hefty_blackmouth", "fixture_rack" }, ids(run.ns.groups:Rows({ filtered = true })))
		assert.are.equal(4, #run.ns.groups:Rows()) -- unfiltered, every current Hunt

		run.ns.SetPinned("fixture_oddity", true)
		assert.are.equal(3, #run.ns.groups:Rows({ filtered = true }))

		run.ns.SetShowCompleted(true)
		assert.is_true(run.ns.db.profile.showCompleted)
		assert.are.equal(4, #run.ns.groups:Rows({ filtered = true }))
		assert.are.equal("groups", run.redraws[#run.redraws])
	end)

	it("hides nothing while the projection is updating (HNT-R69)", function()
		local run = start()
		run.ns.State = function()
			return { casts = 0, coins = 0, hunts = { fixture_snapper = finished(3) }, sets = {} }
		end
		run.ns.IsUpdating = function()
			return true
		end
		assert.are.equal(4, #run.ns.groups:Rows({ filtered = true }))
	end)
end)
