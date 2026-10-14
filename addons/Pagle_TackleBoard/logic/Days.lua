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

--- The latest realm midnight before or at server time `now` (TKB-R11): `now − realm minute × 60 − now mod 60`, the
--- realm minute (minute of the realm's day) from GetGameTime.
---@param api TackleResetAPI
---@param now integer
---@return integer
local function realmMidnight(api, now)
	local hour, minute = api.GetGameTime()
	return now - (hour * 60 + minute) * 60 - now % 60
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

--- The seconds until the next reset from `call` (C_DateAndTime.GetSecondsUntilDailyReset or …WeeklyReset), or nil
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
