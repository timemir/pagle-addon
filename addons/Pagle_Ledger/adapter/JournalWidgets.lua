if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's look and its shared widgets (ledger.md › UI, LED-R4's M3 stage): the Field Leather tints, the
-- serif and handwriting font objects, and one widget per kind of LedgerBlock (logic/Journal.lua), drawn down a page.
-- In-client textures and fonts only; custom art comes after 1.0. Every texture sits on a solid tint, so a texture
-- the client lacks leaves the tint showing.

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

--- A solid tint filling `frame`, or the part its points give.
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@param alpha number?
---@return Texture
function ns.JournalSolid(frame, color, layer, alpha)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	texture:SetAllPoints()
	return texture
end

--- A font string on `frame` in one of the Journal's fonts and tints.
---@param frame Frame
---@param font Font
---@param color number[]
---@return FontString
function ns.JournalText(frame, font, color)
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(font)
	text:SetTextColor(color[1], color[2], color[3])
	text:SetJustifyH("LEFT")
	return text
end

--- A widget drawing one kind of block: `Fill` draws the block across `width` and returns the height it takes;
--- `open` opens a place in the Journal.
---@class LedgerJournalWidget: Button
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
			text:SetTextColor(ink[1], ink[2], ink[3])
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
	texture:SetVertexColor(LOOK.seal[1], LOOK.seal[2], LOOK.seal[3])
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
	outline:SetColorTexture(LOOK.barInk[1], LOOK.barInk[2], LOOK.barInk[3], 0.25)
	outline:SetPoint("TOPLEFT")
	outline:SetPoint("TOPRIGHT")
	outline:SetHeight(height)
	local fill = frame:CreateTexture(nil, "ARTWORK")
	fill:SetColorTexture(LOOK.barInk[1], LOOK.barInk[2], LOOK.barInk[3], 1)
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

-- A link: red ink, or in handwriting blue ink (Notes to self, LED-R133), wrapping across the width, opening its place
-- or calling its call (the Field report, LED-R135).
function makers.link(parent)
	local widget = newWidget(parent)
	local text = ns.JournalText(widget, ns.JournalFonts().text, LOOK.red)
	text:SetPoint("TOPLEFT")
	text:SetWordWrap(true)
	widget.label = text
	local place, call, openPlace
	widget:SetScript("OnClick", function()
		if call then
			call()
		elseif place then
			openPlace(place)
		end
	end)
	function widget.Fill(_, block, width, open)
		place, call, openPlace = block.place, block.call, open
		local ink = block.hand and LOOK.blue or LOOK.red
		text:SetFontObject(block.hand and ns.JournalFonts().hand or ns.JournalFonts().text)
		text:SetTextColor(ink[1], ink[2], ink[3])
		text:SetWidth(width)
		text:SetText(block.text)
		return text:GetStringHeight()
	end
	return widget
end

-- A dotted-leader line: the label left, the value right, dots between (LED-R132's contents list).
function makers.leader(parent)
	local widget = newWidget(parent)
	local label = ns.JournalText(widget, ns.JournalFonts().text, LOOK.ink)
	label:SetPoint("TOPLEFT")
	local value = ns.JournalText(widget, ns.JournalFonts().text, LOOK.ink)
	value:SetPoint("TOPRIGHT")
	value:SetJustifyH("RIGHT")
	local dots = {}
	for i = 1, LEADER_DOTS do
		local dot = widget:CreateTexture(nil, "ARTWORK")
		dot:SetColorTexture(LOOK.kicker[1], LOOK.kicker[2], LOOK.kicker[3], 1)
		dot:SetSize(1, 1)
		dots[i] = dot
	end
	local place, openPlace
	widget:SetScript("OnClick", function()
		if place then
			openPlace(place)
		end
	end)
	function widget.Fill(_, block, width, open)
		place, openPlace = block.place, open
		label:SetText(block.text)
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

-- The bookplate summary's row (LED-R132): the level in large numerals, its caption beside them, and a wax seal at
-- the right with Ledger completion.
function makers.bookplate(parent)
	local widget = newWidget(parent)
	local numerals = ns.JournalText(widget, ns.JournalFonts().numeral, LOOK.title)
	numerals:SetPoint("LEFT")
	local caption = ns.JournalText(widget, ns.JournalFonts().small, LOOK.ink)
	caption:SetPoint("LEFT", numerals, "RIGHT", 12, 0)
	local wax = disc(widget, SEAL_SIZE)
	wax:SetPoint("RIGHT")
	wax:SetRotation(math.rad(-6))
	local seal = ns.JournalText(widget, ns.JournalFonts().seal, LOOK.sealText)
	seal:SetPoint("CENTER", wax)
	seal:SetJustifyH("CENTER")
	widget.label = numerals
	function widget.Fill(_, block)
		numerals:SetText(block.text)
		caption:SetText(block.value or "")
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
			stamp.text:SetTextColor(color[1], color[2], color[3])
			for _, edge in ipairs(stamp.edges) do
				edge:SetColorTexture(color[1], color[2], color[3], 1)
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
---@class LedgerZoneTileView: Button
---@field name FontString
---@field line FontString
---@field line2 FontString
---@field bar LedgerInkBarView
---@field barFrame Frame
---@field seal Frame
---@field sealText FontString
---@field note FontString
---@field place LedgerJournalPlace?

---@param parent Frame
---@param open fun(): fun(place: LedgerJournalPlace)
---@return LedgerZoneTileView
local function newTile(parent, open)
	local tile = CreateFrame("Button", nil, parent) --[[@as LedgerZoneTileView]]
	ns.JournalSolid(tile, LOOK.paper, "BACKGROUND", 0.6)
	local border = tile:CreateTexture(nil, "BORDER")
	border:SetColorTexture(LOOK.kicker[1], LOOK.kicker[2], LOOK.kicker[3], 0.35)
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
	tile:SetScript("OnClick", function(self)
		if self.place then
			open()(self.place)
		end
	end)
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
	local opener
	local function open()
		return opener
	end
	function widget.Fill(_, block, width, openPlace)
		opener = openPlace
		local tileWidth = (width - (TILE_COLUMNS - 1) * TILE_GAP) / TILE_COLUMNS
		local list = block.tiles or {}
		for i, data in ipairs(list) do
			local tile = tiles[i] or newTile(widget, open)
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
			tile.place = data.place
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
---@class LedgerTabView: Button
---@field label FontString
---@field underline Texture
---@field place LedgerJournalPlace?

function makers.tabs(parent)
	local widget = newWidget(parent)
	---@type LedgerTabView[]
	local tabs = {}
	local opener
	function widget.Fill(_, block, _, open)
		opener = open
		local x = 0
		for i, data in ipairs(block.tabs or {}) do
			local tab = tabs[i]
			if not tab then
				tab = CreateFrame("Button", nil, widget) --[[@as LedgerTabView]]
				tab.label = ns.JournalText(tab, ns.JournalFonts().kicker, LOOK.kicker)
				tab.label:SetPoint("TOPLEFT")
				tab.underline = tab:CreateTexture(nil, "ARTWORK")
				tab.underline:SetColorTexture(LOOK.red[1], LOOK.red[2], LOOK.red[3], 1)
				tab.underline:SetPoint("BOTTOMLEFT")
				tab.underline:SetPoint("BOTTOMRIGHT")
				tab.underline:SetHeight(2)
				tab:SetScript("OnClick", function(self)
					if self.place then
						opener(self.place)
					end
				end)
				tabs[i] = tab
			end
			local ink = data.on and LOOK.title or LOOK.kicker
			tab.label:SetText(data.text)
			tab.label:SetTextColor(ink[1], ink[2], ink[3])
			tab.underline:SetShown(data.on)
			tab.place = data.place
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
		local icon = block.icon
		if type(icon) == "number" then
			local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
			icon = fileID or icon
		end
		local size = block.large and LARGE_ICON_SIZE or ICON_SIZE
		texture:SetSize(size, size)
		texture:SetTexture(icon)
		texture:SetDesaturated(true)
		if block.look == "silhouette" then
			texture:SetVertexColor(0, 0, 0)
			texture:SetAlpha(0.6)
		else
			texture:SetVertexColor(LOOK.sepia[1], LOOK.sepia[2], LOOK.sepia[3])
			texture:SetAlpha(1)
		end
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
	fresh:SetColorTexture(LOOK.blue[1], LOOK.blue[2], LOOK.blue[3], 0.35)
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

-- A box of four ink edges around `frame`, each 1.5 px as the prototype's circled rung, coloured `color`.
---@param frame Frame
---@return Texture[]
local function inkBox(frame)
	local edges = {}
	for _, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT", "height" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", "height" },
		{ "TOPLEFT", "BOTTOMLEFT", "width" },
		{ "TOPRIGHT", "BOTTOMRIGHT", "width" },
	}) do
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetPoint(points[1])
		edge:SetPoint(points[2])
		if points[3] == "height" then
			edge:SetHeight(1.5)
		else
			edge:SetWidth(1.5)
		end
		edge:SetColorTexture(LOOK.red[1], LOOK.red[2], LOOK.red[3], 1)
		edges[#edges + 1] = edge
	end
	return edges
end

-- The rank ladder's rung height, and the gap around its separators.
local RUNG_HEIGHT = 18
local RUNG_PAD = 6

-- Zone Mastery's ladder (LED-R135): the ranks side by side, those reached inked, the shown one circled in red.
function makers.ladder(parent)
	local widget = newWidget(parent)
	---@type { frame: Frame, text: FontString, ring: Texture[], separator: FontString? }[]
	local rungs = {}
	local function rungAt(i)
		if not rungs[i] then
			local frame = CreateFrame("Frame", nil, widget)
			local text = ns.JournalText(frame, ns.JournalFonts().text, LOOK.stampOff)
			text:SetPoint("CENTER")
			local separator
			if i > 1 then
				separator = ns.JournalText(widget, ns.JournalFonts().text, LOOK.stampOff)
				separator:SetText(ns.L.ZONE_LADDER_SEPARATOR)
			end
			rungs[i] = { frame = frame, text = text, ring = inkBox(frame), separator = separator }
		end
		return rungs[i]
	end
	function widget.Fill(_, block)
		local x = 0
		for i, data in ipairs(block.rungs or {}) do
			local rung = rungAt(i)
			if rung.separator then
				rung.separator:ClearAllPoints()
				rung.separator:SetPoint("LEFT", widget, "TOPLEFT", x, -RUNG_HEIGHT / 2)
				rung.separator:Show()
				x = x + rung.separator:GetStringWidth()
			end
			local color = data.circled and LOOK.red or data.inked and LOOK.title or LOOK.stampOff
			rung.text:SetText(data.text)
			rung.text:SetTextColor(color[1], color[2], color[3])
			for _, edge in ipairs(rung.ring) do
				edge:SetShown(data.circled)
			end
			local width = rung.text:GetStringWidth() + 2 * RUNG_PAD
			rung.frame:SetSize(width, RUNG_HEIGHT)
			rung.frame:ClearAllPoints()
			rung.frame:SetPoint("TOPLEFT", x, 0)
			rung.frame:Show()
			x = x + width
		end
		for i = #(block.rungs or {}) + 1, #rungs do
			rungs[i].frame:Hide()
			if rungs[i].separator then
				rungs[i].separator:Hide()
			end
		end
		return RUNG_HEIGHT
	end
	return widget
end

-- A list row's icon size, its stars' room and the gap after the icon (LED-R136).
local ROW_ICON_SIZE = 22
local ROW_GAP = 6

-- Three stars in a row, each inked (in the stamps' red) or blank (LED-R48).
---@param stars LedgerStars
---@return string
local function starText(stars)
	local parts = {}
	for star = 1, 3 do
		parts[star] = colorCode(stars[star] and LOOK.red or LOOK.stampOff) .. ns.L.STAR .. "|r"
	end
	return table.concat(parts)
end

---@class LedgerJournalRowView: LedgerJournalWidget
---@field icon Texture
---@field name FontString
---@field margin FontString
---@field stars FontString
---@field value FontString
---@field highlight Texture

-- A list row (LED-R136, LED-R137): a small icon in sepia or as a silhouette, the text, its margin notes in
-- handwriting under it, the stars and a value at the right, a faint wash when selected; it opens its place.
function makers.row(parent)
	local widget = newWidget(parent) --[[@as LedgerJournalRowView]]
	widget.highlight = ns.JournalSolid(widget, LOOK.kicker, "BACKGROUND", 0.15)
	widget.icon = widget:CreateTexture(nil, "ARTWORK")
	widget.icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
	widget.icon:SetPoint("TOPLEFT")
	widget.value = ns.JournalText(widget, ns.JournalFonts().text, LOOK.ink)
	widget.value:SetPoint("TOPRIGHT")
	widget.value:SetJustifyH("RIGHT")
	widget.stars = ns.JournalText(widget, ns.JournalFonts().text, LOOK.red)
	widget.stars:SetJustifyH("RIGHT")
	widget.name = ns.JournalText(widget, ns.JournalFonts().text, LOOK.ink)
	widget.name:SetWordWrap(true)
	widget.label = widget.name
	widget.margin = ns.JournalText(widget, ns.JournalFonts().hand, LOOK.blue)
	widget.margin:SetWordWrap(true)
	local place, openPlace
	widget:SetScript("OnClick", function()
		if place then
			openPlace(place)
		end
	end)
	function widget.Fill(_, block, width, open)
		place, openPlace = block.place, open
		widget.highlight:SetShown(block.selected == true)
		local icon = block.icon
		widget.icon:SetShown(icon ~= nil)
		if type(icon) == "number" then
			local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
			icon = fileID or icon
		end
		widget.icon:SetTexture(icon)
		widget.icon:SetDesaturated(true)
		if block.look == "silhouette" then
			widget.icon:SetVertexColor(0, 0, 0)
		else
			widget.icon:SetVertexColor(LOOK.sepia[1], LOOK.sepia[2], LOOK.sepia[3])
		end
		local left = block.icon and ROW_ICON_SIZE + ROW_GAP or 0
		widget.value:SetText(block.value or "")
		widget.value:SetShown(block.value ~= nil)
		local right = block.value and widget.value:GetStringWidth() + ROW_GAP or 0
		widget.stars:ClearAllPoints()
		widget.stars:SetPoint("TOPRIGHT", -right, 0)
		widget.stars:SetText(block.stars and starText(block.stars) or "")
		widget.stars:SetShown(block.stars ~= nil)
		right = right + (block.stars and widget.stars:GetStringWidth() + ROW_GAP or 0)
		local ink = TEXT_COLORS[block.color] or LOOK.ink
		widget.name:SetTextColor(ink[1], ink[2], ink[3])
		widget.name:ClearAllPoints()
		widget.name:SetPoint("TOPLEFT", left, 0)
		widget.name:SetWidth(width - left - right)
		widget.name:SetText(block.text)
		local height = widget.name:GetStringHeight()
		local margin = block.margin
		widget.margin:SetShown(margin ~= nil)
		if margin then
			widget.margin:ClearAllPoints()
			widget.margin:SetPoint("TOPLEFT", left, -height)
			widget.margin:SetWidth(width - left)
			widget.margin:SetText(table.concat(margin, ns.L.ZONE_MARGIN_SEPARATOR))
			height = height + widget.margin:GetStringHeight()
		end
		return math.max(height, block.icon and ROW_ICON_SIZE or 0)
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
--- place in the Journal; `resetScroll` scrolls back to the top (a new spread, not a redraw of the same one).
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
