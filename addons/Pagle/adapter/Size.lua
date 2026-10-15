---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Simulated Size (LOG-R65–R68): logic/Size.lua computes it, and the Catch log puts it on every Cast it decodes
-- (logic/CatchLog.lua, over the catalogue, ns.CatalogueItem). Here Core publishes what Modules read of it, and how a
-- length reads (LOG-R69, logic/Length.lua).

--- Pagle.SIZE_BANDS (a copy of Core's), Pagle.SIZE_RULES_VERSION and Pagle.FormatLength (logic/Wiring.lua).
ns.PublishSize(Pagle, ns.host)
