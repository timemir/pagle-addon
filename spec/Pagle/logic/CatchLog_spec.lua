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
	-- The character of LOG-R66's first three test vectors, Oak and the character of its fourth (Dee), and a fixture
	-- catalogue: a fish and a Legend whose Species are 300 mm long, a quest fish, a trophy, a junk item, a Noise fish
	-- and a fish whose Species has no typical length yet.
	local VEE = { guid = "Player-4395-0A1B2C3D", name = "Vee", classID = 1, raceID = 1, realmID = 4395 }
	local OAK = { guid = "Player-4395-0F0E0D0C", name = "Oak", classID = 1, raceID = 3, realmID = 4395 }
	local DEE = { guid = "Player-1-00000001", name = "Dee", classID = 1, raceID = 1, realmID = 1 }
	local ITEMS = {
		[6358] = { category = "fish", species = 6358, typicalLength = 300, legend = false, noise = false },
		[19808] = { category = "fish", species = 19808, typicalLength = 300, legend = true, noise = false },
		[6717] = { category = "questFish", species = 6717, typicalLength = 300, legend = false, noise = false },
		[6309] = { category = "trophy", family = 1, weight = 17, legend = false, noise = false },
		[6303] = { category = "junk", legend = false, noise = false },
		[6291] = { category = "fish", species = 6291, typicalLength = 300, legend = false, noise = true },
		[8365] = { category = "fish", species = 8365, legend = false, noise = false },
	}

	-- A log of these entries by Vee (1), Oak (2) and Dee (3), opened over `items` (ITEMS by default) as its catalogue.
	local function veeLog(entries, items)
		return ns.OpenCatchLog(savedLog(entries, 1, { VEE, OAK, DEE }), {}, nil, function(itemID)
			return (items or ITEMS)[itemID]
		end)
	end

	-- LOG-R66's vectors as Casts: Vee's at 1791731747 tie 0 (its items 1 and 2 are vectors A and B), Vee's at
	-- 1791731762 tie 1 (item 1 is C) and Dee's at 1700000000 tie 0 (item 1 is D), of these items, at this skill rank
	-- (empty for none; 86 by default).
	local AB, C, D = "1|1791731747|0", "1|1791731762|1", "3|1700000000|0"
	local function castOf(items, at, skillRank)
		return ("C1|%s|c|494|1439|1|148|453|%s|25|263|||%s"):format(at or AB, skillRank or "86", items)
	end

	-- A Cast of these items by `char` at `time`, skill 300.
	local function earlier(char, time, items)
		return ("C1|%d|%d|0|c|494|1439|1|148|453|300|0||||%s"):format(char, time, items)
	end

	-- Each item's size, by its position in the Cast; false for none.
	local function sizes(cast)
		local all = {}
		for _, item in ipairs(cast.items) do
			all[item.n] = item.size or false
		end
		return all
	end

	-- Each Cast's sizes (`sizes`) in records, by its entry ID.
	local function sizesById(list)
		local all = {}
		for _, record in ipairs(list) do
			if record.kind == "cast" then
				all[record.id] = sizes(record)
			end
		end
		return all
	end

	it(
		"gives a fish's first Catch its smallest length and a Legend its own, one per Catch (LOG-R65, LOG-R67)",
		function()
			local catchLog = veeLog({ castOf("6358x3,19808x1") })

			-- 0.55 × 300 for the fish; vector B as a Legend: ADR 0010's band and length (LOG-R66's table).
			assert.are.same({ { length = 165, band = 1 }, { length = 453, band = 4 } }, sizes(records(catchLog, 0)[1]))
		end
	)

	it("gives a quest fish a size, and none to a trophy, junk, Noise, an Uncharted item or item 0 (LOG-R65)", function()
		local catchLog = veeLog({ castOf("6717x1,6309x1,6303x2,6291x1,7777x1,0x1", C) })

		assert.are.same(
			{ { length = 165, band = 1 }, false, false, false, false, false },
			sizes(records(catchLog, 0)[1])
		)
	end)

	it("gives none to a Species without a typical length, until the catalogue has one (LOG-R65, LOG-R67)", function()
		assert.are.same({ false }, sizes(records(veeLog({ castOf("8365x1") }), 0)[1]))

		local released = setmetatable({
			[8365] = { category = "fish", species = 8365, typicalLength = 300, legend = false, noise = false },
		}, { __index = ITEMS })
		assert.are.same({ { length = 165, band = 1 } }, sizes(records(veeLog({ castOf("8365x1") }, released), 0)[1]))
	end)

	it(
		"counts the Angler's earlier Catches of the item by slot, on any character, earlier slots of the same Cast"
			.. " included, item 0 and later Catches never (LOG-R65, LOG-R67)",
		function()
			local catchLog = veeLog({
				earlier(1, 1791731000, "6358x5,0x1,6303x1"), -- one slot of 6358, whatever its quantity
				earlier(2, 1791731060, "6358x1,6358x1"), -- Oak's
				"S1|1|1791731100|0|300|300|0",
				"A1|1|1791731110|0|Ledger|note|6358x1", -- a Module record, not a Cast
				"C1|1|1791731120|0|g|494|1439|1|148|453|300|0||||", -- got away
				earlier(1, 1791731180, "6358x1,6358x1,6358x1,6358x1,6358x1,6358x1"),
				castOf("6358x1,6358x2", AB, "300"), -- after 9 Catches, then 10
				castOf("6358x1", C, "300"), -- after 11
			})

			local read = records(catchLog, 0)
			-- R = √(9 ÷ 1,000) on A, p 0.080841; √(10 ÷ 1,000) on B, p 0.099477; √(11 ÷ 1,000) on C, p 0.068376.
			assert.are.same({ { length = 195, band = 1 }, { length = 202, band = 1 } }, sizes(read[#read - 1]))
			assert.are.same({ { length = 191, band = 1 } }, sizes(read[#read]))
		end
	)

	-- Oak's 1,000 Catches of 6358, then Vee's Casts with no skill rank, around Vee's and Oak's Skill Readings.
	local function skillLog()
		local entries = { "S1|1|1791730000|0|150|225|0", "S1|2|1791730001|0|300|300|0" }
		for i = 1, 100 do
			entries[#entries + 1] = earlier(2, 1791730100 + i * 5, ("6358x1,"):rep(9) .. "6358x1")
		end
		entries[#entries + 1] = castOf("6358x1,6358x1", AB, "") -- after 1,000 Catches, then 1,001
		entries[#entries + 1] = "S1|1|1791731750|0|225|300|0"
		entries[#entries + 1] = castOf("6358x1", C, "") -- after 1,002
		entries[#entries + 1] = castOf("6358x1", D, "") -- after 1,003, by Dee, who has no Skill Reading
		entries[#entries + 1] = "S1|1|1791731800|0|300|300|0"
		return entries
	end

	it(
		"takes a Cast without a skill rank at its character's latest Skill Reading before it, else at skill 1"
			.. " (LOG-R65, LOG-R67)",
		function()
			local read = sizesById(records(veeLog(skillLog()), 0))

			-- R = 150 ÷ 300 on A and B (p 0.426070, 0.497383), 225 ÷ 300 on C (p 0.488955), 1 ÷ 300 on D.
			assert.are.same(
				{ { length = 325, band = 2 }, { length = 352, band = 3 } },
				read[VEE.guid .. "-1791731747-0"]
			)
			assert.are.same({ { length = 348, band = 3 } }, read[VEE.guid .. "-1791731762-1"])
			assert.are.same({ { length = 166, band = 1 } }, read[DEE.guid .. "-1700000000-0"])
		end
	)

	it(
		"sizes every Cast read from a later seq, forwards or back, as a read from seq 0 does (LOG-R42, LOG-R65)",
		function()
			local entries = skillLog()
			local whole = sizesById(records(veeLog(entries), 0))
			local shared = veeLog(entries) -- one log read from every seq, its reads kept for the login
			for afterSeq = #entries, 0, -1 do
				for _, catchLog in ipairs({ veeLog(entries), shared }) do
					for id, got in pairs(sizesById(records(catchLog, afterSeq))) do
						assert.are.same(whole[id], got, ("read after seq %d"):format(afterSeq))
					end
					local back = {}
					for cast in catchLog:Reverse("cast", afterSeq) do
						back[#back + 1] = cast
					end
					for id, got in pairs(sizesById(back)) do
						assert.are.same(whole[id], got, ("read back from seq %d"):format(afterSeq))
					end
				end
			end
		end
	)

	it(
		"counts an item the catalogue doesn't know, so classifying it moves no other item's size, and it gets the"
			.. " sizes it would have had (LOG-R65, LOG-R96)",
		function()
			local entries = {
				earlier(1, 1791731000, "6358x1,6358x1,7777x1"),
				castOf("7777x1,6358x1", AB, "300"), -- A: 7777 after 1 Catch; B: 6358 after 2
				castOf("7777x1", C, "300"), -- 7777 after 2
			}
			local function read(items)
				local all = records(veeLog(entries, items), 0)
				return { sizes(all[2]), sizes(all[3]) }
			end
			local fish = { category = "fish", species = 7777, typicalLength = 300, legend = false, noise = false }
			local asOily = { category = "fish", species = 6358, typicalLength = 300, legend = false, noise = false }

			-- R = √(2 ÷ 1,000) on B (p 0.044487), √(1 ÷ 1,000) on A (p 0.026947), √(2 ÷ 1,000) on C (p 0.029156).
			assert.are.same({ { false, { length = 182, band = 1 } }, { false } }, read(ITEMS))
			local classified =
				{ { { length = 175, band = 1 }, { length = 182, band = 1 } }, { { length = 176, band = 1 } } }
			assert.are.same(classified, read(setmetatable({ [7777] = fish }, { __index = ITEMS })))
			assert.are.same(classified, read(setmetatable({ [7777] = asOily }, { __index = ITEMS })))
		end
	)

	it(
		"counts a Cast entry's items whether or not the rest of it decodes, as every reader does (LOG-R16, LOG-R65)",
		function()
			local catchLog = veeLog({
				"C1|1|1791731000|0|c|494|1439|1|148|453|300|0||x||6358x1", -- an events field the codec can't read
				castOf("6358x1", C, "300"), -- after 1 Catch
			})

			local read = records(catchLog, 0)
			assert.are.equal(1, #read)
			-- R = √(1 ÷ 1,000) on C, p 0.020616: 300 × (0.55 + 1.25 × 0.020616) = 172.7.
			assert.are.same({ { length = 173, band = 1 } }, sizes(read[1]))
		end
	)

	it(
		"puts the same sizes on an appended Cast and on that Cast read back either way, counting the log before it"
			.. " (LOG-R42, LOG-R43, LOG-R65)",
		function()
			local catchLog = veeLog({
				earlier(1, 1791731000, "6358x1,6358x1,6358x1"),
				earlier(2, 1791731060, "6358x1,6358x1,6358x1,6358x1,6358x1,6358x1"),
			})
			records(catchLog, 1) -- a read from a later seq first
			catchLog:Reverse("cast", 10)() -- and one back from past the log's end

			local appended = catchLog:Append({
				kind = "cast",
				char = 1,
				time = 1791731747,
				outcome = "caught",
				conditions = { minute = 494, zone = 148, subzone = 453, skillRank = 300, events = {}, auras = {} },
				items = { { itemID = 6358, quantity = 1 }, { itemID = 19808, quantity = 1 } },
			})

			-- R = √(9 ÷ 1,000) on A, as above, and vector B as a Legend.
			local expected = { { length = 195, band = 1 }, { length = 453, band = 4 } }
			assert.are.same(expected, sizes(appended))
			assert.are.same(expected, sizes(records(catchLog, 0)[3]))
			assert.are.same(expected, sizes(records(catchLog, 2)[1]))
			assert.are.same(expected, sizes(catchLog:Reverse("cast")()))
			assert.are.same(expected, sizes(catchLog:Reverse("cast", 10)()))
		end
	)

	it(
		"keeps the earlier Catch counts at the log's end in PagleDB.global.catchCounts, and the next login counts on"
			.. " from them (LOG-R100)",
		function()
			local entries = {
				earlier(1, 1791731000, "6358x1,6358x1,6358x1"),
				earlier(2, 1791731060, "6358x1,6358x1,6358x1,6358x1,6358x1,6358x1"),
			}
			local global = {}
			local saved = savedLog(entries, 1, { VEE, OAK, DEE })
			local catchLog = ns.OpenCatchLog(saved, global, nil, function(itemID)
				return ITEMS[itemID]
			end)
			records(catchLog, 0)

			-- Kept with the log's ID, the size rules and the entry they end at, so another log's are never counted on.
			local function kept(fields)
				return {
					logId = fields.logId or saved.logId,
					rulesVersion = fields.rulesVersion or ns.SIZE_RULES_VERSION,
					seq = fields.seq or 2,
					entry = fields.entry or entries[2],
					counts = { [6358] = fields.oily },
				}
			end
			assert.are.same(kept({ oily = 9 }), global.catchCounts)

			-- The next login, with Vee's Cast of vectors A and B appended at the last, read from seq 2.
			entries[3] = castOf("6358x1,6358x1", AB, "300")
			local function nextLogin(stored)
				global.catchCounts = stored
				local opened = ns.OpenCatchLog(saved, global, nil, function(itemID)
					return ITEMS[itemID]
				end)
				return sizes(records(opened, 2)[1])
			end
			-- After 9 and 10 Catches, as above, whether counted again or on from the kept counts.
			local counted = { { length = 195, band = 1 }, { length = 202, band = 1 } }
			assert.are.same(counted, nextLogin(nil))
			assert.are.same(counted, nextLogin(kept({ oily = 9 })))
			-- Kept counts doctored to 99 show they are counted on from: R = √(99 ÷ 1,000) on A, p 0.268120; √(100 ÷
			-- 1,000) on B, p 0.314572.
			assert.are.same({ { length = 266, band = 2 }, { length = 283, band = 2 } }, nextLogin(kept({ oily = 99 })))
			-- Counts kept for another log, under other size rules, or at an entry that isn't this log's are counted again.
			for _, stale in ipairs({
				kept({ oily = 99, logId = "0000000000000000" }),
				kept({ oily = 99, rulesVersion = ns.SIZE_RULES_VERSION - 1 }),
				kept({ oily = 99, entry = entries[1] }),
				kept({ oily = 99, seq = 4 }),
			}) do
				assert.are.same(counted, nextLogin(stale))
			end
		end
	)

	it("gives no sizes when opened without a catalogue (LOG-R65)", function()
		local catchLog = ns.OpenCatchLog(savedLog({ castOf("6358x1") }, 1, { VEE }), {})

		assert.are.same({ false }, sizes(records(catchLog, 0)[1]))
	end)
end)
