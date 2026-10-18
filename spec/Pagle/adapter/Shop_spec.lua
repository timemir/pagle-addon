-- The Curio Shop window and its entry points, as Core runs it through the real TOC (wallet-and-shop.md › Entry points,
-- › UI; SHOP-R35, SHOP-R40, SHOP-R41, SHOP-R93; CORE-R33, CORE-R50, CORE-R61). The window is the shop art kit's
-- sample case: its words in the kit's fonts, capitals where the kit sets them so.

local COIN = " |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local AFTER_COMBAT = "Pagle: the Curio Shop opens after combat."
-- Where the shop's textures are.
local SHOP_ART = "Interface\\AddOns\\Pagle\\media\\shop\\"

-- Core's own slots (SHOP-R25) as the list shows them while nothing of Core's is bought and the balance is under 150,
-- each good named by its ID until its lore lands.
local CORE_UNBOUGHT = {
	"TOAST STYLE 1 of 3",
	"Torn Page | IN USE",
	"Ripple | 150",
	"Lantern Glow | 400",
	"SOUND SET 1 of 2",
	"Driftwood | IN USE",
	"Gilded | 400",
	"BOOKPLATE CREST 1 of 4",
	"Plain | IN USE",
	"Rod and Line | 150",
	"Pearl | 400",
	"Water Spirit | 900",
}

-- Core with the Ledger and Hunts registered, Core's own goods, Hunts' covers and the Ledger's bindings, logged in and
-- in the world. `saved` is a PagleDB; `options.noHunts` leaves Hunts unregistered (off); `options.preview` is
-- Velvet's preview; `options.entries` is the saved log's entries. Returns the loaded addon and the handles.
local function shopCore(saved, options)
	options = options or {}
	local loaded = loadCore(options.entries, saved)
	local Pagle = loaded.env.Pagle
	local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Fish Journal" })
	ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
	ledger:RegisterGood({ id = "ledger.binding.lapis", slot = "ledger.binding", name = "Lapis", tier = 3 })
	local hunts
	if not options.noHunts then
		hunts = Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
		hunts:RegisterSlot({ id = "hunts.cover", label = "Notebook cover", category = "Hunts" })
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

-- The list as shown: each group header as "<label> <count or note>", each row as "<name> | <tag or price>".
local function listed(loaded)
	local lines = {}
	for _, line in ipairs(shopFrame(loaded).lines) do
		if line:IsShown() then
			if line.header then
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

	it("narrows with the search slip (wallet-and-shop.md › UI)", function()
		local loaded = shopCore()
		loaded.env.Pagle.OpenShop()
		local search = shopFrame(loaded).search
		assert.are.equal("Find a look…", search.Instructions:GetText())

		search:Type("RIP")

		assert.is_false(search.Instructions:IsShown())
		assert.are.same({ "TOAST STYLE 1 of 3", "Ripple | 150" }, listed(loaded))
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
		assert.are.same({
			"TOAST STYLE 1 of 3",
			"Ripple | 150",
			"Lantern Glow | 400",
			"SOUND SET 1 of 2",
			"Gilded | 400",
			"BOOKPLATE CREST 1 of 4",
			"Rod and Line | 150",
			"Pearl | 400",
			"NOTEBOOK COVER 1 of 2",
			"Velvet | 400",
		}, listed(loaded))
		assert.is_true(filters.canAfford.pressed)
		assert.are.equal("PagleShopPillOn", filters.canAfford.label.fontObject)
		assert.is_false(filters.all.pressed)
		assert.are.equal("PagleShopPill", filters.all.label.fontObject)
		filters.owned:Click()
		assert.are.same({
			"TOAST STYLE 1 of 3",
			"Torn Page | IN USE",
			"SOUND SET 1 of 2",
			"Driftwood | IN USE",
			"BOOKPLATE CREST 1 of 4",
			"Plain | IN USE",
			"JOURNAL BINDING 1 of 2",
			"Oak | IN USE",
			"NOTEBOOK COVER 1 of 2",
			"Plain | IN USE",
		}, listed(loaded))
		filters.notOwned:Click()
		assert.are.equal(13, #listed(loaded))
		filters.all:Click()
		assert.are.equal(18, #listed(loaded))
	end)

	it(
		"shows a chip for each category a slot uses, in order, and narrows to one (wallet-and-shop.md › UI)",
		function()
			local loaded = shopCore()
			loaded.env.Pagle.OpenShop()
			local frame = shopFrame(loaded)

			assert.are.same({ "ALL", "ANNOUNCEMENTS", "BOOKPLATE", "FISH JOURNAL", "HUNTS" }, pillLabels(frame.chips))
			assert.is_true(frame.chips[1].pressed)

			frame.chips[4]:Click()
			assert.are.same({ "JOURNAL BINDING 1 of 2", "Oak | IN USE", "Lapis | 900" }, listed(loaded))
			assert.is_true(frame.chips[4].pressed)
			assert.is_false(frame.chips[1].pressed)
			frame.chips[1]:Click()
			assert.are.equal(18, #listed(loaded))
		end
	)

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
		scroll:GetScript("OnMouseWheel")(scroll, -1)
		assert.are.same({ 66, 66 }, { scroll:GetVerticalScroll(), bar:GetValue() })
		bar:SetValue(200)
		assert.are.equal(200, scroll:GetVerticalScroll())
		scroll:GetScript("OnMouseWheel")(scroll, -1)
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
				{ "TOAST STYLE 2 of 3", "Torn Page | default", "Ripple | IN USE" },
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
		ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Fish Journal" })
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
		icon = bill.bezel.Icon.texture,
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
		handles.Ledger:ReportCoinsEarned(300)
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
		askToBuy(loaded, "core.crest.crest1")
		assert.are.same({ "Use it now", true, true }, billShown(bill).useNow)
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
			entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1000, "core.crest.crest3", 900)
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
		entries[#entries + 1] = purchaseEntry(SERVER_TIME - 1000, "core.crest.crest3", 900)
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
				{ "TOAST STYLE 2 of 3", "Torn Page | default", "Ripple | IN USE" },
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
