-- Loading Pagle_Hunts for its specs: over FakePagle (its catalogue, clock and Module registry) with the fixture Hunt
-- list in place of the shipped one, and the fixture lore unless a spec asks for none (hunts.md › Data: "Tests inject
-- their own Hunt list and `since` dates"). Specs load this file with dofile (and the undefined-global suppression
-- every dofile in spec/ carries), then call it:
--
--   local hunts = dofile("spec/Pagle_Hunts/support.lua")
--   local loaded, fake = hunts.load()

local FIXTURE_LIST = "spec/Pagle_Hunts/fixtures/HuntList.lua"
local FIXTURE_LORE = "spec/Pagle_Hunts/fixtures/Lore.lua"

-- Runs a fixture file as one of Pagle_Hunts' own files: its globals, its `...` and its ns.
---@param path string
---@param loaded LoadedAddon
local function runAsHunts(path, loaded)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile(path))
	setfenv(chunk, loaded.env)
	chunk("Pagle_Hunts", loaded.ns)
end

local support = {}

--- Loads Pagle_Hunts on `fake` (a new FakePagle if nil) with the fixture Hunt list, which replaces a shipped
--- data/HuntList.lua if the TOC lists one, then fires its ADDON_LOADED, so OnInitialize reads the fixture.
---@param fake table? a FakePagle (newFakePagle()), for a spec that set it up first
---@param options { lore: boolean?, prepare: fun(loaded: LoadedAddon)? }? lore = false loads no fixture lore, so names
--- fall back to IDs (HNT-R1); prepare(loaded) runs after the fixtures, before ADDON_LOADED, e.g. to change the list
--- or the rules version OnInitialize reads
---@return LoadedAddon loaded
---@return table fake
function support.load(fake, options)
	fake = fake or newFakePagle()
	options = options or {}
	-- The client's number formatting, which the Write-up's numbers go through (HNT-R111).
	fake.globals.BreakUpLargeNumbers = fake.globals.BreakUpLargeNumbers or breakUpLargeNumbers
	local loaded = fake.load("Pagle_Hunts", { holdAddonLoaded = true })
	runAsHunts(FIXTURE_LIST, loaded)
	if options.lore ~= false then
		runAsHunts(FIXTURE_LORE, loaded)
	end
	if options.prepare then
		options.prepare(loaded)
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_Hunts")
	return loaded, fake
end

-- A history of Casts for the fixture list, as the projection's and the moments' specs append it to fake.catchLog.

--- 2026-03-01 00:00 UTC: every fixture Hunt but fixture_tide_late and fixture_grouper exists then.
support.MARCH_1 = 1772323200
--- Realm minutes: 22:00 (night), 10:00 (day), 19:00 (fixture_oddity's hours).
support.NIGHT, support.DAY, support.DUSK = 1320, 600, 1140

--- The server time of realm minute `minute` on 2026-03-(1 + day), on a realm 7 hours behind UTC (`day` may run past
--- March).
---@param day integer
---@param minute integer
---@return integer
function support.at(day, minute)
	return support.MARCH_1 + day * 86400 + (minute + 420) * 60
end

--- A Cast record for fake.catchLog:Append, by the player's character (char 1), at realm `minute` (night by default)
--- of `day`.
---@param day integer
---@param minute integer?
---@param where { zone: integer, subzone: integer? }
---@param itemIDs integer[]? nil for a got-away Cast
---@param auras integer[]?
---@return table
function support.cast(day, minute, where, itemIDs, auras)
	local items = {}
	for i, itemID in ipairs(itemIDs or {}) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = support.at(day, minute or support.NIGHT),
		outcome = itemIDs and "caught" or "gotAway",
		conditions = {
			minute = minute,
			zone = where.zone,
			subzone = where.subzone or 0,
			events = {},
			auras = auras or {},
		},
		items = items,
	}
end

--- Appends `records` to fake.catchLog (the player's character first) and returns them as appended, Catch IDs and
--- realm dates filled in by Core's codec.
---@param fake table
---@param records table[]
---@return PagleCast[]
function support.append(fake, records)
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	local appended = {}
	for _, record in ipairs(records) do
		appended[#appended + 1] = fake.catchLog:Append(record)
	end
	return appended
end

--- Pagle_Hunts on a FakePagle serving `options.data` as its catalogue, with `history(fake)` appended before login,
--- then logged in and caught up. `options.prepare(loaded)` runs before Hunts' ADDON_LOADED; `options.fake` is a
--- FakePagle already set up (a next session's).
---@param history (fun(fake: table): any)?
---@param options { data: table, prepare: fun(loaded: LoadedAddon)?, fake: table? }
---@return LoadedAddon loaded
---@return table fake
---@return any appended what `history` returned
function support.session(history, options)
	local fake = options.fake or newFakePagle()
	fake.setCatalogue(options.data)
	local appended = history and history(fake)
	local loaded = support.load(fake, { prepare = options.prepare })
	fake.login()
	fake.enterWorld()
	return loaded, fake, appended
end

--- The next session on the same machine: a new FakePagle over the same Catch log and the PagleHuntsDB the last one
--- saved (its global section: the fake client has no strlenutf8 for AceDB's profile keys).
---@param last table the last session's FakePagle
---@param lastLoaded LoadedAddon
---@return table fake
function support.nextSession(last, lastLoaded)
	local fake = newFakePagle()
	fake.catchLog.data = last.catchLog.data
	fake.globals.PagleHuntsDB = { global = lastLoaded.env.PagleHuntsDB.global }
	return fake
end

--- Moves the live conditions to realm `minute` in `where`, with `auras` up (none by default).
---@param fake table
---@param minute integer
---@param where { zone: integer, subzone: integer? }
---@param auras integer[]?
function support.fishAt(fake, minute, where, auras)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	conditions.minute, conditions.zone, conditions.subzone = minute, where.zone, where.subzone or 0
	conditions.auras = auras or {}
	fake.setConditions(conditions)
end

return support
