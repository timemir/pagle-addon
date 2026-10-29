if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Taking a goal down (TKB-R55, TKB-R56): whether a goal may be taken down (once per board day, for a re-posted goal
-- from the next daily reset), whether the player is asked first and what. And spending a Refresh on an empty slot (TKB-R58, TKB-R59): whether a goal can be posted into one, and what
-- the player is asked and told. Pure logic (CORE-R7): Core's catalogue calls, the board day now and the Refreshes held
-- come in from adapter/Reroll.lua, which appends the `reroll` and `post` records (TKB-R80).

--- Whether a goal was re-posted by a take-down on board day `today` or later (TKB-R55): the goal a `reroll` posts is
--- issued on the day the projection has reached for that record (TKB-R57), so its `issuedDay` is the day of the take-down,
--- read from the log on every rebuild and never from the clock at the click. A goal that was not re-posted is never.
---@param goal TackleGoal
---@param today integer the board day now, the projection's day (TKB-R104)
---@return boolean
function ns.IsRepostedToday(goal, today)
	return goal.reposted and goal.issuedDay >= today
end

--- The goal `goalID` names, if it is one that can be taken down (TKB-R55): an open goal (not completed) that was not
--- re-posted by a take-down today, or a re-posted one while it is stranded (TKB-R44). A goal re-posted on an earlier
--- board day can come down again, Notice and Expedition alike. Nil otherwise, also for an ID the board doesn't know.
--- Whether the projection is updating (TKB-R108) is the caller's: the button shows greyed then, and nothing is taken
--- down.
---@param state TackleBoardState
---@param goalID string
---@param pagle table Core's catalogue calls (LOG-R55), for ns.IsStranded
---@return TackleGoal?
function ns.TakeDownGoal(state, goalID, pagle)
	local goal = state.goals[goalID]
	if not goal or goal.doneDay ~= nil then
		return nil
	end
	if ns.IsRepostedToday(goal, state.day) and not ns.IsStranded(goal, pagle) then
		return nil
	end
	return goal
end

--- What "take it down" says under the mouse (TKB-R55, TKB-R56, TKB-R44, TKB-R108): what it does for the goal's type,
--- then the one rule that applies: while the projection is updating, that it waits; for a stranded goal, that it is no
--- longer catchable (and so can come down though re-posted); otherwise, that the new goal can't be taken down again
--- until the daily reset (in `untilReset`, when the board has the time to hand), unless it stops being catchable.
---@param goal TackleGoal
---@param updating boolean ns.IsUpdating() (TKB-R108)
---@param pagle table Core's catalogue calls (LOG-R55), for ns.IsStranded
---@param untilReset string? the countdown to the daily reset, ns.ResetCountdown (TKB-R105)
---@return string[] lines its title, what it does, the rule
function ns.TakeDownTip(goal, updating, pagle, untilReset)
	local L = ns.L
	local rule
	if updating then
		rule = L.TAKE_DOWN_TIP_UPDATING
	elseif ns.IsStranded(goal, pagle) then
		rule = goal.reposted and L.TAKE_DOWN_TIP_STRANDED or L.TAKE_DOWN_TIP_STRANDED_FIRST
	elseif untilReset then
		rule = ns.Fill(L.TAKE_DOWN_TIP_ONCE_IN, { time = untilReset })
	else
		rule = L.TAKE_DOWN_TIP_ONCE
	end
	return { L.TAKE_DOWN_TIP_TITLE, L.TAKE_DOWN_TIP[goal.type], rule }
end

--- The confirm's question (TKB-R56): its title, what is lost, and the progress inside that, which the confirm inks
--- apart.
---@class TackleTakeDownQuestion
---@field title string      -- "Take down this Notice?"
---@field text string       -- "Its progress (12/30) is lost, and the new one can't be taken down again today."
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

--- Whether a Refresh can post a goal of `goalType` now (TKB-R58): the board is started, the projection isn't updating
--- (TKB-R108), at least one Refresh is held (REF-R5) and a pin of that type is empty (TKB-R101), so a post never goes
--- past the caps. The adapter checks it again when the player confirms (TKB-R59).
---@param state TackleBoardState
---@param goalType TackleGoalType|any
---@param held integer the Refreshes held, `Pagle.GetTickets().tickets`
---@param updating boolean ns.IsUpdating() (TKB-R108)
---@return boolean
function ns.CanPostGoal(state, goalType, held, updating)
	if state.started == nil or updating or held <= 0 then
		return false
	end
	return (goalType == "n" or goalType == "e") and ns.EmptyPin(state, goalType) ~= nil
end

--- What an empty pin says under the mouse while a Refresh can be used on it (TKB-R58, TKB-R105): what clicking does by
--- type, then what it costs and how many Refreshes are held.
---@param goalType TackleGoalType
---@param held integer the Refreshes held
---@return string[] lines its title, what it does, what it costs
function ns.PostTip(goalType, held)
	local L = ns.L
	return { L.POST_TIP_TITLE[goalType], L.POST_TIP[goalType], ns.Fill(L.POST_TIP_COST, { held = held }) }
end

--- The confirm's question before a Refresh posts a goal (TKB-R59), which always asks: it cannot be undone.
---@class TacklePostQuestion
---@field title string      -- "Post a new Notice?"
---@field text string       -- "This uses 1 Refresh, and it can't be undone. The new goal can be taken down once a day, like any other."
---@field cost string       -- "1 Refresh", as it reads in `text`, which the confirm inks apart

---@param goalType TackleGoalType
---@return TacklePostQuestion
function ns.PostQuestion(goalType)
	local L = ns.L
	local cost = ns.Plural(1, "REFRESHES")
	return { title = L.POST_TITLE[goalType], text = ns.Fill(L.POST_TEXT, { cost = cost }), cost = cost }
end
