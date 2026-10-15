-- The Look and Feel page and the slot dropdowns, driven through the fake client's Settings panel over Core's own slots
-- and a fixture Ledger's "Fish Journal" slot (settings.md SET-R1, SET-R5, SET-R12, SET-R30, SET-R50–R53, SET-R60–R62;
-- CORE-R40, CORE-R42, CORE-R43; wallet-and-shop.md › UI, SHOP-R32, SHOP-R35, SHOP-R40, SHOP-R41).

local PARAGRAPH = "Looks you own. Pick one here or with Use in the Curio Shop; both change the same thing."

-- Core logged in and in the world with its own goods and a fixture Ledger (order 10) whose "Fish Journal" slot has
-- Oak (default), Lapis (tier 3) and Ivy (tier 1). `options.saved` is a PagleDB; `options.noLedger` leaves the Ledger
-- unregistered (off); `options.hunts` registers Hunts (order 20) with a Trackers slot. Returns the loaded addon.
local function session(options)
	options = options or {}
	local loaded = loadCore(nil, options.saved)
	local Pagle = loaded.env.Pagle
	if not options.noLedger then
		local ledger = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		ledger:RegisterSlot({ id = "ledger.binding", label = "Journal binding", category = "Fish Journal" })
		ledger:RegisterGood({ id = "ledger.binding.oak", slot = "ledger.binding", name = "Oak", default = true })
		ledger:RegisterGood({ id = "ledger.binding.lapis", slot = "ledger.binding", name = "Lapis", tier = 3 })
		ledger:RegisterGood({ id = "ledger.binding.ivy", slot = "ledger.binding", name = "Ivy", tier = 1 })
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

-- A registered Settings page by name.
local function page(loaded, name)
	return assert(loaded.client.settings.category(name), "no page " .. name)
end

-- Shows Look and Feel as the panel does, and returns its rows.
local function showLook(loaded)
	return loaded.client.settings.show(page(loaded, "Look and Feel"))
end

-- A slot dropdown row's dropdown (the fake's DropdownButton, spec/support/widgets.lua).
local function dropdownOf(row)
	for _, child in ipairs(row.frame.children) do
		if child.kind == "DropdownButton" then
			return child
		end
	end
	error("no dropdown on " .. row.initializer:GetName())
end

-- The texts a slot dropdown row shows under its label and dropdown: its note while shown.
local function notes(row, settings)
	return { select(3, unpack(settings.textsOf(row.frame))) }
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
			out[#out + 1] = ("%s = %s"):format(initializer:GetName(), tostring(dropdownOf(row).selected))
			for _, text in ipairs(notes(row, settings)) do
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

-- The shown row whose label is `label`.
local function rowNamed(rows, label)
	for _, row in ipairs(rows) do
		if row.initializer:GetName() == label then
			return row
		end
	end
	error("no row " .. label)
end

-- The values of a slot dropdown's choices, read as the dropdown opens.
local function optionValues(row)
	return dropdownOf(row):choices()
end

describe("The Look and Feel page", function()
	it("is registered after Announcements with no Module On (SET-R1, CORE-R40)", function()
		local loaded = session({ noLedger = true })

		local names = {}
		for i, category in ipairs(loaded.client.settings.categories) do
			names[i] = category.name
		end
		assert.are.same({ "Pagle", "Announcements", "Look and Feel" }, names)
		assert.are.equal(page(loaded, "Pagle"), page(loaded, "Look and Feel").parent)
	end)

	it(
		"shows the paragraph, Announcements, Bookplate and Fish Journal with their dropdowns, then the Curio Shop (SET-R50)",
		function()
			local loaded = session()

			assert.are.same({
				PARAGRAPH,
				"# Announcements",
				"Toast style = core.toaststyle.timber",
				"  2 more in the Curio Shop",
				"Sound set = core.soundset.driftwood",
				"  1 more in the Curio Shop",
				"# Bookplate",
				"Bookplate crest = core.crest.plain",
				"  3 more in the Curio Shop",
				"# Fish Journal",
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
			local loaded = session({ noLedger = true, hunts = true })

			local shown = lines(showLook(loaded), loaded.client.settings)

			assert.is_false(table.concat(shown, "\n"):find("Fish Journal", 1, true) ~= nil)
			assert.are.same(
				{ "# Trackers", "Hunts tracker frame = hunts.trackerframe.none", "# Curio Shop" },
				{ shown[10], shown[11], shown[12] }
			)
		end
	)

	it('is opened by Pagle.OpenSettings("look") (CORE-R43)', function()
		local loaded = session()

		loaded.env.Pagle.OpenSettings("look")

		assert.are.same({ "Look and Feel" }, openedNames(loaded))
	end)
end)

describe("A slot dropdown", function()
	it(
		"is Core's own row found by its slot's label, never greyed out, with no tooltip (SET-R5, SET-R6, SET-R51, SET-R2)",
		function()
			local loaded = session()

			local row = rowNamed(showLook(loaded), "Journal binding")

			assert.are.equal("PagleSettingsSlotRowTemplate", row.initializer:GetTemplate())
			assert.are.equal("PagleSettingsSlotRowMixin", loaded.client.templates.PagleSettingsSlotRowTemplate.mixin)
			assert.are.same({ "JOURNAL BINDING" }, row.initializer.searchTags)
			assert.is_true(row.frame.enabled)
			assert.is_nil(row.initializer:GetTooltip())
			assert.are.equal("Journal binding", loaded.client.settings.textsOf(row.frame)[1])
			-- Its Defaults setting (SET-R60): the slot's default good.
			local setting = loaded.client.settings.variables["Pagle_Core_look_ledger.binding"]
			assert.are.equal("ledger.binding.oak", setting:GetDefaultValue())
		end
	)

	it("lists only the slot's owned goods, read each time it opens (SET-R51, SHOP-R30)", function()
		local loaded = session()
		local row = rowNamed(showLook(loaded), "Journal binding")
		assert.are.same({ "ledger.binding.oak=Oak" }, optionValues(row))

		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true })

		assert.are.same({ "ledger.binding.oak=Oak", "ledger.binding.ivy=Ivy" }, optionValues(row))
	end)

	it("equips the good picked, and shows the equipped one with its name (SET-R51, SHOP-R32)", function()
		local loaded = session()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.lapis"] = true })
		local row = rowNamed(showLook(loaded), "Journal binding")

		dropdownOf(row):pick("Lapis")

		assert.are.equal("ledger.binding.lapis", loaded.env.Pagle.GetEquipped("ledger.binding"))
		assert.are.equal("Lapis", dropdownOf(row).text)
	end)

	it("redraws at once when SetEquipped is called elsewhere (SET-R51, SET-R62, SHOP-R33)", function()
		local loaded = session()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true })
		local row = rowNamed(showLook(loaded), "Journal binding")

		loaded.env.Pagle.SetEquipped("ledger.binding", "ledger.binding.ivy")

		assert.are.same({ "ledger.binding.ivy", "Ivy" }, { dropdownOf(row).selected, dropdownOf(row).text })
	end)

	it("shows no note once every good for sale in the slot is owned (SET-R51)", function()
		local loaded = session()
		loaded.ns.goods:SetPurchased({ ["ledger.binding.ivy"] = true, ["ledger.binding.lapis"] = true })

		local row = rowNamed(showLook(loaded), "Journal binding")

		assert.are.same({}, notes(row, loaded.client.settings))
	end)
end)

describe("The Announcements page's slot rows", function()
	it("end Core's rows with Toast style and Sound set, after Show every catch (SET-R30, CORE-R42)", function()
		local loaded = session()

		local names = {}
		for i, row in ipairs(loaded.client.settings.show(page(loaded, "Announcements"))) do
			names[i] = row.initializer:GetName()
		end

		assert.are.same({
			"Cozy mode",
			"Interruption budget",
			"Interruptions",
			"Per",
			"Show every catch",
			"Toast style",
			"Sound set",
		}, names)
	end)

	it("pick the same look Look and Feel shows (SET-R30, SET-R51)", function()
		local loaded = session()
		loaded.ns.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })
		local toast = rowNamed(loaded.client.settings.show(page(loaded, "Announcements")), "Toast style")

		dropdownOf(toast):pick("core.toaststyle.ripple")

		assert.are.equal("core.toaststyle.ripple", dropdownOf(rowNamed(showLook(loaded), "Toast style")).selected)
		assert.are.equal("core.toaststyle.ripple", loaded.env.Pagle.GetEquipped("core.toaststyle"))
	end)
end)

describe("Defaults", function()
	-- A PagleDB whose picks are Lapis, Ripple, Gilded, crest 1 and Hunts' Velvet cover, all bought.
	local function picked()
		return {
			profiles = {
				Default = {
					appearance = {
						["ledger.binding"] = "ledger.binding.lapis",
						["core.toaststyle"] = "core.toaststyle.ripple",
						["core.soundset"] = "core.soundset.gilded",
						["core.crest"] = "core.crest.crest1",
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
		["core.crest.crest1"] = true,
		["hunts.cover.velvet"] = true,
	}

	it(
		"on Look and Feel sets every slot shown to its default good, keeping what is owned (SET-R52, SET-R60)",
		function()
			local loaded = session({ saved = picked() })
			loaded.ns.goods:SetPurchased(BOUGHT)
			local Pagle = loaded.env.Pagle
			assert.are.equal("ledger.binding.lapis", Pagle.GetEquipped("ledger.binding"))
			showLook(loaded)

			loaded.client.settings.defaults(page(loaded, "Look and Feel"))

			assert.are.same({
				"core.toaststyle.timber",
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
		local loaded = session({ saved = picked() })
		loaded.ns.goods:SetPurchased(BOUGHT)
		showLook(loaded)

		loaded.client.settings.defaults(page(loaded, "Look and Feel"))

		assert.are.equal("hunts.cover.velvet", loaded.ns.db.profile.appearance["hunts.cover"])
	end)

	it("on Announcements restores its two slot rows and leaves the crest and binding (SET-R33, SET-R60)", function()
		local loaded = session({ saved = picked() })
		loaded.ns.goods:SetPurchased(BOUGHT)
		local Pagle = loaded.env.Pagle

		loaded.client.settings.defaults(page(loaded, "Announcements"))

		assert.are.same({
			"core.toaststyle.timber",
			"core.soundset.driftwood",
			"core.crest.crest1",
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
		return loaded.client.settings.buttonsOf(rowNamed(showLook(loaded), "Buy more looks with Pagle Coins").frame)[1]
	end

	it("closes the Settings panel, then opens the Curio Shop (SET-R50, SET-R12, SHOP-R40)", function()
		local loaded = session()
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
		local loaded = session()
		local button = shopButton(loaded)
		setCombat(loaded, true)

		button:Click()

		assert.is_false(loaded.client.settings.panel:IsShown())
		assert.is_nil(loaded.ns.shopFrame)
		assert.are.same({ "Pagle: the Curio Shop opens after combat." }, loaded.printed)
	end)
end)
