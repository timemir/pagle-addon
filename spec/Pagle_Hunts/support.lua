-- Loading Pagle_Hunts for its specs: over FakePagle (its catalogue, clock and Module registry) with the fixture Hunt
-- list and event pool in place of the shipped ones, and the fixture lore unless a spec asks for none (hunts.md › Data:
-- "Tests inject their own Hunt list and `since` dates"). Specs load this file with dofile (and the undefined-global suppression
-- every dofile in spec/ carries), then call it:
--
--   local hunts = dofile("spec/Pagle_Hunts/support.lua")
--   local loaded, fake = hunts.load()          -- loaded, not logged in
--   local run = hunts.start({ ... })           -- logged in and grouped: { loaded, fake, ns }
--   local loaded, fake = hunts.login(history, options)   -- a Catch history, logged in and caught up
--
-- The fixture catalogue is `hunts.catalogue` (spec/Pagle_Hunts/fixtures/Catalogue.lua).

local FIXTURE_LIST = "spec/Pagle_Hunts/fixtures/HuntList.lua"
local FIXTURE_LORE = "spec/Pagle_Hunts/fixtures/Lore.lua"
local FIXTURE_EVENTS = "spec/Pagle_Hunts/fixtures/EventList.lua"

local support = {}

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")
--- The fixture catalogue (DATA-R76's shape), for fake.setCatalogue.
support.catalogue = catalogue

-- Runs a fixture file as one of Pagle_Hunts' own files: its globals, its `...` and its ns.
---@param path string
---@param loaded LoadedAddon
local function runAsHunts(path, loaded)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile(path))
	setfenv(chunk, loaded.env)
	chunk("Pagle_Hunts", loaded.ns)
end

--- A binding's look as the stand-in renderer below hands it out (core/book-binding.md, `PagleBindingLook`'s inks): Field
--- Leather's by default, and a cold silver one for any good whose ID says "silver" or "fiveseal".
---@param goodID string?
---@return table
function support.bindingLook(goodID)
	local cold = goodID ~= nil and (goodID:find("silver") ~= nil or goodID:find("fiveseal") ~= nil)
	return {
		id = goodID or "core.binding.fieldleather",
		gilt = cold and { 0.8, 0.82, 0.86 } or { 0.91, 0.79, 0.42 },
		giltShadow = { 0, 0, 0, 0.95, 0, -1 },
		silver = cold,
		paperTint = cold and { 0.95, 0.97, 1 } or { 1, 1, 1 },
	}
end

-- A stand-in for Core's book binding (core/book-binding.md, BIND-R1–R3), for a FakePagle that has none of its own: it
-- draws nothing, wears the pinned good's look or Field Leather's, and calls `onLook` as it is made and at each
-- SetLook. Its `skin` records the look it wears, as FakePagle's own does.
---@param frame table
---@param options { pinned: string?, onLook: fun(look: table)? }?
---@return table
local function newBookBinding(frame, options)
	options = options or {}
	local binding = { frame = frame, skin = { dim = 1 } }
	function binding.SetLook(self, goodID)
		self.pinned = goodID
		self.skin.look = support.bindingLook(goodID)
		if options.onLook then
			options.onLook(self.skin.look)
		end
	end
	function binding.Look(self)
		return self.skin.look
	end
	binding:SetLook(options.pinned)
	return binding
end

--- support.load's options.
---@class HuntsLoadOptions
---@field lore boolean?   -- false loads no fixture lore, so names fall back to IDs (HNT-R1)
---@field list (HuntListData|fun(fixture: HuntListData): HuntListData)?   -- the Hunt list OnInitialize reads in place
--- of the fixture's (or what it makes of the fixture's), as data\HuntList.lua sets it
---@field events (EventListData|fun(fixture: EventListData): EventListData)?   -- the event pool OnInitialize reads in
--- place of the fixture's (or what it makes of the fixture's), as data\EventList.lua sets it
---@field prepare fun(loaded: LoadedAddon)?   -- runs after the fixtures, before ADDON_LOADED, e.g. to change the rules
--- version OnInitialize reads
---@field motion boolean?   -- true leaves Core's Animations setting on; by default it is off, so the board draws settled
--- at once and the specs of what it shows need not wait for its fades, turns and slides (BoardMotion_spec turns it on)

--- Loads Pagle_Hunts on `fake` (a new FakePagle if nil) with the fixture Hunt list and event pool, which replace the
--- shipped data/HuntList.lua and data/EventList.lua, then fires its ADDON_LOADED, so OnInitialize reads the fixtures.
---@param fake table? a FakePagle (newFakePagle()), for a spec that set it up first
---@param options HuntsLoadOptions?
---@return LoadedAddon loaded
---@return table fake
function support.load(fake, options)
	fake = fake or newFakePagle()
	options = options or {}
	-- Core's book binding, until FakePagle has its own (#351)
	if not fake.Pagle.NewBookBinding then
		fake.Pagle.NewBookBinding = newBookBinding
	end
	if not options.motion then
		fake.profile.announcements.motion = false
	end
	-- The client's number formatting, which the Write-up's numbers go through (HNT-R111).
	fake.globals.BreakUpLargeNumbers = fake.globals.BreakUpLargeNumbers or breakUpLargeNumbers
	local loaded = fake.load("Pagle_Hunts", { holdAddonLoaded = true })
	runAsHunts(FIXTURE_LIST, loaded)
	runAsHunts(FIXTURE_EVENTS, loaded)
	if options.lore ~= false then
		runAsHunts(FIXTURE_LORE, loaded)
	end
	local list = options.list
	if type(list) == "function" then
		loaded.ns.huntList = list(loaded.ns.huntList)
	elseif list then
		loaded.ns.huntList = list
	end
	local events = options.events
	if type(events) == "function" then
		loaded.ns.eventList = events(loaded.ns.eventList)
	elseif events then
		loaded.ns.eventList = events
	end
	if options.prepare then
		options.prepare(loaded)
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_Hunts")
	return loaded, fake
end

-- Dates and times the fixtures use (spec/Pagle_Hunts/fixtures/HuntList.lua's header).

--- 2026-01-01 00:00 UTC: the fixture Hunts' since.
support.JAN_1 = 1767225600
--- 2026-06-01 00:00 UTC: the fixture's retired date.
support.JUN_1 = 1780272000
--- 2026-11-04 00:00 UTC: a since after FakePagle's clock.
support.NOV_4 = 1793750400
support.HOUR = 3600
--- FakePagle's realm clock at SERVER_TIME: 08:15 on Sunday 11 October 2026.
support.REALM_START = 8 * 60 + 15
--- FakePagle's live snapshot at SERVER_TIME (LOG-R45), as the logic specs hand it in: realm 08:15 on Sunday 11
--- October 2026 (weekday 1 is Sunday).
support.SUNDAY = {
	time = SERVER_TIME,
	minute = support.REALM_START,
	date = { year = 2026, month = 10, day = 11, weekday = 1 },
}

--- Seconds from FakePagle's start (realm 08:15) to realm `hour`:`minute` the same day (hours past 24 run into the
--- next).
---@param hour integer
---@param minute integer?
---@return integer
function support.untilRealm(hour, minute)
	return (hour * 60 + (minute or 0) - support.REALM_START) * 60
end

--- The server time at realm `hour`:`minute` that day.
---@param hour integer
---@param minute integer?
---@return integer
function support.realm(hour, minute)
	return SERVER_TIME + support.untilRealm(hour, minute)
end

--- HNT-R121's goods by slot, in its order, each with its kind as the table writes it: the specs' oracle, kept apart
--- from the addon's own list (logic/Goods.lua).
support.GOODS = {
	["hunts.notebookcover"] = {
		{ "hunts.notebookcover.leather", "default" },
		{ "hunts.notebookcover.oilcloth", "tier 1" },
		{ "hunts.notebookcover.tooled", "tier 2" },
		{ "hunts.notebookcover.verdigris", "tier 3" },
		{ "hunts.notebookcover.canvas", "tier 1" },
		{ "hunts.notebookcover.kraft", "tier 1" },
		{ "hunts.notebookcover.tartan", "tier 1" },
		{ "hunts.notebookcover.maplinen", "tier 2" },
		{ "hunts.notebookcover.planks", "tier 2" },
		{ "hunts.notebookcover.snakeskin", "tier 3" },
		{ "hunts.notebookcover.shagreen", "tier 3" },
		{ "hunts.notebookcover.lacquer", "tier 3" },
		{ "hunts.notebookcover.bone", "tier 3" },
		{ "hunts.notebookcover.brasscase", "tier 3" },
		{ "hunts.notebookcover.scrimshaw", "tier 4" },
		{ "hunts.notebookcover.trophycase", "tier 5" },
		{ "hunts.notebookcover.pathfinder", "earned" },
		{ "hunts.notebookcover.fiveseal", "earned" },
		{ "hunts.notebookcover.wagersilk", "earned" },
	},
	["hunts.trackerframe"] = {
		{ "hunts.trackerframe.none", "default" },
		{ "hunts.trackerframe.inkwash", "tier 1" },
		{ "hunts.trackerframe.waxseal", "tier 2" },
		{ "hunts.trackerframe.slate", "tier 1" },
		{ "hunts.trackerframe.mapscrap", "tier 1" },
		{ "hunts.trackerframe.bounty", "tier 2" },
		{ "hunts.trackerframe.spyglass", "tier 3" },
		{ "hunts.trackerframe.wagerribbon", "earned" },
	},
}

--- A Hunts run on FakePagle: what support.start returns.
---@class HuntsRun
---@field loaded LoadedAddon
---@field fake table
---@field ns table

--- The client loads the names of the fixture catalogue's items and areas (catalogue.NAMES).
---@param loaded LoadedAddon
function support.loadNames(loaded)
	for itemID, name in pairs(catalogue.NAMES.items) do
		loaded.client.loadItem(itemID, name)
	end
	for areaID, name in pairs(catalogue.NAMES.areas) do
		loaded.client.areaNames[areaID] = name
	end
end

--- Hunts on a FakePagle (`options.fake`, or a new one) over `options.catalogue` (the fixture's by default), through
--- its first PLAYER_ENTERING_WORLD, so the first grouping has run (HNT-R42):
--- - `saved` is PagleHuntsDB, and `history(fake)` is appended to the Catch log before login;
--- - `list`, `events`, `prepare` and `motion` go to support.load, and `names` (default false) loads catalogue.NAMES;
--- - the server time runs on the client's clock, from `from` seconds after SERVER_TIME (realm 08:15), so the client's
---   C_Timer and the grouping's "now" move together;
--- - `beforeLogin(run)` runs once loaded (e.g. to listen to regroups), `afterLogin(run)` once logged in;
--- - Fishing is read at `skill` (150 by default; false for none, so every Hunt with a skill need is short);
--- - `caughtUp` false stays before enterWorld, so the projection stays updating (HNT-R69);
--- - `restricted` puts the player in combat before the world (a `/reload` in combat);
--- - `beforeGrouping(run)` runs just before the first PLAYER_ENTERING_WORLD, and `world` false stops there.
---@param options { fake: table?, catalogue: table?, saved: table?, history: fun(fake: table)?, list: any, events: any, prepare: fun(loaded: LoadedAddon)?, motion: boolean?, names: boolean?, from: integer?, beforeLogin: fun(run: HuntsRun)?, afterLogin: fun(run: HuntsRun)?, beforeGrouping: fun(run: HuntsRun)?, skill: integer|false|nil, caughtUp: boolean?, restricted: boolean?, world: boolean? }?
---@return HuntsRun
function support.start(options)
	options = options or {}
	local fake = options.fake or newFakePagle()
	fake.setCatalogue(options.catalogue or catalogue.base())
	local clock
	fake.globals.GetServerTime = function()
		return SERVER_TIME + (options.from or 0) + math.floor(clock and clock() or 0)
	end
	fake.globals.PagleHuntsDB = options.saved
	if options.history then
		options.history(fake)
	end
	local loaded = support.load(
		fake,
		{ list = options.list, events = options.events, prepare = options.prepare, motion = options.motion }
	)
	clock = loaded.client.time
	if options.names then
		support.loadNames(loaded)
	end
	local run = { loaded = loaded, fake = fake, ns = loaded.ns }
	if options.beforeLogin then
		options.beforeLogin(run)
	end
	fake.login()
	if options.afterLogin then
		options.afterLogin(run)
	end
	if options.skill ~= false then
		fake.readSkill(options.skill or 150, 300, 0)
	end
	if options.restricted then
		fake.setRestricted(true)
	end
	if options.caughtUp ~= false then
		fake.enterWorld()
	end
	if options.beforeGrouping then
		options.beforeGrouping(run)
	end
	if options.world ~= false then
		fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
	end
	return run
end

--- Moves the client's clock (and so the server time) on, running each C_Timer that comes due.
---@param run HuntsRun
---@param seconds integer
function support.wait(run, seconds)
	run.loaded.client.advance(seconds)
end

--- Serves `huntsProgress` (by Hunt ID) and `sets` (titles by set ID) as the projection's state, a new one at each
--- read (ns.NewHuntsState()'s shape), updating or not: the hand-made state views read through ns.State() and
--- ns.IsUpdating() (logic/Seams.lua).
---@param run HuntsRun
---@param huntsProgress table<string, HuntProgress>?
---@param sets table<string, HuntsSetTitle>?
---@param updating boolean?
function support.useState(run, huntsProgress, sets, updating)
	run.ns.projection = {
		GetState = function()
			local state = run.ns.NewHuntsState()
			state.hunts, state.sets = huntsProgress or {}, sets or {}
			return state
		end,
		IsUpdating = function()
			return updating == true
		end,
	}
end

--- A Hunt's progress (HuntProgress, hunts.md › Projection state): `count` Catches (the reached tiers' number by
--- default), `effort` effort Casts and `sinceLast`, with its first `tiers` tiers reached at `time` on realm `date`
--- (2026-01-01 by default), each by a Catch of `itemID` (Raw Nightfin Snapper) in `zone` (Darkshore).
---@param fields { count: integer?, effort: integer?, sinceLast: integer?, tiers: integer?, time: integer?, date: table?, itemID: integer?, zone: integer? }
---@return HuntProgress
function support.progress(fields)
	local tiers = fields.tiers or 0
	local count = fields.count or tiers
	local reached = {}
	for k = 1, tiers do
		reached[k] = {
			time = fields.time or support.JAN_1,
			catchId = "c" .. k,
			itemID = fields.itemID or catalogue.NIGHTFIN,
			zone = fields.zone or catalogue.DARKSHORE,
			date = fields.date or { year = 2026, month = 1, day = 1 },
		}
	end
	return {
		count = count,
		effort = fields.effort or 0,
		sinceLast = fields.sinceLast or 0,
		caught = count > 0,
		reached = reached,
	}
end

--- Hunts the fixture list lacks, made over imposed Hunts `extra_1`, `extra_2`, … of set fixture_extra (DATA-R93), each
--- with `huntFields` over it, as one list with `classes` (none by default).
---@param huntFields table[]
---@param classes table<string, table<integer, true>>?
---@return HuntListData
function support.extraList(huntFields, classes)
	local list = { fingerprint = "e", sets = { { id = "fixture_extra" } }, hunts = {}, classes = classes or {} }
	for i, fields in ipairs(huntFields) do
		local hunt = {
			id = "extra_" .. i,
			set = "fixture_extra",
			kind = "imposed",
			since = support.JAN_1,
			tiers = { 1 },
		}
		for key, value in pairs(fields) do
			hunt[key] = value
		end
		list.hunts[i] = hunt
	end
	return list
end

--- A copy of the `fixture` Hunt list with `sets` and `huntDefs` appended (DATA-R93).
---@param fixture HuntListData
---@param sets table[]
---@param huntDefs table[]
---@return HuntListData
function support.withExtra(fixture, sets, huntDefs)
	local list = { fingerprint = fixture.fingerprint, sets = {}, hunts = {}, classes = fixture.classes }
	for _, part in ipairs({ { list.sets, fixture.sets }, { list.sets, sets }, { list.hunts, fixture.hunts } }) do
		for _, entry in ipairs(part[2]) do
			part[1][#part[1] + 1] = entry
		end
	end
	for _, hunt in ipairs(huntDefs) do
		list.hunts[#list.hunts + 1] = hunt
	end
	return list
end

--- The live conditions with `changes` made, as the next snapshot: setConditions fires ConditionsChanged.
---@param fake table
---@param changes table
function support.setConditions(fake, changes)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	for key, value in pairs(changes) do
		conditions[key] = value
	end
	fake.setConditions(conditions)
end

--- Whether `list` holds `value`.
---@param list any[]
---@param value any
---@return boolean
function support.has(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

--- The `id` of each of `rows`, in order.
---@param rows { id: string }[]
---@return string[]
function support.ids(rows)
	local out = {}
	for i, row in ipairs(rows) do
		out[i] = row.id
	end
	return out
end

--- A deep copy of `value`.
---@generic T
---@param value T
---@return T
function support.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, v in pairs(value) do
		copy[key] = support.deepCopy(v)
	end
	return copy
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

--- Pagle_Hunts on a FakePagle serving `options.data` (the fixture catalogue by default) as its catalogue, with
--- `history(fake)` appended before login, then logged in and caught up. `options.prepare(loaded)` runs before Hunts'
--- ADDON_LOADED; `options.fake` is a FakePagle already set up (a next login's).
---@param history (fun(fake: table): any)?
---@param options { data: table?, prepare: fun(loaded: LoadedAddon)?, fake: table?, events: any }?
---@return LoadedAddon loaded
---@return table fake
---@return any appended what `history` returned
function support.login(history, options)
	options = options or {}
	local fake = options.fake or newFakePagle()
	fake.setCatalogue(options.data or catalogue.base())
	local appended = history and history(fake)
	local loaded = support.load(fake, { prepare = options.prepare, events = options.events })
	fake.login()
	fake.enterWorld()
	return loaded, fake, appended
end

--- The next login on the same machine: a new FakePagle over the same Catch log and the PagleHuntsDB the last one
--- saved (its global section: the fake client has no strlenutf8 for AceDB's profile keys).
---@param last table the last login's FakePagle
---@param lastLoaded LoadedAddon
---@return table fake
function support.nextLogin(last, lastLoaded)
	local fake = newFakePagle()
	fake.catchLog.data = last.catchLog.data
	fake.globals.PagleHuntsDB = { global = lastLoaded.env.PagleHuntsDB.global }
	return fake
end

--- One of Hunts' own Module records (LOG-R40, ADR 0008) for fake.catchLog:Append, by the player's character at
--- server time `time`: kind `run` or `def` with `payload` (hunts.md › Contracts). support.append appends it.
---@param kind string
---@param payload string
---@param time integer
---@return table
function support.record(kind, payload, time)
	return { kind = "module", char = 1, time = time, module = "Hunts", recordKind = kind, payload = payload }
end

--- A `run` record's payload (HNT-R150), written here apart from logic/Records.lua: `<eventID>|<start>|<end>|<source>`.
---@param event string
---@param start integer
---@param end_ integer
---@param source string? "r" by default
---@return string
function support.runPayload(event, start, end_, source)
	return ("%s|%d|%d|%s"):format(event, start, end_, source or "r")
end

--- Moves the live conditions to realm `minute` in `where`, with `auras` up (none by default).
---@param fake table
---@param minute integer
---@param where { zone: integer, subzone: integer? }
---@param auras integer[]?
function support.fishAt(fake, minute, where, auras)
	support.setConditions(fake, {
		minute = minute,
		zone = where.zone,
		subzone = where.subzone or 0,
		auras = auras or {},
	})
end

--- A new copy of the banded event pool, three rotating events per skill band (spec/Pagle_Hunts/fixtures/
--- BandedEventList.lua), for support.load's or support.start's `events`.
---@return EventListData
function support.bandedEvents()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	return dofile("spec/Pagle_Hunts/fixtures/BandedEventList.lua")
end

return support
