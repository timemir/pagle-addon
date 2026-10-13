-- QoL's rows on Core's Fishing page: the Casting header and the Fishing key (M1), and the While you fish rows (Track Q
-- step 4) (qol.md › Settings, SET-R20, SET-R21, CORE-R42).

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
			{ "QoL", "keybinding", "Fishing key", false },
			{ "QoL", "header", "While you fish", false },
			{ "QoL", "checkbox", "Fishing audio mix", false },
			{ "QoL", "checkbox", "Keep sound when the game is in the background", true },
			{ "QoL", "checkbox", "Auto-loot while fishing", false },
		}, rows)
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

	it("binds the key row to PAGLE_FISHING_KEY with qol.md's tooltip, no parent and no greying (SET-R20)", function()
		local fake = newFakePagle()
		fake.load("Pagle_QoL")
		fake.login()

		local key = assert(fake.settingsPage("fishing"))[2].setting

		assert.are.equal("PAGLE_FISHING_KEY", key.binding)
		-- qol.md › Settings › Tooltips, word for word.
		assert.are.equal(
			"Each press does the next single thing: cast, reel, or a lure, gear or clam when needed.",
			key.tooltip
		)
		assert.is_nil(key.parent)
		assert.is_nil(key.isEnabled)
	end)
end)

describe("QoL's Fishing page with Core", function()
	-- Loads Core and QoL with the client knowing QoL's Bindings.xml, then logs in; returns the Fishing page.
	local function fishingPage()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		loaded.client.bindings = { "MOVEFORWARD", "PAGLE_FISHING_KEY" }
		loaded.client.fire("PLAYER_LOGIN")
		return loaded, assert(loaded.client.settings.category("Fishing"))
	end

	it("registers under Pagle as a native header and the Fishing key's binding row (SET-R5, SET-R20)", function()
		local loaded, fishing = fishingPage()

		local header, key = unpack(fishing.layout.initializers)
		assert.are.equal(loaded.client.settings.category("Pagle"), fishing.parent)
		assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
		assert.are.equal("Casting", header:GetName())
		assert.are.equal("KeyBindingFrameBindingTemplate", key.template)
		assert.are.equal(2, key:GetData().bindingIndex)
		assert.are.same({ "FISHING KEY" }, key.searchTags)
		assert.is_nil(key:GetParentInitializer())
		assert.is_true(key:EvaluateModifyPredicates())
	end)

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

	-- Presses the Fishing page's Defaults button: every setting registered on it goes back to its default (SET-R60).
	local function pressDefaults(loaded, fishing)
		for _, setting in pairs(loaded.client.settings.variables) do
			if setting.category == fishing then
				setting:SetValue(setting:GetDefaultValue())
			end
		end
	end

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
