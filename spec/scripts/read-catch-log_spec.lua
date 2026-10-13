-- scripts/read-catch-log.lua, the M1 exit check's reader for steps 3 and 4 (#75): it reads PagleLog and PagleDB from
-- a SavedVariables folder with Core's own codec, prints a summary and, with --expect-casts, checks the steps.
-- Its fixtures are SavedVariables folders written here the way the client writes Pagle.lua (CRLF line ends, the
-- client's layout), with entries encoded by Core's codec (CatchLog:Append), so they follow catch-log.md › Entry
-- formats exactly as Core does.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local T0 = 1791731700 -- 2026-10-11 15:15:00 UTC
local ADA = { guid = "Player-4618-0A1B2C3D", name = "Ada", surname = "Brook", realmID = 4618 }
local BRAM = { guid = "Player-4618-0F0E0D0C", name = "Bram", surname = "Reed", realmID = 4618 }

-- The client's SavedVariables layout for one value: `["key"] = value,` per field, array items with `-- [n]`.
local function serialize(value, lines, prefix, suffix)
	if type(value) == "table" then
		lines[#lines + 1] = prefix .. "{"
		for i, item in ipairs(value) do
			serialize(item, lines, "", ", -- [" .. i .. "]")
		end
		local keys = {}
		for key in pairs(value) do
			if type(key) == "string" then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			serialize(value[key], lines, ('["%s"] = '):format(key), ",")
		end
		lines[#lines + 1] = "}" .. suffix
	elseif type(value) == "string" then
		lines[#lines + 1] = prefix .. ("%q"):format(value) .. suffix
	else
		lines[#lines + 1] = prefix .. tostring(value) .. suffix
	end
end

-- A new folder whose path has a space and a `#`, as WTF/Account/<ACCOUNT>#1/SavedVariables/ has.
local function newFolder()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
	local base = os.tmpname()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
	os.remove(base)
	local folder = base .. " Account#1"
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
	assert(os.execute(("mkdir -p '%s'"):format(folder)) == 0)
	return folder
end

local function writeFile(path, text)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
end

--- A SavedVariables folder holding Pagle.lua with these globals, as the client writes it.
local function savedVariables(globals)
	local lines, names = {}, {}
	for name in pairs(globals) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		serialize(globals[name], lines, name .. " = ", "")
	end
	local folder = newFolder()
	writeFile(folder .. "/Pagle.lua", table.concat(lines, "\r\n") .. "\r\n")
	return folder
end

local function conditions(zone)
	return {
		minute = 494,
		uiMap = 1439,
		instance = 1,
		zone = zone,
		subzone = zone and 453 or nil,
		skillRank = 86,
		skillMod = 25,
		lure = 263,
		events = {},
		auras = {},
	}
end

--- A PagleLog with Ada and Bram, its entries appended with Core's codec in order. Each `record` is
--- `{ "cast", char, dt, "caught"|"gotAway", zone }`, `{ "skill", char, dt }` or `{ "build", char, dt }`, dt seconds
--- after T0.
local function catchLog(records)
	local log = ns.OpenCatchLog(nil, { decodeErrors = 0 }, T0)
	log.data.characters = { ADA, BRAM }
	for _, r in ipairs(records) do
		local kind, char, time = r[1], r[2], T0 + r[3]
		if kind == "cast" then
			local items = r[4] == "caught" and { { itemID = 6358, quantity = 1 } } or {}
			log:Append({
				kind = kind,
				char = char,
				time = time,
				outcome = r[4],
				conditions = conditions(r[5]),
				items = items,
			})
		elseif kind == "skill" then
			log:Append({ kind = kind, char = char, time = time, rank = 85, max = 150, mod = 25 })
		else
			log:Append({ kind = kind, char = char, time = time, build = 70338, version = "1.60.1" })
		end
	end
	return log.data
end

-- A 30-minute stretch: a build and a Skill Reading at login, then five Casts by two characters in two zones.
local STRETCH = {
	{ "build", 1, 0 },
	{ "skill", 1, 0 },
	{ "cast", 1, 60, "caught", 148 },
	{ "cast", 1, 60, "caught", 148 },
	{ "cast", 1, 600, "gotAway", 148 },
	{ "cast", 1, 1200, "caught", 1519 },
	{ "cast", 2, 1800, "caught", 1519 },
}

--- Runs the script as `lua scripts/read-catch-log.lua <args>` would, and returns its output lines, what it wrote
--- to stderr, and its exit code.
---@return string[] out, string err, integer code
local function run(...)
	local out, err, code = {}, {}, nil
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile("scripts/read-catch-log.lua"))
	local env = setmetatable({
		arg = { [0] = "scripts/read-catch-log.lua", ... },
		print = function(line)
			out[#out + 1] = line
		end,
		io = setmetatable({
			stderr = {
				write = function(_, text)
					err[#err + 1] = text
				end,
			},
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		}, { __index = io }),
		os = setmetatable({
			exit = function(status)
				code = status
			end,
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
		}, { __index = os }),
	}, { __index = _G })
	setfenv(chunk, env)
	chunk(...)
	return out, table.concat(err), code
end

--- The one output line that starts with `start`, or nil.
local function line(out, start)
	for _, text in ipairs(out) do
		if text:sub(1, #start) == start then
			return text
		end
	end
	return nil
end

--- The lines after `heading`, up to the next one that isn't indented.
local function block(out, heading)
	local lines
	for _, text in ipairs(out) do
		if lines and text:sub(1, 2) ~= "  " then
			break
		end
		if lines then
			lines[#lines + 1] = text
		end
		if text == heading then
			lines = {}
		end
	end
	return lines
end

describe("scripts/read-catch-log.lua", function()
	describe("after a 30-minute stretch", function()
		local log = catchLog(STRETCH)
		local folder = savedVariables({
			PagleLog = log,
			PagleDB = {
				global = { decodeErrors = 0, schemaVersion = 1 },
				profileKeys = { ["Ada - Brook"] = "Default" },
			},
		})

		it("exits 0 and prints the logId and the entries by tag (#75 step 3)", function()
			local out, err, code = run(folder)
			assert.are.equal("", err)
			assert.are.equal(0, code)
			assert.are.equal(
				("PagleLog: format 1, logId %s, 2 characters, 7 entries"):format(log.logId),
				line(out, "PagleLog: ")
			)
			assert.are.equal("entries by tag: B1 1, C1 5, S1 1", line(out, "entries by tag: "))
		end)

		it("counts the C1 entries by outcome, per character and per zone areaID (#75 steps 3, 4)", function()
			local out = run(folder)
			assert.are.equal("C1 outcomes: caught 4, got away 1", line(out, "C1 outcomes: "))
			assert.are.same({
				"  1 Ada Brook (Player-4618-0A1B2C3D): caught 3, got away 1",
				"  2 Bram Reed (Player-4618-0F0E0D0C): caught 1",
			}, block(out, "C1 by character:"))
			assert.are.same({
				"  148: caught 2, got away 1",
				"  1519: caught 2",
			}, block(out, "C1 by zone areaID:"))
			assert.are.equal("zone areaID 0: none", line(out, "zone areaID 0: "))
		end)

		it("prints the time span, the B1 and S1 entries and decodeErrors", function()
			local out = run(folder)
			assert.are.equal(
				"C1: 5 Casts, from 2026-10-11 15:16:00 UTC to 2026-10-11 15:45:00 UTC (29 min)",
				line(out, "C1: ")
			)
			assert.are.equal("B1: 1 entry, the last build 70338 (1.60.1)", line(out, "B1: "))
			assert.are.equal("S1: 1 entry, the last rank 85, max 150, mod 25 (character 1)", line(out, "S1: "))
			assert.are.equal("PagleDB.global.decodeErrors: 0", line(out, "PagleDB.global.decodeErrors: "))
		end)

		it("passes the exit check's steps 3 and 4 with the dev's count, and exits 0 (#75)", function()
			local out, err, code = run(folder, "--expect-casts", "5")
			assert.are.equal("", err)
			assert.are.same({
				"  ok    5 C1 Casts, the dev's count",
				"  ok    each Cast is there once (no repeated entry ID)",
				"  ok    no Cast in zone areaID 0",
				"  ok    a B1 entry",
				"  ok    an S1 entry",
				"  ok    PagleDB.global.decodeErrors is 0",
				"  ok    every entry decodes",
				"  ok    1 Cast got away (g)",
			}, block(out, "== Exit check (#75 steps 3 and 4): passed"))
			assert.are.equal(0, code)
		end)

		it("fails the count when the dev counted another number, and exits 1 (#75 step 3)", function()
			local out, _, code = run(folder, "--expect-casts", "6")
			assert.are.equal("  FAIL  5 C1 Casts, the dev counted 6", line(out, "  FAIL  "))
			assert.is_not_nil(line(out, "== Exit check (#75 steps 3 and 4): FAILED (1 of 8 checks)"))
			assert.are.equal(1, code)
		end)
	end)

	describe("on a log that fails every check", function()
		-- No B1 or S1, a repeated Cast, a zone that didn't resolve (LOG-R93), no got-away Cast, an entry Core's
		-- codec can't read and decodeErrors counted in the game (LOG-R16).
		local log = catchLog({
			{ "cast", 1, 60, "caught", 148 },
			{ "cast", 1, 120, "caught", nil },
		})
		log.entries[3] = log.entries[2]
		log.entries[4] = "C1|1|1791731900|0|x"
		local folder = savedVariables({ PagleLog = log, PagleDB = { global = { decodeErrors = 2 } } })

		it("prints the Casts in zone areaID 0 by seq", function()
			local out = run(folder)
			assert.are.equal("zone areaID 0: 2 Casts, seq 2, 3", line(out, "zone areaID 0: "))
			assert.are.equal("entries the codec can't decode: 1", line(out, "entries the codec can't decode: "))
		end)

		it("fails each check that doesn't hold, and exits 1 (#75 steps 3 and 4)", function()
			local out, _, code = run(folder, "--expect-casts", "2")
			assert.are.same({
				"  FAIL  3 C1 Casts, the dev counted 2",
				"  FAIL  repeated entry ID: Player-4618-0A1B2C3D-1791731820-0",
				"  FAIL  2 Casts in zone areaID 0",
				"  FAIL  no B1 entry",
				"  FAIL  no S1 entry",
				"  FAIL  PagleDB.global.decodeErrors is 2",
				"  FAIL  1 entry the codec can't decode",
				"  FAIL  no Cast got away (g)",
			}, block(out, "== Exit check (#75 steps 3 and 4): FAILED (8 of 8 checks)"))
			assert.are.equal(1, code)
		end)
	end)

	describe("with --since", function()
		-- An earlier session with a Cast in zone areaID 0 and a got-away Cast, then this session's two Casts.
		local folder = savedVariables({
			PagleLog = catchLog({
				{ "build", 1, 0 },
				{ "skill", 1, 0 },
				{ "cast", 1, 60, "caught", nil },
				{ "cast", 1, 3600, "caught", 148 },
				{ "cast", 1, 4000, "gotAway", 148 },
			}),
			PagleDB = { global = { decodeErrors = 0 } },
		})

		it("counts only the Casts at that server time or later", function()
			local out, _, code = run(folder, "--since", tostring(T0 + 3600), "--expect-casts", "2")
			assert.are.equal(
				"C1: 2 Casts of 3, since 2026-10-11 16:15:00 UTC (--since 1791735300), "
					.. "from 2026-10-11 16:15:00 UTC to 2026-10-11 16:21:40 UTC (6 min)",
				line(out, "C1: ")
			)
			assert.are.equal("zone areaID 0: none", line(out, "zone areaID 0: "))
			assert.are.equal(0, code)
		end)

		it("still finds the B1 and S1 entries from before it", function()
			local out = run(folder, "--since", tostring(T0 + 3600), "--expect-casts", "2")
			assert.are.equal("  ok    a B1 entry", line(out, "  ok    a B1"))
			assert.are.equal("  ok    an S1 entry", line(out, "  ok    an S1"))
		end)
	end)

	it("reports a log in another format than the codec's and fails the check, keeping it as it is (LOG-R18)", function()
		local folder = savedVariables({
			PagleLog = { format = 0, logId = "0123456789abcdef", characters = { ADA }, entries = { "C0|1|1|0" } },
			PagleDB = { global = { decodeErrors = 0 } },
		})
		local out, err, code = run(folder, "--expect-casts", "1")
		assert.are.equal("", err)
		assert.are.equal("PagleLog: format 0, logId 0123456789abcdef, 1 character, 1 entry", line(out, "PagleLog: "))
		assert.are.equal("format 0 isn't the codec's format 1: Core starts a new log at login", line(out, "format "))
		assert.are.equal("  FAIL  PagleLog is format 0, the codec reads format 1", line(out, "  FAIL  "))
		assert.are.equal(1, code)
	end)

	describe("on a folder it can't read", function()
		it("exits 2 when there's no Pagle.lua, as before M1 is installed", function()
			local out, err, code = run(newFolder())
			assert.matches("^read%-catch%-log: can't read .*/Pagle%.lua: missing\n$", err)
			assert.are.same({}, out)
			assert.are.equal(2, code)
		end)

		it("refuses to run Pagle.lua as code: it gets no globals, so a call fails (LOG-R10)", function()
			local folder = newFolder()
			writeFile(folder .. "/Pagle.lua", "os.exit(0)\r\nPagleLog = { entries = {}, characters = {} }\r\n")
			local _, err, code = run(folder)
			assert.matches("can't read .*Pagle%.lua: Pagle%.lua:1: attempt to index global 'os'", err)
			assert.are.equal(2, code)
		end)

		it("refuses a precompiled chunk", function()
			local folder = newFolder()
			writeFile(folder .. "/Pagle.lua", string.dump(function() end))
			local _, err, code = run(folder)
			assert.matches("a precompiled chunk, not data", err)
			assert.are.equal(2, code)
		end)

		it("exits 2 when Pagle.lua holds no PagleLog", function()
			local _, err, code = run(savedVariables({ PagleDB = { global = { decodeErrors = 0 } } }))
			assert.matches("holds no PagleLog", err)
			assert.are.equal(2, code)
		end)
	end)

	it("exits 2 with the usage on a bad argument", function()
		for _, args in ipairs({
			{},
			{ "a", "b" },
			{ "a", "--expect-casts" },
			{ "a", "--expect-casts", "x" },
			{ "a", "-v" },
		}) do
			local out, err, code = run(unpack(args))
			assert.matches("\nusage: lua scripts/read%-catch%-log%.lua ", err)
			assert.are.same({}, out)
			assert.are.equal(2, code)
		end
	end)

	it("runs from scripts/read-catch-log.sh on a path with spaces and a #, and passes its exit code on", function()
		local folder = savedVariables({
			PagleLog = catchLog(STRETCH),
			PagleDB = { global = { decodeErrors = 0 } },
		})
		local command = ("bash scripts/read-catch-log.sh '%s' --expect-casts 5; echo \"exit $?\""):format(folder)
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local shell = assert(io.popen(command))
		local out = shell:read("*a")
		shell:close()
		assert.matches("== Exit check %(#75 steps 3 and 4%): passed\n", out)
		assert.matches("\nexit 0\n$", out)

		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		shell = assert(io.popen((command:gsub("expect%-casts 5", "expect-casts 4"))))
		out = shell:read("*a")
		shell:close()
		assert.matches("\nexit 1\n$", out)
	end)
end)
