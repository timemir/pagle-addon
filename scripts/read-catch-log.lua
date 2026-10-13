-- Reads the Catch log from a SavedVariables folder after a fishing stretch and checks the M1 exit check's steps 3
-- and 4 (#75), so nobody reads PagleLog by hand. docs/agents/exit-check.md says when to run it.
--
--   lua scripts/read-catch-log.lua <WTF/Account/<ACCOUNT>/SavedVariables folder> [--expect-casts N] [--since T]
--
-- It decodes PagleLog with Core's own codec (addons/Pagle/logic/CatchLog.lua, loaded as Core loads it) and prints
-- the logId, the entries by tag, the C1 Casts by outcome, per character and per zone areaID, the Casts in zone
-- areaID 0, their time span, the B1 and S1 entries and PagleDB.global.decodeErrors.
--
--   --since T         counts only the Casts at server time T (Unix seconds) or later: this session's
--   --expect-casts N  checks steps 3 and 4: N C1 Casts, each there once, no zone areaID 0, a B1 and an S1 entry,
--                     decodeErrors 0, every entry decodes, and at least one Cast got away (`g`)
--
-- Exits 0 when the log reads (and, with --expect-casts, every check passes), 1 when a check fails, 2 on a usage
-- error or when Pagle.lua can't be read. Pagle.lua is loaded as data: it runs in an empty environment, so it can
-- only assign values, and precompiled chunks are refused. The folder is only read.

local USAGE = "usage: lua scripts/read-catch-log.lua <SavedVariables folder> [--expect-casts N] [--since T]\n"

-- The repo root, from this script's path.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = {}
	local i = 1
	while args[i] do
		local word, value = args[i], args[i + 1]
		if word == "--expect-casts" or word == "--since" then
			if not value or not value:match("^%d+$") then
				return nil, word .. " needs a whole number"
			end
			options[word == "--since" and "since" or "expectCasts"] = tonumber(value)
			i = i + 2
		elseif word:sub(1, 1) == "-" then
			return nil, "unknown option " .. word
		elseif options.folder then
			return nil, "one SavedVariables folder only"
		else
			options.folder = word:gsub("[/\\]+$", "")
			i = i + 1
		end
	end
	if not options.folder then
		return nil, "no SavedVariables folder"
	end
	return options
end

-- Core's namespace with its Catch log codec: the logic/ files the codec needs, each called with ("Pagle", ns) as
-- the client calls an addon's files. logic/ is plain Lua 5.1 (CORE-R7), so the standard globals are all it gets.
local function loadCodec()
	local ns = {}
	local env = setmetatable({}, { __index = _G })
	for _, file in ipairs({ "Conditions.lua", "CatchLog.lua" }) do
		local chunk = assert(loadfile(ROOT .. "/addons/Pagle/logic/" .. file))
		setfenv(chunk, env)
		chunk("Pagle", ns)
	end
	return ns
end

-- Loads a SavedVariables file as data and returns the globals it assigned. Returns nil and a reason when the file
-- is missing or isn't plain Lua source that runs with no globals at all.
local function loadSavedVariables(path)
	local file = io.open(path, "rb")
	if not file then
		return nil, "missing"
	end
	local source = file:read("*a")
	file:close()
	if source:sub(1, 1) == "\27" then
		return nil, "a precompiled chunk, not data"
	end
	local chunk, loadErr = loadstring(source, "=" .. path:match("[^/\\]*$"))
	if not chunk then
		return nil, loadErr
	end
	local globals = {}
	setfenv(chunk, globals)
	local ok, runErr = pcall(chunk)
	if not ok then
		return nil, runErr
	end
	return globals
end

local function utc(time)
	return os.date("!%Y-%m-%d %H:%M:%S UTC", time)
end

-- "1 entry", "2 entries"; plural defaults to noun .. "s".
local function count(n, noun, plural)
	return n .. " " .. (n == 1 and noun or plural or noun .. "s")
end

local OUTCOMES = { "caught", "gotAway" }
local OUTCOME_NAMES = { caught = "caught", gotAway = "got away" }

-- A tally of outcomes as "caught 3, got away 1", leaving out those with none.
local function outcomes(tally)
	local parts = {}
	for _, outcome in ipairs(OUTCOMES) do
		if (tally[outcome] or 0) > 0 then
			parts[#parts + 1] = OUTCOME_NAMES[outcome] .. " " .. tally[outcome]
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or "none"
end

-- The keys of a table, in ascending order.
local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

-- What the log holds, read with Core's codec: the Casts counted (those at `since` or later), the tags, the last
-- B1 and S1 entries and the entries the codec can't decode.
local function readLog(ns, log, since)
	local tags = {}
	for _, entry in ipairs(log.entries) do
		local tag = type(entry) == "string" and entry:match("^[^|]*") or "(not a string)"
		tags[tag] = (tags[tag] or 0) + 1
	end
	-- A reader's own decodeErrors, so the file's count stays what Pagle counted in the game.
	local global = { decodeErrors = 0 }
	local catchLog = ns.OpenCatchLog(log, global, 0)
	local facts = { tags = tags, casts = {}, allCasts = 0, builds = 0, skills = 0 }
	for record in catchLog:Iterate() do
		if record.kind == "cast" then
			facts.allCasts = facts.allCasts + 1
			if record.time >= (since or 0) then
				facts.casts[#facts.casts + 1] = record
			end
		elseif record.kind == "build" then
			facts.builds, facts.build = facts.builds + 1, record
		elseif record.kind == "skill" then
			facts.skills, facts.skill = facts.skills + 1, record
		end
	end
	facts.undecodable = global.decodeErrors
	return facts
end

local function characterName(log, char)
	local c = log.characters[char] or {}
	local name = table.concat({ tostring(c.name or "?"), c.surname and tostring(c.surname) or nil }, " ")
	return ("%d %s (%s)"):format(char, name, tostring(c.guid))
end

local function printCasts(log, facts, since)
	local casts = facts.casts
	local first, last = math.huge, -math.huge
	local byOutcome, byChar, byZone, zeroZone = {}, {}, {}, {}
	for _, cast in ipairs(casts) do
		first, last = math.min(first, cast.time), math.max(last, cast.time)
		byOutcome[cast.outcome] = (byOutcome[cast.outcome] or 0) + 1
		byChar[cast.char] = byChar[cast.char] or {}
		byChar[cast.char][cast.outcome] = (byChar[cast.char][cast.outcome] or 0) + 1
		local zone = cast.conditions.zone
		byZone[zone] = byZone[zone] or {}
		byZone[zone][cast.outcome] = (byZone[zone][cast.outcome] or 0) + 1
		if zone == 0 then
			zeroZone[#zeroZone + 1] = cast.seq
		end
	end
	local which = since and (" of %d, since %s (--since %d)"):format(facts.allCasts, utc(since), since) or ""
	if #casts == 0 then
		print("C1: no Casts" .. which)
		return
	end
	print(
		("C1: %s%s, from %s to %s (%d min)"):format(
			count(#casts, "Cast"),
			which,
			utc(first),
			utc(last),
			math.floor((last - first) / 60)
		)
	)
	print("C1 outcomes: " .. outcomes(byOutcome))
	print("C1 by character:")
	for _, char in ipairs(sortedKeys(byChar)) do
		print("  " .. characterName(log, char) .. ": " .. outcomes(byChar[char]))
	end
	print("C1 by zone areaID:")
	for _, zone in ipairs(sortedKeys(byZone)) do
		print("  " .. zone .. ": " .. outcomes(byZone[zone]))
	end
	print(
		"zone areaID 0: "
			.. (#zeroZone > 0 and count(#zeroZone, "Cast") .. ", seq " .. table.concat(zeroZone, ", ") or "none")
	)
end

local function printLog(log, facts, options)
	local tags = {}
	for _, tag in ipairs(sortedKeys(facts.tags)) do
		tags[#tags + 1] = tag .. " " .. facts.tags[tag]
	end
	print("entries by tag: " .. (#tags > 0 and table.concat(tags, ", ") or "none"))
	print("entries the codec can't decode: " .. (facts.undecodable > 0 and facts.undecodable or "none"))
	printCasts(log, facts, options.since)
	local build, skill = facts.build, facts.skill
	if build then
		local builds = count(facts.builds, "entry", "entries")
		print(("B1: %s, the last build %d (%s)"):format(builds, build.build, build.version))
	else
		print("B1: none")
	end
	if skill then
		local skills = count(facts.skills, "entry", "entries")
		local last = ("rank %d, max %d, mod %d (character %d)"):format(skill.rank, skill.max, skill.mod, skill.char)
		print(("S1: %s, the last %s"):format(skills, last))
	else
		print("S1: none")
	end
end

-- The exit check's steps 3 and 4 (#75) over the Casts counted, as { ok, line } pairs.
local function exitChecks(facts, global, expected)
	local checks = {}
	local function check(ok, line)
		checks[#checks + 1] = { ok = ok, line = line }
	end
	local casts = facts.casts
	check(
		#casts == expected,
		count(#casts, "C1 Cast") .. (#casts == expected and ", the dev's count" or ", the dev counted " .. expected)
	)
	local ids, repeated, zeroZone, gotAway = {}, {}, 0, 0
	for _, cast in ipairs(casts) do
		if ids[cast.id] then
			repeated[#repeated + 1] = cast.id
		end
		ids[cast.id] = true
		zeroZone = zeroZone + (cast.conditions.zone == 0 and 1 or 0)
		gotAway = gotAway + (cast.outcome == "gotAway" and 1 or 0)
	end
	check(
		#repeated == 0,
		#repeated == 0 and "each Cast is there once (no repeated entry ID)"
			or "repeated entry ID: " .. table.concat(repeated, ", ")
	)
	check(zeroZone == 0, zeroZone == 0 and "no Cast in zone areaID 0" or count(zeroZone, "Cast") .. " in zone areaID 0")
	check(facts.builds > 0, facts.builds > 0 and "a B1 entry" or "no B1 entry")
	check(facts.skills > 0, facts.skills > 0 and "an S1 entry" or "no S1 entry")
	check(global.decodeErrors == 0, "PagleDB.global.decodeErrors is " .. tostring(global.decodeErrors))
	check(
		facts.undecodable == 0,
		facts.undecodable == 0 and "every entry decodes"
			or count(facts.undecodable, "entry", "entries") .. " the codec can't decode"
	)
	check(gotAway > 0, gotAway > 0 and count(gotAway, "Cast") .. " got away (g)" or "no Cast got away (g)")
	return checks
end

-- Prints the checks under one heading; true when every one passed.
local function printChecks(checks)
	local failed = 0
	for _, c in ipairs(checks) do
		failed = failed + (c.ok and 0 or 1)
	end
	local verdict = failed == 0 and "passed" or ("FAILED (%d of %d checks)"):format(failed, #checks)
	print("== Exit check (#75 steps 3 and 4): " .. verdict)
	for _, c in ipairs(checks) do
		print((c.ok and "  ok    " or "  FAIL  ") .. c.line)
	end
	return failed == 0
end

local function main(args)
	if args[1] == "--help" or args[1] == "-h" then
		print(USAGE)
		return 0
	end
	local options, err = parseArgs(args)
	if not options then
		io.stderr:write("read-catch-log: " .. err .. "\n" .. USAGE)
		return 2
	end
	local path = options.folder .. "/Pagle.lua"
	local saved, loadErr = loadSavedVariables(path)
	if not saved then
		io.stderr:write(("read-catch-log: can't read %s: %s\n"):format(path, loadErr))
		return 2
	end
	local ns = loadCodec()
	local log = saved.PagleLog
	if type(log) ~= "table" or type(log.entries) ~= "table" or type(log.characters) ~= "table" then
		io.stderr:write("read-catch-log: " .. path .. " holds no PagleLog with characters and entries\n")
		return 2
	end
	print("== Catch log: " .. path)
	print(
		("PagleLog: format %s, logId %s, %s, %s"):format(
			tostring(log.format),
			tostring(log.logId),
			count(#log.characters, "character"),
			count(#log.entries, "entry", "entries")
		)
	)
	local db = saved.PagleDB
	local global = type(db) == "table" and type(db.global) == "table" and db.global or {}
	print("PagleDB.global.decodeErrors: " .. tostring(global.decodeErrors))
	local checks
	if log.format ~= ns.LOG_FORMAT then
		-- Opening it would set it aside for a new log (LOG-R18), so it isn't decoded at all.
		print(
			("format %s isn't the codec's format %d: Core starts a new log at login"):format(log.format, ns.LOG_FORMAT)
		)
		checks = {
			{
				ok = false,
				line = ("PagleLog is format %s, the codec reads format %d"):format(log.format, ns.LOG_FORMAT),
			},
		}
	else
		local facts = readLog(ns, log, options.since)
		printLog(log, facts, options)
		checks = options.expectCasts and exitChecks(facts, global, options.expectCasts)
	end
	if options.expectCasts and not printChecks(checks) then
		return 1
	end
	return 0
end

os.exit(main(arg))
