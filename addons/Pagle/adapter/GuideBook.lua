---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Field guide's book (ONB-R20, ONB-R24, ONB-R27): Core's own fork of the Stats book's shell
-- (Pagle_Stats/adapter/BookWidgets.lua's leather, parchment and wax close, adapter/Book.lua's build and ribbons,
-- adapter/BookMotion.lua's page turn), trimmed to what the guide draws and drawn on Core's media/books
-- (data/GuideArt.lua's Book atlas): a leather binding with two parchment pages, the gilt strip above them with the
-- crumbs "Pagle · A field guide" and "{n} of {m}" at its right, the wax close past its top right, and the step
-- ribbons hanging under its bottom edge (adapter/GuideKit.lua's), over a dim of the world. Core can't call into a
-- Module (ADR 0001), so the shell is copied, not shared; a shared book API is #319. The Stats book's brass corners,
-- nameplate, live line and search slip aren't drawn: the guide's canvas boards (prototypes/onboarding-kit, boards 2–9)
-- have none. adapter/Guide.lua drives it.

--- The book's measures (ONB-R20, ONB-R27; Tunables), in UI units: the frame, its leather at the sides, the strip
--- above the pages and the band under them, each page, the whole extent fitted to the screen (the wax close and the
--- ribbons with it), how far above the screen's centre it opens (half the ribbons' hang), the world's dim behind it,
--- and its fades (MOTION.md: opening 0.16 s, closing 0.12 s).
ns.GUIDE_BOOK = {
	width = 920,
	height = 600,
	side = 18,
	strip = 38,
	foot = 16,
	pageWidth = 442,
	pageHeight = 546,
	extentWidth = 950,
	extentHeight = 760,
	lift = 40,
	dim = 0.58,
	openFade = 0.16,
	closeFade = 0.12,
}
local BOOK = ns.GUIDE_BOOK

-- The binding: the band's width, where the tiled grain starts under it, and the grain's repeat.
local BAND, FILL_INSET, LEATHER_TILE = 16, 7, 128
-- The gutter's shade at the spine.
local GUTTER_WIDTH = 40
-- A page's rounded outer corners (Core's media/books corner masks).
local CORNER_RADIUS = 6
local CORNER_MASKS = {
	TOPLEFT = "Interface\\AddOns\\Pagle\\media\\books\\CornerTL",
	TOPRIGHT = "Interface\\AddOns\\Pagle\\media\\books\\CornerTR",
	BOTTOMLEFT = "Interface\\AddOns\\Pagle\\media\\books\\CornerBL",
	BOTTOMRIGHT = "Interface\\AddOns\\Pagle\\media\\books\\CornerBR",
}
-- The first ribbon's place from the book's left, the ribbons' gap, and where they hang from (the kit's 40 and 586).
local RIBBONS_LEFT = 40

-- Shows `texture` the texels `x0`..`x0 + w`, `y0`..`y0 + h` of `atlas`.
---@param texture Texture
---@param atlas PagleAtlas
---@param x0 number
---@param y0 number
---@param w number
---@param h number
local function cut(texture, atlas, x0, y0, w, h)
	texture:SetTexture(atlas.file)
	texture:SetTexCoord(x0 / atlas.width, (x0 + w) / atlas.width, y0 / atlas.height, (y0 + h) / atlas.height)
end

--- The leather binding on a book's frame (the Stats book's NewBookLeather): the tiled grain, darker toward the foot,
--- under the leather's vignette, and the binding band, nine-sliced on its own frame six levels up, so a ribbon's
--- tucked top hides under it.
---@class PagleGuideLeather
---@field fill Texture
---@field vignette Texture
---@field band Frame

---@param frame Frame
---@return PagleGuideLeather
function ns.NewGuideLeather(frame)
	local crisp = ns.ArtCrisp
	local fill = crisp(frame:CreateTexture(nil, "BACKGROUND", nil, 0))
	fill:SetTexture(ns.BOOK_FILES.leather, "REPEAT", "REPEAT")
	fill:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
	fill:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
	-- darker toward the foot, as the canvas shades it (the gradient's first colour is the bottom's)
	fill:SetGradient("VERTICAL", CreateColor(0.8, 0.8, 0.8, 1), CreateColor(1, 1, 1, 1))
	local width, height = frame:GetSize()
	fill:SetTexCoord(0, (width - 2 * FILL_INSET) / LEATHER_TILE, 0, (height - 2 * FILL_INSET) / LEATHER_TILE)
	local book = ns.ATLASES.Book
	local vignette = crisp(frame:CreateTexture(nil, "BACKGROUND", nil, 1))
	local sprite = book.sprites.vignette
	cut(vignette, book, sprite.x + 1, sprite.y + 1, sprite.w - 2, sprite.h - 2)
	vignette:SetAllPoints(fill)
	local band = CreateFrame("Frame", nil, frame)
	band:SetAllPoints()
	band:SetFrameLevel(frame:GetFrameLevel() + 6)
	-- The band's nine slices from the 96-texel binding sprite: 32-texel corners, the edges stretched from a 2-texel
	-- slice.
	local binding = book.sprites.binding
	local function piece(sx, sy, sw, sh)
		local texture = crisp(band:CreateTexture(nil, "BORDER"))
		cut(texture, book, binding.x + sx, binding.y + sy, sw, sh)
		return texture
	end
	local tl, tr = piece(0, 0, 32, 32), piece(64, 0, 32, 32)
	local bl, br = piece(0, 64, 32, 32), piece(64, 64, 32, 32)
	for _, corner in ipairs({ tl, tr, bl, br }) do
		corner:SetSize(BAND, BAND)
	end
	tl:SetPoint("TOPLEFT")
	tr:SetPoint("TOPRIGHT")
	bl:SetPoint("BOTTOMLEFT")
	br:SetPoint("BOTTOMRIGHT")
	local top, bottom = piece(47, 0, 2, 32), piece(47, 64, 2, 32)
	local left, right = piece(0, 47, 32, 2), piece(64, 47, 32, 2)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
	top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	return { fill = fill, vignette = vignette, band = band }
end

--- A parchment page on `frame`, filling it (the Stats book's NewBookParchment): the books' parchment, mirrored on a
--- right page so the two don't match, its outer corners slightly rounded, and the gutter's shade along the spine.
---@class PagleGuideParchment
---@field paper Texture
---@field gutter Texture

---@param frame Frame
---@param spine "LEFT"|"RIGHT" the side its spine is on: a left page's is on its right
---@return PagleGuideParchment
function ns.NewGuideParchment(frame, spine)
	local crisp = ns.ArtCrisp
	local paper = crisp(frame:CreateTexture(nil, "BACKGROUND"))
	paper:SetTexture(ns.BOOK_FILES.parchment)
	paper:SetAllPoints()
	if spine == "LEFT" then
		paper:SetTexCoord(1, 0, 0, 1)
	end
	for _, corner in ipairs(spine == "RIGHT" and { "TOPLEFT", "BOTTOMLEFT" } or { "TOPRIGHT", "BOTTOMRIGHT" }) do
		local mask = frame:CreateMaskTexture()
		mask:SetTexture(CORNER_MASKS[corner], "CLAMPTOWHITE", "CLAMPTOWHITE")
		mask:SetSize(CORNER_RADIUS, CORNER_RADIUS)
		mask:SetPoint(corner, paper, corner)
		paper:AddMaskTexture(mask)
	end
	local book = ns.ATLASES.Book
	local sprite = book.sprites.gutter
	local gutter = crisp(frame:CreateTexture(nil, "BORDER"))
	gutter:SetTexture(book.file)
	local left, right = (sprite.x + 1) / book.width, (sprite.x + sprite.w - 1) / book.width
	local top, bottom = (sprite.y + 1) / book.height, (sprite.y + sprite.h - 1) / book.height
	if spine == "LEFT" then
		gutter:SetTexCoord(right, left, top, bottom)
	else
		gutter:SetTexCoord(left, right, top, bottom)
	end
	gutter:SetWidth(GUTTER_WIDTH)
	gutter:SetPoint("TOP" .. spine)
	gutter:SetPoint("BOTTOM" .. spine)
	return { paper = paper, gutter = gutter }
end

--- The wax close button (the Stats book's NewBookClose): a round seal of red wax with a cross, pressed when clicked,
--- glowing under the mouse.
---@class PagleGuideCloseButton: Button
---@field normal Texture
---@field pushed Texture
---@field glow Texture

---@param parent Frame
---@return PagleGuideCloseButton
function ns.NewGuideClose(parent)
	local close = CreateFrame("Button", nil, parent) --[[@as PagleGuideCloseButton]]
	close:SetSize(26, 26)
	local function layer(name, drawLayer, sublevel)
		local texture = ns.ArtSprite(close, "Book", name, drawLayer, sublevel)
		texture:SetAllPoints()
		return texture
	end
	close.normal = layer("close", "ARTWORK", 0)
	close.pushed = layer("close-pushed", "ARTWORK", 1)
	close.pushed:Hide()
	close.glow = layer("close-highlight", "HIGHLIGHT", 0)
	close.glow:SetBlendMode("ADD")
	close:SetScript("OnMouseDown", function(self)
		self.pushed:Show()
	end)
	close:SetScript("OnMouseUp", function(self)
		self.pushed:Hide()
	end)
	return close
end

-- The page turn (the Stats book's adapter/BookMotion.lua, the kit's Views.lua). Each step's page draws inside a clip
-- frame on its paper, whose visible strip can be narrowed from either edge, so a turn is two complementary wipes,
-- with no frame levels changed: forward, the right page lifts away toward the spine, uncovering the new right page
-- (0.22 s, speeding up), then lands on the left from the spine outward, covering the old left page (0.28 s,
-- settling). Backward is the mirror image. A fold shade darkens the lifting page (up to 28%) and a 26-unit shadow
-- falls beside the moving edge, with a 1.5-unit light line on the edge itself; both fade as the page lands.

--- One page of one step as the turn sees it: the clip frame on its paper, and the paper.
---@class PagleGuideTurnSide
---@field clip Frame
---@field paper Frame

--- The turn's halves, in seconds.
ns.GUIDE_TURN = { lift = 0.22, land = 0.28 }
local TURN = ns.GUIDE_TURN
-- The fold's shade at its darkest, its cast shadow's width and darkness, and the edge's light.
local SHADE, CAST_WIDTH, CAST_DARK, EDGE_WIDTH, EDGE_LIGHT = 0.28, 26, 0.32, 1.5, 0.55

--- Shows only the strip [a, b] (shares of the paper's width) of `side`; none when it is (near) empty.
---@param side PagleGuideTurnSide?
---@param a number
---@param b number
function ns.RevealGuideSide(side, a, b)
	if not side then
		return
	end
	local clip, paper = side.clip, side.paper
	if b - a <= 0.002 then
		clip:Hide()
		return
	end
	local width = paper:GetWidth()
	clip:Show()
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", paper, "TOPLEFT", a * width, 0)
	clip:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", a * width, 0)
	clip:SetWidth((b - a) * width)
end

---@class PagleGuideFold: Frame
---@field shade Texture
---@field cast Texture
---@field edge Texture

--- The fold over `book`'s pages: a shade over the turning strip and a cast shadow beside its edge, made once.
---@param book PagleGuideBookFrame
---@return PagleGuideFold
local function foldOf(book)
	local fold = book.turnFold
	if fold then
		return fold
	end
	fold = CreateFrame("Frame", nil, book) --[[@as PagleGuideFold]]
	fold:SetAllPoints()
	fold:SetFrameLevel(book:GetFrameLevel() + 40)
	fold.shade = fold:CreateTexture(nil, "OVERLAY", nil, 0)
	fold.shade:SetColorTexture(0.16, 0.08, 0.02, 1)
	fold.cast = fold:CreateTexture(nil, "OVERLAY", nil, 1)
	fold.cast:SetColorTexture(1, 1, 1, 1)
	fold.edge = fold:CreateTexture(nil, "OVERLAY", nil, 2)
	fold.edge:SetColorTexture(1, 0.97, 0.85, 1)
	fold:Hide()
	book.turnFold = fold
	return fold
end

-- Places the fold: the turning strip [x0, x1] on `paper` (units from its left), its moving edge at `ex`, the cast
-- shadow on the side `side` names (-1 left of the edge, 1 right of it).
---@param fold PagleGuideFold
---@param paper Frame
---@param x0 number
---@param x1 number
---@param ex number
---@param side integer
---@param shade number
---@param cast number
local function placeFold(fold, paper, x0, x1, ex, side, shade, cast)
	fold.shade:ClearAllPoints()
	fold.shade:SetPoint("TOPLEFT", paper, "TOPLEFT", x0, 0)
	fold.shade:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", x0, 0)
	fold.shade:SetWidth(math.max(0.01, x1 - x0))
	fold.shade:SetAlpha(shade)
	local castX = side > 0 and ex or ex - CAST_WIDTH
	fold.cast:ClearAllPoints()
	fold.cast:SetPoint("TOPLEFT", paper, "TOPLEFT", castX, 0)
	fold.cast:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", castX, 0)
	fold.cast:SetWidth(CAST_WIDTH)
	local dark, clear = CreateColor(0.12, 0.06, 0.02, CAST_DARK * cast), CreateColor(0.12, 0.06, 0.02, 0)
	if side > 0 then
		fold.cast:SetGradient("HORIZONTAL", dark, clear)
	else
		fold.cast:SetGradient("HORIZONTAL", clear, dark)
	end
	local edgeX = ex - (side > 0 and EDGE_WIDTH or 0)
	fold.edge:ClearAllPoints()
	fold.edge:SetPoint("TOPLEFT", paper, "TOPLEFT", edgeX, 0)
	fold.edge:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", edgeX, 0)
	fold.edge:SetWidth(EDGE_WIDTH)
	fold.edge:SetAlpha(EDGE_LIGHT * cast)
end

--- A turn between two steps: each one's pages, by "left" and "right".
---@class PagleGuideTurn
---@field from table<"left"|"right", PagleGuideTurnSide>
---@field to table<"left"|"right", PagleGuideTurnSide>
---@field forward boolean
---@field papers table<"left"|"right", Frame>
---@field midway fun()    -- at the spine: the count changes
---@field done fun()      -- when it has landed, or at once with Animations off

--- Plays `turn` on `book`, the books' two halves, with the page-turn sound; settled at once, silently, with
--- Animations off. Returns the owner it plays on, which Pagle.StopMotion cuts short (the caller then settles it).
---@param book PagleGuideBookFrame
---@param turn PagleGuideTurn
---@return table owner
function ns.PlayGuideTurn(book, turn)
	local owner = {}
	local from, to, papers = turn.from, turn.to, turn.papers
	local leftWidth, rightWidth = papers.left:GetWidth(), papers.right:GetWidth()
	local fold = foldOf(book)
	local function settle()
		fold:Hide()
		turn.done()
	end
	if not Pagle.IsAnimationsOn() then
		turn.midway()
		settle()
		return owner
	end
	ns.GuideSound("pageTurn")
	fold:Show()
	local forward = turn.forward
	if forward then
		ns.RevealGuideSide(to.left, 1, 1)
		ns.RevealGuideSide(from.left, 0, 1)
	else
		ns.RevealGuideSide(to.right, 0, 0)
		ns.RevealGuideSide(from.right, 0, 1)
	end
	Pagle.Animate(owner, {
		-- first half: the page lifts toward the spine
		{
			dur = TURN.lift,
			ease = Pagle.Bezier(0.5, 0, 0.9, 0.6),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if forward then
					ns.RevealGuideSide(from.right, 0, 1 - k)
					ns.RevealGuideSide(to.right, 1 - k, 1)
					placeFold(fold, papers.right, 0, (1 - k) * rightWidth, (1 - k) * rightWidth, 1, SHADE * k, 1)
				else
					ns.RevealGuideSide(from.left, k, 1)
					ns.RevealGuideSide(to.left, 0, k)
					placeFold(fold, papers.left, k * leftWidth, leftWidth, k * leftWidth, -1, SHADE * k, 1)
				end
			end,
			done = turn.midway,
		},
		-- second half: it lands on the other page, from the spine outward
		{
			dur = TURN.land,
			delay = TURN.lift,
			ease = Pagle.Bezier(0.1, 0.4, 0.4, 1),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if k <= 0 then
					return
				end
				if forward then
					ns.RevealGuideSide(from.right, 0, 0)
					ns.RevealGuideSide(to.right, 0, 1)
					ns.RevealGuideSide(to.left, 1 - k, 1)
					ns.RevealGuideSide(from.left, 0, 1 - k)
					local x = (1 - k) * leftWidth
					placeFold(fold, papers.left, x, leftWidth, x, -1, SHADE * (1 - k), 1 - k)
				else
					ns.RevealGuideSide(from.left, 0, 0)
					ns.RevealGuideSide(to.left, 0, 1)
					ns.RevealGuideSide(to.right, 0, k)
					ns.RevealGuideSide(from.right, k, 1)
					placeFold(fold, papers.right, 0, k * rightWidth, k * rightWidth, 1, SHADE * (1 - k), 1 - k)
				end
			end,
		},
	}, settle)
	return owner
end

--- The guide's book frame (PagleGuide, in UISpecialFrames so Esc closes it, ONB-R20).
---@class PagleGuideBookFrame: Frame
---@field dim Frame                                   -- the world's dim behind it, at 0.58
---@field leather PagleGuideLeather
---@field papers table<"left"|"right", Frame>         -- each page's paper, which the turn's wipes measure
---@field parchments table<"left"|"right", PagleGuideParchment>
---@field crumbs FontString[]                         -- "Pagle", "A field guide"
---@field fleuron Texture                             -- between them
---@field count FontString                            -- "{n} of {m}" at the strip's right
---@field close PagleGuideCloseButton
---@field ribbons PagleGuideRibbonView[]
---@field turnFold PagleGuideFold?

--- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (ONB-R20).
ns.GUIDE_FRAME_NAME = "PagleGuide"

-- A page's paper on the frame, the side's place under the strip.
---@param frame PagleGuideBookFrame
---@param side "left"|"right"
local function buildPage(frame, side)
	local paper = CreateFrame("Frame", nil, frame)
	paper:SetSize(BOOK.pageWidth, BOOK.pageHeight)
	paper:SetPoint("TOPLEFT", side == "left" and BOOK.side or BOOK.side + BOOK.pageWidth, -BOOK.strip)
	-- the paper takes the mouse, so a click on a page never reaches the world behind the book
	paper:EnableMouse(true)
	frame.papers[side] = paper
	frame.parchments[side] = ns.NewGuideParchment(paper, side == "left" and "RIGHT" or "LEFT")
end

-- The strip's crumbs, "Pagle" ❧ "A field guide", and "{n} of {m}" at its right, in gilt on the leather.
---@param frame PagleGuideBookFrame
local function buildStrip(frame)
	local middle = -(FILL_INSET + BOOK.strip) / 2
	local first = ns.GuideText(frame, "gilt", 14, "crumb", ns.L.GUIDE_CRUMB_PAGLE, { shadow = true })
	first:SetPoint("LEFT", frame, "TOPLEFT", BOOK.side + 6, middle)
	frame.fleuron = ns.ArtSprite(frame, "Book", "fleuron", "OVERLAY")
	frame.fleuron:SetSize(16, 16)
	frame.fleuron:SetPoint("LEFT", first, "RIGHT", 8, 0)
	local second = ns.GuideText(frame, "gilt", 14, "crumb", ns.L.GUIDE_CRUMB_GUIDE, { shadow = true })
	second:SetPoint("LEFT", frame.fleuron, "RIGHT", 8, 0)
	frame.crumbs = { first, second }
	frame.count = ns.GuideText(frame, "gilt", 14, "count", "", { shadow = true, justify = "RIGHT" })
	frame.count:SetPoint("RIGHT", frame, "TOPRIGHT", -(BOOK.side + 6), middle)
end

--- Builds the guide's book, hidden, with a ribbon for each of `count` steps (more are added as asked for, ns.
--- GuideRibbonAt): the dim, the leather, two pages, the strip, the ribbons and the wax close. `onClose` is the wax
--- close's click, `onHidden` runs as the frame hides however it hides (Esc through UISpecialFrames, the close's fade),
--- and `onRibbon(i)` is ribbon i's click.
---@param count integer
---@param onClose fun()
---@param onHidden fun()
---@param onRibbon fun(index: integer)
---@return PagleGuideBookFrame
function ns.NewGuideBook(count, onClose, onHidden, onRibbon)
	local dim = CreateFrame("Frame", nil, UIParent)
	dim:SetAllPoints(UIParent)
	dim:SetFrameStrata("HIGH")
	-- the game keeps running behind it, and the dim takes no clicks from the world (ONB-R71)
	dim:EnableMouse(false)
	local shade = dim:CreateTexture(nil, "BACKGROUND")
	shade:SetColorTexture(0x06 / 255, 0x08 / 255, 0x08 / 255, BOOK.dim)
	shade:SetAllPoints()
	dim:Hide()

	local frame = CreateFrame("Frame", ns.GUIDE_FRAME_NAME, UIParent) --[[@as PagleGuideBookFrame]]
	frame:SetSize(BOOK.width, BOOK.height)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame.dim = dim
	frame.leather = ns.NewGuideLeather(frame)
	frame.papers, frame.parchments = {}, {}
	buildPage(frame, "left")
	buildPage(frame, "right")
	buildStrip(frame)
	frame.ribbons = {}
	for i = 1, count do
		ns.GuideRibbonAt(frame, i, onRibbon)
	end
	frame.close = ns.NewGuideClose(frame)
	frame.close:SetPoint("CENTER", frame, "TOPRIGHT", -3, -3)
	frame.close:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.close:SetScript("OnClick", onClose)
	frame:Hide()
	-- Esc hides it (CloseSpecialWindows). Hiding UIParent (Alt-Z, a cinematic) also runs OnHide but leaves it shown:
	-- that isn't the guide closing.
	frame:SetScript("OnHide", function(self)
		if not self:IsShown() then
			onHidden()
		end
	end)
	table.insert(UISpecialFrames, ns.GUIDE_FRAME_NAME)
	return frame
end

--- Ribbon `i` under `frame`'s bottom edge, made on first use (ONB-R24): left to right from 40 in, 98 wide with an
--- 8-unit gap, its top tucked 14 units under the band (the ribbon is a level under it), clicked to turn to its step.
---@param frame PagleGuideBookFrame
---@param i integer
---@param onRibbon fun(index: integer)
---@return PagleGuideRibbonView
function ns.GuideRibbonAt(frame, i, onRibbon)
	local ribbon = frame.ribbons[i]
	if not ribbon then
		local sizes = ns.GUIDE_RIBBON
		ribbon = ns.NewGuideRibbon(frame)
		ribbon:SetFrameLevel(frame:GetFrameLevel() + 1)
		ribbon:SetPoint(
			"TOPLEFT",
			frame,
			"TOPLEFT",
			RIBBONS_LEFT + (i - 1) * (sizes.width + sizes.gap),
			-(BOOK.height - sizes.tuck)
		)
		ribbon:SetScript("OnClick", function()
			onRibbon(i)
		end)
		frame.ribbons[i] = ribbon
	end
	return ribbon
end
