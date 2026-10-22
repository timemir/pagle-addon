if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- When the run log's live step runs (HNT-R42, HNT-R151, HNT-R155): on a frame after each regroup, after
-- PushedContentReady and after each done, never inside an apply or a done (LOG-R40). The rules, and the appends, are
-- logic/RunLog.lua's. The regroup timer for a run's start or end, or a slot's turn, is adapter/Groups.lua's.
--
--   ns.runLog                    The run log (HuntsRunLog): ns.runLog:Snapshot() is this login's pushed content.
--   ns.ScheduleRunStep(afterDone) Runs the step on a later frame. Calls made before it runs share one step.

local OWNER = "Pagle_Hunts run log"

local scheduled = false -- a step is waiting for a later frame
local waits = false -- that step waits out the projection's update (it was scheduled from done)

-- The scheduled step: from a done it waits while the projection is still updating (Core applies the entries appended
-- meanwhile right after, LOG-R74), so it reads them back first; otherwise an update's own done schedules the next.
local function scheduledStep()
	if ns.IsUpdating() then
		if waits then
			C_Timer.After(0, scheduledStep)
		else
			scheduled = false
		end
		return
	end
	scheduled, waits = false, false
	local fresh = ns.runLog.snapshot == nil
	local appended = ns.runLog:Step()
	-- The runs ahead change once the snapshot is read (HNT-R160); each record appended redrew as it was applied.
	if appended and fresh then
		ns.Redraw("runs")
	end
end

--- Runs the run log's step on a later frame (HNT-R151): `afterDone` (the projection's done) waits out the update.
---@param afterDone boolean?
function ns.ScheduleRunStep(afterDone)
	waits = waits or afterDone == true
	if scheduled then
		return
	end
	scheduled = true
	C_Timer.After(0, scheduledStep)
end

--- Starts the run log, from OnInitialize once the projection is made: its step over Hunts' handle `M`, Core's pushed
--- content and the server time, run after PushedContentReady, after each done (ns.outlets.StepDue) and after each
--- regroup (ns.OnRegroup, HNT-R42).
---@param M PagleModuleHandle
function ns.StartRunLog(M)
	ns.runLog = ns.NewRunLog(M, {
		ServerTime = GetServerTime,
		CompanionState = function()
			return Pagle.GetCompanionState()
		end,
		PushedContent = function(kind)
			return Pagle.GetPushedContent(kind)
		end,
		State = ns.State,
		IsUpdating = ns.IsUpdating,
		lookups = ns.lookups,
	})
	ns.outlets.StepDue = function()
		ns.ScheduleRunStep(true)
	end
	Pagle.RegisterCallback(OWNER, "PushedContentReady", function()
		ns.ScheduleRunStep()
	end)
	ns.OnRegroup(function()
		ns.ScheduleRunStep()
	end)
end
