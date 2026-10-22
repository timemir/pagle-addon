if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The field art kit on the client (qol.md › UI): its inks and fonts, the sprite helpers QoL's frames are drawn with,
-- and the pieces they share: the brass key cap and the two note buttons. Sprites come from the Field atlas
-- (data/FieldArt.lua). The helpers have the shape and names of Core's (Pagle/adapter/Art.lua), which QoL can't
-- reach: a Module sees Core only through the Pagle API. Every size is the kit's canvas pixel, a UI unit. Nothing here
-- draws until a frame that uses it is first made, so the fonts and the texture load only then.

-- An ink from its hex, as { r, g, b }.
---@param hex string
---@return number[]
local function rgb(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

--- The kit's inks, by role, from its canvas.
---@type table<string, number[]>
ns.FIELD_INKS = {
	ink = rgb("1E1408"), -- the handwriting on paper: the button's label, a Nudge, a note's question
	brassText = rgb("2A1806"), -- a key on its brass cap
	gilt = rgb("F0CD6A"), -- the tooltip's words, the leather button's
	red = rgb("7A2A1A"), -- printed red: a binding's name in a Nudge
	pbtn = rgb("3A2614"), -- the outlined note button's words
	lacquer = rgb("170F09"), -- the tooltip's ground
	hairline = rgb("C9A24A"), -- the tooltip's gilt edge
}

local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
-- The faces, which Core bundles (Pagle/media/fonts/OFL-*.txt): IM Fell English for print, its italic for notes and
-- its small caps (IM Fell English SC) for kickers, Caveat for the Angler's handwriting, Marcellus for gilt and keys.
local FACES = {
	print = "IMFeENrm28P.ttf",
	italic = "IMFeENit28P.ttf",
	sc = "IMFeENsc28P.ttf",
	gilt = "Marcellus-Regular.ttf",
	hand = "Caveat-Medium.ttf",
	handSemi = "Caveat-SemiBold.ttf",
}
-- What draws if a bundled face won't load: the client's own.
local FALLBACK = "Fonts\\FRIZQT__.TTF"
-- Each font: its face, size and ink, and whether it has a shadow (the leather button's words do; what is on paper or
-- brass doesn't).
local FONTS = {
	Key = { "gilt", 12, "brassText" },
	Label = { "handSemi", 18, "ink" },
	Tip = { "gilt", 16, "gilt" },
	Nudge = { "handSemi", 24, "ink" },
	NudgeKey = { "gilt", 14, "brassText" },
	NudgeEm = { "print", 19, "red" }, -- printed type the hand's size on the line, not a small chip in it
	NoteHead = { "print", 26, "ink" },
	NoteButton = { "gilt", 16, "pbtn" },
	Button = { "gilt", 17, "gilt", true },
}
-- The font objects, each made the first time a frame asks for it: PagleQoL<key>.
---@type table<string, table>
local fonts = {}

--- A font string on `frame` in the kit's font `key`: one line, left-justified.
---@param frame Frame
---@param key string
---@param layer DrawLayer?
---@return FontString
function ns.ArtText(frame, key, layer)
	if not fonts[key] then
		local def = FONTS[key]
		local font = CreateFont("PagleQoL" .. key)
		if font:SetFont(FONT_DIR .. FACES[def[1]], def[2], "") == false then
			font:SetFont(FALLBACK, def[2], "")
		end
		local ink = ns.FIELD_INKS[def[3]]
		font:SetTextColor(ink[1], ink[2], ink[3])
		if def[4] then
			font:SetShadowColor(0, 0, 0, 0.95)
			font:SetShadowOffset(0, -1)
		else
			font:SetShadowOffset(0, 0)
		end
		fonts[key] = font
	end
	local fontString = frame:CreateFontString(nil, layer or "OVERLAY")
	fontString:SetFontObject(fonts[key])
	fontString:SetWordWrap(false)
	fontString:SetJustifyH("LEFT")
	return fontString
end

-- Each font ns.FaceFont has made, by face and size.
---@type table<string, Font>
local faceFonts = {}

--- A font object in the kit's `face` ("print", "italic", "sc", "gilt", "hand" or "handSemi") at `size` UI units,
--- made once, without a shadow (words on paper): the Field guide's pages set type at many sizes. Its ink is the font
--- string's to set.
---@param face string
---@param size number
---@return Font
function ns.FaceFont(face, size)
	local key = face .. "_" .. (tostring(size):gsub("%.", "_"))
	if not faceFonts[key] then
		local font = CreateFont("PagleQoLFace_" .. key)
		if font:SetFont(FONT_DIR .. assert(FACES[face], "no face " .. face), size, "") == false then
			font:SetFont(FALLBACK, size, "")
		end
		font:SetShadowOffset(0, 0)
		faceFonts[key] = font
	end
	return faceFonts[key]
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

--- Shows sprite `name` of atlas `atlasName` in `texture`, at its designed size.
---@param texture Texture
---@param atlasName string
---@param name string
---@return PagleSprite
function ns.SetSprite(texture, atlasName, name)
	local atlas, sprite = spriteOf(atlasName, name)
	local shown = texture --[[@as PagleSprite]]
	shown:SetTexture(atlas.file)
	shown:SetTexCoord(
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height
	)
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

--- A key on a brass cap: the Nudge's key, or the next-action button's hotkey.
---@class PagleQoLKeyCap: Frame
---@field cap PagleThreeSlice the brass, three-sliced to the key's width
---@field Text FontString the key

--- A brass key cap on `parent`, in the font `key`, its text set with ns.SetKeyCap.
---@param parent Frame
---@param key string "Key" (the button's) or "NudgeKey" (the Nudge's)
---@return PagleQoLKeyCap
function ns.NewKeyCap(parent, key)
	local keyCap = CreateFrame("Frame", nil, parent) --[[@as PagleQoLKeyCap]]
	keyCap.cap = CreateFrame("Frame", nil, keyCap) --[[@as PagleThreeSlice]]
	keyCap.cap:SetPoint("TOPLEFT")
	-- On a frame above the brass, so the key draws over it.
	local words = CreateFrame("Frame", nil, keyCap)
	words:SetAllPoints()
	words:SetFrameLevel(keyCap.cap:GetFrameLevel() + 1)
	keyCap.Text = ns.ArtText(words, key)
	keyCap.Text:SetJustifyH("CENTER")
	keyCap.Text:SetPoint("CENTER", keyCap, "CENTER")
	return keyCap
end

--- Sets a key cap's key and sizes the brass to it: `width` wide and `height` high. The cap is drawn 24 high; a lower
--- one is the same cap squashed, as the kit draws the button's 18 high one.
---@param keyCap PagleQoLKeyCap
---@param text string
---@param width number
---@param height number
function ns.SetKeyCap(keyCap, text, width, height)
	keyCap.Text:SetText(text)
	keyCap:SetSize(width, height)
	ns.SetThreeSlice(keyCap.cap, "Field", "key", width, 6, "ARTWORK")
	-- All three slices are the sprite's height; the end caps carry it, as the middle is anchored between them.
	local squashed = keyCap.cap.left:GetHeight() * height / 24
	for _, slice in ipairs({ keyCap.cap.left, keyCap.cap.middle, keyCap.cap.right }) do
		slice:SetHeight(squashed)
	end
end

--- A note button: leather with gilt words for the first choice, or the outlined one for the second.
---@class PagleQoLNoteButton: Button
---@field Text FontString

--- A button on `parent` reading `label`: the kit's leather `button` (`outlined` false) or its outlined `pbtn`, 44
--- high and as wide as its words with 26 either side, or `width` wide.
---@param parent Frame
---@param label string
---@param outlined boolean
---@param width number?
---@return PagleQoLNoteButton
function ns.NewNoteButton(parent, label, outlined, width)
	local button = CreateFrame("Button", nil, parent) --[[@as PagleQoLNoteButton]]
	local face = CreateFrame("Frame", nil, button)
	face:SetPoint("TOPLEFT")
	local words = CreateFrame("Frame", nil, button)
	words:SetAllPoints()
	words:SetFrameLevel(face:GetFrameLevel() + 1)
	button.Text = ns.ArtText(words, outlined and "NoteButton" or "Button")
	button.Text:SetJustifyH("CENTER")
	button.Text:SetText(label)
	button.Text:SetPoint("CENTER", button, "CENTER")
	width = width or math.floor(button.Text:GetStringWidth() + 52 + 0.5)
	ns.SetThreeSlice(face, "Field", outlined and "pbtn" or "button", width, outlined and 10 or 12, "ARTWORK")
	button:SetSize(width, 44)
	return button
end
