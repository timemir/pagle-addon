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

--- What going from level `level` to the next costs (LED-R30, Tunables): 1,000 + 80 × L. The Prestige factor comes in
--- M4.
---@param level integer
---@return integer
function ns.StepCost(level)
	return 1000 + 80 * level
end

--- The climb `xp` covers (LED-R30): the level, 1 plus the steps covered, at most 60; then below 60 the XP into the
--- level and the next step's cost, at 60 the carried XP (kept, unused until Prestige) and no cost.
---@param xp integer the climb's XP (LED-R31)
---@return integer level
---@return integer into XP into the level, or the carried XP at 60
---@return integer? cost the next step's cost; nil at 60
function ns.ClimbOf(xp)
	local level = 1
	while level < ns.LEVEL_CAP do
		local cost = ns.StepCost(level)
		if xp < cost then
			return level, xp, cost
		end
		xp = xp - cost
		level = level + 1
	end
	return level, xp, nil
end

--- The climb's computed level (LED-R30).
---@param state LedgerState
---@return integer
function ns.Level(state)
	return (ns.ClimbOf(state.xp))
end

--- The peak level (LED-R35): 60 once the prestige rank is above 0, else the current level.
---@param state LedgerState
---@return integer
function ns.PeakLevel(state)
	if state.prestige > 0 then
		return ns.LEVEL_CAP
	end
	return ns.Level(state)
end
