---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Field report's text on the client (field-report.md › Format): logic/FieldReportText.lua's rules over the
-- lookups only the client has, through Core's wiring (ns.FieldReportTextFunction in logic/Wiring.lua), which
-- FakePagle runs too.

--- The Field report's text for `rows` (ns.FieldReportRows(), any order), as its parts in order (REP-R30–R33): the
--- header from this addon's TOC version, `Pagle.CONTENT_FINGERPRINT`, `GetLocale()` and PagleLog's logId, which is
--- written only as its reporter key (REP-R35, REP-R36). The names a row's comment shows are in the player's locale
--- (REP-R30); a secret is never a name (CORE-R31). Built when called, never stored.
ns.FieldReportText = ns.FieldReportTextFunction(ns.host, {
	addon = function()
		return C_AddOns.GetAddOnMetadata("Pagle", "Version") or "unknown"
	end,
	locale = function()
		return GetLocale()
	end,
	names = {
		-- nil until the client has cached the item.
		item = function(itemID)
			return ns.UnlessSecret(issecretvalue, (C_Item.GetItemInfo(itemID)))
		end,
		area = function(areaID)
			return ns.UnlessSecret(issecretvalue, (C_Map.GetAreaInfo(areaID)))
		end,
	},
})
