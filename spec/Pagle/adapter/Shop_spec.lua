-- The Curio Shop window and its entry points, as Core runs it through the real TOC (wallet-and-shop.md › Entry points,
-- › UI; SHOP-R35, SHOP-R40, SHOP-R41, SHOP-R93; CORE-R33, CORE-R50, CORE-R61).

local COIN = " |TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local AFTER_COMBAT = "Pagle: the Curio Shop opens after combat."

-- Core's own slots (SHOP-R25) as the list shows them while nothing of Core's is bought and the balance is under 150,
-- each good named by its ID until its lore lands.
local CORE_UNBOUGHT = {
	"Toast style 1/3",
	"core.toaststyle.timber | In use",
	"core.toaststyle.ripple | 150" .. COIN,
	"core.toaststyle.lanternglow | 400" .. COIN,
	"Sound set 1/2",
	"core.soundset.driftwood | In use",
	"core.soundset.gilded | 400" .. COIN,
	"Bookplate crest 1/4",
	"core.crest.plain | In use",
	"core.crest.crest1 | 150" .. COIN,
	"core.crest.crest2 | 400" .. COIN,
	"core.crest.crest3 | 900" .. COIN,
}

-- Core with the Ledger and Hunts registered, Core's own goods, Hunts' covers and the Ledger's bindings, logged in and
-- in the world. `saved` is a PagleDB; `options.noHunts` leaves Hunts unregistered (off); `options.preview` is
-- Velvet's preview. Returns the loaded addon and the handles.
local function shopSession(saved, options)
	options = options or {}
	local loaded = loadCore(nil, saved)
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
local function shop(loaded)
	return loaded.ns.shopFrame
end

-- The list as shown: each group header as "<label> <count or note>", each row as "<name> | <tag or price>".
local function listed(loaded)
	local lines = {}
	for _, line in ipairs(shop(loaded).lines) do
		if line:IsShown() then
			if line.header then
				lines[#lines + 1] = ("%s %s"):format(line.label:GetText(), line.count:GetText())
			else
				lines[#lines + 1] = ("%s | %s"):format(line.label:GetText(), line.tag:GetText())
			end
		end
	end
	return lines
end

-- The row showing `goodID`.
local function rowOf(loaded, goodID)
	for _, line in ipairs(shop(loaded).lines) do
		if line:IsShown() and line.goodID == goodID then
			return line
		end
	end
	error("no row for " .. goodID)
end

-- Presses Esc as the client does: the focused edit box takes it first; with none focused, CloseSpecialWindows hides
-- every shown frame named in UISpecialFrames.
local function escape(loaded)
	local focus = loaded.client.focus
	local onEscape = focus and focus:GetScript("OnEscapePressed")
	if onEscape then
		onEscape(focus)
		return
	end
	local frame = shop(loaded)
	for _, name in ipairs(loaded.env.UISpecialFrames) do
		if frame and name == frame.name and frame:IsShown() then
			frame:Hide()
			local onHide = frame:GetScript("OnHide")
			if onHide then
				onHide(frame)
			end
		end
	end
end

-- Clicks Pagle in the Addon Compartment and returns the menu Core opens on the next frame.
local function compartmentMenu(loaded)
	local opened = #loaded.client.menus
	loaded.client.clickCompartment("Pagle")
	loaded.client.runTimers()
	return assert(loaded.client.menus[opened + 1])
end

describe("The Curio Shop's entry points", function()
	it("opens with Pagle.OpenShop(), titled Curio Shop (SHOP-R40)", function()
		local loaded = shopSession()

		loaded.env.Pagle.OpenShop()

		local frame = assert(shop(loaded))
		assert.is_true(frame:IsShown())
		assert.are.equal("Curio Shop", frame.title)
		assert.are.same({}, loaded.printed)
	end)

	it("toggles with /pagle shop, matched case-insensitively (CORE-R61, SHOP-R40)", function()
		local loaded = shopSession()
		local slash = loaded.env.SlashCmdList.PAGLE

		slash("shop")
		assert.is_true(shop(loaded):IsShown())
		slash(" SHOP ")
		assert.is_false(shop(loaded):IsShown())
		slash("shop")
		assert.is_true(shop(loaded):IsShown())
		assert.are.same({}, loaded.printed)
	end)

	it("opens from the compartment menu's Curio Shop entry, which shows the balance (CORE-R50, SHOP-R40)", function()
		local loaded, handles = shopSession()
		handles.Ledger:ReportCoinsEarned(1950)

		compartmentMenu(loaded).click("Curio Shop  1,950" .. COIN)

		assert.is_true(shop(loaded):IsShown())
	end)

	it("closes with Esc, from the search box or with nothing focused, and with its close button (SHOP-R40)", function()
		local loaded = shopSession()
		local Pagle = loaded.env.Pagle

		Pagle.OpenShop()
		assert.is_true(loaded.ns.shopFrame.name ~= nil)
		escape(loaded)
		assert.is_false(shop(loaded):IsShown())

		Pagle.OpenShop()
		shop(loaded).search:SetFocus()
		escape(loaded)
		assert.is_false(shop(loaded):IsShown())
		assert.is_nil(loaded.client.focus) -- a closed shop keeps no keyboard focus

		Pagle.OpenShop()
		shop(loaded).CloseButton:Click()
		assert.is_false(shop(loaded):IsShown())
	end)

	it("never opens on its own (SHOP-R40)", function()
		local loaded, handles = shopSession()
		handles.Ledger:ReportCoinsEarned(500)
		setCombat(loaded, true)
		setCombat(loaded, false)

		assert.is_nil(shop(loaded))
	end)
end)

describe("Pagle.OpenShop(goodID)", function()
	it("selects that good on the stage (SHOP-R40)", function()
		local loaded = shopSession()

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")

		local frame = shop(loaded)
		assert.are.equal("Velvet", frame.stage.name:GetText())
		assert.are.equal("Notebook cover · Hunts", frame.stage.slotLine:GetText())
		assert.is_true(rowOf(loaded, "hunts.cover.velvet").selectedMark:IsShown())
		assert.is_false(rowOf(loaded, "hunts.cover.plain").selectedMark:IsShown())
	end)

	it("selects nothing for an unknown ID, the stage asking for a pick (SHOP-R40)", function()
		local loaded = shopSession()
		local Pagle = loaded.env.Pagle
		Pagle.OpenShop("hunts.cover.velvet")

		Pagle.OpenShop("hunts.cover.none")

		local stage = shop(loaded).stage
		assert.is_true(stage.hint:IsShown())
		assert.are.equal("Pick a look to see it here.", stage.hint:GetText())
		assert.is_false(stage.name:IsShown())
		assert.is_false(stage.buy:IsShown())
		assert.is_false(stage.use:IsShown())
	end)

	it("keeps the selection when opened again with no ID (SHOP-R40)", function()
		local loaded = shopSession()
		local Pagle = loaded.env.Pagle
		Pagle.OpenShop("ledger.binding.lapis")
		shop(loaded).CloseButton:Click()

		Pagle.OpenShop()

		assert.are.equal("Lapis", shop(loaded).stage.name:GetText())
	end)

	it("clears the search, the filter and the chip so the good's row shows (SHOP-R40)", function()
		local loaded = shopSession()
		local Pagle = loaded.env.Pagle
		Pagle.OpenShop()
		local frame = shop(loaded)
		frame.search:Type("oak")
		frame.filters.owned:Click()

		Pagle.OpenShop("hunts.cover.velvet")

		assert.are.equal("", frame.search:GetText())
		assert.is_true(frame.filters.all.highlightLocked)
		assert.is_true(rowOf(loaded, "hunts.cover.velvet").selectedMark:IsShown())
	end)

	it(
		"selects an owned good of a Module off under Put away, greyed, with its cached icon (SHOP-R40, SHOP-R35)",
		function()
			local first = shopSession()
			first.ns.goods:SetPurchased({ ["hunts.cover.velvet"] = true })
			-- The next session, with Hunts off: its goods are in PagleDB's cache.
			local loaded = shopSession(first.env.PagleDB, { noHunts = true })
			loaded.ns.goods:SetPurchased({ ["hunts.cover.velvet"] = true })

			loaded.env.Pagle.OpenShop("hunts.cover.velvet")

			local frame = shop(loaded)
			local stage = frame.stage
			assert.are.equal("Velvet", stage.name:GetText())
			assert.are.equal("Hunts is off", stage.tags:GetText())
			assert.are.equal("Yours to keep", stage.notes:GetText())
			assert.are.equal(134939, stage.swatch.texture)
			assert.is_true(stage.swatch:IsShown())
			assert.is_false(stage.use:IsShown())
			local lines = listed(loaded)
			assert.are.same(
				{ "Put away: Module off Yours to keep", "Velvet | Hunts is off" },
				{ lines[#lines - 1], lines[#lines] }
			)
			assert.are.equal(0.55, rowOf(loaded, "hunts.cover.velvet"):GetAlpha())

			loaded.env.Pagle.OpenShop("hunts.cover.plain")
			assert.is_true(stage.hint:IsShown()) -- a Module off's default isn't listed
		end
	)
end)

describe("The Curio Shop while restricted", function()
	it("prints SHOP-R41's line from every entry point and opens nothing (SHOP-R41, CORE-R33, SHOP-R93)", function()
		local loaded = shopSession()
		setCombat(loaded, true)

		loaded.env.Pagle.OpenShop()
		loaded.env.SlashCmdList.PAGLE("shop")
		compartmentMenu(loaded).click("Curio Shop  0" .. COIN)

		assert.is_nil(shop(loaded))
		assert.are.same({ AFTER_COMBAT, AFTER_COMBAT, AFTER_COMBAT }, loaded.printed)
	end)

	it("closes when combat starts, and doesn't reopen after (SHOP-R41, CORE-R33)", function()
		local loaded = shopSession()
		loaded.env.Pagle.OpenShop()

		setCombat(loaded, true)
		assert.is_false(shop(loaded):IsShown())
		setCombat(loaded, false)

		assert.is_false(shop(loaded):IsShown())
		assert.are.same({}, loaded.printed)
	end)
end)

describe("The Curio Shop's purse", function()
	it(
		"shows the balance, one segment per Module that reported, its total in the legend and tooltip, and who pays"
			.. " none (wallet-and-shop.md › UI)",
		function()
			local loaded, handles = shopSession()
			handles.Ledger:ReportCoinsEarned(1500)
			handles.Hunts:ReportCoinsEarned(500)
			loaded.env.Pagle.OpenShop()

			local purse = shop(loaded).purse
			assert.are.equal("2,000", purse.balance:GetText())
			assert.are.equal("Pagle Coins", purse.label:GetText())
			assert.are.equal("Stats and QoL pay none", purse.payNone:GetText())
			local shown = {}
			for _, segment in ipairs(purse.segments) do
				if segment:IsShown() then
					shown[#shown + 1] =
						{ segment.legend:GetText(), segment.share, segment:GetAlpha(), segment.strike:IsShown() }
				end
			end
			assert.are.same({ { "Ledger 1,500", 0.75, 1, false }, { "Hunts 500", 0.25, 1, false } }, shown)

			purse.segments[1]:GetScript("OnEnter")(purse.segments[1])
			assert.are.same({ "Ledger", "1,500 Coins all time" }, loaded.client.gameTooltip.lines)
			assert.is_true(loaded.client.gameTooltip.shown)
			purse.segments[1]:GetScript("OnLeave")(purse.segments[1])
			assert.is_false(loaded.client.gameTooltip.shown)
		end
	)

	it(
		"fades an off Module's segment and strikes its legend through, its total still counting (wallet-and-shop.md › UI)",
		function()
			local loaded = shopSession(
				{ global = { coins = { earned = { Hunts = 300, Ledger = 100 } } } },
				{ noHunts = true }
			)
			loaded.env.Pagle.OpenShop()

			local purse = shop(loaded).purse
			local hunts = purse.segments[2]
			assert.are.equal("400", purse.balance:GetText())
			assert.are.equal("Hunts 300", hunts.legend:GetText())
			assert.are.equal(0.35, hunts:GetAlpha())
			assert.is_true(hunts.strike:IsShown())
			assert.is_false(purse.segments[1].strike:IsShown())
		end
	)

	it("redraws on BalanceChanged, and never shows Spent (wallet-and-shop.md › UI)", function()
		local loaded, handles = shopSession()
		loaded.env.Pagle.OpenShop()

		handles.Ledger:ReportCoinsEarned(200)

		local frame = shop(loaded)
		assert.are.equal("200", frame.purse.balance:GetText())
		assert.are.equal("core.toaststyle.ripple | 150" .. COIN, listed(loaded)[3])
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
			local loaded = shopSession()

			loaded.env.Pagle.OpenShop()

			local expected = { unpack(CORE_UNBOUGHT) }
			for _, line in ipairs({
				"Journal binding 1/2",
				"Oak | In use",
				"Lapis | 900" .. COIN,
				"Notebook cover 1/2",
				"Plain | In use",
				"Velvet | 400" .. COIN,
			}) do
				expected[#expected + 1] = line
			end
			assert.are.same(expected, listed(loaded))
			local velvet = rowOf(loaded, "hunts.cover.velvet")
			assert.are.equal(134939, velvet.swatch.texture)
			assert.are.same({ 1, 0.25, 0.25 }, velvet.tag.textColor, "a price the balance can't cover is red")
		end
	)

	it("narrows with the search box (wallet-and-shop.md › UI)", function()
		local loaded = shopSession()
		loaded.env.Pagle.OpenShop()

		shop(loaded).search:Type("RIP")

		assert.are.same({ "Toast style 1/3", "core.toaststyle.ripple | 150" .. COIN }, listed(loaded))
		shop(loaded).search:Type("nothing like it")
		assert.are.same({}, listed(loaded))
		assert.is_true(shop(loaded).empty:IsShown())
		assert.are.equal("No looks match.", shop(loaded).empty:GetText())
	end)

	it("narrows with the filter All / Owned / Not owned / Can afford (wallet-and-shop.md › UI)", function()
		local loaded, handles = shopSession()
		handles.Ledger:ReportCoinsEarned(500)
		loaded.env.Pagle.OpenShop()
		local filters = shop(loaded).filters

		assert.are.same(
			{ "All", "Owned", "Not owned", "Can afford" },
			{ filters.all:GetText(), filters.owned:GetText(), filters.notOwned:GetText(), filters.canAfford:GetText() }
		)
		filters.canAfford:Click()
		assert.are.same({
			"Toast style 1/3",
			"core.toaststyle.ripple | 150" .. COIN,
			"core.toaststyle.lanternglow | 400" .. COIN,
			"Sound set 1/2",
			"core.soundset.gilded | 400" .. COIN,
			"Bookplate crest 1/4",
			"core.crest.crest1 | 150" .. COIN,
			"core.crest.crest2 | 400" .. COIN,
			"Notebook cover 1/2",
			"Velvet | 400" .. COIN,
		}, listed(loaded))
		assert.is_true(filters.canAfford.highlightLocked)
		assert.is_false(filters.all.highlightLocked)
		filters.owned:Click()
		assert.are.same({
			"Toast style 1/3",
			"core.toaststyle.timber | In use",
			"Sound set 1/2",
			"core.soundset.driftwood | In use",
			"Bookplate crest 1/4",
			"core.crest.plain | In use",
			"Journal binding 1/2",
			"Oak | In use",
			"Notebook cover 1/2",
			"Plain | In use",
		}, listed(loaded))
		filters.notOwned:Click()
		assert.are.equal(13, #listed(loaded))
		filters.all:Click()
		assert.are.equal(18, #listed(loaded))
	end)

	it(
		"shows a chip for each category a slot uses, in order, and narrows to one (wallet-and-shop.md › UI)",
		function()
			local loaded = shopSession()
			loaded.env.Pagle.OpenShop()
			local frame = shop(loaded)

			local labels = {}
			for _, chip in ipairs(frame.chips) do
				if chip:IsShown() then
					labels[#labels + 1] = chip:GetText()
				end
			end
			assert.are.same({ "All", "Announcements", "Bookplate", "Fish Journal", "Hunts" }, labels)

			frame.chips[4]:Click()
			assert.are.same({ "Journal binding 1/2", "Oak | In use", "Lapis | 900" .. COIN }, listed(loaded))
			assert.is_true(frame.chips[4].highlightLocked)
			frame.chips[1]:Click()
			assert.are.equal(18, #listed(loaded))
		end
	)

	it("puts a clicked row's good on the stage (wallet-and-shop.md › UI)", function()
		local loaded = shopSession()
		loaded.env.Pagle.OpenShop()

		rowOf(loaded, "ledger.binding.lapis"):Click()

		assert.are.equal("Lapis", shop(loaded).stage.name:GetText())
		assert.is_true(rowOf(loaded, "ledger.binding.lapis").selectedMark:IsShown())
	end)
end)

describe("The Curio Shop's stage", function()
	it(
		"shows a good for sale's price and Buy for N, disabled until buying arrives, with its description"
			.. " (wallet-and-shop.md › UI)",
		function()
			local loaded, handles = shopSession()
			handles.Ledger:ReportCoinsEarned(1000)

			loaded.env.Pagle.OpenShop("hunts.cover.velvet")

			local stage = shop(loaded).stage
			assert.are.equal("Soft to the touch.", stage.description:GetText())
			assert.are.equal("400" .. COIN, stage.price:GetText())
			assert.are.same({ 1, 1, 1 }, stage.price.textColor)
			assert.is_true(stage.buy:IsShown())
			assert.are.equal("Buy for 400" .. COIN, stage.buy:GetText())
			assert.is_false(stage.buy:IsEnabled())
			assert.is_false(stage.needed:IsShown())
			assert.is_false(stage.use:IsShown())
		end
	)

	it("shows a price the balance can't cover in red, with N more needed (wallet-and-shop.md › UI)", function()
		local loaded, handles = shopSession()
		handles.Ledger:ReportCoinsEarned(100)

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")

		local stage = shop(loaded).stage
		assert.are.same({ 1, 0.25, 0.25 }, stage.price.textColor)
		assert.is_false(stage.buy:IsEnabled())
		assert.is_true(stage.needed:IsShown())
		assert.are.equal("300 more needed", stage.needed:GetText())
	end)

	it(
		"shows Owned and Use for an owned good, and Use equips it, then In use (SHOP-R32, wallet-and-shop.md › UI)",
		function()
			local loaded = shopSession()
			local Pagle = loaded.env.Pagle
			loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
			Pagle.OpenShop("core.toaststyle.ripple")
			local stage = shop(loaded).stage
			assert.are.equal("Owned", stage.tags:GetText())
			assert.is_false(stage.buy:IsShown())
			assert.is_true(stage.use:IsShown())
			assert.are.equal("Use", stage.use:GetText())

			stage.use:Click()

			assert.are.equal("core.toaststyle.ripple", Pagle.GetEquipped("core.toaststyle"))
			assert.are.equal("In use", stage.tags:GetText())
			assert.is_false(stage.use:IsShown())
			assert.are.same(
				{ "Toast style 2/3", "core.toaststyle.timber | default", "core.toaststyle.ripple | In use" },
				{ listed(loaded)[1], listed(loaded)[2], listed(loaded)[3] }
			)
		end
	)

	it("redraws on AppearanceChanged from elsewhere (SHOP-R33)", function()
		local loaded = shopSession()
		local Pagle = loaded.env.Pagle
		loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
		Pagle.OpenShop("core.toaststyle.timber")
		assert.are.equal("In use · default", shop(loaded).stage.tags:GetText())

		Pagle.SetEquipped("core.toaststyle", "core.toaststyle.ripple")

		assert.are.equal("default", shop(loaded).stage.tags:GetText())
		assert.is_true(shop(loaded).stage.use:IsShown())
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

		local stage = shop(loaded).stage
		assert.are.equal("Angler Level 30\nA Ledger reward, not for sale", stage.notes:GetText())
		assert.is_false(stage.buy:IsShown())
		assert.is_false(stage.price:IsShown())
		assert.are.equal("Angler Level 30", rowOf(loaded, "ledger.binding.level30").tag:GetText())
	end)

	it(
		"draws the good's preview on its own stage frame, once each time it is selected (wallet-and-shop.md › UI)",
		function()
			local drawn = {}
			local loaded = shopSession(nil, {
				preview = function(stage)
					drawn[#drawn + 1] = stage
				end,
			})
			local Pagle = loaded.env.Pagle

			Pagle.OpenShop("hunts.cover.velvet")
			local stage = shop(loaded).stage
			assert.are.equal(1, #drawn)
			assert.is_true(drawn[1]:IsShown())
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
		local loaded = shopSession(nil, {
			preview = function()
				error("no paint")
			end,
		})

		loaded.env.Pagle.OpenShop("hunts.cover.velvet")

		assert.are.equal("Velvet", shop(loaded).stage.name:GetText())
		assert.are.equal(1, #loaded.client.errors)
		assert.matches("no paint", loaded.client.errors[1], 1, true)
	end)
end)
