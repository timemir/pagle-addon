-- Margin notes on the client, through the real TOC and the fake client (core/onboarding.md › Margin notes, › UI,
-- › Motion): Core's first-moment notes beside the catch Nod, a toast's coin and the Session summary card, once per
-- account (ONB-R50, ONB-R52), a moment's firstNote (ONB-R53), the welcome-back and other-character notes on Pagle's
-- menu button (ONB-R2, ONB-R3, ONB-R108), the hold and the lifetime (ONB-R51), M:ShowMarginNote (ONB-R92), the arrow
-- of Lines and its ring (core/onboarding.md › UI), the guide's illustrative arrows, and `/pagle dev onboarding note`
-- (ONB-R83).

local NOTE_IN = "827 SFX"
local CAST = ("%s-%d-0"):format(PLAYER_GUID, SERVER_TIME)

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- PagleDB.global.onboarding as the client holds it.
local function state(loaded)
	return loaded.env.PagleDB.global.onboarding
end

-- The notes on screen now, as their frames show them: each one's id.
local function onScreen(loaded)
	local ids = {}
	for _, frame in ipairs(loaded.ns.marginNoteFrames) do
		if frame.note and frame.shown then
			ids[#ids + 1] = frame.note.id
		end
	end
	return ids
end

-- The frame showing note `id`, or nil.
local function noteFrame(loaded, id)
	for _, frame in ipairs(loaded.ns.marginNoteFrames) do
		if frame.note and frame.note.id == id then
			return frame
		end
	end
	return nil
end

-- What note `id` points at now.
local function targetOf(loaded, id)
	local note = assert(noteFrame(loaded, id), "no note " .. id).note
	return type(note.target) == "function" and note.target() or note.target
end

-- Core logged in for a new Angler (no Cast in the log) with `saved` PagleDB, Animations off so each note settles at
-- once, and Oily Blackmouth's name cached.
local function newAngler(saved)
	local loaded = loadCore({ BUILD_ENTRY }, saved)
	loaded.ns.db.profile.announcements.motion = false
	loaded.client.itemNames[6358] = "Oily Blackmouth"
	enterWorld(loaded, 3)
	return loaded
end

-- Registers the Ledger, as its OnInitialize would before PLAYER_LOGIN.
local function ledger(loaded)
	return loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
end

describe("the first catch Nod's note (ONB-R52)", function()
	it("shows core.nod beside the first catch Nod, playing noteIn, once (ONB-R50, ONB-R52)", function()
		local loaded = newAngler()

		catchAndFlush(loaded)

		assert.are.same({ "core.nod" }, onScreen(loaded))
		assert.are.equal(loaded.ns.announcementFrames.nod, targetOf(loaded, "core.nod"))
		assert.are.equal(
			"That’s a |cff9a2a1aNod|r: one quiet line for every Catch. It’s gone in three seconds, and it’s in your"
				.. " Ledger for good.",
			noteFrame(loaded, "core.nod").text:GetText()
		)
		assert.are.same({ NOTE_IN }, loaded.client.sounds)
		assert.is_true(state(loaded).notesSeen["core.nod"])

		loaded.client.advance(12)
		catchAndFlush(loaded)
		assert.are.same({}, onScreen(loaded))
	end)

	it("never shows again after a /reload, and /pagle guide notes brings it back (ONB-R50, ONB-R80)", function()
		local first = newAngler()
		catchAndFlush(first)

		local again = newAngler({ global = first.env.PagleDB.global })
		catchAndFlush(again)
		assert.are.same({}, onScreen(again))

		again.client.advance(5)
		pagle(again, "guide notes")
		catchAndFlush(again)
		assert.are.same({ "core.nod" }, onScreen(again))
	end)

	it("never shows with Margin notes off (ONB-R50, ONB-R81)", function()
		local loaded = newAngler()
		state(loaded).notesOn = false

		catchAndFlush(loaded)

		assert.are.same({}, onScreen(loaded))
		assert.are.same({}, state(loaded).notesSeen)
	end)

	it("shows core.uncharted, not core.nod, beside an Uncharted Catch's Nod (ONB-R52)", function()
		local loaded = newAngler()
		loaded.client.itemNames[9999] = "Sickly Looking Fish"

		catchOne(
			loaded,
			{ { link = "|cffffffff|Hitem:9999::::::::15:::::::::|h[Sickly Looking Fish]|h|r", quantity = 1 } }
		)
		loaded.client.advance(0)

		assert.are.same({ "core.uncharted" }, onScreen(loaded))
		assert.is_nil(state(loaded).notesSeen["core.nod"])
	end)

	it("leaves with its Nod, and when clicked (ONB-R51)", function()
		local loaded = newAngler()
		catchAndFlush(loaded)
		local frame = noteFrame(loaded, "core.nod") --[[@as table]]
		assert.is_true(frame.mouseEnabled)

		loaded.client.advance(3.3)
		loaded.client.update(0)

		assert.are.same({}, onScreen(loaded))

		pagle(loaded, "guide notes")
		loaded.client.advance(1)
		catchAndFlush(loaded)
		noteFrame(loaded, "core.nod").scripts.OnMouseUp(noteFrame(loaded, "core.nod"), "LeftButton")
		assert.are.same({}, onScreen(loaded))
	end)
end)

describe("a toast's notes (ONB-R52, ONB-R53)", function()
	-- Raises `moment` for one Cast and runs the frame Core shows it on.
	local function raise(loaded, M, moment)
		M:RaiseMoment(moment)
		loaded.client.advance(0)
	end

	local SPECIES = {
		rung = "toast",
		kind = "newSpecies",
		title = "New Species",
		text = "Oily Blackmouth",
		cast = CAST,
		coins = 12,
		firstNote = "A new Species for your Ledger.",
	}

	it(
		"shows core.toast at the first toast's coin, prefixed by its moment's firstNote, on that Module and kind's"
			.. " first showing only (ONB-R52, ONB-R53)",
		function()
			local loaded = loadCore({ BUILD_ENTRY })
			loaded.ns.db.profile.announcements.motion = false
			local M = ledger(loaded)
			enterWorld(loaded, 3)

			raise(loaded, M, SPECIES)

			assert.are.same({ "core.toast" }, onScreen(loaded))
			assert.are.equal(loaded.ns.announcementFrames.toast.coins.coin, targetOf(loaded, "core.toast"))
			assert.are.equal(
				"A new Species for your Ledger. The coin is |cff9a2a1aPagle Coins|r: earned by doing things, never"
					.. " bought, spent on looks in the Curio Shop.",
				noteFrame(loaded, "core.toast").text:GetText()
			)
			assert.is_true(state(loaded).notesSeen["ledger.newSpecies"])

			loaded.client.advance(12)
			raise(loaded, M, SPECIES)
			assert.are.same({}, onScreen(loaded))
		end
	)

	it("shows nothing for a moment held by Cozy mode, and the note at its next first showing (ONB-R52)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.ns.db.profile.announcements.motion = false
		local M = ledger(loaded)
		enterWorld(loaded, 3)
		loaded.ns.db.profile.announcements.cozy = true

		raise(loaded, M, SPECIES)
		assert.are.same({}, onScreen(loaded))
		assert.are.same({}, state(loaded).notesSeen)

		loaded.ns.db.profile.announcements.cozy = false
		raise(loaded, M, SPECIES)
		assert.are.same({ "core.toast" }, onScreen(loaded))
	end)

	it("raises an error at the Module's call for a firstNote that isn't a text (ONB-R93)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		local M = ledger(loaded)
		enterWorld(loaded)

		local ok, err = pcall(function()
			M:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species", firstNote = true })
		end)

		assert.is_false(ok)
		assert.matches("MarginNotes_spec%.lua:%d+: RaiseMoment: a moment's firstNote is a text", tostring(err))
	end)
end)

describe("the Session summary's note (ONB-R52)", function()
	it("shows core.summary beside the first Session summary card", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.ns.db.profile.announcements.motion = false
		local M = ledger(loaded)
		enterWorld(loaded, 3)
		catchOne(loaded)
		M:RaiseMoment({ rung = "nod", kind = "newInZone", title = "New in this zone" })
		loaded.client.advance(300)
		loaded.client.advance(0)

		assert.is_true(loaded.ns.cardFrame.shown)
		assert.are.same({ "core.summary" }, onScreen(loaded))
		assert.are.equal(loaded.ns.cardFrame, targetOf(loaded, "core.summary"))
	end)
end)

describe("Pagle's menu button's notes (ONB-R2, ONB-R3, ONB-R108)", function()
	-- A returning Angler logged in with Animations off.
	local function returning(saved)
		local loaded = loadCore(history(2), saved)
		loaded.ns.db.profile.announcements.motion = false
		enterWorld(loaded, 3)
		return loaded
	end

	it("shows core.welcome on the minimap icon at the first SessionStarted for a returning Angler (ONB-R2)", function()
		local loaded = returning()
		assert.are.same({}, onScreen(loaded))

		catchOne(loaded)

		assert.are.equal("core.welcome", onScreen(loaded)[1])
		assert.are.equal(loaded.env.PagleMinimapButton, targetOf(loaded, "core.welcome"))
		assert.are.equal(
			"Welcome back. |cff9a2a1a/pagle guide|r shows you around, if you want the tour.",
			noteFrame(loaded, "core.welcome").text:GetText()
		)
	end)

	it(
		"points at the compartment's button with the icon hidden, and moves its arrow as the icon shows (ONB-R108)",
		function()
			local loaded = returning({ global = { minimap = { hide = true } } })

			loaded.client.advance(20)

			assert.are.same({ "core.welcome" }, onScreen(loaded))
			assert.are.equal(loaded.env.AddonCompartmentFrame, targetOf(loaded, "core.welcome"))

			local arrow = noteFrame(loaded, "core.welcome").arrow
			local compartment = loaded.env.AddonCompartmentFrame
			compartment.screenLeft, compartment.screenRight, compartment.screenBottom, compartment.screenTop =
				1500, 1520, 1040, 1060
			local note = noteFrame(loaded, "core.welcome") --[[@as table]]
			note.screenLeft, note.screenRight, note.screenBottom, note.screenTop = 1200, 1450, 900, 990
			local icon = loaded.env.PagleMinimapButton
			icon.screenLeft, icon.screenRight, icon.screenBottom, icon.screenTop = 1700, 1731, 900, 931
			loaded.client.update(0)
			local before = arrow.ring.points[1][4]

			loaded.ns.SetMinimapIconShown(true)

			assert.are.equal(icon, targetOf(loaded, "core.welcome"))
			assert.is_true(arrow.ring.points[1][4] > before)
		end
	)

	it("shows core.character on another character while QoL is registered (ONB-R3)", function()
		local saved = { global = { schemaVersion = 2, onboarding = nil } }
		local seeded = { letter = "opened", characters = { ["Player-4618-0A1B2C3D"] = true } }
		saved.global.onboarding = seeded
		local loaded = loadCore({ BUILD_ENTRY }, saved)
		loaded.ns.db.profile.announcements.motion = false
		loaded.client.addons.Pagle_QoL = { metadata = { ["X-Pagle-API"] = "1" } }
		loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })

		enterWorld(loaded)

		assert.are.same({ "core.character" }, onScreen(loaded))
		assert.are.equal(
			"Same Ledger on every character. Only your |cff9a2a1afishing clothes|r are per character.",
			noteFrame(loaded, "core.character").text:GetText()
		)
	end)
end)

describe("a Module's note (ONB-R51, ONB-R92)", function()
	-- QoL registered and logged in, Animations off; returns the load, its handle and a shown target frame.
	local function withQoL()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.ns.db.profile.announcements.motion = false
		loaded.client.addons.Pagle_QoL = { metadata = { ["X-Pagle-API"] = "1" } }
		local M = loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
		enterWorld(loaded)
		return loaded, M, loaded.env.CreateFrame("Button", nil, loaded.env.UIParent)
	end
	local LURE = "Your pole has no lure on. |cff9a2a1aOnly that|r; then you cast."

	it("shows a note raised in combat after it, and leaves after 12 s (ONB-R51)", function()
		local loaded, M, button = withQoL()
		setCombat(loaded, true)

		M:ShowMarginNote({ id = "qol.lure", text = LURE, target = button })
		assert.are.same({}, onScreen(loaded))
		setCombat(loaded, false)

		assert.are.same({ "qol.lure" }, onScreen(loaded))
		loaded.client.advance(11.9)
		assert.are.same({ "qol.lure" }, onScreen(loaded))
		loaded.client.advance(0.1)
		assert.are.same({}, onScreen(loaded))
	end)

	it("drops a note raised in combat whose target hid meanwhile (ONB-R51)", function()
		local loaded, M, button = withQoL()
		setCombat(loaded, true)
		M:ShowMarginNote({ id = "qol.lure", text = LURE, target = button })
		button:Hide()

		setCombat(loaded, false)

		assert.are.same({}, onScreen(loaded))
		assert.is_nil(state(loaded).notesSeen["qol.lure"])
	end)

	it(
		"draws its arrow of 16 Lines, 2 thick in the pencil at 90%, a curve and a two-stroke head, to a red ring at"
			.. " its target (core/onboarding.md › UI)",
		function()
			local loaded, M, button = withQoL()
			button.screenLeft, button.screenRight, button.screenBottom, button.screenTop = 800, 852, 300, 352

			M:ShowMarginNote({ id = "qol.lure", text = LURE, target = button })
			local note = noteFrame(loaded, "qol.lure") --[[@as table]]
			note.screenLeft, note.screenRight, note.screenBottom, note.screenTop = 500, 770, 280, 370
			loaded.client.update(0)

			local arrow = note.arrow
			assert.are.equal(16, #arrow.lines)
			for _, line in ipairs(arrow.lines) do
				assert.are.same({ true, 2, "OVERLAY" }, { line.shown, line.thickness, line.layer })
				assert.are.same({ 0x23 / 255, 0x40 / 255, 0x7a / 255, 0.9 }, line.color)
			end
			-- the curve leaves the note's right edge and ends on the button, where the ring is
			assert.are.same({ "BOTTOMLEFT", loaded.env.UIParent, 770, 340 }, arrow.lines[1].startPoint)
			local finish = arrow.lines[14].endPoint
			assert.is_true(finish[3] >= 800 and finish[3] <= 852 and finish[4] >= 300 and finish[4] <= 352)
			assert.are.same({ finish[3], finish[4] }, { arrow.lines[15].endPoint[3], arrow.lines[15].endPoint[4] })
			assert.are.same({ "CENTER", loaded.env.UIParent, "BOTTOMLEFT", finish[3], finish[4] }, arrow.ring.points[1])
			assert.is_true(arrow.ring.shown)
		end
	)

	it(
		"fades in, then draws its arrow on and pops its ring, as MOTION.md has it (core/onboarding.md › Motion)",
		function()
			local loaded, M, button = withQoL()
			loaded.ns.db.profile.announcements.motion = true
			button.screenLeft, button.screenRight, button.screenBottom, button.screenTop = 800, 852, 300, 352

			M:ShowMarginNote({ id = "qol.lure", text = LURE, target = button })
			local note = noteFrame(loaded, "qol.lure") --[[@as table]]
			note.screenLeft, note.screenRight, note.screenBottom, note.screenTop = 500, 770, 280, 370
			loaded.client.update(0)
			local arrow = note.arrow
			local start = { note.alpha, arrow.lines[1].shown, arrow.ring.shown }
			loaded.client.update(0.3)
			local drawing = { note.alpha, arrow.lines[1].shown, arrow.lines[14].shown, arrow.ring.shown }
			loaded.client.update(0.5)

			assert.are.same({ 0, false, false }, start)
			assert.are.same({ 1, true, false, false }, drawing)
			assert.are.same({ 1, true, true }, { note.alpha, arrow.lines[16].shown, arrow.ring.shown })
		end
	)
end)

describe("the Field guide's illustrative notes", function()
	it("draw their arrow to their target through ns.DrawNoteArrow (core/onboarding.md › UI)", function()
		local loaded = newAngler()
		local page = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		local target = loaded.env.CreateFrame("Frame", nil, page)

		local note = loaded.ns.NewGuideNote(page, "Click a *name* to open it.", 30, 300, 230, target, 1)

		assert.is_table(note.arrow)
		assert.are.equal(16, #note.arrow.lines)
	end)
end)

describe("/pagle dev onboarding note <id> (ONB-R83)", function()
	it("shows a Core note on its target if it shows, marking nothing, and names the notes it knows", function()
		local loaded = newAngler()
		pagle(loaded, "dev on")

		pagle(loaded, "dev onboarding note core.welcome")
		pagle(loaded, "dev onboarding note core.nod")
		pagle(loaded, "dev onboarding note nothing")

		assert.are.same({ "core.welcome" }, onScreen(loaded))
		assert.is_nil(state(loaded).notesSeen["core.welcome"])
		assert.are.same({
			"Pagle dev: dev commands are on.",
			"Pagle dev: margin note core.nod has nothing on screen to point at now.",
			"Pagle dev: no margin note nothing; the notes are core.character, core.nod, core.summary, core.toast,"
				.. " core.uncharted, core.welcome.",
		}, loaded.printed)
	end)
end)
