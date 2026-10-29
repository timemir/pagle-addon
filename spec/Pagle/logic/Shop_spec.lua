-- The Curio Shop as data (wallet-and-shop.md › UI, SHOP-R22, SHOP-R30, SHOP-R35, SHOP-R40): the purse, the list
-- and the stage, built by ns.NewShopModel over Core's real goods registry and wallet, here FakePagle's.

-- A FakePagle with the Ledger (order 10) and Hunts (order 20) On, unless `off` names one to leave unregistered, and
-- Core's own slots and goods, as Core registers them (SHOP-R25), named by their IDs until their lore lands; nothing
-- logged in yet. Returns the fake and the handles, by def.name.
local function coreWithModules(off)
	local fake = newFakePagle()
	local handles = {}
	for _, def in ipairs({ { name = "Ledger", order = 10 }, { name = "Hunts", order = 20 } }) do
		if def.name ~= off then
			handles[def.name] = fake.Pagle.RegisterModule({ name = def.name, title = def.name, order = def.order })
		end
	end
	return fake, handles
end

-- `lines`, then `more`, as one new list.
---@param lines string[]
---@param more string[]
---@return string[]
local function joined(lines, more)
	local all = { unpack(lines) }
	for _, line in ipairs(more) do
		all[#all + 1] = line
	end
	return all
end

-- The crest slot as the list outlines it with Plain in use: Plain alone, as no crest is for sale and its earned crests,
-- Core's fish crests (VAR-R12) among them, are neither listed nor counted (SHOP-R25).
local CREST_LINES = { "Crests (1 of 1)", "  core.crest.plain In use" }

-- Core's toast styles, sound sets and bindings for sale (SHOP-R25), each slot's in the order the list shows them
-- (SHOP-R27): cheapest tier first, goods of a tier in registration order, so the Curio Shop expansion's come after
-- Ripple and Lanternglow, and the round two's Storm Front and the round three's after the older goods of their tier.
local FOR_SALE = {
	toaststyle = {
		{ "ripple", 1 },
		{ "lanternglow", 1 },
		{ "ship", 1 },
		{ "birch", 1 },
		{ "tidepool", 1 },
		{ "chart", 1 },
		{ "frost", 1 },
		{ "goblin", 2 },
		{ "kelp", 2 },
		{ "moon", 2 },
		{ "leaf", 2 },
		{ "bottle", 2 },
		{ "folio", 2 },
		{ "rune", 3 },
		{ "ooze", 3 },
		{ "robot", 3 },
		{ "spider", 3 },
		{ "glacier", 3 },
		{ "pirate", 3 },
		{ "storm", 4 },
		{ "hive", 4 },
		{ "magma", 4 },
		{ "arcane", 4 },
	},
	soundset = {
		{ "rain", 1 },
		{ "marimba", 1 },
		{ "shipbell", 1 },
		{ "squeaky", 1 },
		{ "bubbleworks", 1 },
		{ "gilded", 2 },
		{ "kalimba", 2 },
		{ "musicbox", 2 },
		{ "glass", 2 },
		{ "steelpan", 2 },
		{ "dulcimer", 2 },
		{ "goblintill", 2 },
		{ "kazoo", 2 },
		{ "arcade", 2 },
		{ "boing", 2 },
		{ "slime", 2 },
		{ "frost", 3 },
		{ "harp", 3 },
		{ "gizmo", 3 },
		{ "mrglglgl", 3 },
		{ "parrot", 3 },
		{ "laser", 3 },
		{ "silithid", 3 },
		{ "succubus", 3 },
		{ "wardrums", 4 },
		{ "dragonroost", 4 },
	},
	-- Core's book binding's bindings for sale (ADR 0015), in the shop's order.
	binding = {
		{ "birch", 1 },
		{ "chartlinen", 1 },
		{ "sailcloth", 1 },
		{ "oilskin", 1 },
		{ "canvas", 1 },
		{ "kraft", 1 },
		{ "tartan", 1 },
		{ "buckram", 2 },
		{ "moss", 2 },
		{ "driftwood", 2 },
		{ "eelskin", 2 },
		{ "kodo", 2 },
		{ "frosthide", 2 },
		{ "netcork", 2 },
		{ "tooled", 2 },
		{ "maplinen", 2 },
		{ "planks", 2 },
		{ "sharkskin", 3 },
		{ "copper", 3 },
		{ "velvet", 3 },
		{ "turtle", 3 },
		{ "morocco", 3 },
		{ "verdigris", 3 },
		{ "snakeskin", 3 },
		{ "shagreen", 3 },
		{ "lacquer", 3 },
		{ "bone", 3 },
		{ "brasscase", 3 },
		{ "coral", 4 },
		{ "scrimshaw", 4 },
		{ "shagreenbone", 4 },
		{ "pearl", 5 },
		{ "trophycase", 5 },
	},
}
-- The toast styles that aren't for sale come after those that are, as the list outlines them not owned: Prize Foil,
-- the Curio crate's alone (SHOP-R50). Sonar Scope, earned once the companion is linked (SHOP-R29), is no longer among
-- them: an earned good is listed only from its fallback date on, and Sonar Scope has none yet (SHOP-R24, SHOP-R28).
local ROUND_TWO_UNOWNED = {
	"  core.toaststyle.foil From a crate",
}
local ROUND_TWO_IDS = { "core.toaststyle.foil" }

-- Each tier's price (SHOP-R22), as the list prints it.
local PRICES = { "250", "400", "900", "3,000", "10,000", "25,000" }
local PRICE_VALUES = { 250, 400, 900, 3000, 10000, 25000 }

-- The goods for sale of Core's slot `slot` ("toaststyle", "soundset" or "binding") as the list outlines them, with a
-- balance of `balance`: each priced, in red where the balance falls short, but for those `tags` gives another tag
-- (by name): bought, in use. The toast styles go on with those that aren't for sale.
---@param slot string
---@param balance integer
---@param tags? table<string, string>
---@return string[]
local function saleLines(slot, balance, tags)
	local lines = {}
	for _, good in ipairs(FOR_SALE[slot]) do
		local tier = good[2]
		local tag = tags and tags[good[1]]
		lines[#lines + 1] = ("  core.%s.%s %s%s"):format(
			slot,
			good[1],
			tag or PRICES[tier],
			not tag and PRICE_VALUES[tier] > balance and " [red]" or ""
		)
	end
	if slot == "toaststyle" then
		for _, line in ipairs(ROUND_TWO_UNOWNED) do
			lines[#lines + 1] = line
		end
	end
	return lines
end

-- The goods for sale of Core's slot `slot` the balance `balance` covers, by ID, in the list's order.
---@param slot string
---@param balance integer
---@return string[]
local function saleAffordable(slot, balance)
	local ids = {}
	for _, good in ipairs(FOR_SALE[slot]) do
		if PRICE_VALUES[good[2]] <= balance then
			ids[#ids + 1] = ("core.%s.%s"):format(slot, good[1])
		end
	end
	return ids
end

-- Core's book binding (ADR 0015) as the list outlines it with Field Leather in use and a balance of `balance`.
---@param balance integer
---@return string[]
local function bindingLines(balance)
	return joined({ "Book binding (1 of 34)", "  core.binding.field In use" }, saleLines("binding", balance))
end

-- Core's own slots (SHOP-R25) as the list outlines them while nothing of Core's is bought and the balance is under
-- 150: each default in use, everything else priced in red.
local CORE_UNBOUGHT = joined(
	joined(
		joined(
			joined({ "Toast style (1 of 25)", "  core.toaststyle.page In use" }, saleLines("toaststyle", 0)),
			joined({ "Sound set (1 of 27)", "  core.soundset.driftwood In use" }, saleLines("soundset", 0))
		),
		CREST_LINES
	),
	bindingLines(0)
)

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
-- while `earned.value`, "Every Hunt done"), which the shop lists only from `fallbackFrom` on, at tier 2's price
-- (SHOP-R24, SHOP-R28): never when that is nil.
local function huntsCovers(hunts, earned, fallbackFrom)
	hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
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
		fallbackTier = fallbackFrom and 2 or nil,
		fallbackFrom = fallbackFrom,
	})
end

-- The Ledger's binding slot: Oak (default) and Lapis (tier 3).
local function ledgerBindings(ledger)
	ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Books" })
	ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
	ledger:RegisterGood({ id = "ledger.binding.lapis", slot = "ledger.binding", name = "Lapis", tier = 3 })
end

-- The Ledger's zone crests in Core's crest slot, open to earned goods (SHOP-R23, LED-R113): The Old Oak, earned while
-- `earned.value`, and The Desert Sun, never; each earnedText a function giving `texts[id]` (the row's tag, then the
-- stage's note) and counting its calls in `texts.calls`. Neither has a preview of its own.
local function ledgerCrests(ledger, earned, texts)
	texts = texts
		or {
			["ledger.crest.elwynn"] = { "Expert · 88%", "Earned when Elwynn reaches Master." },
			["ledger.crest.tanaris"] = { "Unfished", "Earned when Tanaris reaches Master. Catch anything there." },
		}
	texts.calls = texts.calls or 0
	local function crest(id, name, isEarned)
		ledger:RegisterGood({
			id = id,
			slot = "core.crest",
			name = name,
			icon = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\" .. id:match("[^.]+$"),
			isEarned = isEarned,
			earnedText = function()
				texts.calls = texts.calls + 1
				local given = texts[id] or {}
				return given[1], given[2]
			end,
		})
	end
	crest("ledger.crest.elwynn", "The Old Oak", function()
		return earned.value
	end)
	crest("ledger.crest.tanaris", "The Desert Sun", function()
		return false
	end)
	return texts
end

-- The shop's model now, as Core builds it (ns.ShopModel): over the fake's goods, cache, Modules On, balance and
-- projections.
local function model(fake)
	return fake.ns.ShopModel(breakUpLargeNumbers)
end

describe("The Curio Shop's purse", function()
	it(
		"shows the balance, and a segment per Module that reported Coins in roster order with its share"
			.. " (wallet-and-shop.md › UI)",
		function()
			local fake, handles = coreWithModules()
			handles.Hunts:ReportCoinsEarned(500)
			handles.Ledger:ReportCoinsEarned(1500)
			fake.setSpent(150)

			local purse = model(fake):Purse()

			assert.are.equal("1,850", purse.balance)
			assert.are.equal("Pagle Coins", purse.label)
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
			local fake = coreWithModules("Hunts")
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

	it(
		"counts a test log's granted Coins in the balance, with no segment of their own (catch-log.md › Test logs)",
		function()
			local fake = coreWithModules("Ledger")
			fake.global.coins.earned.Ledger = 100
			fake.global.coins.earned.Dev = 900

			local purse = model(fake):Purse()

			assert.are.equal("1,000", purse.balance)
			assert.are.same({ "Ledger" }, { purse.segments[1].module, purse.segments[2] and purse.segments[2].module })
			assert.are.equal(1, purse.segments[1].share)
		end
	)

	it("has no segment before any Module reports, and never says Spent (wallet-and-shop.md › UI)", function()
		local fake = coreWithModules()
		fake.setSpent(50)

		local purse = model(fake):Purse()

		assert.are.same({}, purse.segments)
		assert.are.equal("0", purse.balance)
		assert.is_true(purse.held)
		for _, text in pairs({ purse.label, purse.balance }) do
			assert.falsy(text:find("Spent", 1, true))
		end
	end)
end)

-- Each group's label and owned count, and its rows as "<id> <tag or price>", from a list; a grouped slot's header
-- (SHOP-R27) as "  -- <name>" before the row it heads.
local function outline(groups)
	local lines = {}
	for _, group in ipairs(groups) do
		lines[#lines + 1] = ("%s (%s)"):format(group.label, group.count or group.note)
		for i, row in ipairs(group.rows) do
			local heading = group.headings and group.headings[i]
			if heading then
				lines[#lines + 1] = "  -- " .. heading
			end
			lines[#lines + 1] = ("  %s %s%s"):format(row.id, row.tag or row.price, row.short and " [red]" or "")
		end
	end
	return lines
end

-- Hunts' frames, a grouped slot (SHOP-R27): Gilt frames then Wooden frames, its goods registered out of that order:
-- Plain (default), Oak (wooden, tier 1), Gold leaf (gilt, earned while `earned.value`, its texts a function's),
-- Velvet (tier 1, no group) and Birch (wooden, tier 2). Gold leaf is listed only from `fallbackFrom` on, at tier 2's
-- price (SHOP-R24, SHOP-R28), never when that is nil.
local function huntsFrames(hunts, earned, fallbackFrom)
	hunts:RegisterSlot({
		id = "hunts.frame",
		label = "Frame",
		category = "Trackers",
		groups = { { key = "gilt", name = "Gilt frames" }, { key = "wood", name = "Wooden frames" } },
	})
	hunts:RegisterGood({ id = "hunts.frame.plain", slot = "hunts.frame", name = "Plain", default = true })
	hunts:RegisterGood({ id = "hunts.frame.oak", slot = "hunts.frame", name = "Oak", tier = 1, group = "wood" })
	hunts:RegisterGood({
		id = "hunts.frame.leaf",
		slot = "hunts.frame",
		name = "Gold leaf",
		group = "gilt",
		isEarned = function()
			return earned.value
		end,
		earnedText = function()
			return "2 of 3 gilded", "Gild 3 frames. 2 gilded so far."
		end,
		fallbackTier = fallbackFrom and 2 or nil,
		fallbackFrom = fallbackFrom,
	})
	hunts:RegisterGood({ id = "hunts.frame.velvet", slot = "hunts.frame", name = "Velvet", tier = 1 })
	hunts:RegisterGood({ id = "hunts.frame.birch", slot = "hunts.frame", name = "Birch", tier = 2, group = "wood" })
end

describe("The Curio Shop's list", function()
	-- The Core the list specs share: Core's toast styles, Hunts' covers (Gold not yet earned) and the Ledger's
	-- bindings, logged in, with a balance of 300 and Ripple bought and in use.
	local function shopping()
		local fake, handles = coreWithModules()
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

			assert.are.same(
				joined(
					joined(
						joined(
							joined(
								{ "Toast style (2 of 25)", "  core.toaststyle.page default" },
								saleLines("toaststyle", 300, { ripple = "In use" })
							),
							joined(
								{ "Sound set (1 of 27)", "  core.soundset.driftwood In use" },
								saleLines("soundset", 300)
							)
						),
						joined(CREST_LINES, bindingLines(300))
					),
					{
						"Journal binding (1 of 2)",
						"  ledger.binding.oak In use",
						"  ledger.binding.lapis 900" .. " [red]",
						"Notebook cover (1 of 2)",
						"  hunts.cover.plain In use",
						"  hunts.cover.velvet 400" .. " [red]",
					}
				),
				outline(model(fake):List({}))
			)
		end
	)

	it(
		"prices a good the balance covers in white, with its name and icon on the row (wallet-and-shop.md › UI)",
		function()
			local fake, handles = shopping()
			handles.Ledger:ReportCoinsEarned(1000)

			local rows = model(fake):List({ category = "Trackers" })[1].rows

			assert.are.same(
				{ id = "hunts.cover.velvet", name = "Velvet", icon = 134939, state = "forSale", price = "400" },
				rows[2]
			)
		end
	)

	it("marks a crest's row, stage and purchase to draw its shield, and no other good's (SHOP-R25)", function()
		local fake, handles = shopping()
		fake.enterWorld()
		-- No crest is for sale (SHOP-R25), but the shop draws any good of the slot as its shield: one of Core's here.
		fake.ns.RegisterCoreGood({ id = "core.crest.peaks", slot = "core.crest", name = "Peaks", tier = 2 })
		handles.Ledger:ReportCoinsEarned(1000)
		local shop = model(fake)

		local rows = shop:List({ category = "Crests" })[1].rows
		local velvet = shop:List({ category = "Trackers" })[1].rows[2]

		assert.are.same({ true, true }, { rows[1].shield, rows[2].shield })
		assert.is_nil(velvet.shield)
		assert.is_true(shop:Stage("core.crest.peaks").shield)
		assert.is_true(shop:Purchase("core.crest.peaks").shield)
		assert.is_nil(shop:Stage("hunts.cover.velvet").shield)
		assert.is_nil(shop:Purchase("core.toaststyle.lanternglow").shield)
	end)

	it("matches the search against names, ignoring case (wallet-and-shop.md › UI)", function()
		local fake = shopping()

		assert.are.same({
			"Journal binding (1 of 2)",
			"  ledger.binding.lapis 900" .. " [red]",
		}, outline(model(fake):List({ search = "LaPi" })))
		assert.are.same({
			"Crests (1 of 1)",
			"  core.crest.plain In use",
			"Notebook cover (1 of 2)",
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

		assert.are.equal(25 + 27 + 1 + 34 + 2 + 2, #ids("all"))
		assert.are.same({
			"core.toaststyle.page",
			"core.toaststyle.ripple",
			"core.soundset.driftwood",
			"core.crest.plain",
			"core.binding.field",
			"ledger.binding.oak",
			"hunts.cover.plain",
		}, ids("owned"))
		-- Ripple is bought; the toast styles that aren't for sale list after those that are
		local toastStyles = saleAffordable("toaststyle", math.huge)
		table.remove(toastStyles, 1)
		local notOwned = joined(
			joined(joined(toastStyles, ROUND_TWO_IDS), saleAffordable("soundset", math.huge)),
			saleAffordable("binding", math.huge)
		)
		assert.are.same(joined(notOwned, { "ledger.binding.lapis", "hunts.cover.velvet" }), ids("notOwned"))
		local affordableStyles = saleAffordable("toaststyle", 550)
		table.remove(affordableStyles, 1) -- Ripple is bought
		assert.are.same(
			joined(
				joined(affordableStyles, joined(saleAffordable("soundset", 550), saleAffordable("binding", 550))),
				{ "hunts.cover.velvet" }
			),
			ids("canAfford")
		)
	end)

	it(
		"shows a chip for each category a live slot uses, in SHOP's order, and narrows to one (wallet-and-shop.md › UI)",
		function()
			local fake = shopping()
			local shop = model(fake)

			assert.are.same({
				{ category = "Announcements", label = "Announcements" },
				{ category = "Crests", label = "Crests" },
				{ category = "Books", label = "Books" },
				{ category = "Trackers", label = "Trackers" },
			}, shop:Chips())
			assert.are.same(
				joined(bindingLines(300), {
					"Journal binding (1 of 2)",
					"  ledger.binding.oak In use",
					"  ledger.binding.lapis 900" .. " [red]",
				}),
				outline(shop:List({ category = "Books" }))
			)
		end
	)

	it("counts an earned good owned once its Module says so, from its fallback date on (SHOP-R22, SHOP-R24)", function()
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, { value = true }, 1)
		fake.login()

		assert.are.same(
			afterCore({
				"Notebook cover (2 of 3)",
				"  hunts.cover.plain In use",
				"  hunts.cover.velvet 400" .. " [red]",
				"  hunts.cover.gold Owned",
			}),
			outline(model(fake):List({}))
		)
	end)

	it("never lists an earned good before its fallback date, owned or not (SHOP-R24)", function()
		for _, earned in ipairs({ false, true }) do
			local fake, handles = coreWithModules()
			huntsCovers(handles.Hunts, { value = earned }, fake.serverTime() + 86400)
			fake.login()

			assert.are.same(
				afterCore({
					"Notebook cover (1 of 2)",
					"  hunts.cover.plain In use",
					"  hunts.cover.velvet 400" .. " [red]",
				}),
				outline(model(fake):List({}))
			)
			assert.is_nil(model(fake):Entry("hunts.cover.gold"))
		end
	end)

	it(
		"lists an earned good from its fallback date on, at its fallback price beside its earned tag (SHOP-R24, SHOP-R28)",
		function()
			local fake, handles = coreWithModules()
			huntsCovers(handles.Hunts, { value = false }, fake.serverTime() + 100)
			fake.login()
			handles.Ledger:ReportCoinsEarned(1000)

			local before = model(fake):Row("hunts.cover.gold")
			fake.wait(100)
			local after = model(fake):Row("hunts.cover.gold")

			assert.is_nil(before)
			assert.are.same(
				{ id = "hunts.cover.gold", name = "Gold", state = "forSale", price = "400", tag = "Every Hunt done" },
				after
			)
		end
	)
end)

describe("A grouped slot on the Curio Shop's list", function()
	-- Hunts' frames alone of Hunts' (Gold leaf not yet earned), logged in, with a balance of 300.
	local function framing()
		local fake, handles = coreWithModules()
		huntsFrames(handles.Hunts, { value = false }, 1)
		fake.login()
		handles.Ledger:ReportCoinsEarned(300)
		return fake, handles
	end

	it(
		"lists the goods with no group first, then each group in the slot's order under its name, each in"
			.. " registration order (SHOP-R27)",
		function()
			local fake = framing()

			assert.are.same({
				"Frame (1 of 5)",
				"  hunts.frame.plain In use",
				"  hunts.frame.velvet 250",
				"  -- Gilt frames",
				"  hunts.frame.leaf 2 of 3 gilded [red]",
				"  -- Wooden frames",
				"  hunts.frame.oak 250",
				"  hunts.frame.birch 400" .. " [red]",
			}, outline(model(fake):List({ category = "Trackers" })))
		end
	)

	it("heads only the groups with a row left once the list is narrowed (SHOP-R27)", function()
		local fake = framing()
		local shop = model(fake)

		assert.are.same({
			"Frame (1 of 5)",
			"  -- Wooden frames",
			"  hunts.frame.birch 400" .. " [red]",
		}, outline(shop:List({ search = "birch", category = "Trackers" }))) -- Core's Birch Scroll is no Frame
		assert.are.same({
			"Frame (1 of 5)",
			"  hunts.frame.velvet 250",
			"  -- Wooden frames",
			"  hunts.frame.oak 250",
		}, outline(shop:List({ category = "Trackers", filter = "canAfford" })))
		assert.are.same(
			{ "Frame (1 of 5)", "  hunts.frame.plain In use" },
			outline(shop:List({ search = "plain", category = "Trackers" }))
		)
	end)

	it("never heads a group holding only goods the shop doesn't list (SHOP-R24, SHOP-R27)", function()
		local fake, handles = coreWithModules()
		huntsFrames(handles.Hunts, { value = true }, fake.serverTime() + 86400)
		fake.login()
		handles.Ledger:ReportCoinsEarned(300)

		assert.are.same({
			"Frame (1 of 4)",
			"  hunts.frame.plain In use",
			"  hunts.frame.velvet 250",
			"  -- Wooden frames",
			"  hunts.frame.oak 250",
			"  hunts.frame.birch 400" .. " [red]",
		}, outline(model(fake):List({ category = "Trackers" })))
	end)

	it("lists a slot with no groups as before, its goods in registration order (SHOP-R27)", function()
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, { value = false }, 1)
		fake.login()

		local group = model(fake):List({ category = "Trackers" })[1]

		assert.is_nil(group.headings)
		assert.are.same({ "hunts.cover.plain", "hunts.cover.velvet", "hunts.cover.gold" }, {
			group.rows[1].id,
			group.rows[2].id,
			group.rows[3].id,
		})
	end)

	it("gives Core's crest slot its Zone crests and Fish crests groups, in that order (SHOP-R25, SHOP-R27)", function()
		local fake = coreWithModules()
		fake.login()

		local crest
		for _, slot in ipairs(fake.ns.goods:Slots()) do
			if slot.id == "core.crest" then
				crest = slot
			end
		end

		assert.are.same(
			{ { key = "zone", name = "Zone crests" }, { key = "fish", name = "Fish crests" } },
			assert(crest).groups
		)
	end)
end)

describe("The Curio Shop's list order within a slot", function()
	-- Hunts' pennants, a slot whose registration order is not its tier order: Gale (tier 3), Dawn (earned, no fallback),
	-- Plain (the default), Reef (tier 1), Mist (tier 2), Dusk (tier 1), Storm (tier 6), Isle (tier 5), Ember (earned,
	-- its fallback price from a date past, SHOP-R28) and Wren (earned, its fallback from a date to come), logged in.
	local function pennants()
		local fake, handles = coreWithModules()
		local hunts = handles.Hunts
		hunts:RegisterSlot({ id = "hunts.pennant", label = "Pennant", category = "Trackers" })
		local function good(name, extra)
			local registered = { id = "hunts.pennant." .. name:lower(), slot = "hunts.pennant", name = name }
			for key, value in pairs(extra) do
				registered[key] = value
			end
			hunts:RegisterGood(registered)
		end
		local never = function()
			return false
		end
		good("Gale", { tier = 3 })
		good("Dawn", { isEarned = never, earnedText = "Dawn text" })
		good("Plain", { default = true })
		good("Reef", { tier = 1 })
		good("Mist", { tier = 2 })
		good("Dusk", { tier = 1 })
		good("Storm", { tier = 6 })
		good("Isle", { tier = 5 })
		good("Ember", { isEarned = never, earnedText = "Ember text", fallbackTier = 4, fallbackFrom = 1 })
		good("Wren", { isEarned = never, earnedText = "Wren text", fallbackTier = 4, fallbackFrom = 2 ^ 31 })
		fake.login()
		return fake, handles
	end

	-- The last part of each row's ID in `group`, in order.
	local function ids(group)
		local list = {}
		for i, row in ipairs(group.rows) do
			list[i] = row.id:match("[^.]+$")
		end
		return list
	end

	it(
		"lists the default first, then goods for sale cheapest tier first in registration order, then the earned goods"
			.. " on sale at their fallback price, none before its date (SHOP-R24, SHOP-R27)",
		function()
			local fake = pennants()

			local group = model(fake):List({ category = "Trackers" })[1]

			assert.are.same({ "plain", "reef", "dusk", "mist", "gale", "isle", "storm", "ember" }, ids(group))
		end
	)

	it("sorts a tier 6 good after every other good for sale (SHOP-R22, SHOP-R27)", function()
		local fake = pennants()

		local rows = model(fake):List({ category = "Trackers" })[1].rows

		assert.are.same({ "storm", "25,000" }, { rows[7].id:match("[^.]+$"), rows[7].price })
		assert.are.same({ "ember", "3,000", "Ember text" }, { rows[8].id:match("[^.]+$"), rows[8].price, rows[8].tag })
	end)

	it("counts over all the slot's goods and keeps the narrowed list in the same order (SHOP-R27)", function()
		local fake = pennants()
		local shop = model(fake)

		assert.are.equal("1 of 8", shop:List({ category = "Trackers" })[1].count)
		assert.are.same(
			{ "reef", "dusk", "mist", "gale", "isle", "storm", "ember" },
			ids(shop:List({ category = "Trackers", filter = "notOwned" })[1])
		)
	end)

	it("sorts a grouped slot's goods inside each group, the goods with no group first (SHOP-R27)", function()
		local fake, handles = coreWithModules()
		local hunts = handles.Hunts
		hunts:RegisterSlot({
			id = "hunts.flag",
			label = "Flag",
			category = "Trackers",
			groups = { { key = "a", name = "A flags" }, { key = "b", name = "B flags" } },
		})
		local function good(name, extra)
			local registered = { id = "hunts.flag." .. name, slot = "hunts.flag", name = name }
			for key, value in pairs(extra) do
				registered[key] = value
			end
			hunts:RegisterGood(registered)
		end
		local never = function()
			return false
		end
		good("b3", { tier = 3, group = "b" })
		good("b1", { tier = 1, group = "b" })
		good("a2", { tier = 2, group = "a" })
		good("a_earned", { isEarned = never, group = "a", fallbackTier = 2, fallbackFrom = 1 })
		good("a1", { tier = 1, group = "a" })
		good("n4", { tier = 4 })
		good("plain", { default = true, group = "b" })
		good("n2", { tier = 2 })
		good("b_earned", { isEarned = never, group = "b" })
		good("b2", { tier = 2, group = "b" })
		fake.login()

		local group = model(fake):List({ category = "Trackers" })[1]

		assert.are.same({ "n2", "n4", "a1", "a2", "a_earned", "plain", "b1", "b2", "b3" }, ids(group))
		assert.are.same({ [3] = "A flags", [6] = "B flags" }, group.headings)
		assert.are.equal("1 of 9", group.count)
	end)

	it("leaves Pagle.GetSlotGoods in registration order (SHOP-R21)", function()
		local fake = pennants()

		local registered = {}
		for i, id in ipairs(fake.Pagle.GetSlotGoods("hunts.pennant")) do
			registered[i] = id:match("[^.]+$")
		end

		assert.are.same(
			{ "gale", "dawn", "plain", "reef", "mist", "dusk", "storm", "isle", "ember", "wren" },
			registered,
			"every good, the earned ones the shop doesn't list too (SHOP-R36)"
		)
	end)

	it("puts a default registered last first all the same (SHOP-R22)", function()
		local fake, handles = coreWithModules()
		handles.Hunts:RegisterSlot({ id = "hunts.pin", label = "Pin", category = "Trackers" })
		handles.Hunts:RegisterGood({ id = "hunts.pin.two", slot = "hunts.pin", name = "Two", tier = 2 })
		handles.Hunts:RegisterGood({ id = "hunts.pin.one", slot = "hunts.pin", name = "One", tier = 1 })
		handles.Hunts:RegisterGood({ id = "hunts.pin.base", slot = "hunts.pin", name = "Base", default = true })
		fake.login()

		assert.are.same({ "base", "one", "two" }, ids(model(fake):List({ category = "Trackers" })[1]))
	end)
end)

describe("An earned good's texts and progress in the Curio Shop", function()
	-- Hunts' frames (Gold leaf earned while `earned.value`, with `progress` as its progress if given, on sale at tier
	-- 2's price from a fallback date past, SHOP-R28), logged in.
	local function earning(earned, progress)
		local fake, handles = coreWithModules()
		handles.Hunts:RegisterSlot({ id = "hunts.frame", label = "Frame", category = "Trackers" })
		handles.Hunts:RegisterGood({ id = "hunts.frame.plain", slot = "hunts.frame", name = "Plain", default = true })
		handles.Hunts:RegisterGood({
			id = "hunts.frame.leaf",
			slot = "hunts.frame",
			name = "Gold leaf",
			isEarned = function()
				return earned.value
			end,
			earnedText = function()
				return ("%d of 3 gilded"):format(earned.gilded or 2), "Gild 3 frames."
			end,
			progress = progress,
			fallbackTier = 2,
			fallbackFrom = 1,
		})
		fake.login()
		return fake, handles
	end

	-- Two dots: the first filled in red, the second ringed in blue.
	local function twoDots()
		return { { color = { 1, 0, 0 }, filled = true }, { color = { 0, 0, 1 }, filled = false } }
	end

	it(
		"shows an earnedText function's first text on the row and its second as the stage's note, read afresh at"
			.. " each draw (SHOP-R22)",
		function()
			local earned = { value = false }
			local fake = earning(earned)

			assert.are.same(
				{ "2 of 3 gilded", "400" },
				{ assert(model(fake):Row("hunts.frame.leaf")).tag, model(fake):Row("hunts.frame.leaf").price }
			)
			assert.are.same(
				{ "Gild 3 frames.", "Or buy it for 400" },
				assert(model(fake):Stage("hunts.frame.leaf")).notes
			)
			earned.gilded = 1
			assert.are.equal("1 of 3 gilded", assert(model(fake):Row("hunts.frame.leaf")).tag)
		end
	)

	it(
		"shows an earned good's progress dots on the stage while it isn't owned, read at each draw (SHOP-R22)",
		function()
			local calls = 0
			local earned = { value = false }
			local fake, handles = earning(earned, function()
				calls = calls + 1
				return twoDots()
			end)
			assert.are.equal(0, calls, "never called to register or own it")

			local stage = assert(model(fake):Stage("hunts.frame.leaf"))

			assert.are.same(twoDots(), stage.progress)
			assert.are.equal(1, calls)
			model(fake):Stage("hunts.frame.leaf")
			assert.are.equal(2, calls)
			assert.is_nil(model(fake):Stage("hunts.frame.plain").progress)

			earned.value = true
			handles.Hunts:RefreshGoods()
			local owned = assert(model(fake):Stage("hunts.frame.leaf"))
			assert.are.same({ "owned", {} }, { owned.state, owned.notes })
			assert.is_nil(owned.progress)
			assert.are.equal(2, calls)
		end
	)

	it("keeps only well-made dots, and none when progress raises (SHOP-R22)", function()
		local fake = earning({ value = false }, function()
			return {
				{ color = { 1, 0.5, 0 }, filled = true },
				{ color = { 1, 0.5 }, filled = true },
				{ color = "red", filled = false },
				"dot",
				{ color = { 0, 0, 1 } },
			}
		end)

		assert.are.same(
			{ { color = { 1, 0.5, 0 }, filled = true }, { color = { 0, 0, 1 }, filled = false } },
			assert(model(fake):Stage("hunts.frame.leaf")).progress
		)

		local raising = earning({ value = false }, function()
			error("no dots today")
		end)
		assert.is_nil(assert(model(raising):Stage("hunts.frame.leaf")).progress)
		assert.are.equal(1, #raising.reported)
		assert.matches("no dots today", raising.reported[1])
	end)
end)

-- Hunts off this session: its cached goods from an earlier one, with Velvet bought and Gold earned then, and the
-- Ledger On with its bindings. Logged in.
local huntsOff

describe("The Curio Shop's Put away group", function()
	function huntsOff()
		local fake, handles = coreWithModules("Hunts")
		ledgerBindings(handles.Ledger)
		local function cached(id, name, fields)
			local row = {
				name = name,
				slot = "hunts.cover",
				slotLabel = "Notebook cover",
				category = "Trackers",
				module = "Hunts",
			}
			for key, value in pairs(fields) do
				row[key] = value
			end
			fake.global.goods[id] = row
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
		"lists an off Module's purchased goods last, not its default, goods for sale or earned goods, saying Yours to"
			.. " keep (SHOP-R35, SHOP-R24)",
		function()
			local fake = huntsOff()

			local groups = model(fake):List({})

			assert.are.same(
				afterCore({
					"Journal binding (1 of 2)",
					"  ledger.binding.oak In use",
					"  ledger.binding.lapis 900" .. " [red]",
					"Put away: Module off (Yours to keep)",
					"  hunts.cover.velvet Hunts is off",
				}),
				outline(groups)
			)
			local putAway = groups[#groups]
			assert.is_true(putAway.putAway)
			assert.are.same(
				{ id = "hunts.cover.velvet", name = "Velvet", icon = 134939, state = "putAway", tag = "Hunts is off" },
				putAway.rows[1]
			)
			assert.are.same({
				{ category = "Announcements", label = "Announcements" },
				{ category = "Crests", label = "Crests" },
				{ category = "Books", label = "Books" },
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
		assert.are.equal(1, putAway({ filter = "owned" }))
		assert.are.equal(0, putAway({ filter = "notOwned" }))
		assert.are.equal(0, putAway({ filter = "canAfford" }))
		assert.are.equal(1, putAway({ category = "Trackers" }))
		assert.are.equal(0, putAway({ category = "Books" }))
	end)
end)

describe("Selecting a good", function()
	it("selects a live good and an owned good put away; nothing for anything else (SHOP-R40, SHOP-R35)", function()
		local fake = huntsOff()
		local shop = model(fake)

		assert.are.equal("ledger.binding.lapis", shop:Select("ledger.binding.lapis"))
		assert.are.equal("core.toaststyle.page", shop:Select("core.toaststyle.page"))
		assert.are.equal("hunts.cover.velvet", shop:Select("hunts.cover.velvet"))
		assert.is_nil(shop:Select("hunts.cover.tide")) -- for sale, of a Module off
		assert.is_nil(shop:Select("hunts.cover.plain")) -- a default of a Module off
		assert.is_nil(shop:Select("hunts.cover.gold")) -- earned, owned, of a Module off: the Collection's (SHOP-R40)
		assert.is_nil(shop:Select("nobody.nothing"))
		assert.is_nil(shop:Select(42))
		assert.is_nil(shop:Select(nil))
	end)
end)

describe("One good's row", function()
	it("is the row the list shows for it, whatever narrows the list; nothing for a good not shown", function()
		local fake = huntsOff()
		local shop = model(fake)

		local tornPage = assert(shop:Row("core.toaststyle.page"))
		assert.are.same({ "equipped", "In use" }, { tornPage.state, tornPage.tag })
		assert.are.same(
			{ id = "ledger.binding.lapis", name = "Lapis", state = "short", price = "900", short = true },
			shop:Row("ledger.binding.lapis")
		)
		assert.are.equal("putAway", assert(shop:Row("hunts.cover.velvet")).state)
		assert.is_nil(shop:Row("hunts.cover.tide"))
		assert.is_nil(shop:Row(42))
	end)
end)

describe("The Curio Shop's stage", function()
	-- Core's own goods, Hunts' covers (Gold earned while `earned.value`, on sale at its fallback price) and the
	-- Ledger's bindings, logged in, with a balance of `balance`.
	local function stageReady(balance, earned)
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, earned or { value = false }, 1)
		ledgerBindings(handles.Ledger)
		fake.login()
		handles.Ledger:ReportCoinsEarned(balance)
		return fake, handles
	end

	it(
		"shows a good for sale with its name, slot, owner, description, price and Buy (wallet-and-shop.md › UI)",
		function()
			local fake = stageReady(1000)

			local stage = assert(model(fake):Stage("hunts.cover.velvet"))

			assert.are.same({
				id = "hunts.cover.velvet",
				name = "Velvet",
				icon = 134939,
				slotLine = "Notebook cover · Hunts",
				description = "Soft to the touch.",
				state = "forSale",
				buy = "Buy for 400",
				tags = {},
				notes = {},
			}, stage)
		end
	)

	it("shows what more a good the balance can't cover needs, its price in red (wallet-and-shop.md › UI)", function()
		local fake = stageReady(650)

		local stage = assert(model(fake):Stage("ledger.binding.lapis"))

		assert.are.same(
			{ "Journal binding · Ledger", "short", true, "Buy for 900", "250 more Coins" },
			{ stage.slotLine, stage.state, stage.short, stage.buy, stage.needed }
		)
		assert.are.equal("350 more Coins", assert(model(stageReady(50)):Stage("hunts.cover.velvet")).needed)
	end)

	it(
		"shows Owned and Use for an owned good, In use for the equipped one, and default (wallet-and-shop.md › UI)",
		function()
			local fake = stageReady(0)
			local shop = model(fake)

			local tornPage, plain = assert(shop:Stage("core.toaststyle.page")), assert(shop:Stage("hunts.cover.plain"))

			assert.are.same(
				{ "equipped", { "In use", "default" }, "Toast style · Pagle" },
				{ tornPage.state, tornPage.tags, tornPage.slotLine }
			)
			assert.is_nil(tornPage.use)
			assert.is_nil(tornPage.buy)
			assert.are.equal("Notebook cover · Hunts", plain.slotLine)

			fake.setPurchased({ ["core.toaststyle.ripple"] = true })
			fake.Pagle.SetEquipped("core.toaststyle", "core.toaststyle.ripple")
			shop = model(fake)
			local ripple = assert(shop:Stage("core.toaststyle.ripple"))
			tornPage = assert(shop:Stage("core.toaststyle.page"))

			assert.are.same({ "equipped", { "In use" } }, { ripple.state, ripple.tags })
			assert.are.same({ "owned", { "default" }, true }, { tornPage.state, tornPage.tags, tornPage.use })
			fake.setPurchased({ ["core.toaststyle.ripple"] = true, ["core.toaststyle.lanternglow"] = true })
			local lantern = assert(model(fake):Stage("core.toaststyle.lanternglow"))
			assert.are.same({ "owned", { "Owned" }, true }, { lantern.state, lantern.tags, lantern.use })
			assert.is_nil(lantern.buy)
		end
	)

	it(
		'shows an earned good on sale at its fallback price with its earnedText, then "Or buy it for N", and Buy;'
			.. " owned, it shows the earnedText and Use (SHOP-R24, SHOP-R28, wallet-and-shop.md › UI)",
		function()
			local earned = { value = false }
			local fake, handles = stageReady(5000, earned)

			local gold = assert(model(fake):Stage("hunts.cover.gold"))
			assert.are.same(
				{ "forSale", {}, { "Every Hunt done", "Or buy it for 400" }, "Buy for 400" },
				{ gold.state, gold.tags, gold.notes, gold.buy }
			)

			earned.value = true
			handles.Hunts:RefreshGoods()
			gold = assert(model(fake):Stage("hunts.cover.gold"))
			assert.are.same(
				{ "owned", { "Owned" }, { "Every Hunt done" }, true },
				{ gold.state, gold.tags, gold.notes, gold.use }
			)
			assert.is_nil(gold.buy)
		end
	)

	it("has no stage for an earned good before its fallback date (SHOP-R24)", function()
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, { value = false })
		fake.login()

		assert.is_nil(model(fake):Stage("hunts.cover.gold"))
		assert.is_nil(model(fake):Entry("hunts.cover.gold"))
		assert.is_nil(model(fake):Select("hunts.cover.gold"))
	end)

	it("hands over the good's preview and icon (wallet-and-shop.md › UI)", function()
		local fake, handles = coreWithModules()
		local function preview() end
		handles.Hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
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

	it("is nil for a good the Curio Shop doesn't show (SHOP-R40)", function()
		local fake = huntsOff()

		assert.is_nil(model(fake):Stage("hunts.cover.tide"))
		assert.is_nil(model(fake):Stage(nil))
	end)
end)

describe("Buy on the stage", function()
	-- The Ledger's bindings and Hunts' covers (Gold earned while `earned.value`), logged in and in the world, every
	-- projection caught up, with the Ledger's `balance` Coins.
	local function buyReady(balance, earned)
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, earned or { value = false }, 1)
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
			local shop = model(buyReady(400))

			assert.is_true(assert(shop:Stage("hunts.cover.velvet")).canBuy) -- 400 covers 400
			assert.is_true(assert(shop:Stage("core.toaststyle.ripple")).canBuy)
		end
	)

	it(
		"is disabled for an owned good, a default, and a good the balance doesn't cover, and enabled for an earned good"
			.. " on sale at its fallback price until it is earned (SHOP-R13, SHOP-R28)",
		function()
			local earned = { value = false }
			local fake, handles = buyReady(899, earned)
			fake.setPurchased({ ["core.toaststyle.ripple"] = true })
			local shop = model(fake)

			for _, goodID in ipairs({
				"core.toaststyle.ripple", -- bought
				"hunts.cover.plain", -- the default
				"ledger.binding.lapis", -- 900, one more needed
			}) do
				assert.are.same({ goodID }, { goodID, assert(shop:Stage(goodID)).canBuy, shop:Purchase(goodID) })
			end
			assert.is_true(assert(shop:Stage("hunts.cover.gold")).canBuy) -- earned, not yet: 400 at its fallback
			assert.are.equal(400, assert(shop:Purchase("hunts.cover.gold")).price)
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
			local fake, handles = coreWithModules()
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
			local fake, handles = coreWithModules()
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
				amount = "400",
				left = "1,050",
			}, model(fake):Purchase("hunts.cover.velvet"))
			assert.is_nil(model(fake):Purchase("hunts.cover.none"))
			assert.is_nil(model(fake):Purchase(nil))
		end
	)
end)

describe("Buying", function()
	-- Hunts' covers, logged in and in the world, with the Ledger's `balance` Coins, and a Session open (one Cast), so a
	-- moment or a summary line would land in it.
	local function readyToBuy(balance)
		local fake, handles = coreWithModules()
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
			local fake = readyToBuy(300)
			local Pagle = fake.Pagle
			local before = #fake.catchLog.data.entries
			local changed = looks(fake)

			assert.is_true(fake.ns.shop.Buy("core.toaststyle.ripple", true))

			local entries = fake.catchLog.data.entries
			assert.are.equal(before + 1, #entries)
			-- Ada at the fake's server time, tie 1 after the Cast in the same second (LOG-R12).
			assert.are.equal(purchaseEntry(SERVER_TIME, "core.toaststyle.ripple", 250, 1), entries[#entries])
			assert.are.equal(50, Pagle.GetBalance().balance)
			assert.is_true(Pagle.IsOwned("core.toaststyle.ripple"))
			assert.are.equal("core.toaststyle.ripple", Pagle.GetEquipped("core.toaststyle"))
			assert.are.same({ "core.toaststyle core.toaststyle.ripple" }, changed)
		end
	)

	it("leaves the look as it was without Use it now: owned, not equipped (wallet-and-shop.md › UI: Buy)", function()
		local fake = readyToBuy(300)
		local changed = looks(fake)

		assert.is_true(fake.ns.shop.Buy("core.toaststyle.ripple", false))

		assert.is_true(fake.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal("core.toaststyle.page", fake.Pagle.GetEquipped("core.toaststyle"))
		assert.are.same({}, changed)
	end)

	it("equips an owned good with Use, and nothing for a good not owned or not known (SHOP-R32)", function()
		local fake = readyToBuy(300)
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
		local fake = readyToBuy(300)
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
			local fake, handles = readyToBuy(300)
			local before = #fake.catchLog.data.entries

			assert.is_false(fake.ns.shop.Buy("hunts.cover.velvet", true)) -- 400, with 200
			assert.is_true(fake.ns.shop.Buy("core.toaststyle.ripple", false))
			assert.is_false(fake.ns.shop.Buy("core.toaststyle.ripple", false)) -- owned now
			local during
			handles.Hunts:NewProjection({
				db = {},
				rulesVersion = 1,
				reset = function()
					return {}
				end,
				apply = function() end,
				done = function()
					during = fake.ns.shop.Buy("core.toaststyle.lanternglow", true) -- in Hunts' first build
				end,
			})

			assert.is_false(during)
			assert.are.equal(before + 1, #fake.catchLog.data.entries)
			assert.is_false(fake.Pagle.IsOwned("core.toaststyle.lanternglow"))
			assert.are.equal(50, fake.Pagle.GetBalance().balance)
		end
	)
end)

-- Two of the Ledger's earned goods in Core's toast style slot, open to earned goods (SHOP-R23): The Old Oak, earned
-- while `earned.value`, and The Desert Sun, never; each earnedText a function giving `texts[id]` (the row's tag, then
-- the stage's note) and counting its calls in `texts.calls`. Neither has a preview of its own, and both are on sale at
-- tier 2's price from a fallback date past (SHOP-R24, SHOP-R28), so the shop lists them.
local function ledgerStyles(ledger, earned, texts)
	texts = texts
		or {
			["ledger.toaststyle.oak"] = { "Expert · 88%", "Earned when Elwynn reaches Master." },
			["ledger.toaststyle.sun"] = { "Unfished", "Earned when Tanaris reaches Master. Catch anything there." },
		}
	texts.calls = texts.calls or 0
	local function style(id, name, isEarned)
		ledger:RegisterGood({
			id = id,
			slot = "core.toaststyle",
			name = name,
			isEarned = isEarned,
			earnedText = function()
				texts.calls = texts.calls + 1
				local given = texts[id] or {}
				return given[1], given[2]
			end,
			fallbackTier = 2,
			fallbackFrom = 1,
		})
	end
	style("ledger.toaststyle.oak", "The Old Oak", function()
		return earned.value
	end)
	style("ledger.toaststyle.sun", "The Desert Sun", function()
		return false
	end)
	return texts
end

describe("Another Module's earned goods in a Core slot open to them", function()
	-- Core, the Ledger's two toast styles in Core's toast style slot (The Old Oak earned while `earned.value`), logged in.
	local function styled(earned, texts)
		local fake, handles = coreWithModules()
		texts = ledgerStyles(handles.Ledger, earned, texts)
		fake.login()
		return fake, handles, texts
	end

	it(
		"lists them in the slot after its own, counted, each not yet earned with its earnedText function's first text beside its fallback price (SHOP-R22, SHOP-R23, SHOP-R28)",
		function()
			local fake = styled({ value = true })

			assert.are.same(
				joined(
					joined({ "Toast style (2 of 27)", "  core.toaststyle.page In use" }, saleLines("toaststyle", 0)),
					{
						"  ledger.toaststyle.oak Owned",
						"  ledger.toaststyle.sun Unfished [red]",
					}
				),
				outline({ model(fake):List({ category = "Announcements" })[1] })
			)
		end
	)

	it(
		"shows the function's second text on the stage, then \"Or buy it for N\", its owner the good's Module (SHOP-R22, SHOP-R23, SHOP-R28)",
		function()
			local fake = styled({ value = false })

			local stage = model(fake):Stage("ledger.toaststyle.oak")

			assert.are.same({
				"short",
				"Toast style · Ledger",
				{ "Earned when Elwynn reaches Master.", "Or buy it for 400" },
				{},
				"Buy for 400",
			}, { stage.state, stage.slotLine, stage.notes, stage.tags, stage.buy })
		end
	)

	it(
		"calls the function each time it draws a good not owned, and never for an owned one (SHOP-R22, SHOP-R30)",
		function()
			local earned = { value = false }
			local fake, handles, texts = styled(earned)
			local before = texts.calls

			model(fake):Row("ledger.toaststyle.oak")
			model(fake):Row("ledger.toaststyle.oak")
			texts["ledger.toaststyle.oak"] = { "Master · 100%" }
			local row = model(fake):Row("ledger.toaststyle.oak")
			assert.are.equal(before + 3, texts.calls)
			assert.are.equal("Master · 100%", row.tag) -- never cached

			earned.value = true
			handles.Ledger:RefreshGoods()
			local calls = texts.calls
			local owned = model(fake):Stage("ledger.toaststyle.oak")

			assert.are.equal(calls, texts.calls)
			assert.are.same({ "owned", { "Owned" }, {} }, { owned.state, owned.tags, owned.notes })
		end
	)

	it(
		"has no earned note on the stage when the function gives none, nor a tag on the row when it gives no text (SHOP-R22, SHOP-R28)",
		function()
			local fake = styled({ value = false }, {
				["ledger.toaststyle.oak"] = { "Expert · 88%" },
				["ledger.toaststyle.sun"] = {},
			})
			local shop = model(fake)

			assert.are.same({ "Or buy it for 400" }, shop:Stage("ledger.toaststyle.oak").notes)
			assert.is_nil(shop:Row("ledger.toaststyle.sun").tag)
		end
	)

	it(
		"draws a good with no preview of its own with the slot's preview, Core's, and one with its own with that (SHOP-R25)",
		function()
			local fake, handles = coreWithModules()
			local drawn = {}
			fake.ns.RegisterCoreSlot({
				id = "core.plate",
				label = "Plate",
				category = "Announcements",
				openToEarned = true,
				preview = function(stage, good)
					drawn[#drawn + 1] = { stage, good.id, good.icon }
				end,
			})
			fake.ns.RegisterCoreGood({ id = "core.plate.plain", slot = "core.plate", name = "Plain", default = true })
			local own = function() end
			handles.Ledger:RegisterGood({
				id = "ledger.plate.oak",
				slot = "core.plate",
				name = "Oak",
				icon = 134939,
				isEarned = function()
					return false
				end,
				fallbackTier = 2,
				fallbackFrom = 1,
			})
			handles.Ledger:RegisterGood({
				id = "ledger.plate.own",
				slot = "core.plate",
				name = "Own",
				isEarned = function()
					return false
				end,
				fallbackTier = 2,
				fallbackFrom = 1,
				preview = own,
			})
			fake.login()
			local shop = model(fake)

			shop:Stage("ledger.plate.oak").preview("stage")
			shop:Stage("core.plate.plain").preview("other") -- Core's own, registered here without one, too
			assert.are.same({ { "stage", "ledger.plate.oak", 134939 }, { "other", "core.plate.plain" } }, drawn)
			assert.are.equal(own, shop:Stage("ledger.plate.own").preview)
		end
	)

	it(
		"lists none while its Module is off, owned or not, the Collection's to show put away (SHOP-R35, SHOP-R24)",
		function()
			local fake = coreWithModules("Ledger")
			for id, cached in pairs({
				["ledger.toaststyle.oak"] = { name = "The Old Oak", earned = true },
				["ledger.toaststyle.sun"] = { name = "The Desert Sun", earned = false },
			}) do
				cached.slot, cached.slotLabel, cached.category, cached.module =
					"core.toaststyle", "Toast style", "Announcements", "Ledger"
				fake.global.goods[id] = cached
			end
			fake.login()
			local shop = model(fake)

			local groups = shop:List({ category = "Announcements" })

			for _, group in ipairs(groups) do
				assert.is_nil(group.putAway) -- no Put away group
			end
			assert.is_nil(shop:Select("ledger.toaststyle.oak"))
			assert.is_nil(shop:Select("ledger.toaststyle.sun"))
			assert.are.same(
				{ true, true },
				{ shop:IsEarnedUnlisted("ledger.toaststyle.oak"), shop:IsEarnedUnlisted("ledger.toaststyle.sun") }
			)
			assert.is_false(shop:IsEarnedUnlisted("core.toaststyle.page"))
		end
	)
end)

describe("The earned crests, which Look and Feel equips and the Curio Shop doesn't list", function()
	-- The first fish crest (VAR-R12), and the second.
	local FISH = "core.crest.fish." .. FISH_CREST_SPECIES[1]
	local OTHER_FISH = "core.crest.fish." .. FISH_CREST_SPECIES[2]

	-- Core with the Ledger's two zone crests (The Old Oak earned while `earned.value`, LED-R113) and Core's fish crests,
	-- logged in, the first fish crest earned as its cache says (SHOP-R30). Returns the fake and the zone crests' texts.
	local function crested(earned)
		local fake, handles = coreWithModules()
		local texts = ledgerCrests(handles.Ledger, earned)
		fake.login()
		fake.global.goods[FISH].earned = true
		assert.is_true(fake.Pagle.IsOwned(FISH))
		return fake, texts
	end

	it(
		"lists only the crest slot's default and its crests for sale, never an earned one, owned or in use, nor counts"
			.. " them (SHOP-R25, SHOP-R27)",
		function()
			local fake = crested({ value = true })
			fake.ns.RegisterCoreGood({ id = "core.crest.peaks", slot = "core.crest", name = "Peaks", tier = 2 })
			assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.elwynn"))
			local shop = model(fake)

			assert.are.same(
				{ "Crests (1 of 2)", "  core.crest.plain default", "  core.crest.peaks 400" .. " [red]" },
				outline(shop:List({ category = "Crests" }))
			)
			assert.are.same(
				{ "Crests (1 of 2)", "  core.crest.plain default" },
				outline(shop:List({ category = "Crests", filter = "owned" }))
			)
			assert.are.same({}, shop:List({ search = "oak" }))
			assert.are.equal("ledger.crest.elwynn", fake.Pagle.GetEquipped("core.crest"), "still in use")
		end
	)

	it(
		"has no row, stage or purchase for one, nor selects it, so the shop opened on one selects nothing, and never"
			.. " asks its texts (SHOP-R22, SHOP-R40)",
		function()
			local fake, texts = crested({ value = true })
			local shop = model(fake)
			local before = texts.calls

			for _, id in ipairs({ "ledger.crest.elwynn", "ledger.crest.tanaris", FISH, OTHER_FISH }) do
				assert.are.same({ id, "none" }, {
					id,
					(shop:Select(id) or shop:Row(id) or shop:Stage(id) or shop:Purchase(id)) and "some" or "none",
				})
			end
			shop:List({})
			assert.are.equal(before, texts.calls)
			assert.are.equal("core.crest.plain", shop:Select("core.crest.plain"))
		end
	)

	it("puts none away while its Module is off (SHOP-R35)", function()
		local fake = coreWithModules("Ledger")
		fake.global.goods["ledger.crest.elwynn"] = {
			name = "The Old Oak",
			slot = "core.crest",
			slotLabel = "Crests",
			category = "Crests",
			module = "Ledger",
			earned = true,
		}
		fake.login()
		local shop = model(fake)

		assert.are.same(CREST_LINES, outline(shop:List({ category = "Crests" })), "nothing put away")
		assert.is_nil(shop:Select("ledger.crest.elwynn"))
	end)

	it(
		"leaves them to Look and Feel, whose crest dropdown lists the owned ones, none more in the shop (SET-R51)",
		function()
			local fake = crested({ value = true })

			local values = {}
			for _, choice in ipairs(fake.ns.SlotChoices(fake.ns.goods, "core.crest")) do
				values[#values + 1] = choice.value
			end
			table.sort(values)

			assert.are.same({ FISH, "core.crest.plain", "ledger.crest.elwynn" }, values)
			assert.are.equal(0, fake.ns.SlotMoreInShop(fake.ns.goods, "core.crest"))
		end
	)
end)

describe("The Curio crate", function()
	local CRATE, FOIL = "core.crate", "core.toaststyle.foil"
	local TOP = 4294967295 -- the highest hash: a Curio crate

	-- Core with Hunts' covers and the Ledger's bindings, logged in and in the world, with the Ledger's `balance` Coins,
	-- and a Session open (one Cast), so a moment or a summary line would land in it. `owned` goods are bought first,
	-- each with a U1 at price 0 the projection applies live (SHOP-R10).
	local function crated(balance, owned)
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, { value = false })
		ledgerBindings(handles.Ledger)
		fake.login()
		fake.enterWorld()
		for _, good in ipairs(owned or {}) do
			fake.ns.RecordPurchase(good, 0)
		end
		handles.Ledger:ReportCoinsEarned(balance)
		fake.playCast("caught", { { itemID = 6358, quantity = 1 } })
		fake.nextFrame()
		return fake, handles
	end

	-- The pool's goods of crate tier `tier`.
	local function poolOf(fake, tier)
		local ids = {}
		for _, row in ipairs(fake.ns.CRATE_POOL) do
			if row.tier == tier then
				ids[#ids + 1] = row.id
			end
		end
		return ids
	end

	-- Every crate hashes to `h` from now on (the fake's ns is the one the draw reads), and the pool is `pool`.
	local function rigged(fake, h, pool)
		fake.ns.SizeHash = function()
			return h
		end
		fake.ns.CRATE_POOL = pool
	end

	-- The odds lines as the stage writes them: name, goods left or payback, chance.
	local function lines(stage)
		local out = {}
		for i, odds in ipairs(stage.odds) do
			out[i] = { odds.name, odds.detail, odds.chance }
		end
		return out
	end

	it(
		"has its own row, at the very top, whichever chip is on, never a slot's (SHOP-R50, wallet-and-shop.md › UI)",
		function()
			local fake = crated(300)
			local shop = model(fake)
			local row = {
				id = CRATE,
				name = "Curio crate",
				icon = fake.ns.CRATE_ICON,
				state = "short",
				price = "1,500",
				short = true,
			}

			assert.are.same(row, shop:Crate({}))
			for _, chip in ipairs(shop:Chips()) do
				assert.are.same(row, shop:Crate({ category = chip.category }), chip.category)
			end
			for _, filter in ipairs(fake.ns.SHOP_FILTERS) do
				assert.are.same(row, shop:Crate({ filter = filter }), filter)
			end
			assert.are.same(row, shop:Crate({ search = "CRATE" }))
			assert(shop:Crate({ search = "binding" }) == nil, "a search its label doesn't match leaves it out")
			for _, group in ipairs(shop:List({})) do
				for _, listed in ipairs(group.rows) do
					assert.are_not.equal(CRATE, listed.id, "not in a slot's group")
				end
			end
			assert.are.equal(CRATE, shop:Select(CRATE))
			assert.are.same(row, shop:Row(CRATE))
		end
	)

	it("shows its price in white once the balance covers 1,500 (SHOP-R50, SHOP-R54)", function()
		local fake = crated(1500)

		local row = model(fake):Crate({})

		assert.are.same({ "forSale", "1,500" }, { row.state, row.price })
		assert.is_nil(row.short)
	end)

	it(
		"shows on the stage a line for each crate tier: its name and colour, the goods it has left, its chance (SHOP-R54)",
		function()
			local fake = crated(3500)

			local stage = model(fake):Stage(CRATE)

			assert.are.same({
				{ "Plain", "28 left", "40%" },
				{ "Fine", "35 left", "26%" },
				{ "Lively", "27 left", "16%" },
				{ "Showpiece", "9 left", "10%" },
				{ "Marvel", "2 left", "5%" },
				{ "Heirloom", "pays back 1,500", "2.5%" },
				{ "Curio", "1 left", "0.5%" },
			}, lines(stage))
			local colors = {}
			for i, odds in ipairs(stage.odds) do
				colors[i] = { odds.color[1] * 255, odds.color[2] * 255, odds.color[3] * 255 }
				assert.are.equal(fake.ns.CRATE_TIERS[i], odds.tier)
			end
			assert.are.same({ 0xe9, 0xe6, 0xdf }, colors[1])
			assert.are.same({ 0x3e, 0xd3, 0x5a }, colors[2])
			assert.are.same({ 0x3b, 0x86, 0xff }, colors[3])
			assert.are.same({ 0xb0, 0x5c, 0xff }, colors[4])
			assert.are.same({ 0xec, 0x3a, 0x3f }, colors[5])
			assert.are.same({ 0xff, 0x8a, 0x1c }, colors[6])
			assert.are.same({ 0xff, 0xd0, 0x4a }, colors[7])
		end
	)

	it(
		"counts a tier's goods left as the Angler buys and wins them, and says what an empty one pays back (SHOP-R54)",
		function()
			local owned = poolOf(crated(0), 1)
			for _, id in ipairs(poolOf(crated(0), 5)) do
				owned[#owned + 1] = id
			end
			owned[#owned + 1] = FOIL
			local fake = crated(3500, owned)
			local first = poolOf(fake, 2)
			fake.ns.RecordPurchase(first[1], 0)

			local stage = model(fake):Stage(CRATE)

			assert.are.same({
				{ "Plain", "pays back 250", "40%" },
				{ "Fine", "34 left", "26%" },
				{ "Lively", "27 left", "16%" },
				{ "Showpiece", "9 left", "10%" },
				{ "Marvel", "pays back 1,500", "5%" },
				{ "Heirloom", "pays back 1,500", "2.5%" },
				{ "Curio", "pays back 1,500", "0.5%" },
			}, lines(stage))
			assert(stage.pity == nil, "no crate-only good is a candidate")
		end
	)

	it("keeps the crate's stage as a name, its kind, its lore, its odds and Buy (SHOP-R54)", function()
		local fake = crated(3500)

		local stage = model(fake):Stage(CRATE)

		assert.are.same(
			{ CRATE, "Curio crate", "A crate of looks", "forSale", true, "Buy for 1,500", true },
			{ stage.id, stage.name, stage.slotLine, stage.state, stage.crate, stage.buy, stage.canBuy }
		)
		assert.are.same({ {}, {} }, { stage.tags, stage.notes })
		assert.are.equal(
			"Packed down at the docks by someone who never says what's in them. Nearly every crate holds one look you"
				.. " don't yet own, rarer the deeper you dig. Straw, mostly.",
			stage.description
		)
		assert.is_nil(stage.caption)
	end)

	it(
		'writes the pity line: "A Curio within N more crates", N a hundred less the crates since one (SHOP-R52, SHOP-R54)',
		function()
			local fake = crated(300000)
			rigged(fake, 0, { { id = FOIL, tier = "curio", kind = "toaststyle" } })
			assert.are.equal("A Curio within 100 more crates", model(fake):Stage(CRATE).pity)

			for _ = 1, 3 do
				assert.is_true(fake.ns.shop.Buy(CRATE, false))
			end
			assert.are.equal("A Curio within 97 more crates", model(fake):Stage(CRATE).pity)
			for _ = 1, 95 do
				assert.is_true(fake.ns.shop.Buy(CRATE, false))
			end
			assert.are.equal("A Curio within 2 more crates", model(fake):Stage(CRATE).pity)
			assert.is_true(fake.ns.shop.Buy(CRATE, false))
			assert.are.equal("A Curio in the next crate", model(fake):Stage(CRATE).pity)
			assert.are.equal(99, fake.ns.walletSnapshot.dry)

			local bought, result = fake.ns.shop.Buy(CRATE, false) -- the 100th crate, whatever the hash says
			assert.is_true(bought)
			assert.are.same({ tier = "curio", good = FOIL, crateOnly = true }, result)
			assert(model(fake):Stage(CRATE) == nil, "the pool is empty: the crate has left the shop")
		end
	)

	it(
		'enables Buy while a pool good is a candidate and the balance covers it; the bill has no "Use it now" (SHOP-R13, SHOP-R54)',
		function()
			local fake = crated(3500)
			assert.is_true(model(fake):Stage(CRATE).canBuy)
			assert.are.same({
				id = CRATE,
				crate = true,
				name = "Curio crate",
				icon = fake.ns.CRATE_ICON,
				price = 1500,
				amount = "1,500",
				left = "2,000",
				question = "Open a Curio crate?",
				fine = "One look you don't own yet, by chance; the chances are on the crate.",
			}, model(fake):Purchase(CRATE))
			assert(model(fake):Purchase(CRATE).slot == nil, "no slot to use it in: there is no Use it now")

			local short = model(crated(1499)):Stage(CRATE)
			assert.are.same({ true, "1 more Coins", nil }, { short.short, short.needed, short.canBuy })
			assert(model(crated(1499)):Purchase(CRATE) == nil, "the balance short")
		end
	)

	it("leaves the list once every pool good is owned, and comes back when the pool grows (SHOP-R54)", function()
		local owned = {}
		for _, row in ipairs(crated(0).ns.CRATE_POOL) do
			owned[#owned + 1] = row.id
		end
		local fake = crated(5000, owned)
		local shop = model(fake)

		assert.is_nil(shop:Crate({}))
		assert.is_nil(shop:Crate({ search = "crate" }))
		assert.is_nil(shop:Row(CRATE))
		assert.is_nil(shop:Select(CRATE))
		assert.is_nil(shop:Stage(CRATE))
		assert.is_nil(shop:Purchase(CRATE))
		local first = shop:List({})[1].rows[1].id
		assert.are.equal(first, shop:Reselect(CRATE, {}), "the stage shows the list's first good")
		assert.are.equal(first, fake.ns.ShopModel():Reselect(CRATE, { filter = "all" }))
		local before = #fake.catchLog.data.entries
		assert.is_false(fake.ns.shop.Buy(CRATE, false))
		assert.are.equal(before, #fake.catchLog.data.entries)

		local pool = fake.ns.CRATE_POOL
		local grown = { unpack(pool) }
		grown[#grown + 1] = { id = "core.binding.later", tier = 1, kind = "binding", since = SERVER_TIME - 100 }
		fake.ns.CRATE_POOL = grown
		shop = model(fake)

		assert.are.equal(CRATE, shop:Select(CRATE))
		assert.is_not_nil(shop:Crate({}))
		assert.are.same({ "Plain", "1 left", "40%" }, lines(shop:Stage(CRATE))[1])
		assert.are.equal(CRATE, shop:Reselect(CRATE, {}))
		fake.ns.CRATE_POOL = pool
	end)

	it("keeps the row for a pool good that joins later, only once its release has come (SHOP-R53)", function()
		local owned = {}
		for _, row in ipairs(crated(0).ns.CRATE_POOL) do
			owned[#owned + 1] = row.id
		end
		local fake = crated(5000, owned)
		local pool = fake.ns.CRATE_POOL
		local grown = { unpack(pool) }
		grown[#grown + 1] = { id = "core.binding.later", tier = 1, kind = "binding", since = SERVER_TIME + 1000 }
		fake.ns.CRATE_POOL = grown

		assert(model(fake):Crate({}) == nil, "a release not yet out adds no candidate")
		fake.ns.CRATE_POOL = pool
	end)

	it(
		"buys one crate with one U1 of core.crate at 1,500 and opens it at once: what it gave is owned, not in use,"
			.. " whatever Use it now says; no Announcement (SHOP-R10, SHOP-R50, SHOP-R51, SHOP-R55)",
		function()
			local fake = crated(3500)
			local Pagle = fake.Pagle
			local before, announced = #fake.catchLog.data.entries, #fake.announcements
			local inUse = Pagle.GetEquipped("core.toaststyle")

			local bought, result = fake.ns.shop.Buy(CRATE, true)

			assert.is_true(bought)
			local entries = fake.catchLog.data.entries
			assert.are.equal(before + 1, #entries)
			assert.are.equal(purchaseEntry(SERVER_TIME, CRATE, 1500, 1), entries[#entries])
			local guid = fake.catchLog.data.characters[1].guid
			local entryID = ("%s-%d-1"):format(guid, SERVER_TIME)
			assert.are.same(fake.ns.CrateRoll(entryID, {}, 0, SERVER_TIME, 1500), result)
			local crates = fake.ns.walletSnapshot.crates
			assert.are.same({ result.good or result.payback }, crates)
			assert.are.equal(3500 - 1500 + (result.payback or 0), Pagle.GetBalance().balance)
			if result.good then
				assert.is_true(Pagle.IsOwned(result.good))
			end
			assert.are.equal(inUse, Pagle.GetEquipped("core.toaststyle"))
			fake.nextFrame()
			assert.are.equal(announced, #fake.announcements)
		end
	)

	it(
		"gives a payback of a tier with no good left, and the purse is out only the difference (SHOP-R11, SHOP-R51)",
		function()
			local fake = crated(3500)
			-- the hash rolls tier 2, whose goods are all owned; tier 5 still has one
			rigged(fake, 1717986919, { { id = "core.toaststyle.storm", tier = 5, kind = "toaststyle" } })

			local bought, result = fake.ns.shop.Buy(CRATE, false)

			assert.is_true(bought)
			assert.are.same({ tier = 2, payback = 400 }, result)
			assert.are.same({ 400 }, fake.ns.walletSnapshot.crates)
			assert.are.equal(3500 - 1100, fake.Pagle.GetBalance().balance)
			assert(model(fake):Crate({}) ~= nil, "a payback gives no good: the row stays")
		end
	)

	it(
		"gives a crate-only good by Curio, and keeps a good it can't show on the card of the crate (SHOP-R50, SHOP-R55)",
		function()
			local fake = crated(3500)
			rigged(fake, TOP, { { id = FOIL, tier = "curio", kind = "toaststyle" } })

			local _, result = fake.ns.shop.Buy(CRATE, false)

			assert.are.same({ tier = "curio", good = FOIL, crateOnly = true }, result)
			assert.is_true(fake.Pagle.IsOwned(FOIL))
		end
	)

	it("never gives a good owned already, with only one left it gives that one (SHOP-R50, SHOP-R51)", function()
		local pool = crated(0).ns.CRATE_POOL
		local owned = {}
		for i = 2, #pool do
			owned[#owned + 1] = pool[i].id
		end
		local fake = crated(5000, owned)
		fake.ns.SizeHash = function(id)
			return id:sub(-5) == "/good" and 12345 or 0
		end
		-- tier 1 is the hash's: its good, the pool's first, is the only one left
		local first = pool[1]
		assert.are.equal(1, first.tier)

		local bought, result = fake.ns.shop.Buy(CRATE, false)

		assert.is_true(bought)
		assert.are.same({ tier = 1, good = first.id }, result)
		assert.is_nil(model(fake):Crate({}))
	end)

	describe("result card", function()
		it("shows a good as its name, its crate tier's name and colour, and offers Use it now (SHOP-R55)", function()
			local fake = crated(3500)
			local good = fake.ns.goods:Good("core.toaststyle.ship")
			fake.ns.RecordPurchase(good.id, 0)

			local card = model(fake):CrateResult({ tier = 2, good = good.id })

			assert.are.same(
				{ good.name, "Fine", good.id, good.id, true, good.icon },
				{ card.title, card.tier, card.good, card.select, card.canUse, card.icon }
			)
			assert.are.equal(0x3e / 255, card.color[1])
			assert.is_nil(card.payback)
			assert.is_nil(card.line)
		end)

		it('shows a payback as the coin card: "+N Coins", the tier\'s name, and no good to use (SHOP-R55)', function()
			local fake = crated(3500)

			local card = model(fake):CrateResult({ tier = "curio", payback = 1500 })

			assert.are.same(
				{ "+1,500 Coins", "Curio", 1500, CRATE, false, fake.ns.CRATE_COIN_ICON },
				{ card.title, card.tier, card.payback, card.select, card.canUse, card.icon }
			)
			local plain = model(fake):CrateResult({ tier = 1, payback = 250 })
			assert.are.same({ "+250 Coins", "Plain" }, { plain.title, plain.tier })
		end)

		it(
			'turns a good no Module has registered, with no cache entry, over to "A new look", the crate staying selected (SHOP-R50)',
			function()
				local fake = crated(3500)
				local id = "stats.trackerframe.greenbar"
				fake.ns.RecordPurchase(id, 0)

				local card = model(fake):CrateResult({ tier = 1, good = id })

				assert.are.same(
					{ "A new look", "It shows here once its Module is on.", false, CRATE, "trackerframe" },
					{ card.title, card.line, card.canUse, card.select, card.kind }
				)
				assert.are.equal(fake.ns.CRATE_NEW_LOOK_ICON, card.icon)
			end
		)

		it(
			"names a good from the cache when the shop can't list it yet, without Use it now (SHOP-R35, SHOP-R50)",
			function()
				local fake = crated(3500)
				local id = "stats.trackerframe.greenbar"
				fake.ns.RecordPurchase(id, 0)
				local cache =
					{ [id] = { name = "Green Bar", icon = "x", slot = "stats.trackerframe", module = "Stats" } }
				local function shopWith(modules)
					return fake.ns.NewShopModel({
						goods = fake.ns.goods,
						cache = cache,
						modules = modules,
						balance = fake.Pagle.GetBalance(),
						updating = false,
						wallet = fake.ns.walletSnapshot,
						now = SERVER_TIME,
					})
				end

				-- its Module on but the good not registered (its slot is yet to come): the cache names it
				local card = shopWith({ { def = { name = "Stats" } } }):CrateResult({ tier = 1, good = id })
				assert.are.same({ "Green Bar", "x", false, CRATE }, { card.title, card.icon, card.canUse, card.select })
				assert.is_nil(card.line)

				-- its Module off: the good is put away, owned, and selected there
				card = shopWith({}):CrateResult({ tier = 1, good = id })
				assert.are.same({ "Green Bar", false, id }, { card.title, card.canUse, card.select })
			end
		)
	end)

	describe("result card's reveal (SHOP-R55, wallet-and-shop.md › UI: Motion and sound)", function()
		it(
			"gives a good the card it turns over to, its kind named, its crate tier's reveal and the YOURS stamp",
			function()
				local fake = crated(3500)
				local good = fake.ns.goods:Good("core.toaststyle.ship")
				fake.ns.RecordPurchase(good.id, 0)

				local card = model(fake):CrateResult({ tier = 2, good = good.id })

				assert.are.same(
					{ "kind", "toast", "toaststyle", "Toast style", "Yours", 2 },
					{ card.face, card.emblem, card.kind, card.kindName, card.stamp, card.reveal.tier }
				)
				assert.is_false(card.reveal.payback)
				assert.is_nil(card.unseen)
			end
		)

		it("gives a crate-only good the Curio '?' card, still naming its kind for the reveal", function()
			local fake = crated(3500)
			fake.ns.RecordPurchase(FOIL, 0)

			local card = model(fake):CrateResult({ tier = "curio", good = FOIL, crateOnly = true })

			assert.are.same(
				{ "curio", "Toast style", 7, "curio" },
				{ card.face, card.kindName, card.reveal.tier, card.reveal.sting }
			)
		end)

		it("gives a payback the coin card, none of its tier's fanfare, and the PAID BACK stamp", function()
			local fake = crated(3500)

			for _, tier in ipairs({ 1, 6, "curio" }) do
				local card = model(fake):CrateResult({ tier = tier, payback = 250 })
				assert.are.same(
					{ "coin", "coin", "Paid back", true },
					{ card.face, card.emblem, card.stamp, card.reveal.payback }
				)
				assert.are.same({ nil, nil, nil, nil, 0.76 }, {
					card.reveal.sparks,
					card.reveal.embers,
					card.reveal.shake,
					card.reveal.flash,
					card.reveal.wait,
				})
				assert.is_nil(card.kindName)
			end
		end)

		it("gives a good with no cache entry its kind's emblem as its face, marked unseen", function()
			local fake = crated(3500)
			local id = "stats.trackerframe.greenbar"
			fake.ns.RecordPurchase(id, 0)

			local card = model(fake):CrateResult({ tier = 1, good = id })

			assert.are.same(
				{ true, "kind", "tracker", "Tracker frame" },
				{ card.unseen, card.face, card.emblem, card.kindName }
			)
		end)

		it(
			"draws the reel's 60 cards from what the Angler owns now and the server time, the result's the 53rd",
			function()
				local fake = crated(3500)
				local good = fake.ns.goods:Good("core.toaststyle.ship")
				fake.ns.RecordPurchase(good.id, 0)

				local cards = model(fake):CrateReel({ tier = 1, good = good.id }, function(n)
					return math.ceil(n / 2)
				end)

				assert.are.equal(60, #cards)
				assert.are.same({ tier = 1, face = "kind", kind = "toaststyle" }, cards[53])
			end
		)
	end)

	it('lists Prize Foil as "From a crate", never for sale, until a crate gives it (SHOP-R22, SHOP-R50)', function()
		local fake = crated(10000)
		local shop = model(fake)

		assert.are.same({
			id = FOIL,
			name = fake.ns.goods:Good(FOIL).name,
			icon = fake.ns.goods:Good(FOIL).icon,
			state = "crateOnly",
			tag = "From a crate",
		}, shop:Row(FOIL))
		local stage = shop:Stage(FOIL)
		assert.are.same({ { "Only in a Curio crate, never for sale" }, {} }, { stage.notes, stage.tags })
		assert.is_nil(stage.buy)
		assert.is_nil(shop:Purchase(FOIL))

		rigged(fake, TOP, { { id = FOIL, tier = "curio", kind = "toaststyle" } })
		fake.ns.shop.Buy(CRATE, false)

		local owned = model(fake):Stage(FOIL)
		assert.are.same({ "owned", { "From a crate" } }, { owned.state, owned.notes })
		assert.is_true(owned.use)
	end)

	it(
		"doesn't list Sonar Scope, an earned good with no fallback yet, until it has one (SHOP-R24, SHOP-R29)",
		function()
			local fake = crated(0)

			assert.is_nil(model(fake):Stage("core.toaststyle.sonar"))
			assert.is_nil(model(fake):Row("core.toaststyle.sonar"))
			assert.is_true(model(fake):IsEarnedUnlisted("core.toaststyle.sonar"))
			assert.are.same(
				{ tag = "Link the companion", note = "Link the companion" },
				fake.Pagle.GetEarnedProgress("core.toaststyle.sonar")
			)
		end
	)

	it(
		"owns Sonar Scope once a check ends connected with the file's keyId and seq, through K1 (SHOP-R29, LOG-R37)",
		function()
			local fake = newFakePagle()
			fake.setPushedContent({ state = "connected", items = {}, keyId = "testKey", seq = 42 })
			fake.login()
			fake.enterWorld()
			assert.is_false(fake.Pagle.IsOwned("core.toaststyle.sonar"))

			fake.nextFrame()

			assert.is_true(fake.Pagle.IsOwned("core.toaststyle.sonar"))
			local entries = fake.catchLog.data.entries
			assert.is_truthy(entries[#entries]:find("^K1|%d+|%d+|%d+|testKey|42$"))
		end
	)
end)
