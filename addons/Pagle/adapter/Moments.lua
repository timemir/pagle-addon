---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Moments and one Announcement per Cast (announcements.md › Moments and the ladder, › One Announcement per Cast;
-- ADR 0007) on the client: logic/Wiring.lua's collector over adapter/Host.lua's host, with frames through
-- C_Timer.After and dropped moments reported through geterrorhandler() (ANN-R4).

--- Core's one collector, as ns.moments, with M:RaiseMoment on every Module handle. Each Announcement goes to the
--- lanes adapter/Announcements.lua makes (ANN-R20), and every moment Core keeps to ns.summary (ANN-R25).
ns.WireMoments(ns.host, function(announcement)
	ns.lanes:Push(announcement)
end)

--- Core's catch toast for each live caught Cast (ANN-R13), named as the client has the item cached; a secret is never
--- a name (CORE-R31).
ns.WireCatchToasts(ns.host, function(itemID)
	return ns.UnlessSecret(issecretvalue, (C_Item.GetItemNameByID(itemID)))
end)
