-- Core's login sequence (LOG-R1, CORE-R10, CORE-R19) driven through the client's events, and what it writes before
-- any Cast: the character table (LOG-R25, LOG-R26), Skill Readings (LOG-R30–R32) and build entries (LOG-R36), with
-- Pagle.GetAngler (LOG-R27) on top.

local ADA = "Player-4618-0A1B2C3D"

-- A client whose fishing skill is `skill.rank`/`skill.max`+`skill.mod`, changeable between events, on build
-- `build.number` (version `build.version`).
local function fishingClient(extra)
	local skill = { rank = 86, max = 150, mod = 0 }
	local build = { number = "70338", version = "1.60.1" }
	local globals = foreverWith({
		GetProfessions = function()
			return 7, nil, 5, 8, 6
		end,
		GetProfessionInfo = function(index)
			if index == 8 then
				return "Fishing", 136245, skill.rank, skill.max, 2, 34, 356, skill.mod, -1, 0, "Fishing"
			end
			return "Cooking", 133971, 88, 150, 1, 30, 185, 0, -1, 0, "Cooking"
		end,
		GetBuildInfo = function()
			return build.version, build.number, "Oct  9 2026", 16001, "", " "
		end,
	})
	for key, value in pairs(extra or {}) do
		globals[key] = value
	end
	return globals, skill, build
end

-- Every Core event fired on the bus, in order, as { event, ... }.
local function recordEvents(loaded, events)
	local fired = {}
	for _, event in ipairs(events) do
		loaded.env.Pagle.RegisterCallback("Spec " .. event, event, function(...)
			fired[#fired + 1] = { ... }
		end)
	end
	return fired
end

describe("Core's login order", function()
	it(
		"at ADDON_LOADED checks the format, notes loginSeq, migrates PagleDB, then builds the catalogue (LOG-R1)",
		function()
			local log = savedLog({ "S1|1|1791731000|0|80|150|0", "B1|1|1791731001|0|70338|1.60.1|pagle-2026a" })
			local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), { holdAddonLoaded = true })
			local ns = loaded.ns
			local duringMigration
			ns.PAGLEDB_MIGRATIONS[#ns.PAGLEDB_MIGRATIONS + 1] = function()
				duringMigration = { loginSeq = ns.loginSeq, catalogue = ns.Catalogue }
			end

			loaded.client.fire("ADDON_LOADED", "Pagle")

			assert.are.same({ loginSeq = 2 }, duringMigration)
			assert.are.equal(2, ns.loginSeq)
			assert.are.equal(#ns.PAGLEDB_MIGRATIONS, ns.db.global.schemaVersion)
			assert.is_function(loaded.env.Pagle.GetItem)
		end
	)

	it("notes loginSeq after the format check, so a set-aside log counts as empty (LOG-R1, LOG-R18)", function()
		local log = savedLog({ "S1|1|1791731000|0|80|150|0" }, 1)
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))

		assert.are.equal(0, loaded.ns.loginSeq)
	end)

	it(
		"at PLAYER_LOGIN adds the character, builds the area index, starts the conditions, then fires ModulesChanged"
			.. " (LOG-R1, LOG-R47)",
		function()
			local steps = {}
			local loaded
			loaded = loadAddon(
				"Pagle",
				foreverWith({
					C_Map = {
						GetAreaInfo = function(id)
							if id == 1 then
								steps[#steps + 1] = "area index, characters: " .. #loaded.env.PagleLog.characters
							end
						end,
					},
				})
			)
			local startConditions = loaded.ns.StartConditions
			loaded.ns.StartConditions = function()
				steps[#steps + 1] = "conditions"
				startConditions()
			end
			loaded.env.Pagle.RegisterCallback("Spec", "ModulesChanged", function()
				steps[#steps + 1] = "ModulesChanged, current: " .. tostring(loaded.env.Pagle.GetAngler().current)
			end)
			assert.are.same({}, loaded.env.PagleLog.characters)

			loaded.client.fire("PLAYER_LOGIN")
			loaded.client.fire("PLAYER_LOGIN")

			assert.are.same({ "area index, characters: 1", "conditions", "ModulesChanged, current: 1" }, steps)
		end
	)

	it("at the first PLAYER_ENTERING_WORLD only appends a build entry, then a Skill Reading (LOG-R1)", function()
		local globals, skill, build = fishingClient()
		local loaded = loadAddon("Pagle", globals)
		loaded.client.fire("PLAYER_LOGIN")
		assert.are.same({}, loaded.env.PagleLog.entries)

		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
		skill.rank, build.number = 87, "70412"
		loaded.client.fire("PLAYER_ENTERING_WORLD", false, false)

		assert.are.same({
			"B1|1|1791731700|0|70338|1.60.1|pagle-2026b",
			"S1|1|1791731700|1|86|150|0",
		}, loaded.env.PagleLog.entries)
	end)

	for _, event in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do
		it("declares the active rules before " .. event .. " can append during startup", function()
			local globals = fishingClient()
			local loaded = loadAddon("Pagle", globals)
			loaded.client.fire("PLAYER_LOGIN")
			loaded.client.fire(event)
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
			local entries = loaded.env.PagleLog.entries
			assert.are.equal(loaded.ns.RULE_SET_ID, entries[1]:match("^B1|.*|([^|]+)$"))
			assert.matches("^S1|", entries[2])
			assert.are.equal(2, #entries)
			assert.are.same({}, loaded.client.errors)
		end)
	end

	it("has Core's DBs loaded and its catalogue built when a Module's OnInitialize runs (CORE-R10)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local env = loaded.env
		local found
		-- A Module's files load after Core's ADDON_LOADED (its TOC depends on Pagle); its AceAddon OnInitialize runs
		-- at its own ADDON_LOADED.
		local module = env.LibStub("AceAddon-3.0"):NewAddon("Pagle_QoL")
		function module.OnInitialize()
			found = {
				log = env.PagleLog and env.PagleLog.format,
				db = env.PagleDB and env.PagleDB.global and env.PagleDB.global.schemaVersion,
				catalogue = env.Pagle.GetZones and #env.Pagle.GetZones() > 0,
			}
		end

		loaded.client.fire("ADDON_LOADED", "Pagle_QoL")

		assert.are.same({ log = 3, db = #loaded.ns.PAGLEDB_MIGRATIONS, catalogue = true }, found)
	end)
end)

describe("the character table at PLAYER_LOGIN", function()
	-- Logs in as Ada with a saved log, through a client answering with `extra`.
	local function loginAsAda(extra, log)
		local globals = foreverWith({
			PagleLog = log,
			UnitGUID = function()
				return ADA
			end,
			UnitName = function()
				return "Ada", "Brook"
			end,
			UnitClass = function()
				return "Warlock", "WARLOCK", 9
			end,
		})
		for key, value in pairs(extra or {}) do
			globals[key] = value
		end
		local loaded = loadAddon("Pagle", globals)
		loaded.client.fire("PLAYER_LOGIN")
		return loaded.env.PagleLog.characters
	end

	it("adds a new GUID with its display fields; hardcore is nil without C_GameRules (LOG-R25, LOG-R26)", function()
		local characters = loginAsAda()

		assert.are.same({
			{
				guid = ADA,
				name = "Ada",
				surname = "Brook",
				classID = 9,
				raceID = 1,
				faction = "Alliance",
				realmID = 4618,
				firstSeen = 1791731700,
				lastSeen = 1791731700,
			},
		}, characters)
	end)

	it("updates lastSeen and the display fields of a known GUID (LOG-R25, LOG-R26)", function()
		local characters = loginAsAda(nil, savedLog())

		assert.are.equal(1, #characters)
		assert.are.same(
			{ "Brook", 9, 1791700000, 1791731700 },
			{ characters[1].surname, characters[1].classID, characters[1].firstSeen, characters[1].lastSeen }
		)
	end)

	it("reads hardcore from C_GameRules.IsHardcoreActive when it exists (LOG-R26)", function()
		for _, active in ipairs({ true, false }) do
			local characters = loginAsAda({
				C_GameRules = {
					IsHardcoreActive = function()
						return active
					end,
				},
			})

			assert.are.equal(active, characters[1].hardcore)
		end
	end)
end)

describe("Skill Readings from the client", function()
	-- Logged in as Ada and through the first loading screen, with the reading taken there.
	local function loggedIn(log)
		local globals, skill = fishingClient({
			PagleLog = log,
			UnitGUID = function()
				return ADA
			end,
		})
		local loaded = loadAddon("Pagle", globals)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
		return loaded, skill
	end

	for _, event in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do
		it(
			"are taken on " .. event .. ": SkillChanged after the append, then ConditionsChanged (LOG-R31, LOG-R32)",
			function()
				local loaded, skill = loggedIn()
				local log = loaded.env.PagleLog
				local fired = {}
				loaded.env.Pagle.RegisterCallback("Spec", "SkillChanged", function(_, reading)
					fired[#fired + 1] = { "SkillChanged", reading.rank, reading.seq, #log.entries }
				end)
				loaded.env.Pagle.RegisterCallback("Spec", "ConditionsChanged", function(_, changedKeys)
					fired[#fired + 1] = { "ConditionsChanged", changedKeys[1], #changedKeys }
				end)

				skill.rank = 87
				loaded.client.fire(event)

				assert.are.equal("S1|1|1791731700|2|87|150|0", log.entries[3])
				assert.are.same({ { "SkillChanged", 87, 3, 3 }, { "ConditionsChanged", "skill", 1 } }, fired)
			end
		)
	end

	it("append nothing for a modifier change alone, which still fires ConditionsChanged (LOG-R31, LOG-R32)", function()
		local loaded, skill = loggedIn()
		local fired = recordEvents(loaded, { "SkillChanged", "ConditionsChanged" })

		skill.mod = 25
		loaded.client.fire("SKILL_LINES_CHANGED")
		loaded.client.fire("SKILL_LINES_CHANGED")

		assert.are.equal(2, #loaded.env.PagleLog.entries)
		assert.are.equal(1, #fired)
		assert.are.same({ "skill" }, fired[1][2])
	end)

	it(
		"fire ConditionsChanged once for one skill-up that both skill events report, agreeing with GetConditions"
			.. " (LOG-R32, LOG-R47)",
		function()
			local loaded, skill = loggedIn()
			local fired = recordEvents(loaded, { "SkillChanged", "ConditionsChanged" })

			skill.rank = 87
			loaded.client.fire("SKILL_LINES_CHANGED")
			loaded.client.fire("CHAT_MSG_SKILL")

			assert.are.equal(3, #loaded.env.PagleLog.entries)
			assert.are.same({ "SkillChanged", "ConditionsChanged" }, { fired[1][1], fired[2][1] })
			assert.are.equal(2, #fired)
			assert.are.same({ "skill" }, fired[2][2])
			local conditions = loaded.env.Pagle.GetConditions()
			assert.are.same({ 87, 0 }, { conditions.skillRank, conditions.skillMod })
		end
	)

	it("fire no ConditionsChanged for the login reading: it's in the baseline (LOG-R1, LOG-R47)", function()
		local globals = fishingClient({
			PagleLog = savedLog({ "S1|1|1791731000|0|80|150|25" }),
			UnitGUID = function()
				return ADA
			end,
		})
		local loaded = loadAddon("Pagle", globals)
		local fired = recordEvents(loaded, { "SkillChanged", "ConditionsChanged" })

		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		assert.are.equal(1, #fired)
		assert.are.equal("SkillChanged", fired[1][1])
	end)

	it("are not taken again at login for a character whose last reading matches (LOG-R31)", function()
		local loaded =
			loggedIn(savedLog({ "B1|1|1791731000|0|70338|1.60.1|pagle-2026b", "S1|1|1791731001|0|86|150|0" }))

		assert.are.equal(2, #loaded.env.PagleLog.entries)
	end)
end)

describe("Pagle.GetAngler", function()
	it("gives the current character, each one's last Skill Reading and bestBaseSkill (LOG-R27)", function()
		local globals = fishingClient({
			PagleLog = savedLog({ "S1|1|1791731000|0|130|150|0" }),
		})
		local loaded = loadAddon("Pagle", globals)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		local angler = loaded.env.Pagle.GetAngler()

		assert.are.equal(loaded.env.PagleLog.logId, angler.logId)
		assert.are.equal(loaded.env.PagleLog.characters, angler.characters)
		assert.are.equal(2, angler.current)
		assert.are.same({ 130, 86 }, { angler.skill[1].rank, angler.skill[2].rank })
		assert.are.equal(130, angler.bestBaseSkill)
	end)
end)
