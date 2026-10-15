-- Pagle_Stats' spec harness: Stats over FakePagle (its catalogue, clock, Sessions and Module registry) with the fixture
-- catalogue served in place of the shipped one, so Stats' specs never run on the shipped catalogue; the fixture's IDs
-- and names, read by every spec from here; and the steps the specs share: opening Stats logged in, building Cast and
-- Skill Reading records, moving the player, playing Casts, loading an item on the client and reading what is shown.
-- Specs load this file with dofile (and the undefined-global suppression every dofile in spec/ carries), then call it:
--
--   local stats = dofile("spec/Pagle_Stats/support.lua")
--   local I = stats.IDS
--   local loaded, fake, book = stats.start({ records = stats.darkshore(), at = { zone = I.DARKSHORE } })

local FIXTURE_CATALOGUE = "spec/Pagle_Stats/fixtures/Catalogue.lua"

local support = {}

--- The fixture's IDs (spec/Pagle_Stats/fixtures/Catalogue.lua's header says what each is for), and the Uncharted ones
--- the specs use: an item and a subzone the catalogue lacks.
support.IDS = {
	DARKSHORE = 148,
	AUBERDINE = 442,
	BASHAL_ARAN = 446,
	ELWYNN = 12,
	STRANGLETHORN = 33,
	STORMWIND = 1519,
	FERALAS = 357,
	FEATHERMOON = 1116,
	MACKEREL = 6303,
	BLACKMOUTH = 6358,
	FIREFIN = 6359,
	NIGHTFIN = 13759,
	BASS = 13756,
	MUD_SNAPPER = 6289,
	SMALLFISH = 6291,
	MANA_POTION = 2455,
	RUSTED_LURE = 90001,
	UNCHARTED = 77777,
	UNCHARTED_SUBZONE = 9999,
}
local I = support.IDS

--- The names the client gives the fixture's areas and items, as the fixture's header lists them: one name each.
support.NAMES = {
	areas = {
		[I.DARKSHORE] = "Darkshore",
		[I.AUBERDINE] = "Auberdine",
		[I.BASHAL_ARAN] = "Bashal'Aran",
		[I.ELWYNN] = "Elwynn Forest",
		[I.STRANGLETHORN] = "Stranglethorn Vale",
		[I.STORMWIND] = "Stormwind City",
		[I.FERALAS] = "Feralas",
		[I.FEATHERMOON] = "Feathermoon Stronghold",
	},
	items = {
		[I.MACKEREL] = "Raw Mackerel",
		[I.BLACKMOUTH] = "Oily Blackmouth",
		[I.FIREFIN] = "Firefin Snapper",
		[I.NIGHTFIN] = "Raw Nightfin Snapper",
		[I.BASS] = "Raw Summer Bass",
		[I.MUD_SNAPPER] = "Raw Mud Snapper",
		[I.SMALLFISH] = "Raw Brilliant Smallfish",
		[I.MANA_POTION] = "Minor Mana Potion",
		[I.RUSTED_LURE] = "Rusted Lure",
	},
}

--- Stats' goods (STA-R88), in its table's order: its tracker frames.
support.GOODS = { "stats.trackerframe.none", "stats.trackerframe.logbook", "stats.trackerframe.brass" }

--- Another character in a spec's Catch log, beside the player's (PLAYER_GUID).
support.OTHER_GUID = "Player-4618-0B0B0B0B"
--- Realm minutes in the fixture's day (06:00–18:00) and night (18:00–06:00): 10:00 and 20:00.
support.DAY, support.NIGHT = 600, 1200
--- A history's start: 11 October 2026, 700 s before the fake's server time; not summer.
support.T0 = SERVER_TIME - 700

--- The fixture catalogue (spec/Pagle_Stats/fixtures/Catalogue.lua), a new table each call.
---@return table
function support.catalogue()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	return dofile(FIXTURE_CATALOGUE)
end

--- Loads Pagle_Stats on `fake` (a new FakePagle if nil), serving `options.catalogue` or else the fixture catalogue
--- through fake.setCatalogue first, so Stats reads it from OnInitialize on. Stats' GetServerTime is the fake's clock
--- (fake.serverTime), so fake.wait moves it; a spec may still pin it. `options.prepare(loaded)` runs after Stats'
--- files load and before its ADDON_LOADED (OnInitialize), e.g. to change `loaded.ns.STATS_RULES_VERSION`.
---@param fake table? a FakePagle (newFakePagle()), for a spec that set it up first
---@param options { catalogue: table?, prepare: fun(loaded: LoadedAddon)? }? catalogue: a catalogue in the shape of
--- ns.catalogue to serve instead
---@return LoadedAddon loaded
---@return table fake
function support.load(fake, options)
	fake = fake or newFakePagle()
	options = options or {}
	fake.setCatalogue(options.catalogue or support.catalogue())
	local loaded = fake.load("Pagle_Stats", { holdAddonLoaded = true })
	loaded.env.GetServerTime = function()
		return fake.serverTime()
	end
	if options.prepare then
		options.prepare(loaded)
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_Stats")
	return loaded, fake
end

--- Names every fixture area on `loaded`'s client, and the fixture items `items` lists (every one by default; an item
--- left out reads "Item {id}" until a spec loads it).
---@param loaded LoadedAddon
---@param items integer[]?
function support.nameAll(loaded, items)
	for areaID, name in pairs(support.NAMES.areas) do
		loaded.client.areaNames[areaID] = name
	end
	if items then
		for _, itemID in ipairs(items) do
			loaded.client.itemNames[itemID] = assert(support.NAMES.items[itemID], "no fixture item " .. itemID)
		end
	else
		for itemID, name in pairs(support.NAMES.items) do
			loaded.client.itemNames[itemID] = name
		end
	end
end

--- Moves the player: `fields` replace those of the live snapshot (zone, subzone, minute, skillRank, ...), and a field
--- set to false is cleared (a secret value).
---@param fake table
---@param fields table
function support.move(fake, fields)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	for key, value in pairs(fields) do
		if value == false then
			conditions[key] = nil
		else
			conditions[key] = value
		end
	end
	fake.setConditions(conditions)
end

---@class StatsSpecStart
---@field fake table?                     -- a FakePagle set up first (a new one by default)
---@field records table[]?                -- appended to its Catch log before login, so the first build counts them
---@field characters table[]?             -- the log's characters before the records (the player's alone by default)
---@field items integer[]?                -- the fixture items the client has named (every one by default)
---@field catalogue table?                -- support.load's
---@field prepare fun(loaded: LoadedAddon)? -- support.load's
---@field updating boolean?               -- stop at login: the projection's first build waits for fake.enterWorld
---@field at table?                       -- where the player is then (support.move's fields)

--- Pagle_Stats on a fake that has logged in with its projection built (STA-R20), the fixture's areas and items named
--- on the client, and the player moved as `options.at` says.
---@param options StatsSpecStart?
---@return LoadedAddon loaded
---@return table fake
---@return StatsBook book
function support.start(options)
	options = options or {}
	local fake = options.fake or newFakePagle()
	if options.records or options.characters then
		for i, character in ipairs(options.characters or { { guid = PLAYER_GUID } }) do
			fake.catchLog.data.characters[i] = character
		end
		for _, record in ipairs(options.records or {}) do
			fake.catchLog:Append(record)
		end
	end
	local loaded = support.load(fake, { catalogue = options.catalogue, prepare = options.prepare })
	support.nameAll(loaded, options.items)
	fake.login()
	if not options.updating then
		fake.enterWorld()
	end
	if options.at then
		support.move(fake, options.at)
	end
	return loaded, fake, loaded.ns.book
end

--- A Cast record for fake.catchLog:Append (PagleCast): by the player (1) by day (support.DAY) in Darkshore, no
--- subzone, at an unknown skill (side `na`, STA-R93) unless `c` says otherwise. `c.items` are item IDs, one of each
--- (none: got away).
---@param c { time: integer, char: integer?, minute: integer?, zone: integer?, subzone: integer?, rank: integer?, mod: integer?, items: integer[]? }
---@return table
function support.cast(c)
	local items = {}
	for i, itemID in ipairs(c.items or {}) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = c.char or 1,
		time = c.time,
		outcome = c.items and "caught" or "gotAway",
		conditions = {
			minute = c.minute or support.DAY,
			zone = c.zone or I.DARKSHORE,
			subzone = c.subzone or 0,
			skillRank = c.rank,
			skillMod = c.mod or 0,
			events = {},
			auras = {},
		},
		items = items,
	}
end

--- A Skill Reading record for fake.catchLog:Append (PagleSkillReading): `rank` of 300, no modifier, by character
--- `char` (the player by default).
---@param time integer
---@param rank integer
---@param char integer?
---@return table
function support.skill(time, rank, char)
	return { kind = "skill", char = char or 1, time = time, rank = rank, max = 300, mod = 0 }
end

--- The records of `lists`, one list after the other.
---@param ... table[]
---@return table[]
function support.concat(...)
	local records = {}
	for _, list in ipairs({ ... }) do
		for _, record in ipairs(list) do
			records[#records + 1] = record
		end
	end
	return records
end

--- The worked Darkshore history (STA-R43–R45, STA-R50–R53, worked by hand): 150 Casts by day at skill 150 + 25 = 175
--- (Darkshore's line is 170: side hi), 10 s apart from support.T0, catching
---   Smallfish on Casts 1–5: about 1 in 30, 145 since, P = (1 − 5/150)^145 ≈ 0.0073: unlucky
---   Blackmouth on Casts 10 and 20: about 1 in 75, 130 since, P ≈ 0.17: normal, "About 17 anglers in 100"
---   with `options.uncharted`, the Uncharted item on Cast 100: 1 in 150, 50 since
---   Firefin on Cast 150, the last: a Dry spell of 0, just now
--- Mackerel is never caught (not seen yet); Nightfin's `night` window holds no Cast (learning 0/100). The rest got away.
---@param options { uncharted: boolean? }?
---@return table[]
function support.darkshore(options)
	local catches = { [10] = I.BLACKMOUTH, [20] = I.BLACKMOUTH, [150] = I.FIREFIN }
	if options and options.uncharted then
		catches[100] = I.UNCHARTED
	end
	for i = 1, 5 do
		catches[i] = I.SMALLFISH
	end
	local records = {}
	for i = 1, 150 do
		local caught = catches[i]
		records[i] = support.cast({ time = support.T0 + 10 * i, rank = 150, mod = 25, items = caught and { caught } })
	end
	return records
end

--- Plays `n` live Casts through Core's Cast state machine: caught one `itemID` each, or got away with none.
---@param fake table
---@param n integer
---@param itemID integer?
function support.fish(fake, n, itemID)
	for _ = 1, n do
		if itemID then
			fake.playCast("caught", { { itemID = itemID, quantity = 1 } })
		else
			fake.playCast("gotAway")
		end
	end
end

--- The client loads an item Stats asked for (STA-R73): its name (the fixture's by default) and its quality if given,
--- then ITEM_DATA_LOAD_RESULT through Pagle.RegisterEvent. The redraws it queues run at the next frame: a spec calls
--- loaded.client.runTimers() to see them.
---@param loaded LoadedAddon
---@param itemID integer
---@param fields { name: string?, quality: integer? }?
function support.loadItem(loaded, itemID, fields)
	fields = fields or {}
	local name = fields.name or support.NAMES.items[itemID]
	if name then
		loaded.client.itemNames[itemID] = name
	end
	if fields.quality then
		loaded.client.itemQualities[itemID] = fields.quality
	end
	loaded.client.fireGameEvent("ITEM_DATA_LOAD_RESULT", itemID, true)
end

--- The texts of every shown widget under `widget`, depth first in the order the widgets were made.
---@param widget table
---@param texts string[]?
---@return string[]
function support.textsOf(widget, texts)
	texts = texts or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text ~= nil and child.text ~= "" then
				texts[#texts + 1] = child.text
			end
			support.textsOf(child, texts)
		end
	end
	return texts
end

--- Every shown widget under `widget`, depth first, skipping hidden ones and what they hold.
---@param widget table
---@param list table[]?
---@return table[]
function support.shownDescendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			list[#list + 1] = child
			support.shownDescendants(child, list)
		end
	end
	return list
end

--- The texts of every shown font string under `widget`, depth first, empty ones included: a tracker block's lines.
---@param widget table
---@return string[]
function support.fontTexts(widget)
	local texts = {}
	for _, child in ipairs(support.shownDescendants(widget)) do
		if child.kind == "FontString" and child.text then
			texts[#texts + 1] = child.text
		end
	end
	return texts
end

--- Each shown tile of a tile grid (ns.NewBookTileGrid) as "name | line | I'm here | note", "-" for a part not shown.
---@param grid StatsBookTileGridView
---@return string[]
function support.tilesOf(grid)
	local out = {}
	for _, tile in ipairs(grid.tiles) do
		if tile.shown then
			local function read(text)
				return text.shown and text.text or "-"
			end
			out[#out + 1] = table.concat({ tile.name.text, read(tile.line), read(tile.here), read(tile.note) }, " | ")
		end
	end
	return out
end

return support
