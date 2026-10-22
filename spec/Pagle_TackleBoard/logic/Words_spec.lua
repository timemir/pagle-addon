-- The board's words (tackle-board.md › Generating a goal, The board view, The tracker): goal text, the kind's label,
-- where a goal is worked, workable here, names and realm times, on FakePagle over the fixture catalogue with the fake
-- client's C_Map and C_Item.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local STRANGLETHORN, FERALAS, DUROTAR, DARKSHORE, BARRENS = 33, 357, 14, 148, 17
local BLACKMOUTH = 6358

-- A goal record (TackleGoalDef) of `kind` and `goalType`, with `need` and `target`.
local function goal(goalType, kind, need, target, items)
	return {
		type = goalType,
		kind = kind,
		tier = goalType == "e" and 0 or 1,
		pay = 10,
		need = need,
		target = target,
		items = items,
	}
end

-- A loaded Tackle Board whose client knows the names TKB-R36's examples use.
local function loadNamed()
	local loaded, fake = board.load()
	loaded.client.areaNames[STRANGLETHORN] = "Stranglethorn Vale"
	loaded.client.areaNames[FERALAS] = "Feralas"
	loaded.client.mapNames[1414] = "Kalimdor"
	loaded.client.itemNames[BLACKMOUTH] = "Oily Blackmouth"
	return loaded, fake
end

describe("the goal text", function()
	it("reads each of TKB-R36's examples from a goal record of its kind and type (TKB-R36)", function()
		local ns = loadNamed().ns

		local cases = {
			{ "30 Catches in Stranglethorn Vale", goal("n", "haul", 30, STRANGLETHORN) },
			{ "4 different Species in Feralas", goal("n", "variety", 4, FERALAS) },
			{ "Every Species of Feralas", goal("e", "variety", 3, FERALAS, { 4603, 13754, 13760 }) },
			{ "Catches in 3 zones today", goal("n", "wanderer", 3) },
			{ "Catches in 5 zones of Kalimdor", goal("e", "wanderer", 5, 1) },
			{ "5 uncommon-or-better Catches", goal("n", "quality", 5, 2) },
			{ "3 rare-or-better Catches", goal("e", "quality", 3, 3) },
			{ "A junk item and a container today", goal("n", "collector", 2) },
			{ "3 Sub-collection items you don't have", goal("e", "collector", 3) },
			{ "20 Catches with a lure on", goal("n", "lure", 20) },
			{ "10 Oily Blackmouth", goal("n", "species", 10, BLACKMOUTH) },
		}
		local expected, texts = {}, {}
		for i, case in ipairs(cases) do
			expected[i], texts[i] = case[1], ns.GoalText(case[2])
		end

		assert.are.same(expected, texts)
	end)

	it("reads an Expedition's Haul like a Notice's, with its own need (TKB-R36, TKB-R34)", function()
		local ns = loadNamed().ns

		assert.are.equal("150 Catches in Stranglethorn Vale", ns.GoalText(goal("e", "haul", 150, STRANGLETHORN)))
	end)

	it('shows a zone or continent the client has no name for by its ID, "Area {id}" (TKB-R36)', function()
		local ns = board.load().ns

		assert.are.same({ "20 Catches in Area 14", "Catches in 5 zones of Continent 0", "Area 99999" }, {
			ns.GoalText(goal("n", "haul", 20, DUROTAR)),
			ns.GoalText(goal("e", "wanderer", 5, 0)),
			ns.ZoneName(99999),
		})
	end)

	describe("of a Species goal", function()
		it('reads "10 …" until the client has the name, and asks for it once (TKB-R36)', function()
			local loaded = board.load()
			local species = goal("n", "species", 10, BLACKMOUTH)

			local first, second = loaded.ns.GoalText(species), loaded.ns.GoalText(species)

			assert.are.same({ "10 …", "10 …" }, { first, second })
			assert.are.same({ BLACKMOUTH }, loaded.client.itemRequests)
		end)

		it("redraws once with the name on the next frame, however many arrive in it (TKB-R36)", function()
			local loaded, fake = board.load()
			local reasons = {}
			loaded.ns.OnRedraw(function(reason)
				reasons[#reasons + 1] = reason
			end)
			loaded.ns.GoalText(goal("n", "species", 10, BLACKMOUTH))
			loaded.ns.GoalText(goal("n", "species", 5, 6359))

			loaded.client.itemNames[BLACKMOUTH] = "Oily Blackmouth"
			loaded.client.itemNames[6359] = "Raw Firefin Snapper"
			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", BLACKMOUTH, true)
			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", 6359, true)
			assert.are.same({}, reasons, "the redraw waits for the next frame")
			loaded.client.runTimers()

			assert.are.same({ "names" }, reasons)
			assert.are.equal("10 Oily Blackmouth", loaded.ns.GoalText(goal("n", "species", 10, BLACKMOUTH)))
		end)

		it("redraws nothing for an item no name asked for, or one that failed to load (TKB-R36)", function()
			local loaded, fake = board.load()
			local reasons = {}
			loaded.ns.OnRedraw(function(reason)
				reasons[#reasons + 1] = reason
			end)
			loaded.ns.GoalText(goal("n", "species", 10, BLACKMOUTH))

			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", 2589, true)
			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", BLACKMOUTH, false)
			loaded.client.runTimers()
			loaded.ns.GoalText(goal("n", "species", 10, BLACKMOUTH))

			assert.are.same({}, reasons)
			assert.are.same({ BLACKMOUTH, BLACKMOUTH }, loaded.client.itemRequests, "a failed load is asked again")
		end)
	end)

	it("has no text, label or icon for a size goal, a kind no longer drawn (TKB-R36, ADR 0014)", function()
		local ns = board.load().ns

		assert.is_nil(ns.L.GOAL_TEXT.n.size)
		assert.is_nil(ns.L.GOAL_TEXT.e.size)
		assert.is_nil(ns.L.KINDS.size)
		assert.is_nil(ns.KIND_ICONS.size)
	end)
end)

describe("the kind's label", function()
	it("is the kind's ID capitalised, with one in-client icon per kind (TKB-R102, tackle-board.md › UI)", function()
		local ns = board.load().ns
		local labels, icons, notIcons = {}, {}, {}

		for _, kind in ipairs({ "haul", "variety", "wanderer", "quality", "collector", "lure", "species" }) do
			labels[#labels + 1] = ns.KindLabel(kind)
			local icon = ns.KIND_ICONS[kind]
			icons[icon] = true
			if not (icon and icon:match("^Interface\\Icons\\[%w_]+$")) then
				notIcons[#notIcons + 1] = kind
			end
		end

		local kinds = { "Haul", "Variety", "Wanderer", "Quality", "Collector", "Lure", "Species" }
		assert.are.same(kinds, labels)
		assert.are.same({}, notIcons, "every kind's icon is an in-client icon")
		local distinct = 0
		for _ in pairs(icons) do
			distinct = distinct + 1
		end
		assert.are.equal(7, distinct, "each kind has its own icon")
	end)
end)

describe("ns.Plural", function()
	it("takes the singular form for 1 and the plural otherwise, with {n} filled (CORE-R8)", function()
		local ns = board.load().ns

		assert.are.same({ "1 Catch", "0 Catches", "30 Catches", "1 Coin", "60 Coins" }, {
			ns.Plural(1, "CATCHES"),
			ns.Plural(0, "CATCHES"),
			ns.Plural(30, "CATCHES"),
			ns.Plural(1, "COINS"),
			ns.Plural(60, "COINS"),
		})
	end)

	it("fills any other field it is given (CORE-R8)", function()
		local ns = board.load().ns
		ns.L.TEST_COUNT = { one = "{n} Catch in {zone}", other = "{n} Catches in {zone}" }

		assert.are.equal("2 Catches in Feralas", ns.Plural(2, "TEST_COUNT", { zone = "Feralas" }))
	end)
end)

describe("where a goal is worked", function()
	-- One goal of each kind and type that has a where of its own, on the fixture's zones.
	local function goals()
		return {
			haul = goal("n", "haul", 20, DUROTAR),
			variety = goal("n", "variety", 3, DARKSHORE),
			varietyExpedition = goal("e", "variety", 5, DARKSHORE, { 4603, 6303, 6358, 12238, 13754 }),
			wanderer = goal("n", "wanderer", 3),
			wandererExpedition = goal("e", "wanderer", 5, 1),
			quality = goal("n", "quality", 5, 2),
			qualityExpedition = goal("e", "quality", 3, 3),
			collector = goal("n", "collector", 2),
			collectorExpedition = goal("e", "collector", 3),
			lure = goal("n", "lure", 20),
			species = goal("n", "species", 10, BLACKMOUTH),
		}
	end

	-- `fn(goal)` for each of goals(), by name.
	local function each(fn)
		local results = {}
		for name, g in pairs(goals()) do
			results[name] = fn(g)
		end
		return results
	end

	local function loadPlaces()
		local loaded = board.load()
		loaded.client.areaNames[DUROTAR] = "Durotar"
		loaded.client.areaNames[DARKSHORE] = "Darkshore"
		loaded.client.mapNames[1414] = "Kalimdor"
		return loaded.ns
	end

	it('reads the zone, the continent, "wherever it bites" or "anywhere" by kind (TKB-R102)', function()
		local ns = loadPlaces()

		assert.are.same({
			haul = "Durotar",
			variety = "Darkshore",
			varietyExpedition = "Darkshore",
			wanderer = "anywhere",
			wandererExpedition = "Kalimdor",
			quality = "anywhere",
			qualityExpedition = "anywhere",
			collector = "anywhere",
			collectorExpedition = "anywhere",
			lure = "anywhere",
			species = "wherever it bites",
		}, each(ns.GoalWhere))
	end)

	it("ties haul, variety, the Wanderer Expedition and species goals to a place (TKB-R102)", function()
		local ns = loadPlaces()

		assert.are.same({
			haul = true,
			variety = true,
			varietyExpedition = true,
			wanderer = false,
			wandererExpedition = true,
			quality = false,
			qualityExpedition = false,
			collector = false,
			collectorExpedition = false,
			lure = false,
			species = true,
		}, each(ns.IsPlaceGoal))
	end)

	it("binds only the Wanderer and Collector Notices to one board day (TKB-R41)", function()
		local ns = loadPlaces()
		local bound = {}
		for name, isBound in pairs(each(ns.IsDayBound)) do
			if isBound then
				bound[#bound + 1] = name
			end
		end
		table.sort(bound)

		assert.are.same({ "collector", "wanderer" }, bound)
	end)

	describe("on the tracker", function()
		it('starts with "today · " for a day-bound goal (TKB-R122)', function()
			local ns = loadPlaces()

			assert.are.same(
				{ "today · anywhere", "today · anywhere" },
				{ ns.TrackerWhere(goal("n", "wanderer", 3), true), ns.TrackerWhere(goal("n", "collector", 2), true) }
			)
		end)

		it('ends with " · here" for a goal tied to a place that is workable here (TKB-R122, TKB-R102)', function()
			local ns = loadPlaces()

			assert.are.same({
				"Durotar · here",
				"Kalimdor · here",
				"wherever it bites · here",
				"Durotar",
				"anywhere",
			}, {
				ns.TrackerWhere(goal("n", "haul", 20, DUROTAR), true),
				ns.TrackerWhere(goal("e", "wanderer", 5, 1), true),
				ns.TrackerWhere(goal("n", "species", 10, BLACKMOUTH), true),
				ns.TrackerWhere(goal("n", "haul", 20, DUROTAR), false),
				ns.TrackerWhere(goal("n", "lure", 20), true),
			})
		end)
	end)

	describe("workable here", function()
		local MIGHTFISH, BASS = 13754, 13756
		local ELWYNN, AUBERDINE, FERALAS_ZONE, UNKNOWN = 12, 442, 357, 9999

		it("holds for a haul or variety goal in its own zone only (TKB-R121)", function()
			local ns = board.load().ns
			local haul, variety = goal("n", "haul", 20, DUROTAR), goal("e", "variety", 5, DARKSHORE, { 6303 })

			assert.are.same({ true, false, true, false }, {
				ns.IsWorkableHere(haul, DUROTAR),
				ns.IsWorkableHere(haul, DARKSHORE),
				ns.IsWorkableHere(variety, DARKSHORE),
				ns.IsWorkableHere(variety, AUBERDINE),
			})
		end)

		it("holds for a Wanderer Expedition anywhere on its continent (TKB-R121)", function()
			local ns = board.load().ns
			local kalimdor = goal("e", "wanderer", 5, 1)

			assert.are.same({ true, true, false, false }, {
				ns.IsWorkableHere(kalimdor, DUROTAR),
				ns.IsWorkableHere(kalimdor, FERALAS_ZONE),
				ns.IsWorkableHere(kalimdor, ELWYNN),
				ns.IsWorkableHere(kalimdor, UNKNOWN),
			})
		end)

		it(
			"holds for a Species goal where its Species has a catch entry, by Species, gated or not (TKB-R121)",
			function()
				local ns = board.load().ns
				local mightfish, bass = goal("n", "species", 10, MIGHTFISH), goal("n", "species", 5, BASS)

				assert.are.same({
					-- Darkshore lists Large Raw Mightfish (Species 13754), and Auberdine Mightfish itself
					darkshore = true,
					feralas = true,
					durotar = false,
					-- Bass is in Durotar's list only behind its summer gate
					bassDurotar = true,
					bassBarrens = false,
					unknown = false,
				}, {
					darkshore = ns.IsWorkableHere(mightfish, DARKSHORE),
					feralas = ns.IsWorkableHere(mightfish, FERALAS_ZONE),
					durotar = ns.IsWorkableHere(mightfish, DUROTAR),
					bassDurotar = ns.IsWorkableHere(bass, DUROTAR),
					bassBarrens = ns.IsWorkableHere(bass, BARRENS),
					unknown = ns.IsWorkableHere(mightfish, UNKNOWN),
				})
			end
		)

		it("always holds for every other kind, and in zone 0 only for those (TKB-R121)", function()
			local ns = board.load().ns
			local workable = {}

			for name, g in pairs(goals()) do
				workable[name] = { here = ns.IsWorkableHere(g, ELWYNN), nowhere = ns.IsWorkableHere(g, 0) }
			end

			local always, never = { here = true, nowhere = true }, { here = false, nowhere = false }
			assert.are.same({
				haul = never,
				variety = never,
				varietyExpedition = never,
				wanderer = always,
				wandererExpedition = never,
				quality = always,
				qualityExpedition = always,
				collector = always,
				collectorExpedition = always,
				lure = always,
				species = never,
			}, workable)
		end)

		it("is asked of the current zone, Pagle.GetConditions().zone, read afresh at each call (TKB-R121)", function()
			local loaded, fake = board.load()
			local before = loaded.ns.CurrentZone()
			local conditions = {}
			for key, value in pairs(fake.conditions) do
				conditions[key] = value
			end
			conditions.zone, conditions.subzone = DUROTAR, nil
			fake.setConditions(conditions)

			assert.are.same({ DARKSHORE, DUROTAR }, { before, loaded.ns.CurrentZone() })
		end)

		it("takes no zone (a secret one) as zone 0 (TKB-R121)", function()
			local loaded, fake = board.load()
			local conditions = {}
			for key, value in pairs(fake.conditions) do
				conditions[key] = value
			end
			conditions.zone, conditions.subzone = nil, nil
			fake.setConditions(conditions)

			assert.are.equal(0, loaded.ns.CurrentZone())
		end)
	end)
end)

-- Server times below are UTC epoch seconds. SERVER_TIME is Sunday 11 October 2026 15:15:47 UTC; the fixture realm
-- (support.lua) is at UTC−7, so its clock reads 08:15.
describe("realm dates and times", function()
	local HOUR, MINUTE = 3600, 60

	describe("the realm's UTC offset", function()
		-- Core's LOG-R49 cases (spec/Pagle/logic/Conditions_spec.lua): { server time, realm minute, offset }.
		local CORE_CASES = {
			{ 1791965670, 494, 0 }, -- 08:14 UTC, 08:14 realm
			{ 1791972000, 720, 120 }, -- 10:00 UTC, 12:00 realm
			{ 1792000800, 780, -300 }, -- 18:00 UTC, 13:00 realm
			{ 1791972000, 727, 120 }, -- rounded to 15 minutes: 12:07, 12:08, 11:53 and 11:52 at 10:00 UTC
			{ 1791972000, 728, 135 },
			{ 1791972000, 713, 120 },
			{ 1791972000, 712, 105 },
			{ 1792002600, 0, 330 }, -- 18:30 UTC, 00:00 next day at +05:30
			{ 1792002600, 15, 345 }, -- 18:30 UTC, 00:15 next day at +05:45
			{ 1792015200, 540, 660 }, -- 22:00 UTC, 09:00 next day realm: +11, not -13
			{ 1792033200, 1200, -420 }, -- 03:00 UTC, 20:00 day before realm: -7
			{ 1792015200, 735, -585 }, -- 22:00 UTC, 12:15 realm: -9:45, not +14:15
			{ 1791936000, 780, 780 }, -- 00:00 UTC, 13:00 realm: +13 (NZDT)
			{ 1791979200, 60, 780 }, -- 12:00 UTC, 01:00 next day realm: -11 h wraps to +13
			{ 1791936000, 840, 840 }, -- 00:00 UTC, 14:00 realm: +14 (Kiribati)
			{ 1791975600, 60, 840 }, -- 11:00 UTC, 01:00 next day realm
			{ 1791936000, 720, 720 }, -- 00:00 UTC, 12:00 realm: +12
			{ 1791982800, 60, 720 }, -- 13:00 UTC, 01:00 next day realm
			{ 1791954000, 1140, 840 }, -- 05:00 UTC, 19:00: -10 or +14, read as +14
			{ 1791936000, 848, -585 }, -- +14:08 rounds to +14:15, which is -9:45
			{ 1792018800, 787, 840 }, -- -9:53 rounds to -10:00, which is +14:00
		}

		it(
			"matches LOG-R49's cases, a +13 h realm and one wrapping from −11 h among them (TKB-R105, LOG-R49)",
			function()
				local ns = board.load().ns
				local expected, offsets = {}, {}

				for i, case in ipairs(CORE_CASES) do
					expected[i], offsets[i] = case[3], ns.RealmOffset(case[1], case[2])
				end

				assert.are.same(expected, offsets)
			end
		)

		it(
			"agrees with Core's own LOG-R49 offset at every realm minute of a day (TKB-R105, LOG-R49, ADR 0001)",
			function()
				local ns = board.load().ns
				local core = loadAddon("Pagle", FOREVER_GLOBALS).ns
				local disagreements = {}

				for _, serverTime in ipairs({ 1791936000, 1791954000, 1792015200, 1792002600 }) do
					for realmMinute = 0, 1439, 7 do
						local mine, cores =
							ns.RealmOffset(serverTime, realmMinute), core.RealmUtcOffset(serverTime, realmMinute)
						if mine ~= cores then
							disagreements[#disagreements + 1] = serverTime .. "/" .. realmMinute
						end
					end
				end

				assert.are.same({}, disagreements)
			end
		)
	end)

	describe("ns.RealmDate", function()
		it("converts a server time with the offset read live from the realm clock (TKB-R105)", function()
			local ns = board.load().ns

			assert.are.same(
				{ year = 2026, month = 10, day = 11, weekday = 1, hour = 8, minute = 15 },
				ns.RealmDate(SERVER_TIME)
			)
		end)

		it("is on the realm's day, not UTC's, east of UTC too (TKB-R105)", function()
			local loaded = board.load()
			-- A +13 realm: 15:15 UTC Sunday is 04:15 Monday there.
			loaded.ns.api.GetGameTime = function()
				return 4, 15
			end

			assert.are.same(
				{ year = 2026, month = 10, day = 12, weekday = 2, hour = 4, minute = 15 },
				loaded.ns.RealmDate(SERVER_TIME)
			)
		end)

		it("falls back to UTC while the realm clock is missing (TKB-R105, LOG-R49)", function()
			local loaded = board.load()
			loaded.ns.api.GetGameTime = nil

			assert.are.same(
				{ year = 2026, month = 10, day = 11, weekday = 1, hour = 15, minute = 15 },
				loaded.ns.RealmDate(SERVER_TIME)
			)
		end)
	end)

	it("writes the posted time in Core's clock format, 12-hour when it is set so (TKB-R102, CORE-R87)", function()
		local loaded, fake = board.load()
		fake.profile.clockFormat = "12h"

		assert.are.same({ "Posted Sun 11 Oct, 8:15 am", "Posted Sat 10 Oct, 11:15 pm" }, {
			loaded.ns.PostedTime(SERVER_TIME),
			loaded.ns.PostedTime(SERVER_TIME - 9 * HOUR),
		})
	end)

	it('posts a goal at "Posted {weekday} {day} {month}, {hh:mm}", realm-local and 24-hour (TKB-R102)', function()
		local ns = board.load().ns

		assert.are.same({
			"Posted Sun 11 Oct, 08:15",
			-- 06:15 UTC on Sunday is still Saturday on the realm
			"Posted Sat 10 Oct, 23:15",
			"Posted Thu 1 Oct, 17:05",
		}, {
			ns.PostedTime(SERVER_TIME),
			ns.PostedTime(SERVER_TIME - 9 * HOUR),
			ns.PostedTime(SERVER_TIME - 10 * 24 * HOUR + 8 * HOUR + 50 * MINUTE),
		})
	end)

	it("names the realm weekday of a server time, Sun–Sat (TKB-R105)", function()
		local loaded = board.load()
		local onUSRealm = loaded.ns.WeekdayName(board.WEEKLY_RESET)
		local week = {}
		for day = 0, 6 do
			week[#week + 1] = loaded.ns.WeekdayName(SERVER_TIME + day * 24 * HOUR)
		end
		loaded.ns.api.GetGameTime = function()
			return 4, 15 -- a +13 realm, where the Tuesday 15:00 UTC reset is Wednesday 04:00
		end
		local onNZRealm = loaded.ns.WeekdayName(board.WEEKLY_RESET)

		assert.are.same({ "Tue", "Wed" }, { onUSRealm, onNZRealm })
		assert.are.same({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }, week)
	end)

	it("counts down in whole hours from one hour up and whole minutes below (TKB-R105)", function()
		local ns = board.load().ns

		assert.are.same({ "13h", "13h", "1h", "59m", "45m", "45m", "0m" }, {
			ns.Countdown(13 * HOUR + 59 * MINUTE + 59),
			ns.Countdown(13 * HOUR),
			ns.Countdown(HOUR),
			ns.Countdown(HOUR - 1),
			ns.Countdown(45 * MINUTE + 59),
			ns.Countdown(45 * MINUTE),
			ns.Countdown(59),
		})
	end)
end)
