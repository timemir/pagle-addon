-- The Tackle Board's projection (TKB-R2, TKB-R6, TKB-R12, TKB-R14, TKB-R20–R23, TKB-R57, TKB-R80–R82, TKB-R101,
-- TKB-R194, TKB-R197, TKB-R198; LOG-R70–R76) on FakePagle over the fixture catalogue: a history of Casts and the
-- board's own Module records appended with fake.catchLog:Append, then login and the first PLAYER_ENTERING_WORLD,
-- then live records through M:AppendRecord. Every expected value is worked out by hand from the rules.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, start, day, issue, reroll, idAt, cast, join, copy, withHistory, built =
	board.record,
	board.start,
	board.day,
	board.issue,
	board.reroll,
	board.idAt,
	board.cast,
	board.join,
	board.copy,
	board.withHistory,
	board.built

local DAY, WEEK = board.DAY, board.WEEK
local W = board.WEEK0 -- Tuesday 6 October 2026 15:00 UTC: the weekly reset week 0 starts at
local D0 = board.DAY0 -- Wednesday 7 October 15:00 UTC: board day 0, the start record's day
local DUROTAR, BARRENS = 14, 17

-- Goal payloads (Data): three Notices and an Expedition, then spares.
local N1, N2, N3 = "n;haul;2;15;30;14", "n;quality;1;10;3;2", "n;lure;3;20;25;"
local N4, N5, N6 = "n;size;1;10;3;3", "n;haul;1;10;20;17", "n;species;2;15;10;6358"
local N7, N8 = "n;wanderer;3;20;3;", "n;collector;2;15;2;"
local E1, E2 = "e;size;0;60;1;4", "e;haul;0;60;150;17"

-- The board after day 0's start: three Notices and an Expedition issued.
local STARTED = {
	start(D0 + 3600),
	issue(D0 + 3601, E1),
	issue(D0 + 3602, N1),
	issue(D0 + 3603, N2),
	issue(D0 + 3604, N3),
}

-- An unstarted board's state, with `zones` and `caught` (tackle-board.md › Projection).
local function unstarted(zones, caught)
	return {
		day = 0,
		week = 0,
		owed = { notices = 0, expeditions = 0 },
		pins = { expeditions = { false, false }, notices = { false, false, false, false, false, false } },
		goals = {},
		tally = { notices = 0, expeditions = 0 },
		coins = 0,
		flies = {},
		titles = {},
		fire = { count = 0, kindling = 0, longest = 0, milestones = {}, log = {} },
		zones = zones or {},
		caught = caught or {},
	}
end

-- The IDs of `ns.BoardOrder(state)`.
local function orderOf(ns)
	local ids = {}
	for i, goal in ipairs(ns.BoardOrder(ns.State())) do
		ids[i] = goal.id
	end
	return ids
end

describe("the Tackle Board's projection", function()
	describe("before Start (TKB-R2)", function()
		it("learns zone recency and every item caught from Casts, and nothing else", function()
			local ns = built(withHistory({
				cast(D0, DUROTAR, { 6358, 92011 }),
				cast(D0 + 60, BARRENS), -- got away: the zone still counts as fished
				cast(D0 + 120, 0, { 6359 }), -- zone 0: never a zone, its item still caught
				cast(D0 + 180, DUROTAR, { 6358, 0 }), -- item 0 is no item
				issue(D0 + 200, N1), -- a record before the start record changes nothing (TKB-R6)
				day(D0 + 300, D0 + DAY, W),
			}))

			assert.are.same(
				unstarted(
					{ [DUROTAR] = D0 + 180, [BARRENS] = D0 + 60 },
					{ [6358] = true, [92011] = true, [6359] = true }
				),
				ns.State()
			)
			assert.is_false(ns.IsStarted())
		end)
	end)

	describe("the start record (TKB-R6, TKB-R20, TKB-R21, TKB-R71, TKB-R101)", function()
		it("starts day 0 and week 0, owes 3 Notices and an Expedition, and lights 2 Kindling", function()
			local ns = built(withHistory({ start(D0 + 3600) }))

			local state = ns.State()
			assert.are.same({ seq = 1, time = D0 + 3600 }, state.started)
			assert.are.same({ seq = 1, day = 0, week = 0, dayStart = D0, weekStart = W }, state.boundary)
			assert.are.same({ notices = 3, expeditions = 1 }, state.owed)
			assert.are.same({ count = 0, kindling = 2, longest = 0, milestones = {}, log = {} }, state.fire)
			assert.is_true(ns.IsStarted())
		end)

		it("puts four issued goals on Notice pins 1–3 and Expedition pin 1, owing nothing more", function()
			local ns = built(withHistory(STARTED))

			local state = ns.State()
			assert.are.same({ notices = 0, expeditions = 0 }, state.owed)
			assert.are.same({ idAt(D0 + 3601), false }, state.pins.expeditions)
			assert.are.same(
				{ idAt(D0 + 3602), idAt(D0 + 3603), idAt(D0 + 3604), false, false, false },
				state.pins.notices
			)
			-- TKB-R21–R23: the goal reads its ID, seq, time, day and definition from its record alone
			assert.are.same({
				id = idAt(D0 + 3602),
				seq = 3,
				time = D0 + 3602,
				issuedDay = 0,
				type = "n",
				kind = "haul",
				tier = 2,
				pay = 15,
				need = 30,
				target = 14,
				reposted = false,
				pin = 1,
				progress = 0,
				seen = {},
			}, state.goals[idAt(D0 + 3602)])
			assert.are.same({ idAt(D0 + 3601), idAt(D0 + 3602), idAt(D0 + 3603), idAt(D0 + 3604) }, orderOf(ns))
		end)

		it("ignores a second start record (TKB-R6)", function()
			local first = built(withHistory(STARTED)).State()

			local ns = built(withHistory(join(STARTED, { start(D0 + 2 * DAY) })))

			assert.are.same(first, ns.State())
		end)

		it("leaves a goal owed when its issue record was lost in a crash (TKB-R194)", function()
			local ns = built(withHistory({ STARTED[1], STARTED[2], STARTED[3], STARTED[5] }))

			assert.are.same({ notices = 1, expeditions = 0 }, ns.State().owed)
		end)
	end)

	describe("advancing through days (TKB-R12, TKB-R14, TKB-R20)", function()
		it("closes the days before a day record three days later and owes Notices up to the cap of 6", function()
			local ns = built(withHistory(join(STARTED, { day(D0 + 3 * DAY + 60, D0 + 3 * DAY, W) })))

			local state = ns.State()
			-- day 0's close owes min(3, 6 − 3 open − 0 owed) = 3; days 1 and 2 add nothing more
			assert.are.same({ notices = 3, expeditions = 0 }, state.owed)
			assert.are.same({ 3, 0 }, { state.day, state.week })
			assert.are.same({ seq = 6, day = 3, week = 0, dayStart = D0 + 3 * DAY, weekStart = W }, state.boundary)
			-- no fire yet: each unlit day is "not lit", and the Kindling stays (TKB-R72)
			assert.are.same({ [0] = "unlit", [1] = "unlit", [2] = "unlit" }, state.fire.log)
			assert.are.equal(2, state.fire.kindling)
		end)

		it(
			"owes an Expedition at the first daily reset at or after a weekly reset, up to 2 (TKB-R14, TKB-R20)",
			function()
				local ns = built(withHistory(join(STARTED, { day(D0 + 14 * DAY + 60, D0 + 14 * DAY, W + 2 * WEEK) })))

				local state = ns.State()
				-- week 1 starts on day 6 (Tuesday 13 October), week 2 on day 13: min(1, 2 − 1 open − 0) = 1, then 0
				assert.are.same({ notices = 3, expeditions = 1 }, state.owed)
				assert.are.same({ 14, 2 }, { state.day, state.week })
			end
		)

		it("raises the week to a day record's own week, one weekly accrual per week risen (TKB-R14)", function()
			-- a day record one day on whose week start is a week later (a switch to the fallback, TKB-R11)
			local ns = built(withHistory(join(STARTED, { day(D0 + DAY + 60, D0 + DAY, W + WEEK) })))

			local state = ns.State()
			assert.are.same({ 1, 1 }, { state.day, state.week })
			assert.are.same({ notices = 3, expeditions = 1 }, state.owed)
		end)

		it("numbers every other entry from the latest boundary record before it (TKB-R12)", function()
			local ns = built(withHistory(join(STARTED, {
				cast(D0 + 2 * DAY + 10, DUROTAR, { 6358 }), -- day 2
				issue(D0 + 2 * DAY + 20, N4),
			})))

			local state = ns.State()
			assert.are.equal(2, state.day)
			assert.are.equal(2, state.goals[idAt(D0 + 2 * DAY + 20)].issuedDay)
		end)

		it("applies an entry stamped before the projection's day on that day (TKB-R14)", function()
			local ns = built(withHistory(join(STARTED, {
				day(D0 + 2 * DAY + 60, D0 + 2 * DAY, W),
				issue(D0 + DAY + 3600, N4), -- the clock stepped back to day 1
			})))

			local state = ns.State()
			assert.are.equal(2, state.day)
			assert.are.equal(2, state.goals[idAt(D0 + DAY + 3600)].issuedDay)
		end)

		it(
			"burns Kindling on unlit days of a burning fire, then puts it out (ns.AdvanceTo, TKB-R14, TKB-R72)",
			function()
				local ns = built(withHistory(STARTED))
				local state = ns.State()
				local advanced = {}
				local outlets = ns.outlets --[[@as table]] -- replaced here, as logic/Moments.lua defines it
				outlets.Advanced = function(result, mode)
					advanced[#advanced + 1] = { result = copy(result), mode = mode }
				end
				state.fire.count, state.fire.longest, state.fire.log[0] = 5, 5, "lit"

				ns.AdvanceTo(state, 3, "live")
				ns.AdvanceTo(state, 5, "live")
				ns.AdvanceTo(state, 4, "live") -- never backwards

				assert.are.same({
					{
						mode = "live",
						result = {
							from = 0,
							to = 3,
							closed = {
								{ day = 0, log = "lit" },
								{ day = 1, log = "burned" },
								{ day = 2, log = "burned" },
							},
							burned = 2,
							wentOut = false,
							count = 5,
							longest = 5,
						},
					},
					{
						mode = "live",
						result = {
							from = 3,
							to = 5,
							closed = { { day = 3, log = "out" }, { day = 4, log = "unlit" } },
							burned = 0,
							wentOut = true,
							count = 0,
							longest = 5,
						},
					},
				}, advanced)
				assert.are.same({ 5, 2, 0 }, { state.day, state.fire.kindling, state.fire.count })
				assert.are.same({ notices = 3, expeditions = 0 }, state.owed)
			end
		)

		it("hands an advance in apply to ns.outlets.Advanced with the apply's mode (TKB-R14)", function()
			local modes = {}
			built(withHistory(join(STARTED, { day(D0 + DAY + 60, D0 + DAY, W) })), {
				prepare = function(loaded)
					loaded.ns.outlets.Advanced = function(result, mode)
						modes[#modes + 1] = ("%s %d-%d"):format(mode, result.from, result.to)
					end
				end,
			})

			assert.are.same({ "rebuild 0-1" }, modes)
		end)
	end)

	describe("pins and the overflow strip (TKB-R101)", function()
		local SEVEN = join(STARTED, {
			issue(D0 + 3605, N4),
			issue(D0 + 3606, N5),
			issue(D0 + 3607, N6),
			issue(D0 + 3608, N7), -- no Notice pin left: the overflow strip
			issue(D0 + 3609, N8),
			issue(D0 + 3610, E2),
		})

		it("hangs a goal with no empty pin of its type in the overflow strip, ordered by seq", function()
			local ns = built(withHistory(SEVEN))

			local state = ns.State()
			assert.is_nil(state.goals[idAt(D0 + 3608)].pin)
			assert.is_nil(state.goals[idAt(D0 + 3609)].pin)
			assert.are.same({ idAt(D0 + 3601), idAt(D0 + 3610) }, state.pins.expeditions)
			assert.are.same({
				idAt(D0 + 3601),
				idAt(D0 + 3610),
				idAt(D0 + 3602),
				idAt(D0 + 3603),
				idAt(D0 + 3604),
				idAt(D0 + 3605),
				idAt(D0 + 3606),
				idAt(D0 + 3607),
				idAt(D0 + 3608),
				idAt(D0 + 3609),
			}, orderOf(ns))
		end)

		it("gives a freed pin to the first goal of its type waiting in the strip (ns.FreePin)", function()
			local ns = built(withHistory(SEVEN))
			local state = ns.State()
			local done = state.goals[idAt(D0 + 3603)]
			done.doneDay = 0 -- as a completion marks it (#232), before freeing its pin

			ns.FreePin(state, done)

			assert.is_nil(done.pin)
			assert.are.equal(idAt(D0 + 3608), state.pins.notices[2])
			assert.are.equal(2, state.goals[idAt(D0 + 3608)].pin)
			assert.is_nil(state.goals[idAt(D0 + 3609)].pin)
		end)

		it("gives a freed pin no goal waits for to the next goal issued", function()
			local ns = built(withHistory(STARTED))
			local state = ns.State()
			local done = state.goals[idAt(D0 + 3603)]
			done.doneDay = 0
			ns.FreePin(state, done)
			assert.are.same({ idAt(D0 + 3602), false, idAt(D0 + 3604), false, false, false }, state.pins.notices)
		end)
	end)

	describe("rerolls (TKB-R55, TKB-R57)", function()
		it("replace an open goal in its pin with the re-posted new goal", function()
			local ns = built(withHistory(join(STARTED, { reroll(D0 + 7200, idAt(D0 + 3603), N4) })))

			local state = ns.State()
			local new = state.goals[idAt(D0 + 7200)]
			assert.is_nil(state.goals[idAt(D0 + 3603)])
			assert.are.same({ true, 2, 6, "size" }, { new.reposted, new.pin, new.seq, new.kind })
			assert.are.equal(idAt(D0 + 7200), state.pins.notices[2])
			assert.are.same({ notices = 0, expeditions = 0 }, state.owed)
		end)

		it("apply even to a re-posted goal: the once rule is the button's (TKB-R57)", function()
			local ns = built(withHistory(join(STARTED, {
				reroll(D0 + 7200, idAt(D0 + 3603), N4),
				reroll(D0 + 7300, idAt(D0 + 7200), N5),
			})))

			assert.are.equal(idAt(D0 + 7300), ns.State().pins.notices[2])
		end)

		it("keep a re-posted goal in the overflow strip when the old one waited there (TKB-R101)", function()
			local ns = built(withHistory(join(STARTED, {
				issue(D0 + 3605, N4),
				issue(D0 + 3606, N5),
				issue(D0 + 3607, N6),
				issue(D0 + 3608, N7),
				reroll(D0 + 7200, idAt(D0 + 3608), N8),
			})))

			local new = ns.State().goals[idAt(D0 + 7200)]
			assert.are.same({ true, nil }, { new.reposted, new.pin })
		end)

		it("ignore the whole record for an unknown or completed goal", function()
			local fake = withHistory(STARTED)
			local ns = built(fake)
			local state = ns.State()
			state.goals[idAt(D0 + 3603)].doneDay = 0
			ns.FreePin(state, state.goals[idAt(D0 + 3603)])
			local before = copy(state)

			ns.Module:AppendRecord("reroll", idAt(D0 + 3603) .. ";" .. N4)
			ns.Module:AppendRecord("reroll", "Player-1-00000001-1-0;" .. N5)

			assert.are.same(before, ns.State())
		end)

		it("leave the old goal open and still rerollable when the reroll record was lost (TKB-R194)", function()
			local ns = built(withHistory(STARTED))

			local old = ns.State().goals[idAt(D0 + 3603)]
			assert.are.same({ false, 2 }, { old.reposted, old.pin })
		end)
	end)

	describe("skipped records (TKB-R80)", function()
		it("skip an unknown kind and an out-of-range payload", function()
			local first = built(withHistory(STARTED)).State()

			local ns = built(withHistory(join(STARTED, {
				record("issue2", D0 + 2 * DAY, N4),
				issue(D0 + 2 * DAY + 1, "n;haul;7;15;30;14"),
				record("day", D0 + 2 * DAY + 2, "x;1"),
			})))

			assert.are.same(first, ns.State())
		end)
	end)

	-- A history over three board weeks: Casts, a goal issued on day 1, a reroll on day 3, an Expedition on day 8.
	local HISTORY = join(STARTED, {
		cast(D0 + 7200, DUROTAR, { 6358 }),
		day(D0 + DAY + 60, D0 + DAY, W),
		issue(D0 + DAY + 61, N4),
		cast(D0 + 3 * DAY, BARRENS),
		reroll(D0 + 3 * DAY + 10, idAt(D0 + 3603), N5),
		day(D0 + 8 * DAY + 60, D0 + 8 * DAY, W + WEEK),
		issue(D0 + 8 * DAY + 61, E2),
		cast(D0 + 8 * DAY + 100, 0, { 92011 }),
		issue(D0 + 15 * DAY, N6), -- no day record since day 8: day 15, across another weekly reset
	})

	-- The next login on the same machine: a new FakePagle over `log` (a PagleLog table) and PagleTackleBoardDB's
	-- global as saved, with Core's Session rules version `options.sessionRules` (default Core's own).
	local function nextLogin(log, global, options)
		options = options or {}
		local fake = newFakePagle()
		fake.catchLog.data = log
		if options.sessionRules then
			fake.Pagle.SESSION_RULES_VERSION = options.sessionRules
		end
		fake.globals.PagleTackleBoardDB = { global = global }
		return (built(fake, options))
	end

	-- A first login over HISTORY, then the saved projection marked (its Coins set to 999), so the next login shows
	-- whether it caught up on the saved state (the mark stays) or rebuilt from seq 0 (it's gone). Returns the PagleLog
	-- data, the PagleTackleBoardDB global the next login loads, and the state the first built.
	local function savedMarked()
		local fake = withHistory(HISTORY)
		local ns, loaded = built(fake)
		local first = copy(ns.State())
		local global = loaded.env.PagleTackleBoardDB.global
		global.board.projection.coins = 999
		return fake.catchLog.data, global, first
	end

	describe("purity and rebuilds (TKB-R81, TKB-R82)", function()
		it("gives the same state rebuilt twice and applied live with the live step's advance between", function()
			local ns = built(withHistory(HISTORY))
			local rebuilt = copy(ns.State())
			ns.projection:Rebuild()
			local again = copy(ns.State())

			local fake = withHistory({})
			local live = built(fake)
			for _, entry in ipairs(HISTORY) do
				local state = live.State()
				if state.started then
					live.AdvanceTo(state, live.DayOf(state.boundary, entry.time) or 0, "live") -- the live step (TKB-R13)
				end
				fake.live(fake.catchLog:Append(entry))
			end

			-- by hand: day 0's close owes 3 Notices, N4 takes one (4 open, 2 owed: the cap); week 1 (day 6) owes an
			-- Expedition, E2 takes it (2 open: the cap, so week 2 adds none); N6 on day 15 takes a Notice
			assert.are.same({ 15, 2 }, { rebuilt.day, rebuilt.week })
			assert.are.same({ notices = 1, expeditions = 0 }, rebuilt.owed)
			assert.are.same(rebuilt, again)
			assert.are.same(rebuilt, live.State())
		end)

		it("catches up on the saved state when nothing changed (LOG-R71)", function()
			local log, global = savedMarked()

			local ns = nextLogin(log, global)

			assert.are.equal(999, ns.State().coins)
			assert.are.equal(1001, global.board.rulesVersion) -- TKB_RULES_VERSION × 1000 + SESSION_RULES_VERSION
		end)

		it("rebuilds to the same state when TKB_RULES_VERSION changes", function()
			local log, global, first = savedMarked()

			local ns = nextLogin(log, global, {
				prepare = function(loaded)
					loaded.ns.TKB_RULES_VERSION = 2
				end,
			})

			assert.are.same(first, ns.State())
			assert.are.equal(2001, global.board.rulesVersion)
		end)

		it("rebuilds to the same state when Pagle.SESSION_RULES_VERSION changes (TKB-R41)", function()
			local log, global, first = savedMarked()

			local ns = nextLogin(log, global, { sessionRules = 2 })

			assert.are.same(first, ns.State())
			assert.are.equal(1002, global.board.rulesVersion)
		end)

		it(
			"rebuilds an unstarted board over a new dev log: each log keeps its own board (TKB-R197, TKB-R198)",
			function()
				local _, global = savedMarked()
				local fake = withHistory({ cast(D0 + 20 * DAY, BARRENS, { 6359 }) })
				fake.globals.PagleTackleBoardDB = { global = global }

				local ns = built(fake)

				assert.are.same(unstarted({ [BARRENS] = D0 + 20 * DAY }, { [6359] = true }), ns.State())
				assert.is_false(ns.IsStarted())
			end
		)
	end)

	describe("the seams (TKB-R81, logic/Seams.lua)", function()
		it("ns.State, ns.IsUpdating and ns.IsStarted follow the projection", function()
			local loaded, fake = board.load(withHistory(STARTED))
			local ns = loaded.ns
			fake.login()
			local before = { ns.IsUpdating(), ns.IsStarted() }

			fake.enterWorld()

			assert.are.same({ true, false }, before)
			assert.are.same({ false, true }, { ns.IsUpdating(), ns.IsStarted() })
			assert.are.equal(ns.projection:GetState(), ns.State())
		end)

		it("done calls ns.outlets.Done, ns.ReportCoins, ns.ScheduleLiveStep, then redraws, in that order", function()
			local calls = {}
			local ns = built(withHistory(join(STARTED, { cast(D0 + 7200, DUROTAR, { 6358 }) })), {
				prepare = function(loaded)
					local seams = loaded.ns
					seams.outlets.Done = function(state, info)
						calls[#calls + 1] = ("Done %s %s"):format(
							tostring(state.started ~= nil),
							tostring(info.firstBuild)
						)
					end
					seams.ReportCoins = function()
						calls[#calls + 1] = "ReportCoins"
					end
					seams.ScheduleLiveStep = function()
						calls[#calls + 1] = "ScheduleLiveStep"
					end
					seams.OnRedraw(function(reason)
						calls[#calls + 1] = "Redraw " .. reason
					end)
				end,
			})

			assert.are.same({ "Done true true", "ReportCoins", "ScheduleLiveStep", "Redraw projection" }, calls)
			assert.is_true(ns.IsStarted())
		end)

		it("redraws after a live apply that changes the state, and only then", function()
			local ns = built(withHistory(STARTED))
			local redraws = {}
			ns.OnRedraw(function(reason)
				redraws[#redraws + 1] = reason
			end)

			ns.Module:AppendRecord("start", D0 .. ";" .. W) -- ignored (TKB-R6)
			ns.Module:AppendRecord("issue2", N4) -- skipped (TKB-R80)
			ns.Module:AppendRecord("issue", N4)

			assert.are.same({ "projection" }, redraws)
			assert.are.equal(4, ns.State().goals[ns.State().pins.notices[4]].pin)
		end)
	end)
end)
