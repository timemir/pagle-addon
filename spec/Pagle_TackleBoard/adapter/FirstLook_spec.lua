-- The board's First look and its "?" (ONB-R55–R59, ONB-R90; board 15) on FakePagle's First looks, Core's own wiring
-- (fake.firstLooks, fake.looksShown): what the board registers, when its set shows, where each note points and the
-- "?" beside the close mark.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record = board.record

local W = board.WEEK0
local TODAY = board.DAILY_RESET
local S = TODAY + 60
local FILLER = "n;haul;2;15;30;12"
local EXPEDITION = "e;haul;0;60;150;12"
local ID = "tackleboard.board"

-- A board started today with an Expedition and three Notices.
local STARTED = {
	board.skill(S - 30),
	record("start", S, TODAY .. ";" .. W),
	record("issue", S + 1, EXPEDITION),
	record("issue", S + 2, FILLER),
	record("issue", S + 3, FILLER),
	record("issue", S + 4, FILLER),
}

-- Pagle_TackleBoard on a fake whose log holds `records`, logged in, its projection built and the login's live step
-- run; the board isn't opened. `prepare` runs on the fake first.
local function loggedIn(records, prepare)
	local fake = board.withHistory(records)
	if prepare then
		prepare(fake)
	end
	local loaded = board.load(fake)
	fake.login()
	fake.enterWorld()
	loaded.client.runTimers()
	return loaded, fake
end

-- Hides `frame` as the client does, running its OnHide (the fake's Hide runs no script).
local function hide(frame)
	frame:Hide()
	local onHide = frame:GetScript("OnHide")
	if onHide then
		onHide(frame)
	end
end

-- The set the board registered.
local function boardSet(fake)
	for _, entry in ipairs(fake.firstLooks:List()) do
		if entry.set.id == ID then
			return entry.set
		end
	end
	return nil
end

-- Each set Core showed: its id and how many notes.
local function shown(fake)
	local list = {}
	for i, look in ipairs(fake.looksShown) do
		list[i] = look.id .. " " .. #look.notes
	end
	return list
end

describe("the board's First look (ONB-R55–R57)", function()
	it("registers tackleboard.board at load, titled the Tackle Board, its window the board once made", function()
		local loaded, fake = loggedIn(STARTED)

		local set = assert(boardSet(fake))
		assert.are.equal("the Tackle Board", set.title)
		assert.is_nil(fake.firstLooks:Window(ID))
		loaded.ns.OpenBoard()
		assert.are.equal(loaded.ns.board.frame, fake.firstLooks:Window(ID))
	end)

	it("has the canvas's five notes, verbatim, each key term in the red pencil (ONB-R57)", function()
		local _, fake = loggedIn(STARTED)

		local texts = {}
		for i, note in ipairs(boardSet(fake).notes) do
			texts[i] = note.text
		end
		assert.are.same({
			"|cff9a2a1aExpeditions|r are the bigger weekly ones. They wait too, up to two.",
			"A Notice |cff9a2a1anever expires|r. Don’t fancy it? Take it down, once, for another.",
			"Your |cff9a2a1aCampfire|r: days in a row with one done. A missed day burns Kindling instead.",
			"Each one done ties a fly for your |cff9a2a1aFly Box|r.",
			"They pay |cff9a2a1aPagle Coins|r, spent on looks in the Curio Shop.",
		}, texts)
	end)

	it(
		"points each note at its part of the board: the Expedition, a Notice's take-down, the Campfire, the Fly Box "
			.. "and the shop card",
		function()
			local loaded, fake = loggedIn(STARTED)
			local notes = boardSet(fake).notes
			assert.is_nil(notes[1].target())
			loaded.ns.OpenBoard()
			local frame = loaded.ns.board.frame
			local pins, ledge = frame.parts.pins.slots, frame.parts.ledge

			assert.are.equal(pins.expeditions[1].goal.icon, notes[1].target())
			assert.are.equal(pins.notices[1].goal.takeDown, notes[2].target())
			assert.is_not_nil(notes[3].target())
			assert.are.equal(ledge.fire.burning.layers["-base"] or ledge.fire.burning.layers[""], notes[3].target())
			assert.are.equal(ledge.box.title, notes[4].target())
			assert.are.equal(ledge.shop, notes[5].target())
		end
	)

	it("shows its 5 notes the first time a started board opens, and never again (ONB-R55)", function()
		local loaded, fake = loggedIn(STARTED)

		loaded.ns.OpenBoard()
		assert.are.same({ ID .. " 5" }, shown(fake))
		hide(loaded.ns.board.frame)
		assert.is_nil(fake.firstLooks:Showing())
		loaded.ns.OpenBoard()

		assert.are.same({ ID .. " 5" }, shown(fake))
		assert.is_true(fake.global.onboarding.looksSeen[ID])
	end)

	it("waits for a started board: an empty board opens without it, and Start my board shows it", function()
		local loaded, fake = loggedIn({})

		loaded.ns.OpenBoard()
		assert.are.same({}, shown(fake))
		loaded.ns.board.frame.start:Click()

		assert.is_true(loaded.ns.IsStarted())
		assert.are.same({ ID .. " 5" }, shown(fake))
	end)

	it("never shows with Margin notes off", function()
		local loaded, fake = loggedIn(STARTED)
		fake.global.onboarding.notesOn = false

		loaded.ns.OpenBoard()

		assert.are.same({}, shown(fake))
	end)
end)

describe('the board\'s "?" (ONB-R59)', function()
	it("is a brass pin with its mark beside the close mark, shown while a started board shows", function()
		local loaded = loggedIn(STARTED)
		loaded.ns.OpenBoard()
		local frame = loaded.ns.board.frame
		local help = frame.help

		assert.is_true(help:IsShown())
		assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 928, -15 }, help.points[1])
		assert.are.same({ 26, 26 }, { help.width, help.height })
		assert.are.equal(loaded.ns.BOARD_ATLASES.Board.file, help.pin.texture)
		assert.are.equal("?", help.mark:GetText())
	end)

	it("is hidden on the empty board, where the notes have nothing to point at", function()
		local loaded = loggedIn({})
		loaded.ns.OpenBoard()

		assert.is_false(loaded.ns.board.frame.help:IsShown())
	end)

	it('reads "Show the notes for this page again" under the mouse', function()
		local loaded = loggedIn(STARTED)
		loaded.ns.OpenBoard()
		local help = loaded.ns.board.frame.help

		help:GetScript("OnEnter")(help)

		assert.are.same({ "Show the notes for this page again" }, loaded.ns.BoardHoverLines())
		help:GetScript("OnLeave")(help)
		assert.is_nil(loaded.ns.BoardHoverLines())
	end)

	it("shows the set again once seen, and with Margin notes off; pressed again while it shows, hides it", function()
		local loaded, fake = loggedIn(STARTED)
		loaded.ns.OpenBoard()
		hide(loaded.ns.board.frame)
		loaded.ns.OpenBoard()
		fake.global.onboarding.notesOn = false
		local help = loaded.ns.board.frame.help

		help:Click()
		assert.are.same({ ID .. " 5", ID .. " 5" }, shown(fake))
		assert.are.equal(ID, fake.firstLooks:Showing().id)
		help:Click()

		assert.is_nil(fake.firstLooks:Showing())
	end)
end)

describe("the board on a Core without First looks (ONB-R90)", function()
	it('opens with no set and no "?"', function()
		local loaded, fake = loggedIn(STARTED, function(fake)
			fake.ns.ModuleHandle.RegisterFirstLook = nil
		end)

		loaded.ns.OpenBoard()

		assert.is_true(loaded.ns.board:IsShown())
		assert.is_nil(loaded.ns.board.frame.help)
		assert.is_nil(boardSet(fake))
		assert.are.same({}, loaded.client.errors)
	end)
end)
