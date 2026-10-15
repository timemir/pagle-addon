if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board's art (HNT-R60's second paragraph): its tints and fonts, and a widget maker for each piece the board,
-- its pages, the covers and the tracker draw, in the books art kit (the dev's PagleArtBooks probe, a fork of the Fish
-- Journal's book shell): the leather binding with its band, parchment pages with their gutter, the wax close button,
-- the brass nameplate, grosgrain set ribbons, the wax seal (pressed, or the dashed "not yet"), the ink bar, the
-- timeline's bars, item medallions in their tier's ring (HNT-R18), tier marks, group dots, and the fleuron and
-- pointing-hand marks, drawn as textures, never as font glyphs. The sprites are adapter/BookAtlas.lua's, drawn with
-- adapter/BookArt.lua's helpers. Hunts shares no code with the Fish Journal or Stats (ADR 0001); the shell's textures
-- are Core's media, which both books read.
--
-- The kit's shared pieces every board adapter uses: ns.BoardTint, ns.BoardOutline, ns.BoardTooltip and the pools
-- (ns.BoardPooled, ns.BoardHideFrom).

--- A tint from its hex code, as the kit's canvas writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
function ns.BoardTint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end
local tint = ns.BoardTint

--- The board's tints, the books kit's design-system colours.
ns.BOARD_LOOK = {
	gilt = tint("e8c96a"), -- the breadcrumbs on the leather
	giltBright = tint("fff4c8"), -- a crumb under the mouse
	clock = tint("f6e3a8"), -- the realm clock
	clockJoin = tint("c9b27a"), -- the clock's dots
	checkLabel = tint("e8d6a8"), -- "show completed"
	paper = tint("ead6ac"), -- the page's mid tone: a tracker frame's words sit on it
	ink = tint("3a2614"), -- printed text
	title = tint("3e220c"), -- headings and names
	kicker = tint("8a5a2a"), -- small-caps kickers
	group = tint("5a3a14"), -- group names, the ruler's ink
	small = tint("5a4028"), -- target lines, conditions
	note = tint("8a6a40"), -- italic notes
	faded = tint("9a8060"), -- what is greyed
	count = tint("7a5a30"), -- a group's count, in the margin
	legend = tint("6a4a28"), -- the legend's words
	hand = tint("23407a"), -- handwriting
	red = tint("9a2a1a"), -- margin labels, "Pinned", the back link
	setName = tint("7a2a14"), -- the set line
	rule = tint("c4a874"), -- the rule over the set line
	nowLine = tint("b4281a"), -- the now line
	soonWash = tint("d6a028"), -- the next 3 hours, faintly amber
	soonAlpha = 0.16,
	nightWash = tint("23407a"), -- the night, faintly blue
	nightAlpha = 0.08,
	shade = tint("784614"), -- the selected row's shade
	shadeAlpha = 0.12,
	rail = tint("6a4a20"), -- the list's scroll rail
	thumb = tint("8a5a2a"),
	sealText = tint("f4dfa8"), -- a pressed seal's words
	sealOff = tint("b8a080"), -- the dashed "not yet"
	sepia = tint("dcb37a"), -- an item icon's tint over its greys (CSS sepia(.75))
	plateText = tint("2a1a04"), -- the brass nameplate's words
	chipText = tint("3a2614"),
	here = tint("2a6a2a"), -- "you're here"
	unconfirmed = tint("6a3a8a"), -- the unconfirmed chip's words
	ribbonLabel = tint("efd286"), -- a ribbon's words
	ribbonLabelOn = tint("fff0bc"), -- the chosen ribbon's
	--- Tier trims (HNT-R18), by ns.Trim's names: the medallions' rings and the trims' other uses.
	trims = { bronze = tint("a8652a"), silver = tint("c9ccd3"), gold = tint("f2c230") },
	--- The tier marks' inks on the ladder, by trim.
	tierInks = { bronze = tint("c0844a"), silver = tint("b8bec6"), gold = tint("d8a93a") },
	--- Group dots (HNT-R76), by HuntGroup: Now green, Soon amber, Later grey, On demand blue; bright over the world, in
	--- the tracker's native look, and in ink on paper.
	groups = { now = tint("4aa84a"), soon = tint("e0a030"), later = tint("8a8a8a"), onDemand = tint("4a8ad0") },
	paperGroups = { now = tint("3a8a3a"), soon = tint("c89030"), later = tint("8a8070"), onDemand = tint("3a6aa0") },
	--- Ribbons: the Board's, then set colours in turn, in Hunt list order.
	boardRibbon = tint("2e4a3a"),
	ribbons = { tint("2f5a8a"), tint("2f7a4a"), tint("8a5a1a"), tint("6a3a7a"), tint("8a2a1a") },
}
local LOOK = ns.BOARD_LOOK

--- In-client textures the board still draws: the old covers' grains and the white disc, and the pointing hand, which
--- the kit leaves out. Each is a file the forever client's FrameXML names (Gethe/wow-ui-source branch forever at
--- 943764493e6b16d63ded3ab304150d1f05e58b57).
ns.BOARD_TEXTURES = {
	-- The old covers' grain (FrameGeneral's rock backdrop) and the achievement parchment.
	leather = "Interface\\FrameGeneral\\UI-Background-Rock",
	paper = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
	-- A white disc (CharacterFrame's portrait mask): dots, and the round mask over an item's icon.
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- The pointing hand (the gauntlet cursor).
	hand = "Interface\\Cursor\\Point",
}
local TEXTURES = ns.BOARD_TEXTURES

--- A cover's look (HNT-R70): the kit's leather (`kit`, the default cover's), or the old covers' tint, outline, gilt rule
--- and grain. A cover look (`ns.board:SetCover`) gives any of these fields; the rest come from ns.BOARD_COVER.
---@class BoardCoverLook
---@field kit boolean?        -- the books kit's leather and band (the default cover)
---@field leather number[]?   -- the leather's tint
---@field edge number[]?      -- the outline
---@field rule number[]?      -- the gilt rule inside the edge
---@field grain string?       -- the grain's texture
---@field grainAlpha number?

---@class BoardCover: BoardCoverLook -- a cover look with every field
---@field kit boolean
---@field leather number[]
---@field edge number[]
---@field rule number[]
---@field grain string
---@field grainAlpha number

---@type BoardCover
ns.BOARD_COVER = {
	kit = true,
	leather = tint("4e2c16"),
	edge = tint("120a04"),
	rule = tint("8a5a2a"),
	grain = TEXTURES.leather,
	grainAlpha = 0.5,
}

--- The board's font objects (adapter/BookArt.lua's faces), made on first use.
---@class BoardFonts
---@field text Font      -- printed text: names (IM Fell, 14)
---@field small Font     -- target lines, conditions, the set line (13.5)
---@field note Font      -- italic notes (13)
---@field kicker Font    -- small-caps kickers and group names (12)
---@field title Font     -- an entry's or a set's name (29)
---@field heading Font   -- the timeline's title (25)
---@field hand Font      -- handwriting: effort, the set's title line (Caveat, 20)
---@field handLarge Font -- the window line (22)
---@field margin Font    -- the timeline's margin labels (15.5)
---@field count Font     -- a group's count, "next 22h" (17)
---@field inkCount Font  -- the ink bar's words (19)
---@field pin Font       -- "Pinned" (18)
---@field crumb Font     -- the leather's breadcrumbs (Marcellus, 14, shadowed)
---@field clock Font     -- the realm clock (14, shadowed)
---@field check Font     -- "show completed" (italic 13.5, shadowed)
---@field tier Font      -- a tier's threshold (Marcellus, 15)
---@field seal Font      -- a seal's date (13.5)
---@field sealSmall Font -- a seal's word and year (IM Fell, 9.5)
---@field ribbon Font    -- a ribbon's words (Marcellus 12, shadowed)
---@field plate Font     -- the nameplate (12)
---@field legend Font    -- the legend (italic 12.5)
---@field tick Font      -- the ruler's hours (12)
local fonts

---@return BoardFonts
function ns.BoardFonts()
	if not fonts then
		local font = ns.ArtFont
		fonts = {
			text = font("print", 14),
			small = font("print", 13.5),
			note = font("italic", 13),
			kicker = font("print", 12),
			title = font("print", 29),
			heading = font("print", 25),
			hand = font("hand", 20),
			handLarge = font("hand", 22),
			margin = font("hand", 15.5),
			count = font("hand", 17),
			inkCount = font("hand", 19),
			pin = font("hand", 18),
			crumb = font("gilt", 14, true),
			clock = font("gilt", 14, true),
			check = font("italic", 13.5, true),
			tier = font("gilt", 15),
			seal = font("gilt", 13.5),
			sealSmall = font("print", 9.5),
			ribbon = font("gilt", 12, true),
			plate = font("gilt", 12),
			legend = font("italic", 12.5),
			tick = font("print", 12),
		}
	end
	return fonts
end

--- A heading in small caps: the client has none, so it is set in capitals a size down (the kicker face).
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

--- Lets `text` wrap at `width`, its lines spaced as the kit's canvas sets them (handwriting close, print a third of
--- its size apart).
---@param text FontString
---@param width number
---@param spacing number
function ns.BoardWrap(text, width, spacing)
	text:SetWidth(width)
	text:SetWordWrap(true)
	text:SetSpacing(spacing)
end

--- A trim's colour (HNT-R18), by ns.Trim's name; nil for none (before tier 1).
---@param trim ("bronze"|"silver"|"gold")?
---@return number[]?
function ns.BoardTrimColor(trim)
	return trim and LOOK.trims[trim]
end

--- A set ribbon's colour: the `i`th set in Hunt list order takes the `i`th, round again after the last.
---@param i integer
---@return number[]
function ns.BoardRibbonColor(i)
	return LOOK.ribbons[(i - 1) % #LOOK.ribbons + 1]
end

--- An outline round a frame: four solid edges (top, bottom, left, right), or dashes along the frame's edges, in one
--- tint. `Solid` sets the edges' tint, and their thickness when `size` is given (1 pixel at first).
---@class BoardOutline
---@field Solid fun(self: BoardOutline, color: number[], alpha: number?, size: number?)
---@field Dashed fun(self: BoardOutline, color: number[], width: number, height: number)
---@field Hide fun(self: BoardOutline)
---@field edges Texture[]
---@field dashes Texture[]

-- A dash's length and the gap after it (the kit's `outline: 1px dashed`).
local DASH, GAP = 3, 2

-- An outline's corner offset: `inset` pixels in from `point` (out, when negative).
---@param point string
---@param inset number
---@return number x
---@return number y
local function insetAt(point, inset)
	return point:find("RIGHT") and -inset or inset, point:find("TOP") and -inset or inset
end

--- The outline round `frame`, `inset` pixels inside its edges (outside, when negative; on them by default), its
--- edges on `layer` (BORDER by default) at `sublevel`. The selected row's dashes, the old covers' gilt rule and the
--- old covers' notebook each draw one.
---@param frame Frame
---@param inset number?
---@param layer DrawLayer?
---@param sublevel integer?
---@return BoardOutline
function ns.BoardOutline(frame, inset, layer, sublevel)
	inset, layer = inset or 0, layer or "BORDER"
	local edges = {}
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" },
		{ "TOPRIGHT", "BOTTOMRIGHT" },
	}) do
		local edge = frame:CreateTexture(nil, layer, nil, sublevel)
		if inset == 0 then
			edge:SetPoint(points[1])
			edge:SetPoint(points[2])
		else
			edge:SetPoint(points[1], insetAt(points[1], inset))
			edge:SetPoint(points[2], insetAt(points[2], inset))
		end
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
			view.dashes[i] = frame:CreateTexture(nil, layer, nil, sublevel)
		end
		return view.dashes[i]
	end
	function view.Solid(_, color, alpha, size)
		for i, edge in ipairs(edges) do
			edge:SetColorTexture(color[1], color[2], color[3], alpha or 1)
			if size and i <= 2 then
				edge:SetHeight(size)
			elseif size then
				edge:SetWidth(size)
			end
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
local outline = ns.BoardOutline

--- Shows `lines` in GameTooltip, owned by `owner`: the first as its heading, one line each.
---@param owner Frame
---@param lines string[]
function ns.BoardTooltip(owner, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	GameTooltip:SetText(lines[1])
	for i = 2, #lines do
		GameTooltip:AddLine(lines[i])
	end
	GameTooltip:Show()
end

--- The `i`th widget of `pool`, made with `make` the first time, shown: the board's views reuse their widgets from one
--- draw to the next, and hide what is left over with ns.BoardHideFrom.
---@generic T
---@param pool T[]
---@param i integer
---@param make fun(): T
---@return T
function ns.BoardPooled(pool, i, make)
	local widget = pool[i] or make()
	pool[i] = widget
	local region = widget --[[@as ScriptRegion]] -- each pool holds widgets (or views with their own Show)
	region:Show()
	return widget
end

--- Hides the widgets of `pool` after the first `used`.
---@param pool Region[]
---@param used integer
function ns.BoardHideFrom(pool, used)
	for i = used + 1, #pool do
		pool[i]:Hide()
	end
end

-- The leather's measures: the band's corner (16 units, 32 texels), how far in the tiled grain starts (under the
-- band's opaque lines), and one repeat of the grain (Leather.blp is 256 texels, 128 units).
local BAND, FILL_INSET, LEATHER_TILE = 16, 7, 128

--- The leather on `frame`, filling it, in a cover (HNT-R70): the kit's (the grain tiled under a vignette, the binding
--- band round it on its own frame, above the ribbons so their tucked tops hide under it), or an old cover's (its
--- outline, tint, grain and gilt rule).
---@class BoardLeatherView
---@field edge Texture
---@field leather Texture
---@field grain Texture
---@field rules Texture[]
---@field fill Texture         -- the kit's tiled grain
---@field vignette Texture
---@field band Frame           -- the kit's band, 6 levels over the frame
---@field bandPieces table<string, Texture>
---@field kit boolean          -- whether it wears the kit's leather
---@field SetCover fun(self: BoardLeatherView, look: BoardCover) -- every field given (adapter/Board.lua merges a look)

-- The band's nine slices from the 96-texel binding sprite: 32-texel corners, the edges stretched from a 2-texel slice.
---@param bandFrame Frame
---@return table<string, Texture>
local function bandOf(bandFrame)
	local atlas, sprite = ns.ArtSpriteOf("Book", "binding")
	local pieces = {}
	local function piece(key, sx, sy, sw, sh)
		local texture = ns.ArtCrisp(bandFrame:CreateTexture(nil, "BORDER"))
		ns.ArtCut(texture, atlas, sprite.x + sx, sprite.y + sy, sw, sh)
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
	return pieces
end

---@param frame Frame
---@return BoardLeatherView
function ns.NewBoardLeather(frame)
	local leatherTexture = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	leatherTexture:SetPoint("TOPLEFT", 2, -2)
	leatherTexture:SetPoint("BOTTOMRIGHT", -2, 2)
	local grain = frame:CreateTexture(nil, "BORDER")
	grain:SetPoint("TOPLEFT", 2, -2)
	grain:SetPoint("BOTTOMRIGHT", -2, 2)
	local fill = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, 2))
	fill:SetTexture(ns.BOOK_FILES.leather, "REPEAT", "REPEAT")
	fill:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
	fill:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
	-- darker toward the foot, as the canvas shades it (the gradient's first colour is the bottom's)
	fill:SetGradient("VERTICAL", CreateColor(0.8, 0.8, 0.8, 1), CreateColor(1, 1, 1, 1))
	local vignette = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, 3))
	local atlas, sprite = ns.ArtSpriteOf("Book", "vignette")
	ns.ArtCut(vignette, atlas, sprite.x + 1, sprite.y + 1, sprite.w - 2, sprite.h - 2)
	vignette:SetAllPoints(fill)
	local band = CreateFrame("Frame", nil, frame)
	band:SetAllPoints()
	band:SetFrameLevel(frame:GetFrameLevel() + 6)
	---@type BoardLeatherView
	local view = {
		edge = ns.BoardSolid(frame, ns.BOARD_COVER.edge, "BACKGROUND"),
		leather = leatherTexture,
		grain = grain,
		rules = {},
		fill = fill,
		vignette = vignette,
		band = band,
		bandPieces = bandOf(band),
		kit = true,
		SetCover = function() end, -- below
	}
	local rules = outline(frame, 5, "BORDER", 1)
	view.rules = rules.edges
	function view.SetCover(_, look)
		local kit = look.kit
		view.kit = kit
		for _, texture in ipairs({ view.fill, view.vignette }) do
			texture:SetShown(kit)
		end
		view.band:SetShown(kit)
		for _, texture in ipairs({ view.edge, view.leather, view.grain }) do
			texture:SetShown(not kit)
		end
		if kit then
			rules:Hide()
			-- the grain tiles at its authored density
			local width, height = frame:GetSize()
			local across = math.max(1, width - 2 * FILL_INSET) / LEATHER_TILE
			local down = math.max(1, height - 2 * FILL_INSET) / LEATHER_TILE
			view.fill:SetTexCoord(0, across, 0, down)
			return
		end
		local leather, edge = look.leather, look.edge
		view.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
		view.leather:SetColorTexture(leather[1], leather[2], leather[3], 1)
		view.grain:SetTexture(look.grain)
		view.grain:SetVertexColor(leather[1], leather[2], leather[3])
		view.grain:SetAlpha(look.grainAlpha)
		rules:Solid(look.rule)
	end
	view.SetCover(view, ns.BOARD_COVER)
	return view
end

--- A parchment page on `frame`, filling it: the kit's parchment (mirrored on a right page, so the two don't match) and
--- the gutter's shade along the side `spine` names.
---@class BoardParchmentView
---@field paper Texture
---@field gutter Texture?

-- The gutter's width at the spine.
local GUTTER_WIDTH = 40

---@param frame Frame
---@param spine "LEFT"|"RIGHT"|nil
---@return BoardParchmentView
function ns.NewBoardParchment(frame, spine)
	local view = {}
	view.paper = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND"))
	view.paper:SetTexture(ns.BOOK_FILES.parchment)
	view.paper:SetAllPoints()
	if spine == "LEFT" then
		view.paper:SetTexCoord(1, 0, 0, 1)
	end
	if spine then
		local atlas, sprite = ns.ArtSpriteOf("Book", "gutter")
		local gutter = ns.ArtCrisp(frame:CreateTexture(nil, "BORDER"))
		ns.ArtCut(gutter, atlas, sprite.x + 1, sprite.y + 1, sprite.w - 2, sprite.h - 2)
		gutter:SetWidth(GUTTER_WIDTH)
		gutter:SetPoint("TOP" .. spine)
		gutter:SetPoint("BOTTOM" .. spine)
		if spine == "LEFT" then
			local left, right, top, bottom =
				(sprite.x + 1) / atlas.width,
				(sprite.x + sprite.w - 1) / atlas.width,
				(sprite.y + 1) / atlas.height,
				(sprite.y + sprite.h - 1) / atlas.height
			gutter:SetTexCoord(right, left, top, bottom)
		end
		view.gutter = gutter
	end
	return view
end

--- The wax close button (HNT-R60): a round seal of red wax with a cross, pressed when clicked, glowing under the mouse.
---@class BoardCloseButton: Button
---@field normal Texture
---@field pushed Texture
---@field glow Texture

---@param parent Frame
---@return BoardCloseButton
function ns.NewBoardClose(parent)
	local close = CreateFrame("Button", nil, parent) --[[@as BoardCloseButton]]
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

--- A grosgrain set ribbon (HNT-R61): one white ribbon tinted to its colour, with a gold running stitch over it, hanging
--- from under the leather's foot, its words in gilt near its swallowtail end. The chosen one hangs longer and brighter;
--- one under the mouse brightens. adapter/Sets.lua lays them along the leather's ribbons anchor.
---@class BoardRibbonView: Button
---@field body Texture
---@field stitch Texture
---@field label FontString
---@field chosen boolean
---@field hover boolean
---@field color number[]
---@field tooltip string[]?
---@field SetRibbon fun(self: BoardRibbonView, text: string, color: number[], chosen: boolean)

--- The ribbons' measures (the kit's Hunts board): each one's width and the gap between, how long it hangs (longer
--- chosen), how much of its top tucks under the leather's band, its words' inset, and how much brighter it turns.
ns.BOARD_RIBBON = { width = 104, gap = 10, length = 104, lengthChosen = 120, tuck = 10, pad = 13, lift = 1.13 }
local RIBBON = ns.BOARD_RIBBON

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

-- Paints a ribbon as it is now: its length, its tint (brighter chosen or under the mouse) and its words' ink.
---@param ribbon BoardRibbonView
local function paintRibbon(ribbon)
	local length = ribbon.chosen and RIBBON.lengthChosen or RIBBON.length
	ribbon:SetSize(RIBBON.width, length)
	hang(ribbon.body, ribbon, "ribbon", length)
	hang(ribbon.stitch, ribbon, "ribbon-stitch", length)
	local lift = (ribbon.chosen or ribbon.hover) and RIBBON.lift or 1
	local color = ribbon.color
	ribbon.body:SetVertexColor(math.min(1, color[1] * lift), math.min(1, color[2] * lift), math.min(1, color[3] * lift))
	local ink = ribbon.chosen and LOOK.ribbonLabelOn or LOOK.ribbonLabel
	ribbon.label:SetTextColor(ink[1], ink[2], ink[3])
end

---@param parent Frame
---@return BoardRibbonView
function ns.NewBoardRibbon(parent)
	local ribbon = CreateFrame("Button", nil, parent) --[[@as BoardRibbonView]]
	ribbon.body = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK", nil, 0))
	ribbon.stitch = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK", nil, 1))
	ribbon.label = ns.BoardText(ribbon, ns.BoardFonts().ribbon, LOOK.ribbonLabel)
	ribbon.label:SetJustifyH("CENTER")
	ns.BoardWrap(ribbon.label, RIBBON.width - 2 * RIBBON.pad, 1)
	ribbon.label:SetPoint("BOTTOM", ribbon, "BOTTOM", 0, 31)
	ribbon.chosen, ribbon.hover, ribbon.color = false, false, LOOK.boardRibbon
	ribbon:SetScript("OnEnter", function(self)
		self.hover = true
		paintRibbon(self)
		if self.tooltip then
			ns.BoardTooltip(self, self.tooltip)
		end
	end)
	ribbon:SetScript("OnLeave", function(self)
		self.hover = false
		paintRibbon(self)
		GameTooltip:Hide()
	end)
	function ribbon.SetRibbon(self, text, color, chosen)
		self.label:SetText(text)
		self.color, self.chosen = color, chosen
		paintRibbon(self)
	end
	return ribbon
end

--- A wax seal (HNT-R64, HNT-R66): pressed red wax, tilted, with its words (a word, a date and a year, one above the
--- other, or one wrapped line), or the dashed ring of "not yet" with faded words.
---@class BoardSealView: Frame
---@field wax Texture
---@field empty Texture
---@field label FontString
---@field lines FontString[]
---@field filled boolean
---@field SetSeal fun(self: BoardSealView, text: string, filled: boolean, lines: string[]?)

-- The seal's tilt, and the kit's size the words' places are measured at.
local SEAL_TILT, SEAL_DESIGN = -8, 88

---@param parent Frame
---@param size number
---@return BoardSealView
function ns.NewBoardSeal(parent, size)
	local seal = CreateFrame("Frame", nil, parent) --[[@as BoardSealView]]
	seal:SetSize(size, size)
	seal.wax = ns.ArtSprite(seal, "Book", "seal", "ARTWORK", 0, size)
	seal.wax:SetAllPoints()
	seal.empty = ns.ArtSprite(seal, "Book", "seal-empty", "ARTWORK", 0, size)
	seal.empty:SetAllPoints()
	for _, texture in ipairs({ seal.wax, seal.empty }) do
		texture:SetRotation(math.rad(SEAL_TILT))
	end
	local faces, k = ns.BoardFonts(), size / SEAL_DESIGN
	seal.label = ns.BoardText(seal, faces.seal, LOOK.sealText)
	seal.label:SetPoint("CENTER", 0, 1)
	seal.label:SetJustifyH("CENTER")
	ns.BoardWrap(seal.label, size - 24 * k, 0)
	seal.lines = {}
	for i, place in ipairs({ { faces.sealSmall, 11 }, { faces.seal, -1 }, { faces.sealSmall, -13 } }) do
		local line = ns.BoardText(seal, place[1], LOOK.sealText)
		line:SetJustifyH("CENTER")
		line:SetPoint("CENTER", 0, place[2] * k)
		seal.lines[i] = line
	end
	seal.filled = false
	function seal.SetSeal(self, text, filled, lines)
		local ink = filled and LOOK.sealText or LOOK.sealOff
		local stacked = lines ~= nil and #lines == 3
		self.label:SetText(text)
		self.label:SetShown(not stacked)
		self.label:SetTextColor(ink[1], ink[2], ink[3])
		for i, line in ipairs(self.lines) do
			line:SetText(stacked and (i == 2 and lines[i] or ns.BoardSmallCaps(lines[i])) or "")
			line:SetShown(stacked)
			line:SetTextColor(ink[1], ink[2], ink[3])
		end
		self.wax:SetShown(filled)
		self.empty:SetShown(not filled)
		self.filled = filled
	end
	return seal
end

--- An ink bar (HNT-R64, HNT-R66): the kit's empty ink stroke, sliced to its width, the full stroke cut to its share
--- over it (stretched only past the sprite's own length), and its words to its right in handwriting ("12 / 40").
---@class BoardInkBarView: Frame
---@field empty HuntsThreeSlice
---@field fill Texture         -- the full stroke cut to length
---@field fillSlice HuntsThreeSlice -- the full stroke, sliced, when its share is longer than the sprite
---@field label FontString
---@field value number
---@field SetBar fun(self: BoardInkBarView, fill: number, label: string?)

-- The bar's height, and the ink's end caps.
local INK_HEIGHT, INK_CAP = 10, 6

---@param parent Frame
---@param width number
---@return BoardInkBarView
function ns.NewBoardInkBar(parent, width)
	local bar = CreateFrame("Frame", nil, parent) --[[@as BoardInkBarView]]
	bar:SetSize(width, INK_HEIGHT)
	bar.empty = CreateFrame("Frame", nil, bar) --[[@as HuntsThreeSlice]]
	bar.empty:SetPoint("TOPLEFT")
	ns.SetThreeSlice(bar.empty, "Parts", "ink-empty", width, INK_CAP, "ARTWORK", 0)
	bar.fill = ns.ArtCrisp(bar:CreateTexture(nil, "ARTWORK", nil, 1))
	bar.fillSlice = CreateFrame("Frame", nil, bar) --[[@as HuntsThreeSlice]]
	bar.fillSlice:SetPoint("TOPLEFT")
	bar.fillSlice:SetFrameLevel(bar.empty:GetFrameLevel() + 1)
	bar.label = ns.BoardText(bar, ns.BoardFonts().inkCount, LOOK.ink)
	bar.label:SetPoint("LEFT", bar, "RIGHT", 10, 1)
	bar.value = 0
	local _, sprite = ns.ArtSpriteOf("Parts", "ink-full")
	local spriteLength = sprite.box[3]
	function bar.SetBar(self, fill, label)
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
		self.label:SetText(label or "")
		self.value = fill
	end
	return bar
end

--- A bar on the timeline (HNT-R63), in one of its styles, each the kit's own stroke:
---   "hatched"  open: hatched ink
---   "dashed"   the window is unconfirmed: faint hatching in a dashed outline
---   "pencil"   short of skill: a pencil outline, nothing inside
---   "camp"     the camp is up: solid blue
--- A bar is cut to length, never squeezed, and keeps its own right end, so both ends stay square-on. adapter/Timeline.lua
--- anchors it on the ruler and gives each its width.
---@alias BoardBarStyle "hatched"|"dashed"|"pencil"|"camp"

---@class BoardTimelineBarView: Frame
---@field body Texture
---@field tip Texture
---@field style BoardBarStyle
---@field SetBar fun(self: BoardTimelineBarView, style: BoardBarStyle, width: number)

--- Each bar style's sprite.
---@type table<BoardBarStyle, string>
ns.BOARD_BAR_SPRITES = { hatched = "bar-hatch", dashed = "bar-dash", pencil = "bar-pencil", camp = "bar-blue" }

-- A bar's height, its right end's length, and the shortest bar that keeps it.
local BAR_HEIGHT, BAR_TIP = 12, 4

---@param parent Frame
---@return BoardTimelineBarView
function ns.NewBoardTimelineBar(parent)
	local bar = CreateFrame("Frame", nil, parent) --[[@as BoardTimelineBarView]]
	bar:SetHeight(BAR_HEIGHT)
	bar.body = ns.ArtCrisp(bar:CreateTexture(nil, "ARTWORK"))
	bar.body:SetPoint("TOPLEFT")
	bar.tip = ns.ArtCrisp(bar:CreateTexture(nil, "ARTWORK"))
	bar.tip:SetPoint("TOPRIGHT")
	function bar.SetBar(self, style, width)
		local name = assert(ns.BOARD_BAR_SPRITES[style], "a timeline bar has no style " .. tostring(style))
		self:SetWidth(width)
		local tipped = width > 2 * BAR_TIP
		ns.SetCrop(self.body, "Parts", name, tipped and width - BAR_TIP or width)
		if tipped then
			local atlas, sprite = ns.ArtSpriteOf("Parts", name)
			local right = sprite.x + (sprite.box[1] + sprite.box[3]) * atlas.scale
			ns.ArtCut(self.tip, atlas, right - BAR_TIP * atlas.scale, sprite.y, BAR_TIP * atlas.scale, sprite.h)
			self.tip:SetSize(BAR_TIP, sprite.h / atlas.scale)
		end
		self.tip:SetShown(tipped)
		self.style = style
	end
	return bar
end

--- A Hunt's icon on the board (HNT-R55, HNT-R18): the icon round, in sepia (or in the tint given: a generated class's
--- quality colour), inside a ring in the trim of its highest tier, or a plain ring before the first.
---@class BoardIconView: Frame
---@field icon Texture
---@field ring HuntsSpriteTexture
---@field trimName ("bronze"|"silver"|"gold")?
---@field SetIcon fun(self: BoardIconView, texture: string|integer, tintColor: number[]?)
---@field SetTrim fun(self: BoardIconView, trim: ("bronze"|"silver"|"gold")?)

---@param parent Frame
---@param size number the icon's size
---@param ringSize number? the ring's drawn size (the icon's plus 3 by default)
---@return BoardIconView
function ns.NewBoardIcon(parent, size, ringSize)
	ringSize = ringSize or size + 3
	local view = CreateFrame("Frame", nil, parent) --[[@as BoardIconView]]
	view:SetSize(size, size)
	view.icon = ns.ArtCrisp(view:CreateTexture(nil, "ARTWORK", nil, 0))
	view.icon:SetSize(size - 2, size - 2)
	view.icon:SetPoint("CENTER")
	local mask = view:CreateMaskTexture()
	mask:SetTexture(TEXTURES.disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(view.icon)
	view.icon:AddMaskTexture(mask)
	view.ring = ns.ArtSprite(view, "Parts", "ic-ring", "ARTWORK", 1, ringSize)
	ns.CenterSprite(view.ring, view)
	function view.SetIcon(self, texture, tintColor)
		local color = tintColor or LOOK.sepia
		self.icon:SetTexture(texture)
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(color[1], color[2], color[3])
	end
	function view.SetTrim(self, trim)
		local named = ns.BoardTrimColor(trim) and trim or nil
		ns.SetSprite(self.ring, "Parts", named and "ic-ring-" .. named or "ic-ring", ringSize)
		ns.CenterSprite(self.ring, self)
		self.trimName = named
	end
	view:SetTrim(nil)
	return view
end

--- A tier's mark on the ladder (HNT-R64): the kit's diamond in its trim's ink, filled once reached, an outline before.
---@class BoardDiamondView: Frame
---@field mark HuntsSpriteTexture
---@field SetDiamond fun(self: BoardDiamondView, trim: "bronze"|"silver"|"gold", reached: boolean)

---@param parent Frame
---@param size number
---@return BoardDiamondView
function ns.NewBoardDiamond(parent, size)
	local view = CreateFrame("Frame", nil, parent) --[[@as BoardDiamondView]]
	view:SetSize(size, size)
	view.mark = ns.ArtSprite(view, "Parts", "tier-off", "ARTWORK", 0, size)
	function view.SetDiamond(self, trim, reached)
		ns.SetSprite(self.mark, "Parts", reached and "tier-on" or "tier-off", size)
		ns.PlaceSprite(self.mark, self, 0, 0)
		local color = LOOK.tierInks[trim] or LOOK.tierInks.bronze
		self.mark:SetVertexColor(color[1], color[2], color[3])
	end
	return view
end

--- A group's dot (HNT-R76): a round dot in the group's colour, bright over the world or in ink on paper.
---@class BoardDotView: HuntsArtDot
---@field group HuntGroup?
---@field SetGroup fun(self: BoardDotView, group: HuntGroup, paper: boolean?)

---@param parent Frame
---@param size number
---@return BoardDotView
function ns.NewBoardDot(parent, size)
	local dot = ns.NewArtDot(parent, size) --[[@as BoardDotView]]
	function dot.SetGroup(self, group, paper)
		local color = assert((paper and LOOK.paperGroups or LOOK.groups)[group], "no group " .. tostring(group))
		ns.SetDotColor(self, color)
		self.group = group
	end
	return dot
end

--- A mark drawn as a texture (HNT-R60): the kit's gilt fleuron between crumbs (HNT-R61), or the pointing hand before
--- "back to {set}" (HNT-R66) in red ink.
---@alias BoardMark "fleuron"|"hand"

---@param parent Frame
---@param mark BoardMark
---@param size number
---@return Texture
function ns.NewBoardMark(parent, mark, size)
	if mark == "fleuron" then
		return ns.ArtSprite(parent, "Book", "fleuron", "ARTWORK", 0, size)
	end
	assert(mark == "hand", "no mark " .. tostring(mark))
	local texture = parent:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(TEXTURES.hand)
	texture:SetSize(size, size)
	texture:SetDesaturated(true)
	texture:SetVertexColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	return texture
end

--- The brass nameplate (HNT-R61): the kit's brass plate, three-sliced to its words, hidden with none.
---@class BoardPlateView: Frame
---@field brass HuntsThreeSlice
---@field label FontString
---@field SetPlate fun(self: BoardPlateView, text: string?)

-- The plate's end caps, and the room its words leave.
local PLATE_CAP, PLATE_ROOM = 8, 22

---@param parent Frame
---@return BoardPlateView
function ns.NewBoardPlate(parent)
	local plate = CreateFrame("Frame", nil, parent) --[[@as BoardPlateView]]
	plate.brass = CreateFrame("Frame", nil, plate) --[[@as HuntsThreeSlice]]
	plate.brass:SetPoint("TOPLEFT")
	plate.label = ns.BoardText(plate, ns.BoardFonts().plate, LOOK.plateText)
	plate.label:SetPoint("CENTER", 0, 1)
	function plate.SetPlate(self, text)
		self.label:SetText(text or "")
		local width = math.ceil(self.label:GetStringWidth()) + PLATE_ROOM
		ns.SetThreeSlice(self.brass, "Book", "plate", width, PLATE_CAP, "ARTWORK")
		self:SetSize(width, self.brass:GetHeight())
		self:SetShown(text ~= nil)
	end
	return plate
end

--- The "show completed" box on the leather (HNT-R61, HNT-R82): a small gilt-edged box, filled with gilt when ticked,
--- and its words in italic. `Sync` shows the tick as the box's state.
---@class BoardCheckButton: CheckButton
---@field Text FontString
---@field tick Texture
---@field Sync fun(self: BoardCheckButton)

-- The box's size, and the tick's inset.
local CHECK_SIZE, TICK_INSET = 14, 3.5

---@param parent Frame
---@return BoardCheckButton
function ns.NewBoardCheck(parent)
	local check = CreateFrame("CheckButton", nil, parent) --[[@as BoardCheckButton]]
	check:SetSize(CHECK_SIZE, CHECK_SIZE)
	ns.BoardSolid(check, LOOK.gilt, "BACKGROUND")
	local well = ns.BoardSolid(check, tint("1a1008"), "BORDER")
	well:SetPoint("TOPLEFT", 1.5, -1.5)
	well:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
	check.tick = ns.BoardSolid(check, LOOK.gilt, "ARTWORK")
	check.tick:SetPoint("TOPLEFT", TICK_INSET, -TICK_INSET)
	check.tick:SetPoint("BOTTOMRIGHT", -TICK_INSET, TICK_INSET)
	check.Text = ns.BoardText(check, ns.BoardFonts().check, LOOK.checkLabel)
	check.Text:SetPoint("LEFT", check, "RIGHT", 7, 0)
	function check.Sync(self)
		self.tick:SetShown(self:GetChecked() == true)
	end
	return check
end
