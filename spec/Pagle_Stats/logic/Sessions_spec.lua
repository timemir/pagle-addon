-- The figures Stats works out from its Session records when shown, never stored (STA-R32, STA-R33, STA-R95): which
-- record is the current Session or "My last Session", time fished, Catches per hour, got-away rates, Catches by
-- quality, lifetime time at the water, the bests and the first Cast's date. Hand-written Session records in
-- stats.md › Projection state's shape (#203 builds the same shape from the log); `live` stands for
-- `Pagle.GetSession()` (LOG-R64).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

-- 2026-10-11 08:15 UTC, a server time (FakePagle's clock day).
local T0 = 1791706500

-- A Session record (StatsSession, STA-R30) starting `start` seconds after T0 and lasting `length` seconds, with
-- `fields` over its counts.
---@param id string
---@param start integer
---@param length integer
---@param fields table?
---@return StatsSession
local function record(id, start, length, fields)
	local session = {
		id = id,
		startTime = T0 + start,
		endTime = T0 + start + length,
		casts = 0,
		catches = 0,
		gotAway = 0,
		chars = {},
		zones = {},
		items = {},
		skill = 0,
	}
	for key, value in pairs(fields or {}) do
		session[key] = value
	end
	return session
end

-- Core's Session (PagleSession, LOG-R64) with the given ID.
---@param id string
---@return table
local function live(id)
	return { id = id, startTime = T0, endTime = T0, casts = 1, catches = 1, gotAway = 0, characters = {}, zones = {} }
end

describe("Session figures", function()
	local ns = stats.load().ns

	describe("the current Session (STA-R32)", function()
		local first, last = record("A", 0, 600), record("B", 7200, 1800)

		it("is the last record while Core's Session is open and its ID matches", function()
			local shown = ns.CurrentSession({ first, last }, live("B"))

			assert.are.equal("current", shown.kind)
			assert.are.equal(last, shown.record)
			assert.are.equal(2, shown.index)
		end)

		it("is reported as mismatched, with Core's Session alone, when the IDs differ (STA-R72, STA-R85)", function()
			local open = live("C")
			local shown = ns.CurrentSession({ first, last }, open)

			assert.are.same({ kind = "mismatched", live = open }, shown)
			assert.are.equal(open, shown.live)
		end)

		it("is mismatched while Core has a Session and Stats has no record yet (STA-R72, STA-R85)", function()
			assert.are.same({ kind = "mismatched", live = live("A") }, ns.CurrentSession({}, live("A")))
		end)

		it("isn't there with no Session open: the last record is My last Session", function()
			local shown = ns.CurrentSession({ first, last }, nil)

			assert.are.equal("last", shown.kind)
			assert.are.equal(last, shown.record)
			assert.are.equal(2, shown.index)
		end)

		it("is none with no Session open and no records (STA-R97)", function()
			assert.is_nil(ns.CurrentSession({}, nil))
		end)
	end)

	describe("time fished (STA-R33)", function()
		it("is endTime − startTime for a Session that has ended", function()
			assert.are.equal(1800, ns.TimeFished(record("A", 0, 1800)))
		end)

		it("counts to now for the current Session, so far", function()
			local current = record("B", 0, 1800)
			local shown = assert(ns.CurrentSession({ current }, live("B")))

			assert.are.equal(1860, ns.TimeFished(shown.record, T0 + 1860))
		end)

		it("is 0 for a Session of one Cast", function()
			assert.are.equal(0, ns.TimeFished(record("A", 0, 0)))
		end)

		it("is one Session's length across midnight, dated by its start (STA-R95)", function()
			-- 23:30 to 00:45 the next day, UTC.
			local midnight = 1791763200
			local crossing = record("A", midnight - 1800 - T0, 4500)

			assert.are.equal(4500, ns.TimeFished(crossing))
			assert.are.equal(midnight - 1800, ns.SessionDate(crossing))
		end)
	end)

	describe("Catches per hour (STA-R33, STA-R44's rounding)", function()
		it("has its Tunables minimum of 60 s", function()
			assert.are.equal(60, ns.CATCHES_PER_HOUR_MIN_SECONDS)
		end)

		it("is catches × 3600 / time fished, a whole number", function()
			-- 46 Catches in 21 minutes: 131.43 an hour.
			assert.are.equal(131, ns.CatchesPerHour(record("A", 0, 1260, { catches = 46 })))
		end)

		it("counts at least 60 s: 2 Catches in 10 s gives 120", function()
			assert.are.equal(120, ns.CatchesPerHour(record("A", 0, 10, { catches = 2 })))
		end)

		it("counts at least 60 s for a Session of one Cast", function()
			assert.are.equal(60, ns.CatchesPerHour(record("A", 0, 0, { catches = 1 })))
		end)

		it("rounds half up", function()
			-- 1 Catch in 4,800 s is 0.75 an hour, in 2,400 s 1.5, in 7,200 s 0.5.
			assert.are.equal(1, ns.CatchesPerHour(record("A", 0, 4800, { catches = 1 })))
			assert.are.equal(2, ns.CatchesPerHour(record("A", 0, 2400, { catches = 1 })))
			assert.are.equal(1, ns.CatchesPerHour(record("A", 0, 7200, { catches = 1 })))
			-- 5 in 1,800 s is 10 exactly; 3 in 1,200 s is 9, 7 in 2,400 s is 10.5.
			assert.are.equal(10, ns.CatchesPerHour(record("A", 0, 1800, { catches = 5 })))
			assert.are.equal(11, ns.CatchesPerHour(record("A", 0, 2400, { catches = 7 })))
		end)

		it("is 0 with no Catches", function()
			assert.are.equal(0, ns.CatchesPerHour(record("A", 0, 1800, { casts = 12, gotAway = 12 })))
		end)

		it("counts the current Session's time so far", function()
			-- 10 Catches over 30 minutes so far, though the latest Cast was at 20 minutes.
			assert.are.equal(20, ns.CatchesPerHour(record("B", 0, 1200, { catches = 10 }), T0 + 1800))
		end)
	end)

	describe("the got-away rate (STA-R33)", function()
		it("is gotAway / casts as a whole percentage, half up", function()
			assert.are.equal(25, ns.GotAwayRate({ casts = 8, gotAway = 2 }))
			-- 1 in 3 is 33.3%, 2 in 3 66.7%, 1 in 8 12.5%.
			assert.are.equal(33, ns.GotAwayRate({ casts = 3, gotAway = 1 }))
			assert.are.equal(67, ns.GotAwayRate({ casts = 3, gotAway = 2 }))
			assert.are.equal(13, ns.GotAwayRate({ casts = 8, gotAway = 1 }))
		end)

		it("is 0 and 100 at the ends", function()
			assert.are.equal(0, ns.GotAwayRate(record("A", 0, 60, { casts = 4, catches = 4 })))
			assert.are.equal(100, ns.GotAwayRate(record("A", 0, 60, { casts = 4, gotAway = 4 })))
		end)

		it("is none with 0 Casts", function()
			assert.is_nil(ns.GotAwayRate({ casts = 0, gotAway = 0 }))
		end)
	end)

	describe("Catches by quality (STA-R33)", function()
		-- Fixture items of quality 1 (Common), with Core's records (LOG-R55).
		local MACKEREL, NIGHTFIN, MANA_POTION = 6303, 13759, 2455
		-- Rusted Lure: a Core record without a quality.
		local RUSTED_LURE = 90001
		-- A rare (3) fish this spec adds to its copy of the fixture catalogue.
		local RARE = 90100
		-- Items Core has no record of (Uncharted, LOG-R55).
		local UNCHARTED_GREEN, UNCHARTED_GREY, UNCHARTED_UNLOADED = 90200, 90201, 90202

		local catalogue = stats.catalogue()
		catalogue.items[RARE] = {
			category = "fish",
			species = RARE,
			quality = 3,
			legend = false,
			noise = false,
			removed = false,
			pool = false,
		}
		local loaded = stats.load(nil, { catalogue = catalogue })
		local Pagle = loaded.env.Pagle
		local statsNs = loaded.ns

		-- The client's qualities, as C_Item.GetItemQualityByID gives them once loaded (nil before). It knows the
		-- catalogue items too, at another quality, so a spec can tell whose quality was used.
		local client = {
			[MACKEREL] = 4,
			[RARE] = 4,
			[RUSTED_LURE] = 2,
			[UNCHARTED_GREEN] = 2,
			[UNCHARTED_GREY] = 0,
		}
		local asked = {}
		local lookups = {
			GetItem = Pagle.GetItem,
			GetItemQualityByID = function(itemID)
				asked[#asked + 1] = itemID
				return client[itemID]
			end,
		}

		it("groups items by Core's quality, highest first, summing their Catches", function()
			asked = {}
			local qualities, pending = statsNs.CatchesByQuality({ [MACKEREL] = 5, [NIGHTFIN] = 2, [RARE] = 1 }, lookups)

			assert.are.same({ { quality = 3, catches = 1 }, { quality = 1, catches = 7 } }, qualities)
			assert.are.same({}, pending)
			assert.are.same({}, asked)
		end)

		it("falls back to the client's quality when Core has none: Uncharted, or a record without one", function()
			local qualities, pending = statsNs.CatchesByQuality({
				[MANA_POTION] = 1,
				[RUSTED_LURE] = 2,
				[UNCHARTED_GREEN] = 3,
				[UNCHARTED_GREY] = 4,
			}, lookups)

			assert.are.same({
				{ quality = 2, catches = 5 },
				{ quality = 1, catches = 1 },
				{ quality = 0, catches = 4 },
			}, qualities)
			assert.are.same({}, pending)
		end)

		it("leaves out an item whose quality isn't loaded yet and reports it pending, for the caller to ask", function()
			local qualities, pending = statsNs.CatchesByQuality({
				[MACKEREL] = 2,
				[UNCHARTED_UNLOADED] = 6,
				[UNCHARTED_GREEN] = 1,
			}, lookups)

			assert.are.same({ { quality = 2, catches = 1 }, { quality = 1, catches = 2 } }, qualities)
			assert.are.same({ UNCHARTED_UNLOADED }, pending)
		end)

		it("counts a pending item once its quality loads", function()
			local items = { [UNCHARTED_UNLOADED] = 6 }
			assert.are.same({}, (statsNs.CatchesByQuality(items, lookups)))

			client[UNCHARTED_UNLOADED] = 2
			local qualities, pending = statsNs.CatchesByQuality(items, lookups)
			client[UNCHARTED_UNLOADED] = nil

			assert.are.same({ { quality = 2, catches = 6 } }, qualities)
			assert.are.same({}, pending)
		end)

		it("lists pending items by item ID, ascending", function()
			local _, pending = statsNs.CatchesByQuality({ [90302] = 1, [90300] = 1, [90301] = 1 }, lookups)

			assert.are.same({ 90300, 90301, 90302 }, pending)
		end)

		it("is empty with no items", function()
			local qualities, pending = statsNs.CatchesByQuality({}, lookups)

			assert.are.same({}, qualities)
			assert.are.same({}, pending)
		end)
	end)

	describe("lifetime time at the water (STA-R33)", function()
		it("sums every record's endTime − startTime", function()
			local sessions = { record("A", 0, 1800), record("B", 7200, 600), record("C", 90000, 0) }

			assert.are.equal(2400, ns.TimeAtTheWater(sessions))
		end)

		it("counts the current Session up to its latest Cast, not to now", function()
			local sessions = { record("A", 0, 1800), record("B", 7200, 600) }
			assert(ns.CurrentSession(sessions, live("B")))

			assert.are.equal(2400, ns.TimeAtTheWater(sessions))
		end)

		it("is 0 with no records (STA-R97)", function()
			assert.are.equal(0, ns.TimeAtTheWater({}))
		end)
	end)

	describe("the longest Session (STA-R33)", function()
		it("is the record with the most endTime − startTime", function()
			local longest = record("B", 7200, 3600)
			local sessions = { record("A", 0, 1800), longest, record("C", 90000, 600) }

			assert.are.equal(longest, ns.LongestSession(sessions))
		end)

		it("is the earliest on a tie", function()
			local earliest = record("A", 0, 3600)
			local sessions = { record("Z", -9000, 60), earliest, record("B", 7200, 3600), record("C", 90000, 3600) }

			assert.are.equal(earliest, ns.LongestSession(sessions))
		end)

		it("includes the current one, up to its latest Cast", function()
			local current = record("C", 90000, 5400)
			local sessions = { record("A", 0, 1800), current }
			assert.are.equal("current", assert(ns.CurrentSession(sessions, live("C"))).kind)

			assert.are.equal(current, ns.LongestSession(sessions))
		end)

		it("is none with no records (STA-R97)", function()
			assert.is_nil(ns.LongestSession({}))
		end)
	end)

	describe("the most Catches per hour (STA-R33)", function()
		it("has its Tunables bests minimum of 20 minutes", function()
			assert.are.equal(1200, ns.BESTS_MIN_SECONDS)
		end)

		it("is the record with the best rate, with that rate as a whole number", function()
			-- 30 an hour, 40.5 an hour, 25 an hour.
			local best = record("B", 7200, 1600, { catches = 18 })
			local sessions = {
				record("A", 0, 3600, { catches = 30 }),
				best,
				record("C", 90000, 7200, { catches = 50 }),
			}

			local session, rate = ns.BestCatchesPerHour(sessions)

			assert.are.equal(best, session)
			assert.are.equal(41, rate)
		end)

		it("never counts a record under 20 minutes, however fast", function()
			-- 1,199 s at 600 an hour; then 1,200 s exactly at 30 an hour.
			local qualifying = record("B", 7200, 1200, { catches = 10 })
			local sessions = { record("A", 0, 1199, { catches = 200 }), qualifying }

			local session, rate = ns.BestCatchesPerHour(sessions)

			assert.are.equal(qualifying, session)
			assert.are.equal(30, rate)
		end)

		it("is none when no record has 20 minutes", function()
			local session, rate = ns.BestCatchesPerHour({ record("A", 0, 600, { catches = 9 }), record("B", 7200, 0) })

			assert.is_nil(session)
			assert.is_nil(rate)
		end)

		it("is none with no records (STA-R97)", function()
			assert.is_nil((ns.BestCatchesPerHour({})))
		end)

		it("is the earliest on a tie of unrounded rates", function()
			-- 40 an hour twice; 401 in 10 hours (40.1) rounds to 40 too but is better.
			local earliest = record("A", 0, 1800, { catches = 20 })
			local tie = { earliest, record("B", 7200, 3600, { catches = 40 }) }
			assert.are.equal(earliest, (ns.BestCatchesPerHour(tie)))

			local better = record("C", 90000, 36000, { catches = 401 })
			local unrounded = { earliest, record("B", 7200, 3600, { catches = 40 }), better }
			assert.are.equal(better, (ns.BestCatchesPerHour(unrounded)))
		end)

		it("includes the current one, over its endTime − startTime", function()
			-- The current Session's latest Cast came at 25 minutes: it qualifies, at 48 an hour, though by now (40
			-- minutes) its rate so far would be 30.
			local current = record("B", 7200, 1500, { catches = 20 })
			local sessions = { record("A", 0, 3600, { catches = 40 }), current }
			assert.are.equal("current", assert(ns.CurrentSession(sessions, live("B"))).kind)

			local session, rate = ns.BestCatchesPerHour(sessions)

			assert.are.equal(current, session)
			assert.are.equal(48, rate)
		end)
	end)

	describe("the first Cast's date (STA-R33)", function()
		it("is the first record's startTime", function()
			assert.are.equal(T0 + 60, ns.FirstCastTime({ record("A", 60, 600), record("B", 7200, 600) }))
		end)

		it("is none with no records (STA-R97)", function()
			assert.is_nil(ns.FirstCastTime({}))
		end)
	end)
end)
