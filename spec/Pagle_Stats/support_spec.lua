-- spec/Pagle_Stats/support.lua: Stats' specs run on FakePagle over the fixture catalogue, never the shipped one, and
-- the fixture holds each case its header promises, read through Core's own accessors
-- (LOG-R55) as Stats reads it (STA-R12–R17).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN = I.DARKSHORE, I.AUBERDINE, I.BASHAL_ARAN, I.ELWYNN
local STRANGLETHORN, STORMWIND = I.STRANGLETHORN, I.STORMWIND
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, BASS = I.MACKEREL, I.BLACKMOUTH, I.FIREFIN, I.NIGHTFIN, I.BASS
local MUD_SNAPPER, MANA_POTION, RUSTED_LURE = I.MUD_SNAPPER, I.MANA_POTION, I.RUSTED_LURE

-- The window IDs of `itemID`'s entries in `zone`'s catches, in order, "-" for an ungated one. Core's records reach
-- specs as FakePagle's read-only proxies, so this walks them with its proxy-aware ipairs.
local function windowsOf(fake, zone, itemID)
	local windows = {}
	for _, entry in fake.globals.ipairs(fake.Pagle.GetZoneCatches(zone)) do
		if entry.itemID == itemID then
			windows[#windows + 1] = entry.window or "-"
		end
	end
	return windows
end

describe("Stats' spec support", function()
	it("serves the fixture catalogue to Core's accessors before Stats loads, and Stats registers (DATA-R76)", function()
		local loaded, fake = stats.load()

		assert.are.equal("57a757a757a757a7", fake.Pagle.CONTENT_FINGERPRINT)
		assert.is_not_nil(loaded.ns.Module)
	end)

	it("serves a spec's own catalogue instead when given one (DATA-R76)", function()
		local catalogue = stats.catalogue()
		catalogue.fingerprint = "0000000000000001"

		local _, fake = stats.load(nil, { catalogue = catalogue })

		assert.are.equal("0000000000000001", fake.Pagle.CONTENT_FINGERPRINT)
	end)

	it("hands out a new fixture each time, so a spec's change stays its own (DATA-R76)", function()
		stats.catalogue().areas[DARKSHORE].skillBase = 1

		assert.are.equal(75, stats.catalogue().areas[DARKSHORE].skillBase)
	end)

	it("names every area and item of the fixture once, and keeps its Uncharted IDs out of it (DATA-R76)", function()
		local catalogue = stats.catalogue()
		local function keys(map)
			local out = {}
			for id in pairs(map) do
				out[#out + 1] = id
			end
			table.sort(out)
			return out
		end

		assert.are.same(keys(catalogue.areas), keys(stats.NAMES.areas))
		assert.are.same(keys(catalogue.items), keys(stats.NAMES.items))
		for name, id in pairs(stats.IDS) do
			local uncharted = name:match("^UNCHARTED") ~= nil
			assert.are.equal(not uncharted, catalogue.areas[id] ~= nil or catalogue.items[id] ~= nil, name)
		end
	end)

	it("starts Stats logged in and built, the fixture named, the player moved (STA-R20)", function()
		local loaded, fake, book = stats.start({
			records = { stats.cast({ time = stats.T0, items = { NIGHTFIN } }) },
			items = { NIGHTFIN },
			at = { zone = ELWYNN, subzone = 0, skillRank = false },
		})

		assert.are.equal(loaded.ns.book, book)
		assert.is_false(loaded.ns.IsUpdating())
		assert.are.equal(1, loaded.ns.State().totals.casts)
		assert.are.same({ "Elwynn Forest", "Raw Nightfin Snapper" }, {
			loaded.client.areaNames[ELWYNN],
			loaded.client.itemNames[NIGHTFIN],
		})
		assert.is_nil(loaded.client.itemNames[MACKEREL])
		assert.are.same({ ELWYNN, 0 }, { fake.conditions.zone, fake.conditions.subzone })
		assert.is_nil(fake.conditions.skillRank)
		fake.wait(60)
		assert.are.equal(SERVER_TIME + 60, loaded.env.GetServerTime())
	end)

	describe("the fixture", function()
		local fake = select(2, stats.load())
		local Pagle = fake.Pagle

		it(
			"has a zone with a confirmed line, one with no skillBase and one whose line is unconfirmed (STA-R12)",
			function()
				assert.are.same(
					{ 75, true },
					{ Pagle.GetArea(DARKSHORE).skillBase, Pagle.GetArea(DARKSHORE).skillBaseConfirmed }
				)
				assert.is_nil(Pagle.GetArea(ELWYNN).skillBase)
				assert.are.same(
					{ 130, false },
					{ Pagle.GetArea(STRANGLETHORN).skillBase, Pagle.GetArea(STRANGLETHORN).skillBaseConfirmed }
				)
			end
		)

		it("has a subzone with its own catches and one with none, both in Darkshore (STA-R17)", function()
			assert.are.equal(DARKSHORE, Pagle.GetZoneOf(AUBERDINE))
			assert.are.equal(DARKSHORE, Pagle.GetZoneOf(BASHAL_ARAN))
			assert.is_not_nil(fake.globals.next(Pagle.GetArea(AUBERDINE).catches))
			assert.is_nil(fake.globals.next(Pagle.GetArea(BASHAL_ARAN).catches))
		end)

		it("has an area with no catch data (LOG-R55)", function()
			assert.is_false(Pagle.GetArea(STORMWIND).hasData)
		end)

		it("has the day, night and summer windows (STA-R15)", function()
			for _, windowID in ipairs({ "day", "night", "summer" }) do
				assert.is_not_nil(Pagle.GetWindowSpec(windowID))
			end
		end)

		it("gates Nightfin by night in Darkshore only, and Firefin both ways in Darkshore (STA-R14)", function()
			assert.are.same({ "night" }, windowsOf(fake, DARKSHORE, NIGHTFIN))
			assert.are.same({ "-" }, windowsOf(fake, ELWYNN, NIGHTFIN))
			assert.are.same({ "night", "-" }, windowsOf(fake, DARKSHORE, FIREFIN))
			assert.are.same({ "summer" }, windowsOf(fake, ELWYNN, BASS))
			assert.are.same({ "day" }, windowsOf(fake, ELWYNN, MUD_SNAPPER))
		end)

		it(
			"has a zone with skillBase 205 whose subzone has its own skillBase, and gated Noise and removed items (STA-R12, STA-R16)",
			function()
				local FERALAS, FEATHERMOON = 357, 1116
				assert.are.equal(205, Pagle.GetArea(FERALAS).skillBase)
				assert.are.same(
					{ FERALAS, 300 },
					{ Pagle.GetZoneOf(FEATHERMOON), Pagle.GetArea(FEATHERMOON).skillBase }
				)
				assert.are.same({ "day" }, windowsOf(fake, FERALAS, MANA_POTION))
				assert.are.same({ "summer" }, windowsOf(fake, FERALAS, RUSTED_LURE))
			end
		)

		it("has a pool-associated item, a Noise item and a removed item (STA-R17, STA-R18)", function()
			assert.is_true(Pagle.GetItem(BLACKMOUTH).pool)
			assert.is_true(Pagle.GetItem(MANA_POTION).noise)
			assert.is_true(Pagle.GetItem(RUSTED_LURE).removed)
		end)

		it("has confirmed and unconfirmed entries, and confirmed and unconfirmed gates (LOG-R55)", function()
			local darkshore = Pagle.GetArea(DARKSHORE).catches
			assert.are.same({ MACKEREL, true }, { darkshore[1].itemID, darkshore[1].confirmed })
			assert.are.same(
				{ NIGHTFIN, false, false },
				{ darkshore[4].itemID, darkshore[4].confirmed, darkshore[4].gateConfirmed }
			)
			assert.are.same(
				{ BASS, true },
				{ Pagle.GetArea(ELWYNN).catches[2].itemID, Pagle.GetArea(ELWYNN).catches[2].gateConfirmed }
			)
		end)
	end)
end)
