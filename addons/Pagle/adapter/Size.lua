---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Simulated Size (LOG-R65–R68): logic/Size.lua computes it, and the Catch log puts it on every Cast it decodes
-- (logic/CatchLog.lua, over the catalogue, ns.CatalogueItem). What Modules read of it, Pagle.SIZE_BANDS (a copy of
-- Core's), Pagle.SIZE_RULES_VERSION and Pagle.FormatLength (LOG-R69, logic/Length.lua), is published by ns.PublishSize
-- (logic/Wiring.lua) in Core's login step 1 (adapter/Login.lua), not as this file loads: the bands' names are read from
-- ns.L, which a file must not do while it loads (CORE-R8).

--- Publishes Simulated Size on `Pagle`: login step 1 calls it (adapter/Login.lua).
function ns.PublishSizeAtLogin()
	ns.PublishSize(Pagle, ns.host)
end
