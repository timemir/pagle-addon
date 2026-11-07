---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The tracker dock on the client (CORE-R70–R72, CORE-R88): one invisible anchor frame on UIParent, under the minimap
-- cluster or at dock.point, that each docked tracker frame is parented and anchored to, top to bottom. Core sets each
-- frame's parent and anchor, and makes it take a left-button drag, so a Shift-drag of any of them moves the anchor and
-- with it the stack; it never shows or hides a tracker itself, which is its Module's (CORE-R72). Hiding the anchor
-- hides the whole stack, each tracker keeping its own shown state, for "Show trackers only while fishing" (CORE-R88).
-- No docked tracker is a secure frame, so that is allowed in combat and while restricted. The stacking and shown rules
-- are logic/Dock.lua's; the wiring is ns.WireDock's (logic/Wiring.lua).
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

-- Anchors each shown tracker in its place in the stack, and sizes the anchor to the stack (1 px with nothing in it).
local function reflow()
	local layout = ns.dock:Layout()
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
	-- In the anchor, so it shows and hides with the dock (CORE-R88). Same strata, and the anchor has UIParent's scale.
	frame:SetParent(anchor)
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

-- Whether a fishing pole is in the main hand (CORE-R88): its item's class and subclass, read without the item's data
-- being loaded.
---@return boolean
local function poleInHand()
	local itemID = GetInventoryItemID("player", 16) -- the main hand (INVSLOT_MAINHAND)
	if not itemID then
		return false
	end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
	return ns.IsFishingPole(classID, subclassID)
end

-- Shows or hides the whole stack (CORE-R88). A drag in progress when it hides ends there, as when the dragged tracker
-- hides.
---@param shown boolean
local function setShown(shown)
	if not shown and dragged then
		stopDrag()
	end
	anchor:SetShown(shown)
end

ns.WireDock(ns.host, {
	watch = watch,
	reflow = reflow,
	place = place,
	stopMoving = stopMoving,
	poleInHand = poleInHand,
	setShown = setShown,
})

-- CORE-R88: a pole going in hand shows the dock at once, and one coming off hides it at once unless the dock's fishing
-- stretch runs. Before login step 1 has opened PagleDB there is no setting to read yet; ModulesChanged decides then.
Pagle.RegisterEvent("Pagle dock", "PLAYER_EQUIPMENT_CHANGED", function()
	if ns.db then
		ns.dock:Refresh()
	end
end)

-- The Trackers page's Core rows, which never register the page alone (SET-R1, ns.IsPageRegistered). First
-- (SET-R40), "Tracker position", a button "Reset" that puts the dock back under the minimap: never greyed out, and
-- pressed while restricted it does nothing (ns.dock:Reset), since the dock never moves then (CORE-R71). Then
-- (SET-R46, from 1.3) "Show trackers only while fishing", a native checkbox, off by default and restored by Defaults,
-- that shows or hides the dock at once (CORE-R88).
---@param category SettingsCategory
---@param layout SettingsLayout
ns.CoreSettingsRows.trackers = function(category, layout)
	layout:AddInitializer(
		CreateSettingsButtonInitializer(L.SETTINGS_TRACKER_POSITION, L.SETTINGS_TRACKER_RESET, function()
			ns.dock:Reset()
		end, L.SETTINGS_TRACKER_RESET_TOOLTIP, true)
	)
	local whileFishing = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_trackers_onlyWhileFishing",
		Settings.VarType.Boolean,
		L.SETTINGS_TRACKERS_WHILE_FISHING,
		false,
		function()
			return ns.dock:OnlyWhileFishing()
		end,
		function(value)
			ns.dock:SetOnlyWhileFishing(value)
		end
	)
	Settings.CreateCheckbox(category, whileFishing, L.SETTINGS_TRACKERS_WHILE_FISHING_TOOLTIP)
end
