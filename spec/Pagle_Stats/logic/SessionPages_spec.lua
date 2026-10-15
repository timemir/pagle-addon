-- The Session pages' order and paging (stats.md › UI › This Session, Sessions; Tunables): which Sessions the ruled
-- ledgers list, newest first, on which page of the Sessions ledger a Session falls, which Sessions come before the one
-- shown, and the order of an entry's zones and characters. Pure logic over Session indices (oldest first, STA-R30) and
-- a Session record's `zones` and `chars`.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

describe("the Session pages' order and paging", function()
	local ns = stats.load().ns

	describe("the Sessions ledger (stats.md › UI › Sessions; Tunables: 16 per page)", function()
		it("puts twenty Sessions on two pages of 16 and 4, newest first", function()
			local first = ns.SessionLedger(20, 1)
			local second = ns.SessionLedger(20, 2)

			assert.are.same({ 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5 }, first.indices)
			assert.are.same({ 4, 3, 2, 1 }, second.indices)
			assert.are.same({ 1, 2 }, { first.page, first.pages })
			assert.are.same({ 2, 2 }, { second.page, second.pages })
		end)

		it("hides each arrow at its end: no later on page 1, no earlier on the last page", function()
			local first, middle, last = ns.SessionLedger(40, 1), ns.SessionLedger(40, 2), ns.SessionLedger(40, 3)

			assert.are.same({ false, true }, { first.later, first.earlier })
			assert.are.same({ true, true }, { middle.later, middle.earlier })
			assert.are.same({ true, false }, { last.later, last.earlier })
			assert.are.same({ false, false }, { ns.SessionLedger(16, 1).later, ns.SessionLedger(16, 1).earlier })
		end)

		it("opens on page 1, the newest, with no page given, and keeps a page past either end to the ends", function()
			assert.are.equal(1, ns.SessionLedger(20).page)
			assert.are.equal(2, ns.SessionLedger(20, 9).page)
			assert.are.equal(1, ns.SessionLedger(20, 0).page)
		end)

		it("has one empty page with no Sessions", function()
			local ledger = ns.SessionLedger(0, 1)

			assert.are.same({}, ledger.indices)
			assert.are.same({ 1, 1, false, false }, { ledger.page, ledger.pages, ledger.later, ledger.earlier })
		end)

		it("finds the page a Session falls on: the newest 16 on page 1", function()
			assert.are.same({ 1, 1, 2, 2 }, {
				ns.LedgerPageOf(20, 20),
				ns.LedgerPageOf(20, 5),
				ns.LedgerPageOf(20, 4),
				ns.LedgerPageOf(20, 1),
			})
		end)
	end)

	describe("This Session's earlier Sessions (stats.md › UI › This Session; Tunables: 10)", function()
		it("are the 10 Sessions before the one shown, newest first", function()
			assert.are.same({ 14, 13, 12, 11, 10, 9, 8, 7, 6, 5 }, ns.EarlierSessions(15))
			assert.are.same({ 2, 1 }, ns.EarlierSessions(3))
			assert.are.same({}, ns.EarlierSessions(1))
		end)
	end)

	describe("a Session by its ID (stats.md › UI › Sessions)", function()
		it("is found by Core's Session ID, or nil when no record has it", function()
			local sessions = { { id = "A" }, { id = "B" }, { id = "C" } }

			assert.are.equal(2, ns.FindSession(sessions, "B"))
			assert.is_nil(ns.FindSession(sessions, "Z"))
			assert.is_nil(ns.FindSession(sessions, nil))
		end)
	end)

	describe("an entry's Where and who (stats.md › UI › This Session)", function()
		it("orders zones by Casts, most first, ties by areaID", function()
			assert.are.same({
				{ zone = 33, casts = 9 },
				{ zone = 12, casts = 4 },
				{ zone = 148, casts = 4 },
			}, ns.ZonesByCasts({ [148] = 4, [33] = 9, [12] = 4 }))
		end)

		it("orders characters alphabetically by name, ties by character index", function()
			local names = { "Zed Brook", "Ada Brook", "Ada Brook" }
			local function nameOf(index)
				return names[index]
			end

			assert.are.same({
				{ char = 2, casts = 1, name = "Ada Brook" },
				{ char = 3, casts = 7, name = "Ada Brook" },
				{ char = 1, casts = 5, name = "Zed Brook" },
			}, ns.CharactersByName({ 5, 1, 7 }, nameOf))
		end)
	end)
end)
