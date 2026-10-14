-- Showing Announcements on the client, through the real TOC (announcements.md › The display queue, › Interruption
-- budget, › Sounds, › Toast styles, › UI): a Module raises moments, logic/Moments.lua merges them, and Core shows them
-- through the lanes in the Timber frames, playing their sounds with PlaySoundFile.

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"
local DRIFTWOOD = SOUNDS .. "driftwood\\"
local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
-- The Pagle Coin icon the Coins stamp shows after its "+N" (ANN-R23).
local COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"

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
				{ 136245, "New Species", "Nightfin Snapper" },
				{ toast.icon.texture, toast.title:GetText(), toast.text:GetText() }
			)
			assert.are.same({ "New here", "★★", "Rank up", "Skill", "+1", "+25 " .. COIN }, stampsOf(toast))
			assert.is_false(toast.more.shown)
			loaded.client.advance(5.9)
			assert.is_true(toast.shown)
			loaded.client.advance(0.1)
			assert.is_false(toast.shown)
		end
	)

	it(
		"show a banner in the centre for 4 s, then the toasts that waited, the next reading +1 more (ANN-R20)",
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
			raise(loaded, M, moment("banner", "Level 12", { text = "Angler Level" }))

			loaded.client.advance(6)
			local banner = frameOf(loaded, "banner")
			assert.are.same({ true, false }, { banner.shown, showing(loaded, "toast") })
			assert.are.same({ "Level 12", "Angler Level" }, { banner.title:GetText(), banner.text:GetText() })
			loaded.client.advance(4)

			local toast = frameOf(loaded, "toast")
			assert.are.same({ false, true }, { banner.shown, toast.shown })
			assert.are.same(
				{ "Toast 2", true, "+1 more" },
				{ toast.title:GetText(), toast.more.shown, toast.more:GetText() }
			)
		end
	)

	it("show a splash full screen until it is clicked, playing the Legend sting (ANN-R20, ANN-R72)", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("splash", "Legend", { text = "Old Ironjaw", icon = 6292 }))

		local splash = frameOf(loaded, "splash")
		assert.are.same(
			{ true, "Legend", "Old Ironjaw" },
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
		assert.are.same({ "New here", "+10 " .. COIN }, stampsOf(nod))
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
			assert.are.same({ "12.0 lb", "+2.0 lb", "weight" }, {
				view.value:GetText(),
				view.margin:GetText(),
				view.label:GetText(),
			})
			assert.are.same({ true, false }, { view.margin.shown, view.record.shown })
			loaded.client.update(loaded.ns.RULER_STAMP_DELAY)
			assert.are.same({ true, "New record" }, { view.record.shown, view.record.label:GetText() })
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
			assert.are.same({ true, false }, { nod.ruler.margin.shown, nod.ruler.record.shown })
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
