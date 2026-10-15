if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The book fits the screen (stats.md › UI), after the books art kit v2's Fit.lua: it is drawn at 1 UI unit per canvas
-- px, and at a large UI scale on a 16:9 screen UIParent is only 668 units tall (768 / 1.15), less than the book with
-- its ribbons, so it shrinks itself to fit, never grows, and re-fits when the UI scale or the window size changes. The
-- kit centres the window as it fits it; the book keeps the place it was left (STA-R71), clamped to the screen, so only
-- its scale is the kit's.

-- The room kept clear round the window, in UIParent's units.
local MARGIN = 24

---@type table<Frame, { [1]: number, [2]: number }>
local fitted = {}
-- Whether they re-fit on the UI scale's and the window's changes: registered at the first fit, so an inert Stats,
-- which never opens its book, listens to nothing (CORE-R13).
local listening = false
-- The owner of those registrations (CORE-R23).
local OWNER = "Pagle_Stats fit"

--- Scales `frame` to fit the screen: `width` and `height` are its whole extent in its own units, with what hangs
--- outside it (the ribbons, the wax close button); never above 1. Returns the scale used. A screen not laid out yet
--- (no size) leaves it at 1.
---@param frame Frame
---@param width number
---@param height number
---@return number
function ns.FitToScreen(frame, width, height)
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local scale = 1
	if screenWidth > 0 and screenHeight > 0 then
		scale = math.min(1, (screenHeight - 2 * MARGIN) / height, (screenWidth - 2 * MARGIN) / width)
	end
	frame:SetScale(scale)
	fitted[frame] = { width, height }
	if not listening then
		listening = true
		local function refit()
			for each, extent in pairs(fitted) do
				ns.FitToScreen(each, extent[1], extent[2])
			end
		end
		-- through Core, as every WoW event registration (CORE-R23)
		Pagle.RegisterEvent(OWNER, "UI_SCALE_CHANGED", refit)
		Pagle.RegisterEvent(OWNER, "DISPLAY_SIZE_CHANGED", refit)
	end
	return scale
end
