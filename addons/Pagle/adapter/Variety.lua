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
-- catalogue (adapter/Catalogue.lua); here Core publishes the rarities.

--- Pagle.VARIETY_RARITIES, a copy of Core's (logic/Wiring.lua).
ns.PublishVarieties(Pagle)
