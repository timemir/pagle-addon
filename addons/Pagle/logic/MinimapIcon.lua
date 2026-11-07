---@class PagleNS
local ns = select(2, ...)

-- The minimap icon's place round the minimap's edge (CORE-R53), as angles: pure logic, everything passed in
-- (CORE-R7). adapter/MinimapIcon.lua draws the button there and saves the angle in PagleDB.global.minimap.

--- The favicon, a gilt "P" on parchment: pagle-backend's favicon.ico, its 48 px image at 64 x 64
--- (scripts/encode-blp.py --raw). The minimap icon's, and the Pagle block's header on a player's tooltip (VIEW-R21).
ns.PAGLE_ICON = "Interface\\AddOns\\Pagle\\media\\minimap\\Pagle"

--- Where the icon starts, and sits until it is first dragged: 225 degrees, the minimap's bottom left, clear of the
--- tracker dock under its right edge (CORE-R70).
ns.MINIMAP_ICON_ANGLE = 225

--- The angle round the minimap's centre at which a point lies, in degrees counterclockwise from its right (0 to
--- 360), to 0.1 of a degree: where a drag to that point puts the icon (CORE-R53). How far out the point is doesn't
--- matter, so the icon stays on the edge.
---@param x number the point, in the minimap's units
---@param y number
---@param centerX number the minimap's centre, in the same units
---@param centerY number
---@return number
function ns.MinimapAngle(x, y, centerX, centerY)
	local angle = math.deg(math.atan2(y - centerY, x - centerX)) % 360
	return (math.floor(angle * 10 + 0.5) / 10) % 360
end

--- The icon's centre's offset from the minimap's at `angle`, on a circle of `radius` (CORE-R53).
---@param angle number degrees, as MinimapAngle gives them
---@param radius number
---@return number x
---@return number y
function ns.MinimapIconOffset(angle, radius)
	local radians = math.rad(angle)
	return math.cos(radians) * radius, math.sin(radians) * radius
end

-- From 1.5, "Detach from the minimap" (CORE-R53): the detached icon sits anywhere on the screen, its centre kept as
-- fractions of the screen's width and height, so it means the same spot at any UI scale and window size, and kept
-- far enough from each edge that the whole button shows. The screen is UIParent, in its own units.

--- `value` kept between `low` and `high`, or midway when the range is empty.
---@param value number
---@param low number
---@param high number
---@return number
local function within(value, low, high)
	if high < low then
		return (low + high) / 2
	end
	return math.min(math.max(value, low), high)
end

--- The detached icon's centre kept on a `width` x `height` screen: at least half the `size` button from each edge,
--- or the screen's middle on a screen smaller than the button (CORE-R53).
---@param x number the centre, from the screen's bottom left
---@param y number
---@param width number
---@param height number
---@param size number the button's side
---@return number x
---@return number y
function ns.ClampMinimapIcon(x, y, width, height, size)
	local half = size / 2
	return within(x, half, width - half), within(y, half, height - half)
end

--- The spot a detached icon whose centre is at `x`, `y` keeps (PagleDB.global.minimap.point): the clamped centre as
--- fractions of the screen (CORE-R53).
---@param x number
---@param y number
---@param width number
---@param height number
---@param size number
---@return { x: number, y: number }
function ns.DetachedIconPoint(x, y, width, height, size)
	local clampedX, clampedY = ns.ClampMinimapIcon(x, y, width, height, size)
	return { x = clampedX / width, y = clampedY / height }
end

--- Whether `value` is a number that isn't NaN or infinite.
---@param value any
---@return boolean
local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--- Where a saved spot puts the detached icon's centre on a `width` x `height` screen now, clamped to it; nil for a
--- spot that isn't one (CORE-R53).
---@param point any PagleDB.global.minimap.point
---@param width number
---@param height number
---@param size number
---@return number? x
---@return number? y
function ns.DetachedIconCenter(point, width, height, size)
	if type(point) ~= "table" or not (finite(point.x) and finite(point.y)) then
		return nil
	end
	return ns.ClampMinimapIcon(point.x * width, point.y * height, width, height, size)
end
