-- Pagle.NextWindow as Core publishes it (LOG-R50): the forecast rules over the realm clock and the live calendar the
-- client reports, and the catalogue's weekly rules.

-- A value the client hands out as secret: issecretvalue is true for it alone (CORE-R31).
local SECRET = setmetatable({}, {
	__tostring = function()
		return "<secret>"
	end,
})

-- A catalogue in the M1 shape (DATA-R79) whose event list holds the Extravaganza (301) on Sundays from 14:00 for
-- 2 hours, unconfirmed, and Hallow's End (324) with no weekly rule.
local function fixture()
	return {
		fingerprint = "0123456789abcdef",
		items = {},
		areas = {},
		aliases = {},
		pools = {},
		windows = {},
		events = { [301] = { weekday = 1, start = 840, duration = 120, confirmed = false }, [324] = {} },
		fishingSpells = { 7620 },
		auras = { 1265220 },
	}
end

-- Loads Core over the fixture catalogue on the fake client, which reads realm 08:15 on Sunday 11 October 2026 at
-- SERVER_TIME (a US Pacific realm, UTC-7), with `globals` replacing some of its reads; fires ADDON_LOADED.
local function load(globals)
	local loaded = loadAddon("Pagle", foreverWith(globals), { holdAddonLoaded = true })
	loaded.ns.catalogue = fixture()
	loaded.client.fire("ADDON_LOADED", "Pagle")
	return loaded.env.Pagle
end

-- A calendar whose today (11 October) holds `events`, as C_Calendar day events.
local function calendarWith(events)
	return {
		OpenCalendar = function() end,
		GetMonthInfo = function()
			return { year = 2026, month = 10, numDays = 31, firstWeekday = 5 }
		end,
		GetNumDayEvents = function()
			return #events
		end,
		GetDayEvent = function(_, _, index)
			return events[index]
		end,
	}
end

local MINUTE = 60

describe("Pagle.NextWindow", function()
	it("forecasts at the realm's UTC offset, read from the realm clock (LOG-R49, LOG-R50)", function()
		local Pagle = load()
		-- From realm 08:15, the night opens at 21:00 and closes at 06:00 the next morning.
		assert.are.same({
			opensAt = SERVER_TIME + 765 * MINUTE,
			closesAt = SERVER_TIME + 1305 * MINUTE,
			confirmed = true,
		}, Pagle.NextWindow({ time = { { 1260, 360 } } }, SERVER_TIME))
	end)

	it("forecasts an event from the catalogue's weekly rule, carrying its confirmed (LOG-R50, LOG-R56)", function()
		local Pagle = load()
		assert.are.same({
			opensAt = SERVER_TIME + 345 * MINUTE,
			closesAt = SERVER_TIME + 465 * MINUTE,
			confirmed = false,
		}, Pagle.NextWindow({ events = { 301 } }, SERVER_TIME))
		assert.is_nil(Pagle.NextWindow({ events = { 324 } }, SERVER_TIME))
	end)

	it("is open now for an event the live calendar shows active (LOG-R46, LOG-R50)", function()
		local function at(hour)
			return { year = 2026, month = 10, monthDay = 11, hour = hour, minute = 0 }
		end
		local Pagle = load({
			C_Calendar = calendarWith({ { eventID = 324, sequenceType = "", startTime = at(8), endTime = at(10) } }),
		})
		assert.are.same({ openNow = true, confirmed = true }, Pagle.NextWindow({ events = { 324 } }, SERVER_TIME))
	end)

	describe("while the realm clock is secret (LOG-R49, CORE-R31)", function()
		local function secretClock()
			return load({
				issecretvalue = function(value)
					return value == SECRET
				end,
				GetGameTime = function()
					return SECRET, SECRET
				end,
			})
		end

		it("forecasts nothing for a time-based spec: the offset can't be read (LOG-R50)", function()
			local Pagle = secretClock()
			assert.is_nil(Pagle.NextWindow({ time = { { 1260, 360 } } }, SERVER_TIME))
			assert.is_nil(Pagle.NextWindow({ events = { 301 } }, SERVER_TIME))
			assert.is_nil(Pagle.NextWindow({ season = { { from = { 6, 21 }, to = { 9, 22 } } } }, SERVER_TIME))
		end)

		it("still answers a spec without time-based fields, which needs no clock (LOG-R50)", function()
			local Pagle = secretClock()
			assert.are.same(
				{ onDemand = true, confirmed = true },
				Pagle.NextWindow({ auras = { 1265220 } }, SERVER_TIME)
			)
			assert.are.same({ always = true, confirmed = true }, Pagle.NextWindow({ areas = { 148 } }, SERVER_TIME))
		end)

		it("still raises an error for an invalid spec (LOG-R48)", function()
			local Pagle = secretClock()
			assert.error_matches(function()
				Pagle.NextWindow({ time = { { 360, 360 } } }, SERVER_TIME)
			end, "invalid condition spec: time[1] has from == to", 1, true)
		end)
	end)
end)
