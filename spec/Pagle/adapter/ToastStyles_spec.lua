-- The toast styles on the client, through the real TOC (announcements.md › Toast styles, › UI, ANN-R80;
-- wallet-and-shop.md › SHOP-R25, SHOP-R33, › UI): the toast and Nod are drawn from the equipped style's atlas with its
-- medallions, stamps and inks, follow AppearanceChanged, and a sample toast draws in any style; the banner, splash and
-- card look the same in every style. Each frame's sprites and inks are asserted, not pixels.

local TORN_PAGE = "core.toaststyle.page"
local RIPPLE = "core.toaststyle.ripple"
local LANTERN = "core.toaststyle.lanternglow"

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

-- Raises one moment on `rung` with a stamp riding on it, and runs the frame Core shows it on.
local function raise(loaded, M, rung, title)
	M:RaiseMoment({ rung = rung, kind = "spec", title = title or rung, text = "Nightfin Snapper", coins = 5 })
	M:RaiseMoment({ rung = "nod", kind = "spec", title = "New here", cast = nil })
	loaded.client.advance(0)
end

-- Raises a toast with a stamp, both on one Cast, so the stamp rides on it.
local function raiseStamped(loaded, M)
	local cast = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
	M:RaiseMoment({ rung = "toast", kind = "spec", title = "New Species", text = "Nightfin Snapper", cast = cast })
	M:RaiseMoment({ rung = "nod", kind = "spec", title = "New here", cast = cast, coins = 5 })
	loaded.client.advance(0)
end

local function equip(loaded, goodID)
	assert.is_true(loaded.env.Pagle.SetEquipped("core.toaststyle", goodID))
end

-- The "<atlas> <sprite>" a texture shows, found by its file and texture coordinates in data/AnnounceArt.lua.
local function spriteOf(loaded, texture)
	for atlasName, atlas in pairs(loaded.ns.ATLASES) do
		if texture.texture == atlas.file and texture.texCoord then
			for name, sprite in pairs(atlas.sprites) do
				local left, top = sprite.x / atlas.width, sprite.y / atlas.height
				if math.abs(texture.texCoord[1] - left) < 1e-9 and math.abs(texture.texCoord[3] - top) < 1e-9 then
					return atlasName .. " " .. name
				end
			end
		end
	end
	return nil
end

-- A toast's or Nod's look: what a style changes, read from its sprites and inks.
local function lookOf(loaded, frame)
	local stamp = frame.stamps[1]
	return {
		page = spriteOf(loaded, frame.page or frame.strip.left),
		trim = spriteOf(loaded, frame.bezel.Ring),
		stamp = stamp.shown and spriteOf(loaded, stamp.border.left) or false,
		title = frame.title.textColor,
		text = frame.text.textColor,
	}
end

-- An ink of the palette as a font string's text colour reads back.
local function ink(loaded, role)
	local color = loaded.ns.ANNOUNCE_COLORS[role]
	return { color[1], color[2], color[3] }
end

describe("the toast's and Nod's toast style", function()
	it(
		"is Torn Page, the ledger page with brass and red ink, at login: the slot's default (ANN-R80, SHOP-R25)",
		function()
			local loaded, M = styledCore()

			raiseStamped(loaded, M)

			assert.are.same({
				page = "ToastsLedger toast-toast",
				trim = "Announce bezel-gold-84",
				stamp = "Announce stamp",
				title = ink(loaded, "red"),
				text = ink(loaded, "ink"),
			}, lookOf(loaded, loaded.ns.announcementFrames.toast))
		end
	)

	it("is Torn Page for a stored pick that is no toast style (ANN-R80, SHOP-R32)", function()
		local loaded, M = styledCore({ picked = "core.toaststyle.moonlit" })

		raiseStamped(loaded, M)

		assert.are.equal("ToastsLedger toast-toast", lookOf(loaded, loaded.ns.announcementFrames.toast).page)
	end)

	it("draws a toast in Ripple once Ripple is equipped: its page, silver, blue stamps and inks (ANN-R80)", function()
		local loaded, M = styledCore()
		equip(loaded, RIPPLE)

		raiseStamped(loaded, M)

		local toast = loaded.ns.announcementFrames.toast
		assert.are.same({
			page = "ToastsRipple toast-toast",
			trim = "Announce bezel-silver-84",
			stamp = "Announce stamp-blue",
			title = ink(loaded, "rippleWhat"),
			text = ink(loaded, "rippleInk"),
		}, lookOf(loaded, toast))
		assert.are.same(ink(loaded, "rippleStamp"), toast.stamps[1].label.textColor)
	end)

	it("draws a Nod's strip from the equipped style's atlas (ANN-R80)", function()
		local loaded, M = styledCore()
		equip(loaded, LANTERN)

		raise(loaded, M, "nod")

		local nod = loaded.ns.announcementFrames.nod
		assert.are.same(
			{ "ToastsLantern nod-strip", "Announce bezel-gold-34" },
			{ lookOf(loaded, nod).page, lookOf(loaded, nod).trim }
		)
	end)

	it("redraws a toast on screen at once when the style changes, keeping it on screen (ANN-R80, SHOP-R33)", function()
		local loaded, M = styledCore()
		raiseStamped(loaded, M)
		local toast = loaded.ns.announcementFrames.toast

		equip(loaded, LANTERN)

		assert.are.same(
			{ true, "ToastsLantern toast-toast", ink(loaded, "lanternWhat"), "NEW SPECIES" },
			{ toast.shown, lookOf(loaded, toast).page, lookOf(loaded, toast).title, toast.title:GetText() }
		)
		loaded.client.advance(8.7 + 0.4) -- it settles, stays its 6 s and leaves
		assert.is_false(toast.shown)
	end)

	it("keeps a record ruler counting through a style change on screen (ANN-R22, ANN-R80)", function()
		local loaded, M = styledCore()
		M:RaiseMoment({
			rung = "toast",
			kind = "spec",
			title = "Trophy weight",
			text = "Raw Glossy Mightfish",
			ruler = { old = 10, new = 12, unit = "lb", label = "weight" },
		})
		loaded.client.advance(0)
		local view = loaded.ns.announcementFrames.toast.ruler
		loaded.client.update(1)

		equip(loaded, RIPPLE)
		loaded.client.update(0.5 + loaded.ns.RULER_STAMP_DELAY)

		assert.are.same({ true, "+2.0 lb", true }, { view.margin.shown, view.margin:GetText(), view.record.shown })
		assert.are.equal("Announce stamp-blue", spriteOf(loaded, view.record.border.left))
	end)

	it("leaves the banner, the splash and the card as they look in Torn Page (announcements.md › UI)", function()
		local function looks(style)
			local loaded, M = styledCore({ card = true })
			if style then
				equip(loaded, style)
			end
			raise(loaded, M, "banner")
			local banner = loaded.ns.announcementFrames.banner
			loaded.client.advance(5.9 + 0.5) -- the banner's stay, and its leaving
			raise(loaded, M, "splash")
			local splash = loaded.ns.announcementFrames.splash
			return {
				seal = spriteOf(loaded, banner.seal),
				bannerTitle = banner.title.textColor,
				splashTitle = splash.title.textColor,
				card = loaded.ns.cardFrame.title.textColor,
			}
		end

		assert.are.same(looks(), looks(RIPPLE))
		assert.are.same(looks(), looks(LANTERN))
	end)
end)

describe("a toast style change", function()
	-- What shows over 40 s from a burst of moments, sampled each half second as "<s> <form>: <headline title>", and
	-- the sounds played: three toasts and a banner, a Nod while a toast shows, four more toasts (two past the 2 that
	-- wait), then, with the budget spent, a toast.low and a splash.
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
			local lines = {}
			for _, frame in ipairs(loaded.ns.AnnouncementFramesShowing()) do
				local display = frame.display --[[@as table]]
				lines[#lines + 1] = ("%.1f %s: %s"):format(step / 2, display.form, display.announcement.headline.title)
			end
			table.sort(lines)
			for _, line in ipairs(lines) do
				seen[#seen + 1] = line
			end
		end
		for step = 1, 80 do
			if step == 30 then
				M:RaiseMoment({ rung = "nod", kind = "spec", title = "New here" })
				loaded.client.advance(0)
			elseif step == 40 then
				for i = 4, 7 do
					M:RaiseMoment({ rung = "toast", kind = "spec", title = "Toast " .. i })
					loaded.client.advance(0)
				end
			elseif step == 69 then
				M:RaiseMoment({ rung = "toast.low", kind = "spec", title = "Size record" })
				loaded.client.advance(0)
			elseif step == 70 then
				M:RaiseMoment({ rung = "splash", kind = "spec", title = "Legend" })
				loaded.client.advance(0)
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
			local tornPageSeen, tornPageSounds = timeline()

			for _, style in ipairs({ RIPPLE, LANTERN }) do
				local seen, sounds = timeline(style)
				assert.are.same(tornPageSeen, seen)
				assert.are.same(tornPageSounds, sounds)
			end
			local DRIFTWOOD = "Interface\\AddOns\\Pagle\\media\\sounds\\driftwood\\"
			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				DRIFTWOOD .. "toast_3.ogg SFX",
				DRIFTWOOD .. "banner.ogg SFX",
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				DRIFTWOOD .. "toast_3.ogg SFX",
				DRIFTWOOD .. "toast_1.ogg SFX",
				"Interface\\AddOns\\Pagle\\media\\sounds\\legend.ogg SFX",
			}, tornPageSounds)
			-- When each first shows: three toasts and the banner together; the Nod in the column; three more toasts,
			-- the 7th once they leave; the toast.low stepped down to a Nod once the budget is spent; the splash once the
			-- column's last toast has left (ANN-R20, ANN-R31, #249).
			local first = {}
			for _, line in ipairs(tornPageSeen) do
				local what = line:match("^[%d.]+ (.+)$")
				first[what] = first[what] or line
			end
			assert.are.same({
				"0.5 toast: Toast 1",
				"0.5 banner: Level 12",
				"15.0 nod: New here",
				"20.0 toast: Toast 6",
				"28.5 toast: Toast 7",
				"34.5 nod: Size record",
				"37.0 splash: Legend",
			}, {
				first["toast: Toast 1"],
				first["banner: Level 12"],
				first["nod: New here"],
				first["toast: Toast 6"],
				first["toast: Toast 7"],
				first["nod: Size record"],
				first["splash: Legend"],
			})
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

	-- The texts of a frame's stamps on show, then its Coins'.
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
		"draws on a given frame in a given style, Torn Page still equipped, with nothing shown, played or summarized"
			.. " (ANN-R80, wallet-and-shop.md › UI)",
		function()
			local loaded = styledCore()
			local stage, summarized = stageOf(loaded)

			local sample = loaded.ns.DrawSampleToast(stage, RIPPLE)

			assert.are.equal(stage, sample:GetParent())
			assert.are.same(
				{ true, "NEW SPECIES", "A sample toast", 136245, 0.8 },
				{ sample.shown, sample.title:GetText(), sample.text:GetText(), sample.icon.texture, sample:GetScale() }
			)
			assert.are.same({ "NEW HERE", "+5" }, stampsOf(sample))
			assert.are.same(
				{ "ToastsRipple toast-toast", "Announce bezel-silver-84" },
				{ lookOf(loaded, sample).page, lookOf(loaded, sample).trim }
			)
			assert.are.same({ {}, {}, nil }, { summarized, loaded.client.sounds, loaded.ns.announcementFrames.toast })
			assert.are.equal(TORN_PAGE, loaded.env.Pagle.GetEquipped("core.toaststyle"))
			-- It stands still on the stage: no slide, no fade (announcements.md › Motion).
			assert.are.same({ 1, 1 }, { sample.alpha, #sample.body.points[1] })
		end
	)

	it(
		"redraws the same frame on the same stage in the next style asked for, Torn Page for an unknown one (ANN-R80)",
		function()
			local loaded = styledCore()
			local stage = stageOf(loaded)
			local first = loaded.ns.DrawSampleToast(stage, LANTERN)

			local again = loaded.ns.DrawSampleToast(stage, "core.toaststyle.moonlit")

			assert.are.equal(first, again)
			assert.are.equal("ToastsLedger toast-toast", lookOf(loaded, again).page)
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
				{ true, "NEW SPECIES", "ToastsLantern toast-toast" },
				{ toast.shown, toast.title:GetText(), lookOf(loaded, toast).page }
			)
			assert.are.same(
				{ "Interface\\AddOns\\Pagle\\media\\sounds\\driftwood\\toast_1.ogg SFX" },
				loaded.client.sounds
			)
			equip(loaded, RIPPLE)
			assert.are.equal("ToastsLantern toast-toast", lookOf(loaded, toast).page)
			loaded.client.advance(8.7 + 0.4)
			assert.is_false(toast.shown)
			raiseStamped(loaded, M)
			assert.are.equal("ToastsRipple toast-toast", lookOf(loaded, toast).page)
			assert.are.same({ "New Species" }, { summarized[1].title, summarized[3] })
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
				{ true, "NEW SPECIES", "ToastsRipple toast-toast" },
				{ panel.shown, sample.title:GetText(), lookOf(loaded, sample).page }
			)
			assert.are.same({ true, "Show on screen" }, { button.shown, button:GetText() })
			loaded.ns.goods:Good(LANTERN).preview(stage)
			assert.are.same({ sample, "ToastsLantern toast-toast" }, { panel.children[1], lookOf(loaded, sample).page })
			button:Click()
			local toast = loaded.ns.announcementFrames.toast
			assert.are.same(
				{ true, "ToastsLantern toast-toast", {} },
				{ toast.shown, lookOf(loaded, toast).page, summarized }
			)
		end
	)

	it(
		"hides behind another of Core's previews on the same stage, and comes back (wallet-and-shop.md › UI)",
		function()
			local loaded = styledCore()
			local stage = stageOf(loaded)
			loaded.ns.goods:Good(TORN_PAGE).preview(stage)
			local panel = stage.children[1]

			loaded.ns.goods:Good("core.crest.crest1").preview(stage)
			assert.is_false(panel.shown)
			loaded.ns.goods:Good(RIPPLE).preview(stage)

			assert.are.same({ true, false }, { panel.shown, stage.children[2].shown })
		end
	)
end)
