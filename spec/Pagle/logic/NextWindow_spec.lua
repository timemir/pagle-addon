-- Window forecasts (LOG-R50): ns.NextWindow, the pure rules behind Pagle.NextWindow, over hand-made specs and weekly
-- rules at a fixed realm UTC offset.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local OFFSET = 120 -- the realm runs at UTC+2 (minutes east of UTC)

-- Days from 1970-01-01 to a proleptic Gregorian date (Howard Hinnant's days_from_civil), for the expected values.
local function daysFromCivil(year, month, day)
	year = month <= 2 and year - 1 or year
	local era = math.floor(year / 400)
	local yearOfEra = year - era * 400
	local dayOfYear = math.floor((153 * (month > 2 and month - 3 or month + 9) + 2) / 5) + day - 1
	local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

-- The server time (UTC epoch seconds) of a realm date and clock time on the UTC+2 realm.
local function realm(year, month, day, hour, minute)
	return daysFromCivil(year, month, day) * 86400 + (hour * 60 + minute - OFFSET) * 60
end

-- The Extravaganza (301) on Sundays from 14:00 for 2 hours, confirmed or not.
local function sundayRule(confirmed)
	return { weekday = 1, start = 840, duration = 120, confirmed = confirmed ~= false }
end

-- A weekly-rule lookup (ns.Catalogue.GetEventRule's shape) over `rules`, by event ID.
local function rulesOf(rules)
	return function(eventID)
		return rules[eventID]
	end
end

local NO_RULES = rulesOf({})

-- Forecasts `spec` from `fromTime` on the UTC+2 realm, with `active` the events the live calendar shows (none by
-- default) and `rules` the weekly rules (none by default).
local function forecast(spec, fromTime, active, rules)
	return ns.NextWindow(spec, fromTime, OFFSET, active or {}, rules or NO_RULES)
end

local NIGHT_WRAPPING = { time = { { 1260, 360 } } } -- 21:00–06:00 as one range wrapping midnight (DATA-R36)
local NIGHT_SPLIT = { time = { { 1260, 0 }, { 0, 360 } } } -- the same night as two ranges meeting at midnight
local SUMMER = { season = { { from = { 6, 21 }, to = { 9, 22 } } } }

describe("ns.NextWindow", function()
	it("sanity: 2026-10-14 is a Wednesday, so the 17th is a Saturday and the 18th a Sunday", function()
		-- 1970-01-01 was a Thursday (weekday 5, Sunday = 1).
		assert.are.equal(4, (daysFromCivil(2026, 10, 14) + 4) % 7 + 1)
	end)

	describe("time (LOG-R48, LOG-R50)", function()
		for name, night in pairs({ ["one wrapping range"] = NIGHT_WRAPPING, ["two ranges meeting"] = NIGHT_SPLIT }) do
			it(
				("is open at realm 22:00 until 06:00 the next realm morning, night as %s (LOG-R50)"):format(name),
				function()
					assert.are.same(
						{ openNow = true, closesAt = realm(2026, 10, 15, 6, 0), confirmed = true },
						forecast(night, realm(2026, 10, 14, 22, 0))
					)
				end
			)

			it(("opens at 21:00 that realm day when read at 08:15, night as %s (LOG-R50)"):format(name), function()
				assert.are.same({
					opensAt = realm(2026, 10, 14, 21, 0),
					closesAt = realm(2026, 10, 15, 6, 0),
					confirmed = true,
				}, forecast(night, realm(2026, 10, 14, 8, 15)))
			end)
		end

		it("is open at a range's from minute and closed at its to minute (LOG-R48)", function()
			local day = { time = { { 360, 1260 } } }
			assert.is_true(forecast(day, realm(2026, 10, 14, 6, 0)).openNow)
			assert.are.same({
				opensAt = realm(2026, 10, 15, 6, 0),
				closesAt = realm(2026, 10, 15, 21, 0),
				confirmed = true,
			}, forecast(day, realm(2026, 10, 14, 21, 0)))
		end)

		it("reads the realm clock at the realm's offset, not UTC (LOG-R49, LOG-R50)", function()
			-- 20:30 UTC is 22:30 on the realm: open, though 20:30 is outside the night.
			local window = ns.NextWindow(NIGHT_WRAPPING, realm(2026, 10, 14, 22, 30), OFFSET, {}, NO_RULES)
			assert.is_true(window.openNow)
			assert.is_nil(ns.NextWindow(NIGHT_WRAPPING, realm(2026, 10, 14, 22, 30), 0, {}, NO_RULES).openNow)
		end)
	end)

	describe("season (LOG-R48, LOG-R50)", function()
		it("opens on a season's first day next year at realm 00:00 when read in October (LOG-R50)", function()
			assert.are.same({
				opensAt = realm(2027, 6, 21, 0, 0),
				closesAt = realm(2027, 9, 23, 0, 0),
				confirmed = true,
			}, forecast(SUMMER, realm(2026, 10, 14, 8, 15)))
		end)

		it("opens a time and season spec at the first time range inside the season (LOG-R50)", function()
			local summerDays = { time = { { 360, 1260 } }, season = SUMMER.season }
			assert.are.same({
				opensAt = realm(2027, 6, 21, 6, 0),
				closesAt = realm(2027, 6, 21, 21, 0),
				confirmed = true,
			}, forecast(summerDays, realm(2026, 10, 14, 8, 15)))
		end)

		it("closes a season wrapping the year at its end, across New Year (LOG-R48, LOG-R50)", function()
			local winter = { season = { { from = { 12, 21 }, to = { 3, 19 } } } }
			assert.are.same(
				{ openNow = true, closesAt = realm(2027, 3, 20, 0, 0), confirmed = true },
				forecast(winter, realm(2026, 12, 30, 12, 0))
			)
		end)

		it("leaves closesAt out when the season doesn't stop within the horizon (LOG-R50)", function()
			local always = { season = { { from = { 1, 1 }, to = { 12, 31 } } } }
			assert.are.same({ openNow = true, confirmed = true }, forecast(always, realm(2026, 10, 14, 8, 15)))
		end)
	end)

	describe("events (LOG-R46, LOG-R50, LOG-R56)", function()
		local EXTRAVAGANZA = { events = { 301 } }
		local RULES = rulesOf({ [301] = sundayRule() })

		it("opens on Saturday at Sunday 14:00 and closes after the rule's duration (LOG-R50, LOG-R56)", function()
			assert.are.same({
				opensAt = realm(2026, 10, 18, 14, 0),
				closesAt = realm(2026, 10, 18, 16, 0),
				confirmed = true,
			}, forecast(EXTRAVAGANZA, realm(2026, 10, 17, 10, 0), {}, RULES))
		end)

		it(
			"is open now when the live calendar shows it active, until its weekly occurrence ends (LOG-R46, LOG-R50)",
			function()
				assert.are.same(
					{ openNow = true, closesAt = realm(2026, 10, 18, 16, 0), confirmed = true },
					forecast(EXTRAVAGANZA, realm(2026, 10, 18, 15, 0), { 301 }, RULES)
				)
			end
		)

		it("is open now when active outside its weekly rule, with no closesAt (LOG-R50)", function()
			assert.are.same(
				{ openNow = true, confirmed = true },
				forecast(EXTRAVAGANZA, realm(2026, 10, 17, 10, 0), { 301 }, RULES)
			)
		end)

		it(
			"isn't open during its weekly occurrence when the calendar doesn't show it, and opens the Sunday after (LOG-R50)",
			function()
				local expected = {
					opensAt = realm(2026, 10, 25, 14, 0),
					closesAt = realm(2026, 10, 25, 16, 0),
					confirmed = true,
				}
				assert.are.same(expected, forecast(EXTRAVAGANZA, realm(2026, 10, 18, 15, 0), {}, RULES))
				-- Calendar data read while secret counts as no events (LOG-R46).
				assert.are.same(expected, ns.NextWindow(EXTRAVAGANZA, realm(2026, 10, 18, 15, 0), OFFSET, nil, RULES))
			end
		)

		it("forecasts from the weekly rule, never the calendar, after now (LOG-R50)", function()
			-- Another event active now doesn't open this one.
			assert.are.same(
				realm(2026, 10, 18, 14, 0),
				forecast(EXTRAVAGANZA, realm(2026, 10, 17, 10, 0), { 324 }, RULES).opensAt
			)
		end)

		it("opens later only by its weekly rule when active now but closed by another field (LOG-R50)", function()
			-- Wednesday 22:00, active by the calendar outside its Sunday rule, after the 06:00–21:00 time range: the
			-- calendar opens nothing later, so Sunday's occurrence is next.
			local daytime = { events = { 301 }, time = { { 360, 1260 } } }
			assert.are.same({
				opensAt = realm(2026, 10, 18, 14, 0),
				closesAt = realm(2026, 10, 18, 16, 0),
				confirmed = true,
			}, forecast(daytime, realm(2026, 10, 14, 22, 0), { 301 }, RULES))
			-- With no weekly rule, nothing opens later (LOG-R50's parenthesis).
			local noRule = { events = { 999 }, time = { { 360, 1260 } } }
			assert.is_nil(forecast(noRule, realm(2026, 10, 14, 22, 0), { 999 }, RULES))
		end)

		describe("from a time other than now: the live calendar decides now alone (LOG-R46, LOG-R50)", function()
			-- Sunday 15:00, with the Extravaganza live in its 14:00–16:00 occurrence.
			local NOW = realm(2026, 10, 18, 15, 0)

			-- Forecasts `spec` from `fromTime`, with the live calendar showing `active` at NOW.
			local function forecastAtNow(spec, fromTime, active)
				return ns.NextWindow(spec, fromTime, OFFSET, active, RULES, NOW)
			end

			it("gives the occurrence under way now its weekly span when forecast from before it (HNT-R63)", function()
				-- The board's ruler starts 2 hours before now, at 13:00.
				assert.are.same({
					opensAt = realm(2026, 10, 18, 14, 0),
					closesAt = realm(2026, 10, 18, 16, 0),
					confirmed = true,
				}, forecastAtNow(EXTRAVAGANZA, realm(2026, 10, 18, 13, 0), { 301 }))
			end)

			it("forecasts from the weekly rules alone after now, even at the occurrence's end (HNT-R53)", function()
				assert.are.same({
					opensAt = realm(2026, 10, 25, 14, 0),
					closesAt = realm(2026, 10, 25, 16, 0),
					confirmed = true,
				}, forecastAtNow(EXTRAVAGANZA, realm(2026, 10, 18, 16, 0), { 301 }))
			end)

			it("opens at now, with no closesAt, an event active outside its weekly rule (HNT-R63)", function()
				-- Saturday 10:00 now, forecast from 08:00: the calendar opens it at now, never before.
				local saturday = realm(2026, 10, 17, 10, 0)
				assert.are.same(
					{ opensAt = saturday, confirmed = true },
					ns.NextWindow(EXTRAVAGANZA, realm(2026, 10, 17, 8, 0), OFFSET, { 301 }, RULES, saturday)
				)
			end)

			it("drops the occurrence under way now when the calendar doesn't show it, from before now", function()
				assert.are.same(
					realm(2026, 10, 25, 14, 0),
					forecastAtNow(EXTRAVAGANZA, realm(2026, 10, 18, 13, 0), {}).opensAt
				)
			end)
		end)

		it("takes the first occurrence of any of its events (LOG-R48, LOG-R50)", function()
			local rules = rulesOf({
				[301] = sundayRule(),
				[324] = { weekday = 7, start = 1200, duration = 300, confirmed = true },
			})
			-- Saturday 20:00 for 5 hours runs into Sunday 01:00.
			assert.are.same({
				opensAt = realm(2026, 10, 17, 20, 0),
				closesAt = realm(2026, 10, 18, 1, 0),
				confirmed = true,
			}, forecast({ events = { 301, 324 } }, realm(2026, 10, 17, 10, 0), {}, rules))
		end)

		it("knows an occurrence that started the realm day before is still under way (LOG-R50)", function()
			local rules = rulesOf({ [324] = { weekday = 7, start = 1200, duration = 300, confirmed = true } })
			local sundayNight = realm(2026, 10, 18, 0, 30)
			assert.are.same(
				{ openNow = true, closesAt = realm(2026, 10, 18, 1, 0), confirmed = true },
				forecast({ events = { 324 } }, sundayNight, { 324 }, rules)
			)
			assert.are.same(realm(2026, 10, 24, 20, 0), forecast({ events = { 324 } }, sundayNight, {}, rules).opensAt)
		end)

		it("intersects with the time ranges: open only while both hold (LOG-R50)", function()
			local afternoon = { events = { 301 }, time = { { 900, 1260 } } } -- 15:00–21:00
			assert.are.same({
				opensAt = realm(2026, 10, 18, 15, 0),
				closesAt = realm(2026, 10, 18, 16, 0),
				confirmed = true,
			}, forecast(afternoon, realm(2026, 10, 17, 10, 0), {}, RULES))
		end)
	end)

	describe("no opening (LOG-R50)", function()
		it("is nil when the fields never hold together within 400 days", function()
			local nightExtravaganza = { events = { 301 }, time = NIGHT_WRAPPING.time }
			local rules = rulesOf({ [301] = sundayRule() })
			assert.is_nil(forecast(nightExtravaganza, realm(2026, 10, 14, 8, 15), {}, rules))
		end)

		it("is nil when the next opening is more than 400 days away (Tunables)", function()
			-- 20–21 October is a Tuesday and Wednesday in 2026, a Wednesday and Thursday in 2027, and isn't a Sunday
			-- again until 2030, past the 400 days that end on 18 November 2027.
			local spec = { events = { 301 }, season = { { from = { 10, 20 }, to = { 10, 21 } } } }
			local rules = rulesOf({ [301] = sundayRule() })
			assert.is_nil(forecast(spec, realm(2026, 10, 14, 8, 15), {}, rules))
		end)

		it("is nil for an event with no weekly rule that isn't active", function()
			assert.is_nil(forecast({ events = { 301 } }, realm(2026, 10, 14, 8, 15)))
		end)

		it("is open now for an event with no weekly rule that is active, with no closesAt", function()
			assert.are.same(
				{ openNow = true, confirmed = true },
				forecast({ events = { 301 } }, realm(2026, 10, 14, 8, 15), { 301 })
			)
		end)
	end)

	describe("specs without time-based fields (LOG-R50)", function()
		it("gives { onDemand = true } for a spec with auras", function()
			assert.are.same(
				{ onDemand = true, confirmed = true },
				forecast({ auras = { 1265220 } }, realm(2026, 10, 14, 8, 15))
			)
			assert.are.same(
				{ onDemand = true, confirmed = true },
				forecast({ auras = { 1265220 }, areas = { 148 }, lure = true }, realm(2026, 10, 14, 8, 15))
			)
		end)

		it("gives { always = true } for areas, lure or skill alone, or an empty spec", function()
			for _, spec in ipairs({ { areas = { 148 } }, { skill = { min = 100 } }, { lure = { 263 } }, {} }) do
				assert.are.same({ always = true, confirmed = true }, forecast(spec, realm(2026, 10, 14, 8, 15)))
			end
		end)

		it("forecasts the time fields of a spec that also has auras, areas, lure or skill", function()
			local spec =
				{ time = NIGHT_WRAPPING.time, auras = { 1265220 }, areas = { 148 }, lure = true, skill = { min = 1 } }
			assert.are.same({
				opensAt = realm(2026, 10, 14, 21, 0),
				closesAt = realm(2026, 10, 15, 6, 0),
				confirmed = true,
			}, forecast(spec, realm(2026, 10, 14, 8, 15)))
		end)
	end)

	describe("confirmed (LOG-R50)", function()
		it("is false for a window spec carrying confirmed = false", function()
			local night = { time = NIGHT_WRAPPING.time, confirmed = false }
			assert.is_false(forecast(night, realm(2026, 10, 14, 8, 15)).confirmed)
			assert.is_false(forecast({ auras = { 1265220 }, confirmed = false }, realm(2026, 10, 14, 8, 15)).confirmed)
			assert.is_false(forecast({ confirmed = false }, realm(2026, 10, 14, 8, 15)).confirmed)
		end)

		it("is true for a window spec carrying confirmed = true", function()
			local night = { time = NIGHT_WRAPPING.time, confirmed = true }
			assert.is_true(forecast(night, realm(2026, 10, 14, 8, 15)).confirmed)
		end)

		it("is false for a forecast that used an unconfirmed weekly rule", function()
			local rules = rulesOf({ [301] = sundayRule(false) })
			assert.is_false(forecast({ events = { 301 } }, realm(2026, 10, 17, 10, 0), {}, rules).confirmed)
			assert.is_false(forecast({ events = { 301 } }, realm(2026, 10, 18, 15, 0), { 301 }, rules).confirmed)
		end)

		it("reads only the weekly rules of the occurrence the opening used (LOG-R50, LOG-R56)", function()
			-- 301 confirmed on Sundays at 14:00; 302 unconfirmed on Tuesdays at 14:00.
			local rules = rulesOf({
				[301] = sundayRule(),
				[302] = { weekday = 3, start = 840, duration = 120, confirmed = false },
			})
			local both = { events = { 301, 302 } }
			local sunday = forecast(both, realm(2026, 10, 17, 10, 0), {}, rules)
			assert.are.same({ realm(2026, 10, 18, 14, 0), true }, { sunday.opensAt, sunday.confirmed })
			local tuesday = forecast(both, realm(2026, 10, 19, 10, 0), {}, rules)
			assert.are.same({ realm(2026, 10, 20, 14, 0), false }, { tuesday.opensAt, tuesday.confirmed })
			-- Active by the calendar outside every rule: no rule made the opening.
			assert.is_true(forecast(both, realm(2026, 10, 19, 10, 0), { 302 }, rules).confirmed)
		end)

		it("is true for a Module's own spec, with no confirmed field and confirmed weekly rules", function()
			local rules = rulesOf({ [301] = sundayRule() })
			assert.is_true(forecast({ events = { 301 } }, realm(2026, 10, 17, 10, 0), {}, rules).confirmed)
		end)
	end)

	it("raises an error for an invalid condition spec, as MatchesConditions does (LOG-R48)", function()
		assert.error_matches(function()
			forecast({ time = { { 360, 360 } } }, realm(2026, 10, 14, 8, 15))
		end, "invalid condition spec: time[1] has from == to", 1, true)
	end)
end)
