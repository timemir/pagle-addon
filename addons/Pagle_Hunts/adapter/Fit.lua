if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The board fits the screen (hunts.md › UI, HNT-R60), the books art kit v2's Fit.lua: the board is drawn at 1 UI unit
-- per canvas px, and at a large UI scale on a 16:9 screen UIParent is only 668 units tall (768 / 1.15), less than the
-- board with its ribbons, so it shrinks itself to fit, never grows, and re-fits when the UI scale or the window size
-- changes. The kit's function, its events registered through Core (CORE-R23) at the first fit, so a Hunts that never
-- opens its board listens to nothing (CORE-R13).

-- The room kept clear round the window, in UIParent's units.
local MARGIN = 24

---@type table<Frame, { [1]: number, [2]: number, [3]: number?, [4]: number? }>
local fitted = {}
local listening = false
-- The owner of those registrations (CORE-R23).
local OWNER = "Pagle_Hunts fit"

--- Scales `frame` to fit the screen and centres it: `width` and `height` are its whole extent in its own units,
--- including what hangs outside it (the ribbons, the nameplate, the wax close button); `lift` is how far its centre sits
--- above that extent's centre; `want` the scale asked for (1 by default), never exceeded. Returns the scale used.
---@param frame Frame
---@param width number
---@param height number
---@param lift number?
---@param want number?
---@return number
function ns.FitToScreen(frame, width, height, lift, want)
	local scale =
		math.min(want or 1, (UIParent:GetHeight() - 2 * MARGIN) / height, (UIParent:GetWidth() - 2 * MARGIN) / width)
	frame:SetScale(scale)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, lift or 0) -- offsets are in the frame's own (scaled) units
	fitted[frame] = { width, height, lift, want }
	if not listening then
		listening = true
		local function refit()
			for each, extent in pairs(fitted) do
				ns.FitToScreen(each, extent[1], extent[2], extent[3], extent[4])
			end
		end
		Pagle.RegisterEvent(OWNER, "UI_SCALE_CHANGED", refit)
		Pagle.RegisterEvent(OWNER, "DISPLAY_SIZE_CHANGED", refit)
	end
	return scale
end
