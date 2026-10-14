---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The wallet projection on the client (wallet-and-shop.md › Spending, LOG-R78): logic/WalletProjection.lua's, bound
-- in PagleDB.global.projections.wallet on Core's projection machinery over Pagle.IterateCatches. It hands the wallet
-- (adapter/Wallet.lua) the Coins spent and the goods registry (adapter/Goods.lua) the purchased set, so
-- Pagle.GetBalance and Pagle.IsOwned follow every purchase entry (SHOP-R11) and hold steady while it updates
-- (SHOP-R34).

--- ns.StartWalletProjection, which adapter/Login.lua calls at login step 1, after the Field report's (LOG-R1, LOG-R78).
ns.WireWalletProjection(ns.host)
