-- The Letter on the client, through the real TOC and the fake client (core/onboarding.md › The Letter): when it
-- shows (ONB-R10), its frame and copy (ONB-R11), its buttons (ONB-R12), the menu tooltip's "A letter for you"
-- (ONB-R13, CORE-R55), the restriction (ONB-R14), `/pagle dev onboarding letter` (ONB-R83), its tour stop (ONB-R84),
-- motion and sound (core/onboarding.md › Motion, › Sounds).

local SOUND_LETTER = "7355 SFX"

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- PagleDB.global.onboarding as the client holds it.
local function state(loaded)
	return loaded.env.PagleDB.global.onboarding
end

-- The Letter's frame, nil before its first showing.
local function letterOf(loaded)
	return loaded.env.PagleLetter
end

-- Whether the Letter is on screen.
local function shows(loaded)
	local frame = letterOf(loaded)
	return frame ~= nil and frame:IsShown()
end

-- Turns Animations off (SET-R30).
local function stillness(loaded)
	loaded.ns.db.profile.announcements.motion = false
end

-- Plays `seconds` of frames at 60 a second, each moving the clock on and running every OnUpdate (Core's motion driver).
local function play(loaded, seconds)
	for _ = 1, math.ceil(seconds * 60 - 1e-9) do
		loaded.client.nextFrame(1 / 60)
	end
end

-- Core loaded over `log` and `saved` (a new Angler's first login by default) and logged in, its login frames run.
local function login(log, saved)
	local loaded = loadCore(log or { BUILD_ENTRY }, saved)
	enterWorld(loaded, 3)
	return loaded
end

-- A new Angler's login, past the Letter's 4 s (ONB-R10), with Animations off unless `moving`.
local function arrived(log, saved, moving)
	local loaded = loadCore(log or { BUILD_ENTRY }, saved)
	if not moving then
		stillness(loaded)
	end
	enterWorld(loaded, 3)
	loaded.client.advance(4)
	return loaded
end

-- The next login of the same Angler, with what `loaded` saved.
local function nextLogin(loaded)
	return arrived(loaded.env.PagleLog, loaded.env.PagleDB)
end

-- Clicks the Letter's button reading `text`.
local function press(loaded, text)
	local frame = assert(letterOf(loaded))
	for _, button in ipairs({ frame.open, frame.later }) do
		if button.label.text == text then
			button:Click()
			return
		end
	end
	error("no " .. text .. " on the Letter")
end

describe("when the Letter shows (ONB-R10)", function()
	it("shows a new Angler's Letter 4 s after PLAYER_ENTERING_WORLD, not before (ONB-R10, Tunables)", function()
		local loaded = login()

		loaded.client.advance(3.9)
		assert.is_false(shows(loaded))
		loaded.client.advance(0.1)

		assert.is_true(shows(loaded))
	end)

	it("never shows a returning Angler's (ONB-R2)", function()
		local loaded = arrived(history(2))

		assert.is_false(shows(loaded))
	end)

	it("waits for the login's card to be closed (ONB-R10, ANN-R21)", function()
		local loaded = login({ BUILD_ENTRY }, {
			global = {
				cards = {
					{
						title = "Fishing session",
						numbers = { casts = 1, catches = 1, gotAway = 0, seconds = 60 },
						coins = 0,
						lines = {},
						moments = {},
					},
				},
			},
		})
		stillness(loaded)
		assert.is_true(loaded.env.PagleCard:IsShown())
		loaded.client.advance(4)
		assert.is_false(shows(loaded))

		loaded.client.pressEscape()

		assert.is_true(shows(loaded))
	end)

	it("never shows in an instance, and shows as the player comes out of it (ONB-R10)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.client.instanceType = "party"
		enterWorld(loaded, 3)
		loaded.client.advance(4)
		assert.is_false(shows(loaded))

		loaded.client.instanceType = nil
		loaded.client.fire("PLAYER_ENTERING_WORLD", false, false)
		loaded.client.advance(4)

		assert.is_true(shows(loaded))
	end)

	it("checks again on ZONE_CHANGED_NEW_AREA (ONB-R10)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.client.instanceType = "scenario"
		enterWorld(loaded, 3)
		loaded.client.advance(4)
		loaded.client.instanceType = nil

		loaded.client.fire("ZONE_CHANGED_NEW_AREA")

		assert.is_true(shows(loaded))
	end)

	it("never shows in combat: it waits for the combat hold to end (ONB-R10, ANN-R36)", function()
		local loaded = login()
		setCombat(loaded, true)
		loaded.client.advance(4)
		assert.is_false(shows(loaded))

		setCombat(loaded, false)
		assert.is_false(shows(loaded))
		loaded.client.advance(2)

		assert.is_true(shows(loaded))
	end)

	it("waits while a Module's dialog is open, and shows as it closes (ONB-R10, ONB-R100)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.client.addons.Pagle_QoL = { metadata = { ["X-Pagle-API"] = "1" } }
		local M = loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
		loaded.client.fire("PLAYER_LOGIN")
		M:SetDialogOpen(true)
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
		for _ = 1, 3 do
			loaded.client.advance(0)
		end
		loaded.client.advance(4)
		assert.is_false(shows(loaded))

		M:SetDialogOpen(false)

		assert.is_true(shows(loaded))
	end)
end)

describe("the Letter's frame (ONB-R11)", function()
	it("sits in the toast column's place, centred, with the kit's copy and two buttons (ONB-R11)", function()
		local loaded = arrived()
		local frame = letterOf(loaded)

		assert.are.equal(loaded.env.UIParent, frame.parent)
		assert.are.same({ { "BOTTOM", loaded.env.UIParent, "BOTTOM", 0, 156 } }, frame.points)
		assert.are.same({ 534, 132 }, { frame.width, frame.height })
		assert.are.equal("DIALOG", frame:GetFrameStrata())
		assert.are.same({
			"A letter, left on the dock",
			"Pagle has arrived. Open it whenever you’re ready; it’ll keep.",
		}, { frame.kicker.text, frame.line.text })
		assert.are.same({ "Open the letter", "Later" }, { frame.open.label.text, frame.later.label.text })
	end)

	it(
		"sits at the Toast column's foot wherever the Angler moved it, as the column's clamp has it (ONB-R11, ANN-R98)",
		function()
			local loaded = login()
			stillness(loaded)
			loaded.ns.db.profile.announcements.point = { x = 200, y = 500 }
			loaded.client.advance(4)

			assert.are.same({ "BOTTOM", loaded.env.UIParent, "BOTTOM", 200, 500 }, letterOf(loaded).points[1])
		end
	)

	it(
		"keeps to that foot as it rises, and takes the nearest foot a full column fits if the screen can't hold the saved one (ONB-R11, ANN-R98)",
		function()
			local loaded = login()
			loaded.ns.db.profile.announcements.point = { x = 5000, y = 5000 }
			loaded.client.advance(4)
			local frame = letterOf(loaded)
			local screen = loaded.env.UIParent

			assert.are.same({ "BOTTOM", screen, "BOTTOM", 629, 758 - 30 }, frame.points[1])
			play(loaded, 0.6)

			assert.are.same({ "BOTTOM", screen, "BOTTOM", 629, 758 }, frame.points[1])
			assert.are.same({ x = 5000, y = 5000 }, loaded.ns.db.profile.announcements.point)
		end
	)

	it("is no Announcement: it counts no interruption and Esc doesn't close it (ONB-R11, ANN-R30)", function()
		local loaded = arrived()

		loaded.client.pressEscape()

		assert.is_true(shows(loaded))
		assert.is_falsy(table.concat(loaded.env.UISpecialFrames, " "):find("PagleLetter", 1, true))
		assert.is_true(loaded.ns.lanes:IsEmpty())
	end)

	it("rises 30 units and fades in over 0.5 s with its seal dropping from 1.6x, playing letter (Motion)", function()
		local loaded = login()
		loaded.client.sounds = {}
		loaded.client.advance(4)
		local frame = letterOf(loaded)
		assert.are.equal(0, frame.alpha)
		assert.are.same({ "BOTTOM", loaded.env.UIParent, "BOTTOM", 0, 126 }, frame.points[1])
		assert.are.same({ 1.6, 0 }, { frame.seal:GetScale(), frame.seal.alpha })

		play(loaded, 0.6)

		assert.are.equal(1, frame.alpha)
		assert.are.same({ "BOTTOM", loaded.env.UIParent, "BOTTOM", 0, 156 }, frame.points[1])
		assert.are.same({ 1, 1 }, { frame.seal:GetScale(), frame.seal.alpha })
		assert.are.same({ SOUND_LETTER }, loaded.client.sounds)
	end)

	it("appears settled with Animations off, still with its sound (Motion, Sounds)", function()
		local loaded = login()
		stillness(loaded)
		loaded.client.sounds = {}
		loaded.client.advance(4)
		local frame = letterOf(loaded)

		assert.are.equal(1, frame.alpha)
		assert.are.same({ "BOTTOM", loaded.env.UIParent, "BOTTOM", 0, 156 }, frame.points[1])
		assert.are.equal(1, frame.seal:GetScale())
		assert.are.same({ SOUND_LETTER }, loaded.client.sounds)
	end)

	it("arrives silently in Cozy mode, and still shows (ONB-R11, Sounds)", function()
		local loaded = login()
		loaded.ns.db.profile.announcements.cozy = true
		loaded.client.sounds = {}
		loaded.client.advance(4)

		assert.is_true(shows(loaded))
		assert.are.same({}, loaded.client.sounds)
	end)
end)

describe("the Letter's buttons (ONB-R12)", function()
	it("Later, reload, Later, reload: shown twice, then never (ONB-R12)", function()
		local first = arrived()
		assert.is_true(shows(first))
		press(first, "Later")
		assert.is_false(shows(first))
		assert.are.equal("later", state(first).letter)

		local second = nextLogin(first)
		assert.is_true(shows(second))
		press(second, "Later")
		assert.are.equal("declined", state(second).letter)

		local third = nextLogin(second)
		assert.is_false(shows(third))
	end)

	it("Open the letter opens the guide at its first step, and it never shows again (ONB-R12, ONB-R20)", function()
		local loaded = arrived()

		press(loaded, "Open the letter")

		assert.is_false(shows(loaded))
		assert.are.equal("opened", state(loaded).letter)
		assert.is_true(loaded.ns.guide:IsOpen())
		assert.are.equal("welcome", loaded.ns.guide:Current().step.id)
		assert.is_false(shows(nextLogin(loaded)))
	end)
end)

describe("the menu tooltip while the Letter shows (ONB-R13, CORE-R55)", function()
	-- The tooltip's lines with the mouse over the compartment entry, then over the minimap icon.
	local function tooltips(loaded)
		local row = loaded.client.hoverCompartment("Pagle")
		local compartment = loaded.client.tooltipLines()
		loaded.client.leaveCompartment("Pagle", row)
		local button = loaded.env.PagleMinimapButton
		button:GetScript("OnEnter")(button)
		local icon = loaded.client.tooltipLines()
		button:GetScript("OnLeave")(button)
		return { compartment, icon }
	end

	it("reads A letter for you on the compartment and the minimap icon while it shows, not after (ONB-R13)", function()
		local loaded = login()
		stillness(loaded)
		assert.are.same({ { "Pagle" }, { "Pagle" } }, tooltips(loaded))
		loaded.client.advance(4)

		assert.are.same({ { "Pagle", "A letter for you" }, { "Pagle", "A letter for you" } }, tooltips(loaded))
		press(loaded, "Later")
		assert.are.same({ { "Pagle" }, { "Pagle" } }, tooltips(loaded))
	end)
end)

describe("the Letter and a restriction (ONB-R14)", function()
	it("hides as combat starts and comes back after it, its state untouched (ONB-R14)", function()
		local loaded = arrived()

		setCombat(loaded, true)
		assert.is_false(shows(loaded))
		assert.is_false(loaded.ns.LetterShows())
		setCombat(loaded, false)
		loaded.client.advance(2)

		assert.is_true(shows(loaded))
		assert.are.equal("waiting", state(loaded).letter)
	end)
end)

describe("/pagle dev onboarding letter and the tour stop (ONB-R83, ONB-R84)", function()
	it("shows the Letter now from /pagle dev onboarding letter (ONB-R83)", function()
		local loaded = login()
		stillness(loaded)
		state(loaded).letter = "declined"
		pagle(loaded, "dev on")

		pagle(loaded, "dev onboarding letter")

		assert.is_true(shows(loaded))
	end)

	it("adds core.onboarding.letter, which shows it as a sample and puts the state back (ONB-R84, CORE-R68)", function()
		local loaded = login()
		stillness(loaded)
		state(loaded).letter = "opened"
		local stop
		for _, listed in ipairs(loaded.ns.tourStops:List(loaded.ns.Modules:Modules(), "core")) do
			if listed.name == "core.onboarding.letter" then
				stop = listed
			end
		end

		stop.show()
		assert.is_true(shows(loaded))
		press(loaded, "Open the letter")
		assert.is_false(loaded.ns.guide:IsOpen())
		stop.show()
		stop.hide()

		assert.is_false(shows(loaded))
		assert.are.equal("opened", state(loaded).letter)
	end)
end)

describe("a Module's letter on the same frame (ONB-R15, ONB-R16, ONB-R17)", function()
	local TEXT = "Sixty: the top of the climb."

	-- A returning Angler's login (no onboarding Letter) with a fixture Ledger that registered its letter `ledger.prestige`
	-- before login, in the world past the delay. Returns the Core, the Module's handle and what its confirm button ran.
	local function withLetter(saved)
		local loaded = loadCore({ BUILD_ENTRY }, saved)
		stillness(loaded)
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		local ran = { confirmed = 0 }
		M:RegisterLetter("ledger.prestige", {
			kicker = "A letter, left on the dock",
			text = TEXT,
			confirm = "Show me",
			later = "Later",
			onConfirm = function()
				ran.confirmed = ran.confirmed + 1
			end,
		})
		enterWorld(loaded, 3)
		return loaded, M, ran
	end

	-- The onboarding Letter answered, so the fixture's letter has the frame to itself.
	local function opened()
		return { global = { onboarding = { letter = "opened" } } }
	end

	it(
		"shows the letter's own words on the Letter's frame, 4 s after the world, once sent (ONB-R15, ONB-R16)",
		function()
			local loaded, M = withLetter(opened())
			loaded.client.advance(4)
			assert.is_false(shows(loaded))

			M:ShowLetter("ledger.prestige")

			assert.is_true(shows(loaded))
			local frame = letterOf(loaded)
			assert.are.same(
				{ "A letter, left on the dock", TEXT, "Show me", "Later" },
				{ frame.kicker.text, frame.line.text, frame.open.label.text, frame.later.label.text }
			)
			assert.are.same({ 534, 132 }, { frame.width, frame.height })
			assert.are.same({ ["ledger.prestige"] = "waiting" }, state(loaded).letters)
		end
	)

	it("sizes its buttons to their words, the second after the first (ONB-R15)", function()
		local loaded, M = withLetter(opened())
		loaded.client.advance(4)

		M:ShowLetter("ledger.prestige")

		local frame = letterOf(loaded)
		assert.are.equal(#"Show me" * 6 + 36, frame.open:GetWidth())
		assert.are.equal(#"Later" * 6 + 36, frame.later:GetWidth())
		assert.are.same(
			{ "TOPLEFT", frame.slip, "TOPLEFT", 34 + frame.open:GetWidth() + 14, -92 },
			frame.later.points[1]
		)
	end)

	it("grows the slip, and moves the buttons down, for a line longer than the kit's two (ONB-R15)", function()
		local loaded, M = withLetter(opened())
		loaded.client.advance(4)
		M:ShowLetter("ledger.prestige")
		local frame = letterOf(loaded)
		-- The client measures the line at five 30-unit lines where the two-line gauge measures its 14.
		frame.line.GetStringHeight = function()
			return 150 + 14
		end

		pagle(loaded, "dev on")
		pagle(loaded, "dev onboarding letter ledger.prestige")
		frame.later:Click()
		pagle(loaded, "dev onboarding letter ledger.prestige")

		assert.are.same({ 534, 132 + 150 }, { frame.width, frame.height })
		assert.are.equal(132 + 150, frame.slip.height)
		assert.are.same({ "TOPLEFT", frame.slip, "TOPLEFT", 34, -(92 + 150) }, frame.open.points[1])
		assert.are.equal(25 + 75, frame.sealY)
	end)

	it("says A letter for you on the menu while it shows, as for the onboarding Letter (ONB-R13)", function()
		local loaded, M = withLetter(opened())
		loaded.client.advance(4)
		M:ShowLetter("ledger.prestige")

		assert.is_true(loaded.ns.LetterShows())
		press(loaded, "Later")

		assert.is_false(loaded.ns.LetterShows())
	end)

	it("Later, then Later at the next login, declines it: shown twice, never a third time (ONB-R16)", function()
		local first, M = withLetter(opened())
		first.client.advance(4)
		M:ShowLetter("ledger.prestige")
		press(first, "Later")
		assert.are.equal("later", state(first).letters["ledger.prestige"])

		local second, again = withLetter(first.env.PagleDB)
		second.client.advance(4)
		assert.is_true(again:ShowLetter("ledger.prestige"))
		assert.is_true(shows(second))
		press(second, "Later")
		assert.are.equal("declined", state(second).letters["ledger.prestige"])

		local third, last = withLetter(second.env.PagleDB)
		third.client.advance(4)
		assert.is_false(last:ShowLetter("ledger.prestige"))
		assert.is_false(shows(third))
	end)

	it("runs the Module's onConfirm from its confirm button, and never shows again once opened (ONB-R16)", function()
		local loaded, M, ran = withLetter(opened())
		loaded.client.advance(4)
		M:ShowLetter("ledger.prestige")

		press(loaded, "Show me")

		assert.are.equal(1, ran.confirmed)
		assert.is_false(shows(loaded))
		assert.is_false(loaded.ns.guide:IsOpen())
		assert.are.equal("opened", state(loaded).letters["ledger.prestige"])
		assert.is_false(M:ShowLetter("ledger.prestige"))
	end)

	it(
		"keeps the Module's letter off screen until the onboarding Letter is answered, and its guide closed (ONB-R17)",
		function()
			local loaded, M = withLetter()
			loaded.client.advance(4)
			M:ShowLetter("ledger.prestige")
			local frame = letterOf(loaded)
			assert.are.equal("Open the letter", frame.open.label.text)

			press(loaded, "Open the letter")
			loaded.client.advance(4)
			assert.is_true(loaded.ns.guide:IsOpen())
			assert.is_false(shows(loaded))

			loaded.ns.guide:Close()

			assert.is_true(shows(loaded))
			assert.are.equal("Show me", frame.open.label.text)
		end
	)

	it("hides as combat starts and comes back after it, its state untouched (ONB-R14)", function()
		local loaded, M = withLetter(opened())
		loaded.client.advance(4)
		M:ShowLetter("ledger.prestige")

		setCombat(loaded, true)
		assert.is_false(shows(loaded))
		setCombat(loaded, false)
		loaded.client.advance(2)

		assert.is_true(shows(loaded))
		assert.are.equal("waiting", state(loaded).letters["ledger.prestige"])
	end)

	it(
		"raises an error at the call for a letter the Module hasn't registered, or one that's malformed (ONB-R90's sense)",
		function()
			local loaded, M = withLetter(opened())
			local other = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })

			local okSend, sendProblem = pcall(function()
				M:ShowLetter("ledger.nothing")
			end)
			local okOwner, ownerProblem = pcall(function()
				other:ShowLetter("ledger.prestige")
			end)
			local okRegister, registerProblem = pcall(function()
				M:RegisterLetter("ledger.broken", { kicker = "k" })
			end)

			assert.is_false(okSend)
			assert.matches("ShowLetter: Ledger hasn't registered a letter ledger%.nothing", tostring(sendProblem))
			assert.is_false(okOwner)
			assert.matches("ShowLetter: Hunts hasn't registered a letter ledger%.prestige", tostring(ownerProblem))
			assert.is_false(okRegister)
			assert.matches("letter ledger%.broken needs a text", tostring(registerProblem))
		end
	)

	it(
		"shows from /pagle dev onboarding letter <id>, an unknown id printing the letters there are (ONB-R83)",
		function()
			local loaded, _, ran = withLetter(opened())
			loaded.client.advance(4)
			pagle(loaded, "dev on")

			pagle(loaded, "dev onboarding letter ledger.prestige")
			assert.is_true(shows(loaded))
			assert.are.equal("Show me", letterOf(loaded).open.label.text)
			press(loaded, "Show me")
			assert.are.equal(1, ran.confirmed)
			local before = #loaded.printed
			pagle(loaded, "dev onboarding letter ledger.nothing")

			assert.are.same(
				{ "Pagle dev: no letter ledger.nothing; the letters are core.onboarding, ledger.prestige." },
				{ unpack(loaded.printed, before + 1) }
			)
		end
	)

	it("adds core.onboarding.letter.<id> to the tour, a sample that writes nothing (ONB-R84, CORE-R68)", function()
		local loaded = withLetter(opened())
		loaded.client.advance(4)
		local stop
		for _, listed in ipairs(loaded.ns.tourStops:List(loaded.ns.Modules:Modules(), "core")) do
			if listed.name == "core.onboarding.letter.ledger.prestige" then
				stop = listed
			end
		end

		stop.show()
		assert.is_true(shows(loaded))
		assert.are.equal("Show me", letterOf(loaded).open.label.text)
		press(loaded, "Show me")
		stop.show()
		stop.hide()

		assert.is_false(shows(loaded))
		assert.is_nil(state(loaded).letters)
	end)

	it("forgets Module letters on /pagle dev onboarding reset (ONB-R17, ONB-R83)", function()
		local loaded, M = withLetter(opened())
		loaded.client.advance(4)
		M:ShowLetter("ledger.prestige")
		press(loaded, "Show me")
		pagle(loaded, "dev on")

		pagle(loaded, "dev onboarding reset")

		assert.is_nil(state(loaded).letters)
		assert.are.equal("waiting", state(loaded).letter)
	end)
end)
