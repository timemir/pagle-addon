-- The rules of grouping (HNT-R40, HNT-R42, HNT-R44, HNT-R81, HNT-R82): pure functions over NextWindow results, the
-- live auras, the Hunt list and the projection's progress, as logic/Groups.lua gives them. The adapter's timers and
-- events over FakePagle are in spec/Pagle_Hunts/adapter/Groups_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local ns = hunts.load().ns
local NOW = SERVER_TIME
local HOUR = hunts.HOUR
local AURA, OTHER_AURA = 1280341, 1265220

describe("Grouping one Hunt (HNT-R40)", function()
	local timed = { time = { { 1200, 360 } } }
	local auraOnly = { auras = { AURA } }
	local timedAura = { time = { { 1200, 360 } }, auras = { AURA, OTHER_AURA } }

	it("puts a Hunt without a board spec in Later, whatever its window (HNT-R7)", function()
		assert.are.same({ "later", false }, { ns.GroupOf(nil, nil, false, {}, NOW) })
	end)

	it("puts a short-of-skill Hunt in Later, even while its window is open (HNT-R33)", function()
		local open = { openNow = true, closesAt = NOW + HOUR, confirmed = true }
		assert.are.same({ "later", false }, { ns.GroupOf(timed, open, true, {}, NOW) })
		assert.are.same({ "later", false }, { ns.GroupOf(auraOnly, { onDemand = true }, true, {}, NOW) })
	end)

	it("still says a short-of-skill Hunt's aura is up, for the window line that ignores skill (HNT-R52)", function()
		local open = { openNow = true, closesAt = NOW + HOUR, confirmed = true }
		assert.are.same({ "later", true }, { ns.GroupOf(auraOnly, { onDemand = true }, true, { AURA }, NOW) })
		assert.are.same({ "later", true }, { ns.GroupOf(timedAura, open, true, { OTHER_AURA }, NOW) })
		-- Up only while the window holds, as for a Hunt not short (HNT-R40).
		local later = { opensAt = NOW + 5 * HOUR, closesAt = NOW + 6 * HOUR, confirmed = true }
		assert.are.same({ "later", false }, { ns.GroupOf(timedAura, later, true, { AURA }, NOW) })
	end)

	it("puts an aura-only Hunt in On demand, and in Now with its aura up while one of its auras is live", function()
		local window = { onDemand = true, confirmed = true }
		assert.are.same({ "onDemand", false }, { ns.GroupOf(auraOnly, window, false, {}, NOW) })
		assert.are.same({ "onDemand", false }, { ns.GroupOf(auraOnly, window, false, { OTHER_AURA }, NOW) })
		assert.are.same({ "now", true }, { ns.GroupOf(auraOnly, window, false, { OTHER_AURA, AURA }, NOW) })
	end)

	it("reads secret auras (none in the snapshot) as none up", function()
		assert.are.same({ "onDemand", false }, { ns.GroupOf(auraOnly, { onDemand = true }, false, nil, NOW) })
	end)

	it("puts an always-open Hunt in Now, aura not up", function()
		assert.are.same({ "now", false }, { ns.GroupOf({}, { always = true, confirmed = true }, false, {}, NOW) })
	end)

	it("puts an open Hunt in Now; with auras too, in Now with its aura up only while one is up", function()
		local open = { openNow = true, closesAt = NOW + HOUR, confirmed = true }
		assert.are.same({ "now", false }, { ns.GroupOf(timed, open, false, {}, NOW) })
		assert.are.same({ "onDemand", false }, { ns.GroupOf(timedAura, open, false, {}, NOW) })
		assert.are.same({ "now", true }, { ns.GroupOf(timedAura, open, false, { OTHER_AURA }, NOW) })
	end)

	it("puts a Hunt opening within the Soon horizon, 3 hours, in Soon, and one after it in Later", function()
		local function opening(at)
			return (ns.GroupOf(timed, { opensAt = at, closesAt = at + HOUR, confirmed = true }, false, {}, NOW))
		end
		assert.are.equal("soon", opening(NOW + 1))
		assert.are.equal("soon", opening(NOW + 2 * HOUR))
		assert.are.equal("soon", opening(NOW + 3 * HOUR))
		assert.are.equal("later", opening(NOW + 3 * HOUR + 1))
		assert.are.equal(3 * HOUR, ns.SOON_HORIZON)
	end)

	it("puts a Hunt with no forecast (a secret clock, or nothing within 400 days) in Later", function()
		assert.are.same({ "later", false }, { ns.GroupOf(timed, nil, false, {}, NOW) })
	end)
end)

-- A row as the grouping keeps it: its group, NextWindow result, pin, skill and place in the Hunt list.
local function row(id, group, order, fields)
	local r = { id = id, group = group, order = order, pinned = false, short = false }
	for key, value in pairs(fields or {}) do
		r[key] = value
	end
	return r
end

local function ids(rows)
	local out = {}
	for i, r in ipairs(rows) do
		out[i] = r.id
	end
	return out
end

describe("Sorting rows (HNT-R44)", function()
	it("puts the groups in board order: Now, Soon, Later, On demand (HNT-R62, HNT-R76)", function()
		local rows = {
			row("d", "onDemand", 1),
			row("l", "later", 2),
			row("s", "soon", 3, { window = { opensAt = NOW + 60 } }),
			row("n", "now", 4),
		}
		assert.are.same({ "n", "s", "l", "d" }, ids(ns.SortRows(rows)))
	end)

	it("puts pinned rows first in their group, then short of skill last among the unpinned", function()
		local rows = {
			row("short", "later", 1, { short = true }),
			row("plain", "later", 2, { window = { opensAt = NOW + 9 * HOUR } }),
			row("pinnedShort", "later", 3, { short = true, pinned = true }),
			row("pinned", "later", 4, { pinned = true, window = { opensAt = NOW + 8 * HOUR } }),
		}
		-- The pinned short-of-skill row has no opensAt (its window is open), so it follows the pinned one that has.
		assert.are.same({ "pinned", "pinnedShort", "plain", "short" }, ids(ns.SortRows(rows)))
	end)

	it("sorts Now by closesAt ascending, those with none last, then by Hunt list order", function()
		local rows = {
			row("always", "now", 1, { window = { always = true } }),
			row("late", "now", 2, { window = { openNow = true, closesAt = NOW + 2 * HOUR } }),
			row("aura", "now", 3, { window = { onDemand = true } }),
			row("early", "now", 4, { window = { openNow = true, closesAt = NOW + HOUR } }),
		}
		assert.are.same({ "early", "late", "always", "aura" }, ids(ns.SortRows(rows)))
	end)

	it("sorts Soon and Later by opensAt ascending, a nil result last, then by Hunt list order", function()
		local rows = {
			row("none", "later", 1),
			row("later2", "later", 2, { window = { opensAt = NOW + 6 * HOUR } }),
			row("later1", "later", 3, { window = { opensAt = NOW + 5 * HOUR } }),
			row("soon2", "soon", 4, { window = { opensAt = NOW + 2 * HOUR } }),
			row("soon1", "soon", 5, { window = { opensAt = NOW + HOUR } }),
			row("tie", "later", 6, { window = { opensAt = NOW + 5 * HOUR } }),
		}
		assert.are.same({ "soon1", "soon2", "later1", "tie", "later2", "none" }, ids(ns.SortRows(rows)))
	end)

	it("leaves an unpinned short-of-skill row last even when its time is earlier", function()
		local rows = {
			row("short", "now", 1, { short = true, window = { openNow = true, closesAt = NOW + 60 } }),
			row("plain", "now", 2, { window = { openNow = true, closesAt = NOW + HOUR } }),
		}
		assert.are.same({ "plain", "short" }, ids(ns.SortRows(rows)))
	end)

	it("sorts On demand by Hunt list order alone", function()
		local rows = { row("b", "onDemand", 2), row("c", "onDemand", 3), row("a", "onDemand", 1) }
		assert.are.same({ "a", "b", "c" }, ids(ns.SortRows(rows)))
	end)
end)

describe("When to regroup next (HNT-R42)", function()
	it("is the earliest opensAt, closesAt or Soon-horizon crossing ahead among the windows", function()
		local windows = {
			{ openNow = true, closesAt = NOW + 5 * HOUR },
			{ opensAt = NOW + 4 * HOUR, closesAt = NOW + 6 * HOUR }, -- enters Soon at NOW + 1 h
			{ onDemand = true },
			{ always = true },
		}
		assert.are.equal(NOW + HOUR, ns.NextEdge(windows, NOW))
		-- From there, the next is the same Hunt's opening, 3 hours on.
		assert.are.equal(NOW + 4 * HOUR, ns.NextEdge(windows, NOW + HOUR))
		assert.are.equal(NOW + 5 * HOUR, ns.NextEdge(windows, NOW + 4 * HOUR))
	end)

	it("skips a Soon crossing already behind: a Hunt in Soon next changes at its opening", function()
		assert.are.equal(NOW + 2 * HOUR, ns.NextEdge({ { opensAt = NOW + 2 * HOUR } }, NOW))
	end)

	it("is nil with nothing ahead: no window, or only always, on demand and nil results", function()
		assert.is_nil(ns.NextEdge({}, NOW))
		assert.is_nil(ns.NextEdge({ { always = true }, { onDemand = true }, { openNow = true } }, NOW))
	end)

	it("for the Hunt list, is the earliest since or retired ahead among every Hunt (HNT-R2, HNT-R3)", function()
		local list = {
			{ id = "out", since = NOW - HOUR },
			{ id = "retiring", since = NOW - HOUR, retired = NOW + 3 * HOUR },
			{ id = "coming", since = NOW + 2 * HOUR },
			{ id = "gone", since = NOW - 9 * HOUR, retired = NOW - HOUR },
		}
		assert.are.equal(NOW + 2 * HOUR, ns.NextListChange(list, NOW))
		assert.are.equal(NOW + 3 * HOUR, ns.NextListChange(list, NOW + 2 * HOUR))
		assert.is_nil(ns.NextListChange(list, NOW + 3 * HOUR))
	end)
end)

describe('The "show completed" filter (HNT-R82)', function()
	local hunt = { id = "h", tiers = { 1, 5 } }
	local fresh = ns.NewHuntProgress()
	local done = { count = 2, effort = 0, sinceLast = 0, caught = true, reached = { {} } }
	local finished = { count = 5, effort = 0, sinceLast = 0, caught = true, reached = { {}, {} } }

	it("with it off, leaves out a finished Hunt unless pinned", function()
		assert.is_false(ns.ShownByFilter(hunt, finished, false, false, false))
		assert.is_true(ns.ShownByFilter(hunt, finished, true, false, false))
	end)

	it("always shows a Hunt with tiers left: done or not, touched or not (HNT-R17)", function()
		assert.is_true(ns.ShownByFilter(hunt, done, false, false, false))
		assert.is_true(ns.ShownByFilter(hunt, fresh, false, false, false))
		assert.is_true(ns.ShownByFilter(hunt, nil, false, false, false))
	end)

	it("with it on, shows a finished Hunt", function()
		assert.is_true(ns.ShownByFilter(hunt, finished, false, true, false))
	end)

	it("hides nothing while the projection is updating (HNT-R69)", function()
		assert.is_true(ns.ShownByFilter(hunt, finished, false, false, true))
	end)
end)

describe("Pins to drop (HNT-R81, HNT-R3)", function()
	local list = ns.hunts -- the fixture list: sunscale retired 2026-06-01, grouper out from 2026-11-04

	it("are those on a Retired Hunt, a Hunt not yet out, or one no longer in the list, in ID order", function()
		local pins = { fixture_snapper = true, fixture_sunscale = true, gone_hunt = true, fixture_grouper = true }
		assert.are.same({ "fixture_grouper", "fixture_sunscale", "gone_hunt" }, ns.StalePins(pins, list, NOW))
	end)

	it("are none while every pinned Hunt is current", function()
		assert.are.same({}, ns.StalePins({ fixture_snapper = true, fixture_rack = true }, list, NOW))
	end)
end)

describe("The groups views read (HNT-R40–R44, HNT-R80, HNT-R82)", function()
	local snapper, oddity, rack =
		ns.hunts:Hunt("fixture_snapper"), ns.hunts:Hunt("fixture_oddity"), ns.hunts:Hunt("fixture_rack")
	-- Both tiers of oddity's and of rack's reached.
	local finished = { count = 10, effort = 0, sinceLast = 0, caught = true, reached = { {}, {} } }

	-- The groups over pins, the filter, a state and the updating flag the spec sets.
	local function model(given)
		given.pins = given.pins or {}
		return ns.NewGroups({
			pins = function()
				return given.pins
			end,
			showCompleted = function()
				return given.showCompleted == true
			end,
			state = function()
				local state = ns.NewHuntsState()
				state.hunts = given.progress or {}
				return state
			end,
			updating = function()
				return given.updating == true
			end,
		})
	end

	-- A grouping as one regroup makes it: rows in Hunt list order.
	local function grouping(rows)
		local byId = {}
		for _, r in ipairs(rows) do
			byId[r.id] = r
		end
		return { time = NOW, rows = rows, byId = byId }
	end
	local function snapperRow()
		return row("fixture_snapper", "later", 1, { hunt = snapper, window = { opensAt = NOW + 9 * HOUR } })
	end
	local function oddityRow()
		return row("fixture_oddity", "later", 2, { hunt = oddity, window = { opensAt = NOW + 8 * HOUR } })
	end
	local function rackRow()
		return row("fixture_rack", "onDemand", 3, { hunt = rack, window = { onDemand = true } })
	end

	it("has no rows and isn't paused before the first grouping", function()
		local groups = model({})
		assert.are.same({}, groups:Rows())
		assert.is_false(groups:IsPaused())
		assert.is_nil(groups:Time())
	end)

	it("hands out every Hunt of the grouping sorted, each marked pinned or not, at the grouping's time", function()
		local given = { pins = { fixture_snapper = true } }
		local groups = model(given)
		groups:Set(grouping({ snapperRow(), oddityRow(), rackRow() }), false)

		local rows = groups:Rows()
		assert.are.same({ "fixture_snapper", "fixture_oddity", "fixture_rack" }, ids(rows))
		assert.are.same({ true, false, false }, { rows[1].pinned, rows[2].pinned, rows[3].pinned })
		assert.are.equal(NOW, groups:Time())

		-- A pin set since moves the row at the next read, with no regroup (HNT-R80).
		given.pins = { fixture_oddity = true }
		assert.are.same({ "fixture_oddity", "fixture_snapper", "fixture_rack" }, ids(groups:Rows()))
		assert.is_true(groups:Row("fixture_oddity").pinned)
		assert.is_nil(groups:Row("fixture_sunscale"))
	end)

	it("hands out copies, so a view changing a row changes no grouping", function()
		local groups = model({})
		groups:Set(grouping({ snapperRow() }), false)
		groups:Rows()[1].group = "now"
		assert.are.equal("later", groups:Rows()[1].group)
	end)

	it("with the filter, leaves out a finished unpinned Hunt while show completed is off (HNT-R82)", function()
		local given = { progress = { fixture_oddity = finished, fixture_rack = finished } }
		local groups = model(given)
		groups:Set(grouping({ snapperRow(), oddityRow(), rackRow() }), false)

		assert.are.same({ "fixture_snapper" }, ids(groups:Rows({ filtered = true })))
		assert.are.equal(3, #groups:Rows()) -- without it, every current Hunt

		given.pins = { fixture_rack = true }
		assert.are.same({ "fixture_snapper", "fixture_rack" }, ids(groups:Rows({ filtered = true })))

		given.showCompleted = true
		assert.are.equal(3, #groups:Rows({ filtered = true }))

		given.showCompleted, given.updating = false, true -- HNT-R69
		assert.are.equal(3, #groups:Rows({ filtered = true }))
	end)

	it("narrows the rows to a set's Hunts, or to pinned Hunts (HNT-R66, HNT-R76)", function()
		local groups = model({ pins = { fixture_rack = true } })
		groups:Set(grouping({ snapperRow(), oddityRow(), rackRow() }), false)

		assert.are.same({ "fixture_oddity", "fixture_rack" }, ids(groups:Rows({ set = "fixture_wagers" })))
		assert.are.same({ "fixture_rack" }, ids(groups:Rows({ pinnedOnly = true })))
	end)

	it("is paused as the grouping was marked (HNT-R43)", function()
		local groups = model({})
		groups:Set(grouping({ snapperRow() }), true)
		assert.is_true(groups:IsPaused())
		groups:SetPaused(false)
		assert.is_false(groups:IsPaused())
	end)
end)
