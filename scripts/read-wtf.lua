-- Reads what the WoW client wrote under one WTF account folder, so an agent can check in-game results without the
-- dev reading files (docs/agents/in-game-verification.md). It prints:
--   - the latest !BugGrabber session's Lua errors, with their stacks;
--   - the PagleLog and PagleDB facts the M1 exit check asks for;
--   - named CVars from Config.wtf and the account's and the character's config-cache.wtf;
--   - named addons' enable state from the character's AddOns.txt.
--
--   lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm folder>/<Name-Surname>]
--       [--cvar <name>]... [--addon <name>]...
--
-- --cvar defaults to SoftTargetInteract and --addon to Pagle and Pagle_QoL; naming one replaces its defaults.
-- The character's CVars and addons need --character, e.g. --character 70/Ada-Brook.
--
-- SavedVariables files are loaded as data: each runs in an empty environment, so it can only assign values, and
-- precompiled chunks are refused. Exits 2 on a usage error, otherwise 0, whatever the files hold.

local USAGE = "usage: lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm>/<Name-Surname>]"
	.. " [--cvar <name>]... [--addon <name>]...\n"

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

-- `key: n` pairs in ascending key order, joined with commas.
local function tally(counts)
	local keys = {}
	for key in pairs(counts) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or math.huge) < (tonumber(b) or math.huge) or (tonumber(a) == tonumber(b) and a < b)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = key .. ": " .. counts[key]
	end
	return table.concat(parts, ", ")
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

-- The header and the fields after it, split at every `|` (LOG-R11), or nil when the entry has no header.
local function splitEntry(entry)
	if type(entry) ~= "string" then
		return nil
	end
	local fields = {}
	for field in (entry .. "|"):gmatch("([^|]*)|") do
		fields[#fields + 1] = field
	end
	if #fields < 4 or not fields[1]:match("^%u%d+$") or not tonumber(fields[3]) then
		return nil
	end
	return fields
end

local function printCatchLog(account)
	local path = account .. "/SavedVariables/Pagle.lua"
	local saved, err = loadSavedVariables(path)
	if not saved then
		print("== Catch log: can't read " .. path .. ": " .. err)
		return
	end
	local log = saved.PagleLog
	if type(log) ~= "table" then
		print("== Catch log: Pagle.lua holds no PagleLog")
	else
		local entries = type(log.entries) == "table" and log.entries or {}
		local characters = type(log.characters) == "table" and #log.characters or 0
		print(
			("== Catch log (PagleLog): format %s, logId %s, %s, %s"):format(
				tostring(log.format),
				tostring(log.logId),
				count(characters, "character"),
				count(#entries, "entry", "entries")
			)
		)

		local tags, outcomes, zones, ids, repeated = {}, {}, {}, {}, {}
		local unreadable, casts, first, last = 0, 0, nil, nil
		local builds, skill, skills = {}, nil, 0
		for _, entry in ipairs(entries) do
			local f = splitEntry(entry)
			if not f then
				unreadable = unreadable + 1
			else
				local tag, time = f[1], tonumber(f[3])
				tags[tag] = (tags[tag] or 0) + 1
				-- The entry ID is <character GUID>-<time>-<tie> (LOG-R13); the character index stands for the GUID.
				local id = f[2] .. "-" .. f[3] .. "-" .. f[4]
				if ids[id] then
					repeated[#repeated + 1] = id
				end
				ids[id] = true
				if tag == "C1" then
					casts = casts + 1
					first, last = first and math.min(first, time) or time, last and math.max(last, time) or time
					local outcome = f[5] or ""
					outcomes[outcome] = (outcomes[outcome] or 0) + 1
					local zone = f[9] ~= "" and f[9] or "(empty)"
					zones[zone] = (zones[zone] or 0) + 1
				elseif tag == "B1" then
					builds[#builds + 1] = ("%s (%s)"):format(tostring(f[5]), tostring(f[6]))
				elseif tag == "S1" then
					skills = skills + 1
					skill = ("rank %s, max %s, mod %s"):format(tostring(f[5]), tostring(f[6]), tostring(f[7]))
				end
			end
		end

		print("entries by tag: " .. (next(tags) and tally(tags) or "none"))
		print("unreadable entries (no tag|char|time|tie header): " .. unreadable)
		print("repeated entry IDs (char-time-tie): " .. (#repeated > 0 and table.concat(repeated, ", ") or "none"))
		if casts > 0 then
			print(("C1: %s, from %s to %s"):format(count(casts, "entry", "entries"), utc(first), utc(last)))
			print("C1 outcomes (c caught, g got away): " .. tally(outcomes))
			print("C1 zone areaIDs (areaID: Casts): " .. tally(zones))
		else
			print("C1: no entries")
		end
		print("B1 builds: " .. (#builds > 0 and table.concat(builds, ", ") or "none"))
		print("S1: " .. (skill and count(skills, "Skill Reading") .. ", the last " .. skill or "no Skill Readings"))
	end

	local db = saved.PagleDB
	local global = type(db) == "table" and type(db.global) == "table" and db.global or nil
	if not global then
		print("PagleDB.global: not in Pagle.lua")
	else
		print("PagleDB.global.decodeErrors: " .. tostring(global.decodeErrors))
	end
end

-- `SET <name> "<value>"` lines as a table keyed by the lowercased name; CVar names ignore case.
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
	printCatchLog(options.account)
	printCVars(options.account, options.character, options.cvars)
	printAddons(options.account, options.character, options.addons)
	return 0
end

os.exit(main(arg))
