if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What Pagle's backend reads from the Ledger's state (#223, #76 item 5): its projection driver folds the Catch log
-- through logic/ alone and computes none of these itself, so each is a function of a projection state, read through
-- the world index the projection was bound with (ns.world: the adapter's OnInitialize sets it, and ns.BindProjections
-- in the driver). Each counts what the state computes, never the celebrated set, which never leaves the client
-- (LOG-R77). Pure logic (CORE-R7).

---@class LedgerMeasures
---@field anglerLevel { prestige: integer, level: integer, xp: integer }   -- prestige rank, the climb's level and XP
---@field ledgerCompletion { percent: integer, done: integer, total: integer } -- LED-R70, the percentage floored
---@field speciesCaught integer   -- Species caught, removed ones left out (LED-R71's species part)
---@field legendsCaught integer   -- distinct Legends caught, removed ones left out (LED-R63)

-- The title view of a state alone: no celebrated set, no stored active title.
---@param state LedgerState
---@return LedgerTitleView
local function computedView(state)
	return { world = ns.world, state = state, celebrated = {}, getItem = ns.world.getItem }
end

--- The four leaderboard measures of a Ledger state: the Angler Level (LED-R30–R32), Ledger completion (LED-R70,
--- LED-R71), Species caught and Legends caught (LED-R63). Every number is a whole number, 0 or more.
---@param state LedgerState
---@return LedgerMeasures
function ns.Measures(state)
	local completion = ns.LedgerCompletion(ns.world, state)
	return {
		anglerLevel = { prestige = state.prestige, level = ns.Level(state), xp = state.xp },
		ledgerCompletion = { percent = completion.percent, done = completion.done, total = completion.total },
		speciesCaught = completion.species.done,
		legendsCaught = completion.legends.done,
	}
end

--- The title keys a Ledger state earns (LED-R75, LED-R76), in LED-R75's order: computed only, so a title the
--- celebrated set keeps after a rebalance isn't listed.
---@param state LedgerState
---@return string[]
function ns.EarnedTitles(state)
	return ns.TitleKeys(computedView(state))
end

--- The automatic title's key (LED-R77): the highest level title a Ledger state earns, or nil with none.
---@param state LedgerState
---@return string?
function ns.AutomaticTitle(state)
	return (ns.ActiveTitle(computedView(state)))
end

--- The charted zones a Ledger state ranks Master (LED-R50, LED-R71): Ledger completion's zone part.
---@param state LedgerState
---@return integer
function ns.ZonesMastered(state)
	return ns.LedgerCompletion(ns.world, state).zones.done
end

--- A Ledger state's lifetime Catches (LED-R42).
---@param state LedgerState
---@return integer
function ns.LifetimeCatches(state)
	return state.catches
end
