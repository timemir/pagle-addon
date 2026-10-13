-- QoL's rows on Core's Fishing page: the Casting header and the Fishing key (M1), the Lures and clams rows (Track Q
-- step 1), the Gear rows (Track Q step 2), Cast with (Track Q step 3), the While you fish rows (Track Q step 4) and
-- Open clams between Casts (Track Q step 6) (qol.md › Settings, SET-R20, SET-R21, CORE-R42).

-- QoL's row on a FakePagle Fishing page by its label.
---@param fake FakePagle
---@param label string
---@return PagleSetting
local function rowOf(fake, label)
	for _, row in ipairs(assert(fake.settingsPage("fishing"))) do
		if row.label == label then
			return row.setting
		end
	end
	error("no row " .. label)
end

describe("QoL's Fishing page with FakePagle", function()
	it("holds exactly its rows so far, in SET-R20's order, with QoL On (SET-R20, CORE-R42)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")

		fake.login()

		local page = assert(fake.settingsPage("fishing"))
		local rows = {}
		for i, row in ipairs(page) do
			rows[i] = { row.module, row.kind, row.label, row.indented }
		end
		assert.are.same({
			{ "QoL", "header", "Casting", false },
			{ "QoL", "dropdown", "Cast with", false },
			{ "QoL", "keybinding", "Fishing key", true },
			{ "QoL", "header", "Gear", false },
			{ "QoL", "dropdown", "Fishing set", false },
			{ "QoL", "button", "Save what I'm wearing as my fishing set", true },
			{ "QoL", "keybinding", "Swap gear", true },
			{ "QoL", "header", "Lures and clams", false },
			{ "QoL", "dropdown", "Lures", false },
			{ "QoL", "dropdown", "Lure", true },
			{ "QoL", "checkbox", "Open clams between Casts", false },
			{ "QoL", "header", "While you fish", false },
			{ "QoL", "checkbox", "Fishing audio mix", false },
			{ "QoL", "checkbox", "Keep sound when the game is in the background", true },
			{ "QoL", "checkbox", "Auto-loot while fishing", false },
		}, rows)
	end)

	it("gives the Gear rows qol.md's tooltips, and the fishing set no default (SET-R20, SET-R21)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		local set = rowOf(fake, "Fishing set")
		local save = rowOf(fake, "Save what I'm wearing as my fishing set")
		local swap = rowOf(fake, "Swap gear")

		-- qol.md › Settings › Tooltips, word for word; it gives the button none.
		assert.are.equal("The Fishing key puts it on when no pole is in hand. Double-click skips this.", set.tooltip)
		assert.is_nil(save.tooltip)
		assert.are.equal(
			"Swaps between your fishing set and what you wore before (saved as Pagle Previous).",
			swap.tooltip
		)
		assert.are.equal("PAGLE_SWAP_GEAR", swap.binding)
		-- None is chosen at first, and Defaults has no value to put back.
		assert.is_nil(set.default)
		assert.are.equal(-1, set.get())
		assert.are.equal("fishingSet", save.parent)
		assert.are.equal("fishingSet", swap.parent)
	end)

	it("greys Swap gear out while no fishing set is chosen (SET-R20)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		local client = loaded.client
		client.equipmentSets[3] = { name = "Fishing", items = { [16] = 6256 } }
		client.equipmentSets[5] = { name = "Pagle Previous", items = {} }
		fake.login()
		fake.fireGameEvent("PLAYER_LOGIN")
		local swap = rowOf(fake, "Swap gear")

		assert.is_false(swap.isEnabled())
		rowOf(fake, "Fishing set").set(3)
		assert.is_true(swap.isEnabled())
		rowOf(fake, "Fishing set").set(-1)
		assert.is_false(swap.isEnabled())
	end)

	it("greys the Fishing set and its button out while restricted (QOL-R41)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()
		local set = rowOf(fake, "Fishing set")
		local save = rowOf(fake, "Save what I'm wearing as my fishing set")

		fake.setRestricted(true)
		assert.is_false(set.isEnabled())
		assert.is_false(save.isEnabled())
		fake.setRestricted(false)
		assert.is_true(set.isEnabled())
		assert.is_true(save.isEnabled())
	end)

	it("offers Off, Best I have and Only this one for Lures (SET-R20, QOL-R50)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		assert.are.same({
			{ value = "off", label = "Off" },
			{ value = "best", label = "Best I have" },
			{ value = "one", label = "Only this one" },
		}, rowOf(fake, "Lures").options())
	end)

	it("offers the lure table's six items for Lure, by their names from C_Item (SET-R20, QOL-R54)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		fake.login()

		-- The fake client has every lure's enUS name cached.
		assert.are.same({
			{ value = 6529, label = "Shiny Bauble" },
			{ value = 6530, label = "Nightcrawlers" },
			{ value = 6811, label = "Aquadynamic Fish Lens" },
			{ value = 6532, label = "Bright Baubles" },
			{ value = 7307, label = "Flesh Eating Worm" },
			{ value = 6533, label = "Aquadynamic Fish Attractor" },
		}, rowOf(fake, "Lure").options())

		-- A name the client hasn't loaded yet shows as its item ID and is asked for, then read again the next time the
		-- list opens.
		local requested = {}
		loaded.env.C_Item.RequestLoadItemDataByID = function(itemID)
			requested[#requested + 1] = itemID
		end
		loaded.client.itemNames[6811] = nil
		assert.are.same({ value = 6811, label = "Item 6811" }, rowOf(fake, "Lure").options()[3])
		assert.are.same({ 6811 }, requested)
		loaded.client.itemNames[6811] = "Aquadynamic Fish Lens"
		assert.are.same({ value = 6811, label = "Aquadynamic Fish Lens" }, rowOf(fake, "Lure").options()[3])
	end)

	it("gives Lures qol.md's tooltip, and the defaults Best I have and Shiny Bauble (SET-R20, QOL-R50)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		local lures = rowOf(fake, "Lures")
		local lure = rowOf(fake, "Lure")

		-- qol.md › Settings › Tooltips, word for word; it gives Lure none.
		assert.are.equal("A press before a cast applies a lure when none is on.", lures.tooltip)
		assert.is_nil(lure.tooltip)
		assert.are.equal("best", lures.default)
		assert.are.equal(6529, lure.default)
		-- A new PagleQoLDB starts at the defaults.
		assert.are.equal("best", lures.get())
		assert.are.equal(6529, lure.get())
	end)

	it("stores both in profile.lures, as QoL's lure logic reads them (qol.md › Data, QOL-R50, QOL-R51)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		fake.login()

		rowOf(fake, "Lures").set("one")
		rowOf(fake, "Lure").set(6532)

		local stored = loaded.env.PagleQoLDB.profiles.Default.lures
		assert.are.same({ mode = "one", item = 6532 }, stored)
		assert.are.equal("one", rowOf(fake, "Lures").get())
		assert.are.equal(6532, rowOf(fake, "Lure").get())
		-- With every lure available, Only this one picks Bright Baubles, where Best I have would pick the Attractor.
		local function always()
			return true
		end
		assert.are.equal(6532, loaded.ns.ChooseLure(stored.mode, stored.item, always))
	end)

	it("greys Lure out unless Lures is Only this one, keeping its value (SET-R20, SET-R31, QOL-R50)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()
		local lures = rowOf(fake, "Lures")
		local lure = rowOf(fake, "Lure")
		lure.set(6533)

		assert.is_false(lure.isEnabled())
		lures.set("one")
		assert.is_true(lure.isEnabled())
		lures.set("off")
		assert.is_false(lure.isEnabled())
		assert.are.equal(6533, lure.get())

		assert.is_nil(lures.isEnabled)
	end)

	it("gives Open clams between Casts its tooltip and default on, in profile.clams (SET-R20, QOL-R56)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		fake.login()
		local clams = rowOf(fake, "Open clams between Casts")

		-- qol.md › Settings › Tooltips, word for word.
		assert.are.equal("One clam per press, never during a cast.", clams.tooltip)
		assert.is_true(clams.default)
		assert.is_true(clams.get())
		assert.is_nil(clams.isEnabled)

		clams.set(false)
		assert.is_false(loaded.env.PagleQoLDB.profiles.Default.clams)
		assert.is_false(clams.get())
	end)

	it("gives the While you fish checkboxes qol.md's tooltips and defaults (SET-R20, qol.md › Data)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		local audio = rowOf(fake, "Fishing audio mix")
		local background = rowOf(fake, "Keep sound when the game is in the background")
		local autoLoot = rowOf(fake, "Auto-loot while fishing")

		-- qol.md › Settings › Tooltips, word for word; it gives the background option none.
		assert.are.equal(
			"While you fish: effects at full; music, ambience and dialog muted; master untouched. Put back afterwards.",
			audio.tooltip
		)
		assert.is_nil(background.tooltip)
		assert.are.equal("Only while you fish. Skipped if you already have auto-loot on.", autoLoot.tooltip)
		assert.is_true(audio.default)
		assert.is_false(background.default)
		assert.is_true(autoLoot.default)
		-- A new PagleQoLDB starts at the defaults.
		assert.is_true(audio.get())
		assert.is_false(background.get())
		assert.is_true(autoLoot.get())
	end)

	it("stores the three in profile.audio and profile.autoLoot (qol.md › Data)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		fake.login()

		rowOf(fake, "Fishing audio mix").set(false)
		rowOf(fake, "Keep sound when the game is in the background").set(true)
		rowOf(fake, "Auto-loot while fishing").set(false)

		local profile = loaded.env.PagleQoLDB.profiles.Default
		assert.are.same({ on = false, background = true }, profile.audio)
		assert.is_false(profile.autoLoot)
		assert.is_false(rowOf(fake, "Fishing audio mix").get())
		assert.is_true(rowOf(fake, "Keep sound when the game is in the background").get())
		assert.is_false(rowOf(fake, "Auto-loot while fishing").get())
	end)

	it("greys the background option out while the audio mix is off, keeping its value (SET-R20, SET-R31)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()
		local audio = rowOf(fake, "Fishing audio mix")
		local background = rowOf(fake, "Keep sound when the game is in the background")
		background.set(true)

		assert.is_true(background.isEnabled())
		audio.set(false)
		assert.is_false(background.isEnabled())
		assert.is_true(background.get())
		audio.set(true)
		assert.is_true(background.isEnabled())

		assert.is_nil(audio.isEnabled)
		assert.is_nil(rowOf(fake, "Auto-loot while fishing").isEnabled)
	end)

	it("registers no Fishing page while QoL is inert (SET-R20, CORE-R13, CORE-R42)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_QoL.metadata["X-Pagle-API"] = "2"
		fake.load("Pagle_QoL")

		fake.login()

		assert.is_nil(fake.settingsPage("fishing"))
	end)

	it("binds the key row to PAGLE_FISHING_KEY with qol.md's tooltip, under Cast with (SET-R20)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		local castWith = rowOf(fake, "Cast with")
		local key = rowOf(fake, "Fishing key")

		assert.are.equal("PAGLE_FISHING_KEY", key.binding)
		-- qol.md › Settings › Tooltips, word for word.
		assert.are.equal(
			"Each press does the next single thing: cast, reel, or a lure, gear or clam when needed.",
			key.tooltip
		)
		assert.are.equal("input", castWith.id)
		assert.are.equal("input", key.parent)
	end)

	it("offers Fishing key, Double right-click and Both for Cast with, with its tooltip (SET-R20, QOL-R12)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		local castWith = rowOf(fake, "Cast with")

		assert.are.same({
			{ value = "key", label = "Fishing key" },
			{ value = "click", label = "Double right-click" },
			{ value = "both", label = "Both" },
		}, castWith.options())
		-- qol.md › Settings › Tooltips, word for word.
		assert.are.equal("Also on the compartment menu and /pagle qol input.", castWith.tooltip)
		assert.are.equal("both", castWith.default)
		assert.are.equal("both", castWith.get())
		assert.is_nil(castWith.isEnabled)
	end)

	it("stores Cast with in profile.input, as the menu and /pagle qol do (qol.md › Data, QOL-R18)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL")
		fake.login()
		local castWith = rowOf(fake, "Cast with")

		castWith.set("click")
		assert.are.equal("click", loaded.env.PagleQoLDB.profiles.Default.input)
		assert.are.equal("Input: Double-click", fake.menu()[1].label)

		fake.slash("qol input key")
		assert.are.equal("key", castWith.get())
	end)

	it("greys the key row out under Double right-click only (SET-R20, QOL-R12)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()
		local castWith = rowOf(fake, "Cast with")
		local key = rowOf(fake, "Fishing key")

		local enabled = {}
		for _, input in ipairs({ "key", "click", "both" }) do
			castWith.set(input)
			enabled[input] = key.isEnabled()
		end

		assert.are.same({ key = true, click = false, both = true }, enabled)
	end)
end)

describe("QoL's Fishing page with Core", function()
	-- Loads Core and QoL with the client knowing QoL's Bindings.xml, then logs in; returns the Fishing page.
	local function fishingPage()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		loaded.client.bindings = { "MOVEFORWARD", "PAGLE_FISHING_KEY", "PAGLE_SWAP_GEAR" }
		loaded.client.fire("PLAYER_LOGIN")
		return loaded, assert(loaded.client.settings.category("Fishing"))
	end

	it(
		"registers under Pagle as a native header, Cast with and the Fishing key's binding row under it (SET-R5, SET-R20)",
		function()
			local loaded, fishing = fishingPage()

			local header, castWith, key = unpack(fishing.layout.initializers)
			assert.are.equal(loaded.client.settings.category("Pagle"), fishing.parent)
			assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
			assert.are.equal("Casting", header:GetName())
			assert.are.equal("SettingsDropdownControlTemplate", castWith.template)
			assert.are.equal("Cast with", castWith:GetSetting():GetName())
			assert.are.equal("Also on the compartment menu and /pagle qol input.", castWith:GetTooltip())
			assert.are.equal("KeyBindingFrameBindingTemplate", key.template)
			assert.are.equal(2, key:GetData().bindingIndex)
			assert.are.same({ "FISHING KEY" }, key.searchTags)
			assert.are.equal(castWith, key:GetParentInitializer())

			-- Greyed out under Double right-click only (SET-R20).
			assert.is_true(key:EvaluateModifyPredicates())
			castWith:GetSetting():SetValue("click")
			assert.is_false(key:EvaluateModifyPredicates())
			castWith:GetSetting():SetValue("key")
			assert.is_true(key:EvaluateModifyPredicates())
		end
	)

	-- The Fishing page's native row by its label.
	local function initializerOf(fishing, label)
		for _, initializer in ipairs(fishing.layout.initializers) do
			local setting = initializer:GetSetting()
			if setting and setting:GetName() == label or initializer:GetName() == label then
				return initializer
			end
		end
		error("no row " .. label)
	end

	-- Presses the Fishing page's Defaults button: every setting registered on it goes back to its default (SET-R60),
	-- skipping one with no default, as Blizzard's SettingMixin:SetValueToDefault does (Gethe/wow-ui-source branch
	-- forever, Blizzard_Settings_Shared/Blizzard_Setting.lua).
	local function pressDefaults(loaded, fishing)
		for _, setting in pairs(loaded.client.settings.variables) do
			if setting.category == fishing and setting:GetDefaultValue() ~= nil then
				setting:SetValue(setting:GetDefaultValue())
			end
		end
	end

	it(
		"restores Cast with to Both with Defaults and leaves the Fishing key's binding alone (SET-R21, SET-R60)",
		function()
			local loaded, fishing = fishingPage()
			local castWith = initializerOf(fishing, "Cast with"):GetSetting()
			castWith:SetValue("click")

			pressDefaults(loaded, fishing)

			assert.are.equal("both", castWith:GetValue())
			assert.are.equal("both", loaded.env.PagleQoLDB.profiles.Default.input)
			-- The key row under it carries no setting, only its binding index, so Defaults has nothing of it to restore.
			local key = fishing.layout.initializers[3]
			assert.are.equal("KeyBindingFrameBindingTemplate", key.template)
			assert.is_nil(key:GetSetting())
		end
	)

	it("registers Gear as a header, a native dropdown, a button and Swap gear's binding row (SET-R20)", function()
		local loaded, fishing = fishingPage()

		local header = initializerOf(fishing, "Gear")
		local set = initializerOf(fishing, "Fishing set")
		assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
		assert.are.equal("SettingsDropdownControlTemplate", set.template)
		assert.are.equal(
			"The Fishing key puts it on when no pole is in hand. Double-click skips this.",
			set:GetTooltip()
		)
		-- The rows after the dropdown hang under it: the button, then Swap gear's binding row.
		local initializers = fishing.layout.initializers
		local at
		for i, initializer in ipairs(initializers) do
			if initializer == set then
				at = i
			end
		end
		local save, swap = initializers[at + 1], initializers[at + 2]
		assert.are.equal("SettingButtonControlTemplate", save.template)
		assert.are.equal(set, save:GetParentInitializer())
		assert.are.equal("KeyBindingFrameBindingTemplate", swap.template)
		assert.are.equal(3, swap:GetData().bindingIndex)
		assert.are.same({ "SWAP GEAR" }, swap.searchTags)
		assert.are.equal(set, swap:GetParentInitializer())
		-- Greyed out while no set is chosen.
		assert.is_false(swap:EvaluateModifyPredicates())
		loaded.client.equipmentSets[0] = { name = "Fishing", items = { [16] = 6256 } }
		set:GetSetting():SetValue(0)
		assert.is_true(swap:EvaluateModifyPredicates())
	end)

	it("leaves the fishing set alone with Defaults (SET-R21, SET-R60)", function()
		local loaded, fishing = fishingPage()
		loaded.client.equipmentSets[0] = { name = "Fishing", items = { [16] = 6256 } }
		local set = initializerOf(fishing, "Fishing set"):GetSetting()
		set:SetValue(0)

		pressDefaults(loaded, fishing)

		assert.is_nil(set:GetDefaultValue())
		assert.are.equal(0, set:GetValue())
		assert.are.same({ setID = 0, name = "Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
	end)

	it("registers Lures and clams as a header and two native dropdowns, greying as SET-R20 says", function()
		local _, fishing = fishingPage()

		local header = initializerOf(fishing, "Lures and clams")
		local lures = initializerOf(fishing, "Lures")
		local lure = initializerOf(fishing, "Lure")
		assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
		assert.are.equal("SettingsDropdownControlTemplate", lures.template)
		assert.are.equal("SettingsDropdownControlTemplate", lure.template)
		assert.are.equal("A press before a cast applies a lure when none is on.", lures:GetTooltip())
		assert.is_nil(lures:GetParentInitializer())
		assert.are.equal(lures, lure:GetParentInitializer())
		-- The native list's labels, read as it opens: Lure's come from C_Item (QOL-R54).
		local labels = {}
		for i, option in ipairs(lures:GetData().options()) do
			labels[i] = option.label
		end
		assert.are.same({ "Off", "Best I have", "Only this one" }, labels)
		assert.are.equal("Bright Baubles", lure:GetData().options()[4].label)

		-- Live only for Only this one (QOL-R50).
		assert.is_false(lure:EvaluateModifyPredicates())
		lures:GetSetting():SetValue("one")
		assert.is_true(lure:EvaluateModifyPredicates())
		lures:GetSetting():SetValue("off")
		assert.is_false(lure:EvaluateModifyPredicates())
	end)

	it("restores Lures and Lure with Defaults (SET-R21, SET-R60, QOL-R50)", function()
		local loaded, fishing = fishingPage()
		local lures = initializerOf(fishing, "Lures"):GetSetting()
		local lure = initializerOf(fishing, "Lure"):GetSetting()
		lures:SetValue("one")
		lure:SetValue(6533)

		pressDefaults(loaded, fishing)

		assert.are.equal("best", lures:GetValue())
		assert.are.equal(6529, lure:GetValue())
		assert.are.same({ mode = "best", item = 6529 }, loaded.env.PagleQoLDB.profiles.Default.lures)
	end)

	it("registers Open clams between Casts as a native checkbox under Lures and clams, restored by Defaults", function()
		local loaded, fishing = fishingPage()
		local initializer = initializerOf(fishing, "Open clams between Casts")
		local clams = initializer:GetSetting()
		assert.are.equal("SettingsCheckboxControlTemplate", initializer.template)
		assert.is_nil(initializer:GetParentInitializer())
		assert.are.equal("One clam per press, never during a cast.", initializer:GetTooltip())
		clams:SetValue(false)
		assert.is_false(loaded.env.PagleQoLDB.profiles.Default.clams)

		pressDefaults(loaded, fishing)

		-- SET-R21: Defaults restores it (QOL-R56).
		assert.is_true(clams:GetValue())
		assert.is_true(loaded.env.PagleQoLDB.profiles.Default.clams)
	end)

	it("registers While you fish as a header and three native checkboxes, greying as SET-R20 says", function()
		local _, fishing = fishingPage()

		local header = initializerOf(fishing, "While you fish")
		local audio = initializerOf(fishing, "Fishing audio mix")
		local background = initializerOf(fishing, "Keep sound when the game is in the background")
		local autoLoot = initializerOf(fishing, "Auto-loot while fishing")
		assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
		for _, row in ipairs({ audio, background, autoLoot }) do
			assert.are.equal("SettingsCheckboxControlTemplate", row.template)
		end
		assert.are.equal(audio, background:GetParentInitializer())
		assert.is_nil(autoLoot:GetParentInitializer())

		assert.is_true(background:EvaluateModifyPredicates())
		audio:GetSetting():SetValue(false)
		assert.is_false(background:EvaluateModifyPredicates())
	end)

	it("restores the three checkboxes with Defaults and leaves the binding alone (SET-R21, SET-R60)", function()
		local loaded, fishing = fishingPage()
		local audio = initializerOf(fishing, "Fishing audio mix"):GetSetting()
		local background = initializerOf(fishing, "Keep sound when the game is in the background"):GetSetting()
		local autoLoot = initializerOf(fishing, "Auto-loot while fishing"):GetSetting()
		audio:SetValue(false)
		background:SetValue(true)
		autoLoot:SetValue(false)

		pressDefaults(loaded, fishing)

		assert.is_true(audio:GetValue())
		assert.is_false(background:GetValue())
		assert.is_true(autoLoot:GetValue())
		-- The key row carries no setting, only its binding index, so Defaults has nothing of it to restore.
		for _, initializer in ipairs(fishing.layout.initializers) do
			if initializer.template == "KeyBindingFrameBindingTemplate" then
				assert.is_nil(initializer:GetSetting())
			end
		end
	end)

	it("isn't registered with QoL Off (SET-R20, SET-R4, CORE-R42)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		loaded.client.addons.Pagle_QoL =
			{ enabled = false, loaded = false, metadata = { ["X-Pagle-API"] = "1", Version = "1.2.3" } }

		loaded.client.fire("PLAYER_LOGIN")

		assert.is_table(loaded.client.settings.category("Pagle"))
		assert.is_nil(loaded.client.settings.category("Fishing"))
	end)
end)
