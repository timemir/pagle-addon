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

-- The Curio Shop expansion's toast styles and sound sets (SHOP-R25), each slot's in its order, with their tiers.
local EXPANSION = {
	toaststyle = {
		{ "ship", 1 },
		{ "birch", 1 },
		{ "tidepool", 1 },
		{ "chart", 2 },
		{ "frost", 2 },
		{ "goblin", 2 },
		{ "kelp", 3 },
		{ "moon", 3 },
		{ "leaf", 3 },
		{ "bottle", 3 },
		{ "rune", 4 },
		{ "folio", 5 },
	},
	soundset = {
		{ "rain", 1 },
		{ "marimba", 1 },
		{ "shipbell", 1 },
		{ "kalimba", 2 },
		{ "musicbox", 2 },
		{ "glass", 2 },
		{ "steelpan", 2 },
		{ "dulcimer", 2 },
		{ "frost", 3 },
		{ "harp", 3 },
		{ "gizmo", 3 },
		{ "wardrums", 4 },
	},
}
-- Each tier's price (SHOP-R22), as the list prints it.
local PRICES = { "150", "400", "900", "2,000", "5,000" }
local PRICE_VALUES = { 150, 400, 900, 2000, 5000 }

-- The expansion's goods of Core's slot `slot` ("toaststyle" or "soundset") as the list outlines them, none bought,
-- with a balance of `balance`: each priced, in red where the balance falls short.
---@param slot string
---@param balance integer
---@return string[]
local function expansionLines(slot, balance)
	local lines = {}
	for _, good in ipairs(EXPANSION[slot]) do
		local tier = good[2]
		lines[#lines + 1] = ("  core.%s.%s %s%s"):format(
			slot,
			good[1],
			PRICES[tier],
			PRICE_VALUES[tier] > balance and " [red]" or ""
		)
	end
	return lines
end

-- The expansion's goods of Core's slot `slot` the balance `balance` covers, by ID, in the list's order.
---@param slot string
---@param balance integer
---@return string[]
local function expansionAffordable(slot, balance)
	local ids = {}
	for _, good in ipairs(EXPANSION[slot]) do
		if PRICE_VALUES[good[2]] <= balance then
			ids[#ids + 1] = ("core.%s.%s"):format(slot, good[1])
		end
	end
	return ids
end

-- Core's own slots (SHOP-R25) as the list outlines them while nothing of Core's is bought and the balance is under
-- 150: each default in use, everything else priced in red.
local CORE_UNBOUGHT = joined(
	joined(
		joined(
			joined({
				"Toast style (1 of 15)",
				"  core.toaststyle.page In use",
				"  core.toaststyle.ripple 150" .. " [red]",
				"  core.toaststyle.lanternglow 400" .. " [red]",
			}, expansionLines("toaststyle", 0)),
			{
				"Sound set (1 of 14)",
				"  core.soundset.driftwood In use",
				"  core.soundset.gilded 400" .. " [red]",
			}
		),
		expansionLines("soundset", 0)
	),
	CREST_LINES
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
-- Velvet (tier 1, no group) and Birch (wooden, tier 2).
local function huntsFrames(hunts, earned)
	hunts:RegisterSlot({
		id = "hunts.frame",
		label = "Frame",
		category = "Hunts",
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
							joined({
								"Toast style (2 of 15)",
								"  core.toaststyle.page default",
								"  core.toaststyle.ripple In use",
								"  core.toaststyle.lanternglow 400" .. " [red]",
							}, expansionLines("toaststyle", 300)),
							joined({
								"Sound set (1 of 14)",
								"  core.soundset.driftwood In use",
								"  core.soundset.gilded 400" .. " [red]",
							}, expansionLines("soundset", 300))
						),
						CREST_LINES
					),
					{
						"Journal binding (1 of 2)",
						"  ledger.binding.oak In use",
						"  ledger.binding.lapis 900" .. " [red]",
						"Notebook cover (1 of 3)",
						"  hunts.cover.plain In use",
						"  hunts.cover.velvet 400" .. " [red]",
						"  hunts.cover.gold Every Hunt done",
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

			local rows = model(fake):List({ category = "Hunts" })[1].rows

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
		local velvet = shop:List({ category = "Hunts" })[1].rows[2]

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
			"Notebook cover (1 of 3)",
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

		assert.are.equal(11 + 24, #ids("all"))
		assert.are.same({
			"core.toaststyle.page",
			"core.toaststyle.ripple",
			"core.soundset.driftwood",
			"core.crest.plain",
			"ledger.binding.oak",
			"hunts.cover.plain",
		}, ids("owned"))
		local notOwned = joined(
			joined({ "core.toaststyle.lanternglow" }, expansionAffordable("toaststyle", math.huge)),
			joined({ "core.soundset.gilded" }, expansionAffordable("soundset", math.huge))
		)
		assert.are.same(
			joined(notOwned, { "ledger.binding.lapis", "hunts.cover.velvet", "hunts.cover.gold" }),
			ids("notOwned")
		)
		assert.are.same(
			joined(
				joined(
					joined({ "core.toaststyle.lanternglow" }, expansionAffordable("toaststyle", 550)),
					joined({ "core.soundset.gilded" }, expansionAffordable("soundset", 550))
				),
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
				{ category = "Fish Journal", label = "Fish Journal" },
				{ category = "Hunts", label = "Hunts" },
			}, shop:Chips())
			assert.are.same({
				"Journal binding (1 of 2)",
				"  ledger.binding.oak In use",
				"  ledger.binding.lapis 900" .. " [red]",
			}, outline(shop:List({ category = "Fish Journal" })))
		end
	)

	it("counts an earned good owned once its Module says so (SHOP-R22, SHOP-R30)", function()
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, { value = true })
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
end)

describe("A grouped slot on the Curio Shop's list", function()
	-- Hunts' frames alone of Hunts' (Gold leaf not yet earned), logged in, with a balance of 200.
	local function framing()
		local fake, handles = coreWithModules()
		huntsFrames(handles.Hunts, { value = false })
		fake.login()
		handles.Ledger:ReportCoinsEarned(200)
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
				"  hunts.frame.velvet 150",
				"  -- Gilt frames",
				"  hunts.frame.leaf 2 of 3 gilded",
				"  -- Wooden frames",
				"  hunts.frame.oak 150",
				"  hunts.frame.birch 400" .. " [red]",
			}, outline(model(fake):List({ category = "Hunts" })))
		end
	)

	it("heads only the groups with a row left once the list is narrowed (SHOP-R27)", function()
		local fake = framing()
		local shop = model(fake)

		assert.are.same({
			"Frame (1 of 5)",
			"  -- Wooden frames",
			"  hunts.frame.birch 400" .. " [red]",
		}, outline(shop:List({ search = "birch", category = "Hunts" }))) -- Core's Birch Scroll is no Frame
		assert.are.same({
			"Frame (1 of 5)",
			"  hunts.frame.velvet 150",
			"  -- Wooden frames",
			"  hunts.frame.oak 150",
		}, outline(shop:List({ category = "Hunts", filter = "canAfford" })))
		assert.are.same(
			{ "Frame (1 of 5)", "  hunts.frame.plain In use" },
			outline(shop:List({ search = "plain", category = "Hunts" }))
		)
	end)

	it("lists a slot with no groups as before, its goods in registration order (SHOP-R27)", function()
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, { value = false })
		fake.login()

		local group = model(fake):List({ category = "Hunts" })[1]

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

describe("An earned good's texts and progress in the Curio Shop", function()
	-- Hunts' frames (Gold leaf earned while `earned.value`, with `progress` as its progress if given), logged in.
	local function earning(earned, progress)
		local fake, handles = coreWithModules()
		handles.Hunts:RegisterSlot({ id = "hunts.frame", label = "Frame", category = "Hunts" })
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

			assert.are.equal("2 of 3 gilded", assert(model(fake):Row("hunts.frame.leaf")).tag)
			assert.are.same(
				{ "Gild 3 frames.", "A Hunts reward, not for sale" },
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
			assert.are.same({ "owned", { "A Hunts reward, not for sale" } }, { owned.state, owned.notes })
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
				category = "Hunts",
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
		"lists an off Module's bought and earned goods last, not its default or goods for sale, saying Yours to keep"
			.. " (SHOP-R35)",
		function()
			local fake = huntsOff()

			local groups = model(fake):List({})

			assert.are.same(
				afterCore({
					"Journal binding (1 of 2)",
					"  ledger.binding.oak In use",
					"  ledger.binding.lapis 900" .. " [red]",
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
				{ category = "Crests", label = "Crests" },
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
		assert.are.equal("core.toaststyle.page", shop:Select("core.toaststyle.page"))
		assert.are.equal("hunts.cover.velvet", shop:Select("hunts.cover.velvet"))
		assert.is_nil(shop:Select("hunts.cover.tide")) -- for sale, of a Module off
		assert.is_nil(shop:Select("hunts.cover.plain")) -- a default of a Module off
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
	-- Core's own goods, Hunts' covers (Gold earned while `earned.value`) and the Ledger's bindings, logged in, with a
	-- balance of `balance`.
	local function stageReady(balance, earned)
		local fake, handles = coreWithModules()
		huntsCovers(handles.Hunts, earned or { value = false })
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
		"shows an earned good's earnedText and that it isn't for sale, earned or not (wallet-and-shop.md › UI)",
		function()
			local earned = { value = false }
			local fake, handles = stageReady(5000, earned)

			local gold = assert(model(fake):Stage("hunts.cover.gold"))
			assert.are.same(
				{ "unearned", {}, { "Every Hunt done", "A Hunts reward, not for sale" } },
				{ gold.state, gold.tags, gold.notes }
			)
			assert.is_nil(gold.buy)

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
		local fake, handles = coreWithModules()
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
			local shop = model(buyReady(400))

			assert.is_true(assert(shop:Stage("hunts.cover.velvet")).canBuy) -- 400 covers 400
			assert.is_true(assert(shop:Stage("core.toaststyle.ripple")).canBuy)
		end
	)

	it(
		"is disabled for an owned good, a default, an earned good, and a good the balance doesn't cover (SHOP-R13)",
		function()
			local earned = { value = false }
			local fake, handles = buyReady(899, earned)
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
			local fake = readyToBuy(200)
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
		local fake = readyToBuy(200)
		local changed = looks(fake)

		assert.is_true(fake.ns.shop.Buy("core.toaststyle.ripple", false))

		assert.is_true(fake.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal("core.toaststyle.page", fake.Pagle.GetEquipped("core.toaststyle"))
		assert.are.same({}, changed)
	end)

	it("equips an owned good with Use, and nothing for a good not owned or not known (SHOP-R32)", function()
		local fake = readyToBuy(200)
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
		local fake = readyToBuy(200)
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
			local fake, handles = readyToBuy(200)
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
-- the stage's note) and counting its calls in `texts.calls`. Neither has a preview of its own.
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
		"lists them in the slot after its own, counted, each not yet earned with its earnedText function's first text (SHOP-R22, SHOP-R23)",
		function()
			local fake = styled({ value = true })

			assert.are.same(
				joined(
					joined({
						"Toast style (2 of 17)",
						"  core.toaststyle.page In use",
						"  core.toaststyle.ripple 150" .. " [red]",
						"  core.toaststyle.lanternglow 400" .. " [red]",
					}, expansionLines("toaststyle", 0)),
					{
						"  ledger.toaststyle.oak Owned",
						"  ledger.toaststyle.sun Unfished",
					}
				),
				outline({ model(fake):List({ category = "Announcements" })[1] })
			)
		end
	)

	it(
		"shows the function's second text on the stage, then whose reward it is, its owner the good's Module (SHOP-R22, SHOP-R23)",
		function()
			local fake = styled({ value = false })

			local stage = model(fake):Stage("ledger.toaststyle.oak")

			assert.are.same({
				"unearned",
				"Toast style · Ledger",
				{ "Earned when Elwynn reaches Master.", "A Ledger reward, not for sale" },
				{},
			}, { stage.state, stage.slotLine, stage.notes, stage.tags })
			assert.is_nil(stage.buy)
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
			assert.are.same({ "owned", { "Owned" }, { "A Ledger reward, not for sale" } }, {
				owned.state,
				owned.tags,
				owned.notes,
			})
		end
	)

	it(
		"has no stage note when the function gives none, and the reward line on the row when it gives no text (SHOP-R22)",
		function()
			local fake = styled({ value = false }, {
				["ledger.toaststyle.oak"] = { "Expert · 88%" },
				["ledger.toaststyle.sun"] = {},
			})
			local shop = model(fake)

			assert.are.same({ "A Ledger reward, not for sale" }, shop:Stage("ledger.toaststyle.oak").notes)
			assert.are.equal("A Ledger reward, not for sale", shop:Row("ledger.toaststyle.sun").tag)
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
			})
			handles.Ledger:RegisterGood({
				id = "ledger.plate.own",
				slot = "core.plate",
				name = "Own",
				isEarned = function()
					return false
				end,
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

	it("puts an owned one away while its Module is off, and hides the rest (SHOP-R35)", function()
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

		assert.are.same(
			{ "Put away: Module off (Yours to keep)", "  ledger.toaststyle.oak Ledger is off" },
			outline({ groups[#groups] })
		)
		assert.is_nil(groups[#groups].rows[1].shield)
		assert.is_nil(shop:Select("ledger.toaststyle.sun"))
	end)
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
