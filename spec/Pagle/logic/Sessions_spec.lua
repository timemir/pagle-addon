-- Sessions (LOG-R60–R64, LOG-R95, LOG-R98): cut from the Catch log by Core's logic/, through the seams Core's
-- adapter wraps: the session tag on the records ns.OpenCatchLog's Iterate and Append hand out, the latest Session
-- the log holds (catchLog:Session), and the live Session events (ns.NewSessionTracker).

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local ADA = "Player-4618-0A1B2C3D"
local BRAM = "Player-4618-0F0E0D0C"
local T = 1791731000

-- A PagleLog holding Ada, Bram and these entries.
local function log(entries)
	return savedLog(entries, 1, {
		{ guid = ADA, name = "Ada", classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 },
		{ guid = BRAM, name = "Bram", classID = 1, raceID = 3, faction = "Alliance", realmID = 4618 },
	})
end

-- A caught Cast entry by character `char` at T + `at`, in zone/subzone, with `items` ("6358x1,6303x2").
local function cast(at, char, zone, subzone, items)
	return ("C1|%d|%d|0|c|494|1439|1|%d|%d|86|25|263|||%s"):format(
		char or 1,
		T + at,
		zone or 148,
		subzone or 453,
		items or "6358x1"
	)
end

-- A got-away Cast entry by Ada at T + `at`.
local function gotAway(at)
	return ("C1|1|%d|0|g|494|1439|1|148|453|86|25|263|||"):format(T + at)
end

-- A Skill Reading entry by Ada at T + `at`.
local function skill(at)
	return ("S1|1|%d|0|80|150|0"):format(T + at)
end

-- The entry ID of Ada's entry at T + `at` (LOG-R13).
local function idAt(at, guid)
	return ("%s-%d-0"):format(guid or ADA, T + at)
end

-- Each record's `session` after `afterSeq`, by seq; `false` for none.
local function tags(catchLog, afterSeq)
	local all = {}
	for record in catchLog:Iterate(afterSeq) do
		local session = record.session
		if session == nil then
			session = false
		end
		all[record.seq] = session
	end
	return all
end

describe("cutting Sessions", function()
	it("keeps Casts 899 s apart in one Session and splits Casts 900 s apart (LOG-R60)", function()
		local catchLog = ns.OpenCatchLog(log({ cast(0), cast(899), cast(1799) }), {})

		assert.are.same({ idAt(0), idAt(0), idAt(1799) }, tags(catchLog, 0))
	end)

	it("doesn't split one for a character switch, a zone change or a reload between Casts (LOG-R60)", function()
		local catchLog = ns.OpenCatchLog(
			log({
				cast(0),
				cast(600, 2), -- Bram, on another login
				"B1|2|1791731700|0|70338|1.60.1", -- a reload in between: a build entry
				cast(1200, 2, 1519, 0), -- Stormwind
				cast(2000, 1),
			}),
			{}
		)

		assert.are.same({ idAt(0), idAt(0), false, idAt(0), idAt(0) }, tags(catchLog, 0))
	end)

	it("keeps a Session that crosses realm midnight as one (LOG-R95)", function()
		-- realm 23:58, then 00:06 the next day, 480 s later
		local catchLog = ns.OpenCatchLog(
			log({
				("C1|1|%d|0|c|1438|1439|1|148|453|86|25|263|||6358x1"):format(T),
				("C1|1|%d|0|c|6|1439|1|148|453|86|25|263|||6358x1"):format(T + 480),
			}),
			{}
		)

		assert.are.same({ idAt(0), idAt(0) }, tags(catchLog, 0))
	end)

	it("tags a Skill Reading with the Session open when it was appended, else with none (LOG-R98)", function()
		local catchLog = ns.OpenCatchLog(log({ skill(0), cast(10), skill(909), skill(910), cast(2000) }), {})

		assert.are.same({ false, idAt(10), idAt(10), false, idAt(2000) }, tags(catchLog, 0))
	end)

	it("gives a Skill Reading before a new Session's first Cast no session (LOG-R98)", function()
		local catchLog = ns.OpenCatchLog(log({ cast(0), skill(1000), cast(1001) }), {})

		assert.are.same({ idAt(0), false, idAt(1001) }, tags(catchLog, 0))
	end)

	it("tags the same whether the log is read from seq 0 or from any later afterSeq (LOG-R98)", function()
		local catchLog = ns.OpenCatchLog(
			log({ cast(0), skill(5), cast(300), cast(890, 2), skill(1700), cast(2000), skill(2100), cast(2500) }),
			{}
		)
		local whole = tags(catchLog, 0)

		for afterSeq = 1, 8 do
			local part = tags(catchLog, afterSeq)
			for seq = afterSeq + 1, 8 do
				assert.are.equal(whole[seq], part[seq], ("seq %d read after %d"):format(seq, afterSeq))
			end
		end
	end)

	it("tags each Cast and Skill Reading Append returns as reading the log back does (LOG-R98)", function()
		local catchLog = ns.OpenCatchLog(log({ cast(0), skill(5) }), {})
		local conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} }
		local function append(record)
			return catchLog:Append(record).session or false
		end

		local appended = {
			append({ kind = "cast", char = 1, time = T + 600, outcome = "caught", conditions = conditions, items = {} }),
			append({ kind = "skill", char = 1, time = T + 1400, rank = 81, max = 150, mod = 0 }),
			append({ kind = "skill", char = 1, time = T + 1500, rank = 82, max = 150, mod = 0 }),
			append({ kind = "cast", char = 1, time = T + 1500, outcome = "gotAway", conditions = conditions, items = {} }),
		}

		-- tie 1: the Skill Reading took tie 0 in that second (LOG-R12)
		assert.are.same({ idAt(0), idAt(0), false, ("%s-%d-1"):format(ADA, T + 1500) }, appended)
		local back = tags(catchLog, 2)
		assert.are.same(appended, { back[3], back[4], back[5], back[6] })
	end)
end)

describe("the latest Session", function()
	it("counts Casts, Catches (items, not quantities), got-aways, characters and zones (LOG-R62, LOG-R64)", function()
		local catchLog = ns.OpenCatchLog(
			log({
				cast(0, 1, 148, 453, "6358x1"),
				"B1|1|1791731100|0|70338|1.60.1",
				cast(200, 2, 1519, 0, "6358x5,6303x2,6299x1"), -- 3 Catches, 8 fish
				gotAway(400),
				cast(500, 1, 0, 0, "6358x1"), -- zone unresolved
			}),
			{}
		)

		assert.are.same({
			id = idAt(0),
			startTime = T,
			endTime = T + 500,
			firstSeq = 1,
			lastSeq = 5,
			casts = 4,
			catches = 5,
			gotAway = 1,
			characters = { 1, 2 },
			zones = { 148, 1519 },
		}, ns.SessionPayload(catchLog:Session()))
	end)

	it("is the last one cut, and follows each Cast appended (LOG-R60, LOG-R62)", function()
		local catchLog = ns.OpenCatchLog(log({ cast(0), cast(100), cast(5000) }), {})
		assert.are.same({ idAt(5000), 3, 3, 1 }, {
			catchLog:Session().id,
			catchLog:Session().firstSeq,
			catchLog:Session().lastSeq,
			catchLog:Session().casts,
		})

		catchLog:Append({
			kind = "cast",
			char = 1,
			time = T + 5100,
			outcome = "caught",
			conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
			items = { { itemID = 6358, quantity = 1 } },
		})

		assert.are.same({ idAt(5000), T + 5100, 4, 2 }, {
			catchLog:Session().id,
			catchLog:Session().endTime,
			catchLog:Session().lastSeq,
			catchLog:Session().casts,
		})
	end)

	it("is nil in a log without a Cast (LOG-R60)", function()
		assert.is_nil(ns.OpenCatchLog(log({ skill(0) }), {}):Session())
	end)
end)
