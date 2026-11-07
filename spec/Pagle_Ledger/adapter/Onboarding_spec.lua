-- The Ledger's parts of onboarding on FakePagle (core/onboarding.md): the Field guide's Your Ledger step (ONB-R21,
-- ONB-R36) drawn from a fixture state with the Angler page's Prestige frame (LED-R146) and the guide's parts; its line
-- on What's in the box (ONB-R91); the First evening list's `journal` item (ONB-R61); the `ledger.fresh` Margin note (ONB-R52);
-- and the first New Species toast's note (ONB-R53).

local MACKEREL, ELWYNN = 6303, 12
local T0 = SERVER_TIME - 700

-- The fixture: the player's character (the fake client's "Angler"), whose Fishing skill was read at 125 before any Catch (so Skill
-- Milestone 75 is credited, LED-R40), and `log` after it.
---@param log table[]?
---@param options table? more of openJournal's options
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger(log, options)
	local records = { { kind = "skill", char = 1, time = T0 - 300, rank = 125, max = 150, mod = 0 } }
	for _, record in ipairs(log or {}) do
		records[#records + 1] = record
	end
	local all = {
		logId = "log",
		log = records,
		id = false,
	}
	for key, value in pairs(options or {}) do
		all[key] = value
	end
	return openJournal(all)
end

-- The guide open at the Your Ledger step, and its two pages as drawn.
---@param fake FakePagle
---@return table left
---@return table right
local function ledgerStep(fake)
	fake.guide:Open("ledger")
	local pages = assert(fake.guidePages.ledger, "the Your Ledger step drew no pages")
	return pages.left, pages.right
end

-- The guide notes (nav.Note's frames) drawn on `page`, shown or not, in order.
---@param page table
---@return table[]
local function notesOn(page)
	local notes = {}
	for _, child in ipairs(page.children) do
		if child.w and child.text then
			notes[#notes + 1] = child
		end
	end
	return notes
end

-- The guide parts (nav.Part's sprites) drawn on `page`, shown or not, in order.
---@param page table
---@return string[]
local function partsOn(page)
	local sprites = {}
	for _, child in ipairs(page.children) do
		if child.sprite then
			sprites[#sprites + 1] = child.sprite
		end
	end
	return sprites
end

describe("the Ledger's onboarding", function()
	describe("the Field guide's Your Ledger step (ONB-R36)", function()
		it("is registered at 60, ribboned Your Ledger, between Core's Moments and Off you go (ONB-R21)", function()
			local fake = ledger()

			local ids = {}
			for i, entry in ipairs(fake.guideSteps:List()) do
				ids[i] = entry.step.id
			end
			assert.are.same({ "welcome", "box", "moments", "ledger", "off" }, ids)
			local step = fake.guideSteps:List()[4].step
			assert.are.same({ 60, "Your Ledger" }, { step.order, step.ribbon })
		end)

		it(
			"shows the bookplate on the left: Ex Libris, the Angler page's Prestige frame holding the likeness, The Angler's "
				.. "Ledger, the character and kept since … your first Catch (ONB-R36, LED-R146)",
			function()
				local fake, loaded = ledger()

				local left = ledgerStep(fake)

				assert.are.same({
					"Your Ledger",
					"It starts with your next fish",
					"Pagle writes down only what it sees. Fish you caught before today aren’t in your Ledger, and Pagle "
						.. "won’t pretend they are. Your first Catch is page one.",
					"Ex Libris",
					"The Angler's Ledger",
					"Angler",
					"kept since … your first Catch",
				}, shownTexts(left))
				assert.are.same({ "plate" }, partsOn(left))
				-- the Angler page's Prestige frame: No Prestige's (rank 0) with the player's likeness, no crest pinned
				local crest = loaded.ns.guideLedger.crest
				assert.are.equal("none", crest.frame.key)
				assert.are.equal("player", crest.frame:GetWell().portrait)
				assert.is_false(crest.pin:IsShown())
			end
		)

		it(
			"pins the zone crest the Angler wears on the step's crest, the Ledger's own texture (ONB-R36, LED-R112, LED-R113)",
			function()
				local fake, loaded = ledger(nil, {
					globals = {
						PagleLedgerDB = { global = { celebrated = { zones = { [ELWYNN] = 5 }, logId = "log" } } },
					},
				})
				assert.is_true(fake.Pagle.IsOwned("ledger.crest.elwynn")) -- its zone celebrated at Master (LED-R114)
				assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.elwynn"))

				ledgerStep(fake)

				local pin = loaded.ns.guideLedger.crest.pin
				assert.is_true(pin:IsShown())
				assert.are.equal("Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn", pin.shield.texture)
			end
		)

		it(
			"shows the box of Skill Milestones on the right, from the Ledger's state: 75 ticked with its XP, 150 with "
				.. "its skill to go, 225 and 300 for later; then the account paragraph and the note (ONB-R36, LED-R40)",
			function()
				local fake = ledger()

				local _, right = ledgerStep(fake)

				assert.are.same({
					"Already written in",
					"What Pagle could see",
					"Your Fishing skill is the one thing that tells your past honestly, so it counts from the start.",
					"Angler · Fishing 125",
					"read just now",
					"Skill Milestone 75",
					"reached before Pagle came",
					"+1,000 XP",
					"Skill Milestone 150",
					"25 skill to go",
					"+1,000 XP",
					"Skill Milestones 225 and 300",
					"for later",
					"Every character on this account writes in the same Ledger. Log in with another and Pagle reads "
						.. "their Fishing skill too.",
					"Turn a part on later and it reads back through *every Catch* since today, then writes up what "
						.. "you’d earned.",
				}, shownTexts(right))
				-- the marks: a red tick for the credited one, ghost rings for the rest (the fourth row's, unused, hidden)
				local marks = {}
				for _, child in ipairs(right.children) do
					if child.sprite and child.shown then
						marks[#marks + 1] = child.sprite
					end
				end
				assert.are.same({ "tick-red", "ring-ghost", "ring-ghost" }, marks)
				-- the note is the guide's, 290 wide, its *term* for the guide's red pencil; its copy across the column waits
				local notes = notesOn(right)
				assert.are.same({ { 70, 290, true }, { 30, 382, false } }, {
					{ notes[1].x, notes[1].w, notes[1]:IsShown() },
					{ notes[2].x, notes[2].w, notes[2]:IsShown() },
				})
			end
		)

		it(
			"keeps the note off Core's foot: across the column when it would reach Next », lifted if it must (ONB-R23)",
			function()
				local fake = ledger()
				local _, right = ledgerStep(fake)
				local notes = notesOn(right)
				local function topOf(region)
					return -region.points[1][5]
				end

				-- a note as tall as a longer translation writes it: 290 wide it would pass 486, across the column it ends above
				local natural = topOf(notes[1])
				notes[1]:SetSize(290, 486 - natural + 20)
				notes[2]:SetSize(382, 486 - natural - 10)
				fake.guide:Close()
				fake.guide:Open("ledger")

				assert.are.same({ false, true }, { notes[1]:IsShown(), notes[2]:IsShown() })
				assert.are.same({ 30, natural }, { notes[2].points[1][4], topOf(notes[2]) })

				-- taller still, it is lifted to end at 486
				notes[2]:SetSize(382, 486 - natural + 30)
				fake.guide:Close()
				fake.guide:Open("ledger")
				assert.are.equal(486, topOf(notes[2]) + notes[2]:GetHeight())
			end
		)

		describe("the note in its real face, over Core's foot (ONB-R36, 1.3.5)", function()
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
			local RealFont = dofile("scripts/measure-layout/realfont.lua")
			local width = RealFont.width
			local FOOT_TOP = 486

			-- The Your Ledger step on Core's own guide in `language` on a client of that language, the Ledger's and
			-- Core's guide texts measured in their real faces (a ruRU client's FRIZQT___CYR, which isn't bundled, in
			-- RealFont's stand-in), `wider` times as wide when given. Returns the step as drawn.
			local function step(language, wider)
				RealFont.width = function(...)
					local w, estimated = width(...)
					return w * (wider or 1), estimated
				end
				local loaded = loadAddon(
					"Pagle",
					foreverWith({
						GetLocale = function()
							return language
						end,
						PagleDB = { global = { language = language } },
					}),
					{ also = { "Pagle_Ledger" } }
				)
				enterWorld(loaded, 3)
				local core, ledgerNs = loaded.namespaces.Pagle, loaded.namespaces.Pagle_Ledger
				core.db.profile.announcements.motion = false
				for _, ns in ipairs({ core, ledgerNs }) do
					for _, name in ipairs({ "GuideText", "JournalLabel" }) do
						local make = rawget(ns, name)
						if make then
							ns[name] = function(...)
								return RealFont.patch(make(...))
							end
						end
					end
				end
				core.guide:Open("ledger")
				assert.are.same({}, loaded.client.errors)
				return assert(ledgerNs.guideLedger)
			end

			after_each(function()
				RealFont.width = width
			end)

			-- A region's top, from its one anchor.
			local function topOf(region)
				return -region.points[1][5]
			end

			it("onb_r36 holds ruRU's long note between the account paragraph and the foot, over neither", function()
				for _, wider in ipairs({ false, 1.1 }) do
					local view = step("ruRU", wider or nil)
					local note = view.note:IsShown() and view.note or view.wideNote
					local times = ("%s times the stand-in"):format(wider or 1)
					local size = select(2, RealFont.face(note.text))

					assert(
						topOf(note) >= topOf(view.account) + view.account:GetStringHeight(),
						"note over the account paragraph, " .. times
					)
					assert(topOf(note) + note:GetHeight() <= FOOT_TOP + 1e-6, "note on the foot, " .. times)
					assert(size >= 14.5, ("set at %s, %s"):format(size, times))
				end
			end)

			it("onb_r36 leaves the note at the hand's 19, whole, in enUS, deDE and esES", function()
				for _, language in ipairs({ "enUS", "deDE", "esES" }) do
					local view = step(language)
					local note = view.note:IsShown() and view.note or view.wideNote
					assert.are.equal(19, select(2, RealFont.face(note.text)))
					assert.are.equal(0, note.text:GetMaxLines())
					assert.is_true(topOf(note) + note:GetHeight() <= FOOT_TOP + 1e-6)
				end
			end)
		end)

		it(
			"reads the Ledger's state again each time it shows: kept since the first Catch (ONB-R36, LED-R146)",
			function()
				local fake = ledger()
				local left = ledgerStep(fake)
				fake.guide:Close()

				fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
				fake.guide:Open("ledger")

				local texts = shownTexts(left)
				assert.matches("^kept since %d+ %a+$", texts[#texts])
			end
		)

		it("registers nothing on a Core without the guide (ONB-R90)", function()
			local fake = newFakePagle()
			fake.ns.ModuleHandle.RegisterGuideStep = nil
			fake.load("Pagle_Ledger")
			fake.login()

			assert.are.equal(4, fake.guideSteps:Count())
		end)
	end)

	it("gives What's in the box the Ledger's line (ONB-R91)", function()
		local _, loaded = ledger()

		assert.are.equal(
			"Your book: every water and every fish, your Angler Level, records and titles.",
			loaded.ns.ModuleDef(function() end).guideBlurb
		)
	end)

	describe("as the Fish Journal opens", function()
		it("ticks the First evening list's journal item (ONB-R61)", function()
			local fake, loaded = ledger()
			assert.is_false(fake.onboarding:IsEveningItemDone("journal"))

			loaded.ns.journal:Toggle()

			assert.is_true(fake.onboarding:IsEveningItemDone("journal"))
		end)

		-- A Catch the logged-in Angler made two hours ago: a real break (LED-R22) has passed since it.
		local TWO_HOURS_AGO = SERVER_TIME - 7200

		it(
			"shows ledger.fresh on the ink bar's blue part the first time it opens with Fresh Water once a real break "
				.. "has passed, once (ONB-R52)",
			function()
				local fake, loaded =
					ledger({ castRecord({ time = TWO_HOURS_AGO, zone = ELWYNN, items = { MACKEREL } }) })
				local journal = loaded.ns.journal

				journal:Toggle()

				assert.are.equal(1, #fake.notesShown)
				local note = fake.notesShown[1]
				assert.are.equal("ledger.fresh", note.id)
				assert.are.equal(
					"You’ve been away, so your next Catches earn bonus XP. That’s |cff9a2a1aFresh Water|r, the blue in "
						.. "your bar. A rest is never a penalty.",
					note.text
				)
				assert.are.equal(journal.shown.right.drawn.xpBar[1].bar.fresh, note.target)
				assert.is_true(note.target:IsShown())

				journal:Close()
				journal:Toggle()
				assert.are.equal(1, #fake.notesShown)
			end
		)

		it(
			"waits for an opening that shows the blue part: a spread without the ink bar shows none (ONB-R52)",
			function()
				local fake, loaded =
					ledger({ castRecord({ time = TWO_HOURS_AGO, zone = ELWYNN, items = { MACKEREL } }) })
				local journal = loaded.ns.journal

				journal:Open("zone", { zone = ELWYNN })
				assert.are.same({}, fake.notesShown)

				journal:Close()
				journal:Open("home")
				assert.are.same({ "ledger.fresh" }, { fake.notesShown[1] and fake.notesShown[1].id })
			end
		)

		it("shows no ledger.fresh to a new Angler before any Catch, and marks it unseen (ONB-R52)", function()
			local fake, loaded = ledger()

			loaded.ns.journal:Toggle()

			assert.is_truthy(loaded.ns.JournalFreshPart(loaded.ns.journal))
			assert.are.same({}, fake.notesShown)
			assert.is_nil(fake.global.onboarding.notesSeen["ledger.fresh"])
		end)

		it(
			"shows no ledger.fresh after a Session end alone: a Session that ended 700 s ago is no real break (ONB-R52)",
			function()
				local fake, loaded = ledger({ castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }) })

				loaded.ns.journal:Toggle()

				assert.is_truthy(loaded.ns.JournalFreshPart(loaded.ns.journal))
				assert.are.same({}, fake.notesShown)
				assert.is_nil(fake.global.onboarding.notesSeen["ledger.fresh"])
			end
		)

		it(
			"shows no ledger.fresh at the opening after a SessionEnded, but at the first one an hour after the last "
				.. "Catch (ONB-R52, LED-R22)",
			function()
				local fake, loaded = ledger()
				local journal = loaded.ns.journal
				fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
				journal:Toggle()
				journal:Close()
				assert.are.same({}, fake.notesShown)

				local ended = false
				fake.Pagle.RegisterCallback("spec: ended", "SessionEnded", function()
					ended = true
				end)
				fake.wait(300)
				assert.is_true(ended)
				journal:Toggle()
				journal:Close()
				assert.are.same({}, fake.notesShown)
				assert.is_nil(fake.global.onboarding.notesSeen["ledger.fresh"])

				-- The server clock reaches an hour after the Cast (the fake client's stands still).
				loaded.env.GetServerTime = function()
					return SERVER_TIME + 3600
				end
				journal:Toggle()
				assert.are.same({ "ledger.fresh" }, { fake.notesShown[1] and fake.notesShown[1].id })
			end
		)

		it(
			"counts a logged gap of an hour between two Catches, though the last is recent (ONB-R52, LED-R22)",
			function()
				local fake, loaded = ledger({
					castRecord({ time = SERVER_TIME - 3 * 3600, zone = ELWYNN, items = { MACKEREL } }),
					castRecord({ time = SERVER_TIME - 2 * 3600, zone = ELWYNN, items = { MACKEREL } }),
					castRecord({ time = SERVER_TIME - 10, zone = ELWYNN, items = { MACKEREL } }),
				})

				loaded.ns.journal:Toggle()

				assert.are.same({ "ledger.fresh" }, { fake.notesShown[1] and fake.notesShown[1].id })
			end
		)

		it("counts a logged gap of exactly an hour, but not one of 59 minutes (ONB-R52, LED-R22)", function()
			local short, shortLoaded = ledger({
				castRecord({ time = SERVER_TIME - 3600, zone = ELWYNN, items = { MACKEREL } }),
				castRecord({ time = SERVER_TIME - 3600 + 59 * 60, zone = ELWYNN, items = { MACKEREL } }),
				castRecord({ time = SERVER_TIME - 10, zone = ELWYNN, items = { MACKEREL } }),
			})
			shortLoaded.ns.journal:Toggle()
			assert.are.same({}, short.notesShown)

			local exact, exactLoaded = ledger({
				castRecord({ time = SERVER_TIME - 3600 - 10, zone = ELWYNN, items = { MACKEREL } }),
				castRecord({ time = SERVER_TIME - 10, zone = ELWYNN, items = { MACKEREL } }),
			})
			exactLoaded.ns.journal:Toggle()
			assert.are.same({ "ledger.fresh" }, { exact.notesShown[1] and exact.notesShown[1].id })
		end)

		it("shows no ledger.fresh with no Fresh Water, whatever the break, and marks it unseen (ONB-R52)", function()
			-- 320 Catches in the latest Cast spend all 300 of the Fresh Water the two hours since the first refilled.
			local flood = {}
			for i = 1, 320 do
				flood[i] = MACKEREL
			end
			local fake, loaded = ledger({
				castRecord({ time = TWO_HOURS_AGO, zone = ELWYNN, items = { MACKEREL } }),
				castRecord({ time = SERVER_TIME - 10, zone = ELWYNN, items = flood }),
			})

			loaded.ns.journal:Toggle()

			assert.is_nil(loaded.ns.JournalFreshPart(loaded.ns.journal))
			assert.are.same({}, fake.notesShown)
			assert.is_nil(fake.global.onboarding.notesSeen["ledger.fresh"])
		end)

		it("shows no note while the Ledger is being written up (ONB-R52, LED-R122)", function()
			local fake, loaded = ledger(nil, { building = true })

			loaded.ns.journal:Toggle()

			assert.are.same({}, fake.notesShown)
		end)
	end)

	describe("the Fish Journal's First look (ONB-R55–R59)", function()
		-- The fixture with a Catch in Elwynn, so Home has a fished tile, unfished (dashed) ones and Notes to self.
		local function fished()
			return ledger({ castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }) })
		end

		-- Each set shown, as "<id> <title>" and its notes' texts.
		local function looks(fake)
			local list = {}
			for i, look in ipairs(fake.looksShown) do
				local texts = {}
				for j, note in ipairs(look.notes) do
					texts[j] = note.n .. " " .. note.text
				end
				list[i] = { look.id .. " " .. look.title, texts }
			end
			return list
		end

		local ALL = {
			"1 Every water you fish gets a tile. Its rank climbs from *Visitor* to *Master*.",
			"2 Your Angler Level. The *blue* stretch is Fresh Water: bonus XP after a break.",
			"3 Notes to self: what’s closest to done. They rewrite themselves as you fish.",
			"4 Find a water or a fish. A fish you haven’t caught is *never named*.",
			"5 Dashed tiles are waters you haven’t fished yet, with the skill they ask.",
		}

		it("is registered before the book first shows, its window the book once made (ONB-R56)", function()
			local fake, loaded = fished()

			assert.is_nil(fake.firstLooks:Window("ledger.journal"))
			loaded.ns.journal:Toggle()
			assert.are.equal(loaded.ns.journal.frame, fake.firstLooks:Window("ledger.journal"))
		end)

		it("shows its five notes the first time the Journal opens, and not again (ONB-R55, ONB-R57)", function()
			local fake, loaded = fished()
			local journal = loaded.ns.journal

			journal:Toggle()

			assert.are.same({ { "ledger.journal the Fish Journal", ALL } }, looks(fake))
			-- each note points at its part of Home: the fished tile's rank, the ink bar's blue part, the first Note
			-- to self, the search slip and an unfished tile's line
			local set = loaded.ns.JournalFirstLook(journal)
			local tile = set.notes[1].target().parent
			assert.are.same({ false, tile.line }, { tile.dashed, set.notes[1].target() })
			assert.are.equal(journal.shown.left.drawn.tiles[1], tile.parent)
			assert.are.equal(journal.shown.right.drawn.xpBar[1].bar.fresh, set.notes[2].target())
			assert.are.equal(journal.shown.right.drawn.link[1].label, set.notes[3].target())
			assert.are.equal(journal.search, set.notes[4].target())
			assert.is_true(set.notes[5].target().parent.dashed)

			journal:Close()
			journal:Toggle()
			assert.are.equal(1, #fake.looksShown)
		end)

		it(
			'has a "?" in the Journal\'s wax beside the close that shows the set again, and hides it while it shows '
				.. "(ONB-R59)",
			function()
				local fake, loaded = fished()
				local journal = loaded.ns.journal
				journal:Toggle()
				fake.firstLooks:Hide()
				local look = journal.frame.help

				assert.is_true(look:IsShown())
				assert.are.equal("?", look.label:GetText())
				look.scripts.OnEnter(look)
				assert.is_true(look.tip:IsShown())
				assert.are.equal("Show the notes for this page again", look.tip.text:GetText())

				look:Click()
				assert.are.equal(2, #fake.looksShown)
				assert.are.equal("ledger.journal", fake.firstLooks:Showing().id)

				look:Click()
				assert.is_nil(fake.firstLooks:Showing())
			end
		)

		it("shows again even with Margin notes off (ONB-R59)", function()
			local fake, loaded = fished()
			fake.global.onboarding.notesOn = false
			local journal = loaded.ns.journal

			journal:Toggle()
			assert.are.same({}, fake.looksShown)

			journal.frame.help:Click()
			assert.are.equal(1, #fake.looksShown)
		end)

		it('off Home, the "?" shows only the search slip\'s note; the rest drop (ONB-R56)', function()
			local fake, loaded = fished()
			local journal = loaded.ns.journal
			journal:Open("zone", { zone = ELWYNN })
			fake.firstLooks:Hide()

			journal.frame.help:Click()

			assert.are.same({ "1 " .. ALL[4]:sub(3) }, looks(fake)[#fake.looksShown][2])
		end)

		it('has no "?" and no set on a Core without First looks (ONB-R90)', function()
			local fake = newFakePagle()
			fake.ns.ModuleHandle.RegisterFirstLook = nil
			fake.profile.announcements.motion = false
			local loaded = fake.load("Pagle_Ledger")
			fake.login()
			fake.enterWorld()

			loaded.ns.journal:Toggle()

			assert.is_false(loaded.ns.journal.frame.help:IsShown())
			assert.are.same({}, fake.looksShown)
		end)
	end)

	it(
		'carries "A new Species for your Ledger." on New Species, so the first toast\'s coin note reads "A new '
			.. 'Species for your Ledger. The coin is…" (ONB-R53, ONB-R52)',
		function()
			local fake = ledger()

			fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
			fake.nextFrame()

			-- the catch side's toast (its level-up is the big side's banner, ANN-R11)
			local announcement
			for _, shown in ipairs(fake.announcements) do
				if shown.rung == "toast" then
					announcement = shown
				end
			end
			assert.are.equal("A new Species for your Ledger.", announcement.moments[1].firstNote)
			local coin = {}
			fake.marginNotes:AnnouncementShown(announcement, "toast", {
				frame = function()
					return coin
				end,
				coin = function()
					return coin
				end,
			}, false)
			assert.are.equal("core.toast", fake.notesShown[1].id)
			assert.are.equal(
				"A new Species for your Ledger. The coin is ",
				fake.notesShown[1].text:sub(1, #"A new Species for your Ledger. The coin is ")
			)
		end
	)
end)
