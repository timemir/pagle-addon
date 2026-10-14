if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's words (LED-R126, LED-R127, LED-R161): names, realm dates, window labels and states, and lore. Pure
-- logic, the client's reads passed in (CORE-R7); adapter/JournalText.lua passes them.

local MINUTES_PER_DAY = 1440
local SECONDS_PER_DAY = 86400
-- LOG-R49's offset: rounded to 15 minutes, in the range after −10 h up to and including +14 h.
local OFFSET_STEP, MIN_OFFSET, MAX_OFFSET = 15, -600, 840
local FORECAST_HOURS = 48 -- Tunables: forecast in hours up to (LED-R127)

--- The realm's UTC offset in minutes, worked out live as LOG-R49 does (LED-R126): the realm minute less the UTC
--- minute of the server time, rounded to 15 minutes, taken after −10 h up to and including +14 h. The Ledger can't
--- call Core's ns.RealmDate (ADR 0001), so it has its own.
---@param serverTime integer GetServerTime()
---@param realmMinute integer the realm clock's minute of day, 0–1439 (GetGameTime())
---@return integer minutes
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

--- A realm date: a Cast's `conditions.date` (LOG-R49) or a server time's day at the realm's offset.
---@class LedgerRealmDate
---@field year integer
---@field month integer
---@field day integer

--- The proleptic Gregorian date of a count of days since 1970-01-01 (Howard Hinnant's civil_from_days).
---@param days integer
---@return LedgerRealmDate
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
	return { year = yearOfEra + era * 400 + (month <= 2 and 1 or 0), month = month, day = day }
end

--- The realm date of a server time at the realm's offset (LED-R126, LED-R127).
---@param serverTime integer
---@param offset integer minutes, ns.RealmOffset
---@return LedgerRealmDate
function ns.RealmDateAt(serverTime, offset)
	return civilFromDays(math.floor((serverTime + offset * 60) / SECONDS_PER_DAY))
end

--- A realm date as the Journal prints it (LED-R126): "{day} {month abbreviation}", with the year added when it isn't
--- `currentYear`; "…" with no date (a Cast stored without a realm minute).
---@param date LedgerRealmDate?
---@param currentYear integer the current realm year
---@return string
function ns.FormatJournalDate(date, currentYear)
	local L = ns.L
	if not date then
		return L.NAME_UNKNOWN
	end
	local short = L.DATE_SHORT:format(date.day, L.MONTHS_SHORT[date.month])
	if date.year == currentYear then
		return short
	end
	return L.DATE_WITH_YEAR:format(short, date.year)
end

--- A window's label (LED-R127): `day`, `night`, the seasons, `event.301` "Extravaganza", any other `event.<id>`
--- "event"; "…" for an ID that is none of these (LED-R126).
---@param windowID string
---@return string
function ns.WindowLabel(windowID)
	local L = ns.L
	return L.WINDOWS[windowID] or (windowID:find("^event%.") and L.WINDOW_EVENT) or L.NAME_UNKNOWN
end

--- A window's state from its Window (LED-R127): `openNow` "biting now"; `opensAt` under 48 h away "back in {n} h"
--- (hours rounded up), or "back in {n} min" (rounded up) under an hour; further, "back in {month}" of `opensAt`'s
--- realm date; nil for a nil Window or one with no opening. `confirmed` isn't shown. A pure function of the Window,
--- the time now and the realm offset: callers forecast afresh each time they draw and never keep the result.
---@param window Window?
---@param now integer server time
---@param offset integer the realm's UTC offset in minutes (ns.RealmOffset)
---@return string?
function ns.WindowState(window, now, offset)
	local L = ns.L
	if not window then
		return nil
	end
	if window.openNow then
		return L.WINDOW_OPEN
	end
	local opensAt = window.opensAt
	if not opensAt then
		return nil
	end
	local away = opensAt - now
	if away < 3600 then
		return L.WINDOW_BACK_MINUTES:format(math.ceil(away / 60))
	elseif away < FORECAST_HOURS * 3600 then
		return L.WINDOW_BACK_HOURS:format(math.ceil(away / 3600))
	end
	return L.WINDOW_BACK_MONTH:format(L.MONTHS[ns.RealmDateAt(opensAt, offset).month])
end

-- Tunables: the continent name map (LED-R126, LED-R130). Every other ContinentID is "Other waters".
local CONTINENT_MAPS = { [0] = 1415, [1] = 1414 }

--- The client's reads the Journal's words need, passed in (CORE-R7).
---@class LedgerTextClient
---@field ItemName fun(itemID: integer): string?               -- C_Item.GetItemNameByID
---@field RequestItem fun(itemID: integer)                     -- C_Item.RequestLoadItemDataByID
---@field AreaName fun(areaID: integer): string?               -- C_Map.GetAreaInfo
---@field MapName fun(uiMapID: integer): string?               -- C_Map.GetMapInfo(uiMapID).name
---@field Characters fun(): PagleCharacter[]                   -- Pagle.GetAngler().characters
---@field ServerTime fun(): integer                            -- GetServerTime()
---@field RealmMinute fun(): integer?                          -- GetGameTime() as a minute of day; nil while secret
---@field WindowSpec fun(windowID: string): table?             -- Pagle.GetWindowSpec
---@field NextWindow fun(spec: table, fromTime: integer): Window? -- Pagle.NextWindow

--- The Journal's words (LED-R126, LED-R127, LED-R161): every Journal page reads its names, dates, window lines and
--- lore through one, as `context.text`. Nothing is cached but the items asked for and not yet arrived: names and
--- window states are read afresh at each call, so a spread drawn again shows them as they are then.
---@class LedgerJournalText
---@field private client LedgerTextClient
---@field private requested { [integer]: true }
local Text = {}
Text.__index = Text

--- The Journal's words over the client's reads.
---@param client LedgerTextClient
---@return LedgerJournalText
function ns.NewJournalText(client)
	return setmetatable({ client = client, requested = {} }, Text)
end

--- The Journal's words for lore alone (`:Lore`, LED-R161), as the moments name titles (LED-R97): zone names from
--- `areaName`, nothing else read.
---@param areaName fun(areaID: integer): string? C_Map.GetAreaInfo
---@return LedgerJournalText
function ns.NewLoreText(areaName)
	return setmetatable({ client = { AreaName = areaName }, requested = {} }, Text)
end

-- The realm's UTC offset now (LED-R126); UTC's while the realm clock is secret.
---@param client LedgerTextClient
---@param now integer
---@return integer
local function offsetAt(client, now)
	local minute = client.RealmMinute()
	return minute and ns.RealmOffset(now, minute) or 0
end

--- An item's name (LED-R126). Until the client has it cached: "…" (or "Item {id}" with `numbered`, as the
--- Uncharted list has it), and the client is asked to load it, once until it arrives (ItemArrived).
---@param itemID integer
---@param numbered boolean?
---@return string
function Text:Item(itemID, numbered)
	local name = self.client.ItemName(itemID)
	if name then
		return name
	end
	if not self.requested[itemID] then
		self.requested[itemID] = true
		self.client.RequestItem(itemID)
	end
	return numbered and ns.L.ITEM_FALLBACK:format(itemID) or ns.L.NAME_UNKNOWN
end

--- GET_ITEM_INFO_RECEIVED's `itemID` and `success` (LED-R126): true when an item this asked for has arrived, so
--- the Journal should redraw. A failed load is forgotten, to be asked again at the next draw, but redraws nothing.
---@param itemID integer
---@param success boolean?
---@return boolean redraw
function Text:ItemArrived(itemID, success)
	if not self.requested[itemID] then
		return false
	end
	self.requested[itemID] = nil
	return success == true
end

--- A zone's name from C_Map.GetAreaInfo, or "…" (LED-R126).
---@param areaID integer
---@return string
function Text:Zone(areaID)
	return self.client.AreaName(areaID) or ns.L.NAME_UNKNOWN
end

--- A continent tab's label (LED-R126, LED-R130): Eastern Kingdoms (0) and Kalimdor (1) from C_Map.GetMapInfo on the
--- continent's uiMapID ("…" if it has no name), "Other waters" for any other ContinentID or none.
---@param continentID integer?
---@return string
function Text:Continent(continentID)
	local uiMapID = continentID and CONTINENT_MAPS[continentID]
	if not uiMapID then
		return ns.L.OTHER_WATERS
	end
	return self.client.MapName(uiMapID) or ns.L.NAME_UNKNOWN
end

--- A character's name by character index, from the Angler, or "…" (LED-R126).
---@param index integer
---@return string
function Text:Character(index)
	local character = self.client.Characters()[index]
	return character and character.name or ns.L.NAME_UNKNOWN
end

--- A Cast's realm date (`conditions.date`) as the Journal prints it (LED-R126): "3 Mar", or "3 Mar 2025" outside the
--- current realm year, worked out live; "…" with none.
---@param date LedgerRealmDate?
---@return string
function Text:Date(date)
	local now = self.client.ServerTime()
	return ns.FormatJournalDate(date, ns.RealmDateAt(now, offsetAt(self.client, now)).year)
end

--- A window's label alone (LED-R127), e.g. for the plain hint's window part (LED-R141).
---@param _ LedgerJournalText
---@param windowID string
---@return string
Text.WindowLabel = function(_, windowID)
	return ns.WindowLabel(windowID)
end

--- A window's line (LED-R127): "{label}, {state}" from Pagle.NextWindow(Pagle.GetWindowSpec(windowID), now),
--- forecast afresh at each call; the label alone with no state, or for an ID GetWindowSpec doesn't know.
---@param windowID string
---@return string
function Text:WindowLine(windowID)
	local label = ns.WindowLabel(windowID)
	local spec = self.client.WindowSpec(windowID)
	if not spec then
		return label
	end
	local now = self.client.ServerTime()
	local state = ns.WindowState(self.client.NextWindow(spec, now), now, offsetAt(self.client, now))
	return state and ns.L.WINDOW_LINE:format(label, state) or label
end

--- A lore key's text (LED-R160, LED-R161), e.g. `species.6303.riddle` or `line.unchartedwaters.text`, with `{zone}`
--- filled with zone `zone`'s name (DATA-R108); nil when the key has no text, so the caller leaves its line out.
---@param key string
---@param zone integer?
---@return string?
function Text:Lore(key, zone)
	local text = ns.L[key]
	if type(text) ~= "string" or not key:find("%.") then
		return nil
	end
	if not text:find("{zone}", 1, true) then
		return text
	end
	local name = zone and self:Zone(zone) or ns.L.NAME_UNKNOWN
	return (text:gsub("{zone}", function()
		return name
	end))
end
