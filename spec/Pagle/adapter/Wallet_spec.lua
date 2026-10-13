-- The wallet as Core runs it, through the real TOC (wallet-and-shop.md › Earning, SHOP-R12, SHOP-R90–R96):
-- M:ReportCoinsEarned, PagleDB.global.coins.earned, Pagle.GetBalance and BalanceChanged.

-- Loads Core on Forever with this PagleDB and the Ledger, Hunts and Tackle Board installed, so each can register.
---@param PagleDB table?
---@return LoadedAddon
local function loadCore(PagleDB)
	local loaded = loadAddon("Pagle", foreverWith({ PagleDB = PagleDB }))
	for _, name in ipairs({ "Ledger", "Hunts", "TackleBoard" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

local ORDER = { Ledger = 10, Hunts = 20, TackleBoard = 40 }

-- Registers a roster Module and returns its handle.
---@param loaded LoadedAddon
---@param name string
local function register(loaded, name)
	return loaded.env.Pagle.RegisterModule({ name = name, title = name, order = ORDER[name] })
end

-- Each BalanceChanged Core fires from now on.
---@param loaded LoadedAddon
---@return Balance[]
local function listen(loaded)
	local fired = {}
	loaded.env.Pagle.RegisterCallback("spec", "BalanceChanged", function(_, balance)
		fired[#fired + 1] = balance
	end)
	return fired
end

describe("M:ReportCoinsEarned", function()
	it("adds two Modules' totals in the balance, stored in PagleDB by def.name (SHOP-R3, SHOP-R12)", function()
		local loaded = loadCore()
		local ledger, board = register(loaded, "Ledger"), register(loaded, "TackleBoard")
		loaded.client.fire("PLAYER_LOGIN")

		ledger:ReportCoinsEarned(1200)
		board:ReportCoinsEarned(750)

		assert.are.same(
			{ balance = 1950, held = false, earned = { Ledger = 1200, TackleBoard = 750 } },
			loaded.env.Pagle.GetBalance()
		)
		assert.are.same({ Ledger = 1200, TackleBoard = 750 }, loaded.env.PagleDB.global.coins.earned)
	end)

	it("lowers only the reporting Module's total on a lower report (SHOP-R4)", function()
		local loaded = loadCore()
		local ledger, board = register(loaded, "Ledger"), register(loaded, "TackleBoard")
		ledger:ReportCoinsEarned(1720)
		board:ReportCoinsEarned(2030)

		ledger:ReportCoinsEarned(620)

		assert.are.same({ Ledger = 620, TackleBoard = 2030 }, loaded.env.Pagle.GetBalance().earned)
		assert.are.equal(2650, loaded.env.Pagle.GetBalance().balance)
	end)

	it("fires BalanceChanged once per change, and never for a report equal to the stored total", function()
		local loaded = loadCore({ global = { coins = { earned = { Ledger = 40 } } } })
		local ledger = register(loaded, "Ledger")
		local fired = listen(loaded)

		ledger:ReportCoinsEarned(40) -- unchanged since last session (SHOP-R2's refill report)
		ledger:ReportCoinsEarned(60)
		ledger:ReportCoinsEarned(60)

		assert.are.same({ { balance = 60, held = false, earned = { Ledger = 60 } } }, fired)
	end)

	for _, case in ipairs({
		{ "a negative number", -5 },
		{ "a fraction", 12.5 },
		{ "a string", "150" },
		{ "nothing", nil },
	}) do
		it("raises an error at the Module's call for " .. case[1] .. ", storing nothing (SHOP-R2)", function()
			local loaded = loadCore()
			local ledger = register(loaded, "Ledger")
			ledger:ReportCoinsEarned(10)
			local fired = listen(loaded)

			local ok, err = pcall(ledger.ReportCoinsEarned, ledger, case[2])

			assert.is_false(ok)
			assert.matches("ReportCoinsEarned takes a whole number of Coins", err, 1, true)
			assert.are.same({ Ledger = 10 }, loaded.env.Pagle.GetBalance().earned)
			assert.are.same({}, fired)
		end)
	end

	it("names the Module's own line in the error (SHOP-R2)", function()
		local loaded = loadCore()
		local ledger = register(loaded, "Ledger")

		local ok, err = pcall(function()
			ledger:ReportCoinsEarned(-1)
		end)

		assert.is_false(ok)
		assert.matches("Wallet_spec.lua:%d+:", tostring(err))
	end)

	it("is a handle method: called on anything else, it raises an error (CORE-R12)", function()
		local loaded = loadCore()
		local ledger = register(loaded, "Ledger")

		assert.has_error(function()
			ledger.ReportCoinsEarned({}, 10)
		end)
	end)

	it("makes no Announcement or chat line of its own (SHOP-R5)", function()
		local loaded = loadCore()
		local ledger = register(loaded, "Ledger")
		loaded.client.fire("PLAYER_LOGIN")

		ledger:ReportCoinsEarned(100)

		assert.are.same({}, loaded.printed)
	end)

	it("keeps working while restricted (SHOP-R93)", function()
		local loaded = loadCore()
		local ledger = register(loaded, "Ledger")
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)
		local fired = listen(loaded)

		ledger:ReportCoinsEarned(100)

		assert.are.equal(100, loaded.env.Pagle.GetBalance().balance)
		assert.are.equal(1, #fired)
	end)
end)

describe("The balance across logins", function()
	it(
		"still counts a Module that reported last session and is disabled now, with no report (SHOP-R3, SHOP-R90)",
		function()
			local first = loadCore()
			register(first, "Hunts"):ReportCoinsEarned(300)
			register(first, "Ledger"):ReportCoinsEarned(20)
			first.client.fire("PLAYER_LOGIN")

			-- The next login, with Hunts disabled: only the Ledger registers, and it hasn't reported yet.
			-- (Only the account-wide part goes on: the fake client can't validate AceDB's profile keys.)
			local second = loadCore({ global = first.env.PagleDB.global })
			second.client.addons.Pagle_Hunts = nil
			register(second, "Ledger")
			second.client.fire("PLAYER_LOGIN")

			assert.are.same(
				{ balance = 320, held = false, earned = { Hunts = 300, Ledger = 20 } },
				second.env.Pagle.GetBalance()
			)
		end
	)

	it("pays nothing for Casts or Catches: a log of Casts with no Module reporting is 0 (SHOP-R1)", function()
		local loaded = loadAddon(
			"Pagle",
			foreverWith({ PagleLog = savedLog({ "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1" }) })
		)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD")

		assert.are.same({ balance = 0, held = false, earned = {} }, loaded.env.Pagle.GetBalance())
	end)

	it("shows 0 and held while earned is below spent, and BalanceChanged says so (SHOP-R12, SHOP-R91)", function()
		local loaded = loadCore({ global = { coins = { earned = { Ledger = 1720, TackleBoard = 2030 } } } })
		local ledger = register(loaded, "Ledger")
		loaded.client.fire("PLAYER_LOGIN")
		-- Nothing spends before the Curio Shop (M4): spent is set directly.
		loaded.ns.wallet:SetSpent(3700)
		local fired = listen(loaded)

		ledger:ReportCoinsEarned(620) -- a rebuild recounts the Ledger lower

		local held = { balance = 0, held = true, earned = { Ledger = 620, TackleBoard = 2030 } }
		assert.are.same(held, loaded.env.Pagle.GetBalance())
		assert.are.same({ held }, fired)
	end)

	it("hands out a copy each time, so a caller's change never reaches PagleDB (CORE-R18)", function()
		local loaded = loadCore({ global = { coins = { earned = { Ledger = 10 } } } })

		loaded.env.Pagle.GetBalance().earned.Ledger = 999

		assert.are.same({ Ledger = 10 }, loaded.env.PagleDB.global.coins.earned)
	end)
end)
