-- Simulated Size on the client (LOG-R43, LOG-R65, LOG-R67, LOG-R68): the size every record Core hands out carries,
-- the same live, replayed and rebuilt, and the band list and rules version Core publishes.

-- Core over a saved log (`log`, a PagleLog, or none) with Oily Blackmouth's Species given a typical length of 300 mm
-- in the catalogue Core loaded, and the Ledger registered with a projection over `db` that keeps each Cast it's
-- handed, with its mode, in `applied`. Each Catch event's payload goes to `catches`.
local function sizedCore(log, db)
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
	loaded.ns.catalogue.items[6358].typicalLength = 300
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local Pagle = loaded.env.Pagle
	local applied, catches = {}, {}
	Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 }):NewProjection({
		db = db,
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			if record.kind == "cast" then
				applied[#applied + 1] = { mode = mode, cast = record }
			end
		end,
	})
	Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
		catches[#catches + 1] = catch
	end)
	return loaded, applied, catches
end

-- A copy of `t`, all the way down.
local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for key, value in pairs(t) do
		out[key] = copy(value)
	end
	return out
end

describe("Simulated Size on the client", function()
	it("publishes the Size bands in order as { key, name } and SIZE_RULES_VERSION 1 (LOG-R67, LOG-R68)", function()
		local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle

		assert.are.same({
			{ key = "tiddler", name = "Tiddler" },
			{ key = "typical", name = "Typical" },
			{ key = "hefty", name = "Hefty" },
			{ key = "whopper", name = "Whopper" },
			{ key = "monster", name = "Monster" },
		}, Pagle.SIZE_BANDS)
		assert.are.equal(1, Pagle.SIZE_RULES_VERSION)
	end)

	it("puts one size on the Catch event and on the Cast's item, whatever its quantity (LOG-R43, LOG-R65)", function()
		local loaded, applied, catches = sizedCore(nil, {})
		enterWorld(loaded)

		catchOne(loaded, { { link = OILY_BLACKMOUTH, quantity = 3 } })

		local catch = catches[1]
		assert.are.same(loaded.ns.SimulatedSize(catch.catchId, 300), catch.size)
		assert.are.same(catch.size, catch.cast.items[1].size)
		assert.are.same(catch.size, applied[#applied].cast.items[1].size)
		assert.are.equal("live", applied[#applied].mode)
	end)

	it("gives the same Cast the same size live, replayed, rebuilt and read back (LOG-R43, LOG-R65)", function()
		local loaded, _, catches = sizedCore(nil, {})
		enterWorld(loaded)
		catchOne(loaded)
		local cast, size = catches[1].cast, catches[1].size
		assert.is_table(size)
		local log = copy(loaded.env.PagleLog)

		-- The next login, twice: a projection that catches up from just before the Cast, and one that rebuilds.
		local replayDb = {
			projection = {},
			lastSeq = cast.seq - 1,
			logId = log.logId,
			fingerprint = loaded.env.Pagle.CONTENT_FINGERPRINT,
			rulesVersion = 1,
		}
		local replaying, replayed = sizedCore(copy(log), replayDb)
		enterWorld(replaying)
		local rebuilding, rebuilt = sizedCore(copy(log), {})
		enterWorld(rebuilding)

		-- The mode the Cast was applied in and its item's size, from what a projection was handed.
		local function handed(applied)
			for _, entry in ipairs(applied) do
				if entry.cast.id == cast.id then
					return { entry.mode, entry.cast.items[1].size }
				end
			end
		end
		assert.are.same({ "replay", size }, handed(replayed))
		assert.are.same({ "rebuild", size }, handed(rebuilt))
		assert.are.same(size, rebuilding.env.Pagle.IterateCatches(cast.seq - 1)().items[1].size)
	end)
end)
