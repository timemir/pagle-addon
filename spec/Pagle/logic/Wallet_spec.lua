-- The wallet's earned totals and balance (wallet-and-shop.md › Earning, SHOP-R12, `BalanceChanged`), as pure logic.

describe("ns.NewWallet", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- A wallet over `earned` (PagleDB.global.coins.earned), with each BalanceChanged it fires collected.
	local function newWallet(earned)
		local fired = {}
		local wallet = ns.NewWallet(function(event, balance)
			fired[#fired + 1] = { event = event, balance = balance }
		end)
		wallet:Open(earned or {})
		return wallet, fired
	end

	it("adds every Module's last total into the balance, none held (SHOP-R3, SHOP-R12)", function()
		local wallet = newWallet()

		wallet:Report("Ledger", 1200)
		wallet:Report("TackleBoard", 750)

		assert.are.same({ balance = 1950, held = false, earned = { Ledger = 1200, TackleBoard = 750 } }, wallet:Get())
	end)

	it("lowers only the reporting Module's total on a lower report (SHOP-R4)", function()
		local wallet = newWallet()
		wallet:Report("Ledger", 1200)
		wallet:Report("TackleBoard", 750)

		wallet:Report("Ledger", 1100)

		assert.are.same({ Ledger = 1100, TackleBoard = 750 }, wallet:Get().earned)
		assert.are.equal(1850, wallet:Get().balance)
	end)

	it("stores each total in the table it opened, by def.name (SHOP-R3)", function()
		local earned = {}
		local wallet = newWallet(earned)

		wallet:Report("Hunts", 30)

		assert.are.same({ Hunts = 30 }, earned)
	end)

	it("counts a total already stored, with no report this session (SHOP-R3, SHOP-R90)", function()
		local wallet = newWallet({ Hunts = 300, Ledger = 20 })

		assert.are.same({ balance = 320, held = false, earned = { Hunts = 300, Ledger = 20 } }, wallet:Get())
	end)

	it("fires BalanceChanged once per change, with the new Balance (wallet-and-shop.md › Contracts)", function()
		local wallet, fired = newWallet()

		wallet:Report("Ledger", 20)
		wallet:Report("Ledger", 40)

		assert.are.same({
			{ event = "BalanceChanged", balance = { balance = 20, held = false, earned = { Ledger = 20 } } },
			{ event = "BalanceChanged", balance = { balance = 40, held = false, earned = { Ledger = 40 } } },
		}, fired)
	end)

	it("fires nothing for a report equal to the stored total (SHOP-R2, wallet-and-shop.md › Contracts)", function()
		local wallet, fired = newWallet({ Ledger = 40 })

		wallet:Report("Ledger", 40)

		assert.are.same({}, fired)
	end)

	it("fires for a first report of 0, which adds a Module to `earned` (wallet-and-shop.md › Contracts)", function()
		local wallet, fired = newWallet()

		wallet:Report("Stats", 0)

		assert.are.same(
			{ { event = "BalanceChanged", balance = { balance = 0, held = false, earned = { Stats = 0 } } } },
			fired
		)
	end)

	it("shows 0, held, while earned is below spent, and new Coins fill the gap first (SHOP-R12, SHOP-R91)", function()
		local wallet = newWallet({ Ledger = 620, TackleBoard = 3130 })
		wallet:SetSpent(4150)

		assert.are.same({ balance = 0, held = true, earned = { Ledger = 620, TackleBoard = 3130 } }, wallet:Get())
		wallet:Report("TackleBoard", 3530)
		assert.are.same({ balance = 0, held = false }, { balance = wallet:Get().balance, held = wallet:Get().held })
		wallet:Report("TackleBoard", 3580)
		assert.are.equal(50, wallet:Get().balance)
	end)

	it("fires on a spent change only when the balance or held changes (wallet-and-shop.md › Contracts)", function()
		local wallet, fired = newWallet({ Ledger = 100 })

		wallet:SetSpent(150) -- 100 -> 0, held
		wallet:SetSpent(400) -- still 0 and held
		wallet:SetSpent(400)

		assert.are.same({
			{ event = "BalanceChanged", balance = { balance = 0, held = true, earned = { Ledger = 100 } } },
		}, fired)
	end)

	it("hands out a copy, so changing a Balance never changes the wallet (CORE-R18)", function()
		local earned = { Ledger = 10 }
		local wallet = newWallet(earned)

		wallet:Get().earned.Ledger = 999

		assert.are.same({ Ledger = 10 }, earned)
	end)
end)

describe("ns.CoinTotalProblem", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("accepts a whole number of Coins, 0 or more (SHOP-R2)", function()
		for _, total in ipairs({ 0, 1, 1950, 2 ^ 31 }) do
			assert.is_nil(ns.CoinTotalProblem(total))
		end
	end)

	it("refuses a negative number, a fraction, a string, nil, NaN or infinity (SHOP-R2)", function()
		for _, total in ipairs({ -1, 2.5, "150", true, {}, 0 / 0, math.huge }) do
			assert.is_string(ns.CoinTotalProblem(total))
		end
		assert.is_string(ns.CoinTotalProblem(nil))
	end)
end)
