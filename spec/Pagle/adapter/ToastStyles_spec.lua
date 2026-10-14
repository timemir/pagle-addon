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

-- Core logged in on Forever over Ada's log, in which she bought Ripple and Lantern Glow, with the Ledger registered;
-- Core registers its toast styles at login (SHOP-R25). With `card`, a stored summary card shows at login; with
-- `picked`, that is the stored toast style pick.
local function styledCore(options)
	options = options or {}
	local entries = history(2)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, RIPPLE, 150)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1900, LANTERN, 400)
	local saved = {
		global = options.card and { cards = { storedCard() } } or nil,
		profiles = options.picked and { Default = { appearance = { ["core.toaststyle"] = options.picked } } } or nil,
	}
	local loaded = loadCore(entries, saved)
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
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
	it("is Timber, M2's look, at login: the slot's default (ANN-R80, SHOP-R25)", function()
		local loaded, M = styledCore()

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

	it("is Timber for a stored pick that is no toast style (ANN-R80, SHOP-R32)", function()
		local loaded, M = styledCore({ picked = "core.toaststyle.moonlit" })

		raise(loaded, M, "toast")

		assert.are.same({ { 0.16, 0.11, 0.07, 0.94 }, false, { 1, 0.82, 0 } }, {
			lookOf(loaded.ns.announcementFrames.toast).background,
			lookOf(loaded.ns.announcementFrames.toast).glow,
			lookOf(loaded.ns.announcementFrames.toast).title,
		})
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
describe("a toast style change", function()
	-- What shows over 40 s from a burst of moments, sampled each half second as "<s> <form>: <title>", and the sounds
	-- played: three toasts and a banner, a Nod while the slot is busy, four more toasts (two past the 2 that wait),
	-- then, with the budget spent, a toast.low and a splash.
	local function timeline(style)
		local loaded, M = styledCore()
		if style then
			equip(loaded, style)
		end
		for i = 1, 3 do
			M:RaiseMoment({ rung = "toast", kind = "spec", title = "Toast " .. i })
		end
		M:RaiseMoment({ rung = "banner", kind = "spec", title = "Level 12" })
		loaded.client.advance(0)
		local seen = {}
		local function sample(step)
			for _, form in ipairs({ "toast", "nod", "banner", "splash" }) do
				local frame = loaded.ns.announcementFrames[form]
				if frame and frame.shown then
					seen[#seen + 1] = ("%.1f %s: %s"):format(step / 2, form, frame.title:GetText())
				end
			end
		end
		for step = 1, 80 do
			if step == 30 then
				raise(loaded, M, "nod", "New here")
			elseif step == 40 then
				for i = 4, 7 do
					raise(loaded, M, "toast", "Toast " .. i)
				end
			elseif step == 69 then
				raise(loaded, M, "toast.low", "Size record")
			elseif step == 70 then
				raise(loaded, M, "splash", "Legend")
			end
			loaded.client.advance(0.5)
			sample(step)
		end
		return seen, loaded.client.sounds
	end

	it(
		"leaves the lanes, the timing, the Interruption budget and the sounds as they were: the same Announcements show"
			.. " in the same order with the same sounds (ANN-R80, ANN-R20, ANN-R31, ANN-R72)",
		function()
			local timberSeen, timberSounds = timeline()

			for _, style in ipairs({ RIPPLE, LANTERN }) do
				local seen, sounds = timeline(style)
				assert.are.same(timberSeen, seen)
				assert.are.same(timberSounds, sounds)
			end
			local DRIFTWOOD = "Interface\\AddOns\\Pagle\\media\\sounds\\driftwood\\"
			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "banner.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				DRIFTWOOD .. "toast_3.ogg SFX",
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				"Interface\\AddOns\\Pagle\\media\\sounds\\legend.ogg SFX",
			}, timberSounds)
			assert.are.same(
				{ "5.5 toast: Toast 1", "6.0 banner: Level 12", "34.5 nod: Size record", "35.0 splash: Legend" },
				{ timberSeen[11], timberSeen[12], timberSeen[68], timberSeen[70] }
			)
		end
	)
end)
describe("the sample toast", function()
	-- A stage frame as the Curio Shop hands a good's preview, and a spy on the Session summary: each moment Core
	-- hands it, in order.
	local function stageOf(loaded)
		local summarized = {}
		function loaded.ns.summary.Add(_, moment)
			summarized[#summarized + 1] = moment
		end
		return loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent), summarized
	end

	-- The texts of a frame's stamps on show, then its Coins stamp's.
	local function stampsOf(frame)
		local texts = {}
		for _, stamp in ipairs(frame.stamps) do
			if stamp.shown then
				texts[#texts + 1] = stamp.label:GetText()
			end
		end
		texts[#texts + 1] = frame.coins.shown and frame.coins.label:GetText() or nil
		return texts
	end

	it(
		"draws on a given frame in a given style, Timber still equipped, with nothing shown, played or summarized"
			.. " (ANN-R80, wallet-and-shop.md › UI)",
		function()
			local loaded = styledCore()
			local stage, summarized = stageOf(loaded)

			local sample = loaded.ns.DrawSampleToast(stage, RIPPLE)

			assert.are.equal(stage, sample:GetParent())
			assert.are.same(
				{ true, "New Species", "A sample toast", 136245 },
				{ sample.shown, sample.title:GetText(), sample.text:GetText(), sample.icon.texture }
			)
			assert.are.same({ "New here", "+5 |TInterface\\MoneyFrame\\UI-GoldIcon:0|t" }, stampsOf(sample))
			assert.are.same({ { 0.37, 0.71, 0.84, 1 }, PING }, { lookOf(sample).edge, lookOf(sample).glow })
			assert.are.same({ {}, {}, nil }, { summarized, loaded.client.sounds, loaded.ns.announcementFrames.toast })
			assert.are.equal(TIMBER, loaded.env.Pagle.GetEquipped("core.toaststyle"))
		end
	)

	it(
		"redraws the same frame on the same stage in the next style asked for, Timber for an unknown one (ANN-R80)",
		function()
			local loaded = styledCore()
			local stage = stageOf(loaded)
			local first = loaded.ns.DrawSampleToast(stage, LANTERN)

			local again = loaded.ns.DrawSampleToast(stage, "core.toaststyle.moonlit")

			assert.are.equal(first, again)
			assert.are.same(
				{ { 0.16, 0.11, 0.07, 0.94 }, false, "GameFontNormalLarge" },
				{ lookOf(again).background, lookOf(again).glow, lookOf(again).titleFont }
			)
		end
	)

	it(
		"shows on screen through the real lanes in its own style, with the toast's sound, never reaching the Session"
			.. " summary; the next toast is in the equipped style again (ANN-R80, ANN-R20, ANN-R25)",
		function()
			local loaded, M = styledCore()
			local _, summarized = stageOf(loaded)

			loaded.ns.ShowSampleToast(LANTERN)

			local toast = loaded.ns.announcementFrames.toast
			assert.are.same(
				{ true, "New Species", { 0.85, 0.47, 0.16, 1 } },
				{ toast.shown, toast.title:GetText(), lookOf(toast).edge }
			)
			assert.are.same(
				{ "Interface\\AddOns\\Pagle\\media\\sounds\\driftwood\\toast_1.ogg SFX" },
				loaded.client.sounds
			)
			equip(loaded, RIPPLE)
			assert.are.same({ 0.85, 0.47, 0.16, 1 }, lookOf(toast).edge)
			loaded.client.advance(6)
			assert.is_false(toast.shown)
			raise(loaded, M, "toast", "New Species")
			assert.are.same({ 0.37, 0.71, 0.84, 1 }, lookOf(toast).edge)
			assert.are.same({ "New Species" }, { summarized[1].title, summarized[2] })
		end
	)

	it(
		"is each toast style good's preview: the sample on the stage in that style and Show on screen, which shows it"
			.. " (wallet-and-shop.md › UI, ANN-R80, SHOP-R25)",
		function()
			local loaded = styledCore()
			local stage, summarized = stageOf(loaded)

			loaded.ns.goods:Good(RIPPLE).preview(stage)

			local panel = stage.children[1]
			local sample, button = panel.children[1], panel.children[2]
			assert.are.same(
				{ true, "New Species", MARBLE },
				{ panel.shown, sample.title:GetText(), lookOf(sample).backdrop }
			)
			assert.are.same({ true, "Show on screen" }, { button.shown, button:GetText() })
			loaded.ns.goods:Good(LANTERN).preview(stage)
			assert.are.same({ sample, DISC }, { panel.children[1], lookOf(sample).glow })
			button:Click()
			local toast = loaded.ns.announcementFrames.toast
			assert.are.same({ true, DISC, {} }, { toast.shown, lookOf(toast).glow, summarized })
		end
	)

	it(
		"hides behind another of Core's previews on the same stage, and comes back (wallet-and-shop.md › UI)",
		function()
			local loaded = styledCore()
			local stage = stageOf(loaded)
			loaded.ns.goods:Good(TIMBER).preview(stage)
			local panel = stage.children[1]

			loaded.ns.goods:Good("core.crest.crest1").preview(stage)
			assert.is_false(panel.shown)
			loaded.ns.goods:Good(RIPPLE).preview(stage)

			assert.are.same({ true, false }, { panel.shown, stage.children[2].shown })
		end
	)
end)
