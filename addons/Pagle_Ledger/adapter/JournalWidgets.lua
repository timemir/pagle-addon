if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's look and its shared widgets (ledger.md › UI, LED-R4's M3 stage): the Field Leather tints, the
-- serif and handwriting font objects, and one widget per kind of LedgerBlock (logic/Journal.lua), drawn down a page.
-- In-client textures and fonts only; custom art comes after 1.0. Every texture sits on a solid tint, so a texture
-- the client lacks leaves the tint showing.

-- A tint from its hex code, as the prototype's CSS writes it (logic/Bindings.lua).
local tint = ns.HexTint

--- The Field Leather look (LED-R4, LED-R110's default binding), its tints picked against
--- prototypes/fish-journal/ variant E (its book is variant C's): leather, gilt and page paper, and the inks drawn
--- on the paper. Where the prototype shades a gradient, the tint is a colour between its ends.
ns.JOURNAL_LOOK = {
	leather = tint("4e2c16"), -- between the cover's #6a3e20 and #3a2010
	leatherEdge = tint("120a04"), -- the book's dark outline
	gilt = tint("e8c96a"), -- the breadcrumbs
	giltRule = tint("8a5a2a"), -- the gilt rule inside the leather's edge
	paper = tint("ead6ac"), -- between the page's #f3e5c3 and #dfc89a
	spine = tint("46280a"), -- rgba(70,40,10,.65): the shadow at the spine
	ink = tint("3a2614"), -- printed text
	title = tint("3e220c"), -- titles and zone names
	kicker = tint("8a5a2a"), -- kickers, tile lines, the leaders' dots
	faded = tint("9a8060"), -- what is unknown or unfished
	red = tint("9a2a1a"), -- notes, links, inked stamps
	blue = tint("23407a"), -- handwriting and Fresh Water
	barInk = tint("5a3a14"), -- the ink bars
	seal = tint("a82a1a"), -- between the seal's #d0402a and #7a1810
	sealText = tint("f4dfa8"), -- a seal's words
	stampOff = tint("b8a080"), -- a stamp not yet inked
	sepia = tint("dcb37a"), -- an icon's tint over its greys (CSS sepia(.6))
	brass = tint("c19e45"), -- the brass plate: between its #e8c96a and #9a7420
	brassEdge = tint("4a3008"), -- the brass plate's outline
	brassText = tint("2a1a04"), -- its words
}
local LOOK = ns.JOURNAL_LOOK
-- A silhouette's ink: black (LED-R124).
local SILHOUETTE = { 0, 0, 0 }

--- In-client textures (ledger.md › UI): the leather's grain, the page paper and the seal's disc.
ns.JOURNAL_TEXTURES = {
	leather = "Interface\\FrameGeneral\\UI-Background-Rock",
	paper = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
}

-- The serif text face and the handwriting face (ledger.md › UI): in-client fonts.
local SERIF = "Fonts\\FRIZQT__.TTF"
local HAND = "Fonts\\MORPHEUS.TTF"

-- `|cffRRGGBB` for a tint, for text drawn in two colours.
---@param color number[]
---@return string
local function colorCode(color)
	local function byte(value)
		return math.floor(value * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(byte(color[1]), byte(color[2]), byte(color[3]))
end

--- The Journal's font objects, made on first use: printed text in the serif face, notes in the handwriting face.
---@class LedgerJournalFonts
---@field text Font
---@field small Font
---@field kicker Font
---@field title Font
---@field hand Font
---@field crumb Font
---@field seal Font
---@field numeral Font -- the bookplate's level (LED-R132)
---@field plate Font   -- the brass plate (LED-R149)
local fonts

---@return LedgerJournalFonts
function ns.JournalFonts()
	if not fonts then
		local function font(name, file, size)
			local object = CreateFont("PagleLedgerJournal" .. name)
			object:SetFont(file, size, "")
			return object
		end
		fonts = {
			text = font("Text", SERIF, 13),
			small = font("Small", SERIF, 11),
			kicker = font("Kicker", SERIF, 11),
			title = font("Title", HAND, 24),
			hand = font("Hand", HAND, 16),
			crumb = font("Crumb", SERIF, 13),
			seal = font("Seal", SERIF, 10),
			numeral = font("Numeral", SERIF, 40),
			plate = font("Plate", SERIF, 12),
		}
	end
	return fonts
end

--- Paints `texture` a solid tint: `color` ({ r, g, b }, as ns.JOURNAL_LOOK holds them) at `alpha`, 1 when nil. Text and
--- vertex colours take a tint whole, as `SetTextColor(unpack(color))`.
---@param texture Texture
---@param color number[]
---@param alpha number?
function ns.JournalPaint(texture, color, alpha)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

--- A solid tint filling `frame`, or the part its points give.
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@param alpha number?
---@return Texture
function ns.JournalSolid(frame, color, layer, alpha)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	ns.JournalPaint(texture, color, alpha)
	texture:SetAllPoints()
	return texture
end

--- Four thin rules boxing `frame`'s inside, `inset` in from its edges, untinted: the cover's and a binding swatch's
--- gilt rules, a Legend plate's double rule and the shown rung's box. `options`, each optional: `left`, the inset from
--- the left edge (more at a book's spine; `inset` by default), `thickness` (1) and `layer` ("BORDER"). Top, bottom,
--- left, right.
---@param frame Frame
---@param inset number
---@param options { left: number?, thickness: number?, layer: DrawLayer? }?
---@return Texture[]
function ns.JournalRules(frame, inset, options)
	options = options or {}
	local left, thickness = options.left or inset, options.thickness or 1
	local rules = {}
	for i, side in ipairs({
		{ "TOPLEFT", left, -inset, "TOPRIGHT", -inset, -inset },
		{ "BOTTOMLEFT", left, inset, "BOTTOMRIGHT", -inset, inset },
		{ "TOPLEFT", left, -inset, "BOTTOMLEFT", left, inset },
		{ "TOPRIGHT", -inset, -inset, "BOTTOMRIGHT", -inset, inset },
	}) do
		local rule = frame:CreateTexture(nil, options.layer or "BORDER")
		rule:SetPoint(side[1], side[2], side[3])
		rule:SetPoint(side[4], side[5], side[6])
		if i <= 2 then
			rule:SetHeight(thickness)
		else
			rule:SetWidth(thickness)
		end
		rules[i] = rule
	end
	return rules
end

--- A leather cover (LED-R110): the Journal's, and each binding's closed-book swatch in the Curio Shop.
---@class LedgerJournalCover: Frame
---@field leather Texture   -- the leather's tint, and its grain over it (LED-R112)
---@field grain Texture
---@field rules Texture[]   -- the gilt rules inside the leather's edge

--- Covers `frame` in leather: the dark outline, the leather `border` in from the edges with its grain at half alpha
--- over it, and the gilt rules (ns.JournalRules, `inset` and `left`), in the Field Leather tints until
--- ns.TintJournalCover tints them in a binding's look.
---@param frame LedgerJournalCover
---@param border number
---@param inset number
---@param left number?
function ns.DrawJournalCover(frame, border, inset, left)
	ns.JournalSolid(frame, LOOK.leatherEdge, "BACKGROUND")
	frame.leather = ns.JournalSolid(frame, LOOK.leather, "BACKGROUND")
	frame.grain = frame:CreateTexture(nil, "BORDER")
	frame.grain:SetTexture(ns.JOURNAL_TEXTURES.leather)
	frame.grain:SetAlpha(0.5)
	for _, texture in ipairs({ frame.leather, frame.grain }) do
		texture:SetPoint("TOPLEFT", border, -border)
		texture:SetPoint("BOTTOMRIGHT", -border, border)
	end
	-- Over the grain, which shares its layer.
	frame.rules = ns.JournalRules(frame, inset, { left = left, layer = "ARTWORK" })
end

--- Tints a cover in binding `look` (LED-R110, LED-R112): the leather and its grain, and the rules in `rule` at
--- `alpha` (1 when nil).
---@param frame LedgerJournalCover
---@param look LedgerBindingLook
---@param rule number[]
---@param alpha number?
function ns.TintJournalCover(frame, look, rule, alpha)
	ns.JournalPaint(frame.leather, look.leather)
	frame.grain:SetVertexColor(unpack(look.leather))
	for _, line in ipairs(frame.rules) do
		ns.JournalPaint(line, rule, alpha)
	end
end

--- A font string on `frame` in one of the Journal's fonts and tints.
---@param frame Frame
---@param font Font
---@param color number[]
---@return FontString
function ns.JournalText(frame, font, color)
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(font)
	text:SetTextColor(unpack(color))
	text:SetJustifyH("LEFT")
	return text
end

--- Shows `icon` on `texture` (LED-R124, ledger.md › UI): an item ID's icon, or a texture, in greys tinted sepia, or
--- solid black as the silhouette of what isn't caught. Every widget that draws an item icon draws it here.
---@param texture Texture
---@param icon integer|string? an item ID or a texture
---@param look "sepia"|"silhouette"?
function ns.JournalItemIcon(texture, icon, look)
	if type(icon) == "number" then
		local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
		icon = fileID or icon
	end
	texture:SetTexture(icon)
	texture:SetDesaturated(true)
	local ink = look == "silhouette" and SILHOUETTE or LOOK.sepia
	texture:SetVertexColor(unpack(ink))
	texture:SetAlpha(1)
end

--- A button that opens a place in the Journal (LED-R125): whoever fills it sets `place` and `open`, the Journal's
--- opener, or `action` to call instead (a link to the Field report, REP-R43).
---@class LedgerJournalClickable: Button
---@field place LedgerJournalPlace?
---@field open fun(place: LedgerJournalPlace)?
---@field action fun()?

--- Makes `button` take clicks as a LedgerJournalClickable: it calls its `action`, or opens its `place`, or with
--- neither does nothing.
---@param button LedgerJournalClickable
function ns.JournalClickable(button)
	---@param self LedgerJournalClickable
	button:SetScript("OnClick", function(self)
		if self.action then
			self.action()
		elseif self.place and self.open then
			self.open(self.place)
		end
	end)
end

--- A widget drawing one kind of block: `Fill` draws the block across `width` and returns the height it takes;
--- `open` opens a place in the Journal. The kinds that open a place take clicks (ns.JournalClickable).
---@class LedgerJournalWidget: LedgerJournalClickable
---@field Fill fun(self: LedgerJournalWidget, block: LedgerBlock, width: number, open: fun(place: LedgerJournalPlace)): number
---@field label FontString?
---@field texture Texture?

-- A widget on `parent`: a Button, so the kinds that open a place take clicks.
---@param parent Frame
---@return LedgerJournalWidget
local function newWidget(parent)
	return CreateFrame("Button", nil, parent) --[[@as LedgerJournalWidget]]
end

-- A one-text widget in `font` and `color`, wrapping across the width.
---@param font fun(): Font
---@param color fun(block: LedgerBlock): number[]
---@return fun(parent: Frame): LedgerJournalWidget
local function textWidget(font, color)
	return function(parent)
		local widget = newWidget(parent)
		local text = ns.JournalText(widget, font(), LOOK.ink)
		text:SetPoint("TOPLEFT")
		text:SetWordWrap(true)
		widget.label = text
		function widget.Fill(_, block, width)
			local ink = color(block)
			text:SetFontObject(block.hand and ns.JournalFonts().hand or font())
			text:SetTextColor(unpack(ink))
			text:SetWidth(width)
			text:SetText(block.text)
			return text:GetStringHeight()
		end
		return widget
	end
end

-- The inks a text block can ask for.
local TEXT_COLORS = { faded = LOOK.faded, red = LOOK.red, blue = LOOK.blue }

-- A row of dots from a dotted-leader line's label to its value.
local LEADER_DOTS = 80
local LEADER_DOT_STEP = 5

-- The ink XP bar's height.
local BAR_HEIGHT = 12

-- A seal's diameter on a page, and on a zone tile.
local SEAL_SIZE = 64
local TILE_SEAL_SIZE = 26

-- An icon's size on a page, and a large one's (a Species' entry, LED-R140).
local ICON_SIZE, LARGE_ICON_SIZE = 40, 80

-- Zone tiles: three across, with a gap.
local TILE_COLUMNS = 3
local TILE_HEIGHT = 74
local TILE_GAP = 8

-- Tabs: their height, and the gap between them.
local TAB_HEIGHT = 18
local TAB_GAP = 14

-- A disc in `color`: a seal's wax.
---@param frame Frame
---@param size number
---@return Texture
local function disc(frame, size)
	local texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(ns.JOURNAL_TEXTURES.disc)
	texture:SetVertexColor(unpack(LOOK.seal))
	texture:SetSize(size, size)
	return texture
end

-- A thin ink bar's frame: its outline and its fill, `fill` 0 to 1 of `width`.
---@class LedgerInkBarView
---@field fill Texture
---@field Set fun(self: LedgerInkBarView, fill: number, width: number)

---@param frame Frame
---@param height number
---@return LedgerInkBarView
local function inkBar(frame, height)
	local outline = frame:CreateTexture(nil, "BORDER")
	ns.JournalPaint(outline, LOOK.barInk, 0.25)
	outline:SetPoint("TOPLEFT")
	outline:SetPoint("TOPRIGHT")
	outline:SetHeight(height)
	local fill = frame:CreateTexture(nil, "ARTWORK")
	ns.JournalPaint(fill, LOOK.barInk)
	fill:SetPoint("TOPLEFT")
	fill:SetHeight(height)
	return {
		fill = fill,
		Set = function(_, value, width)
			fill:SetWidth(math.max(1, value * width))
			fill:SetShown(value > 0)
		end,
	}
end

--- Each block kind's widget maker (logic/Journal.lua's LedgerBlock).
---@type table<string, fun(parent: Frame): LedgerJournalWidget>
local makers = {}

--- Registers `maker` as the widget of block kind `kind`: a spread's own adapter file adds the kinds only it draws.
---@param kind string
---@param maker fun(parent: Frame): LedgerJournalWidget
function ns.RegisterJournalWidget(kind, maker)
	makers[kind] = maker
end

makers.kicker = textWidget(function()
	return ns.JournalFonts().kicker
end, function()
	return LOOK.kicker
end)

makers.title = textWidget(function()
	return ns.JournalFonts().title
end, function()
	return LOOK.title
end)

makers.text = textWidget(function()
	return ns.JournalFonts().text
end, function(block)
	return TEXT_COLORS[block.color] or (block.hand and LOOK.blue) or LOOK.ink
end)

-- A link: red ink, or in handwriting blue ink (Notes to self, LED-R133), wrapping across the width, opening its place,
-- or calling its action instead (the Field report, REP-R43).
function makers.link(parent)
	local widget = newWidget(parent)
	local text = ns.JournalText(widget, ns.JournalFonts().text, LOOK.red)
	text:SetPoint("TOPLEFT")
	text:SetWordWrap(true)
	widget.label = text
	ns.JournalClickable(widget)
	function widget.Fill(_, block, width, open)
		widget.place, widget.action, widget.open = block.place, block.action, open
		local ink = block.hand and LOOK.blue or LOOK.red
		text:SetFontObject(block.hand and ns.JournalFonts().hand or ns.JournalFonts().text)
		text:SetTextColor(unpack(ink))
		text:SetWidth(width)
		text:SetText(block.text)
		return text:GetStringHeight()
	end
	return widget
end

---@class LedgerLeaderWidget: LedgerJournalWidget
---@field value FontString

-- A dotted-leader line: the label left, the value right, dots between (LED-R132's contents list), opening its place;
-- or with an `action`, calling it, its value in a link's red (the Angler page's bindings, LED-R146).
function makers.leader(parent)
	local widget = newWidget(parent) --[[@as LedgerLeaderWidget]]
	local label = ns.JournalText(widget, ns.JournalFonts().text, LOOK.ink)
	label:SetPoint("TOPLEFT")
	widget.label = label
	local value = ns.JournalText(widget, ns.JournalFonts().text, LOOK.ink)
	value:SetPoint("TOPRIGHT")
	value:SetJustifyH("RIGHT")
	widget.value = value
	local dots = {}
	for i = 1, LEADER_DOTS do
		local dot = widget:CreateTexture(nil, "ARTWORK")
		ns.JournalPaint(dot, LOOK.kicker)
		dot:SetSize(1, 1)
		dots[i] = dot
	end
	ns.JournalClickable(widget)
	function widget.Fill(_, block, width, open)
		widget.place, widget.action, widget.open = block.place, block.action, open
		label:SetText(block.text)
		value:SetTextColor(unpack(block.action and LOOK.red or LOOK.ink))
		value:SetText(block.value or "")
		local height = label:GetStringHeight()
		local from, to = label:GetStringWidth() + 4, width - value:GetStringWidth() - 4
		for i, dot in ipairs(dots) do
			local x = (i - 1) * LEADER_DOT_STEP
			dot:ClearAllPoints()
			dot:SetPoint("TOPLEFT", x, -(height - 3))
			dot:SetShown(x >= from and x <= to)
		end
		return height
	end
	return widget
end

-- A wax seal with its text, at the page's right (LED-R132, LED-R135).
function makers.seal(parent)
	local widget = newWidget(parent)
	local wax = disc(widget, SEAL_SIZE)
	wax:SetPoint("TOPRIGHT")
	wax:SetRotation(math.rad(-8))
	local text = ns.JournalText(widget, ns.JournalFonts().seal, LOOK.sealText)
	text:SetPoint("CENTER", wax)
	text:SetJustifyH("CENTER")
	text:SetWidth(SEAL_SIZE - 10)
	widget.label = text
	function widget.Fill(_, block)
		text:SetText(block.text)
		return SEAL_SIZE
	end
	return widget
end

-- The bookplate summary's row (LED-R132), as variant E's: the level in large numerals; beside them its caption with
-- the Prestige emblem and stars after it (makers.emblem), and the active title in handwriting under the caption; a
-- wax seal at the right with Ledger completion.
function makers.bookplate(parent)
	local widget = newWidget(parent)
	local numerals = ns.JournalText(widget, ns.JournalFonts().numeral, LOOK.title)
	numerals:SetPoint("LEFT")
	local caption = ns.JournalText(widget, ns.JournalFonts().small, LOOK.ink)
	local emblem = makers.emblem(widget)
	emblem:SetPoint("LEFT", caption, "RIGHT", 8, 0)
	local signature = ns.JournalText(widget, ns.JournalFonts().hand, LOOK.blue)
	signature:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -4)
	local wax = disc(widget, SEAL_SIZE)
	wax:SetPoint("RIGHT")
	wax:SetRotation(math.rad(-6))
	local seal = ns.JournalText(widget, ns.JournalFonts().seal, LOOK.sealText)
	seal:SetPoint("CENTER", wax)
	seal:SetJustifyH("CENTER")
	widget.label = numerals
	function widget.Fill(_, block, width, open)
		numerals:SetText(block.text)
		caption:SetText(block.value or "")
		signature:SetText(block.signature or "")
		signature:SetShown(block.signature ~= nil)
		-- With a title under it, the caption rides above the numerals' middle so the two stay centred beside them.
		caption:ClearAllPoints()
		caption:SetPoint(block.signature and "BOTTOMLEFT" or "LEFT", numerals, "RIGHT", 12, block.signature and 2 or 0)
		local room = math.max(1, width - numerals:GetStringWidth() - caption:GetStringWidth() - SEAL_SIZE - 32)
		emblem:SetWidth(room)
		emblem:SetHeight(emblem:Fill({ kind = "emblem", mark = block.mark }, room, open))
		emblem:SetShown(block.mark ~= nil and block.mark.emblem ~= nil)
		seal:SetText(block.seal or "")
		wax:SetShown(block.seal ~= nil)
		return SEAL_SIZE
	end
	return widget
end

-- Ink stamps side by side (★ marks, LED-R140, LED-R143): red when inked, faded when not.
function makers.stamps(parent)
	local widget = newWidget(parent)
	---@type { frame: Frame, text: FontString, edges: Texture[] }[]
	local stamps = {}
	local function stampAt(i)
		if not stamps[i] then
			local frame = CreateFrame("Frame", nil, widget)
			local text = ns.JournalText(frame, ns.JournalFonts().small, LOOK.stampOff)
			text:SetPoint("CENTER")
			local edges = {}
			for side, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
				local edge = frame:CreateTexture(nil, "BORDER")
				edge:SetPoint(points[1])
				edge:SetPoint(points[2])
				edge:SetHeight(2)
				edges[side] = edge
			end
			for side, points in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
				local edge = frame:CreateTexture(nil, "BORDER")
				edge:SetPoint(points[1])
				edge:SetPoint(points[2])
				edge:SetWidth(2)
				edges[2 + side] = edge
			end
			stamps[i] = { frame = frame, text = text, edges = edges }
		end
		return stamps[i]
	end
	function widget.Fill(_, block)
		local x = 0
		for i, data in ipairs(block.stamps or {}) do
			local stamp = stampAt(i)
			local color = data.inked and LOOK.red or LOOK.stampOff
			stamp.text:SetText(data.text)
			stamp.text:SetTextColor(unpack(color))
			for _, edge in ipairs(stamp.edges) do
				ns.JournalPaint(edge, color)
			end
			local width = stamp.text:GetStringWidth() + 14
			stamp.frame:SetSize(width, 20)
			stamp.frame:SetPoint("TOPLEFT", x, 0)
			stamp.frame:Show()
			x = x + width + 6
		end
		for i = #(block.stamps or {}) + 1, #stamps do
			stamps[i].frame:Hide()
		end
		return 20
	end
	return widget
end

-- One zone tile (LED-R131): name, two lines, a thin ink bar, a seal and a red note, opening its place.
---@class LedgerZoneTileView: LedgerJournalClickable
---@field name FontString
---@field line FontString
---@field line2 FontString
---@field bar LedgerInkBarView
---@field barFrame Frame
---@field seal Frame
---@field sealText FontString
---@field note FontString

---@param parent Frame
---@return LedgerZoneTileView
local function newTile(parent)
	local tile = CreateFrame("Button", nil, parent) --[[@as LedgerZoneTileView]]
	ns.JournalClickable(tile)
	ns.JournalSolid(tile, LOOK.paper, "BACKGROUND", 0.6)
	local border = tile:CreateTexture(nil, "BORDER")
	ns.JournalPaint(border, LOOK.kicker, 0.35)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	tile.name = ns.JournalText(tile, ns.JournalFonts().text, LOOK.title)
	tile.name:SetPoint("TOPLEFT", 6, -5)
	tile.name:SetPoint("TOPRIGHT", -(TILE_SEAL_SIZE + 6), -5)
	tile.name:SetWordWrap(true)
	tile.line = ns.JournalText(tile, ns.JournalFonts().small, LOOK.kicker)
	tile.line:SetPoint("BOTTOMLEFT", 6, 22)
	tile.line2 = ns.JournalText(tile, ns.JournalFonts().small, LOOK.kicker)
	tile.line2:SetPoint("BOTTOMLEFT", 6, 12)
	tile.barFrame = CreateFrame("Frame", nil, tile)
	tile.barFrame:SetPoint("BOTTOMLEFT", 6, 5)
	tile.barFrame:SetPoint("BOTTOMRIGHT", -6, 5)
	tile.barFrame:SetHeight(4)
	tile.bar = inkBar(tile.barFrame, 4)
	tile.seal = CreateFrame("Frame", nil, tile)
	tile.seal:SetSize(TILE_SEAL_SIZE, TILE_SEAL_SIZE)
	tile.seal:SetPoint("TOPRIGHT", -4, -4)
	local wax = disc(tile.seal, TILE_SEAL_SIZE)
	wax:SetPoint("CENTER")
	wax:SetRotation(math.rad(-10))
	tile.sealText = ns.JournalText(tile.seal, ns.JournalFonts().seal, LOOK.sealText)
	tile.sealText:SetPoint("CENTER")
	tile.note = ns.JournalText(tile, ns.JournalFonts().hand, LOOK.red)
	tile.note:SetPoint("BOTTOMRIGHT", -6, 12)
	return tile
end

-- Sets text `text` on `fontString`, shown only when there is one.
---@param fontString FontString
---@param text string?
local function setOptional(fontString, text)
	fontString:SetText(text or "")
	fontString:SetShown(text ~= nil)
end

-- Zone tiles in a grid, three across (LED-R130, LED-R131), filled by the Home and zone tickets.
function makers.tiles(parent)
	local widget = newWidget(parent)
	---@type LedgerZoneTileView[]
	local tiles = {}
	function widget.Fill(_, block, width, open)
		local tileWidth = (width - (TILE_COLUMNS - 1) * TILE_GAP) / TILE_COLUMNS
		local list = block.tiles or {}
		for i, data in ipairs(list) do
			local tile = tiles[i] or newTile(widget)
			tiles[i] = tile
			local column, row = (i - 1) % TILE_COLUMNS, math.floor((i - 1) / TILE_COLUMNS)
			tile:SetSize(tileWidth, TILE_HEIGHT)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", column * (tileWidth + TILE_GAP), -row * (TILE_HEIGHT + TILE_GAP))
			tile.name:SetText(data.name)
			setOptional(tile.line, data.line)
			setOptional(tile.line2, data.line2)
			tile.barFrame:SetShown(data.bar ~= nil)
			tile.bar:Set(data.bar or 0, tileWidth - 12)
			tile.seal:SetShown(data.seal ~= nil)
			tile.sealText:SetText(data.seal or "")
			setOptional(tile.note, data.note)
			tile:SetAlpha(data.faded and 0.5 or 1)
			tile.place, tile.open = data.place, open
			tile:Show()
		end
		for i = #list + 1, #tiles do
			tiles[i]:Hide()
		end
		local rows = math.ceil(#list / TILE_COLUMNS)
		return math.max(0, rows * (TILE_HEIGHT + TILE_GAP) - TILE_GAP)
	end
	return widget
end

-- Tabs side by side (LED-R130's continent tabs): the chosen one in the title's ink, underlined in red; each opens
-- its place.
---@class LedgerTabView: LedgerJournalClickable
---@field label FontString
---@field underline Texture

function makers.tabs(parent)
	local widget = newWidget(parent)
	---@type LedgerTabView[]
	local tabs = {}
	function widget.Fill(_, block, _, open)
		local x = 0
		for i, data in ipairs(block.tabs or {}) do
			local tab = tabs[i]
			if not tab then
				tab = CreateFrame("Button", nil, widget) --[[@as LedgerTabView]]
				tab.label = ns.JournalText(tab, ns.JournalFonts().kicker, LOOK.kicker)
				tab.label:SetPoint("TOPLEFT")
				tab.underline = tab:CreateTexture(nil, "ARTWORK")
				ns.JournalPaint(tab.underline, LOOK.red)
				tab.underline:SetPoint("BOTTOMLEFT")
				tab.underline:SetPoint("BOTTOMRIGHT")
				tab.underline:SetHeight(2)
				ns.JournalClickable(tab)
				tabs[i] = tab
			end
			local ink = data.on and LOOK.title or LOOK.kicker
			tab.label:SetText(data.text)
			tab.label:SetTextColor(unpack(ink))
			tab.underline:SetShown(data.on)
			tab.place, tab.open = data.place, open
			local width = tab.label:GetStringWidth() + 2
			tab:SetSize(width, TAB_HEIGHT)
			tab:ClearAllPoints()
			tab:SetPoint("TOPLEFT", x, 0)
			tab:Show()
			x = x + width + TAB_GAP
		end
		for i = #(block.tabs or {}) + 1, #tabs do
			tabs[i]:Hide()
		end
		return TAB_HEIGHT
	end
	return widget
end

-- An icon: an item's (by ID) or a texture, in sepia, or as a black silhouette for what isn't caught (LED-R124).
function makers.icon(parent)
	local widget = newWidget(parent)
	local texture = widget:CreateTexture(nil, "ARTWORK")
	texture:SetSize(ICON_SIZE, ICON_SIZE)
	texture:SetPoint("TOPLEFT")
	widget.texture = texture
	function widget.Fill(_, block)
		local size = block.large and LARGE_ICON_SIZE or ICON_SIZE
		texture:SetSize(size, size)
		ns.JournalItemIcon(texture, block.icon, block.look)
		return size
	end
	return widget
end

-- The ink XP bar (LED-R145): the inked fill, Fresh Water's blue stretch, and the words under it, Fresh Water's blue.
function makers.xpBar(parent)
	local widget = newWidget(parent)
	local track = CreateFrame("Frame", nil, widget)
	track:SetPoint("TOPLEFT")
	track:SetPoint("TOPRIGHT")
	track:SetHeight(BAR_HEIGHT)
	local bar = inkBar(track, BAR_HEIGHT)
	local fresh = track:CreateTexture(nil, "ARTWORK")
	ns.JournalPaint(fresh, LOOK.blue, 0.35)
	fresh:SetHeight(BAR_HEIGHT)
	local text = ns.JournalText(widget, ns.JournalFonts().small, LOOK.ink)
	text:SetPoint("TOPLEFT", 0, -(BAR_HEIGHT + 4))
	text:SetWordWrap(true)
	widget.label = text
	function widget.Fill(_, block, width)
		local data = block.bar --[[@as LedgerInkXpBar]]
		bar:Set(data.fill, width)
		local stretch = data.fresh
		fresh:SetShown(stretch ~= nil and stretch.to > stretch.from)
		if stretch then
			fresh:ClearAllPoints()
			fresh:SetPoint("TOPLEFT", stretch.from * width, 0)
			fresh:SetWidth(math.max(1, (stretch.to - stretch.from) * width))
		end
		text:SetWidth(width)
		text:SetText(data.text .. (data.freshText and (colorCode(LOOK.blue) .. data.freshText .. "|r") or ""))
		return BAR_HEIGHT + 4 + text:GetStringHeight()
	end
	return widget
end

-- A Prestige emblem's plate: a strip of leather the numeral is stamped on.
local EMBLEM_HEIGHT = 30
local EMBLEM_PAD = 10

---@class LedgerEmblemWidget: LedgerJournalWidget
---@field numeral FontString

-- A Prestige emblem (LED-R34): its roman numeral stamped in gilt on a leather plate, then a Master Prestige's stars
-- as ink stamps beside it. No custom art (ledger.md › UI). Nothing at all before the first Prestige.
function makers.emblem(parent)
	local widget = newWidget(parent) --[[@as LedgerEmblemWidget]]
	local plate = CreateFrame("Frame", nil, widget)
	plate:SetPoint("TOPLEFT")
	plate:SetHeight(EMBLEM_HEIGHT)
	ns.JournalSolid(plate, LOOK.leather, "BACKGROUND")
	local numeral = ns.JournalText(plate, ns.JournalFonts().title, LOOK.gilt)
	numeral:SetPoint("CENTER")
	numeral:SetJustifyH("CENTER")
	widget.numeral = numeral
	local stars = makers.stamps(widget)
	function widget.Fill(_, block, width, open)
		local mark = block.mark or { stars = 0 }
		if not mark.emblem then
			plate:Hide()
			stars:Hide()
			return 0
		end
		numeral:SetText(mark.emblem)
		local plateWidth = numeral:GetStringWidth() + 2 * EMBLEM_PAD
		plate:SetWidth(plateWidth)
		plate:Show()
		local list = {}
		for i = 1, mark.stars do
			list[i] = { text = ns.L.STAR, inked = true }
		end
		stars:ClearAllPoints()
		stars:SetPoint("LEFT", plate, "RIGHT", 6, 0)
		stars:SetSize(math.max(1, width - plateWidth - 6), 20)
		stars:Fill({ kind = "stamps", stamps = list }, width, open)
		stars:SetShown(mark.stars > 0)
		return EMBLEM_HEIGHT
	end
	return widget
end

-- A button's height, and the room each side of its words.
local BUTTON_HEIGHT, BUTTON_PAD = 24, 12

---@class LedgerButtonWidget: LedgerJournalWidget
---@field face LedgerJournalClickable -- the button itself, sized to its words; the widget spans the page

-- A button (the Angler page's Prestige, LED-R146): its words in gilt on a red face with a gilt edge, as variant E's
-- `.btn`, sized to them; clicking the face calls the block's `action`.
function makers.button(parent)
	local widget = newWidget(parent) --[[@as LedgerButtonWidget]]
	local face = CreateFrame("Button", nil, widget) --[[@as LedgerJournalClickable]]
	ns.JournalClickable(face)
	face:SetPoint("TOPLEFT")
	face:SetHeight(BUTTON_HEIGHT)
	ns.JournalSolid(face, LOOK.gilt, "BACKGROUND")
	local red = ns.JournalSolid(face, LOOK.seal, "BORDER")
	red:SetPoint("TOPLEFT", 1, -1)
	red:SetPoint("BOTTOMRIGHT", -1, 1)
	local text = ns.JournalText(face, ns.JournalFonts().small, LOOK.gilt)
	text:SetPoint("CENTER")
	text:SetJustifyH("CENTER")
	widget.label = text
	widget.face = face
	function widget.Fill(_, block)
		face.action = block.action
		text:SetText(block.text)
		face:SetWidth(text:GetStringWidth() + 2 * BUTTON_PAD)
		return BUTTON_HEIGHT
	end
	return widget
end

-- The gap between blocks on a page.
local BLOCK_GAP = 6

--- A page body: a frame whose contents scroll vertically when they overflow (LED-R123), with each kind's widgets
--- pooled and `drawn` naming those in use, by kind, in page order.
---@class LedgerJournalPage: Frame
---@field scroll ScrollFrame
---@field content Frame
---@field width number
---@field pools table<string, LedgerJournalWidget[]>
---@field drawn table<string, LedgerJournalWidget[]>

--- A page body on `parent`, `width` wide, that scrolls with the mouse wheel.
---@param parent Frame
---@param width number
---@return LedgerJournalPage
function ns.NewJournalPage(parent, width)
	local page = CreateFrame("Frame", nil, parent) --[[@as LedgerJournalPage]]
	page.width = width
	page.pools, page.drawn = {}, {}
	page.scroll = CreateFrame("ScrollFrame", nil, page)
	page.scroll:SetAllPoints()
	page.content = CreateFrame("Frame", nil, page.scroll)
	page.content:SetWidth(width)
	page.content:SetHeight(1)
	page.scroll:SetScrollChild(page.content)
	page.scroll:EnableMouseWheel(true)
	page.scroll:SetScript("OnMouseWheel", function(self, delta)
		local offset = self:GetVerticalScroll() - delta * 40
		self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
	end)
	return page
end

--- Draws `blocks` down `page`, top to bottom, reusing its widgets and hiding the ones left over. `open` opens a
--- place in the Journal; `resetScroll` scrolls back to the top (the page's subject changed, LED-R129).
---@param page LedgerJournalPage
---@param blocks LedgerBlock[]
---@param open fun(place: LedgerJournalPlace)
---@param resetScroll boolean
function ns.DrawJournalPage(page, blocks, open, resetScroll)
	local drawn = {}
	local y = 0
	for _, block in ipairs(blocks) do
		local kind = block.kind
		local pool = page.pools[kind] or {}
		page.pools[kind] = pool
		local used = drawn[kind] or {}
		drawn[kind] = used
		local widget = pool[#used + 1]
		if not widget then
			widget = makers[kind](page.content)
			pool[#pool + 1] = widget
		end
		used[#used + 1] = widget
		widget:ClearAllPoints()
		widget:SetPoint("TOPLEFT", 0, -y)
		widget:SetWidth(page.width)
		local height = widget:Fill(block, page.width, open)
		widget:SetHeight(math.max(1, height))
		widget:Show()
		y = y + height + BLOCK_GAP
	end
	for kind, pool in pairs(page.pools) do
		for i = #(drawn[kind] or {}) + 1, #pool do
			pool[i]:Hide()
		end
	end
	page.drawn = drawn
	page.content:SetHeight(math.max(1, y))
	if resetScroll then
		page.scroll:SetVerticalScroll(0)
	end
end
