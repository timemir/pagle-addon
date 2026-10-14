---@class PagleNS
local ns = select(2, ...)

-- The toast styles (announcements.md › Toast styles, ANN-R80; wallet-and-shop.md › SHOP-R25): the looks the toast,
-- Nod, banner, splash and card frames are drawn in, as data keyed by Core's toast style good IDs. Timber is the free
-- default and M2's look; Ripple and Lantern Glow are Curio Shop goods, after prototypes/curio-shop/ (variant B)'s
-- .ts-ripple and .ts-lantern. A style changes only the look, never timing, lanes, the Interruption budget, sounds or
-- which moments show. adapter/Timber.lua paints the frames in one, and adapter/ToastStyles.lua follows the pick.

--- Core's toast style slot (SHOP-R25), registered with its goods by Core's own goods.
ns.TOAST_STYLE_SLOT = "core.toaststyle"
--- Timber's good ID: the slot's default, and the style for any ID that isn't one.
ns.TOAST_STYLE_DEFAULT = "core.toaststyle.timber"

--- A texture over a frame's background, tinted.
---@class PagleStyleBackdrop
---@field file string
---@field tint number[] { r, g, b, a }

--- Rings drawn around an Announcement's icon, under it, each `scale` times the icon's size, cropped to the frame.
---@class PagleStyleGlow
---@field file string
---@field blend BlendMode
---@field tint number[] { r, g, b }
---@field rings { scale: number, alpha: number }[]

--- A font file for the frames' titles, at a size for each font object a title is otherwise drawn in.
---@class PagleStyleFace
---@field file string
---@field sizes table<string, number>

--- A toast style: every colour role the frames paint, each { r, g, b[, a] }, and its textures and title face, if any.
---@class PagleToastStyle
---@field id string
---@field colors table<string, number[]>
---@field backdrop? PagleStyleBackdrop
---@field glow? PagleStyleGlow
---@field titleFace? PagleStyleFace

---@type table<string, PagleToastStyle>
ns.TOAST_STYLES = {
	-- M2's look (#84, #87, #88): dark planks with a worn brass edge, gold headings, and stamps coloured like
	-- prototypes/catch-feedback/ (variant A)'s. The text roles are the colours of the font objects the frames use.
	[ns.TOAST_STYLE_DEFAULT] = {
		id = ns.TOAST_STYLE_DEFAULT,
		colors = {
			wood = { 0.16, 0.11, 0.07, 0.94 },
			edge = { 0.54, 0.42, 0.25, 1 },
			band = { 0, 0, 0, 0.6 }, -- the banner's band
			titleBand = { 0.18, 0.15, 0.12, 1 }, -- a card's title band
			well = { 0, 0, 0, 0.42 }, -- a card's numbers
			title = { 1, 0.82, 0 }, -- GameFontNormal's gold: titles and a card's headings
			text = { 1, 1, 1 }, -- GameFontHighlight's white
			label = { 0.5, 0.5, 0.5 }, -- GameFontDisable's grey: the ruler's label
			gold = { 1, 0.82, 0 }, -- the ruler's margin
			dim = { 0.66, 0.62, 0.55 },
			more = { 0.62, 0.82, 1 },
			stamp = { 0.70, 0.13, 0.10, 1 },
			stampText = { 1, 1, 1 },
			stampsMore = { 0.33, 0.33, 0.33, 1 },
			coins = { 0.63, 0.47, 0, 1 },
			record = { 0.82, 0.46, 0.10, 1 },
			track = { 0.10, 0.08, 0.05, 1 },
			fill = { 1, 0.75, 0.30, 1 },
			mark = { 0.81, 0.78, 0.70, 1 },
			passed = { 1, 0.35, 0.23, 1 },
			shade = { 0, 0, 0, 0.8 },
			parchment = { 0.93, 0.87, 0.72, 1 }, -- the splash's card
			parchmentEdge = { 0.54, 0.35, 0.10, 1 },
			ink = { 0.23, 0.15, 0.06 }, -- the splash's text
			legend = { 0.63, 0.29, 0 }, -- the splash's title
		},
	},
	-- Cool water, with rings spreading from the icon: .ts-ripple's #123544 to #06141c, its #5fb6d6 edge and its
	-- rgba(140, 220, 255) rings at .25, .18 and .12.
	["core.toaststyle.ripple"] = {
		id = "core.toaststyle.ripple",
		colors = {
			wood = { 0.05, 0.16, 0.21, 0.94 },
			edge = { 0.37, 0.71, 0.84, 1 },
			band = { 0.02, 0.08, 0.11, 0.7 },
			titleBand = { 0.07, 0.21, 0.27, 1 },
			well = { 0, 0.04, 0.07, 0.45 },
			title = { 0.75, 0.92, 1 },
			text = { 0.92, 0.97, 1 },
			label = { 0.48, 0.62, 0.68 },
			gold = { 0.55, 0.86, 1 },
			dim = { 0.6, 0.72, 0.78 },
			more = { 0.62, 0.86, 1 },
			stamp = { 0.10, 0.43, 0.58, 1 },
			stampText = { 1, 1, 1 },
			stampsMore = { 0.2, 0.3, 0.35, 1 },
			coins = { 0.70, 0.55, 0.10, 1 },
			record = { 0.16, 0.58, 0.72, 1 },
			track = { 0.02, 0.09, 0.12, 1 },
			fill = { 0.55, 0.86, 1, 1 },
			mark = { 0.82, 0.9, 0.93, 1 },
			passed = { 1, 0.55, 0.4, 1 },
			shade = { 0, 0.03, 0.06, 0.8 },
			parchment = { 0.06, 0.19, 0.25, 1 },
			parchmentEdge = { 0.37, 0.71, 0.84, 1 },
			ink = { 0.85, 0.95, 1 },
			legend = { 0.55, 0.86, 1 },
		},
		-- Marble's mottle, tinted blue, as light on water.
		backdrop = { file = "Interface\\FrameGeneral\\UI-Background-Marble", tint = { 0.35, 0.75, 0.95, 0.16 } },
		glow = {
			file = "Interface\\Cooldown\\ping4",
			blend = "ADD",
			tint = { 0.55, 0.86, 1 },
			rings = { { scale = 1.5, alpha = 0.25 }, { scale = 2.6, alpha = 0.18 }, { scale = 4.2, alpha = 0.12 } },
		},
	},
	-- A warm lantern light behind the catch: .ts-lantern's #2a1608 to #0c0602, its #d8782a edge and its
	-- rgba(255, 170, 60, .45) glow fading out from the icon, with titles in the client's Morpheus face.
	["core.toaststyle.lanternglow"] = {
		id = "core.toaststyle.lanternglow",
		colors = {
			wood = { 0.11, 0.06, 0.02, 0.95 },
			edge = { 0.85, 0.47, 0.16, 1 },
			band = { 0.08, 0.04, 0.01, 0.7 },
			titleBand = { 0.2, 0.1, 0.03, 1 },
			well = { 0, 0, 0, 0.45 },
			title = { 1, 0.78, 0.42 },
			text = { 1, 0.93, 0.82 },
			label = { 0.62, 0.5, 0.38 },
			gold = { 1, 0.67, 0.24 },
			dim = { 0.78, 0.66, 0.52 },
			more = { 1, 0.75, 0.45 },
			stamp = { 0.72, 0.25, 0.06, 1 },
			stampText = { 1, 0.95, 0.85 },
			stampsMore = { 0.35, 0.25, 0.18, 1 },
			coins = { 0.75, 0.55, 0.05, 1 },
			record = { 0.9, 0.45, 0.1, 1 },
			track = { 0.12, 0.06, 0.02, 1 },
			fill = { 1, 0.67, 0.24, 1 },
			mark = { 0.9, 0.82, 0.7, 1 },
			passed = { 1, 0.35, 0.23, 1 },
			shade = { 0.04, 0.02, 0, 0.8 },
			parchment = { 0.16, 0.08, 0.03, 1 },
			parchmentEdge = { 0.85, 0.47, 0.16, 1 },
			ink = { 1, 0.9, 0.75 },
			legend = { 1, 0.72, 0.3 },
		},
		-- Discs of light, smallest brightest, adding up to a glow that fades out from the icon.
		glow = {
			file = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
			blend = "ADD",
			tint = { 1, 0.6, 0.2 },
			rings = { { scale = 1.6, alpha = 0.16 }, { scale = 2.8, alpha = 0.11 }, { scale = 4.5, alpha = 0.08 } },
		},
		titleFace = {
			file = "Fonts\\MORPHEUS.TTF",
			sizes = { GameFontNormal = 15, GameFontNormalLarge = 19, GameFontNormalHuge = 26 },
		},
	},
}

--- The style a toast style good ID draws in: its own, or Timber for any other ID, or none (ANN-R80): before Core's
--- slot is registered, GetEquipped has no good for it.
---@param goodID any
---@return PagleToastStyle
function ns.ToastStyleOf(goodID)
	return ns.TOAST_STYLES[goodID] or ns.TOAST_STYLES[ns.TOAST_STYLE_DEFAULT]
end

--- Where a square of `size` centred at (`cx`, `cy`) from a frame's top left shows inside a `width` by `height` frame:
--- the part inside as an offset and a size, with the texture coordinates of that part. Nil when none of it is inside.
---@param cx number
---@param cy number
---@param size number
---@param width number
---@param height number
---@return { x: number, y: number, width: number, height: number, left: number, right: number, top: number, bottom: number }?
function ns.CroppedSquare(cx, cy, size, width, height)
	local x0, y0 = cx - size / 2, cy - size / 2
	local left, right = math.max(0, x0), math.min(width, x0 + size)
	local top, bottom = math.max(0, y0), math.min(height, y0 + size)
	if right <= left or bottom <= top then
		return nil
	end
	return {
		x = left,
		y = top,
		width = right - left,
		height = bottom - top,
		left = (left - x0) / size,
		right = (right - x0) / size,
		top = (top - y0) / size,
		bottom = (bottom - y0) / size,
	}
end

--- A sample toast in a style (wallet-and-shop.md › UI, the preview stage): an Announcement raised by no Module and on
--- no Cast, a headline with one stamp and 5 Coins, carrying `style` so it is drawn in that style, whatever is equipped.
---@param styleID string
---@return PagleAnnouncement
function ns.SampleAnnouncement(styleID)
	local L = ns.L
	local function sample(fields)
		local moment = { module = "Core", moduleTitle = "Pagle", moduleOrder = 0, raised = 0, kind = "sample" }
		for key, value in pairs(fields) do
			moment[key] = value
		end
		return moment
	end
	local announcement = ns.MakeAnnouncement({
		sample({ rung = "toast", title = L.TOAST_SAMPLE_TITLE, text = L.TOAST_SAMPLE_TEXT, icon = 136245 }),
		sample({ rung = "nod", title = L.TOAST_SAMPLE_STAMP, coins = 5 }),
	}) --[[@as PagleAnnouncement]]
	announcement.style = styleID
	return announcement
end
