-- The item page in the Stats book on FakePagle (stats.md › UI › Item page; STA-R17, STA-R43, STA-R50, STA-R73,
-- STA-R74): Casts played through Core's real Cast state machine over the fixture catalogue, the page opened through
-- ns.OpenBook, and each page's words and links read back. Every form of its lines is in logic/Item_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, ELWYNN = 148, 442, 12
local MACKEREL, BASS = 6303, 13756
local MACKEREL_ICON = 133888

-- Moves the player: `fields` replace those of the live snapshot (zone, subzone, ...).
local function move(fake, fields)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	for key, value in pairs(fields) do
		conditions[key] = value
	end
	fake.setConditions(conditions)
end

-- Pagle_Stats on a fake that has logged in, its projection built, fishing Darkshore (no subzone) at realm 08:15 with
-- skill 86 + 25 = 111, below Darkshore's line of 170; Stats' server time is where the fake's clock is.
local function ready()
	local loaded, fake = stats.load()
	local names = loaded.client.areaNames
	names[DARKSHORE], names[AUBERDINE], names[ELWYNN] = "Darkshore", "Auberdine", "Elwynn Forest"
	loaded.client.itemNames[MACKEREL] = "Raw Mackerel"
	loaded.client.itemNames[BASS] = "Large Raw Mightfish"
	loaded.client.itemIcons[MACKEREL] = MACKEREL_ICON
	fake.login()
	fake.enterWorld()
	move(fake, { zone = DARKSHORE, subzone = 0 })
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

-- The item page's two views, as adapter/Item.lua keeps them on each side's content.
local function facts(book)
	return book.pages["item:left"].content.facts
end
local function waters(book)
	return book.pages["item:right"].content.waters
end

-- Each shown tile's name, line, "I'm here" and note ("-" for one not shown).
local function tilesOf(book)
	local out = {}
	for _, tile in ipairs(waters(book).tiles) do
		if tile.shown then
			local function read(text)
				return text.shown and text.text or "-"
			end
			out[#out + 1] = table.concat({ tile.name.text, read(tile.line), read(tile.here), read(tile.note) }, " | ")
		end
	end
	return out
end

describe("the item page's left page (stats.md › UI › Item page)", function()
	it("names the fish under its kicker, says when it bites, and reads my records of it", function()
		local loaded, fake, book = ready()
		fish(fake, 2, MACKEREL)
		fish(fake, 1)

		loaded.ns.OpenBook({ page = "item", item = MACKEREL })

		local view = facts(book)
		assert.are.same({ "A FISH", "Raw Mackerel" }, { view.kicker.text, view.title.text })
		assert.are.equal(MACKEREL_ICON, view.icon.icon.texture)
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
		assert.are.same({ "0", "—", "—" }, { view.facts[1].value.text, view.facts[2].value.text, view.facts[3].value.text })
	end)

	it("asks for an item's name, and redraws with it once it loads (STA-R73)", function()
		local loaded, fake, book = ready()
		loaded.client.itemNames[MACKEREL] = nil

		loaded.ns.OpenBook({ page = "item", item = MACKEREL })
		assert.are.equal("Item 6303", facts(book).title.text)
		assert.are.same({ MACKEREL }, loaded.client.itemRequests)
		loaded.client.itemNames[MACKEREL] = "Raw Mackerel"
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", MACKEREL, true)
		loaded.client.runTimers()

		assert.are.equal("Raw Mackerel", facts(book).title.text)
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
		}, tilesOf(book))
		view.tiles[2]:Click()
		assert.are.same({ page = "place", area = AUBERDINE, item = MACKEREL }, book.router:Place())
	end)

	it("reads \"I haven't fished anywhere it bites.\" with no tiles", function()
		local loaded, fake, book = ready()
		fish(fake, 1)

		loaded.ns.OpenBook({ page = "item", item = BASS })

		assert.is_true(waters(book).empty.shown)
		assert.are.equal("I haven't fished anywhere it bites.", waters(book).empty.text)
		assert.are.same({}, tilesOf(book))
	end)
end)
