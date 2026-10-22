---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The clock format (CORE-R87, logic/Clock.lua): Pagle.FormatClock, and ClockFormatChanged when the format a time was
-- written in changes. The Clock row on the Settings root changes it (ns.ClockRow, below); so does the game's own
-- clock while the row follows it, which the game tells through CVAR_UPDATE. Every CVAR_UPDATE checks: its payload's
-- first value has been an event name instead of the CVar's (adapter/FishingKey.lua in QoL), and the check is cheap.

--- Payload of `ClockFormatChanged`: the format times now read in.
---@alias PagleClockFormatChangedHandler fun(event: "ClockFormatChanged", format: PagleClockFormat)

ns.PublishClock(Pagle, ns.host)

Pagle.RegisterEvent("Pagle clock", "CVAR_UPDATE", function()
	ns.NoteClockFormat()
end)

--- The Units section's Clock row (SET-R10 row 9a, CORE-R87), after the length unit (adapter/Settings.lua): a dropdown
--- of "Follow the game's clock", "24-hour" and "12-hour". Following the game is the default, which the root's
--- Defaults button restores (SET-R13), and stores none: PagleDB.profile.clockFormat is nil while it follows. A pick
--- notes the format, so a shown book's clock redraws in it at once.
---@param category SettingsCategory
function ns.ClockRow(category)
	local L = ns.L
	local clock = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_clockFormat",
		Settings.VarType.String,
		L.SETTINGS_CLOCK,
		"game",
		function()
			local stored = ns.db.profile.clockFormat
			return (stored == "24h" or stored == "12h") and stored or "game"
		end,
		function(value)
			ns.db.profile.clockFormat = value ~= "game" and value or nil
			ns.NoteClockFormat()
		end
	)
	Settings.CreateDropdown(category, clock, function()
		local container = Settings.CreateControlTextContainer()
		for _, choice in ipairs(ns.CLOCK_CHOICES) do
			container:Add(choice, L.SETTINGS_CLOCK_CHOICES[choice])
		end
		return container:GetData()
	end, L.SETTINGS_CLOCK_TOOLTIP)
end
