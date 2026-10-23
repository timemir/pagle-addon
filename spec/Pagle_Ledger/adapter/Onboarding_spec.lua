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
				-- the note is the guide's, 290 wide, its *term* for the guide's red pencil
				local note = right.children[#right.children]
				assert.are.same({ 70, 290 }, { note.x, note.w })
			end
		)

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

		it(
			"shows ledger.fresh on the ink bar's blue part the first time it opens with Fresh Water once a Session has "
				.. "ended, once (ONB-R52)",
			function()
				-- A Session that ended before this login, 700 s ago (LOG-R60).
				local fake, loaded = ledger({ castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }) })
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
				local fake, loaded = ledger({ castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }) })
				local journal = loaded.ns.journal

				journal:Open("zone", { zone = ELWYNN })
				assert.are.same({}, fake.notesShown)

				journal:Close()
				journal:Open("home")
				assert.are.same({ "ledger.fresh" }, { fake.notesShown[1] and fake.notesShown[1].id })
			end
		)

		it("shows no ledger.fresh to a new Angler before any Session, and marks it unseen (ONB-R52)", function()
			local fake, loaded = ledger()

			loaded.ns.journal:Toggle()

			assert.is_truthy(loaded.ns.JournalFreshPart(loaded.ns.journal))
			assert.are.same({}, fake.notesShown)
			assert.is_nil(fake.global.onboarding.notesSeen["ledger.fresh"])
		end)

		it("shows no ledger.fresh while the first Session is still open (ONB-R52, LOG-R64)", function()
			local fake, loaded =
				ledger({ castRecord({ time = SERVER_TIME - 10, zone = ELWYNN, items = { MACKEREL } }) })
			assert.is_not_nil(fake.Pagle.GetSession())

			loaded.ns.journal:Toggle()

			assert.is_truthy(loaded.ns.JournalFreshPart(loaded.ns.journal))
			assert.are.same({}, fake.notesShown)
			assert.is_nil(fake.global.onboarding.notesSeen["ledger.fresh"])
		end)

		it(
			"shows ledger.fresh at the first opening after the first Session's SessionEnded (ONB-R52, LOG-R62)",
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

				assert.are.same({ "ledger.fresh" }, { fake.notesShown[1] and fake.notesShown[1].id })
			end
		)

		it("counts a Session ended before the one open now, from the Catch log (ONB-R52, LOG-R98)", function()
			local fake, loaded = ledger({
				castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }),
				castRecord({ time = SERVER_TIME - 10, zone = ELWYNN, items = { MACKEREL } }),
			})
			assert.is_not_nil(fake.Pagle.GetSession())

			loaded.ns.journal:Toggle()

			assert.are.same({ "ledger.fresh" }, { fake.notesShown[1] and fake.notesShown[1].id })
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
