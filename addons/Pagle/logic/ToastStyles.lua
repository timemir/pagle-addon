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
	pencil = rgb("4A4844"), -- toast.low's kicker, the old record, "+N more"
	pencilName = rgb("3E3C38"), -- toast.low's name
	amt = rgb("7A5410"), -- the Coins beside a coin
	amtLow = rgb("6A6458"), -- toast.low's Coins
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
--- kicker and name, the Coins', toast.high's kicker and toast.low's, each the ledger's own where the style has none
--- (ns.ToastInks), and the tint of toast.high's wax, over its grey with `waxDesaturated`.
---@class PagleToastStyle
---@field id string
---@field atlas string
---@field ring? true                       -- its own ring, `bezel-<size>` in its atlas (ANN-R81), for the trims
---@field trim? "gold"|"silver"|"bronze"   -- the shared trims, for a style without a ring
---@field highTrim? "gold"|"silver"|"bronze"
---@field stamp string
---@field stampInk string
---@field what string
---@field name string
---@field amt? string
---@field highWhat? string
---@field lowWhat? string
---@field lowName? string
---@field lowAmt? string
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
		inks = { what = "1F3A5A", name = "14202E", stampInk = "1F3A6A", amt = "7A5410", wax = "47AEFF" },
		waxDesaturated = true,
	},
	-- Peeled bark tied with twine.
	{
		id = "core.toaststyle.birch",
		atlas = "ToastsBirch",
		stamp = "stamp-blue",
		inks = { what = "6A3A1A", name = "2A1A0A", stampInk = "3A5A2A", amt = "7A5410", wax = "BBD062" },
		waxDesaturated = true,
	},
	-- Sand in the fold, a shell left behind.
	{
		id = "core.toaststyle.tidepool",
		atlas = "ToastsTidepool",
		stamp = "stamp-blue",
		inks = { what = "1F5A5A", name = "102A2A", stampInk = "1F6A6A", amt = "7A5410", wax = "56FFCF" },
		waxDesaturated = true,
	},
	-- Soundings, rhumb lines and a compass rose; the red wax as it is.
	{
		id = "core.toaststyle.chart",
		atlas = "ToastsChart",
		stamp = "stamp",
		inks = { what = "8A1A10", name = "1A1408", stampInk = "8A1A10", amt = "7A5410" },
	},
	-- Rime grown in from the corners.
	{
		id = "core.toaststyle.frost",
		atlas = "ToastsFrost",
		stamp = "stamp-blue",
		inks = { what = "2A5A8A", name = "0E2440", stampInk = "2A6AA0", amt = "7A5410", wax = "77D9FF" },
		waxDesaturated = true,
	},
	-- Ticker tape, rivets and a gear.
	{
		id = "core.toaststyle.goblin",
		atlas = "ToastsGoblin",
		stamp = "stamp-blue",
		inks = { what = "1A6A2A", name = "102010", stampInk = "2A7A2A", amt = "7A5410", wax = "68FF3F" },
		waxDesaturated = true,
	},
	-- A kelp-wrapped spine studded with pearls.
	{
		id = "core.toaststyle.kelp",
		atlas = "ToastsKelp",
		stamp = "stamp-blue",
		inks = { what = "2A6A5A", name = "142A24", stampInk = "1E5A4E", amt = "7A5410", wax = "7AFFBF" },
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
			lowWhat = "C8D0E8",
			lowName = "E8ECF8",
			lowAmt = "C8D0E8",
			wax = "58A3FF",
		},
		waxDesaturated = true,
	},
	-- One great leaf, pressed and dried gold.
	{
		id = "core.toaststyle.leaf",
		atlas = "ToastsLeaf",
		stamp = "stamp",
		inks = { what = "3A5A10", name = "1A2A06", stampInk = "8A3A10", amt = "7A5410", wax = "FF9621" },
		waxDesaturated = true,
	},
	-- Rolled up and corked: Driftglass Bottle.
	{
		id = "core.toaststyle.bottle",
		atlas = "ToastsBottle",
		stamp = "stamp-blue",
		inks = { what = "6A2A10", name = "2A1408", stampInk = "1F4A7A", amt = "7A5410", wax = "FF631F" },
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
			lowWhat = "3A1E06",
			lowName = "1E1004",
			lowAmt = "3A1E06",
			wax = "FF803C",
		},
		waxDesaturated = true,
	},
	-- Gold leaf, lapis and vermilion; the red wax as it is.
	{
		id = "core.toaststyle.folio",
		atlas = "ToastsFolio",
		stamp = "stamp",
		inks = { what = "9A1A10", name = "1A1030", stampInk = "A8781A", amt = "7A5410", highWhat = "E8B830" },
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
			lowWhat = "E8C890",
			lowName = "FBEFD0",
			lowAmt = "E8C890",
			wax = "D9D9D9",
		},
	},
	-- A page that was nearly kindling once (the Tackle Board's, TKB-R126).
	{
		id = "tackleboard.toaststyle.ember",
		atlas = "ToastsEmber",
		stamp = "stamp",
		inks = { what = "8A2A08", name = "1E0E04", stampInk = "C0400A", amt = "7A5410", wax = "FF4300" },
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

--- The inks a style writes in on `page` (ANN-R80, ANN-R81), each a role in ns.ANNOUNCE_COLORS: the kicker, the name
--- and the Coins. toast.low is in pencil and toast.high's kicker gilt, unless the style has its own; with no page, the
--- Nod's.
---@param style PagleToastStyle
---@param page PagleToastPage?
---@return { what: string, name: string, amt: string }
function ns.ToastInks(style, page)
	if page and page.low then
		return { what = style.lowWhat or "pencil", name = style.lowName or "pencilName", amt = style.lowAmt or "amtLow" }
	end
	return {
		what = page and page.high and (style.highWhat or "giltDeep") or style.what,
		name = style.name,
		amt = style.amt or "amt",
	}
end

--- A toast's page: its art (the sprite "toast-<page>" in the style's atlas) and its layout, in UI units: its size, the
--- medallion's size and left, the words' left and top, and the coin's size. `low` is pencil, `high` gilt and wax.
---@class PagleToastPage
---@field page string
---@field w number
---@field h number
---@field bezel number
---@field bx number
---@field tx number
---@field ty number
---@field coin number
---@field low boolean?
---@field high boolean?
---@field ruled boolean?
---@field digest boolean?

---@type table<string, PagleToastPage>
local PAGES = {
	["low"] = { page = "low", w = 404, h = 74, bezel = 64, bx = 6, tx = 86, ty = 10, coin = 30, low = true },
	["low-ruled"] = {
		page = "low-ruled",
		w = 470,
		h = 122,
		bezel = 64,
		bx = 6,
		tx = 86,
		ty = 10,
		coin = 30,
		low = true,
		ruled = true,
	},
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

--- The page a toast is drawn on (announcements.md › UI): "While you were fighting" on the digest page; a headline with
--- a record ruler on a ruled page (a toast.high's on toast's, the high page having no room for one); else by its
--- rung, toast.low on the pencil page and toast.high on the gilt one.
---@param announcement PagleAnnouncement
---@return PagleToastPage
function ns.ToastPage(announcement)
	if announcement.fighting then
		return PAGES.digest
	end
	local rung, ruled = announcement.headline.rung, announcement.headline.ruler ~= nil
	if rung == "toast.low" then
		return ruled and PAGES["low-ruled"] or PAGES.low
	elseif rung == "toast.high" and not ruled then
		return PAGES.high
	end
	return ruled and PAGES["toast-ruled"] or PAGES.toast
end

--- What a banner's wax seal shows (announcements.md › Contracts, `seal`): a number pressed into it, the Prestige crest,
--- or one of the pressed marks, the waves when the headline names none. With `crest`, a crest good's icon (a fish
--- crest, VAR-R25) shows in the Prestige crest's place, without the Angler's portrait: `icon`.
---@param headline PagleMoment
---@return { number: integer?, crest: boolean?, icon: (integer|string)?, mark: string? }
function ns.BannerSeal(headline)
	local seal = headline.seal
	if type(seal) == "number" then
		return { number = seal }
	elseif seal == "crest" then
		return { crest = true, icon = headline.crest }
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
-- head is a square at its left, inset from its snout (VAR-R26 crops the catch Nod's medallion the same way). As
-- shares of the art's width and height.
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

--- How a catch Nod draws the variety its line names (VAR-R26): the name and the line either side of it, the rarity's
--- colour for the gem before the name and its ink for the name (these two alone leave the style's ink, ANN-R80), the
--- colour for the medallion's ring, none for Common, whose ring stays the style's, and whether its strip gleams as it
--- enters.
---@class PagleNodVarietyLook
---@field name string
---@field before string
---@field after string
---@field color number[]
---@field ink number[]
---@field ring number[]?
---@field gleam boolean

-- The rarities whose catch Nod gleams as it enters (VAR-R26), and the one whose ring stays the style's.
local GLEAMS = { rare = true, epic = true }
local PLAIN_RING = "common"

--- A catch Nod's variety as it is drawn (VAR-R26), or nil for a headline that isn't Core's catch Nod naming one, or
--- one of a rarity Core doesn't know.
---@param headline { catchNod: true?, variety: PagleNodVariety? }
---@return PagleNodVarietyLook?
function ns.CatchNodVarietyLook(headline)
	local variety = headline.catchNod and headline.variety
	if not variety then
		return nil
	end
	for _, rarity in ipairs(ns.VARIETY_RARITIES) do
		if rarity.key == variety.rarity then
			return {
				name = variety.name,
				before = variety.before,
				after = variety.after,
				color = rarity.color,
				ink = rarity.ink,
				ring = rarity.key ~= PLAIN_RING and rarity.color or nil,
				gleam = GLEAMS[rarity.key] == true,
			}
		end
	end
	return nil
end
