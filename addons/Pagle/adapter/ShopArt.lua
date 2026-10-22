---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Curio Shop art kit on the client (wallet-and-shop.md › UI): its inks, its fonts as font objects, and the pieces
-- the case is drawn from: the medallion round a good's icon, the brass coin, the pills and chips, and the leather
-- buttons. Sprites come from the atlases in data/ShopArt.lua, through ns.SetSprite and ns.SetThreeSlice. Every size is
-- the canvas's CSS pixel, a UI unit.

-- An ink from its hex, as { r, g, b } (logic/ToastStyles.lua's).
local rgb = ns.Rgb

--- The shop's inks, by role, from the canvas's shop.css.
---@type table<string, number[]>
ns.SHOP_INKS = {
	gilt = rgb("F0CD6A"), -- the balance, the leather buttons' words
	giltLight = rgb("FFE7A6"), -- the chip that's on
	cream = rgb("EFE0BB"), -- the legend
	creamText = rgb("E6D8B8"), -- the stage's hint, the tooltip's lines
	name = rgb("F3E6C4"), -- a good's name on the velvet, a tooltip's numbers
	lab = rgb("CDB98E"), -- "PAGLE COINS"
	muted = rgb("BCAE8C"), -- a slot's owned count
	pill = rgb("CFC0A0"), -- a filter that's off, "Owned"
	pillOn = rgb("2A1806"), -- the filter that's on
	chip = rgb("C9B27A"), -- a chip that's off
	inuse = rgb("FFD894"), -- "IN USE"
	held = rgb("E8C96A"), -- the held line
	off = rgb("8A7C62"), -- a Module off's legend, the search's hint
	ink = rgb("1E1408"), -- the handwriting on paper and tags
	ink2 = rgb("2E1C0C"), -- the bill's lines, the stage's tags
	red = rgb("7A2A1A"), -- printed red: the slot line, the bill's head
	stamp = rgb("B4281A"), -- a price the balance doesn't cover, "N more Coins"
	desc = rgb("4A3018"), -- a good's description
	note = rgb("5A4028"), -- notes on paper
	cancel = rgb("5A3A1C"), -- Cancel on the bill
	strike = rgb("C7503A"), -- the red line through a Module off's legend
}

local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
-- The faces (media/fonts/OFL-*.txt): IM Fell English and its italic for print, Caveat for the Angler's handwriting,
-- Marcellus for gilt and labels.
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

--- One of the shop's fonts: its face, size and ink (a role in ns.SHOP_INKS), whether it has a shadow (what is on the
--- leather and velvet does; what is on paper doesn't), and whether its words are set in capitals (the client has no
--- small caps).
---@class PagleShopFontDef
---@field [1] string face
---@field [2] number size
---@field [3] string ink
---@field shadow? true
---@field caps? true

---@type table<string, PagleShopFontDef>
local FONTS = {
	-- the purse, on the leather
	PurseLab = { "print", 13, "lab", shadow = true, caps = true },
	Balance = { "gilt", 40, "gilt", shadow = true },
	Legend = { "handSemi", 20, "cream", shadow = true },
	LegendOff = { "handSemi", 20, "off", shadow = true },
	Held = { "italic", 14, "held", shadow = true },
	-- the tray, on velvet
	Find = { "handSemi", 22, "ink" },
	FindHint = { "handSemi", 22, "off" },
	Pill = { "print", 13.5, "pill" },
	PillOn = { "print", 13.5, "pillOn" },
	Chip = { "gilt", 12.5, "chip", shadow = true, caps = true },
	ChipOn = { "gilt", 12.5, "giltLight", shadow = true, caps = true },
	Slot = { "print", 15, "gilt", shadow = true, caps = true },
	SlotCount = { "hand", 18, "muted", shadow = true },
	Good = { "gilt", 17, "name", shadow = true },
	InUse = { "print", 13, "inuse", shadow = true, caps = true },
	Owned = { "hand", 20, "pill", shadow = true },
	Price = { "handBold", 20, "ink" },
	PriceShort = { "handBold", 20, "stamp" },
	Empty = { "italic", 15, "creamText", shadow = true },
	-- the lid's cards, on paper
	Stage = { "handSemi", 20, "creamText", shadow = true },
	GoodName = { "handBold", 38, "ink" },
	Meta = { "print", 13, "red", caps = true },
	Desc = { "italic", 15.5, "desc" },
	Notes = { "italic", 14, "note" },
	Tags = { "print", 14, "ink2", caps = true },
	Need = { "handSemi", 20, "stamp" },
	Button = { "gilt", 17, "gilt", shadow = true },
	-- the bill of sale
	SlipHead = { "print", 15, "red", caps = true },
	SlipQ = { "handBold", 40, "ink" },
	SlipLine = { "print", 16, "ink2" },
	SlipNum = { "handBold", 26, "ink" },
	SlipFine = { "italic", 15, "note" },
	Check = { "handSemi", 22, "ink" },
	Cancel = { "print", 16, "cancel", caps = true },
	-- the income tooltip
	TipHead = { "gilt", 15, "gilt" },
	Tip = { "print", 14, "creamText" },
	-- the "?" beside the close button (ONB-R59)
	Help = { "gilt", 20, "gilt", shadow = true },
}

--- The shop's font object names, by key: PagleShop<key>.
---@type table<string, string>
ns.SHOP_FONTS = {}
for key, def in pairs(FONTS) do
	local name = "PagleShop" .. key
	local font = CreateFont(name)
	if font:SetFont(FONT_DIR .. FACES[def[1]], def[2], "") == false then
		font:SetFont(FALLBACK, def[2], "")
	end
	local ink = ns.SHOP_INKS[def[3]]
	font:SetTextColor(ink[1], ink[2], ink[3])
	if def.shadow then
		font:SetShadowColor(0, 0, 0, 0.95)
		font:SetShadowOffset(0, -1)
	else
		font:SetShadowOffset(0, 0)
	end
	ns.SHOP_FONTS[key] = name
end

--- A font string in one of the shop's fonts: `shopFont` is its key.
---@class PagleShopFontString: FontString
---@field shopFont string

--- Puts a font string in the shop's font `key`, in that font's ink.
---@param fontString FontString
---@param key string
---@return PagleShopFontString
function ns.SetShopFont(fontString, key)
	local shown = fontString --[[@as PagleShopFontString]]
	shown:SetFontObject(ns.SHOP_FONTS[key])
	local ink = ns.SHOP_INKS[FONTS[key][3]]
	shown:SetTextColor(ink[1], ink[2], ink[3])
	shown.shopFont = key
	return shown
end

--- Sets a shop font string's text, in capitals for a font set in them.
---@param fontString PagleShopFontString
---@param text string?
function ns.SetShopText(fontString, text)
	if text and FONTS[fontString.shopFont].caps then
		text = text:upper()
	end
	fontString:SetText(text or "")
end

--- A one-line font string on `frame` in the shop's font `key`.
---@param frame Frame
---@param key string
---@param layer DrawLayer?
---@return PagleShopFontString
function ns.ShopText(frame, key, layer)
	local fontString = ns.SetShopFont(frame:CreateFontString(nil, layer or "OVERLAY"), key)
	fontString:SetWordWrap(false)
	fontString:SetJustifyH("LEFT")
	return fontString
end

--- Shows the brass coin with the stamped fish in `texture`, `size` across: the large coin from 30 up, the small one
--- under it.
---@param texture Texture
---@param size number
---@return PagleSprite
function ns.SetShopCoin(texture, size)
	local large = size > 30
	return ns.SetArtCoin(texture, "Shop", large and "coin" or "coin-small", large and 52 or 20, size)
end

--- A medallion: the brass ring with a good's icon round inside it and the gloss over it.
---@class PagleShopBezel: Frame
---@field Ring PagleSprite
---@field Icon Texture
---@field Gloss PagleSprite
---@field Shield Texture? a crest's shield, in place of the rest (made at its first)
---@field shield boolean whether it shows a crest's shield

-- The icon's width inside each medallion size.
local INNER = { [64] = 46, [34] = 26 }

--- A medallion on `parent`, 34 or 64 across, set with ns.SetShopBezel.
---@param parent Frame
---@param size integer
---@return PagleShopBezel
function ns.NewShopBezel(parent, size)
	local bezel = ns.NewArtBezel(parent, "Shop", "bezel-" .. size, "gloss-" .. size) --[[@as PagleShopBezel]]
	bezel:SetSize(size, size)
	ns.CenterSprite(bezel.Ring, bezel)
	bezel.Icon:SetSize(INNER[size] - 2, INNER[size] - 2)
	ns.CenterSprite(bezel.Gloss, bezel)
	return bezel
end

-- The icon a good with none shows.
local NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

--- Crops a crest's texture to its shield (SHOP-R25): the shield, 120:140, fills the square texture's height.
---@param texture Texture
function ns.CropShield(texture)
	texture:SetTexCoord(0.5 - 60 / 140, 0.5 + 60 / 140, 0, 1)
end

--- Sets a medallion's icon, greyed for a good put away. A crest's (`shield`, SHOP-R25) is its shield instead, square
--- with no ring, gloss or mask: 30 x 35 in a row's medallion, and as tall in proportion in a larger one.
---@param bezel PagleShopBezel
---@param icon integer|string|nil
---@param greyed boolean?
---@param shield boolean?
function ns.SetShopBezel(bezel, icon, greyed, shield)
	shield = shield == true
	bezel.shield = shield
	bezel.Ring:SetShown(not shield)
	bezel.Gloss:SetShown(not shield)
	bezel.Icon:SetShown(not shield)
	if shield and not bezel.Shield then
		bezel.Shield = bezel:CreateTexture(nil, "ARTWORK", nil, 1)
		local h = bezel:GetHeight() * 35 / 34
		bezel.Shield:SetSize(h * 120 / 140, h)
		bezel.Shield:SetPoint("CENTER")
		ns.CropShield(bezel.Shield)
	end
	if bezel.Shield then
		bezel.Shield:SetShown(shield)
	end
	local texture = shield and bezel.Shield or bezel.Icon
	texture:SetTexture(icon or NO_ICON)
	texture:SetDesaturated(greyed == true)
end

--- A pill, a chip or a leather button: a three-sliced sprite with its words on it.
---@class PagleShopPill: Button, PagleThreeSlice
---@field label PagleShopFontString
---@field coin PagleSprite? a leather button's coin after its words
---@field pressed boolean? a filter's or chip's: it is the one on

--- A pill on `parent` that runs `onClick`, drawn by ns.SetShopPill.
---@param parent Frame
---@param onClick fun()?
---@return PagleShopPill
function ns.NewShopPill(parent, onClick)
	local pill = CreateFrame("Button", nil, parent) --[[@as PagleShopPill]]
	pill.label = ns.ShopText(pill, "Pill")
	pill.label:SetPoint("CENTER")
	if onClick then
		pill:SetScript("OnClick", onClick)
	end
	return pill
end

--- Draws a pill: sprite `sprite` three-sliced on it (`cap` units kept at each end, as high as the sprite's drawn
--- element) round `text` in font `fontKey`, with `pad` units each side of it; returns its width.
---@param pill PagleShopPill
---@param sprite string
---@param fontKey string
---@param text string
---@param pad number
---@param cap number
---@return number
function ns.SetShopPill(pill, sprite, fontKey, text, pad, cap)
	ns.SetShopFont(pill.label, fontKey)
	ns.SetShopText(pill.label, text)
	local width = math.floor(pill.label:GetStringWidth() + pad * 2 + 0.5)
	ns.SetThreeSlice(pill, "Shop", sprite, width, cap, "ARTWORK")
	return width
end

-- A leather button's padding each side of its words, and the room its coin takes after them.
local BUTTON_PAD, BUTTON_COIN = 34, 28

--- A leather button on `parent` that runs `onClick`, drawn by ns.SetShopButton.
---@param parent Frame
---@param onClick fun()
---@return PagleShopPill
function ns.NewShopButton(parent, onClick)
	local button = ns.NewShopPill(parent, onClick)
	ns.SetShopFont(button.label, "Button")
	button.label:ClearAllPoints()
	button.label:SetPoint("LEFT", BUTTON_PAD, 0)
	button.coin = ns.ArtSprite(button, "Shop", "coin-small", "OVERLAY")
	return button
end

--- Draws a leather button reading `text`, with the coin after it when `withCoin`; dimmed while disabled.
---@param button PagleShopPill
---@param text string
---@param withCoin boolean
---@param enabled boolean
function ns.SetShopButton(button, text, withCoin, enabled)
	ns.SetShopText(button.label, text)
	local width = button.label:GetStringWidth() + BUTTON_PAD * 2 + (withCoin and BUTTON_COIN or 0)
	ns.SetThreeSlice(button, "Shop", "button", width, 12, "ARTWORK")
	local coin = ns.SetShopCoin(button.coin, 20)
	coin:ClearAllPoints()
	coin:SetPoint("LEFT", button.label, "RIGHT", 8 - coin.box[1], 0)
	coin:SetShown(withCoin)
	button:SetEnabled(enabled)
	button:SetAlpha(enabled and 1 or 0.6)
end
