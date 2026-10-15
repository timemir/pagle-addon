-- Showing Announcements on the client, through the real TOC (announcements.md › The display queue, › Interruption
-- budget, › Sounds, › Toast styles, › UI): a Module raises moments, logic/Moments.lua merges them, and Core shows them
-- through the lanes in the announcements art's frames, playing their sounds with PlaySoundFile. A headline with text
-- prints its title in capitals over the text, one without shows its title as it is, and stamps are in capitals.

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"
local DRIFTWOOD = SOUNDS .. "driftwood\\"
local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
-- A banner's title, "Level 12", spaced as the art spaces it.
local LEVEL_12 = "L E V E L    1 2"

-- Core logged in on Forever with the Ledger registered. Each moment Core hands the summary is in `summarized`.
local function loadCore()
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }))
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local summarized = {}
	function loaded.ns.summary.Add(_, moment)
		summarized[#summarized + 1] = moment
	end
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.runTimers()
	return loaded, M, summarized
end

-- A moment on `rung` titled `title`, with other fields from `fields`.
local function moment(rung, title, fields)
	local m = { rung = rung, kind = "spec", title = title }
	for key, value in pairs(fields or {}) do
		m[key] = value
	end
	return m
end

-- Raises each moment, then runs the next frame, where Core flushes them (ANN-R10, ANN-R12).
local function raise(loaded, M, ...)
	for i = 1, select("#", ...) do
		M:RaiseMoment((select(i, ...)))
	end
	loaded.client.advance(0)
end

-- The frame Core draws `form` in, or nil before it first showed one.
local function frameOf(loaded, form)
	return loaded.ns.announcementFrames[form]
end

-- Whether a frame for `form` is on screen.
local function showing(loaded, form)
	local frame = frameOf(loaded, form)
	return frame ~= nil and frame.shown
end

-- The texts of a frame's stamps on show, in order, then its Coins stamp if it shows.
local function stampsOf(frame)
	local texts = {}
	for _, stamp in ipairs(frame.stamps) do
		if stamp.shown then
			texts[#texts + 1] = stamp.label:GetText()
		end
	end
	if frame.coins.shown then
		texts[#texts + 1] = frame.coins.label:GetText()
	end
	return texts
end

describe("Announcement frames", function()
	it(
		"draw a toast with its icon, title, text, 4 stamps, a +N stamp and the Coins stamp, for 6 s"
			.. " (ANN-R11, ANN-R20, ANN-R23, ANN-R80)",
		function()
			local loaded, M = loadCore()
			local moments =
				{ moment("toast", "New Species", { text = "Nightfin Snapper", icon = 136245, cast = CAST }) }
			for i, stamp in ipairs({ "New here", "★★", "Rank up", "Skill", "Trophy" }) do
				moments[#moments + 1] = moment("nod", "Moment " .. i, { stamp = stamp, cast = CAST, coins = 5 })
			end

			raise(loaded, M, unpack(moments))

			local toast = frameOf(loaded, "toast")
			assert.is_true(toast.shown)
			assert.are.same(
				{ 136245, "NEW SPECIES", "Nightfin Snapper" },
				{ toast.icon.texture, toast.title:GetText(), toast.text:GetText() }
			)
			assert.are.same({ "NEW HERE", "★★", "RANK UP", "SKILL", "+1", "+25" }, stampsOf(toast))
			assert.is_false(toast.more.shown)
			loaded.client.advance(5.9)
			assert.is_true(toast.shown)
			loaded.client.advance(0.1)
			assert.is_false(toast.shown)
		end
	)

	it(
		"show a banner in the centre for 4 s while the toasts keep their turn, the next reading +1 more (ANN-R20)",
		function()
			local loaded, M = loadCore()
			raise(
				loaded,
				M,
				moment("toast", "Toast 1"),
				moment("toast", "Toast 2"),
				moment("toast", "Toast 3"),
				moment("toast", "Toast 4")
			)
			loaded.client.advance(1)
			raise(loaded, M, moment("banner", "Level 12", { text = "Angler Level" }))

			local banner, toast = frameOf(loaded, "banner"), frameOf(loaded, "toast")
			assert.are.same({ true, true }, { banner.shown, toast.shown })
			assert.are.same({ LEVEL_12, "Angler Level" }, { banner.title:GetText(), banner.text:GetText() })
			loaded.client.advance(4)
			assert.are.same({ false, true }, { banner.shown, toast.shown })
			loaded.client.advance(1)

			assert.are.same(
				{ "Toast 2", true, "+1 more" },
				{ toast.title:GetText(), toast.more.shown, toast.more:GetText() }
			)
		end
	)

	it(
		"show a Cast's level-up banner and its New Species toast at the same time, each with its own stamps and"
			.. " Coins, playing only the banner's sound (ANN-R11, ANN-R20, ANN-R23, ANN-R24)",
		function()
			local loaded, M = loadCore()

			raise(
				loaded,
				M,
				moment("toast", "New Species", { text = "Nightfin Snapper", cast = CAST, coins = 10 }),
				moment("banner", "Level 12", { text = "Angler Level", cast = CAST, coins = 20 }),
				moment("nod", "New in this zone", { cast = CAST, coins = 2 })
			)

			local banner, toast = frameOf(loaded, "banner"), frameOf(loaded, "toast")
			assert.are.same({ true, true }, { banner.shown, toast.shown })
			assert.are.same({ LEVEL_12, "NEW SPECIES" }, { banner.title:GetText(), toast.title:GetText() })
			assert.are.same({ "+20" }, stampsOf(banner))
			assert.are.same({ "NEW IN THIS ZONE", "+12" }, stampsOf(toast))
			assert.are.same({ DRIFTWOOD .. "banner.ogg SFX" }, loaded.client.sounds)
		end
	)

	it("show a splash full screen until it is clicked, playing the Legend sting (ANN-R20, ANN-R72)", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("splash", "Legend", { text = "Old Ironjaw", icon = 6292 }))

		local splash = frameOf(loaded, "splash")
		assert.are.same(
			{ true, "LEGEND", "Old Ironjaw" },
			{ splash.shown, splash.title:GetText(), splash.text:GetText() }
		)
		assert.are.same({ SOUNDS .. "legend.ogg SFX" }, loaded.client.sounds)
		splash:Click()
		assert.is_false(splash.shown)
	end)

	it(
		"leave a Nod raised while the slot is busy off screen; it still reaches the summary (ANN-R20, ANN-R25)",
		function()
			local loaded, M, summarized = loadCore()
			raise(loaded, M, moment("toast", "New Species"))

			raise(loaded, M, moment("nod", "New here"))

			assert.is_false(showing(loaded, "nod"))
			assert.are.same({ "New Species", "New here" }, { summarized[1].title, summarized[2].title })
		end
	)

	it("show the Coins stamp on a Nod, adding up identical moments' Coins (ANN-R23)", function()
		local loaded, M = loadCore()

		raise(
			loaded,
			M,
			moment("nod", "New here", { cast = CAST, coins = 5 }),
			moment("nod", "New here", { cast = CAST, coins = 5 })
		)

		local nod = frameOf(loaded, "nod")
		assert.is_true(nod.shown)
		assert.are.same({ "NEW HERE", "+10" }, stampsOf(nod))
		assert.are.same({}, loaded.client.sounds)
		loaded.client.advance(3)
		assert.is_false(nod.shown)
	end)

	it(
		"animate a toast's record ruler: the number counts up over 1.5 s, the margin lands, then New record a beat"
			.. " later (ANN-R22)",
		function()
			local loaded, M = loadCore()
			local ruler = { old = 10, new = 12, unit = "lb", label = "weight" }

			raise(loaded, M, moment("toast", "Trophy weight", { ruler = ruler }))

			local view = frameOf(loaded, "toast").ruler
			assert.are.same({ true, false, false }, { view.shown, view.margin.shown, view.record.shown })
			loaded.client.update(0.75)
			assert.is_false(view.margin.shown)
			loaded.client.update(0.75)
			assert.are.same({ "12.0 lb", "+2.0 lb", "WEIGHT" }, {
				view.value:GetText(),
				view.margin:GetText(),
				view.label:GetText(),
			})
			assert.are.same({ true, false }, { view.margin.shown, view.record.shown })
			loaded.client.update(loaded.ns.RULER_STAMP_DELAY)
			assert.are.same({ true, "NEW RECORD" }, { view.record.shown, view.record.label:GetText() })
		end
	)

	it("show a weight ruler's old record by its mark, as given (ANN-R22)", function()
		local loaded, M = loadCore()

		raise(
			loaded,
			M,
			moment("toast", "Trophy weight", { ruler = { old = 10, new = 12, unit = "lb", label = "weight" } })
		)

		local view = frameOf(loaded, "toast").ruler
		assert.are.same({ "10.0 lb", true }, { view.old:GetText(), view.old.shown })
	end)

	it(
		"show a size ruler's old and new lengths and its margin in the Angler's length unit (ANN-R22, LOG-R69)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.lengthUnit = "cm"
			local size = { old = 300, new = 342, unit = "length", label = "length" }

			raise(loaded, M, moment("toast", "Size record", { ruler = size }))
			loaded.client.update(1.5)

			local view = frameOf(loaded, "toast").ruler
			assert.are.same(
				{ "30.0 cm", "34.2 cm", "+4.2 cm", "LENGTH" },
				{ view.old:GetText(), view.value:GetText(), view.margin:GetText(), view.label:GetText() }
			)
		end
	)

	it(
		"draw the old record's mark and the ruler's labels above the fill, on the toast and the Nod (ANN-R22)",
		function()
			-- The client's draw layers, back to front; regions in one layer draw by sublevel.
			local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
			local function above(region, fill)
				local layer, sublevel = region:GetDrawLayer()
				local fillLayer, fillSublevel = fill:GetDrawLayer()
				return LAYERS[layer] > LAYERS[fillLayer] or (layer == fillLayer and sublevel > fillSublevel)
			end
			local loaded, M = loadCore()
			local ruler = { old = 1, new = 2, unit = "lb", label = "w" }
			raise(loaded, M, moment("toast", "Size record", { ruler = ruler }))
			loaded.client.advance(6)
			for _ = 1, 4 do
				raise(loaded, M, moment("toast", "Interruption"))
				loaded.client.advance(6)
			end
			raise(loaded, M, moment("toast.low", "Size record", { ruler = ruler })) -- the 5th: a Nod (ANN-R31)

			local drawn = {}
			for _, form in ipairs({ "toast", "nod" }) do
				local view = frameOf(loaded, form).ruler
				drawn[form] = {
					mark = above(view.mark, view.fill),
					old = above(view.old, view.fill),
					margin = above(view.margin, view.fill),
					fillOverTrack = above(view.fill, view.track),
				}
			end
			local all = { mark = true, old = true, margin = true, fillOverTrack = true }
			assert.are.same({ toast = all, nod = all }, drawn)
		end
	)

	it("show a size margin that rounds to zero in inches as +<0.1 in (ANN-R22)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.lengthUnit = "in"
		local size = { old = 300, new = 300.2, unit = "length", label = "length" }

		raise(loaded, M, moment("toast", "Size record", { ruler = size }))
		loaded.client.update(1.5)

		local view = frameOf(loaded, "toast").ruler
		assert.are.same({ "11.8 in", "+<0.1 in" }, { view.value:GetText(), view.margin:GetText() })
	end)
end)

describe("the announcements art", function()
	-- The sprite a texture shows, by its texture coordinates' top left in the atlas named by its file.
	local function spriteOf(loaded, texture)
		for _, atlas in pairs(loaded.ns.ATLASES) do
			if texture.texture == atlas.file then
				for name, sprite in pairs(atlas.sprites) do
					if
						math.abs(texture.texCoord[1] - sprite.x / atlas.width) < 1e-9
						and math.abs(texture.texCoord[3] - sprite.y / atlas.height) < 1e-9
					then
						return name
					end
				end
			end
		end
	end

	it(
		"draws each toast rung on its own page: pencil for toast.low, ruled for a record, gilt and wax for toast.high"
			.. " (announcements.md › UI)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.announcements.budget.on = false
			local pages = {}
			local ruler = { old = 1, new = 2, unit = "lb", label = "weight" }
			for _, step in ipairs({
				{ "toast.low", {} },
				{ "toast.low", { ruler = ruler } },
				{ "toast", {} },
				{ "toast.high", {} },
			}) do
				raise(loaded, M, moment(step[1], "Moment", step[2]))
				local toast = frameOf(loaded, "toast")
				pages[#pages + 1] = { spriteOf(loaded, toast.page), toast.wax.shown, toast.bezel.Ring:GetWidth() > 90 }
				loaded.client.advance(6)
			end

			assert.are.same({
				{ "toast-low", false, false },
				{ "toast-low-ruled", false, false },
				{ "toast-toast", false, true },
				{ "toast-high", true, true },
			}, pages)
		end
	)

	it(
		"shrinks a handwritten line too wide for its page to fit, down to 70% of its size, and draws the next at full"
			.. " size",
		function()
			local loaded, M = loadCore()
			local hand = "Interface\\AddOns\\Pagle\\media\\fonts\\Caveat-SemiBold.ttf"

			-- The fake measures 6 pixels a character: 49 characters are 294, over the toast's 292 for words.
			raise(loaded, M, moment("toast", "New Species", { text = ("x"):rep(49) }))
			local text = frameOf(loaded, "toast").text
			local shrunk = { text.font, text:GetWidth() }
			loaded.client.advance(6)
			-- 100 characters are 600: half the size would fit, but the line stops at 70% and ends in "...".
			raise(loaded, M, moment("toast", "New Species", { text = ("x"):rep(100) }))
			local floored = { text.font, text:GetWidth() }
			loaded.client.advance(6)
			raise(loaded, M, moment("toast", "New Species", { text = "Oily Blackmouth" }))

			assert.are.same({ { hand, 30, "" }, 292 }, shrunk)
			assert.are.same({ { hand, 22, "" }, 292 }, floored)
			assert.are.same({ "PagleArtName", nil }, { text.fontObject, text.font })
		end
	)

	it("writes a headline with no text as its title alone in the Angler's hand, as a catch Nod's line", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("nod", "Oily Blackmouth · Typical · 34.2 cm"))

		local nod = frameOf(loaded, "nod")
		assert.are.same(
			{ "Oily Blackmouth · Typical · 34.2 cm", "PagleArtNodName", false },
			{ nod.title:GetText(), nod.title.fontObject, nod.text.shown }
		)
	end)

	it(
		"presses a banner's seal with the headline's number or mark, or shows the Prestige crest with the Angler's"
			.. " portrait (announcements.md › Contracts)",
		function()
			local loaded, M = loadCore()
			local seals = {}
			for _, seal in ipairs({ 1200, "quill", "crest" }) do
				raise(loaded, M, moment("banner", "Prestige I", { seal = seal }))
				local banner = frameOf(loaded, "banner")
				seals[#seals + 1] = {
					banner.seal.shown and spriteOf(loaded, banner.seal) or false,
					banner.sealNumber.shown and banner.sealNumber:GetText() or false,
					banner.crest.shown and banner.portrait.portrait or false,
					banner.crestLabel.shown and banner.crestLabel:GetText() or false,
				}
				loaded.client.advance(4)
			end

			assert.are.same({
				{ "seal", "1,200", false, false },
				{ "seal-quill", false, false, false },
				{ false, false, "player", "PRESTIGE I" },
			}, seals)
		end
	)
end)

describe("the Interruption budget on the client", function()
	-- Raises `n` toasts, each shown in full before the next.
	local function interrupt(loaded, M, n)
		for i = 1, n do
			raise(loaded, M, moment("toast", "Interruption " .. i))
			loaded.client.advance(6)
		end
	end

	it(
		"steps the 5th toast.low down to a Nod with a compact ruler, at PagleDB's 4 per 5 minutes (ANN-R31, ANN-R22)",
		function()
			local loaded, M = loadCore()
			interrupt(loaded, M, 4)

			raise(
				loaded,
				M,
				moment("toast.low", "Size record", { ruler = { old = 1, new = 2, unit = "lb", label = "w" } })
			)

			local nod = frameOf(loaded, "nod")
			assert.are.same({ true, false }, { nod.shown, showing(loaded, "toast") })
			assert.are.same({ "Size record", true }, { nod.title:GetText(), nod.ruler.shown })
			loaded.client.update(1.5)
			-- A compact ruler: the margin, with no old record's number or stamp.
			assert.are.same(
				{ true, false, false },
				{ nod.ruler.margin.shown, nod.ruler.old.shown, nod.ruler.record.shown }
			)
			loaded.client.advance(3)
			raise(loaded, M, moment("toast", "New Species"))
			assert.is_true(showing(loaded, "toast"))
		end
	)

	it("steps nothing down with the budget off in PagleDB (ANN-R32)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.budget.on = false
		interrupt(loaded, M, 4)

		raise(loaded, M, moment("toast.low", "Size record"))

		assert.are.same({ true, "Size record" }, { showing(loaded, "toast"), frameOf(loaded, "toast").title:GetText() })
	end)
end)

describe("Announcement sounds on the client", function()
	it(
		"play toast_1, toast_2 and toast_3 on SFX across back-to-back toasts, a waiting toast's only as it shows, and"
			.. " never a Nod's (ANN-R24, ANN-R70–R73)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("toast", "Toast 1"), moment("toast", "Toast 2"))
			assert.are.same({ DRIFTWOOD .. "toast_1.ogg SFX" }, loaded.client.sounds)

			loaded.client.advance(6)
			raise(loaded, M, moment("toast", "Toast 3"))
			loaded.client.advance(12)
			raise(loaded, M, moment("nod", "New here"))
			assert.is_true(showing(loaded, "nod"))
			raise(loaded, M, moment("banner", "Level 12"))

			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				DRIFTWOOD .. "toast_3.ogg SFX",
				DRIFTWOOD .. "banner.ogg SFX",
			}, loaded.client.sounds)
		end
	)

	it(
		"play the equipped set: Gilded's one toast and its banner, the shared sting, then Driftwood's rotation where it"
			.. " left off (ANN-R70, ANN-R72, SHOP-R33)",
		function()
			local GILDED = SOUNDS .. "gilded\\"
			local loaded, M = loadCore()
			local Pagle = loaded.env.Pagle
			raise(loaded, M, moment("toast", "Toast 1"))
			loaded.client.advance(6)
			loaded.ns.RecordPurchase("core.soundset.gilded", 400) -- the Curio Shop's buy (SHOP-R10, SHOP-R11)
			assert.is_true(Pagle.SetEquipped("core.soundset", "core.soundset.gilded"))

			for _, step in ipairs({ { "toast", 6 }, { "toast", 6 }, { "banner", 4 }, { "splash", 8 } }) do
				raise(loaded, M, moment(step[1], step[1]))
				loaded.client.advance(step[2])
			end
			assert.is_true(Pagle.SetEquipped("core.soundset", "core.soundset.driftwood"))
			raise(loaded, M, moment("toast", "Toast 2"))

			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg SFX",
				GILDED .. "toast_1.ogg SFX",
				GILDED .. "toast_1.ogg SFX",
				GILDED .. "banner.ogg SFX",
				SOUNDS .. "legend.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
			}, loaded.client.sounds)
		end
	)

	it("keep a headline with sound = false silent (ANN-R71)", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("banner", "Level 12", { sound = false }))

		assert.is_true(showing(loaded, "banner"))
		assert.are.same({}, loaded.client.sounds)
	end)
end)

describe("The catch Nod on the client", function()
	-- Core as loadCore makes it, with Oily Blackmouth's name cached and the Angler's unit in cm.
	local function catching()
		local loaded, M, summarized = loadCore()
		loaded.client.itemNames[6358] = "Oily Blackmouth"
		loaded.ns.db.profile.lengthUnit = "cm"
		return loaded, M, summarized
	end

	it(
		'draws an ordinary Catch as a silent Nod, "{item name} · {band} · {length}", for 3 s, never summarized'
			.. " (ANN-R13, ANN-R20, ANN-R25)",
		function()
			local loaded, _, summarized = catching()

			catchAndFlush(loaded)

			assert.is_true(showing(loaded, "nod"))
			local frame = frameOf(loaded, "nod") --[[@as table]]
			assert.matches("^Oily Blackmouth · %a+ · %d+%.%d cm$", frame.title:GetText())
			assert.are.same({}, stampsOf(frame))
			assert.are.same({}, loaded.client.sounds)
			assert.are.same({}, summarized)
			loaded.client.advance(3)
			assert.is_false(showing(loaded, "nod"))
		end
	)

	it("never counts toward the Interruption budget (ANN-R13, ANN-R30, ANN-R31)", function()
		local loaded, M = catching()
		loaded.ns.db.profile.announcements.budget.count = 1

		catchAndFlush(loaded)
		loaded.client.advance(3)
		raise(loaded, M, moment("toast.low", "Size record"))

		assert.is_true(showing(loaded, "toast"))
	end)

	it("is dropped, not held, in combat and in Cozy mode (ANN-R13, ANN-R35, ANN-R36, ANN-R40)", function()
		local loaded = catching()
		setCombat(loaded, true)
		catchAndFlush(loaded)
		setCombat(loaded, false)
		loaded.client.advance(2)
		assert.is_nil(frameOf(loaded, "nod"))

		loaded.ns.db.profile.announcements.cozy = true
		catchAndFlush(loaded)

		assert.is_nil(frameOf(loaded, "nod"))
	end)

	it('shows nothing for an ordinary Catch with "Show every catch" off (ANN-R13, SET-R30)', function()
		local loaded = catching()
		loaded.ns.db.profile.announcements.everyCatch = false

		catchAndFlush(loaded)

		assert.is_nil(frameOf(loaded, "nod"))
	end)
end)
