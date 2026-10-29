-- The pins and the overflow strip on the board (TKB-R44, TKB-R55, TKB-R101, TKB-R102, TKB-R104, TKB-R105, TKB-R108,
-- TKB-R109, TKB-R121) on FakePagle over the fixture catalogue: a started board's log (its Module records appended with
-- fake.catchLog:Append, as the live step will append them), then login and the first PLAYER_ENTERING_WORLD, then the
-- board opened. What the logic decides is in logic/Pins_spec; this checks what the board draws, when it redraws and
-- what its buttons and hovers do.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, idAt = board.record, board.idAt

local W = board.WEEK0 -- Tuesday 6 October 2026 15:00 UTC: week 0's weekly reset
local D0 = board.DAY0 -- Wednesday 7 October 15:00 UTC: board day 0
local DUROTAR, DARKSHORE = 14, 148
local MACKEREL, BLACKMOUTH, MIGHTFISH, REMOVED_FISH = 6303, 6358, 13754, 92003

-- Goal payloads (tackle-board.md › Data).
local HAUL_HERE = "n;haul;2;15;30;148" -- 30 Catches in Darkshore, the fake's zone
local RARITY = "n;rarity;1;10;3;2"
local COLLECTOR = "n;collector;2;15;2;" -- day-bound: 2 on one board day
local LURE = "n;lure;3;20;25;"
local STRANDED = "n;species;2;15;10;" .. REMOVED_FISH
local EXPEDITION = "e;rarity;0;60;8;3"
local VARIETY = "e;variety;0;60;3;148:" .. MACKEREL .. "," .. BLACKMOUTH .. "," .. MIGHTFISH

-- Each goal record's time: the start is at T, its goals one second apart after it.
local T = D0 + 3600

-- A started board's log: the start record, then an `issue` record for each payload, one second apart.
local function startedLog(...)
	local records = { record("start", T, D0 .. ";" .. W) }
	for i, payload in ipairs({ ... }) do
		records[#records + 1] = record("issue", T + i, payload)
	end
	return records
end

-- Pagle_TackleBoard on a fake whose log holds `records`, its client knowing the fixture's names, logged in, its
-- projection built, and its board open.
local function opened(records, options)
	return board.opened(records, {
		names = {
			areas = { [DUROTAR] = "Durotar", [DARKSHORE] = "Darkshore" },
			items = {
				[MACKEREL] = "Raw Slitherskin Mackerel",
				[BLACKMOUTH] = "Oily Blackmouth",
				[MIGHTFISH] = "Mightfish",
			},
		},
		load = options,
	})
end

-- The `i`th Notice pin's or Expedition pin's slot.
local function notice(frame, i)
	return frame.parts.pins.slots.notices[i]
end
local function expedition(frame, i)
	return frame.parts.pins.slots.expeditions[i]
end

-- Whether `widget` and every parent up to `top` are shown.
local function visible(widget, top)
	while widget do
		if not widget:IsShown() then
			return false
		end
		if widget == top then
			return true
		end
		widget = widget:GetParent()
	end
	return true
end

-- What a pinned goal's slip reads, line by line, as drawn: each shown line's text.
local function reads(slot)
	local slip = slot.goal
	local lines = {}
	for _, key in ipairs({ "kicker", "text", "progress", "where", "here", "stranded", "pay" }) do
		if slip[key]:IsShown() then
			lines[#lines + 1] = slip[key]:GetText()
		end
	end
	return lines
end

-- A copy of the fake's conditions in another zone, for fake.setConditions.
local function inZone(fake, zone)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	conditions.zone, conditions.subzone = zone, 0
	return conditions
end

-- Hovers `widget`, as the mouse going over it does.
local function hover(widget)
	widget:GetScript("OnEnter")(widget)
end

describe("a started board's pins (TKB-R101, TKB-R102)", function()
	it('shows its Expedition on a poster with the "60" seal and its Notices on papers with their coins', function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, HAUL_HERE, RARITY, LURE))
		local atlas = loaded.ns.BOARD_ATLASES.Board

		local poster = expedition(frame, 1).goal
		assert.is_true(visible(poster, frame))
		assert.are.equal(atlas.file, poster.paper.texture)
		assert.are.equal("60", poster.seal.label:GetText())
		assert.are.same({
			"E X P E D I T I O N   ·   R A R I T Y",
			"8 Catches of a rare variety or better",
			"0 of 8",
			"anywhere",
			"pays 60 Coins",
		}, reads(expedition(frame, 1)))
		assert.are.same({ "HAUL", "30 Catches in Darkshore", "0 of 30", "I'm here", "pays" }, reads(notice(frame, 1)))
		assert.are.same(
			{ "RARITY", "3 Catches of an uncommon variety or better", "0 of 3", "anywhere", "pays" },
			reads(notice(frame, 2))
		)
		assert.are.same({ "LURE", "25 Catches with a lure on", "0 of 25", "anywhere", "pays" }, reads(notice(frame, 3)))
		assert.are.same({ "15", "10", "20" }, {
			notice(frame, 1).goal.coin.label:GetText(),
			notice(frame, 2).goal.coin.label:GetText(),
			notice(frame, 3).goal.coin.label:GetText(),
		})
		assert.is_nil(notice(frame, 1).goal.seal)
		assert.is_false(visible(notice(frame, 1).empty, frame))
	end)

	it("leans each paper on its pin, and straightens it under the mouse (TKB-R102)", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, HAUL_HERE))
		local paper = notice(frame, 1).goal.paper
		paper.SetRotation = function(self, radians)
			self.rotation = radians
		end
		loaded.ns.Redraw("projection")

		assert.are.equal(math.rad(1.6), paper.rotation) -- the first Notice pin leans -1.6°
		hover(notice(frame, 1).goal)
		loaded.client.update(0.2) -- 0.18 s, eased out
		assert.are.equal(0, paper.rotation)
		assert.are.same({ "TOPLEFT", notice(frame, 1), "TOPLEFT", 0, 2 }, notice(frame, 1).goal.points[1]) -- lifted
		notice(frame, 1).goal:GetScript("OnLeave")(notice(frame, 1).goal)
		loaded.client.update(0.2)
		assert.are.equal(math.rad(1.6), paper.rotation)
		assert.are.same({ "TOPLEFT", notice(frame, 1), "TOPLEFT", 0, 0 }, notice(frame, 1).goal.points[1])
	end)

	it("closes up its Notice rows while the overflow strip shows (TKB-R101)", function()
		local _, _, frame = opened(startedLog(EXPEDITION, RARITY, RARITY, RARITY, RARITY, RARITY, RARITY, LURE))

		assert.are.same({ "TOPLEFT", frame.parts.pins, "TOPLEFT", 26, -300 }, notice(frame, 4).points[1])
		assert.are.same({ "TOPLEFT", frame.parts.pins, "TOPLEFT", 26, -8 }, expedition(frame, 1).points[1])
	end)

	it("draws no overflow strip, nor its twine over the bottom row, while every goal has a pin (TKB-R101)", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, RARITY, RARITY, RARITY, RARITY, RARITY, RARITY))

		assert.is_false(frame.parts.overflow:IsShown())
		loaded.ns.Redraw("projection")
		assert.is_false(frame.parts.overflow:IsShown())
	end)

	it("hangs a goal with no empty pin in the overflow strip", function()
		local _, _, frame = opened(startedLog(EXPEDITION, RARITY, RARITY, RARITY, RARITY, RARITY, RARITY, LURE))

		local chips = frame.parts.overflow.chips
		assert.is_true(visible(chips[1], frame))
		assert.are.same(
			{ "25 Catches with a lure on", "0 of 25" },
			{ chips[1].label:GetText(), chips[1].count:GetText() }
		)
		assert.is_false(chips[2] ~= nil and chips[2]:IsShown())
	end)

	it("shows the overflow goal's lines on its hover", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, RARITY, RARITY, RARITY, RARITY, RARITY, RARITY, LURE))

		hover(frame.parts.overflow.chips[1])

		assert.are.same({
			"25 Catches with a lure on",
			"0 of 25",
			"anywhere",
			"pays 20 Coins",
			"Posted Wed 7 Oct, 09:00",
			"Only my Catches since then count",
		}, loaded.ns.BoardHoverLines())
	end)
end)

describe('"I\'m here" (TKB-R121)', function()
	it("stops after a zone change, and comes back on returning", function()
		local _, fake, frame = opened(startedLog(EXPEDITION, HAUL_HERE))
		assert.is_true(notice(frame, 1).goal.here:IsShown())

		fake.setConditions(inZone(fake, DUROTAR))

		assert.is_false(notice(frame, 1).goal.here:IsShown())
		assert.are.equal("Darkshore", notice(frame, 1).goal.where:GetText())
		assert.is_true(notice(frame, 1).goal.where:IsShown())

		fake.setConditions(inZone(fake, DARKSHORE))
		assert.is_true(notice(frame, 1).goal.here:IsShown())
	end)
end)

describe("a day-bound goal's progress (TKB-R104)", function()
	it('reads "1 of 2 today" on its board day and "0 of 2 today" once the live step has moved to the next', function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, COLLECTOR))
		local ns = loaded.ns
		-- ns.CountCatch (logic/Progress.lua) counts the Catch; here its outcome is set: 1, today.
		local state = ns.State()
		local collector = state.goals[idAt(T + 2)]
		collector.progress, collector.progressDay = 1, state.day
		ns.Redraw("projection")

		assert.are.equal("1 of 2 today", notice(frame, 1).goal.progress:GetText())

		-- The live step at the next daily reset (TKB-R13): it advances the projection, then redraws.
		ns.AdvanceTo(state, state.day + 1, "live")
		ns.Redraw("step")

		assert.are.equal("0 of 2 today", notice(frame, 1).goal.progress:GetText())
	end)
end)

describe('"take it down", RE-POSTED and stranded goals (TKB-R44, TKB-R55, TKB-R108)', function()
	-- The board with a re-posted goal and a stranded one, the real ns.CanTakeDown (TKB-R55) and a ns.TakeDown that
	-- records each goal taken down.
	local function withSeams()
		local records = startedLog(EXPEDITION, RARITY, STRANDED)
		records[#records + 1] = record("reroll", T + 10, idAt(T + 2) .. ";" .. LURE)
		local taken = {}
		local loaded, fake, frame = opened(records, {
			prepare = function(l)
				l.ns.TakeDown = function(goalID)
					taken[#taken + 1] = goalID
				end
			end,
		})
		return loaded, fake, frame, taken
	end

	it("stamps a re-posted goal RE-POSTED with no button, on its old goal's pin", function()
		local _, _, frame = withSeams()

		local slip = notice(frame, 1).goal
		assert.are.equal("25 Catches with a lure on", slip.text:GetText())
		assert.is_true(slip.stamp:IsShown())
		assert.are.equal("RE-POSTED", slip.stamp.label:GetText())
		assert.is_false(slip.takeDown:IsShown())
	end)

	it(
		"says on the re-posted goal's hover that it can come down again at the daily reset (in 23h) (TKB-R55)",
		function()
			local loaded, _, frame = withSeams()

			hover(notice(frame, 1).goal)

			assert.are.same({
				"Posted Wed 7 Oct, 09:00",
				"Only my Catches since then count",
				"Re-posted today. It can be taken down again at the daily reset (in 23h).",
			}, loaded.ns.BoardHoverLines())
		end
	)

	it("takes the stamp off and brings the button back once the day has gone by (TKB-R55)", function()
		local loaded, _, frame, taken = withSeams()
		loaded.ns.AdvanceTo(loaded.ns.State(), 1, "live")
		loaded.ns.Redraw("projection")

		local slip = notice(frame, 1).goal
		assert.is_false(slip.stamp:IsShown())
		assert.is_true(slip.takeDown:IsShown())
		hover(slip)
		assert.are.same({ "Posted Wed 7 Oct, 09:00", "Only my Catches since then count" }, loaded.ns.BoardHoverLines())
		slip.takeDown:Click()
		assert.are.same({ idAt(T + 10) }, taken)
	end)

	it('marks a stranded goal "no longer catchable", and it can be taken down', function()
		local _, _, frame, taken = withSeams()

		local slip = notice(frame, 2).goal
		assert.is_true(slip.stranded:IsShown())
		assert.are.equal("no longer catchable", slip.stranded:GetText())
		assert.is_true(slip.takeDown:IsShown())
		assert.are.equal("take it down", slip.takeDown.label:GetText())
		slip.takeDown:Click()

		assert.are.same({ idAt(T + 3) }, taken)
	end)

	it("calls ns.TakeDown with the goal's ID from an ordinary goal's button", function()
		local _, _, frame, taken = withSeams()

		expedition(frame, 1).goal.takeDown:Click()

		assert.are.same({ idAt(T + 1) }, taken)
		assert.is_false(expedition(frame, 1).goal.stamp:IsShown())
	end)

	it("disables every button while the projection is updating, and takes nothing down", function()
		local loaded, _, frame, taken = withSeams()
		loaded.ns.IsUpdating = function()
			return true
		end
		loaded.ns.Redraw("projection")

		local button = expedition(frame, 1).goal.takeDown
		assert.is_true(button:IsShown())
		assert.is_false(button:IsEnabled())
		button:Click()

		assert.are.same({}, taken)
	end)
end)

describe("the empty pins (TKB-R105)", function()
	it("read the countdown and the weekly reset's realm weekday, with a dashed outline and a lone tack", function()
		local _, _, frame = opened(startedLog(EXPEDITION, RARITY))

		local empty = notice(frame, 2).empty
		assert.is_true(visible(empty, frame))
		assert.is_false(visible(notice(frame, 2).goal, frame))
		assert.is_not_nil(empty.tack)
		assert.is_true(#empty.dashes > 0)
		-- Sunday 15:15 UTC: the daily reset at 15:00 UTC is 23 h 45 min away.
		assert.are.same({ "A fresh Notice at reset", "(in 23h)" }, { empty.label:GetText(), empty.note:GetText() })
		assert.are.equal("(in 23h)", notice(frame, 4).empty.note:GetText())
		assert.are.equal("More Notices at later resets", notice(frame, 5).empty.label:GetText())
		assert.is_false(notice(frame, 5).empty.note:IsShown())
		assert.are.same(
			{ "Next Expedition at the weekly reset", "(Tue)" },
			{ expedition(frame, 2).empty.label:GetText(), expedition(frame, 2).empty.note:GetText() }
		)
	end)

	it("refresh their countdown every 60 s while the board is open", function()
		local loaded, fake, frame = opened(startedLog(EXPEDITION, RARITY))

		fake.wait(3600)
		assert.are.equal("(in 23h)", notice(frame, 2).empty.note:GetText())
		loaded.client.advance(60)

		assert.are.equal("(in 22h)", notice(frame, 2).empty.note:GetText())
	end)
end)

describe("the empty pins with a Refresh held (TKB-R58, TKB-R105)", function()
	-- A board started today (its day 0 is the day the fake's clock is in, so nothing is owed or to be issued but what
	-- the log holds): the Expedition on pin 1 and Notices on pins 1-3, the Angler's skill read. Notice pins 4-6 and
	-- Expedition pin 2 are empty. The board is open after the login's live step.
	local TODAY = board.DAILY_RESET
	local TODAY_LOG = {
		board.skill(TODAY + 30),
		record("start", TODAY + 60, TODAY .. ";" .. W),
		record("issue", TODAY + 61, EXPEDITION),
		record("issue", TODAY + 62, HAUL_HERE),
		record("issue", TODAY + 63, RARITY),
		record("issue", TODAY + 64, LURE),
	}

	-- The board open on TODAY_LOG; the Angler holds `held` Refreshes when given: Hunts has earned that many, and Core
	-- tells the board (TicketsChanged).
	local function holding(held)
		local loaded, fake, frame = board.opened(TODAY_LOG, {
			names = { areas = { [DUROTAR] = "Durotar", [DARKSHORE] = "Darkshore" } },
			step = true,
		})
		if held then
			fake.setTickets("Hunts", held)
			fake.fire("TicketsChanged", fake.Pagle.GetTickets())
		end
		return loaded, fake, frame
	end

	it("take no mouse while none is held, so the board drags by them, and have no hover", function()
		local loaded, _, frame = holding()

		for _, empty in ipairs({ notice(frame, 4).empty, expedition(frame, 2).empty }) do
			assert.is_false(empty.mouseEnabled)
			hover(empty)
			assert.is_nil(loaded.ns.BoardHoverLines())
		end
	end)

	it("become clickable once one is held, every empty pin of both types and no hung goal's", function()
		local _, _, frame = holding(1)

		for i = 4, 6 do
			assert.is_true(notice(frame, i).empty.mouseEnabled)
		end
		assert.is_true(expedition(frame, 2).empty.mouseEnabled)
		assert.is_false(visible(notice(frame, 1).empty, frame))
		assert.is_false(notice(frame, 1).empty.mouseEnabled)
	end)

	it("say what a click does, what it costs and how many are held, under the mouse", function()
		local loaded, _, frame = holding(3)

		hover(notice(frame, 4).empty)
		local forNotice = loaded.ns.BoardHoverLines()
		hover(expedition(frame, 2).empty)
		local forExpedition = loaded.ns.BoardHoverLines()
		expedition(frame, 2).empty:GetScript("OnLeave")(expedition(frame, 2).empty)

		assert.are.same({
			"Post a Notice now",
			"Click to pin a fresh Notice here instead of waiting for the next reset.",
			"It uses 1 Refresh. You hold 3.",
		}, forNotice)
		assert.are.same({
			"Post an Expedition now",
			"Click to pin a fresh Expedition here instead of waiting for the weekly reset.",
			"It uses 1 Refresh. You hold 3.",
		}, forExpedition)
		assert.is_nil(loaded.ns.BoardHoverLines())
	end)

	it("keep their words and countdown (TKB-R105)", function()
		local _, _, frame = holding(1)

		assert.are.same(
			{ "A fresh Notice at reset", "(in 23h)" },
			{ notice(frame, 4).empty.label:GetText(), notice(frame, 4).empty.note:GetText() }
		)
		assert.are.same(
			{ "Next Expedition at the weekly reset", "(Tue)" },
			{ expedition(frame, 2).empty.label:GetText(), expedition(frame, 2).empty.note:GetText() }
		)
	end)

	it("ask on the confirm when clicked, for the type of the pin, and post nothing until it is answered", function()
		local loaded, _, frame = holding(1)

		notice(frame, 4).empty:Click()
		local confirm = assert(loaded.ns.TakeDownConfirm())
		local forNotice = confirm.title:GetText()
		confirm.keep:Click()
		expedition(frame, 2).empty:Click()

		assert.are.equal("Post a new Notice?", forNotice)
		assert.are.equal("Post a new Expedition?", confirm.title:GetText())
		assert.are.equal(0, loaded.ns.State().ticketsSpent)
	end)

	it("post the goal on the first empty pin when answered, then fall quiet: no Refresh is left", function()
		local loaded, _, frame = holding(1)

		notice(frame, 6).empty:Click() -- whichever empty Notice pin is clicked, the goal takes the first
		loaded.ns.TakeDownConfirm().accept:Click()

		local state = loaded.ns.State()
		assert.are.equal(1, state.ticketsSpent)
		assert.is_not.equal(false, state.pins.notices[4])
		assert.is_true(visible(notice(frame, 4).goal, frame))
		assert.is_false(visible(notice(frame, 4).empty, frame))
		assert.is_true(visible(notice(frame, 5).empty, frame))
		for _, empty in ipairs({ notice(frame, 5).empty, notice(frame, 6).empty, expedition(frame, 2).empty }) do
			assert.is_false(empty.mouseEnabled)
		end
	end)

	it("go quiet again when the projection is updating (TKB-R108)", function()
		local loaded, _, frame = holding(1)
		loaded.ns.IsUpdating = function()
			return true
		end

		loaded.ns.Redraw("projection")
		notice(frame, 4).empty:Click()

		assert.is_false(notice(frame, 4).empty.mouseEnabled)
		assert.is_nil(loaded.ns.TakeDownConfirm())
	end)

	it("follow the count when Core reports a change while the board is open", function()
		local _, fake, frame = holding(1)
		assert.is_true(notice(frame, 4).empty.mouseEnabled)

		fake.setTickets("TackleBoard", nil, 1)
		fake.fire("TicketsChanged", fake.Pagle.GetTickets())

		assert.is_false(notice(frame, 4).empty.mouseEnabled)
	end)
end)

describe("a pinned goal's hover (TKB-R102)", function()
	it("shows its realm posted time and that only Catches since then count", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, HAUL_HERE))

		hover(notice(frame, 1).goal)

		-- Posted Wednesday 7 October 16:00:02 UTC: 09:00 on the UTC-7 realm.
		assert.are.same({ "Posted Wed 7 Oct, 09:00", "Only my Catches since then count" }, loaded.ns.BoardHoverLines())
		notice(frame, 1).goal:GetScript("OnLeave")(notice(frame, 1).goal)
		assert.is_nil(loaded.ns.BoardHoverLines())
	end)

	it("lists a Variety Expedition's Species, caught ones ticked", function()
		local loaded, _, frame = opened(startedLog(VARIETY, RARITY))
		-- ns.CountCatch (logic/Progress.lua) counts a Mightfish, and the live apply redraws.
		loaded.ns.State().goals[idAt(T + 1)].seen[MIGHTFISH] = true
		loaded.ns.Redraw("projection")

		hover(expedition(frame, 1).goal)

		assert.are.same({
			"Posted Wed 7 Oct, 09:00",
			"Only my Catches since then count",
			"Raw Slitherskin Mackerel",
			"Oily Blackmouth",
			"Mightfish",
		}, loaded.ns.BoardHoverLines())
	end)
end)

describe("the highlight (TKB-R109)", function()
	it("rings an open goal's pin for 2 s when the board opens on its ID", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, RARITY, LURE))
		loaded.ns.board:Hide()

		loaded.ns.OpenBoard(idAt(T + 3))

		assert.is_true(notice(frame, 2).highlight:IsShown())
		assert.is_false(notice(frame, 1).highlight:IsShown())
		loaded.client.advance(1.9)
		assert.is_true(notice(frame, 2).highlight:IsShown())
		loaded.client.advance(0.1)
		assert.is_false(notice(frame, 2).highlight:IsShown())
	end)

	it("highlights nothing for a completed goal's ID", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, RARITY, LURE))
		local ns = loaded.ns
		local state = ns.State()
		local done = state.goals[idAt(T + 3)]
		done.doneDay = state.day
		ns.FreePin(state, done)
		ns.board:Hide()

		ns.OpenBoard(idAt(T + 3))

		for i = 1, 6 do
			assert.is_false(notice(frame, i).highlight:IsShown())
		end
		for i = 1, 2 do
			assert.is_false(expedition(frame, i).highlight:IsShown())
		end
	end)
end)

describe('"take it down"\'s tooltip (TKB-R55, TKB-R44, TKB-R108)', function()
	-- The tooltip's lines once the mouse is over a pin's "take it down".
	local function tip(loaded, slot)
		local button = slot.goal.takeDown
		button:GetScript("OnEnter")(button)
		return loaded.ns.BoardHoverLines()
	end

	it("says what it does, by type, and that the new one waits for the daily reset (in 23h), at the cursor", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, RARITY))
		loaded.client.cursor = { 300, 200 }

		assert.are.same({
			"Take it down",
			"Pin a fresh Notice of another kind in its place. Any progress on this one is lost.",
			"The new one can't be taken down again until the daily reset (in 23h), unless it stops being catchable.",
		}, tip(loaded, notice(frame, 1)))
		local shown = tip(loaded, expedition(frame, 1))
		assert.are.equal(
			"Pin a fresh Expedition of another kind in its place. Any progress on this one is lost.",
			shown[2]
		)
	end)

	it("says why it waits while the board is updating", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, RARITY))
		loaded.ns.IsUpdating = function()
			return true
		end
		loaded.ns.Redraw("projection")

		assert.are.equal(
			"Not while the board is updating. It can come down once that's done.",
			tip(loaded, notice(frame, 1))[3]
		)
	end)

	it("says a stranded goal is no longer catchable, re-posted or not", function()
		local records = startedLog(EXPEDITION, RARITY, STRANDED)
		local loaded, _, frame = opened(records)

		assert.are.equal(
			"This one is no longer catchable: it can never be finished where it hangs.",
			tip(loaded, notice(frame, 2))[3]
		)
	end)

	it(
		"says a stranded goal re-posted today comes down though re-posted, with no stamp and its button (TKB-R44, TKB-R55)",
		function()
			local records = startedLog(EXPEDITION, RARITY, STRANDED)
			records[#records + 1] = record("reroll", T + 10, idAt(T + 3) .. ";" .. STRANDED) -- stranded again, re-posted
			local loaded, _, frame = opened(records)

			local slip = notice(frame, 2).goal
			assert.is_false(slip.stamp:IsShown())
			assert.is_true(slip.takeDown:IsShown())
			assert.are.equal(loaded.ns.L.TAKE_DOWN_TIP_STRANDED, tip(loaded, notice(frame, 2))[3])
			hover(slip)
			assert.are.equal(2, #loaded.ns.BoardHoverLines())
		end
	)

	it("keeps its words to the glyphs every font draws (CORE-R9)", function()
		local ns = opened(startedLog(EXPEDITION)).ns
		for _, line in ipairs({
			ns.L.TAKE_DOWN_TIP_TITLE,
			ns.L.TAKE_DOWN_TIP.n,
			ns.L.TAKE_DOWN_TIP.e,
			ns.L.TAKE_DOWN_TIP_ONCE,
			ns.L.REPOSTED_HOVER,
			ns.L.TAKE_DOWN_TIP_STRANDED,
			ns.L.TAKE_DOWN_TIP_STRANDED_FIRST,
			ns.L.TAKE_DOWN_TIP_UPDATING,
		}) do
			assert(line:find("[\128-\255]") == nil, line) -- plain ASCII
			assert(line:lower():find("reroll", 1, true) == nil, line)
		end
	end)
end)

describe("a pinned goal's tacks (TKB-R102)", function()
	-- A rect { left, top, right, bottom } from the paper's top left, y down.
	local function rect(left, top, width, height)
		return { left, top, left + width, top + height }
	end
	local function overlap(a, b)
		return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
	end
	-- A tack's drawn element, from its TOPLEFT anchor on the paper (ns.PlaceSprite).
	local function tackRect(tack)
		local point = tack.points[1]
		return rect(point[4] + tack.box[1], -point[5] + tack.box[2], tack.box[3], tack.box[4])
	end
	-- A font string anchored by its CENTER or TOPRIGHT to the paper's top left, at the fake's 6 units a character.
	local function textRect(text)
		local point = text.points[1]
		local width, x, y = text:GetStringWidth(), point[4], -point[5]
		if point[1] == "CENTER" then
			return rect(x - width / 2, y - 7, width, 14)
		end
		return rect(x - width, y, width, 14) -- TOPRIGHT
	end

	for _, lean in ipairs({ true, false }) do
		it(
			"never sits on a pay: the posters' seals, the Notices' coins and their pay (lean " .. tostring(lean) .. ")",
			function()
				local loaded, _, frame = opened(startedLog(EXPEDITION, VARIETY, HAUL_HERE, RARITY, LURE, COLLECTOR))
				loaded.ns.db.profile.lean = lean
				loaded.ns.Redraw("projection")

				local checked = 0
				for _, slot in ipairs(frame.parts.pins.slots.expeditions) do
					local slip = slot.goal
					for _, tack in ipairs(slip.tacks) do
						assert.is_false(overlap(tackRect(tack), textRect(slip.seal.label)))
						checked = checked + 1
					end
				end
				for i = 1, 4 do
					local slip = notice(frame, i).goal
					for _, tack in ipairs(slip.tacks) do
						assert.is_false(overlap(tackRect(tack), textRect(slip.coin.label)))
						assert.is_false(overlap(tackRect(tack), textRect(slip.pay)))
						checked = checked + 1
					end
				end
				assert.are.equal(8, checked) -- two tacks on each of the two posters, one on each of four Notices
			end
		)
	end
end)
