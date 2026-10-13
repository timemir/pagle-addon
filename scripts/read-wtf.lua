-- Reads what the WoW client wrote under one WTF account folder, so an agent can check in-game results without the
-- dev reading files (docs/agents/in-game-verification.md). It prints:
--   - the latest !BugGrabber session's Lua errors, with their stacks;
--   - the Catch log, decoded with Core's own codec (addons/Pagle/logic/CatchLog.lua): the logId, the entries by
--     tag, the C1 Casts by outcome, per character and per zone areaID, those in zone areaID 0, their time span, the
--     B1 and S1 entries and PagleDB.global.decodeErrors (0 when AceDB left that default out of the file);
--   - named CVars from Config.wtf and the account's and the character's config-cache.wtf;
--   - named addons' enable state from the character's AddOns.txt.
--
--   lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm folder>/<Name-Surname>]
--       [--cvar <name>]... [--addon <name>]... [--expect-casts N] [--since T]
--
-- --cvar defaults to SoftTargetInteract and --addon to Pagle and Pagle_QoL; naming one replaces its defaults.
-- The character's CVars and addons need --character, e.g. --character 70/Ada-Brook.
-- --expect-casts N checks the M1 exit check's steps 3 and 4 (#75): N C1 Casts, each there once, no zone areaID 0,
-- a B1 and an S1 entry, decodeErrors 0, every entry decodes, and at least one Cast got away (`g`). --since T
-- counts only the Casts at server time T (Unix seconds) or later; B1 and S1 are still looked for in the whole log.
--
-- SavedVariables files are loaded as data: each runs in an empty environment, so it can only assign values, and
-- precompiled chunks are refused. Exits 2 on a usage error, 1 when an --expect-casts check fails, otherwise 0,
-- whatever the files hold.

local USAGE = "usage: lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm>/<Name-Surname>]"
	.. " [--cvar <name>]... [--addon <name>]... [--expect-casts N] [--since T]\n"

-- The repo root, from this script's path: Core's codec is read from addons/Pagle/logic/.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = { cvars = {}, addons = {} }
	local i = 1
	while args[i] do
		local word, value = args[i], args[i + 1]
		if word == "--character" or word == "--cvar" or word == "--addon" then
			if not value then
				return nil, word .. " needs a value"
			end
			if word == "--character" then
				options.character = value:gsub("[/\\]+$", "")
			else
				local list = word == "--cvar" and options.cvars or options.addons
				list[#list + 1] = value
			end
			i = i + 2
		elseif word == "--expect-casts" or word == "--since" then
			if not value or not value:match("^%d+$") then
				return nil, word .. " needs a whole number"
			end
			options[word == "--since" and "since" or "expectCasts"] = tonumber(value)
			i = i + 2
		elseif word:sub(1, 1) == "-" then
			return nil, "unknown option " .. word
		elseif options.account then
			return nil, "one account folder only"
		else
			options.account = word:gsub("[/\\]+$", "")
			i = i + 1
		end
	end
	if not options.account then
		return nil, "no account folder"
	end
	if #options.cvars == 0 then
		options.cvars = { "SoftTargetInteract" }
	end
	if #options.addons == 0 then
		options.addons = { "Pagle", "Pagle_QoL" }
	end
	return options
end

-- A file's lines without their line ends (the client writes CRLF), or nil when it can't be opened.
local function readLines(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local lines = {}
	for line in file:lines() do
		lines[#lines + 1] = (line:gsub("\r$", ""))
	end
	file:close()
	return lines
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

-- "1 Cast", "2 Casts"; plural defaults to noun .. "s".
local function count(n, noun, plural)
	return n .. " " .. (n == 1 and noun or plural or noun .. "s")
end

local function printErrors(account)
	local path = account .. "/SavedVariables/!BugGrabber.lua"
	local saved, err = loadSavedVariables(path)
	local db = saved and saved.BugGrabberDB
	if not db then
		print("== Lua errors: can't read " .. path .. ": " .. (err or "no BugGrabberDB in it"))
		return
	end
	local session = db.session
	local errors = {}
	for _, e in ipairs(type(db.errors) == "table" and db.errors or {}) do
		if type(e) == "table" and e.session == session then
			errors[#errors + 1] = e
		end
	end
	print(("== Lua errors (!BugGrabber, latest session %s): %s"):format(tostring(session), count(#errors, "error")))
	for i, e in ipairs(errors) do
		local times = (tonumber(e.counter) or 1) > 1 and (" (x%d)"):format(e.counter) or ""
		print(("%d. %s%s"):format(i, tostring(e.message), times))
		for line in tostring(e.stack or "(no stack)"):gmatch("[^\n]+") do
			print("   " .. line)
		end
	end
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

local OUTCOMES = { "caught", "gotAway" }
local OUTCOME_NAMES = { caught = "caught", gotAway = "got away" }

-- A tally of outcomes as "caught 3, got away 1", leaving out those with none.
local function outcomes(counts)
	local parts = {}
	for _, outcome in ipairs(OUTCOMES) do
		if (counts[outcome] or 0) > 0 then
			parts[#parts + 1] = OUTCOME_NAMES[outcome] .. " " .. counts[outcome]
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

-- What the log holds, decoded with Core's codec: the Casts counted (those at `since` or later), the tags, the last
-- B1 and S1 entries, repeated entry IDs and the entries the codec can't decode.
local function readLog(ns, log, since)
	local tags = {}
	for _, entry in ipairs(log.entries) do
		local tag = type(entry) == "string" and entry:match("^(%u%d+)|") or "(no tag)"
		tags[tag] = (tags[tag] or 0) + 1
	end
	-- The reader's own decodeErrors, so the file's count stays what Pagle counted in the game (LOG-R16).
	local global = { decodeErrors = 0 }
	local catchLog = ns.OpenCatchLog(log, global, 0)
	local facts = { tags = tags, casts = {}, allCasts = 0, builds = 0, skills = 0, repeated = {} }
	local ids = {}
	for record in catchLog:Iterate() do
		if ids[record.id] then
			facts.repeated[#facts.repeated + 1] = record.id
		end
		ids[record.id] = true
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
	local span = math.floor((last - first) / 60)
	print(("C1: %s%s, from %s to %s (%d min)"):format(count(#casts, "Cast"), which, utc(first), utc(last), span))
	print("C1 outcomes: " .. outcomes(byOutcome))
	print("C1 by character:")
	for _, char in ipairs(sortedKeys(byChar)) do
		print("  " .. characterName(log, char) .. ": " .. outcomes(byChar[char]))
	end
	print("C1 by zone areaID:")
	for _, zone in ipairs(sortedKeys(byZone)) do
		print("  " .. zone .. ": " .. outcomes(byZone[zone]))
	end
	local zero = #zeroZone > 0 and count(#zeroZone, "Cast") .. ", seq " .. table.concat(zeroZone, ", ")
	print("zone areaID 0: " .. (zero or "none"))
end

local function printLog(log, facts, since)
	local tags = {}
	for _, tag in ipairs(sortedKeys(facts.tags)) do
		tags[#tags + 1] = tag .. " " .. facts.tags[tag]
	end
	print("entries by tag: " .. (#tags > 0 and table.concat(tags, ", ") or "none"))
	print("entries Core's codec can't decode: " .. (facts.undecodable > 0 and facts.undecodable or "none"))
	print("repeated entry IDs: " .. (#facts.repeated > 0 and table.concat(facts.repeated, ", ") or "none"))
	printCasts(log, facts, since)
	local build, skill = facts.build, facts.skill
	if build then
		local builds = count(facts.builds, "entry", "entries")
		print(("B1: %s, the last build %d (%s)"):format(builds, build.build, build.version))
	else
		print("B1: none")
	end
	if skill then
		local skills = count(facts.skills, "entry", "entries")
		local reading = ("rank %d, max %d, mod %d (character %d)"):format(skill.rank, skill.max, skill.mod, skill.char)
		print(("S1: %s, the last %s"):format(skills, reading))
	else
		print("S1: none")
	end
end

-- The exit check's steps 3 and 4 (#75) over the Casts counted, as { ok, line } pairs.
local function exitChecks(facts, decodeErrors, expected)
	local checks = {}
	local function check(ok, line)
		checks[#checks + 1] = { ok = ok, line = line }
	end
	local casts = facts.casts
	local counted = #casts == expected and ", the dev's count" or ", the dev counted " .. expected
	check(#casts == expected, count(#casts, "C1 Cast") .. counted)
	local ids, repeated, zeroZone, gotAway = {}, {}, 0, 0
	for _, cast in ipairs(casts) do
		if ids[cast.id] then
			repeated[#repeated + 1] = cast.id
		end
		ids[cast.id] = true
		zeroZone = zeroZone + (cast.conditions.zone == 0 and 1 or 0)
		gotAway = gotAway + (cast.outcome == "gotAway" and 1 or 0)
	end
	local once = #repeated == 0 and "each Cast is there once (no repeated entry ID)"
	check(#repeated == 0, once or "repeated entry ID: " .. table.concat(repeated, ", "))
	check(zeroZone == 0, zeroZone == 0 and "no Cast in zone areaID 0" or count(zeroZone, "Cast") .. " in zone areaID 0")
	check(facts.builds > 0, facts.builds > 0 and "a B1 entry" or "no B1 entry")
	check(facts.skills > 0, facts.skills > 0 and "an S1 entry" or "no S1 entry")
	check(decodeErrors.count == 0, "PagleDB.global.decodeErrors is " .. decodeErrors.text)
	local undecodable = count(facts.undecodable, "entry", "entries") .. " Core's codec can't decode"
	check(facts.undecodable == 0, facts.undecodable == 0 and "every entry decodes" or undecodable)
	check(gotAway > 0, gotAway > 0 and count(gotAway, "Cast") .. " got away (g)" or "no Cast got away (g)")
	return checks
end

-- Prints the Catch log section and returns the exit check's checks (#75 steps 3 and 4), which need expectCasts.
local function printCatchLog(account, expectCasts, since)
	local path = account .. "/SavedVariables/Pagle.lua"
	local saved, err = loadSavedVariables(path)
	if not saved then
		print("== Catch log: can't read " .. path .. ": " .. err)
		return { { ok = false, line = "no Pagle.lua to read" } }
	end
	local db = saved.PagleDB
	local global = type(db) == "table" and type(db.global) == "table" and db.global or {}
	local log = saved.PagleLog
	if type(log) ~= "table" or type(log.entries) ~= "table" or type(log.characters) ~= "table" then
		print("== Catch log: Pagle.lua holds no PagleLog with characters and entries")
		return { { ok = false, line = "no PagleLog in Pagle.lua" } }
	end
	print(
		("== Catch log (PagleLog): format %s, logId %s, %s, %s"):format(
			tostring(log.format),
			tostring(log.logId),
			count(#log.characters, "character"),
			count(#log.entries, "entry", "entries")
		)
	)
	-- AceDB leaves out of the file every value equal to its default, so a PagleDB without decodeErrors means 0.
	local decodeErrors = { count = global.decodeErrors, text = tostring(global.decodeErrors) }
	if type(db) == "table" and global.decodeErrors == nil then
		decodeErrors = { count = 0, text = "0 (not saved: AceDB leaves out a default)" }
	end
	print(type(db) == "table" and "PagleDB.global.decodeErrors: " .. decodeErrors.text or "PagleDB: not in Pagle.lua")
	local ns = loadCodec()
	if log.format ~= ns.LOG_FORMAT then
		-- Opening it would set it aside for a new log (LOG-R18), so it isn't decoded at all.
		local format = ("format %s, the codec reads format %d"):format(tostring(log.format), ns.LOG_FORMAT)
		print("PagleLog is " .. format .. ": Core starts a new log at login")
		return { { ok = false, line = "PagleLog is " .. format } }
	end
	local facts = readLog(ns, log, since)
	printLog(log, facts, since)
	return expectCasts and exitChecks(facts, decodeErrors, expectCasts) or {}
end

-- Prints the exit check's checks under one heading; true when every one passed.
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

local function readCVars(path)
	local lines = readLines(path)
	if not lines then
		return nil
	end
	local cvars = {}
	for _, line in ipairs(lines) do
		local name, value = line:match('^SET (%S+) "(.*)"$')
		if name then
			cvars[name:lower()] = { name = name, value = value }
		end
	end
	return cvars
end

local function printCVars(account, character, names)
	-- Config.wtf sits two levels up, in WTF/; the character's file only with --character.
	local sources = {
		{ label = "Config.wtf", path = account .. "/../../Config.wtf" },
		{ label = "account config-cache.wtf", path = account .. "/config-cache.wtf" },
	}
	if character then
		sources[3] =
			{ label = character .. "/config-cache.wtf", path = account .. "/" .. character .. "/config-cache.wtf" }
	end
	local read, missing = {}, {}
	for _, source in ipairs(sources) do
		source.cvars = readCVars(source.path)
		local list = source.cvars and read or missing
		list[#list + 1] = source.label
	end
	print(
		"== CVars, from "
			.. (#read > 0 and table.concat(read, ", ") or "no file")
			.. (#missing > 0 and "; missing: " .. table.concat(missing, ", ") or "")
			.. (character and "" or "; the character's config-cache.wtf needs --character")
	)
	for _, name in ipairs(names) do
		local found = {}
		for _, source in ipairs(sources) do
			local cvar = source.cvars and source.cvars[name:lower()]
			if cvar then
				found[#found + 1] = ('"%s" in %s'):format(cvar.value, source.label)
			end
		end
		print(name .. ": " .. (#found > 0 and table.concat(found, ", ") or "not set (the client's default applies)"))
	end
end

local function printAddons(account, character, names)
	if not character then
		print("== Addons: enable state needs --character <realm folder>/<Name-Surname>")
		return
	end
	local path = account .. "/" .. character .. "/AddOns.txt"
	local lines = readLines(path)
	if not lines then
		print("== Addons: can't read " .. path)
		return
	end
	-- Addon names ignore case.
	local states = {}
	for _, line in ipairs(lines) do
		local name, state = line:match("^(.-): (%a+)$")
		if name then
			states[name:lower()] = state
		end
	end
	print("== Addons (" .. character .. "/AddOns.txt)")
	for _, name in ipairs(names) do
		print(name .. ": " .. (states[name:lower()] or "not listed (its TOC's default state applies)"))
	end
end

local function main(args)
	if args[1] == "--help" or args[1] == "-h" then
		print(USAGE)
		return 0
	end
	local options, err = parseArgs(args)
	if not options then
		io.stderr:write("read-wtf: " .. err .. "\n" .. USAGE)
		return 2
	end
	printErrors(options.account)
	local checks = printCatchLog(options.account, options.expectCasts, options.since)
	printCVars(options.account, options.character, options.cvars)
	printAddons(options.account, options.character, options.addons)
	-- Last, so the verdict is the output's last word.
	if options.expectCasts and not printChecks(checks) then
		return 1
	end
	return 0
end

os.exit(main(arg))
