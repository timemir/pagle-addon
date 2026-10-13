describe("ns.NewReportOnce", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("says to report the first failure of an owner and event, and none after it (CORE-R23)", function()
		local reports = ns.NewReportOnce()

		assert.is_true(reports:First("Ledger", "BAG_UPDATE"))
		assert.is_false(reports:First("Ledger", "BAG_UPDATE"))
		assert.is_false(reports:First("Ledger", "BAG_UPDATE"))
	end)

	it("counts each owner and event apart (CORE-R23)", function()
		local reports = ns.NewReportOnce()
		local ledger = {}

		assert.is_true(reports:First(ledger, "BAG_UPDATE"))
		assert.is_true(reports:First(ledger, "LOOT_OPENED"))
		assert.is_true(reports:First("Hunts", "BAG_UPDATE"))
		assert.is_true(reports:First({}, "BAG_UPDATE"))
	end)

	it("starts empty for each login, since it lives only in memory (CORE-R23)", function()
		ns.NewReportOnce():First("Ledger", "BAG_UPDATE")

		assert.is_true(ns.NewReportOnce():First("Ledger", "BAG_UPDATE"))
	end)
end)
