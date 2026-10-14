-- STA-R58, the copy test: no Stats string says or implies that a Catch is owed. Every value in Stats' string table
-- (ns.L, as Stats loads it, so the generated data/Lore.lua's entries too) and every string value in
-- data/lore/stats.toml, once that file exists (the M6 lore batch, #210), is checked for "due", "overdue", "soon",
-- "pity", "guaranteed", "bound to" and "owed", case-insensitively and as whole words. The one exception is the exact
-- line "Every Cast is its own roll; nothing is owed." This spec runs in scripts/check.sh's busted stage, so every
-- Stats ticket's strings are held to it.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local LORE = "data/lore/stats.toml"

-- The words and phrases STA-R58 bans, and its one allowed line.
local BANNED = { "due", "overdue", "soon", "pity", "guaranteed", "bound to", "owed" }
local ALLOWED = "Every Cast is its own roll; nothing is owed."

--- The banned words in `text`, in BANNED's order: whole words, any case, a phrase's words apart by any space. None
--- for the allowed line, exactly as STA-R58 gives it.
---@param text string
---@return string[]
local function bannedIn(text)
	local found = {}
	if text == ALLOWED then
		return found
	end
	local lower = text:lower()
	for _, word in ipairs(BANNED) do
		if lower:find("%f[%w]" .. word:gsub(" ", "%%s+") .. "%f[%W]") then
			found[#found + 1] = word
		end
	end
	return found
end

--- Each string with a banned word, as "<where>: <text> (<words>)", sorted. `strings` maps where each string is to it.
---@param strings table<string, string>
---@return string[]
local function problemsIn(strings)
	local problems = {}
	for where, text in pairs(strings) do
		local found = bannedIn(text)
		if #found > 0 then
			problems[#problems + 1] = ("%s: %s (%s)"):format(where, text, table.concat(found, ", "))
		end
	end
	table.sort(problems)
	return problems
end

--- Every string value in a string table, nested tables walked, by its key path ("COUNTS.Casts.one").
---@param strings table
---@param prefix string?
---@param into table<string, string>?
---@return table<string, string>
local function stringsOf(strings, prefix, into)
	into = into or {}
	for key, value in pairs(strings) do
		local where = prefix and (prefix .. "." .. tostring(key)) or tostring(key)
		if type(value) == "string" then
			into[where] = value
		elseif type(value) == "table" then
			stringsOf(value, where, into)
		end
	end
	return into
end

-- TOML's escapes in a basic string; \uXXXX and \UXXXXXXXX are left as they are, as no banned word hides in one.
local ESCAPES = { b = "\b", t = "\t", n = "\n", f = "\f", r = "\r", ['"'] = '"', ["\\"] = "\\" }

--- Every string value in a lore file, by "<line>: <key>" (DATA-R101: each table holds its fields as strings): basic,
--- literal and multi-line strings. Raises an error on a value that is no string, so nothing passes unread.
---@param path string
---@return table<string, string>
local function loreStrings(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = assert(io.open(path, "r"))
	local text = file:read("*a")
	file:close()
	local strings = {}
	local at, line = 1, 1
	local function advance(to)
		local _, newlines = text:sub(at, to - 1):gsub("\n", "")
		line, at = line + newlines, to
	end
	while at <= #text do
		local lineEnd = text:find("\n", at, true) or #text + 1
		local current = text:sub(at, lineEnd - 1)
		local key, valueStart = current:match("^%s*([%w_%-%.\"']-)%s*=%s*()")
		if not key or current:match("^%s*#") or current:match("^%s*%[") then
			advance(lineEnd + 1)
		else
			local where = ("%s:%d: %s"):format(path, line, key)
			local from = at + valueStart - 1
			local value, after
			local quote = text:sub(from, from + 2)
			if quote == '"""' or quote == "'''" then
				local close = assert(text:find(quote, from + 3, true), where .. ": unclosed multi-line string")
				value, after = text:sub(from + 3, close - 1):gsub("^\n", ""), close + 3
				if quote == '"""' then
					value = value:gsub("\\(.)", ESCAPES)
				end
			elseif text:sub(from, from) == "'" then
				local close = assert(text:find("'", from + 1, true), where .. ": unclosed literal string")
				value, after = text:sub(from + 1, close - 1), close + 1
			elseif text:sub(from, from) == '"' then
				local i, parts = from + 1, {}
				while true do
					local c = text:sub(i, i)
					assert(c ~= "" and c ~= "\n", where .. ": unclosed string")
					if c == '"' then
						break
					elseif c == "\\" then
						local escaped = text:sub(i + 1, i + 1)
						parts[#parts + 1] = ESCAPES[escaped] or ("\\" .. escaped)
						i = i + 2
					else
						parts[#parts + 1] = c
						i = i + 1
					end
				end
				value, after = table.concat(parts), i + 1
			else
				error(where .. ": a value the copy test can't read as a string", 0)
			end
			strings[where] = value
			advance(after)
		end
	end
	return strings
end

--- Whether a file exists.
---@param path string
---@return boolean
local function exists(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = io.open(path, "r")
	if file then
		file:close()
	end
	return file ~= nil
end

describe("the copy test (STA-R58)", function()
	it("passes every value in Stats' string table", function()
		assert.are.same({}, problemsIn(stringsOf(stats.load().ns.L)))
	end)

	it("passes every string in data/lore/stats.toml, once the M6 lore batch adds it (#210)", function()
		if exists(LORE) then
			assert.are.same({}, problemsIn(loreStrings(LORE)))
		end
	end)

	it("has the one allowed line in Stats' string table, exactly", function()
		assert.are.equal(ALLOWED, stats.load().ns.L.NOTHING_IS_OWED)
	end)

	describe("bites", function()
		it("on a planted 'You're due one' and 'coming soon'", function()
			assert.are.same({ "due" }, bannedIn("You're due one"))
			assert.are.same({ "soon" }, bannedIn("coming soon"))
		end)

		it("on each banned word and phrase, in any case", function()
			assert.are.same({ "overdue" }, bannedIn("This one is OVERDUE."))
			assert.are.same({ "pity" }, bannedIn("A pity timer"))
			assert.are.same({ "guaranteed" }, bannedIn("Guaranteed by 500 Casts"))
			assert.are.same({ "bound to" }, bannedIn("You're bound to catch it"))
			assert.are.same({ "bound to" }, bannedIn("Bound  to bite"))
			assert.are.same({ "owed" }, bannedIn("A Catch is owed"))
			assert.are.same({ "due", "soon" }, bannedIn("Due soon"))
		end)

		it("on a word with punctuation around it", function()
			assert.are.same({ "due" }, bannedIn("(due)"))
			assert.are.same({ "soon" }, bannedIn("soon!"))
			assert.are.same({ "due" }, bannedIn("long over-due"))
		end)

		it("on the allowed line changed in any way, or inside a longer string", function()
			assert.are.same({ "owed" }, bannedIn("Every Cast is its own roll; nothing is owed"))
			assert.are.same({ "owed" }, bannedIn("every cast is its own roll; nothing is owed."))
			assert.are.same({ "owed" }, bannedIn("Unlucky. Every Cast is its own roll; nothing is owed."))
		end)

		it("but not on a longer word, or 'bound' alone", function()
			assert.are.same({}, bannedIn("soonest"))
			assert.are.same({}, bannedIn("Bound"))
			assert.are.same({}, bannedIn("Duelist, residue, pitying, owedness, boundary to"))
			assert.are.same({}, bannedIn(ALLOWED))
		end)

		it("on a planted string anywhere in Stats' string table, nested tables too", function()
			local L = stats.load().ns.L
			L.PLANTED = "You're due one"
			L.COUNTS.Casts.other = "%s Casts, coming soon"

			assert.are.same({
				"COUNTS.Casts.other: %s Casts, coming soon (soon)",
				"PLANTED: You're due one (due)",
			}, problemsIn(stringsOf(L)))
		end)

		it("on a planted string in a lore file, in each kind of TOML string", function()
			local path = "spec/Pagle_Stats/fixtures/stats_planted.toml"

			assert.are.same({
				path .. ':14: description: The "logbook" frame. You\'re due one. (due)',
				path .. ":17: description: Coming soon.\nRuled lines. (soon)",
				path .. ":23: name: Bound to please (bound to)",
				path .. ":24: description: No pity here. (pity)",
			}, problemsIn(loreStrings(path)))
		end)

		it("reads a shipped lore file's every string, as the lore batch writes them (core.toml, DATA-R101)", function()
			local read, nRead = {}, 0
			for _, text in pairs(loreStrings("data/lore/core.toml")) do
				read[text], nRead = true, nRead + 1
			end

			assert.is_true(read["Lantern Glow"])
			-- The generator's Lua for the same file (addons/Pagle/data/Lore.lua) holds the same strings.
			local generated = 0
			for key, text in pairs(loadAddon("Pagle", FOREVER_GLOBALS).ns.L) do
				if type(key) == "string" and key:match("^good%.core%.") then
					generated = generated + 1
					assert.is_true(read[text], key)
				end
			end
			assert.are.equal(generated, nRead)
		end)

		it("on a lore value it can't read as a string, rather than passing it unread", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
			local path = os.tmpname()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local file = assert(io.open(path, "w"))
			file:write('[statsgood."stats.trackerframe.brass"]\nname = ["Brass"]\n')
			file:close()

			local ok, err = pcall(loreStrings, path)
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
			os.remove(path)

			assert.is_false(ok)
			assert.matches("can't read as a string", err)
		end)
	end)
end)
