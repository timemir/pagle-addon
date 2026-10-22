-- Activity XP as Core runs it, through the real TOC (core/activity-xp.md, ADR 0011): M:ReportXPEarned,
-- PagleDB.global.activityXP, Pagle.GetActivityXP, ActivityXPChanged and the P1 entry's snapshot; and the Coins totals'
-- logId (SHOP-R3), which works the same way.

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's logId
local OLD_LOG = "0000000000000001" -- another log's

local ORDER = { Ledger = 10, Hunts = 20, TackleBoard = 40 }

-- Core over a saved log holding `entries` (Ada's 1 old Cast by default) and PagleDB `saved`, with the Ledger, Hunts
-- and the Tackle Board installed, so each can register.
---@param entries table?
---@param saved table?
---@return LoadedAddon
local function core(entries, saved)
	local loaded = loadCore(entries or history(1), saved)
	loaded.client.addons.Pagle_TackleBoard = { metadata = { ["X-Pagle-API"] = "1" } }
	return loaded
end

-- Registers a roster Module and returns its handle.
---@param loaded LoadedAddon
---@param name string
---@return table
local function register(loaded, name)
	return loaded.env.Pagle.RegisterModule({ name = name, title = name, order = ORDER[name] })
end

-- Each ActivityXPChanged Core fires from now on, as `{ entry }`, and the total Pagle.GetActivityXP gives then.
---@param loaded LoadedAddon
---@return { entry: PagleRecord?, total: integer }[]
local function listen(loaded)
	local fired = {}
	loaded.env.Pagle.RegisterCallback("spec", "ActivityXPChanged", function(_, entry)
		fired[#fired + 1] = { entry = entry, total = loaded.env.Pagle.GetActivityXP().total }
	end)
	return fired
end

-- A PagleDB saved by an earlier login, at the current schema, holding these Activity XP and Coins totals of `logId`.
---@param loaded LoadedAddon any Core, for its migrations
---@param logId string
---@param xp table<string, integer>
---@param coins table<string, integer>
---@return table
local function savedDB(loaded, logId, xp, coins)
	return {
		global = {
			schemaVersion = #loaded.ns.PAGLEDB_MIGRATIONS,
			activityXP = { earned = xp, logId = logId },
			coins = { earned = coins, logId = logId },
		},
	}
end

describe("M:ReportXPEarned", function()
	it("stores 150 under the Module's def.name and fires ActivityXPChanged once (AXP-R2, AXP-R3, AXP-R7)", function()
		local loaded = core()
		local hunts = register(loaded, "Hunts")
		enterWorld(loaded)
		local fired = listen(loaded)

		hunts:ReportXPEarned(150)

		assert.are.same({ Hunts = 150 }, loaded.env.PagleDB.global.activityXP.earned)
		assert.are.equal(LOG_ID, loaded.env.PagleDB.global.activityXP.logId)
		assert.are.same({ { total = 150 } }, fired)
	end)

	it("fires nothing for 150 again, and replaces it with a lower 100 (AXP-R4, AXP-R7)", function()
		local loaded = core()
		local hunts = register(loaded, "Hunts")
		enterWorld(loaded)
		hunts:ReportXPEarned(150)
		local fired = listen(loaded)

		hunts:ReportXPEarned(150)
		assert.are.same({}, fired)
		hunts:ReportXPEarned(100)

		assert.are.same({ { total = 100 } }, fired)
		assert.are.same({ Hunts = 100 }, loaded.env.PagleDB.global.activityXP.earned)
	end)

	for _, case in ipairs({
		{ "-1", -1 },
		{ "1.5", 1.5 },
		{ '"10"', "10" },
		{ "nothing", nil },
	}) do
		it("raises an error at the Module's call for " .. case[1] .. ", storing nothing (AXP-R2)", function()
			local loaded = core()
			local hunts = register(loaded, "Hunts")
			enterWorld(loaded)
			hunts:ReportXPEarned(10)
			local fired = listen(loaded)

			local ok, err = pcall(function()
				hunts:ReportXPEarned(case[2])
			end)

			assert.is_false(ok)
			assert.matches(
				"ActivityXP_spec.lua:%d+: M:ReportXPEarned takes a whole number of Activity XP",
				tostring(err)
			)
			assert.are.same({ Hunts = 10 }, loaded.env.PagleDB.global.activityXP.earned)
			assert.are.same({}, fired)
		end)
	end

	it("is a handle method: called on anything else, it raises an error (CORE-R12)", function()
		local loaded = core()
		local hunts = register(loaded, "Hunts")

		local ok, err = pcall(hunts.ReportXPEarned, {}, 10)

		assert.is_false(ok)
		assert.matches("ReportXPEarned is a Module handle method: call M:ReportXPEarned(total)", err, 1, true)
	end)

	it(
		"raises an error at the Module's call from a rebuild apply, storing nothing; its done reports (AXP-R2)",
		function()
			local loaded = core(history(2))
			local board = register(loaded, "TackleBoard")
			local raised = {}
			board:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return { xp = 0 }
				end,
				apply = function(state, record, mode)
					if record.kind == "cast" then
						state.xp = state.xp + 100
						local ok, err = pcall(function()
							board:ReportXPEarned(state.xp)
						end)
						raised[#raised + 1] = { mode, ok, tostring(err):match("ActivityXP_spec.lua:%d+: (.*)") }
					end
				end,
				done = function(state)
					board:ReportXPEarned(state.xp)
				end,
			})
			local fired = listen(loaded)

			enterWorld(loaded)

			local why = "M:ReportXPEarned can't report from a projection's rebuild: report from its done"
			assert.are.same({ { "rebuild", false, why }, { "rebuild", false, why } }, raised)
			assert.are.same({ TackleBoard = 200 }, loaded.env.PagleDB.global.activityXP.earned)
			assert.are.same({ { total = 200 } }, fired) -- from done: no entry (AXP-R7)
		end
	)

	it("hands ActivityXPChanged the live entry whose apply led to the report (AXP-R7)", function()
		local loaded = core()
		local board = register(loaded, "TackleBoard")
		board:NewProjection({
			db = {},
			rulesVersion = 1,
			reset = function()
				return { xp = 0 }
			end,
			apply = function(state, record, mode)
				if mode == "live" and record.kind == "module" then
					state.xp = state.xp + 150
					board:ReportXPEarned(state.xp)
				end
			end,
		})
		enterWorld(loaded)
		local fired = listen(loaded)

		local record = board:AppendRecord("notice", "n1")

		assert.are.equal(1, #fired)
		assert.are.equal(record.id, fired[1].entry.id)
		assert.are.equal(record.seq, fired[1].entry.seq)
		assert.are.equal(150, fired[1].total)
	end)
end)

describe("Pagle.GetActivityXP", function()
	it(
		"sums the stored totals, lists a disabled Module with enabled false and its last total, and leaves out one that"
			.. " never reported (AXP-R3, AXP-R6, AXP-R90)",
		function()
			local first = core()
			register(first, "Hunts"):ReportXPEarned(600)
			register(first, "TackleBoard"):ReportXPEarned(250)
			register(first, "Ledger")
			enterWorld(first)

			-- The next login, with Hunts disabled: it doesn't register, and the Tackle Board hasn't reported yet.
			local second = core(first.env.PagleLog, first.env.PagleDB)
			second.client.addons.Pagle_Hunts.enabled = false
			register(second, "TackleBoard")
			register(second, "Ledger")
			enterWorld(second)

			assert.are.same({
				total = 850,
				bySource = { Hunts = { total = 600, enabled = false }, TackleBoard = { total = 250, enabled = true } },
			}, second.env.Pagle.GetActivityXP())
		end
	)

	it("is 0 with no source before any Module reports (AXP-R6)", function()
		local loaded = enterWorld(core())

		assert.are.same({ total = 0, bySource = {} }, loaded.env.Pagle.GetActivityXP())
	end)

	it("hands out a fresh table each call, so a caller's change never reaches PagleDB (AXP-R6, CORE-R18)", function()
		local loaded = core(nil, savedDB(core(), LOG_ID, { Hunts = 300 }, {}))
		local first = loaded.env.Pagle.GetActivityXP()

		first.bySource.Hunts.total = 999

		assert.are_not.equal(first, loaded.env.Pagle.GetActivityXP())
		assert.are.same({ Hunts = 300 }, loaded.env.PagleDB.global.activityXP.earned)
	end)
end)

describe("The totals' logId at ADDON_LOADED", function()
	it("empties the Activity XP and Coins totals of another log and takes the new logId (AXP-R3, SHOP-R3)", function()
		local saved = savedDB(core(), OLD_LOG, { Hunts = 600, TackleBoard = 250 }, { Ledger = 5000, Hunts = 300 })

		local loaded = core(nil, saved)

		local global = loaded.env.PagleDB.global
		assert.are.same({ earned = {}, logId = LOG_ID }, global.activityXP)
		assert.are.same({ earned = {}, logId = LOG_ID }, global.coins)
		assert.are.same({ total = 0, bySource = {} }, loaded.env.Pagle.GetActivityXP())
		assert.are.same({ balance = 0, held = false, earned = {} }, loaded.env.Pagle.GetBalance())
	end)

	it("keeps both across a reload of the same log (AXP-R3, SHOP-R3)", function()
		local first = core()
		local hunts = register(first, "Hunts")
		enterWorld(first)
		hunts:ReportXPEarned(600)
		hunts:ReportCoinsEarned(300)

		local second = core(first.env.PagleLog, first.env.PagleDB)

		assert.are.same({ earned = { Hunts = 600 }, logId = LOG_ID }, second.env.PagleDB.global.activityXP)
		assert.are.same({ earned = { Hunts = 300 }, logId = LOG_ID }, second.env.PagleDB.global.coins)
		assert.are.equal(600, second.env.Pagle.GetActivityXP().total)
		assert.are.equal(300, second.env.Pagle.GetBalance().balance)
	end)

	it(
		"keeps a fresh log's first totals, reported before its logId existed at ADDON_LOADED (AXP-R3, LOG-R15)",
		function()
			local first = loadAddon("Pagle", FOREVER_GLOBALS) -- a fresh install: no PagleLog, so no logId yet
			first.client.addons.Pagle_Hunts = { metadata = { ["X-Pagle-API"] = "1" } }
			local hunts = first.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			enterWorld(first) -- PLAYER_LOGIN creates the logId
			hunts:ReportXPEarned(150)
			hunts:ReportCoinsEarned(20)
			assert.is_string(first.env.PagleLog.logId)

			local second =
				loadAddon("Pagle", foreverWith({ PagleLog = first.env.PagleLog, PagleDB = first.env.PagleDB }))

			assert.are.equal(150, second.env.Pagle.GetActivityXP().total)
			assert.are.equal(20, second.env.Pagle.GetBalance().balance)
		end
	)

	it(
		"keeps the Coins totals PagleDB held before M8 stored their logId: migration step 3 (SHOP-R3, SHOP-R4)",
		function()
			local saved = { global = { schemaVersion = 2, coins = { earned = { Ledger = 1200, Hunts = 300 } } } }

			local loaded = core(nil, saved)

			assert.are.same(
				{ earned = { Ledger = 1200, Hunts = 300 }, logId = LOG_ID },
				loaded.env.PagleDB.global.coins
			)
			assert.are.equal(1500, loaded.env.Pagle.GetBalance().balance)
		end
	)

	it("counts the new log's purchases against the emptied Coins, never the old log's (SHOP-R3, SHOP-R4)", function()
		local entries = history(1)
		entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, "core.toaststyle.ripple", 150)
		local loaded = core(entries, savedDB(core(), OLD_LOG, {}, { Ledger = 5000 }))
		local ledger = register(loaded, "Ledger")
		enterWorld(loaded)

		-- SHOP-R12: earned 0 is below the 150 this log spent, until the Ledger's report fills its total in again.
		assert.are.same({ balance = 0, held = true, earned = {} }, loaded.env.Pagle.GetBalance())
		ledger:ReportCoinsEarned(400)
		assert.are.same({ balance = 250, held = false, earned = { Ledger = 400 } }, loaded.env.Pagle.GetBalance())
	end)
end)

describe("The Prestige snapshot", function()
	it("writes the sum of the stored totals as the P1 entry's activityXP (AXP-R5, LOG-R38)", function()
		local loaded = core(nil, savedDB(core(), LOG_ID, { Hunts = 600 }, {})) -- Hunts is disabled: still counts
		local board, ledger = register(loaded, "TackleBoard"), register(loaded, "Ledger")
		enterWorld(loaded)
		board:ReportXPEarned(250)
		loaded.client.advance(60)

		local prestige = ledger:RecordPrestige()

		local entries = loaded.env.PagleLog.entries
		assert.are.equal(prestigeEntry(SERVER_TIME + 60, 1, 0, 2, 850), entries[#entries])
		assert.are.equal(850, prestige.activityXP)
	end)

	it(
		"holds the totals as they stand while another Module is updating; a later rise lands after it (AXP-R92)",
		function()
			local loaded = core(history(3), savedDB(core(), LOG_ID, { TackleBoard = 100 }, {}))
			local board, ledger = register(loaded, "TackleBoard"), register(loaded, "Ledger")
			local logged = #loaded.env.PagleLog.entries
			board:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function()
					board:ReportXPEarned(400)
				end,
			})
			loaded.client.fire("PLAYER_LOGIN")
			assert.is_true(loaded.ns.projections:IsUpdating()) -- no catch-up has started yet

			local prestige = ledger:RecordPrestige()
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

			assert.are.equal(100, prestige.activityXP)
			assert.are.equal(400, loaded.env.Pagle.GetActivityXP().total)
			assert.is_truthy(loaded.env.PagleLog.entries[logged + 1]:match("^P1|.*|1|100$"))
		end
	)

	it("takes no Activity XP from the caller: M:RecordPrestige ignores what it is passed (AXP-R5)", function()
		local loaded = core(nil, savedDB(core(), LOG_ID, { Hunts = 600 }, {}))
		local ledger = register(loaded, "Ledger")
		enterWorld(loaded)

		local prestige = ledger:RecordPrestige(99999)

		assert.are.equal(600, prestige.activityXP)
	end)
end)
