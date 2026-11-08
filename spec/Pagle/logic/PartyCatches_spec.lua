-- The party catch message and the receiver's checks (LOG-R110–R113, LOG-R121, LOG-R123–R126), through
-- ns.PartyCatchText, ns.ParsePartyCatch and ns.NewPartyCatches, logic/PartyCatches.lua's seams: pure Lua over what it
-- is handed (a Catch log, a clock, the party), which Core's adapter wires to the client. From 1.6 (pagle-2026j, #644).

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local ADA = "Player-4618-0A1B2C3D" -- the receiver's character
local KUKLI = "Player-4618-0B00000A" -- a groupmate
local NOW = 1791731760

-- The copy of Kukli's caught Cast `C1|1|1791731748|0|c|494|1439|1|148|453|120|0||||6358x1`, which the message and the
-- G1 carry (LOG-R111).
local COPY = "1791731748|0|494|148|453|120|0||||6358x1"
local MESSAGE = "PC|1|" .. KUKLI .. "|" .. COPY

local function adaLog(entries)
	return savedLog(entries, 4, {
		{ guid = ADA, name = "Ada", classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 },
	})
end

-- Ada's own Cast at `time` in zone `zone` (Darkshore, 148, by default), caught unless `outcome` is "g".
local function adaCast(time, zone, outcome)
	if outcome == "g" then
		return ("C1|1|%d|0|g|494|1439|1|%d|0|86|25||||"):format(time, zone or 148)
	end
	return ("C1|1|%d|0|c|494|1439|1|%d|453|86|25|263|||6358x1"):format(time, zone or 148)
end

describe("the party catch message", function()
	local function castRecord(entry)
		local catchLog = ns.OpenCatchLog(adaLog({ entry }), {})
		return catchLog:Iterate(0)(), entry
	end

	it(
		"is PC, version 1, the GUID and the Cast's time and tie, then its C1 fields from minute to items, byte for"
			.. " byte (LOG-R110, LOG-R111)",
		function()
			local cast, entry = castRecord("C1|1|1791731748|2|c|494|1439|1|148|453|86|-5|263|12,301|8087|6358x1,0x1")
			assert.are.equal(
				"PC|1|" .. ADA .. "|1791731748|2|494|148|453|86|-5|263|12,301|8087|6358x1,0x1",
				ns.PartyCatchText(cast, entry, ADA)
			)
		end
	)

	it("leaves out the outcome, the map and the instance (LOG-R111)", function()
		local cast, entry = castRecord(adaCast(1791731748))
		local text = ns.PartyCatchText(cast, entry, ADA) --[[@as string]]
		assert.is_nil(text:find("|c|", 1, true))
		assert.is_nil(text:find("1439", 1, true))
	end)

	it("isn't made for a got-away Cast, a zone 0 or a Cast of only item 0 (LOG-R111)", function()
		for _, entry in ipairs({
			adaCast(1791731748, 148, "g"),
			"C1|1|1791731748|0|c|494|1439|1|0|0|86|25|263|||6358x1",
			"C1|1|1791731748|0|c|494|1439|1|148|453|86|25|263|||0x1,0x2",
		}) do
			local cast = castRecord(entry)
			assert(ns.PartyCatchText(cast, entry, ADA) == nil, entry)
		end
	end)

	it("isn't made at all past the addon message limit, 255 bytes (LOG-R111, Tunables)", function()
		local items = {}
		for i = 1, 30 do
			items[i] = (100000 + i) .. "x1"
		end
		local entry = "C1|1|1791731748|0|c|494|1439|1|148|453|86|25|263|||" .. table.concat(items, ",")
		local cast = castRecord(entry)
		assert.is_nil(ns.PartyCatchText(cast, entry, ADA))
		assert.are.equal(255, ns.ADDON_MESSAGE_LIMIT)
	end)

	it("is read back as the GUID, the time, the tie, the zone and the copy (LOG-R113 item 3)", function()
		local message = ns.ParsePartyCatch(MESSAGE)
		assert.are.same(
			{ guid = KUKLI, time = 1791731748, tie = 0, zone = 148, copy = COPY, sourceId = KUKLI .. "-1791731748-0" },
			message
		)
	end)

	it("refuses anything that isn't exactly one (LOG-R113 item 3)", function()
		for _, text in ipairs({
			"PC|2|" .. KUKLI .. "|" .. COPY, -- a later version
			"PC|1|" .. COPY, -- no GUID
			"PC|1|Party-Kukli|" .. COPY, -- not a player GUID
			"PC|1|Player-4618-0b00000a|" .. COPY, -- lower-case hex, not as UnitGUID gives it
			"PC|1|Player-4618-" .. ("A"):rep(60) .. "|" .. COPY, -- a GUID over 64 bytes
			"PC|1|" .. KUKLI .. "|1791731748|0|494|0|453|120|0||||6358x1", -- zone 0
			"PC|1|" .. KUKLI .. "|1791731748|0|494|148|453|120|0||||0x1", -- only item 0
			"PC|1|" .. KUKLI .. "|1791731748|0|494|148|453|120|0||||", -- no item
			"PC|1|" .. KUKLI .. "|1791731748|0|c|494|1439|1|148|453|120|0||||6358x1", -- a C1's own fields
			"PC|1|" .. KUKLI .. "|1791731748|0|494|148|453|120|0|||6358x1", -- a field short
			"PC|1|" .. KUKLI .. "|" .. COPY .. "|", -- a field more
			"PC|1|" .. KUKLI .. "|01791731748|0|494|148|453|120|0||||6358x1", -- a leading zero
			"PC|1|" .. KUKLI .. "|1791731748|0|494|148|453|120|0||9,5||6358x1", -- events out of order
			"PC|1|" .. KUKLI .. "|1791731748|0|494|148|453|120|0||||6358x1\n", -- a line feed
			"PC|1|" .. KUKLI .. "|" .. COPY .. ("1"):rep(255), -- past the limit
			"PC|1", -- nothing after
			"",
			7,
		}) do
			assert(ns.ParsePartyCatch(text) == nil, tostring(text))
		end
	end)
end)

-- A receiver: Ada, in a party with Kukli, over a log holding `entries`, with `world` driving what the checks read.
-- `world.appended` holds what was logged ({ copy, name, sourceId }), and `world.sent` what was handed to the queue.
local function receiver(entries, options)
	options = options or {}
	local catchLog = ns.OpenCatchLog(adaLog(entries or { adaCast(NOW - 30) }), { decodeErrors = 0 })
	local world = {
		catchLog = catchLog,
		now = NOW,
		on = true,
		party = true,
		character = 1,
		wants = true,
		asked = {},
		appended = {},
		sent = {},
		-- Kukli, by the name the message arrives from; the player echoes as "Ada-Testrealm".
		members = { ["Kukli-Testrealm"] = { guid = KUKLI, name = "Kukli Emnabi" } },
	}
	world.receiver = ns.NewPartyCatches({
		isPlayer = function(sender)
			return sender == "Ada-Testrealm"
		end,
		on = function()
			return world.on
		end,
		inParty = function()
			return world.party
		end,
		groupmate = function(sender)
			return world.members[sender]
		end,
		catchLog = function()
			return catchLog
		end,
		character = function()
			return world.character
		end,
		now = function()
			return world.now
		end,
		wants = function(record)
			world.asked[#world.asked + 1] = record
			return world.wants
		end,
		append = function(copy, name, sourceId)
			local record = catchLog:Append({ kind = "party", char = 1, time = world.now, copy = copy })
			world.appended[#world.appended + 1] = { copy = copy, name = name, sourceId = sourceId }
			return record
		end,
		send = function(text, castTime)
			world.sent[#world.sent + 1] = { text = text, castTime = castTime }
		end,
	})
	for key, value in pairs(options) do
		world[key] = value
	end
	function world.receive(text, sender)
		return world.receiver:Receive(text, sender or "Kukli-Testrealm")
	end
	return world
end

describe("what the receiver checks, in order", function()
	it(
		"logs a message that passes every check as a Party Catch, with the name and source ID live (LOG-R113)",
		function()
			local world = receiver()
			local record, failed = world.receive(MESSAGE)
			assert.is_nil(failed)
			assert.are.equal("party", record.kind)
			assert.are.same(
				{ { copy = COPY, name = "Kukli Emnabi", sourceId = KUKLI .. "-1791731748-0" } },
				world.appended
			)
			assert.are.equal("G1|1|" .. NOW .. "|0|" .. COPY, logEntries(world.catchLog.data)[2])
		end
	)

	it("ignores a message of a kind it doesn't know, or a later version, without a word (LOG-R110)", function()
		local world = receiver()
		local _, failed = world.receive("hp|1|h|night_run|" .. KUKLI .. "-1791731748-0:1")
		assert.are.equal(0, failed)
		_, failed = world.receive("PC|2|" .. KUKLI .. "|" .. COPY)
		assert.are.equal(3, failed)
		assert.are.same({}, world.appended)
	end)

	it("1. drops the player's own message, echoed back (LOG-R113 item 1)", function()
		local world = receiver()
		-- The player's echo also fails 2 (the setting off) and 3 (a later version): 1 comes first.
		world.on = false
		local _, failed = world.receive("PC|2|" .. ADA .. "|" .. COPY, "Ada-Testrealm")
		assert.are.equal(1, failed)
	end)

	it("2. drops everything with Party Hunts off, or out of a party (LOG-R113 item 2, LOG-R121, LOG-R123)", function()
		local world = receiver()
		world.on = false
		-- Also a later version (check 3): 2 comes first.
		local _, failed = world.receive("PC|2|" .. KUKLI .. "|" .. COPY)
		assert.are.equal(2, failed)
		world.on, world.party = true, false
		_, failed = world.receive(MESSAGE)
		assert.are.equal(2, failed)
		assert.are.same({}, world.appended)
	end)

	it("3. drops a message that isn't exactly the party catch message (LOG-R113 item 3)", function()
		local world = receiver()
		-- From someone who isn't a groupmate too (check 4): 3 comes first.
		local _, failed = world.receive("PC|1|" .. KUKLI .. "|1791731748|0|494|0|453|120|0||||6358x1", "Bram-Testrealm")
		assert.are.equal(3, failed)
	end)

	it("4. drops a message from outside the party, or speaking for another character (LOG-R113 item 4)", function()
		local world = receiver()
		local _, failed = world.receive(MESSAGE, "Bram-Testrealm")
		assert.are.equal(4, failed)
		-- Arwen, in the party, sending Kukli's GUID.
		world.members["Arwen-Testrealm"] = { guid = "Player-4618-0C00000C", name = "Arwen" }
		_, failed = world.receive(MESSAGE, "Arwen-Testrealm")
		assert.are.equal(4, failed)
		-- A groupmate whose GUID the client doesn't resolve can't be checked, so nothing of theirs counts.
		world.members["Bram-Testrealm"] = { name = "Bram" }
		_, failed = world.receive("PC|1|Player-4618-0D00000D|" .. COPY, "Bram-Testrealm")
		assert.are.equal(4, failed)
	end)

	it("5. drops a Cast of one of this Catch log's own characters (LOG-R113 item 5, LOG-R125)", function()
		local world = receiver()
		-- Ada's other self, logged into a second client in the party, under her GUID: also out of time (check 6).
		world.members["Ada-Otherrealm"] = { guid = ADA, name = "Ada" }
		local _, failed = world.receive("PC|1|" .. ADA .. "|1791731000|0|494|148|453|120|0||||6358x1", "Ada-Otherrealm")
		assert.are.equal(5, failed)
	end)

	it(
		"6. drops a Cast more than the clock slack ahead, or the max party delay behind (LOG-R113 item 6, LOG-R126)",
		function()
			local world = receiver({ adaCast(NOW - 30) })
			local function at(time)
				return ("PC|1|%s|%d|0|494|148|453|120|0||||6358x1"):format(KUKLI, time)
			end
			local _, failed = world.receive(at(NOW + 31))
			assert.are.equal(6, failed)
			_, failed = world.receive(at(NOW - 61))
			assert.are.equal(6, failed)
			assert.is_nil(select(2, world.receive(at(NOW + 30))))
			assert.is_nil(select(2, world.receive(at(NOW - 60))))
			assert.are.equal(30, ns.PARTY_CLOCK_SLACK)
			assert.are.equal(60, ns.PARTY_MAX_DELAY)
		end
	)

	describe("7. fishing in the same zone (LOG-R113 item 7)", function()
		it("drops a Catch while the receiver's latest Cast is in another zone", function()
			local world = receiver({ adaCast(NOW - 30, 12) })
			local _, failed = world.receive(MESSAGE)
			assert.are.equal(7, failed)
		end)

		it("takes the same zone in another subzone, and a got-away latest Cast", function()
			local world = receiver({ adaCast(NOW - 30, 148, "g") })
			-- The receiver got away in subzone 0; Kukli caught in The Long Wash (453).
			assert.is_nil(select(2, world.receive(MESSAGE)))
		end)

		it("drops a Catch more than the party window after the receiver's latest Cast", function()
			-- Kukli's Cast is at NOW - 12; the window is 300 s.
			local world = receiver({ adaCast(NOW - 12 - 301) })
			local _, failed = world.receive(MESSAGE)
			assert.are.equal(7, failed)
			assert.are.equal(300, ns.PARTY_WINDOW)
			world = receiver({ adaCast(NOW - 12 - 300) })
			assert.is_nil(select(2, world.receive(MESSAGE)))
		end)

		it("drops a Catch when the receiver has no Cast, or its latest is another character's", function()
			local world = receiver({})
			assert.are.equal(7, select(2, world.receive(MESSAGE)))
			world = receiver({ adaCast(NOW - 30) })
			world.character = 2
			assert.are.equal(7, select(2, world.receive(MESSAGE)))
		end)

		it("reads only the latest Cast, past later Party Catches", function()
			local world = receiver({
				adaCast(NOW - 30),
				"G1|1|" .. (NOW - 20) .. "|0|" .. (NOW - 21) .. "|0|494|12|0|120|0||||6358x1",
			})
			assert.is_nil(select(2, world.receive(MESSAGE)))
		end)
	end)

	describe("8. not seen before (LOG-R113 item 8, LOG-R125)", function()
		it("logs one copy once, whoever sends it again", function()
			local world = receiver()
			world.receive(MESSAGE)
			world.members["Arwen-Testrealm"] = { guid = "Player-4618-0C00000C", name = "Arwen" }
			-- Arwen's own Cast with the very same fields, in the same second: the same copy (LOG-R125).
			local _, failed = world.receive("PC|1|Player-4618-0C00000C|" .. COPY, "Arwen-Testrealm")
			assert.are.equal(8, failed)
			_, failed = world.receive(MESSAGE)
			assert.are.equal(8, failed)
			assert.are.equal(1, #world.appended)
		end)

		it("logs two Casts that differ in any field, the tie included", function()
			local world = receiver()
			world.receive(MESSAGE)
			-- From two other groupmates, as one groupmate has one Party Catch a second (check 9).
			world.members["Arwen-Testrealm"] = { guid = "Player-4618-0C00000C", name = "Arwen" }
			world.members["Bram-Testrealm"] = { guid = "Player-4618-0D00000D", name = "Bram" }
			local tie = "PC|1|Player-4618-0C00000C|1791731748|1|494|148|453|120|0||||6358x1"
			local items = "PC|1|Player-4618-0D00000D|1791731748|0|494|148|453|120|0||||6358x2"
			assert.is_nil(select(2, world.receive(tie, "Arwen-Testrealm")))
			assert.is_nil(select(2, world.receive(items, "Bram-Testrealm")))
			assert.are.equal(3, #world.appended)
		end)

		it("reads back the Party Catches logged before a /reload from the log's end", function()
			local world = receiver({ adaCast(NOW - 30), "G1|1|" .. (NOW - 5) .. "|0|" .. COPY })
			local _, failed = world.receive(MESSAGE)
			assert.are.equal(8, failed)
		end)
	end)

	-- Kukli's Cast at `time`, tie `tie`, as a message: the copy differs from COPY's in time and tie only.
	local function kukliAt(time, tie)
		return ("PC|1|%s|%d|%d|494|148|453|120|0||||6358x1"):format(KUKLI, time, tie or 0)
	end

	describe("9. one Party Catch a second from each groupmate (LOG-R113 item 9)", function()
		it("drops a second Cast of one groupmate's in the same second, whatever its tie", function()
			local world = receiver()
			assert.is_nil(select(2, world.receive(kukliAt(NOW - 12, 0))))
			for tie = 1, 5 do
				local _, failed = world.receive(kukliAt(NOW - 12, tie))
				assert.are.equal(9, failed)
			end
			-- the next second, and another groupmate's in the same second, are taken
			assert.is_nil(select(2, world.receive(kukliAt(NOW - 11, 1))))
			world.members["Arwen-Testrealm"] = { guid = "Player-4618-0C00000C", name = "Arwen" }
			local arwen = "PC|1|Player-4618-0C00000C|" .. (NOW - 12) .. "|3|494|148|453|120|0||||6358x1"
			assert.is_nil(select(2, world.receive(arwen, "Arwen-Testrealm")))
			assert.are.equal(3, #world.appended)
		end)

		it("remembers each second as long as a message of it can arrive", function()
			local world = receiver()
			world.receive(kukliAt(NOW + 30))
			-- 90 s on, the Cast is at the max party delay: still in time, and still a second already taken.
			world.now = NOW + 90
			local _, failed = world.receive(kukliAt(NOW + 30, 1))
			assert.are.equal(9, failed)
		end)

		it("counts only what was logged: a Cast the Hunts filter refused leaves its second free", function()
			local world = receiver()
			world.wants = false
			world.receive(kukliAt(NOW - 12, 0))
			world.wants = true
			assert.is_nil(select(2, world.receive(kukliAt(NOW - 12, 1))))
		end)
	end)

	describe("10. at most the party catch cap from each groupmate a minute (LOG-R113 item 10, Tunables)", function()
		it(
			"drops a groupmate's eleventh Party Catch in 60 s, and takes one again once the first is a minute old",
			function()
				local world = receiver()
				assert.are.same({ 10, 60 }, { ns.PARTY_CATCH_CAP, ns.PARTY_CATCH_CAP_WINDOW })
				for i = 1, 10 do
					world.now = NOW + (i - 1) * 3
					assert(select(2, world.receive(kukliAt(world.now - 1))) == nil, "Catch " .. i)
				end
				world.now = NOW + 59
				local _, failed = world.receive(kukliAt(NOW + 58))
				assert.are.equal(10, failed)
				-- another groupmate has a cap of their own
				world.members["Arwen-Testrealm"] = { guid = "Player-4618-0C00000C", name = "Arwen" }
				local arwen = "PC|1|Player-4618-0C00000C|" .. (NOW + 58) .. "|0|494|148|453|120|0||||6358x1"
				assert.is_nil(select(2, world.receive(arwen, "Arwen-Testrealm")))
				-- the first, received at NOW, leaves the window at NOW + 60
				world.now = NOW + 60
				assert.is_nil(select(2, world.receive(kukliAt(NOW + 59))))
				assert.are.equal(12, #world.appended)
			end
		)
	end)

	it(
		"11. logs nothing the Hunts filter refuses, asking with the record the entry would make (LOG-R113 item 11,"
			.. " LOG-R114)",
		function()
			local world = receiver()
			world.wants = false
			local _, failed = world.receive(MESSAGE)
			assert.are.equal(11, failed)
			assert.are.same({}, world.appended)
			assert.are.equal(1, world.catchLog:Count())
			local asked = world.asked[1]
			assert.are.equal("party", asked.kind)
			assert.are.equal(2, asked.seq)
			assert.are.equal(NOW, asked.time)
			assert.are.equal(1791731748, asked.catchTime)
			assert.are.equal(6358, asked.items[1].itemID)
			-- A copy the filter refused isn't remembered: offered again, it is asked again.
			world.wants = true
			assert.is_nil(select(2, world.receive(MESSAGE)))
		end
	)
end)

describe("sending", function()
	-- The receiver's world, over a log whose last entry is Ada's Cast `entry`, sending it as Core does after the append.
	local function sending(entry, setup)
		local world = receiver({ entry })
		for key, value in pairs(setup or {}) do
			world[key] = value
		end
		local cast = world.catchLog:Iterate(0)()
		world.receiver:Send(cast, setup and setup.synthetic)
		return world
	end

	it(
		"hands the queue each of the Angler's own caught Casts in a party, with its time (LOG-R111, LOG-R112)",
		function()
			local world = sending(adaCast(NOW))
			assert.are.same({
				{
					text = "PC|1|" .. ADA .. "|" .. NOW .. "|0|494|148|453|86|25|263|||6358x1",
					castTime = NOW,
				},
			}, world.sent)
		end
	)

	it("sends nothing with Party Hunts off, out of a party, or for /pagle dev catch (LOG-R111, LOG-R121)", function()
		assert.are.same({}, sending(adaCast(NOW), { on = false }).sent)
		assert.are.same({}, sending(adaCast(NOW), { party = false }).sent)
		assert.are.same({}, sending(adaCast(NOW), { synthetic = true }).sent)
		assert.are.same({}, sending(adaCast(NOW, 148, "g")).sent)
	end)
end)
