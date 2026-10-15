if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Board days and weeks (TKB-R10–R13): when the current board day and week started, live or by fallback, and the day
-- and week every record and Cast gets from the log alone. Pure logic (CORE-R7): the WoW calls come in as `api`
-- (ns.api's shape, logic/Seams.lua), so specs drive every case.

--- Day and week length in seconds (tackle-board.md › Tunables).
ns.DAY_SECONDS = 86400
ns.WEEK_SECONDS = 604800

--- The fallback weekly reset weekday (1 = Sunday) by `GetCurrentRegion()` (tackle-board.md › Tunables): Tuesday for
--- the Americas (1), Thursday for Korea, Taiwan and China (2, 4, 5); any other region, or none, is
--- ns.FALLBACK_WEEKDAY_OTHER, Wednesday (Europe, 3).
ns.FALLBACK_WEEKDAY = { [1] = 3, [2] = 5, [4] = 5, [5] = 5 }
ns.FALLBACK_WEEKDAY_OTHER = 4

--- The realm clock as a minute of the realm's day, 0–1439, from `api.GetGameTime` (TKB-R11, TKB-R105): nil while the
--- client lacks the call, it answers nil, or either value is secret (LOG-R49, CORE-R31: `api.issecretvalue`).
---@param api TackleResetAPI
---@return integer?
function ns.RealmMinute(api)
	local getGameTime = api.GetGameTime
	if not getGameTime then
		return nil
	end
	local hour, minute = getGameTime()
	local isSecret = api.issecretvalue
	if hour == nil or minute == nil or (isSecret and (isSecret(hour) or isSecret(minute))) then
		return nil
	end
	return hour * 60 + minute
end

--- The latest realm midnight before or at server time `now` (TKB-R11): `now − realm minute × 60 − now mod 60`, the
--- realm minute from ns.RealmMinute; UTC's midnight while the realm clock can't be read, as the realm dates fall back
--- to UTC (TKB-R105).
---@param api TackleResetAPI
---@param now integer
---@return integer
local function realmMidnight(api, now)
	local minute = ns.RealmMinute(api) or math.floor(now / 60) % (ns.DAY_SECONDS / 60)
	return now - minute * 60 - now % 60
end

--- The week's fallback start (TKB-R11): realm midnight on the fallback reset weekday on or before the realm's today.
---@param api TackleResetAPI
---@param now integer
---@return integer
local function fallbackWeekStart(api, now)
	local region = api.GetCurrentRegion and api.GetCurrentRegion()
	local resetWeekday = ns.FALLBACK_WEEKDAY[region] or ns.FALLBACK_WEEKDAY_OTHER
	local today = api.C_DateAndTime.GetCurrentCalendarTime().weekday
	return realmMidnight(api, now) - (today - resetWeekday) % 7 * ns.DAY_SECONDS
end

--- The seconds until the next reset from the C_DateAndTime call `name`, or nil
--- when it is missing or answers nil or a value ≤ 0, so its boundary falls back (TKB-R11).
---@param api TackleResetAPI
---@param name "GetSecondsUntilDailyReset"|"GetSecondsUntilWeeklyReset"
---@return integer?
local function secondsUntil(api, name)
	local call = api.C_DateAndTime and api.C_DateAndTime[name]
	local seconds = call and call()
	if seconds and seconds > 0 then
		return seconds
	end
	return nil
end

--- The current board day's and week's starts in server time (TKB-R10), each falling back on its own (TKB-R11).
---@param api TackleResetAPI
---@return integer dayStart
---@return integer weekStart
function ns.LiveBoundaries(api)
	local now = api.GetServerTime()
	local daily = secondsUntil(api, "GetSecondsUntilDailyReset")
	local weekly = secondsUntil(api, "GetSecondsUntilWeeklyReset")
	local dayStart = daily and now + daily - ns.DAY_SECONDS or realmMidnight(api, now)
	local weekStart = weekly and now + weekly - ns.WEEK_SECONDS or fallbackWeekStart(api, now)
	return dayStart, weekStart
end

--- The latest `start` or `day` record's numbers and boundaries (TKB-R12), what DayOf, DayStartOf, WeekOfDay and Today
--- count from. The projection's `state.boundary` is one (it also carries the record's `seq`).
---@class TackleBoundary
---@field day integer
---@field week integer
---@field dayStart integer
---@field weekStart integer

--- `floor(x + 0.5)` (TKB-R12's round).
---@param x number
---@return integer
local function round(x)
	return math.floor(x + 0.5)
end

--- The day and week a `start` or `day` record with these boundaries gets (TKB-R12): 0 and 0 for the `start` record
--- (`previous` nil); for a `day` record, the previous boundary record's plus the whole days and weeks its boundaries
--- moved, rounded, never lower than the previous record's (a clock step back or a switch to or from the fallback can't
--- number backwards).
---@param previous TackleBoundary? the latest earlier `start` or `day` record; nil for the `start` record
---@param dayStart integer
---@param weekStart integer
---@return { day: integer, week: integer }
function ns.NumberBoundary(previous, dayStart, weekStart)
	if not previous then
		return { day = 0, week = 0 }
	end
	local days = round((dayStart - previous.dayStart) / ns.DAY_SECONDS)
	local weeks = round((weekStart - previous.weekStart) / ns.WEEK_SECONDS)
	return { day = previous.day + math.max(0, days), week = previous.week + math.max(0, weeks) }
end

--- The board day of an entry at server time `t` (TKB-R12), counted from `boundary`, the latest `start` or `day` record
--- with a lower `seq` than the entry; nil for an entry before the `start` record (no boundary). A `start` or `day`
--- record's own day is the number NumberBoundary gave it, not this.
---@param boundary TackleBoundary?
---@param t integer
---@return integer?
function ns.DayOf(boundary, t)
	if not boundary then
		return nil
	end
	return boundary.day + math.floor((t - boundary.dayStart) / ns.DAY_SECONDS)
end

--- The server time board day `k` starts at, counted from `boundary` (TKB-R12).
---@param boundary TackleBoundary
---@param k integer
---@return integer
function ns.DayStartOf(boundary, k)
	return boundary.dayStart + (k - boundary.day) * ns.DAY_SECONDS
end

--- The 12 h slack in WeekOfDay, so a weekly reset that coincides with a daily one isn't missed by seconds (TKB-R12,
--- tackle-board.md › Tunables).
ns.WEEK_SLACK = 43200

--- The board week board day `k` belongs to, counted from `boundary` (TKB-R12): the week its start falls in, with
--- ns.WEEK_SLACK.
---@param boundary TackleBoundary
---@param k integer
---@return integer
function ns.WeekOfDay(boundary, k)
	local since = ns.DayStartOf(boundary, k) - boundary.weekStart + ns.WEEK_SLACK
	return boundary.week + math.floor(since / ns.WEEK_SECONDS)
end

--- Today's board day, live (TKB-R12): the number a `day` record written now would get against `boundary`, the latest
--- `start` or `day` record, so never below its day. Nil before the `start` record (no boundary).
---@param boundary TackleBoundary?
---@param api TackleResetAPI
---@return integer?
function ns.Today(boundary, api)
	if not boundary then
		return nil
	end
	return ns.NumberBoundary(boundary, ns.LiveBoundaries(api)).day
end

--- The reset timer's delay past the reset, in seconds (TKB-R13, tackle-board.md › Tunables).
ns.RESET_TIMER_DELAY = 2

--- The seconds to arm the reset timer for (TKB-R13 step 4): to the next daily reset, from the daily call or else the
--- next realm midnight (TKB-R11), plus ns.RESET_TIMER_DELAY.
---@param api TackleResetAPI
---@return integer
function ns.SecondsToNextReset(api)
	local daily = secondsUntil(api, "GetSecondsUntilDailyReset")
	if not daily then
		local now = api.GetServerTime()
		daily = realmMidnight(api, now) + ns.DAY_SECONDS - now
	end
	return daily + ns.RESET_TIMER_DELAY
end
