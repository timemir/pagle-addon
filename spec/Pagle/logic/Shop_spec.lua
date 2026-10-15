-- The Curio Shop as data (wallet-and-shop.md › UI, SHOP-R22, SHOP-R30, SHOP-R35, SHOP-R40): the purse, the list
-- and the stage, built by ns.NewShopModel over Core's real goods registry and wallet, here FakePagle's.

local COIN = " |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"

-- A FakePagle with the Ledger (order 10) and Hunts (order 20) On, unless `off` names one to leave unregistered, and
-- Core's own slots and goods, as Core registers them (SHOP-R25), named by their IDs until their lore lands; nothing
-- logged in yet. Returns the fake and the handles, by def.name.
local function session(off)
	local fake = newFakePagle()
	local handles = {}
	for _, def in ipairs({ { name = "Ledger", order = 10 }, { name = "Hunts", order = 20 } }) do
		if def.name ~= off then
			handles[def.name] = fake.Pagle.RegisterModule({ name = def.name, title = def.name, order = def.order })
		end
	end
	return fake, handles
end

-- Core's own slots (SHOP-R25) as the list outlines them while nothing of Core's is bought and the balance is under
-- 150: each default in use, everything else priced in red.
local CORE_UNBOUGHT = {
	"Toast style (1/3)",
	"  core.toaststyle.timber In use",
	"  core.toaststyle.ripple 150" .. COIN .. " [red]",
	"  core.toaststyle.lanternglow 400" .. COIN .. " [red]",
	"Sound set (1/2)",
	"  core.soundset.driftwood In use",
	"  core.soundset.gilded 400" .. COIN .. " [red]",
	"Bookplate crest (1/4)",
	"  core.crest.plain In use",
	"  core.crest.crest1 150" .. COIN .. " [red]",
	"  core.crest.crest2 400" .. COIN .. " [red]",
	"  core.crest.crest3 900" .. COIN .. " [red]",
}

-- CORE_UNBOUGHT, then `lines`.
local function afterCore(lines)
	local all = {}
	for _, line in ipairs(CORE_UNBOUGHT) do
		all[#all + 1] = line
	end
	for _, line in ipairs(lines) do
		all[#all + 1] = line
	end
	return all
end

-- Hunts' notebook covers on its handle: Plain (default), Velvet (tier 2, icon 134939, a description) and Gold (earned
-- while `earned.value`, "Every Hunt done").
local function huntsCovers(hunts, earned)
	hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Hunts" })
	hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
	hunts:RegisterGood({
		id = "hunts.cover.velvet",
		slot = "hunts.cover",
		name = "Velvet",
		tier = 2,
		icon = 134939,
		description = "Soft to the touch.",
	})
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

-- The Ledger's binding slot: Oak (default) and Lapis (tier 3).
local function ledgerBindings(ledger)
	ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Fish Journal" })
	ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
	ledger:RegisterGood({ id = "ledger.binding.lapis", slot = "ledger.binding", name = "Lapis", tier = 3 })
end

-- The shop's model now, as Core builds it (ns.ShopModel): over the fake's goods, cache, Modules On, balance and
-- projections.
local function model(fake)
	return fake.ns.ShopModel(breakUpLargeNumbers)
end

describe("The shop's purse", function()
	it(
		"shows the balance, a segment per Module that reported Coins in roster order with its share, and who pays"
			.. " none (wallet-and-shop.md › UI)",
		function()
			local fake, handles = session()
			handles.Hunts:ReportCoinsEarned(500)
			handles.Ledger:ReportCoinsEarned(1500)
			fake.setSpent(150)

			local purse = model(fake):Purse()

			assert.are.equal("1,850", purse.balance)
			assert.are.equal("Pagle Coins", purse.label)
			assert.are.equal("Stats and QoL pay none", purse.payNone)
			assert.are.same({
				{
					module = "Ledger",
					share = 0.75,
					off = false,
					legend = "Ledger 1,500",
					tooltip = { "Ledger", "1,500 Coins all time" },
				},
				{
					module = "Hunts",
					share = 0.25,
					off = false,
					legend = "Hunts 500",
					tooltip = { "Hunts", "500 Coins all time" },
				},
			}, purse.segments)
		end
	)

	it(
		"marks an off Module's segment, whose total still counts, and names it by its title (SHOP-R3, CORE-R41)",
		function()
			local fake = session("Hunts")
			fake.global.coins.earned.TackleBoard = 300
			fake.global.coins.earned.Ledger = 100

			local purse = model(fake):Purse()

			assert.are.equal("400", purse.balance)
			assert.are.same({ "Ledger", "TackleBoard" }, { purse.segments[1].module, purse.segments[2].module })
			assert.is_false(purse.segments[1].off)
			local board = purse.segments[2]
			assert.is_true(board.off)
			assert.are.equal(0.75, board.share)
			assert.are.equal("Tackle Board 300", board.legend)
			assert.are.same(
				{ "Tackle Board", "300 Coins all time", "Off: pays nothing new, keeps what it paid." },
				board.tooltip
			)
		end
	)

	it("has no segment before any Module reports, and never says Spent (wallet-and-shop.md › UI)", function()
		local fake = session()
		fake.setSpent(50)

		local purse = model(fake):Purse()

		assert.are.same({}, purse.segments)
		assert.are.equal("0", purse.balance)
		assert.is_true(purse.held)
		for _, text in pairs({ purse.label, purse.payNone, purse.balance }) do
			assert.falsy(text:find("Spent", 1, true))
		end
	end)
end)

-- Each group's label and owned count, and its rows as "<id> <tag or price>", from a list.
local function outline(groups)
	local lines = {}
	for _, group in ipairs(groups) do
		lines[#lines + 1] = ("%s (%s)"):format(group.label, group.count or group.note)
		for _, row in ipairs(group.rows) do
			lines[#lines + 1] = ("  %s %s%s"):format(row.id, row.tag or row.price, row.short and " [red]" or "")
		end
	end
	return lines
end

describe("The shop's list", function()
	-- The session the list specs share: Core's toast styles, Hunts' covers (Gold not yet earned) and the Ledger's
	-- bindings, logged in, with a balance of 300 and Ripple bought and in use.
	local function shopping()
		local fake, handles = session()
		huntsCovers(handles.Hunts, { value = false })
		ledgerBindings(handles.Ledger)
		fake.login()
		handles.Ledger:ReportCoinsEarned(450)
		fake.setSpent(150)
		fake.setPurchased({ ["core.toaststyle.ripple"] = true })
		assert.is_true(fake.Pagle.SetEquipped("core.toaststyle", "core.toaststyle.ripple"))
		return fake, handles
	end

	it(
		"groups goods by slot, Core's first then by Module order, with owned counts, each row's state"
			.. " (wallet-and-shop.md › UI)",
		function()
			local fake = shopping()

			assert.are.same({
				"Toast style (2/3)",
				"  core.toaststyle.timber default",
				"  core.toaststyle.ripple In use",
				"  core.toaststyle.lanternglow 400" .. COIN .. " [red]",
				"Sound set (1/2)",
				"  core.soundset.driftwood In use",
				"  core.soundset.gilded 400" .. COIN .. " [red]",
				"Bookplate crest (1/4)",
				"  core.crest.plain In use",
				"  core.crest.crest1 150" .. COIN,
				"  core.crest.crest2 400" .. COIN .. " [red]",
				"  core.crest.crest3 900" .. COIN .. " [red]",
				"Journal binding (1/2)",
				"  ledger.binding.oak In use",
				"  ledger.binding.lapis 900" .. COIN .. " [red]",
				"Notebook cover (1/3)",
				"  hunts.cover.plain In use",
				"  hunts.cover.velvet 400" .. COIN .. " [red]",
				"  hunts.cover.gold Every Hunt done",
			}, outline(model(fake):List({})))
		end
	)

	it(
		"prices a good the balance covers in white, with its name and icon on the row (wallet-and-shop.md › UI)",
		function()
			local fake, handles = shopping()
			handles.Ledger:ReportCoinsEarned(1000)

			local rows = model(fake):List({ category = "Hunts" })[1].rows

			assert.are.same(
				{ id = "hunts.cover.velvet", name = "Velvet", icon = 134939, state = "forSale", price = "400" .. COIN },
				rows[2]
			)
		end
	)

	it("matches the search against names, ignoring case (wallet-and-shop.md › UI)", function()
		local fake = shopping()

		assert.are.same({
			"Journal binding (1/2)",
			"  ledger.binding.lapis 900" .. COIN .. " [red]",
		}, outline(model(fake):List({ search = "LaPi" })))
		assert.are.same({
			"Bookplate crest (1/4)",
			"  core.crest.plain In use",
			"Notebook cover (1/3)",
			"  hunts.cover.plain In use",
		}, outline(model(fake):List({ search = "plain" })))
		assert.are.same({}, model(fake):List({ search = "binding" }), "names only, not the slot's label")
	end)

	it("filters All, Owned, Not owned and Can afford (wallet-and-shop.md › UI)", function()
		local fake, handles = shopping()
		handles.Ledger:ReportCoinsEarned(700)

		local function ids(filter)
			local list = {}
			for _, group in ipairs(model(fake):List({ filter = filter })) do
				for _, row in ipairs(group.rows) do
					list[#list + 1] = row.id
				end
			end
			return list
		end

		assert.are.equal(14, #ids("all"))
		assert.are.same({
			"core.toaststyle.timber",
			"core.toaststyle.ripple",
			"core.soundset.driftwood",
			"core.crest.plain",
			"ledger.binding.oak",
			"hunts.cover.plain",
		}, ids("owned"))
		assert.are.same({
			"core.toaststyle.lanternglow",
			"core.soundset.gilded",
			"core.crest.crest1",
			"core.crest.crest2",
			"core.crest.crest3",
			"ledger.binding.lapis",
			"hunts.cover.velvet",
			"hunts.cover.gold",
		}, ids("notOwned"))
		assert.are.same({
			"core.toaststyle.lanternglow",
			"core.soundset.gilded",
			"core.crest.crest1",
			"core.crest.crest2",
			"hunts.cover.velvet",
		}, ids("canAfford"))
	end)

	it(
		"shows a chip for each category a live slot uses, in SHOP's order, and narrows to one (wallet-and-shop.md › UI)",
		function()
			local fake = shopping()
			local shop = model(fake)

			assert.are.same({
				{ category = "Announcements", label = "Announcements" },
				{ category = "Bookplate", label = "Bookplate" },
				{ category = "Fish Journal", label = "Fish Journal" },
				{ category = "Hunts", label = "Hunts" },
			}, shop:Chips())
			assert.are.same({
				"Journal binding (1/2)",
				"  ledger.binding.oak In use",
				"  ledger.binding.lapis 900" .. COIN .. " [red]",
			}, outline(shop:List({ category = "Fish Journal" })))
		end
	)

	it("counts an earned good owned once its Module says so (SHOP-R22, SHOP-R30)", function()
		local fake, handles = session()
		huntsCovers(handles.Hunts, { value = true })
		fake.login()

		assert.are.same(
			afterCore({
				"Notebook cover (2/3)",
				"  hunts.cover.plain In use",
				"  hunts.cover.velvet 400" .. COIN .. " [red]",
				"  hunts.cover.gold Owned",
			}),
			outline(model(fake):List({}))
		)
	end)
end)

-- Hunts off this session: its cached goods from an earlier one, with Velvet bought and Gold earned then, and the
-- Ledger On with its bindings. Logged in.
local huntsOff

describe("The shop's Put away group", function()
	function huntsOff()
		local fake, handles = session("Hunts")
		ledgerBindings(handles.Ledger)
		local function cached(id, name, fields)
			local row = {
				name = name,
				slot = "hunts.cover",
				slotLabel = "Notebook cover",
				category = "Hunts",
				module = "Hunts",
			}
			for key, value in pairs(fields) do
				row[key] = value
			end
			fake.goods[id] = row
		end
		cached("hunts.cover.plain", "Plain", { default = true })
		cached("hunts.cover.velvet", "Velvet", { tier = 2, icon = 134939, description = "Soft." })
		cached("hunts.cover.gold", "Gold", { earned = true })
		cached("hunts.cover.tide", "Tide", { tier = 1 })
		fake.login()
		fake.setPurchased({ ["hunts.cover.velvet"] = true })
		return fake
	end

	it(
		"lists an off Module's bought and earned goods last, not its default or goods for sale, saying Yours to keep"
			.. " (SHOP-R35)",
		function()
			local fake = huntsOff()

			local groups = model(fake):List({})

			assert.are.same(
				afterCore({
					"Journal binding (1/2)",
					"  ledger.binding.oak In use",
					"  ledger.binding.lapis 900" .. COIN .. " [red]",
					"Put away: Module off (Yours to keep)",
					"  hunts.cover.gold Hunts is off",
					"  hunts.cover.velvet Hunts is off",
				}),
				outline(groups)
			)
			local putAway = groups[#groups]
			assert.is_true(putAway.putAway)
			assert.are.same(
				{ id = "hunts.cover.velvet", name = "Velvet", icon = 134939, state = "putAway", tag = "Hunts is off" },
				putAway.rows[2]
			)
			assert.are.same({
				{ category = "Announcements", label = "Announcements" },
				{ category = "Bookplate", label = "Bookplate" },
				{ category = "Fish Journal", label = "Fish Journal" },
			}, model(fake):Chips(), "no chip for a slot that isn't live")
		end
	)

	it("follows the search, the filter and the chip (SHOP-R35, wallet-and-shop.md › UI)", function()
		local fake = huntsOff()
		local shop = model(fake)

		local function putAway(query)
			local groups = shop:List(query)
			local last = groups[#groups]
			return last and last.putAway and #last.rows or 0
		end

		assert.are.equal(1, putAway({ search = "velv" }))
		assert.are.equal(2, putAway({ filter = "owned" }))
		assert.are.equal(0, putAway({ filter = "notOwned" }))
		assert.are.equal(0, putAway({ filter = "canAfford" }))
		assert.are.equal(2, putAway({ category = "Hunts" }))
		assert.are.equal(0, putAway({ category = "Fish Journal" }))
	end)
end)

describe("Selecting a good", function()
	it("selects a live good and an owned good put away; nothing for anything else (SHOP-R40, SHOP-R35)", function()
		local fake = huntsOff()
		local shop = model(fake)

		assert.are.equal("ledger.binding.lapis", shop:Select("ledger.binding.lapis"))
		assert.are.equal("core.toaststyle.timber", shop:Select("core.toaststyle.timber"))
		assert.are.equal("hunts.cover.velvet", shop:Select("hunts.cover.velvet"))
		assert.is_nil(shop:Select("hunts.cover.tide")) -- for sale, of a Module off
		assert.is_nil(shop:Select("hunts.cover.plain")) -- a default of a Module off
		assert.is_nil(shop:Select("nobody.nothing"))
		assert.is_nil(shop:Select(42))
		assert.is_nil(shop:Select(nil))
	end)
end)

describe("The shop's stage", function()
	-- Core's own goods, Hunts' covers (Gold earned while `earned.value`) and the Ledger's bindings, logged in, with a
	-- balance of `balance`.
	local function staged(balance, earned)
		local fake, handles = session()
		huntsCovers(handles.Hunts, earned or { value = false })
		ledgerBindings(handles.Ledger)
		fake.login()
		handles.Ledger:ReportCoinsEarned(balance)
		return fake, handles
	end

	it(
		"shows a good for sale with its name, slot, owner, description, price and Buy (wallet-and-shop.md › UI)",
		function()
			local fake = staged(1000)

			local stage = assert(model(fake):Stage("hunts.cover.velvet"))

			assert.are.same({
				id = "hunts.cover.velvet",
				name = "Velvet",
				icon = 134939,
				slotLine = "Notebook cover · Hunts",
				description = "Soft to the touch.",
				state = "forSale",
				price = "400" .. COIN,
				buy = "Buy for 400" .. COIN,
				tags = {},
				notes = {},
			}, stage)
		end
	)

	it("shows what more a good the balance can't cover needs, its price in red (wallet-and-shop.md › UI)", function()
		local fake = staged(650)

		local stage = assert(model(fake):Stage("ledger.binding.lapis"))

		assert.are.same(
			{ "Journal binding · Ledger", "short", "900" .. COIN, true, "Buy for 900" .. COIN, "250 more needed" },
			{ stage.slotLine, stage.state, stage.price, stage.short, stage.buy, stage.needed }
		)
		assert.are.equal("350 more needed", assert(model(staged(50)):Stage("hunts.cover.velvet")).needed)
	end)

	it(
		"shows Owned and Use for an owned good, In use for the equipped one, and default (wallet-and-shop.md › UI)",
		function()
			local fake = staged(0)
			local shop = model(fake)

			local timber, plain = assert(shop:Stage("core.toaststyle.timber")), assert(shop:Stage("hunts.cover.plain"))

			assert.are.same(
				{ "equipped", { "In use", "default" }, "Toast style · Pagle" },
				{ timber.state, timber.tags, timber.slotLine }
			)
			assert.is_nil(timber.use)
			assert.is_nil(timber.buy)
			assert.are.equal("Notebook cover · Hunts", plain.slotLine)

			fake.setPurchased({ ["core.toaststyle.ripple"] = true })
			fake.Pagle.SetEquipped("core.toaststyle", "core.toaststyle.ripple")
			shop = model(fake)
			local ripple = assert(shop:Stage("core.toaststyle.ripple"))
			timber = assert(shop:Stage("core.toaststyle.timber"))

			assert.are.same({ "equipped", { "In use" } }, { ripple.state, ripple.tags })
			assert.are.same({ "owned", { "default" }, true }, { timber.state, timber.tags, timber.use })
			fake.setPurchased({ ["core.toaststyle.ripple"] = true, ["core.toaststyle.lanternglow"] = true })
			local lantern = assert(model(fake):Stage("core.toaststyle.lanternglow"))
			assert.are.same({ "owned", { "Owned" }, true }, { lantern.state, lantern.tags, lantern.use })
			assert.is_nil(lantern.price)
		end
	)

	it(
		"shows an earned good's earnedText and that it isn't for sale, earned or not (wallet-and-shop.md › UI)",
		function()
			local earned = { value = false }
			local fake, handles = staged(5000, earned)

			local gold = assert(model(fake):Stage("hunts.cover.gold"))
			assert.are.same(
				{ "unearned", {}, { "Every Hunt done", "A Hunts reward, not for sale" } },
				{ gold.state, gold.tags, gold.notes }
			)
			assert.is_nil(gold.buy)
			assert.is_nil(gold.price)

			earned.value = true
			handles.Hunts:RefreshGoods()
			gold = assert(model(fake):Stage("hunts.cover.gold"))
			assert.are.same(
				{ "owned", { "Owned" }, { "Every Hunt done", "A Hunts reward, not for sale" }, true },
				{ gold.state, gold.tags, gold.notes, gold.use }
			)
		end
	)

	it("hands over the good's preview and icon (wallet-and-shop.md › UI)", function()
		local fake, handles = session()
		local function preview() end
		handles.Hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Hunts" })
		handles.Hunts:RegisterGood({
			id = "hunts.cover.plain",
			slot = "hunts.cover",
			name = "Plain",
			default = true,
			icon = 134939,
			preview = preview,
		})
		fake.login()

		local stage = assert(model(fake):Stage("hunts.cover.plain"))

		assert.are.equal(preview, stage.preview)
		assert.are.equal(134939, stage.icon)
	end)

	it(
		"shows a good put away greyed, with its cached icon, its Module off and Yours to keep, and no Use (SHOP-R35)",
		function()
			local fake = huntsOff()

			local velvet = assert(model(fake):Stage("hunts.cover.velvet"))

			assert.are.same({
				id = "hunts.cover.velvet",
				name = "Velvet",
				icon = 134939,
				slotLine = "Notebook cover · Hunts",
				description = "Soft.",
				state = "putAway",
				greyed = true,
				tags = { "Hunts is off" },
				notes = { "Yours to keep" },
			}, velvet)
		end
	)

	it("is nil for a good the shop doesn't show (SHOP-R40)", function()
		local fake = huntsOff()

		assert.is_nil(model(fake):Stage("hunts.cover.tide"))
		assert.is_nil(model(fake):Stage(nil))
	end)
end)

describe("Buy on the stage", function()
	-- The Ledger's bindings and Hunts' covers (Gold earned while `earned.value`), logged in and in the world, every
	-- projection caught up, with the Ledger's `balance` Coins.
	local function ready(balance, earned)
		local fake, handles = session()
		huntsCovers(handles.Hunts, earned or { value = false })
		ledgerBindings(handles.Ledger)
		fake.login()
		fake.enterWorld()
		handles.Ledger:ReportCoinsEarned(balance)
		return fake, handles
	end

	it(
		"is enabled for a good for sale, not owned, of a Module On, that the balance covers, with no projection"
			.. " updating (SHOP-R13)",
		function()
			local shop = model(ready(400))

			assert.is_true(assert(shop:Stage("hunts.cover.velvet")).canBuy) -- 400 covers 400
			assert.is_true(assert(shop:Stage("core.toaststyle.ripple")).canBuy)
		end
	)

	it(
		"is disabled for an owned good, a default, an earned good, and a good the balance doesn't cover (SHOP-R13)",
		function()
			local earned = { value = false }
			local fake, handles = ready(899, earned)
			fake.setPurchased({ ["core.toaststyle.ripple"] = true })
			local shop = model(fake)

			for _, goodID in ipairs({
				"core.toaststyle.ripple", -- bought
				"hunts.cover.plain", -- the default
				"hunts.cover.gold", -- earned, not yet
				"ledger.binding.lapis", -- 900, one more needed
			}) do
				assert.are.same({ goodID }, { goodID, assert(shop:Stage(goodID)).canBuy, shop:Purchase(goodID) })
			end
			earned.value = true
			handles.Hunts:RefreshGoods()
			assert.is_nil(model(fake):Purchase("hunts.cover.gold"))
		end
	)

	it("is disabled for a good of a Module off, owned or not (SHOP-R13, SHOP-R35)", function()
		local fake = huntsOff()
		fake.enterWorld()
		fake.setPurchased({ ["hunts.cover.velvet"] = true }) -- the log's own set replaced huntsOff's
		fake.global.coins.earned.Ledger = 5000
		local shop = model(fake)

		assert.is_nil(shop:Stage("hunts.cover.tide")) -- for sale, not shown
		assert.is_nil(shop:Purchase("hunts.cover.tide"))
		assert.is_nil(assert(shop:Stage("hunts.cover.velvet")).canBuy) -- put away
		assert.is_nil(shop:Purchase("hunts.cover.velvet"))
	end)

	it(
		"is disabled while any projection updates: at login, and while a Module's catches up (SHOP-R13, SHOP-R91)",
		function()
			local fake, handles = session()
			huntsCovers(handles.Hunts, { value = false })
			handles.Ledger:ReportCoinsEarned(1000)
			local during
			handles.Hunts:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function()
					during = model(fake)
				end,
			})
			fake.login()

			assert.is_nil(assert(model(fake):Stage("hunts.cover.velvet")).canBuy) -- nothing has caught up yet
			fake.enterWorld()
			assert.is_nil(assert(during:Stage("hunts.cover.velvet")).canBuy) -- in Hunts' done
			assert.is_nil(during:Purchase("hunts.cover.velvet"))
			assert.is_true(assert(model(fake):Stage("hunts.cover.velvet")).canBuy)
		end
	)
end)

describe("A purchase", function()
	it(
		"is the good's ID, slot, name, swatch and price now, and the Coins left after (SHOP-R10, wallet-and-shop.md"
			.. " › UI: Buy)",
		function()
			local fake, handles = session()
			huntsCovers(handles.Hunts, { value = false })
			fake.login()
			fake.enterWorld()
			handles.Ledger:ReportCoinsEarned(1450)

			assert.are.same({
				id = "hunts.cover.velvet",
				slot = "hunts.cover",
				name = "Velvet",
				icon = 134939,
				price = 400,
				priceText = "400" .. COIN,
				leftAfter = "Pagle Coins left after: 1,050. Looks are yours for good.",
			}, model(fake):Purchase("hunts.cover.velvet"))
			assert.is_nil(model(fake):Purchase("hunts.cover.none"))
			assert.is_nil(model(fake):Purchase(nil))
		end
	)
end)

describe("Buying", function()
	-- Hunts' covers, logged in and in the world, with the Ledger's `balance` Coins, and a Session open (one Cast), so a
	-- moment or a summary line would land in it.
	local function ready(balance)
		local fake, handles = session()
		huntsCovers(handles.Hunts, { value = false })
		fake.login()
		fake.enterWorld()
		handles.Ledger:ReportCoinsEarned(balance)
		fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
		fake.nextFrame()
		return fake, handles
	end

	-- Each look change from now on, as "<slot> <goodID>".
	local function looks(fake)
		local changed = {}
		fake.Pagle.RegisterCallback("spec", "AppearanceChanged", function(_, slot, goodID)
			changed[#changed + 1] = slot .. " " .. goodID
		end)
		return changed
	end

	it(
		"appends one U1 with the good and its price, the balance drops and it's owned; Use it now equips it (SHOP-R10,"
			.. " SHOP-R13, LOG-R39, wallet-and-shop.md › UI: Buy)",
		function()
			local fake = ready(200)
			local Pagle = fake.Pagle
			local before = #fake.catchLog.data.entries
			local changed = looks(fake)

			assert.is_true(fake.ns.shop.Buy("core.toaststyle.ripple", true))

			local entries = fake.catchLog.data.entries
			assert.are.equal(before + 1, #entries)
			-- Ada at the fake's server time, tie 1 after the Cast in the same second (LOG-R12).
			assert.are.equal(purchaseEntry(SERVER_TIME, "core.toaststyle.ripple", 150, 1), entries[#entries])
			assert.are.equal(50, Pagle.GetBalance().balance)
			assert.is_true(Pagle.IsOwned("core.toaststyle.ripple"))
			assert.are.equal("core.toaststyle.ripple", Pagle.GetEquipped("core.toaststyle"))
			assert.are.same({ "core.toaststyle core.toaststyle.ripple" }, changed)
		end
	)

	it("leaves the look as it was without Use it now: owned, not equipped (wallet-and-shop.md › UI: Buy)", function()
		local fake = ready(200)
		local changed = looks(fake)

		assert.is_true(fake.ns.shop.Buy("core.toaststyle.ripple", false))

		assert.is_true(fake.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal("core.toaststyle.timber", fake.Pagle.GetEquipped("core.toaststyle"))
		assert.are.same({}, changed)
	end)

	it("equips an owned good with Use, and nothing for a good not owned or not known (SHOP-R32)", function()
		local fake = ready(200)
		local changed = looks(fake)
		fake.ns.shop.Buy("core.toaststyle.ripple", false)

		assert.are.same({ true, false, false }, {
			fake.ns.shop.Use("core.toaststyle.ripple"),
			fake.ns.shop.Use("core.toaststyle.lanternglow"),
			fake.ns.shop.Use("core.toaststyle.none"),
		})
		assert.are.equal("core.toaststyle.ripple", fake.Pagle.GetEquipped("core.toaststyle"))
		assert.are.same({ "core.toaststyle core.toaststyle.ripple" }, changed)
	end)

	it("raises no Announcement and no Session summary line (ANN-R23, SHOP-R5)", function()
		local fake = ready(200)
		local announced, summarized = #fake.announcements, #fake.summarized

		fake.ns.shop.Buy("core.toaststyle.ripple", true)
		fake.nextFrame()
		fake.wait(900) -- the Session ends

		assert.are.equal(announced, #fake.announcements)
		assert.are.equal(summarized, #fake.summarized)
		assert.are.same({}, fake.cardsShown)
	end)

	it(
		"does nothing once Buy isn't enabled any more: the balance short, the good owned, a projection updating"
			.. " (SHOP-R13)",
		function()
			local fake, handles = ready(200)
			local before = #fake.catchLog.data.entries

			assert.is_false(fake.ns.shop.Buy("hunts.cover.velvet", true)) -- 400, with 200
			assert.is_true(fake.ns.shop.Buy("core.crest.crest1", false))
			assert.is_false(fake.ns.shop.Buy("core.crest.crest1", false)) -- owned now
			local during
			handles.Hunts:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function()
					during = fake.ns.shop.Buy("core.toaststyle.ripple", true) -- in Hunts' first build
				end,
			})

			assert.is_false(during)
			assert.are.equal(before + 1, #fake.catchLog.data.entries)
			assert.is_false(fake.Pagle.IsOwned("core.toaststyle.ripple"))
			assert.are.equal(50, fake.Pagle.GetBalance().balance)
		end
	)
end)
