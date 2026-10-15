-- Loading Pagle_TackleBoard for its specs: over FakePagle (its catalogue, clock, Sessions and Module registry) with
-- the fixture catalogue served in place of the shipped one, and the board's reset API and random source injected (M7
-- graph, conventions: the Tackle Board's specs never run on the shipped catalogue, and they choose the clock, the
-- resets and the draws). Specs load this file with dofile (and the undefined-global suppression every dofile in spec/
-- carries), then call it:
--
--   local board = dofile("spec/Pagle_TackleBoard/support.lua")
--   local loaded, fake = board.load()
--   board.readSkill(fake)                          -- after fake.login(): the fixture Angler's skill (board.SKILL)
--   local loaded, fake = board.load(nil, { api = board.resetAPI(nil, { region = 3 }), random = board.random(7) })
--
-- The default reset API follows the fake's clock (fake.serverTime, which fake.wait moves): a US realm, UTC−7, whose
-- daily reset is 15:00 UTC and weekly reset Tuesday 15:00 UTC. FakePagle's clock starts at SERVER_TIME, Sunday 11
-- October 2026 15:15 UTC (realm 08:15), so the board day began 15 minutes ago and the week on Tuesday 6 October.

local FIXTURE_CATALOGUE = "spec/Pagle_TackleBoard/fixtures/Catalogue.lua"

local DAY, WEEK = 86400, 604800

local support = {}

--- The fixture Angler's best base skill (LOG-R27): every candidate zone of the fixture is at or below it (TKB-R30).
support.SKILL = 150

--- The server time of a daily reset: Sunday 11 October 2026 15:00 UTC, 15 minutes before SERVER_TIME.
support.DAILY_RESET = SERVER_TIME - 900

--- The server time of a weekly reset: Tuesday 13 October 2026 15:00 UTC.
support.WEEKLY_RESET = support.DAILY_RESET + 2 * DAY

--- The realm's UTC offset in seconds: UTC−7, US Pacific in summer time, as the fake client's GetGameTime (08:15).
support.REALM_OFFSET = -7 * 3600

--- The fixture catalogue (spec/Pagle_TackleBoard/fixtures/Catalogue.lua), a new table each call.
---@return table
function support.catalogue()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	return dofile(FIXTURE_CATALOGUE)
end

-- The seconds from `now` to the next reset of a period anchored at `anchor`: in (0, period].
---@param anchor integer
---@param period integer
---@param now integer
---@return integer
local function untilReset(anchor, period, now)
	local left = (anchor - now) % period
	return left == 0 and period or left
end

--- A reset API in the shape of ns.api (logic/Seams.lua): GetServerTime, C_DateAndTime (GetSecondsUntilDailyReset,
--- GetSecondsUntilWeeklyReset, GetCurrentCalendarTime), GetGameTime and GetCurrentRegion, on `now` (default: the
--- fake's server time, or SERVER_TIME with no fake). `overrides` changes it: `now` (a function), `region` (a number,
--- or false for a client without GetCurrentRegion), `daily` / `weekly` (functions returning the seconds to the reset,
--- or false for a missing call, TKB-R11).
---@param fake table? a FakePagle, whose clock it follows
---@param overrides { now: (fun(): integer)?, region: (integer|false)?, daily: (fun(): integer?)|false?, weekly: (fun(): integer?)|false? }?
---@return table
function support.resetAPI(fake, overrides)
	overrides = overrides or {}
	local now = overrides.now or (fake and fake.serverTime) or function()
		return SERVER_TIME
	end
	-- The realm's date and time at `now`, from the realm offset.
	local function realm()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has its own os
		return os.date("!*t", now() + support.REALM_OFFSET)
	end
	local dateAndTime = {
		GetCurrentCalendarTime = function()
			local t = realm()
			return { year = t.year, month = t.month, monthDay = t.day, weekday = t.wday, hour = t.hour, minute = t.min }
		end,
	}
	if overrides.daily ~= false then
		dateAndTime.GetSecondsUntilDailyReset = overrides.daily
			or function()
				return untilReset(support.DAILY_RESET, DAY, now())
			end
	end
	if overrides.weekly ~= false then
		dateAndTime.GetSecondsUntilWeeklyReset = overrides.weekly
			or function()
				return untilReset(support.WEEKLY_RESET, WEEK, now())
			end
	end
	local region = overrides.region
	if region == nil then
		region = 1
	end
	return {
		GetServerTime = function()
			return now()
		end,
		C_DateAndTime = dateAndTime,
		GetGameTime = function()
			local t = realm()
			return t.hour, t.min
		end,
		GetCurrentRegion = region ~= false and function()
			return region
		end or nil,
	}
end

--- A seeded random source, like math.random: random() in [0, 1), random(m) in 1..m and random(m, n) in m..n. The
--- same seed draws the same numbers, so a spec's goals are the same every run.
---@param seed integer?
---@return fun(m: integer?, n: integer?): number
function support.random(seed)
	local state = (seed or 1) % 2147483647
	if state <= 0 then
		state = state + 2147483646
	end
	return function(m, n)
		state = (state * 16807) % 2147483647 -- Park–Miller
		local r = (state - 1) / 2147483646
		if m == nil then
			return r
		end
		if n == nil then
			m, n = 1, m
		end
		return m + math.floor(r * (n - m + 1))
	end
end

--- Reads the fixture Angler's skill on `fake` after fake.login(): Fishing support.SKILL of 225, no modifier, so
--- Pagle.GetAngler().bestBaseSkill is support.SKILL (LOG-R27, TKB-R30).
---@param fake table a FakePagle, logged in
function support.readSkill(fake)
	fake.readSkill(support.SKILL, 225, 0)
end

-- The lore kinds the generated data/Lore.lua adds to ns.L (TKB-R130): `fly.`, `boardtitle.` and `boardgood.` keys.
local LORE_KINDS = { "fly", "boardtitle", "boardgood" }

-- Removes the shipped lore batch's keys from ns.L, so names fall back to their IDs (M7 graph, open question 7) and no
-- spec depends on text the dev's review may change (#244).
---@param L table ns.L
local function withoutLore(L)
	local keys = {}
	for key in pairs(L) do
		for _, kind in ipairs(LORE_KINDS) do
			if type(key) == "string" and key:sub(1, #kind + 1) == kind .. "." then
				keys[#keys + 1] = key
			end
		end
	end
	for _, key in ipairs(keys) do
		L[key] = nil
	end
end

--- Loads Pagle_TackleBoard on `fake` (a new FakePagle if nil), serving `options.catalogue` or else the fixture
--- catalogue through fake.setCatalogue first, so the board reads it from OnInitialize on, and putting
--- `options.api` (default support.resetAPI(fake)) and `options.random` (default support.random(1)) at ns.api and
--- ns.random before its ADDON_LOADED. The shipped lore batch (data/Lore.lua) is left out of ns.L, as the shipped
--- catalogue is, unless `options.lore` is true; a spec sets the lore keys it needs itself. `options.prepare(loaded)`
--- runs after that, still before OnInitialize.
---@param fake table? a FakePagle (newFakePagle()), for a spec that set it up first
---@param options { catalogue: table?, api: table?, random: function?, lore: boolean?, prepare: fun(loaded: LoadedAddon)? }?
---@return LoadedAddon loaded
---@return table fake
function support.load(fake, options)
	fake = fake or newFakePagle()
	options = options or {}
	fake.setCatalogue(options.catalogue or support.catalogue())
	local loaded = fake.load("Pagle_TackleBoard", { holdAddonLoaded = true })
	-- An inert load (no Pagle) leaves ns empty: nothing to inject into.
	if loaded.ns.TackleBoard then
		loaded.ns.api = options.api or support.resetAPI(fake)
		loaded.ns.random = options.random or support.random(1)
		if not options.lore then
			withoutLore(loaded.ns.L)
		end
	end
	if options.prepare then
		options.prepare(loaded)
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_TackleBoard")
	return loaded, fake
end

return support
