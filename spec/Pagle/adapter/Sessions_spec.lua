-- Sessions on the client (LOG-R9 step 3, LOG-R60–R64, LOG-R98): the Session events, Pagle.GetSession and the session
-- tag, driven through the fake client's events, with a server time that moves with the client's clock.

local FIRESCALE = "|cffffffff|Hitem:6303::::::::15:::::::::|h[Raw Slitherskin Mackerel]|h|r"
local ADA = "Player-4618-0A1B2C3D"

-- Core over a saved log holding `entries` (or the PagleLog `entries` itself, when it has `format`), and PagleDB
-- `saved` if given, its server time SERVER_TIME plus the client's clock, plus what `seen.jump(seconds)` adds without
-- moving the clock (no timer runs, as when the client hangs). The Ledger is registered with a projection that notes "apply <seq> <mode>" in `seen.order`, and
-- every Core event this file checks is noted there too ("<event> [<session id>] [whileAway]").
local function core(entries, saved)
	local clock
	local jumped = 0
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			PagleLog = entries.format and entries or savedLog(entries),
			PagleDB = saved,
			GetServerTime = function()
				return SERVER_TIME + math.floor(clock and clock() or 0) + jumped
			end,
		})
	)
	clock = loaded.client.time
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local Pagle = loaded.env.Pagle
	local seen = { order = {}, payloads = {} }
	function seen.jump(seconds)
		jumped = jumped + seconds
	end
	local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	seen.projection = M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			seen.order[#seen.order + 1] = ("apply %d %s"):format(record.seq, mode)
		end,
		done = function()
			seen.order[#seen.order + 1] = "done"
		end,
	})
	for _, event in ipairs({ "SessionStarted", "SessionEnded", "Catch", "CastEnded", "SkillChanged" }) do
		Pagle.RegisterCallback("Spec " .. event, event, function(_, payload, castEnded)
			local note = event
			if event == "SessionStarted" or event == "SessionEnded" then
				note = note .. " " .. payload.id .. (payload.whileAway and " whileAway" or "")
				seen.payloads[#seen.payloads + 1] = payload
				-- Every event fires only after the entry is in PagleLog.entries (LOG-R9).
				note = note .. " #" .. #loaded.env.PagleLog.entries
			elseif event == "CastEnded" then
				seen.cast = castEnded
			end
			seen.order[#seen.order + 1] = note
		end)
	end
	return loaded, seen
end

-- The entry ID of the player's (PLAYER_GUID, character 2 here) entry at SERVER_TIME + `offset`. A Cast in the login's
-- second has tie 1, after the login's Skill Reading (LOG-R12).
local function playerId(offset)
	return ("%s-%d-%d"):format(PLAYER_GUID, SERVER_TIME + offset, offset == 0 and 1 or 0)
end

describe("Sessions on the client", function()
	it("publishes Pagle.SESSION_RULES_VERSION 1 (LOG-R61)", function()
		assert.are.equal(1, loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle.SESSION_RULES_VERSION)
	end)

	it(
		"for a Cast that opens a Session: appends, ends the previous Session, starts this one, applies it live, then"
			.. " Catch and CastEnded (LOG-R9, LOG-R62, LOG-R73)",
		function()
			local loaded, seen = core({ BUILD_ENTRY })
			enterWorld(loaded)
			catchOne(loaded)
			seen.jump(1000) -- the 900 s timer hasn't run
			seen.order = {}

			catchOne(loaded)

			assert.are.same({
				"SessionEnded " .. playerId(0) .. " #4",
				"SessionStarted " .. playerId(1000) .. " #4",
				"apply 4 live",
				"Catch",
				"CastEnded",
			}, seen.order)
			assert.are.same({ 1, 1 }, { seen.payloads[3].casts, seen.payloads[3].catches })
		end
	)

	it("ends a Session when 900 s pass with no Cast, then GetSession is nil (LOG-R62, LOG-R64)", function()
		local loaded, seen = core({ BUILD_ENTRY })
		local Pagle = loaded.env.Pagle
		enterWorld(loaded)
		catchOne(loaded)
		seen.order = {}

		loaded.client.advance(899)
		assert.are.equal(playerId(0), Pagle.GetSession().id)
		assert.are.same({}, seen.order)
		loaded.client.advance(1)

		assert.are.same({ "SessionEnded " .. playerId(0) .. " #3" }, seen.order)
		assert.is_nil(Pagle.GetSession())
		assert.are.equal(playerId(0), loaded.env.PagleDB.global.lastEndedSession)
	end)

	it("waits 900 s from the last Cast, not the first (LOG-R62)", function()
		local loaded, seen = core({ BUILD_ENTRY })
		enterWorld(loaded)
		catchOne(loaded)
		loaded.client.advance(600)
		catchOne(loaded)
		seen.order = {}

		loaded.client.advance(899)
		assert.are.same({}, seen.order)
		loaded.client.advance(1)

		assert.are.same({ "SessionEnded " .. playerId(0) .. " #4" }, seen.order)
		assert.are.equal(2, seen.payloads[2].casts)
	end)

	it("counts a Cast's 3 items as 3 Catches, whatever their quantities (LOG-R64)", function()
		local loaded = core({ BUILD_ENTRY })
		enterWorld(loaded)

		catchOne(loaded, {
			{ link = OILY_BLACKMOUTH, quantity = 5 },
			{ link = FIRESCALE, quantity = 2 },
			{ link = OILY_BLACKMOUTH, quantity = 1 },
		})

		assert.are.equal(3, loaded.env.Pagle.GetSession().catches)
	end)

	it(
		"tags the records Catch, CastEnded, SkillChanged and IterateCatches hand out with their Session (LOG-R98)",
		function()
			local loaded, seen = core({ BUILD_ENTRY })
			local Pagle = loaded.env.Pagle
			local readings = {}
			Pagle.RegisterCallback("Spec readings", "SkillChanged", function(_, reading)
				readings[#readings + 1] = reading.session or false
			end)
			enterWorld(loaded) -- a Skill Reading at login, before any Cast
			catchOne(loaded)
			loaded.client.advance(10)
			loaded.env.GetProfessionInfo = function()
				return "Fishing", 136245, 76, 150, 2, 34, 356, 0, -1, 0, "Fishing"
			end
			loaded.client.fire("SKILL_LINES_CHANGED")

			assert.are.equal(playerId(0), seen.cast.session)
			assert.are.same({ false, playerId(0) }, readings)
			local tags = {}
			for record in Pagle.IterateCatches(2) do
				tags[#tags + 1] = record.session or false
			end
			assert.are.same({ playerId(0), playerId(0) }, tags)
		end
	)

	describe("at login", function()
		-- A Session of 501 Casts that ended 4499 s before login, then the build entry: 502 entries, so a projection
		-- rebuilds on later frames (LOG-R71).
		local function awayHistory()
			local entries = {}
			for i = 1, 501 do
				entries[i] = castEntry(SERVER_TIME - 5000 + i)
			end
			entries[502] = BUILD_ENTRY
			return entries
		end
		local AWAY_ID = ("%s-%d-0"):format(ADA, SERVER_TIME - 4999)

		it(
			"fires SessionEnded with whileAway for a Session that ended while away, after the last projection"
				.. " finishes (LOG-R63)",
			function()
				local loaded, seen = core(awayHistory())

				enterWorld(loaded)
				assert.is_true(seen.projection:IsUpdating())
				assert.are.same({}, seen.payloads)
				loaded.client.runTimers() -- Core's Field report projection rebuilds first (LOG-R78)
				loaded.client.runTimers() -- then Core's wallet projection (LOG-R78)
				loaded.client.runTimers() -- the entries
				loaded.client.runTimers() -- done, in a frame of its own (#79), then the live entries

				local order = seen.order
				local last = { order[#order - 2], order[#order - 1], order[#order] }
				assert.are.same({ "done", "apply 503 live", "SessionEnded " .. AWAY_ID .. " whileAway #503" }, last)
				assert.are.equal(501, seen.payloads[1].casts)
			end
		)

		it("fires it before the first new Cast's SessionStarted when that comes first (LOG-R63)", function()
			local loaded, seen = core(awayHistory())
			enterWorld(loaded)

			catchOne(loaded)
			loaded.client.runTimers()

			local ended = "SessionEnded " .. AWAY_ID .. " whileAway #504"
			local events = {}
			for _, note in ipairs(seen.order) do
				if note:match("^Session") then
					events[#events + 1] = note
				end
			end
			assert.are.same({ ended, "SessionStarted " .. playerId(0) .. " #504" }, events)
		end)

		it("fires nothing at a second login (LOG-R63)", function()
			local first = core({ castEntry(SERVER_TIME - 2000), BUILD_ENTRY })
			enterWorld(first)
			assert.are.equal(ADA .. "-" .. (SERVER_TIME - 2000) .. "-0", first.env.PagleDB.global.lastEndedSession)

			local second, seen = core(first.env.PagleLog, first.env.PagleDB)
			enterWorld(second)
			second.client.runTimers()

			assert.are.same({}, seen.payloads)
		end)
	end)
end)
