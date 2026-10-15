if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's art kit (TKB-R100): its tints, fonts and in-client textures, and a widget maker for each piece the
-- board and its parts draw: the wood, the cork, the ledge and the brass plaque (the shell's own), and for the part
-- tickets a printed line, a handwritten line, a small-caps kicker, an ink bar, a stamp, a brass tack, a wax seal, a
-- parchment slip and a wooden button. The look follows prototypes/tackle-board/ variant C: the materials of the Fish
-- Journal, the Hunts board and the Stats book (parchment, ink, a serif face for printed text, a handwriting face for
-- notes, brass and wax), but not a book. The Tackle Board shares no code with them (ADR 0001), though some textures
-- are the same client files. Every texture sits on a solid tint or carries a vertex tint, so a texture the client
-- lacks leaves the tint showing. The pins (adapter/Pins.lua), the ledge (adapter/Ledge.lua), the tracker
-- (adapter/TrackerBlock.lua) and the Curio Shop's previews (adapter/Goods.lua) draw with these makers.

--- A tint from its hex code, as the prototype's CSS writes it: { r, g, b }, 0 to 1. The board, the tracker and the
--- tracker frames all tint with it.
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

--- The board's tints, from variant C's CSS (`.vC`, `.slip`, `.ledge`, `.woodbtn`). Where the prototype shades a
--- gradient, the tint lies between its ends.
ns.BOARD_LOOK = {
	wood = tint("5a3418"), -- the frame: between #4a2c14 and #6a4020
	woodDark = tint("4a2c14"), -- its darker ends, left and right
	woodEdge = tint("1a0e04"), -- its outline
	woodInner = tint("2a1608"), -- the line inside its edge, and round the cork
	cork = tint("b0824b"), -- between #b98a52 and #a87a44
	corkFleck = tint("3c1e0a"), -- rgba(60,30,10,.18): the cork's flecks
	shade = tint("000000"), -- the cork's inset shadow, the updating wash
	ledge = tint("623a1a"), -- between #7a4a22 and #4a2a12
	ledgeDark = tint("4a2a12"),
	ledgeLip = tint("9a6a36"), -- the light along the ledge's top edge
	brass = tint("c19e45"), -- the plaque: between #e8c96a and #9a7420
	brassEdge = tint("4a3008"),
	brassText = tint("2a1a04"),
	tack = tint("a87410"), -- a brass tack's head: #ffe9a0, #a87410, #5a3a04
	tackShine = tint("ffe9a0"),
	tackEdge = tint("5a3a04"),
	paper = tint("ecdcb9"), -- a slip: between #f6ead0 and #e3cfa2
	poster = tint("e5d0a2"), -- an Expedition's poster: between #f3e2bd and #d8bf88
	posterTop = tint("8a2a1a"), -- the poster's red top edge
	shadow = tint("281405"), -- rgba(40,20,5,.55): a slip's shadow on the cork
	title = tint("2a1608"), -- a goal's text
	ink = tint("3a2614"), -- printed text
	kicker = tint("8a5a2a"), -- small-caps kickers
	where = tint("6a4a20"), -- italic notes: where a goal is worked
	hand = tint("23407a"), -- handwriting
	here = tint("2a6a2a"), -- the green "I'm here"
	pay = tint("7a5a10"), -- "pays N Coins"
	red = tint("9a2a1a"), -- "take it down", the stamp
	barInk = tint("5a3a14"), -- an ink bar's outline and hatching
	barFill = tint("7a5224"), -- between the hatching's lines
	seal = tint("a82a1a"), -- between the seal's #d0402a and #7a1a10
	sealText = tint("f4dfa8"), -- a seal's words, a wooden button's, "Updating…"
	button = tint("724724"), -- a wooden button: between #8a5a2a and #5a3414
	buttonShine = tint("b07a40"), -- its top edge
	buttonOff = tint("8a7a60"), -- a disabled button's words
	-- The spike and the ledge (adapter/Ledge.lua): variant C's `.spike`, `.ledge .fire`, `.box`, `.brass`, `.drawer`, `.felt`,
	-- `.card2` and the flame's SVG.
	nail = tint("9a9a9a"), -- the spike's nail: between #666 and #ddd
	spiked = tint("e8d8b0"), -- a done slip on the spike
	log = tint("5a3a1c"), -- the Campfire's logs and a stick of Kindling's outline
	logLight = tint("a0703a"), -- a stick of Kindling
	stickOff = tint("777777"), -- a stick of Kindling not held
	flame = tint("e8501a"), -- the flame's outer colour, its glow and the embers
	ember = tint("ff8a2a"),
	ash = tint("3a3a3a"), -- the ash under a fire gone out
	fireText = tint("f4dfa8"), -- the Campfire's words on the ledge
	fireSmall = tint("d8c08a"),
	boxSmall = tint("e8d0a0"), -- the Fly Box's count, the shop link
	felt = tint("24392d"), -- a drawer's compartment: between #2e4a3a and #1a2a20
	feltEdge = tint("3a2410"),
	gilt = tint("c8901a"), -- a rare pattern's gilt edge
	feltText = tint("d8e8c8"),
	feltMiss = tint("6a7a6a"), -- "not tied yet"
	lit = tint("e8701a"), -- a lit day on the Campfire card
	burned = tint("78501e"), -- a day that burned Kindling
	cardLine = tint("c4a874"), -- a day's outline on the card
	cardMuted = tint("9a8060"), -- a title not yet earned
}
local LOOK = ns.BOARD_LOOK

--- In-client textures. Each is in build 70338's ManifestInterfaceData, and is a file the forever client's FrameXML
--- names (Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57).
ns.BOARD_TEXTURES = {
	-- The wood's grain (FrameGeneral's rock backdrop, file 374155) and the cork's flecks (its marble backdrop, 374154),
	-- each under a vertex tint.
	grain = "Interface\\FrameGeneral\\UI-Background-Rock",
	fleck = "Interface\\FrameGeneral\\UI-Background-Marble",
	-- A slip's paper: the achievement parchment (130661).
	paper = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
	-- A white disc: a tack's head and a wax seal (CharacterFrame's portrait mask, 130924).
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- Diagonal stripes that tile (the absorb shield's overlay, 798065): an ink bar's hatching.
	hatch = "Interface\\RaidFrame\\Shield-Overlay",
	-- A Variety Expedition's Species on its hover (TKB-R102): a tick for a caught one, an empty box for the rest (the
	-- check button's art, Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml).
	tick = "Interface\\Buttons\\UI-CheckBox-Check",
	box = "Interface\\Buttons\\UI-CheckBox-Up",
	-- The Campfire's flame (TKB-R106): the fire icon (ns.REWARD_ICONS.campfire, 135805), added onto the ledge so its
	-- dark ground drops out.
	flame = ns.REWARD_ICONS.campfire,
	-- The shop link's pointing hand (TKB-R106): the client's pointing-gauntlet cursor (131028), mirrored to point right.
	pointer = "Interface\\CURSOR\\Point",
}
local TEXTURES = ns.BOARD_TEXTURES

-- The hatching's tile and the flecks' tile, in pixels: one repeat of each.
local HATCH_TILE, FLECK_TILE = 16, 128

--- The serif text face and the handwriting face: in-client fonts, named by the forever FrameXML (FRIZQT__ in
--- Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerFonts.xml, MORPHEUS in Blizzard_Fonts_Shared/Mainline/
--- GameFonts.xml).
ns.BOARD_FONT_FILES = { serif = "Fonts\\FRIZQT__.TTF", hand = "Fonts\\MORPHEUS.TTF" }

--- The board's font objects, made on first use.
---@class TackleBoardFonts
---@field text Font      -- printed text (serif)
---@field title Font     -- an Expedition's text (serif, larger)
---@field small Font     -- where a goal is worked, notes
---@field kicker Font    -- small-caps kickers (ns.BoardSmallCaps)
---@field hand Font      -- handwriting
---@field plaque Font    -- the brass plaque
---@field button Font    -- a wooden button's words
---@field seal Font      -- a wax seal's words
---@field stamp Font     -- a stamp's words
---@field updating Font  -- "Updating…" over the cork (handwriting, large)
local fonts

---@return TackleBoardFonts
function ns.BoardFonts()
	if not fonts then
		local serif, hand = ns.BOARD_FONT_FILES.serif, ns.BOARD_FONT_FILES.hand
		local function font(name, file, size)
			local object = CreateFont("PagleTackleBoard" .. name)
			object:SetFont(file, size, "")
			return object
		end
		fonts = {
			text = font("Text", serif, 14),
			title = font("Title", serif, 18),
			small = font("Small", serif, 12),
			kicker = font("Kicker", serif, 11),
			hand = font("Hand", hand, 17),
			plaque = font("Plaque", serif, 15),
			button = font("Button", serif, 14),
			seal = font("Seal", serif, 12),
			stamp = font("Stamp", serif, 10),
			updating = font("Updating", hand, 26),
		}
	end
	return fonts
end

--- A kicker in small caps: the client's fonts have none, so it is set in capitals in the small kicker face.
---@param text string
---@return string
function ns.BoardSmallCaps(text)
	return text:upper()
end

--- A solid tint filling `frame` (or the part its points give, once set again).
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@param alpha number?
---@param sublevel integer?
---@return Texture
function ns.BoardSolid(frame, color, layer, alpha, sublevel)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	texture:SetAllPoints()
	return texture
end

--- A face framed by an edge (TKB-R100): an `edgeColor` solid filling `frame` and a `faceColor` solid `inset` pixels
--- inside it, as the wooden button and the Fly Box (wood), and the brass plaque and the tally plate (brass) draw theirs.
---@param frame Frame
---@param edgeColor number[]
---@param faceColor number[]
---@param inset number
---@return Texture face
---@return Texture edge
function ns.NewBoardFace(frame, edgeColor, faceColor, inset)
	local edge = ns.BoardSolid(frame, edgeColor, "BACKGROUND")
	local face = ns.BoardSolid(frame, faceColor, "BORDER")
	face:SetPoint("TOPLEFT", inset, -inset)
	face:SetPoint("BOTTOMRIGHT", -inset, inset)
	return face, edge
end

--- A hover on `owner` (TKB-R102, TKB-R106): GameTooltip with `lines[1]` as its title and the rest under it.
---@param owner Frame
---@param lines string[]
function ns.BoardHover(owner, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(lines[1])
	for i = 2, #lines do
		GameTooltip:AddLine(lines[i])
	end
	GameTooltip:Show()
end

--- Hides the board's hover.
function ns.BoardHoverHide()
	GameTooltip:Hide()
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

-- A texture tinted `color` and tiled across `width` × `height` in `tile`-pixel repeats.
---@param frame Frame
---@param file string
---@param color number[]
---@param alpha number
---@param tile integer
---@param width number
---@param height number
---@param layer DrawLayer
---@return Texture
local function tiled(frame, file, color, alpha, tile, width, height, layer)
	local texture = frame:CreateTexture(nil, layer)
	texture:SetTexture(file, "REPEAT", "REPEAT")
	texture:SetVertexColor(color[1], color[2], color[3])
	texture:SetAlpha(alpha)
	texture:SetTexCoord(0, width / tile, 0, height / tile)
	return texture
end

-- A solid edge of `thickness` along one side of `frame`, `inset` in from it.
---@param frame Frame
---@param side "TOP"|"BOTTOM"|"LEFT"|"RIGHT"
---@param color number[]
---@param alpha number
---@param thickness number
---@param inset number
---@param layer DrawLayer
---@param sublevel integer?
---@return Texture
local function edge(frame, side, color, alpha, thickness, inset, layer, sublevel)
	local texture = frame:CreateTexture(nil, layer, nil, sublevel)
	texture:SetColorTexture(color[1], color[2], color[3], alpha)
	if side == "TOP" or side == "BOTTOM" then
		local y = side == "TOP" and -inset or inset
		texture:SetPoint(side .. "LEFT", inset, y)
		texture:SetPoint(side .. "RIGHT", -inset, y)
		texture:SetHeight(thickness)
	else
		local x = side == "LEFT" and inset or -inset
		texture:SetPoint("TOP" .. side, x, -inset)
		texture:SetPoint("BOTTOM" .. side, x, inset)
		texture:SetWidth(thickness)
	end
	return texture
end

-- An outline of `thickness` round `frame`, `inset` in from its edges.
---@return Texture[]
local function outline(frame, color, alpha, thickness, inset, layer, sublevel)
	local edges = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		edges[i] = edge(frame, side, color, alpha, thickness, inset, layer, sublevel)
	end
	return edges
end

--- The wooden frame on `frame`, filling it (TKB-R100): its outline, the wood, the grain, the darker ends and the line
--- inside its edge.
---@class TackleWoodView
---@field outline Texture
---@field wood Texture
---@field grain Texture
---@field ends Texture[]
---@field inner Texture[]

---@param frame Frame
---@param width number
---@param height number
---@return TackleWoodView
function ns.NewBoardWood(frame, width, height)
	local view = { ends = {} }
	view.outline = ns.BoardSolid(frame, LOOK.woodEdge, "BACKGROUND")
	view.wood = ns.BoardSolid(frame, LOOK.wood, "BACKGROUND", 1, 1)
	view.wood:SetPoint("TOPLEFT", 2, -2)
	view.wood:SetPoint("BOTTOMRIGHT", -2, 2)
	view.grain = tiled(frame, TEXTURES.grain, LOOK.wood, 0.5, 256, width, height, "BORDER")
	view.grain:SetAllPoints(view.wood)
	-- The CSS's 90° gradient: the wood darkens toward its left and right ends.
	for i, side in ipairs({ "LEFT", "RIGHT" }) do
		local shade = frame:CreateTexture(nil, "BORDER", nil, 1)
		shade:SetColorTexture(LOOK.woodDark[1], LOOK.woodDark[2], LOOK.woodDark[3], 0.6)
		shade:SetPoint("TOP" .. side, side == "LEFT" and 2 or -2, -2)
		shade:SetPoint("BOTTOM" .. side, side == "LEFT" and 2 or -2, 2)
		shade:SetWidth(width * 0.08)
		view.ends[i] = shade
	end
	view.inner = outline(frame, LOOK.woodInner, 1, 2, 4, "BORDER", 2)
	return view
end

--- The cork on `frame`, filling it (TKB-R100): its dark edge, the cork, its flecks and the shadow inside its edge.
---@class TackleCorkView
---@field cork Texture
---@field flecks Texture
---@field edges Texture[]
---@field shadow Texture[]

---@param frame Frame
---@param width number
---@param height number
---@return TackleCorkView
function ns.NewBoardCork(frame, width, height)
	local view = {}
	view.cork = ns.BoardSolid(frame, LOOK.cork, "BACKGROUND")
	view.flecks = tiled(frame, TEXTURES.fleck, LOOK.corkFleck, 0.35, FLECK_TILE, width, height, "BACKGROUND")
	view.flecks:SetAllPoints()
	view.edges = outline(frame, LOOK.woodInner, 1, 3, 0, "BORDER")
	-- The CSS's inset shadow: fading bands inside the edge.
	view.shadow = {}
	for band = 1, 4 do
		for _, texture in ipairs(outline(frame, LOOK.shade, 0.12, 4, 3 + (band - 1) * 4, "BORDER", 1)) do
			view.shadow[#view.shadow + 1] = texture
		end
	end
	return view
end

--- The ledge on `frame`, filling it (TKB-R100, TKB-R106): the wood, darker toward the bottom, and the light along its
--- top edge.
---@class TackleLedgeView
---@field top Texture
---@field bottom Texture
---@field lip Texture

---@param frame Frame
---@return TackleLedgeView
function ns.NewBoardLedge(frame)
	local view = {}
	view.top = ns.BoardSolid(frame, LOOK.ledge, "BACKGROUND")
	view.bottom = ns.BoardSolid(frame, LOOK.ledgeDark, "BACKGROUND", 1, 1)
	view.bottom:ClearAllPoints()
	view.bottom:SetPoint("BOTTOMLEFT")
	view.bottom:SetPoint("BOTTOMRIGHT")
	view.bottom:SetHeight(frame:GetHeight() / 2)
	view.lip = edge(frame, "TOP", LOOK.ledgeLip, 1, 3, 0, "BORDER")
	return view
end

--- The brass plaque (TKB-R100): a brass face with a dark outline, sized to its words in capitals.
---@class TacklePlaqueView: Frame
---@field face Texture
---@field label FontString
---@field SetPlaque fun(self: TacklePlaqueView, text: string)

---@param parent Frame
---@return TacklePlaqueView
function ns.NewBoardPlaque(parent)
	local plaque = CreateFrame("Frame", nil, parent) --[[@as TacklePlaqueView]]
	plaque.face = ns.NewBoardFace(plaque, LOOK.brassEdge, LOOK.brass, 1)
	plaque.label = ns.BoardText(plaque, ns.BoardFonts().plaque, LOOK.brassText)
	plaque.label:SetPoint("CENTER")
	function plaque.SetPlaque(self, text)
		self.label:SetText(ns.BoardSmallCaps(text))
		self:SetSize(self.label:GetStringWidth() + 44, 24)
	end
	return plaque
end

--- A printed line (TKB-R100: the serif face): a goal's text, the empty slip's words. `large` for an Expedition's.
---@param parent Frame
---@param large boolean?
---@return FontString
function ns.NewBoardPrinted(parent, large)
	local fontSet = ns.BoardFonts()
	local text = ns.BoardText(parent, large and fontSet.title or fontSet.text, large and LOOK.title or LOOK.ink)
	text:SetWordWrap(true)
	return text
end

--- A handwritten line (TKB-R100: the handwriting face): progress, "I'm here", notes. In handwriting blue, or `color`.
---@param parent Frame
---@param color number[]?
---@return FontString
function ns.NewBoardHand(parent, color)
	return ns.BoardText(parent, ns.BoardFonts().hand, color or LOOK.hand)
end

--- A small-caps kicker (TKB-R102: a goal's kind): `SetKicker` sets its words in capitals.
---@class TackleKickerView: FontString
---@field SetKicker fun(self: TackleKickerView, text: string)

---@param parent Frame
---@return TackleKickerView
function ns.NewBoardKicker(parent)
	local kicker = ns.BoardText(parent, ns.BoardFonts().kicker, LOOK.kicker) --[[@as TackleKickerView]]
	function kicker.SetKicker(self, text)
		self:SetText(ns.BoardSmallCaps(text))
	end
	return kicker
end

--- An ink bar (TKB-R102: progress): an ink outline filled with hatching from the left.
---@class TackleInkBarView: Frame
---@field edges Texture[]
---@field fill Texture
---@field hatch Texture
---@field value number
---@field SetBar fun(self: TackleInkBarView, fill: number)

---@param parent Frame
---@param width number
---@param height number
---@return TackleInkBarView
function ns.NewBoardInkBar(parent, width, height)
	local bar = CreateFrame("Frame", nil, parent) --[[@as TackleInkBarView]]
	bar:SetSize(width, height)
	bar.edges = outline(bar, LOOK.barInk, 1, 1, 0, "BORDER")
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
	bar:SetBar(0)
	return bar
end

--- A stamp (TKB-R102: RE-POSTED): its words in capitals inside a red-ink outline, as ink stamped on paper.
---@class TackleStampView: Frame
---@field edges Texture[]
---@field label FontString
---@field SetStamp fun(self: TackleStampView, text: string)

-- How see-through a stamp's ink is (the CSS's rgba(154,42,26,.75)).
local STAMP_ALPHA = 0.75

---@param parent Frame
---@return TackleStampView
function ns.NewBoardStamp(parent)
	local stamp = CreateFrame("Frame", nil, parent) --[[@as TackleStampView]]
	stamp.edges = outline(stamp, LOOK.red, STAMP_ALPHA, 2, 0, "ARTWORK")
	stamp.label = ns.BoardText(stamp, ns.BoardFonts().stamp, LOOK.red)
	stamp.label:SetAlpha(STAMP_ALPHA)
	stamp.label:SetPoint("CENTER")
	function stamp.SetStamp(self, text)
		self.label:SetText(ns.BoardSmallCaps(text))
		self:SetSize(self.label:GetStringWidth() + 12, 18)
	end
	return stamp
end

--- A brass tack (TKB-R102, TKB-R105, TKB-R107): a dark rim, a brass head and its shine at the upper left.
---@class TackleTackView: Frame
---@field rim Texture
---@field head Texture
---@field shine Texture

-- A disc of `size` on `frame`, tinted `color`, centred `x`, `y` off its centre.
---@return Texture
local function disc(frame, layer, sublevel, size, color, x, y)
	local texture = frame:CreateTexture(nil, layer, nil, sublevel)
	texture:SetTexture(TEXTURES.disc)
	texture:SetVertexColor(color[1], color[2], color[3])
	texture:SetSize(size, size)
	texture:SetPoint("CENTER", x or 0, y or 0)
	return texture
end

---@param parent Frame
---@param size number
---@return TackleTackView
function ns.NewBoardTack(parent, size)
	local tack = CreateFrame("Frame", nil, parent) --[[@as TackleTackView]]
	tack:SetSize(size, size)
	tack.rim = disc(tack, "ARTWORK", 0, size, LOOK.tackEdge)
	tack.head = disc(tack, "ARTWORK", 1, size - 2, LOOK.tack)
	tack.shine = disc(tack, "ARTWORK", 2, size * 0.4, LOOK.tackShine, -size * 0.15, size * 0.15)
	return tack
end

--- A wax seal (TKB-R102: an Expedition's pay): a red wax disc with its words.
---@class TackleSealView: Frame
---@field wax Texture
---@field label FontString
---@field SetSeal fun(self: TackleSealView, text: string)

---@param parent Frame
---@param size number
---@return TackleSealView
function ns.NewBoardSeal(parent, size)
	local seal = CreateFrame("Frame", nil, parent) --[[@as TackleSealView]]
	seal:SetSize(size, size)
	seal.wax = disc(seal, "ARTWORK", 0, size, LOOK.seal)
	seal.label = ns.BoardText(seal, ns.BoardFonts().seal, LOOK.sealText)
	seal.label:SetPoint("CENTER")
	seal.label:SetJustifyH("CENTER")
	function seal.SetSeal(self, text)
		self.label:SetText(text)
	end
	return seal
end

--- A parchment slip pinned to the cork (TKB-R102, TKB-R107): its shadow, the paper and its grain, and a brass tack at
--- the top centre; a `poster` (an Expedition) is darker paper with a red top edge. The slip takes the mouse, so it can
--- show a tooltip.
---@class TackleSlipView: Frame
---@field shadow Texture
---@field paper Texture
---@field grain Texture
---@field top Texture?
---@field tack TackleTackView

-- How far a slip's shadow falls, right and down (the CSS's 2px 4px).
local SHADOW_X, SHADOW_Y = 2, 4

---@param parent Frame
---@param width number
---@param height number
---@param poster boolean?
---@return TackleSlipView
function ns.NewBoardSlip(parent, width, height, poster)
	local slip = CreateFrame("Frame", nil, parent) --[[@as TackleSlipView]]
	slip:SetSize(width, height)
	slip:EnableMouse(true)
	slip.shadow = slip:CreateTexture(nil, "BACKGROUND")
	slip.shadow:SetColorTexture(LOOK.shadow[1], LOOK.shadow[2], LOOK.shadow[3], 0.55)
	slip.shadow:SetPoint("TOPLEFT", SHADOW_X, -SHADOW_Y)
	slip.shadow:SetPoint("BOTTOMRIGHT", SHADOW_X, -SHADOW_Y)
	local color = poster and LOOK.poster or LOOK.paper
	slip.paper = ns.BoardSolid(slip, color, "BACKGROUND", 1, 1)
	slip.grain = slip:CreateTexture(nil, "BORDER")
	slip.grain:SetTexture(TEXTURES.paper)
	slip.grain:SetVertexColor(color[1], color[2], color[3])
	slip.grain:SetAlpha(0.35)
	slip.grain:SetAllPoints()
	if poster then
		slip.top = edge(slip, "TOP", LOOK.posterTop, 1, 6, 0, "BORDER", 1)
	end
	slip.tack = ns.NewBoardTack(slip, 12)
	slip.tack:SetPoint("TOP", 0, -5)
	return slip
end

--- A scrap of paper on the cork (TKB-R101: an overflow chip): a slip's shadow filling `frame` and its paper 1 px in
--- from the right and 2 px up from the bottom, so the shadow shows there.
---@param frame Frame
---@return Texture paper
function ns.BoardScrap(frame)
	ns.BoardSolid(frame, LOOK.shadow, "BACKGROUND", 0.55)
	local paper = ns.BoardSolid(frame, LOOK.paper, "BACKGROUND", 1, 1)
	paper:SetPoint("TOPLEFT", 0, 0)
	paper:SetPoint("BOTTOMRIGHT", -1, 2)
	return paper
end

--- A wooden button (TKB-R107: Start my board): its dark edge, the wood, the light along its top and its words.
--- `SetUsable` enables or disables it, greying its words while disabled; the mouse over it brightens the wood.
---@class TackleButtonView: Button
---@field edge Texture
---@field face Texture
---@field shine Texture
---@field label FontString
---@field SetUsable fun(self: TackleButtonView, usable: boolean)

-- How much the mouse over a wooden button brightens its wood (the CSS's brightness(1.15)).
local HOVER = 1.15

---@param parent Frame
---@param text string
---@param onClick fun()
---@return TackleButtonView
function ns.NewBoardButton(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent) --[[@as TackleButtonView]]
	button.face, button.edge = ns.NewBoardFace(button, LOOK.woodInner, LOOK.button, 2)
	button.shine = edge(button, "TOP", LOOK.buttonShine, 1, 2, 2, "ARTWORK")
	button.label = ns.BoardText(button, ns.BoardFonts().button, LOOK.sealText)
	button.label:SetPoint("CENTER")
	button.label:SetText(text)
	button:SetSize(button.label:GetStringWidth() + 44, 30)
	local function wood(brightness)
		local c = LOOK.button
		button.face:SetColorTexture(
			math.min(1, c[1] * brightness),
			math.min(1, c[2] * brightness),
			math.min(1, c[3] * brightness),
			1
		)
	end
	button:SetScript("OnClick", function()
		onClick()
	end)
	button:SetScript("OnEnter", function(self)
		if self:IsEnabled() then
			wood(HOVER)
		end
	end)
	button:SetScript("OnLeave", function()
		wood(1)
	end)
	function button.SetUsable(self, usable)
		self:SetEnabled(usable)
		local ink = usable and LOOK.sealText or LOOK.buttonOff
		self.label:SetTextColor(ink[1], ink[2], ink[3])
		self:SetAlpha(usable and 1 or 0.7)
		if not usable then
			wood(1)
		end
	end
	return button
end

-- The pins' makers (adapter/Pins.lua).

--- An empty pin (TKB-R105): a dashed outline on the cork, a lone brass tack and its words by hand at the bottom.
--- `SetEmpty` sets its words. It takes no mouse, so the board drags by it.
---@class TackleEmptyPinView: Frame
---@field dashes Texture[]
---@field tack TackleTackView
---@field label FontString
---@field SetEmpty fun(self: TackleEmptyPinView, text: string)

-- An empty pin's dashes: 6 pixels of ink, then 4 of cork (the CSS's 1.5px dashed rgba(60,30,10,.35)).
local DASH, DASH_GAP, DASH_ALPHA = 6, 4, 0.35

---@param parent Frame
---@param width number
---@param height number
---@return TackleEmptyPinView
function ns.NewBoardEmptyPin(parent, width, height)
	local pin = CreateFrame("Frame", nil, parent) --[[@as TackleEmptyPinView]]
	pin:SetSize(width, height)
	pin.dashes = {}
	local color = LOOK.corkFleck
	local function dash(point, x, y, w, h)
		local texture = pin:CreateTexture(nil, "BORDER")
		texture:SetColorTexture(color[1], color[2], color[3], DASH_ALPHA)
		texture:SetSize(w, h)
		texture:SetPoint(point, x, y)
		pin.dashes[#pin.dashes + 1] = texture
	end
	local step = DASH + DASH_GAP
	for i = 0, math.floor(width / step) - 1 do
		dash("TOPLEFT", i * step, 0, DASH, 2)
		dash("BOTTOMLEFT", i * step, 0, DASH, 2)
	end
	for i = 0, math.floor(height / step) - 1 do
		dash("TOPLEFT", 0, -i * step, 2, DASH)
		dash("TOPRIGHT", 0, -i * step, 2, DASH)
	end
	pin.tack = ns.NewBoardTack(pin, 10)
	pin.tack:SetPoint("TOP", 0, -5)
	pin.label = ns.BoardText(pin, ns.BoardFonts().hand, LOOK.corkFleck)
	pin.label:SetAlpha(0.8)
	pin.label:SetJustifyH("CENTER")
	pin.label:SetWordWrap(true)
	pin.label:SetWidth(width - 16)
	pin.label:SetPoint("BOTTOM", 0, 8)
	function pin.SetEmpty(self, text)
		self.label:SetText(text)
	end
	return pin
end

--- A brass ring round a pin (TKB-R109: the highlight when the board opens on a goal), hidden until shown. Set its
--- points round the pin.
---@class TackleHighlightView: Frame
---@field edges Texture[]

---@param parent Frame
---@return TackleHighlightView
function ns.NewBoardHighlight(parent)
	local ring = CreateFrame("Frame", nil, parent) --[[@as TackleHighlightView]]
	ring.edges = outline(ring, LOOK.tackShine, 1, 3, 0, "OVERLAY")
	ring:Hide()
	return ring
end

-- The spike's and the ledge's makers (adapter/Ledge.lua).

--- An outline of `thickness` round `frame` in `color`: a day's box on the Campfire card.
---@param frame Frame
---@param color number[]
---@param thickness number
---@param layer DrawLayer
---@return Texture[]
function ns.BoardOutline(frame, color, thickness, layer)
	return outline(frame, color, 1, thickness, 0, layer)
end

--- A solid bar of `width` × `height` tinted `color`, turned `angle` radians about its centre: a log, a stick of
--- Kindling, the spike's nail.
---@param frame Frame
---@param color number[]
---@param width number
---@param height number
---@param angle number
---@param layer DrawLayer
---@param sublevel integer?
---@return Texture
local function bar(frame, color, width, height, angle, layer, sublevel)
	local texture = frame:CreateTexture(nil, layer, nil, sublevel)
	texture:SetColorTexture(color[1], color[2], color[3], 1)
	texture:SetSize(width, height)
	texture:SetRotation(angle)
	return texture
end

--- The Campfire (TKB-R106): two crossed logs; over them a fire's glow and its flame (the fire icon added onto the
--- ledge, so its dark ground drops out), sized by the flame's step and brightened within it; or, for a fire gone out,
--- ash and two embers; or bare logs. `SetFire(view)` draws a TackleCampfireView (logic/Ledge.lua). Every piece is a
--- texture, never a glyph.
---@class TackleFlameView: Frame
---@field logs Texture[]
---@field glow Texture
---@field flame Texture
---@field ash Texture
---@field embers Texture[]
---@field SetFire fun(self: TackleFlameView, view: TackleCampfireView)

-- The flame's size at each step, as a share of the Campfire's box (variant C's flame scales 0.5 to 1.04).
local FLAME_SCALES = { 0.5, 0.66, 0.8, 0.92, 1.04 }
-- How far the fire icon's square is cropped to its flame, each side (an icon's edge is a frame).
local ICON_CROP = 0.08

--- Sets `texture` to the fire icon (ns.BOARD_TEXTURES.flame) cropped to its flame: the Campfire's flame and the
--- tracker header's small one (TKB-R106, TKB-R122).
---@param texture Texture
---@return Texture texture
function ns.BoardFlameIcon(texture)
	texture:SetTexture(TEXTURES.flame)
	texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	return texture
end

---@param parent Frame
---@param size number the Campfire's box, square
---@return TackleFlameView
function ns.NewBoardFlame(parent, size)
	local fire = CreateFrame("Frame", nil, parent) --[[@as TackleFlameView]]
	fire:SetSize(size, size)
	local base = size * 0.12 -- the logs' height above the box's bottom
	fire.glow = disc(fire, "BACKGROUND", 0, size, LOOK.flame)
	fire.glow:ClearAllPoints()
	fire.glow:SetPoint("BOTTOM", 0, base - size * 0.08)
	fire.logs = {}
	for i, angle in ipairs({ 0.16, -0.16 }) do
		local color = i == 1 and LOOK.log or LOOK.ledgeDark
		local log = bar(fire, color, size * 0.66, size * 0.08, angle, "ARTWORK", i)
		log:SetPoint("BOTTOM", 0, base)
		fire.logs[i] = log
	end
	fire.ash = bar(fire, LOOK.ash, size * 0.42, size * 0.06, 0, "ARTWORK", 3)
	fire.ash:SetAlpha(0.7)
	fire.ash:SetPoint("BOTTOM", 0, base + size * 0.08)
	fire.embers = {}
	for i, at in ipairs({ { -0.06, 0.16, 0.05, LOOK.flame }, { 0.06, 0.14, 0.04, LOOK.ember } }) do
		local ember = disc(fire, "OVERLAY", 0, size * at[3], at[4])
		ember:ClearAllPoints()
		ember:SetPoint("BOTTOM", size * at[1], base + size * at[2])
		fire.embers[i] = ember
	end
	fire.flame = ns.BoardFlameIcon(fire:CreateTexture(nil, "OVERLAY", nil, 1))
	fire.flame:SetBlendMode("ADD")
	fire.flame:SetPoint("BOTTOM", 0, base)
	function fire.SetFire(self, view)
		local lit = view.step > 0
		self.flame:SetShown(lit)
		self.glow:SetShown(lit)
		if lit then
			local scale = FLAME_SCALES[view.step]
			self.flame:SetSize(size * scale, size * scale)
			local light = math.min(1, 0.7 + 0.5 * view.bright)
			self.flame:SetVertexColor(light, light, light)
			self.glow:SetSize(size * (0.32 + 0.52 * scale), size * 0.18)
			self.glow:SetAlpha(0.15 + 0.3 * view.bright)
		end
		local out = view.state == "out"
		self.ash:SetShown(out)
		for _, ember in ipairs(self.embers) do
			ember:SetShown(out)
		end
	end
	return fire
end

--- Kindling as sticks (TKB-R106): one stick per Kindling the cap allows, the held ones in wood and the rest faint.
--- `SetSticks(held)` draws them.
---@class TackleSticksView: Frame
---@field sticks Texture[]
---@field SetSticks fun(self: TackleSticksView, held: integer)

-- A stick: 18 × 4 pixels, slanted, 4 pixels apart.
local STICK_WIDTH, STICK_HEIGHT, STICK_GAP, STICK_ANGLE = 18, 4, 4, 0.18

---@param parent Frame
---@param cap integer the sticks drawn
---@return TackleSticksView
function ns.NewBoardSticks(parent, cap)
	local frame = CreateFrame("Frame", nil, parent) --[[@as TackleSticksView]]
	frame:SetSize(cap * (STICK_WIDTH + STICK_GAP), 10)
	frame.sticks = {}
	for i = 1, cap do
		local stick = bar(frame, LOOK.logLight, STICK_WIDTH, STICK_HEIGHT, STICK_ANGLE, "ARTWORK")
		stick:SetPoint("LEFT", (i - 1) * (STICK_WIDTH + STICK_GAP), 0)
		frame.sticks[i] = stick
	end
	function frame.SetSticks(self, held)
		for i, stick in ipairs(self.sticks) do
			local color = i <= held and LOOK.logLight or LOOK.stickOff
			stick:SetColorTexture(color[1], color[2], color[3], 1)
			stick:SetAlpha(i <= held and 1 or 0.45)
		end
	end
	return frame
end

--- A felt compartment of the Fly Box drawer (TKB-R106): green felt in a wooden edge, gilt for a rare pattern, the
--- pattern's icon once tied and its words below. `SetCell(cell)` draws a TackleFlyCell (logic/Ledge.lua). It takes the
--- mouse, for its hover.
---@class TackleFeltCellView: Frame
---@field felt Texture
---@field edges Texture[]
---@field icon Texture
---@field label FontString
---@field cell TackleFlyCell?
---@field SetCell fun(self: TackleFeltCellView, cell: TackleFlyCell)

-- A compartment's icon, square, and its edge's thickness.
local FELT_ICON, FELT_EDGE = 30, 2

---@param parent Frame
---@param width number
---@param height number
---@return TackleFeltCellView
function ns.NewBoardFeltCell(parent, width, height)
	local cell = CreateFrame("Frame", nil, parent) --[[@as TackleFeltCellView]]
	cell:SetSize(width, height)
	cell:EnableMouse(true)
	cell.felt = ns.BoardSolid(cell, LOOK.felt, "BACKGROUND")
	cell.edges = outline(cell, LOOK.feltEdge, 1, FELT_EDGE, 0, "BORDER")
	cell.icon = cell:CreateTexture(nil, "ARTWORK")
	cell.icon:SetSize(FELT_ICON, FELT_ICON)
	cell.icon:SetPoint("TOP", 0, -6)
	cell.label = ns.BoardText(cell, ns.BoardFonts().small, LOOK.feltText)
	cell.label:SetJustifyH("CENTER")
	cell.label:SetWordWrap(true)
	cell.label:SetWidth(width - 8)
	cell.label:SetPoint("BOTTOM", 0, 6)
	function cell.SetCell(self, view)
		self.cell = view
		local rim = view.rare and LOOK.gilt or LOOK.feltEdge
		for _, texture in ipairs(self.edges) do
			texture:SetColorTexture(rim[1], rim[2], rim[3], 1)
		end
		self.icon:SetShown(view.tied)
		if view.icon then
			self.icon:SetTexture(view.icon)
		end
		local ink = view.tied and LOOK.feltText or LOOK.feltMiss
		self.label:SetTextColor(ink[1], ink[2], ink[3])
		self.label:SetText(view.text)
	end
	return cell
end

--- The shop link's pointing hand (TKB-R106): the client's pointing gauntlet, mirrored to point right, as a texture,
--- never a glyph (CORE-R9).
---@param parent Frame
---@param size number
---@return Texture
function ns.NewBoardPointer(parent, size)
	local hand = parent:CreateTexture(nil, "ARTWORK")
	hand:SetTexture(TEXTURES.pointer)
	hand:SetTexCoord(1, 0, 0, 1)
	hand:SetSize(size, size)
	return hand
end
