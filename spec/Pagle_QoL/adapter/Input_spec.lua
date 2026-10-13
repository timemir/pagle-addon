-- Input's three places: the compartment entry (QOL-R16, CORE-R52), `/pagle qol` (QOL-R17, CORE-R62) and what a
-- change does to the Fishing key (QOL-R12, QOL-R18), driven through FakePagle's menu and slash command, and once
-- through Core's own.

local CAST = "SPELL Fishing"

-- QoL loaded against FakePagle and logged in, with F bound to the Fishing key.
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start()
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- QoL's compartment entry, as the menu would open now: its first entry, since QoL has no views (QOL-R2).
---@param fake FakePagle
---@return PagleMenuEntry
local function inputEntry(fake)
	return fake.menu()[1]
end

describe("Input", function()
	it("is Both in a new PagleQoLDB (QOL-R12, qol.md › Data)", function()
		local _, client, loaded = start()

		assert.are.equal("both", loaded.ns.db.profile.input)
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	describe("on the compartment menu", function()
		it("reads the current Input each time the menu opens, before Settings (QOL-R16, CORE-R50, CORE-R52)", function()
			local fake, _, loaded = start()

			local labels = {}
			for i, entry in ipairs(fake.menu()) do
				labels[i] = entry.label
			end
			assert.are.same({ "Input: Both", "Settings" }, labels)

			loaded.ns.db.profile.input = "click"
			assert.are.equal("Input: Double-click", inputEntry(fake).label)
		end)

		it("cycles Both, Fishing key, Double-click and Both, storing each in profile.input (QOL-R16)", function()
			local fake, _, loaded = start()

			local seen = {}
			for i = 1, 3 do
				inputEntry(fake).onClick()
				seen[i] = { inputEntry(fake).label, loaded.env.PagleQoLDB.profiles.Default.input }
			end

			assert.are.same({
				{ "Input: Fishing key", "key" },
				{ "Input: Double-click", "click" },
				{ "Input: Both", "both" },
			}, seen)
		end)

		it(
			"disarms the key at once when the cycle reaches Double-click, and arms it again at Both (QOL-R18)",
			function()
				local fake, client = start()

				inputEntry(fake).onClick() -- Fishing key
				assert.are.equal(CAST, client.overrideAction("F"))
				inputEntry(fake).onClick() -- Double-click
				assert.is_nil(client.overrideAction("F"))
				inputEntry(fake).onClick() -- Both
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		)
	end)

	describe("through /pagle qol", function()
		it("sets Double-click with input click, prints its line and disarms the key (QOL-R17, QOL-R12)", function()
			local fake, client, loaded = start()

			fake.slash("qol input click")

			assert.are.same({ "Pagle: cast with a double right-click." }, loaded.printed)
			assert.are.equal("click", loaded.ns.db.profile.input)
			assert.is_nil(client.overrideAction("F"))
		end)

		it("arms the key again with input key or input both (QOL-R17, QOL-R18)", function()
			for _, input in ipairs({ "key", "both" }) do
				local fake, client = start()
				fake.slash("qol input click")

				fake.slash("QOL Input " .. input:upper())

				assert.are.equal(CAST, client.overrideAction("F"))
			end
		end)

		it("opens the Fishing page with no argument (QOL-R17, CORE-R43)", function()
			local fake = start()

			fake.slash("qol")

			assert.are.same({ "fishing" }, fake.openedSettings)
		end)

		it("prints the usage line for anything else, changing nothing (QOL-R17)", function()
			local fake, client, loaded = start()

			fake.slash("qol foo")

			assert.are.same({ "Pagle: /pagle qol input key|click|both" }, loaded.printed)
			assert.are.equal("both", loaded.ns.db.profile.input)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("is listed in /pagle help with its help text (QOL-R2, CORE-R60)", function()
			local fake = start()

			fake.slash("help")

			assert.are.equal("/pagle qol: input key|click|both: choose how you cast", fake.printed[#fake.printed])
		end)
	end)

	describe("in combat", function()
		it("is saved at once and takes effect when restriction ends (QOL-R18, QOL-R32)", function()
			local fake, client, loaded = start()
			fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			fake.setRestricted(true)
			local inLockdown = true
			loaded.env.InCombatLockdown = function()
				return inLockdown
			end

			-- Every override call raises under the fake's lockdown, so none may be made here.
			fake.slash("qol input key")
			inputEntry(fake).onClick() -- Double-click
			assert.are.equal("click", loaded.ns.db.profile.input)

			inLockdown = false
			fake.setRestricted(false)
			assert.is_nil(client.overrideAction("F"))
		end)
	end)
end)

describe("Input with Core", function()
	it(
		"cycles from Core's compartment menu and is set by Core's /pagle (CORE-R52, CORE-R62, QOL-R16, QOL-R17)",
		function()
			local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
			local client = loaded.client
			client.boundKeys.PAGLE_FISHING_KEY = { "F" }
			client.fire("PLAYER_LOGIN")

			-- Clicks Pagle in the Addon Compartment; Core opens its menu on the next frame (CORE-R50).
			local function openMenu()
				local func = assert(client.addons.Pagle.metadata).AddonCompartmentFunc
				loaded.env[func]("Pagle", "LeftButton")
				client.runTimers()
				return client.menus[#client.menus]
			end

			local menu = openMenu()
			assert.are.same({ "Input: Both", "Settings" }, menu.texts())
			menu.click("Input: Both")
			assert.are.same({ "Input: Fishing key", "Settings" }, openMenu().texts())

			loaded.env.SlashCmdList.PAGLE("qol input click")
			assert.are.equal("Pagle: cast with a double right-click.", loaded.printed[#loaded.printed])
			assert.is_nil(client.overrideAction("F"))
			assert.are.same({ "Input: Double-click", "Settings" }, openMenu().texts())
		end
	)
end)
