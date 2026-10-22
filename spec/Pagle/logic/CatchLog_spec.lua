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

	it("round-trips a Prestige with its Activity XP (LOG-R11, LOG-R16, LOG-R38, AXP-R5, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		catchLog:Append({ kind = "prestige", char = 1, time = 1791731682, rank = 2, activityXP = 1850 })

		assert.are.same({ "P1|1|1791731682|0|2|1850" }, catchLog.data.entries)
		assert.are.same({
			{
				seq = 1,
				id = ADA .. "-1791731682-0",
				kind = "prestige",
				char = 1,
				time = 1791731682,
				rank = 2,
				activityXP = 1850,
			},
		}, records(catchLog, 0))
	end)

	it("writes a Prestige appended without Activity XP with 0 (LOG-R38, AXP-R5, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		local appended = catchLog:Append({ kind = "prestige", char = 1, time = 1791731682, rank = 1 })

		assert.are.same({ "P1|1|1791731682|0|1|0" }, catchLog.data.entries)
		assert.are.equal(0, appended.activityXP)
	end)

	it("reads a pre-1.0 Prestige without the activityXP field as 0 (LOG-R38, AXP-R5, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog({ "P1|1|1791731682|0|2" }), {})

		assert.are.same({
			{
				seq = 1,
				id = ADA .. "-1791731682-0",
				kind = "prestige",
				char = 1,
				time = 1791731682,
				rank = 2,
				activityXP = 0,
			},
		}, records(catchLog, 0))
		assert.are.equal(1, catchLog:Prestiges())
	end)

	it("round-trips a purchase (LOG-R11, LOG-R16, LOG-R39, SHOP-R10, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		catchLog:Append({ kind = "purchase", char = 2, time = 1791731683, good = "core.toaststyle.ripple", price = 150 })

		assert.are.same({ "U1|2|1791731683|0|core.toaststyle.ripple|150" }, catchLog.data.entries)
		assert.are.same({
			{
				seq = 1,
				id = BRAM .. "-1791731683-0",
				kind = "purchase",
				char = 2,
				time = 1791731683,
				good = "core.toaststyle.ripple",
				price = 150,
			},
		}, records(catchLog, 0))
	end)

	it(
		"round-trips a Module record whose payload holds | and ; verbatim, to the Module that wrote it"
			.. " (LOG-R11, LOG-R16, LOG-R40, LOG-R42, Entry formats)",
		function()
			local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})
			local payload = "n|haul;1;30|1429;e|x" -- everything after the 6th |, verbatim

			catchLog:Append({
				kind = "module",
				char = 2,
				time = 1791731684,
				module = "TackleBoard",
				recordKind = "issue.v1",
				payload = payload,
			})

			assert.are.same({ "A1|2|1791731684|0|TackleBoard|issue.v1|n|haul;1;30|1429;e|x" }, catchLog.data.entries)
			local read = {}
			for record in catchLog:Iterate(0, "TackleBoard") do
				read[#read + 1] = record
			end
			assert.are.same({
				{
					seq = 1,
					id = BRAM .. "-1791731684-0",
					kind = "module",
					char = 2,
					time = 1791731684,
					module = "TackleBoard",
					recordKind = "issue.v1",
					payload = payload,
				},
			}, read)
		end
	)

	it("round-trips a Module record with an empty payload (LOG-R40, Entry formats)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})

		local record = catchLog:Append({
			kind = "module",
			char = 1,
			time = 1791731685,
			module = "TackleBoard",
			recordKind = "start",
			payload = "",
		})

		assert.are.same({ "A1|1|1791731685|0|TackleBoard|start|" }, catchLog.data.entries)
		assert.are.same({ "module", "TackleBoard", "start", "" }, {
			record.kind,
			record.module,
			record.recordKind,
			record.payload,
		})
	end)

	it("raises an error in the caller and appends nothing for a record it can't write (LOG-R16)", function()
		local catchLog = ns.OpenCatchLog(adaAndBramLog(), {})
		local function moduleRecord(module, recordKind, payload)
			local record = { kind = "module", char = 1, time = 1791731680 }
			record.module, record.recordKind, record.payload = module, recordKind, payload
			return record
		end
		local unwritable = {
			moduleRecord("TackleBoard", "bad kind", "x"), -- a kind outside [%w_.]+ (LOG-R40)
			moduleRecord("TackleBoard", "", "x"),
			moduleRecord("TackleBoard", "re|roll", "x"),
			moduleRecord("TackleBoard", nil, "x"),
			moduleRecord("TackleBoard", "day", "two\nlines"), -- a newline (LOG-R40)
			moduleRecord("TackleBoard", "day", ("x"):rep(201)), -- over 200 bytes (LOG-R40, Tunables)
			moduleRecord("TackleBoard", "day", 7), -- not a string
			moduleRecord("TackleBoard", "day", nil),
			moduleRecord("", "day", "x"), -- no Module
			moduleRecord("Tackle|Board", "day", "x"),
			moduleRecord(nil, "day", "x"),
			{ kind = "prestige", char = 1, time = 1791731680, rank = 0 }, -- ranks start at 1
			{ kind = "prestige", char = 1, time = 1791731680, rank = 1.5 },
			{ kind = "prestige", char = 1, time = 1791731680, rank = 1, activityXP = 12.5 }, -- AXP-R5
			{ kind = "purchase", char = 1, time = 1791731680, good = "core.toast style", price = 150 },
			{ kind = "purchase", char = 1, time = 1791731680, good = "core.crest|x", price = 150 },
			{ kind = "purchase", char = 1, time = 1791731680, good = "", price = 150 },
			{ kind = "purchase", char = 1, time = 1791731680, good = "core.crest.otter", price = -5 },
			{ kind = "purchase", char = 1, time = 1791731680, good = "core.crest.otter", price = "150" },
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
		"A1|1|1791731700|0|TackleBoard|bad kind|x", -- a Module record's kind outside [%w_.]+ (LOG-R40)
		"A1|1|1791731700|0|TackleBoard||x", -- no kind
		"A1|1|1791731700|0|TackleBoard|day", -- no payload field
		"A1|1|1791731700|0|TackleBoard", -- no kind or payload
		"A1|1|1791731700|0||day|x", -- no Module
		"A1|9|1791731700|0|TackleBoard|day|x", -- no character 9
		"C1|1|1791731700|0|c|494|1439|1|148|453|86|25|263|||6358x1|extra", -- one field too many
		"P1|1|1791731700|0|", -- no rank
		"P1|1|1791731700|0|0", -- ranks start at 1
		"P1|1|1791731700|0|one",
		"P1|1|1791731700|0|1|", -- an empty activityXP: absent is 0, empty is no number (AXP-R5)
		"P1|1|1791731700|0|1|lots",
		"P1|1|1791731700|0|1|-5",
		"P1|1|1791731700|0|1|2|3", -- one field too many
		"U1|1|1791731700|0|core.toast style|150", -- a good ID outside [%w_.]+
		"U1|1|1791731700|0||150",
		"U1|1|1791731700|0|core.crest.otter|lots", -- a price that isn't a number
		"U1|1|1791731700|0|core.crest.otter|-5",
		"U1|1|1791731700|0|core.crest.otter|1.5",
		"U1|1|1791731700|0|core.crest.otter",
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

	it("yields Prestiges and purchases in seq order beside Casts, Skill Readings and builds (LOG-R42)", function()
		local catchLog = ns.OpenCatchLog(
			adaAndBramLog({
				"B1|1|1791731680|0|70338|1.60.1",
				"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
				"P1|1|1791731750|0|1",
				"S1|1|1791731751|0|87|150|0",
				"U1|2|1791731752|0|core.crest.otter|300",
				"C1|1|1791731760|0|g|494|1439|1|148|453|87|25|263|||",
			}),
			{}
		)

		local seen = {}
		for _, record in ipairs(records(catchLog, 0)) do
			seen[#seen + 1] = record.seq .. " " .. record.kind
		end
		assert.are.same({ "1 build", "2 cast", "3 prestige", "4 skill", "5 purchase", "6 cast" }, seen)
	end)

	describe("with Module records", function()
		local function withRecords()
			return ns.OpenCatchLog(
				adaAndBramLog({
					"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
					"A1|1|1791731748|0|TackleBoard|start|",
					"A1|1|1791731749|0|Ledger|note|x", -- another Module's
					"A1|1|1791731750|0|TackleBoard|issue|n|haul",
					"C1|1|1791731760|0|g|494|1439|1|148|453|87|25|263|||",
				}),
				{ decodeErrors = 0 }
			)
		end

		local function seen(iterate)
			local list = {}
			for record in iterate do
				list[#list + 1] = record.seq .. " " .. record.kind .. (record.module and (" " .. record.module) or "")
			end
			return list
		end

		it("yields none to a reader that names no Module: Pagle.IterateCatches (LOG-R42)", function()
			local catchLog = withRecords()

			assert.are.same({ "1 cast", "5 cast" }, seen(catchLog:Iterate(0)))
			assert.are.equal(0, catchLog.global.decodeErrors) -- skipped, not undecodable (LOG-R41)
		end)

		it("yields a Module its own records in seq order, never another Module's (LOG-R41, LOG-R42)", function()
			local catchLog = withRecords()

			assert.are.same(
				{ "1 cast", "2 module TackleBoard", "4 module TackleBoard", "5 cast" },
				seen(catchLog:Iterate(0, "TackleBoard"))
			)
			assert.are.same({ "4 module TackleBoard", "5 cast" }, seen(catchLog:Iterate(3, "TackleBoard")))
			assert.are.same({ "1 cast", "3 module Ledger", "5 cast" }, seen(catchLog:Iterate(0, "Ledger")))
			assert.are.same({ "1 cast", "5 cast" }, seen(catchLog:Iterate(0, "Stats")))
			assert.are.equal(0, catchLog.global.decodeErrors)
		end)

		it("leaves Casts' Sessions as they are without the records (LOG-R98)", function()
			local catchLog = withRecords()
			local sessions = {}
			for record in catchLog:Iterate(2, "TackleBoard") do
				sessions[#sessions + 1] = record.session or "-"
			end

			local first
			for record in catchLog:Iterate(0) do
				first = first or record.session
			end
			assert.are.same({ "-", first }, sessions)
		end)
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

describe("the Simulated Size on decoded Casts", function()
	-- The character of LOG-R66's test vectors, and a fixture catalogue: a fish and a Legend whose Species are 300 mm
	-- long, a quest fish, a trophy, a junk item, a Noise fish and a fish whose Species has no typical length yet.
	local VEE = { guid = "Player-4395-0A1B2C3D", name = "Vee", classID = 1, raceID = 1, realmID = 4395 }
	local ITEMS = {
		[6358] = { category = "fish", species = 6358, typicalLength = 300, legend = false, noise = false },
		[19808] = { category = "fish", species = 19808, typicalLength = 300, legend = true, noise = false },
		[6717] = { category = "questFish", species = 6717, typicalLength = 300, legend = false, noise = false },
		[6309] = { category = "trophy", family = 1, weight = 17, legend = false, noise = false },
		[6303] = { category = "junk", legend = false, noise = false },
		[6291] = { category = "fish", species = 6291, typicalLength = 300, legend = false, noise = true },
		[8365] = { category = "fish", species = 8365, legend = false, noise = false },
	}

	-- A log of Vee's entries, opened over `items` (ITEMS by default) as its catalogue.
	local function veeLog(entries, items)
		return ns.OpenCatchLog(savedLog(entries, 1, { VEE }), {}, nil, function(itemID)
			return (items or ITEMS)[itemID]
		end)
	end

	-- A Cast of Vee's at 1791731747 (LOG-R66's first two vectors) or 1791731762 with tie 1 (its third), of these items.
	local function castOf(items, third)
		return ("C1|1|%s|c|494|1439|1|148|453|86|25|263|||%s"):format(third and "1791731762|1" or "1791731747|0", items)
	end

	-- Each item's size, by its position in the Cast; false for none.
	local function sizes(cast)
		local all = {}
		for _, item in ipairs(cast.items) do
			all[item.n] = item.size or false
		end
		return all
	end

	it("gives a fish and a Legend LOG-R66's sizes, one per Catch whatever its quantity (LOG-R65, LOG-R66)", function()
		local catchLog = veeLog({ castOf("6358x3,19808x1") })

		assert.are.same({ { length = 314, band = 2 }, { length = 453, band = 4 } }, sizes(records(catchLog, 0)[1]))
	end)

	it("gives a quest fish a size, and none to a trophy, junk, Noise, an Uncharted item or item 0 (LOG-R65)", function()
		local catchLog = veeLog({ castOf("6717x1,6309x1,6303x2,6291x1,7777x1,0x1", true) })

		assert.are.same(
			{ { length = 249, band = 2 }, false, false, false, false, false },
			sizes(records(catchLog, 0)[1])
		)
	end)

	it("gives none to a Species without a typical length, until the catalogue has one (LOG-R65, LOG-R67)", function()
		assert.are.same({ false }, sizes(records(veeLog({ castOf("8365x1") }), 0)[1]))

		local released = setmetatable({
			[8365] = { category = "fish", species = 8365, typicalLength = 300, legend = false, noise = false },
		}, { __index = ITEMS })
		assert.are.same({ { length = 314, band = 2 } }, sizes(records(veeLog({ castOf("8365x1") }, released), 0)[1]))
	end)

	it(
		"gives an Uncharted Catch, once a release classifies it, the size it would have had (LOG-R96, LOG-R65)",
		function()
			local items = {}
			local catchLog = veeLog({ castOf("7777x1") }, items)
			assert.are.same({ false }, sizes(records(catchLog, 0)[1]))

			items[7777] = { category = "fish", species = 7777, typicalLength = 300, legend = false, noise = false }

			assert.are.same({ { length = 314, band = 2 } }, sizes(records(catchLog, 0)[1]))
		end
	)

	it(
		"puts the same sizes on an appended Cast and on that Cast read back either way (LOG-R42, LOG-R43, LOG-R65)",
		function()
			local catchLog = veeLog({})

			local appended = catchLog:Append({
				kind = "cast",
				char = 1,
				time = 1791731747,
				outcome = "caught",
				conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
				items = { { itemID = 6358, quantity = 1 }, { itemID = 19808, quantity = 1 } },
			})

			local expected = { { length = 314, band = 2 }, { length = 453, band = 4 } }
			assert.are.same(expected, sizes(appended))
			assert.are.same(expected, sizes(records(catchLog, 0)[1]))
			assert.are.same(expected, sizes(catchLog:Reverse("cast")()))
		end
	)

	it("gives no sizes when opened without a catalogue (LOG-R65)", function()
		local catchLog = ns.OpenCatchLog(savedLog({ castOf("6358x1") }, 1, { VEE }), {})

		assert.are.same({ false }, sizes(records(catchLog, 0)[1]))
	end)
end)

describe("the variety on decoded Casts", function()
	-- The character of VAR-R3's test vectors, and a fixture catalogue: a fish whose Species lists its ten varieties, a
	-- Legend that would list them too, and a fish whose Species lists none.
	local VEE = { guid = "Player-4395-0A1B2C3D", name = "Vee", classID = 1, raceID = 1, realmID = 4395 }
	local KEYS = { "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k10" }
	local ITEMS = {
		[6359] = {
			category = "fish",
			species = 6359,
			typicalLength = 300,
			legend = false,
			noise = false,
			varieties = KEYS,
		},
		[19808] = {
			category = "fish",
			species = 19808,
			typicalLength = 300,
			legend = true,
			noise = false,
			varieties = KEYS,
		},
		[6358] = { category = "fish", species = 6358, typicalLength = 300, legend = false, noise = false },
		[6303] = { category = "junk", legend = false, noise = false },
	}

	-- A log of Vee's entries, opened over `items` (ITEMS by default) as its catalogue.
	local function veeLog(entries, items)
		return ns.OpenCatchLog(savedLog(entries, 1, { VEE }), {}, nil, function(itemID)
			return (items or ITEMS)[itemID]
		end)
	end

	-- A Cast of Vee's at 1791731747 (VAR-R3's first two vectors) or 1791731762 with tie 1 (its third), of these items.
	local function castOf(items, third)
		return ("C1|1|%s|c|494|1439|1|148|453|86|25|263|||%s"):format(third and "1791731762|1" or "1791731747|0", items)
	end

	-- Each item's variety, by its position in the Cast; false for none.
	local function varieties(cast)
		local all = {}
		for _, item in ipairs(cast.items) do
			all[item.n] = item.variety or false
		end
		return all
	end

	it(
		"gives each Catch of a Species with varieties VAR-R3's, whatever its quantity, beside its size (VAR-R4)",
		function()
			local cast = records(veeLog({ castOf("6359x3,6359x1") }), 0)[1]

			assert.are.same({
				{ id = "6359.k9", index = 9, rarity = "rare" },
				{ id = "6359.k1", index = 1, rarity = "common" },
			}, varieties(cast))
			assert.is_table(cast.items[1].size)
		end
	)

	it("gives none to a Legend, a Species without varieties, junk, an Uncharted item or item 0 (VAR-R1)", function()
		local cast = records(veeLog({ castOf("19808x1,6358x1,6303x1,7777x1,0x1", true) }), 0)[1]

		assert.are.same({ false, false, false, false, false }, varieties(cast))
		assert.is_table(cast.items[1].size) -- a Legend keeps its size (LOG-R65)
	end)

	it(
		"gives an Uncharted Catch, once a release classifies it, the variety it would have had (VAR-R1, VAR-R90)",
		function()
			local items = {}
			local catchLog = veeLog({ castOf("7777x1", true) }, items)
			assert.are.same({ false }, varieties(records(catchLog, 0)[1]))

			items[7777] = {
				category = "fish",
				species = 7777,
				typicalLength = 300,
				legend = false,
				noise = false,
				varieties = KEYS,
			}

			assert.are.same({ { id = "7777.k10", index = 10, rarity = "epic" } }, varieties(records(catchLog, 0)[1]))
		end
	)

	it("puts the same varieties on an appended Cast and on that Cast read back either way (VAR-R4, LOG-R43)", function()
		local catchLog = veeLog({})

		local appended = catchLog:Append({
			kind = "cast",
			char = 1,
			time = 1791731747,
			outcome = "caught",
			conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
			items = { { itemID = 6359, quantity = 1 }, { itemID = 6359, quantity = 2 } },
		})

		local expected =
			{ { id = "6359.k9", index = 9, rarity = "rare" }, { id = "6359.k1", index = 1, rarity = "common" } }
		assert.are.same(expected, varieties(appended))
		assert.are.same(expected, varieties(records(catchLog, 0)[1]))
		assert.are.same(expected, varieties(catchLog:Reverse("cast")()))
	end)

	it("gives no varieties when opened without a catalogue (VAR-R4)", function()
		local catchLog = ns.OpenCatchLog(savedLog({ castOf("6359x1") }, 1, { VEE }), {})

		assert.are.same({ false }, varieties(records(catchLog, 0)[1]))
	end)
end)
