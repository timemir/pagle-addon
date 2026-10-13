-- Lures on the Fishing key (QOL-R20 step 4, QOL-R24, QOL-R27, QOL-R29, QOL-R50–R53), driven through FakePagle and
-- the fake client's game side (spec/support/fake_game.lua).

local FISHING_POLE = 6256
local SHINY_BAUBLE, BRIGHT_BAUBLES = 6529, 6532
local SHINY_BAUBLE_SPELL, BRIGHT_BAUBLES_SPELL = 8087, 8090
local CAST, REEL, CLICK = "SPELL Fishing", "INTERACTTARGET", "CLICK PagleQoLActionButton:LeftButton"

-- QoL loaded against FakePagle and logged in, F bound to the Fishing key, a fishing pole in hand with no lure on and
-- five Shiny Baubles in the bags. `before(fake, client, loaded)` runs after the load and before PLAYER_LOGIN.
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
	client.bags[SHINY_BAUBLE] = 5
	client.itemSpells[BRIGHT_BAUBLES] = { "Bright Baubles", BRIGHT_BAUBLES_SPELL }
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

-- A press that applies the lure the key points at, up to its use finishing: the lure's use casts for a while
-- (UNIT_SPELLCAST_START), then succeeds and stops. The enchant isn't on yet.
---@param fake FakePagle
---@param client FakeClient
---@param spellID integer
local function applyLure(fake, client, spellID)
	client.casting = "Lure"
	fake.fireGameEvent("UNIT_SPELLCAST_START", "player", "Cast-2", spellID)
	client.casting = nil
	fake.fireGameEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", spellID)
	fake.fireGameEvent("UNIT_SPELLCAST_STOP", "player", "Cast-2", spellID)
end

describe("Lures on the Fishing key", function()
	describe("the next action", function()
		it(
			"with a pole, no lure on and Shiny Baubles in the bags, clicks PagleQoLActionButton set to item 6529 (QOL-R20, QOL-R24, QOL-R52)",
			function()
				local _, client, loaded = start()

				assert.are.equal(CLICK, client.overrideAction("F"))
				local button = loaded.env.PagleQoLActionButton
				assert.are.equal("Button", button.kind)
				assert.are.equal("SecureActionButtonTemplate", button.template)
				assert.are.equal("item", button:GetAttribute("type"))
				assert.are.equal("item:6529", buttonItem(loaded))
				-- No target slot and no macro: the lure goes on the pole in hand (QOL-R52, probe B4).
				assert.is_nil(button:GetAttribute("target-slot"))
				assert.is_nil(button:GetAttribute("macrotext"))
			end
		)

		it("reels with the bobber out, and casts once a lure is on (QOL-R20)", function()
			local fake, client = start()

			fake.fire("CastStarted")
			assert.are.equal(REEL, client.overrideAction("F"))

			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			assert.are.equal(CLICK, client.overrideAction("F"))

			client.mainHandEnchant = 263
			fake.fireGameEvent("UNIT_INVENTORY_CHANGED", "player")
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("catches a lure running out between events with the 0.5 s tick (QOL-R25)", function()
			local _, client = start(function(_, client)
				client.mainHandEnchant = 263
			end)
			assert.are.equal(CAST, client.overrideAction("F"))

			client.mainHandEnchant = nil
			client.update(0.5)

			assert.are.equal(CLICK, client.overrideAction("F"))
		end)

		it("casts with no pole in hand, though a lure is in the bags (QOL-R20, QOL-R23)", function()
			local _, client = start(function(_, client)
				client.mainHand = nil
			end)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("casts with no lure available: none in the bags, or none usable (QOL-R51)", function()
			local _, empty = start(function(_, client)
				client.bags = {}
			end)
			local _, unusable = start(function(_, client)
				client.unusable[SHINY_BAUBLE] = true
			end)

			assert.are.equal(CAST, empty.overrideAction("F"))
			assert.are.equal(CAST, unusable.overrideAction("F"))
		end)

		it("re-points when the bags change (QOL-R25)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags = {}
			end)

			client.bags[BRIGHT_BAUBLES] = 1
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:6532", buttonItem(loaded))

			client.bags = {}
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("the Lures setting", function()
		it("picks Bright Baubles over Shiny Bauble under Best I have, the default (QOL-R50, QOL-R51)", function()
			local _, client, loaded = start(function(_, client)
				client.bags[BRIGHT_BAUBLES] = 2
			end)

			assert.are.same({ mode = "best", item = SHINY_BAUBLE }, {
				mode = loaded.ns.db.profile.lures.mode,
				item = loaded.ns.db.profile.lures.item,
			})
			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:6532", buttonItem(loaded))
		end)

		it("uses the chosen lure under Only this one, and casts while it is missing (QOL-R50, QOL-R51)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[BRIGHT_BAUBLES] = 2
			end)
			local lures = loaded.ns.db.profile.lures

			lures.mode = "one"
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.equal("item:6529", buttonItem(loaded))

			client.bags[SHINY_BAUBLE] = nil
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("re-points at once when Lures or Lure changes on the Fishing page (QOL-R25, QOL-R50)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[BRIGHT_BAUBLES] = 2
			end)
			local rows = {}
			for _, row in ipairs(assert(fake.settingsPage("fishing"))) do
				rows[row.label] = row.setting
			end
			assert.are.equal("item:6532", buttonItem(loaded))

			rows.Lures.set("one")
			assert.are.equal("item:6529", buttonItem(loaded))
			rows.Lure.set(BRIGHT_BAUBLES)
			assert.are.equal("item:6532", buttonItem(loaded))
			rows.Lures.set("off")
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("casts under Off, with lures in the bags (QOL-R20, QOL-R50)", function()
			local fake, client, loaded = start()

			loaded.ns.db.profile.lures.mode = "off"
			fake.fireGameEvent("BAG_UPDATE_DELAYED")

			assert.are.equal(CAST, client.overrideAction("F"))
		end)
	end)

	describe("waiting for a lure's result", function()
		it("counts the pole as lured after the use succeeds, until the enchant shows (QOL-R29)", function()
			local fake, client = start()

			applyLure(fake, client, SHINY_BAUBLE_SPELL)
			assert.are.equal(CAST, client.overrideAction("F"))

			client.mainHandEnchant = 263
			fake.fireGameEvent("UNIT_INVENTORY_CHANGED", "player")
			client.advance(2)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("skips the lure when 2 s pass with no lure on, so the key casts (QOL-R29, QOL-R51)", function()
			local fake, client = start()
			applyLure(fake, client, SHINY_BAUBLE_SPELL)

			client.advance(1.9)
			assert.are.equal(CAST, client.overrideAction("F"))
			client.advance(0.1)
			assert.are.equal(CAST, client.overrideAction("F"))

			-- The lure stays skipped: a later reading still casts.
			fake.fireGameEvent("BAG_UPDATE_DELAYED")
			client.update(0.5)
			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("skips a lure whose use fails while it is the target, so the key casts (QOL-R29)", function()
			local fake, client = start()

			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-2", SHINY_BAUBLE_SPELL)

			assert.are.equal(CAST, client.overrideAction("F"))
		end)

		it("moves on to the next best lure once the best one is skipped (QOL-R29, QOL-R51)", function()
			local fake, client, loaded = start(function(_, client)
				client.bags[BRIGHT_BAUBLES] = 1
			end)

			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-2", BRIGHT_BAUBLES_SPELL)

			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:6529", buttonItem(loaded))
		end)

		it("ignores another spell's failure, and another unit's (QOL-R29)", function()
			local fake, client = start()

			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-3", 8690) -- Hearthstone
			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "party1", "Cast-4", SHINY_BAUBLE_SPELL)

			assert.are.equal(CLICK, client.overrideAction("F"))
		end)

		it("ignores a lure spell that wasn't the target, and casting it from the bags (QOL-R29)", function()
			local fake, client = start(function(_, client)
				client.mainHandEnchant = 263
			end)

			-- The key casts; the player uses a bauble from the bags, and it fails.
			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-2", SHINY_BAUBLE_SPELL)
			client.mainHandEnchant = nil
			fake.fireGameEvent("UNIT_INVENTORY_CHANGED", "player")

			assert.are.equal(CLICK, client.overrideAction("F"))
		end)

		it(
			"matches no spell while the targeted lure's spell isn't loaded yet, and asks the client for the lure (QOL-R29)",
			function()
				local requested = {}
				local fake, client = start(function(_, client, loaded)
					client.itemSpells[SHINY_BAUBLE] = nil
					loaded.env.C_Item.RequestLoadItemDataByID = function(itemID)
						requested[#requested + 1] = itemID
					end
				end)
				assert.are.equal(CLICK, client.overrideAction("F"))

				-- Right after login, the player casts other spells: neither marks the pole lured nor skips the lure.
				fake.fireGameEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 2383) -- Find Herbs
				client.advance(2)
				assert.are.equal(CLICK, client.overrideAction("F"))
				fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-3", 8690) -- Hearthstone
				assert.are.equal(CLICK, client.overrideAction("F"))
				assert.are.equal(SHINY_BAUBLE, requested[1])

				-- Once the client has the lure, its own failed use skips it.
				client.itemSpells[SHINY_BAUBLE] = { "Shiny Bauble", SHINY_BAUBLE_SPELL }
				fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-4", SHINY_BAUBLE_SPELL)
				assert.are.equal(CAST, client.overrideAction("F"))
			end
		)

		it("tries skipped lures again after SKILL_LINES_CHANGED (QOL-R29)", function()
			local fake, client, loaded = start()
			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-2", SHINY_BAUBLE_SPELL)

			fake.fireGameEvent("SKILL_LINES_CHANGED")

			assert.are.equal(CLICK, client.overrideAction("F"))
			assert.are.equal("item:6529", buttonItem(loaded))
		end)

		it("forgets the skips at the next login or /reload (QOL-R29)", function()
			local fake, client = start()
			fake.fireGameEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-2", SHINY_BAUBLE_SPELL)
			assert.are.equal(CAST, client.overrideAction("F"))

			local _, reloaded = start()

			assert.are.equal(CLICK, reloaded.overrideAction("F"))
		end)
	end)

	describe("the out-of-lures Nudge", function()
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

		-- QoL with the pole's lure on and no lure left in the bags, a Fishing stretch running (its first Cast's
		-- channel stopped).
		---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
		---@return FakePagle fake
		---@return FakeClient client
		---@return LoadedAddon loaded
		local function fishingWithTheLastLure(before)
			local fake, client, loaded = start(function(fake, client, loaded)
				client.bags = {}
				client.mainHandEnchant = 263
				if before then
					before(fake, client, loaded)
				end
			end)
			fake.fire("CastStarted")
			fake.fireGameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", 7620)
			return fake, client, loaded
		end

		-- The pole's lure runs out, noticed by the next tick; then the Nudge, if any, has its 3.5 s.
		---@param client FakeClient
		---@return string? the Nudge it showed
		local function lureRunsOut(client)
			client.mainHandEnchant = nil
			client.update(0.5)
			local shown = nudge(client)
			client.update(4)
			return shown
		end

		it("shows when the lure runs out mid-stretch with none left, under Best I have (QOL-R53)", function()
			local _, client = fishingWithTheLastLure()

			assert.are.equal("Your lure is gone and there are none left in your bags.", lureRunsOut(client))
		end)

		it("names the chosen lure under Only this one (QOL-R53)", function()
			local _, client = fishingWithTheLastLure(function(_, client, loaded)
				client.bags[BRIGHT_BAUBLES] = 3 -- not the chosen lure
				loaded.ns.db.profile.lures.mode = "one"
			end)

			assert.are.equal("Your lure is gone and there's no Shiny Bauble left in your bags.", lureRunsOut(client))
		end)

		it("shows once per stretch, and again in the next one (QOL-R53, QOL-R61)", function()
			local fake, client = fishingWithTheLastLure()
			assert.is_string(lureRunsOut(client))

			client.mainHandEnchant = 263
			client.update(0.5)
			assert.is_nil(lureRunsOut(client))

			fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- not mounted: the stretch goes on
			client.mounted = true
			fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
			client.mounted = false
			client.mainHandEnchant = 263
			fake.fire("CastStarted")
			assert.is_string(lureRunsOut(client))
		end)

		it("doesn't show under Off (QOL-R53)", function()
			local _, client = fishingWithTheLastLure(function(_, _, loaded)
				loaded.ns.db.profile.lures.mode = "off"
			end)

			assert.is_nil(lureRunsOut(client))
		end)

		it("doesn't show with a lure left: the key puts it on instead (QOL-R53)", function()
			local _, client = fishingWithTheLastLure(function(_, client)
				client.bags[SHINY_BAUBLE] = 1
			end)

			assert.is_nil(lureRunsOut(client))
			assert.are.equal(CLICK, client.overrideAction("F"))
		end)

		it("doesn't show outside a Fishing stretch (QOL-R53)", function()
			local _, client = start(function(_, client)
				client.bags = {}
				client.mainHandEnchant = 263
			end)

			assert.is_nil(lureRunsOut(client))
		end)
	end)

	describe("the button's clicks", function()
		it("fire on key-down while ActionButtonUseKeyDown is 1, else on key-up (QOL-R27)", function()
			local _, down, downLoaded = start()
			local _, up, upLoaded = start(function(_, client)
				client.cvars.ActionButtonUseKeyDown = "0"
			end)

			assert.are.equal(CLICK, down.overrideAction("F"))
			assert.are.same({ "AnyDown" }, downLoaded.env.PagleQoLActionButton.clicks)
			assert.are.equal(CLICK, up.overrideAction("F"))
			assert.are.same({ "AnyUp" }, upLoaded.env.PagleQoLActionButton.clicks)
		end)

		it("follow the CVar at once on CVAR_UPDATE (QOL-R27)", function()
			local fake, client, loaded = start()

			client.cvars.ActionButtonUseKeyDown = "0"
			fake.fireGameEvent("CVAR_UPDATE", "ActionButtonUseKeyDown", "0")
			assert.are.same({ "AnyUp" }, loaded.env.PagleQoLActionButton.clicks)

			client.cvars.ActionButtonUseKeyDown = "1"
			fake.fireGameEvent("CVAR_UPDATE", "ActionButtonUseKeyDown", "1")
			assert.are.same({ "AnyDown" }, loaded.env.PagleQoLActionButton.clicks)
		end)

		it("are read again whenever QoL arms (QOL-R27)", function()
			local fake, client, loaded = start()

			client.cvars.ActionButtonUseKeyDown = "0" -- changed with no CVAR_UPDATE heard
			fake.fire("CastStarted")

			assert.are.equal(REEL, client.overrideAction("F"))
			assert.are.same({ "AnyUp" }, loaded.env.PagleQoLActionButton.clicks)
		end)

		it("aren't changed under lockdown; the arm after it reads the CVar (QOL-R27, QOL-R32)", function()
			local fake, client, loaded = start()
			local locked = false
			loaded.env.InCombatLockdown = function()
				return locked
			end
			fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			fake.setRestricted(true)
			locked = true

			client.cvars.ActionButtonUseKeyDown = "0"
			fake.fireGameEvent("CVAR_UPDATE", "ActionButtonUseKeyDown", "0")
			assert.are.same({ "AnyDown" }, loaded.env.PagleQoLActionButton.clicks)

			locked = false
			fake.setRestricted(false)
			assert.are.same({ "AnyUp" }, loaded.env.PagleQoLActionButton.clicks)
		end)
	end)
end)

describe("Lures on the Fishing key, with Core", function()
	it("creates PagleQoLActionButton at load and points the key at it (QOL-R24, QOL-R33)", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local client = loaded.client
		client.boundKeys.PAGLE_FISHING_KEY = { "F" }
		client.mainHand = FISHING_POLE
		client.bags[SHINY_BAUBLE] = 1
		assert.is_table(loaded.env.PagleQoLActionButton)

		client.fire("PLAYER_LOGIN")

		assert.are.equal(CLICK, client.overrideAction("F"))
		assert.are.equal("item:6529", buttonItem(loaded))
	end)
end)
