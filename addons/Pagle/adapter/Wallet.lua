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

--- Core's one wallet, as ns.wallet, with M:ReportCoinsEarned on every Module handle (logic/Wiring.lua). Login step 1
--- opens the stored totals (ns.OpenWallet).
ns.WireWallet(ns.host)

--- The Angler's Pagle Coins (SHOP-R12): Σ earned − spent, 0 and `held` while negative, and each Module's total.
---@return Balance
function Pagle.GetBalance()
	return ns.wallet:Get()
end

--- A test log's grant `name` (catch-log.md › Test logs): its whole number, only on a log marked `test = true`, else
--- nil. Readable from a Module's OnInitialize on: login step 1 has opened the log by then.
---@param name "devCoins"|"devXP"|"devHuntsSince"
---@return integer?
function Pagle.GetTestLogGrant(name)
	local log = ns.catchLog
	return log and ns.TestLogGrant(log.data, name) or nil
end
