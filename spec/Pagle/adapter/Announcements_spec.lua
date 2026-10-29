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
		'stamp the sum of a Cast\'s tickets as "Refresh +N" after the other stamps, outside the 4 and the +N, before'
			.. " the Coins (ANN-R23, REF-R7)",
		function()
			local loaded, M = loadCore()
			local moments =
				{ moment("toast", "New Species", { text = "Nightfin Snapper", icon = 136245, cast = CAST }) }
			for i, stamp in ipairs({ "New here", "Rank up", "Skill", "Trophy", "Extra" }) do
				moments[#moments + 1] = moment("nod", "Moment " .. i, { stamp = stamp, cast = CAST, tickets = 1 })
			end

			raise(loaded, M, unpack(moments))

			local toast = frameOf(loaded, "toast")
			local stamps = stampsOf(toast)
			-- The Refresh stamp leads with the ticket's icon, an inline texture of Core's own atlas (#466).
			assert.is_truthy(stamps[6]:find("^|T.-Pagle.media.ticket.Ticket:14:20:"))
			stamps[6] = stamps[6]:gsub("^|T[^|]*|t ", "")
			assert.are.same({ "NEW HERE", "RANK UP", "SKILL", "TROPHY", "+1", "REFRESH +5" }, stamps)
		end
	)

	it("stamps a banner's tickets the same way, and a toast with none shows no Refresh stamp (REF-R7)", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("banner", "Level 12", { cast = CAST, tickets = 2 }))
		loaded.client.advance(BANNER + LEAVE_BANNER)
		raise(loaded, M, moment("toast", "New Species", { cast = CAST }))

		local banner = stampsOf(frameOf(loaded, "banner"))
		assert.are.same({ "REFRESH +2" }, { (banner[1]:gsub("^|T[^|]*|t ", "")) })
		assert.are.same({}, stampsOf(frameOf(loaded, "toast")))
	end)

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

	-- #363 (#76 item 12): a hint, not a button, since ReloadUI() is protected; no setting turns it off.
	it("always carry the line /reload to keep it safe on a splash, in Cozy mode too (ANN-R41, ANN-R97)", function()
		local loaded, M = loadCore()

		raise(loaded, M, moment("splash", "Legend", { text = "Old Ironjaw", icon = 6292 }))
		local splash = frameOf(loaded, "splash")
		assert.are.same({ true, "/reload to keep it safe" }, { splash.reload:IsVisible(), splash.reload:GetText() })
		splash:Click()

		loaded.ns.db.profile.announcements.cozy = true
		raise(loaded, M, moment("splash", "Legend", { text = "Keefer's Angelfish", icon = 19805 }))
		assert.are.same(
			{ true, "Keefer's Angelfish", true, "/reload to keep it safe" },
			{ splash.shown, splash.text:GetText(), splash.reload:IsVisible(), splash.reload:GetText() }
		)
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
			for _ = 1, 40 do
				raise(loaded, M, moment("toast", "Interruption"))
				loaded.client.advance(6)
			end
			-- Past PagleDB's 40 per 5 minutes: a Nod (ANN-R31).
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
		"draws every toast full size on the toast page, ruled for a record, toast.low's too, and toast.high's gilt with"
			.. " wax; there is no slim page (ANN-R80, announcements.md › UI)",
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
				{ "toast-toast", false, true },
				{ "toast-toast-ruled", false, true },
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

	it(
		"writes a headline with no text as its title alone in the Angler's hand, as a stepped-down catch toast's line",
		function()
			local loaded, M = loadCore()

			raise(loaded, M, moment("nod", "Oily Blackmouth · Decent · 34.2 cm"))

			local nod = frameOf(loaded, "nod")
			assert.are.same(
				{ "Oily Blackmouth · Decent · 34.2 cm", "PagleArtNodName", false },
				{ nod.title:GetText(), nod.title.fontObject, nod.text.shown }
			)
		end
	)

	it(
		"presses a banner's seal with the headline's number or mark, or shows the Prestige frame of its frameRank with"
			.. " the Angler's portrait (announcements.md › Contracts, ANN-R83)",
		function()
			local loaded, M = loadCore()
			local seals = {}
			for _, fields in ipairs({
				{ seal = 1200 },
				{ seal = "quill" },
				{ seal = "frame", frameRank = 7 },
				{ seal = "frame", frameRank = 13 },
			}) do
				raise(loaded, M, moment("banner", "Prestige", fields))
				local banner = frameOf(loaded, "banner")
				local prestige = banner.prestige
				seals[#seals + 1] = {
					banner.seal.shown and spriteOf(loaded, banner.seal) or false,
					banner.sealNumber.shown and banner.sealNumber:GetText() or false,
					prestige.shown and prestige.key or false,
					prestige.shown and prestige:GetWell().portrait or false,
					prestige.shown and prestige.label:GetText() or false,
				}
				loaded.client.advance(BANNER + LEAVE_BANNER)
			end

			assert.are.same({
				{ "seal", "1,200", false, false, false },
				{ "seal-quill", false, false, false, false },
				{ false, false, "coral", "player", "VII" },
				{ false, false, "constellation", "player", "MASTER" },
			}, seals)
		end
	)

	it(
		"draws the Prestige frame at 0.6 of its box, its likeness's centre on the seal's, dropping in with the seal"
			.. " (ANN-R83)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("banner", "Prestige V", { seal = "frame", frameRank = 5 }))
			local banner = frameOf(loaded, "banner")
			local prestige = banner.prestige
			local well = loaded.ns.PRESTIGE_WELL

			assert.are.same({ 156, 168 }, { prestige.width, prestige.height })
			assert.are.same(
				{ "TOPLEFT", banner.sealFrame, "CENTER", -well.cx * 0.6, well.cy * 0.6 },
				{ prestige:GetPoint() }
			)
			assert.are.equal(banner.sealFrame, prestige:GetParent())
			-- Its sprites are the Storm's, each at its box at 0.6.
			local art = loaded.ns.PrestigeFrameArt(5)
			local atlas = loaded.ns.ATLASES[art.atlas]
			for i, layer in ipairs(art.layers) do
				local texture = prestige.art.active[i].texture
				assert.are.equal(atlas.file, texture.texture)
				assert.are.same({ layer.w * 0.6, layer.h * 0.6 }, { texture.width, texture.height })
			end
		end
	)

	it(
		"plays the Prestige frame's own motion once the seal has dropped in, while the banner holds, and stops it as"
			.. " the banner goes (ANN-R83)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("banner", "Prestige V", { seal = "frame", frameRank = 5 }))
			local prestige = frameOf(loaded, "banner").prestige
			local wheel
			for _, slot in ipairs(prestige.art.active) do
				if slot.layer.name == "body" then
					wheel = slot.texture
				end
			end

			local function near(a, b)
				return math.abs(a - b) < 1e-6
			end
			assert.are.equal(prestige, prestige.art.playing)
			-- Still dropping in: the wheel waits at its first frame, 7° anticlockwise (the client turns anticlockwise).
			loaded.client.nextFrame(0.5)
			assert.is_true(near(math.rad(7), wheel.rotation))
			loaded.client.nextFrame(0.13 + 4.6 / 4) -- a quarter of its rock on, from -7° to 7°: upright
			assert.is_true(near(0, wheel.rotation))
			loaded.client.nextFrame(4.6 / 4) -- and at 7° clockwise
			assert.is_true(near(-math.rad(7), wheel.rotation))

			loaded.client.advance(BANNER + LEAVE_BANNER)
			assert.is_nil(prestige.art.playing)
		end
	)

	it(
		"stands the Prestige frame still with Animations off: resting, the lightning unseen (ANN-R83, SET-R30)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.announcements.motion = false
			raise(loaded, M, moment("banner", "Prestige V", { seal = "frame", frameRank = 5 }))
			local prestige = frameOf(loaded, "banner").prestige
			local shown = {}
			for _, slot in ipairs(prestige.art.active) do
				shown[slot.layer.name] = { slot.texture.shown, slot.texture.rotation }
			end

			assert.is_nil(prestige.art.playing)
			assert.are.same({
				back = { true, 0 },
				fx1 = { false, 0 },
				fx2 = { false, 0 },
				body = { true, 0 },
				lab = { true, 0 },
			}, shown)
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
			local crop = loaded.ns.ICON_CROP
			assert.are.same({ 136245, { crop, 1 - crop, crop, 1 - crop } }, { toast.icon.texture, toast.icon.texCoord })

			raise(loaded, M, moment("nod", "New variety · Coral", { art = ART }))
			local nod = frameOf(loaded, "nod")
			assert.are.same({ ART.texture }, { nod.icon.texture })
			assert.are.same(rounded({ headCrop(loaded, ART) }), rounded(nod.icon.texCoord))
		end
	)

	it("draws a banner's art on its seal's ribbon, and a crest good's icon in the seal's place", function()
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
		assert.are.same({ false, false, true, "fish6359", false }, {
			banner.seal.shown,
			banner.prestige.shown,
			banner.crestIcon.shown,
			banner.crestIcon.texture,
			banner.ribbonArt.shown,
		})
	end)
end)

describe("the column on the client", function()
	-- A column frame's bottom above the screen's: its offset from the column's foot, the anchor it hangs from (ANN-R98),
	-- plus the foot's own.
	local function bottomOf(frame)
		local _, anchor, _, _, y = frame:GetPoint(1)
		return y + select(5, anchor:GetPoint(1))
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
		"runs a clicked toast's or Nod's headline onClick as it sends it away (ANN-R20, announcements.md › Contracts)",
		function()
			local loaded, M = loadCore()
			local clicked = {}
			raise(
				loaded,
				M,
				moment("nod", "Open me", {
					onClick = function()
						clicked[#clicked + 1] = "nod"
					end,
				})
			)
			local nod = frameOf(loaded, "nod")
			nod.scripts.OnMouseUp(nod, "LeftButton")
			assert.is_false(showing(loaded, "nod"))

			raise(
				loaded,
				M,
				moment("toast", "Me too", {
					onClick = function()
						error("the Module's own failure")
					end,
				})
			)
			local toast = frameOf(loaded, "toast")
			toast.scripts.OnMouseUp(toast, "LeftButton")

			assert.are.same({ "nod" }, clicked)
			assert.is_false(showing(loaded, "toast")) -- sent away all the same, its error reported, not raised
			local errors = loaded.client.errors
			assert.are.equal(1, #errors)
			assert.matches("the Module's own failure", errors[1])
		end
	)

	it("refuses a moment whose onClick isn't a function (announcements.md › Contracts)", function()
		local _, M = loadCore()

		local ok, err = pcall(M.RaiseMoment, M, moment("nod", "Bad", { onClick = "open" }))

		assert.is_false(ok)
		assert.matches("RaiseMoment: a moment's onClick is a function", tostring(err))
	end)

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
		"steps the 41st toast.low down to a Nod with a compact ruler, at PagleDB's 40 per 5 minutes (ANN-R31, ANN-R22)",
		function()
			local loaded, M = loadCore()
			-- 40 toasts take over 5 minutes here: the longest window keeps them all in it.
			loaded.ns.db.profile.announcements.budget.window = 900
			interrupt(loaded, M, 40)

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
		interrupt(loaded, M, 40)

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

describe("The catch toast on the client", function()
	-- Core as loadCore makes it, with Oily Blackmouth's name cached, the Angler's unit in cm and, unless `firstTime`,
	-- every one of its varieties caught before in Core's projection (VAR-R10), so its toast may name any (VAR-R27).
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
		'draws an ordinary Catch as a toast.low, its kicker "{band} · {length}" over the fish named with its variety,'
			.. " with the toast sound, for 6 s, never summarized (ANN-R13, ANN-R20, ANN-R25, ANN-R70)",
		function()
			local loaded, _, summarized = catching()

			catchAndFlush(loaded)

			assert.is_true(showing(loaded, "toast"))
			local frame = frameOf(loaded, "toast") --[[@as table]]
			local headline = frame.display.announcement.headline
			assert.are.same({ "toast.low", "Oily Blackmouth" }, { headline.rung, headline.text })
			assert.matches("^%u+ · %d+%.%d CM$", frame.title:GetText())
			-- Oily Blackmouth has varieties: its text line is the fish's name, then a gem and the variety's (VAR-R26).
			assert.are.equal("Oily Blackmouth ·", frame.text:GetText())
			assert.matches("^[%a%- ]+$", frame.variety:GetText())
			assert.is_true(frame.gem.shown)
			assert.are.same({}, stampsOf(frame))
			assert.are.equal(DRIFTWOOD .. "toast_1.ogg SFX", loaded.client.sounds[1])
			assert.are.same({}, summarized)
			loaded.client.advance(6 + 2.7 - 0.1)
			assert.is_true(showing(loaded, "toast"))
			loaded.client.advance(0.2)
			assert.is_false(showing(loaded, "toast"))
		end
	)

	it('reads "CAUGHT" for its kicker when the Catch has no size (ANN-R13)', function()
		local loaded = catching()
		-- An Uncharted item has no Simulated Size (LOG-R55, LOG-R65).
		loaded.client.itemNames[99001] = "Strange Flotsam"

		catchOne(
			loaded,
			{ { link = "|cffffffff|Hitem:99001::::::::15:::::::::|h[Strange Flotsam]|h|r", quantity = 1 } }
		)
		loaded.client.advance(0)

		local frame = frameOf(loaded, "toast") --[[@as table]]
		assert.are.same({ "CAUGHT", "Strange Flotsam", false }, {
			frame.title:GetText(),
			frame.text:GetText(),
			frame.gem.shown,
		})
	end)

	it("names no variety caught for the first time: that Catch reads as one without (VAR-R27)", function()
		local loaded = catching(true)

		catchAndFlush(loaded)

		local frame = frameOf(loaded, "toast") --[[@as table]]
		assert.is_nil(frame.display.announcement.headline.variety)
		assert.are.same({ "Oily Blackmouth", false }, { frame.text:GetText(), frame.gem.shown })
	end)

	it(
		"counts toward the Interruption budget and steps down, past it, to a Nod reading as the catch Nod did: no"
			.. " sound, the old line (ANN-R13, ANN-R30, ANN-R31)",
		function()
			local loaded, M = catching()
			loaded.ns.db.profile.announcements.budget.count = 1

			catchAndFlush(loaded)
			assert.is_true(showing(loaded, "toast"))
			loaded.client.advance(TOAST)
			local sounds = #loaded.client.sounds
			catchAndFlush(loaded)

			assert.is_false(showing(loaded, "toast"))
			local nod = frameOf(loaded, "nod") --[[@as table]]
			assert.is_true(showing(loaded, "nod"))
			assert.are.equal("Oily Blackmouth ·", nod.title:GetText())
			assert.matches("^[%a%- ]+$", nod.variety:GetText())
			assert.matches("^· %a+ · %d+%.%d cm$", nod.tail:GetText())
			assert.is_false(nod.text.shown)
			assert.are.equal(sounds, #loaded.client.sounds)
			raise(loaded, M, moment("toast", "New Species"))
			assert.is_true(showing(loaded, "toast"))
		end
	)

	it("steps down to its whole name and size line when it names no variety (ANN-R31)", function()
		local loaded = catching(true)
		loaded.ns.db.profile.announcements.budget.count = 0

		catchAndFlush(loaded)

		local nod = frameOf(loaded, "nod") --[[@as table]]
		assert.matches("^Oily Blackmouth · %a+ · %d+%.%d cm$", nod.title:GetText())
		assert.is_false(nod.variety.shown)
	end)

	it("is held in combat as a toast is, and shows once it ends; Cozy mode shows nothing (ANN-R35, ANN-R40)", function()
		local loaded = catching()
		setCombat(loaded, true)
		catchAndFlush(loaded)
		assert.is_nil(frameOf(loaded, "toast"))
		setCombat(loaded, false)
		loaded.client.advance(2)
		assert.is_true(showing(loaded, "toast"))
		loaded.client.advance(TOAST)

		loaded.ns.db.profile.announcements.cozy = true
		catchAndFlush(loaded)

		assert.is_false(showing(loaded, "toast"))
		assert.is_false(showing(loaded, "nod"))
	end)

	it('shows nothing for an ordinary Catch with "Show every catch" off (ANN-R13, SET-R30)', function()
		local loaded = catching()
		loaded.ns.db.profile.announcements.everyCatch = false

		catchAndFlush(loaded)

		assert.is_nil(frameOf(loaded, "toast"))
		assert.is_nil(frameOf(loaded, "nod"))
	end)
end)

describe("a catch toast stepped down to a Nod naming a variety on the client (VAR-R26, ANN-R31)", function()
	-- The rarity of `key`, as Core has it.
	local function rarityOf(loaded, key)
		for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
			if rarity.key == key then
				return rarity
			end
		end
		error("no rarity " .. key)
	end

	-- Core's catch toast naming Coral as a variety of `rarity`, as ns.CatchToastMoment makes it.
	local function coralToast(rarity)
		return {
			rung = "toast.low",
			kind = "catch",
			title = "Decent · 34.2 cm",
			text = "Firefin Snapper",
			nodLine = "Firefin Snapper · Coral · Decent · 34.2 cm",
			icon = 6359,
			cast = CAST,
			variety = { name = "Coral", rarity = rarity, before = "Firefin Snapper ·", after = "· Decent · 34.2 cm" },
		}
	end

	-- Raises that catch toast with the budget spent, so it steps down to a Nod, and runs the frame it shows on.
	-- Returns the Nod's frame.
	local function raiseVarietyNod(loaded, rarity)
		loaded.ns.db.profile.announcements.budget.count = 0
		loaded.ns.moments:RaiseCatchToast(coralToast(rarity))
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
		"shows the Catch's item icon in the medallion, not the variety's art, its ring in the rarity's colour but"
			.. " Common's the style's own, and a plain Nod after as before (VAR-R26)",
		function()
			local loaded, M = loadCore()
			local rings = {}
			for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
				local nod = raiseVarietyNod(loaded, rarity.key)
				rings[#rings + 1] = { nod.bezel.Ring.desaturated == true, nod.bezel.Ring.vertexColor }
				assert.are.equal(6359, nod.icon.texture)
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
		"puts no opaque disc behind a variety Nod's medallion: it shows the item's icon, as the catch toast does"
			.. " (#424, VAR-R26)",
		function()
			local loaded = loadCore()

			local nod = raiseVarietyNod(loaded, "epic")

			assert.are.same({ false, 6359 }, { nod.bezel.Back ~= nil and nod.bezel.Back.shown, nod.icon.texture })
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

describe("a toast announcing a variety on the client (#424, VAR-R25, VAR-R26, ANN-R22, ANN-R80)", function()
	-- Bristle Whisker Catfish's Coral: a 192 × 96 rectangle of a 2048 atlas (VAR-R11).
	local ART = {
		texture = "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
		left = 0.09375,
		right = 0.1875,
		top = 0,
		bottom = 0.046875,
	}
	local ITEM = 6291
	local FISH = "Raw Bristle Whisker Catfish"

	local function rarityOf(loaded, key)
		for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
			if rarity.key == key then
				return rarity
			end
		end
		error("no rarity " .. key)
	end

	local function rgb(color)
		return { color[1], color[2], color[3] }
	end

	-- The Cast of the issue: a size record from 30.3 to 30.4 cm and a first catch of Coral, a variety of `rarity`, as
	-- the Ledger raises them (LED-R97), the record first.
	local function recordAndVariety(rarity)
		local record = moment("toast.low", "Size record", {
			kind = "sizeRecord",
			order = 100,
			text = FISH,
			stamp = "Record",
			icon = ITEM,
			cast = CAST,
			ruler = { old = 303, new = 304, unit = "length", label = "Tiddler" },
		})
		local variety = moment("toast.low", "New variety", {
			kind = "newVariety",
			order = 120,
			text = "Coral",
			stamp = "New variety",
			icon = ITEM,
			cast = CAST,
			art = ART,
			variety = { name = "Coral", rarity = rarity },
		})
		return record, variety
	end

	-- Raises the Cast's moments and returns the toast it shows.
	local function raiseRecord(loaded, M, rarity)
		raise(loaded, M, recordAndVariety(rarity))
		return frameOf(loaded, "toast") --[[@as table]]
	end

	-- A toast's name ink, as its style and page give it.
	local function nameInk(loaded, toast)
		local display = toast.display
		local inks = loaded.ns.ToastInks(loaded.ns.DisplayStyle(display), loaded.ns.ToastPage(display.announcement))
		return rgb(loaded.ns.ANNOUNCE_COLORS[inks.name])
	end

	it(
		"shows the variety's art cropped to the fish's head in the medallion in place of the item icon, its ring in the"
			.. " rarity's colour but Common's the style's own (#424, VAR-R26)",
		function()
			local loaded, M = loadCore()
			local seen = {}
			for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
				local toast = raiseRecord(loaded, M, rarity.key)
				assert.are.same(
					{ ART.texture, { loaded.ns.HeadCrop(ART) } },
					{ toast.icon.texture, toast.icon.texCoord }
				)
				seen[#seen + 1] = { toast.bezel.Ring.desaturated == true, rgb(toast.bezel.Ring.vertexColor) }
				loaded.client.advance(TOAST + LEAVE_TOAST)
			end

			local expected = {}
			for i, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
				expected[i] = { i > 1, i > 1 and rgb(rarity.color) or { 1, 1, 1 } }
			end
			assert.are.same(expected, seen)
		end
	)

	it(
		"names the fish alone, then the variety after a gem in its colour in its rarity's ink, the first half staying in"
			.. " the style's ink (#424, VAR-R26, ANN-R80)",
		function()
			local loaded, M = loadCore()
			local rare = rarityOf(loaded, "rare")

			local toast = raiseRecord(loaded, M, "rare")

			assert.are.same({ "SIZE RECORD", FISH .. " ·", "Coral" }, {
				toast.title:GetText(),
				toast.text:GetText(),
				toast.variety:GetText(),
			})
			assert.are.same(
				{ nameInk(loaded, toast), rgb(rare.ink) },
				{ rgb(toast.text.textColor), rgb(toast.variety.textColor) }
			)
			-- The gem: a small square turned to a diamond, rimmed in the ink and filled with the colour.
			assert.are.same({ true, rgb(rare.color), rgb(rare.ink), math.rad(45) }, {
				toast.gem.shown,
				rgb(toast.gem.fill.color),
				rgb(toast.gem.rim.color),
				toast.gem.fill.rotation,
			})
			-- In a row after the fish's name, no longer than the toast.
			assert.are.same({ toast.text, toast.gem }, { toast.gem.points[1][2], toast.variety.points[1][2] })
			assert.are.same({}, bounds.overflows(toast))
		end
	)

	it(
		"writes the size band at the ruler's bottom left in place of LENGTH, the title no longer holding it (#424)",
		function()
			local loaded, M = loadCore()

			local toast = raiseRecord(loaded, M, "common")

			local ruler = toast.ruler
			local page = loaded.ns.ToastPage(toast.display.announcement)
			-- In the toast's bottom left corner, at the text's margin and a little above its edge, not beside the track.
			assert.are.same(
				{ true, "TIDDLER", { "BOTTOMLEFT", toast.body, "BOTTOMLEFT", page.tx, 8 } },
				{ ruler.shown, ruler.label:GetText(), { ruler.label:GetPoint() } }
			)
			assert.are.same({ "TOPLEFT", ruler, "TOPLEFT", 0, -16 }, { ruler.bar:GetPoint() })
			assert.is_nil(toast.text:GetText():find("Tiddler", 1, true))
		end
	)

	it(
		"centres the kicker and name block down a toast with no ruler, as its medallion is, and leaves a ruled toast's"
			.. " block where it was (#424)",
		function()
			local loaded, M = loadCore()
			local variety = moment("toast", "Rare variety", {
				kind = "rareVariety",
				order = 105,
				text = "Coral",
				icon = ITEM,
				cast = CAST,
				art = ART,
				variety = { name = "Coral", rarity = "rare" },
			})
			raise(loaded, M, variety)
			local toast = frameOf(loaded, "toast") --[[@as table]]
			local page = loaded.ns.ToastPage(toast.display.announcement)

			-- The kicker's and the name line's measured heights (the fake's are one flat 14) and a gap of 5: a block
			-- about the page's middle, to a pixel.
			local top = -select(5, toast.title:GetPoint())
			assert.is_true(math.abs(top + (14 + 5 + 14) / 2 - page.h / 2) < 1)
			assert.are.same({ "TOPLEFT", toast.title, "BOTTOMLEFT", 0, -5 }, { toast.text:GetPoint() })
			-- The gem and the name sit on the name line's own middle, with no offset of their own.
			assert.are.same({ "LEFT", toast.text, "RIGHT", 0, 0 }, { toast.gem:GetPoint() })
			assert.are.same({ "LEFT", toast.gem, "RIGHT", 3, 0 }, { toast.variety:GetPoint() })
			-- The gem grows with the name's font from the Nod's 10 units at its 22.
			assert.is_true(math.abs(toast.gem.width - 10 * 31 / 22) < 0.01)
			assert.is_true(math.abs(toast.gem.width - toast.gem.height) < 0.001)

			loaded.client.advance(TOAST + LEAVE_TOAST)
			local ruled = raiseRecord(loaded, M, "common")
			local ruledPage = loaded.ns.ToastPage(ruled.display.announcement)
			assert.are.equal(ruledPage.ty, -select(5, ruled.title:GetPoint()))
		end
	)

	it(
		"sets the kicker in the same print face at 16, not 13, and centres the block by what its lines measure, not by"
			.. " their fonts' sizes (#467)",
		function()
			local loaded, M = loadCore()
			raise(loaded, M, moment("toast", "New Species", { text = "Nightfin Snapper", icon = ITEM, cast = CAST }))
			local toast = frameOf(loaded, "toast") --[[@as table]]
			local page = loaded.ns.ToastPage(toast.display.announcement)
			-- The client's lines are taller than their fonts' sizes and differ by face: the kicker's 20 and the name's 42.
			toast.title.GetStringHeight = function()
				return 20
			end
			toast.text.GetStringHeight = function()
				return 42
			end

			loaded.ns.DrawAnnouncement(toast, toast.display)

			assert.are.equal(loaded.ns.ART_FONTS.What, toast.title.fontObject)
			assert.is_true(loaded.ns.ArtFontSize("What") >= 16 and loaded.ns.ArtFontSize("What") <= 17)
			local top = -select(5, toast.title:GetPoint())
			assert.is_true(math.abs(top - (page.h - (20 + 5 + 42)) / 2) < 0.01)
			-- Not where the nominal 16 + 5 + 31 would put it.
			assert.is_true(math.abs(top - (page.h - (16 + 5 + 31)) / 2) > 1)
		end
	)

	-- Draws the toast `raised` has put up measured as the client does, its lines taller than their fonts' sizes and
	-- growing with them (a kicker 1.25 a unit of its font, a name line 42/31), a kicker's letters 0.62 a unit wide, a
	-- name's 0.4 and a stamp's 0.62. Returns it, drawn again, then leaves it.
	local function measuredToast(loaded)
		local toast = frameOf(loaded, "toast") --[[@as table]]
		local function size(fontString, nominal)
			return fontString.font and fontString.font[2] or nominal
		end
		local nominal = loaded.ns.ArtFontSize
		toast.title.GetStringHeight = function(self)
			return 1.25 * size(self, nominal("What"))
		end
		toast.title.GetStringWidth = function(self)
			return #(self.text or "") * 0.62 * size(self, nominal("What"))
		end
		for _, line in ipairs({ toast.text, toast.variety }) do
			line.GetStringHeight = function(self)
				return 42 / 31 * size(self, nominal("Name"))
			end
			line.GetStringWidth = function(self)
				return #(self.text or "") * 0.4 * size(self, nominal("Name"))
			end
		end
		for _, stamp in ipairs(toast.stamps) do
			stamp.label.GetStringWidth = function(self)
				return #(self.text or "") * 0.62 * (self.font and self.font[2] or 11)
			end
		end
		loaded.ns.DrawAnnouncement(toast, toast.display)
		return toast
	end

	-- Where the Torn Page's red ruling line runs down the toast page at the kicker (the ToastsLedger texture's rule:
	-- 33.5 units from the page's top at the kicker's left, 31 at its right), and how far down its 20-unit line a
	-- 16-unit kicker's letters stand, their baseline.
	local TORN_RULE, BASELINE = 31, 15

	it(
		"keeps the kicker where it is on the toast page, its baseline above the page's ruling line, whether stamps ride"
			.. " on the toast, its name line stepped down or its own font stepped down for the stamps, the name line"
			.. " staying where the block as written puts it",
		function()
			local loaded, M = loadCore()
			local page = loaded.ns.ToastPage({ headline = { rung = "toast" } } --[[@as table]])
			local What, Name = loaded.ns.ArtFontSize("What"), loaded.ns.ArtFontSize("Name")
			-- Raises `moments`, draws their toast measured, and reads where its kicker and name line are.
			local function drawn(...)
				raise(loaded, M, ...)
				local toast = measuredToast(loaded)
				local top = -select(5, toast.title:GetPoint())
				local read = {
					toast = toast,
					top = top,
					kicker = toast.title.font and toast.title.font[2] or What,
					name = toast.text.font and toast.text.font[2] or Name,
					-- The name line's top down the page, from its anchor under the kicker's foot.
					nameTop = top + toast.title:GetStringHeight() - select(5, toast.text:GetPoint()),
					stamps = 0,
				}
				for _, stamp in ipairs(toast.stamps) do
					read.stamps = read.stamps + (stamp.shown and 1 or 0)
				end
				loaded.client.advance(TOAST + LEAVE_TOAST)
				return read
			end
			-- The page centres the kicker, 1.25 a unit of its font, over a name line of 42, as they measure.
			local nominal = (page.h - (1.25 * What + 5 + 42)) / 2
			local function standsClear(read)
				assert(read.top + BASELINE <= TORN_RULE - 2, "the kicker's baseline is " .. read.top + BASELINE)
			end

			local alone = drawn(moment("toast", "New Species", { text = "Pike", icon = ITEM, cast = CAST }))
			assert.are.same({ 0, What, Name }, { alone.stamps, alone.kicker, alone.name })
			assert(math.abs(alone.top - nominal) < 1e-6, "the kicker is " .. alone.top)
			assert.is_true(math.abs(alone.nameTop - (alone.top + 1.25 * What + 5)) < 1e-6)
			standsClear(alone)

			-- A long name that steps its line down to fit, with two stamps riding: the kicker has not moved. The name
			-- line stays as the block as written is centred, lower than under the kicker by what the kicker is above it.
			local long = "Raw Bristle Whisker Catfish"
			local stamped = drawn(
				moment("toast", "New Species", { text = long, icon = ITEM, cast = CAST }),
				moment("nod", "New variety", { cast = CAST, stamp = "New variety" }),
				moment("nod", "Rank up", { cast = CAST, stamp = "Rank up" })
			)
			assert.are.same({ 2, What }, { stamped.stamps, stamped.kicker })
			assert(stamped.name < Name and stamped.name >= 22, "the name line is " .. stamped.name)
			assert.are.equal(alone.top, stamped.top)
			standsClear(stamped)
			local laid = (page.h - (1.25 * What + 5 + 42 / 31 * stamped.name)) / 2
			assert.is_true(math.abs(stamped.nameTop - (laid + 1.25 * What + 5)) < 1e-6)
			assert.is_true(stamped.nameTop > alone.nameTop)

			-- A long size kicker beside a second stamp steps the kicker's own font down: its top stays too.
			local own = drawn(
				moment("toast.low", "New variety", {
					kind = "newVariety",
					order = 120,
					text = "Coral",
					stamp = "New variety",
					icon = ITEM,
					cast = CAST,
					ownStamp = true,
					kicker = "Trophy · 123.4 cm",
					variety = { name = "Coral", rarity = "common", fish = "Cat" },
				}),
				moment("nod", "New here", { cast = CAST, stamp = "New here" })
			)
			assert(own.kicker < What and own.kicker >= 13, "the kicker is " .. own.kicker)
			assert.are.equal(alone.top, own.top)
			standsClear(own)

			-- A ruled toast's words start at the page's own top, as the same rule runs down its page.
			local ruled = loaded.ns.ToastPage({ headline = { rung = "toast", ruler = {} } } --[[@as table]])
			assert.is_true(ruled.ruled and ruled.ty + BASELINE <= TORN_RULE - 2)
		end
	)

	-- The width a font string measures at its font's size, as the client's grow with it: 0.4 a character a unit.
	local function measureBySize(...)
		for _, fontString in ipairs({ ... }) do
			fontString.GetStringWidth = function(self)
				return #(self.text or "") * 0.4 * (self.font and self.font[2] or 31)
			end
		end
	end

	-- Draws a catch toast naming `variety` after `fish`, its words measured by size, and returns its frame. Its name
	-- line has 292 units: the page's 464, less the words' left (138) and a margin of 34.
	local function drawCatch(loaded, fish, variety)
		loaded.ns.moments:RaiseCatchToast({
			rung = "toast.low",
			kind = "catch",
			title = "Decent · 34.2 cm",
			text = fish,
			nodLine = fish .. " · " .. variety,
			icon = ITEM,
			cast = CAST,
			variety = { name = variety, rarity = "uncommon", before = fish .. " ·", after = "· Decent · 34.2 cm" },
		})
		loaded.client.advance(0)
		local toast = frameOf(loaded, "toast") --[[@as table]]
		measureBySize(toast.title, toast.text, toast.variety)
		loaded.ns.DrawAnnouncement(toast, toast.display)
		return toast
	end

	-- A font string's font size, for a name line's.
	local function sizeOf(fontString)
		return fontString.font[2]
	end

	it(
		"steps the name line's font down before it cuts either name, the fish's name whole while sizes remain (#467,"
			.. " VAR-R28)",
		function()
			local loaded = loadCore()

			local toast = drawCatch(loaded, "Bristle Cat", "Longwhisker")

			local fish, variety = toast.text, toast.variety
			-- The fake counts bytes: "Bristle Cat ·" is 14 and "Longwhisker" 11, at 0.4 a unit a size. At the Name
			-- font's 31 the two are 310 with the gem and its gaps on top, over the toast's 292 for words; 27 is the
			-- largest size that fits.
			assert.are.same({ 27, 27, "Bristle Cat ·" }, { sizeOf(fish), sizeOf(variety), fish:GetText() })
			assert.are.equal(14 * 0.4 * 27, fish:GetWidth())
			assert.are.equal(11 * 0.4 * 27, variety:GetWidth())
			-- The gem shrank with the font.
			assert.is_true(math.abs(toast.gem.width - 10 * 27 / 22) < 0.01)
		end
	)

	it(
		"keeps the fish's name whole at the smallest font and cuts the variety's name first when the line still"
			.. " doesn't fit (#467, VAR-R28)",
		function()
			local loaded = loadCore()

			local toast = drawCatch(loaded, ("F"):rep(19), ("V"):rep(20))

			local fish, variety = toast.text, toast.variety
			-- 22 is the floor of the Name font's 31 (70%).
			assert.are.same({ 22, 22 }, { sizeOf(fish), sizeOf(variety) })
			assert.are.equal(#fish:GetText() * 0.4 * 22, fish:GetWidth())
			assert.is_true(variety:GetWidth() < 20 * 0.4 * 22 and variety:GetWidth() >= 48)
			assert.is_true(fish:GetWidth() + 6 + toast.gem.width + 3 + variety:GetWidth() <= 292 + 0.01)
		end
	)

	it(
		"cuts the fish's name only as a last resort: when the variety's name is down to its floor and the line still"
			.. " doesn't fit (#467, VAR-R28)",
		function()
			local loaded = loadCore()

			local toast = drawCatch(loaded, ("F"):rep(30), ("V"):rep(14))

			local fish, variety = toast.text, toast.variety
			assert.are.equal(48, variety:GetWidth())
			assert.is_true(fish:GetWidth() < #fish:GetText() * 0.4 * 22)
			assert.is_true(fish:GetWidth() + 6 + toast.gem.width + 3 + variety:GetWidth() <= 292 + 0.01)
		end
	)

	it("leaves a name line that fits at its font's full size, the Name font's 31 (#467)", function()
		local loaded = loadCore()

		local toast = drawCatch(loaded, "Coral", "Fin")

		assert.are.same({ 31, 31 }, { sizeOf(toast.text), sizeOf(toast.variety) })
		assert.are.equal(#toast.text:GetText() * 0.4 * 31, toast.text:GetWidth())
	end)

	it(
		"keeps a ruled toast's name line clear of the ruler's numbers, cutting the fish's name when the variety's short"
			.. " name has no room to give (#424, #467)",
		function()
			local loaded, M = loadCore()
			local record, variety = recordAndVariety("rare")
			record.text = "Raw Bristle Whisker Catfish of the Deep Reaches"

			raise(loaded, M, record, variety)
			local toast = frameOf(loaded, "toast") --[[@as table]]

			local page = loaded.ns.ToastPage(toast.display.announcement)
			local natural = #toast.text:GetText() * 6
			-- The fish's name is held short of its length; the variety's stays whole and the gem keeps its place.
			assert.is_true(toast.text.width < natural)
			assert.are.equal("Coral", toast.variety:GetText())
			-- The whole line ends before the landed number, which stands at the track's 1/1.1.
			local right = page.tx + toast.text.width + 6 + toast.gem.width + 3 + #"Coral" * 6
			assert.is_true(right <= page.tx + toast.ruler.trackWidth / 1.1)
		end
	)

	-- Measures the stamps' words and the kicker as the client does: a letter is 0.62 of the font's size wide, so a
	-- larger font is wider and a smaller one narrower. Returns the toast, drawn again.
	local function measuredBySize(loaded, toast)
		local function measure(label)
			label.GetStringWidth = function(self)
				return #(self.text or "") * 0.62 * (self.font and self.font[2] or 11)
			end
		end
		for _, stamp in ipairs(toast.stamps) do
			measure(stamp.label)
		end
		measure(toast.ruler.record.label)
		toast.title.GetStringWidth = function(self)
			return #(self.text or "") * 0.62 * (self.font and self.font[2] or loaded.ns.ArtFontSize("What"))
		end
		loaded.ns.DrawAnnouncement(toast, toast.display)
		return toast
	end

	it(
		"steps the kicker down from 16 only as far as a stamp row needs, never letting the stamps reach it, for an own"
			.. " stamp with a long size kicker and a second stamp, or a ruled toast with its New record stamp (#467)",
		function()
			local loaded, M = loadCore()
			local function leftEdge(toast)
				local lefts = {}
				for i, stamp in ipairs(toast.stamps) do
					if stamp.shown then
						lefts[#lefts + 1] = select(4, toast.pivots[i]:GetPoint()) - stamp:GetWidth() / 2
					end
				end
				if toast.ruler.record.shown ~= false and toast.display.announcement.headline.ruler then
					lefts[#lefts + 1] = select(4, toast.recordPivot:GetPoint()) - toast.ruler.record:GetWidth() / 2
				end
				table.sort(lefts)
				return lefts[1]
			end
			local function kickerRight(toast)
				local page = loaded.ns.ToastPage(toast.display.announcement)
				return page.tx + toast.title:GetWidth()
			end

			-- A Common variety's own toast, its kicker the size text, and a second stamp riding on it.
			local own = moment("toast.low", "New variety", {
				kind = "newVariety",
				order = 120,
				text = "Coral",
				stamp = "New variety",
				icon = ITEM,
				cast = CAST,
				ownStamp = true,
				kicker = "Trophy · 123.4 cm",
				variety = { name = "Coral", rarity = "common", fish = "Cat" },
			})
			raise(loaded, M, own, moment("nod", "New here", { cast = CAST, stamp = "New here" }))
			local toast = measuredBySize(loaded, frameOf(loaded, "toast") --[[@as table]])
			local size = toast.title.font[2]
			assert.are.same({ "TROPHY · 123.4 CM", "NEW VARIETY", "NEW HERE" }, {
				toast.title:GetText(),
				toast.stamps[1].label:GetText(),
				toast.stamps[2].label:GetText(),
			})
			assert(size < 16 and size >= 13, "the kicker is " .. size)
			assert(
				leftEdge(toast) >= kickerRight(toast) + 10,
				("%.1f from %.1f"):format(leftEdge(toast), kickerRight(toast))
			)
			-- The block is still centred, for the kicker as it now is.
			local page = loaded.ns.ToastPage(toast.display.announcement)
			assert.is_true(math.abs(-select(5, toast.title:GetPoint()) - (page.h - (14 + 5 + 14)) / 2) < 0.01)
			loaded.client.advance(TOAST + LEAVE_TOAST)

			-- Alone, the same kicker keeps its 16: the stamp has room.
			raise(loaded, M, own)
			toast = measuredBySize(loaded, frameOf(loaded, "toast") --[[@as table]])
			assert.are.equal(16, toast.title.font and toast.title.font[2] or 16)
			assert.is_true(leftEdge(toast) >= kickerRight(toast) + 10)
			loaded.client.advance(TOAST + LEAVE_TOAST)

			-- A ruled toast: the size record's kicker with its New record stamp and a riding New variety.
			local record, variety = recordAndVariety("common")
			raise(loaded, M, record, variety)
			toast = measuredBySize(loaded, frameOf(loaded, "toast") --[[@as table]])
			assert(
				leftEdge(toast) >= kickerRight(toast) + 10,
				("%.1f from %.1f"):format(leftEdge(toast), kickerRight(toast))
			)
		end
	)

	it("hangs three stamps and the New record stamp clear of the kicker, squeezing them to fit (#424)", function()
		local loaded, M = loadCore()
		local record, variety = recordAndVariety("common")
		local here = moment("nod", "New here", { cast = CAST, stamp = "New here" })
		raise(loaded, M, record, variety, here)
		local toast = frameOf(loaded, "toast") --[[@as table]]
		-- The fake client measures a word at a flat 6 units a letter; the client's grow with the font. Measure as it
		-- does, so a smaller font makes a narrower stamp, and the kicker as wide as the print is.
		local function measure(label)
			label.GetStringWidth = function(self)
				return #(self.text or "") * 0.62 * (self.font and self.font[2] or 11)
			end
		end
		for _, stamp in ipairs(toast.stamps) do
			measure(stamp.label)
		end
		measure(toast.ruler.record.label)
		toast.title.GetStringWidth = function(self)
			return #(self.text or "") * 8.5
		end

		loaded.ns.DrawAnnouncement(toast, toast.display)

		local page = loaded.ns.ToastPage(toast.display.announcement)
		local kickerRight = page.tx + toast.title:GetWidth()
		local lefts, sizes = {}, {}
		local function note(stamp, pivot)
			local x = select(4, pivot:GetPoint())
			lefts[#lefts + 1] = x - stamp:GetWidth() / 2
			sizes[#sizes + 1] = stamp.label.font and stamp.label.font[2] or 11
		end
		local shown = 0
		for i, stamp in ipairs(toast.stamps) do
			if stamp.shown then
				shown = shown + 1
				note(stamp, toast.pivots[i])
			end
		end
		note(toast.ruler.record, toast.recordPivot)
		assert.are.equal(2, shown)
		table.sort(lefts)
		assert.are.equal(
			true,
			lefts[1] >= kickerRight,
			("the row starts at %.1f, the kicker ends at %.1f"):format(lefts[1], kickerRight)
		)
		-- Squeezed, not dropped: every word still shows, in a smaller font.
		for _, size in ipairs(sizes) do
			assert.is_true(size < 11 and size >= 8)
		end
		assert.are.same(
			{ "NEW VARIETY", "NEW HERE" },
			{ toast.stamps[1].label:GetText(), toast.stamps[2].label:GetText() }
		)
	end)

	it(
		"draws a catch toast's variety caught before with the item's icon in the medallion, not the art, and the ring"
			.. " and name in the rarity's colour and ink, a gleam for Rare, and no New variety stamp (#437, #469, VAR-R26,"
			.. " VAR-R28)",
		function()
			local loaded = loadCore()
			local rare = rarityOf(loaded, "rare")

			loaded.ns.moments:RaiseCatchToast({
				rung = "toast.low",
				kind = "catch",
				title = "Decent · 34.2 cm",
				text = FISH,
				nodLine = FISH .. " · Coral · Decent · 34.2 cm",
				icon = ITEM,
				cast = CAST,
				variety = { name = "Coral", rarity = "rare", before = FISH .. " ·", after = "· Decent · 34.2 cm" },
			})
			loaded.client.advance(0)
			local toast = frameOf(loaded, "toast") --[[@as table]]

			assert.are.same({ "DECENT · 34.2 CM", FISH .. " ·", "Coral" }, {
				toast.title:GetText(),
				toast.text:GetText(),
				toast.variety:GetText(),
			})
			-- The variety's art fills a medallion only on its own toast (VAR-R25): here the item, on no disc.
			assert.are.same({ ITEM, false }, { toast.icon.texture, toast.bezel.Back ~= nil and toast.bezel.Back.shown })
			assert.are.same(
				{ true, rgb(rare.color) },
				{ toast.bezel.Ring.desaturated == true, rgb(toast.bezel.Ring.vertexColor) }
			)
			assert.are.same({ true, rgb(rare.ink) }, { toast.gem.shown, rgb(toast.variety.textColor) })
			assert.is_true(toast.gleams)
			assert.are.same({}, stampsOf(toast))
			assert.are.same({}, bounds.overflows(toast))
		end
	)

	it(
		"puts an opaque round disc, deep water tinted by the rarity, behind the art across the medallion's face, and"
			.. " takes it away for the next toast's item icon (#424)",
		function()
			local loaded, M = loadCore()

			local toast = raiseRecord(loaded, M, "rare")

			-- The 84 medallion of a toast's page has a face 62 across; the rare tint: 15% of its blue (0, 112, 221) over
			-- the water.
			local back = toast.bezel.Back
			assert.are.same({ true, 62, 62 }, { back.shown, back.width, back.height })
			assert.is_true(back.masks ~= nil and #back.masks == 1)
			local expected = { 0.0595, 0.12 * 0.85 + (112 / 255) * 0.15, 0.18 * 0.85 + (221 / 255) * 0.15 }
			for i = 1, 3 do
				assert.is_true(math.abs(back.color[i] - expected[i]) < 0.001)
			end
			assert.are.equal(1, back.color[4])

			loaded.client.advance(TOAST + LEAVE_TOAST)
			raise(loaded, M, moment("toast", "New Species", { text = "Nightfin Snapper", icon = ITEM }))
			local after = frameOf(loaded, "toast") --[[@as table]]
			assert.are.same({ toast, false, ITEM }, { after, after.bezel.Back.shown, after.icon.texture })
		end
	)

	it("keeps every other ruler's own label (ANN-R22)", function()
		local loaded, M = loadCore()

		raise(
			loaded,
			M,
			moment("toast", "Trophy weight", { ruler = { old = 10, new = 12, unit = "lb", label = "weight" } })
		)

		assert.are.equal("WEIGHT", frameOf(loaded, "toast").ruler.label:GetText())
	end)

	it(
		"inks the New variety stamp and its border in the rarity's ink and no other stamp, and a toast after it in"
			.. " the style's (#424, VAR-R26, ANN-R80)",
		function()
			local loaded, M = loadCore()
			local epic = rarityOf(loaded, "epic")
			local record, variety = recordAndVariety("epic")
			local here = moment("nod", "New here", { cast = CAST, stamp = "New here" })

			raise(loaded, M, record, variety, here)
			local toast = frameOf(loaded, "toast") --[[@as table]]

			local inked = {}
			for _, stamp in ipairs(toast.stamps) do
				if stamp.shown then
					inked[stamp.label:GetText()] = {
						rgb(stamp.label.textColor),
						stamp.border.left.desaturated == true,
						rgb(stamp.border.left.vertexColor),
					}
				end
			end
			local style = loaded.ns.DisplayStyle(toast.display)
			assert.are.same({ rgb(epic.ink), true, rgb(epic.ink) }, inked["NEW VARIETY"])
			assert.are.same({ rgb(loaded.ns.ANNOUNCE_COLORS[style.stampInk]), false, { 1, 1, 1 } }, inked["NEW HERE"])

			-- The frame goes on to another toast: its stamps are inked as the style has them, whatever it was.
			loaded.client.advance(TOAST + LEAVE_TOAST)
			raise(
				loaded,
				M,
				moment("toast", "New Species", { text = "Nightfin Snapper", cast = CAST }),
				moment("nod", "New variety", { stamp = "New variety", cast = CAST })
			)
			local after = frameOf(loaded, "toast") --[[@as table]]
			assert.are.equal(toast, after)
			local reset = {}
			for _, stamp in ipairs(after.stamps) do
				if stamp.shown then
					reset[#reset + 1] = {
						stamp.label:GetText(),
						stamp.border.left.desaturated == true,
						rgb(stamp.border.left.vertexColor),
						rgb(stamp.label.textColor),
					}
				end
			end
			assert.are.same(
				{ { "NEW VARIETY", false, { 1, 1, 1 }, rgb(loaded.ns.ANNOUNCE_COLORS[style.stampInk]) } },
				reset
			)
		end
	)

	it("writes a variety's toast with no fish's name to give as the gem and name alone (#424)", function()
		local loaded, M = loadCore()
		local rare = rarityOf(loaded, "rare")
		local variety = moment("toast", "Rare variety", {
			kind = "rareVariety",
			order = 105,
			text = "Coral",
			icon = ITEM,
			cast = CAST,
			art = ART,
			variety = { name = "Coral", rarity = "rare" },
		})

		raise(loaded, M, variety)
		local toast = frameOf(loaded, "toast") --[[@as table]]

		assert.are.same({ "RARE VARIETY", "", "Coral", true, ART.texture }, {
			toast.title:GetText(),
			toast.text:GetText(),
			toast.variety:GetText(),
			toast.gem.shown,
			toast.icon.texture,
		})
		assert.are.same(
			{ rgb(rare.ink), rgb(rare.color) },
			{ rgb(toast.variety.textColor), rgb(toast.bezel.Ring.vertexColor) }
		)
		assert.are.same({}, stampsOf(toast))
	end)

	it("names and colours no variety on a toast with no first-catch variety moment (VAR-R27)", function()
		local loaded, M = loadCore()
		raiseRecord(loaded, M, "rare")
		loaded.client.advance(TOAST + LEAVE_TOAST)

		raise(loaded, M, moment("toast.low", "Size record", { text = FISH, icon = ITEM }))

		local toast = frameOf(loaded, "toast") --[[@as table]]
		assert.are.same({ FISH, false, false, ITEM, false, { 1, 1, 1 } }, {
			toast.text:GetText(),
			toast.gem.shown,
			toast.variety.shown,
			toast.icon.texture,
			toast.bezel.Ring.desaturated == true,
			rgb(toast.bezel.Ring.vertexColor),
		})
		assert.are.same(nameInk(loaded, toast), rgb(toast.text.textColor))
	end)

	it(
		"sweeps one gleam across a Rare or Epic variety's toast as it enters, in the rarity's colour, added on, then"
			.. " gone; none for Common or Uncommon, nor with Animations off (VAR-R26)",
		function()
			local function sweep(rarity, motion)
				local loaded, M = loadCore()
				loaded.ns.db.profile.announcements.motion = motion
				local toast = raiseRecord(loaded, M, rarity)
				local peak, xs = toast.gleam.alpha or 0, {}
				for _ = 1, 240 do
					loaded.client.update(1 / 60)
					peak = math.max(peak, toast.gleam.alpha or 0)
					xs[#xs + 1] = toast.gleam.points[1] and toast.gleam.points[1][4]
				end
				return { peak = peak, xs = xs, gleam = toast.gleam, loaded = loaded }
			end

			for _, key in ipairs({ "rare", "epic" }) do
				local seen = sweep(key, true)
				assert.is_true(seen.peak > 0.5)
				assert.are.same({ 0, "ADD", true, rgb(rarityOf(seen.loaded, key).color) }, {
					seen.gleam.alpha,
					seen.gleam.blendMode,
					seen.gleam.desaturated,
					rgb(seen.gleam.vertexColor),
				})
			end
			for _, case in ipairs({ { "common", true }, { "uncommon", true }, { "rare", false } }) do
				assert.are.equal(0, sweep(case[1], case[2]).peak)
			end
		end
	)
end)

describe("a new variety's own toast on the client (#422, VAR-R25, VAR-R28, ANN-R11)", function()
	local ART = {
		texture = "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
		left = 0.09375,
		right = 0.1875,
		top = 0,
		bottom = 0.046875,
	}
	local ITEM = 6291
	local FISH = "Raw Bristle Whisker Catfish"
	local KICKER = "Decent · 34.2 cm"

	local function rarityOf(loaded, key)
		for _, rarity in ipairs(loaded.ns.VARIETY_RARITIES) do
			if rarity.key == key then
				return rarity
			end
		end
		error("no rarity " .. key)
	end

	local function rgb(color)
		return { color[1], color[2], color[3] }
	end

	-- The moment the Ledger raises for a first catch of Coral, a variety of `rarity` (LED-R97).
	local function variety(rarity)
		local rare = rarity == "rare"
		return moment(rare and "toast" or "toast.low", rare and "Rare variety" or "New variety", {
			kind = rare and "rareVariety" or "newVariety",
			order = rare and 105 or 120,
			text = "Coral",
			stamp = not rare and "New variety" or nil,
			icon = ITEM,
			cast = CAST,
			art = ART,
			ownStamp = true,
			kicker = KICKER,
			variety = { name = "Coral", rarity = rarity, fish = FISH },
		})
	end

	-- The stamps a toast shows as { text, ink, border tint }, by text.
	local function inkedStamps(toast)
		local inked = {}
		for _, stamp in ipairs(toast.stamps) do
			if stamp.shown then
				inked[stamp.label:GetText()] = {
					rgb(stamp.label.textColor),
					stamp.border.left.desaturated == true,
					rgb(stamp.border.left.vertexColor),
				}
			end
		end
		return inked
	end

	it(
		"is drawn on the default toast page, the size as its kicker, the fish's name then the gem and the variety on its"
			.. " line, and its stamp top right in the rarity's ink, all within the page (#422)",
		function()
			local loaded, M = loadCore()
			for _, key in ipairs({ "common", "uncommon", "rare" }) do
				local rarity = rarityOf(loaded, key)

				raise(loaded, M, variety(key))
				local toast = frameOf(loaded, "toast") --[[@as table]]
				local page = loaded.ns.ToastPage(toast.display.announcement)

				assert.are.same(
					{ "toast", 464, 92, 84 },
					{ page.page, toast:GetWidth(), toast:GetHeight(), page.bezel }
				)
				assert.are.same({ "DECENT · 34.2 CM", FISH .. " ·", "Coral" }, {
					toast.title:GetText(),
					toast.text:GetText(),
					toast.variety:GetText(),
				})
				assert.are.same(
					{ rgb(rarity.ink), rgb(rarity.color), true },
					{ rgb(toast.variety.textColor), rgb(toast.gem.fill.color), toast.gem.shown }
				)
				assert.are.same(
					{ ART.texture, { loaded.ns.HeadCrop(ART) } },
					{ toast.icon.texture, toast.icon.texCoord }
				)
				-- Its one stamp, inked in the rarity's ink, hangs from the top right, clear of the kicker.
				local word = key == "rare" and "RARE VARIETY" or "NEW VARIETY"
				assert.are.same({ word }, stampsOf(toast))
				assert.are.same({ [word] = { rgb(rarity.ink), true, rgb(rarity.ink) } }, inkedStamps(toast))
				local x, y = select(4, toast.pivots[1]:GetPoint())
				assert.is_true(x > page.w - 30 - toast.stamps[1]:GetWidth() - 1 and x <= page.w - 30)
				assert.is_true(y > -20 and y < 0)
				assert.is_true(x - toast.stamps[1]:GetWidth() / 2 >= page.tx + toast.title:GetWidth())
				assert.are.same({}, bounds.overflows(toast))
				-- The title still names the moment, for the Session summary and the cards.
				assert.are.equal(
					key == "rare" and "Rare variety" or "New variety",
					toast.display.announcement.headline.title
				)

				loaded.client.advance(TOAST + LEAVE_TOAST)
			end
		end
	)

	it("holds for a toast page's 6 s, not a toast.low's 4 (#422, ANN-R20)", function()
		local loaded, M = loadCore()

		raise(loaded, M, variety("common"))
		loaded.client.advance(TOAST - 0.1)
		assert.is_true(showing(loaded, "toast"))
		loaded.client.advance(0.1)

		assert.is_false(showing(loaded, "toast"))
	end)

	it("keeps a Rare one's gleam, and none for Common or Uncommon (VAR-R28)", function()
		local loaded, M = loadCore()
		local gleams = {}
		for _, key in ipairs({ "common", "uncommon", "rare" }) do
			raise(loaded, M, variety(key))
			gleams[#gleams + 1] = frameOf(loaded, "toast").gleams
			loaded.client.advance(TOAST + LEAVE_TOAST)
		end

		assert.are.same({ false, false, true }, gleams)
	end)

	it(
		"shows the stamps of the moments riding on it beside its own, merging an identical one (#422, ANN-R11)",
		function()
			local loaded, M = loadCore()
			local here = moment("nod", "New here", { cast = CAST, stamp = "New here" })
			local twin = moment("nod", "New variety", { cast = CAST, stamp = "New variety" })
			local stars = moment("nod", "Regular", { cast = CAST, stamp = "★★★", order = 130 })

			raise(loaded, M, variety("uncommon"), here, twin, stars)
			local toast = frameOf(loaded, "toast") --[[@as table]]

			assert.are.same({ "NEW VARIETY", "NEW HERE", "★★★" }, stampsOf(toast))
			local uncommon = rarityOf(loaded, "uncommon")
			local inked = inkedStamps(toast)
			assert.are.same(rgb(uncommon.ink), inked["NEW VARIETY"][1])
			assert.are_not.same(rgb(uncommon.ink), inked["NEW HERE"][1])
			assert.are.same({}, bounds.overflows(toast))
		end
	)

	it("counts in the 4 stamps shown, the rest as +N (#422, ANN-R11)", function()
		local loaded, M = loadCore()
		local riding = {}
		for i = 1, 4 do
			riding[i] = moment("nod", "Rider " .. i, { cast = CAST, stamp = "R" .. i, order = 130 + i })
		end

		raise(loaded, M, variety("common"), unpack(riding))

		assert.are.same({ "NEW VARIETY", "R1", "R2", "R3", "+1" }, stampsOf(frameOf(loaded, "toast")))
	end)

	it(
		"draws the variety riding on a size record as it was: the record's page, title and kicker, the stamp riding (#424)",
		function()
			local loaded, M = loadCore()
			local record = moment("toast.low", "Size record", {
				kind = "sizeRecord",
				order = 100,
				text = FISH,
				stamp = "Record",
				icon = ITEM,
				cast = CAST,
				ruler = { old = 303, new = 304, unit = "length", label = "Tiddler" },
			})

			raise(loaded, M, record, variety("common"))
			local toast = frameOf(loaded, "toast") --[[@as table]]

			assert.are.same({ "toast-ruled", "SIZE RECORD", { "NEW VARIETY" } }, {
				loaded.ns.ToastPage(toast.display.announcement).page,
				toast.title:GetText(),
				stampsOf(toast),
			})
			assert.are.equal(FISH .. " ·", toast.text:GetText())
		end
	)

	it(
		"steps a lone Common one down to its old Nod, with the budget spent: no kicker, no own stamp (#422, ANN-R31)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.announcements.budget.count = 0

			raise(loaded, M, variety("common"))
			local nod = frameOf(loaded, "nod") --[[@as table]]

			assert.are.same({ "NEW VARIETY", "Coral", {} }, { nod.title:GetText(), nod.text:GetText(), stampsOf(nod) })
		end
	)

	it("keeps its stamps beside a stepped-down Nod's riding ones only (#422)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.budget.count = 0
		local stars = moment("nod", "Trophy family", { cast = CAST, stamp = "★★", order = 130 })

		raise(loaded, M, variety("common"), stars)

		assert.are.same({ "★★" }, stampsOf(frameOf(loaded, "nod")))
	end)

	it("goes to the Session summary as it was: its title, not its kicker (#422, ANN-R25)", function()
		local loaded, M, summarized = loadCore()

		raise(loaded, M, variety("common"))

		assert.are.same({ "New variety", "Coral" }, { summarized[1].title, summarized[1].text })
	end)

	it("leaves a toast after it as the page has it: its kicker the title, no stamp of the variety's (#422)", function()
		local loaded, M = loadCore()
		raise(loaded, M, variety("common"))
		loaded.client.advance(TOAST + LEAVE_TOAST)

		raise(loaded, M, moment("toast", "New Species", { text = "Nightfin Snapper", icon = ITEM, cast = CAST }))
		local toast = frameOf(loaded, "toast") --[[@as table]]

		assert.are.same({ "NEW SPECIES", "Nightfin Snapper", {}, { 464, 92 } }, {
			toast.title:GetText(),
			toast.text:GetText(),
			stampsOf(toast),
			{ toast:GetWidth(), toast:GetHeight() },
		})
		assert.is_false(toast.gem.shown)
	end)
end)

describe("moving the Toast column on the client (ANN-R98)", function()
	-- UIParent is 1920 × 1080 here, so its bottom centre is x 960.
	local SCREEN_WIDTH, SCREEN_HEIGHT = 1920, 1080

	-- A column frame's offset from the column's foot, the anchor it hangs from.
	local function offsetOf(frame)
		local point, anchor, relativePoint, _, y = frame:GetPoint(1)
		assert.are.same({ "BOTTOM", "BOTTOM" }, { point, relativePoint })
		return y, anchor
	end

	-- Where the column's anchor is: its BOTTOM point's offsets from UIParent's bottom centre.
	local function footOf(loaded)
		local point, relativeTo, relativePoint, x, y = loaded.ns.columnAnchor:GetPoint(1)
		assert.are.same({ "BOTTOM", loaded.env.UIParent, "BOTTOM" }, { point, relativeTo, relativePoint })
		return { x = x, y = y }
	end

	-- A column frame's bottom above the screen's bottom: its offset plus the foot's.
	local function bottomOf(loaded, frame)
		local y, anchor = offsetOf(frame)
		assert.are.equal(loaded.ns.columnAnchor, anchor)
		return y + footOf(loaded).y
	end

	-- A press on `frame` that Shift-drags the column and is let go with its foot at (`x`, `y`) from UIParent's bottom
	-- centre, as the client reports the anchor then. Returns whether the drag moved the anchor.
	local function dragColumn(loaded, frame, x, y)
		local anchor = loaded.ns.columnAnchor
		frame.scripts.OnMouseDown(frame, "LeftButton")
		frame.scripts.OnDragStart(frame)
		local moved = anchor.moving == true
		anchor.screenCenter, anchor.screenBottom = { SCREEN_WIDTH / 2 + x, y + 0.5 }, y
		frame.scripts.OnDragStop(frame)
		frame.scripts.OnMouseUp(frame, "LeftButton")
		return moved
	end

	-- Core with a toast with an `onClick` and a Nod showing in the column, and the clicks `onClick` counted.
	local function withColumn()
		local loaded, M = loadCore()
		-- The column settles at once, with no glide to wait out.
		loaded.ns.db.profile.announcements.motion = false
		local clicks = {}
		raise(
			loaded,
			M,
			moment("toast", "Toast", {
				onClick = function()
					clicks[#clicks + 1] = "toast"
				end,
			})
		)
		raise(
			loaded,
			M,
			moment("nod", "Nod", {
				onClick = function()
					clicks[#clicks + 1] = "nod"
				end,
			})
		)
		return loaded, M, clicks, frameOf(loaded, "toast"), frameOf(loaded, "nod")
	end

	it("hangs every toast and Nod off one anchor, at the bottom of the screen with nothing saved", function()
		local loaded, _, _, toast, nod = withColumn()

		assert.are.same({ x = 0, y = 156 }, footOf(loaded))
		assert.are.same({ 156 + 52, 156 }, { bottomOf(loaded, toast), bottomOf(loaded, nod) })
		assert.are.same({ "LeftButton" }, toast.dragButtons)
		assert.are.same({ "LeftButton" }, nod.dragButtons)
	end)

	it("Shift-dragging a toast moves the whole column with it and saves the foot (ANN-R98)", function()
		local loaded, _, _, toast, nod = withColumn()
		loaded.client.keysDown.SHIFT = true

		assert.is_true(dragColumn(loaded, toast, 200, 500))

		assert.are.same({ x = 200, y = 500 }, loaded.ns.db.profile.announcements.point)
		assert.are.same({ x = 200, y = 500 }, footOf(loaded))
		assert.are.same({ 500 + 52, 500 }, { bottomOf(loaded, toast), bottomOf(loaded, nod) })
		assert.is_false(loaded.ns.columnAnchor.moving)
	end)

	it("Shift-dragging a Nod moves it too (ANN-R98)", function()
		local loaded, _, _, _, nod = withColumn()
		loaded.client.keysDown.SHIFT = true

		dragColumn(loaded, nod, -300, 80)

		assert.are.same({ x = -300, y = 80 }, loaded.ns.db.profile.announcements.point)
	end)

	it("never dismisses or runs onClick on the drag's mouse-up, but the next click does (ANN-R20, ANN-R98)", function()
		local loaded, _, clicks, toast, nod = withColumn()
		loaded.client.keysDown.SHIFT = true

		dragColumn(loaded, toast, 200, 500)

		assert.are.same({ "Nod", "Toast" }, columnTitles(loaded))
		assert.are.same({}, clicks)
		nod.scripts.OnMouseDown(nod, "LeftButton")
		nod.scripts.OnMouseUp(nod, "LeftButton")
		assert.are.same({ "Toast" }, columnTitles(loaded))
		assert.are.same({ "nod" }, clicks)
	end)

	it("keeps the mouse-up from clicking when the client sends it before OnDragStop (ANN-R98)", function()
		local loaded, _, clicks, toast = withColumn()
		loaded.client.keysDown.SHIFT = true

		toast.scripts.OnMouseDown(toast, "LeftButton")
		toast.scripts.OnDragStart(toast)
		toast.scripts.OnMouseUp(toast, "LeftButton")
		toast.scripts.OnDragStop(toast)

		assert.are.same({ "Nod", "Toast" }, columnTitles(loaded))
		assert.are.same({}, clicks)
		assert.is_false(loaded.ns.lanes:IsColumnHeld())
	end)

	it(
		"still dismisses and runs onClick for a plain click, and for a Shift-click that never dragged (ANN-R20)",
		function()
			local loaded, _, clicks, toast, nod = withColumn()

			nod.scripts.OnMouseDown(nod, "LeftButton")
			nod.scripts.OnMouseUp(nod, "LeftButton")
			loaded.client.keysDown.SHIFT = true
			toast.scripts.OnMouseDown(toast, "LeftButton")
			toast.scripts.OnMouseUp(toast, "LeftButton")

			assert.are.same({}, columnTitles(loaded))
			assert.are.same({ "nod", "toast" }, clicks)
			assert.is_nil(loaded.ns.db.profile.announcements.point)
		end
	)

	it(
		"moves nothing without Shift: the drag starts no move, and the pointer's let-go clicks as before (ANN-R98)",
		function()
			local loaded, _, clicks, toast = withColumn()

			assert.is_false(dragColumn(loaded, toast, 200, 500))

			assert.is_nil(loaded.ns.db.profile.announcements.point)
			assert.are.same({ x = 0, y = 156 }, footOf(loaded))
			assert.is_false(loaded.ns.lanes:IsColumnHeld())
			assert.are.same({ "toast" }, clicks)
		end
	)

	it("holds the whole column during the drag, hovered or not, and resumes on the drop (ANN-R98)", function()
		local loaded, M, _, toast, nod = withColumn()
		loaded.client.advance(1)
		loaded.client.keysDown.SHIFT = true
		toast.scripts.OnEnter(toast)
		toast.scripts.OnMouseDown(toast, "LeftButton")
		toast.scripts.OnDragStart(toast)
		-- The pointer leaves the frame mid-drag.
		toast.scripts.OnLeave(toast)

		loaded.client.advance(60)
		raise(loaded, M, moment("toast", "Waiting"))

		assert.are.same({ "Nod", "Toast" }, columnTitles(loaded))
		assert.is_true(loaded.ns.lanes:IsColumnHeld())

		local anchor = loaded.ns.columnAnchor
		anchor.screenCenter, anchor.screenBottom = { SCREEN_WIDTH / 2 + 100, 300.5 }, 300
		toast.scripts.OnDragStop(toast)
		toast.scripts.OnMouseUp(toast, "LeftButton")

		assert.is_false(loaded.ns.lanes:IsColumnHeld())
		-- What waited has entered the column, now where it was dropped.
		assert.are.same({ "Waiting", "Nod", "Toast" }, columnTitles(loaded))
		for _, frame in ipairs(loaded.ns.columnFrames) do
			assert.is_true(bottomOf(loaded, frame) >= 300)
		end
		-- The clocks went on from where they stood: the Nod had 2.3 s left, the toast 7.7.
		loaded.client.advance(2.3)
		assert.is_false(nod.display ~= nil)
		loaded.client.advance(5.4 - 0.01)
		assert.is_true(toast.display ~= nil)
		loaded.client.advance(0.01)
		assert.is_false(toast.display ~= nil)
	end)

	it("keeps the dropped foot inside where a full column fits the screen (ANN-R98)", function()
		local loaded, _, _, toast = withColumn()
		loaded.client.keysDown.SHIFT = true

		dragColumn(loaded, toast, 5000, 5000)
		local right = loaded.ns.db.profile.announcements.point

		-- 22 + 640 wide is the widest entry; its top is 300 + 22 under the screen's.
		assert.are.same({ x = SCREEN_WIDTH / 2 - 331, y = SCREEN_HEIGHT - 322 }, right)
		assert.are.same(right, footOf(loaded))
		dragColumn(loaded, toast, -5000, -40)
		assert.are.same({ x = -(SCREEN_WIDTH / 2 - 331), y = 0 }, loaded.ns.db.profile.announcements.point)
	end)

	it("starts no move while restricted (ANN-R98)", function()
		local loaded, _, _, toast = withColumn()
		loaded.client.keysDown.SHIFT = true
		setCombat(loaded, true)

		assert.is_false(dragColumn(loaded, toast, 200, 500))

		assert.is_nil(loaded.ns.db.profile.announcements.point)
		assert.is_false(loaded.ns.lanes:IsColumnHeld())
	end)

	it("stops a move where it is when restriction starts, and saves it (ANN-R98, ANN-R35)", function()
		local loaded, _, _, toast = withColumn()
		loaded.client.keysDown.SHIFT = true
		toast.scripts.OnMouseDown(toast, "LeftButton")
		toast.scripts.OnDragStart(toast)
		local anchor = loaded.ns.columnAnchor
		anchor.screenCenter, anchor.screenBottom = { SCREEN_WIDTH / 2 - 150, 400.5 }, 400

		setCombat(loaded, true)

		assert.is_false(anchor.moving)
		assert.are.same({ x = -150, y = 400 }, loaded.ns.db.profile.announcements.point)
		assert.are.same({ x = -150, y = 400 }, footOf(loaded))
		assert.is_false(loaded.ns.lanes:IsColumnHeld())
		-- Letting go later changes nothing.
		anchor.screenCenter, anchor.screenBottom = { SCREEN_WIDTH / 2 + 300, 100.5 }, 100
		toast.scripts.OnDragStop(toast)
		assert.are.same({ x = -150, y = 400 }, loaded.ns.db.profile.announcements.point)
		-- And when it is over, what was held shows where the Angler dropped the column.
		setCombat(loaded, false)
		loaded.client.advance(2)
		for _, frame in ipairs(loaded.ns.columnFrames) do
			assert.is_true(bottomOf(loaded, frame) >= 400)
		end
	end)

	it("stops a move when the dragged toast is taken back, and saves it (ANN-R98)", function()
		local loaded, _, _, toast = withColumn()
		loaded.client.keysDown.SHIFT = true
		toast.scripts.OnMouseDown(toast, "LeftButton")
		toast.scripts.OnDragStart(toast)
		local anchor = loaded.ns.columnAnchor
		anchor.screenCenter, anchor.screenBottom = { SCREEN_WIDTH / 2 + 50, 250.5 }, 250

		loaded.ns.lanes:Withdraw(toast.display.announcement)

		assert.is_false(anchor.moving)
		assert.is_false(loaded.ns.lanes:IsColumnHeld())
		assert.are.same({ x = 50, y = 250 }, loaded.ns.db.profile.announcements.point)
	end)

	it("places the column at the saved foot at the next login (ANN-R98, announcements.md › Data)", function()
		local first, _, _, toast = withColumn()
		first.client.keysDown.SHIFT = true
		dragColumn(first, toast, 200, 500)

		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog(), PagleDB = first.env.PagleDB }))
		loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
		loaded.client.runTimers()
		raise(loaded, M, moment("toast", "Placed"))

		assert.are.same({ x = 200, y = 500 }, footOf(loaded))
		assert.are.equal(500, bottomOf(loaded, frameOf(loaded, "toast")))
	end)

	it("places a saved foot the screen can't hold at the nearest that fits, without rewriting it (ANN-R98)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.point = { x = 5000, y = 5000 }

		raise(loaded, M, moment("toast", "Clamped"))

		assert.are.same({ x = SCREEN_WIDTH / 2 - 331, y = SCREEN_HEIGHT - 322 }, footOf(loaded))
		assert.are.same({ x = 5000, y = 5000 }, loaded.ns.db.profile.announcements.point)
	end)

	it("reads a saved value it can't make sense of as the default (ANN-R98)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.point = "garbage"

		raise(loaded, M, moment("toast", "Default"))

		assert.are.same({ x = 0, y = 156 }, footOf(loaded))
	end)

	it("keeps the column on screen when the screen shrinks, and follows a bigger one back (ANN-R98)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.point = { x = 600, y = 700 }
		raise(loaded, M, moment("toast", "Watched"))
		assert.are.same({ x = 600, y = 700 }, footOf(loaded))

		loaded.env.UIParent:SetSize(1366, 768)

		assert.are.same({ x = 1366 / 2 - 331, y = 768 - 322 }, footOf(loaded))
		assert.are.same({ x = 600, y = 700 }, loaded.ns.db.profile.announcements.point)
		loaded.env.UIParent:SetSize(SCREEN_WIDTH, SCREEN_HEIGHT)
		assert.are.same({ x = 600, y = 700 }, footOf(loaded))
	end)

	it("Reset clears the saved foot and puts the toasts and Nods on screen back at the bottom (ANN-R98)", function()
		local loaded, _, _, toast, nod = withColumn()
		loaded.client.keysDown.SHIFT = true
		dragColumn(loaded, toast, 200, 500)

		assert.is_true(loaded.ns.ResetToastColumn())

		assert.is_nil(loaded.ns.db.profile.announcements.point)
		assert.are.same({ x = 0, y = 156 }, footOf(loaded))
		assert.are.same({ 156 + 52, 156 }, { bottomOf(loaded, toast), bottomOf(loaded, nod) })
	end)

	it("Reset does nothing while restricted (ANN-R98)", function()
		local loaded, _, _, toast = withColumn()
		loaded.client.keysDown.SHIFT = true
		dragColumn(loaded, toast, 200, 500)
		setCombat(loaded, true)

		assert.is_false(loaded.ns.ResetToastColumn())

		assert.are.same({ x = 200, y = 500 }, loaded.ns.db.profile.announcements.point)
		assert.are.same({ x = 200, y = 500 }, footOf(loaded))
	end)

	it(
		"moves and holds an ordinary Catch's toast, and a Nod it steps down to, with the column (ANN-R13, ANN-R98)",
		function()
			local loaded = loadCore()
			loaded.client.itemNames[6358] = "Oily Blackmouth"
			loaded.ns.db.profile.announcements.motion = false
			catchAndFlush(loaded)
			local toast = frameOf(loaded, "toast") --[[@as table]]
			assert.are.same("toast.low", toast.display.announcement.headline.rung)
			loaded.client.advance(1)
			loaded.client.keysDown.SHIFT = true

			toast.scripts.OnMouseDown(toast, "LeftButton")
			toast.scripts.OnDragStart(toast)
			-- The budget is spent mid-drag, and another Catch waits for the column, whose clocks stand still.
			loaded.ns.db.profile.announcements.budget.count = 1
			loaded.client.advance(60)
			catchAndFlush(loaded)
			assert.are.same({ toast }, loaded.ns.columnFrames)

			local anchor = loaded.ns.columnAnchor
			anchor.screenCenter, anchor.screenBottom = { SCREEN_WIDTH / 2 + 120, 350.5 }, 350
			toast.scripts.OnDragStop(toast)
			toast.scripts.OnMouseUp(toast, "LeftButton")

			assert.are.same({ x = 120, y = 350 }, loaded.ns.db.profile.announcements.point)
			assert.are.equal(2, #loaded.ns.columnFrames)
			for _, frame in ipairs(loaded.ns.columnFrames) do
				assert.is_true(bottomOf(loaded, frame) >= 350)
			end
			assert.are.same(
				{ "toast", "nod" },
				{ loaded.ns.columnFrames[2].display.form, loaded.ns.columnFrames[1].display.form }
			)
		end
	)

	it("leaves banners and the splash where they are (ANN-R98)", function()
		local loaded, M = loadCore()
		loaded.ns.db.profile.announcements.point = { x = 200, y = 500 }

		raise(loaded, M, moment("banner", "Level 12"), moment("toast", "Toast"))

		local point, relativeTo, relativePoint, x, y = frameOf(loaded, "banner"):GetPoint(1)
		assert.are.same({ "TOP", loaded.env.UIParent, "TOP", 0, -120 }, { point, relativeTo, relativePoint, x, y })
	end)
end)
