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

--- The Size bands in order, `{ key, name }`, Tiddler to Monster (LOG-R67). The names are drafts for the lore pass.
Pagle.SIZE_BANDS = {}
for band, entry in ipairs(ns.SIZE_BANDS) do
	Pagle.SIZE_BANDS[band] = { key = entry.key, name = entry.name }
end

--- Changes whenever the size multipliers change; a Module that stores sizes folds it into its rules version
--- (LOG-R68).
Pagle.SIZE_RULES_VERSION = ns.SIZE_RULES_VERSION

--- A length of `mm` millimetres in the Angler's length unit, to 0.1 of it: "34.2 cm" or "13.5 in" (LOG-R69). The unit
--- is PagleDB.profile.lengthUnit, or inches on region 1 and centimetres elsewhere. It changes only what a length
--- reads: compare lengths in millimetres.
---@type fun(mm: number): string
Pagle.FormatLength = ns.WireLength(ns.host)
