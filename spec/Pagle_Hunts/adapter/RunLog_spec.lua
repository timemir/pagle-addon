-- The run log on FakePagle (HNT-R42, HNT-R43, HNT-R150–R155, HNT-R160, HNT-R200–R202; LOG-R40, PUSH-R15, PUSH-R16):
-- which runs Hunts logs, and when, over the banded fixture pool (spec/Pagle_Hunts/fixtures/BandedEventList.lua, three
-- events per band), the fixture catalogue, a fixed clock that moves only when a spec moves it, and the companion's
-- pushed content as fake.setPushedContent hands it in. The rotation's origin is moved into the past for each login;
-- its picks, slot by slot, are vale, firth, reef, brook, cove, tarn, shore, glen, sound (logic/Rotation_spec.lua).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local SLOT = 3 * DAY

-- The origin a spec logs in under: slot 0 starts `ago` seconds before SERVER_TIME.
local function originAgo(ago)
	return SERVER_TIME - ago
end

-- Hunts' own records in the Catch log, in order, as "<kind> <payload>".
local function huntsRecords(fake)
	local out = {}
	for entry in fake.catchLog:Iterate(0, "Hunts") do
		if entry.kind == "module" then
			out[#out + 1] = entry.recordKind .. " " .. entry.payload
		end
	end
	return out
end

local function run(event, start, end_, source)
	return ("run %s|%d|%d|%s"):format(event, start, end_, source)
end

-- A pushed event in Darkshore (hunts.md › Pushed Hunt Events and runs), its note long enough for two `def` records.
local function tideItem()
	return {
		kind = "huntEvent",
		v = 1,
		id = "p_fixture_tide",
		zones = { C.DARKSHORE },
		tags = { "coast" },
		skill = { 75, 150 },
		rotation = false,
		name = "Pushed Tide",
		note = string.rep("A long night on the shore. ", 8),
		hunts = {
			{ id = "p_fixture_tide_haul", name = "Tide Haul", class = "species.any", tiers = { 1 } },
			{ id = "p_fixture_tide_snapper", species = C.NIGHTFIN, tiers = { 1 } },
			{ id = "p_fixture_tide_blackmouth", species = C.BLACKMOUTH, tiers = { 1 } },
		},
	}
end

local function runItem(event, start, end_)
	return { kind = "huntRun", v = 1, event = event, start = start, ["end"] = end_ }
end

-- Hunts logged in on FakePagle with the banded pool and the origin at `origin`, through the first grouping, with
-- `pushed` (fake.setPushedContent's argument) if given; then the frame where the pushed-content check ends and the
-- frame after (the step's), unless `frames` is false. Other options go to support.start.
---@return HuntsRun
local function start(origin, pushed, options)
	options = options or {}
	local prepare = options.prepare
	options.events = options.events or hunts.bandedEvents()
	options.prepare = function(loaded)
		loaded.ns.ROTATION_ORIGIN = origin
		if prepare then
			prepare(loaded)
		end
	end
	local beforeLogin = options.beforeLogin
	options.beforeLogin = function(r)
		if pushed then
			r.fake.setPushedContent(pushed)
		end
		if beforeLogin then
			beforeLogin(r)
		end
	end
	local frames = options.frames
	options.frames = nil
	local r = hunts.start(options)
	if frames ~= false then
		r.fake.nextFrame()
		r.loaded.client.runTimers()
	end
	return r
end

-- The next login over the same Catch log and PagleHuntsDB.
local function nextLogin(r, origin, pushed, options)
	options = options or {}
	options.fake = hunts.nextLogin(r.fake, r.loaded)
	options.saved = options.fake.globals.PagleHuntsDB
	return start(origin, pushed, options)
end

-- The runs the board shows now, as "<key> on" or "<key> ahead" (HNT-R160).
local function shown(r)
	local out = {}
	for i, entry in ipairs(r.ns.RunsShown(r.ns.State(), r.fake.globals.GetServerTime())) do
		out[i] = entry.key .. (entry.on and " on" or " ahead")
	end
	return out
end

describe("the run log", function()
	describe("without the companion (HNT-R151–R153)", function()
		local O = originAgo(HOUR)

		it("logs the fallback slot on now once, with source r, and nothing at the next regroup", function()
			local r = start(O)
			assert.are.equal("missing", r.fake.globals.Pagle.GetCompanionState())
			assert.are.same({ run("fixture_vale", O, O + SLOT, "r") }, huntsRecords(r.fake))
			-- Known now (HNT-R150): the next regroup appends nothing.
			r.fake.fire("SkillChanged", {})
			r.loaded.client.runTimers()
			assert.are.same({ run("fixture_vale", O, O + SLOT, "r") }, huntsRecords(r.fake))
			assert.are.same({ "fixture_vale@" .. O .. " on", "fixture_firth@" .. O + SLOT .. " ahead" }, shown(r))
		end)

		-- Logged in a minute before slot 1 starts.
		local LATE = originAgo(SLOT - 60)

		it("logs the next slot at its start, by the regroup timer (HNT-R42)", function()
			local r = start(LATE)
			hunts.wait(r, 59)
			r.loaded.client.runTimers()
			assert.are.equal(1, #huntsRecords(r.fake))
			hunts.wait(r, 1)
			r.loaded.client.runTimers()
			assert.are.same({
				run("fixture_vale", LATE, LATE + SLOT, "r"),
				run("fixture_firth", LATE + SLOT, LATE + 2 * SLOT, "r"),
			}, huntsRecords(r.fake))
			-- The ended run leaves every list; the next slot's pick is ahead (HNT-R143, HNT-R160).
			assert.are.same(
				{ "fixture_firth@" .. LATE + SLOT .. " on", "fixture_reef@" .. LATE + 2 * SLOT .. " ahead" },
				shown(r)
			)
		end)

		it("waits out a restriction: the slot is logged at RestrictionChanged(false) (HNT-R43)", function()
			local r = start(LATE)
			r.fake.setRestricted(true)
			hunts.wait(r, 60)
			r.loaded.client.runTimers()
			assert.are.equal(1, #huntsRecords(r.fake))
			r.fake.setRestricted(false)
			r.loaded.client.runTimers()
			assert.are.equal(run("fixture_firth", LATE + SLOT, LATE + 2 * SLOT, "r"), huntsRecords(r.fake)[2])
		end)

		it("logs nothing before the origin, and the board shows nothing (HNT-R152, HNT-R204)", function()
			local soon = SERVER_TIME + 60
			local r = start(soon)
			assert.are.same({}, huntsRecords(r.fake))
			assert.are.same({}, shown(r))
			-- The origin passing is a slot turn: slot 0 is logged then.
			hunts.wait(r, 60)
			r.loaded.client.runTimers()
			assert.are.same({ run("fixture_vale", soon, soon + SLOT, "r") }, huntsRecords(r.fake))
		end)

		it("logs nothing while the projection is still catching up", function()
			local r = start(O, nil, { caughtUp = false })
			assert.are.same({}, huntsRecords(r.fake))
		end)
	end)

	describe("with the companion connected (HNT-R151, HNT-R153, HNT-R154, HNT-R160)", function()
		local O = originAgo(HOUR)
		local onStart = SERVER_TIME - DAY
		local aheadStart = SERVER_TIME + 60

		local function pushed()
			return {
				state = "connected",
				items = {
					tideItem(),
					runItem("p_fixture_tide", onStart, onStart + SLOT),
					runItem("fixture_cove", aheadStart, aheadStart + SLOT),
				},
			}
		end

		it("logs the pushed definition's parts, then its run with its real start; no fallback run starts", function()
			local r = start(O, pushed())
			local records = huntsRecords(r.fake)
			local parts = r.ns.EncodeDefParts("p_fixture_tide", assert(r.ns.WriteContentItem(tideItem())))
			assert.is_true(#parts > 1)
			local expected = {}
			for i, payload in ipairs(parts) do
				expected[i] = "def " .. payload
			end
			expected[#expected + 1] = run("p_fixture_tide", onStart, onStart + SLOT, "p")
			assert.are.same(expected, records)
			assert.are.equal("p", r.ns.State().runs["p_fixture_tide@" .. onStart].source)
		end)

		it("lists the pushed run ahead without logging it, until it starts (HNT-R151, HNT-R160)", function()
			local r = start(O, pushed())
			assert.are.same(
				{ "p_fixture_tide@" .. onStart .. " on", "fixture_cove@" .. aheadStart .. " ahead" },
				shown(r)
			)
			local count = #huntsRecords(r.fake)
			hunts.wait(r, 59)
			r.loaded.client.runTimers()
			assert.are.equal(count, #huntsRecords(r.fake))
			hunts.wait(r, 1)
			r.loaded.client.runTimers()
			local records = huntsRecords(r.fake)
			assert.are.equal(count + 1, #records)
			assert.are.equal(run("fixture_cove", aheadStart, aheadStart + SLOT, "p"), records[#records])
		end)

		it("drops a run ahead withdrawn from the next snapshot (HNT-R151)", function()
			local r = start(O, pushed())
			local count = #huntsRecords(r.fake)
			local again = nextLogin(r, O, { state = "connected", items = { tideItem() } })
			assert.are.same({ "p_fixture_tide@" .. onStart .. " on" }, shown(again))
			-- The logged run plays out; nothing new is logged (HNT-R153).
			assert.are.equal(count, #huntsRecords(again.fake))
		end)

		it("logs nothing until PushedContentReady, and nothing of the rotation then (PUSH-R16)", function()
			local r = start(O, pushed(), { frames = false })
			r.loaded.client.runTimers()
			assert.are.same({}, huntsRecords(r.fake))
			assert.are.equal("checking", r.fake.globals.Pagle.GetCompanionState())
			r.fake.nextFrame()
			r.loaded.client.runTimers()
			local records = huntsRecords(r.fake)
			assert.are.equal(run("p_fixture_tide", onStart, onStart + SLOT, "p"), records[#records])
		end)
	end)

	describe("between the two (HNT-R153, HNT-R200, HNT-R201)", function()
		it(
			"leaves a slot a logged pushed run overlaps empty, and fills the next once the companion is quiet",
			function()
				local O = originAgo(HOUR)
				-- Logged connected: a pushed shore run from a day before slot 0 to a day into it.
				local r = start(O, {
					state = "connected",
					items = { runItem("fixture_shore", O - DAY, O + DAY) },
				})
				assert.are.same({ run("fixture_shore", O - DAY, O + DAY, "p") }, huntsRecords(r.fake))
				-- Next login, the companion missing, a minute before slot 1: slot 0 is covered, and stayed empty after
				-- the run ended.
				local quiet = nextLogin(r, O, nil, { from = SLOT - HOUR - 60 })
				assert.are.same({ run("fixture_shore", O - DAY, O + DAY, "p") }, huntsRecords(quiet.fake))
				assert.are.same({ "fixture_firth@" .. O + SLOT .. " ahead" }, shown(quiet))
				-- Slot 1 is filled at its start (HNT-R201).
				hunts.wait(quiet, 60)
				quiet.loaded.client.runTimers()
				assert.are.equal(run("fixture_firth", O + SLOT, O + 2 * SLOT, "r"), huntsRecords(quiet.fake)[2])
			end
		)

		it("takes the band's next pick when a pushed run of the slot's own is in the slot (notRunning)", function()
			local O = originAgo(HOUR)
			local r = start(O, {
				state = "notRunning",
				items = { runItem("fixture_vale", O + DAY, O + 2 * DAY) },
			})
			assert.are.same({ run("fixture_brook", O, O + SLOT, "r") }, huntsRecords(r.fake))
		end)

		it("ignores a pushed run already ended when first seen (HNT-R200)", function()
			local O = originAgo(HOUR)
			local r = start(O, {
				state = "connected",
				items = { runItem("fixture_shore", O - 3 * DAY, O - DAY) },
			})
			assert.are.same({}, huntsRecords(r.fake))
			assert.are.same({}, shown(r))
		end)
	end)

	describe("a catch-up (HNT-R155, HNT-R149)", function()
		it(
			"logs both past slots from the step after done, and credits their Casts; nothing during the replay",
			function()
				-- First login before the rotation: nothing logged, the projection built.
				local first = start(SERVER_TIME + 100 * DAY)
				assert.are.same({}, huntsRecords(first.fake))
				-- Hunts off for a week: a Cast in each of slots 0 and 1, in vale's and firth's waters.
				local O = originAgo(7 * DAY)
				local fake = hunts.nextLogin(first.fake, first.loaded)
				local casts = hunts.append(fake, {
					(function()
						local c = hunts.cast(0, hunts.NIGHT, { zone = C.ELWYNN }, { C.NIGHTFIN })
						c.time = O + HOUR
						return c
					end)(),
					(function()
						local c = hunts.cast(0, hunts.NIGHT, { zone = C.WESTFALL }, { C.NIGHTFIN })
						c.time = O + SLOT + HOUR
						return c
					end)(),
				})
				local atDone
				local r = start(O, nil, {
					fake = fake,
					saved = fake.globals.PagleHuntsDB,
					prepare = function(loaded)
						local done = loaded.ns.outlets.Done
						loaded.ns.outlets.Done = function(state, info)
							atDone = { replayed = info.replayed, records = #huntsRecords(fake) }
							done(state, info)
						end
					end,
				})
				assert.are.same({ replayed = 2, records = 0 }, atDone)
				assert.are.same({
					run("fixture_vale", O, O + SLOT, "r"),
					run("fixture_firth", O + SLOT, O + 2 * SLOT, "r"),
					run("fixture_reef", O + 2 * SLOT, O + 3 * SLOT, "r"),
				}, huntsRecords(r.fake))
				local state = r.ns.State()
				assert.are.equal(1, state.runs["fixture_vale@" .. O].hunts.fixture_vale_haul.count)
				assert.are.equal(1, state.runs["fixture_firth@" .. O + SLOT].hunts.fixture_firth_haul.count)
				assert.are.equal(
					casts[1].time,
					state.runs["fixture_vale@" .. O].hunts.fixture_vale_haul.reached[1].time
				)
			end
		)
	end)

	describe("a pool change in an update (HNT-R202)", function()
		it("keeps a logged run on, and picks from the new pool from now on", function()
			local O = originAgo(HOUR)
			local r = start(O)
			assert.are.same({ run("fixture_vale", O, O + SLOT, "r") }, huntsRecords(r.fake))
			-- The next release retires firth from slot 1's start: slot 1 picks from cove and glen.
			local events = hunts.bandedEvents()
			events.fingerprint = "b2b2b2b2b2b2b2b2"
			for _, event in ipairs(events.events) do
				if event.id == "fixture_firth" then
					event.retired = O + SLOT
				end
			end
			local again = nextLogin(r, O, nil, { events = events })
			local next = again.ns.RotationPick(again.ns.events:Events(), 1)
			assert.are_not.equal("fixture_firth", next.id)
			assert.are.same({ "fixture_vale@" .. O .. " on", next.id .. "@" .. O + SLOT .. " ahead" }, shown(again))
			assert.are.equal(1, #huntsRecords(again.fake))
		end)
	end)
end)
