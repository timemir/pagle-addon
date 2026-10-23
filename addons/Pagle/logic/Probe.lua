---@class PagleNS
local ns = select(2, ...)

-- `/pagle dev probe` (#261): reads the client facts launch re-verification checks 3, 8, 11, 12, 16 and 18–21 need
-- (roadmap.md › Launch re-verification checklist), saves them in PagleDB.global.probe and prints one line per check,
-- so on launch day the dev types one command and `/reload`s, and an agent reads every answer from the WTF files
-- (scripts/read-wtf.lua's Probe section, which judges them with ns.ProbeReport below). Pure logic over what it's
-- handed (CORE-R7): every API a check tests is looked up by name in the globals table the adapter hands it (_G), and
-- called under pcall, so the luacheck inventory lists only what Pagle really uses, and a name the client lacks is a
-- miss, never an error. It changes no game state.

--- The checks, in the order they print.
ns.PROBE_CHECKS = { 3, 8, 11, 12, 16, 18, 19, 20, 21 }

--- Nat Pagle's quest, "Nat Pagle, Angler Extreme" (check 8, DATA-R22).
ns.PROBE_QUEST = 6607

--- How long after the probe check 8 reads the quest title again: the server may answer late.
ns.PROBE_QUEST_SECONDS = 2

--- The Fishing spell every rank shares a name and icon with (QOL-R24).
local FISHING = 7620

--- LOG-R66's test vectors: each Catch ID's `h` and its band (check 20).
ns.PROBE_SIZE_VECTORS = {
	{ id = "Player-4395-0A1B2C3D-1791731747-0:1", h = 2657620567, band = 2 },
	{ id = "Player-4395-0A1B2C3D-1791731747-0:2", h = 4227872046, band = 4 },
	{ id = "Player-4395-0A1B2C3D-1791731762-1:1", h = 1190098033, band = 2 },
	{ id = "Player-1-00000001-1700000000-0:1", h = 3063819173, band = 3 },
}

-- The calls that may give a quest's title, tried in order (check 8): the forever dump has the first.
local QUEST_TITLE_CALLS = { "C_QuestLog.GetTitleForQuestID", "C_QuestLog.GetQuestInfo" }
-- The calls that may say whether a spell is known, tried in order (check 21): the forever dump has the first.
local SPELL_KNOWN_CALLS = { "C_SpellBook.IsSpellKnown", "IsPlayerSpell", "IsSpellKnown" }

-- The value at dotted `name` in `globals`, or nil when any part is missing or can't be read. Never raises.
---@param globals table
---@param name string
---@return any
local function resolve(globals, name)
	local value = globals
	for part in name:gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		local ok, field = pcall(function()
			return value[part]
		end)
		if not ok then
			return nil
		end
		value = field
	end
	return value
end

-- A value as saved and shown: a number, string or boolean as it is, anything else as its type, and nil as "nil".
---@param value any
---@return string|number|boolean
local function saveable(value)
	local kind = type(value)
	if kind == "number" or kind == "string" or kind == "boolean" then
		return value
	end
	return kind
end

-- Calls the function at dotted `name` with `...` under pcall. Returns whether the call ran (nil when there's no such
-- function) and its results as { n = count, ... }: the error alone when it raised, none when it's missing.
---@param globals table
---@param name string
---@return boolean? ok
---@return table results
local function call(globals, name, ...)
	local fn = resolve(globals, name)
	if type(fn) ~= "function" then
		return nil, { n = 0 }
	end
	local packed = { n = 0 }
	local function pack(...)
		packed.n = select("#", ...)
		for i = 1, packed.n do
			packed[i] = (select(i, ...))
		end
	end
	pack(pcall(fn, ...))
	local results = { n = packed.n - 1 }
	for i = 2, packed.n do
		results[i - 1] = packed[i]
	end
	return packed[1], results
end

-- The first value a call gives, or nil when it's missing or raised.
---@param globals table
---@param name string
---@return any
local function first(globals, name, ...)
	local ok, results = call(globals, name, ...)
	if ok then
		return results[1]
	end
	return nil
end

-- Results as text: "2, 0.75", each value as tostring gives it.
---@param results table
---@return string
local function resultsText(results)
	local parts = {}
	for i = 1, results.n do
		parts[i] = tostring(saveable(results[i]))
	end
	return table.concat(parts, ", ")
end

-- The sorted keys of a table.
---@param t table
---@return string[]
local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = tostring(key)
	end
	table.sort(keys)
	return keys
end

--- The player channels named Fishing seen while dev mode is on (check 21, LOG-R2), in or out of the fishing-spell
--- list, each with a count. Kept for the login session, never saved: the probe saves them.
---@class PagleProbeChannels
---@field package counts table<integer, integer>
local Channels = {}
Channels.__index = Channels

---@return PagleProbeChannels
function ns.NewProbeChannels()
	return setmetatable({ counts = {} }, Channels)
end

--- Notes a player channel of `spellID`, named `name`, when that's the Fishing spell's name `fishingName`.
---@param spellID integer?
---@param name any
---@param fishingName any
function Channels:Note(spellID, name, fishingName)
	if spellID and type(name) == "string" and name == fishingName then
		self.counts[spellID] = (self.counts[spellID] or 0) + 1
	end
end

--- The spell IDs seen, ascending, each with its count and whether `isListed` says it's on the fishing-spell list.
---@param isListed fun(spellID: integer): boolean
---@return { id: integer, count: integer, listed: boolean }[]
function Channels:List(isListed)
	local ids = {}
	for id in pairs(self.counts) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	local list = {}
	for i, id in ipairs(ids) do
		list[i] = { id = id, count = self.counts[id], listed = isListed(id) }
	end
	return list
end

--- What the probe is handed besides the client's globals.
---@class PagleProbeFacts
---@field inventory string[]                 -- ns.API_INVENTORY (check 11)
---@field fishingSpells integer[]            -- the catalogue's fishing-spell list (check 21, DATA-R39)
---@field channels { id: integer, count: integer, listed: boolean }[] -- the Fishing channels seen (check 21, LOG-R2)
---@field sizeHash fun(catchId: string): integer -- Core's LOG-R66 hash (check 20)
---@field sizeBand fun(catchId: string): integer -- the band of its percentile (LOG-R67)
---@field isForever fun(projectID: any, camelotID: any): boolean -- CORE-R4's check

-- The checks, each reading `globals`, by number.
local READ = {}

-- Check 3: every key of C_Weather, every value GetCurrentWeather returns, and the zone (LOG-R21).
READ[3] = function(globals)
	local weather = resolve(globals, "C_Weather")
	local check = { exists = type(weather) == "table", zone = saveable(first(globals, "GetRealZoneText")) }
	check.map = saveable(first(globals, "C_Map.GetBestMapForUnit", "player"))
	if check.exists then
		check.keys = sortedKeys(weather)
		local ok, results = call(globals, "C_Weather.GetCurrentWeather")
		if ok ~= nil then
			check.call = ok and resultsText(results) or ("error: " .. tostring(results[1]))
			check.values = {}
			for i = 1, ok and results.n or 0 do
				check.values[i] = saveable(results[i])
			end
		end
	end
	return check
end

-- Check 8: quest 6607's title from the quest-title call the client has, asked for first (DATA-R22). The second read
-- is ns.ProbeQuestAgain's.
READ[8] = function(globals)
	call(globals, "C_QuestLog.RequestLoadQuestByID", ns.PROBE_QUEST)
	for _, name in ipairs(QUEST_TITLE_CALLS) do
		if type(resolve(globals, name)) == "function" then
			local title = first(globals, name, ns.PROBE_QUEST)
			if type(title) == "table" then -- GetQuestInfo's QuestInfo
				title = title.title
			end
			return { call = name, first = type(title) == "string" and title ~= "" and title or nil }
		end
	end
	return {}
end

-- Check 11: every inventoried name (.luacheckrc's stds.wow and stds.wow_variables) that's nil here.
READ[11] = function(globals, facts)
	local missing = {}
	for _, name in ipairs(facts.inventory) do
		if resolve(globals, name) == nil then
			missing[#missing + 1] = name
		end
	end
	return { checked = #facts.inventory, missing = missing }
end

-- Check 12: GetBuildInfo, the project IDs, and CORE-R4's check (CORE-R2, CORE-R4).
READ[12] = function(globals, facts)
	local projectID, camelotID = resolve(globals, "WOW_PROJECT_ID"), resolve(globals, "WOW_PROJECT_CAMELOT")
	return {
		projectId = saveable(projectID),
		camelot = saveable(camelotID),
		forever = facts.isForever(projectID, camelotID),
	}
end

-- Check 16: the equipment-set limit and the character's sets (QOL-R42, QOL-R103).
READ[16] = function(globals)
	local check = { max = saveable(resolve(globals, "MAX_EQUIPMENT_SETS_PER_PLAYER")), sets = {} }
	local ids = first(globals, "C_EquipmentSet.GetEquipmentSetIDs")
	for _, id in ipairs(type(ids) == "table" and ids or {}) do
		check.sets[#check.sets + 1] = saveable(first(globals, "C_EquipmentSet.GetEquipmentSetInfo", id))
	end
	return check
end

-- Check 18: the reset calls, beside the server time, the realm time and the day start TKB-R11's fallback would give:
-- `now − (realm minute × 60) − (now mod 60)`.
READ[18] = function(globals)
	local check = {}
	for key, name in pairs({ daily = "GetSecondsUntilDailyReset", weekly = "GetSecondsUntilWeeklyReset" }) do
		check[key .. "Exists"] = type(resolve(globals, "C_DateAndTime." .. name)) == "function"
		local value = first(globals, "C_DateAndTime." .. name)
		check[key] = value ~= nil and saveable(value) or nil
	end
	local now = first(globals, "GetServerTime")
	local ok, results = call(globals, "GetGameTime")
	check.serverTime = saveable(now)
	if ok and type(results[1]) == "number" and type(results[2]) == "number" then
		local hour, minute = results[1], results[2]
		check.gameTime = ("%d:%02d"):format(hour, minute)
		if type(now) == "number" then
			check.fallbackDayStart = now - (hour * 60 + minute) * 60 - now % 60
		end
	end
	return check
end

-- Check 19: GetCurrentRegion (LOG-R69).
READ[19] = function(globals)
	local exists = type(resolve(globals, "GetCurrentRegion")) == "function"
	return { exists = exists, region = exists and saveable(first(globals, "GetCurrentRegion")) or nil }
end

-- Check 20: the `bit` library, and Core's hash and band of each LOG-R66 vector.
READ[20] = function(globals, facts)
	local check = { bit = type(resolve(globals, "bit")) == "table", vectors = {} }
	for i, vector in ipairs(ns.PROBE_SIZE_VECTORS) do
		local hashed, h = pcall(facts.sizeHash, vector.id)
		local banded, band = pcall(facts.sizeBand, vector.id)
		check.vectors[i] = { h = hashed and h or "error", band = banded and band or "error" }
	end
	return check
end

-- Check 21: each listed fishing spell's name, icon and whether it's known, beside 7620's; the channels seen (DATA-R39,
-- LOG-R2, QOL-R24, QOL-R71).
READ[21] = function(globals, facts)
	local check = {
		reference = {
			name = saveable(first(globals, "C_Spell.GetSpellName", FISHING)),
			icon = saveable(first(globals, "C_Spell.GetSpellTexture", FISHING)),
		},
		spells = {},
		channels = facts.channels,
	}
	for _, name in ipairs(SPELL_KNOWN_CALLS) do
		if type(resolve(globals, name)) == "function" then
			check.knownCall = name
			break
		end
	end
	for i, id in ipairs(facts.fishingSpells) do
		check.spells[i] = {
			id = id,
			name = saveable(first(globals, "C_Spell.GetSpellName", id)),
			icon = saveable(first(globals, "C_Spell.GetSpellTexture", id)),
			known = check.knownCall and saveable(first(globals, check.knownCall, id)) or nil,
		}
	end
	return check
end

--- The probe: every check's facts read from `globals` (the client's _G), with the server time, GetBuildInfo and
--- GetLocale. Check 8's second read is ns.ProbeQuestAgain's.
---@param globals table
---@param facts PagleProbeFacts
---@return table probe what PagleDB.global.probe holds
function ns.ReadProbe(globals, facts)
	local ok, build = call(globals, "GetBuildInfo")
	build = ok and build or {}
	local probe = {
		time = saveable(first(globals, "GetServerTime")),
		build = {
			version = saveable(build[1]),
			build = saveable(build[2]),
			date = saveable(build[3]),
			interface = saveable(build[4]),
		},
		locale = saveable(first(globals, "GetLocale")),
		checks = {},
	}
	for _, n in ipairs(ns.PROBE_CHECKS) do
		probe.checks[n] = READ[n](globals, facts)
	end
	return probe
end

--- Check 8's second read: the quest title again, by the call the first read used.
---@param probe table
---@param globals table
function ns.ProbeQuestAgain(probe, globals)
	local check = probe.checks[8]
	if check.call then
		local title = first(globals, check.call, ns.PROBE_QUEST)
		if type(title) == "table" then
			title = title.title
		end
		check.later = type(title) == "string" and title ~= "" and title or nil
		check.laterRead = true
	end
end

-- A list as "a, b, c", or "none".
---@param items any[]
---@return string
local function listText(items)
	local parts = {}
	for i, item in ipairs(items or {}) do
		parts[i] = tostring(item)
	end
	return #parts > 0 and table.concat(parts, ", ") or "none"
end

-- A title as `"…"`, or "none".
local function titleText(title)
	return title and ('"%s"'):format(title) or "none"
end

-- The report of each check: { summary, details, verdicts }. Each reads a stored check, which may come from an older
-- probe or be missing a key, so none assumes a field is there.
local REPORT = {}

REPORT[3] = function(check)
	if not check.exists then
		return "C_Weather is missing", {}, { { false, "no C_Weather: LOG-R21 keeps weather unrecorded" } }
	end
	local zone = ("%s"):format(tostring(check.zone))
	local summary = ("C_Weather keys %s; GetCurrentWeather() = %s in %s"):format(
		listText(check.keys),
		check.call or "missing",
		zone
	)
	local details = { ("zone %s, map %s"):format(zone, tostring(check.map)) }
	local reported = false
	for _, value in ipairs(check.values or {}) do
		if value ~= 0 and value ~= false and value ~= "nil" then
			reported = true
		end
	end
	if reported then
		return summary, details, { { true, "weather reported: LOG-R21 may record it" } }
	end
	return summary,
		details,
		{ { false, "only zeros or nothing: probe again while it rains; LOG-R21 keeps weather unrecorded" } }
end

REPORT[8] = function(check)
	if not check.call then
		return "no quest-title call (" .. table.concat(QUEST_TITLE_CALLS, ", ") .. ")",
			{},
			{ { false, "no quest-title call: DATA-R22 keeps Nat Pagle's quest fish out of the Legends" } }
	end
	local summary = ("quest %d by %s: %s at once, %s"):format(
		ns.PROBE_QUEST,
		check.call,
		titleText(check.first),
		check.laterRead and titleText(check.later) .. " 2 s later" or "not read again yet"
	)
	if check.first or check.later then
		return summary, {}, { { true, "quest 6607 exists: DATA-R22 may make Nat Pagle's quest fish Legends" } }
	end
	return summary,
		{},
		{ { false, "no title for quest 6607: DATA-R22 keeps Nat Pagle's quest fish out of the Legends" } }
end

REPORT[11] = function(check)
	local missing = check.missing or {}
	local summary = ("%s inventory names checked, %d missing"):format(tostring(check.checked), #missing)
	if #missing == 0 then
		return summary, {}, { { true, "every inventoried name exists" } }
	end
	return summary .. ": " .. listText(missing),
		{},
		{
			{
				false,
				("%s missing: each rule that uses them changes (CORE-R23)"):format(listText(missing)),
			},
		}
end

REPORT[12] = function(check, probe)
	local build = probe.build or {}
	local summary = ("GetBuildInfo() = %s, %s, %s, %s; WOW_PROJECT_ID %s, WOW_PROJECT_CAMELOT %s"):format(
		tostring(build.version),
		tostring(build.build),
		tostring(build.date),
		tostring(build.interface),
		tostring(check.projectId),
		tostring(check.camelot)
	)
	if check.forever then
		return summary, {}, { { true, "CORE-R4's check passes" } }
	end
	return summary,
		{},
		{ { false, "CORE-R4's check fails: WOW_PROJECT_ID isn't WOW_PROJECT_CAMELOT (CORE-R2, CORE-R4)" } }
end

REPORT[16] = function(check)
	local sets = check.sets or {}
	local summary = ("MAX_EQUIPMENT_SETS_PER_PLAYER = %s; %d %s: %s"):format(
		tostring(check.max),
		#sets,
		#sets == 1 and "set" or "sets",
		listText(sets)
	)
	if type(check.max) ~= "number" then
		return summary,
			{},
			{ { false, "no MAX_EQUIPMENT_SETS_PER_PLAYER: QOL-R42 can't count free slots (QOL-R42, QOL-R103)" } }
	end
	return summary,
		{},
		{
			{
				true,
				("%d free of %d: QOL-R42 needs 2, for Pagle Fishing and Pagle Previous (QOL-R103)"):format(
					check.max - #sets,
					check.max
				),
			},
		}
end

REPORT[18] = function(check)
	local function value(key, name)
		if not check[key .. "Exists"] then
			return name .. " is missing"
		end
		return ("%s() = %s"):format(name, tostring(check[key]))
	end
	local summary = ("%s, %s; GetServerTime() = %s, GetGameTime() = %s; TKB-R11's fallback day starts at %s"):format(
		value("daily", "GetSecondsUntilDailyReset"),
		value("weekly", "GetSecondsUntilWeeklyReset"),
		tostring(check.serverTime),
		tostring(check.gameTime),
		tostring(check.fallbackDayStart)
	)
	local verdicts = {}
	for key, name in pairs({ daily = "GetSecondsUntilDailyReset", weekly = "GetSecondsUntilWeeklyReset" }) do
		local answer = check[key]
		if not check[key .. "Exists"] then
			verdicts[#verdicts + 1] = { false, name .. " is missing: TKB-R11's fallback runs (TKB-R10, TKB-R11)" }
		elseif type(answer) ~= "number" or answer <= 0 then
			verdicts[#verdicts + 1] =
				{ false, name .. " gives no time left: TKB-R11's fallback runs (TKB-R10, TKB-R11)" }
		end
	end
	table.sort(verdicts, function(a, b)
		return a[2] < b[2]
	end)
	if #verdicts == 0 then
		verdicts[1] = { true, "both reset calls answer: TKB-R10 holds" }
	end
	return summary, {}, verdicts
end

REPORT[19] = function(check)
	if not check.exists then
		return "GetCurrentRegion is missing",
			{},
			{ { false, "no GetCurrentRegion: LOG-R69's default length unit is always cm" } }
	end
	return ("GetCurrentRegion() = %s"):format(tostring(check.region)),
		{},
		{ { true, "LOG-R69's default length unit reads the region" } }
end

REPORT[20] = function(check)
	local matched, details, verdicts = 0, {}, {}
	for i, vector in ipairs(ns.PROBE_SIZE_VECTORS) do
		local got = (check.vectors or {})[i] or {}
		local same = got.h == vector.h and got.band == vector.band
		matched = matched + (same and 1 or 0)
		details[i] = ("%s: h %s band %s, LOG-R66 says h %d band %d"):format(
			vector.id,
			tostring(got.h),
			tostring(got.band),
			vector.h,
			vector.band
		)
		if not same then
			verdicts[#verdicts + 1] = { false, details[i] }
		end
	end
	local summary = ("bit %s; %d of %d LOG-R66 vectors match"):format(
		check.bit and "is there" or "is missing",
		matched,
		#ns.PROBE_SIZE_VECTORS
	)
	if not check.bit then
		table.insert(verdicts, 1, { false, "no bit library: LOG-R66's Simulated Size hash can't run" })
	end
	if #verdicts == 0 then
		verdicts[1] = { true, "bit is there and every LOG-R66 vector matches" }
	end
	return summary, details, verdicts
end

REPORT[21] = function(check)
	local reference = check.reference or {}
	local known, details, verdicts = {}, {}, {}
	for _, spell in ipairs(check.spells or {}) do
		if spell.known == true then
			known[#known + 1] = spell.id
		end
		details[#details + 1] = ("spell %s: %s, icon %s, known %s"):format(
			tostring(spell.id),
			tostring(spell.name),
			tostring(spell.icon),
			tostring(spell.known)
		)
		if spell.name ~= reference.name then
			verdicts[#verdicts + 1] = { false, ("%s's name isn't 7620's (DATA-R39, QOL-R24)"):format(spell.id) }
		end
		if spell.icon ~= reference.icon then
			verdicts[#verdicts + 1] = { false, ("%s's icon isn't 7620's (DATA-R39, QOL-R71)"):format(spell.id) }
		end
	end
	local seen = {}
	for _, channel in ipairs(check.channels or {}) do
		seen[#seen + 1] = ("%s x%s"):format(tostring(channel.id), tostring(channel.count))
		if not channel.listed then
			verdicts[#verdicts + 1] = {
				false,
				("channel %s isn't on the fishing-spell list (LOG-R2, DATA-R39, QOL-R22)"):format(channel.id),
			}
		end
	end
	if #seen == 0 then
		verdicts[#verdicts + 1] =
			{ false, "no Fishing channel seen with dev mode on: fish once, then probe again (LOG-R2, DATA-R39)" }
	end
	local summary = ("7620 is %s, icon %s; %d listed spells, known %s (by %s); channels seen %s"):format(
		titleText(type(reference.name) == "string" and reference.name or nil),
		tostring(reference.icon),
		#(check.spells or {}),
		listText(known),
		tostring(check.knownCall or "no known-spell call"),
		listText(seen)
	)
	if #verdicts == 0 then
		verdicts[1] = { true, "every listed spell has 7620's name and icon, and every Fishing channel seen is listed" }
	end
	return summary, details, verdicts
end

--- One check's report.
---@class PagleProbeCheckReport
---@field check integer
---@field summary string            -- the facts in one line, as chat shows them
---@field details string[]          -- the facts in full, line by line
---@field verdicts { [1]: boolean, [2]: string }[] -- each ok or miss, naming the rule a miss changes

--- Judges a stored probe against what the spec expects (roadmap.md's checklist, its right-hand column naming the rule
--- a miss changes): one report per check, in ns.PROBE_CHECKS' order. The game's chat lines and scripts/read-wtf.lua's
--- Probe section both read it.
---@param probe table PagleDB.global.probe
---@return PagleProbeCheckReport[]
function ns.ProbeReport(probe)
	local reports = {}
	for _, n in ipairs(ns.PROBE_CHECKS) do
		local check = (probe.checks or {})[n]
		if type(check) == "table" then
			local summary, details, verdicts = REPORT[n](check, probe)
			reports[#reports + 1] = { check = n, summary = summary, details = details, verdicts = verdicts }
		else
			reports[#reports + 1] =
				{ check = n, summary = "not in this probe", details = {}, verdicts = { { false, "not probed" } } }
		end
	end
	return reports
end

--- A check's chat line: its facts, and the first miss if it has one.
---@param report PagleProbeCheckReport
---@return string
function ns.ProbeLine(report)
	local line = ("probe %d: %s"):format(report.check, report.summary)
	for _, verdict in ipairs(report.verdicts) do
		if not verdict[1] then
			return line .. "; FAIL: " .. verdict[2]
		end
	end
	return line
end

--- What `/pagle dev probe` runs on.
---@class PagleProbeOptions
---@field globals fun(): table         -- the client's globals (_G), where every API a check tests is looked up
---@field global fun(): table          -- PagleDB.global, which keeps the probe
---@field facts fun(): PagleProbeFacts -- what the probe is handed besides the globals
---@field after fun(seconds: number, fn: fun())
---@field print fun(line: string)      -- prints a chat line

--- Runs `/pagle dev probe`: reads and saves the probe at once (replacing the last one, but keeping its load timings,
--- #262), then 2 s later reads check
--- 8's quest title again, saves that too, and prints one line per check and the saved line. The lines wait for the
--- second read, so the saved line is the last word.
---@param options PagleProbeOptions
function ns.RunProbe(options)
	local L, globals = ns.L, options.globals()
	local probe = ns.ReadProbe(globals, options.facts())
	-- This login's load timings (#262, logic/LoadTimings.lua) stay: they aren't the probe's to replace.
	local last = options.global().probe
	probe.timings = type(last) == "table" and last.timings or nil
	options.global().probe = probe
	options.after(ns.PROBE_QUEST_SECONDS, function()
		ns.ProbeQuestAgain(probe, globals)
		for _, report in ipairs(ns.ProbeReport(probe)) do
			options.print(L.DEV_PROBE_LINE:format(ns.ProbeLine(report)))
		end
		options.print(L.DEV_PROBE_SAVED)
	end)
end
