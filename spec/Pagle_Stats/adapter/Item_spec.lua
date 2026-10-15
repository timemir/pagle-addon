-- The item page in the Stats book on FakePagle (stats.md › UI › Item page; STA-R17, STA-R43, STA-R50, STA-R73,
-- STA-R74): Casts played through Core's real Cast state machine over the fixture catalogue, the page opened through
-- ns.OpenBook, and each page's words and links read back. Every form of its lines is in logic/Item_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE = I.DARKSHORE, I.AUBERDINE
local MACKEREL, BASS = I.MACKEREL, I.BASS
local MACKEREL_ICON = 133888
local move, fish = stats.move, stats.fish

-- Pagle_Stats on a fake that has logged in, its projection built, every area named and Mackerel (with its icon) and
-- Summer Bass, fishing Darkshore (no subzone) at realm 08:15 with skill 86 + 25 = 111, below Darkshore's line of 170.
local function ready()
	local loaded, fake, book = stats.start({ items = { MACKEREL, BASS }, at = { zone = DARKSHORE, subzone = 0 } })
	loaded.client.itemIcons[MACKEREL] = MACKEREL_ICON
	return loaded, fake, book
end

-- The item page's two views, as adapter/Item.lua keeps them on each side's content.
local function facts(book)
	return book.pages["item:left"].content.facts
end
local function waters(book)
	return book.pages["item:right"].content.waters
end

describe("the item page's left page (stats.md › UI › Item page)", function()
	it("names the fish under its kicker, says when it bites, and reads my records of it", function()
		local loaded, fake, book = ready()
		fish(fake, 2, MACKEREL)
		fish(fake, 1)

		loaded.ns.OpenBook({ page = "item", item = MACKEREL })

		local view = facts(book)
		assert.are.same({ "A FISH", "Raw Mackerel" }, { view.kicker.text, view.name.title.text })
		assert.are.equal(MACKEREL_ICON, view.name.icon.icon.texture)
		assert.are.equal("Bites at any hour.", view.bites.text)
		assert.are.same(
			{ "Caught", "First caught", "Last caught" },
			{ view.facts[1].label.text, view.facts[2].label.text, view.facts[3].label.text }
		)
		assert.are.equal("2", view.facts[1].value.text)
		assert.matches("^%d+ %a+ %d+$", view.facts[2].value.text)
		assert.matches("^%d+ %a+ %d+, just now$", view.facts[3].value.text)
	end)

	it("shows Where I am on the current place's rows, and opens its entry there (STA-R74)", function()
		local loaded, fake, book = ready()
		fish(fake, 2, MACKEREL)
		fish(fake, 1)

		loaded.ns.OpenBook({ page = "item", item = MACKEREL })

		local view = facts(book)
		assert.is_true(view.here.shown)
		assert.are.same({ "WHERE I AM", "Darkshore" }, { view.here.label.text, view.here.note.text })
		-- 3 Casts in Darkshore below its line, Mackerel last caught 1 Cast ago (STA-R43, STA-R50)
		assert.are.equal("learning 3/100; 1 since the last.", view.hereText.text)
		assert.are.equal("Open its page here", view.open.label.text)
		view.open:Click()
		assert.are.same({ page = "place", area = DARKSHORE, item = MACKEREL }, book.router:Place())
	end)

	it("leaves out Where I am and the bite line where they don't apply", function()
		local loaded, _, book = ready()

		-- Summer Bass is listed only in Elwynn, where I haven't fished and am not
		loaded.ns.OpenBook({ page = "item", item = BASS })

		local view = facts(book)
		assert.is_false(view.bites.shown)
		assert.is_false(view.here.shown)
		assert.is_false(view.hereText.shown)
		assert.is_false(view.open.shown)
		assert.are.same(
			{ "0", "—", "—" },
			{ view.facts[1].value.text, view.facts[2].value.text, view.facts[3].value.text }
		)
	end)

	it("asks for an item's name, and redraws with it once it loads (STA-R73)", function()
		local loaded, _, book = ready()
		loaded.client.itemNames[MACKEREL] = nil

		loaded.ns.OpenBook({ page = "item", item = MACKEREL })
		assert.are.equal("Item 6303", facts(book).name.title.text)
		assert.are.same({ MACKEREL }, loaded.client.itemRequests)
		stats.loadItem(loaded, MACKEREL)
		loaded.client.runTimers()

		assert.are.equal("Raw Mackerel", facts(book).name.title.text)
	end)
end)

describe("the item page's right page, Where I've fished for it (stats.md › UI › Item page)", function()
	it("tiles the zone, then its waters, each opening its place page with the fish chosen", function()
		local loaded, fake, book = ready()
		fish(fake, 2, MACKEREL)
		move(fake, { subzone = AUBERDINE })
		fish(fake, 1, MACKEREL)

		loaded.ns.OpenBook({ page = "item", item = MACKEREL })

		local view = waters(book)
		assert.are.same({ "ITS WATERS", "Where I've fished for it" }, { view.kicker.text, view.title.text })
		assert.is_false(view.empty.shown)
		assert.are.same({
			"Darkshore | learning 3/100 | - | -",
			"Auberdine | Darkshore · learning 3/100 | I'm here | -",
		}, stats.tilesOf(waters(book).grid))
		view.grid.tiles[2]:Click()
		assert.are.same({ page = "place", area = AUBERDINE, item = MACKEREL }, book.router:Place())
	end)

	it('reads "I haven\'t fished anywhere it bites." with no tiles', function()
		local loaded, fake, book = ready()
		fish(fake, 1)

		loaded.ns.OpenBook({ page = "item", item = BASS })

		assert.is_true(waters(book).empty.shown)
		assert.are.equal("I haven't fished anywhere it bites.", waters(book).empty.text)
		assert.are.same({}, stats.tilesOf(waters(book).grid))
	end)
end)
