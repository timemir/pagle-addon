if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The double-click's choices (QOL-R13–R15): pure logic, everything passed in (CORE-R7). adapter/DoubleClick.lua hears
-- the mouse and sets the BUTTON2 override.

--- The key the double-click window overrides: the right mouse button (QOL-R13).
ns.DOUBLE_CLICK_KEY = "BUTTON2"
--- The longest a qualifying click's button may be held, in seconds (qol.md › Tunables, QOL-R13).
ns.CLICK_HOLD_LIMIT = 0.3
--- How long the double-click window stays open, in seconds (qol.md › Tunables, probe B3, QOL-R13).
ns.DOUBLE_CLICK_WINDOW = 0.4

--- Whether a mouse-up lands on the game world: the frames under the mouse (`GetMouseFoci()`) are only
--- `worldFrame`, or none (QOL-R13).
---@param foci table[]
---@param worldFrame table
---@return boolean
function ns.OnGameWorld(foci, worldFrame)
	for _, focus in ipairs(foci) do
		if focus ~= worldFrame then
			return false
		end
	end
	return true
end

-- The double-click column of QOL-R24: the same target as the Fishing key's. Equipping the fishing set has none
-- (QOL-R15), and clams join with Track Q step 6.
local CLICK_ACTIONS = { cast = true, reel = true, lure = true }

--- The double-click column of QOL-R24: the Fishing key's target for a cast, a reel or a lure; no target (no
--- override) for anything else, so it never equips the fishing set (QOL-R15).
---@param action PagleQoLAction
---@param fishingName string? `C_Spell.GetSpellName(ns.FISHING_SPELL_ID)`
---@param lure integer? the lure's item ID, for the lure action
---@return PagleQoLKeyTarget?
function ns.ClickTarget(action, fishingName, lure)
	if CLICK_ACTIONS[action] then
		return ns.KeyTarget(action, fishingName, lure)
	end
	return nil
end

--- Whether the double-click is live (QOL-R14): Input allows it, QoL is armed, a fishing pole is in hand, and the next
--- action has a double-click target. With no pole in hand it does nothing (QOL-R15).
---@param input PagleQoLInput
---@param state PagleQoLLadderState
---@param target PagleQoLKeyTarget? `ns.ClickTarget` of the next action
---@return boolean
function ns.DoubleClickLive(input, state, target)
	return ns.InputArmsClick(input) and state.armed == true and state.poleInHand == true and target ~= nil
end

--- The double-click window's timing (QOL-R13), on `GetTime()` values, which hold one value through a frame.
---@class PagleQoLDoubleClickWindow
---@field downAt number? when the right button went down, for a click that may open a window
---@field openedAt number? when the window opened; nil while it is closed
---@field closingAt number? when the mouse-up that closes it came
local Window = {}
Window.__index = Window

--- A closed double-click window, with no right button down.
---@return PagleQoLDoubleClickWindow
function ns.NewDoubleClickWindow()
	return setmetatable({}, Window)
end

--- A mouse button went down (`GLOBAL_MOUSE_DOWN`). A right press while a window is open is that window's click:
--- it can't open another one.
---@param button string
---@param now number
function Window:MouseDown(button, now)
	if button == "RightButton" then
		self.downAt = not self.openedAt and now or nil
	end
end

--- A mouse button came up (`GLOBAL_MOUSE_UP`). Returns whether it ends a qualifying click, one that may open a
--- window: a right click held no longer than the click hold limit, landing on the game world, with no window open.
--- A right mouse-up while a window is open closes it on a later frame, and never opens a new one (QOL-R13).
---@param button string
---@param now number
---@param onWorld boolean `ns.OnGameWorld` at this mouse-up
---@return boolean
function Window:MouseUp(button, now, onWorld)
	if button ~= "RightButton" then
		return false
	end
	local downAt = self.downAt
	self.downAt = nil
	if self.openedAt then
		self.closingAt = self.closingAt or now
		return false
	end
	return downAt ~= nil and now - downAt <= ns.CLICK_HOLD_LIMIT and onWorld
end

--- Opens the window now.
---@param now number
function Window:Open(now)
	self.openedAt, self.closingAt = now, nil
end

---@return boolean
function Window:IsOpen()
	return self.openedAt ~= nil
end

--- Whether the open window is due to close, on the frame of `now`: on a frame after the mouse-up that closes it (so a
--- click that fires on key-up still reaches it), or once the window time has passed (QOL-R13).
---@param now number
---@return boolean
function Window:Due(now)
	if not self.openedAt then
		return false
	end
	return (self.closingAt ~= nil and now > self.closingAt) or now - self.openedAt >= ns.DOUBLE_CLICK_WINDOW
end

--- Closes the window at once.
function Window:Close()
	self.openedAt, self.closingAt = nil, nil
end
