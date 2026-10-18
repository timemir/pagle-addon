-- /pagle dev probe (#261): reads the client facts launch re-verification checks 3, 8, 11, 12, 16 and 18–22 need
-- (roadmap.md › Launch re-verification checklist), saves them in PagleDB.global.probe and prints one line per check,
-- through the real TOC and the fake client. Every API it tests is looked up by name through _G, so a name the client
-- lacks is a miss, never an error.

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

local TITLE = "Nat Pagle, Angler Extreme"

-- The calls the fake client lacks that a live Forever client may have, answering as launch day would hope: both
-- reset calls, a Self-Found call, rain, quest 6607 (whose title arrives once asked for), and Fishing known.
local function liveClient(loaded)
	local env, asked = loaded.env, false
	env.C_DateAndTime.GetSecondsUntilDailyReset = function()
		return 3600
	end
	env.C_DateAndTime.GetSecondsUntilWeeklyReset = function()
		return 172800
	end
	env.C_GameRules = {
		IsHardcoreActive = function()
			return false
		end,
		IsSelfFoundAllowed = function()
			return true
		end,
		IsSelfFoundBroken = function()
			error("needs an argument")
		end,
		GetActiveGameMode = function()
			return 3
		end,
	}
	env.C_Weather = {
		GetCurrentWeather = function()
			return 2, 0.75
		end,
	}
	env.C_QuestLog = {
		RequestLoadQuestByID = function(questID)
			asked = questID == 6607
		end,
		GetTitleForQuestID = function(questID)
			return questID == 6607 and asked and loaded.client.time() >= 2 and TITLE or nil
		end,
	}
	env.C_SpellBook = {
		IsSpellKnown = function(spellID)
			return spellID == 7620
		end,
	}
	env.GetRealZoneText = function()
		return "Darkshore"
	end
	return loaded
end

-- Core logged in with dev mode on, on a client with the calls liveClient adds.
local function probing()
	local loaded = liveClient(enterWorld(loadCore({ BUILD_ENTRY })))
	pagle(loaded, "dev on")
	return loaded
end

-- The lines printed after the first `skip`, in order.
local function printedAfter(loaded, skip)
	return { unpack(loaded.printed, skip + 1) }
end

-- The printed line of check `n`, or nil.
local function checkLine(loaded, n)
	local prefix = ("Pagle dev: probe %d: "):format(n)
	for _, line in ipairs(loaded.printed) do
		if line:sub(1, #prefix) == prefix then
			return line
		end
	end
	return nil
end

describe("/pagle dev probe", function()
	it("prints the dev-off line and saves nothing while dev mode is off (#261)", function()
		local loaded = liveClient(enterWorld(loadCore({ BUILD_ENTRY })))

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.same({ "Pagle dev: dev commands are off; /pagle dev on turns them on." }, loaded.printed)
		assert.is_nil(loaded.env.PagleDB.global.probe)
	end)

	it("is in the dev usage line (#261)", function()
		local loaded = probing()

		pagle(loaded, "dev")

		assert.truthy(loaded.printed[2]:find("| probe", 1, true))
	end)

	it(
		"saves the probe with its time, build and locale, and prints one line per check, then the saved line, once the"
			.. " quest title is read again 2 s later (#261)",
		function()
			local loaded = probing()

			pagle(loaded, "dev probe")
			local before = #loaded.printed
			loaded.client.advance(2)

			local probe = loaded.env.PagleDB.global.probe
			assert.are.equal(SERVER_TIME, probe.time)
			assert.are.same(
				{ version = "1.60.1", build = "70338", date = "Oct  9 2026", interface = 16001 },
				probe.build
			)
			assert.are.equal("enUS", probe.locale)
			local lines = printedAfter(loaded, before)
			local checks = {}
			for i = 1, #lines - 1 do
				checks[i] = tonumber(lines[i]:match("^Pagle dev: probe (%d+): "))
			end
			assert.are.same({ 3, 8, 11, 12, 16, 18, 19, 20, 21, 22 }, checks)
			assert.are.equal("Pagle dev: Probe saved; /reload to write it.", lines[#lines])
		end
	)

	it("replaces the last probe, and changes nothing else in PagleDB.global (#261)", function()
		local loaded = probing()
		pagle(loaded, "dev probe")
		loaded.client.advance(2)
		local global = loaded.env.PagleDB.global
		local keys = {}
		for key in pairs(global) do
			keys[key] = true
		end
		loaded.client.advance(60)

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.equal(SERVER_TIME + 62, global.probe.time)
		for key in pairs(global) do
			assert.is_true(keys[key])
		end
	end)

	it("reads check 19, GetCurrentRegion, and the probe's own examples (#261, LOG-R69)", function()
		local loaded = probing()

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.equal("Pagle dev: probe 19: GetCurrentRegion() = 1", checkLine(loaded, 19))
		assert.are.same({ exists = true, region = 1 }, loaded.env.PagleDB.global.probe.checks[19])
	end)

	it("reads check 8's quest title at once and again 2 s later (#261, DATA-R22)", function()
		local loaded = probing()

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.same(
			{ call = "C_QuestLog.GetTitleForQuestID", first = nil, later = TITLE, laterRead = true },
			loaded.env.PagleDB.global.probe.checks[8]
		)
		assert.are.equal(
			'Pagle dev: probe 8: quest 6607 by C_QuestLog.GetTitleForQuestID: none at once, "' .. TITLE .. '" 2 s later',
			checkLine(loaded, 8)
		)
	end)

	it("reads check 18's reset calls beside the server time, the realm time and TKB-R11's fallback (#261)", function()
		local loaded = probing()

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		-- Realm 08:15 at SERVER_TIME (15:15:00 UTC), so the fallback day starts 8 h 15 min earlier.
		assert.are.same({
			daily = 3600,
			weekly = 172800,
			dailyExists = true,
			weeklyExists = true,
			serverTime = SERVER_TIME,
			gameTime = "8:15",
			fallbackDayStart = SERVER_TIME - (8 * 60 + 15) * 60,
		}, loaded.env.PagleDB.global.probe.checks[18])
	end)

	it("reads check 22: every C_GameRules key with its type, and each Is*SelfFound* call's result (#261)", function()
		local loaded = probing()

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		local check = loaded.env.PagleDB.global.probe.checks[22]
		assert.are.same({
			{ name = "GetActiveGameMode", type = "function" },
			{ name = "IsHardcoreActive", type = "function" },
			{ name = "IsSelfFoundAllowed", type = "function" },
			{ name = "IsSelfFoundBroken", type = "function" },
		}, check.keys)
		assert.are.equal("IsSelfFoundAllowed", check.calls[1].name)
		assert.are.equal("true", check.calls[1].result)
		assert.are.equal("IsSelfFoundBroken", check.calls[2].name)
		assert.truthy(check.calls[2].result:find("^error: "))
	end)

	it("reads check 3: C_Weather's keys, what GetCurrentWeather returns, and the zone (#261, LOG-R21)", function()
		local loaded = probing()

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.equal(
			"Pagle dev: probe 3: C_Weather keys GetCurrentWeather; GetCurrentWeather() = 2, 0.75 in Darkshore",
			checkLine(loaded, 3)
		)
	end)

	it("reads check 16: the equipment-set limit and the character's sets (#261, QOL-R42, QOL-R103)", function()
		local loaded = probing()
		loaded.client.equipmentSets[0] = { name = "Pagle Fishing", items = {} }

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.equal(
			"Pagle dev: probe 16: MAX_EQUIPMENT_SETS_PER_PLAYER = 10; 1 set: Pagle Fishing",
			checkLine(loaded, 16)
		)
	end)

	it("reads check 21: each listed fishing spell's name, icon and whether it's known, beside 7620's (#261)", function()
		local loaded = probing()

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		local check = loaded.env.PagleDB.global.probe.checks[21]
		assert.are.same({ name = "Fishing", icon = 136245 }, check.reference)
		assert.are.equal("C_SpellBook.IsSpellKnown", check.knownCall)
		assert.are.same({ id = 7620, name = "Fishing", icon = 136245, known = true }, check.spells[1])
		assert.are.equal(8, #check.spells)
	end)

	it(
		"saves each player channel named Fishing seen while dev mode is on, listed or not, with a count (LOG-R2)",
		function()
			local loaded = probing()
			local getName = loaded.env.C_Spell.GetSpellName
			loaded.env.C_Spell.GetSpellName = function(spellID)
				return spellID == 1300000 and "Fishing" or getName(spellID)
			end
			catchOne(loaded)
			catchOne(loaded)
			loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-9", 1300000)
			loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-9", 1300000)
			loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-8", 133) -- Fireball: not Fishing

			pagle(loaded, "dev probe")
			loaded.client.advance(2)

			assert.are.same({
				{ id = FISHING, count = 2, listed = true },
				{ id = 1300000, count = 1, listed = false },
			}, loaded.env.PagleDB.global.probe.checks[21].channels)
			assert.truthy(checkLine(loaded, 21):find("FAIL: channel 1300000 isn't on the fishing-spell list", 1, true))
		end
	)

	it("records the Cast first and keeps it when C_Spell.GetSpellName errors (LOG-R9, LOG-R2)", function()
		local loaded = probing()
		local ended = {}
		loaded.env.Pagle.RegisterCallback("Spec", "CastEnded", function(_, outcome)
			ended[#ended + 1] = outcome
		end)
		loaded.env.C_Spell.GetSpellName = function()
			error("no such spell")
		end

		catchOne(loaded)

		assert.are.same({ "caught" }, ended)
	end)

	it("keeps no channel while dev mode is off (LOG-R2)", function()
		local loaded = liveClient(enterWorld(loadCore({ BUILD_ENTRY })))
		catchOne(loaded)
		pagle(loaded, "dev on")

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		assert.are.same({}, loaded.env.PagleDB.global.probe.checks[21].channels)
	end)

	describe("shows a miss naming its check and rule", function()
		it("for a missing inventory name (check 11)", function()
			local loaded = probing()
			loaded.env.GetCurrentRegion = nil

			pagle(loaded, "dev probe")
			loaded.client.advance(2)

			local check = loaded.env.PagleDB.global.probe.checks[11]
			assert.are.equal(#loaded.ns.API_INVENTORY, check.checked)
			assert.truthy(table.concat(check.missing, " "):find("GetCurrentRegion", 1, true))
			assert.truthy(checkLine(loaded, 11):find("FAIL: ", 1, true))
			assert.truthy(checkLine(loaded, 11):find("each rule that uses them changes (CORE-R23)", 1, true))
		end)

		it("for no bit library (check 20, LOG-R66)", function()
			local loaded = probing()
			-- The fake client's globals fall back to busted's own, which hold LuaBitOp too.
			getmetatable(loaded.env).__index = function(_, name)
				return name ~= "bit" and _G[name] or nil
			end
			loaded.env.bit = nil

			pagle(loaded, "dev probe")
			loaded.client.advance(2)

			assert.are.equal(
				"Pagle dev: probe 20: bit is missing; 4 of 4 LOG-R66 vectors match;"
					.. " FAIL: no bit library: LOG-R66's Simulated Size hash can't run",
				checkLine(loaded, 20)
			)
		end)

		it("for a missing reset call (check 18, TKB-R10, TKB-R11)", function()
			local loaded = probing()
			loaded.env.C_DateAndTime.GetSecondsUntilWeeklyReset = nil

			pagle(loaded, "dev probe")
			loaded.client.advance(2)

			assert.truthy(
				checkLine(loaded, 18):find(
					"FAIL: GetSecondsUntilWeeklyReset is missing: TKB-R11's fallback runs (TKB-R10, TKB-R11)",
					1,
					true
				)
			)
		end)

		it("for no GetCurrentRegion (check 19, LOG-R69)", function()
			local loaded = probing()
			loaded.env.GetCurrentRegion = nil

			pagle(loaded, "dev probe")
			loaded.client.advance(2)

			assert.are.equal(
				"Pagle dev: probe 19: GetCurrentRegion is missing;"
					.. " FAIL: no GetCurrentRegion: LOG-R69's default length unit is always cm",
				checkLine(loaded, 19)
			)
			assert.are.same({ exists = false }, loaded.env.PagleDB.global.probe.checks[19])
		end)

		it("for a fishing-spell ID whose name differs from 7620's (check 21, QOL-R24, DATA-R39)", function()
			local loaded = probing()
			local getName = loaded.env.C_Spell.GetSpellName
			loaded.env.C_Spell.GetSpellName = function(spellID)
				return spellID ~= 1240948 and getName(spellID) or "Fishing Rank 5"
			end
			catchOne(loaded)

			pagle(loaded, "dev probe")
			loaded.client.advance(2)

			assert.truthy(checkLine(loaded, 21):find("FAIL: 1240948's name isn't 7620's (DATA-R39, QOL-R24)", 1, true))
		end)
	end)

	it("passes every check but 11 on a client with every call the checks name (#261)", function()
		local loaded = probing()
		catchOne(loaded)

		pagle(loaded, "dev probe")
		loaded.client.advance(2)

		for _, n in ipairs({ 3, 8, 12, 16, 18, 19, 20, 21, 22 }) do
			-- A line with no miss: its whole text, the check named, so a failure shows which.
			local line = assert(checkLine(loaded, n))
			assert.are.equal((line:gsub("; FAIL: .*", "")), line)
		end
	end)
end)
