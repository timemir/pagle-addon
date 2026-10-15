-- The Lifetime ribbon's spread on FakePagle (stats.md › UI › Lifetime; STA-R22, STA-R25, STA-R26, STA-R33, STA-R59,
-- STA-R96, STA-R97) over the fixture catalogue: a history of three Sessions by two characters, on both sides of
-- Darkshore's no-junk line, appended to the log before login, then the book opened on its Lifetime page. Every
-- expected value is worked out by hand beside the history.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local AUBERDINE, ELWYNN = I.AUBERDINE, I.ELWYNN
local MACKEREL, BLACKMOUTH, MANA_POTION, UNCHARTED = I.MACKEREL, I.BLACKMOUTH, I.MANA_POTION, I.UNCHARTED
-- Thursday 8 October 2026, 12:55 UTC (the fake player's local clock is UTC), and the next two days: three Sessions,
-- each a day apart and over a day before the fake's server time, so none is open.
local T0 = 1791464100
local T1, T2 = T0 + 86400, T0 + 2 * 86400

-- Cast records (stats.cast: by day in Darkshore, no subzone, no modifier). Darkshore's line is 75 + 95 = 170
-- (STA-R12): the margin is `rank` − 170 (STA-R26); Elwynn has no line, so no margin.
local cast = stats.cast

-- Session 1, 8 Oct: the player ("Angler Tester", 1) in Darkshore at 100 skill (70 below: lo50), 4 Casts over 30m, the
-- first got away: 3 Catches, 6 per hour. The longest Session.
local SESSION_1 = {
	cast({ time = T0, rank = 100 }),
	cast({ time = T0 + 600, rank = 100, items = { MACKEREL } }),
	cast({ time = T0 + 1200, rank = 100, items = { MACKEREL } }),
	cast({ time = T0 + 1800, rank = 100, items = { MACKEREL } }),
}
-- Session 2, 9 Oct: the other character ("Ada Brook", 2) in Auberdine, 10m: two Casts at 175 (5 over: hi0), the second
-- with item 0 beside a Blackmouth (a Catch, never an index entry, STA-R96), then one at 200 (30 over: hi25) got away.
-- 3 Catches in 10m is 18 per hour, but under the bests minimum of 20m (STA-R33).
local SESSION_2 = {
	cast({ time = T1, char = 2, subzone = AUBERDINE, rank = 175, items = { BLACKMOUTH } }),
	cast({ time = T1 + 300, char = 2, subzone = AUBERDINE, rank = 175, items = { BLACKMOUTH, 0 } }),
	cast({ time = T1 + 600, char = 2, subzone = AUBERDINE, rank = 200 }),
}
-- Session 3, 10 Oct: the player in Elwynn (no line: no margin), 25m (Casts 12m 30s apart, inside Core's 15-minute gap):
-- a Noise item, a Mackerel, then an Uncharted item (one the catalogue lacks). 3 Catches in 25m is 7.2 per hour, the
-- best.
local SESSION_3 = {
	cast({ time = T2, zone = ELWYNN, rank = 150, items = { MANA_POTION } }),
	cast({ time = T2 + 750, zone = ELWYNN, rank = 150, items = { MACKEREL } }),
	cast({ time = T2 + 1500, zone = ELWYNN, rank = 150, items = { UNCHARTED } }),
}

-- Pagle_Stats on a FakePagle whose log holds the player (1), "Ada Brook" (2) and `records`, logged in with its
-- projection built, and three of the four items named (the Uncharted one isn't loaded).
---@param records table[]
local function built(records)
	local loaded, fake = stats.start({
		records = records,
		characters = { { guid = PLAYER_GUID }, { guid = stats.OTHER_GUID, name = "Ada", surname = "Brook" } },
		items = { MACKEREL, BLACKMOUTH, MANA_POTION },
	})
	return loaded, fake
end

-- The book opened on Lifetime: its left and right content frames.
local function lifetime(loaded)
	loaded.ns.OpenBook({ page = "lifetime" })
	local pages = loaded.ns.book.pages
	local left, right = pages["lifetime:left"], pages["lifetime:right"]
	return left and left.content, right and right.content
end

-- Where a shown child of a page sits: its TOPLEFT offset from the page.
local function offset(child)
	local point = child.points[1]
	assert(point and point[1] == "TOPLEFT", "a page's pieces sit by their top left")
	return point[2], point[3]
end

-- A page as it reads: each shown piece in reading order (down the first column, then down the second), as its text or
-- its shown texts joined by " | " ("Casts | 9").
local function read(content)
	local pieces = {}
	for _, child in ipairs(content.children) do
		if child.shown then
			local words = child.text
			if words == nil or words == "" then
				words = table.concat(stats.textsOf(child), " | ")
			end
			if words ~= "" then
				local x, y = offset(child)
				pieces[#pieces + 1] = { x = x, y = y, words = words, widget = child }
			end
		end
	end
	table.sort(pieces, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.y > b.y
	end)
	local lines = {}
	for i, piece in ipairs(pieces) do
		lines[i] = piece.words
	end
	return lines, pieces
end

-- `heading` and the `n` lines after it in `lines`.
local function section(lines, heading, n)
	for i, line in ipairs(lines) do
		if line == heading then
			return { unpack(lines, i, i + n) }
		end
	end
	error("no " .. heading .. " in " .. table.concat(lines, " / "))
end

-- The shown piece of `content` that reads `words`.
local function pieceReading(content, words)
	local _, pieces = read(content)
	for _, piece in ipairs(pieces) do
		if piece.words == words then
			return piece.widget
		end
	end
	error("nothing reads " .. words)
end

describe("the Lifetime spread (stats.md › UI › Lifetime)", function()
	describe("the left page", function()
		it("reads the lifetime totals, the Sessions and the time at the water (STA-R22, STA-R33, STA-R59)", function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))

			local left = lifetime(loaded)

			local lines = read(left)
			assert.are.same({
				"LIFETIME",
				"Every Cast I've made",
				"Casts | 10", -- 4 + 3 + 3
				"Catches | 9", -- 3 + 3 (item 0 counts, STA-R22) + 3
				"Got away | 2 (20%)", -- 1 in Session 1, 1 in Session 2
				"Sessions | 3",
				"Time at the water | 1h 05m", -- 30m + 10m + 25m
			}, { unpack(lines, 1, 7) })
		end)

		it("names the longest Session and the most Catches per hour with their dates (STA-R33, STA-R59)", function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))

			local lines = read((lifetime(loaded)))

			assert.are.same({
				"BESTS",
				"Longest Session, 8 Oct 2026 | 30m", -- Session 1's 30m beats Session 3's 25m
				"Most Catches per hour, 10 Oct 2026 | 7", -- Session 3's 7.2 beats Session 1's 6; Session 2 is under 20m
			}, section(lines, "BESTS", 2))
		end)

		it("leaves out the most Catches per hour when no Session reaches 20 minutes (STA-R33)", function()
			local loaded = built(SESSION_2)

			local lines = read((lifetime(loaded)))

			assert.are.same({ "BESTS", "Longest Session, 9 Oct 2026 | 10m" }, section(lines, "BESTS", 1))
			for _, line in ipairs(lines) do
				assert.is_nil(line:find("Most Catches per hour", 1, true))
			end
		end)

		it("gives the got-away rate of each skill margin bucket with Casts, in STA-R26's order (STA-R26)", function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))

			local lines = read((lifetime(loaded)))

			-- No Cast was 1–49 below the line, and Elwynn's Casts have no line: neither has a line here.
			assert.are.same({
				"GOT AWAY, BY SKILL | against each water's no-junk line",
				"below by 50+ | 25% of 4 Casts", -- Session 1: 1 of 4 got away
				"0–24 over | 0% of 2 Casts", -- Session 2's first two Casts
				"25+ over | 100% of 1 Cast", -- Session 2's last Cast got away
				"CHARACTERS",
			}, section(lines, "GOT AWAY, BY SKILL | against each water's no-junk line", 4))
		end)

		it("lists each character with Casts, alphabetically by name, with their numbers (STA-R22, STA-R59)", function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))

			local lines = read((lifetime(loaded)))

			-- "Ada Brook" is the log's second character, "Angler Tester" its first: by name, Ada comes first.
			assert.are.same({
				"CHARACTERS",
				"Ada Brook | 3 Casts · 3 Catches · 1 got away",
				"Angler Tester | 7 Casts · 6 Catches · 1 got away", -- Sessions 1 and 3
			}, section(lines, "CHARACTERS", 2))
			assert.are.equal("Angler Tester | 7 Casts · 6 Catches · 1 got away", lines[#lines])
		end)

		it("reads one Cast, Catch and character's Casts in the singular (STA-R59)", function()
			local loaded = built({ SESSION_1[2] })

			local lines = read((lifetime(loaded)))

			assert.are.same(
				{ "CHARACTERS", "Angler Tester | 1 Cast · 1 Catch · 0 got away" },
				section(lines, "CHARACTERS", 1)
			)
			assert.are.same(
				{ "GOT AWAY, BY SKILL | against each water's no-junk line", "below by 50+ | 0% of 1 Cast" },
				section(lines, "GOT AWAY, BY SKILL | against each water's no-junk line", 1)
			)
		end)
	end)

	describe("the right page", function()
		it(
			"indexes every item caught in two columns, most caught first, Noise and Uncharted included, never item 0 "
				.. "(STA-R25, STA-R96)",
			function()
				local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))

				local _, right = lifetime(loaded)

				-- Down the first column, then the second; the two caught once by item ID. The Uncharted item isn't
				-- loaded: "Item {id}" until it is, and the book asks for it (STA-R59, STA-R73).
				assert.are.same({
					"THE CATCH",
					"Every fish",
					"How many I've caught. Hover for first and last; click for its waters.",
					"Raw Mackerel | 4", -- 3 in Session 1, 1 in Session 3
					"Oily Blackmouth | 2",
					"Minor Mana Potion | 1", -- Noise
					"Item 77777 | 1", -- Uncharted
				}, read(right))
				local _, pieces = read(right)
				assert.are.equal(pieces[4].x, pieces[5].x)
				assert.is_true(pieces[6].x > pieces[4].x)
				assert.are.equal(pieces[4].y, pieces[6].y)
				-- search (adapter/Search.lua) also asks, as the book opens, for the unnamed fish on the rows of the
				-- zones I've fished
				assert.are.equal(UNCHARTED, loaded.client.itemRequests[1])
			end
		)

		it('shows "First {date}, last {date}" on hovering an item (STA-R25, STA-R59)', function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))
			local _, right = lifetime(loaded)
			local entry = pieceReading(right, "Raw Mackerel | 4")

			entry:GetScript("OnEnter")(entry)
			local tooltip = loaded.client.gameTooltip
			assert.are.same({ entry, { "First 8 Oct 2026, last 10 Oct 2026" }, true }, {
				tooltip.owner,
				tooltip.lines,
				tooltip.shown,
			})
			entry:GetScript("OnLeave")(entry)

			assert.is_false(tooltip.shown)
		end)

		it("opens an item's page on clicking it (STA-R74)", function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))
			local _, right = lifetime(loaded)

			pieceReading(right, "Oily Blackmouth | 2"):Click()

			assert.are.same({ page = "item", item = BLACKMOUTH }, loaded.ns.book.router:Place())
		end)

		it("returns the index's height, so a long index scrolls (STA-R70)", function()
			local loaded = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))
			local _, right = lifetime(loaded)
			local _, pieces = read(right)

			-- Below the lowest entry, the first column's second.
			local lowest = pieces[5].widget
			assert.is_true(right.height >= -pieces[5].y + lowest.height)
		end)
	end)

	it('reads "No Sessions yet." on both pages with no Casts (STA-R97)', function()
		local loaded = built({})

		local left, right = lifetime(loaded)

		assert.are.same({ "LIFETIME", "Every Cast I've made", "No Sessions yet." }, read(left))
		assert.are.same({ "THE CATCH", "Every fish", "No Sessions yet." }, read(right))
	end)

	it("redraws in place: a Cast later, each line once with the new numbers (STA-R73)", function()
		local loaded, fake = built(stats.concat(SESSION_1, SESSION_2, SESSION_3))
		local left, right = lifetime(loaded)
		local before = #read(left)

		fake.playCast("caught", { { itemID = MANA_POTION, quantity = 1 } })
		loaded.client.runTimers()

		local lines = read(left)
		assert.are.equal(before, #lines)
		assert.are.equal("Casts | 11", lines[3])
		assert.are.same(
			-- The Mana Potion ties the Blackmouth at 2 and has the lower item ID.
			{ "Raw Mackerel | 4", "Minor Mana Potion | 2", "Oily Blackmouth | 2", "Item 77777 | 1" },
			{ unpack(read(right), 4) }
		)
	end)
end)
