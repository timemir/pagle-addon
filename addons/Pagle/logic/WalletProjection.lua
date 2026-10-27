---@class PagleNS
local ns = select(2, ...)

-- The wallet projection (ADR 0009, wallet-and-shop.md › Spending, SHOP-R10, SHOP-R11, LOG-R78): Core's second
-- projection over the Catch log, keeping the Coins spent and the goods purchased from its purchase entries (U1), the
-- result of each Curio crate, a good or Coins paid back (SHOP-R50–R52, logic/Crate.lua) and whether a Companion entry (K1) is in (SHOP-R29), and
-- handing them to the wallet and the goods registry. Pure logic, everything passed in (CORE-R7); logic/Wiring.lua
-- binds Core's one.

--- The wallet rules version (wallet-and-shop.md › Data): a change rebuilds the projection (LOG-R72). 2: the whole-shop
--- crate, with its payback and Curio pity (SHOP-R53). 3: each good's `ownedAt`, the time of the entry that gave it
--- (SHOP-R36).
ns.WALLET_RULES_VERSION = 3

--- What the wallet projection stores in PagleDB.global.projections.wallet (wallet-and-shop.md › Data). The crate,
--- companion and ownedAt fields are left out until a crate, a Companion entry or a purchase sets them, so a state from
--- before them reads the same as a fresh one.
---@class PagleWalletState
---@field spent integer                    -- the price paid in each counted purchase, summed
---@field purchased table<string, true>    -- every good purchased, by ID
---@field crates? (string|integer)[]      -- each crate's result in log order: the good it gave, or the Coins it paid
--- back (SHOP-R50, SHOP-R51)
---@field dry? integer                     -- crates since the last that gave a crate-only good (SHOP-R52); 0 when nil
---@field companion? true                  -- a Companion entry is applied (SHOP-R29, LOG-R37)
---@field ownedAt? table<string, integer>  -- the server time of the entry that first gave each good: its U1, or the
--- crate's U1 for a good a crate gave, never a payback's (SHOP-R36); left out until a purchase or a crate gives one

--- What the wallet projection hands Core besides the spent total and the owned set: the crates and the companion.
---@class PagleWalletSnapshot
---@field crates (string|integer)[]       -- each crate's result in log order: a good ID, or the Coins paid back
---@field dry integer                      -- crates since the last that gave a crate-only good (SHOP-R52)
---@field owned table<string, true>        -- the goods purchases and crates gave (SHOP-R51's "owned")
---@field companion boolean                -- a Companion entry is applied (SHOP-R29)

--- What the wallet projection is fed (logic/Wiring.lua, for Core's adapter and FakePagle alike).
---@class PagleWalletProjectionOptions
---@field projections PagleProjections   -- Core's projection machinery
---@field db table                         -- PagleDB.global.projections.wallet
---@field iterate fun(afterSeq: integer?, reader: string?): fun(): PagleRecord? -- the log's records (PagleHost.iterate)
---@field wallet PagleWallet               -- takes the spent total (SHOP-R12)
---@field goods PagleGoods                 -- takes the owned set: purchased and crated (SHOP-R30)
---@field published? fun(snapshot: PagleWalletSnapshot) -- hears each hand-over, after the wallet and goods have it

-- A fresh, empty state: nothing spent or purchased.
---@return PagleWalletState
local function reset()
	return { spent = 0, purchased = {} }
end

-- The goods a state's purchases and crates gave (SHOP-R51's "owned"), as a fresh set.
---@param state table
---@return table<string, true>
local function ownedBy(state)
	local owned = {}
	if type(state.purchased) == "table" then
		for good in pairs(state.purchased) do
			if type(good) == "string" then
				owned[good] = true
			end
		end
	end
	if type(state.crates) == "table" then
		for _, good in ipairs(state.crates) do
			if type(good) == "string" then
				owned[good] = true
			end
		end
	end
	return owned
end

-- Notes the server time `time` of the entry that gave `good`, unless an earlier one did already (SHOP-R36).
---@param state PagleWalletState
---@param good string
---@param time integer
local function noteOwned(state, good, time)
	local at = state.ownedAt or {}
	state.ownedAt = at
	at[good] = at[good] or time
end

-- Opens the crate `record` bought (SHOP-R50–R52): its price less what it pays back is spent, every crate's counting
-- (SHOP-R11), and the draw's result, the good or the Coins paid back, goes into `crates`, the pity's count of crates
-- since the last crate-only good going back to 0 or on by one. A good it gave is noted at the crate's time; a payback
-- gives no good and notes none (SHOP-R36).
---@param state PagleWalletState
---@param record PaglePurchase
local function openCrate(state, record)
	local dry = state.dry or 0
	local roll = ns.CrateRoll(record.id, ownedBy(state), dry, record.time, record.price)
	state.spent = state.spent + record.price - (roll.payback or 0)
	local crates = state.crates or {}
	crates[#crates + 1] = roll.good or roll.payback
	state.crates = crates
	if roll.good then
		noteOwned(state, roll.good, record.time)
	end
	state.dry = not roll.crateOnly and dry + 1 or nil
end

-- Counts one record (SHOP-R10, SHOP-R11): the first U1 for a good adds the price it stores, the price paid, to
-- `spent` and the good to `purchased`; a later one for the same good is ignored, so nothing costs twice. Each crate's
-- U1 counts and opens it (SHOP-R50). The first Companion entry marks the companion linked (SHOP-R29). Every other
-- kind, Casts and their Uncharted Catches too, concerns no wallet (SHOP-R96). Returns whether it counted.
---@param state PagleWalletState
---@param record PagleRecord
---@return boolean
local function count(state, record)
	if record.kind == "companion" then
		if state.companion then
			return false
		end
		state.companion = true
		return true
	elseif record.kind ~= "purchase" then
		return false
	end
	---@cast record PaglePurchase
	local good = record.good
	if good == ns.CRATE_ID then
		openCrate(state, record)
		return true
	elseif state.purchased[good] then
		return false
	end
	state.purchased[good] = true
	noteOwned(state, good, record.time)
	state.spent = state.spent + record.price
	return true
end

-- The goods a state's crates gave, as a fresh set (SHOP-R36's `fromCrate`): a payback's Coins are no good.
---@param state table
---@return table<string, true>
local function cratedBy(state)
	local crated = {}
	if type(state.crates) == "table" then
		for _, result in ipairs(state.crates) do
			if type(result) == "string" then
				crated[result] = true
			end
		end
	end
	return crated
end

-- The server time of each good a state's purchases and crates gave, as a fresh table (SHOP-R36); a good whose time
-- isn't a number is left out.
---@param state table
---@return table<string, integer>
local function ownedAtOf(state)
	local at = {}
	if type(state.ownedAt) == "table" then
		for good, time in pairs(state.ownedAt) do
			if type(good) == "string" and type(time) == "number" then
				at[good] = time
			end
		end
	end
	return at
end

--- What a wallet state hands Core (PagleWalletSnapshot): fresh copies, for Core to keep while the state changes on.
---@param state table
---@return PagleWalletSnapshot
function ns.WalletSnapshot(state)
	local crates = {}
	if type(state.crates) == "table" then
		for _, result in ipairs(state.crates) do
			if type(result) == "string" or type(result) == "number" then
				crates[#crates + 1] = result
			end
		end
	end
	return {
		crates = crates,
		dry = tonumber(state.dry) or 0,
		owned = ownedBy(state),
		companion = state.companion == true,
	}
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

	-- Hands a state's spent total and a copy of what its purchases and crates gave over (SHOP-R30: a crate's good is
	-- owned as a purchase is), then its snapshot to `published`. The wallet fires BalanceChanged only if the balance or
	-- held changes, and the registry fires AppearanceChanged for each look a purchase changes (SHOP-R33).
	---@param state table
	local function publish(state)
		local snapshot = ns.WalletSnapshot(state)
		wallet:SetSpent(tonumber(state.spent) or 0)
		goods:SetPurchased(ownedBy(state), ownedAtOf(state), cratedBy(state))
		if options.published then
			options.published(snapshot)
		end
	end

	local stored = options.db.projection
	if type(stored) == "table" then
		publish(stored)
	end

	return ns.AddCoreProjection(
		options.projections,
		ns.WalletProjectionDef(options.db, publish),
		options.iterate,
		"wallet"
	)
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
--- whose state carries the Coins spent (SHOP-R11), and the varieties' ("varieties"), whose state carries each
--- Species' varieties caught (VAR-R10, logic/VarietyProjection.lua). The Field report's is left out: its input, the
--- diagnostics buffer, never leaves the client (LOG-R82).
---@param newProjection fun(name: string, def: PagleProjectionDef)
function ns.BindCoreProjections(newProjection)
	newProjection("wallet", ns.WalletProjectionDef({}, function() end))
	newProjection("varieties", ns.VarietyProjectionDef({}, function() end))
end
