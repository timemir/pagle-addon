if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger art kit on the client (ledger.md › UI): its inks and fonts, its sounds, the fit to the screen, and the
-- sprite helpers and small pieces every page draws with, over data/JournalArt.lua's atlases. They are the kit's
-- Kit.lua, LedgerKit.lua, Sound.lua and Fit.lua (PagleArtLedger), copied over the Ledger's namespace: every size is the
-- canvas's CSS pixel, a UI unit, and a sprite's `box` is where its drawn element sits in it. The fonts are Core's
-- (Pagle/media/fonts; Core is a required dependency, so they are always there).

--- The kit's inks, by name, as the canvas's CSS writes them.
ns.JOURNAL_INK = {
	kicker = "8a5a2a",
	title = "3e220c",
	body = "3a2614",
	small = "5a4028",
	note = "7a5a30",
	noteLight = "8a6a40",
	hand = "23407a",
	red = "9a2a1a",
	green = "2a6a2a",
	brown = "7a3a10",
	rule = "c4a874",
	ghost = "b8a080",
	tileInk = "6a4a20",
	faded = "9a8060",
	link = "7a2a14",
	hover = "7a2a14",
	wax = "f4dfa8",
	gilt = "e8c96a",
	giltLight = "fff4c8",
	brass = "2a1a04",
	field = "efe0bb",
	trim = "8a5a2a",
}
local INK = ns.JOURNAL_INK

-- Each tint made from its hex, once.
---@type table<string, number[]>
local tints = {}

--- `hex`'s tint as r, g, b (0 to 1), made once.
---@param hex string
---@return number r
---@return number g
---@return number b
function ns.JournalRGB(hex)
	local tint = tints[hex]
	if not tint then
		tint = ns.HexTint(hex)
		tints[hex] = tint
	end
	return tint[1], tint[2], tint[3]
end
local rgb = ns.JournalRGB

-- ---------------------------------------------------------------- fonts

local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
-- The faces (Pagle/media/fonts/OFL-*.txt): IM Fell English for print, its italic for notes and its small capitals
-- for kickers, group headings, tabs and stamps; Caveat for the Angler's handwriting; Marcellus for gilt, wax and brass.
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

---@alias LedgerArtFace "print"|"italic"|"sc"|"gilt"|"hand"|"handSemi"|"handBold"

--- A face's file, for a spec or a probe to read.
---@param face LedgerArtFace
---@return string
function ns.JournalFontFile(face)
	return FONT_DIR .. assert(FACES[face], "the Ledger kit has no face " .. tostring(face))
end

---@type table<string, Font>
local fonts = {}

--- The kit's font object in `face` at `size`, with a shadow when `shadow` (words on the leather and the wax; never on
--- paper), made once. Its ink is the font string's.
---@param face LedgerArtFace
---@param size number
---@param shadow boolean?
---@return Font
function ns.JournalFont(face, size, shadow)
	local key = ("%s:%s:%s"):format(face, size, shadow and 1 or 0)
	local font = fonts[key]
	if not font then
		local name = ("PagleLedgerArt_%s_%s%s"):format(face, (tostring(size):gsub("%.", "_")), shadow and "_s" or "")
		font = CreateFont(name)
		if font:SetFont(ns.JournalFontFile(face), size, "") == false then
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

--- A font string on `parent` in `face` at `size` and ink `hex`, its font set before any text. `options`, each
--- optional: `wrap` (and `width`), `spacing` between wrapped lines, `justify`, `shadow` and `layer`.
---@param parent Frame
---@param face LedgerArtFace
---@param size number
---@param hex string
---@param text string?
---@param options { wrap: boolean?, width: number?, spacing: number?, justify: string?, shadow: boolean?, layer: DrawLayer? }?
---@return FontString
function ns.JournalLabel(parent, face, size, hex, text, options)
	options = options or {}
	local label = parent:CreateFontString(nil, options.layer or "OVERLAY")
	label:SetFontObject(ns.JournalFont(face, size, options.shadow))
	label:SetTextColor(rgb(hex))
	label:SetJustifyH(options.justify or "LEFT")
	label:SetWordWrap(options.wrap == true)
	if options.width then
		label:SetWidth(options.width)
	end
	if options.wrap then
		local hand = face:sub(1, 4) == "hand"
		label:SetSpacing(options.spacing or (hand and 2 or math.floor(size * 0.33 + 0.5)))
	end
	label:SetText(text or "")
	return label
end

--- Sets `label`'s face, size and ink anew (a row's name, written in once a fish is caught).
---@param label FontString
---@param face LedgerArtFace
---@param size number
---@param hex string
function ns.JournalRestyle(label, face, size, hex)
	label:SetFontObject(ns.JournalFont(face, size))
	label:SetTextColor(rgb(hex))
end

-- ---------------------------------------------------------------- sprites

--- A texture showing a sprite: `box` is where its drawn element sits in it.
---@class LedgerSpriteTexture: Texture
---@field box number[]
---@field sprite string?    -- the stamp it shows, for a spec to read

-- Stretched art: no pixel snapping, or it shimmers as the book moves.
---@param texture Texture
---@return Texture
local function crisp(texture)
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(false)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
	end
	return texture
end
ns.JournalCrisp = crisp

---@param atlas string
---@param name string
---@return LedgerArtAtlas
---@return LedgerArtSprite
local function spriteOf(atlas, name)
	local found = ns.JOURNAL_ATLASES[atlas]
	local sprite = found and found.sprites[name]
	if not sprite then
		error(("Pagle Ledger: no sprite %s in %s"):format(tostring(name), tostring(atlas)))
	end
	return found, sprite
end

--- A texel rectangle inside a sprite, from the sprite's origin: { x, y, width, height }.
---@alias LedgerCut number[]

--- Texture coordinates for the texel rectangle `cut` inside sprite `name` of `atlas` (the whole sprite without one).
---@param atlas string
---@param name string
---@param cut LedgerCut?
---@return number left
---@return number right
---@return number top
---@return number bottom
function ns.JournalCoords(atlas, name, cut)
	local found, sprite = spriteOf(atlas, name)
	cut = cut or { 0, 0, sprite.w, sprite.h }
	local x0, y0 = sprite.x + cut[1], sprite.y + cut[2]
	return x0 / found.width, (x0 + cut[3]) / found.width, y0 / found.height, (y0 + cut[4]) / found.height
end

--- A texture of part of sprite `name` (the texel rectangle `cut`, the whole sprite without one), unsized.
---@param parent Frame
---@param atlas string
---@param name string
---@param layer DrawLayer?
---@param sub integer?
---@param cut LedgerCut?
---@return Texture
function ns.JournalPiece(parent, atlas, name, layer, sub, cut)
	local found = spriteOf(atlas, name)
	local texture = crisp(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
	texture:SetTexture(found.file)
	texture:SetTexCoord(ns.JournalCoords(atlas, name, cut))
	return texture
end

--- A texture showing sprite `name` whole at its drawn size, scaled so its box is `w` wide (and `h` tall, or in
--- proportion) when given.
---@param parent Frame
---@param atlas string
---@param name string
---@param layer DrawLayer?
---@param sub integer?
---@param w number?
---@param h number?
---@return LedgerSpriteTexture
function ns.JournalSprite(parent, atlas, name, layer, sub, w, h)
	local found, sprite = spriteOf(atlas, name)
	local texture = ns.JournalPiece(parent, atlas, name, layer, sub) --[[@as LedgerSpriteTexture]]
	local box = sprite.box
	local kx = w and w / box[3] or 1
	local ky = h and h / box[4] or kx
	texture:SetSize(sprite.w / found.scale * kx, sprite.h / found.scale * ky)
	texture.box = { box[1] * kx, box[2] * ky, box[3] * kx, box[4] * ky }
	return texture
end

--- Re-points a sprite texture at sprite `name` (same atlas, same box size: a stamp inked, a check ticked).
---@param texture LedgerSpriteTexture
---@param atlas string
---@param name string
function ns.JournalSetSprite(texture, atlas, name)
	texture:SetTexCoord(ns.JournalCoords(atlas, name))
end

--- Places a region's own top left at (x, y) from `rel`'s top left, y down: the frame's corner, whatever it draws.
--- ns.JournalBoxAt places a sprite by its drawn box instead.
---@param region Region
---@param rel Region
---@param x number
---@param y number
---@return Region
function ns.JournalAt(region, rel, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", rel, "TOPLEFT", x, -y)
	return region
end

--- Places a sprite so its drawn box's top left lands at (x, y) from `rel`'s top left (y down): the art, not the
--- texture's corner, which sits out by the transparent margin round it (ns.JournalSprite's `box`). ns.JournalAt
--- places a region by its own corner instead.
---@param texture LedgerSpriteTexture
---@param rel Region
---@param x number
---@param y number
function ns.JournalBoxAt(texture, rel, x, y)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", rel, "TOPLEFT", x - texture.box[1], -(y - texture.box[2]))
end

--- Centres a sprite's box on (cx, cy) from `rel`'s top left (y down).
---@param texture LedgerSpriteTexture
---@param rel Region
---@param cx number
---@param cy number
function ns.JournalCenter(texture, rel, cx, cy)
	local box = texture.box
	local w, h = texture:GetSize()
	local ox, oy = (box[1] + box[3] / 2) - w / 2, (box[2] + box[4] / 2) - h / 2
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", rel, "TOPLEFT", cx - ox, -(cy - oy))
end

--- A solid tint on `parent`.
---@param parent Frame
---@param hex string
---@param alpha number?
---@param layer DrawLayer?
---@param sub integer?
---@return Texture
function ns.JournalTint(parent, hex, alpha, layer, sub)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	local r, g, b = rgb(hex)
	texture:SetColorTexture(r, g, b, alpha or 1)
	return texture
end

--- A three-slice of sprite `name` across `width` (a tile, a button, the ink bar's case): its ends keep `cap` units of
--- the box (with the sprite's margin), the middle stretches. A frame `width` wide and the box's height.
---@class LedgerThreeSlice: Frame
---@field slices Texture[]

---@param parent Frame
---@param atlas string
---@param name string
---@param width number
---@param cap number
---@param layer DrawLayer?
---@return LedgerThreeSlice
function ns.JournalThreeSlice(parent, atlas, name, width, cap, layer)
	local found, sprite = spriteOf(atlas, name)
	local scale = found.scale
	local bx, by, bw, bh = sprite.box[1], sprite.box[2], sprite.box[3], sprite.box[4]
	local frame = CreateFrame("Frame", nil, parent) --[[@as LedgerThreeSlice]]
	frame:SetFrameLevel(parent:GetFrameLevel())
	frame:SetSize(width, bh)
	local full = sprite.w / scale
	local marginL, marginR = bx, full - bx - bw
	local leftW, rightW = marginL + cap, cap + marginR
	local function piece(u0, uw)
		local texture =
			ns.JournalPiece(frame, atlas, name, layer or "BACKGROUND", 0, { u0 * scale, 0, uw * scale, sprite.h })
		texture:SetHeight(sprite.h / scale)
		return texture
	end
	local left = piece(0, leftW)
	left:SetWidth(leftW)
	local right = piece(full - rightW, rightW)
	right:SetWidth(rightW)
	local middle = piece(leftW, full - leftW - rightW)
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", -marginL, by)
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", marginR, by)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	frame.slices = { left, middle, right }
	return frame
end

--- Resizes a three-slice to `width` (its middle stretches).
---@param slice LedgerThreeSlice
---@param width number
function ns.JournalSliceWidth(slice, width)
	slice:SetWidth(width)
end

--- A vertical three-slice of sprite `name`, `height` tall: its top and bottom keep `capT` and `capB` units of the box
--- (with the sprite's margin), the middle stretches (the search drop-down, the Prestige card).
---@param parent Frame
---@param atlas string
---@param name string
---@param height number
---@param capT number
---@param capB number
---@param layer DrawLayer?
---@return Frame
function ns.JournalVSlice(parent, atlas, name, height, capT, capB, layer)
	local found, sprite = spriteOf(atlas, name)
	local scale = found.scale
	local bx, by, bw, bh = sprite.box[1], sprite.box[2], sprite.box[3], sprite.box[4]
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel(parent:GetFrameLevel())
	frame:SetSize(bw, height)
	local full = sprite.h / scale
	local marginT, marginB = by, full - by - bh
	local topH, bottomH = marginT + capT, capB + marginB
	local function piece(v0, vh)
		local texture =
			ns.JournalPiece(frame, atlas, name, layer or "BACKGROUND", 0, { 0, v0 * scale, sprite.w, vh * scale })
		texture:SetWidth(sprite.w / scale)
		return texture
	end
	local top = piece(0, topH)
	top:SetHeight(topH)
	local bottom = piece(full - bottomH, bottomH)
	bottom:SetHeight(bottomH)
	local middle = piece(topH, full - topH - bottomH)
	top:SetPoint("TOPLEFT", frame, "TOPLEFT", -bx, marginT)
	bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -bx, -marginB)
	middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
	return frame
end

--- The first `w` units of sprite `name`'s box, unstretched: an ink fill cut to length.
---@param parent Frame
---@param atlas string
---@param name string
---@param w number
---@param layer DrawLayer?
---@param sub integer?
---@return LedgerSpriteTexture
function ns.JournalCrop(parent, atlas, name, w, layer, sub)
	local found, sprite = spriteOf(atlas, name)
	local texture = crisp(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)) --[[@as LedgerSpriteTexture]]
	texture:SetTexture(found.file)
	texture:SetHeight(sprite.h / found.scale)
	texture.box = { 0, sprite.box[2], w, sprite.box[4] }
	ns.JournalCropWidth(texture, atlas, name, w)
	return texture
end

--- Cuts a cropped sprite to a new length (an ink fill running on); hidden when nothing is left.
---@param texture Texture
---@param atlas string
---@param name string
---@param w number
function ns.JournalCropWidth(texture, atlas, name, w)
	if w < 0.5 then
		texture:Hide()
		return
	end
	local found, sprite = spriteOf(atlas, name)
	texture:Show()
	local x0 = sprite.x + sprite.box[1] * found.scale
	texture:SetTexCoord(
		x0 / found.width,
		(x0 + w * found.scale) / found.width,
		sprite.y / found.height,
		(sprite.y + sprite.h) / found.height
	)
	texture:SetWidth(w)
end

--- A 1-unit outline (the canvas's `border: 1px solid`), `t` thick: top, bottom, left, right.
---@param parent Frame
---@param x number
---@param y number
---@param w number
---@param h number
---@param hex string
---@param alpha number?
---@param layer DrawLayer?
---@param t number?
---@return Texture[]
function ns.JournalOutline(parent, x, y, w, h, hex, alpha, layer, t)
	t = t or 1
	local edges = {}
	for i, r in ipairs({ { x, y, w, t }, { x, y + h - t, w, t }, { x, y, t, h }, { x + w - t, y, t, h } }) do
		local edge = ns.JournalTint(parent, hex, alpha, layer)
		edge:SetSize(r[3], r[4])
		ns.JournalAt(edge, parent, r[1], r[2])
		edges[i] = edge
	end
	return edges
end

--- A 1-unit dashed outline (the canvas's `outline: 1px dashed`), drawn as short dashes on a frame of its own.
---@param parent Frame
---@param x number
---@param y number
---@param w number
---@param h number
---@param hex string
---@param alpha number?
---@param layer DrawLayer?
---@return Frame
function ns.JournalDashes(parent, x, y, w, h, hex, alpha, layer)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(w, h)
	ns.JournalAt(frame, parent, x, y)
	local dash, gap = 3, 2
	local function line(dx, dy, dw, dh)
		local texture = ns.JournalTint(frame, hex, alpha, layer, 2)
		texture:SetSize(dw, dh)
		ns.JournalAt(texture, frame, dx, dy)
	end
	for i = 0, w - 1, dash + gap do
		line(i, 0, math.min(dash, w - i), 1)
		line(i, h - 1, math.min(dash, w - i), 1)
	end
	for i = 0, h - 1, dash + gap do
		line(0, i, 1, math.min(dash, h - i))
		line(w - 1, i, 1, math.min(dash, h - i))
	end
	return frame
end

--- A dotted line kept on a widget and laid anew at each draw (a contents line's leader, a link's underline), its dots
--- pooled.
---@class LedgerDotLine: Frame
---@field dots Texture[]
---@field Lay fun(self: LedgerDotLine, x: number, y: number, w: number)

---@param parent Frame
---@param hex string
---@param alpha number?
---@param step number?
---@return LedgerDotLine
function ns.JournalDotLine(parent, hex, alpha, step)
	local line = CreateFrame("Frame", nil, parent) --[[@as LedgerDotLine]]
	line.dots = {}
	step = step or 3
	function line.Lay(self, x, y, w)
		self:SetSize(math.max(1, w), 1)
		ns.JournalAt(self, parent, x, y)
		local count = w >= 1 and math.floor((w - 1) / step) + 1 or 0
		for i = 1, math.max(count, #self.dots) do
			local dot = self.dots[i]
			if i <= count then
				if not dot then
					dot = ns.JournalTint(self, hex, alpha)
					dot:SetSize(1, 1)
					self.dots[i] = dot
				end
				ns.JournalAt(dot, self, (i - 1) * step, 0)
				dot:Show()
			elseif dot then
				dot:Hide()
			end
		end
		self:Show()
	end
	line:Hide()
	return line
end

--- The fleuron rule: the fleuron between two lines that fade toward the edges, `w` wide at (x, y).
---@param parent Frame
---@param x number
---@param y number
---@param w number
---@return Frame
function ns.JournalRule(parent, x, y, w)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(w, 14)
	ns.JournalAt(frame, parent, x, y)
	local cx = w / 2
	local fleuron = ns.JournalSprite(frame, "Book", "fleuron", "ARTWORK", 0, 14)
	fleuron:SetAlpha(0.8)
	ns.JournalBoxAt(fleuron, frame, cx - 7, 0)
	local clear, solid = CreateColor(0.77, 0.66, 0.45, 0), CreateColor(0.77, 0.66, 0.45, 1)
	local left = ns.JournalTint(frame, "ffffff")
	left:SetSize(math.max(1, cx - 17), 1)
	ns.JournalAt(left, frame, 0, 7)
	left:SetGradient("HORIZONTAL", clear, solid)
	local right = ns.JournalTint(frame, "ffffff")
	right:SetSize(math.max(1, cx - 17), 1)
	ns.JournalAt(right, frame, cx + 17, 7)
	right:SetGradient("HORIZONTAL", solid, clear)
	return frame
end

-- ---------------------------------------------------------------- the kit's pieces

--- Shows `icon` on `texture` in the Journal's sepia (LED-R140, ledger.md › UI): an item ID's icon, or a texture,
--- desaturated about 60% and warmed toward sepia, as the canvas draws every icon; or, `look` "silhouette", in black
--- (LED-R124).
---@param texture Texture
---@param icon integer|string? an item ID or a texture
---@param look "sepia"|"silhouette"?
function ns.JournalItemIcon(texture, icon, look)
	if type(icon) == "number" then
		local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
		icon = fileID or icon
	end
	texture:SetTexture(icon)
	if look == "silhouette" then
		texture:SetDesaturated(true)
		texture:SetVertexColor(0, 0, 0)
	else
		if texture.SetDesaturation then
			texture:SetDesaturation(0.6)
		else
			texture:SetDesaturated(true)
		end
		texture:SetVertexColor(1, 0.94, 0.82)
	end
	texture:SetAlpha(1)
end

-- The medallion rings by size, and the unknown fish's (one outline for every unknown, so it never hints which fish).
local RINGS = { [26] = "medal", [44] = "medal-44", [60] = "medal-lg" }
local UNKNOWN = { [26] = "medal-unk", [44] = "medal-unk-44", [60] = "medal-unk-lg", [88] = "medal-unk-lg" }

--- A round medallion: the game's icon masked round, in sepia, in the double ink ring; or for what isn't caught, the
--- unknown fish in its dashed ring, never the item's own icon (LED-R124).
---@class LedgerMedal: Frame
---@field icon Texture
---@field ring LedgerSpriteTexture
---@field unknown LedgerSpriteTexture
---@field size number

---@param parent Frame
---@param size number 26, 44, 60 or 88
---@return LedgerMedal
function ns.JournalMedal(parent, size)
	local medal = CreateFrame("Frame", nil, parent) --[[@as LedgerMedal]]
	medal:SetSize(size, size)
	medal.size = size
	local inset = size >= 44 and 2 or 1.5
	medal.icon = crisp(medal:CreateTexture(nil, "ARTWORK", nil, 0))
	medal.icon:SetSize(size - 2 * inset, size - 2 * inset)
	medal.icon:SetPoint("CENTER")
	local mask = medal:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(medal.icon)
	medal.icon:AddMaskTexture(mask)
	medal.ring = ns.JournalSprite(medal, "Parts", RINGS[size] or "medal-lg", "ARTWORK", 1, size)
	ns.JournalBoxAt(medal.ring, medal, 0, 0)
	medal.unknown = ns.JournalSprite(medal, "Parts", UNKNOWN[size] or "medal-unk", "ARTWORK", 0, size)
	ns.JournalBoxAt(medal.unknown, medal, 0, 0)
	return medal
end

--- Shows `icon` on medallion `medal`, or the unknown fish while `look` is "silhouette" (LED-R124).
---@param medal LedgerMedal
---@param icon integer|string?
---@param look "sepia"|"silhouette"?
function ns.JournalSetMedal(medal, icon, look)
	local unknown = look == "silhouette" or icon == nil
	medal.unknown:SetShown(unknown)
	medal.icon:SetShown(not unknown)
	medal.ring:SetShown(not unknown)
	if unknown then
		medal.icon:SetTexture(nil) -- never left holding an uncaught item's icon (LED-R124)
	else
		ns.JournalItemIcon(medal.icon, icon, "sepia")
	end
end

--- The ink bar: an empty case and a striped fill cut to length, with Fresh Water's blue stretch ahead of it.
---@class LedgerInkBar: Frame
---@field fill LedgerSpriteTexture
---@field fresh Texture
---@field edge Texture
---@field case LedgerThreeSlice
---@field width number
---@field pct number
---@field freshPct number
---@field Set fun(self: LedgerInkBar, pct: number, fresh: number?)

---@param parent Frame
---@param width number
---@return LedgerInkBar
function ns.JournalInkBar(parent, width)
	local bar = CreateFrame("Frame", nil, parent) --[[@as LedgerInkBar]]
	bar:SetSize(width, 12)
	bar.width = width
	bar.case = ns.JournalThreeSlice(bar, "Parts", "ink-empty", width, 7, "ARTWORK")
	bar.case:SetPoint("TOPLEFT")
	bar.fill = ns.JournalCrop(bar, "Parts", "ink-full", 1, "ARTWORK", 1)
	ns.JournalAt(bar.fill, bar, 0, -1)
	bar.fresh = ns.JournalTint(bar, INK.hand, 0.58, "ARTWORK", 2)
	bar.fresh:SetHeight(9)
	bar.edge = ns.JournalTint(bar, INK.hand, 1, "ARTWORK", 3)
	bar.edge:SetSize(1, 9)
	function bar.Set(self, pct, fresh)
		local inner = self.width - 3
		local x = 1.5 + inner * math.max(0, math.min(1, pct))
		ns.JournalCropWidth(self.fill, "Parts", "ink-full", x)
		local stretch = inner * (fresh or 0)
		self.fresh:SetShown(stretch > 0.5)
		self.edge:SetShown(stretch > 0.5)
		self.fresh:SetWidth(math.max(0.01, math.min(stretch, self.width - 1.5 - x)))
		ns.JournalAt(self.fresh, self, x, 1.5)
		ns.JournalAt(self.edge, self, x, 1.5)
		self.pct, self.freshPct = pct, fresh or 0
	end
	bar:Set(0, 0)
	return bar
end

--- Resizes an ink bar to `width`.
---@param bar LedgerInkBar
---@param width number
function ns.JournalInkBarWidth(bar, width)
	bar.width = width
	bar:SetWidth(width)
	ns.JournalSliceWidth(bar.case, width)
	bar:Set(bar.pct or 0, bar.freshPct)
end

-- The kit's stamps by their words, lowercased: inked red, or in ghost ink when not earned.
local STAMPS = {
	["caught"] = "stamp-caught",
	["in its element"] = "stamp-in-its-element",
	["regular"] = "stamp-regular",
	["any weight"] = "stamp-any-weight",
	["half the weights"] = "stamp-half-the-weights",
	["the heaviest"] = "stamp-the-heaviest",
	["whopper"] = "stamp-whopper",
}

--- The kit's stamp sprite for a stamp's words (LED-R140, LED-R143), inked or in ghost ink; nil for words it has none
--- for.
---@param words string
---@param inked boolean
---@return string?
function ns.JournalStampSprite(words, inked)
	local name = STAMPS[words:lower()]
	return name and (inked and name or name .. "-off") or nil
end

--- Stars as textures, `size` the glyph's font size: `stars` (LED-R48) each inked or blank, three in all.
---@class LedgerStarsView: Frame
---@field stars LedgerSpriteTexture[]

---@param parent Frame
---@param size number
---@return LedgerStarsView
function ns.JournalStarRow(parent, size)
	local frame = CreateFrame("Frame", nil, parent) --[[@as LedgerStarsView]]
	local k, step = size / 13, 12.5 * size / 12
	frame:SetSize(step * 3, size)
	frame.stars = {}
	for i = 1, 3 do
		local star = ns.JournalSprite(frame, "Parts", "star", "ARTWORK", 0, 11.5 * k)
		ns.JournalAt(star, frame, (i - 1) * step + 0.5, 2.5 * k)
		frame.stars[i] = star
	end
	return frame
end

--- Inks `view`'s stars: each of the three inked when `stars[i]`.
---@param view LedgerStarsView
---@param stars table<integer, boolean>
function ns.JournalSetStars(view, stars)
	for i, star in ipairs(view.stars) do
		ns.JournalSetSprite(star, "Parts", stars[i] and "star" or "star-off")
	end
end

--- A wax seal with its words, tilted (LED-R132, LED-R135): the wax disc, or the empty ring for "not yet".
---@class LedgerSeal: Frame
---@field wax Texture
---@field empty Texture
---@field label FontString
---@field size number

---@param parent Frame
---@param size number
---@param textSize number?
---@return LedgerSeal
function ns.JournalSeal(parent, size, textSize)
	local seal = CreateFrame("Frame", nil, parent) --[[@as LedgerSeal]]
	seal:SetSize(size, size)
	seal.size = size
	seal.wax = ns.JournalPiece(seal, "Book", "seal", "ARTWORK", 0)
	seal.wax:SetAllPoints()
	seal.empty = ns.JournalPiece(seal, "Book", "seal-empty", "ARTWORK", 0)
	seal.empty:SetAllPoints()
	seal.label = ns.JournalLabel(seal, "gilt", textSize or 12, INK.wax, "", { justify = "CENTER" })
	seal.label:SetPoint("CENTER", 0, 1)
	seal.label:SetWidth(size - 10)
	local tilt = math.rad(-8)
	seal.wax:SetRotation(tilt)
	seal.empty:SetRotation(tilt)
	if seal.label.SetRotation then
		seal.label:SetRotation(math.rad(8))
	end
	return seal
end

--- Sets a seal's words and whether it is pressed (the wax) or not yet (the empty ring, its words in ghost ink).
---@param seal LedgerSeal
---@param text string
---@param earned boolean
function ns.JournalSetSeal(seal, text, earned)
	seal.wax:SetShown(earned)
	seal.empty:SetShown(not earned)
	seal.label:SetTextColor(rgb(earned and INK.wax or "9a8060"))
	seal.label:SetText(text)
end

--- A page button on the leather's ink (LED-R146's Prestige, "Open the plate", "Help chart the waters"): its words in
--- gilt, a lighter face on hover, the click sound, calling `action`. `look` "light" is the parchment button.
---@class LedgerButton: Button
---@field label FontString
---@field face LedgerThreeSlice
---@field hover LedgerThreeSlice
---@field action fun()?

---@param parent Frame
---@param look "light"?
---@return LedgerButton
function ns.JournalButton(parent, look)
	local button = CreateFrame("Button", nil, parent) --[[@as LedgerButton]]
	local light = look == "light"
	button.label = ns.JournalLabel(button, "gilt", 15, light and INK.body or INK.wax, "", {
		shadow = not light,
		justify = "CENTER",
	})
	button.label:SetPoint("CENTER")
	button.face = ns.JournalThreeSlice(button, "Parts", light and "button-light" or "button", 160, 10, "BACKGROUND")
	button.face:SetPoint("TOPLEFT")
	button.hover =
		ns.JournalThreeSlice(button, "Parts", light and "button-light" or "button-hover", 160, 10, "BACKGROUND")
	button.hover:SetPoint("TOPLEFT")
	button.hover:Hide()
	button:SetScript("OnEnter", function(self)
		self.hover:Show()
		self.face:Hide()
	end)
	button:SetScript("OnLeave", function(self)
		self.hover:Hide()
		self.face:Show()
	end)
	button:SetScript("OnClick", function(self)
		ns.JournalSound("click")
		if self.action then
			self.action()
		end
	end)
	return button
end

--- Sets a page button's words and width (to its words with room either side when `width` is nil).
---@param button LedgerButton
---@param text string
---@param width number?
function ns.JournalSetButton(button, text, width)
	button.label:SetText(text)
	width = width or math.ceil(button.label:GetStringWidth()) + 36
	button:SetSize(width, 34)
	ns.JournalSliceWidth(button.face, width)
	ns.JournalSliceWidth(button.hover, width)
end

-- ---------------------------------------------------------------- motion and sound

--- Whether things move: Core's Animations setting (`Pagle.IsAnimationsOn()`, on by default). It sets the motion
--- driver's switch (adapter/Motion.lua) as it reads it, so every animation started after it plays or settles at once.
---@return boolean
function ns.Moving()
	ns.motion = Pagle.IsAnimationsOn() ~= false
	return ns.motion
end

-- The Journal's sounds (the kit's SOUND.md): the client's own sound kits by numeric id, on the SFX channel, so the
-- client's SFX volume and mute are their only switch. UI foley, never part of a sound set (core.soundset.*).
local SOUNDS = {
	bookOpen = 829, -- IG_SPELLBOOK_OPEN
	bookClose = 830, -- IG_SPELLBOOK_CLOSE
	pageTurn = 836, -- IG_ABILITY_PAGE_TURN: the page turn
	pick = 836, -- the same kit: a fish picked, the right page crossfading
	plateOpen = 836, -- the same kit: a Legend's plate opening
	rebind = 836, -- the same kit: a binding change
	write = 3093, -- IG_WRITE_QUEST
	stamp = 1204, -- PUT_DOWN_GEMS
	popupOpen = 850, -- IG_MAINMENU_OPEN
	popupClose = 851, -- IG_MAINMENU_CLOSE
	click = 852, -- IG_MAINMENU_OPTION
	banner = 33338, -- UI_CHALLENGES_NEW_RECORD
}
-- The beats tied to a motion (a page turning, a name written in, a stamp landing, the Prestige's banner): they play
-- only while things move. Opening, closing, clicks, a fish picked, the plate opening and a binding change always sound
-- (ledger.md › UI › Sounds), though the last three share the page turn's kit.
local TIED = { pageTurn = true, write = true, stamp = true, banner = true }

--- The sound kit id of each of the Journal's sounds, for a spec to read.
ns.JOURNAL_SOUNDS = SOUNDS

--- Plays the Journal's sound `event` on the SFX channel; a beat tied to a motion only while things move.
---@param event string
function ns.JournalSound(event)
	local id = SOUNDS[event]
	if not id or (TIED[event] and not ns.Moving()) then
		return
	end
	PlaySound(id, "SFX")
end

-- ---------------------------------------------------------------- fit to the screen

-- The room kept free round the book at the screen's edges.
local FIT_MARGIN = 24

--- Shrinks `frame` to fit the screen, never growing it (the kit's Fit.lua): `w` and `h` its whole extent in its own
--- units, what hangs outside its frame included (the wax close, the brass plate). Centred. Returns the scale used.
---@param frame Frame
---@param w number
---@param h number
---@return number
function ns.FitJournal(frame, w, h)
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	local scale = 1
	if screenW and screenH and screenW > 0 and screenH > 0 then
		scale = math.min(1, (screenH - 2 * FIT_MARGIN) / h, (screenW - 2 * FIT_MARGIN) / w)
	end
	frame:SetScale(scale)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return scale
end
