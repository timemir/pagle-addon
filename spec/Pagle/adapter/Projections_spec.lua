-- The projection machinery on the client (LOG-R1 step 3, LOG-R9 step 4, LOG-R42, LOG-R70–R74): a Module's
-- projection bound through its handle, started at the first PLAYER_ENTERING_WORLD and handed each entry Core
-- appends, driven through the fake client's events.

local OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"
local FISHING = 7731

-- Entry `i` of a saved log: a caught Cast by Ada.
local function cast(i)
	return ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||6358x1"):format(1791731000 + i)
end

-- `n` Casts, then the build entry the fake client's build matches, so login appends no B1.
local function history(n)
	local entries = {}
	for i = 1, n do
		entries[i] = cast(i)
	end
	entries[n + 1] = "B1|1|1791731999|0|70338|1.60.1"
	return entries
end

-- Core over a saved log holding `entries`, with the Ledger installed and registered, its projection over `db`
-- noting what it's handed in `seen.applied` ("<seq> <kind> <mode>") and `seen.done`, and each event in `seen.events`.
local function coreWithLedger(entries, db)
	local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog(entries) }))
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local Pagle = loaded.env.Pagle
	local seen = { applied = {}, done = {}, events = {} }
	local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	local projection = M:NewProjection({
		db = db,
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			seen.applied[#seen.applied + 1] = record.seq .. " " .. record.kind .. " " .. mode
		end,
		done = function(_, info)
			seen.done[#seen.done + 1] = info
			seen.applied[#seen.applied + 1] = "done"
		end,
	})
	for _, event in ipairs({ "Catch", "CastEnded", "SkillChanged" }) do
		Pagle.RegisterCallback("Spec " .. event, event, function()
			seen.applied[#seen.applied + 1] = event
		end)
	end
	return loaded, seen, projection, M
end

-- Plays a caught Cast of one Oily Blackmouth on the fake client.
local function catchOne(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
	loaded.client.loot = { fishing = true, slots = { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", FISHING)
	loaded.client.fire("LOOT_CLOSED")
end

describe("a Module's projection at login", function()
	it(
		"rebuilds at the first PLAYER_ENTERING_WORLD, before the Skill Reading login appends, which is live"
			.. " (LOG-R1, LOG-R70, LOG-R72)",
		function()
			local db = {}
			local loaded, seen, projection = coreWithLedger(history(2), db)

			loaded.client.fire("PLAYER_LOGIN")
			assert.is_true(projection:IsUpdating())
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

			assert.are.same({
				"1 cast rebuild",
				"2 cast rebuild",
				"3 build rebuild",
				"done",
				"4 skill live",
				"SkillChanged",
			}, seen.applied)
			assert.are.same({ firstBuild = true, rebuilt = true, replayed = 0 }, seen.done[1])
			assert.are.same({ 4, loaded.env.PagleLog.logId, loaded.env.Pagle.CONTENT_FINGERPRINT, 1 }, {
				db.lastSeq,
				db.logId,
				db.fingerprint,
				db.rulesVersion,
			})
			assert.is_false(projection:IsUpdating())
		end
	)

	it("catches up from lastSeq to loginSeq in replay mode (LOG-R71)", function()
		local fingerprint = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle.CONTENT_FINGERPRINT
		local db =
			{ projection = {}, lastSeq = 1, logId = "3f9a2c1e7b0d4a65", fingerprint = fingerprint, rulesVersion = 1 }
		local loaded, seen = coreWithLedger(history(2), db)

		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		assert.are.same({ "2 cast replay", "3 build replay", "done", "4 skill live", "SkillChanged" }, seen.applied)
		assert.are.same({ firstBuild = false, rebuilt = false, replayed = 2 }, seen.done[1])
	end)

	it("runs more than 500 pending entries on later frames, still updating until done (LOG-R71)", function()
		local loaded, seen, projection = coreWithLedger(history(501), {})

		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
		assert.are.same({ "SkillChanged" }, seen.applied)
		assert.is_true(projection:IsUpdating())
		loaded.client.runTimers() -- the entries
		loaded.client.runTimers() -- done, in a frame of its own (#79)

		assert.is_false(projection:IsUpdating())
		assert.are.equal(1, #seen.done)
	end)
end)

describe("a Cast recorded", function()
	it(
		"while the projection is up to date is applied live before Catch and CastEnded fire (LOG-R9, LOG-R73)",
		function()
			local loaded, seen = coreWithLedger(history(1), {})
			loaded.client.fire("PLAYER_LOGIN")
			loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
			seen.applied = {}

			catchOne(loaded)

			assert.are.same({ "4 cast live", "Catch", "CastEnded" }, seen.applied)
		end
	)

	it("during an update is applied once, as live, after done and in order (LOG-R74)", function()
		local loaded, seen = coreWithLedger(history(501), {})
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		catchOne(loaded)
		loaded.client.runTimers() -- the entries
		loaded.client.runTimers() -- done, in a frame of its own (#79), then the live entries

		local tail = { unpack(seen.applied, #seen.applied - 3) }
		assert.are.same({ "502 build rebuild", "done", "503 skill live", "504 cast live" }, tail)
		assert.are.same({ "SkillChanged", "Catch", "CastEnded" }, { unpack(seen.applied, 1, 3) })
	end)
end)

describe("M:IterateCatches", function()
	it("yields what Pagle.IterateCatches yields (LOG-R42)", function()
		local loaded, _, _, M = coreWithLedger(history(2), {})
		local fromHandle, fromPagle = {}, {}

		for record in M:IterateCatches(1) do
			fromHandle[#fromHandle + 1] = record
		end
		for record in loaded.env.Pagle.IterateCatches(1) do
			fromPagle[#fromPagle + 1] = record
		end

		assert.are.same(fromPagle, fromHandle)
		assert.are.equal(2, #fromHandle)
	end)
end)

describe("M:NewProjection", function()
	it("raises an error at the Module's call for a def without db (LOG-R70)", function()
		local _, _, _, M = coreWithLedger({}, {})

		local ok, err = pcall(function()
			M:NewProjection({ rulesVersion = 1, reset = print, apply = print })
		end)

		assert.is_false(ok)
		assert.matches("Projections_spec.lua:%d+: NewProjection: def.db", tostring(err))
	end)
end)
