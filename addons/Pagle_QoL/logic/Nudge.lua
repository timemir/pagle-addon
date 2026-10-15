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

--- One piece of a Nudge's line (QOL-R75): words in the Angler's hand, a key on a brass cap (`key`), or a binding's
--- name in printed red (`em`).
---@alias PagleQoLNudgePart string|{ key: string }|{ em: string }

--- A Nudge's line as pieces (QOL-R75): `template` split at its one `%s`, with `value` there as a `kind` piece ("key" or
--- "em"); the template alone when it has no `%s` or there is no value. The words either side lose the spaces next to
--- the value, which the layout puts back as gaps.
---@param template string
---@param value string?
---@param kind "key"|"em"
---@return PagleQoLNudgePart[]
function ns.NudgeParts(template, value, kind)
	local at = template:find("%s", 1, true)
	if not at or not value then
		return { template }
	end
	local parts = {}
	local before = template:sub(1, at - 1):match("^(.-)%s*$")
	local after = template:sub(at + 2):match("^%s*(.-)$")
	if before ~= "" then
		parts[#parts + 1] = before
	end
	parts[#parts + 1] = { [kind] = value }
	if after ~= "" then
		parts[#parts + 1] = after
	end
	return parts
end

--- A Nudge's line as plain text, its pieces joined by spaces: what it says, for /fstack and the specs.
---@param parts PagleQoLNudgePart[]
---@return string
function ns.NudgeText(parts)
	local words = {}
	for i, part in ipairs(parts) do
		words[i] = type(part) == "string" and part or part.key or part.em
	end
	return table.concat(words, " ")
end

--- Where the Nudge strip's pieces go (QOL-R75, the field art kit): 30 px in from the strip's left end, 8 px apart, and
--- 30 px to its right end. A key's cap is its text's width and 6 px either side, at least 26 px.
---@param parts PagleQoLNudgePart[]
---@param textWidth fun(index: integer): number the width of piece `index`'s words, as drawn
---@return { x: number, width: number }[] pieces each piece's left edge on the strip, and its width
---@return number width the strip's width
function ns.NudgeLayout(parts, textWidth)
	local pieces, x = {}, 30
	for i, part in ipairs(parts) do
		local width = textWidth(i)
		if type(part) == "table" and part.key then
			width = math.max(26, width + 12)
		end
		pieces[i] = { x = x, width = width }
		x = x + width + 8
	end
	return pieces, x - 8 + 30
end
