if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board's art (HNT-R60's second paragraph): its tints and fonts, its sounds, and a widget maker for each
-- piece its pages and the tracker draw, in the books art kit (the dev's PagleArtBooks probe): the wax seal (pressed,
-- or the dashed "not yet"), the ink bar, the timeline's bars, item medallions in their tier's ring (HNT-R18), tier
-- marks, group dots, the pointing hand and the "show completed" box, drawn as textures, never as font glyphs. The
-- sprites are adapter/BookAtlas.lua's, drawn with adapter/BookArt.lua's helpers. The book round the pages (the window,
-- the binding, the parchment, the crumbs, the nameplate, the wax close and "?", the ribbons and the page turn) is
-- Core's shell, `Pagle.NewBook` (ADR 0016), which adapter/Board.lua opens.
--
-- The kit's shared pieces every board adapter uses: ns.BoardTint, ns.BoardOutline, ns.BoardTooltip and the pools
-- (ns.BoardPooled, ns.BoardHideFrom).

--- Whether things move: Core's Animations setting, `Pagle.IsAnimationsOn()` (announcements.md › Contracts; on by
--- default). Core's driver reads it too, so the board asks only to choose what it draws.
---@return boolean
function ns.MotionOn()
	return Pagle.IsAnimationsOn() ~= false
end

-- The books kit's sounds (SOUND.md) the board plays itself, by the client's sound kit ids, on the SFX channel: UI
-- foley, never part of a sound set, with no setting of Pagle's own (the client's SFX volume is their switch). The
-- book's opening, closing and page turn are the shell's (BOOK-R4, BOOK-R31).
---@type table<string, integer>
ns.BOARD_SOUNDS = {
	check = 856, -- IG_MAINMENU_OPTION_CHECKBOX_ON: "show completed"
	uncheck = 857, -- IG_MAINMENU_OPTION_CHECKBOX_OFF
	huntOpens = 3175, -- MAP_PING: a Hunt's window opens while the board is open
	write = 3093, -- IG_WRITE_QUEST: a catch is written into the Hunt's count
}
-- The beats tied to a motion, which play only while things move: the ink running on.
local MOTION_TIED = { write = true }

--- Plays the board's sound `name` (ns.BOARD_SOUNDS) on the SFX channel; a beat tied to a motion only while things move.
---@param name string
function ns.BoardSound(name)
	local id = assert(ns.BOARD_SOUNDS[name], "the board has no sound " .. tostring(name))
	if MOTION_TIED[name] and not ns.MotionOn() then
		return
	end
	PlaySound(id, "SFX")
end

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
	gilt = tint("e8c96a"), -- the "show completed" box's edge
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
	chipText = tint("3a2614"),
	here = tint("2a6a2a"), -- "you're here"
	unconfirmed = tint("6a3a8a"), -- the unconfirmed chip's words
	--- Tier trims (HNT-R18), by ns.Trim's names: the medallions' rings and the trims' other uses.
	trims = { bronze = tint("a8652a"), silver = tint("c9ccd3"), gold = tint("f2c230") },
	--- The tier marks' inks on the ladder, by trim.
	tierInks = { bronze = tint("c0844a"), silver = tint("b8bec6"), gold = tint("d8a93a") },
	--- Group dots (HNT-R76), by HuntGroup: Now green, Soon amber, Later grey, On demand blue; bright over the world, in
	--- the tracker's native look, and in ink on paper.
	--- Pagle Wagers (HNT-R161) have the WAGERS group's oxblood, the Pagle Wagers ribbon's (variant B's `--oxblood`).
	groups = {
		now = tint("4aa84a"),
		soon = tint("e0a030"),
		later = tint("8a8a8a"),
		onDemand = tint("4a8ad0"),
		wagers = tint("c04a30"),
	},
	paperGroups = {
		now = tint("3a8a3a"),
		soon = tint("c89030"),
		later = tint("8a8070"),
		onDemand = tint("3a6aa0"),
		wagers = tint("8a2a1a"),
	},
	oxblood = tint("8a2a1a"), -- Pagle Wagers: the run's bar, its mark, the strip's edge (HNT-R161)
	stripPaper = tint("fbf4df"), -- the wager strip's paper, pinned over the page
	runWashAlpha = 0.12, -- the run's bar's oxblood wash
	--- The Pagle Wagers spread's own (HNT-R162, HNT-R163; data/art/wagers/art.json's `look`), a fourth value its alpha:
	pencil = tint("6a6a6a"), -- "needs skill {n}" (HNT-R156): pencil grey, never red
	spent = tint("8a7a60"), -- a settled run's dial
	holiday = tint("2a6a3a"), -- a holiday's tag and chip
	tagText = tint("f4ecd8"), -- the words on them
	oxbloodWash = { 0x8a / 255, 0x2a / 255, 0x1a / 255, 0.07 }, -- the pay boxes' wash…
	oxbloodRing = { 0x8a / 255, 0x2a / 255, 0x1a / 255, 0.3 }, -- …and their rim
	aheadDash = { 0x6a / 255, 0x4a / 255, 0x28 / 255, 0.55 }, -- a run ahead's dashes, and the empty box's
	hintDash = { 0x8a / 255, 0x2a / 255, 0x1a / 255, 1 }, -- the hint slip's dashes
	hintPaper = { 0xff / 255, 0xf8 / 255, 0xe8 / 255, 0.55 }, -- the hint slip's paper
	rowRule = { 0xc4 / 255, 0xa8 / 255, 0x74 / 255, 0.55 }, -- under each Hunt's row in the run's entry
	huntsRule = { 0xc4 / 255, 0xa8 / 255, 0x74 / 255, 0.8 }, -- over the rows
	secRule = { 0xc4 / 255, 0xa8 / 255, 0x74 / 255, 1 }, -- after a section's heading, fading out
	barTrack = { 0x5a / 255, 0x3a / 255, 0x14 / 255, 0.14 }, -- a Hunt's ink bar: its track…
	barEdge = { 0x5a / 255, 0x3a / 255, 0x14 / 255, 0.45 }, -- …its edge…
	barInk = { 0x23 / 255, 0x40 / 255, 0x7a / 255, 0.75 }, -- …its ink…
	barInkGot = { 0x8a / 255, 0x2a / 255, 0x1a / 255, 0.75 }, -- …in oxblood once it has its first mark
	strike = { 0x5a / 255, 0x40 / 255, 0x28 / 255, 0.6 }, -- through a closed ticket's name
	--- Ribbons: the Board's, then set colours in turn, in Hunt list order.
	boardRibbon = tint("2e4a3a"),
	ribbons = { tint("2f5a8a"), tint("2f7a4a"), tint("8a5a1a"), tint("6a3a7a"), tint("8a2a1a") },
}
local LOOK = ns.BOARD_LOOK

--- In-client textures the board still draws: the white disc, and the pointing hand, which the kit leaves out. Each is a
--- file the forever client's FrameXML names (Gethe/wow-ui-source branch forever at
--- 943764493e6b16d63ded3ab304150d1f05e58b57).
ns.BOARD_TEXTURES = {
	-- A white disc (CharacterFrame's portrait mask): dots, and the round mask over an item's icon.
	disc = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- The pointing hand (the gauntlet cursor).
	hand = "Interface\\Cursor\\Point",
	-- The mark at the ruler's end of a run that outlasts it (HNT-R161's ▸, which the client's fonts lack, CORE-R9): the
	-- menus' submenu arrow, Blizzard_Menu/MenuVariants.lua's `arrow:SetTexture`.
	more = "Interface\\ChatFrame\\ChatFrameExpandArrow",
}
local TEXTURES = ns.BOARD_TEXTURES

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
---@field clock Font     -- the realm clock (14, shadowed)
---@field check Font     -- "show completed" (italic 13.5, shadowed)
---@field tier Font      -- a tier's threshold (Marcellus, 15)
---@field seal Font      -- a seal's date (13.5)
---@field sealSmall Font -- a seal's word and year (IM Fell, 9.5)
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
			clock = font("gilt", 14, true),
			check = font("italic", 13.5, true),
			tier = font("gilt", 15),
			seal = font("gilt", 13.5),
			sealSmall = font("print", 9.5),
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
--- edges on `layer` (BORDER by default) at `sublevel`. The selected row's dashes, the wager slips and the companion's
--- card each draw one.
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
---@field fillFrame Frame        -- holds the cut stroke, over the empty one
---@field label FontString
---@field value number
---@field SetBar fun(self: BoardInkBarView, fill: number, label: string?, animate: boolean?) -- with `animate`, a fill
--- that grows runs on

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
	-- the full stroke on its own frame over the empty one's, which a child frame would otherwise draw over
	bar.fillFrame = CreateFrame("Frame", nil, bar)
	bar.fillFrame:SetAllPoints()
	bar.fillFrame:SetFrameLevel(bar.empty:GetFrameLevel() + 1)
	bar.fill = ns.ArtCrisp(bar.fillFrame:CreateTexture(nil, "ARTWORK"))
	bar.fillSlice = CreateFrame("Frame", nil, bar) --[[@as HuntsThreeSlice]]
	bar.fillSlice:SetPoint("TOPLEFT")
	bar.fillSlice:SetFrameLevel(bar.empty:GetFrameLevel() + 1)
	bar.label = ns.BoardText(bar, ns.BoardFonts().inkCount, LOOK.ink)
	bar.label:SetPoint("LEFT", bar, "RIGHT", 10, 1)
	bar.value = 0
	local _, sprite = ns.ArtSpriteOf("Parts", "ink-full")
	local spriteLength = sprite.box[3]
	-- Inks the bar to `fill` of its width.
	local function ink(fill)
		local length = width * fill
		local cut = length > 0 and length <= spriteLength
		local slice = length > spriteLength
		if cut then
			local shown = ns.SetCrop(bar.fill, "Parts", "ink-full", length)
			ns.PlaceSprite(shown, bar, 0, 0)
		elseif slice then
			ns.SetThreeSlice(bar.fillSlice, "Parts", "ink-full", length, INK_CAP, "ARTWORK", 0)
		end
		bar.fill:SetShown(cut)
		bar.fillSlice:SetShown(slice)
	end
	function bar.SetBar(self, fill, label, animate)
		fill = math.max(0, math.min(1, fill))
		local from = self.value
		self.label:SetText(label or "")
		self.value = fill
		Pagle.StopMotion(self)
		if not (animate and fill > from and self:IsVisible() and ns.MotionOn()) then
			self.label:SetAlpha(1)
			ink(fill)
			return
		end
		-- a catch: the ink runs on (0.6 s, ease-out) and its words fade up from 30% (0.3 s)
		Pagle.Animate(self, {
			{
				dur = 0.6,
				ease = Pagle.EASE.out,
				keys = { { 0, { from } }, { 1, { fill } } },
				apply = function(v)
					ink(v[1])
				end,
			},
			{
				dur = 0.3,
				ease = Pagle.EASE.out,
				keys = { { 0, { 0.3 } }, { 1, { 1 } } },
				apply = function(v)
					self.label:SetAlpha(v[1])
				end,
			},
		})
	end
	return bar
end

--- A bar on the timeline (HNT-R63), in one of its styles, each the kit's own stroke:
---   "hatched"  open: hatched ink
---   "dashed"   the window is unconfirmed: faint hatching in a dashed outline
---   "pencil"   short of skill: a pencil outline, nothing inside
---   "camp"     the camp is up: solid blue
---   "run"      a Pagle Wagers run's days (HNT-R161): the pencil outline inked oxblood over a faint oxblood wash
---   "wager"    a timed event Hunt's window over its run's bar (HNT-R161): the hatch inked red
--- A bar is cut to length, never squeezed, and keeps its own right end, so both ends stay square-on. adapter/Timeline.lua
--- anchors it on the ruler and gives each its width.
---@alias BoardBarStyle "hatched"|"dashed"|"pencil"|"camp"|"run"|"wager"

---@class BoardTimelineBarView: Frame
---@field body Texture
---@field tip Texture
---@field wash Texture
---@field style BoardBarStyle
---@field SetBar fun(self: BoardTimelineBarView, style: BoardBarStyle, width: number)

--- Each bar style's sprite.
---@type table<BoardBarStyle, string>
ns.BOARD_BAR_SPRITES = {
	hatched = "bar-hatch",
	dashed = "bar-dash",
	pencil = "bar-pencil",
	camp = "bar-blue",
	run = "bar-pencil",
	wager = "bar-hatch",
}

--- The inks Pagle Wagers' styles lay over their strokes, as vertex colours: the kit has no oxblood bar, so the pencil
--- outline and the brown hatch are tinted towards the WAGERS group's oxblood. The other styles keep their own ink.
---@type table<BoardBarStyle, number[]>
ns.BOARD_BAR_INKS = { run = tint("e64d3a"), wager = tint("ff8c9e") }

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
	-- a run's wash, inside the outline's box
	bar.wash = ns.BoardSolid(bar, LOOK.oxblood, "BACKGROUND", LOOK.runWashAlpha)
	bar.wash:ClearAllPoints()
	bar.wash:SetPoint("TOPLEFT", 0, -1)
	bar.wash:SetPoint("BOTTOMRIGHT", 0, 1)
	function bar.SetBar(self, style, width)
		local name = assert(ns.BOARD_BAR_SPRITES[style], "a timeline bar has no style " .. tostring(style))
		local ink = ns.BOARD_BAR_INKS[style] or { 1, 1, 1 }
		for _, texture in ipairs({ self.body, self.tip }) do
			texture:SetVertexColor(ink[1], ink[2], ink[3], 1)
		end
		self.wash:SetShown(style == "run")
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
---@field group (HuntGroup|"wagers")?
---@field SetGroup fun(self: BoardDotView, group: HuntGroup|"wagers", paper: boolean?)

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

--- The pointing hand before "back to {set}" (HNT-R66), in red ink: a texture, never a font glyph (HNT-R60).
---@param parent Frame
---@param size number
---@return Texture
function ns.NewBoardHand(parent, size)
	local texture = parent:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(TEXTURES.hand)
	texture:SetSize(size, size)
	texture:SetDesaturated(true)
	texture:SetVertexColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	return texture
end

--- The "show completed" box on the leather (HNT-R61, HNT-R82): a small gilt-edged box, filled with the kit's gilt
--- gradient when ticked, and its words in italic. `Sync` shows the fill as the box's state.
---@class BoardCheckButton: CheckButton
---@field Text FontString
---@field tick Texture
---@field Sync fun(self: BoardCheckButton)

-- The box's size, and the fill's inset.
local CHECK_SIZE, TICK_INSET = 14, 1.5

---@param parent Frame
---@return BoardCheckButton
function ns.NewBoardCheck(parent)
	local check = CreateFrame("CheckButton", nil, parent) --[[@as BoardCheckButton]]
	check:SetSize(CHECK_SIZE, CHECK_SIZE)
	ns.BoardSolid(check, LOOK.gilt, "BACKGROUND")
	local well = ns.BoardSolid(check, tint("1a1008"), "BORDER")
	well:SetPoint("TOPLEFT", 1.5, -1.5)
	well:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
	check.tick = ns.BoardSolid(check, { 1, 1, 1 }, "ARTWORK")
	check.tick:SetPoint("TOPLEFT", TICK_INSET, -TICK_INSET)
	check.tick:SetPoint("BOTTOMRIGHT", -TICK_INSET, TICK_INSET)
	-- the gilt gradient, darker at the foot (the gradient's first colour is the bottom's)
	check.tick:SetGradient("VERTICAL", CreateColor(0.75, 0.57, 0.18, 1), CreateColor(0.96, 0.86, 0.54, 1))
	check.Text = ns.BoardText(check, ns.BoardFonts().check, LOOK.checkLabel)
	check.Text:SetPoint("LEFT", check, "RIGHT", 7, 0)
	function check.Sync(self)
		self.tick:SetShown(self:GetChecked() == true)
	end
	return check
end
