-- The Tackle Board's Activity XP (TKB-R60, TKB-R65, TKB-R84; AXP-R2, AXP-R7, ANN-R23; ADR 0011) on FakePagle over the
-- fixture catalogue: a history of the board's own records and Casts appended with fake.catchLog:Append, then login and
-- the first PLAYER_ENTERING_WORLD, then live entries through fake.live. What Core is told is read from fake.xpReports;
-- the Write-up's "Angler XP" line is in adapter/Moments_spec. Every expected value is worked out by hand from the rules.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local start, issue, idAt, cast, copy, withHistory, built, live =
	board.start, board.issue, board.idAt, board.cast, board.copy, board.withHistory, board.built, board.live

local DAY = board.DAY
local D0 = board.DAY0 -- board day 0, the start record's day
local DUROTAR, BARRENS = 14, 17
local BLACKMOUTH = 6358 -- a Haul goal counts a Catch of any item in its zone

-- Goal payloads (Data): Notices of each tier and an Expedition, each done by one Catch in Durotar.
local TIER_1 = "n;haul;1;10;1;14"
local TIER_2 = "n;haul;2;15;1;14"
local TIER_3 = "n;haul;3;20;1;14"
local EXPEDITION = "e;haul;0;60;1;14"

local T = D0 + 3600 -- the start record's time; every record of a spec follows it

-- Each of fake.xpReports as { total, entry ID or false }.
local function reports(fake)
	local out = {}
	for i, report in ipairs(fake.xpReports) do
		assert.are.equal("TackleBoard", report.module)
		out[i] = { report.total, report.entry and report.entry.id or false }
	end
	return out
end

describe("the Tackle Board's Activity XP", function()
	describe("the total (TKB-R60, TKB-R65)", function()
		it("starts at 0 in a new state (tackle-board.md › Data)", function()
			assert.are.equal(0, board.load().ns.NewBoardState().xp)
		end)

		it("adds a tier-2 Notice's 150, an Expedition's 600, and hands the XP on in what it earned", function()
			local earned = {}
			local fake = withHistory({ start(T), issue(T + 1, TIER_2), issue(T + 2, EXPEDITION) })
			local ns = built(fake, {
				prepare = function(loaded)
					loaded.ns.outlets.Completed = function(goal, _, got)
						earned[#earned + 1] = { goal.id, got.xp }
					end
				end,
			})
			local before = ns.State().xp

			live(fake, cast(T + 3, DUROTAR, { BLACKMOUTH }))

			assert.are.equal(0, before)
			-- board order: the Expedition's pin first (TKB-R101)
			assert.are.same({ { idAt(T + 2), 600 }, { idAt(T + 1), 150 } }, earned)
			assert.are.equal(750, ns.State().xp)
		end)

		it("pays 100, 150 and 200 by tier, from the Tunables, whatever the goal's pay says (TKB-R34)", function()
			-- a tier-1 Notice whose record says it pays 15 still pays the tier's XP
			local ns = built(withHistory({
				start(T),
				issue(T + 1, TIER_1),
				issue(T + 2, "n;haul;1;15;1;14"),
				issue(T + 3, TIER_3),
				cast(T + 4, DUROTAR, { BLACKMOUTH }),
			}))

			assert.are.same({ 400, 45 }, { ns.State().xp, ns.State().coins })
		end)

		it("adds nothing for a Campfire milestone or its title (TKB-R65, TKB-R73)", function()
			-- a tier-1 Notice issued and done on each of board days 0–6: the 7th lights the 7-day milestone
			local log = { start(T) }
			for i = 0, 6 do
				log[#log + 1] = issue(T + i * DAY + 1, TIER_1)
				log[#log + 1] = cast(T + i * DAY + 2, DUROTAR, { BLACKMOUTH })
			end
			local last = {}
			local ns = built(withHistory(log), {
				prepare = function(loaded)
					loaded.ns.outlets.Completed = function(_, _, got)
						last = copy(got)
					end
				end,
			})

			local state = ns.State()
			assert.are.same({ campfire_7 = { day = 6, cast = idAt(T + 6 * DAY + 2) } }, state.titles)
			assert.are.same({ 7 * 10 + 25, 7 * 100 }, { state.coins, state.xp })
			assert.are.same({ 35, 100 }, { last.coins, last.xp })
		end)

		it("is not lost when a goal done 28 board days back is dropped (tackle-board.md › Data)", function()
			local ns = built(withHistory({
				start(T),
				issue(T + 1, TIER_3),
				cast(T + 2, DUROTAR, { BLACKMOUTH }),
				cast(T + 28 * DAY, BARRENS),
			}))

			assert.is_nil(ns.State().goals[idAt(T + 1)])
			assert.are.equal(200, ns.State().xp)
		end)
	end)

	describe("reporting it (TKB-R65, AXP-R2, AXP-R7)", function()
		it("reports a live completion once, with that Cast as the entry", function()
			local fake = withHistory({ start(T), issue(T + 1, TIER_2) })
			built(fake)

			live(fake, cast(T + 2, BARRENS, { BLACKMOUTH })) -- changes the state, not the XP
			live(fake, cast(T + 3, DUROTAR, { BLACKMOUTH }))
			live(fake, cast(T + 4, DUROTAR, { BLACKMOUTH })) -- nothing left open to complete

			assert.are.same({ { 0, false }, { 150, idAt(T + 3) } }, reports(fake))
			local xp = fake.Pagle.GetActivityXP()
			assert.are.same(
				{ 150, 150, true },
				{ xp.total, xp.bySource.TackleBoard.total, xp.bySource.TackleBoard.enabled }
			)
		end)

		it("reports from done, beside the Coins (TKB-R63)", function()
			local fake = withHistory({ start(T), issue(T + 1, EXPEDITION), cast(T + 2, DUROTAR, { BLACKMOUTH }) })

			built(fake)

			assert.are.same({ { 600, false } }, reports(fake))
			assert.are.same({ { module = "TackleBoard", total = 60 } }, fake.coinReports)
		end)

		it("reports 0 from a done before Start", function()
			local fake = withHistory({ cast(T, DUROTAR, { BLACKMOUTH }) })

			local ns = built(fake)

			assert.is_false(ns.IsStarted())
			assert.are.same({ { 0, false } }, reports(fake))
		end)

		it("reports 0 from a new dev log's rebuild, clearing the old log's total (TKB-R197, AXP-R3)", function()
			local first = withHistory({ start(T), issue(T + 1, TIER_1), cast(T + 2, DUROTAR, { BLACKMOUTH }) })
			local _, loaded = built(first)
			local fake = withHistory({ cast(T + DAY, DUROTAR, { BLACKMOUTH }) }) -- another logId (LOG-R72)
			fake.globals.PagleTackleBoardDB = { global = loaded.env.PagleTackleBoardDB.global }

			built(fake)

			assert.are.same({ { 100, false } }, reports(first))
			assert.are.same({ { 0, false } }, reports(fake))
		end)

		it("reports the same total from a rebuild's done as the live run did (TKB-R82)", function()
			local fake = withHistory({ start(T), issue(T + 1, TIER_2), issue(T + 2, EXPEDITION) })
			local ns = built(fake)
			live(fake, cast(T + 3, DUROTAR, { BLACKMOUTH }))
			live(fake, issue(T + 4, TIER_3))
			live(fake, cast(T + 5, DUROTAR, { BLACKMOUTH }))
			local liveTotal = fake.xpReports[#fake.xpReports].total

			ns.projection:Rebuild()

			assert.are.equal(150 + 600 + 200, liveTotal)
			assert.are.same({ liveTotal, false }, reports(fake)[#fake.xpReports])
			assert.are.equal(liveTotal, ns.State().xp)
		end)

		it("reports nothing after a live entry while the Module has no handle (CORE-R13)", function()
			local fake = withHistory({ start(T), issue(T + 1, TIER_1) })
			local ns = built(fake)
			ns.Module = nil

			live(fake, cast(T + 2, DUROTAR, { BLACKMOUTH }))

			assert.are.same({ { 0, false } }, reports(fake))
			assert.are.equal(100, ns.State().xp)
		end)

		it("leaves the Notice's toast stamped with its Coins alone (ANN-R23)", function()
			local fake = withHistory({ start(T), issue(T + 1, TIER_2) })
			built(fake)

			live(fake, cast(T + 2, DUROTAR, { BLACKMOUTH }))
			fake.nextFrame() -- Core shows the moment on the frame after it is raised

			local toast = fake.announcements[1]
			assert.are.same({ "noticeDone", 15, {} }, { toast.headline.kind, toast.coins, toast.stamps })
			assert.is_nil(toast.headline.xp)
		end)
	end)
end)
