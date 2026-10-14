-- The toast styles on the client, through the real TOC (announcements.md › Toast styles, ANN-R80; wallet-and-shop.md
-- › SHOP-R25, SHOP-R33, › UI): the toast, Nod, banner, splash and card frames are drawn in the equipped style, follow
-- AppearanceChanged, and a sample toast draws in any style. Each frame's textures and colours are asserted, not pixels.

local TIMBER = "core.toaststyle.timber"
local RIPPLE = "core.toaststyle.ripple"
local LANTERN = "core.toaststyle.lanternglow"
local MARBLE = "Interface\\FrameGeneral\\UI-Background-Marble"
local PING = "Interface\\Cooldown\\ping4"
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MORPHEUS = "Fonts\\MORPHEUS.TTF"

-- Core's toast style slot and goods as SHOP-R25 lists them, registered here unless Core already has them (Core's own
-- goods register them at login).
local function registerStyles(loaded)
	local ns = loaded.ns
	if ns.goods:Good(TIMBER) then
		return
	end
	ns.RegisterCoreSlot({ id = "core.toaststyle", label = "Toast style", category = "Announcements" })
	ns.RegisterCoreGood({ id = TIMBER, slot = "core.toaststyle", name = "Timber", default = true })
	ns.RegisterCoreGood({ id = RIPPLE, slot = "core.toaststyle", name = "Ripple", tier = 1 })
	ns.RegisterCoreGood({ id = LANTERN, slot = "core.toaststyle", name = "Lantern Glow", tier = 2 })
end

-- A summary card for PagleDB.global.cards, with one Ledger moment.
local function storedCard()
	local moment = { module = "Ledger", moduleTitle = "Ledger", moduleOrder = 10, kind = "x", rung = "toast" }
	moment.title = "New Species"
	return {
		title = "Fishing session",
		numbers = { casts = 3, catches = 3, gotAway = 0, seconds = 600 },
		coins = 0,
		lines = {},
		moments = { { module = "Ledger", title = "Ledger", order = 10, moments = { moment } } },
	}
end

-- Core logged in on Forever over Ada's log, in which she bought Ripple and Lantern Glow, with the Ledger registered
-- and, unless `unregistered`, the toast styles. With `card`, a stored summary card shows at login.
local function styledCore(options)
	options = options or {}
	local entries = history(2)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, RIPPLE, 150)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1900, LANTERN, 400)
	local loaded = loadCore(entries, options.card and { global = { cards = { storedCard() } } } or nil)
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	if not options.unregistered then
		registerStyles(loaded)
	end
	enterWorld(loaded, 3)
	loaded.client.runTimers()
	return loaded, M
end

-- Raises one moment on `rung` and runs the frame Core shows it on.
local function raise(loaded, M, rung, title)
	M:RaiseMoment({ rung = rung, kind = "spec", title = title or rung, text = "Nightfin Snapper", coins = 5 })
	loaded.client.advance(0)
end

local function equip(loaded, goodID)
	assert.is_true(loaded.env.Pagle.SetEquipped("core.toaststyle", goodID))
end

-- A frame's look: what a style changes, read from its textures and font strings.
local function lookOf(frame)
	local skin = frame.skin
	local look = {
		background = skin.background.color,
		edge = skin.edges[1].color,
		backdrop = skin.backdrop.shown and skin.backdrop.texture or false,
		glow = skin.glow[1] and skin.glow[1].shown and skin.glow[1].texture or false,
		title = frame.title.textColor,
		titleFont = frame.title.font and frame.title.font[1] or frame.title.fontObject,
	}
	if frame.stamps then
		look.stamp, look.coins = frame.stamps[1].background.color, frame.coins.background.color
		look.text = frame.text.textColor
	end
	return look
end

-- The five frames: the toast, Nod, banner and splash Core has drawn, and the card frame.
local function framesOf(loaded)
	local frames = loaded.ns.announcementFrames
	return { frames.toast, frames.nod, frames.banner, frames.splash, loaded.ns.cardFrame }
end

-- Shows a toast, a Nod, a banner and a splash in turn, each until it goes.
local function showEveryForm(loaded, M)
	raise(loaded, M, "toast")
	loaded.client.advance(6)
	raise(loaded, M, "nod")
	loaded.client.advance(3)
	raise(loaded, M, "banner")
	loaded.client.advance(4)
	raise(loaded, M, "splash")
	loaded.ns.announcementFrames.splash:Click()
end

describe("the frames' toast style", function()
	it("is Timber, M2's look, while Core's toast style slot isn't registered (ANN-R80)", function()
		local loaded, M = styledCore({ unregistered = true })

		raise(loaded, M, "toast")

		assert.are.same({
			background = { 0.16, 0.11, 0.07, 0.94 },
			edge = { 0.54, 0.42, 0.25, 1 },
			backdrop = false,
			glow = false,
			title = { 1, 0.82, 0 },
			titleFont = "GameFontNormalLarge",
			text = { 1, 1, 1 },
			stamp = { 0.70, 0.13, 0.10, 1 },
			coins = { 0.63, 0.47, 0, 1 },
		}, lookOf(loaded.ns.announcementFrames.toast))
	end)

	it("draws a toast in Ripple once Ripple is equipped: its water, rings and colours (ANN-R80, SHOP-R33)", function()
		local loaded, M = styledCore()
		equip(loaded, RIPPLE)

		raise(loaded, M, "toast")

		local toast = loaded.ns.announcementFrames.toast
		assert.are.same({
			background = { 0.05, 0.16, 0.21, 0.94 },
			edge = { 0.37, 0.71, 0.84, 1 },
			backdrop = MARBLE,
			glow = PING,
			title = { 0.75, 0.92, 1 },
			titleFont = "GameFontNormalLarge",
			text = { 0.92, 0.97, 1 },
			stamp = { 0.10, 0.43, 0.58, 1 },
			coins = { 0.70, 0.55, 0.10, 1 },
		}, lookOf(toast))
		assert.are.same(
			{ "ADD", { 0.55, 0.86, 1, 0.25 } },
			{ toast.skin.glow[1].blendMode, toast.skin.glow[1].vertexColor }
		)
	end)

	it(
		"draws a Nod, a banner, a splash and a card in Ripple, and AppearanceChanged back to Timber repaints all five"
			.. " as a Timber login draws them (ANN-R80, SHOP-R33)",
		function()
			local timber, timberM = styledCore({ card = true })
			showEveryForm(timber, timberM)
			local loaded, M = styledCore({ card = true })
			equip(loaded, RIPPLE)

			showEveryForm(loaded, M)

			local nod, banner, splash, card = unpack(framesOf(loaded), 2)
			assert.are.same(
				{ { 0.05, 0.16, 0.21, 0.94 }, PING, { 0.75, 0.92, 1 } },
				{ lookOf(nod).background, lookOf(nod).glow, lookOf(nod).title }
			)
			assert.are.same(
				{ { 0.02, 0.08, 0.11, 0.7 }, MARBLE, { 0.10, 0.43, 0.58, 1 } },
				{ lookOf(banner).background, lookOf(banner).backdrop, lookOf(banner).stamp }
			)
			assert.are.same(
				{ { 0.06, 0.19, 0.25, 1 }, { 0.37, 0.71, 0.84, 1 }, { 0.55, 0.86, 1 }, { 0.85, 0.95, 1 } },
				{ lookOf(splash).background, lookOf(splash).edge, lookOf(splash).title, lookOf(splash).text }
			)
			assert.are.same({
				background = { 0.05, 0.16, 0.21, 0.94 },
				edge = { 0.37, 0.71, 0.84, 1 },
				backdrop = MARBLE,
				glow = false,
				title = { 0.75, 0.92, 1 },
				titleFont = "GameFontNormalLarge",
			}, lookOf(card))

			equip(loaded, TIMBER)

			for i, frame in ipairs(framesOf(timber)) do
				assert.are.same(lookOf(frame), lookOf(framesOf(loaded)[i]))
			end
		end
	)

	it("repaints a toast on screen at once when the style changes, keeping it on screen (ANN-R80, SHOP-R33)", function()
		local loaded, M = styledCore()
		raise(loaded, M, "toast")
		local toast = loaded.ns.announcementFrames.toast

		equip(loaded, LANTERN)

		assert.are.same(
			{ true, { 0.11, 0.06, 0.02, 0.95 }, DISC, MORPHEUS, { 1, 0.78, 0.42 } },
			{ toast.shown, lookOf(toast).background, lookOf(toast).glow, lookOf(toast).titleFont, lookOf(toast).title }
		)
		assert.are.same({ MORPHEUS, 19, "" }, toast.title.font)
		loaded.client.advance(6)
		assert.is_false(toast.shown)
	end)
end)