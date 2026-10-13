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

		it("after a /reload in combat, has no frame, button or override until restriction ends (QOL-R33)", function()
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
			assert.is_nil(loaded.env.PagleQoLActionButton)
			assert.is_nil(loaded.env.PagleQoLGearButton)
			assert.are.same({}, client.bindingCalls)

			setLockdown(loaded, false)
			fake.setRestricted(false)
			-- The override owner, then PagleQoLActionButton and PagleQoLGearButton (QOL-R24), then the double-click's
			-- BUTTON2 owner (QOL-R13).
			assert.are.equal(libFrames + 4, #client.frames)
			assert.are.equal(loaded.env.PagleQoLActionButton, client.frames[libFrames + 2])
			assert.are.equal(loaded.env.PagleQoLGearButton, client.frames[libFrames + 3])
			assert.are.equal(CAST, client.overrideAction("F"))
			assert.is_function(client.frames[libFrames + 1].scripts.OnUpdate) -- the tick (QOL-R25)
			-- The BUTTON2 owner: unnamed, and running OnUpdate only while a double-click window is open.
			local clickOwner = client.frames[libFrames + 4]
			assert.are.same({ "Frame", nil }, { clickOwner.kind, clickOwner.name })
			assert.is_nil(clickOwner.scripts.OnUpdate)
			client.mainHand = 6256 -- a Fishing Pole
			client.click("RightButton")
			assert.are.equal(CAST, client.overrideAction("BUTTON2"))
			assert.is_function(clickOwner.scripts.OnUpdate)
		end)
	end)

	describe("gear", function()
		local FISHING_POLE, SWORD = 6256, 25
		local FISHING, PREVIOUS = 3, 5
		local GEAR = "CLICK PagleQoLGearButton:LeftButton"
		-- The client calls outside C_EquipmentSet that change what the player wears. C_EquipmentSet's are in the fake
		-- client's equipmentSetCalls (spec/support/fake_game.lua).
		local EQUIP_CALLS = {
			"EquipItemByName",
			"PickupInventoryItem",
			"EquipCursorItem",
			"AutoEquipCursorItem",
			"UseInventoryItem",
		}

		-- QoL with a swap to hand at every main hand: the set "Fishing" (a pole) chosen as the fishing set, and
		-- Pagle Previous (a sword). With no pole in hand the gear step is ready and Swap gear would swap to the fishing
		-- set; with the pole in hand the set is fully worn and Swap gear would swap back.
		---@param mainHand integer?
		---@return FakePagle fake
		---@return FakeClient client
		---@return LoadedAddon loaded
		---@return string[] equipCalls the EQUIP_CALLS made, from now on
		local function startWithSet(mainHand)
			local fake = newFakePagle()
			local loaded = fake.load("Pagle_QoL")
			local client = loaded.client
			client.boundKeys.PAGLE_FISHING_KEY = { "F" }
			client.mainHand = mainHand
			client.equipmentSets[FISHING] = { name = "Fishing", items = { [16] = FISHING_POLE } }
			client.equipmentSets[PREVIOUS] = { name = "Pagle Previous", items = { [16] = SWORD } }
			loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
			fake.login()
			fake.fireGameEvent("PLAYER_LOGIN")
			local equipCalls = {}
			for _, name in ipairs(EQUIP_CALLS) do
				loaded.env[name] = function()
					equipCalls[#equipCalls + 1] = name
				end
			end
			return fake, client, loaded, equipCalls
		end

		-- What the Fishing key arms with this main hand and nothing else going on.
		---@param mainHand integer?
		---@return string
		local function armedWith(mainHand)
			return mainHand == FISHING_POLE and CAST or GEAR
		end

		-- What Swap gear calls with this main hand, out of restriction (QOL-R44, QOL-R45).
		---@param mainHand integer?
		---@return string[]
		local function swapGearCalls(mainHand)
			if mainHand == FISHING_POLE then
				return { "use " .. PREVIOUS }
			end
			return { "clear ignored", "save " .. PREVIOUS, "use " .. FISHING }
		end

		it("is never swapped by combat, with the pole in hand or not (QOL-R34, QOL-R47, QOL-R93)", function()
			for _, mainHand in ipairs({ FISHING_POLE, SWORD, false }) do
				local fake, client, loaded, equipCalls = startWithSet(mainHand or nil)
				assert.are.equal(armedWith(mainHand or nil), client.overrideAction("F"))

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

				assert.are.same({}, equipCalls)
				assert.are.same({}, client.equipmentSetCalls)
				assert.are.equal(armedWith(mainHand or nil), client.overrideAction("F"))
			end
		end)

		it(
			"isn't swapped by a press while restricted, even one an override kept through lockdown sends (QOL-R34, QOL-R47)",
			function()
				for _, mainHand in ipairs({ FISHING_POLE, SWORD, false }) do
					for _, window in ipairs({ "combat", "addon restriction" }) do
						local fake, client, loaded, equipCalls = startWithSet(mainHand or nil)
						if window == "combat" then
							-- Lockdown came first, so the overrides stay until restriction ends (QOL-R31).
							setLockdown(loaded, true)
							fake.fireGameEvent("PLAYER_REGEN_DISABLED")
							fake.setRestricted(true)
							assert.are.equal(armedWith(mainHand or nil), client.overrideAction("F"))
						else
							fake.setRestricted(true)
						end

						-- The gear step's press as a kept override sends it, then Swap gear's Bindings.xml body.
						loaded.env.PagleQoLGearButton:Click()
						loaded.env.PagleQoL_SwapGear()
						client.update(1)

						assert.are.same({}, equipCalls)
						assert.are.same({}, client.equipmentSetCalls)

						-- Out of restriction, the same press swaps: the set-up above had a swap to hand.
						setLockdown(loaded, false)
						fake.setRestricted(false)
						loaded.env.PagleQoL_SwapGear()
						assert.are.same(swapGearCalls(mainHand or nil), client.equipmentSetCalls)
					end
				end
			end
		)
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
