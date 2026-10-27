---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The goods registry (ADR 0009, wallet-and-shop.md › Goods, Owning and equipping): Modules and Core register the
-- looks for their own views, Core caches them in PagleDB.global.goods and keeps each slot's pick in
-- PagleDB.profile.appearance, and views redraw on AppearanceChanged.

--- Core's one goods registry, as ns.goods, with M:RegisterSlot, M:RegisterGood and M:RefreshGoods on every Module
--- handle and ns.RegisterCoreSlot / ns.RegisterCoreGood for Core's own (logic/Wiring.lua).
ns.WireGoods(ns.host)

--- Pagle.IsOwned, GetEquipped, SetEquipped, GetGood and the rest of SHOP-R36's reads over ns.goods, and
--- Pagle.DrawGoodPreview over adapter/GoodPreview.lua's drawing (logic/Wiring.lua).
ns.PublishGoods(Pagle, nil, function(frame, goodID, size)
	ns.DrawGoodPreview(frame, goodID, size)
end)
