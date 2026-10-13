---@class PagleNS
local ns = select(2, ...)

-- Condition specs (LOG-R48) and the realm date of a Cast (LOG-R49): pure logic, everything passed in (CORE-R7).

--- What a Cast snapshot (LOG-R20) or a live one (`Pagle.GetConditions()`, LOG-R45) holds. Secret values are nil.
---@class ConditionsSnapshot
---@field time integer           -- server time
---@field minute integer         -- realm minute of day
---@field date { year: integer, month: integer, day: integer, weekday: integer }  -- realm date; derived for Casts (LOG-R49)
---@field uiMap? integer
---@field instance? integer
---@field zone integer           -- 0 if unresolved or secret
---@field subzone integer        -- 0 if none, unresolved or secret
---@field skillRank? integer
---@field skillMod? integer
---@field lure? integer
---@field events integer[]
---@field auras integer[]
---@field restricted? boolean    -- live snapshots only

--- A condition spec (LOG-R48). Fields combine with AND, the values within one with OR; an absent field doesn't
--- constrain. An empty list, or a range with from == to, is invalid.
---@class PagleConditionSpec
---@field areas? integer[]                  -- the zone or subzone is one of them
---@field time? { [1]: integer, [2]: integer }[]  -- { from, to } realm minutes, from inclusive, to exclusive; wraps past midnight when to < from
---@field season? { from: { [1]: integer, [2]: integer }, to: { [1]: integer, [2]: integer } }[]  -- { month, day }s, both inclusive; wraps the year when to < from
---@field events? integer[]                 -- calendar event IDs, any active
---@field auras? integer[]                  -- spell IDs from the catalogue's aura list, any active
---@field lure? true|integer[]              -- any lure, or one of these enchant IDs
---@field skill? { min: integer }           -- effective skill (rank + modifier) at least min

-- Whether a list holds a value. A nil or 0 value (secret or unresolved) is in no list (LOG-R48).
---@param list integer[]
---@param value integer?
---@return boolean
local function listHas(list, value)
	if value == nil or value == 0 then
		return false
	end
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- Whether any of a spec's IDs is in a snapshot's list of active ones. A nil list (secret) meets nothing (LOG-R48).
---@param ids integer[]
---@param active integer[]?
---@return boolean
local function listMeets(ids, active)
	if active == nil then
		return false
	end
	for _, id in ipairs(active) do
		if listHas(ids, id) then
			return true
		end
	end
	return false
end

-- One matcher per spec field (LOG-R48): whether the snapshot meets that field's values, which combine with OR.
---@type table<string, fun(values: any, snapshot: ConditionsSnapshot): boolean>
local matchers = {
	areas = function(areas, s)
		return listHas(areas, s.zone) or listHas(areas, s.subzone)
	end,

	time = function(ranges, s)
		local minute = s.minute
		if minute == nil then
			return false
		end
		for _, range in ipairs(ranges) do
			local from, to = range[1], range[2]
			if from < to then
				if minute >= from and minute < to then
					return true
				end
			elseif minute >= from or minute < to then -- wraps past midnight
				return true
			end
		end
		return false
	end,

	season = function(ranges, s)
		local date = s.date
		if date == nil then
			return false
		end
		-- Month and day as one comparable number: 14 Oct is 1014.
		local today = date.month * 100 + date.day
		for _, range in ipairs(ranges) do
			local from = range.from[1] * 100 + range.from[2]
			local to = range.to[1] * 100 + range.to[2]
			if from < to then
				if today >= from and today <= to then
					return true
				end
			elseif today >= from or today <= to then -- wraps the year
				return true
			end
		end
		return false
	end,

	events = function(events, s)
		return listMeets(events, s.events)
	end,

	auras = function(auras, s)
		return listMeets(auras, s.auras)
	end,

	lure = function(lure, s)
		if lure == true then
			return s.lure ~= nil and s.lure ~= 0
		end
		return listHas(lure, s.lure)
	end,

	-- Effective skill is rank + modifier; with either unknown it can't be told, so it never matches.
	skill = function(skill, s)
		local rank, mod = s.skillRank, s.skillMod
		if rank == nil or rank == 0 or mod == nil then
			return false
		end
		return rank + mod >= skill.min
	end,
}

local DAYS_IN_MONTH = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

---@param value any
---@param min integer
---@param max number
---@return boolean
local function isIntegerIn(value, min, max)
	return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

-- Whether a value is a list: a table whose keys are exactly 1..n.
---@param value any
---@return boolean
local function isList(value)
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	return count == #value
end

---@param id any
---@return boolean
local function isID(id)
	return isIntegerIn(id, 1, math.huge)
end

-- What's wrong with a list field's value, or nil if nothing: it must be a non-empty list whose items pass `isItem`.
---@param field string
---@param values any
---@param isItem fun(item: any): boolean
---@param shape string what the field must be, for the message
---@return string?
local function checkList(field, values, isItem, shape)
	if type(values) == "table" and next(values) == nil then
		return field .. " is an empty list"
	end
	if not isList(values) then
		return field .. " must be " .. shape
	end
	for _, item in ipairs(values) do
		if not isItem(item) then
			return field .. " must be " .. shape
		end
	end
	return nil
end

-- What's wrong with a list of ranges, or nil if nothing: it must be a non-empty list of ranges that pass `isRange`
-- and whose `from` differs from their `to`.
---@param field string
---@param ranges any
---@param isRange fun(range: any): boolean
---@param fromEqualsTo fun(range: table): boolean
---@param shape string what each range must be, for the message
---@return string?
local function checkRanges(field, ranges, isRange, fromEqualsTo, shape)
	local problem = checkList(field, ranges, function()
		return true
	end, "a list of ranges")
	if problem then
		return problem
	end
	for i, range in ipairs(ranges) do
		if not isRange(range) then
			return ("%s[%d] must be %s"):format(field, i, shape)
		end
		if fromEqualsTo(range) then
			return ("%s[%d] has from == to"):format(field, i)
		end
	end
	return nil
end

---@param minute any
---@return boolean
local function isMinuteOfDay(minute)
	return isIntegerIn(minute, 0, 1439)
end

---@param monthDay any
---@return boolean
local function isMonthDay(monthDay)
	return isList(monthDay)
		and #monthDay == 2
		and isIntegerIn(monthDay[1], 1, 12)
		and isIntegerIn(monthDay[2], 1, DAYS_IN_MONTH[monthDay[1]] or 0)
end

-- One checker per spec field (LOG-R48): what's wrong with the field's value, or nil if nothing.
---@type table<string, fun(values: any): string?>
local checkers = {
	areas = function(areas)
		return checkList("areas", areas, isID, "a list of IDs")
	end,

	time = function(ranges)
		return checkRanges("time", ranges, function(range)
			return isList(range) and #range == 2 and isMinuteOfDay(range[1]) and isMinuteOfDay(range[2])
		end, function(range)
			return range[1] == range[2]
		end, "{ from, to } realm minutes of day")
	end,

	season = function(ranges)
		return checkRanges("season", ranges, function(range)
			return type(range) == "table" and isMonthDay(range.from) and isMonthDay(range.to)
		end, function(range)
			return range.from[1] == range.to[1] and range.from[2] == range.to[2]
		end, "{ from = { month, day }, to = { month, day } }")
	end,

	events = function(events)
		return checkList("events", events, isID, "a list of IDs")
	end,

	auras = function(auras)
		return checkList("auras", auras, isID, "a list of IDs")
	end,

	lure = function(lure)
		if lure == true then
			return nil
		end
		return checkList("lure", lure, isID, "true or a list of IDs")
	end,

	skill = function(skill)
		local onlyMin = type(skill) == "table" and next(skill) == "min" and next(skill, "min") == nil
		if not onlyMin or not isIntegerIn(skill.min, 0, math.huge) then
			return "skill must be { min = n }"
		end
		return nil
	end,
}

-- What's wrong with a condition spec, or nil if nothing (LOG-R48).
---@param spec any
---@return string?
local function checkSpec(spec)
	if type(spec) ~= "table" then
		return "it must be a table"
	end
	for field, values in pairs(spec) do
		local checker = checkers[field]
		if not checker then
			return tostring(field) .. " is not a condition field"
		end
		local problem = checker(values)
		if problem then
			return problem
		end
	end
	return nil
end

--- Whether a snapshot meets a condition spec (LOG-R48, LOG-R49). Fields combine with AND, the values within a field
--- with OR, and an absent field doesn't constrain. A nil or 0 snapshot value (secret or unresolved) never matches.
--- Raises an error in the caller for an invalid spec: an empty list, a range with from == to, or a field or value
--- LOG-R48 doesn't define.
---@param spec PagleConditionSpec
---@param snapshot ConditionsSnapshot
---@return boolean
function ns.MatchesConditions(spec, snapshot)
	local problem = checkSpec(spec)
	if problem then
		error("invalid condition spec: " .. problem, 2)
	end
	for field, values in pairs(spec) do
		if not matchers[field](values, snapshot) then
			return false
		end
	end
	return true
end
