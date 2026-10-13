-- The live conditions service as Core runs it against the client: the Cast snapshot's raw observations (LOG-R20,
-- LOG-R21), Pagle.GetConditions (LOG-R45), active calendar events (LOG-R46) and ConditionsChanged (LOG-R47).

-- A value the client hands out as secret: issecretvalue is true for it alone (CORE-R31).
local SECRET = setmetatable({}, {
	__tostring = function()
		return "<secret>"
	end,
})

local NAMES = { [141] = "Teldrassil", [148] = "Darkshore", [453] = "The Long Wash" }

-- A catalogue in the M1 shape (DATA-R79): Darkshore (148) with The Long Wash (453), and Teldrassil (141), all on
-- Kalimdor (1); the Extravaganza (301) and Hallow's End (324) on the event list; two fishing auras.
local function fixture()
	local function area(parent)
		return { parent = parent, continent = 1, hasData = false, skillBaseConfirmed = false, catches = {} }
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {},
		areas = { [141] = area(0), [148] = area(0), [453] = area(148) },
		aliases = {},
		pools = {},
		windows = {},
		events = { [301] = {}, [324] = {} },
		fishingSpells = { 7620 },
		auras = { 1265220, 1280341 },
	}
end

-- What the client reports, which a spec changes between reads: fishing in The Long Wash at realm 08:14 on Sunday
-- 11 October 2026, Fishing 86+25 with lure 263 on, the Rack's aura (1280341) up, and today's calendar holding the
-- Extravaganza (14:00–16:00), the middle of Hallow's End and a Call to Arms that isn't on the event list.
local function newWorld()
	local function at(monthDay, hour, minute)
		return { year = 2026, month = 10, monthDay = monthDay, hour = hour, minute = minute }
	end
	return {
		serverTime = 1791731640,
		gameTime = { 8, 14 },
		calendarTime = { year = 2026, month = 10, monthDay = 11, weekday = 1, hour = 8, minute = 14 },
		shownMonth = { year = 2026, month = 10, numDays = 31, firstWeekday = 5 },
		uiMap = 1439,
		continent = 1,
		zoneText = "Darkshore",
		subzoneText = "The Long Wash",
		skill = { rank = 86, max = 150, mod = 25, line = 356 },
		lure = 263,
		auras = { [1280341] = true },
		dayEvents = {
			[10] = {},
			[11] = {
				{ eventID = 1840, sequenceType = "ONGOING", startTime = at(6, 0, 0), endTime = at(31, 23, 59) },
				{ eventID = 324, sequenceType = "ONGOING", startTime = at(10, 10, 0), endTime = at(31, 11, 0) },
				{ eventID = 301, sequenceType = "", startTime = at(11, 14, 0), endTime = at(11, 16, 0) },
			},
		},
		dayEventsAsked = {},
		combat = false,
	}
end

-- Client stubs that answer from `world`. A world field set to SECRET comes back secret.
local function clientOf(world)
	---@type table<string, any>
	local globals = {
		issecretvalue = function(value)
			return value == SECRET
		end,
		InCombatLockdown = function()
			return world.combat
		end,
		GetServerTime = function()
			return world.serverTime
		end,
		GetGameTime = function()
			if world.gameTime == SECRET then
				return SECRET, SECRET
			end
			return world.gameTime[1], world.gameTime[2]
		end,
		C_DateAndTime = {
			GetCurrentCalendarTime = function()
				return world.calendarTime
			end,
		},
		C_Map = {
			GetAreaInfo = function(id)
				return NAMES[id]
			end,
			GetBestMapForUnit = function(unit)
				return unit == "player" and world.uiMap or nil
			end,
		},
		GetRealZoneText = function()
			return world.zoneText
		end,
		GetSubZoneText = function()
			return world.subzoneText
		end,
		GetInstanceInfo = function()
			return "Kalimdor", "none", 0, "", 0, 0, false, world.continent, 0, nil, false
		end,
		-- Fishing is the 4th return, as GetProfessions gives it (probe report 70338 › 7: 7, nil, 5, 8, 6).
		GetProfessions = function()
			return 7, nil, 5, 8, 6
		end,
		GetProfessionInfo = function(index)
			local skill = world.skill
			if index == 8 then
				return "Fishing", 136245, skill.rank, skill.max, 2, 34, skill.line, skill.mod, -1, 0, "Fishing"
			end
			return "Tailoring", 136249, 29, 75, 1, 32, 197, 0, -1, 0, "Tailoring"
		end,
		GetWeaponEnchantInfo = function()
			if world.lure == nil then
				return false, nil, nil, nil, false, nil, nil, nil, false, nil, nil, nil
			end
			return true, 251777, 0, world.lure, false, nil, nil, nil, false, nil, nil, nil
		end,
		C_UnitAuras = {
			GetPlayerAuraBySpellID = function(spellID)
				if world.auras == SECRET then
					return SECRET
				elseif world.auras == "raise" then
					error("auras are secret")
				end
				return world.auras[spellID] and { spellId = spellID } or nil
			end,
		},
		C_Calendar = {
			OpenCalendar = function()
				world.calendarOpened = true
			end,
			GetMonthInfo = function()
				return world.shownMonth
			end,
			GetNumDayEvents = function(offset, monthDay)
				world.dayEventsAsked[#world.dayEventsAsked + 1] = { offset, monthDay }
				if world.dayEvents == SECRET then
					return SECRET
				end
				local month = world.dayEvents[offset == 0 and monthDay or -1] or {}
				return #month
			end,
			GetDayEvent = function(offset, monthDay, index)
				return world.dayEvents[offset == 0 and monthDay or -1][index]
			end,
		},
	}
	for key, value in pairs(FOREVER_GLOBALS) do
		globals[key] = value
	end
	return globals
end

-- Loads Core over the fixture catalogue against `world`, fires ADDON_LOADED and, unless `beforeLogin`,
-- PLAYER_LOGIN. Records each ConditionsChanged payload in `fired`.
local function load(world, beforeLogin)
	local loaded = loadAddon("Pagle", clientOf(world), { holdAddonLoaded = true })
	loaded.ns.catalogue = fixture()
	local fired = {}
	loaded.env.Pagle.RegisterCallback("Spec", "ConditionsChanged", function(_, changedKeys)
		fired[#fired + 1] = changedKeys
	end)
	loaded.client.fire("ADDON_LOADED", "Pagle")
	if not beforeLogin then
		loaded.client.fire("PLAYER_LOGIN")
	end
	return loaded, fired
end

describe("Pagle.GetConditions", function()
	it("reads every Cast snapshot field, the realm date and the restriction flag (LOG-R20, LOG-R45)", function()
		local Pagle = load(newWorld()).env.Pagle
		assert.are.same({
			time = 1791731640,
			minute = 494,
			date = { year = 2026, month = 10, day = 11, weekday = 1 },
			uiMap = 1439,
			instance = 1,
			zone = 148,
			subzone = 453,
			skillRank = 86,
			skillMod = 25,
			lure = 263,
			events = { 324 },
			auras = { 1280341 },
			restricted = false,
		}, Pagle.GetConditions())
	end)

	it("holds no weather and no pool field (LOG-R21)", function()
		local conditions = load(newWorld()).env.Pagle.GetConditions()
		for _, field in ipairs({ "weather", "pool", "pools" }) do
			assert.is_nil(conditions[field])
		end
	end)

	it("reads a fresh snapshot on each call (LOG-R45)", function()
		local world = newWorld()
		local Pagle = load(world).env.Pagle
		local before = Pagle.GetConditions()
		world.lure = nil
		world.gameTime = { 9, 0 }
		local after = Pagle.GetConditions()
		assert.are.equal(263, before.lure)
		assert.is_nil(after.lure)
		assert.are.equal(540, after.minute)
	end)

	it("is restricted in combat (LOG-R45, CORE-R30)", function()
		local world = newWorld()
		world.combat = true
		assert.is_true(load(world).env.Pagle.GetConditions().restricted)
	end)

	it("gives 0 for a zone or subzone that doesn't resolve (LOG-R20, LOG-R22)", function()
		local world = newWorld()
		world.subzoneText = "Somewhere New"
		local conditions = load(world).env.Pagle.GetConditions()
		assert.are.equal(148, conditions.zone)
		assert.are.equal(0, conditions.subzone)

		world.zoneText = "Nowhere"
		conditions = load(world).env.Pagle.GetConditions()
		assert.are.equal(0, conditions.zone)
		assert.are.equal(0, conditions.subzone)
	end)

	it("has no skill when the fishing profession isn't known (LOG-R30)", function()
		local world = newWorld()
		local loaded = load(world)
		loaded.env.GetProfessions = function()
			return 7, nil, 5, nil, 6
		end
		local conditions = loaded.env.Pagle.GetConditions()
		assert.is_nil(conditions.skillRank)
		assert.is_nil(conditions.skillMod)
	end)

	it("finds Fishing by its skill line, whichever GetProfessions return holds it (LOG-R30)", function()
		local world = newWorld()
		local loaded = load(world)
		loaded.env.GetProfessions = function()
			return 8, nil, 5, nil, 6
		end
		local conditions = loaded.env.Pagle.GetConditions()
		assert.are.same({ 86, 25 }, { conditions.skillRank, conditions.skillMod })
	end)

	describe("with secret values", function()
		it("reads each secret value as nil (LOG-R45, CORE-R31)", function()
			-- Secret only after login, which keys the character by a real server time (LOG-R25).
			local world = newWorld()
			local Pagle = load(world).env.Pagle
			world.serverTime = SECRET
			world.gameTime = SECRET
			world.uiMap = SECRET
			world.continent = SECRET
			world.lure = SECRET
			world.skill.rank = SECRET
			world.skill.mod = SECRET
			world.auras = SECRET
			local conditions = Pagle.GetConditions()
			for _, field in ipairs({ "time", "minute", "uiMap", "instance", "lure", "skillRank", "skillMod", "auras" }) do
				assert(conditions[field] == nil, field .. " should be nil")
			end
		end)

		it("reads a secret zone or subzone text as 0 (LOG-R20, Entry formats)", function()
			local world = newWorld()
			world.zoneText = SECRET
			world.subzoneText = SECRET
			local conditions = load(world).env.Pagle.GetConditions()
			assert.are.equal(0, conditions.zone)
			assert.are.equal(0, conditions.subzone)
		end)

		it("counts secret calendar data as no events (LOG-R46, LOG-R93)", function()
			local world = newWorld()
			world.dayEvents = SECRET
			assert.are.same({}, load(world).env.Pagle.GetConditions().events)

			world = newWorld()
			world.dayEvents[11][3].startTime.hour = SECRET
			assert.are.same({}, load(world).env.Pagle.GetConditions().events)
		end)

		it("has no realm date, and no events, while the calendar time is secret (LOG-R45, LOG-R46)", function()
			local world = newWorld()
			world.calendarTime = SECRET
			local conditions = load(world).env.Pagle.GetConditions()
			assert.is_nil(conditions.date)
			assert.are.same({}, conditions.events)
		end)

		it("has no aura list when reading auras raises, as it does while they're secret (LOG-R45)", function()
			local world = newWorld()
			world.auras = "raise"
			assert.is_nil(load(world).env.Pagle.GetConditions().auras)
		end)
	end)

	it("reads today's events from the current month while the calendar shows another (LOG-R46)", function()
		local world = newWorld()
		world.shownMonth = { year = 2026, month = 8, numDays = 31, firstWeekday = 7 }
		local Pagle = load(world).env.Pagle
		world.dayEventsAsked = {}
		Pagle.GetConditions()
		assert.are.same({ 2, 11 }, world.dayEventsAsked[1])
	end)
end)

describe("ns.TakeSnapshot", function()
	it("reads a Cast's raw observations, without the realm date or the restriction flag (LOG-R20)", function()
		local snapshot = load(newWorld()).ns.TakeSnapshot()
		assert.are.same({
			time = 1791731640,
			minute = 494,
			uiMap = 1439,
			instance = 1,
			zone = 148,
			subzone = 453,
			skillRank = 86,
			skillMod = 25,
			lure = 263,
			events = { 324 },
			auras = { 1280341 },
		}, snapshot)
	end)

	it("gives the zone and subzone texts that didn't resolve, for the diagnostics buffer (LOG-R22, LOG-R81)", function()
		local world = newWorld()
		world.subzoneText = "Somewhere New"
		local _, unresolved = load(world).ns.TakeSnapshot()
		assert.are.same({ zone = "Darkshore", subzone = "Somewhere New" }, unresolved)

		local _, none = load(newWorld()).ns.TakeSnapshot()
		assert.is_nil(none)
	end)
end)

describe("ConditionsChanged", function()
	it("doesn't fire at login: the first reading is the baseline (LOG-R47)", function()
		local _, fired = load(newWorld())
		assert.are.same({}, fired)
	end)

	it("asks the server for calendar data at login (LOG-R46)", function()
		local world = newWorld()
		local loaded = load(world, true)
		assert.is_nil(world.calendarOpened)
		loaded.client.fire("PLAYER_LOGIN")
		assert.is_true(world.calendarOpened)
	end)

	it("fires area on a zone-change event that changed the zone or subzone (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.subzoneText = ""
		loaded.client.fire("ZONE_CHANGED")
		world.zoneText = "Teldrassil"
		loaded.client.fire("ZONE_CHANGED_NEW_AREA")
		world.zoneText = "Darkshore"
		world.subzoneText = "The Long Wash"
		loaded.client.fire("ZONE_CHANGED_INDOORS")
		assert.are.same({ { "area" }, { "area" }, { "area" } }, fired)
	end)

	it("doesn't fire for a zone-change event that changed nothing (LOG-R47)", function()
		local loaded, fired = load(newWorld())
		loaded.client.fire("ZONE_CHANGED")
		assert.are.same({}, fired)
	end)

	it("fires auras on the player's UNIT_AURA that changed a fishing aura, and for no other unit (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.auras = {}
		loaded.client.fire("UNIT_AURA", "target")
		assert.are.same({}, fired)
		loaded.client.fire("UNIT_AURA", "player")
		assert.are.same({ { "auras" } }, fired)
	end)

	it("polls the lure every 5 s (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.lure = nil
		loaded.client.advance(4.9)
		assert.are.same({}, fired)
		loaded.client.advance(0.1)
		assert.are.same({ { "lure" } }, fired)
		world.lure = 264
		loaded.client.advance(5)
		assert.are.same({ { "lure" }, { "lure" } }, fired)
	end)

	it("polls the calendar every 60 s (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.dayEvents[11] = {}
		loaded.client.advance(59)
		assert.are.same({}, fired)
		loaded.client.advance(1)
		assert.are.same({ { "events" } }, fired)
	end)

	it("reads the calendar on CALENDAR_UPDATE_EVENT_LIST (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.dayEvents[11] = {}
		loaded.client.fire("CALENDAR_UPDATE_EVENT_LIST")
		assert.are.same({ { "events" } }, fired)
	end)

	it("fires events when the realm time passes an event's start or end (LOG-R46, LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.calendarTime.hour, world.calendarTime.minute = 14, 0
		loaded.client.advance(60)
		assert.are.same({ { "events" } }, fired)
	end)

	it("fires nothing for the passing of realm time alone (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.serverTime = world.serverTime + 3600
		world.gameTime = { 9, 14 }
		world.calendarTime.hour = 9
		loaded.client.advance(600)
		loaded.client.fire("ZONE_CHANGED")
		loaded.client.fire("UNIT_AURA", "player")
		loaded.client.fire("CALENDAR_UPDATE_EVENT_LIST")
		assert.are.same({}, fired)
	end)

	it("fires skill, when asked to re-read it, if the rank or modifier changed (LOG-R32, LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		loaded.ns.RefreshConditions("skill")
		assert.are.same({}, fired)
		world.skill.mod = 0
		loaded.ns.RefreshConditions("skill")
		world.skill.max = 225
		loaded.ns.RefreshConditions("skill")
		assert.are.same({ { "skill" } }, fired)
	end)

	it("carries exactly the keys that changed, among those re-read (LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world)
		world.lure = nil
		world.skill.rank = 87
		world.zoneText = "Teldrassil"
		loaded.ns.RefreshConditions("skill", "lure", "events")
		assert.are.same({ { "lure", "skill" } }, fired)
	end)

	it("fires nothing before login, when there is no baseline yet (LOG-R1, LOG-R47)", function()
		local world = newWorld()
		local loaded, fired = load(world, true)
		world.lure = nil
		loaded.ns.RefreshConditions("lure")
		loaded.client.fire("ZONE_CHANGED")
		assert.are.same({}, fired)
	end)
end)
