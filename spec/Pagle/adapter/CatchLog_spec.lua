-- PagleLog and PagleDB as Core loads them at ADDON_LOADED (CORE-R5, LOG-R10, LOG-R18) and Pagle.IterateCatches
-- (LOG-R42), through the real TOC.

local ADA = "Player-4618-0A1B2C3D"

-- Every key catch-log.md › Data allows in PagleDB.
local PAGLEDB_KEYS = {
	global = {
		"schemaVersion",
		"lastBuild",
		"lastEndedSession",
		"decodeErrors",
		"dev",
		"diagnostics",
		"summary",
		"pending",
		"cards",
		"writeUp",
		"coins",
		"activityXP", -- activity-xp.md › Data (AXP-R3), from M8
		"tickets", -- refresh.md › Data (REF-R3), the Refresh totals
		"pushed", -- pushed-content.md › Data (PUSH-R13), from M8
		"goods",
		"projections",
		"minimap", -- CORE-R53, from M8.5
		"onboarding", -- onboarding.md › Data (ONB-R1)
		"pasteExports", -- paste-string.md › Data (PST-R40), from Track P
		"pasteCheckpoints", -- paste-string.md › Data (PST-R42)
		"tailSession", -- catch-log.md › Data (LOG-R98)
	},
	profile = {
		"reloadReminder",
		"lengthUnit",
		"announcements",
		"appearance",
		"dock",
		"books", -- core/book.md › Data (BOOK-R5)
		"anglerTooltips", -- anglers-in-game.md › Data (VIEW-R30), from Track V
	},
}

-- Loads Core on Forever with these SavedVariables, as the client does at login.
---@param saved { PagleLog: table?, PagleDB: table? }
local function login(saved)
	return loadAddon("Pagle", foreverWith({ PagleLog = saved.PagleLog, PagleDB = saved.PagleDB }))
end

local function catches(Pagle, afterSeq)
	local all = {}
	for record in Pagle.IterateCatches(afterSeq) do
		all[#all + 1] = record
	end
	return all
end

describe("Core's SavedVariables at load", function()
	it("start an empty PagleLog and a PagleDB on a fresh install, silently (CORE-R5, LOG-R10)", function()
		local loaded = login({})

		assert.are.same({ format = 4, characters = {}, blockSize = 256, count = 0, blocks = {} }, loaded.env.PagleLog)
		assert.is_table(loaded.env.PagleDB)
		assert.are.same({}, loaded.printed)
	end)

	it("keep PagleDB in one shared Default profile, migrated to the current schema (CORE-R5)", function()
		local loaded = login({})

		assert.are.equal("Default", loaded.ns.db:GetCurrentProfile())
		assert.are.equal(#loaded.ns.PAGLEDB_MIGRATIONS, loaded.ns.db.global.schemaVersion)
	end)

	it("load a PagleDB saved by an earlier login, profile keys and all, into the Default profile (CORE-R5)", function()
		local saved = loadAddon("Pagle", FOREVER_GLOBALS).env.PagleDB
		saved.global.decodeErrors = 2

		local loaded = login({ PagleDB = saved })

		assert.are.same({ ["Angler - Testrealm"] = "Default" }, saved.profileKeys)
		assert.is_table(loaded.ns.db)
		assert.are.equal("Default", loaded.ns.db:GetCurrentProfile())
		assert.are.equal(2, loaded.ns.db.global.decodeErrors)
	end)

	it("hold no PagleDB key outside catch-log.md › Data (CORE-R5)", function()
		local loaded = login({ PagleLog = savedLog({ "X9|1|1791731690|0" }) })
		catches(loaded.env.Pagle, 0)

		for scope, allowed in pairs(PAGLEDB_KEYS) do
			local known = {}
			for _, key in ipairs(allowed) do
				known[key] = true
			end
			local unknown = {}
			for key in pairs(loaded.ns.db[scope]) do
				if not known[key] then
					unknown[#unknown + 1] = scope .. "." .. key
				end
			end
			assert.are.same({}, unknown)
		end
	end)

	it("start a new log from a beta log (format 1), keeping characters, and say so once (LOG-R18)", function()
		local loaded = login({ PagleLog = savedLog({ "S1|1|1791731690|0|86|150|0" }, 1) })

		local log = loaded.env.PagleLog
		assert.are.equal(4, log.format)
		assert.are.equal(ADA, log.characters[1].guid)
		assert.are.same({}, logEntries(log))
		assert.are_not.equal("3f9a2c1e7b0d4a65", log.logId)
		assert.are.matches("^%x+$", log.logId)
		assert.are.same({ loaded.ns.L.LOG_FORMAT_CHANGED }, loaded.printed)
		assert.are.equal("Pagle: dev log format changed; started a new log.", loaded.ns.L.LOG_FORMAT_CHANGED)
	end)
end)

describe("Pagle.IterateCatches", function()
	it("yields the typed records after afterSeq, in order (LOG-R42)", function()
		local loaded = login({
			PagleLog = savedLog({
				"B1|1|1791731680|0|70338|1.60.1|pagle-2026a",
				"S1|1|1791731681|0|86|150|0",
				"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
			}),
		})

		local records = catches(loaded.env.Pagle, 1)

		assert.are.same({ 2, 3 }, { records[1].seq, records[2].seq })
		assert.are.same({ "skill", "cast" }, { records[1].kind, records[2].kind })
		assert.are.equal(ADA .. "-1791731747-0:1", records[2].items[1].catchId)
	end)

	it("skips an undecodable entry and counts it in PagleDB once per login (LOG-R16)", function()
		local loaded = login({
			PagleLog = savedLog({ "S1|1|1791731681|0|86|150|0", "X9|1|1791731690|0" }),
			PagleDB = { global = { decodeErrors = 4 } },
		})

		assert.are.equal(1, #catches(loaded.env.Pagle, 0))
		assert.are.equal(1, #catches(loaded.env.Pagle, 0))
		assert.are.equal(5, loaded.env.PagleDB.global.decodeErrors)
	end)
end)

describe("Core's SavedVariables at load, a Catch log it can't read (LOG-R104)", function()
	-- Copies a table, for comparing a log with what it was.
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local made = {}
		for key, item in pairs(value) do
			made[key] = copy(item)
		end
		return made
	end

	local function entries()
		return {
			"B1|1|1791731690|0|70374|1.60.1|pagle-2026a",
			"S1|1|1791731690|1|86|150|25",
			"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
		}
	end

	for name, damage in pairs({
		["a count that doesn't match its blocks"] = function(log)
			log.count = log.count + 1
		end,
		["a block that starts with a reserved byte"] = function(log)
			log.blocks[1] = "\1" .. log.blocks[1]
		end,
		["a missing blockSize"] = function(log)
			log.blockSize = nil
		end,
	}) do
		it(("stops with one line and leaves PagleLog exactly as it loaded, for %s"):format(name), function()
			local log = setLogEntries(savedLog(), entries(), 2)
			damage(log)
			local before = copy(log)

			local loaded = login({ PagleLog = log })

			assert.are.equal(log, loaded.env.PagleLog)
			assert.are.same(before, loaded.env.PagleLog)
			assert.is_true(loaded.ns.recoveryBlocked)
			assert.is_nil(loaded.ns.catchLog)
			assert.is_nil(loaded.env.Pagle)
			assert.are.equal(1, #loaded.printed)
			assert.is_truthy(loaded.printed[1]:find("can't be read", 1, true))
			assert.is_truthy(loaded.printed[1]:find("Before you log out", 1, true))
			assert.are.same({}, loaded.client.errors)
		end)
	end

	for name, change in pairs({
		["a newer format"] = function(log)
			log.format = 5
		end,
		["a format that isn't a number"] = function(log)
			log.format = "4"
		end,
	}) do
		it(("leaves a log with %s exactly as it is, and stops with the advice (LOG-R104)"):format(name), function()
			local log = setLogEntries(savedLog(), entries(), 2)
			change(log)
			local before = copy(log)

			local loaded = login({ PagleLog = log })

			assert.are.same(before, loaded.env.PagleLog)
			assert.is_true(loaded.ns.recoveryBlocked)
			assert.are.equal(1, #loaded.printed)
			for _, text in ipairs({ "Before you log out", "Pagle.lua.bak", "github.com/timemir/pagle-addon/issues" }) do
				assert(loaded.printed[1]:find(text, 1, true), text)
			end
			-- /pagle says why, not that Recovery paused it.
			loaded.env.SlashCmdList.PAGLE("")
			assert.is_truthy(loaded.printed[2]:find("Catch log can't be read", 1, true))
			assert.is_nil(loaded.printed[2]:find("Recovery", 1, true))
			assert.are.same({}, loaded.client.errors)
		end)
	end

	it("opens a readable log of several blocks and reads the same entries through Pagle.IterateCatches", function()
		local log = setLogEntries(savedLog(), entries(), 2)

		local loaded = login({ PagleLog = log })

		assert.is_nil(loaded.ns.recoveryBlocked)
		assert.are.equal(log, loaded.env.PagleLog)
		assert.are.equal(3, loaded.ns.loginSeq)
		assert.are.equal(3, loaded.env.PagleLog.count)
	end)
end)
