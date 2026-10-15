if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- "Take it down" on the client (TKB-R55, TKB-R56): ns.CanTakeDown and ns.TakeDown (logic/Seams.lua; the pins, #239,
-- show the button and call them), and the native confirm. The rules are logic/Reroll.lua's. The popup is a plain
-- StaticPopup, not secure, so it works in combat (TKB-R193).

-- The confirm's StaticPopupDialogs key, the one field .luacheckrc lets the Tackle Board set.
local DIALOG = "PAGLE_TACKLEBOARD_REROLL"

--- The goal `goalID` names if it can be taken down now (TKB-R55, TKB-R108), from the projection's state.
---@param goalID string
---@return TackleGoal?
local function takeable(goalID)
	return ns.TakeDownGoal(ns.State(), goalID, ns.IsUpdating(), Pagle)
end

--- Whether a goal's "take it down" shows and works now (TKB-R55): an open goal from an `issue` record, or a stranded
--- re-posted one, while the projection isn't updating.
---@param goalID string the entry ID of the record that issued it (TKB-R23)
---@return boolean
function ns.CanTakeDown(goalID)
	return takeable(goalID) ~= nil
end

-- Appends the `reroll` record for `goalID` if it can still be taken down (TKB-R55: checked again on confirm).
---@param goalID string
local function reroll(goalID)
	local goal = takeable(goalID)
	if goal then
		ns.Reroll(goal, ns.GenerationContext(ns.State(), ns.api.GetServerTime(), ns.random))
	end
end

--- Takes a goal down (TKB-R55, TKB-R56), if it can be now: at once with no displayed progress, else after "Take it
--- down" in a native confirm, checking the conditions again then. "Keep it" and Esc append nothing.
---@param goalID string the entry ID of the record that issued it (TKB-R23)
function ns.TakeDown(goalID)
	local goal = takeable(goalID)
	if not goal then
		return
	end
	local question = ns.TakeDownQuestion(goal, Pagle.GetSession(), Pagle)
	if not question then
		reroll(goalID)
		return
	end
	local L = ns.L
	StaticPopupDialogs.PAGLE_TACKLEBOARD_REROLL = {
		text = question,
		button1 = L.TAKE_DOWN_YES,
		button2 = L.TAKE_DOWN_NO,
		OnAccept = function(_, data)
			reroll(data)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
	StaticPopup_Show(DIALOG, nil, nil, goalID)
end
