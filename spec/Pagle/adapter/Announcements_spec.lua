-- Showing Announcements on the client, through the real TOC (announcements.md › The display queue, › Interruption
-- budget, › Sounds, › Toast styles, › UI): a Module raises moments, logic/Moments.lua merges them, and Core shows them
-- through the lanes in the announcements art's frames, playing their sounds with PlaySoundFile. A headline with text
-- prints its title in capitals over the text, one without shows its title as it is, and stamps are in capitals.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")
local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"
local DRIFTWOOD = SOUNDS .. "driftwood\\"
local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)
-- A banner's title, "Level 12", spaced as the art spaces it.
local LEVEL_12 = "L E V E L    1 2"
-- How long each stays from when it appears (its motion settles, then its hold), and how long each takes to leave.
local TOAST, NOD, BANNER = 8.7, 3.3, 5.9
local LEAVE_TOAST, LEAVE_NOD, LEAVE_BANNER = 0.4, 0.3, 0.5

-- Core logged in on Forever with the Ledger registered. Each moment Core hands the summary is in `summarized`. Its
-- Angler has answered the Letter already, so no Letter arrives with its sound 4 s in (ONB-R10, ONB-R12).
local function loadCore()
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog() }))
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local summarized = {}
	function loaded.ns.summary.Add(_, moment)
		summarized[#summarized + 1] = moment
	end
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	-- Margin notes off: these hear only the Announcements' own sounds, not a note's noteIn (ONB-R50, ONB-R52).
	loaded.env.PagleDB.global.onboarding.notesOn = false
	loaded.client.fire("PLAYER_LOGIN")
	loaded.ns.onboarding:State().letter = "declined"
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	loaded.client.runTimers()
	return loaded, M, summarized
end

-- Core's crop of a moment's art to the fish's head (ns.HeadCrop), as texture coordinates.
local function headCrop(loaded, art)
	return loaded.ns.HeadCrop(art)
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

-- Whether something of `form` is on screen, as the lanes have it: a frame leaving doesn't count.
local function showing(loaded, form)
	for _, frame in ipairs(loaded.ns.AnnouncementFramesShowing()) do
		if frame.display.form == form then
			return true
		end
	end
	return false
end

-- The column's headline titles on screen, the newest first.
local function columnTitles(loaded)
	local titles = {}
	for _, frame in ipairs(loaded.ns.columnFrames) do
		titles[#titles + 1] = frame.display.announcement.headline.title
	end
	return titles
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
		"draw a toast with its icon, title, text, 4 stamps, a +N stamp and the Coins stamp; it settles, stays 6 s, then"
			.. " leaves over 0.4 s (ANN-R11, ANN-R20, ANN-R23, ANN-R80)",
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
			loaded.client.advance(TOAST - 0.1)
			assert.is_true(showing(loaded, "toast"))
			loaded.client.advance(0.1)
			assert.are.same({ false, true }, { showing(loaded, "toast"), toast.shown })
			loaded.client.advance(LEAVE_TOAST)
			assert.is_false(toast.shown)
		end
	)

	it(
		"show a banner in the centre for 5.9 s beside the column's 3 toasts, the 4th coming in as they leave (ANN-R20)",
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

			local banner = frameOf(loaded, "banner")
			assert.are.same({ "Toast 3", "Toast 2", "Toast 1" }, columnTitles(loaded))
			assert.are.same({ LEVEL_12, "Angler Level" }, { banner.title:GetText(), banner.text:GetText() })
			loaded.client.advance(BANNER)
			assert.are.same({ false, true }, { showing(loaded, "banner"), banner.shown })
			loaded.client.advance(LEAVE_BANNER)
			assert.is_false(banner.shown)
			loaded.client.advance(TOAST - 1 - BANNER - LEAVE_BANNER)

			assert.are.same({ "Toast 4" }, columnTitles(loaded))
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
		assert.are.same({ SOUNDS .. "legend\\19803.ogg SFX" }, loaded.client.sounds)
		splash:Click()
		assert.is_false(splash.shown)
	end)

	it(
		"show a Nod raised while a toast shows under it in the column; both reach the summary (ANN-R20, ANN-R25)",
		function()
			local loaded, M, summarized = loadCore()
			raise(loaded, M, moment("toast", "New Species"))

			raise(loaded, M, moment("nod", "New here"))

			assert.are.same({ "New here", "New Species" }, columnTitles(loaded))
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
		loaded.client.advance(NOD + LEAVE_NOD)
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

	it(
		"show a toast's record ruler settled at once with Animations off: counted up, the margin in, New record down (ANN-R22)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.announcements.motion = false

			raise(
				loaded,
				M,
				moment("toast", "Trophy weight", { ruler = { old = 10, new = 12, unit = "lb", label = "weight" } })
			)

			local view = frameOf(loaded, "toast").ruler
			assert.are.same({ true, "12.0 lb", true, "+2.0 lb", true, "NEW RECORD" }, {
				view.shown,
				view.value:GetText(),
				view.margin.shown,
				view.margin:GetText(),
				view.record.shown,
				view.record.label:GetText(),
			})
			assert.is_nil(view.scripts.OnUpdate)
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
			for _ = 1, 20 do
				raise(loaded, M, moment("toast", "Interruption"))
				loaded.client.advance(6)
			end
			-- Past PagleDB's 20 per 5 minutes: a Nod (ANN-R31).
			raise(loaded, M, moment("toast.low", "Size record", { ruler = ruler }))

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
			loaded.client.advance(TOAST + LEAVE_TOAST)
			-- 100 characters are 600: half the size would fit, but the line stops at 70% and ends in "...".
			raise(loaded, M, moment("toast", "New Species", { text = ("x"):rep(100) }))
			local floored = { text.font, text:GetWidth() }
			loaded.client.advance(TOAST + LEAVE_TOAST)
			raise(loaded, M, moment("toast", "New Species", { text = "Oily Blackmouth" }))

			assert.are.same({ { hand, 30, "" }, 292 }, shrunk)
			assert.are.same({ { hand, 22, "" }, 292 }, floored)
			assert.are.same({ "PagleArtName", nil }, { text.fontObject, text.font })
		end
	)

	-- A toast's body's drop below its place, and its alpha.
	local function slid(toast)
		return { -select(5, toast.body:GetPoint(1)), toast.alpha }
	end

	it(
		"slides a toast in from 26 low and unseen, writes its name out, slams its stamps and turns its coin in, all"
			.. " settled by 2.66 s (announcements.md › Motion)",
		function()
			local loaded, M = loadCore()
			raise(
				loaded,
				M,
				moment("toast", "New Species", { text = "Oily Blackmouth", cast = CAST, coins = 5 }),
				moment("nod", "Rank up", { cast = CAST })
			)
			local toast = frameOf(loaded, "toast")
			local stamp, coin, clip = toast.stamps[1], toast.coins.coin, toast.nameClip
			local before = { slid(toast), stamp.scale, coin:GetWidth() < 1, clip:GetWidth() < 1 }

			for _ = 1, 30 do
				loaded.client.update(0.1)
			end

			assert.are.same({ { 26, 0 }, 2.6, true, true }, before)
			assert.are.same({ { 0, 1 }, 1, 0.9, coin.w0 }, { slid(toast), stamp.scale, stamp.alpha, coin:GetWidth() })
			assert.are.equal(toast.text:GetWidth() + 8, clip:GetWidth())
		end
	)

	it(
		"drops a banner's seal from 2.2x and draws its tooling out from it, settled by 1.4 s (announcements.md › Motion)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("banner", "Angler Level 12", { seal = 12 }))
			local banner = frameOf(loaded, "banner")
			local left, right = banner.tools[1].sprite, banner.tools[2].sprite
			local before = { banner.sealFrame.scale, left:GetWidth() < 1, right:GetWidth() < 1, banner.rays.alpha }

			for _ = 1, 15 do
				loaded.client.update(0.1)
			end

			assert.are.same({ 2.2, true, true, 0 }, before)
			assert.are.same(
				{ 1, left.w0, right.w0, 1, 0 },
				{ banner.sealFrame.scale, left:GetWidth(), right:GetWidth(), banner.rays.alpha, banner.rays.rotation }
			)
		end
	)

	it("turns the splash's rays a quarter turn in 15 s, clockwise (announcements.md › Motion)", function()
		local loaded, M = loadCore()
		raise(loaded, M, moment("splash", "Legend", { text = "Old Ironjaw" }))

		for _ = 1, 150 do
			loaded.client.update(0.1)
		end

		assert.are.equal(-90, math.floor(math.deg(frameOf(loaded, "splash").rays.rotation) + 0.5))
	end)

	it("shows each settled at once with Animations off (SET-R30, announcements.md › Motion)", function()
		local loaded, M = loadCore()
		assert.is_true(loaded.env.Pagle.IsAnimationsOn())
		loaded.ns.db.profile.announcements.motion = false
		assert.is_false(loaded.env.Pagle.IsAnimationsOn()) -- what a Module reads (announcements.md › Contracts)

		raise(
			loaded,
			M,
			moment("toast", "New Species", { text = "Oily Blackmouth", cast = CAST, coins = 5 }),
			moment("banner", "Angler Level 12", { cast = CAST, seal = 12 })
		)

		local toast, banner = frameOf(loaded, "toast"), frameOf(loaded, "banner")
		assert.are.same(
			{ { 0, 1 }, toast.coins.coin.w0, 1, banner.tools[1].sprite.w0 },
			{ slid(toast), toast.coins.coin:GetWidth(), banner.sealFrame.scale, banner.tools[1].sprite:GetWidth() }
		)
	end)

	it("writes a headline with no text as its title alone in the Angler's hand, as a catch Nod's line", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("nod", "Oily Blackmouth · Decent · 34.2 cm"))

		local nod = frameOf(loaded, "nod")
		assert.are.same(
			{ "Oily Blackmouth · Decent · 34.2 cm", "PagleArtNodName", false },
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
				loaded.client.advance(BANNER + LEAVE_BANNER)
			end

			assert.are.same({
				{ "seal", "1,200", false, false },
				{ "seal-quill", false, false, false },
				{ false, false, "player", "PRESTIGE I" },
			}, seals)
		end
	)
end)

describe("a variety's art and a fish crest on the client (VAR-R25)", function()
	-- A variety's art: a 192 × 96 rectangle at (0, 0) of a 2048 atlas (VAR-R11).
	local ART = {
		texture = "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
		left = 0,
		right = 0.09375,
		top = 0,
		bottom = 0.046875,
	}

	-- Rounded to 6 places, for texture coordinates worked out in floating point.
	local function rounded(coords)
		local out = {}
		for i, v in ipairs(coords) do
			out[i] = math.floor(v * 1e6 + 0.5) / 1e6
		end
		return out
	end

	it(
		"draws a toast's and a Nod's medallion with the art cropped to the fish's head, and the icon again after",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("toast", "Rare variety", { text = "Coral", icon = 6359, art = ART }))
			local toast = frameOf(loaded, "toast")

			assert.are.equal(ART.texture, toast.icon.texture)
			assert.are.same(rounded({ headCrop(loaded, ART) }), rounded(toast.icon.texCoord))

			loaded.client.advance(TOAST + LEAVE_TOAST)
			raise(loaded, M, moment("toast", "New Species", { icon = 136245 }))
			assert.are.same({ 136245, { 0, 1, 0, 1 } }, { toast.icon.texture, toast.icon.texCoord })

			raise(loaded, M, moment("nod", "New variety · Coral", { art = ART }))
			local nod = frameOf(loaded, "nod")
			assert.are.same({ ART.texture }, { nod.icon.texture })
			assert.are.same(rounded({ headCrop(loaded, ART) }), rounded(nod.icon.texCoord))
		end
	)

	it("draws a banner's art on its seal's ribbon, and a crest good's icon in the Prestige crest's place", function()
		local loaded, M = loadCore()
		raise(loaded, M, moment("banner", "Epic variety", { text = "Phoenix-fin", art = ART }))
		local banner = frameOf(loaded, "banner")
		assert.are.same({ true, true, ART.texture, { ART.left, ART.right, ART.top, ART.bottom }, false }, {
			banner.seal.shown,
			banner.ribbonArt.shown,
			banner.ribbonArt.texture,
			banner.ribbonArt.texCoord,
			banner.crestIcon.shown,
		})
		loaded.client.advance(BANNER + LEAVE_BANNER)

		raise(loaded, M, moment("banner", "Every colour of Firefin Snapper", { seal = "crest", crest = "fish6359" }))
		assert.are.same({ false, false, false, false, true, "fish6359", false }, {
			banner.seal.shown,
			banner.crest.shown,
			banner.portrait.shown,
			banner.crestLabel.shown,
			banner.crestIcon.shown,
			banner.crestIcon.texture,
			banner.ribbonArt.shown,
		})
	end)
end)

describe("the column on the client", function()
	-- A column frame's bottom above the screen's: its BOTTOM anchor's y.
	local function bottomOf(frame)
		return select(5, frame:GetPoint(1))
	end

	it(
		"stacks toasts and Nods at the bottom centre, the newest at the foot, each a page and a gap above the last"
			.. " (ANN-R20)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.announcements.motion = false
			raise(loaded, M, moment("toast", "First"))
			raise(loaded, M, moment("toast", "Second"))

			raise(loaded, M, moment("nod", "Third"))

			assert.are.same({ "Third", "Second", "First" }, columnTitles(loaded))
			local column = loaded.ns.columnFrames
			-- A Nod is 40 tall and a toast 92, each with a 12 gap.
			assert.are.same({ 156, 156 + 52, 156 + 52 + 104 }, {
				bottomOf(column[1]),
				bottomOf(column[2]),
				bottomOf(column[3]),
			})
		end
	)

	it(
		"hides the banner and the toasts on screen at once as combat starts, with no leaving motion (ANN-R35)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("banner", "Level 12"), moment("toast", "First"))
			loaded.client.advance(3)
			local banner, toast = frameOf(loaded, "banner"), frameOf(loaded, "toast")
			assert.is_true(banner:IsShown() and toast:IsShown())

			setCombat(loaded, true)

			assert.is_false(banner:IsShown())
			assert.is_false(toast:IsShown())
		end
	)

	it(
		"keeps a toast while the pointer is on it, then gives it the time it had left; a click sends one away (ANN-R20)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("toast", "Hovered"))
			local frame = frameOf(loaded, "toast")
			loaded.client.advance(5)

			frame.scripts.OnEnter(frame)
			loaded.client.advance(60)
			assert.is_true(showing(loaded, "toast"))
			frame.scripts.OnLeave(frame)
			loaded.client.advance(TOAST - 5 - 0.01)
			assert.is_true(showing(loaded, "toast"))
			loaded.client.advance(0.01)
			assert.is_false(showing(loaded, "toast"))

			raise(loaded, M, moment("nod", "Clicked"))
			local nod = frameOf(loaded, "nod")
			nod.scripts.OnMouseUp(nod, "LeftButton")
			assert.is_false(showing(loaded, "nod"))
		end
	)

	it(
		"lets a toast leave over 0.4 s, fading as it drifts up; with Animations off it goes at once"
			.. " (announcements.md › Motion)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("toast", "Leaving"))
			local frame = frameOf(loaded, "toast")
			loaded.client.advance(TOAST)
			loaded.client.update(0.2)
			local leaving = { frame.shown, frame.alpha < 1, bottomOf(frame) > 156 }
			loaded.client.advance(LEAVE_TOAST)
			local gone = frame.shown

			loaded.ns.db.profile.announcements.motion = false
			raise(loaded, M, moment("toast", "At once"))
			local other = frameOf(loaded, "toast")
			loaded.client.advance(TOAST)

			assert.are.same({ { true, true, true }, false, false }, { leaving, gone, other.shown })
		end
	)

	it(
		"plays a toast's beats on its motion: the pen at 0.98 s, a stamp at 2.17 s, the coin at 2.66 s; none for a silent"
			.. " toast or with Animations off (announcements.md › Sounds)",
		function()
			-- The sounds a toast raised with `fields` plays over its first 3 s, with motion on or off.
			local function beats(fields, motion)
				local loaded, M = loadCore()
				loaded.ns.db.profile.announcements.motion = motion
				local headline = { text = "Oily Blackmouth", cast = CAST, coins = 5 }
				for key, value in pairs(fields) do
					headline[key] = value
				end
				raise(loaded, M, moment("toast", "New Species", headline), moment("nod", "Rank up", { cast = CAST }))
				for _ = 1, 30 do
					loaded.client.update(0.1)
				end
				return loaded.client.sounds
			end

			assert.are.same({ DRIFTWOOD .. "toast_1.ogg SFX", "3093 SFX", "1204 SFX", "120 SFX" }, beats({}, true))
			assert.are.same({}, beats({ sound = false }, true))
			assert.are.same({ DRIFTWOOD .. "toast_1.ogg SFX" }, beats({}, false))
		end
	)
end)

describe("the motion driver", function()
	it("leaves what plays alone when told to stop an owner it isn't playing, even from inside an animation", function()
		local loaded = loadCore()
		local owner, stranger = loaded.env.CreateFrame("Frame"), loaded.env.CreateFrame("Frame")
		local last
		loaded.ns.Animate(owner, {
			{
				dur = 1,
				ease = loaded.ns.EASE.linear,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					last = v[1]
					loaded.ns.StopMotion(stranger)
				end,
			},
		})

		for _ = 1, 12 do
			loaded.client.update(0.1)
		end

		-- It played to its end.
		assert.are.equal(1, last)
	end)

	it("settles a toast that arrives while the UI is hidden, so it never stays unseen yet takes the mouse", function()
		local loaded, M = loadCore()
		loaded.env.UIParent:Hide() -- Alt-Z
		raise(loaded, M, moment("toast", "New Species", { text = "Oily Blackmouth", cast = CAST, coins = 5 }))
		local toast = frameOf(loaded, "toast")

		loaded.client.update(0.1)
		loaded.env.UIParent:Show()

		assert.are.same({ 0, 1, toast.coins.coin.w0 }, {
			-select(5, toast.body:GetPoint(1)),
			toast.alpha,
			toast.coins.coin:GetWidth(),
		})
	end)
end)

describe("the Interruption budget on the client", function()
	-- Raises `n` toasts, each shown in full before the next.
	local function interrupt(loaded, M, n)
		for i = 1, n do
			raise(loaded, M, moment("toast", "Interruption " .. i))
			loaded.client.advance(TOAST + LEAVE_TOAST)
		end
	end

	it(
		"steps the 21st toast.low down to a Nod with a compact ruler, at PagleDB's 20 per 5 minutes (ANN-R31, ANN-R22)",
		function()
			local loaded, M = loadCore()
			interrupt(loaded, M, 20)

			raise(
				loaded,
				M,
				moment("toast.low", "Size record", { ruler = { old = 1, new = 2, unit = "lb", label = "w" } })
			)

			local nod = frameOf(loaded, "nod")
			assert.are.same({ true, false }, { showing(loaded, "nod"), showing(loaded, "toast") })
			assert.are.same({ "Size record", true }, { nod.title:GetText(), nod.ruler.shown })
			loaded.client.update(1.5)
			-- A compact ruler: the margin, with no old record's number or stamp.
			assert.are.same(
				{ true, false, false },
				{ nod.ruler.margin.shown, nod.ruler.old.shown, nod.ruler.record.shown }
			)
			loaded.client.advance(NOD)
			raise(loaded, M, moment("toast", "New Species"))
			assert.is_true(showing(loaded, "toast"))
		end
	)

	it("steps nothing down with the budget off in PagleDB (ANN-R32)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.budget.on = false
		interrupt(loaded, M, 20)

		raise(loaded, M, moment("toast.low", "Size record"))

		assert.are.same({ true, "Size record" }, { showing(loaded, "toast"), frameOf(loaded, "toast").title:GetText() })
	end)
end)

describe("Announcement sounds on the client", function()
	it(
		"play toast_1, toast_2 and toast_3 on SFX across toasts, a waiting toast's only as it shows, and never a"
			.. " Nod's (ANN-R24, ANN-R70–R73)",
		function()
			local loaded, M = loadCore()
			for i = 1, 4 do
				raise(loaded, M, moment("toast", "Toast " .. i))
			end
			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				DRIFTWOOD .. "toast_3.ogg SFX",
			}, loaded.client.sounds)

			loaded.client.advance(TOAST)
			raise(loaded, M, moment("nod", "New here"))
			assert.is_true(showing(loaded, "nod"))
			raise(loaded, M, moment("banner", "Level 12"))

			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "toast_2.ogg SFX",
				DRIFTWOOD .. "toast_3.ogg SFX",
				DRIFTWOOD .. "toast_1.ogg SFX",
				DRIFTWOOD .. "banner.ogg SFX",
			}, loaded.client.sounds)
		end
	)

	it(
		"play the Ledger's earned Old Salt's Concertina like Core's own once equipped, from sounds keyed by its ID"
			.. " (ANN-R72, SHOP-R25)",
		function()
			local CONCERTINA = SOUNDS .. "concertina\\"
			local loaded, M = loadCore()
			M:RegisterGood({
				id = "ledger.soundset.concertina",
				slot = "core.soundset",
				name = "Old Salt's Concertina",
				isEarned = function()
					return true
				end,
				earnedText = "Prestige I",
			})
			assert.is_true(loaded.env.Pagle.SetEquipped("core.soundset", "ledger.soundset.concertina"))

			raise(loaded, M, moment("toast", "Toast 1"))
			loaded.client.advance(TOAST)
			raise(loaded, M, moment("toast", "Toast 2"))
			loaded.client.advance(TOAST)
			raise(loaded, M, moment("banner", "Banner"))

			assert.are.same({
				CONCERTINA .. "toast_1.ogg SFX",
				CONCERTINA .. "toast_2.ogg SFX",
				CONCERTINA .. "banner.ogg SFX",
			}, loaded.client.sounds)
		end
	)

	it(
		"play the equipped set: Gilded's one toast and its banner, the first Legend's sting, then Driftwood's rotation where it"
			.. " left off (ANN-R70, ANN-R72, SHOP-R33)",
		function()
			local GILDED = SOUNDS .. "gilded\\"
			local loaded, M = loadCore()
			local Pagle = loaded.env.Pagle
			raise(loaded, M, moment("toast", "Toast 1"))
			loaded.client.advance(TOAST)
			loaded.ns.RecordPurchase("core.soundset.gilded", 400) -- the Curio Shop's buy (SHOP-R10, SHOP-R11)
			assert.is_true(Pagle.SetEquipped("core.soundset", "core.soundset.gilded"))

			local steps =
				{ { "toast", TOAST }, { "toast", TOAST }, { "banner", BANNER + LEAVE_BANNER }, { "splash", 8 } }
			for _, step in ipairs(steps) do
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
				SOUNDS .. "legend\\19803.ogg SFX",
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
	-- Core as loadCore makes it, with Oily Blackmouth's name cached, the Angler's unit in cm and, unless `firstTime`,
	-- every one of its varieties caught before in Core's projection (VAR-R10), so its Nod may name any (VAR-R27).
	---@param firstTime boolean?
	local function catching(firstTime)
		local loaded, M, summarized = loadCore()
		loaded.client.itemNames[6358] = "Oily Blackmouth"
		loaded.ns.db.profile.lengthUnit = "cm"
		if not firstTime then
			local all = {}
			for index = 1, 10 do
				all[index] = true
			end
			loaded.ns.db.global.projections.varieties.projection.bySpecies[6358] = all
		end
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
			-- Oily Blackmouth has varieties: its line names the Catch's, the name a segment of its own (VAR-R26).
			assert.matches(
				"^Oily Blackmouth · [%a%- ]+ · %a+ · %d+%.%d cm$",
				frame.display.announcement.headline.title
			)
			assert.are.equal("Oily Blackmouth ·", frame.title:GetText())
			assert.matches("^[%a%- ]+$", frame.variety:GetText())
			assert.matches("^· %a+ · %d+%.%d cm$", frame.tail:GetText())
			assert.are.same({}, stampsOf(frame))
			assert.are.same({}, loaded.client.sounds)
			assert.are.same({}, summarized)
			loaded.client.advance(NOD)
			assert.is_false(showing(loaded, "nod"))
		end
	)

	it("names no variety caught for the first time: that Catch reads as one without (VAR-R27)", function()
		local loaded = catching(true)

		catchAndFlush(loaded)

		local frame = frameOf(loaded, "nod") --[[@as table]]
		assert.matches("^Oily Blackmouth · %a+ · %d+%.%d cm$", frame.display.announcement.headline.title)
		assert.is_nil(frame.display.announcement.headline.variety)
	end)

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

describe("a catch Nod naming a variety on the client (VAR-R26)", function()
	-- Firefin Snapper's Coral: a 192 × 96 rectangle at (192, 0) of a 2048 atlas (VAR-R11).
	local ART = {
		texture = "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
		left = 0.09375,
		right = 0.1875,
		top = 0,
		bottom = 0.046875,
	}

	-- The rarity of `key`, as Core has it.
	local function rarityOf(loaded, key)
		for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
			if rarity.key == key then
				return rarity
			end
		end
		error("no rarity " .. key)
	end

	-- Raises Core's catch Nod naming Coral as a variety of `rarity`, as ns.CatchNodMoment makes it, and runs the frame
	-- it shows on. Returns the Nod's frame.
	local function raiseVarietyNod(loaded, rarity)
		loaded.ns.moments:RaiseCatchNod({
			rung = "nod",
			kind = "catch",
			title = "Firefin Snapper · Coral · Decent · 34.2 cm",
			icon = 6359,
			cast = CAST,
			sound = false,
			variety = { name = "Coral", rarity = rarity, before = "Firefin Snapper ·", after = "· Decent · 34.2 cm" },
			art = ART,
		})
		loaded.client.advance(0)
		return frameOf(loaded, "nod") --[[@as table]]
	end

	-- A text colour as it reads back, from an { r, g, b }.
	local function rgb(color)
		return { color[1], color[2], color[3] }
	end

	it(
		"writes the variety's name between the line's halves in its rarity's ink, after a gem in its colour; the rest"
			.. " stays in the style's ink, on a strip sized to it (VAR-R26, ANN-R80)",
		function()
			local loaded = loadCore()
			local rare = rarityOf(loaded, "rare")

			local nod = raiseVarietyNod(loaded, "rare")

			local ink = rgb(loaded.ns.ANNOUNCE_COLORS.ink)
			assert.are.same({
				{ "Firefin Snapper ·", ink },
				{ "Coral", rgb(rare.ink) },
				{ "· Decent · 34.2 cm", ink },
			}, {
				{ nod.title:GetText(), nod.title.textColor },
				{ nod.variety:GetText(), nod.variety.textColor },
				{ nod.tail:GetText(), nod.tail.textColor },
			})
			-- The gem: a small square turned to a diamond, rimmed in the ink and filled with the colour.
			assert.are.same({ true, rgb(rare.color), rgb(rare.ink), math.rad(45), math.rad(45) }, {
				nod.gem.shown,
				rgb(nod.gem.fill.color),
				rgb(nod.gem.rim.color),
				nod.gem.fill.rotation,
				nod.gem.rim.rotation,
			})
			-- In a row: the first half, the gem, the name, the second half.
			assert.are.same(
				{ nod.title, nod.gem, nod.variety },
				{ nod.gem.points[1][2], nod.variety.points[1][2], nod.tail.points[1][2] }
			)
			assert.is_false(nod.text.shown)
			assert.are.same({}, bounds.overflows(nod))
			assert.are.equal(3, bounds.measured)
			assert.are.equal(nod:GetWidth() - 22, nod.strip:GetWidth())
		end
	)

	it(
		"shows the variety's art cropped to the fish's head in the medallion, its ring in the rarity's colour but"
			.. " Common's the style's own, and a plain Nod after as before (VAR-R26)",
		function()
			local loaded, M = loadCore()
			local rings = {}
			for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
				local nod = raiseVarietyNod(loaded, rarity.key)
				rings[#rings + 1] = { nod.bezel.Ring.desaturated == true, nod.bezel.Ring.vertexColor }
				assert.are.same({ ART.texture, { loaded.ns.HeadCrop(ART) } }, { nod.icon.texture, nod.icon.texCoord })
				loaded.client.advance(NOD + LEAVE_NOD)
			end
			local colors = {}
			for i, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
				colors[i] = { i > 1, i > 1 and rgb(rarity.color) or { 1, 1, 1 } }
			end
			for _, ring in ipairs(rings) do
				ring[2] = rgb(ring[2])
			end
			assert.are.same(colors, rings)

			raise(loaded, M, moment("nod", "New here", { icon = 136245 }))

			local nod = frameOf(loaded, "nod") --[[@as table]]
			assert.are.same({ "New here", false, false, false, false, { 1, 1, 1 }, 136245 }, {
				nod.title:GetText(),
				nod.gem.shown,
				nod.variety.shown,
				nod.tail.shown,
				nod.bezel.Ring.desaturated == true,
				rgb(nod.bezel.Ring.vertexColor),
				nod.icon.texture,
			})
		end
	)

	it(
		"sweeps one gleam across a Rare or Epic Nod's strip as it enters, in the rarity's colour, added on, then gone;"
			.. " none for Common or Uncommon, nor with Animations off, and silent (VAR-R26, ANN-R13)",
		function()
			-- The gleam's brightest and where it went over the Nod's first second, and the gleam after.
			local function sweep(rarity, motion)
				local loaded = loadCore()
				loaded.ns.db.profile.announcements.motion = motion
				local nod = raiseVarietyNod(loaded, rarity)
				local peak, xs = nod.gleam.alpha or 0, {}
				for _ = 1, 60 do
					loaded.client.update(1 / 60)
					peak = math.max(peak, nod.gleam.alpha or 0)
					xs[#xs + 1] = nod.gleam.points[1] and nod.gleam.points[1][4]
				end
				return { peak = peak, xs = xs, gleam = nod.gleam, sounds = loaded.client.sounds, loaded = loaded }
			end

			for _, key in ipairs({ "rare", "epic" }) do
				local seen = sweep(key, true)
				assert.is_true(seen.peak > 0.5)
				assert.are.same({ 0, "ADD", true, rgb(rarityOf(seen.loaded, key).color), {} }, {
					seen.gleam.alpha,
					seen.gleam.blendMode,
					seen.gleam.desaturated,
					rgb(seen.gleam.vertexColor),
					seen.sounds,
				})
				-- Left to right, once.
				assert.is_true(seen.xs[5] < seen.xs[30])
			end
			for _, case in ipairs({ { "common", true }, { "uncommon", true }, { "rare", false } }) do
				assert.are.equal(0, sweep(case[1], case[2]).peak)
			end
		end
	)
end)
