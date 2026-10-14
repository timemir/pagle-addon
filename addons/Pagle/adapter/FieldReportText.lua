---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field report's text on the client (field-report.md › Format): logic/FieldReportText.lua's rules over the
-- lookups only the client has.

-- The names a row's comment shows, in the player's locale (REP-R30). A secret is never a name (CORE-R31).
---@type PagleReportNames
local NAMES = {
	-- nil until the client has cached the item.
	item = function(itemID)
		return ns.UnlessSecret(issecretvalue, (C_Item.GetItemInfo(itemID)))
	end,
	area = function(areaID)
		return ns.UnlessSecret(issecretvalue, (C_Map.GetAreaInfo(areaID)))
	end,
}

--- The Field report's text for `rows` (ns.FieldReportRows(), any order), as its parts in order (REP-R30–R33): the
--- header from this addon's TOC version, `Pagle.CONTENT_FINGERPRINT`, `GetLocale()` and PagleLog's logId, which is
--- written only as its reporter key (REP-R35, REP-R36). Built when called, never stored.
---@param rows PagleReportRow[]
---@return string[]
function ns.FieldReportText(rows)
	return ns.FieldReportParts(rows, {
		addon = C_AddOns.GetAddOnMetadata("Pagle", "Version") or "unknown",
		fingerprint = Pagle.CONTENT_FINGERPRINT,
		locale = GetLocale(),
		logId = ns.catchLog.data.logId or "",
	}, NAMES)
end
