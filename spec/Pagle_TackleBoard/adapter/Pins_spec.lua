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
local QUALITY = "n;quality;1;10;3;2"
local COLLECTOR = "n;collector;2;15;2;" -- session-bound: 2 in one Session
local LURE = "n;lure;3;20;25;"
local STRANDED = "n;species;2;15;10;" .. REMOVED_FISH
local EXPEDITION = "e;size;0;60;1;4"
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
	it('shows its Expedition on a poster with the "60" seal and its Notices on slips', function()
		local _, _, frame = opened(startedLog(EXPEDITION, HAUL_HERE, QUALITY, LURE))

		local poster = expedition(frame, 1).goal
		assert.is_true(visible(poster, frame))
		assert.is_not_nil(poster.top) -- the poster's red top edge
		assert.are.equal("60", poster.seal.label:GetText())
		assert.are.same(
			{ "SIZE", "A Whopper-or-better Catch", "0 of 1", "anywhere", "pays 60 Coins" },
			reads(expedition(frame, 1))
		)
		assert.are.same(
			{ "HAUL", "30 Catches in Darkshore", "0 of 30", "I'm here", "pays 15 Coins" },
			reads(notice(frame, 1))
		)
		assert.are.same(
			{ "QUALITY", "3 uncommon-or-better Catches", "0 of 3", "anywhere", "pays 10 Coins" },
			reads(notice(frame, 2))
		)
		assert.are.same(
			{ "LURE", "25 Catches with a lure on", "0 of 25", "anywhere", "pays 20 Coins" },
			reads(notice(frame, 3))
		)
		assert.is_nil(notice(frame, 1).goal.seal)
		assert.is_false(visible(notice(frame, 1).empty, frame))
	end)

	it("hangs a goal with no empty pin in the overflow strip", function()
		local _, _, frame = opened(startedLog(EXPEDITION, QUALITY, QUALITY, QUALITY, QUALITY, QUALITY, QUALITY, LURE))

		local chips = frame.parts.overflow.chips
		assert.is_true(visible(chips[1], frame))
		assert.are.equal("Lure: 25 Catches with a lure on", chips[1].label:GetText())
		assert.is_false(chips[2] ~= nil and chips[2]:IsShown())
	end)

	it("shows the overflow goal's lines on its hover", function()
		local loaded, _, frame =
			opened(startedLog(EXPEDITION, QUALITY, QUALITY, QUALITY, QUALITY, QUALITY, QUALITY, LURE))

		hover(frame.parts.overflow.chips[1])

		assert.are.same({
			"25 Catches with a lure on",
			"0 of 25",
			"anywhere",
			"pays 20 Coins",
			"Posted Wed 7 Oct, 09:00",
			"Only my Catches since then count",
		}, loaded.client.gameTooltip.lines)
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

describe("a session-bound goal's progress (TKB-R104)", function()
	it('reads "1 of 2 this Session" during its Session and "0 of 2 this Session" after it ends', function()
		local loaded, fake, frame = opened(startedLog(EXPEDITION, COLLECTOR))
		fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })
		-- The completions' ticket counts the Catch (#232); here its outcome is set: 1, in this Session.
		local collector = loaded.ns.State().goals[idAt(T + 2)]
		collector.progress, collector.session = 1, fake.Pagle.GetSession().id
		loaded.ns.Redraw("projection")

		assert.are.equal("1 of 2 this Session", notice(frame, 1).goal.progress:GetText())

		fake.wait(901) -- the Session ends 15 minutes after its last Cast (LOG-R62)

		assert.are.equal("0 of 2 this Session", notice(frame, 1).goal.progress:GetText())
	end)
end)

describe('"take it down", RE-POSTED and stranded goals (TKB-R44, TKB-R55, TKB-R108)', function()
	-- The board with a re-posted goal and a stranded one, and a reroll seam that lets every goal not re-posted, and the
	-- stranded one, be taken down, recording each goal taken down.
	local function withSeams()
		local records = startedLog(EXPEDITION, QUALITY, STRANDED)
		records[#records + 1] = record("reroll", T + 10, idAt(T + 2) .. ";" .. LURE)
		local taken = {}
		local loaded, fake, frame = opened(records, {
			prepare = function(l)
				l.ns.CanTakeDown = function(goalID)
					local goal = l.ns.State().goals[goalID]
					return goal ~= nil and (not goal.reposted or goalID == idAt(T + 3))
				end
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
		local _, _, frame = opened(startedLog(EXPEDITION, QUALITY))

		local empty = notice(frame, 2).empty
		assert.is_true(visible(empty, frame))
		assert.is_false(visible(notice(frame, 2).goal, frame))
		assert.is_not_nil(empty.tack)
		assert.is_true(#empty.dashes > 0)
		-- Sunday 15:15 UTC: the daily reset at 15:00 UTC is 23 h 45 min away.
		assert.are.equal("A fresh Notice at reset (in 23h)", empty.label:GetText())
		assert.are.equal("A fresh Notice at reset (in 23h)", notice(frame, 4).empty.label:GetText())
		assert.are.equal("More Notices at later resets", notice(frame, 5).empty.label:GetText())
		assert.are.equal("Next Expedition at the weekly reset (Tue)", expedition(frame, 2).empty.label:GetText())
	end)

	it("refresh their countdown every 60 s while the board is open", function()
		local loaded, fake, frame = opened(startedLog(EXPEDITION, QUALITY))

		fake.wait(3600)
		assert.are.equal("A fresh Notice at reset (in 23h)", notice(frame, 2).empty.label:GetText())
		loaded.client.advance(60)

		assert.are.equal("A fresh Notice at reset (in 22h)", notice(frame, 2).empty.label:GetText())
	end)
end)

describe("a pinned goal's hover (TKB-R102)", function()
	it("shows its realm posted time and that only Catches since then count", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, HAUL_HERE))

		hover(notice(frame, 1).goal)

		-- Posted Wednesday 7 October 16:00:02 UTC: 09:00 on the UTC-7 realm.
		assert.are.same(
			{ "Posted Wed 7 Oct, 09:00", "Only my Catches since then count" },
			loaded.client.gameTooltip.lines
		)
		assert.is_true(loaded.client.gameTooltip.shown)
		notice(frame, 1).goal:GetScript("OnLeave")(notice(frame, 1).goal)
		assert.is_false(loaded.client.gameTooltip.shown)
	end)

	it("lists a Variety Expedition's Species, caught ones ticked", function()
		local loaded, _, frame = opened(startedLog(VARIETY, QUALITY))
		-- The completions' ticket counts a Mightfish (#232), and the live apply redraws.
		loaded.ns.State().goals[idAt(T + 1)].seen[MIGHTFISH] = true
		loaded.ns.Redraw("projection")

		hover(expedition(frame, 1).goal)

		local box = "|TInterface\\Buttons\\UI-CheckBox-Up:0|t "
		local tick = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "
		assert.are.same({
			"Posted Wed 7 Oct, 09:00",
			"Only my Catches since then count",
			box .. "Raw Slitherskin Mackerel",
			box .. "Oily Blackmouth",
			tick .. "Mightfish",
		}, loaded.client.gameTooltip.lines)
	end)
end)

describe("the highlight (TKB-R109)", function()
	it("rings an open goal's pin for 2 s when the board opens on its ID", function()
		local loaded, _, frame = opened(startedLog(EXPEDITION, QUALITY, LURE))
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
		local loaded, _, frame = opened(startedLog(EXPEDITION, QUALITY, LURE))
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
