---@class PagleNS
local ns = select(2, ...)

-- The wallet projection (ADR 0009, wallet-and-shop.md › Spending, SHOP-R10, SHOP-R11, LOG-R78): Core's second
-- projection over the Catch log, keeping the Coins spent and the goods purchased from its purchase entries (U1), and
-- handing both to the wallet and the goods registry. Pure logic, everything passed in (CORE-R7); logic/Wiring.lua
-- binds Core's one.

--- The wallet rules version (wallet-and-shop.md › Data): a change rebuilds the projection (LOG-R72).
ns.WALLET_RULES_VERSION = 1

--- What the wallet projection stores in PagleDB.global.projections.wallet (wallet-and-shop.md › Data).
---@class PagleWalletState
---@field spent integer                    -- the price paid in each counted purchase, summed
---@field purchased table<string, true>    -- every good purchased, by ID

--- What the wallet projection is fed (logic/Wiring.lua, for Core's adapter and FakePagle alike).
---@class PagleWalletProjectionOptions
---@field projections PagleProjections   -- Core's projection machinery
---@field db table                         -- PagleDB.global.projections.wallet
---@field iterate fun(afterSeq: integer?): fun(): PagleRecord? -- the log's records (Pagle.IterateCatches)
---@field wallet PagleWallet               -- takes the spent total (SHOP-R12)
---@field goods PagleGoods                 -- takes the purchased set (SHOP-R30)

-- A fresh, empty state: nothing spent or purchased.
---@return PagleWalletState
local function reset()
	return { spent = 0, purchased = {} }
end

-- Counts one record (SHOP-R10, SHOP-R11): the first U1 for a good adds the price it stores, the price paid, to
-- `spent` and the good to `purchased`; a later one for the same good is ignored, so nothing costs twice. Every other
-- kind, Casts and their Uncharted Catches too, concerns no wallet (SHOP-R96). Returns whether it counted.
---@param state PagleWalletState
---@param record PagleRecord
---@return boolean
local function count(state, record)
	if record.kind ~= "purchase" then
		return false
	end
	---@cast record PaglePurchase
	local good = record.good
	if state.purchased[good] then
		return false
	end
	state.purchased[good] = true
	state.spent = state.spent + record.price
	return true
end

-- A copy of a purchased set, for the goods registry to keep while the state it came from changes on (SHOP-R34).
---@param purchased any
---@return table<string, true>
local function copySet(purchased)
	local copy = {}
	if type(purchased) == "table" then
		for good in pairs(purchased) do
			if type(good) == "string" then
				copy[good] = true
			end
		end
	end
	return copy
end

--- Binds the wallet projection on Core's machinery (LOG-R78) to `options.db`, with the wallet rules version and no
--- extraFingerprint, and hands the wallet and the goods registry what it stored: so the balance and ownership hold
--- steady while it catches up or rebuilds (SHOP-R34). Each catch-up or rebuild hands over its new spent total and
--- purchased set in its done, never before, and each live purchase that counts hands them over at once. Nothing is
--- ever revoked but by the log: a purchase lost with its session is simply not owned (SHOP-R94). No rule here
--- depends on the daily or weekly reset (SHOP-R95).
---@param options PagleWalletProjectionOptions
---@return PagleProjection
function ns.AddWalletProjection(options)
	local wallet, goods = options.wallet, options.goods

	-- Hands a state's spent total and a copy of its purchased set over. The wallet fires BalanceChanged only if the
	-- balance or held changes, and the registry fires AppearanceChanged for each look a purchase changes (SHOP-R33).
	---@param state table
	local function publish(state)
		wallet:SetSpent(tonumber(state.spent) or 0)
		goods:SetPurchased(copySet(state.purchased))
	end

	local stored = options.db.projection
	if type(stored) == "table" then
		publish(stored)
	end

	return ns.AddCoreProjection(options.projections, ns.WalletProjectionDef(options.db, publish), options.iterate)
end

--- The wallet projection's def (LOG-R70) over `db`: each live purchase that counts, and each done, hands the state
--- to `publish`.
---@param db table PagleDB.global.projections.wallet, or a table of the caller's making
---@param publish fun(state: PagleWalletState)
---@return PagleProjectionDef
function ns.WalletProjectionDef(db, publish)
	return {
		db = db,
		rulesVersion = ns.WALLET_RULES_VERSION,
		reset = reset,
		apply = function(state, record, mode)
			if count(state, record) and mode == "live" then
				publish(state)
			end
		end,
		done = function(state)
			publish(state)
		end,
	}
end

--- Core's own projections for Pagle's backend (#223): its projection driver folds the Catch log through logic/ alone,
--- without adapter/ (CORE-R7). Calls `newProjection(name, def)` for each of Core's projections (LOG-R78) the backend
--- folds, named by its PagleDB.global.projections key, each over a table of its own making: the wallet's ("wallet"),
--- whose state carries the Coins spent (SHOP-R11). The Field report's is left out: its input, the diagnostics buffer,
--- never leaves the client (LOG-R82).
---@param newProjection fun(name: string, def: PagleProjectionDef)
function ns.BindCoreProjections(newProjection)
	newProjection("wallet", ns.WalletProjectionDef({}, function() end))
end
