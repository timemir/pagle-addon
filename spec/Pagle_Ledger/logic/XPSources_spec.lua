-- "Where your XP came from" (LED-R150, LED-R37, AXP-R6, AXP-R90) through ns.XPSourceLines and ns.PrestigeSources,
-- with no Core: the Ledger's own XP and each source's Activity XP, this climb and all told, for a state, Core's
-- Pagle.GetActivityXP() and the totals saved at the latest Prestige.

describe("where your XP came from", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	-- A state whose own XP is `xp` this climb and `lifetime` all told, at prestige rank `rank` with Core's Activity XP
	-- total `snapshot` at that Prestige.
	---@param xp integer
	---@param lifetime integer
	---@param rank integer?
	---@param snapshot integer?
	---@return LedgerState
	local function stateAt(xp, lifetime, rank, snapshot)
		return { xp = xp, lifetimeXP = lifetime, prestige = rank or 0, prestigeActivityXP = snapshot or 0 }
	end

	-- Pagle.GetActivityXP()'s shape (AXP-R6) for `totals`, `{ [def.name] = total }`, every source On but those in `off`.
	---@param totals table<string, integer>
	---@param off table<string, true>?
	---@return ActivityXP
	local function activityXP(totals, off)
		local bySource, sum = {}, 0
		for name, total in pairs(totals) do
			bySource[name] = { total = total, enabled = not (off and off[name]) }
			sum = sum + total
		end
		return { total = sum, bySource = bySource }
	end

	-- Each line as { name, this climb, all told, struck through }.
	local function rows(lines)
		local list = {}
		for i, line in ipairs(lines) do
			list[i] = { line.name, line.climb, line.total, line.off }
		end
		return list
	end

	it("lists the Ledger's own XP first, then each source in Core's Module order, all told (LED-R150)", function()
		local lines = ns.XPSourceLines(stateAt(40000, 40000), activityXP({ TackleBoard = 900, Hunts = 1500 }), nil)

		assert.are.same({
			{ "Catches and discoveries", 40000, 40000, false },
			{ "Hunts", 1500, 1500, false },
			{ "Tackle Board", 900, 900, false },
		}, rows(lines))
		assert.are.same({ "ledger", "Hunts", "TackleBoard" }, { lines[1].source, lines[2].source, lines[3].source })
	end)

	it(
		"splits the climb's Activity XP by each source's rise since the totals saved at the Prestige (LED-R150)",
		function()
			-- Prestige at Hunts 1,500 and the Tackle Board 900 (snapshot 2,400); since then Hunts 2,100 and the Tackle
			-- Board 1,100: the climb's 800 is Hunts' 600 and the Tackle Board's 200 (LED-R37).
			local saved = ns.PrestigeSources(activityXP({ Hunts = 1500, TackleBoard = 900 }).bySource, {
				rank = 1,
				activityXP = 2400,
			})
			local state = stateAt(3000, 45000, 1, 2400)

			local lines = ns.XPSourceLines(state, activityXP({ Hunts = 2100, TackleBoard = 1100 }), saved)

			assert.are.same({
				{ "Catches and discoveries", 3000, 45000, false },
				{ "Hunts", 600, 2100, false },
				{ "Tackle Board", 200, 1100, false },
			}, rows(lines))
		end
	)

	it("with no totals saved, splits the climb's Activity XP by each source's total now (LED-R150)", function()
		-- A Prestige before #295, or a lost PagleLedgerDB: 800 split 2,100 : 1,100.
		local state = stateAt(3000, 45000, 1, 2400)

		local lines = ns.XPSourceLines(state, activityXP({ Hunts = 2100, TackleBoard = 1100 }), nil)

		assert.are.same({ 525, 275 }, { lines[2].climb, lines[3].climb })
	end)

	it("ignores totals saved at another Prestige than the latest (LED-R150)", function()
		-- Saved at rank 1; the state is at rank 2, its snapshot 3,200: the climb's 400 is split by the totals now.
		local saved = ns.PrestigeSources(activityXP({ Hunts = 1500, TackleBoard = 900 }).bySource, {
			rank = 1,
			activityXP = 2400,
		})
		local state = stateAt(0, 45000, 2, 3200)

		local lines = ns.XPSourceLines(state, activityXP({ Hunts = 2400, TackleBoard = 1200 }), saved)

		assert.are.same({ 267, 133 }, { lines[2].climb, lines[3].climb })
	end)

	it("rounds the split so the parts sum to the climb's Activity XP (LED-R150)", function()
		local lines = ns.XPSourceLines(stateAt(0, 0), activityXP({ Hunts = 1, TackleBoard = 1, Zeta = 1 }), nil)
		-- 1 Activity XP each: 3 in all, nothing to round; a climb of 100 over equal rises is 34, 33, 33.
		assert.are.same({ 1, 1, 1 }, { lines[2].climb, lines[3].climb, lines[4].climb })

		local state = stateAt(0, 0, 1, 2)
		local split = ns.XPSourceLines(state, activityXP({ Hunts = 34, TackleBoard = 34, Zeta = 34 }), nil)
		assert.are.same({ 34, 33, 33 }, { split[2].climb, split[3].climb, split[4].climb })
	end)

	it("never counts a source's rise below 0 (LED-R150, AXP-R4)", function()
		-- The Tackle Board recounted lower since the Prestige: its rise is 0, so Hunts has the climb's 100.
		local saved = { rank = 1, activityXP = 2400, totals = { Hunts = 1500, TackleBoard = 900 } }
		local state = stateAt(0, 0, 1, 2400)

		local lines = ns.XPSourceLines(state, activityXP({ Hunts = 1700, TackleBoard = 800 }), saved)

		assert.are.same({ 100, 0 }, { lines[2].climb, lines[3].climb })
	end)

	it("strikes a disabled source through, and still counts it in the climb (LED-R150, AXP-R90)", function()
		local lines = ns.XPSourceLines(
			stateAt(40000, 40000),
			activityXP({ Hunts = 1500, TackleBoard = 900 }, { TackleBoard = true }),
			nil
		)

		assert.are.same({ "Tackle Board", 900, 900, true }, rows(lines)[3])
		assert.is_false(lines[2].off)
	end)

	it("shows only the Ledger's own line with no source reported yet (LED-R150)", function()
		local lines = ns.XPSourceLines(stateAt(1200, 5000, 1, 0), { total = 0, bySource = {} }, nil)

		assert.are.same({ { "Catches and discoveries", 1200, 5000, false } }, rows(lines))
	end)

	it("puts a source the Ledger doesn't know after the others, by its name (LED-R150)", function()
		local lines = ns.XPSourceLines(stateAt(0, 0), activityXP({ Zeta = 5, Alpha = 7, TackleBoard = 1 }), nil)

		assert.are.same({ "Catches and discoveries", "Tackle Board", "Alpha", "Zeta" }, {
			lines[1].name,
			lines[2].name,
			lines[3].name,
			lines[4].name,
		})
	end)

	it("saves each source's total with the Prestige's rank and snapshot (LED-R150)", function()
		local saved = ns.PrestigeSources(activityXP({ Hunts = 1500, TackleBoard = 900 }).bySource, {
			kind = "prestige",
			rank = 3,
			activityXP = 2400,
		})

		assert.are.same({ rank = 3, activityXP = 2400, totals = { Hunts = 1500, TackleBoard = 900 } }, saved)
	end)

	it("gives the ink XP bar's tooltip this climb's lines, by source, roughly (LED-R145, LED-R150)", function()
		local lines = ns.XPSourceLines(
			stateAt(3000, 45000, 1, 2400),
			activityXP({ Hunts = 2100, TackleBoard = 1100 }, { TackleBoard = true }),
			{ rank = 1, activityXP = 2400, totals = { Hunts = 1500, TackleBoard = 900 } }
		)

		assert.are.same({
			title = "Where this climb's XP came from",
			lines = {
				{ text = "Catches and discoveries", value = "3,000", off = false },
				{ text = "Hunts", value = "600", off = false },
				{ text = "Tackle Board", value = "200", off = true },
			},
			note = "by source, roughly",
		}, ns.XPBarTip(lines, breakUpLargeNumbers))
	end)
end)
