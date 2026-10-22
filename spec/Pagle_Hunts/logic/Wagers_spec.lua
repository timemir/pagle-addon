-- Pagle Wagers on the board as data (HNT-R27, HNT-R53, HNT-R54, HNT-R163): an event Hunt's shape and its line, and the
-- run entry's pay rule. Pure logic, on the fixture event pool's Hunts and stand-in names. The strip, the WAGERS rows
-- and a whole run entry are checked on FakePagle (spec/Pagle_Hunts/adapter/Wagers_spec.lua).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue

-- Hunts' logic over the fixtures, and name stand-ins from the fixture catalogue's names.
local function load()
	local ns = hunts.load().ns
	local sources = {
		ItemName = function(itemID)
			return C.NAMES.items[itemID]
		end,
		BandName = function(band)
			return ({ [2] = "Hefty", [3] = "Trophy" })[band]
		end,
	}
	return ns, sources
end

-- An event Hunt over the fixture's Darkshore event, its fields `fields`.
local function eventHunt(ns, fields)
	fields.id = fields.id or "spec_hunt"
	fields.tiers = fields.tiers or { 1 }
	return ns.NewEventHunt(fields, { id = "spec_event", zones = { C.DARKSHORE } })
end

describe("an event Hunt's shape (HNT-R163, default chosen while building)", function()
	it('is "Timed" with a time condition, whatever else it has', function()
		local ns = load()
		local hunt = eventHunt(ns, { class = "species.any", minBand = 2, conditions = { time = { { 1320, 240 } } } })
		assert.are.equal("timed", ns.EventHuntShape(hunt))
	end)

	it('is "Big ones" with a minBand, "Quality" for a quality class, "Haul" for any fish, else "Named fish"', function()
		local ns = load()
		assert.are.equal("big", ns.EventHuntShape(eventHunt(ns, { species = C.NIGHTFIN, minBand = 2 })))
		assert.are.equal("quality", ns.EventHuntShape(eventHunt(ns, { class = "quality.uncommon" })))
		assert.are.equal("quality", ns.EventHuntShape(eventHunt(ns, { class = "quality.rare" })))
		assert.are.equal("haul", ns.EventHuntShape(eventHunt(ns, { class = "species.any" })))
		assert.are.equal("named", ns.EventHuntShape(eventHunt(ns, { species = C.NIGHTFIN })))
		assert.are.equal("named", ns.EventHuntShape(eventHunt(ns, { class = "fixed.oddity" })))
	end)
end)

describe("an event Hunt's line (HNT-R163, HNT-R53, HNT-R54)", function()
	it("reads its shape, its target line and its time words", function()
		local ns, sources = load()
		local grouper = eventHunt(ns, { species = C.NIGHTFIN, conditions = { time = { { 1320, 240 } } } })
		local big = eventHunt(ns, { species = C.BLACKMOUTH, minBand = 2 })
		local two = eventHunt(ns, { class = "species.any", conditions = { time = { { 0, 60 }, { 300, 360 } } } })

		assert.are.equal("Timed · Raw Nightfin Snapper, 22:00–04:00", ns.EventHuntLine(grouper, ns.hunts, sources))
		assert.are.equal("Big ones · Oily Blackmouth, Hefty or better", ns.EventHuntLine(big, ns.hunts, sources))
		assert.are.equal("Timed · Any fish, 00:00–01:00, 05:00–06:00", ns.EventHuntLine(two, ns.hunts, sources))
	end)
end)

describe("the run entry's pay rule (HNT-R163, HNT-R27)", function()
	it("comes from the Tunables, and claims no odds, chance or due fish", function()
		local ns = load()
		ns.XP_EVENT, ns.COINS_EVENT, ns.XP_RUN, ns.COINS_RUN = { 200, 120 }, { 20, 12 }, 300, 60

		local rule = ns.RunPayRule()

		assert.are.equal(
			"Each Hunt's first mark pays +200 XP and 20 Coins, each mark after it +120 XP and 12 Coins. "
				.. "Land every Hunt's first mark and the wager settles: +300 XP and 60 Coins more.",
			rule
		)
		for _, word in ipairs({ "odds", "chance", "due", "likely", "%%" }) do
			assert.is_nil(rule:lower():find(word))
		end
	end)
end)
