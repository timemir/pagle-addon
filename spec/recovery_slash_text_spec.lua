-- Recovery's and /pagle's own lines are ns.L text (#525, CORE-R8, ADR 0019, "What stays English"): the files that print
-- them hold no English sentence. A line a player reads is a string of `ns.L`, filled with `ns.RenderText`; a literal
-- in a print, a SetText or a window's text would stay English in every Language. The spec reads the source of each file
-- and fails on a string literal with words in the call that prints or shows text.
--
-- What it does not guard, and why: the messages in logic/Recovery.lua and logic/RecoverySnapshot.lua. The ones a player
-- is meant to read are raised by code (`ns.RecoveryProblem`) and worded by adapter/Recovery.lua; the rest are the
-- diagnostics of a strict parser (a bad digest, a forged package) and stay English as raised, so a literal in an
-- `assert` there is not text for the player.

local FILES = {
	"addons/Pagle/adapter/Recovery.lua",
	"addons/Pagle/adapter/Slash.lua",
	"addons/Pagle/logic/Slash.lua",
}
-- The calls whose arguments a player reads.
local SHOWING = { print = true, SetText = true, windowFor = true }

--- The string literals in the arguments of every `print(`, `:SetText(` and `windowFor(` call of `source`, with the
--- line of each. Comments are skipped; a string is read with its escapes, a long string whole.
---@param source string
---@return {line: integer, call: string, text: string}[]
local function literalsInShowingCalls(source)
	local found = {}
	local at, line, length = 1, 1, #source
	-- Calls being read: the depth of their open paren, and the name of the call.
	local open = {}
	local depth = 0
	local function bump(text)
		local _, newlines = text:gsub("\n", "\n")
		line = line + newlines
	end
	while at <= length do
		local char = source:sub(at, at)
		if source:sub(at, at + 1) == "--" then
			local long = source:match("^%-%-%[(=*)%[", at)
			local stop
			if long then
				local _, close = source:find("]" .. long .. "]", at, true)
				stop = close or length
			else
				stop = (source:find("\n", at, true) or length + 1) - 1
			end
			bump(source:sub(at, stop))
			at = stop + 1
		elseif char == '"' or char == "'" then
			local text, cursor = {}, at + 1
			while cursor <= length do
				local c = source:sub(cursor, cursor)
				if c == "\\" then
					text[#text + 1] = source:sub(cursor + 1, cursor + 1)
					cursor = cursor + 2
				elseif c == char then
					break
				else
					text[#text + 1] = c
					cursor = cursor + 1
				end
			end
			if #open > 0 then
				found[#found + 1] = { line = line, call = open[#open].name, text = table.concat(text) }
			end
			at = cursor + 1
		elseif source:match("^%[=*%[", at) then
			local long = source:match("^%[(=*)%[", at)
			local _, close = source:find("]" .. long .. "]", at, true)
			local stop = close or length
			if #open > 0 then
				found[#found + 1] = { line = line, call = open[#open].name, text = source:sub(at, stop) }
			end
			bump(source:sub(at, stop))
			at = stop + 1
		elseif char == "(" then
			depth = depth + 1
			local name = source:sub(1, at - 1):match("([%a_][%w_]*)%s*$")
			if name and SHOWING[name] then
				open[#open + 1] = { name = name, depth = depth }
			end
			at = at + 1
		elseif char == ")" then
			if #open > 0 and open[#open].depth == depth then
				open[#open] = nil
			end
			depth = depth - 1
			at = at + 1
		else
			if char == "\n" then
				line = line + 1
			end
			at = at + 1
		end
	end
	return found
end

--- The literals among them that hold words: two letters in a row. "" and "|" and "%d" are not text.
---@param source string
---@return {line: integer, call: string, text: string}[]
local function englishLiterals(source)
	local words = {}
	for _, literal in ipairs(literalsInShowingCalls(source)) do
		if literal.text:find("%a%a") then
			words[#words + 1] = literal
		end
	end
	return words
end

describe("Recovery's and /pagle's own lines (#525)", function()
	for _, path in ipairs(FILES) do
		it(path .. " prints and shows no English literal", function()
			local words = englishLiterals(readFile(path))
			local lines = {}
			for _, literal in ipairs(words) do
				lines[#lines + 1] = ("%s:%d: %s(%q)"):format(path, literal.line, literal.call, literal.text)
			end

			assert.are.same({}, lines, "move the sentence into data/locale/enUS/core.toml and print ns.L.KEY")
		end)
	end

	describe("the guard itself", function()
		it("fails a print of an English literal, however it is split or joined", function()
			local source = [==[
print("Pagle Recovery: " .. tostring(reason))
print(
	"Pagle is paused"
		.. " for Recovery."
)
window:SetText('Recovery snapshot')
windowFor(parts, labels, "Recovery records", ns.L.X)
]==]
			local words = englishLiterals(source)

			assert.are.same({ 1, 3, 4, 6, 7 }, {
				words[1].line,
				words[2].line,
				words[3].line,
				words[4].line,
				words[5].line,
			})
			assert.are.same({ "print", "print", "print", "SetText", "windowFor" }, {
				words[1].call,
				words[2].call,
				words[3].call,
				words[4].call,
				words[5].call,
			})
		end)

		it("passes text from ns.L, a bare line, a comment and a literal that is no sentence", function()
			local source = [==[
print(ns.L.SLASH_PAUSED_FOR_RECOVERY) -- "Pagle is paused for Recovery."
print(ns.RenderText(ns.L.RECOVERY_STOPPED, { reason = reasonText(err) }))
commands:Run(line, subcommands, securecallfunction, print)
local text = "Pagle Recovery: not shown"
window.line:SetText("")
print("%d")
--[[ print("Pagle Recovery: a long comment") ]]
print(ns.RenderText(ns.L.X, { id = id }))
]==]

			assert.are.same({}, englishLiterals(source))
		end)
	end)
end)
