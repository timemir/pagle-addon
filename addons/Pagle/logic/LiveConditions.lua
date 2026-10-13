---@class PagleNS
local ns = select(2, ...)

-- The live conditions service (LOG-R45–R47): which calendar events are active, and which ConditionsChanged keys a
-- new reading changed. Pure logic, with what the client gave passed in (CORE-R7).

--- The fields of a C_Calendar day event the activity rule reads (LOG-R46). Times are realm times.
---@class PagleDayEvent
---@field eventID integer
---@field sequenceType string "START", "ONGOING" or "END" on the first, a middle or the last day of a multi-day event; anything else is a single-day event
---@field startTime { hour: integer, minute: integer }
---@field endTime { hour: integer, minute: integer }

-- A CalendarTime's minute of day.
---@param time { hour: integer, minute: integer }
---@return integer
local function minuteOf(time)
	return time.hour * 60 + time.minute
end

-- Whether a day event that today's calendar lists is inside the realm minute (LOG-R46): a multi-day event all of a
-- middle day, from its start time on its first day and until its end time on its last; a single-day event between
-- its start and end times. Start times count, end times don't.
---@param event PagleDayEvent
---@param minute integer
---@return boolean
local function isOn(event, minute)
	local sequence = event.sequenceType
	if sequence == "ONGOING" then
		return true
	elseif sequence == "START" then
		return minute >= minuteOf(event.startTime)
	elseif sequence == "END" then
		return minute < minuteOf(event.endTime)
	end
	return minute >= minuteOf(event.startTime) and minute < minuteOf(event.endTime)
end

--- The events on the catalogue's event list that are active now (LOG-R46), ascending, each once.
---@param dayEvents PagleDayEvent[]? today's C_Calendar day events; nil when the calendar was read while secret, which counts as no events
---@param eventIDs integer[] the catalogue's event list
---@param minute integer? the realm minute of day; nil when unknown, which also counts as no events
---@return integer[]
function ns.ActiveEvents(dayEvents, eventIDs, minute)
	local active = {}
	if dayEvents == nil or minute == nil then
		return active
	end
	local listed, seen = {}, {}
	for _, eventID in ipairs(eventIDs) do
		listed[eventID] = true
	end
	for _, event in ipairs(dayEvents) do
		local eventID = event.eventID
		if listed[eventID] and not seen[eventID] and isOn(event, minute) then
			seen[eventID] = true
			active[#active + 1] = eventID
		end
	end
	table.sort(active)
	return active
end

--- A key of `ConditionsChanged` (LOG-R47).
---@alias PagleConditionKey "area"|"auras"|"lure"|"events"|"skill"

--- The keys of `ConditionsChanged`, in the order a payload lists them, each with the snapshot fields it covers
--- (LOG-R47). Realm time, the date, uiMap, instance and the restriction flag are no key: their passing is no change.
---@type { key: PagleConditionKey, fields: string[] }[]
local KEYS = {
	{ key = "area", fields = { "zone", "subzone" } },
	{ key = "auras", fields = { "auras" } },
	{ key = "lure", fields = { "lure" } },
	{ key = "events", fields = { "events" } },
	{ key = "skill", fields = { "skillRank", "skillMod" } },
}

--- Every key of `ConditionsChanged`, in payload order (LOG-R47).
---@type PagleConditionKey[]
ns.CONDITION_KEYS = {}
for i, entry in ipairs(KEYS) do
	ns.CONDITION_KEYS[i] = entry.key
end

-- Whether two readings of a snapshot field are the same: equal values, or lists with equal items in order.
---@param a any
---@param b any
---@return boolean
local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

--- Remembers the last reading of each `ConditionsChanged` key, to tell which keys a new reading changed (LOG-R47).
---@class PagleConditionsTracker
---@field private last table<PagleConditionKey, table>
local Tracker = {}
Tracker.__index = Tracker

--- Compares `snapshot` with the last reading of each key in `keys` (every key if nil) and keeps it as their last
--- reading. Returns the keys whose fields changed, in payload order. A key's first reading is its baseline and
--- changes nothing.
---@param snapshot table a ConditionsSnapshot, or as much of one as `keys` covers
---@param keys PagleConditionKey[]?
---@return PagleConditionKey[]
function Tracker:Update(snapshot, keys)
	local asked = {}
	for _, key in ipairs(keys or ns.CONDITION_KEYS) do
		asked[key] = true
	end
	local changed = {}
	for _, entry in ipairs(KEYS) do
		local key = entry.key
		if asked[key] then
			local last, now = self.last[key], {}
			local differs = false
			for i, field in ipairs(entry.fields) do
				now[i] = snapshot[field]
				differs = differs or (last ~= nil and not same(last[i], now[i]))
			end
			if differs then
				changed[#changed + 1] = key
			end
			self.last[key] = now
		end
	end
	return changed
end

--- A tracker with no reading yet (LOG-R47).
---@return PagleConditionsTracker
function ns.NewConditionsTracker()
	return setmetatable({ last = {} }, Tracker)
end

--- The C_Calendar month offset of the current month (LOG-R46). Calendar reads take an offset from the month the
--- calendar shows, which the player may have paged away from the current one.
---@param shown { year: integer, month: integer } `C_Calendar.GetMonthInfo(0)`
---@param now { year: integer, month: integer } the current realm date
---@return integer
function ns.CalendarMonthOffset(shown, now)
	return (now.year - shown.year) * 12 + now.month - shown.month
end
