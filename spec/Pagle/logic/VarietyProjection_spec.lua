-- Core's variety projection (VAR-R10, VAR-R11, VAR-R13, VAR-R90, LOG-R78) as pure logic: ns.AddVarietyProjection on
-- a real projection machinery over a saved log whose Casts carry Core's decoded varieties (VAR-R4), and
-- ns.VarietiesCaughtIn, what Pagle.GetVarietiesCaught returns.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's logId
local GUID = characterRecord().guid
local FINGERPRINT = "0123456789abcdef"
local FIREFIN, FIREFIN_FOLDED, OILY, UNCHARTED = 6359, 21153, 6358, 9999
local KEYS = { "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k10" }

-- A Species item of the catalogue's shape (VAR-R4), with its ten variety keys unless `varieties` is false.
---@param species integer
---@param varieties boolean
---@return PagleItem
local function fish(species, varieties)
	return {
		category = "fish",
		species = species,
		typicalLength = 300,
		legend = false,
		noise = false,
		varieties = varieties and KEYS or nil,
	}
end

-- The catalogue's items: the Firefin Snapper and a folded item of its Species with varieties, the Oily Blackmouth
-- without (as before a release gives it some), and nothing for 9999, an Uncharted item.
local function items()
	return {
		[FIREFIN] = fish(FIREFIN, true),
		[FIREFIN_FOLDED] = fish(FIREFIN, true),
		[OILY] = fish(OILY, false),
	}
end

-- The position of the first item of Ada's Cast at `time` (VAR-R3): its Catch ID is "<GUID>-<time>-0:1".
---@param time integer
---@param n integer? the item's place in the Cast; 1 by default
---@return integer
local function positionAt(time, n)
	return ns.VarietyIndex(("%s-%d-0:%d"):format(GUID, time, n or 1))
end

-- The first time from `from` on whose Cast's first item is at `position` (VAR-R3).
---@param position integer
---@param from integer
---@return integer
local function timeFor(position, from)
	local time = from
	while positionAt(time) ~= position do
		time = time + 1
	end
	return time
end

-- A caught Cast of Ada's at `time` with the items `itemIDs`, one of each, as a PagleLog entry.
---@param time integer
---@param itemIDs integer[]
---@return string
local function caught(time, itemIDs)
	local parts = {}
	for i, itemID in ipairs(itemIDs) do
		parts[i] = itemID .. "x1"
	end
	return ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||%s"):format(time, table.concat(parts, ","))
end

-- A Cast of Ada's at `time` that got away.
---@param time integer
---@return string
local function gotAway(time)
	return ("C1|1|%d|0|g|494|1439|1|148|453|86|25|263|||"):format(time)
end

-- A world over a saved log holding `entries` and a stored variety projection `db` (empty by default): the machinery
-- (frames the spec runs, chunked from more than `syncLimit` pending entries), the catalogue's items in `world.items`,
-- read at each decode, and each call of the projection's `changed` counted in `world.changed`, with whether the
-- projection was updating then in `world.updatingAtChange`.
local function newWorld(entries, db, syncLimit)
	local world = {
		db = db or {},
		fingerprint = FINGERPRINT,
		items = items(),
		now = 0,
		frames = {},
		changed = 0,
		updatingAtChange = {},
	}
	local catchLog = ns.OpenCatchLog(savedLog(entries), { decodeErrors = 0 }, SERVER_TIME, function(itemID)
		return world.items[itemID]
	end)
	world.catchLog = catchLog
	world.projections = ns.NewProjections({
		length = function()
			return #catchLog.data.entries
		end,
		logId = function()
			return catchLog.data.logId
		end,
		fingerprint = function()
			return world.fingerprint
		end,
		clock = function()
			world.now = world.now + 1 -- every step costs 1 ms
			return world.now
		end,
		nextFrame = function(step)
			world.frames[#world.frames + 1] = step
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		syncLimit = syncLimit,
		budget = 1, -- one step a frame
	})

	-- Login step 1: the projection binds.
	world.projection = ns.AddVarietyProjection({
		projections = world.projections,
		db = world.db,
		iterate = function(afterSeq)
			return catchLog:Iterate(afterSeq)
		end,
		changed = function()
			world.changed = world.changed + 1
			world.updatingAtChange[#world.updatingAtChange + 1] = world.projections:IsUpdating()
				and world.projections:Mode() ~= "done"
		end,
	})

	-- Login step 3: the catch-up or rebuild, run to its end unless `frames` limits the frames run.
	function world.enterWorld(frames)
		world.projections:Start(#catchLog.data.entries)
		world.runFrames(frames)
	end
	function world.runFrames(limit)
		local count = 0
		while #world.frames > 0 and (not limit or count < limit) do
			table.remove(world.frames, 1)()
			count = count + 1
		end
	end
	-- Appends Ada's caught Cast of `itemIDs` at `time` and hands it over live, as the Cast state machine does
	-- (LOG-R73).
	function world.live(time, itemIDs)
		local record = { kind = "cast", char = 1, time = time, outcome = "caught", items = {} }
		record.conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} }
		for i, itemID in ipairs(itemIDs) do
			record.items[i] = { itemID = itemID, quantity = 1 }
		end
		catchLog:Append(record)
		-- Live entries reach projections decoded, as Pagle.IterateCatches hands them out (LOG-R73).
		world.projections:Live(catchLog:Iterate(#catchLog.data.entries - 1)())
	end
	return world
end

-- A stored variety projection, up to date with a log of `lastSeq` entries, as login finds it in PagleDB.
local function stored(bySpecies, lastSeq)
	return {
		projection = { bySpecies = bySpecies },
		lastSeq = lastSeq,
		logId = LOG_ID,
		fingerprint = FINGERPRINT,
		rulesVersion = ns.VARIETY_RULES_VERSION,
	}
end

-- Times at which Ada's first Catch is at positions 1, 3 and 10 (the Epic), from SERVER_TIME - 90000 on.
local T1 = timeFor(1, SERVER_TIME - 90000)
local T3 = timeFor(3, T1 + 1)
local T10 = timeFor(10, T3 + 1)

describe("ns.AddVarietyProjection", function()
	it(
		"keeps each Species' positions caught from every caught Cast's items with a variety, folded items in their"
			.. " Species, after the catch-up (VAR-R10)",
		function()
			local world = newWorld({
				caught(T1, { FIREFIN }),
				caught(T3, { FIREFIN_FOLDED }),
				caught(T10, { FIREFIN }),
				caught(T10 + 1, { FIREFIN }), -- position positionAt(T10 + 1), maybe one of those above
			})

			world.enterWorld()

			local expected = { [1] = true, [3] = true, [10] = true, [positionAt(T10 + 1)] = true }
			assert.are.same({ bySpecies = { [FIREFIN] = expected } }, world.db.projection)
			assert.are.equal(1, world.db.rulesVersion) -- varieties.md › Data: rules version 1
			assert.are.equal(FINGERPRINT, world.db.fingerprint)
		end
	)

	it("counts every item of a Cast with a variety, each its own Catch (VAR-R10, VAR-R92)", function()
		local world = newWorld({ caught(T1, { FIREFIN, FIREFIN }) })

		world.enterWorld()

		assert.are.same({ [1] = true, [positionAt(T1, 2)] = true }, world.db.projection.bySpecies[FIREFIN])
	end)

	it(
		"adds nothing for a Species without varieties, an Uncharted item, a Cast that got away, or a purchase"
			.. " (VAR-R1, VAR-R10)",
		function()
			local world = newWorld({
				caught(T1, { OILY }),
				caught(T3, { UNCHARTED }),
				gotAway(T10),
				purchaseEntry(T10 + 1, "core.crest.elwynn", 150),
			})

			world.enterWorld()

			assert.are.same({ bySpecies = {} }, world.db.projection)
		end
	)

	it("calls changed once from its done, never while it catches up across frames (VAR-R13)", function()
		local entries = {}
		for i = 1, 6 do
			entries[i] = caught(T1 + i, { FIREFIN })
		end
		local world = newWorld(entries, nil, 0)

		world.enterWorld(4) -- some Casts applied, the finish not run yet
		assert.is_true(world.projection:IsUpdating())
		assert.are.equal(0, world.changed)

		world.runFrames()
		assert.are.equal(1, world.changed)
		assert.are.same({ false }, world.updatingAtChange)
	end)

	it(
		"calls changed from its done with nothing caught, so the earned goods are asked once anyway (VAR-R13)",
		function()
			local world = newWorld({})

			world.enterWorld()

			assert.are.equal(1, world.changed)
		end
	)

	it("applies a live Catch of a new variety and calls changed once (VAR-R10, VAR-R13)", function()
		local world = newWorld({ caught(T1, { FIREFIN }) })
		world.enterWorld()

		world.live(T10, { FIREFIN })

		assert.are.same({ [1] = true, [10] = true }, world.db.projection.bySpecies[FIREFIN])
		assert.are.equal(2, world.changed) -- the done's, then the live Catch's
	end)

	it("leaves changed alone for a live Catch of a variety already caught, or without one (VAR-R13)", function()
		local world = newWorld({ caught(T1, { FIREFIN }) })
		world.enterWorld()

		world.live(timeFor(1, T10 + 1), { FIREFIN })
		world.live(T10 + 1, { OILY, UNCHARTED })

		assert.are.same({ bySpecies = { [FIREFIN] = { [1] = true } } }, world.db.projection)
		assert.are.equal(1, world.changed) -- the done's only
	end)

	it(
		"rebuilds on a new content fingerprint, a reclassified item gaining its varieties and another losing them"
			.. " (VAR-R90, DATA-R71)",
		function()
			local entries = { caught(T1, { FIREFIN }), caught(T3, { OILY }) }
			local first = newWorld(entries)
			first.enterWorld()
			assert.are.same({ [FIREFIN] = { [1] = true } }, first.db.projection.bySpecies)

			local world = newWorld(entries, first.db)
			world.items[OILY] = fish(OILY, true) -- a release gives the Oily Blackmouth its ten
			world.items[FIREFIN] = nil -- and takes the Firefin Snapper out of the catalogue
			world.fingerprint = "a new release"
			world.enterWorld()

			assert.are.equal("a new release", world.db.fingerprint)
			assert.are.same({ bySpecies = { [OILY] = { [3] = true } } }, world.db.projection)
			assert.are.equal(1, world.changed)
		end
	)

	it("rebuilds on a new rules version (LOG-R72)", function()
		local db = stored({ [FIREFIN] = { [2] = true } }, 1)
		db.rulesVersion = 0
		local world = newWorld({ caught(T1, { FIREFIN }) }, db)

		world.enterWorld()

		assert.are.same({ bySpecies = { [FIREFIN] = { [1] = true } } }, world.db.projection)
		assert.are.equal(1, world.db.rulesVersion)
	end)

	it("catches up from the stored state, keeping the positions it stored (LOG-R71)", function()
		-- Stored up to seq 1 with position 2, which no entry in this log gives: only a catch-up keeps it.
		local db = stored({ [FIREFIN] = { [2] = true } }, 1)
		local world = newWorld({ caught(T1, { FIREFIN }), caught(T10, { FIREFIN }) }, db)

		world.enterWorld()

		assert.are.same({ bySpecies = { [FIREFIN] = { [2] = true, [10] = true } } }, world.db.projection)
	end)
end)

describe("ns.VarietiesCaughtIn", function()
	it("gives a Species' positions caught as a fresh set each call (VAR-R11)", function()
		local world = newWorld({ caught(T1, { FIREFIN }), caught(T10, { FIREFIN }) })
		world.enterWorld()

		local caught1 = ns.VarietiesCaughtIn(world.db, FIREFIN)
		caught1[2] = true

		assert.are.same({ [1] = true, [10] = true }, ns.VarietiesCaughtIn(world.db, FIREFIN))
		assert.are_not.equal(ns.VarietiesCaughtIn(world.db, FIREFIN), ns.VarietiesCaughtIn(world.db, FIREFIN))
		assert.are.same({ [1] = true, [10] = true }, world.db.projection.bySpecies[FIREFIN])
	end)

	it(
		"gives an empty set for a Species with none caught or without varieties, and before a first build (VAR-R11)",
		function()
			local world = newWorld({ caught(T1, { FIREFIN }) })
			assert.are.same({}, ns.VarietiesCaughtIn(world.db, FIREFIN))

			world.enterWorld()

			assert.are.same({}, ns.VarietiesCaughtIn(world.db, OILY))
			assert.are.same({}, ns.VarietiesCaughtIn(world.db, UNCHARTED))
			assert.are.same({}, ns.VarietiesCaughtIn(nil, FIREFIN))
		end
	)

	it("answers from the last stored state while a rebuild runs, then from the rebuilt one (LOG-R72)", function()
		local entries = {}
		for i = 1, 6 do
			entries[i] = caught(T1 + i, { OILY })
		end
		entries[#entries + 1] = caught(T10, { FIREFIN })
		local db = stored({ [FIREFIN] = { [1] = true, [3] = true } }, #entries)
		db.fingerprint = "an older release" -- DATA-R71: a new content fingerprint rebuilds it
		local world = newWorld(entries, db, 0)

		world.enterWorld(4)
		assert.is_true(world.projection:IsUpdating())
		assert.are.same({ [1] = true, [3] = true }, ns.VarietiesCaughtIn(world.db, FIREFIN))

		world.runFrames()
		assert.are.same({ [10] = true }, ns.VarietiesCaughtIn(world.db, FIREFIN))
	end)
end)

describe("ns.BindCoreProjections", function()
	it("binds the variety projection for the backend, after the wallet's, with its rules version (#223)", function()
		local bound = {}
		ns.BindCoreProjections(function(name, def)
			bound[#bound + 1] = { name, def.rulesVersion }
		end)

		assert.are.same({ { "wallet", ns.WALLET_RULES_VERSION }, { "varieties", ns.VARIETY_RULES_VERSION } }, bound)
	end)
end)
