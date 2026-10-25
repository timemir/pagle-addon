-- The goods registry (wallet-and-shop.md › Goods, Owning and equipping, SHOP-R20–R26, SHOP-R30–R33, SHOP-R90), as
-- pure logic: slots and goods registered, the cache in PagleDB.global.goods, what is owned and what is equipped.

describe("ns.NewGoods", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- A registry over a fresh PagleDB, with Hunts (order 20) and the Ledger (10) On. `env.on` is the Modules On, by
	-- name, which a spec changes to turn one off; `env.fired` each AppearanceChanged as { slot, goodID }; `env.reported`
	-- each report; `env.db` the PagleDB. `call` runs a Module's isEarned, by default as is.
	local function newGoods(db, call)
		local env = {
			db = db or { global = { goods = {} }, profile = { appearance = {} } },
			on = { Hunts = 20, Ledger = 10 },
			fired = {},
			reported = {},
		}
		env.goods = ns.NewGoods({
			db = function()
				return env.db
			end,
			modules = function()
				local list = {}
				for name, order in pairs(env.on) do
					list[#list + 1] = { def = { name = name, title = name, order = order } }
				end
				table.sort(list, function(a, b)
					return a.def.order < b.def.order
				end)
				return list
			end,
			fire = function(event, slot, goodID)
				env.fired[#env.fired + 1] = { event, slot, goodID }
			end,
			call = call or function(fn, ...)
				return fn(...)
			end,
			report = function(message)
				env.reported[#env.reported + 1] = message
			end,
		})
		return env
	end

	-- Hunts' notebook cover slot, with a default, a tier-2 good and an earned good whose isEarned returns `earned.value`.
	local function huntsCovers(env, earned)
		local goods = env.goods
		assert.is_nil(
			goods:RegisterSlot("Hunts", { id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
		)
		assert.is_nil(
			goods:RegisterGood(
				"Hunts",
				{ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true }
			)
		)
		assert.is_nil(
			goods:RegisterGood("Hunts", { id = "hunts.cover.velvet", slot = "hunts.cover", name = "Velvet", tier = 2 })
		)
		assert.is_nil(goods:RegisterGood("Hunts", {
			id = "hunts.cover.gold",
			slot = "hunts.cover",
			name = "Gold",
			isEarned = function()
				return earned.value
			end,
			earnedText = "Every Hunt done",
		}))
	end

	describe("registering", function()
		-- Each mistake SHOP-R23 lists (and a field of the wrong type), as `module` registering `slot` or `good` after
		-- Hunts' covers, Core's toast style slot and the Ledger's binding slot are in. `cover` is a tier-1 cover with
		-- `fields` changed, a field set to false left out.
		local function cover(fields)
			local good = { id = "hunts.cover.tide", slot = "hunts.cover", name = "Tide", tier = 1 }
			for key, value in pairs(fields) do
				if value == false then
					good[key] = nil
				else
					good[key] = value
				end
			end
			return good
		end
		local isEarned = function()
			return true
		end
		local cases = {
			{ "a slot that isn't a table", "Hunts", { slot = "hunts.cover" } },
			{
				"a slot ID with a space",
				"Hunts",
				{ slot = { id = "hunts.big cover", label = "Cover", category = "Trackers" } },
			},
			{
				"a slot ID without the Module's prefix",
				"Hunts",
				{ slot = { id = "ledger.cover", label = "Cover", category = "Trackers" } },
			},
			{
				"a slot ID that is only the prefix",
				"Hunts",
				{ slot = { id = "hunts.", label = "Cover", category = "Trackers" } },
			},
			{
				"Core's slot ID without core.",
				"Core",
				{ slot = { id = "hunts.style", label = "Style", category = "Announcements" } },
			},
			{
				"a duplicate slot ID",
				"Hunts",
				{ slot = { id = "hunts.cover", label = "Cover", category = "Trackers" } },
			},
			{ "a slot without a label", "Hunts", { slot = { id = "hunts.frame", category = "Trackers" } } },
			{ "an unknown category", "Hunts", { slot = { id = "hunts.frame", label = "Frame", category = "Maps" } } },
			{ "a good that isn't a table", "Hunts", { good = "hunts.cover.tide" } },
			{ "a duplicate good ID", "Hunts", { good = cover({ id = "hunts.cover.velvet" }) } },
			{ "a good ID without the Module's prefix", "Hunts", { good = cover({ id = "cover.tide" }) } },
			{ "a good ID with a slash", "Hunts", { good = cover({ id = "hunts.cover/tide" }) } },
			{ "an unknown slot", "Hunts", { good = cover({ slot = "hunts.frame" }) } },
			{ "a slot of a different Module", "Ledger", { good = cover({ id = "ledger.tide" }) } },
			{ "a slot of Core, for a Module", "Hunts", { good = cover({ slot = "core.toaststyle" }) } },
			{ "a second default in a slot", "Hunts", { good = cover({ tier = false, default = true }) } },
			{ "a default for sale", "Hunts", { good = cover({ default = true }) } },
			{ "an earned good for sale", "Hunts", { good = cover({ isEarned = isEarned }) } },
			{
				"an earned default",
				"Ledger",
				{
					good = { id = "ledger.x", slot = "ledger.binding", name = "X", default = true, isEarned = isEarned },
				},
			},
			{ "neither default, for sale nor earned", "Hunts", { good = cover({ tier = false }) } },
			{ "tier 0", "Hunts", { good = cover({ tier = 0 }) } },
			{ "tier 7", "Hunts", { good = cover({ tier = 7 }) } },
			{ "an isEarned that isn't a function", "Hunts", { good = cover({ tier = false, isEarned = true }) } },
			{ "a good without a name", "Hunts", { good = cover({ name = "" }) } },
			{ "a preview that isn't a function", "Hunts", { good = cover({ preview = "stage" }) } },
			{ "a default that isn't true or false", "Hunts", { good = cover({ tier = false, default = "yes" }) } },
			{ "an earnedText that is neither text nor a function", "Hunts", { good = cover({ earnedText = 3 }) } },
			{
				"a progress that isn't a function",
				"Hunts",
				{ good = cover({ tier = false, isEarned = isEarned, progress = {} }) },
			},
			{ "a progress on a good that isn't earned", "Hunts", { good = cover({ progress = function() end }) } },
			{ "a group its slot doesn't have", "Hunts", { good = cover({ group = "gilt" }) } },
			{ "a crate-only good from a Module", "Hunts", { good = cover({ tier = false, crate = true }) } },
			{
				"a crate-only good for sale",
				"Core",
				{ good = { id = "core.x", slot = "core.toaststyle", name = "X", tier = 1, crate = true } },
			},
			{
				"a crate-only good earned",
				"Core",
				{ good = { id = "core.x", slot = "core.toaststyle", name = "X", isEarned = isEarned, crate = true } },
			},
			{
				"a crate that isn't true",
				"Core",
				{ good = { id = "core.x", slot = "core.toaststyle", name = "X", crate = "yes" } },
			},
			{
				"groups that aren't a list",
				"Hunts",
				{ slot = { id = "hunts.frame", label = "Frame", category = "Trackers", groups = "gilt" } },
			},
			{
				"a group without a key",
				"Hunts",
				{
					slot = {
						id = "hunts.frame",
						label = "Frame",
						category = "Trackers",
						groups = { { name = "Gilt" } },
					},
				},
			},
			{
				"a group key with a dot",
				"Hunts",
				{
					slot = {
						id = "hunts.frame",
						label = "Frame",
						category = "Trackers",
						groups = { { key = "gilt.old", name = "Gilt" } },
					},
				},
			},
			{
				"a group without a name",
				"Hunts",
				{
					slot = { id = "hunts.frame", label = "Frame", category = "Trackers", groups = { { key = "gilt" } } },
				},
			},
			{
				"a group key twice",
				"Hunts",
				{
					slot = {
						id = "hunts.frame",
						label = "Frame",
						category = "Trackers",
						groups = { { key = "gilt", name = "Gilt" }, { key = "gilt", name = "Gold" } },
					},
				},
			},
		}
		for _, case in ipairs(cases) do
			it("refuses " .. case[1] .. ", registering and caching nothing (SHOP-R21, SHOP-R23)", function()
				local env = newGoods()
				huntsCovers(env, { value = false })
				assert.is_nil(
					env.goods:RegisterSlot(
						"Core",
						{ id = "core.toaststyle", label = "Toast style", category = "Announcements" }
					)
				)
				assert.is_nil(
					env.goods:RegisterSlot(
						"Ledger",
						{ id = "ledger.binding", label = "Journal binding", category = "Books" }
					)
				)
				local cached = {}
				for id in pairs(env.db.global.goods) do
					cached[#cached + 1] = id
				end
				table.sort(cached)
				local slots = #env.goods:Slots()
				local inCovers = #env.goods:GoodsOf("hunts.cover")

				local problem
				if case[3].good ~= nil then
					problem = env.goods:RegisterGood(case[2], case[3].good)
				else
					problem = env.goods:RegisterSlot(case[2], case[3].slot)
				end

				assert.is_string(problem)
				local after = {}
				for id in pairs(env.db.global.goods) do
					after[#after + 1] = id
				end
				table.sort(after)
				assert.are.same(cached, after)
				assert.are.same({ slots, inCovers }, { #env.goods:Slots(), #env.goods:GoodsOf("hunts.cover") })
			end)
		end

		it("says what is wrong, naming the call (SHOP-R23)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			assert.are.equal(
				"M:RegisterGood: hunts.cover already has a default, hunts.cover.plain",
				env.goods:RegisterGood("Hunts", cover({ tier = false, default = true }))
			)
			assert.are.equal(
				"M:RegisterSlot: ledger.cover doesn't start with hunts.",
				env.goods:RegisterSlot("Hunts", { id = "ledger.cover", label = "Cover", category = "Trackers" })
			)
		end)

		it("keeps a slot's groups in order, as a copy, and each good's group (SHOP-R27)", function()
			local env = newGoods()
			local groups = { { key = "gilt", name = "Gilt frames" }, { key = "wood", name = "Wooden frames" } }
			local progress = function()
				return {}
			end
			assert.is_nil(
				env.goods:RegisterSlot(
					"Hunts",
					{ id = "hunts.frame", label = "Frame", category = "Trackers", groups = groups }
				)
			)
			groups[1].name = "Changed"
			assert.is_nil(env.goods:RegisterGood("Hunts", {
				id = "hunts.frame.oak",
				slot = "hunts.frame",
				name = "Oak",
				tier = 1,
				group = "wood",
			}))
			assert.is_nil(env.goods:RegisterGood("Hunts", {
				id = "hunts.frame.leaf",
				slot = "hunts.frame",
				name = "Gold leaf",
				group = "gilt",
				isEarned = function()
					return false
				end,
				earnedText = function()
					return "1 of 3", "One of three gilded."
				end,
				progress = progress,
			}))

			local slot = env.goods:Slots()[1]
			assert.are.same(
				{ { key = "gilt", name = "Gilt frames" }, { key = "wood", name = "Wooden frames" } },
				slot.groups
			)
			assert.are.same({ "wood", "gilt" }, { slot.goods[1].group, slot.goods[2].group })
			assert.are.equal(progress, assert(env.goods:Good("hunts.frame.leaf")).progress)
			assert.is_nil(env.goods:Slots()[1].groups[3])
		end)

		it("leaves a slot registered without groups without any (SHOP-R27)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			assert.is_nil(env.goods:Slots()[1].groups)
		end)

		it("lists the slots of Core first, then by Module order, each with its goods in order (SHOP-R21)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })
			env.goods:RegisterSlot("Ledger", { id = "ledger.binding", label = "Journal binding", category = "Books" })
			env.goods:RegisterSlot("Core", { id = "core.crest", label = "Crests", category = "Crests" })
			env.goods:RegisterSlot(
				"Core",
				{ id = "core.toaststyle", label = "Toast style", category = "Announcements" }
			)

			local ids = {}
			for i, slot in ipairs(env.goods:Slots()) do
				ids[i] = slot.id .. " " .. slot.module
			end
			local covers = {}
			for i, good in ipairs(env.goods:GoodsOf("hunts.cover")) do
				covers[i] = good.id
			end

			assert.are.same(
				{ "core.crest Core", "core.toaststyle Core", "ledger.binding Ledger", "hunts.cover Hunts" },
				ids
			)
			assert.are.same({ "hunts.cover.plain", "hunts.cover.velvet", "hunts.cover.gold" }, covers)
		end)
	end)

	it(
		"prices tiers 1 to 6 at 250, 400, 900, 3,000, 10,000 and 25,000 Coins, and registers a tier 4, a tier 5 and a tier 6 good (SHOP-R22, Tunables)",
		function()
			local env = newGoods()
			env.goods:RegisterSlot("Hunts", { id = "hunts.cover", label = "Cover", category = "Trackers" })
			env.goods:RegisterGood(
				"Hunts",
				{ id = "hunts.cover.calf", slot = "hunts.cover", name = "Calf", default = true }
			)
			env.goods:RegisterGood(
				"Hunts",
				{ id = "hunts.cover.scrim", slot = "hunts.cover", name = "Scrim", tier = 4 }
			)
			env.goods:RegisterGood(
				"Hunts",
				{ id = "hunts.cover.trophy", slot = "hunts.cover", name = "Trophy", tier = 5 }
			)
			env.goods:RegisterGood(
				"Hunts",
				{ id = "hunts.cover.regalia", slot = "hunts.cover", name = "Regalia", tier = 6 }
			)

			assert.are.same({ 250, 400, 900, 3000, 10000, 25000 }, ns.TIER_PRICES)
			assert.are.same({}, env.reported)
		end
	)

	describe("owning", function()
		it("lists a slot's owned goods, and which of its goods are still for sale (SHOP-R22, SHOP-R30)", function()
			local env = newGoods()
			huntsCovers(env, { value = true })
			env.goods:RegisterGood("Hunts", { id = "hunts.cover.tide", slot = "hunts.cover", name = "Tide", tier = 1 })
			env.goods:SetPurchased({ ["hunts.cover.tide"] = true })

			local owned = {}
			for _, good in ipairs(env.goods:OwnedOf("hunts.cover")) do
				owned[#owned + 1] = good.id
			end
			assert.are.same({ "hunts.cover.plain", "hunts.cover.gold", "hunts.cover.tide" }, owned)
			assert.are.same({ false, true, false, false, false }, {
				env.goods:IsForSale("hunts.cover.plain"),
				env.goods:IsForSale("hunts.cover.velvet"),
				env.goods:IsForSale("hunts.cover.gold"),
				env.goods:IsForSale("hunts.cover.tide"),
				env.goods:IsForSale("hunts.cover.none"),
			})
		end)

		it(
			"takes Core's crate-only good, cached as one, never for sale, owned once a crate's good is handed over"
				.. " (SHOP-R22, SHOP-R26, SHOP-R50)",
			function()
				local env = newGoods()
				assert.is_nil(
					env.goods:RegisterSlot(
						"Core",
						{ id = "core.toaststyle", label = "Toast style", category = "Announcements" }
					)
				)
				assert.is_nil(
					env.goods:RegisterGood(
						"Core",
						{ id = "core.toaststyle.page", slot = "core.toaststyle", name = "Torn Page", default = true }
					)
				)

				assert.is_nil(
					env.goods:RegisterGood(
						"Core",
						{ id = "core.toaststyle.foil", slot = "core.toaststyle", name = "Prize Foil", crate = true }
					)
				)

				assert.is_true(env.db.global.goods["core.toaststyle.foil"].crate)
				assert.are.same({ false, false }, {
					env.goods:IsForSale("core.toaststyle.foil"),
					env.goods:IsOwned("core.toaststyle.foil"),
				})
				env.goods:SetPurchased({ ["core.toaststyle.foil"] = true }) -- the wallet's owned set, crates' goods in it
				assert.is_true(env.goods:IsOwned("core.toaststyle.foil"))
			end
		)

		it("owns a registered slot's default, not a good for sale (SHOP-R22, SHOP-R30)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			assert.is_true(env.goods:IsOwned("hunts.cover.plain"))
			assert.is_false(env.goods:IsOwned("hunts.cover.velvet"))
		end)

		it("owns a good for sale once it is in the purchased set, and only then (SHOP-R30, SHOP-R11)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
			assert.is_true(env.goods:IsOwned("hunts.cover.velvet"))

			env.goods:SetPurchased({})
			assert.is_false(env.goods:IsOwned("hunts.cover.velvet"))
		end)

		it("follows an earned good's cached isEarned(), which changes only at Refresh (SHOP-R30, SHOP-R31)", function()
			local env = newGoods()
			local earned, calls = { value = false }, 0
			huntsCovers(
				env,
				setmetatable({}, {
					__index = function()
						calls = calls + 1
						return earned.value
					end,
				})
			)
			assert.are.equal(1, calls) -- at registration (SHOP-R31)

			earned.value = true
			assert.is_false(env.goods:IsOwned("hunts.cover.gold"))
			assert.are.equal(1, calls) -- an ownership check never calls it

			env.goods:Refresh("Hunts")
			assert.is_true(env.goods:IsOwned("hunts.cover.gold"))
			assert.are.equal(2, calls)
		end)

		it(
			"keeps owning a cached good of a Module that isn't On, and never calls its isEarned (SHOP-R30, SHOP-R90)",
			function()
				local env = newGoods({
					global = {
						goods = {
							["hunts.cover.gold"] = {
								name = "Gold",
								slot = "hunts.cover",
								module = "Hunts",
								earned = true,
							},
							["hunts.cover.velvet"] = {
								name = "Velvet",
								slot = "hunts.cover",
								module = "Hunts",
								tier = 2,
							},
							["hunts.cover.plain"] = {
								name = "Plain",
								slot = "hunts.cover",
								module = "Hunts",
								default = true,
							},
						},
					},
					profile = { appearance = {} },
				})
				env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })

				assert.are.same(
					{ true, true },
					{ env.goods:IsOwned("hunts.cover.gold"), env.goods:IsOwned("hunts.cover.velvet") }
				)
				-- A default is owned for a registered slot only (SHOP-R30); this one isn't registered this session.
				assert.is_false(env.goods:IsOwned("hunts.cover.plain"))
			end
		)

		it("owns nothing unknown, and answers false for an ID that isn't a string (SHOP-R30)", function()
			local env = newGoods()

			assert.are.same({ false, false }, { env.goods:IsOwned("hunts.cover.none"), env.goods:IsOwned(nil) })
		end)
	end)

	describe("equipping", function()
		it("equips a slot's default until something else is picked (SHOP-R32)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			assert.are.equal("hunts.cover.plain", env.goods:GetEquipped("hunts.cover"))
			assert.is_nil(env.goods:GetEquipped("hunts.frame"))
		end)

		it("stores an owned good of the slot as the pick, in PagleDB.profile.appearance (SHOP-R32)", function()
			local env = newGoods()
			huntsCovers(env, { value = true })

			assert.is_true(env.goods:SetEquipped("hunts.cover", "hunts.cover.gold"))

			assert.are.equal("hunts.cover.gold", env.goods:GetEquipped("hunts.cover"))
			assert.are.same({ ["hunts.cover"] = "hunts.cover.gold" }, env.db.profile.appearance)
		end)

		it("refuses a good that isn't owned, isn't of that slot or isn't known, storing nothing (SHOP-R32)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })
			env.goods:RegisterSlot("Hunts", { id = "hunts.frame", label = "Tracker frame", category = "Trackers" })
			env.goods:RegisterGood(
				"Hunts",
				{ id = "hunts.frame.oak", slot = "hunts.frame", name = "Oak", default = true }
			)

			assert.are.same({ false, false, false, false }, {
				env.goods:SetEquipped("hunts.cover", "hunts.cover.velvet"), -- for sale, not bought
				env.goods:SetEquipped("hunts.cover", "hunts.cover.gold"), -- earned, not yet
				env.goods:SetEquipped("hunts.cover", "hunts.frame.oak"), -- owned, another slot's
				env.goods:SetEquipped("hunts.cover", "hunts.cover.none"),
			})
			assert.are.same({}, env.db.profile.appearance)
			assert.are.equal("hunts.cover.plain", env.goods:GetEquipped("hunts.cover"))
		end)

		it(
			"falls back to the default while the pick isn't owned, keeping the pick, which comes back (SHOP-R32)",
			function()
				local env = newGoods()
				local earned = { value = true }
				huntsCovers(env, earned)
				env.goods:SetEquipped("hunts.cover", "hunts.cover.gold")

				earned.value = false
				env.goods:Refresh("Hunts")
				assert.are.equal("hunts.cover.plain", env.goods:GetEquipped("hunts.cover"))
				assert.are.equal("hunts.cover.gold", env.db.profile.appearance["hunts.cover"])

				earned.value = true
				env.goods:Refresh("Hunts")
				assert.are.equal("hunts.cover.gold", env.goods:GetEquipped("hunts.cover"))
			end
		)

		it(
			"falls back to the default while its Module is off, and the pick comes back with it (SHOP-R32, SHOP-R90)",
			function()
				local env = newGoods()
				huntsCovers(env, { value = false })
				env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
				env.goods:SetEquipped("hunts.cover", "hunts.cover.velvet")

				env.on.Hunts = nil
				assert.are.equal("hunts.cover.plain", env.goods:GetEquipped("hunts.cover"))
				assert.is_true(env.goods:IsOwned("hunts.cover.velvet")) -- still owned, from the cache

				env.on.Hunts = 20
				assert.are.equal("hunts.cover.velvet", env.goods:GetEquipped("hunts.cover"))
			end
		)

		it(
			"falls back to the cached default in a session its Module doesn't register in, and back after (SHOP-R90)",
			function()
				local env = newGoods()
				huntsCovers(env, { value = false })
				env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
				env.goods:SetEquipped("hunts.cover", "hunts.cover.velvet")

				local off = newGoods(env.db) -- the next session: Hunts disabled, so it registers nothing
				off.on.Hunts = nil
				off.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
				assert.are.equal("hunts.cover.plain", off.goods:GetEquipped("hunts.cover"))

				local on = newGoods(env.db) -- the one after: Hunts on again
				huntsCovers(on, { value = false })
				on.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
				assert.are.equal("hunts.cover.velvet", on.goods:GetEquipped("hunts.cover"))
			end
		)
	end)

	describe("AppearanceChanged", function()
		-- Hunts' covers registered and Start (ModulesChanged) run, with `earned` deciding the earned cover.
		local function started(earned)
			local env = newGoods()
			huntsCovers(env, earned or { value = true })
			env.goods:Start()
			return env
		end

		it("fires nothing at Start, nor before it (SHOP-R33)", function()
			local env = newGoods()
			huntsCovers(env, { value = true })
			env.goods:SetEquipped("hunts.cover", "hunts.cover.gold")
			env.goods:Start()

			assert.are.same({}, env.fired)
		end)

		it("fires once for a SetEquipped that changes the look, and not for one that doesn't (SHOP-R33)", function()
			local env = started()

			env.goods:SetEquipped("hunts.cover", "hunts.cover.gold")
			env.goods:SetEquipped("hunts.cover", "hunts.cover.gold")
			env.goods:SetEquipped("hunts.cover", "hunts.cover.velvet") -- refused

			assert.are.same({ { "AppearanceChanged", "hunts.cover", "hunts.cover.gold" } }, env.fired)
		end)

		it("fires once when the Module goes off and once when it comes back (SHOP-R33, SHOP-R90)", function()
			local env = started()
			env.goods:SetEquipped("hunts.cover", "hunts.cover.gold")
			env.fired = {}

			env.on.Hunts = nil
			env.goods:Settle()
			env.goods:Settle()
			env.on.Hunts = 20
			env.goods:Settle()

			assert.are.same({
				{ "AppearanceChanged", "hunts.cover", "hunts.cover.plain" },
				{ "AppearanceChanged", "hunts.cover", "hunts.cover.gold" },
			}, env.fired)
		end)

		it("fires once when an earned good is lost, at the Refresh that loses it (SHOP-R31, SHOP-R33)", function()
			local earned = { value = true }
			local env = started(earned)
			env.goods:SetEquipped("hunts.cover", "hunts.cover.gold")
			env.fired = {}

			earned.value = false
			env.goods:Refresh("Hunts")
			env.goods:Refresh("Hunts")

			assert.are.same({ { "AppearanceChanged", "hunts.cover", "hunts.cover.plain" } }, env.fired)
		end)

		it("fires when a purchase makes the stored pick owned (SHOP-R33)", function()
			local env = newGoods({
				global = { goods = {} },
				profile = { appearance = { ["hunts.cover"] = "hunts.cover.velvet" } },
			})
			huntsCovers(env, { value = false })
			env.goods:Start()

			env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
			env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })

			assert.are.same({ { "AppearanceChanged", "hunts.cover", "hunts.cover.velvet" } }, env.fired)
		end)

		it("fires nothing for a change that leaves the look, such as an unequipped good earned (SHOP-R33)", function()
			local earned = { value = false }
			local env = started(earned)

			earned.value = true
			env.goods:Refresh("Hunts")
			env.goods:SetPurchased({ ["hunts.cover.velvet"] = true })

			assert.are.same({}, env.fired)
		end)

		it("fires when a slot registered after Start brings back its stored pick (SHOP-R21, SHOP-R33)", function()
			local env = newGoods({
				global = { goods = {} },
				profile = { appearance = { ["hunts.cover"] = "hunts.cover.gold" } },
			})
			env.goods:Start()

			huntsCovers(env, { value = true })

			assert.are.same({
				{ "AppearanceChanged", "hunts.cover", "hunts.cover.plain" },
				{ "AppearanceChanged", "hunts.cover", "hunts.cover.gold" },
			}, env.fired)
		end)
	end)

	describe("Start", function()
		it("reports a slot with no default, whose first good stands in for it (SHOP-R23)", function()
			local env = newGoods()
			env.goods:RegisterSlot("Hunts", { id = "hunts.frame", label = "Tracker frame", category = "Trackers" })
			env.goods:RegisterGood("Hunts", { id = "hunts.frame.oak", slot = "hunts.frame", name = "Oak", tier = 1 })
			env.goods:RegisterGood("Hunts", { id = "hunts.frame.ash", slot = "hunts.frame", name = "Ash", tier = 2 })

			env.goods:Start()

			assert.are.same(
				{ "Pagle: the slot hunts.frame has no default good; hunts.frame.oak stands in" },
				env.reported
			)
			assert.are.equal("hunts.frame.oak", env.goods:GetEquipped("hunts.frame"))
			assert.is_true(env.goods:IsOwned("hunts.frame.oak"))
		end)

		it("passes over a cached entry without a slot, as a hand-edited PagleDB might hold (SHOP-R26)", function()
			local env = newGoods({
				global = { goods = { ["hunts.cover.odd"] = { name = "Odd" } } },
				profile = { appearance = {} },
			})
			huntsCovers(env, { value = false })

			env.goods:Start()
			env.goods:Settle()

			assert.are.equal("hunts.cover.plain", env.goods:GetEquipped("hunts.cover"))
		end)

		it("reports a slot whose goods all say default = false, which marks no default (SHOP-R22, SHOP-R23)", function()
			local env = newGoods()
			env.goods:RegisterSlot("Hunts", { id = "hunts.frame", label = "Tracker frame", category = "Trackers" })
			env.goods:RegisterGood("Hunts", {
				id = "hunts.frame.oak",
				slot = "hunts.frame",
				name = "Oak",
				default = false,
				tier = 1,
			})

			env.goods:Start()

			assert.are.same(
				{ "Pagle: the slot hunts.frame has no default good; hunts.frame.oak stands in" },
				env.reported
			)
		end)

		it("reports nothing when every slot has a default (SHOP-R23)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			env.goods:Start()

			assert.are.same({}, env.reported)
		end)
	end)

	describe("GetGood", function()
		it("reads a good's name, slot, icon, Module and description from the cache, as a copy (SHOP-R26)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })
			env.goods:RegisterGood("Hunts", {
				id = "hunts.cover.tide",
				slot = "hunts.cover",
				name = "Tide",
				description = "Blue as the Long Wash.",
				icon = 134939,
				tier = 1,
			})

			local good = env.goods:GetGood("hunts.cover.tide")
			good.name = "Changed"

			assert.are.same({
				name = "Tide",
				slot = "hunts.cover",
				icon = 134939,
				module = "Hunts",
				description = "Blue as the Long Wash.",
				isDefault = false,
			}, env.goods:GetGood("hunts.cover.tide"))
		end)

		it("tells the slot's default, the good a view may draw as no look at all (SHOP-R22, SHOP-R26)", function()
			local env = newGoods()
			huntsCovers(env, { value = true })

			assert.are.same({ true, false, false }, {
				env.goods:GetGood("hunts.cover.plain").isDefault,
				env.goods:GetGood("hunts.cover.velvet").isDefault,
				env.goods:GetGood("hunts.cover.gold").isDefault,
			})
		end)

		it("tells the good standing in for a slot with no default as its default (SHOP-R23)", function()
			local env = newGoods()
			env.goods:RegisterSlot("Hunts", { id = "hunts.frame", label = "Tracker frame", category = "Trackers" })
			env.goods:RegisterGood("Hunts", { id = "hunts.frame.oak", slot = "hunts.frame", name = "Oak", tier = 1 })
			env.goods:RegisterGood("Hunts", { id = "hunts.frame.ash", slot = "hunts.frame", name = "Ash", tier = 2 })

			assert.are.same(
				{ true, false },
				{ env.goods:GetGood("hunts.frame.oak").isDefault, env.goods:GetGood("hunts.frame.ash").isDefault }
			)
		end)

		it("reads a cached good of a Module that is off, and nil for one never cached (SHOP-R26)", function()
			local env = newGoods({
				global = {
					goods = {
						["hunts.cover.gold"] = { name = "Gold", slot = "hunts.cover", module = "Hunts", earned = true },
					},
				},
				profile = { appearance = {} },
			})

			assert.are.same(
				{ name = "Gold", slot = "hunts.cover", module = "Hunts", isDefault = false },
				env.goods:GetGood("hunts.cover.gold")
			)
			assert.is_nil(env.goods:GetGood("hunts.cover.none"))
			assert.is_nil(env.goods:GetGood(nil))
		end)
	end)

	describe("the cache", function()
		it("caches every registered good in PagleDB.global.goods, with isEarned()'s result (SHOP-R26)", function()
			local env = newGoods()
			huntsCovers(env, { value = true })
			assert.is_nil(env.goods:RegisterGood("Hunts", {
				id = "hunts.cover.tide",
				slot = "hunts.cover",
				name = "Tide",
				description = "Blue as the Long Wash.",
				icon = 134939,
				tier = 1,
			}))

			assert.are.same({
				["hunts.cover.plain"] = {
					name = "Plain",
					slot = "hunts.cover",
					slotLabel = "Notebook cover",
					category = "Trackers",
					module = "Hunts",
					default = true,
				},
				["hunts.cover.velvet"] = {
					name = "Velvet",
					slot = "hunts.cover",
					slotLabel = "Notebook cover",
					category = "Trackers",
					module = "Hunts",
					tier = 2,
				},
				["hunts.cover.gold"] = {
					name = "Gold",
					slot = "hunts.cover",
					slotLabel = "Notebook cover",
					category = "Trackers",
					module = "Hunts",
					earned = true,
				},
				["hunts.cover.tide"] = {
					name = "Tide",
					slot = "hunts.cover",
					slotLabel = "Notebook cover",
					category = "Trackers",
					module = "Hunts",
					icon = 134939,
					tier = 1,
					description = "Blue as the Long Wash.",
				},
			}, env.db.global.goods)
		end)

		it("keeps a cached good no one registers this session (SHOP-R26)", function()
			local stored = { name = "Old", slot = "hunts.cover", module = "Hunts", tier = 3 }
			local env =
				newGoods({ global = { goods = { ["hunts.cover.old"] = stored } }, profile = { appearance = {} } })
			huntsCovers(env, { value = true })

			assert.are.equal(stored, env.db.global.goods["hunts.cover.old"])
		end)

		it("keeps the earlier cached result when an isEarned() raises (SHOP-R26, SHOP-R31)", function()
			-- `call` as securecallfunction: an error is reported (here dropped) and returns nothing.
			local env = newGoods(nil, function(fn, ...)
				local ok, result = pcall(fn, ...)
				if ok then
					return result
				end
			end)
			local earned = { value = true }
			huntsCovers(env, earned)

			earned.value = nil
			setmetatable(earned, {
				__index = function()
					error("broken")
				end,
			})
			env.goods:Refresh("Hunts")

			assert.is_true(env.db.global.goods["hunts.cover.gold"].earned)
			assert.is_true(env.goods:IsOwned("hunts.cover.gold"))
		end)
	end)

	describe("a Core slot open to earned goods", function()
		-- Core's crest slot, open to earned goods, with Plain its default (SHOP-R23, SHOP-R25), and a Core slot that
		-- isn't open.
		local function coreSlots(env)
			assert.is_nil(
				env.goods:RegisterSlot(
					"Core",
					{ id = "core.crest", label = "Crests", category = "Crests", openToEarned = true }
				)
			)
			assert.is_nil(
				env.goods:RegisterGood(
					"Core",
					{ id = "core.crest.plain", slot = "core.crest", name = "Plain", default = true }
				)
			)
			assert.is_nil(
				env.goods:RegisterSlot("Core", { id = "core.closed", label = "Closed", category = "Announcements" })
			)
		end

		-- The Ledger's earned crest `id` in Core's crest slot, its isEarned returning `earned.value`.
		local function crest(earned, fields)
			local good = {
				id = "ledger.crest.elwynn",
				slot = "core.crest",
				name = "The Old Oak",
				icon = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn",
				isEarned = function()
					return earned.value
				end,
				earnedText = "Master of the forest",
			}
			for key, value in pairs(fields or {}) do
				if value == false then
					good[key] = nil
				else
					good[key] = value
				end
			end
			return good
		end

		it("takes another Module's earned good, cached as that Module's (SHOP-R23, SHOP-R26)", function()
			local env = newGoods()
			coreSlots(env)

			assert.is_nil(env.goods:RegisterGood("Ledger", crest({ value = true })))

			local ids = {}
			for i, good in ipairs(env.goods:GoodsOf("core.crest")) do
				ids[i] = good.id .. " " .. good.module
			end
			assert.are.same({ "core.crest.plain Core", "ledger.crest.elwynn Ledger" }, ids)
			assert.are.same({ "Ledger", "core.crest", "Crests", true }, {
				env.db.global.goods["ledger.crest.elwynn"].module,
				env.db.global.goods["ledger.crest.elwynn"].slot,
				env.db.global.goods["ledger.crest.elwynn"].slotLabel,
				env.db.global.goods["ledger.crest.elwynn"].earned,
			})
			assert.are.equal("Ledger", env.goods:GetGood("ledger.crest.elwynn").module)
			assert.is_true(env.goods:IsOwned("ledger.crest.elwynn"))
			assert.is_true(env.goods:SetEquipped("core.crest", "ledger.crest.elwynn"))
			assert.are.equal("ledger.crest.elwynn", env.goods:GetEquipped("core.crest"))
		end)

		local isEarned = function()
			return true
		end
		local refused = {
			{
				"a good for sale",
				"Ledger",
				crest({ value = true }, { isEarned = false, earnedText = false, tier = 1 }),
			},
			{
				"a default",
				"Ledger",
				crest({ value = true }, { isEarned = false, earnedText = false, default = true }),
			},
			{ "an earned default", "Ledger", crest({ value = true }, { default = true }) },
			{ "an earned good for sale", "Ledger", crest({ value = true }, { tier = 2 }) },
			{
				"an earned good in a Core slot not open",
				"Ledger",
				crest({ value = true }, { slot = "core.closed" }),
			},
			{
				"an earned good without its Module's prefix",
				"Ledger",
				crest({ value = true }, { id = "core.crest.oak" }),
			},
			{
				"an earned good in a Module's slot",
				"Hunts",
				{ id = "hunts.oak", slot = "ledger.binding", name = "Oak", isEarned = isEarned },
			},
			{
				"an earned good in a Module's slot registered open",
				"Hunts",
				{ id = "hunts.oak", slot = "ledger.open", name = "Oak", isEarned = isEarned },
			},
			{
				"an earnedText that is neither a string nor a function",
				"Ledger",
				crest({ value = true }, { earnedText = 3 }),
			},
		}
		for _, case in ipairs(refused) do
			it("still refuses " .. case[1] .. ", registering and caching nothing (SHOP-R23)", function()
				local env = newGoods()
				coreSlots(env)
				env.goods:RegisterSlot(
					"Ledger",
					{ id = "ledger.binding", label = "Journal binding", category = "Books" }
				)
				-- openToEarned is Core's alone: on a Module's slot it opens nothing.
				env.goods:RegisterSlot(
					"Ledger",
					{ id = "ledger.open", label = "Open", category = "Books", openToEarned = true }
				)

				assert.is_string(env.goods:RegisterGood(case[2], case[3]))
				assert.is_nil(env.db.global.goods[case[3].id])
				assert.are.same({ 1, 0, 0 }, {
					#env.goods:GoodsOf("core.crest"),
					#env.goods:GoodsOf("core.closed"),
					#env.goods:GoodsOf("ledger.open"),
				})
			end)
		end

		it(
			"puts a Module's earned sound set in Core's slot away with its Module off, the slot falling back to its"
				.. " default, and brings it back with it (SHOP-R23, SHOP-R32, SHOP-R35)",
			function()
				local env = newGoods()
				local goods = env.goods
				assert.is_nil(goods:RegisterSlot("Core", {
					id = "core.soundset",
					label = "Sound set",
					category = "Announcements",
					openToEarned = true,
				}))
				assert.is_nil(
					goods:RegisterGood(
						"Core",
						{ id = "core.soundset.driftwood", slot = "core.soundset", name = "Driftwood", default = true }
					)
				)
				assert.is_nil(goods:RegisterGood("Hunts", {
					id = "hunts.soundset.nightwatch",
					slot = "core.soundset",
					name = "Night Watch",
					isEarned = function()
						return true
					end,
					earnedText = "Finish every Hunt set",
				}))
				assert.is_true(goods:SetEquipped("core.soundset", "hunts.soundset.nightwatch"))

				env.on.Hunts = nil
				local off = { goods:GetEquipped("core.soundset"), goods:IsOwned("hunts.soundset.nightwatch") }
				env.on.Hunts = 20

				assert.are.same({ "core.soundset.driftwood", true }, off)
				assert.are.same({ "hunts.soundset.nightwatch", "hunts.soundset.nightwatch" }, {
					goods:GetEquipped("core.soundset"),
					env.db.profile.appearance["core.soundset"],
				})
				assert.are.equal(ns.SOUND_SETS["core.soundset.driftwood"], ns.SoundSetOf(off[1]))
			end
		)

		it("says the slot is Core's when it refuses a Module's good for sale there (SHOP-R23)", function()
			local env = newGoods()
			coreSlots(env)

			assert.are.equal(
				"M:RegisterGood: ledger.crest.elwynn's slot core.crest is Core's",
				env.goods:RegisterGood(
					"Ledger",
					crest({ value = true }, { isEarned = false, earnedText = false, tier = 1 })
				)
			)
		end)

		it(
			"puts the good away while its Module is off: the slot falls back to its default, and lists it no more (SHOP-R32, SHOP-R33, SHOP-R90)",
			function()
				local env = newGoods()
				coreSlots(env)
				env.goods:RegisterGood("Ledger", crest({ value = true }))
				env.goods:Start()
				env.goods:SetEquipped("core.crest", "ledger.crest.elwynn")
				env.fired = {}

				env.on.Ledger = nil
				env.goods:Settle()
				local off = { env.goods:GetEquipped("core.crest"), #env.goods:GoodsOf("core.crest") }
				local owned = env.goods:IsOwned("ledger.crest.elwynn")
				env.on.Ledger = 10
				env.goods:Settle()

				assert.are.same({ "core.crest.plain", 1 }, off)
				assert.is_true(owned) -- still owned, from the cache (SHOP-R30)
				assert.are.equal("ledger.crest.elwynn", env.goods:GetEquipped("core.crest"))
				assert.are.same({
					{ "AppearanceChanged", "core.crest", "core.crest.plain" },
					{ "AppearanceChanged", "core.crest", "ledger.crest.elwynn" },
				}, env.fired)
			end
		)
	end)

	describe("an earned good's texts", function()
		it("are its earnedText string, for the row and the stage alike (SHOP-R22)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			assert.are.same({ "Every Hunt done", "Every Hunt done" }, { env.goods:EarnedTexts("hunts.cover.gold") })
		end)

		it(
			"come from its earnedText function each time they are asked for while it isn't owned, never at registration, Refresh or an ownership check (SHOP-R22, SHOP-R30)",
			function()
				local env = newGoods()
				local calls, texts = 0, { "Expert · 88%", "Earned when the forest reaches Master." }
				assert.is_nil(
					env.goods:RegisterSlot("Ledger", { id = "ledger.book", label = "Book", category = "Books" })
				)
				assert.is_nil(
					env.goods:RegisterGood(
						"Ledger",
						{ id = "ledger.book.plain", slot = "ledger.book", name = "Plain", default = true }
					)
				)
				assert.is_nil(env.goods:RegisterGood("Ledger", {
					id = "ledger.book.oak",
					slot = "ledger.book",
					name = "Oak",
					isEarned = function()
						return false
					end,
					earnedText = function()
						calls = calls + 1
						return texts[1], texts[2]
					end,
				}))
				env.goods:Refresh("Ledger")
				env.goods:IsOwned("ledger.book.oak")
				env.goods:OwnedOf("ledger.book")
				assert.are.equal(0, calls)

				local first = { env.goods:EarnedTexts("ledger.book.oak") }
				texts = { "Master · 100%" }
				local second = { env.goods:EarnedTexts("ledger.book.oak") }

				assert.are.same({ "Expert · 88%", "Earned when the forest reaches Master." }, first)
				assert.are.same({ "Master · 100%" }, second) -- a stage note only when it gives one
				assert.are.equal(2, calls)
				assert.is_nil(env.db.global.goods["ledger.book.oak"].earnedText) -- never cached (SHOP-R26)

				env.goods:SetPurchased({ ["ledger.book.oak"] = true }) -- owned now: the function isn't called
				assert.are.same({}, { env.goods:EarnedTexts("ledger.book.oak") })
				assert.are.equal(2, calls)
			end
		)

		it("are nothing when the function raises, which is reported, or gives what isn't text (SHOP-R22)", function()
			-- `call` as securecallfunction: an error is reported (here noted) and returns nothing.
			local errors = 0
			local env = newGoods(nil, function(fn, ...)
				local ok, result = pcall(fn, ...)
				if ok then
					return result
				end
				errors = errors + 1
			end)
			local give
			env.goods:RegisterSlot("Ledger", { id = "ledger.book", label = "Book", category = "Books" })
			env.goods:RegisterGood(
				"Ledger",
				{ id = "ledger.book.plain", slot = "ledger.book", name = "Plain", default = true }
			)
			env.goods:RegisterGood("Ledger", {
				id = "ledger.book.oak",
				slot = "ledger.book",
				name = "Oak",
				isEarned = function()
					return false
				end,
				earnedText = function()
					return give()
				end,
			})

			give = function()
				error("broken")
			end
			local raised = { env.goods:EarnedTexts("ledger.book.oak") }
			give = function()
				return 3, ""
			end
			local odd = { env.goods:EarnedTexts("ledger.book.oak") }

			assert.are.same({}, raised)
			assert.are.equal(1, errors)
			assert.are.same({}, odd)
		end)

		it("are nothing for a good that isn't earned, or isn't registered (SHOP-R22)", function()
			local env = newGoods()
			huntsCovers(env, { value = false })

			assert.are.same({}, { env.goods:EarnedTexts("hunts.cover.velvet") })
			assert.are.same({}, { env.goods:EarnedTexts("hunts.cover.none") })
		end)
	end)
end)
