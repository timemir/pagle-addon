if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

--- The context generation draws a goal from, live (M7 graph, shapes; TKB-R30–R33): Core's catalogue calls, the
--- Angler's best base skill (LOG-R27), the projection's `zones` and `caught` tables as they are, and its open goals
--- (not yet completed) in issue order. The live step (#233) and the reroll (#234) build one per goal they generate.
---@param state TackleBoardState the projection's state
---@param now integer server time
---@param random fun(m: integer, n: integer): integer like math.random (ns.random)
---@return TackleGenerationContext
function ns.GenerationContext(state, now, random)
	local open = {}
	for _, goal in pairs(state.goals) do
		if goal.doneDay == nil then
			open[#open + 1] = goal
		end
	end
	table.sort(open, function(a, b)
		return a.seq < b.seq
	end)
	return {
		pagle = ns.api.pagle,
		bestBaseSkill = Pagle.GetAngler().bestBaseSkill,
		now = now,
		zones = state.zones,
		caught = state.caught,
		open = open,
		random = random,
	}
end
