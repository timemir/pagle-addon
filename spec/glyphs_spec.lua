-- CORE-R9 (#248): every string the package draws uses only characters the client's fonts have. Build 1.60.1.70374
-- draws a box for ❧, ☚, ☆, ☑, ☐ and ▸. On 2026-10-15 `/pagle dev glyphs` showed every font Pagle uses
-- (GameFontHighlight, ChatFontNormal, NumberFontNormalSmallGray, Fonts\MORPHEUS.TTF) drawing the en and em dashes, the
-- ellipsis, curly single and double quotes, the bullet and the Latin-1 characters tried (· « » ×); a box for ★ and ✓
-- in all four, and for → in GameFontHighlight and MORPHEUS. The allowed set is ASCII, Latin-1 (U+00A0–U+00FF) and
-- – — ‘ ’ “ ” • … (U+2013, U+2014, U+2018, U+2019, U+201C, U+201D, U+2022, U+2026). Checked over every file the
-- package ships outside libs/: each Lua string literal (locale files, generated data such as Lore.lua, and code),
-- decoded as Lua reads it, so a byte escape counts as the character it spells; XML outside comments; TOC lines
-- outside comments. Comments are never drawn, so they may hold anything. The generator checks lore on the way in
-- (DATA-R107).

-- The punctuation outside Latin-1 that CORE-R9 allows, by code point.
local PUNCTUATION = {
	[0x2013] = true,
	[0x2014] = true,
	[0x2018] = true,
	[0x2019] = true,
	[0x201C] = true,
	[0x201D] = true,
	[0x2022] = true,
	[0x2026] = true,
}

-- Whether code point `cp` is in CORE-R9's set.
---@param cp integer
---@return boolean
local function allowed(cp)
	return cp < 0x80 or (cp >= 0xA0 and cp <= 0xFF) or PUNCTUATION[cp] == true
end

-- Each code point in `text` outside CORE-R9's set, as "U+XXXX". Bytes that spell no UTF-8 character are skipped: they
-- are byte patterns such as FieldReportText's "[^\128-\191]", never drawn.
---@param text string
---@return string[]
local function outside(text)
	local found, i = {}, 1
	while i <= #text do
		local byte = text:byte(i)
		local size, cp
		if byte < 0x80 then
			size, cp = 1, byte
		elseif byte >= 0xC2 and byte <= 0xDF then
			size, cp = 2, byte % 0x20
		elseif byte >= 0xE0 and byte <= 0xEF then
			size, cp = 3, byte % 0x10
		elseif byte >= 0xF0 and byte <= 0xF4 then
			size, cp = 4, byte % 0x08
		end
		for k = 1, (size or 1) - 1 do
			local next = text:byte(i + k)
			if not next or next < 0x80 or next > 0xBF then
				size = nil
				break
			end
			cp = cp * 0x40 + next % 0x40
		end
		if not size then
			i = i + 1
		else
			if not allowed(cp) then
				found[#found + 1] = ("U+%04X"):format(cp)
			end
			i = i + size
		end
	end
	return found
end

-- Lua 5.1's single-character escapes.
local ESCAPES = { a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v" }

-- Each string literal in Lua source `code`, as { line = the line it starts on, value = its text as Lua reads it }.
-- Comments are skipped.
---@param code string
---@return { line: integer, value: string }[]
local function literals(code)
	local found, i, line = {}, 1, 1
	-- Skips a long bracket opening at `at` with `level` equals signs; returns its body and the index after it.
	local function long(at, level)
		local open = at + level + 2
		local close, after = code:find("]" .. ("="):rep(level) .. "]", open, true)
		close, after = close or #code + 1, after or #code
		local body = code:sub(open, close - 1)
		local _, lines = code:sub(at, after):gsub("\n", "")
		line = line + lines
		return body:gsub("^\r?\n", ""), after + 1
	end
	while i <= #code do
		local c = code:sub(i, i)
		if c == "\n" then
			line, i = line + 1, i + 1
		elseif code:sub(i, i + 1) == "--" then
			local level = code:match("^%[(=*)%[", i + 2)
			if level then
				local _
				_, i = long(i + 2, #level)
			else
				i = code:find("\n", i, true) or #code + 1
			end
		elseif c == '"' or c == "'" then
			local parts, start, j = {}, line, i + 1
			while j <= #code do
				local ch = code:sub(j, j)
				if ch == c or ch == "\n" then
					break
				elseif ch == "\\" then
					local escaped = code:sub(j + 1, j + 1)
					local digits = code:match("^%d%d?%d?", j + 1)
					if digits then
						parts[#parts + 1], j = string.char(tonumber(digits) % 256), j + 1 + #digits
					else
						if escaped == "\n" then
							line = line + 1
						end
						parts[#parts + 1], j = ESCAPES[escaped] or escaped, j + 2
					end
				else
					parts[#parts + 1], j = ch, j + 1
				end
			end
			found[#found + 1] = { line = start, value = table.concat(parts) }
			i = j + 1
		elseif c == "[" and code:match("^%[=*%[", i) then
			local start = line
			local body
			body, i = long(i, #code:match("^%[(=*)%[", i))
			found[#found + 1] = { line = start, value = body }
		else
			i = i + 1
		end
	end
	return found
end

-- Each character `path`'s text `text` draws outside CORE-R9's set, as "<path>:<line>: U+XXXX".
---@param path string
---@param text string
---@return string[]
local function offences(path, text)
	local found = {}
	local function add(line, value)
		for _, what in ipairs(outside(value)) do
			found[#found + 1] = ("%s:%d: %s"):format(path, line, what)
		end
	end
	if path:match("%.lua$") then
		for _, literal in ipairs(literals(text)) do
			add(literal.line, literal.value)
		end
	else
		-- XML outside <!-- --> (each comment's line breaks kept, so lines still count), or a TOC outside "# " comments.
		text = text:gsub("<!%-%-.-%-%->", function(comment)
			return (comment:gsub("[^\n]", ""))
		end)
		local n = 0
		for row in (text .. "\n"):gmatch("([^\n]*)\n") do
			n = n + 1
			if not (path:match("%.toc$") and row:match("^#") and not row:match("^##")) then
				add(n, row)
			end
		end
	end
	return found
end

-- Every .lua, .xml and .toc file under addons/ outside libs/, sorted.
---@return string[]
local function shipped()
	local files = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local find = assert(io.popen("find addons -type f \\( -name '*.lua' -o -name '*.xml' -o -name '*.toc' \\)"))
	for path in find:lines() do
		if not path:find("/libs/", 1, true) then
			files[#files + 1] = path
		end
	end
	find:close()
	table.sort(files)
	return files
end

describe("Every string the package draws (CORE-R9)", function()
	local files = shipped()

	it("is checked in every addon's locale, its generated data and its code", function()
		local listed = {}
		for _, path in ipairs(files) do
			listed[path] = true
		end
		for _, path in ipairs({
			"addons/Pagle/locale/enUS.lua",
			"addons/Pagle/data/Catalogue.lua",
			"addons/Pagle/logic/Dev.lua",
			"addons/Pagle/Pagle.toc",
			"addons/Pagle_Ledger/locale/enUS.lua",
			"addons/Pagle_Ledger/data/Lore.lua",
			"addons/Pagle_QoL/Bindings.xml",
		}) do
			assert.are.equal(path, listed[path] and path)
		end
		for path in pairs(listed) do
			assert.is_nil(path:find("/libs/", 1, true))
		end
	end)

	for _, path in ipairs(files) do
		it(path .. " uses only ASCII, Latin-1 and the allowed punctuation", function()
			assert.are.same({}, offences(path, readFile(path)))
		end)
	end

	describe("catches", function()
		local planted = {
			{ 'L.LEVEL = "Angler Level %d → %d"', "x.lua:1: U+2192" },
			{ "local a = 1\nlocal STAR = '★'", "x.lua:2: U+2605" },
			{ 'L.NEXT = "\\226\\134\\146 %s"', "x.lua:1: U+2192" },
			{ "L.HINT = [[\nRead the plain hint ▸]]", "x.lua:1: U+25B8" },
			{ "L.TICK = [==[caught ✓]==]", "x.lua:1: U+2713" },
			{ 'L.BACK = "\\\n☚ back"', "x.lua:1: U+261A" },
			{ 'L.STAR = "Bright ☆"', "x.lua:1: U+2606" },
			{ 'L.LOW = "‚low‛ ‣ ‥"', "x.lua:1: U+201A" },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				assert.are.same(case[2], offences("x.lua", case[1])[1])
			end)
		end

		it("in XML text and a TOC's fields", function()
			assert.are.same({ "x.xml:2: U+2192" }, offences("x.xml", '<Ui>\n<Binding header="A → B"/>\n</Ui>'))
			assert.are.same({ "x.toc:1: U+2605" }, offences("x.toc", "## Title: Pagle ★\n# a ★ comment\nfile.lua"))
		end)

		it("but not ASCII, Latin-1, the allowed punctuation, a comment or a texture escape", function()
			assert.are.same(
				{},
				offences(
					"x.lua",
					table.concat({
						'local a = "Café × 3 · Pagle » back — unknown —"',
						'local q = "06:00–24:00 • ‘one’ “two” Updating…"',
						'local e = "\\226\\128\\156%s\\226\\128\\157"',
						"-- a comment may say → ★ ✓",
						"--[==[ or ☑ ☐ “quotes” ]==]",
						'local b = "|TInterface\\\\TargetingFrame\\\\UI-RaidTargetingIcon_1:0|t" -- ★',
						"local c = '\\195\\169' .. [[ok]] -- é as bytes",
						'local d = s:gsub("[^\\128-\\191]", "") -- a byte pattern, never drawn',
					}, "\n")
				)
			)
			assert.are.same({}, offences("x.xml", "<Ui>\n<!-- a → comment -->\n</Ui>"))
		end)
	end)
end)
