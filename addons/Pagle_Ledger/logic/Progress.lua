if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- What the Ledger shows from its state, computed, never stored (ledger.md › Data): the level and XP into it, the peak
-- level and Fresh Water shown now. Pure functions of the state and what is passed in (CORE-R7), so the fold and a view
-- (or a backend running logic/ unchanged) agree.

--- Fresh Water's cap, also its value before the first Catch (LED-R22, Tunables).
ns.FRESH_WATER_CAP = 300

-- Fresh Water's refill, per hour (LED-R22, Tunables).
local FRESH_WATER_RATE = 10

--- Fresh Water `fresh`, as of time `from`, refilled up to time `to` (LED-R22, LED-R23): `min(cap, F + rate ×
--- max(0, to − from) / 3,600)`.
---@param fresh number
---@param from integer server time
---@param to integer server time
---@return number
function ns.FreshWaterAt(fresh, from, to)
	return math.min(ns.FRESH_WATER_CAP, fresh + FRESH_WATER_RATE * math.max(0, to - from) / 3600)
end

--- Fresh Water shown at server time `now` (LED-R23): the cap before the first Catch, else the refilled F, rounded down.
---@param state LedgerState
---@param now integer server time
---@return integer
function ns.FreshWaterShown(state, now)
	if not state.lastCatch then
		return ns.FRESH_WATER_CAP
	end
	return math.floor(ns.FreshWaterAt(state.fresh, state.lastCatch, now))
end

--- The level cap (LED-R30, Tunables).
ns.LEVEL_CAP = 60

-- The Prestige climb cost factor (LED-R30, Tunables): every step costs this much of its rank-0 cost after any Prestige.
local PRESTIGE_FACTOR = 0.5

--- What going from level `level` to the next costs at prestige rank `rank` (LED-R30, Tunables): (1,000 + 80 × L) × f,
--- with f = 1 at rank 0 and 0.5 after any Prestige. 1,000 + 80 × L is even, so half of it is whole too.
---@param level integer
---@param rank integer the prestige rank
---@return integer
function ns.StepCost(level, rank)
	local cost = 1000 + 80 * level
	if rank > 0 then
		return math.floor(cost * PRESTIGE_FACTOR)
	end
	return cost
end

--- The climb `xp` covers at prestige rank `rank` (LED-R30): the level, 1 plus the steps covered, at most 60; then
--- below 60 the XP into the level and the next step's cost, at 60 the carried XP (unused until a Prestige carries it
--- into the next climb, LED-R32) and no cost.
---@param xp integer the climb's XP (LED-R31)
---@param rank integer the prestige rank
---@return integer level
---@return integer into XP into the level, or the carried XP at 60
---@return integer? cost the next step's cost; nil at 60
function ns.ClimbOf(xp, rank)
	local level = 1
	while level < ns.LEVEL_CAP do
		local cost = ns.StepCost(level, rank)
		if xp < cost then
			return level, xp, cost
		end
		xp = xp - cost
		level = level + 1
	end
	return level, xp, nil
end

--- The climb's computed level (LED-R30), at the state's prestige rank.
---@param state LedgerState
---@return integer
function ns.Level(state)
	return (ns.ClimbOf(state.xp, state.prestige))
end

--- The peak level (LED-R35): 60 once the prestige rank is above 0, else the current level. Level rewards follow it,
--- so a Prestige never takes them away.
---@param state LedgerState
---@return integer
function ns.PeakLevel(state)
	if state.prestige > 0 then
		return ns.LEVEL_CAP
	end
	return ns.Level(state)
end
