-- The Catch log and its codec (LOG-R10–R16, LOG-R18, LOG-R42, LOG-R97), through ns.OpenCatchLog, the logic/ seam
-- Core's adapter wraps. Per ADR 0003 these specs are also the entry formats' reference examples: each one shows an
-- entry string next to the record it stands for.

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local ADA = "Player-4618-0A1B2C3D"
local BRAM = "Player-4618-0F0E0D0C"

-- A PagleLog as the client loads it from SavedVariables (savedLog), holding Ada, Bram and these entries.
local function adaAndBramLog(entries)
	return savedLog(entries, 1, {
		{ guid = ADA, name = "Ada", classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 },
		{ guid = BRAM, name = "Bram", classID = 1, raceID = 3, faction = "Alliance", realmID = 4618 },
	})
end

-- Every record the log yields after `afterSeq`, in order.
local function records(catchLog, afterSeq)
	local all = {}
	for record in catchLog:Iterate(afterSeq) do
		all[#all + 1] = record
	end
	return all
end

describe("the Catch log codec", function()
	it("decodes catch-log.md's example Cast to the documented values (LOG-R11, LOG-R13, LOG-R16)", function()
		local catchLog =
			ns.OpenCatchLog(adaAndBramLog({ "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1" }), {})

		local id = ADA .. "-1791731747-0"
		assert.are.same({
			{
				seq = 1,
				id = id,
				kind = "cast",
				char = 1,
				time = 1791731747,
				outcome = "caught",
				session = id, -- it opens its Session (LOG-R98)
				conditions = {
					time = 1791731747,
					minute = 494, -- realm 08:14
					-- 15:15:47 UTC, on a realm at UTC-7: Sunday 11 Oct 2026 (LOG-R49)
					date = { year = 2026, month = 10, day = 11, weekday = 1 },
					uiMap = 1439,
					instance = 1,
					zone = 148, -- The Long Wash
					subzone = 453,
					skillRank = 86,
					skillMod = 25,
					lure = 263,
					events = {},
					auras = {},
				},
				items = { { n = 1, itemID = 6358, quantity = 1, catchId = id .. ":1" } }, -- one Oily Blackmouth
			},
		}, records(catchLog, 0))
	end)

	-- Each case appends a record, checks the entry string it wrote, then checks the record read back holds every
	-- field it was given.
	local roundTrips = {
		{
			what = "a caught Cast with every field filled; lists ascending without duplicates, items in slot order",
			rule = "LOG-R11, LOG-R16, Entry formats",
			record = {
				kind = "cast",
				char = 2,
				time = 1791731762,
				outcome = "caught",
				conditions = {
					minute = 1080,
					uiMap = 1429,
					instance = 0,
					zone = 12,
					subzone = 87,
					skillRank = 150,
					skillMod = -5,
					lure = 264,
					events = { 301, 12, 301 },
					auras = { 8087 },
				},
				items = {
					{ itemID = 6303, quantity = 1 },
					{ itemID = 6358, quantity = 2 },
					{ itemID = 6303, quantity = 1 }, -- a repeated item ID keeps its slot
				},
			},
			entry = "C1|2|1791731762|0|c|1080|1429|0|12|87|150|-5|264|12,301|8087|6303x1,6358x2,6303x1",
			conditions = {
				minute = 1080,
				uiMap = 1429,
				instance = 0,
				zone = 12,
				subzone = 87,
				skillRank = 150,
				skillMod = -5,
				lure = 264,
				events = { 12, 301 },
				auras = { 8087 },
			},
			items = { { 6303, 1 }, { 6358, 2 }, { 6303, 1 } },
		},
		{
			what = "a got-away Cast with every optional field empty and zone and subzone 0",
			rule = "LOG-R11, LOG-R16, LOG-R93, Entry formats",
			record = {
				kind = "cast",
				char = 1,
				time = 1791731800,
				outcome = "gotAway",
				conditions = { zone = 0, subzone = 0, events = {}, auras = {} },
				items = {},
			},
			entry = "C1|1|1791731800|0|g||||0|0||||||",
			conditions = { zone = 0, subzone = 0, events = {}, auras = {} },
			items = {},
		},
		{
			what = "a Cast whose secret zone and subzone are nil, stored as 0, and a secret item, stored as item 0",
			rule = "LOG-R8, LOG-R93, Entry formats",
			record = {
				kind = "cast",
				char = 1,
				time = 1791731900,
				outcome = "caught",
				conditions = { minute = 0, events = {}, auras = {} },
				items = { { itemID = 0, quantity = 1 } },
			},
			entry = "C1|1|1791731900|0|c|0|||0|0||||||0x1",
			conditions = { minute = 0, zone = 0, subzone = 0, events = {}, auras = {} },
			items = { { 0, 1 } },
		},
	}

	for _, case in ipairs(roundTrips) do
		it("round-trips " .. case.what .. " (" .. case.rule .. ")", function()
			local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

			local appended = catchLog:Append(case.record)

			assert.are.same({ case.entry }, catchLog.data.entries)
			local read = records(catchLog, 0)[1]
			assert.are.same(appended, read)
			assert.are.equal(case.record.kind, read.kind)
			assert.are.equal(case.record.char, read.char)
			assert.are.equal(case.record.time, read.time)
			assert.are.equal(case.record.outcome, read.outcome)
			local conditions = {}
			for key, value in pairs(read.conditions) do
				conditions[key] = value
			end
			assert.are.equal(case.record.time, conditions.time)
			assert.are.same(conditions.minute and ns.RealmDate(read.time, conditions.minute), conditions.date)
			conditions.time, conditions.date = nil, nil
			assert.are.same(case.conditions, conditions)
			local items = {}
			for n, item in ipairs(read.items) do
				assert.are.equal(n, item.n)
				assert.are.equal(read.id .. ":" .. n, item.catchId) -- LOG-R13
				items[n] = { item.itemID, item.quantity }
			end
			assert.are.same(case.items, items)
		end)
	end

	it("round-trips a Skill Reading (LOG-R11, LOG-R16, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		catchLog:Append({ kind = "skill", char = 1, time = 1791731680, rank = 86, max = 150, mod = 0 })

		assert.are.same({ "S1|1|1791731680|0|86|150|0" }, catchLog.data.entries)
		assert.are.same({
			{
				seq = 1,
				id = ADA .. "-1791731680-0",
				kind = "skill",
				char = 1,
				time = 1791731680,
				rank = 86,
				max = 150,
				mod = 0,
			},
		}, records(catchLog, 0))
	end)

	it("round-trips a build entry (LOG-R11, LOG-R16, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		catchLog:Append({ kind = "build", char = 2, time = 1791731681, build = 70338, version = "1.60.1" })

		assert.are.same({ "B1|2|1791731681|0|70338|1.60.1" }, catchLog.data.entries)
		assert.are.same({
			{
				seq = 1,
				id = BRAM .. "-1791731681-0",
				kind = "build",
				char = 2,
				time = 1791731681,
				build = 70338,
				version = "1.60.1",
			},
		}, records(catchLog, 0))
	end)

	it("raises an error in the caller and appends nothing for a record it can't write (LOG-R16)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})
		local unwritable = {
			{ kind = "prestige", char = 1, time = 1791731680, rank = 1 }, -- not a kind M1 writes
			{ kind = "skill", char = 3, time = 1791731680, rank = 86, max = 150, mod = 0 }, -- no character 3
			{ kind = "skill", char = 1, time = 1791731680.5, rank = 86, max = 150, mod = 0 },
			{ kind = "build", char = 1, time = 1791731680, build = 70338, version = "1.60|1" },
			{ kind = "cast", char = 1, time = 1791731680, outcome = "lost", conditions = {}, items = {} },
			{
				kind = "cast",
				char = 1,
				time = 1791731680,
				outcome = "caught",
				conditions = {},
				items = { { itemID = 6358, quantity = 1.5 } },
			},
		}
		for _, record in ipairs(unwritable) do
			assert.has_error(function()
				catchLog:Append(record)
			end)
		end
		assert.are.same({}, catchLog.data.entries)
	end)
end)

describe("an entry the codec can't decode", function()
	local undecodable = {
		"P1|1|1791731700|0|1", -- a tag M1 doesn't read
		"C1|1|1791731700|0|c|494|1439|1|148|453|86|25|263|||6358x1|extra", -- one field too many
		"S1|9|1791731700|0|86|150|0", -- no character 9
		"S1|1|1791731700|0|86|max|0",
		"C1|1|1791731700|0|c|494|1439|1|148|453|86|25|263|||6358",
		42,
	}

	for _, bad in ipairs(undecodable) do
		it(("is skipped by every reader and counted once per login: %s (LOG-R16)"):format(tostring(bad)), function()
			local global = { decodeErrors = 0 }
			local saved = adaAndBramLog({ "S1|1|1791731680|0|86|150|0", bad, "S1|1|1791731690|0|87|150|0" })
			local catchLog = ns.OpenCatchLog(saved, global)

			for _ = 1, 3 do
				local read = records(catchLog, 0)
				assert.are.same({ 1, 3 }, { read[1].seq, read[2].seq })
				assert.are.equal(2, #read)
			end
			assert.are.equal(1, global.decodeErrors)

			local nextLogin = ns.OpenCatchLog(saved, global)
			records(nextLogin, 0)
			records(nextLogin, 1)
			assert.are.equal(2, global.decodeErrors)
		end)
	end

	it("starts the count at 0 in a PagleDB that has none (LOG-R16)", function()
		local global = {}
		records(ns.OpenCatchLog(adaAndBramLog({ "X9|1|1791731700|0" }), global), 0)
		assert.are.equal(1, global.decodeErrors)
	end)
end)

describe("iterating the log", function()
	local function skillAt(time)
		return ("S1|1|%d|0|86|150|0"):format(time)
	end

	it("yields the entries with seq > afterSeq, in order (LOG-R14, LOG-R42)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog({ skillAt(1), skillAt(2), skillAt(3), skillAt(4) }), {})

		local seqs = {}
		for _, record in ipairs(records(catchLog, 2)) do
			seqs[#seqs + 1] = record.seq
		end
		assert.are.same({ 3, 4 }, seqs)
		assert.are.equal(4, #records(catchLog, nil))
		assert.are.same({}, records(catchLog, 4))
	end)

	it("stops at the log's length when called, never at entries appended meanwhile (LOG-R42)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog({ skillAt(1), skillAt(2) }), {})

		local seqs = {}
		for record in catchLog:Iterate(0) do
			seqs[#seqs + 1] = record.seq
			catchLog:Append({ kind = "skill", char = 1, time = 10 + record.seq, rank = 86, max = 150, mod = 0 })
		end
		assert.are.same({ 1, 2 }, seqs)
		assert.are.equal(4, #catchLog.data.entries)
	end)

	it("gives each appended entry the next seq; the log only grows (LOG-R14)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog({ skillAt(1) }), {})

		local appended = catchLog:Append({ kind = "skill", char = 1, time = 2, rank = 87, max = 150, mod = 0 })

		assert.are.equal(2, appended.seq)
		assert.are.same({ skillAt(1), "S1|1|2|0|87|150|0" }, catchLog.data.entries)
	end)
end)

describe("opening PagleLog", function()
	local NOW = 1791731700

	it("starts an empty log on a fresh install, without a chat line (LOG-R10, LOG-R18)", function()
		local catchLog, started = ns.OpenCatchLog(nil, {}, NOW)

		assert.are.same({ format = 1, characters = {}, entries = {} }, catchLog.data)
		assert.is_false(started)
	end)

	it("keeps a log in the codec's format as it is (LOG-R14, LOG-R18)", function()
		local saved = adaAndBramLog({ "S1|1|1791731680|0|86|150|0" })
		local before = adaAndBramLog({ "S1|1|1791731680|0|86|150|0" })

		local catchLog, started = ns.OpenCatchLog(saved, {}, NOW)

		assert.are.equal(saved, catchLog.data)
		assert.are.same(before, catchLog.data)
		assert.is_false(started)
	end)

	for _, format in ipairs({ 0, 2, "nil" }) do
		it(("starts a new log from one in format %s, keeping the characters (LOG-R18)"):format(format), function()
			local saved = adaAndBramLog({ "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1" })
			saved.format = tonumber(format)
			saved.stale = true
			local characters = saved.characters

			local catchLog, started = ns.OpenCatchLog(saved, {}, NOW)

			assert.is_true(started)
			assert.are.equal(characters, catchLog.data.characters)
			assert.are.same({}, catchLog.data.entries)
			assert.are.equal(1, catchLog.data.format)
			assert.is_nil(catchLog.data.stale)
			assert.are.matches("^[0-9a-f]+$", catchLog.data.logId)
			assert.are.equal(16, #catchLog.data.logId)
			assert.are_not.equal("3f9a2c1e7b0d4a65", catchLog.data.logId)
		end)
	end
end)

describe("the logId", function()
	local function firstSkill(catchLog)
		catchLog:Append({ kind = "skill", char = 1, time = 1791731680, rank = 1, max = 75, mod = 0 })
	end

	it("is 16 lowercase hex characters, created with the log's first character (LOG-R15)", function()
		local catchLog = ns.OpenCatchLog(nil, {}, 1791731600)
		assert.is_nil(catchLog.data.logId)
		catchLog.data.characters[1] = { guid = ADA }

		firstSkill(catchLog)

		assert.are.matches("^[0-9a-f]+$", catchLog.data.logId)
		assert.are.equal(16, #catchLog.data.logId)
	end)

	it("is created once and never changes (LOG-R15)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {}, 1791731600)
		firstSkill(catchLog)
		firstSkill(catchLog)
		assert.are.equal("3f9a2c1e7b0d4a65", catchLog.data.logId)
		assert.are.equal("3f9a2c1e7b0d4a65", ns.OpenCatchLog(catchLog.data, {}, 1791731900).data.logId)
	end)

	it("differs between two logs started by the same character at the same second (LOG-R15, LOG-R97)", function()
		local logIds = {}
		for i = 1, 2 do
			local catchLog = ns.OpenCatchLog(nil, {}, 1791731600)
			catchLog.data.characters[1] = { guid = ADA }
			firstSkill(catchLog)
			logIds[i] = catchLog.data.logId
		end
		assert.are_not.equal(logIds[1], logIds[2])
	end)
end)

describe("the tie counter", function()
	local function skill(char, time)
		return { kind = "skill", char = char, time = time, rank = 86, max = 150, mod = 0 }
	end

	it("is 0, then one more than the highest, for entries with the same character and time (LOG-R12)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		local first = catchLog:Append(skill(1, 1791731680))
		local second = catchLog:Append(skill(1, 1791731680))
		local third = catchLog:Append(skill(1, 1791731680))

		assert.are.same({ ADA .. "-1791731680-0", ADA .. "-1791731680-1", ADA .. "-1791731680-2" }, {
			first.id,
			second.id,
			third.id,
		})
		assert.are.same({
			"S1|1|1791731680|0|86|150|0",
			"S1|1|1791731680|1|86|150|0",
			"S1|1|1791731680|2|86|150|0",
		}, catchLog.data.entries)
	end)

	it("is 0 for a different character at the same second, and for the next second (LOG-R12)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		catchLog:Append(skill(1, 1791731680))
		local otherCharacter = catchLog:Append(skill(2, 1791731680))
		local nextSecond = catchLog:Append(skill(1, 1791731681))

		assert.are.equal(BRAM .. "-1791731680-0", otherCharacter.id)
		assert.are.equal(ADA .. "-1791731681-0", nextSecond.id)
	end)

	it("counts entries already in the log from an earlier load (LOG-R12)", function()
		local catchLog =
			ns.OpenCatchLog(adaAndBramLog({ "S1|1|1791731680|0|86|150|0", "S1|2|1791731680|0|86|150|0" }), {})

		assert.are.equal(ADA .. "-1791731680-1", catchLog:Append(skill(1, 1791731680)).id)
	end)
end)
