if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's art kit (STA-R70, stats.md › UI): the book language's tints, fonts and in-client textures, and a
-- widget maker for each piece the book and its pages draw: the leather, parchment, ribbons and the nameplate for the
-- shell (adapter/Book.lua); a kicker, a title, a handwriting line, a heading with its small note, a "☛" link, sepia
-- ink icons, an ink bar, a ruled ledger and a tile for the pages (#212–#217); and the fleuron and pointing hands,
-- drawn as textures, never as font glyphs. The look follows prototypes/stats-window/ variant D. Stats shares no code
-- with the Ledger's Fish Journal (ADR 0001), though some textures and fonts are the same client files. Every texture
-- sits on a solid tint or carries a vertex tint, so a texture the client lacks leaves the tint showing.
--
-- The page tickets add their own makers here (the luck ruler, #214).

-- A tint from its hex code, as the prototype's CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
local function tint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

--- The book's tints, from variant D's CSS (`.vD`). Where the prototype shades a gradient, the tint lies between its
--- ends.
ns.BOOK_LOOK = {
	leather = tint("4e2c16"), -- between the binding's #6a3e20 and #3a2010
	leatherEdge = tint("120a04"), -- the outline
	leatherRule = tint("8a5a2a"), -- the gilt rule inside the edge
	gilt = tint("e8c96a"), -- the breadcrumbs and the live line
	giltBright = tint("fff4c8"), -- a crumb under the mouse
	fleuron = tint("a8803a"), -- the fleuron between crumbs
	paper = tint("ead6ac"), -- between the page's #f3e5c3 and #dfc89a
	spine = tint("46280a"), -- rgba(70,40,10,.65): the shadow at the spine
	ink = tint("3a2614"), -- printed text
	title = tint("3e220c"), -- titles, large ink, tile names
	kicker = tint("8a5a2a"), -- small-caps kickers and headings
	small = tint("5a4028"), -- small print
	note = tint("8a6a40"), -- italic notes
	faded = tint("9a8060"), -- a heading's small note
	hand = tint("23407a"), -- handwriting
	red = tint("9a2a1a"), -- unlucky, the "me" mark, the pointing hand
	green = tint("2a6a2a"), -- "I'm here"
	headingRule = tint("c4a874"), -- the rule under a heading
	ledgerRule = tint("6a4a20"), -- the ruled ledger's head rule, a tile's outline
	rowRule = tint("8a5a2a"), -- rgba(138,90,42,.3): a ledger row's rule
	rowRuleAlpha = 0.3,
	shade = tint("784614"), -- rgba(120,70,20,.14): the chosen row, a tile under the mouse
	shadeAlpha = 0.14,
	tileWash = tint("fffaeb"), -- rgba(255,250,235,.22): a tile's face
	tileWashAlpha = 0.22,
	barInk = tint("5a3a14"), -- an ink bar's outline and hatching
	barFill = tint("7a5224"), -- between the hatching's lines
	sepia = tint("dcb37a"), -- an item icon's tint over its greys (CSS sepia(.75))
	ribbon = tint("82221a"), -- between #6a1810 and #9a2a1c
	ribbonChosen = tint("b5351f"), -- between #9a2a1c and #d0402a
	ribbonHere = tint("264a21"), -- Where I am: between #1e3a1a and #2e5a28
	ribbonHereChosen = tint("366a2e"), -- between #2e5a28 and #3e7a34
	ribbonText = tint("f4dfa8"),
	plate = tint("c19e45"), -- the gold nameplate: between its #e8c96a and #9a7420
	plateEdge = tint("4a3008"),
	plateText = tint("2a1a04"),
	searchPaper = tint("efe0bb"), -- the search box (#215)
}
local LOOK = ns.BOOK_LOOK

--- In-client textures, every one the book draws. Each is a file the forever client's FrameXML names (Gethe/wow-ui-source
--- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57).
ns.BOOK_TEXTURES = {
	-- The leather's grain (FrameGeneral's rock backdrop) and the page paper (the achievement parchment).
	leather = "Interface\\FrameGeneral\\UI-Background-Rock",
	paper = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
	-- A white disc (CharacterFrame's portrait mask): the live line's dot.
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- Diagonal stripes that tile (the absorb shield's overlay, Blizzard_UnitFrame/Shared/UnitFrame.xml): an ink bar's
	-- hatching.
	hatch = "Interface\\RaidFrame\\Shield-Overlay",
	-- The fleuron between crumbs (the quest log's bullet) and the pointing hand (the gauntlet cursor).
	fleuron = "Interface\\QuestFrame\\UI-Quest-BulletPoint",
	hand = "Interface\\Cursor\\Point",
}
local TEXTURES = ns.BOOK_TEXTURES

--- The fonts: the serif text face and the handwriting face, in-client files.
ns.BOOK_FONT_FILES = {
	serif = "Fonts\\FRIZQT__.TTF",
	hand = "Fonts\\MORPHEUS.TTF",
}

-- The hatching's tile, in pixels: one repeat of its stripes.
local HATCH_TILE = 16

--- The book's font objects, made on first use.
---@class StatsBookFonts
---@field text Font     -- printed text (serif, 14 as variant D)
---@field small Font    -- small print and ledger cells
---@field note Font     -- notes, a heading's small note, tile lines
---@field kicker Font   -- small-caps kickers and headings (ns.BookSmallCaps)
---@field title Font    -- page titles (handwriting face, large)
---@field big Font      -- large ink: "about 1 in 40" (serif, large)
---@field hand Font     -- handwriting
---@field crumb Font    -- the leather's breadcrumbs and the live line
---@field ribbon Font   -- a ribbon's letters
---@field plate Font    -- the nameplate
local fonts

---@return StatsBookFonts
function ns.BookFonts()
	if not fonts then
		local function font(name, file, size)
			local object = CreateFont("PagleStatsBook" .. name)
			object:SetFont(file, size, "")
			return object
		end
		local serif, hand = ns.BOOK_FONT_FILES.serif, ns.BOOK_FONT_FILES.hand
		fonts = {
			text = font("Text", serif, 13),
			small = font("Small", serif, 12),
			note = font("Note", serif, 11),
			kicker = font("Kicker", serif, 11),
			title = font("Title", hand, 24),
			big = font("Big", serif, 28),
			hand = font("Hand", hand, 16),
			crumb = font("Crumb", serif, 13),
			ribbon = font("Ribbon", serif, 11),
			plate = font("Plate", serif, 12),
		}
	end
	return fonts
end

--- A heading in small caps: the client's fonts have none, so it is set in capitals in the small kicker face.
---@param text string
---@return string
function ns.BookSmallCaps(text)
	return text:upper()
end

--- A solid tint filling `frame`, or the part its points give.
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@param alpha number?
---@return Texture
function ns.BookSolid(frame, color, layer, alpha)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	texture:SetAllPoints()
	return texture
end

--- A font string on `frame` in one of the book's fonts and tints, left-justified.
---@param frame Frame
---@param font Font
---@param color number[]
---@return FontString
function ns.BookText(frame, font, color)
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(font)
	text:SetTextColor(color[1], color[2], color[3])
	text:SetJustifyH("LEFT")
	return text
end

--- A kicker: the small-caps line above a page's title ("THE WATERS"). Its SetText sets the words in small caps.
---@param parent Frame
---@return FontString
function ns.NewBookKicker(parent)
	local kicker = ns.BookText(parent, ns.BookFonts().kicker, LOOK.kicker)
	local setText = kicker.SetText
	kicker.SetText = function(self, text)
		setText(self, text and ns.BookSmallCaps(text))
	end
	return kicker
end

--- A page's title, in the handwriting face's large size and the title ink.
---@param parent Frame
---@return FontString
function ns.NewBookTitle(parent)
	return ns.BookText(parent, ns.BookFonts().title, LOOK.title)
end

--- A line of handwriting: first-person notes (STA-R59), in the hand's blue ink, wrapping at its width.
---@param parent Frame
---@return FontString
function ns.NewBookHand(parent)
	local hand = ns.BookText(parent, ns.BookFonts().hand, LOOK.hand)
	hand:SetWordWrap(true)
	return hand
end

--- A heading over a group (*Dry spell*, *In my records*): its words in small caps at the left, its small note in
--- italic at the right, and a rule under both. 20 px high.
---@class StatsBookHeadingView: Frame
---@field label FontString
---@field note FontString
---@field rule Texture
---@field SetHeading fun(self: StatsBookHeadingView, text: string, note: string?)

---@param parent Frame
---@param width number
---@return StatsBookHeadingView
function ns.NewBookHeading(parent, width)
	local heading = CreateFrame("Frame", nil, parent) --[[@as StatsBookHeadingView]]
	heading:SetSize(width, 20)
	heading.label = ns.BookText(heading, ns.BookFonts().kicker, LOOK.kicker)
	heading.label:SetPoint("BOTTOMLEFT", 0, 3)
	heading.note = ns.BookText(heading, ns.BookFonts().note, LOOK.faded)
	heading.note:SetPoint("BOTTOMRIGHT", 0, 3)
	heading.note:SetJustifyH("RIGHT")
	heading.rule = heading:CreateTexture(nil, "ARTWORK")
	heading.rule:SetColorTexture(LOOK.headingRule[1], LOOK.headingRule[2], LOOK.headingRule[3], 1)
	heading.rule:SetPoint("BOTTOMLEFT")
	heading.rule:SetPoint("BOTTOMRIGHT")
	heading.rule:SetHeight(1)
	function heading.SetHeading(self, text, note)
		self.label:SetText(ns.BookSmallCaps(text))
		self.note:SetText(note or "")
		self.note:SetShown(note ~= nil)
	end
	return heading
end

--- A mark drawn as a texture (STA-R70's art, never a font glyph): the fleuron between crumbs in the fleuron's gilt,
--- the pointing hand "☛" after a link, or "☚" before one, in red ink. The gauntlet cursor points up and to the left:
--- mirrored and turned it points right, turned the other way it points left.
---@alias StatsBookMark "fleuron"|"hand"|"handLeft"

---@type table<StatsBookMark, { texture: string, color: number[], mirror: boolean, turn: number }>
local MARKS = {
	fleuron = { texture = TEXTURES.fleuron, color = LOOK.fleuron, mirror = false, turn = 0 },
	hand = { texture = TEXTURES.hand, color = LOOK.red, mirror = true, turn = -math.pi / 4 },
	handLeft = { texture = TEXTURES.hand, color = LOOK.red, mirror = false, turn = math.pi / 4 },
}

---@param parent Frame
---@param mark StatsBookMark
---@param size number
---@return Texture
function ns.NewBookMark(parent, mark, size)
	local look = assert(MARKS[mark], "the Stats book has no mark " .. tostring(mark))
	local texture = parent:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(look.texture)
	texture:SetSize(size, size)
	texture:SetDesaturated(true)
	texture:SetVertexColor(look.color[1], look.color[2], look.color[3])
	if look.mirror then
		texture:SetTexCoord(1, 0, 0, 1)
	else
		texture:SetTexCoord(0, 1, 0, 1)
	end
	if look.turn ~= 0 then
		texture:SetRotation(look.turn)
	end
	return texture
end

--- A link on a page: its words in the hand's ink with the pointing hand after them ("Every water it bites in ☛"),
--- clicking it doing what it names.
---@class StatsBookLinkView: Button
---@field label FontString
---@field mark Texture
---@field SetLink fun(self: StatsBookLinkView, text: string, onClick: fun())

---@param parent Frame
---@return StatsBookLinkView
function ns.NewBookLink(parent)
	local link = CreateFrame("Button", nil, parent) --[[@as StatsBookLinkView]]
	link.label = ns.BookText(link, ns.BookFonts().hand, LOOK.hand)
	link.label:SetPoint("LEFT")
	link.mark = ns.NewBookMark(link, "hand", 16)
	link.mark:SetPoint("LEFT", link.label, "RIGHT", 4, 0)
	function link.SetLink(self, text, onClick)
		self.label:SetText(text)
		self:SetSize(self.label:GetStringWidth() + 22, 20)
		self:SetScript("OnClick", function()
			onClick()
		end)
	end
	return link
end

--- An ink icon: an item's icon (or the question mark, STA-R59) in sepia, within a thin ink frame.
---@class StatsBookIconView: Frame
---@field icon Texture
---@field SetIcon fun(self: StatsBookIconView, texture: string|integer)

---@param parent Frame
---@param size number
---@return StatsBookIconView
function ns.NewBookIcon(parent, size)
	local view = CreateFrame("Frame", nil, parent) --[[@as StatsBookIconView]]
	view:SetSize(size, size)
	ns.BookSolid(view, LOOK.barInk, "BACKGROUND")
	view.icon = view:CreateTexture(nil, "ARTWORK")
	view.icon:SetPoint("TOPLEFT", 1, -1)
	view.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	function view.SetIcon(self, texture)
		self.icon:SetTexture(texture)
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(LOOK.sepia[1], LOOK.sepia[2], LOOK.sepia[3])
	end
	return view
end

--- An ink bar (stats.md › UI: "Learning…"): an ink outline filled from the left with hatched ink to its share.
---@class StatsBookInkBarView: Frame
---@field edges Texture[]
---@field fill Texture
---@field hatch Texture
---@field value number
---@field SetBar fun(self: StatsBookInkBarView, fill: number)

---@param parent Frame
---@param width number
---@param height number
---@return StatsBookInkBarView
function ns.NewBookInkBar(parent, width, height)
	local bar = CreateFrame("Frame", nil, parent) --[[@as StatsBookInkBarView]]
	bar:SetSize(width, height)
	bar.edges = {}
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" },
		{ "TOPRIGHT", "BOTTOMRIGHT" },
	}) do
		local edge = bar:CreateTexture(nil, "BORDER")
		edge:SetColorTexture(LOOK.barInk[1], LOOK.barInk[2], LOOK.barInk[3], 1)
		edge:SetPoint(points[1])
		edge:SetPoint(points[2])
		if i <= 2 then
			edge:SetHeight(1)
		else
			edge:SetWidth(1)
		end
		bar.edges[i] = edge
	end
	bar.fill = bar:CreateTexture(nil, "ARTWORK")
	bar.fill:SetColorTexture(LOOK.barFill[1], LOOK.barFill[2], LOOK.barFill[3], 1)
	bar.fill:SetPoint("TOPLEFT", 1, -1)
	bar.fill:SetHeight(height - 2)
	bar.hatch = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	bar.hatch:SetTexture(TEXTURES.hatch, "REPEAT", "REPEAT")
	bar.hatch:SetVertexColor(LOOK.barInk[1], LOOK.barInk[2], LOOK.barInk[3])
	bar.hatch:SetAllPoints(bar.fill)
	bar.value = 0
	function bar.SetBar(self, fill)
		fill = math.max(0, math.min(1, fill))
		local inner = math.max(1, (width - 2) * fill)
		self.fill:SetWidth(inner)
		self.hatch:SetTexCoord(0, inner / HATCH_TILE, 0, (height - 2) / HATCH_TILE)
		self.fill:SetShown(fill > 0)
		self.hatch:SetShown(fill > 0)
		self.value = fill
	end
	return bar
end

--- A small disc in a tint: the live line's "●".
---@param parent Frame
---@param size number
---@return Texture
function ns.NewBookDot(parent, size)
	local dot = parent:CreateTexture(nil, "ARTWORK")
	dot:SetTexture(TEXTURES.disc)
	dot:SetSize(size, size)
	dot:SetVertexColor(LOOK.gilt[1], LOOK.gilt[2], LOOK.gilt[3])
	return dot
end

--- A ruled ledger (stats.md › UI: This Session, Sessions): column heads in small caps over a heavy rule, then one row
--- per line with a faint rule under it. A row with `onClick` opens what it names; the chosen row is shaded.
---@class StatsBookLedgerColumn
---@field label string
---@field width number
---@field align ("LEFT"|"RIGHT")?

---@class StatsBookLedgerRow
---@field cells string[]
---@field onClick fun()?

---@class StatsBookLedgerRowView: Button
---@field cells FontString[]
---@field shade Texture
---@field rule Texture

---@class StatsBookLedgerView: Frame
---@field heads FontString[]
---@field rows StatsBookLedgerRowView[]
---@field SetRows fun(self: StatsBookLedgerView, rows: StatsBookLedgerRow[], chosen: integer?): number

-- A ledger's head and row heights.
local LEDGER_HEAD, LEDGER_ROW = 20, 20

---@param parent Frame
---@param width number
---@param columns StatsBookLedgerColumn[]
---@return StatsBookLedgerView
function ns.NewBookLedger(parent, width, columns)
	local ledger = CreateFrame("Frame", nil, parent) --[[@as StatsBookLedgerView]]
	ledger:SetWidth(width)
	ledger.heads, ledger.rows = {}, {}
	-- Lays `cells` (font strings) along a line, one per column.
	local function lay(line, cells)
		local x = 0
		for i, column in ipairs(columns) do
			local cell = cells[i]
			cell:ClearAllPoints()
			cell:SetPoint("LEFT", line, "LEFT", x + 4, 0)
			cell:SetWidth(column.width - 8)
			cell:SetJustifyH(column.align or "LEFT")
			cell:SetWordWrap(false) -- a long cell ("Where") is cut short, never wrapped over the next row
			x = x + column.width
		end
	end
	local head = CreateFrame("Frame", nil, ledger)
	head:SetPoint("TOPLEFT")
	head:SetSize(width, LEDGER_HEAD)
	for i, column in ipairs(columns) do
		local text = ns.BookText(head, ns.BookFonts().kicker, LOOK.kicker)
		text:SetText(ns.BookSmallCaps(column.label))
		ledger.heads[i] = text
	end
	lay(head, ledger.heads)
	local headRule = head:CreateTexture(nil, "ARTWORK")
	headRule:SetColorTexture(LOOK.ledgerRule[1], LOOK.ledgerRule[2], LOOK.ledgerRule[3], 1)
	headRule:SetPoint("BOTTOMLEFT")
	headRule:SetPoint("BOTTOMRIGHT")
	headRule:SetHeight(2)

	-- Row `i`, made on first use.
	local function rowAt(i)
		local row = ledger.rows[i]
		if not row then
			row = CreateFrame("Button", nil, ledger) --[[@as StatsBookLedgerRowView]]
			row:SetSize(width, LEDGER_ROW)
			row:SetPoint("TOPLEFT", 0, -(LEDGER_HEAD + (i - 1) * LEDGER_ROW))
			row.shade = ns.BookSolid(row, LOOK.shade, "BACKGROUND", LOOK.shadeAlpha)
			row.rule = row:CreateTexture(nil, "BORDER")
			row.rule:SetColorTexture(LOOK.rowRule[1], LOOK.rowRule[2], LOOK.rowRule[3], LOOK.rowRuleAlpha)
			row.rule:SetPoint("BOTTOMLEFT")
			row.rule:SetPoint("BOTTOMRIGHT")
			row.rule:SetHeight(1)
			row.cells = {}
			for c in ipairs(columns) do
				row.cells[c] = ns.BookText(row, ns.BookFonts().small, LOOK.ink)
			end
			lay(row, row.cells)
			ledger.rows[i] = row
		end
		return row
	end

	function ledger.SetRows(self, rows, chosen)
		for i, data in ipairs(rows) do
			local row = rowAt(i)
			for c, cell in ipairs(row.cells) do
				cell:SetText(data.cells[c] or "")
			end
			row.shade:SetShown(i == chosen)
			local onClick = data.onClick
			row:SetScript("OnClick", onClick and function()
				onClick()
			end or nil)
			row:Show()
		end
		for i = #rows + 1, #self.rows do
			self.rows[i]:Hide()
		end
		local height = LEDGER_HEAD + #rows * LEDGER_ROW
		self:SetHeight(height)
		return height
	end
	return ledger
end

--- A tile (stats.md › UI: the home spread's zones, an item's waters): an ink outline round a pale wash, the name at its
--- top left, its line in italic at its foot, "I'm here" in green handwriting at its right, and a red handwritten note
--- under it ("watching 2", "212 since"). Clicking it opens what it names.
---@class StatsBookTileData
---@field name string
---@field line string?
---@field here string?     -- "I'm here", when it is the current place
---@field note string?     -- red handwriting
---@field onClick fun()?

---@class StatsBookTileView: Button
---@field name FontString
---@field line FontString
---@field here FontString
---@field note FontString
---@field SetTile fun(self: StatsBookTileView, tile: StatsBookTileData)

---@param parent Frame
---@param width number
---@param height number
---@return StatsBookTileView
function ns.NewBookTile(parent, width, height)
	local tile = CreateFrame("Button", nil, parent) --[[@as StatsBookTileView]]
	tile:SetSize(width, height)
	ns.BookSolid(tile, LOOK.ledgerRule, "BACKGROUND")
	local face = ns.BookSolid(tile, LOOK.paper, "BORDER")
	face:SetPoint("TOPLEFT", 1, -1)
	face:SetPoint("BOTTOMRIGHT", -1, 1)
	local wash = ns.BookSolid(tile, LOOK.tileWash, "BORDER", LOOK.tileWashAlpha)
	wash:SetPoint("TOPLEFT", 1, -1)
	wash:SetPoint("BOTTOMRIGHT", -1, 1)
	local faces = ns.BookFonts()
	tile.name = ns.BookText(tile, faces.text, LOOK.title)
	tile.name:SetPoint("TOPLEFT", 8, -6)
	tile.name:SetPoint("TOPRIGHT", -8, -6)
	tile.line = ns.BookText(tile, faces.note, LOOK.ledgerRule)
	tile.line:SetPoint("BOTTOMLEFT", 8, 7)
	tile.line:SetPoint("BOTTOMRIGHT", -8, 7)
	tile.here = ns.BookText(tile, faces.hand, LOOK.green)
	tile.here:SetPoint("TOPRIGHT", -7, -22)
	tile.here:SetJustifyH("RIGHT")
	tile.note = ns.BookText(tile, faces.hand, LOOK.red)
	tile.note:SetPoint("BOTTOMRIGHT", -7, 22)
	tile.note:SetJustifyH("RIGHT")
	function tile.SetTile(self, data)
		self.name:SetText(data.name)
		for _, field in ipairs({ "line", "here", "note" }) do
			local text = data[field]
			self[field]:SetText(text or "")
			self[field]:SetShown(text ~= nil)
		end
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return tile
end

--- The leather on `frame`, filling it: the outline, the leather's tint, its grain and the gilt rule inside its edge.
---@class StatsBookLeatherView
---@field edge Texture
---@field leather Texture
---@field grain Texture
---@field rules Texture[]

---@param frame Frame
---@return StatsBookLeatherView
function ns.NewBookLeather(frame)
	local view = { rules = {} }
	view.edge = ns.BookSolid(frame, LOOK.leatherEdge, "BACKGROUND")
	view.leather = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	view.leather:SetColorTexture(LOOK.leather[1], LOOK.leather[2], LOOK.leather[3], 1)
	view.leather:SetPoint("TOPLEFT", 2, -2)
	view.leather:SetPoint("BOTTOMRIGHT", -2, 2)
	view.grain = frame:CreateTexture(nil, "BORDER")
	view.grain:SetTexture(TEXTURES.leather)
	view.grain:SetVertexColor(LOOK.leather[1], LOOK.leather[2], LOOK.leather[3])
	view.grain:SetAlpha(0.5)
	view.grain:SetPoint("TOPLEFT", 2, -2)
	view.grain:SetPoint("BOTTOMRIGHT", -2, 2)
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT", 5, -5 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", 5, 5 },
		{ "TOPLEFT", "BOTTOMLEFT", 5, -5 },
		{ "TOPRIGHT", "BOTTOMRIGHT", -5, -5 },
	}) do
		local rule = frame:CreateTexture(nil, "BORDER", nil, 1)
		rule:SetColorTexture(LOOK.leatherRule[1], LOOK.leatherRule[2], LOOK.leatherRule[3], 1)
		local x, y = points[3], points[4]
		rule:SetPoint(points[1], x, y)
		if i <= 2 then
			rule:SetPoint(points[2], -x, y)
			rule:SetHeight(1)
		else
			rule:SetPoint(points[2], x, -y)
			rule:SetWidth(1)
		end
		view.rules[i] = rule
	end
	return view
end

--- A parchment page on `frame`, filling it: the paper's tint and texture and, on the side `spine` names, the spine's
--- shadow fading into the page.
---@class StatsBookParchmentView
---@field paper Texture
---@field grain Texture
---@field spine Texture[]

-- The spine's shadow: strips of fading shade at a page's inner edge.
local SPINE_STRIPS, SPINE_STRIP_WIDTH = 6, 5

---@param frame Frame
---@param spine "LEFT"|"RIGHT"|nil
---@return StatsBookParchmentView
function ns.NewBookParchment(frame, spine)
	local view = { spine = {} }
	view.paper = ns.BookSolid(frame, LOOK.paper, "BACKGROUND")
	view.grain = frame:CreateTexture(nil, "BORDER")
	view.grain:SetTexture(TEXTURES.paper)
	view.grain:SetVertexColor(LOOK.paper[1], LOOK.paper[2], LOOK.paper[3])
	view.grain:SetAlpha(0.35)
	view.grain:SetAllPoints()
	if spine then
		for i = 1, SPINE_STRIPS do
			local strip = frame:CreateTexture(nil, "BORDER", nil, 1)
			local alpha = 0.4 * (SPINE_STRIPS - i + 1) / SPINE_STRIPS
			strip:SetColorTexture(LOOK.spine[1], LOOK.spine[2], LOOK.spine[3], alpha)
			strip:SetWidth(SPINE_STRIP_WIDTH)
			local x = (i - 1) * SPINE_STRIP_WIDTH * (spine == "RIGHT" and -1 or 1)
			strip:SetPoint("TOP" .. spine, x, 0)
			strip:SetPoint("BOTTOM" .. spine, x, 0)
			view.spine[i] = strip
		end
	end
	return view
end

--- A ribbon (STA-R74): a cloth tab hanging from the leather's right edge, its words in letters stacked down it, red,
--- or green for Where I am, standing out further and brighter when its page shows.
---@class StatsBookRibbonView: Button
---@field face Texture
---@field label FontString
---@field chosen boolean
---@field SetRibbon fun(self: StatsBookRibbonView, text: string, green: boolean, chosen: boolean)

-- A ribbon's width, its padding at each end, a letter's height, and how far a chosen one stands out.
local RIBBON_WIDTH, RIBBON_PAD, LETTER_HEIGHT, RIBBON_OUT = 22, 9, 11, 5

---@param parent Frame
---@return StatsBookRibbonView
function ns.NewBookRibbon(parent)
	local ribbon = CreateFrame("Button", nil, parent) --[[@as StatsBookRibbonView]]
	ribbon.face = ribbon:CreateTexture(nil, "BACKGROUND")
	ribbon.label = ns.BookText(ribbon, ns.BookFonts().ribbon, LOOK.ribbonText)
	ribbon.label:SetJustifyH("CENTER")
	ribbon.chosen = false
	function ribbon.SetRibbon(self, text, green, chosen)
		local letters = {}
		for letter in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
			letters[#letters + 1] = letter
		end
		self.label:SetText(table.concat(letters, "\n"))
		local height = #letters * LETTER_HEIGHT + 2 * RIBBON_PAD
		self:SetSize(RIBBON_WIDTH + RIBBON_OUT, height)
		local color = green and (chosen and LOOK.ribbonHereChosen or LOOK.ribbonHere)
			or (chosen and LOOK.ribbonChosen or LOOK.ribbon)
		self.face:SetColorTexture(color[1], color[2], color[3], 1)
		self.face:ClearAllPoints()
		self.face:SetPoint("TOPLEFT", chosen and RIBBON_OUT or 0, 0)
		self.face:SetSize(RIBBON_WIDTH, height)
		self.label:ClearAllPoints()
		self.label:SetPoint("TOP", self.face, "TOP", 0, -RIBBON_PAD)
		self.chosen = chosen
	end
	return ribbon
end

--- The gold nameplate on the leather (stats.md › UI › On the leather): a gold face with an outline, sized to its words.
---@class StatsBookPlateView: Frame
---@field face Texture
---@field label FontString
---@field SetPlate fun(self: StatsBookPlateView, text: string)

---@param parent Frame
---@return StatsBookPlateView
function ns.NewBookPlate(parent)
	local plate = CreateFrame("Frame", nil, parent) --[[@as StatsBookPlateView]]
	ns.BookSolid(plate, LOOK.plateEdge, "BACKGROUND")
	plate.face = ns.BookSolid(plate, LOOK.plate, "BORDER")
	plate.face:SetPoint("TOPLEFT", 1, -1)
	plate.face:SetPoint("BOTTOMRIGHT", -1, 1)
	plate.label = ns.BookText(plate, ns.BookFonts().plate, LOOK.plateText)
	plate.label:SetPoint("CENTER")
	function plate.SetPlate(self, text)
		self.label:SetText(text)
		self:SetSize(self.label:GetStringWidth() + 20, 22)
	end
	return plate
end
