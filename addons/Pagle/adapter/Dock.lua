---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The tracker dock on the client (CORE-R70–R72): one invisible anchor frame on UIParent, under the minimap cluster
-- or at dock.point, that each docked tracker frame is anchored to, top to bottom. Core reparents no tracker: it only
-- sets each frame's anchor, and makes it take a left-button drag, so a Shift-drag of any of them moves the anchor and
-- with it the stack. The stacking rules are logic/Dock.lua's; the wiring is ns.WireDock's (logic/Wiring.lua).
local L = ns.L

-- The anchor, sized to the stack so the client keeps the whole stack on screen. Unnamed, so the client's layout cache
-- never saves or restores it: dock.point is the one place its position is kept.
local anchor = CreateFrame("Frame", nil, UIParent)
anchor:SetSize(1, 1)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
ns.dockFrame = anchor

---@type table? the docked frame whose Shift-drag is moving the dock, while one is
local dragged

---@param frame table
---@return boolean
local function isShown(frame)
	return frame:IsShown()
end

---@param frame table
---@return number, number
local function sizeOf(frame)
	return frame:GetWidth(), frame:GetHeight()
end

-- Anchors each shown tracker in its place in the stack, and sizes the anchor to the stack (1 px with nothing in it).
local function reflow()
	local layout = ns.dock:Layout(isShown, sizeOf)
	for _, placement in ipairs(layout.placements) do
		local frame = placement.tracker.frame
		frame:ClearAllPoints()
		frame:SetPoint(placement.point, anchor, placement.relativePoint, placement.x, placement.y)
	end
	anchor:SetSize(math.max(layout.width, 1), math.max(layout.height, 1))
end

-- Puts the anchor at `point`: relative to the frame it names (UIParent, or the minimap cluster by default).
---@param point PagleDockPoint
local function place(point)
	local relativeTo = point.relativeTo == "MinimapCluster" and MinimapCluster or UIParent
	anchor:ClearAllPoints()
	anchor:SetPoint(point.point, relativeTo, point.relativePoint, point.x, point.y)
end

-- Ends a drag in progress where the anchor is now, keeping its top right there so the stack grows down from it.
-- Returns that point, nil with no drag in progress (or nowhere the client can say).
---@return PagleDockPoint?
local function stopMoving()
	if not dragged then
		return nil
	end
	dragged = nil
	anchor:StopMovingOrSizing()
	local right, top = anchor:GetRight(), anchor:GetTop()
	if not (right and top) then
		return nil
	end
	local point = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = right, y = top }
	place(point)
	return point
end

-- A drag of a docked frame (CORE-R71): with Shift held and outside restriction, the anchor follows the cursor.
---@param frame table
local function startDrag(frame)
	if dragged or not IsShiftKeyDown() or not ns.dock:CanMove() then
		return
	end
	dragged = frame
	anchor:StartMoving()
end

-- The player let go: the dock stays there, saved to dock.point.
local function stopDrag()
	local point = stopMoving()
	if point then
		ns.dock:Moved(point)
	end
end

-- A tracker docked: its frame reflows the stack as it shows, hides or resizes, and takes a left-button drag. A drag
-- of it in progress when it hides ends there.
---@param tracker PagleTracker
local function watch(tracker)
	local frame = tracker.frame
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:HookScript("OnDragStart", startDrag)
	frame:HookScript("OnDragStop", stopDrag)
	frame:HookScript("OnShow", reflow)
	frame:HookScript("OnHide", function(self)
		if dragged == self then
			stopDrag()
		end
		reflow()
	end)
	frame:HookScript("OnSizeChanged", reflow)
end

ns.WireDock(ns.host, {
	isRestricted = function()
		return Pagle.IsRestricted()
	end,
	watch = watch,
	reflow = reflow,
	place = place,
	stopMoving = stopMoving,
})

-- The Trackers page's first row (SET-R40): "Tracker position", a button "Reset" that puts the dock back under the
-- minimap. Never greyed out; pressed while restricted it does nothing (ns.dock:Reset), since the dock never moves
-- then (CORE-R71). This row never registers the page alone (SET-R1, ns.IsPageRegistered).
---@param _ SettingsCategory
---@param layout SettingsLayout
ns.CoreSettingsRows.trackers = function(_, layout)
	layout:AddInitializer(
		CreateSettingsButtonInitializer(L.SETTINGS_TRACKER_POSITION, L.SETTINGS_TRACKER_RESET, function()
			ns.dock:Reset()
		end, L.SETTINGS_TRACKER_RESET_TOOLTIP, true)
	)
end
