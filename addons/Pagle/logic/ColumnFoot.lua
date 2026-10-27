---@class PagleNS
local ns = select(2, ...)

-- Where the Toast column stands (announcements.md › Data, ANN-R98): pure logic, read by adapter/Announcements.lua and
-- by scripts/read-wtf.lua. Needs nothing loaded to read a saved point; the clamp reads logic/Announcements.lua's
-- column tunables and logic/ToastStyles.lua's widest page when it is called.

--- The column's foot by default, in UI units above the screen's bottom, centred (ANN-R20): where the canvas's board
--- puts its toast.
ns.COLUMN_FOOT = 156

--- Where the Toast column's foot is (ANN-R98): its BOTTOM centre, `x` to the right of UIParent's BOTTOM centre and `y`
--- above its bottom edge, in UI units. `announcements.point` is one.
---@class PagleColumnFoot
---@field x number
---@field y number

--- The Toast column's foot (ANN-R98): the saved `announcements.point`, or by default the middle of the screen's
--- bottom, COLUMN_FOOT up. A saved value that isn't `{ x, y }` of two finite numbers counts as none.
---@param saved any PagleDB.profile.announcements.point
---@return PagleColumnFoot
function ns.ColumnFoot(saved)
	if type(saved) == "table" then
		local x, y = saved.x, saved.y
		if
			type(x) == "number"
			and type(y) == "number"
			and x > -math.huge
			and x < math.huge
			and y > -math.huge
			and y < math.huge
		then
			return { x = x, y = y }
		end
	end
	return { x = 0, y = ns.COLUMN_FOOT }
end

--- `foot` moved the least that lets a full column show on a screen `width` by `height` UI units (ANN-R98): its foot
--- not below the bottom edge, its top (COLUMN_HEIGHT and toast.high's bookmark above it) not past the top edge, and
--- the widest entry (a Nod with its medallion, or the widest toast page) not past either side. A screen too small for
--- that keeps the foot at the bottom edge (the newest entry, which the Angler reads first, stays in view) or in the
--- middle, whichever way it is too small. Without a screen size, `foot` as it is.
---@param foot PagleColumnFoot
---@param width number? UIParent's width
---@param height number? UIParent's height
---@return PagleColumnFoot
function ns.ClampColumnFoot(foot, width, height)
	local x, y = foot.x, foot.y
	if type(width) == "number" and width > 0 then
		local room = width / 2 - math.max(22 + ns.NOD_WIDTH, ns.TOAST_WIDTH_MAX) / 2
		x = math.max(-math.max(room, 0), math.min(math.max(room, 0), x))
	end
	if type(height) == "number" and height > 0 then
		local room = height - ns.COLUMN_HEIGHT - ns.RIBBON_HEIGHT
		y = math.max(0, math.min(math.max(room, 0), y))
	end
	return { x = x, y = y }
end
