-- The Fishing key in combat and restriction (QOL-R30–R34, QOL-R93): it steps aside before lockdown, changes
-- nothing while restricted, and comes back when restriction ends. Driven through FakePagle, with the fake client's
-- lockdown (`loaded.env.InCombatLockdown`), under which every override call raises as the client blocks it.

local CAST, REEL = "SPELL Fishing", "INTERACTTARGET"

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

-- Sets the fake client's combat lockdown.
---@param loaded LoadedAddon
---@param inLockdown boolean
local function setLockdown(loaded, inLockdown)
	loaded.env.InCombatLockdown = function()
		return inLockdown
	end
end

-- Whether every override call since the last reset was a clear: nothing was armed.
---@param client FakeClient
---@return boolean
local function onlyClears(client)
	for _, call in ipairs(client.bindingCalls) do
		if call ~= "clear" then
			return false
		end
	end
	return true
end

describe("The Fishing key in combat", function()
	describe("when restriction starts", function()
		it("disarms at PLAYER_REGEN_DISABLED, before lockdown, and arms nothing there (QOL-R31)", function()
			local fake, client = start()
			fake.fire("CastStarted")
			client.bindingCalls = {}

			fake.fireGameEvent("PLAYER_REGEN_DISABLED")

			assert.is_nil(client.overrideAction("F"))
			assert.are.same({ "clear" }, client.bindingCalls)
		end)

		it(
			"disarms at RestrictionChanged(true) when that comes first, as an addon restriction does (QOL-R31)",
			function()
				local fake, client = start()
				client.bindingCalls = {}

				fake.setRestricted(true)

				assert.is_nil(client.overrideAction("F"))
				assert.are.same({ "clear" }, client.bindingCalls)
			end
		)

		it(
			"arms nothing at either, in combat's order: PLAYER_REGEN_DISABLED, then RestrictionChanged(true) (QOL-R31)",
			function()
				local fake, client, loaded = start()
				client.bindingCalls = {}

				fake.fireGameEvent("PLAYER_REGEN_DISABLED")
				fake.setRestricted(true)
				setLockdown(loaded, true)
				fake.fire("CastStarted")
				fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
				client.update(1)

				assert.is_nil(client.overrideAction("F"))
				assert.is_true(onlyClears(client))
			end
		)

		it(
			"keeps the overrides when lockdown has already started, until restriction ends (QOL-R31, QOL-R32)",
			function()
				local fake, client, loaded = start()
				client.bindingCalls = {}

				setLockdown(loaded, true)
				fake.fireGameEvent("PLAYER_REGEN_DISABLED")
				fake.setRestricted(true)
				fake.fire("CastStarted")
				client.update(1)
				assert.are.equal(CAST, client.overrideAction("F"))
				assert.are.same({}, client.bindingCalls)

				setLockdown(loaded, false)
				fake.setRestricted(false)
				assert.are.equal(REEL, client.overrideAction("F"))
			end
		)
	end)

	describe("when restriction ends", function()
		-- Combat as the client runs it: PLAYER_REGEN_DISABLED before lockdown, then Core's RestrictionChanged(true).
		---@param fake FakePagle
		---@param loaded LoadedAddon
		local function enterCombat(fake, loaded)
			fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			fake.setRestricted(true)
			setLockdown(loaded, true)
		end

		it("re-evaluates and arms at RestrictionChanged(false) (QOL-R32)", function()
			local fake, client, loaded = start()
			enterCombat(fake, loaded)
			client.bindingCalls = {}

			setLockdown(loaded, false)
			fake.setRestricted(false)

			assert.are.equal(CAST, client.overrideAction("F"))
			assert.are.same({ "clear", "set F " .. CAST }, client.bindingCalls)
		end)

		it("arms for the game as it is then, with no queue of what changed in combat (QOL-R25, QOL-R32)", function()
			local fake, client, loaded = start()
			enterCombat(fake, loaded)

			client.boundKeys.PAGLE_FISHING_KEY = { "G" }
			fake.fireGameEvent("UPDATE_BINDINGS")
			fake.fireGameEvent("LOOT_READY", false)
			fake.fireGameEvent("LOOT_CLOSED")
			fake.fire("CastStarted")
			client.bindingCalls = {}
			setLockdown(loaded, false)
			fake.setRestricted(false)

			assert.are.same({ "clear", "set G " .. REEL }, client.bindingCalls)
			assert.is_nil(client.overrideAction("F"))
		end)

		it("waits for RestrictionChanged(false), not for combat's own end (QOL-R30, QOL-R32)", function()
			local fake, client, loaded = start()
			fake.setRestricted(true) -- an addon restriction, before combat
			fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			setLockdown(loaded, true)
			client.bindingCalls = {}

			-- Combat ends while the addon restriction holds: Core stays restricted and fires nothing.
			setLockdown(loaded, false)
			fake.fireGameEvent("PLAYER_REGEN_ENABLED")
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			client.update(1)
			assert.is_nil(client.overrideAction("F"))
			assert.are.same({}, client.bindingCalls)

			fake.setRestricted(false)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("from a load", function()
		it("first arms at PLAYER_LOGIN, never earlier (QOL-R33)", function()
			local fake = newFakePagle()
			local client = fake.load("Pagle_QoL").client
			client.boundKeys.PAGLE_FISHING_KEY = { "F" }

			-- The client loads bindings, and may fight, before PLAYER_LOGIN.
			fake.fireGameEvent("UPDATE_BINDINGS")
			fake.setRestricted(true)
			fake.setRestricted(false)
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			fake.login()
			client.update(1)
			assert.are.same({}, client.bindingCalls)

			fake.fireGameEvent("PLAYER_LOGIN")
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("after a /reload in combat, has no frame or override until restriction ends (QOL-R33)", function()
			local fake = newFakePagle()
			fake.setRestricted(true)
			local loaded = fake.load("Pagle_QoL", { holdAddonLoaded = true })
			local client = loaded.client
			setLockdown(loaded, true)
			client.boundKeys.PAGLE_FISHING_KEY = { "F" }
			local libFrames = #client.frames -- the vendored libraries' own

			client.fire("ADDON_LOADED", "Pagle_QoL")
			fake.login()
			fake.fireGameEvent("PLAYER_LOGIN")
			fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			fake.fireGameEvent("UPDATE_BINDINGS")
			fake.fire("CastStarted")
			assert.are.equal(libFrames, #client.frames)
			assert.are.same({}, client.bindingCalls)

			setLockdown(loaded, false)
			fake.setRestricted(false)
			assert.are.equal(libFrames + 1, #client.frames)
			assert.are.equal(CAST, client.overrideAction("F"))
			assert.is_function(client.frames[libFrames + 1].scripts.OnUpdate) -- the tick (QOL-R25)
		end)
	end)

	describe("gear", function()
		-- The client calls that change what the player wears. M1 has no gear code; Track Q's swap (QOL-R44) may
		-- call one only on a press (QOL-R47), never because combat started or ended.
		local GEAR_CALLS = {
			"EquipItemByName",
			"PickupInventoryItem",
			"EquipCursorItem",
			"AutoEquipCursorItem",
			"UseInventoryItem",
			"C_EquipmentSet.UseEquipmentSet",
		}

		it("is never swapped by combat, with the pole in hand or not (QOL-R34, QOL-R93)", function()
			for _, mainHand in ipairs({ 6256, 25, false }) do
				local fake, client, loaded = start()
				client.mainHand = mainHand or nil
				local called = {}
				for _, name in ipairs(GEAR_CALLS) do
					local namespace, field = name:match("^(.-)%.(.+)$")
					local spy = function()
						called[#called + 1] = name
					end
					if namespace then
						loaded.env[namespace] = loaded.env[namespace] or {}
						loaded.env[namespace][field] = spy
					else
						loaded.env[name] = spy
					end
				end

				fake.fire("CastStarted")
				fake.fireGameEvent("PLAYER_REGEN_DISABLED")
				fake.setRestricted(true)
				setLockdown(loaded, true)
				fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
				fake.fire("CastEnded", "interrupted")
				fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
				client.update(1)
				setLockdown(loaded, false)
				fake.setRestricted(false)
				client.update(1)

				assert.are.same({}, called)
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		end)
	end)
end)

describe("The Fishing key in combat, with Core", function()
	it("steps aside at PLAYER_REGEN_DISABLED and comes back at PLAYER_REGEN_ENABLED (QOL-R31, QOL-R32)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.boundKeys.PAGLE_FISHING_KEY = { "F" }
		client.fire("PLAYER_LOGIN")
		client.bindingCalls = {}

		client.fire("PLAYER_REGEN_DISABLED")
		setLockdown(loaded, true)
		client.fire("LOOT_CLOSED")
		client.update(1)
		assert.is_nil(client.overrideAction("F"))
		assert.is_true(onlyClears(client))

		setLockdown(loaded, false)
		client.fire("PLAYER_REGEN_ENABLED")
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	it("after a /reload in combat, first arms when combat ends (QOL-R33)", function()
		-- In lockdown from the start, so Core reads the load as restricted at its ADDON_LOADED.
		local loaded = loadAddon(
			"Pagle_QoL",
			foreverWith({
				InCombatLockdown = function()
					return true
				end,
			})
		)
		local client = loaded.client
		client.boundKeys.PAGLE_FISHING_KEY = { "F" }

		client.fire("PLAYER_LOGIN")
		client.fire("UPDATE_BINDINGS")
		client.update(1)
		assert.are.same({}, client.bindingCalls)

		setLockdown(loaded, false)
		client.fire("PLAYER_REGEN_ENABLED")
		assert.are.equal(CAST, client.overrideAction("F"))
	end)
end)
