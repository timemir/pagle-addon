-- The live conditions service's logic: which calendar events are active (LOG-R46) and which ConditionsChanged keys
-- a new reading changed (LOG-R47). Pure logic/, called with what the adapter read.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- The catalogue's event list in these specs: the Stranglethorn Fishing Extravaganza (301) and Hallow's End (324).
local LISTED = { 301, 324 }

-- A realm minute of day from a realm hour and minute.
local function at(hour, minute)
	return hour * 60 + minute
end

-- A CalendarTime on October 2026, as C_Calendar hands one out.
local function time(monthDay, hour, minute)
	return { year = 2026, month = 10, monthDay = monthDay, hour = hour, minute = minute }
end

-- A CalendarDayEvent with the fields the activity rule reads. sequenceType is "START", "ONGOING" or "END" on the
-- first, a middle and the last day of a multi-day event, and "" for a single-day one.
local function dayEvent(eventID, sequenceType, startTime, endTime)
	return { eventID = eventID, sequenceType = sequenceType, startTime = startTime, endTime = endTime }
end

-- The Extravaganza on Sunday 11 October: a single-day event, 14:00 to 16:00 realm time.
local EXTRAVAGANZA = dayEvent(301, "", time(11, 14, 0), time(11, 16, 0))

-- Hallow's End, 18 October 10:00 to 31 October 11:00: a multi-day event, as each of its days lists it.
local function hallowsEnd(sequenceType)
	return dayEvent(324, sequenceType, time(18, 10, 0), time(31, 11, 0))
end

describe("ns.ActiveEvents", function()
	describe("for a single-day event", function()
		it("is empty before its start time (LOG-R46)", function()
			assert.are.same({}, ns.ActiveEvents({ EXTRAVAGANZA }, LISTED, at(13, 59)))
		end)

		it("holds it from its start time until its end time (LOG-R46)", function()
			assert.are.same({ 301 }, ns.ActiveEvents({ EXTRAVAGANZA }, LISTED, at(14, 0)))
			assert.are.same({ 301 }, ns.ActiveEvents({ EXTRAVAGANZA }, LISTED, at(15, 59)))
		end)

		it("is empty from its end time on (LOG-R46)", function()
			assert.are.same({}, ns.ActiveEvents({ EXTRAVAGANZA }, LISTED, at(16, 0)))
			assert.are.same({}, ns.ActiveEvents({ EXTRAVAGANZA }, LISTED, at(23, 59)))
		end)
	end)

	describe("for a multi-day event", function()
		it("holds it on its first day only from its start time (LOG-R46)", function()
			assert.are.same({}, ns.ActiveEvents({ hallowsEnd("START") }, LISTED, at(9, 59)))
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("START") }, LISTED, at(10, 0)))
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("START") }, LISTED, at(23, 59)))
		end)

		it("holds it all of a middle day, whatever the start and end times (LOG-R46)", function()
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("ONGOING") }, LISTED, at(0, 0)))
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("ONGOING") }, LISTED, at(10, 30)))
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("ONGOING") }, LISTED, at(23, 59)))
		end)

		it("holds it on its last day only until its end time (LOG-R46)", function()
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("END") }, LISTED, at(0, 0)))
			assert.are.same({ 324 }, ns.ActiveEvents({ hallowsEnd("END") }, LISTED, at(10, 59)))
			assert.are.same({}, ns.ActiveEvents({ hallowsEnd("END") }, LISTED, at(11, 0)))
		end)
	end)

	it("leaves out an event not on the catalogue's event list (LOG-R46)", function()
		local callToArms = dayEvent(1840, "ONGOING", time(6, 0, 0), time(31, 23, 59))
		assert.are.same({ 301 }, ns.ActiveEvents({ callToArms, EXTRAVAGANZA }, LISTED, at(15, 0)))
	end)

	it("lists each active event once, ascending (LOG-R46, Entry formats)", function()
		local events = { hallowsEnd("ONGOING"), EXTRAVAGANZA, EXTRAVAGANZA }
		assert.are.same({ 301, 324 }, ns.ActiveEvents(events, LISTED, at(15, 0)))
	end)

	it("is empty for calendar data read while secret, passed in as nil (LOG-R46, LOG-R93)", function()
		assert.are.same({}, ns.ActiveEvents(nil, LISTED, at(15, 0)))
	end)

	it("is empty when the realm time is unknown (LOG-R46)", function()
		assert.are.same({}, ns.ActiveEvents({ EXTRAVAGANZA }, LISTED, nil))
	end)
end)

describe("ns.CalendarMonthOffset", function()
	it("is 0 while the calendar shows the current month (LOG-R46)", function()
		assert.are.equal(0, ns.CalendarMonthOffset({ year = 2026, month = 10 }, time(11, 8, 14)))
	end)

	it("counts months from the month the calendar shows to the current one, across years (LOG-R46)", function()
		assert.are.equal(2, ns.CalendarMonthOffset({ year = 2026, month = 8 }, time(11, 8, 14)))
		assert.are.equal(-3, ns.CalendarMonthOffset({ year = 2027, month = 1 }, time(11, 8, 14)))
	end)
end)

-- A reading of the live conditions (LOG-R45): The Long Wash (148/453) at realm 08:14, skill 86+25 with lure 263,
-- the Extravaganza on and no aura. `fields` overrides any of these; NONE makes one nil.
local NONE = {}
local function reading(fields)
	local r = {
		time = 1791731640,
		minute = 494,
		date = { year = 2026, month = 10, day = 11, weekday = 1 },
		uiMap = 1439,
		instance = 1,
		zone = 148,
		subzone = 453,
		skillRank = 86,
		skillMod = 25,
		lure = 263,
		events = { 301 },
		auras = {},
		restricted = false,
	}
	for key, value in pairs(fields or {}) do
		if value == NONE then
			r[key] = nil
		else
			r[key] = value
		end
	end
	return r
end

describe("a conditions tracker", function()
	it("takes the first reading of each key as its baseline: nothing has changed yet (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		assert.are.same({}, tracker:Update(reading()))
	end)

	it("reports nothing when only the passing of realm time differs (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading())
		local later = reading({
			time = 1791735240,
			minute = 554,
			date = { year = 2026, month = 10, day = 12, weekday = 2 },
		})
		assert.are.same({}, tracker:Update(later))
	end)

	it("reports area when the zone or the subzone changes (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading())
		assert.are.same({ "area" }, tracker:Update(reading({ subzone = 0 })))
		assert.are.same({ "area" }, tracker:Update(reading({ zone = 141, subzone = 0 })))
	end)

	it("reports each other key on a change of its own fields (LOG-R47, LOG-R32)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading())
		assert.are.same({ "auras" }, tracker:Update(reading({ auras = { 1280341 } })))
		assert.are.same({ "lure" }, tracker:Update(reading({ auras = { 1280341 }, lure = NONE })))
		assert.are.same({ "events" }, tracker:Update(reading({ auras = { 1280341 }, lure = NONE, events = {} })))
		assert.are.same(
			{ "skill" },
			tracker:Update(reading({ auras = { 1280341 }, lure = NONE, events = {}, skillMod = 0 }))
		)
		assert.are.same(
			{ "skill" },
			tracker:Update(reading({ auras = { 1280341 }, lure = NONE, events = {}, skillMod = 0, skillRank = 87 }))
		)
	end)

	it("reports exactly the keys that changed, in a fixed order (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading())
		local changed = tracker:Update(reading({ skillRank = 87, events = {}, zone = 141 }))
		assert.are.same({ "area", "events", "skill" }, changed)
	end)

	it("compares lists by their contents, not as tables (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading({ auras = { 1265220, 1280341 } }))
		assert.are.same({}, tracker:Update(reading({ auras = { 1265220, 1280341 } })))
		assert.are.same({ "auras" }, tracker:Update(reading({ auras = { 1265220 } })))
	end)

	it("counts a value turning secret (nil) as a change, and back (LOG-R45, LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading())
		assert.are.same({ "auras" }, tracker:Update(reading({ auras = NONE })))
		assert.are.same({ "auras" }, tracker:Update(reading()))
	end)

	it("compares only the keys it's asked to, keeping the others' last reading (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading())
		local moved = reading({ zone = 141, subzone = 0, lure = NONE })
		assert.are.same({ "lure" }, tracker:Update(moved, { "lure" }))
		assert.are.same({ "area" }, tracker:Update(moved, { "area" }))
	end)

	it("takes a key's first reading as its baseline even after other keys have one (LOG-R47)", function()
		local tracker = ns.NewConditionsTracker()
		tracker:Update(reading(), { "area" })
		assert.are.same({}, tracker:Update(reading({ skillRank = 87 }), { "skill" }))
		assert.are.same({ "skill" }, tracker:Update(reading({ skillRank = 88 }), { "skill" }))
	end)
end)
