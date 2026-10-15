-- The Session pages on FakePagle (stats.md › UI › This Session, Sessions; STA-R30, STA-R32, STA-R33, STA-R59,
-- STA-R95, STA-R97): a history of Casts and Skill Readings across several Sessions and two characters, appended to the
-- log before login, then the projection's first build, then live Casts; the book opened on This Session or Sessions
-- and its pages read back line by line. Every expected figure is worked out by hand in the comments beside it.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local AUBERDINE, ELWYNN = I.AUBERDINE, I.ELWYNN
local MACKEREL, BLACKMOUTH = I.MACKEREL, I.BLACKMOUTH -- both Common in the fixture catalogue
-- Uncharted items (not in the catalogue): their qualities come from the client (STA-R33).
local RARE, POOR, LATE = 7080, 7070, 7090
local OTHER_GUID = stats.OTHER_GUID
local DAY0 = 1791676800 -- Sunday 11 October 2026 00:00 UTC; the fake's clock is 15:15 that day (SERVER_TIME)
local OCT1_1000 = DAY0 - 10 * 86400 + 10 * 3600 -- Thursday 1 October 2026 10:00
local OCT5_2104 = DAY0 - 6 * 86400 + 21 * 3600 + 4 * 60 -- Monday 5 October 2026 21:04

-- A Cast record (stats.cast: by day in Darkshore, no subzone) at skill 150. `c.items` are item IDs (none: got away).
---@param c { time: integer, char: integer?, zone: integer?, subzone: integer?, items: integer[]? }
local function cast(c)
	c.rank = 150
	return stats.cast(c)
end
local skill, concat = stats.skill, stats.concat

-- Session 1: one Cast in Darkshore on Thursday 1 October at 10:00, a Mackerel.
local OLD = { cast({ time = OCT1_1000, items = { MACKEREL } }) }

-- Session 2, on Monday 5 October from 21:04 to 21:44 (40m): 5 Casts, 3 by the Angler (char 1) in Darkshore and 2 by
-- Aaron (char 2) in Elwynn; 5 Catches (the last Cast holds two items), 1 got away (20%); 5 × 3600 / 2400 = 7.5, so 8
-- Catches per hour; the Angler's skill 150 → 153, +3 (the first reading adds nothing, STA-R27). By quality: Rare 1,
-- Common 2 (Mackerel, Blackmouth), Poor 1, and LATE, whose quality the client hasn't loaded yet.
local RICH = {
	cast({ time = OCT5_2104, subzone = AUBERDINE, items = { MACKEREL } }),
	skill(OCT5_2104 + 100, 150),
	cast({ time = OCT5_2104 + 600, char = 2, zone = ELWYNN, items = { RARE } }),
	cast({ time = OCT5_2104 + 1200 }),
	cast({ time = OCT5_2104 + 1800, items = { BLACKMOUTH } }),
	skill(OCT5_2104 + 1900, 153),
	cast({ time = OCT5_2104 + 2400, char = 2, zone = ELWYNN, items = { POOR, LATE } }),
}

-- `count` Sessions of one caught Cast in Darkshore, an hour apart from Saturday 10 October 00:00, so the newest
-- starts at {count − 1}:00.
local function hourly(count)
	local records = {}
	for i = 1, count do
		records[i] = cast({ time = DAY0 - 86400 + (i - 1) * 3600, items = { MACKEREL } })
	end
	return records
end

-- Pagle_Stats over a log of the Angler (char 1, the player) and Aaron Brook (char 2) holding `records`, logged in
-- with its projection built, its book ready. The client knows the areas' names and the Uncharted items' qualities but
-- LATE's.
local function withHistory(records)
	local loaded, fake, book = stats.start({
		records = records,
		characters = {
			{ guid = PLAYER_GUID, name = "Angler", surname = "Tester" },
			{ guid = OTHER_GUID, name = "Aaron", surname = "Brook" },
		},
		items = {},
		prepare = function(loaded)
			loaded.client.itemQualities[RARE] = 3
			loaded.client.itemQualities[POOR] = 0
		end,
	})
	return loaded, fake, book
end

-- The vertical offset a widget's first anchor gives it (its last number), 0 with none.
local function offsetOf(widget)
	local anchor = widget.points[1]
	local y = anchor and anchor[#anchor]
	return type(y) == "number" and y or 0
end

-- The texts of every shown widget under `widget`, top to bottom: siblings by their anchor's offset, then as made.
local function linesOf(widget, out)
	out = out or {}
	local children = {}
	for i, child in ipairs(widget.children) do
		if child.shown then
			children[#children + 1] = { child = child, i = i }
		end
	end
	table.sort(children, function(a, b)
		local ya, yb = offsetOf(a.child), offsetOf(b.child)
		if ya ~= yb then
			return ya > yb
		end
		return a.i < b.i
	end)
	for _, entry in ipairs(children) do
		local child = entry.child
		if child.text ~= nil and child.text ~= "" then
			out[#out + 1] = child.text
		end
		linesOf(child, out)
	end
	return out
end

-- The lines of side `side` of the page shown.
local function page(book, side)
	return linesOf(book.frame.bodies[side])
end

-- The ledger's "Started" cells on side `side`, top to bottom.
local function started(book, side)
	local out = {}
	for _, line in ipairs(page(book, side)) do
		if line:match("^%d+ Oct 2026 %d%d:%d%d$") then
			out[#out + 1] = line
		end
	end
	return out
end

-- Whether a shown widget under `widget` has text `text`.
local function holds(widget, text)
	for _, child in ipairs(widget.children) do
		if child.shown and (child.text == text or holds(child, text)) then
			return true
		end
	end
	return false
end

-- The shown clickable widget under side `side` whose words are `text`, deepest first.
local function clickable(book, side, text)
	local function find(widget)
		for _, child in ipairs(widget.children) do
			if child.shown then
				local found = find(child)
				if found then
					return found
				end
				if child.scripts.OnClick and holds(child, text) then
					return child
				end
			end
		end
	end
	return assert(find(book.frame.bodies[side]), "nothing to click reads " .. text)
end

-- The shown font string under side `side` whose text is `text`.
local function textNamed(book, side, text)
	local function find(widget)
		for _, child in ipairs(widget.children) do
			if child.shown then
				if child.text == text then
					return child
				end
				local found = find(child)
				if found then
					return found
				end
			end
		end
	end
	return assert(find(book.frame.bodies[side]), "no text " .. text)
end

describe("the Session pages", function()
	describe("with no Sessions (STA-R97)", function()
		it('read "No Sessions yet." on both pages of This Session and of Sessions', function()
			local loaded, _, book = withHistory({})

			loaded.ns.OpenBook({ page = "session" })
			assert.are.same({ "No Sessions yet." }, page(book, "left"))
			assert.are.same({ "No Sessions yet." }, page(book, "right"))
			loaded.ns.OpenBook({ page = "sessions" })

			assert.are.same({ "No Sessions yet." }, page(book, "left"))
			assert.are.same({ "No Sessions yet." }, page(book, "right"))
		end)
	end)

	describe("a Session's entry (stats.md › UI › This Session)", function()
		it(
			"reads My last Session's date heading, span, counts, rates, Catches per hour, skill, qualities, zones and characters",
			function()
				local loaded, _, book = withHistory(concat(OLD, RICH))

				loaded.ns.OpenBook({ page = "session" })

				assert.are.same({
					"MY LAST SESSION", -- STA-R32: no Session open
					"Monday 5 October", -- STA-R59, STA-R95: by its start
					"21:04 to 21:44, 40m at the water.",
					"Casts",
					"5",
					"Catches",
					"5",
					"Got away",
					"1 (20%)",
					"Catches per hour",
					"8",
					"Skill gained",
					"+3",
					"BY QUALITY", -- highest first; LATE isn't loaded yet
					"Rare",
					"1",
					"Common",
					"2",
					"Poor",
					"1",
					"WHERE AND WHO", -- zones by Casts, then characters by name
					"Darkshore",
					"3",
					"Elwynn Forest",
					"2",
					"Aaron Brook",
					"2",
					"Angler Tester",
					"3",
				}, page(book, "left"))
			end
		)

		it("writes each quality in the game's colour, Common's white in ink so it reads on the paper", function()
			local loaded, _, book = withHistory(concat(OLD, RICH))
			loaded.ns.OpenBook({ page = "session" })

			local colors = loaded.env.ITEM_QUALITY_COLORS
			local rare, poor = colors[3], colors[0]
			assert.are.same({ rare.r, rare.g, rare.b }, { unpack(textNamed(book, "left", "Rare").textColor, 1, 3) })
			assert.are.same({ poor.r, poor.g, poor.b }, { unpack(textNamed(book, "left", "Poor").textColor, 1, 3) })
			assert.are.same(loaded.ns.BOOK_LOOK.ink, { unpack(textNamed(book, "left", "Common").textColor, 1, 3) })
		end)

		it("asks for an item whose quality isn't loaded, and counts it once it loads (STA-R33)", function()
			local loaded, _, book = withHistory(concat(OLD, RICH))
			loaded.ns.OpenBook({ page = "session" })
			-- search (adapter/Search.lua) also asks, as the book opens, for the unnamed fish of my records and fished
			-- zones' rows
			assert.are.equal(LATE, loaded.client.itemRequests[1])

			stats.loadItem(loaded, LATE, { quality = 2 })
			loaded.client.runTimers()

			local lines = page(book, "left")
			local from = 0
			for i, line in ipairs(lines) do
				from = line == "BY QUALITY" and i or from
			end
			assert.are.same(
				{ "Rare", "1", "Uncommon", "1", "Common", "2", "Poor", "1" },
				{ unpack(lines, from + 1, from + 8) }
			)
		end)

		it("opens a zone's place page from its line", function()
			local loaded, _, book = withHistory(concat(OLD, RICH))
			loaded.ns.OpenBook({ page = "session" })

			clickable(book, "left", "Elwynn Forest"):Click()

			assert.are.same({ page = "place", area = ELWYNN }, book.router:Place())
		end)
	end)

	describe("This Session (stats.md › UI › This Session; STA-R32, STA-R33)", function()
		it("shows the current Session's entry to now, with its figures so far", function()
			local loaded, fake, book = withHistory(concat(OLD, RICH))
			-- Two live Casts by the Angler in Darkshore at 15:15 and 15:25; the server time is 15:40, 25m so far:
			-- 1 Catch × 3600 / 1500 = 2.4, so 2 per hour (STA-R33).
			fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })
			fake.wait(600)
			fake.playCast("gotAway")
			loaded.env.GetServerTime = function()
				return SERVER_TIME + 1500
			end

			loaded.ns.OpenBook({ page = "session" })

			assert.are.same({
				"THIS SESSION",
				"Sunday 11 October",
				"15:15 to now, 25m at the water.",
				"Casts",
				"2",
				"Catches",
				"1",
				"Got away",
				"1 (50%)",
				"Catches per hour",
				"2",
				"Skill gained",
				"+0",
				"BY QUALITY",
				"Common",
				"1",
				"WHERE AND WHO",
				"Darkshore",
				"2",
				"Angler Tester",
				"2",
			}, page(book, "left"))
		end)

		it("lists the Sessions before it in a ruled ledger, newest first, then Every Session", function()
			local loaded, fake, book = withHistory(concat(OLD, RICH))
			fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })

			loaded.ns.OpenBook({ page = "session" })

			assert.are.same({
				"BEFORE THAT",
				"Earlier Sessions",
				"STARTED",
				"WHERE",
				"LENGTH",
				"CASTS",
				"CATCHES",
				"5 Oct 2026 21:04",
				"Darkshore, Elwynn Forest", -- zones by Casts: 3 and 2
				"40m",
				"5",
				"5",
				"1 Oct 2026 10:00",
				"Darkshore",
				"under 1m",
				"1",
				"1",
				"Every Session",
			}, page(book, "right"))
		end)

		it("lists only the 10 Sessions before My last Session (Tunables)", function()
			local loaded, _, book = withHistory(hourly(20))

			loaded.ns.OpenBook({ page = "session" })

			assert.are.same({
				"10 Oct 2026 18:00",
				"10 Oct 2026 17:00",
				"10 Oct 2026 16:00",
				"10 Oct 2026 15:00",
				"10 Oct 2026 14:00",
				"10 Oct 2026 13:00",
				"10 Oct 2026 12:00",
				"10 Oct 2026 11:00",
				"10 Oct 2026 10:00",
				"10 Oct 2026 09:00",
			}, started(book, "right"))
		end)

		it("opens a row's Session on the Sessions page, and Every Session opens Sessions", function()
			local loaded, fake, book = withHistory(concat(OLD, RICH))
			fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })
			loaded.ns.OpenBook({ page = "session" })
			local rich = loaded.ns.State().sessions[2]

			clickable(book, "right", "5 Oct 2026 21:04"):Click()
			assert.are.same({ page = "sessions", session = rich.id, ledgerPage = 1 }, book.router:Place())
			assert.are.equal("SESSION 2", page(book, "right")[1])
			loaded.ns.OpenBook({ page = "session" })
			clickable(book, "right", "Every Session"):Click()

			assert.are.same({ page = "sessions" }, book.router:Place())
		end)
	end)

	describe("Sessions (stats.md › UI › Sessions)", function()
		it("lists twenty Sessions on ledger pages of 16 and 4, newest first, each arrow hidden at its end", function()
			local loaded, _, book = withHistory(hourly(20))

			loaded.ns.OpenBook({ page = "sessions" })
			local lines = page(book, "left")
			assert.are.same(
				{ "SESSIONS", "20 Sessions", "A Session ends after 15 minutes without a Cast." },
				{ unpack(lines, 1, 3) }
			)
			local first = started(book, "left")
			assert.are.equal(16, #first)
			assert.are.same({ "10 Oct 2026 19:00", "10 Oct 2026 04:00" }, { first[1], first[16] })
			assert.are.same({ "page 1 of 2", "earlier" }, { unpack(lines, #lines - 1) })

			clickable(book, "left", "earlier"):Click()
			assert.are.same({ page = "sessions", ledgerPage = 2 }, book.router:Place())
			assert.are.same({
				"10 Oct 2026 03:00",
				"10 Oct 2026 02:00",
				"10 Oct 2026 01:00",
				"10 Oct 2026 00:00",
			}, started(book, "left"))
			lines = page(book, "left")
			assert.are.same({ "later", "page 2 of 2" }, { unpack(lines, #lines - 1) })
			clickable(book, "left", "later"):Click()

			assert.are.same({ page = "sessions", ledgerPage = 1 }, book.router:Place())
		end)

		it("shows the newest Session's entry by default, numbered from the oldest, its row highlighted", function()
			local loaded, _, book = withHistory(hourly(20))

			loaded.ns.OpenBook({ page = "sessions" })

			assert.are.same({
				"SESSION 20",
				"Saturday 10 October",
				"19:00 to 19:00, under 1m at the water.",
			}, { unpack(page(book, "right"), 1, 3) })
			assert.is_true(clickable(book, "left", "10 Oct 2026 19:00").shade.shown)
			assert.is_false(clickable(book, "left", "10 Oct 2026 18:00").shade.shown)
		end)

		it("shows a chosen row's entry and highlights it, keeping its ledger page", function()
			local loaded, _, book = withHistory(hourly(20))
			loaded.ns.OpenBook({ page = "sessions", ledgerPage = 2 })
			local second = loaded.ns.State().sessions[2]

			clickable(book, "left", "10 Oct 2026 01:00"):Click()

			assert.are.same({ page = "sessions", session = second.id, ledgerPage = 2 }, book.router:Place())
			assert.are.same({ "SESSION 2", "Saturday 10 October" }, { unpack(page(book, "right"), 1, 2) })
			assert.is_true(clickable(book, "left", "10 Oct 2026 01:00").shade.shown)
			assert.is_false(clickable(book, "left", "10 Oct 2026 03:00").shade.shown)
		end)

		it("shows the current Session's entry to now, numbered", function()
			local loaded, fake, book = withHistory(concat(OLD, RICH))
			fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })

			loaded.ns.OpenBook({ page = "sessions" })

			assert.are.same({
				"SESSION 3",
				"Sunday 11 October",
				"15:15 to now, under 1m at the water.",
			}, { unpack(page(book, "right"), 1, 3) })
		end)

		it("dates a Session that crosses midnight by its start, as one row (STA-R95)", function()
			-- Friday 9 October 23:50 to Saturday 10 October 00:20: four Casts 10 minutes apart, one Session.
			local start = DAY0 - 2 * 86400 + 23 * 3600 + 50 * 60
			local records = {}
			for i = 1, 4 do
				records[i] = cast({ time = start + (i - 1) * 600, items = { MACKEREL } })
			end
			local loaded, _, book = withHistory(records)

			loaded.ns.OpenBook({ page = "sessions" })

			assert.are.same({ "9 Oct 2026 23:50" }, started(book, "left"))
			assert.are.same({ "1 Session" }, { page(book, "left")[2] })
			assert.are.same({
				"SESSION 1",
				"Friday 9 October",
				"23:50 to 00:20, 30m at the water.",
			}, { unpack(page(book, "right"), 1, 3) })
		end)
	end)

	describe("while the projection is updating (STA-R72)", function()
		it("leave both pages to the book's updating line", function()
			-- no first PLAYER_ENTERING_WORLD yet: the first build hasn't run
			local loaded, _, book = stats.start({
				records = RICH,
				characters = { { guid = PLAYER_GUID }, { guid = OTHER_GUID } },
				items = {},
				updating = true,
			})

			loaded.ns.OpenBook({ page = "sessions" })

			assert.are.same({ "Updating my records…" }, page(book, "left"))
			assert.are.same({ "Updating my records…" }, page(book, "right"))
		end)
	end)
end)
