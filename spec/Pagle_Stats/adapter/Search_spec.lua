-- Search on the Stats book's leather on FakePagle (STA-R72, STA-R73, STA-R74, STA-R76): the box in the book's search
-- anchor, typed into as the player does, its dropdown read back and its results clicked. What a query finds, in every
-- form, is in logic/Search_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE = I.DARKSHORE, I.AUBERDINE
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH = I.MACKEREL, I.BLACKMOUTH, I.FIREFIN, I.NIGHTFIN, I.SMALLFISH

-- Pagle_Stats on a fake that has logged in, its projection built, with the areas and Darkshore's fish named, and 2
-- Casts in Auberdine (Darkshore): Darkshore and Auberdine are in my records, Elwynn isn't.
local function ready()
	local loaded, fake, book = stats.start({
		items = { MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH },
		at = { zone = DARKSHORE, subzone = AUBERDINE },
	})
	stats.fish(fake, 1, MACKEREL)
	stats.fish(fake, 1)
	return loaded, fake, book
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

	it(
		"is the Curio Shop's paper slip with its magnifier, centred on the strip, its gilt edge lit while typing",
		function()
			local loaded, _, book = ready()
			loaded.ns.ToggleBook()
			local view = search(book)
			local ns = loaded.ns

			-- centred between the band's inner edge (7) and the pages (38): 9.5 above and below its 26
			assert.are.same({ "TOPRIGHT", -24, -9.5 }, view.points[1])
			assert.are.equal(26, view:GetHeight())
			local slip
			for _, child in ipairs(view.children) do
				if child.left and child.left.texture == ns.ATLASES.Slip.file then
					slip = child
				end
			end
			assert.is_table(slip)
			assert.are.equal(26 / 36, slip:GetScale()) -- the slip at the strip's height, its magnifier whole
			local resting = view.edge[1].color[4]

			view.box:SetFocus()
			assert.are.same({ unpack(ns.BOOK_LOOK.giltBright) }, { unpack(view.edge[1].color, 1, 3) })
			assert.is_true(view.edge[1].color[4] > resting)
			view.box:GetScript("OnEditFocusLost")(view.box)

			assert.are.same({ unpack(ns.BOOK_LOOK.gilt) }, { unpack(view.edge[1].color, 1, 3) })
			assert.are.equal(loaded.ns.ArtFontFile("italic"), view.hint.fontObject.font[1]) -- the italic placeholder
		end
	)

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
		local loaded, _, book = ready()
		loaded.client.itemNames[SMALLFISH] = nil

		loaded.ns.ToggleBook()
		local view = search(book)
		view.box:Type("small")
		assert.are.same({ "Nothing by that name in my records." }, dropped(book))
		assert.are.same({ SMALLFISH }, loaded.client.itemRequests)

		stats.loadItem(loaded, SMALLFISH)
		loaded.client.runTimers()

		assert.are.same({ "Raw Brilliant Smallfish (fish)" }, dropped(book))
	end)

	it("is disabled while the projection is updating, and works once it is done (STA-R72)", function()
		local loaded, fake, book = stats.start({ items = {}, updating = true })

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

		-- hidden as Esc or the close button hides it; the fake's Hide runs its OnHide, as the client's does
		book.frame:Hide()
		loaded.ns.ToggleBook()

		assert.are.equal("", search(book).box:GetText())
		assert.is_false(search(book).drop.shown)
	end)
end)
