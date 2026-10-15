if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- Start my board and the live step (TKB-R5, TKB-R13): with adapter/Reroll.lua, the only live code that appends the
-- Tackle Board's records (TKB-R80): the start, day and issue records here, the reroll there. The step runs on the
-- frame after the projection's done, never inside it (LOG-R40), and at each daily reset while logged in, through one
-- reset timer. The rules are logic's: the days (logic/Days.lua), the advance (logic/Projection.lua) and generation
-- (logic/Generate.lua), over ns.api and ns.random (adapter/Client.lua).
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

local resetTimer -- the one reset timer, or nil before the first live step

--- Arms the reset timer (TKB-R13): one timer that runs the live step after `seconds`, cancelling any earlier one.
--- A one-shot C_Timer ticker, as C_Timer.NewTimer makes. Firing while the projection is updating, the step does
--- nothing; the next done schedules it (TKB-R195).
---@param seconds number
function ns.ArmResetTimer(seconds)
	if resetTimer then
		resetTimer:Cancel()
	end
	resetTimer = C_Timer.NewTicker(seconds, function(ticker)
		ticker:Cancel()
		ns.LiveStep()
	end, 1)
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

local scheduled = false -- a step is waiting for the next frame

-- The scheduled step: on a frame where the projection is still updating (after a chunked build's done, Core applies
-- the entries appended during it in later frames, LOG-R74), it waits another frame, so the step reads them back
-- first and issues every goal owed (TKB-R13).
local function scheduledStep()
	if ns.IsUpdating() then
		C_Timer.After(0, scheduledStep)
		return
	end
	scheduled = false
	ns.LiveStep()
end

--- Schedules the live step for the next frame on which the projection isn't updating (TKB-R13, TKB-R84): the
--- projection's done calls it last. Calls made before it runs share its one step.
function ns.ScheduleLiveStep()
	if scheduled then
		return
	end
	scheduled = true
	C_Timer.After(0, scheduledStep)
end
