-- The Prestige letter on FakePagle (LED-R200–R202, ONB-R15–R17): registered with Core in the Ledger's words; sent when
-- the first climb's computed level reaches 60, live or as the login's projection is built, never at prestige rank 1 or
-- above and never once opened or declined; Show me opening the Fish Journal at the Angler page with a Margin note on the
-- Prestige button once, and with no note when the button isn't shown. Core's letter service is its real logic over a fake
-- frame, so what shows is fake.letterOnScreen and fake.letterContent.

local T0 = SERVER_TIME - 700
local ZONE = 12 -- uncharted in the catalogue below: no Zone Mastery rank adds to the numbers (LED-R54)
local FIRST_FISH = 100001
-- One Cast landing this many new Species in a new zone reaches level 60 at prestige rank 0 (Prestige_spec: 200,840 XP
-- against the 200,600 that reaching 60 costs); one fewer stops at 59, and the next Species caught live reaches 60.
local TO_60_SPECIES = 324
local LETTER = "ledger.prestige"

-- A catalogue of TO_60_SPECIES fish, each its own Species, and no area.
local function catalogue()
	local items = {}
	for i = 0, TO_60_SPECIES - 1 do
		items[FIRST_FISH + i] = fishRecord(FIRST_FISH + i)
	end
	return catalogueWith({ items = items })
end

-- A caught Cast by the player's character at `time`, of `count` of the fish from the first.
local function cast(time, count)
	local items = {}
	for i = 1, count do
		items[i] = FIRST_FISH + i - 1
	end
	return castRecord({ time = time, zone = ZONE, items = items })
end

-- A Prestige entry in the log (LOG-R38).
local function prestige(time, rank)
	return { kind = "prestige", char = 1, time = time, rank = rank }
end

-- A Ledger on a fake over the catalogue, its log holding `records` (a Cast reaching 60 by default), logged in and in the
-- world (the projection built) with the onboarding Letter's state `returning`, as a log that holds a Cast makes it.
-- `letters` are the Module letters' states saved before login; `closed` leaves the Journal shut.
---@param options { records: table[]?, letters: table<string, string>?, closed: boolean?, updating: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger(options)
	options = options or {}
	return openJournal({
		catalogue = catalogue(),
		log = options.records or { cast(T0, TO_60_SPECIES) },
		building = options.updating,
		id = false,
		modules = function(fake)
			if options.letters then
				fake.global.onboarding = fake.ns.NewOnboardingState("returning")
				fake.global.onboarding.letters = options.letters
			end
		end,
	})
end

-- The login's cards shown and closed (the Ledger's first build writes one up, LED-R192), so the Letter's wait for them
-- (ONB-R10) is over.
---@param fake FakePagle
local function settle(fake)
	fake.nextFrame()
	fake.nextFrame()
	for _ = 1, 3 do
		if not fake.ns.cards:IsSettled() and #fake.cardsShown > 0 then
			fake.closeCard()
		end
	end
end

-- The world's PLAYER_ENTERING_WORLD and the 4 s after it (ONB-R10), the cards settled: a letter due shows now.
---@param fake FakePagle
local function arrive(fake)
	fake.letter:EnteredWorld()
	fake.wait(fake.ns.LETTER_DELAY)
	settle(fake)
end

-- The Prestige button's face on the Journal's pages, nil when none shows.
---@param loaded LoadedAddon
---@return table?
local function prestigeButton(loaded)
	return loaded.ns.JournalPrestigeButton(loaded.ns.journal)
end

describe("the Prestige letter's words (LED-R200)", function()
	it(
		"is registered with Core, shows the kicker, the hand and Show me and Later when it is sent (LED-R200)",
		function()
			local fake, loaded = ledger()
			arrive(fake)

			assert.is_true(fake.letterOnScreen)
			assert.are.equal(LETTER, fake.letter:Showing())
			assert.are.same({
				kicker = "A letter, left on the dock",
				text = "Sixty: the top of the climb. Begin a new Ledger whenever you like. Your level starts again from 1, "
					.. "a Prestige mark goes on your Ledger, and nothing you’ve earned is taken away. Or stay at sixty as "
					.. "long as you please.",
				confirm = "Show me",
				later = "Later",
			}, {
				kicker = fake.letterContent.kicker,
				text = fake.letterContent.text,
				confirm = fake.letterContent.confirm,
				later = fake.letterContent.later,
			})
			assert.are.equal("waiting", fake.global.onboarding.letters[LETTER])
			assert.are.equal(60, loaded.ns.Level(loaded.ns.projection:GetState()))
		end
	)

	it("is one letter among Core's: the Ledger can't register it twice (ONB-R15)", function()
		local _, loaded = ledger()

		local ok, problem = pcall(function()
			loaded.ns.Module:RegisterLetter(LETTER, {
				kicker = "k",
				text = "t",
				confirm = "c",
				later = "l",
				onConfirm = function() end,
			})
		end)

		assert.is_false(ok)
		assert.matches("letter ledger%.prestige is registered already", tostring(problem))
	end)
end)

describe("when the Prestige letter comes (LED-R201)", function()
	it("is due at login when the projection says level 60 at rank 0 and the letter is waiting (LED-R201)", function()
		local fake = ledger()
		assert.is_false(fake.letterOnScreen)

		arrive(fake)

		assert.is_true(fake.letterOnScreen)
		assert.are.equal("waiting", fake.global.onboarding.letters[LETTER])
	end)

	it("is due at login when it was `later` too, and Later then declines it (LED-R201, ONB-R16)", function()
		local fake = ledger({ letters = { [LETTER] = "later" } })
		arrive(fake)
		assert.is_true(fake.letterOnScreen)

		fake.letter:Later()

		assert.are.equal("declined", fake.global.onboarding.letters[LETTER])
	end)

	it("is never due at login once declined or opened (LED-R201, ONB-R16)", function()
		for _, state in ipairs({ "declined", "opened" }) do
			local fake = ledger({ letters = { [LETTER] = state } })

			arrive(fake)

			assert.are.equal(false, fake.letterOnScreen, state)
			assert.are.equal(state, fake.global.onboarding.letters[LETTER])
		end
	end)

	it("is not due below 60: a login at 59 sends nothing (LED-R201)", function()
		local fake = ledger({ records = { cast(T0, TO_60_SPECIES - 1) } })

		arrive(fake)

		assert.is_false(fake.letterOnScreen)
		assert.is_nil(fake.global.onboarding.letters)
	end)

	it("is raised live when a Cast reaches 60 at rank 0, once the toast is gone (LED-R201)", function()
		local fake, loaded = ledger({ records = { cast(T0, TO_60_SPECIES - 1) } })
		arrive(fake)
		assert.are.equal(59, loaded.ns.Level(loaded.ns.projection:GetState()))
		assert.is_false(fake.letterOnScreen)

		fake.playCast("caught", { { itemID = FIRST_FISH + TO_60_SPECIES - 1, quantity = 1 } })
		fake.nextFrame()
		fake.nextFrame()

		assert.are.equal(60, loaded.ns.Level(loaded.ns.projection:GetState()))
		assert.is_true(fake.letterOnScreen)
		assert.are.equal(LETTER, fake.letter:Showing())
	end)

	it("is raised live when another Module's Activity XP brings the climb to 60 (LED-R201, LED-R39)", function()
		local handle
		local fake, loaded = openJournal({
			catalogue = catalogue(),
			log = { cast(T0, TO_60_SPECIES - 1) },
			id = false,
			modules = function(f)
				handle = f.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
				handle:NewProjection({
					db = {},
					rulesVersion = 1,
					reset = function()
						return {}
					end,
					apply = function() end,
				})
			end,
		})
		arrive(fake)
		assert.are.equal(59, loaded.ns.Level(loaded.ns.projection:GetState()))
		assert.is_false(fake.letterOnScreen)

		handle:ReportXPEarned(2000)
		loaded.client.runTimers()
		fake.nextFrame()
		fake.nextFrame()

		assert.are.equal(60, loaded.ns.Level(loaded.ns.projection:GetState()))
		assert.is_true(fake.letterOnScreen)
	end)

	it("is never raised at prestige rank 1 or above, live or at login (LED-R201)", function()
		-- The Prestige starts the next climb at level 1 with the 240 carried XP (LED-R32); another Cast of 324 Species
		-- would be needed for 60, so the letter stays away at the new rank (Prestige_spec); and a live Cast that does
		-- reach 60 at rank 1 sends nothing either.
		local fake, loaded = ledger({ records = { cast(T0, TO_60_SPECIES), prestige(T0 + 1, 1) } })
		arrive(fake)

		assert.are.equal(1, loaded.ns.projection:GetState().prestige)
		assert.is_false(fake.letterOnScreen)
		assert.is_nil(fake.global.onboarding.letters)
		assert.is_false(loaded.ns.PrestigeLetterDue(loaded.ns.projection:GetState(), false))
	end)

	it(
		"drops a letter still waiting to show when the Angler Prestiges first, in the same login (LED-R201, LED-R33)",
		function()
			local fake, loaded = ledger({ records = { cast(T0, TO_60_SPECIES) } })
			assert.are.equal("waiting", fake.global.onboarding.letters[LETTER])
			loaded.ns.journal:Open("angler")
			loaded.ns.AskPrestige()
			local card = loaded.ns.journal.prestigeCard
			card.yes.scripts.OnClick(card.yes)

			arrive(fake)

			assert.are.equal(1, loaded.ns.projection:GetState().prestige)
			assert.is_false(fake.letterOnScreen)
		end
	)

	it(
		"sends nothing while the projection is updating, and the login's check does once it is built (LED-R201)",
		function()
			local fake = ledger({ updating = true })
			arrive(fake)
			assert.is_false(fake.letterOnScreen)
			assert.is_nil(fake.global.onboarding.letters)

			fake.enterWorld()
			settle(fake)

			assert.is_true(fake.letterOnScreen)
		end
	)

	it("is raised once a login: after Later it doesn't come again until the next login (LED-R201, ONB-R10)", function()
		local fake, loaded = ledger({ records = { cast(T0, TO_60_SPECIES - 1) } })
		arrive(fake)
		fake.playCast("caught", { { itemID = FIRST_FISH + TO_60_SPECIES - 1, quantity = 1 } })
		fake.nextFrame()
		fake.nextFrame()
		assert.is_true(fake.letterOnScreen)
		fake.letter:Later()
		assert.are.equal("later", fake.global.onboarding.letters[LETTER])

		loaded.ns.NotePrestigeLetter()
		fake.wait(fake.ns.LETTER_DELAY)

		assert.is_false(fake.letterOnScreen)
		assert.are.equal("later", fake.global.onboarding.letters[LETTER])
	end)
end)

describe("Show me (LED-R202)", function()
	-- The letter on screen, its confirm button pressed: Core sets it opened and calls the Ledger's onConfirm.
	local function showMe(fake)
		assert.is_true(fake.letterOnScreen)
		fake.letter:Open()
	end

	it(
		"sets opened, hides the letter and opens the Journal at the Angler page with the note on the button (LED-R202)",
		function()
			local fake, loaded = ledger()
			arrive(fake)

			showMe(fake)

			assert.is_false(fake.letterOnScreen)
			assert.are.equal("opened", fake.global.onboarding.letters[LETTER])
			local journal = loaded.ns.journal
			assert.is_true(journal:IsShown())
			assert.are.equal(loaded.ns.JOURNAL_ANGLER, journal.router:Place().id)
			local button = assert(prestigeButton(loaded))
			assert.are.equal(1, #fake.notesShown)
			local note = fake.notesShown[1]
			assert.are.equal(LETTER, note.id)
			assert.are.equal("|cff9a2a1aBegin a new Ledger|r here, when you’re ready. No hurry.", note.text)
			assert.are.equal(button, note.target)
			assert.are.equal("Begin a new Ledger (Prestige)", button.label.text)
			assert.is_true(fake.global.onboarding.notesSeen[LETTER])
		end
	)

	it(
		"prestiges nothing: the log gets no P1 and no confirm card is up, the Journal's card staying the way (LED-R33)",
		function()
			local fake, loaded = ledger()
			arrive(fake)

			showMe(fake)

			for _, entry in ipairs(fake.catchLog.data.entries) do
				assert.is_not.equal("P1|", entry:sub(1, 3))
			end
			assert.are.equal(0, loaded.ns.projection:GetState().prestige)
			assert.is_false(loaded.ns.IsPrestigeConfirmShown())
			assert.is_true(loaded.ns.CanPrestige())
		end
	)

	it(
		"shows the note once: a second Show me, in another login, opens the page without it (LED-R202, ONB-R50)",
		function()
			local fake, loaded = ledger()
			arrive(fake)
			showMe(fake)
			assert.are.equal(1, #fake.notesShown)

			loaded.ns.journal:Close()
			loaded.ns.ShowPrestigeLetterPage()

			assert.is_true(loaded.ns.journal:IsShown())
			assert.are.equal(1, #fake.notesShown)
			assert.is_not_nil(prestigeButton(loaded))
		end
	)

	it("shows no note with Margin notes off, but still opens the page (ONB-R50)", function()
		local fake, loaded = ledger()
		fake.onboarding:SetNotesOn(false)
		arrive(fake)

		showMe(fake)

		assert.are.equal(loaded.ns.JOURNAL_ANGLER, loaded.ns.journal.router:Place().id)
		assert.is_not_nil(prestigeButton(loaded))
		assert.are.same({}, fake.notesShown)
	end)

	it("opens the page from another spread of a Journal already open (LED-R202)", function()
		local fake, loaded = ledger()
		arrive(fake)
		loaded.ns.journal:Open("home")

		showMe(fake)

		assert.are.equal(loaded.ns.JOURNAL_ANGLER, loaded.ns.journal.router:Place().id)
		assert.are.equal(1, #fake.notesShown)
		assert.are.equal(prestigeButton(loaded), fake.notesShown[1].target)
	end)

	it("opens the page with no note when the button isn't shown: the level is no longer 60 (LED-R202)", function()
		local fake, loaded = ledger()
		arrive(fake)
		-- The computed level falls below 60 before Show me (an Activity XP recount, LED-R38): no button, so no note.
		local state = loaded.ns.projection:GetState()
		state.xp = 0

		showMe(fake)

		assert.is_false(loaded.ns.CanPrestige())
		assert.are.equal(loaded.ns.JOURNAL_ANGLER, loaded.ns.journal.router:Place().id)
		assert.is_nil(prestigeButton(loaded))
		assert.are.same({}, fake.notesShown)
		assert.is_nil(fake.global.onboarding.notesSeen[LETTER])
		assert.are.equal("opened", fake.global.onboarding.letters[LETTER])
	end)

	it("opens the page with no note while the projection is updating (LED-R202, LED-R33)", function()
		local fake, loaded = ledger()
		arrive(fake)
		loaded.ns.projection.IsUpdating = function()
			return true
		end

		showMe(fake)

		assert.is_true(loaded.ns.journal:IsShown())
		assert.is_nil(prestigeButton(loaded))
		assert.are.same({}, fake.notesShown)
		assert.is_nil(fake.global.onboarding.notesSeen[LETTER])
	end)

	it("leaves Prestiging to the Journal's own confirm card: pressing the button asks, as ever (LED-R33)", function()
		local fake, loaded = ledger()
		arrive(fake)
		showMe(fake)

		local button = assert(prestigeButton(loaded))
		button.scripts.OnClick(button)

		assert.is_true(loaded.ns.IsPrestigeConfirmShown())
		assert.are.equal(0, loaded.ns.projection:GetState().prestige)
	end)
end)

describe("the Prestige letter from /pagle dev onboarding letter ledger.prestige (ONB-R83)", function()
	it("shows it now whatever its state, and Show me works as from the login's (ONB-R83, LED-R202)", function()
		local fake, loaded = ledger({ records = { cast(T0, 1) }, letters = { [LETTER] = "declined" } })
		arrive(fake)
		assert.is_false(fake.letterOnScreen)
		fake.slash("dev on")

		fake.slash("dev onboarding letter " .. LETTER)
		assert.is_true(fake.letterOnScreen)
		assert.are.equal("Show me", fake.letterContent.confirm)
		fake.letter:Open()

		-- Below 60 here, so the Angler page has no button and the page opens without the note.
		assert.are.equal(loaded.ns.JOURNAL_ANGLER, loaded.ns.journal.router:Place().id)
		assert.are.same({}, fake.notesShown)
	end)
end)
