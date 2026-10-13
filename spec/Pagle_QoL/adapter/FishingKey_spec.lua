-- The Fishing key in M1: cast, reel and the loot guard, armed with override bindings (QOL-R10, QOL-R11, QOL-R20–R28,
-- QOL-R30, QOL-R98), driven through FakePagle and the fake client's game side (spec/support/fake_game.lua).

local FISHING_POLE, SWORD = 6256, 25
local CAST, REEL = "SPELL Fishing", "INTERACTTARGET"

-- QoL loaded against FakePagle and logged in, with `keys` bound to the Fishing key. `before(fake, client)` runs
-- after the load and before PLAYER_LOGIN.
---@param keys string[]
---@param before fun(fake: FakePagle, client: FakeClient)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(keys, before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = keys
	if before then
		before(fake, client)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- What each key's override does now, by key.
---@param client FakeClient
---@param keys string[]
---@return table<string, string|false>
local function actions(client, keys)
	local found = {}
	for _, key in ipairs(keys) do
		found[key] = client.overrideAction(key) or false
	end
	return found
end

-- Whether any of QoL's frames runs an OnUpdate script (the 0.5 s tick, or the wait for a key to come up).
---@param client FakeClient
---@return boolean
local function ticking(client)
	for _, frame in ipairs(client.frames) do
		if frame.scripts.OnUpdate then
			return true
		end
	end
	return false
end

describe("The Fishing key", function()
	describe("arming", function()
		it("sets a priority override to cast on each key bound to it, once logged in (QOL-R11, QOL-R24)", function()
			local _, client = start({ "F", "SHIFT-F" })

			assert.are.same({ F = CAST, ["SHIFT-F"] = CAST }, actions(client, { "F", "SHIFT-F" }))
			assert.are.same({ "clear", "set F " .. CAST, "set SHIFT-F " .. CAST }, client.bindingCalls)
		end)

		it("sets nothing while it is unbound (QOL-R11)", function()
			local _, client = start({})

			assert.are.same({}, client.bindingCalls)
		end)

		it("casts with or without a pole in hand (QOL-R21, QOL-R23)", function()
			for _, mainHand in ipairs({ FISHING_POLE, SWORD, false }) do
				local _, client = start({ "F" }, function(_, client)
					client.mainHand = mainHand or nil
				end)

				assert.are.equal(CAST, client.overrideAction("F"))
			end
		end)
	end)

	describe("reeling", function()
		it(
			"reels from CastStarted until the player's channel stops, without waiting for CastEnded (QOL-R22)",
			function()
				local fake, client = start({ "F" })

				fake.fire("CastStarted")
				assert.are.equal(REEL, client.overrideAction("F"))

				fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		)

		it("ignores another unit's channel stopping (QOL-R22)", function()
			local fake, client = start({ "F" })
			fake.fire("CastStarted")

			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "party1", "Cast-1", 7620)

			assert.are.equal(REEL, client.overrideAction("F"))
		end)

		it("reels after a load mid-channel, when UnitChannelInfo names Fishing (QOL-R22)", function()
			local fake, client = start({ "F" }, function(_, client)
				client.channel = "Fishing"
			end)
			assert.are.equal(REEL, client.overrideAction("F"))

			client.channel = nil
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("casts after a load mid-channel of another spell (QOL-R22)", function()
			local _, client = start({ "F" }, function(_, client)
				client.channel = "First Aid"
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("doing nothing", function()
		it("clears every key's override while a loot window is open, until LOOT_CLOSED (QOL-R28)", function()
			local fake, client = start({ "F", "G" })

			-- Fishing loot: the reel ends the channel, then the loot window opens.
			fake.fire("CastStarted")
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			fake.fireGameEvent("LOOT_READY", false)
			assert.are.same({ F = false, G = false }, actions(client, { "F", "G" }))

			fake.fire("CastEnded", "caught")
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			client.update(1)
			assert.are.same({ F = false, G = false }, actions(client, { "F", "G" }))

			fake.fireGameEvent("LOOT_CLOSED")
			assert.are.same({ F = CAST, G = CAST }, actions(client, { "F", "G" }))
		end)

		it("does nothing with any loot window open: a clam's or a mob's, opened while idle (QOL-R28)", function()
			local fake, client = start({ "F" })

			fake.fireGameEvent("LOOT_READY", true)
			assert.is_nil(client.overrideAction("F"))

			fake.fireGameEvent("LOOT_CLOSED")
			fake.fireGameEvent("LOOT_CLOSED") -- the client fires it twice (probe B1)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("does nothing while the player casts a spell with a cast time (QOL-R20)", function()
			local fake, client = start({ "F" })

			client.casting = "Shiny Bauble"
			fake.fireGameEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 8087)
			assert.is_nil(client.overrideAction("F"))

			client.casting = nil
			fake.fireGameEvent("UNIT_SPELLCAST_STOP", "player", "Cast-2", 8087)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("re-pointing", function()
		it(
			"re-points only when the keys or the target change, so its own UPDATE_BINDINGS never loops (QOL-R25)",
			function()
				local fake, client = start({ "F" })
				client.bindingCalls = {}

				for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_BINDINGS" }) do
					fake.fireGameEvent(event)
				end
				fake.fireGameEvent("UNIT_INVENTORY_CHANGED", "player")
				fake.fire("CastEnded", "interrupted")
				fake.fire("FishingStateChanged", "idle")
				client.update(0.5)

				assert.are.same({}, client.bindingCalls)
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		)

		it(
			"re-arms on the new keys after UPDATE_BINDINGS, clearing the old key's override first (QOL-R25, QOL-R98)",
			function()
				local fake, client = start({ "F" })
				client.bindingCalls = {}

				client.boundKeys.PAGLE_FISHING_KEY = { "G" }
				fake.fireGameEvent("UPDATE_BINDINGS")

				assert.are.same({ "clear", "set G " .. CAST }, client.bindingCalls)
				assert.are.same({ F = false, G = CAST }, actions(client, { "F", "G" }))
			end
		)

		it("reads the bound keys only on UPDATE_BINDINGS (QOL-R25)", function()
			local fake, client = start({ "F" })

			client.bindingCalls = {}

			client.boundKeys.PAGLE_FISHING_KEY = { "G" }
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			client.update(0.5)

			assert.are.same({}, client.bindingCalls)
			assert.are.same({ F = CAST, G = false }, actions(client, { "F", "G" }))
		end)

		it("disarms when the last key is unbound (QOL-R11, QOL-R98)", function()
			local fake, client = start({ "F" })

			client.boundKeys.PAGLE_FISHING_KEY = {}
			fake.fireGameEvent("UPDATE_BINDINGS")

			assert.is_nil(client.overrideAction("F"))
		end)

		it("re-points a held key on the first frame it is up (QOL-R26)", function()
			local fake, client = start({ "SHIFT-F" })

			client.keysDown.F = true
			fake.fire("CastStarted")
			assert.are.equal(CAST, client.overrideAction("SHIFT-F"))
			client.update(0.016)
			assert.are.equal(CAST, client.overrideAction("SHIFT-F"))

			client.keysDown.F = nil
			client.update(0.016)
			assert.are.equal(REEL, client.overrideAction("SHIFT-F"))
		end)

		it("re-evaluates every 0.5 s while armed, catching a change no event reported (QOL-R25)", function()
			local _, client = start({ "F" })

			client.casting = "Shiny Bauble"
			client.update(0.25)
			assert.are.equal(CAST, client.overrideAction("F"))
			client.update(0.25)
			assert.is_nil(client.overrideAction("F"))
		end)
	end)

	describe("restriction", function()
		it("runs no tick before PLAYER_LOGIN, and ticks once armed (QOL-R25)", function()
			local fake = newFakePagle()
			local client = fake.load("Pagle_QoL").client
			client.boundKeys.PAGLE_FISHING_KEY = { "F" }
			assert.is_false(ticking(client))

			fake.login()
			fake.fireGameEvent("PLAYER_LOGIN")
			assert.is_true(ticking(client))
		end)

		it(
			"stops the tick and changes no binding while restricted, then re-arms when it ends (QOL-R25, QOL-R30, QOL-R32)",
			function()
				local fake, client = start({ "F" })

				fake.setRestricted(true)
				client.bindingCalls = {}
				fake.fire("CastStarted")
				fake.fireGameEvent("LOOT_READY", false)
				fake.fireGameEvent("LOOT_CLOSED")
				assert.is_false(ticking(client))
				assert.are.same({}, client.bindingCalls)

				fake.setRestricted(false)
				assert.is_true(ticking(client))
				assert.are.equal(REEL, client.overrideAction("F"))
			end
		)
	end)

	describe("boundary", function()
		it("records nothing and changes only bindings, over a whole Cast (QOL-R4, QOL-R5)", function()
			local fake, client, loaded = start({ "F" })
			local saved = loaded.env.PagleQoLDB
			local function copy(value)
				if type(value) ~= "table" then
					return value
				end
				local copied = {}
				for k, v in pairs(value) do
					copied[k] = copy(v)
				end
				return copied
			end
			local before = copy(saved)
			local globals = {}
			for name in pairs(loaded.env) do
				globals[name] = true
			end
			client.bindingCalls = {}

			fake.fire("CastStarted")
			fake.fire("FishingStateChanged", "channeling")
			client.update(0.5)
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			fake.fireGameEvent("LOOT_READY", true)
			fake.fire("CastEnded", "caught")
			fake.fireGameEvent("LOOT_CLOSED")

			assert.are.same(
				{ "clear", "set F " .. REEL, "clear", "set F " .. CAST, "clear", "clear", "set F " .. CAST },
				client.bindingCalls
			)
			assert.are.same(before, saved)
			local added = {}
			for name in pairs(loaded.env) do
				if not globals[name] then
					added[#added + 1] = name
				end
			end
			assert.are.same({}, added)
		end)
	end)
end)

describe("The Fishing key with Core", function()
	it("arms at PLAYER_LOGIN and hears WoW events through Pagle.RegisterEvent (QOL-R11, CORE-R23)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.boundKeys.PAGLE_FISHING_KEY = { "F" }

		client.fire("PLAYER_LOGIN")
		assert.are.equal(CAST, client.overrideAction("F"))

		client.fire("LOOT_READY", true)
		assert.is_nil(client.overrideAction("F"))
		client.fire("LOOT_CLOSED")
		assert.are.equal(CAST, client.overrideAction("F"))
	end)
end)
