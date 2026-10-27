-- Helpers many specs share, so each is written once. spec/support/addon.lua loads this file, so busted's helper
-- defines them for every spec.
--
--   local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ "S1|1|1791731000|0|80|150|0" }) }))
--   setCombat(loaded, true)
--   openedNames(loaded)                       -- { "Pagle", "Fishing" }
--   keyRowDrawn(loaded, row.frame)            -- { texts = { "Fishing key", "F", "Not Bound" }, live = true }
--   local loaded, errors = loadCollectingErrors()
--   breakUpLargeNumbers(1950)                -- "1,950"
--
--   local loaded = loadCore(history(2))       -- Core over Ada's 2 old Casts, its server time on the client's clock
--   enterWorld(loaded, 3)                     -- PLAYER_LOGIN, the first PLAYER_ENTERING_WORLD, then 3 frames
--   catchOne(loaded)                          -- a caught Cast of one Oily Blackmouth (catchAndFlush: then a frame)
--   local entries = history(2)                -- then add Ada's Prestige and purchase entries to that history:
--   entries[#entries + 1] = prestigeEntry(SERVER_TIME - 3000, 1)
--   entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, "core.toaststyle.ripple", 150)

--- FOREVER_GLOBALS plus `extra`, as loadAddon's globals.
---@param extra table<string, any>?
---@return table<string, any>
function foreverWith(extra)
	local globals = {}
	for key, value in pairs(FOREVER_GLOBALS) do
		globals[key] = value
	end
	for key, value in pairs(extra or {}) do
		globals[key] = value
	end
	return globals
end

--- A combat flip on the fake client: PLAYER_REGEN_DISABLED or _ENABLED, with InCombatLockdown agreeing.
---@param loaded LoadedAddon
---@param inCombat boolean
function setCombat(loaded, inCombat)
	loaded.env.InCombatLockdown = function()
		return inCombat
	end
	loaded.client.fire(inCombat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

--- How Core's keybinding row (SET-R20) is drawn on `frame` now: `texts`, its label and its two keys' captions, and
--- `live`, whether both key buttons take clicks (false while it is greyed out).
---@param loaded LoadedAddon
---@param frame table a frame of PagleSettingsKeyRowTemplate, as the fake panel showed it
---@return { texts: string[], live: boolean }
function keyRowDrawn(loaded, frame)
	local settings = loaded.client.settings
	local buttons = settings.buttonsOf(frame)
	assert(#buttons == 2, "a keybinding row has two key buttons")
	return { texts = settings.textsOf(frame), live = buttons[1]:IsEnabled() and buttons[2]:IsEnabled() }
end

--- The names of the categories Settings.OpenToCategory opened, in order (false for an unknown ID).
---@param loaded LoadedAddon
---@return (string|false)[]
function openedNames(loaded)
	local names = {}
	for i, category in ipairs(loaded.client.settings.opened) do
		names[i] = category and category.name
	end
	return names
end

--- A character record of PagleLog's `characters` (catch-log.md › Data): an Alliance character on the fake client's
--- realm (4618), first and last seen at 1791700000. By default Ada (Player-4618-0A1B2C3D), a human warrior.
---@param guid string?
---@param name string?
---@param classID integer?
---@param raceID integer?
---@return table
function characterRecord(guid, name, classID, raceID)
	return {
		guid = guid or "Player-4618-0A1B2C3D",
		name = name or "Ada",
		classID = classID or 1,
		raceID = raceID or 1,
		faction = "Alliance",
		realmID = 4618,
		firstSeen = 1791700000,
		lastSeen = 1791700000,
	}
end

--- A PagleLog as SavedVariables hand it back (catch-log.md › Data), holding `entries`. Its characters are
--- `characters`, or by default Ada (Player-4618-0A1B2C3D), first and last seen at 1791700000. Each call makes a
--- fresh table, which Core may change.
---@param entries string[]?
---@param format integer? Default 3, the codec's (LOG-R18).
---@param characters table[]?
---@return table
function savedLog(entries, format, characters)
	return {
		format = format or 3,
		logId = "3f9a2c1e7b0d4a65",
		characters = characters or { characterRecord() },
		entries = entries or {},
	}
end

--- Loads Core on Forever, with the errors its default handler gets (loaded.client.errors), for a spec that asserts
--- them.
---@return LoadedAddon loaded
---@return string[] errors Each error the handler got, as text, in order.
function loadCollectingErrors()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	return loaded, loaded.client.errors
end

--- What the enUS client's BreakUpLargeNumbers writes for a whole number, 0 or more: commas between groups of three
--- digits.
---@param value integer
---@return string
function breakUpLargeNumbers(value)
	local grouped = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

--- Oily Blackmouth's item link, as the loot window hands it.
OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"
--- Fishing (Classic Journeyman), on the generated catalogue's fishing-spell list (probe report 70338 §4).
FISHING = 7731
--- The Species with varieties in the generated catalogue, by Species ID: Core's fish crests, in their order (VAR-R12).
FISH_CREST_SPECIES = {
	1467,
	4603,
	6289,
	6291,
	6299,
	6303,
	6308,
	6317,
	6358,
	6359,
	6361,
	6362,
	6458,
	6522,
	8365,
	12238,
	13422,
	13754,
	13755,
	13756,
	13757,
	13758,
	13759,
	13760,
	13888,
	13889,
	13890,
	13893,
	16967,
	16968,
	16969,
	16970,
	19807,
	19975,
	21071,
	21153,
	251524,
}

--- The build entry the fake client's build matches, so login appends no B1.
BUILD_ENTRY = ("B1|1|%d|0|70338|1.60.1|pagle-2026b"):format(SERVER_TIME - 5000)

--- A caught Cast at server time `time`, as a PagleLog entry: in Darkshore (148) at realm 08:14, Fishing 86+25 with
--- lure 263, catching one item. By default the item is Oily Blackmouth (6358), the subzone The Long Wash (453), and
--- the character savedLog's character 1 (Ada); `char` is another index into the log's characters.
---@param time integer
---@param itemID integer?
---@param subzone integer?
---@param char integer?
---@return string
function castEntry(time, itemID, subzone, char)
	return ("C1|%d|%d|0|c|494|1439|1|148|%d|86|25|263|||%dx1"):format(char or 1, time, subzone or 453, itemID or 6358)
end

--- Ada's Prestige to `rank` at server time `time`, as a PagleLog entry (LOG-R38): tie `tie` (0) within its second
--- (LOG-R12), `char` another index into the log's characters, and `activityXP` Core's Activity XP total then (AXP-R5),
--- 0 by default, as M:RecordPrestige writes it with nothing reported.
---@param time integer
---@param rank integer
---@param tie integer?
---@param char integer?
---@param activityXP integer?
---@return string
function prestigeEntry(time, rank, tie, char, activityXP)
	return ("P1|%d|%d|%d|%d|%d"):format(char or 1, time, tie or 0, rank, activityXP or 0)
end

--- Ada's purchase of `good` for `price` Coins at server time `time`, as a PagleLog entry (LOG-R39): tie `tie` (0)
--- within its second (LOG-R12), and `char` another index into the log's characters.
---@param time integer
---@param good string
---@param price integer
---@param tie integer?
---@param char integer?
---@return string
function purchaseEntry(time, good, price, tie, char)
	return ("U1|%d|%d|%d|%s|%d"):format(char or 1, time, tie or 0, good, price)
end

--- `n` of Ada's Casts, at `first` + 1, + 2, … (default SERVER_TIME - 90000, long ended), then BUILD_ENTRY.
---@param n integer
---@param first integer?
---@return string[]
function history(n, first)
	local entries = {}
	for i = 1, n do
		entries[i] = castEntry((first or SERVER_TIME - 90000) + i)
	end
	entries[n + 1] = BUILD_ENTRY
	return entries
end

--- BUILD_ENTRY, then `n` of Ada's Casts in Darkshore (148, subzone 0) at `first` + 1, + 2, …, each catching an item
--- no catalogue has, so it is Uncharted and makes an I row (REP-R10, REP-R20): `item` every time, or by default a new
--- one each (9999, 9998, …).
---@param n integer
---@param first integer
---@param item integer?
---@return string[]
function unchartedHistory(n, first, item)
	local entries = { BUILD_ENTRY }
	for i = 1, n do
		entries[#entries + 1] = castEntry(first + i, item or (10000 - i), 0)
	end
	return entries
end

--- Sets every `confirmed`, `gateConfirmed` and `skillBaseConfirmed` in a generated catalogue table to false, as
--- DATA-R56 has it before any observation.
---@param data table
local function unconfirmed(data)
	local seen = {}
	local function walk(node)
		if seen[node] then
			return
		end
		seen[node] = true
		for key, value in pairs(node) do
			if key == "confirmed" or key == "gateConfirmed" or key == "skillBaseConfirmed" then
				node[key] = false
			elseif type(value) == "table" then
				walk(value)
			end
		end
	end
	walk(data)
end

--- Core on Forever over a saved log holding `entries` (or the PagleLog `entries` itself, when it has `format`) and
--- PagleDB `saved`, if given, with the Ledger and Hunts installed. Its server time is SERVER_TIME plus the client's
--- clock, so loaded.client.advance moves both.
--- Its catalogue is the shipped one with nothing confirmed (DATA-R56), so an imported Field report confirming the
--- fixture spot (Darkshore, The Long Wash, Oily Blackmouth) changes no spec. ADDON_LOADED, where Core builds its
--- catalogue (LOG-R1), fires once that's done.
---@param entries table?
---@param saved table?
---@return LoadedAddon
function loadCore(entries, saved)
	local clock
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			PagleLog = entries and entries.format and entries or savedLog(entries),
			PagleDB = saved,
			GetServerTime = function()
				return SERVER_TIME + math.floor(clock and clock() or 0)
			end,
		}),
		{ holdAddonLoaded = true }
	)
	clock = loaded.client.time
	unconfirmed(loaded.ns.catalogue)
	loaded.client.fire("ADDON_LOADED", "Pagle")
	for _, name in ipairs({ "Ledger", "Hunts" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

--- Login up to the first PLAYER_ENTERING_WORLD (LOG-R1), then `frames` frames (none by default).
---@param loaded LoadedAddon
---@param frames integer?
---@return LoadedAddon loaded
function enterWorld(loaded, frames)
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	for _ = 1, frames or 0 do
		loaded.client.advance(0)
	end
	return loaded
end

--- Plays a caught Cast of `slots` (one Oily Blackmouth by default) on the fake client: the channel, the loot, the
--- channel stopping and the loot closing.
---@param loaded LoadedAddon
---@param slots table[]?
function catchOne(loaded, slots)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
	loaded.client.loot = { fishing = true, slots = slots or { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", FISHING)
	loaded.client.fire("LOOT_CLOSED")
end

--- catchOne, then the next frame, where Core flushes the Cast's moments (ANN-R10).
---@param loaded LoadedAddon
function catchAndFlush(loaded)
	catchOne(loaded)
	loaded.client.advance(0)
end

--- Code with its comments removed, for a Module's boundary spec: Lua's --[[ ]] and -- comments, XML's <!-- -->.
---@param text string
---@return string
function withoutComments(text)
	text = text:gsub("<!%-%-.-%-%->", "")
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	text = text:gsub("%-%-[^\n]*", "")
	return text
end

--- Each forbidden thing `code` (comments removed) says, as "<why>: <match>": `forbidden` lists { Lua pattern, why }.
---@param code string
---@param forbidden string[][]
---@return string[]
function forbiddenIn(code, forbidden)
	local found = {}
	for _, rule in ipairs(forbidden) do
		local match = code:match(rule[1])
		if match then
			found[#found + 1] = rule[2] .. ": " .. match
		end
	end
	return found
end

--- Every .lua and .xml file under `dir` (an addon's folder, "addons/Pagle_QoL/"), sorted.
---@param dir string
---@return string[]
function shippedFiles(dir)
	local files = {}
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local find = assert(io.popen("find " .. dir .. " -type f \\( -name '*.lua' -o -name '*.xml' \\)"))
	for path in find:lines() do
		files[#files + 1] = path
	end
	find:close()
	table.sort(files)
	return files
end

--- A file's bytes, exactly (binary mode: no line-end translation), for goldens as for code.
---@param path string
---@return string
function readFile(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

--- Core over a saved PagleDB (`saved`, if given) with the Ledger and Hunts installed (loadCore's) and each of `modules`
--- too, as Pagle_<name>, before PLAYER_LOGIN: the roster a tracker spec's fixture Modules dock under (CORE-R17).
---@param saved table?
---@param modules string[] roster names beyond the Ledger and Hunts, e.g. { "Stats", "TackleBoard" }
---@return LoadedAddon
function coreWithTrackers(saved, modules)
	local loaded = loadCore(nil, saved)
	for _, name in ipairs(modules) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

--- Days from 1970-01-01 to a proleptic Gregorian date (Howard Hinnant's days_from_civil): a spec's expected server
--- times, written as dates.
---@param year integer
---@param month integer
---@param day integer
---@return integer
function daysFromCivil(year, month, day)
	year = month <= 2 and year - 1 or year
	local era = math.floor(year / 400)
	local yearOfEra = year - era * 400
	local dayOfYear = math.floor((153 * (month > 2 and month - 3 or month + 9) + 2) / 5) + day - 1
	local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

-- The Ledger art kit's sprites the Ledger draws for the symbols its fonts lack (CORE-R9, #248), by the glyph ledger.md
-- writes each as: a star, a blank star, a ticked and an empty box, a tick.
local PARTS = "|TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:"
local SYMBOLS = {
	["★"] = PARTS .. "0:0:0:0:1024:2048:650:673:1126:1149|t",
	["☆"] = PARTS .. "0:0:0:0:1024:2048:677:700:1126:1149|t",
	["☑"] = PARTS .. "0:0:0:0:1024:2048:468:502:1836:1870|t",
	["☐"] = PARTS .. "0:0:0:0:1024:2048:430:464:1836:1870|t",
	["✓"] = PARTS .. "11:15:0:0:1024:2048:486:513:1586:1606|t",
}

--- `text` as the Ledger draws it: each ★, ☆, ☑, ☐ and ✓ in it as the texture escape the Ledger draws instead
--- (CORE-R9), so a spec can say "Catfish ★★☆" as ledger.md does.
---@param text string
---@return string
function drawnSymbols(text)
	return (text:gsub("\226[\152-\157][\128-\191]", SYMBOLS))
end

-- `fields` over `record`, key by key; returns `record`.
---@param record table
---@param fields table?
---@return table
local function over(record, fields)
	for key, value in pairs(fields or {}) do
		record[key] = value
	end
	return record
end

--- A catalogue item record (DATA-R76's items, LOG-R55): `category` with `legend`, `noise`, `removed` and `pool` all
--- false, then `fields` over it.
---@param category string
---@param fields table?
---@return table
function itemRecord(category, fields)
	return over({ category = category, legend = false, noise = false, removed = false, pool = false }, fields)
end

--- A fish item record of Species `species` (DATA-R19), then `fields` over it.
---@param species integer
---@param fields table?
---@return table
function fishRecord(species, fields)
	return over(itemRecord("fish", { species = species }), fields)
end

--- An area record (DATA-R76's areas): under `parent` (0 for a zone), on continent 0, with data, its skill base
--- unconfirmed and no catches, then `fields` over it.
---@param parent integer
---@param fields table?
---@return table
function areaRecord(parent, fields)
	return over({ parent = parent, continent = 0, hasData = true, skillBaseConfirmed = false, catches = {} }, fields)
end

--- One entry of a zone's catches (LOG-R55, GetZoneCatches), confirmed: ungated, or gated by window `window` with its
--- spec `gate` (DATA-R78), the gate confirmed too.
---@param itemID integer
---@param window string?
---@param gate table?
---@return table
function catchEntry(itemID, window, gate)
	return { itemID = itemID, confirmed = true, window = window, gate = gate, gateConfirmed = window and true or nil }
end

--- A night window's spec for fixtures (DATA-R78): 21:00 to 06:00 realm time, one range wrapping midnight. Not the
--- generated `night` (data/forever/windows.toml); a spec that needs that reads it from the catalogue.
NIGHT_WINDOW = { time = { { 1260, 360 } } }

--- Core's GetItem over a spec's `items` (item ID -> record), as the Ledger's fold and world read it: it asserts that
--- item 0, nothing caught, is never looked up (LED-R5).
---@param items table<integer, table>
---@return fun(itemID: integer): table?
function itemLookup(items)
	return function(itemID)
		assert(itemID ~= 0, "item 0 is never looked up (LED-R5)")
		return items[itemID]
	end
end

--- Applies each of `records` through the Ledger's `fold` to `state` (a fresh fold.reset() if nil) in `mode` ("live"
--- by default), in order; returns the state and every achievement earned, in order.
---@param fold LedgerFold
---@param records table[]
---@param state LedgerState?
---@param mode string?
---@return LedgerState state
---@return LedgerAchievement[] earned
function applyLive(fold, records, state, mode)
	state = state or fold.reset()
	local earned = {}
	for _, record in ipairs(records) do
		fold.apply(state, record, mode or "live", earned)
	end
	return state, earned
end

--- A catalogue in the shape of ns.catalogue (DATA-R76), for fake.setCatalogue: every part empty and a fixed
--- fingerprint, then `parts` (items, areas, windows, …) over it.
---@param parts table?
---@return table
function catalogueWith(parts)
	return over({
		fingerprint = "0123456789abcdef",
		items = {},
		areas = {},
		aliases = {},
		pools = {},
		windows = {},
		events = {},
		fishingSpells = {},
		auras = {},
	}, parts)
end

--- A caught Cast record as the Catch log hands one out (PagleCast, LOG-R42), from named fields, each optional:
--- `time` (SERVER_TIME - 700), `char` (1), `zone` (148), `subzone` (0), `minute` (494, realm 08:14), `date` (none),
--- `items` (item IDs, one of each; none by default), `outcome` ("caught"; "gotAway" with no items) and `seq`. With
--- `seq`, it carries what a stored record does too: its `seq`, an `id` from the time and seq, each Catch's `n` and
--- `catchId`, a session and the conditions' `time`.
---@param fields { time: integer?, char: integer?, zone: integer?, subzone: integer?, minute: integer?, date: table?, items: integer[]?, outcome: string?, seq: integer? }?
---@return table
function castRecord(fields)
	fields = fields or {}
	local time = fields.time or SERVER_TIME - 700
	local record = {
		kind = "cast",
		char = fields.char or 1,
		time = time,
		outcome = fields.outcome or "caught",
		conditions = {
			minute = fields.minute or 494,
			zone = fields.zone or 148,
			subzone = fields.subzone or 0,
			date = fields.date,
			events = {},
			auras = {},
		},
		items = {},
	}
	local seq = fields.seq
	if seq then
		record.seq, record.session = seq, "s"
		record.id = ("%s-%d-%d"):format(PLAYER_GUID, time, seq)
		record.conditions.time = time
	end
	for n, itemID in ipairs(fields.items or {}) do
		record.items[n] = { itemID = itemID, quantity = 1 }
		if seq then
			record.items[n].n, record.items[n].catchId = n, ("%s:%d"):format(record.id, n)
		end
	end
	return record
end

--- The texts a drawn widget shows, depth first through its shown children, leaving out empty ones: what a player
--- reads on a page of the Fish Journal.
---@param widget table
---@param texts string[]?
---@return string[]
function shownTexts(widget, texts)
	texts = texts or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if type(child.text) == "string" and child.text ~= "" then
				texts[#texts + 1] = child.text
			end
			shownTexts(child, texts)
		end
	end
	return texts
end

--- The texts of a Journal page's blocks, in order; a block without text (the XP bar, an icon) as its kind in
--- brackets.
---@param blocks LedgerBlock[]
---@return string[]
function blockTexts(blocks)
	local list = {}
	for i, block in ipairs(blocks) do
		list[i] = block.text or ("[" .. block.kind .. "]")
	end
	return list
end

--- The first of a Journal page's blocks of `kind`; nil if none.
---@param blocks LedgerBlock[]
---@param kind string
---@return LedgerBlock?
function blockOfKind(blocks, kind)
	for _, block in ipairs(blocks) do
		if block.kind == kind then
			return block
		end
	end
	return nil
end

--- The first of a Journal page's blocks whose text is `text`; an error if none does.
---@param blocks LedgerBlock[]
---@param text string
---@return LedgerBlock
function blockWithText(blocks, text)
	for _, block in ipairs(blocks) do
		if block.text == text then
			return block
		end
	end
	error("no block reads " .. text)
end

--- The vertical scroll of the open Fish Journal's `side` page ("left" or "right"), as last left (LED-R129).
---@param loaded LoadedAddon
---@param side "left"|"right"
---@return number
function pageScroll(loaded, side)
	return loaded.ns.journal.shown[side].scroll:GetVerticalScroll()
end

--- Scrolls the open Fish Journal's `side` page ("left" or "right") down to `offset`, as the mouse wheel does.
---@param loaded LoadedAddon
---@param side "left"|"right"
---@param offset number
function scrollPage(loaded, side, offset)
	loaded.ns.journal.shown[side].scroll:SetVerticalScroll(offset)
end

--- The Ledger on FakePagle over a spec's catalogue and log, logged in and in the world, with the Fish Journal open.
--- `options`, each optional: `catalogue` (fake.setCatalogue's; the generated one by default), `characters` (the
--- log's; the player's alone by default), `logId` (the log's), `log` (records appended in order), `entries` (the
--- log's entries as saved, in place of `log`), `globals` (set on
--- the fake's globals before the Ledger loads, such as a saved PagleLedgerDB), `itemNames`, `areaNames` and `mapNames`
--- (what the fake client's C_Item and C_Map know), `modules` (run with fake before the Ledger loads: registering
--- another Module, such as a paying one, AXP-R2), `following` (the PagleFollowingData Pagle_Following sets this login,
--- fake.setFollowing's; none, so absent, by default), `before` (run with loaded and fake before the book opens), and
--- where it opens: `place`, one of the Ledger's own places as `{ constructor, args... }` (ns.JournalPlace, e.g.
--- `{ "zone", 148 }`), or `id` and `args` for a spec's own spread, which must be registered; Home, at its first
--- opening, by default; with `id` false the book stays closed. With `building`, it stops after login, before entering
--- the world, so the projection is still being built (LOG-R74, LED-R122). With `motion`, Core's Animations setting
--- stays on and the Journal moves (its page turns, crossfades and moments); without it, everything draws settled.
---@param options { catalogue: table?, characters: table[]?, logId: string?, log: table[]?, entries: string[]?, globals: table?, itemNames: table?, areaNames: table?, mapNames: table?, modules: fun(fake: FakePagle)?, following: table?, before: fun(loaded: LoadedAddon, fake: FakePagle)?, building: boolean?, place: table?, id: string|false|nil, args: table?, motion: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
function openJournal(options)
	options = options or {}
	local fake = newFakePagle()
	-- The Journal draws settled unless a spec watches its motion (`motion`): with Core's Animations setting on, a page
	-- turn or a crossfade ends only on frames the fake runs when asked (client.update).
	if not options.motion then
		fake.profile.announcements.motion = false
	end
	if options.catalogue then
		fake.setCatalogue(options.catalogue)
	end
	fake.catchLog.data.characters = options.characters or { { guid = PLAYER_GUID } }
	if options.logId then
		fake.catchLog.data.logId = options.logId
	end
	if options.entries then
		fake.catchLog.data.entries = options.entries
	end
	for _, record in ipairs(options.log or {}) do
		fake.catchLog:Append(record)
	end
	over(fake.globals, options.globals)
	if options.modules then
		options.modules(fake)
	end
	if options.following then
		fake.setFollowing(options.following)
	end
	local loaded = fake.load("Pagle_Ledger")
	over(loaded.client.itemNames, options.itemNames)
	over(loaded.client.areaNames, options.areaNames)
	over(loaded.client.mapNames, options.mapNames)
	fake.login()
	if not options.building then
		fake.enterWorld()
	end
	if options.before then
		options.before(loaded, fake)
	end
	local id, args = options.id, options.args
	if options.place then
		local at = loaded.ns.JournalPlace[options.place[1]](unpack(options.place, 2))
		id, args = at.id, at.args
	end
	if id then
		assert(loaded.ns.journal:Open(id, args), "no spread is registered as " .. id)
	elseif id == nil then
		loaded.ns.journal:Toggle()
	end
	return fake, loaded
end

-- The punctuation outside Latin-1 that CORE-R9 allows, by code point.
local GLYPH_PUNCTUATION = {
	[0x2013] = true,
	[0x2014] = true,
	[0x2018] = true,
	[0x2019] = true,
	[0x201C] = true,
	[0x201D] = true,
	[0x2022] = true,
	[0x2026] = true,
}

-- Whether code point `cp` is in CORE-R9's set.
---@param cp integer
---@return boolean
local function glyphAllowed(cp)
	return cp < 0x80 or (cp >= 0xA0 and cp <= 0xFF) or GLYPH_PUNCTUATION[cp] == true
end

--- Each code point in `text` outside CORE-R9's set, as "U+XXXX": what spec/glyphs_spec.lua checks every shipped
--- string with, and spec/settings_tree_spec.lua every Settings string. Bytes that spell no UTF-8 character are skipped:
--- they are byte patterns such as FieldReportText's "[^\128-\191]", never drawn.
---@param text string
---@return string[]
function glyphsOutside(text)
	local found, i = {}, 1
	while i <= #text do
		local byte = text:byte(i)
		local size, cp
		if byte < 0x80 then
			size, cp = 1, byte
		elseif byte >= 0xC2 and byte <= 0xDF then
			size, cp = 2, byte % 0x20
		elseif byte >= 0xE0 and byte <= 0xEF then
			size, cp = 3, byte % 0x10
		elseif byte >= 0xF0 and byte <= 0xF4 then
			size, cp = 4, byte % 0x08
		end
		for k = 1, (size or 1) - 1 do
			local next = text:byte(i + k)
			if not next or next < 0x80 or next > 0xBF then
				size = nil
				break
			end
			cp = cp * 0x40 + next % 0x40
		end
		if not size then
			i = i + 1
		else
			if not glyphAllowed(cp) then
				found[#found + 1] = ("U+%04X"):format(cp)
			end
			i = i + size
		end
	end
	return found
end

--- The bytes `hex` spells, two hex digits a byte: the signing fixtures' form (spec/Pagle/fixtures/Signing.lua).
---@param hex string
---@return string
function fromHex(hex)
	assert(#hex % 2 == 0 and not hex:find("[^%x]"), "not hex: " .. hex)
	return (hex:gsub("..", function(pair)
		return string.char(tonumber(pair, 16))
	end))
end

--- `bytes` as lowercase hex, two digits a byte.
---@param bytes string
---@return string
function toHex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(byte:byte())
	end))
end

--- The known answers in spec/Pagle/fixtures/Signing.lua, which scripts/make-signing-fixtures.sh writes from openssl
--- (PUSH-R2, PUSH-R11), and the bytes of spec/Pagle/fixtures/signing/random-64k.bin as `data`.
---@return table
function signingFixtures()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	local fixtures = dofile("spec/Pagle/fixtures/Signing.lua")
	fixtures.data = readFile("spec/Pagle/fixtures/signing/random-64k.bin")
	return fixtures
end

local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- `bytes` in Base64 (RFC 4648 §4), padded: the spec's own encoder, for pushed files made in a spec (PUSH-R2).
---@param bytes string
---@return string
function toBase64(bytes)
	local out = {}
	for i = 1, #bytes, 3 do
		local a, b, c = bytes:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local quad = {}
		for k = 1, 4 do
			local sextet = math.floor(n / 2 ^ (6 * (4 - k))) % 64
			quad[k] = BASE64:sub(sextet + 1, sextet + 1)
		end
		if not b then
			quad[3], quad[4] = "=", "="
		elseif not c then
			quad[4] = "="
		end
		out[#out + 1] = table.concat(quad)
	end
	return table.concat(out)
end

--- The signed Pagle_Content files in spec/Pagle/fixtures/Content.lua, which scripts/make-content-fixtures.sh writes
--- with openssl and the TEST ONLY key (PUSH-R2, PUSH-R11): `good`, `functionCall`, `singleQuote` and `big`, each a
--- fresh PagleContentData table a spec may change, with their `generatedAt`, `expires` and `seq`, and `testKey`, the
--- test key's ns.PUSHED_KEYS entry. A spec registers it itself (`ns.PUSHED_KEYS.testKey = fixtures.testKey`): Core's
--- shipped keys never hold it.
---@return table
function pushedContentFixtures()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	local fixtures = dofile("spec/Pagle/fixtures/Content.lua")
	fixtures.testKey = signingFixtures().testKey
	return fixtures
end

--- The Companion's two data files as pagle-backend's IGV Contracts gives their examples, byte for byte in
--- spec/Pagle/fixtures/views/ (core/anglers-in-game.md): `following`, the PagleFollowingData that Following.txt sets
--- (Ada, one Followed Angler with two GUIDs), and `anglers`, the PagleAnglersData that Anglers.txt sets (one block of
--- two Anglers and three keys). Each call runs the files afresh, so a spec may change what it gets.
---@return { following: table, anglers: table }
function anglerFileExamples()
	local env = {}
	for _, file in ipairs({ "Following.txt", "Anglers.txt" }) do
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadstring
		local chunk = assert(loadstring(readFile("spec/Pagle/fixtures/views/" .. file), "=" .. file))
		setfenv(chunk, env)
		chunk()
	end
	return { following = env.PagleFollowingData, anglers = env.PagleAnglersData }
end
