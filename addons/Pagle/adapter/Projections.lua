---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The projection machinery (LOG-R70–R78) on the client: logic/Projections.lua, with frames through C_Timer.After,
-- time through debugprofilestop and each Module function through securecallfunction (CORE-R21). adapter/Login.lua
-- starts it (LOG-R1 step 3); every place Core appends an entry hands the record to `ns.projections:Live` before
-- firing any event for it but the Session events (LOG-R73).

--- Core's one machinery. Core's other files use its seams: `:IsUpdating()` (any projection catching up or
--- rebuilding, or login not reached yet), `:Mode()` (the apply in progress: "live", "replay", "rebuild", "done" or
--- nil), `:WhenIdle(fn)` (runs fn once none is updating) and `:Live(record)` (hands an appended entry over).
ns.projections = ns.NewProjections({
	length = function()
		return #ns.catchLog.data.entries
	end,
	logId = function()
		return ns.catchLog.data.logId
	end,
	fingerprint = function()
		return Pagle.CONTENT_FINGERPRINT
	end,
	clock = debugprofilestop,
	nextFrame = function(step)
		C_Timer.After(0, step)
	end,
	call = securecallfunction,
})

-- M:NewProjection (LOG-R70) and M:IterateCatches (LOG-R42) on every Module handle. Until Module records (M7), a
-- Module's records are the ones Pagle.IterateCatches yields.
ns.AddProjectionMethods(ns.Modules, ns.projections, function(afterSeq)
	return Pagle.IterateCatches(afterSeq)
end)

--- Login step 3 (LOG-R1): starts every projection's catch-up or rebuild up to loginSeq (LOG-R71, LOG-R72).
function ns.StartProjections()
	ns.projections:Start(ns.loginSeq)
end
