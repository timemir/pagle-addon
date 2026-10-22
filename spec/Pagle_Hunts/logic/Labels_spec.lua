-- Labels in realm time (HNT-R50–R55): the pure wording of logic/Labels.lua, each case's inputs passed in, the name
-- lookups a table of stand-ins (adapter/Names.lua builds the real one).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local MINUTE, HOUR, DAY = 60, hunts.HOUR, 86400

-- A live snapshot (LOG-R45) at server time `time`: realm `minute` of day on `date`; weekday 1 is Sunday.
local function snapshotAt(time, minute, year, month, day, weekday)
	return { time = time, minute = minute, date = { year = year, month = month, day = day, weekday = weekday } }
end

-- Sunday 11 October 2026 at realm 08:15 (FakePagle's clock).
local NOW = SERVER_TIME
local SUNDAY = hunts.SUNDAY

describe("Labels in realm time", function()
	local ns = hunts.load().ns

	describe("realm time (HNT-R50)", function()
		it("converts a server time 26 hours ahead across midnight and a month's end", function()
			-- Wednesday 30 September 2026, 23:00.
			local snapshot = snapshotAt(1000000, 23 * 60, 2026, 9, 30, 4)

			local clock = ns.RealmClockAt(1000000 + 26 * HOUR, snapshot)

			assert.are.equal(60, clock.minute) -- 01:00
			assert.are.same({ year = 2026, month = 10, day = 2, weekday = 6 }, clock.date) -- Friday 2 October
		end)

		it("converts across a year's end, and back across midnight to the day before", function()
			-- Thursday 31 December 2026, 22:00.
			local snapshot = snapshotAt(5000, 22 * 60, 2026, 12, 31, 5)

			assert.are.same(
				{ minute = 0, date = { year = 2027, month = 1, day = 2, weekday = 7 } },
				ns.RealmClockAt(5000 + 26 * HOUR, snapshot)
			)
			assert.are.same(
				{ minute = 23 * 60, date = { year = 2026, month = 12, day = 30, weekday = 4 } },
				ns.RealmClockAt(5000 - 23 * HOUR, snapshot)
			)
		end)

		it("counts whole minutes from the snapshot: 59 seconds on is the same realm minute", function()
			assert.are.equal(hunts.REALM_START, ns.RealmClockAt(NOW + 59, SUNDAY).minute)
			assert.are.equal(hunts.REALM_START + 1, ns.RealmClockAt(NOW + 60, SUNDAY).minute)
		end)

		it("rounds durations down to the minute: 37m, 2h, 2h 10m, 1d, 1d 4h", function()
			assert.are.equal("0m", ns.FormatDuration(59))
			assert.are.equal("37m", ns.FormatDuration(37 * MINUTE + 59))
			assert.are.equal("59m", ns.FormatDuration(HOUR - 1))
			assert.are.equal("2h", ns.FormatDuration(2 * HOUR + 59))
			assert.are.equal("2h 10m", ns.FormatDuration(2 * HOUR + 10 * MINUTE + 30))
			assert.are.equal("23h 59m", ns.FormatDuration(DAY - 1))
			assert.are.equal("1d", ns.FormatDuration(DAY + 59 * MINUTE))
			assert.are.equal("1d 4h", ns.FormatDuration(DAY + 4 * HOUR + 59 * MINUTE))
		end)

		it("writes clock times in 24 hours, weekdays, short and full dates and months from ns.L", function()
			local friday = { year = 2026, month = 10, day = 2, weekday = 6 }

			assert.are.equal("06:00", ns.FormatClock(6 * 60))
			assert.are.equal("23:05", ns.FormatClock(23 * 60 + 5))
			assert.are.equal("Fri", ns.FormatWeekday(friday))
			assert.are.equal("2 Oct", ns.FormatShortDate(friday))
			assert.are.equal("2 Oct 2026", ns.FormatFullDate(friday))
			assert.are.equal("March", ns.MonthName(3))
		end)

		it("is the same realm day when the target's realm date is today's, by the realm clock, not UTC", function()
			-- 08:15 now: 23:59 today is the same day; 15:45 later, 00:00 tomorrow, isn't.
			assert.is_true(ns.IsSameRealmDay(NOW + (15 * 60 + 44) * MINUTE, NOW, SUNDAY))
			assert.is_false(ns.IsSameRealmDay(NOW + (15 * 60 + 45) * MINUTE, NOW, SUNDAY))
			assert.are.equal("23:59", ns.FormatRealmWhen(NOW + (15 * 60 + 44) * MINUTE, NOW, SUNDAY))
			assert.are.equal("Mon 00:00", ns.FormatRealmWhen(NOW + (15 * 60 + 45) * MINUTE, NOW, SUNDAY))
		end)
	end)

	-- A row's case at Sunday 08:15: its group, aura up, NextWindow result, board spec, and the grouping's skill
	-- verdicts with the numbers the window line says (HNT-R40, HNT-R33).
	local function case(fields)
		fields.now, fields.snapshot = NOW, SUNDAY
		return fields
	end

	-- The margin label, the tracker label and the window line of a case, as one list.
	local auraNames = {
		AuraName = function(spellID)
			return ({ [1280341] = "Fishing Rack" })[spellID]
		end,
	}
	local function labels(c)
		local margin, tracker = ns.HuntLabels(c)
		return { margin, tracker, ns.HuntWindowLine(c, auraNames) }
	end

	describe("the margin and tracker labels (HNT-R51) and the window line (HNT-R52), row by row", function()
		it("short of skill: need 225 / needs 225, and the line adds the need and the best", function()
			local c = case({
				group = "later",
				window = { opensAt = NOW + 37 * MINUTE },
				short = true,
				lureGetsThere = true,
				need = 225,
				best = 180,
			})

			assert.are.same({
				"need 225",
				"needs 225",
				"Opens in 37m, at 08:52. Needs 225; my best is 180. A lure gets me there.",
			}, labels(c))
		end)

		it(
			"short of skill beyond the lure reach: no lure sentence, as the grouping found it (HNT-R33, HNT-R52)",
			function()
				local c = case({
					group = "later",
					window = { opensAt = NOW + 37 * MINUTE },
					short = true,
					lureGetsThere = false,
					need = 225,
					best = 124,
				})

				assert.are.equal("Opens in 37m, at 08:52. Needs 225; my best is 124.", ns.HuntWindowLine(c, auraNames))
				c.best, c.lureGetsThere = 125, true
				assert.are.equal(
					"Opens in 37m, at 08:52. Needs 225; my best is 125. A lure gets me there.",
					ns.HuntWindowLine(c, auraNames)
				)
			end
		)

		it("short of skill while open: the line ignores skill, by the window as if not short (HNT-R52)", function()
			local c = case({ group = "later", window = { openNow = true, closesAt = NOW + 3 * HOUR + 45 * MINUTE } })
			c.short, c.lureGetsThere, c.need, c.best = true, true, 225, 180

			assert.are.same({
				"need 225",
				"needs 225",
				"Open now. Closes in 3h 45m, at 12:00. Needs 225; my best is 180. A lure gets me there.",
			}, labels(c))
		end)

		it("a row the grouping didn't find short reads by its group, whatever its skill need (HNT-R33)", function()
			local c = case({
				group = "soon",
				window = { opensAt = NOW + 37 * MINUTE },
				short = false,
				need = 180,
				best = 180,
			})

			assert.are.same({ "in 37m", "in 37m", "Opens in 37m, at 08:52." }, labels(c))
		end)

		it("Now with aura up: up now / up now / Up now.", function()
			local c =
				case({ group = "now", auraUp = true, window = { onDemand = true }, spec = { auras = { 1280341 } } })

			assert.are.same({ "up now", "up now", "Up now." }, labels(c))
		end)

		it("On demand: on demand, and the line names the spec's first aura", function()
			local c =
				case({ group = "onDemand", window = { onDemand = true }, spec = { auras = { 1280341, 1280342 } } })

			assert.are.same({ "on demand", "on demand", "Whenever I set up Fishing Rack." }, labels(c))
		end)

		it("On demand with an aura whose name the client hasn't given: …", function()
			local c = case({ group = "onDemand", window = { onDemand = true }, spec = { auras = { 1280342 } } })

			assert.are.equal("Whenever I set up ….", ns.HuntWindowLine(c, auraNames))
		end)

		it("Now, always: any time / any time / Open any time.", function()
			assert.are.same(
				{ "any time", "any time", "Open any time." },
				labels(case({ group = "now", window = { always = true } }))
			)
		end)

		it("Now with no closesAt: while the event runs / now / Open while the event runs.", function()
			assert.are.same(
				{ "while the event runs", "now", "Open while the event runs." },
				labels(case({ group = "now", window = { openNow = true } }))
			)
		end)

		it("Now, closing within 7 days on the same realm day: until 10:25 / ends in 2h 10m", function()
			local c = case({ group = "now", window = { openNow = true, closesAt = NOW + 2 * HOUR + 10 * MINUTE } })

			assert.are.same({ "until 10:25", "ends in 2h 10m", "Open now. Closes in 2h 10m, at 10:25." }, labels(c))
		end)

		it("Now, closing within 7 days on another realm day: until Sat 16:00 / ends in 6d 7h", function()
			local c =
				case({ group = "now", window = { openNow = true, closesAt = NOW + 6 * DAY + 7 * HOUR + 45 * MINUTE } })

			assert.are.same(
				{ "until Sat 16:00", "ends in 6d 7h", "Open now. Closes in 6d 7h, at Sat 16:00." },
				labels(c)
			)
		end)

		it("Now, closing exactly 7 days on still reads the time: the month wording starts beyond (Tunables)", function()
			local c = case({ group = "now", window = { openNow = true, closesAt = NOW + 7 * DAY } })

			assert.are.equal("until Sun 08:15", (ns.HuntLabels(c)))
			c.window = { openNow = true, closesAt = NOW + 7 * DAY + MINUTE }
			assert.are.same({ "until October", "until October", "Open now, until October." }, labels(c))
		end)

		it("Now, closing later: until September, in the closing's realm month", function()
			local c = case({ group = "now", window = { openNow = true, closesAt = NOW + 340 * DAY } })

			assert.are.same({ "until September", "until September", "Open now, until September." }, labels(c))
		end)

		it("Soon: in 37m, and the line gives the opening's time", function()
			local c = case({ group = "soon", window = { opensAt = NOW + 37 * MINUTE + 30 } })

			assert.are.same({ "in 37m", "in 37m", "Opens in 37m, at 08:52." }, labels(c))
		end)

		it("Soon across realm midnight: the line's time takes the weekday, as every other-day time does", function()
			local late = snapshotAt(NOW, 23 * 60, 2026, 10, 11, 1)
			local c = { group = "soon", window = { opensAt = NOW + 2 * HOUR }, now = NOW, snapshot = late }

			assert.are.equal("Opens in 2h, at Mon 01:00.", ns.HuntWindowLine(c, auraNames))
		end)

		it("Later, opening within 7 days on the same realm day: 21:00 / Opens at 21:00.", function()
			local c = case({ group = "later", window = { opensAt = NOW + 12 * HOUR + 45 * MINUTE } })

			assert.are.same({ "21:00", "21:00", "Opens at 21:00." }, labels(c))
		end)

		it("Later, opening within 7 days on another realm day: Tue 14:00 / Opens Tue 14:00.", function()
			local c = case({ group = "later", window = { opensAt = NOW + 2 * DAY + 5 * HOUR + 45 * MINUTE } })

			assert.are.same({ "Tue 14:00", "Tue 14:00", "Opens Tue 14:00." }, labels(c))
		end)

		it("Later, opening later: back in March / Back in March.", function()
			local c = case({ group = "later", window = { opensAt = NOW + 150 * DAY } })

			assert.are.same({ "back in March", "back in March", "Back in March." }, labels(c))
		end)

		it("Later with a nil result, or no board spec: no date known / No date known.", function()
			assert.are.same({ "no date known", "no date known", "No date known." }, labels(case({ group = "later" })))
		end)
	end)

	describe("the conditions line (HNT-R53)", function()
		local loaded, fake = hunts.load()
		-- The names as the client would give them, and FakePagle's forecasts (its Extravaganza: Sundays 14:00 for 2
		-- hours, LOG-R56), over FakePagle's clock, Sunday 08:15.
		local names = {
			AreaName = function(areaID)
				return ({ [148] = "Darkshore", [10] = "Duskwood" })[areaID]
			end,
			AuraName = function(spellID)
				return ({ [1280341] = "Fishing Rack", [1280342] = "Fishing Hut" })[spellID]
			end,
			EventName = function(eventID)
				if eventID == 301 then
					return "Stranglethorn Fishing Extravaganza"
				elseif eventID == 999 then
					return false -- looked up, not on the calendar
				end
				return nil -- not looked up yet
			end,
			NextWindow = fake.Pagle.NextWindow,
		}
		local function line(spec, windowID, stubbed)
			return loaded.ns.HuntConditionsLine(spec, windowID, NOW, SUNDAY, stubbed or names)
		end

		it("reads Grouper by Moonlight's: Realm time 22:00–04:00 · In Darkshore", function()
			assert.are.equal(
				"Realm time 22:00–04:00 · In Darkshore",
				line({ areas = { 148 }, time = { { 1320, 240 } } })
			)
		end)

		it("names the time Night or Day by the board spec's window ID, never by comparing specs", function()
			local spec = { time = { { 1320, 240 } } }

			assert.are.equal("Night 22:00–04:00", line(spec, "night"))
			assert.are.equal("Day 06:00–00:00", line({ time = { { 360, 0 } } }, "day"))
			assert.are.equal("Realm time 22:00–04:00", line(spec, nil))
			assert.are.equal(
				"Realm time 05:00–08:00, 18:00–21:00",
				line({ time = { { 300, 480 }, { 1080, 1260 } } })
			)
		end)

		it("names a season window's season, and gives an imposed season its bare ranges", function()
			local summer = { season = { { from = { 3, 20 }, to = { 9, 19 } } } }

			assert.are.equal("Summer (20 Mar – 19 Sep)", line(summer, "summer"))
			assert.are.equal("20 Mar – 19 Sep", line(summer, nil))
			assert.are.equal(
				"1 Jan – 31 Jan, 1 Jun – 30 Jun",
				line({ season = { { from = { 1, 1 }, to = { 1, 31 } }, { from = { 6, 1 }, to = { 6, 30 } } } })
			)
		end)

		it("gives the Extravaganza its name, then Sundays 14:00 for 2h from its next forecast opening", function()
			assert.are.equal(
				"Stranglethorn Fishing Extravaganza, Sundays 14:00 for 2h",
				line({ events = { 301 } }, "event.301")
			)
		end)

		it("forecasts an event open now from its closesAt: the opening after this one gives the schedule", function()
			local closesAt = NOW + HOUR
			local asked = {}
			local stubbed = setmetatable({
				NextWindow = function(spec, fromTime)
					asked[#asked + 1] = { spec.events[1], fromTime }
					if fromTime == NOW then
						return { openNow = true, closesAt = closesAt }
					end
					return { opensAt = closesAt + 7 * DAY - 2 * HOUR, closesAt = closesAt + 7 * DAY }
				end,
			}, { __index = names })

			assert.are.equal(
				"Stranglethorn Fishing Extravaganza, Sundays 07:15 for 2h",
				line({ events = { 301 } }, "event.301", stubbed)
			)
			assert.are.same({ { 301, NOW }, { 301, closesAt } }, asked)
		end)

		it("shows only the name with no forecast", function()
			local stubbed = setmetatable({
				NextWindow = function()
					return nil
				end,
			}, { __index = names })

			assert.are.equal("Stranglethorn Fishing Extravaganza", line({ events = { 301 } }, nil, stubbed))
		end)

		it("reads an event the calendar doesn't list as a calendar event, and one not looked up yet as …", function()
			local stubbed = setmetatable({
				NextWindow = function()
					return nil
				end,
			}, { __index = names })

			assert.are.equal("a calendar event", line({ events = { 999 } }, nil, stubbed))
			assert.are.equal("…", line({ events = { 998 } }, nil, stubbed))
			assert.are.equal(
				"Stranglethorn Fishing Extravaganza or a calendar event",
				line({ events = { 301, 999 } }, nil, stubbed)
			)
		end)

		it("joins areas and auras with or, and says the lure and the skill in plain words", function()
			assert.are.equal("In Darkshore or Duskwood or …", line({ areas = { 148, 10, 17 } }))
			assert.are.equal("While Fishing Rack or Fishing Hut is up", line({ auras = { 1280341, 1280342 } }))
			assert.are.equal("With a lure on", line({ lure = true }))
			assert.are.equal("With a lure on", line({ lure = { 263 } }))
			assert.are.equal("Skill 150 or more (lures count)", line({ skill = { min = 150 } }))
		end)

		it(
			"lists the fields in its order whatever the spec's: time, season, events, areas, auras, lure, skill",
			function()
				local spec = {
					skill = { min = 150 },
					lure = true,
					auras = { 1280341 },
					areas = { 10 },
					season = { { from = { 3, 20 }, to = { 9, 19 } } },
					time = { { 0, 180 } },
					confirmed = false,
				}

				assert.are.equal(
					"Realm time 00:00–03:00 · 20 Mar – 19 Sep · In Duskwood · While Fishing Rack is up · With a lure on"
						.. " · Skill 150 or more (lures count)",
					line(spec)
				)
			end
		)

		it("is nil for a Hunt without a board spec (HNT-R7)", function()
			assert.is_nil(line(nil))
		end)
	end)

	describe("target lines (HNT-R54) and icons (HNT-R55)", function()
		local list = ns.hunts
		local GREEN, BLUE = { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }
		local itemNames = {}
		local names = {
			ItemName = function(itemID)
				return itemNames[itemID]
			end,
			ItemIcon = function(itemID)
				return 100000 + itemID
			end,
			BandName = function(band)
				return ({ "Tiddler", "Decent", "Hefty", "Whopper", "Monster" })[band]
			end,
			QualityColor = function(quality)
				return ({ [2] = GREEN, [3] = BLUE })[quality]
			end,
		}
		before_each(function()
			itemNames = {}
		end)

		it("reads a species target's item name, and … until it has loaded", function()
			local snapper = list:Hunt("fixture_snapper")

			assert.are.equal("…", ns.HuntTargetLine(snapper, list, names))
			itemNames[13759] = "Raw Nightfin Snapper"
			assert.are.equal("Raw Nightfin Snapper", ns.HuntTargetLine(snapper, list, names))
		end)

		it("joins a fixed class's member names with or, in ascending item ID order", function()
			local oddity = list:Hunt("fixture_oddity")
			itemNames[251524] = "Whimsyfin"

			assert.are.equal("… or Whimsyfin", ns.HuntTargetLine(oddity, list, names))
			itemNames[6522] = "Deviate Fish"
			assert.are.equal("Deviate Fish or Whimsyfin", ns.HuntTargetLine(oddity, list, names))
		end)

		it("words the generated classes: uncommon-or-better, rare-or-better, any fish", function()
			local function target(class)
				return ns.HuntTargetLine({ class = class }, list, names)
			end

			assert.are.equal("Any uncommon-or-better Catch", target("quality.uncommon"))
			assert.are.equal("Any rare-or-better Catch", target("quality.rare"))
			assert.are.equal("Any fish", target("species.any"))
		end)

		it("adds a minBand's band name: , Hefty or better", function()
			itemNames[6358] = "Oily Blackmouth"

			assert.are.equal(
				"Oily Blackmouth, Hefty or better",
				ns.HuntTargetLine(list:Hunt("fixture_hefty_blackmouth"), list, names)
			)
			assert.are.equal(
				"Any fish, Whopper or better",
				ns.HuntTargetLine({ class = "species.any", minBand = 4 }, list, names)
			)
		end)

		it("gives a species target its item's icon and a fixed class its first member's, untinted", function()
			assert.are.same({ 113759 }, { ns.HuntIcon(list:Hunt("fixture_snapper"), list, names) })
			assert.are.same({ 106522 }, { ns.HuntIcon(list:Hunt("fixture_oddity"), list, names) })
		end)

		it(
			"gives a generated class Trade_Fishing, tinted uncommon or rare by ITEM_QUALITY_COLORS, any fish untinted",
			function()
				local function icon(class)
					return { ns.HuntIcon({ class = class }, list, names) }
				end

				assert.are.same({ "Interface\\Icons\\Trade_Fishing", GREEN }, icon("quality.uncommon"))
				assert.are.same({ "Interface\\Icons\\Trade_Fishing", BLUE }, icon("quality.rare"))
				assert.are.same({ "Interface\\Icons\\Trade_Fishing" }, icon("species.any"))
			end
		)

		it("gives a moment the qualifying Catch's item ID, or Trade_Fishing untinted with none (HNT-R86)", function()
			assert.are.equal(13759, ns.HuntMomentIcon(13759))
			assert.are.equal("Interface\\Icons\\Trade_Fishing", ns.HuntMomentIcon(nil))
		end)
	end)
end)

describe("Labels in Core's clock format (HNT-R50, CORE-R87)", function()
	-- Hunts over a FakePagle set to 12-hour: every clock time goes through Pagle.FormatClock (ns.ClockTime).
	local function twelveHour()
		local loaded, fake = hunts.load()
		fake.profile.clockFormat = "12h"
		return loaded.ns, fake
	end

	it("writes 24-hour by default: midnight 00:00, 00:05, noon 12:00, 23:59, and a day's end as 00:00", function()
		local ns = hunts.load().ns

		assert.are.same(
			{ "00:00", "00:05", "12:00", "23:59", "00:00" },
			{ ns.FormatClock(0), ns.FormatClock(5), ns.FormatClock(720), ns.FormatClock(1439), ns.FormatClock(1440) }
		)
	end)

	it("writes 12-hour: midnight 12:00 AM, 12:05 AM, noon 12:00 PM, 11:59 PM, and a day's end as 12:00 AM", function()
		local ns = twelveHour()

		assert.are.same(
			{ "12:00 AM", "12:05 AM", "12:00 PM", "11:59 PM", "12:00 AM" },
			{ ns.FormatClock(0), ns.FormatClock(5), ns.FormatClock(720), ns.FormatClock(1439), ns.FormatClock(1440) }
		)
	end)

	it("writes the board's clock, the window line and a later day's time in it", function()
		local ns = twelveHour()
		local c = { group = "later", window = { opensAt = NOW + 37 * MINUTE }, now = NOW, snapshot = SUNDAY }

		assert.are.same({
			"8:15 AM · Sun 11 Oct",
			"Opens at 8:52 AM.",
			"Mon 12:00 AM",
		}, {
			ns.TimelineClock(NOW, SUNDAY, nil, false),
			ns.HuntWindowLine(c, {}),
			ns.FormatRealmWhen(NOW + (15 * 60 + 45) * MINUTE, NOW, SUNDAY),
		})
	end)

	it("writes the conditions line's times and an event's weekly time in it, its duration as before", function()
		local ns, fake = twelveHour()
		local names = {
			EventName = function()
				return "Stranglethorn Fishing Extravaganza"
			end,
			NextWindow = fake.Pagle.NextWindow,
		}

		assert.are.same({
			"Realm time 10:00 PM–4:00 AM",
			"Stranglethorn Fishing Extravaganza, Sundays 2:00 PM for 2h",
		}, {
			ns.HuntConditionsLine({ time = { { 1320, 240 } } }, nil, NOW, SUNDAY, names),
			ns.HuntConditionsLine({ events = { 301 } }, "event.301", NOW, SUNDAY, names),
		})
	end)

	it(
		"labels the ruler's hour ticks 06 and 18 in 24-hour, and compact 6a, 6p, 12a, 12p in 12-hour (HNT-R62)",
		function()
			local ns24 = hunts.load().ns
			local ns12 = twelveHour()
			local function labels(ns)
				local out = {}
				for i, hour in ipairs({ 0, 6, 12, 18, 21 }) do
					out[i] = ns.FormatRulerHour(hour)
				end
				return out
			end

			assert.are.same({ "00", "06", "12", "18", "21" }, labels(ns24))
			assert.are.same({ "12a", "6a", "12p", "6p", "9p" }, labels(ns12))
		end
	)
end)
