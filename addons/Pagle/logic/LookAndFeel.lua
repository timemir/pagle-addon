---@class PagleNS
local ns = select(2, ...)

-- The Look and Feel page and the slot dropdowns as data (settings.md SET-R30, SET-R50, SET-R51; CORE-R42;
-- wallet-and-shop.md › UI): which slots show under which header, a slot's owned choices and how many more the Curio
-- Shop has. Pure logic over the goods registry (CORE-R7); adapter/LookAndFeel.lua makes native rows of it.

--- One header's slots on Look and Feel.
---@class PagleLookSection
---@field category string        -- the slot category, as registered ("Fish Journal")
---@field slots PagleRegisteredSlot[]

--- Look and Feel's sections (SET-R50): for each slot category in ns.SLOT_CATEGORY_ORDER that has a slot of Core or of
--- a Module On, its slots, Core's first, then by def.order. A Module that isn't On has no slots here (SET-R4), and a
--- slot with no goods yet has nothing to pick, so it isn't shown.
---@param goods PagleGoods
---@return PagleLookSection[]
function ns.LookAndFeelSections(goods)
	local byCategory = {}
	for _, slot in ipairs(goods:Slots()) do
		if #slot.goods > 0 then
			local list = byCategory[slot.category] or {}
			byCategory[slot.category] = list
			list[#list + 1] = slot
		end
	end
	local sections = {}
	for _, category in ipairs(ns.SLOT_CATEGORY_ORDER) do
		if byCategory[category] then
			sections[#sections + 1] = { category = category, slots = byCategory[category] }
		end
	end
	return sections
end

--- Core's slots in the "Announcements" category that have goods, in registration order: the rows that end Core's
--- rows on the Announcements page (CORE-R42, SET-R30).
---@param goods PagleGoods
---@return PagleRegisteredSlot[]
function ns.CoreAnnouncementSlots(goods)
	local list = {}
	for _, slot in ipairs(goods:Slots()) do
		if slot.module == "Core" and slot.category == "Announcements" and #slot.goods > 0 then
			list[#list + 1] = slot
		end
	end
	return list
end

--- A slot dropdown's options (SET-R51): the slot's owned goods (SHOP-R30), by name, in registration order.
---@param goods PagleGoods
---@param slotID string
---@return { value: string, label: string }[]
function ns.SlotChoices(goods, slotID)
	local choices = {}
	for _, good in ipairs(goods:GoodsOf(slotID)) do
		if goods:IsOwned(good.id) then
			choices[#choices + 1] = { value = good.id, label = good.name }
		end
	end
	return choices
end

--- N in a slot dropdown's "{N} more in the Curio Shop" (SET-R51): the slot's for-sale goods not owned.
---@param goods PagleGoods
---@param slotID string
---@return integer
function ns.SlotMoreInShop(goods, slotID)
	local more = 0
	for _, good in ipairs(goods:GoodsOf(slotID)) do
		if good.tier and not goods:IsOwned(good.id) then
			more = more + 1
		end
	end
	return more
end
