-- The Ledger's projection (LED-R2, LED-R4, LED-R198; LOG-R70–R77) on FakePagle: a log built with
-- fake.catchLog:Append, then login, then live Casts with fake.playCast.

local MACKEREL, SMALLFISH, OILY = 6303, 6291, 6358
local ELWYNN, WESTFALL = 12, 40
local T0 = SERVER_TIME - 700

-- A Cast record for fake.catchLog:Append, by the player's character (char 1).
---@param time integer
---@param zone integer
---@param itemIDs integer[]? nil for a got-away Cast
local function cast(time, zone, itemIDs)
	return castRecord({ time = time, zone = zone, items = itemIDs, outcome = itemIDs and "caught" or "gotAway" })
end

-- History before login: Catches in two zones, a got-away Cast and a Skill Reading that credits two Skill
-- Milestones (LED-R40), so the fold has every M2 row to fold.
---@param fake FakePagle
local function withHistory(fake)
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	fake.catchLog:Append(cast(T0, ELWYNN, { MACKEREL, SMALLFISH }))
	fake.catchLog:Append(cast(T0 + 60, ELWYNN))
	fake.catchLog:Append({ kind = "skill", char = 1, time = T0 + 90, rank = 150, max = 225, mod = 0 })
	fake.catchLog:Append(cast(T0 + 120, WESTFALL, { MACKEREL, OILY }))
end

-- Ticket #99's fold, with the fake's GetItem and the Ledger's world index, over every record in fake.catchLog: the state the projection must hold.
---@param fake FakePagle
---@param ns PagleLedgerNS
local function foldOfLog(fake, ns)
	local fold = ns.NewLedgerFold({
		GetItem = fake.Pagle.GetItem,
		MatchesConditions = fake.Pagle.MatchesConditions,
		world = ns.world,
	})
	local state = fold.reset()
	for record in fake.catchLog:Iterate(0) do
		fold.apply(state, record, "rebuild")
	end
	return state
end

-- Loads the Ledger on `fake`, noting each record its fold applies, as "<seq> <kind> <mode>", in `applied`.
-- `prepare(loaded)` runs before the Ledger's ADDON_LOADED, e.g. to raise its rules version.
---@param fake FakePagle
---@param prepare fun(loaded: LoadedAddon)?
---@return LoadedAddon loaded
---@return string[] applied
local function loadLedger(fake, prepare)
	local loaded = fake.load("Pagle_Ledger", { holdAddonLoaded = true })
	if prepare then
		prepare(loaded)
	end
	local applied = {}
	local newFold = loaded.ns.NewLedgerFold
	loaded.ns.NewLedgerFold = function(lookups)
		local fold = newFold(lookups)
		local apply = fold.apply
		fold.apply = function(state, record, mode, ...)
			applied[#applied + 1] = record.seq .. " " .. record.kind .. " " .. mode
			return apply(state, record, mode, ...)
		end
		return fold
	end
	loaded.client.fire("ADDON_LOADED", "Pagle_Ledger")
	return loaded, applied
end

-- A first session: the history, login, then one live Cast. Returns the fake and the Ledger loaded on it.
---@param prepare fun(loaded: LoadedAddon)?
---@return FakePagle fake
---@return LoadedAddon loaded
local function firstSession(prepare)
	local fake = newFakePagle()
	withHistory(fake)
	local loaded = loadLedger(fake, prepare)
	fake.login()
	fake.enterWorld()
	fake.playCast("caught", { { itemID = SMALLFISH, quantity = 1 } })
	return fake, loaded
end

-- The next session on the same machine: a new FakePagle over the same PagleLog and the PagleLedgerDB the last one
-- saved, with `between` Casts recorded meanwhile (while the Ledger was off), before login.
---@param last FakePagle
---@param lastLoaded LoadedAddon
---@param between integer
---@return FakePagle
local function nextSession(last, lastLoaded, between)
	local fake = newFakePagle()
	fake.catchLog.data = last.catchLog.data
	for i = 1, between do
		fake.catchLog:Append(cast(T0 + 600 + i, WESTFALL, { SMALLFISH }))
	end
	fake.globals.PagleLedgerDB = lastLoaded.env.PagleLedgerDB
	return fake
end

describe("the Ledger's projection", function()
	it("rebuilds from seq 0 at the first login, to the state ticket #99's fold makes (LED-R2, LOG-R72)", function()
		local fake = newFakePagle()
		withHistory(fake)
		local loaded, applied = loadLedger(fake)

		fake.login()
		fake.enterWorld()

		local projection = loaded.ns.projection
		assert.is_false(projection:IsUpdating())
		assert.are.same({ "1 cast rebuild", "2 cast rebuild", "3 skill rebuild", "4 cast rebuild" }, applied)
		assert.are.same(foldOfLog(fake, loaded.ns), projection:GetState())
		assert.are.same({ 3, 4 }, { projection:GetState().casts, projection:GetState().catches })
		local db = loaded.env.PagleLedgerDB.global.projection
		assert.are.equal(projection:GetState(), db.projection)
		assert.are.same(
			{ 4, fake.catchLog.data.logId, fake.Pagle.CONTENT_FINGERPRINT },
			{ db.lastSeq, db.logId, db.fingerprint }
		)
	end)

	it("applies a live Cast once, before Catch fires (LOG-R73)", function()
		local fake = newFakePagle()
		withHistory(fake)
		local loaded, applied = loadLedger(fake)
		fake.login()
		fake.enterWorld()
		local castsAtCatch
		fake.Pagle.RegisterCallback("Spec", "Catch", function()
			castsAtCatch = loaded.ns.projection:GetState().casts
		end)

		fake.playCast("caught", { { itemID = MACKEREL, quantity = 1 } })

		assert.are.equal(4, castsAtCatch)
		assert.are.same({ "5 cast live" }, { unpack(applied, 5) })
		assert.are.same(foldOfLog(fake, loaded.ns), loaded.ns.projection:GetState())
		assert.are.equal(5, loaded.env.PagleLedgerDB.global.projection.lastSeq)
	end)

	it("applies a Cast recorded while it updates after the rebuild, in order (LOG-R74)", function()
		local fake = newFakePagle()
		withHistory(fake)
		local loaded, applied = loadLedger(fake)
		fake.login()

		fake.playCast("caught", { { itemID = SMALLFISH, quantity = 1 } })
		fake.playCast("gotAway")

		assert.is_true(loaded.ns.projection:IsUpdating())
		assert.are.same({}, applied)

		fake.enterWorld()

		assert.is_false(loaded.ns.projection:IsUpdating())
		assert.are.same({
			"1 cast rebuild",
			"2 cast rebuild",
			"3 skill rebuild",
			"4 cast rebuild",
			"5 cast live",
			"6 cast live",
		}, applied)
		assert.are.same(foldOfLog(fake, loaded.ns), loaded.ns.projection:GetState())
		assert.are.equal(5, loaded.ns.projection:GetState().casts)
	end)

	-- Every seq from 1 to `last`, each a rebuild apply.
	---@param fake FakePagle
	---@param last integer
	local function rebuiltTo(fake, last)
		local applied = {}
		for record in fake.catchLog:Iterate(0) do
			if record.seq <= last then
				applied[#applied + 1] = record.seq .. " " .. record.kind .. " rebuild"
			end
		end
		return applied
	end

	it("catches up from lastSeq at a login with neither a new fingerprint nor rules version (LOG-R71)", function()
		local last, lastLoaded = firstSession()
		local fake = nextSession(last, lastLoaded, 2)
		local loaded, applied = loadLedger(fake)

		fake.login()
		fake.enterWorld()

		assert.are.same({ "6 cast replay", "7 cast replay" }, applied)
		assert.are.same(foldOfLog(fake, loaded.ns), loaded.ns.projection:GetState())
		assert.are.equal(7, loaded.env.PagleLedgerDB.global.projection.lastSeq)
	end)

	it("rebuilds from seq 0 at a login with a new content fingerprint (LED-R191, LOG-R72)", function()
		local last, lastLoaded = firstSession()
		local fake = nextSession(last, lastLoaded, 2)
		fake.Pagle.CONTENT_FINGERPRINT = "a new release"
		local loaded, applied = loadLedger(fake)

		fake.login()
		fake.enterWorld()

		assert.are.same(rebuiltTo(fake, 7), applied)
		assert.are.same(foldOfLog(fake, loaded.ns), loaded.ns.projection:GetState())
		assert.are.equal("a new release", loaded.env.PagleLedgerDB.global.projection.fingerprint)
	end)

	it("rebuilds an M2 projection, rules version 100, at this build's rules version (LED-R4, LED-R191)", function()
		local last, lastLoaded = firstSession(function(loading)
			loading.ns.LEDGER_RULES_VERSION = 1 -- M2's
		end)
		lastLoaded.env.PagleLedgerDB.global.projection.rulesVersion = 100 -- as M2 stored it, before Core's sizes
		local fake = nextSession(last, lastLoaded, 0)
		local loaded, applied = loadLedger(fake)

		fake.login()
		fake.enterWorld()

		assert.are.same(rebuiltTo(fake, 5), applied)
		assert.are.same(foldOfLog(fake, loaded.ns), loaded.ns.projection:GetState())
		assert.are.equal(loaded.ns.RulesVersion(2), loaded.env.PagleLedgerDB.global.projection.rulesVersion)
	end)

	it(
		"rebuilds from this machine's log alone over a projection of another PagleLog: nothing merges (LED-R198)",
		function()
			local _, otherLoaded = firstSession()
			local fake = newFakePagle() -- another machine: its own PagleLog, with its own logId
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for i = 1, 6 do -- more entries than the other log's lastSeq (5), so only the logId tells them apart
				fake.catchLog:Append(cast(T0 + 5000 + i, WESTFALL, { OILY }))
			end
			fake.globals.PagleLedgerDB = otherLoaded.env.PagleLedgerDB
			local loaded, applied = loadLedger(fake)

			fake.login()
			fake.enterWorld()

			assert.are.same(rebuiltTo(fake, 6), applied)
			assert.are.same(foldOfLog(fake, loaded.ns), loaded.ns.projection:GetState())
			assert.are.equal(6, loaded.ns.projection:GetState().casts)
			assert.are.equal(fake.catchLog.data.logId, loaded.env.PagleLedgerDB.global.projection.logId)
		end
	)

	it("changes nothing in the state for a build or purchase record (LED-R2, LED-R4)", function()
		local fake, loaded = firstSession()
		local before = foldOfLog(fake, loaded.ns)
		-- A build entry (LOG-R36) and a purchase (LOG-R39) through the log, each handed over live.
		local build =
			fake.catchLog:Append({ kind = "build", char = 1, time = T0 + 900, build = 66432, version = "1.60.1" })
		fake.live(build)
		fake.ns.RecordPurchase("core.toaststyle.ripple", 50)

		assert.are.equal(7, loaded.env.PagleLedgerDB.global.projection.lastSeq) -- each was handed over
		assert.are.same(before, loaded.ns.projection:GetState())
	end)

	it("stores rulesVersion LEDGER_RULES_VERSION × 100 + Core's SIZE_RULES_VERSION 2 (LED-R2, LOG-R68)", function()
		local fake, loaded = firstSession()

		assert.are.equal(2, fake.Pagle.SIZE_RULES_VERSION)
		assert.are.equal(
			loaded.ns.LEDGER_RULES_VERSION * 100 + 2,
			loaded.env.PagleLedgerDB.global.projection.rulesVersion
		)
	end)

	it(
		"rebuilds an M3 projection, stored at 200 with no SIZE_RULES_VERSION, at the first M4 login (LED-R2, LED-R191, LOG-R68)",
		function()
			local last, lastLoaded = firstSession()
			lastLoaded.env.PagleLedgerDB.global.projection.rulesVersion = 200 -- as M3 stored it
			local fake = nextSession(last, lastLoaded, 0)
			local loaded, applied = loadLedger(fake)

			fake.login()
			fake.enterWorld()

			assert.are.same(rebuiltTo(fake, 5), applied)
			assert.are.equal(loaded.ns.RulesVersion(2), loaded.env.PagleLedgerDB.global.projection.rulesVersion)
		end
	)

	it("rebuilds a projection stored at 201, M3's fold with Core's sizes, at 502 (LED-R4, LED-R2)", function()
		local last, lastLoaded = firstSession()
		lastLoaded.env.PagleLedgerDB.global.projection.rulesVersion = 201
		local fake = nextSession(last, lastLoaded, 0)
		local loaded, applied = loadLedger(fake)

		fake.login()
		fake.enterWorld()

		assert.are.same(rebuiltTo(fake, 5), applied)
		assert.are.equal(502, loaded.env.PagleLedgerDB.global.projection.rulesVersion)
	end)

	it(
		"rebuilds a projection stored at 301, M4's fold, at 502, with ★ at the 5th Catch (LED-R4, LED-R2, LED-R45)",
		function()
			local last, lastLoaded = firstSession()
			lastLoaded.env.PagleLedgerDB.global.projection.rulesVersion = 301
			local fake = nextSession(last, lastLoaded, 0)
			local loaded, applied = loadLedger(fake)

			fake.login()
			fake.enterWorld()

			assert.are.same(rebuiltTo(fake, 5), applied)
			assert.are.equal(502, loaded.env.PagleLedgerDB.global.projection.rulesVersion)
		end
	)

	it(
		"rebuilds a projection stored at 401, the half-cost climb's, at 502, the full cost's with Activity XP (LED-R4, LED-R2, LED-R30, LED-R37)",
		function()
			local last, lastLoaded = firstSession()
			lastLoaded.env.PagleLedgerDB.global.projection.rulesVersion = 401
			local fake = nextSession(last, lastLoaded, 0)
			local loaded, applied = loadLedger(fake)

			fake.login()
			fake.enterWorld()

			assert.are.same(rebuiltTo(fake, 5), applied)
			assert.are.equal(502, loaded.env.PagleLedgerDB.global.projection.rulesVersion)
			assert.are.same(
				{ 0, foldOfLog(fake, loaded.ns).lifetimeXP },
				{ loaded.ns.projection:GetState().prestigeActivityXP, loaded.ns.projection:GetState().lifetimeXP }
			)
		end
	)

	it("rebuilds a projection stored at 501, sized before the Reach, at 502 (LED-R2, LOG-R68, ADR 0014)", function()
		local last, lastLoaded = firstSession()
		lastLoaded.env.PagleLedgerDB.global.projection.rulesVersion = 501
		local fake = nextSession(last, lastLoaded, 0)
		local loaded, applied = loadLedger(fake)

		fake.login()
		fake.enterWorld()

		assert.are.same(rebuiltTo(fake, 5), applied)
		assert.are.equal(502, loaded.env.PagleLedgerDB.global.projection.rulesVersion)
	end)
end)
