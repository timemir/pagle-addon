-- Pagle Wagers on the board as data (HNT-R27, HNT-R53, HNT-R54, HNT-R156, HNT-R162, HNT-R163, HNT-R166, HNT-R167): an
-- event Hunt's shape and its line, the run entry's pay rule, the event mark's layers, the time dial, "needs skill {n}",
-- a holiday's name, and a run's entry with its fit rule. Pure logic, on the fixture event pool's Hunts and stand-in
-- names, at FakePagle's fixed clock (realm 08:15 on Sunday 11 October 2026, at UTC). The spread's left page is
-- spec/Pagle_Hunts/logic/WagersSpread_spec.lua's; the strip, the WAGERS rows and a whole run entry are checked on
-- FakePagle (spec/Pagle_Hunts/adapter/Wagers_spec.lua), and the spread as drawn too (spec/Pagle_Hunts/adapter/
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
			"Each Hunt's first mark pays +200 XP and 20 Coins, each tier after it +120 XP and 12 Coins, and settling "
				.. "the wager +300 XP and 60 Coins more.",
			rule
		)
		for _, word in ipairs({ "odds", "chance", "due", "likely", "%%" }) do
			assert.is_nil(rule:lower():find(word))
		end
	end)
end)

local HOUR, DAY = hunts.HOUR, 86400
local NOW = SERVER_TIME -- realm 08:15 on Sunday 11 October 2026, at UTC (hunts.SUNDAY)

-- What the spread and the entry share ----------------------------------------------------------------------------

describe("the event mark's layers (HNT-R166)", function()
	it("stack the shadow, the time tag's sky, the water tag's water, the ring and a holiday's charm", function()
		local ns = load()

		assert.are.same(
			{ "mark-shadow", "mark-sky-night", "mark-water-coast", "mark-ring", "mark-charm-winter_veil" },
			ns.EventMarkLayers({ "winter_veil", "coast", "night", "high" })
		)
		assert.are.same(
			{ "mark-shadow", "mark-sky-day", "mark-water-lake", "mark-ring" },
			ns.EventMarkLayers({ "lake", "low", "day" })
		)
	end)

	it("draw a plain sky with no time tag, and open water with no water tag", function()
		local ns = load()

		assert.are.same(
			{ "mark-shadow", "mark-sky-plain", "mark-water-river", "mark-ring" },
			ns.EventMarkLayers({ "river" })
		)
		-- the empty box's mark: no tags at all
		assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-ring" }, ns.EventMarkLayers({}))
		assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-ring" }, ns.EventMarkLayers(nil))
	end)

	it("come from the tags alone: events with the same tags share a mark, the first tag of a kind picks", function()
		local ns = load()

		assert.are.same(ns.EventMarkLayers({ "lake", "day", "mid" }), ns.EventMarkLayers({ "day", "lake", "low" }))
		assert.are.same(
			{ "mark-shadow", "mark-sky-dusk", "mark-water-pool", "mark-ring", "mark-charm-midsummer" },
			ns.EventMarkLayers({ "dusk", "pool", "midsummer", "night", "coast", "hallows_end" })
		)
	end)
end)

describe("the time dial (HNT-R167)", function()
	it("shows the share still to go in 36 steps, rounded up, at least 1 while any is left", function()
		local ns = load()
		local length = 72 * HOUR

		assert.are.equal(36, ns.DialStep(length, length))
		assert.are.equal(18, ns.DialStep(length / 2, length))
		assert.are.equal(19, ns.DialStep(length / 2 + 1, length))
		assert.are.equal(1, ns.DialStep(1, length))
		assert.are.equal(1, ns.DialStep(42 * 60, length))
		assert.is_nil(ns.DialStep(0, length))
		assert.is_nil(ns.DialStep(-60, length))
	end)

	it(
		"is red within the closing-note time (3 h, Tunables), grey once settled, empty once closed, dashed ahead",
		function()
			local ns = load()
			local function shown(start, end_, on)
				return { key = "x@" .. start, run = { start = start, end_ = end_ }, on = on }
			end
			local now = 1000000

			assert.are.equal(3 * 3600, ns.WAGER_CLOSING_NOTE)
			assert.are.same(
				{ kind = "on", step = 1, urgent = true, left = "42m" },
				ns.WagerDial(shown(now - 72 * HOUR + 42 * 60, now + 42 * 60, true), now, false, false)
			)
			assert.are.same(
				{ kind = "on", step = 2, urgent = true, left = "3h" },
				ns.WagerDial(shown(now - 69 * HOUR, now + 3 * HOUR, true), now, false, false)
			)
			assert.are.same(
				{ kind = "on", step = 2, urgent = false, left = "3h 1m" },
				ns.WagerDial(shown(now - 69 * HOUR, now + 3 * HOUR + 60, true), now, false, false)
			)
			assert.are.same(
				{ kind = "settled", step = 1, urgent = false, left = "42m" },
				ns.WagerDial(shown(now - 72 * HOUR + 42 * 60, now + 42 * 60, true), now, true, false)
			)
			assert.are.same(
				{ kind = "closed", urgent = false, left = "closed" },
				ns.WagerDial(shown(now - 72 * HOUR, now - 60, false), now, false, true)
			)
			assert.are.same(
				{ kind = "ahead", urgent = false },
				ns.WagerDial(shown(now + HOUR, now + 73 * HOUR, false), now, false, false)
			)
		end
	)
end)

describe('"needs skill {n}" (HNT-R156)', function()
	it("is the event's skill lower end when it is above the Angler's best, else nothing", function()
		local ns = load()
		local event = { skill = { 276, 300 } }

		assert.are.equal("needs skill 276", ns.EventSkillNeed(event, 275))
		assert.is_nil(ns.EventSkillNeed(event, 276))
		assert.is_nil(ns.EventSkillNeed(event, 300))
		assert.is_nil(ns.EventSkillNeed(event, nil))
	end)
end)

describe("a holiday run's tag (HNT-R162, HNT-R163)", function()
	it("is its holiday tag's full name, and nothing for an event without one", function()
		local ns = load()

		assert.are.equal("Hallow's End", ns.EventHolidayName({ tags = { "coast", "hallows_end", "low" } }))
		assert.are.equal("Feast of Winter Veil", ns.EventHolidayName({ tags = { "winter_veil", "low" } }))
		assert.are.equal(
			"Stranglethorn Fishing Extravaganza",
			ns.EventHolidayName({ tags = { "stv_extravaganza", "coast" } })
		)
		assert.is_nil(ns.EventHolidayName({ tags = { "coast", "night", "low" } }))
	end)
end)

describe("a line in more than one ink", function()
	it("is the locale's line cut at its markers, each run with its ink, empty runs left out", function()
		local ns = load()

		assert.are.same(
			{
				{ text = "17", ink = "count" },
				{ text = " wagers settled · 8 more for ", ink = "line" },
				{ text = "Bookmaker's Bane", ink = "title" },
			},
			ns.InkRuns(
				"\1 wagers settled · 8 more for \2",
				"line",
				{ ["\1"] = { "17", "count" }, ["\2"] = { "Bookmaker's Bane", "title" } }
			)
		)
	end)
end)

-- A run's entry --------------------------------------------------------------------------------------------------

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

-- logic/Wagers.lua's inputs over `runs` at NOW, with the fixture catalogue's area names, the live zone Darkshore, a
-- best skill of 150 and `window` (a Window) as every Hunt's next window.
local function wagersInput(ns, runs, updating, window)
	local snapshot = {}
	for key, value in pairs(hunts.SUNDAY) do
		snapshot[key] = value
	end
	snapshot.zone = C.DARKSHORE
	return {
		runs = runs,
		now = NOW,
		snapshot = snapshot,
		updating = updating == true,
		list = ns.hunts,
		best = 150,
		sources = {
			AreaName = function(areaID)
				return C.NAMES.areas[areaID]
			end,
			ItemName = function(itemID)
				return C.NAMES.items[itemID]
			end,
			NextWindow = window and function()
				return window
			end,
		},
	}
end

describe("a run's entry (HNT-R163)", function()
	-- fixture_shore on from a day ago for three days: the Snapper at its first mark, the Haul at 1 of 2 with 7 Casts.
	local function shore(ns, fields)
		return shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY, {
			fixture_shore_snapper = hunts.progress({ tiers = 1, effort = 3 }),
			fixture_shore_haul = hunts.progress({ count = 1, effort = 7 }),
		}, fields)
	end

	it("reads its kicker, name, mark, time block, chips and note", function()
		local ns = load()

		local entry = ns.BuildRunEntry(wagersInput(ns, {}), shore(ns))

		assert.are.same(
			{ "rotation", "From the rotation · low waters", "Shore Wager" },
			{ entry.source, entry.kicker, entry.name }
		)
		assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-water-coast", "mark-ring" }, entry.mark)
		assert.are.same({
			dial = { kind = "on", step = 24, urgent = false, left = "2d" },
			hand = "closes in 2d",
			ahead = false,
			small = "until Tue 08:15 · 3d in all",
		}, entry.time)
		assert.are.same({ { kind = "zone", text = "Darkshore", here = true, badge = "you're here" } }, entry.chips)
		assert.are.equal("Darkshore's tide, three days long.", entry.note)
		assert.is_nil(entry.seal)
		assert.is_nil(entry.updating)
		assert.is_false(entry.tight)
	end)

	it("gives each Hunt its glyph, line, count in two inks, diamonds in their trims and ink bar", function()
		local ns = load()

		local entry = ns.BuildRunEntry(wagersInput(ns, {}), shore(ns))

		local haul, snapper, oddity = entry.hunts[1], entry.hunts[2], entry.hunts[3]
		assert.are.same(
			{ "haul", "Haul · Any fish", false, { count = "1", rest = " / 2" }, 0.5 },
			{ haul.shape, haul.line, haul.got, haul.count, haul.fill }
		)
		assert.are.same({ { trim = "bronze", reached = false }, { trim = "silver", reached = false } }, haul.tiers)
		assert.are.same(
			{ "named", true, { count = "1", rest = " caught" }, 1 },
			{ snapper.shape, snapper.got, snapper.count, snapper.fill }
		)
		assert.are.same({ { trim = "bronze", reached = true } }, snapper.tiers)
		assert.are.same({ "timed", { count = "0", rest = " / 1" } }, { oddity.shape, oddity.count })
	end)

	it('reads the Casts with the first marks, "Paid so far" and "Settle it", then the pay rule', function()
		local ns = load()

		local entry = ns.BuildRunEntry(wagersInput(ns, {}), shore(ns))

		assert.are.equal("7 Casts in these waters this run · 1 of 3 first marks", entry.casts)
		assert.are.same({
			{ label = "Paid so far", amount = "+150 XP · 15 Coins" },
			{ label = "Settle it", amount = "+250 XP · 50 Coins" },
		}, entry.pay)
		assert.are.equal(ns.RunPayRule(), entry.payRule)
	end)

	it('presses the seal once settled, reads "settled, and still open" and "Settled" over "paid out"', function()
		local ns = load()
		local done = hunts.progress({ tiers = 1, time = NOW - HOUR, date = { year = 2026, month = 10, day = 10 } })
		local shown = shownRun(ns, "fixture_shore", NOW - DAY, NOW + 2 * DAY, {
			fixture_shore_haul = hunts.progress({ tiers = 1, count = 2 }),
			fixture_shore_snapper = done,
			fixture_shore_oddity = done,
		}, { completedAt = NOW - HOUR })

		local entry = ns.BuildRunEntry(wagersInput(ns, {}), shown)

		assert.are.same({ word = "Settled", date = "10 Oct" }, entry.seal)
		assert.are.same({ "settled", "settled, and still open" }, { entry.time.dial.kind, entry.time.hand })
		assert.are.same({ label = "Settled", amount = "paid out" }, entry.pay[2])
		-- three first marks and the settled run: 3 × 150 + 250 XP, 3 × 15 + 50 Coins
		assert.are.same({ label = "Paid so far", amount = "+700 XP · 95 Coins" }, entry.pay[1])
	end)

	it("reads a run ahead's opening with the dashed dial, and has no Casts line and no boxes", function()
		local ns = load()
		local vale = shownRun(ns, "fixture_vale", NOW + 3 * HOUR, NOW + 3 * HOUR + 3 * DAY)

		local entry = ns.BuildRunEntry(wagersInput(ns, {}), vale)

		assert.are.same({
			dial = { kind = "ahead", urgent = false },
			hand = "opens Sun 11:15",
			ahead = true,
			small = "until Wed 11:15 · 3d on the table",
		}, entry.time)
		assert.is_nil(entry.casts)
		assert.is_nil(entry.pay)
		assert.are.same({ "Ashenvale", "Elwynn Forest" }, { entry.chips[1].text, entry.chips[2].text })
	end)

	it('adds a pencilled "needs skill {n}" chip short of skill, then a holiday\'s chip, never in red', function()
		local ns = load()
		local shown =
			withEvent(shore(ns, { source = "p" }), { skill = { 276, 300 }, tags = { "coast", "winter_veil" } })

		local entry = ns.BuildRunEntry(wagersInput(ns, {}), shown)

		assert.are.same({
			{ kind = "zone", text = "Darkshore", here = true, badge = "you're here" },
			{ kind = "skill", text = "needs skill 276" },
			{ kind = "holiday", text = "Feast of Winter Veil" },
		}, entry.chips)
		assert.is_nil(entry.chips[2].short) -- not the Hunt entry's red chip
		assert.are.same({ "companion", "Sent by the companion" }, { entry.source, entry.kicker })
		assert.are.equal("mark-charm-winter_veil", entry.mark[#entry.mark])
	end)

	it("reads a Timed Hunt's window: open now until its close, or when it opens and in how long", function()
		local ns = load()
		local open = { openNow = true, closesAt = NOW + 2 * HOUR }
		local shut = { openNow = false, opensAt = NOW + 2 * HOUR + 50 * 60, closesAt = NOW + 5 * HOUR }

		local opened = ns.BuildRunEntry(wagersInput(ns, {}, false, open), shore(ns))
		local closed = ns.BuildRunEntry(wagersInput(ns, {}, false, shut), shore(ns))

		assert.are.same({ open = true, text = "open now, until 10:15" }, opened.hunts[3].window)
		assert.are.same({ open = false, text = "opens at 11:05, in 2h 50m" }, closed.hunts[3].window)
		-- only a Hunt with a time condition has one
		assert.is_nil(opened.hunts[1].window)
	end)

	it("tightens with five Hunts", function()
		local ns = load()
		local shown = shore(ns)
		local five = {}
		for i = 1, 5 do
			five[i] = shown.event.hunts[(i - 1) % 3 + 1]
		end

		assert.is_true(ns.BuildRunEntry(wagersInput(ns, {}), withEvent(shown, { hunts = five })).tight)
	end)

	it(
		"draws nothing from the projection while it updates: the updating line, no seal, counts, Casts or boxes",
		function()
			local ns = load()
			local shown = shore(ns, { completedAt = NOW - HOUR })

			local entry = ns.BuildRunEntry(wagersInput(ns, {}, true), shown)

			assert.are.equal("Updating from your Catch log…", entry.updating)
			assert.is_nil(entry.seal)
			assert.are.same({ "on", "closes in 2d" }, { entry.time.dial.kind, entry.time.hand })
			for _, hunt in ipairs(entry.hunts) do
				assert.is_nil(hunt.got)
				assert.is_nil(hunt.count)
				assert.is_nil(hunt.tiers)
				assert.is_nil(hunt.fill)
				assert.is_string(hunt.line)
			end
			assert.is_nil(entry.casts)
			assert.is_nil(entry.pay)
		end
	)

	it("claims no odds, chance or due fish in any of its words (HNT-R27)", function()
		local ns = load()
		local entry = ns.BuildRunEntry(wagersInput(ns, {}), shore(ns))
		local words = { entry.kicker, entry.time.hand, entry.time.small, entry.casts, entry.payRule }
		for _, pay in ipairs(entry.pay) do
			words[#words + 1] = pay.label .. " " .. pay.amount
		end

		for _, text in ipairs(words) do
			for _, word in ipairs({ "odds", "chance", "due", "likely", "luck", "%%" }) do
				assert(text:lower():find(word) == nil, text)
			end
		end
	end)
end)

describe("the entry's fit rule (HNT-R163)", function()
	it("leaves nothing out when the entry ends within the limit", function()
		local ns = load()

		local out, ends = ns.RunEntryFit({ ends = 500, rule = 30, casts = 20, windows = 40 }, 512)

		assert.are.same({ { rule = false, casts = false, windows = false }, 500 }, { out, ends })
	end)

	it("leaves out the pay rule first, then the Casts line, then the window lines, until it fits", function()
		local ns = load()
		local sizes = { rule = 30, casts = 20, windows = 40 }
		local function fit(ends)
			sizes.ends = ends
			return (ns.RunEntryFit(sizes, 512))
		end

		assert.are.same({ rule = true, casts = false, windows = false }, fit(530))
		assert.are.same({ rule = true, casts = true, windows = false }, fit(555))
		assert.are.same({ rule = true, casts = true, windows = true }, fit(580))
	end)

	it("skips a part that isn't shown: while updating, the Casts line", function()
		local ns = load()

		local out, ends = ns.RunEntryFit({ ends = 560, rule = 30, casts = 0, windows = 40 }, 512)

		assert.are.same({ { rule = true, casts = false, windows = true }, 490 }, { out, ends })
	end)
end)
