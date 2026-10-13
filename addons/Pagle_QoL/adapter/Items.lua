if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Item names from the client (QOL-R54: the lure table's names come from C_Item at runtime). The client knows an
-- item's name only once its data has loaded, so QoL asks for every lure's at load, and asks again for any name it
-- reads before then.

for _, lure in ipairs(ns.LURES) do
	C_Item.RequestLoadItemDataByID(lure.itemID)
end

--- An item's name in the client's language, or nil while its data hasn't loaded (it is asked for then).
---@param itemID integer
---@return string?
function ns.ItemName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return name
end
