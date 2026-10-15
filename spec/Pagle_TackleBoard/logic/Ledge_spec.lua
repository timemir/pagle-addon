-- What the spike and the ledge show (TKB-R62, TKB-R64, TKB-R70–R74, TKB-R103, TKB-R105, TKB-R106, TKB-R130), decided
-- by logic/Ledge.lua, on FakePagle over the fixture catalogue: a started board's log (its Module records and Casts
-- appended with fake.catchLog:Append, as the live step and Core append them), then login and the first
-- PLAYER_ENTERING_WORLD, so the projection is built and the login's live step has run. The support's reset API puts the
-- realm at UTC-7, with the daily reset at 15:00 UTC (08:00 realm) and the weekly on Tuesday; the fake's clock starts on
-- Sunday 11 October 2026 at 15:15 UTC. Every expected value is worked out by hand from the rules.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, idAt, pass = board.record, board.idAt, board.pass

local DAY = board.DAY
local W = board.WEEK0 -- Tuesday 6 October 2026 15:00 UTC: the weekly reset week 0 starts at
local TODAY = board.DAILY_RESET -- Sunday 11 October 15:00 UTC: the board day the fake's clock is in
local D0 = board.DAY0 -- Wednesday 7 October 15:00 UTC: four board days before TODAY
local DUROTAR, BARRENS = 14, 17
local BLACKMOUTH = 6358

-- Goal payloads (tackle-board.md › Data): Notices done by one Catch in Durotar or The Barrens, and fillers no Catch of
-- these specs completes.
local ONE_DUROTAR = "n;haul;1;10;1;14"
local ONE_BARRENS = "n;haul;2;15;1;17"
local FILLER = "n;haul;2;15;30;12"
local EXPEDITION = "e;haul;0;60;150;12"

-- A caught Cast of one `itemID` in `zone`, for fake.catchLog:Append.
local function cast(time, zone, itemID)
	return board.cast(time, zone, { itemID })
end

-- A board started at `at` on the board day starting `dayStart`, after the Angler's skill was read (generation's,
-- TKB-R30): the start record, then an Expedition and three Notices issued one second apart (the four goals owed at
-- Start, TKB-R20), the first Notices `notices`, then fillers.
local function started(at, dayStart, notices)
	local records = {
		board.skill(at - 30),
		record("start", at, dayStart .. ";" .. W),
		record("issue", at + 1, EXPEDITION),
	}
	for i = 1, 3 do
		records[#records + 1] = record("issue", at + 1 + i, notices[i] or FILLER)
	end
	return records
end

-- Pagle_TackleBoard over a log holding `records`, logged in with its projection built and the login's live step run.
---@return PagleTackleBoardNS ns
---@return LoadedAddon loaded
---@return table fake
local function built(records)
	local fake = board.withHistory(records)
	local loaded = board.load(fake)
	loaded.client.areaNames[DUROTAR] = "Durotar"
	loaded.client.areaNames[BARRENS] = "The Barrens"
	fake.login()
	fake.enterWorld()
	loaded.client.runTimers() -- the frame after done: the login's live step (TKB-R13)
	return loaded.ns, loaded, fake
end

-- Today's board: started at 15:01 UTC, two Notices done today, Durotar's at 15:01:10 and The Barrens' at 15:01:20.
local S = TODAY + 60
local TWO_DONE_TODAY = {
	started(S, TODAY, { ONE_DUROTAR, ONE_BARRENS }),
	{ cast(S + 10, DUROTAR, BLACKMOUTH), cast(S + 20, BARRENS, BLACKMOUTH) },
}

-- `lists` concatenated, in order.
local function join(lists)
	local out = {}
	for _, list in ipairs(lists) do
		for _, value in ipairs(list) do
			out[#out + 1] = value
		end
	end
	return out
end

describe("the spike (TKB-R103)", function()
	it("hangs today's done goals in completion order, with \"2 done today. The fire's lit.\"", function()
		local ns = built(join(TWO_DONE_TODAY))

		local spike = ns.SpikeView(ns.State())

		assert.are.equal(2, #spike.goals)
		assert.are.equal(idAt(S + 2), spike.goals[1].id)
		assert.are.equal("1 Catch in Durotar", spike.goals[1].text)
		assert.are.equal(idAt(S + 3), spike.goals[2].id)
		assert.are.equal("1 Catch in The Barrens", spike.goals[2].text)
		assert.are.equal("2 done today. The fire's lit.", spike.label)
	end)

	it("shows each goal's Coins and the fly it tied on its hover", function()
		local ns = built(join(TWO_DONE_TODAY))
		local fly = ns.State().goals[idAt(S + 2)].fly

		local hover = ns.SpikeView(ns.State()).goals[1].hover

		-- The support leaves the shipped lore out: the fly's name falls back to its ID (TKB-R130).
		assert.are.same({ "1 Catch in Durotar", "Paid 10 Coins", "Tied for your Fly Box: " .. fly }, hover)
	end)

	it('reads "Done ones go on the spike." with none done, and empties at the next reset', function()
		local ns, loaded, fake = built(join(TWO_DONE_TODAY))

		pass(loaded, fake, DAY)

		local spike = ns.SpikeView(ns.State())
		assert.are.same({}, spike.goals)
		assert.are.equal("Done ones go on the spike.", spike.label)
	end)

	it("hangs only the goals done on the projection's day, not those of the day before", function()
		local ns = built(join({
			started(D0 + 3600, D0, { ONE_DUROTAR }),
			{ cast(D0 + 3610, DUROTAR, BLACKMOUTH) },
		}))

		assert.are.same({}, ns.SpikeView(ns.State()).goals)
	end)
end)

-- A board that started on Wednesday (board day 0) and lit it, then went unvisited until Sunday (day 4): day 1 and day
-- 2 burned its two Kindling, and day 3 put the fire out (TKB-R71, TKB-R72).
local WENT_OUT = join({
	started(D0 + 3600, D0, { ONE_DUROTAR }),
	{ cast(D0 + 3610, DUROTAR, BLACKMOUTH) },
})

-- A board started today with nothing done: the login's live step issues its first goals (TKB-R20).
local FRESH = {
	board.skill(S - 30),
	record("start", S, TODAY .. ";" .. W),
}

-- A Campfire table (TackleFire) at `count` days: lit, with the longest at least the count.
local function fire(count, longest)
	return { count = count, kindling = 2, longest = longest or count, milestones = {}, log = {} }
end

describe("the Campfire on the ledge (TKB-R106)", function()
	it('reads "Not lit yet" with bare logs on a board never lit', function()
		local ns = built(FRESH)

		local view = ns.CampfireView(ns.State().fire)

		assert.are.equal("unlit", view.state)
		assert.are.equal("Not lit yet", view.text)
		assert.are.equal(0, view.step) -- no flame: bare logs
		assert.are.equal(2, view.kindling) -- the Kindling Start gives (TKB-R71)
		assert.are.equal(3, view.kindlingCap)
		assert.are.equal("longest 0", view.longest)
	end)

	it('reads "{n} days" with its Kindling and longest while lit', function()
		local ns = built(join(TWO_DONE_TODAY))

		local view = ns.CampfireView(ns.State().fire)

		assert.are.equal("lit", view.state)
		assert.are.equal("1 day", view.text)
		assert.are.equal(1, view.step)
		assert.are.equal(2, view.kindling)
		assert.are.equal("longest 1", view.longest)
		assert.are.equal("12 days", ns.CampfireView(fire(12)).text)
	end)

	it('reads "Gone out" with embers when the count is 0 after a fire, its longest kept (TKB-R72, TKB-R74)', function()
		local ns = built(WENT_OUT)

		local view = ns.CampfireView(ns.State().fire)

		assert.are.equal("out", view.state)
		assert.are.equal("Gone out", view.text)
		assert.are.equal(0, view.step)
		assert.are.equal(2, view.kindling) -- refilled when it went out (TKB-R72)
		assert.are.equal("longest 1", view.longest)
	end)

	it("steps its flame up at 7, 30, 100 and 365 days of the current fire, not at the longest", function()
		local ns = built({})

		local steps = {}
		for _, count in ipairs({ 1, 6, 7, 29, 30, 99, 100, 364, 365, 1000 }) do
			steps[#steps + 1] = ns.CampfireView(fire(count)).step
		end

		assert.are.same({ 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 }, steps)
		assert.are.equal(1, ns.CampfireView(fire(3, 400)).step)
	end)

	it("brightens between the steps, and starts each step dimmer than the last one ended", function()
		local ns = built({})
		local function bright(count)
			return ns.CampfireView(fire(count)).bright
		end

		assert.is_true(bright(1) < bright(6))
		assert.is_true(bright(7) < bright(20))
		assert.is_true(bright(20) < bright(29))
		assert.is_true(bright(30) < bright(29))
		assert.is_true(bright(1) >= 0 and bright(1000) <= 1)
	end)
end)

-- The celebrated set's titles (PagleTackleBoardDB.global.celebrated, TKB-R83), none by default.
local NONE_CELEBRATED = {}

describe("the Campfire card's four-week log (TKB-R106, TKB-R105)", function()
	it("lists the last 28 board days, today last, each dated in realm time", function()
		local ns = built(WENT_OUT)

		local days = ns.CampfireCard(ns.State(), NONE_CELEBRATED).days

		assert.are.equal(28, #days)
		assert.are.same({ day = 4, status = "today", text = "today", date = "Sun 11 Oct", number = 11 }, days[28])
		assert.are.same(
			{ day = -23, status = "before", text = "before the board", date = "Mon 14 Sep", number = 14 },
			days[1]
		)
	end)

	it("logs a lit day, the Kindling burned, the day it went out and the days before the board (TKB-R72)", function()
		local ns = built(WENT_OUT)

		local days = ns.CampfireCard(ns.State(), NONE_CELEBRATED).days
		local texts = {}
		for i = 23, 28 do
			texts[#texts + 1] = days[i].date .. ": " .. days[i].text
		end

		assert.are.same({
			"Tue 6 Oct: before the board",
			"Wed 7 Oct: lit",
			"Thu 8 Oct: Kindling burned",
			"Fri 9 Oct: Kindling burned",
			"Sat 10 Oct: went out",
			"Sun 11 Oct: today",
		}, texts)
	end)

	it('logs "not lit" for a day closed with no fire, and today as lit once a goal is done on it', function()
		local unlit = built({
			board.skill(D0 + 3570),
			record("start", D0 + 3600, D0 .. ";" .. W),
		})
		local lit = built(join(TWO_DONE_TODAY))

		local unlitDays = unlit.CampfireCard(unlit.State(), NONE_CELEBRATED).days
		local litDays = lit.CampfireCard(lit.State(), NONE_CELEBRATED).days

		assert.are.equal("not lit", unlitDays[24].text) -- Wednesday, the board's first day
		assert.are.equal("unlit", unlitDays[24].status)
		assert.are.equal("lit", litDays[28].status)
		assert.are.equal("before", litDays[27].status)
	end)

	it("heads its four weeks with the weekdays of its first seven days", function()
		local ns = built(WENT_OUT)

		local heads = ns.CampfireCard(ns.State(), NONE_CELEBRATED).heads

		assert.are.same({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }, heads)
	end)
end)

describe("the Campfire card's titles (TKB-R106, TKB-R64)", function()
	it("lists the milestones with their Coins and titles, greyed with what they need until reached", function()
		local ns = built(WENT_OUT)

		local milestones = ns.CampfireCard(ns.State(), NONE_CELEBRATED).milestones

		assert.are.same({
			{
				id = "campfire_7",
				name = "campfire_7",
				need = "a Campfire of 7 days",
				coins = "25 Coins",
				earned = false,
			},
			{
				id = "campfire_30",
				name = "campfire_30",
				need = "a Campfire of 30 days",
				coins = "75 Coins",
				earned = false,
			},
			{
				id = "campfire_100",
				name = "campfire_100",
				need = "a Campfire of 100 days",
				coins = "200 Coins",
				earned = false,
			},
			{
				id = "campfire_365",
				name = "campfire_365",
				need = "a Campfire of 365 days",
				coins = "500 Coins",
				earned = false,
			},
		}, milestones)
	end)

	it("lists the tally titles and the Fly Box title with what they need", function()
		local ns = built(WENT_OUT)

		local card = ns.CampfireCard(ns.State(), NONE_CELEBRATED)

		assert.are.same({
			{ id = "tally_25", name = "tally_25", need = "25 goals done", earned = false },
			{ id = "tally_100", name = "tally_100", need = "100 goals done", earned = false },
			{ id = "tally_500", name = "tally_500", need = "500 goals done", earned = false },
		}, card.tally)
		assert.are.same(
			{ { id = "flybox", name = "flybox", need = "every Fly Box pattern tied", earned = false } },
			card.flybox
		)
	end)

	it("shows a title earned in the projection, or only in the celebrated set, as earned (TKB-R64)", function()
		local ns = built(WENT_OUT)
		local state = ns.State()
		state.titles.campfire_7 = { day = 0, cast = idAt(D0 + 3610) }

		local card = ns.CampfireCard(state, { tally_25 = true })

		assert.is_true(card.milestones[1].earned)
		assert.is_true(card.tally[1].earned)
		assert.is_false(card.tally[2].earned)
	end)

	it("names titles from ns.L once the lore batch gives them text (TKB-R130)", function()
		local ns = built(WENT_OUT)
		ns.L["boardtitle.campfire_7.text"] = "Kindler"

		assert.are.equal("Kindler", ns.CampfireCard(ns.State(), NONE_CELEBRATED).milestones[1].name)
	end)
end)

-- Today's board with one Notice done, Durotar's at 15:01:10 UTC (08:01 realm).
local ONE_DONE_TODAY = join({
	started(S, TODAY, { ONE_DUROTAR }),
	{ cast(S + 10, DUROTAR, BLACKMOUTH) },
})

-- The cells of `view` whose text is `text`.
local function cellsReading(view, text)
	local found = {}
	for _, cell in ipairs(view.cells) do
		if cell.text == text then
			found[#found + 1] = cell
		end
	end
	return found
end

describe("the Fly Box and its drawer (TKB-R106, TKB-R62)", function()
	it('reads "1 of 30 tied" after one completion, and "0 of 30 tied" before any', function()
		local ns = built(ONE_DONE_TODAY)
		local fresh = built(FRESH)

		assert.are.equal("1 of 30 tied", ns.FlyBoxView(ns.State().flies).label)
		assert.are.equal("0 of 30 tied", fresh.FlyBoxView(fresh.State().flies).label)
	end)

	it("fills 6 columns by 5 rows in pattern order, row by row, the rare six on the last row", function()
		local ns = built(FRESH)

		local cells = ns.FlyBoxView(ns.State().flies).cells

		assert.are.equal(30, #cells)
		assert.are.same({ "murloc_nymph", 1, 1, false }, { cells[1].id, cells[1].row, cells[1].column, cells[1].rare })
		assert.are.same(
			{ "elwynn_royal", 2, 6, false },
			{ cells[12].id, cells[12].row, cells[12].column, cells[12].rare }
		)
		assert.are.same(
			{ "darkshore_dun", 4, 6, false },
			{ cells[24].id, cells[24].row, cells[24].column, cells[24].rare }
		)
		for i = 25, 30 do
			assert.are.same({ 5, i - 24, true }, { cells[i].row, cells[i].column, cells[i].rare })
		end
	end)

	it("shows the tied pattern's icon and name, with when and by which goal it was tied on its hover", function()
		local ns = built(ONE_DONE_TODAY)
		ns.L["fly.duskwood_shadow.name"] = "Duskwood Shadow"
		local state = ns.State()
		local tied = state.goals[idAt(S + 2)].fly

		local view = ns.FlyBoxView(state.flies)
		local cell
		for _, each in ipairs(view.cells) do
			cell = each.id == tied and each or cell
		end

		assert.is_true(cell.tied)
		assert.are.equal(ns.L["fly." .. tied .. ".name"] or tied, cell.text)
		local icon
		for _, pattern in ipairs(ns.FLY_PATTERNS) do
			icon = pattern.id == tied and pattern.icon or icon
		end
		assert.are.equal(icon, cell.icon)
		assert.are.same({ cell.text, "Tied Sun 11 Oct", "by: 1 Catch in Durotar" }, cell.hover)
	end)

	it("reads the hover's goal from the fly's stored copy, after the goal itself is gone", function()
		local ns = built(ONE_DONE_TODAY)
		local state = ns.State()
		local tied = state.goals[idAt(S + 2)].fly
		state.goals[idAt(S + 2)] = nil -- pruned after 28 board days (Data)

		for _, cell in ipairs(ns.FlyBoxView(state.flies).cells) do
			if cell.id == tied then
				assert.are.equal("by: 1 Catch in Durotar", cell.hover[3])
			end
		end
	end)

	it('reads "not tied yet" on the 29 untied patterns, with no icon', function()
		local ns = built(ONE_DONE_TODAY)

		local untied = cellsReading(ns.FlyBoxView(ns.State().flies), "not tied yet")

		assert.are.equal(29, #untied)
		for _, cell in ipairs(untied) do
			assert.is_false(cell.tied)
			assert.is_nil(cell.icon)
		end
	end)

	it('reads "tied only by Expeditions" on the rare six, and on no common one', function()
		local ns = built(FRESH)

		for _, cell in ipairs(ns.FlyBoxView(ns.State().flies).cells) do
			local hover = table.concat(cell.hover, "\n")
			assert.are.equal(cell.rare, hover:find("tied only by Expeditions", 1, true) ~= nil)
		end
	end)
end)

describe("the tally plate (TKB-R106, TKB-R61)", function()
	it("counts the Notices and Expeditions done, and shows no title before any", function()
		local ns = built(join(TWO_DONE_TODAY))

		local plate = ns.TallyView(ns.State())

		assert.are.equal("2 Notices · 0 Expeditions", plate.counts)
		assert.is_nil(plate.latest)
	end)

	it("counts one of each in the singular", function()
		local ns = built({})
		local state = ns.NewBoardState()
		state.tally = { notices = 1, expeditions = 1 }

		assert.are.equal("1 Notice · 1 Expedition", ns.TallyView(state).counts)
	end)

	it("shows the latest title: the one earned on the highest board day", function()
		local ns = built({})
		local state = ns.NewBoardState()
		state.titles = { tally_25 = { day = 9, cast = "a" }, campfire_7 = { day = 4, cast = "b" } }
		ns.L["boardtitle.tally_25.text"] = "the Dependable"

		assert.are.equal("the Dependable", ns.TallyView(state).latest)
	end)

	it("breaks a tie on the same day by the Titles table's order: the later one is the latest", function()
		local ns = built({})
		local state = ns.NewBoardState()
		state.titles = {
			flybox = { day = 3, cast = "a" },
			tally_25 = { day = 7, cast = "b" },
			campfire_7 = { day = 7, cast = "b" },
			tally_100 = { day = 7, cast = "c" },
		}

		-- TKB-R60 grants a Cast's tally title before its Campfire title; the table lists them in that order.
		assert.are.equal("campfire_7", ns.TallyView(state).latest)
	end)
end)
