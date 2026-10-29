---@class PagleNS
local ns = select(2, ...)

-- The toast styles and the announcement art's choices (announcements.md › Toast styles, › UI, ANN-R80;
-- wallet-and-shop.md › SHOP-R25), as data keyed by the toast style good IDs. The look is the announcements art
-- kit's: a toast is a fresh entry in the Angler's ledger, a torn page on a leather spine, written in ink. Torn Page is
-- the free default and the kit's Ledger style; Ripple and Lantern Glow are Curio Shop goods, the kit's Ripple and
-- Lantern styles; the Curio Shop expansion's twelve are Curio Shop goods too, and three more are earned goods the
-- Ledger and the Tackle Board register in Core's slot (ANN-R81, SHOP-R25). A style picks the toast and Nod art (its
-- own atlas, data/AnnounceArt.lua or data/ToastStyleArt.lua), the medallions' trim or its own ring, the rubber stamps'
-- ink, the page's inks and toast.high's wax; the banner, the splash and the cards look the same in every style. A
-- style changes only the look, never timing, lanes, the Interruption budget, sounds or which moments show.
-- adapter/Art.lua draws the art, and adapter/Announcements.lua and adapter/Cards.lua the frames.

--- An { r, g, b } from a "RRGGBB" hex string: Core's one, for the announcements' inks and the Curio Shop's
--- (adapter/ShopArt.lua).
---@param hex string
---@return number[]
function ns.Rgb(hex)
	local out = {}
	for i = 1, 5, 2 do
		out[#out + 1] = tonumber(hex:sub(i, i + 1), 16) / 255
	end
	return out
end
local rgb = ns.Rgb

--- The canvas's inks, each { r, g, b }, by role.
---@type table<string, number[]>
ns.ANNOUNCE_COLORS = {
	ink = rgb("1E1408"), -- the handwriting
	ink2 = rgb("5A3A1C"), -- a size after the name, a ruler's label
	red = rgb("7A2A1A"), -- the printed kicker
	stamp = rgb("B4281A"), -- the rubber stamps' ink, a ruler's gain
	pencil = rgb("4A4844"), -- the old record, "+N more"
	amt = rgb("7A5410"), -- the Coins beside a coin
	gilt = rgb("F0CD6A"), -- over the world: banners, the card's head
	giltDeep = rgb("B98A26"), -- toast.high's kicker
	cream = rgb("EFE0BB"), -- a banner's handwritten line
	creamText = rgb("E6D8B8"),
	paperInk = rgb("3A2614"), -- a card's lines
	kicker = rgb("8A5A2A"), -- the books' small-caps kicker (adapter/Art.lua's SmallCaps)
	whenText = rgb("D8C49A"), -- a card's time, on its leather head
	dim = rgb("A89A7A"), -- the splash's "click anywhere"
	rule = rgb("2A1A0A"), -- a ruler's ticks
	fill = rgb("1C2846"), -- a ruler's new mark
	rippleWhat = rgb("1F4A66"),
	rippleInk = rgb("13243A"),
	rippleStamp = rgb("1F5A7A"),
	lanternWhat = rgb("8A3A08"),
	lanternInk = rgb("2A1404"),
}

--- A toast style: its toast and Nod atlas, its medallions' ring (the shared trim, a toast.high's own, or its own ring
--- in its atlas), the rubber stamp sprite and its ink, and the page's inks, each a role in ns.ANNOUNCE_COLORS: the
--- kicker and name, the Coins', toast.high's kicker, the size ruler's label and number (`small`), each the ledger's
--- own where the style has none (ns.ToastInks), and the tint of toast.high's wax, over its grey with `waxDesaturated`.
---@class PagleToastStyle
---@field id string
---@field atlas string
---@field layered? true                    -- a composed style, drawn from its `art` (ANN-R82)
---@field art? PagleToastArt2
---@field ring? true                       -- its own ring, `bezel-<size>` in its atlas (ANN-R81), for the trims
---@field trim? "gold"|"silver"|"bronze"   -- the shared trims, for a style without a ring
---@field highTrim? "gold"|"silver"|"bronze"
---@field stamp string
---@field stampInk string
---@field what string
---@field name string
---@field amt? string
---@field highWhat? string
---@field small? string                    -- the size ruler's label and number, for a dark page (ANN-R81)
---@field wax? string
---@field waxDesaturated? true

---@type table<string, PagleToastStyle>
ns.TOAST_STYLES = {
	-- The ledger itself: tan parchment, a brown leather spine, brass medallions and red ink.
	[ns.TOAST_STYLE_DEFAULT] = {
		id = ns.TOAST_STYLE_DEFAULT,
		atlas = "ToastsLedger",
		trim = "gold",
		highTrim = "bronze",
		stamp = "stamp",
		stampInk = "stamp",
		what = "red",
		name = "ink",
	},
	-- Blue leather, faint rings on the page, silver medallions and blue stamps.
	["core.toaststyle.ripple"] = {
		id = "core.toaststyle.ripple",
		atlas = "ToastsRipple",
		trim = "silver",
		highTrim = "silver",
		stamp = "stamp-blue",
		stampInk = "rippleStamp",
		what = "rippleWhat",
		name = "rippleInk",
	},
	-- A warm lamp glowing behind the medallion, and browner inks.
	["core.toaststyle.lanternglow"] = {
		id = "core.toaststyle.lanternglow",
		atlas = "ToastsLantern",
		trim = "gold",
		highTrim = "bronze",
		stamp = "stamp",
		stampInk = "stamp",
		what = "lanternWhat",
		name = "lanternInk",
	},
}

-- The Curio Shop expansion's twelve styles and the three the Ledger and the Tackle Board earn in Core's slot, which
-- Core draws like its own (ANN-R81, SHOP-R25), each with its own ring in its own atlas (data/ToastStyleArt.lua). Their
-- inks are the shop expansion kit's goods.json's, as "RRGGBB", each added to ns.ANNOUNCE_COLORS as the role
-- "<goodID>.<field>". Its blue, green and silver stamps take the blue stamp, the rest the red. `wax` is close to the
-- board's filter on the red wax: a tint over its grey for a style that turns it, a shade for one that keeps it.
local RINGED = {
	-- A sailcloth spine and tide columns ruled in navy.
	{
		id = "core.toaststyle.ship",
		atlas = "ToastsShip",
		stamp = "stamp-blue",
		inks = {
			what = "1F3A5A",
			name = "14202E",
			stampInk = "1F3A6A",
			amt = "7A5410",
			small = "14202E",
			wax = "47AEFF",
		},
		waxDesaturated = true,
	},
	-- Peeled bark tied with twine.
	{
		id = "core.toaststyle.birch",
		atlas = "ToastsBirch",
		stamp = "stamp-blue",
		inks = {
			what = "6A3A1A",
			name = "2A1A0A",
			stampInk = "3A5A2A",
			amt = "7A5410",
			small = "2A1A0A",
			wax = "BBD062",
		},
		waxDesaturated = true,
	},
	-- Sand in the fold, a shell left behind.
	{
		id = "core.toaststyle.tidepool",
		atlas = "ToastsTidepool",
		stamp = "stamp-blue",
		inks = {
			what = "1F5A5A",
			name = "102A2A",
			stampInk = "1F6A6A",
			amt = "7A5410",
			small = "102A2A",
			wax = "56FFCF",
		},
		waxDesaturated = true,
	},
	-- Soundings, rhumb lines and a compass rose; the red wax as it is.
	{
		id = "core.toaststyle.chart",
		atlas = "ToastsChart",
		stamp = "stamp",
		inks = { what = "8A1A10", name = "1A1408", stampInk = "8A1A10", amt = "7A5410", small = "1A1408" },
	},
	-- Rime grown in from the corners.
	{
		id = "core.toaststyle.frost",
		atlas = "ToastsFrost",
		stamp = "stamp-blue",
		inks = {
			what = "2A5A8A",
			name = "0E2440",
			stampInk = "2A6AA0",
			amt = "7A5410",
			small = "0E2440",
			wax = "77D9FF",
		},
		waxDesaturated = true,
	},
	-- Ticker tape, rivets and a gear.
	{
		id = "core.toaststyle.goblin",
		atlas = "ToastsGoblin",
		stamp = "stamp-blue",
		inks = {
			what = "1A6A2A",
			name = "102010",
			stampInk = "2A7A2A",
			amt = "7A5410",
			small = "102010",
			wax = "68FF3F",
		},
		waxDesaturated = true,
	},
	-- A kelp-wrapped spine studded with pearls.
	{
		id = "core.toaststyle.kelp",
		atlas = "ToastsKelp",
		stamp = "stamp-blue",
		inks = {
			what = "2A6A5A",
			name = "142A24",
			stampInk = "1E5A4E",
			amt = "7A5410",
			small = "142A24",
			wax = "7AFFBF",
		},
		waxDesaturated = true,
	},
	-- Night-blue vellum written in silver, on every page.
	{
		id = "core.toaststyle.moon",
		atlas = "ToastsMoon",
		stamp = "stamp-blue",
		inks = {
			what = "B8C8F0",
			name = "F2F4FF",
			stampInk = "DFE6FF",
			amt = "E8D080",
			highWhat = "E8EEFF",
			small = "B0BCD8",
			wax = "58A3FF",
		},
		waxDesaturated = true,
	},
	-- One great leaf, pressed and dried gold.
	{
		id = "core.toaststyle.leaf",
		atlas = "ToastsLeaf",
		stamp = "stamp",
		inks = {
			what = "3A5A10",
			name = "1A2A06",
			stampInk = "8A3A10",
			amt = "7A5410",
			small = "1A2A06",
			wax = "FF9621",
		},
		waxDesaturated = true,
	},
	-- Rolled up and corked: Driftglass Bottle.
	{
		id = "core.toaststyle.bottle",
		atlas = "ToastsBottle",
		stamp = "stamp-blue",
		inks = {
			what = "6A2A10",
			name = "2A1408",
			stampInk = "1F4A7A",
			amt = "7A5410",
			small = "2A1408",
			wax = "FF631F",
		},
		waxDesaturated = true,
	},
	-- A bronze plate, the catch hammered in.
	{
		id = "core.toaststyle.rune",
		atlas = "ToastsRune",
		stamp = "stamp",
		inks = {
			what = "3A1E06",
			name = "1E1004",
			stampInk = "3A1E06",
			amt = "2A1404",
			highWhat = "5A2A06",
			wax = "FF803C",
			small = "3A1E06",
		},
		waxDesaturated = true,
	},
	-- Gold leaf, lapis and vermilion; the red wax as it is.
	{
		id = "core.toaststyle.folio",
		atlas = "ToastsFolio",
		stamp = "stamp",
		inks = {
			what = "9A1A10",
			name = "1A1030",
			stampInk = "A8781A",
			amt = "7A5410",
			highWhat = "E8B830",
			small = "4A3A6A",
		},
	},
	-- The Tall Tale: a gilt border, blue silk and a proper seal (the Ledger's, LED-R117).
	{
		id = "ledger.toaststyle.legend",
		atlas = "ToastsLegend",
		stamp = "stamp-blue",
		inks = {
			what = "1A3A7A",
			name = "140E04",
			stampInk = "1A3A8A",
			amt = "7A5410",
			highWhat = "D8A830",
			wax = "0D95FF",
			small = "140E04",
		},
		waxDesaturated = true,
	},
	-- Oxblood vellum and gilt laurels (the Ledger's, LED-R117): gilt on every page, the wax shaded.
	{
		id = "ledger.toaststyle.prestige",
		atlas = "ToastsPrestige",
		stamp = "stamp",
		inks = {
			what = "F0CD6A",
			name = "FBEFD0",
			stampInk = "F0CD6A",
			amt = "F0CD6A",
			highWhat = "FFF1B8",
			small = "E0C8A0",
			wax = "D9D9D9",
		},
	},
	-- A page that was nearly kindling once (the Tackle Board's, TKB-R126).
	{
		id = "tackleboard.toaststyle.ember",
		atlas = "ToastsEmber",
		stamp = "stamp",
		inks = {
			what = "8A2A08",
			name = "1E0E04",
			stampInk = "C0400A",
			amt = "7A5410",
			small = "1E0E04",
			wax = "FF4300",
		},
		waxDesaturated = true,
	},
}
for _, entry in ipairs(RINGED) do
	local style = {
		id = entry.id,
		atlas = entry.atlas,
		ring = true,
		stamp = entry.stamp,
		waxDesaturated = entry.waxDesaturated,
	}
	for field, hex in pairs(entry.inks) do
		local role = ("%s.%s"):format(entry.id, field)
		ns.ANNOUNCE_COLORS[role] = rgb(hex)
		style[field] = role
	end
	ns.TOAST_STYLES[entry.id] = style
end

-- The Curio Shop round two's ten composed styles (ANN-R82): seven the Ledger earns in Core's slot, Sonar Scope Core
-- earns, Prize Foil from the Curio crate and Storm Front for sale. Each draws its own layers on each rung instead of a
-- page (adapter/ToastLayers.lua), from its art in data/ToastStyleArt2.lua, keyed by its good ID. Its inks are its
-- rungs', each added to ns.ANNOUNCE_COLORS as the role "<goodID>.<rung>.<ink>"; the style's own fields name its toast
-- rung's, for what reads a style without a page (the digest's rows). It has no ring and no wax: its medallion is its
-- layers' and toast.high's seal its art's.

---@class PagleToastInk
---@field face PagleArtFace
---@field size number
---@field color string "RRGGBB"
---@field caps? true                  -- set in capitals
---@field shadow? { color: string, alpha: number, x: number, y: number }

---@alias PagleToastBox PagleArtBox
---@alias PagleToastLayerMotion PagleArtMotion

--- A composed rung's layer (logic/LayeredArt.lua's), on the host it draws on: under the medallion's icon, over it,
--- or over the words. A layer's motion that loops on the canvas loops in game, but ns.TOAST_MOTION_ONCE's.
---@class PagleToastLayer: PagleArtLayer
---@field host "under"|"front"|"over"

--- A composed rung's stamp: its sprite at its box, three-sliced at its caps to hold its word and tilted, with any
--- motion; drawn on the stamp's own frame, not on a host.
---@class PagleToastStamp: PagleArtBox
---@field name string
---@field sprite string
---@field slice { left: number, right: number } -- its caps
---@field tilt? number                -- degrees clockwise
---@field motion? PagleArtMotion

---@class PagleToastRung
---@field w number
---@field h number
---@field med PagleToastBox
---@field icon PagleToastBox
---@field text PagleToastBox
---@field coin? PagleToastBox
---@field amt? PagleToastBox
---@field slice? { left: number, right: number } -- the Nod body's caps
---@field inks table<string, PagleToastInk>
---@field layers PagleToastLayer[]
---@field stamp? PagleToastStamp

--- A stage's deco on one rung: its sprite in the style's atlas, and its box (UI units from the rung's top left).
---@class PagleToastStageDeco: PagleArtBox
---@field sprite string

--- One stage of a style whose art grows with a count (ANN-R85): from `min` on, its deco layer draws `toast` on the toast
--- rung and `high` on toast.high's, each at its own box.
---@class PagleToastStage
---@field min integer
---@field toast PagleToastStageDeco
---@field high PagleToastStageDeco

---@class PagleToastArt2
---@field atlas string
---@field rungs table<"toast"|"high"|"nod", PagleToastRung>
---@field stages? PagleToastStage[] -- by `min`, rising: the Cartographer's Folio's five (ANN-R85)

for id, art in pairs(ns.TOAST_STYLE_ART2 or {}) do
	for rungName, rung in pairs(art.rungs) do
		for field, ink in pairs(rung.inks) do
			ns.ANNOUNCE_COLORS[("%s.%s.%s"):format(id, rungName, field)] = rgb(ink.color)
		end
	end
	local function role(field)
		return art.rungs.toast.inks[field] and ("%s.toast.%s"):format(id, field) or nil
	end
	ns.TOAST_STYLES[id] = {
		id = id,
		atlas = art.atlas,
		layered = true,
		art = art,
		trim = "gold",
		highTrim = "bronze",
		stamp = "stamp",
		stampInk = role("stamp") or "stamp",
		what = role("what") or "red",
		name = role("name") or "ink",
		amt = role("amt"),
		small = role("small"),
	}
end

--- The kit's keyframes that play once in game, though the canvas loops them: a beat on the toast landing (Through the
--- Ice's tip-up flag springs up and settles; the Cartographer's Folio's leaves open, its needle settles and its route
--- inks itself with the ship sailing it; Nat's Study turns yesterday's page; the Deep Trench's gauge sinks to the red,
--- ANN-R85). Every other layer's motion is the style's own weather, and loops while its toast is on screen.
ns.TOAST_MOTION_ONCE = {
	["ice-flag"] = true,
	["carto-open"] = true,
	["carto-needle"] = true,
	["carto-route"] = true,
	["carto-sail-toast"] = true,
	["carto-sail-high"] = true,
	["study-turn-toast"] = true,
	["study-turn-high"] = true,
	["tr-depth"] = true,
}

--- The layers that draw only on a toast whose variety gleams (VAR-R26: a Rare or Epic one), by the keyframes of their
--- motion: the Extravaganza Gala's burst of confetti, which goes off once on toast.high (ANN-R85). On any other toast the
--- style draws without it.
ns.TOAST_GLEAM_ONLY = { ["gala-pop"] = true }

--- A layer's motion as animations (logic/LayeredArt.lua's ns.LayerAnimations), `landing` seconds in, a keyframe
--- ns.TOAST_MOTION_ONCE names played once: the toast layers' rule, which the Legend crests' layered pieces share.
---@param motion PagleArtMotion
---@param landing number
---@param apply fun(kind: string, values: number[])
---@return PagleAnimation[]
function ns.ToastLayerAnimations(motion, landing, apply)
	return ns.LayerAnimations(motion, landing, apply, ns.TOAST_MOTION_ONCE[motion.keyframes])
end

--- The rung of a composed style's art a page is drawn from (ANN-R82): toast.high's page from its high rung, every other
--- page from its toast rung (toast.low's toasts are drawn full size, ANN-R80); with no page, the Nod's.
---@param page PagleToastPage?
---@return "toast"|"high"|"nod"
function ns.ToastRungKey(page)
	if not page then
		return "nod"
	end
	return page.high and "high" or "toast"
end

--- A composed style's rung for a page (ns.ToastRungKey), or nil for a style that isn't composed.
---@param style PagleToastStyle
---@param page PagleToastPage?
---@return PagleToastRung?
function ns.ToastRungArt(style, page)
	return style.art and style.art.rungs[ns.ToastRungKey(page)]
end

--- The stage deco a style's art draws at `count` (ANN-R85): on the rung `page` is drawn from, the last of its `stages`
--- whose `min` the count has reached, the first when the count is below them all (the Folio is owned from its first
--- stage on, so only a good the test log grants, or a preview before it is earned, is there). Nil for a style with no
--- stages, for a nil count (the Ledger hasn't counted yet) and for a stage whose sprite isn't in the style's atlas:
--- the deco layer is then the rung's own, which is stage 4's.
---@param style PagleToastStyle
---@param page PagleToastPage?
---@param count integer?
---@return PagleToastStageDeco?
function ns.ToastStageDeco(style, page, count)
	local stages = style.art and style.art.stages
	if not stages or count == nil then
		return nil
	end
	local chosen = stages[1]
	for _, stage in ipairs(stages) do
		if count >= stage.min then
			chosen = stage
		end
	end
	local deco = chosen and chosen[ns.ToastRungKey(page)]
	local atlas = ns.ATLASES[style.art.atlas]
	if type(deco) ~= "table" or not (atlas and atlas.sprites[deco.sprite]) then
		return nil
	end
	return deco
end

--- What a composed toast draws differently from its rung's own layers (ANN-R85).
---@class PagleToastDrawing
---@field gleams boolean? the toast's variety gleams (VAR-R26), so a layer in ns.TOAST_GLEAM_ONLY draws
---@field count integer? the count the style's stages are picked by (ns.ToastStageDeco)

--- The layers of a composed style's rung to draw for `page` (a Nod's with none): the rung's own, but for the layers
--- ns.TOAST_GLEAM_ONLY keeps back unless the toast's variety gleams, and the deco layer of a style with stages drawn
--- from its stage's sprite, at its stage's box (ns.ToastStageDeco). A Nod has neither.
---@param style PagleToastStyle
---@param page PagleToastPage?
---@param drawing PagleToastDrawing?
---@return PagleToastLayer[]
function ns.ToastDrawLayers(style, page, drawing)
	local rung = ns.ToastRungArt(style, page) --[[@as PagleToastRung]]
	drawing = drawing or {}
	local stage = page and ns.ToastStageDeco(style, page, drawing.count) or nil
	local layers = {}
	for _, layer in ipairs(rung.layers) do
		local motion = layer.motion
		-- A layer the toast's variety doesn't call for is left out.
		if not (page and motion and ns.TOAST_GLEAM_ONLY[motion.keyframes] and not drawing.gleams) then
			if stage and layer.name == "deco" then
				local staged = {}
				for key, value in pairs(layer) do
					staged[key] = value
				end
				staged.sprite, staged.x, staged.y, staged.w, staged.h = stage.sprite, stage.x, stage.y, stage.w, stage.h
				layer = staged
			end
			layers[#layers + 1] = layer
		end
	end
	return layers
end

--- A composed style's ink `field` ("what", "name", "small", "amt" or "stamp") on a page, and its role in
--- ns.ANNOUNCE_COLORS: its rung's, else its toast rung's (the Nod has no Coins, ruler or stamp inks of its own), else
--- none.
---@param style PagleToastStyle
---@param page PagleToastPage?
---@param field string
---@return PagleToastInk?
---@return string?
function ns.ToastInk(style, page, field)
	local key = ns.ToastRungKey(page)
	for _, rungName in ipairs({ key, "toast" }) do
		local ink = style.art.rungs[rungName].inks[field]
		if ink then
			return ink, ("%s.%s.%s"):format(style.id, rungName, field)
		end
	end
	return nil, nil
end

--- A composed style's stamp on a rung (ANN-R82): its own, or its toast rung's kept as far from the right edge (the Nod
--- has none of its own).
---@param style PagleToastStyle
---@param page PagleToastPage?
---@return PagleToastStamp
function ns.ToastStampArt(style, page)
	local rung = ns.ToastRungArt(style, page) --[[@as PagleToastRung]]
	if rung.stamp then
		return rung.stamp
	end
	local toast = style.art.rungs.toast
	local stamp = {}
	for key, value in pairs(toast.stamp) do
		stamp[key] = value
	end
	stamp.x = toast.stamp.x + rung.w - toast.w
	return stamp
end

-- A layer as wide or tall as this share of its rung stretches with the page; a smaller one keeps its size.
local SPAN = 0.6

-- One axis of ns.FitToastBox: a box at `at`, `size` long on a rung `from` long, on a page `to` long.
local function fitAxis(at, size, from, to, centred)
	local grow = to - from
	if grow == 0 then
		return at, size
	elseif centred then
		return at + grow / 2, size
	elseif size >= from * SPAN then
		return at, size + grow
	elseif at + size / 2 > from / 2 then
		return at + grow, size
	end
	return at, size
end

--- Where a box of a rung's art goes on a page of another size (ANN-R82): the kit draws four rungs, and a toast with a
--- ruler or the digest is taller or wider than its rung, a Nod as long as its line. Across and down, a box spanning
--- most of the rung (the body, a sweep) stretches with the page, keeping its edges' distance from the rung's; a smaller
--- one keeps its size and its distance from the nearer edge, so a stamp stays at the top right and a lure at the
--- medallion. A `centred` box (the medallion's) stays centred down the page instead.
---@param box PagleToastBox
---@param rung { w: number, h: number }
---@param w number the page's width
---@param h number its height
---@param centred boolean?
---@return PagleToastBox
function ns.FitToastBox(box, rung, w, h, centred)
	local x, width = fitAxis(box.x, box.w, rung.w, w, false)
	local y, height = fitAxis(box.y, box.h, rung.h, h, centred)
	return { x = x, y = y, w = width, h = height }
end

--- The style a toast style good ID draws in: its own, or Torn Page for any other ID, or none (ANN-R80): before Core's
--- slot is registered, GetEquipped has no good for it.
---@param goodID any
---@return PagleToastStyle
function ns.ToastStyleOf(goodID)
	return ns.TOAST_STYLES[goodID] or ns.TOAST_STYLES[ns.TOAST_STYLE_DEFAULT]
end

--- A medallion's ring: a sprite of an atlas.
---@class PagleBezelRing
---@field atlas string
---@field sprite string

--- The ring a style draws round a medallion `size` across (84, 64, 34 or 22), on toast.high's page with `high`: its
--- own `bezel-<size>` in its atlas (ANN-R81), or the shared trim's, its toast.high's own there (ANN-R80).
---@param style PagleToastStyle
---@param size integer
---@param high boolean?
---@return PagleBezelRing
function ns.BezelRing(style, size, high)
	if style.ring then
		return { atlas = style.atlas, sprite = "bezel-" .. size }
	end
	return { atlas = "Announce", sprite = ("bezel-%s-%d"):format(high and style.highTrim or style.trim, size) }
end

--- The inks a style writes in on `page` (ANN-R80, ANN-R81), each a role in ns.ANNOUNCE_COLORS: the kicker, the name,
--- the Coins, and the size ruler's label and number. toast.high's kicker is gilt, unless the style has its own; the
--- ruler's label and number are in the style's `small` on every page, the Nod's number too, or in the ledger's inks
--- for a style without one. With no page, the Nod's.
---@param style PagleToastStyle
---@param page PagleToastPage?
---@return { what: string, name: string, amt: string, label: string, value: string }
function ns.ToastInks(style, page)
	if style.layered then
		-- A composed style's rung's own (ANN-R82), else its toast rung's, else the ledger's.
		local function role(field, fallback)
			local _, found = ns.ToastInk(style, page, field)
			return found or fallback
		end
		return {
			what = role("what", "red"),
			name = role("name", "ink"),
			amt = role("amt", "amt"),
			label = role("small", "ink2"),
			value = role("small", "ink"),
		}
	end
	local label, value = style.small or "ink2", style.small or "ink"
	return {
		what = page and page.high and (style.highWhat or "giltDeep") or style.what,
		name = style.name,
		amt = style.amt or "amt",
		label = label,
		value = value,
	}
end

--- A toast's page: its art (the sprite "toast-<page>" in the style's atlas) and its layout, in UI units: its size, the
--- medallion's size and left, the words' left and top, and the coin's size. `high` is gilt and wax.
---@class PagleToastPage
---@field page string
---@field w number
---@field h number
---@field bezel number
---@field bx number
---@field tx number
---@field ty number
---@field coin number
---@field high boolean?
---@field ruled boolean?
---@field digest boolean?

---@type table<string, PagleToastPage>
local PAGES = {
	["toast"] = { page = "toast", w = 464, h = 92, bezel = 84, bx = 4, tx = 138, ty = 12, coin = 42 },
	["toast-ruled"] = {
		page = "toast-ruled",
		w = 464,
		h = 122,
		bezel = 84,
		bx = 4,
		tx = 138,
		ty = 12,
		coin = 42,
		ruled = true,
	},
	["high"] = { page = "high", w = 524, h = 100, bezel = 84, bx = 4, tx = 138, ty = 12, coin = 42, high = true },
	["digest"] = { page = "digest", w = 560, h = 176, bezel = 84, bx = 4, tx = 138, ty = 12, coin = 42, digest = true },
}

--- The widest toast page, in UI units: where the Toast column's foot may go (ANN-R98).
ns.TOAST_WIDTH_MAX = 0
for _, page in pairs(PAGES) do
	ns.TOAST_WIDTH_MAX = math.max(ns.TOAST_WIDTH_MAX, page.w)
end

--- The page a toast is drawn on (announcements.md › UI): "While you were fighting" on the digest page; a headline with
--- a record ruler on a ruled page (a toast.high's on toast's, the high page having no room for one); else by its
--- rung, toast.high on the gilt page and every other toast, toast.low's (the catch toast's) included, on toast's.
---@param announcement PagleAnnouncement
---@return PagleToastPage
function ns.ToastPage(announcement)
	if announcement.fighting then
		return PAGES.digest
	end
	local rung, ruled = announcement.headline.rung, announcement.headline.ruler ~= nil
	if rung == "toast.high" and not ruled then
		return PAGES.high
	end
	return ruled and PAGES["toast-ruled"] or PAGES.toast
end

--- What a banner's wax seal shows (announcements.md › Contracts, `seal`): a number pressed into it, the Prestige frame
--- of the headline's `frameRank` holding the Angler's portrait (`frame`, ANN-R83), a crest good's icon in the seal's
--- place (`icon`: "crest" with `crest`, a fish crest, VAR-R25), or one of the pressed marks; the waves when the
--- headline names none, a "frame" with no rank or a "crest" with no icon.
---@param headline PagleMoment
---@return { number: integer?, frame: integer?, icon: (integer|string)?, mark: string? }
function ns.BannerSeal(headline)
	local seal = headline.seal
	if type(seal) == "number" then
		return { number = seal }
	elseif seal == "frame" and type(headline.frameRank) == "number" then
		return { frame = math.max(0, math.floor(headline.frameRank)) }
	elseif seal == "crest" and headline.crest ~= nil then
		return { icon = headline.crest }
	elseif seal == "book" or seal == "quill" or seal == "waves" then
		return { mark = seal }
	end
	return { mark = "waves" }
end

-- The client's escape sequences a text may hold, each copied as it is: a texture (|T…|t), an atlas (|A…|a) or a
-- link's data (|H…|h) to its end, a colour's |c and 8 hex digits, and the two-character ones (|r, |n, ||).
local ESCAPE_ENDS = { T = "|t", A = "|a", H = "|h" }

--- `text` in capitals, as the art sets printed words and stamps (the client has no small caps), leaving its escape
--- sequences as they are: a capital |t would no longer end a texture.
---@param text string
---@return string
function ns.Capitals(text)
	local out, i = {}, 1
	while i <= #text do
		local bar = text:find("|", i, true)
		if not bar then
			out[#out + 1] = text:sub(i):upper()
			break
		end
		out[#out + 1] = text:sub(i, bar - 1):upper()
		local kind = text:sub(bar + 1, bar + 1)
		local last = bar + 1
		if ESCAPE_ENDS[kind] then
			local _, ends = text:find(ESCAPE_ENDS[kind], bar + 2, true)
			last = ends or #text
		elseif kind == "c" then
			last = bar + 9
		end
		out[#out + 1] = text:sub(bar, last)
		i = last + 1
	end
	return table.concat(out)
end

--- A banner's kicker: its letters in capitals, a space between each and four between words, as the canvas spaces it
--- (the client has no letter-spacing). A text with escape sequences is only put in capitals.
---@param text string
---@return string
function ns.SpacedCaps(text)
	if text:find("|", 1, true) then
		return ns.Capitals(text)
	end
	local out = {}
	for char in text:upper():gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		out[#out + 1] = char == " " and "  " or char
	end
	return table.concat(out, " ")
end

--- A sample toast in a style (wallet-and-shop.md › UI, the preview stage): an Announcement raised by no Module and on
--- no Cast, a headline with one stamp and 5 Coins, carrying `style` so it is drawn in that style, whatever is equipped.
---@param styleID string
---@return PagleAnnouncement
function ns.SampleAnnouncement(styleID)
	local L = ns.L
	local function sample(fields)
		local moment =
			{ module = ns.CORE_OWNER, moduleTitle = L.SHOP_CORE, moduleOrder = 0, raised = 0, kind = "sample" }
		for key, value in pairs(fields) do
			moment[key] = value
		end
		return moment
	end
	local announcement = ns.MakeAnnouncement({
		sample({ rung = "toast", title = L.TOAST_SAMPLE_TITLE, text = L.TOAST_SAMPLE_TEXT, icon = ns.DEFAULT_ICON }),
		sample({ rung = "nod", title = L.TOAST_SAMPLE_STAMP, coins = 5 }),
	}) --[[@as PagleAnnouncement]]
	announcement.style = styleID
	return announcement
end

-- A variety's art cropped to the fish's head (core/varieties.md › UI): the art faces left, 192 × 96 texels, so the
-- head is a square at its left, inset from its snout (VAR-R26 crops a stepped-down catch toast's medallion the same
-- way). As shares of the art's width and height.
local HEAD_LEFT, HEAD_RIGHT = 0.03, 0.405
local HEAD_TOP, HEAD_BOTTOM = 0.125, 0.875

--- A moment's art (announcements.md › Contracts, `art`) cropped to the fish's head, as texture coordinates for a
--- medallion's round icon: the square at the left of the art's rectangle.
---@param art { left: number, right: number, top: number, bottom: number }
---@return number left
---@return number right
---@return number top
---@return number bottom
function ns.HeadCrop(art)
	local w, h = art.right - art.left, art.bottom - art.top
	return art.left + w * HEAD_LEFT, art.left + w * HEAD_RIGHT, art.top + h * HEAD_TOP, art.top + h * HEAD_BOTTOM
end

--- How a variety is drawn on a toast or a stepped-down catch toast's Nod (VAR-R26): the colour for the gem before
--- the name and its ink for the name and a stamp (these alone leave the style's ink, ANN-R80), the colour for the
--- medallion's ring, none for Common, whose ring stays the style's, and whether it gleams as it enters.
---@class PagleVarietyLook
---@field color number[]
---@field ink number[]
---@field ring number[]?
---@field gleam boolean
---@field backing number[]  -- the opaque disc behind its art in the medallion (ns.ArtBacking)

--- How a catch toast stepped down to a Nod draws the variety its line names (VAR-R26): the name and the line either
--- side of it.
---@class PagleNodVarietyLook: PagleVarietyLook
---@field name string
---@field before string
---@field after string

-- The rarities whose toast or stepped-down catch toast gleams as it enters (VAR-R26), and the one whose ring stays
-- the style's.
local GLEAMS = { rare = true, epic = true }
local PLAIN_RING = "common"

-- The disc behind a variety's art (#424): its art is transparent round the fish, so the medallion's face is deep
-- water, as the fish swims in, tinted a little by the rarity's colour.
local BACKING, BACKING_TINT = { 0.07, 0.12, 0.18 }, 0.15

--- The opaque colour behind a medallion's art, `{ r, g, b }`: deep water, tinted by `color` (a rarity's) a little, or
--- plain without one.
---@param color number[]?
---@return number[]
function ns.ArtBacking(color)
	local out = {}
	for i = 1, 3 do
		out[i] = color and BACKING[i] * (1 - BACKING_TINT) + color[i] * BACKING_TINT or BACKING[i]
	end
	return out
end

-- The look of a variety of rarity `key`, or nil for a rarity Core doesn't know.
---@param key string
---@return PagleVarietyLook?
local function rarityLook(key)
	for _, rarity in ipairs(ns.VARIETY_RARITIES) do
		if rarity.key == key then
			return {
				color = rarity.color,
				ink = rarity.ink,
				ring = rarity.key ~= PLAIN_RING and rarity.color or nil,
				gleam = GLEAMS[rarity.key] == true,
				backing = ns.ArtBacking(rarity.color),
			}
		end
	end
	return nil
end

--- The variety a catch toast stepped down to a Nod names, as the Nod draws it (VAR-R26), or nil for a headline that
--- isn't Core's catch toast naming one, or one of a rarity Core doesn't know.
---@param headline { catchToast: true?, variety: PagleNodVariety? }
---@return PagleNodVarietyLook?
function ns.CatchToastNodLook(headline)
	local variety = headline.catchToast and headline.variety
	if not variety then
		return nil
	end
	local look = rarityLook(variety.rarity)
	if not look then
		return nil
	end
	---@cast look PagleNodVarietyLook
	look.name = variety.name
	look.before = variety.before --[[@as string]]
	look.after = variety.after --[[@as string]]
	return look
end

--- How a toast that announces a variety draws it (VAR-R26, #424).
---@class PagleToastVarietyLook: PagleVarietyLook
---@field name string
---@field rarity string
---@field art PagleMomentArt?   -- the variety's, cropped to the fish's head in the medallion in place of the icon
---@field stamp string?         -- the text its moment shows as a stamp, which takes the rarity's ink; nil for the headline with no stamp of its own
---@field before string?        -- the name line's first half before the gem and the name ("" for the name alone); nil: no name

--- The variety a toast announces, as it is drawn (VAR-R25, VAR-R26), or nil for an Announcement that isn't a toast, the
--- "While you were fighting" toast, one with no variety moment or one of a rarity Core doesn't know. The moment is a
--- Module's first-catch one (VAR-R25) or Core's catch toast naming a variety caught before (VAR-R26, VAR-R28), the
--- only toast to name one that isn't just caught (VAR-R27), and the one with no stamp. The variety's moment may be
--- the headline (a Rare variety's toast) or ride on another's (a size record's, a New Species'): its art then still
--- fills the medallion and its stamp takes the rarity's ink. The name is written, after a gem, on the headline's text
--- line only when that line is about the fish itself: the variety's own toast, or one whose `icon` is the variety
--- moment's item and whose text is its first half.
---@param announcement PagleAnnouncement
---@return PagleToastVarietyLook?
function ns.ToastVarietyLook(announcement)
	local headline = announcement.headline
	if announcement.fighting or not headline.rung:find("^toast") then
		return nil
	end
	local moment
	for _, candidate in ipairs(announcement.moments) do
		if candidate.variety then
			moment = candidate
			break
		end
	end
	local look = moment and rarityLook(moment.variety.rarity)
	if not (moment and look) then
		return nil
	end
	---@cast look PagleToastVarietyLook
	look.name, look.rarity, look.art = moment.variety.name, moment.variety.rarity, moment.art
	if moment ~= headline then
		look.stamp = moment.stamp or moment.title
		if headline.text and headline.icon ~= nil and headline.icon == moment.icon then
			look.before = ns.L.TOAST_VARIETY_BEFORE:format(headline.text)
		end
	elseif headline.catchToast then
		-- Core's catch toast: its text is the fish's name, with no stamp.
		look.before = ns.L.TOAST_VARIETY_BEFORE:format(headline.text --[[@as string]])
	elseif headline.ownStamp then
		-- Its own toast (VAR-R28): the fish's name, then the variety's, and its own stamp.
		look.stamp = headline.stamp or headline.title
		local fish = moment.variety.fish
		look.before = fish and ns.L.TOAST_VARIETY_BEFORE:format(fish) or ""
	elseif headline.text then
		look.before = ""
	end
	return look
end

--- A toast's kicker, the printed line over its name: its headline's title, or for a variety's own toast (an `ownStamp`
--- headline, VAR-R28) the Catch's size text, "{band} · {length}", when the moment gives one (the title is then its
--- stamp). Only a toast's is drawn this way: the title still names the moment everywhere else.
---@param headline PagleRaisedMoment
---@return string
function ns.ToastKicker(headline)
	return headline.ownStamp and headline.kicker or headline.title
end
