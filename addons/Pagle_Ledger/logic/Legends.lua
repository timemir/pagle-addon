if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Legends (LED-R63), the fold's part: a Legend Catch (LED-R5's Legend class) counts toward the base and Legends only,
-- never also as a Species. Its item's first Catch and count are kept in `state.items` (ledger.md › Data); the counter
-- is computed from the world (logic/World.lua). Pure logic, everything passed in (CORE-R7).

-- A Legend item's first Catch earns 2,000 XP (LED-R20) and 100 Coins (LED-R88, Tunables).
local LEGEND_XP = 2000
--- Coins for a Legend item's first Catch (LED-R88); its `legend` moment pays them (LED-R97).
ns.LEGEND_COINS = 100

--- A Legend Catch (LED-R63): its item's count and first Catch, as a LedgerFirst in `state.items`. The first Catch of
--- each Legend item earns 2,000 XP, 100 Coins and a `legend` achievement, with the Catch's size for its moment
--- (LED-R81); later ones only the base the fold gives.
---@param state LedgerState
---@param record PagleCast
---@param itemID integer
---@param earned LedgerAchievement[]
---@param size PagleSize? the Catch's Simulated Size (LOG-R65)
function ns.CreditLegend(state, record, itemID, earned, size)
	local entry = state.items[itemID]
	if entry then
		entry.n = entry.n + 1
		return
	end
	entry = ns.FirstCatch(record)
	entry.n = 1
	state.items[itemID] = entry
	state.xp = state.xp + LEGEND_XP
	state.coins = state.coins + ns.LEGEND_COINS
	earned[#earned + 1] =
		{ kind = "legend", cast = record.id, coins = ns.LEGEND_COINS, itemID = itemID, size = ns.CopySize(size) }
end
