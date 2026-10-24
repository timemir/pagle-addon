-- The Look and Feel page and the slot dropdowns, driven through the fake client's Settings panel over Core's own slots
-- and a fixture Ledger's "Books" slot (settings.md SET-R1, SET-R5, SET-R12, SET-R30, SET-R50–R53, SET-R60–R62;
-- CORE-R40, CORE-R42, CORE-R43; wallet-and-shop.md › UI, SHOP-R32, SHOP-R35, SHOP-R40, SHOP-R41).

local PARAGRAPH = "Looks you own. Pick one here or with Use in the Curio Shop; both change the same thing."

-- Core logged in and in the world with its own goods and a fixture Ledger (order 10) whose "Books" slot has
-- Oak (default), Lapis (tier 3) and Ivy (tier 1), and with two zone crests in Core's crest slot, earned goods
-- (SHOP-R23): The Old Oak, earned, and The Desert Sun, not. `options.saved` is a PagleDB; `options.noLedger` leaves the Ledger
-- unregistered (off); `options.hunts` registers Hunts (order 20) with a Trackers slot. Returns the loaded addon.
local function coreWithModules(options)
	options = options or {}
	local loaded = loadCore(nil, options.saved)
	local Pagle = loaded.env.Pagle
	if not options.noLedger then
		local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
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
-- then its note "  <note>" while shown, a button row "<label> [<caption>]".
local function lines(rows, settings)
	local out = {}
	for _, row in ipairs(rows) do
		local initializer, frame = row.initializer, row.frame
		if initializer.template == "SettingsListSectionHeaderTemplate" then
			out[#out + 1] = "# " .. initializer:GetName()
		elseif initializer.template == "PagleSettingsSlotRowTemplate" then
			out[#out + 1] = ("%s = %s"):format(initializer:GetName(), tostring(settings.dropdownOf(row).selected))
			for _, text in ipairs(settings.notesOf(row)) do
				out[#out + 1] = "  " .. text
			end
		elseif initializer.template == "SettingButtonControlTemplate" then
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
		"shows the paragraph, Announcements, Crests and Books with their dropdowns, then the Curio Shop (SET-R50)",
		function()
			local loaded = coreWithModules()

			assert.are.same({
				PARAGRAPH,
				"# Announcements",
				"Toast style = core.toaststyle.page",
				"  15 more in the Curio Shop",
				"Sound set = core.soundset.driftwood",
				"  26 more in the Curio Shop",
				"# Crests",
				"Crests = core.crest.plain",
				"# Books",
				"Book binding = core.binding.field",
				"  33 more in the Curio Shop",
				"Journal binding = ledger.binding.oak",
				"  2 more in the Curio Shop",
				"# Curio Shop",
				"Buy more looks with Pagle Coins [Open the Curio Shop]",
			}, lines(showLook(loaded), loaded.client.settings))
		end
	)

	it(
		"leaves out a Module's slots and header while it isn't On, and adds a Trackers one after (SET-R4, SET-R50)",
		function()
			local loaded = coreWithModules({ noLedger = true, hunts = true })

			local shown = lines(showLook(loaded), loaded.client.settings)

			assert.is_false(table.concat(shown, "\n"):find("Journal binding", 1, true) ~= nil)
			assert.are.same(
				{ "# Trackers", "Hunts tracker frame = hunts.trackerframe.none", "# Curio Shop" },
				{ shown[12], shown[13], shown[14] }
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

	it("shows no note once every good for sale in the slot is owned (SET-R51)", function()
		local loaded = coreWithModules()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true, ["ledger.binding.lapis"] = true })

		local row = loaded.client.settings.rowNamed(showLook(loaded), "Journal binding")

		assert.are.same({}, loaded.client.settings.notesOf(row))
	end)
end)

describe("The Announcements page's slot rows", function()
	it("end Core's rows with Toast style and Sound set, after Animations (SET-R30, CORE-R42)", function()
		local loaded = coreWithModules()

		local names = {}
		for i, row in ipairs(loaded.client.settings.show(loaded.client.settings.page("Announcements"))) do
			names[i] = row.initializer:GetName()
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
		}, names)
	end)

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
