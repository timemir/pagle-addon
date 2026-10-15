if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Taking a goal down (TKB-R55, TKB-R56): whether a goal may be taken down, whether the player is asked first and
-- what, and the `reroll` record that takes it down. Pure logic (CORE-R7): Core's catalogue calls, the current Session
-- and the generation context come in from adapter/Reroll.lua. This file and logic/LiveStep.lua are the only ones that
-- append records (TKB-R80; the boundary spec checks it).

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

--- Takes a goal down (TKB-R55): appends one `reroll` record naming it, with a new goal of its type generated with
--- its kind dropped (TKB-R30–R36). The projection applies it live (TKB-R57): the new goal takes the old one's pin and
--- is re-posted. Call it only from live code, for a goal ns.TakeDownGoal has just returned (TKB-R80).
---@param goal TackleGoal
---@param ctx TackleGenerationContext the live generation context (ns.GenerationContext)
---@return PagleModuleRecord record the appended record; its ID is the new goal's (TKB-R23)
function ns.Reroll(goal, ctx)
	local def = ns.GenerateGoal(ctx, goal.type, goal.kind)
	return ns.Module:AppendRecord("reroll", ns.EncodeReroll(goal.id, def))
end
