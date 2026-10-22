-- The Ledger's parts of onboarding on FakePagle (core/onboarding.md): the Field guide's Your Ledger step (ONB-R21,
-- ONB-R36) drawn from a fixture state with the Angler page's crest (LED-R146) and the guide's parts; its line on What's
-- in the box (ONB-R91); the First evening list's `journal` item (ONB-R61); the `ledger.fresh` Margin note (ONB-R52);
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
			"shows the bookplate on the left: Ex Libris, the Angler page's crest holding the likeness, The Angler's "
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
				-- the Angler page's crest: the plain Prestige crest (rank 0) with the player's likeness, no crest pinned
				local crest = loaded.ns.guideLedger.crest
				assert.are.same({ loaded.ns.JournalCoords("Crests", "crest-none") }, crest.frameArt.texCoord)
				assert.are.equal("player", crest.portrait.portrait)
				assert.is_false(crest.pin:IsShown())
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
			"shows ledger.fresh on the ink bar's blue part the first time it opens with Fresh Water, once (ONB-R52)",
			function()
				local fake, loaded = ledger()
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
				assert.are.equal(journal.frame.right.drawn.xpBar[1].bar.fresh, note.target)
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

		it("shows no note while the Ledger is being written up (ONB-R52, LED-R122)", function()
			local fake, loaded = ledger(nil, { building = true })

			loaded.ns.journal:Toggle()

			assert.are.same({}, fake.notesShown)
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
