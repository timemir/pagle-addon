-- The Cast state machine (LOG-R2–R9) through ns.NewFishing, the logic/ seam Core's adapter feeds with the client's
-- fishing signals and a clock. What the client reports is passed in as plain values.

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local DRAIN_LIFE = 689

-- A state machine whose record step makes a Cast record the way the codec decodes one (LOG-R13), and a log of
-- every step it takes: each record call as { "record", outcome, items, startedAt } and each event fired as
-- { event, ... }.
local function watch()
	local steps = {}
	local casts = 0
	local fishing
	fishing = ns.NewFishing({
		isFishingSpell = function(spellID)
			return spellID == FISHING
		end,
		record = function(outcome, items, startedAt)
			steps[#steps + 1] = { "record", outcome, items, startedAt, fishing:GetState() }
			casts = casts + 1
			local id = "Player-1-00000001-" .. (1791731700 + casts) .. "-0"
			local cast = { seq = casts, id = id, kind = "cast", outcome = outcome, items = {} }
			for n, item in ipairs(items) do
				cast.items[n] = { n = n, itemID = item.itemID, quantity = item.quantity, catchId = id .. ":" .. n }
			end
			return cast
		end,
		fire = function(event, ...)
			steps[#steps + 1] = { event, ... }
		end,
	})
	return fishing, steps
end

-- The events fired, by name only, in order.
local function names(steps)
	local out = {}
	for i, step in ipairs(steps) do
		out[i] = step[1]
	end
	return out
end

-- Loot as the adapter reads it: a function returning the window's items.
local function loot(...)
	local items = { ... }
	return function()
		return items
	end
end

describe("the fishing channel", function()
	it("is a player channel of a fishing spell: the state becomes channeling and CastStarted fires (LOG-R2)", function()
		local fishing, steps = watch()

		fishing:ChannelStarted(FISHING, 10)

		assert.are.equal("channeling", fishing:GetState())
		assert.are.same({ { "CastStarted" }, { "FishingStateChanged", "channeling" } }, steps)
	end)

	it("starts nothing for a channel whose spell isn't on the fishing-spell list (LOG-R2)", function()
		local fishing, steps = watch()

		fishing:ChannelStarted(DRAIN_LIFE, 10)
		fishing:ChannelStopped(DRAIN_LIFE, 15)

		assert.are.equal("idle", fishing:GetState())
		assert.are.same({}, steps)
	end)

	it("starts idle (LOG-R2)", function()
		assert.are.equal("idle", (watch()):GetState())
	end)
end)

describe("a Cast that ends caught", function()
	it(
		"ends at a fishing LOOT_READY with the window's items, in LOG-R9's order: record, Catch per item, CastEnded,"
			.. " then the state (LOG-R3, LOG-R9)",
		function()
			local fishing, steps = watch()
			fishing:ChannelStarted(FISHING, 10)

			fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }, { itemID = 6303, quantity = 2 }), 14)

			local cast = steps[4][2].cast
			assert.are.same({
				"CastStarted",
				"FishingStateChanged",
				"record",
				"Catch",
				"Catch",
				"CastEnded",
				"FishingStateChanged",
			}, names(steps))
			assert.are.same({
				"record",
				"caught",
				{ { itemID = 6358, quantity = 1 }, { itemID = 6303, quantity = 2 } },
				10,
				"channeling",
			}, steps[3])
			assert.are.same({
				catchId = "Player-1-00000001-1791731701-0:1",
				itemID = 6358,
				quantity = 1,
				n = 1,
				cast = cast,
			}, steps[4][2])
			assert.are.same({
				catchId = "Player-1-00000001-1791731701-0:2",
				itemID = 6303,
				quantity = 2,
				n = 2,
				cast = cast,
			}, steps[5][2])
			assert.are.equal(cast, steps[5][2].cast)
			assert.are.same({ "CastEnded", "caught", cast }, steps[6])
			assert.are.equal(cast, steps[6][3])
			assert.are.same({ "FishingStateChanged", "looting" }, steps[7])
		end
	)

	it("keeps looting until LOOT_CLOSED, then idles (LOG-R3)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }), 14)
		fishing:ChannelStopped(FISHING, 14)
		assert.are.equal("looting", fishing:GetState())

		fishing:LootClosed(15)

		assert.are.equal("idle", fishing:GetState())
		assert.are.same({ "FishingStateChanged", "idle" }, steps[#steps])
	end)

	it("ends caught at loot that comes after the channel stopped, within the grace time (LOG-R3, LOG-R7)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		local graceEnded = fishing:ChannelStopped(FISHING, 14)

		fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }), 14.3)
		assert(graceEnded)()

		assert.are.same({ "CastEnded", "caught" }, { steps[5][1], steps[5][2] })
		assert.are.same({ "FishingStateChanged", "looting" }, steps[6])
		assert.are.equal(6, #steps)
	end)

	it("ignores a second LOOT_READY before LOOT_CLOSED: it's the same window (LOG-R4)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }), 14)
		local count = #steps

		fishing:LootReady(true, loot({ itemID = 6303, quantity = 1 }), 14.1)

		assert.are.equal(count, #steps)
		assert.are.equal("looting", fishing:GetState())
	end)

	it("records the next window after LOOT_CLOSED as a new Cast (LOG-R4, LOG-R5)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }), 14)
		fishing:LootClosed(15)
		local count = #steps

		fishing:LootReady(true, loot({ itemID = 6303, quantity = 1 }), 40)

		assert.are.same({ "record", "Catch", "CastEnded", "FishingStateChanged" }, { unpack(names(steps), count + 1) })
	end)

	it("ends caught at fishing loot with no channel seen, as after a reload mid-cast (LOG-R5)", function()
		local fishing, steps = watch()

		fishing:LootReady(true, loot({ itemID = 12238, quantity = 1 }), 3)

		assert.are.same({ "record", "Catch", "CastEnded", "FishingStateChanged" }, names(steps))
		assert.are.same({ "record", "caught", { { itemID = 12238, quantity = 1 } }, nil, "idle" }, steps[1])
		assert.are.same({ "FishingStateChanged", "looting" }, steps[4])
	end)

	it("ignores a loot window that isn't fishing loot, leaving the Cast running (LOG-R3)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		local read = false

		fishing:LootReady(false, function()
			read = true
			return {}
		end, 12)
		fishing:LootClosed(13)

		assert.is_false(read)
		assert.are.same({ "CastStarted", "FishingStateChanged" }, names(steps))
		assert.are.equal("channeling", fishing:GetState())
	end)

	it("counts a window whose IsFishingLoot is secret as fishing only during a Cast (LOG-R3, LOG-R93)", function()
		local idle, idleSteps = watch()
		idle:LootReady(nil, loot({ itemID = 2589, quantity = 1 }), 3)
		assert.are.same({}, idleSteps)

		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		fishing:LootReady(nil, loot({ itemID = 6358, quantity = 1 }), 14)
		assert.are.same({ "CastEnded", "caught" }, { steps[#steps - 1][1], steps[#steps - 1][2] })
	end)

	it("fires an empty-handed caught Cast's CastEnded with no Catch (LOG-R9)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)

		fishing:LootReady(true, loot(), 14)

		assert.are.same(
			{ "CastStarted", "FishingStateChanged", "record", "CastEnded", "FishingStateChanged" },
			names(steps)
		)
	end)
end)

describe("a Cast that ends got away", function()
	it("ends at the escaped message during the channel, with no items, then idles (LOG-R6, LOG-R9)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)

		fishing:Escaped(25)

		assert.are.same({ "record", "gotAway", {}, 10, "channeling" }, steps[3])
		assert.are.same({ "CastEnded", "gotAway" }, { steps[4][1], steps[4][2] })
		assert.are.same({ "FishingStateChanged", "idle" }, steps[5])
		assert.are.equal(5, #steps)
		assert.are.equal("idle", fishing:GetState())
	end)

	it("ends at the escaped message within the grace time after the channel stops (LOG-R6)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		local graceEnded = fishing:ChannelStopped(FISHING, 25)

		fishing:Escaped(26.9)
		assert(graceEnded)()

		assert.are.same(
			{ "CastStarted", "FishingStateChanged", "record", "CastEnded", "FishingStateChanged" },
			names(steps)
		)
		assert.are.equal("gotAway", steps[4][2])
	end)

	it("ignores the escaped message with no Cast in progress (LOG-R6)", function()
		local fishing, steps = watch()

		fishing:Escaped(5)

		assert.are.same({}, steps)
	end)
end)

describe("a Cast that's interrupted", function()
	it(
		"ends when the grace time passes with no loot or escaped message: CastEnded(interrupted), nothing"
			.. " recorded, then idle (LOG-R7)",
		function()
			local fishing, steps = watch()
			fishing:ChannelStarted(FISHING, 10)
			local graceEnded = fishing:ChannelStopped(FISHING, 12)

			assert(graceEnded)()

			assert.are.same(
				{ { "CastEnded", "interrupted" }, { "FishingStateChanged", "idle" } },
				{ steps[3], steps[4] }
			)
			assert.are.equal(4, #steps)
			assert.are.equal("idle", fishing:GetState())
		end
	)

	it("stays channeling through the grace time, until the Cast ends (LOG-R7)", function()
		local fishing = watch()
		fishing:ChannelStarted(FISHING, 10)
		fishing:ChannelStopped(FISHING, 12)

		assert.are.equal("channeling", fishing:GetState())
	end)

	it("ignores loot or the escaped message that comes after the grace time ended it (LOG-R7)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		assert(fishing:ChannelStopped(FISHING, 12))()
		local count = #steps

		fishing:Escaped(14.5)

		assert.are.equal(count, #steps)
	end)

	it("records fishing loot that comes after the grace time as a new no-channel Cast (LOG-R7, LOG-R5)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		local graceEnded = fishing:ChannelStopped(FISHING, 12)

		fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }), 14.5)
		assert(graceEnded)()

		assert.are.same({
			"CastStarted",
			"FishingStateChanged",
			"CastEnded",
			"FishingStateChanged",
			"record",
			"Catch",
			"CastEnded",
			"FishingStateChanged",
		}, names(steps))
		assert.are.equal("interrupted", steps[3][2])
		assert.are.same({ "FishingStateChanged", "idle" }, steps[4])
		assert.are.same({ "record", "caught", { { itemID = 6358, quantity = 1 } }, nil, "idle" }, steps[5])
		assert.are.equal("caught", steps[7][2])
		assert.are.equal("looting", fishing:GetState())
	end)

	it("ends before a signal that comes after the grace time but before its timer ran (LOG-R7)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		local graceEnded = fishing:ChannelStopped(FISHING, 12)

		fishing:Escaped(14.5)
		assert(graceEnded)()

		assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "FishingStateChanged" }, names(steps))
		assert.are.equal("interrupted", steps[3][2])
	end)

	it("ends at a recast within the grace time: its CastEnded comes before the new CastStarted (LOG-R7)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		local graceEnded = fishing:ChannelStopped(FISHING, 12)

		fishing:ChannelStarted(FISHING, 13)
		assert(graceEnded)()

		assert.are.same({
			{ "CastStarted" },
			{ "FishingStateChanged", "channeling" },
			{ "CastEnded", "interrupted" },
			{ "CastStarted" },
		}, steps)
		assert.are.equal("channeling", fishing:GetState())
	end)

	it("ends at a new fishing channel with no stop seen in between (LOG-R7)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)

		fishing:ChannelStarted(FISHING, 11)

		assert.are.same({ "CastStarted", "FishingStateChanged", "CastEnded", "CastStarted" }, names(steps))
	end)

	it("keeps looting when a Cast started over an open loot window is interrupted (LOG-R3, LOG-R7)", function()
		local fishing, steps = watch()
		fishing:LootReady(true, loot({ itemID = 6358, quantity = 1 }), 3)
		fishing:ChannelStarted(FISHING, 4)
		assert(fishing:ChannelStopped(FISHING, 5))()

		assert.are.same({ "FishingStateChanged", "looting" }, steps[#steps])
		fishing:LootClosed(8)
		assert.are.equal("idle", fishing:GetState())
	end)
end)

describe("each Cast", function()
	it("ends exactly once, whatever signals for it follow (LOG-R7)", function()
		local fishing, steps = watch()
		fishing:ChannelStarted(FISHING, 10)
		fishing:Escaped(20)
		local graceEnded = fishing:ChannelStopped(FISHING, 20.1)
		fishing:Escaped(20.2)
		fishing:LootReady(false, loot(), 20.3)

		assert.is_nil(graceEnded)
		local ended = 0
		for _, step in ipairs(steps) do
			ended = ended + (step[1] == "CastEnded" and 1 or 0)
		end
		assert.are.equal(1, ended)
	end)

	it("still ends, and the state still follows, when recording raises; the error goes on to the caller", function()
		local steps = {}
		local fishing = ns.NewFishing({
			isFishingSpell = function()
				return true
			end,
			record = function()
				error("can't write", 0)
			end,
			fire = function(event, ...)
				steps[#steps + 1] = { event, ... }
			end,
		})
		fishing:ChannelStarted(FISHING, 10)

		assert.has_error(function()
			fishing:Escaped(12)
		end, "can't write")

		assert.are.equal("idle", fishing:GetState())
		assert.are.same({ "FishingStateChanged", "idle" }, steps[#steps])
		fishing:Escaped(12.5)
		assert.are.equal(3, #steps)
	end)
end)

describe("a loot slot", function()
	local function isSecret(value)
		return value == "secret"
	end

	it("keeps an item's ID from its link, and its quantity (LOG-R3)", function()
		local link = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"

		assert.are.same({ itemID = 6358, quantity = 3 }, ns.LootItem(isSecret, link, 3, nil, false))
	end)

	it("skips money and currency slots (LOG-R3)", function()
		assert.is_nil(ns.LootItem(isSecret, nil, 0, nil, true))
		assert.is_nil(ns.LootItem(isSecret, "|cff00aaff|Hcurrency:1901:0|h[Coin]|h|r", 5, 1901, false))
	end)

	it("records an item whose link is secret as item 0 (LOG-R8, CORE-R85)", function()
		assert.are.same({ itemID = 0, quantity = 1 }, ns.LootItem(isSecret, "secret", 1, nil, false))
	end)

	it("counts a secret quantity as 1, the least a slot offers (LOG-R8)", function()
		assert.are.same(
			{ itemID = 6358, quantity = 1 },
			ns.LootItem(isSecret, "|Hitem:6358::|h[Oily Blackmouth]|h", "secret", nil, false)
		)
	end)

	it("counts a quantity below 1 or not whole as 1, which the log's grammar holds (LOG-R8)", function()
		local link = "|Hitem:6358::|h[Oily Blackmouth]|h"
		for _, quantity in ipairs({ 0, -2, 1.5 }) do
			assert.are.same({ itemID = 6358, quantity = 1 }, ns.LootItem(isSecret, link, quantity, nil, false))
		end
	end)

	it("skips a slot with no link to read an item from (LOG-R3)", function()
		assert.is_nil(ns.LootItem(isSecret, nil, 1, nil, false))
	end)
end)
