---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Session summary's data on the client (announcements.md › Session summary): logic/Wiring.lua's summary over
-- PagleDB.global, fed every moment Core keeps and the Session events on its own owner, "Pagle summary".

--- Core's one Session summary, as ns.summary, with M:SetSummaryLine on every Module handle. It reads PagleDB.global
--- at each call, so it works from the moment login step 1 has opened PagleDB, before any Module can raise a moment or
--- set a line. The open Session's summary takes every moment Core keeps, popped up or not (ANN-R25), or
--- `global.pending` with none open (ANN-R50, ANN-R52). The count Cozy mode kept shows on the compartment entry's
--- label (CORE-R51): adapter/Menu.lua's, looked up when called.
ns.WireSummary(ns.host, function()
	ns.UpdateCompartmentText()
end)
