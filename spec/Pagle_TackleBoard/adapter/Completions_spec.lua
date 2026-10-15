-- Completing a goal inside the Tackle Board's projection (TKB-R40, TKB-R45, TKB-R46, TKB-R60–R63, TKB-R70, TKB-R73,
-- TKB-R84, TKB-R101; tackle-board.md › Data: Projection, "Completed goals older than 28 board days"; SHOP-R2) on
-- FakePagle over the fixture catalogue: a history of the board's own records and Casts appended with
-- fake.catchLog:Append, then login and the first PLAYER_ENTERING_WORLD, then live entries through fake.live. Every
-- expected value is worked out by hand from the rules.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DAY, WEEK = 86400, 604800
local W = board.WEEKLY_RESET - WEEK -- Tuesday 6 October 2026 15:00 UTC: the weekly reset week 0 starts at
local D0 = W + DAY -- Wednesday 7 October 15:00 UTC: board day 0, the start record's day
local DUROTAR, BARRENS = 14, 17
local BLACKMOUTH = 6358 -- a Durotar fish of the fixture

-- Goal payloads (Data): a Haul Notice for 20 Catches in Durotar paying 10, Notices and an Expedition done by one
-- Catch in Durotar, and fillers no Durotar Catch counts toward.
local HAUL_20 = "n;haul;1;10;20;14"
local ONE = "n;haul;1;10;1;14"
local ONE_E = "e;haul;0;60;1;14"
local FILLER = "n;haul;2;15;30;17"

-- A Tackle Board Module record for fake.catchLog:Append, by the player's character (1).
local function record(kind, time, payload)
	return { kind = "module", char = 1, time = time, module = "TackleBoard", recordKind = kind, payload = payload }
end

-- A `start` record at `time` on day 0 of week 0.
local function start(time)
	return record("start", time, D0 .. ";" .. W)
end

local function issue(time, payload)
	return record("issue", time, payload)
end

-- The entry ID of the player's entry at `time`, the first at that second (LOG-R13): a goal's ID (TKB-R23), a Cast's.
local function idAt(time)
	return PLAYER_GUID .. "-" .. time .. "-0"
end

-- A Cast record for fake.catchLog:Append: `items` are item IDs (none: got away).
local function cast(time, zone, items)
	local slots = {}
	for i, itemID in ipairs(items or {}) do
		slots[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = items and "caught" or "gotAway",
		conditions = { minute = 600, zone = zone, subzone = 0, skillRank = 150, skillMod = 0, events = {}, auras = {} },
		items = slots,
	}
end

-- `lists` concatenated, in order.
local function join(...)
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, value in ipairs(list) do
			out[#out + 1] = value
		end
	end
	return out
end

-- `n` records made by `make(i)`, i = 1..n.
local function times(n, make)
	local out = {}
	for i = 1, n do
		out[i] = make(i)
	end
	return out
end

-- A new FakePagle whose log has the player's character, then `records`, appended in order.
local function withHistory(records)
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, entry in ipairs(records) do
		fake.catchLog:Append(entry)
	end
	return fake
end

-- The Tackle Board loaded on `fake`, then login and its first PLAYER_ENTERING_WORLD: the projection's first build.
---@return PagleTackleBoardNS ns
---@return LoadedAddon loaded
local function built(fake, options)
	local loaded = board.load(fake, options)
	fake.login()
	fake.enterWorld()
	return loaded.ns, loaded
end

-- Appends `entry` to `fake`'s log and hands it to the projections live (LOG-R73).
local function live(fake, entry)
	fake.live(fake.catchLog:Append(entry))
end

-- A deep copy of a plain table.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in pairs(value) do
		out[key] = copy(inner)
	end
	return out
end

local T = D0 + 3600 -- the start record's time; every record of a spec follows it

describe("completing a goal", function()
	describe("progress in the fold (TKB-R40, TKB-R45)", function()
		-- The start record, Catches in Durotar before the Haul Notice's record, then its record at T + 10.
		local BEFORE = join(
			{ start(T) },
			times(5, function(i)
				return cast(T + i, DUROTAR, { BLACKMOUTH })
			end),
			{ issue(T + 10, HAUL_20) }
		)
		local HAUL = idAt(T + 10)

		it("counts only Catches in its zone after its record, and completes on the 20th, not before", function()
			local fake = withHistory(join(
				BEFORE,
				times(19, function(i)
					return cast(T + 10 + i, DUROTAR, { BLACKMOUTH })
				end),
				{ cast(T + 40, BARRENS, { BLACKMOUTH }) } -- another zone counts nothing
			))
			local ns = built(fake)
			local goal = ns.State().goals[HAUL]
			local before = { goal.progress, goal.doneDay }

			live(fake, cast(T + 50, DUROTAR, { BLACKMOUTH }))

			assert.are.same({ 19, nil }, before)
			assert.are.same(
				{ 20, 0, T + 50, idAt(T + 50) },
				{ goal.progress, goal.doneDay, goal.doneTime, goal.doneCast }
			)
		end)

		it(
			"frees its pin, which a goal waiting in the overflow strip takes before a newly issued one (TKB-R101)",
			function()
				-- the Haul Notice on Notice pin 1, five fillers on pins 2–6, a seventh Notice in the strip
				local fake = withHistory(join(
					BEFORE,
					times(6, function(i)
						return issue(T + 10 + i, FILLER)
					end),
					times(20, function(i)
						return cast(T + 20 + i, DUROTAR, { BLACKMOUTH })
					end)
				))
				local ns = built(fake)

				live(fake, issue(T + 50, FILLER))

				local state = ns.State()
				assert.is_nil(state.goals[HAUL].pin)
				assert.are.same({ 1, nil }, { state.goals[idAt(T + 16)].pin, state.goals[idAt(T + 50)].pin })
				assert.are.same({
					idAt(T + 16),
					idAt(T + 11),
					idAt(T + 12),
					idAt(T + 13),
					idAt(T + 14),
					idAt(T + 15),
				}, state.pins.notices)
			end
		)
	end)

	describe("the ever-caught set (TKB-R46)", function()
		it("reads it as it stood before each Catch, the Cast's earlier Catches and older Casts included", function()
			local JUNK_A, JUNK_B, CONTAINER_A = 92011, 92012, 92021
			local ns = built(withHistory({
				start(T),
				cast(T + 1, DUROTAR, { JUNK_B }), -- caught before the goal: never new to it
				issue(T + 2, "e;collector;0;60;3;"),
				cast(T + 3, DUROTAR, { JUNK_A, JUNK_A, JUNK_B, CONTAINER_A }),
			}))

			local state = ns.State()
			assert.are.same({ 2, nil }, { state.goals[idAt(T + 2)].progress, state.goals[idAt(T + 2)].doneDay })
			assert.are.same({ [JUNK_A] = true, [JUNK_B] = true, [CONTAINER_A] = true }, state.caught)
		end)
	end)

	-- Records each ns.outlets.Completed call on `loaded`'s ns as { goal ID, earned, mode }, before its OnInitialize.
	local function recordCompleted(calls)
		return function(loaded)
			loaded.ns.outlets.Completed = function(goal, completing, earned, mode)
				assert.are.equal(goal.doneCast, completing.id)
				calls[#calls + 1] = { goal.id, copy(earned), mode }
			end
		end
	end

	-- Whether pattern `id` is one of the Fly Box's rare ones (tackle-board.md › Data › Fly Box patterns: the last 6).
	local RARE = {
		nats_golden_doctor = true,
		kraken_ink_streamer = true,
		phoenix_hackle = true,
		moonwell_silverwing = true,
		thunderhead_tiger = true,
		deepwater_duchess = true,
	}

	describe("rewards, in TKB-R60's order", function()
		it(
			"add 1 to the tally and the pay to the Coins, tie a common fly and light the day (TKB-R60–R63, TKB-R70)",
			function()
				local calls = {}
				local ns = built(
					withHistory({ start(T), issue(T + 1, ONE), cast(T + 2, DUROTAR, { BLACKMOUTH }) }),
					{ prepare = recordCompleted(calls) }
				)

				local state = ns.State()
				local goal = state.goals[idAt(T + 1)]
				assert.are.same({ notices = 1, expeditions = 0 }, state.tally)
				assert.are.equal(10, state.coins)
				assert.is_string(goal.fly)
				assert.is_nil(RARE[goal.fly])
				local fly = state.flies[goal.fly]
				assert.are.same({ 0, T + 2, idAt(T + 1), {} }, { fly.day, fly.time, fly.goal.id, fly.goal.seen })
				assert.are.same(
					{ count = 1, kindling = 2, longest = 1, milestones = {}, log = { [0] = "lit" } },
					state.fire
				)
				assert.are.same({}, state.titles)
				assert.are.same({
					{ idAt(T + 1), { pay = 10, coins = 10, fly = goal.fly, titles = {}, lit = true }, "rebuild" },
				}, calls)
			end
		)

		it(
			"complete the goals one Catch brings to their need in board order; the first lights the day (TKB-R45, TKB-R70)",
			function()
				local calls = {}
				-- the Notice is issued first, but the Expedition pins come first in board order (TKB-R101)
				local ns = built(
					withHistory({
						start(T),
						issue(T + 1, ONE),
						issue(T + 2, ONE_E),
						cast(T + 3, DUROTAR, { BLACKMOUTH }),
					}),
					{ prepare = recordCompleted(calls) }
				)

				local state = ns.State()
				assert.are.same({ idAt(T + 2), idAt(T + 1) }, { calls[1][1], calls[2][1] })
				assert.are.same({ true, false }, { calls[1][2].lit, calls[2][2].lit })
				assert.is_true(RARE[state.goals[idAt(T + 2)].fly])
				assert.are.same({ 1, 70 }, { state.fire.count, state.coins })
				assert.are.same({ notices = 1, expeditions = 1 }, state.tally)
			end
		)

		it("grant tally_25 at the 25th goal done, on its board day and Cast (TKB-R60, TKB-R61)", function()
			local calls = {}
			local ns = built(
				withHistory(join(
					{ start(T) },
					times(26, function(i)
						return issue(T + i, ONE)
					end),
					{ cast(T + 100, DUROTAR, { BLACKMOUTH }) }
				)),
				{ prepare = recordCompleted(calls) }
			)

			local state = ns.State()
			assert.are.equal(26, #calls)
			assert.are.same(
				{ {}, { "tally_25" }, {} },
				{ calls[24][2].titles, calls[25][2].titles, calls[26][2].titles }
			)
			assert.are.same({ tally_25 = { day = 0, cast = idAt(T + 100) } }, state.titles)
			assert.are.same({ 26, 260 }, { state.tally.notices, state.coins })
		end)

		it("grant campfire_7 and its 25 Coins on the 7th lit day (TKB-R60, TKB-R63, TKB-R73)", function()
			local calls = {}
			-- a Notice issued and done on each of board days 0–6 (each entry's day from the start record, TKB-R12)
			local ns = built(
				withHistory(join(
					{ start(T) },
					join(unpack(times(7, function(i)
						local t = T + (i - 1) * DAY
						return { issue(t + 1, ONE), cast(t + 2, DUROTAR, { BLACKMOUTH }) }
					end)))
				)),
				{ prepare = recordCompleted(calls) }
			)

			local state = ns.State()
			local last = idAt(T + 6 * DAY + 2)
			assert.are.same({ 7, 7, 3 }, { state.fire.count, state.fire.longest, state.fire.kindling })
			assert.are.same({ [7] = { day = 6, cast = last } }, state.fire.milestones)
			assert.are.same({ campfire_7 = { day = 6, cast = last } }, state.titles)
			assert.are.equal(7 * 10 + 25, state.coins)
			local earned = calls[7][2]
			assert.are.same({ 35, { "campfire_7" }, { days = 7, coins = 25, title = "campfire_7" } }, {
				earned.coins,
				earned.titles,
				earned.milestone,
			})
		end)

		it("grant flybox when the 30th fly fills the box, after the tally title (TKB-R60, TKB-R62)", function()
			local calls = {}
			-- 24 Notices tie the commons, 6 Expeditions the rares; all done by one Catch
			local ns = built(
				withHistory(join(
					{ start(T) },
					times(24, function(i)
						return issue(T + i, ONE)
					end),
					times(6, function(i)
						return issue(T + 30 + i, ONE_E)
					end),
					{ cast(T + 100, DUROTAR, { BLACKMOUTH }) }
				)),
				{ prepare = recordCompleted(calls) }
			)

			local state = ns.State()
			local flies = 0
			for _ in pairs(state.flies) do
				flies = flies + 1
			end
			assert.are.same({ 30, 30 }, { #calls, flies })
			-- board order: the 2 Expedition pins, the 6 Notice pins, then the strip by seq; the last is the 6th Expedition
			assert.are.same({ idAt(T + 36), { "flybox" } }, { calls[30][1], calls[30][2].titles })
			assert.are.same({
				tally_25 = { day = 0, cast = idAt(T + 100) },
				flybox = { day = 0, cast = idAt(T + 100) },
			}, state.titles)
			assert.are.equal(24 * 10 + 6 * 60, state.coins)
		end)

		it("tie no fly once its pool is empty, and grant flybox only once (TKB-R62)", function()
			local ns = built(withHistory(join(
				{ start(T) },
				times(31, function(i)
					return issue(T + i, ONE) -- 31 Notices: 24 commons, then nothing to tie
				end),
				times(6, function(i)
					return issue(T + 40 + i, ONE_E)
				end),
				{
					cast(T + 100, DUROTAR, { BLACKMOUTH }),
					issue(T + 101, ONE_E),
					cast(T + 102, DUROTAR, { BLACKMOUTH }),
				}
			)))

			local state = ns.State()
			assert.is_nil(state.goals[idAt(T + 31)].fly)
			assert.is_nil(state.goals[idAt(T + 101)].fly)
			assert.are.same({ day = 0, cast = idAt(T + 100) }, state.titles.flybox)
		end)
	end)

	describe("the outlet, the redraw and Coins (TKB-R60, TKB-R63, TKB-R84, SHOP-R2)", function()
		it("hand each completion to ns.outlets.Completed in rebuild, replay and live mode", function()
			local calls = {}
			local fake = withHistory({ start(T), issue(T + 1, ONE), cast(T + 2, DUROTAR, { BLACKMOUTH }) })
			local _, loaded = built(fake, { prepare = recordCompleted(calls) })
			-- written while the board was off: the next login replays them (LOG-R71)
			fake.catchLog:Append(issue(T + 3, ONE))
			fake.catchLog:Append(cast(T + 4, DUROTAR, { BLACKMOUTH }))
			local next = newFakePagle()
			next.catchLog.data = fake.catchLog.data
			next.globals.PagleTackleBoardDB = { global = loaded.env.PagleTackleBoardDB.global }
			built(next, { prepare = recordCompleted(calls) })

			live(next, issue(T + 5, ONE))
			live(next, cast(T + 6, DUROTAR, { BLACKMOUTH }))

			assert.are.same(
				{ { idAt(T + 1), "rebuild" }, { idAt(T + 3), "replay" }, { idAt(T + 5), "live" } },
				{ { calls[1][1], calls[1][3] }, { calls[2][1], calls[2][3] }, { calls[3][1], calls[3][3] } }
			)
		end)

		it("ask the views to redraw the completed goal live, before the projection redraw (TKB-R123)", function()
			local redraws = {}
			local fake = withHistory({ start(T), issue(T + 1, ONE), cast(T + 2, DUROTAR, { BLACKMOUTH }) })
			local ns = built(fake, {
				prepare = function(loaded)
					loaded.ns.OnRedraw(function(reason, detail)
						redraws[#redraws + 1] = reason .. " " .. tostring(detail)
					end)
				end,
			})

			live(fake, issue(T + 3, ONE))
			live(fake, cast(T + 4, DUROTAR, { BLACKMOUTH }))

			assert.are.same({
				"projection nil", -- done
				"projection nil", -- the issue record
				"completed " .. idAt(T + 3),
				"projection nil",
			}, redraws)
			assert.is_number(ns.State().goals[idAt(T + 3)].doneDay)
		end)

		it("report lifetime Coins from done and after each live entry that changes them (TKB-R63, SHOP-R2)", function()
			local fake = withHistory({ start(T), issue(T + 1, ONE), cast(T + 2, DUROTAR, { BLACKMOUTH }) })
			built(fake)

			live(fake, cast(T + 3, BARRENS, { BLACKMOUTH })) -- changes the state, not the Coins
			live(fake, issue(T + 4, ONE_E))
			live(fake, cast(T + 5, DUROTAR, { BLACKMOUTH }))

			assert.are.same(
				{ { module = "TackleBoard", total = 10 }, { module = "TackleBoard", total = 70 } },
				fake.coinReports
			)
		end)

		it("report nothing after a live entry while the Module has no handle (CORE-R13)", function()
			local fake = withHistory({ start(T), issue(T + 1, ONE) })
			local ns = built(fake)
			ns.Module = nil

			live(fake, cast(T + 2, DUROTAR, { BLACKMOUTH }))

			assert.are.same({ { module = "TackleBoard", total = 0 } }, fake.coinReports)
			assert.are.equal(10, ns.State().coins)
		end)

		it("report nothing on a board not started, and 0 Coins once it is (TKB-R2, SHOP-R2)", function()
			local fake = withHistory({ cast(T, DUROTAR, { BLACKMOUTH }) })
			local ns = built(fake)
			ns.ReportCoins()
			local before = copy(fake.coinReports)

			live(fake, start(T + 1))
			ns.ReportCoins() -- as the next done does

			assert.are.same({}, before)
			assert.are.same({ { module = "TackleBoard", total = 0 } }, fake.coinReports)
		end)
	end)

	describe("the 28-day history (tackle-board.md › Data, TKB-R106)", function()
		-- 25 Notices done by one Catch on day 0 (tally_25), an open filler, then a Cast in Barrens on board day `k`.
		local function history(k)
			return join(
				{ start(T) },
				times(25, function(i)
					return issue(T + i, ONE)
				end),
				{ issue(T + 30, FILLER), cast(T + 100, DUROTAR, { BLACKMOUTH }), cast(T + k * DAY, BARRENS) }
			)
		end

		it("keeps goals done on the last 28 board days, today included", function()
			local state = built(withHistory(history(27))).State()

			assert.are.equal(27, state.day)
			assert.are.same({ 0, 0 }, { state.goals[idAt(T + 1)].doneDay, state.goals[idAt(T + 25)].doneDay })
		end)

		it("drops goals done 28 board days back, keeping the open ones, the tally, Coins, flies and titles", function()
			local state = built(withHistory(history(28))).State()

			local goals = {}
			for id in pairs(state.goals) do
				goals[#goals + 1] = id
			end
			assert.are.same({ idAt(T + 30) }, goals)
			local flies = 0
			for _, fly in pairs(state.flies) do
				flies = flies + 1
				assert.are.equal(0, fly.goal.doneDay)
			end
			assert.are.same({ 24, 25, 250 }, { flies, state.tally.notices, state.coins })
			assert.are.same({ tally_25 = { day = 0, cast = idAt(T + 100) } }, state.titles)
		end)

		it("drops them as the live step advances the day, too (TKB-R14)", function()
			local ns = built(withHistory(history(27)))
			local state = ns.State()

			ns.AdvanceTo(state, 28, "live")

			assert.is_nil(state.goals[idAt(T + 1)])
			assert.is_table(state.goals[idAt(T + 30)])
		end)

		it("gives the same state rebuilt, and applied live with the live step's advance between (TKB-R82)", function()
			local log = join(history(30), { issue(T + 30 * DAY + 1, ONE), cast(T + 30 * DAY + 2, DUROTAR, { 6291 }) })
			local ns = built(withHistory(log))
			local rebuilt = copy(ns.State())
			ns.projection:Rebuild()
			local again = copy(ns.State())

			local fake = withHistory({})
			local applied = built(fake)
			for _, entry in ipairs(log) do
				local state = applied.State()
				if state.started then
					applied.AdvanceTo(state, applied.DayOf(state.boundary, entry.time) or 0, "live")
				end
				live(fake, entry)
			end

			assert.are.same({ 30, 260, 1 }, { rebuilt.day, rebuilt.coins, rebuilt.fire.count }) -- out on day 3, relit on day 30
			assert.are.same(rebuilt, again)
			assert.are.same(rebuilt, applied.State())
		end)
	end)
end)
