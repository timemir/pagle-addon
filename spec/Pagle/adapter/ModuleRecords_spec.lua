-- Module records on the client (LOG-R1, LOG-R40–R43, LOG-R73, LOG-R74, ADR 0008): M:AppendRecord on a Module
-- handle, and M:IterateCatches replaying a Module's own records to it and to no one else, through the real TOC over a
-- saved log.

-- A minute after login: what the client appended at login (a Skill Reading) is a second behind, so it shares no tie.
local NOW = SERVER_TIME + 60

-- Registers `name` on `Pagle` with a projection that notes each apply ("<seq> <kind> <mode>", a Module record's as
-- "<seq> <recordKind> <mode>") and its done ("done") in `seen`. `hooks.apply(record, mode)` and `hooks.done()` run
-- after the note. Returns the handle and the projection's db.
local function moduleWithProjection(Pagle, name, order, seen, hooks)
	hooks = hooks or {}
	local M = Pagle.RegisterModule({ name = name, title = name, order = order })
	local db = {}
	M:NewProjection({
		db = db,
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			seen[#seen + 1] = ("%d %s %s"):format(record.seq, record.recordKind or record.kind, mode)
			if hooks.apply then
				hooks.apply(record, mode)
			end
		end,
		done = function()
			seen[#seen + 1] = "done"
			if hooks.done then
				hooks.done()
			end
		end,
	})
	return M, db
end

-- Core over a saved log holding `entries`, with the Tackle Board installed beside the Ledger and Hunts.
local function loadWithBoard(entries)
	local loaded = loadCore(entries)
	loaded.client.addons.Pagle_TackleBoard = { metadata = { ["X-Pagle-API"] = "1" } }
	return loaded
end

-- Core over a saved log holding `entries`, with the Tackle Board and the Ledger registered, logged in and in the
-- world, at NOW. Each one's projection notes what it is handed in `seen.board` and `seen.ledger`.
local function coreWithBoard(entries, hooks)
	local loaded = loadWithBoard(entries)
	local Pagle = loaded.env.Pagle
	local seen = { board = {}, ledger = {} }
	local board, boardDb = moduleWithProjection(Pagle, "TackleBoard", 40, seen.board, hooks)
	local _, ledgerDb = moduleWithProjection(Pagle, "Ledger", 10, seen.ledger)
	enterWorld(loaded)
	loaded.client.advance(NOW - SERVER_TIME)
	return loaded, board, seen, { board = boardDb, ledger = ledgerDb }
end

-- Every record `iterate` yields, as "<seq> <kind>" (a Module record's as "<seq> <module>.<recordKind>").
local function walk(iterate)
	local list = {}
	for record in iterate do
		local what = record.kind == "module" and (record.module .. "." .. record.recordKind) or record.kind
		list[#list + 1] = record.seq .. " " .. what
	end
	return list
end

describe("M:AppendRecord", function()
	it(
		"appends A1 for the current character with the Module's name and returns the record, applied live at once"
			.. " to its Module only (LOG-R40, LOG-R41, LOG-R73)",
		function()
			local loaded, board, seen, dbs = coreWithBoard(history(2))
			local log = loaded.env.PagleLog
			local before = log.count
			local boardSeen, ledgerSeen = #seen.board, #seen.ledger

			local record = board:AppendRecord("issue", "n;haul;1;10;20;148")

			assert.are.same(
				{ ("A1|2|%d|0|TackleBoard|issue|n;haul;1;10;20;148"):format(NOW) },
				{ unpack(logEntries(log), before + 1) }
			)
			assert.are.same({
				seq = before + 1,
				id = PLAYER_GUID .. "-" .. NOW .. "-0",
				kind = "module",
				char = 2,
				time = NOW,
				module = "TackleBoard",
				recordKind = "issue",
				payload = "n;haul;1;10;20;148",
			}, record)
			assert.are.same({ ("%d issue live"):format(before + 1) }, { unpack(seen.board, boardSeen + 1) })
			assert.are.equal(ledgerSeen, #seen.ledger)
			local global = loaded.env.PagleDB.global
			assert.are.same({ before + 1, before + 1, before + 1, before + 1 }, {
				dbs.board.lastSeq,
				dbs.ledger.lastSeq,
				global.projections.fieldReport.lastSeq,
				global.projections.wallet.lastSeq,
			})
		end
	)

	it("takes a payload of exactly 200 bytes, and the next one gets the next tie (LOG-R12, LOG-R40)", function()
		local loaded, board = coreWithBoard(history(1))

		local suffix = "-0-0;n;haul;1;10;20;148"
		local payload = "Player-1-" .. ("A"):rep(200 - #"Player-1-" - #suffix) .. suffix
		local first = board:AppendRecord("reroll", payload)
		local second = board:AppendRecord("day", "0;0")

		assert.are.equal(PLAYER_GUID .. "-" .. NOW .. "-1", second.id)
		assert.are.equal(first.seq + 1, second.seq)
		assert.are.equal(("A1|2|%d|1|TackleBoard|day|0;0"):format(NOW), logEntries(loaded.env.PagleLog)[second.seq])
	end)

	local refused = {
		{ "a 201-byte payload", "day", ("x"):rep(201) },
		{ "a payload with a newline", "day", "two\nlines" },
		{ "a payload that isn't a string", "day", 30 },
		{ "no payload", "day", nil },
		{ "a kind outside [%w_.]+", "re roll", "x" },
		{ "a kind with a |", "re|roll", "x" },
		{ "an empty kind", "", "x" },
		{ "a kind that isn't a string", 7, "x" },
	}
	for _, case in ipairs(refused) do
		it(("raises an error at the caller and appends nothing for %s (LOG-R40)"):format(case[1]), function()
			local loaded, board = coreWithBoard(history(1))
			local before = loaded.env.PagleLog.count

			local ok, err = pcall(function()
				board:AppendRecord(case[2], case[3])
			end)

			assert.is_false(ok)
			assert.matches("ModuleRecords_spec.lua:%d+:", tostring(err))
			assert.are.equal(before, loaded.env.PagleLog.count)
		end)
	end

	it("is a Module handle method (LOG-R40, CORE-R12)", function()
		local _, board = coreWithBoard(history(1))

		local ok, err = pcall(board.AppendRecord, "day", "x")

		assert.is_false(ok)
		assert.matches("AppendRecord is a Module handle method: call M:AppendRecord(kind, payload)", err, 1, true)
	end)

	it("raises an error before PLAYER_LOGIN, appending nothing (LOG-R11, LOG-R40)", function()
		local loaded = loadWithBoard(history(1))
		local board = moduleWithProjection(loaded.env.Pagle, "TackleBoard", 40, {})
		local before = loaded.env.PagleLog.count

		local ok, err = pcall(function()
			board:AppendRecord("start", "0;0")
		end)

		assert.is_false(ok)
		assert.matches("ModuleRecords_spec.lua:%d+:.*PLAYER_LOGIN", tostring(err))
		assert.are.equal(before, loaded.env.PagleLog.count)
	end)

	it("from inside a live apply, reaches the Module right after that apply returns (LOG-R40, LOG-R73)", function()
		local board, seen
		local loaded, handle, notes = coreWithBoard(history(1), {
			apply = function(record, mode)
				if record.kind == "cast" and mode == "live" then
					board:AppendRecord("issue", "n;haul;1;10;20;148")
					table.insert(seen.board, "returned")
				end
			end,
		})
		board, seen = handle, notes
		local count = #seen.board
		local before = loaded.env.PagleLog.count

		catchOne(loaded)

		assert.are.same({
			("%d cast live"):format(before + 1),
			"returned",
			("%d issue live"):format(before + 2),
		}, { unpack(seen.board, count + 1) })
	end)

	it(
		"while its projection catches up, reaches it after done, in order with the other queued entries (LOG-R74)",
		function()
			local loaded = loadWithBoard(history(600)) -- over the sync limit: the rebuild runs in chunks
			local seen = {}
			local board = moduleWithProjection(loaded.env.Pagle, "TackleBoard", 40, seen)
			enterWorld(loaded)
			assert.is_true(loaded.ns.projections:IsUpdating())
			local before = loaded.env.PagleLog.count

			board:AppendRecord("start", "0;0")
			catchOne(loaded)
			board:AppendRecord("day", "0;0")
			for _ = 1, 400 do
				loaded.client.advance(0)
			end

			assert.is_false(loaded.ns.projections:IsUpdating())
			local done
			for i, note in ipairs(seen) do
				if note == "done" then
					done = i
				end
			end
			assert.are.same({
				"done",
				("%d skill live"):format(before), -- the Skill Reading login appended
				("%d start live"):format(before + 1),
				("%d cast live"):format(before + 2),
				("%d day live"):format(before + 3),
			}, { unpack(seen, done, done + 4) })
			assert.are.equal(done + 4, #seen)
		end
	)

	it("from the Module's login code reaches its projection as live, never replay (LOG-R1, LOG-R74)", function()
		local loaded = loadWithBoard(history(1))
		local seen = {}
		local board = moduleWithProjection(loaded.env.Pagle, "TackleBoard", 40, seen)
		loaded.client.fire("PLAYER_LOGIN")

		local record = board:AppendRecord("start", "0;0")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		assert.are.same({ ("%d start live"):format(record.seq) }, { seen[#seen - 1] })
		for _, note in ipairs(seen) do
			assert.is_nil(note:match("start replay") or note:match("start rebuild"))
		end
	end)

	for _, mode in ipairs({ "rebuild", "replay" }) do
		it(("raises an error from a %s apply, appending nothing (LOG-R40, LOG-R75)"):format(mode), function()
			local loaded = loadWithBoard(history(2))
			local raised = {}
			local board, db
			board, db = moduleWithProjection(loaded.env.Pagle, "TackleBoard", 40, {}, {
				apply = function(record, applyMode)
					if record.kind == "cast" then
						local ok, err = pcall(board.AppendRecord, board, "day", "")
						raised[#raised + 1] = applyMode
							.. " "
							.. tostring(not ok)
							.. " "
							.. tostring(err):match("[^:]*$")
					end
				end,
			})
			if mode == "replay" then
				-- Built over the first Cast: the second is caught up as replay (LOG-R71).
				db.projection, db.lastSeq, db.rulesVersion = {}, 1, 1
				db.logId = loaded.env.PagleLog.logId
				db.fingerprint = loaded.env.Pagle.CONTENT_FINGERPRINT
			end
			local logged = loaded.env.PagleLog.count

			enterWorld(loaded)

			assert.is_true(#raised >= 1)
			for _, line in ipairs(raised) do
				assert.matches("^" .. mode .. " true .*" .. mode, line)
			end
			for seq = logged + 1, loaded.env.PagleLog.count do
				assert.is_nil(logEntries(loaded.env.PagleLog)[seq]:match("^A1"))
			end
		end)
	end

	it("raises an error from done, appending nothing (LOG-R40, LOG-R76)", function()
		local loaded = loadWithBoard(history(1))
		local result
		local board
		board = moduleWithProjection(loaded.env.Pagle, "TackleBoard", 40, {}, {
			done = function()
				result = { pcall(board.AppendRecord, board, "day", "") }
			end,
		})

		enterWorld(loaded)

		assert.is_false(result[1])
		assert.matches("done", result[2])
		for _, entry in ipairs(logEntries(loaded.env.PagleLog)) do
			assert.is_nil(entry:match("^A1"))
		end
	end)
end)

describe("Module records in the log", function()
	local function withRecords()
		local entries = history(2)
		entries[#entries + 1] = "A1|1|1791731000|0|TackleBoard|start|0;0"
		entries[#entries + 1] = "A1|1|1791731001|0|Ledger|title|title:level1"
		entries[#entries + 1] = "A1|1|1791731002|0|Hunts|run|darkshore_moonlight|1792422000|1792681200|r" -- a Module not registered here
		entries[#entries + 1] = "A1|1|1791731003|0|TackleBoard|issue|n;haul;1;10;20;148"
		entries[#entries + 1] = castEntry(1791731004)
		return entries
	end

	it("are never yielded by Pagle.IterateCatches (LOG-R42)", function()
		local loaded = coreWithBoard(withRecords())

		local seen = walk(loaded.env.Pagle.IterateCatches(3))

		assert.are.same({ "8 cast", "9 skill" }, seen) -- the Skill Reading login appended
	end)

	it("are replayed by M:IterateCatches to the Module that wrote them, never another's (LOG-R41, LOG-R42)", function()
		local _, board = coreWithBoard(withRecords())

		assert.are.same(
			{ "4 TackleBoard.start", "7 TackleBoard.issue", "8 cast", "9 skill" },
			walk(board:IterateCatches(3))
		)
	end)

	it(
		"reach their Module's projection in a rebuild; every other projection skips them, silently, and ends at the"
			.. " log's length (LOG-R16, LOG-R41, LOG-R72)",
		function()
			local loaded, _, seen, dbs = coreWithBoard(withRecords())

			assert.are.same({
				"1 cast rebuild",
				"2 cast rebuild",
				"3 build rebuild",
				"4 start rebuild",
				"7 issue rebuild",
				"8 cast rebuild",
				"done",
				"9 skill live",
			}, seen.board)
			assert.are.same({
				"1 cast rebuild",
				"2 cast rebuild",
				"3 build rebuild",
				"5 title rebuild", -- the Ledger's own
				"8 cast rebuild",
				"done",
				"9 skill live",
			}, seen.ledger)
			local global = loaded.env.PagleDB.global
			local length = loaded.env.PagleLog.count
			assert.are.same({ length, length, length, length }, {
				dbs.board.lastSeq,
				dbs.ledger.lastSeq,
				global.projections.fieldReport.lastSeq,
				global.projections.wallet.lastSeq,
			})
			assert.are.equal(0, global.decodeErrors)
		end
	)

	it("that can't be decoded are skipped and counted once in decodeErrors (LOG-R16)", function()
		local entries = history(1)
		entries[#entries + 1] = "A1|1|1791731000|0|TackleBoard|bad kind|x"
		local loaded, board = coreWithBoard(entries)
		walk(board:IterateCatches(0))
		walk(loaded.env.Pagle.IterateCatches(0))

		assert.are.equal(1, loaded.env.PagleDB.global.decodeErrors)
	end)

	it("never ride on Catch or CastEnded (LOG-R43)", function()
		local loaded, board = coreWithBoard(history(1))
		local got = {}
		loaded.env.Pagle.RegisterCallback("Spec", "CastEnded", function(_, _, cast)
			got[#got + 1] = cast.kind
		end)
		loaded.env.Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
			got[#got + 1] = catch.cast.kind
		end)
		board:AppendRecord("day", "0;0")

		catchOne(loaded)

		assert.are.same({ "cast", "cast" }, got)
	end)
end)

describe("a dev log written before Module records", function()
	it("still loads with the same format, logId and entries, and silently (LOG-R14, LOG-R18)", function()
		local saved = savedLog({
			"B1|1|1791731680|0|70338|1.60.1|pagle-2026a",
			"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
		})
		local loaded, board = coreWithBoard(saved)
		board:AppendRecord("start", "0;0")

		local log = loaded.env.PagleLog
		assert.are.same({ 4, "3f9a2c1e7b0d4a65" }, { log.format, log.logId })
		assert.are.equal("C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1", logEntries(log)[2])
		assert.are.equal("A1", logEntries(log)[log.count]:sub(1, 2))
		assert.are.same({}, loaded.printed)
	end)
end)
