---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Pagle Coins wallet (ADR 0009, wallet-and-shop.md › Earning): Modules report what they have earned, Core keeps
-- the last total of each in PagleDB.global.coins.earned and shows the balance. Core itself pays nothing (SHOP-R1),
-- and earning makes no Announcement of its own (SHOP-R5).

--- Core's one wallet. Empty until login step 1 opens the stored totals (ns.OpenWallet).
ns.wallet = ns.NewWallet(ns.Fire)

--- Login step 1, once PagleDB is open: the wallet reads and writes the stored totals from now on (SHOP-R3).
function ns.OpenWallet()
	ns.wallet:Open(ns.db.global.coins.earned)
end

---@class PagleModuleHandle
local ModuleHandle = ns.ModuleHandle

--- Reports the Module's lifetime Coins earned (SHOP-R2): see ns.ReportCoinsEarnedMethod. Raises an error for
--- anything but a whole number, 0 or more.
ModuleHandle.ReportCoinsEarned = ns.ReportCoinsEarnedMethod(ns.Modules, ns.wallet)

--- The Angler's Pagle Coins (SHOP-R12): Σ earned − spent, 0 and `held` while negative, and each Module's total.
---@return Balance
function Pagle.GetBalance()
	return ns.wallet:Get()
end
