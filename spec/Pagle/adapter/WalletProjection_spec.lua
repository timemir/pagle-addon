-- The wallet projection on the client (wallet-and-shop.md › Spending, SHOP-R10–R12, SHOP-R34, SHOP-R91, LOG-R78):
-- Core's own projection in PagleDB.global.projections.wallet, over a saved log's purchase entries (U1), through the
-- real TOC, feeding Pagle.GetBalance, BalanceChanged, Pagle.IsOwned and Pagle.GetEquipped.

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's
local VELVET, SILK = "hunts.cover.velvet", "hunts.cover.silk"

-- Ada's history: `n` old Casts and the build entry, then her purchases of the Velvet cover at 150 and the Silk one
-- at 400, and a second Velvet purchase, which counts for nothing (SHOP-R11).
local function purchases(n)
	local entries = history(n)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 3000, VELVET, 150)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, SILK, 400)
	entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1000, VELVET, 150)
	return entries
end

-- Core over a saved log of `entries` and PagleDB `saved`, with Hunts registered and its notebook cover slot: Plain the
-- default, Velvet and Silk for sale. Before PLAYER_LOGIN.
local function huntsCore(entries, saved)
	local loaded = loadCore(entries, saved)
	local hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
	hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
	hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
	hunts:RegisterGood({ id = VELVET, slot = "hunts.cover", name = "Velvet", tier = 1 })
	hunts:RegisterGood({ id = SILK, slot = "hunts.cover", name = "Silk", tier = 2 })
	return loaded, hunts
end

-- Each event Core fires from now on, as "<event> <payload>".
local function listen(loaded)
	local fired = {}
	local Pagle = loaded.env.Pagle
	Pagle.RegisterCallback("spec", "BalanceChanged", function(_, balance)
		fired[#fired + 1] = ("BalanceChanged %d%s"):format(balance.balance, balance.held and " held" or "")
	end)
	Pagle.RegisterCallback("spec", "AppearanceChanged", function(_, slot, goodID)
		fired[#fired + 1] = ("AppearanceChanged %s %s"):format(slot, goodID)
	end)
	return fired
end

-- What the wallet projection stores after the purchases above.
local BOTH = {
	spent = 550,
	purchased = { [VELVET] = true, [SILK] = true },
	ownedAt = { [VELVET] = SERVER_TIME - 3000, [SILK] = SERVER_TIME - 2000 },
}

describe("the wallet projection", function()
	it(
		"is Core's own, after the Field report's, bound to PagleDB.global.projections.wallet with rules version 3 and"
			.. " the content fingerprint alone (LOG-R70, LOG-R78)",
		function()
			local loaded = enterWorld(loadCore(purchases(2)))

			local global = loaded.env.PagleDB.global
			local db = global.projections.wallet
			assert.are.same({ 3, loaded.env.Pagle.CONTENT_FINGERPRINT, LOG_ID, loaded.env.PagleLog.count }, {
				db.rulesVersion,
				db.fingerprint,
				db.logId,
				db.lastSeq,
			})
			-- Core's projections come first, in the order login step 1 binds them.
			local list = loaded.ns.projections.list
			assert.are.same({ global.projections.fieldReport, db }, { list[1].def.db, list[2].def.db })
		end
	)

	it("binds to a PagleDB saved before M4, which holds only the Field report's projection (LOG-R78)", function()
		local saved = { global = { projections = { fieldReport = {} } } }
		local loaded = enterWorld((huntsCore(purchases(2), saved)))

		assert.are.same(BOTH, loaded.env.PagleDB.global.projections.wallet.projection)
	end)

	it(
		"gives 550 spent and both goods owned after the catch-up, a second U1 for a good changing nothing (SHOP-R11)",
		function()
			local loaded = enterWorld((huntsCore(purchases(2))))
			local Pagle = loaded.env.Pagle

			assert.are.same(BOTH, loaded.env.PagleDB.global.projections.wallet.projection)
			assert.are.same({ true, true }, { Pagle.IsOwned(VELVET), Pagle.IsOwned(SILK) })
		end
	)

	it(
		"shows 50 for 600 earned and 550 spent, then 0, held, when a Module's rebuild recounts it to 500, both goods"
			.. " still owned (SHOP-R12, SHOP-R91)",
		function()
			local loaded = huntsCore(purchases(2))
			local Pagle = loaded.env.Pagle
			local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local earned = 600
			local projection = ledger:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function()
					ledger:ReportCoinsEarned(earned) -- SHOP-R2: from every done
				end,
			})
			enterWorld(loaded)
			assert.are.same({ 50, false }, { Pagle.GetBalance().balance, Pagle.GetBalance().held })
			local fired = listen(loaded)

			earned = 500
			projection:Rebuild()

			assert.are.same({ "BalanceChanged 0 held" }, fired)
			assert.are.same({ true, true }, { Pagle.IsOwned(VELVET), Pagle.IsOwned(SILK) })
		end
	)

	it(
		"applies a purchase live: spent rises, BalanceChanged fires once, the good is owned (SHOP-R10, SHOP-R11)",
		function()
			local loaded = huntsCore(history(2), { global = { coins = { earned = { Ledger = 600 } } } })
			enterWorld(loaded)
			local Pagle = loaded.env.Pagle
			local fired = listen(loaded)

			loaded.ns.RecordPurchase(SILK, 400)

			assert.are.same({ "BalanceChanged 200" }, fired)
			assert.are.equal(400, loaded.env.PagleDB.global.projections.wallet.projection.spent)
			assert.is_true(Pagle.IsOwned(SILK))
			assert.are.equal(200, Pagle.GetBalance().balance) -- 600 earned − 400 spent
		end
	)

	it(
		"keeps IsOwned on the set saved before a rebuild, so an equipped bought look never falls back to its default"
			.. " (SHOP-R34, SHOP-R91)",
		function()
			local first = enterWorld(loadCore(purchases(600)), 4) -- chunked: the entries, then done, per projection
			assert.are.same(BOTH, first.env.PagleDB.global.projections.wallet.projection)
			local global = first.env.PagleDB.global
			global.projections.wallet.fingerprint = "an older release" -- DATA-R71: a new content fingerprint rebuilds
			local loaded = huntsCore(first.env.PagleLog, { global = global })
			local Pagle = loaded.env.Pagle
			loaded.client.fire("PLAYER_LOGIN")
			assert.is_true(Pagle.SetEquipped("hunts.cover", VELVET)) -- owned from the stored set before the rebuild
			local fired = listen(loaded)

			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
			local frames = 0
			while loaded.ns.walletProjection:IsUpdating() do
				assert.are.same(
					{ true, true, VELVET },
					{ Pagle.IsOwned(VELVET), Pagle.IsOwned(SILK), Pagle.GetEquipped("hunts.cover") }
				)
				loaded.client.runTimers()
				frames = frames + 1
			end

			assert.is_true(frames > 0) -- the rebuild ran across frames
			assert.are.same({}, fired, "neither the balance nor a look moved")
			assert.are.same(BOTH, loaded.env.PagleDB.global.projections.wallet.projection)
			assert.are.equal(Pagle.CONTENT_FINGERPRINT, loaded.env.PagleDB.global.projections.wallet.fingerprint)
		end
	)
end)
