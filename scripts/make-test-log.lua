-- Makes the test logs the M4, M7 and M8 exit checks play (#172, #174, #243, #310; docs/agents/in-game-verification.md):
-- a copy of the dev's SavedVariables/Pagle.lua with PagleLog replaced by a synthetic one a few Catches short of a level
-- or a Catch Milestone, so it is reached live in the game, or (boardday) holding a Tackle Board started two board days
-- ago with a goal done on its first day and nothing on its second, so the next login closes the unlit day, or (wagers)
-- the last fallback slot's run settled and the current slot's not logged, so the next login puts the current one on.
-- Run it in WSL with the game fully closed.
--
--   lua scripts/make-test-log.lua --account <WTF/Account/<ACCT> folder>
--       --preset <level10|level60|catches1000|boardday|big5|big20|showcase|wagers|veteran> [--out <folder>]
--       [--catalogue <Catalogue.lua>] [--huntlist <HuntList.lua>] [--eventlist <EventList.lua>]
--   lua scripts/make-test-log.lua --account <folder> --install [--out <folder>]
--   lua scripts/make-test-log.lua --account <folder> --restore [--out <folder>]
--
-- --preset only reads the account folder. It writes a dated stage folder under <out>/<ACCT>/ (--out defaults to
-- ~/pagle-test-logs): original/, a byte-for-byte backup of every Pagle addon's SavedVariables file and .bak there is
-- (SV_FILES), written first, then Pagle.lua, the test log. That Pagle.lua is the backed-up one with only PagleLog
-- replaced: a new logId (LOG-R15), `test = true` (a test log, catch-log.md › Data, so /pagle dev catch appends on
-- it), the same characters, the last build entry, each character's last Skill Reading, and Casts of ordinary Species,
-- junk and trophies on the charted zones' lists, one item each, for the character of the dev's last Cast.
-- The entries are written by Core's own codec (addons/Pagle/logic/CatchLog.lua), which sizes each Species Catch with
-- Core's logic/Size.lua (LOG-R65), and the log is folded with the Ledger's own logic/ (listed in Pagle_Ledger.toc)
-- over the catalogue (the repo's generated one, or --catalogue): nothing is written unless the fold lands where the
-- preset says. When a test log is installed, the backup is the one its stage holds, so the real files are never lost
-- between presets.
--
-- boardday (#243) needs a started board: it takes the reset time of day from the dev's latest Tackle Board `start` or
-- `day` record (refusing without one, or when it is older than a week) and writes, with the Tackle Board's own record
-- encoder (logic/Records.lua), a `start` record two board days before the current one, an Expedition and three
-- Notices, one a Haul Notice in a charted zone, then on that first day just the Casts the Haul Notice needs. It folds
-- the log with the Tackle Board's own logic/ (listed in Pagle_TackleBoard.toc) and writes nothing unless day 0 is lit
-- by that Notice alone and, advanced to today, day 1 burns a Kindling.
--
-- big5 and big20 (#262) write a large log for launch re-verification checks 2 and 10 (the load and rebuild times of
-- a 5 MB and a 20 MB PagleLog): a Pagle.lua of about 5 or 20 MiB, its PagleLog real-looking Casts written by Core's
-- codec, sessions of every character in turn, in each charted zone in turn, over several months up to an hour
-- before the run, one Cast in BIG_AWAY got away. They're checked by decoding, not folded: no level to land.
--
-- showcase writes as much as the books can show at once, for an in-game look-and-feel check: a Tackle Board started
-- SHOWCASE_LIT + #SHOWCASE_UNLIT - 1 board days before its last lit day (today's, or yesterday's when today's began
-- too late), on the dev's reset time as boardday takes it. Each lit day the live step's records come first (`start`
-- or `day`, the goals owed, each drawn by the board's own logic/Generate.lua until it is one Casts can complete), then
-- the Casts that complete its Notices and work its Expedition, and a session in the next zone in turn; the unlit days
-- hold nothing, so each burns a Kindling. A Prestige entry follows the day the climb reaches 60. Folded with the
-- Ledger's and the Tackle Board's own logic/, it is written only when the Campfire is at least SHOWCASE_FIRE days, the
-- last lit day is the board's day, Kindling is held and SHOWCASE_COINS Coins are earned in all.
--
-- wagers (#310) writes the fallback slot before the current one played to completion, for M8 exit check step 7: Hunts'
-- own logic/Rotation.lua over the event pool (the repo's data/EventList.lua, or --eventlist; the Hunt list's classes
-- from data/HuntList.lua, or --huntlist) gives the slot and its pick, and refuses in slot 0, before the origin or with
-- an empty pool. After the header comes that slot's `run` record (Hunts' own logic/Records.lua, source `r`) an hour
-- into it, then caught Casts in the event's zones until every Hunt of it reaches tier 1, nothing after the slot's end.
-- Folded with Hunts' own logic/ (listed in Pagle_Hunts.toc), it is written only when that run is the one known run,
-- completed, `settled` is 1 and no run is on now, so the login's live step logs the current slot's run (HNT-R151).
--
-- veteran writes a seasoned account to play as: three weeks of sessions across the charted zones (the standing Hunts
-- move on from them), three Prestige entries, the last fallback slot's run settled as wagers plays it and the current
-- slot's run logged and part played, so it is on at the next login. Its Prestiges are honest through the test-log
-- grants (catch-log.md › Test logs): `devXP` gives each one's snapshot (AXP-R5) a full climb's Activity XP, and
-- `devCoins` tops the balance up to VETERAN_COINS. Folded with the Ledger's and Hunts' own logic/, it is written only
-- when the Ledger is at Prestige 3 below level 60, a standing Hunt has a tier, the old run is settled and the current
-- one is on.
--
-- --install copies the newest stage's Pagle.lua into the account's SavedVariables, only when the account's Pagle.lua
-- is the one backed up or another test log made here (a boardday one only before its board day ends, as the next
-- reset would close day 2 unlit too, and a wagers one only before its current fallback slot ends). --restore puts back
-- the backup of the stage whose test log is installed, byte for byte, and removes a file that wasn't there. Both first
-- keep every file they replace in <stage>/replaced-<time>/. These two are the only ones that write under the account
-- folder.
--
-- SavedVariables files are loaded as data: each runs in an empty environment, so it can only assign values, and
-- precompiled chunks are refused. Exits 2 on a usage error, 1 when it refuses (nothing is changed then), else 0.

local USAGE = "usage: lua scripts/make-test-log.lua --account <WTF/Account/<ACCT> folder>"
	.. " (--preset <level10|level60|catches1000|boardday|big5|big20|showcase|wagers|veteran> [--catalogue <Catalogue.lua>]"
	.. " [--huntlist <HuntList.lua>] [--eventlist <EventList.lua>] | --install | --restore)"
	.. " [--out <folder>]\n"

-- The repo root, from this script's path: Core's, the Ledger's and the Tackle Board's logic/ and the catalogue are
-- read from addons/.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The helpers this script shares with scripts/read-wtf.lua, in this script's environment.
local wtf = setfenv(assert(loadfile(ROOT .. "/scripts/lib/wtf.lua")), getfenv(1))(ROOT)
local count, quote, readFile, writeFile, listFolder = wtf.count, wtf.quote, wtf.readFile, wtf.writeFile, wtf.listFolder
local loadData, characterName = wtf.loadSavedVariables, wtf.characterName

-- A server time as a UTC date and time, to the minute.
local function utc(t)
	return os.date("!%Y-%m-%d %H:%M UTC", t)
end

-- The SavedVariables files backed up and restored, in this order: every Pagle addon's file and its .bak, Core's,
-- the Ledger's and QoL's, and the Modules' that ship later, so a test play leaves none of them changed.
local SV_FILES = {}
for _, addon in ipairs({ "Pagle", "Pagle_Ledger", "Pagle_QoL", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard" }) do
	SV_FILES[#SV_FILES + 1] = addon .. ".lua"
	SV_FILES[#SV_FILES + 1] = addon .. ".lua.bak"
end

-- The test Casts' times: sessions of CASTS_PER_SESSION Casts CAST_GAP seconds apart, starting SESSION_GAP apart,
-- the last one END_GAP before the script runs. Fresh Water refills 10 an hour (LED-R22), so each session starts with
-- enough for all its Catches: every test Catch is doubled, and so is the dev's next one.
local CAST_GAP, CASTS_PER_SESSION, SESSION_GAP, END_GAP = 30, 60, 12 * 3600, 3600

-- How many Catches short of the level a level preset may stop (the ticket's "within three Catches").
local PROBE_CATCHES = 3

-- At most this many Casts in a test log, so a preset that can't land stops. The big presets are sized by bytes, not
-- landed, so this doesn't hold for them (BIG_MAX_CASTS does).
local MAX_CASTS = 100000

-- The big presets (#262): the Casts span about BIG_SPAN seconds (several months, longer if the sessions need it),
-- one in BIG_AWAY got away, and at most BIG_MAX_CASTS. The size is MiB, as the client's file browser shows it, and
-- the written Pagle.lua must be within BIG_TOLERANCE of it.
local BIG_SPAN, BIG_AWAY, BIG_MAX_CASTS, BIG_TOLERANCE = 120 * 86400, 8, 1000000, 0.1
local MIB = 1024 * 1024

-- Lua 5.1 keeps at most this many distinct constants in one function: a SavedVariables file with more distinct
-- strings than this can't be loaded in one piece ("constant table overflow").
local LUA_CONSTANTS = 262143

-- What a test Cast may catch, by the kind the Ledger's own ClassifyCatch gives it (a curio by its category): an
-- ordinary Species, junk or trophy (LED-R5), never a Legend, Noise, an Uncharted item, a container or treasure.
local ORDINARY = { species = true, junk = true, trophy = true }

-- The presets: a level preset stops a few Catches short of `level`, a Catches preset at `catches` lifetime Catches,
-- `short` of the `milestone`-Catch Catch Milestone (LED-R42). The first Casts discover what the lists hold (each new
-- item and zone earns XP, LED-R20) until the XP reaches `discovery` × the level's cost (or `discoveryXP`); the rest
-- catch those items again for Catch XP only.
-- boardday writes a started Tackle Board instead (#243).
local PRESETS = {
	level10 = { level = 10, discovery = 0.5, check = "M4", step = "2" },
	level60 = { level = 60, discovery = 0.3, check = "M4", step = "3" },
	catches1000 = { catches = 995, milestone = "1,000", short = 5, discoveryXP = 8000, check = "M4", step = "5" },
	boardday = { board = true, check = "M7", step = "5" },
	-- #262: launch re-verification checks 2 and 10 (roadmap.md › Launch re-verification checklist).
	big5 = { bytes = 5 * MIB, checks = "M8 launch re-verification checks 2 and 10" },
	big20 = { bytes = 20 * MIB, checks = "M8 launch re-verification checks 2 and 10" },
	-- The in-game look-and-feel check: a lit Campfire of SHOWCASE_FIRE days or more and Coins to spend.
	showcase = { showcase = true, checks = "the in-game look-and-feel check" },
	-- #310: the last fallback slot's run played to completion, the current slot left unlogged.
	wagers = { wagers = true, check = "M8", step = "7" },
	-- A seasoned Angler to look around as: Prestige III, Hunts under way, Pagle Wagers live and Coins to spend.
	veteran = { veteran = true, checks = "a seasoned account to play and look around as" },
}
local PRESET_NAMES =
	{ "level10", "level60", "catches1000", "boardday", "big5", "big20", "showcase", "wagers", "veteran" }

-- veteran's log: VETERAN_DAYS days of history before the last fallback slot, a session of VETERAN_SESSION Casts each
-- evening in the next charted zone in turn, and a Prestige the evening of each of VETERAN_PRESTIGE_DAYS. Its test-log
-- grants (catch-log.md › Test logs): Activity XP enough that each Prestige's snapshot is VETERAN_CLIMB_GAP above the
-- last, so each climb reaches 60, and VETERAN_CLIMB_XP more into the climb after the last; Coins enough that the
-- balance is VETERAN_COINS. The current slot's run is played until half its Hunts reach tier 1, its Casts ending
-- VETERAN_END before the run, so it is still on at the next login.
local VETERAN_DAYS, VETERAN_SESSION, VETERAN_PRESTIGE_DAYS = 21, 40, { 6, 12, 18 }
local VETERAN_CLIMB_GAP, VETERAN_CLIMB_XP, VETERAN_COINS, VETERAN_END = 201000, 60000, 50000, 900

-- wagers' run: its `run` record WAGERS_RECORD_OFFSET seconds into the slot before the current one, as a login an hour
-- into it logs it (HNT-R151), the Casts from a minute after; at most WAGERS_MAX_CASTS of them, so a run its Casts can't
-- complete (a Big ones Hunt above the character's reach, LOG-R67) stops.
local WAGERS_RECORD_OFFSET, WAGERS_MAX_CASTS = 3600, 3000

-- boardday's board: day 0 is BOARD_DAYS board days before the dev's current one, and its `start` record is
-- BOARD_START_OFFSET seconds into it, its goals' `issue` records at the same time and the Casts from a minute after.
local BOARD_DAYS, BOARD_START_OFFSET = 2, 3600

-- How old the dev's latest `start` or `day` record may be: its reset time of day is taken as the realm's now.
local BOARD_BOUNDARY_MAX_AGE = 7 * 86400

-- showcase's board: SHOWCASE_LIT lit days, the last today's (or yesterday's, when today's board day began less than
-- SHOWCASE_TODAY before the run), and an unlit day each SHOWCASE_UNLIT board days before it, so day 0 is
-- SHOWCASE_LIT + #SHOWCASE_UNLIT - 1 days before the last lit one. Each unlit day burns a Kindling (TKB-R72): they're at
-- least 7 lit days apart, so a Kindling earned between them (TKB-R70) keeps the fire from going out, and three fall
-- in the four weeks the Campfire card shows (TKB-R106). The 100-day milestone falls in those weeks too (TKB-R73).
local SHOWCASE_LIT, SHOWCASE_UNLIT, SHOWCASE_TODAY = 104, { 5, 13, 22, 47, 81 }, 3600
-- What the fold must reach: a Campfire of SHOWCASE_FIRE days or more (its 100-day step) and SHOWCASE_COINS Coins in
-- all, several tier-3 goods (900 each, SHOP-R22).
local SHOWCASE_FIRE, SHOWCASE_COINS = 100, 5000
-- A lit day's play: at most SHOWCASE_NOTICES Notices completed and SHOWCASE_EXPEDITION_CASTS Casts toward each open
-- Expedition, a goal given up for the day after SHOWCASE_GOAL_CASTS Casts, then a session of SHOWCASE_EXPLORE Casts
-- in the next charted zone in turn, so every zone's list is fished in time. Today completes one Notice only, its
-- Casts ending SHOWCASE_TODAY_END before the run.
local SHOWCASE_NOTICES, SHOWCASE_EXPEDITION_CASTS, SHOWCASE_GOAL_CASTS = 3, 60, 300
local SHOWCASE_EXPLORE, SHOWCASE_TODAY_END = 30, 600
-- The generator is drawn again, at most SHOWCASE_DRAWS times, until it hands out a goal the test Casts can complete:
-- they catch no container (a Collector Notice's half) and only Species, junk and trophies on the lists. When every
-- kind they can complete is open already, the generator offers only the others (TKB-R32), and the last draw is
-- issued: it stays open, as a goal no Catch moves on does in play, until the dev takes it down.
local SHOWCASE_DRAWS = 50
-- The lure a Lure Notice's Casts carry (their snapshot's `lure`, LOG-R47) when the dev's own Casts never had one.
local SHOWCASE_LURE = 263

-- boardday's goals, in issuing order (TKB-R21: the Expedition, then the Notices), as generation would stamp them
-- (TKB-R34's needs and pays, read from the board's own logic/Generate.lua and logic/Rewards.lua): `zone` is the Haul
-- Notice's charted zone. Only the Haul Notice can complete from Casts in one zone without a lure: the Haul Expedition
-- needs 150 Catches, the Lure Notice a lure and the Wanderer Notice three zones.
local function boardGoals(board, zone)
	local notice, expedition = board.NOTICE_NEEDS, board.EXPEDITION_NEEDS
	local pay = board.NOTICE_PAY
	return {
		{ type = "e", kind = "haul", tier = 0, pay = board.EXPEDITION_PAY, need = expedition.haul, target = zone },
		{ type = "n", kind = "haul", tier = 1, pay = pay[1], need = notice.haul[1], target = zone },
		{ type = "n", kind = "lure", tier = 1, pay = pay[1], need = notice.lure[1] },
		{ type = "n", kind = "wanderer", tier = 3, pay = pay[3], need = notice.wanderer[3] },
	}
end

-- Refuses: main prints `reason` and exits 1. Nothing has been changed when this is raised.
local function refuse(reason)
	error({ refused = reason }, 0)
end

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = {}
	local i = 1
	while args[i] do
		local word, value = args[i], args[i + 1]
		if
			word == "--account"
			or word == "--preset"
			or word == "--out"
			or word == "--catalogue"
			or word == "--huntlist"
			or word == "--eventlist"
		then
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
	-- The account's SavedVariables folder, and the folder its stages go in, named after the account's folder.
	options.sv = options.account .. "/SavedVariables"
	options.stages = options.out .. "/" .. options.account:match("[^/\\]+$")
	return options
end

-- Files ------------------------------------------------------------------------------------------------------------

local function makeFolder(path)
	if os.execute("mkdir -p " .. quote(path)) ~= 0 then
		error("can't make the folder " .. path)
	end
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
	wtf.serialize(value, replaced, name .. " = ", "")
	for i = last + 1, #lines do
		replaced[#replaced + 1] = lines[i]
	end
	return table.concat(replaced, eol) .. (trailing and eol or "")
end

-- Core and the Ledger -------------------------------------------------------------------------------------------

-- Core's codec, sizes (logic/Size.lua on LuaBitOp, LOG-R65, LOG-R66), varieties (logic/Variety.lua, VAR-R4) and
-- MatchesConditions, the catalogue's accessors (Core's logic/Catalogue.lua over the catalogue file), and the Ledger's
-- logic/ in Pagle_Ledger.toc order with its world index over that catalogue (LED-R10). `open` opens a Catch log as
-- Core does in the game: every Cast it hands out sized, and given its varieties, through the catalogue (LOG-R65,
-- VAR-R4).
local function loadGame(cataloguePath)
	if not wtf.luaBitOp() then
		refuse("no LuaBitOp to size the Catches with: run scripts/setup.sh, then this through scripts/make-test-log.sh")
	end
	local core = wtf.loadCore({
		"locale/enUS.lua",
		"logic/Size.lua",
		"logic/Variety.lua",
		"logic/Conditions.lua",
		"logic/Sessions.lua",
		"logic/Integrity.lua",
		"logic/CatchLog.lua",
	})
	local label = cataloguePath or "the repo's addons/Pagle/data/Catalogue.lua"
	local catalogue, err = wtf.loadCatalogue(cataloguePath)
	if not catalogue then
		refuse(("can't load the catalogue %s: %s"):format(label, tostring(err)))
	end
	local ledger = wtf.loadLedgerLogic()
	local world = ledger.NewWorld(catalogue)
	local lookups = { GetItem = catalogue.GetItem, MatchesConditions = core.MatchesConditions, world = world }
	local game =
		{ core = core, catalogue = catalogue, label = label, ledger = ledger, world = world, lookups = lookups }
	function game.open(data, global, now)
		return core.OpenCatchLog(data, global, now, catalogue.GetItem)
	end
	return game
end

-- What an item is to a test log: the class the Ledger's own ClassifyCatch gives it (LED-R5), a curio by its
-- category, "Uncharted" when the catalogue doesn't know it.
local function kindOf(game, itemID)
	local item = game.catalogue.GetItem(itemID)
	local class = game.ledger.ClassifyCatch(itemID, item)
	return item and (class == "curio" and item.category or class) or "Uncharted"
end

-- Whether a test Cast may catch the item: an ordinary Species, junk or trophy (ORDINARY) that isn't removed.
local function ordinary(game, itemID)
	local item = game.catalogue.GetItem(itemID)
	return ORDINARY[kindOf(game, itemID)] == true and not item.removed
end

-- The Tackle Board as read-wtf.lua loads it: each locale/, data/ and logic/ file Pagle_TackleBoard.toc lists, in TOC
-- order (TKB-R81), on the client's `bit` library (LuaBitOp, which its FNV-1a hash reads), with the script's stand-ins
-- for the client's calls in its ns.api (logic/Seams.lua): "Area {id}", "Map {id}" and "Item {id}" for the names, no
-- realm clock, and Core's catalogue calls over the game's catalogue.
local function loadBoard(game)
	local bit = wtf.luaBitOp()
	if not bit then
		refuse("no LuaBitOp (`bit`), which the Tackle Board's logic/ needs: run scripts/setup.sh; nothing written")
	end
	local board = {}
	local env = setmetatable({ Pagle = {}, bit = bit }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_TackleBoard/"
	for _, file in ipairs(wtf.tocEntries("Pagle_TackleBoard")) do
		if file:match("^locale/[^/]+%.lua$") or file:match("^data/[^/]+%.lua$") or file:match("^logic/[^/]+%.lua$") then
			assert(wtf.loadInto(board, env, dir .. file, "Pagle_TackleBoard"))
		end
	end
	local function named(prefix)
		return function(id)
			return prefix .. " " .. tostring(id)
		end
	end
	board.api = {
		AreaName = named("Area"),
		MapName = named("Map"),
		ItemName = named("Item"),
		RequestItem = function() end,
		FormatNumber = tostring,
		pagle = game.catalogue,
	}
	return board
end

-- The real log -------------------------------------------------------------------------------------------------

-- What the test log takes from the dev's PagleLog, read with Core's codec: the character of the last Cast and
-- its Skill Reading, the last build, each character's last Skill Reading, the charted zones fished (the latest
-- first), the uiMapID seen in each zone, the latest lure on and the realm's UTC offset (LOG-R49).
local function readRealLog(game, log)
	local global = { decodeErrors = 0 }
	local facts = { skills = {}, uiMaps = {}, fished = {}, offset = 0 }
	local casts = {}
	for record in game.open(deepCopy(log), global, 0):Iterate() do
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
		if c.lure and c.lure ~= 0 then
			facts.lure = facts.lure or c.lure
		end
		if c.minute and not facts.offsetSet then
			facts.offset, facts.offsetSet = game.ledger.RealmOffset(casts[i].time, c.minute), true
		end
	end
	return facts
end

-- The (zone, item) pairs a test Cast may catch: each charted zone's list entries without a window whose item is
-- `ordinary`; the zones fished first.
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
			local key = zone .. ":" .. entry.itemID
			if ordinary(game, entry.itemID) and not entry.window and not taken[key] then
				taken[key] = true
				local subzone = entry.areaID ~= zone and entry.areaID or 0
				list[#list + 1] = { zone = zone, subzone = subzone, itemID = entry.itemID }
			end
		end
	end
	return list
end

-- A caught Cast of one item of `pair` at `time` (catch-log.md › Entry formats), as Core's Append takes it, by the
-- character `char` (by default the one of the dev's last Cast), at its last Skill Reading (else that one's).
local function castRecord(game, facts, pair, time, char)
	local area = game.catalogue.GetArea(pair.zone)
	local skill = char and facts.skills[char] or facts.skill
	return {
		kind = "cast",
		char = char or facts.char,
		time = time,
		outcome = "caught",
		conditions = {
			minute = (math.floor(time / 60) + facts.offset) % 1440,
			uiMap = facts.uiMaps[pair.zone],
			instance = area and area.continent,
			zone = pair.zone,
			subzone = pair.subzone,
			skillRank = skill.rank,
			skillMod = skill.mod,
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

-- A new test log (`test = true`, catch-log.md › Data: /pagle dev catch appends only on one) with the dev's
-- characters, its build entry and each character's last Skill Reading at `time`.
local function newLog(game, log, facts, time)
	local data = { format = game.core.LOG_FORMAT, characters = deepCopy(log.characters), entries = {}, test = true }
	local catchLog = game.open(data, {}, time)
	local header = {}
	if facts.build then
		local build = { kind = "build", char = facts.char, time = time }
		build.build, build.version, build.rules = facts.build.build, facts.build.version, facts.build.rules
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
	local scratch = game.open({ format = game.core.LOG_FORMAT, characters = facts.characters, entries = {} }, {}, time)
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

-- What's wrong with a test log's logId (LOG-R15): not 16 lowercase hex digits, or the real log's; nil if nothing.
local function logIdProblem(data, facts)
	if not (type(data.logId) == "string" and data.logId:match("^[0-9a-f]+$") and #data.logId == 16) then
		return "the logId isn't 16 lowercase hex digits"
	elseif data.logId == facts.log.logId then
		return "the logId is the real log's"
	end
	return nil
end

-- Checks the written log as the game will read it: decoded with Core's codec, each Species Catch sized (LOG-R65),
-- and folded with the Ledger's own logic/ from nothing (LED-R3). Returns what it found and the failures (none when
-- the preset landed).
local function check(game, facts, preset, data, probePair, now)
	local global = { decodeErrors = 0 }
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local state = fold.reset()
	local found = { tags = {}, classes = {}, zones = {}, kept = {}, failures = {} }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	-- Each entry's tag as Core's codec wrote it (catch-log.md › Entry formats).
	for _, entry in ipairs(data.entries) do
		local tag = entry:match("^(%u%d+)|") or "(no tag)"
		found.tags[tag] = (found.tags[tag] or 0) + 1
	end
	for record in game.open(deepCopy(data), global, now):Iterate() do
		fold.apply(state, record, "rebuild")
		if record.kind == "cast" then
			found.zones[record.conditions.zone] = true
			if record.char ~= facts.char then
				fail("a Cast is on another character")
			end
			for _, catch in ipairs(record.items) do
				local kind = kindOf(game, catch.itemID)
				if not ordinary(game, catch.itemID) then
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
		fail("an item no test Cast may catch (LED-R5) is caught: " .. table.concat(found.kept, ", "))
	end
	local problem = logIdProblem(data, facts)
	if problem then
		fail(problem)
	end
	if data.test ~= true then
		fail("PagleLog.test isn't true, so /pagle dev catch would refuse it")
	end
	found.level, found.toNext = climb(game, state)
	found.state = state
	found.catches, found.xp = state.catches, state.xp
	found.records = 0
	for _, entry in pairs(state.species) do
		found.records = found.records + (entry.record and 1 or 0)
	end
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

-- The Tackle Board (boardday) --------------------------------------------------------------------------------------

-- The dev's latest Tackle Board `start` or `day` record (TKB-R12), read with Core's codec and the board's own decoder
-- (TKB-R80): { kind, seq, dayStart, weekStart }, or nil when the log has none.
local function latestBoundary(game, board, log)
	local latest
	local module = board.ModuleDef().name
	for record in game.core.OpenCatchLog(deepCopy(log), { decodeErrors = 0 }, 0):Iterate(0, module) do
		local decoded = record.kind == "module" and board.DecodeRecord(record.recordKind, record.payload)
		if decoded and (decoded.kind == "start" or decoded.kind == "day") then
			latest =
				{ kind = decoded.kind, seq = record.seq, dayStart = decoded.dayStart, weekStart = decoded.weekStart }
		end
	end
	return latest
end

-- Plans boardday's board at server time `now` (TKB-R10–R12), numbered by the board's own logic/Days.lua from the
-- latest boundary: today's board day starts at its reset time of day, day 0 BOARD_DAYS days before it, and day 0's
-- week is the one of its weekly reset (moved by whole weeks) that day 0's start falls in (ns.WeekOfDay).
local function planBoard(game, board, facts, log, now)
	local latest = latestBoundary(game, board, log)
	if not latest then
		refuse(
			"PagleLog has no Tackle Board start or day record: start the board first (M7 exit check step 2), quit,"
				.. " then run this again; nothing written"
		)
	end
	if now - latest.dayStart > BOARD_BOUNDARY_MAX_AGE then
		refuse(
			("the board's latest boundary, the %s record at seq %d (day began %s), is older than a week: log in once"):format(
				latest.kind,
				latest.seq,
				utc(latest.dayStart)
			) .. " with the board started, so its live step writes a day record, then quit; nothing written"
		)
	end
	-- The latest boundary as day 0 of week 0, so the board's numbers count from it.
	local from = { day = 0, week = 0, dayStart = latest.dayStart, weekStart = latest.weekStart }
	local today = board.DayOf(from, now) --[[@as integer]]
	local dayStart = board.DayStartOf(from, today - BOARD_DAYS)
	local weekStart = latest.weekStart + board.WeekOfDay(from, today - BOARD_DAYS) * board.WEEK_SECONDS
	local catches = catchable(game, facts)
	if #catches == 0 then
		refuse("no charted zone lists an ordinary Species, junk or trophy item to catch; nothing written")
	end
	local zone = catches[1].zone
	local inZone = {}
	for _, pair in ipairs(catches) do
		if pair.zone == zone then
			inZone[#inZone + 1] = pair
		end
	end
	return {
		latest = latest,
		dayStart = dayStart,
		weekStart = weekStart,
		nextReset = board.DayStartOf(from, today + 1),
		zone = zone,
		pairs = inZone,
		goals = boardGoals(board, zone),
	}
end

-- A Tackle Board Module record for Core's Append (LOG-R40), by the fishing character.
local function boardRecord(board, facts, time, recordKind, payload)
	return {
		kind = "module",
		char = facts.char,
		time = time,
		module = board.ModuleDef().name,
		recordKind = recordKind,
		payload = payload,
	}
end

-- boardday's log: the header just before day 0's `start` record, the goals' `issue` records (TKB-R21), then the Haul
-- Notice's need of caught Casts in its zone, CAST_GAP apart, and nothing after.
local function writeBoard(game, board, facts, log, layout)
	local start = layout.dayStart + BOARD_START_OFFSET
	local data, catchLog = newLog(game, log, facts, start - 60)
	catchLog:Append(boardRecord(board, facts, start, "start", board.EncodeBoundary(layout.dayStart, layout.weekStart)))
	for _, goal in ipairs(layout.goals) do
		catchLog:Append(boardRecord(board, facts, start, "issue", board.EncodeIssue(goal)))
	end
	for i = 1, layout.goals[2].need do
		local pair = layout.pairs[(i - 1) % #layout.pairs + 1]
		catchLog:Append(castRecord(game, facts, pair, start + 60 + (i - 1) * CAST_GAP))
	end
	return data
end

local function countOf(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end

-- Checks boardday's log as the game will read it: decoded with Core's codec and folded with the Tackle Board's own
-- logic/ from nothing (TKB-R81), then a copy advanced to today as the live step will (TKB-R13, TKB-R14). Day 0 must be
-- lit by the Haul Notice alone (Campfire 1, 2 Kindling, tally 1, a fly tied, 2 Notices and 1 Expedition open), and
-- today must be day 2, closing day 1 as "burned" (1 Kindling, Campfire still 1) with 4 Notices owed and 1 Expedition
-- if a weekly reset falls in days 1–2 (TKB-R20, TKB-R72). Returns what it found and the failures.
local function checkBoard(game, board, facts, data, layout, now)
	local found = { tags = {}, failures = {} }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	local global = { decodeErrors = 0 }
	local state = board.NewBoardState()
	-- Read without Simulated Sizes (LOG-R65): none of boardday's goals is a Size goal.
	-- Each entry's tag as Core's codec wrote it (catch-log.md › Entry formats).
	for _, entry in ipairs(data.entries) do
		local tag = entry:match("^(%u%d+)|") or "(no tag)"
		found.tags[tag] = (found.tags[tag] or 0) + 1
	end
	for record in game.core.OpenCatchLog(deepCopy(data), global, now):Iterate(0, board.ModuleDef().name) do
		board.ApplyEntry(state, record, "rebuild")
	end
	if global.decodeErrors > 0 then
		fail(count(global.decodeErrors, "entry", "entries") .. " Core's codec can't decode")
	end
	local problem = logIdProblem(data, facts)
	if problem then
		fail(problem)
	end
	local done, open = {}, { n = 0, e = 0 }
	for _, goal in pairs(state.goals) do
		if goal.doneDay == nil then
			open[goal.type] = open[goal.type] + 1
		else
			done[#done + 1] = goal
		end
	end
	local haul = layout.goals[2]
	if not state.started or state.day ~= 0 then
		fail("the board isn't started on day 0")
	elseif #done == 0 then
		fail("no goal is done on day 0")
	elseif #done > 1 or done[1].kind ~= haul.kind or done[1].type ~= haul.type or done[1].doneDay ~= 0 then
		fail("another goal than the Haul Notice is done")
	end
	-- TKB-R41: the Wanderer Notice holds day 0's one zone, and shows 0 on any later day (TKB-R104).
	local wanderer
	for _, goal in pairs(state.goals) do
		if goal.kind == "wanderer" then
			wanderer = goal
		end
	end
	if not wanderer or wanderer.progress ~= 1 or wanderer.progressDay ~= 0 then
		fail("the Wanderer Notice doesn't hold day 0's one zone (TKB-R41)")
	end
	local fire, tally = state.fire, state.tally
	found.flies = countOf(state.flies)
	if fire.count ~= 1 or fire.kindling ~= 2 or tally.notices ~= 1 or tally.expeditions ~= 0 or found.flies ~= 1 then
		fail(
			("day 0 folds to Campfire %d, %d Kindling, tally %d/%d, %d flies, not Campfire 1, 2 Kindling, a Notice and a fly"):format(
				fire.count,
				fire.kindling,
				tally.notices,
				tally.expeditions,
				found.flies
			)
		)
	end
	if open.n ~= 2 or open.e ~= 1 then
		fail(("%s and %s are open, not 2 and 1"):format(count(open.n, "Notice"), count(open.e, "Expedition")))
	end
	found.state, found.open = state, open

	local advanced = deepCopy(state)
	found.today = board.DayOf(advanced.boundary, now) or -1
	found.weekly = advanced.boundary ~= nil and board.WeekOfDay(advanced.boundary, BOARD_DAYS) > advanced.week
	local result = board.AdvanceTo(advanced, found.today, "rebuild")
	local closed = result and result.closed[#result.closed]
	found.advanced, found.closed = advanced, closed and closed.log
	local expeditions = found.weekly and 1 or 0
	if found.today ~= BOARD_DAYS or found.closed ~= "burned" then
		fail(
			("today is day %d, closing day %d as %s, not day 2 closing day 1 as burned"):format(
				found.today,
				found.today - 1,
				tostring(found.closed)
			)
		)
	elseif advanced.fire.kindling ~= 1 or advanced.fire.count ~= 1 then
		fail(
			("advanced, the Campfire is %d with %d Kindling, not 1 with 1"):format(
				advanced.fire.count,
				advanced.fire.kindling
			)
		)
	elseif advanced.owed.notices ~= 4 or advanced.owed.expeditions ~= expeditions then
		fail(
			("advanced, %s and %s are owed, not 4 and %d"):format(
				count(advanced.owed.notices, "Notice"),
				count(advanced.owed.expeditions, "Expedition"),
				expeditions
			)
		)
	end
	return found
end

-- The big logs (big5, big20) ---------------------------------------------------------------------------------------

-- A big preset's log (#262): the header, then `n` Casts in sessions of CASTS_PER_SESSION, CAST_GAP apart, each
-- session by the next character (all of the dev's in turn) in one charted zone (the next once every character has
-- fished it), catching the zone's ordinary items at random (`catchable`), one Cast in BIG_AWAY got away. The
-- sessions start about BIG_SPAN / sessions apart, a little later at random, the last ending END_GAP before `now`.
local function writeBig(game, facts, log, n, now)
	local byZone, zones = {}, {}
	for _, pair in ipairs(catchable(game, facts)) do
		if not byZone[pair.zone] then
			byZone[pair.zone] = {}
			zones[#zones + 1] = pair.zone
		end
		local list = byZone[pair.zone]
		list[#list + 1] = pair
	end
	if #zones == 0 then
		refuse("no charted zone lists an ordinary Species, junk or trophy item to catch; nothing written")
	end
	local sessions = math.ceil(n / CASTS_PER_SESSION)
	local length = CASTS_PER_SESSION * CAST_GAP
	local gap = math.max(math.floor(BIG_SPAN / sessions), length + 120)
	-- Session k starts in [first + k * gap, first + (k + 1) * gap - length - 120], so the last ends before now - END_GAP.
	local first = now - END_GAP - sessions * gap
	local data, catchLog = newLog(game, log, facts, first - 60)
	local chars = #log.characters
	local start
	for i = 0, n - 1 do
		local session, nth = math.floor(i / CASTS_PER_SESSION), i % CASTS_PER_SESSION
		if nth == 0 then
			start = first + session * gap + math.random(0, gap - length - 120)
		end
		local list = byZone[zones[math.floor(session / chars) % #zones + 1]]
		local record = castRecord(game, facts, list[math.random(#list)], start + nth * CAST_GAP, session % chars + 1)
		if math.random(BIG_AWAY) == 1 then
			record.outcome, record.items = "gotAway", {}
		end
		catchLog:Append(record)
	end
	return data
end

-- How many Casts make the test Pagle.lua `bytes` long: the file with only the header (`base` bytes), plus each Cast's
-- line as the client writes it (`"<entry>", -- [<seq>]` and the line end), its entry as long as the average of a
-- sample of writeBig's.
local function bigCasts(game, facts, log, original, bytes, now)
	local header = newLog(game, log, facts, now)
	local base = #replaceGlobal(original, "PagleLog", header)
	local sample = writeBig(game, facts, log, 600, now)
	local length = 0
	for seq = #header.entries + 1, #sample.entries do
		length = length + #sample.entries[seq]
	end
	local average = length / (#sample.entries - #header.entries)
	local eol = original:find("\r\n", 1, true) and 2 or 1
	local size, n = base, 0
	while size < bytes and n < BIG_MAX_CASTS do
		n = n + 1
		size = size + average + #'"", -- []' + #tostring(#header.entries + n) + eol
	end
	return n
end

-- Checks a big log as the game will read it: decoded whole with Core's codec, each Cast by one of the dev's
-- characters catching an ordinary item (or nothing, got away), and the written Pagle.lua within BIG_TOLERANCE of
-- the preset's size. Returns what it found and the failures.
local function checkBig(game, facts, preset, data, text, now)
	local found = { tags = {}, failures = {}, chars = {}, zones = {}, casts = 0, away = 0, bytes = #text }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	for _, entry in ipairs(data.entries) do
		local tag = entry:match("^(%u%d+)|") or "(no tag)"
		found.tags[tag] = (found.tags[tag] or 0) + 1
	end
	local global, kept = { decodeErrors = 0 }, {}
	for record in game.open(data, global, now):Iterate() do
		if record.kind == "cast" then
			found.casts = found.casts + 1
			found.first, found.last = found.first or record.time, record.time
			found.chars[record.char] = (found.chars[record.char] or 0) + 1
			found.zones[record.conditions.zone] = true
			found.away = found.away + (record.outcome == "gotAway" and 1 or 0)
			for _, catch in ipairs(record.items) do
				if not ordinary(game, catch.itemID) then
					kept[#kept + 1] = catch.itemID
				end
			end
			if not data.characters[record.char] then
				fail("a Cast is on a character the log hasn't")
			end
		end
	end
	if global.decodeErrors > 0 then
		fail(count(global.decodeErrors, "entry", "entries") .. " Core's codec can't decode")
	end
	if #kept > 0 then
		fail("an item no test Cast may catch (LED-R5) is caught: " .. kept[1])
	end
	if found.away == 0 then
		fail("no Cast got away")
	end
	local problem = logIdProblem(data, facts)
	if problem then
		fail(problem)
	end
	if data.test ~= true then
		fail("PagleLog.test isn't true, so /pagle dev catch would refuse it")
	end
	if math.abs(found.bytes - preset.bytes) > BIG_TOLERANCE * preset.bytes then
		fail(("Pagle.lua is %d bytes, not within 10%% of %d"):format(found.bytes, preset.bytes))
	end
	return found
end

-- A count with thousands separators: 1,234,567.
local function thousands(n)
	local text = tostring(math.floor(n))
	repeat
		local done
		text, done = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until done == 0
	return text
end

-- The big log's lines: its size, the Casts and where they are, and whether Lua 5.1 loads it in one piece.
local function printBigFold(found, log, data, preset, game)
	print(
		("size: Pagle.lua %s bytes (%.2f MiB), %+.1f%% of the preset's %d MiB"):format(
			thousands(found.bytes),
			found.bytes / MIB,
			(found.bytes - preset.bytes) / preset.bytes * 100,
			preset.bytes / MIB
		)
	)
	local zones = 0
	for _ in pairs(found.zones) do
		zones = zones + 1
	end
	print(
		("C1: %s Casts, %s got away, from %s to %s (%d days), in %s (catalogue: %s)"):format(
			thousands(found.casts),
			thousands(found.away),
			utc(found.first),
			utc(found.last),
			math.floor((found.last - found.first) / 86400),
			count(zones, "zone"),
			game.label
		)
	)
	local chars = {}
	for char = 1, #log.characters do
		chars[#chars + 1] = ("%d %s: %s"):format(char, characterName(log, char), thousands(found.chars[char] or 0))
	end
	print("Casts by character: " .. table.concat(chars, ", "))
	if #data.entries > LUA_CONSTANTS then
		print(
			(
				'note: its %s entries are more distinct strings than Lua 5.1 loads in one piece (%s: "constant table'
				.. " overflow\"); this script loads it in parts. If the client can't either, its login says so: that"
				.. " is check 2's answer for this size (LOG-R14)."
			):format(thousands(#data.entries), thousands(LUA_CONSTANTS))
		)
	end
end

-- What the dev should know before playing a big log: the login rebuilds every projection (check 10), timed only with
-- dev mode on (#262), and how to time the loading screen (check 2).
local function bigNote(devOn)
	print("  Time the loading screen with a stopwatch, as with the real log (check 2). The new logId makes every")
	print("  projection rebuild from seq 0 at that login (LOG-R72): the rebuild check 10 times.")
	if devOn then
		print("  Dev mode is on in this PagleDB, so that login keeps its load timings (PagleDB.global.probe.timings):")
		print("  log out right after it, then read them with scripts/read-wtf.sh (the Re-verification section).")
	else
		print("  Dev mode is off in this PagleDB, so no load timings are kept: /pagle dev on and log out with the")
		print("  real log first, then run --preset again.")
	end
end

-- The showcase -----------------------------------------------------------------------------------------------------

-- What a showcase's Casts can catch: the `catchable` pairs, by zone and in all, and the zones in their order.
local function showcasePairs(game, facts)
	local byZone, zones, all = {}, {}, catchable(game, facts)
	for _, pair in ipairs(all) do
		if not byZone[pair.zone] then
			byZone[pair.zone] = {}
			zones[#zones + 1] = pair.zone
		end
		local list = byZone[pair.zone]
		list[#list + 1] = pair
	end
	if #zones == 0 then
		refuse("no charted zone lists an ordinary Species, junk or trophy item to catch; nothing written")
	end
	return { byZone = byZone, zones = zones, all = all }
end

-- The `pairs` whose item passes `test(item, pair)`.
local function pairsWhere(game, pairs, test)
	local found = {}
	for _, pair in ipairs(pairs) do
		if test(game.catalogue.GetItem(pair.itemID), pair) then
			found[#found + 1] = pair
		end
	end
	return found
end

-- The Species IDs a Variety Expedition stores: its representative items' (TKB-R31, TKB-R44).
local function storedSpecies(game, def)
	local stored = {}
	for _, itemID in ipairs(def.items or {}) do
		local item = game.catalogue.GetItem(itemID)
		if item and item.species then
			stored[item.species] = true
		end
	end
	return stored
end

-- The pairs that move goal `goal` on (TKB-R42), counting only what it hasn't seen yet for a distinct-count kind; an
-- empty list when no test Cast can. `caught` is the board's ever-caught set (TKB-R46).
local function goalPairs(sim, goal, caught)
	local game, kind, target, seen = sim.game, goal.kind, goal.target, goal.seen or {}
	local catalogue = game.catalogue
	if kind == "haul" then
		return sim.pairs.byZone[target] or {}
	elseif kind == "variety" then
		local stored = goal.type == "e" and storedSpecies(game, goal)
		return pairsWhere(game, sim.pairs.byZone[target] or {}, function(item)
			return item.species ~= nil
				and not item.noise
				and not seen[item.species]
				and (not stored or stored[item.species] == true)
		end)
	elseif kind == "wanderer" then
		return pairsWhere(game, sim.pairs.all, function(_, pair)
			local area = catalogue.GetArea(pair.zone)
			return not seen[pair.zone] and (goal.type == "n" or (area and area.continent == target))
		end)
	elseif kind == "species" then
		local representative = catalogue.GetItem(target)
		return pairsWhere(game, sim.pairs.all, function(item)
			return representative ~= nil and item.species ~= nil and item.species == representative.species
		end)
	elseif kind == "rarity" then
		-- Only a Catch of a sized Species has a Variety (VAR-R4), and each Catch's is the hash of its Catch ID
		-- (VAR-R3): these Casts can only try, and `work` casts on until the Varieties come up.
		return pairsWhere(game, sim.pairs.all, function(item)
			return item.species ~= nil and not item.legend and not item.noise
		end)
	elseif kind == "lure" then
		return sim.pairs.all
	elseif kind == "collector" and goal.type == "e" then
		local SUB = { junk = true, container = true, treasure = true, trophy = true }
		local distinct, list = {}, {}
		for _, pair in
			ipairs(pairsWhere(game, sim.pairs.all, function(item, pair)
				return SUB[item.category] == true and not item.noise and not item.removed and not caught[pair.itemID]
			end))
		do
			if not distinct[pair.itemID] then
				distinct[pair.itemID], list[#list + 1] = true, pair
			end
		end
		return list
	end
	return {} -- a Collector Notice needs a container, which no test Cast catches
end

-- Whether the test Casts can complete a goal definition from nothing: enough distinct Species, zones or items for a
-- distinct-count kind, and some pair for the others.
local function completable(sim, def)
	local list = goalPairs(sim, def, sim.board.caught)
	if def.kind == "lure" and not sim.lure then
		return false
	end
	local distinct, n = {}, 0
	for _, pair in ipairs(list) do
		local item = sim.game.catalogue.GetItem(pair.itemID)
		local key = def.kind == "variety" and item.species or def.kind == "wanderer" and pair.zone or pair.itemID
		if not distinct[key] then
			distinct[key], n = true, n + 1
		end
	end
	local counted = def.kind == "variety" or def.kind == "wanderer" or def.kind == "collector"
	return n > 0 and (not counted or n >= def.need)
end

-- The open goals in seq order, as generation reads them (TKB-R32, TKB-R33).
local function openGoals(state)
	local open = {}
	for _, goal in pairs(state.goals) do
		if goal.doneDay == nil then
			open[#open + 1] = goal
		end
	end
	table.sort(open, function(a, b)
		return a.seq < b.seq
	end)
	return open
end

-- A goal of `goalType` the board's own generator draws at `time` (TKB-R30–R36), drawn again until the test Casts can
-- complete it.
local function drawGoal(sim, goalType, time)
	local board, state = sim.boardNs, sim.board
	local ctx = {
		pagle = sim.game.catalogue,
		bestBaseSkill = sim.bestSkill,
		now = time,
		zones = state.zones,
		caught = state.caught,
		open = openGoals(state),
		random = math.random,
	}
	local def
	for _ = 1, SHOWCASE_DRAWS do
		def = board.GenerateGoal(ctx, goalType)
		if completable(sim, def) then
			return def
		end
	end
	sim.stuck = sim.stuck + 1
	return def
end

-- Appends a record and folds it into the showcase's running Ledger and Tackle Board states as the game folds the log:
-- the Ledger every entry but Module records (LOG-R42), the board every entry and its own records (TKB-R81).
local function showcaseAppend(sim, record)
	local appended = sim.catchLog:Append(record)
	sim.boardNs.ApplyEntry(sim.board, appended, "rebuild")
	if appended.kind ~= "module" then
		sim.fold.apply(sim.ledger, appended, "rebuild")
	end
	return appended
end

-- One Cast of `pair` at the showcase's clock, caught unless `away`, with the lure on for a Lure Notice; the clock
-- moves a CAST_GAP.
local function showcaseCast(sim, pair, lure, away)
	local record = castRecord(sim.game, sim.facts, pair, sim.t)
	if lure then
		record.conditions.lure = sim.lure
	end
	if away then
		record.outcome, record.items = "gotAway", {}
	end
	showcaseAppend(sim, record)
	sim.casts, sim.t = sim.casts + 1, sim.t + CAST_GAP
end

-- Casts toward `goal` until it is done (or its progress reaches `upTo`, if given), `limit` Casts are made, no pair
-- moves it on, or the clock reaches `before`.
local function work(sim, goal, limit, before, upTo)
	local n = 0
	while goal.doneDay == nil and n < limit and sim.t < before and (not upTo or goal.progress < upTo) do
		local list = goalPairs(sim, goal, sim.board.caught)
		if #list == 0 then
			break
		end
		sim.turn = sim.turn + 1
		showcaseCast(sim, list[sim.turn % #list + 1], goal.kind == "lure")
		n = n + 1
	end
	return goal.doneDay ~= nil
end

-- What a goal still needs on board day `day`: its need less its progress, which a day-bound goal starts again from 0
-- on a new day (TKB-R41).
local function remaining(board, goal, day)
	local progress = board.IsDayBound(goal) and goal.progressDay ~= day and 0 or goal.progress
	return goal.need - progress
end

-- One lit board day of the showcase, its abs-th by the real latest boundary `from`: the live step's records at login
-- (TKB-R13: `start` on day 0, else `day`, then every goal owed, TKB-R21), the Prestige the climb has been ready for
-- (LED-R33), then the Casts. Today completes the one open Notice nearest done; any other day up to
-- SHOWCASE_NOTICES Notices, then each open Expedition's share, then a session in the day's zone.
local function showcaseDay(sim, layout, k, isToday, now)
	local board, game = sim.boardNs, sim.game
	local abs = layout.first + k
	local dayStart = board.DayStartOf(layout.from, abs)
	local weekStart = layout.latest.weekStart + board.WeekOfDay(layout.from, abs) * board.WEEK_SECONDS
	local login = isToday and math.max(dayStart + 120, now - SHOWCASE_TODAY + 600)
		or dayStart + math.random(3600, 5 * 3600)
	local before = isToday and now - SHOWCASE_TODAY_END or dayStart + board.DAY_SECONDS - 600
	local boundary = board.EncodeBoundary(dayStart, weekStart)
	showcaseAppend(sim, boardRecord(board, sim.facts, login, k == 0 and "start" or "day", boundary))
	local owed = sim.board.owed
	while owed.expeditions > 0 do
		showcaseAppend(sim, boardRecord(board, sim.facts, login, "issue", board.EncodeIssue(drawGoal(sim, "e", login))))
	end
	while owed.notices > 0 do
		showcaseAppend(sim, boardRecord(board, sim.facts, login, "issue", board.EncodeIssue(drawGoal(sim, "n", login))))
	end
	if sim.ledger.prestige == 0 and climb(game, sim.ledger) >= game.ledger.LEVEL_CAP then
		showcaseAppend(sim, { kind = "prestige", char = sim.facts.char, time = login, rank = 1 })
		sim.prestigeDay = k
	end
	sim.t = login + 60
	local notices = {}
	for _, goal in ipairs(board.BoardOrder(sim.board)) do
		if goal.type == "n" and #goalPairs(sim, goal, sim.board.caught) > 0 then
			notices[#notices + 1] = goal
		end
	end
	if isToday then
		-- The Notice nearest done.
		local day = sim.board.day
		table.sort(notices, function(a, b)
			local left, right = remaining(board, a, day), remaining(board, b, day)
			return left < right or left == right and a.seq < b.seq
		end)
		work(sim, notices[1] or {}, SHOWCASE_GOAL_CASTS, before)
		return
	end
	local done = 0
	for _, goal in ipairs(notices) do
		if done < SHOWCASE_NOTICES and work(sim, goal, SHOWCASE_GOAL_CASTS, before) then
			done = done + 1
		end
	end
	-- The last lit day's week leaves its Expeditions half done, so the board shows one under way.
	local lastWeek = board.WeekOfDay(layout.from, layout.first + layout.last)
	local halfway = board.WeekOfDay(layout.from, abs) == lastWeek
	for _, goal in ipairs(board.BoardOrder(sim.board)) do
		if goal.type == "e" then
			work(sim, goal, SHOWCASE_EXPEDITION_CASTS, before, halfway and math.floor(goal.need / 2) or nil)
		end
	end
	-- The day's zone, its list fished on from where its last turn stopped; one Cast in BIG_AWAY got away.
	sim.t = sim.t + math.random(1800, 5400)
	local list = sim.pairs.byZone[sim.pairs.zones[k % #sim.pairs.zones + 1]]
	for i = 1, SHOWCASE_EXPLORE do
		if sim.t >= before then
			break
		end
		local pair = list[(math.floor(k / #sim.pairs.zones) * SHOWCASE_EXPLORE + i - 1) % #list + 1]
		showcaseCast(sim, pair, false, math.random(BIG_AWAY) == 1)
	end
end

-- Plans showcase's board at server time `now` from the dev's latest boundary, as planBoard does (TKB-R10–R12): today
-- by its reset time of day, the last lit day today's or, when today's board day began less than SHOWCASE_TODAY ago,
-- yesterday's, and day 0 SHOWCASE_LIT + #SHOWCASE_UNLIT - 1 days before it.
local function planShowcase(game, board, log, now)
	local latest = latestBoundary(game, board, log)
	if not latest then
		refuse(
			"PagleLog has no Tackle Board start or day record, so there's no reset time to take: start the board,"
				.. " quit, then run this again; nothing written"
		)
	end
	if now - latest.dayStart > BOARD_BOUNDARY_MAX_AGE then
		refuse(
			("the board's latest boundary, the %s record at seq %d (day began %s), is older than a week: log in once"):format(
				latest.kind,
				latest.seq,
				utc(latest.dayStart)
			) .. " with the board started, so its live step writes a day record, then quit; nothing written"
		)
	end
	local from = { day = 0, week = 0, dayStart = latest.dayStart, weekStart = latest.weekStart }
	local today = board.DayOf(from, now) --[[@as integer]]
	local todayLit = now - board.DayStartOf(from, today) >= SHOWCASE_TODAY
	local last = SHOWCASE_LIT + #SHOWCASE_UNLIT - 1
	local lastAbs = todayLit and today or today - 1
	local unlit = {}
	for _, before in ipairs(SHOWCASE_UNLIT) do
		unlit[last - before] = true
	end
	return {
		latest = latest,
		from = from,
		today = today,
		todayLit = todayLit,
		first = lastAbs - last,
		last = last,
		unlit = unlit,
		dayStart = board.DayStartOf(from, lastAbs - last),
		nextReset = board.DayStartOf(from, today + 1),
		-- The last lit day closes lit at the next reset and unlit at the one after (TKB-R72): play before that one.
		deadline = board.DayStartOf(from, lastAbs + 2),
	}
end

-- Writes showcase's log: the header just before day 0, then each board day 0 … layout.last, lit or left empty,
-- folding as it goes. Returns the log and the running states.
local function writeShowcase(game, board, facts, log, layout, now)
	local start = layout.dayStart + 60
	local data, catchLog, header = newLog(game, log, facts, start - 60)
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local sim = {
		game = game,
		boardNs = board,
		facts = facts,
		catchLog = catchLog,
		fold = fold,
		ledger = fold.reset(),
		board = board.NewBoardState(),
		pairs = showcasePairs(game, facts),
		lure = facts.lure or SHOWCASE_LURE,
		casts = 0,
		turn = 0,
		stuck = 0,
		t = start,
	}
	local best = 0
	for _, skill in pairs(facts.skills) do
		best = math.max(best, skill.rank or 0)
	end
	sim.bestSkill = best
	for _, record in ipairs(header) do
		board.ApplyEntry(sim.board, record, "rebuild")
		fold.apply(sim.ledger, record, "rebuild")
	end
	for k = 0, layout.last do
		if not layout.unlit[k] then
			showcaseDay(sim, layout, k, layout.todayLit and k == layout.last, now)
		end
	end
	return data, sim
end

-- The board's last 28 days by outcome (TKB-R106).
local function fireLog(fire)
	local outcomes = {}
	for _, outcome in pairs(fire.log) do
		outcomes[outcome] = (outcomes[outcome] or 0) + 1
	end
	return outcomes
end

-- Checks showcase's log as the game will read it: decoded whole with Core's codec, each Species Catch sized (LOG-R65),
-- and folded from nothing with the Ledger's own logic/ (LED-R3) and, apart, the Tackle Board's (TKB-R81), which must
-- agree with the states folded while writing. The board must be on its last lit day, lit, with a Campfire of
-- SHOWCASE_FIRE days or more, Kindling held and nothing owed (the live step issued it all, TKB-R21); advanced a day, as
-- a login after the next reset does, that day closes lit (TKB-R14, TKB-R72). The Coins in all must reach
-- SHOWCASE_COINS. Returns what it found and the failures.
local function checkShowcase(game, board, facts, data, layout, sim, now)
	local found = { tags = {}, failures = {}, sessions = {}, zones = {}, kept = {}, casts = 0, catches = 0, away = 0 }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	for _, entry in ipairs(data.entries) do
		local tag = entry:match("^(%u%d+)|") or "(no tag)"
		found.tags[tag] = (found.tags[tag] or 0) + 1
	end
	local global = { decodeErrors = 0 }
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local ledger = fold.reset()
	for record in game.open(deepCopy(data), global, now):Iterate() do
		fold.apply(ledger, record, "rebuild")
		if record.kind == "cast" then
			found.casts = found.casts + 1
			found.first, found.last = found.first or record.time, record.time
			found.sessions[record.session] = true
			found.zones[record.conditions.zone] = true
			found.away = found.away + (record.outcome == "gotAway" and 1 or 0)
			if record.char ~= facts.char then
				fail("a Cast is on another character")
			end
			for _, catch in ipairs(record.items) do
				found.catches = found.catches + 1
				if not ordinary(game, catch.itemID) then
					found.kept[#found.kept + 1] = catch.itemID
				end
			end
		end
	end
	local state = board.NewBoardState()
	for record in game.open(deepCopy(data), global, now):Iterate(0, board.ModuleDef().name) do
		board.ApplyEntry(state, record, "rebuild")
	end
	if global.decodeErrors > 0 then
		fail(count(global.decodeErrors, "entry", "entries") .. " Core's codec can't decode")
	end
	if #found.kept > 0 then
		fail("an item no test Cast may catch (LED-R5) is caught: " .. found.kept[1])
	end
	local problem = logIdProblem(data, facts)
	if problem then
		fail(problem)
	end
	if data.test ~= true then
		fail("PagleLog.test isn't true, so /pagle dev catch would refuse it")
	end
	if not deepEqual(ledger, sim.ledger) then
		fail("the Ledger's fold of the written log isn't the one made while writing it")
	end
	if not deepEqual(state, sim.board) then
		fail("the Tackle Board's fold of the written log isn't the one made while writing it")
	end
	found.ledger, found.board = ledger, state
	found.level = climb(game, ledger)
	local lastAbs = layout.first + layout.last
	local fire = state.fire
	found.outcomes = fireLog(fire)
	if not state.started or state.day ~= layout.last or fire.log[layout.last] ~= "lit" then
		fail(
			("the board's last day is %s, %s, not day %d lit"):format(
				tostring(state.day),
				tostring(fire.log[state.day]),
				layout.last
			)
		)
	end
	if fire.count < SHOWCASE_FIRE or fire.kindling < 1 or not found.outcomes.burned then
		fail(
			("the Campfire is %s with %d Kindling, not %d days or more with Kindling held and a burned day in its last"):format(
				count(fire.count, "day"),
				fire.kindling,
				SHOWCASE_FIRE
			) .. " four weeks"
		)
	end
	if state.owed.notices ~= 0 or state.owed.expeditions ~= 0 then
		fail("the board still owes goals the live step would have issued (TKB-R21)")
	end
	-- Today, live, is the number a `day` record written now would get (TKB-R12).
	found.today = board.DayOf(state.boundary, now)
	if found.today ~= layout.today - layout.first then
		fail(("the board's today is day %s, not the run's"):format(tostring(found.today)))
	end
	local advanced = deepCopy(state)
	local result = board.AdvanceTo(advanced, layout.last + 1, "rebuild")
	local closed = result and result.closed[#result.closed]
	if
		not closed
		or closed.log ~= "lit"
		or advanced.fire.count ~= fire.count
		or advanced.fire.kindling ~= fire.kindling
	then
		fail(("advanced past day %d, as the login after the next reset does, it doesn't close lit"):format(layout.last))
	end
	found.coins = { Ledger = ledger.coins, TackleBoard = state.coins, Hunts = 0 }
	found.total = ledger.coins + state.coins
	if found.total < SHOWCASE_COINS then
		fail(("the Modules earn %d Coins in all, not %d or more"):format(found.total, SHOWCASE_COINS))
	end
	found.lastAbs = lastAbs
	return found
end

-- The showcase's lines: where the board sits, the board and the Ledger folded, and the Coins each Module reports.
local function printShowcase(found, layout, sim, game)
	local state, ledger, fire = found.board, found.ledger, found.board.fire
	print(
		("board: day 0 began %s, %d board days before today, on the reset time of the %s record at seq %d"):format(
			utc(layout.dayStart),
			layout.today - layout.first,
			layout.latest.kind,
			layout.latest.seq
		)
	)
	local outcomes = found.outcomes
	print(
		("Campfire: %s (longest %d), %d Kindling, the last lit day %s; its last four weeks %d lit, %d burned"):format(
			count(fire.count, "day"),
			fire.longest,
			fire.kindling,
			layout.todayLit and "today" or "yesterday",
			outcomes.lit or 0,
			outcomes.burned or 0
		)
	)
	local titles = {}
	for id in pairs(state.titles) do
		titles[#titles + 1] = id
	end
	table.sort(titles)
	local open = openGoals(state)
	local openN = 0
	for _, goal in ipairs(open) do
		openN = openN + (goal.type == "n" and 1 or 0)
	end
	local stuck = sim.stuck > 0 and (", %d of the goals issued no test Cast moves on"):format(sim.stuck) or ""
	print(
		("goals: %s and %s done, %d Notices and %d Expeditions open%s; %s of 30 tied; titles %s"):format(
			count(state.tally.notices, "Notice"),
			count(state.tally.expeditions, "Expedition"),
			openN,
			#open - openN,
			stuck,
			count(countOf(state.flies), "fly", "flies"),
			#titles > 0 and table.concat(titles, ", ") or "none"
		)
	)
	-- Zone Mastery ranks (LED-R50): how many fished zones are at each, 1 Visitor to 5 Master.
	local ranks, zones = {}, 0
	for _, zone in pairs(ledger.zones) do
		zones = zones + 1
		ranks[zone.rank or 0] = (ranks[zone.rank or 0] or 0) + 1
	end
	local spread = {}
	for rank = 5, 0, -1 do
		if ranks[rank] then
			spread[#spread + 1] = ("%d at rank %d"):format(ranks[rank], rank)
		end
	end
	local level, toNext = climb(game, ledger)
	local prestige = ledger.prestige > 0
			and (" at Prestige %d (its entry on board day %d)"):format(ledger.prestige, sim.prestigeDay)
		or ""
	print(
		("Ledger: Angler Level %d%s, %s XP%s; %s Species; %s fished, %s"):format(
			level,
			prestige,
			thousands(ledger.xp),
			toNext and (", %s to the next"):format(thousands(toNext)) or " (carried: Prestige ready again)",
			thousands(countOf(ledger.species)),
			count(zones, "zone"),
			table.concat(spread, ", ")
		)
	)
	print(
		("Casts: %s (%s Catches, %s got away) in %s Sessions on %d board days, %s to %s (catalogue: %s)"):format(
			thousands(found.casts),
			thousands(found.catches),
			thousands(found.away),
			thousands(countOf(found.sessions)),
			layout.last + 1 - #SHOWCASE_UNLIT,
			utc(found.first),
			utc(found.last),
			game.label
		)
	)
	print(
		("Coins: Ledger %s, Tackle Board %s, Hunts 0 (no Hunt is open yet): %s in all, and nothing spent in this log"):format(
			thousands(found.coins.Ledger),
			thousands(found.coins.TackleBoard),
			thousands(found.total)
		)
	)
end

-- What the dev should see at a showcase test log's login (TKB-R84, LED-R93, SHOP-R92).
local function showcaseNote()
	print("  The Ledger and the Tackle Board write themselves up from the test log (LED-R93, TKB-R84), with no moment,")
	print("  and each reports its whole Coins total (SHOP-R92): the Curio Shop's purse holds their sum.")
end

-- Hunts (wagers) ---------------------------------------------------------------------------------------------------

-- Hunts as its OnInitialize builds it (HNT-R136, adapter/Hunts.lua): each locale/, data/ and logic/ file
-- Pagle_Hunts.toc lists, in TOC order, on the client's `bit` library (LuaBitOp, which the rotation's FNV-1a hash
-- reads), with `huntListPath` (--huntlist) for data/HuntList.lua and `eventListPath` (--eventlist) for
-- data/EventList.lua; then the Hunt list, its lookups over the game's catalogue and Core's MatchesConditions, where
-- each Hunt bites and the event pool at runtime (ns.hunts, ns.lookups, ns.where, ns.events). With `since`, a test
-- log's release date (catch-log.md › Test logs), every Hunt is out from then, as Hunts' adapter makes it in the game.
local function loadHunts(game, huntListPath, eventListPath, since)
	local bit = wtf.luaBitOp()
	if not bit then
		refuse("no LuaBitOp (`bit`), which Hunts' rotation needs: run scripts/setup.sh; nothing written")
	end
	local ns = {}
	local env = setmetatable({ Pagle = {}, bit = bit }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_Hunts/"
	local given = { ["data/HuntList.lua"] = huntListPath, ["data/EventList.lua"] = eventListPath }
	for _, file in ipairs(wtf.tocEntries("Pagle_Hunts")) do
		if file:match("^locale/[^/]+%.lua$") or file:match("^data/[^/]+%.lua$") or file:match("^logic/[^/]+%.lua$") then
			local path = given[file] or dir .. file
			local ok, err = wtf.loadInto(ns, env, path, "Pagle_Hunts")
			if not ok then
				refuse(("can't load %s: %s; nothing written"):format(path, tostring(err)))
			end
		end
	end
	if type(ns.huntList) ~= "table" or type(ns.eventList) ~= "table" then
		refuse("the Hunt list or the event pool sets no ns.huntList or ns.eventList; nothing written")
	end
	local catalogue = game.catalogue
	ns.hunts = ns.NewHuntList(ns.HuntListFrom(ns.huntList, since), ns.L)
	ns.lookups = ns.NewLookups({
		GetItem = catalogue.GetItem,
		GetZones = catalogue.GetZones,
		GetZoneCatches = catalogue.GetZoneCatches,
		GetZoneOf = catalogue.GetZoneOf,
		GetArea = catalogue.GetArea,
		GetWindowSpec = catalogue.GetWindowSpec,
		MatchesConditions = game.core.MatchesConditions,
	}, ns.hunts)
	ns.where = ns.NewWhere(ns.hunts, ns.lookups)
	ns.events = ns.NewEventList(ns.eventList, ns.L, ns.lookups)
	ns.label = eventListPath or "the repo's addons/Pagle_Hunts/data/EventList.lua"
	return ns
end

-- Hunts' projection def over `catchLog` (logic/Projection.lua, HNT-R136): its Coins and XP reports go nowhere, a
-- `run` record's earlier Casts are read back from the same log (HNT-R149), and `done` would check titles at `now`.
local function huntsDef(hunts, catchLog, now)
	return hunts.ProjectionDef({}, hunts.lookups, {
		ReportCoinsEarned = function() end,
		ReportXPEarned = function() end,
		ReportTicketsEarned = function() end,
		IterateCatches = function(afterSeq)
			return catchLog:Iterate(afterSeq, "Hunts")
		end,
		ServerTime = function()
			return now
		end,
	})
end

-- An event's name as the board shows it (HNT-R140), with its ID when the lore names it.
local function eventLabel(hunts, event)
	local name = hunts.events:EventName(event)
	return name == event.id and name or ("%s (%s)"):format(name, event.id)
end

-- Plans wagers' run at server time `now` from Hunts' own rotation (logic/Rotation.lua, HNT-R152) over the pool: the
-- current fallback slot and the one before it, which must have ended, and that slot's pick (HNT-R153: no other run is
-- known in the test log, so its own pick). Refuses before the origin, in slot 0, and with no pick.
local function planWagers(hunts, now)
	local current = hunts.RotationSlotAt(now)
	if not current then
		refuse(
			("the fallback rotation starts at %s, after now: no slot has ended yet (HNT-R152); nothing written"):format(
				utc(hunts.ROTATION_ORIGIN)
			)
		)
	end
	local slot = hunts.RotationSlot(current)
	if current == 0 then
		refuse(
			("the current fallback slot, 0 (from %s), is the rotation's first: no slot before it has ended (HNT-R152)"):format(
				utc(slot.start)
			)
				.. "; wait until slot 1 starts, at "
				.. utc(slot.end_)
				.. ", then run this again; nothing written"
		)
	end
	local pool = hunts.events:Events()
	if #pool == 0 then
		refuse(("the event pool %s has no event, so the rotation runs nothing; nothing written"):format(hunts.label))
	end
	local previous = hunts.RotationSlot(current - 1)
	local event = hunts.RotationPick(pool, current - 1)
	if not event then
		refuse(
			("slot %d's band, %s, has no event in the rotation (HNT-R152), so no run was on; nothing written"):format(
				current - 1,
				previous.band
			)
		)
	end
	return {
		current = slot,
		slot = previous,
		event = event,
		pool = pool,
		key = hunts.RunKey(event.id, previous.start),
		recordTime = previous.start + WAGERS_RECORD_OFFSET,
	}
end

-- The (zone, item) pairs on the event's zones' lists that a Cast of `hunt` may catch for it: its target (HNT-R10,
-- HNT-R12), conditions and Size aside. The ordinary Species, junk and trophies outside any window when there are any,
-- else any other item the catalogue knows that isn't removed or Noise.
local function wagerPairs(game, hunts, event, hunt)
	local target = { kind = "natural", species = hunt.species, class = hunt.class, tiers = hunt.tiers }
	local plain, other, taken = {}, {}, {}
	for _, zone in ipairs(event.zones) do
		for _, entry in ipairs(game.catalogue.GetZoneCatches(zone) or {}) do
			local item = game.catalogue.GetItem(entry.itemID)
			local cast = { outcome = "caught", conditions = {}, items = { { itemID = entry.itemID, quantity = 1 } } }
			local key = zone .. ":" .. entry.areaID .. ":" .. entry.itemID
			if item and not item.removed and not item.noise and not taken[key] then
				if #hunts.MatchingCatches(target, cast, hunts.lookups) > 0 then
					taken[key] = true
					local pair =
						{ zone = zone, subzone = entry.areaID ~= zone and entry.areaID or 0, itemID = entry.itemID }
					local list = ordinary(game, entry.itemID) and not entry.window and plain or other
					list[#list + 1] = pair
				end
			end
		end
	end
	return #plain > 0 and plain or other
end

-- wagers' log: the header just before the run record, the `run` record of the slot's pick (Hunts' own encoder,
-- logic/Records.lua, HNT-R150) an hour into the slot, then caught Casts by the fishing character in the event's
-- zones, CAST_GAP apart, each Hunt of the event in turn until it reaches tier 1 in the run: a Hunt with conditions
-- (a Timed Hunt's realm window) waits for a time they match, and a Big ones Hunt casts its one item until enough of
-- its Catches are sized at its band (HNT-R14, LOG-R65). Folded with Hunts' own logic/ as it is written; nothing at or
-- after the slot's end, and at most WAGERS_MAX_CASTS Casts.
local function writeWagers(game, hunts, facts, log, layout, now)
	local slot, event = layout.slot, layout.event
	local data, catchLog, header = newLog(game, log, facts, layout.recordTime - 60)
	local def = huntsDef(hunts, catchLog, now)
	local state = def.reset()
	for _, record in ipairs(header) do
		def.apply(state, record, "rebuild")
	end
	local payload = hunts.EncodeRun(event.id, slot.start, slot.end_, "r")
	local run = {
		kind = "module",
		char = facts.char,
		time = layout.recordTime,
		module = "Hunts",
		recordKind = hunts.RUN_RECORD,
		payload = payload,
	}
	def.apply(state, catchLog:Append(run), "rebuild")
	local sim = { casts = 0, t = layout.recordTime + 60, unreached = {} }
	local function reached(hunt)
		local known = state.runs[layout.key]
		local progress = known and known.hunts[hunt.id]
		return progress ~= nil and progress.reached[1] ~= nil
	end
	for _, hunt in ipairs(event.hunts) do
		local candidates = wagerPairs(game, hunts, event, hunt)
		local i = 0
		while #candidates > 0 and not reached(hunt) and sim.t < slot.end_ and sim.casts < WAGERS_MAX_CASTS do
			-- A Big ones Hunt's one item, so its Catches gain the experience their Size grows with (LOG-R67).
			i = hunt.minBand and 1 or i % #candidates + 1
			local t = sim.t
			local record = castRecord(game, facts, candidates[i], t)
			while t < slot.end_ and not game.core.MatchesConditions(hunt.conditions, record.conditions) do
				t = t + 60
				record = castRecord(game, facts, candidates[i], t)
			end
			if t >= slot.end_ then
				break
			end
			def.apply(state, catchLog:Append(record), "rebuild")
			sim.casts, sim.t = sim.casts + 1, t + CAST_GAP
		end
		if not reached(hunt) then
			sim.unreached[#sim.unreached + 1] = hunt.id
		end
	end
	sim.state = state
	return data, sim
end

-- Checks wagers' log as the game will read it: decoded whole with Core's codec, each Species Catch sized (LOG-R65),
-- and folded from nothing with Hunts' own logic/ (HNT-R136), which must agree with the state folded while writing.
-- The slot's run must be the one known run, completed within its slot, `settled` 1, and no run on now; nothing is
-- logged at or after the slot's end. Then the live step at login, without the companion (HNT-R151, HNT-R153), must
-- log the current slot's run and nothing else, after which the board shows nothing of the old run (HNT-R143,
-- HNT-R160). Returns what it found and the failures.
local function checkWagers(game, hunts, facts, data, layout, sim, now)
	local found = { tags = {}, failures = {}, casts = 0, zones = {} }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	for _, entry in ipairs(data.entries) do
		local tag = entry:match("^(%u%d+)|") or "(no tag)"
		found.tags[tag] = (found.tags[tag] or 0) + 1
	end
	local global = { decodeErrors = 0 }
	local catchLog = game.open(deepCopy(data), global, now)
	local def = huntsDef(hunts, catchLog, now)
	local state = def.reset()
	local slot = layout.slot
	for record in catchLog:Iterate(0, "Hunts") do
		def.apply(state, record, "rebuild")
		if record.time >= slot.end_ or record.time < slot.start then
			found.outside = true
		end
		if record.kind == "cast" then
			found.casts = found.casts + 1
			found.zones[record.conditions.zone] = true
			if record.char ~= facts.char then
				fail("a Cast is on another character")
			end
		end
	end
	if global.decodeErrors > 0 then
		fail(count(global.decodeErrors, "entry", "entries") .. " Core's codec can't decode")
	end
	local problem = logIdProblem(data, facts)
	if problem then
		fail(problem)
	end
	if data.test ~= true then
		fail("PagleLog.test isn't true, so /pagle dev catch would refuse it")
	end
	if found.outside then
		fail("an entry falls outside the slot")
	end
	if not deepEqual(state, sim.state) then
		fail("Hunts' fold of the written log isn't the one made while writing it")
	end
	found.state = state
	local known = hunts.RunsKnown(state)
	local run = state.runs[layout.key]
	if #known ~= 1 or not run then
		fail(("Hunts knows %s, not the one run %s"):format(count(#known, "run"), layout.key))
	elseif not run.completedAt or run.completedAt >= slot.end_ or state.settled ~= 1 then
		local short = #sim.unreached > 0 and (" (short of tier 1: %s)"):format(table.concat(sim.unreached, ", ")) or ""
		fail(("the run %s isn't settled in its slot, %d settled%s"):format(layout.key, state.settled, short))
	end
	if #hunts.RunOn(state, now) > 0 then
		fail("a run is on now, so the current slot would be covered")
	end
	found.run = run

	-- The live step at login, without the companion: the current slot's run, then what the board shows.
	local snapshot = { companion = "missing", events = {}, runs = {} }
	local steps = hunts.PlanRunLog({ state = deepCopy(state), now = now, snapshot = snapshot, pool = layout.pool })
	local logged = steps[1] and steps[1].kind == hunts.RUN_RECORD and hunts.DecodeRun(steps[1].payload)
	if #steps ~= 1 or not logged or logged.start ~= layout.current.start or logged.source ~= "r" then
		fail(("the live step at login would log %s, not the current slot's run"):format(count(#steps, "record")))
		return found
	end
	found.next = hunts.events:Event(logged.event)
	found.nextRun = logged
	local after = deepCopy(state)
	hunts.AddRun(after, logged, hunts.lookups)
	found.shown = hunts.RunsShown(after, now, snapshot, layout.pool)
	for _, entry in ipairs(found.shown) do
		if entry.run.event == layout.event.id then
			fail("the board would still show " .. layout.event.id)
		end
	end
	if not (found.shown[1] and found.shown[1].on and found.shown[1].run.event == logged.event) then
		fail("the board wouldn't show the current slot's run on")
	end
	return found
end

-- wagers' lines: the rotation, the run and its Hunts, the fold, and what the live step logs at login.
local function printWagers(found, layout, hunts, game)
	local current, slot, event = layout.current, layout.slot, layout.event
	print(
		("rotation: origin %s; now in slot %d, %s to %s, %s band; %s in the pool (%s)"):format(
			utc(hunts.ROTATION_ORIGIN),
			current.slot,
			utc(current.start),
			utc(current.end_),
			current.band,
			count(#layout.pool, "event"),
			hunts.label
		)
	)
	local zones = {}
	for zone in pairs(found.zones) do
		zones[#zones + 1] = zone
	end
	table.sort(zones)
	print(
		("run: slot %d's pick, %s, %s band, %s to %s, logged %s; settled %s by %s in zone %s"):format(
			slot.slot,
			eventLabel(hunts, event),
			slot.band,
			utc(slot.start),
			utc(slot.end_),
			utc(layout.recordTime),
			utc(found.run.completedAt),
			count(found.casts, "Cast"),
			table.concat(zones, ", ")
		)
	)
	local tiers = {}
	for _, hunt in ipairs(event.hunts) do
		local progress = found.run.hunts[hunt.id]
		tiers[#tiers + 1] = ("%s %d (tier %d)"):format(hunt.id, progress.count, #progress.reached)
	end
	print("hunts: " .. table.concat(tiers, ", "))
	local state = found.state
	print(
		("fold: 1 run known, %s, no run on now; Hunts' Coins %s, Angler XP %s (catalogue: %s)"):format(
			count(state.settled, "wager settled", "wagers settled"),
			thousands(state.coins),
			thousands(state.xp),
			game.label
		)
	)
	local ahead = {}
	for _, entry in ipairs(found.shown) do
		if not entry.on then
			ahead[#ahead + 1] = eventLabel(hunts, entry.event)
		end
	end
	print(
		("at login: the live step logs slot %d's run of %s, on until %s; the board then shows it on%s, and nothing of %s"):format(
			current.slot,
			eventLabel(hunts, found.next),
			utc(found.nextRun.end_),
			#ahead > 0 and " and " .. table.concat(ahead, ", ") .. " ahead" or "",
			event.id
		)
	)
end

-- What the dev should see at a wagers test log's login (HNT-R111, HNT-R151, HNT-R143).
local function wagersNote(found, hunts, layout)
	print("  Hunts writes itself up from the test log (a first build, HNT-R111), with no moment: the section lists")
	print(
		("  %s, its Pagle Coins and Angler XP. Then the live step logs the current slot's run (HNT-R151):"):format(
			count(found.state.settled, "wager settled", "wagers settled")
		)
	)
	print(
		("  the strip, the WAGERS group, the spread and the tracker show %s only, and nothing lists %s (HNT-R143)."):format(
			eventLabel(hunts, found.next),
			eventLabel(hunts, layout.event)
		)
	)
	print(
		"  Play it without the companion (no Pagle_Content): while it is connected, no fallback run starts (HNT-R153)."
	)
end

-- The veteran ------------------------------------------------------------------------------------------------------

-- Plans veteran's log at server time `now`: wagers' rotation (planWagers), the current slot's own pick, which must
-- have started long enough ago to log its run and play some of it, and the history's first day.
local function planVeteran(hunts, now)
	local layout = planWagers(hunts, now)
	local current = layout.current
	local event = hunts.RotationPick(layout.pool, current.slot)
	if not event then
		refuse(
			("the current slot %d's band, %s, has no event in the rotation (HNT-R152); nothing written"):format(
				current.slot,
				current.band
			)
		)
	end
	local runTime = math.min(current.start + WAGERS_RECORD_OFFSET, now - VETERAN_END - 600)
	if runTime <= current.start then
		refuse(
			("the current fallback slot began %s, too lately to play its run; run this again in an hour"):format(
				utc(current.start)
			) .. "; nothing written"
		)
	end
	layout.currentEvent = event
	layout.currentKey = hunts.RunKey(event.id, current.start)
	layout.currentTime = runTime
	-- The history ends the day before the old run's slot begins.
	layout.historyStart = layout.slot.start - (VETERAN_DAYS + 1) * 86400
	-- Each Prestige's snapshot (AXP-R5) a full climb's Activity XP above the last; the grant covers them all and the
	-- climb after the last.
	layout.snapshots = {}
	for k = 1, #VETERAN_PRESTIGE_DAYS do
		layout.snapshots[k] = k * VETERAN_CLIMB_GAP
	end
	layout.devXP = #VETERAN_PRESTIGE_DAYS * VETERAN_CLIMB_GAP + VETERAN_CLIMB_XP
	return layout
end

-- Appends a record to veteran's log and folds it into the running Hunts state (every entry, as the game hands Hunts
-- its Casts and its own records) and the Ledger's (every entry but Module records, LOG-R42).
local function veteranAppend(sim, record)
	local appended = sim.catchLog:Append(record)
	sim.huntsDef.apply(sim.hunts, appended, "rebuild")
	if appended.kind ~= "module" then
		sim.fold.apply(sim.ledger, appended, "rebuild")
	end
	return appended
end

-- Logs `event`'s run from `slot` at `time` (Hunts' own encoder, source `r`), then plays it as wagers does: caught
-- Casts in its zones, each of its first `hunts` Hunts in turn until it reaches tier 1 in the run, nothing at or after
-- `stop`. With `open`, a Cast that would complete the run (its Hunts can share Catches) is left out, so it stays on
-- unsettled. Returns the Hunts left short of tier 1.
local function playRun(sim, event, slot, time, hunts, stop, open)
	local game, facts, ns = sim.game, sim.facts, sim.huntsNs
	veteranAppend(sim, {
		kind = "module",
		char = facts.char,
		time = time,
		module = "Hunts",
		recordKind = ns.RUN_RECORD,
		payload = ns.EncodeRun(event.id, slot.start, slot.end_, "r"),
	})
	local key = ns.RunKey(event.id, slot.start)
	local function reached(hunt)
		local known = sim.hunts.runs[key]
		local progress = known and known.hunts[hunt.id]
		return progress ~= nil and progress.reached[1] ~= nil
	end
	local unreached = {}
	-- Kept open: one Hunt is held back, never played nor reached by a Cast another one plays. It is the one whose
	-- Catches leave the others the most to play, so a narrow Hunt is held rather than a broad one.
	local held, heldHunt = {}, nil
	local function keyOf(pair)
		return pair.zone .. ":" .. pair.subzone .. ":" .. pair.itemID
	end
	if open then
		hunts = math.min(hunts, #event.hunts - 1)
		local best = -1
		for _, candidate in ipairs(event.hunts) do
			local its = {}
			for _, pair in ipairs(wagerPairs(game, ns, event, candidate)) do
				its[keyOf(pair)] = true
			end
			local left = 0
			for _, other in ipairs(event.hunts) do
				if other ~= candidate then
					for _, pair in ipairs(wagerPairs(game, ns, event, other)) do
						left = left + (its[keyOf(pair)] and 0 or 1)
					end
				end
			end
			if left > best then
				best, held, heldHunt = left, its, candidate
			end
		end
	end
	sim.t = time + 60
	local toPlay = {}
	for _, hunt in ipairs(event.hunts) do
		if hunt ~= heldHunt and #toPlay < hunts then
			toPlay[#toPlay + 1] = hunt
		end
	end
	for _, hunt in ipairs(toPlay) do
		local candidates = {}
		for _, pair in ipairs(wagerPairs(game, ns, event, hunt)) do
			if not held[keyOf(pair)] then
				candidates[#candidates + 1] = pair
			end
		end
		local i, casts = 0, 0
		while #candidates > 0 and not reached(hunt) and sim.t < stop and casts < WAGERS_MAX_CASTS do
			i = hunt.minBand and 1 or i % #candidates + 1
			local t = sim.t
			local record = castRecord(game, facts, candidates[i], t)
			while t < stop and not game.core.MatchesConditions(hunt.conditions, record.conditions) do
				t = t + 60
				record = castRecord(game, facts, candidates[i], t)
			end
			if t >= stop then
				break
			end
			veteranAppend(sim, record)
			casts, sim.t = casts + 1, t + CAST_GAP
		end
		if not reached(hunt) then
			unreached[#unreached + 1] = hunt.id
		end
	end
	return unreached
end

-- veteran's log: the header just before the history's first day; each day an evening session of VETERAN_SESSION
-- Casts in the next charted zone in turn (one in BIG_AWAY got away), a Prestige before it on each Prestige day; then
-- the old slot's run played to settled and the current slot's run played until half its Hunts reach tier 1, its
-- Casts ending VETERAN_END before the run. Folded with the Ledger's and Hunts' own logic/ as it is written.
local function writeVeteran(game, hunts, facts, log, layout, now)
	local data, catchLog, header = newLog(game, log, facts, layout.historyStart - 60)
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local sim = {
		game = game,
		facts = facts,
		catchLog = catchLog,
		fold = fold,
		ledger = fold.reset(),
		huntsNs = hunts,
		huntsDef = huntsDef(hunts, catchLog, now),
		pairs = showcasePairs(game, facts),
	}
	sim.hunts = sim.huntsDef.reset()
	for _, record in ipairs(header) do
		sim.huntsDef.apply(sim.hunts, record, "rebuild")
		fold.apply(sim.ledger, record, "rebuild")
	end
	local prestigeOn = {}
	for k, day in ipairs(VETERAN_PRESTIGE_DAYS) do
		prestigeOn[day] = k
	end
	local zones = sim.pairs.zones
	for d = 0, VETERAN_DAYS - 1 do
		local evening = layout.historyStart + d * 86400 + math.random(17 * 3600, 20 * 3600)
		local rank = prestigeOn[d]
		if rank then
			veteranAppend(sim, {
				kind = "prestige",
				char = facts.char,
				time = evening - 600,
				rank = rank,
				activityXP = layout.snapshots[rank],
			})
		end
		local list = sim.pairs.byZone[zones[d % #zones + 1]]
		for i = 1, VETERAN_SESSION do
			local pair = list[(math.floor(d / #zones) * VETERAN_SESSION + i - 1) % #list + 1]
			local record = castRecord(game, facts, pair, evening + (i - 1) * CAST_GAP)
			if math.random(BIG_AWAY) == 1 then
				record.outcome, record.items = "gotAway", {}
			end
			veteranAppend(sim, record)
		end
	end
	sim.oldShort = playRun(sim, layout.event, layout.slot, layout.recordTime, math.huge, layout.slot.end_)
	local half = math.max(1, math.floor(#layout.currentEvent.hunts / 2))
	sim.currentShort =
		playRun(sim, layout.currentEvent, layout.current, layout.currentTime, half, now - VETERAN_END, true)
	return data, sim
end

-- Checks veteran's log as the game will read it: decoded whole with Core's codec, folded from nothing with Hunts' own
-- logic/ (which must agree with the state folded while writing) and the Ledger's, its climb read over Core's Activity
-- XP total at login: the grant and Hunts' XP (LED-R37, AXP-R6). The Ledger must be at Prestige 3 below level 60, a
-- standing Hunt must have a tier, the old run must be settled and the current one on now. Returns what it found and
-- the failures.
local function checkVeteran(game, hunts, facts, data, layout, sim, now)
	local found = { tags = {}, failures = {}, casts = 0, sessions = {}, zones = {} }
	local function fail(line)
		found.failures[#found.failures + 1] = line
	end
	for _, entry in ipairs(data.entries) do
		local tag = entry:match("^(%u%d+)|") or "(no tag)"
		found.tags[tag] = (found.tags[tag] or 0) + 1
	end
	local global = { decodeErrors = 0 }
	local catchLog = game.open(deepCopy(data), global, now)
	local def = huntsDef(hunts, catchLog, now)
	local state = def.reset()
	for record in catchLog:Iterate(0, "Hunts") do
		def.apply(state, record, "rebuild")
	end
	local fold = game.ledger.NewLedgerFold(game.lookups)
	local ledger = fold.reset()
	for record in game.open(deepCopy(data), global, now):Iterate() do
		fold.apply(ledger, record, "rebuild")
		if record.kind == "cast" then
			found.casts = found.casts + 1
			found.first, found.last = found.first or record.time, record.time
			found.sessions[record.session] = true
			found.zones[record.conditions.zone] = true
			if record.char ~= facts.char then
				fail("a Cast is on another character")
			end
		end
	end
	if global.decodeErrors > 0 then
		fail(count(global.decodeErrors, "entry", "entries") .. " Core's codec can't decode")
	end
	local problem = logIdProblem(data, facts)
	if problem then
		fail(problem)
	end
	if data.test ~= true then
		fail("PagleLog.test isn't true, so its grants would mean nothing")
	end
	if not deepEqual(state, sim.hunts) then
		fail("Hunts' fold of the written log isn't the one made while writing it")
	end
	found.hunts, found.ledger = state, ledger
	-- Core's Activity XP total at login: the grant and Hunts' report (no Tackle Board record in this log).
	found.total = layout.devXP + state.xp
	found.level = game.ledger.Level(ledger, found.total)
	if ledger.prestige ~= #VETERAN_PRESTIGE_DAYS or found.level >= game.ledger.LEVEL_CAP then
		fail(
			("the Ledger is at Prestige %d, level %d, not Prestige %d below level %d"):format(
				ledger.prestige,
				found.level,
				#VETERAN_PRESTIGE_DAYS,
				game.ledger.LEVEL_CAP
			)
		)
	end
	found.tiered = 0
	for _, progress in pairs(state.hunts) do
		if progress.reached[1] then
			found.tiered = found.tiered + 1
		end
	end
	if found.tiered == 0 then
		fail("no standing Hunt has a tier")
	end
	local old = state.runs[layout.key]
	if not (old and old.completedAt) then
		fail(("the old run %s isn't settled"):format(layout.key))
	end
	local on = false
	for _, run in ipairs(hunts.RunOn(state, now)) do
		on = on or run.key == layout.currentKey
	end
	local current = state.runs[layout.currentKey]
	if not on or (current and current.completedAt) then
		fail(("the current run %s isn't on now, unsettled"):format(layout.currentKey))
	end
	found.coins = { Ledger = game.ledger.CoinsEarned(ledger, found.total), Hunts = state.coins }
	found.earned = found.coins.Ledger + found.coins.Hunts
	return found
end

-- veteran's lines: the Ledger's climb, the Hunts and runs, and the Coins the grant tops up.
local function printVeteran(found, layout, sim, hunts, game)
	local ledger, state = found.ledger, found.hunts
	print(
		("Ledger: Prestige %d, Angler Level %d over %s Activity XP (%s granted); %s Species, %s fished"):format(
			ledger.prestige,
			found.level,
			thousands(found.total),
			thousands(layout.devXP),
			thousands(countOf(ledger.species)),
			count(countOf(ledger.zones), "zone")
		)
	)
	local short = #sim.oldShort > 0 and (" (short: %s)"):format(table.concat(sim.oldShort, ", ")) or ""
	local current, marks = state.runs[layout.currentKey], 0
	for _, hunt in ipairs(layout.currentEvent.hunts) do
		local progress = current and current.hunts[hunt.id]
		marks = marks + (progress and progress.reached[1] and 1 or 0)
	end
	print(
		("Hunts: %s with a tier; %s; old run %s settled%s; current run %s on until %s, %d of %d first marks"):format(
			count(found.tiered, "standing Hunt"),
			count(state.settled, "wager settled", "wagers settled"),
			eventLabel(hunts, layout.event),
			short,
			eventLabel(hunts, layout.currentEvent),
			utc(layout.current.end_),
			marks,
			#layout.currentEvent.hunts
		)
	)
	print(
		("Casts: %s in %s Sessions, %s to %s (catalogue: %s)"):format(
			thousands(found.casts),
			thousands(countOf(found.sessions)),
			utc(found.first),
			utc(found.last),
			game.label
		)
	)
	print(
		("Coins: Ledger %s, Hunts %s, and %s granted: %s to spend, nothing spent"):format(
			thousands(found.coins.Ledger),
			thousands(found.coins.Hunts),
			thousands(found.devCoins),
			thousands(found.earned + found.devCoins)
		)
	)
end

-- veteran's steps in one table, so makeTestLog holds one upvalue for them (Lua 5.1 allows a function 60): its plan,
-- write, check and print, its aim, and the grants it writes into the log once checked.
local VETERAN = {
	plan = planVeteran,
	write = writeVeteran,
	check = checkVeteran,
	print = printVeteran,
	aim = function()
		return ("Prestige %d, Hunts under way, a Pagle Wagers run on and %s Coins to spend"):format(
			#VETERAN_PRESTIGE_DAYS,
			thousands(VETERAN_COINS)
		)
	end,
	-- The Activity XP the Prestiges' snapshots hold and the climb after them, the Coins that bring the balance to
	-- VETERAN_COINS and the release date the standing Hunts are out from (catch-log.md › Test logs).
	grant = function(data, layout, found)
		found.devCoins = math.max(0, VETERAN_COINS - found.earned)
		data.devXP, data.devCoins, data.devHuntsSince = layout.devXP, found.devCoins, layout.historyStart
	end,
}

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

-- What the dev should see at a boardday test log's login (TKB-R13, TKB-R84, TKB-R86).
local function boardNote(found)
	local expedition = found.weekly and "; the week's Expedition fills the second Expedition pin" or ""
	print("  The Tackle Board writes itself up from the test log (a first build, TKB-R84), then its live step closes")
	print('  day 1 (TKB-R13, TKB-R86): the "kept burning while you were away" nod (1 Kindling used, Campfire still')
	print("  1 day), Campfire 1 day on the board, and 4 new Notices fill the 6 Notice pins" .. expedition .. ".")
	print('  The Wanderer Notice reads "0 of 3 today": its zone from day 0 counts on day 0 only (TKB-R41, TKB-R104).')
end

local function restoreNote(options)
	print("To put the real files back, with the game fully closed:")
	print("  " .. command(options, "--restore"))
	print("  It puts every Pagle SavedVariables file and .bak back byte for byte, so the real log, Ledger and settings")
	print("  return with their own logId and celebrated set, and nothing is written up again.")
end

-- The Ledger fold's lines for a level or Catches preset.
local function printLedgerFold(found, preset, game)
	local toNext = found.toNext and (", %d XP to level %d"):format(found.toNext, found.level + 1) or ""
	local reach = found.needed and (", %s reach level %d"):format(count(found.needed, "Catch", "Catches"), preset.level)
		or ""
	local fold = "fold: Angler Level %d, %d XP%s; one more Catch gives %d XP%s; %d lifetime Catches, %d Simulated Size"
		.. " records"
	print(fold:format(found.level, found.xp, toNext, found.nextXP, reach, found.catches, found.records))
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
end

-- The Tackle Board fold's lines for boardday: where day 0 sits, day 0 folded, and today's advance.
local function printBoardFold(found, layout)
	local latest, state, advanced = layout.latest, found.state, found.advanced
	print(
		("board: day 0 began %s, the reset time of the %s record at seq %d; today is day %d"):format(
			utc(layout.dayStart),
			latest.kind,
			latest.seq,
			found.today
		)
	)
	local tally = state.tally.notices + state.tally.expeditions
	print(
		("fold: day 0 lit by the Haul Notice (%s in zone %d): Campfire %s, %d Kindling, tally %d, %s tied; %s and %s open"):format(
			count(layout.goals[2].need, "Catch", "Catches"),
			layout.zone,
			count(state.fire.count, "day"),
			state.fire.kindling,
			tally,
			count(found.flies, "fly", "flies"),
			count(found.open.n, "Notice"),
			count(found.open.e, "Expedition")
		)
	)
	print(
		("advanced to day %d: day %d %s, %d Kindling left, Campfire still %s; %s owed, %s owed%s"):format(
			found.today,
			found.today - 1,
			found.closed,
			advanced.fire.kindling,
			count(advanced.fire.count, "day"),
			count(advanced.owed.notices, "Notice"),
			count(advanced.owed.expeditions, "Expedition"),
			found.weekly and " (a weekly reset falls in days 1-2)" or ""
		)
	)
end

-- Modes ----------------------------------------------------------------------------------------------------------

local function makeTestLog(options, now)
	local preset = PRESETS[options.preset]
	local sv, root = options.sv, options.stages
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

	local data, found, boardPlan, showcase, sim, hunts, wagers, veteran
	if preset.veteran then
		hunts = loadHunts(game, options.huntlist, options.eventlist)
		veteran = VETERAN.plan(hunts, now)
		-- Hunts again, every standing Hunt out from the history's first day, as the log's release date makes it
		hunts = loadHunts(game, options.huntlist, options.eventlist, veteran.historyStart)
		math.randomseed(now)
		data, sim = VETERAN.write(game, hunts, facts, log, veteran, now)
		found = VETERAN.check(game, hunts, facts, data, veteran, sim, now)
		VETERAN.grant(data, veteran, found)
	elseif preset.wagers then
		hunts = loadHunts(game, options.huntlist, options.eventlist)
		wagers = planWagers(hunts, now)
		math.randomseed(now)
		data, sim = writeWagers(game, hunts, facts, log, wagers, now)
		found = checkWagers(game, hunts, facts, data, wagers, sim, now)
	elseif preset.showcase then
		local board = loadBoard(game)
		showcase = planShowcase(game, board, log, now)
		math.randomseed(now)
		data, sim = writeShowcase(game, board, facts, log, showcase, now)
		found = checkShowcase(game, board, facts, data, showcase, sim, now)
	elseif preset.board then
		local board = loadBoard(game)
		boardPlan = planBoard(game, board, facts, log, now)
		math.randomseed(now)
		data = writeBoard(game, board, facts, log, boardPlan)
		found = checkBoard(game, board, facts, data, boardPlan, now)
	elseif preset.bytes then
		local n = bigCasts(game, facts, log, originals["Pagle.lua"], preset.bytes, now)
		math.randomseed(now)
		data = writeBig(game, facts, log, n, now)
	else
		local casts, probePair = plan(game, facts, preset, catchable(game, facts))
		-- The real log, at real times: the last Cast END_GAP before now.
		math.randomseed(now)
		local first = now - END_GAP - castTime(#casts - 1)
		local catchLog
		data, catchLog = newLog(game, log, facts, first - 60)
		for i, pair in ipairs(casts) do
			catchLog:Append(castRecord(game, facts, pair, first + castTime(i - 1)))
		end
		found = check(game, facts, preset, data, probePair, now)
	end

	local text = replaceGlobal(originals["Pagle.lua"], "PagleLog", data)
	if preset.bytes then
		found = checkBig(game, facts, preset, data, text, now)
	end
	-- A big log may load only in parts (wtf.loadSavedVariables).
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
	local backedUp = {}
	for _, name in ipairs(SV_FILES) do
		if originals[name] then
			writeFile(stage .. "/original/" .. name, originals[name])
			backedUp[#backedUp + 1] = name
		end
	end
	writeFile(stage .. "/Pagle.lua", text)
	-- A boardday test log is played only before its board day ends, a showcase one before its last lit day closes
	-- unlit, a wagers one before its current fallback slot ends (install refuses after).
	local until_ = boardPlan and boardPlan.nextReset
		or showcase and showcase.deadline
		or wagers and wagers.current.end_
		or veteran and veteran.current.end_
	local nextReset = until_ and ("nextReset %d\n"):format(until_) or ""
	writeFile(
		stage .. "/stage.txt",
		("preset %s\ntestLogId %s\noriginalLogId %s\ncharacter %s\n%s"):format(
			options.preset,
			data.logId,
			tostring(log.logId),
			characterName(log, facts.char),
			nextReset
		)
	)

	local tags = {}
	for tag, n in pairs(found.tags) do
		tags[#tags + 1] = tag .. " " .. n
	end
	table.sort(tags)
	local aim = preset.veteran and VETERAN.aim()
		or preset.wagers and "the last fallback slot's run settled, the current slot's not logged yet"
		or preset.showcase and ("a Campfire of %d days or more lit on the board's day, and %s Coins or more to spend"):format(
			SHOWCASE_FIRE,
			thousands(SHOWCASE_COINS)
		)
		or preset.board and "a started board, day 0 lit and day 1 not, two board days old"
		or preset.bytes and ("a Pagle.lua of about %d MiB of real-looking Casts"):format(preset.bytes / MIB)
		or preset.level and ("within %d Catches of level %d"):format(PROBE_CATCHES, preset.level)
		or ("%d Catches short of the %s-Catch Catch Milestone"):format(preset.short, preset.milestone)
	local purpose = preset.checks or ("%s exit check step %s"):format(preset.check, preset.step)
	print(("== Test log %s: %s (%s)"):format(options.preset, aim, purpose))
	print(
		("real log: %s/Pagle.lua, logId %s, %s"):format(
			sourceDir,
			tostring(log.logId),
			count(#log.entries, "entry", "entries")
		)
	)
	local fishers = preset.bytes and "every character"
		or ("character %d, %s"):format(facts.char, characterName(log, facts.char))
	print(
		("test log: logId %s, %s, %s (%s), the Casts on %s"):format(
			data.logId,
			count(#data.characters, "character"),
			count(#data.entries, "entry", "entries"),
			table.concat(tags, ", "),
			fishers
		)
	)
	if preset.veteran then
		VETERAN.print(found, veteran, sim, hunts, game)
	elseif preset.wagers then
		printWagers(found, wagers, hunts, game)
	elseif preset.showcase then
		printShowcase(found, showcase, sim, game)
	elseif preset.board then
		printBoardFold(found, boardPlan)
	elseif preset.bytes then
		printBigFold(found, log, data, preset, game)
	else
		printLedgerFold(found, preset, game)
	end
	print(
		("backup: %s/original/ holds %s as they were, every Pagle SavedVariables file there is"):format(
			stage,
			table.concat(backedUp, ", ")
		)
	)
	print(("test log: %s/Pagle.lua, PagleDB and the rest of Pagle.lua as they were"):format(stage))
	print("Nothing under " .. options.account .. " was changed. To play it, with the game fully closed:")
	print("  " .. command(options, "--install"))
	if preset.veteran then
		print(
			("  then log in as %s before %s, when the current run's slot ends: after it, that run is over."):format(
				characterName(log, facts.char),
				utc(veteran.current.end_)
			)
		)
		print("  Its Coins and Activity XP grants count only on this test log (catch-log.md › Test logs): --restore")
		print("  puts your real log back, and with it the real totals.")
	elseif preset.wagers then
		print(
			("  then log in as %s before %s, when slot %d ends: after it, a later slot's event is on instead."):format(
				characterName(log, facts.char),
				utc(wagers.current.end_),
				wagers.current.slot
			)
		)
		wagersNote(found, hunts, wagers)
	elseif preset.showcase then
		local lit = showcase.todayLit and "today" or "yesterday"
		print(
			("  then log in as %s. Before the next daily reset, %s, the Campfire shows %s lit; log in before the"):format(
				characterName(log, facts.char),
				utc(showcase.nextReset),
				lit
			)
		)
		print(
			("  reset after that, %s, at the latest: a login after it closes the day after the last lit one unlit,"):format(
				utc(showcase.deadline)
			)
		)
		print("  which burns a Kindling (TKB-R72). --install refuses after it.")
		showcaseNote()
	elseif preset.board then
		print(
			("  then log in as %s before the next daily reset, %s: after it, day 2 closes unlit too."):format(
				characterName(log, facts.char),
				utc(boardPlan.nextReset)
			)
		)
		boardNote(found)
	elseif preset.bytes then
		print("  then log in as any of its characters.")
		local db = type(source.PagleDB) == "table" and source.PagleDB or {}
		bigNote(type(db.global) == "table" and db.global.dev == true)
	else
		print("  then log in as " .. characterName(log, facts.char) .. ".")
	end
	firstBuildNote()
	restoreNote(options)
	return 0
end

local function install(options, now)
	local sv = options.sv
	local stages = readStages(options.stages)
	local stage = stages[#stages]
	if not stage then
		refuse("no test log made for " .. options.account .. " in " .. options.out .. "; run --preset first")
	end
	local test = readFile(stage.dir .. "/Pagle.lua")
	local current = readFile(sv .. "/Pagle.lua")
	local currentLogId = logIdOf(current)
	local real = current and current == readFile(stage.dir .. "/original/Pagle.lua")
	local other = stageOfLog(stages, currentLogId)
	local nextReset = tonumber(stage.nextReset)
	if not test then
		refuse(stage.dir .. " holds no Pagle.lua; run --preset again")
	elseif nextReset and now >= nextReset then
		local why = stage.preset == "showcase"
				and "its last lit day's next day ended at %s, so it would burn a Kindling;"
			or stage.preset == "wagers" and "its fallback slot ended at %s, so a later slot's event would be on;"
			or stage.preset == "veteran" and "its current run's slot ended at %s, so that run is over;"
			or "its board day ended at %s, so day 2 would close unlit too;"
		refuse(
			("%s is a %s test log and " .. why):format(stage.dir, stage.preset, utc(nextReset))
				.. " run --preset "
				.. stage.preset
				.. " again. Nothing changed"
		)
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
	local by = stage.preset == "showcase" and " before %s, when its Campfire's last lit day is followed by an unlit one"
		or (stage.preset == "wagers" or stage.preset == "veteran") and " before %s, when its current fallback slot ends"
		or " before the next daily reset, %s"
	local before = nextReset and by:format(utc(nextReset)) or ""
	print("Log in as " .. tostring(stage.character) .. before .. ".")
	firstBuildNote()
	restoreNote(options)
	return 0
end

local function restore(options, now)
	local sv = options.sv
	local stages = readStages(options.stages)
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
