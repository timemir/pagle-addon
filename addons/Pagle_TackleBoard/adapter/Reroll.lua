if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- "Take it down" on the client (TKB-R55, TKB-R56): ns.CanTakeDown and ns.TakeDown (logic/Seams.lua; adapter/Pins.lua
-- shows the button and calls them), the native confirm and the `reroll` record, which only this file and
-- adapter/LiveStep.lua's live step append (TKB-R80). The rules are logic/Reroll.lua's. The popup is a plain
-- StaticPopup, not secure, so it works in combat (TKB-R193).

-- The confirm's StaticPopupDialogs key, the one field .luacheckrc lets the Tackle Board set.
local DIALOG = "PAGLE_TACKLEBOARD_REROLL"

--- The goal `goalID` names if it can be taken down now (TKB-R55, TKB-R108): one ns.CanTakeDown allows, while the
--- projection isn't updating.
---@param goalID string
---@return TackleGoal?
local function takeable(goalID)
	if ns.IsUpdating() then
		return nil
	end
	return ns.TakeDownGoal(ns.State(), goalID, ns.api.pagle)
end

--- Whether a goal's "take it down" shows (TKB-R55): an open goal from an `issue` record, or a stranded re-posted
--- one. It doesn't read ns.IsUpdating(): the pins grey the button while the projection is updating (TKB-R108), and
--- ns.TakeDown refuses then.
---@param goalID string the entry ID of the record that issued it (TKB-R23)
---@return boolean
function ns.CanTakeDown(goalID)
	return ns.TakeDownGoal(ns.State(), goalID, ns.api.pagle) ~= nil
end

-- Takes the goal `goalID` names down if it can still be (TKB-R55: checked again on confirm): appends one `reroll`
-- record naming it, with a new goal of its type generated with its kind dropped (TKB-R30–R36). The projection applies
-- it live (TKB-R57): the new goal takes the old one's pin and is re-posted.
---@param goalID string
local function reroll(goalID)
	local goal = takeable(goalID)
	if goal then
		local ctx = ns.GenerationContext(ns.State(), ns.api.GetServerTime(), ns.random)
		local def = ns.GenerateGoal(ctx, goal.type, goal.kind)
		ns.Module:AppendRecord("reroll", ns.EncodeReroll(goal.id, def))
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
	local question = ns.TakeDownQuestion(goal, Pagle.GetSession(), ns.api.pagle)
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
