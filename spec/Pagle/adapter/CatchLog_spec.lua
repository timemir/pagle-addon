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
		"diagnostics",
		"summary",
		"pending",
		"cards",
		"writeUp",
		"coins",
		"goods",
		"projections",
	},
	profile = { "reloadReminder", "lengthUnit", "announcements", "appearance", "dock" },
}

-- Loads Core on Forever with these SavedVariables, as the client does at login.
---@param saved { PagleLog: table?, PagleDB: table? }
local function login(saved)
	---@type table<string, any>
	local globals = { PagleLog = saved.PagleLog, PagleDB = saved.PagleDB }
	for key, value in pairs(FOREVER_GLOBALS) do
		globals[key] = value
	end
	return loadAddon("Pagle", globals)
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

		assert.are.same({ format = 1, characters = {}, entries = {} }, loaded.env.PagleLog)
		assert.is_table(loaded.env.PagleDB)
		assert.are.same({}, loaded.printed)
	end)

	it("keep PagleDB in one shared Default profile, migrated to the current schema (CORE-R5)", function()
		local loaded = login({})

		assert.are.equal("Default", loaded.ns.db:GetCurrentProfile())
		assert.are.equal(1, loaded.ns.db.global.schemaVersion)
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

	it("start a new log from one in another format, keeping characters, and say so once (LOG-R18)", function()
		local loaded = login({ PagleLog = savedLog({ "C0|1|1791731690|0" }, 0) })

		local log = loaded.env.PagleLog
		assert.are.equal(1, log.format)
		assert.are.equal(ADA, log.characters[1].guid)
		assert.are.same({}, log.entries)
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
				"B1|1|1791731680|0|70338|1.60.1",
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
