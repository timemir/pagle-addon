-- One reading of time in both languages (DATA-R92, LOG-R48, LOG-R50): scripts/tests/fixtures/time_specs.json, the
-- shared fixture the generator's rarity-cap evaluator is held to in scripts/tests/test_realm_time.py, read here
-- against Core's ns.MatchesConditions and ns.NextWindow, so the two can't drift. Each case is a spec's time-based
-- fields at a naive realm date-time: the realm runs at UTC+0 here, so a realm date-time is its own server time.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local FIXTURE = "scripts/tests/fixtures/time_specs.json"

-- busted runs on stock Lua 5.1, which has the require the WoW client lacks; dkjson comes with busted.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no require
local require = require

local function readFixture()
	local document = assert(require("dkjson").decode(readFile(FIXTURE)))
	-- JSON keys are strings; the event list's are event IDs (DATA-R38).
	local rules = {}
	for eventID, rule in pairs(document.rules) do
		rules[tonumber(eventID)] =
			{ weekday = rule.weekday, start = rule.start, duration = rule.duration, confirmed = true }
	end
	return document.cases, rules
end

local cases, rules = readFixture()

-- A weekly-rule lookup (ns.Catalogue.GetEventRule's shape) over the fixture's rules; 303 has none.
local function getEventRule(eventID)
	return rules[eventID]
end

-- The server time and realm minute of a fixture's "YYYY-MM-DD HH:MM" on the UTC+0 realm.
local function realmTime(at)
	local year, month, day, hour, minute = at:match("^(%d+)-(%d+)-(%d+) (%d+):(%d+)$")
	local minuteOfDay = tonumber(hour) * 60 + tonumber(minute)
	return daysFromCivil(tonumber(year), tonumber(month), tonumber(day)) * 86400 + minuteOfDay * 60, minuteOfDay
end

local SECONDS_PER_DAY = 86400

-- Whether a spec's forecast holds at a server time (LOG-R50), with no live calendar: the openings NextWindow forecasts
-- from 8 days before, walked until one holds the time or opens after it. The live calendar alone decides whether an
-- event is open now (LOG-R46), so an occurrence under way at the time a forecast starts from never counts; starting
-- 8 days back, past any weekly occurrence still under way at the time, reads the time from the weekly rules alone.
local function forecastOpen(spec, time)
	local from = time - 8 * SECONDS_PER_DAY
	while true do
		local window = ns.NextWindow(spec, from, 0, nil, getEventRule)
		if window == nil then
			return false
		elseif window.always then
			return true
		end
		local opens = window.openNow and from or window.opensAt
		if opens > time then
			return false
		elseif window.closesAt == nil or time < window.closesAt then
			return true
		end
		from = window.closesAt
	end
end

-- The events the calendar would show active at a server time, each read from its weekly rule as NextWindow forecasts
-- it (LOG-R50): an event with no rule is never active.
local function activeEvents(events, time)
	local active = {}
	for _, eventID in ipairs(events or {}) do
		if forecastOpen({ events = { eventID } }, time) then
			active[#active + 1] = eventID
		end
	end
	return active
end

describe("the shared time fixture (DATA-R92, LOG-R48, LOG-R50)", function()
	it("has cases", function()
		assert.is_true(#cases > 40)
	end)

	for _, case in ipairs(cases) do
		describe(case.why .. " (" .. case.at .. ")", function()
			local time, minute = realmTime(case.at)

			it("reads the same in MatchesConditions", function()
				local snapshot = {
					time = time,
					minute = minute,
					date = ns.RealmDate(time, minute),
					events = activeEvents(case.spec.events, time),
					auras = {},
					zone = 0,
					subzone = 0,
				}
				assert.are.equal(case.open, ns.MatchesConditions(case.spec, snapshot))
			end)

			it("reads the same in NextWindow's forecast", function()
				assert.are.equal(case.open, forecastOpen(case.spec, time))
			end)
		end)
	end
end)
