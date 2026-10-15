if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Taking a goal down (TKB-R55, TKB-R56): whether a goal may be taken down, whether the player is asked first and
-- what. Pure logic (CORE-R7): Core's catalogue calls and the current Session come in from adapter/Reroll.lua, which
-- appends the `reroll` record that takes the goal down (TKB-R80).

--- The goal `goalID` names, if it is one that can be taken down (TKB-R55): an open goal (not completed) issued by an
--- `issue` record, or a re-posted one only while it is stranded (TKB-R44). Nil otherwise, also for an ID the board
--- doesn't know. Whether the projection is updating (TKB-R108) is the caller's: the button shows greyed then, and
--- nothing is taken down.
---@param state TackleBoardState
---@param goalID string
---@param pagle table Core's catalogue calls (LOG-R55), for ns.IsStranded
---@return TackleGoal?
function ns.TakeDownGoal(state, goalID, pagle)
	local goal = state.goals[goalID]
	if not goal or goal.doneDay ~= nil then
		return nil
	end
	if goal.reposted and not ns.IsStranded(goal, pagle) then
		return nil
	end
	return goal
end

--- The confirm's question before a goal comes down (TKB-R56), or nil when it comes down at once: it asks only for a
--- goal whose displayed progress (TKB-R104) is above 0, showing that progress against its need (TKB-R44).
---@param goal TackleGoal
---@param session table? Pagle.GetSession()'s table, or nil with no current Session
---@param pagle table Core's catalogue calls (LOG-R55), for ns.GoalNeed
---@return string?
function ns.TakeDownQuestion(goal, session, pagle)
	local progress = ns.DisplayedProgress(goal, session)
	if progress <= 0 then
		return nil
	end
	return string.format(ns.L.TAKE_DOWN_CONFIRM[goal.type], progress, ns.GoalNeed(goal, pagle))
end
