-- The diagnostics buffer driven through the client (LOG-R80–R82): world-object hovers through the tooltip data hook,
-- fishing sequences against the fake client, read back from PagleDB.global.diagnostics and PagleLog.

-- The names C_Map.GetAreaInfo gives, so Core's area index resolves Darkshore (148) and The Long Wash (453), both in
-- the generated catalogue on Kalimdor (1).
local NAMES = { [148] = "Darkshore", [453] = "The Long Wash" }

-- Core, logged in on the fake client standing in `zone`/`subzone` on Kalimdor, with `extra` globals.
local function fishingCore(zone, subzone, extra)
	---@type table<string, any>
	local globals = {
		C_Map = {
			GetAreaInfo = function(id)
				return NAMES[id]
			end,
			GetBestMapForUnit = function()
				return nil
			end,
		},
		GetRealZoneText = function()
			return zone
		end,
		GetSubZoneText = function()
			return subzone
		end,
	}
	for key, value in pairs(extra or {}) do
		globals[key] = value
	end
	local loaded = loadAddon("Pagle", foreverWith(globals))
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

local function channel(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3-4618-1-1-7731-000000AAAA", FISHING)
end

local function stop(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3-4618-1-1-7731-000000AAAA", FISHING)
end

-- A fishing loot window holding one Oily Blackmouth opens with auto-loot on, and closes.
local function loot(loaded)
	loaded.client.loot = { fishing = true, slots = { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("LOOT_CLOSED")
	loaded.client.loot = { fishing = false, slots = {} }
end

-- A caught Cast: the channel starts, loot comes `channelFor` seconds later (default 5), then the channel stops.
local function caughtCast(loaded, channelFor)
	channel(loaded)
	loaded.client.advance(channelFor or 5)
	loot(loaded)
	stop(loaded)
end

-- The ID of every Cast in the Catch log, in order.
local function castIDs(loaded)
	local ids = {}
	for record in loaded.env.Pagle.IterateCatches() do
		if record.kind == "cast" then
			ids[#ids + 1] = record.id
		end
	end
	return ids
end

local function diagnostics(loaded)
	return loaded.env.PagleDB.global.diagnostics
end

describe("the diagnostics buffer", function()
	it("gets one entry per Cast: its ID, zone, subzone, locale and hovered texts (LOG-R80, LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash")
		loaded.client.hover("Mailbox")
		loaded.client.advance(10)
		loaded.client.hover("Oily Blackmouth School")
		loaded.client.advance(10)

		caughtCast(loaded)

		assert.are.same({
			{
				id = castIDs(loaded)[1],
				zone = 148,
				subzone = 453,
				locale = "enUS",
				texts = { "Oily Blackmouth School", "Mailbox" },
			},
		}, diagnostics(loaded))
	end)

	it("keeps only texts hovered in the 60 s before the channel started (LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash")
		loaded.client.hover("Food Crate")
		loaded.client.advance(1)
		loaded.client.hover("Mailbox")
		loaded.client.advance(60)

		channel(loaded)
		loaded.client.advance(3)
		loaded.client.hover("Fishing Bobber")
		loaded.client.advance(2)
		loot(loaded)

		assert.are.same({ "Mailbox" }, diagnostics(loaded)[1].texts)
	end)

	it("keeps up to 3 distinct texts, most recent first, leaving out older or repeated ones (LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash")
		for _, text in ipairs({ "Mailbox", "Food Crate", "Gubber Blump", "Oily Blackmouth School", "Gubber Blump" }) do
			loaded.client.hover(text)
			loaded.client.advance(1)
		end

		caughtCast(loaded)

		assert.are.same({ "Gubber Blump", "Oily Blackmouth School", "Food Crate" }, diagnostics(loaded)[1].texts)
	end)

	it("holds the zone and subzone texts when the subzone didn't resolve (LOG-R22, LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "Nowhere")

		caughtCast(loaded)

		local entry = diagnostics(loaded)[1]
		assert.are.same({ 148, 0 }, { entry.zone, entry.subzone })
		assert.are.same({ zone = "Darkshore", subzone = "Nowhere" }, entry.unresolved)
	end)

	it("holds the zone and subzone texts when the zone didn't resolve (LOG-R22, LOG-R81)", function()
		local loaded = fishingCore("Elsewhere", "")

		caughtCast(loaded)

		local entry = diagnostics(loaded)[1]
		assert.are.same({ 0, 0 }, { entry.zone, entry.subzone })
		assert.are.same({ zone = "Elsewhere", subzone = "" }, entry.unresolved)
	end)

	it("has no unresolved texts when the zone resolved and there is no subzone (LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "")

		caughtCast(loaded)

		local entry = diagnostics(loaded)[1]
		assert.are.same({ 148, 0 }, { entry.zone, entry.subzone })
		assert.is_nil(entry.unresolved)
	end)

	it("gets an entry for a Cast that got away, and none for one interrupted (LOG-R6, LOG-R7, LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash")

		channel(loaded)
		stop(loaded)
		loaded.client.fire("UI_ERROR_MESSAGE", 0, loaded.env.ERR_FISH_ESCAPED)
		channel(loaded)
		stop(loaded)
		loaded.client.advance(5)

		assert.are.equal(1, #castIDs(loaded))
		assert.are.same(castIDs(loaded), { diagnostics(loaded)[1].id })
		assert.are.equal(1, #diagnostics(loaded))
	end)

	it("takes the texts of the 60 s before the record for loot with no channel seen (LOG-R5, LOG-R81)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash")
		loaded.client.hover("Mailbox")
		loaded.client.advance(30)
		loaded.client.hover("Oily Blackmouth School")
		loaded.client.advance(40)

		loot(loaded)

		assert.are.same({ "Oily Blackmouth School" }, diagnostics(loaded)[1].texts)
	end)

	it("drops the oldest entry for the 501st (LOG-R81)", function()
		local saved = {}
		for i = 1, 500 do
			saved[i] = { id = "old" .. i, zone = 0, subzone = 0, locale = "enUS", texts = {} }
		end
		local loaded = fishingCore("Darkshore", "The Long Wash", { PagleDB = { global = { diagnostics = saved } } })

		caughtCast(loaded)

		local buffer = diagnostics(loaded)
		assert.are.equal(500, #buffer)
		assert.are.equal("old2", buffer[1].id)
		assert.are.equal(castIDs(loaded)[1], buffer[500].id)
	end)

	it("starts again when the saved buffer isn't a table, since it may be dropped (LOG-R82)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash", { PagleDB = { global = { diagnostics = "junk" } } })

		caughtCast(loaded)

		assert.are.same(castIDs(loaded), { diagnostics(loaded)[1].id })
	end)

	it("stays out of the Catch log (LOG-R82)", function()
		local loaded = fishingCore("Darkshore", "Nowhere")
		loaded.client.hover("Oily Blackmouth School")

		caughtCast(loaded)

		local log = loaded.env.PagleLog
		assert.is_nil(log.diagnostics)
		for _, entry in ipairs(logEntries(log)) do
			assert.is_nil(entry:find("Oily Blackmouth School", 1, true))
			assert.is_nil(entry:find("Nowhere", 1, true))
			assert.is_nil(entry:find("enUS", 1, true))
		end
		assert.are.equal(1, #diagnostics(loaded))
	end)
end)

describe("the hovers the diagnostics buffer keeps", function()
	it("are world objects only: other tooltips are left out (LOG-R80)", function()
		local loaded = fishingCore("Darkshore", "The Long Wash")
		local Unit = loaded.env.Enum.TooltipDataType.Unit
		loaded.client.showTooltip(Unit, { type = Unit, lines = { { leftText = "Gubber Blump" } } })
		loaded.client.hover("Mailbox")

		caughtCast(loaded)

		assert.are.same({ "Mailbox" }, diagnostics(loaded)[1].texts)
	end)

	it("leave out a secret or empty first line, and a tooltip with no lines (LOG-R80, CORE-R31)", function()
		local secret = {}
		local loaded = fishingCore("Darkshore", "The Long Wash", {
			issecretvalue = function(value)
				return value == secret
			end,
		})
		local Object = loaded.env.Enum.TooltipDataType.Object
		loaded.client.hover("Mailbox")
		loaded.client.hover(secret)
		loaded.client.hover("")
		loaded.client.showTooltip(Object, { type = Object, lines = {} })
		loaded.client.showTooltip(Object, secret)

		caughtCast(loaded)

		assert.are.same({ "Mailbox" }, diagnostics(loaded)[1].texts)
	end)
end)
