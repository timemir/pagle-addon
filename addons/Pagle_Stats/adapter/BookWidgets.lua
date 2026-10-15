if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's art kit (STA-R70, stats.md › UI): the book language's tints, fonts and in-client textures, and a
-- widget maker for each piece the book and its pages draw: the leather, parchment, ribbons and the nameplate for the
-- shell (adapter/Book.lua); for the pages, a kicker, a title, a handwriting line, a heading with its small note, a "☛"
-- link, sepia ink icons, an item's icon and name, an ink bar, the luck ruler, a ruled ledger, a tile and the tile
-- grid, a place's row, a short list's line, a figure line with its leader and "No Sessions yet."; and the fleuron,
-- pointing hands and star, drawn as textures, never as font glyphs. The look follows prototypes/stats-window/ variant
-- D. Stats shares no code with the Ledger's Fish Journal (ADR 0001), though some textures and fonts are the same
-- client files. Every texture sits on a solid tint or carries a vertex tint, so a texture the client lacks leaves the
-- tint showing.
--
-- A piece two pages draw has its one maker here, so the pages draw it alike.

--- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1. The tracker block and the goods'
--- frame looks (adapter/TrackerBlock.lua, adapter/Goods.lua) mix theirs with it too.
---@param hex string "RRGGBB"
---@return number[]
function ns.BookTint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end
local tint = ns.BookTint

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
	searchPaper = tint("efe0bb"), -- the search box (adapter/Search.lua)
	margin = tint("7a6a50"), -- a row's margin: its Dry spell in handwriting
	-- Item names by quality, in inks that read on the paper (variant D's `.vD .qn.q<n>`; the game's own white and
	-- yellows don't): poor, common, uncommon, rare, epic, then legendary in a dark orange of our own.
	quality = {
		[0] = tint("7a7060"),
		tint("3a2614"),
		tint("2a7a1a"),
		tint("1a4a9a"),
		tint("6a2a9a"),
		tint("9a5a10"),
	},
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
	-- The star raid target (Blizzard_ChatFrameBase/Shared/ChatFrameConstants.lua's {rt1}): a watched row's ★.
	star = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
	-- A pencil on a note (the friends list's note icon, Blizzard_FriendsFrame/Camelot/FriendsFrame.xml): the "✎" before
	-- a watched Dry spell on the home spread (adapter/Home.lua).
	pencil = "Interface\\FriendsFrame\\UI-FriendsFrame-Note",
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
--- mirrored and turned it points right, turned the other way it points left. The pencil "✎" is in the hand's ink;
--- the star "★" marks a watched row, in red ink.
---@alias StatsBookMark "fleuron"|"hand"|"handLeft"|"pencil"|"star"

---@type table<StatsBookMark, { texture: string, color: number[], mirror: boolean, turn: number }>
local MARKS = {
	fleuron = { texture = TEXTURES.fleuron, color = LOOK.fleuron, mirror = false, turn = 0 },
	star = { texture = TEXTURES.star, color = LOOK.red, mirror = false, turn = 0 },
	hand = { texture = TEXTURES.hand, color = LOOK.red, mirror = true, turn = -math.pi / 4 },
	handLeft = { texture = TEXTURES.hand, color = LOOK.red, mirror = false, turn = math.pi / 4 },
	pencil = { texture = TEXTURES.pencil, color = LOOK.hand, mirror = false, turn = 0 },
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

--- The luck ruler (stats.md › UI › Place spread; an entry's, adapter/Entry.lua): where my wait sits among anglers with
--- my odds, never a bar filling toward "due". A horizontal log scale of `P` from 1 at the left ("all") to 10⁻⁶ at the
--- right ("1 in 1M"), ticked at each power of ten with its label above; the unlucky and very unlucky ranges as two
--- faint red washes on it, the three bands named underneath; a red "me" mark at the reading's `P` (ns.RulerPosition,
--- clamped at both ends); then the fixed line "Every Cast is its own roll; nothing is owed." (STA-R58). Drawn in solid
--- tints (SetColorTexture) and the book's fonts, no texture file. Its width is the scale's: its labels at the ends
--- reach past it by half their width, so a page sets it in from both sides.
---@class StatsBookRulerView: Frame
---@field rule Texture            -- the scale's base line
---@field ticks Texture[]         -- left to right, one per ns.LUCK_RULER_TICKS
---@field tickLabels FontString[]
---@field washes Texture[]        -- unlucky, very unlucky
---@field bandLabels FontString[] -- normal, unlucky, very unlucky
---@field mark Texture            -- the red "me" mark
---@field me FontString
---@field owed FontString
---@field position number         -- where the mark is, 0 (left) to 1 (right)
---@field SetRuler fun(self: StatsBookRulerView, P: number)

-- The ruler's measures down from its top: the mark's top, the tick labels' top, the washes' top, the ticks' top, the
-- base line, the band labels' top, the fixed line's top, and its whole height.
local RULER_MARK, RULER_TICK_LABEL, RULER_WASH, RULER_TICK, RULER_BASE = 24, 32, 40, 48, 56
local RULER_BANDS, RULER_OWED, RULER_HEIGHT = 61, 80, 96
-- The washes' opacity: unlucky fainter than very unlucky (variant D's rgba(154,42,26,.08) and .18).
local RULER_WASH_ALPHA = { 0.08, 0.18 }

---@param parent Frame
---@param width number the scale's width
---@return StatsBookRulerView
function ns.NewBookRuler(parent, width)
	local ruler = CreateFrame("Frame", nil, parent) --[[@as StatsBookRulerView]]
	ruler:SetSize(width, RULER_HEIGHT)
	local faces, L = ns.BookFonts(), ns.L
	-- Shows `region` centred on `x` across the scale, `y` down.
	local function centre(region, x, y)
		region:ClearAllPoints()
		region:SetPoint("TOP", ruler, "TOPLEFT", x, -y)
	end
	local function solid(color, alpha, layer)
		local texture = ruler:CreateTexture(nil, layer or "ARTWORK")
		texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
		return texture
	end
	-- The bands' edges along the scale: the left end, unlucky's, very unlucky's and the right end.
	local edges = { 0, ns.RulerPosition(ns.UNLUCKY_BELOW), ns.RulerPosition(ns.VERY_UNLUCKY_BELOW), 1 }

	ruler.washes = {}
	for i = 1, 2 do
		local from, to = edges[i + 1] * width, edges[i + 2] * width
		local wash = solid(LOOK.red, RULER_WASH_ALPHA[i], "BACKGROUND")
		wash:SetPoint("TOPLEFT", from, -RULER_WASH)
		wash:SetSize(to - from, RULER_BASE - RULER_WASH)
		ruler.washes[i] = wash
	end
	ruler.rule = solid(LOOK.ledgerRule)
	ruler.rule:SetPoint("TOPLEFT", 0, -RULER_BASE)
	ruler.rule:SetSize(width, 2)
	ruler.ticks, ruler.tickLabels = {}, {}
	for i, P in ipairs(ns.LUCK_RULER_TICKS) do
		local x = ns.RulerPosition(P) * width
		local tick = solid(LOOK.note)
		tick:SetSize(1, RULER_BASE - RULER_TICK)
		centre(tick, x, RULER_TICK)
		local label = ns.BookText(ruler, faces.note, LOOK.note)
		label:SetJustifyH("CENTER")
		label:SetText(L.RULER_TICKS[i])
		centre(label, x, RULER_TICK_LABEL)
		ruler.ticks[i], ruler.tickLabels[i] = tick, label
	end
	ruler.bandLabels = {}
	---@type StatsBand[]
	local bands = { "normal", "unlucky", "veryUnlucky" }
	for i, band in ipairs(bands) do
		local label = ns.BookText(ruler, faces.note, LOOK.note)
		label:SetJustifyH("CENTER")
		label:SetText(ns.BandWord(band))
		label:SetPoint("TOPLEFT", edges[i] * width, -RULER_BANDS)
		label:SetWidth((edges[i + 1] - edges[i]) * width)
		ruler.bandLabels[i] = label
	end
	ruler.mark = solid(LOOK.red, 1, "OVERLAY")
	ruler.mark:SetSize(2, RULER_BASE - RULER_MARK)
	ruler.me = ns.BookText(ruler, faces.hand, LOOK.red)
	ruler.me:SetJustifyH("CENTER")
	ruler.me:SetText(L.RULER_ME)
	ruler.me:SetPoint("BOTTOM", ruler.mark, "TOP", 0, 1)
	ruler.owed = ns.BookText(ruler, faces.note, LOOK.note)
	ruler.owed:SetPoint("TOPLEFT", 0, -RULER_OWED)
	ruler.owed:SetWidth(width)
	ruler.owed:SetWordWrap(true)
	ruler.owed:SetText(L.NOTHING_IS_OWED)
	ruler.position = 0
	function ruler.SetRuler(self, P)
		self.position = ns.RulerPosition(P)
		centre(self.mark, self.position * width, RULER_MARK)
	end
	ruler:SetRuler(1)
	return ruler
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

--- An item name's ink on the paper by its quality (variant D): `ns.BOOK_LOOK.quality`, or plain ink for a quality it
--- has none for or none known (an Uncharted item the client hasn't described).
---@param quality integer?
---@return number[]
function ns.BookQualityInk(quality)
	return quality and LOOK.quality[quality] or LOOK.ink
end

--- A row on a place's page (stats.md › UI › Place spread): an ink icon, the name in its quality's ink, ★ when watched,
--- Your odds in short ("learning {n}/100" in handwriting, "not seen yet" in the note's italic ink), and in the margin,
--- in handwriting, the Dry spell with ", unlucky" or ", very unlucky" after it in red. Clicking it chooses the item;
--- the chosen row is shaded.
---@class StatsBookRowData
---@field icon string|integer
---@field name string
---@field ink number[]                 -- the name's ink (ns.BookQualityInk)
---@field watched boolean
---@field odds string
---@field oddsState "learning"|"unseen"|"known"
---@field margin string?               -- nothing in the margin when nil
---@field band string?                 -- red, after the margin
---@field chosen boolean
---@field onClick fun()?

---@class StatsBookRowView: Button
---@field isBookRow true
---@field shade Texture
---@field icon StatsBookIconView
---@field name FontString
---@field star Texture
---@field odds FontString
---@field margin FontString
---@field band FontString
---@field SetRow fun(self: StatsBookRowView, row: StatsBookRowData)

-- A row's height, its icon's size, the margin's width and the gap before it.
local ROW_HEIGHT, ROW_ICON, ROW_MARGIN, ROW_GAP = 24, 20, 104, 8
-- How much room a row's odds take at most, and the star's size.
local ROW_ODDS, ROW_STAR = 96, 12

---@param parent Frame
---@param width number
---@return StatsBookRowView
function ns.NewBookRow(parent, width)
	local row = CreateFrame("Button", nil, parent) --[[@as StatsBookRowView]]
	row:SetSize(width, ROW_HEIGHT)
	row.isBookRow = true
	row.shade = ns.BookSolid(row, LOOK.shade, "BACKGROUND", LOOK.shadeAlpha)
	row.icon = ns.NewBookIcon(row, ROW_ICON)
	row.icon:SetPoint("LEFT", 2, 0)
	local faces = ns.BookFonts()
	row.name = ns.BookText(row, faces.text, LOOK.ink)
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetWordWrap(false)
	row.star = ns.NewBookMark(row, "star", ROW_STAR)
	row.star:SetPoint("LEFT", row.name, "RIGHT", 3, 0)
	row.odds = ns.BookText(row, faces.small, LOOK.title)
	row.odds:SetPoint("RIGHT", -(ROW_MARGIN + ROW_GAP), 0)
	row.odds:SetJustifyH("RIGHT")
	row.margin = ns.BookText(row, faces.hand, LOOK.margin)
	row.margin:SetJustifyH("RIGHT")
	row.band = ns.BookText(row, faces.hand, LOOK.red)
	row.band:SetPoint("RIGHT", -2, 0)
	row.band:SetJustifyH("RIGHT")
	-- The name's room: the row less the icon, the star, the odds and the margin.
	local nameRoom = width - (ROW_ICON + 8) - (ROW_STAR + 6) - ROW_ODDS - ROW_MARGIN - ROW_GAP
	function row.SetRow(self, data)
		self.icon:SetIcon(data.icon)
		self.name:SetText(data.name)
		self.name:SetTextColor(data.ink[1], data.ink[2], data.ink[3])
		self.name:SetWidth(math.min(self.name:GetStringWidth() + 1, nameRoom))
		self.star:SetShown(data.watched)
		self.odds:SetText(data.odds)
		if data.oddsState == "learning" then
			self.odds:SetFontObject(faces.hand)
			self.odds:SetTextColor(LOOK.hand[1], LOOK.hand[2], LOOK.hand[3])
		elseif data.oddsState == "unseen" then
			self.odds:SetFontObject(faces.note)
			self.odds:SetTextColor(LOOK.note[1], LOOK.note[2], LOOK.note[3])
		else
			self.odds:SetFontObject(faces.small)
			self.odds:SetTextColor(LOOK.title[1], LOOK.title[2], LOOK.title[3])
		end
		self.margin:SetText(data.margin or "")
		self.margin:SetShown(data.margin ~= nil)
		self.band:SetText(data.band or "")
		self.band:SetShown(data.band ~= nil)
		self.margin:ClearAllPoints()
		if data.band then
			self.margin:SetPoint("RIGHT", self.band, "LEFT", 0, 0)
		else
			self.margin:SetPoint("RIGHT", -2, 0)
		end
		self.shade:SetShown(data.chosen)
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return row
end

--- A line of a short list (stats.md › UI: a zone's waters, a place's numbers): its label at the left, "I'm here" in
--- green handwriting after it when given, its value at the right, and a faint rule under it. With `onClick` it opens
--- what it names.
---@class StatsBookLineData
---@field label string
---@field value string
---@field here string?
---@field onClick fun()?

---@class StatsBookLineView: Button
---@field label FontString
---@field here FontString
---@field value FontString
---@field rule Texture
---@field SetLine fun(self: StatsBookLineView, line: StatsBookLineData)

-- A line's height.
local LINE_HEIGHT = 20

---@param parent Frame
---@param width number
---@return StatsBookLineView
function ns.NewBookLine(parent, width)
	local line = CreateFrame("Button", nil, parent) --[[@as StatsBookLineView]]
	line:SetSize(width, LINE_HEIGHT)
	local faces = ns.BookFonts()
	line.label = ns.BookText(line, faces.text, LOOK.ink)
	line.label:SetPoint("LEFT", 0, 0)
	line.here = ns.BookText(line, faces.hand, LOOK.green)
	line.here:SetPoint("LEFT", line.label, "RIGHT", 8, 0)
	line.value = ns.BookText(line, faces.text, LOOK.ink)
	line.value:SetPoint("RIGHT", 0, 0)
	line.value:SetJustifyH("RIGHT")
	line.rule = line:CreateTexture(nil, "BORDER")
	line.rule:SetColorTexture(LOOK.rowRule[1], LOOK.rowRule[2], LOOK.rowRule[3], LOOK.rowRuleAlpha)
	line.rule:SetPoint("BOTTOMLEFT")
	line.rule:SetPoint("BOTTOMRIGHT")
	line.rule:SetHeight(1)
	function line.SetLine(self, data)
		self.label:SetText(data.label)
		self.here:SetText(data.here or "")
		self.here:SetShown(data.here ~= nil)
		self.value:SetText(data.value)
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return line
end

--- A figure line (stats.md › UI: In this book, the Lifetime figures, a Session's figures): its label at the left, its
--- value at the right and a faint leader between them, as variant D's dotted table of contents. With `onClick` it
--- opens what it names, and its label reddens under the mouse.
---@class StatsBookFigureData
---@field label string
---@field value string?        -- none: no value and no leader
---@field ink number[]?        -- the label's ink, ns.BOOK_LOOK.ink by default
---@field valueInk number[]?   -- the value's ink, ns.BOOK_LOOK.ink by default
---@field onClick fun()?

---@class StatsBookFigureView: Button
---@field label FontString
---@field value FontString
---@field leader Texture
---@field ink number[]         -- the label's ink when the mouse leaves
---@field SetFigure fun(self: StatsBookFigureView, figure: StatsBookFigureData)

-- The leader's opacity, and how far above the line's foot it runs.
local LEADER_ALPHA, LEADER_RISE = 0.5, 3

---@param parent Frame
---@param width number
---@param height number
---@return StatsBookFigureView
function ns.NewBookFigure(parent, width, height)
	local faces = ns.BookFonts()
	local figure = CreateFrame("Button", nil, parent) --[[@as StatsBookFigureView]]
	figure:SetSize(width, height)
	figure.label = ns.BookText(figure, faces.text, LOOK.ink)
	figure.label:SetPoint("LEFT")
	figure.value = ns.BookText(figure, faces.text, LOOK.ink)
	figure.value:SetPoint("RIGHT")
	figure.value:SetJustifyH("RIGHT")
	figure.leader = figure:CreateTexture(nil, "ARTWORK")
	figure.leader:SetColorTexture(LOOK.note[1], LOOK.note[2], LOOK.note[3], LEADER_ALPHA)
	figure.leader:SetHeight(1)
	figure.leader:SetPoint("BOTTOMLEFT", figure.label, "BOTTOMRIGHT", 4, LEADER_RISE)
	figure.leader:SetPoint("BOTTOMRIGHT", figure.value, "BOTTOMLEFT", -4, LEADER_RISE)
	figure.ink = LOOK.ink
	figure:SetScript("OnEnter", function(self)
		if self:GetScript("OnClick") then
			self.label:SetTextColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
		end
	end)
	figure:SetScript("OnLeave", function(self)
		self.label:SetTextColor(self.ink[1], self.ink[2], self.ink[3])
	end)
	function figure.SetFigure(self, data)
		self.ink = data.ink or LOOK.ink
		local valueInk = data.valueInk or LOOK.ink
		self.label:SetText(data.label)
		self.label:SetTextColor(self.ink[1], self.ink[2], self.ink[3])
		self.value:SetText(data.value or "")
		self.value:SetTextColor(valueInk[1], valueInk[2], valueInk[3])
		self.leader:SetShown(data.value ~= nil)
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return figure
end

--- An item's name under a kicker (stats.md › UI: an entry, the item page): its ink icon, then its name as the page's
--- title beside it. The name is "Item {id}" until the client has it; the book asks for it and redraws when it arrives
--- (adapter/Book.lua's Book:Item, STA-R73).
---@class StatsBookItemTitleView
---@field icon StatsBookIconView
---@field title FontString
---@field SetItem fun(self: StatsBookItemTitleView, itemID: integer, y: number)

-- The icon's size and the gap between it and the name.
local ITEM_ICON, ITEM_ICON_GAP = 28, 8

---@param parent Frame
---@param width number
---@return StatsBookItemTitleView
function ns.NewBookItemTitle(parent, width)
	local view = { icon = ns.NewBookIcon(parent, ITEM_ICON), title = ns.NewBookTitle(parent) }
	view.title:SetWidth(width - ITEM_ICON - ITEM_ICON_GAP)
	function view.SetItem(self, itemID, y)
		local name, icon = ns.book:Item(itemID)
		self.icon:SetIcon(icon)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("TOPLEFT", 0, -y)
		self.icon:Show()
		self.title:SetText(name)
		self.title:ClearAllPoints()
		self.title:SetPoint("TOPLEFT", ITEM_ICON + ITEM_ICON_GAP, -(y + 2))
		self.title:Show()
	end
	return view
end

--- Tiles two a row (stats.md › UI: the home spread's zones, an item's waters), each opening its target: ns.NewBookTile
--- with variant D's height and gap, made as the rows need them, the ones left over hidden.
---@class StatsBookTileTarget: StatsBookTileData
---@field target StatsBookTarget

---@class StatsBookTileGridView
---@field tiles StatsBookTileView[]
---@field SetTiles fun(self: StatsBookTileGridView, tiles: StatsBookTileTarget[], y: number): number

-- A tile's height and the gap between tiles, across and down.
local TILE_HEIGHT, TILE_GAP = 84, 9

---@param parent Frame
---@return StatsBookTileGridView
function ns.NewBookTileGrid(parent)
	local grid = { tiles = {} }
	--- Lays `tiles` out from `y` down `parent`, across its width; returns their height, 0 for none.
	function grid.SetTiles(self, tiles, y)
		local tileWidth = (parent:GetWidth() - TILE_GAP) / 2
		for i, tile in ipairs(tiles) do
			local view = self.tiles[i]
			if not view then
				view = ns.NewBookTile(parent, tileWidth, TILE_HEIGHT)
				self.tiles[i] = view
			end
			local target = tile.target
			view:SetTile({
				name = tile.name,
				line = tile.line,
				here = tile.here,
				note = tile.note,
				onClick = function()
					ns.OpenBook(target)
				end,
			})
			local row, column = math.floor((i - 1) / 2), (i - 1) % 2
			view:ClearAllPoints()
			view:SetPoint(
				"TOPLEFT",
				parent,
				"TOPLEFT",
				column * (tileWidth + TILE_GAP),
				-(y + row * (TILE_HEIGHT + TILE_GAP))
			)
			view:Show()
		end
		for i = #tiles + 1, #self.tiles do
			self.tiles[i]:Hide()
		end
		local rows = math.ceil(#tiles / 2)
		return rows > 0 and rows * TILE_HEIGHT + (rows - 1) * TILE_GAP or 0
	end
	return grid
end

--- A page side's "No Sessions yet." in handwriting across `parent` (STA-R97): This Session, Sessions and Lifetime all
--- read it with no Casts.
---@param parent Frame
---@return FontString
function ns.NewBookNoSessions(parent)
	local text = ns.NewBookHand(parent)
	text:SetWidth(parent:GetWidth())
	text:SetText(ns.L.NO_SESSIONS)
	return text
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
