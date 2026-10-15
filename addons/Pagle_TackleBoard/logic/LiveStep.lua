if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Start my board and the live step (TKB-R5, TKB-R13): the only live code that appends the start, day and issue
-- records (TKB-R80; the reroll is logic/Reroll.lua's). Pure logic (CORE-R7): the clock and the reset API come through
-- ns.api, the draws through ns.random, Core through ns.Module and ns.GenerationContext, and the next frame and the
-- reset timer through the adapter's ns.ScheduleLiveStep and ns.ArmResetTimer (adapter/LiveStep.lua).
--
-- Each record is appended outside any apply or done (LOG-R40) while the projection isn't updating, so Core applies
-- it as "live" at once (LOG-R73): the start record has started the board, a day record has moved its boundary and an
-- issue record has lowered what is owed by the time AppendRecord returns.

-- True from login (this load) until the login's first live step has finished (TKB-R86).
local loginWindow = true

-- Issues every goal of `goalType` owed (TKB-R21), one issue record each, generated over the state as it stands, so
-- each goal sees those issued before it as open (TKB-R30–R36).
---@param goalType TackleGoalType
local function issueOwed(goalType)
	local field = goalType == "e" and "expeditions" or "notices"
	while true do
		local state = ns.State()
		local owed = state.owed[field]
		if owed <= 0 then
			return
		end
		local def = ns.GenerateGoal(ns.GenerationContext(state, ns.api.GetServerTime(), ns.random), goalType)
		ns.Module:AppendRecord("issue", ns.EncodeIssue(def))
		if ns.State().owed[field] >= owed then
			return -- the record didn't lower what is owed: never loop on it
		end
	end
end

--- The live step (TKB-R13), when the board is started and the projection isn't updating: advances the projection to
--- today (TKB-R14, "live", which may raise a Campfire nod, TKB-R86), appends a `day` record with today's live
--- boundaries if the latest boundary record isn't for today, issues every goal owed (TKB-R21: Expeditions, then
--- Notices), then updates the summary line (ns.outlets.Stepped), redraws ("step") and re-arms the reset timer for the
--- next daily reset plus the delay (Tunables). Returns whether it ran. A second step on the same day appends nothing
--- (TKB-R195).
---@return boolean ran
function ns.LiveStep()
	if not ns.IsStarted() or ns.IsUpdating() then
		return false
	end
	local state = ns.State()
	local boundary = state.boundary --[[@as TackleBoundary]]
	local today = ns.Today(boundary, ns.api) --[[@as integer]]
	ns.AdvanceTo(state, today, "live")
	if boundary.day ~= today then
		ns.Module:AppendRecord("day", ns.EncodeBoundary(ns.LiveBoundaries(ns.api)))
	end
	issueOwed("e")
	issueOwed("n")
	ns.outlets.Stepped()
	ns.Redraw("step")
	ns.ArmResetTimer(ns.SecondsToNextReset(ns.api))
	loginWindow = false
	return true
end

--- Starts the board (TKB-R5): unless the projection is updating or the board is already started, appends the
--- `start` record with the live day and week starts (TKB-R10, TKB-R11), then runs the live step, which issues the
--- first goals.
function ns.Start()
	if ns.projection == nil or ns.IsUpdating() or ns.IsStarted() then
		return
	end
	ns.Module:AppendRecord("start", ns.EncodeBoundary(ns.LiveBoundaries(ns.api)))
	ns.LiveStep()
end

--- Whether an advance now is "at login" (TKB-R86): from login until the login's first live step has finished.
---@return boolean
function ns.InLoginWindow()
	return loginWindow
end
