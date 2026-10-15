-- The Journal bindings' rules, names and tints (LED-R110, LED-R111, LED-R35, LED-R92, LED-R161) through
-- ns.LevelBindingEarned, ns.LevelBindingCrossed, ns.BindingName and ns.BindingLook, with no Core.

describe("the Journal bindings", function()
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

		it("is crossed when the peak level reaches a level binding's level, the moment to refresh (LED-R111)", function()
			assert.is_true(ns.LevelBindingCrossed(9, 10))
			assert.is_true(ns.LevelBindingCrossed(18, 31))
			assert.is_false(ns.LevelBindingCrossed(10, 19))
			assert.is_false(ns.LevelBindingCrossed(60, 60))
		end)
	end)

	describe("a binding's name", function()
		it("is its lore, or its good's ID while the lore has no text, empty included (LED-R110, LED-R161)", function()
			local birch = ns.BINDINGS[8]
			local key = "binding.birch.name"
			local lore = ns.L[key]
			assert.are.equal(lore, ns.BindingName(birch))

			ns.L[key] = ""
			local empty = ns.BindingName(birch)
			ns.L[key] = lore

			assert.are.equal("ledger.binding.birch", empty)
		end)
	end)

	describe("a binding's look", function()
		it("is Field Leather's for the default and for an ID that isn't a binding (LED-R110, LED-R112)", function()
			local field = ns.BindingLook("ledger.binding.field")

			assert.are.same(
				{ ns.JOURNAL_LOOK.leather, ns.JOURNAL_LOOK.gilt, ns.JOURNAL_LOOK.paper },
				{ field.leather, field.gilt, field.paper }
			)
			assert.are.same(field, ns.BindingLook("core.crest.plain"))
			assert.are.same(field, ns.BindingLook(nil))
		end)

		it("is the prototype swatch's leather and gilt (LED-R110, prototypes/curio-shop/ › Tidewater Blue)", function()
			local look = ns.BindingLook("ledger.binding.level20")

			assert.are.same({ 0x1f / 255, 0x3a / 255, 0x5a / 255 }, look.leather)
			assert.are.same({ 0xc9 / 255, 0xd6 / 255, 0xe0 / 255 }, look.gilt)
		end)

		it("puts dark ink on a light brass plate and the paper's tint on a dark one (LED-R110)", function()
			local field = ns.BindingLook("ledger.binding.field")
			local birch = ns.BindingLook("ledger.binding.birch") -- pale bark, dark gilt

			assert.are.same({ 0x2a / 255, 0x1a / 255, 0x04 / 255 }, field.plateText)
			assert.are.same(birch.paper, birch.plateText)
		end)
	end)
end)
