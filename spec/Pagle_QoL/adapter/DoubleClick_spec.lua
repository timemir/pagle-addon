-- The double-click (QOL-R13–R15, QOL-R24's BUTTON2 column, QOL-R31): a right double-click on the game world does what
-- the Fishing key would, through a short-lived priority override on BUTTON2. Driven through FakePagle and the fake
-- client's mouse (spec/support/fake_game.lua): `client.click` fires GLOBAL_MOUSE_DOWN and _UP, `client.nextFrame`
-- moves the clock on and runs a frame.

local FISHING_POLE, SWORD = 6256, 25
local CAST, REEL = "SPELL Fishing", "INTERACTTARGET"
local LURE = "CLICK PagleQoLActionButton:LeftButton"

-- QoL loaded against FakePagle and logged in, with F bound to the Fishing key and a fishing pole in hand.
-- `before(fake, client)` runs after the load and before PLAYER_LOGIN.
---@param before fun(fake: FakePagle, client: FakeClient)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	client.mainHand = FISHING_POLE
	if before then
		before(fake, client)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- What BUTTON2's override does now, or false with none.
---@param client FakeClient
---@return string|false
local function button2(client)
	return client.overrideAction("BUTTON2") or false
end

-- Sets the fake client's combat lockdown.
---@param loaded LoadedAddon
---@param inLockdown boolean
local function setLockdown(loaded, inLockdown)
	loaded.env.InCombatLockdown = function()
		return inLockdown
	end
end

-- A right click held 0.1 s, then the next frame, as quick clicks come.
---@param client FakeClient
local function rightClick(client)
	client.click("RightButton")
	client.nextFrame()
end

-- What each right press would do: BUTTON2's override at each GLOBAL_MOUSE_DOWN, by press.
---@param fake FakePagle
---@param client FakeClient
---@return (string|false)[]
local function pressesDo(fake, client)
	local done = {}
	fake.Pagle.RegisterEvent("spec: presses", "GLOBAL_MOUSE_DOWN", function(_, button)
		if button == "RightButton" then
			done[#done + 1] = button2(client)
		end
	end)
	return done
end

describe("The double-click", function()
	describe("opening the window", function()
		it("points BUTTON2 at the cast on a right click on the world within 0.3 s (QOL-R13, QOL-R24)", function()
			local _, client = start()

			client.click("RightButton", 0.29)

			assert.are.equal(CAST, button2(client))
			-- Its own owner: the Fishing key's override is untouched (QOL-R13).
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("opens nothing for a click held 0.31 s, a camera turn (QOL-R13)", function()
			local _, client = start()

			client.click("RightButton", 0.31)

			assert.is_false(button2(client))
		end)

		it("opens nothing for a click on a UI frame (QOL-R13)", function()
			local _, client, loaded = start()
			client.mouseFoci = { loaded.env.UIParent }

			client.click("RightButton")

			assert.is_false(button2(client))
		end)

		it("opens nothing for a left click (QOL-R13)", function()
			local _, client = start()

			client.click("LeftButton")

			assert.is_false(button2(client))
		end)

		it("opens on a click with nothing under the mouse, as over the world (QOL-R13)", function()
			local _, client = start()
			client.mouseFoci = {}

			client.click("RightButton")

			assert.are.equal(CAST, button2(client))
		end)
	end)

	describe("closing the window", function()
		it("closes on the frame after the next right mouse-up, so that click reaches it (QOL-R13)", function()
			local fake, client = start()
			local done = pressesDo(fake, client)
			rightClick(client)

			client.click("RightButton")
			assert.are.equal(CAST, button2(client))
			client.nextFrame()

			assert.is_false(button2(client))
			assert.are.same({ false, CAST }, done)
		end)

		it("closes 0.4 s after it opens (QOL-R13)", function()
			local _, client = start()
			client.click("RightButton")

			client.nextFrame(0.39)
			assert.are.equal(CAST, button2(client))
			client.nextFrame(0.01)
			assert.is_false(button2(client))
		end)

		it("makes a triple click one double-click and one ignored click (QOL-R13)", function()
			local fake, client = start()
			local done = pressesDo(fake, client)

			for _ = 1, 3 do
				rightClick(client)
			end

			assert.are.same({ false, CAST, false }, done)
		end)

		it("never opens from the click whose press came while a window was open (QOL-R13)", function()
			local fake, client = start()
			local done = pressesDo(fake, client)
			rightClick(client)

			-- The second press is held past the window's end, frames running meanwhile.
			client.fireGameEvent("GLOBAL_MOUSE_DOWN", "RightButton")
			client.nextFrame(0.4)
			assert.is_false(button2(client))
			client.fireGameEvent("GLOBAL_MOUSE_UP", "RightButton")

			assert.are.same({ false, CAST }, done)
			assert.is_false(button2(client))
		end)

		it("closes at once when a loot window opens, its target becoming nothing (QOL-R13, QOL-R28)", function()
			local fake, client = start()
			fake.fire("CastStarted")
			client.click("RightButton")
			assert.are.equal(REEL, button2(client))

			-- The first click reeled the bobber in: the channel stops and the loot window opens.
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			fake.fireGameEvent("LOOT_READY", false)

			assert.is_false(button2(client))
			-- Closed, not waiting: the loot window closing doesn't bring it back.
			fake.fireGameEvent("LOOT_CLOSED")
			assert.is_false(button2(client))
		end)
	end)

	describe("re-pointing", function()
		it("re-points BUTTON2 with every re-evaluation while the window is open (QOL-R13, QOL-R25)", function()
			local fake, client = start()
			client.click("RightButton")

			fake.fire("CastStarted")

			assert.are.equal(REEL, button2(client))
		end)

		it("points BUTTON2 at a lure through PagleQoLActionButton (QOL-R24, QOL-R27, QOL-R52)", function()
			local _, client, loaded = start(function(_, client)
				client.bags[6529] = 5
			end)
			assert.are.equal(LURE, client.overrideAction("F"))

			client.click("RightButton")

			assert.are.equal(LURE, button2(client))
			local button = loaded.env.PagleQoLActionButton
			assert.are.same({ type = "item", item = "item:6529" }, button.attributes)
			assert.are.same({ "AnyDown" }, button.clicks)
		end)

		it("points BUTTON2 at a lure under Double-click too, with the key unarmed (QOL-R12, QOL-R24)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[6529] = 5
				client.cvars.ActionButtonUseKeyDown = "0"
			end)
			fake.slash("qol input click")

			client.click("RightButton")

			assert.is_nil(client.overrideAction("F"))
			assert.are.equal(LURE, button2(client))
			local button = loaded.env.PagleQoLActionButton
			assert.are.same({ type = "item", item = "item:6529" }, button.attributes)
			assert.are.same({ "AnyUp" }, button.clicks)
		end)

		it("doesn't re-point BUTTON2 when nothing changed, so its own UPDATE_BINDINGS never loops (QOL-R25)", function()
			local fake, client = start()
			client.click("RightButton")
			client.bindingCalls = {}

			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			fake.fireGameEvent("UPDATE_BINDINGS")
			client.nextFrame()

			assert.are.same({}, client.bindingCalls)
		end)
	end)

	describe("when it is live", function()
		it("does nothing under Input Fishing key (QOL-R12, QOL-R14)", function()
			local fake, client = start()
			fake.slash("qol input key")

			client.click("RightButton")

			assert.is_false(button2(client))
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("works under Input Double-click, where the key isn't armed (QOL-R12, QOL-R14)", function()
			local fake, client = start()
			fake.slash("qol input click")

			client.click("RightButton")

			assert.are.equal(CAST, button2(client))
			assert.is_nil(client.overrideAction("F"))
		end)

		it("does nothing with no pole in hand, while the key still casts (QOL-R14, QOL-R15, QOL-R23)", function()
			for _, mainHand in ipairs({ SWORD, false }) do
				local _, client = start(function(_, client)
					client.mainHand = mainHand or nil
				end)

				client.click("RightButton")

				assert.is_false(button2(client))
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		end)

		it("closes when the pole comes off while the window is open (QOL-R14, QOL-R15)", function()
			local fake, client = start()
			client.click("RightButton")

			client.mainHand = nil
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)

			assert.is_false(button2(client))
		end)

		it("does nothing while a loot window is open or a spell is being cast (QOL-R14, QOL-R20)", function()
			local fake, client = start()
			fake.fireGameEvent("LOOT_READY", true)
			client.click("RightButton")
			assert.is_false(button2(client))
			fake.fireGameEvent("LOOT_CLOSED")

			client.casting = "Shiny Bauble"
			fake.fireGameEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 8087)
			client.nextFrame(0.5)
			client.click("RightButton")
			assert.is_false(button2(client))
		end)

		it("does nothing before PLAYER_LOGIN or while restricted (QOL-R14, QOL-R30, QOL-R33)", function()
			local fake = newFakePagle()
			local client = fake.load("Pagle_QoL").client
			client.mainHand = FISHING_POLE
			fake.login()
			client.click("RightButton")
			assert.is_false(button2(client))

			fake.fireGameEvent("PLAYER_LOGIN")
			fake.setRestricted(true)
			client.click("RightButton")
			assert.is_false(button2(client))
			assert.are.same({}, client.bindingCalls)
		end)
	end)

	describe("in combat", function()
		it("clears BUTTON2 with the Fishing key's override as restriction starts (QOL-R31)", function()
			local fake, client = start()
			client.click("RightButton")

			fake.fireGameEvent("PLAYER_REGEN_DISABLED")

			assert.is_false(button2(client))
			assert.is_nil(client.overrideAction("F"))
		end)

		it(
			"keeps BUTTON2 under lockdown, even past the window's end, until restriction ends (QOL-R31, QOL-R32)",
			function()
				local fake, client, loaded = start()
				client.click("RightButton")

				-- Every override call raises under the fake's lockdown.
				setLockdown(loaded, true)
				fake.fireGameEvent("PLAYER_REGEN_DISABLED")
				fake.setRestricted(true)
				client.nextFrame(0.5)
				client.click("RightButton")
				client.nextFrame()
				assert.are.equal(CAST, button2(client))

				setLockdown(loaded, false)
				fake.setRestricted(false)
				assert.is_false(button2(client))
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		)
	end)
end)

describe("The double-click with Core", function()
	it("hears the mouse through Pagle.RegisterEvent and casts from BUTTON2 (QOL-R13, CORE-R23)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.mainHand = FISHING_POLE
		client.fire("PLAYER_LOGIN")

		client.click("RightButton")
		assert.are.equal(CAST, client.overrideAction("BUTTON2"))

		client.click("RightButton")
		client.nextFrame()
		assert.is_nil(client.overrideAction("BUTTON2"))
	end)
end)
