if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The lure table (QOL-R54): QoL's own, hand-kept, outside the content data pipeline (qol.md › Shipped tables).
-- Names come from C_Item at runtime. Only 6529 → 263 is proven on Forever (probe B4); M8 re-verifies the rest and
-- looks for Forever's own lures (QOL-R100).

--- One lure: its item, the enchant it puts on the pole, and its fishing bonus.
---@class PagleQoLLure
---@field itemID integer
---@field enchantID integer
---@field bonus integer

--- The six Classic lures, from the Classic baseline (QOL-R54).
---@type PagleQoLLure[]
ns.LURES = {
	{ itemID = 6529, enchantID = 263, bonus = 25 }, -- Shiny Bauble
	{ itemID = 6530, enchantID = 264, bonus = 50 }, -- Nightcrawlers
	{ itemID = 6811, enchantID = 264, bonus = 50 }, -- Aquadynamic Fish Lens
	{ itemID = 6532, enchantID = 265, bonus = 75 }, -- Bright Baubles
	{ itemID = 7307, enchantID = 265, bonus = 75 }, -- Flesh Eating Worm
	{ itemID = 6533, enchantID = 266, bonus = 100 }, -- Aquadynamic Fish Attractor
}
