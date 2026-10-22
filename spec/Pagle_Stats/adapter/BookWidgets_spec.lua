-- The Stats book's art kit (STA-R70, stats.md › UI): its tints, fonts and in-client textures, and the widget makers
-- the shell and its pages draw with; then adapter/Text.lua's item loader, which the book, the tracker, the Curio Shop's
-- samples and the Settings row ask the client through. The fake client lays nothing out, so these check what each
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

local textsOf = stats.textsOf

describe("the Stats book's art (STA-R70, stats.md › UI)", function()
	it("draws the books kit's textures from Core's media, and in-client ones only where the kit has none", function()
		local ns, parent = kit()
		parent:SetSize(980, 640)
		ns.NewBookMark(parent, "fleuron", 16)
		ns.NewBookMark(parent, "hand", 16)
		ns.NewBookInkBar(parent, 200):SetBar(0.5)
		ns.NewBookDot(parent, 8)

		local listed = {}
		for _, path in pairs(ns.BOOK_TEXTURES) do
			assert.matches("^Interface\\", path)
			listed[path] = true
		end
		local drawn, stray = texturesOf(parent), {}
		for _, path in ipairs(drawn) do
			if not listed[path] and not path:find("^Interface\\AddOns\\Pagle\\media\\books\\") then
				stray[#stray + 1] = path
			end
		end
		assert.are.same({}, stray)
		assert.is_true(#drawn >= 4)
		assert.is_nil(ns.NewBookCorners)
	end)

	it(
		"sets its print in IM Fell English, its handwriting in Caveat and its gilt in Marcellus, Core's fonts",
		function()
			local ns = kit()
			local fonts = ns.BookFonts()
			local dir = "Interface\\AddOns\\Pagle\\media\\fonts\\"

			assert.are.equal(dir .. "IMFeENrm28P.ttf", fonts.text.font[1])
			assert.are.equal(dir .. "IMFeENrm28P.ttf", fonts.title.font[1])
			assert.are.equal(dir .. "IMFeENit28P.ttf", fonts.note.font[1])
			assert.are.equal(dir .. "Caveat-Medium.ttf", fonts.hand.font[1])
			assert.are.equal(dir .. "Caveat-Bold.ttf", fonts.big.font[1])
			assert.are.equal(dir .. "Marcellus-Regular.ttf", fonts.crumb.font[1])
		end
	)

	it(
		"draws the fleuron, the pointing hands and the star as textures, never as font glyphs, and no other mark",
		function()
			local ns, parent = kit()

			local fleuron = ns.NewBookMark(parent, "fleuron", 16)
			local right = ns.NewBookMark(parent, "hand", 16)
			local left = ns.NewBookMark(parent, "handLeft", 16)
			local star = ns.NewBookMark(parent, "star", 12) -- a watched row's ★ (adapter/Place.lua)

			assert.are.equal("Texture", fleuron.kind)
			assert.are.equal(ns.ATLASES.Book.file, fleuron.texture) -- the kit's gilt fleuron
			assert.are.same({ ns.BOOK_TEXTURES.hand, ns.BOOK_TEXTURES.hand }, { right.texture, left.texture })
			assert.are_not.same(right.texCoord, left.texCoord) -- ☛ is ☚ mirrored
			assert.are.equal(ns.ATLASES.Parts.file, star.texture) -- the kit's red star
			assert.are.same({ 12 * 30 / 2 / 15, 12 * 30 / 2 / 15 }, { star.width, star.height })
			assert.error_matches(function()
				ns.NewBookMark(parent, "asterisk", 12)
			end, "the Stats book has no mark asterisk", nil, true)
		end
	)

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

	it("fills an ink bar with the kit's full stroke from the left, cut to its share, clamped", function()
		local ns, parent = kit()

		local bar = ns.NewBookInkBar(parent, 240)
		bar:SetBar(0.25)
		assert.are.same({ 60, true }, { bar.fill.width, bar.fill.shown })
		assert.are.equal(ns.ATLASES.Parts.file, bar.fill.texture)
		assert.are.equal(240, bar.empty.width)
		bar:SetBar(1.4) -- past the stroke's own 200 units: sliced, not cut
		assert.are.same({ false, true, 240 }, { bar.fill.shown, bar.fillSlice.shown, bar.fillSlice.width })
		bar:SetBar(0)

		assert.are.same({ false, false }, { bar.fill.shown, bar.fillSlice.shown })
	end)

	it(
		"rules a ledger: small-caps column heads, a line per row, a row opening what it names, the chosen one shaded",
		function()
			local ns, parent = kit()
			local opened = {}

			local ledger = ns.NewBookLedger(parent, 400, {
				{ label = "Started", width = 140 },
				{ label = "Where", width = 140 },
				{ label = "Casts", width = 60, align = "RIGHT" },
			})
			local height = ledger:SetRows({
				{
					cells = { "5 Oct 2026 18:02", "Darkshore", "51" },
					onClick = function()
						opened[#opened + 1] = "first"
					end,
				},
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

			-- the kit v2's rules: faint blue under each row, faint red between the columns down the whole ledger
			local look = ns.BOOK_LOOK
			assert.are.same(
				{ look.ledgerBlue[1], look.ledgerBlue[2], look.ledgerBlue[3], look.ledgerBlueAlpha },
				ledger.rows[1].rule.color
			)
			assert.are.equal(#ledger.heads - 1, #ledger.columnRules)
			assert.are.equal(height, ledger.columnRules[1].height)

			ledger:SetRows({ { cells = { "5 Oct 2026 18:02", "Darkshore", "51" } } })
			assert.is_false(ledger.rows[2].shown)
		end
	)

	it('draws a tile with its name, its line, "I\'m here" and a red note, opening what it names', function()
		local ns, parent = kit()
		local clicks = 0

		local tile = ns.NewBookTile(parent, 200, 66)
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
		-- the kit v2's green-edged tile for the place I'm in, from Stats' own atlas
		local atlas, here = ns.ATLASES.Stats, ns.ATLASES.Stats.sprites["tile-here"]
		assert.are.equal(atlas.file, tile.paper.texture)
		assert.are.equal(here.y / atlas.height, tile.paper.texCoord[3])
		tile:SetTile({ name = "Elwynn Forest", line = "not fished yet" })

		assert.are.same({ "Elwynn Forest", "not fished yet" }, textsOf(tile))
		assert.are.equal(ns.ATLASES.Stats.sprites.tile.y / atlas.height, tile.paper.texCoord[3])
		assert.are.equal(1, clicks)
	end)

	it("warms a tile slightly under the mouse, as the kit's home tiles", function()
		local ns, parent = kit()
		local tile = ns.NewBookTile(parent, 200, 66)
		tile:SetTile({ name = "Darkshore" })

		tile:GetScript("OnEnter")(tile)
		assert.are.same(ns.BOOK_LOOK.tileWarm, { unpack(tile.paper.vertexColor, 1, 3) })
		tile:GetScript("OnLeave")(tile)

		assert.are.same({ 1, 1, 1 }, { unpack(tile.paper.vertexColor, 1, 3) })
	end)

	it("keeps a tile's words on the tile: a long name stops before \"I'm here\"", function()
		local ns, parent = kit()
		local tile = ns.NewBookTile(parent, 200, 66)

		tile:SetTile({ name = "The Very Long Name of Some Distant Water", here = "I'm here" })

		-- 6 px a character in the fake; 11 in from each edge
		assert.are.equal(200 - 22 - (#"I'm here" * 6 + 1) - 6, tile.name.width)
	end)

	it("sets a learning row's odds at its right edge, and stops a long name before them", function()
		local ns, parent = kit()
		local row = ns.NewBookRow(parent, 416)
		local name = "Raw Spotted Yellowtail of the Very Long Uncharted Name"
		local data = { icon = 133890, name = name, ink = ns.BOOK_LOOK.ink, watched = false, chosen = false }
		data.odds, data.oddsState = "learning 27/100", "learning"

		row:SetRow(data)

		-- at the row's right edge, past the odds' column; the name ends 8 before them (6 px a character in the fake)
		assert.are.same({ "TOPRIGHT", -12, -3 }, row.odds.points[1])
		local oddsLeft = 416 - 12 - #"learning 27/100" * 6
		assert.are.equal(oddsLeft - 8 - 32, row.name.width)
		assert.is_true(row.name.width < #name * 6) -- cut short, the client's ellipsis at its end

		data.watched = true -- the star takes its room from the name
		row:SetRow(data)
		assert.are.equal(oddsLeft - 8 - 32 - 12 - 5, row.name.width)

		data.odds, data.oddsState, data.watched = "1 in 30", "known", false
		row:SetRow(data) -- a known reading keeps its column, and a short name its own width
		assert.are.same({ "TOPRIGHT", -140, -5 }, row.odds.points[1])
		data.name = "Smallfish"
		row:SetRow(data)
		assert.are.equal(#"Smallfish" * 6 + 1, row.name.width)
	end)

	it(
		"draws a figure line with a leader to its value, reddening under the mouse only when it opens something",
		function()
			local ns, parent = kit()
			local look, clicks = ns.BOOK_LOOK, 0

			local figure = ns.NewBookFigure(parent, 300, 20)
			figure:SetFigure({ label = "Casts", value = "9", valueInk = look.title })
			figure:GetScript("OnEnter")(figure)
			assert.are.same({ "Casts", "9" }, textsOf(figure))
			assert.is_true(figure.leader.shown)
			assert.are.same(look.ink, { unpack(figure.label.textColor, 1, 3) })
			assert.are.same(look.title, { unpack(figure.value.textColor, 1, 3) })
			figure:SetFigure({
				label = "Darkshore",
				onClick = function()
					clicks = clicks + 1
				end,
			})
			figure:GetScript("OnEnter")(figure)
			assert.are.same(look.red, { unpack(figure.label.textColor, 1, 3) })
			figure:GetScript("OnLeave")(figure)
			figure:Click()

			assert.are.same({ "Darkshore" }, textsOf(figure))
			assert.is_false(figure.leader.shown)
			assert.are.same(look.ink, { unpack(figure.label.textColor, 1, 3) })
			assert.are.equal(1, clicks)
		end
	)

	it("lays tiles two a row, each opening its target, hiding the ones left over", function()
		local ns, parent, loaded = kit()
		parent:SetWidth(409)
		local opened = {}
		loaded.ns.OpenBook = function(target)
			opened[#opened + 1] = target.area
		end
		local function tiles(n)
			local out = {}
			for i = 1, n do
				out[i] = { name = "Zone " .. i, target = { page = "place", area = i } }
			end
			return out
		end

		local grid = ns.NewBookTileGrid(parent)
		-- the kit v2's tiles: 66 high, 8 apart
		assert.are.equal(66 * 2 + 8, grid:SetTiles(tiles(3), 10))
		assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 200.5 + 8, -10 }, grid.tiles[2].points[1])
		assert.are.same({ "TOPLEFT", parent, "TOPLEFT", 0, -(10 + 66 + 8) }, grid.tiles[3].points[1])
		grid.tiles[3]:Click()
		assert.are.equal(0, grid:SetTiles({}, 10))

		assert.are.same({ 3 }, opened)
		assert.are.same({ false, false, false }, { grid.tiles[1].shown, grid.tiles[2].shown, grid.tiles[3].shown })
	end)

	it('reads "No Sessions yet." in handwriting across its page (STA-R97)', function()
		local ns, parent = kit()
		parent:SetWidth(320)

		local empty = ns.NewBookNoSessions(parent)

		assert.are.equal("No Sessions yet.", empty.text)
		assert.are.equal(320, empty.width)
		assert.are.same(ns.BOOK_LOOK.hand, { unpack(empty.textColor, 1, 3) })
	end)
end)

describe("the item loader every Stats view asks the client through (STA-R59, STA-R73)", function()
	it("asks once while an item is on its way, and runs its redraw when it loads", function()
		local loaded, fake = stats.load()
		local redrawn = {}
		local request = loaded.ns.NewItemLoader("spec", function(itemID)
			redrawn[#redrawn + 1] = itemID
		end)

		request(13759)
		request(13759)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", 6358, true)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", 13759, true)

		assert.are.same({ 13759 }, loaded.client.itemRequests)
		assert.are.same({ 13759 }, redrawn)
	end)

	it("runs nothing when a load fails, and asks again at the next request", function()
		local loaded, fake = stats.load()
		local redrawn = 0
		local request = loaded.ns.NewItemLoader("spec", function()
			redrawn = redrawn + 1
		end)

		request(13759)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", 13759, false)
		request(13759)

		assert.are.equal(0, redrawn)
		assert.are.same({ 13759, 13759 }, loaded.client.itemRequests)
	end)
end)
