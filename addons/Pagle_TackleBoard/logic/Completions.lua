if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Goals moving and completing inside the projection's fold (tackle-board.md › Progress, Completion and rewards):
-- each caught Cast runs logic/Progress.lua over the open goals in board order (TKB-R45) and keeps the ever-caught set
-- current one Catch at a time (TKB-R46); a goal that completes pays out in TKB-R60's order through logic/Rewards.lua.
-- Pure logic (CORE-R7): Core's catalogue calls come through ns.api.pagle (logic/Seams.lua), read at call time. logic/Projection.lua's ApplyEntry calls ns.CountCast for every Cast and AdvanceTo calls
-- ns.PruneDone on each new day.

-- The Fly Box title's ID (ns.TITLES, source "flybox").
local FLYBOX_TITLE
for _, title in ipairs(ns.TITLES) do
	if title.source == "flybox" then
		FLYBOX_TITLE = title.id
	end
end

-- Records a title earned on board day `day` by the Cast `castID` (tackle-board.md › Data: `titles`).
---@param state TackleBoardState
---@param earned TackleEarned
---@param titleID string
---@param day integer
---@param castID string
local function grant(state, earned, titleID, day, castID)
	state.titles[titleID] = { day = day, cast = castID }
	earned.titles[#earned.titles + 1] = titleID
end

-- Marks a goal done on the Cast's board day and pays it out, in TKB-R60's order: done and its pin freed; the tally;
-- its pay and its Activity XP (TKB-R65: by type and tier from the Tunables, never from the goal); a fly; a tally
-- title; the day lit, with a milestone's Coins and title; the Fly Box title if the box just filled. Returns what it
-- earned.
---@param state TackleBoardState
---@param goal TackleGoal
---@param cast PagleCast the completing Cast
---@return TackleEarned
local function complete(state, goal, cast)
	local day, castID = state.day, cast.id
	goal.doneDay, goal.doneTime, goal.doneCast = day, cast.time, castID
	ns.FreePin(state, goal)
	local xp = goal.type == "e" and ns.EXPEDITION_XP or ns.NOTICE_XP[goal.tier]
	---@type TackleEarned
	local earned = { pay = goal.pay, coins = goal.pay, xp = xp, titles = {}, lit = false }
	local tallyTitle = ns.Tally.Add(state.tally, goal.type)
	state.coins = state.coins + goal.pay
	state.xp = state.xp + xp
	local wasFull = ns.FlyBox.IsFull(state.flies)
	earned.fly = ns.FlyBox.Tie(state.flies, goal)
	if tallyTitle then
		grant(state, earned, tallyTitle, day, castID)
	end
	local lit = ns.Campfire.Light(state.fire, day, castID)
	earned.lit = lit.lit
	local milestone = lit.milestone
	if milestone then
		state.coins = state.coins + milestone.coins
		earned.coins = earned.coins + milestone.coins
		earned.milestone = milestone
		grant(state, earned, milestone.title, day, castID)
	end
	if not wasFull and ns.FlyBox.IsFull(state.flies) then
		grant(state, earned, FLYBOX_TITLE, day, castID)
	end
	return earned
end

--- Drops the goals completed more than the kept history ago (tackle-board.md › Data; ns.KEPT_DAYS, 28 board days):
--- `goals` keeps the open ones and those done on the projection's day and the 27 before it, as the Campfire's
--- four-week log does (TKB-R106). The tally, flies and titles keep what the board needs from the rest. AdvanceTo
--- calls it on each new day, so a goal a rebuild completes that far back is gone before `done` (TKB-R84).
---@param state TackleBoardState
function ns.PruneDone(state)
	local oldest = state.day - ns.KEPT_DAYS
	local goals = state.goals
	for id, goal in pairs(goals) do
		if goal.doneDay ~= nil and goal.doneDay <= oldest then
			goals[id] = nil
		end
	end
end

--- Runs one Cast through the board's goals and the ever-caught set (TKB-R40–R46, TKB-R60): for a caught Cast after
--- Start, ns.EnterCast on every open goal, then for each Catch in item order ns.CountCatch on the open goals in board
--- order, completing a goal at the Catch that brings it to its need; each Catch's item then joins `caught`. Every
--- completion goes to ns.outlets.Completed with `mode`. Returns whether the state changed.
---@param state TackleBoardState
---@param cast PagleCast
---@param mode TackleApplyMode
---@return boolean changed
function ns.CountCast(state, cast, mode)
	if cast.outcome ~= "caught" then
		return false
	end
	local caught = state.caught
	local order = state.started and ns.BoardOrder(state) or {}
	local changed = #order > 0 -- EnterCast may reset a day-bound goal (TKB-R41)
	for _, goal in ipairs(order) do
		ns.EnterCast(goal, cast, state.day)
	end
	local pagle = ns.api.pagle
	---@type TackleProgressContext
	local ctx = {
		pagle = pagle,
		caughtBefore = function(itemID)
			return caught[itemID] == true
		end,
		day = state.day,
	}
	for _, slot in ipairs(cast.items) do
		local completed = false
		for _, goal in ipairs(order) do
			if goal.doneDay == nil and ns.CountCatch(goal, cast, slot, ctx) then
				changed = true
				if ns.IsComplete(goal, pagle) then
					completed = true
					ns.outlets.Completed(goal, cast, complete(state, goal, cast), mode)
					if mode == "live" then
						ns.Redraw("completed", goal.id) -- the tracker flashes its line (TKB-R123)
					end
				end
			end
		end
		-- TKB-R46: a later Catch sees this one as caught before it
		if slot.itemID ~= 0 and not caught[slot.itemID] then
			caught[slot.itemID] = true
			changed = true
		end
		if completed then
			order = ns.BoardOrder(state) -- a freed pin may have changed it (TKB-R101)
		end
	end
	return changed
end
