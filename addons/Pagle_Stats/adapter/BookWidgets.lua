if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's art (STA-R70, stats.md › UI), in the books art kit (the dev's PagleArtBooks probe, a fork of the
-- Fish Journal's book shell): the book language's tints and fonts, and a widget maker for each piece the book and its
-- pages draw: for the shell (adapter/Book.lua), the leather binding with its band and brass corners, parchment pages
-- with their gutter, the wax close button, grosgrain ribbons and the brass nameplate; for the pages, a kicker, a
-- title, a handwriting line, a heading with its small note, a "☛" link, item medallions, an item's icon and name, the
-- ink bar, the luck ruler, a ruled ledger, a tile and the tile grid, a place's row, a short list's line, a figure line
-- with its leader and "No Sessions yet."; and the fleuron, pointing hands, pencil and star, drawn as textures, never
-- as font glyphs. The sprites are adapter/BookAtlas.lua's, drawn with adapter/BookArt.lua's helpers; Stats shares no code
-- with the Ledger or Hunts (ADR 0001), though the shell's textures are Core's media, which Hunts reads too.
--
-- A piece two pages draw has its one maker here, so the pages draw it alike.

--- A tint from its hex code, as the kit's canvas writes it: { r, g, b }, 0 to 1. The tracker block and the goods'
--- looks (adapter/TrackerBlock.lua, adapter/Goods.lua) mix theirs with it too.
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

--- The book's tints, the books kit's design-system colours.
ns.BOOK_LOOK = {
	gilt = tint("e8c96a"), -- the breadcrumbs on the leather
	giltBright = tint("fff4c8"), -- a crumb under the mouse
	live = tint("f6e3a8"), -- the live line
	liveDot = tint("5ac85a"), -- its dot, glowing
	paper = tint("ead6ac"), -- the page's mid tone
	ink = tint("3a2614"), -- printed text
	title = tint("3e220c"), -- titles, large ink, tile names
	big = tint("1e1408"), -- Your odds in large ink
	kicker = tint("8a5a2a"), -- small-caps kickers and headings
	small = tint("5a4028"), -- small print
	note = tint("8a6a40"), -- italic notes
	faded = tint("9a8060"), -- what is greyed
	hand = tint("23407a"), -- handwriting
	red = tint("9a2a1a"), -- unlucky, the pointing hand, the star
	meRed = tint("b4281a"), -- the luck ruler's washes and "me"
	green = tint("2a6a2a"), -- "I'm here"
	link = tint("7a2a14"), -- a link's words
	headingRule = tint("c4a874"), -- the rule under a heading
	ledgerRule = tint("6a4a20"), -- the ruled ledger's head rule, a tile's outline
	rowRule = tint("8a5a2a"), -- rgba(138,90,42,.3): a ledger row's rule
	rowRuleAlpha = 0.3,
	shade = tint("784614"), -- the chosen row
	shadeAlpha = 0.12,
	tileLine = tint("6a4a20"), -- a tile's italic line
	tileWarm = { 1.06, 1.03, 0.95 }, -- a tile under the mouse warms slightly
	tipText = tint("e6d8b8"), -- the dark tooltip slip's words
	indexDots = tint("b8a080"), -- an index entry's dotted leader
	ledgerBlue = tint("466ea0"), -- a ruled ledger's row rules, faint blue
	ledgerBlueAlpha = 0.28,
	ledgerRed = tint("b4281a"), -- its column rules, faint red
	ledgerRedAlpha = 0.35,
	sepia = tint("dcb37a"), -- an item icon's tint over its greys (CSS sepia(.75))
	plateText = tint("2a1a04"), -- the brass nameplate's words
	wax = tint("f4dfa8"), -- the gilt "?" pressed into the wax beside the close (ONB-R59)
	margin = tint("5a4028"), -- a row's margin: its Dry spell in handwriting
	ribbonLabel = tint("efd286"), -- a ribbon's words
	ribbonLabelOn = tint("fff0bc"), -- the chosen ribbon's
	--- Each ribbon's colour, by its ns.BOOK_RIBBONS id: Where I am green, the others in their own.
	ribbons = { here = tint("2f6a3a"), session = tint("2f5a8a"), lifetime = tint("8a5a1a"), sessions = tint("6a2a2a") },
}
local LOOK = ns.BOOK_LOOK

--- In-client textures the book still draws (each a file the forever client's FrameXML names, Gethe/wow-ui-source
--- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57): what the kit leaves out.
ns.BOOK_TEXTURES = {
	-- A white disc (CharacterFrame's portrait mask): dots, and the round mask over an item's icon.
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- The pointing hand (the gauntlet cursor): "☛" and "☚".
	hand = "Interface\\Cursor\\Point",
}
local TEXTURES = ns.BOOK_TEXTURES

--- The book's font objects (adapter/BookArt.lua's faces), made on first use.
---@class StatsBookFonts
---@field text Font     -- printed text (IM Fell, 14)
---@field row Font      -- a row's name (14.5)
---@field small Font    -- small print, ledger cells, odds (13.5)
---@field note Font     -- italic notes (13.5)
---@field headNote Font -- a heading's small note (italic 12.5)
---@field kicker Font   -- small-caps kickers (12)
---@field head Font     -- small-caps headings (12.5)
---@field title Font    -- page titles (29)
---@field itemTitle Font -- an item's name beside its medallion (26)
---@field big Font      -- large ink: "1 in 40" (Caveat Bold, 46)
---@field about Font    -- "about" before it (Caveat SemiBold, 24)
---@field hand Font     -- handwriting (Caveat, 20)
---@field margin Font   -- a row's margin (17)
---@field link Font     -- a link's words (IM Fell, 15)
---@field crumb Font    -- the leather's breadcrumbs and the live line (Marcellus, 14, shadowed)
---@field ribbon Font   -- a ribbon's words (12, shadowed)
---@field plate Font    -- the nameplate (12)
---@field tick Font     -- the ruler's ticks (11.5)
---@field band Font     -- the ruler's bands (10.5)
---@field me Font       -- the ruler's "me" (Caveat Bold, 18)
---@field tileName Font -- a tile's name (IM Fell, 16)
---@field tileLine Font -- a tile's line (italic 13)
---@field tip Font      -- the dark tooltip slip's words (13.5)
---@field count Font    -- an index entry's count, in the hand (Caveat, 17)
local fonts

---@return StatsBookFonts
function ns.BookFonts()
	if not fonts then
		local font = ns.ArtFont
		fonts = {
			text = font("print", 14),
			row = font("print", 14.5),
			small = font("print", 13.5),
			note = font("italic", 13.5),
			headNote = font("italic", 12.5),
			kicker = font("print", 12),
			head = font("print", 12.5),
			title = font("print", 29),
			itemTitle = font("print", 26),
			big = font("handBold", 46),
			about = font("handSemi", 24),
			hand = font("hand", 20),
			margin = font("hand", 17),
			link = font("print", 15),
			crumb = font("gilt", 14, true),
			ribbon = font("gilt", 12, true),
			plate = font("gilt", 12),
			tick = font("print", 11.5),
			band = font("print", 10.5),
			me = font("handBold", 18),
			tileName = font("print", 16),
			tileLine = font("italic", 13),
			tip = font("print", 13.5),
			count = font("hand", 17),
		}
	end
	return fonts
end

--- A heading in small caps: the client has none, so it is set in capitals a size down.
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

--- Holds a single line within `room`: as wide as its words, or `room`, past which the client cuts it short with an
--- ellipsis. Every line on a page is bound so, so no words draw past the page's edge.
---@param text FontString
---@param room number
function ns.BookBound(text, room)
	text:SetWordWrap(false)
	text:SetWidth(0) -- measured unbounded
	text:SetWidth(math.max(1, math.min(text:GetStringWidth() + 1, room)))
end
local bound = ns.BookBound

--- A kicker: the small-caps line above a page's title ("THE WATERS"). Its SetText sets the words in small caps, held
--- within its page's width.
---@param parent Frame
---@param room number? its width, the page's by default
---@return FontString
function ns.NewBookKicker(parent, room)
	local kicker = ns.BookText(parent, ns.BookFonts().kicker, LOOK.kicker)
	local setText = kicker.SetText
	kicker.SetText = function(self, text)
		setText(self, text and ns.BookSmallCaps(text))
		bound(self, room or parent:GetWidth())
	end
	return kicker
end

--- A page's title, in the print face's large size and the title ink, held within its page's width.
---@param parent Frame
---@return FontString
function ns.NewBookTitle(parent)
	local title = ns.BookText(parent, ns.BookFonts().title, LOOK.title)
	local setText = title.SetText
	title.SetText = function(self, text)
		setText(self, text)
		bound(self, parent:GetWidth())
	end
	return title
end

--- A line of handwriting: first-person notes (STA-R59), in the hand's blue ink, wrapping at its width, its lines
--- close as the hand sets them.
---@param parent Frame
---@return FontString
function ns.NewBookHand(parent)
	local hand = ns.BookText(parent, ns.BookFonts().hand, LOOK.hand)
	hand:SetWordWrap(true)
	hand:SetSpacing(2)
	return hand
end

--- A heading over a group (*Dry spell*, *In my records*): its words in small caps, its small note in italic after
--- them, and a rule under both. 21 px high.
---@class StatsBookHeadingView: Frame
---@field label FontString
---@field note FontString
---@field rule Texture
---@field SetHeading fun(self: StatsBookHeadingView, text: string, note: string?)

---@param parent Frame
---@param width number
---@return StatsBookHeadingView
function ns.NewBookHeading(parent, width)
	local faces = ns.BookFonts()
	local heading = CreateFrame("Frame", nil, parent) --[[@as StatsBookHeadingView]]
	heading:SetSize(width, 21)
	heading.label = ns.BookText(heading, faces.head, LOOK.kicker)
	heading.label:SetPoint("TOPLEFT", 0, -4)
	heading.note = ns.BookText(heading, faces.headNote, LOOK.note)
	heading.note:SetPoint("LEFT", heading.label, "RIGHT", 8, 0)
	heading.rule = heading:CreateTexture(nil, "ARTWORK")
	heading.rule:SetColorTexture(LOOK.headingRule[1], LOOK.headingRule[2], LOOK.headingRule[3], 1)
	heading.rule:SetPoint("BOTTOMLEFT")
	heading.rule:SetPoint("BOTTOMRIGHT")
	heading.rule:SetHeight(1)
	function heading.SetHeading(self, text, note)
		self.label:SetText(ns.BookSmallCaps(text))
		bound(self.label, width)
		self.note:SetText(note or "")
		self.note:SetShown(note ~= nil)
		bound(self.note, width - self.label:GetWidth() - 8)
	end
	return heading
end

--- A mark drawn as a texture (STA-R70's art, never a font glyph): the kit's gilt fleuron between crumbs, the kit's red
--- star "★" on a watched row; the pointing hand "☛" after a link, or "☚" before one, in red ink (the gauntlet cursor
--- points up and to the left: mirrored and turned it points right, turned the other way it points left), and the
--- kit v2's pen "✎" before a watched Dry spell, tinted to its line's ink.
---@alias StatsBookMark "fleuron"|"hand"|"handLeft"|"pen"|"star"

---@type table<StatsBookMark, { texture: string, color: number[], mirror: boolean, turn: number }>
local MARKS = {
	hand = { texture = TEXTURES.hand, color = LOOK.red, mirror = true, turn = -math.pi / 4 },
	handLeft = { texture = TEXTURES.hand, color = LOOK.red, mirror = false, turn = math.pi / 4 },
}

---@param parent Frame
---@param mark StatsBookMark
---@param size number
---@return Texture
function ns.NewBookMark(parent, mark, size)
	if mark == "fleuron" then
		return ns.ArtSprite(parent, "Book", "fleuron", "ARTWORK", 0, size)
	elseif mark == "star" then
		return ns.ArtSprite(parent, "Parts", "star", "ARTWORK", 0, size)
	elseif mark == "pen" then
		local pen = ns.ArtSprite(parent, "Stats", "pen", "ARTWORK", 0, size)
		pen:SetVertexColor(LOOK.hand[1], LOOK.hand[2], LOOK.hand[3])
		return pen
	end
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

--- A link on a page: its words in the link's ink over a dotted underline, with the pointing hand after them ("Every
--- water it bites in ☛"), clicking it doing what it names.
---@class StatsBookLinkView: Button
---@field label FontString
---@field mark Texture
---@field dots Texture[]
---@field SetLink fun(self: StatsBookLinkView, text: string, onClick: fun())

-- The underline's dots: one every few units, faint.
local LINK_DOT_STEP, LINK_DOT_ALPHA = 3, 0.5

---@param parent Frame
---@return StatsBookLinkView
function ns.NewBookLink(parent)
	local link = CreateFrame("Button", nil, parent) --[[@as StatsBookLinkView]]
	link.label = ns.BookText(link, ns.BookFonts().link, LOOK.link)
	link.label:SetPoint("LEFT")
	link.mark = ns.NewBookMark(link, "hand", 16)
	link.mark:SetPoint("LEFT", link.label, "RIGHT", 4, 0)
	link.dots = {}
	function link.SetLink(self, text, onClick)
		self.label:SetText(text)
		bound(self.label, parent:GetWidth() - 22)
		local width = self.label:GetWidth()
		self:SetSize(width + 22, 20)
		local count = math.floor(width / LINK_DOT_STEP) + 1
		for i = 1, count do
			local dot = self.dots[i]
			if not dot then
				dot = ns.BookSolid(self, LOOK.link, "ARTWORK", LINK_DOT_ALPHA)
				dot:ClearAllPoints()
				dot:SetSize(1, 1)
				self.dots[i] = dot
			end
			dot:SetPoint("BOTTOMLEFT", (i - 1) * LINK_DOT_STEP, 1)
			dot:Show()
		end
		for i = count + 1, #self.dots do
			self.dots[i]:Hide()
		end
		self:SetScript("OnClick", function()
			onClick()
		end)
	end
	return link
end

--- An item's medallion: its icon (or the question mark, STA-R59) round, in sepia, inside a ring: the kit's small ring
--- on a row, its silver ring by a title.
---@class StatsBookIconView: Frame
---@field icon Texture
---@field ring StatsSpriteTexture
---@field SetIcon fun(self: StatsBookIconView, texture: string|integer)

---@param parent Frame
---@param size number the icon's size
---@return StatsBookIconView
function ns.NewBookIcon(parent, size)
	local view = CreateFrame("Frame", nil, parent) --[[@as StatsBookIconView]]
	view:SetSize(size, size)
	view.icon = ns.ArtCrisp(view:CreateTexture(nil, "ARTWORK", nil, 0))
	view.icon:SetSize(size - 2, size - 2)
	view.icon:SetPoint("CENTER")
	local mask = view:CreateMaskTexture()
	mask:SetTexture(TEXTURES.disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(view.icon)
	view.icon:AddMaskTexture(mask)
	local small = size <= 20
	view.ring =
		ns.ArtSprite(view, "Parts", small and "sic-ring" or "ic-ring-silver", "ARTWORK", 1, size + (small and 2 or 6))
	ns.CenterSprite(view.ring, view)
	function view.SetIcon(self, texture)
		self.icon:SetTexture(texture)
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(LOOK.sepia[1], LOOK.sepia[2], LOOK.sepia[3])
	end
	return view
end

--- An ink bar (stats.md › UI: "Learning…"): the kit's empty ink stroke, sliced to its width, the full stroke cut to its
--- share over it (stretched only past the sprite's own length).
---@class StatsBookInkBarView: Frame
---@field empty StatsThreeSlice
---@field fill Texture
---@field fillSlice StatsThreeSlice
---@field fillFrame Frame
---@field value number
---@field SetBar fun(self: StatsBookInkBarView, fill: number)

-- The bar's height, and the ink's end caps.
local INK_HEIGHT, INK_CAP = 10, 6

---@param parent Frame
---@param width number
---@return StatsBookInkBarView
function ns.NewBookInkBar(parent, width)
	local bar = CreateFrame("Frame", nil, parent) --[[@as StatsBookInkBarView]]
	bar:SetSize(width, INK_HEIGHT)
	bar.empty = CreateFrame("Frame", nil, bar) --[[@as StatsThreeSlice]]
	bar.empty:SetPoint("TOPLEFT")
	ns.SetThreeSlice(bar.empty, "Parts", "ink-empty", width, INK_CAP, "ARTWORK", 0)
	-- the full stroke on its own frame over the empty one's, which a child frame would otherwise draw over
	bar.fillFrame = CreateFrame("Frame", nil, bar)
	bar.fillFrame:SetAllPoints()
	bar.fillFrame:SetFrameLevel(bar.empty:GetFrameLevel() + 1)
	bar.fill = ns.ArtCrisp(bar.fillFrame:CreateTexture(nil, "ARTWORK"))
	bar.fillSlice = CreateFrame("Frame", nil, bar) --[[@as StatsThreeSlice]]
	bar.fillSlice:SetPoint("TOPLEFT")
	bar.fillSlice:SetFrameLevel(bar.empty:GetFrameLevel() + 1)
	bar.value = 0
	local _, sprite = ns.ArtSpriteOf("Parts", "ink-full")
	local spriteLength = sprite.box[3]
	function bar.SetBar(self, fill)
		fill = math.max(0, math.min(1, fill))
		local length = width * fill
		local cut = length > 0 and length <= spriteLength
		local slice = length > spriteLength
		if cut then
			local shown = ns.SetCrop(self.fill, "Parts", "ink-full", length)
			ns.PlaceSprite(shown, self, 0, 0)
		elseif slice then
			ns.SetThreeSlice(self.fillSlice, "Parts", "ink-full", length, INK_CAP, "ARTWORK", 0)
		end
		self.fill:SetShown(cut)
		self.fillSlice:SetShown(slice)
		self.value = fill
	end
	return bar
end

--- The luck ruler (stats.md › UI › Place spread; an entry's, adapter/Entry.lua): where my wait sits among anglers with
--- my odds, never a bar filling toward "due". A horizontal log scale of `P` from 1 at the left ("all") to 10⁻⁶ at the
--- right ("1 in 1M") on an ink rule, ticked at each power of ten with its label under it; the unlucky and very unlucky
--- ranges as two faint red washes over it, the three bands named underneath in small caps; the kit's red "me" mark at
--- the reading's `P` (ns.RulerPosition, clamped at both ends) with "me" in the hand beside it; then the fixed line
--- "Every Cast is its own roll; nothing is owed." (STA-R58). Its width is the scale's: its labels at the ends reach
--- no further than the scale.
---@class StatsBookRulerView: Frame
---@field rule Texture            -- the scale's line
---@field ticks Texture[]         -- left to right, one per ns.LUCK_RULER_TICKS
---@field tickLabels FontString[]
---@field washes Texture[]        -- unlucky, very unlucky
---@field bandLabels FontString[] -- normal, unlucky, very unlucky
---@field mark StatsSpriteTexture -- the kit's red "me" mark
---@field me FontString
---@field owed FontString
---@field position number         -- where the mark is, 0 (left) to 1 (right)
---@field SetRuler fun(self: StatsBookRulerView, P: number)
---@field SetMark fun(self: StatsBookRulerView, position: number) -- the mark at `position` along the scale, 0 to 1

-- The ruler's measures down from its top: the scale's top (the washes'), the ticks' top, the scale's line, the tick
-- labels' top, the band labels' top, the fixed line's top, and its whole height; and the washes' height.
local RULER_SCALE, RULER_TICK, RULER_LINE, RULER_TICK_LABEL = 24, 30, 38, 42
local RULER_BANDS, RULER_OWED, RULER_HEIGHT, RULER_WASH = 57, 80, 96, 15
-- The washes' opacity: unlucky fainter than very unlucky.
local RULER_WASH_ALPHA = { 0.10, 0.20 }

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
		local wash = solid(LOOK.meRed, RULER_WASH_ALPHA[i], "BACKGROUND")
		wash:SetPoint("TOPLEFT", from, -RULER_SCALE)
		wash:SetSize(to - from, RULER_WASH)
		ruler.washes[i] = wash
	end
	ruler.rule = solid(LOOK.ink)
	ruler.rule:SetPoint("TOPLEFT", 0, -RULER_LINE)
	ruler.rule:SetSize(width, 1.5)
	ruler.ticks, ruler.tickLabels = {}, {}
	local last = #ns.LUCK_RULER_TICKS
	for i, P in ipairs(ns.LUCK_RULER_TICKS) do
		local x = ns.RulerPosition(P) * width
		local tick = solid(LOOK.ink)
		tick:SetSize(1.2, RULER_LINE + 1 - RULER_TICK)
		centre(tick, x, RULER_TICK)
		local label = ns.BookText(ruler, faces.tick, LOOK.small)
		label:SetText(L.RULER_TICKS[i])
		-- the end labels stay within the scale
		if i == 1 then
			label:SetPoint("TOPLEFT", ruler, "TOPLEFT", x, -RULER_TICK_LABEL)
		elseif i == last then
			label:SetJustifyH("RIGHT")
			label:SetPoint("TOPRIGHT", ruler, "TOPLEFT", x, -RULER_TICK_LABEL)
		else
			label:SetJustifyH("CENTER")
			centre(label, x, RULER_TICK_LABEL)
		end
		ruler.ticks[i], ruler.tickLabels[i] = tick, label
	end
	ruler.bandLabels = {}
	---@type StatsBand[]
	local bands = { "normal", "unlucky", "veryUnlucky" }
	for i, band in ipairs(bands) do
		local label = ns.BookText(ruler, faces.band, band == "normal" and LOOK.small or LOOK.red)
		label:SetJustifyH("CENTER")
		label:SetText(ns.BookSmallCaps(ns.BandWord(band)))
		centre(label, (edges[i] + edges[i + 1]) / 2 * width, RULER_BANDS)
		ruler.bandLabels[i] = label
	end
	ruler.mark = ns.ArtSprite(ruler, "Parts", "me", "OVERLAY")
	ruler.me = ns.BookText(ruler, faces.me, LOOK.meRed)
	ruler.me:SetText(L.RULER_ME)
	ruler.owed = ns.BookText(ruler, faces.note, LOOK.small)
	ruler.owed:SetPoint("TOPLEFT", 0, -RULER_OWED)
	ruler.owed:SetWidth(width)
	ruler.owed:SetWordWrap(true)
	ruler.owed:SetText(L.NOTHING_IS_OWED)
	ruler.position = 0
	function ruler.SetRuler(self, P)
		self:SetMark(ns.RulerPosition(P))
	end
	function ruler.SetMark(self, position)
		self.position = position
		local x = self.position * width
		-- the mark's point sits on the scale's line, its tail up through the washes
		centre(self.mark, x, RULER_LINE + 3 - self.mark:GetHeight())
		self.me:ClearAllPoints()
		self.me:SetPoint("TOPLEFT", ruler, "TOPLEFT", x + 7, -(RULER_SCALE - 21))
	end
	ruler:SetRuler(1)
	return ruler
end

--- A small disc in a tint: the live line's "●" and its glow.
---@param parent Frame
---@param size number
---@param color number[]?
---@return Texture
function ns.NewBookDot(parent, size, color)
	color = color or LOOK.liveDot
	local dot = parent:CreateTexture(nil, "ARTWORK")
	dot:SetTexture(TEXTURES.disc)
	dot:SetSize(size, size)
	dot:SetVertexColor(color[1], color[2], color[3])
	return dot
end

--- A ruled ledger (stats.md › UI: This Session, Sessions), as the kit v2's: column heads in small caps over a heavy
--- rule, then one row per line ruled in faint blue, its columns parted by faint red rules down the whole ledger. A row
--- with `onClick` opens what it names; the chosen row is shaded.
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
---@field columnRules Texture[]
---@field rows StatsBookLedgerRowView[]
---@field SetRows fun(self: StatsBookLedgerView, rows: StatsBookLedgerRow[], chosen: integer?): number

-- A ledger's head and row heights.
local LEDGER_HEAD, LEDGER_ROW = 20, 24

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
	headRule:SetHeight(1.5)
	-- the red rules between the columns, down the head and every row
	ledger.columnRules = {}
	local x = 0
	for i, column in ipairs(columns) do
		if i > 1 then
			local rule = ledger:CreateTexture(nil, "BORDER")
			rule:SetColorTexture(LOOK.ledgerRed[1], LOOK.ledgerRed[2], LOOK.ledgerRed[3], LOOK.ledgerRedAlpha)
			rule:SetWidth(1)
			rule:SetPoint("TOPLEFT", x, 0)
			ledger.columnRules[#ledger.columnRules + 1] = rule
		end
		x = x + column.width
	end

	-- Row `i`, made on first use.
	local function rowAt(i)
		local row = ledger.rows[i]
		if not row then
			row = CreateFrame("Button", nil, ledger) --[[@as StatsBookLedgerRowView]]
			row:SetSize(width, LEDGER_ROW)
			row:SetPoint("TOPLEFT", 0, -(LEDGER_HEAD + (i - 1) * LEDGER_ROW))
			row.shade = ns.BookSolid(row, LOOK.shade, "BACKGROUND", LOOK.shadeAlpha)
			row.rule = row:CreateTexture(nil, "BORDER")
			row.rule:SetColorTexture(LOOK.ledgerBlue[1], LOOK.ledgerBlue[2], LOOK.ledgerBlue[3], LOOK.ledgerBlueAlpha)
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
		for _, rule in ipairs(self.columnRules) do
			rule:SetHeight(height)
		end
		return height
	end
	return ledger
end

--- A tile (stats.md › UI: the home spread's zones, an item's waters): the kit v2's paper tile (its green-edged "here"
--- tile for the place I'm in), the name at its top left, its line in italic at its foot, "I'm here" in green
--- handwriting at its top right, and a red handwritten note at its foot's right ("watching 2", "212 since"). It warms
--- slightly under the mouse; clicking it opens what it names.
---@class StatsBookTileData
---@field name string
---@field line string?
---@field here string?     -- "I'm here", when it is the current place
---@field note string?     -- red handwriting
---@field onClick fun()?

---@class StatsBookTileView: Button
---@field paper StatsSpriteTexture
---@field name FontString
---@field line FontString
---@field here FontString
---@field note FontString
---@field SetTile fun(self: StatsBookTileView, tile: StatsBookTileData)

-- The words' inset from a tile's edges.
local TILE_PAD = 11

---@param parent Frame
---@param width number
---@param height number
---@return StatsBookTileView
function ns.NewBookTile(parent, width, height)
	local tile = CreateFrame("Button", nil, parent) --[[@as StatsBookTileView]]
	tile:SetSize(width, height)
	tile.paper = ns.ArtSprite(tile, "Stats", "tile", "BACKGROUND", 2)
	local faces = ns.BookFonts()
	tile.name = ns.BookText(tile, faces.tileName, LOOK.title)
	tile.name:SetPoint("TOPLEFT", TILE_PAD, -8)
	tile.line = ns.BookText(tile, faces.tileLine, LOOK.tileLine)
	tile.line:SetPoint("BOTTOMLEFT", TILE_PAD, 10)
	tile.here = ns.BookText(tile, faces.margin, LOOK.green)
	tile.here:SetPoint("TOPRIGHT", -TILE_PAD, -6)
	tile.here:SetJustifyH("RIGHT")
	tile.note = ns.BookText(tile, faces.margin, LOOK.red)
	tile.note:SetPoint("BOTTOMRIGHT", -TILE_PAD, 8)
	tile.note:SetJustifyH("RIGHT")
	tile:SetScript("OnEnter", function(self)
		self.paper:SetVertexColor(LOOK.tileWarm[1], LOOK.tileWarm[2], LOOK.tileWarm[3])
	end)
	tile:SetScript("OnLeave", function(self)
		self.paper:SetVertexColor(1, 1, 1)
	end)
	function tile.SetTile(self, data)
		-- the kit's tile, its green-edged face for the place I'm in, stretched to the tile
		ns.SetSprite(self.paper, "Stats", data.here and "tile-here" or "tile")
		local atlas, sprite = ns.ArtSpriteOf("Stats", "tile")
		local box = sprite.box
		local kx, ky = width / box[3], height / box[4]
		self.paper:SetSize(sprite.w / atlas.scale * kx, sprite.h / atlas.scale * ky)
		self.paper:ClearAllPoints()
		self.paper:SetPoint("TOPLEFT", self, "TOPLEFT", -box[1] * kx, box[2] * ky)
		self.name:SetText(data.name)
		for _, field in ipairs({ "line", "here", "note" }) do
			local text = data[field]
			self[field]:SetText(text or "")
			self[field]:SetShown(text ~= nil)
		end
		-- every word stays on the tile: "I'm here" and the note keep their room, the name and line stop before them
		local room = width - 2 * TILE_PAD
		bound(self.here, room / 2)
		bound(self.note, room / 2)
		bound(self.name, room - (data.here and self.here:GetWidth() + 6 or 0))
		bound(self.line, room - (data.note and self.note:GetWidth() + 6 or 0))
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return tile
end

-- A quality colour this light or lighter (by its luminance; Common's white) is drawn in the paper's ink: the game's
-- colours are made for dark frames (STA-R59).
local PALE = 0.75

--- An item quality's colour on the paper (STA-R59), for a place's rows and a Session's Catches by quality alike: the
--- game's own (`ITEM_QUALITY_COLORS`), or the paper's ink for one too pale to read on it, or for no quality known
--- (an Uncharted item the client hasn't described).
---@param quality integer?
---@return number[]
function ns.BookQualityInk(quality)
	if quality == nil then
		return LOOK.ink
	end
	local r, g, b = ns.QualityColor(quality)
	if 0.299 * r + 0.587 * g + 0.114 * b >= PALE then
		return LOOK.ink
	end
	return { r, g, b }
end

--- A row on a place's page (stats.md › UI › Place spread): the item's medallion, the name in its quality's ink, the
--- kit's red ★ when watched, Your odds in short at a column ("learning {n}/100" in handwriting, "not seen yet" in the
--- note's italic ink), and in the margin, in handwriting, the Dry spell with ", unlucky" or ", very unlucky" after it
--- in red. Clicking it chooses the item; the chosen row is shaded in a dashed outline.
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
---@field dashes Texture[]
---@field icon StatsBookIconView
---@field name FontString
---@field star Texture
---@field odds FontString
---@field margin FontString
---@field band FontString
---@field SetRow fun(self: StatsBookRowView, row: StatsBookRowData)

-- A row's height, its medallion's size and place, its name's place, where the odds' column ends (from the row's
-- right), the margin's right inset, and the star's size.
local ROW_HEIGHT, ROW_ICON, ROW_ICON_X, ROW_NAME_X, ROW_ODDS_END, ROW_MARGIN_END, ROW_STAR = 25, 16, 5, 32, 140, 12, 12
-- The least room between the name (or its star) and the odds.
local ROW_NAME_GAP = 8
-- The dashed outline's dash and gap.
local DASH, DASH_GAP = 3, 2

-- A dashed outline round `frame`, `width` × `height`, in `color`: the chosen row's.
---@param frame Frame
---@param width number
---@param height number
---@param color number[]
---@return Texture[]
local function dashedOutline(frame, width, height, color)
	local dashes = {}
	local function dash(x, y, w, h)
		local texture = frame:CreateTexture(nil, "BORDER")
		texture:SetColorTexture(color[1], color[2], color[3], 1)
		texture:SetSize(w, h)
		texture:SetPoint("TOPLEFT", x, -y)
		dashes[#dashes + 1] = texture
	end
	for at = 0, width - 1, DASH + DASH_GAP do
		local w = math.min(DASH, width - at)
		dash(at, 0, w, 1)
		dash(at, height - 1, w, 1)
	end
	for at = 0, height - 1, DASH + DASH_GAP do
		local h = math.min(DASH, height - at)
		dash(0, at, 1, h)
		dash(width - 1, at, 1, h)
	end
	return dashes
end

---@param parent Frame
---@param width number
---@return StatsBookRowView
function ns.NewBookRow(parent, width)
	local row = CreateFrame("Button", nil, parent) --[[@as StatsBookRowView]]
	row:SetSize(width, ROW_HEIGHT)
	row.isBookRow = true
	row.shade = ns.BookSolid(row, LOOK.shade, "BACKGROUND", LOOK.shadeAlpha)
	row.dashes = dashedOutline(row, width, ROW_HEIGHT, LOOK.kicker)
	row.icon = ns.NewBookIcon(row, ROW_ICON)
	row.icon:SetPoint("TOPLEFT", ROW_ICON_X, -4.5)
	local faces = ns.BookFonts()
	row.name = ns.BookText(row, faces.row, LOOK.ink)
	row.name:SetPoint("TOPLEFT", ROW_NAME_X, -4)
	row.name:SetWordWrap(false)
	row.star = ns.NewBookMark(row, "star", ROW_STAR)
	row.star:SetPoint("LEFT", row.name, "RIGHT", 5, 0)
	row.odds = ns.BookText(row, faces.small, LOOK.title)
	row.odds:SetJustifyH("RIGHT")
	row.margin = ns.BookText(row, faces.margin, LOOK.margin)
	row.margin:SetJustifyH("RIGHT")
	row.band = ns.BookText(row, faces.margin, LOOK.red)
	row.band:SetPoint("TOPRIGHT", -ROW_MARGIN_END, -3)
	row.band:SetJustifyH("RIGHT")
	function row.SetRow(self, data)
		self.icon:SetIcon(data.icon)
		self.star:SetShown(data.watched)
		self.odds:SetText(data.odds)
		if data.oddsState == "learning" then
			self.odds:SetFontObject(faces.margin)
			self.odds:SetTextColor(LOOK.hand[1], LOOK.hand[2], LOOK.hand[3])
		elseif data.oddsState == "unseen" then
			self.odds:SetFontObject(faces.note)
			self.odds:SetTextColor(LOOK.note[1], LOOK.note[2], LOOK.note[3])
		else
			self.odds:SetFontObject(faces.small)
			self.odds:SetTextColor(LOOK.title[1], LOOK.title[2], LOOK.title[3])
		end
		-- "learning n/100" is long: with nothing in the margin it sits at the row's right edge, clear of the name
		local oddsEnd = (data.oddsState == "learning" and data.margin == nil) and ROW_MARGIN_END or ROW_ODDS_END
		self.odds:ClearAllPoints()
		self.odds:SetPoint("TOPRIGHT", -oddsEnd, data.oddsState == "learning" and -3 or -5)
		-- The name stops before the odds, less the star when it shows: a longer one is cut short with an ellipsis, as
		-- the client cuts a font string that doesn't wrap.
		local room = width - oddsEnd - self.odds:GetStringWidth() - ROW_NAME_GAP - ROW_NAME_X
		if data.watched then
			room = room - ROW_STAR - 5
		end
		self.name:SetText(data.name)
		self.name:SetTextColor(data.ink[1], data.ink[2], data.ink[3])
		self.name:SetWidth(math.max(1, math.min(self.name:GetStringWidth() + 1, room)))
		self.margin:SetText(data.margin or "")
		self.margin:SetShown(data.margin ~= nil)
		self.band:SetText(data.band or "")
		self.band:SetShown(data.band ~= nil)
		-- the Dry spell keeps to the margin, right of the odds' column
		local margin = ROW_ODDS_END - ROW_MARGIN_END - ROW_NAME_GAP
		bound(self.band, margin)
		bound(self.margin, margin - (data.band and self.band:GetWidth() or 0))
		self.margin:ClearAllPoints()
		if data.band then
			self.margin:SetPoint("TOPRIGHT", self.band, "TOPLEFT", 0, 0)
		else
			self.margin:SetPoint("TOPRIGHT", -ROW_MARGIN_END, -3)
		end
		self.shade:SetShown(data.chosen)
		for _, dash in ipairs(self.dashes) do
			dash:SetShown(data.chosen)
		end
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
	line.here = ns.BookText(line, faces.margin, LOOK.green)
	line.here:SetPoint("LEFT", line.label, "RIGHT", 8, 0)
	line.value = ns.BookText(line, faces.text, LOOK.small)
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
		-- the label, and "I'm here" after it, stop before the value
		bound(self.value, width)
		local room = width - self.value:GetWidth() - 8
		bound(self.here, data.here and room / 2 or 1)
		bound(self.label, room - (data.here and self.here:GetWidth() + 8 or 0))
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return line
end

--- A figure line (stats.md › UI: In this book, the Lifetime figures, a Session's figures): its label at the left, its
--- value at the right and a dotted leader between them, as the kit v2's table of contents. With `onClick` it opens
--- what it names, and its label reddens under the mouse.
---@class StatsBookFigureData
---@field label string
---@field value string?        -- none: no value and no leader
---@field ink number[]?        -- the label's ink, ns.BOOK_LOOK.ink by default
---@field valueInk number[]?   -- the value's ink, ns.BOOK_LOOK.ink by default
---@field onClick fun()?

---@class StatsBookFigureView: Button
---@field label FontString
---@field value FontString
---@field leader StatsBookDotsView
---@field ink number[]         -- the label's ink when the mouse leaves
---@field SetFigure fun(self: StatsBookFigureView, figure: StatsBookFigureData)

-- The leader's opacity, how far above the line's foot it runs, and its dots' pitch.
local LEADER_ALPHA, LEADER_RISE, LEADER_STEP = 0.8, 4, 3

--- A dotted leader: 1-unit dots a few units apart along a line, as the kit draws its tables of contents and index.
---@class StatsBookDotsView: Frame
---@field dots Texture[]
---@field SetDots fun(self: StatsBookDotsView, from: number, to: number, y: number)

--- A dotted leader on `parent` in `color` at `alpha`: SetDots lays its dots from `from` to `to` across `parent`, `y`
--- above its foot.
---@param parent Frame
---@param color number[]
---@param alpha number
---@return StatsBookDotsView
function ns.NewBookDots(parent, color, alpha)
	local leader = CreateFrame("Frame", nil, parent) --[[@as StatsBookDotsView]]
	leader:SetAllPoints()
	leader.dots = {}
	function leader.SetDots(self, from, to, y)
		local count = math.max(0, math.floor((to - from) / LEADER_STEP) + 1)
		if to - from < LEADER_STEP then
			count = 0
		end
		for i = 1, count do
			local dot = self.dots[i]
			if not dot then
				dot = self:CreateTexture(nil, "ARTWORK")
				dot:SetColorTexture(color[1], color[2], color[3], alpha)
				dot:SetSize(1, 1)
				self.dots[i] = dot
			end
			dot:ClearAllPoints()
			dot:SetPoint("BOTTOMLEFT", from + (i - 1) * LEADER_STEP, y)
			dot:Show()
		end
		for i = count + 1, #self.dots do
			self.dots[i]:Hide()
		end
	end
	return leader
end

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
	figure.leader = ns.NewBookDots(figure, LOOK.note, LEADER_ALPHA)
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
		-- the label stops before the value, the dots running between them
		bound(self.value, width)
		bound(self.label, width - (data.value and self.value:GetWidth() + 12 or 0))
		self.leader:SetDots(
			self.label:GetWidth() + 6,
			width - self.value:GetWidth() - 6,
			math.floor((height - 14) / 2) + LEADER_RISE - 2
		)
		local onClick = data.onClick
		self:SetScript("OnClick", onClick and function()
			onClick()
		end or nil)
	end
	return figure
end

--- An item's name under a kicker (stats.md › UI: an entry, the item page): its medallion in the kit's silver ring, then
--- its name as the page's title beside it. The name is "Item {id}" until the client has it; the book asks for it and
--- redraws when it arrives (adapter/Book.lua's Book:Item, STA-R73).
---@class StatsBookItemTitleView
---@field icon StatsBookIconView
---@field title FontString
---@field SetItem fun(self: StatsBookItemTitleView, itemID: integer, y: number)

-- The medallion's size and place, and the name's place beside it.
local ITEM_ICON, ITEM_ICON_X, ITEM_NAME_X = 34, 3, 50

---@param parent Frame
---@param width number
---@return StatsBookItemTitleView
function ns.NewBookItemTitle(parent, width)
	local view =
		{ icon = ns.NewBookIcon(parent, ITEM_ICON), title = ns.BookText(parent, ns.BookFonts().itemTitle, LOOK.title) }
	view.title:SetWidth(width - ITEM_NAME_X)
	view.title:SetWordWrap(false)
	function view.SetItem(self, itemID, y)
		local name, icon = ns.book:Item(itemID)
		self.icon:SetIcon(icon)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("TOPLEFT", ITEM_ICON_X, -y)
		self.icon:Show()
		self.title:SetText(name)
		self.title:ClearAllPoints()
		self.title:SetPoint("TOPLEFT", ITEM_NAME_X, -(y + 4))
		self.title:Show()
	end
	return view
end

--- Tiles two a row (stats.md › UI: the home spread's zones, an item's waters), each opening its target: ns.NewBookTile
--- with the kit v2's height and gap, made as the rows need them, the ones left over hidden.
---@class StatsBookTileGridView
---@field tiles StatsBookTileView[]
---@field SetTiles fun(self: StatsBookTileGridView, tiles: StatsTile[], y: number): number

-- A tile's height and the gap between tiles, across and down: the kit v2's 66, on a 74 pitch.
local TILE_HEIGHT, TILE_GAP = 66, 8

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

-- The leather's measures: the band's corner (16 units, 32 texels), how far in the tiled grain starts (under the
-- band's opaque lines), and one repeat of the grain (Leather.blp is 256 texels, 128 units).
local BAND, FILL_INSET, LEATHER_TILE = 16, 7, 128

--- The leather on `frame`, filling it: the kit's grain tiled under a vignette, darker toward the foot, and the binding
--- band round it on its own frame, above the ribbons so their tucked tops hide under it.
---@class StatsBookLeatherView
---@field fill Texture
---@field vignette Texture
---@field band Frame
---@field bandPieces table<string, Texture>

---@param frame Frame
---@return StatsBookLeatherView
function ns.NewBookLeather(frame)
	local fill = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, 0))
	fill:SetTexture(ns.BOOK_FILES.leather, "REPEAT", "REPEAT")
	fill:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
	fill:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
	-- darker toward the foot, as the canvas shades it (the gradient's first colour is the bottom's)
	fill:SetGradient("VERTICAL", CreateColor(0.8, 0.8, 0.8, 1), CreateColor(1, 1, 1, 1))
	local width, height = frame:GetSize()
	fill:SetTexCoord(0, (width - 2 * FILL_INSET) / LEATHER_TILE, 0, (height - 2 * FILL_INSET) / LEATHER_TILE)
	local vignette = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, 1))
	local atlas, sprite = ns.ArtSpriteOf("Book", "vignette")
	ns.ArtCut(vignette, atlas, sprite.x + 1, sprite.y + 1, sprite.w - 2, sprite.h - 2)
	vignette:SetAllPoints(fill)
	local band = CreateFrame("Frame", nil, frame)
	band:SetAllPoints()
	band:SetFrameLevel(frame:GetFrameLevel() + 6)
	-- The band's nine slices from the 96-texel binding sprite: 32-texel corners, the edges stretched from a 2-texel
	-- slice.
	local binding, bindingSprite = ns.ArtSpriteOf("Book", "binding")
	local pieces = {}
	local function piece(key, sx, sy, sw, sh)
		local texture = ns.ArtCrisp(band:CreateTexture(nil, "BORDER"))
		ns.ArtCut(texture, binding, bindingSprite.x + sx, bindingSprite.y + sy, sw, sh)
		pieces[key] = texture
		return texture
	end
	local tl, tr = piece("TL", 0, 0, 32, 32), piece("TR", 64, 0, 32, 32)
	local bl, br = piece("BL", 0, 64, 32, 32), piece("BR", 64, 64, 32, 32)
	for _, corner in ipairs({ tl, tr, bl, br }) do
		corner:SetSize(BAND, BAND)
	end
	tl:SetPoint("TOPLEFT")
	tr:SetPoint("TOPRIGHT")
	bl:SetPoint("BOTTOMLEFT")
	br:SetPoint("BOTTOMRIGHT")
	local top, bottom = piece("T", 47, 0, 2, 32), piece("B", 47, 64, 2, 32)
	local left, right = piece("L", 0, 47, 32, 2), piece("R", 64, 47, 32, 2)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
	top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	return { fill = fill, vignette = vignette, band = band, bandPieces = pieces }
end

--- The brass corners on the book's four corners, over the band: one sprite, mirrored by its texture coordinates.
---@param frame Frame
---@return Texture[] corners top left, top right, bottom left, bottom right
function ns.NewBookCorners(frame)
	local over = CreateFrame("Frame", nil, frame)
	over:SetAllPoints()
	over:SetFrameLevel(frame:GetFrameLevel() + 8)
	local atlas, sprite = ns.ArtSpriteOf("Parts", "corner")
	local left, right = sprite.x / atlas.width, (sprite.x + sprite.w) / atlas.width
	local top, bottom = sprite.y / atlas.height, (sprite.y + sprite.h) / atlas.height
	local corners = {}
	for i, spot in ipairs({
		{ "TOPLEFT", -3, 3, left, right, top, bottom },
		{ "TOPRIGHT", 3, 3, right, left, top, bottom },
		{ "BOTTOMLEFT", -3, -3, left, right, bottom, top },
		{ "BOTTOMRIGHT", 3, -3, right, left, bottom, top },
	}) do
		local corner = ns.ArtCrisp(over:CreateTexture(nil, "OVERLAY"))
		corner:SetTexture(atlas.file)
		corner:SetTexCoord(spot[4], spot[5], spot[6], spot[7])
		corner:SetSize(sprite.w / atlas.scale, sprite.h / atlas.scale)
		corner:SetPoint(spot[1], frame, spot[1], spot[2], spot[3])
		corners[i] = corner
	end
	return corners
end

--- A parchment page on `frame`, filling it: the kit's parchment (mirrored on a right page, so the two don't match) and
--- the gutter's shade along the side `spine` names.
---@class StatsBookParchmentView
---@field paper Texture
---@field gutter Texture?
---@field corners MaskTexture[]   -- the rounded outer corners

-- The gutter's width at the spine.
local GUTTER_WIDTH = 40

---@param frame Frame
---@param spine "LEFT"|"RIGHT"|nil
---@return StatsBookParchmentView
function ns.NewBookParchment(frame, spine)
	local view = {}
	view.paper = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND"))
	view.paper:SetTexture(ns.BOOK_FILES.parchment)
	view.paper:SetAllPoints()
	if spine == "LEFT" then
		view.paper:SetTexCoord(1, 0, 0, 1)
	end
	-- its outer corners slightly rounded, the corners at the spine square, as a bound page is
	local outer = spine == "RIGHT" and { "TOPLEFT", "BOTTOMLEFT" }
		or spine == "LEFT" and { "TOPRIGHT", "BOTTOMRIGHT" }
		or { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
	view.corners = ns.RoundCorners(view.paper, frame, outer)
	if spine then
		local atlas, sprite = ns.ArtSpriteOf("Book", "gutter")
		local gutter = ns.ArtCrisp(frame:CreateTexture(nil, "BORDER"))
		local left, right = (sprite.x + 1) / atlas.width, (sprite.x + sprite.w - 1) / atlas.width
		local top, bottom = (sprite.y + 1) / atlas.height, (sprite.y + sprite.h - 1) / atlas.height
		gutter:SetTexture(atlas.file)
		if spine == "LEFT" then
			gutter:SetTexCoord(right, left, top, bottom)
		else
			gutter:SetTexCoord(left, right, top, bottom)
		end
		gutter:SetWidth(GUTTER_WIDTH)
		gutter:SetPoint("TOP" .. spine)
		gutter:SetPoint("BOTTOM" .. spine)
		view.gutter = gutter
	end
	return view
end

--- The wax close button: a round seal of red wax with a cross, pressed when clicked, glowing under the mouse.
---@class StatsBookCloseButton: Button
---@field normal Texture
---@field pushed Texture
---@field glow Texture

---@param parent Frame
---@return StatsBookCloseButton
function ns.NewBookClose(parent)
	local close = CreateFrame("Button", nil, parent) --[[@as StatsBookCloseButton]]
	close:SetSize(26, 26)
	close.normal = ns.ArtSprite(close, "Book", "close", "ARTWORK", 0, 26)
	close.normal:SetAllPoints()
	close.pushed = ns.ArtSprite(close, "Book", "close-pushed", "ARTWORK", 1, 26)
	close.pushed:SetAllPoints()
	close.pushed:Hide()
	close.glow = ns.ArtSprite(close, "Book", "close-highlight", "HIGHLIGHT", 0, 26)
	close.glow:SetAllPoints()
	close.glow:SetBlendMode("ADD")
	close:SetScript("OnMouseDown", function(self)
		self.pushed:Show()
	end)
	close:SetScript("OnMouseUp", function(self)
		self.pushed:Hide()
	end)
	return close
end

--- The "?" beside the close (ONB-R59), in the book's own wax: the plain seal of red wax at the close's size with a
--- gilt "?" pressed into it, the close's glow under the mouse, the wax darker while pressed; and its tooltip on the
--- book's dark slip (the Lifetime index's), under it. Its click is the book's (adapter/Book.lua).
---@class StatsBookHelpTip: Frame
---@field slip StatsThreeSlice
---@field text FontString

---@class StatsBookHelpButton: Button
---@field wax Texture
---@field glow Texture
---@field label FontString
---@field tip StatsBookHelpTip

-- The "?"'s size (the close's), its tooltip slip's height, end caps and padding, and how far under the "?" it hangs.
local HELP_SIZE, HELP_TIP_HEIGHT, HELP_TIP_CAP, HELP_TIP_PAD, HELP_TIP_DROP = 26, 33, 10, 12, 4
-- The wax's shade while pressed.
local HELP_PRESSED = 0.78

---@param parent Frame
---@param tooltip string the tooltip's words
---@return StatsBookHelpButton
function ns.NewBookHelp(parent, tooltip)
	local help = CreateFrame("Button", nil, parent) --[[@as StatsBookHelpButton]]
	help:SetSize(HELP_SIZE, HELP_SIZE)
	help.wax = ns.ArtSprite(help, "Book", "seal", "ARTWORK", 0, HELP_SIZE)
	help.wax:SetAllPoints()
	help.label = ns.BookText(help, ns.ArtFont("gilt", 17, true), LOOK.wax)
	help.label:SetJustifyH("CENTER")
	help.label:SetPoint("CENTER", 0, 1)
	help.label:SetText(ns.L.LOOK_HELP)
	help.glow = ns.ArtSprite(help, "Book", "close-highlight", "HIGHLIGHT", 0, HELP_SIZE)
	help.glow:SetAllPoints()
	help.glow:SetBlendMode("ADD")

	local tip = CreateFrame("Frame", nil, parent) --[[@as StatsBookHelpTip]]
	tip:SetFrameLevel(help:GetFrameLevel() + 20)
	tip.slip = CreateFrame("Frame", nil, tip) --[[@as StatsThreeSlice]]
	tip.slip:SetPoint("TOPLEFT")
	-- on the slip's own frame, which draws over the tip's: the words over the paper
	tip.text = ns.BookText(tip.slip, ns.BookFonts().tip, LOOK.tipText)
	tip.text:SetWordWrap(false)
	tip.text:SetPoint("LEFT", tip, "LEFT", HELP_TIP_PAD, 0)
	tip.text:SetText(tooltip)
	tip:Hide()
	help.tip = tip

	help:SetScript("OnMouseDown", function(self)
		self.wax:SetVertexColor(HELP_PRESSED, HELP_PRESSED, HELP_PRESSED)
	end)
	help:SetScript("OnMouseUp", function(self)
		self.wax:SetVertexColor(1, 1, 1)
	end)
	help:SetScript("OnEnter", function(self)
		local width = math.ceil(tip.text:GetStringWidth()) + 2 * HELP_TIP_PAD
		ns.SetThreeSlice(tip.slip, "Stats", "tip", width, HELP_TIP_CAP, "BACKGROUND")
		tip:SetSize(width, HELP_TIP_HEIGHT)
		tip:ClearAllPoints()
		tip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -HELP_TIP_DROP)
		tip:SetFrameLevel(self:GetFrameLevel() + 20)
		tip:Show()
	end)
	help:SetScript("OnLeave", function()
		tip:Hide()
	end)
	return help
end

--- A grosgrain ribbon (STA-R74): one white ribbon tinted to its colour, with a gold running stitch over it, hanging
--- from under the leather's foot, its words in gilt near its swallowtail end; the chosen one hangs longer and brighter,
--- and one under the mouse brightens.
---@class StatsBookRibbonView: Button
---@field body Texture
---@field stitch Texture
---@field label FontString
---@field chosen boolean
---@field hover boolean
---@field color number[]
---@field length number           -- how long it hangs now: eased toward its choice's length
---@field SetRibbon fun(self: StatsBookRibbonView, text: string, color: number[], chosen: boolean, animate: boolean?)

--- The ribbons' measures (the kit's Stats book, hanging a fifth shorter, as the dev asked): each one's width and the
--- gap between, how long it hangs (longer chosen), how much of its top tucks under the leather's band, how much
--- brighter it turns, and how long a change of choice takes to run its lengths (the kit v2's 0.2 s).
ns.BOOK_RIBBON = { width = 96, gap = 12, length = 75, lengthChosen = 86, tuck = 2, lift = 1.13, ease = 0.2 }
local RIBBON = ns.BOOK_RIBBON

-- Shows the bottom `length` units of ribbon sprite `name` (its swallowtail end always shows) in `texture`, the
-- ribbon's width across, from `ribbon`'s top left.
---@param texture Texture
---@param ribbon Frame
---@param name string
---@param length number
local function hang(texture, ribbon, name, length)
	local atlas, sprite = ns.ArtSpriteOf("Parts", name)
	local box = sprite.box
	local k = RIBBON.width / box[3]
	local dropped = (box[4] - length) * atlas.scale
	ns.ArtCut(texture, atlas, sprite.x, sprite.y + dropped, sprite.w, sprite.h - dropped)
	texture:SetSize(sprite.w / atlas.scale * k, sprite.h / atlas.scale - box[4] + length)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", ribbon, "TOPLEFT", -box[1] * k, 0)
end

-- Hangs a ribbon `length` long.
---@param ribbon StatsBookRibbonView
---@param length number
local function hangRibbon(ribbon, length)
	ribbon.length = length
	ribbon:SetSize(RIBBON.width, length)
	hang(ribbon.body, ribbon, "ribbon", length)
	hang(ribbon.stitch, ribbon, "ribbon-stitch", length)
end

-- Paints a ribbon as it is now: its tint (brighter chosen or under the mouse) and its words' ink.
---@param ribbon StatsBookRibbonView
local function paintRibbon(ribbon)
	local lift = (ribbon.chosen or ribbon.hover) and RIBBON.lift or 1
	local color = ribbon.color
	ribbon.body:SetVertexColor(math.min(1, color[1] * lift), math.min(1, color[2] * lift), math.min(1, color[3] * lift))
	local ink = ribbon.chosen and LOOK.ribbonLabelOn or LOOK.ribbonLabel
	ribbon.label:SetTextColor(ink[1], ink[2], ink[3])
end

---@param parent Frame
---@return StatsBookRibbonView
function ns.NewBookRibbon(parent)
	local ribbon = CreateFrame("Button", nil, parent) --[[@as StatsBookRibbonView]]
	ribbon.body = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK", nil, 0))
	ribbon.stitch = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK", nil, 1))
	ribbon.label = ns.BookText(ribbon, ns.BookFonts().ribbon, LOOK.ribbonLabel)
	ribbon.label:SetJustifyH("CENTER")
	ribbon.label:SetWordWrap(false)
	ribbon.label:SetPoint("BOTTOM", ribbon, "BOTTOM", 0, 31)
	ribbon.chosen, ribbon.hover, ribbon.color = false, false, LOOK.ribbons.session
	ribbon:SetScript("OnEnter", function(self)
		self.hover = true
		paintRibbon(self)
	end)
	ribbon:SetScript("OnLeave", function(self)
		self.hover = false
		paintRibbon(self)
	end)
	hangRibbon(ribbon, RIBBON.length)
	function ribbon.SetRibbon(self, text, color, chosen, animate)
		self.label:SetText(text)
		self.color, self.chosen = color, chosen
		paintRibbon(self)
		-- the kit's Ribbons.lua: a change of choice runs the lengths over 0.2 s (ease-out), so the old one draws up as
		-- the new one drops; settled at once with the motion off
		local to = chosen and RIBBON.lengthChosen or RIBBON.length
		Pagle.StopMotion(self)
		if animate and to ~= self.length and ns.MotionOn() then
			Pagle.Animate(self, {
				{
					dur = RIBBON.ease,
					ease = Pagle.EASE.out,
					keys = { { 0, { self.length } }, { 1, { to } } },
					apply = function(v)
						hangRibbon(self, v[1])
					end,
				},
			})
		else
			hangRibbon(self, to)
		end
	end
	return ribbon
end

--- The brass nameplate on the leather (stats.md › UI › On the leather): the kit's brass plate, three-sliced to its
--- words.
---@class StatsBookPlateView: Frame
---@field brass StatsThreeSlice
---@field label FontString
---@field SetPlate fun(self: StatsBookPlateView, text: string)

-- The plate's end caps, and the room its words leave.
local PLATE_CAP, PLATE_ROOM = 8, 22

---@param parent Frame
---@return StatsBookPlateView
function ns.NewBookPlate(parent)
	local plate = CreateFrame("Frame", nil, parent) --[[@as StatsBookPlateView]]
	plate.brass = CreateFrame("Frame", nil, plate) --[[@as StatsThreeSlice]]
	plate.brass:SetPoint("TOPLEFT")
	-- on the brass's own frame, which draws over the plate's: its words over its slices
	plate.label = ns.BookText(plate.brass, ns.BookFonts().plate, LOOK.plateText)
	plate.label:SetPoint("CENTER", plate, "CENTER", 0, 1)
	function plate.SetPlate(self, text)
		self.label:SetText(text)
		local width = math.ceil(self.label:GetStringWidth()) + PLATE_ROOM
		ns.SetThreeSlice(self.brass, "Book", "plate", width, PLATE_CAP, "ARTWORK")
		self:SetSize(width, self.brass:GetHeight())
	end
	return plate
end
