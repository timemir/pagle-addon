-- CORE-R8 (#514): no file reads `ns.L` at its top level. A Language is applied after a file has loaded (Core's overlay
-- runs in its ADDON_LOADED, a Module's when its locale files load, ADR 0019), so an `L.KEY` read that runs while a file
-- loads sees English for the whole session. `local L = ns.L` is fine: it caches the table, and the overlay writes into
-- that table in place. Reading a field of it in the main chunk is not.
--
-- The spec lists each shipped addon file's main chunk with Lua 5.1's `luac -l` (not the nested functions, which run
-- later) and follows which registers may hold `ns.L` (a GETTABLE with the key "L", and any MOVE or `or` of it). A
-- GETTABLE or SELF through such a register is a read of a field of L. Writes (`L.KEY = ...`) are not reads.

-- The one read left, and why. Off Forever, Core's first file prints L.NOT_FOREVER and stops (CORE-R4): no ADDON_LOADED
-- handler is registered, so no Language is ever applied there and the line is English, as before 1.1. The spec fails
-- if the file stops reading it, so the exemption cannot outlive the read.
local WHILE_LOADING = {
	["addons/Pagle/adapter/Core.lua"] = 1,
}

-- Where the toolchain installs Lua 5.1's luac (scripts/setup.sh links no `luac` into .tools/bin), in the .tools/ the
-- gate runs its tools from: scripts/lib/tools.sh's tools_dir, the one copy of that rule ($PAGLE_TOOLS, this checkout's
-- .tools/, or a linked worktree's main checkout's), so a fresh worktree needs no .tools/ of its own (DATA-R61).
---@return string
local function toolsDir()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local run = assert(io.popen([[bash -c 'source scripts/lib/tools.sh && tools_dir "$PWD"']]))
	local dir = run:read("*l") or ".tools"
	run:close()
	return dir
end
local LUAC = toolsDir() .. "/lua/bin/luac"
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
local luacFile = io.open(LUAC, "rb")
if luacFile then
	luacFile:close()
end
-- Without luac anywhere the spec skips, saying where it looked; in CI, which always installs it, it fails instead
-- (GitHub Actions sets CI), as the "finds luac" case below asserts.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
if not luacFile and not os.getenv("CI") then
	describe("No file reads ns.L at its top level (CORE-R8)", function()
		pending("no " .. LUAC .. ": run scripts/setup.sh in the main checkout", function() end)
	end)
	return
end

---@param path string
---@return string
local function listing(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local run = assert(io.popen(LUAC .. " -l -p " .. path .. " 2>&1"))
	local text = run:read("*a")
	run:close()
	return text
end

-- The main chunk's instructions from a `luac -l` listing, as { op, a, b, c, line, jump = target index or nil,
-- note = the comment }. The main chunk is the listing up to the first nested `function <` header.
---@param text string
---@return table[]
local function mainChunk(text)
	local code = {}
	local inMain = false
	local capturing = false -- the rows after a CLOSURE that name its upvalues: not real MOVEs or GETUPVALs
	for row in (text .. "\n"):gmatch("([^\n]*)\n") do
		if row:match("^main <") then
			inMain = true
		elseif row:match("^function <") then
			break
		elseif inMain then
			local index, line, op, rest = row:match("^%s*(%d+)%s+%[(%-?%d+)%]%s+(%u+)%s*(.*)$")
			if index then
				local operands, note = rest:match("^([^;]*);?%s*(.*)$")
				local numbers = {}
				for number in operands:gmatch("%-?%d+") do
					numbers[#numbers + 1] = tonumber(number)
				end
				local pseudo = capturing and (op == "MOVE" or op == "GETUPVAL") and numbers[1] == 0
				capturing = op == "CLOSURE" or pseudo
				code[tonumber(index)] = {
					op = pseudo and "NOP" or op,
					a = numbers[1],
					b = numbers[2],
					c = numbers[3],
					line = tonumber(line),
					jump = tonumber(note:match("^to (%d+)")),
					note = note,
				}
			elseif row:match("^%s*%d+%s+%[") then
				error("luac -l row not understood: " .. row)
			end
		end
	end
	return code
end

local ARITH = {
	LOADK = true,
	LOADBOOL = true,
	GETUPVAL = true,
	GETGLOBAL = true,
	NEWTABLE = true,
	ADD = true,
	SUB = true,
	MUL = true,
	DIV = true,
	MOD = true,
	POW = true,
	UNM = true,
	NOT = true,
	LEN = true,
	CONCAT = true,
	CLOSURE = true,
}

-- The lines of the main chunk (of the `luac -l` listing `text`) that read a field of L, as { line = n }, in order.
-- Registers that may hold L are followed through every path (a jump merges the two sets), so `local L = ns.L or {}`
-- still counts as L.
---@param text string
---@return { line: integer }[]
local function readsOfL(text)
	local code = mainChunk(text)
	local before = {} -- before[i]: the registers that may hold L when instruction i runs
	local queue = { 1 }
	before[1] = {}
	local reads = {}
	local seen = {}
	local function flow(to, set)
		if not code[to] then
			return
		end
		local have = before[to]
		if not have then
			have = {}
			before[to] = have
			for register in pairs(set) do
				have[register] = true
			end
			queue[#queue + 1] = to
			return
		end
		local grew = false
		for register in pairs(set) do
			if not have[register] then
				have[register], grew = true, true
			end
		end
		if grew then
			queue[#queue + 1] = to
		end
	end
	while #queue > 0 do
		local i = table.remove(queue)
		local ins = code[i]
		local held = {}
		for register in pairs(before[i]) do
			held[register] = true
		end
		local op, a, b, c = ins.op, ins.a, ins.b, ins.c
		local falls, skips = true, false
		if op == "GETTABLE" then
			if held[b] and not seen[ins.line] then
				seen[ins.line] = true
				reads[#reads + 1] = { line = ins.line }
			end
			held[a] = (c < 0 and ins.note == '"L"') or nil
		elseif op == "SELF" then
			if held[b] and not seen[ins.line] then
				seen[ins.line] = true
				reads[#reads + 1] = { line = ins.line }
			end
			held[a], held[a + 1] = nil, nil
		elseif op == "MOVE" or op == "TESTSET" then
			held[a] = held[b]
			skips = op == "TESTSET"
		elseif ARITH[op] then
			held[a] = nil
			if op == "LOADBOOL" and c ~= 0 then
				skips, falls = true, false
			end
		elseif op == "LOADNIL" then
			for register = a, b do
				held[register] = nil
			end
		elseif op == "CALL" or op == "VARARG" or op == "FORPREP" or op == "FORLOOP" or op == "TFORLOOP" then
			for register in pairs(held) do
				if register >= a then
					held[register] = nil
				end
			end
			skips = op == "TFORLOOP"
		elseif op == "JMP" then
			falls = false
		elseif op == "EQ" or op == "LT" or op == "LE" or op == "TEST" then
			skips = true
		elseif op == "RETURN" or op == "TAILCALL" then
			falls = false
		end
		if ins.jump and op ~= "JMP" or op == "JMP" then
			flow(ins.jump, held)
		end
		if falls then
			flow(i + 1, held)
		end
		if skips then
			flow(i + 2, held)
		end
	end
	table.sort(reads, function(x, y)
		return x.line < y.line
	end)
	return reads
end

-- The top-level reads of L in the Lua file at `path`, as "path:line: reads a field of ns.L while the file loads".
---@param path string
---@return string[]
local function offences(path)
	local text = listing(path)
	assert(text:find("main <", 1, true), path .. ": luac -l did not list it: " .. text)
	local found = {}
	for _, read in ipairs(readsOfL(text)) do
		found[#found + 1] = ("%s:%d: reads a field of ns.L while the file loads"):format(path, read.line)
	end
	return found
end

-- Every .lua file under addons/ outside libs/, sorted.
---@return string[]
local function shipped()
	local files = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local find = assert(io.popen("find addons -type f -name '*.lua'"))
	for path in find:lines() do
		if not path:find("/libs/", 1, true) then
			files[#files + 1] = path
		end
	end
	find:close()
	table.sort(files)
	return files
end

-- The offences in a Lua `source` text, written to a scratch file first (luac lists files).
---@param source string
---@return string[]
local function offencesIn(source)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os or io
	local path = os.tmpname()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os or io
	local file = assert(io.open(path, "wb"))
	file:write(source)
	file:close()
	local found = offences(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os or io
	os.remove(path)
	for i, row in ipairs(found) do
		found[i] = row:sub(#path + 2)
	end
	return found
end

describe("No file reads ns.L at its top level (CORE-R8)", function()
	local files = shipped()

	it("checks every addon's code, generated files included", function()
		local listed = {}
		for _, path in ipairs(files) do
			listed[path] = true
		end
		for _, path in ipairs({
			"addons/Pagle/adapter/Tour.lua",
			"addons/Pagle/logic/Size.lua",
			"addons/Pagle/locale/enUS.lua",
			"addons/Pagle_Ledger/adapter/Journal.lua",
			"addons/Pagle_QoL/adapter/Bindings.lua",
		}) do
			assert.are.equal(path, listed[path] and path)
		end
		for path in pairs(listed) do
			assert.is_nil(path:find("/libs/", 1, true))
		end
	end)

	it("data_r61 finds luac where the toolchain installs it, failing in CI without it", function()
		assert(luacFile, "no " .. LUAC .. ": CI installs every tool, so a missing one fails here")
		assert.is_truthy(listing("addons/Pagle/logic/Size.lua"):find("main <", 1, true))
	end)

	for _, path in ipairs(files) do
		if WHILE_LOADING[path] then
			it(path .. " reads ns.L while it loads only off Forever, where no Language applies", function()
				assert.are.equal(WHILE_LOADING[path], #offences(path))
			end)
		else
			it(path .. " reads no field of ns.L while it loads", function()
				assert.are.same({}, offences(path))
			end)
		end
	end

	describe("catches", function()
		it("a read in a fixture file, by file and line", function()
			assert.are.same({
				"spec/fixtures/top_level_l_read.lua:6: reads a field of ns.L while the file loads",
				"spec/fixtures/top_level_l_read.lua:7: reads a field of ns.L while the file loads",
				"spec/fixtures/top_level_l_read.lua:9: reads a field of ns.L while the file loads",
				"spec/fixtures/top_level_l_read.lua:12: reads a field of ns.L while the file loads",
				"spec/fixtures/top_level_l_read.lua:13: reads a field of ns.L while the file loads",
				"spec/fixtures/top_level_l_read.lua:16: reads a field of ns.L while the file loads",
			}, offences("spec/fixtures/top_level_l_read.lua"))
		end)

		local planted = {
			{ "a field of the cached table", "local _, ns = ...\nlocal L = ns.L\nlocal a = L.TITLE", { 3 } },
			{ "a field read straight off ns.L", "local _, ns = ...\nlocal a = ns.L.TITLE", { 2 } },
			{ "a field read with a string key", 'local _, ns = ...\nlocal L = ns.L\nlocal a = L["TITLE"]', { 3 } },
			{
				"a field read with a computed key",
				"local _, ns = ...\nlocal L = ns.L\nlocal k = 'a'\nlocal a = L[k]",
				{ 4 },
			},
			{ "a read through `or {}`", "local _, ns = ...\nlocal L = ns.L or {}\nlocal a = L.TITLE", { 3 } },
			{
				"a read through a copy of L",
				"local _, ns = ...\nlocal L = ns.L\nlocal M = L\nlocal a = M.TITLE",
				{ 4 },
			},
			{ "a read in an if", "local _, ns = ...\nlocal L = ns.L\nif ns then\n\tns.x = L.TITLE\nend", { 4 } },
			{ "a read in a loop", "local _, ns = ...\nlocal L = ns.L\nfor i = 1, 2 do\n\tns[i] = L.TITLE\nend", { 4 } },
			{ "a read in an argument", "local _, ns = ...\nlocal L = ns.L\nprint(L.TITLE)", { 3 } },
			{ "a method call on L", "local _, ns = ...\nlocal L = ns.L\nlocal a = L:Get()", { 3 } },
		}
		for _, case in ipairs(planted) do
			it(case[1], function()
				local lines = {}
				for _, row in ipairs(offencesIn(case[2])) do
					lines[#lines + 1] = tonumber(row:match("^(%d+):"))
				end
				assert.are.same(case[3], lines)
			end)
		end

		it("but not a cached table, a write, or a read inside a function", function()
			assert.are.same(
				{},
				offencesIn(table.concat({
					"local _, ns = ...",
					"local L = ns.L",
					"local M = ns.L or {}",
					"L.TITLE = 'Title'",
					"ns.L.OTHER = 'Other'",
					"ns.label = function()",
					"\treturn L.TITLE .. M.OTHER",
					"end",
					"local function again()",
					"\tlocal T = {}",
					"\tT.x = ns.L.TITLE",
					"\treturn T",
					"end",
					"ns.again = again",
					"local plain = {}",
					"local fine = plain.TITLE",
					"ns.fine = fine",
				}, "\n"))
			)
		end)
	end)
end)
