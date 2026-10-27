---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's Refresh purse (ADR 0017, core/refresh.md): Hunts reports the Refreshes it has earned, the Tackle Board the
-- ones it has spent, and Core keeps the last total of each in PagleDB.global.tickets, tied to the log's logId. Core
-- itself pays and spends none (REF-R1), and earning makes no Announcement of its own (REF-R7).

--- Core's Refresh purse as ns.tickets, with M:ReportTicketsEarned and M:ReportTicketsSpent on every Module handle
--- (logic/Wiring.lua). Login step 1 opens the stored totals (ns.OpenTickets).
ns.WireTickets(ns.host)

--- The Refreshes the Angler holds (REF-R5, REF-R6): `tickets`, the earned total less the spent one and never below
--- 0, with the two sums. A fresh table each call.
---@return PagleTickets
function Pagle.GetTickets()
	return ns.tickets:Get()
end
