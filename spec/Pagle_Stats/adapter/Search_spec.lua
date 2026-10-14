-- Search on the Stats book's leather on FakePagle (STA-R72, STA-R73, STA-R74, STA-R76): the box in the book's search
-- anchor, typed into as the player does, its dropdown read back and its results clicked. What a query finds, in every
-- form, is in logic/Search_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, ELWYNN = 148, 442, 12
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH = 6303, 6358, 6359, 13759, 6291

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

-- Pagle_Stats on a fake that has logged in, its projection built, with Darkshore's fish named, and 2 Casts in Auberdine
-- (Darkshore): Darkshore and Auberdine are in my records, Elwynn isn't.
local function ready()
	local loaded, fake = stats.load()
	local names = loaded.client.areaNames
	names[DARKSHORE], names[AUBERDINE], names[ELWYNN] = "Darkshore", "Auberdine", "Elwynn Forest"
	local items = loaded.client.itemNames
	items[MACKEREL], items[BLACKMOUTH], items[FIREFIN] = "Raw Mackerel", "Oily Blackmouth", "Firefin Snapper"
	items[NIGHTFIN], items[SMALLFISH] = "Raw Nightfin Snapper", "Raw Brilliant Smallfish"
	fake.login()
	fake.enterWorld()
	move(fake, { zone = DARKSHORE, subzone = AUBERDINE })
	fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
	fake.playCast("gotAway")
	return loaded, fake, loaded.ns.book
end

-- The search anchor's parts, as adapter/Search.lua keeps them.
local function search(book)
	return book.frame.anchors.search
end

-- Each shown row of the dropdown as "{name} ({label})", or its name alone with no label.
local function dropped(book)
	local out = {}
	for _, row in ipairs(search(book).drop.rows) do
		if row.shown then
			out[#out + 1] = row.label.shown and (row.name.text .. " (" .. row.label.text .. ")") or row.name.text
		end
	end
	return out
end

describe("search on the leather (STA-R76)", function()
	it('is a box in the search anchor with its hint "Find a fish or a water…", and no dropdown', function()
		local loaded, _, book = ready()

		loaded.ns.ToggleBook()

		local view = search(book)
		assert.are.equal("EditBox", view.box.kind)
		assert.are.equal("Find a fish or a water…", view.hint.text)
		assert.is_true(view.hint.shown)
		assert.is_false(view.drop.shown)
		assert.is_true(view.box:IsEnabled())
	end)

	it("lists matches from the first character in a dropdown, fish then places, and hides it when emptied", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		local view = search(book)

		view.box:Type("r")

		assert.is_false(view.hint.shown)
		assert.is_true(view.drop.shown)
		assert.are.same({
			"Firefin Snapper (fish)",
			"Raw Brilliant Smallfish (fish)",
			"Raw Mackerel (fish)",
			"Raw Nightfin Snapper (fish)",
			"Auberdine (Darkshore)",
			"Darkshore (zone)",
		}, dropped(book))

		view.box:Type("")
		assert.is_false(view.drop.shown)
		assert.is_true(view.hint.shown)
	end)

	it("opens a result on click, and empties the box", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		local view = search(book)

		view.box:Type("auber")
		view.drop.rows[1]:Click()

		assert.are.same({ page = "place", area = AUBERDINE }, book.router:Place())
		assert.are.equal("", view.box:GetText())
		assert.is_false(view.drop.shown)
	end)

	it("opens the first result on Enter", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		local view = search(book)

		view.box:Type("MACK")
		view.box.scripts.OnEnterPressed(view.box)

		assert.are.same({ page = "item", item = MACKEREL }, book.router:Place())
		assert.is_false(view.drop.shown)
	end)

	it('reads "Nothing by that name in my records." with no results, and Enter opens nothing', function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		local view = search(book)

		view.box:Type("zzz")
		view.box.scripts.OnEnterPressed(view.box)

		assert.are.same({ "Nothing by that name in my records." }, dropped(book))
		assert.are.same({ page = "home" }, book.router:Place())
		view.drop.rows[1]:Click()
		assert.are.same({ page = "home" }, book.router:Place())
	end)

	it("asks for the names it lacks when the book opens, and finds an item once its name loads (STA-R73)", function()
		local loaded, fake, book = ready()
		loaded.client.itemNames[SMALLFISH] = nil

		loaded.ns.ToggleBook()
		local view = search(book)
		view.box:Type("small")
		assert.are.same({ "Nothing by that name in my records." }, dropped(book))
		assert.are.same({ SMALLFISH }, loaded.client.itemRequests)

		loaded.client.itemNames[SMALLFISH] = "Raw Brilliant Smallfish"
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", SMALLFISH, true)
		loaded.client.runTimers()

		assert.are.same({ "Raw Brilliant Smallfish (fish)" }, dropped(book))
	end)

	it("is disabled while the projection is updating, and works once it is done (STA-R72)", function()
		local loaded, fake = stats.load()
		loaded.client.areaNames[DARKSHORE] = "Darkshore"
		fake.login()
		local book = loaded.ns.book

		loaded.ns.ToggleBook()
		local view = search(book)
		assert.is_false(view.box:IsEnabled())
		assert.is_false(view.drop.shown)

		fake.enterWorld()
		loaded.client.runTimers()
		assert.is_true(view.box:IsEnabled())
	end)

	it("empties the box when the book closes", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		search(book).box:Type("raw")

		-- hidden as the client does (Esc, the close button), running its OnHide: the fake's Hide runs no script
		book.frame:Hide()
		book.frame:GetScript("OnHide")(book.frame)
		loaded.ns.ToggleBook()

		assert.are.equal("", search(book).box:GetText())
		assert.is_false(search(book).drop.shown)
	end)
end)
