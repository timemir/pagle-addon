if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Input as PagleQoLDB stores it (QOL-R12, qol.md › Data), read and set by its three places, the Fishing key, the
-- double-click and the next-action button. What each value arms, the compartment entry's cycle and label, and
-- `/pagle qol` are pure logic in logic/Input.lua (CORE-R7).

--- Input now, as stored in `PagleQoLDB.profile.input` (qol.md › Data). QoL's OnInitialize opens PagleQoLDB before
--- anything reads it: the menu, `/pagle qol`, the Settings row and the Fishing key all run later.
---@return PagleQoLInput
function ns.CurrentInput()
	return ns.db.profile.input
end

--- Sets Input from any of its three places and re-evaluates at once (QOL-R18, QOL-R25). While restricted that
--- re-evaluation does nothing, and the one at the end of restriction applies it (QOL-R32).
---@param input PagleQoLInput
function ns.SetInput(input)
	ns.db.profile.input = input
	ns.EvaluateFishingKey()
end
