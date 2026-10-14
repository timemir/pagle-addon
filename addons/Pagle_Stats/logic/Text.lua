if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' words (STA-R44, STA-R59): the one text layer every Stats view writes through. Rounding, counts, durations,
-- times ago, dates and Session headings, and the names of items, areas, characters and qualities. Pure logic: the
-- client's reads are passed in once through ns.WireText (CORE-R7), and each is called when a word is written, never
-- kept, so a name that loads or a clock that moves shows at the next draw. No view formats a count, duration or name
-- on its own (M6 graph, conventions), and every string is in ns.L, held to STA-R58's copy test.

-- The question-mark icon an item shows until the client has its data (STA-R59).
ns.QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local MINUTE, HOUR, DAY = 60, 3600, 86400

--- The client's reads Stats' words need, passed in (CORE-R7). adapter/Text.lua passes the game's.
---@class StatsTextClient
---@field BreakUpLargeNumbers fun(n: number): string   -- the client's thousands separators
---@field Date fun(format: string, time: integer): string   -- `date`, the player's local clock
---@field ServerTime fun(): integer                    -- GetServerTime()
---@field ItemName fun(itemID: integer): string?       -- C_Item.GetItemNameByID
---@field ItemIcon fun(itemID: integer): (integer|string)?   -- C_Item.GetItemIconByID
---@field AreaName fun(areaID: integer): string?       -- C_Map.GetAreaInfo
---@field Characters fun(): table                      -- Pagle.GetAngler().characters
---@field QualityName fun(quality: integer): string?   -- ITEM_QUALITY<n>_DESC
---@field QualityColor fun(quality: integer): { r: number, g: number, b: number, hex: string }?   -- ITEM_QUALITY_COLORS

---@type StatsTextClient
local client

--- Passes in the client's reads every word below goes through. adapter/Text.lua calls it when it loads.
---@param reads StatsTextClient
function ns.WireText(reads)
	client = reads
end

--- Rounds half up (STA-R44): `floor(x + 0.5)`.
---@param x number
---@return integer
function ns.Round(x)
	return math.floor(x + 0.5)
end

--- A whole number with the client's thousands separators (STA-R59): 1234567 reads "1,234,567".
---@param n number
---@return string
function ns.Number(n)
	return client.BreakUpLargeNumbers(n)
end

--- A number rounded for display (STA-R44): below 1.5 "1"; below 20 the nearest whole number; otherwise two
--- significant figures with thousands separators. 39.6 reads "40", 212 "210", 1,447 "1,400".
---@param x number
---@return string
function ns.Nice(x)
	if x < 1.5 then
		return "1"
	elseif x < 20 then
		return tostring(ns.Round(x))
	end
	local unit = 1 -- the second significant figure's place value
	while x >= 100 * unit do
		unit = unit * 10
	end
	return ns.Number(ns.Round(x / unit) * unit)
end

--- A count with its noun (STA-R59): "{n} Casts", with the singular when n is 1 ("1 Cast") and thousands separators
--- from 1,000. `noun` names one of ns.L.COUNTS: "Casts", "Catches", "Sessions", "waters" or "anglers" ("{n} anglers
--- in 100 wait").
---@param n integer
---@param noun "Casts"|"Catches"|"Sessions"|"waters"|"anglers"
---@return string
function ns.Count(n, noun)
	local forms = ns.L.COUNTS[noun]
	return (n == 1 and forms.one or forms.other):format(ns.Number(n))
end

--- A length of time (STA-R59): under a minute "under 1m", under an hour "21m", otherwise "1h 05m", hours unbounded.
--- Minutes are rounded half up (STA-R44), so 59m 30s reads "1h 00m".
---@param seconds number
---@return string
function ns.Duration(seconds)
	local L = ns.L
	if seconds < MINUTE then
		return L.DURATION_UNDER_MINUTE
	end
	local minutes = ns.Round(seconds / MINUTE)
	if minutes < 60 then
		return L.DURATION_MINUTES:format(minutes)
	end
	return L.DURATION_HOURS:format(math.floor(minutes / 60), minutes % 60)
end

--- How long ago a server time was (STA-R59): under a minute "just now", under an hour "21m ago", under a day "3h ago",
--- otherwise "4d ago". Each count is rounded half up (STA-R44) and read in the next unit when it rounds up to it, so
--- 59m 30s reads "1h ago". A time to come reads "just now".
---@param time integer server time
---@param now integer? server time; GetServerTime() if nil
---@return string
function ns.TimeAgo(time, now)
	local L = ns.L
	local ago = (now or client.ServerTime()) - time
	if ago < MINUTE then
		return L.AGO_NOW
	end
	local minutes = ns.Round(ago / MINUTE)
	if minutes < 60 then
		return L.AGO_MINUTES:format(minutes)
	end
	local hours = ns.Round(ago / HOUR)
	if hours < 24 then
		return L.AGO_HOURS:format(hours)
	end
	return L.AGO_DAYS:format(ns.Round(ago / DAY))
end

-- The day of the month in the player's local clock, without a leading zero.
---@param time integer
---@return integer
local function dayOf(time)
	return tonumber(client.Date("%d", time)) --[[@as integer]]
end

--- A time of day in the player's local clock, as the game's timestamps (STA-R59): `date("%H:%M")`, "09:07".
---@param time integer server time
---@return string
function ns.Time(time)
	return client.Date("%H:%M", time)
end

--- A date in the player's local clock (STA-R59): "{day} {%b} {%Y}", "5 Oct 2026".
---@param time integer server time
---@return string
function ns.Date(time)
	return ns.L.DATE:format(dayOf(time), client.Date("%b", time), client.Date("%Y", time))
end

--- A Session's heading by a time in it, in the player's local clock (STA-R59): "{%A} {day} {%B}", "Monday 5 October".
---@param time integer server time
---@return string
function ns.SessionHeading(time)
	return ns.L.SESSION_HEADING:format(client.Date("%A", time), dayOf(time), client.Date("%B", time))
end

--- A window's bound, in realm time (STA-R59): a minute of the realm's day as "HH:MM"; 1440, the day's end, as "00:00".
---@param minute integer 0–1440
---@return string
function ns.WindowTime(minute)
	return ns.L.WINDOW_TIME:format(math.floor(minute / 60) % 24, minute % 60)
end

--- An item's name and icon (STA-R59): its C_Item name and icon, or "Item {id}" and the question-mark icon until the
--- client has its name, and whether it has. Nothing is asked of the client here: a view that draws an unloaded item
--- asks for it and redraws when it arrives (the book, #211).
---@param itemID integer
---@return string name
---@return integer|string icon
---@return boolean loaded
function ns.Item(itemID)
	local name = client.ItemName(itemID)
	if not name then
		return ns.L.ITEM_FALLBACK:format(itemID), ns.QUESTION_MARK_ICON, false
	end
	return name, client.ItemIcon(itemID) or ns.QUESTION_MARK_ICON, true
end

--- An area's name (STA-R59): its C_Map.GetAreaInfo name, or "Area {id}" if it has none.
---@param areaID integer
---@return string
function ns.AreaName(areaID)
	local name = client.AreaName(areaID)
	if not name or name == "" then
		return ns.L.AREA_FALLBACK:format(areaID)
	end
	return name
end

--- A character's name by its Catch log index (STA-R59): name and surname as Core stores them ("Ada Brook"), the name
--- alone without a surname, or "Character {index}" for an index the Angler doesn't have.
---@param index integer
---@return string
function ns.CharacterName(index)
	local character = client.Characters()[index]
	if not character then
		return ns.L.CHARACTER_FALLBACK:format(index)
	end
	if character.surname then
		return ns.L.CHARACTER_NAME:format(character.name, character.surname)
	end
	return character.name
end

--- An item quality's name in the game's own words (STA-R59): ITEM_QUALITY<n>_DESC, or "Quality {n}" for one the game
--- has no name for.
---@param quality integer
---@return string
function ns.QualityName(quality)
	return client.QualityName(quality) or ns.L.QUALITY_FALLBACK:format(quality)
end

local WHITE = { r = 1, g = 1, b = 1, hex = "|cffffffff" }

--- An item quality's colour, the game's own (STA-R59): ITEM_QUALITY_COLORS as it is now, or white for a quality it
--- has none for.
---@param quality integer
---@return number r
---@return number g
---@return number b
function ns.QualityColor(quality)
	local color = client.QualityColor(quality) or WHITE
	return color.r, color.g, color.b
end

--- `text` in an item quality's colour (STA-R59), as a font string shows it: "|cff0070dd{text}|r".
---@param quality integer
---@param text string
---@return string
function ns.QualityText(quality, text)
	local color = client.QualityColor(quality) or WHITE
	return color.hex .. text .. "|r"
end
