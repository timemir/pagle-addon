-- The Stats book's art kit (STA-R70, stats.md › UI): its tints, fonts and in-client textures, and the widget makers
-- the shell and the page tickets (#212–#217) draw with. The fake client lays nothing out, so these check what each
-- maker puts on screen: its texts, textures, tints and clicks.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

-- Stats' namespace and a parent frame to draw on.
local function kit()
	local loaded = stats.load()
	local parent = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
	return loaded.ns, parent, loaded
end

-- The textures of every widget under `widget` that show one, depth first.
local function texturesOf(widget, found)
	found = found or {}
	for _, child in ipairs(widget.children) do
		if child.texture ~= nil then
			found[#found + 1] = child.texture
		end
		texturesOf(child, found)
	end
	return found
end

-- The texts of every shown widget under `widget`, depth first.
local function textsOf(widget, texts)
	texts = texts or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text ~= nil and child.text ~= "" then
				texts[#texts + 1] = child.text
			end
			textsOf(child, texts)
		end
	end
	return texts
end

describe("the Stats book's art (STA-R70, graph.md open question 4)", function()
	it("uses in-client textures only, each listed in ns.BOOK_TEXTURES for the dev to judge", function()
		local ns, parent = kit()
		ns.NewBookLeather(parent)
		ns.NewBookParchment(parent, "RIGHT")
		ns.NewBookMark(parent, "fleuron", 12)
		ns.NewBookMark(parent, "hand", 16)
		ns.NewBookInkBar(parent, 200, 10):SetBar(0.5)
		ns.NewBookDot(parent, 8)

		local listed = {}
		for _, path in pairs(ns.BOOK_TEXTURES) do
			assert.matches("^Interface\\", path)
			listed[path] = true
		end
		for _, path in ipairs(texturesOf(parent)) do
			assert.is_true(listed[path], path .. " is not in ns.BOOK_TEXTURES")
		end
	end)

	it("sets its text in the client's serif face and its handwriting in another, both listed", function()
		local ns = kit()
		local fonts = ns.BookFonts()

		assert.are.equal(ns.BOOK_FONT_FILES.serif, fonts.text.font[1])
		assert.are.equal(ns.BOOK_FONT_FILES.hand, fonts.hand.font[1])
		assert.are.equal(ns.BOOK_FONT_FILES.hand, fonts.title.font[1])
		assert.are_not.equal(ns.BOOK_FONT_FILES.serif, ns.BOOK_FONT_FILES.hand)
		assert.matches("^Fonts\\", ns.BOOK_FONT_FILES.serif)
	end)

	it("draws the fleuron and the pointing hands as textures, never as font glyphs, and no other mark", function()
		local ns, parent = kit()

		local fleuron = ns.NewBookMark(parent, "fleuron", 12)
		local right = ns.NewBookMark(parent, "hand", 16)
		local left = ns.NewBookMark(parent, "handLeft", 16)

		assert.are.equal("Texture", fleuron.kind)
		assert.are.equal(ns.BOOK_TEXTURES.fleuron, fleuron.texture)
		assert.are.same({ ns.BOOK_TEXTURES.hand, ns.BOOK_TEXTURES.hand }, { right.texture, left.texture })
		assert.are_not.same(right.texCoord, left.texCoord) -- ☛ is ☚ mirrored
		assert.has_error(function()
			ns.NewBookMark(parent, "star", 12)
		end)
	end)

	it("writes kickers in small caps, titles and handwriting in their own faces and inks", function()
		local ns, parent = kit()
		local fonts, look = ns.BookFonts(), ns.BOOK_LOOK

		local kicker = ns.NewBookKicker(parent)
		kicker:SetText("The waters")
		local title = ns.NewBookTitle(parent)
		title:SetText("Where I've fished")
		local hand = ns.NewBookHand(parent)
		hand:SetText("Pick a fish on the left for its odds and its Dry spell.")

		assert.are.equal("THE WATERS", kicker.text)
		assert.are.same({ fonts.kicker, look.kicker }, { kicker.fontObject, { unpack(kicker.textColor, 1, 3) } })
		assert.are.same({ fonts.title, look.title }, { title.fontObject, { unpack(title.textColor, 1, 3) } })
		assert.are.same({ fonts.hand, look.hand }, { hand.fontObject, { unpack(hand.textColor, 1, 3) } })
	end)

	it("heads a group with its words in small caps and its small note, over a rule", function()
		local ns, parent = kit()

		local heading = ns.NewBookHeading(parent, 400)
		heading:SetHeading("Dry spell", "counted like the odds above")
		assert.are.same({ "DRY SPELL", "counted like the odds above" }, textsOf(heading))
		heading:SetHeading("In my records")

		assert.are.same({ "IN MY RECORDS" }, textsOf(heading))
		assert.is_table(heading.rule.color)
	end)

	it('makes a link with the pointing hand after its words, as "Every water it bites in ☛"', function()
		local ns, parent = kit()
		local clicks = 0

		local link = ns.NewBookLink(parent)
		link:SetLink("Every water it bites in", function()
			clicks = clicks + 1
		end)
		link:Click()

		assert.are.equal("Every water it bites in", link.label.text)
		assert.are.equal(ns.BOOK_TEXTURES.hand, link.mark.texture)
		assert.are.equal(1, clicks)
	end)

	it("inks an item icon in sepia, and the question mark too", function()
		local ns, parent = kit()

		local icon = ns.NewBookIcon(parent, 20)
		icon:SetIcon(133890)

		assert.are.equal(133890, icon.icon.texture)
		assert.is_true(icon.icon.desaturated)
		assert.are.same(ns.BOOK_LOOK.sepia, { unpack(icon.icon.vertexColor, 1, 3) })
	end)

	it("fills an ink bar with hatching from the left, to its share, clamped", function()
		local ns, parent = kit()

		local bar = ns.NewBookInkBar(parent, 202, 10)
		bar:SetBar(0.25)
		assert.are.same({ 50, true }, { bar.fill.width, bar.fill.shown })
		assert.are.equal(ns.BOOK_TEXTURES.hatch, bar.hatch.texture)
		bar:SetBar(1.4)
		assert.are.equal(200, bar.fill.width)
		bar:SetBar(0)

		assert.is_false(bar.fill.shown)
	end)

	it("rules a ledger: small-caps column heads, a line per row, a row opening what it names, the chosen one shaded", function()
		local ns, parent = kit()
		local opened = {}

		local ledger = ns.NewBookLedger(parent, 400, {
			{ label = "Started", width = 140 },
			{ label = "Where", width = 140 },
			{ label = "Casts", width = 60, align = "RIGHT" },
		})
		local height = ledger:SetRows({
			{ cells = { "5 Oct 2026 18:02", "Darkshore", "51" }, onClick = function()
				opened[#opened + 1] = "first"
			end },
			{ cells = { "4 Oct 2026 21:40", "Elwynn Forest", "1,204" } },
		}, 2)

		assert.are.same({
			"STARTED",
			"WHERE",
			"CASTS",
			"5 Oct 2026 18:02",
			"Darkshore",
			"51",
			"4 Oct 2026 21:40",
			"Elwynn Forest",
			"1,204",
		}, textsOf(ledger))
		ledger.rows[1]:Click()
		ledger.rows[2]:Click()
		assert.are.same({ "first" }, opened)
		assert.is_false(ledger.rows[1].shade.shown)
		assert.is_true(ledger.rows[2].shade.shown)
		assert.is_true(height > 0)

		ledger:SetRows({ { cells = { "5 Oct 2026 18:02", "Darkshore", "51" } } })
		assert.is_false(ledger.rows[2].shown)
	end)

	it('draws a tile with its name, its line, "I\'m here" and a red note, opening what it names', function()
		local ns, parent = kit()
		local clicks = 0

		local tile = ns.NewBookTile(parent, 200, 84)
		tile:SetTile({
			name = "Darkshore",
			line = "1,840 Casts · 3 waters",
			here = "I'm here",
			note = "watching 2",
			onClick = function()
				clicks = clicks + 1
			end,
		})
		tile:Click()
		assert.are.same({ "Darkshore", "1,840 Casts · 3 waters", "I'm here", "watching 2" }, textsOf(tile))
		tile:SetTile({ name = "Elwynn Forest", line = "not fished yet" })

		assert.are.same({ "Elwynn Forest", "not fished yet" }, textsOf(tile))
		assert.are.equal(1, clicks)
	end)

	it("hangs a ribbon in its letters, green or red, standing out when chosen", function()
		local ns, parent = kit()

		local ribbon = ns.NewBookRibbon(parent)
		ribbon:SetRibbon("Lifetime", false, false)
		assert.are.equal("L\ni\nf\ne\nt\ni\nm\ne", ribbon.label.text)
		assert.are.same(ns.BOOK_LOOK.ribbon, { unpack(ribbon.face.color, 1, 3) })
		ribbon:SetRibbon("Where I am", true, true)

		assert.are.same(ns.BOOK_LOOK.ribbonHereChosen, { unpack(ribbon.face.color, 1, 3) })
		assert.is_true(ribbon.chosen)
	end)

	it("sizes the gold nameplate to its words", function()
		local ns, parent = kit()

		local plate = ns.NewBookPlate(parent)
		plate:SetPlate("No Casts yet")

		assert.are.equal("No Casts yet", plate.label.text)
		assert.are.equal(#"No Casts yet" * 6 + 20, plate.width)
	end)
end)
