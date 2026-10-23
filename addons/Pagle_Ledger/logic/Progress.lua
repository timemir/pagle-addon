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

-- The Prestige climb cost factor (LED-R30, Tunables): 1 in every climb, so a climb after a Prestige costs what the
-- first did (#279; 0.5 after any Prestige before LEDGER_RULES_VERSION 5).
local PRESTIGE_FACTOR = 1

--- What going from level `level` to the next costs (LED-R30, Tunables): (1,000 + 80 × L) × f, the same in every
--- climb.
---@param level integer
---@return integer
function ns.StepCost(level)
	return (1000 + 80 * level) * PRESTIGE_FACTOR
end

-- The XP a climb needs to reach each level (LED-R30): the step costs below it, summed; 0 for level 1. Made at the
-- first climb worked out, as the fold works one out several times for every Cast it applies.
---@type integer[]?
local reachAt

--- The climb `xp` covers (LED-R30): the level, 1 plus the steps covered, at most 60; then below 60 the XP into the
--- level and the next step's cost, at 60 the carried XP (unused until a Prestige carries it into the next climb,
--- LED-R32) and no cost.
---@param xp integer the climb's XP (LED-R31)
---@return integer level
---@return integer into XP into the level, or the carried XP at 60
---@return integer? cost the next step's cost; nil at 60
function ns.ClimbOf(xp)
	if not reachAt then
		reachAt = { 0 }
		for level = 1, ns.LEVEL_CAP - 1 do
			reachAt[level + 1] = reachAt[level] + ns.StepCost(level)
		end
	end
	-- The highest level whose reach `xp` covers.
	local low, high = 1, ns.LEVEL_CAP
	while low < high do
		local middle = math.ceil((low + high) / 2)
		if reachAt[middle] <= xp then
			low = middle
		else
			high = middle - 1
		end
	end
	if low == ns.LEVEL_CAP then
		return low, xp - reachAt[low], nil
	end
	return low, xp - reachAt[low], ns.StepCost(low)
end

-- Where Core's Activity XP total comes from: none until ns.SetActivityXPSource gives one.
---@type (fun(): integer)?
local activityXPSource

--- Sets where Core's Activity XP total comes from (AXP-R6, LED-R37): the adapter passes one reading
--- `Pagle.GetActivityXP().total` (adapter/Ledger.lua), as Pagle's backend may, the way it sets ns.world. Nil sets none
--- again, so logic/ alone reads a climb of the Ledger's own XP.
---@param source (fun(): integer)?
function ns.SetActivityXPSource(source)
	activityXPSource = source
end

--- Core's Activity XP total now (AXP-R6, LED-R37), from the source ns.SetActivityXPSource set, 0 without one. Read
--- whenever the level is worked out, never stored (ADR 0011); the fold never reads it.
---@return integer
function ns.ActivityXPTotal()
	return activityXPSource and activityXPSource() or 0
end

--- The current climb's Activity XP (LED-R37): `max(0, total − s)`, with `s` the `activityXP` of the latest Prestige
--- entry the state applied (0 before the first, AXP-R5). Never below 0, so a total recounted lower (AXP-R4) never
--- takes XP from the Ledger's own.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return integer
function ns.ClimbActivityXP(state, total)
	return math.max(0, (total or ns.ActivityXPTotal()) - (state.prestigeActivityXP or 0))
end

--- The climb's XP (LED-R31): the state's own XP of the climb (the Ledger's own since the latest Prestige, plus the
--- carried XP) and the climb's Activity XP, which Fresh Water never doubles (LED-R22, AXP-R8).
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return integer
function ns.ClimbXP(state, total)
	return state.xp + ns.ClimbActivityXP(state, total)
end

--- The state's climb now (LED-R30, LED-R38): ns.ClimbOf over the climb's XP, its Activity XP included.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return integer level
---@return integer into XP into the level, or the carried XP at 60
---@return integer? cost the next step's cost; nil at 60
function ns.Climb(state, total)
	return ns.ClimbOf(ns.ClimbXP(state, total))
end

--- The climb's computed level (LED-R30, LED-R38), its Activity XP included.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return integer
function ns.Level(state, total)
	return (ns.Climb(state, total))
end

--- The level the climb's own XP reaches alone, without its Activity XP (LED-R31): the fold keeps the Coins of its
--- levels in the state, and the levels the Activity XP adds above it are worked out (ns.CoinsEarned, LED-R38).
---@param state LedgerState
---@return integer
function ns.OwnLevel(state)
	return (ns.ClimbOf(state.xp))
end

--- The peak level (LED-R35): 60 once the prestige rank is above 0, else the current level. Level rewards follow it,
--- so a Prestige never takes them away.
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@return integer
function ns.PeakLevel(state, total)
	if state.prestige > 0 then
		return ns.LEVEL_CAP
	end
	return ns.Level(state, total)
end

--- The level-ups the climb's Activity XP brings (LED-R39, LED-R199): one `levelUp` for the levels above the climb's
--- own level up to the computed one, with its climb's rank and 20 Coins a level for its moment (LED-R88, LED-R97),
--- then `prestigeReady` when that is 60. `cast` is the Cast they ride on, or nil. Celebrating them raises and pays
--- only the levels above the celebrated one (logic/Moments.lua).
---@param state LedgerState
---@param total integer? Core's Activity XP total; ns.ActivityXPTotal() when nil
---@param cast string? the live Cast's entry ID (ANN-R10)
---@return LedgerAchievement[]
function ns.ActivityLevelUps(state, total, cast)
	local own, level = ns.OwnLevel(state), ns.Level(state, total)
	if level <= own then
		return {}
	end
	local levels = {}
	for raised = own + 1, level do
		levels[#levels + 1] = raised
	end
	local earned = {
		{ kind = "levelUp", cast = cast, coins = ns.LEVEL_UP_COINS * #levels, levels = levels, rank = state.prestige },
	}
	if level >= ns.LEVEL_CAP then
		earned[2] = { kind = "prestigeReady", cast = cast, coins = 0, rank = state.prestige }
	end
	return earned
end
