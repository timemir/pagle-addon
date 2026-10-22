---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The announcements art kit on the client (announcements.md › UI, ANN-R80): its bundled fonts as font objects, and
-- the pieces the toast, Nod, banner, splash and card frames are drawn from: sprites from the atlases in
-- data/AnnounceArt.lua, three-sliced strips, the medallion round an icon, the brass coin and the rubber stamp. Every
-- size is the canvas's CSS pixel, a UI unit. Each piece is made once and set again for each Announcement, so a frame
-- reused by the lanes redraws in place.

local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
-- The faces (media/fonts/OFL-*.txt): IM Fell English for print, its italic for notes and its small caps (IM Fell
-- English SC) for kickers, Caveat for the Angler's handwriting, Marcellus for gilt, stamps and labels.
local FACES = {
	print = "IMFeENrm28P.ttf",
	italic = "IMFeENit28P.ttf",
	sc = "IMFeENsc28P.ttf",
	gilt = "Marcellus-Regular.ttf",
	hand = "Caveat-Medium.ttf",
	handSemi = "Caveat-SemiBold.ttf",
	handBold = "Caveat-Bold.ttf",
}
-- What draws if a bundled face won't load: the client's own.
local FALLBACK = "Fonts\\FRIZQT__.TTF"

-- Each font: its face, size and ink (a role in ns.ANNOUNCE_COLORS), and whether it has a shadow (what is drawn over
-- the world does; what is on the page doesn't).
local FONTS = {
	-- toasts
	What = { "print", 13, "red" }, -- set in capitals: the client has no small caps
	Name = { "handSemi", 31, "ink" },
	NameLow = { "hand", 26, "pencilName" },
	NameHigh = { "handSemi", 34, "ink" },
	More = { "hand", 19, "pencil" },
	Amt = { "handBold", 24, "amt" },
	Stamp = { "gilt", 11, "stamp" },
	RuleLabel = { "print", 11, "ink2" },
	RuleGain = { "handBold", 22, "stamp" },
	RuleOld = { "hand", 17, "pencil" },
	RuleNew = { "handBold", 19, "ink" },
	DigestWhat = { "print", 12, "red" },
	DigestName = { "handSemi", 23, "ink" },
	-- Nods
	NodWhat = { "print", 12, "red" },
	NodName = { "handSemi", 22, "ink" },
	NodStat = { "handBold", 18, "stamp" },
	NodAmt = { "handBold", 19, "amt" },
	-- banners
	Kick = { "gilt", 21, "gilt", true },
	SealNumber = { "gilt", 60, "red" },
	SealSmall = { "gilt", 36, "red" },
	TitleGilt = { "handBold", 46, "gilt", true },
	Say = { "handSemi", 28, "cream", true },
	BanAmt = { "handBold", 26, "gilt", true },
	Label = { "gilt", 13, "gilt", true },
	Crest = { "print", 11, "ink" },
	-- the splash
	SplashWhat = { "print", 16, "red" },
	SplashName = { "handBold", 58, "ink" },
	AnyClick = { "gilt", 13, "dim" },
	-- cards
	CardTitle = { "gilt", 26, "gilt", true },
	CardNum = { "handBold", 44, "ink" },
	CardNumLabel = { "print", 12, "ink2" },
	CardLine = { "print", 15, "paperInk" },
	CardDetail = { "hand", 20, "ink2" },
	CardGroup = { "print", 13, "red" },
	Button = { "gilt", 17, "gilt", true },
	-- the books' kicker over a page's title (the Field guide's, ONB-R30), in IM Fell English SC: the client has no
	-- small caps of its own
	SmallCaps = { "sc", 14, "kicker" },
}

--- The art's font object names, by key: PagleArt<key>.
---@type table<string, string>
ns.ART_FONTS = {}
for key, def in pairs(FONTS) do
	local name = "PagleArt" .. key
	local font = CreateFont(name)
	if font:SetFont(FONT_DIR .. FACES[def[1]], def[2], "") == false then
		font:SetFont(FALLBACK, def[2], "")
	end
	local color = ns.ANNOUNCE_COLORS[def[3]]
	font:SetTextColor(color[1], color[2], color[3])
	if def[4] then
		font:SetShadowColor(0, 0, 0, 0.9)
		font:SetShadowOffset(0, -1.5)
	else
		font:SetShadowOffset(0, 0)
	end
	ns.ART_FONTS[key] = name
end

--- Puts a font string in the art's font `key`, in that font's ink.
---@param fontString FontString
---@param key string
function ns.SetArtFont(fontString, key)
	fontString:SetFontObject(ns.ART_FONTS[key])
	ns.Ink(fontString, FONTS[key][3])
end

--- The art's font object name for the small-caps kicker (IM Fell English SC, 14), in the books' kicker ink.
ns.ART_SMALL_CAPS = ns.ART_FONTS.SmallCaps

--- A face the art bundles, for a font made at any size (ns.ArtFaceFont).
---@alias PagleArtFace "print"|"italic"|"sc"|"gilt"|"hand"|"handSemi"|"handBold"

-- Each font object ns.ArtFaceFont has made, by face, size and shadow.
---@type table<string, Font>
local faceFonts = {}

--- A font object in the art's `face` at `size` (UI units), with a shadow when `shadow` (words on leather, ribbons and
--- the world; never on paper), made once: the Field guide's pages set type at many sizes, as the books do. Its ink is
--- the font string's to set.
---@param face PagleArtFace
---@param size number
---@param shadow boolean?
---@return Font
function ns.ArtFaceFont(face, size, shadow)
	local key = ("%s_%s%s"):format(face, (tostring(size):gsub("%.", "_")), shadow and "_s" or "")
	local font = faceFonts[key]
	if not font then
		local file = assert(FACES[face], "the art has no face " .. tostring(face))
		font = CreateFont("PagleArtFace_" .. key)
		if font:SetFont(FONT_DIR .. file, size, "") == false then
			font:SetFont(FALLBACK, size, "")
		end
		if shadow then
			font:SetShadowColor(0, 0, 0, 0.95)
			font:SetShadowOffset(0, -1)
		else
			font:SetShadowOffset(0, 0)
		end
		faceFonts[key] = font
	end
	return font
end

--- The size of the art's font `key`.
---@param key string
---@return number
function ns.ArtFontSize(key)
	return FONTS[key][2]
end

--- Colours a font string in an ink of ns.ANNOUNCE_COLORS.
---@param fontString FontString
---@param role string
function ns.Ink(fontString, role)
	local color = ns.ANNOUNCE_COLORS[role]
	fontString:SetTextColor(color[1], color[2], color[3])
end

--- A one-line font string on `frame` in the art's font `key`.
---@param frame Frame
---@param key string
---@param layer DrawLayer?
---@return FontString
function ns.ArtText(frame, key, layer)
	local fontString = frame:CreateFontString(nil, layer or "OVERLAY")
	ns.SetArtFont(fontString, key)
	fontString:SetWordWrap(false)
	fontString:SetJustifyH("LEFT")
	return fontString
end

-- How far a line in the hand may shrink to fit: the art's pages are a fixed size, so a longer one ends in "...".
local SHRINK_FLOOR = 0.7

--- Holds a font string in the art's font `key`, its text already set, to `width`: a text too wide shrinks to fit,
--- down to SHRINK_FLOOR of the font's size, and one still too wide ends in "...".
---@param fontString FontString
---@param key string
---@param width number
function ns.ShrinkToFit(fontString, key, width)
	fontString:SetWidth(0)
	local natural = fontString:GetStringWidth()
	if natural > width then
		local def = FONTS[key]
		local size = math.max(math.ceil(def[2] * SHRINK_FLOOR), math.floor(def[2] * width / natural))
		if fontString:SetFont(FONT_DIR .. FACES[def[1]], size, "") == false then
			fontString:SetFont(FALLBACK, size, "")
		end
	end
	fontString:SetWidth(math.min(fontString:GetStringWidth(), width))
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
---@return PagleAtlas
---@return PagleAtlasSprite
local function spriteOf(atlasName, name)
	local atlas = ns.ATLASES[atlasName]
	local sprite = atlas and atlas.sprites[name]
	if not sprite then
		error(("Pagle: no sprite %s in the %s atlas"):format(tostring(name), tostring(atlasName)))
	end
	return atlas, sprite
end

--- A texture showing a sprite. `texture.box` is where its drawn element sits in it.
---@class PagleSprite: Texture
---@field box number[]
---@field tc number[] its texture coordinates: left, right, top, bottom
---@field w0 number? its width before an animation squashes or cuts it

--- Shows sprite `name` of atlas `atlasName` in `texture`, at its designed size.
---@param texture Texture
---@param atlasName string
---@param name string
---@return PagleSprite
function ns.SetSprite(texture, atlasName, name)
	local atlas, sprite = spriteOf(atlasName, name)
	local shown = texture --[[@as PagleSprite]]
	shown:SetTexture(atlas.file)
	shown.tc = {
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height,
	}
	shown:SetTexCoord(shown.tc[1], shown.tc[2], shown.tc[3], shown.tc[4])
	shown:SetSize(sprite.w / atlas.scale, sprite.h / atlas.scale)
	shown.box = sprite.box
	return shown
end

--- A texture on `frame` showing a sprite.
---@param frame Frame
---@param atlasName string
---@param name string
---@param layer DrawLayer?
---@param sublevel integer?
---@return PagleSprite
function ns.ArtSprite(frame, atlasName, name, layer, sublevel)
	return ns.SetSprite(crisp(frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)), atlasName, name)
end

--- Anchors a sprite so its drawn element's top left is `x`, `y` from `relativeTo`'s top left (y grows downward).
---@param sprite PagleSprite
---@param relativeTo Region
---@param x number
---@param y number
function ns.PlaceSprite(sprite, relativeTo, x, y)
	sprite:ClearAllPoints()
	sprite:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x - sprite.box[1], -(y - sprite.box[2]))
end

--- Anchors a sprite so its drawn element's centre is on `relativeTo`'s centre.
---@param sprite PagleSprite
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

--- Anchors a sprite by its CENTER so its drawn element's centre is `x`, `y` from `relativeTo`'s top left (y grows
--- downward), and keeps its width as `w0`: an animation can squash or grow it about that centre.
---@param sprite PagleSprite
---@param relativeTo Region
---@param x number
---@param y number
function ns.CenterSpriteAt(sprite, relativeTo, x, y)
	local box = sprite.box
	local width, height = sprite:GetSize()
	sprite.w0 = width
	sprite:ClearAllPoints()
	sprite:SetPoint(
		"CENTER",
		relativeTo,
		"TOPLEFT",
		x + width / 2 - (box[1] + box[3] / 2),
		-(y + height / 2 - (box[2] + box[4] / 2))
	)
end

--- A 1 x 1 frame on `parent` at `x`, `y` from `relativeTo`'s top left: a frame anchored by its CENTER to it, with no
--- offset, grows about that point under SetScale (a scaled frame's own anchor offsets would scale too).
---@param parent Frame
---@param relativeTo Region
---@param x number
---@param y number
---@return Frame
function ns.Pivot(parent, relativeTo, x, y)
	local pivot = CreateFrame("Frame", nil, parent)
	pivot:SetSize(1, 1)
	pivot:SetPoint("CENTER", relativeTo, "TOPLEFT", x, -y)
	return pivot
end

--- A frame drawn as a sprite sliced in three across: its end caps keep their size, its middle stretches.
---@class PagleThreeSlice: Frame
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
function ns.SetThreeSlice(frame, atlasName, name, width, cap, layer)
	local slice = frame --[[@as PagleThreeSlice]]
	if not slice.left then
		slice.left = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
		slice.middle = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
		slice.right = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
	end
	local atlas, sprite = spriteOf(atlasName, name)
	local scale, box = atlas.scale, sprite.box
	local spriteWidth = sprite.w / scale
	local marginLeft, marginRight = box[1], spriteWidth - box[1] - box[3]
	local leftWidth, rightWidth = marginLeft + cap, cap + marginRight
	frame:SetSize(width, box[4])
	-- One slice: `span` UI units of the sprite from `from`.
	local function cut(texture, from, span)
		local x0 = sprite.x + from * scale
		texture:SetTexture(atlas.file)
		texture:SetTexCoord(
			x0 / atlas.width,
			(x0 + span * scale) / atlas.width,
			sprite.y / atlas.height,
			(sprite.y + sprite.h) / atlas.height
		)
		texture:SetHeight(sprite.h / scale)
	end
	cut(slice.left, 0, leftWidth)
	slice.left:SetWidth(leftWidth)
	cut(slice.right, spriteWidth - rightWidth, rightWidth)
	slice.right:SetWidth(rightWidth)
	cut(slice.middle, leftWidth, spriteWidth - leftWidth - rightWidth)
	slice.left:ClearAllPoints()
	slice.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -marginLeft, box[2])
	slice.right:ClearAllPoints()
	slice.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", marginRight, box[2])
	slice.middle:ClearAllPoints()
	slice.middle:SetPoint("TOPLEFT", slice.left, "TOPRIGHT")
	slice.middle:SetPoint("BOTTOMRIGHT", slice.right, "BOTTOMLEFT")
end

--- A panel drawn as a sprite sliced in nine on a frame, following the frame's size: its corners keep their size, its
--- edges and middle stretch. The frame is the drawn element's box; the sprite's margin (its shadow) hangs outside it.
--- Paper, cards, fields and boxes of any size are drawn so (the onboarding kit's GuideParts: "note", "opt", "bind", …).
---@class PagleNineSlice
---@field pieces Texture[] top left, top, top right, left, middle, right, bottom left, bottom, bottom right
local NineSlice = {}
NineSlice.__index = NineSlice

--- Shows or hides the panel.
---@param shown boolean
function NineSlice:SetShown(shown)
	for _, piece in ipairs(self.pieces) do
		piece:SetShown(shown)
	end
end

function NineSlice:Show()
	self:SetShown(true)
end

function NineSlice:Hide()
	self:SetShown(false)
end

--- Tints the panel (a card under the mouse warms, a dimmed one greys).
---@param r number
---@param g number
---@param b number
---@param a number?
function NineSlice:SetVertexColor(r, g, b, a)
	for _, piece in ipairs(self.pieces) do
		piece:SetVertexColor(r, g, b, a or 1)
	end
end

--- Draws sprite `name` of atlas `atlasName` nine-sliced on `frame`, in `layer` (BACKGROUND by default, under the
--- frame's own words): `cap` UI units of the drawn element are kept at each corner (a number, or { x, y }), with the
--- sprite's margin outside them. The pieces are anchored to the frame, so the panel follows its size from then on.
---@param frame Frame
---@param atlasName string
---@param name string
---@param cap number|number[]
---@param layer DrawLayer?
---@param sublevel integer?
---@return PagleNineSlice
function ns.NewNineSlice(frame, atlasName, name, cap, layer, sublevel)
	local atlas, sprite = spriteOf(atlasName, name)
	local scale, box = atlas.scale, sprite.box
	local capX, capY = cap, cap
	if type(cap) == "table" then
		capX, capY = cap[1], cap[2]
	end
	---@cast capX number
	---@cast capY number
	local spriteWidth, spriteHeight = sprite.w / scale, sprite.h / scale
	local left, top = box[1], box[2]
	local right, bottom = spriteWidth - box[1] - box[3], spriteHeight - box[2] - box[4]
	-- The sprite's columns and rows in UI units from its top left, each { from, span }: a cap with its margin, the
	-- stretched middle, the other cap with its margin.
	local cols = { { 0, left + capX }, { left + capX, 0 }, { spriteWidth - capX - right, capX + right } }
	cols[2][2] = cols[3][1] - cols[2][1]
	local rows = { { 0, top + capY }, { top + capY, 0 }, { spriteHeight - capY - bottom, capY + bottom } }
	rows[2][2] = rows[3][1] - rows[2][1]
	local pieces = {}
	for row = 1, 3 do
		for col = 1, 3 do
			local piece = crisp(frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0))
			local x0, y0 = sprite.x + cols[col][1] * scale, sprite.y + rows[row][1] * scale
			piece:SetTexture(atlas.file)
			piece:SetTexCoord(
				x0 / atlas.width,
				(x0 + cols[col][2] * scale) / atlas.width,
				y0 / atlas.height,
				(y0 + rows[row][2] * scale) / atlas.height
			)
			pieces[#pieces + 1] = piece
		end
	end
	local tl, t, tr, l, m, r, bl, b, br = unpack(pieces)
	tl:SetSize(cols[1][2], rows[1][2])
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -left, top)
	tr:SetSize(cols[3][2], rows[1][2])
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", right, top)
	bl:SetSize(cols[1][2], rows[3][2])
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -left, -bottom)
	br:SetSize(cols[3][2], rows[3][2])
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, -bottom)
	-- each edge and the middle between the corners round it
	for _, span in ipairs({
		{ t, tl, "TOPRIGHT", tr, "BOTTOMLEFT" },
		{ b, bl, "TOPRIGHT", br, "BOTTOMLEFT" },
		{ l, tl, "BOTTOMLEFT", bl, "TOPRIGHT" },
		{ r, tr, "BOTTOMLEFT", br, "TOPRIGHT" },
		{ m, tl, "BOTTOMRIGHT", br, "TOPLEFT" },
	}) do
		span[1]:SetPoint("TOPLEFT", span[2], span[3])
		span[1]:SetPoint("BOTTOMRIGHT", span[4], span[5])
	end
	return setmetatable({ pieces = pieces }, NineSlice)
end

--- A medallion: a brass, bronze or silver ring with an icon round inside it and the gloss over it.
---@class PagleBezel: Frame
---@field Ring PagleSprite
---@field Icon Texture
---@field Gloss PagleSprite

-- The icon's width inside each medallion size.
local INNER = { [84] = 62, [64] = 46, [34] = 26, [22] = 17 }

--- A medallion's parts on `parent`, from `atlas` (the announcements' or the Curio Shop's): sprite `ring` under an icon
--- masked round, centred, and sprite `gloss` over it. The announcements' medallion and the shop's share it.
---@param parent Frame
---@param atlas string
---@param ring string
---@param gloss string
---@return PagleBezel
function ns.NewArtBezel(parent, atlas, ring, gloss)
	local bezel = CreateFrame("Frame", nil, parent) --[[@as PagleBezel]]
	bezel.Ring = ns.ArtSprite(bezel, atlas, ring, "ARTWORK", 0)
	bezel.Icon = bezel:CreateTexture(nil, "ARTWORK", nil, 1)
	bezel.Icon:SetPoint("CENTER")
	local mask = bezel:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(bezel.Icon)
	bezel.Icon:AddMaskTexture(mask)
	bezel.Gloss = ns.ArtSprite(bezel, atlas, gloss, "ARTWORK", 2)
	return bezel
end

--- A medallion on `parent`, set with ns.SetBezel.
---@param parent Frame
---@return PagleBezel
function ns.NewBezel(parent)
	local bezel = ns.NewArtBezel(parent, "Announce", "bezel-gold-84", "gloss-84")
	crisp(bezel.Icon)
	return bezel
end

--- Sets a medallion's size (84, 64, 34 or 22), trim and icon, the icon's whole texture or `coords` of it ({ left,
--- right, top, bottom }: a variety's art cropped to the fish's head, VAR-R25).
---@param bezel PagleBezel
---@param size integer
---@param trim string "gold", "silver" or "bronze"
---@param icon integer|string
---@param coords number[]?
function ns.SetBezel(bezel, size, trim, icon, coords)
	bezel:SetSize(size, size)
	ns.SetSprite(bezel.Ring, "Announce", ("bezel-%s-%d"):format(trim, size))
	ns.CenterSprite(bezel.Ring, bezel)
	bezel.Icon:SetSize(INNER[size] - 2, INNER[size] - 2)
	bezel.Icon:SetTexture(icon)
	coords = coords or { 0, 1, 0, 1 }
	bezel.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	ns.SetSprite(bezel.Gloss, "Announce", "gloss-" .. size)
	ns.CenterSprite(bezel.Gloss, bezel)
end

--- Shows the brass coin with the stamped fish in `texture`, `size` across.
---@param texture Texture
---@param size number
---@return PagleSprite
function ns.SetCoin(texture, size)
	local small = size <= 30
	return ns.SetArtCoin(texture, "Announce", small and "coin-small" or "coin", small and 26 or 42, size)
end

--- Shows coin sprite `sprite` of `atlas` in `texture`, scaled from its `base` across to `size`, its box with it. The
--- announcements' coin and the shop's share it.
---@param texture Texture
---@param atlas string
---@param sprite string
---@param base number
---@param size number
---@return PagleSprite
function ns.SetArtCoin(texture, atlas, sprite, base, size)
	local coin = ns.SetSprite(texture, atlas, sprite)
	local k = size / base
	coin:SetSize(coin:GetWidth() * k, coin:GetHeight() * k)
	coin.box = { coin.box[1] * k, coin.box[2] * k, size, size }
	return coin
end

--- A rubber stamp: a three-sliced double border and its label in capitals.
---@class PagleStamp: Frame
---@field border PagleThreeSlice
---@field label FontString

--- A rubber stamp on `parent`, hidden until ns.SetStamp.
---@param parent Frame
---@return PagleStamp
function ns.NewStamp(parent)
	local stamp = CreateFrame("Frame", nil, parent) --[[@as PagleStamp]]
	stamp.border = CreateFrame("Frame", nil, stamp) --[[@as PagleThreeSlice]]
	stamp.border:SetPoint("TOPLEFT")
	-- On the border's own frame, which draws over the stamp's.
	stamp.label = ns.ArtText(stamp.border, "Stamp")
	stamp.label:SetPoint("CENTER", stamp, "CENTER")
	stamp:SetAlpha(0.9)
	stamp:Hide()
	return stamp
end

--- Inks a rubber stamp with `text` in a toast style's stamp and ink, and shows it.
---@param stamp PagleStamp
---@param text string
---@param style PagleToastStyle
function ns.SetStamp(stamp, text, style)
	stamp.label:SetText(ns.Capitals(text))
	ns.Ink(stamp.label, style.stampInk)
	local width = stamp.label:GetStringWidth() + 18
	ns.SetThreeSlice(stamp.border, "Announce", style.stamp, width, 8, "ARTWORK")
	stamp:SetSize(width, 26)
	stamp:Show()
end
