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

	it("brings a new PagleDB to schemaVersion 2, the onboarding state's (catch-log.md › Data, ONB-R1)", function()
		local db = { global = {} }
		local catchLog = ns.OpenCatchLog(savedLog(), { decodeErrors = 0 }, SERVER_TIME)

		ns.Migrate(db, ns.PAGLEDB_MIGRATIONS, { catchLog = catchLog })

		assert.are.equal(2, #ns.PAGLEDB_MIGRATIONS)
		assert.are.equal(2, db.global.schemaVersion)
		assert.are.equal("waiting", db.global.onboarding.letter)
	end)

	it("leaves step 1, the first schema, with nothing to migrate (ADR 0003)", function()
		local db = { global = { schemaVersion = 0 } }

		ns.PAGLEDB_MIGRATIONS[1](db, {})

		assert.are.same({ schemaVersion = 0 }, db.global)
	end)
end)

describe("ns.PAGLEDB_DEFAULTS", function()
	it("gives each of Core's own projections its table, the Field report's and the wallet's (LOG-R78)", function()
		assert.are.same({ fieldReport = {}, wallet = {} }, ns.PAGLEDB_DEFAULTS.global.projections)
	end)
end)
