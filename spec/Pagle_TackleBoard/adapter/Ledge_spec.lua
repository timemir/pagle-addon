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
	end)

	it("shows a done goal's Coins and fly on its hover", function()
		local loaded, _, spike = opened(TWO_DONE_TODAY)
		local fly = loaded.ns.State().goals[PLAYER_GUID .. "-" .. (S + 2) .. "-0"].fly

		hover(spike.slips[1])

		assert.are.same(
			{ "1 Catch in Durotar", "Paid 10 Coins", "Tied for your Fly Box: " .. fly },
			loaded.client.tooltipLines()
		)
	end)

	it('is empty after the reset and reads "Done ones go on the spike."', function()
		local loaded, fake, spike = opened(TWO_DONE_TODAY)

		pass(loaded, fake, DAY) -- the reset's live step redraws the open board

		assert.are.same({}, spiked(spike))
		assert.are.equal("Done ones go on the spike.", spike.label:GetText())
	end)
end)

describe("the Campfire on the ledge (TKB-R106)", function()
	it('reads "Not lit yet" over bare logs on a fresh board', function()
		local _, _, _, ledge = opened(FRESH)
		local fire = ledge.fire

		assert.are.equal("Not lit yet", fire.text:GetText())
		assert.is_false(fire.flame.flame:IsShown())
		assert.is_false(fire.flame.embers[1]:IsShown())
		assert.is_true(fire.flame.logs[1]:IsShown())
	end)

	it('reads "1 day" with 2 of 3 sticks of Kindling and "longest 1" while lit, the flame a texture', function()
		local _, _, _, ledge = opened(ONE_DONE_TODAY)
		local fire = ledge.fire

		assert.are.equal("1 day", fire.text:GetText())
		assert.are.equal("longest 1", fire.longest:GetText())
		assert.are.same({ 1, 1, 0.45 }, {
			fire.sticks.sticks[1]:GetAlpha(),
			fire.sticks.sticks[2]:GetAlpha(),
			fire.sticks.sticks[3]:GetAlpha(),
		})
		assert.is_true(fire.flame.flame:IsShown())
		assert.are.equal("Interface\\Icons\\Spell_Fire_Fire", fire.flame.flame.texture)
	end)

	it('reads "Gone out" over embers after a fire went out', function()
		local _, _, _, ledge = opened(WENT_OUT)
		local fire = ledge.fire

		assert.are.equal("Gone out", fire.text:GetText())
		assert.is_false(fire.flame.flame:IsShown())
		assert.is_true(fire.flame.embers[1]:IsShown())
		assert.is_true(fire.flame.ash:IsShown())
	end)

	it("draws a larger flame at 7 days than at 6", function()
		local loaded, _, _, ledge = opened(ONE_DONE_TODAY)
		local state = loaded.ns.State()

		state.fire.count = 6
		loaded.ns.Redraw("projection")
		local six = ledge.fire.flame.flame:GetWidth()
		state.fire.count = 7
		loaded.ns.Redraw("projection")
		local seven = ledge.fire.flame.flame:GetWidth()

		assert.is_true(seven > six)
	end)
end)

describe("the Campfire card (TKB-R106, TKB-R64)", function()
	it("opens on a click on the Campfire, with 28 days, today last", function()
		local loaded, _, _, ledge, frame = opened(WENT_OUT)

		ledge.fire:Click()

		local card = ledge.card
		assert.is_true(visible(card, frame))
		assert.are.equal(28, #card.days)
		assert.are.equal("11", card.days[28].number:GetText())
		hover(card.days[28])
		assert.are.same({ "Sun 11 Oct", "today" }, loaded.client.tooltipLines())
		hover(card.days[26])
		assert.are.same({ "Fri 9 Oct", "Kindling burned" }, loaded.client.tooltipLines())
		hover(card.days[23])
		assert.are.same({ "Tue 6 Oct", "before the board" }, loaded.client.tooltipLines())
	end)

	it("lists the milestones with their Coins, and greys the titles not earned with what they need", function()
		local _, _, _, ledge = opened(WENT_OUT)

		ledge.fire:Click()

		local row = ledge.card.rows.milestones[1]
		assert.are.equal("campfire_7", row.name:GetText())
		assert.are.equal("a Campfire of 7 days, 25 Coins", row.need:GetText())
		assert.is_true(row:GetAlpha() < 1)
		assert.is_false(row.tick:IsShown())
		assert.are.equal("25 goals done", ledge.card.rows.tally[1].need:GetText())
		assert.are.equal("every Fly Box pattern tied", ledge.card.rows.flybox[1].need:GetText())
	end)

	it("shows a celebrated title as earned (TKB-R64)", function()
		local loaded, _, _, ledge = opened(WENT_OUT)
		loaded.ns.db.global.celebrated.titles.tally_25 = true

		ledge.fire:Click()

		local row = ledge.card.rows.tally[1]
		assert.are.equal(1, row:GetAlpha())
		assert.is_true(row.tick:IsShown())
	end)

	it("closes with its close button, and is closed when the board opens again", function()
		local loaded, _, _, ledge = opened(WENT_OUT)
		ledge.fire:Click()

		ledge.card.close:Click()
		assert.is_false(ledge.card:IsShown())

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
	end)

	it("opens its drawer: the tied pattern's icon with its hover, 29 not tied yet, the rare row gilt", function()
		local loaded, _, _, ledge, frame = opened(ONE_DONE_TODAY)
		local tied = loaded.ns.State().goals[PLAYER_GUID .. "-" .. (S + 2) .. "-0"].fly

		ledge.box:Click()

		local drawer = ledge.drawer
		assert.is_true(visible(drawer, frame))
		assert.is_false(ledge.card:IsShown())
		local untied, tiedCell = 0, nil
		for _, cell in ipairs(drawer.cells) do
			if cell.label:GetText() == "not tied yet" then
				untied = untied + 1
				assert.is_false(cell.icon:IsShown())
			end
			if cell.cell.id == tied then
				tiedCell = cell
			end
		end
		assert.are.equal(29, untied)
		assert(tiedCell, "the tied pattern's compartment")
		assert.is_true(tiedCell.icon:IsShown())
		assert.are.equal(tied, tiedCell.label:GetText())
		hover(tiedCell)
		assert.are.same({ tied, "Tied Sun 11 Oct", "by: 1 Catch in Durotar" }, loaded.client.tooltipLines())
		local gilt = loaded.ns.BOARD_LOOK.gilt
		for i = 25, 30 do
			assert.are.same({ gilt[1], gilt[2], gilt[3], 1 }, drawer.cells[i].edges[1].color)
		end
		assert.are_not.same({ gilt[1], gilt[2], gilt[3], 1 }, drawer.cells[24].edges[1].color)
	end)

	it("closes its drawer on a second click", function()
		local _, _, _, ledge = opened(ONE_DONE_TODAY)

		ledge.box:Click()
		ledge.box:Click()

		assert.is_false(ledge.drawer:IsShown())
	end)
end)

describe("the tally plate (TKB-R106, TKB-R64)", function()
	it("shows the counts and the latest title", function()
		local loaded, _, _, ledge = opened(TWO_DONE_TODAY)
		loaded.ns.State().titles.tally_25 = { day = 0, cast = "c" }
		loaded.ns.L["boardtitle.tally_25.text"] = "the Dependable"

		loaded.ns.Redraw("projection")

		assert.are.equal("2 Notices, 0 Expeditions", ledge.plate.counts:GetText())
		assert.are.equal("the Dependable", ledge.plate.latest:GetText())
		assert.is_true(ledge.plate.latest:IsShown())
	end)

	it("never shows a title earned only in the celebrated set as the latest (TKB-R64)", function()
		local loaded, _, _, ledge = opened(TWO_DONE_TODAY)
		loaded.ns.db.global.celebrated.titles.campfire_7 = true

		loaded.ns.Redraw("projection")

		assert.is_false(ledge.plate.latest:IsShown())
	end)
end)

describe("the shop link (TKB-R106, SHOP-R41, TKB-R193)", function()
	it("reads its words with a pointing hand drawn as a texture, and opens the Curio Shop", function()
		local _, fake, _, ledge = opened(FRESH)

		assert.are.equal("Coins go to the Curio Shop", ledge.shop.label:GetText())
		assert.are.equal("Interface\\CURSOR\\Point", ledge.shop.pointer.texture)

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

describe("the spike's and the ledge's words (CORE-R9)", function()
	it("are plain ASCII: no glyph the client's fonts may lack", function()
		local loaded, _, spike, ledge = opened(WENT_OUT)
		ledge.fire:Click()
		local card = ledge.card
		ledge.box:Click()
		loaded.ns.State().titles.tally_25 = { day = 0, cast = "c" }
		loaded.ns.Redraw("projection")

		local function walk(widget)
			local text = widget.GetText and widget:GetText()
			if type(text) == "string" then
				assert.are.equal(text, (text:gsub("[\128-\255]", "?")))
			end
			for _, child in ipairs(widget.children or {}) do
				walk(child)
			end
		end
		walk(spike)
		walk(ledge)
		walk(card)
		walk(ledge.drawer)
	end)
end)
