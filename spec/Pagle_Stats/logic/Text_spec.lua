-- Stats' words (STA-R44, STA-R59): rounding, counts, durations, times ago, dates and Session headings, and the names
-- of items, areas, characters and qualities, as every Stats view writes them through logic/Text.lua. Loaded over
-- FakePagle, whose client reads are the game's: its local clock (`date`) is UTC, its BreakUpLargeNumbers the enUS
-- client's.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

-- 2026-10-05 00:00 UTC, a Monday: FakePagle's SERVER_TIME (Sunday 2026-10-11 15:15 UTC) less 6 days, 15 h 15 min.
local MONDAY_5_OCTOBER = SERVER_TIME - 6 * 86400 - 15 * 3600 - 15 * 60

describe("Stats' words", function()
	describe("rounding (STA-R44)", function()
		it("rounds half up", function()
			local ns = stats.load().ns

			assert.are.equal(2, ns.Round(1.5))
			assert.are.equal(1, ns.Round(1.49))
			assert.are.equal(3, ns.Round(2.5))
			assert.are.equal(0, ns.Round(0.49))
			assert.are.equal(-1, ns.Round(-1.5))
		end)

		it("reads STA-R44's examples: 39.6 as 40, 212 as 210, 1,447 as 1,400", function()
			local ns = stats.load().ns

			assert.are.equal("40", ns.Nice(39.6))
			assert.are.equal("210", ns.Nice(212))
			assert.are.equal("1,400", ns.Nice(1447))
		end)

		it("reads anything below 1.5 as 1", function()
			local ns = stats.load().ns

			assert.are.equal("1", ns.Nice(1))
			assert.are.equal("1", ns.Nice(1.49))
			assert.are.equal("1", ns.Nice(0.2))
			assert.are.equal("2", ns.Nice(1.5))
		end)

		it("reads the nearest whole number below 20, and two significant figures from 20 on", function()
			local ns = stats.load().ns

			assert.are.equal("19", ns.Nice(19.49))
			assert.are.equal("20", ns.Nice(19.5))
			assert.are.equal("20", ns.Nice(20))
			assert.are.equal("21", ns.Nice(20.5))
			assert.are.equal("99", ns.Nice(99.4))
			assert.are.equal("100", ns.Nice(99.5))
			assert.are.equal("990", ns.Nice(994))
			assert.are.equal("1,000", ns.Nice(995))
			assert.are.equal("9,900", ns.Nice(9949))
			assert.are.equal("10,000", ns.Nice(9950))
			assert.are.equal("1,200,000", ns.Nice(1234567))
		end)
	end)

	describe("counts (STA-R59)", function()
		it("take the singular at 1 for Casts, Catches, Sessions, waters and anglers who wait", function()
			local ns = stats.load().ns

			assert.are.equal("1 Cast", ns.Count(1, "Casts"))
			assert.are.equal("1 Catch", ns.Count(1, "Catches"))
			assert.are.equal("1 Session", ns.Count(1, "Sessions"))
			assert.are.equal("1 water", ns.Count(1, "waters"))
			assert.are.equal("1 angler in 100 waits", ns.Count(1, "anglers"))
		end)

		it("take the plural at 0 and from 2 on", function()
			local ns = stats.load().ns

			assert.are.equal("0 Casts", ns.Count(0, "Casts"))
			assert.are.equal("2 Catches", ns.Count(2, "Catches"))
			assert.are.equal("12 Sessions", ns.Count(12, "Sessions"))
			assert.are.equal("3 waters", ns.Count(3, "waters"))
			assert.are.equal("38 anglers in 100 wait", ns.Count(38, "anglers"))
		end)

		it("separate thousands through BreakUpLargeNumbers from 1,000", function()
			local ns = stats.load().ns

			assert.are.equal("999 Casts", ns.Count(999, "Casts"))
			assert.are.equal("1,000 Casts", ns.Count(1000, "Casts"))
			assert.are.equal("12,345 Catches", ns.Count(12345, "Catches"))
			assert.are.equal("1,234,567", ns.Number(1234567))
			assert.are.equal("412", ns.Number(412))
		end)

		it("go through the client's BreakUpLargeNumbers, read when they're written", function()
			local loaded = stats.load()
			loaded.env.BreakUpLargeNumbers = function(n)
				return ("<%d>"):format(n)
			end

			assert.are.equal("<1000> Casts", loaded.ns.Count(1000, "Casts"))
			assert.are.equal("<1400>", loaded.ns.Nice(1447))
		end)
	end)

	describe("durations (STA-R59)", function()
		it("read under a minute as under 1m", function()
			local ns = stats.load().ns

			assert.are.equal("under 1m", ns.Duration(0))
			assert.are.equal("under 1m", ns.Duration(59))
		end)

		it("read whole minutes under an hour, rounded half up (STA-R44)", function()
			local ns = stats.load().ns

			assert.are.equal("1m", ns.Duration(60))
			assert.are.equal("1m", ns.Duration(89))
			assert.are.equal("2m", ns.Duration(90))
			assert.are.equal("21m", ns.Duration(21 * 60))
			assert.are.equal("59m", ns.Duration(59 * 60 + 29))
		end)

		it("read hours and two-digit minutes from an hour on, the hours unbounded", function()
			local ns = stats.load().ns

			assert.are.equal("1h 00m", ns.Duration(59 * 60 + 30))
			assert.are.equal("1h 05m", ns.Duration(65 * 60))
			assert.are.equal("2h 30m", ns.Duration(150 * 60))
			assert.are.equal("31h 07m", ns.Duration(31 * 3600 + 7 * 60))
			assert.are.equal("250h 00m", ns.Duration(250 * 3600))
		end)
	end)

	describe("time ago (STA-R59)", function()
		it("reads under a minute as just now, and a time to come as just now too", function()
			local ns = stats.load().ns

			assert.are.equal("just now", ns.TimeAgo(SERVER_TIME))
			assert.are.equal("just now", ns.TimeAgo(SERVER_TIME - 59))
			assert.are.equal("just now", ns.TimeAgo(SERVER_TIME + 30))
		end)

		it("reads minutes under an hour, hours under a day, days after that", function()
			local ns = stats.load().ns

			assert.are.equal("1m ago", ns.TimeAgo(SERVER_TIME - 60))
			assert.are.equal("21m ago", ns.TimeAgo(SERVER_TIME - 21 * 60))
			assert.are.equal("1h ago", ns.TimeAgo(SERVER_TIME - 3600))
			assert.are.equal("3h ago", ns.TimeAgo(SERVER_TIME - 3 * 3600))
			assert.are.equal("1d ago", ns.TimeAgo(SERVER_TIME - 86400))
			assert.are.equal("4d ago", ns.TimeAgo(SERVER_TIME - 4 * 86400))
			assert.are.equal("400d ago", ns.TimeAgo(SERVER_TIME - 400 * 86400))
		end)

		it("rounds half up, so a count that rounds up to the next unit reads in that unit (STA-R44)", function()
			local ns = stats.load().ns

			assert.are.equal("59m ago", ns.TimeAgo(SERVER_TIME - (59 * 60 + 29)))
			assert.are.equal("1h ago", ns.TimeAgo(SERVER_TIME - (59 * 60 + 30)))
			assert.are.equal("2h ago", ns.TimeAgo(SERVER_TIME - 90 * 60))
			assert.are.equal("1d ago", ns.TimeAgo(SERVER_TIME - (23 * 3600 + 30 * 60)))
		end)

		it("counts from the time given, when one is", function()
			local ns = stats.load().ns

			assert.are.equal("21m ago", ns.TimeAgo(1000, 1000 + 21 * 60))
		end)
	end)

	describe("times and dates, in the player's local clock (STA-R59)", function()
		it("read a time as HH:MM", function()
			local ns = stats.load().ns

			assert.are.equal("09:07", ns.Time(MONDAY_5_OCTOBER + 9 * 3600 + 7 * 60))
			assert.are.equal("23:59", ns.Time(MONDAY_5_OCTOBER + 23 * 3600 + 59 * 60))
		end)

		it("read a date as day, month abbreviation and year, the day without a leading zero", function()
			local ns = stats.load().ns

			assert.are.equal("5 Oct 2026", ns.Date(MONDAY_5_OCTOBER + 9 * 3600))
			assert.are.equal("11 Oct 2026", ns.Date(SERVER_TIME))
		end)

		it("read a Session's heading as weekday, day and month, the day without a leading zero", function()
			local ns = stats.load().ns

			assert.are.equal("Monday 5 October", ns.SessionHeading(MONDAY_5_OCTOBER + 9 * 3600))
			assert.are.equal("Sunday 11 October", ns.SessionHeading(SERVER_TIME))
		end)

		it("read the client's local clock, not the server's", function()
			local loaded = stats.load()
			-- A player two hours east of UTC: their 5 October starts at 22:00 UTC on the 4th.
			loaded.env.date = function(format, time)
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
				return os.date("!" .. format, time + 2 * 3600)
			end
			local ns = loaded.ns
			local late = MONDAY_5_OCTOBER - 3600 -- 23:00 UTC on Sunday 4 October

			assert.are.equal("01:00", ns.Time(late))
			assert.are.equal("5 Oct 2026", ns.Date(late))
			assert.are.equal("Monday 5 October", ns.SessionHeading(late))
		end)

		it("read a realm-time window bound, a minute of the realm's day, as HH:MM", function()
			local ns = stats.load().ns

			assert.are.equal("00:00", ns.WindowTime(0))
			assert.are.equal("06:00", ns.WindowTime(360))
			assert.are.equal("18:05", ns.WindowTime(1085))
			assert.are.equal("00:00", ns.WindowTime(1440))
		end)

		it("write times and window bounds in Core's clock format, 12-hour when it is set so (CORE-R87)", function()
			local loaded, fake = stats.load()
			fake.profile.clockFormat = "12h"
			local ns = loaded.ns

			assert.are.same({ "9:07 am", "11:59 pm", "12:00 am", "6:00 am", "6:05 pm", "12:00 am" }, {
				ns.Time(MONDAY_5_OCTOBER + 9 * 3600 + 7 * 60),
				ns.Time(MONDAY_5_OCTOBER + 23 * 3600 + 59 * 60),
				ns.WindowTime(0),
				ns.WindowTime(360),
				ns.WindowTime(1085),
				ns.WindowTime(1440),
			})
		end)
	end)

	describe("names (STA-R59)", function()
		it("read an item by its C_Item name and icon once the client has them", function()
			local loaded = stats.load()
			loaded.client.itemNames[13759] = "Raw Nightfin Snapper"
			loaded.client.itemIcons[13759] = 133918

			local name, icon, ready = loaded.ns.Item(13759)

			assert.are.equal("Raw Nightfin Snapper", name)
			assert.are.equal(133918, icon)
			assert.is_true(ready)
		end)

		it("reads an item without loaded data as Item {id} with the question-mark icon", function()
			local loaded = stats.load()
			loaded.client.itemIcons[13759] = 133918 -- the icon alone doesn't make it loaded

			local name, icon, ready = loaded.ns.Item(13759)

			assert.are.equal("Item 13759", name)
			assert.are.equal("Interface\\Icons\\INV_Misc_QuestionMark", icon)
			assert.is_false(ready)
		end)

		it("reads a named item with no icon with the question-mark icon", function()
			local loaded = stats.load()
			loaded.client.itemNames[6358] = "Oily Blackmouth"

			local name, icon = loaded.ns.Item(6358)

			assert.are.equal("Oily Blackmouth", name)
			assert.are.equal("Interface\\Icons\\INV_Misc_QuestionMark", icon)
		end)

		it("doesn't ask the client to load an item: the book asks and redraws (STA-R73)", function()
			local loaded = stats.load()

			loaded.ns.Item(13759)

			assert.are.same({}, loaded.client.itemRequests)
		end)

		it("reads an area by its C_Map.GetAreaInfo name, or Area {id} with none", function()
			local loaded = stats.load()
			loaded.client.areaNames[148] = "Darkshore"
			loaded.client.areaNames[446] = ""

			assert.are.equal("Darkshore", loaded.ns.AreaName(148))
			assert.are.equal("Area 442", loaded.ns.AreaName(442))
			assert.are.equal("Area 446", loaded.ns.AreaName(446))
		end)

		it("reads a character by name and surname as Core stores them, the name alone without one", function()
			local loaded, fake = stats.load()
			fake.login() -- the fake client's character: Angler Tester
			local characters = fake.catchLog.data.characters
			characters[2] = {
				guid = "Player-4618-0B0B0B0B",
				name = "Ada",
				classID = 1,
				raceID = 1,
				faction = "Alliance",
				realmID = 4618,
				firstSeen = SERVER_TIME,
				lastSeen = SERVER_TIME,
			}

			assert.are.equal("Angler Tester", loaded.ns.CharacterName(1))
			assert.are.equal("Ada", loaded.ns.CharacterName(2))
		end)

		it("reads a character index the Angler doesn't have as Character {index}", function()
			local loaded = stats.load()

			assert.are.equal("Character 3", loaded.ns.CharacterName(3))
		end)
	end)

	describe("qualities (STA-R59)", function()
		it("read in the game's own names", function()
			local ns = stats.load().ns

			assert.are.equal("Poor", ns.QualityName(0))
			assert.are.equal("Common", ns.QualityName(1))
			assert.are.equal("Uncommon", ns.QualityName(2))
			assert.are.equal("Rare", ns.QualityName(3))
			assert.are.equal("Epic", ns.QualityName(4))
			assert.are.equal("Legendary", ns.QualityName(5))
		end)

		it("read in the game's own colours, from ITEM_QUALITY_COLORS as it is when they're drawn", function()
			local loaded = stats.load()
			local ns = loaded.ns

			local r, g, b = ns.QualityColor(3)
			assert.are.same({ 0, 0.44, 0.87 }, { r, g, b })
			assert.are.equal("|cff0070ddRaw Nightfin Snapper|r", ns.QualityText(3, "Raw Nightfin Snapper"))

			-- The client fills a new table when the player's colour overrides change (ColorManager).
			loaded.env.ITEM_QUALITY_COLORS = { [3] = { r = 1, g = 0, b = 0, hex = "|cffff0000" } }
			assert.are.same({ 1, 0, 0 }, { ns.QualityColor(3) })
			assert.are.equal("|cffff0000Raw Nightfin Snapper|r", ns.QualityText(3, "Raw Nightfin Snapper"))
		end)

		it("read a quality the game has no name or colour for as Quality {n}, in white", function()
			local ns = stats.load().ns

			assert.are.equal("Quality 12", ns.QualityName(12))
			assert.are.same({ 1, 1, 1 }, { ns.QualityColor(12) })
			assert.are.equal("|cffffffffSomething|r", ns.QualityText(12, "Something"))
		end)
	end)
end)
