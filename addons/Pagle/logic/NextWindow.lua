---@class PagleNS
local ns = select(2, ...)

-- Window forecasts (LOG-R50): when a condition spec's time-based fields next hold. Pure logic: the realm's UTC
-- offset, the events the live calendar shows active and the weekly rules are all passed in (CORE-R7).

--- What `Pagle.NextWindow` returns (LOG-R50), as catch-log.md › Contracts has it. Times are server times.
---@class Window
---@field openNow? boolean
---@field opensAt? integer
---@field closesAt? integer
---@field always? boolean
---@field onDemand? boolean
---@field confirmed boolean

local SECONDS_PER_DAY = 86400
local MINUTES_PER_DAY = 1440
local HORIZON_DAYS = 400 -- Tunables: the NextWindow horizon (LOG-R50)

-- A span [from, to) of realm seconds: a server time plus the realm's UTC offset, so a realm day starts at a
-- multiple of a day.
---@alias PagleSpan { [1]: number, [2]: number }

-- Spans clipped to [from, to), in order, with overlapping or touching ones merged into one (LOG-R50): a night
-- written as two ranges meeting at midnight is one opening.
---@param spans PagleSpan[]
---@param from integer
---@param to integer
---@return PagleSpan[]
local function normalize(spans, from, to)
	local clipped = {}
	for _, span in ipairs(spans) do
		local opens, closes = math.max(span[1], from), math.min(span[2], to)
		if opens < closes then
			clipped[#clipped + 1] = { opens, closes }
		end
	end
	table.sort(clipped, function(a, b)
		return a[1] < b[1]
	end)
	local merged = {}
	for _, span in ipairs(clipped) do
		local last = merged[#merged]
		if last and span[1] <= last[2] then
			last[2] = math.max(last[2], span[2])
		else
			merged[#merged + 1] = span
		end
	end
	return merged
end

-- Where two normalized span lists both hold, normalized (fields combine with AND, LOG-R48).
---@param a PagleSpan[]
---@param b PagleSpan[]
---@return PagleSpan[]
local function intersect(a, b)
	local both, i, j = {}, 1, 1
	while i <= #a and j <= #b do
		local opens, closes = math.max(a[i][1], b[j][1]), math.min(a[i][2], b[j][2])
		if opens < closes then
			both[#both + 1] = { opens, closes }
		end
		if a[i][2] < b[j][2] then
			i = i + 1
		else
			j = j + 1
		end
	end
	return both
end

---@param list integer[]?
---@param value integer
---@return boolean
local function listHas(list, value)
	for _, item in ipairs(list or {}) do
		if item == value then
			return true
		end
	end
	return false
end

--- What one forecast walks over: realm days, their dates and the instant it starts from.
---@class PagleForecastRange
---@field from integer realm second of fromTime
---@field firstDay integer realm day of fromTime, in days since 1970-01-01
---@field lastDay integer realm day the horizon ends in
---@field dateOf fun(day: integer): { year: integer, month: integer, day: integer, weekday: integer }

-- The spans of each time-based field (LOG-R48) over the forecast's days. The values within a field combine with OR.
---@type table<string, fun(values: any, range: PagleForecastRange, context: table): PagleSpan[]>
local spansOf = {
	-- Realm minutes of day, from inclusive, to exclusive; a range wrapping midnight is its two parts in each day.
	time = function(ranges, range)
		local spans = {}
		for day = range.firstDay, range.lastDay do
			local midnight = day * SECONDS_PER_DAY
			for _, minutes in ipairs(ranges) do
				local opens, closes = midnight + minutes[1] * 60, midnight + minutes[2] * 60
				if minutes[1] < minutes[2] then
					spans[#spans + 1] = { opens, closes }
				else
					spans[#spans + 1] = { opens, midnight + SECONDS_PER_DAY }
					spans[#spans + 1] = { midnight, closes }
				end
			end
		end
		return spans
	end,

	-- Whole realm days whose date is in a range, as MatchesConditions reads a date (LOG-R48).
	season = function(ranges, range)
		local spans, season = {}, { season = ranges }
		for day = range.firstDay, range.lastDay do
			---@type table a snapshot with only the date, all season matching reads
			local onDay = { date = range.dateOf(day) }
			if ns.MatchesConditions(season, onDay) then
				spans[#spans + 1] = { day * SECONDS_PER_DAY, (day + 1) * SECONDS_PER_DAY }
			end
		end
		return spans
	end,

	-- Each event's weekly occurrences (LOG-R56), never later calendar days (LOG-R50). The live calendar decides now
	-- alone (LOG-R46): an occurrence under way while the event isn't active doesn't count, and an active event is
	-- open from now, to the end of the occurrence under way or, with none, past the horizon.
	events = function(events, range, context)
		local spans = {}
		for _, eventID in ipairs(events) do
			local active = listHas(context.activeEvents, eventID)
			local rule = context.getEventRule(eventID)
			local underWay = false
			if rule then
				if rule.confirmed == false then
					context.confirmed = false
				end
				-- An occurrence that started this many days back may still be under way.
				local back = math.ceil(rule.duration / MINUTES_PER_DAY)
				for day = range.firstDay - back, range.lastDay do
					if range.dateOf(day).weekday == rule.weekday then
						local opens = day * SECONDS_PER_DAY + rule.start * 60
						local closes = opens + rule.duration * 60
						local isUnderWay = opens <= range.from and range.from < closes
						underWay = underWay or isUnderWay
						if active or not isUnderWay then
							spans[#spans + 1] = { opens, closes }
						end
					end
				end
			end
			if active and not underWay then
				spans[#spans + 1] = { range.from, math.huge }
			end
		end
		return spans
	end,
}

local TIME_FIELDS = { "time", "season", "events" }

--- When a condition spec's time-based fields (`time`, `season`, `events`), intersected, next hold (LOG-R50):
--- `{ openNow = true, closesAt? }` when they all hold at `fromTime`, else `{ opensAt, closesAt? }` for the next
--- opening within 400 days, or nil with none. `closesAt` is left out when the opening doesn't stop within the
--- horizon. A spec with none of them gives `{ onDemand = true }` when it has `auras`, else `{ always = true }`; its
--- `areas`, `auras`, `lure` and `skill` never constrain the forecast. Every result carries `confirmed`: false when
--- the spec's own `confirmed` (a window spec, LOG-R55) or a weekly rule it read is false.
---
--- Realm days are walked, never minutes, at one UTC offset for the whole horizon: across a daylight-saving change
--- an hour-level state can be an hour off. Raises an error in the caller for an invalid spec, as MatchesConditions
--- does (LOG-R48).
---@param spec PagleConditionSpec|PagleWindowSpec
---@param fromTime integer server time to forecast from
---@param offset integer the realm's UTC offset in minutes (`ns.RealmUtcOffset`, LOG-R49)
---@param activeEvents integer[]? the events the live calendar shows active now (LOG-R46); nil while secret
---@param getEventRule fun(eventID: integer): PagleWeeklyRule? an event's weekly rule (LOG-R56)
---@return Window?
function ns.NextWindow(spec, fromTime, offset, activeEvents, getEventRule)
	-- Matching against an empty snapshot checks the spec and matches nothing (LOG-R48).
	---@type table
	local nothing = {}
	local valid, problem = pcall(ns.MatchesConditions, spec, nothing)
	if not valid then
		error(problem, 2)
	end
	local confirmed = spec.confirmed ~= false
	if spec.time == nil and spec.season == nil and spec.events == nil then
		if spec.auras ~= nil then
			return { onDemand = true, confirmed = confirmed }
		end
		return { always = true, confirmed = confirmed }
	end

	local shift = offset * 60
	local from = fromTime + shift
	local horizon = from + HORIZON_DAYS * SECONDS_PER_DAY
	local dates = {}
	---@type PagleForecastRange
	local range = {
		from = from,
		firstDay = math.floor(from / SECONDS_PER_DAY),
		lastDay = math.floor((horizon - 1) / SECONDS_PER_DAY),
		-- Noon of a realm day, as a server time, with its realm minute: RealmDate reads that day back (LOG-R49).
		dateOf = function(day)
			dates[day] = dates[day] or ns.RealmDate(day * SECONDS_PER_DAY + SECONDS_PER_DAY / 2 - shift, 720)
			return dates[day]
		end,
	}
	local context = { activeEvents = activeEvents, getEventRule = getEventRule, confirmed = confirmed }

	local open
	for _, field in ipairs(TIME_FIELDS) do
		if spec[field] ~= nil then
			local spans = normalize(spansOf[field](spec[field], range, context), from, horizon)
			open = open and intersect(open, spans) or spans
		end
	end

	local first = open[1]
	if first == nil then
		return nil
	end
	local window = { confirmed = context.confirmed }
	if first[1] == from then
		window.openNow = true
	else
		window.opensAt = first[1] - shift
	end
	if first[2] < horizon then
		window.closesAt = first[2] - shift
	end
	return window
end
