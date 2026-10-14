-- Board days and weeks (tackle-board.md › Board days and weeks, TKB-R10–R13): the live day and week starts, their
-- fallback, the numbering every record and Cast gets from the log alone, and the time to the next reset.
--
-- The reset API is spec/Pagle_TackleBoard/support.lua's: a US realm at UTC−7 whose clock reads Sunday 11 October 2026
-- 15:15 UTC (realm 08:15), daily reset 15:00 UTC, weekly reset Tuesday 15:00 UTC. Expected times are literals worked
-- out by hand (`date -u -d @<t>` checks each).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local DAY, WEEK = 86400, 604800

local NOW = 1791731700 -- Sun 11 Oct 2026 15:15 UTC, realm 08:15 (SERVER_TIME)
local DAILY = 1791730800 -- Sun 11 Oct 15:00 UTC: today's daily reset
local WEEKLY = 1791298800 -- Tue 6 Oct 15:00 UTC: this week's weekly reset
local MIDNIGHT = 1791702000 -- Sun 11 Oct 07:00 UTC: realm midnight today

describe("board days and weeks", function()
	local ns = board.load().ns

	--- The reset API at server time `now`, with `overrides` as support.resetAPI takes them.
	local function api(now, overrides)
		overrides = overrides or {}
		overrides.now = function()
			return now
		end
		return board.resetAPI(nil, overrides)
	end

	describe("ns.LiveBoundaries", function()
		it("starts the day and week at the last daily and weekly reset, from the reset calls (TKB-R10)", function()
			assert.are.same({ DAILY, WEEKLY }, { ns.LiveBoundaries(api(NOW)) })
		end)

		-- Each way a reset call can fail (TKB-R11): missing (false in support.resetAPI), nil, 0 or negative.
		local failures = {
			missing = false,
			["nil"] = function()
				return nil
			end,
			["0"] = function()
				return 0
			end,
			negative = function()
				return -5
			end,
		}

		for name, failed in pairs(failures) do
			it("falls the day back to realm midnight when the daily call is " .. name .. ", not the week (TKB-R11)", function()
				assert.are.same({ MIDNIGHT, WEEKLY }, { ns.LiveBoundaries(api(NOW, { daily = failed })) })
			end)

			it("falls the week back when the weekly call is " .. name .. ", not the day (TKB-R11)", function()
				-- Region 1: Tuesday, so realm midnight on Tue 6 Oct (07:00 UTC), 5 days before today's.
				assert.are.same({ DAILY, MIDNIGHT - 5 * DAY }, { ns.LiveBoundaries(api(NOW, { weekly = failed })) })
			end)
		end

		it("falls both back when both calls are missing (TKB-R11)", function()
			local both = api(NOW, { daily = false, weekly = false })
			assert.are.same({ MIDNIGHT, MIDNIGHT - 5 * DAY }, { ns.LiveBoundaries(both) })
		end)

		it("takes realm midnight to the second, whatever the seconds past the realm minute (TKB-R11)", function()
			-- 08:15:42 realm: the realm minute is 495, and the 42 s come off with now mod 60.
			local later = api(NOW + 42, { daily = false })
			assert.are.equal(MIDNIGHT, (ns.LiveBoundaries(later)))
		end)

		describe("the fallback week", function()
			-- The fallback reset weekday by region (tackle-board.md › Tunables), from Sunday 11 Oct (realm).
			local regions = {
				{ region = 1, weekday = "Tuesday", start = MIDNIGHT - 5 * DAY }, -- Tue 6 Oct
				{ region = 2, weekday = "Thursday", start = MIDNIGHT - 3 * DAY }, -- Thu 8 Oct
				{ region = 3, weekday = "Wednesday", start = MIDNIGHT - 4 * DAY }, -- Wed 7 Oct
				{ region = 4, weekday = "Thursday", start = MIDNIGHT - 3 * DAY },
				{ region = 5, weekday = "Thursday", start = MIDNIGHT - 3 * DAY },
				{ region = 72, weekday = "Wednesday", start = MIDNIGHT - 4 * DAY },
				{ region = false, weekday = "Wednesday", start = MIDNIGHT - 4 * DAY },
			}
			for _, case in ipairs(regions) do
				local region = case.region and ("region " .. case.region) or "no GetCurrentRegion"
				it("starts on " .. case.weekday .. " with " .. region .. " (TKB-R11, Tunables)", function()
					local fallback = api(NOW, { weekly = false, region = case.region })
					assert.are.equal(case.start, select(2, ns.LiveBoundaries(fallback)))
				end)
			end

			it("starts today when today is the fallback weekday (TKB-R11: on or before today)", function()
				-- Tue 13 Oct 08:15 realm; realm midnight is Tue 13 Oct 07:00 UTC.
				local tuesday = api(NOW + 2 * DAY, { weekly = false, region = 1 })
				assert.are.equal(MIDNIGHT + 2 * DAY, select(2, ns.LiveBoundaries(tuesday)))
			end)

			it("starts 6 days back the day before the fallback weekday (TKB-R11)", function()
				-- Mon 12 Oct 08:15 realm, region 1: Tuesday 6 Oct.
				local monday = api(NOW + DAY, { weekly = false, region = 1 })
				assert.are.equal(MIDNIGHT - 5 * DAY, select(2, ns.LiveBoundaries(monday)))
			end)
		end)
	end)
end)
