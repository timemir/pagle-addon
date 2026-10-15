-- The Tackle Board's Module record payloads (TKB-R80, tackle-board.md › Data › Module records): the four kinds'
-- payloads to and from the goal definition (M7 graph, shapes), and what is skipped.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local OLD_ID = "Player-4618-0A1B2C3D-1791731747-0"

describe("the board's records", function()
	local ns = board.load().ns

	describe("encoding", function()
		it("writes start and day as dayStart;weekStart (Data)", function()
			assert.are.equal("1791730800;1791557600", ns.EncodeBoundary(1791730800, 1791557600))
		end)

		it("writes an issue as type;kind;tier;pay;need;target, Data's example (Data, TKB-R80)", function()
			local payload = ns.EncodeIssue({ type = "n", kind = "haul", tier = 2, pay = 15, need = 30, target = 33 })

			assert.are.equal("n;haul;2;15;30;33", payload)
		end)

		it("leaves the target empty for a kind without one (Data)", function()
			local payload = ns.EncodeIssue({ type = "n", kind = "wanderer", tier = 3, pay = 20, need = 3 })

			assert.are.equal("n;wanderer;3;20;3;", payload)
		end)

		it("writes a reroll as the old goal's ID, then the new definition, Data's example (Data, TKB-R80)", function()
			local payload =
				ns.EncodeReroll(OLD_ID, { type = "n", kind = "size", tier = 1, pay = 10, need = 3, target = 3 })

			assert.are.equal(OLD_ID .. ";n;size;1;10;3;3", payload)
		end)

		it("writes a Variety Expedition's target as zone:items, comma-separated and ascending (Data)", function()
			local payload = ns.EncodeIssue({
				type = "e",
				kind = "variety",
				tier = 0,
				pay = 60,
				need = 4,
				target = 148,
				items = { 13893, 6358, 6359, 13754 },
			})

			assert.are.equal("e;variety;0;60;4;148:6358,6359,13754,13893", payload)
		end)

		it(
			"keeps the largest Variety Expedition, 12 Species with 6-digit items, under 200 bytes (Data, LOG-R40)",
			function()
				local items = {}
				for i = 1, 12 do
					items[i] = 999999 - i
				end
				local def =
					{ type = "e", kind = "variety", tier = 0, pay = 60, need = 12, target = 999999, items = items }

				local issue, reroll = ns.EncodeIssue(def), ns.EncodeReroll(OLD_ID, def)

				assert.is_true(#issue < 200, "issue: " .. #issue)
				assert.is_true(#reroll < 200, "reroll: " .. #reroll)
			end
		)
	end)

	describe("decoding", function()
		it("reads start and day back as their two times (Data)", function()
			assert.are.same(
				{ kind = "start", dayStart = 1791730800, weekStart = 1791557600 },
				ns.DecodeRecord("start", "1791730800;1791557600")
			)
			assert.are.same(
				{ kind = "day", dayStart = 1791817200, weekStart = 1791557600 },
				ns.DecodeRecord("day", "1791817200;1791557600")
			)
		end)

		it("reads every goal definition back as it was encoded (Data, M7 graph shapes)", function()
			local defs = {
				{ type = "n", kind = "haul", tier = 2, pay = 15, need = 30, target = 33 },
				{ type = "e", kind = "haul", tier = 0, pay = 60, need = 150, target = 14 },
				{ type = "n", kind = "variety", tier = 1, pay = 10, need = 3, target = 17 },
				{ type = "e", kind = "variety", tier = 0, pay = 60, need = 4, target = 148, items = { 6358, 13893 } },
				{ type = "n", kind = "wanderer", tier = 3, pay = 20, need = 3 },
				{ type = "e", kind = "wanderer", tier = 0, pay = 60, need = 5, target = 0 },
				{ type = "n", kind = "quality", tier = 1, pay = 10, need = 3, target = 2 },
				{ type = "e", kind = "size", tier = 0, pay = 60, need = 1, target = 4 },
				{ type = "n", kind = "collector", tier = 2, pay = 15, need = 2 },
				{ type = "e", kind = "collector", tier = 0, pay = 60, need = 3 },
				{ type = "n", kind = "lure", tier = 3, pay = 20, need = 25 },
				{ type = "n", kind = "species", tier = 2, pay = 15, need = 10, target = 6358 },
			}
			for _, def in ipairs(defs) do
				assert.are.same({ kind = "issue", goal = def }, ns.DecodeRecord("issue", ns.EncodeIssue(def)))
				assert.are.same(
					{ kind = "reroll", old = OLD_ID, goal = def },
					ns.DecodeRecord("reroll", ns.EncodeReroll(OLD_ID, def))
				)
			end
		end)

		it("skips a kind it doesn't know (TKB-R80)", function()
			assert.is_nil(ns.DecodeRecord("issue2", "n;haul;2;15;30;33"))
			assert.is_nil(ns.DecodeRecord("note", ""))
		end)

		it("skips a payload it can't parse (TKB-R80)", function()
			for _, case in ipairs({
				{ "start", "" },
				{ "start", "1791730800" },
				{ "day", "1791730800;x" },
				{ "day", "1791730800;1791557600;1" },
				{ "issue", "n;haul;2;15;30" }, -- a field short
				{ "issue", "n;haul;2;15;30;33;1" }, -- a field over
				{ "issue", "n;haul;2;15;30;" }, -- a zone goal without its zone
				{ "issue", "n;lure;2;15;20;7" }, -- a kind without a target with one
				{ "issue", "n;haul;two;15;30;33" },
				{ "issue", "n;haul;2;-15;30;33" },
				{ "issue", "e;variety;0;60;4;148" }, -- a Variety Expedition without its items
				{ "issue", "e;variety;0;60;4;148:" },
				{ "issue", "e;variety;0;60;4;148:6358,,13893" },
				{ "issue", "n;variety;1;10;3;148:6358" }, -- a Variety Notice's target is the zone alone
				{ "reroll", "n;haul;2;15;30;33" }, -- no old goal
				{ "reroll", ";n;haul;2;15;30;33" },
			}) do
				assert.is_nil(ns.DecodeRecord(case[1], case[2]), case[1] .. "|" .. case[2])
			end
		end)

		it(
			"skips values out of range: an unknown type or kind, a tier outside 0–3, a need below 1 (TKB-R80)",
			function()
				for _, payload in ipairs({
					"x;haul;2;15;30;33",
					"n;fishing;2;15;30;33",
					"n;haul;4;15;30;33",
					"n;haul;2;15;0;33",
				}) do
					assert.is_nil(ns.DecodeRecord("issue", payload), payload)
					assert.is_nil(ns.DecodeRecord("reroll", OLD_ID .. ";" .. payload), payload)
				end
			end
		)
	end)
end)
