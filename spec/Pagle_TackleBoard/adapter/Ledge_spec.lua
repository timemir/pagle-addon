-- The spike and the ledge on the board (TKB-R64, TKB-R103, TKB-R106, TKB-R193; SHOP-R41; ADR 0009) on FakePagle over
-- the fixture catalogue: a started board's log (its Module records and Casts appended with fake.catchLog:Append), then
-- login, the first PLAYER_ENTERING_WORLD and the login's live step, then the board opened. What the logic decides is
-- in logic/Ledge_spec; this checks what the board draws, what its clicks open and what its hovers show.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, pass = board.record, board.pass

local DAY = board.DAY
local W = board.WEEK0 -- Tuesday 6 October 2026 15:00 UTC: the weekly reset week 0 starts at
local TODAY = board.DAILY_RESET -- Sunday 11 October 15:00 UTC: the board day the fake's clock is in
local D0 = board.DAY0 -- Wednesday 7 October 15:00 UTC: four board days before TODAY
local DUROTAR, BARRENS = 14, 17
local BLACKMOUTH = 6358

local ONE_DUROTAR = "n;haul;1;10;1;14"
local ONE_BARRENS = "n;haul;2;15;1;17"
local FILLER = "n;haul;2;15;30;12"
local EXPEDITION = "e;haul;0;60;150;12"

-- A caught Cast of one `itemID` in `zone`, for fake.catchLog:Append.
local function cast(time, zone, itemID)
	return board.cast(time, zone, { itemID })
end

-- The Angler's skill read, then a board started at `at` on the board day starting `dayStart`, with an Expedition and
-- three Notices, the first Notices `notices`, then fillers; then `casts`.
local function started(at, dayStart, notices, casts)
	local records = {
		board.skill(at - 30),
		record("start", at, dayStart .. ";" .. W),
		record("issue", at + 1, EXPEDITION),
	}
	for i = 1, 3 do
		records[#records + 1] = record("issue", at + 1 + i, notices[i] or FILLER)
	end
	for _, entry in ipairs(casts or {}) do
		records[#records + 1] = entry
	end
	return records
end

local S = TODAY + 60
-- Two Notices done today: Durotar's at 15:01:10 UTC, then The Barrens' at 15:01:20.
local TWO_DONE_TODAY = started(
	S,
	TODAY,
	{ ONE_DUROTAR, ONE_BARRENS },
	{ cast(S + 10, DUROTAR, BLACKMOUTH), cast(S + 20, BARRENS, BLACKMOUTH) }
)
-- One Notice done today.
local ONE_DONE_TODAY = started(S, TODAY, { ONE_DUROTAR }, { cast(S + 10, DUROTAR, BLACKMOUTH) })
-- Started today, nothing done.
local FRESH = started(S, TODAY, {})
-- Started Wednesday and lit, then away: two Kindling burned, then the fire went out on Saturday.
local WENT_OUT = started(D0 + 3600, D0, { ONE_DUROTAR }, { cast(D0 + 3610, DUROTAR, BLACKMOUTH) })

-- Pagle_TackleBoard on a fake whose log holds `records`, logged in, its projection built and the login's live step
-- run, and its board open.
local function opened(records)
	local names = { areas = { [DUROTAR] = "Durotar", [BARRENS] = "The Barrens" } }
	local loaded, fake, frame = board.opened(records, { names = names, step = true })
	return loaded, fake, frame.parts.spike, frame.parts.ledge, frame
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

-- Hovers `widget`, as the mouse going over it does.
local function hover(widget)
	widget:GetScript("OnEnter")(widget)
end

-- The spike's shown slips' texts, top to bottom.
local function spiked(spike)
	local texts = {}
	for _, slip in ipairs(spike.slips or {}) do
		if slip:IsShown() then
			texts[#texts + 1] = slip.label:GetText()
		end
	end
	return texts
end

describe("the spike (TKB-R103)", function()
	it("hangs today's two done goals in completion order over \"2 done today. The fire's lit.\"", function()
		local _, _, spike, _, frame = opened(TWO_DONE_TODAY)

		assert.is_true(visible(spike, frame))
		assert.are.same({ "1 Catch in Durotar", "1 Catch in The Barrens" }, spiked(spike))
		assert.are.equal("2 done today. The fire's lit.", spike.label:GetText())
		assert.are.equal("NOTICE DONE", spike.slips[1].kicker:GetText())
		assert.is_true(spike.slips[2]:GetFrameLevel() > spike.slips[1]:GetFrameLevel()) -- the later over the earlier
	end)

	it("notes each slip's Coins and the fly it tied by hand, and shows them with the fly on its hover", function()
		local loaded, _, spike = opened(TWO_DONE_TODAY)
		local fly = loaded.ns.State().goals[PLAYER_GUID .. "-" .. (S + 2) .. "-0"].fly

		hover(spike.slips[1])

		assert.are.equal("+10 · " .. fly, spike.slips[1].note:GetText())
		assert.are.same(
			{ "1 Catch in Durotar", "Paid 10 Coins", "Tied for your Fly Box: " .. fly },
			loaded.ns.BoardHoverLines()
		)
	end)

	it("swings its slips on the nail while the papers lean, and hangs them straight with the lean off", function()
		local loaded, _, spike = opened(TWO_DONE_TODAY)
		local paper = spike.slips[1].paper
		paper.SetRotation = function(self, radians)
			self.rotation = radians
		end

		loaded.ns.Redraw("projection")
		assert.are.equal(-math.rad(14), paper.rotation)
		loaded.ns.db.profile.lean = false
		loaded.ns.board:Draw("open")
		assert.are.equal(0, paper.rotation)
	end)

	it('is empty after the reset and reads "Done ones go on the spike."', function()
		local loaded, fake, spike = opened(TWO_DONE_TODAY)

		pass(loaded, fake, DAY) -- the reset's live step redraws the open board

		assert.are.same({}, spiked(spike))
		assert.are.equal("Done ones go on the spike.", spike.label:GetText())
	end)
end)

-- A done slip's lines against its paper and its column (TKB-R103, #471). The fake measures no font, so each line is
-- measured here, a little wider than the client's IM Fell (about 0.46 of its size a character, 0.5 here) and as tall as
-- the client sets it (a line of the kicker and the goal text its font's size, the hand note 1.25 times): the goal text
-- wrapped at the words to its width, its lines 1.3 apart as ArtWrap sets them, and cut by its SetMaxLines.
describe("a done slip's lines (TKB-R103)", function()
	local PAPER_WIDTH, PAPER_HEIGHT = 136, 92
	local STONETALON, PLAGUELANDS, CATFISH = 406, 139, 6308
	-- The Done today column, in the spike's own units from its top left: the cork's right edge is at 160 (the board's cork
	-- is 952 wide, the spike at 792) and the Notice papers it stands beside end at 780, so -12; the heading "Done today"
	-- is over the first slip, and the line "N done today..." under the last, down to the cork's bottom, 452.
	local COLUMN_LEFT, COLUMN_RIGHT, COLUMN_BOTTOM = -12, 160, 452
	local HOLE_X, HOLE_Y, STACK_ROOM = 68, 12, 250 -- the nail's hole in a slip, and the stack's room (adapter/Ledge.lua)
	local function sizeOf(fontString)
		return fontString.fontObject.font[2]
	end
	local function measure(fontString, wraps, tall)
		local size, lines, line = sizeOf(fontString), 1, ""
		if not wraps then
			return size * tall
		end
		for word in (fontString.text or ""):gmatch("%S+") do
			local try = line == "" and word or line .. " " .. word
			if #try * size * 0.5 > fontString:GetWidth() and line ~= "" then
				lines, line = lines + 1, word
			else
				line = try
			end
		end
		if (fontString.maxLines or 0) > 0 then
			lines = math.min(lines, fontString.maxLines)
		end
		return lines * size * tall + (lines - 1) * 1.3
	end

	-- The Tackle Board's goal texts: every type and kind of ns.L.GOAL_TEXT, as one, four, thirty and 150, with the longest
	-- zone, continent, Species and fly names the shipped catalogue has (Stonetalon Mountains, Eastern Plaguelands, Raw
	-- Bristle Whisker Catfish, the Eastern Kingdoms), so every text the generator can write is among them or shorter.
	local function longestTexts(ns)
		local texts, seen = {}, {}
		local targets = { haul = STONETALON, variety = PLAGUELANDS, species = CATFISH, rarity = 2 }
		for goalType, kinds in pairs(ns.L.GOAL_TEXT) do
			for kind in pairs(kinds) do
				for _, target in ipairs({ targets[kind] or 0, kind == "rarity" and 3 or targets[kind] or 1 }) do
					for _, need in ipairs({ 1, 4, 30, 150 }) do
						local text = ns.GoalText({
							type = goalType,
							kind = kind,
							tier = 1,
							pay = 10,
							need = need,
							target = target,
							items = { CATFISH },
						})
						if not seen[text] then
							seen[text] = true
							texts[#texts + 1] = text
						end
					end
				end
			end
		end
		table.sort(texts)
		return texts
	end

	-- Measures each line of every slip as the client would.
	local function measured(spike)
		for _, slip in ipairs(spike.slips) do
			slip.kicker.GetStringHeight = function(self)
				return measure(self, false, 1)
			end
			slip.label.GetStringHeight = function(self)
				return measure(self, true, 1)
			end
			slip.note.GetStringHeight = function(self)
				return measure(self, false, 1.25)
			end
		end
	end

	-- Draws done slips, one for each of `goals` ({ kicker, text, note }), as the spike draws them.
	local function hang(loaded, goals)
		loaded.ns.SpikeView = function()
			local view = { goals = {}, label = "N done today. The fire's lit." }
			for i, goal in ipairs(goals) do
				view.goals[i] = { id = "g" .. i, kicker = goal[1], text = goal[2], note = goal[3], hover = { goal[2] } }
			end
			return view
		end
		loaded.ns.Redraw("projection")
	end

	-- Each line of `slip` as a rect from the paper's top left: { left, top, right, bottom }.
	local function linesOf(slip)
		local rects = {}
		for i, fontString in ipairs({ slip.kicker, slip.label, slip.note }) do
			local height = measure(fontString, fontString == slip.label, i == 3 and 1.25 or 1)
			local width = fontString:GetWidth()
			local point = fontString.points[1]
			local x, y = point[4] - slip.hangX, -point[5] - slip.hangY
			rects[i] = { x - width / 2, y - height / 2, x + width / 2, y + height / 2 }
		end
		return rects
	end

	local function newSpike(n)
		local loaded, _, spike = opened(TWO_DONE_TODAY)
		loaded.ns.db.profile.lean = false -- straight, so a line's rect is its own
		loaded.client.areaNames[STONETALON], loaded.client.areaNames[PLAGUELANDS] =
			"Stonetalon Mountains", "Eastern Plaguelands"
		loaded.client.itemNames[CATFISH] = "Raw Bristle Whisker Catfish"
		loaded.client.mapNames[1415] = "Eastern Kingdoms"
		local goals = {}
		for i = 1, n or 1 do
			goals[i] = { "NOTICE DONE", "1 Catch in Durotar", "+10" }
		end
		hang(loaded, goals) -- makes the slips, which are then measured
		measured(spike)
		return loaded, spike
	end

	it("sets every goal text on the paper, in full, clear of the kicker and the note, at the longest (#471)", function()
		local loaded, spike = newSpike()
		local texts = longestTexts(loaded.ns)
		local note = "+200 · Thicket Fern"

		assert.is_true(#texts >= 15) -- every type and kind, in the one and the many forms
		local problems, smallest = {}, 13
		for _, text in ipairs(texts) do
			for _, kicker in ipairs({ "NOTICE DONE", "EXPEDITION DONE" }) do
				hang(loaded, { { kicker, text, note } })
				local slip = spike.slips[1]
				local rects, what = linesOf(slip), text .. " / " .. kicker
				for i, rect in ipairs(rects) do
					if rect[1] < 0 or rect[3] > PAPER_WIDTH or rect[2] < 0 or rect[4] > PAPER_HEIGHT then
						problems[#problems + 1] = what .. ": line " .. i .. " is off the paper"
					end
				end
				if rects[1][4] > rects[2][2] + 0.001 then
					problems[#problems + 1] = what .. ": the text is over the kicker"
				end
				if rects[2][4] > rects[3][2] + 0.001 then
					problems[#problems + 1] = what .. ": the text is over the note"
				end
				-- No ellipsis: the goal text isn't cut by lines.
				if (slip.label.maxLines or 0) ~= 0 then
					problems[#problems + 1] = what .. ": the text is cut to " .. slip.label.maxLines .. " lines"
				end
				smallest = math.min(smallest, sizeOf(slip.label))
			end
		end
		assert.are.same({}, problems)
		assert.is_true(smallest >= 10.5) -- no smaller than the smallest of its fonts
	end)

	it(
		"keeps the slip as it was while the goal text fits at 13: the kicker at 22, the text at 36, the note at 68 (#471)",
		function()
			local loaded, spike = newSpike()

			hang(loaded, { { "NOTICE DONE", "1 Catch in Durotar", "+10" } })
			local rects = linesOf(spike.slips[1])

			assert.are.equal("PagleTackleBoardDoneGoal", spike.slips[1].label.fontObject.name)
			for i, top in ipairs({ 22, 36, 68 }) do
				assert.is.near(top, rects[i][2], 0.001)
			end
		end
	)

	it(
		"makes room for a longer goal text: the kicker up under the nail, the text the paper's width, a smaller font (#471)",
		function()
			local loaded, spike = newSpike()

			hang(loaded, { { "NOTICE DONE", "3 Catches of an uncommon variety or better", "+10 · Thicket Fern" } })
			local slip = spike.slips[1]
			local rects = linesOf(slip)

			assert.is_true(rects[1][2] < 22) -- the kicker has moved up
			assert.is_true(slip.label:GetWidth() > 114) -- and the text runs wider
			assert.are_not.equal("PagleTackleBoardDoneGoal", slip.label.fontObject.name)
			assert.are.equal(0, slip.label.maxLines)
		end
	)

	it(
		"cuts a text no font can fit by lines, an ellipsis being the last resort, and lets the next one have its font back (#471)",
		function()
			local loaded, spike = newSpike()
			local absurd = ("Catches in Stonetalon Mountains "):rep(8)

			hang(loaded, { { "NOTICE DONE", absurd, "+10" } })
			assert.is_true(spike.slips[1].label.maxLines > 0)
			local rects = linesOf(spike.slips[1])
			assert.is_true(rects[2][4] <= rects[3][2] + 0.001)

			hang(loaded, { { "NOTICE DONE", "1 Catch in Durotar", "+10" } })
			assert.are.equal("PagleTackleBoardDoneGoal", spike.slips[1].label.fontObject.name)
			assert.are.equal(0, spike.slips[1].label.maxLines)
		end
	)

	it(
		"hangs every slip inside its column at the most it holds: clear of the Notices, the cork, the heading and the line under (#471)",
		function()
			local swings, count = {}, 30 -- far more than the 250 units of room holds at their step
			local loaded, spike = newSpike(count)
			local longest = "150 different Species in Eastern Plaguelands"
			local goals = {}
			for i = 1, count do
				goals[i] = { "EXPEDITION DONE", longest, "+200 · Thicket Fern" }
			end
			hang(loaded, goals)

			local left, right, top, bottom = math.huge, -math.huge, math.huge, -math.huge
			for i = 1, count do
				local slip = spike.slips[i]
				swings[#swings + 1] = slip.swing
				-- The paper's corners turned about the nail's hole (clockwise, y down), from the spike's top left.
				local width, height = slip.paper.box[3], slip.paper.box[4]
				local angle = math.rad(slip.swing)
				for _, corner in ipairs({ { 0, 0 }, { width, 0 }, { 0, height }, { width, height } }) do
					local dx, dy = corner[1] - HOLE_X, corner[2] - HOLE_Y
					local x = slip.hangX + HOLE_X + dx * math.cos(angle) - dy * math.sin(angle)
					local y = slip.hangY + HOLE_Y + dx * math.sin(angle) + dy * math.cos(angle)
					left, right = math.min(left, x), math.max(right, x)
					top, bottom = math.min(top, y), math.max(bottom, y)
				end
			end
			local labelTop = -spike.label.points[1][5]

			assert.is_true(count > STACK_ROOM / 12) -- the step has closed up
			local problems = {}
			if left < COLUMN_LEFT or right > COLUMN_RIGHT then
				problems[#problems + 1] = ("across %.1f to %.1f, not inside %d to %d"):format(
					left,
					right,
					COLUMN_LEFT,
					COLUMN_RIGHT
				)
			end
			if top < spike.head:GetStringHeight() then -- the heading is at 0
				problems[#problems + 1] = ("up to %.1f, over the heading"):format(top)
			end
			if bottom > labelTop then
				problems[#problems + 1] = ("down to %.1f, over the line under at %.1f"):format(bottom, labelTop)
			end
			if labelTop + 2 * 20 > COLUMN_BOTTOM then -- the line under, two lines tall, inside the cork
				problems[#problems + 1] = "the line under runs off the cork"
			end
			assert.are.same({}, problems)
			assert.is_true(#swings == count)
		end
	)
end)

-- The Campfire's stage on the ledge, and its layers shown, sorted.
local function fireLayers(fire)
	local layers = {}
	for suffix, texture in pairs(fire.burning.layers) do
		if texture:IsShown() then
			layers[#layers + 1] = suffix
		end
	end
	table.sort(layers)
	return fire.burning.stage, layers
end

describe("the Campfire on the ledge (TKB-R106)", function()
	it('reads "Not lit yet" by bare logs on a fresh board, with no glow', function()
		local _, _, _, ledge, frame = opened(FRESH)
		local fire = ledge.fire

		assert.are.equal("Not lit yet", fire.text:GetText())
		assert.is_false(fire.days:IsShown())
		assert.are.same({ "none", { "" } }, { fireLayers(fire) })
		assert.is_false(fire.glow:IsShown())
		assert.is_false(frame.glow:IsShown())
	end)

	it('reads "1 day" with 2 of 3 sticks of Kindling and "longest 1" while lit, its glow over the cork', function()
		local _, _, _, ledge, frame = opened(ONE_DONE_TODAY)
		local fire = ledge.fire

		assert.are.same({ "1", "day" }, { fire.days:GetText(), fire.word:GetText() })
		assert.are.equal("longest 1", fire.longest:GetText())
		assert.are.same({ 1, 1, 0.28 }, {
			fire.sticks[1]:GetAlpha(),
			fire.sticks[2]:GetAlpha(),
			fire.sticks[3]:GetAlpha(),
		})
		assert.are.same({ "3", { "-base", "-fl1", "-fl2", "-fl3", "-front" } }, { fireLayers(fire) })
		assert.is_true(fire.glow:IsShown())
		assert.is_true(frame.glow:IsShown())
	end)

	it('reads "Gone out" over embers after a fire went out', function()
		local _, _, _, ledge = opened(WENT_OUT)
		local fire = ledge.fire

		assert.are.equal("Gone out", fire.text:GetText())
		assert.are.same({ "out", { "-base", "-embers", "-front" } }, { fireLayers(fire) })
		assert.is_false(fire.glow:IsShown())
	end)

	it("steps the fire up at 7, 30, 100 and 365 days", function()
		local loaded, _, _, ledge = opened(ONE_DONE_TODAY)
		local state = loaded.ns.State()

		local stages = {}
		for _, count in ipairs({ 6, 7, 30, 100, 365 }) do
			state.fire.count = count
			loaded.ns.Redraw("projection")
			stages[#stages + 1] = ledge.fire.burning.stage
		end

		assert.are.same({ "3", "7", "30", "100", "365" }, stages)
		assert.is_true(ledge.fire.burning.layers["-rays"]:IsShown()) -- the 365-day rays
		assert.is_nil(ledge.fire.burning.layers["-embers"])
	end)
end)

describe("the Campfire card (TKB-R106, TKB-R64)", function()
	it("is made at its first opening, on a click on the Campfire, with 28 days, today last and ringed", function()
		local loaded, _, _, ledge, frame = opened(WENT_OUT)
		assert.is_nil(ledge.card)

		ledge.fire:Click()

		local card = ledge.card
		assert.is_true(visible(card, frame))
		assert.is_true(ledge.veil:IsShown())
		assert.are.equal(loaded.ns.BOARD_ATLASES.Card.file, card.paper.texture)
		assert.are.equal(28, #card.days)
		assert.is_true(card.days[28].today:IsShown())
		assert.is_false(card.days[27].today:IsShown())
		assert.are.same({ "14 Sep", "21 Sep", "28 Sep", "5 Oct" }, {
			card.weeks[1]:GetText(),
			card.weeks[2]:GetText(),
			card.weeks[3]:GetText(),
			card.weeks[4]:GetText(),
		})
		hover(card.days[28])
		assert.are.same({ "Sun 11 Oct", "today" }, loaded.ns.BoardHoverLines())
		hover(card.days[26])
		assert.are.same({ "Fri 9 Oct", "Kindling burned" }, loaded.ns.BoardHoverLines())
		hover(card.days[23])
		assert.are.same({ "Tue 6 Oct", "before the board" }, loaded.ns.BoardHoverLines())
		assert.is_false(card.days[23].icon:IsShown())
		assert.is_true(card.days[26].icon:IsShown())
	end)

	it(
		"plays its own crackling sound once each time it opens, on the SFX channel, and none when it closes (#473)",
		function()
			local loaded, _, _, ledge = opened(WENT_OUT)
			local file = "Interface\\AddOns\\Pagle_TackleBoard\\media\\sounds\\Campfire.ogg SFX"
			local function crackles()
				local count = 0
				for _, sound in ipairs(loaded.client.sounds) do
					if sound == file then
						count = count + 1
					end
				end
				return count
			end

			assert.are.equal(0, crackles())
			ledge.fire:Click() -- opens
			assert.are.equal(1, crackles())
			ledge.fire:Click() -- closes
			assert.are.equal(1, crackles())
			ledge.plate:Click() -- opens again, by the tally plate
			assert.are.equal(2, crackles())
			ledge.box:Click() -- the drawer takes the card's place: no crackle
			assert.are.equal(2, crackles())
		end
	)

	it("lists the milestones with their Coins and what is still to go, the titles not earned greyed", function()
		local _, _, _, ledge = opened(WENT_OUT)

		ledge.fire:Click()

		local row = ledge.card.rows.milestones[1]
		assert.are.same(
			{ "7 days", "campfire_7", "7 more days", "25" },
			{ row.label:GetText(), row.name:GetText(), row.more:GetText(), row.coins:GetText() }
		)
		assert.are.equal("PagleTackleBoardCardNotEarned", row.name.fontObject.name)
		assert.are.same(
			{ "25 goals", "24 more goals" },
			{ ledge.card.rows.tally[1].label:GetText(), ledge.card.rows.tally[1].more:GetText() }
		)
		assert.is_false(ledge.card.rows.tally[1].coins:IsShown())
		assert.are.same(
			{ "Fly Box", "29 more patterns" },
			{ ledge.card.rows.flybox[1].label:GetText(), ledge.card.rows.flybox[1].more:GetText() }
		)
	end)

	it("shows a celebrated title as earned (TKB-R64)", function()
		local loaded, _, _, ledge = opened(WENT_OUT)
		loaded.ns.db.global.celebrated.titles.tally_25 = true

		ledge.fire:Click()

		local row = ledge.card.rows.tally[1]
		assert.are.equal("PagleTackleBoardCardEarned", row.name.fontObject.name)
		assert.is_false(row.more:IsShown())
	end)

	it("closes with its close mark, and is closed when the board opens again", function()
		local loaded, _, _, ledge = opened(WENT_OUT)
		ledge.fire:Click()

		ledge.card.close:Click()
		assert.is_false(ledge.card:IsShown())
		assert.is_false(ledge.veil:IsShown())

		ledge.fire:Click()
		loaded.ns.board:Hide()
		loaded.ns.OpenBoard()
		assert.is_false(ledge.card:IsShown())
	end)
end)

describe("the Fly Box (TKB-R106)", function()
	it('reads "1 of 30 tied" after one completion', function()
		local _, _, _, ledge = opened(ONE_DONE_TODAY)

		assert.are.equal("1 of 30 tied", ledge.box.count:GetText())
		assert.are.equal("F L Y   B O X", ledge.box.title:GetText())
	end)

	it("opens its drawer: the tied fly in full with its hover, the rest faint, the rare row gilt", function()
		local loaded, _, _, ledge, frame = opened(ONE_DONE_TODAY)
		local tied = loaded.ns.State().goals[PLAYER_GUID .. "-" .. (S + 2) .. "-0"].fly
		assert.is_nil(ledge.drawer)

		ledge.box:Click()

		local drawer = ledge.drawer
		assert.is_true(visible(drawer, frame))
		assert.is_true(ledge.card == nil or not ledge.card:IsShown())
		assert.are.equal("1 of 30 tied", drawer.count:GetText())
		local untied, rare, tiedCell = 0, 0, nil
		for _, cell in ipairs(drawer.cells) do
			if cell.label:GetText() == "not tied yet" then
				untied = untied + 1
				assert.are.equal(0.22, cell.fly:GetAlpha())
				assert.is_true(cell.fly:IsDesaturated())
			elseif cell.label:GetText() == "tied only by Expeditions" then
				rare = rare + 1
			end
			if cell.cell.id == tied then
				tiedCell = cell
			end
		end
		assert.are.same({ 23, 6 }, { untied, rare })
		assert(tiedCell, "the tied pattern's compartment")
		assert.are.equal(1, tiedCell.fly:GetAlpha())
		assert.are.equal(loaded.ns.BOARD_ATLASES.Flies.file, tiedCell.fly.texture)
		assert.are.equal(tied, tiedCell.label:GetText())
		hover(tiedCell)
		assert.are.same({ tied, "Tied Sun 11 Oct", "by: 1 Catch in Durotar" }, loaded.ns.BoardHoverLines())
		for i = 25, 30 do
			assert.is_not_nil(drawer.cells[i].rare)
		end
		assert.is_nil(drawer.cells[24].rare)
	end)

	it("closes its drawer on a second click", function()
		local _, _, _, ledge = opened(ONE_DONE_TODAY)

		ledge.box:Click()
		ledge.box:Click()

		assert.is_false(ledge.drawer:IsShown())
		assert.is_false(ledge.veil:IsShown())
	end)
end)

describe("the tally plate (TKB-R106, TKB-R64)", function()
	it("shows the counts and the latest title", function()
		local loaded, _, _, ledge = opened(TWO_DONE_TODAY)
		loaded.ns.State().titles.tally_25 = { day = 0, cast = "c" }
		loaded.ns.L["boardtitle.tally_25.text"] = "the Dependable"

		loaded.ns.Redraw("projection")

		assert.are.equal("2 Notices · 0 Expeditions", ledge.plate.counts:GetText())
		assert.are.equal("the Dependable", ledge.plate.latest:GetText())
	end)

	it('never shows a title earned only in the celebrated set as the latest: "no title yet" (TKB-R64)', function()
		local loaded, _, _, ledge = opened(TWO_DONE_TODAY)
		loaded.ns.db.global.celebrated.titles.campfire_7 = true

		loaded.ns.Redraw("projection")

		assert.are.equal("no title yet", ledge.plate.latest:GetText())
		assert.are.equal("PagleTackleBoardTallyNone", ledge.plate.latest.fontObject.name)
	end)
end)

describe("the shop card (TKB-R106, SHOP-R41, TKB-R193)", function()
	it("reads its words with a pointing hand drawn as a texture, and opens the Curio Shop", function()
		local loaded, fake, _, ledge = opened(FRESH)

		assert.are.equal("Coins go to the Curio Shop", ledge.shop.label:GetText())
		assert.are.equal(loaded.ns.BOARD_ATLASES.Board.file, ledge.shop.pointer.texture)

		ledge.shop:Click()

		assert.are.equal(1, #fake.shopsOpened)
	end)

	it("prints Core's line instead while restricted, opening nothing", function()
		local _, fake, _, ledge = opened(FRESH)
		fake.setRestricted(true)
		local printed = #fake.printed

		ledge.shop:Click()

		assert.are.equal(0, #fake.shopsOpened)
		assert.are.equal(printed + 1, #fake.printed)
	end)
end)

describe("the Refresh count (TKB-R106, REF-R5)", function()
	-- The count's words, without the Refresh ticket's icon (an inline texture) before them.
	local function words(label)
		return (label:GetText():gsub("^|T[^|]*|t ", ""))
	end

	it("reads the Refreshes held under the shop card, 0 until one is earned", function()
		local _, _, _, ledge = opened(FRESH)

		assert.are.equal("0 Refreshes held", words(ledge.refresh.label))
		assert.is_true(visible(ledge.refresh, ledge))
	end)

	it("draws the Refresh ticket's icon before the count (#466)", function()
		local loaded, _, _, ledge = opened(FRESH)

		assert.are.equal(loaded.ns.TicketMarkup(16) .. " 0 Refreshes held", ledge.refresh.label:GetText())
		assert.is_truthy(ledge.refresh.label:GetText():find("^|T.-Pagle_TackleBoard.-Ticket:16:23:"))
	end)

	it("follows Core's count as Refreshes are earned and spent, with the singular for one", function()
		local _, fake, _, ledge = opened(FRESH)

		fake.setTickets("Hunts", 1)
		fake.fire("TicketsChanged", fake.Pagle.GetTickets())
		local one = words(ledge.refresh.label)
		fake.setTickets("Hunts", 5)
		fake.fire("TicketsChanged", fake.Pagle.GetTickets())
		local five = words(ledge.refresh.label)
		fake.setTickets("TackleBoard", nil, 2)
		fake.fire("TicketsChanged", fake.Pagle.GetTickets())

		assert.are.same({ "1 Refresh held", "5 Refreshes held", "3 Refreshes held" }, {
			one,
			five,
			words(ledge.refresh.label),
		})
	end)

	it("says under the mouse what a Refresh is for and where it comes from", function()
		local loaded, _, _, ledge = opened(FRESH)

		ledge.refresh:GetScript("OnEnter")(ledge.refresh)

		assert.are.same({
			"Refreshes",
			"Each one posts a fresh Notice or Expedition in an empty slot on the board. Click an empty slot to use one.",
			"Pagle Wagers earn them.",
		}, loaded.ns.BoardHoverLines())
		ledge.refresh:GetScript("OnLeave")(ledge.refresh)
		assert.is_nil(loaded.ns.BoardHoverLines())
	end)
end)

describe("the board's layers (ns.BOARD_LAYERS)", function()
	it(
		"draws the card, the drawer, their veil, the updating note and the welcome slip over the spike's nail",
		function()
			local loaded, _, spike, ledge, frame = opened(TWO_DONE_TODAY)
			ledge.fire:Click()
			ledge.box:Click()
			local nail = spike.top:GetFrameLevel()

			for _, slip in ipairs(spike.slips) do
				assert.is_true(slip:GetFrameLevel() < nail) -- the nail over its own slips
			end
			for name, overlay in pairs({
				card = ledge.card,
				drawer = ledge.drawer,
				veil = ledge.veil,
				updating = frame.updating,
				welcome = frame.empty,
				close = frame.close,
			}) do
				assert(overlay:GetFrameLevel() > nail, name)
			end
			assert.is_true(ledge.card:GetFrameLevel() > ledge.veil:GetFrameLevel())
			assert.is_true(frame.close:GetFrameLevel() > ledge.drawer:GetFrameLevel())
			assert.has_error(function()
				loaded.ns.BoardLayer("attic")
			end)
		end
	)
end)
