-- Board days and weeks (tackle-board.md › Board days and weeks, TKB-R10–R13): the live day and week starts, their
-- fallback, the numbering every record and Cast gets from the log alone, and the time to the next reset.
--
-- The reset API is spec/Pagle_TackleBoard/support.lua's: a US realm at UTC−7 whose clock reads Sunday 11 October 2026
-- 15:15 UTC (realm 08:15), daily reset 15:00 UTC, weekly reset Tuesday 15:00 UTC. Expected times are literals worked
-- out by hand (`date -u -d @<t>` checks each).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DAY, WEEK = 86400, 604800

local NOW = SERVER_TIME -- Sun 11 Oct 2026 15:15 UTC, realm 08:15
local DAILY = 1791730800 -- Sun 11 Oct 15:00 UTC: today's daily reset
local WEEKLY = 1791298800 -- Tue 6 Oct 15:00 UTC: this week's weekly reset
local MIDNIGHT = 1791702000 -- Sun 11 Oct 07:00 UTC: realm midnight today

-- The hand-worked resets are the support's, so the two can't drift apart.
assert(DAILY == board.DAILY_RESET, "DAILY is not support.DAILY_RESET")
assert(WEEKLY == board.WEEKLY_RESET - WEEK, "WEEKLY is not a week before support.WEEKLY_RESET")
assert(MIDNIGHT == NOW - (8 * 3600 + 15 * 60), "MIDNIGHT is not realm 00:00 at SERVER_TIME (realm 08:15)")

-- Each way a reset call can fail (TKB-R11): missing (false in support.resetAPI), nil, 0 or negative.
local FAILURES = {
	{ "missing", false },
	{
		"nil",
		function()
			return nil
		end,
	},
	{
		"0",
		function()
			return 0
		end,
	},
	{
		"negative",
		function()
			return -5
		end,
	},
}

describe("board days and weeks", function()
	local ns = board.load().ns

	--- The reset API at server time `now`, with `overrides` as support.resetAPI takes them.
	local function api(now, overrides)
		overrides = overrides or {}
		overrides.now = function()
			return now
		end
		return board.resetAPI(nil, overrides)
	end

	describe("ns.LiveBoundaries", function()
		it("starts the day and week at the last daily and weekly reset, from the reset calls (TKB-R10)", function()
			assert.are.same({ DAILY, WEEKLY }, { ns.LiveBoundaries(api(NOW)) })
		end)

		for _, failure in ipairs(FAILURES) do
			local name, failed = failure[1], failure[2]
			it("falls the day back when the daily call is " .. name .. ", not the week (TKB-R11)", function()
				assert.are.same({ MIDNIGHT, WEEKLY }, { ns.LiveBoundaries(api(NOW, { daily = failed })) })
			end)

			it("falls the week back when the weekly call is " .. name .. ", not the day (TKB-R11)", function()
				-- Region 1: Tuesday, so realm midnight on Tue 6 Oct (07:00 UTC), 5 days before today's.
				assert.are.same({ DAILY, MIDNIGHT - 5 * DAY }, { ns.LiveBoundaries(api(NOW, { weekly = failed })) })
			end)
		end

		it("falls both back when both calls are missing (TKB-R11)", function()
			local both = api(NOW, { daily = false, weekly = false })
			assert.are.same({ MIDNIGHT, MIDNIGHT - 5 * DAY }, { ns.LiveBoundaries(both) })
		end)

		it("takes realm midnight to the second, whatever the seconds past the realm minute (TKB-R11)", function()
			-- 08:15:42 realm: the realm minute is 495, and the 42 s come off with now mod 60.
			local later = api(NOW + 42, { daily = false })
			assert.are.equal(MIDNIGHT, (ns.LiveBoundaries(later)))
		end)

		describe("while the realm clock can't be read", function()
			-- 15:15 UTC: UTC's midnight is Sun 11 Oct 00:00 UTC, 15 h 15 min back.
			local UTC_MIDNIGHT = NOW - (15 * 3600 + 15 * 60)
			-- A secret value (CORE-R31): arithmetic on it raises an error, as the client's does.
			local SECRET = setmetatable({}, {
				__add = function()
					error("arithmetic on a secret value")
				end,
				__mul = function()
					error("arithmetic on a secret value")
				end,
			})
			local UNREADABLE = {
				{
					"missing",
					function(at)
						at.GetGameTime = nil
					end,
				},
				{
					"answering nil",
					function(at)
						at.GetGameTime = function()
							return nil, nil
						end
					end,
				},
				{
					"secret",
					function(at)
						at.GetGameTime = function()
							return SECRET, SECRET
						end
						at.issecretvalue = function(value)
							return value == SECRET
						end
					end,
				},
			}

			for _, case in ipairs(UNREADABLE) do
				local name, unread = case[1], case[2]
				it(
					"falls the day back to UTC's midnight with the clock " .. name .. " (TKB-R11, TKB-R105, CORE-R31)",
					function()
						local at = api(NOW, { daily = false, weekly = false })
						unread(at)

						-- Region 1: the week from Tuesday 6 Oct, 5 days before the calendar's Sunday.
						assert.are.same({ UTC_MIDNIGHT, UTC_MIDNIGHT - 5 * DAY }, { ns.LiveBoundaries(at) })
						assert.is_nil(ns.RealmMinute(at))
					end
				)

				it(
					"arms the reset timer for UTC's next midnight with the clock " .. name .. " (TKB-R11, TKB-R13)",
					function()
						local at = api(NOW, { daily = false })
						unread(at)

						-- 15:15 UTC to midnight: 8 h 45 min, plus the 2 s delay.
						assert.are.equal(31500 + 2, ns.SecondsToNextReset(at))
					end
				)
			end

			it("reads the realm minute once the clock is readable again (TKB-R11)", function()
				assert.are.equal(8 * 60 + 15, ns.RealmMinute(api(NOW)))
			end)
		end)

		describe("the fallback week", function()
			-- The fallback reset weekday by region (tackle-board.md › Tunables), from Sunday 11 Oct (realm).
			local regions = {
				{ region = 1, weekday = "Tuesday", start = MIDNIGHT - 5 * DAY }, -- Tue 6 Oct
				{ region = 2, weekday = "Thursday", start = MIDNIGHT - 3 * DAY }, -- Thu 8 Oct
				{ region = 3, weekday = "Wednesday", start = MIDNIGHT - 4 * DAY }, -- Wed 7 Oct
				{ region = 4, weekday = "Thursday", start = MIDNIGHT - 3 * DAY },
				{ region = 5, weekday = "Thursday", start = MIDNIGHT - 3 * DAY },
				{ region = 72, weekday = "Wednesday", start = MIDNIGHT - 4 * DAY },
				{ region = false, weekday = "Wednesday", start = MIDNIGHT - 4 * DAY },
			}
			for _, case in ipairs(regions) do
				local region = case.region and ("region " .. case.region) or "no GetCurrentRegion"
				it("starts on " .. case.weekday .. " with " .. region .. " (TKB-R11, Tunables)", function()
					local fallback = api(NOW, { weekly = false, region = case.region })
					assert.are.equal(case.start, select(2, ns.LiveBoundaries(fallback)))
				end)
			end

			it("starts today when today is the fallback weekday (TKB-R11: on or before today)", function()
				-- Tue 13 Oct 08:15 realm; realm midnight is Tue 13 Oct 07:00 UTC.
				local tuesday = api(NOW + 2 * DAY, { weekly = false, region = 1 })
				assert.are.equal(MIDNIGHT + 2 * DAY, select(2, ns.LiveBoundaries(tuesday)))
			end)

			it("starts 6 days back the day before the fallback weekday (TKB-R11)", function()
				-- Mon 12 Oct 08:15 realm, region 1: Tuesday 6 Oct.
				local monday = api(NOW + DAY, { weekly = false, region = 1 })
				assert.are.equal(MIDNIGHT - 5 * DAY, select(2, ns.LiveBoundaries(monday)))
			end)
		end)
	end)

	describe("ns.NumberBoundary", function()
		-- The `start` record of a board started now: day 0, week 0, live boundaries.
		local START = { day = 0, week = 0, dayStart = DAILY, weekStart = WEEKLY }

		it("numbers the start record day 0 and week 0 (TKB-R12)", function()
			assert.are.same({ day = 0, week = 0 }, ns.NumberBoundary(nil, DAILY, WEEKLY))
		end)

		it("numbers a day record 3 days after start day 3, a weekly reset later week 1 (TKB-R12)", function()
			-- Wed 14 Oct: the weekly reset of Tue 13 Oct is behind it.
			assert.are.same({ day = 3, week = 1 }, ns.NumberBoundary(START, DAILY + 3 * DAY, WEEKLY + WEEK))
		end)

		it("rounds a day start an hour later or earlier (daylight saving) to whole days (TKB-R12)", function()
			assert.are.same({ day = 3, week = 0 }, ns.NumberBoundary(START, DAILY + 3 * DAY + 3600, WEEKLY))
			assert.are.same({ day = 3, week = 0 }, ns.NumberBoundary(START, DAILY + 3 * DAY - 3600, WEEKLY))
		end)

		it("never numbers below the previous record when the day start steps back an hour (TKB-R12)", function()
			local day3 = { day = 3, week = 1, dayStart = DAILY + 3 * DAY, weekStart = WEEKLY + WEEK }
			assert.are.same({ day = 3, week = 1 }, ns.NumberBoundary(day3, DAILY + 3 * DAY - 3600, WEEKLY + WEEK))
		end)

		it("never numbers below the previous record when the clock steps back a day or a week (TKB-R12)", function()
			local day3 = { day = 3, week = 1, dayStart = DAILY + 3 * DAY, weekStart = WEEKLY + WEEK }
			assert.are.same({ day = 3, week = 1 }, ns.NumberBoundary(day3, DAILY + 2 * DAY, WEEKLY))
		end)

		it("never numbers below the previous record on a switch to the fallback and back (TKB-R11, TKB-R12)", function()
			-- Today, both calls failed: realm midnight (8 h before the daily reset) and Tuesday's realm midnight.
			local fallback = { ns.LiveBoundaries(api(NOW, { daily = false, weekly = false })) }
			local onFallback = ns.NumberBoundary(START, fallback[1], fallback[2])
			assert.are.same({ day = 0, week = 0 }, onFallback)

			-- The next day, the calls answer again.
			local back = { day = 0, week = 0, dayStart = fallback[1], weekStart = fallback[2] }
			assert.are.same({ day = 1, week = 0 }, ns.NumberBoundary(back, DAILY + DAY, WEEKLY))
		end)

		it("raises the week by one for a weekly reset 10 seconds off a daily reset (TKB-R12)", function()
			assert.are.same({ day = 7, week = 1 }, ns.NumberBoundary(START, DAILY + 7 * DAY, WEEKLY + WEEK - 10))
			assert.are.same({ day = 7, week = 1 }, ns.NumberBoundary(START, DAILY + 7 * DAY, WEEKLY + WEEK + 10))
		end)
	end)

	describe("an entry's day and a day's start and week", function()
		-- A board started now: its `start` record is day 0, week 0 (Sun 11 Oct; the week began Tue 6 Oct).
		local START = { day = 0, week = 0, dayStart = DAILY, weekStart = WEEKLY }

		it("gives an entry before the start record no day (TKB-R12)", function()
			assert.is_nil(ns.DayOf(nil, NOW))
		end)

		it("puts an entry on the day it falls in, counted from the latest boundary record (TKB-R12)", function()
			assert.are.equal(0, ns.DayOf(START, NOW))
			assert.are.equal(0, ns.DayOf(START, DAILY + DAY - 1))
			assert.are.equal(1, ns.DayOf(START, DAILY + DAY))
			assert.are.equal(3, ns.DayOf(START, DAILY + 3 * DAY + 5))
			-- From a later `day` record: day 3 started Wed 14 Oct 15:00.
			local day3 = { day = 3, week = 1, dayStart = DAILY + 3 * DAY, weekStart = WEEKLY + WEEK }
			assert.are.equal(5, ns.DayOf(day3, DAILY + 5 * DAY + 600))
		end)

		it("starts day k k whole days after the boundary's day start (TKB-R12)", function()
			assert.are.equal(DAILY, ns.DayStartOf(START, 0))
			assert.are.equal(DAILY + 4 * DAY, ns.DayStartOf(START, 4)) -- Thu 15 Oct 15:00
			local day3 = { day = 3, week = 1, dayStart = DAILY + 3 * DAY, weekStart = WEEKLY + WEEK }
			assert.are.equal(DAILY + 9 * DAY, ns.DayStartOf(day3, 9))
		end)

		it("puts a day in the week its start falls in, from the weekly reset on (TKB-R12)", function()
			-- Day 1 is Mon 12 Oct, day 2 Tue 13 Oct (the weekly reset), day 8 Mon 19, day 9 Tue 20 Oct.
			local weeks = {}
			for k = 0, 9 do
				weeks[#weeks + 1] = ns.WeekOfDay(START, k)
			end
			assert.are.same({ 0, 0, 1, 1, 1, 1, 1, 1, 1, 2 }, weeks)
		end)

		it("keeps a weekly reset 10 s off a daily one from being missed: the 12 h slack (TKB-R12)", function()
			local late = { day = 0, week = 0, dayStart = DAILY, weekStart = WEEKLY + 10 }
			assert.are.same({ 0, 1 }, { ns.WeekOfDay(late, 1), ns.WeekOfDay(late, 2) })
			local early = { day = 0, week = 0, dayStart = DAILY, weekStart = WEEKLY - 10 }
			assert.are.same({ 0, 1 }, { ns.WeekOfDay(early, 1), ns.WeekOfDay(early, 2) })
		end)

		it("agree with each other and with the day record written live, across a week boundary (TKB-R12)", function()
			-- Each day from Sun 11 to Wed 21 Oct, a minute after its reset: what live play, catch-up and rebuild see.
			local expectedWeeks = { [0] = 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2 }
			for k = 0, 10 do
				local t = DAILY + k * DAY + 60
				local live = api(t)
				local dayStart, weekStart = ns.LiveBoundaries(live)
				local record = ns.NumberBoundary(START, dayStart, weekStart)

				assert.are.same({ day = k, week = expectedWeeks[k] }, record, "day " .. k)
				assert.are.equal(k, ns.DayOf(START, t), "DayOf, day " .. k)
				assert.are.equal(k, ns.Today(START, live), "Today, day " .. k)
				assert.are.equal(dayStart, ns.DayStartOf(START, k), "DayStartOf, day " .. k)
				assert.are.equal(expectedWeeks[k], ns.WeekOfDay(START, k), "WeekOfDay, day " .. k)
			end
		end)

		it("gives today the number a day record written now would get, never below the boundary's (TKB-R12)", function()
			local day3 = { day = 3, week = 1, dayStart = DAILY + 3 * DAY, weekStart = WEEKLY + WEEK }
			-- The clock stepped back to day 1: today stays day 3, as a `day` record would.
			assert.are.equal(3, ns.Today(day3, api(DAILY + DAY + 60)))
			-- On the fallback, 8 h before the daily reset, today is still day 3, and day 4 a day on.
			assert.are.equal(3, ns.Today(day3, api(DAILY + 3 * DAY + 60, { daily = false })))
			assert.are.equal(4, ns.Today(day3, api(DAILY + 4 * DAY + 60, { daily = false })))
		end)

		it("has no today before the start record (TKB-R12)", function()
			assert.is_nil(ns.Today(nil, api(NOW)))
		end)

		describe("when the reset shifts an hour (daylight saving)", function()
			-- From Wed 14 Oct (day 3) the daily reset is at 16:00 UTC instead of 15:00.
			local function shiftedReset(k)
				return DAILY + k * DAY + (k >= 3 and 3600 or 0)
			end
			local function shifted(now)
				return api(now, {
					daily = function()
						local k = 0
						while shiftedReset(k) <= now do
							k = k + 1
						end
						return shiftedReset(k) - now
					end,
				})
			end
			local wed1530 = DAILY + 3 * DAY + 1800 -- before Wednesday's (shifted) reset: really still day 2
			local thu1530 = DAILY + 4 * DAY + 1800 -- before Thursday's reset: really still day 3

			it("puts a Cast within the shifted hour on the neighbouring day, as accepted (TKB-R12)", function()
				assert.are.equal(3, ns.DayOf(START, wed1530))
				assert.are.equal(4, ns.DayOf(START, thu1530))
			end)

			it("is corrected from the next day record on (TKB-R12)", function()
				-- The live step writes a `day` record on Wednesday at 16:30, after the shifted reset.
				local wed1630 = DAILY + 3 * DAY + 5400
				local dayStart, weekStart = ns.LiveBoundaries(shifted(wed1630))
				assert.are.equal(DAILY + 3 * DAY + 3600, dayStart)
				local record = ns.NumberBoundary(START, dayStart, weekStart)
				assert.are.same({ day = 3, week = 1 }, record)
				local day3 = { day = 3, week = 1, dayStart = dayStart, weekStart = weekStart }

				assert.are.equal(3, ns.DayOf(day3, thu1530))
				assert.are.equal(3, ns.Today(day3, shifted(thu1530)))
				assert.are.equal(4, ns.DayOf(day3, DAILY + 4 * DAY + 3600))
			end)
		end)
	end)

	describe("ns.SecondsToNextReset", function()
		it("is the daily call's answer plus the 2 s reset timer delay (TKB-R13, Tunables)", function()
			-- 15:15 UTC to the next reset at 15:00 UTC: 23 h 45 min.
			assert.are.equal(85500 + 2, ns.SecondsToNextReset(api(NOW)))
		end)

		for _, failure in ipairs(FAILURES) do
			local name, failed = failure[1], failure[2]
			it("is the time to realm midnight plus 2 s on a daily call " .. name .. " (TKB-R11, TKB-R13)", function()
				-- 08:15 realm to midnight: 15 h 45 min.
				assert.are.equal(56700 + 2, ns.SecondsToNextReset(api(NOW, { daily = failed })))
			end)
		end

		it("counts to the next realm midnight a second after one (TKB-R11, TKB-R13)", function()
			assert.are.equal(DAY - 1 + 2, ns.SecondsToNextReset(api(MIDNIGHT + 1, { daily = false })))
		end)
	end)
end)
