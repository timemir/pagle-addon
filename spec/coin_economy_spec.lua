-- The coin economy's pacing (#412, decided in #393, #397, #399, #402 and #403). The constants below are the ones the
-- calibration model tuned to the pacing table in docs/spec/core/wallet-and-shop.md › Tunables: a casual angler
-- (1.5 h a day, 180 catches an hour, about 170 Coins per fishing hour) reaches the first purchase in under an hour,
-- 25% of the items in about 40 h, 50% in about 100 h, 75% in about 200 h, tiers 1-4 in about 430 h, tiers 1-5 in
-- about 720 h and the first tier-6 good in about 870 h. A price is that casual's Coins per hour times the tier's target
-- hours per item.
--
-- This spec fails when one of them moves. If a content or price change is meant, re-run the calibration
-- (docs/research/coin-calibration on the research/coin-calibration branch), update the pacing table and the
-- payout tables in the specs, and change the numbers here with them; do not edit them to make a failure go away.

local PACING = "the coin economy no longer matches the pacing table (docs/spec/core/wallet-and-shop.md, Tunables; #412)"

describe("the coin economy", function()
	local core, ledger, hunts

	setup(function()
		local loadedLedger = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		core, ledger = loadedLedger.namespaces.Pagle, loadedLedger.ns
		hunts = loadAddon("Pagle_Hunts", FOREVER_GLOBALS).ns
	end)

	it("prices six tiers of goods (SHOP-R22)", function()
		assert.are.same({ 250, 400, 900, 3000, 10000, 25000 }, core.TIER_PRICES, PACING)
	end)

	it("pays 40 Coins for a level-up and 1,500 for a Prestige (LED-R88)", function()
		assert.are.equal(40, ledger.LEVEL_UP_COINS, PACING)
		assert.are.equal(1500, ledger.PRESTIGE_COINS, PACING)
	end)

	it("pays 8 / 5 Coins for an event Hunt's tiers and 25 for a completed run (HNT-R110)", function()
		assert.are.same({ 8, 5 }, hunts.COINS_EVENT, PACING)
		assert.are.equal(25, hunts.COINS_RUN, PACING)
	end)

	it("sells the late rounds' earned goods at tier 4 once their fallback opens (SHOP-R28)", function()
		ledger.ROUND_TWO_RELEASE = 1000
		local tier, from = ledger.RoundTwoFallback()
		ledger.ROUND_TWO_RELEASE = nil

		assert.are.same({ 4, 1000 + 90 * 86400 }, { tier, from }, PACING)
	end)

	it("prices the Curio crate at 1,500 Coins, a price of its own (SHOP-R50)", function()
		assert.are.equal(1500, core.CRATE_PRICE, PACING)
	end)
end)
