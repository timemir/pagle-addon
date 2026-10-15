if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The books art kit on the client (HNT-R60): its fonts, bundled in Core's media (Core is a required dependency, so its
-- files are always there), and the sprite helpers the board, its pages and the tracker draw with, over the atlases in
-- adapter/BookAtlas.lua. They have the shape and names of Core's art helpers (the announcements kit's adapter/Art.lua):
-- every size is the canvas's CSS pixel, a UI unit, and a sprite's `box` is where its drawn element sits in it. Stats
-- keeps its own copy (ADR 0001: Modules share no code).

--- A sprite's texel rectangle in its atlas, and its drawn element's box in UI units ({ x, y, w, h }).
---@class HuntsArtSprite
---@field x integer
---@field y integer
---@field w integer
---@field h integer
---@field box number[]

---@class HuntsArtAtlas
---@field file string
---@field width integer
---@field height integer
---@field scale number          -- texels per UI unit
---@field sprites table<string, HuntsArtSprite>

--- A texture showing a sprite: `box` is where its drawn element sits in it.
---@class HuntsSpriteTexture: Texture
---@field box number[]

local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
-- The faces (Pagle/media/fonts/OFL-*.txt): IM Fell English for print and its italic for notes, Caveat for the
-- Angler's handwriting, Marcellus for gilt, ribbons and brass.
local FACES = {
	print = "IMFeENrm28P.ttf",
	italic = "IMFeENit28P.ttf",
	gilt = "Marcellus-Regular.ttf",
	hand = "Caveat-Medium.ttf",
	handSemi = "Caveat-SemiBold.ttf",
	handBold = "Caveat-Bold.ttf",
}
-- What draws if a bundled face won't load: the client's own.
local FALLBACK = "Fonts\\FRIZQT__.TTF"

---@alias HuntsArtFace "print"|"italic"|"gilt"|"hand"|"handSemi"|"handBold"

--- A face's file, for a spec or a probe to read.
---@param face HuntsArtFace
---@return string
function ns.ArtFontFile(face)
	return FONT_DIR .. assert(FACES[face], "the books kit has no face " .. tostring(face))
end

-- Each font object made, by face, size and shadow.
---@type table<string, Font>
local fonts = {}

--- The kit's font object in `face` at `size`, with a shadow when `shadow` (words on the leather, the ribbons and the
--- native tracker; never on paper), made once. Its ink is the font string's: ns.BoardText colours it.
---@param face HuntsArtFace
---@param size number
---@param shadow boolean?
---@return Font
function ns.ArtFont(face, size, shadow)
	local key = ("%s:%s:%s"):format(face, size, shadow and 1 or 0)
	local font = fonts[key]
	if not font then
		font = CreateFont(("PagleHuntsArt_%s_%s%s"):format(face, tostring(size):gsub("%.", "_"), shadow and "_s" or ""))
		if font:SetFont(ns.ArtFontFile(face), size, "") == false then
			font:SetFont(FALLBACK, size, "")
		end
		if shadow then
			font:SetShadowColor(0, 0, 0, 0.95)
			font:SetShadowOffset(0, -1)
		else
			font:SetShadowOffset(0, 0)
		end
		fonts[key] = font
	end
	return font
end

-- Draws texels as they are, unsnapped, so a sprite scaled by the UI doesn't shimmer.
---@param texture Texture
---@return Texture
local function crisp(texture)
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
	return texture
end
ns.ArtCrisp = crisp

---@param atlasName string
---@param name string
---@return HuntsArtAtlas
---@return HuntsArtSprite
local function spriteOf(atlasName, name)
	local atlas = ns.ATLASES[atlasName]
	local sprite = atlas and atlas.sprites[name]
	if not sprite then
		error(("Pagle_Hunts: no sprite %s in the %s atlas"):format(tostring(name), tostring(atlasName)))
	end
	return atlas, sprite
end
ns.ArtSpriteOf = spriteOf

-- Shows `texture` the texels `x0`..`x0 + w`, `y0`..`y0 + h` of `atlas`.
---@param texture Texture
---@param atlas HuntsArtAtlas
---@param x0 number
---@param y0 number
---@param w number
---@param h number
local function cut(texture, atlas, x0, y0, w, h)
	texture:SetTexture(atlas.file)
	texture:SetTexCoord(x0 / atlas.width, (x0 + w) / atlas.width, y0 / atlas.height, (y0 + h) / atlas.height)
end
ns.ArtCut = cut

--- Shows sprite `name` of atlas `atlasName` in `texture`, at its designed size (or its box `size` wide, scaled).
---@param texture Texture
---@param atlasName string
---@param name string
---@param size number?
---@return HuntsSpriteTexture
function ns.SetSprite(texture, atlasName, name, size)
	local atlas, sprite = spriteOf(atlasName, name)
	local shown = texture --[[@as HuntsSpriteTexture]]
	cut(shown, atlas, sprite.x, sprite.y, sprite.w, sprite.h)
	local k = size and size / sprite.box[3] or 1
	shown:SetSize(sprite.w / atlas.scale * k, sprite.h / atlas.scale * k)
	local box = sprite.box
	shown.box = { box[1] * k, box[2] * k, box[3] * k, box[4] * k }
	return shown
end

--- A texture on `frame` showing a sprite.
---@param frame Frame
---@param atlasName string
---@param name string
---@param layer DrawLayer?
---@param sublevel integer?
---@param size number?
---@return HuntsSpriteTexture
function ns.ArtSprite(frame, atlasName, name, layer, sublevel, size)
	local texture = crisp(frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0))
	return ns.SetSprite(texture, atlasName, name, size)
end

--- Anchors a sprite so its drawn element's top left is `x`, `y` from `relativeTo`'s top left (y grows downward).
---@param sprite HuntsSpriteTexture
---@param relativeTo Region
---@param x number
---@param y number
function ns.PlaceSprite(sprite, relativeTo, x, y)
	sprite:ClearAllPoints()
	sprite:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x - sprite.box[1], -(y - sprite.box[2]))
end

--- Anchors a sprite so its drawn element's centre is on `relativeTo`'s centre.
---@param sprite HuntsSpriteTexture
---@param relativeTo Region
function ns.CenterSprite(sprite, relativeTo)
	local box = sprite.box
	local width, height = sprite:GetSize()
	sprite:ClearAllPoints()
	sprite:SetPoint(
		"CENTER",
		relativeTo,
		"CENTER",
		width / 2 - (box[1] + box[3] / 2),
		-(height / 2 - (box[2] + box[4] / 2))
	)
end

--- A frame drawn as a sprite sliced in three across: its end caps keep their size, its middle stretches.
---@class HuntsThreeSlice: Frame
---@field left Texture
---@field middle Texture
---@field right Texture

--- Draws sprite `name` three-sliced on `frame`, `width` wide and its drawn element's height high: `cap` UI units of the
--- element are kept at each end, with the sprite's margin outside them. Makes the slices the first time.
---@param frame Frame
---@param atlasName string
---@param name string
---@param width number
---@param cap number
---@param layer DrawLayer?
---@param sublevel integer?
function ns.SetThreeSlice(frame, atlasName, name, width, cap, layer, sublevel)
	local slice = frame --[[@as HuntsThreeSlice]]
	if not slice.left then
		slice.left = crisp(frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0))
		slice.middle = crisp(frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0))
		slice.right = crisp(frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0))
	end
	local atlas, sprite = spriteOf(atlasName, name)
	local scale, box = atlas.scale, sprite.box
	local spriteWidth = sprite.w / scale
	local marginLeft, marginRight = box[1], spriteWidth - box[1] - box[3]
	local leftWidth, rightWidth = marginLeft + cap, cap + marginRight
	frame:SetSize(width, box[4])
	local function piece(texture, from, span)
		cut(texture, atlas, sprite.x + from * scale, sprite.y, span * scale, sprite.h)
		texture:SetHeight(sprite.h / scale)
	end
	piece(slice.left, 0, leftWidth)
	slice.left:SetWidth(leftWidth)
	piece(slice.right, spriteWidth - rightWidth, rightWidth)
	slice.right:SetWidth(rightWidth)
	piece(slice.middle, leftWidth, spriteWidth - leftWidth - rightWidth)
	slice.left:ClearAllPoints()
	slice.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -marginLeft, box[2])
	slice.right:ClearAllPoints()
	slice.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", marginRight, box[2])
	slice.middle:ClearAllPoints()
	slice.middle:SetPoint("TOPLEFT", slice.left, "TOPRIGHT")
	slice.middle:SetPoint("BOTTOMRIGHT", slice.right, "BOTTOMLEFT")
end

--- Shows in `texture` the first `width` UI units of sprite `name`'s drawn element, unstretched: a bar or an ink fill is
--- cut to length, not squeezed. Its box is the part shown.
---@param texture Texture
---@param atlasName string
---@param name string
---@param width number
---@return HuntsSpriteTexture
function ns.SetCrop(texture, atlasName, name, width)
	local atlas, sprite = spriteOf(atlasName, name)
	local shown = texture --[[@as HuntsSpriteTexture]]
	width = math.max(0, math.min(width, sprite.box[3]))
	cut(shown, atlas, sprite.x + sprite.box[1] * atlas.scale, sprite.y, width * atlas.scale, sprite.h)
	shown:SetSize(width, sprite.h / atlas.scale)
	shown.box = { 0, sprite.box[2], width, sprite.box[4] }
	return shown
end

--- A frame drawn as a sprite sliced in three down: its top and bottom keep their size, its middle stretches, or
--- repeats every `period` UI units when given (ruled paper keeps its line pitch).
---@class HuntsVSlice: Frame
---@field top Texture
---@field bottom Texture
---@field middles Texture[]

--- Draws sprite `name` sliced down on `frame`, its drawn element `height` high: `capTop` and `capBottom` UI units of the
--- element are kept at the top and bottom, with the sprite's margin outside them. The frame is the element's box; the
--- sprite's margin reaches outside it. Makes the slices the first time, and the middles as the height needs them.
---@param frame Frame
---@param atlasName string
---@param name string
---@param height number
---@param capTop number
---@param capBottom number
---@param period number?
function ns.SetVSlice(frame, atlasName, name, height, capTop, capBottom, period)
	local slice = frame --[[@as HuntsVSlice]]
	local atlas, sprite = spriteOf(atlasName, name)
	local scale, box = atlas.scale, sprite.box
	local spriteHeight = sprite.h / scale
	local marginTop, marginBottom = box[2], spriteHeight - box[2] - box[4]
	local topHeight, bottomHeight = marginTop + capTop, capBottom + marginBottom
	local middleSpan = spriteHeight - topHeight - bottomHeight
	slice.middles = slice.middles or {}
	if not slice.top then
		slice.top = crisp(frame:CreateTexture(nil, "BACKGROUND"))
		slice.bottom = crisp(frame:CreateTexture(nil, "BACKGROUND"))
	end
	frame:SetSize(box[3], height)
	local function piece(texture, from, span)
		cut(texture, atlas, sprite.x, sprite.y + from * scale, sprite.w, span * scale)
		texture:SetSize(sprite.w / scale, span)
	end
	piece(slice.top, 0, topHeight)
	slice.top:ClearAllPoints()
	slice.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -box[1], marginTop)
	piece(slice.bottom, spriteHeight - bottomHeight, bottomHeight)
	slice.bottom:ClearAllPoints()
	slice.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -box[1], -marginBottom)
	local need = math.max(0, height - capTop - capBottom)
	local count = 0
	local at = 0
	while need - at > 0.01 do
		local span = period and math.min(period, need - at) or need
		count = count + 1
		local middle = slice.middles[count]
		if not middle then
			middle = crisp(frame:CreateTexture(nil, "BACKGROUND"))
			slice.middles[count] = middle
		end
		-- Stretched, the whole middle draws over its span; repeated, each step shows the middle's first `span`
		piece(middle, topHeight, period and span or middleSpan)
		middle:SetHeight(span)
		middle:ClearAllPoints()
		middle:SetPoint("TOPLEFT", slice.top, "BOTTOMLEFT", 0, -at)
		middle:Show()
		at = at + span
	end
	for i = count + 1, #slice.middles do
		slice.middles[i]:Hide()
	end
end

--- A round dot: a solid colour through the portrait mask's disc, with a thin dark edge, as the group and tracker
--- bullets.
---@class HuntsArtDot: Frame
---@field edge Texture
---@field face Texture

--- A round dot on `parent`, `size` across; ns.SetDotColor colours it.
---@param parent Frame
---@param size number
---@return HuntsArtDot
function ns.NewArtDot(parent, size)
	local dot = CreateFrame("Frame", nil, parent) --[[@as HuntsArtDot]]
	dot:SetSize(size, size)
	dot.edge = dot:CreateTexture(nil, "ARTWORK", nil, 0)
	dot.edge:SetAllPoints()
	dot.face = dot:CreateTexture(nil, "ARTWORK", nil, 1)
	dot.face:SetPoint("TOPLEFT", 1, -1)
	dot.face:SetPoint("BOTTOMRIGHT", -1, 1)
	for _, texture in ipairs({ dot.edge, dot.face }) do
		texture:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	end
	dot.edge:SetVertexColor(0x28 / 255, 0x14 / 255, 0x05 / 255, 0.55)
	return dot
end

--- Colours a dot.
---@param dot HuntsArtDot
---@param color number[]
function ns.SetDotColor(dot, color)
	dot.face:SetVertexColor(color[1], color[2], color[3])
end

-- The rounded corner's radius, in UI units, and the mask drawn on each corner: white, its alpha a quarter disc.
local CORNER_RADIUS = 6
local CORNER_MASKS = {
	TOPLEFT = "InterfaceAddOnsPaglemedia\booksCornerTL",
	TOPRIGHT = "InterfaceAddOnsPaglemedia\booksCornerTR",
	BOTTOMLEFT = "InterfaceAddOnsPaglemedia\booksCornerBL",
	BOTTOMRIGHT = "InterfaceAddOnsPaglemedia\booksCornerBR",
}

--- Rounds `texture`'s corners named in `corners` (e.g. { "TOPLEFT", "BOTTOMLEFT" }), a few units across: a small mask
--- on each, clamped to white past its edge, so the rest of the texture shows as it is and the leather behind shows
--- through the cut.
---@param texture Texture
---@param frame Frame the frame the masks are made on, which `texture` fills
---@param corners string[]
---@return MaskTexture[]
function ns.RoundCorners(texture, frame, corners)
	local masks = {}
	for i, corner in ipairs(corners) do
		local mask = frame:CreateMaskTexture()
		mask:SetTexture(CORNER_MASKS[corner], "CLAMPTOWHITE", "CLAMPTOWHITE")
		mask:SetSize(CORNER_RADIUS, CORNER_RADIUS)
		mask:SetPoint(corner, texture, corner)
		texture:AddMaskTexture(mask)
		masks[i] = mask
	end
	return masks
end

--- Lays `text` in `face` at `size`, or a half point smaller at a time down to `floor`, until it fits `width`; past
--- the floor the client cuts it short with an ellipsis; in `color` (a font object brings its own, so it is set again).
--- Returns the size it took. As Core's ns.ShrinkToFit does for the announcements, here for the Module's own fonts.
---@param text FontString
---@param face HuntsArtFace
---@param size number
---@param width number
---@param floor number
---@param shadow boolean?
---@param color number[]?
---@return number
function ns.FitText(text, face, size, width, floor, shadow, color)
	text:SetWidth(0) -- measured unbounded
	local at = size
	text:SetFontObject(ns.ArtFont(face, at, shadow))
	while at > floor and text:GetStringWidth() > width do
		at = math.max(floor, at - 0.5)
		text:SetFontObject(ns.ArtFont(face, at, shadow))
	end
	text:SetWidth(width)
	if color then
		text:SetTextColor(color[1], color[2], color[3])
	end
	return at
end
