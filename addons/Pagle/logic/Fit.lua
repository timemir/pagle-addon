---@class PagleNS
local ns = select(2, ...)

-- Fitting a big window to the screen (core/README.md › Contracts, Pagle.FitToScreen), the art kits' Fit.lua as maths:
-- the books, the Tackle Board and the Curio Shop are drawn at 1 UI unit per canvas px, and at a large UI scale on a
-- 16:9 screen UIParent is only 668 units tall (768 / 1.15), so a window shrinks to fit and never grows.

-- The room kept clear round a window, in UIParent's units.
local MARGIN = 24

--- The scale that fits a window's whole extent (`width` × `height`, in its own units) on a `screenWidth` ×
--- `screenHeight` screen with MARGIN clear round it: never above 1, and 1 on a screen not laid out yet (no size).
---@param screenWidth number
---@param screenHeight number
---@param width number
---@param height number
---@return number
function ns.FitScale(screenWidth, screenHeight, width, height)
	if not (screenWidth > 0 and screenHeight > 0) then
		return 1
	end
	return math.min(1, (screenHeight - 2 * MARGIN) / height, (screenWidth - 2 * MARGIN) / width)
end

--- How a window fits: its whole extent in its own units, with what hangs outside its frame (ribbons, a plate, the wax
--- close button); how far its centre sits above that extent's centre; and whether it keeps its place on the screen
--- (a window the player moves and whose place is saved) instead of being centred.
---@class PagleFitOptions
---@field width number
---@field height number
---@field lift number? default 0
---@field keepPlace boolean?

--- Scales `frame` to fit `screen` (UIParent) and places it: centred on it, `lift` up, or, keeping its place, with its
--- first anchor's offsets rescaled so it stays where it is on the screen (a scaled frame's offsets are in its own
--- units). Returns the scale used.
---@param frame Frame
---@param screen Frame
---@param options PagleFitOptions
---@return number
function ns.FitFrame(frame, screen, options)
	local before = frame:GetScale()
	local scale = ns.FitScale(screen:GetWidth() or 0, screen:GetHeight() or 0, options.width, options.height)
	frame:SetScale(scale)
	if options.keepPlace then
		local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
		if point then
			frame:ClearAllPoints()
			frame:SetPoint(point, relativeTo, relativePoint, (x or 0) * before / scale, (y or 0) * before / scale)
		end
	else
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", screen, "CENTER", 0, options.lift or 0)
	end
	return scale
end

--- Pagle.FitToScreen over a client: `screen()` is UIParent, and `listen(refit)` registers `refit` for the UI scale's
--- and the window's changes. The fit it returns fits a frame with FitFrame and keeps it, so each change fits every
--- frame fitted so far again; `listen` runs at the first fit, so nothing listens before a window is fitted.
---@param screen fun(): Frame
---@param listen fun(refit: fun())
---@return fun(frame: Frame, options: PagleFitOptions): number
function ns.NewFitter(screen, listen)
	---@type table<Frame, PagleFitOptions>
	local fitted = {}
	local listening = false
	local function refit()
		for frame, options in pairs(fitted) do
			ns.FitFrame(frame, screen(), options)
		end
	end
	return function(frame, options)
		fitted[frame] = options
		if not listening then
			listening = true
			listen(refit)
		end
		return ns.FitFrame(frame, screen(), options)
	end
end
