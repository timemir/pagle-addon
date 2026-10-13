---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Moments and one Announcement per Cast (announcements.md › Moments and the ladder, › One Announcement per Cast;
-- ADR 0007) on the client: logic/Moments.lua over the projection machinery's seams, with frames through
-- C_Timer.After and dropped moments reported through geterrorhandler() (ANN-R4).

--- Hands a finished Announcement to the display: the lanes adapter/Announcements.lua makes (ANN-R20).
---@param announcement PagleAnnouncement
function ns.ShowAnnouncement(announcement)
	ns.lanes:Push(announcement)
end

--- Hands every moment Core keeps to the Session summary when it is raised, shown or not (ANN-R25): Core's one
--- summary, ns.summary in adapter/Summary.lua.
---@param moment PagleRaisedMoment
function ns.SummarizeMoment(moment)
	ns.summary:Add(moment)
end

--- Core's one collector: the moments raised and not yet flushed.
ns.moments = ns.NewMoments({
	mode = function()
		return ns.projections:Mode()
	end,
	isUpdating = function()
		return ns.projections:IsUpdating()
	end,
	whenIdle = function(fn)
		ns.projections:WhenIdle(fn)
	end,
	nextFrame = function(step)
		C_Timer.After(0, step)
	end,
	report = function(message)
		geterrorhandler()(message)
	end,
	-- Looked up at each call, so the display and the summary are whatever their tickets set.
	show = function(announcement)
		securecallfunction(ns.ShowAnnouncement, announcement)
	end,
	summarize = function(moment)
		securecallfunction(ns.SummarizeMoment, moment)
	end,
})

---@class PagleModuleHandle
local ModuleHandle = ns.ModuleHandle

--- Raises a moment (ANN-R1): see ns.RaiseMomentMethod. Raises an error for an unknown rung, or no kind or title.
--- Ordinary Catches raise nothing (ANN-R13): that is each Module's choice, not Core's.
ModuleHandle.RaiseMoment = ns.RaiseMomentMethod(ns.Modules, ns.moments)
