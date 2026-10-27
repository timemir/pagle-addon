---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Curio crate's opening, drawn (wallet-and-shop.md › UI: Motion and sound, "A crate opens"; SHOP-R55): the frames and
-- textures of the crate, its plaque and odds, the reel with its 60 pooled cards, the reveal's card, rays, words and
-- buttons, and the particles, all over the case's inside (its velvet tray and lid), from the crate kit in
-- data/CrateArt.lua. adapter/ShopCrateMotion.lua plays it, and logic/CrateReel.lua says when and how; this file only
-- builds it and sets each piece where the motion has it. Positions are the prototype's (prototypes/curio-crate/), in UI
-- units from the inside's top left, y growing downward; the prototype's px are 0.8 units.
local L = ns.L

-- The case's inside: the velvet tray and the lid, from the tray's left to the lid's right (22 from the case's edge
-- each side) and from their top to their foot. Its corners are about 6 units round.
local INSIDE_X, INSIDE_Y, INSIDE_W, INSIDE_H = 22, 98, 936, 520
local CORNER = 6
-- Its middle across, the crate (256 x 214, its top 74 units in) and the light behind it.
local CX = INSIDE_W / 2
local CRATE_X, CRATE_Y, CRATE_H = CX - 128, 73.6, 214
local LIGHT_Y = 150.4
-- The plaque's top, and the odds along the foot.
local PLAQUE_Y, ODDS_FOOT = 20.8, 27.2
-- The reel's frame (848 x 169.6), its window inset, and its cards: their top in the window.
local REEL_W, REEL_H = 848, 169.6
local REEL_X, REEL_Y = CX - REEL_W / 2, 172.8
local WINDOW_INSET = 11.2
local WINDOW_W, WINDOW_H = REEL_W - 2 * WINDOW_INSET, REEL_H - 2 * WINDOW_INSET
local CARD_TOP = 4.8
local CARD_W, CARD_H = 120, 137.78
-- The reveal: where the card lifts to, and its words (tier, good, kind, the note) and buttons.
local HERO_X, HERO_Y = CX, 168
local TIER_Y, NAME_Y, KIND_Y, NOTE_Y, BUTTONS_Y = 290, 305.6, 357, 374, 396
-- A good's medallion on its card (the shop's, this much larger so the card is full), and a crest's shield.
local MEDAL = 1.5
local SHIELD_H = 100
-- How many particles each swarm holds.
local SWARM = { straw = 34, dust = 4, spark = 80, ember = 56, coin = 46 }

---@class PagleCratePart
---@field tex PagleSprite
---@field def PagleAtlasSprite
---@field x number          where the sprite's top left lies at rest, from its anchor's top left
---@field y number
---@field w number
---@field h number
---@field alpha number      the opacity it is drawn at when it shows whole
---@field fade number       how much of that it shows
---@field group boolean?    the crate's group pose carries it
---@field origin { x: number, y: number }? what its own pose turns and grows about (its middle by default)
---@field own number[]      its own pose: { x, y, degrees clockwise, sx, sy }
---@field anchor Frame?     what it is placed from (the stage's box by default), `ax`, `ay` being that anchor's place there
---@field ax number?
---@field ay number?

--- The crate stage's pose of the crate as a whole: where it sits, how far it is turned and squashed, about its foot.
---@class PagleCrateGroup
---@field tx number
---@field ty number
---@field deg number
---@field sx number
---@field sy number
---@field ox number
---@field oy number

--- One particle of a swarm: its texture, and its path from `start` for `dur` seconds, a few keys in, each at an offset of
--- the (eased) progress with a position, scale, opacity, turn and width.
---@class PagleCrateParticle
---@field tex Texture
---@field live boolean
---@field start number
---@field dur number
---@field ease PagleEase
---@field n integer
---@field o number[]
---@field x number[]
---@field y number[]
---@field s number[]
---@field a number[]
---@field r number[]
---@field f number[]       its width, as a flipping coin's

---@class PagleCrateSwarm
---@field frame Frame
---@field sprite string
---@field def PagleAtlasSprite
---@field layer DrawLayer
---@field parts PagleCrateParticle[]

--- A card layer: a sprite at its place on the card.
---@class PagleCrateCardLayer
---@field tex PagleSprite|Texture
---@field x number
---@field y number
---@field w number
---@field h number
---@field alpha number

---@class PagleCrateCard: Frame
---@field layers PagleCrateCardLayer[]
---@field shadow PagleCrateCardLayer
---@field glow PagleCrateCardLayer
---@field base PagleCrateCardLayer
---@field coin PagleCrateCardLayer
---@field curio PagleCrateCardLayer
---@field tint PagleCrateCardLayer
---@field hatch PagleCrateCardLayer
---@field emblem PagleCrateCardLayer
---@field emblemHi PagleCrateCardLayer
---@field glyph PagleCrateCardLayer
---@field sheen PagleCrateCardLayer
---@field ring PagleCrateCardLayer?
---@field icon PagleCrateCardLayer?
---@field shield PagleCrateCardLayer?
---@field gloss PagleCrateCardLayer?
---@field label PagleShopFontString
---@field coins PagleShopFontString?
---@field colour number[]?  the crate tier's colour it is drawn in
---@field ringing boolean?  its glow rings it (the card the line stopped on)

---@class PagleCrateReel
---@field clip Frame                the reel's wipe: it opens sideways out of the light
---@field root Frame
---@field window Frame
---@field track Frame
---@field cards PagleCrateCard[]
---@field light PagleCratePart
---@field glow PagleCratePart
---@field line PagleCratePart
---@field bobber PagleCratePart
---@field hook PagleCratePart

---@class PagleCrateStage
---@field root Frame                the inside: clips what it holds, takes the clicks the case would
---@field box Frame                 everything but the dim: the case shakes it
---@field dim Texture[]
---@field fans PagleCratePart[]     the crate's rays, then the reveal's two
---@field beam PagleCratePart
---@field burst PagleCratePart
---@field halo PagleCratePart
---@field parts PagleCratePart[]    the crate's, in drawing order
---@field crate table<string, PagleCratePart> body, lid, glow, ribbon, sealLeft, sealRight
---@field group PagleCrateGroup
---@field groupAlpha number         how much of the crate shows
---@field plaque Frame
---@field odds PagleShopFontString[]
---@field pips Texture[]
---@field reel PagleCrateReel
---@field swarmFrame Frame
---@field swarms table<string, PagleCrateSwarm>
---@field embers { nextAt: number, endAt: number }? embers still rising
---@field hero Frame                the card in the reveal, scaled about its middle
---@field pivot Frame               where it is, as a point
---@field back PagleCrateCard       what it shows before it turns over
---@field front PagleCrateCard      what it turns over to
---@field stamp Frame
---@field stampPivot Frame
---@field stampWord PagleShopFontString
---@field tier PagleShopFontString
---@field tierRules Texture[]
---@field name PagleShopFontString
---@field kind PagleShopFontString
---@field note PagleShopFontString
---@field useButton PagleShopPill
---@field backButton PagleShopPill
---@field flash Texture
---@field onUse fun()?
---@field onBack fun()?
---@field phase "crate"|"reel"|"landed"|"reveal"
---@field onPhase fun(phase: string)? told when the opening moves on
---@field cards PagleCrateCard[]? the reel's cards, as drawn
---@field data PagleShopCrateResult?
---@field offset number             where the line stops, off the result card's middle
---@field rayTurn number[]          the three fans' turn in degrees: the crate's, then the reveal's two
---@field whip number               the reveal's fans' extra turn, degrees
---@field rayColour number[]
---@field tremble number[]          the card's tremble: x, y
---@field heroAt number[]            where the card is: x, y
---@field swarmNow number           the particles' clock

local sprites = ns.ATLASES.Crate.sprites

-- A colour as { r, g, b }, 0 to 1, of a sprite's own tint (0 to 255).
---@param tint number[]
---@return number[]
local function unit(tint)
	return { tint[1] / 255, tint[2] / 255, tint[3] / 255 }
end

--- A sprite of the crate kit on `parent`, its top left where its `at` puts it from the anchor at `x`, `y`.
---@param parent Frame
---@param name string
---@param x number the anchor's
---@param y number
---@param layer DrawLayer
---@param sublevel integer?
---@return PagleCratePart
local function newPart(parent, name, x, y, layer, sublevel)
	local def = sprites[name]
	local tex = ns.ArtSprite(parent, "Crate", name, layer, sublevel)
	tex:SetSize(def.size[1], def.size[2])
	if def.use:find("add", 1, true) then
		tex:SetBlendMode("ADD")
	end
	if def.tint then
		local c = unit(def.tint)
		tex:SetVertexColor(c[1], c[2], c[3])
	end
	return {
		tex = tex,
		def = def,
		x = x + def.at[1],
		y = y + def.at[2],
		w = def.size[1],
		h = def.size[2],
		alpha = def.alpha or 1,
		fade = 1,
		own = { 0, 0, 0, 1, 1 },
	}
end

-- Where the group pose has a point: squashed, turned about the group's foot, then moved.
---@param g PagleCrateGroup
---@param x number
---@param y number
---@return number
---@return number
local function grouped(g, x, y)
	local r = math.rad(g.deg)
	local c, s = math.cos(r), math.sin(r)
	local dx, dy = (x - g.ox) * g.sx, (y - g.oy) * g.sy
	return g.ox + g.tx + c * dx - s * dy, g.oy + g.ty + s * dx + c * dy
end

--- Puts `part` where its pose has it: its own (about its origin, its middle by default), then the group's if it has one.
---@param stage PagleCrateStage
---@param part PagleCratePart
function ns.PoseCratePart(stage, part)
	local origin = part.origin or { x = part.x + part.w / 2, y = part.y + part.h / 2 }
	local placed = ns.TransformLayerBox(part --[[@as PagleArtBox]], origin, part.own, 1)
	local cx, cy, w, h, rotation = placed.cx, placed.cy, placed.w, placed.h, placed.rotation
	if part.group then
		local g = stage.group
		cx, cy = grouped(g, cx, cy)
		w, h = w * g.sx, h * g.sy
		rotation = rotation - math.rad(g.deg)
	end
	local tex = part.tex
	tex:SetSize(math.max(0.01, w), math.max(0.01, h))
	tex:ClearAllPoints()
	tex:SetPoint("CENTER", part.anchor or stage.box, "TOPLEFT", cx - (part.ax or 0), -(cy - (part.ay or 0)))
	tex:SetRotation(rotation)
end

-- Draws `part` at `fade` of the opacity it has whole, the crate's group's share of it besides.
---@param stage PagleCrateStage
---@param part PagleCratePart
local function showPart(stage, part)
	part.tex:SetAlpha(part.fade * part.alpha * (part.group and stage.groupAlpha or 1))
end

--- Sets how much of `part` shows, 0 to 1: its own opacity, if it has less than whole.
---@param stage PagleCrateStage
---@param part PagleCratePart
---@param a number
function ns.FadeCratePart(stage, part, a)
	part.fade = math.max(0, math.min(1, a))
	showPart(stage, part)
end

--- Sets how much of the crate as a whole shows, 0 to 1.
---@param stage PagleCrateStage
---@param a number
function ns.SetCrateGroupAlpha(stage, a)
	stage.groupAlpha = math.max(0, math.min(1, a))
	for _, part in ipairs(stage.parts) do
		if part.group then
			showPart(stage, part)
		end
	end
end

-- Draws `part` in `colour` ({ r, g, b }).
---@param part PagleCratePart
---@param colour number[]
local function tintPart(part, colour)
	part.tex:SetVertexColor(colour[1], colour[2], colour[3])
end

-- The inside's dark, as rows narrowing at the corners (a rounded rectangle), each a solid sheet of the same colour, so
-- its opacity is the dim's as a whole.
---@param root Frame
---@return Texture[]
local function buildDim(root)
	local dim = {}
	local function sheet(x, y, w, h)
		local texture = root:CreateTexture(nil, "BACKGROUND")
		texture:SetColorTexture(0.03, 0.02, 0.01, 0.985)
		texture:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
		texture:SetSize(w, h)
		dim[#dim + 1] = texture
	end
	local rows = { 3.5, 2, 1, 0.4 }
	local step = CORNER / #rows
	sheet(0, CORNER, INSIDE_W, INSIDE_H - 2 * CORNER)
	for i, inset in ipairs(rows) do
		sheet(inset, (i - 1) * step, INSIDE_W - 2 * inset, step)
		sheet(inset, INSIDE_H - i * step, INSIDE_W - 2 * inset, step)
	end
	return dim
end

-- A crate tier's colour.
---@param tier 1|2|3|4|5|6|"curio"
---@return number[]
local function colourOf(tier)
	return ns.CRATE_TIER_COLORS[tier]
end

-- A frame as big as the inside, `above` frame levels over `base`.
---@param parent Frame
---@param base Frame
---@param above integer
---@return Frame
local function layerOf(parent, base, above)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame:SetFrameLevel(base:GetFrameLevel() + above)
	return frame
end

-- The crate in parts, over its light: body, lid, the seal's glow, ribbon and the seal's two halves, in the prototype's
-- order, each carried by the group pose (the crate drops, rattles and sinks as one), the lid and the halves also with
-- a pose of their own about their middle (the lid about its foot, 80% of the way down the crate).
---@param stage PagleCrateStage
---@param frame Frame
local function buildCrate(stage, frame)
	local ax, ay = CRATE_X, CRATE_Y
	local crate = {
		body = newPart(frame, "crate-body", ax, ay, "ARTWORK", 0),
		lid = newPart(frame, "crate-lid", ax, ay, "ARTWORK", 1),
		glow = newPart(frame, "fx-seal-glow", ax + 128 - 38.4, ay + 78.4 - 38.4, "ARTWORK", 2),
		ribbon = newPart(frame, "crate-ribbon", ax, ay, "ARTWORK", 3),
		sealLeft = newPart(frame, "crate-seal-left", ax, ay, "ARTWORK", 4),
		sealRight = newPart(frame, "crate-seal-right", ax, ay, "ARTWORK", 5),
	}
	crate.lid.origin = { x = CX, y = ay + CRATE_H * 0.8 }
	stage.parts = { crate.body, crate.lid, crate.glow, crate.ribbon, crate.sealLeft, crate.sealRight }
	for _, part in ipairs(stage.parts) do
		part.group = true
	end
	stage.crate = crate
	stage.groupAlpha = 1
	stage.group = { tx = 0, ty = 0, deg = 0, sx = 1, sy = 1, ox = CX, oy = ay + CRATE_H }
end

-- The plaque, "CURIO CRATE": its two caps and its middle stretched between them, with the words over them.
---@param stage PagleCrateStage
---@param frame Frame
local function buildPlaque(stage, frame)
	local plaque = CreateFrame("Frame", nil, frame)
	local word = ns.ShopText(plaque, "CratePlaque", "OVERLAY")
	ns.SetShopText(word, L.SHOP_CRATE)
	local width = math.floor(word:GetStringWidth() + 2 * (26 * 0.8 + 2.4) + 0.5)
	plaque:SetSize(width, 32.8)
	plaque:SetPoint("TOP", frame, "TOPLEFT", CX, -PLAQUE_Y)
	word:SetPoint("CENTER", plaque, "CENTER", 0, 0)
	local capLeft = ns.ArtSprite(plaque, "Crate", "plaque-cap", "BACKGROUND", 0)
	local capRight = ns.ArtSprite(plaque, "Crate", "plaque-cap", "BACKGROUND", 0)
	local mid = ns.ArtSprite(plaque, "Crate", "plaque-mid", "BACKGROUND", 1)
	local cap, slice = sprites["plaque-cap"], sprites["plaque-mid"]
	local inner = cap.at[1] + cap.size[1]
	capLeft:SetSize(cap.size[1], cap.size[2])
	capLeft:SetPoint("TOPLEFT", plaque, "TOPLEFT", cap.at[1], -cap.at[2])
	capRight:SetSize(cap.size[1], cap.size[2])
	capRight:SetPoint("TOPLEFT", plaque, "TOPLEFT", width - inner, -cap.at[2])
	capRight:SetTexCoord(capRight.tc[2], capRight.tc[1], capRight.tc[3], capRight.tc[4])
	mid:SetSize(width - 2 * inner, slice.size[2])
	mid:SetPoint("TOPLEFT", plaque, "TOPLEFT", inner, -slice.at[2])
	stage.plaque = plaque
end

-- The odds along the crate's foot: each crate tier's pip in its colour, its name and its chance.
---@param stage PagleCrateStage
---@param frame Frame
local function buildOdds(stage, frame)
	stage.odds, stage.pips = {}, {}
	local gap, pipGap, y = 14.4, 4.8, INSIDE_H - ODDS_FOOT - 5
	local total = 0
	for i, tier in ipairs(ns.CRATE_TIERS) do
		local pip = frame:CreateTexture(nil, "ARTWORK")
		local c = colourOf(tier)
		pip:SetColorTexture(c[1], c[2], c[3], 1)
		pip:SetSize(8, 8)
		stage.pips[i] = pip
		local label = ns.ShopText(frame, "CrateOdds", "ARTWORK")
		label:SetText(("%s %s"):format(L.SHOP_CRATE_TIERS[tier], ns.CratePercent(ns.CRATE_ODDS[i])))
		stage.odds[i] = label
		total = total + 8 + pipGap + label:GetStringWidth() + (i > 1 and gap or 0)
	end
	local x = CX - total / 2
	for i, label in ipairs(stage.odds) do
		stage.pips[i]:SetPoint("LEFT", frame, "TOPLEFT", x, -y)
		label:SetPoint("LEFT", frame, "TOPLEFT", x + 8 + pipGap, -y)
		x = x + 8 + pipGap + label:GetStringWidth() + gap
	end
end

--- Lays a card's layers out about its middle, `sx` of the way across (a turning card is squashed to it).
---@param card PagleCrateCard
---@param sx number
function ns.LayoutCrateCard(card, sx)
	local width = math.max(0.01, sx)
	for _, layer in ipairs(card.layers) do
		local cx = layer.x + layer.w / 2 - CARD_W / 2
		local cy = layer.y + layer.h / 2 - CARD_H / 2
		layer.tex:ClearAllPoints()
		layer.tex:SetPoint("CENTER", card, "CENTER", cx * width, -cy)
		layer.tex:SetSize(math.max(0.01, layer.w * width), layer.h)
	end
end

-- A card layer from the crate kit, hidden.
---@param card PagleCrateCard
---@param name string
---@param layer DrawLayer
---@param sublevel integer
---@return PagleCrateCardLayer
local function cardLayer(card, name, layer, sublevel)
	local def = sprites[name]
	local tex = ns.ArtSprite(card, "Crate", name, layer, sublevel)
	tex:SetSize(def.size[1], def.size[2])
	if def.use:find("add", 1, true) then
		tex:SetBlendMode("ADD")
	end
	tex:Hide()
	local made = { tex = tex, x = def.at[1], y = def.at[2], w = def.size[1], h = def.size[2], alpha = def.alpha or 1 }
	card.layers[#card.layers + 1] = made
	return made
end

-- Swaps the sprite a layer shows (an emblem's), and its place with it.
---@param layer PagleCrateCardLayer
---@param name string
local function swapLayer(layer, name)
	local def = sprites[name]
	ns.SetSprite(layer.tex --[[@as Texture]], "Crate", name)
	layer.tex:SetSize(def.size[1], def.size[2])
	layer.x, layer.y, layer.w, layer.h = def.at[1], def.at[2], def.size[1], def.size[2]
end

-- A layer of a good's medallion on a card: a sprite of the shop's atlas, or a round picture.
---@param card PagleCrateCard
---@param sublevel integer
---@param sprite string? a shop sprite; none for the round picture
---@return PagleCrateCardLayer
local function medalLayer(card, sublevel, sprite)
	local tex
	if sprite then
		tex = ns.ArtSprite(card, "Shop", sprite, "ARTWORK", sublevel)
	else
		tex = ns.ArtCrisp(card:CreateTexture(nil, "ARTWORK", nil, sublevel))
		local mask = card:CreateMaskTexture()
		mask:SetTexture(
			"Interface\\CharacterFrame\\TempPortraitAlphaMask",
			"CLAMPTOBLACKADDITIVE",
			"CLAMPTOBLACKADDITIVE"
		)
		mask:SetAllPoints(tex)
		tex:AddMaskTexture(mask)
	end
	tex:Hide()
	local made = { tex = tex, x = 0, y = 0, w = 1, h = 1, alpha = 1 }
	card.layers[#card.layers + 1] = made
	return made
end

--- A card on `parent` (120 x 138): every layer a card can show, hidden, ns.StyleCrateCard showing the ones it takes. The
--- reveal's `full` card has a good's medallion and its Coins as well.
---@param parent Frame
---@param full boolean?
---@return PagleCrateCard
local function newCard(parent, full)
	local card = CreateFrame("Frame", nil, parent) --[[@as PagleCrateCard]]
	card:SetSize(CARD_W, CARD_H)
	card.layers = {}
	card.shadow = cardLayer(card, "card-shadow", "BACKGROUND", 0)
	card.glow = cardLayer(card, "card-glow", "BACKGROUND", 1)
	card.base = cardLayer(card, "card-base", "BORDER", 0)
	card.coin = cardLayer(card, "card-coin", "BORDER", 0)
	card.curio = cardLayer(card, "card-curio", "BORDER", 0)
	card.tint = cardLayer(card, "card-tint", "ARTWORK", 0)
	card.hatch = cardLayer(card, "card-hatch", "ARTWORK", 1)
	card.emblem = cardLayer(card, "emblem-toast", "ARTWORK", 2)
	card.emblemHi = cardLayer(card, "emblem-toast-hi", "ARTWORK", 3)
	card.glyph = cardLayer(card, "kind-toast", "ARTWORK", 5)
	card.sheen = cardLayer(card, "card-sheen", "OVERLAY", 2)
	card.label = ns.ShopText(card, "CardKind", "OVERLAY")
	card.label:SetPoint("BOTTOM", card, "BOTTOM", 0, 13.6)
	card.label:Hide()
	if full then
		card.ring = medalLayer(card, 3, "bezel-64")
		card.icon = medalLayer(card, 4)
		card.shield = medalLayer(card, 4)
		card.gloss = medalLayer(card, 6, "gloss-64")
		card.coins = ns.ShopText(card, "CardCoins", "OVERLAY")
		card.coins:SetPoint("BOTTOM", card, "BOTTOM", 0, 14)
		card.coins:SetJustifyH("CENTER")
		card.coins:Hide()
	end
	ns.LayoutCrateCard(card, 1)
	return card
end

-- Puts a shop-atlas sprite's drawn element, `scale` times its size, in the middle of a card.
---@param layer PagleCrateCardLayer
---@param name string
---@param scale number
local function medallion(layer, name, scale)
	local atlas = ns.ATLASES.Shop
	local def = atlas.sprites[name]
	local w, h = def.w / atlas.scale * scale, def.h / atlas.scale * scale
	layer.tex:SetSize(w, h)
	layer.w, layer.h = w, h
	layer.x = CARD_W / 2 - (def.box[1] + def.box[3] / 2) * scale
	layer.y = CARD_H / 2 - (def.box[2] + def.box[4] / 2) * scale
end

---@param layer PagleCrateCardLayer
---@param shown boolean
local function showLayer(layer, shown)
	layer.tex:SetShown(shown)
	if shown then
		layer.tex:SetAlpha(layer.alpha)
	end
end

-- Hides every layer of a card and its words.
---@param card PagleCrateCard
local function clearCard(card)
	for _, layer in ipairs(card.layers) do
		layer.tex:Hide()
	end
	card.label:Hide()
	if card.coins then
		card.coins:Hide()
	end
	card.ringing = nil
end

--- Dresses `card` for a card of the reel (ns.CrateReelCards): what it shows (the kind's emblem, the coin's, or the Curio
--- "?") in its crate tier's colour, and the kind's name under an emblem of a kind. `card.colour` is the colour.
---@param card PagleCrateCard
---@param spec PagleCrateCard|{ tier: 1|2|3|4|5|6|"curio", face: "kind"|"coin"|"curio", kind: string? }
function ns.StyleCrateCard(card, spec)
	local c = colourOf(spec.tier)
	card.colour = c
	clearCard(card)
	showLayer(card.shadow, true)
	card.glow.tex:SetVertexColor(c[1], c[2], c[3])
	if spec.face == "curio" then
		showLayer(card.curio, true)
		showLayer(card.sheen, true)
		ns.LayoutCrateCard(card, 1)
		return
	end
	local emblem = spec.face == "coin" and "coin" or ns.CrateEmblem(spec.kind)
	showLayer(card.base, true)
	for _, layer in ipairs({ card.tint, card.hatch, card.emblem }) do
		layer.tex:SetVertexColor(c[1], c[2], c[3])
		showLayer(layer, true)
	end
	swapLayer(card.emblem, "emblem-" .. emblem)
	swapLayer(card.emblemHi, "emblem-" .. emblem .. "-hi")
	showLayer(card.emblemHi, true)
	showLayer(card.sheen, true)
	local name = spec.face == "kind" and L.SHOP_CRATE_KINDS[spec.kind or ""]
	if name then
		card.label:SetText(name)
		card.label:SetTextColor(c[1], c[2], c[3])
		card.label:SetAlpha(0.85)
		card.label:Show()
	end
	ns.LayoutCrateCard(card, 1)
end

--- Dresses the reveal's `front` card for the result `data` (ns.ShopModel's CrateResult): a good's picture in its
--- medallion (a crest's shield instead) with its kind's glyph; a good the cache has nothing of turns over to its kind's
--- emblem; a payback's is the coin card, "+N Coins" under its coin. All in the crate tier's colour.
---@param card PagleCrateCard
---@param data PagleShopCrateResult
function ns.StyleCrateFront(card, data)
	local c = data.color
	if data.unseen then
		ns.StyleCrateCard(card, { tier = data.crateTier, face = "kind", kind = data.kind })
		card.label:Hide()
		return
	end
	card.colour = c
	clearCard(card)
	showLayer(card.shadow, true)
	card.tint.tex:SetVertexColor(c[1], c[2], c[3])
	if data.payback then
		showLayer(card.coin, true)
		showLayer(card.tint, true)
		showLayer(card.sheen, true)
		card.coins:SetText(data.title)
		card.coins:Show()
		ns.LayoutCrateCard(card, 1)
		return
	end
	showLayer(card.base, true)
	showLayer(card.tint, true)
	local picture = (data.shield and card.shield or card.icon) --[[@as PagleCrateCardLayer]]
	picture.tex:SetTexture(data.icon)
	if data.shield then
		picture.w, picture.h = SHIELD_H * 120 / 140, SHIELD_H
		ns.CropShield(picture.tex --[[@as Texture]])
	else
		medallion(card.ring --[[@as PagleCrateCardLayer]], "bezel-64", MEDAL)
		medallion(card.gloss --[[@as PagleCrateCardLayer]], "gloss-64", MEDAL)
		picture.w, picture.h = 44 * MEDAL, 44 * MEDAL
		picture.tex:SetTexCoord(ns.ICON_CROP, 1 - ns.ICON_CROP, ns.ICON_CROP, 1 - ns.ICON_CROP)
		showLayer(card.ring --[[@as PagleCrateCardLayer]], true)
		showLayer(card.gloss --[[@as PagleCrateCardLayer]], true)
	end
	picture.tex:SetSize(picture.w, picture.h)
	picture.x, picture.y = (CARD_W - picture.w) / 2, (CARD_H - picture.h) / 2
	showLayer(picture, true)
	local glyph = "kind-" .. ns.CrateEmblem(data.kind)
	if sprites[glyph] then
		swapLayer(card.glyph, glyph)
		showLayer(card.glyph, true)
	end
	showLayer(card.sheen, true)
	ns.LayoutCrateCard(card, 1)
end

-- The reel: its frame, its window with the 60 cards on a track, the ends fading to dark, the light under the line, the
-- line with its bobber and hook. `clip` wipes it open from its middle.
---@param stage PagleCrateStage
---@param frame Frame
local function buildReel(stage, frame)
	local reel = {}
	local rule = ns.CRATE_REEL
	local cap, slice = sprites["reel-frame-cap"], sprites["reel-frame-mid"]
	local capLeft, capTop, capW, capH = cap.at[1], cap.at[2], cap.size[1], cap.size[2]
	reel.clip = CreateFrame("Frame", nil, frame)
	reel.clip:SetClipsChildren(true)
	reel.clip:SetSize(REEL_W - 2 * capLeft, capH)
	reel.clip:SetPoint("TOPLEFT", frame, "TOPLEFT", REEL_X + capLeft, -(REEL_Y + capTop))
	reel.root = CreateFrame("Frame", nil, reel.clip)
	reel.root:SetSize(REEL_W, REEL_H)
	reel.root:SetPoint("TOPLEFT", frame, "TOPLEFT", REEL_X, -REEL_Y)
	-- the frame: its caps, the right one the left's mirrored, and its middle stretched between them
	local left = ns.ArtSprite(reel.root, "Crate", "reel-frame-cap", "BACKGROUND", 0)
	local right = ns.ArtSprite(reel.root, "Crate", "reel-frame-cap", "BACKGROUND", 0)
	local mid = ns.ArtSprite(reel.root, "Crate", "reel-frame-mid", "BACKGROUND", 1)
	local inner = capLeft + capW
	left:SetSize(capW, capH)
	left:SetPoint("TOPLEFT", reel.root, "TOPLEFT", capLeft, -capTop)
	right:SetSize(capW, capH)
	right:SetPoint("TOPLEFT", reel.root, "TOPLEFT", REEL_W - inner, -capTop)
	right:SetTexCoord(right.tc[2], right.tc[1], right.tc[3], right.tc[4])
	mid:SetSize(REEL_W - 2 * inner, slice.size[2])
	mid:SetPoint("TOPLEFT", reel.root, "TOPLEFT", inner, -slice.at[2])
	-- the window clips the cards, which run on a track
	reel.window = CreateFrame("Frame", nil, reel.root)
	reel.window:SetClipsChildren(true)
	reel.window:SetFrameLevel(reel.root:GetFrameLevel() + 1)
	reel.window:SetSize(WINDOW_W, WINDOW_H)
	reel.window:SetPoint("TOPLEFT", reel.root, "TOPLEFT", WINDOW_INSET, -WINDOW_INSET)
	reel.track = CreateFrame("Frame", nil, reel.window)
	reel.track:SetFrameLevel(reel.window:GetFrameLevel() + 1)
	reel.track:SetSize(rule.cards * rule.pitch, CARD_H)
	reel.track:SetPoint("TOPLEFT", reel.window, "TOPLEFT", WINDOW_W / 2 - CARD_W / 2, -CARD_TOP)
	reel.cards = {}
	for i = 1, rule.cards do
		local card = newCard(reel.track)
		card:SetPoint("TOPLEFT", reel.track, "TOPLEFT", (i - 1) * rule.pitch, 0)
		reel.cards[i] = card
	end
	-- the light under the line, in the colour of the card passing, over the cards' foot
	local lit = CreateFrame("Frame", nil, reel.window)
	lit:SetAllPoints(reel.window)
	lit:SetFrameLevel(reel.track:GetFrameLevel() + 2)
	local light = sprites["reel-light"]
	reel.light = newPart(
		lit,
		"reel-light",
		REEL_X + WINDOW_INSET + WINDOW_W / 2 - light.size[1] / 2,
		REEL_Y + WINDOW_INSET,
		"ARTWORK",
		0
	)
	-- the window's ends fade to dark
	local fades = CreateFrame("Frame", nil, reel.window)
	fades:SetAllPoints(reel.window)
	fades:SetFrameLevel(lit:GetFrameLevel() + 1)
	local fade = sprites["reel-fade"]
	for _, side in ipairs({ "left", "right" }) do
		local tex = ns.ArtSprite(fades, "Crate", "reel-fade", "ARTWORK", 0)
		tex:SetSize(fade.size[1], WINDOW_H)
		if side == "left" then
			tex:SetPoint("TOPLEFT", fades, "TOPLEFT", 0, 0)
		else
			tex:SetPoint("TOPRIGHT", fades, "TOPRIGHT", 0, 0)
			tex:SetTexCoord(tex.tc[2], tex.tc[1], tex.tc[3], tex.tc[4])
		end
	end
	-- the line, its glow, the bobber above it and the hook below
	local marker = CreateFrame("Frame", nil, reel.root)
	marker:SetAllPoints(reel.root)
	marker:SetFrameLevel(fades:GetFrameLevel() + 2)
	local lineX, lineY = REEL_X + REEL_W / 2, REEL_Y - 3.2
	reel.glow = newPart(marker, "reel-line-glow", lineX, lineY, "ARTWORK", 0)
	reel.line = newPart(marker, "reel-line", lineX, lineY, "ARTWORK", 1)
	reel.bobber = newPart(marker, "reel-bobber", lineX - 10.4, REEL_Y - 28.8, "ARTWORK", 2)
	reel.bobber.origin = { x = reel.bobber.x + reel.bobber.w / 2, y = reel.bobber.y + reel.bobber.h }
	reel.hook = newPart(marker, "reel-hook", lineX - 8.8, REEL_Y + 161.6, "ARTWORK", 2)
	for _, part in ipairs({ reel.glow, reel.line, reel.bobber, reel.hook }) do
		part.anchor, part.ax, part.ay = reel.root, REEL_X, REEL_Y
		ns.PoseCratePart(stage, part)
	end
	reel.light.anchor, reel.light.ax, reel.light.ay = lit, REEL_X + WINDOW_INSET, REEL_Y + WINDOW_INSET
	ns.PoseCratePart(stage, reel.light)
	reel.clip:Hide()
	stage.reel = reel --[[@as PagleCrateReel]]
end

-- The reveal: the halo and the two fans, the card (its two faces and the stamp), the words, the buttons and the flash.
---@param stage PagleCrateStage
---@param frame Frame
local function buildReveal(stage, frame)
	local behind = layerOf(frame, frame, 0)
	stage.halo = newPart(behind, "fx-halo", HERO_X, HERO_Y, "ARTWORK", 0)
	stage.fans[2] = newPart(behind, "rays-a", HERO_X, HERO_Y, "ARTWORK", 1)
	stage.fans[3] = newPart(behind, "rays-b", HERO_X, HERO_Y, "ARTWORK", 2)
	for _, part in ipairs({ stage.halo, stage.fans[2], stage.fans[3] }) do
		ns.PoseCratePart(stage, part)
	end
	local top = layerOf(frame, behind, 5)
	stage.pivot = CreateFrame("Frame", nil, top)
	stage.pivot:SetSize(1, 1)
	stage.pivot:SetPoint("CENTER", stage.box, "TOPLEFT", HERO_X, -HERO_Y)
	stage.hero = CreateFrame("Frame", nil, top)
	stage.hero:SetSize(CARD_W, CARD_H)
	stage.hero:SetPoint("CENTER", stage.pivot, "CENTER", 0, 0)
	stage.back = newCard(stage.hero)
	stage.back:SetPoint("CENTER", stage.hero, "CENTER", 0, 0)
	stage.front = newCard(stage.hero, true)
	stage.front:SetPoint("CENTER", stage.hero, "CENTER", 0, 0)
	-- the stamp: its word in a red box, upright (the client turns no words), landing from 2.6x
	stage.stampPivot = CreateFrame("Frame", nil, stage.hero)
	stage.stampPivot:SetSize(1, 1)
	stage.stampPivot:SetFrameLevel(stage.front:GetFrameLevel() + 5)
	stage.stamp = CreateFrame("Frame", nil, stage.stampPivot)
	stage.stamp:SetPoint("CENTER", stage.stampPivot, "CENTER", 0, 0)
	stage.stampWord = ns.ShopText(stage.stamp, "CrateStamp", "OVERLAY")
	stage.stampWord:SetPoint("CENTER", stage.stamp, "CENTER", 0, 0)
	local red = ns.SHOP_INKS.crateInk
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = stage.stamp:CreateTexture(nil, "OVERLAY")
		line:SetColorTexture(red[1], red[2], red[3], 1)
		if side == "TOP" or side == "BOTTOM" then
			line:SetHeight(2.4)
			line:SetPoint(side .. "LEFT", stage.stamp, side .. "LEFT", 0, 0)
			line:SetPoint(side .. "RIGHT", stage.stamp, side .. "RIGHT", 0, 0)
		else
			line:SetWidth(2.4)
			line:SetPoint("TOP" .. side, stage.stamp, "TOP" .. side, 0, 0)
			line:SetPoint("BOTTOM" .. side, stage.stamp, "BOTTOM" .. side, 0, 0)
		end
	end
	-- the words
	local words = layerOf(frame, top, 5)
	stage.tier = ns.ShopText(words, "CrateTier", "OVERLAY")
	stage.tierRules = {}
	for i = 1, 2 do
		stage.tierRules[i] = words:CreateTexture(nil, "OVERLAY")
		stage.tierRules[i]:SetSize(48, 1)
	end
	stage.name = ns.ShopText(words, "CrateName", "OVERLAY")
	stage.name:SetJustifyH("CENTER")
	stage.name:SetWidth(INSIDE_W - 80)
	stage.kind = ns.ShopText(words, "CrateKind", "OVERLAY")
	stage.note = ns.ShopText(words, "CrateNote", "OVERLAY")
	stage.note:SetJustifyH("CENTER")
	stage.note:SetWidth(INSIDE_W - 80)
	-- the buttons
	local buttons = layerOf(frame, words, 3)
	stage.useButton = ns.NewShopButton(buttons, function()
		if stage.onUse then
			stage.onUse()
		end
	end)
	stage.backButton = ns.NewShopButton(buttons, function()
		if stage.onBack then
			stage.onBack()
		end
	end)
	-- the white flash over the whole inside
	local flash = layerOf(frame, buttons, 3)
	stage.flash = flash:CreateTexture(nil, "OVERLAY")
	stage.flash:SetColorTexture(1, 1, 1, 1)
	stage.flash:SetBlendMode("ADD")
	stage.flash:SetAllPoints(flash)
end

--- A swarm of `sprite` (a particle sprite of the crate kit) on `frame`: its textures are made as they are needed.
---@param frame Frame
---@param sprite string
---@return PagleCrateSwarm
function ns.NewCrateSwarm(frame, sprite)
	return { frame = frame, sprite = sprite, def = sprites[sprite], layer = "ARTWORK", parts = {} }
end

--- Makes a swarm hold `count` particles.
---@param swarm PagleCrateSwarm
---@param count integer
function ns.GrowCrateSwarm(swarm, count)
	for i = #swarm.parts + 1, count do
		local tex = ns.ArtSprite(swarm.frame, "Crate", swarm.sprite, swarm.layer, 0)
		if swarm.def.use:find("add", 1, true) then
			tex:SetBlendMode("ADD")
		end
		tex:Hide()
		swarm.parts[i] = {
			tex = tex,
			live = false,
			start = 0,
			dur = 1,
			ease = ns.EASE.linear,
			n = 2,
			o = { 0, 1, 1, 1 },
			x = { 0, 0, 0, 0 },
			y = { 0, 0, 0, 0 },
			s = { 1, 1, 1, 1 },
			a = { 1, 1, 1, 1 },
			r = { 0, 0, 0, 0 },
			f = { 1, 1, 1, 1 },
		}
	end
end

--- Hides every particle of a swarm.
---@param swarm PagleCrateSwarm
function ns.ClearCrateSwarm(swarm)
	for _, part in ipairs(swarm.parts) do
		part.live = false
		part.tex:Hide()
	end
end

--- The swarm of `name` particles on the stage, made when first wanted, with all its particles.
---@param stage PagleCrateStage
---@param name "straw"|"dust"|"spark"|"ember"|"coin"
---@return PagleCrateSwarm
function ns.CrateSwarmOf(stage, name)
	local swarm = stage.swarms[name]
	if not swarm then
		swarm = ns.NewCrateSwarm(stage.swarmFrame, "fx-" .. name)
		stage.swarms[name] = swarm
	end
	ns.GrowCrateSwarm(swarm, SWARM[name])
	return swarm
end

--- Moves each live particle of `swarm` to where the swarm's clock `now` has it, hiding one that has not begun or is
--- done.
---@param stage PagleCrateStage
---@param swarm PagleCrateSwarm
---@param now number
function ns.StepCrateSwarm(stage, swarm, now)
	local def = swarm.def
	for _, p in ipairs(swarm.parts) do
		if p.live then
			local progress = (now - p.start) / p.dur
			if progress < 0 then
				p.tex:Hide()
			elseif progress >= 1 then
				p.live = false
				p.tex:Hide()
			else
				local u = p.ease(progress)
				local i = 1
				while i < p.n - 1 and p.o[i + 1] < u do
					i = i + 1
				end
				local span = p.o[i + 1] - p.o[i]
				local k = span > 0 and (u - p.o[i]) / span or 1
				local scale = p.s[i] + (p.s[i + 1] - p.s[i]) * k
				local flip = math.abs(p.f[i] + (p.f[i + 1] - p.f[i]) * k)
				local tex = p.tex
				tex:SetSize(math.max(0.01, def.size[1] * scale * flip), math.max(0.01, def.size[2] * scale))
				tex:ClearAllPoints()
				tex:SetPoint(
					"CENTER",
					stage.box,
					"TOPLEFT",
					p.x[i] + (p.x[i + 1] - p.x[i]) * k,
					-(p.y[i] + (p.y[i + 1] - p.y[i]) * k)
				)
				tex:SetRotation(math.rad(-(p.r[i] + (p.r[i + 1] - p.r[i]) * k)))
				tex:SetAlpha((p.a[i] + (p.a[i + 1] - p.a[i]) * k) * (def.alpha or 1))
				tex:Show()
			end
		end
	end
end

--- A particle of `swarm` not in the air, or nil when every one is.
---@param swarm PagleCrateSwarm
---@return PagleCrateParticle?
function ns.FreeCrateParticle(swarm)
	for _, p in ipairs(swarm.parts) do
		if not p.live then
			return p
		end
	end
	return nil
end

--- The crate's art and what it draws: the whole opening, over the case's inside. `frame` is the case.
---@param frame PagleShopFrame
---@return PagleCrateStage
function ns.BuildCrateStage(frame)
	local made = {
		phase = "crate",
		offset = 0,
		swarms = {},
		fans = {},
		rayTurn = { 0, 0, 0 },
		whip = 0,
		swarmNow = 0,
		tremble = { 0, 0 },
		heroAt = { HERO_X, HERO_Y },
		rayColour = { 1, 1, 1 },
	}
	local stage = made --[[@as PagleCrateStage]]
	local root = CreateFrame("Frame", nil, frame)
	root:SetSize(INSIDE_W, INSIDE_H)
	root:SetPoint("TOPLEFT", frame, "TOPLEFT", INSIDE_X, -INSIDE_Y)
	-- Over everything on the case; under the DIALOG strata's bill, flyer and catcher.
	root:SetFrameLevel(frame:GetFrameLevel() + 100)
	root:SetClipsChildren(true)
	root:EnableMouse(true) -- the tray and the lid under it take no clicks
	stage.root = root
	stage.dim = buildDim(root)
	local box = CreateFrame("Frame", nil, root)
	box:SetSize(INSIDE_W, INSIDE_H)
	box:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	stage.box = box
	-- the crate's light: its rays, the burst and the beam, then the crate over them
	local light = layerOf(box, box, 1)
	stage.fans[1] = newPart(light, "rays-crate", CX, LIGHT_Y, "ARTWORK", 0)
	stage.burst = newPart(light, "fx-burst", CX - 208, LIGHT_Y - 120, "ARTWORK", 1)
	stage.beam = newPart(light, "fx-beam", CX - 120, -67.2, "ARTWORK", 2)
	stage.beam.origin = { x = CX, y = 116.8 }
	for _, part in ipairs({ stage.fans[1], stage.burst, stage.beam }) do
		ns.PoseCratePart(stage, part)
	end
	buildCrate(stage, layerOf(box, box, 3))
	for _, part in ipairs(stage.parts) do
		ns.PoseCratePart(stage, part)
	end
	local plaque = layerOf(box, box, 5)
	buildPlaque(stage, plaque)
	buildOdds(stage, plaque)
	stage.swarmFrame = layerOf(box, box, 7)
	buildReel(stage, layerOf(box, box, 9))
	local reveal = layerOf(box, box, 20)
	buildReveal(stage, reveal)
	stage.swarmFrame:SetFrameLevel(reveal:GetFrameLevel() + 12)
	root:Hide()
	return stage
end

-- Sets a font string's opacity and its place `dy` units below `y` under the inside's middle.
---@param text PagleShopFontString
---@param stage PagleCrateStage
---@param y number
---@param a number
---@param dy number
local function placeText(text, stage, y, a, dy)
	text:SetAlpha(a)
	text:ClearAllPoints()
	text:SetPoint("TOP", stage.box, "TOPLEFT", CX, -(y + dy))
end

--- The reveal's words, shown `a` of the way, the tier's name with the rules either side of it.
---@param stage PagleCrateStage
---@param a number
function ns.SetCrateTier(stage, a)
	placeText(stage.tier, stage, TIER_Y, a, 0)
	for _, rule in ipairs(stage.tierRules) do
		rule:SetAlpha(a)
	end
end

---@param stage PagleCrateStage
---@param a number
---@param dy number
function ns.SetCrateName(stage, a, dy)
	placeText(stage.name, stage, NAME_Y, a, dy)
	placeText(stage.note, stage, NOTE_Y, a, dy)
end

---@param stage PagleCrateStage
---@param a number
---@param dy number
function ns.SetCrateKind(stage, a, dy)
	placeText(stage.kind, stage, KIND_Y, a, dy)
end

--- The stamp `scale` times its size, `a` of the way visible.
---@param stage PagleCrateStage
---@param scale number
---@param a number
function ns.SetCrateStamp(stage, scale, a)
	stage.stamp:SetScale(math.max(0.01, scale))
	stage.stamp:SetAlpha(a)
end

--- The buttons: shown or not, and `a` of the way visible.
---@param stage PagleCrateStage
---@param shown boolean
function ns.ShowCrateButtons(stage, shown)
	stage.backButton:SetShown(shown)
	stage.useButton:SetShown(shown and stage.data ~= nil and stage.data.canUse)
end

---@param stage PagleCrateStage
---@param a number
function ns.SetCrateButtons(stage, a)
	stage.backButton:SetAlpha(a)
	stage.useButton:SetAlpha(a)
end

--- Puts the revealed card `x`, `y` from the inside's top left (its tremble besides), `scale` times its size.
---@param stage PagleCrateStage
---@param x number
---@param y number
---@param scale number
function ns.SetCrateHero(stage, x, y, scale)
	stage.heroAt[1], stage.heroAt[2] = x, y
	stage.pivot:ClearAllPoints()
	stage.pivot:SetPoint("CENTER", stage.box, "TOPLEFT", x + stage.tremble[1], -(y + stage.tremble[2]))
	stage.hero:SetScale(scale)
end

--- Shakes the revealed card `dx`, `dy` units where it is.
---@param stage PagleCrateStage
---@param dx number
---@param dy number
function ns.SetCrateTremble(stage, dx, dy)
	stage.tremble[1], stage.tremble[2] = dx, dy
	stage.pivot:ClearAllPoints()
	stage.pivot:SetPoint("CENTER", stage.box, "TOPLEFT", stage.heroAt[1] + dx, -(stage.heroAt[2] + dy))
end

--- Shows or hides the revealed card.
---@param stage PagleCrateStage
---@param shown boolean
function ns.ShowCrateHero(stage, shown)
	stage.hero:SetShown(shown)
end

--- The halo behind the card, `a` of the way visible and `scale` times its size.
---@param stage PagleCrateStage
---@param a number
---@param scale number
function ns.SetCrateHalo(stage, a, scale)
	local halo = stage.halo
	halo.own[4], halo.own[5] = scale, scale
	ns.PoseCratePart(stage, halo)
	ns.FadeCratePart(stage, halo, a)
end

--- The reveal's rays: the two fans `rays` of the way visible, their halo `halo` and `scale`.
---@param stage PagleCrateStage
---@param rays number
---@param halo number
---@param scale number
function ns.SetCrateRays(stage, rays, halo, scale)
	ns.FadeCratePart(stage, stage.fans[2], rays)
	ns.FadeCratePart(stage, stage.fans[3], rays)
	ns.SetCrateHalo(stage, halo, scale)
end

--- The plaque `dy` units below its place, `a` of the way visible.
---@param stage PagleCrateStage
---@param dy number
---@param a number
function ns.SetCratePlaque(stage, dy, a)
	stage.plaque:ClearAllPoints()
	stage.plaque:SetPoint("TOP", stage.box, "TOPLEFT", CX, -(PLAQUE_Y + dy))
	stage.plaque:SetAlpha(a)
end

--- The odds line `a` of the way visible.
---@param stage PagleCrateStage
---@param a number
function ns.SetCrateOdds(stage, a)
	for i, label in ipairs(stage.odds) do
		label:SetAlpha(a)
		stage.pips[i]:SetAlpha(a)
	end
end

--- The card the line stopped on rings in its colour: its glow, shown or not.
---@param stage PagleCrateStage
---@param shown boolean
function ns.ShowCrateRing(stage, shown)
	local card = stage.reel.cards[ns.CRATE_REEL.win]
	card.ringing = shown or nil
	showLayer(card.glow, shown)
	if shown then
		card.glow.tex:SetAlpha(0)
	end
end

--- The ring `a` of the way lit.
---@param stage PagleCrateStage
---@param a number
function ns.SetCrateRing(stage, a)
	local card = stage.reel.cards[ns.CRATE_REEL.win]
	card.glow.tex:SetAlpha(a * card.glow.alpha)
end

--- Turns the revealed card `degrees` of the way through its turn over: squashed to the cosine of it, the face it shows
--- swapping at nothing, the back for an even number of half turns so far and the front for an odd one.
---@param stage PagleCrateStage
---@param degrees number
function ns.TurnCrateHero(stage, degrees)
	local sx = math.abs(math.cos(math.rad(degrees)))
	local front = math.floor((degrees + 90) / 180) % 2 == 1
	local shown, hidden = front and stage.front or stage.back, front and stage.back or stage.front
	hidden:Hide()
	shown:Show()
	ns.LayoutCrateCard(shown, sx)
	-- words can't be squashed: they show only on a face turned fully to us
	local words = sx >= 0.999
	shown.label:SetAlpha(words and 0.85 or 0)
	if shown.coins then
		shown.coins:SetAlpha(words and 1 or 0)
	end
end

--- Prepares the opening for a crate that gave `data` (ns.ShopModel's CrateResult): dresses the reel's 60 cards from `cards`
--- (ns.CrateReelCards) and the card that lifts out of it (the 53rd's, and the face it turns over to), the tier's name, the
--- good's name and kind and the stamp in the tier's colour, and sets the buttons. `offset` is where the line stops, in
--- units off the 53rd card's middle. Nothing is shown yet: ns.ResetCrateStage starts the opening.
---@param stage PagleCrateStage
---@param data PagleShopCrateResult
---@param cards PagleCrateCard[]
---@param offset number
function ns.PrepareCrateStage(stage, data, cards, offset)
	stage.data, stage.cards, stage.offset = data, cards, offset
	for i, card in ipairs(stage.reel.cards) do
		ns.StyleCrateCard(card, cards[i])
	end
	ns.StyleCrateCard(stage.back, cards[ns.CRATE_REEL.win])
	ns.StyleCrateFront(stage.front, data)
	local c = data.color
	stage.rayColour = c
	for _, rule in ipairs(stage.tierRules) do
		rule:SetColorTexture(c[1], c[2], c[3], 1)
	end
	stage.tier:SetTextColor(c[1], c[2], c[3])
	ns.SetShopText(stage.tier, data.tier)
	ns.SetShopText(stage.name, data.good and data.title or "")
	ns.SetShopText(stage.kind, data.good and data.kindName or "")
	stage.note:SetText(data.line or "")
	for i = 2, 3 do
		tintPart(stage.fans[i], c)
	end
	tintPart(stage.halo, c)
	-- the stamp sits on the card's top right corner, a little over its edge
	ns.SetShopText(stage.stampWord, data.stamp)
	local w = stage.stampWord:GetStringWidth() + 2 * (12 * 0.8 + 2.4)
	local h = 14.4 + 9 * 0.8 + 2 * 2.4
	stage.stamp:SetSize(w, h)
	stage.stampPivot:ClearAllPoints()
	stage.stampPivot:SetPoint("CENTER", stage.hero, "TOPRIGHT", 36 * 0.8 - w / 2, 18 * 0.8 * -1 + h / 2)
	-- the buttons: "Use it now" beside "Back to the shop", or the second alone
	ns.SetShopButton(stage.useButton, L.SHOP_USE_NOW, false, true)
	ns.SetShopButton(stage.backButton, L.SHOP_CRATE_BACK, false, true)
	stage.useButton:ClearAllPoints()
	stage.backButton:ClearAllPoints()
	if data.canUse then
		stage.useButton:SetPoint("TOPRIGHT", stage.box, "TOPLEFT", CX - 6, -BUTTONS_Y)
		stage.backButton:SetPoint("TOPLEFT", stage.box, "TOPLEFT", CX + 6, -BUTTONS_Y)
	else
		stage.backButton:SetPoint("TOP", stage.box, "TOPLEFT", CX, -BUTTONS_Y)
	end
	stage.tierRules[1]:ClearAllPoints()
	stage.tierRules[1]:SetPoint("RIGHT", stage.tier, "LEFT", -14, 0)
	stage.tierRules[2]:ClearAllPoints()
	stage.tierRules[2]:SetPoint("LEFT", stage.tier, "RIGHT", 14, 0)
end

--- What the motion needs to know of where things are, from the inside's top left.
ns.CRATE_STAGE = {
	width = INSIDE_W,
	height = INSIDE_H,
	cx = CX,
	lightY = LIGHT_Y,
	reelX = REEL_X,
	reelY = REEL_Y,
	-- the reel's wipe: its full size, and where its middle is (the frame's caps and shadow reach past the reel)
	clipWidth = REEL_W - 2 * sprites["reel-frame-cap"].at[1],
	clipHeight = sprites["reel-frame-cap"].size[2],
	clipY = REEL_Y + sprites["reel-frame-cap"].at[2] + sprites["reel-frame-cap"].size[2] / 2,
	windowWidth = WINDOW_W,
	cardTop = CARD_TOP,
	-- the middle of a card as it lies in the reel: where the card lifts out from
	cardY = REEL_Y + WINDOW_INSET + CARD_TOP + CARD_H / 2,
	heroX = HERO_X,
	heroY = HERO_Y,
}
