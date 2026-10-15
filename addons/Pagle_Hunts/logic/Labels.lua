if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Labels in realm time (HNT-R50–R55): every piece of text Hunts derives for a Hunt. Pure logic (CORE-R7): each
-- function takes its case's inputs (a row's group, aura up, NextWindow result and skill, the time now and one live
-- snapshot), and the names it needs come from a HuntNameSources table, which adapter/Names.lua builds as ns.names.
-- Hunts shares no code with the Ledger (ADR 0001), so its date arithmetic is its own: ns.CivilFromDays
-- (logic/Titles.lua) and daysFromCivil here.

local MINUTES_PER_DAY = 1440
local SECONDS_PER_DAY = 86400

--- A realm date, as a snapshot's `date` (LOG-R45): weekday 1 is Sunday.
---@class HuntRealmDate
---@field year integer
---@field month integer
---@field day integer
---@field weekday integer

--- A realm clock: the minute of day and the realm date (HNT-R50).
---@class HuntRealmClock
---@field minute integer
---@field date HuntRealmDate

-- Days since 1970-01-01 of a proleptic Gregorian date (Howard Hinnant's days_from_civil).
---@param year integer
---@param month integer
---@param day integer
---@return integer
local function daysFromCivil(year, month, day)
	year = month <= 2 and year - 1 or year
	local era = math.floor(year / 400)
	local yearOfEra = year - era * 400
	local monthFromMarch = month > 2 and month - 3 or month + 9
	local dayOfYear = math.floor((153 * monthFromMarch + 2) / 5) + day - 1
	local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

--- The realm clock at server time `t`, from one live snapshot (HNT-R50): minute of day `(minute + floor((t - time)
--- / 60)) mod 1440`, and the snapshot's date moved by the whole days that adds. With no realm minute or date (a
--- secret clock), UTC's.
---@param t integer server time
---@param snapshot { time: integer, minute: integer?, date: HuntRealmDate? } `Pagle.GetConditions()`
---@return HuntRealmClock
function ns.RealmClockAt(t, snapshot)
	local date = snapshot.date
	if snapshot.minute == nil or date == nil then
		return {
			minute = math.floor(t / 60) % MINUTES_PER_DAY,
			date = ns.CivilFromDays(math.floor(t / SECONDS_PER_DAY)),
		}
	end
	local total = snapshot.minute + math.floor((t - snapshot.time) / 60)
	local days = math.floor(total / MINUTES_PER_DAY)
	return {
		minute = total % MINUTES_PER_DAY,
		date = ns.CivilFromDays(daysFromCivil(date.year, date.month, date.day) + days),
	}
end

--- A duration rounded down to the minute (HNT-R50): under an hour "37m"; under a day "2h" or "2h 10m"; from a day
--- "1d" or "1d 4h", the minutes dropped. A negative one reads as none.
---@param seconds number
---@return string
function ns.FormatDuration(seconds)
	local L = ns.L
	local minutes = math.max(0, math.floor(seconds / 60))
	if minutes < 60 then
		return L.DURATION_MINUTES:format(minutes)
	elseif minutes < MINUTES_PER_DAY then
		local hours, rest = math.floor(minutes / 60), minutes % 60
		return rest == 0 and L.DURATION_HOURS:format(hours) or L.DURATION_HOURS_MINUTES:format(hours, rest)
	end
	local days, hours = math.floor(minutes / MINUTES_PER_DAY), math.floor(minutes % MINUTES_PER_DAY / 60)
	return hours == 0 and L.DURATION_DAYS:format(days) or L.DURATION_DAYS_HOURS:format(days, hours)
end

--- A count in its singular or plural string, `L[key .. "_ONE"]` or `L[key .. "_OTHER"]`, with its number written by
--- `format` (tostring by default): "1 title", "3 Hunts completed".
---@param n integer
---@param key string
---@param format (fun(n: integer): string)?
---@return string
function ns.CountText(n, key, format)
	return ns.L[key .. (n == 1 and "_ONE" or "_OTHER")]:format((format or tostring)(n))
end

--- A minute of day as a 24-hour clock time, "06:00" (HNT-R50).
---@param minute integer
---@return string
function ns.FormatClock(minute)
	return ns.L.CLOCK:format(math.floor(minute / 60), minute % 60)
end

--- A date's weekday, "Sun" (HNT-R50).
---@param date HuntRealmDate
---@return string
function ns.FormatWeekday(date)
	return ns.L.WEEKDAYS_SHORT[date.weekday]
end

--- A short date, "12 Oct" (HNT-R50).
---@param date { month: integer, day: integer }
---@return string
function ns.FormatShortDate(date)
	return ns.L.DATE_SHORT:format(date.day, ns.L.MONTHS_SHORT[date.month])
end

--- A full date, "12 Oct 2026" (HNT-R50): seals, the nameplate's tooltip, a retired entry.
---@param date { year: integer, month: integer, day: integer }
---@return string
function ns.FormatFullDate(date)
	return ns.L.DATE_FULL:format(ns.FormatShortDate(date), date.year)
end

--- A month's name, "March" (HNT-R50).
---@param month integer 1–12
---@return string
function ns.MonthName(month)
	return ns.L.MONTHS[month]
end

-- Whether two realm dates are the same day.
---@param a HuntRealmDate
---@param b HuntRealmDate
---@return boolean
local function sameDate(a, b)
	return a.year == b.year and a.month == b.month and a.day == b.day
end

--- Whether server time `t` falls on today's realm date, today being `now`'s (HNT-R50: "same realm day").
---@param t integer
---@param now integer
---@param snapshot table `Pagle.GetConditions()`
---@return boolean
function ns.IsSameRealmDay(t, now, snapshot)
	return sameDate(ns.RealmClockAt(t, snapshot).date, ns.RealmClockAt(now, snapshot).date)
end

--- Server time `t` as a realm clock time: "06:00" on the same realm day as `now`, else "Sun 16:00" (HNT-R51,
--- HNT-R52).
---@param t integer
---@param now integer
---@param snapshot table `Pagle.GetConditions()`
---@return string
function ns.FormatRealmWhen(t, now, snapshot)
	local clock = ns.RealmClockAt(t, snapshot)
	local time = ns.FormatClock(clock.minute)
	if sameDate(clock.date, ns.RealmClockAt(now, snapshot).date) then
		return time
	end
	return ns.L.WEEKDAY_CLOCK:format(ns.FormatWeekday(clock.date), time)
end

-- Tunables: the month wording beyond (HNT-R51). The Soon horizon (HNT-R40) and the lure reach (HNT-R33) are the
-- grouping's (ns.SOON_HORIZON, ns.LURE_REACH): a row's case carries its verdicts.
local MONTH_WORDING_BEYOND = 7 * SECONDS_PER_DAY

--- A row's case, as the label functions take it: the grouping's verdicts on the row (HNT-R40's group and aura up,
--- HNT-R33's short of skill and lure reach), its window, and the skill numbers the window line says. Built by
--- ns.LabelCase.
---@class HuntLabelCase
---@field group HuntGroup HNT-R40's group
---@field auraUp boolean? Now through an aura (HNT-R40's "aura up"); short of skill, it would be (HNT-R52)
---@field window Window? `Pagle.NextWindow(boardSpec, now)`; nil with none or no board spec
---@field spec table? the board spec (HNT-R6), for its auras
---@field short boolean? short of skill (HNT-R33), as the grouping found it
---@field lureGetsThere boolean? short by at most the lure reach (HNT-R33)
---@field need integer? the skill need (HNT-R32), nil with none
---@field best integer? the Angler's `bestBaseSkill` (HNT-R33), for the window line's "my best is"
---@field now integer server time now
---@field snapshot table one live `Pagle.GetConditions()` (HNT-R50)

--- A grouping row's label case (HNT-R51, HNT-R52): every view's labels read the row the same way.
---@param row HuntRow
---@param where HuntWhere the row's Hunt's (ns.where[row.id])
---@param now integer server time the labels count from
---@param snapshot table one live `Pagle.GetConditions()`
---@param best integer? the Angler's `bestBaseSkill`, for the window line; the margin and tracker labels don't read it
---@return HuntLabelCase
function ns.LabelCase(row, where, now, snapshot, best)
	return {
		group = row.group,
		auraUp = row.auraUp,
		window = row.window,
		spec = where.boardSpec,
		short = row.short,
		lureGetsThere = row.lureGetsThere,
		need = where.skillNeed,
		best = best,
		now = now,
		snapshot = snapshot,
	}
end

--- The names the labels read, each nil while the client hasn't given it: adapter/Names.lua builds them (ns.names).
---@class HuntNameSources
---@field ItemName fun(itemID: integer): string?            -- loaded with Item:CreateFromItemID (HNT-R54)
---@field ItemIcon fun(itemID: integer): integer|string|nil -- C_Item.GetItemIconByID (HNT-R55)
---@field AreaName fun(areaID: integer): string?            -- C_Map.GetAreaInfo (HNT-R53)
---@field AuraName fun(spellID: integer): string?           -- C_Spell.GetSpellName (HNT-R52, HNT-R53)
---@field EventName fun(eventID: integer): string|false|nil -- the calendar's; false when not found, nil before (HNT-R53)
---@field BandName fun(band: integer): string?              -- Pagle.SIZE_BANDS[band].name (HNT-R54)
---@field QualityColor fun(quality: integer): number[]?     -- ITEM_QUALITY_COLORS[quality] as { r, g, b } (HNT-R55)
---@field NextWindow fun(spec: table, fromTime: integer): Window? -- Pagle.NextWindow (HNT-R53)

-- The group a short-of-skill row would have without its skill (HNT-R40's rules 2–6), for the window line, which
-- ignores skill (HNT-R52).
---@param c HuntLabelCase
---@return HuntGroup
local function groupIgnoringSkill(c)
	if c.window == nil then
		return "later"
	end
	return (ns.WindowGroup(c.spec or {}, c.window, c.auraUp == true, c.now))
end

-- A case's row of HNT-R51's table (HNT-R52's when `ignoreSkill`): "short", "auraUp", "onDemand", "always",
-- "whileEvent", "closes" (within 7 days), "closesLater", "soon", "opens" (within 7 days), "opensLater" or "noDate".
---@param c HuntLabelCase
---@param ignoreSkill boolean
---@return string
local function rowOf(c, ignoreSkill)
	local group = c.group
	if c.short then
		if not ignoreSkill then
			return "short"
		end
		group = groupIgnoringSkill(c)
	end
	local window = c.window
	if group == "now" and c.auraUp then
		return "auraUp"
	elseif group == "onDemand" then
		return "onDemand"
	elseif group == "now" then
		if window and window.always then
			return "always"
		elseif not (window and window.closesAt) then
			return "whileEvent"
		end
		return window.closesAt - c.now <= MONTH_WORDING_BEYOND and "closes" or "closesLater"
	elseif group == "soon" then
		return "soon"
	elseif not (window and window.opensAt) then
		return "noDate"
	end
	return window.opensAt - c.now <= MONTH_WORDING_BEYOND and "opens" or "opensLater"
end

-- The realm month of server time `t`, "September".
---@param t integer
---@param c HuntLabelCase
---@return string
local function monthOf(t, c)
	return ns.MonthName(ns.RealmClockAt(t, c.snapshot).date.month)
end

--- A current Hunt's margin label (the board) and tracker label (HNT-R51), by the row its case falls in.
---@param c HuntLabelCase
---@return string margin
---@return string tracker
function ns.HuntLabels(c)
	local L = ns.L
	local row, window = rowOf(c, false), c.window or {}
	if row == "short" then
		return L.LABEL_NEED:format(c.need), L.TRACKER_NEED:format(c.need)
	elseif row == "auraUp" then
		return L.LABEL_UP_NOW, L.LABEL_UP_NOW
	elseif row == "onDemand" then
		return L.LABEL_ON_DEMAND, L.LABEL_ON_DEMAND
	elseif row == "always" then
		return L.LABEL_ANY_TIME, L.LABEL_ANY_TIME
	elseif row == "whileEvent" then
		return L.LABEL_WHILE_EVENT, L.TRACKER_NOW
	elseif row == "closes" then
		return L.LABEL_UNTIL:format(ns.FormatRealmWhen(window.closesAt, c.now, c.snapshot)),
			L.TRACKER_ENDS_IN:format(ns.FormatDuration(window.closesAt - c.now))
	elseif row == "closesLater" then
		local label = L.LABEL_UNTIL:format(monthOf(window.closesAt, c))
		return label, label
	elseif row == "soon" then
		local label = L.LABEL_IN:format(ns.FormatDuration(window.opensAt - c.now))
		return label, label
	elseif row == "opens" then
		local label = ns.FormatRealmWhen(window.opensAt, c.now, c.snapshot)
		return label, label
	elseif row == "opensLater" then
		local label = L.LABEL_BACK_IN:format(monthOf(window.opensAt, c))
		return label, label
	end
	return L.LABEL_NO_DATE, L.LABEL_NO_DATE
end

--- The selected Hunt's window line (HNT-R52): its case's row ignoring skill, then, when short of skill, "Needs 225;
--- my best is 180." and, within the lure reach, "A lure gets me there.", one sentence after another.
---@param c HuntLabelCase
---@param sources HuntNameSources for the first aura's name
---@return string
function ns.HuntWindowLine(c, sources)
	local L = ns.L
	local row, window = rowOf(c, true), c.window or {}
	local line
	if row == "auraUp" then
		line = L.LINE_UP_NOW
	elseif row == "onDemand" then
		local aura = c.spec and c.spec.auras and c.spec.auras[1]
		line = L.LINE_ON_DEMAND:format(aura and sources.AuraName(aura) or L.NAME_UNKNOWN)
	elseif row == "always" then
		line = L.LINE_ANY_TIME
	elseif row == "whileEvent" then
		line = L.LINE_WHILE_EVENT
	elseif row == "closes" then
		line = L.LINE_CLOSES:format(
			ns.FormatDuration(window.closesAt - c.now),
			ns.FormatRealmWhen(window.closesAt, c.now, c.snapshot)
		)
	elseif row == "closesLater" then
		line = L.LINE_UNTIL:format(monthOf(window.closesAt, c))
	elseif row == "soon" then
		line = L.LINE_SOON:format(
			ns.FormatDuration(window.opensAt - c.now),
			ns.FormatRealmWhen(window.opensAt, c.now, c.snapshot)
		)
	elseif row == "opens" then
		local sameDay = ns.IsSameRealmDay(window.opensAt, c.now, c.snapshot)
		line = (sameDay and L.LINE_OPENS_AT or L.LINE_OPENS_ON):format(
			ns.FormatRealmWhen(window.opensAt, c.now, c.snapshot)
		)
	elseif row == "opensLater" then
		line = L.LINE_BACK:format(monthOf(window.opensAt, c))
	else
		line = L.LINE_NO_DATE
	end
	if c.short then
		line = line .. " " .. L.LINE_NEEDS:format(c.need, c.best or 0)
		if c.lureGetsThere then
			line = line .. " " .. L.LINE_LURE
		end
	end
	return line
end

-- The windows whose name the conditions line says (HNT-R53): night and day for `time`, the seasons for `season`.
local TIME_WINDOWS = { night = "CONDITION_NIGHT", day = "CONDITION_DAY" }

-- A day of the year, "20 Mar", from a season range's `{ month, day }`.
---@param monthDay integer[]
---@return string
local function dayOfYear(monthDay)
	return ns.FormatShortDate({ month = monthDay[1], day = monthDay[2] })
end

-- Each value of a list, turned into text by `text`, joined by `separator`.
---@param values table
---@param text fun(value: any): string
---@param separator string
---@return string
local function joined(values, text, separator)
	local parts = {}
	for i, value in ipairs(values) do
		parts[i] = text(value)
	end
	return table.concat(parts, separator)
end

-- An event's words (HNT-R53): its name ("…" before the calendar is read, "a calendar event" when it doesn't list
-- it), then "Sundays 14:00 for 2h" from its next forecast opening: from now, or from its closesAt while it is open.
-- With no forecast, the name alone.
---@param eventID integer
---@param now integer
---@param snapshot table
---@param sources HuntNameSources
---@return string
local function eventText(eventID, now, snapshot, sources)
	local L = ns.L
	local name = sources.EventName(eventID)
	if name == nil then
		name = L.NAME_UNKNOWN
	elseif name == false then
		name = L.EVENT_UNKNOWN
	end
	local spec = { events = { eventID } }
	local window = sources.NextWindow(spec, now)
	if window and window.openNow then
		window = window.closesAt and sources.NextWindow(spec, window.closesAt)
	end
	if not (window and window.opensAt and window.closesAt) then
		return name
	end
	local opens = ns.RealmClockAt(window.opensAt, snapshot)
	return L.CONDITION_EVENT:format(
		name,
		L.WEEKDAYS_PLURAL[opens.date.weekday],
		ns.FormatClock(opens.minute),
		ns.FormatDuration(window.closesAt - window.opensAt)
	)
end

--- A board spec's conditions line (HNT-R53): its fields in plain words, in the order time, season, events, areas,
--- auras, lure, skill, joined by " · "; values within a field joined by ", " for ranges and " or " for areas,
--- events and auras. Time is "Night"/"Day" by the window ID (never by comparing specs), else "Realm time"; a named
--- season window's season names its ranges. Nil for a Hunt without a board spec (HNT-R7).
---@param spec table? the board spec (HNT-R6)
---@param windowID string? a natural Hunt's window ID; nil for an imposed Hunt's conditions
---@param now integer
---@param snapshot table one live `Pagle.GetConditions()`
---@param sources HuntNameSources
---@return string?
function ns.HuntConditionsLine(spec, windowID, now, snapshot, sources)
	if spec == nil then
		return nil
	end
	local L = ns.L
	local parts = {}
	if spec.time then
		local ranges = joined(spec.time, function(range)
			return L.TIME_RANGE:format(ns.FormatClock(range[1]), ns.FormatClock(range[2]))
		end, L.JOIN_RANGES)
		parts[#parts + 1] = L[TIME_WINDOWS[windowID] or "CONDITION_TIME"]:format(ranges)
	end
	if spec.season then
		local ranges = joined(spec.season, function(range)
			return L.SEASON_RANGE:format(dayOfYear(range.from), dayOfYear(range.to))
		end, L.JOIN_RANGES)
		local season = windowID and L.SEASONS[windowID]
		parts[#parts + 1] = season and L.CONDITION_SEASON:format(season, ranges) or ranges
	end
	if spec.events then
		parts[#parts + 1] = joined(spec.events, function(eventID)
			return eventText(eventID, now, snapshot, sources)
		end, L.JOIN_OR)
	end
	if spec.areas then
		parts[#parts + 1] = L.CONDITION_AREAS:format(joined(spec.areas, function(areaID)
			return sources.AreaName(areaID) or L.NAME_UNKNOWN
		end, L.JOIN_OR))
	end
	if spec.auras then
		parts[#parts + 1] = L.CONDITION_AURAS:format(joined(spec.auras, function(spellID)
			return sources.AuraName(spellID) or L.NAME_UNKNOWN
		end, L.JOIN_OR))
	end
	if spec.lure then
		parts[#parts + 1] = L.CONDITION_LURE
	end
	if spec.skill then
		parts[#parts + 1] = L.CONDITION_SKILL:format(spec.skill.min)
	end
	return table.concat(parts, L.JOIN_FIELDS)
end

-- The generated classes' target lines and icon tints (HNT-R54, HNT-R55; DATA-R91): the qualities of
-- ITEM_QUALITY_COLORS, none for any fish.
local GENERATED = {
	["quality.uncommon"] = { text = "TARGET_UNCOMMON", quality = 2 },
	["quality.rare"] = { text = "TARGET_RARE", quality = 3 },
	["species.any"] = { text = "TARGET_ANY" },
}
--- The generic fish icon (HNT-R55): a generated class's, and a Hunt moment's with no Catch.
ns.TRADE_FISHING = "Interface\\Icons\\Trade_Fishing"
local TRADE_FISHING = ns.TRADE_FISHING

-- A fixed class's members in ascending item ID order: the list holds them as a set (DATA-R93), and the target line
-- and the icon need one order ("first member", HNT-R55).
---@param hunt HuntDef
---@param list HuntList
---@return integer[]
local function membersOf(hunt, list)
	local members = {}
	for itemID in pairs(list:Class(hunt.class) or {}) do
		members[#members + 1] = itemID
	end
	table.sort(members)
	return members
end

--- A Hunt's target line (HNT-R54): a `species` target's item name; a fixed class's member names joined with " or ";
--- a generated class's words. A name not loaded yet reads "…". A `minBand` adds ", {band name} or better".
---@param hunt HuntDef
---@param list HuntList for a fixed class's members
---@param sources HuntNameSources
---@return string
function ns.HuntTargetLine(hunt, list, sources)
	local L = ns.L
	local function itemName(itemID)
		return sources.ItemName(itemID) or L.NAME_UNKNOWN
	end
	local line
	if hunt.species then
		line = itemName(hunt.species)
	elseif GENERATED[hunt.class] then
		line = L[GENERATED[hunt.class].text]
	else
		line = joined(membersOf(hunt, list), itemName, L.JOIN_OR)
	end
	if hunt.minBand then
		line = L.TARGET_MIN_BAND:format(line, sources.BandName(hunt.minBand) or L.NAME_UNKNOWN)
	end
	return line
end

--- A Hunt's icon and its tint (HNT-R55): a `species` target's item icon; a fixed class's first member's; a generated
--- class's Trade_Fishing, tinted with ITEM_QUALITY_COLORS[2] for `quality.uncommon` and [3] for `quality.rare`.
--- The board's sepia tint on item icons is the board's (adapter/BoardWidgets.lua).
---@param hunt HuntDef
---@param list HuntList for a fixed class's members
---@param sources HuntNameSources
---@return integer|string? icon
---@return number[]? tint { r, g, b }, as the board's tints; nil for none
function ns.HuntIcon(hunt, list, sources)
	if hunt.species then
		return sources.ItemIcon(hunt.species)
	end
	local generated = GENERATED[hunt.class]
	if generated then
		if generated.quality then
			return TRADE_FISHING, sources.QualityColor(generated.quality)
		end
		return TRADE_FISHING
	end
	local first = membersOf(hunt, list)[1]
	if first then
		return sources.ItemIcon(first)
	end
	return TRADE_FISHING
end

--- The calendar event IDs Hunts' specs name, as a set (HNT-R53's lookup): an imposed Hunt's `conditions.events`
--- and a natural Hunt's window spec's.
---@param hunts HuntDef[]
---@param windowSpec fun(windowID: string): table? Pagle.GetWindowSpec
---@return table<integer, true>
function ns.HuntEventIDs(hunts, windowSpec)
	local ids = {}
	for _, hunt in ipairs(hunts) do
		local spec = hunt.conditions or (hunt.window and windowSpec(hunt.window))
		for _, eventID in ipairs(spec and spec.events or {}) do
			ids[eventID] = true
		end
	end
	return ids
end

--- A Hunt moment's icon (HNT-R55, HNT-R86): the qualifying Catch's item ID, or Trade_Fishing untinted with none.
---@param itemID integer?
---@return integer|string
function ns.HuntMomentIcon(itemID)
	return itemID or TRADE_FISHING
end
