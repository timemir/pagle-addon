if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' goods (HNT-R120–R122): its two slots and seven goods as data, each good's name and description from lore,
-- and the goods to register made from them. Pure logic, everything passed in (CORE-R7): adapter/Goods.lua registers
-- them, draws each preview and holds the looks the board and the tracker wear.

--- The notebook cover slot (HNT-R120): the board's leather (HNT-R70).
ns.COVER_SLOT = "hunts.notebookcover"
--- The tracker frame slot (HNT-R120): the Hunts tracker's frame (HNT-R79).
ns.TRACKER_FRAME_SLOT = "hunts.trackerframe"

local ICONS = "Interface\\Icons\\"

--- One of Hunts' goods, as data: exactly one of `default` or `tier` (SHOP-R22; Hunts has no earned goods, HNT-R122),
--- and its icon, the shop's swatch for it (HNT-R121): an in-client texture.
---@class HuntsGoodData
---@field id string
---@field default? true
---@field tier? 1|2|3 -- Tunables: notebook cover and tracker frame tiers
---@field icon string

--- One of Hunts' slots, with its goods in the order the shop lists them.
---@class HuntsSlotData
---@field id string
---@field label string -- an ns.L key
---@field category "Hunts"|"Trackers"
---@field goods HuntsGoodData[]

--- HNT-R120's slots and HNT-R121's goods, in the order they register.
---@type HuntsSlotData[]
ns.HUNTS_GOODS = {
	{
		id = ns.COVER_SLOT,
		label = "SLOT_NOTEBOOK_COVER",
		category = "Hunts",
		goods = {
			{ id = "hunts.notebookcover.leather", default = true, icon = ICONS .. "INV_Misc_LeatherScrap_05" },
			{ id = "hunts.notebookcover.oilcloth", tier = 1, icon = ICONS .. "INV_Fabric_Felcloth_Ebon" },
			{ id = "hunts.notebookcover.tooled", tier = 2, icon = ICONS .. "Trade_LeatherWorking" },
			{ id = "hunts.notebookcover.verdigris", tier = 3, icon = ICONS .. "INV_Ore_Copper_01" },
		},
	},
	{
		id = ns.TRACKER_FRAME_SLOT,
		label = "SLOT_TRACKER_FRAME",
		category = "Trackers",
		goods = {
			{ id = "hunts.trackerframe.none", default = true, icon = ICONS .. "INV_Misc_Note_02" },
			{ id = "hunts.trackerframe.inkwash", tier = 1, icon = ICONS .. "INV_Inscription_InkBlack01" },
			{ id = "hunts.trackerframe.waxseal", tier = 2, icon = ICONS .. "INV_Letter_03" },
		},
	},
}

--- A good's name (HNT-R121): its lore, `huntgood.<goodID>.name` (HNT-R130), or its ID while the key has no text
--- (graph.md open question 4).
---@param goodID string
---@return string
function ns.HuntsGoodName(goodID)
	return rawget(ns.L, "huntgood." .. goodID .. ".name") or goodID
end

--- A good's description (HNT-R121): its lore, `huntgood.<goodID>.description` (HNT-R130), or nil while it has none.
---@param goodID string
---@return string?
function ns.HuntsGoodDescription(goodID)
	return rawget(ns.L, "huntgood." .. goodID .. ".description")
end

--- What a good's preview draws on the Curio Shop's stage: `goodID`'s look in slot `slotID`.
---@alias HuntsPreview fun(stage: Frame, slotID: string, goodID: string)

--- Hunts' slots and their goods to register, in order (HNT-R120, HNT-R121): each good named from lore, its icon its
--- swatch, and its preview drawn by `preview`.
---@param preview HuntsPreview
---@return { slot: PagleSlot, goods: PagleGood[] }[]
function ns.HuntsGoods(preview)
	local list = {}
	for i, data in ipairs(ns.HUNTS_GOODS) do
		local goods = {}
		for k, good in ipairs(data.goods) do
			local slotID, goodID = data.id, good.id
			goods[k] = {
				id = goodID,
				slot = slotID,
				name = ns.HuntsGoodName(goodID),
				description = ns.HuntsGoodDescription(goodID),
				icon = good.icon,
				default = good.default,
				tier = good.tier,
				preview = function(stage)
					preview(stage, slotID, goodID)
				end,
			}
		end
		list[i] = {
			slot = { id = data.id, label = ns.L[data.label], category = data.category },
			goods = goods,
		}
	end
	return list
end
