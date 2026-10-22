---@class PagleNS
local ns = select(2, ...)

-- The clock format (CORE-R87): how a time of day reads, "18:05" or "6:05 pm". Pure logic over the stored choice
-- (PagleDB.profile.clockFormat) and what the game's clock CVar, timeMgrUseMilitaryTime, answered; Pagle.FormatClock
-- reads it through logic/Wiring.lua's ns.WireClock. Only the display changes with the format: times are kept and
-- compared as hours and minutes.

---@alias PagleClockFormat "24h"|"12h"
---@alias PagleClockChoice "game"|PagleClockFormat

--- The Clock row's choices, in the order the Settings root lists them (SET-R10): following the game's clock first,
--- the default, then the two formats.
---@type PagleClockChoice[]
ns.CLOCK_CHOICES = { "game", "24h", "12h" }

--- The format times read in (CORE-R87): `stored` when it is "24h" or "12h"; otherwise the game's clock, 12-hour only
--- when `military` is "0" (the minimap clock's 24-hour mode off), and 24-hour when it is "1" or the client has no
--- such CVar (nil), as Pagle wrote every time before the setting.
---@param stored string?
---@param military string? `GetCVar("timeMgrUseMilitaryTime")`
---@return PagleClockFormat
function ns.ClockFormatOf(stored, military)
	if stored == "24h" or stored == "12h" then
		return stored
	end
	return military == "0" and "12h" or "24h"
end

--- A time of day in `format` (CORE-R87): 24-hour "00:05", "18:30"; 12-hour "12:05 am", "6:30 pm", midnight "12:00
--- am" and noon "12:00 pm". The hour is taken mod 24, so 24:00, a day's end, reads as midnight.
---@param hour integer 0–24
---@param minute integer 0–59
---@param format PagleClockFormat
---@return string
function ns.FormatClock(hour, minute, format)
	hour = hour % 24
	local clock = ns.L.CLOCK
	if format ~= "12h" then
		return clock["24h"]:format(hour, minute)
	end
	local half = clock["12h"][hour < 12 and "am" or "pm"]
	return half:format((hour - 1) % 12 + 1, minute)
end
