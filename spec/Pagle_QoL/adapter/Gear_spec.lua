-- Gear (QOL-R20 step 3, QOL-R23, QOL-R24, QOL-R27, QOL-R29, QOL-R40–R47, QOL-R77): the fishing set on the Fishing
-- key, Swap gear and the swap-back Nudge, driven through FakePagle and the fake client's equipment sets
-- (spec/support/fake_game.lua).

local FISHING_POLE, SWORD, HAT = 6256, 25, 33
local FISHING, PREVIOUS = 3, 5
local CAST, REEL, GEAR = "SPELL Fishing", "INTERACTTARGET", "CLICK PagleQoLGearButton:LeftButton"
local SWORD_ICON, POLE_ICON, FISHING_ICON = 135274, 132932, 136245

-- QoL loaded against FakePagle and logged in: F bound to the Fishing key and G to Swap gear, a sword in hand, and
-- the set "Fishing" (a pole and a hat) chosen as the fishing set. `before(fake, client, loaded)` runs after the load
-- and before PLAYER_LOGIN.
---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	client.boundKeys.PAGLE_SWAP_GEAR = { "G" }
	client.mainHand = SWORD
	client.equipmentSets[FISHING] = { name = "Fishing", items = { [16] = FISHING_POLE, [1] = HAT } }
	loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
	if before then
		before(fake, client, loaded)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- Adds Pagle Previous, holding the sword, as the character's set PREVIOUS.
---@param client FakeClient
local function withPrevious(client)
	client.equipmentSets[PREVIOUS] = { name = "Pagle Previous", items = { [16] = SWORD } }
end

-- A swap to `setID` ending: its items go on and the client says so.
---@param fake FakePagle
---@param client FakeClient
---@param setID integer
local function swapEnds(fake, client, setID)
	client.wearSet(setID)
	fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
	fake.fireGameEvent("EQUIPMENT_SWAP_FINISHED", true, setID)
end

-- Presses Swap gear: its Bindings.xml body.
---@param loaded LoadedAddon
local function pressSwapGear(loaded)
	loaded.env.PagleQoL_SwapGear()
end

-- The Nudge showing now, or nil: the text of a shown GameFontNormalLarge line in a shown frame.
---@param client FakeClient
---@return string?
local function nudge(client)
	for _, frame in ipairs(client.frames) do
		for _, child in ipairs(frame.children) do
			if child.fontObject == "GameFontNormalLarge" and frame.shown then
				return child.text
			end
		end
	end
	return nil
end

describe("Gear on the Fishing key", function()
	describe("the gear step", function()
		it(
			"clicks PagleQoLGearButton with a pole-holding set chosen and no pole in hand (QOL-R20, QOL-R24, QOL-R43)",
			function()
				local _, client, loaded = start()

				assert.are.equal(GEAR, client.overrideAction("F"))
				local button = loaded.env.PagleQoLGearButton
				-- A plain Button, never shown: no template, parent, size or anchor (QOL-R24).
				assert.are.equal("Button", button.kind)
				assert.is_nil(button.template)
				assert.is_nil(button.parent)
				assert.are.same({}, button.points)
			end
		)

		it("comes before a lure, and the reel before it (QOL-R20)", function()
			local fake, client = start(function(_, client)
				client.bags[6529] = 5
			end)
			assert.are.equal(GEAR, client.overrideAction("F"))

			fake.fire("CastStarted")
			assert.are.equal(REEL, client.overrideAction("F"))
		end)

		it("isn't offered with a pole in hand: the key lures or casts (QOL-R43, QOL-R23)", function()
			local _, client = start(function(_, client)
				client.mainHand = FISHING_POLE
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("is never offered for a set whose pole is missing, or that holds no pole (QOL-R43, QOL-R23)", function()
			local _, missing = start(function(_, client)
				client.equipmentSets[FISHING].lost = 1 -- the pole is in the bank
			end)
			local _, poleless = start(function(_, client)
				client.equipmentSets[FISHING].items[16] = SWORD
			end)

			assert.are.equal(CAST, missing.overrideAction("F"))
			assert.are.equal(CAST, poleless.overrideAction("F"))
		end)

		it("isn't offered with no fishing set chosen (QOL-R43)", function()
			local _, client = start(function(_, _, loaded)
				loaded.ns.db.global.gear[PLAYER_GUID] = nil
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("re-points when the chosen set changes (QOL-R25)", function()
			local fake, client = start()

			client.equipmentSets[FISHING].lost = 1
			fake.fireGameEvent("EQUIPMENT_SETS_CHANGED")
			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("a press", function()
		it("saves the gear worn into a new Pagle Previous, then uses the set once (QOL-R44)", function()
			local _, client, loaded = start()

			loaded.env.PagleQoLGearButton:Click()

			assert.are.same(
				{ "clear ignored", "create Pagle Previous " .. SWORD_ICON, "use " .. FISHING },
				client.equipmentSetCalls
			)
			assert.are.same({ [16] = SWORD }, client.equipmentSets[0].items)
		end)

		it("saves over Pagle Previous when it exists (QOL-R44)", function()
			local _, client, loaded = start(function(_, client)
				withPrevious(client)
				client.worn[1] = HAT
			end)

			loaded.env.PagleQoLGearButton:Click()

			assert.are.same({ "clear ignored", "save " .. PREVIOUS, "use " .. FISHING }, client.equipmentSetCalls)
			assert.are.same({ [16] = SWORD, [1] = HAT }, client.equipmentSets[PREVIOUS].items)
		end)

		it("still swaps with no slot free for Pagle Previous, which then isn't made (QOL-R44)", function()
			local _, client, loaded = start(function(_, client)
				for setID = 10, 18 do
					client.equipmentSets[setID] = { name = "Set " .. setID, items = {} }
				end
			end)

			loaded.env.PagleQoLGearButton:Click()

			assert.are.same({ "use " .. FISHING }, client.equipmentSetCalls)
		end)

		it("doesn't equip again until EQUIPMENT_SWAP_FINISHED (QOL-R29, QOL-R43)", function()
			local fake, client, loaded = start()
			loaded.env.PagleQoLGearButton:Click()
			client.equipmentSetCalls = {}

			assert.are.equal(CAST, client.overrideAction("F"))
			loaded.env.PagleQoLGearButton:Click() -- a click the old override still sends
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 1, true) -- the hat goes on first
			client.update(0.5)
			assert.are.equal(CAST, client.overrideAction("F"))
			assert.are.same({}, client.equipmentSetCalls)

			-- The swap failed: nothing changed, and the step is ready again.
			fake.fireGameEvent("EQUIPMENT_SWAP_FINISHED", false, FISHING)
			assert.are.equal(GEAR, client.overrideAction("F"))
		end)

		it("offers the step again after the 2 s result wait with no swap finished (QOL-R29)", function()
			local _, client, loaded = start()
			loaded.env.PagleQoLGearButton:Click()

			client.advance(1.9)
			assert.are.equal(CAST, client.overrideAction("F"))
			client.advance(0.1)
			assert.are.equal(GEAR, client.overrideAction("F"))
		end)

		it("casts once the set is on (QOL-R20, QOL-R43)", function()
			local fake, client, loaded = start()
			loaded.env.PagleQoLGearButton:Click()

			swapEnds(fake, client, FISHING)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("does nothing once the step isn't ready, though the override still points at it (QOL-R43)", function()
			local fake, client, loaded = start()
			client.mainHand = FISHING_POLE -- no event heard yet

			loaded.env.PagleQoLGearButton:Click()

			assert.are.same({}, client.equipmentSetCalls)
			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("the gear button's clicks", function()
		it(
			"fire on key-down while ActionButtonUseKeyDown is 1, else on key-up, read again on CVAR_UPDATE (QOL-R27)",
			function()
				local fake, client, loaded = start()
				local _, _, upLoaded = start(function(_, upClient)
					upClient.cvars.ActionButtonUseKeyDown = "0"
				end)
				assert.are.same({ "AnyDown" }, loaded.env.PagleQoLGearButton.clicks)
				assert.are.same({ "AnyUp" }, upLoaded.env.PagleQoLGearButton.clicks)

				client.cvars.ActionButtonUseKeyDown = "0"
				fake.fireGameEvent("CVAR_UPDATE", "ActionButtonUseKeyDown", "0")

				assert.are.same({ "AnyUp" }, loaded.env.PagleQoLGearButton.clicks)
			end
		)
	end)

	describe("the fishing set's choice", function()
		it("is per character: another character's choice isn't this one's (QOL-R40)", function()
			local _, client = start(function(_, _, loaded)
				local gear = loaded.ns.db.global.gear
				gear["Player-1-00000002"], gear[PLAYER_GUID] = gear[PLAYER_GUID], nil
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("holds no set once none has its ID and name, and is dropped (QOL-R40)", function()
			local fake, client, loaded = start()

			client.equipmentSets[FISHING].name = "Old fishing"
			fake.fireGameEvent("EQUIPMENT_SETS_CHANGED")

			assert.are.equal(CAST, client.overrideAction("F"))
			assert.is_nil(loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		end)

		it("is never Pagle Previous (QOL-R40)", function()
			local _, client = start(function(_, client, loaded)
				client.equipmentSets[PREVIOUS] = { name = "Pagle Previous", items = { [16] = FISHING_POLE } }
				loaded.ns.db.global.gear[PLAYER_GUID] = { setID = PREVIOUS, name = "Pagle Previous" }
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)
end)

describe("Swap gear", function()
	it("swaps back to Pagle Previous with the set fully worn (QOL-R46, QOL-R45)", function()
		local _, client, loaded = start(function(_, client)
			withPrevious(client)
			client.wearSet(FISHING)
		end)

		pressSwapGear(loaded)

		assert.are.same({ "use " .. PREVIOUS }, client.equipmentSetCalls)
	end)

	it("does nothing with the set fully worn and no Pagle Previous (QOL-R46)", function()
		local _, client, loaded = start(function(_, client)
			client.wearSet(FISHING)
		end)

		pressSwapGear(loaded)

		assert.are.same({}, client.equipmentSetCalls)
	end)

	it("does nothing with the set fully worn and a pole in Pagle Previous's main hand (QOL-R46)", function()
		local _, client, loaded = start(function(_, client)
			client.equipmentSets[PREVIOUS] = { name = "Pagle Previous", items = { [16] = FISHING_POLE, [1] = HAT } }
			client.wearSet(FISHING)
		end)

		pressSwapGear(loaded)

		assert.are.same({}, client.equipmentSetCalls)
	end)

	it("swaps to the set while it is partly worn, saving Pagle Previous first (QOL-R46, QOL-R44)", function()
		local _, client, loaded = start(function(_, client)
			withPrevious(client)
			client.worn[1] = HAT -- the hat, but not the pole
		end)

		pressSwapGear(loaded)

		assert.are.same({ "clear ignored", "save " .. PREVIOUS, "use " .. FISHING }, client.equipmentSetCalls)
		assert.are.same({ [16] = SWORD, [1] = HAT }, client.equipmentSets[PREVIOUS].items)
	end)

	it("only uses the set with a pole in hand: Pagle Previous keeps the gear it holds (QOL-R46, QOL-R44)", function()
		local _, client, loaded = start(function(_, client)
			withPrevious(client)
			client.mainHand = FISHING_POLE -- the pole, but not the hat: a swap that ended half done
		end)

		pressSwapGear(loaded)

		assert.are.same({ "use " .. FISHING }, client.equipmentSetCalls)
		assert.are.same({ [16] = SWORD }, client.equipmentSets[PREVIOUS].items)
	end)

	it("creates no Pagle Previous with a pole in hand (QOL-R46, QOL-R44)", function()
		local _, client, loaded = start(function(_, client)
			client.mainHand = FISHING_POLE
		end)

		pressSwapGear(loaded)

		assert.are.same({ "use " .. FISHING }, client.equipmentSetCalls)
	end)

	it("does nothing with an item of the set missing (QOL-R46)", function()
		local _, client, loaded = start(function(_, client)
			client.equipmentSets[FISHING].lost = 1
		end)

		pressSwapGear(loaded)

		assert.are.same({}, client.equipmentSetCalls)
	end)

	it("does nothing while disarmed: restricted, or standing down (QOL-R46, QOL-R30, QOL-R82)", function()
		local fake, client, loaded = start(function(_, client)
			withPrevious(client)
		end)
		local _, downClient, downLoaded = start(function(_, standingDown)
			withPrevious(standingDown)
			standingDown.addons.Angleur = { metadata = { Title = "Angleur" } }
		end)

		fake.setRestricted(true)
		pressSwapGear(loaded)
		pressSwapGear(downLoaded)

		assert.are.same({}, client.equipmentSetCalls)
		assert.are.same({}, downClient.equipmentSetCalls)
	end)

	it("does nothing with no fishing set chosen (QOL-R46)", function()
		local _, client, loaded = start(function(_, _, loaded)
			loaded.ns.db.global.gear[PLAYER_GUID] = nil
		end)

		pressSwapGear(loaded)

		assert.are.same({}, client.equipmentSetCalls)
	end)

	it("does nothing again until the swap finishes, either way (QOL-R29)", function()
		local fake, client, loaded = start(function(_, client)
			withPrevious(client)
		end)
		pressSwapGear(loaded)
		client.equipmentSetCalls = {}

		pressSwapGear(loaded)
		assert.are.same({}, client.equipmentSetCalls)

		swapEnds(fake, client, FISHING)
		pressSwapGear(loaded)
		assert.are.same({ "use " .. PREVIOUS }, client.equipmentSetCalls)
		pressSwapGear(loaded)
		assert.are.same({ "use " .. PREVIOUS }, client.equipmentSetCalls)
	end)

	it("holds the gear step and Swap gear after a swap back too, until it finishes (QOL-R29, QOL-R45)", function()
		local fake, client, loaded = start(function(_, client)
			withPrevious(client)
			client.wearSet(FISHING)
		end)
		pressSwapGear(loaded)
		client.equipmentSetCalls = {}

		client.mainHand = SWORD -- the pole comes off first: a half-swapped outfit
		fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
		pressSwapGear(loaded)
		assert.are.equal(CAST, client.overrideAction("F"))
		assert.are.same({}, client.equipmentSetCalls)

		swapEnds(fake, client, PREVIOUS)
		assert.are.equal(GEAR, client.overrideAction("F"))
	end)
end)

describe("No swap without a press", function()
	it("swaps no gear over a whole stretch, its end and combat, with a set chosen (QOL-R47, QOL-R34)", function()
		local fake, client = start(function(_, client)
			withPrevious(client)
			client.wearSet(FISHING)
		end)

		fake.fire("CastStarted")
		fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
		fake.fire("CastEnded", "caught")
		client.mounted = true
		fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
		client.mainHand = SWORD
		fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
		fake.fireGameEvent("EQUIPMENT_SETS_CHANGED")
		fake.fireGameEvent("PLAYER_REGEN_DISABLED")
		fake.setRestricted(true)
		fake.setRestricted(false)
		client.update(0.5)
		client.advance(60)

		assert.are.same({}, client.equipmentSetCalls)
	end)
end)

describe("The swap-back Nudge", function()
	-- QoL with the set worn and Pagle Previous there, a Fishing stretch running (its first Cast ended).
	---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
	---@return FakePagle fake
	---@return FakeClient client
	local function fishingInTheSet(before)
		local fake, client = start(function(fake, client, loaded)
			withPrevious(client)
			client.wearSet(FISHING)
			if before then
				before(fake, client, loaded)
			end
		end)
		fake.fire("CastStarted")
		fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
		fake.fire("CastEnded", "caught")
		return fake, client
	end

	-- The player mounts, ending the stretch.
	local function mount(fake, client)
		client.mounted = true
		fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
	end

	it("shows with the key's short text when mounting ends the stretch (QOL-R77, QOL-R47)", function()
		local fake, client = fishingInTheSet(function(_, client)
			client.boundKeys.PAGLE_SWAP_GEAR = { "SHIFT-G", "H" }
		end)

		mount(fake, client)

		assert.are.equal("Still holding your pole. Press s-G to swap back.", nudge(client))
	end)

	it("shows when the stretch ends 60 s after the last Cast (QOL-R77, QOL-R61)", function()
		local _, client = fishingInTheSet()

		client.update(30)
		client.update(30)

		assert.are.equal("Still holding your pole. Press G to swap back.", nudge(client))
	end)

	it("asks for a binding while Swap gear is unbound (QOL-R77)", function()
		local fake, client = fishingInTheSet(function(_, client)
			client.boundKeys.PAGLE_SWAP_GEAR = nil
		end)

		mount(fake, client)

		assert.are.equal("Still holding your pole. Bind Pagle: Swap gear to swap back in one press.", nudge(client))
	end)

	it("doesn't show when combat or logout ends the stretch (QOL-R77)", function()
		local combat, combatClient = fishingInTheSet()
		local logout, logoutClient = fishingInTheSet()

		combat.fireGameEvent("PLAYER_REGEN_DISABLED")
		combat.setRestricted(true)
		logout.fireGameEvent("PLAYER_LOGOUT")

		assert.is_nil(nudge(combatClient))
		assert.is_nil(nudge(logoutClient))
	end)

	it("doesn't show unless Swap gear would swap back (QOL-R77, QOL-R46)", function()
		local partly, partlyClient = fishingInTheSet(function(_, client)
			client.worn[1] = nil -- the hat came off
		end)
		local noPrevious, noPreviousClient = fishingInTheSet(function(_, client)
			client.equipmentSets[PREVIOUS] = nil
		end)
		local polePrevious, polePreviousClient = fishingInTheSet(function(_, client)
			client.equipmentSets[PREVIOUS].items[16] = FISHING_POLE -- it counts as absent
		end)

		mount(partly, partlyClient)
		mount(noPrevious, noPreviousClient)
		mount(polePrevious, polePreviousClient)

		assert.is_nil(nudge(partlyClient))
		assert.is_nil(nudge(noPreviousClient))
		assert.is_nil(nudge(polePreviousClient))
	end)

	it("doesn't show when no stretch was running (QOL-R77)", function()
		local fake, client = start(function(_, client)
			withPrevious(client)
			client.wearSet(FISHING)
		end)

		mount(fake, client)

		assert.is_nil(nudge(client))
	end)
end)

describe("Choosing the fishing set", function()
	-- QoL's row on the FakePagle Fishing page by its label.
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

	-- QoL with no fishing set chosen and the sets Fishing and Raid (0).
	---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
	local function choosing(before)
		return start(function(fake, client, loaded)
			loaded.ns.db.global.gear[PLAYER_GUID] = nil
			client.equipmentSets[0] = { name = "Raid", items = { [16] = SWORD } }
			if before then
				before(fake, client, loaded)
			end
		end)
	end

	-- Fills the character's set slots up to `count` sets with placeholders from ID 10.
	---@param client FakeClient
	---@param count integer
	local function fillSets(client, count)
		local sets = 0
		for _ in pairs(client.equipmentSets) do
			sets = sets + 1
		end
		for setID = 10, 10 + count - sets - 1 do
			client.equipmentSets[setID] = { name = "Set " .. setID, items = {} }
		end
	end

	it("offers None and the character's sets but Pagle Previous, and reads None at first (SET-R20, QOL-R40)", function()
		local fake = choosing(function(_, client)
			withPrevious(client)
		end)
		local row = rowOf(fake, "Fishing set")

		assert.are.same({
			{ value = -1, label = "None (gear stays as it is)" },
			{ value = 0, label = "Raid" },
			{ value = FISHING, label = "Fishing" },
		}, row.options())
		assert.are.equal(-1, row.get())
	end)

	it("stores the set by ID and name, creating Pagle Previous from the gear worn (QOL-R40, QOL-R42)", function()
		local fake, client, loaded = choosing()
		local row = rowOf(fake, "Fishing set")

		row.set(FISHING)

		assert.are.same({ setID = FISHING, name = "Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		assert.are.equal(FISHING, row.get())
		assert.are.same({ "clear ignored", "create Pagle Previous " .. SWORD_ICON }, client.equipmentSetCalls)
		assert.are.equal(GEAR, client.overrideAction("F")) -- at once (QOL-R25)
	end)

	it("creates nothing more when Pagle Previous exists (QOL-R42)", function()
		local fake, client = choosing(function(_, client)
			withPrevious(client)
		end)

		rowOf(fake, "Fishing set").set(FISHING)

		assert.are.same({}, client.equipmentSetCalls)
	end)

	it("with a pole in hand creates no Pagle Previous; the first swap to the set does (QOL-R42, QOL-R44)", function()
		local fake, client, loaded = choosing(function(_, client)
			client.mainHand = FISHING_POLE
		end)

		rowOf(fake, "Fishing set").set(FISHING)

		assert.are.same({ setID = FISHING, name = "Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		assert.are.same({}, client.equipmentSetCalls)

		client.mainHand = SWORD
		fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
		loaded.env.PagleQoLGearButton:Click()
		assert.are.same(
			{ "clear ignored", "create Pagle Previous " .. SWORD_ICON, "use " .. FISHING },
			client.equipmentSetCalls
		)
		assert.are.same({ [16] = SWORD }, client.equipmentSets[1].items) -- the lowest free ID: Raid holds 0
	end)

	it("with a pole in hand still needs the slot for Pagle Previous (QOL-R42)", function()
		local fake, client, loaded = choosing(function(_, client)
			client.mainHand = FISHING_POLE
			fillSets(client, 10)
		end)
		local row = rowOf(fake, "Fishing set")

		row.set(FISHING)

		assert.are.same({}, client.equipmentSetCalls)
		assert.are.equal(-1, row.get())
		assert.are.same({ "Pagle: needs a free equipment set slot for Pagle Previous." }, loaded.printed)
	end)

	it("with no free slot for Pagle Previous creates nothing, keeps the choice and says so (QOL-R42)", function()
		local fake, client, loaded = choosing(function(_, client)
			fillSets(client, 10)
		end)
		local row = rowOf(fake, "Fishing set")

		row.set(FISHING)

		assert.are.same({}, client.equipmentSetCalls)
		assert.are.equal(-1, row.get())
		assert.are.same({ "Pagle: needs a free equipment set slot for Pagle Previous." }, loaded.printed)
	end)

	it("goes back to None, and the key casts (QOL-R40)", function()
		local fake, client, loaded = start()

		rowOf(fake, "Fishing set").set(-1)

		assert.is_nil(loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	describe("Save what I'm wearing as my fishing set", function()
		it("creates Pagle Fishing from the gear worn, with no ignored slots, and chooses it (QOL-R41, QOL-R42)", function()
			local fake, client, loaded = choosing(function(_, client)
				client.mainHand = FISHING_POLE
				client.worn[1] = HAT
			end)

			rowOf(fake, "Save what I'm wearing as my fishing set").onClick()

			-- No Pagle Previous with the pole in hand: it would hold the fishing outfit (QOL-R42).
			assert.are.same({ "clear ignored", "create Pagle Fishing " .. POLE_ICON }, client.equipmentSetCalls)
			local fishing = client.equipmentSets[1] -- the lowest free ID: Raid holds 0
			assert.are.same({ [16] = FISHING_POLE, [1] = HAT }, fishing.items)
			assert.are.same({ setID = 1, name = "Pagle Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		end)

		it("creates Pagle Previous too without a pole in hand (QOL-R41, QOL-R42)", function()
			local fake, client = choosing()

			rowOf(fake, "Save what I'm wearing as my fishing set").onClick()

			assert.are.same({
				"clear ignored",
				"create Pagle Fishing " .. FISHING_ICON,
				"clear ignored",
				"create Pagle Previous " .. SWORD_ICON,
			}, client.equipmentSetCalls)
		end)

		it("takes the Fishing spell's icon without a pole in hand (QOL-R41)", function()
			local fake, client = choosing(function(_, client)
				withPrevious(client)
			end)

			rowOf(fake, "Save what I'm wearing as my fishing set").onClick()

			assert.are.same({ "clear ignored", "create Pagle Fishing " .. FISHING_ICON }, client.equipmentSetCalls)
		end)

		it("saves over Pagle Fishing when it exists (QOL-R41)", function()
			local fake, client, loaded = choosing(function(_, client)
				withPrevious(client)
				client.equipmentSets[7] = { name = "Pagle Fishing", items = {} }
			end)

			rowOf(fake, "Save what I'm wearing as my fishing set").onClick()

			assert.are.same({ "clear ignored", "save 7" }, client.equipmentSetCalls)
			assert.are.same({ setID = 7, name = "Pagle Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
		end)

		it("with one free slot when two are needed creates nothing and keeps the choice (QOL-R42)", function()
			local fake, client, loaded = start(function(_, client)
				client.mainHand = FISHING_POLE -- Pagle Previous's slot is counted all the same
				fillSets(client, 9)
			end)

			rowOf(fake, "Save what I'm wearing as my fishing set").onClick()

			assert.are.same({}, client.equipmentSetCalls)
			assert.are.same({ setID = FISHING, name = "Fishing" }, loaded.env.PagleQoLDB.global.gear[PLAYER_GUID])
			assert.are.equal(FISHING, rowOf(fake, "Fishing set").get())
			assert.are.same(
				{ "Pagle: needs two free equipment set slots for Pagle Fishing and Pagle Previous." },
				loaded.printed
			)
		end)
	end)

	it("is disabled while restricted, and changes nothing then (QOL-R41)", function()
		local fake, client = choosing()
		local set = rowOf(fake, "Fishing set")
		local save = rowOf(fake, "Save what I'm wearing as my fishing set")
		assert.is_true(set.isEnabled())
		assert.is_true(save.isEnabled())

		fake.setRestricted(true)
		set.set(FISHING)
		save.onClick()

		assert.is_false(set.isEnabled())
		assert.is_false(save.isEnabled())
		assert.are.equal(-1, set.get())
		assert.are.same({}, client.equipmentSetCalls)
	end)
end)

describe("Gear, with Core", function()
	it("creates PagleQoLGearButton with the action button at load, and the key clicks it (QOL-R24, QOL-R33)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.boundKeys.PAGLE_FISHING_KEY = { "F" }
		client.mainHand = SWORD
		client.equipmentSets[FISHING] = { name = "Fishing", items = { [16] = FISHING_POLE } }
		loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
		assert.is_table(loaded.env.PagleQoLGearButton)

		client.fire("PLAYER_LOGIN")

		assert.are.equal(GEAR, client.overrideAction("F"))
	end)

	it("runs Swap gear from its Bindings.xml body (QOL-R46)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.mainHand = SWORD
		client.equipmentSets[FISHING] = { name = "Fishing", items = { [16] = FISHING_POLE } }
		loaded.ns.db.global.gear[PLAYER_GUID] = { setID = FISHING, name = "Fishing" }
		client.fire("PLAYER_LOGIN")
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local file = assert(io.open("addons/Pagle_QoL/Bindings.xml", "r"))
		local body = assert(file:read("*a"):match('<Binding name="PAGLE_SWAP_GEAR"[^>]*>(.-)</Binding>'))
		file:close()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1, whose loadstring the client has too
		local chunk = assert(loadstring(body))
		setfenv(chunk, loaded.env)

		chunk()

		assert.are.same(
			{ "clear ignored", "create Pagle Previous " .. SWORD_ICON, "use " .. FISHING },
			client.equipmentSetCalls
		)
	end)
end)
