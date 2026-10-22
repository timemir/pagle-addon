-- Cast recording driven through the client's events (LOG-R2–R9, LOG-R43, LOG-R93, LOG-R96): scripted fishing
-- sequences against the fake client, read back from PagleLog.entries and Core's bus.

local T = SERVER_TIME -- the fake client's GetServerTime(), 15:15 UTC: realm 08:15
local DRAIN_LIFE = 689

local MACKEREL = "|cffffffff|Hitem:6303::::::::15:::::::::|h[Raw Slitherskin Mackerel]|h|r"

-- The snapshot fields of a Cast on the fake client (LOG-R20): realm minute 495, no uiMap, instance 1, no zone or
-- subzone text, Fishing 75+0, no lure, event or aura.
local SNAPSHOT = "495||1|0|0|75|0|||"

local EVENTS = { "CastStarted", "Catch", "CastEnded", "FishingStateChanged" }

-- Core, logged in on the fake client, with a server clock the spec moves (`server.time`), and `extra` globals.
local function fishingCore(extra)
	local server = { time = T }
	---@type table<string, any>
	local globals = {
		GetServerTime = function()
			return server.time
		end,
	}
	for key, value in pairs(extra or {}) do
		globals[key] = value
	end
	local loaded = loadAddon("Pagle", foreverWith(globals))
	loaded.client.fire("PLAYER_LOGIN")
	return loaded, server
end

-- Every fishing event Core fires, in order, as { event, ..., entries = #PagleLog.entries when it fired }.
local function recordEvents(loaded)
	local fired = {}
	for _, event in ipairs(EVENTS) do
		loaded.env.Pagle.RegisterCallback("Spec " .. event, event, function(...)
			fired[#fired + 1] = { entries = #loaded.env.PagleLog.entries, ... }
		end)
	end
	return fired
end

-- The event names fired, in order.
local function names(fired)
	local out = {}
	for i, step in ipairs(fired) do
		out[i] = step[1]
	end
	return out
end

-- The Cast entries in PagleLog, in order.
local function casts(loaded)
	local out = {}
	for _, entry in ipairs(loaded.env.PagleLog.entries) do
		if entry:sub(1, 3) == "C1|" then
			out[#out + 1] = entry
		end
	end
	return out
end

local function channel(loaded, spellID)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3-4618-1-1-7731-000000AAAA", spellID or FISHING)
end

local function stop(loaded, spellID)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3-4618-1-1-7731-000000AAAA", spellID or FISHING)
end

-- A fishing loot window holding `slots` opens: LOOT_READY with auto-loot `autoLoot` (default on).
local function lootReady(loaded, slots, autoLoot)
	loaded.client.loot = { fishing = true, slots = slots }
	loaded.client.fire("LOOT_READY", autoLoot ~= false)
end

local function lootClosed(loaded)
	loaded.client.fire("LOOT_CLOSED")
	loaded.client.loot = { fishing = false, slots = {} }
end

describe("a caught Cast", function()
	it("is recorded with auto-loot on: channel, LOOT_READY, the channel stops, LOOT_CLOSED (LOG-R3, LOG-R9)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)

		channel(loaded)
		lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 } })
		stop(loaded)
		lootClosed(loaded)
		loaded.client.advance(5)

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6358x1" }, casts(loaded))
		assert.are.same(
			{ "CastStarted", "FishingStateChanged", "Catch", "CastEnded", "FishingStateChanged", "FishingStateChanged" },
			names(fired)
		)
		assert.are.same({ "channeling", "looting", "idle" }, { fired[2][2], fired[5][2], fired[6][2] })
		assert.are.equal("idle", loaded.env.Pagle.GetFishingState())
	end)

	it("is recorded with auto-loot off, where LOOT_OPENED also fires and is never used (LOG-R3, LOG-R4)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)

		channel(loaded)
		stop(loaded)
		lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 } }, false)
		loaded.client.fire("LOOT_OPENED", false, false)
		loaded.client.advance(5)
		assert.are.equal("looting", loaded.env.Pagle.GetFishingState())
		lootClosed(loaded)

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6358x1" }, casts(loaded))
		assert.are.equal(1, #casts(loaded))
		assert.are.same(
			{ "CastStarted", "FishingStateChanged", "Catch", "CastEnded", "FishingStateChanged", "FishingStateChanged" },
			names(fired)
		)
	end)

	it("ignores a second LOOT_READY in the same window (LOG-R4)", function()
		local loaded = fishingCore()
		channel(loaded)

		lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 } })
		lootReady(loaded, { { link = MACKEREL, quantity = 1 } })
		lootClosed(loaded)

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6358x1" }, casts(loaded))
	end)

	it("is recorded from fishing loot with no channel seen, as after a reload mid-cast (LOG-R5)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)

		lootReady(loaded, { { link = MACKEREL, quantity = 1 } })

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6303x1" }, casts(loaded))
		assert.are.same({ "Catch", "CastEnded", "FishingStateChanged" }, names(fired))
	end)

	it("keeps every item in slot order with its quantity, skipping money and currency (LOG-R3, LOG-R8)", function()
		local loaded = fishingCore()
		channel(loaded)

		lootReady(loaded, {
			{ quantity = 0, isCoin = true },
			{ link = MACKEREL, quantity = 2 },
			{ link = "|cff00aaff|Hcurrency:1901:0|h[Coin]|h|r", quantity = 5, currencyID = 1901 },
			{ link = OILY_BLACKMOUTH, quantity = 1 },
			{ link = MACKEREL, quantity = 1 },
		})

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6303x2,6358x1,6303x1" }, casts(loaded))
	end)

	it("records an item whose ID is secret as item 0 (LOG-R8, CORE-R85)", function()
		local secret = {}
		local loaded = fishingCore({
			issecretvalue = function(value)
				return value == secret
			end,
		})
		channel(loaded)

		lootReady(loaded, { { link = secret, quantity = 1 }, { link = OILY_BLACKMOUTH, quantity = 1 } })

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|0x1,6358x1" }, casts(loaded))
	end)

	it("records an Uncharted item, unknown to the catalogue, like any other (LOG-R8, LOG-R96)", function()
		local loaded = fishingCore()
		assert.is_nil(loaded.env.Pagle.GetItem(276275))
		channel(loaded)

		lootReady(loaded, { { link = "|Hitem:276275::|h[Bitter Baitling]|h", quantity = 1 } })

		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|276275x1" }, casts(loaded))
	end)

	it("records nothing for a loot window that isn't fishing loot (LOG-R3)", function()
		local loaded = fishingCore()
		channel(loaded)

		loaded.client.loot = { fishing = false, slots = { { link = MACKEREL, quantity = 1 } } }
		loaded.client.fire("LOOT_READY", true)

		assert.are.same({}, casts(loaded))
		assert.are.equal("channeling", loaded.env.Pagle.GetFishingState())
	end)
end)

describe("a got-away Cast", function()
	-- Forever's own sequence, from the in-game probe on #112: UI_INFO_MESSAGE 418 during the channel, then the stop.
	it("is recorded at the escaped UI info message during the channel, with no items (LOG-R6)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)
		channel(loaded)

		loaded.client.fire("UI_INFO_MESSAGE", 418, loaded.env.ERR_FISH_ESCAPED)
		stop(loaded)
		loaded.client.advance(5)

		assert.are.same({ "C1|1|" .. T .. "|0|g|" .. SNAPSHOT .. "|" }, casts(loaded))
		assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "FishingStateChanged" }, names(fired))
		assert.are.equal("gotAway", fired[3][2])
	end)

	it("is recorded at the escaped UI error during the channel, with no items (LOG-R6)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)
		channel(loaded)

		loaded.client.fire("UI_ERROR_MESSAGE", 397, "Your fish got away!")
		stop(loaded)
		loaded.client.advance(5)

		assert.are.same({ "C1|1|" .. T .. "|0|g|" .. SNAPSHOT .. "|" }, casts(loaded))
		assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "FishingStateChanged" }, names(fired))
		assert.are.equal("gotAway", fired[3][2])
	end)

	it("is recorded at the escaped system message within 2 s after the channel stops (LOG-R6)", function()
		local loaded = fishingCore()
		channel(loaded)
		stop(loaded)
		loaded.client.advance(1.5)

		loaded.client.fire("CHAT_MSG_SYSTEM", "Your fish got away!")
		loaded.client.advance(5)

		assert.are.same({ "C1|1|" .. T .. "|0|g|" .. SNAPSHOT .. "|" }, casts(loaded))
	end)

	it("ignores any other UI info, UI error or system message (LOG-R6)", function()
		local loaded = fishingCore()
		channel(loaded)

		loaded.client.fire("UI_INFO_MESSAGE", 418, "You are not in a party.")
		loaded.client.fire("UI_ERROR_MESSAGE", 398, "No fish are hooked.")
		loaded.client.fire("CHAT_MSG_SYSTEM", "You feel rested.")

		assert.are.same({}, casts(loaded))
		assert.are.equal("channeling", loaded.env.Pagle.GetFishingState())
	end)
end)

describe("an interrupted Cast", function()
	it("writes nothing when nothing comes within 2 s of the channel stopping (LOG-R7)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)
		channel(loaded)
		stop(loaded)
		local entries = #loaded.env.PagleLog.entries

		loaded.client.advance(1.9)
		assert.are.equal("channeling", loaded.env.Pagle.GetFishingState())
		loaded.client.advance(0.1)

		assert.are.equal(entries, #loaded.env.PagleLog.entries)
		assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "FishingStateChanged" }, names(fired))
		assert.are.same({ "interrupted" }, { fired[3][2] })
		assert.are.equal("idle", loaded.env.Pagle.GetFishingState())
	end)

	it("ignores an escaped message after the grace time (LOG-R7)", function()
		local loaded = fishingCore()
		channel(loaded)
		stop(loaded)
		loaded.client.advance(2)

		loaded.client.fire("UI_ERROR_MESSAGE", 397, "Your fish got away!")

		assert.are.same({}, casts(loaded))
	end)

	it("ends at a recast before the grace time ends: CastEnded comes before the new CastStarted (LOG-R7)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)
		channel(loaded)
		stop(loaded)
		loaded.client.advance(0.5)

		channel(loaded)
		loaded.client.advance(5)

		assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "CastStarted" }, names(fired))
		assert.are.equal("interrupted", fired[3][2])
		assert.are.equal("channeling", loaded.env.Pagle.GetFishingState())
	end)
end)

describe("each Cast", function()
	it("ends exactly once, whatever signals for it follow (LOG-R7)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)
		channel(loaded)

		loaded.client.fire("UI_ERROR_MESSAGE", 397, "Your fish got away!")
		loaded.client.fire("CHAT_MSG_SYSTEM", "Your fish got away!")
		stop(loaded)
		loaded.client.advance(5)

		local ended = 0
		for _, step in ipairs(fired) do
			ended = ended + (step[1] == "CastEnded" and 1 or 0)
		end
		assert.are.equal(1, ended)
		assert.are.equal(1, #casts(loaded))
	end)

	it(
		"fires every event after its entry is in PagleLog.entries, in LOG-R9's order, with the records"
			.. " IterateCatches yields (LOG-R9, LOG-R43)",
		function()
			local loaded = fishingCore()
			local fired = recordEvents(loaded)
			channel(loaded)
			local before = #loaded.env.PagleLog.entries

			lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 }, { link = MACKEREL, quantity = 3 } })

			local seq = before + 1
			local record = loaded.env.Pagle.IterateCatches(before)()
			assert.are.same({ "Catch", "Catch", "CastEnded", "FishingStateChanged" }, names({ unpack(fired, 3) }))
			for i = 3, #fired do
				assert.are.equal(seq, fired[i].entries)
			end
			assert.are.equal(seq, record.seq)
			assert.are.same({ { 6358, 1 }, { 6303, 3 } }, {
				{ record.items[1].itemID, record.items[1].quantity },
				{ record.items[2].itemID, record.items[2].quantity },
			})
			-- Both are Species with a typical length in the generated catalogue, so each Catch has a size (LOG-R65) and a
			-- variety (VAR-R1, VAR-R4).
			assert.is_table(record.items[1].size)
			assert.is_table(record.items[2].size)
			assert.is_table(record.items[1].variety)
			assert.is_table(record.items[2].variety)
			assert.are.same({
				catchId = PLAYER_GUID .. "-" .. T .. "-0:1",
				itemID = 6358,
				quantity = 1,
				n = 1,
				size = record.items[1].size,
				variety = record.items[1].variety,
				cast = record,
			}, fired[3][2])
			assert.are.same({
				catchId = PLAYER_GUID .. "-" .. T .. "-0:2",
				itemID = 6303,
				quantity = 3,
				n = 2,
				size = record.items[2].size,
				variety = record.items[2].variety,
				cast = record,
			}, fired[4][2])
			assert.are.same({ "CastEnded", "caught", record }, { fired[5][1], fired[5][2], fired[5][3] })
		end
	)

	it("takes its snapshot when it ends, at that moment's server time (LOG-R9, LOG-R20)", function()
		local loaded, server = fishingCore()
		channel(loaded)
		server.time = T + 17

		lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 } })

		assert.are.same({ "C1|1|" .. (T + 17) .. "|0|c|" .. SNAPSHOT .. "|6358x1" }, casts(loaded))
	end)

	it("gets the next tie when two Casts end in the same second (LOG-R12)", function()
		local loaded = fishingCore()

		lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 } })
		lootClosed(loaded)
		lootReady(loaded, { { link = MACKEREL, quantity = 1 } })

		assert.are.same({
			"C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6358x1",
			"C1|1|" .. T .. "|1|c|" .. SNAPSHOT .. "|6303x1",
		}, casts(loaded))
	end)
end)

describe("the fishing channel", function()
	it("starts nothing when its spell isn't on the fishing-spell list (LOG-R2)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)

		channel(loaded, DRAIN_LIFE)
		stop(loaded, DRAIN_LIFE)
		loaded.client.advance(5)

		assert.are.same({}, fired)
		assert.are.equal("idle", loaded.env.Pagle.GetFishingState())
	end)

	it("is the player's only: another unit's channel starts nothing (LOG-R2)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)

		loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "party1", "Cast-guid", FISHING)

		assert.are.same({}, fired)
	end)

	it("sets the fishing state Pagle.GetFishingState reports (LOG-R2)", function()
		local loaded = fishingCore()
		assert.are.equal("idle", loaded.env.Pagle.GetFishingState())

		channel(loaded)

		assert.are.equal("channeling", loaded.env.Pagle.GetFishingState())
	end)
end)

describe("in combat", function()
	it("still records a loot window that opens as combat starts (LOG-R93)", function()
		local inCombat = false
		local loaded = fishingCore({
			InCombatLockdown = function()
				return inCombat
			end,
		})
		channel(loaded)
		stop(loaded)

		inCombat = true
		loaded.client.fire("PLAYER_REGEN_DISABLED")
		lootReady(loaded, { { link = OILY_BLACKMOUTH, quantity = 1 } })

		assert.is_true(loaded.env.Pagle.IsRestricted())
		assert.are.same({ "C1|1|" .. T .. "|0|c|" .. SNAPSHOT .. "|6358x1" }, casts(loaded))
	end)

	it("ends a channel combat cuts as interrupted, writing nothing (LOG-R7, LOG-R93)", function()
		local loaded = fishingCore()
		local fired = recordEvents(loaded)
		channel(loaded)

		loaded.client.fire("PLAYER_REGEN_DISABLED")
		stop(loaded)
		loaded.client.advance(2)

		assert.are.same({}, casts(loaded))
		assert.are.equal("interrupted", fired[3][2])
	end)
end)
