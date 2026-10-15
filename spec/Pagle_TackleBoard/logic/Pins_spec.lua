-- What the pins show (TKB-R44, TKB-R55, TKB-R101, TKB-R102, TKB-R104, TKB-R105, TKB-R108, TKB-R109, TKB-R121): each
-- pinned goal's lines, the empty pins' texts and which goals the board lays out where, decided by logic/Pins.lua, on
-- FakePagle over the fixture catalogue with the fake client's names and the support's reset API (a US realm at
-- UTC-7; the fake's clock starts Sunday 11 October 2026 15:15 UTC, 15 minutes into the board day).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DUROTAR, DARKSHORE, BARRENS = 14, 148, 17
local MACKEREL, BLACKMOUTH, MIGHTFISH, LARGE_MIGHTFISH, REMOVED_FISH = 6303, 6358, 13754, 13893, 92003
local KALIMDOR = 1

-- A goal on the board (TackleGoal): a Notice or an Expedition of `kind`, open, with no progress, posted at the fake's
-- start. `fields` changes any of it.
local function goal(goalType, kind, fields)
	local g = {
		id = "Player-1-0A-1791731747-0",
		seq = 5,
		type = goalType,
		kind = kind,
		tier = goalType == "e" and 0 or 2,
		pay = goalType == "e" and 60 or 15,
		need = 30,
		reposted = false,
		pin = 1,
		issuedDay = 0,
		time = SERVER_TIME,
		progress = 0,
		seen = {},
	}
	for key, value in pairs(fields or {}) do
		g[key] = value
	end
	return g
end

-- The Tackle Board loaded, its client knowing the fixture's names.
local function loadNamed()
	local loaded, fake = board.load()
	loaded.client.areaNames[DUROTAR] = "Durotar"
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	loaded.client.mapNames[1414] = "Kalimdor"
	loaded.client.itemNames[MACKEREL] = "Longjaw Mud Snapper"
	loaded.client.itemNames[BLACKMOUTH] = "Oily Blackmouth"
	loaded.client.itemNames[MIGHTFISH] = "Mightfish"
	return loaded.ns, loaded, fake
end

-- What a pin shows for `g`, with the view's context: no Session, in The Barrens, not updating, can't be taken down,
-- unless `ctx` says otherwise.
local function view(ns, g, ctx)
	local context = { session = nil, zone = BARRENS, updating = false, canTakeDown = false }
	for key, value in pairs(ctx or {}) do
		context[key] = value
	end
	return ns.PinView(g, context)
end

describe("a pinned goal's lines (TKB-R102)", function()
	it('shows a Notice\'s kind, text, "0 of N" over an empty bar, where, and "pays N Coins"', function()
		local ns = loadNamed()

		local shown = view(ns, goal("n", "haul", { need = 30, target = DUROTAR, pay = 15 }))

		assert.are.equal("Haul", shown.kicker)
		assert.are.equal("30 Catches in Durotar", shown.text)
		assert.are.equal("0 of 30", shown.progress)
		assert.are.equal(0, shown.fill)
		assert.are.equal("Durotar", shown.where)
		assert.is_false(shown.here)
		assert.are.equal("pays 15 Coins", shown.pay)
		assert.is_nil(shown.seal)
		assert.is_false(shown.stamp)
		assert.is_nil(shown.stranded)
	end)

	it('fills the ink bar with the progress over the need ("12 of 30")', function()
		local ns = loadNamed()

		local shown = view(ns, goal("n", "haul", { need = 30, target = DUROTAR, progress = 12 }))

		assert.are.equal("12 of 30", shown.progress)
		assert.are.equal(0.4, shown.fill)
	end)

	it('seals an Expedition\'s poster with its pay ("60")', function()
		local ns = loadNamed()

		local shown = view(ns, goal("e", "haul", { need = 150, target = DUROTAR, pay = 60 }))

		assert.are.equal("60", shown.seal)
		assert.are.equal("pays 60 Coins", shown.pay)
		assert.are.equal("0 of 150", shown.progress)
	end)

	it('reads "1 Coin" for a pay of one', function()
		local ns = loadNamed()

		assert.are.equal("pays 1 Coin", view(ns, goal("n", "lure", { pay = 1, need = 3 })).pay)
	end)

	it('reads "wherever it bites" for a Species goal and "anywhere" for a goal tied to no place', function()
		local ns = loadNamed()

		assert.are.equal("wherever it bites", view(ns, goal("n", "species", { target = BLACKMOUTH })).where)
		assert.are.equal("anywhere", view(ns, goal("n", "lure", { need = 3 })).where)
	end)
end)

describe('"I\'m here" (TKB-R102, TKB-R121)', function()
	it("marks a Haul goal in the current zone, and not in another", function()
		local ns = loadNamed()
		local haul = goal("n", "haul", { target = DUROTAR })

		assert.is_true(view(ns, haul, { zone = DUROTAR }).here)
		assert.is_false(view(ns, haul, { zone = BARRENS }).here)
	end)

	it("marks a Wanderer Expedition on the current zone's continent", function()
		local ns = loadNamed()

		local shown = view(ns, goal("e", "wanderer", { need = 5, target = KALIMDOR }), { zone = DUROTAR })

		assert.is_true(shown.here)
		assert.are.equal("Kalimdor", shown.where)
	end)

	it("never marks a goal tied to no place, workable everywhere as it is", function()
		local ns = loadNamed()

		assert.is_false(view(ns, goal("n", "lure", { need = 3 }), { zone = DUROTAR }).here)
	end)

	it("marks nothing in zone 0", function()
		local ns = loadNamed()

		assert.is_false(view(ns, goal("n", "haul", { target = DUROTAR }), { zone = 0 }).here)
	end)
end)

describe("a session-bound goal's progress (TKB-R104, TKB-R41)", function()
	local function wanderer()
		return goal("n", "wanderer", { need = 2, progress = 1, session = "S1" })
	end

	it('reads "1 of 2 this Session" while its Session is the current one', function()
		local ns = loadNamed()

		local shown = view(ns, wanderer(), { session = { id = "S1" } })

		assert.are.equal("1 of 2 this Session", shown.progress)
		assert.are.equal(0.5, shown.fill)
	end)

	it('reads "0 of 2 this Session" once its Session has ended, or another is open', function()
		local ns = loadNamed()

		assert.are.equal("0 of 2 this Session", view(ns, wanderer(), { session = nil }).progress)
		assert.are.equal("0 of 2 this Session", view(ns, wanderer(), { session = { id = "S2" } }).progress)
		assert.are.equal(0, view(ns, wanderer()).fill)
	end)
end)

describe('"take it down" and RE-POSTED (TKB-R55, TKB-R102, TKB-R108)', function()
	it("shows the button, enabled, on a goal that can be taken down", function()
		local ns = loadNamed()

		local shown = view(ns, goal("n", "lure", { need = 3 }), { canTakeDown = true })

		assert.are.equal("enabled", shown.takeDown)
	end)

	it("hides it on a goal that can't be taken down", function()
		local ns = loadNamed()

		assert.are.equal("hidden", view(ns, goal("n", "lure", { need = 3 }), { canTakeDown = false }).takeDown)
	end)

	it("stamps a re-posted goal RE-POSTED, with no button", function()
		local ns = loadNamed()

		local shown = view(ns, goal("n", "lure", { need = 3, reposted = true }), { canTakeDown = false })

		assert.is_true(shown.stamp)
		assert.are.equal("hidden", shown.takeDown)
	end)

	it("disables the button while the projection is updating", function()
		local ns = loadNamed()

		local shown = view(ns, goal("n", "lure", { need = 3 }), { canTakeDown = true, updating = true })

		assert.are.equal("disabled", shown.takeDown)
	end)
end)

describe("a stranded goal (TKB-R44)", function()
	it('reads "no longer catchable", and a re-posted one still shows "take it down" when it can be', function()
		local ns = loadNamed()
		local removed = goal("n", "species", { need = 10, target = REMOVED_FISH, reposted = true })

		local shown = view(ns, removed, { canTakeDown = true })

		assert.are.equal("no longer catchable", shown.stranded)
		assert.is_true(shown.stamp)
		assert.are.equal("enabled", shown.takeDown)
	end)

	it("leaves a goal whose target resolves unmarked", function()
		local ns = loadNamed()

		assert.is_nil(view(ns, goal("n", "species", { need = 10, target = BLACKMOUTH })).stranded)
	end)
end)

describe("a pinned goal's hover (TKB-R102)", function()
	it("shows the realm date and time it was posted, and that only Catches since then count", function()
		local ns = loadNamed()

		-- SERVER_TIME is 15:15 UTC on Sunday 11 October 2026: 08:15 on the UTC-7 realm.
		local shown = view(ns, goal("n", "haul", { target = DUROTAR }))

		assert.are.same({ "Posted Sun 11 Oct, 08:15", "Only my Catches since then count" }, shown.hover)
		assert.is_nil(shown.species)
	end)

	it("adds that they all fall within one Session for a session-bound goal", function()
		local ns = loadNamed()

		local shown = view(ns, goal("n", "collector", { need = 2 }))

		assert.are.equal("Only my Catches since then count, all within one Session", shown.hover[2])
	end)

	it("lists a Variety Expedition's Species, caught ones ticked, leaving out a removed one (TKB-R44)", function()
		local ns = loadNamed()
		local variety = goal("e", "variety", {
			need = 4,
			target = DARKSHORE,
			items = { MACKEREL, BLACKMOUTH, MIGHTFISH, REMOVED_FISH },
			progress = 1,
			seen = { [MIGHTFISH] = true },
		})

		local shown = view(ns, variety)

		assert.are.same({
			{ name = "Longjaw Mud Snapper", caught = false },
			{ name = "Oily Blackmouth", caught = false },
			{ name = "Mightfish", caught = true },
		}, shown.species)
		assert.are.equal("1 of 3", shown.progress)
	end)

	it("ticks a Species by its own ID, whichever of its items was caught", function()
		local ns = loadNamed()
		local variety = goal("e", "variety", {
			need = 1,
			target = DARKSHORE,
			items = { LARGE_MIGHTFISH },
			seen = { [MIGHTFISH] = true },
		})

		assert.is_true(view(ns, variety).species[1].caught)
	end)
end)

-- A started board's state with `goals` in it: each on the pin it names (`pin`), or, with `pin = false`, unpinned in
-- the overflow strip (a completed one off the board).
local function stateWith(ns, goals)
	local state = ns.NewBoardState()
	state.started = { seq = 1, time = SERVER_TIME }
	for _, g in ipairs(goals) do
		if g.pin == false then
			g.pin = nil
		end
		state.goals[g.id] = g
		if g.pin then
			local pins = g.type == "e" and state.pins.expeditions or state.pins.notices
			pins[g.pin] = g.id
		end
	end
	return state
end

-- A layout's row: each pin's goal ID, or its empty pin's text.
local function row(pins)
	local out = {}
	for i, pin in ipairs(pins) do
		out[i] = pin.goal and pin.goal.id or pin.empty
	end
	return out
end

describe("the board's layout (TKB-R101)", function()
	it("puts each open goal on its pin, and the unpinned ones in the overflow strip by seq", function()
		local ns = loadNamed()
		local state = stateWith(ns, {
			goal("e", "haul", { id = "E1", seq = 2, pin = 2, target = DUROTAR }),
			goal("n", "lure", { id = "N1", seq = 3, pin = 1 }),
			goal("n", "lure", { id = "N2", seq = 4, pin = 3 }),
			goal("n", "lure", { id = "N9", seq = 9, pin = false }),
			goal("n", "lure", { id = "N7", seq = 7, pin = false }),
			goal("e", "haul", { id = "E8", seq = 8, pin = false, target = DUROTAR }),
		})

		local layout = ns.PinLayout(state, ns.api)

		assert.are.equal("E1", layout.expeditions[2].goal.id)
		assert.is_nil(layout.expeditions[1].goal)
		assert.are.same({ "N1", "N2" }, { layout.notices[1].goal.id, layout.notices[3].goal.id })
		local overflow = {}
		for i, g in ipairs(layout.overflow) do
			overflow[i] = g.id
		end
		assert.are.same({ "N7", "E8", "N9" }, overflow)
	end)

	it("labels an overflow goal's chip with its kind and text, and counts what the strip can't show", function()
		local ns = loadNamed()

		assert.are.equal("Lure: 3 Catches with a lure on", view(ns, goal("n", "lure", { need = 3 })).chip)
		assert.are.equal("+2 more waiting for a pin", ns.OverflowMore(2))
	end)

	it("leaves a completed goal off the board", function()
		local ns = loadNamed()
		local state = stateWith(ns, { goal("n", "lure", { id = "N1", pin = false, doneDay = 0 }) })

		assert.are.same({}, ns.PinLayout(state, ns.api).overflow)
	end)
end)

describe("the empty pins (TKB-R105)", function()
	it("read the countdown to the daily reset on the first 3 empty Notice pins, and later resets after", function()
		local ns = loadNamed()
		local state = stateWith(ns, { goal("n", "lure", { id = "N1", pin = 2 }) })

		-- 15:15 UTC: the daily reset at 15:00 UTC is 23 h 45 min away, whole hours rounded down.
		assert.are.same({
			"A fresh Notice at reset (in 23h)",
			"N1",
			"A fresh Notice at reset (in 23h)",
			"A fresh Notice at reset (in 23h)",
			"More Notices at later resets",
			"More Notices at later resets",
		}, row(ns.PinLayout(state, ns.api).notices))
	end)

	it("count whole minutes under an hour, read live from the API", function()
		local ns, _, fake = loadNamed()
		fake.wait(23 * 3600 + 20 * 60) -- 14:35 UTC the next day: 25 minutes to the reset

		local notices = row(ns.PinLayout(stateWith(ns, {}), ns.api).notices)

		assert.are.equal("A fresh Notice at reset (in 25m)", notices[1])
	end)

	it(
		"read the weekly reset's realm weekday on the first empty Expedition pin, the one after on the second",
		function()
			local ns = loadNamed()

			-- The weekly reset is Tuesday 13 October 15:00 UTC: Tuesday 08:00 on the realm.
			assert.are.same({
				"Next Expedition at the weekly reset (Tue)",
				"Another at the weekly reset after",
			}, row(ns.PinLayout(stateWith(ns, {}), ns.api).expeditions))
		end
	)

	it("name the realm's weekday, not UTC's, where they differ", function()
		-- A weekly reset at Tuesday 03:00 UTC is Monday 20:00 on the UTC-7 realm.
		local early = board.WEEKLY_RESET - 12 * 3600
		local loaded = board.load(nil, {
			api = board.resetAPI(nil, {
				weekly = function()
					return early - SERVER_TIME
				end,
			}),
		})
		local ns = loaded.ns

		assert.are.equal(
			"Next Expedition at the weekly reset (Mon)",
			ns.PinLayout(stateWith(ns, {}), ns.api).expeditions[1].empty
		)
	end)

	it("give the first empty Expedition pin's text to the second pin when the first is taken", function()
		local ns = loadNamed()
		local state = stateWith(ns, { goal("e", "haul", { id = "E1", pin = 1, target = DUROTAR }) })

		assert.are.same(
			{ "E1", "Next Expedition at the weekly reset (Tue)" },
			row(ns.PinLayout(state, ns.api).expeditions)
		)
	end)
end)

describe("the highlight (TKB-R109)", function()
	it("highlights an open goal's ID, and nothing for a completed or unknown one", function()
		local ns = loadNamed()
		local state = stateWith(ns, {
			goal("n", "lure", { id = "N1", pin = 1 }),
			goal("n", "lure", { id = "N2", pin = false, doneDay = 0 }),
		})

		assert.are.equal("N1", ns.HighlightedGoal(state, "N1"))
		assert.is_nil(ns.HighlightedGoal(state, "N2"))
		assert.is_nil(ns.HighlightedGoal(state, "N3"))
		assert.is_nil(ns.HighlightedGoal(state, nil))
	end)
end)
