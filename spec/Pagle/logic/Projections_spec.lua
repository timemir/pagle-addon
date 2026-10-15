-- The projection machinery (LOG-R70–R77, LOG-R90–R92, CORE-R80, CORE-R81, DATA-R71) through ns.NewProjections, the
-- logic/ seam Core's adapter wraps: fed the Catch log's records, a clock and a frame scheduler the spec drives.

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's logId
local FINGERPRINT = "0123456789abcdef"

-- Entry `i` of a log: a caught Cast by Ada, `i` seconds after 1791731000.
local function cast(i)
	return ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||6358x1"):format(1791731000 + i)
end
local SKILL = "S1|1|1791730000|0|80|150|0"
local BUILD = "B1|1|1791730000|1|70338|1.60.1"

-- `n` Casts.
local function casts(n)
	local entries = {}
	for i = 1, n do
		entries[i] = cast(i)
	end
	return entries
end

-- A machinery over a saved log holding `entries`, with a clock in ms and frames the spec runs (`world.frames`).
-- `world.fingerprint` is the content fingerprint; errors Module code raises go to `world.reported`.
local function machinery(entries)
	local catchLog = ns.OpenCatchLog(savedLog(entries), { decodeErrors = 0 }, SERVER_TIME)
	local world = { now = 0, frames = {}, fingerprint = FINGERPRINT, catchLog = catchLog, reported = {} }
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
			return world.now
		end,
		nextFrame = function(step)
			world.frames[#world.frames + 1] = step
		end,
		call = function(fn, ...)
			local results = { pcall(fn, ...) }
			if not results[1] then
				world.reported[#world.reported + 1] = tostring(results[2])
				return
			end
			return unpack(results, 2, table.maxn(results))
		end,
	})
	-- Runs the frames queued so far, one per frame; returns false once none is left.
	function world.frame()
		local step = table.remove(world.frames, 1)
		if not step then
			return false
		end
		step()
		return true
	end
	function world.runFrames()
		local count = 0
		while world.frame() do
			count = count + 1
		end
		return count
	end
	-- Appends a Cast and hands it to the machinery live, as Core does (LOG-R9, LOG-R73).
	function world.append(i)
		local record = catchLog:Append({
			kind = "cast",
			char = 1,
			time = 1791740000 + i,
			outcome = "caught",
			conditions = {
				minute = 494,
				zone = 148,
				subzone = 453,
				events = {},
				auras = {},
			},
			items = { { itemID = 6358, quantity = 1 } },
		})
		world.projections:Live(record)
		return record
	end
	-- Appends a Module record of `module` and hands it to the machinery live, as M:AppendRecord does (LOG-R40).
	function world.appendRecord(module, kind)
		local record = catchLog:Append({
			kind = "module",
			char = 1,
			time = 1791750000,
			module = module,
			recordKind = kind,
			payload = "",
		})
		world.projections:Live(record)
		return record
	end
	return world
end

-- A projection definition over `db` that notes what it's handed: `seen.applied` as "<seq> <mode>", `seen.done` as
-- each done's info. Its state counts the entries applied.
local function recorder(db, extra)
	local seen = { applied = {}, done = {} }
	local def = {
		db = db,
		rulesVersion = 7,
		reset = function()
			return { count = 0 }
		end,
		apply = function(state, record, mode)
			state.count = state.count + 1
			seen.applied[#seen.applied + 1] = record.seq .. " " .. mode
		end,
		done = function(state, info)
			seen.done[#seen.done + 1] =
				{ firstBuild = info.firstBuild, rebuilt = info.rebuilt, replayed = info.replayed }
			seen.doneState = state
		end,
	}
	for key, value in pairs(extra or {}) do
		def[key] = value
	end
	return def, seen
end

-- `def`, its apply taking 1 ms of the world's clock each time.
local function costly(world, def)
	local apply = def.apply
	def.apply = function(...)
		world.now = world.now + 1
		apply(...)
	end
	return def
end

-- Binds `def` to the machinery, iterating its Catch log as `module` does (M:IterateCatches), or as Core does without.
local function bind(world, def, module)
	local projection, problem = world.projections:Add(def, function(afterSeq)
		return world.catchLog:Iterate(afterSeq, module)
	end, module)
	assert(projection, problem)
	return projection
end

-- A db as a finished build over the first `lastSeq` entries leaves it.
local function builtDb(lastSeq, overrides)
	local db = {
		projection = { count = lastSeq },
		lastSeq = lastSeq,
		logId = LOG_ID,
		fingerprint = FINGERPRINT,
		rulesVersion = 7,
	}
	for key, value in pairs(overrides or {}) do
		db[key] = value
	end
	return db
end

describe("a projection's first build", function()
	it(
		"rebuilds a fresh projection from seq 0 once, with firstBuild over a log with Casts (LOG-R72, LOG-R76)",
		function()
			local world = machinery(casts(3))
			local db = {}
			local def, seen = recorder(db)
			bind(world, def)

			world.projections:Start(3)
			world.runFrames()

			assert.are.same({ "1 rebuild", "2 rebuild", "3 rebuild" }, seen.applied)
			assert.are.same({ { firstBuild = true, rebuilt = true, replayed = 0 } }, seen.done)
		end
	)

	it("keeps the state, lastSeq, logId, fingerprint and rulesVersion in def.db (LOG-R70)", function()
		local world = machinery(casts(2))
		local db = {}
		bind(world, (recorder(db)))

		world.projections:Start(2)
		world.runFrames()

		assert.are.same(builtDb(2), db)
	end)

	it("has no firstBuild over a log with only builds and Skill Readings (LOG-R76, LOG-R92)", function()
		local world = machinery({ BUILD, SKILL })
		local def, seen = recorder({})
		bind(world, def)

		world.projections:Start(2)
		world.runFrames()

		assert.are.same({ { firstBuild = false, rebuilt = true, replayed = 0 } }, seen.done)
	end)
end)

describe("a projection's catch-up", function()
	it(
		"applies the entries after lastSeq up to loginSeq as replay, counting them (LOG-R71, LOG-R76, LOG-R90)",
		function()
			local world = machinery(casts(5))
			local db = builtDb(2)
			local def, seen = recorder(db)
			bind(world, def)

			world.projections:Start(4)
			world.runFrames()

			assert.are.same({ "3 replay", "4 replay", "5 live" }, seen.applied)
			assert.are.same({ { firstBuild = false, rebuilt = false, replayed = 2 } }, seen.done)
			assert.are.same(builtDb(5), db)
		end
	)

	it("calls done after a catch-up with nothing to apply (LOG-R76, CORE-R80)", function()
		local world = machinery(casts(2))
		local def, seen = recorder(builtDb(2))
		bind(world, def)

		world.projections:Start(2)
		world.runFrames()

		assert.are.same({}, seen.applied)
		assert.are.same({ { firstBuild = false, rebuilt = false, replayed = 0 } }, seen.done)
	end)
end)

describe("a stored projection", function()
	local triggers = {
		{ "its projection is missing", { projection = false } },
		{ "its logId is another log's", { logId = "ffffffffffffffff" } },
		{ "its lastSeq is past the log's end (an older backup)", { lastSeq = 4 } },
		{ "its fingerprint is another release's (DATA-R71)", { fingerprint = "fedcba9876543210" } },
		{ "its rulesVersion is another one", { rulesVersion = 6 } },
	}
	for _, trigger in ipairs(triggers) do
		it("rebuilds from seq 0 when " .. trigger[1] .. " (LOG-R72)", function()
			local world = machinery(casts(3))
			local overrides = trigger[2]
			local db = builtDb(2, overrides)
			if overrides.projection == false then
				db.projection = nil
			end
			local def, seen = recorder(db)
			bind(world, def)

			world.projections:Start(3)
			world.runFrames()

			assert.are.same({ "1 rebuild", "2 rebuild", "3 rebuild" }, seen.applied)
			assert.are.same({ { firstBuild = overrides.projection == false, rebuilt = true, replayed = 0 } }, seen.done)
			assert.are.same(builtDb(3), db)
		end)
	end

	it(
		"rebuilds when its own extraFingerprint changes, and stores it with the content one (LOG-R70, DATA-R72)",
		function()
			local world = machinery(casts(1))
			local db = builtDb(1)
			local def, seen = recorder(db, { extraFingerprint = "hunts1" })
			bind(world, def)

			world.projections:Start(1)
			world.runFrames()

			assert.are.same({ "1 rebuild" }, seen.applied)
			assert.are.equal(FINGERPRINT .. "+hunts1", db.fingerprint)
		end
	)

	it("keeps the Module's celebrated set, outside projection, through a rebuild (LOG-R77)", function()
		local world = machinery(casts(1))
		local db = builtDb(1, { rulesVersion = 6 })
		db.celebrated = { level = 4 }
		bind(world, (recorder(db)))

		world.projections:Start(1)
		world.runFrames()

		assert.are.same({ level = 4 }, db.celebrated)
	end)
end)

describe("a catch-up or rebuild of many entries", function()
	it("applies 501 pending entries over several frames, within the budget, updating until done (LOG-R71)", function()
		local world = machinery(casts(501))
		local def, seen = recorder({})
		local projection = bind(world, costly(world, def))
		local perFrame = {}

		world.projections:Start(501)
		assert.are.same({}, seen.applied)
		while #seen.done == 0 do
			assert.is_true(projection:IsUpdating())
			assert.is_true(world.projections:IsUpdating())
			local before, started = #seen.applied, world.now
			assert.is_true(world.frame())
			perFrame[#perFrame + 1] = #seen.applied - before
			assert.is_true(world.now - started <= ns.PROJECTION_BUDGET)
		end

		assert.are.equal(501, #seen.applied)
		assert.are.equal(127, #perFrame) -- 4 entries per 4 ms frame, then done in a frame of its own (#79)
		assert.is_false(projection:IsUpdating())
		assert.are.equal(501, projection:GetState().count)
	end)

	it("never runs a frame past the budget when entries cost unevenly (LOG-R71, #79)", function()
		-- Entries cost 2, 1, 3, 2, 1, 3 ... ms: checked only before each apply, a frame of 2 + 1 would go on to the
		-- 3 and spend 6 ms. The chunk stops once the budget left can't fit another entry as costly as this frame's
		-- costliest.
		local world = machinery(casts(501))
		local def, seen = recorder({})
		local apply, costs = def.apply, { 2, 1, 3 }
		def.apply = function(state, record, mode)
			world.now = world.now + costs[(record.seq - 1) % #costs + 1]
			apply(state, record, mode)
		end
		bind(world, def)

		world.projections:Start(501)
		repeat
			local started = world.now
			local ran = world.frame()
			assert.is_true(world.now - started <= ns.PROJECTION_BUDGET)
		until not ran

		assert.are.equal(501, #seen.applied)
		assert.are.equal(1, #seen.done)
	end)

	it(
		"runs done in a frame of its own, then the entries appended meanwhile, each frame within the budget"
			.. " (LOG-R71, LOG-R74, LOG-R76, #79)",
		function()
			-- Applies cost 1 ms and done 3 ms. Run in the frame that finds the end, done and the three live entries
			-- would take 1 + 3 + 3 ms.
			local world = machinery(casts(501))
			local def, seen = recorder({})
			local done = def.done
			def.done = function(state, info)
				world.now = world.now + 3
				done(state, info)
				seen.applied[#seen.applied + 1] = "done"
			end
			bind(world, costly(world, def))

			world.projections:Start(501)
			world.frame()
			world.append(1)
			world.append(2)
			world.append(3)
			repeat
				local started = world.now
				local ran = world.frame()
				assert.is_true(world.now - started <= ns.PROJECTION_BUDGET)
			until not ran

			assert.are.same(
				{ "501 rebuild", "done", "502 live", "503 live", "504 live" },
				{ unpack(seen.applied, 501) }
			)
			assert.is_false(world.projections:IsUpdating())
		end
	)

	it(
		"stays updating after done until the entries appended during the update are applied, reading false in done"
			.. " (LOG-R74)",
		function()
			-- Done costs 3 ms, so the entries appended during the update are applied in a later frame than done's.
			local world = machinery(casts(501))
			local def, seen = recorder({})
			local projection
			local inDone = {}
			local done = def.done
			def.done = function(state, info)
				world.now = world.now + 3
				inDone[#inDone + 1] = projection:IsUpdating()
				done(state, info)
			end
			projection = bind(world, costly(world, def))

			world.projections:Start(501)
			world.frame()
			world.append(1)
			world.append(2)
			while #seen.done == 0 do
				assert.is_true(world.frame())
			end

			assert.are.same({ false }, inDone)
			assert.are.equal("501 rebuild", seen.applied[#seen.applied])
			assert.is_true(projection:IsUpdating()) -- 502 and 503 aren't applied yet
			world.runFrames()
			assert.are.same({ "502 live", "503 live" }, { unpack(seen.applied, 502) })
			assert.is_false(projection:IsUpdating())
		end
	)

	it("applies 500 pending entries at once, done before Start returns (LOG-R71)", function()
		local world = machinery(casts(500))
		local def, seen = recorder({})
		bind(world, def)

		world.projections:Start(500)

		assert.are.equal(500, #seen.applied)
		assert.are.equal(1, #seen.done)
		assert.are.same({}, world.frames)
	end)

	it(
		"leaves the stored values as they were when a rebuild is cut short, so the next login rebuilds from seq 0"
			.. " with the same firstBuild (LOG-R72)",
		function()
			local entries = casts(600)
			local world = machinery(entries)
			local db = {}
			bind(world, costly(world, (recorder(db))))
			world.projections:Start(600)
			world.frame() -- one chunk, then the player logs out
			assert.are.same({}, db)

			local nextLogin = machinery(entries)
			local def, seen = recorder(db)
			bind(nextLogin, def)
			nextLogin.projections:Start(600)
			nextLogin.runFrames()

			assert.are.equal("1 rebuild", seen.applied[1])
			assert.are.same({ { firstBuild = true, rebuilt = true, replayed = 0 } }, seen.done)
		end
	)

	it("keeps lastSeq with the state when a chunked catch-up is cut short, resuming there (LOG-R71)", function()
		local entries = casts(1000)
		local world = machinery(entries)
		local db = builtDb(10)
		bind(world, costly(world, (recorder(db))))
		world.projections:Start(1000)
		world.frame()
		assert.are.same({ 14, 14 }, { db.lastSeq, db.projection.count })

		local nextLogin = machinery(entries)
		local resumed, seen = recorder(db)
		bind(nextLogin, resumed)
		nextLogin.projections:Start(1000)
		nextLogin.runFrames()

		assert.are.equal("15 replay", seen.applied[1])
		assert.are.equal(1000, db.projection.count)
	end)

	it("shares one budget per frame between the projections, in the order they were added (LOG-R71)", function()
		local world = machinery(casts(600))
		local first, firstSeen = recorder({})
		local second, secondSeen = recorder({})
		bind(world, costly(world, first))
		bind(world, costly(world, second))

		world.projections:Start(600)
		world.frame()

		assert.are.same({ 4, 0 }, { #firstSeen.applied, #secondSeen.applied })
		world.runFrames()
		assert.are.same({ 600, 600 }, { #firstSeen.applied, #secondSeen.applied })
	end)
end)

describe("live entries", function()
	it("are applied at once as live, setting lastSeq, while the projection is up to date (LOG-R73)", function()
		local world = machinery(casts(2))
		local db = builtDb(2)
		local def, seen = recorder(db)
		bind(world, def)
		world.projections:Start(2)

		local record = world.append(1)

		assert.are.same({ "3 live" }, seen.applied)
		assert.are.equal(3, record.seq)
		assert.are.equal(3, db.lastSeq)
	end)

	it("appended during an update are applied once, as live, after done and in order (LOG-R74)", function()
		local world = machinery(casts(600))
		local def, seen = recorder({})
		bind(world, costly(world, def))
		world.projections:Start(600)
		world.frame()
		assert.are.equal(4, #seen.applied)

		world.append(1)
		world.append(2)
		world.runFrames()

		assert.are.equal(602, #seen.applied)
		assert.are.same({ "600 rebuild", "601 live", "602 live" }, { unpack(seen.applied, 600, 602) })
		assert.are.equal(1, #seen.done)
	end)

	it("appended before Start are live, never replayed, after the catch-up (LOG-R1, LOG-R74)", function()
		local world = machinery(casts(2))
		local def, seen = recorder(builtDb(1))
		bind(world, def)

		world.append(1) -- e.g. a Skill Reading during login
		world.projections:Start(2)

		assert.are.same({ "2 replay", "3 live" }, seen.applied)
	end)

	it("handed over during an apply are applied after it returns (LOG-R40)", function()
		local world = machinery(casts(1))
		local def, seen = recorder(builtDb(1))
		local apply = def.apply
		def.apply = function(state, record, mode)
			apply(state, record, mode)
			if record.seq == 2 then
				world.append(2)
				seen.applied[#seen.applied + 1] = "returned"
			end
		end
		bind(world, def)
		world.projections:Start(1)

		world.append(1)

		assert.are.same({ "2 live", "returned", "3 live" }, seen.applied)
	end)

	it("reach a projection added after Start once it has caught up (LOG-R1)", function()
		local world = machinery(casts(2))
		world.projections:Start(2)
		world.append(1)

		local def, seen = recorder(builtDb(1))
		bind(world, def)

		assert.are.same({ "2 replay", "3 live" }, seen.applied)
	end)
end)

describe("Module records", function()
	-- The Tackle Board's projection, the Ledger's and Core's own (no Module), each up to date over 2 Casts.
	local function threeProjections(world)
		local board, boardSeen = recorder(builtDb(2))
		local ledger, ledgerSeen = recorder(builtDb(2))
		local core, coreSeen = recorder(builtDb(2))
		bind(world, board, "TackleBoard")
		bind(world, ledger, "Ledger")
		bind(world, core)
		return { board = board.db, ledger = ledger.db, core = core.db }, {
			board = boardSeen.applied,
			ledger = ledgerSeen.applied,
			core = coreSeen.applied,
		}
	end

	it(
		"reach only their Module's projections live; the others still reach the log's length in lastSeq"
			.. " (LOG-R41, LOG-R73)",
		function()
			local world = machinery(casts(2))
			local dbs, applied = threeProjections(world)
			world.projections:Start(2)

			world.appendRecord("TackleBoard", "day")

			assert.are.same({ "3 live" }, applied.board)
			assert.are.same({}, applied.ledger)
			assert.are.same({}, applied.core)
			assert.are.same({ 3, 3, 3 }, { dbs.board.lastSeq, dbs.ledger.lastSeq, dbs.core.lastSeq })
		end
	)

	it(
		"appended during an update reach their Module after done, in order with the other queued entries, and the"
			.. " others' lastSeq still ends at the log's length (LOG-R41, LOG-R74)",
		function()
			local world = machinery(casts(2))
			local dbs, applied = threeProjections(world)

			world.appendRecord("TackleBoard", "start") -- from the Module's login code (LOG-R1)
			world.append(1)
			world.appendRecord("TackleBoard", "day")
			world.appendRecord("Ledger", "note")
			world.projections:Start(2)

			assert.are.same({ "3 live", "4 live", "5 live" }, applied.board)
			assert.are.same({ "4 live", "6 live" }, applied.ledger)
			assert.are.same({ "4 live" }, applied.core)
			assert.are.same({ 6, 6, 6 }, { dbs.board.lastSeq, dbs.ledger.lastSeq, dbs.core.lastSeq })
		end
	)

	it(
		"are skipped by a catch-up and rebuild of another's projection, which still ends at the target (LOG-R41)",
		function()
			local world = machinery(casts(2))
			world.appendRecord("TackleBoard", "start")
			local caughtUp, caughtUpSeen = recorder(builtDb(1))
			local rebuilt, rebuiltSeen = recorder({})
			bind(world, caughtUp, "Ledger")
			bind(world, rebuilt)

			world.projections:Start(3)

			assert.are.same({ "2 replay" }, caughtUpSeen.applied)
			assert.are.same({ "1 rebuild", "2 rebuild" }, rebuiltSeen.applied)
			assert.are.same({ 3, 3 }, { caughtUp.db.lastSeq, rebuilt.db.lastSeq })
		end
	)
end)

describe("the machinery's seams", function()
	it("tells the mode of the apply in progress, done while done runs, and none otherwise (LOG-R75, ANN-R4)", function()
		local world = machinery(casts(2))
		local modes = {}
		local def = recorder(builtDb(1))
		def.apply = function()
			modes[#modes + 1] = world.projections:Mode()
		end
		def.done = function()
			modes[#modes + 1] = world.projections:Mode()
		end
		bind(world, def)

		world.projections:Start(2)
		world.append(1)

		assert.are.same({ "replay", "done", "live" }, modes)
		assert.is_nil(world.projections:Mode())
	end)

	it("counts as updating before Start and while any projection updates (LOG-R74)", function()
		local world = machinery(casts(600))
		bind(world, (recorder(builtDb(600))))
		local rebuilding = bind(world, (recorder({})))
		assert.is_true(world.projections:IsUpdating())

		world.projections:Start(600)

		assert.is_true(world.projections:IsUpdating())
		assert.is_true(rebuilding:IsUpdating())
		world.runFrames()
		assert.is_false(world.projections:IsUpdating())
	end)

	it(
		"runs WhenIdle hooks once none is updating, after the last done and its live entries (LOG-R63, ANN-R61)",
		function()
			local world = machinery(casts(600))
			local def, seen = recorder({})
			bind(world, def)
			local order = {}
			world.projections:WhenIdle(function()
				order[#order + 1] = "idle after " .. #seen.done .. " done, " .. #seen.applied .. " applied"
			end)

			world.projections:Start(600)
			world.append(1)
			assert.are.same({}, order)
			world.runFrames()

			assert.are.same({ "idle after 1 done, 601 applied" }, order)
			world.projections:WhenIdle(function()
				order[#order + 1] = "at once"
			end)
			assert.are.equal("at once", order[2])
		end
	)

	it("runs WhenIdle hooks at Start when no projection is bound (LOG-R63)", function()
		local world = machinery({})
		local ran = false
		world.projections:WhenIdle(function()
			ran = true
		end)
		assert.is_false(ran)

		world.projections:Start(0)

		assert.is_true(ran)
	end)
end)

describe("a manual rebuild", function()
	it("rebuilds from seq 0 to the log's end, not as a first build (LOG-R72)", function()
		local world = machinery(casts(2))
		local def, seen = recorder(builtDb(2))
		local projection = bind(world, def)
		world.projections:Start(2)
		world.append(1)

		projection:Rebuild()

		assert.are.same({ "3 live", "1 rebuild", "2 rebuild", "3 rebuild" }, seen.applied)
		assert.are.same({ firstBuild = false, rebuilt = true, replayed = 0 }, seen.done[2])
		assert.are.equal(3, projection:GetState().count)
	end)
end)

describe("a projection definition", function()
	it("is refused without a db table, an integer rulesVersion, reset or apply (Projection definition)", function()
		local world = machinery({})
		for _, broken in ipairs({ "db", "rulesVersion", "reset", "apply", "done" }) do
			local def = recorder({})
			def[broken] = "broken"
			local projection, problem = world.projections:Add(def, function() end)
			assert.is_nil(projection)
			assert.matches("^NewProjection", problem)
		end
	end)

	it("whose apply raises has the error reported, and the next entry still applied (CORE-R21)", function()
		local world = machinery(casts(2))
		local def, seen = recorder({})
		local apply = def.apply
		def.apply = function(state, record, mode)
			if record.seq == 1 then
				error("broken entry")
			end
			apply(state, record, mode)
		end
		bind(world, def)

		world.projections:Start(2)

		assert.are.same({ "2 rebuild" }, seen.applied)
		assert.are.equal(1, #world.reported)
		assert.matches("broken entry", world.reported[1])
	end)
end)
