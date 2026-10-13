if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Input (QOL-R12) and its two quick places, the compartment entry (QOL-R16) and `/pagle qol` (QOL-R17): pure logic,
-- everything passed in (CORE-R7). The Settings row is in logic/Settings.lua.

---@alias PagleQoLInput "key"|"click"|"both"

--- Whether the Fishing key is armed under this Input: under *Fishing key* or *Both* (QOL-R12).
---@param input PagleQoLInput
---@return boolean
function ns.InputArmsKey(input)
	return input == "key" or input == "both"
end

--- Whether the double-click can be live under this Input: under *Double-click* or *Both* (QOL-R12, QOL-R14).
---@param input PagleQoLInput
---@return boolean
function ns.InputArmsClick(input)
	return input == "click" or input == "both"
end

-- The compartment entry's cycle: Both → Fishing key → Double-click → Both (QOL-R16).
local NEXT_INPUT = { both = "key", key = "click", click = "both" }

--- The Input after this one on the compartment entry's cycle (QOL-R16).
---@param input PagleQoLInput
---@return PagleQoLInput
function ns.NextInput(input)
	return NEXT_INPUT[input] or "both"
end

--- The compartment entry's label: "Input: Fishing key", "Input: Double-click" or "Input: Both" (QOL-R16).
---@param input PagleQoLInput
---@return string
function ns.InputMenuLabel(input)
	local L = ns.L
	local names = { key = L.INPUT_KEY, click = L.INPUT_CLICK, both = L.INPUT_BOTH }
	return L.MENU_INPUT:format(names[input] or L.INPUT_BOTH)
end

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

--- What `/pagle qol` acts through.
---@class PagleQoLSlashActions
---@field setInput fun(input: PagleQoLInput) sets Input, taking effect at once or after combat (QOL-R18)
---@field openSettings fun(topic: string) opens a Settings topic page, as `Pagle.OpenSettings` does
---@field print fun(text: string) prints a line to chat

--- `/pagle qol <line>` (QOL-R17): `input key|click|both` sets Input and says so, nothing opens the Fishing page, and
--- anything else prints the usage line. Matched in any case, as Core matches the subcommand (CORE-R62).
---@param line string the rest of the line, trimmed (CORE-R62)
---@param actions PagleQoLSlashActions
function ns.QoLSlash(line, actions)
	local L = ns.L
	if line == "" then
		actions.openSettings("fishing")
		return
	end
	local said = { key = L.INPUT_SET_KEY, click = L.INPUT_SET_CLICK, both = L.INPUT_SET_BOTH }
	local input = line:lower():match("^input%s+(%a+)$")
	if input and said[input] then
		actions.setInput(input)
		actions.print(said[input])
	else
		actions.print(L.SLASH_USAGE)
	end
end
