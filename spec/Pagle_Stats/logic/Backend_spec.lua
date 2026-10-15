-- Stats' Journal values for Pagle's backend (#223; logic/Fold.lua): the lifetime figures and the latest Sessions the
-- Angler page shows (STA-R30, STA-R33), from a projection state alone, on FakePagle. The binding itself is checked in
-- spec/logic_alone_spec.lua.

local ELWYNN, WESTFALL = 12, 40
local OILY = 6358
local T = SERVER_TIME - 90000
local T2 = T + 5000

-- A Cast record by character 1: caught (one Oily Blackmouth) unless `gotAway`.
local function cast(time, zone, gotAway)
	return castRecord({
		time = time,
		zone = zone,
		items = not gotAway and { OILY } or nil,
		outcome = gotAway and "gotAway",
	})
end

-- Three Sessions, each cut from the next by more than 5 minutes (LOG-R60): A (120 s, Elwynn twice, Westfall once),
-- B (60 s, Westfall twice, Elwynn once), each with one Cast that got away, then C (1200 s, six Catches in Westfall,
-- 4 minutes apart).
local HISTORY = {
	cast(T, ELWYNN),
	cast(T + 60, ELWYNN, true),
	cast(T + 120, WESTFALL),
	cast(T + 1000, WESTFALL),
	cast(T + 1030, WESTFALL),
	cast(T + 1060, ELWYNN, true),
}
for minutes = 0, 20, 4 do
	HISTORY[#HISTORY + 1] = cast(T2 + minutes * 60, WESTFALL)
end

-- Stats loaded on a fake whose log holds HISTORY, logged in and built.
---@return PagleStatsNS
local function statsOverHistory()
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(HISTORY) do
		fake.catchLog:Append(record)
	end
	local ns = fake.load("Pagle_Stats").ns
	fake.login()
	fake.enterWorld()
	return ns
end

describe("Stats' Journal values for the backend (#223)", function()
	local ns
	setup(function()
		ns = statsOverHistory()
	end)

	it("gives time at the water, the got-away rate, the longest Session and the best rate (STA-R33)", function()
		assert.are.same({
			time = 120 + 60 + 1200,
			gotAwayRate = 17, -- 2 of 12 Casts, rounded half up
			longest = { start = T2, length = 1200 },
			bestRate = { start = T2, rate = 18 }, -- 6 Catches in 20 minutes; A and B are too short to count
		}, ns.JournalValues(ns.State(), 20).stats)
	end)

	it("gives the latest Sessions, newest first, each with its zones by Casts, most first (STA-R30)", function()
		assert.are.same({
			{ start = T2, length = 1200, casts = 6, catches = 6, gotAway = 0, zones = { WESTFALL } },
			{ start = T + 1000, length = 60, casts = 3, catches = 2, gotAway = 1, zones = { WESTFALL, ELWYNN } },
			{ start = T, length = 120, casts = 3, catches = 2, gotAway = 1, zones = { ELWYNN, WESTFALL } },
		}, ns.JournalValues(ns.State(), 20).sessions)
	end)

	it("gives at most `sessionRows` Sessions", function()
		local sessions = ns.JournalValues(ns.State(), 2).sessions

		assert.are.same({ T2, T + 1000 }, { sessions[1].start, sessions[2].start })
		assert.are.equal(2, #sessions)
	end)

	it("gives no longest Session, no best rate and no Sessions before any Cast", function()
		local journal = ns.JournalValues(ns.NewStatsState(), 20)

		assert.are.same({ time = 0, gotAwayRate = 0 }, journal.stats)
		assert.are.same({}, journal.sessions)
		assert.are.same({}, journal.odds)
	end)
end)

describe("Stats' Your odds and Dry spells for the backend (#223, STA-R40–R54)", function()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	local stats = dofile("spec/Pagle_Stats/support.lua")
	local I = stats.IDS

	it("gives each zone fished, with its place spread's rows in group and odds order, worked by hand", function()
		-- support.darkshore: 150 Casts in Darkshore at 175 skill, above its line of 170, so with the live skill
		-- unknown the reading side is `hi`, where every Cast is (STA-R41). Darkshore's rows (STA-R17): Mackerel,
		-- Firefin and Smallfish any time, Blackmouth in the pools, Nightfin in its night window, which holds no Cast.
		local loaded = stats.start({ records = stats.darkshore() })
		local ns = loaded.ns

		local odds = ns.JournalValues(ns.State(), 20).odds

		assert.are.same({
			{
				zone = I.DARKSHORE,
				casts = 150,
				rows = {
					-- 5 of 150: 1 in 30, Wilson 1 in 13.2 to 1 in 69.8; 145 Casts since, P ≈ 0.0073
					{
						item = I.SMALLFISH,
						group = "anytime",
						state = "known",
						n = 150,
						k = 5,
						threshold = 100,
						oneIn = 30,
						lo = 13,
						hi = 70,
						since = 145,
						band = "unlucky",
					},
					-- 1 of 150, on the last Cast: Wilson 1 in 27.2 to 1 in 849; a Dry spell of 0 reads normal (STA-R54)
					{
						item = I.FIREFIN,
						group = "anytime",
						state = "known",
						n = 150,
						k = 1,
						threshold = 100,
						oneIn = 150,
						lo = 27,
						hi = 850,
						since = 0,
						band = "normal",
					},
					-- never caught: rarer than 1 in 150 / 3, and no Dry spell count to read luck from
					{ item = I.MACKEREL, group = "anytime", state = "unseen", n = 150, threshold = 100, oneIn = 50 },
					-- 2 of 150: Wilson 1 in 21.1 to 1 in 273; 130 since, P ≈ 0.17
					{
						item = I.BLACKMOUTH,
						group = "pools",
						state = "known",
						n = 150,
						k = 2,
						threshold = 100,
						oneIn = 75,
						lo = 21,
						hi = 270,
						since = 130,
						band = "normal",
					},
					{ item = I.NIGHTFIN, group = "window", state = "learning", n = 0, threshold = 100 },
				},
			},
		}, odds)
	end)
end)
