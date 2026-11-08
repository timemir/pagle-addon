-- Party Catches on the client, through the real TOC and the fake client (catch-log.md › Party Catches, LOG-R110–R126;
-- settings.md SET-R35; from 1.6, pagle-2026j, #644): the party catch message sent for each of the Angler's own caught
-- Casts in a home party, on its own prefix, through the party send queue it shares with the party toasts; what is
-- received, checked and logged as a G1; and the Party Hunts setting. The receiver's checks one by one are
-- spec/Pagle/logic/PartyCatches_spec.lua's; the G1 entry and record spec/Pagle/logic/PartyCatchLog_spec.lua's.

local KUKLI = "Player-4618-0B00000A"
local ARWEN = "Player-4618-0C00000C"
local KEEFER = 19805

-- A party of Kukli Emnabi and Arwen, each with a player GUID as UnitGUID gives it.
local function party()
	return {
		members = {
			{ name = "Kukli", surname = "Emnabi", guid = KUKLI },
			{ name = "Arwen", guid = ARWEN },
		},
	}
end

-- A PagleLog whose one character is the fake client's own (PLAYER_GUID), holding the build entry and the player's
-- Cast in Darkshore (148) `castAgo` seconds ago (none for nil), so a groupmate fishing there now is in the window.
local function playerLog(castAgo)
	local entries = { BUILD_ENTRY }
	if castAgo then
		entries[2] = castEntry(SERVER_TIME - castAgo)
	end
	return savedLog(entries, 4, { characterRecord(PLAYER_GUID, "Angler") })
end

-- Core logged in on Forever with `group`, the player fishing in Darkshore, and a Module "Hunts" whose projection
-- takes Party Catches, noting each record it is applied (`seen.applied`, "<kind> <mode>", and `seen.records`) and
-- asked about (`seen.asked`); `seen.wants` is its filter's answer (true by default). `options.takes = false` gives it
-- a projection that doesn't take them; `options.log` another PagleLog.
local function loggedIn(group, options)
	options = options or {}
	local loaded = loadCore(options.log or playerLog(20))
	loaded.env.PagleDB.global.onboarding.notesOn = false
	loaded.client.group = group
	loaded.client.areaNames[148] = "Darkshore"
	loaded.env.GetRealZoneText = function()
		return "Darkshore"
	end
	local seen = { applied = {}, records = {}, asked = {}, wants = true, events = {} }
	local M = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		partyCatches = options.takes ~= false,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			seen.applied[#seen.applied + 1] = record.kind .. " " .. mode
			seen.records[#seen.records + 1] = record
		end,
		wantsPartyCatch = function(_, record)
			seen.asked[#seen.asked + 1] = record
			return seen.wants
		end,
	})
	for _, event in ipairs({ "PartyCatch", "Catch", "CastEnded", "SessionStarted" }) do
		loaded.env.Pagle.RegisterCallback(seen, event, function(name, payload)
			seen.events[#seen.events + 1] = { name = name, payload = payload }
		end)
	end
	enterWorld(loaded, 3)
	-- Past the hello at login, which the party toasts send (ANN-R103), and the limiter's burst back.
	loaded.client.advance(5)
	loaded.client.addonMessages = {}
	return loaded, seen, M
end

-- The texts Core sent on `prefix` (the party catch prefix by default), in order; every message sent is forgotten.
local function sentOn(loaded, prefix)
	local texts = {}
	for _, message in ipairs(loaded.client.addonMessages) do
		if message.prefix == (prefix or "PagleCatch") then
			assert.are.equal("PARTY", message.chatType)
			texts[#texts + 1] = message.text
		end
	end
	loaded.client.addonMessages = {}
	return texts
end

-- Every message sent, as "<prefix> <text>", in order, forgotten.
local function sentAll(loaded)
	local texts = {}
	for _, message in ipairs(loaded.client.addonMessages) do
		texts[#texts + 1] = message.prefix .. " " .. message.text
	end
	loaded.client.addonMessages = {}
	return texts
end

-- The party catch message for the player's newest Cast: its entry's own fields, behind PLAYER_GUID (LOG-R111).
local function messageFor(loaded)
	local entries = logEntries(loaded.env.PagleLog)
	local entry = entries[#entries]
	local time, tie, minute, rest = entry:match("^C1|%d+|(%d+)|(%d+)|c|([^|]*)|[^|]*|[^|]*|(.*)$")
	return ("PC|1|%s|%s|%s|%s|%s"):format(PLAYER_GUID, time, tie, minute, rest)
end

-- A message on `prefix` (the party catch prefix by default) from `sender` (Kukli), on the party channel.
local function receive(loaded, text, sender, prefix)
	loaded.client.fire(
		"CHAT_MSG_ADDON",
		prefix or "PagleCatch",
		text,
		"PARTY",
		sender or "Kukli-Testrealm",
		"",
		0,
		0,
		"",
		0
	)
end

-- Kukli's Cast `ago` seconds ago (5 by default) in Darkshore, The Long Wash: its copy, and the message carrying it.
local function kukliCatch(loaded, ago, item)
	local time = loaded.env.GetServerTime() - (ago or 5)
	local copy = ("%d|0|494|148|453|120|0||||%dx1"):format(time, item or 6358)
	return "PC|1|" .. KUKLI .. "|" .. copy, copy
end

local function entries(loaded)
	return logEntries(loaded.env.PagleLog)
end

describe("sending the party catch message", function()
	it("registers its own prefix at load, beside the party toasts' (LOG-R110)", function()
		local loaded = loggedIn(party())
		assert.is_true(loaded.client.prefixes.PagleCatch)
		assert.is_true(loaded.client.prefixes.Pagle)
	end)

	it(
		"sends each of the Angler's own caught Casts in a home party, its own fields behind the GUID (LOG-R111)",
		function()
			local loaded = loggedIn(party())
			catchOne(loaded)
			assert.are.same({ messageFor(loaded) }, sentOn(loaded))
			assert.matches("^PC|1|" .. PLAYER_GUID:gsub("%-", "%%-") .. "|%d+|0|495|148|0|", messageFor(loaded))
		end
	)

	it("sends nothing alone, in a raid or in an instance group (LOG-R110, LOG-R123)", function()
		for _, group in ipairs({
			false,
			{ raid = true, members = party().members },
			{ instance = true, members = party().members },
		}) do
			local loaded = loggedIn(group or nil)
			catchOne(loaded)
			assert.are.same({}, sentOn(loaded))
		end
	end)

	it("sends nothing with Party Hunts off, or for a Cast that got away (LOG-R111, LOG-R121)", function()
		local loaded = loggedIn(party())
		loaded.ns.db.profile.partyHunts = false
		catchOne(loaded)
		assert.are.same({}, sentOn(loaded))

		loaded.ns.db.profile.partyHunts = true
		loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-2", FISHING)
		loaded.client.fire("UI_INFO_MESSAGE", 0, loaded.env.ERR_FISH_ESCAPED)
		loaded.client.advance(3)
		assert.are.same({}, sentOn(loaded))
	end)

	it("sends nothing for a Cast /pagle dev catch writes (LOG-R111)", function()
		local log = playerLog(20)
		log.test = true
		local loaded = loggedIn(party(), { log = log })
		loaded.env.SlashCmdList.PAGLE("dev on")
		loaded.env.SlashCmdList.PAGLE("dev catch 6358 148")
		local written = entries(loaded)
		assert.matches("^C1|1|%d+|%d+|c|[^|]*|[^|]*|[^|]*|148|", written[#written])
		assert.are.same({}, sentOn(loaded))
		-- A real Catch after it still goes.
		catchOne(loaded)
		assert.are.equal(1, #sentOn(loaded))
	end)
end)

describe("the party send queue (LOG-R112)", function()
	it("is the party toasts' own: 3 at once, then one a second, catches and toasts alike", function()
		local loaded = loggedIn(party())
		for _ = 1, 5 do
			catchOne(loaded)
		end
		assert.are.equal(3, #sentOn(loaded))
		loaded.client.advance(1)
		assert.are.equal(1, #sentOn(loaded))
		loaded.client.advance(1)
		assert.are.equal(1, #sentOn(loaded))
	end)

	it("sends a party catch message before the party toasts and cheers waiting", function()
		local loaded = loggedIn(party())
		loaded.client.chatLockdown = true
		loaded.ns.SendPartyMessage("1:C:k3x91")
		loaded.ns.SendPartyMessage("1:H:0")
		catchOne(loaded)
		loaded.client.chatLockdown = false
		loaded.client.advance(1)
		assert.are.same({ "PagleCatch " .. messageFor(loaded), "Pagle 1:C:k3x91", "Pagle 1:H:0" }, sentAll(loaded))
	end)

	it("drops a party catch message still waiting once its Cast is the max party delay old", function()
		local loaded = loggedIn(party())
		loaded.client.chatLockdown = true
		catchOne(loaded)
		loaded.ns.SendPartyMessage("1:H:0")
		loaded.client.advance(61)
		loaded.client.chatLockdown = false
		loaded.client.advance(1)
		assert.are.same({ "Pagle 1:H:0" }, sentAll(loaded))
	end)

	it("holds at most 8: a party catch message takes the place of the last toast or cheer waiting", function()
		local loaded = loggedIn(party())
		loaded.client.chatLockdown = true
		for i = 1, 8 do
			loaded.ns.SendPartyMessage("1:C:wait" .. i)
		end
		loaded.ns.SendPartyMessage("1:C:over") -- a ninth toast or cheer is dropped, as from 1.5.2
		catchOne(loaded)
		loaded.client.chatLockdown = false
		loaded.client.advance(10)
		local sent = sentAll(loaded)
		assert.are.equal(8, #sent)
		assert.are.equal("PagleCatch " .. messageFor(loaded), sent[1])
		assert.are.equal("Pagle 1:C:wait7", sent[8])
	end)
end)

describe("receiving a groupmate's catch", function()
	it(
		"logs a groupmate's Catch as a Party Catch, the receiver's header and the copy, with no GUID (LOG-R113, LOG-R115)",
		function()
			local loaded = loggedIn(party())
			local before = loaded.env.PagleLog.count
			local text, copy = kukliCatch(loaded)

			receive(loaded, text)

			local log = entries(loaded)
			assert.are.equal(before + 1, #log)
			assert.are.equal(("G1|1|%d|0|%s"):format(loaded.env.GetServerTime(), copy), log[#log])
			assert.is_nil(log[#log]:find(KUKLI, 1, true))
		end
	)

	it(
		"hands it live to the projection that takes it, with the groupmate's name and source ID, then fires"
			.. " PartyCatch, and nothing of a Cast's (LOG-R115, LOG-R116)",
		function()
			local loaded, seen = loggedIn(party())
			local text, copy = kukliCatch(loaded)
			seen.applied, seen.events = {}, {}

			receive(loaded, text)

			assert.are.same({ "party live" }, seen.applied)
			local record = seen.records[#seen.records]
			assert.are.equal("Kukli Emnabi", record.name)
			assert.are.equal(KUKLI .. "-" .. copy:match("^%d+") .. "-0", record.sourceId)
			assert.are.equal(record.id .. ":1", record.items[1].catchId)
			assert.are.equal(1, #seen.events)
			assert.are.equal("PartyCatch", seen.events[1].name)
			assert.are.equal("Kukli Emnabi", seen.events[1].payload.name)
		end
	)

	it(
		"never names the groupmate once read back: a /reload's catch-up has neither name nor GUID (LOG-R116, LOG-R120)",
		function()
			local loaded = loggedIn(party())
			receive(loaded, (kukliCatch(loaded)))
			local saved = loaded.env.PagleLog

			local _, seen = loggedIn(party(), { log = saved })
			local replayed = seen.records[#seen.records]
			assert.are.equal("party", replayed.kind)
			assert.is_nil(replayed.name)
			assert.is_nil(replayed.sourceId)
		end
	)

	it("logs nothing the Hunts filter refuses, nor with no projection that takes them (LOG-R114, LOG-R122)", function()
		local loaded, seen = loggedIn(party())
		seen.wants = false
		local before = loaded.env.PagleLog.count
		receive(loaded, (kukliCatch(loaded)))
		assert.are.equal(1, #seen.asked)
		assert.are.equal(before, loaded.env.PagleLog.count)

		local none = loggedIn(party(), { takes = false })
		before = none.env.PagleLog.count
		receive(none, (kukliCatch(none)))
		assert.are.equal(before, none.env.PagleLog.count)
	end)

	it(
		"logs nothing with Party Hunts off, alone, in a raid or in an instance group (LOG-R113 item 2, LOG-R121)",
		function()
			local function nothingLogged(loaded)
				local before = loaded.env.PagleLog.count
				receive(loaded, (kukliCatch(loaded)))
				assert.are.equal(before, loaded.env.PagleLog.count)
			end
			local off = loggedIn(party())
			off.ns.db.profile.partyHunts = false
			nothingLogged(off)
			nothingLogged(loggedIn(nil))
			nothingLogged(loggedIn({ raid = true, members = party().members }))
			nothingLogged(loggedIn({ instance = true, members = party().members }))
		end
	)

	it("logs nothing from outside the party, for another groupmate's GUID, or the player's echo (LOG-R113)", function()
		local loaded = loggedIn(party())
		local before = loaded.env.PagleLog.count
		local text, copy = kukliCatch(loaded)
		receive(loaded, text, "Bram-Testrealm")
		receive(loaded, text, "Arwen-Testrealm")
		receive(loaded, "PC|1|" .. PLAYER_GUID .. "|" .. copy, "Angler-Testrealm")
		assert.are.equal(before, loaded.env.PagleLog.count)
	end)

	it("logs one copy once, however often it comes (LOG-R113 item 8, LOG-R125)", function()
		local loaded = loggedIn(party())
		local before = loaded.env.PagleLog.count
		local text = kukliCatch(loaded)
		receive(loaded, text)
		receive(loaded, text)
		assert.are.equal(before + 1, loaded.env.PagleLog.count)
	end)

	it("logs nothing while the receiver fishes another zone, or hasn't cast in the window (LOG-R113 item 7)", function()
		local stale = loggedIn(party(), { log = playerLog(400) })
		local before = stale.env.PagleLog.count
		receive(stale, (kukliCatch(stale)))
		assert.are.equal(before, stale.env.PagleLog.count)
	end)

	it(
		"ignores it on the party toasts' prefix, where a Pagle before 1.6 would read it, and shows nothing"
			.. " (LOG-R110, LOG-R124)",
		function()
			local loaded = loggedIn(party())
			local before = loaded.env.PagleLog.count
			local text = kukliCatch(loaded)
			assert.is_nil(loaded.ns.ParsePartyText(text))
			receive(loaded, text, "Kukli-Testrealm", "Pagle")
			assert.are.equal(before, loaded.env.PagleLog.count)
			assert.is_nil(loaded.ns.announcementFrames.party and loaded.ns.announcementFrames.party.display)
		end
	)

	it("is on by default (LOG-R121, SET-R35)", function()
		local loaded = loggedIn(party())
		assert.is_true(loaded.ns.db.profile.partyHunts)
	end)
end)

describe("a shared moment and a party catch together", function()
	it("both go out, the catch first, through the one queue (LOG-R112, ANN-R103)", function()
		local loaded, _, M = loggedIn(party())
		receive(loaded, "1:H:0", "Kukli-Testrealm", "Pagle")
		sentAll(loaded)
		loaded.client.chatLockdown = true
		M:RaiseMoment({ rung = "splash", kind = "legend", title = "Legend", icon = KEEFER, party = "legend" })
		loaded.client.advance(0)
		catchOne(loaded)
		loaded.client.chatLockdown = false
		loaded.client.advance(1)
		local sent = sentAll(loaded)
		assert.are.equal(2, #sent)
		assert.matches("^PagleCatch PC|1|", sent[1])
		assert.matches("^Pagle 1:M:[0-9a-z]+:legend:19805$", sent[2])
	end)
end)
