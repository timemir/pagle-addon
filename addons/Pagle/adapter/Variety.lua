---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Fish varieties (VAR-R1–R5): logic/Variety.lua computes a Catch's, and the Catch log puts it on every Cast it decodes
-- beside the size (logic/CatchLog.lua, over the catalogue, ns.CatalogueItem). Pagle.GetVarieties comes with the
-- catalogue (adapter/Catalogue.lua). Pagle.VARIETY_RARITIES, a copy of Core's, is published by ns.PublishVarieties
-- (logic/Wiring.lua) in Core's login step 1 (adapter/Login.lua), not as this file loads: the rarities' names are read
-- from ns.L, which a file must not do while it loads (CORE-R8).

--- Publishes the variety rarities on `Pagle`: login step 1 calls it (adapter/Login.lua).
function ns.PublishVarietiesAtLogin()
	ns.PublishVarieties(Pagle)
end
