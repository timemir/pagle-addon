-- The Pagle Wagers spread's left page as data (HNT-R27, HNT-R143, HNT-R148, HNT-R156, HNT-R160, HNT-R162, HNT-R166,
-- HNT-R167, HNT-R204): the note that follows the table, the closing note, the wager tickets and the rows ahead, the
-- empty box, and the ladder as a rail. Pure logic, on the fixture event pool and stand-in names, at FakePagle's fixed
-- clock (realm 08:15 on Sunday 11 October 2026, at UTC). The spread as drawn is spec/Pagle_Hunts/adapter/
-- WagersSpread_spec.lua's.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local NOW = SERVER_TIME -- realm 08:15 on Sunday 11 October 2026, at UTC (hunts.SUNDAY)

local function load()
	return hunts.load().ns
end

-- One of ns.RunsShown's runs (HuntsShownRun) of the fixture pool's event `id`, from `start` to `end_`, on or ahead as
-- NOW falls, with `huntsProgress` (by Hunt ID) its progress; `fields` over the run (`source`, `completedAt`).
local function shownRun(ns, id, start, end_, huntsProgress, fields)
	local run = { event = id, start = start, end_ = end_, source = "r", hunts = huntsProgress or {} }
	for key, value in pairs(fields or {}) do
		run[key] = value
	end
	return { key = id .. "@" .. start, run = run, event = ns.events:Event(id), on = start <= NOW }
end

-- `shown` with its event's fields `fields` over a copy of it.
local function withEvent(shown, fields)
	local event = {}
	for key, value in pairs(shown.event) do
		event[key] = value
	end
	for key, value in pairs(fields) do
		event[key] = value
	end
	shown.event = event
	return shown
end

-- logic/Wagers.lua's inputs over `runs` at NOW, with the fixture catalogue's area names and a best skill of 150.
local function wagersInput(runs, updating)
	return {
		runs = runs,
		now = NOW,
		snapshot = hunts.SUNDAY,
		updating = updating == true,
		best = 150,
		sources = {
			AreaName = function(areaID)
				return C.NAMES.areas[areaID]
			end,
		},
	}
end

local function spreadOf(runs, spread, updating)
	spread = spread or {}
	spread.settled, spread.ladder, spread.ended = spread.settled or 0, spread.ladder or {}, spread.ended or {}
	return load().BuildWagersSpread(wagersInput(runs, updating), spread)
end

-- fixture_shore on from a day ago, closing in `left` seconds (2d 4h by default): the Snapper at its first mark, the
-- Haul at 1 of 2.
local function shore(ns, left, fields)
	return shownRun(
		ns,
		"fixture_shore",
		NOW + (left or 2 * DAY + 4 * HOUR) - 3 * DAY,
		NOW + (left or 2 * DAY + 4 * HOUR),
		{
			fixture_shore_snapper = hunts.progress({ tiers = 1 }),
			fixture_shore_haul = hunts.progress({ count = 1 }),
		},
		fields
	)
end

describe("the spread's note (HNT-R162)", function()
	it("counts the wagers on, two or more, or reads one", function()
		local ns = load()
		local one = spreadOf({ shore(ns) })
		local two = spreadOf({ shore(ns), shownRun(ns, "fixture_vale", NOW - HOUR, NOW + DAY) })

		assert.are.same(
			{ "Pagle Wagers", "On the table", "One wager on. Land every Hunt's first mark before it closes." },
			{ one.kicker, one.title, one.note }
		)
		assert.are.equal("2 wagers on. Land every Hunt's first mark before its wager closes.", two.note)
	end)

	it("says when the next opens with none on and one ahead, and that nothing is posted with neither", function()
		local ns = load()
		local ahead = spreadOf({ shownRun(ns, "fixture_vale", NOW + 3 * HOUR, NOW + 3 * HOUR + 3 * DAY) })

		assert.are.equal("Nothing on just now. The next wager opens Sun 11:15.", ahead.note)
		assert.are.equal("Nothing on the table, and nothing posted yet.", spreadOf({}).note)
	end)
end)

describe("the closing note (HNT-R162)", function()
	it("names the soonest run on within 3 hours of its end, up to the first comma of its name", function()
		local ns = load()
		local soon = withEvent(shore(ns, 42 * 60), { id = "fixture_shore" })
		ns.L["event.fixture_shore.name"] = "Frenzy Water, at Last"

		local spread = ns.BuildWagersSpread(
			wagersInput({ soon, shownRun(ns, "fixture_vale", NOW - HOUR, NOW + 2 * HOUR) }),
			{ settled = 0, ladder = {}, ended = {} }
		)

		assert.are.equal("Frenzy Water closes in 42m!", spread.closing)
	end)

	it("leaves out a settled run and a run more than 3 hours from its end, and is nil with none", function()
		local ns = load()

		assert.is_nil(spreadOf({ shore(ns, 3 * HOUR + 60) }).closing)
		assert.are.equal("Shore Wager closes in 3h!", spreadOf({ shore(ns, 3 * HOUR) }).closing)
		assert.is_nil(spreadOf({ shore(ns, 42 * 60, { completedAt = NOW - HOUR }) }).closing)
		assert.is_nil(spreadOf({}).closing)
	end)
end)

describe("the wager tickets (HNT-R162, HNT-R160)", function()
	it('give a run on its mark, dial, name, line, pips and first marks, under "On now {n}"', function()
		local ns = load()
		local run = shore(ns)

		local spread = spreadOf({ run })

		assert.are.same({ label = "On now", count = 1 }, spread.onNow)
		assert.are.equal(1, #spread.tickets)
		local ticket = spread.tickets[1]
		assert.are.same({
			run.key,
			false,
			true,
			false,
			"rotation",
			"Shore Wager",
			"Darkshore · until Tue 12:15", -- HNT-R50, HNT-R203: the end in realm time
			"1 of 3 first marks",
		}, {
			ticket.run,
			ticket.closed,
			ticket.selected,
			ticket.settled,
			ticket.source,
			ticket.name,
			ticket.line,
			ticket.marks,
		})
		assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-water-coast", "mark-ring" }, ticket.mark)
		-- 2d 4h of 3d to go: 26 of 36
		assert.are.same({ kind = "on", step = 26, urgent = false, left = "2d 4h" }, ticket.dial)
		assert.are.same({ false, true, false }, ticket.pips)
		assert.is_nil(ticket.need)
		assert.is_nil(ticket.holiday)
		assert.are.equal(run.key, spread.selected) -- the first run's by default
	end)

	it("press the SETTLED stamp in place of the pips once a run is completed, the dial staying in grey", function()
		local ns = load()
		local done = hunts.progress({ tiers = 1 })
		local run = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY, {
			fixture_shore_haul = hunts.progress({ tiers = 1, count = 2 }),
			fixture_shore_snapper = done,
			fixture_shore_oddity = done,
		}, { completedAt = NOW - HOUR })

		local ticket = spreadOf({ run }).tickets[1]

		assert.is_true(ticket.settled)
		assert.is_nil(ticket.pips)
		assert.is_nil(ticket.marks)
		assert.are.same({ kind = "settled", step = 24, urgent = false, left = "2d" }, ticket.dial)
	end)

	it("redden the dial within 3 hours of the end", function()
		local ns = load()

		local ticket = spreadOf({ shore(ns, 42 * 60) }).tickets[1]

		assert.are.same({ kind = "on", step = 1, urgent = true, left = "42m" }, ticket.dial)
	end)

	it("put a holiday run's tag after its name, from the companion or the rotation", function()
		local ns = load()
		local pushed = withEvent(shore(ns, nil, { source = "p" }), { tags = { "coast", "hallows_end", "low" } })
		local rotation = withEvent(shore(ns), { tags = { "winter_veil", "low" } })

		local tickets = spreadOf({ pushed, rotation }).tickets

		assert.are.same({ "Hallow's End", "companion" }, { tickets[1].holiday, tickets[1].source })
		assert.are.equal("Feast of Winter Veil", tickets[2].holiday)
		assert.are.equal("mark-charm-hallows_end", tickets[1].mark[#tickets[1].mark])
	end)

	it('read "needs skill {n}" short of skill, the event\'s own lower end (HNT-R156)', function()
		local ns = load()
		local short = withEvent(shore(ns), { skill = { 276, 300 } })

		assert.are.equal("needs skill 276", spreadOf({ short }).tickets[1].need)
	end)

	it("show no requirement for a skill below 0, however low the Angler's best (HNT-R156)", function()
		local ns = load()
		for _, skill in ipairs({ { -70, -20 }, { -20, 75 } }) do
			local input = wagersInput({ withEvent(shore(ns), { skill = skill }) })
			input.best = -50
			local spread = load().BuildWagersSpread(input, { settled = 0, ladder = {}, ended = {} })
			assert.is_nil(spread.tickets[1].need)
		end
	end)

	it("keep a run that ended this showing, greyed and closed, after the rest, never chosen (HNT-R143)", function()
		local ns = load()
		local ended = shownRun(ns, "fixture_shore", NOW - 3 * DAY, NOW - HOUR, {
			fixture_shore_snapper = hunts.progress({ tiers = 1 }),
		})
		local vale = shownRun(ns, "fixture_vale", NOW - HOUR, NOW + 3 * DAY - HOUR)

		local spread = spreadOf({ vale }, { ended = { ended }, run = ended.key })

		assert.are.same({ vale.key, ended.key }, { spread.tickets[1].run, spread.tickets[2].run })
		local closed = spread.tickets[2]
		assert.are.same({ true, false }, { closed.closed, closed.selected })
		assert.are.equal("Darkshore · closed Sun 07:15", closed.line)
		assert.are.same({ kind = "closed", urgent = false, left = "closed" }, closed.dial)
		assert.are.equal("1 of 3 first marks", closed.marks)
		-- "On now" counts the runs still on
		assert.are.same({ label = "On now", count = 1 }, spread.onNow)
		-- the run asked for has closed: the first run's is chosen in its place
		assert.are.equal(vale.key, spread.selected)
	end)

	it(
		'read "updating…" for their marks, with no pips and no stamp, while the projection updates (HNT-R69)',
		function()
			local ns = load()
			local run = shore(ns, nil, { completedAt = NOW - HOUR })

			local spread = spreadOf({ run }, { settled = 3 }, true)

			local ticket = spread.tickets[1]
			assert.are.same({ "updating…", false }, { ticket.marks, ticket.settled })
			assert.is_nil(ticket.pips)
			assert.are.equal("on", ticket.dial.kind)
		end
	)
end)

describe("the rows ahead (HNT-R162)", function()
	it(
		'give a run ahead its mark, name, zones, "opens {weekday} {time}" and "for {length}" under "Ahead {n}"',
		function()
			local ns = load()
			local vale = withEvent(shownRun(ns, "fixture_vale", NOW + 3 * HOUR, NOW + 3 * HOUR + 3 * DAY), {
				skill = { 276, 300 },
			})

			local spread = spreadOf({ shore(ns), vale })

			assert.are.same(
				{ label = "Ahead", count = 1, caption = "posted, and may change before it opens" },
				spread.ahead
			)
			assert.are.equal(1, #spread.tickets)
			assert.are.same({
				run = vale.key,
				selected = false,
				mark = { "mark-shadow", "mark-sky-plain", "mark-water-lake", "mark-ring" },
				name = "fixture_vale",
				zones = "Ashenvale & Elwynn Forest",
				need = "needs skill 276",
				opens = "opens Sun 11:15",
				length = "for 3d",
			}, spread.aheadRows[1])
		end
	)

	it("can be chosen, and the first run ahead is chosen with none on", function()
		local ns = load()
		local vale = shownRun(ns, "fixture_vale", NOW + 3 * HOUR, NOW + 3 * HOUR + 3 * DAY)

		local alone = spreadOf({ vale })
		local chosen = spreadOf({ shore(ns), vale }, { run = vale.key })

		assert.are.same({ vale.key, true }, { alone.selected, alone.aheadRows[1].selected })
		assert.is_nil(alone.onNow)
		assert.are.same(
			{ vale.key, false, true },
			{ chosen.selected, chosen.tickets[1].selected, chosen.aheadRows[1].selected }
		)
	end)
end)

describe("the empty box (HNT-R162, HNT-R204)", function()
	it("shows with no run on or ahead, the ladder still at the foot", function()
		local spread = spreadOf({})

		assert.are.same({}, spread.tickets)
		assert.are.same({}, spread.aheadRows)
		assert.are.equal(
			"No wagers on the table, and none posted ahead. The rotation puts one on at the next turn.",
			spread.empty
		)
		assert.is_nil(spread.selected)
		assert.is_nil(spread.onNow)
		assert.is_nil(spread.ahead)
		assert.are.equal("0 wagers settled · 25 more for Bookmaker's Bane", spread.ladder.line)
	end)

	it("doesn't show beside a ticket that closed this showing", function()
		local ns = load()
		local ended = shownRun(ns, "fixture_shore", NOW - 3 * DAY, NOW - HOUR)

		assert.is_nil(spreadOf({}, { ended = { ended } }).empty)
	end)
end)

describe("the ladder's rail (HNT-R148, HNT-R162)", function()
	-- The ladder for `settled` completed runs and the steps earned in `ladder`.
	local function ladderAt(settled, ladder, updating)
		return load().BuildWagersLadder(settled, ladder or {}, updating)
	end
	-- The titles at 50 and 100, the lore's (#307) as ns.LadderTitle reads them.
	local RUIN, BREAKER = load().LadderTitle(50), load().LadderTitle(100)

	it("puts its share at 0, a third, two thirds and the whole rail at 0, 25, 50 and 100, straight between", function()
		local ns = load()
		local function near(expected, actual)
			assert(math.abs(expected - actual) < 1e-12, ("%s, not %s"):format(expected, actual))
		end

		near(0, ns.LadderShare(0))
		near(1 / 3 * 17 / 25, ns.LadderShare(17))
		near(1 / 3, ns.LadderShare(25))
		near(1 / 3 + 1 / 3 * 5 / 25, ns.LadderShare(30))
		near(2 / 3, ns.LadderShare(50))
		near(2 / 3 + 1 / 3 * 25 / 50, ns.LadderShare(75))
		near(1, ns.LadderShare(100))
		near(1, ns.LadderShare(121))
	end)

	it('reads "The ladder", its posts at 25, 50 and 100 each with its title, and its line cut in three inks', function()
		local ladder = ladderAt(17)

		assert.are.equal("The ladder", ladder.label)
		assert.are.same({
			{ step = 25, title = "Bookmaker's Bane", reached = false, at = 1 / 3 },
			{ step = 50, title = RUIN, reached = false, at = 2 / 3 },
			{ step = 100, title = BREAKER, reached = false, at = 1 },
		}, ladder.marks)
		assert.are.equal("17 wagers settled · 8 more for Bookmaker's Bane", ladder.line)
		assert.are.same({
			{ text = "17", ink = "count" },
			{ text = " wagers settled · 8 more for ", ink = "line" },
			{ text = "Bookmaker's Bane", ink = "title" },
		}, ladder.runs)
	end)

	it("counts one wager settled in the singular", function()
		assert.are.equal("1 wager settled · 24 more for Bookmaker's Bane", ladderAt(1).line)
	end)

	it("presses an earned post, and puts the token toward the next", function()
		local ladder = ladderAt(30, { [25] = NOW })

		assert.are.same(
			{ true, false, false },
			{ ladder.marks[1].reached, ladder.marks[2].reached, ladder.marks[3].reached }
		)
		assert.are.equal("30 wagers settled · 20 more for " .. RUIN, ladder.line)
		assert(math.abs(ladder.share - 0.4) < 1e-12)
	end)

	it('reads only "{count} wagers settled" past the last mark, its rail full (default chosen in #303)', function()
		local ladder = ladderAt(121, { [25] = NOW, [50] = NOW, [100] = NOW })

		assert.are.same({ 1, "121 wagers settled" }, { ladder.share, ladder.line })
		assert.are.same({ { text = "121", ink = "count" }, { text = " wagers settled", ink = "line" } }, ladder.runs)
	end)

	it("reads the updating line, presses no post and shows no token while the projection updates (HNT-R69)", function()
		local ladder = ladderAt(30, { [25] = NOW }, true)

		assert.are.equal("Updating from your Catch log…", ladder.line)
		assert.is_nil(ladder.share)
		assert.is_false(ladder.marks[1].reached)
	end)
end)

describe("the spread's words (HNT-R27)", function()
	it("claim no odds, chance or due fish", function()
		local ns = load()
		local spread = spreadOf({ shore(ns, 42 * 60), shownRun(ns, "fixture_vale", NOW + HOUR, NOW + 3 * DAY) })
		local words =
			{ spread.kicker, spread.title, spread.note, spread.closing, spread.ladder.line, ns.L.SPREAD_EMPTY }
		for _, ticket in ipairs(spread.tickets) do
			words[#words + 1] = ticket.line
			words[#words + 1] = ticket.marks
		end
		for _, row in ipairs(spread.aheadRows) do
			words[#words + 1] = row.opens .. " " .. row.length
		end
		words[#words + 1] = spread.ahead.caption

		for _, text in ipairs(words) do
			for _, word in ipairs({ "odds", "chance", "due", "likely", "luck", "%%" }) do
				assert(text:lower():find(word) == nil, text)
			end
		end
	end)
end)
