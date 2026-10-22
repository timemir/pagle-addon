-- The Ledger's earned bindings' rules and names (LED-R110, LED-R111, LED-R116, LED-R35, LED-R92, LED-R161) through
-- ns.LevelBindingEarned, ns.LevelBindingCrossed and ns.BindingName. Their looks are Core's
-- (spec/Pagle/logic/Bindings_spec.lua).

describe("the Ledger's earned bindings", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	-- An empty state but for its climb: `xp` XP at prestige rank `prestige`.
	---@param xp integer
	---@param prestige integer
	---@return LedgerState
	local function state(xp, prestige)
		return {
			casts = 0,
			catches = 0,
			xp = xp,
			prestige = prestige,
			fresh = 300,
			coins = 0,
			skill = {},
			milestones = {},
			species = {},
			items = {},
			uncharted = {},
			zones = {},
		}
	end

	describe("a level binding", function()
		it("is earned once the peak level reaches its level (LED-R111, LED-R35)", function()
			-- 12,600 XP is level 10, 12,599 level 9 (LED-R30).
			assert.is_false(ns.LevelBindingEarned(10, state(12599, 0), {}))
			assert.is_true(ns.LevelBindingEarned(10, state(12600, 0), {}))
			assert.is_false(ns.LevelBindingEarned(20, state(12600, 0), {}))
		end)

		it("stays earned after a Prestige: the peak level is 60 from rank 1 on (LED-R35, LED-R111)", function()
			assert.is_true(ns.LevelBindingEarned(60, state(0, 1), {}))
		end)

		it(
			"stays earned at the highest celebrated level of any climb when the state falls below it (LED-R92, LED-R111)",
			function()
				local celebrated = { levels = { [0] = 60, [1] = 12 } }

				assert.is_true(ns.LevelBindingEarned(60, state(0, 0), celebrated))
				assert.is_true(ns.LevelBindingEarned(30, nil, { levels = { [0] = 34 } }))
				assert.is_false(ns.LevelBindingEarned(10, nil, {}))
			end
		)

		it(
			"is crossed when the peak level reaches a level binding's level, the moment to refresh (LED-R111)",
			function()
				assert.is_true(ns.LevelBindingCrossed(9, 10))
				assert.is_true(ns.LevelBindingCrossed(18, 31))
				assert.is_false(ns.LevelBindingCrossed(10, 19))
				assert.is_false(ns.LevelBindingCrossed(60, 60))
			end
		)
	end)

	describe("a binding's name", function()
		it(
			"is its lore, or its good's ID while the lore has no text, empty included (LED-R110, LED-R160, LED-R161)",
			function()
				local monster = ns.BINDINGS[8]
				local key = "ledgergood.ledger.binding.monster.name"
				local lore = ns.L[key]
				assert.are.equal("Monster Hide", lore)
				assert.are.equal(lore, ns.BindingName(monster))

				ns.L[key] = ""
				local empty = ns.BindingName(monster)
				ns.L[key] = lore

				assert.are.equal("ledger.binding.monster", empty)
			end
		)
	end)
end)
