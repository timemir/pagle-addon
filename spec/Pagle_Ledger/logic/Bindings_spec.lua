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

			-- Core's own leather as it is, its band untoned, the kit's gilt, the paper untinted
			assert.are.same({
				texture = "leather",
				tile = 128,
				gilt = { 0xe8 / 255, 0xc9 / 255, 0x6a / 255 },
				silver = false,
				paperTint = { 1, 1, 1 },
				swatch = "binding-field-leather",
			}, field)
			assert.are.same(field, ns.BindingLook("core.crest.plain"))
			assert.are.same(field, ns.BindingLook(nil))
		end)

		it(
			"tints the grey leather a level binding's tint, the band toward it and the paper by a tenth (LED-R110)",
			function()
				local look = ns.BindingLook("ledger.binding.level20") -- Tidewater Blue, the kit's measured tint

				assert.are.same({ "leatherGrey", 128 }, { look.texture, look.tile })
				assert.are.same({ 0.188, 0.363, 0.563 }, look.tint)
				assert.are.same({ 0.188 / 0.563, 0.363 / 0.563, 1 }, look.band)
				assert.are.same({ 0.9 + 0.1 * 0.188 / 0.563, 0.9 + 0.1 * 0.363 / 0.563, 1 }, look.paperTint)
				assert.are.equal("binding-tidewater-blue", look.swatch)
			end
		)

		it("turns the brass plate silver under a silver gilt only (LED-R110, LED-R149)", function()
			local silver = {}
			for _, binding in ipairs(ns.BINDINGS) do
				silver[binding.name] = ns.BindingLook(ns.BindingID(binding)).silver
			end

			assert.are.same({
				field = false,
				level10 = false,
				level20 = true,
				level30 = false,
				level40 = false,
				level50 = true,
				level60 = false,
				birch = false,
				buckram = false,
				sharkskin = true,
			}, silver)
		end)

		it("draws Birch Bark and Buckram in their own grain, its band toned, untinted (LED-R110)", function()
			local birch, buckram = ns.BindingLook("ledger.binding.birch"), ns.BindingLook("ledger.binding.buckram")

			assert.are.same({ "bark", 256, nil }, { birch.texture, birch.tile, birch.tint })
			assert.are.same({ "cloth", 256, nil }, { buckram.texture, buckram.tile, buckram.tint })
			assert.are.same({ 0xb8 / 255, 0xa8 / 255, 0x88 / 255 }, birch.band)
			assert.are.same({ 0x6a / 255, 0x9a / 255, 0x8c / 255 }, buckram.band)
		end)
	end)
end)
