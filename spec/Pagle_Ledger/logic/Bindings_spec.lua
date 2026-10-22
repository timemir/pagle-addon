-- The Journal bindings' rules, names and looks (LED-R110, LED-R111, LED-R116, LED-R35, LED-R92, LED-R161) through
-- ns.LevelBindingEarned, ns.LevelBindingCrossed, ns.BindingName and ns.BindingLook, with no Core.

local OWN = "Interface\\AddOns\\Pagle_Ledger\\media\\journal\\"

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
				texture = "Interface\\AddOns\\Pagle\\media\\books\\Leather",
				tileW = 128,
				tileH = 128,
				gilt = { 0xe8 / 255, 0xc9 / 255, 0x6a / 255 },
				giltShadow = { 0, 0, 0, 0.95, 0, -1 },
				silver = false,
				paperTint = { 1, 1, 1 },
				swatchAtlas = "Bindings",
				swatch = "binding-field-leather",
			}, field)
			assert.are.same(field, ns.BindingLook("core.crest.plain"))
			assert.are.same(field, ns.BindingLook(nil))
		end)

		it(
			"presses a dark gilt's crumbs into a light material, a light edge under them, not the black shadow",
			function()
				local birch = ns.BindingLook("ledger.binding.birch")
				assert.are.same({ 1, 0.96, 0.86, 0.6, 0, -1 }, birch.giltShadow)
				assert.are.same({ 0, 0, 0, 0.95, 0, -1 }, ns.BindingLook("ledger.binding.field").giltShadow)
				-- every dark gilt, and only those, takes the pressed edge
				for _, binding in ipairs(ns.BINDINGS) do
					local look = ns.BindingLook(ns.BindingID(binding))
					local g = look.gilt
					local dark = 0.2126 * g[1] + 0.7152 * g[2] + 0.0722 * g[3] <= 0.45
					assert.are.equal(dark, look.giltShadow[1] == 1, binding.name)
				end
			end
		)

		it(
			"tints the grey leather a level binding's tint, the band toward it and the paper by a tenth (LED-R110)",
			function()
				local look = ns.BindingLook("ledger.binding.level20") -- Tidewater Blue, the kit's measured tint

				assert.are.same({ OWN .. "LeatherGrey", 128, 128 }, { look.texture, look.tileW, look.tileH })
				assert.are.same({ 0.188, 0.363, 0.563 }, look.tint)
				assert.are.same({ 0.188 / 0.563, 0.363 / 0.563, 1 }, look.band)
				assert.are.same({ 0.9 + 0.1 * 0.188 / 0.563, 0.9 + 0.1 * 0.363 / 0.563, 1 }, look.paperTint)
				assert.are.equal("binding-tidewater-blue", look.swatch)
			end
		)

		it(
			"turns the brass plate silver under a silver gilt, or where the expansion kit says (LED-R110, LED-R149)",
			function()
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
					chartlinen = false,
					sailcloth = false,
					oilskin = false,
					moss = false,
					driftwood = false, -- a gilt that reads silver, under the kit's brass plate
					eelskin = true, -- a gilt that doesn't, under its silver plate
					kodo = false,
					frosthide = true,
					netcork = false,
					copper = false,
					velvet = true,
					turtle = false,
					morocco = false,
					coral = false,
					pearl = true,
					legend = false,
					monster = false,
					abyssal = false,
					keeper = false,
					iridescent = true,
				}, silver)
			end
		)

		it("draws Birch Bark and Buckram in their own grain, its band toned, untinted (LED-R110)", function()
			local birch, buckram = ns.BindingLook("ledger.binding.birch"), ns.BindingLook("ledger.binding.buckram")

			assert.are.same({ OWN .. "Bark", 256, 256 }, { birch.texture, birch.tileW, birch.tileH })
			assert.are.same({ OWN .. "Cloth", 256, 256 }, { buckram.texture, buckram.tileW, buckram.tileH })
			assert.is_nil(birch.tint)
			assert.is_nil(buckram.tint)
			assert.are.same({ 0xb8 / 255, 0xa8 / 255, 0x88 / 255 }, birch.band)
			assert.are.same({ 0x6a / 255, 0x9a / 255, 0x8c / 255 }, buckram.band)
		end)

		it(
			"draws each of the expansion's in its own material at its own repeat, its band at 1.9 times its tone, its corners and its swatch in Bindings2 (LED-R110)",
			function()
				local driftwood = ns.BindingLook("ledger.binding.driftwood")

				assert.are.same({
					texture = OWN .. "bindings\\driftwood",
					tileW = 150,
					tileH = 196,
					band = { math.min(1, 0x5a / 255 * 1.9), math.min(1, 0x54 / 255 * 1.9), 0x48 / 255 * 1.9 },
					gilt = { 0xd8 / 255, 0xd0 / 255, 0xc0 / 255 },
					giltShadow = { 0, 0, 0, 0.95, 0, -1 },
					silver = false,
					corners = "iron",
					paperTint = { 1, 1, 1 },
					swatchAtlas = "Bindings2",
					swatch = "swatch-driftwood",
				}, driftwood)
				local keeper = ns.BindingLook("ledger.binding.keeper")
				assert.are.same({ OWN .. "bindings\\keeper", 28, 28, "gold" }, {
					keeper.texture,
					keeper.tileW,
					keeper.tileH,
					keeper.corners,
				})
			end
		)

		it("draws no corners where the board shows none (LED-R110)", function()
			local none = {}
			for _, binding in ipairs(ns.BINDINGS) do
				if not ns.BindingLook(ns.BindingID(binding)).corners then
					none[#none + 1] = binding.name
				end
			end

			assert.are.same({
				"field",
				"level10",
				"level20",
				"level30",
				"level40",
				"level50",
				"level60",
				"birch",
				"buckram",
				"sharkskin",
				"sailcloth",
				"oilskin",
				"netcork",
				"copper",
			}, none)
		end)

		it("draws Coral Inlay in the grey leather under its tint, its band its own tone (LED-R110)", function()
			local coral = ns.BindingLook("ledger.binding.coral")
			local tint = { 0x1e / 255, 0x5a / 255, 0x54 / 255 }

			assert.are.same({ OWN .. "LeatherGrey", 128, 128 }, { coral.texture, coral.tileW, coral.tileH })
			assert.are.same(tint, coral.tint)
			assert.are.same({ tint[1] * 1.9, tint[2] * 1.9, tint[3] * 1.9 }, coral.band)
			assert.are.equal("pearl", coral.corners)
			-- the paper takes a tenth of the tint's hue, as a level binding's
			local top = tint[2]
			assert.are.same({ 0.9 + 0.1 * tint[1] / top, 1, 0.9 + 0.1 * tint[3] / top }, coral.paperTint)
		end)
	end)
end)
