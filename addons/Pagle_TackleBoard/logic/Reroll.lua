if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Taking a goal down (TKB-R55, TKB-R56): whether a goal may be taken down, whether the player is asked first and
-- what. Pure logic (CORE-R7): Core's catalogue calls and the board day now come in from adapter/Reroll.lua, which
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

--- What "take it down" says under the mouse (TKB-R55, TKB-R56, TKB-R44, TKB-R108): what it does for the goal's type,
--- then the one rule that applies: while the projection is updating, that it waits; for a stranded goal, that it is no
--- longer catchable (and so can come down though re-posted); otherwise, that the new goal can't be taken down in turn
--- unless it stops being catchable.
---@param goal TackleGoal
---@param updating boolean ns.IsUpdating() (TKB-R108)
---@param pagle table Core's catalogue calls (LOG-R55), for ns.IsStranded
---@return string[] lines its title, what it does, the rule
function ns.TakeDownTip(goal, updating, pagle)
	local L = ns.L
	local rule
	if updating then
		rule = L.TAKE_DOWN_TIP_UPDATING
	elseif ns.IsStranded(goal, pagle) then
		rule = goal.reposted and L.TAKE_DOWN_TIP_STRANDED or L.TAKE_DOWN_TIP_STRANDED_FIRST
	else
		rule = L.TAKE_DOWN_TIP_ONCE
	end
	return { L.TAKE_DOWN_TIP_TITLE, L.TAKE_DOWN_TIP[goal.type], rule }
end

--- The confirm's question (TKB-R56): its title, what is lost, and the progress inside that, which the confirm inks
--- apart.
---@class TackleTakeDownQuestion
---@field title string      -- "Take down this Notice?"
---@field text string       -- "Its progress (12/30) is lost, and the new one can't be taken down."
---@field progress string   -- "12/30", as it reads in `text`

--- The confirm's question before a goal comes down (TKB-R56), or nil when it comes down at once: it asks only for a
--- goal whose displayed progress (TKB-R104) is above 0, showing that progress against its need (TKB-R44).
---@param goal TackleGoal
---@param today integer the board day now, the projection's day (TKB-R104)
---@param pagle table Core's catalogue calls (LOG-R55), for ns.GoalNeed
---@return TackleTakeDownQuestion?
function ns.TakeDownQuestion(goal, today, pagle)
	local L = ns.L
	local progress = ns.DisplayedProgress(goal, today)
	if progress <= 0 then
		return nil
	end
	local shown = ns.Fill(L.TAKE_DOWN_PROGRESS, { n = progress, need = ns.GoalNeed(goal, pagle) })
	return {
		title = L.TAKE_DOWN_TITLE[goal.type],
		text = ns.Fill(L.TAKE_DOWN_TEXT, { progress = shown }),
		progress = shown,
	}
end
