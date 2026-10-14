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
-- multiple of a day. `confirmed` is false for an occurrence of an unconfirmed weekly rule (LOG-R56). A merged span
-- keeps as `parts` the spans that made it.
---@alias PagleSpan { [1]: number, [2]: number, confirmed: boolean?, parts: PagleSpan[]? }

-- Spans clipped to [from, to), in order, with overlapping or touching ones merged into one (LOG-R50): a night
-- written as two ranges meeting at midnight is one opening. A span lying inside another adds nothing, so it isn't
-- among the merged span's parts.
---@param spans PagleSpan[]
---@param from integer
---@param to integer
---@return PagleSpan[]
local function normalize(spans, from, to)
	local clipped = {}
	for _, span in ipairs(spans) do
		local opens, closes = math.max(span[1], from), math.min(span[2], to)
		if opens < closes then
			clipped[#clipped + 1] = { opens, closes, confirmed = span.confirmed }
		end
	end
	-- The longer of two spans opening together first, so the shorter lies inside it.
	table.sort(clipped, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] > b[2]
	end)
	local merged = {}
	for _, span in ipairs(clipped) do
		local last = merged[#merged]
		if last and span[1] <= last[2] then
			if span[2] > last[2] then
				last[2] = span[2]
				table.insert(last.parts, span)
			end
		else
			merged[#merged + 1] = { span[1], span[2], parts = { span } }
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

-- Where every field's normalized spans hold, the first such span (fields combine with AND, LOG-R48), or nil.
---@param fields PagleSpan[][]
---@return PagleSpan?
local function firstOpening(fields)
	local open = fields[1]
	for i = 2, #fields do
		open = intersect(open, fields[i])
	end
	return open[1]
end

-- Whether every part of the fields' spans the opening used is confirmed (LOG-R50): the parts overlapping it, of
-- the span in each field it lies in.
---@param fields PagleSpan[][]
---@param opening PagleSpan
---@return boolean
local function usedConfirmed(fields, opening)
	for _, spans in ipairs(fields) do
		for _, span in ipairs(spans) do
			if span[1] <= opening[1] and opening[1] < span[2] then
				for _, part in ipairs(span.parts) do
					if part.confirmed == false and part[1] < opening[2] and opening[1] < part[2] then
						return false
					end
				end
			end
		end
	end
	return true
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
	-- open from now, to the end of the occurrence under way or, with none, past the horizon. ns.NextWindow keeps
	-- that last span only when the forecast is open now.
	events = function(events, range, context)
		local spans = {}
		for _, eventID in ipairs(events) do
			local active = context.activeEvents ~= nil and ns.ListHas(context.activeEvents, eventID)
			local rule = context.getEventRule(eventID)
			local underWay = false
			if rule then
				-- An occurrence that started this many days back may still be under way.
				local back = math.ceil(rule.duration / MINUTES_PER_DAY)
				for day = range.firstDay - back, range.lastDay do
					if range.dateOf(day).weekday == rule.weekday then
						local opens = day * SECONDS_PER_DAY + rule.start * 60
						local closes = opens + rule.duration * 60
						local isUnderWay = opens <= range.from and range.from < closes
						underWay = underWay or isUnderWay
						if active or not isUnderWay then
							spans[#spans + 1] = { opens, closes, confirmed = rule.confirmed }
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

-- Whether a spec has any time-based field, so its forecast needs the realm clock (LOG-R50).
---@param spec PagleConditionSpec
---@return boolean
local function isTimeBased(spec)
	return spec.time ~= nil or spec.season ~= nil or spec.events ~= nil
end

-- Raises "invalid condition spec: …" for an invalid spec in the caller of the function calling it, as
-- MatchesConditions does (LOG-R48): matching against an empty snapshot checks the spec and matches nothing.
---@param spec PagleConditionSpec
local function check(spec)
	---@type table
	local nothing = {}
	local valid, problem = pcall(ns.MatchesConditions, spec, nothing)
	if not valid then
		error(problem, 3)
	end
end

--- When a condition spec's time-based fields (`time`, `season`, `events`), intersected, next hold (LOG-R50):
--- `{ openNow = true, closesAt? }` when they all hold at `fromTime`, else `{ opensAt, closesAt? }` for the next
--- opening within 400 days, or nil with none. `closesAt` is left out when the opening doesn't stop within the
--- horizon. A spec with none of them gives `{ onDemand = true }` when it has `auras`, else `{ always = true }`; its
--- `areas`, `auras`, `lure` and `skill` never constrain the forecast. The live calendar's active events can only
--- make it open now: every later opening comes from the weekly rules. Every result carries `confirmed`: false when
--- the spec's own `confirmed` (a window spec, LOG-R55) is false, or the weekly rule of an occurrence the opening
--- used is unconfirmed.
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
	check(spec)
	local confirmed = spec.confirmed ~= false
	if not isTimeBased(spec) then
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
	local context = { activeEvents = activeEvents, getEventRule = getEventRule }

	local fields = {}
	for _, field in ipairs(TIME_FIELDS) do
		if spec[field] ~= nil then
			fields[#fields + 1] = normalize(spansOf[field](spec[field], range, context), from, horizon)
		end
	end
	local first = firstOpening(fields)
	-- Not open now: the calendar's active events open nothing later, so the events field (last of TIME_FIELDS) is
	-- read again from the weekly rules alone (LOG-R50).
	if first and first[1] ~= from and spec.events ~= nil and activeEvents ~= nil and #activeEvents > 0 then
		context.activeEvents = nil
		fields[#fields] = normalize(spansOf.events(spec.events, range, context), from, horizon)
		first = firstOpening(fields)
	end

	if first == nil then
		return nil
	end
	local window = { confirmed = confirmed and usedConfirmed(fields, first) }
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

--- `Pagle.NextWindow`'s body (LOG-R50), which Core's adapter and FakePagle both call: the forecast from `fromTime` at
--- the realm's UTC offset, read from a conditions snapshot's server time and realm minute (LOG-R49), with the
--- snapshot's events as the ones the live calendar shows active (LOG-R46). While the realm clock is secret (no
--- realm minute, CORE-R31) a spec with `time`, `season` or `events` gives nil, as the offset can't be read; one
--- without them needs no clock and still gets `{ onDemand = true }` or `{ always = true }`. A new table each call.
---@param spec PagleConditionSpec|PagleWindowSpec
---@param fromTime integer server time to forecast from
---@param now ConditionsSnapshot the conditions now: `time`, `minute` and `events` are read
---@param getEventRule fun(eventID: integer): PagleWeeklyRule? an event's weekly rule (LOG-R56)
---@return Window?
function ns.ForecastWindow(spec, fromTime, now, getEventRule)
	if now.time == nil or now.minute == nil then
		if isTimeBased(spec) then
			check(spec)
			return nil
		end
		return ns.NextWindow(spec, fromTime, 0, now.events, getEventRule) -- no time-based field reads the offset
	end
	return ns.NextWindow(spec, fromTime, ns.RealmUtcOffset(now.time, now.minute), now.events, getEventRule)
end
