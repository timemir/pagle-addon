if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Catch Milestones (LED-R42), the fold's part: lifetime Catches count every Catch (LED-R5's base), and each milestone
-- is credited at the Catch that reaches it, in `state.milestones` (ledger.md › Data). Pure logic (CORE-R7).

--- Catch Milestones, ascending (LED-R42, Tunables); the Angler page names the next one (LED-R146).
ns.CATCH_MILESTONES = { 1000, 5000, 10000, 25000, 50000 }

--- Credits each Catch Milestone the lifetime Catches have reached and that isn't credited yet (LED-R42), at the Catch
--- just counted: its Cast's time in `state.milestones[n]`, and a `catchMilestone` achievement. One Catch reaches at
--- most one, but each one reached is credited. They earn no XP and no Coins (LED-R20, LED-R88).
---@param state LedgerState
---@param record PagleCast
---@param earned LedgerAchievement[]
function ns.CreditCatchMilestones(state, record, earned)
	for _, n in ipairs(ns.CATCH_MILESTONES) do
		if state.catches < n then
			return
		elseif not state.milestones[n] then
			state.milestones[n] = record.time
			earned[#earned + 1] = { kind = "catchMilestone", cast = record.id, coins = 0, n = n }
		end
	end
end
