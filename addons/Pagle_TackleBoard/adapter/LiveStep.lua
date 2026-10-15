if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- When the live step runs (TKB-R13): on the frame after the projection's done, never inside it (LOG-R40), and at each
-- daily reset while logged in, through one reset timer. The step itself is logic/LiveStep.lua's.

local scheduled = false -- a step is waiting for the next frame

--- Schedules the live step for the next frame (TKB-R13, TKB-R84): the projection's done calls it last. Calls made
--- before that frame share its one step.
function ns.ScheduleLiveStep()
	if scheduled then
		return
	end
	scheduled = true
	C_Timer.After(0, function()
		scheduled = false
		ns.LiveStep()
	end)
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
