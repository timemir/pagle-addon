if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The pole table (QOL-R48, from 1.7): QoL's own, hand-kept, outside the content data pipeline (qol.md › Shipped
-- tables), as the lure table is. Names come from C_Item at runtime. A fishing pole the table doesn't list counts
-- with no bonus, so a pole Forever adds is still equipped.

--- One fishing pole: its item and its Fishing bonus.
---@class PagleQoLPole
---@field itemID integer
---@field bonus integer

--- The Classic fishing poles and their Fishing bonus, read from Forever 1.60.1.70862's DB2 (each bonus is one of
--- the "Fishing Skill +N" spells it has: 15956 +3, 7823 +5, 7825 +15, 7826 +20, 8082 +25, 24301 +35) (QOL-R48).
---@type PagleQoLPole[]
ns.POLES = {
	{ itemID = 6256, bonus = 0 }, -- Fishing Pole
	{ itemID = 12225, bonus = 3 }, -- Blump Family Fishing Pole
	{ itemID = 6365, bonus = 5 }, -- Strong Fishing Pole
	{ itemID = 6366, bonus = 15 }, -- Darkwood Fishing Pole
	{ itemID = 6367, bonus = 20 }, -- Big Iron Fishing Pole
	{ itemID = 19022, bonus = 25 }, -- Nat Pagle's Extreme Angler FC-5000
	{ itemID = 19970, bonus = 35 }, -- Arcanite Fishing Pole
}
