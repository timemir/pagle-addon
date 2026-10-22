-- Reads what the WoW client wrote under one WTF account folder, so an agent can check in-game results without the
-- dev reading files (docs/agents/in-game-verification.md). It prints:
--   - the latest !BugGrabber session's Lua errors, with their stacks;
--   - the Catch log, decoded with Core's own codec (addons/Pagle/logic/CatchLog.lua): the logId, the entries by
--     tag, the C1 Casts by outcome, per character and per zone areaID, those in zone areaID 0, their time span, the
--     realm's UTC offset from the latest Cast's realm minute (LOG-R49), the B1 and S1 entries, each P1 (Prestige,
--     with its Activity XP) and U1 (purchase) entry, and PagleDB.global.decodeErrors (0 when AceDB left that default
--     out of the file);
--   - the Ledger (PagleLedgerDB in Pagle_Ledger.lua): the projection Core stores and whether its logId, lastSeq and
--     rulesVersion are current, its state (items, the Uncharted list, zone ranks) with what the Ledger's own logic/
--     computes from it over the world index (the level, charted zones, shown ranks, Ledger completion), and the
--     celebrated set; then, in a Ledger M4 section, the climb with Prestige, the Catch Milestones, the Legends, the
--     Simulated Size records, the earned and active titles, the celebrated set's M4 keys, and the log's sized Catches
--     by band and per Species (#267);
--   - Hunts (PagleHuntsDB in Pagle_Hunts.lua): the projection Core stores and whether its logId, lastSeq,
--     rulesVersion and fingerprint are current, its state (Casts, Coins, each Hunt's progress and tiers, the earned
--     set titles) with the Session summary line Hunts' own logic/ computes from it over the Hunt list, the
--     celebrated set, the pins and the profile settings; with --hunt, one Hunt in full;
--   - Stats (PagleStatsDB in Pagle_Stats.lua): the projection Core stores and whether its logId, lastSeq,
--     rulesVersion and fingerprint are current, its totals, places, scopes, hits, skill margins and characters, its
--     last Sessions checked against the log's Session IDs, the live tracker setting, the watches with their readings
--     and the book's position; with --stats-item and --area, one reading in full, from Stats' own logic/;
--   - the Tackle Board: its Module records in PagleLog (A1, by kind, the last 10 decoded with its own codec), and from
--     PagleTackleBoardDB in Pagle_TackleBoard.lua the projection Core stores and whether its logId, lastSeq,
--     rulesVersion and fingerprint are current, its state (started, the days, today, owed, the pins and overflow strip
--     with each goal's text and progress, the completed goals, tally, Coins, flies, titles and Campfire, from its own
--     logic/), the celebrated set checked against the completed goals and titles, and the tracker settings;
--   - the wallet: each Module's reported Coins (PagleDB.global.coins.earned), the balance (held while negative) and
--     the wallet projection (PagleDB.global.projections.wallet): spent and purchased;
--   - Activity XP: each Module's reported total (PagleDB.global.activityXP.earned) and their sum, and whether these
--     totals and the Coins totals belong to PagleLog's logId;
--   - the looks: each slot's equipped good (PagleDB.profile.appearance), the goods cache and the length unit;
--   - the tracker dock's saved place (PagleDB.profile.dock.point);
--   - the cards: the Write-up waiting, the Session summary cards, the open summary and the pending moments;
--   - the onboarding state (PagleDB.global.onboarding): the Letter, the guide's step, the Margin notes and First looks
--     seen, the First evening list and the characters, with PagleDB.global.schemaVersion;
--   - the Field report projection (PagleDB.global.projections.fieldReport), its row count and the reporter key;
--   - the probe `/pagle dev probe` saved (PagleDB.global.probe, #261): each launch re-verification check's facts and
--     an ok or FAIL line, judged by Core's own logic/Probe.lua;
--   - what launch re-verification checks 2, 4-7 and 10 read (#262): PagleLog's entry count and Pagle.lua's size, the
--     load timings (PagleDB.global.probe.timings), the night Casts and the Casts with no realm minute, the
--     diagnostics buffer's hovered texts (as the P rows group them) and unresolved texts, and the Casts per zone and
--     subzone areaID with zone 0, alias sources and areas with no catch data flagged;
--   - named CVars from Config.wtf and the account's and the character's config-cache.wtf;
--   - named addons' enable state from the character's AddOns.txt.
--
--   lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm folder>/<Name-Surname>]
--       [--cvar <name>]... [--addon <name>]... [--catalogue <Catalogue.lua>] [--item <id>]...
--       [--huntlist <HuntList.lua>] [--hunt <id>]... [--stats-item <id> --area <areaID>] [--skill N] [--now T]
--       [--expect-casts N] [--since T]
--
-- --cvar defaults to SoftTargetInteract and --addon to Pagle, Pagle_Ledger, Pagle_QoL, Pagle_Hunts, Pagle_Stats and
-- Pagle_TackleBoard; naming one replaces its defaults.
-- The character's CVars and addons need --character, e.g. --character 70/Ada-Brook.
-- --catalogue builds the Ledger's world from another Catalogue.lua than the repo's addons/Pagle/data/Catalogue.lua,
-- such as the installed addon's; Hunts', Stats' and the Tackle Board's fingerprint checks read its content fingerprint
-- too, Stats' readings its lines and windows, and the Tackle Board its goals' need and stranded ones.
-- --item <id> prints the Simulated Size record (LED-R80) the Ledger keeps for that Species or Legend item ID.
-- --huntlist reads the Hunt list from another HuntList.lua than the repo's addons/Pagle_Hunts/data/HuntList.lua, such
-- as a local-only build's. --hunt <id> prints that Hunt's full progress. --now T computes what depends on the time
-- (current and retired Hunts, the summary line, the pins Hunts drops, how long ago a Dry spell's last Catch was) at
-- server time T instead of the reader's clock, and the Tackle Board's today at T instead of Pagle_TackleBoard.lua's
-- write time.
-- --stats-item <id> --area <areaID> prints Stats' reading of that item in that place (STA-R40–R54): its side, scope,
-- Your odds and Dry spell. --skill N is the live effective skill (rank + modifier) it and the watches are read at;
-- without it, each place's side with the most Casts (STA-R41).
-- --expect-casts N checks the M1 exit check's steps 3 and 4 (#75): N C1 Casts, each there once, no zone areaID 0,
-- a B1 and an S1 entry, decodeErrors 0, every entry decodes, and at least one Cast got away (`g`). --since T
-- counts only the Casts at server time T (Unix seconds) or later; B1 and S1 are still looked for in the whole log.
--
-- SavedVariables files are loaded as data: each runs in an empty environment, so it can only assign values, and
-- precompiled chunks are refused. Exits 2 on a usage error, 1 when an --expect-casts check fails, otherwise 0,
-- whatever the files hold.

local USAGE = "usage: lua scripts/read-wtf.lua <WTF/Account/<ACCT> folder> [--character <realm>/<Name-Surname>]"
	.. " [--cvar <name>]... [--addon <name>]... [--catalogue <Catalogue.lua>] [--item <id>]..."
	.. " [--huntlist <HuntList.lua>] [--hunt <id>]... [--stats-item <id> --area <areaID>] [--skill N] [--now T]"
	.. " [--expect-casts N] [--since T]\n"

-- The repo root, from this script's path: Core's and the Modules' logic/ and the catalogue are read from addons/.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The helpers this script shares with scripts/make-test-log.lua, in this script's environment.
local wtf = setfenv(assert(loadfile(ROOT .. "/scripts/lib/wtf.lua")), getfenv(1))(ROOT)
local count, readLines, loadSavedVariables = wtf.count, wtf.readLines, wtf.readSavedVariables

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = { cvars = {}, addons = {}, items = {}, hunts = {} }
	local lists = { ["--cvar"] = options.cvars, ["--addon"] = options.addons, ["--hunt"] = options.hunts }
	local numbers = { ["--expect-casts"] = "expectCasts", ["--since"] = "since", ["--now"] = "now" }
	numbers["--stats-item"], numbers["--area"], numbers["--skill"] = "statsItem", "area", "skill"
	local i = 1
	while args[i] do
		local word, value = args[i], args[i + 1]
		if word == "--character" or word == "--catalogue" or word == "--huntlist" or lists[word] then
			if not value then
				return nil, word .. " needs a value"
			end
			if word == "--character" then
				options.character = value:gsub("[/\\]+$", "")
			elseif word == "--catalogue" or word == "--huntlist" then
				options[word == "--catalogue" and "catalogue" or "huntList"] = value
			else
				local list = lists[word]
				list[#list + 1] = value
			end
			i = i + 2
		elseif numbers[word] or word == "--item" then
			if not value or not value:match("^%d+$") then
				return nil, word .. " needs a whole number"
			end
			if word == "--item" then
				options.items[#options.items + 1] = tonumber(value)
			else
				options[numbers[word]] = tonumber(value)
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
	if (options.statsItem == nil) ~= (options.area == nil) then
		return nil, "--stats-item and --area go together"
	end
	if #options.cvars == 0 then
		options.cvars = { "SoftTargetInteract" }
	end
	if #options.addons == 0 then
		options.addons = { "Pagle", "Pagle_Ledger", "Pagle_QoL", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard" }
	end
	return options
end

local function utc(time)
	return os.date("!%Y-%m-%d %H:%M:%S UTC", time)
end

-- A UTC offset in minutes as "UTC+02:00" or "UTC-07:30".
local function utcOffset(minutes)
	local size = math.abs(minutes)
	return ("UTC%s%02d:%02d"):format(minutes < 0 and "-" or "+", math.floor(size / 60), size % 60)
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

-- Core's namespace with the logic/ files the reader uses: the Catch log codec, the Field report's P rows and the
-- reporter key (REP-R22, REP-R36).
local function loadCoreLogic()
	return wtf.loadCore({
		"logic/Conditions.lua",
		"logic/Sessions.lua",
		"logic/CatchLog.lua",
		"logic/FieldReport.lua",
		"logic/FieldReportText.lua",
	})
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
-- B1 and S1 entries, repeated entry IDs and the entries the codec can't decode. `breaks` is the file's
-- PagleDB.global.sessionBreaks, so the Casts carry the Session IDs Core gives them (LOG-R99).
local function readLog(ns, log, since, breaks)
	local tags = {}
	for _, entry in ipairs(log.entries) do
		local tag = type(entry) == "string" and entry:match("^(%u%d+)|") or "(no tag)"
		tags[tag] = (tags[tag] or 0) + 1
	end
	-- The reader's own decodeErrors, so the file's count stays what Pagle counted in the game (LOG-R16).
	local global = { decodeErrors = 0, sessionBreaks = breaks }
	local catchLog = ns.OpenCatchLog(log, global, 0)
	local facts = { tags = tags, casts = {}, allCasts = 0, builds = 0, skills = 0, repeated = {} }
	-- sessions: each Session ID the Casts carry (LOG-R98), with its Casts and its first Cast, for Stats' cross-check.
	facts.prestiges, facts.purchases, facts.sessions = {}, {}, {}
	local ids = {}
	for record in catchLog:Iterate() do
		if ids[record.id] then
			facts.repeated[#facts.repeated + 1] = record.id
		end
		ids[record.id] = true
		if record.kind == "cast" then
			facts.allCasts = facts.allCasts + 1
			facts.lastCast = record -- the latest Cast, in log order (LOG-R15), whatever `since`
			if record.session then
				local session = facts.sessions[record.session] or { casts = 0, first = record }
				session.casts = session.casts + 1
				facts.sessions[record.session] = session
			end
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
	-- The realm's UTC offset (LOG-R49), from the latest Cast counted that read the realm minute; nil with none.
	local latest
	for _, cast in ipairs(facts.casts) do
		if cast.conditions.minute and (not latest or cast.time >= latest.time) then
			latest = cast
		end
	end
	facts.realmOffset = latest and ns.RealmUtcOffset(latest.time, latest.conditions.minute)
	return facts
end

-- A character as "1 Ada Brook (Player-4618-0A1B2C3D)": its index, name and GUID.
local function characterName(log, char)
	local guid = (log.characters[char] or {}).guid
	return ("%d %s (%s)"):format(char, wtf.characterName(log, char), tostring(guid))
end

local NO_REALM_MINUTE = "unknown (no Cast read the realm minute)"

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
	local offset = facts.realmOffset
	print("realm clock: " .. (offset and utcOffset(offset) .. " (from the latest Cast)" or NO_REALM_MINUTE))
end

-- The Prestige (P1, LOG-R38) and purchase (U1, LOG-R39) entries: a count each, then one line per entry, P1 with
-- its rank and Activity XP snapshot (AXP-R5, 0 for a pre-1.0 P1 without one) and U1 with its good and price, each
-- with its character and time.
local function printPrestigesAndPurchases(log, facts)
	for _, kind in ipairs({ { "P1", facts.prestiges }, { "U1", facts.purchases } }) do
		local tag, records = kind[1], kind[2]
		print(tag .. ": " .. (#records > 0 and count(#records, "entry", "entries") or "none"))
		for _, record in ipairs(records) do
			local what = tag == "P1" and ("rank %d, %d Activity XP"):format(record.rank, record.activityXP)
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
	local ns = loadCoreLogic()
	if log.format ~= ns.LOG_FORMAT then
		-- Opening it would set it aside for a new log (LOG-R18), so it isn't decoded at all.
		local format = ("format %s, the codec reads format %d"):format(tostring(log.format), ns.LOG_FORMAT)
		print("PagleLog is " .. format .. ": Core starts a new log at login")
		return { { ok = false, line = "PagleLog is " .. format } }
	end
	local facts = readLog(ns, log, since, global.sessionBreaks)
	printLog(log, facts, since)
	return expectCasts and exitChecks(facts, decodeErrors, expectCasts) or {}, facts
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

-- The Ledger's world index (LED-R10), built by its own logic/World.lua over the catalogue at `path` (the repo's
-- generated one unless --catalogue names another), as the Ledger builds it at OnInitialize. Prints which catalogue
-- it is and whether its fingerprint is the one the projection was built against (DATA-R70). Returns the world and
-- GetItem, or nothing when the catalogue can't be loaded.
local function loadWorld(ledger, path, stored)
	local label = path or "the repo's addons/Pagle/data/Catalogue.lua"
	local catalogue, err = wtf.loadCatalogue(path)
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

-- Prints a set of items keyed by item ID as "<what> curio items: …" and "<what> trophy items: …", by the class the
-- Ledger's own ClassifyCatch gives each now (LED-R5), and "<what> other items: …" when any has another class, such as
-- an item no longer in the catalogue. Without a catalogue they are listed together, unclassed. `describe` is
-- listed's.
local function printClassed(what, ledger, items, getItem, describe)
	if not getItem then
		print(what .. " items, not classed: " .. listed(items, describe))
		return
	end
	-- Legend items (LED-R63) are in the state's items too: the Ledger M4 section lists them.
	local byClass = { curio = {}, trophy = {}, legend = {}, other = {} }
	for itemID, value in pairs(items) do
		local class = ledger.ClassifyCatch(itemID, getItem(itemID))
		byClass[byClass[class] and class or "other"][itemID] = value
	end
	print(what .. " curio items: " .. listed(byClass.curio, describe))
	print(what .. " trophy items: " .. listed(byClass.trophy, describe))
	if next(byClass.other) then
		print(what .. " other items: " .. listed(byClass.other, describe))
	end
end

-- The state's trophy and curio items (LED-R60, LED-R64), each with its Catches, by class (printClassed).
local function printItems(ledger, items, getItem)
	printClassed("state", ledger, items, getItem, function(itemID, first)
		return itemID .. " ×" .. tostring(tableOr(first).n)
	end)
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

-- The celebrated set (LED-R90), its curio and trophy items by class (printClassed) when there's a catalogue.
local function printCelebrated(celebrated, ledger, getItem)
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
	printClassed("celebrated", ledger, tableOr(celebrated.items), getItem)
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
-- (logic/WalletProjection.lua). Nothing here hashes a Catch ID, so it reads the same without LuaBitOp.
local function loadCoreRules()
	return wtf.loadCore({ "locale/enUS.lua", "logic/Size.lua", "logic/Wallet.lua", "logic/WalletProjection.lua" })
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

-- The sizes part (#267): every Catch in PagleLog with a Simulated Size, sized by Core's own codec and logic/Size.lua
-- over the catalogue (LOG-R65–R67), by band beside LOG-R67's shares and per Species, so the bands can be checked on
-- a real log before the 1.0 freeze (ADR 0010).

-- Each band's share of Catches, from LOG-R67's cut points (0, 0.15, 0.70, 0.93, 0.995, 1).
local SIZE_SHARES = { 0.15, 0.55, 0.23, 0.065, 0.005 }

-- The central 95% range of a binomial count of `n` draws at probability `p`: the lowest count whose cumulative
-- probability passes 2.5% and the lowest that reaches 97.5%, each term summed in log space so none underflows.
local function binomialRange(n, p)
	local logPmf, logRatio = n * math.log(1 - p), math.log(p) - math.log(1 - p)
	local cdf, low = 0, nil
	for k = 0, n do
		cdf = cdf + math.exp(logPmf)
		low = low or (cdf > 0.025 and k or nil)
		if cdf >= 0.975 then
			return low, k
		end
		logPmf = logPmf + math.log((n - k) / (k + 1)) + logRatio
	end
	return low or n, n
end

-- Every Catch in `log` with a Simulated Size (LOG-R65), decoded by Core's codec with `getItem`: the Catches per
-- band, and per Species its Catches, shortest and longest length and typical length (DATA-R20).
local function tallySizes(core, log, getItem)
	local tally = { total = 0, bands = { 0, 0, 0, 0, 0 }, species = {} }
	for record in core.OpenCatchLog(log, { decodeErrors = 0 }, 0, getItem):Iterate() do
		for _, item in ipairs(record.kind == "cast" and record.items or {}) do
			local size, info = item.size, getItem(item.itemID)
			if size then
				tally.total = tally.total + 1
				tally.bands[size.band] = tally.bands[size.band] + 1
				local species = tally.species[info.species] or { n = 0, typical = info.typicalLength }
				species.n = species.n + 1
				species.legend = species.legend or info.legend
				species.shortest = math.min(species.shortest or size.length, size.length)
				species.longest = math.max(species.longest or size.length, size.length)
				tally.species[info.species] = species
			end
		end
	end
	return tally
end

-- Prints the sizes part: `log` is PagleLog (nil when there's none), `catalogue` the --catalogue path or nil.
local function printSizes(log, catalogue)
	local label = catalogue or "the repo's addons/Pagle/data/Catalogue.lua"
	if not log then
		print("sizes: no PagleLog to read")
		return
	end
	if not wtf.luaBitOp() then
		print(
			"sizes: no LuaBitOp to hash the Catch IDs with (LOG-R66): run scripts/setup.sh, then this through"
				.. " scripts/read-wtf.sh"
		)
		return
	end
	local items, err = wtf.loadCatalogue(catalogue)
	if not items then
		print(("sizes: can't load %s: %s"):format(label, tostring(err)))
		return
	end
	local core = wtf.loadCore({
		"locale/enUS.lua",
		"logic/Conditions.lua",
		"logic/Sessions.lua",
		"logic/Size.lua",
		"logic/Variety.lua",
		"logic/CatchLog.lua",
	})
	if log.format ~= core.LOG_FORMAT then
		print(("sizes: PagleLog is format %s, the codec reads format %d"):format(tostring(log.format), core.LOG_FORMAT))
		return
	end
	local tally = tallySizes(core, log, items.GetItem)
	local species = sortedKeys(tally.species)
	if tally.total == 0 then
		print(("sizes: no Catch has a Simulated Size (LOG-R65), from PagleLog over %s"):format(label))
		return
	end
	print(
		("sizes: %s with a Simulated Size, of %s (LOG-R65), from PagleLog over %s"):format(
			count(tally.total, "Catch", "Catches"),
			count(#species, "Species", "Species"),
			label
		)
	)
	print("sizes by band: Catches (their share; LOG-R67's share, the 95% range of the Catches at it)")
	for band, share in ipairs(SIZE_SHARES) do
		local n, low, high = tally.bands[band], binomialRange(tally.total, share)
		local outside = (n < low or n > high) and ", OUTSIDE its 95% range" or ""
		print(
			("  %d %s: %d (%.1f%%; %s%%, %d–%d)%s"):format(
				band,
				tostring(core.SIZE_BANDS[band].name),
				n,
				100 * n / tally.total,
				("%g"):format(100 * share),
				low,
				high,
				outside
			)
		)
	end
	print("sizes per Species: Catches, shortest–longest, typical length (DATA-R20)")
	for _, id in ipairs(species) do
		local entry = tally.species[id]
		print(
			("  %s%s: %s, %d–%d mm, typical %s mm"):format(
				tostring(id),
				entry.legend and " (Legend)" or "",
				count(entry.n, "Catch", "Catches"),
				entry.shortest,
				entry.longest,
				tostring(entry.typical)
			)
		)
	end
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
	printSizes(context.log, context.catalogue)
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
	local ledger, state, world, getItem = wtf.loadLedgerLogic(), nil, nil, nil
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
	printCelebrated(tableOr(global.celebrated), ledger, getItem)
	printLedgerM4(
		ledger,
		db,
		state,
		{ world = world, getItem = getItem, items = items, log = log, catalogue = catalogue }
	)
end

-- The Hunts section's lines (#199): what PagleHuntsDB holds (hunts.md › Data), with what Hunts' own logic/ computes
-- from it over the Hunt list (`HuntList.lua`, the repo's or --huntlist's) at the time read (--now, or the reader's
-- clock).

-- Hunts' namespace with its strings, its Hunt list and its logic: each locale/, data/ and logic/ file Pagle_Hunts.toc
-- lists, in TOC order, called with ("Pagle_Hunts", ns) as the client calls an addon's files (spec/Pagle_Hunts/
-- support.lua loads them the same way), with `huntListPath` (--huntlist) standing in for data/HuntList.lua. Their
-- CORE-R11 guard reads the Pagle global, so it's a table here; logic/ is plain Lua 5.1 (CORE-R7) and reads nothing of
-- Core's at load. Returns ns with `ns.hunts` (the Hunt list at runtime, which the logic reads at call time), or ns
-- and why the Hunt list can't be loaded.
local function loadHuntsLogic(huntListPath)
	local ns = {}
	local env = setmetatable({ Pagle = {} }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_Hunts/"
	local listErr
	for _, file in ipairs(wtf.tocEntries("Pagle_Hunts")) do
		if file == "data/HuntList.lua" then
			local _, err = wtf.loadInto(ns, env, huntListPath or dir .. file, "Pagle_Hunts")
			listErr = err
		elseif
			file:match("^locale/[^/]+%.lua$")
			or file:match("^data/[^/]+%.lua$")
			or file:match("^logic/[^/]+%.lua$")
		then
			assert(wtf.loadInto(ns, env, dir .. file, "Pagle_Hunts"))
		end
	end
	if not listErr and type(ns.huntList) ~= "table" then
		listErr = "it sets no Hunt list"
	end
	if listErr then
		return ns, listErr
	end
	ns.hunts = ns.NewHuntList(ns.huntList, ns.L)
	return ns
end

-- A realm date ({ year, month, day }, hunts.md › Projection state) as "2026-10-12".
local function dateText(date)
	date = tableOr(date)
	return ("%04d-%02d-%02d"):format(tonumber(date.year) or 0, tonumber(date.month) or 0, tonumber(date.day) or 0)
end

-- A Hunt's stored progress counters (hunts.md › Projection state) as "count 12, effort 80, sinceLast 3".
local function progressText(progress)
	return ("count %s, effort %s, sinceLast %s"):format(
		tostring(progress.count),
		tostring(progress.effort),
		tostring(progress.sinceLast)
	)
end

-- A Hunt's thresholds (HNT-R15) as "1 / 10 / 40".
local function tiersText(hunt)
	return table.concat(hunt.tiers, " / ")
end

-- Where a Hunt stands at `now` (HNT-R2, HNT-R3), from Hunts' own predicates: "current", "retired 2026-09-01" or
-- "not out until 2026-11-04". `long` gives the bare word.
local function huntStatus(hunts, hunt, now, long)
	if hunts.IsCurrent(hunt, now) then
		return "current"
	elseif hunts.IsRetired(hunt, now) then
		return long and "retired" or "retired " .. os.date("!%Y-%m-%d", hunt.retired)
	end
	return long and "not out yet" or "not out until " .. os.date("!%Y-%m-%d", hunt.since)
end

-- The projection Core stores for Hunts (LOG-R70), checked against PagleLog (LOG-R72), Hunts' rules version
-- (HNT-R136, HNT-R138) and the fingerprint Core would store now: the catalogue's plus the Hunt list's (DATA-R72).
-- Prints the Hunt list read, and returns it (nil when it can't be loaded).
local function printHuntsStored(hunts, listErr, stored, log, options)
	printStored(stored, log)
	local rulesVersion = hunts.HUNTS_RULES_VERSION
	if stored.rulesVersion == rulesVersion then
		print(("rulesVersion: Hunts', %d (HNT-R136)"):format(rulesVersion))
	else
		local text = "rulesVersion: %s DIFFERS from Hunts' %d, so Core rebuilds it at login (HNT-R138, LOG-R72)"
		print(text:format(tostring(stored.rulesVersion), rulesVersion))
	end
	local label = options.huntList or "the repo's addons/Pagle_Hunts/data/HuntList.lua"
	if listErr then
		print(("Hunt list: can't load %s: %s; nothing below is computed from it"):format(label, tostring(listErr)))
		print("fingerprint: can't be checked without the Hunt list")
		return nil
	end
	local list = hunts.hunts
	local sizes = count(#list:Hunts(), "Hunt") .. " in " .. count(#list:Sets(), "set")
	print(("Hunt list: %s, fingerprint %s, %s"):format(label, tostring(list:Fingerprint()), sizes))
	local catalogue, err = wtf.loadCatalogue(options.catalogue)
	if not catalogue then
		print("fingerprint: can't be checked: the catalogue can't load: " .. tostring(err))
		return list
	end
	-- What Hunts hands Core (its def's extraFingerprint), after the content fingerprint as Core stores it (LOG-R70).
	local expected = tostring(catalogue.CONTENT_FINGERPRINT) .. "+" .. tostring(hunts.HuntsExtraFingerprint(list))
	if stored.fingerprint == expected then
		print("fingerprint: the catalogue's plus the Hunt list's (DATA-R72)")
	else
		local text = "fingerprint: DIFFERS from the catalogue's plus the Hunt list's, %s, so Core rebuilds it at login"
		print(text:format(expected) .. " (DATA-R72, LOG-R72)")
	end
	return list
end

-- One Hunt's progress line and its reached tiers (hunts.md › Projection state, HNT-R15, HNT-R18), with where it
-- stands at `now` and its thresholds when it's in the Hunt list.
local function printHuntProgress(hunts, id, hunt, progress, now)
	local reached = tableOr(progress.reached)
	local stats = progressText(progress)
	if hunt then
		local tiers = ("tiers %d of %d (%s)"):format(#reached, #hunt.tiers, tiersText(hunt))
		print(("  %s: %s, %s, %s"):format(id, huntStatus(hunts, hunt, now), stats, tiers))
	elseif hunts.hunts then
		print(("  %s: not in the Hunt list, %s, %s"):format(id, stats, count(#reached, "tier") .. " reached"))
	else
		print(("  %s: %s, %s"):format(id, stats, count(#reached, "tier") .. " reached"))
	end
	for k, tier in ipairs(reached) do
		tier = tableOr(tier)
		print(
			("    tier %d %s: %s (realm date), zone %s, item %s"):format(
				k,
				hunts.Trim(k),
				dateText(tier.date),
				tostring(tier.zone),
				tostring(tier.itemID)
			)
		)
	end
end

-- The state's lines (hunts.md › Projection state): the Session summary line Hunts would set at `now` (HNT-R89), from
-- its own ns.HuntsSummaryLine and wording, the state's counts, each Hunt with progress in Hunt-list order (then any the list
-- doesn't have, by ID), and the earned set titles (HNT-R23).
local function printHuntsState(hunts, list, state, now, options)
	local progressOf, sets = tableOr(state.hunts), tableOr(state.sets)
	local ids, titles = sortedKeys(progressOf), sortedKeys(sets)
	if list then
		-- Hunts' own line and wording (logic/Moments.lua, locale/), numbers written plain.
		local line = hunts.HuntsSummaryLine({ hunts = progressOf, sets = sets }, now, tostring)
		print(
			("summary line: %s, at %s (%s) (HNT-R89)"):format(
				line,
				utc(now),
				options.now and "--now" or "the reader's clock"
			)
		)
	else
		print("summary line: can't be computed without the Hunt list")
	end
	print(
		("state: %s, %s, %d Hunts with progress, %s"):format(
			count(tonumber(state.casts) or 0, "Cast"),
			count(tonumber(state.coins) or 0, "Coin"),
			#ids,
			count(#titles, "title")
		)
	)
	local shown = {}
	for _, hunt in ipairs(list and list:Hunts() or {}) do
		if progressOf[hunt.id] then
			shown[hunt.id] = true
			printHuntProgress(hunts, hunt.id, hunt, tableOr(progressOf[hunt.id]), now)
		end
	end
	for _, id in ipairs(ids) do
		if not shown[id] then
			printHuntProgress(hunts, id, nil, tableOr(progressOf[id]), now)
		end
	end
	print("titles earned: " .. (#titles > 0 and #titles or "none"))
	for _, setID in ipairs(titles) do
		local title = tableOr(sets[setID])
		print(
			("  %s: %s, earned at %s, %s"):format(
				setID,
				dateText(title.date),
				utc(tonumber(title.earnedAt) or 0),
				title.fromRetirement and "from a retirement" or "from a Catch"
			)
		)
	end
end

-- The profile (hunts.md › PagleHuntsDB, one shared "Default" profile): the pins, with those Hunts drops at load
-- from its own StalePins (HNT-R81), and the four settings, each marked when AceDB left its default out of the file.
local function printHuntsProfile(hunts, list, profile, now)
	local pins = tableOr(profile.pins)
	local line = "pins: " .. listed(pins)
	local stale = list and next(pins) and hunts.StalePins(pins, list, now) or {}
	if #stale > 0 then
		line = line .. "; not current, so Hunts drops the pin at load (HNT-R81): " .. table.concat(stale, ", ")
	end
	print(line)
	local defaults = hunts.DB_DEFAULTS.profile
	local tracker = tableOr(profile.tracker)
	for _, setting in ipairs({
		{ "tracker.shown", tracker.shown, defaults.tracker.shown },
		{ "tracker.collapsed", tracker.collapsed, defaults.tracker.collapsed },
		{ "windowMoments", profile.windowMoments, defaults.windowMoments },
		{ "showCompleted", profile.showCompleted, defaults.showCompleted },
	}) do
		local name, value, default = setting[1], setting[2], setting[3]
		if value == nil then
			print(("%s: %s (not saved: the default)"):format(name, tostring(default)))
		else
			print(("%s: %s"):format(name, tostring(value)))
		end
	end
end

-- One Hunt in full (--hunt, HNT-R15–R18, HNT-R26): its definition (DATA-R93), where it stands at `now`, its pin and
-- celebrated tier (HNT-R81, HNT-R90), its progress, each reached tier's Catch, and the next threshold.
local function printHuntDetail(hunts, list, id, state, db, now)
	local hunt = list and list:Hunt(id)
	local progress = tableOr(state.hunts)[id]
	local heading = "== Hunt " .. id .. " (--hunt)"
	if not hunt and type(progress) ~= "table" then
		print(heading .. ": not in the Hunt list, and no progress stored")
		return
	end
	print(heading)
	local celebrated = tableOr(tableOr(tableOr(db.global).celebrated).tiers)[id]
	local pinned = tableOr(tableOr(tableOr(db.profiles).Default).pins)[id]
	if hunt then
		local target = hunt.species and "species " .. hunt.species or "class " .. tostring(hunt.class)
		local spec = hunt.window and "window " .. hunt.window
			or "conditions " .. table.concat(sortedKeys(tableOr(hunt.conditions)), ", ")
		local band = hunt.minBand and ", minBand " .. hunt.minBand or ""
		local retired = hunt.retired and ", retired " .. utc(hunt.retired) or ""
		print(
			("set %s, %s, %s%s, %s, tiers %s, since %s%s"):format(
				hunt.set,
				hunt.kind,
				target,
				band,
				spec,
				tiersText(hunt),
				utc(hunt.since),
				retired
			)
		)
		local where = huntStatus(hunts, hunt, now, true)
		local kept = celebrated and "celebrated up to tier " .. tostring(celebrated) or "nothing celebrated"
		print(("%s, %s, %s"):format(where, pinned and "pinned" or "not pinned", kept))
	else
		print("not in the Hunt list")
	end
	if type(progress) ~= "table" then
		print("progress: none stored (no effort Cast or qualifying Catch yet)")
		return
	end
	local done = hunts.HuntDone(progress) and "done" or "not done"
	local finished = hunt and (hunts.HuntFinished(progress, hunt) and "finished" or "not finished")
	print(
		("progress: %s, caught %s, %s%s"):format(
			progressText(progress),
			tostring(progress.caught),
			done,
			finished and ", " .. finished or ""
		)
	)
	local reached = tableOr(progress.reached)
	for k, tier in ipairs(reached) do
		tier = tableOr(tier)
		local threshold = hunt and tostring(hunt.tiers[k]) .. ", " or ""
		print(
			("tier %d (%s%s): Catch %s, item %s, zone %s, realm date %s, at %s"):format(
				k,
				threshold,
				hunts.Trim(k),
				tostring(tier.catchId),
				tostring(tier.itemID),
				tostring(tier.zone),
				dateText(tier.date),
				utc(tonumber(tier.time) or 0)
			)
		)
	end
	if hunt then
		local next = hunt.tiers[#reached + 1]
		if next then
			local togo = next - (tonumber(progress.count) or 0)
			print(("next: tier %d at %d, %d to go"):format(#reached + 1, next, togo))
		else
			print("next: every tier reached (finished)")
		end
	end
end

-- Prints the Hunts section from SavedVariables/Pagle_Hunts.lua (hunts.md › Data): the projection Core stores
-- (LOG-R70) with its checks, the state with what Hunts' own logic/ computes from it at `options.now` (or the
-- reader's clock), the celebrated set (HNT-R90) and the profile; then one section per --hunt.
local function printHunts(account, log, options)
	local path = account .. "/SavedVariables/Pagle_Hunts.lua"
	local saved, err = loadSavedVariables(path)
	if not saved then
		print("== Hunts: can't read " .. path .. ": " .. err)
		return
	end
	local db = saved.PagleHuntsDB
	if type(db) ~= "table" then
		print("== Hunts: Pagle_Hunts.lua holds no PagleHuntsDB")
		return
	end
	print("== Hunts (PagleHuntsDB)")
	local hunts, listErr = loadHuntsLogic(options.huntList)
	local now = options.now or os.time()
	local global = tableOr(db.global)
	local stored = global.projection
	local list, state
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print("projection: none stored (no build has finished, LOG-R72)")
		list = not listErr and hunts.hunts or nil
	else
		list = printHuntsStored(hunts, listErr, stored, log, options)
		state = stored.projection
		printHuntsState(hunts, list, state, now, options)
	end
	local celebrated = tableOr(global.celebrated)
	print("celebrated tiers: " .. listed(tableOr(celebrated.tiers), function(id, tier)
		return id .. " " .. tostring(tier)
	end))
	print("celebrated titles: " .. listed(tableOr(celebrated.sets)))
	printHuntsProfile(hunts, list, tableOr(tableOr(db.profiles).Default), now)
	for _, id in ipairs(options.hunts) do
		printHuntDetail(hunts, list, id, tableOr(state), db, now)
	end
end

-- The Stats section's lines (#219): what PagleStatsDB holds (stats.md › Data), with the readings Stats' own logic/
-- computes from its projection over the catalogue (the repo's or --catalogue's) at the live skill --skill gives.

-- A whole number with thousands separators, as the client's BreakUpLargeNumbers writes it: 1234567 reads "1,234,567".
local function thousands(n)
	local digits = ("%d"):format(n)
	local sign, rest = digits:match("^(-?)(%d+)$")
	return sign .. rest:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Stats' namespace with its strings and its logic: each locale/, data/ and logic/ file Pagle_Stats.toc lists, in TOC
-- order, called with ("Pagle_Stats", ns) as the client calls an addon's files (spec/Pagle_Stats/support.lua loads them
-- the same way over FakePagle). Their CORE-R11 guard reads the Pagle global, so it's a table here; logic/ is plain Lua
-- 5.1 (CORE-R7) and reads nothing of Core's at load. Its words (logic/Text.lua) get the reader's stand-ins for the
-- client's reads: no item or area names (so "Item {id}", "Area {id}"), the log's characters and the clock at `now`.
local function loadStatsLogic(log, now)
	local ns = {}
	local env = setmetatable({ Pagle = {} }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_Stats/"
	for _, line in ipairs(assert(readLines(dir .. "Pagle_Stats.toc"))) do
		local file = line:match("^%s*(.-)%s*$"):gsub("\\", "/")
		if file:match("^locale/[^/]+%.lua$") or file:match("^data/[^/]+%.lua$") or file:match("^logic/[^/]+%.lua$") then
			assert(wtf.loadInto(ns, env, dir .. file, "Pagle_Stats"))
		end
	end
	local none = function() end
	ns.WireText({
		BreakUpLargeNumbers = thousands,
		Date = os.date,
		ServerTime = function()
			return now
		end,
		ItemName = none,
		ItemIcon = none,
		AreaName = none,
		Characters = function()
			return log and log.characters or {}
		end,
		QualityName = none,
		QualityColor = none,
	})
	return ns
end

-- Stats' place tables (STA-R12–R17) over the catalogue at `path` (the repo's unless --catalogue names another), with
-- Core's MatchesConditions (logic/Conditions.lua), as the adapter passes `Pagle` itself. Returns the tables and the
-- catalogue's content fingerprint, or nil and why the catalogue can't be loaded.
local function statsPlaces(stats, core, path)
	local catalogue, err = wtf.loadCatalogue(path)
	if not catalogue then
		return nil, err
	end
	local lookups = { MatchesConditions = core.MatchesConditions }
	for name, value in pairs(catalogue) do
		lookups[name] = value
	end
	return stats.NewPlaceTables(lookups), catalogue.CONTENT_FINGERPRINT
end

-- The projection Core stores for Stats (LOG-R70), checked against PagleLog (LOG-R72), Stats' rules version (STA-R20:
-- 100 × STATS_RULES_VERSION + Core's SESSION_RULES_VERSION, logic/Sessions.lua) and the catalogue's content
-- fingerprint, Stats having no extra one. `context` holds the catalogue's label, its fingerprint or why it can't load.
local function printStatsStored(stats, core, stored, log, context)
	printStored(stored, log)
	local rulesVersion = stats.RulesVersion(core.SESSION_RULES_VERSION)
	if stored.rulesVersion == rulesVersion then
		print(("rulesVersion: Stats', %d (STA-R20)"):format(rulesVersion))
	else
		local text = "rulesVersion: %s DIFFERS from Stats' %d (100 × %d + Core's SESSION_RULES_VERSION %d), so Core"
			.. " rebuilds it at login (STA-R20, LOG-R72)"
		print(
			text:format(
				tostring(stored.rulesVersion),
				rulesVersion,
				stats.STATS_RULES_VERSION,
				core.SESSION_RULES_VERSION
			)
		)
	end
	if not context.places then
		print(("fingerprint: can't be checked: %s can't load: %s"):format(context.label, tostring(context.err)))
	elseif stored.fingerprint == context.fingerprint then
		print(("fingerprint: the catalogue's, %s (LOG-R70)"):format(context.label))
	else
		local text = "fingerprint: DIFFERS from the catalogue's %s, %s, so Core rebuilds it at login (LOG-R70, LOG-R72)"
		print(text:format(tostring(context.fingerprint), context.label))
	end
end

-- "126 Casts, 112 Catches, 14 got away" (STA-R22).
local function countsText(counts)
	return ("%s, %s, %d got away"):format(
		count(tonumber(counts.casts) or 0, "Cast"),
		count(tonumber(counts.catches) or 0, "Catch", "Catches"),
		tonumber(counts.gotAway) or 0
	)
end

-- The state's counts (stats.md › Projection state): totals (STA-R22), the places, scopes and hits (STA-R22–R24), the
-- skill margin buckets (STA-R26) and each character's counts with its last Skill Reading rank (STA-R27).
local function printStatsCounts(state, log)
	print("totals: " .. countsText(tableOr(state.totals)))
	local zones, subzones = 0, 0
	for area, place in pairs(tableOr(state.places)) do
		local zone = tableOr(place).zone == area
		zones, subzones = zones + (zone and 1 or 0), subzones + (zone and 0 or 1)
	end
	print(
		("places: %d (%s, %s), %s, %s"):format(
			zones + subzones,
			count(zones, "zone"),
			count(subzones, "subzone"),
			count(#sortedKeys(tableOr(state.scopes)), "scope"),
			count(#sortedKeys(tableOr(state.hits)), "hit")
		)
	)
	local margins, buckets = tableOr(state.margins), {}
	for i, bucket in ipairs({ "lo50", "lo1", "hi0", "hi25" }) do
		local margin = tableOr(margins[bucket])
		local gotAway = tonumber(margin.gotAway) or 0
		local away = gotAway > 0 and (" (%d got away)"):format(gotAway) or ""
		buckets[i] = ("%s %s%s"):format(bucket, count(tonumber(margin.casts) or 0, "Cast"), away)
	end
	print("margins: " .. table.concat(buckets, ", "))
	local chars, lastRank = tableOr(state.chars), tableOr(state.lastRank)
	local indices = sortedKeys(chars)
	print("characters: " .. #indices)
	for _, char in ipairs(indices) do
		local who = log and characterName(log, char) or tostring(char)
		local rank = lastRank[char] and ", last rank " .. tostring(lastRank[char]) or ""
		print(("  %s: %s%s"):format(who, countsText(tableOr(chars[char])), rank))
	end
end

-- How many Sessions the stored state shows (STA-R30).
local STATS_SESSIONS_SHOWN = 5

-- A Session's start and end in realm-local time, at the realm's UTC offset when its first Cast was made (LOG-R49,
-- Core's own RealmUtcOffset), or nil without that Cast in the log.
local function realmSpan(core, session, first)
	if not first then
		return nil
	end
	local offset = core.RealmUtcOffset(first.time, first.conditions.minute) * 60
	local function realm(time)
		return os.date("!%Y-%m-%d %H:%M", (tonumber(time) or 0) + offset)
	end
	return ("realm %s to %s"):format(realm(session.startTime), realm(session.endTime))
end

-- The last Sessions (STA-R30), oldest first, each with its start and end in realm and server time, its counts, zones
-- and skill gained (STA-R27), and the log's Casts carrying its ID (LOG-R98), which it should count the same.
local function printStatsSessions(core, sessions, facts)
	local tagged = facts and facts.sessions or {}
	local carried = facts and count(#sortedKeys(tagged), "Session ID") or "no PagleLog"
	local first = math.max(1, #sessions - STATS_SESSIONS_SHOWN + 1)
	if #sessions == 0 then
		print(("Sessions: none stored, the log's Casts carry %s"):format(carried))
		return
	end
	local shown = #sessions - first + 1
	print(
		("Sessions: %d stored, the log's Casts carry %s; the last %d, oldest first:"):format(#sessions, carried, shown)
	)
	for i = first, #sessions do
		local session = tableOr(sessions[i])
		local logged = tagged[session.id]
		local span = realmSpan(core, session, logged and logged.first)
			or "realm time unknown (no Cast of it in the log)"
		print(
			("  %d. %s: %s, server %s to %s"):format(
				i,
				tostring(session.id),
				span,
				utc(tonumber(session.startTime) or 0),
				utc(tonumber(session.endTime) or 0)
			)
		)
		local zones = {}
		for j, zone in ipairs(sortedKeys(tableOr(session.zones))) do
			zones[j] = zone .. " ×" .. tostring(session.zones[zone])
		end
		local inLog = logged and logged.casts or 0
		local check = facts
				and ("the log tags %s with it (%s)"):format(
					count(inLog, "Cast"),
					inLog == session.casts and "matches" or "DIFFERS"
				)
			or "no PagleLog to check against"
		print(
			("     %s, zones %s, skill +%s; %s"):format(
				countsText(session),
				#zones > 0 and table.concat(zones, ", ") or "none",
				tostring(session.skill or 0),
				check
			)
		)
	end
end

-- The reading's side (STA-R41), and what decided it: --skill against the line, else the place's most Casts.
local function sideText(reading, state, live, line)
	if line == nil then
		return ("side: %s, no no-junk line (STA-R41)"):format(reading.side)
	elseif live then
		return ("side: %s, --skill %d against the line %d (STA-R41)"):format(reading.side, live, line)
	end
	local casts = {}
	for i, side in ipairs({ "hi", "lo", "na" }) do
		casts[i] = side .. " " .. tostring(tableOr(state.scopes)[reading.area .. ":" .. side] or 0)
	end
	return ("side: %s, the most Casts here (%s), no --skill (STA-R41)"):format(reading.side, table.concat(casts, ", "))
end

-- Prints --stats-item's reading in --area (STA-R40–R54), computed with Stats' own Reading, Odds* and DrySpell* over
-- the stored state, at the live skill --skill gives (STA-R41).
local function printStatsItem(stats, state, places, options)
	local heading = ("== Stats item %d in area %d (--stats-item, --area)"):format(options.statsItem, options.area)
	if not state then
		print(heading .. ": no projection stored to read")
		return
	elseif not places then
		print(heading .. ": can't be read without the catalogue (see fingerprint: above)")
		return
	end
	print(heading)
	local reading = stats.Reading(state, options.statsItem, options.area, options.skill, places)
	print(sideText(reading, state, options.skill, (places:NoJunkLine(reading.zone))))
	local via = reading.viaZone
			and (", its zone's: area %d has under %d there"):format(reading.area, stats.ODDS_THRESHOLD)
		or ""
	print(("scope: %s, %s, %d caught%s (STA-R42)"):format(reading.scope, count(reading.n, "Cast"), reading.k, via))
	print(("state: %s (STA-R43)"):format(reading.state))
	print(("Your odds: %s (short: %s)"):format(stats.OddsHeadline(reading), stats.OddsShort(reading)))
	print("range: " .. (stats.OddsRange(reading) or "none until known (STA-R45)"))
	print("sentence: " .. stats.OddsSentence(reading))
	for _, note in ipairs(stats.OddsNotes(reading, places)) do
		print("note: " .. note)
	end
	local dry = stats.DrySpell(reading)
	if not dry.caught then
		print(("Dry spell: %s, never caught in this scope (STA-R50)"):format(count(dry.since, "Cast")))
	else
		local hit = reading.hit
		local text = ("Dry spell: %s since the last, at %d, last caught %s"):format(
			count(dry.since, "Cast"),
			hit.at,
			utc(hit.last)
		)
		if dry.P then
			text = text .. ("; P %.3g, band %s (STA-R50–R52)"):format(dry.P, dry.band)
		else
			text = text .. " (STA-R50)"
		end
		print(text)
	end
	local first, after = stats.DrySpellText(reading)
	print("Dry spell text: " .. first .. (after and " " .. after or ""))
	local short, band = stats.DrySpellShort(reading)
	print("short: " .. stats.OddsShort(reading) .. (short and " · " .. short .. (band or "") or ""))
end

-- The profile (stats.md › PagleStatsDB, one shared "Default" profile): the live tracker setting (STA-R81), each watch
-- (STA-R60) with its reading in short (STA-R43, STA-R82: its count and band, or no luck reading), and the book's
-- position (STA-R71), each said to be the default when AceDB left it out of the file.
local function printStatsProfile(stats, state, places, profile, live)
	if profile.tracker == nil then
		print("tracker: false (not saved: the default)")
	else
		print("tracker: " .. tostring(profile.tracker))
	end
	local watched = tableOr(profile.watched)
	if #watched == 0 then
		print("watched: none (not saved: the default)")
	else
		local side = live and "read at --skill " .. live
			or "read on the side with the most Casts in each place (no --skill, STA-R41)"
		print(("watched: %d, oldest first, %s"):format(#watched, side))
	end
	for i, watch in ipairs(watched) do
		watch = tableOr(watch)
		local what = ("  %d. item %s in area %s"):format(i, tostring(watch.item), tostring(watch.area))
		if not (state and places) then
			print(what .. " (no reading without a projection and the catalogue)")
		else
			local reading = stats.Reading(state, watch.item, watch.area, live, places)
			local dry = stats.DrySpell(reading)
			local band = dry.band and stats.BandWord(dry.band) or "no luck reading"
			local text = "%s: %s, Dry spell %s, %s (%s)"
			print(text:format(what, stats.OddsShort(reading), stats.DrySpellCount(reading), band, reading.scope))
		end
	end
	local window = profile.window
	if type(window) ~= "table" then
		print("window: not saved, so centred (the default, STA-R71)")
	else
		local text = "window: %s of UIParent's %s, x %s, y %s (moved by the player, STA-R71)"
		print(text:format(tostring(window[1]), tostring(window[2]), tostring(window[3]), tostring(window[4])))
	end
end

-- The latest Cast's place and skill (#221 step 2): its zone and subzone areaIDs and its effective skill, rank + mod
-- (STA-R11), which --area and --skill take to read an item as the book read it there. One line, none with no Cast.
---@param cast table? the latest Cast record, decoded
local function printLatestPlace(cast)
	if not cast then
		return
	end
	local c = cast.conditions
	local subzone = (c.subzone or 0) ~= 0 and ("subzone " .. c.subzone) or "no subzone"
	local skill = "skill unknown" -- not read, as in combat (STA-R93)
	if c.skillRank then
		local mod = c.skillMod or 0
		skill = ("skill %d + %d = %d"):format(c.skillRank, mod, c.skillRank + mod)
	end
	print(("latest Cast: zone %s, %s, %s (for --area and --skill)"):format(tostring(c.zone), subzone, skill))
end

-- Prints the Stats section from SavedVariables/Pagle_Stats.lua (stats.md › Data): the projection Core stores (LOG-R70)
-- with its checks, the state's counts and last Sessions, cross-checked with the log's Session IDs (`facts`, the Catch
-- log section's, nil without a log), and the profile; then --stats-item's reading in its own section.
local function printStats(account, log, facts, options)
	local path = account .. "/SavedVariables/Pagle_Stats.lua"
	local saved, err = loadSavedVariables(path)
	if not saved then
		print("== Stats: can't read " .. path .. ": " .. err)
		return
	end
	local db = saved.PagleStatsDB
	if type(db) ~= "table" then
		print("== Stats: Pagle_Stats.lua holds no PagleStatsDB")
		return
	end
	print("== Stats (PagleStatsDB)")
	local core = loadCoreLogic()
	local stats = loadStatsLogic(log, options.now or os.time())
	local context = { label = options.catalogue or "the repo's addons/Pagle/data/Catalogue.lua" }
	context.places, context.fingerprint =
		statsPlaces(stats, core, options.catalogue or ROOT .. "/addons/Pagle/data/Catalogue.lua")
	if not context.places then
		context.err = context.fingerprint
	end
	local stored, state = tableOr(db.global).projection, nil
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print("projection: none stored (no build has finished, LOG-R72)")
	else
		printStatsStored(stats, core, stored, log, context)
		state = stored.projection
		-- An empty table AceDB or an older state left out reads as empty (stats.md › Projection state).
		state.scopes, state.hits, state.places = tableOr(state.scopes), tableOr(state.hits), tableOr(state.places)
		printStatsCounts(state, log)
		printStatsSessions(core, tableOr(state.sessions), facts)
	end
	printLatestPlace(facts and facts.lastCast)
	printStatsProfile(stats, state, context.places, tableOr(tableOr(db.profiles).Default), options.skill)
	if options.statsItem then
		printStatsItem(stats, state, context.places, options)
	end
end

-- The Tackle Board section's lines (#242): its Module records in PagleLog and what PagleTackleBoardDB holds
-- (tackle-board.md › Data), with what the Tackle Board's own logic/ computes from them over the catalogue (the repo's
-- or --catalogue's): the records decoded, the goals' text and need, stranded goals and today's board day.

local BOARD_MODULE = "TackleBoard"
local BOARD_RECORD_KINDS = { "start", "day", "issue", "reroll" }
local GOAL_TYPES = { n = "Notice", e = "Expedition" }

-- The Tackle Board's namespace with its strings and its logic: each locale/, data/ and logic/ file
-- Pagle_TackleBoard.toc lists, in TOC order, called with ("Pagle_TackleBoard", ns) as the client calls an addon's files
-- (spec/Pagle_TackleBoard/support.lua loads them the same way over FakePagle). Their CORE-R11 guard reads the Pagle
-- global, so it's a table here; logic/Rewards.lua takes LuaBitOp's functions at load: the client's `bit` library, the
-- one setup.sh pins (wtf.luaBitOp, as make-test-log.lua loads it), or an empty one without it, since nothing here ties
-- a fly. Its ns.api (logic/Seams.lua) gets the reader's stand-ins for the client's calls: "Area {id}",
-- "Map {id}" and "Item {id}" for the names, no realm clock (so realm dates read as UTC), and Core's catalogue calls
-- over `catalogue` (nil when it can't load) with Core's Size bands.
local function loadBoardLogic(catalogue)
	local ns = {}
	local env = setmetatable({ Pagle = {}, bit = wtf.luaBitOp() or {} }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_TackleBoard/"
	for _, file in ipairs(wtf.tocEntries("Pagle_TackleBoard")) do
		if file:match("^locale/[^/]+%.lua$") or file:match("^data/[^/]+%.lua$") or file:match("^logic/[^/]+%.lua$") then
			assert(wtf.loadInto(ns, env, dir .. file, "Pagle_TackleBoard"))
		end
	end
	local pagle = { SIZE_BANDS = loadCoreRules().SIZE_BANDS }
	for _, name in ipairs({ "GetItem", "GetArea", "GetZones", "GetZoneCatches" }) do
		pagle[name] = catalogue and catalogue[name]
	end
	local function named(prefix)
		return function(id)
			return prefix .. " " .. tostring(id)
		end
	end
	ns.api = {
		AreaName = named("Area"),
		MapName = named("Map"),
		ItemName = named("Item"),
		RequestItem = function() end,
		FormatNumber = thousands,
		pagle = pagle,
	}
	return ns
end

-- A server time as "realm 2026-10-14 08:10, server 2026-10-14 15:10:00 UTC", at the realm's UTC offset in minutes
-- (LOG-R49), or "realm unknown" without one.
local function realmAndServer(time, offset)
	local realm = offset and os.date("!%Y-%m-%d %H:%M", time + offset * 60) or "unknown"
	return ("realm %s, server %s"):format(realm, utc(time))
end

-- A goal definition (tackle-board.md › Data) as "Notice haul tier 1, pays 10, need 3, target 12 ("3 Catches in
-- Area 12")", its text from the board's own GoalText (TKB-R36).
local function goalDefinition(board, def)
	local target = def.target and tostring(def.target) or "none"
	if def.items then
		target = target .. ":" .. table.concat(def.items, ",")
	end
	return ('%s %s tier %d, pays %d, need %d, target %s ("%s")'):format(
		GOAL_TYPES[def.type],
		def.kind,
		def.tier,
		def.pay,
		def.need,
		target,
		board.GoalText(def)
	)
end

-- One of the board's records (TKB-R80): its seq and time, its kind and its payload decoded with the board's own codec
-- (logic/Records.lua), or flagged when the board skips it.
local function boardRecordLine(board, record, offset)
	local head = ("  seq %d, %s: %s"):format(record.seq, realmAndServer(record.time, offset), record.recordKind)
	local decoded = board.DecodeRecord(record.recordKind, record.payload)
	if not decoded then
		return head .. (', SKIPPED: the board can\'t decode "%s" (TKB-R80)'):format(record.payload)
	elseif decoded.goal then
		return head .. (decoded.old and " of " .. decoded.old or "") .. ", " .. goalDefinition(board, decoded.goal)
	end
	return head .. (", dayStart %s, weekStart %s"):format(utc(decoded.dayStart), utc(decoded.weekStart))
end

-- How many records the board kept, by kind (TKB-R80's four first, then any other), as "start 1, day 7, issue2 1".
local function recordKindCounts(counts)
	local parts, known = {}, {}
	for _, kind in ipairs(BOARD_RECORD_KINDS) do
		known[kind] = true
		if counts[kind] then
			parts[#parts + 1] = kind .. " " .. counts[kind]
		end
	end
	for _, kind in ipairs(sortedKeys(counts)) do
		if not known[kind] then
			parts[#parts + 1] = kind .. " " .. counts[kind]
		end
	end
	return table.concat(parts, ", ")
end

-- The board's Module records in PagleLog (LOG-R40, TKB-R80), read as M:IterateCatches reads them with Core's codec:
-- the count by kind, those the board's codec skips, and the last 10 decoded, at the realm's UTC offset (`offset`,
-- minutes, from the log's latest Cast; nil when none read the realm minute).
local function printBoardRecords(board, core, log, offset)
	if not log then
		print("records: no PagleLog to read")
		return
	elseif log.format ~= core.LOG_FORMAT then
		print(
			("records: PagleLog is format %s, the codec reads format %d"):format(tostring(log.format), core.LOG_FORMAT)
		)
		return
	end
	local records, counts, skipped = {}, {}, {}
	for record in core.OpenCatchLog(log, { decodeErrors = 0 }, 0):Iterate(0, BOARD_MODULE) do
		if record.kind == "module" then
			records[#records + 1] = record
			counts[record.recordKind] = (counts[record.recordKind] or 0) + 1
			if not board.DecodeRecord(record.recordKind, record.payload) then
				skipped[#skipped + 1] = record.seq
			end
		end
	end
	if #records == 0 then
		print("records: no TackleBoard A1 entries in PagleLog")
		return
	end
	print(("records: %d TackleBoard A1 entries in PagleLog: %s"):format(#records, recordKindCounts(counts)))
	local skips = #skipped > 0 and ("%d (seq %s) (TKB-R80)"):format(#skipped, table.concat(skipped, ", ")) or "none"
	print("records the board skips: " .. skips)
	local first = math.max(1, #records - 9)
	local clock = offset and ("realm time at the log's realm clock (%s)"):format(utcOffset(offset))
		or "realm time unknown (no Cast read the realm minute)"
	print(("the last %d, oldest first, %s:"):format(#records - first + 1, clock))
	for i = first, #records do
		print(boardRecordLine(board, records[i], offset))
	end
end

-- The projection Core stores for the Tackle Board (LOG-R70), checked against PagleLog (LOG-R72), its rules version
-- (TKB-R81: the board's own ProjectionDef over Core's SESSION_RULES_VERSION, logic/Sessions.lua) and the catalogue's
-- content fingerprint, the board having no extra one. `context` holds the catalogue's label, and its fingerprint or why
-- it can't load.
local function printBoardStored(board, core, stored, log, context)
	printStored(stored, log)
	local rulesVersion = board.ProjectionDef({}, core.SESSION_RULES_VERSION).rulesVersion
	if stored.rulesVersion == rulesVersion then
		print(("rulesVersion: the Tackle Board's, %d (TKB-R81)"):format(rulesVersion))
	else
		local text = "rulesVersion: %s DIFFERS from the Tackle Board's %d (1000 × TKB_RULES_VERSION %d + Core's"
			.. " SESSION_RULES_VERSION %d), so Core rebuilds it at login (TKB-R81, LOG-R72)"
		print(
			text:format(
				tostring(stored.rulesVersion),
				rulesVersion,
				board.TKB_RULES_VERSION,
				core.SESSION_RULES_VERSION
			)
		)
	end
	if not context.catalogue then
		print(("fingerprint: can't be checked: %s can't load: %s"):format(context.label, tostring(context.err)))
	elseif stored.fingerprint == context.catalogue.CONTENT_FINGERPRINT then
		print(("fingerprint: the catalogue's, %s (LOG-R70)"):format(context.label))
	else
		local text = "fingerprint: DIFFERS from the catalogue's %s, %s, so Core rebuilds it at login (LOG-R70, LOG-R72)"
		print(text:format(tostring(context.catalogue.CONTENT_FINGERPRINT), context.label))
	end
end

-- The seconds since the epoch the file at `path` was last written (`stat`, in WSL), or nil when it can't be read.
local function fileWriteTime(path)
	local ok, pipe = pcall(io.popen, "stat -c %Y -- '" .. path:gsub("'", "'\\''") .. "' 2>/dev/null")
	if not ok or not pipe then
		return nil
	end
	local text = pipe:read("*a") or ""
	pipe:close()
	return tonumber(text:match("^%s*(%d+)%s*$"))
end

-- A goal as "Notice haul, "3 Catches in Area 12"" (TKB-R36).
local function goalHead(board, goal)
	return ('%s %s, "%s"'):format(
		GOAL_TYPES[goal.type] or tostring(goal.type),
		tostring(goal.kind),
		board.GoalText(goal)
	)
end

-- An open goal's line (TKB-R101–R104): its ID, its text, its progress of its need (the board's own GoalNeed over the
-- catalogue, TKB-R44, or the record's without it), and whether it is re-posted (TKB-R55), stranded (TKB-R44) or
-- day-bound, with the board day its progress belongs to (TKB-R41).
local function openGoalLine(board, goal, pagle)
	local need = pagle and board.GoalNeed(goal, pagle) or goal.need
	local line = ("%s: %s, %s of %s"):format(goal.id, goalHead(board, goal), tostring(goal.progress), tostring(need))
	if not pagle then
		line = line .. " (need from the record)"
	end
	-- The record's definition (TKB-R22): what a rebuild must give back unchanged.
	line = line .. (", tier %s, pays %s, need %s"):format(tostring(goal.tier), tostring(goal.pay), tostring(goal.need))
	if pagle and need ~= goal.need then
		line = line .. (", need now %s (TKB-R44)"):format(tostring(need))
	end
	if goal.reposted then
		line = line .. ", re-posted (TKB-R55)"
	end
	if pagle and board.IsStranded(goal, pagle) then
		line = line .. ", STRANDED (TKB-R44)"
	end
	if board.IsDayBound(goal) then
		local day = goal.progressDay and "its board day " .. goal.progressDay or "no board day yet"
		line = line .. ", day-bound, " .. day .. " (TKB-R41)"
	end
	return line
end

-- The pins of one type (TKB-R101), each with its goal or "empty".
local function printPins(board, label, pins, goals, pagle)
	print(label .. " pins:")
	for i, id in ipairs(pins) do
		local goal = id and goals[id]
		if not id then
			print(("  %d. empty"):format(i))
		elseif not goal then
			print(("  %d. %s: not in goals"):format(i, tostring(id)))
		else
			print(("  %d. %s"):format(i, openGoalLine(board, goal, pagle)))
		end
	end
end

-- The completed goals kept (tackle-board.md › Projection: the last 28 board days), by the day each was done (TKB-R60).
local function printCompletedGoals(board, goals)
	local done = {}
	for _, goal in pairs(goals) do
		if goal.doneDay then
			done[#done + 1] = goal
		end
	end
	table.sort(done, function(a, b)
		if a.doneDay ~= b.doneDay then
			return a.doneDay < b.doneDay
		elseif (a.doneTime or 0) ~= (b.doneTime or 0) then
			return (a.doneTime or 0) < (b.doneTime or 0)
		end
		return a.id < b.id
	end)
	local kept = ("in the last %d board days"):format(board.KEPT_DAYS)
	print(#done > 0 and ("completed: %d %s, by doneDay"):format(#done, kept) or "completed: none " .. kept)
	for _, goal in ipairs(done) do
		local line = "  day %d: %s, %s, pays %s, %s"
		local fly = goal.fly and "fly " .. goal.fly or "no fly"
		print(line:format(goal.doneDay, goal.id, goalHead(board, goal), tostring(goal.pay), fly))
	end
end

-- The Fly Box (TKB-R62) in pattern order (Data), each tied pattern with its day and the goal that tied it, then any
-- tied ID that isn't a pattern now; and the titles (TKB-R64) in the board's title order, each with its day and Cast.
local function printFliesAndTitles(board, flies, titles)
	local ids, known = {}, {}
	for _, pattern in ipairs(board.FLY_PATTERNS) do
		known[pattern.id] = true
		if flies[pattern.id] then
			ids[#ids + 1] = pattern.id
		end
	end
	for _, id in ipairs(sortedKeys(flies)) do
		if not known[id] then
			ids[#ids + 1] = id
		end
	end
	local tied = #ids > 0 and ("%d of %d tied, in pattern order (TKB-R62):"):format(#ids, #board.FLY_PATTERNS)
		or ("none of %d tied (TKB-R62)"):format(#board.FLY_PATTERNS)
	print("flies: " .. tied)
	for _, id in ipairs(ids) do
		local fly = tableOr(flies[id])
		local what = known[id] and "" or " (not a pattern now)"
		print(("  %s%s: day %s, goal %s"):format(id, what, tostring(fly.day), tostring(tableOr(fly.goal).id)))
	end
	local earned = {}
	for _, title in ipairs(board.TITLES) do
		if titles[title.id] then
			earned[#earned + 1] = title.id
		end
	end
	print("titles: " .. (#earned > 0 and #earned or "none") .. " (TKB-R64)")
	for _, id in ipairs(earned) do
		local title = tableOr(titles[id])
		print(("  %s: day %s, Cast %s"):format(id, tostring(title.day), tostring(title.cast)))
	end
end

-- The Campfire (TKB-R70–R73): its count, Kindling and longest, the milestones reached and the day log kept.
local function printFire(fire)
	print(
		("fire: count %s, Kindling %s, longest %s (TKB-R70–R72)"):format(
			tostring(fire.count),
			tostring(fire.kindling),
			tostring(fire.longest)
		)
	)
	local milestones = {}
	for i, days in ipairs(sortedKeys(tableOr(fire.milestones))) do
		local reached = tableOr(fire.milestones[days])
		milestones[i] = ("%s days on day %s, Cast %s"):format(days, tostring(reached.day), tostring(reached.cast))
	end
	print("fire milestones: " .. (#milestones > 0 and table.concat(milestones, ", ") or "none") .. " (TKB-R73)")
	local days = {}
	for i, day in ipairs(sortedKeys(tableOr(fire.log))) do
		days[i] = ("day %s %s"):format(day, tostring(fire.log[day]))
	end
	print("fire log: " .. (#days > 0 and table.concat(days, ", ") or "none"))
end

-- The state's lines (tackle-board.md › Projection): started, the latest boundary, the processed day and week, today at
-- `now` (TKB-R12, the board's own DayOf from the latest boundary), the goals owed, the pins and the overflow strip, the
-- completed goals, tally, Coins, flies, titles and Campfire; and, started or not, the zones fished and items caught
-- (TKB-R81). `context` holds Core's catalogue calls (nil without the catalogue), the realm offset, and now and its
-- source.
local function printBoardState(board, state, context)
	local started = state.started
	if type(started) ~= "table" then
		print("started: no, the board isn't started (TKB-R2)")
	else
		local offset = context.offset
		print(("started: seq %s, %s (TKB-R6)"):format(tostring(started.seq), realmAndServer(started.time, offset)))
		local boundary = tableOr(state.boundary)
		print(
			("boundary: seq %s, day %s, week %s, dayStart %s, weekStart %s"):format(
				tostring(boundary.seq),
				tostring(boundary.day),
				tostring(boundary.week),
				utc(boundary.dayStart),
				utc(boundary.weekStart)
			)
		)
		print(("processed: day %s, week %s (TKB-R14)"):format(tostring(state.day), tostring(state.week)))
		local today = board.DayOf(boundary, context.now)
		local after = today - state.day
		local ahead
		if after > 0 then
			ahead = count(after, "day") .. " after the processed day: the next live step advances to it"
		elseif after == 0 then
			ahead = "the processed day"
		else
			ahead = "before the processed day (a clock step back)"
		end
		local when = ("%s (%s)"):format(utc(context.now), context.source)
		print(("today: day %d at %s, %s (TKB-R12, TKB-R13)"):format(today, when, ahead))
		local owed = tableOr(state.owed)
		local notices, expeditions = tonumber(owed.notices) or 0, tonumber(owed.expeditions) or 0
		print(("owed: %s, %s (TKB-R20)"):format(count(notices, "Notice"), count(expeditions, "Expedition")))
		local pins, goals = tableOr(state.pins), state.goals
		printPins(board, "Expedition", tableOr(pins.expeditions), goals, context.pagle)
		printPins(board, "Notice", tableOr(pins.notices), goals, context.pagle)
		local strip = {}
		for _, goal in ipairs(board.BoardOrder(state)) do
			if goal.pin == nil then
				strip[#strip + 1] = goal
			end
		end
		print("overflow strip: " .. (#strip > 0 and #strip .. " (TKB-R101)" or "none"))
		for _, goal in ipairs(strip) do
			print("  " .. openGoalLine(board, goal, context.pagle))
		end
		printCompletedGoals(board, goals)
		local tally = tableOr(state.tally)
		print(
			("tally: %s, %s (TKB-R61)"):format(
				count(tonumber(tally.notices) or 0, "Notice"),
				count(tonumber(tally.expeditions) or 0, "Expedition")
			)
		)
		print(("coins: %s (TKB-R63)"):format(tostring(state.coins)))
		printFliesAndTitles(board, tableOr(state.flies), tableOr(state.titles))
		printFire(tableOr(state.fire))
	end
	print("zones: " .. listed(tableOr(state.zones), function(zone, time)
		return ("%s last at %s"):format(zone, utc(tonumber(time) or 0))
	end))
	print("caught: " .. listed(tableOr(state.caught)))
end

-- The celebrated set (TKB-R83): its goal and title IDs, then, with a state, whether every completed goal kept and every
-- earned title is in it; one that isn't was never shown, and a rebuild raises its moment (TKB-R84).
local function printBoardCelebrated(celebrated, state)
	local goals, titles = tableOr(celebrated.goals), tableOr(celebrated.titles)
	print(("celebrated goals: %s, titles: %s"):format(listed(goals), listed(titles)))
	if not state then
		return
	end
	local missing = {}
	for _, id in ipairs(sortedKeys(tableOr(state.goals))) do
		local goal = state.goals[id]
		if goal.doneDay and not goals[id] then
			missing[#missing + 1] = ("%s (day %s)"):format(id, tostring(goal.doneDay))
		end
	end
	if #missing == 0 then
		print("celebrated: every completed goal is in it")
	else
		print(
			("celebrated: MISSING %s: %s (TKB-R83)"):format(
				count(#missing, "completed goal"),
				table.concat(missing, ", ")
			)
		)
	end
	local unshown = {}
	for _, id in ipairs(sortedKeys(tableOr(state.titles))) do
		if not titles[id] then
			unshown[#unshown + 1] = id
		end
	end
	if #unshown == 0 then
		print("celebrated: every earned title is in it")
	else
		print(
			("celebrated: MISSING %s: %s (TKB-R83)"):format(
				count(#unshown, "earned title"),
				table.concat(unshown, ", ")
			)
		)
	end
end

-- The profile (tackle-board.md › PagleTackleBoardDB, one shared "Default" profile): the tracker's two settings, each
-- marked when AceDB left its default out of the file.
local function printBoardProfile(board, profile)
	local defaults = board.DB_DEFAULTS.profile
	for _, name in ipairs({ "tracker", "trackerCollapsed" }) do
		if profile[name] == nil then
			print(("%s: %s (not saved: the default)"):format(name, tostring(defaults[name])))
		else
			print(("%s: %s"):format(name, tostring(profile[name])))
		end
	end
end

-- Prints the Tackle Board section (tackle-board.md › Data): the board's records in PagleLog (`facts`, the Catch log
-- section's, give the realm offset), then from SavedVariables/Pagle_TackleBoard.lua the projection Core stores
-- (LOG-R70) with its checks, its state, the celebrated set and the profile. Today is read at --now, else at the file's
-- write time, else at the reader's clock.
local function printBoard(account, log, facts, options)
	local path = account .. "/SavedVariables/Pagle_TackleBoard.lua"
	local saved, err = loadSavedVariables(path)
	if not saved then
		print("== Tackle Board: can't read " .. path .. ": " .. err)
		return
	end
	local db = saved.PagleTackleBoardDB
	if type(db) ~= "table" then
		print("== Tackle Board: Pagle_TackleBoard.lua holds no PagleTackleBoardDB")
		return
	end
	print("== Tackle Board (PagleTackleBoardDB)")
	local core = loadCoreLogic()
	local context = { label = options.catalogue or "the repo's addons/Pagle/data/Catalogue.lua" }
	context.catalogue, context.err = wtf.loadCatalogue(options.catalogue)
	local board = loadBoardLogic(context.catalogue)
	local offset = facts and facts.realmOffset
	printBoardRecords(board, core, log, offset)
	local global = tableOr(db.global)
	local stored, state = global.board, nil
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print("projection: none stored (no build has finished, LOG-R72)")
	else
		printBoardStored(board, core, stored, log, context)
		state = stored.projection
		state.goals = tableOr(state.goals)
		local now, source = options.now, "--now"
		if not now then
			now, source = fileWriteTime(path), "the file's write time"
		end
		if not now then
			now, source = os.time(), "the reader's clock"
		end
		local pagle = context.catalogue and board.api.pagle or nil
		printBoardState(board, state, { pagle = pagle, offset = offset, now = now, source = source })
	end
	printBoardCelebrated(tableOr(global.celebrated), state)
	printBoardProfile(board, tableOr(tableOr(db.profiles).Default))
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

-- The line for a store of totals' logId (SHOP-R3, AXP-R3): whether it is PagleLog's, else what login does with it.
---@param logId any
---@param log table?
---@return string
local function totalsLogId(logId, log)
	if logId == nil then
		return "none stored (a fresh log's, or no Module has reported since PagleLog had one)"
	elseif not log then
		return tostring(logId) .. ", no PagleLog to compare with"
	elseif logId == log.logId then
		return tostring(logId) .. ", PagleLog's"
	end
	return ("%s, DIFFERS from PagleLog's %s, so Core empties these totals at login"):format(
		tostring(logId),
		tostring(log.logId)
	)
end

-- Prints the Activity XP section (activity-xp.md › Data): each Module's last reported total (AXP-R3) and their sum,
-- the snapshot the next Prestige would write (AXP-R5), then whether these totals and the Coins totals belong to
-- PagleLog's logId (AXP-R3, SHOP-R3).
local function printActivityXP(pagle, log)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Activity XP: " .. why)
		return
	end
	local store = tableOr(global.activityXP)
	local earned = tableOr(store.earned)
	local sum, names = 0, sortedKeys(earned)
	for _, name in ipairs(names) do
		sum = sum + (tonumber(earned[name]) or 0)
	end
	-- AceDB leaves the default, an empty earned table, out of the file.
	print(
		("== Activity XP (PagleDB.global.activityXP.earned): total %d%s"):format(
			sum,
			#names == 0 and ", no Module has reported Activity XP" or ""
		)
	)
	for _, name in ipairs(names) do
		print(name .. ": " .. tostring(earned[name]))
	end
	print("logId: " .. totalsLogId(store.logId, log))
	print("Coins logId: " .. totalsLogId(tableOr(global.coins).logId, log))
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

-- Prints the Tracker dock section (core/README.md › Data, #199): PagleDB.profile.dock.point, the place the player
-- moved the dock to (CORE-R71), or the default under the minimap (CORE-R70). Core's own logic/Dock.lua reads it, so a
-- saved point Core can't read is said to be one. AceDB leaves a nil point out of the file.
local function printDock(pagle)
	local _, why = pagleGlobal(pagle)
	if why then
		print("== Tracker dock: " .. why)
		return
	end
	print("== Tracker dock (PagleDB.profile.dock.point)")
	local ns = wtf.loadCore({ "logic/Dock.lua" })
	local saved = tableOr(tableOr(tableOr(pagle.saved.PagleDB.profiles).Default).dock).point
	local anchor = ns.DockAnchor(saved)
	local place = ("%s of %s's %s, x %s, y %s"):format(
		anchor.point,
		anchor.relativeTo,
		anchor.relativePoint,
		tostring(anchor.x),
		tostring(anchor.y)
	)
	if saved == nil then
		print("dock.point: default (none saved): " .. place .. " (CORE-R70)")
	elseif anchor.relativeTo == "UIParent" then
		print("dock.point: " .. place .. " (moved by the player, CORE-R71)")
	else
		print("dock.point: saved but not one Core reads, so the default: " .. place .. " (CORE-R70)")
	end
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

-- What each Letter state means for the next login (ONB-R2, ONB-R10, ONB-R12).
local LETTER_MEANINGS = {
	waiting = "a new Angler's: the Letter shows at the next login, ONB-R10",
	later = "Later pressed once: the Letter shows once more, ONB-R12",
	declined = "Later pressed twice: the Letter never shows again, ONB-R12",
	opened = "the Letter was opened, and never shows again, ONB-R12",
	returning = "the Catch log held a Cast when this was made: no Letter and no First evening list, ONB-R2",
}

-- A set of ids (`{ [id] = true }`) as "2 (box, welcome)", or "none"; a value other than true is shown beside its id.
local function idSet(set)
	return listed(tableOr(set), function(key, value)
		return value == true and tostring(key) or ("%s = %s"):format(tostring(key), tostring(value))
	end)
end

-- A boolean key of the onboarding state, or that it is missing.
local function stateFlag(value)
	return value == nil and "missing" or tostring(value)
end

-- Prints the Onboarding section (core/onboarding.md › Data): PagleDB.global.schemaVersion, whose step 2 adds the state
-- (ONB-R1), then PagleDB.global.onboarding key by key: the Letter's state and what it means (ONB-R2, ONB-R12), the
-- guide's step and the steps seen (ONB-R22), done, skipped and reopen (ONB-R25, ONB-R26), the Margin notes setting
-- and the notes and First looks seen (ONB-R50, ONB-R55, ONB-R81), the First evening list (ONB-R60–R63) and the
-- characters' GUIDs (ONB-R3), each named from PagleLog's characters. The state isn't in AceDB's defaults, so it is
-- saved whole: a key the file lacks is said to be missing.
local function printOnboarding(pagle, log)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Onboarding: " .. why)
		return
	end
	print("== Onboarding (PagleDB.global.onboarding)")
	print("schemaVersion: " .. tostring(global.schemaVersion or "none saved, so no migration has run"))
	local state = global.onboarding
	if type(state) ~= "table" then
		print("onboarding: none stored, so the next login adds it (ONB-R1)")
		return
	end
	local letter = state.letter
	local meaning = LETTER_MEANINGS[letter] or "not a state Core knows, ONB-R12"
	print(("letter: %s (%s)"):format(tostring(letter), meaning))
	print("guideStep: " .. (state.guideStep == nil and "none" or tostring(state.guideStep)))
	print("stepsSeen: " .. idSet(state.stepsSeen))
	print(
		("guideDone: %s, skipped: %s, reopen: %s"):format(
			stateFlag(state.guideDone),
			stateFlag(state.skipped),
			stateFlag(state.reopen)
		)
	)
	print("notesOn: " .. stateFlag(state.notesOn))
	print("notesSeen: " .. idSet(state.notesSeen))
	print("looksSeen: " .. idSet(state.looksSeen))
	local evening = tableOr(state.evening)
	print(
		("evening: shown %s, closed %s, done %s"):format(
			stateFlag(evening.shown),
			stateFlag(evening.closed),
			idSet(evening.done)
		)
	)
	-- Each GUID's name, from PagleLog's characters.
	local names = {}
	for char, character in ipairs(log and log.characters or {}) do
		if type(character) == "table" and character.guid then
			names[character.guid] = wtf.characterName(log, char)
		end
	end
	local guids = sortedKeys(tableOr(state.characters))
	print("characters: " .. (#guids > 0 and #guids or "none"))
	for _, guid in ipairs(guids) do
		print(("  %s: %s"):format(tostring(guid), names[guid] or "not in PagleLog's characters"))
	end
end

-- The P rows (REP-R22) Core builds in the game from the diagnostics buffer (LOG-R81) and the log's Casts, with its
-- own ns.FieldReportPRows; none without a log the codec reads.
local function pRows(ns, global, log)
	if not log or log.format ~= ns.LOG_FORMAT then
		return {}
	end
	local buffer = type(global.diagnostics) == "table" and global.diagnostics or {}
	local catchLog = ns.OpenCatchLog(log, { decodeErrors = 0 }, 0)
	return ns.FieldReportPRows(buffer, catchLog:Reverse("cast"))
end

-- Prints the Field report section (field-report.md › Data): the projection Core stores in
-- PagleDB.global.projections.fieldReport (REP-R25), checked against PagleLog (LOG-R72), its count as the box's
-- entry points show it, the stored I and K rows plus the P rows built from the buffer (REP-R26), and the reporter
-- key of PagleLog.logId (REP-R36), all with Core's own logic/. One line while no projection is stored.
local function printFieldReport(pagle, log)
	local global, why = pagleGlobal(pagle)
	if not global then
		print("== Field report: " .. why)
		return
	end
	local ns = loadCoreLogic()
	local heading = "== Field report (PagleDB.global.projections.fieldReport): reporter key "
		.. (log and type(log.logId) == "string" and ns.ReporterKey(log.logId) or "none (no PagleLog logId)")
	local stored = tableOr(global.projections).fieldReport
	if type(stored) ~= "table" or type(stored.projection) ~= "table" then
		print(heading .. ", projection: none stored (no build has finished, LOG-R72)")
		return
	end
	print(heading)
	printStored(stored, log)
	local kept, built = tonumber(stored.projection.count) or 0, #pRows(ns, global, log)
	print(
		('count: %d I and K rows stored + %d P rows from the buffer = %d (the menu\'s "(%d)", REP-R26)'):format(
			kept,
			built,
			kept + built,
			kept + built
		)
	)
end

-- The addons whose TOCs check 12 compares the probe's interface number with (CORE-R2).
local TOC_ADDONS = { "Pagle", "Pagle_Ledger", "Pagle_QoL", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard" }

-- Each `## Interface:` number the repo's TOCs list, deduplicated, as numbers.
local function tocInterfaces()
	local seen, list = {}, {}
	for _, addon in ipairs(TOC_ADDONS) do
		for _, line in ipairs(wtf.tocEntries(addon)) do
			local numbers = line:match("^## Interface:%s*(.-)$")
			for number in (numbers or ""):gmatch("%d+") do
				if not seen[number] then
					seen[number] = true
					list[#list + 1] = tonumber(number)
				end
			end
		end
	end
	table.sort(list)
	return list
end

-- Prints the Probe section (#261): what `/pagle dev probe` saved in PagleDB.global.probe for launch re-verification
-- (roadmap.md › Launch re-verification checklist), judged by Core's own logic/Probe.lua (ns.ProbeReport, the same
-- judge the game's chat lines use): each check's facts, then an ok or FAIL line naming the rule a miss changes. Check
-- 12 also compares the probe's interface number with every TOC's (CORE-R2).
local function printProbe(pagle)
	local global, why = pagleGlobal(pagle)
	if why then
		print("== Probe: " .. why)
		return
	end
	local probe = global.probe
	-- The load timings alone (#262) are no probe: the Re-verification section reads them.
	if type(probe) ~= "table" or type(probe.checks) ~= "table" then
		print("== Probe (PagleDB.global.probe)")
		print("probe: none stored (/pagle dev probe, then /reload)")
		return
	end
	local build = tableOr(probe.build)
	print(
		("== Probe (PagleDB.global.probe): %s, build %s %s (%s), interface %s, %s"):format(
			type(probe.time) == "number" and utc(probe.time) or "no time",
			tostring(build.version),
			tostring(build.build),
			tostring(build.date),
			tostring(build.interface),
			tostring(probe.locale)
		)
	)
	local ns = wtf.loadCore({ "logic/Probe.lua" })
	local failed = {}
	for _, report in ipairs(ns.ProbeReport(probe)) do
		if report.check == 12 then
			for _, interface in ipairs(tocInterfaces()) do
				if interface ~= build.interface then
					report.verdicts[#report.verdicts + 1] = {
						false,
						("interface %s, but a TOC says %d: bump ## Interface in every TOC (CORE-R2)"):format(
							tostring(build.interface),
							interface
						),
					}
				end
			end
		end
		print(("check %d: %s"):format(report.check, report.summary))
		for _, line in ipairs(report.details) do
			print("    " .. line)
		end
		local ok = true
		for _, verdict in ipairs(report.verdicts) do
			print((verdict[1] and "  ok    " or "  FAIL  ") .. verdict[2])
			ok = ok and verdict[1]
		end
		if not ok then
			failed[#failed + 1] = report.check
		end
	end
	print(
		#failed == 0 and ("probe: every check of %d passes"):format(#ns.PROBE_CHECKS)
			or ("probe: %d of %d checks FAIL: %s"):format(#failed, #ns.PROBE_CHECKS, table.concat(failed, ", "))
	)
end

-- Re-verification (#262) ------------------------------------------------------------------------------------------

local MIB = 1024 * 1024

-- count, with thousands separators (the Stats section's thousands): "1 Cast", "116,540 Casts".
local function many(n, noun, plural)
	return thousands(n) .. " " .. (n == 1 and noun or plural or noun .. "s")
end

-- A realm minute of day as "21:03".
local function minuteOfDay(minute)
	return ("%02d:%02d"):format(math.floor(minute / 60), minute % 60)
end

-- Checks 2 and 10's timings (PagleDB.global.probe.timings, logic/LoadTimings.lua): each mark in ms after Core's files
-- loaded, then each projection's catch-up or rebuild on a line of its own, its longest frame set against LOG-R71's
-- budget (one that ran at once, in one frame, has none to meet).
local function printTimings(timings, ns)
	if type(timings) ~= "table" or type(timings.marks) ~= "table" then
		print(
			"check 2, 10: no load timings (PagleDB.global.probe.timings): /pagle dev on, then log in; that login's"
				.. " are saved at the next /reload or logout"
		)
		return
	end
	local marks = timings.marks
	local zero = tonumber(marks.filesLoaded) or tonumber(marks.addonLoaded) or 0
	local function at(ms)
		return ("%.1f ms"):format(ms - zero)
	end
	local budget = tonumber(timings.budget) or 0
	print(
		("check 2, 10: load timings of the login at %s (dev mode on), %s entries at load, after Core's files loaded:"):format(
			type(timings.time) == "number" and utc(timings.time) or "an unknown time",
			thousands(tonumber(timings.entries) or 0)
		)
	)
	for _, mark in ipairs(ns.LOAD_MARKS) do
		local ms = tonumber(marks[mark[1]])
		local missing = mark[1] == "idle"
				and "not reached (a catch-up or rebuild was still running at the /reload or logout)"
			or "not reached"
		print(("  %-22s %s"):format(mark[2], ms and at(ms) or missing))
	end
	for _, timing in ipairs(type(timings.projections) == "table" and timings.projections or {}) do
		local started, finished = tonumber(timing.started) or 0, tonumber(timing.finished) or 0
		local frames, longest = tonumber(timing.frames) or 0, tonumber(timing.longest) or 0
		local frame = frames <= 1
				and ("at once, longest %.2f ms (LOG-R71: %s pending entries or fewer)"):format(
					longest,
					tostring(timings.syncLimit)
				)
			or ("longest frame %.2f ms of the %g ms budget (LOG-R71)%s"):format(
				longest,
				budget,
				longest > budget and ": OVER" or ""
			)
		print(
			("  %s: %s of %s, %s to %s (%.1f ms), %s, %s"):format(
				tostring(timing.name),
				tostring(timing.mode),
				many(tonumber(timing.applied) or 0, "entry", "entries"),
				at(started),
				at(finished),
				finished - started,
				many(frames, "frame"),
				frame
			)
		)
	end
	local entering, idle = tonumber(marks.enteringWorld), tonumber(marks.idle)
	if entering and idle then
		print(("check 10: every projection caught up %.1f ms after PLAYER_ENTERING_WORLD"):format(idle - entering))
	end
end

-- Whether a realm minute is in a window's ranges ({ from, to }, from inclusive, to exclusive, wrapping past midnight
-- when to < from), and how far into its range it is.
local function inRanges(ranges, minute)
	for _, range in ipairs(ranges) do
		local from, to = range[1], range[2]
		local inside = from <= to and (minute >= from and minute < to)
			or (from > to and (minute >= from or minute < to))
		if inside then
			return true, (minute - from) % 1440
		end
	end
	return false
end

-- Check 4: the Casts whose realm minute lies in the catalogue's night window (DATA-R36), with their first and last
-- realm minute through the night, the Casts with no realm minute, and the realm's UTC offset each Cast's realm minute
-- gives (LOG-R49): more than one is a clock change or a wrong minute.
local function printNight(casts, catalogue, ns)
	local spec = catalogue and catalogue.GetWindowSpec("night")
	local ranges = spec and spec.time
	if type(ranges) ~= "table" or #ranges == 0 then
		print("check 4: the catalogue has no night window with realm times (DATA-R36)")
	else
		local window = {}
		for i, range in ipairs(ranges) do
			window[i] = minuteOfDay(range[1]) .. " to " .. minuteOfDay(range[2])
		end
		local n, first, last = 0, nil, nil
		for _, cast in ipairs(casts) do
			local inside, into = false, 0
			if cast.minute then
				inside, into = inRanges(ranges, cast.minute)
			end
			if inside then
				n = n + 1
				if not first or into < first.into then
					first = { into = into, minute = cast.minute }
				end
				if not last or into > last.into then
					last = { into = into, minute = cast.minute }
				end
			end
		end
		local span = first and (", realm minutes %s to %s"):format(minuteOfDay(first.minute), minuteOfDay(last.minute))
			or ""
		print(
			("check 4: %s at night (realm %s, the catalogue's night window, DATA-R36)%s"):format(
				many(n, "Cast"),
				table.concat(window, ", "),
				span
			)
		)
	end
	local none, offsets = {}, {}
	for _, cast in ipairs(casts) do
		if cast.minute then
			local offset = ns.RealmUtcOffset(cast.time, cast.minute)
			offsets[offset] = (offsets[offset] or 0) + 1
		else
			none[#none + 1] = cast.seq
		end
	end
	local seqs = #none > 0
			and ", seq " .. table.concat(none, ", ", 1, math.min(#none, 10)) .. (#none > 10 and ", ..." or "")
		or ""
	print(("check 4: %s with no realm minute%s"):format(many(#none, "Cast"), seqs))
	local keys, parts = sortedKeys(offsets), {}
	for i, offset in ipairs(keys) do
		parts[i] = ("%s: %s Casts"):format(utcOffset(offset), thousands(offsets[offset])):gsub(": 1 Casts$", ": 1 Cast")
	end
	local flag = #keys > 1 and ": more than one, so a clock change or a wrong realm minute" or ""
	print(
		("check 4: the realm's UTC offset, from each Cast's realm minute (LOG-R49): %s%s"):format(
			#parts > 0 and table.concat(parts, ", ") or "none",
			flag
		)
	)
end

-- Checks 5 and 7: the diagnostics buffer (LOG-R81): one line per hovered text and locale with its Casts, areas and
-- catches, from the P rows REP-R22 builds (Core's own ns.FieldReportPRows), then each entry whose zone or subzone
-- text didn't resolve (LOG-R22), with its locale.
local function printDiagnostics(global, log, ns)
	local buffer = type(global.diagnostics) == "table" and global.diagnostics or {}
	local locales = {}
	for _, entry in ipairs(buffer) do
		local locale = type(entry) == "table" and tostring(entry.locale) or "?"
		locales[locale] = (locales[locale] or 0) + 1
	end
	local byLocale = {}
	for _, locale in ipairs(sortedKeys(locales)) do
		byLocale[#byLocale + 1] = locale .. " " .. locales[locale]
	end
	print(
		("check 5, 7: the diagnostics buffer (PagleDB.global.diagnostics, LOG-R81): %s%s"):format(
			many(#buffer, "entry", "entries"),
			#byLocale > 0 and ", " .. table.concat(byLocale, ", ") or ""
		)
	)
	local groups, keys = {}, {}
	for _, row in ipairs(pRows(ns, global, log)) do
		local key = tostring(row.locale) .. "\0" .. tostring(row.text)
		local group = groups[key]
		if not group then
			group = { locale = tostring(row.locale), text = tostring(row.text), casts = 0, areas = {}, items = {} }
			groups[key] = group
			keys[#keys + 1] = key
		end
		group.casts = group.casts + row.casts
		group.areas[row.area] = (group.areas[row.area] or 0) + row.casts
		for _, item in ipairs(row.items) do
			group.items[item.item] = (group.items[item.item] or 0) + item.count
		end
	end
	table.sort(keys)
	print(("check 5: hovered texts, as the Field report's P rows group them (REP-R22): %d"):format(#keys))
	for _, key in ipairs(keys) do
		local group = groups[key]
		local areas, items = {}, {}
		for _, area in ipairs(sortedKeys(group.areas)) do
			areas[#areas + 1] = ("%d (%d)"):format(area, group.areas[area])
		end
		for _, item in ipairs(sortedKeys(group.items)) do
			items[#items + 1] = item .. "x" .. group.items[item]
		end
		print(
			('  %s "%s": %s in area %s; %s'):format(
				group.locale,
				group.text,
				many(group.casts, "Cast"),
				table.concat(areas, ", "),
				#items > 0 and table.concat(items, ", ") or "nothing caught"
			)
		)
	end
	local unresolved = {}
	for _, entry in ipairs(buffer) do
		if type(entry) == "table" and type(entry.unresolved) == "table" then
			unresolved[#unresolved + 1] = entry
		end
	end
	print(("check 7: entries whose zone or subzone text didn't resolve (LOG-R22): %d"):format(#unresolved))
	for _, entry in ipairs(unresolved) do
		print(
			('  %s %s: zone "%s", subzone "%s", stored as %s/%s'):format(
				tostring(entry.id),
				tostring(entry.locale),
				tostring(entry.unresolved.zone or ""),
				tostring(entry.unresolved.subzone or ""),
				tostring(entry.zone),
				tostring(entry.subzone)
			)
		)
	end
end

-- Why a stored zone or subzone areaID is flagged for check 6, or nil: zone 0 (unresolved, LOG-R22), an alias source
-- (LOG-R22 maps it to its target, DATA-R32), outside the catalogue's areas, or with no catch data (DATA-R31).
local function areaFlags(areaID, isZone, catalogue)
	if areaID == 0 then
		return isZone and { "zone 0, unresolved (LOG-R22)" } or nil
	end
	if not catalogue then
		return nil
	end
	local flags = {}
	local target = catalogue.Unalias(areaID)
	if target ~= areaID then
		flags[#flags + 1] = ("%d is an alias source of %d, never stored (LOG-R22, DATA-R32)"):format(areaID, target)
	end
	local area = catalogue.GetArea(areaID)
	if not area then
		flags[#flags + 1] = ("%d isn't in the catalogue's areas"):format(areaID)
	elseif area.hasData == false then
		flags[#flags + 1] = ("%d has no catch data (hasData = false, DATA-R31)"):format(areaID)
	end
	return #flags > 0 and flags or nil
end

-- Check 6: the Casts per zone and subzone areaID, each place flagged as areaFlags says.
local function printPlaces(casts, catalogue, label, err)
	local places, keys = {}, {}
	for _, cast in ipairs(casts) do
		local key = cast.zone .. "/" .. cast.subzone
		if not places[key] then
			places[key] = { zone = cast.zone, subzone = cast.subzone, casts = 0 }
			keys[#keys + 1] = key
		end
		places[key].casts = places[key].casts + 1
	end
	table.sort(keys, function(a, b)
		local pa, pb = places[a], places[b]
		if pa.zone ~= pb.zone then
			return pa.zone < pb.zone
		end
		return pa.subzone < pb.subzone
	end)
	local source = catalogue and "catalogue: " .. label or ("can't load %s: %s"):format(label, tostring(err))
	print(("check 6: Casts per zone/subzone areaID (%s):"):format(source))
	local flagged = 0
	for _, key in ipairs(keys) do
		local place = places[key]
		local flags = areaFlags(place.zone, true, catalogue) or {}
		for _, flag in ipairs(areaFlags(place.subzone, false, catalogue) or {}) do
			flags[#flags + 1] = flag
		end
		flagged = flagged + (#flags > 0 and 1 or 0)
		local note = #flags > 0 and "  FLAGGED: " .. table.concat(flags, "; ") or ""
		print(("  %s: %s%s"):format(key, many(place.casts, "Cast"), note))
	end
	print(("check 6: %d of %s flagged"):format(flagged, many(#keys, "place")))
end

-- Prints the Re-verification section (#262): what launch re-verification checks 2, 4-7 and 10 read from the files
-- (roadmap.md › Launch re-verification checklist): PagleLog's entry count and Pagle.lua's size, the load timings
-- (PagleDB.global.probe.timings), the night Casts, the diagnostics buffer's hovered and unresolved texts, and the
-- Casts per place with the flagged ones, over the catalogue (the repo's or --catalogue's).
local function printReverify(pagle, options)
	local global, why = pagleGlobal(pagle)
	if why then
		print("== Re-verification: " .. why)
		return
	end
	print("== Re-verification (launch re-verification checks 2, 4-7 and 10)")
	local log = pagleLog(pagle.saved)
	local size = wtf.fileSize(pagle.path) or 0
	print(
		("check 2: PagleLog %s, Pagle.lua %s bytes (%.2f MiB)"):format(
			log and many(#log.entries, "entry", "entries") or "missing",
			thousands(size),
			size / MIB
		)
	)
	local ns = wtf.loadCore({
		"logic/Conditions.lua",
		"logic/Sessions.lua",
		"logic/CatchLog.lua",
		"logic/FieldReport.lua",
		"logic/LoadTimings.lua",
	})
	printTimings(tableOr(global.probe).timings, ns)
	if not log or log.format ~= ns.LOG_FORMAT then
		print("checks 4-7: no PagleLog Core's codec reads")
		return
	end
	-- Only what checks 4 and 6 read of each Cast, as a large log's records would take a lot of memory.
	local casts = {}
	local catchLog = ns.OpenCatchLog(log, { decodeErrors = 0, sessionBreaks = global.sessionBreaks }, 0)
	for record in catchLog:Iterate() do
		if record.kind == "cast" then
			local c = record.conditions
			casts[#casts + 1] =
				{ seq = record.seq, time = record.time, minute = c.minute, zone = c.zone, subzone = c.subzone }
		end
	end
	local label = options.catalogue or "the repo's addons/Pagle/data/Catalogue.lua"
	local catalogue, err = wtf.loadCatalogue(options.catalogue)
	printNight(casts, catalogue, ns)
	printDiagnostics(global, log, ns)
	printPlaces(casts, catalogue, label, err)
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
	local checks, facts = printCatchLog(pagle, options.expectCasts, options.since)
	printLedger(options.account, pagleLog(pagle.saved), options.catalogue, options.items)
	printHunts(options.account, pagleLog(pagle.saved), options)
	printStats(options.account, pagleLog(pagle.saved), facts, options)
	printBoard(options.account, pagleLog(pagle.saved), facts, options)
	printWallet(pagle, pagleLog(pagle.saved))
	printActivityXP(pagle, pagleLog(pagle.saved))
	printLooks(pagle)
	printDock(pagle)
	printCards(pagle)
	printOnboarding(pagle, pagleLog(pagle.saved))
	printFieldReport(pagle, pagleLog(pagle.saved))
	printProbe(pagle)
	printReverify(pagle, options)
	printCVars(options.account, options.character, options.cvars)
	printAddons(options.account, options.character, options.addons)
	-- Last, so the verdict is the output's last word.
	if options.expectCasts and not printChecks(checks) then
		return 1
	end
	return 0
end

os.exit(main(arg))
