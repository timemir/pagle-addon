-- The Fish Journal's ink XP bar (LED-R145, LED-R23's bar, LED-R36) through ns.InkXpBar, with no Core: what the bar
-- shows for a state, the celebrated set and the time now.

describe("the ink XP bar", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns
	local NOW = SERVER_TIME

	-- A state at `xp` with Fresh Water `fresh` as of now (no refill), at prestige rank 0.
	---@param xp integer
	---@param fresh number
	---@return LedgerState
	local function stateAt(xp, fresh)
		return {
			casts = 1,
			catches = 1,
			xp = xp,
			prestige = 0,
			fresh = fresh,
			lastCatch = NOW,
			coins = 0,
			skill = {},
			species = {},
			zones = {},
		}
	end

	-- A celebrated set whose highest level celebrated at rank 0 is `level`.
	---@param level integer?
	---@return LedgerCelebrated
	local function celebratedAt(level)
		return { levels = { [0] = level }, species = {}, speciesZones = {}, zones = {}, skill = {}, coins = 0 }
	end

	it(
		"fills to the XP into the level, with Fresh Water as a shaded stretch of F × 10 XP (LED-R145, LED-R23)",
		function()
			-- Level 1 costs 1,080 and level 2 costs 1,160 (LED-R30): 1,580 XP is 500 into level 2.
			local bar = ns.InkXpBar(stateAt(1580, 12), celebratedAt(2), NOW, breakUpLargeNumbers)

			assert.are.near(500 / 1160, bar.fill, 1e-9)
			assert.are.near(500 / 1160, bar.fresh.from, 1e-9)
			assert.are.near(620 / 1160, bar.fresh.to, 1e-9)
			assert.are.equal("500 of 1,160.", bar.text)
			assert.are.equal(" Fresh Water for 12 more Catches.", bar.freshText)
		end
	)

	it("reads the climb's full-cost steps after a Prestige (LED-R145, LED-R30)", function()
		-- At rank 1, as at rank 0, level 1 costs 1,080. A shown level above it reads 0 of that level's step (LED-R36).
		local state = stateAt(600, 0)
		state.prestige = 1
		local celebrated = celebratedAt(nil)
		assert.are.equal("600 of 1,080.", ns.InkXpBar(state, celebrated, NOW, breakUpLargeNumbers).text)

		celebrated.levels[1] = 4
		assert.are.equal("0 of 1,320.", ns.InkXpBar(state, celebrated, NOW, breakUpLargeNumbers).text)
	end)

	it(
		"counts the climb's Activity XP, and waits at 0 of the shown level's step after a lower recount (LED-R38)",
		function()
			local total = 2000
			ns.SetActivityXPSource(function()
				return total
			end)
			-- 500 own XP and 2,000 Activity XP: 1,420 into level 2's 1,160 step is level 3, 260 into 1,240 (LED-R30).
			local state, celebrated = stateAt(500, 0), celebratedAt(3)
			local before = ns.InkXpBar(state, celebrated, NOW, breakUpLargeNumbers).text
			total = 0
			local after = ns.InkXpBar(state, celebrated, NOW, breakUpLargeNumbers).text
			ns.SetActivityXPSource(nil)

			assert.are.same({ "260 of 1,240.", "0 of 1,240." }, { before, after })
		end
	)

	it("clips Fresh Water at the bar's end (LED-R23)", function()
		local bar = ns.InkXpBar(stateAt(1580, 300), celebratedAt(2), NOW, breakUpLargeNumbers)

		assert.are.equal(1, bar.fresh.to)
		assert.are.equal(" Fresh Water for 300 more Catches.", bar.freshText)
	end)

	it("shows Fresh Water refilled up to now, rounded down, and one Catch's in the singular (LED-R23)", function()
		local state = stateAt(1580, 0.5)
		state.lastCatch = NOW - 360 -- 0.5 + 10 × 360 / 3,600 = 1.5

		local bar = ns.InkXpBar(state, celebratedAt(2), NOW, breakUpLargeNumbers)

		assert.are.near(510 / 1160, bar.fresh.to, 1e-9)
		assert.are.equal(" Fresh Water for 1 more Catch.", bar.freshText)
	end)

	it("has no Fresh Water stretch or words while F is 0 (LED-R145)", function()
		local bar = ns.InkXpBar(stateAt(1580, 0.9), celebratedAt(2), NOW, breakUpLargeNumbers)

		assert.is_nil(bar.fresh)
		assert.is_nil(bar.freshText)
		assert.are.equal("500 of 1,160.", bar.text)
	end)

	it("reads 0 of the shown level's step while the shown level is above the computed one (LED-R36)", function()
		-- Computed level 2 (1,580 XP), but level 4 was celebrated: level 4's step costs 1,320.
		local bar = ns.InkXpBar(stateAt(1580, 12), celebratedAt(4), NOW, breakUpLargeNumbers)

		assert.are.equal(0, bar.fill)
		assert.are.equal("0 of 1,320.", bar.text)
		assert.are.near(0, bar.fresh.from, 1e-9)
		assert.are.near(120 / 1320, bar.fresh.to, 1e-9)
		assert.are.equal(" Fresh Water for 12 more Catches.", bar.freshText)
	end)

	it("at a computed level of 60, is full with no Fresh Water and the carried XP set aside (LED-R145)", function()
		-- Reaching 60 costs the sum of 1,000 + 80 × L for L = 1 … 59: 59,000 + 80 × 1,770 = 200,600.
		local bar = ns.InkXpBar(stateAt(200600 + 4321, 50), celebratedAt(60), NOW, breakUpLargeNumbers)

		assert.are.equal(1, bar.fill)
		assert.is_nil(bar.fresh)
		assert.is_nil(bar.freshText)
		assert.are.equal("4,321 XP set aside for the next Prestige", bar.text)
	end)

	it("at a shown level of 60 above the computed one, sets aside 0 XP (LED-R145, LED-R36)", function()
		local bar = ns.InkXpBar(stateAt(200599, 50), celebratedAt(60), NOW, breakUpLargeNumbers)

		assert.are.equal(1, bar.fill)
		assert.is_nil(bar.fresh)
		assert.are.equal("0 XP set aside for the next Prestige", bar.text)
	end)
end)
