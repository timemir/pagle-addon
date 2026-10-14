-- What a completion earns inside the Module and what keeps the Campfire burning (tackle-board.md › Completion and
-- rewards, The Campfire, Data, Coins paid): pure functions over the projection's tally, flies and fire tables.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

describe("the tally", function()
	local ns = board.load().ns

	-- Adds `n` completions of `goalType` and returns each one's result.
	local function add(tally, goalType, n)
		local results = {}
		for i = 1, n do
			results[i] = ns.Tally.Add(tally, goalType) or false
		end
		return results
	end

	it("counts Notices and Expeditions separately (TKB-R61)", function()
		local tally = { notices = 0, expeditions = 0 }

		add(tally, "n", 3)
		add(tally, "e", 2)

		assert.are.same({ notices = 3, expeditions = 2 }, tally)
	end)

	it("returns tally_25 at the 25th combined completion, nothing at the 24th or 26th (TKB-R61)", function()
		local tally = { notices = 20, expeditions = 3 }

		local results = add(tally, "e", 3)

		assert.are.same({ false, "tally_25", false }, results)
	end)

	it("returns tally_100 at the 100th and tally_500 at the 500th, Notices or Expeditions (TKB-R61)", function()
		local tally = { notices = 99, expeditions = 0 }
		local hundred = ns.Tally.Add(tally, "n")
		tally = { notices = 450, expeditions = 49 }
		local fiveHundred = ns.Tally.Add(tally, "e")

		assert.are.same({ "tally_100", "tally_500" }, { hundred, fiveHundred })
	end)

	it("returns nothing on any other count from 1 to 600 (TKB-R61)", function()
		local tally, earned = { notices = 0, expeditions = 0 }, {}

		for i = 1, 600 do
			local title = ns.Tally.Add(tally, i % 4 == 0 and "e" or "n")
			if title then
				earned[#earned + 1] = i .. ":" .. title
			end
		end

		assert.are.same({ "25:tally_25", "100:tally_100", "500:tally_500" }, earned)
	end)
end)

describe("the Tackle Board's FNV-1a", function()
	local ns = board.load().ns

	-- Core's FNV-1a test vectors (spec/Pagle/logic/FieldReportText_spec.lua): FNV-1a 32-bit's published vectors and
	-- REP-R36's reporter keys, as integers.
	local VECTORS = {
		{ "", 0x811c9dc5 },
		{ "a", 0xe40c292c },
		{ "foobar", 0xbf9cf968 },
		{ "3f9a2c1e7b0d4a65", 0xf38e76b0 },
		{ "314ca8bd2fb83d86", 0x38d9e978 },
		{ "000000000000020a", 0x0071890c },
	}
	for _, vector in ipairs(VECTORS) do
		it(("hashes %q to Core's %08x (TKB-R62, LOG-R66 step 1)"):format(vector[1], vector[2]), function()
			assert.are.equal(vector[2], ns.Fnv1a(vector[1]))
		end)
	end

	it("agrees with Core's own FNV-1a on goal IDs (TKB-R62, ADR 0001: the Module's own code)", function()
		local core = loadAddon("Pagle", FOREVER_GLOBALS).ns
		local ids = {
			"Player-4618-0A1B2C3D-1791731747-0",
			"Player-4618-0A1B2C3D-1791732000-1",
			"Player-1-00000001-1700000000-0",
			"Player-4395-FFFFFFFF-2147483647-9",
		}
		for _, id in ipairs(ids) do
			assert.are.equal(core.ReporterKey(id), ("%08x"):format(ns.Fnv1a(id)))
		end
	end)
end)

describe("the Fly Box", function()
	local ns = board.load().ns

	-- Two goal IDs and their FNV-1a hashes, worked out apart from the Module (Python's FNV-1a): A 1591859118 (mod 24 =
	-- 6, mod 23 = 0, mod 6 = 0), B 3755513810 (mod 24 = 2, mod 6 = 2).
	local A = "Player-4618-0A1B2C3D-1791731747-0"
	local B = "Player-4618-0A1B2C3D-1791731800-0"

	-- tackle-board.md › Data › Fly Box patterns, in pattern order.
	local COMMON = {
		"murloc_nymph",
		"westfall_wheatwing",
		"goldshire_gnat",
		"duskwood_shadow",
		"redridge_ember",
		"barrens_dun",
		"mudsnout_woolly",
		"gnomish_whirligig",
		"tarnished_spoon",
		"ashenvale_olive",
		"kodo_hair_caddis",
		"elwynn_royal",
		"swamp_midge",
		"raptor_quill",
		"silverpine_spinner",
		"lakeshire_coachman",
		"bloodsail_streamer",
		"booty_bay_bucktail",
		"desolace_drifter",
		"grimtotem_hackle",
		"needles_ant",
		"feralas_fern",
		"tanaris_sandfly",
		"darkshore_dun",
	}
	local RARE = {
		"nats_golden_doctor",
		"kraken_ink_streamer",
		"phoenix_hackle",
		"moonwell_silverwing",
		"thunderhead_tiger",
		"deepwater_duchess",
	}
	local IS_RARE = {}
	for _, id in ipairs(RARE) do
		IS_RARE[id] = true
	end

	-- A completed goal of `goalType` with this ID, done on board day 3.
	local function goal(goalType, id)
		return {
			id = id,
			seq = 40,
			type = goalType,
			kind = "haul",
			tier = goalType == "e" and 0 or 2,
			pay = goalType == "e" and 60 or 15,
			need = 30,
			target = 12,
			reposted = false,
			issuedDay = 1,
			time = SERVER_TIME,
			progress = 30,
			seen = {},
			doneDay = 3,
			doneTime = SERVER_TIME + 3 * 86400,
		}
	end

	-- A goal ID numbered `n`, for completions in bulk.
	local function nth(n)
		return ("Player-4618-0A1B2C3D-%d-0"):format(1791731747 + n)
	end

	-- The Fly Box with these patterns tied.
	local function tied(ids)
		local flies = {}
		for _, id in ipairs(ids) do
			flies[id] = { day = 0, time = SERVER_TIME, goal = goal("n", id) }
		end
		return flies
	end

	-- How many keys `t` has.
	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end

	it("holds Data's 30 patterns in pattern order, 24 common then 6 rare, each with an icon (TKB-R62)", function()
		local ids, rares, icons = {}, {}, 0
		for i, pattern in ipairs(ns.FLY_PATTERNS) do
			ids[i] = pattern.id
			rares[i] = pattern.rare
			if type(pattern.icon) == "string" and pattern.icon:find("^Interface\\Icons\\%w") then
				icons = icons + 1
			end
		end
		local expected, expectedRares = {}, {}
		for i, id in ipairs(COMMON) do
			expected[i], expectedRares[i] = id, false
		end
		for i, id in ipairs(RARE) do
			expected[24 + i], expectedRares[24 + i] = id, true
		end

		assert.are.same(expected, ids)
		assert.are.same(expectedRares, rares)
		assert.are.equal(30, icons)
	end)

	it("ties pool[(h mod #pool) + 1] for a Notice: A ties the 7th common pattern, B the 3rd (TKB-R62)", function()
		assert.are.equal("mudsnout_woolly", ns.FlyBox.Tie({}, goal("n", A)))
		assert.are.equal("goldshire_gnat", ns.FlyBox.Tie({}, goal("n", B)))
	end)

	it("takes the pool as the untied candidates in pattern order (TKB-R62)", function()
		-- With mudsnout_woolly tied, 23 commons are left and A's h mod 23 is 0: the first of them.
		assert.are.equal("murloc_nymph", ns.FlyBox.Tie(tied({ "mudsnout_woolly" }), goal("n", A)))
	end)

	it("ties a rare pattern for an Expedition: A the 1st, B the 3rd (TKB-R62)", function()
		assert.are.equal("nats_golden_doctor", ns.FlyBox.Tie({}, goal("e", A)))
		assert.are.equal("phoenix_hackle", ns.FlyBox.Tie({}, goal("e", B)))
	end)

	it("records the pattern tied, when and by a copy of the goal, and marks the goal (TKB-R62, Data)", function()
		local flies, done = {}, goal("n", A)

		local pattern = ns.FlyBox.Tie(flies, done)
		done.progress = 99

		assert.are.equal("mudsnout_woolly", done.fly)
		assert.are.same({ 1, true }, { count(flies), flies.mudsnout_woolly ~= nil })
		local entry = flies[pattern]
		assert.are.same({ 3, SERVER_TIME + 3 * 86400 }, { entry.day, entry.time })
		local copy = entry.goal
		assert.are.same(
			{ A, "n", "haul", 12, 30, "mudsnout_woolly" },
			{ copy.id, copy.type, copy.kind, copy.target, copy.progress, copy.fly }
		)
	end)

	it("never ties a rare pattern for a Notice, and ties nothing once every common one is tied (TKB-R62)", function()
		local flies, seen, rare = {}, {}, 0

		for n = 1, 24 do
			local pattern = ns.FlyBox.Tie(flies, goal("n", nth(n)))
			seen[pattern] = true
			rare = rare + (IS_RARE[pattern] and 1 or 0)
		end
		local twentyFifth = goal("n", nth(25))

		assert.are.same({ 24, 0 }, { count(seen), rare })
		assert.is_nil(ns.FlyBox.Tie(flies, twentyFifth))
		assert.is_nil(twentyFifth.fly)
		assert.are.equal(24, count(flies))
	end)

	it("ties rare patterns for Expeditions until all six are tied, then common ones (TKB-R62)", function()
		local flies, rares = {}, 0

		for n = 1, 6 do
			rares = rares + (IS_RARE[ns.FlyBox.Tie(flies, goal("e", nth(n)))] and 1 or 0)
		end
		-- Every rare pattern is tied: A's Expedition takes from the 24 commons, h mod 24 = 6.
		local seventh = ns.FlyBox.Tie(flies, goal("e", A))

		assert.are.same({ 6, "mudsnout_woolly" }, { rares, seventh })
	end)

	it("ties each pattern once: 30 completions fill the box, then nothing is tied and it's full (TKB-R62)", function()
		local flies, distinct = {}, {}

		for n = 1, 24 do
			distinct[ns.FlyBox.Tie(flies, goal("n", nth(n)))] = true
		end
		assert.is_false(ns.FlyBox.IsFull(flies))
		for n = 25, 30 do
			distinct[ns.FlyBox.Tie(flies, goal("e", nth(n)))] = true
		end
		local late = goal("e", A)

		assert.are.equal(30, count(distinct))
		assert.is_true(ns.FlyBox.IsFull(flies))
		assert.is_nil(ns.FlyBox.Tie(flies, late))
		assert.is_nil(ns.FlyBox.Tie(flies, goal("n", B)))
		assert.is_nil(late.fly)
		assert.are.equal(30, count(flies))
	end)

	it("isn't full with 29 patterns tied, nor empty (TKB-R62: the flybox title)", function()
		local ids = {}
		for i = 1, 29 do
			ids[i] = ns.FLY_PATTERNS[i].id
		end

		assert.is_false(ns.FlyBox.IsFull(tied(ids)))
		assert.is_false(ns.FlyBox.IsFull({}))
	end)

	it("has a flame, a tally plate and a Fly Box icon for the ledge and the moments (TKB-R86, TKB-R106)", function()
		local icons = {}
		for _, key in ipairs({ "campfire", "tally", "flyBox" }) do
			icons[#icons + 1] = (ns.REWARD_ICONS[key] or ""):find("^Interface\\Icons\\%w") ~= nil
		end

		assert.are.same({ true, true, true }, icons)
	end)
end)

describe("the titles", function()
	local ns = board.load().ns

	it("are Data's eight title IDs in the Titles table's order, each with what earns it (TKB-R106, Data)", function()
		assert.are.same({
			{ id = "tally_25", source = "tally", need = 25 },
			{ id = "tally_100", source = "tally", need = 100 },
			{ id = "tally_500", source = "tally", need = 500 },
			{ id = "campfire_7", source = "campfire", need = 7 },
			{ id = "campfire_30", source = "campfire", need = 30 },
			{ id = "campfire_100", source = "campfire", need = 100 },
			{ id = "campfire_365", source = "campfire", need = 365 },
			{ id = "flybox", source = "flybox", need = 30 },
		}, ns.TITLES)
	end)
end)

describe("Coins paid", function()
	local ns = board.load().ns

	it(
		"pays 10 / 15 / 20 for a Notice of tier 1 / 2 / 3 and 60 for an Expedition (tackle-board.md › Coins paid)",
		function()
			assert.are.same({ { 10, 15, 20 }, 60 }, { ns.NOTICE_PAY, ns.EXPEDITION_PAY })
		end
	)

	it("pays 25 / 75 / 200 / 500 at the 7 / 30 / 100 / 365-day milestones, with their titles (TKB-R73)", function()
		assert.are.same({
			{ days = 7, coins = 25, title = "campfire_7" },
			{ days = 30, coins = 75, title = "campfire_30" },
			{ days = 100, coins = 200, title = "campfire_100" },
			{ days = 365, coins = 500, title = "campfire_365" },
		}, ns.CAMPFIRE_MILESTONES)
	end)
end)

describe("the Campfire", function()
	local ns = board.load().ns
	local CAST = "Player-4618-0A1B2C3D-1791731747-0"

	-- A fire with these fields over a cold one's.
	local function fire(fields)
		local f = { count = 0, kindling = 0, longest = 0, milestones = {}, log = {} }
		for key, value in pairs(fields or {}) do
			f[key] = value
		end
		return f
	end

	-- The board days `log` holds, ascending.
	local function days(log)
		local list = {}
		for day in pairs(log) do
			list[#list + 1] = day
		end
		table.sort(list)
		return list
	end

	describe("ns.Campfire.Start", function()
		it("gives the Angler 2 Kindling (TKB-R71)", function()
			local f = fire()

			ns.Campfire.Start(f)

			assert.are.same(fire({ kindling = 2 }), f)
		end)
	end)

	describe("ns.Campfire.Light", function()
		it("lights a day: the count rises by 1, the longest follows, the day is logged lit (TKB-R70)", function()
			local f = fire({ kindling = 2 })

			local result = ns.Campfire.Light(f, 4, CAST)

			assert.are.same({ lit = true }, result)
			assert.are.same(fire({ count = 1, kindling = 2, longest = 1, log = { [4] = "lit" } }), f)
		end)

		it("counts a day once however many goals complete on it (TKB-R70)", function()
			local f = fire({ kindling = 2 })

			ns.Campfire.Light(f, 4, CAST)
			local second = ns.Campfire.Light(f, 4, CAST)

			assert.are.same({ lit = false }, second)
			assert.are.same({ 1, 1 }, { f.count, f.longest })
		end)

		it("makes the longest max(longest, count) (TKB-R70, TKB-R74)", function()
			local behind = fire({ count = 3, kindling = 2, longest = 10 })
			local level = fire({ count = 10, kindling = 2, longest = 10 })

			ns.Campfire.Light(behind, 9, CAST)
			ns.Campfire.Light(level, 9, CAST)

			assert.are.same({ 4, 10, 11, 11 }, { behind.count, behind.longest, level.count, level.longest })
		end)

		it("earns a Kindling and the campfire_7 milestone's 25 Coins on the 7th lit day (TKB-R70, TKB-R73)", function()
			local f = fire({ count = 6, kindling = 2, longest = 6 })

			local result = ns.Campfire.Light(f, 12, CAST)

			assert.are.same({ lit = true, milestone = { days = 7, coins = 25, title = "campfire_7" } }, result)
			assert.are.same({ 7, 3, 7 }, { f.count, f.kindling, f.longest })
			assert.are.same({ [7] = { day = 12, cast = CAST } }, f.milestones)
		end)

		it("pays nothing when a later fire reaches 7 again, but still earns the Kindling (TKB-R73)", function()
			local f = fire({ count = 6, kindling = 1, longest = 9, milestones = { [7] = { day = 3, cast = "x" } } })

			local result = ns.Campfire.Light(f, 40, CAST)

			assert.are.same({ lit = true }, result)
			assert.are.same({ 7, 2 }, { f.count, f.kindling })
			assert.are.same({ [7] = { day = 3, cast = "x" } }, f.milestones)
		end)

		it("never lets Kindling pass 3 (TKB-R70)", function()
			local f = fire({ count = 13, kindling = 3, longest = 13 })

			ns.Campfire.Light(f, 20, CAST)

			assert.are.same({ 14, 3 }, { f.count, f.kindling })
		end)

		it("pays each milestone once over a year-long fire, 800 Coins in all (TKB-R70, TKB-R73)", function()
			local f = fire()
			ns.Campfire.Start(f)
			local reached, coins, kindled = {}, 0, {}

			for day = 0, 364 do
				local before = f.kindling
				local result = ns.Campfire.Light(f, day, CAST)
				if result.milestone then
					reached[#reached + 1] = result.milestone.title
					coins = coins + result.milestone.coins
				end
				if f.kindling > before then
					kindled[#kindled + 1] = f.count
				end
			end

			assert.are.same({ "campfire_7", "campfire_30", "campfire_100", "campfire_365" }, reached)
			assert.are.same({ 800, 365, 365, 3 }, { coins, f.count, f.longest, f.kindling })
			assert.are.same({ 7 }, kindled) -- 2 at Start, 3 at day 7, and capped from then on
			assert.are.same({ 7, 30, 100, 365 }, days(f.milestones))
		end)
	end)

	describe("ns.Campfire.CloseDay", function()
		it("logs a lit day as lit and changes nothing else (TKB-R72)", function()
			local f = fire({ count = 5, kindling = 1, longest = 5, log = { [8] = "lit" } })

			local outcome = ns.Campfire.CloseDay(f, 8, true)

			assert.are.equal("lit", outcome)
			assert.are.same(fire({ count = 5, kindling = 1, longest = 5, log = { [8] = "lit" } }), f)
		end)

		it("burns a Kindling for an unlit day and keeps the count (TKB-R72)", function()
			local f = fire({ count = 5, kindling = 2, longest = 9 })

			local outcome = ns.Campfire.CloseDay(f, 8, false)

			assert.are.equal("burned", outcome)
			assert.are.same(fire({ count = 5, kindling = 1, longest = 9, log = { [8] = "burned" } }), f)
		end)

		it(
			"puts the fire out with no Kindling left: count 0, 2 fresh Kindling, the longest kept (TKB-R72, TKB-R74)",
			function()
				local f = fire({ count = 5, kindling = 0, longest = 9, milestones = { [7] = { day = 1, cast = "x" } } })

				local outcome = ns.Campfire.CloseDay(f, 8, false)

				assert.are.equal("out", outcome)
				assert.are.same(
					fire({
						count = 0,
						kindling = 2,
						longest = 9,
						milestones = { [7] = { day = 1, cast = "x" } },
						log = { [8] = "out" },
					}),
					f
				)
			end
		)

		it("changes nothing for an unlit day with a count of 0 (TKB-R72)", function()
			local f = fire({ kindling = 2, longest = 9 })

			local outcome = ns.Campfire.CloseDay(f, 8, false)

			assert.are.equal("unlit", outcome)
			assert.are.same(fire({ kindling = 2, longest = 9, log = { [8] = "unlit" } }), f)
		end)

		it(
			"burns both Kindling, then goes out, over three unlit days; a goal lights a new fire (TKB-R70, TKB-R72)",
			function()
				local f = fire({ count = 4, kindling = 2, longest = 4 })

				local outcomes = {
					ns.Campfire.CloseDay(f, 1, false),
					ns.Campfire.CloseDay(f, 2, false),
					ns.Campfire.CloseDay(f, 3, false),
					ns.Campfire.CloseDay(f, 4, false),
				}
				ns.Campfire.Light(f, 5, CAST)

				assert.are.same({ "burned", "burned", "out", "unlit" }, outcomes)
				assert.are.same({ 1, 2, 4 }, { f.count, f.kindling, f.longest })
			end
		)
	end)

	describe("the four-week log", function()
		it("keeps the last 28 board days as days are closed (TKB-R106, tackle-board.md › Data)", function()
			local f = fire({ kindling = 2 })

			for day = 1, 40 do
				ns.Campfire.CloseDay(f, day, false)
			end

			local expected = {}
			for day = 13, 40 do
				expected[#expected + 1] = day
			end
			assert.are.same(expected, days(f.log))
		end)

		it("drops the oldest day when a new one is lit (TKB-R106, tackle-board.md › Data)", function()
			local f = fire({ kindling = 2 })
			for day = 1, 28 do
				ns.Campfire.CloseDay(f, day, false)
			end

			ns.Campfire.Light(f, 29, CAST)

			assert.are.same({ 28, 2, "lit" }, { #days(f.log), days(f.log)[1], f.log[29] })
		end)
	end)
end)
