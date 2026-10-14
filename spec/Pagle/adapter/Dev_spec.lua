-- /pagle dev (#247): Core's hidden dev commands for fast exit checks, through the real TOC and the fake client. The
-- switch is PagleDB.global.dev; `endsession` ends the open Session as if its gap had passed (LOG-R62); `catch`
-- records a synthetic caught Cast through Core's real append path, on a test log only (PagleLog.test).

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- A test log (PagleLog.test, as the test-log tooling writes it) holding `entries`.
local function testLog(entries)
	local log = savedLog(entries)
	log.test = true
	return log
end

-- Registers a Module whose projection raises a toast for each live caught Cast, noting each Catch event it gets.
local function moduleRaising(loaded)
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	local seen = { catches = {}, applied = {} }
	M:NewProjection({
		db = {},
		rulesVersion = 1,
		reset = function()
			return {}
		end,
		apply = function(_, record, mode)
			if record.kind == "cast" and mode == "live" then
				seen.applied[#seen.applied + 1] = record.seq
				M:RaiseMoment({ rung = "toast", kind = "newSpecies", title = "New Species", cast = record.id })
			end
		end,
	})
	loaded.env.Pagle.RegisterCallback(seen, "Catch", function(_, catch)
		seen.catches[#seen.catches + 1] = catch.itemID
	end)
	return seen
end

-- The last record in the Catch log, as Core reads it back.
local function lastRecord(loaded)
	local last
	for record in loaded.env.Pagle.IterateCatches() do
		last = record
	end
	return last
end

describe("/pagle dev", function()
	it("isn't in the help list (#247, CORE-R60)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "help")

		for _, line in ipairs(loaded.printed) do
			assert.is_nil(line:find("dev", 1, true))
		end
	end)

	it("is reserved: a Module's dev subcommand is skipped and reported (#247, CORE-R61, CORE-R62)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.env.Pagle.RegisterModule({
			name = "Ledger",
			title = "Ledger",
			order = 10,
			slash = { { name = "Dev", fn = print } },
		})

		local errors = loaded.client.errors
		enterWorld(loaded)

		assert.are.same({ "Pagle: Ledger's /pagle Dev is skipped: Pagle reserves dev" }, errors)
	end)

	it("turns on and off in PagleDB.global.dev (#247)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }))

		pagle(loaded, "dev on")
		assert.is_true(loaded.env.PagleDB.global.dev)
		pagle(loaded, "DEV OFF")

		assert.is_false(loaded.env.PagleDB.global.dev)
		assert.are.same({ "Pagle dev: dev commands are on.", "Pagle dev: dev commands are off." }, loaded.printed)
	end)

	it("refuses every other subcommand with one line while off, doing nothing (#247)", function()
		local loaded = loadCore(testLog({ BUILD_ENTRY }))
		enterWorld(loaded, 1)
		catchOne(loaded)
		local entries = #loaded.env.PagleLog.entries

		for _, line in ipairs({ "dev", "dev endsession", "dev catch 6358", "dev preview banner" }) do
			pagle(loaded, line)
		end

		local off = "Pagle dev: dev commands are off; /pagle dev on turns them on."
		assert.are.same({ off, off, off, off }, loaded.printed)
		assert.is_not_nil(loaded.env.Pagle.GetSession())
		assert.are.equal(entries, #loaded.env.PagleLog.entries)
	end)
end)

describe("/pagle dev endsession", function()
	it(
		"ends the open Session now: SessionEnded fires, the summary card shows, and the log is unchanged"
			.. " (#247, LOG-R62, ANN-R53)",
		function()
			local loaded = loadCore({ BUILD_ENTRY })
			moduleRaising(loaded)
			enterWorld(loaded, 2)
			catchAndFlush(loaded)
			loaded.client.advance(loaded.ns.ANNOUNCEMENT_SECONDS.toast) -- the toast leaves the slot: the card may show
			local ended = {}
			loaded.env.Pagle.RegisterCallback(ended, "SessionEnded", function(_, session)
				ended[#ended + 1] = session.id
			end)
			local entries = { unpack(loaded.env.PagleLog.entries) }
			pagle(loaded, "dev on")

			pagle(loaded, "dev endsession")

			assert.are.equal(1, #ended)
			assert.is_nil(loaded.env.Pagle.GetSession())
			assert.are.equal(1, #loaded.env.PagleDB.global.cards)
			local frame = loaded.ns.cardFrame
			assert.is_true(frame:IsShown())
			assert.are.equal("Fishing session", frame.title:GetText())
			assert.are.same(entries, loaded.env.PagleLog.entries)
			assert.are.equal("Pagle dev: the Session ended, as if its gap had passed.", loaded.printed[2])
		end
	)

	it("says so, and fires nothing, with no Session open (#247, LOG-R64)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		local ended = {}
		loaded.env.Pagle.RegisterCallback(ended, "SessionEnded", function()
			ended[#ended + 1] = true
		end)
		pagle(loaded, "dev on")

		pagle(loaded, "dev endsession")

		assert.are.same({}, ended)
		assert.are.equal("Pagle dev: no Session is open.", loaded.printed[2])
	end)

	it("doesn't end the Session again when its gap passes later (#247, LOG-R62)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		catchOne(loaded)
		local ended = {}
		loaded.env.Pagle.RegisterCallback(ended, "SessionEnded", function()
			ended[#ended + 1] = true
		end)
		pagle(loaded, "dev on")
		pagle(loaded, "dev endsession")

		loaded.client.advance(2 * loaded.ns.SESSION_GAP)

		assert.are.equal(1, #ended)
	end)
end)

describe("/pagle dev catch", function()
	it(
		"on a test log appends one caught Cast for the character now, in the current zone, which Modules get"
			.. " live as a real Catch (#247, LOG-R9)",
		function()
			local loaded = loadCore(testLog({ BUILD_ENTRY }))
			local seen = moduleRaising(loaded)
			enterWorld(loaded, 2)
			local entries = #loaded.env.PagleLog.entries
			pagle(loaded, "dev on")

			pagle(loaded, "dev catch 6358")
			loaded.client.advance(0)

			local cast = lastRecord(loaded)
			assert.are.equal(entries + 1, #loaded.env.PagleLog.entries)
			assert.are.same(
				{ "cast", "caught", loaded.env.Pagle.GetAngler().current, 6358, 1 },
				{ cast.kind, cast.outcome, cast.char, cast.items[1].itemID, cast.items[1].quantity }
			)
			assert.are.equal(loaded.env.Pagle.GetConditions().zone, cast.conditions.zone)
			assert.are.equal(SERVER_TIME, cast.time)
			assert.are.same({ 6358 }, seen.catches)
			assert.are.same({ cast.seq }, seen.applied)
			assert.are.equal("New Species", loaded.ns.announcementFrames.toast.title:GetText())
			assert.are.equal(cast.session, loaded.env.Pagle.GetSession().id)
			assert.are.equal(
				("Pagle dev: caught item 6358 in zone %d (entry %d)."):format(cast.conditions.zone, cast.seq),
				loaded.printed[2]
			)
			assert.are.equal("idle", loaded.env.Pagle.GetFishingState())
		end
	)

	it("records it in the zone or subzone given by areaID (#247, LOG-R55)", function()
		local loaded = enterWorld(loadCore(testLog({ BUILD_ENTRY })), 2)
		pagle(loaded, "dev on")

		pagle(loaded, "dev catch 6358 453")
		local subzone = lastRecord(loaded)
		pagle(loaded, "dev catch 6303 148")
		local zone = lastRecord(loaded)

		assert.are.same({ 148, 453 }, { subzone.conditions.zone, subzone.conditions.subzone })
		assert.are.same({ 148, 0, 6303 }, { zone.conditions.zone, zone.conditions.subzone, zone.items[1].itemID })
	end)

	it("on a real log refuses with one line and appends nothing (#247)", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)
		local entries = { unpack(loaded.env.PagleLog.entries) }
		pagle(loaded, "dev on")

		pagle(loaded, "dev catch 6358")

		assert.are.same(entries, loaded.env.PagleLog.entries)
		assert.are.equal(
			"Pagle dev: catch writes to the Catch log, so it runs on a test log only (PagleLog.test); "
				.. "this log is real, and nothing was added.",
			loaded.printed[2]
		)
	end)

	for _, args in ipairs({ "", "fish", "0", "6358 here", "-5" }) do
		it(("prints its usage for /pagle dev catch %s, appending nothing (#247)"):format(args), function()
			local loaded = enterWorld(loadCore(testLog({ BUILD_ENTRY })), 2)
			local entries = #loaded.env.PagleLog.entries
			pagle(loaded, "dev on")

			pagle(loaded, "dev catch " .. args)

			assert.are.equal(entries, #loaded.env.PagleLog.entries)
			assert.are.equal("Pagle dev: /pagle dev catch <itemID> [areaID]", loaded.printed[2])
		end)
	end

	it("refuses an areaID outside the catalogue, appending nothing (#247, LOG-R55)", function()
		local loaded = enterWorld(loadCore(testLog({ BUILD_ENTRY })), 2)
		local entries = #loaded.env.PagleLog.entries
		pagle(loaded, "dev on")

		pagle(loaded, "dev catch 6358 999999")

		assert.are.equal(entries, #loaded.env.PagleLog.entries)
		assert.are.equal("Pagle dev: 999999 isn't an area in Pagle's catalogue.", loaded.printed[2])
	end)
end)
