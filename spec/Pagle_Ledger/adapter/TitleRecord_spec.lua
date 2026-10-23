-- The Ledger's title record on FakePagle (LED-R157, #76 item 2): the title "Signed as" picks (LED-R77, LED-R146),
-- logged as a `title` Module record whenever it isn't the one the last title record the Ledger logged to this log
-- names, the frame after the pick changes or after the projection's done, so Pagle's backend can show the Angler's
-- title. Automatic is logged as an empty payload, and never while nothing is logged to this log. The fold ignores the
-- record (`activeTitle` stays the source in game), so the Ledger remembers what it logged in PagleLedgerDB.global.

local MACKEREL = 6303
local ELWYNN = 12
local T0 = SERVER_TIME - 700
local LOG = "0123456789abcdef"
local LEVEL1 = "title:level1" -- earned from the start (LED-R75)

-- Elwynn lists Mackerel alone.
local function catalogue()
	return catalogueWith({
		items = { [MACKEREL] = fishRecord(MACKEREL) },
		areas = { [ELWYNN] = areaRecord(0, { skillBase = 1, catches = { catchEntry(MACKEREL) } }) },
	})
end

-- A Ledger on a fake over the catalogue and a log with one Mackerel Catch (its logId LOG), with `saved` its
-- PagleLedgerDB from an earlier session, logged in and, unless `updating`, in the world (its projection built).
---@param options { saved: table?, updating: boolean? }?
---@return FakePagle fake
---@return LoadedAddon loaded
local function loggedIn(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue())
	fake.catchLog.data.logId = LOG
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	fake.catchLog:Append(castRecord({ time = T0, zone = ELWYNN, items = { MACKEREL } }))
	fake.globals.PagleLedgerDB = options.saved
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	if not options.updating then
		fake.enterWorld()
	end
	return fake, loaded
end

-- A PagleLedgerDB whose profile picks `title` and that noted `logged` as the last title record logged.
---@param title string?
---@param logged { logId: string, key: string }?
---@return table
local function savedDB(title, logged)
	return { profiles = { Default = { activeTitle = title } }, global = { titleLogged = logged } }
end

-- The payloads of the Ledger's title records in the log, in log order.
---@param fake FakePagle
---@return string[]
local function titleRecords(fake)
	local payloads = {}
	for record in fake.catchLog:Iterate(0, "Ledger") do
		local module = record --[[@as PagleModuleRecord]]
		if record.kind == "module" and module.recordKind == "title" then
			payloads[#payloads + 1] = module.payload
		end
	end
	return payloads
end

describe("the Ledger's title record (LED-R157, #76 item 2)", function()
	it("logs nothing while the title is automatic and nothing is logged to this log", function()
		local fake, loaded = loggedIn()
		loaded.client.runTimers()

		assert.are.same({}, titleRecords(fake))
	end)

	it(
		"logs the title the Player picks in Signed as, the frame after, and automatic again as an empty payload",
		function()
			local fake, loaded = loggedIn()
			loaded.client.runTimers()

			loaded.ns.PickActiveTitle(LEVEL1)
			assert.are.same({}, titleRecords(fake))
			loaded.client.runTimers()
			assert.are.same({ LEVEL1 }, titleRecords(fake))

			loaded.ns.PickActiveTitle(nil)
			loaded.client.runTimers()
			assert.are.same({ LEVEL1, "" }, titleRecords(fake))
			assert.are.same({ logId = LOG, key = "" }, loaded.ns.db.global.titleLogged)
		end
	)

	it("logs nothing for a title it may not set, nor for picking the title already logged", function()
		local fake, loaded = loggedIn()
		loaded.client.runTimers()
		loaded.ns.PickActiveTitle(LEVEL1)
		loaded.client.runTimers()

		assert.is_false(loaded.ns.SetActiveTitle("title:level60")) -- not earned on this log (LED-R77)
		loaded.ns.PickActiveTitle(LEVEL1)
		loaded.client.runTimers()

		assert.are.same({ LEVEL1 }, titleRecords(fake))
	end)

	it("folds nothing from it: the Ledger's state is the same with or without the record", function()
		local _, loaded = loggedIn()
		loaded.client.runTimers()
		local function copyOf(value)
			if type(value) ~= "table" then
				return value
			end
			local copy = {}
			for key, inner in pairs(value) do
				copy[key] = copyOf(inner)
			end
			return copy
		end
		local copy = copyOf(loaded.ns.StateNow())

		loaded.ns.PickActiveTitle(LEVEL1)
		loaded.client.runTimers()

		assert.are.same(copy, loaded.ns.StateNow())
	end)

	-- The catch-up (the backend dev's decision on #363): a title picked before the writer shipped still reaches the log.
	it("logs the title picked before this login once, at login, when it isn't the one last logged", function()
		local fake, loaded = loggedIn({ saved = savedDB(LEVEL1) })
		loaded.client.runTimers()
		loaded.client.runTimers()

		assert.are.same({ LEVEL1 }, titleRecords(fake))
	end)

	it("logs nothing at login when the last title record logged to this log names the pick", function()
		local fake, loaded = loggedIn({ saved = savedDB(LEVEL1, { logId = LOG, key = LEVEL1 }) })
		loaded.client.runTimers()

		assert.are.same({}, titleRecords(fake))
	end)

	it("logs the pick again on a new log, where the record noted belongs to another", function()
		local fake, loaded = loggedIn({ saved = savedDB(LEVEL1, { logId = "fedcba9876543210", key = LEVEL1 }) })
		loaded.client.runTimers()

		assert.are.same({ LEVEL1 }, titleRecords(fake))
	end)

	it("logs automatic at login when the last title record logged names a pick since undone", function()
		local fake, loaded = loggedIn({ saved = savedDB(nil, { logId = LOG, key = LEVEL1 }) })
		loaded.client.runTimers()

		assert.are.same({ "" }, titleRecords(fake))
	end)

	it("waits for the projection's done while it is updating, then logs", function()
		local fake, loaded = loggedIn({ saved = savedDB(LEVEL1), updating = true })
		loaded.client.runTimers()
		assert.are.same({}, titleRecords(fake))

		fake.enterWorld()
		loaded.client.runTimers()
		assert.are.same({ LEVEL1 }, titleRecords(fake))
	end)

	-- `/pagle trailer` runs on a disposable copy of the account (its PagleLedgerDB too): a title record written while
	-- it runs goes to the trailer's disposable log (ctx.moduleRecords), and its note to the copy.
	it("writes no title record to PagleLog for a pick made during the trailer, during it or after it", function()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
			also = { "Pagle_Ledger", "Pagle_Stats", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_QoL" },
		})
		loaded.client.areaNames[148] = "Darkshore"
		loaded.env.GetRealZoneText = function()
			return "Darkshore"
		end
		enterWorld(loaded, 5)
		loaded.client.advance(20)
		local ledger, log = loaded.namespaces.Pagle_Ledger, loaded.env.PagleLog
		-- The title records in PagleLog, as entries (LOG-R40).
		local function logged()
			local found = {}
			for _, entry in ipairs(log.entries) do
				if entry:find("^A1|%d+|%d+|%d+|Ledger|title|") then
					found[#found + 1] = entry
				end
			end
			return found
		end

		loaded.env.SlashCmdList.PAGLE("trailer")
		catchOne(loaded)
		loaded.client.advance(5)
		assert.is_true(ledger.SetActiveTitle(LEVEL1))
		loaded.client.advance(1)
		assert.are.same({}, logged())

		loaded.client.advance(260)
		assert.matches("trailer complete", loaded.printed[#loaded.printed])
		loaded.client.advance(1)
		assert.are.same({}, logged())
		assert.is_nil(ledger.db.profile.activeTitle)
		assert.are.same({}, loaded.client.errors)
	end)
end)
