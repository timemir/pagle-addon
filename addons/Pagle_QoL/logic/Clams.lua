if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Clams on the Fishing key (QOL-R55, QOL-R56): which clam opens next. Pure logic, everything passed in (CORE-R7);
-- adapter/Clams.lua reads the bags.

--- The clam the Fishing key opens next (QOL-R55): while *Open clams between Casts* is on, the available clam with the
--- lowest item ID; otherwise none. Only the clam table's items are ever picked (QOL-R57, QOL-R96).
---@param on boolean *Open clams between Casts* (QOL-R56)
---@param isAvailable fun(itemID: integer): boolean in the bags and usable (QOL-R55)
---@return integer? itemID
function ns.ChooseClam(on, isAvailable)
	if not on then
		return nil
	end
	local lowest
	for _, itemID in ipairs(ns.CLAMS) do
		if (not lowest or itemID < lowest) and isAvailable(itemID) then
			lowest = itemID
		end
	end
	return lowest
end
