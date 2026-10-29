---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The book binding on the client (core/book-binding.md, ADR 0015): Pagle.NewBookBinding, logic/BookBinding.lua's
-- bindings over Core's goods, motion driver and sound, each book's binding drawn on its own frame here. It is the one
-- renderer of the four leathers the books drew for themselves (the Field guide's, the Stats book's, the Hunts board's
-- and the Fish Journal's): the material tiled or stretched and shaded toward its foot, the vignette, the band
-- nine-sliced and toned, the corner pieces, Tooled Leather's double gilt rule and Verdigris's gilt corner, and a whole
-- book's own corner art, clasp, ribbon and fillet (the Curio Shop's second round's), all on Core's art
-- (data/GuideArt.lua's Book atlas, data/BookBindingArt.lua's).

-- The owner of its AppearanceChanged listener on Core's bus (CORE-R23): its own, so no other Core file's registration
-- replaces it.
local OWNER = "Pagle book binding"

-- The measures (BIND-R10–R12), in UI units: how far in the material starts (under the band's opaque lines), the band's
-- corners, the corner pieces and the gilt corner, and the tooled rule's insets, width and gilt (the kit's #d8b660).
local INSET, BAND = 7, 16
local CORNER_SIZE, GILT_CORNER_SIZE = 44, 40
local RULE_INSETS, RULE_WIDTH = { 9, 12 }, 1.5
local RULE_GILT = { 0xd8 / 255, 0xb6 / 255, 0x60 / 255 }
-- A whole book's parts (BIND-R14–R17), at the corner pieces' 44: its own corner art's size and how far it stands out
-- past each corner; the ribbon's top left across from the centre of the pages (or the frame), and how far up into the
-- pages' foot it starts (or up from the frame's foot, without pages); and the fillet's inset, width and alpha. All from
-- the round-two kit's 920 × 600 Journal, its pages 884 × 546 at 18, 38. The ribbon shows only its foot, the notched end:
-- RIBBON_SHOWN units tall, so that from RIBBON_UP above the frame's foot only RIBBON_TAIL hangs below it, enough to read
-- as a bookmark and no more on the screen under the book; the silk's upper end is cropped away.
local CORNER_ART, CORNER_OUT = 76, 4
-- The clasp's right edge passes the frame's right edge by this much, the lip of its strap, so that it lies on the
-- fore-edge, over the band and the cover, as the binding's own cover art shows it, and never stands out over the screen
-- (BIND-R14). Its sprites differ in width (50 to 96 units), so it is its right edge that is anchored, not its left.
local CLASP_LIP = 6
local RIBBON_X, RIBBON_IN, RIBBON_UP, RIBBON_TAIL = 60, 24, 40, 20
local RIBBON_SHOWN = RIBBON_UP + RIBBON_TAIL
local FILLET_INSET, FILLET_WIDTH, FILLET_ALPHA = 5, 1.6, 0.75
-- The band's and the features' alpha through a dip, at the material's `alpha`: never below 0.4 (BIND-R20).
local BAND_FLOOR = 0.4
-- An untinted material: white.
local WHITE = { 1, 1, 1 }
-- The four corners, in the order the corner pieces are made: the top-left piece mirrored across for the even ones,
-- and down for the last two.
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
-- A tooled rule's four edges: the points of `frame` each is anchored between.
local EDGES = {
	{ "TOPLEFT", "TOPRIGHT" },
	{ "BOTTOMLEFT", "BOTTOMRIGHT" },
	{ "TOPLEFT", "BOTTOMLEFT" },
	{ "TOPRIGHT", "BOTTOMRIGHT" },
}

--- A book's binding as drawn (BIND-R10–R12): the regions on its frame, and the look on them.
---@class PagleBookBindingRegions: PagleBookBindingSkin
---@field frame Frame
---@field fill Texture           -- the material
---@field vignette Texture
---@field band Frame             -- six levels over the book's frame
---@field bandPieces Texture[]   -- its nine slices' eight pieces
---@field gilt Frame             -- one level over the band: the features
---@field rules Texture[]        -- the tooled rule's edges, both lines'
---@field fillets Texture[]      -- a whole book's fillet's four edges
---@field giltCorner Texture
---@field corners Texture[]      -- top left, top right, bottom left, bottom right
---@field cornerSize number      -- the metal corner pieces' size (options.cornerSize)
---@field clasp Texture          -- a whole book's clasp on the fore-edge
---@field ribbon Texture         -- a whole book's silk ribbon
---@field look PagleBindingLook? -- the look drawn
local Regions = {}
Regions.__index = Regions

-- Shows `texture` the texels `x0`..`x0 + w`, `y0`..`y0 + h` of `atlas`, mirrored across with `flipX` and down with
-- `flipY`.
---@param texture Texture
---@param atlas PagleAtlas
---@param x0 number
---@param y0 number
---@param w number
---@param h number
---@param flipX boolean?
---@param flipY boolean?
local function cut(texture, atlas, x0, y0, w, h, flipX, flipY)
	local left, right = x0 / atlas.width, (x0 + w) / atlas.width
	local top, bottom = y0 / atlas.height, (y0 + h) / atlas.height
	if flipX then
		left, right = right, left
	end
	if flipY then
		top, bottom = bottom, top
	end
	texture:SetTexture(atlas.file)
	texture:SetTexCoord(left, right, top, bottom)
end

-- The band's eight pieces on `band` (BIND-R11): the binding sprite's 32-texel corners at 16 units, its edges stretched
-- from a 2-texel slice between them.
---@param band Frame
---@return Texture[]
local function bandPieces(band)
	local book = ns.ATLASES.Book
	local binding = book.sprites.binding
	local function piece(sx, sy, sw, sh)
		local texture = ns.ArtCrisp(band:CreateTexture(nil, "BORDER"))
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
	return { tl, tr, bl, br, top, bottom, left, right }
end

-- Ruled lines on `gilt`: for each of `insets`, four edges `width` wide that far in from its own, hidden until a look
-- with them is drawn.
---@param gilt Frame
---@param insets number[]
---@param width number
---@return Texture[]
local function ruledEdges(gilt, insets, width)
	local edges = {}
	for _, inset in ipairs(insets) do
		for i, points in ipairs(EDGES) do
			local edge = gilt:CreateTexture(nil, "ARTWORK", nil, 0)
			for _, point in ipairs(points) do
				edge:SetPoint(point, point:find("RIGHT") and -inset or inset, point:find("TOP") and -inset or inset)
			end
			if i <= 2 then
				edge:SetHeight(width)
			else
				edge:SetWidth(width)
			end
			edge:Hide()
			edges[#edges + 1] = edge
		end
	end
	return edges
end

-- Tooled Leather's double rule on `gilt` (BIND-R12): two gilt lines, 9 and 12 in.
---@param gilt Frame
---@return Texture[]
local function tooledRules(gilt)
	local edges = ruledEdges(gilt, RULE_INSETS, RULE_WIDTH)
	for _, edge in ipairs(edges) do
		edge:SetColorTexture(RULE_GILT[1], RULE_GILT[2], RULE_GILT[3], 1)
	end
	return edges
end

-- Shows `texture` as `name` of `atlas` at its drawn size, or hides it for no name (BIND-R14, BIND-R15).
---@param texture Texture
---@param atlas PagleAtlas
---@param name string?
local function part(texture, atlas, name)
	local sprite = name and atlas.sprites[name]
	if sprite then
		cut(texture, atlas, sprite.x, sprite.y, sprite.w, sprite.h)
		texture:SetSize(sprite.box[3], sprite.box[4])
	end
	texture:SetShown(sprite ~= nil)
end

-- Draws `look`'s corner pieces on `regions` (BIND-R12, BIND-R17): its own corner art, 76 square standing 4 out past
-- each corner (both at the corner pieces' 44, scaled with them), or its metal's piece at the corners; each the top-left
-- one mirrored across for the even corners and down for the last two; none in a look with neither.
---@param regions PagleBookBindingRegions
---@param look PagleBindingLook
local function dressCorners(regions, look)
	local art, metal = look.cornerArt, look.corners
	local atlas, sprite, size, out
	if art then
		atlas = ns.ATLASES.BindingParts2
		sprite = atlas.sprites[art]
		local scale = regions.cornerSize / CORNER_SIZE
		size, out = CORNER_ART * scale, CORNER_OUT * scale
	elseif metal then
		atlas = ns.ATLASES.BindingCorners
		sprite = atlas.sprites["corner-" .. metal]
		size, out = regions.cornerSize, 0
	end
	for i, piece in ipairs(regions.corners) do
		if sprite then
			local point = CORNERS[i]
			cut(piece, atlas, sprite.x, sprite.y, sprite.w, sprite.h, i % 2 == 0, i > 2)
			piece:SetSize(size, size)
			piece:ClearAllPoints()
			if art then
				piece:SetPoint(point, point:find("RIGHT") and out or -out, point:find("TOP") and out or -out)
			else
				piece:SetPoint(point)
			end
		end
		piece:SetShown(sprite ~= nil)
	end
end

--- Draws `look` at once (BIND-R10–R12).
---@param look PagleBindingLook
function Regions:Dress(look)
	self.look = look
	local fill = self.fill
	if look.fill then
		fill:SetTexture(look.fill)
		fill:SetTexCoord(0, 1, 0, 1)
	else
		fill:SetTexture(look.texture, "REPEAT", "REPEAT")
		self:Tile()
	end
	-- the tint at the top, darker toward the foot by `foot` (the gradient's first colour is the bottom's)
	local tint, foot = look.tint or WHITE, look.foot
	fill:SetGradient(
		"VERTICAL",
		CreateColor(tint[1] * foot, tint[2] * foot, tint[3] * foot, 1),
		CreateColor(tint[1], tint[2], tint[3], 1)
	)
	local tone = look.band
	for _, piece in ipairs(self.bandPieces) do
		piece:SetDesaturated(tone ~= nil)
		if tone then
			piece:SetVertexColor(tone[1], tone[2], tone[3])
		else
			piece:SetVertexColor(1, 1, 1)
		end
	end
	for _, edge in ipairs(self.rules) do
		edge:SetShown(look.tooled == true)
	end
	self.giltCorner:SetShown(look.giltCorner == true)
	dressCorners(self, look)
	-- a whole book's parts (BIND-R14–R16)
	local parts = ns.ATLASES.BindingParts2
	part(self.clasp, parts, look.clasp)
	if look.clasp then
		self.clasp:ClearAllPoints()
		self.clasp:SetPoint("RIGHT", self.frame, "RIGHT", CLASP_LIP, 0)
	end
	part(self.ribbon, parts, look.ribbon)
	local ribbon = look.ribbon and parts.sprites[look.ribbon]
	if ribbon then
		-- only its foot: the top of the sprite cropped away, the notch kept
		local drawn = ribbon.box[4]
		local top = ribbon.y + ribbon.h * (1 - RIBBON_SHOWN / drawn)
		self.ribbon:SetTexCoord(
			ribbon.x / parts.width,
			(ribbon.x + ribbon.w) / parts.width,
			top / parts.height,
			(ribbon.y + ribbon.h) / parts.height
		)
		self.ribbon:SetSize(ribbon.box[3], RIBBON_SHOWN)
	end
	local fillet = look.fillet
	for _, edge in ipairs(self.fillets) do
		if fillet then
			edge:SetColorTexture(fillet[1], fillet[2], fillet[3], FILLET_ALPHA)
		end
		edge:SetShown(fillet ~= nil)
	end
end

--- Tiles a material over the frame as it is now (BIND-R10): one repeat every `tileW` × `tileH` units from the top
--- left of the rectangle inside the band. A stretched one needs nothing.
function Regions:Tile()
	local look = self.look
	if not look or look.fill then
		return
	end
	local width, height = self.frame:GetSize()
	self.fill:SetTexCoord(
		0,
		math.max(1, width - 2 * INSET) / look.tileW,
		0,
		math.max(1, height - 2 * INSET) / look.tileH
	)
end

--- The dip (BIND-R20): the material at `alpha`, the band and the features over it at 0.4 + 0.6 × `alpha`.
---@param alpha number
function Regions:Dim(alpha)
	self.fill:SetAlpha(alpha)
	self.band:SetAlpha(BAND_FLOOR + (1 - BAND_FLOOR) * alpha)
end

--- Whether the book is on the screen now.
---@return boolean
function Regions:IsShown()
	return self.frame:IsVisible()
end

-- Makes the regions of a book's binding on `frame` (BIND-R10–R12), drawing nothing yet: the material and the vignette
-- on its BACKGROUND layer, the band on a frame six levels up, the features on one a level above that.
---@param frame Frame
---@param options PagleBookBindingOptions
---@return PagleBookBindingRegions
local function newRegions(frame, options)
	local sublevel = options.sublevel or 0
	local fill = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, sublevel))
	fill:SetPoint("TOPLEFT", INSET, -INSET)
	fill:SetPoint("BOTTOMRIGHT", -INSET, INSET)
	local book = ns.ATLASES.Book
	local vignette = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, sublevel + 1))
	local sprite = book.sprites.vignette
	cut(vignette, book, sprite.x + 1, sprite.y + 1, sprite.w - 2, sprite.h - 2)
	vignette:SetAllPoints(fill)
	local band = CreateFrame("Frame", nil, frame)
	band:SetAllPoints()
	band:SetFrameLevel(frame:GetFrameLevel() + 6)
	local gilt = CreateFrame("Frame", nil, band)
	gilt:SetAllPoints()
	gilt:SetFrameLevel(band:GetFrameLevel() + 1)
	local giltCorner = ns.ArtSprite(gilt, "BindingGilt", "corner", "ARTWORK", 1)
	local giltSize = options.giltCornerSize or GILT_CORNER_SIZE
	giltCorner:SetSize(giltSize, giltSize)
	giltCorner:SetPoint("TOPLEFT")
	local cornerSize = options.cornerSize or CORNER_SIZE
	local corners = {}
	for i, point in ipairs(CORNERS) do
		local piece = ns.ArtCrisp(gilt:CreateTexture(nil, "ARTWORK", nil, 2))
		piece:SetSize(cornerSize, cornerSize)
		piece:SetPoint(point)
		piece:Hide()
		corners[i] = piece
	end
	-- a whole book's ribbon under the corners, hanging from the pages' foot (options.pages, else the frame's), and its
	-- clasp over them on the fore-edge
	local ribbon = ns.ArtCrisp(gilt:CreateTexture(nil, "ARTWORK", nil, 0))
	local pages = options.pages
	if pages then
		ribbon:SetPoint("TOPLEFT", frame, "TOPLEFT", pages.x + pages.w / 2 + RIBBON_X, -(pages.y + pages.h - RIBBON_IN))
	else
		ribbon:SetPoint("TOPLEFT", frame, "BOTTOM", RIBBON_X, RIBBON_UP)
	end
	ribbon:Hide()
	local clasp = ns.ArtCrisp(gilt:CreateTexture(nil, "ARTWORK", nil, 3))
	clasp:Hide()
	local regions = setmetatable({
		frame = frame,
		fill = fill,
		vignette = vignette,
		band = band,
		bandPieces = bandPieces(band),
		gilt = gilt,
		rules = tooledRules(gilt),
		fillets = ruledEdges(gilt, { FILLET_INSET }, FILLET_WIDTH),
		giltCorner = giltCorner,
		corners = corners,
		cornerSize = cornerSize,
		clasp = clasp,
		ribbon = ribbon,
	}, Regions) --[[@as PagleBookBindingRegions]]
	-- tiled again as the book's size changes
	frame:HookScript("OnSizeChanged", function()
		regions:Tile()
	end)
	return regions
end

local bindings = ns.NewBookBindings({
	lookOf = function(goodID)
		return ns.BindingLook(goodID)
	end,
	equipped = function()
		return Pagle.GetEquipped(ns.BINDING_SLOT)
	end,
	skin = newRegions,
	motionOn = function()
		return Pagle.IsAnimationsOn()
	end,
	animate = function(owner, animations, onDone)
		Pagle.Animate(owner, animations, onDone)
	end,
	stopMotion = function(owner)
		Pagle.StopMotion(owner)
	end,
	cue = function(owner, seconds, fn)
		Pagle.Cue(owner, seconds, fn)
	end,
	turnSound = function()
		PlaySound(ns.BINDING_TURN_SOUND, "SFX")
	end,
})

--- Draws a binding on a book's `frame` (sized first) and returns its handle (core/book-binding.md › Contracts): the
--- equipped binding, followed through every change, or `options.pinned`'s.
Pagle.NewBookBinding = bindings.New

Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot, goodID)
	bindings.Changed(slot, goodID)
end)
