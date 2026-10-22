---@class PagleNS
local ns = select(2, ...)

-- The Pagle Coins wallet (ADR 0009, wallet-and-shop.md › Earning): each Module's last reported lifetime total, and
-- the balance. Pure logic, everything passed in (CORE-R7); adapter/Wallet.lua stores the totals in PagleDB.

--- What `Pagle.GetBalance()` returns and `BalanceChanged` carries (wallet-and-shop.md › Contracts).
---@class Balance
---@field balance integer         -- never negative
---@field held boolean            -- earned < spent (SHOP-R12)
---@field earned { [string]: integer }   -- by def.name

--- Fires whenever any field of the Balance changes.
---@alias PagleBalanceChangedHandler fun(event: "BalanceChanged", balance: Balance)

---@class PagleWallet
---@field private earned table<string, integer> PagleDB.global.coins.earned, by def.name (SHOP-R3)
---@field private spent integer
---@field private fire fun(event: "BalanceChanged", balance: Balance)
local Wallet = {}
Wallet.__index = Wallet

--- Why `total` can't be a Module's lifetime Coins earned, or nil if it can: a whole number, 0 or more (SHOP-R2).
---@param total any
---@return string?
function ns.CoinTotalProblem(total)
	if type(total) ~= "number" or total < 0 or total ~= math.floor(total) or total == math.huge then
		return ("M:ReportCoinsEarned takes a whole number of Coins, 0 or more; got %s"):format(tostring(total))
	end
	return nil
end

--- A wallet with nothing earned or spent, until `Open` hands it the stored totals. `fire` fires `BalanceChanged`.
---@param fire fun(event: "BalanceChanged", balance: Balance)
---@return PagleWallet
function ns.NewWallet(fire)
	return setmetatable({ earned = {}, spent = 0, fire = fire }, Wallet)
end

--- Binds the wallet to the stored totals (PagleDB.global.coins.earned), which it then reads and writes in place. A
--- total stays until its Module reports another, so a disabled or uninstalled Module's still counts (SHOP-R3).
---@param earned table<string, integer>
function Wallet:Open(earned)
	self.earned = earned
end

--- The balance now (SHOP-R12): Σ earned − spent, 0 and held while that is negative. `earned` is a copy.
---@return Balance
function Wallet:Get()
	local earned, sum = {}, 0
	for name, total in pairs(self.earned) do
		earned[name] = total
		sum = sum + total
	end
	return { balance = math.max(sum - self.spent, 0), held = sum < self.spent, earned = earned }
end

--- Stores a Module's lifetime total, taken as given, and fires `BalanceChanged` unless it equals the stored one
--- (SHOP-R2–R4). Only a later, lower report lowers a total. The caller checks it with `ns.CoinTotalProblem`.
---@param name string the Module's def.name
---@param total integer
function Wallet:Report(name, total)
	if self.earned[name] == total then
		return
	end
	self.earned[name] = total
	self.fire("BalanceChanged", self:Get())
end

--- Sets the Coins spent, firing `BalanceChanged` if the balance or `held` changes. Nothing spends before the Curio
--- Shop (M4), whose wallet projection sets it (SHOP-R11).
---@param spent integer
function Wallet:SetSpent(spent)
	local before = self:Get()
	self.spent = spent
	local after = self:Get()
	if after.balance ~= before.balance or after.held ~= before.held then
		self.fire("BalanceChanged", after)
	end
end

--- `M:ReportCoinsEarned(total)` over `wallet` (SHOP-R2, SHOP-R3), so Core's adapter and FakePagle publish one
--- method: an error at the Module's call, storing nothing, for anything but a whole number of Coins, 0 or more.
--- `stamp`, if given, runs before each total is stored: Core's wiring has the totals take the log's logId there.
---@param registry PagleModuleRegistry
---@param wallet PagleWallet
---@param stamp fun()?
---@return fun(self: PagleModuleHandle, total: integer)
function ns.ReportCoinsEarnedMethod(registry, wallet, stamp)
	return function(self, total)
		local module = registry:ModuleCalling(self, "ReportCoinsEarned", "total")
		local problem = ns.CoinTotalProblem(total)
		if problem then
			error(problem, 2)
		end
		if stamp then
			stamp()
		end
		wallet:Report(module.def.name, total)
	end
end
