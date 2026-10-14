if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' goods on the client (HNT-R120–R122, HNT-R70): registered with Core, previewed on the Curio Shop's stage, and
-- the looks the board's leather and the tracker's frame wear.

--- Registers Hunts' slots and goods (HNT-R120, HNT-R121, SHOP-R21), from OnInitialize right after RegisterModule
--- (HNT-R122).
---@param module PagleModuleHandle
function ns.RegisterGoods(module)
	for _, entry in ipairs(ns.HuntsGoods(function() end)) do
		module:RegisterSlot(entry.slot)
		for _, good in ipairs(entry.goods) do
			module:RegisterGood(good)
		end
	end
end
