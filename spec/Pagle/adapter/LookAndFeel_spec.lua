-- The Look and Feel page and the slot dropdowns, driven through the fake client's Settings panel over Core's own slots
-- and a fixture Ledger's "Books" slot (settings.md SET-R1, SET-R5, SET-R12, SET-R30, SET-R50–R53, SET-R60–R62;
-- CORE-R40, CORE-R42, CORE-R43; wallet-and-shop.md › UI, SHOP-R32, SHOP-R35, SHOP-R40, SHOP-R41).

local PARAGRAPH =
	"Looks you own. Pick one here, in the Fish Journal's Collection or with Use in the Curio Shop; all of them change the same thing."

-- Core logged in and in the world with its own goods and a fixture Ledger (order 10) whose "Books" slot has
-- Oak (default), Lapis (tier 3) and Ivy (tier 1), and with two zone crests in Core's crest slot, earned goods
-- (SHOP-R23): The Old Oak, earned, and The Desert Sun, not. `options.saved` is a PagleDB; `options.noLedger` leaves the Ledger
-- unregistered (off); `options.hunts` registers Hunts (order 20) with a Trackers slot; `options.collection` is the
-- Ledger's def.collection (CORE-R45); `options.L` replaces Core's strings before its pages are built. Returns the
-- loaded addon.
local function coreWithModules(options)
	options = options or {}
	local loaded = loadCore(nil, options.saved)
	for key, text in pairs(options.L or {}) do
		loaded.ns.L[key] = text
	end
	local Pagle = loaded.env.Pagle
	if not options.noLedger then
		local ledger = Pagle.RegisterModule({
			name = "Ledger",
			title = "Ledger",
			order = 10,
			collection = options.collection,
		})
		ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Books" })
		ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
		ledger:RegisterGood({ id = "ledger.binding.lapis", slot = "ledger.binding", name = "Lapis", tier = 3 })
		ledger:RegisterGood({ id = "ledger.binding.ivy", slot = "ledger.binding", name = "Ivy", tier = 1 })
		for _, crest in ipairs({
			{ "ledger.crest.elwynn", "The Old Oak", true },
			{ "ledger.crest.tanaris", "The Desert Sun" },
		}) do
			ledger:RegisterGood({
				id = crest[1],
				slot = "core.crest",
				name = crest[2],
				isEarned = function()
					return crest[3] == true
				end,
				earnedText = function()
					return "Unfished"
				end,
			})
		end
	end
	if options.hunts then
		local hunts = Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
		hunts:RegisterSlot({ id = "hunts.trackerframe", label = "Hunts tracker frame", category = "Trackers" })
		hunts:RegisterGood({
			id = "hunts.trackerframe.none",
			slot = "hunts.trackerframe",
			name = "None",
			default = true,
		})
	end
	enterWorld(loaded, 2)
	return loaded
end

-- Shows Look and Feel as the panel does, and returns its rows.
local function showLook(loaded)
	return loaded.client.settings.show(loaded.client.settings.page("Look and Feel"))
end

-- Each shown row as one line: a header "# <name>", a paragraph's text, a slot dropdown "<label> = <selected good>"
-- then its note "  <note>" while shown, a button row "<label> [<caption>]", whether Blizzard's or Core's own (#606).
local function lines(rows, settings)
	local out = {}
	for _, row in ipairs(rows) do
		local initializer, frame = row.initializer, row.frame
		if initializer.template == "PagleSettingsListSectionHeaderTemplate" then
			out[#out + 1] = "# " .. initializer:GetName()
		elseif initializer.template == "PagleSettingsSlotRowTemplate" then
			out[#out + 1] = ("%s = %s"):format(initializer:GetName(), tostring(settings.dropdownOf(row).selected))
			for _, text in ipairs(settings.notesOf(row)) do
				out[#out + 1] = "  " .. text
			end
		elseif
			initializer.template == "PagleSettingButtonControlTemplate"
			or (initializer:GetName() and settings.buttonsOf(frame)[1])
		then
			out[#out + 1] = ("%s [%s]"):format(initializer:GetName(), settings.buttonsOf(frame)[1]:GetText())
		else
			for _, text in ipairs(settings.textsOf(frame)) do
				out[#out + 1] = text
			end
		end
	end
	return out
end

describe("The Look and Feel page", function()
	it("is registered after Announcements with no Module On (SET-R1, CORE-R40)", function()
		local loaded = coreWithModules({ noLedger = true })

		local names = {}
		for i, category in ipairs(loaded.client.settings.categories) do
			names[i] = category.name
		end
		assert.are.same({ "Pagle", "Announcements", "Look and Feel" }, names)
		assert.are.equal(loaded.client.settings.page("Pagle"), loaded.client.settings.page("Look and Feel").parent)
	end)

	it(
		"shows the paragraph, Announcements, Crests and Books with their dropdowns, then More looks with the Curio Shop (SET-R50)",
		function()
			local loaded = coreWithModules()

			assert.are.same({
				PARAGRAPH,
				"# Announcements",
				"Toast style = core.toaststyle.page",
				"  23 more in the Curio Shop",
				"Sound set = core.soundset.driftwood",
				"  26 more in the Curio Shop",
				"News sign = core.newssign.wood", -- from 1.6 (SHOP-R60)
				"  5 more in the Curio Shop",
				"# Crests",
				"Crests = core.crest.plain",
				"# Books",
				"Book binding = core.binding.field",
				"  33 more in the Curio Shop",
				"Journal binding = ledger.binding.oak",
				"  2 more in the Curio Shop",
				"# More looks",
				"Buy more looks with Pagle Coins [Open the Curio Shop]",
			}, lines(showLook(loaded), loaded.client.settings))
		end
	)

	it("puts the Collection's row above the Curio Shop's while an On Module offers one (SET-R50, CORE-R45)", function()
		local loaded = coreWithModules({ collection = function() end })

		local shown = lines(showLook(loaded), loaded.client.settings)

		assert.are.same({
			"# More looks",
			"Every look, and how to earn it [Open the Collection]",
			"Buy more looks with Pagle Coins [Open the Curio Shop]",
		}, { unpack(shown, #shown - 2) })
	end)

	it(
		"leaves the Collection's row out while no On Module offers one, the Ledger being off (SET-R50, CORE-R45)",
		function()
			local loaded = coreWithModules({ noLedger = true, hunts = true })

			local shown = table.concat(lines(showLook(loaded), loaded.client.settings), "\n")

			assert.is_nil(shown:find("Open the Collection", 1, true))
			assert.is_truthy(shown:find("# More looks\nBuy more looks with Pagle Coins [Open the Curio Shop]", 1, true))
		end
	)

	it(
		"leaves out a Module's slots and header while it isn't On, and adds a Trackers one after (SET-R4, SET-R50)",
		function()
			local loaded = coreWithModules({ noLedger = true, hunts = true })

			local shown = lines(showLook(loaded), loaded.client.settings)

			assert.is_false(table.concat(shown, "\n"):find("Journal binding", 1, true) ~= nil)
			assert.are.same(
				{ "# Trackers", "Hunts tracker frame = hunts.trackerframe.none", "# More looks" },
				{ shown[14], shown[15], shown[16] }
			)
		end
	)

	it('is opened by Pagle.OpenSettings("look") (CORE-R43)', function()
		local loaded = coreWithModules()

		loaded.env.Pagle.OpenSettings("look")

		assert.are.same({ "Look and Feel" }, openedNames(loaded))
	end)
end)

describe("A slot dropdown", function()
	it(
		"is Core's own row found by its slot's label, never greyed out, with no tooltip (SET-R5, SET-R6, SET-R51, SET-R2)",
		function()
			local loaded = coreWithModules()

			local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")

			assert.are.equal("PagleSettingsSlotRowTemplate", row.initializer:GetTemplate())
			assert.are.equal("PagleSettingsSlotRowMixin", loaded.client.templates.PagleSettingsSlotRowTemplate.mixin)
			assert.are.same({ "JOURNAL BINDING" }, row.initializer.searchTags)
			-- Never greyed out: nothing to grey it by, and its dropdown takes clicks. The fake panel greys only Blizzard's
			-- native controls, as the client does (#120).
			assert.are.same({}, row.initializer.modifyPredicates)
			assert.is_true(loaded.client.settings.dropdownOf(row):IsEnabled())
			assert.is_nil(row.initializer:GetTooltip())
			assert.are.equal("Journal binding", loaded.client.settings.textsOf(row.frame)[1])
			-- Its Defaults setting (SET-R60): the slot's default good.
			local setting = loaded.client.settings.variables["Pagle_Core_look_ledger.binding"]
			assert.are.equal("ledger.binding.oak", setting:GetDefaultValue())
		end
	)

	it("lists only the slot's owned goods, read each time it opens (SET-R51, SHOP-R30)", function()
		local loaded = coreWithModules()
		local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")
		assert.are.same({ "ledger.binding.oak=Oak" }, loaded.client.settings.optionValues(row))

		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true })

		assert.are.same(
			{ "ledger.binding.oak=Oak", "ledger.binding.ivy=Ivy" },
			loaded.client.settings.optionValues(row)
		)
	end)

	it("equips the good picked, and shows the equipped one with its name (SET-R51, SHOP-R32)", function()
		local loaded = coreWithModules()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.lapis"] = true })
		local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")

		loaded.client.settings.dropdownOf(row):pick("Lapis")

		assert.are.equal("ledger.binding.lapis", loaded.env.Pagle.GetEquipped("ledger.binding"))
		assert.are.equal("Lapis", loaded.client.settings.dropdownOf(row).text)
	end)

	it("redraws at once when SetEquipped is called elsewhere (SET-R51, SET-R62, SHOP-R33)", function()
		local loaded = coreWithModules()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true })
		local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")

		loaded.env.Pagle.SetEquipped("ledger.binding", "ledger.binding.ivy")

		assert.are.same(
			{ "ledger.binding.ivy", "Ivy" },
			{ loaded.client.settings.dropdownOf(row).selected, loaded.client.settings.dropdownOf(row).text }
		)
	end)

	it(
		"lists the crests earned, of whichever Module, with no note: none is for sale (SET-R51, SHOP-R23, SHOP-R25)",
		function()
			local loaded = coreWithModules()

			-- The slot's row, the last named Crests: its category's header, of the same name, comes first (SET-R50).
			local row
			for _, candidate in ipairs(showLook(loaded)) do
				if candidate.initializer:GetName() == "Crests" then
					row = candidate
				end
			end
			row = assert(row, "no Crests row")

			assert.are.same(
				{ "core.crest.plain=Plain", "ledger.crest.elwynn=The Old Oak" },
				loaded.client.settings.optionValues(row)
			)
			assert.are.same({}, loaded.client.settings.notesOf(row))
			loaded.client.settings.dropdownOf(row):pick("The Old Oak")
			assert.are.equal("ledger.crest.elwynn", loaded.env.Pagle.GetEquipped("core.crest"))
		end
	)

	it(
		"ends a slot's label short of its dropdown, wrapping on two lines, so a long one never runs under it (SET-R51)",
		function()
			local loaded = coreWithModules()

			local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")

			local label
			for _, child in ipairs(row.frame.children) do
				if child.shown and child.text == "Journal binding" then
					label = child
				end
			end
			label = assert(label)
			local dropdown = loaded.client.settings.dropdownOf(row)
			assert.is_true(label:CanWordWrap())
			assert.are.equal(2, label:GetMaxLines())
			-- Both hang from the row's top centre: the label's right edge ends left of the dropdown's left edge.
			local right
			for _, point in ipairs(label.points) do
				if point[1] == "RIGHT" then
					assert.are.equal(row.frame, point[2])
					assert.are.equal("TOP", point[3])
					right = point[4]
				end
			end
			assert.are.equal("TOP", dropdown.points[1][3])
			assert(right and right < dropdown.points[1][4], "the label runs under the dropdown")
		end
	)

	it(
		"widens its dropdown to its longest good's name, from 220 up to 300, so a longer language's name isn't cut"
			.. " (SET-R51)",
		function()
			local loaded = coreWithModules()
			local dropdown =
				loaded.client.settings.dropdownOf(loaded.client.settings.rowNamed(showLook(loaded), "Journal binding"))
			assert.are.equal(220, dropdown:GetWidth(), "Oak fits the native width")

			-- A name like a German crest's, "Wappen: Longjaw Mud Snapper": wider than the 176 the native width leaves its
			-- words on the fake, 6 a character.
			loaded.ns.goods:SetPurchased({ ["ledger.binding.lapis"] = true })
			local long = "Wappen: Longjaw Mud Snapper (Rare Silver)"
			-- Renamed as a fish crest is once the client has the fish (VAR-R12).
			for _, good in ipairs(loaded.ns.goods:OwnedOf("ledger.binding")) do
				if good.id == "ledger.binding.lapis" then
					good.name = long
				end
			end
			dropdown =
				loaded.client.settings.dropdownOf(loaded.client.settings.rowNamed(showLook(loaded), "Journal binding"))
			assert(#long * 6 > 220 - 44, "the case is cut at the native width")
			assert.are.equal(#long * 6 + 44, dropdown:GetWidth())
		end
	)

	it("shows no note once every good for sale in the slot is owned (SET-R51)", function()
		local loaded = coreWithModules()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true, ["ledger.binding.lapis"] = true })

		local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")

		assert.are.same({}, loaded.client.settings.notesOf(row))
	end)
end)

describe("The Announcements page's slot rows", function()
	it(
		"follow Animations with Toast style and Sound set, then the Toast position button (SET-R30, CORE-R42)",
		function()
			local loaded = coreWithModules()

			-- Core's rows, up to the Party block that follows them (SET-R36, spec/Pagle/adapter/Party_spec.lua).
			local names = {}
			for i, row in ipairs(loaded.client.settings.show(loaded.client.settings.page("Announcements"))) do
				if i <= 9 then
					names[i] = row.initializer:GetName()
				end
			end

			assert.are.same({
				"Cozy mode",
				"Interruption budget",
				"Interruptions",
				"Per",
				"Show every catch",
				"Animations",
				"Toast style",
				"Sound set",
				"Toast position",
			}, names)
		end
	)

	it("pick the same look Look and Feel shows (SET-R30, SET-R51)", function()
		local loaded = coreWithModules()
		loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
		local toast = loaded.client.settings.rowNamed(
			loaded.client.settings.show(loaded.client.settings.page("Announcements")),
			"Toast style"
		)

		loaded.client.settings.dropdownOf(toast):pick("core.toaststyle.ripple")

		assert.are.equal(
			"core.toaststyle.ripple",
			loaded.client.settings.dropdownOf(loaded.client.settings.rowNamed(showLook(loaded), "Toast style")).selected
		)
		assert.are.equal("core.toaststyle.ripple", loaded.env.Pagle.GetEquipped("core.toaststyle"))
	end)
end)

describe("Defaults", function()
	-- A PagleDB whose picks are Lapis, Ripple, Gilded, The Old Oak and Hunts' Velvet cover, all bought but the crest,
	-- which is earned.
	local function picked()
		return {
			profiles = {
				Default = {
					appearance = {
						["ledger.binding"] = "ledger.binding.lapis",
						["core.toaststyle"] = "core.toaststyle.ripple",
						["core.soundset"] = "core.soundset.gilded",
						["core.crest"] = "ledger.crest.elwynn",
						["hunts.cover"] = "hunts.cover.velvet",
					},
				},
			},
		}
	end
	local BOUGHT = {
		["ledger.binding.lapis"] = true,
		["core.toaststyle.ripple"] = true,
		["core.soundset.gilded"] = true,
		["hunts.cover.velvet"] = true,
	}

	it(
		"on Look and Feel sets every slot shown to its default good, keeping what is owned (SET-R52, SET-R60)",
		function()
			local loaded = coreWithModules({ saved = picked() })
			loaded.ns.goods:SetPurchased(BOUGHT)
			local Pagle = loaded.env.Pagle
			assert.are.equal("ledger.binding.lapis", Pagle.GetEquipped("ledger.binding"))
			showLook(loaded)

			loaded.client.settings.defaults(loaded.client.settings.page("Look and Feel"))

			assert.are.same({
				"core.toaststyle.page",
				"core.soundset.driftwood",
				"core.crest.plain",
				"ledger.binding.oak",
			}, {
				Pagle.GetEquipped("core.toaststyle"),
				Pagle.GetEquipped("core.soundset"),
				Pagle.GetEquipped("core.crest"),
				Pagle.GetEquipped("ledger.binding"),
			})
			assert.is_true(Pagle.IsOwned("ledger.binding.lapis"))
		end
	)

	it("on Look and Feel leaves the stored look of a Module that isn't On (SET-R52, SHOP-R32, SET-R90)", function()
		local loaded = coreWithModules({ saved = picked() })
		loaded.ns.goods:SetPurchased(BOUGHT)
		showLook(loaded)

		loaded.client.settings.defaults(loaded.client.settings.page("Look and Feel"))

		assert.are.equal("hunts.cover.velvet", loaded.ns.db.profile.appearance["hunts.cover"])
	end)

	it("on Announcements restores its two slot rows and leaves the crest and binding (SET-R33, SET-R60)", function()
		local loaded = coreWithModules({ saved = picked() })
		loaded.ns.goods:SetPurchased(BOUGHT)
		local Pagle = loaded.env.Pagle

		loaded.client.settings.defaults(loaded.client.settings.page("Announcements"))

		assert.are.same({
			"core.toaststyle.page",
			"core.soundset.driftwood",
			"ledger.crest.elwynn",
			"ledger.binding.lapis",
		}, {
			Pagle.GetEquipped("core.toaststyle"),
			Pagle.GetEquipped("core.soundset"),
			Pagle.GetEquipped("core.crest"),
			Pagle.GetEquipped("ledger.binding"),
		})
	end)
end)

describe("The Collection button", function()
	it(
		"closes the Settings panel, then calls the first On Module's def.collection with no good (SET-R50, CORE-R45)",
		function()
			local calls = {}
			local loaded
			loaded = coreWithModules({
				collection = function(goodID)
					calls[#calls + 1] = { panelShown = loaded.client.settings.panel:IsShown(), goodID = goodID }
				end,
			})
			loaded.env.Pagle.OpenSettings("look")
			local row = loaded.client.settings.rowNamed(showLook(loaded), "Every look, and how to earn it")

			loaded.client.settings.buttonsOf(row.frame)[1]:Click()

			assert.are.same({ { panelShown = false } }, calls)
		end
	)

	it("reports a def.collection that raises through the error handler (CORE-R45)", function()
		local loaded = coreWithModules({
			collection = function()
				error("no Collection today")
			end,
		})
		local row = loaded.client.settings.rowNamed(showLook(loaded), "Every look, and how to earn it")

		loaded.client.settings.buttonsOf(row.frame)[1]:Click()

		assert.are.equal(1, #loaded.client.errors)
		assert.matches("no Collection today", loaded.client.errors[1])
	end)
end)

-- More looks' button rows, which Core draws itself as a native button row looks (SET-R5, SET-R50, #606): a native
-- button is a fixed 200 wide, and a longer caption ran past both its sides.
describe("More looks' button rows", function()
	for _, case in ipairs({
		{ label = "Buy more looks with Pagle Coins", key = "SETTINGS_SHOP_BUTTON" },
		{ label = "Every look, and how to earn it", key = "SETTINGS_COLLECTION_BUTTON", collection = true },
	}) do
		it(
			("draws %q itself, the button from where a native row's control starts and as wide as its caption, found by"):format(
				case.label
			) .. " its label and caption, its label alone over the row and the button (SET-R5, SET-R50, #606)",
			function()
				-- 37 characters: 222 wide in the fake, past a native button's 200 with its padding
				local loaded = coreWithModules({
					collection = case.collection and function() end or nil,
					L = { [case.key] = "Open it all, every last look and coin" },
				})

				local row = loaded.client.settings.rowNamed(showLook(loaded), case.label)

				local button = loaded.client.settings.buttonsOf(row.frame)[1]
				assert.are.equal("PagleSettingsRowTemplate", row.initializer.template)
				assert.are.equal("Open it all, every last look and coin", button.text)
				assert.are.equal(37 * 6 + 24, button:GetWidth())
				assert.are.same({ "TOPLEFT", row.frame, "TOP", -40, 3 }, { button:GetPoint() })
				assert.are.same(
					{ case.label:upper(), "OPEN IT ALL, EVERY LAST LOOK AND COIN" },
					row.initializer.searchTags
				)
				assert.is_nil(row.initializer:GetTooltip())
				local label
				for _, child in ipairs(row.frame.children) do
					if child.kind == "FontString" and child.shown and child.text == case.label then
						label = child
					end
				end
				assert.are.equal("GameFontNormal", assert(label).fontObject)
				-- no tooltip line: the label alone, as a native row with none shows it
				for _, region in ipairs({ row.frame, button }) do
					region:GetScript("OnEnter")(region)
					assert.are.same({ case.label }, loaded.client.tooltipLines())
					region:GetScript("OnLeave")(region)
				end
			end
		)
	end
end)

describe("The Curio Shop button", function()
	-- Look and Feel's button row, shown.
	local function shopButton(loaded)
		return loaded.client.settings.buttonsOf(
			loaded.client.settings.rowNamed(showLook(loaded), "Buy more looks with Pagle Coins").frame
		)[1]
	end

	it("closes the Settings panel, then opens the Curio Shop (SET-R50, SET-R12, SHOP-R40)", function()
		local loaded = coreWithModules()
		local panelShownAtOpen
		local open = loaded.env.Pagle.OpenShop
		loaded.env.Pagle.OpenShop = function(...)
			panelShownAtOpen = loaded.client.settings.panel:IsShown()
			return open(...)
		end
		loaded.env.Pagle.OpenSettings("look")

		shopButton(loaded):Click()

		assert.is_false(panelShownAtOpen)
		assert.is_true(loaded.ns.shopFrame:IsShown())
	end)

	it("closes the panel and prints SHOP-R41's line while restricted (SET-R12, SET-R93, SHOP-R41)", function()
		local loaded = coreWithModules()
		local button = shopButton(loaded)
		setCombat(loaded, true)

		button:Click()

		assert.is_false(loaded.client.settings.panel:IsShown())
		assert.is_nil(loaded.ns.shopFrame)
		assert.are.same({ "Pagle: the Curio Shop opens after combat." }, loaded.printed)
	end)
end)
