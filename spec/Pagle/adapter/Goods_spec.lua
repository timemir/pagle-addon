-- The goods registry as Core runs it, through the real TOC (wallet-and-shop.md › Goods, Owning and equipping,
-- SHOP-R20–R26, SHOP-R30–R33, SHOP-R90): M:RegisterSlot, M:RegisterGood, M:RefreshGoods, Pagle.IsOwned,
-- Pagle.GetEquipped, Pagle.SetEquipped, Pagle.GetGood, AppearanceChanged, PagleDB.global.goods and
-- PagleDB.profile.appearance.

-- Hunts' notebook cover slot on its handle: a default, a tier-2 good and an earned good whose isEarned() returns
-- `earned.value`.
---@param hunts table the Hunts handle
---@param earned { value: boolean }
local function registerCovers(hunts, earned)
	hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
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
local function huntsCore(saved, earned, noCovers)
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
		local loaded = huntsCore(nil, { value = true })
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
			category = "Trackers",
			module = "Hunts",
			icon = 134939,
			tier = 2,
		}, loaded.env.PagleDB.global.goods["hunts.cover.velvet"])
		assert.is_true(loaded.env.PagleDB.global.goods["hunts.cover.gold"].earned)
	end)

	for _, case in ipairs({
		{ "a duplicate slot", "RegisterSlot", { id = "hunts.cover", label = "Cover", category = "Trackers" } },
		{ "a slot without the prefix", "RegisterSlot", { id = "cover", label = "Cover", category = "Trackers" } },
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
			local loaded, hunts = huntsCore()
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
		local loaded, hunts = huntsCore()
		local ledger = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

		assert.has_error(function()
			ledger:RegisterGood({ id = "ledger.cover", slot = "hunts.cover", name = "Cover", tier = 1 })
		end, "M:RegisterGood: ledger.cover's slot hunts.cover is Hunts's")
		assert.is_not_nil(hunts)
	end)

	it("are handle methods: called on anything else, they raise an error (CORE-R12)", function()
		local loaded, hunts = huntsCore()

		assert.has_error(function()
			hunts.RegisterSlot({}, { id = "hunts.frame", label = "Frame", category = "Trackers" })
		end)
		assert.has_error(function()
			hunts.RefreshGoods({})
		end)
		assert.is_nil(loaded.env.Pagle.GetEquipped("hunts.frame"))
	end)

	it("report a slot with no default at ModulesChanged; its first good stands in (SHOP-R23, CORE-R19)", function()
		local loaded, hunts = huntsCore()
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
			local loaded, hunts = huntsCore(nil, earned)
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
		local loaded, hunts = huntsCore(nil, earned)
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
			local loaded = huntsCore(nil, { value = true })
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
		local loaded = huntsCore(nil, { value = false })
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
			huntsCore({ profiles = { Default = { appearance = { ["hunts.cover"] = "hunts.cover.velvet" } } } })
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
			local first = huntsCore(nil, { value = true })
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
			local on = huntsCore(off.env.PagleDB, { value = true })
			on.client.fire("PLAYER_LOGIN")
			assert.are.equal("hunts.cover.gold", on.env.Pagle.GetEquipped("hunts.cover"))
		end
	)
end)

describe("Pagle.GetGood", function()
	it("reads a good's cached name, slot, icon, Module and description (SHOP-R26, LED-R112)", function()
		local loaded = huntsCore()

		assert.are.same({
			name = "Velvet",
			slot = "hunts.cover",
			icon = 134939,
			module = "Hunts",
			isDefault = false,
			kind = "sale",
			tier = 2,
			price = 400,
			purchased = false,
		}, loaded.env.Pagle.GetGood("hunts.cover.velvet"))
		assert.is_nil(loaded.env.Pagle.GetGood("hunts.cover.none"))
	end)
end)

describe("Core's own goods", function()
	it("register with the core. prefix, listed before every Module's, and raise at Core's call (SHOP-R21)", function()
		local loaded = huntsCore()
		local ns = loaded.ns

		-- Core's four slots (SHOP-R25) are in already, from login step 1 (spec/Pagle/adapter/CoreGoods_spec.lua).
		ns.RegisterCoreSlot({ id = "core.frame", label = "Tracker frame", category = "Trackers" })
		ns.RegisterCoreGood({ id = "core.frame.plain", slot = "core.frame", name = "Plain", default = true })
		local ok, err = pcall(function()
			ns.RegisterCoreGood({ id = "hunts.frame", slot = "core.frame", name = "Frame", tier = 1 })
		end)
		loaded.client.fire("PLAYER_LOGIN")

		assert.is_false(ok)
		assert.matches("Goods_spec.lua:%d+: M:RegisterGood: hunts.frame doesn't start with core.", tostring(err))
		assert.are.same({ "core.frame", "hunts.cover" }, {
			ns.goods:Slots()[5].id,
			ns.goods:Slots()[6].id,
		})
		assert.are.equal("Core", loaded.env.Pagle.GetGood("core.frame.plain").module)
		assert.are.equal("core.frame.plain", loaded.env.Pagle.GetEquipped("core.frame"))
	end)
end)

describe("What a view of every good reads (SHOP-R36)", function()
	-- Core with Hunts (order 20) and, unless `noLedger`, the Ledger (order 10) with an earned good in Core's crest
	-- slot that has a count and a fallback price from `options.from`, logged in.
	local function viewed(options)
		options = options or {}
		local loaded, hunts = huntsCore(options.saved, options.earned, options.noCovers)
		local ledger
		if not options.noLedger then
			ledger = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			ledger:RegisterGood({
				id = "ledger.crest.elwynn",
				slot = "core.crest",
				name = "The Old Oak",
				group = "zone",
				isEarned = function()
					return false
				end,
				earnedText = function()
					return "Expert · 88%", "Earned when Elwynn reaches Master."
				end,
				earnedCount = function()
					return 12, 25
				end,
				fallbackTier = options.from and 4 or nil,
				fallbackFrom = options.from,
			})
		end
		loaded.client.fire("PLAYER_LOGIN")
		return loaded, hunts, ledger
	end

	describe("Pagle.GetSlots", function()
		it(
			"lists every slot of Core and the Modules On, Core's first, then by Module order, as fresh copies",
			function()
				local loaded = viewed()
				local Pagle = loaded.env.Pagle
				loaded.ns.RegisterCoreSlot({
					id = "core.frame",
					label = "Frame",
					category = "Trackers",
					groups = { { key = "a", name = "A frames" } },
				})

				local slots = Pagle.GetSlots()

				local ids = {}
				for i, slot in ipairs(slots) do
					ids[i] = slot.id
				end
				assert.are.same(
					{ "core.toaststyle", "core.soundset", "core.crest", "core.binding", "core.frame", "hunts.cover" },
					ids
				)
				assert.are.same(
					{ id = "hunts.cover", label = "Notebook cover", category = "Trackers", module = "Hunts" },
					slots[6]
				)
				assert.are.same({
					id = "core.frame",
					label = "Frame",
					category = "Trackers",
					module = "Core",
					groups = { { key = "a", name = "A frames" } },
				}, slots[5])
				assert.are.same(
					{ { key = "zone", name = "Zone crests" }, { key = "fish", name = "Fish crests" } },
					slots[3].groups
				)
				slots[3].groups[1].name = "Changed"
				slots[3].label = "Changed"
				assert.are.same("Zone crests", Pagle.GetSlots()[3].groups[1].name)
				assert.are.same("Crests", Pagle.GetSlots()[3].label)
			end
		)

		it("leaves out a Module's slots while it isn't On (SHOP-R35)", function()
			local loaded = loadCore()
			loaded.client.fire("PLAYER_LOGIN")

			local ids = {}
			for i, slot in ipairs(loaded.env.Pagle.GetSlots()) do
				ids[i] = slot.id
			end

			assert.are.same({ "core.toaststyle", "core.soundset", "core.crest", "core.binding" }, ids)
		end)
	end)

	describe("Pagle.GetSlotGoods", function()
		it("lists every good of a slot, the earned ones too, in registration order (SHOP-R21)", function()
			local loaded = viewed({ earned = { value = true } })
			local Pagle = loaded.env.Pagle

			assert.are.same(
				{ "hunts.cover.plain", "hunts.cover.velvet", "hunts.cover.gold" },
				Pagle.GetSlotGoods("hunts.cover")
			)
			local crests = Pagle.GetSlotGoods("core.crest")
			assert.are.equal("core.crest.plain", crests[1])
			assert.are.equal("ledger.crest.elwynn", crests[#crests])
			assert.is_true(#crests > 2) -- Core's fish crests among them, earned and unlisted by the shop
		end)

		it(
			"gives another Module's good in a Core slot only while that Module is On, and nothing for an unknown slot",
			function()
				local on = viewed()
				local off = viewed({ noLedger = true })

				assert.is_truthy(
					table.concat(on.env.Pagle.GetSlotGoods("core.crest"), " "):find("ledger.crest.elwynn", 1, true)
				)
				assert.is_nil(
					table.concat(off.env.Pagle.GetSlotGoods("core.crest"), " "):find("ledger.crest.elwynn", 1, true)
				)
				assert.are.same({}, on.env.Pagle.GetSlotGoods("nobody.slot"))
			end
		)
	end)

	describe("Pagle.GetGood", function()
		it("gives an earned good's kind, group and fallback, and its price only from its date on (SHOP-R28)", function()
			local from = SERVER_TIME + 1000
			local loaded = viewed({ from = from })
			local Pagle = loaded.env.Pagle

			local before = Pagle.GetGood("ledger.crest.elwynn")
			assert.are.same(
				{ "earned", "zone", 3000, from, nil },
				{ before.kind, before.group, before.fallbackPrice, before.fallbackFrom, before.price }
			)
			loaded.client.advance(1000)
			assert.are.equal(3000, Pagle.GetGood("ledger.crest.elwynn").price)
		end)

		it("tells a default, a good for sale and a crate-only good apart (SHOP-R22, SHOP-R50)", function()
			local loaded = viewed()
			local Pagle = loaded.env.Pagle

			assert.are.same({ "default", "sale", "crate" }, {
				Pagle.GetGood("core.toaststyle.page").kind,
				Pagle.GetGood("core.toaststyle.ripple").kind,
				Pagle.GetGood("core.toaststyle.foil").kind,
			})
		end)

		it(
			"gives purchased and ownedAt from a purchase entry, and from the crate that gave a good (SHOP-R11, SHOP-R50)",
			function()
				local entries = history(2)
				entries[#entries + 1] = purchaseEntry(SERVER_TIME - 3000, "hunts.cover.velvet", 150)
				entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, "core.crate", 3000)
				local loaded = loadCore(entries)
				registerCovers(
					loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 }),
					{ value = false }
				)
				loaded.client.fire("PLAYER_LOGIN")
				enterWorld(loaded, 4)
				local Pagle = loaded.env.Pagle
				local given = assert(loaded.ns.walletSnapshot.crates[1], "the crate gave a good")

				local crated = Pagle.GetGood(given)
				assert.are.same({ true, SERVER_TIME - 2000 }, { crated.purchased, crated.ownedAt })
				local bought = Pagle.GetGood("hunts.cover.velvet")
				assert.are.same({ true, SERVER_TIME - 3000 }, { bought.purchased, bought.ownedAt })
				local plain = Pagle.GetGood("core.toaststyle.page")
				assert.are.same({ false, nil }, { plain.purchased, plain.ownedAt })
			end
		)
	end)

	describe("Pagle.GetEarnedProgress", function()
		it("gives tag, note, have and need for an earned good not yet owned, read afresh at each call", function()
			local loaded, _, ledger = viewed()
			local Pagle = loaded.env.Pagle
			assert(ledger)

			assert.are.same(
				{ tag = "Expert · 88%", note = "Earned when Elwynn reaches Master.", have = 12, need = 25 },
				Pagle.GetEarnedProgress("ledger.crest.elwynn")
			)
		end)

		it("gives nothing for a good for sale, a default, an unknown good, or one of a Module that is off", function()
			local loaded = viewed()
			local Pagle = loaded.env.Pagle

			assert.is_nil(Pagle.GetEarnedProgress("core.toaststyle.ripple"))
			assert.is_nil(Pagle.GetEarnedProgress("core.toaststyle.page"))
			assert.is_nil(Pagle.GetEarnedProgress("nobody.nothing"))
			assert.is_nil(viewed({ noLedger = true }).env.Pagle.GetEarnedProgress("ledger.crest.elwynn"))
		end)

		it("gives nothing for an earned good already owned", function()
			local loaded, _, ledger = viewed()
			local Pagle = loaded.env.Pagle
			assert(ledger)
			loaded.ns.goods:Good("ledger.crest.elwynn").isEarned = function()
				return true
			end
			ledger:RefreshGoods()

			assert.is_nil(Pagle.GetEarnedProgress("ledger.crest.elwynn"))
		end)

		it("reports an earnedCount that raises through the error handler and gives nothing (SHOP-R22)", function()
			local loaded = viewed()
			loaded.ns.goods:Good("ledger.crest.elwynn").earnedCount = function()
				error("count broke")
			end

			assert.is_nil(loaded.env.Pagle.GetEarnedProgress("ledger.crest.elwynn"))

			assert.are.equal(1, #loaded.client.errors)
			assert.matches("count broke", loaded.client.errors[1])
		end)
	end)

	describe("Pagle.GetPutAwayGoods", function()
		it("lists the owned goods of a Module that is off, earned ones too, never a default (SHOP-R35)", function()
			local loaded = loadCore(nil, {
				global = {
					goods = {
						["hunts.cover.plain"] = {
							name = "Plain",
							slot = "hunts.cover",
							module = "Hunts",
							default = true,
						},
						["hunts.cover.velvet"] = { name = "Velvet", slot = "hunts.cover", module = "Hunts", tier = 2 },
						["hunts.cover.gold"] = { name = "Gold", slot = "hunts.cover", module = "Hunts", earned = true },
						["hunts.cover.tide"] = { name = "Tide", slot = "hunts.cover", module = "Hunts", tier = 1 },
					},
				},
			})
			loaded.client.fire("PLAYER_LOGIN")
			loaded.ns.goods:SetPurchased({ ["hunts.cover.velvet"] = true })

			assert.are.same({ "hunts.cover.gold", "hunts.cover.velvet" }, loaded.env.Pagle.GetPutAwayGoods())
		end)
	end)

	describe("Pagle.DrawGoodPreview", function()
		-- Draws `goodID` on a new 185 x 66 frame at `size`; returns the frame and what it made on it.
		local function drawn(loaded, goodID, size)
			local frame = loaded.env.CreateFrame("Frame")
			frame:SetSize(185, 66)
			loaded.env.Pagle.DrawGoodPreview(frame, goodID, size)
			return frame, frame.children[1]
		end

		it("draws a good's preview at the stage's 370 x 132, centred, standing at its own scale", function()
			local drawnOn = {}
			local loaded, hunts = viewed({ noCovers = true })
			hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
			hunts:RegisterGood({
				id = "hunts.cover.plain",
				slot = "hunts.cover",
				name = "Plain",
				default = true,
				preview = function(stage)
					drawnOn[#drawnOn + 1] = stage
				end,
			})

			local _, box = drawn(loaded, "hunts.cover.plain", "stage")

			assert.are.same({ 370, 132 }, { box:GetSize() })
			assert.are.same({ "CENTER" }, { (box:GetPoint()) })
			assert.are.equal(1, box:GetScale())
			assert.are.equal(1, #drawnOn)
			assert.are.equal(box, drawnOn[1]:GetParent())
		end)

		it("scales the same stage to fit the frame at the card size", function()
			local loaded = viewed()

			local _, box = drawn(loaded, "hunts.cover.velvet", "card")

			assert.are.same({ 370, 132 }, { box:GetSize() })
			assert.are.equal(0.5, box:GetScale()) -- 185 x 66 over 370 x 132
		end)

		it("draws a good with no preview as its icon in a medallion (SHOP-R36)", function()
			local loaded = viewed()

			local _, box = drawn(loaded, "hunts.cover.velvet", "stage")

			assert.is_true(box.swatch:IsShown())
			assert.are.equal(134939, box.swatch.Icon.texture)
		end)

		it("draws a good put away from its cached icon, greyed, and a good never registered as nothing", function()
			local loaded = loadCore(nil, {
				global = {
					goods = {
						["hunts.cover.velvet"] = {
							name = "Velvet",
							slot = "hunts.cover",
							module = "Hunts",
							icon = 134939,
							tier = 2,
						},
					},
				},
			})
			loaded.client.fire("PLAYER_LOGIN")

			local _, box = drawn(loaded, "hunts.cover.velvet", "stage")
			assert.is_true(box.swatch.Icon:IsDesaturated())
			assert.is_true(box.swatch:IsShown())
			local frame = loaded.env.CreateFrame("Frame")
			loaded.env.Pagle.DrawGoodPreview(frame, "hunts.cover.none", "card")
			assert.is_false(frame.children[1].swatch:IsShown())
		end)

		it("draws another good on the same frame in place of the last, which it hides", function()
			local loaded = viewed()
			local frame = loaded.env.CreateFrame("Frame")
			local Pagle = loaded.env.Pagle

			Pagle.DrawGoodPreview(frame, "core.toaststyle.page", "stage")
			local box = frame.children[1]
			local first = box.previews["core.toaststyle.page"]
			Pagle.DrawGoodPreview(frame, "core.soundset.driftwood", "stage")

			assert.are.equal(1, #frame.children, "one box per frame")
			assert.is_false(first:IsShown())
			assert.is_true(box.previews["core.soundset.driftwood"]:IsShown())
		end)

		it("raises an error at the caller for a size other than stage or card, and for no frame", function()
			local loaded = viewed()
			local frame = loaded.env.CreateFrame("Frame")

			assert.matches(
				'Goods_spec.lua:%d+: Pagle.DrawGoodPreview: size is "stage" or "card"',
				select(
					2,
					pcall(function()
						loaded.env.Pagle.DrawGoodPreview(frame, "hunts.cover.velvet", "wide")
					end)
				)
			)
			assert.matches(
				"Goods_spec.lua:%d+: Pagle.DrawGoodPreview takes a frame",
				select(
					2,
					pcall(function()
						loaded.env.Pagle.DrawGoodPreview(nil, "hunts.cover.velvet", "stage")
					end)
				)
			)
		end)
	end)
end)
