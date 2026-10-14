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

--- Whether the Angler owns a good (SHOP-R30): a registered slot's default, a purchased good, or an earned good whose
--- cached isEarned() result is true. It reads the cache, whether or not the good's Module is enabled.
---@param goodID string
---@return boolean
function Pagle.IsOwned(goodID)
	return ns.goods:IsOwned(goodID)
end

--- The good equipped in a slot (SHOP-R32): the stored pick while it is owned and its Module enabled, else the slot's
--- default. Nil for a slot with no goods.
---@param slot string
---@return string? goodID
function Pagle.GetEquipped(slot)
	return ns.goods:GetEquipped(slot)
end

--- Equips an owned good of that slot (SHOP-R32), and returns true; returns false, changing nothing, for any other.
--- AppearanceChanged follows if the look changed (SHOP-R33).
---@param slot string
---@param goodID string
---@return boolean
function Pagle.SetEquipped(slot, goodID)
	return ns.goods:SetEquipped(slot, goodID)
end

--- A good's name, slot, icon, Module and description as cached (SHOP-R26), whether or not its Module is enabled; nil
--- for a good never registered. A fresh copy each call.
---@param goodID string
---@return PagleGoodInfo?
function Pagle.GetGood(goodID)
	return ns.goods:GetGood(goodID)
end
