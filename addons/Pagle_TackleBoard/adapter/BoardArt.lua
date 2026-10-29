if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board art kit's helpers on the client (TKB-R100; tackle-board.md › UI): the kit's bundled fonts as font
-- objects, sprites from the atlases in data/BoardArt.lua, three-sliced and stacked strips, the papers' lean and its
-- switch, a dashed outline and the board's own tooltip. Every size is the kit canvas's CSS pixel, a UI unit. The sprite
-- helpers have the shape and names of Core's adapter/Art.lua (the announcements art) over the Tackle Board's own
-- atlases, as a Module reaches none of Core's code (ADR 0001). The fonts are Core's files in Pagle/media/fonts (Core is
-- a required dependency, CORE-R3).

local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
--- The faces (Pagle/media/fonts/OFL-*.txt): IM Fell English and its italic for print, its small caps for the Field
--- guide page's kickers, Caveat for the Angler's handwriting, Marcellus for gilt and brass.
ns.BOARD_FONT_FACES = {
	print = FONT_DIR .. "IMFeENrm28P.ttf",
	italic = FONT_DIR .. "IMFeENit28P.ttf",
	sc = FONT_DIR .. "IMFeENsc28P.ttf",
	gilt = FONT_DIR .. "Marcellus-Regular.ttf",
	hand = FONT_DIR .. "Caveat-Medium.ttf",
	handSemi = FONT_DIR .. "Caveat-SemiBold.ttf",
	handBold = FONT_DIR .. "Caveat-Bold.ttf",
}
-- What draws if a bundled face won't load: the client's own.
local FALLBACK = "Fonts\\FRIZQT__.TTF"

--- Each of the board's fonts, from the kit (PagleArtBoard's Board.lua, Overlays.lua, Tracker.lua): its face, size and
--- ink ("RRGGBB"), and whether it has a shadow (words on the dark frame, the drawer and the trackers do).
---@type table<string, { [1]: string, [2]: number, [3]: string, [4]: boolean? }>
ns.BOARD_FONTS = {
	-- the frame and the board's own notes
	Title = { "gilt", 17, "3A2406" },
	Updating = { "handSemi", 30, "23407A" },
	UpdatingNote = { "italic", 14, "6A4A28" },
	Welcome = { "print", 17, "2A180A" },
	Button = { "gilt", 17, "FBE8B0", true },
	ButtonSmall = { "gilt", 15, "FBE8B0", true },
	-- a Notice
	Kind = { "print", 11, "8A5A2A" },
	Pays = { "print", 12.5, "6A4A1A" },
	CoinNumber = { "gilt", 9.5, "4A2E04" },
	Goal = { "print", 15, "2A180A" },
	Progress = { "handSemi", 18.5, "23407A" },
	Where = { "italic", 13, "7A5A30" },
	Here = { "handSemi", 18, "2A6A2A" },
	Stranded = { "handSemi", 17, "8A6A4A" },
	TakeDown = { "handSemi", 17, "9A2A1A" },
	-- an Expedition's poster
	PosterKind = { "gilt", 11.5, "F6E3B0", true },
	PosterGoal = { "print", 19, "2A180A" },
	PosterProgress = { "handSemi", 22, "23407A" },
	PosterPays = { "print", 13, "6A4A1A" },
	Seal = { "gilt", 22, "F6DFA4" },
	-- an empty pin
	Empty = { "handBold", 21, "241002" },
	EmptyNote = { "italic", 14, "2E1806" },
	-- the spike
	SpikeHead = { "print", 11, "2C1606" },
	SpikeLabel = { "handSemi", 20, "2C1606" },
	DoneKind = { "print", 9.5, "8A5A2A" },
	DoneGoal = { "print", 13, "2A180A" },
	-- the done slip's goal text where its 13 would run past the paper (adapter/Ledge.lua, #471)
	DoneGoalSmall = { "print", 11.5, "2A180A" },
	DoneGoalTiny = { "print", 10.5, "2A180A" },
	DoneNote = { "handSemi", 16, "7A2A14" },
	-- the overflow strip
	Chip = { "print", 13.5, "2A180A" },
	ChipCount = { "handSemi", 17, "23407A" },
	ChipMore = { "handSemi", 18, "5A3A14" },
	-- the ledge
	FireDays = { "print", 27, "F8E6B4", true },
	FireWord = { "italic", 15, "D8C08A", true },
	FireState = { "print", 23, "F8E6B4", true },
	Longest = { "italic", 14, "CDB27A", true },
	BoxLabel = { "gilt", 14, "3A2410" },
	BoxCount = { "handSemi", 19, "23407A" },
	Tally = { "gilt", 16, "2E1A02" },
	TallyTitle = { "italic", 16, "4A2C04" },
	TallyNone = { "italic", 14, "6A4A18" },
	Shop = { "italic", 14, "3A2614" },
	-- the Campfire card
	CardTitle = { "print", 30, "3E220C" },
	CardFire = { "handSemi", 21, "23407A" },
	CardHead = { "print", 13, "8A5A2A" },
	CardNote = { "italic", 12.5, "8A6A40" },
	CardWeekday = { "print", 10.5, "8A5A2A" },
	CardWeek = { "italic", 12.5, "7A5A30" },
	CardToday = { "handSemi", 13, "23407A" },
	CardLegend = { "print", 13, "5A4028" },
	CardLabel = { "gilt", 14, "6A4A1A" },
	CardEarned = { "italic", 15, "2E1C0C" },
	CardNotEarned = { "italic", 15, "8A7458" },
	CardMore = { "handSemi", 15, "8A6A40" },
	CardCoins = { "print", 13, "6A4A1A" },
	CardClose = { "handSemi", 32, "7A2A14" },
	-- the Fly Box drawer
	DrawerTitle = { "gilt", 17, "F6DFA0", true },
	DrawerCount = { "handSemi", 21, "F0D898" },
	DrawerClose = { "handSemi", 24, "F0D898" },
	FlyName = { "gilt", 11.5, "EFE2C0", true },
	FlyNameRare = { "gilt", 11.5, "F6DC8A", true },
	FlyUntied = { "italic", 12.5, "A8B8A0", true },
	FlyUntiedRare = { "italic", 12.5, "D8C080", true },
	-- the take-it-down confirm
	ConfirmTitle = { "print", 19, "2A180A" },
	ConfirmText = { "italic", 14, "6A4A28" },
	ConfirmKeep = { "handSemi", 20, "5A3A14" },
	-- the RE-POSTED stamp
	Stamp = { "gilt", 14, "9A2A1A" },
	-- the tracker: No frame (the native look), Corkboard and Tideworn Plank
	TrackerTitle = { "gilt", 14, "FFD100", true },
	TrackerHeadRight = { "italic", 12.5, "E8D8A8", true },
	TrackerGoal = { "print", 13, "FFFFFF", true },
	TrackerCount = { "print", 13, "FFD100", true },
	TrackerWhere = { "print", 13, "C8C0A8", true },
	TrackerMore = { "italic", 13, "C8C0A8", true },
	CorkTitle = { "gilt", 14, "F8E6B4", true },
	CorkHeadRight = { "italic", 12.5, "F0DCAE", true },
	CorkGoal = { "print", 14, "2A180A" },
	CorkCount = { "handSemi", 17, "23407A" },
	CorkWhere = { "italic", 13, "6A4A28" },
	CorkMore = { "handSemi", 17, "241002" },
	DriftTitle = { "print", 13, "FFF2C8", true },
	DriftHeadRight = { "italic", 12.5, "E8D8A8", true },
	DriftGoal = { "print", 13, "FBF4E2", true },
	DriftCount = { "handSemi", 17, "FFE08A", true },
	DriftWhere = { "italic", 13, "D8CCB2", true },
	DriftMore = { "italic", 13, "C8C0A8", true },
	-- the Curio Shop expansion's tracker frames (TKB-R125; adapter/TrackerBlock.lua's kit styles), in their goods.json
	-- inks as the kit's board sets them: the title in gilt in the header ink, the header's right text and where lines
	-- in italics a size down and the plain lines in italics, in the dim ink, the goal lines in print in the text ink;
	-- with a shadow on a dark frame (Fishing Net, Tackle Tin, Live Embers)
	KitNetTitle = { "gilt", 14, "F0CD6A", true },
	KitNetHeadRight = { "italic", 12, "B8B4A0", true },
	KitNetGoal = { "print", 13, "F0ECE0", true },
	KitNetCount = { "print", 13, "F0ECE0", true },
	KitNetWhere = { "italic", 12, "B8B4A0", true },
	KitNetMore = { "italic", 13, "B8B4A0", true },
	KitBambooTitle = { "gilt", 14, "4A1A04" },
	KitBambooHeadRight = { "italic", 12, "4A3A14" },
	KitBambooGoal = { "print", 13, "1E1404" },
	KitBambooCount = { "print", 13, "1E1404" },
	KitBambooWhere = { "italic", 12, "4A3A14" },
	KitBambooMore = { "italic", 13, "4A3A14" },
	KitTinTitle = { "gilt", 14, "F0E080", true },
	KitTinHeadRight = { "italic", 12, "B8D0C0", true },
	KitTinGoal = { "print", 13, "F2F6EE", true },
	KitTinCount = { "print", 13, "F2F6EE", true },
	KitTinWhere = { "italic", 12, "B8D0C0", true },
	KitTinMore = { "italic", 13, "B8D0C0", true },
	KitBobberTitle = { "gilt", 14, "A81A10" },
	KitBobberHeadRight = { "italic", 12, "5A5448" },
	KitBobberGoal = { "print", 13, "1E1A14" },
	KitBobberCount = { "print", 13, "1E1A14" },
	KitBobberWhere = { "italic", 12, "5A5448" },
	KitBobberMore = { "italic", 13, "5A5448" },
	KitEmbersTitle = { "gilt", 14, "FFC060", true },
	KitEmbersHeadRight = { "italic", 12, "C8A888", true },
	KitEmbersGoal = { "print", 13, "F6EAD8", true },
	KitEmbersCount = { "print", 13, "F6EAD8", true },
	KitEmbersWhere = { "italic", 12, "C8A888", true },
	KitEmbersMore = { "italic", 13, "C8A888", true },
	-- the Field guide's page (ONB-R37; the onboarding kit's Guide.lua): kickers, titles, print, the facts, the italic
	-- line under Start my board and the button's gilt
	GuideKicker = { "sc", 14, "8A5A2A" },
	GuideTitle = { "print", 29, "3E220C" },
	GuideAsk = { "print", 25, "3E220C" },
	GuideBody = { "print", 15, "3A2614" },
	GuideSide = { "print", 14, "4A3018" },
	GuideFact = { "print", 14.5, "3E220C" },
	GuideNote = { "italic", 13, "7A5A30" },
	GuideButton = { "gilt", 18, "F4DFA8", true },
	-- the "?" on its brass pin beside the close mark (ONB-R59)
	HelpMark = { "gilt", 15, "3A2406" },
	-- the board's tooltip
	TipTitle = { "gilt", 15, "F6E3A8" },
	TipLine = { "print", 13.5, "E8DABC" },
	TipMuted = { "print", 13.5, "8A7A62" },
}

-- The font objects made so far, by key: each is made at its first use, so a font loads with the surface that shows it.
---@type table<string, Font>
local made = {}

--- A colour from its hex code ("RRGGBB"): { r, g, b }, 0 to 1.
---@param hex string
---@return number[]
function ns.BoardHex(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

--- The board's font `key` (ns.BOARD_FONTS) as a font object, PagleTackleBoard<key>, made at its first use: its face,
--- or the client's FRIZQT__ if the face won't load, in its size, ink and shadow.
---@param key string
---@return Font
function ns.ArtFont(key)
	local font = made[key]
	if font then
		return font
	end
	local def = assert(ns.BOARD_FONTS[key], "the Tackle Board has no font " .. tostring(key))
	font = CreateFont("PagleTackleBoard" .. key)
	if font:SetFont(ns.BOARD_FONT_FACES[def[1]], def[2], "") == false then
		font:SetFont(FALLBACK, def[2], "")
	end
	local color = ns.BoardHex(def[3])
	font:SetTextColor(color[1], color[2], color[3])
	if def[4] then
		font:SetShadowColor(0, 0, 0, 0.95)
		font:SetShadowOffset(0, -1)
	else
		font:SetShadowOffset(0, 0)
	end
	made[key] = font
	return font
end

--- Puts a font string in the board's font `key`, in that font's ink.
---@param fontString FontString
---@param key string
function ns.SetArtFont(fontString, key)
	fontString:SetFontObject(ns.ArtFont(key))
	ns.Ink(fontString, ns.BOARD_FONTS[key][3])
end

--- Colours a font string in an ink ("RRGGBB").
---@param fontString FontString
---@param hex string
function ns.Ink(fontString, hex)
	local color = ns.BoardHex(hex)
	fontString:SetTextColor(color[1], color[2], color[3])
end

--- A one-line font string on `frame` in the board's font `key`, left-justified.
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

--- A wrapping font string on `frame` in font `key`, `width` wide, its lines `spacing` apart.
---@param frame Frame
---@param key string
---@param width number
---@param spacing number?
---@return FontString
function ns.ArtWrap(frame, key, width, spacing)
	local fontString = ns.ArtText(frame, key)
	fontString:SetWordWrap(true)
	fontString:SetWidth(width)
	if spacing and fontString.SetSpacing then
		fontString:SetSpacing(spacing)
	end
	return fontString
end

--- Capitals with a space between letters and three between words: the kit's letter-spaced capitals, as the client
--- has no tracking.
---@param text string
---@return string
function ns.Spaced(text)
	local words = {}
	for word in text:upper():gmatch("%S+") do
		local letters = {}
		for letter in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
			letters[#letters + 1] = letter
		end
		words[#words + 1] = table.concat(letters, " ")
	end
	return table.concat(words, "   ")
end

-- Sprites.

---@class TackleSprite: Texture
---@field box number[]   -- where the drawn element sits in the texture, UI units from its top left: x, y, w, h

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
---@return TackleAtlas
---@return TackleAtlasSprite
local function spriteOf(atlasName, name)
	local atlas = ns.BOARD_ATLASES[atlasName]
	local sprite = atlas and atlas.sprites[name]
	if not sprite then
		error(("Pagle_TackleBoard: no sprite %s in the %s atlas"):format(tostring(name), tostring(atlasName)))
	end
	return atlas, sprite
end

--- Shows sprite `name` of atlas `atlasName` in `texture`, at its designed size.
---@param texture Texture
---@param atlasName string
---@param name string
---@return TackleSprite
function ns.SetSprite(texture, atlasName, name)
	local atlas, sprite = spriteOf(atlasName, name)
	local shown = texture --[[@as TackleSprite]]
	shown:SetTexture(atlas.file)
	shown:SetTexCoord(
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height
	)
	shown:SetSize(sprite.w / atlas.scale, sprite.h / atlas.scale)
	shown.box = { sprite.box[1], sprite.box[2], sprite.box[3], sprite.box[4] }
	return shown
end

--- Shows the part of sprite `name`'s drawn element `width` × `height` from `x`, `y` of its top left (UI units) in
--- `texture`, at that size: a cut of the board's art, as the Field guide's samples show the ledge (ONB-R37).
---@param texture Texture
---@param atlasName string
---@param name string
---@param x number
---@param y number
---@param width number
---@param height number
---@return Texture
function ns.SetSpriteCut(texture, atlasName, name, x, y, width, height)
	local atlas, sprite = spriteOf(atlasName, name)
	local scale = atlas.scale
	local x0, y0 = sprite.x + (sprite.box[1] + x) * scale, sprite.y + (sprite.box[2] + y) * scale
	crisp(texture)
	texture:SetTexture(atlas.file)
	texture:SetTexCoord(
		x0 / atlas.width,
		(x0 + width * scale) / atlas.width,
		y0 / atlas.height,
		(y0 + height * scale) / atlas.height
	)
	texture:SetSize(width, height)
	return texture
end

--- A texture on `frame` showing a sprite.
---@param frame Frame
---@param atlasName string
---@param name string
---@param layer DrawLayer?
---@param sublevel integer?
---@return TackleSprite
function ns.ArtSprite(frame, atlasName, name, layer, sublevel)
	return ns.SetSprite(crisp(frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)), atlasName, name)
end

--- Scales a sprite so its drawn element is `width` × `height` (height kept in proportion when nil).
---@param sprite TackleSprite
---@param width number
---@param height number?
function ns.SizeSprite(sprite, width, height)
	local box = sprite.box
	local kx = width / box[3]
	local ky = height and height / box[4] or kx
	local w, h = sprite:GetSize()
	sprite:SetSize(w * kx, h * ky)
	sprite.box = { box[1] * kx, box[2] * ky, width, box[4] * ky }
end

--- Anchors a sprite so its drawn element's top left is `x`, `y` from `relativeTo`'s top left (y grows downward).
---@param sprite TackleSprite
---@param relativeTo Region
---@param x number
---@param y number
function ns.PlaceSprite(sprite, relativeTo, x, y)
	sprite:ClearAllPoints()
	sprite:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x - sprite.box[1], -(y - sprite.box[2]))
end

--- Anchors a sprite so its drawn element's centre is on `relativeTo`'s centre.
---@param sprite TackleSprite
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

--- The first `width` UI units of a sprite's drawn element, cut to length rather than squeezed (a bar's fill).
---@param texture Texture
---@param atlasName string
---@param name string
---@param width number
---@return TackleSprite
function ns.SetCropSprite(texture, atlasName, name, width)
	local atlas, sprite = spriteOf(atlasName, name)
	local shown = texture --[[@as TackleSprite]]
	local x0 = sprite.x + sprite.box[1] * atlas.scale
	shown:SetTexture(atlas.file)
	shown:SetTexCoord(
		x0 / atlas.width,
		(x0 + width * atlas.scale) / atlas.width,
		sprite.y / atlas.height,
		(sprite.y + sprite.h) / atlas.height
	)
	shown:SetSize(width, sprite.h / atlas.scale)
	shown.box = { 0, sprite.box[2], width, sprite.box[4] }
	return shown
end

--- A frame drawn as a sprite sliced in three across: its end caps keep their size, its middle stretches.
---@class TackleThreeSlice: Frame
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
	local slice = frame --[[@as TackleThreeSlice]]
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

--- A frame drawn as a sprite sliced in three down: its top and bottom caps keep their size, its middle stretches.
---@class TackleVSlice: Frame
---@field top Texture
---@field middle Texture
---@field bottom Texture

--- Draws sprite `name` sliced in three down on `frame`: its drawn element `width` wide (squeezed or stretched across
--- from its own width) and `height` high, `capTop` and `capBottom` UI units of the element kept at the ends with the
--- sprite's margin outside them (a tracker frame, which grows with its lines). Makes the slices the first time.
---@param frame Frame
---@param atlasName string
---@param name string
---@param width number
---@param height number
---@param capTop number
---@param capBottom number
---@param layer DrawLayer?
function ns.SetVSlice(frame, atlasName, name, width, height, capTop, capBottom, layer)
	local slice = frame --[[@as TackleVSlice]]
	if not slice.top then
		slice.top = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
		slice.middle = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
		slice.bottom = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
	end
	local atlas, sprite = spriteOf(atlasName, name)
	local scale, box = atlas.scale, sprite.box
	if capTop + capBottom > height then
		capTop = math.floor(height / 2)
		capBottom = height - capTop
	end
	local k = width / box[3]
	local spriteHeight = sprite.h / scale
	local marginTop, marginBottom = box[2], spriteHeight - box[2] - box[4]
	local topHeight, bottomHeight = marginTop + capTop, capBottom + marginBottom
	local drawnWidth = sprite.w / scale * k
	frame:SetSize(width, height)
	local function cut(texture, from, span)
		local y0 = sprite.y + from * scale
		texture:SetTexture(atlas.file)
		texture:SetTexCoord(
			sprite.x / atlas.width,
			(sprite.x + sprite.w) / atlas.width,
			y0 / atlas.height,
			(y0 + span * scale) / atlas.height
		)
		texture:SetWidth(drawnWidth)
	end
	cut(slice.top, 0, topHeight)
	slice.top:SetHeight(topHeight)
	cut(slice.bottom, spriteHeight - bottomHeight, bottomHeight)
	slice.bottom:SetHeight(bottomHeight)
	cut(slice.middle, topHeight, spriteHeight - topHeight - bottomHeight)
	slice.top:ClearAllPoints()
	slice.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -box[1] * k, marginTop)
	slice.bottom:ClearAllPoints()
	slice.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -box[1] * k, -marginBottom)
	slice.middle:ClearAllPoints()
	slice.middle:SetPoint("TOPLEFT", slice.top, "BOTTOMLEFT")
	slice.middle:SetPoint("BOTTOMRIGHT", slice.bottom, "TOPRIGHT")
	slice.top:Show()
	slice.middle:Show()
	slice.bottom:Show()
	-- A Curio Shop expansion frame's pieces, from a kit frame drawn on this frame before (ns.SetKitSlice).
	local kit = frame --[[@as TackleKitSlice]]
	for _, piece in ipairs(kit.pieces or {}) do
		piece:Hide()
	end
end

--- A frame drawn as one of the Curio Shop expansion's tracker frames (TKB-R125): its pieces, top to bottom, as
--- logic/TrackerFrames.lua cuts them. On a frame that has drawn the board kit's (ns.SetVSlice), those slices too.
---@class TackleKitSlice: Frame
---@field pieces Texture[]
---@field top Texture?
---@field middle Texture?
---@field bottom Texture?

--- Draws sprite `name` of atlas `atlasName` sliced in three down on `frame` as `slice` says, its drawn element `width`
--- × `height` (a kit tracker frame, which grows with its lines): scaled evenly to `width`, its top and foot kept, its
--- middle stretched or repeated (ns.FrameSlices). Makes the pieces as it needs them, and hides the ones it doesn't and
--- any board kit slices drawn on `frame` before.
---@param frame Frame
---@param atlasName string
---@param name string
---@param slice TackleFrameSlice
---@param width number
---@param height number
---@param layer DrawLayer?
function ns.SetKitSlice(frame, atlasName, name, slice, width, height, layer)
	local kit = frame --[[@as TackleKitSlice]]
	kit.pieces = kit.pieces or {}
	for _, texture in ipairs({ kit.top, kit.middle, kit.bottom }) do
		texture:Hide()
	end
	local atlas, sprite = spriteOf(atlasName, name)
	local cut = ns.FrameSlices(atlas, sprite, slice, width, height)
	frame:SetSize(width, height)
	for i, piece in ipairs(cut.pieces) do
		local texture = kit.pieces[i]
		if not texture then
			texture = crisp(frame:CreateTexture(nil, layer or "BACKGROUND"))
			kit.pieces[i] = texture
		end
		texture:SetTexture(atlas.file)
		texture:SetTexCoord(cut.left, cut.right, piece.top, piece.bottom)
		texture:SetSize(cut.width, piece.height)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", cut.x, -piece.y)
		texture:Show()
	end
	for i = #cut.pieces + 1, #kit.pieces do
		kit.pieces[i]:Hide()
	end
end

-- The papers' lean (TKB-R102: a Notice "at a slight tilt that straightens on hover").

--- Whether the papers lean: PagleTackleBoardDB.profile.lean (on by default; no command sets it, only the saved
--- variable). Off, every paper hangs straight and nothing turns, for a client whose SetRotation shows the wrong part
--- of a texture.
---@return boolean
function ns.Leans()
	return not (ns.db and ns.db.profile.lean == false)
end

-- Turns `region` by `degrees` (clockwise, as the kit's CSS rotate), if it can turn and the papers lean; straight
-- otherwise. Returns the angle it turned by, in radians clockwise.
---@param region Region
---@param degrees number?
---@return number
local function turn(region, degrees)
	-- A texture turns; a font string turns where the client lets it, and stays straight where it doesn't.
	local turning = region --[[@as Texture]]
	local angle = 0
	if degrees and degrees ~= 0 and ns.Leans() and turning.SetRotation then
		angle = math.rad(degrees)
	end
	if turning.SetRotation then
		turning:SetRotation(-angle)
	end
	return angle
end

--- Leans a sprite by `degrees` about its drawn element's centre, the element's top left (unturned) at `x`, `y` from
--- `relativeTo`'s top left (y down). Straight while the papers don't lean.
---@param sprite TackleSprite
---@param relativeTo Region
---@param x number
---@param y number
---@param degrees number?
function ns.LeanSprite(sprite, relativeTo, x, y, degrees)
	local box = sprite.box
	local width, height = sprite:GetSize()
	-- The sprite's centre from its element's centre, turned with it.
	local ox, oy = width / 2 - (box[1] + box[3] / 2), height / 2 - (box[2] + box[4] / 2)
	local angle = turn(sprite, degrees)
	if angle ~= 0 then
		ox, oy = ox * math.cos(angle) - oy * math.sin(angle), ox * math.sin(angle) + oy * math.cos(angle)
	end
	sprite:ClearAllPoints()
	sprite:SetPoint("CENTER", relativeTo, "TOPLEFT", x + box[3] / 2 + ox, -(y + box[4] / 2 + oy))
end

--- Swings a region by `degrees` about `pivot` ({ x, y }), its unturned `box` ({ x, y, width, height }), both from
--- `relativeTo`'s top left (y down): a done slip and its words on the spike's nail. Straight while the papers don't
--- lean.
---@param region Region
---@param relativeTo Region
---@param box number[]
---@param degrees number
---@param pivot number[]
function ns.Swing(region, relativeTo, box, degrees, pivot)
	local cx, cy = box[1] + box[3] / 2, box[2] + box[4] / 2
	local px, py = pivot[1], pivot[2]
	local angle = turn(region, degrees)
	if angle ~= 0 then
		local dx, dy = cx - px, cy - py
		cx = px + dx * math.cos(angle) - dy * math.sin(angle)
		cy = py + dx * math.sin(angle) + dy * math.cos(angle)
	end
	region:ClearAllPoints()
	region:SetPoint("CENTER", relativeTo, "TOPLEFT", cx, -cy)
end

--- How a dashed outline is inked: in `hex` at `alpha`, `thickness` thick, `dash` units of ink then `gap` of nothing.
---@class TackleDashStyle
---@field hex string
---@field alpha number
---@field thickness number
---@field dash number
---@field gap number

--- A dashed outline round `width` × `height` from `frame`'s top left, inked as `style` says. Returns the dashes.
---@param frame Frame
---@param width number
---@param height number
---@param style TackleDashStyle
---@return Texture[]
function ns.DashBox(frame, width, height, style)
	local alpha, thickness, dash, gap = style.alpha, style.thickness, style.dash, style.gap
	local color, dashes = ns.BoardHex(style.hex), {}
	local function add(x, y, w, h)
		local texture = frame:CreateTexture(nil, "BORDER")
		texture:SetColorTexture(color[1], color[2], color[3], alpha)
		texture:SetSize(w, h)
		texture:SetPoint("TOPLEFT", x, -y)
		dashes[#dashes + 1] = texture
	end
	for i = 0, width - 1, dash + gap do
		add(i, 0, math.min(dash, width - i), thickness)
		add(i, height - thickness, math.min(dash, width - i), thickness)
	end
	for i = 0, height - 1, dash + gap do
		add(0, i, thickness, math.min(dash, height - i))
		add(width - thickness, i, thickness, math.min(dash, height - i))
	end
	return dashes
end

--- A solid `hex` at `alpha` filling `frame`.
---@param frame Frame
---@param hex string
---@param alpha number?
---@param layer DrawLayer?
---@param sublevel integer?
---@return Texture
function ns.BoardSolid(frame, hex, alpha, layer, sublevel)
	local color = ns.BoardHex(hex)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	texture:SetAllPoints()
	return texture
end

-- The board's tooltip (TKB-R102, TKB-R103, TKB-R106): a dark card with a gilt rule, its first line in gilt and the
-- rest in print, sized to its words; a Variety Expedition's Species ticked, a done goal's fly drawn.

--- The tooltip's frame, made at its first showing.
---@class TackleTipFrame: Frame
---@field title FontString
---@field lines FontString[]
---@field marks TackleSprite[]
---@field fly TackleSprite
---@field words string[]   -- the words it shows now: its title, then each line (Species by name)

---@type TackleTipFrame?
local tip

-- The tooltip's width and its padding, UI units.
local TIP_WIDTH, TIP_PAD = 300, 13

---@return TackleTipFrame
local function tipFrame()
	if tip then
		return tip
	end
	local frame = CreateFrame("Frame", nil, UIParent) --[[@as TackleTipFrame]]
	frame:SetFrameStrata("TOOLTIP")
	frame:SetSize(TIP_WIDTH, 40)
	local edge = ns.BoardSolid(frame, "2A1A08", 1, "BACKGROUND", 0)
	edge:ClearAllPoints()
	edge:SetPoint("TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", 2, -2)
	local gilt = ns.BoardSolid(frame, "C9A24A", 1, "BACKGROUND", 1)
	gilt:ClearAllPoints()
	gilt:SetPoint("TOPLEFT", -1, 1)
	gilt:SetPoint("BOTTOMRIGHT", 1, -1)
	ns.BoardSolid(frame, "170E07", 0.97, "BACKGROUND", 2)
	frame.title = ns.ArtWrap(frame, "TipTitle", TIP_WIDTH - 2 * TIP_PAD)
	frame.title:SetPoint("TOPLEFT", TIP_PAD, -9)
	frame.lines, frame.marks = {}, {}
	-- Its fly's sprite is set only when a done goal's tooltip shows one, so the flies load with their first.
	frame.fly = crisp(frame:CreateTexture(nil, "OVERLAY")) --[[@as TackleSprite]]
	frame.fly:Hide()
	frame.words = {}
	frame:Hide()
	tip = frame
	return frame
end

--- What the board's tooltip shows besides its lines: a Variety Expedition's Species, each ticked once caught
--- (TKB-R102), and the pattern a done goal tied, drawn by its line (TKB-R103).
---@class TackleTipExtra
---@field species TackleHoverSpecies[]?
---@field fly string?    -- a pattern ID
---@field cursor boolean? -- at the cursor rather than by its owner

--- Shows the board's tooltip by `owner`: `lines[1]` as its title in gilt, the rest under it, then `extra`.
---@param owner Region
---@param lines string[]
---@param extra TackleTipExtra?
function ns.BoardHover(owner, lines, extra)
	local frame = tipFrame()
	extra = extra or {}
	local inner = TIP_WIDTH - 2 * TIP_PAD
	frame.words = {}
	frame.title:SetText(lines[1] or "")
	frame.words[1] = lines[1]
	local y = 9 + frame.title:GetStringHeight() + 4
	local used = 0
	-- A line on the tooltip at `y`, `indent` in, in font `key`.
	local function line(text, key, indent)
		used = used + 1
		local fontString = frame.lines[used]
		if not fontString then
			fontString = ns.ArtWrap(frame, "TipLine", inner, 4)
			frame.lines[used] = fontString
		end
		ns.SetArtFont(fontString, key)
		fontString:SetWidth(inner - indent)
		fontString:ClearAllPoints()
		fontString:SetPoint("TOPLEFT", TIP_PAD + indent, -y)
		fontString:SetText(text)
		fontString:Show()
		frame.words[#frame.words + 1] = text
		return fontString
	end
	frame.fly:Hide()
	for i = 2, #lines do
		local text = lines[i]
		local indent = 0
		if extra.fly and i == #lines then
			ns.SetSprite(frame.fly, "Flies", "fly-" .. extra.fly)
			ns.SizeSprite(frame.fly, 64)
			ns.PlaceSprite(frame.fly, frame, TIP_PAD, y)
			frame.fly:Show()
			indent = 72
		end
		local fontString = line(text, "TipLine", indent)
		y = y + math.max(fontString:GetStringHeight(), indent > 0 and 38 or 0) + 4
	end
	for i, species in ipairs(extra.species or {}) do
		local mark = frame.marks[i]
		if not mark then
			mark = ns.ArtSprite(frame, "Board", "tick", "OVERLAY")
			frame.marks[i] = mark
		end
		ns.SetSprite(mark, "Board", species.caught and "tick" or "notick")
		ns.PlaceSprite(mark, frame, TIP_PAD, y + 4)
		mark:Show()
		local fontString = line(species.name, species.caught and "TipLine" or "TipMuted", 16)
		y = y + fontString:GetStringHeight() + 4
	end
	for i = #(extra.species or {}) + 1, #frame.marks do
		frame.marks[i]:Hide()
	end
	for i = used + 1, #frame.lines do
		frame.lines[i]:Hide()
	end
	frame:SetHeight(y + 6)
	frame:ClearAllPoints()
	if extra.cursor then
		-- GetCursorPosition is in screen pixels: UIParent's scale makes them its units.
		local x, cursorY = GetCursorPosition()
		local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 14, cursorY / scale + 10)
	else
		frame:SetPoint("TOPLEFT", owner, "TOPRIGHT", 10, 0)
	end
	frame:Show()
end

--- Hides the board's tooltip.
function ns.BoardHoverHide()
	if tip then
		tip:Hide()
	end
end

--- What the board's tooltip shows now (its title, then each line), or nil while it is hidden.
---@return string[]?
function ns.BoardHoverLines()
	if tip and tip:IsShown() then
		return tip.words
	end
	return nil
end
