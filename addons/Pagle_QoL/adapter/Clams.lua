if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Clams on the Fishing key (QOL-R55, QOL-R56): QoL reads the bags for the ladder's step 5 (logic/Clams.lua decides).
-- What it reads, it uses only to choose (QOL-R4). A clam waits for nothing: its loot window holds the key back
-- (QOL-R28), and it is gone from the bags once looted.

-- A clam is available when it is in the bags and usable, as a lure is (QOL-R51, QOL-R55).
---@param itemID integer
---@return boolean
local function isAvailable(itemID)
	return C_Item.GetItemCount(itemID) > 0 and C_Item.IsUsableItem(itemID) == true
end

--- The ladder's clam field (QOL-R20 step 5), read at each of the Fishing key's evaluations while armed. It has no
--- side effects, so the next-action button may read it too.
---@return integer? clam the clam QOL-R55 picks; nil while *Open clams between Casts* is off or none is available
function ns.ReadClams()
	-- QoL's OnInitialize opened PagleQoLDB before the key arms.
	return ns.ChooseClam(ns.db.profile.clams == true, isAvailable)
end
