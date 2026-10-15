-- The home spread in the Stats book on FakePagle (stats.md › UI › Home spread; STA-R10, STA-R13, STA-R32, STA-R60,
-- STA-R64, STA-R73, STA-R74, STA-R93, STA-R97): Casts played through Core's real Cast state machine and Sessions over
-- the fixture catalogue, the book opened through its entry points, and each page's words and links read back. The
-- lines' every form is in logic/Home_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN = 148, 442, 446, 12
local FERALAS, FEATHERMOON = 357, 1116
local MACKEREL, BLACKMOUTH = 6303, 6358

-- Moves the player: `fields` replace those of the live snapshot (zone, subzone, minute, skillRank, ...).
local function move(fake, fields)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	for key, value in pairs(fields) do
		conditions[key] = value ~= false and value or nil
	end
	fake.setConditions(conditions)
end

-- Pagle_Stats on a fake that has logged in, its projection built, every area named, fishing Auberdine at realm 08:15
-- (day) with skill 86 + 25 = 111 (FakePagle's), and Stats' server time where the fake's clock is.
local function ready()
	local loaded, fake = stats.load()
	local names = loaded.client.areaNames
	names[DARKSHORE], names[AUBERDINE], names[BASHAL_ARAN] = "Darkshore", "Auberdine", "Bashal'Aran"
	names[ELWYNN], names[FERALAS], names[FEATHERMOON] = "Elwynn Forest", "Feralas", "Feathermoon Stronghold"
	loaded.client.itemNames[BLACKMOUTH] = "Oily Blackmouth"
	fake.login()
	fake.enterWorld()
	move(fake, { zone = DARKSHORE, subzone = AUBERDINE })
	loaded.env.GetServerTime = function()
		return fake.serverTime()
	end
	return loaded, fake, loaded.ns.book
end

-- Plays `n` Casts: caught `itemID`, or got away with none.
local function fish(fake, n, itemID)
	for _ = 1, n do
		if itemID then
			fake.playCast("caught", { { itemID = itemID, quantity = 1 } })
		else
			fake.playCast("gotAway")
		end
	end
end

-- The home spread's two views, as adapter/Home.lua keeps them on each side's content.
local function waters(book)
	return book.pages["home:left"].content.waters
end
local function rightNow(book)
	return book.pages["home:right"].content.rightNow
end

-- Each shown tile's name, line, "I'm here" and note ("-" for one not shown).
local function tilesOf(book)
	local out = {}
	for _, tile in ipairs(waters(book).grid.tiles) do
		if tile.shown then
			local function read(text)
				return text.shown and text.text or "-"
			end
			out[#out + 1] = table.concat({ tile.name.text, read(tile.line), read(tile.here), read(tile.note) }, " | ")
		end
	end
	return out
end

-- The words of each shown watch line, and of each shown In this book link with its number.
local function watchLines(book)
	local out = {}
	for _, line in ipairs(rightNow(book).watches) do
		if line.shown then
			out[#out + 1] = line.label.text
		end
	end
	return out
end
local function links(book)
	local out = {}
	for _, link in ipairs(rightNow(book).links) do
		if link.shown then
			out[#out + 1] = link.label.text .. (link.value.text ~= "" and (" " .. link.value.text) or "")
		end
	end
	return out
end

describe("the home spread's left page, Where I've fished (stats.md › UI › Home spread)", function()
	it("reads its kicker, title and line, then tiles each zone by my Casts with its waters", function()
		local loaded, fake, book = ready()
		fish(fake, 2, BLACKMOUTH)
		move(fake, { subzone = BASHAL_ARAN })
		fish(fake, 1)
		move(fake, { zone = ELWYNN, subzone = 0 })
		fish(fake, 1, BLACKMOUTH)

		loaded.ns.ToggleBook()

		local view = waters(book)
		assert.are.same({ "THE WATERS", "Where I've fished" }, { view.kicker.text, view.title.text })
		assert.are.equal("Your odds and Dry spells come only from my own Casts, never from game data.", view.intro.text)
		assert.is_false(view.empty.shown)
		assert.are.same({
			"Darkshore | 3 Casts · 2 waters | - | -",
			"Elwynn Forest | 1 Cast · 0 waters | I'm here | -",
		}, tilesOf(book))
	end)

	it(
		"gives the current zone a tile with no Casts, first, and notes watching 1 on a watch's zone from its subzone",
		function()
			local loaded, fake, book = ready()
			fish(fake, 2, BLACKMOUTH)
			move(fake, { zone = ELWYNN, subzone = 0 })
			fish(fake, 3, BLACKMOUTH)
			move(fake, { zone = FERALAS, subzone = FEATHERMOON })
			loaded.ns.db.profile.watched = { { item = BLACKMOUTH, area = AUBERDINE } }

			loaded.ns.ToggleBook()

			assert.are.same({
				"Feralas | not fished yet | I'm here | -",
				"Elwynn Forest | 3 Casts · 0 waters | - | -",
				"Darkshore | 2 Casts · 1 water | - | watching 1",
			}, tilesOf(book))
		end
	)

	it("opens a zone's place page from its tile", function()
		local loaded, fake, book = ready()
		fish(fake, 1)
		loaded.ns.ToggleBook()

		waters(book).grid.tiles[1]:Click()

		assert.are.same({ page = "place", area = DARKSHORE }, book.router:Place())
	end)

	it('reads "Not fished anywhere yet." with no Casts, and no tiles (STA-R97)', function()
		local loaded, _, book = ready()

		loaded.ns.ToggleBook()

		assert.is_true(waters(book).empty.shown)
		assert.are.equal("Not fished anywhere yet.", waters(book).empty.text)
		assert.are.same({}, tilesOf(book))
	end)
end)

describe("the home spread's right page, Right now (stats.md › UI › Home spread)", function()
	it("reads the place by day, the skill below the line, and this Session so far, in handwriting", function()
		local loaded, fake, book = ready()
		fish(fake, 2, BLACKMOUTH)
		fish(fake, 1)
		fake.wait(300)

		loaded.ns.ToggleBook()

		local view = rightNow(book)
		assert.are.equal("RIGHT NOW", view.kicker.text)
		-- STA-R12: Darkshore's line is 75 + 95 = 170; FakePagle's Fishing is 86 + 25
		assert.are.equal(
			"Fishing Auberdine, Darkshore, by day. Skill 111, below the no-junk line (170).",
			view.where.text
		)
		assert.are.equal("This Session: 3 Casts, 2 Catches, 1 got away, 5m so far.", view.session.text)
		assert.are.same(loaded.ns.BOOK_LOOK.hand, { unpack(view.session.textColor, 1, 3) })
	end)

	it("redraws a skill past the line, by night on its tick, and the last Session's end (STA-R73)", function()
		local loaded, fake, book = ready()
		fish(fake, 1, BLACKMOUTH)
		loaded.ns.ToggleBook()
		fake.readSkill(200, 225, 25)
		loaded.client.runTimers()
		assert.are.equal(
			"Fishing Auberdine, Darkshore, by day. Skill 225, past the no-junk line (170).",
			rightNow(book).where.text
		)

		move(fake, { minute = 1200 }) -- realm 20:00: not an area or skill change, so the tick redraws it
		fake.wait(600)
		loaded.client.advance(30)
		assert.are.equal(
			"Fishing Auberdine, Darkshore, by night. Skill 225, past the no-junk line (170).",
			rightNow(book).where.text
		)
		assert.are.equal("This Session: 1 Cast, 1 Catch, 0 got away, 10m so far.", rightNow(book).session.text)

		fake.wait(3 * 3600)
		loaded.client.runTimers()
		assert.are.equal("No Session right now. The last one ended 3h ago.", rightNow(book).session.text)
	end)

	it("leaves out what it can't read in combat: zone 0, the skill and the realm minute (STA-R93)", function()
		local loaded, fake, book = ready()
		move(fake, { zone = 0, subzone = 0, skillRank = false, skillMod = false, minute = false })

		loaded.ns.ToggleBook()

		assert.are.equal("I can't tell where I am.", rightNow(book).where.text)
		assert.are.same({ "Where I am: unknown", "This Session", "Lifetime 0", "Every Session 0" }, links(book))
		rightNow(book).links[1]:Click()
		assert.are.same({ page = "home" }, book.router:Place())

		move(fake, { zone = DARKSHORE, subzone = AUBERDINE })
		loaded.client.runTimers()
		assert.are.equal("Fishing Auberdine, Darkshore.", rightNow(book).where.text)
	end)

	it('reads "No Session yet." with no Casts, and Where I am opens the current place (STA-R97)', function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()

		assert.are.equal("No Session yet.", rightNow(book).session.text)
		rightNow(book).links[1]:Click()

		assert.are.same({ page = "place", area = AUBERDINE }, book.router:Place())
		assert.are.equal(0, loaded.ns.State().totals.casts)
	end)

	describe("Dry spells I'm watching (STA-R60, STA-R64)", function()
		it("heads them, and reads the empty line with no watches", function()
			local loaded, _, book = ready()

			loaded.ns.ToggleBook()

			local view = rightNow(book)
			assert.are.same(
				{ "DRY SPELLS I'M WATCHING", "also on the live tracker" },
				{ view.watched.label.text, view.watched.note.text }
			)
			assert.are.same({}, watchLines(book))
			assert.are.equal("Nothing yet. Watch a Dry spell from any fish's page.", view.noWatches.text)
			assert.is_true(view.noWatches.shown)
		end)

		it("writes each watch after a pencil mark, its band in red, each opening its entry", function()
			local loaded, fake, book = ready()
			-- 100 Casts on the lo side of Darkshore: 50 Blackmouth, then 50 got away. k/n = 0.5, since 50:
			-- P = 0.5^50, very unlucky (STA-R52); Your odds is known at 100 Casts (STA-R43).
			fish(fake, 50, BLACKMOUTH)
			fish(fake, 50)
			loaded.ns.db.profile.watched = {
				{ item = BLACKMOUTH, area = DARKSHORE },
				{ item = MACKEREL, area = AUBERDINE },
			}
			loaded.client.itemNames[MACKEREL] = "Raw Mackerel"

			loaded.ns.ToggleBook()

			local red = loaded.ns.BOOK_LOOK.red
			local hex = ("%02x%02x%02x"):format(red[1] * 255 + 0.5, red[2] * 255 + 0.5, red[3] * 255 + 0.5)
			assert.are.same({
				"Oily Blackmouth, Darkshore: 50 since the last|cff" .. hex .. ", very unlucky|r.",
				"Raw Mackerel, Auberdine: 100 Casts, none yet.",
			}, watchLines(book))
			local line = rightNow(book).watches[1]
			assert.are.equal(loaded.ns.BOOK_TEXTURES.pencil, line.mark.texture)
			assert.is_false(rightNow(book).noWatches.shown)
			rightNow(book).watches[2]:Click()
			assert.are.same({ page = "place", area = AUBERDINE, item = MACKEREL }, book.router:Place())
		end)

		it("asks for a watched item's name, and redraws with it once it loads (STA-R73)", function()
			local loaded, fake, book = ready()
			loaded.ns.db.profile.watched = { { item = MACKEREL, area = DARKSHORE } }

			loaded.ns.ToggleBook()
			assert.are.same({ "Item 6303, Darkshore: 0 Casts, none yet." }, watchLines(book))
			assert.are.same({ MACKEREL }, loaded.client.itemRequests)
			loaded.client.itemNames[MACKEREL] = "Raw Mackerel"
			fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", MACKEREL, true)
			loaded.client.runTimers()

			assert.are.same({ "Raw Mackerel, Darkshore: 0 Casts, none yet." }, watchLines(book))
		end)

		it("redraws when a watch changes (STA-R73)", function()
			local loaded, _, book = ready()
			loaded.ns.ToggleBook()

			loaded.ns.db.profile.watched = { { item = BLACKMOUTH, area = DARKSHORE } }
			loaded.ns.Redraw("watches")
			loaded.client.runTimers()

			assert.are.same({ "Oily Blackmouth, Darkshore: 0 Casts, none yet." }, watchLines(book))
		end)
	end)

	describe("In this book (STA-R74)", function()
		it(
			"lists Where I am, This Session or My last Session, Lifetime and Every Session, each opening its page",
			function()
				local loaded, fake, book = ready()
				fish(fake, 2, BLACKMOUTH)
				loaded.ns.ToggleBook()

				local view = rightNow(book)
				assert.are.equal("IN THIS BOOK", view.contents.label.text)
				assert.are.same(
					{ "Where I am: Auberdine", "This Session", "Lifetime 2", "Every Session 1" },
					links(book)
				)
				for i, target in ipairs({
					{ page = "place", area = AUBERDINE },
					{ page = "session" },
					{ page = "lifetime" },
					{ page = "sessions" },
				}) do
					loaded.ns.OpenBook({ page = "home" })
					rightNow(book).links[i]:Click()
					assert.are.same(target, book.router:Place())
				end

				fake.wait(3600)
				loaded.ns.OpenBook({ page = "home" })
				assert.are.same("My last Session", rightNow(book).links[2].label.text)
			end
		)
	end)
end)
