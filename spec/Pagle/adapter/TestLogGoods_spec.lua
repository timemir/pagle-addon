-- A test log's grant of every good (`devGoods`, catch-log.md › Data, SHOP-R37), as Core runs it through the real TOC:
-- Pagle.GetTestLogGrant("devGoods"), and every ownership question (Pagle.IsOwned, Pagle.GetSlotGoods, the shop's
-- states and crate) answering from the one place that decides it, ns.goods. It is display and ownership only.

-- Core on Forever over a saved log with `fields` set on it, and Hunts registering its notebook cover slot: a default, a
-- good for sale, an earned good not earned, and Core's own goods beside them. Logged in and in the world.
---@param fields table? set on the saved log: `test`, `devGoods`, `devCoins`
---@return LoadedAddon loaded
local function login(fields)
	local log = savedLog({ "C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1" })
	for key, value in pairs(fields or {}) do
		log[key] = value
	end
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
	loaded.client.addons.Pagle_Hunts = { metadata = { ["X-Pagle-API"] = "1" } }
	local hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
	hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
	hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
	hunts:RegisterGood({ id = "hunts.cover.velvet", slot = "hunts.cover", name = "Velvet", tier = 2 })
	hunts:RegisterGood({
		id = "hunts.cover.gold",
		slot = "hunts.cover",
		name = "Gold",
		earnedText = "Every Hunt done",
		isEarned = function()
			return false
		end,
	})
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD")
	return loaded
end

-- Every good Core knows of, registered or cached, by ID.
---@param loaded LoadedAddon
---@return string[]
local function everyGood(loaded)
	local ids = {}
	for id, cached in pairs(loaded.env.PagleDB.global.goods) do
		if type(cached) == "table" then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

-- The IDs of `ids` that Pagle.IsOwned says are not owned.
---@param loaded LoadedAddon
---@param ids string[]
---@return string[]
local function notOwned(loaded, ids)
	local missing = {}
	for _, id in ipairs(ids) do
		if not loaded.env.Pagle.IsOwned(id) then
			missing[#missing + 1] = id
		end
	end
	return missing
end

describe("a test log's devGoods (SHOP-R37)", function()
	it("is read through Pagle.GetTestLogGrant on a test log only (catch-log.md › Data)", function()
		assert.is_true(login({ test = true, devGoods = true }).env.Pagle.GetTestLogGrant("devGoods"))
		assert.is_nil(login({ test = true }).env.Pagle.GetTestLogGrant("devGoods"))
		assert.is_nil(login({ devGoods = true }).env.Pagle.GetTestLogGrant("devGoods"))
		assert.is_nil(login({ test = true, devGoods = 1 }).env.Pagle.GetTestLogGrant("devGoods"))
	end)

	describe("on a test log with it", function()
		local loaded, Pagle
		before_each(function()
			loaded = login({ test = true, devGoods = true })
			Pagle = loaded.env.Pagle
		end)

		it("owns every good in the catalogue, for sale, earned or crate only (SHOP-R30)", function()
			local ids = everyGood(loaded)
			assert.is_true(#ids > 40)
			assert.are.same({}, notOwned(loaded, ids))
			-- one of each kind, by name
			assert.is_true(Pagle.IsOwned("hunts.cover.velvet"))
			assert.is_true(Pagle.IsOwned("hunts.cover.gold"))
			assert.is_true(Pagle.IsOwned("core.toaststyle.foil"))
		end)

		it(
			"owns a good a Module registers and says it isn't earned, and still owns nothing that isn't a good",
			function()
				assert.is_false(loaded.ns.goods:Good("hunts.cover.gold").isEarned())
				assert.is_false(Pagle.IsOwned("hunts.cover.nothing"))
				assert.is_false(Pagle.IsOwned(nil))
			end
		)

		it("lists every good of a slot as owned for its dropdown, and none as for sale (SET-R51)", function()
			local wrong = {}
			for _, slot in ipairs(Pagle.GetSlots()) do
				for _, id in ipairs(Pagle.GetSlotGoods(slot.id)) do
					if not Pagle.IsOwned(id) or loaded.ns.goods:IsForSale(id) then
						wrong[#wrong + 1] = id
					end
				end
			end
			assert.are.same({}, wrong)
			assert.are.equal(3, #loaded.ns.goods:OwnedOf("hunts.cover"))
		end)

		it("equips an owned-by-grant good and wears it, with no purchase behind it (SHOP-R32)", function()
			assert.is_true(Pagle.SetEquipped("hunts.cover", "hunts.cover.velvet"))
			assert.are.equal("hunts.cover.velvet", Pagle.GetEquipped("hunts.cover"))
			assert.is_true(Pagle.SetEquipped("hunts.cover", "hunts.cover.gold"))
			assert.are.equal("hunts.cover.gold", Pagle.GetEquipped("hunts.cover"))
			assert.are.same({ purchased = false, fromCrate = false }, {
				purchased = Pagle.GetGood("hunts.cover.velvet").purchased,
				fromCrate = Pagle.GetGood("hunts.cover.velvet").fromCrate,
			})
		end)

		it(
			"shows each good in the shop as owned or in use, never for sale, and takes the crate away (SHOP-R50)",
			function()
				local shop = loaded.ns.ShopModel()
				assert.are.equal("owned", shop:Entry("hunts.cover.velvet").state)
				assert.are.equal("equipped", shop:Entry("hunts.cover.plain").state)
				assert.are.equal("owned", shop:Entry("core.toaststyle.foil").state)
				assert.is_nil(shop:Purchase("hunts.cover.velvet"))
				assert.is_nil(shop:Select(loaded.ns.CRATE_ID))
				assert.is_nil(shop:Purchase(loaded.ns.CRATE_ID))
			end
		)

		it(
			"spends no Coins and writes no entry: the log, the balance and the purchased set are as they were",
			function()
				local plain = login({ test = true })
				assert.are.equal(#plain.ns.catchLog.data.entries, #loaded.ns.catchLog.data.entries)
				for _, record in ipairs(loaded.ns.catchLog.data.entries) do
					assert.is_nil(record:match("^U1|"))
				end
				assert.are.same({ balance = 0, held = false, earned = {} }, Pagle.GetBalance())
				assert.are.same({}, loaded.ns.walletSnapshot.owned)
			end
		)
	end)

	for _, case in ipairs({
		{ "a player's log (no test mark)", { devGoods = true } },
		{ "a test log without it", { test = true } },
		{ "a test log where it is false", { test = true, devGoods = false } },
	}) do
		it("changes nothing on " .. case[1] .. ": only defaults and earned goods are owned (SHOP-R30)", function()
			local loaded = login(case[2])
			local Pagle = loaded.env.Pagle

			assert.is_true(#notOwned(loaded, everyGood(loaded)) > 40)
			assert.is_true(Pagle.IsOwned("hunts.cover.plain"))
			assert.is_false(Pagle.IsOwned("hunts.cover.velvet"))
			assert.is_false(Pagle.IsOwned("hunts.cover.gold"))
			assert.is_false(Pagle.IsOwned("core.toaststyle.foil"))
			assert.is_false(Pagle.SetEquipped("hunts.cover", "hunts.cover.velvet"))
			assert.is_true(loaded.ns.goods:IsForSale("hunts.cover.velvet"))
			assert.is_not_nil(loaded.ns.ShopModel():Select(loaded.ns.CRATE_ID))
		end)
	end

	it("leaves the Coins a test log grants as they are: devCoins and devGoods are separate grants", function()
		local loaded = login({ test = true, devGoods = true, devCoins = 50000 })

		assert.are.same({ balance = 50000, held = false, earned = { Dev = 50000 } }, loaded.env.Pagle.GetBalance())
	end)

	it("is not what a recording's preview copy of the goods reads (it owns by its own disposable DB)", function()
		local loaded = login({ test = true, devGoods = true })

		local copy = loaded.ns.goods:PreviewCopy()

		assert.is_true(loaded.ns.goods:IsOwned("hunts.cover.velvet"))
		assert.is_false(copy:IsOwned("hunts.cover.velvet"))
	end)
end)
