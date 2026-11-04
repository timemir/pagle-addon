if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's ink XP bar (LED-R145, LED-R23's bar) as data: how far it fills, the Fresh Water stretch and the
-- words under it. Pure logic, everything passed in (CORE-R7); adapter/JournalWidgets.lua draws it.

--- The ink XP bar's contents.
---@class LedgerInkXpBar
---@field fill number                         -- the inked part, 0 to 1 of the bar
---@field fresh? { from: number, to: number } -- the Fresh Water stretch, 0 to 1 of the bar; nil without one
---@field text string                         -- "{xp} of {cost}.", or the XP set aside at 60
---@field freshText? string                   -- " Fresh Water for {F} more Catches.", drawn in blue; nil while F is 0

--- The ink XP bar for `state` at server time `now` (LED-R145): the climb's progress to the next level, with Fresh
--- Water shown now (LED-R23) as a stretch from the current XP covering `shown × CATCH_XP` XP, clipped at the bar's end. A
--- shown level above the computed one reads "0 of {that level's step}" (LED-R36). At a shown level of 60 the bar is
--- full, without Fresh Water, and reads the carried XP set aside (0 while the computed level is below 60).
---@param state LedgerState
---@param celebrated LedgerCelebrated
---@param now integer server time
---@param formatNumber fun(n: integer): string BreakUpLargeNumbers
---@return LedgerInkXpBar
function ns.InkXpBar(state, celebrated, now, formatNumber)
	local L = ns.L
	local level, into, cost = ns.Climb(state)
	local shown = ns.ShownLevel(state, celebrated)
	if shown >= ns.LEVEL_CAP then
		local carried = level >= ns.LEVEL_CAP and into or 0
		return { fill = 1, text = ns.Text(L.XP_BAR_SET_ASIDE, { carried = formatNumber(carried) }) }
	end
	if shown > level or not cost then
		into, cost = 0, ns.StepCost(shown)
	end
	local bar =
		{ fill = into / cost, text = ns.Text(L.XP_BAR_TEXT, { into = formatNumber(into), cost = formatNumber(cost) }) }
	local fresh = ns.FreshWaterShown(state, now)
	if fresh > 0 then
		bar.fresh = { from = bar.fill, to = math.min(1, (into + fresh * ns.CATCH_XP) / cost) }
		bar.freshText = ns.Text(L.XP_BAR_FRESH, { count = fresh })
	end
	return bar
end
