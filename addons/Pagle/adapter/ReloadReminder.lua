---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The unsaved-Casts reminder (LOG-R86): a chat line each time 50 more Casts are recorded since load, while
-- `PagleDB.profile.reloadReminder` is on (its checkbox is on the Settings root, adapter/Settings.lua). A line that
-- falls due while restricted shows when the restriction ends. Core does nothing else about crashes (LOG-R85,
-- CORE-R83). Its own owner on Core's bus.
local OWNER = "Pagle reload reminder"

local reminder = ns.NewReloadReminder({
	isOn = function()
		return ns.db.profile.reloadReminder
	end,
	isRestricted = Pagle.IsRestricted,
	show = function(count)
		print(ns.L.RELOAD_REMINDER:format(count))
	end,
})

-- A Cast with a record was written to the Catch log; an interrupted one has none (LOG-R7, LOG-R9).
Pagle.RegisterCallback(OWNER, "CastEnded", function(_, _, cast)
	if cast then
		reminder:CastRecorded()
	end
end)

Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
	if not isRestricted then
		reminder:RestrictionEnded()
	end
end)
