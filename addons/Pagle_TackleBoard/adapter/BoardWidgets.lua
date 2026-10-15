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
-- lacks leaves the tint showing.
--
-- Later tickets add makers here: the pins (#239), the spike and the ledge (#240).

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
	ns.BoardSolid(plaque, LOOK.brassEdge, "BACKGROUND")
	plaque.face = ns.BoardSolid(plaque, LOOK.brass, "BORDER")
	plaque.face:SetPoint("TOPLEFT", 1, -1)
	plaque.face:SetPoint("BOTTOMRIGHT", -1, 1)
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
	button.edge = ns.BoardSolid(button, LOOK.woodInner, "BACKGROUND")
	button.face = ns.BoardSolid(button, LOOK.button, "BORDER")
	button.face:SetPoint("TOPLEFT", 2, -2)
	button.face:SetPoint("BOTTOMRIGHT", -2, 2)
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

-- The pins' makers (#239).

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
