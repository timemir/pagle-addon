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

-- Core's toast styles and sound sets for sale (SHOP-R25), each slot's in the order the list shows them after its
-- default (SHOP-R27): cheapest tier first, goods of a tier in registration order, by their lore names, with their
-- tiers' prices (SHOP-R22); the toast styles that aren't for sale after those that are.
local EXPANSION = {
	toaststyle = {
		{ "Ripple", 250 },
		{ "Lantern Glow", 250 },
		{ "Ship's Log", 250 },
		{ "Birch Scroll", 250 },
		{ "Tidepool", 250 },
		{ "Sea Chart", 250 },
		{ "Frostbitten", 250 },
		{ "Goblin Ticker", 400 },
		{ "Kelp & Pearl", 400 },
		{ "Moonlit Vellum", 400 },
		{ "Pressed Leaf", 400 },
		{ "Driftglass Bottle", 400 },
		{ "Illuminated Folio", 400 },
		{ "Rune-Plate", 900 },
		{ "Ooze", 900 },
		{ "Mechanical Angler", 900 },
		{ "Widow's Web", 900 },
		{ "Glacier Heart", 900 },
		{ "Black Flag", 900 },
		{ STORM_NAME, 3000 },
		{ "Hive Chitin", 3000 },
		{ "Magma Flow", 3000 },
		{ "Arcane Sigil", 3000 },
		-- The round two's not for sale (SHOP-R50): its row's tag, not a price. Sonar Scope, earned, has no fallback yet and
		-- isn't listed (SHOP-R24, SHOP-R29).
		{ "Prize Foil", nil, "From a crate" },
	},
	soundset = {
		{ "Rain on the Lake", 250 },
		{ "Marimba Shore", 250 },
		{ "Ship's Bell", 250 },
		{ "Squeaky", 250 },
		{ "Bubbleworks", 250 },
		{ "Gilded", 400 },
		{ "Kalimba Creek", 400 },
		{ "Music Box", 400 },
		{ "Glass Floats", 400 },
		{ "Steel Pan Lagoon", 400 },
		{ "Tavern Dulcimer", 400 },
		{ "Goblin Till", 400 },
		{ "Kazoo Parade", 400 },
		{ "Arcade Cabinet", 400 },
		{ "Boing!", 400 },
		{ "Slime Time", 400 },
		{ "Frost Chimes", 900 },
		{ "Harp of the Glade", 900 },
		{ "Gnomish Gizmo", 900 },
		{ "Mrglglgl", 900 },
		{ "Pirate Parrot", 900 },
		{ "Gnomish Laser", 900 },
		{ "Silithid Swarm", 900 },
		{ "Succubus' Whisper", 900 },
		{ "War Drums", 3000 },
		{ "Dragon's Roost", 3000 },
	},
}

-- `lines` with the rows of Core's slot `slot` ("toaststyle" or "soundset") after them, those priced at
-- most `most` (all by default, the ones not for sale with them), as the list shows them: "<name> | <price or tag>".
---@param lines string[]
---@param slot string
---@param most number?
---@return string[]
local function withExpansion(lines, slot, most)
	local all = { unpack(lines) }
	for _, good in ipairs(EXPANSION[slot]) do
		if good[3] then
			if not most then
				all[#all + 1] = ("%s | %s"):format(good[1], good[3])
			end
		elseif good[2] <= (most or math.huge) then
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

-- Core's own slots (SHOP-R25) as the list shows them while nothing of Core's is bought and the balance is under 250,
-- the crest slot with Plain alone: its earned crests, the Ledger's two zone crests and Core's fish crests, aren't
-- listed or counted (SHOP-R25).
local CORE_UNBOUGHT = concat({
	withExpansion({ "TOAST STYLE 1 of 25", "Torn Page | IN USE" }, "toaststyle"),
	withExpansion({ "SOUND SET 1 of 27", "Driftwood | IN USE" }, "soundset"),
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
	"Birch Bark | 250",
	"Tide-Chart Linen | 250",
	"Tarred Sailcloth | 250",
	"Oilskin Yellow | 250",
	"Canvas Field Pad | 250",
	"Waxed Kraft | 250",
	"Tartan Wool | 250",
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
	"Coral Inlay | 3,000",
	"Scrimshaw Panel | 3,000",
	"Shagreen and Bone | 3,000",
	"Mother-of-Pearl | 10,000",
	"Gilded Trophy Case | 10,000",
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
-- `options.preview` is Velvet's preview; `options.entries` is the saved log's entries; `options.collection` is the
-- Ledger's def.collection (CORE-R45). Returns the loaded addon and the handles.
local function shopCore(saved, options)
	options = options or {}
	local loaded = loadCore(options.entries, saved)
	local Pagle = loaded.env.Pagle
	local ledger =
		Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10, collection = options.collection })
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
-- "<name>", each row as "<name> | <tag or price>", "<name> | <price> | <tag>" for an earned good on sale (SHOP-R28).
local function listed(loaded)
	local lines = {}
	for _, line in ipairs(shopFrame(loaded).lines) do
		if line:IsShown() then
			if line.header and not line.count:IsShown() then
				lines[#lines + 1] = line.label:GetText()
			elseif line.header then
				lines[#lines + 1] = ("%s %s"):format(line.label:GetText(), line.count:GetText())
			elseif line.price:IsShown() and line.tag:IsShown() then
				lines[#lines + 1] = ("%s | %s | %s"):format(
					line.label:GetText(),
					line.price.amount:GetText(),
					line.tag:GetText()
				)
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
-- (Ash, wooden, tier 1) and Gold leaf (gilt, earned never, "2 of 3 gilded", with `progress` as its progress), which
-- the shop lists from `fallbackFrom` on, at tier 2's price (SHOP-R24, SHOP-R28), never when that is nil.
local function huntsFrames(hunts, progress, fallbackFrom)
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
		fallbackTier = fallbackFrom and 2 or nil,
		fallbackFrom = fallbackFrom,
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
		assert.are.equal("Ripple | 250", listed(loaded)[3])
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

	it(
		"lists a good of the sixth price tier at 25,000 Coins, in red while the balance falls short (SHOP-R22)",
		function()
			local loaded, handles = shopCore()
			handles.Hunts:RegisterGood({ id = "hunts.cover.regalia", slot = "hunts.cover", name = "Regalia", tier = 6 })

			loaded.env.Pagle.OpenShop()

			local regalia = rowOf(loaded, "hunts.cover.regalia")
			assert.is_true(regalia.price:IsShown())
			assert.are.equal("25,000", regalia.price.amount:GetText())
			assert.are.same(
				loaded.ns.SHOP_INKS.stamp,
				{ unpack(regalia.price.amount.textColor, 1, 3) },
				"a price the balance can't cover is in the stamp's red"
			)
			assert.is_true(regalia.price.coin:IsShown())
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

	it(
		"crops a good's item icon of its own square border, and leaves a crest's shield its own coords (#421)",
		function()
			local loaded = shopCore()
			loaded.env.Pagle.OpenShop()
			local bezel = rowOf(loaded, "core.crest.plain").bezel
			local crop = loaded.ns.ICON_CROP
			local cropped = { crop, 1 - crop, crop, 1 - crop }

			loaded.ns.SetShopBezel(bezel, 136245)
			assert.are.same(cropped, bezel.Icon.texCoord)

			loaded.ns.SetShopBezel(bezel, nil)
			assert.are.same(cropped, bezel.Icon.texCoord, "the question mark is an item icon too")

			loaded.ns.SetShopBezel(bezel, 136245, false, true)
			assert.are.same({ 0.5 - 60 / 140, 0.5 + 60 / 140, 0, 1 }, bezel.Shield.texCoord)
		end
	)

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
		assert.are.same({ "TOAST STYLE 1 of 25", "Ripple | 250" }, listed(loaded))
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
				withExpansion({ "TOAST STYLE 1 of 25" }, "toaststyle", 500),
				withExpansion({ "SOUND SET 1 of 27" }, "soundset", 500),
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
			"TOAST STYLE 1 of 25",
			"Torn Page | IN USE",
			"SOUND SET 1 of 27",
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
		assert.are.equal(9 + 8 + 40 + 33, #listed(loaded))
		filters.all:Click()
		assert.are.equal(15 + 8 + 40 + 34, #listed(loaded))
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
			assert.are.equal(15 + 8 + 40 + 34, #listed(loaded))
		end
	)

	it(
		"heads a grouped slot's groups with their names in the chips' gilt capitals, never as goods (SHOP-R27,"
			.. " wallet-and-shop.md › UI)",
		function()
			local loaded, handles = shopCore()
			huntsFrames(handles.Hunts, nil, 1)

			loaded.env.Pagle.OpenShop()

			local shown = listed(loaded)
			assert.are.same({
				"FRAME 1 of 3",
				"Plain | IN USE",
				"GILT FRAMES",
				"Gold leaf | 400 | 2 of 3 gilded",
				"WOODEN FRAMES",
				"Ash | 250",
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

		assert.are.same({ "FRAME 1 of 2", "WOODEN FRAMES", "Ash | 250" }, listed(loaded))
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
				{ "TOAST STYLE 2 of 25", "Torn Page | default", "Ripple | IN USE" },
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

	it(
		"shows an earned good on sale at its fallback price with its earnedText and Buy (SHOP-R28, wallet-and-shop.md › UI)",
		function()
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
				fallbackTier = 2,
				fallbackFrom = 1,
			})
			enterWorld(loaded, 2)

			loaded.env.Pagle.OpenShop("ledger.binding.level30")

			local stage = shopFrame(loaded).stage
			assert.are.equal("Angler Level 30\nOr buy it for 400", stage.notes:GetText())
			assert.is_true(stage.buy:IsShown())
			local row = rowOf(loaded, "ledger.binding.level30")
			assert.are.same(
				{ "Angler Level 30", true, "400", row.price },
				{ row.tag:GetText(), row.tag:IsShown(), row.price.amount:GetText(), row.price }
			)
			assert.is_true(row.price:IsShown()) -- the price tag, with the earned tag beside it
		end
	)

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
		"opens the Collection on an earned crest the shop doesn't list, through def.collection (SHOP-R40, CORE-R45)",
		function()
			local opened = {}
			local loaded = shopCore(nil, {
				collection = function(goodID)
					opened[#opened + 1] = goodID
				end,
			})

			loaded.env.Pagle.OpenShop("ledger.crest.elwynn")
			loaded.env.Pagle.OpenShop("core.crest.fish.6359") -- one of Core's fish crests, earned and unlisted too

			assert.are.same({ "ledger.crest.elwynn", "core.crest.fish.6359" }, opened)
			assert.is_nil(shopFrame(loaded)) -- the shop never opened
		end
	)

	it("opens the shop, not the Collection, for a good the shop lists, an unknown good or none (SHOP-R40)", function()
		local opened = {}
		local loaded = shopCore(nil, {
			collection = function(goodID)
				opened[#opened + 1] = goodID
			end,
		})

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")
		loaded.env.Pagle.OpenShop("hunts.cover.none")
		loaded.env.Pagle.OpenShop("core.toaststyle.page")
		loaded.env.Pagle.OpenShop()

		assert.are.same({}, opened)
		assert.is_true(shopFrame(loaded):IsShown())
	end)

	it("opens the Collection for an earned good of a Module off, owned or not (SHOP-R35, SHOP-R40)", function()
		local opened = {}
		local loaded = shopCore({
			global = {
				goods = {
					["hunts.cover.gold"] = {
						name = "Gold",
						slot = "hunts.cover",
						slotLabel = "Notebook cover",
						category = "Trackers",
						module = "Hunts",
						earned = true,
					},
				},
			},
		}, {
			noHunts = true,
			collection = function(goodID)
				opened[#opened + 1] = goodID
			end,
		})

		loaded.env.Pagle.OpenShop("hunts.cover.gold")

		assert.are.same({ "hunts.cover.gold" }, opened)
	end)

	it("prints SHOP-R41's line, and opens no Collection, while restricted (SHOP-R41, SHOP-R40)", function()
		local opened = {}
		local loaded = shopCore(nil, {
			collection = function(goodID)
				opened[#opened + 1] = goodID
			end,
		})
		setCombat(loaded, true)

		loaded.env.Pagle.OpenShop("ledger.crest.elwynn")

		assert.are.same({}, opened)
		assert.are.same({ AFTER_COMBAT }, loaded.printed)
	end)

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
			end, 1)

			loaded.env.Pagle.OpenShop("hunts.frame.leaf")

			local stage = shopFrame(loaded).stage
			local dots = stage.dots
			assert.is_true(dots:IsShown())
			assert.are.same({ "TOP", stage.description, "BOTTOM", 0, -8 }, { dots:GetPoint() })
			assert.are.same({ "TOPLEFT", stage.description, "BOTTOMLEFT", 0, -26 }, { stage.notes:GetPoint() })
			assert.are.equal("Gild three frames.\nOr buy it for 400", stage.notes:GetText())
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
		"buys a 250-Coin good with 300 Coins: one U1, the balance reads 50, and it's In use at once (SHOP-R10,"
			.. " LOG-R39, wallet-and-shop.md › UI: Buy)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(300)
			local entries = loaded.env.PagleLog.entries
			local before = #entries
			local bill = askToBuy(loaded, "core.toaststyle.ripple")

			bill.buy:Click()
			play(loaded)

			assert.are.equal(before + 1, #entries)
			-- The logged-in character is the saved log's second (LOG-R25).
			assert.matches("^U1|2|%d+|%d+|core%.toaststyle%.ripple|250$", entries[#entries])
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
		handles.Ledger:ReportCoinsEarned(700)
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
		handles.Ledger:ReportCoinsEarned(700)
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
		handles.Ledger:ReportCoinsEarned(300)
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
		assert.are.equal(300, loaded.env.Pagle.GetBalance().balance)
	end)

	it("does nothing when a projection starts updating between opening it and confirming (SHOP-R13)", function()
		local loaded, handles = shopCore(nil, { entries = history(600) })
		settle(loaded)
		handles.Ledger:ReportCoinsEarned(300)
		local before = #loaded.env.PagleLog.entries
		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		loaded.ns.walletProjection:Rebuild()
		bill.buy:Click()
		settle(loaded)

		assert.is_false(bill:IsShown())
		assert.are.equal(before, #loaded.env.PagleLog.entries)
		assert.is_false(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal(300, loaded.env.Pagle.GetBalance().balance)
	end)

	it("raises no Announcement (ANN-R23)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(300)
		local bill = askToBuy(loaded, "core.toaststyle.ripple")

		bill.buy:Click()
		loaded.client.runTimers()

		assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.is_nil(next(loaded.ns.announcementFrames or {})) -- no Announcement frame was ever drawn
	end)

	it("closes with the shop: in combat, and when the shop closes (SHOP-R41, CORE-R33)", function()
		local loaded, handles = shopCore()
		handles.Ledger:ReportCoinsEarned(300)
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
		handles.Ledger:ReportCoinsEarned(300)

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
			handles.Ledger:ReportCoinsEarned(300)
			local bill = askToBuy(loaded, "core.toaststyle.ripple")
			play(loaded, 0.5)
			local frame = shopFrame(loaded)
			local purse, stage, row = frame.purse, frame.stage, rowOf(loaded, "core.toaststyle.ripple")

			bill.buy:Click()

			assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.ripple")) -- bought at once (SHOP-R10)
			assert.are.same({ "5274 SFX", "865 SFX" }, shopSounds(loaded))
			assert.are.equal("300", purse.balance:GetText()) -- the window shows it as the motion has it
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
			assert.is_true(counting > 50 and counting < 300)
			assert.is_false(bill:IsShown())
			play(loaded, 0.4) -- 1.65 s: delivered
			assert.are.equal("IN USE", row.tag:GetText())
			assert.is_true(row.price:GetAlpha() < 1)
			assert.are.equal("default", rowOf(loaded, "core.toaststyle.page").stepDown:GetText())

			play(loaded)

			assert.are.equal("50", purse.balance:GetText())
			assert.are.same(
				{ "TOAST STYLE 2 of 25", "Torn Page | default", "Ripple | IN USE" },
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
		handles.Ledger:ReportCoinsEarned(300)
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
		handles.Ledger:ReportCoinsEarned(300)
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

describe("The Curio crate in the window", function()
	-- The crate's row, apart from the pooled lines.
	local function crateLine(loaded)
		return shopFrame(loaded).crateLine
	end

	-- How far down the scroll child `line` sits.
	local function topOf(line)
		local _, _, _, _, y = line:GetPoint(1)
		return -y
	end

	-- The crate's odds on the stage as shown: "<name> | <goods left or payback> | <chance>".
	local function oddsShown(stage)
		local lines = {}
		for _, line in ipairs(stage.odds.lines) do
			if line:IsShown() then
				lines[#lines + 1] = ("%s | %s | %s"):format(
					line.label:GetText(),
					line.detail:GetText(),
					line.chance:GetText()
				)
			end
		end
		return lines
	end

	-- Every pool good bought, at 0.
	local function ownAll(loaded)
		for _, row in ipairs(loaded.ns.CRATE_POOL) do
			loaded.ns.RecordPurchase(row.id, 0)
		end
	end

	it(
		"draws its own row at the very top of the list, above the first slot, whichever chip is on (SHOP-R50,"
			.. " wallet-and-shop.md › UI)",
		function()
			local loaded = shopCore()
			loaded.env.Pagle.OpenShop()
			local frame = shopFrame(loaded)

			for i = 1, #frame.chips do
				if frame.chips[i]:IsShown() then
					frame.chips[i]:Click()
					local line = crateLine(loaded)
					assert.is_true(line:IsShown(), frame.chips[i].label:GetText())
					assert.are.same({ "Curio crate", "1,500", 0 }, {
						line.label:GetText(),
						line.price.amount:GetText(),
						topOf(line),
					})
					assert.are.equal(44 + 6, topOf(frame.lines[1]), "the first slot's header under it")
				end
			end
			frame.chips[1]:Click()
			frame.search:Type("ripple")
			assert(not crateLine(loaded):IsShown(), "a search its label doesn't match")
			assert.are.same({ "TOAST STYLE 1 of 25", "Ripple | 250" }, listed(loaded))
		end
	)

	it(
		"shows each crate tier's odds, its goods left or payback, and the pity on the stage when picked (SHOP-R54)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(3500)
			loaded.env.Pagle.OpenShop()

			crateLine(loaded):Click()

			local stage = shopFrame(loaded).stage
			assert.are.equal("Curio crate", stage.name:GetText())
			assert.are.same({
				"Plain | 28 left | 40%",
				"Fine | 35 left | 26%",
				"Lively | 27 left | 16%",
				"Showpiece | 9 left | 10%",
				"Marvel | 2 left | 5%",
				"Heirloom | pays back 1,500 | 2.5%",
				"Curio | 1 left | 0.5%",
			}, oddsShown(stage))
			assert.are.same({ true, "A Curio within 100 more crates" }, { stage.pity:IsShown(), stage.pity:GetText() })
			assert.is_false(stage.description:IsShown() and stage.description:GetText() ~= "")
			assert.is_true(stage.buy:IsEnabled())
			assert.is_true(crateLine(loaded).selectedMark:IsShown())
			local first, last = stage.odds.lines[1], stage.odds.lines[7]
			assert.are.same({ 0xe9, 0xe6, 0xdf }, {
				math.floor(first.pip.color[1] * 255 + 0.5),
				math.floor(first.pip.color[2] * 255 + 0.5),
				math.floor(first.pip.color[3] * 255 + 0.5),
			})
			assert.are.equal(0xff, math.floor(last.pip.color[1] * 255 + 0.5))

			for _, row in ipairs(loaded.ns.CRATE_POOL) do
				if row.tier == 5 then
					loaded.ns.RecordPurchase(row.id, 0)
				end
			end
			loaded.env.Pagle.OpenShop("core.crate")
			assert.are.equal("Marvel | pays back 1,500 | 5%", oddsShown(shopFrame(loaded).stage)[5])
		end
	)

	it(
		"leaves the list once every pool good is owned, showing the list's first good, and returns when the pool grows (SHOP-R54)",
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(3500)
			loaded.env.Pagle.OpenShop("core.crate")
			local frame = shopFrame(loaded)
			assert.are.equal("Curio crate", frame.stage.name:GetText())

			ownAll(loaded)
			loaded.env.Pagle.OpenShop() -- a redraw: the wallet's hand-over comes after the balance's event

			assert.is_false(crateLine(loaded):IsShown())
			assert.are.equal("Torn Page", frame.stage.name:GetText(), "the list's first good")
			assert.are.equal(0, topOf(frame.lines[1]), "the first slot's header at the top")
			loaded.env.Pagle.OpenShop("core.crate")
			assert(frame.stage.hint:IsShown(), "OpenShop on the crate selects nothing now")
			assert.are.equal(nil, frame.stage.buy:IsShown() and "buy" or nil)

			local pool = loaded.ns.CRATE_POOL
			local grown = { unpack(pool) }
			grown[#grown + 1] = { id = "core.binding.later", tier = 1, kind = "binding", since = 1 }
			loaded.ns.CRATE_POOL = grown
			loaded.env.Pagle.OpenShop("core.crate")

			assert.is_true(crateLine(loaded):IsShown())
			assert.are.equal("Curio crate", frame.stage.name:GetText())
			assert.are.equal("Plain | 1 left | 40%", oddsShown(frame.stage)[1])
			loaded.ns.CRATE_POOL = pool
		end
	)

	it(
		'opens one from its bill, "Open a Curio crate?", with no "Use it now", and ends on its result (SHOP-R54, SHOP-R55)',
		function()
			local loaded, handles = shopCore()
			handles.Ledger:ReportCoinsEarned(3500)

			local bill = askToBuy(loaded, "core.crate")

			local shown = billShown(bill)
			assert.are.same({
				"Open a Curio crate?",
				"One look you don't own yet, by chance; the chances are on the crate.",
				"1,500",
				"2,000",
				true,
			}, { shown.question, shown.fine, shown.price[2], shown.left[2], shown.shown })
			assert.is_false(bill.useNow:IsShown())

			bill.buy:Click()

			local result = loaded.ns.walletSnapshot.crates[1]
			assert.is_true(type(result) == "string" or type(result) == "number")
			if type(result) == "string" then
				assert.is_true(loaded.env.Pagle.IsOwned(result)) -- bought at the click
			end
			play(loaded, 16) -- the crate opens over the case's inside first, and its reveal ends it
			assert.is_false(bill:IsShown())
			assert.are.equal("reveal", shopFrame(loaded).crate.phase)
			assert.is_true(shopFrame(loaded).crate.backButton:IsShown())

			-- The next bill for a good says what it always said, and has its box.
			shopFrame(loaded).crate.backButton:Click()
			handles.Ledger:ReportCoinsEarned(3800)
			local again = billShown(askToBuy(loaded, "core.toaststyle.ripple"))
			assert.are.same({ "Buy Ripple?", "Looks are yours for good." }, { again.question, again.fine })
			assert.is_true(shopFrame(loaded).bill.useNow:IsShown())
		end
	)
end)

describe("The Curio crate opening (SHOP-R55, wallet-and-shop.md › UI: Motion and sound)", function()
	local FOIL = "core.toaststyle.foil"
	-- The hash that has the draw roll each crate tier (SHOP-R51's thresholds, over 2^32): Curio, 1, 4, 5 and 6.
	local HASH = { curio = 4294967295, [1] = 0, [4] = 3600000000, [5] = 4100000000, [6] = 4200000000 }

	-- Core with 3,500 Coins and the next crate rigged. `spec.tier` is the crate tier it rolls (Curio by default); the pool
	-- is Prize Foil alone (Curio's), or, for another tier, Storm Front in that tier, so a tier with no good in the pool
	-- (`spec.payback`, tier 1 unless given) pays back instead. Every whole random number is the middle of its range (the
	-- reel's cards, the line's stop), the particles' and shake's fractions a fixed spread. The shop open on the crate's
	-- bill, dropped in. Returns the loaded addon and the bill.
	local function crate(spec)
		spec = spec or {}
		local loaded, handles = shopCore()
		if spec.motionOff then
			loaded.ns.db.profile.announcements.motion = false
		end
		handles.Ledger:ReportCoinsEarned(3500)
		local tier = spec.tier or (spec.payback and 1 or "curio")
		loaded.ns.SizeHash = function()
			return HASH[tier]
		end
		if tier == "curio" then
			loaded.ns.CRATE_POOL = { { id = FOIL, tier = "curio", kind = "toaststyle" } }
		else
			local good = spec.payback and "core.toaststyle.nothing" or "core.toaststyle.storm"
			loaded.ns.CRATE_POOL = { { id = good, tier = spec.payback and 3 or tier, kind = "toaststyle" } }
		end
		local drawn = 0
		loaded.ns.CrateRandom = function(n)
			if n then
				return math.ceil(n / 2)
			end
			drawn = drawn + 1
			return (drawn * 0.618034) % 1
		end
		local bill = askToBuy(loaded, "core.crate")
		play(loaded, 0.5)
		return loaded, bill
	end

	local function stageOf(loaded)
		return shopFrame(loaded).crate
	end

	-- Every crate sound played so far, by its file's name.
	local function crateSounds(loaded)
		local list = {}
		for _, sound in ipairs(loaded.client.sounds) do
			local name = sound:match("crate\\sounds\\([^\\]+)%.ogg SFX$")
			if name then
				list[#list + 1] = name
			end
		end
		return list
	end

	-- How many times `name` has played.
	local function played(loaded, name)
		local n = 0
		for _, sound in ipairs(crateSounds(loaded)) do
			n = n + (sound == name and 1 or 0)
		end
		return n
	end

	-- How many particles of the swarm `name` are in the air.
	local function airborne(loaded, name)
		local swarm = stageOf(loaded).swarms[name]
		local n = 0
		for _, part in ipairs(swarm and swarm.parts or {}) do
			n = n + (part.live and 1 or 0)
		end
		return n
	end

	-- The result of a crate that gave Prize Foil, as SHOP-R55 asks: the good bought and owned, selected on the stage
	-- and its row picked, the purse paid, the bill gone, and the reveal over the case's inside: the card turned over to
	-- the good, its words, "Use it now" and "Back to the shop".
	local function assertGoodResult(loaded)
		local frame = shopFrame(loaded)
		local stage = frame.crate
		assert.is_true(loaded.env.Pagle.IsOwned(FOIL))
		assert.is_false(frame.bill:IsShown())
		assert.are.equal("2,000", frame.purse.balance:GetText())
		assert.is_true(stage.root:IsShown())
		assert.are.equal("reveal", stage.phase)
		assert.are.same({ "CURIO", "Prize Foil", "TOAST STYLE" }, {
			stage.tier:GetText(),
			stage.name:GetText(),
			stage.kind:GetText(),
		})
		assert.are.same({ 1, 1, 1 }, { stage.tier:GetAlpha(), stage.name:GetAlpha(), stage.kind:GetAlpha() })
		assert.are.equal("YOURS", stage.stampWord:GetText())
		assert.are.same({ true, false }, { stage.front:IsShown(), stage.back:IsShown() })
		assert.are.same({ true, true }, { stage.useButton:IsShown(), stage.backButton:IsShown() })
		assert.are.same(
			{ "Use it now", "Back to the shop" },
			{ stage.useButton.label:GetText(), stage.backButton.label:GetText() }
		)
		assert.are.equal(1.5, stage.hero:GetScale())
		assert.is_false(stage.reel.clip:IsShown())
		assert.is_true(frame.catcher:IsShown())
		assert.is_nil(next(loaded.ns.announcementFrames or {})) -- no Announcement (SHOP-R55)
	end

	-- The result of a crate that paid `amount` back, as SHOP-R55 asks: the coin card turned over to "+<amount> Coins", the
	-- tier's name alone, "PAID BACK", the purse counted back to `balance`, and "Back to the shop" alone.
	local function assertPaybackResult(loaded, tierName, amount, balance)
		local frame = shopFrame(loaded)
		local stage = frame.crate
		assert.is_false(loaded.env.Pagle.IsOwned(FOIL))
		assert.is_true(stage.root:IsShown())
		assert.are.equal("reveal", stage.phase)
		assert.are.same(
			{ string.upper(tierName), "", "" },
			{ stage.tier:GetText(), stage.name:GetText(), stage.kind:GetText() }
		)
		assert.are.equal("PAID BACK", stage.stampWord:GetText())
		assert.are.same({ true, false }, { stage.front:IsShown(), stage.back:IsShown() })
		assert.are.equal("+" .. amount .. " Coins", stage.front.coins:GetText())
		assert.are.equal(1, stage.front.coins:GetAlpha())
		assert.are.same({ false, true }, { stage.useButton:IsShown(), stage.backButton:IsShown() })
		assert.are.equal("Back to the shop", stage.backButton.label:GetText())
		assert.are.equal(balance, frame.purse.balance:GetText())
	end

	-- A clock that plays the opening on to the second `t` from the click, returning the stage there.
	local function clockOf(loaded)
		local now = 0
		return function(t)
			play(loaded, t - now)
			now = t
			return stageOf(loaded)
		end
	end

	describe("builds", function()
		it(
			"the opening once over the case's inside, in the HIGH strata under the bill's DIALOG, with 60 pooled cards",
			function()
				local loaded, bill = crate()
				loaded.ns.CRATE_POOL = {
					{ id = FOIL, tier = "curio", kind = "toaststyle" },
					{ id = "core.toaststyle.storm", tier = "curio", kind = "toaststyle" },
				}
				local before = #loaded.client.frames
				bill.buy:Click()
				local frame = shopFrame(loaded)
				local stage = frame.crate

				assert.are.equal(frame, stage.root:GetParent())
				assert.are.same({ 22, -98 }, offset(stage.root))
				assert.are.same({ 936, 520 }, { stage.root:GetWidth(), stage.root:GetHeight() })
				assert.are.equal("HIGH", stage.root:GetFrameStrata())
				assert.are.equal("DIALOG", frame.bill:GetFrameStrata())
				assert.are.equal("DIALOG", frame.catcher:GetFrameStrata())
				assert.is_true(stage.root:GetFrameLevel() > frame.stage.area:GetFrameLevel())
				assert.is_true(stage.root:GetFrameLevel() > frame.scroll:GetFrameLevel())
				assert.is_true(stage.root.mouseEnabled) -- the tray and lid under it take no clicks
				assert.are.equal(60, #stage.reel.cards)
				for _, card in ipairs(stage.reel.cards) do
					assert.are.equal(stage.reel.track, card:GetParent())
				end
				assert.is_true(#loaded.client.frames - before >= 60)

				-- a second crate draws on the same frames: the cards, the swarms' textures, all of it
				play(loaded, 15)
				stage.onBack()
				local made = #loaded.client.frames
				askToBuy(loaded, "core.crate").buy:Click()
				play(loaded, 15)
				assert.are.equal(stage, shopFrame(loaded).crate)
				assert.are.equal(made, #loaded.client.frames, "no frame is made after the first opening")
				assert.is_true(loaded.env.Pagle.IsOwned("core.toaststyle.storm"))
			end
		)

		it("each part from the crate kit: tinted in the tier's colour, additive where the kit says", function()
			local loaded, bill = crate({ tier = 4 })
			bill.buy:Click()
			local stage = stageOf(loaded)

			local c = stage.reel.cards[53].tint.tex.vertexColor
			assert.are.same({ 0xb0, 0x5c, 0xff }, {
				math.floor(c[1] * 255 + 0.5),
				math.floor(c[2] * 255 + 0.5),
				math.floor(c[3] * 255 + 0.5),
			})
			assert.are.equal("ADD", stage.burst.tex.blendMode)
			assert.are.equal("ADD", stage.beam.tex.blendMode)
			assert.are.equal("ADD", stage.fans[2].tex.blendMode)
			assert.are.equal("Interface\\AddOns\\Pagle\\media\\crate\\Crate", stage.fans[2].tex.texture)
			assert.are.equal(0.26, stage.fans[2].alpha)
		end)

		it(
			"the reel's cards as SHOP-R51 draws them: a coin card in the tier's colour where a tier has nothing left",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local stage = stageOf(loaded)

				-- every roll is the middle: tier 2 for the other cards, which has no candidate in this pool
				assert.are.same({ tier = 2, face = "coin" }, stage.cards[1])
				assert.are.same({ tier = "curio", face = "curio" }, stage.cards[53])
				local win = stage.reel.cards[53]
				assert.are.same({ true, false }, { win.curio.tex:IsShown(), win.base.tex:IsShown() })
				local other = stage.reel.cards[1]
				assert.are.same(
					{ false, true, true },
					{ other.curio.tex:IsShown(), other.base.tex:IsShown(), other.emblem.tex:IsShown() }
				)
				assert.is_false(other.label:IsShown()) -- a coin card has no kind
				assert.are.equal(0x3e, math.floor(other.colour[1] * 255 + 0.5)) -- tier 2's green
			end
		)
	end)

	describe("plays the crate", function()
		it(
			"darkening the inside, the purse counting down, the crate dropping to land at 0.7 s and settling by 1.0 s",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local frame = shopFrame(loaded)
				local stage = stageOf(loaded)
				local at = clockOf(loaded)

				assert.is_true(stage.root:IsShown())
				assert.are.same({ true, "crate" }, { frame.catcher:IsShown(), stage.phase })
				assert.is_true(frame.catcher.mouseEnabled)
				assert.are.same({ "5274 SFX", "865 SFX" }, shopSounds(loaded))
				assert.are.equal(0, stage.dim[1]:GetAlpha())
				assert.are.equal("3,500", frame.purse.balance:GetText())

				at(0.2)
				assert.is_true(stage.dim[1]:GetAlpha() > 0.4 and stage.dim[1]:GetAlpha() < 1)
				assert.are.equal(0, stage.groupAlpha) -- the crate not yet in
				at(0.3)
				assert.are.equal(1, stage.groupAlpha)
				assert.is_true(stage.group.ty < -300) -- falling from 450 units up
				at(0.4)
				assert.are.equal(1, stage.dim[1]:GetAlpha()) -- darkened by 0.35 s
				assert.are.same({ "5274 SFX", "865 SFX", "120 SFX" }, shopSounds(loaded)) -- the purse, at 0.25 s
				assert.is_true(tonumber((frame.purse.balance:GetText():gsub(",", ""))) < 3500)
				assert.are.same({}, crateSounds(loaded))
				at(0.65)
				assert.are.same({}, crateSounds(loaded))
				assert.are.equal(0, airborne(loaded, "dust"))
				at(0.75)
				assert.are.same({ "crate_land" }, crateSounds(loaded))
				assert.are.equal(4, airborne(loaded, "dust")) -- a puff each side, two each
				assert.is_true(stage.group.sx > 1 and stage.group.sy < 1) -- squashed wide and low
				at(0.9)
				assert.is_true(stage.group.ty < 0) -- bouncing
				at(1.05)
				assert.are.same({ 0, 0, 1, 1 }, { stage.group.ty, stage.group.deg, stage.group.sx, stage.group.sy })
				at(1.3)
				assert.are.equal("2,000", frame.purse.balance:GetText()) -- counted down to 3,500 less 1,500 by 1.15 s
			end
		)

		it("dropping the plaque and the odds line in at 1.0 s", function()
			local loaded, bill = crate()
			bill.buy:Click()
			local stage = stageOf(loaded)
			local at = clockOf(loaded)

			at(0.95)
			assert.are.same({ 0, 0 }, { stage.plaque:GetAlpha(), stage.odds[1]:GetAlpha() })
			at(1.6)
			assert.are.same({ 1, 1 }, { stage.plaque:GetAlpha(), stage.odds[1]:GetAlpha() })
			local lines = {}
			for i, line in ipairs(stage.odds) do
				lines[i] = line:GetText()
			end
			assert.are.same(
				{ "Plain 40%", "Fine 26%", "Lively 16%", "Showpiece 10%", "Marvel 5%", "Heirloom 2.5%", "Curio 0.5%" },
				lines
			)
		end)

		it(
			"rattling three times at 1.25, 1.6 and 1.9 s, tipping 3°, 5° then 8°, the seal glowing warmer each time",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local stage = stageOf(loaded)
				-- The most the crate tips in each rattle, and the seal's glow just before the next.
				local tipped, glow = { 0, 0, 0 }, {}
				for step = 1, 44 do
					local now = step * 0.05
					play(loaded, 0.05)
					local window = now >= 1.3 and now < 1.5 and 1
						or now >= 1.65 and now < 1.85 and 2
						or now >= 1.95 and now < 2.15 and 3
					if window then
						tipped[window] = math.max(tipped[window], math.abs(stage.group.deg))
					end
					if step == 31 or step == 37 or step == 43 then
						glow[#glow + 1] = stage.crate.glow.tex:GetAlpha()
					end
				end

				assert.are.same({ 1, 1, 1 }, {
					played(loaded, "crate_knock_1"),
					played(loaded, "crate_knock_2"),
					played(loaded, "crate_knock_3"),
				})
				assert.are.same({ 3, 5, 8 }, loaded.ns.CRATE_TIMES.rattleTilt)
				assert.is_true(tipped[1] > 1 and tipped[1] <= 3)
				assert.is_true(tipped[2] > 2 and tipped[2] <= 5)
				assert.is_true(tipped[3] > 4 and tipped[3] <= 8)
				assert(glow[1] > 0 and glow[2] > glow[1] and glow[3] > glow[2], "warmer each time")
			end
		)
	end)

	describe("cracks it open and runs the reel", function()
		it(
			"cracking the seal at 2.2 s into two halves that spin away, dropping the ribbons, flying the lid off at 2.38 s",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local at = clockOf(loaded)
				local stage = at(2.15)
				local parts = stage.crate

				assert.are.same(
					{ 0, 0, 0 },
					{ played(loaded, "seal_crack"), played(loaded, "straps_snap"), played(loaded, "lid_whoosh") }
				)
				assert.are.same({ 0, 0, 0 }, { parts.sealLeft.own[1], parts.sealLeft.own[2], parts.sealLeft.own[3] })
				assert.are.equal(0, airborne(loaded, "straw"))

				at(2.45) -- 0.25 s into the crack, 0.07 s into the lid's flight
				assert.are.same(
					{ 1, 1, 1 },
					{ played(loaded, "seal_crack"), played(loaded, "straps_snap"), played(loaded, "lid_whoosh") }
				)
				assert(parts.sealLeft.own[1] < 0 and parts.sealLeft.own[3] < 0, "the left half goes left, turning back")
				assert(
					parts.sealRight.own[1] > 0 and parts.sealRight.own[3] > 0,
					"the right half goes right, turning on"
				)
				assert(parts.ribbon.own[2] > 0, "the ribbons drop")
				assert(parts.lid.own[2] < 0 and parts.lid.own[3] > 0, "the lid flies up, turning")
				assert.is_true(parts.lid.fade < 1 and parts.lid.fade > 0)
				assert(
					stage.burst.fade > 0 and stage.beam.fade > 0 and stage.fans[1].fade > 0,
					"light bursts, a beam rises, rays turn"
				)
				assert.are.equal(34, airborne(loaded, "straw"))

				at(3.35)
				assert.are.same({ 0, 0, 0 }, { parts.lid.fade, parts.sealLeft.fade, parts.ribbon.fade })
				assert(parts.lid.own[3] > 40 and parts.lid.own[3] <= 48, "the lid turned 48 degrees")
			end
		)

		it("opening the reel sideways out of the light from 2.9 s as the crate sinks, with its sound", function()
			local loaded, bill = crate()
			bill.buy:Click()
			local at = clockOf(loaded)

			local stage = at(2.85)
			assert.are.same(
				{ false, "crate", 0 },
				{ stage.reel.clip:IsShown(), stage.phase, played(loaded, "reel_open") }
			)
			at(3.05)
			assert.are.same(
				{ true, "reel", 1 },
				{ stage.reel.clip:IsShown(), stage.phase, played(loaded, "reel_open") }
			)
			assert(stage.reel.clip:GetWidth() < 912 and stage.reel.clip:GetHeight() < 237, "still opening")
			at(3.55)
			assert.are.same({ 912, 0 }, { math.floor(stage.reel.clip:GetWidth() + 0.5), stage.groupAlpha })
			assert.is_true(stage.beam.fade < 1e-6 and stage.burst.fade < 1e-6)
		end)

		it(
			"running the reel from 3.3 s to land at 9.7 s: eased, a tick and a dip for each card crossed, the light its colour",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local frame = shopFrame(loaded)
				local stage = stageOf(loaded)
				local bobber, ticks, lights = 0, {}, {}
				local start = 412.8 + loaded.ns.CrateReelTrackAt(4, 0)
				local last = start
				for step = 1, 190 do
					local clock = step * 0.05
					play(loaded, 0.05)
					if clock > 3.3 then
						assert(offset(stage.reel.track)[1] <= last + 1e-9, "the track only runs left")
						last = offset(stage.reel.track)[1]
						bobber = math.min(bobber, stage.reel.bobber.own[3])
						local c = stage.reel.light.tex.vertexColor
						lights[("%.2f,%.2f,%.2f"):format(c[1], c[2], c[3])] = true
					end
					if step == 66 then
						assert.are.equal(start, offset(stage.reel.track)[1], "still at the 4th card at 3.3 s")
					end
					if step == 100 then -- 5 s: 1.7 s into the run, most of the way gone
						local travelled = (start - offset(stage.reel.track)[1])
							/ (start - (412.8 + loaded.ns.CrateReelTrackAt(53, 0)))
						assert.is_near(loaded.ns.CrateReelEase(1.7 / 6.4), travelled, 0.03) -- to a frame
					end
				end

				assert.are.same({ "reel", 0 }, { stage.phase, played(loaded, "card_land") })
				local list = crateSounds(loaded)
				for _, name in ipairs(list) do
					ticks[#ticks + 1] = name:match("^card_tick_(%d)$")
				end
				assert(#ticks >= 30 and #ticks <= 49, "a tick for most of the 49 cards crossed: " .. #ticks)
				assert.are.same({ "1", "2", "3", "1", "2", "3" }, { unpack(ticks, 1, 6) })
				assert(bobber < -10, "the bobber dipped")
				assert.are.equal(0, stage.reel.bobber.own[3], "and came up")
				assert.is_true(next(lights) ~= nil)
				local final = 412.8 + loaded.ns.CrateReelTrackAt(53, stage.offset)

				play(loaded, 0.25) -- 9.75 s
				assert.are.same({ "landed", 1 }, { stage.phase, played(loaded, "card_land") })
				assert.are.equal(final, offset(stage.reel.track)[1])
				assert.are.equal(53, loaded.ns.CrateReelCardAt(final - 412.8))
				assert.are.equal(0, stage.offset)
				local c = stage.reel.light.tex.vertexColor
				assert.are.same({ 255, 208, 74 }, {
					math.floor(c[1] * 255 + 0.5),
					math.floor(c[2] * 255 + 0.5),
					math.floor(c[3] * 255 + 0.5),
				}) -- the 53rd card's, Curio's gold

				play(loaded, 0.4) -- 10.15 s: the others dimmed, the card ringed
				assert.is_near(0.22, stage.reel.cards[1]:GetAlpha(), 1e-6)
				assert.are.equal(1, stage.reel.cards[53]:GetAlpha())
				assert.is_true(stage.reel.cards[53].glow.tex:IsShown() and stage.reel.cards[53].glow.tex:GetAlpha() > 0)
				assert.is_false(stage.reel.cards[1].glow.tex:IsShown())
				assert.is_true(frame.catcher.mouseEnabled)
			end
		)

		it("stopping the line anywhere within 48 units of the 53rd card's middle, by chance", function()
			local loaded, bill = crate()
			loaded.ns.CrateRandom = function(n)
				return n and (n == 97 and 97 or 1) or 0.5
			end
			bill.buy:Click()

			assert.are.equal(48, stageOf(loaded).offset)
			play(loaded, 9.8)
			local final = offset(stageOf(loaded).reel.track)[1] - 412.8
			assert.are.equal(53, loaded.ns.CrateReelCardAt(final))
			assert.are.equal(loaded.ns.CrateReelTrackAt(53, 48), final)
		end)
	end)

	-- What the reveal ends on for a good of any crate tier: the good's name (and so on) on the stage over the inside, the
	-- tier's, the stamp, the buttons.
	local function assertGood(loaded, name, tierName, kindName, canUse)
		local stage = stageOf(loaded)
		assert.are.equal("reveal", stage.phase)
		assert.are.same({ string.upper(tierName), name, string.upper(kindName) }, {
			stage.tier:GetText(),
			stage.name:GetText(),
			stage.kind:GetText(),
		})
		assert.are.same({ 1, 1, 1 }, { stage.tier:GetAlpha(), stage.name:GetAlpha(), stage.kind:GetAlpha() })
		assert.are.equal("YOURS", stage.stampWord:GetText())
		assert.are.same({ 1, 0.92 }, { stage.stamp:GetScale(), stage.stamp:GetAlpha() })
		assert.are.same({ true, false }, { stage.front:IsShown(), stage.back:IsShown() })
		assert.are.same({ canUse, true }, { stage.useButton:IsShown(), stage.backButton:IsShown() })
		assert.are.equal(1, stage.backButton:GetAlpha())
	end

	-- The largest distance the stage's box has been shaken from where it sits.
	local function shaken(stage)
		local x, y = unpack(offset(stage.box))
		return math.max(math.abs(x), math.abs(y))
	end

	describe("reveals a good", function()
		it(
			"lifting the card to the middle at 1.5x as the reel drops and fades, the plaque and odds put away, from 10.35 s",
			function()
				local loaded, bill = crate({ tier = 1 })
				bill.buy:Click()
				local frame = shopFrame(loaded)
				local at = clockOf(loaded)

				local stage = at(10.3)
				assert.are.same({ false, "landed" }, { stage.hero:IsShown(), stage.phase })
				assert.is_true(frame.catcher.mouseEnabled)
				at(10.5) -- 0.15 s into the lift
				assert.are.equal("reveal", stage.phase)
				assert.is_false(frame.catcher.mouseEnabled) -- the buttons take the clicks now
				assert.is_true(stage.hero:IsShown() and stage.back:IsShown() and not stage.front:IsShown())
				assert.is_true(stage.hero:GetScale() > 1.1 and stage.hero:GetScale() < 1.7)
				assert(
					stage.heroAt[2] > 150 and stage.heroAt[2] < 258,
					"between the reel and the middle, past it a little"
				)
				at(11.1) -- 0.75 s in
				assert.are.same({ 1.5, 468, 168 }, { stage.hero:GetScale(), stage.heroAt[1], stage.heroAt[2] })
				assert.is_false(stage.reel.clip:IsShown())
				assert.are.same({ 0, 0 }, { stage.plaque:GetAlpha(), stage.odds[1]:GetAlpha() })
				assert.is_true(stage.halo.fade > 0.3)
			end
		)

		it(
			"waiting 0.76 s on a tier 1 good, turning half a turn, and turning to its face at 11.5 s with the tier's sting",
			function()
				local loaded, bill = crate({ tier = 1 })
				bill.buy:Click()
				local at = clockOf(loaded)
				local trembled = 0

				local stage = at(10.35)
				for t = 10.4, 11.05, 0.05 do
					at(t)
					trembled = math.max(trembled, math.abs(stage.tremble[1]) + math.abs(stage.tremble[2]))
				end
				assert.are.equal(0, trembled, "no tremble below tier 4")
				at(11.0)
				assert.are.same({ true, false }, { stage.back:IsShown(), stage.front:IsShown() })
				at(11.25) -- 0.14 s into the turn: squashed
				assert.is_true(stage.back.layers[1].tex:GetWidth() < stage.back.layers[1].w or stage.front:IsShown())
				assert.are.equal(0, played(loaded, "sting_1"))
				at(11.55)
				assert.are.same({ 1, 1 }, { played(loaded, "card_turn"), played(loaded, "sting_1") })
				assert.are.same({ true, false }, { stage.front:IsShown(), stage.back:IsShown() })
				at(11.7)
				assert.are.equal(
					1,
					stage.front.layers[1].tex:GetWidth() / stage.front.layers[1].w,
					"turned fully to the face"
				)
				assert.are.equal(0, airborne(loaded, "spark") + airborne(loaded, "ember") + airborne(loaded, "coin"))
				assert.is_nil(stage.embers)
				assert.are.equal(0, shaken(stage))
				assert.are.equal(0, stage.flash:GetAlpha())

				at(12.9) -- everything in: Storm Front, a tier 1 good here, is Core's and owned
				assertGood(loaded, STORM_NAME, "Plain", "Toast style", true)
				assert.are.equal(1, played(loaded, "stamp"))
			end
		)

		it(
			"trembling while it waits from tier 4 up, turning one and a half turns, with sparks as the face comes round",
			function()
				local loaded, bill = crate({ tier = 4 })
				bill.buy:Click()
				local at = clockOf(loaded)
				local stage = at(10.35)
				local trembled = 0
				for t = 11.1, 11.4, 0.05 do -- waits 1.09 s: from 11.05 s to 11.44 s
					at(t)
					trembled = math.max(trembled, math.abs(stage.tremble[1]) + math.abs(stage.tremble[2]))
				end
				assert(trembled > 0, "it trembles")
				at(12.1) -- the face at 10.35 + 1.09 + 0.72 = 12.16 s: two of the three half turns' sounds so far
				assert.are.same({ 2, 0 }, { played(loaded, "card_turn"), played(loaded, "sting_4") })
				assert.are.equal(0, airborne(loaded, "spark"))
				at(12.25)
				assert.are.same({ 3, 1 }, { played(loaded, "card_turn"), played(loaded, "sting_4") })
				assert.are.equal(56, airborne(loaded, "spark"))
				assert(stage.whip < 0 and stage.whip >= -150, "the rays whip back 60 and 30 more a tier above 1")
				assert.is_nil(stage.embers)
				assert.are.equal(0, shaken(stage))
				assert.are.equal(0, stage.flash:GetAlpha())
				at(14.5)
				assert.are.equal(0, stage.whip)
				assertGood(loaded, STORM_NAME, "Showpiece", "Toast style", true)
			end
		)

		it("rising embers for 5 s and shaking the case 4 units for 0.38 s at tier 5", function()
			local loaded, bill = crate({ tier = 5 })
			bill.buy:Click()
			local at = clockOf(loaded)
			local stage = at(12.3) -- the face at 10.35 + 1.2 + 0.72 = 12.27 s
			local most = 0
			for t = 12.3, 12.6, 0.05 do
				at(t)
				most = math.max(most, shaken(stage))
			end
			assert(most > 0 and most <= 4, "shaken, no more than 4 units: " .. most)
			assert.is_not_nil(stage.embers)
			assert.are.equal(68, airborne(loaded, "spark"))
			assert.are.equal(0, stage.flash:GetAlpha())
			at(13.5)
			assert.are.equal(0, shaken(stage), "the shake over by 0.38 s")
			assert.is_true(airborne(loaded, "ember") > 10)
			at(17.2) -- still rising 5 s after the face
			assert.is_true(airborne(loaded, "ember") > 10 and stage.embers.nextAt < stage.embers.endAt + 0.07)
			at(21) -- the last of them (sent up at 17.3 s, 2.2 to 3.4 s in the air) gone
			assert.are.equal(0, airborne(loaded, "ember"))
		end)

		it("flashing white and shaking 7 units for 0.6 s at tier 6", function()
			local loaded, bill = crate({ tier = 6 })
			bill.buy:Click()
			local at = clockOf(loaded)
			local stage = at(12.4) -- the face at 10.35 + 1.31 + 0.72 = 12.38 s
			assert.is_true(stage.flash:GetAlpha() > 0.4)
			local most = 0
			for t = 12.4, 12.9, 0.05 do
				at(t)
				most = math.max(most, shaken(stage))
			end
			assert(most > 4 and most <= 7, "shaken, no more than 7 units: " .. most)
			assert.are.equal(80, airborne(loaded, "spark"))
			at(13.1)
			assert.are.equal(0, stage.flash:GetAlpha())
		end)

		it(
			"waiting longest for Curio, turning two and a half turns, with a flash, a shake and a shower of coins",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local at = clockOf(loaded)
				local stage = at(11.0)
				local trembled = 0
				for t = 11.1, 11.7, 0.05 do -- waits 1.42 s, trembling
					at(t)
					trembled = math.max(trembled, math.abs(stage.tremble[1]) + math.abs(stage.tremble[2]))
				end
				assert.is_true(trembled > 0)
				at(13.0) -- the face at 10.35 + 1.42 + 1.2 = 12.97 s: four of the five half turns' sounds so far
				assert.are.same({ 4, 1 }, { played(loaded, "card_turn"), played(loaded, "sting_curio") })
				assert.is_true(stage.flash:GetAlpha() > 0.4)
				assert.are.equal(46, airborne(loaded, "coin"))
				assert.are.equal(70, airborne(loaded, "spark"))
				assert.is_not_nil(stage.embers)
				assert(stage.whip < -150, "the rays whip back 240 degrees")
				at(15.5)
				assertGood(loaded, "Prize Foil", "Curio", "Toast style", true)
			end
		)

		it(
			"coming in after the face: the tier's name at 0.2 s, the good's at 0.32 s, its kind at 0.45 s, the stamp at 0.65 s",
			function()
				local loaded, bill = crate({ tier = 1 })
				bill.buy:Click()
				local at = clockOf(loaded)
				local stage = at(11.55) -- the face at 11.49 s
				assert.are.same({ 0, 0, 0 }, { stage.tier:GetAlpha(), stage.name:GetAlpha(), stage.kind:GetAlpha() })
				-- (each beat starts on the first frame at or after its time, 0.05 s apart)
				at(11.8) -- the tier's name from 11.69 s
				assert.is_true(stage.tier:GetAlpha() > 0)
				assert.are.equal(0, stage.name:GetAlpha())
				at(11.9) -- the good's from 11.81 s
				assert.is_true(stage.name:GetAlpha() > 0)
				assert.are.equal(0, stage.kind:GetAlpha())
				at(12.05) -- its kind from 11.94 s
				assert.is_true(stage.kind:GetAlpha() > 0 and stage.kind:GetAlpha() <= 1)
				assert.are.same({ 0, 0 }, { stage.stamp:GetAlpha(), played(loaded, "stamp") })
				at(12.2) -- the stamp lands at 12.14 s, from 2.6x
				assert.is_true(stage.stamp:GetScale() > 1 and stage.stamp:GetScale() < 2.6)
				assert.is_true(stage.stamp:GetAlpha() > 0)
				assert.is_false(stage.backButton:IsShown())
				at(12.45) -- and its sound 0.18 s after
				assert.are.same({ 1, 1 }, { stage.stamp:GetScale(), played(loaded, "stamp") })
				at(12.5) -- the buttons from 12.44 s
				assert.is_true(stage.backButton:IsShown() and stage.useButton:IsShown())
				assert.is_true(stage.backButton:GetAlpha() < 1)
				at(13)
				assert.are.equal(1, stage.backButton:GetAlpha())
			end
		)
	end)

	describe("reveals a payback", function()
		-- The reveal of a payback, sampled every frame: nothing of any tier's fanfare ever shows.
		local function assertNoFanfare(loaded, from, to)
			local stage = stageOf(loaded)
			local at = clockOf(loaded)
			at(from)
			for t = from, to, 0.05 do
				at(t)
				assert.are.equal(0, airborne(loaded, "spark") + airborne(loaded, "ember"), "no sparks or embers")
				assert.is_nil(stage.embers)
				assert.are.equal(0, shaken(stage), "no shake")
				assert.are.equal(0, stage.flash:GetAlpha(), "no flash")
				assert.are.equal(0, stage.whip, "no whip")
				assert.are.equal(0, stage.tremble[1] + stage.tremble[2], "no tremble")
			end
		end

		it("lifting its coin card out, waiting 0.76 s with no tremble, turning once to '+250 Coins', tier 1", function()
			local loaded, bill = crate({ payback = true })
			bill.buy:Click()
			local stage = stageOf(loaded)

			assert.are.same({ tier = 1, face = "coin" }, stage.cards[53])
			assert.are.same({ 250 }, loaded.ns.walletSnapshot.crates)
			assertNoFanfare(loaded, 10.3, 13)
			assert.are.same(
				{ 1, 0, 1 },
				{ played(loaded, "card_turn"), played(loaded, "sting_1"), played(loaded, "payback") }
			)
			assert.is_nil(stage.swarms.spark) -- no sparks were ever made
		end)

		it("pouring 8 coins, counting the purse up by the Coins (0.9 s), PAID BACK, and the one button", function()
			local loaded, bill = crate({ payback = true })
			bill.buy:Click()
			local frame = shopFrame(loaded)
			local stage = stageOf(loaded)
			local at = clockOf(loaded)

			at(11.4) -- the face at 11.49 s: the purse at 2,000 after the price
			assert.are.equal("2,000", frame.purse.balance:GetText())
			at(11.55)
			assert.are.equal(8, airborne(loaded, "coin"))
			at(11.8)
			local mid = tonumber((frame.purse.balance:GetText():gsub(",", "")))
			assert(mid > 2000 and mid < 2250, "counting up: " .. mid)
			at(12.6)
			assertPaybackResult(loaded, "Plain", "250", "2,250")
			assert.are.equal(0.4, stage.fans[2].fade)
			local c = stage.fans[2].tex.vertexColor
			assert.are.equal(0xe9, math.floor(c[1] * 255 + 0.5)) -- the rays still take the tier's colour
		end)

		it("a Heirloom payback has none of tier 6's fanfare either, but its rays are full", function()
			local loaded, bill = crate({ tier = 6, payback = true })
			bill.buy:Click()
			local stage = stageOf(loaded)

			assert.are.same({ 1500 }, loaded.ns.walletSnapshot.crates)
			assertNoFanfare(loaded, 10.3, 13)
			assert.are.same(
				{ 1, 0, 1 },
				{ played(loaded, "card_turn"), played(loaded, "sting_6"), played(loaded, "payback") }
			)
			play(loaded, 0.5)
			assertPaybackResult(loaded, "Heirloom", "1,500", "3,500")
			assert.are.equal(1, stage.fans[2].fade)
		end)
	end)

	describe("ends on its buttons", function()
		it('"Use it now" puts the good in use and closes the opening onto the shop with it selected', function()
			local loaded, bill = crate()
			bill.buy:Click()
			play(loaded, 15)

			stageOf(loaded).useButton:Click()

			local frame = shopFrame(loaded)
			assert.are.same({ false, false }, { frame.crate.root:IsShown(), frame.catcher:IsShown() })
			assert.is_true(frame:IsShown())
			assert.are.equal(FOIL, loaded.env.Pagle.GetEquipped("core.toaststyle"))
			assert.are.equal("Prize Foil", frame.stage.name:GetText())
			assert.are.equal("IN USE", frame.stage.tags:GetText())
			assert.are.equal("IN USE", rowOf(loaded, FOIL).tag:GetText())
			assert.is_true(rowOf(loaded, FOIL).selectedMark:IsShown())
			assert(not frame.crateLine:IsShown(), "Prize Foil was the pool's last good: the crate has left the list")
		end)

		it('"Back to the shop" leaves the good owned and selected, not in use', function()
			local loaded, bill = crate()
			bill.buy:Click()
			play(loaded, 15)

			stageOf(loaded).backButton:Click()

			local frame = shopFrame(loaded)
			assert.are.same({ false, false }, { frame.crate.root:IsShown(), frame.catcher:IsShown() })
			assert.are_not.equal(FOIL, loaded.env.Pagle.GetEquipped("core.toaststyle"))
			assert.are.equal("Prize Foil", frame.stage.name:GetText())
			assert.are.equal("OWNED", frame.stage.tags:GetText())
			assert.is_true(frame.stage.use:IsShown())
			assert.is_true(rowOf(loaded, FOIL).selectedMark:IsShown())
		end)

		it(
			'a payback\'s "Back to the shop" leaves the crate selected, the purse counted back, the pool untouched',
			function()
				local loaded, bill = crate({ payback = true })
				bill.buy:Click()
				play(loaded, 15)
				assertPaybackResult(loaded, "Plain", "250", "2,250")

				stageOf(loaded).backButton:Click()

				local frame = shopFrame(loaded)
				assert.are.same({ false, false }, { frame.crate.root:IsShown(), frame.catcher:IsShown() })
				assert.are.equal("Curio crate", frame.stage.name:GetText(), "the crate stays selected")
				assert.is_true(frame.crateLine.selectedMark:IsShown())
				assert.are.equal("2,250", frame.purse.balance:GetText())
			end
		)

		it(
			"a good with no cache entry turns over to its kind's emblem as 'A new look', with its line, and leaves the crate selected",
			function()
				local loaded, handles = shopCore()
				handles.Ledger:ReportCoinsEarned(3500)
				loaded.ns.SizeHash = function()
					return 0
				end
				loaded.ns.CRATE_POOL = { { id = "stats.trackerframe.greenbar", tier = 1, kind = "trackerframe" } }

				askToBuy(loaded, "core.crate").buy:Click()
				play(loaded, 15)

				local stage = stageOf(loaded)
				assert.are.same(
					{ "PLAIN", "A new look", "TRACKER FRAME" },
					{ stage.tier:GetText(), stage.name:GetText(), stage.kind:GetText() }
				)
				assert.are.same(
					{ true, "It shows here once its Module is on." },
					{ stage.note:IsShown(), stage.note:GetText() }
				)
				assert.are.same(
					{ true, false, false },
					{ stage.front.emblem.tex:IsShown(), stage.front.icon.tex:IsShown(), stage.front.ring.tex:IsShown() }
				)
				assert.are.same({ false, true }, { stage.useButton:IsShown(), stage.backButton:IsShown() })

				stage.backButton:Click()

				local frame = shopFrame(loaded)
				assert(not frame.crateLine:IsShown(), "the pool is empty: the crate has left")
				assert.are.equal("Torn Page", frame.stage.name:GetText())
				assert.is_true(loaded.env.Pagle.IsOwned("stats.trackerframe.greenbar"))
			end
		)

		it("a good's own picture in its medallion on the card, a crest's as its shield", function()
			local loaded, bill = crate()
			bill.buy:Click()
			play(loaded, 15)

			local front = stageOf(loaded).front
			assert.are.same({ true, true, true, false }, {
				front.icon.tex:IsShown(),
				front.ring.tex:IsShown(),
				front.gloss.tex:IsShown(),
				front.shield.tex:IsShown(),
			})
			assert.are.equal(loaded.ns.goods:Good(FOIL).icon, front.icon.tex.texture)
			assert.is_true(front.glyph.tex:IsShown()) -- the kind's glyph in the corner
		end)
	end)

	describe("skips and settles", function()
		-- A click anywhere on the case, as the catcher takes it.
		local function click(loaded)
			local catcher = shopFrame(loaded).catcher
			catcher.scripts.OnMouseDown(catcher, "LeftButton")
		end

		it(
			"on a click anywhere during the crate: straight to the reveal, the crate and its light gone, the reveal playing on",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				local frame = shopFrame(loaded)
				local at = clockOf(loaded)
				local stage = at(1.0)
				assert.are.equal(1, played(loaded, "crate_land"))

				click(loaded)

				assert.are.equal("reveal", stage.phase)
				assert.is_false(frame.catcher.mouseEnabled)
				assert.are.same({ 0, 0, 0 }, { stage.groupAlpha, stage.plaque:GetAlpha(), airborne(loaded, "dust") })
				assert.is_true(stage.reel.clip:IsShown())
				assert.are.equal(1, stage.dim[1]:GetAlpha())
				assert.are.equal("2,000", frame.purse.balance:GetText())
				assert.are.same(
					{ 468 - stage.offset, 257.7 },
					{ stage.heroAt[1], math.floor(stage.heroAt[2] * 10 + 0.5) / 10 }
				)
				assert.are.equal(
					loaded.ns.CrateReelCardAt(offset(stage.reel.track)[1] - 412.8),
					53,
					"the line at its stop"
				)
				assert.is_true(stage.hero:IsShown())

				play(loaded, 15)
				assertGoodResult(loaded)
				-- only the reveal's sounds followed: no rattle, crack, lid, reel or tick
				assert.are.same({ 0, 0, 0, 0, 0 }, {
					played(loaded, "crate_knock_1"),
					played(loaded, "seal_crack"),
					played(loaded, "lid_whoosh"),
					played(loaded, "reel_open"),
					played(loaded, "card_land"),
				})
				assert.are.same(
					{ 5, 1, 1 },
					{ played(loaded, "card_turn"), played(loaded, "sting_curio"), played(loaded, "stamp") }
				)
			end
		)

		it("on Esc during the reel, which leaves the shop open, and a click in the reveal does nothing", function()
			local loaded, bill = crate()
			bill.buy:Click()
			local at = clockOf(loaded)
			local stage = at(6)
			assert.are.equal("reel", stage.phase)

			loaded.client.pressKey("ESCAPE")

			assert.is_true(shopFrame(loaded):IsShown())
			assert.are.equal("reveal", stage.phase)
			assert.are.equal(53, loaded.ns.CrateReelCardAt(offset(stage.reel.track)[1] - 412.8))
			local sounds = #loaded.client.sounds
			click(loaded) -- the catcher takes no click in the reveal (and would do nothing)
			assert.are.equal("reveal", stage.phase)
			assert.is_true(stage.root:IsShown())

			play(loaded, 15)
			assertGoodResult(loaded)
			assert.are_not.equal(sounds, #loaded.client.sounds)
		end)

		it("as the line lands too: a click between 9.7 s and the reveal goes to it", function()
			local loaded, bill = crate()
			bill.buy:Click()
			local at = clockOf(loaded)
			local stage = at(9.9)
			assert.are.equal("landed", stage.phase)

			click(loaded)

			assert.are.equal("reveal", stage.phase)
			play(loaded, 15)
			assertGoodResult(loaded)
		end)

		it("on Esc in the reveal: Back to the shop, closing the opening onto the good, even mid-turn", function()
			local loaded, bill = crate()
			bill.buy:Click()
			local frame = shopFrame(loaded)
			local at = clockOf(loaded)
			at(12.2)
			assert.are.equal("reveal", stageOf(loaded).phase)

			loaded.client.pressKey("ESCAPE")

			assert.is_true(frame:IsShown())
			assert.are.same({ false, false }, { frame.crate.root:IsShown(), frame.catcher:IsShown() })
			assert.are.equal("Prize Foil", frame.stage.name:GetText())
			assert.are.equal("2,000", frame.purse.balance:GetText())
			assert.are_not.equal(FOIL, loaded.env.Pagle.GetEquipped("core.toaststyle"))
			local sounds = #loaded.client.sounds
			play(loaded, 15)
			assert.are.equal(sounds, #loaded.client.sounds, "nothing sounds after")
			assert.is_true(frame:IsShown())
		end)

		it("on Esc on the settled reveal: Back to the shop, and with the opening gone Esc closes the shop", function()
			local loaded, bill = crate()
			bill.buy:Click()
			play(loaded, 15)
			assertGoodResult(loaded)

			loaded.client.pressKey("ESCAPE")

			assert.is_true(shopFrame(loaded):IsShown())
			assert.is_false(shopFrame(loaded).crate.root:IsShown())
			assert.are.equal("Prize Foil", shopFrame(loaded).stage.name:GetText())
		end)

		it("lets every other key go on to the game while the opening plays", function()
			local loaded, bill = crate()
			bill.buy:Click()
			local catcher = shopFrame(loaded).catcher
			play(loaded, 2)

			catcher.scripts.OnKeyDown(catcher, "SPACE")

			assert.is_true(catcher.propagatesKeys)
			assert.are.equal("crate", stageOf(loaded).phase)
			catcher.scripts.OnKeyDown(catcher, "ESCAPE")
			assert.is_false(catcher.propagatesKeys)
			assert.are.equal("reveal", stageOf(loaded).phase)
		end)

		it(
			"at once on any redraw of the window meanwhile: the reveal as it ends, with its buttons, and nothing plays after",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				play(loaded, 5)

				loaded.env.Pagle.OpenShop() -- a redraw

				assertGoodResult(loaded)
				local sounds = #loaded.client.sounds
				play(loaded, 15)
				assertGoodResult(loaded)
				assert.are.equal(sounds, #loaded.client.sounds)
			end
		)

		it("at once on a payback too, the purse at its balance", function()
			local loaded, bill = crate({ payback = true })
			bill.buy:Click()
			play(loaded, 5)

			loaded.env.Pagle.OpenShop()

			assertPaybackResult(loaded, "Plain", "250", "2,250")
			assert.are.equal(0, airborne(loaded, "coin"))
		end)

		it(
			"at once when the shop closes on it: nothing moves after, no frame is left shown, and it opens again on the good",
			function()
				local loaded, bill = crate()
				bill.buy:Click()
				play(loaded, 6)
				local stage = stageOf(loaded)
				local made = #loaded.client.frames

				shopFrame(loaded).CloseButton:Click()

				assert.are.same({ false, false }, { stage.root:IsShown(), shopFrame(loaded).catcher:IsShown() })
				assert.are.equal(0, airborne(loaded, "dust") + airborne(loaded, "straw"))
				local sounds = loaded.client.sounds
				local heard = #sounds
				play(loaded, 15)
				assert.are.equal(heard, #loaded.client.sounds, "no beat after it closed")
				assert.are.equal(made, #loaded.client.frames, "no frame is leaked")
				loaded.env.Pagle.OpenShop()
				assert.is_false(stage.root:IsShown())
				assert.are.equal("Prize Foil", shopFrame(loaded).stage.name:GetText())
			end
		)
	end)

	describe("with Animations off", function()
		it("shows the good's reveal at once, with the same buttons and only Buy's sound (SET-R30)", function()
			local loaded, bill = crate({ motionOff = true })

			bill.buy:Click()

			assertGoodResult(loaded)
			assert.are.same({ "5274 SFX", "865 SFX" }, shopSounds(loaded))
			assert.are.same({}, crateSounds(loaded))
		end)

		it("shows a payback's reveal at once, the purse already at 2,250", function()
			local loaded, bill = crate({ payback = true, motionOff = true })

			bill.buy:Click()

			assertPaybackResult(loaded, "Plain", "250", "2,250")
			assert.are.same({ "5274 SFX", "865 SFX" }, shopSounds(loaded))
			assert.are.same({}, crateSounds(loaded))
		end)

		it("takes Esc on it as Back to the shop", function()
			local loaded, bill = crate({ motionOff = true })
			bill.buy:Click()

			loaded.client.pressKey("ESCAPE")

			assert.is_true(shopFrame(loaded):IsShown())
			assert.is_false(shopFrame(loaded).crate.root:IsShown())
			assert.are.equal("Prize Foil", shopFrame(loaded).stage.name:GetText())
		end)

		it("plays no sound with the setting turned off in mid-opening", function()
			local loaded, bill = crate()
			bill.buy:Click()
			play(loaded, 1)
			loaded.ns.db.profile.announcements.motion = false

			loaded.env.Pagle.OpenShop()

			assertGoodResult(loaded)
			local heard = #crateSounds(loaded)
			play(loaded, 15)
			assert.are.equal(heard, #crateSounds(loaded))
		end)
	end)
end)
