if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board's art kit (HNT-R60's second paragraph): its tints, fonts and in-client textures, and a widget maker
-- for each piece the board, its pages, the covers and the tracker draw: leather, parchment, set ribbons, the wax seal
-- (filled, or the dashed "not yet"), the ink bar with its label, the timeline's bar styles, the tier trims (HNT-R18),
-- the group dots, sepia item icons (HNT-R55), and the fleuron and pointing-hand marks, drawn as textures, never as
-- font glyphs. The look follows prototypes/hunts-board/ variant E. Hunts picks its own art and shares no code with
-- the Fish Journal (ADR 0001), though some textures are the same client files. Every texture sits on a solid tint or
-- carries a vertex tint, so a texture the client lacks leaves the tint showing.
--
-- Later tickets add makers here: the covers (#192), the timeline (#193), an entry (#194), sets (#195), the tracker
-- (#197).

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

--- The board's tints, from variant E's CSS (`.vE`). Where the prototype shades a gradient, the tint lies between its
--- ends.
ns.BOARD_LOOK = {
	gilt = tint("e8c96a"), -- the breadcrumbs and the realm clock on the leather
	giltBright = tint("fff4c8"), -- the clock's time, a crumb under the mouse
	fleuron = tint("a8803a"), -- the fleuron between crumbs
	paper = tint("ead6ac"), -- between the page's #f3e5c3 and #dfc89a
	spine = tint("46280a"), -- rgba(70,40,10,.65): the shadow at the spine
	ink = tint("3a2614"), -- printed text
	title = tint("3e220c"), -- headings and names
	kicker = tint("8a5a2a"), -- small-caps kickers and group headings
	small = tint("5a4028"), -- target lines, conditions
	note = tint("8a6a40"), -- italic notes, ruler ticks
	faded = tint("9a8060"), -- "out of season", what is greyed
	hand = tint("23407a"), -- handwriting
	red = tint("9a2a1a"), -- margin labels, the now line, the back link
	barInk = tint("5a3a14"), -- an ink bar's outline and hatching
	barFill = tint("7a5224"), -- between the hatching's lines
	pencil = tint("a89070"), -- a pencil outline: short of skill
	camp = tint("23407a"), -- the blue camp bar
	campEdge = tint("162a50"),
	soonWash = tint("9a2a1a"), -- rgba(154,42,26,.08): the Soon wash on the timeline
	nightWash = tint("23407a"), -- rgba(35,64,122,.08): the night wash
	washAlpha = 0.08,
	seal = tint("a82a1a"), -- between the seal's #d0402a and #7a1810
	sealText = tint("f4dfa8"), -- a seal's words, a ribbon's
	sealOff = tint("b8a080"), -- the dashed "not yet"
	sepia = tint("dcb37a"), -- an item icon's tint over its greys (CSS sepia(.75))
	plate = tint("c19e45"), -- the gold nameplate: between its #e8c96a and #9a7420
	plateEdge = tint("4a3008"),
	plateText = tint("2a1a04"),
	shadow = tint("000000"), -- the black rings round a trim
	--- Tier trims (HNT-R18): bronze, silver, gold.
	trims = { tint("a8652a"), tint("c9ccd3"), tint("f2c230") },
	--- Group dots (HNT-R76): Now green, Soon amber, Later grey, On demand blue.
	groups = { now = tint("4cc94c"), soon = tint("ffb733"), later = tint("9a9a9a"), demand = tint("6fb6ff") },
	--- Ribbons: the Board's, then set colours in turn, in Hunt list order.
	boardRibbon = tint("5a4735"), -- between #4a3a2a and #6a5440
	ribbons = { tint("2f5a8a"), tint("2f7a4a"), tint("8a5a1a"), tint("6a3a7a"), tint("8a2a1a") },
}
local LOOK = ns.BOARD_LOOK

--- In-client textures. Each is a file the forever client's FrameXML names (Gethe/wow-ui-source branch forever at
--- 943764493e6b16d63ded3ab304150d1f05e58b57).
ns.BOARD_TEXTURES = {
	-- The leather's grain (FrameGeneral's rock backdrop) and the page paper (the achievement parchment).
	leather = "Interface\\FrameGeneral\\UI-Background-Rock",
	paper = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
	-- A white disc: the wax seal and the group dots (CharacterFrame's portrait mask).
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- Diagonal stripes that tile (the absorb shield's overlay, Blizzard_UnitFrame/Shared/UnitFrame.xml): the hatching.
	hatch = "Interface\\RaidFrame\\Shield-Overlay",
	-- The fleuron between crumbs (the quest log's bullet) and the pointing hand (the gauntlet cursor).
	fleuron = "Interface\\QuestFrame\\UI-Quest-BulletPoint",
	hand = "Interface\\Cursor\\Point",
}
local TEXTURES = ns.BOARD_TEXTURES

-- The hatching's tile, in pixels: one repeat of its stripes.
local HATCH_TILE = 16

--- The default cover, the board's own leather (HNT-R70's `hunts.notebookcover.leather`): its tint, its dark outline,
--- the gilt rule inside its edge, and its grain. A cover look (`ns.board:SetCover`) gives any of these fields; the rest
--- come from here.
---@class BoardCoverLook
---@field leather number[]?   -- the leather's tint (between variant E's #6a3e20 and #3a2010)
---@field edge number[]?      -- the outline (#120a04)
---@field rule number[]?      -- the gilt rule inside the edge (#8a5a2a)
---@field grain string?       -- the grain's texture
---@field grainAlpha number?

---@class BoardCover: BoardCoverLook -- a cover look with every field
---@field leather number[]
---@field edge number[]
---@field rule number[]
---@field grain string
---@field grainAlpha number

---@type BoardCover
ns.BOARD_COVER = {
	leather = tint("4e2c16"),
	edge = tint("120a04"),
	rule = tint("8a5a2a"),
	grain = TEXTURES.leather,
	grainAlpha = 0.5,
}

-- The serif text face and the handwriting face: in-client fonts.
local SERIF = "Fonts\\FRIZQT__.TTF"
local HAND = "Fonts\\MORPHEUS.TTF"

--- The board's font objects, made on first use.
---@class BoardFonts
---@field text Font     -- printed text (serif)
---@field small Font    -- target lines, notes, bar labels
---@field kicker Font   -- small-caps headings (ns.BoardSmallCaps)
---@field title Font    -- names and page titles (handwriting face, large)
---@field hand Font     -- handwriting
---@field margin Font   -- the timeline's margin labels (handwriting)
---@field crumb Font    -- the leather's breadcrumbs
---@field clock Font    -- the leather's realm clock
---@field seal Font     -- a seal's words
---@field ribbon Font   -- a ribbon's letters
---@field plate Font    -- the nameplate
local fonts

---@return BoardFonts
function ns.BoardFonts()
	if not fonts then
		local function font(name, file, size)
			local object = CreateFont("PagleHuntsBoard" .. name)
			object:SetFont(file, size, "")
			return object
		end
		fonts = {
			text = font("Text", SERIF, 13),
			small = font("Small", SERIF, 11),
			kicker = font("Kicker", SERIF, 10),
			title = font("Title", HAND, 24),
			hand = font("Hand", HAND, 16),
			margin = font("Margin", HAND, 15),
			crumb = font("Crumb", SERIF, 13),
			clock = font("Clock", SERIF, 12),
			seal = font("Seal", SERIF, 10),
			ribbon = font("Ribbon", SERIF, 10),
			plate = font("Plate", SERIF, 12),
		}
	end
	return fonts
end

--- A heading in small caps: the client's fonts have none, so it is set in capitals in the small kicker face.
---@param text string
---@return string
function ns.BoardSmallCaps(text)
	return text:upper()
end

--- A solid tint filling `frame`, or the part its points give.
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@param alpha number?
---@return Texture
function ns.BoardSolid(frame, color, layer, alpha)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	texture:SetAllPoints()
	return texture
end

--- A font string on `frame` in one of the board's fonts and tints.
---@param frame Frame
---@param font Font
---@param color number[]
---@return FontString
function ns.BoardText(frame, font, color)
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(font)
	text:SetTextColor(color[1], color[2], color[3])
	text:SetJustifyH("LEFT")
	return text
end

--- A tier's trim colour (HNT-R18): tier 1 bronze, tier 2 silver, tier 3 and any later tier gold; nil before tier 1.
---@param tier integer?
---@return number[]?
function ns.BoardTrimColor(tier)
	if not tier or tier < 1 then
		return nil
	end
	return LOOK.trims[math.min(tier, #LOOK.trims)]
end

--- A set ribbon's colour: the `i`th set in Hunt list order takes the `i`th, round again after the last.
---@param i integer
---@return number[]
function ns.BoardRibbonColor(i)
	return LOOK.ribbons[(i - 1) % #LOOK.ribbons + 1]
end

-- An outline round a frame: four solid edges, or dashes along them, in one tint.
---@class BoardOutline
---@field Solid fun(self: BoardOutline, color: number[], alpha: number?)
---@field Dashed fun(self: BoardOutline, color: number[], width: number, height: number)
---@field Hide fun(self: BoardOutline)
---@field edges Texture[]
---@field dashes Texture[]

-- A dash's length and the gap after it.
local DASH, GAP = 4, 3

---@param frame Frame
---@return BoardOutline
local function outline(frame)
	local edges = {}
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" },
		{ "TOPRIGHT", "BOTTOMRIGHT" },
	}) do
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetPoint(points[1])
		edge:SetPoint(points[2])
		if i <= 2 then
			edge:SetHeight(1)
		else
			edge:SetWidth(1)
		end
		edges[i] = edge
	end
	local view = { edges = edges, dashes = {} }
	local function dashAt(i)
		if not view.dashes[i] then
			view.dashes[i] = frame:CreateTexture(nil, "BORDER")
		end
		return view.dashes[i]
	end
	function view.Solid(_, color, alpha)
		for _, edge in ipairs(edges) do
			edge:SetColorTexture(color[1], color[2], color[3], alpha or 1)
			edge:Show()
		end
		for _, dash in ipairs(view.dashes) do
			dash:Hide()
		end
	end
	function view.Dashed(_, color, width, height)
		for _, edge in ipairs(edges) do
			edge:Hide()
		end
		local n = 0
		-- Dashes along the top and bottom, then down each side.
		local function run(length, place)
			local at = 0
			while at < length do
				n = n + 1
				local dash = dashAt(n)
				dash:SetColorTexture(color[1], color[2], color[3], 1)
				dash:ClearAllPoints()
				place(dash, at, math.min(DASH, length - at))
				dash:Show()
				at = at + DASH + GAP
			end
		end
		run(width, function(dash, at, length)
			dash:SetSize(length, 1)
			dash:SetPoint("TOPLEFT", at, 0)
		end)
		run(width, function(dash, at, length)
			dash:SetSize(length, 1)
			dash:SetPoint("BOTTOMLEFT", at, 0)
		end)
		run(height, function(dash, at, length)
			dash:SetSize(1, length)
			dash:SetPoint("TOPLEFT", 0, -at)
		end)
		run(height, function(dash, at, length)
			dash:SetSize(1, length)
			dash:SetPoint("TOPRIGHT", 0, -at)
		end)
		for i = n + 1, #view.dashes do
			view.dashes[i]:Hide()
		end
	end
	function view.Hide()
		for _, edge in ipairs(edges) do
			edge:Hide()
		end
		for _, dash in ipairs(view.dashes) do
			dash:Hide()
		end
	end
	return view
end

-- The hatching over `frame`: the shield overlay's stripes, tiled, in a vertex tint.
---@param frame Frame
---@param layer DrawLayer
---@return Texture
local function hatching(frame, layer)
	local texture = frame:CreateTexture(nil, layer)
	texture:SetTexture(TEXTURES.hatch, "REPEAT", "REPEAT")
	texture:SetAllPoints()
	return texture
end

-- Tiles `hatch` across `width` × `height`, as the client's absorb bars tile it.
---@param hatch Texture
---@param width number
---@param height number
local function tile(hatch, width, height)
	hatch:SetTexCoord(0, width / HATCH_TILE, 0, height / HATCH_TILE)
end

--- The leather on `frame`, filling it: the outline, the leather's tint, its grain and the gilt rule inside the edge.
--- `SetCover` dresses it in a cover look (HNT-R70).
---@class BoardLeatherView
---@field edge Texture
---@field leather Texture
---@field grain Texture
---@field rules Texture[]
---@field SetCover fun(self: BoardLeatherView, look: BoardCoverLook)

---@param frame Frame
---@return BoardLeatherView
function ns.NewBoardLeather(frame)
	local leatherTexture = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	leatherTexture:SetPoint("TOPLEFT", 2, -2)
	leatherTexture:SetPoint("BOTTOMRIGHT", -2, 2)
	local grain = frame:CreateTexture(nil, "BORDER")
	grain:SetPoint("TOPLEFT", 2, -2)
	grain:SetPoint("BOTTOMRIGHT", -2, 2)
	---@type BoardLeatherView
	local view = {
		edge = ns.BoardSolid(frame, ns.BOARD_COVER.edge, "BACKGROUND"),
		leather = leatherTexture,
		grain = grain,
		rules = {},
		SetCover = function() end, -- below
	}
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT", 5, -5 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", 5, 5 },
		{ "TOPLEFT", "BOTTOMLEFT", 5, -5 },
		{ "TOPRIGHT", "BOTTOMRIGHT", -5, -5 },
	}) do
		local rule = frame:CreateTexture(nil, "BORDER", nil, 1)
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
	function view.SetCover(_, look)
		local default = ns.BOARD_COVER
		local leather, edge, rule =
			look.leather or default.leather, look.edge or default.edge, look.rule or default.rule
		view.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
		view.leather:SetColorTexture(leather[1], leather[2], leather[3], 1)
		view.grain:SetTexture(look.grain or default.grain)
		view.grain:SetVertexColor(leather[1], leather[2], leather[3])
		view.grain:SetAlpha(look.grainAlpha or default.grainAlpha)
		for _, line in ipairs(view.rules) do
			line:SetColorTexture(rule[1], rule[2], rule[3], 1)
		end
	end
	view.SetCover(view, ns.BOARD_COVER)
	return view
end

--- A parchment page on `frame`, filling it: the paper's tint and texture and, on the side `spine` names, the spine's
--- shadow fading into the page.
---@class BoardParchmentView
---@field paper Texture
---@field grain Texture
---@field spine Texture[]

-- The spine's shadow: strips of fading shade at a page's inner edge.
local SPINE_STRIPS, SPINE_STRIP_WIDTH = 6, 5

---@param frame Frame
---@param spine "LEFT"|"RIGHT"|nil
---@return BoardParchmentView
function ns.NewBoardParchment(frame, spine)
	local view = { spine = {} }
	view.paper = ns.BoardSolid(frame, LOOK.paper, "BACKGROUND")
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

--- A set ribbon (HNT-R61): a cloth tab on the leather's right edge, its words in letters stacked down it, standing
--- out further when chosen. The ribbons' ticket (#195) anchors them down the leather's ribbons anchor.
---@class BoardRibbonView: Button
---@field face Texture
---@field label FontString
---@field chosen boolean
---@field SetRibbon fun(self: BoardRibbonView, text: string, color: number[], chosen: boolean)

-- A ribbon's width, its padding at each end, a letter's height, and how far a chosen one stands out.
local RIBBON_WIDTH, RIBBON_PAD, LETTER_HEIGHT, RIBBON_OUT = 22, 10, 12, 6

---@param parent Frame
---@return BoardRibbonView
function ns.NewBoardRibbon(parent)
	local ribbon = CreateFrame("Button", nil, parent) --[[@as BoardRibbonView]]
	ribbon.face = ribbon:CreateTexture(nil, "BACKGROUND")
	ribbon.label = ns.BoardText(ribbon, ns.BoardFonts().ribbon, LOOK.sealText)
	ribbon.label:SetJustifyH("CENTER")
	ribbon.chosen = false
	function ribbon.SetRibbon(self, text, color, chosen)
		local letters = {}
		for letter in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
			letters[#letters + 1] = letter
		end
		self.label:SetText(table.concat(letters, "\n"))
		local height = #letters * LETTER_HEIGHT + 2 * RIBBON_PAD
		self:SetSize(RIBBON_WIDTH + RIBBON_OUT, height)
		self.face:SetColorTexture(color[1], color[2], color[3], 1)
		local x = chosen and RIBBON_OUT or 0
		self.face:ClearAllPoints()
		self.face:SetPoint("TOPLEFT", x, 0)
		self.face:SetSize(RIBBON_WIDTH, height)
		self.label:ClearAllPoints()
		self.label:SetPoint("TOP", self.face, "TOP", 0, -RIBBON_PAD)
		self:SetAlpha(chosen and 1 or 0.85)
		self.chosen = chosen
	end
	return ribbon
end

--- A wax seal (HNT-R64): a red wax disc with its words, tilted, or the dashed ring of "not yet" with faded words.
---@class BoardSealView: Frame
---@field wax Texture
---@field ring Texture[]
---@field label FontString
---@field filled boolean
---@field SetSeal fun(self: BoardSealView, text: string, filled: boolean)

-- The dashed ring's dashes.
local RING_DASHES = 18

---@param parent Frame
---@param size number
---@return BoardSealView
function ns.NewBoardSeal(parent, size)
	local seal = CreateFrame("Frame", nil, parent) --[[@as BoardSealView]]
	seal:SetSize(size, size)
	seal.wax = seal:CreateTexture(nil, "ARTWORK")
	seal.wax:SetTexture(TEXTURES.disc)
	seal.wax:SetVertexColor(LOOK.seal[1], LOOK.seal[2], LOOK.seal[3])
	seal.wax:SetSize(size, size)
	seal.wax:SetPoint("CENTER")
	seal.wax:SetRotation(math.rad(-8))
	seal.ring = {}
	local radius = size / 2 - 1
	for i = 1, RING_DASHES do
		local angle = 2 * math.pi * i / RING_DASHES
		local dash = seal:CreateTexture(nil, "ARTWORK")
		dash:SetColorTexture(LOOK.sealOff[1], LOOK.sealOff[2], LOOK.sealOff[3], 1)
		dash:SetSize(2, 5)
		dash:SetPoint("CENTER", radius * math.cos(angle), radius * math.sin(angle))
		dash:SetRotation(angle)
		seal.ring[i] = dash
	end
	seal.label = ns.BoardText(seal, ns.BoardFonts().seal, LOOK.sealText)
	seal.label:SetPoint("CENTER")
	seal.label:SetJustifyH("CENTER")
	seal.label:SetWidth(size - 12)
	seal.filled = false
	function seal.SetSeal(self, text, filled)
		self.label:SetText(text)
		local ink = filled and LOOK.sealText or LOOK.sealOff
		self.label:SetTextColor(ink[1], ink[2], ink[3])
		self.wax:SetShown(filled)
		for _, dash in ipairs(self.ring) do
			dash:SetShown(not filled)
		end
		self.filled = filled
	end
	return seal
end

--- An ink bar (HNT-R64, HNT-R66): an ink outline filled with hatching from the left, and its label to its right
--- ("1 / 10").
---@class BoardInkBarView: Frame
---@field outline BoardOutline
---@field fill Texture
---@field hatch Texture
---@field label FontString
---@field value number
---@field SetBar fun(self: BoardInkBarView, fill: number, label: string?)

---@param parent Frame
---@param width number
---@param height number
---@return BoardInkBarView
function ns.NewBoardInkBar(parent, width, height)
	local bar = CreateFrame("Frame", nil, parent) --[[@as BoardInkBarView]]
	bar:SetSize(width, height)
	bar.outline = outline(bar)
	bar.outline:Solid(LOOK.barInk)
	bar.fill = bar:CreateTexture(nil, "ARTWORK")
	bar.fill:SetColorTexture(LOOK.barFill[1], LOOK.barFill[2], LOOK.barFill[3], 1)
	bar.fill:SetPoint("TOPLEFT", 1, -1)
	bar.fill:SetHeight(height - 2)
	bar.hatch = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	bar.hatch:SetTexture(TEXTURES.hatch, "REPEAT", "REPEAT")
	bar.hatch:SetVertexColor(LOOK.barInk[1], LOOK.barInk[2], LOOK.barInk[3])
	bar.hatch:SetAllPoints(bar.fill)
	bar.label = ns.BoardText(bar, ns.BoardFonts().small, LOOK.note)
	bar.label:SetPoint("LEFT", bar, "RIGHT", 6, 0)
	bar.value = 0
	function bar.SetBar(self, fill, label)
		fill = math.max(0, math.min(1, fill))
		local inner = (width - 2) * fill
		self.fill:SetWidth(math.max(1, inner))
		tile(self.hatch, math.max(1, inner), height - 2)
		self.fill:SetShown(fill > 0)
		self.hatch:SetShown(fill > 0)
		self.label:SetText(label or "")
		self.value = fill
	end
	return bar
end

--- A bar on the timeline (HNT-R63), in one of its styles:
---   "hatched"  open: hatched ink in a solid ink outline, its words in paper
---   "dashed"   the window is unconfirmed: faint hatching in a dashed ink outline
---   "pencil"   short of skill: a dashed pencil outline, nothing inside
---   "camp"     the camp is up: solid blue
--- The timeline's ticket (#193) anchors it on the ruler and gives each its width.
---@alias BoardBarStyle "hatched"|"dashed"|"pencil"|"camp"

---@class BoardTimelineBarView: Frame
---@field outline BoardOutline
---@field fill Texture
---@field hatch Texture
---@field label FontString
---@field style BoardBarStyle
---@field SetBar fun(self: BoardTimelineBarView, style: BoardBarStyle, width: number, label: string?)

---@type table<BoardBarStyle, { fill: number[]?, hatch: number[]?, hatchAlpha: number?, edge: number[], dashed: boolean, text: number[] }>
local BAR_STYLES = {
	hatched = { fill = LOOK.barFill, hatch = LOOK.barInk, edge = LOOK.barInk, dashed = false, text = LOOK.paper },
	dashed = { hatch = LOOK.barInk, hatchAlpha = 0.45, edge = LOOK.barInk, dashed = true, text = LOOK.barInk },
	pencil = { edge = LOOK.pencil, dashed = true, text = LOOK.pencil },
	camp = { fill = LOOK.camp, edge = LOOK.campEdge, dashed = false, text = LOOK.paper },
}

---@param parent Frame
---@param height number
---@return BoardTimelineBarView
function ns.NewBoardTimelineBar(parent, height)
	local bar = CreateFrame("Frame", nil, parent) --[[@as BoardTimelineBarView]]
	bar:SetHeight(height)
	bar.fill = bar:CreateTexture(nil, "ARTWORK")
	bar.fill:SetAllPoints()
	bar.hatch = hatching(bar, "ARTWORK")
	bar.outline = outline(bar)
	bar.label = ns.BoardText(bar, ns.BoardFonts().small, LOOK.paper)
	bar.label:SetPoint("LEFT", 4, 0)
	function bar.SetBar(self, style, width, label)
		local look = assert(BAR_STYLES[style], "a timeline bar has no style " .. tostring(style))
		self:SetWidth(width)
		local fill = look.fill
		if fill then
			self.fill:SetColorTexture(fill[1], fill[2], fill[3], 1)
		end
		self.fill:SetShown(fill ~= nil)
		local hatch = look.hatch
		if hatch then
			self.hatch:SetVertexColor(hatch[1], hatch[2], hatch[3], look.hatchAlpha or 1)
			tile(self.hatch, width, height)
		end
		self.hatch:SetShown(hatch ~= nil)
		if look.dashed then
			self.outline:Dashed(look.edge, width, height)
		else
			self.outline:Solid(look.edge)
		end
		self.label:SetText(label or "")
		self.label:SetTextColor(look.text[1], look.text[2], look.text[3])
		self.style = style
	end
	return bar
end

--- A Hunt's icon on the board (HNT-R55, HNT-R18): the icon in sepia, or in the tint given (a generated class's
--- quality colour), and the trim of its highest tier as a ring round it.
---@class BoardIconView: Frame
---@field icon Texture
---@field trim Texture       -- the trim's colour, between two black rings
---@field rings Texture[]
---@field tier integer?
---@field SetIcon fun(self: BoardIconView, texture: string|integer, tintColor: number[]?)
---@field SetTrim fun(self: BoardIconView, tier: integer?)

---@param parent Frame
---@param size number
---@return BoardIconView
function ns.NewBoardIcon(parent, size)
	local view = CreateFrame("Frame", nil, parent) --[[@as BoardIconView]]
	view:SetSize(size, size)
	local function square(layer, sublevel, grow, color)
		local texture = view:CreateTexture(nil, layer, nil, sublevel)
		texture:SetSize(size + grow, size + grow)
		texture:SetPoint("CENTER")
		if color then
			texture:SetColorTexture(color[1], color[2], color[3], 1)
		end
		return texture
	end
	view.rings = { square("BACKGROUND", 0, 8, LOOK.shadow), square("BACKGROUND", 2, 2, LOOK.shadow) }
	view.trim = square("BACKGROUND", 1, 6)
	view.icon = square("ARTWORK", 0, 0)
	function view.SetIcon(self, texture, tintColor)
		local color = tintColor or LOOK.sepia
		self.icon:SetTexture(texture)
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(color[1], color[2], color[3])
	end
	function view.SetTrim(self, tier)
		local color = ns.BoardTrimColor(tier)
		if color then
			self.trim:SetColorTexture(color[1], color[2], color[3], 1)
		end
		self.trim:SetShown(color ~= nil)
		for _, ring in ipairs(self.rings) do
			ring:SetShown(color ~= nil)
		end
		self.tier = color and tier or nil
	end
	view:SetTrim(nil)
	return view
end

--- A tier's diamond on the ladder (HNT-R64): an ink outline, filled in its trim colour once reached.
---@class BoardDiamondView: Frame
---@field edge Texture
---@field face Texture
---@field SetDiamond fun(self: BoardDiamondView, tier: integer, reached: boolean)

---@param parent Frame
---@param size number
---@return BoardDiamondView
function ns.NewBoardDiamond(parent, size)
	local view = CreateFrame("Frame", nil, parent) --[[@as BoardDiamondView]]
	view:SetSize(size, size)
	view.edge = view:CreateTexture(nil, "ARTWORK")
	view.edge:SetColorTexture(LOOK.kicker[1], LOOK.kicker[2], LOOK.kicker[3], 1)
	view.edge:SetSize(size * 0.72, size * 0.72)
	view.edge:SetPoint("CENTER")
	view.edge:SetRotation(math.rad(45))
	view.face = view:CreateTexture(nil, "ARTWORK", nil, 1)
	view.face:SetSize(size * 0.72 - 3, size * 0.72 - 3)
	view.face:SetPoint("CENTER")
	view.face:SetRotation(math.rad(45))
	function view.SetDiamond(self, tier, reached)
		local color = reached and ns.BoardTrimColor(tier) or LOOK.paper
		self.face:SetColorTexture(color[1], color[2], color[3], 1)
	end
	return view
end

--- A group's dot (HNT-R76): a small disc in the group's colour.
---@alias BoardGroup "now"|"soon"|"later"|"demand"

---@class BoardDotView: Texture
---@field group BoardGroup?
---@field SetGroup fun(self: BoardDotView, group: BoardGroup)

---@param parent Frame
---@param size number
---@return BoardDotView
function ns.NewBoardDot(parent, size)
	local dot = parent:CreateTexture(nil, "ARTWORK") --[[@as BoardDotView]]
	dot:SetTexture(TEXTURES.disc)
	dot:SetSize(size, size)
	function dot.SetGroup(self, group)
		local color = assert(LOOK.groups[group], "no group " .. tostring(group))
		self:SetVertexColor(color[1], color[2], color[3])
		self.group = group
	end
	return dot
end

--- A mark drawn as a texture (HNT-R60): the fleuron between crumbs (HNT-R61) in the gilt's tint, or the pointing hand
--- before "back to {set}" (HNT-R66) in red ink.
---@alias BoardMark "fleuron"|"hand"

---@type table<BoardMark, number[]>
local MARK_COLORS = { fleuron = LOOK.fleuron, hand = LOOK.red }

---@param parent Frame
---@param mark BoardMark
---@param size number
---@return Texture
function ns.NewBoardMark(parent, mark, size)
	local color = assert(MARK_COLORS[mark], "no mark " .. tostring(mark))
	local texture = parent:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(TEXTURES[mark])
	texture:SetSize(size, size)
	texture:SetDesaturated(true)
	texture:SetVertexColor(color[1], color[2], color[3])
	return texture
end

--- The gold nameplate (HNT-R61): a gold face with an outline, sized to its words, hidden with none.
---@class BoardPlateView: Frame
---@field face Texture
---@field label FontString
---@field SetPlate fun(self: BoardPlateView, text: string?)

---@param parent Frame
---@return BoardPlateView
function ns.NewBoardPlate(parent)
	local plate = CreateFrame("Frame", nil, parent) --[[@as BoardPlateView]]
	ns.BoardSolid(plate, LOOK.plateEdge, "BACKGROUND")
	plate.face = ns.BoardSolid(plate, LOOK.plate, "BORDER")
	plate.face:SetPoint("TOPLEFT", 1, -1)
	plate.face:SetPoint("BOTTOMRIGHT", -1, 1)
	plate.label = ns.BoardText(plate, ns.BoardFonts().plate, LOOK.plateText)
	plate.label:SetPoint("CENTER")
	function plate.SetPlate(self, text)
		self.label:SetText(text or "")
		self:SetSize(self.label:GetStringWidth() + 20, 22)
		self:SetShown(text ~= nil)
	end
	return plate
end
