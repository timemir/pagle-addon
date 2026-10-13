-- The character table, Skill Readings, build entries and the Angler (LOG-R25–R27, LOG-R31, LOG-R32, LOG-R36),
-- through ns.NewAngler, the logic/ seam Core's adapter wraps. The client's answers are passed in as plain values.

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local ADA = "Player-4618-0A1B2C3D"
local BRAM = "Player-4618-0F0E0D0C"
local T = 1791731700

-- Ada as the client describes her at login (LOG-R26).
local function ada(overrides)
	local seen = {
		guid = ADA,
		name = "Ada",
		surname = "Brook",
		classID = 1,
		raceID = 1,
		faction = "Alliance",
		realmID = 4618,
	}
	for key, value in pairs(overrides or {}) do
		seen[key] = value
	end
	return seen
end

local function bram()
	return { guid = BRAM, name = "Bram", classID = 9, raceID = 3, faction = "Alliance", realmID = 4618 }
end

-- An Angler over a PagleLog holding these characters and entries (a fresh install when both are nil).
local function anglerOver(characters, entries, global)
	local saved
	if characters or entries then
		saved = { format = 1, logId = "3f9a2c1e7b0d4a65", characters = characters or {}, entries = entries or {} }
	end
	local catchLog = ns.OpenCatchLog(saved, global or {}, T)
	return ns.NewAngler(catchLog), catchLog
end

describe("the character table", function()
	it("adds a character whose GUID is new, first and last seen now (LOG-R25, LOG-R26)", function()
		local angler, catchLog = anglerOver()

		assert.are.equal(1, angler:SeeCharacter(ada(), T))

		assert.are.same({
			{
				guid = ADA,
				name = "Ada",
				surname = "Brook",
				classID = 1,
				raceID = 1,
				faction = "Alliance",
				realmID = 4618,
				firstSeen = T,
				lastSeen = T,
			},
		}, catchLog.data.characters)
	end)

	it("updates lastSeen and the display fields of a known GUID, keeping firstSeen (LOG-R25)", function()
		local angler, catchLog = anglerOver()
		angler:SeeCharacter(bram(), T - 50)
		angler:SeeCharacter(ada({ hardcore = true }), T - 100)

		local index = angler:SeeCharacter(ada({ name = "Adda", surname = "Rook", faction = "Horde", raceID = 2 }), T)

		assert.are.equal(2, index)
		local character = catchLog.data.characters[2]
		assert.are.same({ "Adda", "Rook", "Horde", 2 }, { character.name, character.surname, character.faction, character.raceID })
		assert.are.same({ T - 100, T }, { character.firstSeen, character.lastSeen })
		assert.is_nil(character.hardcore)
		assert.are.equal(2, #catchLog.data.characters)
	end)

	it("never keeps selfFound, whatever it's handed (LOG-R26)", function()
		local angler, catchLog = anglerOver()

		angler:SeeCharacter(ada({ selfFound = true, hardcore = false }), T)

		assert.is_nil(catchLog.data.characters[1].selfFound)
		assert.is_false(catchLog.data.characters[1].hardcore)
	end)

	it("gives a fresh log its logId as soon as it has a character (LOG-R15)", function()
		local angler, catchLog = anglerOver()

		angler:SeeCharacter(ada(), T)

		assert.matches("^%x+$", catchLog.data.logId)
		assert.are.equal(16, #catchLog.data.logId)
	end)
end)

describe("ns.RealmIDFromGUID", function()
	it("reads the realm ID out of a player GUID (LOG-R26)", function()
		assert.are.equal(4618, ns.RealmIDFromGUID(ADA))
		assert.is_nil(ns.RealmIDFromGUID("Creature-0-1-2-3-4-5"))
	end)
end)

describe("build entries", function()
	local LOG_ID = "3f9a2c1e7b0d4a65"

	it("append a B1 into a log with none, and cache it (LOG-R36)", function()
		local global = {}
		local angler, catchLog = anglerOver({ ada() }, {}, global)
		angler:SeeCharacter(ada(), T)

		local build = angler:LogBuild(70338, "1.60.1", T)

		assert.are.same({ "B1|1|1791731700|0|70338|1.60.1" }, catchLog.data.entries)
		assert.are.same({ 1, "build", 70338, "1.60.1" }, { build.seq, build.kind, build.build, build.version })
		assert.are.same({ logId = LOG_ID, build = 70338 }, global.lastBuild)
	end)

	it("append nothing while the build is the cached one, and a B1 when it differs (LOG-R36)", function()
		local global = { lastBuild = { logId = LOG_ID, build = 70338 } }
		local angler, catchLog = anglerOver({ ada() }, { "B1|1|1791731000|0|70338|1.60.1" }, global)
		angler:SeeCharacter(ada(), T)

		assert.is_nil(angler:LogBuild(70338, "1.60.1", T))
		assert.is_table(angler:LogBuild(70412, "1.60.2", T + 1))

		assert.are.same({ "B1|1|1791731000|0|70338|1.60.1", "B1|1|1791731701|0|70412|1.60.2" }, catchLog.data.entries)
		assert.are.same({ logId = LOG_ID, build = 70412 }, global.lastBuild)
	end)

	for name, cache in pairs({ missing = false, ["of another logId"] = { logId = "0000000000000000", build = 1 } }) do
		it("rebuild a cache that is " .. name .. " by walking the log back to its last B1 (LOG-R36)", function()
			local global = { lastBuild = cache or nil }
			local angler, catchLog = anglerOver({ ada() }, {
				"B1|1|1791731000|0|70000|1.60.0",
				"B1|1|1791731100|0|70338|1.60.1",
				"S1|1|1791731200|0|86|150|0",
			}, global)
			angler:SeeCharacter(ada(), T)

			assert.is_nil(angler:LogBuild(70338, "1.60.1", T))

			assert.are.equal(3, #catchLog.data.entries)
			assert.are.same({ logId = LOG_ID, build = 70338 }, global.lastBuild)
		end)
	end

	it("trust a cache of this logId without reading the log (LOG-R36)", function()
		local global = { lastBuild = { logId = LOG_ID, build = 70412 } }
		local angler, catchLog = anglerOver({ ada() }, { "B1|1|1791731000|0|70338|1.60.1" }, global)
		angler:SeeCharacter(ada(), T)

		assert.is_nil(angler:LogBuild(70412, "1.60.2", T))
		assert.are.equal(1, #catchLog.data.entries)
	end)
end)

describe("Skill Readings", function()
	it("append an S1 for a character's first reading and hand back the record (LOG-R31)", function()
		local angler, catchLog = anglerOver()
		angler:SeeCharacter(ada(), T)

		local reading, changed = angler:ReadSkill({ rank = 86, max = 150, mod = 25 }, T)

		assert.are.same({ "S1|1|1791731700|0|86|150|25" }, catchLog.data.entries)
		assert.are.same(
			{ seq = 1, id = ADA .. "-1791731700-0", kind = "skill", char = 1, time = T, rank = 86, max = 150, mod = 25 },
			reading
		)
		assert.is_true(changed)
	end)

	it("append an S1 when the rank or the max rank changes (LOG-R31)", function()
		local angler, catchLog = anglerOver()
		angler:SeeCharacter(ada(), T)
		angler:ReadSkill({ rank = 86, max = 150, mod = 0 }, T)

		assert.is_table((angler:ReadSkill({ rank = 87, max = 150, mod = 0 }, T + 1)))
		assert.is_table((angler:ReadSkill({ rank = 87, max = 225, mod = 0 }, T + 2)))

		assert.are.same({
			"S1|1|1791731700|0|86|150|0",
			"S1|1|1791731701|0|87|150|0",
			"S1|1|1791731702|0|87|225|0",
		}, catchLog.data.entries)
	end)

	it("append nothing for a change in modifier alone, but report it as a change (LOG-R31, LOG-R32)", function()
		local angler, catchLog = anglerOver()
		angler:SeeCharacter(ada(), T)
		angler:ReadSkill({ rank = 86, max = 150, mod = 0 }, T)

		local reading, changed = angler:ReadSkill({ rank = 86, max = 150, mod = 25 }, T + 1)
		assert.is_nil(reading)
		assert.is_true(changed)

		reading, changed = angler:ReadSkill({ rank = 86, max = 150, mod = 25 }, T + 2)
		assert.is_nil(reading)
		assert.is_false(changed)
		assert.are.equal(1, #catchLog.data.entries)
	end)

	it("compare with the character's last Skill Reading in the saved log, not another's (LOG-R31)", function()
		local angler, catchLog = anglerOver({ ada(), bram() }, {
			"S1|1|1791731000|0|80|150|0",
			"S1|1|1791731050|0|86|150|0",
			"S1|2|1791731100|0|40|75|0",
			"C1|1|1791731200|0|c|494|1439|1|148|453|86|0||||6358x1",
		})
		angler:SeeCharacter(ada(), T)

		local reading, changed = angler:ReadSkill({ rank = 86, max = 150, mod = 0 }, T)
		assert.is_nil(reading)
		assert.is_false(changed)
		angler:SeeCharacter(bram(), T + 1)
		assert.is_table((angler:ReadSkill({ rank = 86, max = 150, mod = 0 }, T + 1)))
		assert.are.equal(5, #catchLog.data.entries)
	end)

	it("read nothing while no character is current, or when the character has no fishing (LOG-R30)", function()
		local angler, catchLog = anglerOver()

		assert.is_nil((angler:ReadSkill({ rank = 86, max = 150, mod = 0 }, T)))
		angler:SeeCharacter(ada(), T)
		local reading, changed = angler:ReadSkill(nil, T)

		assert.is_nil(reading)
		assert.is_false(changed)
		assert.are.same({}, catchLog.data.entries)
	end)
end)

describe("the Angler", function()
	it("is the log's logId and characters, the current one, each one's last reading and the best rank (LOG-R27)", function()
		local angler, catchLog = anglerOver({ ada(), bram() }, {
			"S1|1|1791731000|0|80|150|0",
			"S1|2|1791731100|0|120|150|0",
			"S1|1|1791731200|0|130|150|25",
		})
		angler:SeeCharacter(bram(), T)
		angler:ReadSkill({ rank = 125, max = 150, mod = 0 }, T)

		local result = angler:Get()

		assert.are.equal("3f9a2c1e7b0d4a65", result.logId)
		assert.are.equal(catchLog.data.characters, result.characters)
		assert.are.equal(2, result.current)
		assert.are.same({ 3, 4 }, { result.skill[1].seq, result.skill[2].seq })
		assert.are.same({ 130, 125 }, { result.skill[1].rank, result.skill[2].rank })
		assert.are.equal(130, result.bestBaseSkill)
	end)

	it("has no current character before login and a bestBaseSkill of 0 without readings (LOG-R27)", function()
		local result = anglerOver():Get()

		assert.is_nil(result.current)
		assert.are.same({}, result.characters)
		assert.are.same({}, result.skill)
		assert.are.equal(0, result.bestBaseSkill)
	end)
end)
