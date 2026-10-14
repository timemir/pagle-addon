-- Makes the test logs the M4 exit check plays (#172, #174; docs/agents/in-game-verification.md): a copy of the
-- dev's SavedVariables/Pagle.lua with PagleLog replaced by a synthetic one a few Catches short of a milestone, so the
-- milestone is reached live in the game. Run it in WSL with the game fully closed.
--
--   lua scripts/make-test-log.lua --account <WTF/Account/<ACCT> folder> --preset <level10|level60|catches1000>
--       [--out <folder>] [--catalogue <Catalogue.lua>]
--   lua scripts/make-test-log.lua --account <folder> --install [--out <folder>]
--   lua scripts/make-test-log.lua --account <folder> --restore [--out <folder>]
--
-- --preset only reads the account folder. It writes a dated stage folder under <out>/<ACCT>/ (--out defaults to
-- ~/pagle-test-logs): original/, a byte-for-byte backup of Pagle.lua, Pagle_Ledger.lua and their .bak, written
-- first, then Pagle.lua, the test log. That Pagle.lua is the backed-up one with only PagleLog replaced: a new logId
-- (LOG-R15), the same characters, the last build entry, each character's last Skill Reading, and Casts of ordinary
-- Species, junk and trophies on the charted zones' lists, one item each, for the character of the dev's last Cast.
-- The entries are written by Core's own codec (addons/Pagle/logic/CatchLog.lua), and the log is folded with the
-- Ledger's own logic/ (listed in Pagle_Ledger.toc) over the catalogue (the repo's generated one, or --catalogue):
-- nothing is written unless the fold lands where the preset says. When a test log is installed, the backup is the
-- one its stage holds, so the real files are never lost between presets.
--
-- --install copies the newest stage's Pagle.lua into the account's SavedVariables, only when the account's Pagle.lua
-- is the one backed up or another test log made here. --restore puts back the backup of the stage whose test log is
-- installed, byte for byte, and removes a file that wasn't there. Both first keep every file they replace in
-- <stage>/replaced-<time>/. These two are the only ones that write under the account folder.
--
-- SavedVariables files are loaded as data: each runs in an empty environment, so it can only assign values, and
-- precompiled chunks are refused. Exits 2 on a usage error, 1 when it refuses (nothing is changed then), else 0.

local USAGE = "usage: lua scripts/make-test-log.lua --account <WTF/Account/<ACCT> folder>"
	.. " (--preset <level10|level60|catches1000> [--catalogue <Catalogue.lua>] | --install | --restore)"
	.. " [--out <folder>]\n"

-- The repo root, from this script's path: Core's and the Ledger's logic/ and the catalogue are read from addons/.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The SavedVariables files backed up and restored, in this order.
local SV_FILES = { "Pagle.lua", "Pagle.lua.bak", "Pagle_Ledger.lua", "Pagle_Ledger.lua.bak" }

-- The test Casts' times: sessions of CASTS_PER_SESSION Casts CAST_GAP seconds apart, starting SESSION_GAP apart,
-- the last one END_GAP before the script runs. Fresh Water refills 10 an hour (LED-R22), so each session starts with
-- enough for all its Catches: every test Catch is doubled, and so is the dev's next one.
local CAST_GAP, CASTS_PER_SESSION, SESSION_GAP, END_GAP = 30, 60, 12 * 3600, 3600

-- How many Catches short of the level a level preset may stop (the ticket's "within three Catches").
local PROBE_CATCHES = 3

-- At most this many Casts in a test log, so a preset that can't land stops.
local MAX_CASTS = 100000

-- The item categories a test Cast may catch: ordinary Species, junk and trophies (LED-R5).
local CATEGORIES = { fish = true, junk = true, trophy = true }

-- The presets: a level preset stops a few Catches short of `level`, a Catches preset at `catches` lifetime Catches.
-- The first Casts discover what the lists hold (each new item and zone earns XP, LED-R20) until the XP reaches
-- `discovery` × the level's cost (or `discoveryXP`); the rest catch those items again for Catch XP only.
local PRESETS = {
	level10 = { level = 10, discovery = 0.5, step = "2" },
	level60 = { level = 60, discovery = 0.3, step = "3" },
	catches1000 = { catches = 995, milestone = "1,000", short = 5, discoveryXP = 8000, step = "5" },
}
local PRESET_NAMES = { "level10", "level60", "catches1000" }

-- Refuses: main prints `reason` and exits 1. Nothing has been changed when this is raised.
local function refuse(reason)
	error({ refused = reason }, 0)
end

local function count(n, noun, plural)
	return n .. " " .. (n == 1 and noun or plural or noun .. "s")
end

local function quote(path)
	return "'" .. path:gsub("'", "'\\''") .. "'"
end

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = {}
	local i = 1
	while args[i] do
		local word, value = args[i], args[i + 1]
		if word == "--account" or word == "--preset" or word == "--out" or word == "--catalogue" then
			if not value then
				return nil, word .. " needs a value"
			end
			options[word:sub(3)] = word == "--preset" and value or value:gsub("[/\\]+$", "")
			i = i + 2
		elseif word == "--install" or word == "--restore" then
			options[word:sub(3)] = true
			i = i + 1
		else
			return nil, "unknown argument " .. word
		end
	end
	if not options.account then
		return nil, "no --account folder"
	end
	local modes = (options.preset and 1 or 0) + (options.install and 1 or 0) + (options.restore and 1 or 0)
	if modes ~= 1 then
		return nil, "name one of --preset, --install and --restore"
	end
	if options.preset and not PRESETS[options.preset] then
		return nil, "no preset " .. options.preset .. "; the presets are " .. table.concat(PRESET_NAMES, ", ")
	end
	if not options.out then
		local home = os.getenv("HOME")
		if not home then
			return nil, "no HOME, so name the test logs' folder with --out"
		end
		options.out = home .. "/pagle-test-logs"
	end
	return options
end

-- Files ------------------------------------------------------------------------------------------------------------

local function readFile(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

-- Writes `text` to `path` and reads it back: raises if the file doesn't hold exactly `text`.
local function writeFile(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
	if readFile(path) ~= text then
		error("wrote " .. path .. " but it doesn't read back the same")
	end
end

local function makeFolder(path)
	if os.execute("mkdir -p " .. quote(path)) ~= 0 then
		error("can't make the folder " .. path)
	end
end

-- The names in a folder, sorted; none when it doesn't exist.
local function listFolder(path)
	local names = {}
	local ls = io.popen("ls -1 " .. quote(path) .. " 2>/dev/null")
	for name in ls:lines() do
		names[#names + 1] = name
	end
	ls:close()
	table.sort(names)
	return names
end

-- Loads a SavedVariables text as data and returns the globals it assigned, or nil and why not.
local function loadData(text, name)
	if text:sub(1, 1) == "\27" then
		return nil, "a precompiled chunk, not data"
	end
	local chunk, loadErr = loadstring(text, "=" .. name)
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

-- Tables ------------------------------------------------------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- The client's SavedVariables layout for one value: no indent, `["key"] = value,` per field, array items followed
-- by `-- [n]`.
local function serialize(value, lines, prefix, suffix)
	local kind = type(value)
	if kind == "table" then
		lines[#lines + 1] = prefix .. "{"
		for i, item in ipairs(value) do
			serialize(item, lines, "", ", -- [" .. i .. "]")
		end
		local keys = {}
		for key in pairs(value) do
			if type(key) ~= "number" or key < 1 or key > #value or key % 1 ~= 0 then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then
				return type(a) == "number"
			end
			return a < b
		end)
		for _, key in ipairs(keys) do
			local name = type(key) == "string" and ("[%q]"):format(key) or ("[%s]"):format(tostring(key))
			serialize(value[key], lines, name .. " = ", ",")
		end
		lines[#lines + 1] = "}" .. suffix
	elseif kind == "string" then
		lines[#lines + 1] = prefix .. ("%q"):format(value):gsub("\\\n", "\\n"):gsub("\r", "\\r") .. suffix
	elseif kind == "number" and value % 1 == 0 and math.abs(value) < 2 ^ 53 then
		lines[#lines + 1] = prefix .. ("%d"):format(value) .. suffix
	elseif kind == "number" then
		lines[#lines + 1] = prefix .. ("%.17g"):format(value) .. suffix
	else
		lines[#lines + 1] = prefix .. tostring(value) .. suffix
	end
end

-- `text`, a SavedVariables file, with the global `name` assigned `value` instead, every other line as it was.
-- Raises a refusal when the file doesn't assign `name` once at the top level.
local function replaceGlobal(text, name, value)
	local eol = text:find("\r\n", 1, true) and "\r\n" or "\n"
	local trailing = text:sub(-#eol) == eol
	local lines = {}
	for line in (trailing and text or text .. eol):gmatch("(.-)" .. eol) do
		lines[#lines + 1] = line
	end
	local first, last
	for i, line in ipairs(lines) do
		local global = line:match("^([%a_][%w_]*) = ")
		if global and first and not last then
			last = i - 1
		end
		if global == name then
			if first then
				refuse("Pagle.lua assigns " .. name .. " twice")
			end
			first = i
		end
	end
	if not first then
		refuse("Pagle.lua has no " .. name .. " = line, so it isn't in the client's layout")
	end
	last = last or #lines
	while last > first and lines[last] == "" do
		last = last - 1
	end
	local replaced = {}
	for i = 1, first - 1 do
		replaced[#replaced + 1] = lines[i]
	end
	serialize(value, replaced, name .. " = ", "")
	for i = last + 1, #lines do
		replaced[#replaced + 1] = lines[i]
	end
	return table.concat(replaced, eol) .. (trailing and eol or "")
end

-- Core and the Ledger -------------------------------------------------------------------------------------------

-- Calls each file with (addon, ns), as the client calls an addon's files, in an environment over the standard
-- globals (logic/ is plain Lua 5.1, CORE-R7) with a Pagle table for the Ledger's CORE-R11 guard.
local function loadFiles(addon, ns, files)
	local env = setmetatable({ Pagle = {} }, { __index = _G })
	for _, file in ipairs(files) do
		local chunk, loadErr = loadfile(file)
		if not chunk then
			return nil, loadErr
		end
		setfenv(chunk, env)
		local ok, runErr = pcall(chunk, addon, ns)
		if not ok then
			return nil, runErr
		end
	end
	return ns
end

-- Core's codec and MatchesConditions, the catalogue's accessors (Core's logic/Catalogue.lua over the catalogue
-- file), and the Ledger's logic/ in Pagle_Ledger.toc order with its world index over that catalogue (LED-R10).
local function loadGame(cataloguePath)
	local core = assert(loadFiles("Pagle", {}, {
		ROOT .. "/addons/Pagle/logic/Conditions.lua",
		ROOT .. "/addons/Pagle/logic/Sessions.lua",
		ROOT .. "/addons/Pagle/logic/CatchLog.lua",
	}))
	local label = cataloguePath or "the repo's addons/Pagle/data/Catalogue.lua"
	local data, err = loadFiles("Pagle", {}, {
		cataloguePath or ROOT .. "/addons/Pagle/data/Catalogue.lua",
		ROOT .. "/addons/Pagle/logic/Catalogue.lua",
	})
	if not data or type(data.catalogue) ~= "table" then
		refuse(("can't load the catalogue %s: %s"):format(label, tostring(err or "it sets no catalogue")))
	end
	local catalogue = data.NewCatalogue(data.catalogue)
	local dir = ROOT .. "/addons/Pagle_Ledger/"
	local files = {}
	for line in assert(io.open(dir .. "Pagle_Ledger.toc")):lines() do
		local file = line:gsub("\r$", ""):match("^%s*(.-)%s*$"):gsub("\\", "/")
		if file:match("^logic/[^/]+%.lua$") then
			files[#files + 1] = dir .. file
		end
	end
	local ledger = assert(loadFiles("Pagle_Ledger", {}, files))
	local world = ledger.NewWorld(catalogue)
	local lookups = { GetItem = catalogue.GetItem, MatchesConditions = core.MatchesConditions, world = world }
	return { core = core, catalogue = catalogue, label = label, ledger = ledger, world = world, lookups = lookups }
end

-- The real log -------------------------------------------------------------------------------------------------

-- What the test log takes from the dev's PagleLog, read with Core's codec: the character of the last Cast and
-- its Skill Reading, the last build, each character's last Skill Reading, the charted zones fished (the latest
-- first), the uiMapID seen in each zone and the realm's UTC offset (LOG-R49).
local function readRealLog(game, log)
	local global = { decodeErrors = 0 }
	local facts = { skills = {}, uiMaps = {}, fished = {}, offset = 0 }
	local casts = {}
	for record in game.core.OpenCatchLog(deepCopy(log), global, 0):Iterate() do
		if record.kind == "cast" then
			casts[#casts + 1] = record
		elseif record.kind == "build" then
			facts.build = record
		elseif record.kind == "skill" then
			facts.skills[record.char] = record
		end
	end
	local last = casts[#casts]
	if not last then
		refuse("PagleLog has no Cast, so there's no character to fish with")
	end
	facts.char = last.char
	facts.skill = facts.skills[last.char]
	if not facts.skill then
		refuse(("PagleLog has no Skill Reading for character %d: log in with it once"):format(last.char))
	end
	local seen = {}
	for i = #casts, 1, -1 do
		local c = casts[i].conditions
		if game.world.zones[c.zone] and not seen[c.zone] then
			seen[c.zone] = true
			facts.fished[#facts.fished + 1] = c.zone
		end
		facts.uiMaps[c.zone] = facts.uiMaps[c.zone] or c.uiMap
		if c.minute and not facts.offsetSet then
			facts.offset, facts.offsetSet = game.ledger.RealmOffset(casts[i].time, c.minute), true
		end
	end
	return facts
end

-- The (zone, item) pairs a test Cast may catch: each charted zone's list entries without a window whose item is an
-- ordinary Species, junk or trophy, never a Legend, Noise, a removed or an Uncharted item; the zones fished first.
local function catchable(game, facts)
	local zones, seen = {}, {}
	for _, zone in ipairs(facts.fished) do
		zones[#zones + 1], seen[zone] = zone, true
	end
	for _, zone in ipairs(game.world.charted) do
		if not seen[zone] then
			zones[#zones + 1] = zone
		end
	end
	local list, taken = {}, {}
	for _, zone in ipairs(zones) do
		for _, entry in ipairs(game.world.zones[zone].list) do
			local item = game.catalogue.GetItem(entry.itemID)
			local key = zone .. ":" .. entry.itemID
			local ordinary = item and CATEGORIES[item.category] and not (item.legend or item.noise or item.removed)
			if ordinary and not entry.window and not taken[key] then
				taken[key] = true
				local subzone = entry.areaID ~= zone and entry.areaID or 0
				list[#list + 1] = { zone = zone, subzone = subzone, itemID = entry.itemID }
			end
		end
	end
	return list
end

-- A caught Cast of one item of `pair` at `time` (catch-log.md › Entry formats), as Core's Append takes it.
local function castRecord(game, facts, pair, time)
	local area = game.catalogue.GetArea(pair.zone)
	return {
		kind = "cast",
		char = facts.char,
		time = time,
		outcome = "caught",
		conditions = {
			minute = (math.floor(time / 60) + facts.offset) % 1440,
			uiMap = facts.uiMaps[pair.zone],
			instance = area and area.continent,
			zone = pair.zone,
			subzone = pair.subzone,
			skillRank = facts.skill.rank,
			skillMod = facts.skill.mod,
			events = {},
			auras = {},
		},
		items = { { itemID = pair.itemID, quantity = 1 } },
	}
end

-- The time of the i-th test Cast (from 0), in seconds after the first.
local function castTime(i)
	return math.floor(i / CASTS_PER_SESSION) * SESSION_GAP + (i % CASTS_PER_SESSION) * CAST_GAP
end

-- A new log with the dev's characters, its build entry and each character's last Skill Reading at `time`.
local function newLog(game, log, facts, time)
	local data = { format = game.core.LOG_FORMAT, characters = deepCopy(log.characters), entries = {} }
	local catchLog = game.core.OpenCatchLog(data, {}, time)
	local header = {}
	if facts.build then
		local build = { kind = "build", char = facts.char, time = time }
		build.build, build.version = facts.build.build, facts.build.version
		header[1] = build
	end
	for char = 1, #log.characters do
		local skill = facts.skills[char]
		if skill then
			header[#header + 1] =
				{ kind = "skill", char = char, time = time, rank = skill.rank, max = skill.max, mod = skill.mod }
		end
	end
	local records = {}
	for i, record in ipairs(header) do
		records[i] = catchLog:Append(record)
	end
	return data, catchLog, records
end

-- The Ledger's level now (LED-R30) and the XP left to the next one, nil at the cap.
local function climb(game, state)
	local level, into, cost = game.ledger.ClimbOf(state.xp, state.prestige)
	return level, cost and cost - into
end

-- How many Catches of `pair` from `time` on, one a CAST_GAP apart, take the state to level `level`: up to
-- PROBE_CATCHES, or nil if they don't. Also the XP the first one gives. The state isn't changed.
local function probe(game, facts, state, pair, time, level)
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local copy = deepCopy(state)
	local scratch = game.core.OpenCatchLog(
		{ format = game.core.LOG_FORMAT, characters = facts.characters, entries = {} },
		{},
		time
	)
	local firstXP
	for n = 1, PROBE_CATCHES do
		local before = copy.xp
		fold.apply(copy, scratch:Append(castRecord(game, facts, pair, time + (n - 1) * CAST_GAP)), "rebuild")
		firstXP = firstXP or copy.xp - before
		if climb(game, copy) >= level then
			return n, firstXP
		end
	end
	return nil, firstXP
end

-- The cost of the climb up to `level` (LED-R30).
local function costTo(game, level)
	local total = 0
	for l = 1, level - 1 do
		total = total + game.ledger.StepCost(l, 0)
	end
	return total
end

-- Plans the test Casts: the pairs they catch, in order, from folding them with the Ledger's own fold as they're
-- added. Times here are only relative; the log is written again at its real times after.
local function plan(game, facts, preset, pairs)
	local fold = game.ledger.NewLedgerFold(game.lookups)
	-- Any time will do for planning: Fresh Water reads only the gaps between Catches (LED-R22).
	local base = 1000000000
	local _, catchLog, header = newLog(game, facts.log, facts, base - 60)
	local state = fold.reset()
	for _, record in ipairs(header) do
		fold.apply(state, record, "rebuild")
	end
	local casts = {}
	local function add(pair)
		fold.apply(state, catchLog:Append(castRecord(game, facts, pair, base + castTime(#casts))), "rebuild")
		casts[#casts + 1] = pair
		if preset.level and climb(game, state) >= preset.level then
			refuse(("the Casts reach level %d before the preset stops; nothing written"):format(preset.level))
		end
		if #casts > MAX_CASTS then
			refuse("the preset doesn't land within " .. MAX_CASTS .. " Casts; nothing written")
		end
	end
	local budget = preset.discoveryXP or preset.discovery * costTo(game, preset.level)
	local used = {}
	for _, pair in ipairs(pairs) do
		if #used > 0 and (state.xp >= budget or (preset.catches and state.catches >= preset.catches)) then
			break
		end
		add(pair)
		used[#used + 1] = pair
	end
	if #used == 0 then
		refuse("no charted zone lists an ordinary Species, junk or trophy item to catch; nothing written")
	end
	local i = 0
	local function done()
		if preset.catches then
			return state.catches >= preset.catches
		end
		return climb(game, state) == preset.level - 1
			and probe(game, facts, state, used[1], base + castTime(#casts - 1) + END_GAP, preset.level) ~= nil
	end
	while not done() do
		i = i % #used + 1
		add(used[i])
	end
	return casts, used[1]
end

-- Checks the written log as the game will read it: decoded with Core's codec and folded with the Ledger's own
-- logic/ from nothing (LED-R3). Returns what it found and the failures (none when the preset landed).
local function check(game, facts, preset, data, probePair, now)
	local global = { decodeErrors = 0 }
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local state = fold.reset()
	local found = { tags = {}, classes = {}, zones = {}, kept = {}, failures = {} }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	for record in game.core.OpenCatchLog(deepCopy(data), global, now):Iterate() do
		found.tags[record.kind] = (found.tags[record.kind] or 0) + 1
		fold.apply(state, record, "rebuild")
		if record.kind == "cast" then
			found.zones[record.conditions.zone] = true
			if record.char ~= facts.char then
				fail("a Cast is on another character")
			end
			for _, catch in ipairs(record.items) do
				local item = game.catalogue.GetItem(catch.itemID)
				local class = game.ledger.ClassifyCatch(catch.itemID, item)
				local kind = item and (class == "curio" and item.category or class) or "Uncharted"
				if not item or item.legend or item.noise or not CATEGORIES[item.category] then
					found.kept[#found.kept + 1] = catch.itemID
				end
				found.classes[kind] = found.classes[kind] or {}
				found.classes[kind][catch.itemID] = true
			end
		end
	end
	if global.decodeErrors > 0 then
		fail(count(global.decodeErrors, "entry", "entries") .. " Core's codec can't decode")
	end
	if #found.kept > 0 then
		fail("a Legend, Noise or Uncharted item is caught: " .. table.concat(found.kept, ", "))
	end
	if not (type(data.logId) == "string" and data.logId:match("^[0-9a-f]+$") and #data.logId == 16) then
		fail("the logId isn't 16 lowercase hex digits")
	elseif data.logId == facts.log.logId then
		fail("the logId is the real log's")
	end
	found.level, found.toNext = climb(game, state)
	found.state = state
	found.catches, found.xp = state.catches, state.xp
	found.needed, found.nextXP = probe(game, facts, state, probePair, now, preset.level or math.huge)
	if preset.level then
		if found.level ~= preset.level - 1 or not found.needed then
			fail(
				("the fold lands at level %d with %s XP to go, not within %d Catches of level %d"):format(
					found.level,
					tostring(found.toNext),
					PROBE_CATCHES,
					preset.level
				)
			)
		end
	elseif found.catches ~= preset.catches then
		fail(("the fold lands at %d lifetime Catches, not %d"):format(found.catches, preset.catches))
	end
	return found
end

-- Stages ---------------------------------------------------------------------------------------------------------

-- The test logs made for the account: each stage folder under `root` with its stage.txt, oldest first.
local function readStages(root)
	local stages = {}
	for _, name in ipairs(listFolder(root)) do
		local dir = root .. "/" .. name
		local text = readFile(dir .. "/stage.txt")
		if text then
			local stage = { name = name, dir = dir }
			for key, value in text:gmatch("(%a+) ([^\n]*)\n") do
				stage[key] = value
			end
			stages[#stages + 1] = stage
		end
	end
	return stages
end

local function stageOfLog(stages, logId)
	for i = #stages, 1, -1 do
		if logId and stages[i].testLogId == logId then
			return stages[i]
		end
	end
	return nil
end

-- PagleLog's logId in a Pagle.lua text, or nil.
local function logIdOf(text)
	local globals = text and loadData(text, "Pagle.lua")
	local log = globals and globals.PagleLog
	return type(log) == "table" and log.logId or nil
end

-- Copies the files in `names` that are in `sv` into a new <stage>/replaced-<time>/ folder; returns it.
local function keepReplaced(stage, sv, names, now)
	local base = stage.dir .. "/replaced-" .. os.date("!%Y%m%d-%H%M%S", now)
	local dir, n = base, 1
	while #listFolder(dir) > 0 or readFile(dir .. "/" .. names[1]) do
		n = n + 1
		dir = base .. "-" .. n
	end
	makeFolder(dir)
	for _, name in ipairs(names) do
		local text = readFile(sv .. "/" .. name)
		if text then
			writeFile(dir .. "/" .. name, text)
		end
	end
	return dir
end

-- The commands that install and restore, for the printed instructions.
local function command(options, mode)
	return ("scripts/make-test-log.sh --account %s %s --out %s"):format(
		quote(options.account),
		mode,
		quote(options.out)
	)
end

local function firstBuildNote()
	print("  Its new logId makes that login a first build: the Ledger empties its celebrated set and writes itself up")
	print("  from the test log in one Write-up, with no moment (LED-R90, LED-R93). Every Catch after it is live.")
end

local function restoreNote(options)
	print("To put the real files back, with the game fully closed:")
	print("  " .. command(options, "--restore"))
	print("  It puts Pagle.lua, Pagle_Ledger.lua and their .bak back byte for byte, so the real log and Ledger return")
	print("  with their own logId and celebrated set, and nothing is written up again.")
end

local function characterName(log, char)
	local c = log.characters[char] or {}
	return table.concat({ tostring(c.name or "?"), c.surname and tostring(c.surname) or nil }, " ")
end

-- Modes ----------------------------------------------------------------------------------------------------------

local function makeTestLog(options, now)
	local preset = PRESETS[options.preset]
	local sv = options.account .. "/SavedVariables"
	local root = options.out .. "/" .. options.account:match("[^/\\]+$")
	local current = readFile(sv .. "/Pagle.lua")
	if not current then
		refuse("no " .. sv .. "/Pagle.lua: log in once with Pagle enabled, then quit the game; nothing written")
	end
	-- When a test log is installed, the real files are in the backup of the stage that made it.
	local stages = readStages(root)
	local installed = stageOfLog(stages, logIdOf(current))
	local sourceDir = installed and installed.dir .. "/original" or sv
	local originals = {}
	for _, name in ipairs(SV_FILES) do
		originals[name] = readFile(sourceDir .. "/" .. name)
	end
	local source, err = loadData(originals["Pagle.lua"], "Pagle.lua")
	if not source then
		refuse("can't read " .. sourceDir .. "/Pagle.lua: " .. tostring(err) .. "; nothing written")
	end
	local log = source.PagleLog
	if type(log) ~= "table" or type(log.characters) ~= "table" or type(log.entries) ~= "table" then
		refuse("Pagle.lua holds no PagleLog with characters and entries; nothing written")
	end
	local game = loadGame(options.catalogue)
	if log.format ~= game.core.LOG_FORMAT then
		refuse(
			("PagleLog is format %s, Core's codec reads %d; nothing written"):format(
				tostring(log.format),
				game.core.LOG_FORMAT
			)
		)
	end
	local facts = readRealLog(game, log)
	facts.log, facts.characters = log, deepCopy(log.characters)

	local casts, probePair = plan(game, facts, preset, catchable(game, facts))
	-- The real log, at real times: the last Cast END_GAP before now.
	math.randomseed(now)
	local first = now - END_GAP - castTime(#casts - 1)
	local data, catchLog = newLog(game, log, facts, first - 60)
	for i, pair in ipairs(casts) do
		catchLog:Append(castRecord(game, facts, pair, first + castTime(i - 1)))
	end
	local found = check(game, facts, preset, data, probePair, now)

	local text = replaceGlobal(originals["Pagle.lua"], "PagleLog", data)
	local written = loadData(text, "Pagle.lua")
	for name, value in pairs(source) do
		if name ~= "PagleLog" and not deepEqual(value, written and written[name]) then
			found.failures[#found.failures + 1] = name .. " doesn't read back as it was"
		end
	end
	if not (written and deepEqual(written.PagleLog, data)) then
		found.failures[#found.failures + 1] = "PagleLog doesn't read back as written"
	end
	if #found.failures > 0 then
		refuse("the test log misses the preset: " .. table.concat(found.failures, "; ") .. "; nothing written")
	end

	local stage = root .. "/" .. os.date("!%Y%m%d-%H%M%S", now) .. "-" .. options.preset
	if readFile(stage .. "/stage.txt") or #listFolder(stage) > 0 then
		refuse(stage .. " already exists; run it again in a second; nothing written")
	end
	-- The backup first, then the test log, then stage.txt, which makes it a stage --install and --restore see.
	makeFolder(stage .. "/original")
	local backedUp, missing = {}, {}
	for _, name in ipairs(SV_FILES) do
		if originals[name] then
			writeFile(stage .. "/original/" .. name, originals[name])
			backedUp[#backedUp + 1] = name
		else
			missing[#missing + 1] = name
		end
	end
	writeFile(stage .. "/Pagle.lua", text)
	writeFile(
		stage .. "/stage.txt",
		("preset %s\ntestLogId %s\noriginalLogId %s\ncharacter %s\n"):format(
			options.preset,
			data.logId,
			tostring(log.logId),
			characterName(log, facts.char)
		)
	)

	local tags = {}
	for _, kind in ipairs({ { "build", "B1" }, { "skill", "S1" }, { "cast", "C1" } }) do
		tags[#tags + 1] = kind[2] .. " " .. (found.tags[kind[1]] or 0)
	end
	local aim = preset.level and ("within %d Catches of level %d"):format(PROBE_CATCHES, preset.level)
		or ("%d Catches short of the %s Catches milestone"):format(preset.short, preset.milestone)
	print(("== Test log %s: %s (M4 exit check step %s)"):format(options.preset, aim, preset.step))
	print(
		("real log: %s/Pagle.lua, logId %s, %s"):format(
			sourceDir,
			tostring(log.logId),
			count(#log.entries, "entry", "entries")
		)
	)
	print(
		("test log: logId %s, %s, %s (%s), the Casts on character %d, %s"):format(
			data.logId,
			count(#data.characters, "character"),
			count(#data.entries, "entry", "entries"),
			table.concat(tags, ", "),
			facts.char,
			characterName(log, facts.char)
		)
	)
	local toNext = found.toNext and (", %d XP to level %d"):format(found.toNext, found.level + 1) or ""
	local reach = found.needed and (", %s reach level %d"):format(count(found.needed, "Catch", "Catches"), preset.level)
		or ""
	print(
		("fold: Angler Level %d, %d XP%s; one more Catch gives %d XP%s; %d lifetime Catches"):format(
			found.level,
			found.xp,
			toNext,
			found.nextXP,
			reach,
			found.catches
		)
	)
	local function items(kind, noun, plural)
		local n = 0
		for _ in pairs(found.classes[kind] or {}) do
			n = n + 1
		end
		return count(n, noun, plural)
	end
	local zones = 0
	for _ in pairs(found.zones) do
		zones = zones + 1
	end
	print(
		("catches: %s, %s, %s, in %s; no Legend, Noise or Uncharted item (catalogue: %s)"):format(
			items("species", "Species item"),
			items("junk", "junk item"),
			items("trophy", "trophy item"),
			count(zones, "zone"),
			game.label
		)
	)
	local none = #missing > 0 and " (there was no " .. table.concat(missing, ", ") .. ")" or ""
	print(("backup: %s/original/ holds %s as they were%s"):format(stage, table.concat(backedUp, ", "), none))
	print(("test log: %s/Pagle.lua, PagleDB and the rest of Pagle.lua as they were"):format(stage))
	print("Nothing under " .. options.account .. " was changed. To play it, with the game fully closed:")
	print("  " .. command(options, "--install"))
	print("  then log in as " .. characterName(log, facts.char) .. ".")
	firstBuildNote()
	restoreNote(options)
	return 0
end

local function install(options, now)
	local sv = options.account .. "/SavedVariables"
	local stages = readStages(options.out .. "/" .. options.account:match("[^/\\]+$"))
	local stage = stages[#stages]
	if not stage then
		refuse("no test log made for " .. options.account .. " in " .. options.out .. "; run --preset first")
	end
	local test = readFile(stage.dir .. "/Pagle.lua")
	local current = readFile(sv .. "/Pagle.lua")
	local currentLogId = logIdOf(current)
	local real = current and current == readFile(stage.dir .. "/original/Pagle.lua")
	local other = stageOfLog(stages, currentLogId)
	if not test then
		refuse(stage.dir .. " holds no Pagle.lua; run --preset again")
	elseif not (real or other) then
		refuse(
			("%s/Pagle.lua (logId %s) isn't the one backed up in %s, nor a test log: it changed since;"):format(
				sv,
				tostring(currentLogId),
				stage.dir
			) .. " run --preset again so the backup is current. Nothing changed"
		)
	end
	local kept = keepReplaced(stage, sv, { "Pagle.lua" }, now)
	writeFile(sv .. "/Pagle.lua", test)
	print(("== Installed test log %s (logId %s) from %s"):format(stage.preset, stage.testLogId, stage.dir))
	local was = real and "the real log, as backed up" or ("test log %s (logId %s)"):format(other.preset, currentLogId)
	print(("the Pagle.lua it replaced, %s, is kept in %s/"):format(was, kept))
	print("Log in as " .. tostring(stage.character) .. ".")
	firstBuildNote()
	restoreNote(options)
	return 0
end

local function restore(options, now)
	local sv = options.account .. "/SavedVariables"
	local stages = readStages(options.out .. "/" .. options.account:match("[^/\\]+$"))
	local current = readFile(sv .. "/Pagle.lua")
	local currentLogId = logIdOf(current)
	local stage = stageOfLog(stages, currentLogId)
	if not stage then
		local newest = stages[#stages]
		local where = newest and "; the newest backup is " .. newest.dir .. "/original/" or ""
		refuse(
			("%s/Pagle.lua %s, not a test log made here, so nothing was restored%s"):format(
				sv,
				current and "holds logId " .. tostring(currentLogId) or "is missing",
				where
			)
		)
	end
	local kept = keepReplaced(stage, sv, SV_FILES, now)
	local done, removed = {}, {}
	for _, name in ipairs(SV_FILES) do
		local original = readFile(stage.dir .. "/original/" .. name)
		if original then
			writeFile(sv .. "/" .. name, original)
			done[#done + 1] = name
		elseif readFile(sv .. "/" .. name) then
			assert(os.remove(sv .. "/" .. name))
			removed[#removed + 1] = name
		end
	end
	print(("== Restored the real files (logId %s) backed up in %s/original/"):format(stage.originalLogId, stage.dir))
	print("put back byte for byte: " .. table.concat(done, ", "))
	if #removed > 0 then
		print("removed, as there was none before: " .. table.concat(removed, ", "))
	end
	print(("the files they replaced (test log %s, logId %s) are kept in %s/"):format(stage.preset, currentLogId, kept))
	print("The next login reads the real log and Ledger as they were.")
	return 0
end

local function main(args)
	if args[1] == "--help" or args[1] == "-h" then
		print(USAGE)
		return 0
	end
	local options, err = parseArgs(args)
	if not options then
		io.stderr:write("make-test-log: " .. err .. "\n" .. USAGE)
		return 2
	end
	local now = os.time()
	local mode = options.preset and makeTestLog or options.install and install or restore
	local ok, result = pcall(mode, options, now)
	if ok then
		return result
	elseif type(result) == "table" and result.refused then
		io.stderr:write("make-test-log: " .. result.refused .. "\n")
		return 1
	end
	error(result, 0)
end

os.exit(main(arg))
