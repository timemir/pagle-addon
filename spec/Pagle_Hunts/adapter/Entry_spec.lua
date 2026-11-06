-- A Hunt's entry on the board's right page (HNT-R3, HNT-R18, HNT-R64–R67, HNT-R69, HNT-R80): Hunts on FakePagle over
-- the fixture Hunt list and catalogue, grouped at the first PLAYER_ENTERING_WORLD, with hand-made projection states.
-- What each line says is logic/Entry.lua's (spec/Pagle_Hunts/logic/Entry_spec.lua); these check the page draws it,
-- the pin toggle pins, the back link goes back and the tooltips show.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
local has = hunts.has

local UPDATING = "Updating from your Catch log…"

-- Progress with `count` Catches, `effort` effort Casts and the first `tiers` tiers reached, each on realm date 12
-- October 2026 in Darkshore.
local function progress(count, effort, sinceLast, tiers)
	return hunts.progress({
		count = count,
		effort = effort,
		sinceLast = sinceLast,
		tiers = tiers,
		time = SERVER_TIME,
		date = { year = 2026, month = 10, day = 12 },
	})
end

---@class EntryRun: HuntsRun
---@field state HuntsState
---@field updating boolean

--- Hunts on a FakePagle, logged in at Fishing `skill` (150 by default) and grouped, its projection a stand-in that
--- hands out `run.state` and `run.updating` as they are at each read; names for the fixture's areas and items.
--- `prepare` runs before Hunts' ADDON_LOADED, e.g. to change the fixture's Hunt list.
---@param skill integer?
---@param prepare fun(loaded: LoadedAddon)?
---@param motion boolean? Core's Animations setting on (off by default)
---@return EntryRun
local function start(skill, prepare, motion)
	local run = hunts.start({ skill = skill, prepare = prepare, names = true, motion = motion }) --[[@as EntryRun]]
	run.state, run.updating = run.ns.NewHuntsState(), false
	run.ns.projection = {
		GetState = function()
			return run.state
		end,
		IsUpdating = function()
			return run.updating
		end,
	}
	return run
end

--- Opens the board at `place` and hands back the right page's frame and its entry view.
---@param run EntryRun
---@param place BoardPlace
local function open(run, place)
	local board = run.ns.board
	board:Open(place)
	local page = board:Page(place, "right")
	return page, page.entry
end

-- The shown chip whose words are `text`.
local function chipOf(view, text)
	for _, chip in ipairs(view.chips) do
		if chip:IsShown() and chip.label.text == text then
			return chip
		end
	end
	error("no chip " .. text)
end

describe("a Hunt's entry on the board", function()
	describe("the seal, the tier ladder and the effort counter (HNT-R64, HNT-R18)", function()
		it("draws a done Hunt's seal, its tier 1 dated and zoned, the ink bar and the effort counter", function()
			local run = start()
			run.state.hunts.fixture_snapper = progress(1, 96, 11, 1)

			local page, view = open(run, { mode = "board", hunt = "fixture_snapper" })
			local texts = shownTexts(page)

			assert.are.same({ "Hunted 12 Oct 2026", true }, { view.seal.label.text, view.seal.filled })
			-- the pressed seal stacks its word, the short date and the year
			assert.are.same({ "HUNTED", "12 Oct", "2026" }, {
				view.seal.lines[1]:GetText(),
				view.seal.lines[2]:GetText(),
				view.seal.lines[3]:GetText(),
			})
			-- each tier: its threshold, then its Catch's date and zone, or "not yet"
			assert.are.same({ "1", "10" }, { view.thresholds[1]:GetText(), view.thresholds[2]:GetText() })
			assert.are.same({ "12 Oct, Darkshore", "not yet" }, { view.whens[1]:GetText(), view.whens[2]:GetText() })
			for _, text in ipairs({
				"96 Casts under these conditions, 11 since my last one.",
				"Odds live in Stats.",
			}) do
				assert.are.equal(text, has(texts, text) and text or nil)
			end
			assert.are.equal("1 / 10", view.bar.label.text)
			assert.are.equal(0.1, view.bar.value)
		end)

		it(
			"keeps the effort counter on the page when a longer language runs the entry past its foot (HNT-R64)",
			function()
				local run = start()
				run.state.hunts.fixture_snapper = progress(1, 96, 11, 1)
				local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })
				local fonts = run.ns.BoardFonts()
				assert.are.same({ fonts.hand, true }, { view.effort.fontObject, view.odds:IsShown() })

				-- the conditions wrap long, as a language's longer words do: the entry would end past the page's foot
				view.conditions.GetStringHeight = function()
					return 400
				end
				run.ns.board:Draw()

				-- the pointer to Stats goes, and the counter is set small, so it ends on the page
				local effort = "96 Casts under these conditions, 11 since my last one."
				assert.are.same(
					{ effort, fonts.note, false },
					{ view.effort:GetText(), view.effort.fontObject, view.odds:IsShown() }
				)
			end
		)

		it(
			"tightens the entry a step at a time until its set line ends on the page, the conditions cut last (HNT-R64)",
			function()
				local run = start()
				run.state.hunts.fixture_snapper = progress(1, 96, 11, 1)
				local page, view = open(run, { mode = "board", hunt = "fixture_snapper" })
				local fonts = run.ns.BoardFonts()
				-- as the kit lays it: the window line in the large hand, every line of the conditions
				assert.are.same({ fonts.handLarge, 0 }, { view.window.fontObject, view.conditions:GetMaxLines() })

				-- eleven zones in a longer language: twenty lines of conditions, 17.5 a line, or the most it is kept to
				local rows = 20
				view.conditions.GetStringHeight = function(self)
					local most = self:GetMaxLines()
					return (most > 0 and math.min(most, rows) or rows) * 17.5
				end
				run.ns.board:Draw()

				-- the foot compact, the body tight (the window line a size down), and the conditions kept to the lines
				-- that leave the set line's words on the page, which cut them before
				local most = view.conditions:GetMaxLines()
				assert(most >= 1 and most < 20, "kept to " .. most)
				assert.are.same({ fonts.note, false, fonts.hand }, {
					view.effort.fontObject,
					view.odds:IsShown(),
					view.window.fontObject,
				})
				local setLine = view.setLine
				assert.is_true(setLine:IsShown())
				local foot = -setLine.points[1][3] + setLine:GetStringHeight()
				assert(foot <= page:GetHeight(), "the set line ends at " .. foot .. ", past the page")

				-- a short entry again is laid as the kit lays it, every line of its conditions shown
				rows = 1
				run.ns.board:Draw()
				assert.are.same(
					{ fonts.handLarge, 0, true },
					{ view.window.fontObject, view.conditions:GetMaxLines(), view.odds:IsShown() }
				)
			end
		)

		it("keeps a longer language's kicker whole beside the round seal, then sets it smaller (HNT-R64)", function()
			local run = start()
			-- the kit left the kicker the heading's room, 96 short of the page's right for the seal's whole width; at the
			-- kicker's line the wax reaches in only 67 of it
			run.ns.L["set.fixture_dusk.name"] = "Heimische Gewässer am Ufer"
			local page, view = open(run, { mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" })
			local fonts = run.ns.BoardFonts()
			local kicker = view.kicker:GetText()
			assert.are.equal("HEIMISCHE GEWÄSSER AM UFER · NATURAL", kicker) -- never rewritten
			assert(#kicker * 6 > page:GetWidth() - 96, "the kicker fits the kit's room in the fake")
			assert.are.same({ fonts.kicker, true }, { view.kicker.fontObject, view.kicker.width >= #kicker * 6 })
			assert(view.kicker.width <= page:GetWidth() - 71, "the kicker runs into the seal")

			-- longer still: a size down at a time, then the client cuts it
			run.ns.L["set.fixture_dusk.name"] = "Heimische Gewässer am stillen Ufer"
			run.ns.board:Draw()
			assert.are_not.equal(fonts.kicker, view.kicker.fontObject)
			assert.are.equal(page:GetWidth() - 71, view.kicker.width)
		end)

		it("wraps a note too long for one line even set small to two lines in a taller chip (HNT-R65)", function()
			local run = start()
			-- deDE's: at the chips' least size, 11, it still ran past the page and was cut ("…eine Laterne und ei…")
			local long = "Von der Abendglocke bis tief in die Nacht: eine Laterne und ein stilles Ufer."
			run.ns.L["hunt.fixture_snapper.note"] = long
			local page, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			local chip = chipOf(view, long) -- its words whole, never rewritten
			assert(#long * 6 > page:GetWidth(), "the note fits on a line in the fake, so this checks nothing")
			assert.are.same({ true, 2, run.ns.BoardFonts().small }, {
				chip.label:CanWordWrap(),
				chip.label:GetMaxLines(),
				chip.label.fontObject,
			})
			assert.are.equal(page:GetWidth(), chip.width)
			assert(chip.height > 22, "the chip keeps one line's height")
			assert.is_true(chip.face.tall[1]:IsShown())
			-- the set's note, the next chip, starts under it
			local after = chipOf(view, "After the lamps are lit.")
			assert.are.equal(-chip.points[1][3] + chip.height + 5, -after.points[1][3])

			-- a short note is the kit's one-line chip
			assert.are.same({ false, 22 }, { after.label:CanWordWrap(), after.height })
			assert.is_false(after.face.tall ~= nil and after.face.tall[1]:IsShown())
		end)

		it("draws an undone Hunt's dashed 'not yet' and only its effort Casts (HNT-R26)", function()
			local run = start()
			run.state.hunts.fixture_snapper = progress(0, 12, 12, 0)

			local page, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			assert.are.same({ "not yet", false }, { view.seal.label.text, view.seal.filled })
			assert.is_true(has(shownTexts(page), "12 Casts under these conditions."))
		end)

		it("reads a finished Hunt's count, and dresses each diamond in its tier's trim, filled (HNT-R18)", function()
			local run = start()
			local look = run.ns.BOARD_LOOK
			run.state.hunts.fixture_snapper = progress(52, 300, 4, 3)

			local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			assert.are.equal("52 caught", view.bar.label.text)
			for k = 1, 3 do
				local mark = view.diamonds[k].mark
				assert.are.same(look.tierInks[run.ns.Trim(k)], { unpack(mark.vertexColor, 1, 3) })
				assert.are.equal(run.ns.ATLASES.Parts.sprites["tier-on"].y / 1024, mark.texCoord[3])
			end
		end)

		it("leaves an unreached tier's mark an outline", function()
			local run = start()
			run.state.hunts.fixture_snapper = progress(1, 5, 0, 1)

			local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			local mark = view.diamonds[2].mark
			assert.are.equal(run.ns.ATLASES.Parts.sprites["tier-off"].y / 1024, mark.texCoord[3])
		end)
	end)

	describe("its lines and chips (HNT-R64, HNT-R65)", function()
		it(
			"heads it with the set and kind in small caps, the name and the target, then the window and conditions",
			function()
				local run = start()

				local page = open(run, { mode = "board", hunt = "fixture_snapper" })
				local texts = shownTexts(page)

				-- Realm 08:15: the night window opens at 20:00 the same day.
				for _, text in ipairs({
					"DUSK · NATURAL",
					"Snapper Run",
					"Raw Nightfin Snapper",
					"Opens at 20:00.",
					"Night 20:00–06:00",
					"Dusk: 0 of 2 · earns the Duskwatcher",
				}) do
					assert.are.equal(text, has(texts, text) and text or nil)
				end
			end
		)

		it("shows the live zone's chip first with 'you're here', the skill need, and the notes", function()
			local run = start()

			local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			-- Snapper Run bites in Darkshore (the live zone) and Ashenvale; its lowest skill base is Darkshore's 75.
			local darkshore = chipOf(view, "Darkshore")
			assert.are.equal("you're here", darkshore.badge.text)
			assert.is_true(darkshore.badge:IsShown())
			assert.is_false(chipOf(view, "Ashenvale").badge:IsShown())
			chipOf(view, "skill 75")
			chipOf(view, "Keeps late hours.")
			chipOf(view, "After the lamps are lit.")
		end)

		it("reads 'Up now.' for a Hunt short of skill while its aura is up (HNT-R52)", function()
			local rack = 1280341 -- fixture_rack's aura
			local run = start(150, function(l)
				for _, hunt in ipairs(l.ns.huntList.hunts) do
					if hunt.id == "fixture_rack" then
						hunt.conditions = { auras = { rack }, skill = { min = 400 } }
					end
				end
			end)
			local conditions = {}
			for key, value in pairs(run.fake.conditions) do
				conditions[key] = value
			end
			conditions.auras = { rack }
			run.fake.setConditions(conditions) -- ConditionsChanged regroups (HNT-R42)

			local page = open(run, { mode = "board", hunt = "fixture_rack" })

			assert.is_true(has(shownTexts(page), "Up now. Needs 400; my best is 150."))
			-- Its row stays as short of skill draws it: Later, "need 400", no blue camp bar (HNT-R51, HNT-R63).
			assert.are.equal("later", run.ns.groups:Row("fixture_rack").group)
			local drawn
			for _, group in ipairs(run.ns.BoardTimeline({ mode = "board" }).groups) do
				for _, row in ipairs(group.rows) do
					drawn = row.id == "fixture_rack" and row or drawn
				end
			end
			assert.are.same({}, drawn.bars)
			assert.are.equal("need 400", drawn.margin)
		end)

		it("shows '+N more' past 3 zones, its tooltip listing the rest", function()
			local run = start()
			run.ns.where.fixture_oddity.zones = { 10, 12, 40, 148, 331 }

			local _, view = open(run, { mode = "board", hunt = "fixture_oddity" })
			local more = chipOf(view, "+2 more")
			more:GetScript("OnEnter")(more)

			assert.are.same({ "Westfall", "Ashenvale" }, run.loaded.client.tooltipLines())
			assert.is_true(run.loaded.env.GameTooltip.shown)
			more:GetScript("OnLeave")(more)
			assert.is_false(run.loaded.env.GameTooltip.shown)
		end)

		it("draws the skill chip in red when short of skill (HNT-R33)", function()
			local run = start(50)

			local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			local red, color = run.ns.BOARD_LOOK.red, chipOf(view, "needs 75, best: 50").label.textColor
			assert.are.same(red, { color[1], color[2], color[3] })
		end)

		it("marks an unconfirmed window 'unconfirmed', its tooltip saying it is an estimate (HNT-R34)", function()
			local run = start()

			-- Eel Run's window, the day window, is unconfirmed in the fixture catalogue.
			local _, view = open(run, { mode = "board", hunt = "fixture_eel" })
			local chip = chipOf(view, "unconfirmed")
			chip:GetScript("OnEnter")(chip)

			assert.are.same({ "This window is an estimate." }, run.loaded.client.tooltipLines())
		end)
	end)

	describe("the pin toggle (HNT-R80)", function()
		it("pins the Hunt and unpins it again, redrawing the toggle", function()
			local run = start()
			local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			view.pin:Click()
			assert.is_true(run.ns.IsPinned("fixture_snapper"))
			assert.is_true(run.ns.groups:Row("fixture_snapper").pinned)
			assert.is_true(view.pin.pinned)

			view.pin:Click()
			assert.is_false(run.ns.IsPinned("fixture_snapper"))
			assert.is_false(view.pin.pinned)
		end)

		it("says what a click does in its tooltip", function()
			local run = start()
			local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

			view.pin:GetScript("OnEnter")(view.pin)
			assert.are.same({ "Pin to the tracker" }, run.loaded.client.tooltipLines())
			view.pin:Click()
			view.pin:GetScript("OnEnter")(view.pin)
			assert.are.same({ "Unpin" }, run.loaded.client.tooltipLines())
		end)
	end)

	describe("the retired entry (HNT-R3)", function()
		it("shows 'Retired {date}', the seal, ladder and effort, with no window line, chips or pin toggle", function()
			local run = start()
			run.state.hunts.fixture_sunscale = progress(1, 40, 7, 1)

			local page, view = open(run, { mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" })
			local texts = shownTexts(page)

			assert.is_true(has(texts, "Old Sunscale"))
			assert.is_true(has(texts, "Retired 1 Jun 2026"))
			assert.are.equal("Hunted 12 Oct 2026", view.seal.label.text)
			assert.is_true(has(texts, "40 Casts under these conditions, 7 since my last one."))
			assert.is_false(view.pin:IsShown())
			assert.is_false(view.window:IsShown())
			assert.is_false(view.conditions:IsShown())
			for _, chip in ipairs(view.chips) do
				assert.is_false(chip:IsShown())
			end
		end)
	end)

	describe("opened from a set's page (HNT-R66)", function()
		it("shows the pointing hand and 'back to {set}', which goes back to the set's page", function()
			local run = start()

			local _, view = open(run, { mode = "entry", set = "fixture_dusk", hunt = "fixture_hefty_blackmouth" })

			assert.is_true(view.back:IsShown())
			assert.is_true(view.hand:IsShown())
			assert.are.equal("back to Dusk", view.back.label.text)
			view.back:Click()
			assert.are.same({ mode = "set", set = "fixture_dusk" }, run.ns.board.router:Place())
		end)

		it("has no way back on the Board", function()
			local run = start()

			local _, view = open(run, { mode = "board", hunt = "fixture_hefty_blackmouth" })

			assert.is_false(view.back:IsShown())
		end)
	end)

	describe("while the projection is updating (HNT-R69)", function()
		it("reads the updating line in the seal, the tier ladder and the effort counter", function()
			local run = start()
			run.state.hunts.fixture_snapper = progress(1, 96, 11, 1)
			run.updating = true

			local page, view = open(run, { mode = "board", hunt = "fixture_snapper" })
			local texts = shownTexts(page)

			assert.are.equal(UPDATING, view.seal.label.text)
			assert.are.equal(UPDATING, view.ladderUpdating.text)
			assert.are.equal(UPDATING, view.effort.text)
			assert.is_false(has(texts, "Tier 1 · 1"))
			assert.is_false(view.bar:IsShown())
		end)
	end)

	describe("on the Board with no Hunt selected (HNT-R67)", function()
		it("reads that every Hunt is done when the filter hides every row", function()
			local run = start()
			for _, hunt in ipairs(run.ns.hunts:Current(SERVER_TIME)) do
				run.state.hunts[hunt.id] = progress(#hunt.tiers, 1, 0, #hunt.tiers)
			end

			local page = open(run, { mode = "board" })

			assert.are.same({ 'Every Hunt here is done. Tick "show completed" to see them again.' }, shownTexts(page))
		end)

		it("is empty with rows to pick from, and shows no Retired Hunt on the Board", function()
			local run = start()
			-- The entry alone: the timeline (adapter/Timeline.lua) would pick a Hunt from the rows (HNT-R67) before the right page.
			run.ns.board:RegisterPage("board", "left", function() end)

			assert.are.same({}, shownTexts((open(run, { mode = "board" }))))
			assert.are.same({}, shownTexts((open(run, { mode = "board", hunt = "fixture_sunscale" }))))
		end)
	end)

	it("redraws at every redraw while shown, so a Catch that completes the Hunt seals it (HNT-R64, HNT-R42)", function()
		local run = start()
		local _, view = open(run, { mode = "board", hunt = "fixture_snapper" })

		run.state.hunts.fixture_snapper = progress(1, 3, 0, 1)
		run.ns.Redraw("projection")

		assert.are.equal("Hunted 12 Oct 2026", view.seal.label.text)
	end)

	it("draws settled on reopening after a Catch while it was closed: no ink running on, no write sound", function()
		local run = start(nil, nil, true)
		local place = { mode = "board", hunt = "fixture_snapper" }
		run.state.hunts.fixture_snapper = progress(1, 96, 11, 1)
		open(run, place)
		run.ns.board:Hide()
		for _ = 1, 30 do
			run.loaded.client.nextFrame(1 / 60) -- the closing fade ends
		end
		assert.is_false(run.ns.board.frame:IsShown())

		run.state.hunts.fixture_snapper = progress(2, 97, 0, 1)
		run.ns.Redraw("projection")
		local heard = #run.loaded.client.sounds
		local _, view = open(run, place)

		for i = heard + 1, #run.loaded.client.sounds do
			assert.are_not.equal("3093 SFX", run.loaded.client.sounds[i])
		end
		assert.are.equal(1, view.bar.label:GetAlpha())
		assert.are.equal(1, view.effort:GetAlpha())
	end)
end)
