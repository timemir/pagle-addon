---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Pagle's one fit to the screen (core/README.md › Contracts), for the Curio Shop and every Module's big window
-- (logic/Fit.lua's), with one pair of registrations for the UI scale's and the window's changes, made through Core's
-- events (CORE-R23) at the first fit: nothing listens before a window is fitted, and a Module that never fits one (an
-- inert one, CORE-R13) has nothing fitted.

-- The owner of those registrations (CORE-R23).
local OWNER = "Pagle fit"

--- Scales `frame` to fit the screen and places it (logic/Fit.lua's FitFrame), and fits it again whenever the UI scale
--- or the window's size changes. Returns the scale used.
ns.FitToScreen = ns.NewFitter(function()
	return UIParent
end, function(refit)
	Pagle.RegisterEvent(OWNER, "UI_SCALE_CHANGED", refit)
	Pagle.RegisterEvent(OWNER, "DISPLAY_SIZE_CHANGED", refit)
end)

Pagle.FitToScreen = ns.FitToScreen
