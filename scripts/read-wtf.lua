-- Reads what the WoW client wrote under one WTF account folder, so an agent can check in-game results without the
-- dev reading files (docs/agents/in-game-verification.md). It prints:
--   - the latest !BugGrabber session's Lua errors, with their stacks;
--   - the Catch log, decoded with Core's own codec (addons/Pagle/logic/CatchLog.lua): the logId, the entries by
--     tag, the C1 Casts by outcome, per character and per zone areaID, those in zone areaID 0, their time span, the
--     B1 and S1 entries, each P1 (Prestige) and U1 (purchase) entry, and PagleDB.global.decodeErrors (0 when AceDB
--     left that default out of the file);
--   - the Ledger (PagleLedgerDB in Pagle_Ledger.lua): the projection Core stores and whether its logId, lastSeq and
--     rulesVersion are current, its state (items, the Uncharted list, zone ranks) with what the Ledger's own logic/
--     computes from it over the world index (the level, charted zones, shown ranks, Ledger completion), and the
--     celebrated set; then, in a Ledger M4 section, the climb with Prestige, the Catch Milestones, the Legends, the
--     Simulated Size records, the earned and active titles and the celebrated set's M4 keys;
--   - the wallet: each Module's reported Coins (PagleDB.global.coins.earned), the balance (held while negative) and
--     the wallet projection (PagleDB.global.projections.wallet): spent and purchased;
--   - the looks: each slot's equipped good (PagleDB.profile.appearance), the goods cache and the length unit;
--   - the cards: the Write-up waiting, the Session summary cards, the open summary and the pending moments;
--   - the Field report projection (PagleDB.global.projections.fieldReport), its row count and the reporter key;
--   - named CVars from Config.wtf and the account's and the character's config-cache.wtf;
--   - named addons' enable state from the character's AddOns.txt.
--
--   lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm folder>/<Name-Surname>]
--       [--cvar <name>]... [--addon <name>]... [--catalogue <Catalogue.lua>] [--item <id>]... [--expect-casts N]
--       [--since T]
--
-- --cvar defaults to SoftTargetInteract and --addon to Pagle, Pagle_Ledger and Pagle_QoL; naming one replaces its
-- defaults.
-- The character's CVars and addons need --character, e.g. --character 70/Ada-Brook.
-- --catalogue builds the Ledger's world from another Catalogue.lua than the repo's addons/Pagle/data/Catalogue.lua,
-- such as the installed addon's.
-- --item <id> prints the Simulated Size record (LED-R80) the Ledger keeps for that Species or Legend item ID.
-- --expect-casts N checks the M1 exit check's steps 3 and 4 (#75): N C1 Casts, each there once, no zone areaID 0,
-- a B1 and an S1 entry, decodeErrors 0, every entry decodes, and at least one Cast got away (`g`). --since T
-- counts only the Casts at server time T (Unix seconds) or later; B1 and S1 are still looked for in the whole log.
--
-- SavedVariables files are loaded as data: each runs in an empty environment, so it can only assign values, and
-- precompiled chunks are refused. Exits 2 on a usage error, 1 when an --expect-casts check fails, otherwise 0,
-- whatever the files hold.

local USAGE = "usage: lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm>/<Name-Surname>]"
	.. " [--cvar <name>]... [--addon <name>]... [--catalogue <Catalogue.lua>] [--item <id>]... [--expect-casts N]"
	.. " [--since T]\n"

-- The repo root, from this script's path: Core's and the Ledger's logic/ and the catalogue are read from addons/.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = { cvars = {}, addons = {}, items = {} }
	local i = 1
	while args[i] do
		local word, value = args[i], args[i + 1]
		if word == "--character" or word == "--cvar" or word == "--addon" or word == "--catalogue" then
			if not value then
				return nil, word .. " needs a value"
			end
			if word == "--character" then
				options.character = value:gsub("[/\\]+$", "")
			elseif word == "--catalogue" then
				options.catalogue = value
			else
				local list = word == "--cvar" and options.cvars or options.addons
				list[#list + 1] = value
			end
			i = i + 2
		elseif word == "--expect-casts" or word == "--since" or word == "--item" then
			if not value or not value:match("^%d+$") then
				return nil, word .. " needs a whole number"
			end
			if word == "--item" then
				options.items[#options.items + 1] = tonumber(value)
			else
				options[word == "--since" and "since" or "expectCasts"] = tonumber(value)
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
		options.addons = { "Pagle", "Pagle_Ledger", "Pagle_QoL" }
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
	for _, file in ipairs({ "Conditions.lua", "Sessions.lua", "CatchLog.lua" }) do
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
	facts.prestiges, facts.purchases = {}, {}
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
		elseif record.kind == "prestige" or record.kind == "purchase" then
			local list = record.kind == "prestige" and facts.prestiges or facts.purchases
			list[#list + 1] = record
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

-- The Prestige (P1, LOG-R38) and purchase (U1, LOG-R39) entries: a count each, then one line per entry, P1 with
-- its rank and U1 with its good and price, each with its character and time.
local function printPrestigesAndPurchases(log, facts)
	for _, kind in ipairs({ { "P1", facts.prestiges }, { "U1", facts.purchases } }) do
		local tag, records = kind[1], kind[2]
		print(tag .. ": " .. (#records > 0 and count(#records, "entry", "entries") or "none"))
		for _, record in ipairs(records) do
			local what = tag == "P1" and "rank " .. record.rank
				or ("%s for %s"):format(record.good, count(record.price, "Coin"))
			print(("  %s, %s, %s"):format(what, characterName(log, record.char), utc(record.time)))
		end
	end
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
	printPrestigesAndPurchases(log, facts)
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

-- PagleLog from Pagle.lua's globals, or nil when it isn't a log with characters and entries.
local function pagleLog(saved)
	local log = saved and saved.PagleLog
	if type(log) ~= "table" or type(log.entries) ~= "table" or type(log.characters) ~= "table" then
		return nil
	end
	return log
end

-- Prints the Catch log section from Pagle.lua (its globals, or nil and why not) and returns the exit check's checks
-- (#75 steps 3 and 4), which need expectCasts.
local function printCatchLog(pagle, expectCasts, since)
	local saved = pagle.saved
	if not saved then
		print("== Catch log: can't read " .. pagle.path .. ": " .. pagle.err)
		return { { ok = false, line = "no Pagle.lua to read" } }
	end
	local db = saved.PagleDB
	local global = type(db) == "table" and type(db.global) == "table" and db.global or {}
	local log = pagleLog(saved)
	if not log then
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

-- The Ledger's namespace with its logic: each logic/ file Pagle_Ledger.toc lists, in TOC order, called with
-- ("Pagle_Ledger", ns) as the client calls an addon's files (spec/support/addon.lua loads them the same way), so the
-- level shown is the Ledger's own (logic/Progress.lua). Their CORE-R11 guard reads the Pagle global, so it's a table
-- here; logic/ is plain Lua 5.1 (CORE-R7) and reads nothing else of Core's at load.
local function loadLedgerLogic()
	local ns = {}
	local env = setmetatable({ Pagle = {} }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_Ledger/"
	for _, line in ipairs(assert(readLines(dir .. "Pagle_Ledger.toc"))) do
		local file = line:match("^%s*(.-)%s*$"):gsub("\\", "/")
		if file:match("^logic/[^/]+%.lua$") then
			local chunk = assert(loadfile(dir .. file))
			setfenv(chunk, env)
			chunk("Pagle_Ledger", ns)
		end
	end
	return ns
end

-- A table's value, or an empty table when it isn't one (AceDB leaves an empty default out of the file).
local function tableOr(value)
	return type(value) == "table" and value or {}
end

-- A count of a set's keys and the keys themselves, as "2 (6303, 6358)", or "none"; `describe` turns a key and its
-- value into the text shown, `less` orders the keys.
local function listed(set, describe, less)
	local keys = {}
	for key in pairs(set) do
		keys[#keys + 1] = key
	end
	table.sort(keys, less)
	if #keys == 0 then
		return "none"
	end
	local texts = {}
	for i, key in ipairs(keys) do
		texts[i] = describe and describe(key, set[key]) or tostring(key)
	end
	return #keys .. " (" .. table.concat(texts, ", ") .. ")"
end

-- "<speciesID>:<zone>" keys in Species then zone order, as numbers.
local function bySpeciesThenZone(a, b)
	local speciesA, zoneA = a:match("^(%d+):(%d+)$")
	local speciesB, zoneB = b:match("^(%d+):(%d+)$")
	if not (speciesA and speciesB) then
		return a < b
	end
	if speciesA ~= speciesB then
		return tonumber(speciesA) < tonumber(speciesB)
	end
	return tonumber(zoneA) < tonumber(zoneB)
end

-- Core's catalogue accessors (LOG-R55) over a Catalogue.lua in the generated file's shape (DATA-R76): the file and
-- Core's logic/Catalogue.lua, each called with ("Pagle", ns) as the client calls them, as FakePagle builds its
-- catalogue. Returns nil and why when the file can't be loaded.
local function loadCatalogue(path)
	local ns = {}
	local env = setmetatable({}, { __index = _G })
	for _, file in ipairs({ path, ROOT .. "/addons/Pagle/logic/Catalogue.lua" }) do
		local chunk, loadErr = loadfile(file)
		if not chunk then
			return nil, loadErr
		end
		setfenv(chunk, env)
		local ok, runErr = pcall(chunk, "Pagle", ns)
		if not ok then
			return nil, runErr
		end
	end
	if type(ns.catalogue) ~= "table" then
		return nil, "it sets no catalogue"
	end
	local ok, catalogue = pcall(ns.NewCatalogue, ns.catalogue)
	if not ok then
		return nil, catalogue
	end
	return catalogue
end

-- The Ledger's world index (LED-R10), built by its own logic/World.lua over the catalogue at `path` (the repo's
-- generated one unless --catalogue names another), as the Ledger builds it at OnInitialize. Prints which catalogue
-- it is and whether its fingerprint is the one the projection was built against (DATA-R70). Returns the world and
-- GetItem, or nothing when the catalogue can't be loaded.
local function loadWorld(ledger, path, stored)
	local label = path or "the repo's addons/Pagle/data/Catalogue.lua"
	local catalogue, err = loadCatalogue(path or ROOT .. "/addons/Pagle/data/Catalogue.lua")
	if not catalogue then
		print(("world: can't load %s: %s; nothing below is computed"):format(label, tostring(err)))
		return nil
	end
	local world = ledger.NewWorld({
		GetItem = catalogue.GetItem,
		GetZones = catalogue.GetZones,
		GetArea = catalogue.GetArea,
		GetZoneCatches = catalogue.GetZoneCatches,
	})
	local fingerprint = catalogue.CONTENT_FINGERPRINT
	local whose = fingerprint == stored.fingerprint and "the projection's"
		or "NOT the projection's: the lines computed below use it"
	print(
		("world: %s, fingerprint %s (%s), %s"):format(
			label,
			tostring(fingerprint),
			whose,
			count(#world.charted, "charted zone")
		)
	)
	return world, catalogue.GetItem
end

-- The state's trophy and curio items (LED-R60, LED-R64), each with its Catches, by the class the Ledger's own
-- ClassifyCatch gives it now (LED-R5); "other" for any other class, such as an item no longer in the catalogue.
-- Without a catalogue they are listed together, unclassed.
local function printItems(ledger, items, getItem)
	local function withCatches(itemID, first)
		return itemID .. " ×" .. tostring(tableOr(first).n)
	end
	if not getItem then
		print("state items, not classed: " .. listed(items, withCatches))
		return
	end
	-- Legend items (LED-R63) are in the state's items too: the Ledger M4 section lists them.
	local byClass = { curio = {}, trophy = {}, legend = {}, other = {} }
	for itemID, first in pairs(items) do
		local class = ledger.ClassifyCatch(itemID, getItem(itemID))
		byClass[byClass[class] and class or "other"][itemID] = first
	end
	print("state curio items: " .. listed(byClass.curio, withCatches))
	print("state trophy items: " .. listed(byClass.trophy, withCatches))
	if next(byClass.other) then
		print("state other items: " .. listed(byClass.other, withCatches))
	end
end

-- The Uncharted list (LED-R64): each item ID, its Catches and its Catches per zone.
local function printUncharted(uncharted)
	local ids = sortedKeys(uncharted)
	print("state Uncharted: " .. (#ids > 0 and count(#ids, "item") or "none"))
	for _, itemID in ipairs(ids) do
		local entry = tableOr(uncharted[itemID])
		local zones = tableOr(entry.zones)
		local perZone = {}
		for i, zone in ipairs(sortedKeys(zones)) do
			perZone[i] = zone .. " ×" .. tostring(zones[zone])
		end
		local where = #perZone > 0 and ", zones " .. table.concat(perZone, ", ") or ""
		print(("  %s: %s%s"):format(itemID, count(tonumber(entry.n) or 0, "Catch", "Catches"), where))
	end
end

-- Each fished zone (ledger.md › Data, LedgerZone): its computed rank (LED-R50), and with a world whether it's
-- charted (LED-R54) and its shown rank, from the Ledger's own ShownZoneRank (LED-R52, LED-R92).
local function printZones(ledger, view, world, celebrated)
	local zones = sortedKeys(view.zones)
	print("state zones: " .. (#zones > 0 and #zones or "none"))
	for _, zone in ipairs(zones) do
		local line = ("  %s: rank %s"):format(zone, tostring(tableOr(view.zones[zone]).rank or "none"))
		if world then
			local charted = world.zones[zone] and "charted" or "not charted"
			local shown = ledger.ShownZoneRank(world, view, celebrated, zone)
			line = ("%s, %s, shown %d"):format(line, charted, shown)
		end
		print(line)
	end
end

-- Ledger completion and its parts (LED-R70, LED-R71), from the Ledger's own LedgerCompletion; Legends beside it
-- (LED-R63).
local function printCompletion(ledger, view, world, getItem)
	local completion = ledger.LedgerCompletion(world, view, getItem)
	local parts = {}
	for i, part in ipairs({ "species", "junk", "treasure", "trophy", "zones" }) do
		local name = part == "species" and "Species" or part
		parts[i] = ("%s %d of %d"):format(name, completion[part].done, completion[part].total)
	end
	print(
		("completion: %d%% (%d of %d): %s; Legends %d of %d"):format(
			completion.percent,
			completion.done,
			completion.total,
			table.concat(parts, ", "),
			completion.legends.done,
			completion.legends.total
		)
	)
end

-- The state's lines (ledger.md › Data): its counts with the level from the Ledger's own logic/Progress.lua
-- (LED-R30), its items and Uncharted list, its zones, and, with a world, Ledger completion.
local function printLedgerState(ledger, state, world, getItem, celebrated)
	local level, into, cost = ledger.ClimbOf(tonumber(state.xp) or 0, tonumber(state.prestige) or 0)
	local climb = cost and ("Angler Level %d, %d into it, next step %d"):format(level, into, cost)
		or ("Angler Level %d, %d carried"):format(level, into)
	-- An M2 state has no items, Uncharted list or zone ranks.
	local view = {
		species = tableOr(state.species),
		items = tableOr(state.items),
		uncharted = tableOr(state.uncharted),
		zones = tableOr(state.zones),
	}
	print(
		("state: %s, %s, %s XP (%s), %s, %s"):format(
			count(tonumber(state.casts) or 0, "Cast"),
			count(tonumber(state.catches) or 0, "Catch", "Catches"),
			tostring(state.xp),
			climb,
			count(tonumber(state.coins) or 0, "Coin"),
			count(#sortedKeys(view.species), "Species", "Species")
		)
	)
	printItems(ledger, view.items, getItem)
	printUncharted(view.uncharted)
	printZones(ledger, view, world, celebrated)
	if world then
		printCompletion(ledger, view, world, getItem)
	end
end

-- A celebrated star set (LED-R90's `stars` or `familyStars`): the stars in all, and each one's, as
-- "3 on 2 Species (6291 ★1, 6303 ★1 ★2)".
local function celebratedStars(set, noun, plural)
	local ids = sortedKeys(set)
	if #ids == 0 then
		return "none"
	end
	local total, texts = 0, {}
	for i, id in ipairs(ids) do
		local stars = sortedKeys(tableOr(set[id]))
		for j, star in ipairs(stars) do
			stars[j] = "★" .. star
		end
		total = total + #stars
		texts[i] = id .. " " .. table.concat(stars, " ")
	end
	return ("%d on %s (%s)"):format(total, count(#ids, noun, plural), table.concat(texts, ", "))
end

local function printCelebrated(celebrated)
	local highest
	for _, level in pairs(tableOr(celebrated.levels)) do
		highest = math.max(highest or level, level)
	end
	local coins = tonumber(celebrated.coins) or 0 -- AceDB leaves out the default, 0 (LED-R90)
	print(("celebrated: highest level %s, %s"):format(tostring(highest or "none"), count(coins, "Coin")))
	print("celebrated Species: " .. listed(tableOr(celebrated.species)))
	print("celebrated Species × zone pairs: " .. listed(tableOr(celebrated.speciesZones), nil, bySpeciesThenZone))
	print("celebrated zones: " .. listed(tableOr(celebrated.zones), function(zone, rank)
		return zone .. " rank " .. tostring(rank)
	end))
	print("celebrated Species stars: " .. celebratedStars(tableOr(celebrated.stars), "Species", "Species"))
	print("celebrated family stars: " .. celebratedStars(tableOr(celebrated.familyStars), "family", "families"))
	print("celebrated items: " .. listed(tableOr(celebrated.items)))
	print("celebrated Uncharted: " .. listed(tableOr(celebrated.uncharted)))
	print("celebrated Skill Milestones: " .. listed(tableOr(celebrated.skill)))
end

-- Prints a projection's bookkeeping as Core stores it (LOG-R70), and whether its logId and lastSeq match PagleLog's,
-- or Core rebuilds or catches it up at login (LOG-R72).
local function printStored(stored, log)
	print(
		("projection: lastSeq %s, logId %s, fingerprint %s, rulesVersion %s"):format(
			tostring(stored.lastSeq),
			tostring(stored.logId),
			tostring(stored.fingerprint),
			tostring(stored.rulesVersion)
		)
	)
	if not log then
		print("logId: no PagleLog to compare with")
	elseif stored.logId == log.logId then
		print("logId: matches PagleLog's")
	else
		print(("logId: DIFFERS from PagleLog's %s, so Core rebuilds it at login (LOG-R72)"):format(log.logId))
	end
	if log then
		local entries = count(#log.entries, "entry", "entries")
		local same = stored.lastSeq == #log.entries
		print(("lastSeq: %s PagleLog's length (%s)"):format(same and "equals" or "differs from", entries))
	end
end

-- Core's namespace with what M4's lines read of it: its strings (locale/enUS.lua), the size rules and bands
-- (logic/Size.lua, LOG-R65–R68), the wallet (logic/Wallet.lua, SHOP-R12) and the wallet projection's rules version
-- (logic/WalletProjection.lua), each called with ("Pagle", ns) as the client calls them. logic/ is plain Lua 5.1
-- (CORE-R7). Size.lua takes LuaBitOp's functions at load; nothing here hashes a Catch ID, so an empty `bit` serves.
local function loadCoreRules()
	local ns = {}
	local env = setmetatable({ bit = {} }, { __index = _G })
	for _, file in ipairs({ "locale/enUS.lua", "logic/Size.lua", "logic/Wallet.lua", "logic/WalletProjection.lua" }) do
		local chunk = assert(loadfile(ROOT .. "/addons/Pagle/" .. file))
		setfenv(chunk, env)
		chunk("Pagle", ns)
	end
	return ns
end

-- The Ledger M4 section's lines (#173): what M4 adds to the Ledger (ledger.md › Data), with the climb, the earned
-- titles and the active title from the Ledger's own logic/ (Progress.lua, Titles.lua) over the world index.

-- A stored state as the Ledger's logic reads it, M4's keys defaulted, so an M2 or M3 state reads as prestige rank 0
-- with no Catch Milestone, Legend or record.
local function m4State(state)
	return {
		xp = tonumber(state.xp) or 0,
		prestige = tonumber(state.prestige) or 0,
		catches = tonumber(state.catches) or 0,
		milestones = tableOr(state.milestones),
		species = tableOr(state.species),
		items = tableOr(state.items),
		uncharted = tableOr(state.uncharted),
		zones = tableOr(state.zones),
	}
end

-- A list of title keys as "2 (title:level1, legend:19803)", in the order given, or "none".
local function keysText(keys)
	return #keys > 0 and #keys .. " (" .. table.concat(keys, ", ") .. ")" or "none"
end

-- The Catch Milestones reached (LED-R42), each with the time it was reached, and the lifetime Catches.
local function printMilestones(made)
	local reached = listed(made.milestones, function(n, time)
		return ("%s at %s"):format(n, utc(tonumber(time) or 0))
	end)
	print(("Catch Milestones: %s, %s"):format(reached, count(made.catches, "lifetime Catch", "lifetime Catches")))
end

-- The Legend items caught (LED-R63), classed by the Ledger's own ClassifyCatch, each with its first Catch.
local function printLegends(ledger, made, getItem)
	if not getItem then
		print("Legends caught: can't be told from the other items without the world (see world: above)")
		return
	end
	local legends = {}
	for itemID, first in pairs(made.items) do
		if ledger.ClassifyCatch(itemID, getItem(itemID)) == "legend" then
			legends[itemID] = tableOr(first)
		end
	end
	print("Legends caught: " .. listed(legends, function(itemID, first)
		return ("%s ×%s, first at %s by character %s in zone %s"):format(
			itemID,
			tostring(first.n),
			utc(tonumber(first.time) or 0),
			tostring(first.char),
			tostring(first.zone)
		)
	end))
end

-- How many Species and Legends hold a record (LED-R80), then each --item ID's record: a Species' from `species`,
-- else an item's (a Legend's) from `items`. Band names are Core's (LOG-R67).
local function printRecords(ledger, made, getItem, ids)
	local species, sized, legends = 0, 0, 0
	for _, entry in pairs(made.species) do
		species = species + 1
		sized = sized + (type(tableOr(entry).record) == "table" and 1 or 0)
	end
	for _, entry in pairs(made.items) do
		legends = legends + (type(tableOr(entry).record) == "table" and 1 or 0)
	end
	print(("records: %d of %s, %s"):format(sized, count(species, "Species", "Species"), count(legends, "Legend")))
	local bands = loadCoreRules().SIZE_BANDS
	for _, id in ipairs(ids) do
		local entry, kind = made.species[id], "Species"
		if not entry and made.items[id] then
			entry = made.items[id]
			kind = getItem and ledger.ClassifyCatch(id, getItem(id)) == "legend" and "Legend" or "item"
		end
		local record = tableOr(entry).record
		if not entry then
			print(("record of %d: not in the state (no Species or item %d caught)"):format(id, id))
		elseif type(record) ~= "table" then
			print(("record of %d (%s): none (no sized Catch yet)"):format(id, kind))
		else
			local band = bands[record.band]
			print(
				("record of %d (%s): %s mm, band %s%s, Catch %s, since %s"):format(
					id,
					kind,
					tostring(record.length),
					tostring(record.band),
					band and " " .. band.name or "",
					tostring(record.catchId),
					tostring(entry.since)
				)
			)
		end
	end
end

-- The earned titles (LED-R75, LED-R76) and the active title (LED-R77), from the Ledger's own TitleKeys and
-- ActiveTitle. Without a state or a world they read the celebrated titles alone, as the Ledger does before a build.
local function printTitles(ledger, view)
	local only = view.state and "" or ", the celebrated ones only (no state or no world to compute from)"
	print("titles earned: " .. keysText(ledger.TitleKeys(view)) .. only)
	local key, stored = ledger.ActiveTitle(view), view.activeTitle
	if stored == nil then
		print("active title: automatic, so " .. tostring(key or "none"))
	elseif stored == key then
		print("active title: " .. tostring(stored) .. " (profile.activeTitle)")
	else
		local text = "active title: %s in profile.activeTitle isn't earned, so automatic: %s"
		print(text:format(tostring(stored), tostring(key or "none")))
	end
end

-- The celebrated set's M4 keys (LED-R90): the highest level per climb, the prestige rank, the Catch Milestones, the
-- title keys (in LED-R75's order) and the Legend items among its items.
local function printCelebratedM4(ledger, celebrated, getItem)
	local levels = tableOr(celebrated.levels)
	local climbs = {}
	for i, rank in ipairs(sortedKeys(levels)) do
		climbs[i] = ("prestige rank %s level %s"):format(rank, tostring(levels[rank]))
	end
	print("celebrated levels: " .. (#climbs > 0 and table.concat(climbs, ", ") or "none"))
	print("celebrated prestige: " .. tostring(celebrated.prestige or "none"))
	print("celebrated Catch Milestones: " .. listed(tableOr(celebrated.milestones)))
	print("celebrated titles: " .. keysText(ledger.TitleKeys({ celebrated = celebrated })))
	if not getItem then
		print("celebrated Legend items: can't be told from the other items without the world (see world: above)")
		return
	end
	local legends = {}
	for itemID in pairs(tableOr(celebrated.items)) do
		if ledger.ClassifyCatch(itemID, getItem(itemID)) == "legend" then
			legends[itemID] = true
		end
	end
	print("celebrated Legend items: " .. listed(legends))
end

-- Prints the Ledger M4 section (ledger.md › Data, #173): from the state (`state`, nil when none is stored) the climb
-- (LED-R30, LED-R35), the Catch Milestones (LED-R42), the Legends (LED-R63) and the records (LED-R80); the earned
-- and active titles (LED-R75–R77); and the celebrated set's M4 keys (LED-R90). `context` holds the Ledger section's
-- world index and GetItem (nil when it couldn't be built) and the --item IDs. PagleLedgerDB has one shared profile,
-- AceDB's "Default", which holds activeTitle.
local function printLedgerM4(ledger, db, state, context)
	print("== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles")
	local celebrated = tableOr(tableOr(db.global).celebrated)
	local made = state and m4State(state)
	if made then
		print(
			("climb: prestige rank %d, %d XP, computed level %d, peak level %d"):format(
				made.prestige,
				made.xp,
				ledger.Level(made),
				ledger.PeakLevel(made)
			)
		)
		printMilestones(made)
		printLegends(ledger, made, context.getItem)
		printRecords(ledger, made, context.getItem, context.items)
	else
		print("state: none stored, so the titles below are the celebrated ones")
	end
	printTitles(ledger, {
		world = context.world,
		state = context.world and made or nil,
		celebrated = celebrated,
		getItem = context.getItem,
		activeTitle = tableOr(tableOr(db.profiles).Default).activeTitle,
	})
	printCelebratedM4(ledger, celebrated, context.getItem)
end

-- Prints the Ledger section from SavedVariables/Pagle_Ledger.lua (ledger.md › Data): the projection Core stores
-- (LOG-R70), checked against PagleLog (LOG-R72) and the Ledger's rules version (LED-R2), the state with what the
-- Ledger's own logic/ computes from it over the world index, and the celebrated set (LED-R90). `catalogue` is the
-- --catalogue path, or nil for the repo's; `items` the --item IDs. The Ledger M4 section follows it.
local function printLedger(account, log, catalogue, items)
	local path = account .. "/SavedVariables/Pagle_Ledger.lua"
	local saved, err = loadSavedVariables(path)
	if not saved then
		print("== Ledger: can't read " .. path .. ": " .. err)
		return
	end
	local db = saved.PagleLedgerDB
	if type(db) ~= "table" then
		print("== Ledger: Pagle_Ledger.lua holds no PagleLedgerDB")
		return
	end
	print("== Ledger (PagleLedgerDB)")
	local global = tableOr(db.global)
	local stored = global.projection
	local ledger, state, world, getItem = loadLedgerLogic(), nil, nil, nil
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print("projection: none stored (no build has finished, LOG-R72)")
	else
		printStored(stored, log)
		-- The Ledger's own rules version, from its logic/ with Core's size rules (LED-R2, LOG-R68), as
		-- adapter/Ledger.lua passes Pagle.SIZE_RULES_VERSION.
		local rulesVersion = ledger.RulesVersion(loadCoreRules().SIZE_RULES_VERSION)
		if stored.rulesVersion == rulesVersion then
			print(("rulesVersion: the Ledger's, %d (LED-R2)"):format(rulesVersion))
		else
			print(
				("rulesVersion: %s DIFFERS from the Ledger's %d, so Core rebuilds it at login (LED-R2, LOG-R72)"):format(
					tostring(stored.rulesVersion),
					rulesVersion
				)
			)
		end
		world, getItem = loadWorld(ledger, catalogue, stored)
		state = stored.projection
		printLedgerState(ledger, state, world, getItem, tableOr(global.celebrated))
	end
	printCelebrated(tableOr(global.celebrated))
	printLedgerM4(ledger, db, state, { world = world, getItem = getItem, items = items })
end

-- PagleDB.global from Pagle.lua's globals, or nil and why there's none.
local function pagleGlobal(pagle)
	if not pagle.saved then
		return nil, "can't read Pagle.lua: " .. pagle.err
	end
	local db = pagle.saved.PagleDB
	if type(db) ~= "table" then
		return nil, "Pagle.lua holds no PagleDB"
	end
	return tableOr(db.global)
end

-- The wallet projection's lines (#173): its bookkeeping, checked against PagleLog (LOG-R72) and Core's wallet rules
-- version (wallet-and-shop.md › Data), then its state, the Coins spent and the goods purchased (SHOP-R11). One line
-- while none is stored.
local function printWalletProjection(stored, log, rulesVersion)
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print("wallet projection: none stored (no build has finished, LOG-R72)")
		return
	end
	printStored(stored, log)
	if stored.rulesVersion == rulesVersion then
		print(("rulesVersion: Core's wallet rules, %d"):format(rulesVersion))
	else
		local text = "rulesVersion: %s DIFFERS from Core's wallet rules %d, so Core rebuilds it at login (LOG-R72)"
		print(text:format(tostring(stored.rulesVersion), rulesVersion))
	end
	print("spent: " .. tostring(stored.projection.spent))
	print("purchased: " .. listed(tableOr(stored.projection.purchased)))
end

-- Prints the Wallet section (wallet-and-shop.md › Data): each Module's last reported total (SHOP-R3) and the balance,
-- Σ earned − spent, 0 and held while that is negative (SHOP-R12), from Core's own logic/Wallet.lua; `spent` is the
-- wallet projection's (SHOP-R11), which the section prints last.
local function printWallet(pagle, log)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Wallet: " .. why)
		return
	end
	local earned = tableOr(tableOr(global.coins).earned)
	local stored = tableOr(global.projections).wallet
	local state = type(stored) == "table" and type(stored.projection) == "table" and stored.projection or {}
	local spent = tonumber(state.spent) or 0
	local sum, names = 0, sortedKeys(earned)
	for _, name in ipairs(names) do
		sum = sum + (tonumber(earned[name]) or 0)
	end
	-- The balance and held from Core's own wallet (logic/Wallet.lua).
	local core = loadCoreRules()
	local wallet = core.NewWallet(function() end)
	wallet:Open(earned)
	wallet:SetSpent(spent)
	local balance = wallet:Get()
	local heading = "== Wallet (PagleDB.global.coins.earned): balance " .. balance.balance
	if balance.held then
		heading = heading .. (", held (%d earned − %d spent = %d, SHOP-R12)"):format(sum, spent, sum - spent)
	elseif spent > 0 then
		heading = heading .. (" (%d earned − %d spent)"):format(sum, spent)
	end
	-- AceDB leaves the default, an empty earned table, out of the file.
	print(heading .. (#names == 0 and ", no Module has reported Coins" or ""))
	for _, name in ipairs(names) do
		print(name .. ": " .. tostring(earned[name]))
	end
	printWalletProjection(stored, log, core.WALLET_RULES_VERSION)
end

-- Prints the Looks section (wallet-and-shop.md › Data, catch-log.md › Data, #173): each slot's stored pick from
-- PagleDB.profile.appearance, or its default (SHOP-R32), for every slot a cached good or a stored pick names; the
-- goods cache's size and its earned goods cached as earned (SHOP-R26); and profile.lengthUnit (LOG-R69). PagleDB
-- has one shared profile, AceDB's "Default". AceDB leaves an empty appearance, goods or a nil unit out of the file.
local function printLooks(pagle)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Looks: " .. why)
		return
	end
	print("== Looks (PagleDB.profile.appearance, PagleDB.global.goods)")
	local profile = tableOr(tableOr(pagle.saved.PagleDB.profiles).Default)
	local appearance, goods = tableOr(profile.appearance), tableOr(global.goods)
	local slots, defaults, earned, cachedEarned = {}, {}, {}, {}
	for goodID, good in pairs(goods) do
		good = tableOr(good)
		if good.slot then
			slots[good.slot] = true
			defaults[good.slot] = good.default and goodID or defaults[good.slot]
		end
		if good.earned ~= nil then
			earned[goodID] = true
			cachedEarned[goodID] = good.earned == true or nil
		end
	end
	for slot in pairs(appearance) do
		slots[slot] = true
	end
	local ids = sortedKeys(slots)
	if #ids == 0 then
		print("slots: none cached or stored, so every look is its slot's default")
	end
	for _, slot in ipairs(ids) do
		local default = defaults[slot] and " (" .. defaults[slot] .. ")" or ""
		print(slot .. ": " .. (appearance[slot] and tostring(appearance[slot]) or "default" .. default))
	end
	print("goods cached: " .. #sortedKeys(goods))
	local earnedCount = #sortedKeys(earned)
	local earnedText = earnedCount > 0 and earnedCount .. ", cached as earned: " .. listed(cachedEarned) or "none"
	print("earned goods: " .. earnedText)
	print("length unit: " .. tostring(profile.lengthUnit or "region default"))
end

-- The titles of a card's moments, one line per Module group (ANN-R53), each indented by `indent`.
local function printMoments(groups, indent)
	for _, group in ipairs(groups) do
		local titles = {}
		for i, moment in ipairs(tableOr(group.moments)) do
			titles[i] = tostring(tableOr(moment).title)
		end
		print(("%s%s moments: %s"):format(indent, tostring(group.title), table.concat(titles, ", ")))
	end
end

-- The open summary's lines (ANN-R51): by Module order, then each Module's by key.
local function printSummaryLines(lines, indent)
	local modules = sortedKeys(lines)
	table.sort(modules, function(a, b)
		local orderA, orderB = tonumber(tableOr(lines[a]).order) or 0, tonumber(tableOr(lines[b]).order) or 0
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a < b
	end)
	for _, module in ipairs(modules) do
		local texts = tableOr(tableOr(lines[module]).lines)
		for _, key in ipairs(sortedKeys(texts)) do
			print(indent .. "line: " .. tostring(texts[key]))
		end
	end
end

-- Prints the Cards section (announcements.md › Data): the Write-up sections waiting (ANN-R61), the cards waiting
-- (ANN-R53, ANN-R54), and the open Session's summary and the pending moments (ANN-R50, ANN-R52). AceDB leaves out
-- each of them while it's empty.
local function printCards(pagle)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Cards: " .. why)
		return
	end
	print("== Cards (PagleDB.global)")
	local writeUp = tableOr(global.writeUp)
	print("writeUp: " .. (#writeUp > 0 and count(#writeUp, "section") or "none"))
	for _, section in ipairs(writeUp) do
		print(("  %s: %s"):format(tostring(section.title or section.module), tostring(section.heading)))
		for _, line in ipairs(tableOr(section.lines)) do
			print("    " .. tostring(line))
		end
	end
	local cards = tableOr(global.cards)
	print("cards: " .. (#cards > 0 and #cards or "none"))
	for i, card in ipairs(cards) do
		local title = card.title or (card.whileAway and "Your last session" or "Session summary")
		local numbers = tableOr(card.numbers)
		print(
			("  %d. %s: %s, %s, %s got away, %s s, %s"):format(
				i,
				tostring(title),
				count(tonumber(numbers.casts) or 0, "Cast"),
				count(tonumber(numbers.catches) or 0, "Catch", "Catches"),
				tostring(numbers.gotAway or 0),
				tostring(numbers.seconds or 0),
				count(tonumber(card.coins) or 0, "Coin")
			)
		)
		for _, module in ipairs(tableOr(card.lines)) do
			for _, line in ipairs(tableOr(module.lines)) do
				print("    line: " .. tostring(line))
			end
		end
		printMoments(tableOr(card.moments), "    ")
	end
	local summary = tableOr(global.summary)
	print("summary: " .. count(#tableOr(summary.moments), "moment"))
	printSummaryLines(tableOr(summary.lines), "  ")
	print("pending: " .. count(#tableOr(global.pending), "moment"))
end

-- The reporter key of a logId (REP-R36), with Core's own function: logic/FieldReportText.lua, called with
-- ("Pagle", ns) as the client calls it. It is plain Lua 5.1 (CORE-R7) and needs nothing else of Core's.
local function reporterKey(logId)
	local ns = {}
	local chunk = assert(loadfile(ROOT .. "/addons/Pagle/logic/FieldReportText.lua"))
	setfenv(chunk, setmetatable({}, { __index = _G }))
	chunk("Pagle", ns)
	return ns.ReporterKey(logId)
end

-- Prints the Field report section (field-report.md › Data): the projection Core stores in
-- PagleDB.global.projections.fieldReport (REP-R25), checked against PagleLog (LOG-R72), its stored I and K row
-- count (REP-R26), and the reporter key of PagleLog.logId (REP-R36). One line while no projection is stored.
local function printFieldReport(pagle, log)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Field report: " .. why)
		return
	end
	local heading = "== Field report (PagleDB.global.projections.fieldReport): reporter key "
		.. (log and type(log.logId) == "string" and reporterKey(log.logId) or "none (no PagleLog logId)")
	local stored = tableOr(global.projections).fieldReport
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print(heading .. ", projection: none stored (no build has finished, LOG-R72)")
		return
	end
	print(heading)
	printStored(stored, log)
	print("count: " .. tostring(stored.projection.count or 0) .. " I and K rows stored")
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
	local pagle = { path = options.account .. "/SavedVariables/Pagle.lua" }
	pagle.saved, pagle.err = loadSavedVariables(pagle.path)
	local checks = printCatchLog(pagle, options.expectCasts, options.since)
	printLedger(options.account, pagleLog(pagle.saved), options.catalogue, options.items)
	printWallet(pagle, pagleLog(pagle.saved))
	printLooks(pagle)
	printCards(pagle)
	printFieldReport(pagle, pagleLog(pagle.saved))
	printCVars(options.account, options.character, options.cvars)
	printAddons(options.account, options.character, options.addons)
	-- Last, so the verdict is the output's last word.
	if options.expectCasts and not printChecks(checks) then
		return 1
	end
	return 0
end

os.exit(main(arg))
