-- The Refresh purse as Core runs it, through the real TOC (core/refresh.md, ADR 0017): M:ReportTicketsEarned,
-- M:ReportTicketsSpent, PagleDB.global.tickets, Pagle.GetTickets and TicketsChanged.

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

-- Each TicketsChanged Core fires from now on.
---@param loaded LoadedAddon
---@return PagleTickets[]
local function listen(loaded)
	local fired = {}
	loaded.env.Pagle.RegisterCallback("spec", "TicketsChanged", function(_, tickets)
		fired[#fired + 1] = tickets
	end)
	return fired
end

-- A PagleDB saved by an earlier login, at the current schema, holding these Refresh totals of `logId`.
---@param loaded LoadedAddon any Core, for its migrations
---@param logId string
---@param earned table<string, integer>
---@param spent table<string, integer>
---@return table
local function savedDB(loaded, logId, earned, spent)
	return {
		global = {
			schemaVersion = #loaded.ns.PAGLEDB_MIGRATIONS,
			tickets = { earned = earned, spent = spent, logId = logId },
		},
	}
end

describe("M:ReportTicketsEarned and M:ReportTicketsSpent", function()
	it(
		"store a total each under the Module's def.name, tied to the log, and fire TicketsChanged (REF-R2, REF-R3)",
		function()
			local loaded = core()
			local hunts, board = register(loaded, "Hunts"), register(loaded, "TackleBoard")
			enterWorld(loaded)
			local fired = listen(loaded)

			hunts:ReportTicketsEarned(5)
			board:ReportTicketsSpent(2)

			local stored = loaded.env.PagleDB.global.tickets
			assert.are.same({ Hunts = 5 }, stored.earned)
			assert.are.same({ TackleBoard = 2 }, stored.spent)
			assert.are.equal(LOG_ID, stored.logId)
			assert.are.same({
				{ tickets = 5, earned = 5, spent = 0 },
				{ tickets = 3, earned = 5, spent = 2 },
			}, fired)
		end
	)

	it("fire nothing for a total equal to the stored one, and replace it with a lower one (REF-R2, REF-R4)", function()
		local loaded = core()
		local hunts = register(loaded, "Hunts")
		enterWorld(loaded)
		hunts:ReportTicketsEarned(5)
		local fired = listen(loaded)

		hunts:ReportTicketsEarned(5)
		assert.are.same({}, fired)
		hunts:ReportTicketsEarned(3)

		assert.are.same({ { tickets = 3, earned = 3, spent = 0 } }, fired)
		assert.are.same({ Hunts = 3 }, loaded.env.PagleDB.global.tickets.earned)
	end)

	for _, method in ipairs({ "ReportTicketsEarned", "ReportTicketsSpent" }) do
		for _, case in ipairs({
			{ "-1", -1 },
			{ "1.5", 1.5 },
			{ '"3"', "3" },
			{ "nothing", nil },
		}) do
			it(
				"raise an error at the Module's call to "
					.. method
					.. " for "
					.. case[1]
					.. ", storing nothing (REF-R2)",
				function()
					local loaded = core()
					local hunts = register(loaded, "Hunts")
					enterWorld(loaded)
					hunts:ReportTicketsEarned(4)
					local fired = listen(loaded)

					local ok, err = pcall(function()
						hunts[method](hunts, case[2])
					end)

					assert.is_false(ok)
					assert.matches(
						"Tickets_spec.lua:%d+: M:" .. method .. " takes a whole number of Refreshes",
						tostring(err)
					)
					assert.are.same({ tickets = 4, earned = 4, spent = 0 }, loaded.env.Pagle.GetTickets())
					assert.are.same({}, fired)
				end
			)
		end

		it("are handle methods: " .. method .. " called on anything else raises an error (CORE-R12)", function()
			local loaded = core()
			local hunts = register(loaded, "Hunts")

			local ok, err = pcall(hunts[method], {}, 3)

			assert.is_false(ok)
			assert.matches(method .. " is a Module handle method: call M:" .. method .. "(total)", err, 1, true)
		end)
	end

	it("make no chat line of their own, and keep working while restricted (REF-R7)", function()
		local loaded = core()
		local hunts = register(loaded, "Hunts")
		enterWorld(loaded)
		setCombat(loaded, true)

		hunts:ReportTicketsEarned(5)

		assert.are.same({}, loaded.printed)
		assert.are.equal(5, loaded.env.Pagle.GetTickets().tickets)
	end)
end)

describe("Pagle.GetTickets", function()
	it("is 0 of 0 and 0 with no Module reported (REF-R5)", function()
		local loaded = enterWorld(core())

		assert.are.same({ tickets = 0, earned = 0, spent = 0 }, loaded.env.Pagle.GetTickets())
	end)

	it("adds the earned totals of two Modules and subtracts the spent ones (REF-R5)", function()
		local loaded = core()
		local hunts, ledger, board =
			register(loaded, "Hunts"), register(loaded, "Ledger"), register(loaded, "TackleBoard")
		enterWorld(loaded)

		hunts:ReportTicketsEarned(5)
		ledger:ReportTicketsEarned(2)
		board:ReportTicketsSpent(3)

		assert.are.same({ tickets = 4, earned = 7, spent = 3 }, loaded.env.Pagle.GetTickets())
	end)

	it("floors at 0 when more is spent than earned, and counts again from there (REF-R4, REF-R5)", function()
		local loaded = core()
		local hunts, board = register(loaded, "Hunts"), register(loaded, "TackleBoard")
		enterWorld(loaded)
		hunts:ReportTicketsEarned(2)
		board:ReportTicketsSpent(3)

		assert.are.same({ tickets = 0, earned = 2, spent = 3 }, loaded.env.Pagle.GetTickets())

		hunts:ReportTicketsEarned(4)
		assert.are.equal(1, loaded.env.Pagle.GetTickets().tickets)
	end)

	it("hands out a fresh table each call, so a caller's change never reaches PagleDB (REF-R6, CORE-R18)", function()
		local loaded = core(nil, savedDB(core(), LOG_ID, { Hunts = 3 }, {}))
		local first = loaded.env.Pagle.GetTickets()

		first.tickets = 999

		assert.are.same({ tickets = 3, earned = 3, spent = 0 }, loaded.env.Pagle.GetTickets())
		assert.are.same({ Hunts = 3 }, loaded.env.PagleDB.global.tickets.earned)
	end)

	it("still counts a disabled Module's last reported totals (REF-R3, REF-R90)", function()
		local first = core()
		register(first, "Hunts"):ReportTicketsEarned(6)
		register(first, "TackleBoard"):ReportTicketsSpent(1)
		enterWorld(first)

		-- The next login, with Hunts and the Tackle Board disabled: neither registers, so neither reports.
		local second = core(first.env.PagleLog, first.env.PagleDB)
		second.client.addons.Pagle_Hunts.enabled = false
		second.client.addons.Pagle_TackleBoard.enabled = false
		enterWorld(second)

		assert.are.same({ tickets = 5, earned = 6, spent = 1 }, second.env.Pagle.GetTickets())
	end)
end)

describe("PagleDB.global.tickets", function()
	it("is { earned = {}, spent = {} } for a PagleDB that never stored it, before the log's logId (REF-R3)", function()
		-- A DB from before the purse: schema 3, Coins and Activity XP only.
		local saved = { global = { schemaVersion = 3, coins = { earned = {}, logId = LOG_ID } } }

		local loaded = core(nil, saved)

		assert.are.same({ earned = {}, spent = {}, logId = LOG_ID }, loaded.env.PagleDB.global.tickets)
		assert.are.same({ tickets = 0, earned = 0, spent = 0 }, loaded.env.Pagle.GetTickets())
	end)

	it("is emptied, and takes the new logId, when PagleLog.logId differs from the stored one (REF-R3)", function()
		local saved = savedDB(core(), OLD_LOG, { Hunts = 6 }, { TackleBoard = 2 })

		local loaded = core(nil, saved)

		assert.are.same({ earned = {}, spent = {}, logId = LOG_ID }, loaded.env.PagleDB.global.tickets)
		assert.are.same({ tickets = 0, earned = 0, spent = 0 }, loaded.env.Pagle.GetTickets())
	end)

	it("keeps both totals across a reload of the same log (REF-R3)", function()
		local first = core()
		local hunts, board = register(first, "Hunts"), register(first, "TackleBoard")
		enterWorld(first)
		hunts:ReportTicketsEarned(6)
		board:ReportTicketsSpent(2)

		local second = core(first.env.PagleLog, first.env.PagleDB)

		assert.are.same(
			{ earned = { Hunts = 6 }, spent = { TackleBoard = 2 }, logId = LOG_ID },
			second.env.PagleDB.global.tickets
		)
		assert.are.same({ tickets = 4, earned = 6, spent = 2 }, second.env.Pagle.GetTickets())
	end)

	it(
		"keeps a fresh log's first totals, reported before its logId existed at ADDON_LOADED (REF-R3, LOG-R15)",
		function()
			local first = loadAddon("Pagle", FOREVER_GLOBALS) -- a fresh install: no PagleLog, so no logId yet
			first.client.addons.Pagle_Hunts = { metadata = { ["X-Pagle-API"] = "1" } }
			local hunts = first.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			enterWorld(first) -- PLAYER_LOGIN creates the logId
			hunts:ReportTicketsEarned(3)
			assert.is_string(first.env.PagleLog.logId)

			local second =
				loadAddon("Pagle", foreverWith({ PagleLog = first.env.PagleLog, PagleDB = first.env.PagleDB }))

			assert.are.equal(3, second.env.Pagle.GetTickets().tickets)
		end
	)
end)
