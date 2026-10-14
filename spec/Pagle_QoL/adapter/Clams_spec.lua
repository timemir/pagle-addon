-- Clams on the Fishing key (QOL-R20 step 5, QOL-R23, QOL-R24's "open a clam" row, QOL-R28, QOL-R55–R57), driven
-- through FakePagle and the fake client's game side (spec/support/fake_game.lua).

local FISHING_POLE = 6256
local SHINY_BAUBLE = 6529
local SMALL_BARNACLED, THICK_SHELLED, BIG_MOUTH = 5523, 5524, 7973
local CAST, REEL, CLICK = "SPELL Fishing", "INTERACTTARGET", "CLICK PagleQoLActionButton:LeftButton"

-- QoL loaded against FakePagle and logged in, F bound to the Fishing key, a fishing pole in hand with Shiny Bauble's
-- lure on, and nothing in the bags. `before(fake, client, loaded)` runs after the load and before PLAYER_LOGIN.
---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	client.mainHand = FISHING_POLE
	client.mainHandEnchant = 263
	if before then
		before(fake, client, loaded)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- The item PagleQoLActionButton uses now, as its "item" attribute holds it.
---@param loaded LoadedAddon
---@return string?
local function buttonItem(loaded)
	return loaded.env.PagleQoLActionButton:GetAttribute("item")
end

describe("Clams on the Fishing key", function()
	describe("the next action", function()
		it(
			"with the bobber not out, a lure on and a 5524 and a 7973 in the bags, opens 5524 (QOL-R20, QOL-R24, QOL-R55)",
			function()
				local _, client, loaded = start(function(_, client)
					client.bags[THICK_SHELLED] = 1
					client.bags[BIG_MOUTH] = 1
				end)

				assert.are.equal(CLICK, client.overrideAction("F"))
				assert.are.equal("item", loaded.env.PagleQoLActionButton:GetAttribute("type"))
				assert.are.equal("item:5524", buttonItem(loaded))
			end
		)

		it("reels with the bobber out, a clam in the bags: never mid-channel (QOL-R20, QOL-R56)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[THICK_SHELLED] = 1
			end)

			fake.fire("CastStarted")
			assert.are.equal(REEL, client.overrideAction("F"))

			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:5524", buttonItem(loaded))
		end)

		it("puts a lure on before it opens a clam (QOL-R20)", function()
			local fake, client, loaded = start(function(_, client)
				client.mainHandEnchant = nil
				client.bags[SHINY_BAUBLE] = 1
				client.bags[THICK_SHELLED] = 1
			end)
			assert.are.equal("item:6529", buttonItem(loaded))

			client.mainHandEnchant = 263
			fake.fireGameEvent("UNIT_INVENTORY_CHANGED", "player")

			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:5524", buttonItem(loaded))
			-- The lure's target slot is gone: a clam opens from the bags (QOL-R24, QOL-R52).
			assert.is_nil(loaded.env.PagleQoLActionButton:GetAttribute("target-slot"))
		end)

		it("opens the clam in one press, though IsUsableItem says it can't be used (QOL-R24, QOL-R55)", function()
			local _, client, loaded = start(function(_, client)
				client.bags[SMALL_BARNACLED] = 1
			end)
			-- As Forever reads a clam in the bags (#147).
			assert.is_false(loaded.env.C_Item.IsUsableItem(SMALL_BARNACLED))

			client.pressKey("F")

			assert.are.same({ "use 5523" }, client.itemUses)
			assert.is_nil(client.targeting)
		end)

		it("opens a clam with no pole in hand and no gear step ready (QOL-R23)", function()
			local _, client, loaded = start(function(_, client)
				client.mainHand = nil
				client.mainHandEnchant = nil
				client.bags[SMALL_BARNACLED] = 2
			end)

			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:5523", buttonItem(loaded))
		end)

		it("casts with no clam in the bags (QOL-R55)", function()
			local _, client = start()

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("never opens a container outside the clam table (QOL-R57, QOL-R96)", function()
			local _, client = start(function(_, client)
				client.bags[6354] = 1 -- a Small Locked Chest
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("re-points when the bags change (QOL-R25)", function()
			local fake, client, loaded = start()

			client.bags[BIG_MOUTH] = 1
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.equal("item:7973", buttonItem(loaded))

			client.bags[THICK_SHELLED] = 1
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.equal("item:5524", buttonItem(loaded))
		end)
	end)

	describe("the loot window", function()
		it(
			"blocks the press after a clam opens, and the press after it closes opens the next clam, then casts (QOL-R28, QOL-R56)",
			function()
				local fake, client, loaded = start(function(_, client)
					client.bags[THICK_SHELLED] = 2
				end)
				assert.are.equal(CLICK, client.overrideAction("F"))

				-- The press opened one: its loot window is open, and the key does nothing.
				fake.fireGameEvent("LOOT_READY", false)
				assert.is_nil(client.overrideAction("F"))

				client.bags[THICK_SHELLED] = 1
				fake.fireGameEvent("BAG_UPDATE_DELAYED")
				assert.is_nil(client.overrideAction("F"))
				fake.fireGameEvent("LOOT_CLOSED")
				assert.are.equal(CLICK, client.overrideAction("F"))
				assert.are.equal("item:5524", buttonItem(loaded))

				-- The last one: after its loot window, the key casts.
				fake.fireGameEvent("LOOT_READY", false)
				client.bags[THICK_SHELLED] = nil
				fake.fireGameEvent("BAG_UPDATE_DELAYED")
				fake.fireGameEvent("LOOT_CLOSED")
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		)
	end)

	describe("Open clams between Casts", function()
		it("is on by default (QOL-R56, qol.md › Data)", function()
			local _, _, loaded = start()

			assert.is_true(loaded.ns.db.profile.clams)
		end)

		it("re-points at once when it changes on the Fishing page (QOL-R25, QOL-R56)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[THICK_SHELLED] = 1
			end)
			local row
			for _, entry in ipairs(assert(fake.settingsPage("fishing"))) do
				if entry.label == "Open clams between Casts" then
					row = entry.setting
				end
			end

			row.set(false)
			assert.are.equal(CAST, client.overrideAction("F"))
			row.set(true)
			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:5524", buttonItem(loaded))
		end)

		it("casts while it is off, with a clam in the bags (QOL-R20, QOL-R56)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[THICK_SHELLED] = 1
			end)

			loaded.ns.db.profile.clams = false
			fake.fireGameEvent("BAG_UPDATE_DELAYED")

			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("beside the lures", function()
		it("doesn't count another spell's success, while a clam is the target, as a lure's (QOL-R29)", function()
			local fake, client, loaded = start(function(_, client)
				client.mainHandEnchant = nil
				client.bags[THICK_SHELLED] = 1
			end)
			assert.are.equal("item:5524", buttonItem(loaded))

			-- A clam has no item spell, so a spell the player casts now isn't a lure's use.
			fake.fireGameEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 8690) -- Hearthstone
			client.bags[SHINY_BAUBLE] = 1
			fake.fireGameEvent("BAG_UPDATE_DELAYED")

			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:6529", buttonItem(loaded))
		end)
	end)

	describe("the double-click", function()
		it("opens a clam from BUTTON2 through PagleQoLActionButton (QOL-R13, QOL-R24)", function()
			local _, client, loaded = start(function(_, client)
				client.bags[THICK_SHELLED] = 1
			end)

			client.click("RightButton")

			assert.are.equal(CLICK, client.overrideAction("BUTTON2"))
			assert.are.same({ type = "item", item = "item:5524" }, loaded.env.PagleQoLActionButton.attributes)
		end)

		it("opens a clam at ActionButtonUseKeyDown 0 too, under Input Double-click (QOL-R12, QOL-R24)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[BIG_MOUTH] = 1
				client.cvars.ActionButtonUseKeyDown = "0"
			end)
			fake.slash("qol input click")

			client.click("RightButton")

			assert.is_nil(client.overrideAction("F"))
			assert.are.equal(CLICK, client.overrideAction("BUTTON2"))
			assert.are.equal("item:7973", buttonItem(loaded))
			assert.are.same({ "AnyUp" }, loaded.env.PagleQoLActionButton.clicks)
		end)
	end)
end)

describe("Clam names", function()
	it("are asked of the client for every clam at load, as they come from C_Item (QOL-R57, QOL-R74)", function()
		local loaded = newFakePagle().load("Pagle_QoL")

		local asked = {}
		for _, itemID in ipairs(loaded.client.itemDataRequests) do
			asked[itemID] = true
		end
		assert.is_true(asked[SMALL_BARNACLED] and asked[THICK_SHELLED] and asked[BIG_MOUTH])
		assert.are.equal("Thick-shelled Clam", loaded.ns.ItemName(THICK_SHELLED))
	end)
end)

describe("Clams on the Fishing key, with Core", function()
	it("points the key at PagleQoLActionButton set to the clam (QOL-R24)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.boundKeys.PAGLE_FISHING_KEY = { "F" }
		client.bags[THICK_SHELLED] = 1

		client.fire("PLAYER_LOGIN")

		assert.are.equal(CLICK, client.overrideAction("F"))
		assert.are.equal("item:5524", buttonItem(loaded))
	end)
end)
