-- The names Hunts' labels read at runtime (HNT-R53–R55, DATA-R3: no game name ships): items loaded with
-- Item:CreateFromItemID, areas, auras, Size bands and quality colours from the client and Core, and calendar event
-- names looked up once per login, outside restriction (HNT-R53, HNT-R193).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- A Hunt list with an event in its specs: a natural Hunt in the Extravaganza's window (event 301, through
-- Pagle.GetWindowSpec) and an imposed Hunt under event 302, which no calendar lists (DATA-R93's shape).
local EVENT_LIST = {
	fingerprint = "e7e7e7e7e7e7e7e7",
	sets = { { id = "fixture_sunday" } },
	hunts = {
		{
			id = "fixture_tastyfish",
			set = "fixture_sunday",
			kind = "natural",
			since = 1767225600,
			species = 19807,
			window = "event.301",
			tiers = { 1 },
		},
		{
			id = "fixture_unlisted",
			set = "fixture_sunday",
			kind = "imposed",
			since = 1767225600,
			class = "species.any",
			conditions = { events = { 302 } },
			tiers = { 1 },
		},
	},
	classes = {},
}

-- Hunts loaded over the event list, its calendar a stand-in that counts its calls: `months[offset][day]` is that
-- day's events, `{ eventID, title }`, by C_Calendar's month offset from the month shown (`shown`, October 2026 by
-- default; FakePagle's client says today is 11 October 2026).
local function loadWithCalendar(months, shown)
	local loaded, fake = hunts.load()
	local ns = loaded.ns
	ns.hunts = ns.NewHuntList(EVENT_LIST, ns.L)
	local calendar = { opened = 0, monthsRead = {} }
	shown = shown or { year = 2026, month = 10 }
	loaded.env.C_Calendar = {
		OpenCalendar = function()
			calendar.opened = calendar.opened + 1
		end,
		GetMonthInfo = function(offset)
			local month = shown.month + offset
			return { year = shown.year + math.floor((month - 1) / 12), month = (month - 1) % 12 + 1, numDays = 30 }
		end,
		GetNumDayEvents = function(offset, day)
			calendar.monthsRead[offset] = true
			return #((months[offset] or {})[day] or {})
		end,
		GetDayEvent = function(offset, day, index)
			local event = months[offset][day][index]
			return { eventID = event[1], title = event[2] }
		end,
	}
	local redraws = {}
	ns.OnRedraw(function(reason)
		redraws[#redraws + 1] = reason
	end)
	return ns, fake, calendar, redraws
end

local EXTRAVAGANZA = { 301, "Stranglethorn Fishing Extravaganza" }

describe("Hunts' names", function()
	describe("items (HNT-R54, HNT-R55)", function()
		it("reads a loaded item's name and icon from the client", function()
			local loaded = hunts.load()
			loaded.client.itemNames[13759] = "Raw Nightfin Snapper"
			loaded.client.itemIcons[13759] = 133890

			assert.are.equal("Raw Nightfin Snapper", loaded.ns.names.ItemName(13759))
			assert.are.equal(133890, loaded.ns.names.ItemIcon(13759))
		end)

		it("loads an item not cached once, and redraws for names on the frame after it loads", function()
			local loaded = hunts.load()
			local ns, client = loaded.ns, loaded.client
			local redraws = {}
			ns.OnRedraw(function(reason)
				redraws[#redraws + 1] = reason
			end)

			assert.is_nil(ns.names.ItemName(13759))
			assert.is_nil(ns.names.ItemName(13759))
			assert.are.equal(1, #client.itemLoads[13759])
			assert.are.equal("…", ns.HuntTargetLine(ns.hunts:Hunt("fixture_snapper"), ns.hunts, ns.names))

			client.loadItem(13759, "Raw Nightfin Snapper")
			assert.are.same({}, redraws)
			client.runTimers()

			assert.are.same({ "names" }, redraws)
			assert.are.equal(
				"Raw Nightfin Snapper",
				ns.HuntTargetLine(ns.hunts:Hunt("fixture_snapper"), ns.hunts, ns.names)
			)
		end)

		it("redraws once for items that load in the same frame", function()
			local loaded = hunts.load()
			local ns, client = loaded.ns, loaded.client
			local redraws = {}
			ns.OnRedraw(function(reason)
				redraws[#redraws + 1] = reason
			end)
			ns.HuntTargetLine(ns.hunts:Hunt("fixture_oddity"), ns.hunts, ns.names)

			client.loadItem(6522, "Deviate Fish")
			client.loadItem(251524, "Whimsyfin")
			client.runTimers()

			assert.are.same({ "names" }, redraws)
			assert.are.equal(
				"Deviate Fish or Whimsyfin",
				ns.HuntTargetLine(ns.hunts:Hunt("fixture_oddity"), ns.hunts, ns.names)
			)
		end)
	end)

	describe("areas, auras, bands and quality colours", function()
		it("reads areas from C_Map.GetAreaInfo and auras from C_Spell.GetSpellName (HNT-R53)", function()
			local loaded = hunts.load()
			loaded.client.areaNames[148] = "Darkshore"
			loaded.env.C_Spell = {
				GetSpellName = function(spellID)
					return spellID == 1280341 and "Fishing Rack" or nil
				end,
			}

			assert.are.equal(
				"Realm time 22:00–04:00 · In Darkshore · While Fishing Rack is up",
				loaded.ns.HuntConditionsLine(
					{ time = { { 1320, 240 } }, areas = { 148 }, auras = { 1280341 } },
					nil,
					SERVER_TIME,
					{ time = SERVER_TIME, minute = 495 },
					loaded.ns.names
				)
			)
		end)

		it("reads a band's name from Pagle.SIZE_BANDS: , Hefty or better (HNT-R54)", function()
			local ns = hunts.load().ns
			local hefty = ns.hunts:Hunt("fixture_hefty_blackmouth")

			assert.are.equal("…, Hefty or better", ns.HuntTargetLine(hefty, ns.hunts, ns.names))
		end)

		it("tints a quality class's icon with the client's ITEM_QUALITY_COLORS (HNT-R55)", function()
			local loaded = hunts.load()
			local ns = loaded.ns
			local _, tint = ns.HuntIcon(ns.hunts:Hunt("fixture_rack"), ns.hunts, ns.names)

			assert.are.equal(loaded.env.ITEM_QUALITY_COLORS[2], tint)
		end)
	end)

	describe("calendar event names (HNT-R53)", function()
		it("opens the calendar at the first PLAYER_ENTERING_WORLD, not before, and reads it at its update", function()
			local ns, fake, calendar, redraws = loadWithCalendar({ [0] = { [11] = { EXTRAVAGANZA } } })

			assert.are.equal(0, calendar.opened)
			assert.is_nil(ns.names.EventName(301))
			fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
			assert.are.equal(1, calendar.opened)
			assert.is_nil(ns.names.EventName(301))

			fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")

			assert.are.equal("Stranglethorn Fishing Extravaganza", ns.names.EventName(301))
			assert.are.same({ "names" }, redraws)
		end)

		it("reads an event its Hunts' specs name but no calendar day lists as a calendar event", function()
			local ns, fake = loadWithCalendar({ [0] = { [11] = { EXTRAVAGANZA } } })
			fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
			fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")

			assert.is_false(ns.names.EventName(302))
			assert.are.equal(
				"a calendar event",
				ns.HuntConditionsLine({ events = { 302 } }, nil, SERVER_TIME, {}, ns.names)
			)
		end)

		it("searches the current month and the next, from the month the calendar shows", function()
			-- Paged back to September: October is offset 1 and November offset 2.
			local ns, fake, calendar = loadWithCalendar({
				[0] = { [5] = { { 302, "September's" } } },
				[2] = { [29] = { EXTRAVAGANZA } },
			}, { year = 2026, month = 9 })
			fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
			fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")

			assert.are.equal("Stranglethorn Fishing Extravaganza", ns.names.EventName(301))
			assert.is_false(ns.names.EventName(302))
			assert.are.same({ [1] = true, [2] = true }, calendar.monthsRead)
		end)

		it("opens the calendar once and keeps the names for the login: later events read nothing again", function()
			local months = { [0] = { [11] = { EXTRAVAGANZA } } }
			local ns, fake, calendar, redraws = loadWithCalendar(months)
			fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
			fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")
			months[0][11] = { { 301, "Renamed" } }

			fake.fireGameEvent("PLAYER_ENTERING_WORLD", false, false)
			fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")
			fake.setRestricted(true)
			fake.setRestricted(false)

			assert.are.equal(1, calendar.opened)
			assert.are.equal("Stranglethorn Fishing Extravaganza", ns.names.EventName(301))
			assert.are.same({ "names" }, redraws)
		end)

		it(
			"never touches the calendar while restricted: a first entry in combat opens it at RestrictionChanged(false)",
			function()
				local ns, fake, calendar = loadWithCalendar({ [0] = { [11] = { EXTRAVAGANZA } } })
				fake.setRestricted(true)
				fake.fireGameEvent("PLAYER_ENTERING_WORLD", false, true)

				assert.are.equal(0, calendar.opened)
				fake.setRestricted(false)
				assert.are.equal(1, calendar.opened)
				fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")
				assert.are.equal("Stranglethorn Fishing Extravaganza", ns.names.EventName(301))
			end
		)

		it("waits out a restriction that starts before the calendar's update before reading it", function()
			local ns, fake, calendar = loadWithCalendar({ [0] = { [11] = { EXTRAVAGANZA } } })
			fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
			fake.setRestricted(true)

			fake.fireGameEvent("CALENDAR_UPDATE_EVENT_LIST")
			assert.are.same({}, calendar.monthsRead)
			assert.is_nil(ns.names.EventName(301))

			fake.setRestricted(false)
			assert.are.equal("Stranglethorn Fishing Extravaganza", ns.names.EventName(301))
		end)

		it("opens no calendar for a Hunt list whose specs name no event", function()
			local loaded, fake = hunts.load()
			local opened = 0
			loaded.env.C_Calendar = {
				OpenCalendar = function()
					opened = opened + 1
				end,
			}

			fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)

			assert.are.equal(0, opened)
		end)
	end)
end)
