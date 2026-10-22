-- The bindings as data (ADR 0015; wallet-and-shop.md SHOP-R25; ledger.md LED-R110; hunts.md HNT-R121–R123): every
-- binding's good ID and kind, the order Core registers its own in, and the one look each wears on every book, the
-- Ledger's and Hunts' earned ones included, through ns.CoreBindings and ns.BindingLook.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local BOOKS = "Interface\\AddOns\\Pagle\\media\\books\\"
local FIELD_GILT = { 0xe8 / 255, 0xc9 / 255, 0x6a / 255 }

-- An { r, g, b } from "RRGGBB".
---@param hex string
---@return number[]
local function rgb(hex)
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- A band tone at the shop expansion kit's 1.9 gain, each channel stopping at 1.
---@param hex string
---@return number[]
local function gained(hex)
	local tone = rgb(hex)
	return { math.min(1, tone[1] * 1.9), math.min(1, tone[2] * 1.9), math.min(1, tone[3] * 1.9) }
end

describe("the bindings", function()
	it("are Core's slot core.binding, with Field Leather its default (SHOP-R25, ADR 0015)", function()
		assert.are.same({ "core.binding", "core.binding.field" }, { ns.BINDING_SLOT, ns.DEFAULT_BINDING })
	end)

	it(
		"list Field Leather, then every binding for sale by tier, each tier's Ledger kit's before Hunts' kit's (SHOP-R25)",
		function()
			local order = {}
			for i, binding in ipairs(ns.CoreBindings()) do
				order[i] = { binding.id, binding.default and "default" or binding.tier }
			end

			assert.are.same({
				{ "core.binding.field", "default" },
				{ "core.binding.birch", 1 },
				{ "core.binding.chartlinen", 1 },
				{ "core.binding.sailcloth", 1 },
				{ "core.binding.oilskin", 1 },
				{ "core.binding.canvas", 1 },
				{ "core.binding.kraft", 1 },
				{ "core.binding.tartan", 1 },
				{ "core.binding.buckram", 2 },
				{ "core.binding.moss", 2 },
				{ "core.binding.driftwood", 2 },
				{ "core.binding.eelskin", 2 },
				{ "core.binding.kodo", 2 },
				{ "core.binding.frosthide", 2 },
				{ "core.binding.netcork", 2 },
				{ "core.binding.tooled", 2 },
				{ "core.binding.maplinen", 2 },
				{ "core.binding.planks", 2 },
				{ "core.binding.sharkskin", 3 },
				{ "core.binding.copper", 3 },
				{ "core.binding.velvet", 3 },
				{ "core.binding.turtle", 3 },
				{ "core.binding.morocco", 3 },
				{ "core.binding.verdigris", 3 },
				{ "core.binding.snakeskin", 3 },
				{ "core.binding.shagreen", 3 },
				{ "core.binding.lacquer", 3 },
				{ "core.binding.bone", 3 },
				{ "core.binding.brasscase", 3 },
				{ "core.binding.coral", 4 },
				{ "core.binding.scrimshaw", 4 },
				{ "core.binding.pearl", 5 },
				{ "core.binding.trophycase", 5 },
			}, order)
		end
	)

	it(
		"hold the Ledger's eleven earned bindings and Hunts' three, theirs to register, with Core's looks (LED-R110, HNT-R122, SHOP-R23)",
		function()
			local earned = {}
			for _, binding in ipairs(ns.BINDINGS) do
				if binding.earned then
					earned[#earned + 1] = binding.id
				end
				assert.are.equal(
					1,
					(binding.default and 1 or 0) + (binding.tier and 1 or 0) + (binding.earned and 1 or 0)
				)
			end

			assert.are.same({
				"ledger.binding.level10",
				"ledger.binding.level20",
				"ledger.binding.level30",
				"ledger.binding.level40",
				"ledger.binding.level50",
				"ledger.binding.level60",
				"ledger.binding.legend",
				"ledger.binding.monster",
				"ledger.binding.abyssal",
				"ledger.binding.keeper",
				"ledger.binding.iridescent",
				"hunts.binding.pathfinder",
				"hunts.binding.fiveseal",
				"hunts.binding.wagersilk",
			}, earned)
			assert.are.equal(47, #ns.BINDINGS)
		end
	)

	describe("a binding's look", function()
		it("is Field Leather's for the default and for an ID that isn't a binding (ADR 0015, LED-R110)", function()
			local field = ns.BindingLook("core.binding.field")

			-- Core's own leather as it is, darker toward its foot, its band untoned, the kit's gilt over a black
			-- shadow, a brass plate, the paper untinted
			assert.are.same({
				texture = BOOKS .. "Leather",
				tileW = 128,
				tileH = 128,
				foot = 0.8,
				gilt = FIELD_GILT,
				giltShadow = { 0, 0, 0, 0.95, 0, -1 },
				silver = false,
				paperTint = { 1, 1, 1 },
				swatchAtlas = "Bindings",
				swatch = "binding-field-leather",
			}, field)
			assert.are.same(field, ns.BindingLook("ledger.binding.unknown"))
			assert.are.same(field, ns.BindingLook("hunts.binding.unknown"))
			assert.are.same(field, ns.BindingLook("core.crest.plain"))
			assert.are.same(field, ns.BindingLook(nil))
		end)

		it("is a fresh table each time (ADR 0015)", function()
			local look = ns.BindingLook("core.binding.field")
			look.gilt[1], look.giltShadow[1] = 0, 1

			assert.are.same(FIELD_GILT, ns.BindingLook("core.binding.field").gilt)
			assert.are.same({ 0, 0, 0, 0.95, 0, -1 }, ns.BindingLook("core.binding.field").giltShadow)
		end)

		it(
			"tints the grey leather a level binding's tint, the band toward it and the paper by a tenth (LED-R110)",
			function()
				local look = ns.BindingLook("ledger.binding.level20") -- Tidewater Blue, the kit's measured tint

				assert.are.same(
					{ BOOKS .. "LeatherGrey", 128, 128, 0.8 },
					{ look.texture, look.tileW, look.tileH, look.foot }
				)
				assert.are.same({ 0.188, 0.363, 0.563 }, look.tint)
				assert.are.same({ 0.188 / 0.563, 0.363 / 0.563, 1 }, look.band)
				assert.are.same({ 0.9 + 0.1 * 0.188 / 0.563, 0.9 + 0.1 * 0.363 / 0.563, 1 }, look.paperTint)
				assert.are.same({ "Bindings", "binding-tidewater-blue" }, { look.swatchAtlas, look.swatch })
			end
		)

		it(
			"turns the brass plate silver under a silver gilt, or where a kit says, and keeps it brass on every cover (LED-R110, LED-R149)",
			function()
				local silver = {}
				for _, binding in ipairs(ns.BINDINGS) do
					if ns.BindingLook(binding.id).silver then
						silver[#silver + 1] = binding.key
					end
				end

				-- driftwood's gilt reads silver under the kit's brass plate; eelskin's doesn't, under its silver one
				assert.are.same({
					"level20",
					"level50",
					"sharkskin",
					"eelskin",
					"frosthide",
					"velvet",
					"pearl",
					"iridescent",
				}, silver)
			end
		)

		it("presses a dark gilt's words with a light edge, a light gilt's with a black shadow (LED-R125)", function()
			-- Birch Bark's 6a4a20 and Keeper's Gold's 7a5410 are dark ink on a light material.
			assert.are.same({ 1, 0.96, 0.86, 0.6, 0, -1 }, ns.BindingLook("core.binding.birch").giltShadow)
			assert.are.same({ 1, 0.96, 0.86, 0.6, 0, -1 }, ns.BindingLook("ledger.binding.keeper").giltShadow)
			assert.are.same({ 0, 0, 0, 0.95, 0, -1 }, ns.BindingLook("ledger.binding.level60").giltShadow)
			assert.are.same({ 0, 0, 0, 0.95, 0, -1 }, ns.BindingLook("core.binding.canvas").giltShadow)
		end)

		it("draws Birch Bark and Buckram in their own grain, its band toned, untinted (LED-R110)", function()
			local birch, buckram = ns.BindingLook("core.binding.birch"), ns.BindingLook("core.binding.buckram")

			assert.are.same({ BOOKS .. "Bark", 256, 256 }, { birch.texture, birch.tileW, birch.tileH })
			assert.are.same({ BOOKS .. "Cloth", 256, 256 }, { buckram.texture, buckram.tileW, buckram.tileH })
			assert.is_nil(birch.tint)
			assert.is_nil(buckram.tint)
			assert.are.same(rgb("b8a888"), birch.band)
			assert.are.same(rgb("6a9a8c"), buckram.band)
		end)

		it(
			"draws each of the shop expansion's bindings in its own material at its own repeat, its band at 1.9 times its tone, its corners and its swatch in Bindings2 (LED-R110)",
			function()
				assert.are.same({
					texture = BOOKS .. "bindings\\driftwood",
					tileW = 150,
					tileH = 196,
					foot = 0.8,
					band = gained("5a5448"),
					gilt = rgb("d8d0c0"),
					giltShadow = { 0, 0, 0, 0.95, 0, -1 },
					silver = false,
					corners = "iron",
					paperTint = { 1, 1, 1 },
					swatchAtlas = "Bindings2",
					swatch = "swatch-driftwood",
				}, ns.BindingLook("core.binding.driftwood"))
				local keeper = ns.BindingLook("ledger.binding.keeper")
				assert.are.same(
					{ BOOKS .. "bindings\\keeper", 28, 28, "gold", "Bindings2", "swatch-keeper" },
					{ keeper.texture, keeper.tileW, keeper.tileH, keeper.corners, keeper.swatchAtlas, keeper.swatch }
				)
			end
		)

		it("draws Coral Inlay in the grey leather under its tint, its band its own tone (LED-R110)", function()
			local coral = ns.BindingLook("core.binding.coral")
			local tint = { 0x1e / 255, 0x5a / 255, 0x54 / 255 }

			assert.are.same({ BOOKS .. "LeatherGrey", 128, 128 }, { coral.texture, coral.tileW, coral.tileH })
			assert.are.same(tint, coral.tint)
			assert.are.same({ tint[1] * 1.9, tint[2] * 1.9, tint[3] * 1.9 }, coral.band)
			assert.are.equal("pearl", coral.corners)
			-- the paper takes a tenth of the tint's hue, as a level binding's
			local top = tint[2]
			assert.are.same({ 0.9 + 0.1 * tint[1] / top, 1, 0.9 + 0.1 * tint[3] / top }, coral.paperTint)
		end)

		it(
			"draws each ex-cover in its kit's material, band and corners, darker toward its foot, in Field Leather's gilt over a brass plate, with its swatch in Covers2 (HNT-R123, ADR 0015)",
			function()
				assert.are.same({
					texture = BOOKS .. "bindings\\lacquer",
					tileW = 150,
					tileH = 196,
					foot = 0.82,
					band = gained("8a1410"),
					gilt = FIELD_GILT,
					giltShadow = { 0, 0, 0, 0.95, 0, -1 },
					silver = false,
					corners = "gold",
					paperTint = { 1, 1, 1 },
					swatchAtlas = "Covers2",
					swatch = "swatch-lacquer",
				}, ns.BindingLook("core.binding.lacquer"))
				local wagersilk = ns.BindingLook("hunts.binding.wagersilk")
				assert.are.same({ BOOKS .. "bindings\\wagersilk", 56, 56, "gold", "Covers2", "swatch-wagersilk" }, {
					wagersilk.texture,
					wagersilk.tileW,
					wagersilk.tileH,
					wagersilk.corners,
					wagersilk.swatchAtlas,
					wagersilk.swatch,
				})
			end
		)

		it(
			"draws Verdigris as a fill at the book's size, Tooled Leather as Field Leather's with its double rule, neither with a swatch (HNT-R121, ADR 0015)",
			function()
				local tooled = ns.BindingLook("core.binding.tooled")
				local verdigris = ns.BindingLook("core.binding.verdigris")

				assert.are.same({ BOOKS .. "fills\\verdigris", 1, true }, {
					verdigris.fill,
					verdigris.foot,
					verdigris.giltCorner,
				})
				assert.is_nil(verdigris.texture)
				assert.are.same({ BOOKS .. "Leather", 0.75, true }, { tooled.texture, tooled.foot, tooled.tooled })
				for _, look in ipairs({ tooled, verdigris }) do
					assert.are.same({ FIELD_GILT, false }, { look.gilt, look.silver })
					assert.is_nil(look.swatch)
					assert.is_nil(look.swatchAtlas)
				end
			end
		)

		it("sets exactly one of a texture and a fill, and every swatch is in its atlas (ADR 0015)", function()
			local fills = 0
			for _, binding in ipairs(ns.BINDINGS) do
				local look = ns.BindingLook(binding.id)
				assert.are_not.equal(look.texture == nil, look.fill == nil, binding.id)
				fills = fills + (look.fill and 1 or 0)
				if look.swatch then
					assert(ns.ATLASES[look.swatchAtlas].sprites[look.swatch], binding.id)
				end
			end
			assert.are.equal(1, fills)
		end)

		it("ships every material, fill and swatch atlas in Core's media (ADR 0015)", function()
			local files = {}
			for _, binding in ipairs(ns.BINDINGS) do
				local look = ns.BindingLook(binding.id)
				files[look.texture or look.fill] = true
			end
			for _, name in ipairs({ "Bindings", "Bindings2", "Covers2" }) do
				files[ns.ATLASES[name].file] = true
			end
			for file in pairs(files) do
				assert.are.equal("Interface\\AddOns\\Pagle\\", file:sub(1, 23))
				local path = file:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/") .. ".blp"
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local handle = io.open(path, "rb")
				assert(handle, path)
				handle:close()
			end
		end)
	end)
end)
