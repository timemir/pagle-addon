-- The goods registry as Core runs it, through the real TOC (wallet-and-shop.md › Goods, Owning and equipping,
-- SHOP-R20–R26, SHOP-R30–R33, SHOP-R90): M:RegisterSlot, M:RegisterGood, M:RefreshGoods, Pagle.IsOwned,
-- Pagle.GetEquipped, Pagle.SetEquipped, Pagle.GetGood, AppearanceChanged, PagleDB.global.goods and
-- PagleDB.profile.appearance.

-- Hunts' notebook cover slot on its handle: a default, a tier-2 good and an earned good whose isEarned() returns
-- `earned.value`.
---@param hunts table the Hunts handle
---@param earned { value: boolean }
local function registerCovers(hunts, earned)
	hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Hunts" })
	hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
	hunts:RegisterGood({ id = "hunts.cover.velvet", slot = "hunts.cover", name = "Velvet", tier = 2, icon = 134939 })
	hunts:RegisterGood({
		id = "hunts.cover.gold",
		slot = "hunts.cover",
		name = "Gold",
		earnedText = "Every Hunt done",
		isEarned = function()
			return earned.value
		end,
	})
end

-- Core over `saved` PagleDB with Hunts registered, its covers in (unless `noCovers`), before PLAYER_LOGIN.
---@param saved table?
---@param earned { value: boolean }?
---@param noCovers boolean?
---@return LoadedAddon loaded
---@return table hunts
local function huntsSession(saved, earned, noCovers)
	local loaded = loadCore(nil, saved)
	local hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
	if not noCovers then
		registerCovers(hunts, earned or { value = false })
	end
	return loaded, hunts
end

-- Each AppearanceChanged Core fires from now on, as { slot, goodID }.
---@param loaded LoadedAddon
---@return string[][]
local function listen(loaded)
	local fired = {}
	loaded.env.Pagle.RegisterCallback("spec", "AppearanceChanged", function(_, slot, goodID)
		fired[#fired + 1] = { slot, goodID }
	end)
	return fired
end

describe("M:RegisterSlot and M:RegisterGood", function()
	it("register a Module's slot and goods, cached in PagleDB.global.goods (SHOP-R21, SHOP-R22, SHOP-R26)", function()
		local loaded = huntsSession(nil, { value = true })
		loaded.client.fire("PLAYER_LOGIN")

		local Pagle = loaded.env.Pagle
		assert.are.same({ true, false, true }, {
			Pagle.IsOwned("hunts.cover.plain"),
			Pagle.IsOwned("hunts.cover.velvet"),
			Pagle.IsOwned("hunts.cover.gold"),
		})
		assert.are.same({
			name = "Velvet",
			slot = "hunts.cover",
			slotLabel = "Notebook cover",
			category = "Hunts",
			module = "Hunts",
			icon = 134939,
			tier = 2,
		}, loaded.env.PagleDB.global.goods["hunts.cover.velvet"])
		assert.is_true(loaded.env.PagleDB.global.goods["hunts.cover.gold"].earned)
	end)

	for _, case in ipairs({
		{ "a duplicate slot", "RegisterSlot", { id = "hunts.cover", label = "Cover", category = "Hunts" } },
		{ "a slot without the prefix", "RegisterSlot", { id = "cover", label = "Cover", category = "Hunts" } },
		{
			"a good in an unknown slot",
			"RegisterGood",
			{ id = "hunts.frame.oak", slot = "hunts.frame", name = "Oak", tier = 1 },
		},
		{
			"a second default",
			"RegisterGood",
			{ id = "hunts.cover.tide", slot = "hunts.cover", name = "Tide", default = true },
		},
		{
			"a good of two kinds",
			"RegisterGood",
			{ id = "hunts.cover.tide", slot = "hunts.cover", name = "Tide", default = true, tier = 1 },
		},
	}) do
		it("raise an error at the Module's call for " .. case[1] .. ", registering nothing (SHOP-R23)", function()
			local loaded, hunts = huntsSession()
			local goods = {}
			for id in pairs(loaded.env.PagleDB.global.goods) do
				goods[#goods + 1] = id
			end

			local ok, err = pcall(function()
				hunts[case[2]](hunts, case[3])
			end)

			assert.is_false(ok)
			assert.matches("Goods_spec.lua:%d+: M:" .. case[2], tostring(err))
			local after = {}
			for id in pairs(loaded.env.PagleDB.global.goods) do
				after[#after + 1] = id
			end
			assert.are.same(#goods, #after)
			assert.is_nil(loaded.env.PagleDB.global.goods["hunts.cover.tide"])
		end)
	end

	it("refuse a good in another Module's slot (SHOP-R23)", function()
		local loaded, hunts = huntsSession()
		local ledger = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

		assert.has_error(function()
			ledger:RegisterGood({ id = "ledger.cover", slot = "hunts.cover", name = "Cover", tier = 1 })
		end, "M:RegisterGood: ledger.cover's slot hunts.cover is Hunts's")
		assert.is_not_nil(hunts)
	end)

	it("are handle methods: called on anything else, they raise an error (CORE-R12)", function()
		local loaded, hunts = huntsSession()

		assert.has_error(function()
			hunts.RegisterSlot({}, { id = "hunts.frame", label = "Frame", category = "Trackers" })
		end)
		assert.has_error(function()
			hunts.RefreshGoods({})
		end)
		assert.is_nil(loaded.env.Pagle.GetEquipped("hunts.frame"))
	end)

	it("report a slot with no default at ModulesChanged; its first good stands in (SHOP-R23, CORE-R19)", function()
		local loaded, hunts = huntsSession()
		hunts:RegisterSlot({ id = "hunts.frame", label = "Tracker frame", category = "Trackers" })
		hunts:RegisterGood({ id = "hunts.frame.oak", slot = "hunts.frame", name = "Oak", tier = 1 })

		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same(
			{ "Pagle: the slot hunts.frame has no default good; hunts.frame.oak stands in" },
			loaded.client.errors
		)
		assert.are.equal("hunts.frame.oak", loaded.env.Pagle.GetEquipped("hunts.frame"))
	end)
end)

describe("M:RefreshGoods", function()
	it(
		"re-reads isEarned() for the Module's earned goods only then, and the look follows (SHOP-R31, SHOP-R33)",
		function()
			local earned = { value = true }
			local loaded, hunts = huntsSession(nil, earned)
			loaded.client.fire("PLAYER_LOGIN")
			local Pagle = loaded.env.Pagle
			assert.is_true(Pagle.SetEquipped("hunts.cover", "hunts.cover.gold"))
			local fired = listen(loaded)

			earned.value = false
			assert.is_true(Pagle.IsOwned("hunts.cover.gold")) -- the cache, until the Module refreshes
			hunts:RefreshGoods()

			assert.is_false(Pagle.IsOwned("hunts.cover.gold"))
			assert.are.equal("hunts.cover.plain", Pagle.GetEquipped("hunts.cover"))
			assert.are.same({ { "hunts.cover", "hunts.cover.plain" } }, fired)
		end
	)

	it("reports an isEarned() that raises and keeps the cached result (SHOP-R26, CORE-R21)", function()
		local earned = { value = true }
		local loaded, hunts = huntsSession(nil, earned)
		setmetatable(earned, {
			__index = function()
				error("Hunts broke")
			end,
		})
		earned.value = nil

		hunts:RefreshGoods()

		assert.are.equal(1, #loaded.client.errors)
		assert.matches("Hunts broke", loaded.client.errors[1])
		assert.is_true(loaded.env.Pagle.IsOwned("hunts.cover.gold"))
	end)
end)

describe("Pagle.SetEquipped and Pagle.GetEquipped", function()
	it(
		"store an owned pick in PagleDB.profile.appearance and fire AppearanceChanged once (SHOP-R32, SHOP-R33)",
		function()
			local loaded = huntsSession(nil, { value = true })
			loaded.client.fire("PLAYER_LOGIN")
			local fired = listen(loaded)
			local Pagle = loaded.env.Pagle

			assert.is_true(Pagle.SetEquipped("hunts.cover", "hunts.cover.gold"))
			assert.is_true(Pagle.SetEquipped("hunts.cover", "hunts.cover.gold"))

			assert.are.equal("hunts.cover.gold", Pagle.GetEquipped("hunts.cover"))
			assert.are.same({ { "hunts.cover", "hunts.cover.gold" } }, fired)
			assert.are.equal("hunts.cover.gold", loaded.env.PagleDB.profiles.Default.appearance["hunts.cover"])
		end
	)

	it("refuse a good that isn't owned or is of another slot (SHOP-R32)", function()
		local loaded = huntsSession(nil, { value = false })
		loaded.client.fire("PLAYER_LOGIN")
		local fired = listen(loaded)
		local Pagle = loaded.env.Pagle

		assert.is_false(Pagle.SetEquipped("hunts.cover", "hunts.cover.velvet"))
		assert.is_false(Pagle.SetEquipped("hunts.frame", "hunts.cover.plain"))

		assert.are.equal("hunts.cover.plain", Pagle.GetEquipped("hunts.cover"))
		assert.are.same({}, fired)
	end)

	it("fire AppearanceChanged when a purchase brings the stored pick back (SHOP-R33)", function()
		local loaded =
			huntsSession({ profiles = { Default = { appearance = { ["hunts.cover"] = "hunts.cover.velvet" } } } })
		loaded.client.fire("PLAYER_LOGIN")
		local fired = listen(loaded)
		assert.are.equal("hunts.cover.plain", loaded.env.Pagle.GetEquipped("hunts.cover"))

		loaded.ns.goods:SetPurchased({ ["hunts.cover.velvet"] = true }) -- the wallet projection's seam (SHOP-R11)

		assert.are.equal("hunts.cover.velvet", loaded.env.Pagle.GetEquipped("hunts.cover"))
		assert.are.same({ { "hunts.cover", "hunts.cover.velvet" } }, fired)
	end)

	it(
		"fall back to the default while the Module is disabled, keeping the pick, which comes back (SHOP-R90)",
		function()
			local first = huntsSession(nil, { value = true })
			first.client.fire("PLAYER_LOGIN")
			assert.is_true(first.env.Pagle.SetEquipped("hunts.cover", "hunts.cover.gold"))

			-- Hunts disabled: it runs no code, so it registers nothing (CORE-R17).
			local off = loadCore(nil, first.env.PagleDB)
			off.client.fire("PLAYER_LOGIN")
			assert.are.same({ "hunts.cover.plain", true }, {
				off.env.Pagle.GetEquipped("hunts.cover"),
				off.env.Pagle.IsOwned("hunts.cover.gold"), -- from the cache (SHOP-R30)
			})
			assert.are.equal("hunts.cover.gold", off.env.PagleDB.profiles.Default.appearance["hunts.cover"])

			-- Enabled again: the look is back with no SetEquipped.
			local on = huntsSession(off.env.PagleDB, { value = true })
			on.client.fire("PLAYER_LOGIN")
			assert.are.equal("hunts.cover.gold", on.env.Pagle.GetEquipped("hunts.cover"))
		end
	)
end)

describe("Pagle.GetGood", function()
	it("reads a good's cached name, slot, icon, Module and description (graph.md question 2, LED-R112)", function()
		local loaded = huntsSession()

		assert.are.same(
			{ name = "Velvet", slot = "hunts.cover", icon = 134939, module = "Hunts" },
			loaded.env.Pagle.GetGood("hunts.cover.velvet")
		)
		assert.is_nil(loaded.env.Pagle.GetGood("hunts.cover.none"))
	end)
end)

describe("Core's own goods", function()
	it("register with the core. prefix, listed before every Module's, and raise at Core's call (SHOP-R21)", function()
		local loaded = huntsSession()
		local ns = loaded.ns

		-- Core's three slots (SHOP-R25) are in already, from login step 1 (spec/Pagle/adapter/CoreGoods_spec.lua).
		ns.RegisterCoreSlot({ id = "core.frame", label = "Tracker frame", category = "Trackers" })
		ns.RegisterCoreGood({ id = "core.frame.plain", slot = "core.frame", name = "Plain", default = true })
		local ok, err = pcall(function()
			ns.RegisterCoreGood({ id = "hunts.frame", slot = "core.frame", name = "Frame", tier = 1 })
		end)
		loaded.client.fire("PLAYER_LOGIN")

		assert.is_false(ok)
		assert.matches("Goods_spec.lua:%d+: M:RegisterGood: hunts.frame doesn't start with core.", tostring(err))
		assert.are.same({ "core.frame", "hunts.cover" }, {
			ns.goods:Slots()[4].id,
			ns.goods:Slots()[5].id,
		})
		assert.are.equal("Core", loaded.env.Pagle.GetGood("core.frame.plain").module)
		assert.are.equal("core.frame.plain", loaded.env.Pagle.GetEquipped("core.frame"))
	end)
end)
