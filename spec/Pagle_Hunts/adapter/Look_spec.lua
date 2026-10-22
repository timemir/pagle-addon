-- Hunts' onboarding (core/onboarding.md; #333) on FakePagle's First looks and First evening list, Core's own wiring
-- (fake.firstLooks, fake.looksShown, fake.onboarding): the Hunts board's First look, its five notes and where each
-- points (ONB-R55–R58, ONB-R109), its "?" in the board's wax beside the close (ONB-R59), the `hunts` item (ONB-R61),
-- Hunts' line on What's in the box (ONB-R91), and a Core without them (ONB-R90).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local ID = "hunts.board"

-- Hides `frame` as the client does, running its OnHide (the fake's Hide runs no script).
local function hide(frame)
	frame:Hide()
	local onHide = frame:GetScript("OnHide")
	if onHide then
		onHide(frame)
	end
end

-- The set Hunts registered.
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

-- Each note's target now.
local function targets(fake)
	local found = {}
	for i, note in ipairs(boardSet(fake).notes) do
		found[i] = note.target() or false
	end
	return found
end

-- The Board spread's left page's timeline view, and its right page's entry view.
local function views(run)
	local board = run.ns.board
	local left = board:Page({ mode = "board" }, "left")
	local right = board:Page({ mode = "board" }, "right") --[[@as EntryPage]]
	return run.ns.TimelinePageView(left), right.entry
end

-- Pagle Wagers on, as adapter/Wagers_spec.lua sets it up: Thursday 15 October 2026 11:00 UTC on a realm two hours
-- ahead, the rotation's slot 0 (fixture_shore, Darkshore) on until Saturday 15:00 UTC with one Catch an hour in, so
-- the wager strip shows above the ruler and the WAGERS group above Now (HNT-R161).
local THU_11 = SERVER_TIME + 3 * DAY + 19 * HOUR + 45 * 60
local SAT_15 = THU_11 + 2 * DAY + 4 * HOUR
local ORIGIN = SAT_15 - 3 * DAY
local function wagersOn()
	local cast = hunts.cast(0, hunts.NIGHT, { zone = C.DARKSHORE }, { C.NIGHTFIN })
	cast.time = ORIGIN + HOUR
	local run = hunts.start({
		from = THU_11 - SERVER_TIME,
		names = true,
		prepare = function(loaded)
			loaded.ns.ROTATION_ORIGIN = ORIGIN
		end,
		history = function(fake)
			hunts.append(fake, {
				hunts.record("run", hunts.runPayload("fixture_shore", ORIGIN, SAT_15), ORIGIN),
				cast,
			})
		end,
		beforeGrouping = function(r)
			hunts.setConditions(r.fake, {
				time = THU_11,
				minute = 13 * 60,
				date = { year = 2026, month = 10, day = 15, weekday = 5 },
			})
		end,
	})
	run.fake.nextFrame()
	run.loaded.client.runTimers()
	return run
end

describe("the Hunts board's First look (ONB-R55–R57)", function()
	it(
		"registers hunts.board at load, titled Hunts, its window the board once made, its tour opening the Board",
		function()
			local run = hunts.start()
			local set = assert(boardSet(run.fake))

			assert.are.equal("Hunts", set.title)
			assert.is_nil(run.fake.firstLooks:Window(ID))
			run.ns.board:Open({ mode = "set", set = "fixture_dusk" })
			hide(run.ns.board.frame)
			set.open()

			assert.are.equal(run.ns.board.frame, run.fake.firstLooks:Window(ID))
			assert.is_true(run.ns.board:IsShown())
			assert.are.equal("board", run.ns.board.router:Place().mode)
		end
	)

	it("has the canvas's five notes, verbatim, each *term* for Core's red pencil (ONB-R57, board 13)", function()
		local run = hunts.start()

		local texts = {}
		for i, note in ipairs(boardSet(run.fake).notes) do
			texts[i] = note.text
		end
		assert.are.same({
			"*Now*, *Soon* and *Later*: what’s open, what opens within three hours, and the rest.",
			"The red line is *now*, in realm time. Hatched bars are when each Hunt is open.",
			"*Natural* means the game itself keeps this fish to its hours. Imposed Hunts are Pagle’s own rules.",
			"*Pin* a Hunt to keep it on your tracker while you fish.",
			"Each ribbon is a *Hunt set*. Finish every Hunt in one and its title is yours. *Pagle Wagers* holds the "
				.. "wagers on the table now.",
		}, texts)
	end)

	it("names Pagle Wagers in its fifth note as the ribbon it points at reads (ONB-R57, HNT-R162)", function()
		local run = hunts.start()
		run.ns.ToggleBoard()

		local ribbon = run.ns.BoardWagersRibbon()
		local fifth = boardSet(run.fake).notes[5].text
		assert.is_truthy(fifth:find("*" .. ribbon.label:GetText() .. "*", 1, true))
	end)

	it("sits in the board's margins: three on the left, two on the right (ONB-R58)", function()
		local run = hunts.start()
		local width = 920

		for i, note in ipairs(boardSet(run.fake).notes) do
			local left = note.x + note.w <= 0
			local right = note.x >= width
			assert.is_true(left or right)
			assert.are.equal(i == 3 or i == 4, right, "note " .. i)
		end
	end)

	it(
		"points each note at its part of the Board spread: the Now heading, the now line, the entry's Natural, its "
			.. "pin and the Pagle Wagers ribbon (ONB-R109 resolved)",
		function()
			local run = hunts.start({ names = true })
			assert.are.same({ false, false, false, false, false }, targets(run.fake))
			run.ns.ToggleBoard()
			local timeline, entry = views(run)
			local found = targets(run.fake)

			assert.are.equal(timeline.headings.now.label, found[1])
			assert.are.equal(timeline.nowLine, found[2])
			-- the kicker's words "{set} · Natural", hugged so the arrow lands on Natural at their end
			assert.are.same({ "TOPLEFT", entry.kicker, "TOPLEFT", 0, 0 }, found[3].points[1])
			assert.are.equal(entry.kicker:GetStringWidth(), found[3].width)
			assert.are.equal(entry.pin, found[4])
			assert.are.equal(run.ns.BoardWagersRibbon(), found[5])
			assert.is_true(found[5].wagers)
		end
	)

	it("points the first note at the next heading of Soon and Later when nothing is in Now", function()
		local run = hunts.start({ names = true })
		run.ns.ToggleBoard()
		local timeline = views(run)
		timeline.headings.now:Hide()

		assert.are.equal(timeline.headings.later.label, targets(run.fake)[1])
	end)

	it("keeps its notes on the Now heading and the now line when the wager strip pushes the ruler down", function()
		local run = wagersOn()
		run.ns.ToggleBoard()
		local timeline = views(run)
		local found = targets(run.fake)

		assert.is_true(timeline.headings.wagers:IsShown())
		assert.are.equal(timeline.headings.now.label, found[1])
		assert.are.equal(timeline.nowLine, found[2])
		assert.are.same({ ID .. " 5" }, shown(run.fake))
	end)

	it(
		"points the first note at the next heading in view when Now's is scrolled out, and drops it with none",
		function()
			local run = hunts.start({ names = true })
			run.ns.ToggleBoard()
			local timeline = views(run)

			timeline.scroll:SetVerticalScroll(timeline.headings.now.y + 20)
			assert.are.equal(timeline.headings.later.label, targets(run.fake)[1])
			timeline.scroll:SetVerticalScroll(timeline.headings.later.y + 20)
			assert.is_false(targets(run.fake)[1])
		end
	)

	it("shows its 5 notes the first time the board opens, and never again (ONB-R55)", function()
		local run = hunts.start({ names = true })

		run.ns.ToggleBoard()
		assert.are.same({ ID .. " 5" }, shown(run.fake))
		hide(run.ns.board.frame)
		assert.is_nil(run.fake.firstLooks:Showing())
		run.ns.ToggleBoard()

		assert.are.same({ ID .. " 5" }, shown(run.fake))
		assert.is_true(run.fake.global.onboarding.looksSeen[ID])
	end)

	it(
		"waits for the Board spread: opened on a set's page or Pagle Wagers it shows nothing, then on the Board",
		function()
			local run = hunts.start({ names = true })

			run.ns.board:Open({ mode = "set", set = "fixture_dusk" })
			assert.are.same({ false, false, false, false, false }, targets(run.fake))
			hide(run.ns.board.frame)
			run.ns.board:Open({ mode = "wagers" })
			hide(run.ns.board.frame)
			assert.are.same({}, shown(run.fake))
			run.ns.ToggleBoard()

			assert.are.same({ ID .. " 5" }, shown(run.fake))
		end
	)

	it("waits while no Hunt is out, so the timeline has no Now, Soon or Later to point at", function()
		local run = hunts.start({
			names = true,
			list = function(fixture)
				local list = hunts.deepCopy(fixture)
				for _, hunt in ipairs(list.hunts) do
					hunt.since = hunts.NOV_4
				end
				return list
			end,
		})

		run.ns.ToggleBoard()

		assert.are.same({}, shown(run.fake))
		assert.is_nil(run.fake.global.onboarding.looksSeen[ID])
	end)

	it("never shows with Margin notes off", function()
		local run = hunts.start({ names = true })
		run.fake.global.onboarding.notesOn = false

		run.ns.ToggleBoard()

		assert.are.same({}, shown(run.fake))
	end)
end)

describe('the Hunts board\'s "?" (ONB-R59)', function()
	it("is a seal of the board's wax with a gilt ? beside the close, the close's size", function()
		local run = hunts.start()
		run.ns.ToggleBoard()
		local frame = run.ns.board.frame
		local help = frame.help

		assert.is_true(help:IsShown())
		assert.are.same({ "RIGHT", frame.close, "LEFT", -4, 0 }, help.points[1])
		assert.are.same({ 26, 26 }, { help.width, help.height })
		assert.are.equal(frame.close.normal.texture, help.wax.texture)
		assert.are.equal("?", help.label:GetText())
	end)

	it('reads "Show the notes for this page again" under the mouse', function()
		local run = hunts.start()
		run.ns.ToggleBoard()
		local help = run.ns.board.frame.help

		help:GetScript("OnEnter")(help)

		assert.are.same({ "Show the notes for this page again" }, run.loaded.client.tooltipLines())
	end)

	it("shows the set again once seen, and with Margin notes off; pressed again while it shows, hides it", function()
		local run = hunts.start({ names = true })
		run.ns.ToggleBoard()
		hide(run.ns.board.frame)
		run.ns.ToggleBoard()
		run.fake.global.onboarding.notesOn = false
		local help = run.ns.board.frame.help

		help:Click()
		assert.are.same({ ID .. " 5", ID .. " 5" }, shown(run.fake))
		assert.are.equal(ID, run.fake.firstLooks:Showing().id)
		help:Click()

		assert.is_nil(run.fake.firstLooks:Showing())
	end)

	it("turns to the Board spread first when pressed on another", function()
		local run = hunts.start({ names = true })
		run.fake.global.onboarding.looksSeen = { [ID] = true }
		run.ns.board:Open({ mode = "set", set = "fixture_dusk" })

		run.ns.board.frame.help:Click()

		assert.are.equal("board", run.ns.board.router:Place().mode)
		assert.are.same({ ID .. " 5" }, shown(run.fake))
	end)
end)

describe("the First evening list's hunts item (ONB-R61)", function()
	it("is ticked as the board opens, on any spread", function()
		local run = hunts.start()
		assert.is_false(run.fake.onboarding:IsEveningItemDone("hunts"))

		run.ns.board:Open({ mode = "wagers" })

		assert.is_true(run.fake.onboarding:IsEveningItemDone("hunts"))
	end)
end)

describe("Hunts' line on What's in the box (ONB-R91)", function()
	it("is def.guideBlurb, with no guide step", function()
		local run = hunts.start()

		assert.are.equal(
			"Fish that only bite at night, in winter or at the fair, and which of them bite right now.",
			run.fake.registry:Modules()[1].def.guideBlurb
		)
		assert.is_nil(run.fake.guideSteps:FirstOf("Hunts"))
	end)
end)

describe("the Hunts board on a Core without onboarding (ONB-R90)", function()
	it('opens with no set, no "?" and no item, and no error', function()
		local fake = newFakePagle()
		local handle = fake.ns.ModuleHandle
		handle.RegisterFirstLook, handle.ShowFirstLook, handle.CompleteEveningItem = nil, nil, nil
		local run = hunts.start({ fake = fake, names = true })

		run.ns.ToggleBoard()

		assert.is_true(run.ns.board:IsShown())
		assert.is_false(run.ns.board.frame.help:IsShown())
		assert.is_nil(boardSet(fake))
		assert.are.same({}, shown(fake))
		assert.are.same({}, run.loaded.client.errors)
	end)
end)
