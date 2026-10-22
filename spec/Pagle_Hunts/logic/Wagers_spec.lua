-- Pagle Wagers on the board as data (HNT-R27, HNT-R53, HNT-R54, HNT-R148, HNT-R162, HNT-R163, HNT-R204): an event
-- Hunt's shape and its line, the run entry's pay rule, and the Pagle Wagers spread's wager slips and ladder. Pure
-- logic, on the fixture event pool's Hunts and stand-in names, at FakePagle's fixed clock (realm 08:15 on Sunday 11
-- October 2026, at UTC). The strip, the WAGERS rows and a whole run entry are checked on FakePagle
-- (spec/Pagle_Hunts/adapter/Wagers_spec.lua), and the spread as drawn too (spec/Pagle_Hunts/adapter/
-- WagersSpread_spec.lua).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

-- Hunts' logic over the fixtures, and name stand-ins from the fixture catalogue's names.
local function load()
	local ns = hunts.load().ns
	local sources = {
		ItemName = function(itemID)
			return C.NAMES.items[itemID]
		end,
		BandName = function(band)
			return ({ [2] = "Hefty", [3] = "Trophy" })[band]
		end,
	}
	return ns, sources
end

-- An event Hunt over the fixture's Darkshore event, its fields `fields`.
local function eventHunt(ns, fields)
	fields.id = fields.id or "spec_hunt"
	fields.tiers = fields.tiers or { 1 }
	return ns.NewEventHunt(fields, { id = "spec_event", zones = { C.DARKSHORE } })
end

describe("an event Hunt's shape (HNT-R163, default chosen while building)", function()
	it('is "Timed" with a time condition, whatever else it has', function()
		local ns = load()
		local hunt = eventHunt(ns, { class = "species.any", minBand = 2, conditions = { time = { { 1320, 240 } } } })
		assert.are.equal("timed", ns.EventHuntShape(hunt))
	end)

	it('is "Big ones" with a minBand, "Quality" for a quality class, "Haul" for any fish, else "Named fish"', function()
		local ns = load()
		assert.are.equal("big", ns.EventHuntShape(eventHunt(ns, { species = C.NIGHTFIN, minBand = 2 })))
		assert.are.equal("quality", ns.EventHuntShape(eventHunt(ns, { class = "quality.uncommon" })))
		assert.are.equal("quality", ns.EventHuntShape(eventHunt(ns, { class = "quality.rare" })))
		assert.are.equal("haul", ns.EventHuntShape(eventHunt(ns, { class = "species.any" })))
		assert.are.equal("named", ns.EventHuntShape(eventHunt(ns, { species = C.NIGHTFIN })))
		assert.are.equal("named", ns.EventHuntShape(eventHunt(ns, { class = "fixed.oddity" })))
	end)
end)

describe("an event Hunt's line (HNT-R163, HNT-R53, HNT-R54)", function()
	it("reads its shape, its target line and its time words", function()
		local ns, sources = load()
		local grouper = eventHunt(ns, { species = C.NIGHTFIN, conditions = { time = { { 1320, 240 } } } })
		local big = eventHunt(ns, { species = C.BLACKMOUTH, minBand = 2 })
		local two = eventHunt(ns, { class = "species.any", conditions = { time = { { 0, 60 }, { 300, 360 } } } })

		assert.are.equal("Timed · Raw Nightfin Snapper, 22:00–04:00", ns.EventHuntLine(grouper, ns.hunts, sources))
		assert.are.equal("Big ones · Oily Blackmouth, Hefty or better", ns.EventHuntLine(big, ns.hunts, sources))
		assert.are.equal("Timed · Any fish, 00:00–01:00, 05:00–06:00", ns.EventHuntLine(two, ns.hunts, sources))
	end)
end)

describe("the run entry's pay rule (HNT-R163, HNT-R27)", function()
	it("comes from the Tunables, and claims no odds, chance or due fish", function()
		local ns = load()
		ns.XP_EVENT, ns.COINS_EVENT, ns.XP_RUN, ns.COINS_RUN = { 200, 120 }, { 20, 12 }, 300, 60

		local rule = ns.RunPayRule()

		assert.are.equal(
			"Each Hunt's first mark pays +200 XP and 20 Coins, each mark after it +120 XP and 12 Coins. "
				.. "Land every Hunt's first mark and the wager settles: +300 XP and 60 Coins more.",
			rule
		)
		for _, word in ipairs({ "odds", "chance", "due", "likely", "%%" }) do
			assert.is_nil(rule:lower():find(word))
		end
	end)
end)

-- The Pagle Wagers spread --------------------------------------------------------------------------------------------

local HOUR, DAY = hunts.HOUR, 86400
local NOW = SERVER_TIME -- realm 08:15 on Sunday 11 October 2026, at UTC (hunts.SUNDAY)

-- One of ns.RunsShown's runs (HuntsShownRun) of the fixture pool's event `id`, from `start` to `end_`, on or ahead as
-- NOW falls, with `huntsProgress` (by Hunt ID) its progress; `fields` over the run (`source`, `completedAt`).
local function shownRun(ns, id, start, end_, huntsProgress, fields)
	local run = { event = id, start = start, end_ = end_, source = "r", hunts = huntsProgress or {} }
	for key, value in pairs(fields or {}) do
		run[key] = value
	end
	return { key = id .. "@" .. start, run = run, event = ns.events:Event(id), on = start <= NOW }
end

-- logic/Wagers.lua's inputs over `runs` at NOW, with the fixture catalogue's area names.
local function wagersInput(ns, runs, updating)
	return {
		runs = runs,
		now = NOW,
		snapshot = hunts.SUNDAY,
		updating = updating == true,
		list = ns.hunts,
		sources = {
			AreaName = function(areaID)
				return C.NAMES.areas[areaID]
			end,
		},
	}
end

-- A slip's words, as the specs read them.
local function slipWords(slip)
	return { slip.name, slip.where, slip.when, slip.marks }
end

describe("the wager slips on the Pagle Wagers spread (HNT-R162, HNT-R160)", function()
	it("give a run on its name, zones, until, its countdown in red, and its pips with its first marks", function()
		local ns = load()
		local shore = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY + 4 * HOUR, {
			fixture_shore_snapper = hunts.progress({ tiers = 1 }),
			fixture_shore_haul = hunts.progress({ count = 1 }),
		})

		local spread = ns.BuildWagersSpread(wagersInput(ns, { shore }), { settled = 0, ladder = {}, ended = {} })

		assert.are.same(
			{ "Pagle Wagers", "On the table", "Three days each. Land every Hunt's first mark before it closes." },
			{ spread.kicker, spread.title, spread.note }
		)
		assert.is_nil(spread.empty)
		assert.are.equal(1, #spread.slips)
		local slip = spread.slips[1]
		-- HNT-R50, HNT-R203: a server-time countdown, and the end in realm time.
		assert.are.same(
			{ "Shore Wager", "Darkshore · until Tue 12:15", "closes in 2d 4h", "1 of 3 first marks" },
			slipWords(slip)
		)
		assert.are.same({ shore.key, "red", true, false }, { slip.run, slip.tone, slip.on, slip.closed })
		assert.are.same({ false, true, false }, slip.pips)
		assert.is_nil(slip.settled)
		assert.is_nil(slip.tag)
		assert.are.equal(shore.key, spread.selected) -- the first slip's run by default
		assert.is_true(slip.selected)
	end)

	it('read "settled" with its stamp once a run is completed, in place of the countdown (HNT-R146)', function()
		local ns = load()
		local done = hunts.progress({ tiers = 1 })
		local shore = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY, {
			fixture_shore_haul = hunts.progress({ tiers = 1 }),
			fixture_shore_snapper = done,
			fixture_shore_oddity = done,
		}, { completedAt = NOW - HOUR })

		local slip = ns.BuildWagersSpread(wagersInput(ns, { shore }), { settled = 1, ladder = {}, ended = {} }).slips[1]

		assert.are.same({ "settled", "3 of 3 first marks" }, { slip.settled, slip.marks })
		assert.is_nil(slip.when)
		assert.are.same({ true, true, true }, slip.pips)
	end)

	it('give a run ahead "opens {weekday} {time}" where a run on has its countdown (default chosen in #303)', function()
		local ns = load()
		local shore = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY)
		local vale = shownRun(ns, "fixture_vale", NOW + 3 * HOUR, NOW + 3 * HOUR + 3 * DAY)

		local slips =
			ns.BuildWagersSpread(wagersInput(ns, { shore, vale }), { settled = 0, ladder = {}, ended = {} }).slips

		assert.are.same({ shore.key, vale.key }, { slips[1].run, slips[2].run }) -- on, then ahead (HNT-R160)
		assert.are.same(
			{ "fixture_vale", "Ashenvale & Elwynn Forest · until Wed 11:15", "opens Sun 11:15", "0 of 3 first marks" },
			slipWords(slips[2])
		)
		assert.are.same({ "note", false }, { slips[2].tone, slips[2].on })
		assert.are.same({ false, false, false }, slips[2].pips)
	end)

	it("put a pushed run's holiday tag in the margin, never a rotation run's, and no other tag", function()
		local ns = load()
		local function tagged(source, tags)
			local shown = shownRun(ns, "fixture_shore", NOW - DAY, NOW + DAY, {}, { source = source })
			local event = {}
			for key, value in pairs(shown.event) do
				event[key] = value
			end
			event.tags = tags
			shown.event = event
			local input = wagersInput(ns, { shown })
			return ns.BuildWagersSpread(input, { settled = 0, ladder = {}, ended = {} }).slips[1].tag
		end

		assert.are.equal("Hallow's End", tagged("p", { "coast", "hallows_end", "low" }))
		assert.are.equal("Feast of Winter Veil", tagged("p", { "winter_veil", "low" }))
		assert.is_nil(tagged("r", { "hallows_end", "low" }))
		assert.is_nil(tagged("p", { "coast", "night", "low" }))
	end)

	it("keep a run that ended this showing, greyed and closed, after the rest, never chosen (HNT-R143)", function()
		local ns = load()
		local shore = shownRun(ns, "fixture_shore", NOW - 3 * DAY, NOW - HOUR, {
			fixture_shore_snapper = hunts.progress({ tiers = 1 }),
		})
		local vale = shownRun(ns, "fixture_vale", NOW - HOUR, NOW + 3 * DAY - HOUR)

		local spread = ns.BuildWagersSpread(
			wagersInput(ns, { vale }),
			{ settled = 0, ladder = {}, ended = { shore }, run = shore.key }
		)

		assert.are.same({ vale.key, shore.key }, { spread.slips[1].run, spread.slips[2].run })
		local closed = spread.slips[2]
		assert.are.same({ "closed", "faded", true, false }, { closed.when, closed.tone, closed.closed, closed.on })
		assert.are.equal("1 of 3 first marks", closed.marks)
		-- The run asked for has closed: the first open slip is chosen in its place.
		assert.are.equal(vale.key, spread.selected)
		assert.is_false(closed.selected)
	end)

	it("choose the slip asked for, else the first slip's run", function()
		local ns = load()
		local shore = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY)
		local vale = shownRun(ns, "fixture_vale", NOW - HOUR, NOW + 3 * DAY)
		local input = wagersInput(ns, { shore, vale })

		local chosen = ns.BuildWagersSpread(input, { settled = 0, ladder = {}, ended = {}, run = vale.key })
		local unknown = ns.BuildWagersSpread(input, { settled = 0, ladder = {}, ended = {}, run = "fixture_vale@1" })

		assert.are.same(
			{ vale.key, false, true },
			{ chosen.selected, chosen.slips[1].selected, chosen.slips[2].selected }
		)
		assert.are.equal(shore.key, unknown.selected)
	end)

	it(
		'read "No wagers on the table yet." with nothing on or ahead, the ladder still at the foot (HNT-R204)',
		function()
			local ns = load()

			local spread = ns.BuildWagersSpread(wagersInput(ns, {}), { settled = 0, ladder = {}, ended = {} })

			assert.are.same({}, spread.slips)
			assert.are.equal("No wagers on the table yet.", spread.empty)
			assert.is_nil(spread.selected)
			assert.are.equal("0 wagers settled · 25 more for Bookmaker's Bane", spread.ladder.line)
		end
	)

	it("read the updating line for the marks, and press no stamp, while the projection updates (HNT-R69)", function()
		local ns = load()
		local shore = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY, {
			fixture_shore_snapper = hunts.progress({ tiers = 1 }),
		}, { completedAt = NOW - HOUR })

		local spread = ns.BuildWagersSpread(wagersInput(ns, { shore }, true), { settled = 3, ladder = {}, ended = {} })

		local slip = spread.slips[1]
		assert.are.equal("Updating from your Catch log…", slip.marks)
		assert.is_nil(slip.pips)
		assert.is_nil(slip.settled)
		assert.are.equal("closes in 2d", slip.when)
		assert.are.same({ "Updating from your Catch log…", 0 }, { spread.ladder.line, spread.ladder.fill })
	end)

	it("claim no odds, chance or due fish in any of their words (HNT-R27)", function()
		local ns = load()
		local shore = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY)
		local vale = shownRun(ns, "fixture_vale", NOW + HOUR, NOW + 3 * DAY)
		local spread = ns.BuildWagersSpread(wagersInput(ns, { shore, vale }), { settled = 0, ladder = {}, ended = {} })
		local words = { spread.kicker, spread.title, spread.note, spread.ladder.line, ns.L.SPREAD_EMPTY }
		for _, slip in ipairs(spread.slips) do
			for _, word in ipairs(slipWords(slip)) do
				words[#words + 1] = word
			end
		end

		for _, text in ipairs(words) do
			for _, word in ipairs({ "odds", "chance", "due", "likely", "luck", "%%" }) do
				assert.is_nil(text:lower():find(word), text)
			end
		end
	end)
end)

describe("the ladder at the spread's foot (HNT-R148, HNT-R162)", function()
	-- The ladder for `settled` completed runs and the steps earned in `ladder`.
	local function ladderAt(settled, ladder, updating)
		return load().BuildWagersLadder(settled, ladder or {}, updating)
	end
	-- The titles at 50 and 100, the lore's (#307) as ns.LadderTitle reads them.
	local RUIN, BREAKER = load().LadderTitle(50), load().LadderTitle(100)

	it("has three marks at 25, 50 and 100, each with its title, and the bar toward the next", function()
		local ladder = ladderAt(0)

		assert.are.same({
			{ step = 25, title = "Bookmaker's Bane", reached = false },
			{ step = 50, title = RUIN, reached = false },
			{ step = 100, title = BREAKER, reached = false },
		}, ladder.marks)
		assert.are.same({ 0, "0 wagers settled · 25 more for Bookmaker's Bane" }, { ladder.fill, ladder.line })
	end)

	it("counts one wager settled in the singular", function()
		assert.are.equal("1 wager settled · 24 more for Bookmaker's Bane", ladderAt(1).line)
	end)

	it("marks an earned step reached, and fills toward the next mark", function()
		local ladder = ladderAt(30, { [25] = NOW })

		assert.are.same(
			{ true, false, false },
			{ ladder.marks[1].reached, ladder.marks[2].reached, ladder.marks[3].reached }
		)
		assert.are.same({ 30 / 50, "30 wagers settled · 20 more for " .. RUIN }, { ladder.fill, ladder.line })
	end)

	it('reads only "{count} wagers settled" past the last mark, its bar full (default chosen in #303)', function()
		local ladder = ladderAt(104, { [25] = NOW, [50] = NOW, [100] = NOW })

		assert.are.same({ 1, "104 wagers settled" }, { ladder.fill, ladder.line })
	end)
end)
