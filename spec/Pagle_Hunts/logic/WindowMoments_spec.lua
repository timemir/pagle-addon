-- Window moments (HNT-R88, HNT-R190, SET-R32): the pure comparison of logic/WindowMoments.lua, from the previous
-- regroup's baseline, the current rows, the pins and the setting to the Nods to raise. The adapter's regroups over
-- FakePagle are in spec/Pagle_Hunts/adapter/WindowMoments_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local ns = hunts.load().ns
local HOUR = hunts.HOUR

-- Sunday 11 October 2026 at realm 08:15 (FakePagle's clock), as a live snapshot (LOG-R45).
local NOW = SERVER_TIME
local SNAPSHOT = hunts.SUNDAY

-- A HuntRow as ns.NewGroups' grouping makes it, with the fields the comparison reads.
local function row(id, window, fields)
	local r = { id = id, group = "later", window = window, auraUp = false, short = false, pinned = false }
	for key, value in pairs(fields or {}) do
		r[key] = value
	end
	return r
end

local OPEN = { openNow = true, closesAt = NOW + HOUR, confirmed = true }
local CLOSED = { opensAt = NOW + HOUR, closesAt = NOW + 2 * HOUR, confirmed = true }

-- A grouping (HuntsGrouping) of `rows` at `time`.
local function grouping(rows, time)
	local byId = {}
	for _, r in ipairs(rows) do
		byId[r.id] = r
	end
	return { time = time or NOW, rows = rows, byId = byId }
end

-- The IDs of the rows WindowOpenings returns.
local function opened(baseline, rows, pins, on)
	local out = {}
	for i, r in ipairs(ns.WindowOpenings(baseline, rows, pins, on)) do
		out[i] = r.id
	end
	return out
end

describe("The baseline (HNT-R88)", function()
	it("records, for every current Hunt, pinned or not, whether its NextWindow result is openNow", function()
		local baseline = ns.WindowBaseline(grouping({
			row("open", OPEN),
			row("closed", CLOSED),
			row("none", nil),
			row("always", { always = true, confirmed = true }),
			row("onDemand", { onDemand = true, confirmed = true }),
		}))
		assert.are.same({ open = true, closed = false, none = false, always = false, onDemand = false }, baseline)
	end)
end)

describe("Which windows opened (HNT-R88)", function()
	local pins = { a = true, b = true }

	it("finds a pinned Hunt openNow now that was recorded as not openNow", function()
		local rows = { row("a", OPEN), row("b", CLOSED) }
		assert.are.same({ "a" }, opened({ a = false, b = false }, rows, pins, true))
	end)

	it("finds none at the first grouping, which has no baseline", function()
		assert.are.same({}, opened(nil, { row("a", OPEN) }, pins, true))
	end)

	it("finds none for a Hunt with no previous record: it just became current", function()
		assert.are.same({}, opened({ b = false }, { row("a", OPEN) }, pins, true))
	end)

	it("finds none for an unpinned Hunt", function()
		assert.are.same({}, opened({ c = false }, { row("c", OPEN) }, pins, true))
	end)

	it("finds none for a Hunt already open at the previous regroup, so pinning an open Hunt raises nothing", function()
		assert.are.same({}, opened({ a = true }, { row("a", OPEN) }, pins, true))
	end)

	it("finds none for a Hunt short of skill (HNT-R33)", function()
		assert.are.same({}, opened({ a = false }, { row("a", OPEN, { short = true }) }, pins, true))
	end)

	it("finds none for an aura starting: an aura-only Hunt's window is never openNow (HNT-R40)", function()
		local up = row("a", { onDemand = true, confirmed = true }, { group = "now", auraUp = true })
		assert.are.same({}, opened({ a = false }, { up }, pins, true))
	end)

	it("finds none with the setting off (SET-R32)", function()
		assert.are.same({}, opened({ a = false }, { row("a", OPEN) }, pins, false))
	end)

	it("keeps the rows' order, the grouping's", function()
		local rows = { row("b", OPEN), row("a", OPEN) }
		assert.are.same({ "b", "a" }, opened({ a = false, b = false }, rows, pins, true))
	end)
end)

describe("The Nod (HNT-R88, ANN-R12)", function()
	it("is a nod of kind huntWindow, titled with the Hunt's name, with its label, icon and closesAt", function()
		local closesAt = NOW + 3 * HOUR - 15 * 60 -- realm 11:00
		local moment = ns.WindowNod({
			name = "Dawn Trout",
			label = "ends in 2h 45m",
			icon = 6358,
			window = { openNow = true, closesAt = closesAt, confirmed = true },
			from = NOW,
			snapshot = SNAPSHOT,
		})
		assert.are.same({
			rung = "nod",
			kind = "huntWindow",
			title = "Dawn Trout is open",
			text = "ends in 2h 45m",
			icon = 6358,
			expiresAt = closesAt,
			pastText = "Dawn Trout window opened 08:15–11:00",
		}, moment)
	end)

	it("has no expiresAt and no '–{to}' when closesAt is unknown, and never a cast or Coins (ANN-R12)", function()
		local moment = ns.WindowNod({
			name = "Fair Trade",
			label = "now",
			icon = "Interface\\Icons\\Trade_Fishing",
			window = { openNow = true, confirmed = true },
			from = NOW + 5 * 60,
			snapshot = SNAPSHOT,
		})
		assert.is_nil(moment.expiresAt)
		assert.are.equal("Fair Trade window opened 08:20", moment.pastText)
		assert.is_nil(moment.cast)
		assert.is_nil(moment.coins)
	end)

	it("reads {from} and {to} on the realm clock, across realm midnight (HNT-R50)", function()
		local from = NOW + (22 * 60 - 8 * 60 - 15) * 60 -- realm 22:00
		local moment = ns.WindowNod({
			name = "Snapper Run",
			label = "ends in 8h",
			icon = 13759,
			window = { openNow = true, closesAt = from + 8 * HOUR, confirmed = true },
			from = from,
			snapshot = SNAPSHOT,
		})
		assert.are.equal("Snapper Run window opened 22:00–06:00", moment.pastText)
	end)
end)
