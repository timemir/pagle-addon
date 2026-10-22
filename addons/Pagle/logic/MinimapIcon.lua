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
