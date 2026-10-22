-- Which runs are on (HNT-R140, HNT-R150–R155, HNT-R160, HNT-R200, HNT-R204): logic/RunLog.lua's pushed snapshot, the
-- records its step plans, the runs the board shows and the next run edge, over hand-made states, the banded fixture
-- pool (spec/Pagle_Hunts/fixtures/BandedEventList.lua, three events per band) and the fixture catalogue. Its picks,
-- slot by slot from the origin, are vale, firth, reef, brook, cove, tarn, shore, glen, sound (logic/Rotation_spec.lua
-- works them out).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400

describe("which runs are on", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local loaded = hunts.load(fake, { events = hunts.bandedEvents() })
	local ns = loaded.ns
	local ORIGIN = ns.ROTATION_ORIGIN
	local pool = ns.events:Events()

	-- Slot k's bounds (HNT-R152).
	local function S(k)
		return ORIGIN + 3 * DAY * k
	end

	-- A pushed event in Darkshore (hunts.md › Pushed Hunt Events and runs), with a note long enough for two `def`
	-- records.
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

	local lines
	before_each(function()
		lines = {}
		ns.outlets.Diagnostic = function(line)
			lines[#lines + 1] = line
		end
	end)

	local function snapshot(companion, events, runs)
		return ns.ReadPushedSnapshot(companion, events or {}, runs or {}, ns.lookups)
	end

	-- A state with these known runs (`{ event, start, end_, source? }`), each with no progress.
	local function stateWith(runs)
		local state = ns.NewHuntsState()
		for _, run in ipairs(runs or {}) do
			state.runs[ns.RunKey(run[1], run[2])] =
				{ event = run[1], start = run[2], end_ = run[3], source = run[4] or "r", hunts = {} }
		end
		return state
	end

	-- What the step would append, as "<kind> <payload>".
	local function plan(state, now, snap, replayed)
		local out = {}
		for i, record in
			ipairs(ns.PlanRunLog({
				state = state,
				now = now,
				snapshot = snap,
				pool = pool,
				replayed = replayed,
			}))
		do
			out[i] = record.kind .. " " .. record.payload
		end
		return out
	end

	local function run(event, start, end_, source)
		return ("run %s|%d|%d|%s"):format(event, start, end_, source)
	end

	-- The tide's `def` records, as the step writes them (HNT-R154).
	local function tideDefs()
		local out = {}
		for i, payload in ipairs(ns.EncodeDefParts("p_fixture_tide", assert(ns.WriteContentItem(tideItem())))) do
			out[i] = "def " .. payload
		end
		return out
	end

	local function concat(a, b)
		local out = { unpack(a) }
		for _, v in ipairs(b) do
			out[#out + 1] = v
		end
		return out
	end

	describe("the pushed snapshot (HNT-R140, hunts.md › Pushed Hunt Events and runs)", function()
		it("keeps each huntEvent that passes the checks, and each well-formed huntRun, in payload order", function()
			local snap = snapshot(
				"connected",
				{ tideItem() },
				{ runItem("p_fixture_tide", S(0), S(1)), runItem("fixture_shore", S(1), S(2)) }
			)
			assert.are.equal("connected", snap.companion)
			assert.are.equal("Pushed Tide", ns.events:EventName(snap.events.p_fixture_tide.event))
			assert.is_true(#snap.events.p_fixture_tide.parts > 1)
			assert.are.same({
				{ event = "p_fixture_tide", start = S(0), end_ = S(1) },
				{ event = "fixture_shore", start = S(1), end_ = S(2) },
			}, snap.runs)
			assert.are.same({}, lines)
		end)

		it("ignores a huntEvent that fails the checks, or repeats an ID, with a dev line (HNT-R140)", function()
			local short = tideItem()
			short.hunts[3] = nil
			local again = tideItem()
			again.name = "Another Tide"
			local snap = snapshot("connected", { short, tideItem(), again })
			assert.are.equal("Pushed Tide", ns.events:EventName(snap.events.p_fixture_tide.event))
			assert.are.same({
				"Hunts: the pushed definition of p_fixture_tide is ignored: it hasn't 3 to 5 Hunts (HNT-R140)",
				"Hunts: the pushed definition of p_fixture_tide is ignored: its id came earlier in the snapshot"
					.. " (HNT-R140)",
			}, lines)
		end)

		it("ignores a huntRun without an event ID or with times not start < end, with a dev line", function()
			local snap = snapshot("connected", {}, {
				runItem("fixture_shore", S(1), S(1)),
				runItem(nil, S(0), S(1)),
				runItem("fixture_shore", S(0), S(1)),
			})
			assert.are.same({ { event = "fixture_shore", start = S(0), end_ = S(1) } }, snap.runs)
			assert.are.equal(2, #lines)
		end)
	end)

	describe("the records the step plans", function()
		it("logs the fallback slot on now, once, with the slot's bounds and source r (HNT-R151, HNT-R152)", function()
			local missing = snapshot("missing")
			assert.are.same({ run("fixture_vale", S(0), S(1), "r") }, plan(stateWith(), S(0), missing))
			assert.are.same({ run("fixture_firth", S(1), S(2), "r") }, plan(stateWith(), S(1) + 5 * HOUR, missing))
			-- Logged, it is known: nothing more (HNT-R150).
			assert.are.same({}, plan(stateWith({ { "fixture_vale", S(0), S(1) } }), S(0) + HOUR, missing))
			-- The same under notRunning: only "connected" stops the rotation (HNT-R153).
			assert.are.same({ run("fixture_vale", S(0), S(1), "r") }, plan(stateWith(), S(0), snapshot("notRunning")))
		end)

		it("logs nothing before the origin (HNT-R152, HNT-R204)", function()
			assert.are.same({}, plan(stateWith(), ORIGIN - 1, snapshot("missing")))
		end)

		it("starts no fallback run while connected (HNT-R153)", function()
			assert.are.same({}, plan(stateWith(), S(0), snapshot("connected")))
		end)

		it("logs a pushed run on now with its real start, after its definition's parts (HNT-R151, HNT-R154)", function()
			local start = S(0) - DAY
			local snap = snapshot("connected", { tideItem() }, { runItem("p_fixture_tide", start, start + 3 * DAY) })
			local expected = concat(tideDefs(), { run("p_fixture_tide", start, start + 3 * DAY, "p") })
			assert.are.same(expected, plan(stateWith(), S(0) + HOUR, snap))
			-- Of a pool event, no definition; of one whose definition is logged, none again.
			snap = snapshot("connected", {}, { runItem("fixture_shore", start, start + DAY * 2) })
			assert.are.same({ run("fixture_shore", start, start + 2 * DAY, "p") }, plan(stateWith(), S(0), snap))
		end)

		it("never logs a pushed run ahead, or one already ended when seen (HNT-R151, HNT-R200)", function()
			local snap = snapshot("connected", { tideItem() }, {
				runItem("p_fixture_tide", S(0) + DAY, S(0) + 4 * DAY),
				runItem("fixture_shore", S(0) - 3 * DAY, S(0) - HOUR),
			})
			assert.are.same({}, plan(stateWith(), S(0), snap))
		end)

		it("ignores a pushed run of an unknown event, or overlapping a known run of its event (HNT-R142)", function()
			local snap = snapshot("connected", {}, {
				runItem("p_never_defined", S(0) - HOUR, S(1)),
				runItem("fixture_shore", S(0) - HOUR, S(1)),
			})
			assert.are.same({}, plan(stateWith({ { "fixture_shore", S(0) - DAY, S(0) + DAY } }), S(0), snap))
		end)

		it("leaves a slot a logged run of any source overlaps empty (HNT-R153)", function()
			local missing = snapshot("missing")
			-- A pushed run ending an hour into slot 0 covers it; slot 1 is filled at its start (HNT-R201).
			local state = stateWith({ { "p_fixture_tide", S(0) - DAY, S(0) + HOUR, "p" } })
			assert.are.same({}, plan(state, S(0) + 2 * HOUR, missing))
			assert.are.same({ run("fixture_firth", S(1), S(2), "r") }, plan(state, S(1), missing))
			-- A pushed run on now, logged in the same step, covers the slot too.
			local snap = snapshot("notRunning", {}, { runItem("fixture_cove", S(0) - HOUR, S(0) + DAY) })
			assert.are.same({ run("fixture_cove", S(0) - HOUR, S(0) + DAY, "p") }, plan(stateWith(), S(0), snap))
		end)

		it("takes the band's next pick when the slot's own has a run in the slot (HNT-R153)", function()
			-- Slot 0's pick is vale, and a pushed vale run starts a day into it: the slot takes brook.
			local snap = snapshot("notRunning", {}, { runItem("fixture_vale", S(0) + DAY, S(0) + 4 * DAY) })
			assert.are.same({ run("fixture_brook", S(0), S(1), "r") }, plan(stateWith(), S(0), snap))
		end)

		it("logs each uncovered slot of a catch-up's span, in slot order, by the current rule (HNT-R155)", function()
			local missing = snapshot("missing")
			local replayed = { first = S(0) + HOUR, last = S(1) + 2 * DAY }
			assert.are.same({
				run("fixture_vale", S(0), S(1), "r"),
				run("fixture_firth", S(1), S(2), "r"),
				run("fixture_reef", S(2), S(3), "r"),
			}, plan(stateWith(), S(2) + HOUR, missing, replayed))
			-- A slot a logged run covers, or one outside the span, stays empty; the span is clamped to the origin.
			local state = stateWith({ { "fixture_shore", S(1) - HOUR, S(1) + HOUR, "p" } })
			replayed = { first = ORIGIN - 10 * DAY, last = S(1) + HOUR }
			assert.are.same(
				{ run("fixture_cove", S(4), S(5), "r") },
				plan(state, S(4) + HOUR, missing, { first = S(4), last = S(4) })
			)
			assert.are.same({ run("fixture_brook", S(3), S(4), "r") }, plan(state, S(3), missing, replayed))
			-- While connected, a catch-up logs no fallback run either (HNT-R153).
			assert.are.same({}, plan(stateWith(), S(2), snapshot("connected"), replayed))
		end)
	end)

	describe("the runs the board shows (HNT-R160)", function()
		-- Each shown run as "<key> on" or "<key> ahead".
		local function shown(state, now, snap)
			local out = {}
			for i, entry in ipairs(ns.RunsShown(state, now, snap, pool)) do
				out[i] = entry.key .. (entry.on and " on" or " ahead")
				assert.are.equal(entry.run.event, entry.event.id)
			end
			return out
		end

		it("lists the runs on by end, then the runs ahead by start, the next slot's pick among them", function()
			local state = stateWith({
				{ "fixture_vale", S(0), S(1) },
				{ "fixture_shore", S(0) - DAY, S(0) + DAY, "p" },
			})
			local snap = snapshot("notRunning", { tideItem() }, {
				runItem("p_fixture_tide", S(1) + DAY, S(1) + 2 * DAY),
				runItem("fixture_cove", S(0) + DAY, S(0) + 2 * DAY),
			})
			assert.are.same({
				"fixture_shore@" .. S(0) - DAY .. " on",
				"fixture_vale@" .. S(0) .. " on",
				"fixture_cove@" .. S(0) + DAY .. " ahead",
				"fixture_firth@" .. S(1) .. " ahead",
				"p_fixture_tide@" .. S(1) + DAY .. " ahead",
			}, shown(state, S(0) + HOUR, snap))
		end)

		it("hands each run on as its known HuntRun, and each ahead with no progress", function()
			local state = stateWith({ { "fixture_vale", S(0), S(1) } })
			local list = ns.RunsShown(state, S(0), snapshot("missing"), pool)
			assert.are.equal(state.runs["fixture_vale@" .. S(0)], list[1].run)
			assert.are.same(
				{ event = "fixture_firth", start = S(1), end_ = S(2), source = "r", hunts = {} },
				list[2].run
			)
			assert.are.equal(ns.events:Event("fixture_firth"), list[2].event)
		end)

		it("shows no fallback run ahead while connected, nor a slot a pushed run will cover (HNT-R153)", function()
			local state = stateWith({ { "fixture_vale", S(0), S(1) } })
			assert.are.same({ "fixture_vale@" .. S(0) .. " on" }, shown(state, S(0), snapshot("connected")))
			local snap = snapshot("missing", {}, { runItem("fixture_glen", S(1) - HOUR, S(1) + HOUR) })
			assert.are.same({
				"fixture_vale@" .. S(0) .. " on",
				"fixture_glen@" .. S(1) - HOUR .. " ahead",
			}, shown(state, S(0), snap))
			-- A pushed firth run starting a day into slot 1, firth's own slot: it takes mid's next pick, cove
			-- (HNT-R153).
			snap = snapshot("missing", {}, { runItem("fixture_firth", S(1) + DAY, S(1) + 2 * DAY) })
			assert.are.same({
				"fixture_vale@" .. S(0) .. " on",
				"fixture_cove@" .. S(1) .. " ahead",
				"fixture_firth@" .. S(1) + DAY .. " ahead",
			}, shown(state, S(0), snap))
		end)

		it(
			"is empty before the origin with no pushed run, and never lists an ended run (HNT-R143, HNT-R204)",
			function()
				assert.are.same({}, shown(stateWith(), ORIGIN - DAY, snapshot("missing")))
				local snap = snapshot("missing", {}, { runItem("fixture_shore", ORIGIN - 2 * HOUR, ORIGIN - HOUR) })
				assert.are.same({}, shown(stateWith(), ORIGIN - DAY + 3 * HOUR, snapshot("missing")))
				assert.are.same(
					{ "fixture_shore@" .. ORIGIN - 2 * HOUR .. " ahead" },
					shown(stateWith(), ORIGIN - DAY, snap)
				)
				assert.are.same({}, shown(stateWith({ { "fixture_vale", S(0), S(1) } }), S(1), snapshot("connected")))
			end
		)

		it("lists only the runs on before the snapshot is read (the companion checking)", function()
			local state = stateWith({ { "fixture_vale", S(0), S(1) } })
			local runLog = ns.runLog
			ns.runLog = { Snapshot = function() end }
			local list = shown(state, S(0))
			ns.runLog = runLog
			assert.are.same({ "fixture_vale@" .. S(0) .. " on" }, list)
		end)
	end)

	describe("the next run edge (HNT-R42)", function()
		it("is the earliest known or pushed start or end, or slot turn, after now", function()
			local missing = snapshot("missing")
			assert.are.equal(ORIGIN, ns.NextRunEdge(stateWith(), ORIGIN - DAY, missing))
			assert.are.equal(S(1), ns.NextRunEdge(stateWith(), S(0), missing))
			local state = stateWith({ { "fixture_shore", S(0) - DAY, S(0) + DAY, "p" } })
			assert.are.equal(S(0) + DAY, ns.NextRunEdge(state, S(0), missing))
			local snap = snapshot("connected", {}, { runItem("fixture_cove", S(0) + HOUR, S(0) + 2 * HOUR) })
			assert.are.equal(S(0) + HOUR, ns.NextRunEdge(state, S(0), snap))
			assert.are.equal(S(0) + 2 * HOUR, ns.NextRunEdge(state, S(0) + HOUR, snap))
		end)
	end)
end)
