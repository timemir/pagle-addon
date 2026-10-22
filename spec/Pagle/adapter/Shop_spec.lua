-- The Curio Shop window and its entry points, as Core runs it through the real TOC (wallet-and-shop.md › Entry points,
-- › UI; SHOP-R35, SHOP-R40, SHOP-R41, SHOP-R93; CORE-R33, CORE-R50, CORE-R61). The window is the shop art kit's
-- sample case: its words in the kit's fonts, capitals where the kit sets them so.

local COIN = " |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local AFTER_COMBAT = "Pagle: the Curio Shop opens after combat."
-- Where the shop's textures are.
local SHOP_ART = "Interface\\AddOns\\Pagle\\media\\shop\\"

-- Storm Front's name in the list (ANN-R82): its lore's once the round two's lore is in data/Lore.lua, its ID till then.
local STORM_NAME = readFile("addons/Pagle/data/Lore.lua"):match(
	'L%["good%.core%.toaststyle%.storm%.name"%] = "([^"]*)"'
) or "core.toaststyle.storm"

-- The Curio Shop expansion's toast styles and sound sets (SHOP-R25), each slot's in its order, by their lore names,
-- with their tiers' prices (SHOP-R22); the round two's Storm Front after the toast styles.
local EXPANSION = {
	toaststyle = {
		{ "Ship's Log", 150 },
		{ "Birch Scroll", 150 },
		{ "Tidepool", 150 },
		{ "Sea Chart", 400 },
		{ "Frostbitten", 400 },
		{ "Goblin Ticker", 400 },
		{ "Kelp & Pearl", 900 },
		{ "Moonlit Vellum", 900 },
		{ "Pressed Leaf", 900 },
		{ "Driftglass Bottle", 900 },
		{ "Rune-Plate", 2000 },
		{ "Illuminated Folio", 5000 },
		{ STORM_NAME, 5000 },
	},
	soundset = {
		{ "Rain on the Lake", 150 },
		{ "Marimba Shore", 150 },
		{ "Ship's Bell", 150 },
		{ "Kalimba Creek", 400 },
		{ "Music Box", 400 },
		{ "Glass Floats", 400 },
		{ "Steel Pan Lagoon", 400 },
		{ "Tavern Dulcimer", 400 },
		{ "Frost Chimes", 900 },
		{ "Harp of the Glade", 900 },
		{ "Gnomish Gizmo", 900 },
		{ "War Drums", 2000 },
	},
}

-- `lines` with the expansion's rows of Core's slot `slot` ("toaststyle" or "soundset") after them, those priced at
-- most `most` (all by default), as the list shows them: "<name> | <price>".
---@param lines string[]
---@param slot string
---@param most number?
---@return string[]
local function withExpansion(lines, slot, most)
	local all = { unpack(lines) }
	for _, good in ipairs(EXPANSION[slot]) do
		if good[2] <= (most or math.huge) then
			all[#all + 1] = ("%s | %s"):format(good[1], breakUpLargeNumbers(good[2]))
		end
	end
	return all
end

-- `lists`, one after the other, as one new list.
---@param lists string[][]
---@return string[]
local function concat(lists)
	local all = {}
	for _, list in ipairs(lists) do
		for _, line in ipairs(list) do
			all[#all + 1] = line
		end
	end
	return all
end

-- Core's own slots (SHOP-R25) as the list shows them while nothing of Core's is bought and the balance is under 150,
-- the crest slot with Plain alone: its earned crests, the Ledger's two zone crests and Core's fish crests, aren't
-- listed or counted (SHOP-R25).
local CORE_UNBOUGHT = concat({
	withExpansion({ "TOAST STYLE 1 of 16", "Torn Page | IN USE", "Ripple | 150", "Lantern Glow | 400" }, "toaststyle"),
	withExpansion({ "SOUND SET 1 of 14", "Driftwood | IN USE", "Gilded | 400" }, "soundset"),
	{ "CRESTS 1 of 1", "Plain | IN USE" },
})

-- A crest's icon for Peaks, a crest for sale that only the specs register (no crest is for sale, SHOP-R25).
local PEAKS_ICON = "Interface\\AddOns\\Pagle\\media\\crests\\peaks"

-- Registers Peaks, Core's crest for sale at tier 2 with no preview of its own, in `loaded`'s crest slot.
local function registerPeaks(loaded)
	loaded.ns.RegisterCoreGood({
		id = "core.crest.peaks",
		slot = "core.crest",
		name = "Peaks",
		tier = 2,
		icon = PEAKS_ICON,
	})
end

-- Core's book binding (ADR 0015) as the list shows it: Field Leather and every binding for sale, in the shop's order.
local BOOK_BINDING = {
	"BOOK BINDING 1 of 34",
	"Field Leather | IN USE",
	"Birch Bark | 150",
	"Tide-Chart Linen | 150",
	"Tarred Sailcloth | 150",
	"Oilskin Yellow | 150",
	"Oilcloth | 150",
	"Canvas Field Pad | 150",
	"Waxed Kraft | 150",
	"Tartan Wool | 150",
	"Sea-Green Buckram | 400",
	"Mossbound | 400",
	"Driftwood Boards | 400",
	"Eelskin | 400",
	"Kodo Hide | 400",
	"Frost-Tanned Hide | 400",
	"Net over Cork | 400",
	"Tooled Leather | 400",
	"Map Linen | 400",
	"Bound Planks | 400",
	"Sharkskin | 900",
	"Riveted Copper | 900",
	"Night Velvet | 900",
	"Turtle Shell | 900",
	"Gilded Morocco | 900",
	"Verdigris | 900",
	"Snakeskin | 900",
	"Stingray Shagreen | 900",
	"Lacquered Red | 900",
	"Bone & Rawhide | 900",
	"Brass Hunter's Case | 900",
	"Coral Inlay | 2,000",
	"Scrimshaw Panel | 2,000",
	"Mother-of-Pearl | 5,000",
	"Gilded Trophy Case | 5,000",
}
for _, line in ipairs(BOOK_BINDING) do
	CORE_UNBOUGHT[#CORE_UNBOUGHT + 1] = line
end

-- The book binding's header and its bindings for sale priced at most `most`, as the list shows them.
---@param most number
---@return string[]
local function bindingsAtMost(most)
	local all = { BOOK_BINDING[1] }
	for i = 3, #BOOK_BINDING do
		local price = tonumber((BOOK_BINDING[i]:match("| ([%d,]+)$"):gsub(",", ""))) or math.huge
		if price <= most then
			all[#all + 1] = BOOK_BINDING[i]
		end
	end
	return all
end

-- Core with the Ledger and Hunts registered, Core's own goods, Hunts' covers and the Ledger's bindings and two zone
-- crests in Core's crest slot (earned goods, their earnedText functions, SHOP-R22, SHOP-R23; the shop lists neither,
-- SHOP-R25), logged in and in the world. `saved` is a PagleDB; `options.noHunts` leaves Hunts unregistered (off);
-- `options.preview` is Velvet's preview; `options.entries` is the saved log's entries. Returns the loaded addon and
-- the handles.
local function shopCore(saved, options)
	options = options or {}
	local loaded = loadCore(options.entries, saved)
	local Pagle = loaded.env.Pagle
	local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Books" })
	ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
	ledger:RegisterGood({ id = "ledger.binding.lapis", slot = "ledger.binding", name = "Lapis", tier = 3 })
	for _, crest in ipairs({
		{ "elwynn", "The Old Oak", "Expert · 88%", "Earned when Elwynn Forest reaches Master in the Fish Journal." },
		{ "tanaris", "The Desert Sun", "Unfished" },
	}) do
		ledger:RegisterGood({
			id = "ledger.crest." .. crest[1],
			slot = "core.crest",
			name = crest[2],
			icon = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\" .. crest[1],
			isEarned = function()
				return false
			end,
			earnedText = function()
				return crest[3], crest[4]
			end,
		})
	end
	local hunts
	if not options.noHunts then
		hunts = Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
		hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Trackers" })
		hunts:RegisterGood({ id = "hunts.cover.plain", slot = "hunts.cover", name = "Plain", default = true })
		hunts:RegisterGood({
			id = "hunts.cover.velvet",
			slot = "hunts.cover",
			name = "Velvet",
			tier = 2,
			icon = 134939,
			description = "Soft to the touch.",
			preview = options.preview,
		})
	end
	enterWorld(loaded, 2)
	return loaded, { Ledger = ledger, Hunts = hunts }
end

-- The shop's window, or nil before it first opened.
local function shopFrame(loaded)
	return loaded.ns.shopFrame
end

-- The list as shown: each group header as "<label> <count or note>", a grouped slot's group header (SHOP-R27) as
-- "<name>", each row as "<name> | <tag or price>".
local function listed(loaded)
	local lines = {}
	for _, line in ipairs(shopFrame(loaded).lines) do
		if line:IsShown() then
			if line.header and not line.count:IsShown() then
				lines[#lines + 1] = line.label:GetText()
			elseif line.header then
				lines[#lines + 1] = ("%s %s"):format(line.label:GetText(), line.count:GetText())
			elseif line.price:IsShown() then
				lines[#lines + 1] = ("%s | %s"):format(line.label:GetText(), line.price.amount:GetText())
			else
				lines[#lines + 1] = ("%s | %s"):format(line.label:GetText(), line.tag:GetText())
			end
		end
	end
	return lines
end

-- The row showing `goodID`.
local function rowOf(loaded, goodID)
	for _, line in ipairs(shopFrame(loaded).lines) do
		if line:IsShown() and line.goodID == goodID then
			return line
		end
	end
	error("no row for " .. goodID)
end

-- Hunts' frames on its handle, a grouped slot (SHOP-R27): Gilt frames then Wooden frames; Plain (default), Oak
-- (Ash, wooden, tier 1) and Gold leaf (gilt, earned never, "2 of 3 gilded", with `progress` as its progress).
local function huntsFrames(hunts, progress)
	hunts:RegisterSlot({
		id = "hunts.frame",
		label = "Frame",
		category = "Trackers",
		groups = { { key = "gilt", name = "Gilt frames" }, { key = "wood", name = "Wooden frames" } },
	})
	hunts:RegisterGood({ id = "hunts.frame.plain", slot = "hunts.frame", name = "Plain", default = true })
	hunts:RegisterGood({ id = "hunts.frame.ash", slot = "hunts.frame", name = "Ash", tier = 1, group = "wood" })
	hunts:RegisterGood({
		id = "hunts.frame.leaf",
		slot = "hunts.frame",
		name = "Gold leaf",
		group = "gilt",
		isEarned = function()
			return false
		end,
		earnedText = function()
			return "2 of 3 gilded", "Gild three frames."
		end,
		progress = progress,
	})
end

-- The words on each shown pill of `pills`, in order.
local function pillLabels(pills)
	local labels = {}
	for _, pill in ipairs(pills) do
		if pill:IsShown() then
			labels[#labels + 1] = pill.label:GetText()
		end
	end
	return labels
end

-- The shown lines of the purse's tooltip: its head, then each line.
local function tipLines(tip)
	local lines = { tip.head:GetText() }
	for _, line in ipairs(tip.lines) do
		if line:IsShown() then
			lines[#lines + 1] = line:GetText()
		end
	end
	return lines
end

describe("The Curio Shop's entry points", function()
	it("opens with Pagle.OpenShop(), drawn as the sample case (SHOP-R40, wallet-and-shop.md › UI)", function()
		local loaded = shopCore()

		loaded.env.Pagle.OpenShop()

		local frame = assert(shopFrame(loaded))
		assert.is_true(frame:IsShown())
		assert.are.equal(SHOP_ART .. "Case", frame.case.texture)
		assert.are.same({ 2 / 2048, 1406 / 2048, 2 / 1024, 1015 / 1024 }, frame.case.texCoord)
		assert.are.same({}, loaded.printed)
	end)

	it("opens over the windows already open, its bill and medallion over it (wallet-and-shop.md › UI)", function()
		local loaded = shopCore()
		local Pagle = loaded.env.Pagle

		Pagle.OpenShop()
		local frame = shopFrame(loaded)
		assert.are.same({ "HIGH", true, 1 }, { frame:GetFrameStrata(), frame.toplevel, frame.raised })
		assert.are.same({ "DIALOG", "DIALOG" }, { frame.bill:GetFrameStrata(), frame.flyer:GetFrameStrata() })
		Pagle.OpenShop("hunts.cover.velvet") -- asked to open again while open, from Look and Feel or a book
		assert.are.equal(2, frame.raised)
		frame:Hide()
		Pagle.OpenShop()
		assert.are.equal(3, frame.raised)
	end)

	it("toggles with /pagle shop, matched case-insensitively (CORE-R61, SHOP-R40)", function()
		local loaded = shopCore()
		local slash = loaded.env.SlashCmdList.PAGLE

		slash("shop")
		assert.is_true(shopFrame(loaded):IsShown())
		slash(" SHOP ")
		assert.is_false(shopFrame(loaded):IsShown())
		slash("shop")
		assert.is_true(shopFrame(loaded):IsShown())
		assert.are.same({}, loaded.printed)
	end)

	it("opens from the compartment menu's Curio Shop entry, which shows the balance (CORE-R50, SHOP-R40)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(1950)

		loaded.client.openCompartmentMenu("Pagle").click("Curio Shop  1,950" .. COIN)

		assert.is_true(shopFrame(loaded):IsShown())
	end)

	it("closes with Esc, from the search slip or with nothing focused, and with its close button (SHOP-R40)", function()
		local loaded = shopCore()
		local Pagle = loaded.env.Pagle

		Pagle.OpenShop()
		assert.is_true(loaded.ns.shopFrame.name ~= nil)
		loaded.client.pressEscape()
		assert.is_false(shopFrame(loaded):IsShown())

		Pagle.OpenShop()
		shopFrame(loaded).search:SetFocus()
		loaded.client.pressEscape()
		assert.is_false(shopFrame(loaded):IsShown())
		assert.is_nil(loaded.client.focus) -- a closed shop keeps no keyboard focus

		Pagle.OpenShop()
		shopFrame(loaded).CloseButton:Click()
		assert.is_false(shopFrame(loaded):IsShown())
	end)

	it("never opens on its own (SHOP-R40)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(500)
		setCombat(loaded, true)
		setCombat(loaded, false)

		assert.is_nil(shopFrame(loaded))
	end)
end)

describe("Pagle.OpenShop(goodID)", function()
	it("selects that good on the stage (SHOP-R40)", function()
		local loaded = shopCore()

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")

		local frame = shopFrame(loaded)
		assert.are.equal("Velvet", frame.stage.name:GetText())
		assert.are.equal("NOTEBOOK COVER · HUNTS", frame.stage.slotLine:GetText())
		assert.is_true(rowOf(loaded, "hunts.cover.velvet").selectedMark:IsShown())
		assert.is_false(rowOf(loaded, "hunts.cover.plain").selectedMark:IsShown())
	end)

	it("selects nothing for an unknown ID, the stage asking for a pick (SHOP-R40)", function()
		local loaded = shopCore()
		local Pagle = loaded.env.Pagle
		Pagle.OpenShop("hunts.cover.velvet")

		Pagle.OpenShop("hunts.cover.none")

		local stage = shopFrame(loaded).stage
		assert.is_true(stage.hint:IsShown())
		assert.are.equal("Pick a look to see it here.", stage.hint:GetText())
		assert.is_false(stage.name:IsShown())
		assert.is_false(stage.buy:IsShown())
		assert.is_false(stage.use:IsShown())
	end)

	it("keeps the selection when opened again with no ID (SHOP-R40)", function()
		local loaded = shopCore()
		local Pagle = loaded.env.Pagle
		Pagle.OpenShop("ledger.binding.lapis")
		shopFrame(loaded).CloseButton:Click()

		Pagle.OpenShop()

		assert.are.equal("Lapis", shopFrame(loaded).stage.name:GetText())
	end)

	it("clears the search, the filter and the chip so the good's row shows (SHOP-R40)", function()
		local loaded = shopCore()
		local Pagle = loaded.env.Pagle
		Pagle.OpenShop()
		local frame = shopFrame(loaded)
		frame.search:Type("oak")
		frame.filters.owned:Click()

		Pagle.OpenShop("hunts.cover.velvet")

		assert.are.equal("", frame.search:GetText())
		assert.is_true(frame.search.Instructions:IsShown())
		assert.is_true(frame.filters.all.pressed)
		assert.is_true(rowOf(loaded, "hunts.cover.velvet").selectedMark:IsShown())
	end)

	it(
		"selects an owned good of a Module off under Put away, greyed, with its cached icon (SHOP-R40, SHOP-R35)",
		function()
			local first = shopCore()
			first.ns.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
			-- The next session, with Hunts off: its goods are in PagleDB's cache.
			local loaded = shopCore(first.env.PagleDB, { noHunts = true })
			loaded.ns.goods:SetPurchased({ ["hunts.cover.velvet"] = true })

			loaded.env.Pagle.OpenShop("hunts.cover.velvet")

			local frame = shopFrame(loaded)
			local stage = frame.stage
			assert.are.equal("Velvet", stage.name:GetText())
			assert.are.equal("HUNTS IS OFF", stage.tags:GetText())
			assert.are.equal("Yours to keep", stage.notes:GetText())
			assert.are.equal(134939, stage.swatch.Icon.texture)
			assert.is_true(stage.swatch.Icon:IsDesaturated())
			assert.is_true(stage.swatch:IsShown())
			assert.is_false(stage.use:IsShown())
			local lines = listed(loaded)
			assert.are.same(
				{ "PUT AWAY: MODULE OFF Yours to keep", "Velvet | Hunts is off" },
				{ lines[#lines - 1], lines[#lines] }
			)
			local row = rowOf(loaded, "hunts.cover.velvet")
			assert.are.equal(0.55, row:GetAlpha())
			assert.is_true(row.bezel.Icon:IsDesaturated())

			loaded.env.Pagle.OpenShop("hunts.cover.plain")
			assert.is_true(stage.hint:IsShown()) -- a Module off's default isn't listed
		end
	)
end)

describe("The Curio Shop while restricted", function()
	it("prints SHOP-R41's line from every entry point and opens nothing (SHOP-R41, CORE-R33, SHOP-R93)", function()
		local loaded = shopCore()
		setCombat(loaded, true)

		loaded.env.Pagle.OpenShop()
		loaded.env.SlashCmdList.PAGLE("shop")
		loaded.client.openCompartmentMenu("Pagle").click("Curio Shop  0" .. COIN)

		assert.is_nil(shopFrame(loaded))
		assert.are.same({ AFTER_COMBAT, AFTER_COMBAT, AFTER_COMBAT }, loaded.printed)
	end)

	it("closes when combat starts, and doesn't reopen after (SHOP-R41, CORE-R33)", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()

		setCombat(loaded, true)
		assert.is_false(shopFrame(loaded):IsShown())
		setCombat(loaded, false)

		assert.is_false(shopFrame(loaded):IsShown())
		assert.are.same({}, loaded.printed)
	end)
end)

describe("The Curio Shop's purse", function()
	it(
		"shows the balance, and one segment per Module that reported, its total in the legend and tooltip"
			.. " (wallet-and-shop.md › UI)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(1500)
			handles.Hunts:ReportCoinsEarned(500)
			loaded.env.Pagle.OpenShop()

			local purse = shopFrame(loaded).purse
			assert.are.equal("2,000", purse.balance:GetText())
			assert.are.equal("PAGLE COINS", purse.label:GetText())
			local shown = {}
			for _, segment in ipairs(purse.segments) do
				if segment:IsShown() then
					shown[#shown + 1] = {
						segment.legend:GetText(),
						segment.share,
						segment:GetAlpha(),
						segment.strike:IsShown(),
						segment.bar.texCoord[1] * 1024,
					}
				end
			end
			-- The Ledger's segment is drawn from seg-ledger (x 2 in Shop.tga), Hunts' from seg-hunts (x 126).
			assert.are.same({ { "Ledger 1,500", 0.75, 1, false, 2 }, { "Hunts 500", 0.25, 1, false, 126 } }, shown)

			purse.segments[1]:GetScript("OnEnter")(purse.segments[1])
			assert.is_true(purse.tip:IsShown())
			assert.are.same({ "Ledger", "1,500 Coins all time" }, tipLines(purse.tip))
			assert.are.equal(purse.segments[1], select(2, purse.tip:GetPoint()))
			purse.segments[1]:GetScript("OnLeave")(purse.segments[1])
			assert.is_false(purse.tip:IsShown())
		end
	)

	it(
		"fades an off Module's segment and strikes its legend through, its total still counting (wallet-and-shop.md › UI)",
		function()
			local loaded = shopCore(
				{ global = { coins = { earned = { Hunts = 300, Ledger = 100 } } } },
				{ noHunts = true }
			)
			loaded.env.Pagle.OpenShop()

			local purse = shopFrame(loaded).purse
			local hunts = purse.segments[2]
			assert.are.equal("400", purse.balance:GetText())
			assert.are.equal("Hunts 300", hunts.legend:GetText())
			assert.are.equal("PagleShopLegendOff", hunts.legend.fontObject)
			assert.are.equal(0.45, hunts:GetAlpha())
			assert.is_true(hunts.bar:IsDesaturated())
			assert.is_true(hunts.strike:IsShown())
			assert.is_false(purse.segments[1].strike:IsShown())

			hunts:GetScript("OnEnter")(hunts)
			assert.are.same(
				{ "Hunts", "300 Coins all time", "Off: pays nothing new, keeps what it paid." },
				tipLines(purse.tip)
			)
		end
	)

	it("redraws on BalanceChanged, and never shows Spent (wallet-and-shop.md › UI)", function()
		local loaded, handles = shopCore()
		loaded.env.Pagle.OpenShop()

		handles.Ledger:ReportCoinsEarned(200)

		local frame = shopFrame(loaded)
		assert.are.equal("200", frame.purse.balance:GetText())
		assert.are.equal("Ripple | 150", listed(loaded)[3])
		for _, region in ipairs(loaded.client.frames) do
			assert.falsy(tostring(region.text):find("Spent", 1, true))
			for _, child in ipairs(region.children) do
				assert.falsy(tostring(child.text):find("Spent", 1, true))
			end
		end
	end)
end)

describe("The Curio Shop's list", function()
	it(
		"groups goods by slot, Core's first then by Module order, with owned counts (wallet-and-shop.md › UI)",
		function()
			local loaded = shopCore()

			loaded.env.Pagle.OpenShop()

			local expected = { unpack(CORE_UNBOUGHT) }
			for _, line in ipairs({
				"JOURNAL BINDING 1 of 2",
				"Oak | IN USE",
				"Lapis | 900",
				"NOTEBOOK COVER 1 of 2",
				"Plain | IN USE",
				"Velvet | 400",
			}) do
				expected[#expected + 1] = line
			end
			assert.are.same(expected, listed(loaded))
			local velvet = rowOf(loaded, "hunts.cover.velvet")
			assert.are.equal(134939, velvet.bezel.Icon.texture)
			assert.are.equal(1, #velvet.bezel.Icon.masks, "the icon is drawn round, through the portrait mask")
			assert.are.same(
				loaded.ns.SHOP_INKS.stamp,
				{ unpack(velvet.price.amount.textColor, 1, 3) },
				"a price the balance can't cover is in the stamp's red"
			)
			assert.is_true(velvet.price.coin:IsShown())
			local tornPage = rowOf(loaded, "core.toaststyle.page")
			assert.is_true(tornPage.wax:IsShown()) -- In use has its wax dot
			assert.is_false(tornPage.price:IsShown())
		end
	)

	it("draws a crest's row as its shield, 30 x 35, in place of the round medallion (SHOP-R25)", function()
		local loaded = shopCore()
		registerPeaks(loaded)

		loaded.env.Pagle.OpenShop()

		for _, id in ipairs({ "core.crest.plain", "core.crest.peaks" }) do
			local bezel = rowOf(loaded, id).bezel
			assert.are.same(
				{ false, false, false },
				{ bezel.Ring:IsShown(), bezel.Icon:IsShown(), bezel.Gloss:IsShown() }
			)
			assert.is_true(bezel.Shield:IsShown())
			assert.are.equal(loaded.env.Pagle.GetGood(id).icon, bezel.Shield.texture)
			assert.are.same({ 30, 35 }, { bezel.Shield:GetSize() })
			assert.are.same({ 0.5 - 60 / 140, 0.5 + 60 / 140, 0, 1 }, bezel.Shield.texCoord)
			assert.is_nil(bezel.Shield.masks) -- drawn whole, not masked round
			assert.is_false(bezel.Shield:IsDesaturated())
		end
		-- a row reused for a good that isn't a crest shows the medallion again
		local frame = shopFrame(loaded)
		frame.search:Type("peaks")
		local line = rowOf(loaded, "core.crest.peaks")
		frame.search:Type("ripple")
		assert.are.equal(line, rowOf(loaded, "core.toaststyle.ripple"))
		local ripple = line.bezel
		assert.are.same({ true, true, true }, { ripple.Ring:IsShown(), ripple.Icon:IsShown(), ripple.Gloss:IsShown() })
		assert.is_false(ripple.Shield:IsShown())
	end)

	it("greys a crest's shield as it would a medallion's icon (SHOP-R25, SHOP-R35)", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()
		local bezel = rowOf(loaded, "core.crest.plain").bezel

		loaded.ns.SetShopBezel(bezel, loaded.env.Pagle.GetGood("core.crest.plain").icon, true, true)

		assert.is_true(bezel.Shield:IsDesaturated())
	end)

	it("narrows with the search slip (wallet-and-shop.md › UI)", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()
		local search = shopFrame(loaded).search
		assert.are.equal("Find a look…", search.Instructions:GetText())

		search:Type("RIP")

		assert.is_false(search.Instructions:IsShown())
		assert.are.same({ "TOAST STYLE 1 of 16", "Ripple | 150" }, listed(loaded))
		search:Type("nothing like it")
		assert.are.same({}, listed(loaded))
		assert.is_true(shopFrame(loaded).empty:IsShown())
		assert.are.equal("No looks match.", shopFrame(loaded).empty:GetText())
	end)

	it("narrows with the filter All / Owned / Not owned / Can afford (wallet-and-shop.md › UI)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(500)
		loaded.env.Pagle.OpenShop()
		local filters = shopFrame(loaded).filters

		assert.are.same(
			{ "All", "Owned", "Not owned", "Can afford" },
			pillLabels({ filters.all, filters.owned, filters.notOwned, filters.canAfford })
		)
		filters.canAfford:Click()
		assert.are.same(
			concat({
				withExpansion({ "TOAST STYLE 1 of 16", "Ripple | 150", "Lantern Glow | 400" }, "toaststyle", 500),
				withExpansion({ "SOUND SET 1 of 14", "Gilded | 400" }, "soundset", 500),
				bindingsAtMost(500),
				{ "NOTEBOOK COVER 1 of 2", "Velvet | 400" },
			}),
			listed(loaded)
		)
		assert.is_true(filters.canAfford.pressed)
		assert.are.equal("PagleShopPillOn", filters.canAfford.label.fontObject)
		assert.is_false(filters.all.pressed)
		assert.are.equal("PagleShopPill", filters.all.label.fontObject)
		filters.owned:Click()
		assert.are.same({
			"TOAST STYLE 1 of 16",
			"Torn Page | IN USE",
			"SOUND SET 1 of 14",
			"Driftwood | IN USE",
			"CRESTS 1 of 1",
			"Plain | IN USE",
			"BOOK BINDING 1 of 34",
			"Field Leather | IN USE",
			"JOURNAL BINDING 1 of 2",
			"Oak | IN USE",
			"NOTEBOOK COVER 1 of 2",
			"Plain | IN USE",
		}, listed(loaded))
		filters.notOwned:Click()
		assert.are.equal(9 + 25 + 34, #listed(loaded))
		filters.all:Click()
		assert.are.equal(15 + 25 + 35, #listed(loaded))
	end)

	it(
		"shows a chip for each category a slot uses, in order, and narrows to one (wallet-and-shop.md › UI)",
		function()
			local loaded = shopCore()
			loaded.env.Pagle.OpenShop()
			local frame = shopFrame(loaded)

			assert.are.same({ "ALL", "ANNOUNCEMENTS", "CRESTS", "BOOKS", "TRACKERS" }, pillLabels(frame.chips))
			assert.is_true(frame.chips[1].pressed)

			frame.chips[4]:Click()
			assert.are.same(
				concat({ BOOK_BINDING, { "JOURNAL BINDING 1 of 2", "Oak | IN USE", "Lapis | 900" } }),
				listed(loaded)
			)
			assert.is_true(frame.chips[4].pressed)
			assert.is_false(frame.chips[1].pressed)
			frame.chips[1]:Click()
			assert.are.equal(15 + 25 + 35, #listed(loaded))
		end
	)

	it(
		"heads a grouped slot's groups with their names in the chips' gilt capitals, never as goods (SHOP-R27,"
			.. " wallet-and-shop.md › UI)",
		function()
			local loaded, handles = shopCore()
			huntsFrames(handles.Hunts)

			loaded.env.Pagle.OpenShop()

			local shown = listed(loaded)
			assert.are.same({
				"FRAME 1 of 3",
				"Plain | IN USE",
				"GILT FRAMES",
				"Gold leaf | 2 of 3 gilded",
				"WOODEN FRAMES",
				"Ash | 150",
			}, { unpack(shown, #shown - 5) })
			local heading
			for _, line in ipairs(shopFrame(loaded).lines) do
				if line:IsShown() and line.label:GetText() == "GILT FRAMES" then
					heading = line
				end
			end
			heading = assert(heading)
			assert.is_true(heading.header)
			assert.is_nil(heading.goodID)
			assert.is_false(heading.mouseEnabled)
			assert.are.equal(loaded.ns.SHOP_FONTS.Chip, heading.label.fontObject)
			assert.are.same(
				{ true, false, false, false },
				{ heading.rule:IsShown(), heading.bezel:IsShown(), heading.price:IsShown(), heading.tag:IsShown() }
			)
			assert.are.equal(26, heading:GetHeight())
		end
	)

	it("points the First look's note at a good's medallion, never a group's header (SHOP-R27, ONB-R57)", function()
		local loaded, handles = shopCore()
		huntsFrames(handles.Hunts)
		loaded.env.Pagle.OpenShop()
		local frame = shopFrame(loaded)

		frame.search:Type("ash")

		assert.are.same({ "FRAME 1 of 3", "WOODEN FRAMES", "Ash | 150" }, listed(loaded))
		local looks = loaded.ns.ShopFirstLook()
		assert.are.equal(rowOf(loaded, "hunts.frame.ash").bezel, looks.notes[2].target())
	end)

	it("keeps the First look's arrow on a row in the tray as the list scrolls, else on the tray (ONB-R57)", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()
		local frame = shopFrame(loaded)
		local rows = {}
		for _, line in ipairs(frame.lines) do
			if line:IsShown() and not line.header then
				rows[#rows + 1] = line.bezel
			end
		end
		assert(#rows >= 2, "the list shows two goods")
		local looks = loaded.ns.ShopFirstLook()

		-- The client lays the tray out from 100 to 500, the list scrolled so only the second row is in it: the selected
		-- good's row, wherever it is, is clipped above or below.
		frame.scroll.screenTop, frame.scroll.screenBottom = 500, 100
		for i, bezel in ipairs(rows) do
			if i == 2 then
				bezel.screenTop, bezel.screenBottom = 300, 260
			else
				bezel.screenTop, bezel.screenBottom = 560, 520
			end
		end
		assert.are.equal(rows[2], looks.notes[2].target())

		-- Scrolled further, no row in the tray: the tray itself.
		for _, bezel in ipairs(rows) do
			bezel.screenTop, bezel.screenBottom = 900, 860
		end
		assert.are.equal(frame.scroll, looks.notes[2].target())
	end)

	it("puts a clicked row's good on the stage (wallet-and-shop.md › UI)", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()

		rowOf(loaded, "ledger.binding.lapis"):Click()

		assert.are.equal("Lapis", shopFrame(loaded).stage.name:GetText())
		assert.is_true(rowOf(loaded, "ledger.binding.lapis").selectedMark:IsShown())
	end)

	it("scrolls with the wheel and the brass scroll bar, shown only while the list overflows the tray", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()
		local frame = shopFrame(loaded)
		local scroll, bar = frame.scroll, frame.scrollBar
		assert.is_false(bar:IsShown()) -- nothing overflows in the fake client

		-- The client lays the list out 200 taller than the tray shows.
		scroll.GetVerticalScrollRange = function()
			return 200
		end
		scroll:GetScript("OnScrollRangeChanged")(scroll, 0, 200)
		assert.is_true(bar:IsShown())
		assert.are.same({ 0, 200 }, { bar:GetMinMaxValues() })
		-- A notch glides a third of the list's height (Pagle.WheelScroll), the bar following it.
		local notch = scroll:GetHeight() / 3
		assert.is_true(notch > 100 and notch < 200) -- the tray shows a list some 400 tall
		scroll:GetScript("OnMouseWheel")(scroll, -1)
		loaded.client.update(0.2)
		assert.are.same({ notch, notch }, { scroll:GetVerticalScroll(), bar:GetValue() })
		bar:SetValue(200)
		assert.are.equal(200, scroll:GetVerticalScroll())
		scroll:GetScript("OnMouseWheel")(scroll, -1)
		loaded.client.update(0.2)
		assert.are.equal(200, scroll:GetVerticalScroll(), "it stops at the list's foot")
	end)
end)

describe("The Curio Shop's stage", function()
	it(
		"shows a good for sale's description and Buy for N with the coin, enabled (wallet-and-shop.md › UI,"
			.. " SHOP-R13)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(1000)

			loaded.env.Pagle.OpenShop("hunts.cover.velvet")

			local stage = shopFrame(loaded).stage
			assert.are.equal("Soft to the touch.", stage.description:GetText())
			assert.is_true(stage.buy:IsShown())
			assert.are.equal("Buy for 400", stage.buy.label:GetText())
			assert.is_true(stage.buy.coin:IsShown())
			assert.is_true(stage.buy:IsEnabled())
			assert.are.equal(1, stage.buy:GetAlpha())
			assert.is_false(stage.needed:IsShown())
			assert.is_false(stage.use:IsShown())
			assert.is_false(stage.tags:IsShown())
		end
	)

	it("dims Buy for a price the balance can't cover, with N more Coins (wallet-and-shop.md › UI)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(100)

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")

		local stage = shopFrame(loaded).stage
		assert.is_false(stage.buy:IsEnabled())
		assert.are.equal(0.6, stage.buy:GetAlpha())
		assert.is_true(stage.needed:IsShown())
		assert.are.equal("300 more Coins", stage.needed:GetText())
	end)

	it(
		"shows Owned and Use for an owned good, and Use equips it, then In use (SHOP-R32, wallet-and-shop.md › UI)",
		function()
			local loaded = shopCore()
			local Pagle = loaded.env.Pagle
			loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
			Pagle.OpenShop("core.toaststyle.ripple")
			local stage = shopFrame(loaded).stage
			assert.are.equal("OWNED", stage.tags:GetText())
			assert.is_false(stage.buy:IsShown())
			assert.is_true(stage.use:IsShown())
			assert.are.equal("Use", stage.use.label:GetText())
			assert.is_false(stage.use.coin:IsShown())

			stage.use:Click()

			assert.are.equal("core.toaststyle.ripple", Pagle.GetEquipped("core.toaststyle"))
			assert.are.equal("IN USE", stage.tags:GetText())
			assert.is_false(stage.use:IsShown())
			assert.are.same(
				{ "TOAST STYLE 2 of 16", "Torn Page | default", "Ripple | IN USE" },
				{ listed(loaded)[1], listed(loaded)[2], listed(loaded)[3] }
			)
		end
	)

	it("redraws on AppearanceChanged from elsewhere (SHOP-R33)", function()
		local loaded = shopCore()
		local Pagle = loaded.env.Pagle
		loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
		Pagle.OpenShop("core.toaststyle.page")
		assert.are.equal("IN USE · DEFAULT", shopFrame(loaded).stage.tags:GetText())

		Pagle.SetEquipped("core.toaststyle", "core.toaststyle.ripple")

		assert.are.equal("DEFAULT", shopFrame(loaded).stage.tags:GetText())
		assert.is_true(shopFrame(loaded).stage.use:IsShown())
	end)

	it("shows an earned good's earnedText and that it isn't for sale (wallet-and-shop.md › UI)", function()
		local loaded = loadCore()
		local ledger = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Books" })
		ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
		ledger:RegisterGood({
			id = "ledger.binding.level30",
			slot = "ledger.binding",
			name = "Level 30",
			earnedText = "Angler Level 30",
			isEarned = function()
				return false
			end,
		})
		enterWorld(loaded, 2)

		loaded.env.Pagle.OpenShop("ledger.binding.level30")

		local stage = shopFrame(loaded).stage
		assert.are.equal("Angler Level 30\nA Ledger reward, not for sale", stage.notes:GetText())
		assert.is_false(stage.buy:IsShown())
		assert.are.equal("Angler Level 30", rowOf(loaded, "ledger.binding.level30").tag:GetText())
	end)

	it("draws a crest with no preview of its own on the crest slot's bookplate (SHOP-R25)", function()
		local loaded = shopCore()
		registerPeaks(loaded)

		loaded.env.Pagle.OpenShop("core.crest.peaks")

		local stage = shopFrame(loaded).stage
		assert.is_true(stage.buy:IsShown())
		assert.is_false(stage.swatch:IsShown()) -- the bookplate preview, not the medallion
		local crest
		for _, region in ipairs(loaded.client.frames) do
			for _, child in ipairs(region.children) do
				if child.texture == PEAKS_ICON and child:IsVisible() then
					crest = child
				end
			end
		end
		assert.are.same({ 60, 70 }, { assert(crest, "the crest on the stage's bookplate"):GetSize() })
	end)

	it(
		"opens on nothing for an earned crest, which it doesn't list: Look and Feel equips it (SHOP-R25, SHOP-R40)",
		function()
			local loaded = shopCore()

			loaded.env.Pagle.OpenShop("ledger.crest.elwynn")

			local frame = shopFrame(loaded)
			assert.is_true(frame:IsShown())
			assert.is_true(frame.stage.hint:IsShown()) -- "Pick a look to see it here."
			assert.is_false(frame.stage.name:IsShown())
			assert.are.same(CORE_UNBOUGHT, { unpack(listed(loaded), 1, #CORE_UNBOUGHT) })
		end
	)

	it(
		"shows an earned good's progress as dots under its description, filled or ringed in their colours, its note"
			.. " under them (SHOP-R22, wallet-and-shop.md › UI)",
		function()
			local loaded, handles = shopCore()
			local calls = 0
			huntsFrames(handles.Hunts, function()
				calls = calls + 1
				return {
					{ color = { 0.8, 0.2, 0.1 }, filled = true },
					{ color = { 0.1, 0.4, 0.9 }, filled = false },
					{ color = { 0.6, 0.3, 0.9 }, filled = false },
				}
			end)

			loaded.env.Pagle.OpenShop("hunts.frame.leaf")

			local stage = shopFrame(loaded).stage
			local dots = stage.dots
			assert.is_true(dots:IsShown())
			assert.are.same({ "TOP", stage.description, "BOTTOM", 0, -8 }, { dots:GetPoint() })
			assert.are.same({ "TOPLEFT", stage.description, "BOTTOMLEFT", 0, -26 }, { stage.notes:GetPoint() })
			assert.are.equal("Gild three frames.\nA Hunts reward, not for sale", stage.notes:GetText())
			local shown = {}
			for _, dot in ipairs(dots.dots) do
				if dot:IsShown() then
					shown[#shown + 1] = dot
				end
			end
			assert.are.equal(3, #shown)
			assert.are.same({ 10, 10 }, { shown[1]:GetSize() })
			assert.are.same({ 0.8, 0.2, 0.1, 1 }, shown[1].fill.color)
			assert.is_false(shown[1].hollow:IsShown())
			assert.are.same({ 0.1, 0.4, 0.9, 1 }, shown[2].fill.color)
			assert.is_true(shown[2].hollow:IsShown()) -- ringed: the paper shows inside
			for _, texture in ipairs({ shown[2].edge, shown[2].fill, shown[2].hollow }) do
				assert.are.equal(1, #texture.masks, "each drawn round")
			end
			assert.are.equal(1, calls)

			loaded.env.Pagle.OpenShop("hunts.cover.velvet")
			assert.is_false(dots:IsShown())
			assert.are.same({ "TOPLEFT", stage.description, "BOTTOMLEFT", 0, -6 }, { stage.notes:GetPoint() })
		end
	)

	it(
		"draws the good's preview on its own stage frame, once each time it is selected (wallet-and-shop.md › UI)",
		function()
			local drawn = {}
			local loaded = shopCore(nil, {
				preview = function(stage)
					drawn[#drawn + 1] = stage
				end,
			})
			local Pagle = loaded.env.Pagle

			Pagle.OpenShop("hunts.cover.velvet")
			local stage = shopFrame(loaded).stage
			assert.are.equal(1, #drawn)
			assert.is_true(drawn[1]:IsShown())
			assert.are.equal(stage.area, drawn[1]:GetParent())
			assert.are.same({ 390, 190 }, { drawn[1]:GetSize() }, "the showcase card's well and the paper round it")
			assert.is_false(stage.swatch:IsShown())

			Pagle.OpenShop("hunts.cover.plain")
			assert.is_false(drawn[1]:IsShown())
			assert.is_true(stage.swatch:IsShown()) -- a good with no preview shows its swatch

			Pagle.OpenShop("hunts.cover.velvet")
			assert.are.same({ drawn[1], drawn[1] }, drawn)
			assert.is_true(drawn[1]:IsShown())
		end
	)

	it("reports a preview that raises, and still shows the good (wallet-and-shop.md › UI)", function()
		local loaded = shopCore(nil, {
			preview = function()
				error("no paint")
			end,
		})

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")

		assert.are.equal("Velvet", shopFrame(loaded).stage.name:GetText())
		assert.are.equal(1, #loaded.client.errors)
		assert.matches("no paint", loaded.client.errors[1], 1, true)
	end)
end)

-- Runs frames until no projection is updating.
local function settle(loaded)
	while loaded.ns.projections:IsUpdating() do
		loaded.client.runTimers()
	end
end

-- Runs `seconds` of frames (default 3, past every motion's end) at 20 a second, so the shop's motion plays
-- (adapter/ShopMotion.lua, on Core's driver).
local function play(loaded, seconds)
	for _ = 1, math.floor((seconds or 3) * 20 + 0.5) do
		loaded.client.update(0.05)
	end
end

-- Opens the shop on `goodID` and clicks Buy; returns the bill of sale.
local function askToBuy(loaded, goodID)
	loaded.env.Pagle.OpenShop(goodID)
	shopFrame(loaded).stage.buy:Click()
	return shopFrame(loaded).bill
end

-- The bill of sale as shown.
local function billShown(bill)
	return {
		head = bill.head:GetText(),
		question = bill.question:GetText(),
		icon = (bill.bezel.shield and bill.bezel.Shield or bill.bezel.Icon).texture,
		price = { bill.priceLabel:GetText(), bill.price:GetText(), bill.coin:IsShown() },
		left = { bill.leftLabel:GetText(), bill.left:GetText() },
		fine = bill.fine:GetText(),
		useNow = { bill.useNow.label:GetText(), bill.useNow:GetChecked(), bill.useNow.tick:IsShown() },
		buttons = { bill.buy.label:GetText(), bill.cancelLabel:GetText() },
		shown = bill:IsShown(),
	}
end

describe("Buy on the stage", function()
	it(
		"is disabled for a good the balance doesn't cover, and hidden for an owned good or a default (SHOP-R13)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(399)
			loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
			local Pagle = loaded.env.Pagle

			Pagle.OpenShop("hunts.cover.velvet")
			local stage = shopFrame(loaded).stage
			assert.is_false(stage.buy:IsEnabled())
			assert.are.equal("1 more Coins", stage.needed:GetText())
			stage.buy:Click()
			assert.is_false(shopFrame(loaded).bill:IsShown())
			Pagle.OpenShop("core.toaststyle.ripple")
			assert.is_false(stage.buy:IsShown())
			Pagle.OpenShop("hunts.cover.plain")
			assert.is_false(stage.buy:IsShown())

			handles.Ledger:ReportCoinsEarned(400) -- BalanceChanged re-evaluates it
			Pagle.OpenShop("hunts.cover.velvet")
			assert.is_true(stage.buy:IsEnabled())
		end
	)

	it(
		"is disabled while a projection updates, and enabled again once the update finishes (SHOP-R13, SHOP-R91)",
		function()
			local loaded, handles = shopCore(nil, { entries = history(600) })
			settle(loaded)
			handles.Ledger:ReportCoinsEarned(1000)
			loaded.env.Pagle.OpenShop("hunts.cover.velvet")
			local stage = shopFrame(loaded).stage
			assert.is_true(stage.buy:IsEnabled())

			loaded.ns.walletProjection:Rebuild() -- 601 entries: across frames
			loaded.env.Pagle.OpenShop("hunts.cover.velvet")
			assert.is_true(loaded.ns.projections:IsUpdating())
			assert.is_false(stage.buy:IsEnabled())
			settle(loaded)

			assert.is_true(stage.buy:IsEnabled())
		end
	)
end)

describe("The bill of sale", function()
	it(
		"asks Buy {name}? over the dimmed case, with the medallion, the price, the Coins left after, Use it now"
			.. " ticked, and Buy / Cancel (wallet-and-shop.md › UI: Buy)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(1450)

			local bill = askToBuy(loaded, "hunts.cover.velvet")

			assert.are.same({
				head = "C U R I O   S H O P",
				question = "Buy Velvet?",
				icon = 134939,
				price = { "Price", "400", true },
				left = { "Pagle Coins left after", "1,050" },
				fine = "Looks are yours for good.",
				useNow = { "Use it now", true, true },
				buttons = { "Buy", "CANCEL" },
				shown = true,
			}, billShown(bill))
			assert.are.equal(shopFrame(loaded), bill:GetParent())
			assert.are.equal(SHOP_ART .. "Papers", bill.slip.children[1].texture)
		end
	)

	it(
		"buys a 150-Coin good with 200 Coins: one U1, the balance reads 50, and it's In use at once (SHOP-R10,"
			.. " LOG-R39, wallet-and-shop.md › UI: Buy)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(200)
			local entries = loaded.env.PagleLog.entries
			local before = #entries
			local bill = askToBuy(loaded, "core.toaststyle.ripple")

			bill.buy:Click()
			play(loaded)

			assert.are.equal(before + 1, #entries)
			-- The logged-in character is the saved log's second (LOG-R25).
			assert.matches("^U1|2|%d+|%d+|core%.toaststyle%.ripple|150$", entries[#entries])
			assert.are.equal(50, loaded.env.Pagle.GetBalance().balance)
			assert.are.equal("core.toaststyle.ripple", loaded.env.Pagle.GetEquipped("core.toaststyle"))
			local frame = shopFrame(loaded)
			assert.are.equal("50", frame.purse.balance:GetText())
			assert.are.equal("IN USE", frame.stage.tags:GetText())
			assert.is_false(frame.stage.buy:IsShown())
			assert.is_false(bill:IsShown())
		end
	)

	it("with Use it now unticked, buys the good owned but not in use (wallet-and-shop.md › UI: Buy)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(600)
		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		bill.useNow:Click()
		assert.is_false(bill.useNow.tick:IsShown())
		bill.buy:Click()
		play(loaded)

		assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal("core.toaststyle.page", loaded.env.Pagle.GetEquipped("core.toaststyle"))
		local stage = shopFrame(loaded).stage
		assert.are.equal("OWNED", stage.tags:GetText())
		assert.is_true(stage.use:IsShown())
		-- The next Buy asks with Use it now ticked again.
		askToBuy(loaded, "core.soundset.gilded")
		assert.are.same({ "Use it now", true, true }, billShown(bill).useNow)
	end)

	it("shows a crest as its shield on the bill and the flyer, and a medallion again after (SHOP-R25)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(600)
		-- No crest is for sale (SHOP-R25), but the bill draws any good of the slot as its shield: one of Core's here.
		local CREST = "Interface\\AddOns\\Pagle\\media\\crests\\plain"
		loaded.ns.RegisterCoreGood({
			id = "core.crest.peaks",
			slot = "core.crest",
			name = "Peaks",
			tier = 2,
			icon = CREST,
		})

		local bill = askToBuy(loaded, "core.crest.peaks")
		local frame = shopFrame(loaded)
		assert.is_true(bill.bezel.Shield:IsShown())
		assert.is_false(bill.bezel.Icon:IsShown())
		assert.are.equal(CREST, billShown(bill).icon)
		bill.buy:Click()
		assert.is_true(frame.flyer.Shield:IsShown())
		assert.are.equal(CREST, frame.flyer.Shield.texture)
		play(loaded)

		askToBuy(loaded, "core.toaststyle.ripple")
		assert.is_false(bill.bezel.Shield:IsShown())
		assert.is_true(bill.bezel.Icon:IsShown())
	end)

	it("buys nothing on Cancel or Esc; Esc closes only the bill, and other keys go on to the game", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(200)
		local before = #loaded.env.PagleLog.entries

		local bill = askToBuy(loaded, "core.toaststyle.ripple")
		bill.cancel:Click()
		play(loaded) -- it lifts away
		assert.is_false(bill:IsShown())
		askToBuy(loaded, "core.toaststyle.ripple")
		bill:GetScript("OnKeyDown")(bill, "W")
		assert.is_true(bill.propagatesKeys)
		assert.is_true(bill:IsShown())
		loaded.client.pressKey("ESCAPE")
		play(loaded)

		assert.is_false(bill:IsShown())
		assert.is_false(bill.propagatesKeys)
		assert.is_true(shopFrame(loaded):IsShown())
		assert.are.equal(before, #loaded.env.PagleLog.entries)
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal(200, loaded.env.Pagle.GetBalance().balance)
	end)

	it("does nothing when a projection starts updating between opening it and confirming (SHOP-R13)", function()
		local loaded, handles = shopCore(nil, { entries = history(600) })
		settle(loaded)
		handles.Ledger:ReportCoinsEarned(200)
		local before = #loaded.env.PagleLog.entries
		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		loaded.ns.walletProjection:Rebuild()
		bill.buy:Click()
		settle(loaded)

		assert.is_false(bill:IsShown())
		assert.are.equal(before, #loaded.env.PagleLog.entries)
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal(200, loaded.env.Pagle.GetBalance().balance)
	end)

	it("raises no Announcement (ANN-R23)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(200)
		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		bill.buy:Click()
		loaded.client.runTimers()

		assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.is_nil(next(loaded.ns.announcementFrames or {})) -- no Announcement frame was ever drawn
	end)

	it("closes with the shop: in combat, and when the shop closes (SHOP-R41, CORE-R33)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(200)
		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		setCombat(loaded, true)

		assert.is_false(bill:IsShown())
		assert.is_false(shopFrame(loaded):IsShown())
		setCombat(loaded, false)
		askToBuy(loaded, "core.toaststyle.ripple")
		shopFrame(loaded).CloseButton:Click()
		assert.is_false(bill:IsShown())
		loaded.env.Pagle.OpenShop()
		assert.is_false(bill:IsShown()) -- it doesn't come back with the shop
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
	end)
end)

describe("The purse's held line", function()
	it(
		"shows while earned is below spent, the balance reading 0, never a negative number or debt (SHOP-R12)",
		function()
			local entries = history(2)
			entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1000, "core.soundset.gilded", 900)
			local loaded = shopCore({ global = { coins = { earned = { Ledger = 600 } } } }, { entries = entries })

			loaded.env.Pagle.OpenShop()

			local purse = shopFrame(loaded).purse
			assert.are.equal("0", purse.balance:GetText())
			assert.is_true(purse.held:IsShown())
			assert.are.equal(
				"Your balance is 0 while Pagle re-counts earlier Coins. New Coins fill that in first.",
				purse.held:GetText()
			)
			for _, region in ipairs(loaded.client.frames) do
				for _, child in ipairs(region.children) do
					local text = tostring(child.text)
					assert.falsy(text:find("-%d") or text:lower():find("debt"))
				end
			end
		end
	)

	it("hides once new Coins fill it in (SHOP-R12)", function()
		local entries = history(2)
		entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1000, "core.soundset.gilded", 900)
		local loaded, handles = shopCore({ global = { coins = { earned = { Ledger = 600 } } } }, { entries = entries })
		loaded.env.Pagle.OpenShop()

		handles.Ledger:ReportCoinsEarned(1000)

		local purse = shopFrame(loaded).purse
		assert.are.equal("100", purse.balance:GetText())
		assert.is_false(purse.held:IsShown())
	end)
end)

-- The sounds the shop played, each as "<sound kit id> <channel>".
local function shopSounds(loaded)
	local sounds = {}
	for _, sound in ipairs(loaded.client.sounds) do
		if sound:match("^%d+ ") then
			sounds[#sounds + 1] = sound
		end
	end
	return sounds
end

-- Where `region`'s first anchor puts it: its x and y offsets.
local function offset(region)
	local _, _, _, x, y = region:GetPoint(1)
	return { x, y }
end

describe("The Curio Shop's motion and sounds (wallet-and-shop.md › UI: Motion and sound)", function()
	it("plays the case opening and closing on the SFX channel, once each", function()
		local loaded = shopCore()

		loaded.env.Pagle.OpenShop()
		loaded.env.Pagle.OpenShop("core.toaststyle.ripple") -- already open: no sound
		shopFrame(loaded).CloseButton:Click()

		assert.are.same({ "5274 SFX", "5275 SFX" }, shopSounds(loaded))
	end)

	it("drops the bill of sale in over the dimming case, and lifts it away on Cancel", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(200)

		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		assert.are.same({ 0, 0 }, { bill.shade:GetAlpha(), bill.slip:GetAlpha() })
		assert.are.same({ 290, -32 }, offset(bill.slip)) -- 24 units up
		play(loaded, 0.3)
		assert.are.same({ 1, 1 }, { bill.shade:GetAlpha(), bill.slip:GetAlpha() })
		assert.are.same({ 290, -56 }, offset(bill.slip))

		bill.cancel:Click()
		play(loaded, 0.1)
		assert.is_true(bill:IsShown())
		assert.is_true(bill.slip:GetAlpha() < 1)
		bill.buy:Click() -- it no longer asks
		play(loaded, 0.2)
		assert.is_false(bill:IsShown())
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
	end)

	it(
		"plays a purchase: the press, the seal and its stamp, the medallion flying to the row, the purse counting"
			.. " down with the coin, then IN USE in the row and on the lid, the slot's old good stepping down",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(200)
			local bill = askToBuy(loaded, "core.toaststyle.ripple")
			play(loaded, 0.5)
			local frame = shopFrame(loaded)
			local purse, stage, row = frame.purse, frame.stage, rowOf(loaded, "core.toaststyle.ripple")

			bill.buy:Click()

			assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple")) -- bought at once (SHOP-R10)
			assert.are.same({ "5274 SFX", "865 SFX" }, shopSounds(loaded))
			assert.are.equal("200", purse.balance:GetText()) -- the window shows it as the motion has it
			assert.is_true(stage.buy:IsShown())
			play(loaded, 0.45)
			assert.are.same({ "5274 SFX", "865 SFX", "1204 SFX" }, shopSounds(loaded))
			assert.is_true(bill.seal:IsShown())
			assert.are.equal(1, bill.seal:GetAlpha())
			play(loaded, 0.5) -- 0.95 s: the medallion flies, the bill lifts away
			assert.is_true(frame.flyer:IsShown())
			assert.is_false(bill.bezel:IsShown())
			assert.are.same({ "5274 SFX", "865 SFX", "1204 SFX", "120 SFX" }, shopSounds(loaded))
			play(loaded, 0.3) -- 1.25 s: the purse counts down
			local counting = tonumber(purse.balance:GetText())
			assert.is_true(counting > 50 and counting < 200)
			assert.is_false(bill:IsShown())
			play(loaded, 0.4) -- 1.65 s: delivered
			assert.are.equal("IN USE", row.tag:GetText())
			assert.is_true(row.price:GetAlpha() < 1)
			assert.are.equal("default", rowOf(loaded, "core.toaststyle.page").stepDown:GetText())

			play(loaded)

			assert.are.equal("50", purse.balance:GetText())
			assert.are.same(
				{ "TOAST STYLE 2 of 16", "Torn Page | default", "Ripple | IN USE" },
				{ listed(loaded)[1], listed(loaded)[2], listed(loaded)[3] }
			)
			assert.is_false(rowOf(loaded, "core.toaststyle.page").stepDown:IsShown())
			assert.are.equal(0, row.glow:GetAlpha())
			assert.are.equal("IN USE", stage.tags:GetText())
			assert.are.equal(1, stage.tags:GetAlpha())
			assert.is_false(stage.buy:IsShown())
			assert.is_false(frame.flyer:IsShown())
			assert.is_false(bill.seal:IsShown())
			assert.are.equal(purse.coin.w0, purse.coin:GetWidth())
		end
	)

	it("with Animations off, shows a purchase at once, with only Buy's sound (SET-R30)", function()
		local loaded, handles = shopCore()
		loaded.ns.db.profile.announcements.motion = false
		handles.Ledger:ReportCoinsEarned(200)
		local bill = askToBuy(loaded, "core.toaststyle.ripple")
		assert.are.same({ 1, 1 }, { bill.shade:GetAlpha(), bill.slip:GetAlpha() })

		bill.buy:Click()

		local frame = shopFrame(loaded)
		assert.is_false(bill:IsShown())
		assert.are.equal("50", frame.purse.balance:GetText())
		assert.are.equal("IN USE", frame.stage.tags:GetText())
		assert.are.same({ "5274 SFX", "865 SFX" }, shopSounds(loaded))
	end)

	it("settles a purchase the shop closes on: it opens again as bought", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(200)
		local bill = askToBuy(loaded, "core.toaststyle.ripple")
		bill.buy:Click()
		play(loaded, 0.9)

		shopFrame(loaded).CloseButton:Click()
		loaded.env.Pagle.OpenShop()

		local frame = shopFrame(loaded)
		assert.is_false(bill:IsShown())
		assert.is_false(frame.flyer:IsShown())
		assert.are.equal("50", frame.purse.balance:GetText())
		assert.are.equal("Ripple | IN USE", listed(loaded)[3])
		play(loaded)
		assert.are.equal("50", frame.purse.balance:GetText())
	end)

	it("shakes N more Coins with a soft no when Buy is clicked without enough Coins", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(100)
		loaded.env.Pagle.OpenShop("hunts.cover.velvet")
		local stage = shopFrame(loaded).stage
		assert.is_true(stage.short:IsShown())

		stage.short:Click()
		play(loaded, 0.05)

		assert.is_true(offset(stage.needed)[1] < 14) -- on its way 6 units left, by 0.06 s
		assert.are.same({ "5274 SFX", "857 SFX" }, shopSounds(loaded))
		play(loaded)
		assert.are.same({ 14, 0 }, offset(stage.needed))
		assert.is_false(shopFrame(loaded).bill:IsShown())
		handles.Ledger:ReportCoinsEarned(400)
		assert.is_false(stage.short:IsShown())
	end)

	it("shrinks to fit a screen too small for it, never grows, and fits again when the UI scale changes", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()
		local frame = shopFrame(loaded)
		assert.are.equal(1, frame:GetScale())

		loaded.env.UIParent:SetSize(1188, 668) -- UI scale 1.15 on a 1366 x 768 screen
		loaded.client.fire("UI_SCALE_CHANGED")

		assert.are.equal((668 - 48) / 680, frame:GetScale())
		assert.are.same({ "CENTER", loaded.env.UIParent, "CENTER", 0, -20 }, { frame:GetPoint(1) })
	end)
end)

describe("The Curio Shop's art", function()
	it("draws every word in a font object of the kit's bundled faces", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop("hunts.cover.velvet")
		local frame = shopFrame(loaded)

		for _, fontString in ipairs({
			frame.purse.balance,
			frame.purse.label,
			frame.search.Instructions,
			frame.stage.name,
			frame.stage.description,
			frame.bill.question,
		}) do
			assert.matches("^PagleShop%a+$", fontString.fontObject)
		end
		assert.are.equal("PagleShopBalance", frame.purse.balance.fontObject)
		assert.are.equal("PagleShopGoodName", frame.stage.name.fontObject)
		for key, name in pairs(loaded.ns.SHOP_FONTS) do
			assert.are.equal("PagleShop" .. key, name)
		end
	end)

	it("ships each atlas as a BLP of its size, and each sprite inside its texture", function()
		local loaded = shopCore()
		for _, name in ipairs({ "Case", "Shop", "Papers" }) do
			local atlas = loaded.ns.ATLASES[name]
			assert.are.equal(SHOP_ART .. name, atlas.file)
			local blp = readFile("addons/Pagle/media/shop/" .. name .. ".blp")
			assert.are.equal("BLP2", blp:sub(1, 4))
			local width = blp:byte(13) + blp:byte(14) * 256 + blp:byte(15) * 65536
			local height = blp:byte(17) + blp:byte(18) * 256 + blp:byte(19) * 65536
			assert.are.same({ atlas.width, atlas.height }, { width, height }, name)
			for sprite, rect in pairs(atlas.sprites) do
				local inside = rect.x >= 0
					and rect.x + rect.w <= atlas.width
					and rect.y >= 0
					and rect.y + rect.h <= atlas.height
				assert.are.equal(sprite, inside and sprite)
			end
		end
	end)

	it("ships the fonts it draws in, each with its licence", function()
		for _, file in ipairs({
			"IMFeENrm28P.ttf",
			"IMFeENit28P.ttf",
			"Marcellus-Regular.ttf",
			"Caveat-Medium.ttf",
			"Caveat-SemiBold.ttf",
			"Caveat-Bold.ttf",
			"OFL-IMFellEnglish.txt",
			"OFL-Marcellus.txt",
			"OFL-Caveat.txt",
		}) do
			assert.are.equal(file, #readFile("addons/Pagle/media/fonts/" .. file) > 0 and file)
		end
	end)
end)
