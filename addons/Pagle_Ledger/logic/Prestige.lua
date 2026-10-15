if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Prestige (LED-R30–R35): applying a Prestige entry to the state, the emblem a rank shows and when Prestige is allowed.
-- Pure logic, everything passed in (CORE-R7). The fold calls ApplyPrestige for a `prestige` record; the adapter
-- (adapter/Prestige.lua) asks the player and calls `M:RecordPrestige()`.

--- Coins for each Prestige (LED-R88), paid through its `prestige` achievement.
ns.PRESTIGE_COINS = 100

-- Prestiges with an emblem (LED-R34, Tunables): I to X, one per rank; every rank above is a Master Prestige.
local EMBLEMS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

--- What a prestige rank shows (LED-R34): its emblem, I to X (nil at rank 0), and from rank 11 on, rank − 10 stars
--- beside emblem X.
---@class LedgerPrestigeMark
---@field emblem? string  -- "I" … "X"; nil before the first Prestige
---@field stars integer   -- Master Prestige stars: rank − 10 from rank 11, else 0

--- The emblem and stars of prestige rank `rank` (LED-R34).
---@param rank integer
---@return LedgerPrestigeMark
function ns.PrestigeMark(rank)
	if rank <= 0 then
		return { stars = 0 }
	end
	return { emblem = EMBLEMS[math.min(rank, #EMBLEMS)], stars = math.max(0, rank - #EMBLEMS) }
end

--- Prestige rank `rank`'s name (LED-R34), as its moment titles it: "Prestige {I…X}", or "Master Prestige {rank − 10}"
--- from rank 11; nil before the first Prestige.
---@param rank integer
---@return string?
function ns.PrestigeName(rank)
	local mark = ns.PrestigeMark(rank)
	if not mark.emblem then
		return nil
	end
	local L = ns.L
	return mark.stars > 0 and L.MASTER_PRESTIGE_TITLE:format(mark.stars) or L.PRESTIGE_TITLE:format(mark.emblem)
end

--- Applies a Prestige entry (LED-R32), in any mode: the climb's XP becomes the carried XP (0 if the climb hadn't
--- reached 60), the prestige rank the entry's, and it earns a `prestige` achievement with its 100 Coins (LED-R88),
--- no `cast`. Nothing else in the state changes: nothing unlocked is taken away (LED-R92). The fold adds the new
--- climb's level-ups after it, as the entry's (LED-R97).
---@param state LedgerState
---@param record PaglePrestige
---@param earned LedgerAchievement[]
function ns.ApplyPrestige(state, record, earned)
	local level, into = ns.ClimbOf(state.xp, state.prestige)
	state.xp = level >= ns.LEVEL_CAP and into or 0
	state.prestige = record.rank
	state.coins = state.coins + ns.PRESTIGE_COINS
	earned[#earned + 1] = { kind = "prestige", coins = ns.PRESTIGE_COINS, rank = record.rank }
end

--- Whether the Angler may Prestige (LED-R33): only while the computed level of the climb is 60 and the projection
--- isn't updating (no state while it is).
---@param state LedgerState?
---@param updating boolean
---@return boolean
function ns.PrestigeAllowed(state, updating)
	return not updating and state ~= nil and ns.Level(state) >= ns.LEVEL_CAP
end
