---@class PagleNS
local ns = select(2, ...)

-- The toast styles and the announcement art's choices (announcements.md › Toast styles, › UI, ANN-R80;
-- wallet-and-shop.md › SHOP-R25), as data keyed by Core's toast style good IDs. The look is the announcements art
-- kit's: a toast is a fresh entry in the Angler's ledger, a torn page on a leather spine, written in ink. Torn Page is
-- the free default and the kit's Ledger style; Ripple and Lantern Glow are Curio Shop goods, the kit's Ripple and
-- Lantern styles. A style picks the toast and Nod art (its own atlas, data/AnnounceArt.lua), the medallions' trim,
-- the rubber stamps' ink and the page's inks; the banner, the splash and the cards look the same in every style. A
-- style changes only the look, never timing, lanes, the Interruption budget, sounds or which moments show.
-- adapter/Art.lua draws the art, and adapter/Announcements.lua and adapter/Cards.lua the frames.

-- An { r, g, b } from a "RRGGBB" hex string.
---@param hex string
---@return number[]
local function rgb(hex)
	local out = {}
	for i = 1, 5, 2 do
		out[#out + 1] = tonumber(hex:sub(i, i + 1), 16) / 255
	end
	return out
end

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

--- A toast style: its toast and Nod atlas, the medallions' trim (a toast.high's own), the rubber stamp sprite and its
--- ink, and the page's kicker and name inks, each a role in ns.ANNOUNCE_COLORS.
---@class PagleToastStyle
---@field id string
---@field atlas string
---@field trim "gold"|"silver"|"bronze"
---@field highTrim "gold"|"silver"|"bronze"
---@field stamp string
---@field stampInk string
---@field what string
---@field name string

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

--- The style a toast style good ID draws in: its own, or Torn Page for any other ID, or none (ANN-R80): before Core's
--- slot is registered, GetEquipped has no good for it.
---@param goodID any
---@return PagleToastStyle
function ns.ToastStyleOf(goodID)
	return ns.TOAST_STYLES[goodID] or ns.TOAST_STYLES[ns.TOAST_STYLE_DEFAULT]
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
--- or one of the pressed marks, the waves when the headline names none.
---@param headline PagleMoment
---@return { number: integer?, crest: boolean?, mark: string? }
function ns.BannerSeal(headline)
	local seal = headline.seal
	if type(seal) == "number" then
		return { number = seal }
	elseif seal == "crest" then
		return { crest = true }
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
