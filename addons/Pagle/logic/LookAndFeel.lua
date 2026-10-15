---@class PagleNS
local ns = select(2, ...)

-- The Look and Feel page and the slot dropdowns as data (settings.md SET-R30, SET-R50, SET-R51; CORE-R42;
-- wallet-and-shop.md › UI): which slots show under which header, a slot's owned choices and how many more the Curio
-- Shop has. Pure logic over the goods registry (CORE-R7); adapter/LookAndFeel.lua makes native rows of it.

--- Look and Feel's sections (SET-R50): for each slot category in ns.SLOT_CATEGORY_ORDER that has a slot of Core or of
--- a Module On, its slots, Core's first, then by def.order. A Module that isn't On has no slots here (SET-R4), and a
--- slot with no goods yet has nothing to pick, so it isn't shown.
---@param goods PagleGoods
---@return PagleSlotSection[]
function ns.LookAndFeelSections(goods)
	return ns.SlotsByCategory(goods:SlotsWithGoods())
end

--- Core's slots in the "Announcements" category that have goods, in registration order: the rows that end Core's
--- rows on the Announcements page (CORE-R42, SET-R30).
---@param goods PagleGoods
---@return PagleRegisteredSlot[]
function ns.CoreAnnouncementSlots(goods)
	return goods:SlotsWithGoods(function(slot)
		return slot.module == ns.CORE_OWNER and slot.category == "Announcements"
	end)
end

--- The slot dropdowns Core ends each Module's section with on the topic page `topic`, by Module name: on Trackers,
--- each On Module's "Trackers"-category slots that have goods, in registration order (SET-R44, CORE-R42); on any
--- other page, none.
---@param goods PagleGoods
---@param topic string
---@return table<string, PagleRegisteredSlot[]>
function ns.SectionSlots(goods, topic)
	local byModule = {}
	if topic ~= "trackers" then
		return byModule
	end
	local trackers = goods:SlotsWithGoods(function(slot)
		return slot.module ~= ns.CORE_OWNER and slot.category == "Trackers"
	end)
	for _, slot in ipairs(trackers) do
		local list = byModule[slot.module] or {}
		byModule[slot.module] = list
		list[#list + 1] = slot
	end
	return byModule
end

--- A slot dropdown's options (SET-R51): the slot's owned goods (SHOP-R30), by name, in registration order.
---@param goods PagleGoods
---@param slotID string
---@return { value: string, label: string }[]
function ns.SlotChoices(goods, slotID)
	local choices = {}
	for _, good in ipairs(goods:OwnedOf(slotID)) do
		choices[#choices + 1] = { value = good.id, label = good.name }
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
		if goods:IsForSale(good.id) then
			more = more + 1
		end
	end
	return more
end
