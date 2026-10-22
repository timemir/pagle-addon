if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's words (TKB-R36, TKB-R102, TKB-R105, TKB-R121, TKB-R122): everything the board, the tracker and the
-- moments say about a goal, built at display time from its record. Pure logic: the client's names, the realm clock
-- and Core come through ns.api (logic/Seams.lua › TackleClientAPI), read through ns at call time, never cached.

-- Templates and counts.

--- A template with `{name}` fields filled from `fields`; a field with no value stays as written. The board's one
--- filler: every `{name}` template of ns.L is filled through it (ns.Plural for a count).
---@param template string
---@param fields table<string, any>
---@return string
function ns.Fill(template, fields)
	return (
		template:gsub("{(%w+)}", function(name)
			local value = fields[name]
			return value ~= nil and tostring(value) or nil
		end)
	)
end

--- The form of `forms` for a count: `forms.one` for 1, `forms.other` otherwise; a plain string is both.
---@param forms string|{ one: string, other: string }
---@param n integer
---@return string
local function pick(forms, n)
	if type(forms) == "string" then
		return forms
	end
	return n == 1 and forms.one or forms.other
end

--- A count in words (CORE-R8): `ns.L[key]`'s singular form for 1 and its plural otherwise, with `{n}`
--- filled by `n` and any other field by `fields`. `ns.Plural(1, "CATCHES")` is "1 Catch", `ns.Plural(30, "CATCHES")`
--- "30 Catches".
---@param n integer
---@param key string a key of ns.L holding `{ one = …, other = … }`
---@param fields table<string, any>?
---@return string
function ns.Plural(n, key, fields)
	local values = { n = n }
	for name, value in pairs(fields or {}) do
		values[name] = value
	end
	return ns.Fill(pick(ns.L[key], n), values)
end

-- Names (TKB-R36).

local requested = {} -- items asked of the client and not yet arrived: { [itemID] = true }

--- A zone's name from C_Map.GetAreaInfo, or "Area {id}" when the client has none (TKB-R36): the call is synchronous,
--- so no name arrives later.
---@param areaID integer
---@return string
function ns.ZoneName(areaID)
	return ns.api.AreaName(areaID) or ns.Fill(ns.L.AREA_UNKNOWN, { id = areaID })
end

--- A continent's name (TKB-R36): C_Map.GetMapInfo on its uiMapID (ns.CONTINENT_MAPS), or "Continent {id}" when the
--- client has none.
---@param continent integer the continent's ID, `GetArea().continent`
---@return string
function ns.ContinentName(continent)
	local uiMapID = ns.CONTINENT_MAPS[continent]
	return uiMapID and ns.api.MapName(uiMapID) or ns.Fill(ns.L.CONTINENT_UNKNOWN, { id = continent })
end

--- A Species' name: its representative item's, from C_Item.GetItemNameByID (TKB-R31, TKB-R36). Until the client has
--- it: "…", and the client is asked to load it, once until it arrives (ns.ItemArrived).
---@param itemID integer the representative item
---@return string
function ns.SpeciesName(itemID)
	local name = ns.api.ItemName(itemID)
	if name then
		return name
	end
	if not requested[itemID] then
		requested[itemID] = true
		ns.api.RequestItem(itemID)
	end
	return ns.L.NAME_UNKNOWN
end

--- Asks the client for the name of every open Species goal's representative item (TKB-R36), so the moment of a
--- completion carries it: the projection's done and each live step call it (logic/Moments.lua).
---@param state TackleBoardState
function ns.RequestGoalNames(state)
	for _, goal in pairs(state.goals) do
		if goal.doneDay == nil and goal.kind == "species" then
			ns.SpeciesName(goal.target)
		end
	end
end

--- GET_ITEM_INFO_RECEIVED's `itemID` and `success` (TKB-R36): true when an item a name asked for has arrived, so the
--- views should redraw (`ns.Redraw("names")`). A failed load is forgotten, to be asked again at the next draw, but
--- redraws nothing.
---@param itemID integer
---@param success boolean?
---@return boolean redraw
function ns.ItemArrived(itemID, success)
	if not requested[itemID] then
		return false
	end
	requested[itemID] = nil
	return success == true
end

-- Lore names (TKB-R130): fly patterns and titles read their names from the generated lore (data/Lore.lua), falling
-- back to their IDs while a key has no text.

--- A fly pattern's name (TKB-R130): ns.L's `fly.<id>.name`, or the ID while the lore has none.
---@param id string
---@return string
function ns.FlyName(id)
	return ns.L["fly." .. id .. ".name"] or id
end

--- A title's text (TKB-R130): ns.L's `boardtitle.<id>.text`, or the ID while the lore has none.
---@param id string
---@return string
function ns.TitleName(id)
	return ns.L["boardtitle." .. id .. ".text"] or id
end

-- The kind's label and icon (TKB-R102).

--- A goal kind's label, in small caps on a slip (TKB-R102): its ID capitalised, through ns.L
--- (CORE-R8).
---@param kind TackleGoalKind
---@return string
function ns.KindLabel(kind)
	return ns.L.KINDS[kind]
end

--- Interface\Icons\<name>, an in-client icon texture.
---@param name string
---@return string
local function icon(name)
	return "Interface\\Icons\\" .. name
end

--- One in-client icon per goal kind, for the moments and the slips (TKB-R86, TKB-R102; custom art comes after
--- 1.0). Any can be swapped freely: nothing but the views reads them.
---@type { [TackleGoalKind]: string }
ns.KIND_ICONS = {
	haul = icon("INV_Misc_Fish_02"), -- a fish: Catches in a zone
	variety = icon("INV_Misc_Fish_09"), -- another fish: different Species
	wanderer = icon("INV_Misc_Map_01"), -- a map: zones
	quality = icon("INV_Misc_Gem_Pearl_02"), -- a pearl: uncommon or rare
	collector = icon("INV_Box_02"), -- a chest: junk, containers, Sub-collection items
	lure = icon("INV_Misc_Orb_03"), -- Shiny Bauble: a lure on
	species = icon("Trade_Fishing"), -- the rod: one Species
}

-- Goal text (TKB-R36).

--- The goal's text (TKB-R36), built from its record at display time through ns.L's GOAL_TEXT templates, by type and
--- kind: "30 Catches in Stranglethorn Vale", "Every Species of Feralas", "10 Oily Blackmouth".
---@param goal TackleGoalDef
---@return string
function ns.GoalText(goal)
	-- Every kind that reads its target has one (tackle-board.md › Data).
	local kind, target = goal.kind, goal.target --[[@as integer]]
	local fields = { n = goal.need }
	if kind == "haul" or kind == "variety" then
		fields.zone = ns.ZoneName(target)
	elseif kind == "wanderer" and goal.type == "e" then
		fields.continent = ns.ContinentName(target)
	elseif kind == "quality" then
		fields.quality = ns.L.QUALITY_NAMES[target] or ns.L.NAME_UNKNOWN
	elseif kind == "species" then
		fields.species = ns.SpeciesName(target)
	end
	return ns.Fill(pick(ns.L.GOAL_TEXT[goal.type][kind], goal.need), fields)
end

-- Where a goal is worked (TKB-R41, TKB-R102, TKB-R122).

--- Whether a goal is tied to a place (TKB-R102): `haul`, `variety`, the `wanderer` Expedition and `species`. Such a
--- goal shows "I'm here" on the board and " · here" on the tracker while it is workable here (TKB-R121).
---@param goal TackleGoalDef
---@return boolean
function ns.IsPlaceGoal(goal)
	local kind = goal.kind
	return kind == "haul" or kind == "variety" or kind == "species" or (kind == "wanderer" and goal.type == "e")
end

--- Where a goal can be worked (TKB-R102): its zone (`haul`, `variety`), its continent (`wanderer` Expedition),
--- "wherever it bites" (`species`) or "anywhere" (every other).
---@param goal TackleGoalDef
---@return string
function ns.GoalWhere(goal)
	local kind = goal.kind
	if kind == "haul" or kind == "variety" then
		return ns.ZoneName(goal.target)
	elseif kind == "wanderer" and goal.type == "e" then
		return ns.ContinentName(goal.target)
	elseif kind == "species" then
		return ns.L.WHEREVER_IT_BITES
	end
	return ns.L.ANYWHERE
end

--- The tracker's where line (TKB-R122): "today · " first for a day-bound goal, then where it is worked
--- (ns.GoalWhere), then " · here" for a goal tied to a place when `here`.
---@param goal TackleGoalDef
---@param here boolean whether the goal is workable here (ns.IsWorkableHere)
---@return string
function ns.TrackerWhere(goal, here)
	local where = ns.GoalWhere(goal)
	if ns.IsDayBound(goal) then
		where = ns.Fill(ns.L.WHERE_TODAY, { where = where })
	end
	if here and ns.IsPlaceGoal(goal) then
		where = ns.Fill(ns.L.WHERE_HERE, { where = where })
	end
	return where
end

-- Workable here (TKB-R121).

--- The current zone (TKB-R121): `Pagle.GetConditions().zone`, read afresh at each call, or 0 when there is none (a
--- secret one, CORE-R31). Callers read it again on ConditionsChanged with "area".
---@return integer zoneAreaID
function ns.CurrentZone()
	local conditions = ns.api.pagle.GetConditions()
	return conditions and conditions.zone or 0
end

--- Whether a Species, by a representative item, has a catch entry in a zone's list, gated or not (TKB-R121): any
--- entry whose item is of the same Species (TKB-R31), the zone's subzones included (`GetZoneCatches`).
---@param pagle table Core
---@param itemID integer the representative item
---@param zone integer
---@return boolean
local function speciesListed(pagle, itemID, zone)
	local item = pagle.GetItem(itemID)
	local species = item and item.species
	if not species then
		return false
	end
	for _, entry in ipairs(pagle.GetZoneCatches(zone) or {}) do
		local listed = pagle.GetItem(entry.itemID)
		if listed and listed.species == species then
			return true
		end
	end
	return false
end

--- Whether a goal is workable here (TKB-R121): a `haul` or `variety` goal in its zone; a `wanderer` Expedition in a
--- zone of its continent (`GetArea(zone).continent`); a `species` goal where its Species has a catch entry
--- (`GetZoneCatches(zone)`, gated or not); every other kind always. In zone 0 only the always-workable kinds are.
---@param goal TackleGoalDef
---@param zone integer the current zone's areaID (ns.CurrentZone), or 0
---@return boolean
function ns.IsWorkableHere(goal, zone)
	if not ns.IsPlaceGoal(goal) then
		return true
	end
	if zone == 0 then
		return false
	end
	local kind, pagle = goal.kind, ns.api.pagle
	if kind == "haul" or kind == "variety" then
		return goal.target == zone
	elseif kind == "wanderer" then
		local area = pagle.GetArea(zone)
		return area ~= nil and area.continent == goal.target
	end
	return speciesListed(pagle, goal.target, zone)
end

-- Realm dates and times (TKB-R102, TKB-R105).

local SECONDS_PER_DAY = ns.DAY_SECONDS
local MINUTES_PER_DAY = SECONDS_PER_DAY / 60
-- LOG-R49's offset: rounded to 15 minutes, in the range after −10 h up to and including +14 h.
local OFFSET_STEP, MIN_OFFSET, MAX_OFFSET = 15, -600, 840

--- The realm's UTC offset in minutes, worked out as LOG-R49 does (TKB-R105): the realm minute less the UTC minute of
--- the server time, rounded to 15 minutes, taken after −10 h up to and including +14 h (a difference outside that
--- range wraps by a day into it). The Tackle Board can't call Core's (ADR 0001), so it has its own.
---@param serverTime integer GetServerTime()
---@param realmMinute integer the realm clock's minute of day, 0–1439 (GetGameTime())
---@return integer minutes east of UTC
function ns.RealmOffset(serverTime, realmMinute)
	local utcMinute = math.floor(serverTime / 60) % MINUTES_PER_DAY
	local offset = math.floor((realmMinute - utcMinute) / OFFSET_STEP + 0.5) * OFFSET_STEP
	if offset > MAX_OFFSET then
		offset = offset - MINUTES_PER_DAY
	elseif offset <= MIN_OFFSET then
		offset = offset + MINUTES_PER_DAY
	end
	return offset
end

--- The proleptic Gregorian date of a count of days since 1970-01-01 (Howard Hinnant's civil_from_days).
---@param days integer
---@return integer year, integer month, integer day
local function civilFromDays(days)
	local z = days + 719468
	local era = math.floor(z / 146097)
	local dayOfEra = z - era * 146097
	local yearOfEra = math.floor(
		(dayOfEra - math.floor(dayOfEra / 1460) + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365
	)
	local dayOfYear = dayOfEra - (365 * yearOfEra + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
	local monthFromMarch = math.floor((5 * dayOfYear + 2) / 153)
	local day = dayOfYear - math.floor((153 * monthFromMarch + 2) / 5) + 1
	local month = monthFromMarch < 10 and monthFromMarch + 3 or monthFromMarch - 9
	return yearOfEra + era * 400 + (month <= 2 and 1 or 0), month, day
end

--- A realm date and time (TKB-R105).
---@class TackleRealmDate
---@field year integer
---@field month integer
---@field day integer
---@field weekday integer   -- 1 = Sunday, as the client's calendar counts
---@field hour integer
---@field minute integer

--- A server time on the realm's clock (TKB-R105): converted with the realm's UTC offset worked out live, from the
--- realm clock now and the server time now (ns.RealmOffset over ns.api); UTC's while the realm clock is secret or
--- missing.
---@param serverTime integer
---@return TackleRealmDate
function ns.RealmDate(serverTime)
	local minute = ns.RealmMinute(ns.api)
	local offset = minute and ns.RealmOffset(ns.api.GetServerTime(), minute) or 0
	local realmTime = serverTime + offset * 60
	local days = math.floor(realmTime / SECONDS_PER_DAY)
	local year, month, day = civilFromDays(days)
	local seconds = realmTime - days * SECONDS_PER_DAY
	return {
		year = year,
		month = month,
		day = day,
		weekday = (days + 4) % 7 + 1, -- 1970-01-01 was a Thursday, 5
		hour = math.floor(seconds / 3600),
		minute = math.floor(seconds / 60) % 60,
	}
end

--- The realm weekday of a server time, abbreviated Sun–Sat by ns.L (TKB-R105): an empty Expedition pin's weekly
--- reset day.
---@param serverTime integer
---@return string
function ns.WeekdayName(serverTime)
	return ns.L.WEEKDAYS[ns.RealmDate(serverTime).weekday]
end

--- When a goal was posted, in realm time (TKB-R102): "Posted {weekday} {day} {month}, {hh:mm}", 24-hour.
---@param serverTime integer its record's `time`
---@return string
function ns.PostedTime(serverTime)
	local date = ns.RealmDate(serverTime)
	return ns.Fill(ns.L.POSTED, {
		weekday = ns.L.WEEKDAYS[date.weekday],
		day = date.day,
		month = ns.L.MONTHS[date.month],
		time = string.format("%02d:%02d", date.hour, date.minute),
	})
end

--- A countdown to a reset (TKB-R105): whole hours rounded down ("13h") from one hour up, whole minutes rounded down
--- ("45m") below.
---@param seconds integer seconds left
---@return string
function ns.Countdown(seconds)
	if seconds >= 3600 then
		return ns.Fill(ns.L.HOURS_LEFT, { n = math.floor(seconds / 3600) })
	end
	return ns.Fill(ns.L.MINUTES_LEFT, { n = math.floor(math.max(seconds, 0) / 60) })
end
