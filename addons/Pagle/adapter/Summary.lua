---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Session summary's data on the client (announcements.md › Session summary): logic/Summary.lua over
-- PagleDB.global, fed every moment Core keeps and the Session events. Its own owner on the bus, so no other Core
-- file's registration replaces these.
local OWNER = "Pagle summary"

--- Core's one Session summary. It reads PagleDB.global at each call, so it works from the moment login step 1 has
--- opened PagleDB, before any Module can raise a moment or set a line. adapter/Moments.lua's ns.SummarizeMoment hands
--- it every moment Core keeps, popped up or not (ANN-R25): the open Session's summary takes it, or `global.pending`
--- with none open (ANN-R50, ANN-R52).
---@type PagleSummary
ns.summary = ns.NewSummary({
	global = function()
		return ns.db.global
	end,
	isOpen = function()
		return Pagle.GetSession() ~= nil
	end,
	modules = function()
		return ns.Modules:Modules()
	end,
	cozy = function()
		return ns.db.profile.announcements.cozy
	end,
})

-- ANN-R52: moments raised with no Session open join the one that starts.
Pagle.RegisterCallback(OWNER, "SessionStarted", function()
	ns.summary:Started()
end)

-- ANN-R53: a Session that raised a moment becomes a card, which shows when it can (ANN-R21); its moments are cleared
-- either way.
Pagle.RegisterCallback(OWNER, "SessionEnded", function(_, session)
	if ns.summary:Ended(session) then
		ns.cards:Next()
	end
end)

---@class PagleModuleHandle
local ModuleHandle = ns.ModuleHandle

--- Sets one of the Module's Session summary lines, or removes it with nil (ANN-R51): see ns.SetSummaryLineMethod.
--- Lines stay set across Sessions until the Module changes them, and alone never make a card.
ModuleHandle.SetSummaryLine = ns.SetSummaryLineMethod(ns.Modules, ns.summary)
