if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- A Nudge's timing and place (QOL-R75): pure logic, everything passed in (CORE-R7). adapter/Nudge.lua draws it.

--- Seconds a Nudge shows at full strength, then the seconds it fades out over (qol.md › Tunables).
ns.NUDGE_SHOW = 3
ns.NUDGE_FADE = 0.5
--- Pixels between the game's error text (`UIErrorsFrame`) and the Nudge below it (qol.md › Tunables).
ns.NUDGE_GAP = 4

--- A Nudge's alpha `elapsed` seconds after it showed: 1 for NUDGE_SHOW, then down to 0 over NUDGE_FADE, then nil
--- once it is gone (QOL-R75).
---@param elapsed number
---@return number?
function ns.NudgeAlpha(elapsed)
	if elapsed <= ns.NUDGE_SHOW then
		return 1
	end
	local fading = elapsed - ns.NUDGE_SHOW
	if fading >= ns.NUDGE_FADE then
		return nil
	end
	return 1 - fading / ns.NUDGE_FADE
end
