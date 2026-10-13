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

	it("starts PagleDB at schemaVersion 1, the first schema (catch-log.md › Data, ADR 0003)", function()
		local db = { global = {} }

		ns.Migrate(db, ns.PAGLEDB_MIGRATIONS)

		assert.are.equal(1, db.global.schemaVersion)
	end)
end)
