-- PagleTackleBoardDB's schema and the Tunables several Tackle Board tickets share (tackle-board.md › Data, Tunables).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

describe("the Tackle Board's data", function()
	local ns = board.load().ns

	it("has 2 Expedition pins and 6 Notice pins, the caps (TKB-R20, TKB-R101)", function()
		assert.are.same({ 2, 6 }, { ns.EXPEDITION_PINS, ns.NOTICE_PINS })
	end)

	it("keeps 28 board days of history (TKB-R106, tackle-board.md › Data)", function()
		assert.are.equal(28, ns.KEPT_DAYS)
	end)

	it("maps continent 0 to the Eastern Kingdoms' uiMapID 1415 and 1 to Kalimdor's 1414 (TKB-R36)", function()
		assert.are.same({ [0] = 1415, [1] = 1414 }, ns.CONTINENT_MAPS)
	end)

	describe("ns.MigrateDB", function()
		it("stamps a new DB with schema 1", function()
			local global = {}

			ns.MigrateDB(global)

			assert.are.equal(1, global.schemaVersion)
		end)

		it("leaves a DB already at schema 1 as it is", function()
			local global = { schemaVersion = 1, celebrated = { goals = { a = true }, titles = {} } }

			ns.MigrateDB(global)

			assert.are.same({ schemaVersion = 1, celebrated = { goals = { a = true }, titles = {} } }, global)
		end)
	end)
end)
