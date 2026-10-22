---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's Activity XP (ADR 0011, core/activity-xp.md): the paying Modules report their lifetime totals, Core keeps the
-- last of each in PagleDB.global.activityXP.earned, tied to the log's logId, and snapshots their sum into every
-- Prestige entry (AXP-R5). Only the Ledger reads them, for the Angler Level (AXP-R1).

--- Core's Activity XP as ns.activityXP, with M:ReportXPEarned on every Module handle (logic/Wiring.lua). Login step 1
--- opens the stored totals (ns.OpenActivityXP).
ns.WireActivityXP(ns.host)

--- Core's Activity XP now (AXP-R6): `total`, the sum of every Module's last reported total, and `bySource`, each
--- Module that has reported, by def.name, with its total and `enabled`, false for a Module that is off or not loaded
--- this session (CORE-R41), whose total still counts (AXP-R90). A fresh table each call.
---@return ActivityXP
function Pagle.GetActivityXP()
	return ns.activityXP:Get()
end
