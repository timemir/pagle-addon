-- The Journal's news list on FakePagle (LED-R176–R179, LED-R163's News link, LED-R125, LED-R126, LED-R129): Home »
-- Following » News, every item of the news block newest first, the chosen item on the right, the empty states, the
-- marking, and the ways in: def.news(id), which the sign's left click calls (SIGN-R42, VIEW-R46), and the Following
-- spread's link.
--
-- The news is FakePagle's, over Core's real reader and words (VIEW-R42, VIEW-R43, VIEW-R45): each spec's lines ride
-- in Pagle_Following's news block (newsJournal below), the floor and the seen items in fake.global.news (VIEW-R44), and
-- each item is worded by Pagle.NewsWords (said below). So these specs hold what the Ledger draws from those calls; how
-- Core words an item, and what it keeps from naming (VAR-R27), are Core's own specs'. The lines are IGV Contracts'
-- `news-line` shape (pagle-backend's IGV-R60–R66), the Angler of `angler` 1 being Ada, Following.txt's.

local HOUR, DAY = 3600, 24 * 3600

-- The names the fake client gives the fish the lines name (SIGN-R19).
local ITEM_NAMES = {
	[4603] = "Spotted Yellowtail",
	[6291] = "Raw Brilliant Smallfish",
	[6358] = "Oily Blackmouth",
	[19805] = "Keefer's Angelfish",
}

-- Core's words for the item `id` of the news now (Pagle.NewsWords, VIEW-R45), as the sign and the list draw them.
---@param fake FakePagle
---@param id string
---@return PagleNewsSignNews
local function said(fake, id)
	for _, item in ipairs(fake.Pagle.GetNews().items) do
		if item.id == id then
			return fake.Pagle.NewsWords(item)
		end
	end
	error("no news item " .. id)
end

-- A news line (IGV Contracts' `news-line`), about Ada (`angler` 1) unless `fields` say otherwise, `age` seconds old;
-- `new` is the spec's own mark, not the line's: newsJournal marks every item without it seen (VIEW-R44), so GetNews
-- calls only those with it new (VIEW-R42).
---@param id string
---@param kind string
---@param age integer
---@param fields table?
---@return table
local function line(id, kind, age, fields)
	local item = {
		id = id,
		kind = kind,
		time = SERVER_TIME - age,
		angler = 1,
		name = "Ada",
		region = "",
		item = 0,
		rank = 0,
		key = "",
		text = "",
		zone = 0,
		length = 0,
		new = false,
	}
	for key, value in pairs(fields or {}) do
		item[key] = value
	end
	return item
end

-- Four items in the file's order, as GetNews hands them out (VIEW-R42): a Monster an hour old and new, Hunt gold three
-- hours old and new, a region headline about an Angler the player doesn't follow two days old, and a Legend as old as
-- the Monster.
local function four()
	return {
		line("3f9a0c1d2e4b5a69", "monster", HOUR, { item = 6291, length = 544, new = true }),
		line("a01b2c3d4e5f6071", "hunt", 3 * HOUR, { key = "night_run", text = "The Night Run", new = true }),
		line(
			"77c0e1f2a3b4c5d6",
			"region",
			2 * DAY + HOUR,
			{ angler = 0, name = "Grimtusk", region = "eu", item = 6358 }
		),
		line("0123456789abcdef", "legend", HOUR, { item = 19805 }),
	}
end

-- A Pagle_Following file of Ada alone, written ten minutes ago (`age` seconds when given).
---@param age integer?
---@return table
local function file(age)
	local data = anglerFileExamples().following
	data.generatedAt = SERVER_TIME - (age or 600)
	return data
end

-- A Ledger on a fake whose news is `news` ({ state, items }), logged in, in the world, with the Journal open on
-- `options.id` with `options.args` (Home by default; `false` leaves it closed). Pagle_Following is Ada's file()
-- carrying `items` as its news block while `ok`; with none for `none`, written a day ago for `expired` and not
-- installed for `absent`. The floor is 30 days back and every item not marked `new` is seen (VIEW-R44). Returns the
-- fake, the loaded Ledger, and each Pagle.MarkNewsSeen call's argument ("all" for none), each still Core's own.
---@param news { state: string, items: table[]? }
---@param options table?
---@return FakePagle fake
---@return LoadedAddon loaded
---@return any[] marked
local function newsJournal(news, options)
	options = options or {}
	local marked = {}
	local following
	if news.state ~= "absent" then
		following = file(news.state == "expired" and DAY or nil)
		if news.state ~= "none" then
			following.news = {}
			for i, item in ipairs(news.items or {}) do
				local copy = {}
				for key, value in pairs(item) do
					copy[key] = value
				end
				copy.new = nil
				following.news[i] = copy
			end
		end
	end
	local fake, loaded = openJournal({
		globals = { BreakUpLargeNumbers = breakUpLargeNumbers },
		characters = { { guid = PLAYER_GUID, name = "Kukli" } },
		following = following,
		modules = function(fake)
			local seen = {}
			for _, item in ipairs(news.items or {}) do
				if not item.new then
					seen[item.id] = item.time
				end
			end
			fake.global.news = { since = SERVER_TIME - 30 * DAY, seen = seen }
			for id, name in pairs(ITEM_NAMES) do
				fake.itemNames[id] = name
			end
			local markNewsSeen = fake.Pagle.MarkNewsSeen
			fake.Pagle.MarkNewsSeen = function(ids)
				marked[#marked + 1] = ids or "all"
				return markNewsSeen(ids)
			end
		end,
		id = options.id,
		args = options.args,
	})
	return fake, loaded, marked
end

-- The rows of the news list's left page: each one's dot (true for a new item), kicker, headline and age.
---@param blocks LedgerBlock[]
---@return table[]
local function rows(blocks)
	local list = {}
	for _, block in ipairs(blocks) do
		if block.kind == "newsRow" then
			list[#list + 1] = { block.new == true, block.kicker, block.text, block.value }
		end
	end
	return list
end

-- Every text drawn on both pages of the open book: the shown font strings of each page body.
---@param loaded LoadedAddon
---@return string
local function pageWords(loaded)
	local journal = loaded.ns.journal
	local texts = {}
	for _, side in ipairs({ "left", "right" }) do
		shownTexts(journal.shown[side], texts)
	end
	return table.concat(texts, "\n")
end

describe("getting to the news list (LED-R178, LED-R176, LED-R125)", function()
	it(
		"opens the Journal, closed, on the news list with the sign's item chosen, through def.news: Home » Following » News (LED-R178, SIGN-R42, VIEW-R46)",
		function()
			local fake, loaded = newsJournal({ state = "ok", items = four() }, { id = false })
			local journal = loaded.ns.journal
			assert.is_false(journal:IsShown())

			-- what the sign's left click calls: the first On Module's def.news, the Ledger's
			assert.is_true(fake.ns.OpenNews("a01b2c3d4e5f6071"))

			assert.is_true(journal:IsShown())
			assert.are.same({ id = "news", args = { id = "a01b2c3d4e5f6071" } }, journal.router:Place())
			assert.are.same({ "Home", "Following", "News" }, {
				journal.pages.crumbs[1].label,
				journal.pages.crumbs[2].label,
				journal.pages.crumbs[3].label,
			})
			assert.are.same({ id = "following" }, journal.pages.crumbs[2].place)
			assert.are.same({ id = "following" }, journal.pages.back)
			assert.is_true(journal.frame.back:IsShown())
			assert.are.equal(said(fake, "a01b2c3d4e5f6071").head, blockOfKind(journal.pages.right, "title").text)
		end
	)

	it(
		"opens on the newest item when def.news names none, or one the news doesn't have (LED-R176, LED-R178)",
		function()
			local fake, loaded = newsJournal({ state = "ok", items = four() }, { id = false })
			local journal = loaded.ns.journal

			local monster = said(fake, "3f9a0c1d2e4b5a69").head
			fake.ns.OpenNews()
			assert.are.equal(monster, blockOfKind(journal.pages.right, "title").text)

			fake.ns.OpenNews("ffffffffffffffff")
			assert.are.equal(monster, blockOfKind(journal.pages.right, "title").text)
		end
	)

	it("opens while restricted: it makes no secure frames (LED-R178, LED-R121)", function()
		local fake, loaded = newsJournal({ state = "ok", items = four() }, { id = false })
		fake.setRestricted(true)

		fake.ns.OpenNews("3f9a0c1d2e4b5a69")

		assert.is_true(loaded.ns.journal:IsShown())
		assert.are.same({ id = "news", args = { id = "3f9a0c1d2e4b5a69" } }, loaded.ns.journal.router:Place())
	end)

	it(
		"is the Ledger's view, offered to Core as def.news, so the sign only goes up with the Ledger off (VIEW-R46, SIGN-R42)",
		function()
			local off = newFakePagle()
			local on = newsJournal({ state = "ok", items = four() })

			assert.is_nil(off.ns.NewsOffered())
			assert.is_false(off.ns.OpenNews("3f9a0c1d2e4b5a69"))
			assert.is_function(on.ns.NewsOffered())
		end
	)

	it(
		'links from the Following spread: "News: {n} new »" while any item is new, opening the list (LED-R163, LED-R178)',
		function()
			local _, loaded = newsJournal({ state = "ok", items = four() }, { id = "following" })
			local journal = loaded.ns.journal
			local left = journal.pages.left

			assert.are.same({ kind = "link", hand = true, text = "News: 2 new »", place = { id = "news" } }, left[4])
			assert.are.equal("text", left[3].kind) -- under the count line

			local link = journal.shown.left.drawn.link[1]
			assert.are.same({ "News: 2 new »" }, shownTexts(link))
			link:Click()
			assert.are.same({ id = "news" }, journal.router:Place())
		end
	)

	it('reads "News »" with nothing new, and shows in every state but absent (LED-R163)', function()
		local seen = {}
		for _, case in ipairs({
			{ "ok", { state = "ok", items = { line("3f9a0c1d2e4b5a69", "legend", HOUR) } } },
			{ "none", { state = "none" } },
			{ "expired", { state = "expired" } },
			{ "absent", { state = "absent" } },
		}) do
			local _, loaded = newsJournal(case[2], { id = "following" })
			local link = blockOfKind(loaded.ns.journal.pages.left, "link")
			seen[case[1]] = link and link.text or false
		end

		assert.are.same({ ok = "News »", none = "News »", expired = "News »", absent = false }, seen)
	end)
end)

describe("the news list's left page (LED-R176)", function()
	it(
		"reads its kicker, title and line, then a row per item, newest first, ties in the file's order (LED-R176)",
		function()
			local fake, loaded = newsJournal({ state = "ok", items = four() }, { id = "news" })
			local left = loaded.ns.journal.pages.left
			local function row(new, id, age)
				local words = said(fake, id)
				return { new, words.kicker, words.head, age }
			end

			assert.are.same({ kind = "kicker", text = "The Morning Tide" }, left[1])
			assert.are.same({ kind = "title", text = "News" }, left[2])
			assert.are.same({
				kind = "text",
				text = "From the Anglers you follow, and your region's firsts this month. What the sign shows is set in Settings.",
			}, left[3])
			assert.are.same({
				row(true, "3f9a0c1d2e4b5a69", "1 h"),
				row(false, "0123456789abcdef", "1 h"),
				row(true, "a01b2c3d4e5f6071", "3 h"),
				row(false, "77c0e1f2a3b4c5d6", "2 d"),
			}, rows(left))
		end
	)

	it('ages an item "{n} h" under a day and "{n} d" from then on (LED-R176)', function()
		local _, loaded = newsJournal({
			state = "ok",
			items = {
				line("0000000000000001", "first", 20 * 60),
				line("0000000000000002", "first", DAY - 1),
				line("0000000000000003", "first", DAY),
				line("0000000000000004", "first", 29 * DAY + 23 * HOUR),
			},
		}, { id = "news" })

		local ages = {}
		for i, row in ipairs(rows(loaded.ns.journal.pages.left)) do
			ages[i] = row[4]
		end
		assert.are.same({ "0 h", "23 h", "1 d", "29 d" }, ages)
	end)

	it(
		"draws a row for every kind, the region headline among them, in NewsWords' words (LED-R176, VIEW-R45)",
		function()
			local kinds = { "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster", "region" }
			local items = {}
			for i, kind in ipairs(kinds) do
				items[i] = line(("%016x"):format(i), kind, i * 60, { angler = kind == "region" and 0 or 1 })
			end
			local fake, loaded = newsJournal({ state = "ok", items = items }, { id = "news" })
			local journal = loaded.ns.journal

			local drawn = rows(journal.pages.left)
			assert.are.equal(9, #drawn)
			for i in ipairs(kinds) do
				local words = said(fake, items[i].id)
				assert.are.same({ false, words.kicker, words.head, "0 h" }, drawn[i])
			end
			-- each row as drawn: its kicker, its headline and its age, the headline on one line
			local row = journal.shown.left.drawn.newsRow[9]
			local region = said(fake, items[9].id)
			assert.are.same({ region.kicker, region.head, "0 h" }, shownTexts(row))
			assert.is_false(row.head:CanWordWrap())
		end
	)

	it("marks a new item's row with the red wax dot, and only a new one's (LED-R176, VIEW-R42)", function()
		local _, loaded = newsJournal({ state = "ok", items = four() }, { id = "news" })
		local drawn = loaded.ns.journal.shown.left.drawn.newsRow

		assert.are.same({ true, false, true, false }, {
			drawn[1].dot:IsShown(),
			drawn[2].dot:IsShown(),
			drawn[3].dot:IsShown(),
			drawn[4].dot:IsShown(),
		})
	end)

	it("chooses an item when its row is clicked, keeping the list's scroll (LED-R176, LED-R129)", function()
		local fake, loaded = newsJournal({ state = "ok", items = four() }, { id = "news" })
		local journal = loaded.ns.journal
		assert.is_true(journal.pages.left[4].selected)

		journal.shown.left.drawn.newsRow[4]:Click()

		assert.are.same({ id = "news", args = { id = "77c0e1f2a3b4c5d6" } }, journal.router:Place())
		assert.is_nil(journal.pages.left[4].selected)
		assert.is_true(journal.pages.left[7].selected)
		assert.are.equal(said(fake, "77c0e1f2a3b4c5d6").head, blockOfKind(journal.pages.right, "title").text)
		assert.are.equal("news", journal.pages.subjects.left)
	end)
end)

describe("the news list's right page (LED-R176)", function()
	it(
		"shows the chosen item: its emblem at 96, kicker, headline, detail and date, and a followed Angler's card link (LED-R176, LED-R126)",
		function()
			local fake, loaded = newsJournal(
				{ state = "ok", items = four() },
				{ id = "news", args = { id = "a01b2c3d4e5f6071" } }
			)
			local journal = loaded.ns.journal
			local right = journal.pages.right
			local words = said(fake, "a01b2c3d4e5f6071")

			assert.are.same({
				{ kind = "newsEmblem", emblem = words.emblem },
				{ kind = "kicker", text = words.kicker },
				{ kind = "title", text = words.head },
				{ kind = "text", style = "italic", text = "The Night Run" },
				{ kind = "text", color = "faded", text = "11 Oct" },
				{ kind = "link", text = "See Ada's card »", place = { id = "following", args = { angler = 1 } } },
			}, right)
			local emblem = journal.shown.right.drawn.newsEmblem[1]
			assert.are.same({ 96, 96 }, { emblem.art:GetSize() })
			assert.are.same({ emblem = words.emblem, size = 96 }, emblem.art.newsEmblem) -- Core draws it (SIGN-R13)
		end
	)

	it("opens the Following spread with that Angler chosen from the card link (LED-R176, LED-R163)", function()
		local _, loaded = newsJournal({ state = "ok", items = four() }, { id = "news" })
		local journal = loaded.ns.journal

		journal.shown.right.drawn.link[1]:Click()

		assert.are.same({ id = "following", args = { angler = 1 } }, journal.router:Place())
		assert.are.equal("Ada", blockOfKind(journal.pages.right, "title").text)
	end)

	it(
		"says how to follow the Angler of a region headline the player doesn't follow, in the hand (LED-R176)",
		function()
			local _, loaded = newsJournal(
				{ state = "ok", items = four() },
				{ id = "news", args = { id = "77c0e1f2a3b4c5d6" } }
			)
			local right = loaded.ns.journal.pages.right

			assert.are.same(
				{ kind = "text", hand = true, text = "Follow them from their page on the Pagle website." },
				right[#right]
			)
			assert.is_nil(blockOfKind(right, "link"))
		end
	)

	it(
		"keeps a variety the player hasn't caught unnamed: only NewsWords' words and its silhouette (LED-R176, VAR-R27)",
		function()
			local colour = line("c0c0c0c0c0c0c0c0", "colour", HOUR, { item = 4603, key = "all-gold", new = true })
			local fake, loaded = newsJournal({ state = "ok", items = { colour } }, { id = "news" })
			local journal = loaded.ns.journal
			local right = journal.pages.right
			local words = said(fake, colour.id)

			assert.is_true(words.emblem.variety.silhouette)
			assert.are.equal("Rare Spotted Yellowtail", words.detail)
			assert.are.same(words.emblem, right[1].emblem)
			assert.are.equal(words.detail, right[4].text)
			local drawn = pageWords(loaded)
			assert.is_nil(drawn:find("All-gold", 1, true))
			assert.is_nil(drawn:find("all-gold", 1, true))
		end
	)

	it("names Anglers only, never a character: the line's name, never the log's (LED-R176, SIGN-R11)", function()
		local _, loaded = newsJournal({ state = "ok", items = four() }, { id = "news" })

		local words = pageWords(loaded)
		assert.truthy(words:find("See Ada's card »", 1, true))
		assert.is_nil(words:find("Kukli", 1, true))
		assert.is_nil(words:find("Player-", 1, true))
	end)
end)

describe("the news list's empty states (LED-R179)", function()
	for _, case in ipairs({
		{
			"absent, with no Companion",
			{ state = "absent" },
			{
				"The Companion keeps this page.",
				"Anglers you follow on the Pagle website are brought into the game by the Pagle Companion.",
				"Without it, this page stays empty. Pasting your log still updates your own Angler page.",
			},
		},
		{
			"expired",
			{ state = "expired" },
			{
				"These pages are more than a day old.",
				"Pagle has set them aside until the Companion brings fresh ones.",
				"Start the Companion, then /reload.",
			},
		},
		{
			"none, a Companion that brings no news",
			{ state = "none" },
			{
				"The news comes with the Companion.",
				"Update the Pagle Companion to bring news of the Anglers you follow.",
				"Their cards still show on the Following spread.",
			},
		},
		{
			"ok with no item",
			{ state = "ok", items = {} },
			{
				"No news this month.",
				"When an Angler you follow lands a Legend, takes a Prestige or completes the Ledger, it shows here, and on the sign at your next login.",
			},
		},
	}) do
		it(("keeps its kicker and title with %s, the right page blank (LED-R179)"):format(case[1]), function()
			local _, loaded, marked = newsJournal(case[2], { id = "news" })
			local pages = loaded.ns.journal.pages

			local expected = { "The Morning Tide", "News" }
			for _, text in ipairs(case[3]) do
				expected[#expected + 1] = text
			end
			assert.are.same(expected, blockTexts(pages.left))
			assert.is_true(pages.left[3].hand)
			assert.are.equal("faded", pages.left[#pages.left].color)
			assert.are.same({}, pages.right)
			assert.are.same(
				{ "Home", "Following", "News" },
				{ pages.crumbs[1].label, pages.crumbs[2].label, pages.crumbs[3].label }
			)
			assert.are.same({}, marked)
		end)
	end
end)

describe("marking the news seen (LED-R177)", function()
	it(
		"marks every item seen each time the list is drawn with items, the dots staying for the session (LED-R177, VIEW-R43)",
		function()
			local _, loaded, marked = newsJournal({ state = "ok", items = four() }, { id = "news" })
			local journal = loaded.ns.journal
			assert.are.same({ "all" }, marked)

			journal.shown.left.drawn.newsRow[2]:Click()

			assert.are.same({ "all", "all" }, marked)
			assert.are.same(
				{ true, false, true, false },
				(function()
					local dots = {}
					for i, row in ipairs(rows(journal.pages.left)) do
						dots[i] = row[1]
					end
					return dots
				end)()
			)
		end
	)

	it("marks nothing while the list isn't drawn: on another spread, or with the book closed (LED-R177)", function()
		local _, loaded, marked = newsJournal({ state = "ok", items = four() }, { id = "following" })
		assert.are.same({}, marked)

		loaded.ns.journal:Close()
		assert.are.same({}, marked)
	end)
end)
