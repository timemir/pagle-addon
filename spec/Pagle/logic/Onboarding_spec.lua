-- Core's onboarding state (core/onboarding.md › Data): the table in PagleDB.global.onboarding, who is new, returning
-- or another character (ONB-R1–R3), the calls the Letter, the guide, Margin notes, First looks and the First evening
-- list make on it, `/pagle guide notes` (ONB-R80) and the `/pagle dev onboarding` group (ONB-R83). Pure logic
-- (CORE-R7), so it runs over plain tables here.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local ADA = "Player-4618-0A1B2C3D"
local BRAM = "Player-4618-0B2C3D4E"

-- A Catch log holding `entries`, opened as Core opens it.
local function catchLog(entries)
	return ns.OpenCatchLog(savedLog(entries), { decodeErrors = 0 }, SERVER_TIME)
end

-- Core's onboarding over `global` (PagleDB.global), with each hook call and chat line noted.
local function onboardingOver(global)
	local seen = { printed = {}, calls = {} }
	local onboarding = ns.NewOnboarding({
		global = function()
			return global
		end,
		call = function(fn, ...)
			seen.calls[#seen.calls + 1] = fn
			return fn(...)
		end,
		print = function(line)
			seen.printed[#seen.printed + 1] = line
		end,
	})
	return onboarding, seen
end

-- A global whose onboarding state was created for a new Angler, with `guid` in characters if given.
local function created(guid)
	local global = {}
	ns.AddOnboarding(global, catchLog({ BUILD_ENTRY }))
	if guid then
		global.onboarding.characters[guid] = true
	end
	return global
end

describe("ns.NewOnboardingState", function()
	it("holds every key in Data with its default, and letter as given (core/onboarding.md › Data)", function()
		assert.are.same({
			letter = "waiting",
			stepsSeen = {},
			guideDone = false,
			skipped = false,
			reopen = false,
			notesOn = true,
			notesSeen = {},
			looksSeen = {},
			evening = { shown = false, closed = false, done = {} },
			characters = {},
		}, ns.NewOnboardingState("waiting"))
		assert.are.equal("returning", ns.NewOnboardingState("returning").letter)
		assert.is_nil(ns.NewOnboardingState("waiting").guideStep)
	end)

	it("makes fresh tables each call, so no two states share one (core/onboarding.md › Data)", function()
		local a, b = ns.NewOnboardingState("waiting"), ns.NewOnboardingState("waiting")

		a.notesSeen["core.nod"] = true
		a.evening.done.cast = true

		assert.are.same({}, b.notesSeen)
		assert.are.same({}, b.evening.done)
	end)
end)

describe("ns.AddOnboarding", function()
	it("gives an empty Catch log letter = waiting (ONB-R1, ONB-R2)", function()
		local global = {}

		assert.is_true(ns.AddOnboarding(global, catchLog({ BUILD_ENTRY })))

		assert.are.same(ns.NewOnboardingState("waiting"), global.onboarding)
	end)

	it("gives a Catch log that holds a C1 Cast letter = returning (ONB-R2)", function()
		local global = {}

		ns.AddOnboarding(global, catchLog({ castEntry(SERVER_TIME - 9000), BUILD_ENTRY }))

		assert.are.equal("returning", global.onboarding.letter)
	end)

	it("counts only Casts: Skill Readings and build entries alone leave a new Angler (ONB-R2)", function()
		local global = {}

		ns.AddOnboarding(global, catchLog({ "S1|1|1791731000|0|80|150|0", BUILD_ENTRY }))

		assert.are.equal("waiting", global.onboarding.letter)
	end)

	it("never recreates a table that exists (ONB-R1)", function()
		local state = ns.NewOnboardingState("opened")
		state.notesSeen["core.nod"] = true
		local global = { onboarding = state }

		assert.is_false(ns.AddOnboarding(global, catchLog({ castEntry(SERVER_TIME - 9000) })))

		assert.are.equal(state, global.onboarding)
		assert.are.equal("opened", global.onboarding.letter)
		assert.is_true(global.onboarding.notesSeen["core.nod"])
	end)
end)

describe("PagleDB's onboarding migration", function()
	it("adds the table in one step, from the Catch log it is handed (catch-log.md › Data, ONB-R1)", function()
		local new, returning = { global = { schemaVersion = 1 } }, { global = { schemaVersion = 1 } }

		ns.Migrate(new, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog({ BUILD_ENTRY }) })
		ns.Migrate(returning, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog({ castEntry(SERVER_TIME - 9000) }) })

		assert.are.equal(#ns.PAGLEDB_MIGRATIONS, new.global.schemaVersion)
		assert.are.equal("waiting", new.global.onboarding.letter)
		assert.are.equal("returning", returning.global.onboarding.letter)
	end)

	it("leaves a DB already at schemaVersion 2 as it is, its table or none (ONB-R1)", function()
		local db = { global = { schemaVersion = 2 } }

		ns.Migrate(db, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog({}) })

		assert.is_nil(db.global.onboarding)
	end)
end)

describe("ns.NewOnboarding", function()
	describe("new or returning (ONB-R2)", function()
		it("is returning only when letter is returning (ONB-R2)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.is_false(onboarding:IsReturning())
			global.onboarding.letter = "returning"
			assert.is_true(onboarding:IsReturning())
		end)

		it("raises the welcome hook for a returning Angler, and only for one (ONB-R2)", function()
			local global = created()
			local onboarding, seen = onboardingOver(global)
			local raised = 0
			local function hook()
				raised = raised + 1
			end
			onboarding:SetHook("welcome", hook)

			assert.is_false(onboarding:Welcome())
			global.onboarding.letter = "returning"
			assert.is_true(onboarding:Welcome())

			assert.are.equal(1, raised)
			-- Through `call`, so a hook's error is reported, not raised (CORE-R23's sense).
			assert.are.same({ hook }, seen.calls)
		end)

		it("raises nothing while no hook is set (ONB-R2)", function()
			local global = created()
			global.onboarding.letter = "returning"
			local onboarding, seen = onboardingOver(global)

			assert.is_true(onboarding:Welcome())

			assert.are.same({}, seen.calls)
		end)

		it("refuses a hook it doesn't know, or one that isn't a function", function()
			local onboarding = onboardingOver(created())

			assert.has_error(function()
				onboarding:SetHook("letter", function() end)
			end)
			assert.has_error(function()
				onboarding:SetHook("welcome", "core.welcome")
			end)
		end)
	end)

	describe("another character (ONB-R3)", function()
		it("adds the first character without raising the character hook (ONB-R3, Data)", function()
			local global = created()
			local onboarding, seen = onboardingOver(global)
			onboarding:SetHook("character", function() end)

			assert.is_false(onboarding:SeeCharacter(ADA, true))

			assert.are.same({ [ADA] = true }, global.onboarding.characters)
			assert.are.same({}, seen.calls)
		end)

		it("raises the character hook once at a second GUID's first login, and adds it (ONB-R3)", function()
			local global = created(ADA)
			local onboarding = onboardingOver(global)
			local raised = {}
			onboarding:SetHook("character", function()
				raised[#raised + 1] = "character"
			end)

			assert.is_true(onboarding:SeeCharacter(BRAM, true))
			assert.is_false(onboarding:SeeCharacter(BRAM, true))
			assert.is_false(onboarding:SeeCharacter(ADA, true))

			assert.are.same({ "character" }, raised)
			assert.are.same({ [ADA] = true, [BRAM] = true }, global.onboarding.characters)
		end)

		it("adds a second GUID without the hook while QoL isn't registered (ONB-R3, ONB-R101)", function()
			local global = created(ADA)
			local onboarding, seen = onboardingOver(global)
			onboarding:SetHook("character", function() end)

			assert.is_false(onboarding:SeeCharacter(BRAM, false))
			assert.is_false(onboarding:SeeCharacter(BRAM, true))

			assert.are.same({}, seen.calls)
			assert.are.same({ [ADA] = true, [BRAM] = true }, global.onboarding.characters)
		end)

		it("does nothing without a GUID to key the character by (ONB-R3, LOG-R26)", function()
			local global = created(ADA)
			local onboarding = onboardingOver(global)

			assert.is_false(onboarding:SeeCharacter(nil, true))

			assert.are.same({ [ADA] = true }, global.onboarding.characters)
		end)
	end)

	describe("the Letter (ONB-R10, ONB-R12)", function()
		it("waits while waiting or later, and never after (ONB-R10, ONB-R12)", function()
			local global = created()
			local onboarding = onboardingOver(global)
			local due = {}
			for _, letter in ipairs({ "waiting", "later", "declined", "opened", "returning" }) do
				global.onboarding.letter = letter
				due[letter] = onboarding:IsLetterDue()
			end

			assert.are.same({ waiting = true, later = true, declined = false, opened = false, returning = false }, due)
		end)

		it("goes waiting, then later, then declined with each Later (ONB-R12)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.are.equal("waiting", onboarding:Letter())
			assert.are.equal("later", onboarding:LetterLater())
			assert.are.equal("declined", onboarding:LetterLater())
			assert.are.equal("declined", onboarding:LetterLater())
			assert.are.equal("declined", global.onboarding.letter)
		end)

		it("leaves an opened or returning Letter as it is on Later (ONB-R12)", function()
			for _, letter in ipairs({ "opened", "returning" }) do
				local global = created()
				global.onboarding.letter = letter

				assert.are.equal(letter, onboardingOver(global):LetterLater())
			end
		end)

		it("is opened by Open the letter, from waiting or later (ONB-R12)", function()
			for _, letter in ipairs({ "waiting", "later" }) do
				local global = created()
				global.onboarding.letter = letter

				onboardingOver(global):OpenLetter()

				assert.are.equal("opened", global.onboarding.letter)
			end
		end)
	end)

	describe("the letters a Module sends (ONB-R15, ONB-R16)", function()
		local PRESTIGE = "ledger.prestige"

		it(
			"keeps the onboarding Letter's state in `letter` and a Module letter's in `letters`, made as one is sent (ONB-R16)",
			function()
				local global = created()
				local onboarding = onboardingOver(global)

				assert.are.equal("waiting", onboarding:Letter(ns.ONBOARDING_LETTER))
				assert.is_nil(onboarding:Letter(PRESTIGE))
				assert.is_false(onboarding:IsLetterDue(PRESTIGE))
				assert.is_true(onboarding:RaiseLetter(PRESTIGE))

				assert.are.same({ [PRESTIGE] = "waiting" }, global.onboarding.letters)
				assert.are.equal("waiting", global.onboarding.letter)
			end
		)

		it(
			"leaves a saved state with no `letters` as it is while only the onboarding Letter is read or answered (ONB-R16)",
			function()
				local global = created()
				local onboarding = onboardingOver(global)

				onboarding:IsLetterDue()
				onboarding:Letter(ns.ONBOARDING_LETTER)
				onboarding:LetterLater(ns.ONBOARDING_LETTER)
				onboarding:OpenLetter(ns.ONBOARDING_LETTER)

				assert.is_nil(global.onboarding.letters)
				assert.are.equal("opened", global.onboarding.letter)
			end
		)

		it("is due while waiting or later, and never once declined or opened (ONB-R16)", function()
			local global = created()
			local onboarding = onboardingOver(global)
			local due = {}
			for _, state in ipairs({ "waiting", "later", "declined", "opened" }) do
				global.onboarding.letters = { [PRESTIGE] = state }
				due[state] = onboarding:RaiseLetter(PRESTIGE)
			end

			assert.are.same({ waiting = true, later = true, declined = false, opened = false }, due)
			assert.are.equal("opened", global.onboarding.letters[PRESTIGE])
		end)

		it(
			"goes waiting, then later, then declined with each Later, as the onboarding Letter does (ONB-R16)",
			function()
				local global = created()
				local onboarding = onboardingOver(global)
				onboarding:RaiseLetter(PRESTIGE)

				assert.are.equal("later", onboarding:LetterLater(PRESTIGE))
				assert.are.equal("declined", onboarding:LetterLater(PRESTIGE))
				assert.are.equal("declined", onboarding:LetterLater(PRESTIGE))
				assert.are.equal("declined", global.onboarding.letters[PRESTIGE])
				assert.are.equal("waiting", global.onboarding.letter)
			end
		)

		it("is opened by the confirm button from waiting or later, and Later leaves an opened one (ONB-R16)", function()
			for _, state in ipairs({ "waiting", "later" }) do
				local global = created()
				global.onboarding.letters = { [PRESTIGE] = state }
				local onboarding = onboardingOver(global)

				onboarding:OpenLetter(PRESTIGE)
				assert.are.equal("opened", onboarding:LetterLater(PRESTIGE))

				assert.are.equal("opened", global.onboarding.letters[PRESTIGE])
			end
		end)

		it("is forgotten by the dev reset, with the rest of the state (ONB-R17, ONB-R83)", function()
			local global = created(ADA)
			local onboarding = onboardingOver(global)
			onboarding:RaiseLetter(PRESTIGE)
			onboarding:OpenLetter(PRESTIGE)

			onboarding:Reset(ADA)

			assert.is_nil(global.onboarding.letters)
			assert.is_false(onboarding:IsLetterDue(PRESTIGE))
			assert.is_true(onboarding:RaiseLetter(PRESTIGE))
		end)
	end)

	describe("the Field guide (ONB-R22, ONB-R25, ONB-R26)", function()
		it("keeps the step last shown and every step seen (ONB-R22, ONB-R24)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.is_nil(onboarding:GuideStep())
			onboarding:StepShown("welcome")
			onboarding:StepShown("box")
			onboarding:StepShown("welcome")

			assert.are.equal("welcome", onboarding:GuideStep())
			assert.is_true(onboarding:IsStepSeen("box"))
			assert.is_false(onboarding:IsStepSeen("moments"))
			assert.are.same({ welcome = true, box = true }, global.onboarding.stepsSeen)
		end)

		it("notes the guide done, skipped and due to reopen (ONB-R25, ONB-R26)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.is_false(onboarding:IsGuideDone())
			assert.is_false(onboarding:IsSkipped())
			assert.is_false(onboarding:ShouldReopen())
			onboarding:FinishGuide()
			onboarding:SkipGuide()
			onboarding:SetReopen(true)

			assert.is_true(onboarding:IsGuideDone())
			assert.is_true(onboarding:IsSkipped())
			assert.is_true(onboarding:ShouldReopen())
			onboarding:SetReopen(false)
			assert.is_false(global.onboarding.reopen)
		end)
	end)

	describe("Margin notes and First looks (ONB-R50, ONB-R55, ONB-R81)", function()
		it("are on by default, and the setting turns them off and on (ONB-R81)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.is_true(onboarding:AreNotesOn())
			onboarding:SetNotesOn(false)
			assert.is_false(onboarding:AreNotesOn())
			assert.is_false(global.onboarding.notesOn)
		end)

		it("note each note and each set seen, once per account (ONB-R50, ONB-R55)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			onboarding:MarkNoteSeen("core.nod")
			onboarding:MarkLookSeen("ledger.journal")

			assert.is_true(onboarding:IsNoteSeen("core.nod"))
			assert.is_false(onboarding:IsNoteSeen("core.toast"))
			assert.is_true(onboarding:IsLookSeen("ledger.journal"))
			assert.is_false(onboarding:IsLookSeen("core.shop"))
			assert.are.same({ ["core.nod"] = true }, global.onboarding.notesSeen)
			assert.are.same({ ["ledger.journal"] = true }, global.onboarding.looksSeen)
		end)

		it("show again, once each, once both seen lists are cleared (ONB-R80, ONB-R81)", function()
			local global = created()
			local onboarding = onboardingOver(global)
			onboarding:MarkNoteSeen("core.nod")
			onboarding:MarkLookSeen("ledger.journal")
			onboarding:SetNotesOn(false)

			onboarding:ShowNotesAgain()

			assert.are.same({}, global.onboarding.notesSeen)
			assert.are.same({}, global.onboarding.looksSeen)
			-- The setting is the Angler's: showing them again doesn't turn them on.
			assert.is_false(global.onboarding.notesOn)
		end)
	end)

	describe("the First evening list (ONB-R60–R63)", function()
		it("notes it shown, and closed (ONB-R60, ONB-R63)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.is_false(onboarding:IsEveningShown())
			assert.is_false(onboarding:IsEveningClosed())
			onboarding:MarkEveningShown()
			onboarding:CloseEvening()

			assert.are.same({ shown = true, closed = true, done = {} }, global.onboarding.evening)
		end)

		it("keeps items done before the list docks, each once (ONB-R61)", function()
			local global = created()
			local onboarding = onboardingOver(global)

			assert.is_true(onboarding:CompleteEveningItem("cast"))
			assert.is_false(onboarding:CompleteEveningItem("cast"))

			assert.is_true(onboarding:IsEveningItemDone("cast"))
			assert.is_false(onboarding:IsEveningItemDone("catch"))
			assert.are.same({ cast = true }, global.onboarding.evening.done)
		end)

		it("ignores an item once the list is closed (ONB-R61)", function()
			local global = created()
			local onboarding = onboardingOver(global)
			onboarding:CloseEvening()

			assert.is_false(onboarding:CompleteEveningItem("journal"))

			assert.are.same({}, global.onboarding.evening.done)
		end)

		it("shows a closed list again, unclosed, from the Settings root's checkbox (ONB-R63)", function()
			local global = created()
			local onboarding = onboardingOver(global)
			onboarding:CloseEvening()

			onboarding:ReopenEvening()

			assert.is_false(onboarding:IsEveningClosed())
			assert.is_true(onboarding:CompleteEveningItem("journal"))
		end)
	end)

	describe("/pagle guide (ONB-R80, CORE-R61)", function()
		it("clears notesSeen and looksSeen with notes, and prints ONB-R80's line (ONB-R80)", function()
			local global = created()
			local onboarding, seen = onboardingOver(global)
			onboarding:MarkNoteSeen("core.nod")
			onboarding:MarkLookSeen("ledger.journal")

			assert.is_nil(onboarding:Guide("notes"))
			assert.is_nil(onboarding:Guide("NOTES"))

			assert.are.same({}, global.onboarding.notesSeen)
			assert.are.same({}, global.onboarding.looksSeen)
			assert.are.same({
				"Pagle: margin notes will show again, once each.",
				"Pagle: margin notes will show again, once each.",
			}, seen.printed)
		end)

		it("asks for the help list until the guide can open, then opens it (ONB-R80, #322)", function()
			local onboarding, seen = onboardingOver(created())

			assert.are.equal("help", onboarding:Guide(""))

			local opened = {}
			onboarding:SetGuideOpener(function(args)
				opened[#opened + 1] = args
			end)
			assert.is_nil(onboarding:Guide(""))
			assert.is_nil(onboarding:Guide("box"))

			assert.are.same({ "", "box" }, opened)
			assert.are.same({}, seen.printed)
		end)
	end)

	describe("the dev reset (ONB-R83)", function()
		it("puts the state back as created for a new Angler, whatever the log holds (ONB-R83)", function()
			local global = created(ADA)
			local onboarding = onboardingOver(global)
			global.onboarding.letter = "returning"
			global.onboarding.characters[BRAM] = true
			onboarding:StepShown("box")
			onboarding:MarkNoteSeen("core.nod")
			onboarding:CompleteEveningItem("cast")
			onboarding:SetNotesOn(false)

			onboarding:Reset(BRAM)

			local expected = ns.NewOnboardingState("waiting")
			expected.characters[BRAM] = true
			assert.are.same(expected, global.onboarding)
		end)

		it("runs a subcommand added to the group, with the rest of the line (ONB-R83)", function()
			local onboarding, seen = onboardingOver(created())
			local ran = {}
			onboarding:AddDevCommand("step", "step <id>", function(args)
				ran[#ran + 1] = args
			end)

			onboarding:RunDev("STEP  moments ")

			assert.are.same({ "moments" }, ran)
			assert.are.same({}, seen.printed)
		end)

		it("prints the group's usage for none or an unknown one, listing each in the order added (ONB-R83)", function()
			local onboarding, seen = onboardingOver(created())
			onboarding:AddDevCommand("reset", "reset", function() end)
			onboarding:AddDevCommand("step", "step <id>", function() end)

			onboarding:RunDev("")
			onboarding:RunDev("letters")

			local usage = "Pagle dev: /pagle dev onboarding reset | step <id>"
			assert.are.same({ usage, usage }, seen.printed)
		end)

		it("refuses a subcommand added twice, or one with no function (ONB-R83)", function()
			local onboarding = onboardingOver(created())
			onboarding:AddDevCommand("reset", "reset", function() end)

			assert.has_error(function()
				onboarding:AddDevCommand("Reset", "reset", function() end)
			end)
			assert.has_error(function()
				onboarding:AddDevCommand("letter", "letter")
			end)
		end)
	end)
end)
