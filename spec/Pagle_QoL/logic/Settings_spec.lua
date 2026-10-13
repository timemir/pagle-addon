-- QoL's rows on Core's Fishing page in M1: the Casting header and the Fishing key (qol.md › Settings, SET-R20,
-- SET-R21, CORE-R42).

describe("QoL's Fishing page with FakePagle", function()
	it(
		"holds exactly the Casting header and the Fishing key, in that order, with QoL On (SET-R20, CORE-R42)",
		function()
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
			}, rows)
		end
	)

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
		assert.are.equal(2, #fishing.layout.initializers)
		assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
		assert.are.equal("Casting", header:GetName())
		assert.are.equal("KeyBindingFrameBindingTemplate", key.template)
		assert.are.equal(2, key:GetData().bindingIndex)
		assert.are.same({ "FISHING KEY" }, key.searchTags)
		assert.is_nil(key:GetParentInitializer())
		assert.is_true(key:EvaluateModifyPredicates())
	end)

	it("gives the Defaults button nothing to restore, so the binding is left alone (SET-R21, SET-R60)", function()
		local loaded, fishing = fishingPage()

		-- Defaults restores the page's registered settings; the key row carries none, only its binding index.
		for _, initializer in ipairs(fishing.layout.initializers) do
			assert.is_nil(initializer:GetSetting())
		end
		for _, setting in pairs(loaded.client.settings.variables) do
			assert.are_not.equal(fishing, setting.category)
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
