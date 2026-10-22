-- PagleDB's ordered schemaVersion migration steps (catch-log.md › Data, `global.schemaVersion`).

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

describe("ns.Migrate", function()
	-- Three steps that note, in order, which ran and on what.
	local function steps(ran)
		local list = {}
		for n = 1, 3 do
			list[n] = function(db)
				ran[#ran + 1] = { n, db }
			end
		end
		return list
	end

	it("runs every step on a new DB, in order, and records the last (catch-log.md › Data)", function()
		local ran, db = {}, { global = {} }

		ns.Migrate(db, steps(ran))

		assert.are.same({ { 1, db }, { 2, db }, { 3, db } }, ran)
		assert.are.equal(3, db.global.schemaVersion)
	end)

	it("runs only the steps above the DB's schemaVersion (catch-log.md › Data)", function()
		local ran, db = {}, { global = { schemaVersion = 1 } }

		ns.Migrate(db, steps(ran))

		assert.are.same({ { 2, db }, { 3, db } }, ran)
		assert.are.equal(3, db.global.schemaVersion)
	end)

	it("runs nothing on a DB that is up to date, or newer (catch-log.md › Data)", function()
		for _, version in ipairs({ 3, 4 }) do
			local ran, db = {}, { global = { schemaVersion = version } }

			ns.Migrate(db, steps(ran))

			assert.are.same({}, ran)
			assert.are.equal(version, db.global.schemaVersion)
		end
	end)

	it("hands each step the context, after the DB (catch-log.md › Data)", function()
		local context, got = {}, {}
		local db = { global = {} }

		ns.Migrate(db, {
			function(_, given)
				got[#got + 1] = given
			end,
		}, context)

		assert.are.same({ context }, got)
		assert.are.equal(context, got[1])
	end)

	it(
		"brings a new PagleDB to schemaVersion 3, the Coins totals' logId (catch-log.md › Data, ONB-R1, SHOP-R3)",
		function()
			local db = { global = { coins = { earned = {} } } }
			local catchLog = ns.OpenCatchLog(savedLog(), { decodeErrors = 0 }, SERVER_TIME)

			ns.Migrate(db, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog })

			assert.are.equal(3, #ns.PAGLEDB_MIGRATIONS)
			assert.are.equal(3, db.global.schemaVersion)
			assert.are.equal("waiting", db.global.onboarding.letter)
			assert.are.equal(catchLog.data.logId, db.global.coins.logId)
		end
	)

	it("gives step 3 the Coins totals stored before M8 the log's logId, keeping them (SHOP-R3, SHOP-R4)", function()
		local db = { global = { schemaVersion = 2, coins = { earned = { Ledger = 1200, Hunts = 300 } } } }
		local catchLog = ns.OpenCatchLog(savedLog(), { decodeErrors = 0 }, SERVER_TIME)

		ns.Migrate(db, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog })

		assert.are.same(
			{ earned = { Ledger = 1200, Hunts = 300 }, logId = "3f9a2c1e7b0d4a65" }, -- savedLog's logId
			db.global.coins
		)
	end)

	it("gives step 3 no logId on a fresh install, whose log has none until PLAYER_LOGIN (SHOP-R3, LOG-R15)", function()
		local db = { global = { schemaVersion = 2, coins = { earned = {} } } }
		local catchLog = ns.OpenCatchLog(nil, { decodeErrors = 0 }, SERVER_TIME)

		ns.Migrate(db, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog })

		assert.are.same({ earned = {} }, db.global.coins)
	end)

	it("leaves step 1, the first schema, with nothing to migrate (ADR 0003)", function()
		local db = { global = { schemaVersion = 0 } }

		ns.PAGLEDB_MIGRATIONS[1](db, {})

		assert.are.same({ schemaVersion = 0 }, db.global)
	end)
end)

describe("ns.PAGLEDB_DEFAULTS", function()
	it(
		"gives each of Core's own projections its table, the Field report's, the wallet's and the varieties'"
			.. " (LOG-R78, VAR-R10)",
		function()
			assert.are.same({ fieldReport = {}, wallet = {}, varieties = {} }, ns.PAGLEDB_DEFAULTS.global.projections)
		end
	)
end)
