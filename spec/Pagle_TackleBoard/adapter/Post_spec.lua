-- Spending a Refresh on an empty slot (TKB-R58, TKB-R59, TKB-R63; REF-R2, REF-R5, ADR 0017): ns.CanPost, ns.Post, the
-- confirm it asks on, the `post` record and the Refreshes spent the Module reports to Core, on FakePagle over the
-- fixture catalogue with a seeded random source. A started board's history is appended with fake.catchLog:Append, then
-- login and the first PLAYER_ENTERING_WORLD build the projection; the Angler holds a Refresh when a spec says so
-- (fake.setTickets, as Hunts' report would leave it). What `ns.Post` appends is read back from the log, its goal from
-- the projection, and what Core was told from fake.ticketReports. The fold of the record itself is in
-- adapter/Projection_spec.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, idAt = board.record, board.idAt

local W = board.WEEK0 -- Tuesday 6 October 2026 15:00 UTC: week 0's weekly reset
-- The board is started today: board day 0 is the day the fake clock is in (its daily reset, 15 minutes before
-- SERVER_TIME), so the projection has no day to catch up on and nothing is owed but what the records issue.
local TODAY = board.DAILY_RESET
local T = TODAY + 60 -- the start record's time; every record of a spec follows it, before SERVER_TIME

local SEED = 11

-- Goals (tackle-board.md › Data), issued right after the start record: an Expedition on Expedition pin 1, then
-- Notices on Notice pins 1, 2 and 3. Notice pins 4-6 and Expedition pin 2 are empty.
local EXPEDITION, HAUL = idAt(T + 1), idAt(T + 2)
local STARTED = {
	record("start", T, TODAY .. ";" .. W),
	record("issue", T + 1, "e;rarity;0;60;8;3"),
	record("issue", T + 2, "n;haul;2;15;30;14"),
	record("issue", T + 3, "n;rarity;1;10;3;2"),
	record("issue", T + 4, "n;wanderer;3;20;3;"),
}
-- Three more Notices and an Expedition: every pin is hung.
local FULL = board.join(STARTED, {
	record("issue", T + 5, "n;lure;3;20;25;"),
	record("issue", T + 6, "n;species;2;15;10;6358"),
	record("issue", T + 7, "n;collector;2;15;2;"),
	record("issue", T + 8, "e;haul;0;60;150;17"),
})

-- The Tackle Board on a FakePagle whose log holds `records` (STARTED by default), built at login with the fixture
-- Angler's skill read, drawing from `random` (default board.random(SEED)). The Angler holds `held` Refreshes: Hunts has
-- earned that many (REF-R5), none spent.
---@param held integer?
---@param records table[]?
---@param random function?
---@return PagleTackleBoardNS ns
---@return LoadedAddon loaded
---@return table fake
local function started(held, records, random)
	local fake = board.withHistory(records or STARTED)
	local loaded = board.load(fake, { random = random or board.random(SEED) })
	fake.login()
	fake.enterWorld()
	board.readSkill(fake)
	if held then
		fake.setTickets("Hunts", held)
	end
	return loaded.ns, loaded, fake
end

-- The `post` records in the log, in order.
local function posts(ns)
	local found = {}
	for entry in ns.Module:IterateCatches(0) do
		if entry.kind == "module" and entry.recordKind == "post" then
			found[#found + 1] = entry
		end
	end
	return found
end

-- What the confirm asks while it shows, its question and what it costs as one line, the red ink left out; nil while it
-- doesn't show.
local function asked(ns)
	local confirm = ns.TakeDownConfirm()
	if not (confirm and confirm:IsShown()) then
		return nil
	end
	local text = confirm.text:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return confirm.title:GetText() .. " " .. text
end

-- Everything Core was told about the Refreshes spent, as { module, total }.
local function spentReports(fake)
	local out = {}
	for _, report in ipairs(fake.ticketReports) do
		if report.kind == "spent" then
			out[#out + 1] = { report.module, report.total }
		end
	end
	return out
end

describe("posting a goal with a Refresh", function()
	describe("when it is allowed (TKB-R58)", function()
		it("is allowed for either type with an empty pin and a Refresh held", function()
			local ns = started(1)

			assert.are.same({ true, true }, { ns.CanPost("n"), ns.CanPost("e") })
		end)

		it("isn't allowed with no Refresh held, and floors at 0: more spent than earned holds none (REF-R5)", function()
			local ns, _, fake = started()

			assert.are.same({ false, false }, { ns.CanPost("n"), ns.CanPost("e") })
			fake.setTickets("Hunts", 1)
			fake.setTickets("TackleBoard", nil, 3)
			assert.are.same({ false, false }, { ns.CanPost("n"), ns.CanPost("e") })
			assert.are.equal(0, fake.Pagle.GetTickets().tickets)
		end)

		it("isn't allowed for a type whose pins are all hung, only for the other (TKB-R57, TKB-R101)", function()
			local ns = started(1, board.join(STARTED, { record("issue", T + 5, "e;haul;0;60;150;17") }))

			assert.are.same({ true, false }, { ns.CanPost("n"), ns.CanPost("e") })
		end)

		it("isn't allowed while the projection is updating (TKB-R108)", function()
			local ns = started(1)
			ns.IsUpdating = function()
				return true
			end

			assert.are.same({ false, false }, { ns.CanPost("n"), ns.CanPost("e") })
		end)

		it("isn't allowed before Start, or for a type the board doesn't have (TKB-R2)", function()
			local unstarted = started(1, {})
			local ns = started(1)

			assert.are.same({ false, false }, { unstarted.CanPost("n"), unstarted.CanPost("e") })
			assert.is_false(ns.CanPost("x"))
			assert.is_false(ns.CanPost(nil))
		end)
	end)

	describe("asking first (TKB-R59)", function()
		it("opens the confirm with the exact text and answers, appending nothing yet", function()
			local ns, loaded = started(1)

			ns.Post("n")

			local confirm = assert(ns.TakeDownConfirm())
			assert.are.equal(
				"Post a new Notice? This uses 1 Refresh, and it can't be undone. The new goal can be taken down once, like any other.",
				asked(ns)
			)
			assert.are.same({ "Post it", "Keep it" }, { confirm.accept.label:GetText(), confirm.keep.label:GetText() })
			-- what it costs is inked in red, as the take-down inks what it loses
			assert.are.equal(
				"This uses |cff9A2A1A1 Refresh|r, and it can't be undone. The new goal can be taken down once, like any other.",
				confirm.text:GetText()
			)
			assert.are.equal(loaded.ns.BOARD_ATLASES.Board.file, (confirm --[[@as table]]).paper.texture)
			assert.are.equal(0, #posts(ns))
		end)

		it('says "Expedition" for an Expedition', function()
			local ns = started(1)

			ns.Post("e")

			assert.are.equal(
				"Post a new Expedition? This uses 1 Refresh, and it can't be undone. The new goal can be taken down once, like any other.",
				asked(ns)
			)
		end)

		it("asks nothing and appends nothing when no Refresh is held, the type is full or it is updating", function()
			local none = started()
			local full = started(1, FULL)
			local updating = started(1)
			updating.IsUpdating = function()
				return true
			end

			none.Post("n")
			full.Post("n")
			full.Post("e")
			updating.Post("n")

			for _, ns in ipairs({ none, full, updating }) do
				assert.is_nil(asked(ns))
				assert.are.equal(0, #posts(ns))
			end
		end)

		it('"Keep it" and Esc append nothing, and the Refresh stays held', function()
			local ns, loaded, fake = started(1)

			ns.Post("n")
			ns.TakeDownConfirm().keep:Click()
			ns.Post("n")
			loaded.client.pressEscape()

			assert.is_nil(asked(ns))
			assert.are.equal(0, #posts(ns))
			assert.are.equal(1, fake.Pagle.GetTickets().tickets)
		end)

		it("closes on one Esc with the board left open, and the next Esc closes the board", function()
			local ns, loaded = started(1)
			ns.ToggleBoard()

			ns.Post("n")
			loaded.client.pressEscape()

			assert.is_nil(asked(ns))
			assert.is_true(ns.board:IsShown())
			loaded.client.pressEscape()
			assert.is_false(ns.board:IsShown())
		end)

		it("is the take-down's own confirm, answering for whichever it was opened for", function()
			local ns = started(1)
			ns.State().goals[HAUL].progress = 12

			ns.Post("n")
			local first = assert(ns.TakeDownConfirm())
			first.keep:Click()
			ns.TakeDown(HAUL)

			assert.are.equal(first, ns.TakeDownConfirm())
			assert.are.equal(
				"Take down this Notice? Its progress (12/30) is lost, and the new one can't be taken down.",
				asked(ns)
			)
			assert.are.same({ "Take it down", "Keep it" }, {
				ns.TakeDownConfirm().accept.label:GetText(),
				ns.TakeDownConfirm().keep.label:GetText(),
			})
			ns.TakeDownConfirm().accept:Click()
			assert.are.equal(0, #posts(ns)) -- "Take it down" never posts
		end)
	end)

	describe("posting (TKB-R58)", function()
		it(
			"appends one post record carrying the goal ns.GenerateGoal draws for the type, on the first empty pin",
			function()
				local ns, _, fake = started(1)
				-- the same draws the post will make: a source of the same seed, nothing drawn from it yet
				local expected =
					ns.GenerateGoal(ns.GenerationContext(ns.State(), fake.serverTime(), board.random(SEED)), "n")

				ns.Post("n")
				ns.TakeDownConfirm().accept:Click()

				local appended = posts(ns)
				assert.are.equal(1, #appended)
				assert.are.equal(ns.EncodePost(expected), appended[1].payload)
				local state = ns.State()
				local goal = state.goals[appended[1].id]
				assert.are.same({ "n", 4, false, 0 }, { goal.type, goal.pin, goal.reposted, goal.progress })
				assert.are.equal(appended[1].id, state.pins.notices[4])
				assert.are.same({ notices = 0, expeditions = 0 }, state.owed) -- nothing owed was taken (nothing was owed)
				assert.is_nil(asked(ns))
			end
		)

		it("posts an Expedition on the Expedition pins, never a Notice", function()
			local ns = started(1)

			ns.Post("e")
			ns.TakeDownConfirm().accept:Click()

			local appended = posts(ns)
			assert.are.equal(1, #appended)
			local decoded = assert(ns.DecodeRecord("post", appended[1].payload))
			assert.are.same({ "e", 0, 60 }, { decoded.goal.type, decoded.goal.tier, decoded.goal.pay })
			assert.are.same({ EXPEDITION, appended[1].id }, ns.State().pins.expeditions)
			assert.are.equal(1, ns.State().ticketsSpent)
		end)

		it(
			"generates by the normal rules: a Notice of a kind the type allows, not one already open if another exists",
			function()
				-- a source that always draws its lowest value picks the first kind by weight, haul, unless it is open
				local ns = started(1, nil, function(m)
					return m or 0
				end)

				ns.Post("n")
				ns.TakeDownConfirm().accept:Click()

				local decoded = assert(ns.DecodeRecord("post", posts(ns)[1].payload))
				assert.are_not.equal("haul", decoded.goal.kind) -- TKB-R32: the open Haul Notice's kind is dropped
				assert.are.equal("n", decoded.goal.type)
			end
		)

		it("spends the Refresh: Core is told one more spent and the count held falls (REF-R5, REF-R2)", function()
			local ns, _, fake = started(1)

			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()

			assert.are.same({ 0, 1, 1 }, {
				fake.Pagle.GetTickets().tickets,
				fake.Pagle.GetTickets().earned,
				fake.Pagle.GetTickets().spent,
			})
			assert.are.same({ { "TackleBoard", 0 }, { "TackleBoard", 1 } }, spentReports(fake))
			assert.is_false(ns.CanPost("n"))
		end)

		it("posts nothing more once the Refresh is spent, and posts again when another is held", function()
			local ns, _, fake = started(1)

			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()
			ns.Post("n")
			assert.is_nil(asked(ns))
			fake.setTickets("Hunts", 2)
			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()

			assert.are.equal(2, #posts(ns))
			assert.are.same({ idAt(T + 2), idAt(T + 3), idAt(T + 4) }, {
				ns.State().pins.notices[1],
				ns.State().pins.notices[2],
				ns.State().pins.notices[3],
			})
			assert.are.same(
				{ posts(ns)[1].id, posts(ns)[2].id },
				{ ns.State().pins.notices[4], ns.State().pins.notices[5] }
			)
		end)

		it("stops at the cap: the last empty pin is filled, the next post is refused (TKB-R20, TKB-R57)", function()
			local ns, _, fake = started(5)

			for _ = 1, 4 do
				ns.Post("n")
				if asked(ns) then
					ns.TakeDownConfirm().accept:Click()
				end
			end

			assert.are.equal(3, #posts(ns)) -- Notice pins 4, 5 and 6; the fourth ask was refused
			assert.are.equal(3, ns.State().ticketsSpent)
			assert.are.equal(2, fake.Pagle.GetTickets().tickets)
			assert.is_nil(ns.State().pins.notices[7])
			assert.is_false(ns.CanPost("n"))
		end)

		it(
			'checks again on "Post it": nothing is appended if the Refresh is gone, the pins are full or an update began',
			function()
				local ns, _, fake = started(1)
				ns.Post("n")
				fake.setTickets("TackleBoard", nil, 1) -- spent elsewhere meanwhile
				ns.TakeDownConfirm().accept:Click()
				assert.are.equal(0, #posts(ns))

				local ns2, _, fake2 = started(1)
				ns2.Post("n")
				for _, entry in ipairs({
					record("issue", T + 300, "n;lure;3;20;25;"),
					record("issue", T + 301, "n;species;2;15;10;6358"),
					record("issue", T + 302, "n;collector;2;15;2;"),
				}) do
					board.live(fake2, entry)
				end
				ns2.TakeDownConfirm().accept:Click()
				assert.are.equal(0, #posts(ns2))

				local ns3 = started(1)
				ns3.Post("n")
				ns3.IsUpdating = function()
					return true
				end
				ns3.TakeDownConfirm().accept:Click()
				assert.are.equal(0, #posts(ns3))
			end
		)

		it(
			"lets a reset that passed refill the board first, then posts where room is left (TKB-R13, TKB-R20)",
			function()
				-- a Notice done leaves two open and nothing owed; the reset owes 3 more, which the live step issues into pins
				-- 1, 4 and 5 before the post, which the last pin is left for
				local ns, _, fake = started(1, {
					record("start", T, TODAY .. ";" .. W),
					record("issue", T + 1, "e;rarity;0;60;8;3"),
					record("issue", T + 2, "n;haul;1;10;1;14"),
					record("issue", T + 3, "n;rarity;1;10;3;2"),
					record("issue", T + 4, "n;wanderer;3;20;3;"),
					board.cast(T + 5, 14, { 6358 }), -- completes the Haul
				})
				assert.are.equal(false, ns.State().pins.notices[1])
				fake.wait(board.DAY) -- the daily reset passed; the reset timer hasn't fired yet

				ns.Post("n")
				ns.TakeDownConfirm().accept:Click()

				local state = ns.State()
				assert.are.equal(1, state.day)
				assert.are.same({ notices = 0, expeditions = 0 }, state.owed)
				local appended = posts(ns)
				assert.are.equal(1, #appended)
				assert.are.equal(appended[1].id, state.pins.notices[6])
				for _, pin in ipairs({ 1, 4, 5 }) do
					assert.are_not.equal(false, state.pins.notices[pin]) -- the owed goals, issued first
					assert.are_not.equal(appended[1].id, state.pins.notices[pin])
				end
			end
		)

		it("posts nothing when that refill takes the last pin, and the Refresh stays (TKB-R20, TKB-R57)", function()
			local ns, _, fake = started(1)
			fake.wait(board.DAY) -- three Notices owed, three pins empty

			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()

			assert.are.equal(0, #posts(ns))
			assert.are.equal(0, ns.State().ticketsSpent)
			assert.are.equal(1, fake.Pagle.GetTickets().tickets)
			assert.is_nil(ns.State().pins.notices[7])
			assert.is_false(ns.State().pins.notices[6] == false)
		end)

		it("works while restricted: the confirm is a plain frame, nothing secure (TKB-R193)", function()
			local ns, _, fake = started(1)
			fake.setRestricted(true)

			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()

			assert.are.equal(1, #posts(ns))
		end)

		it("is a goal that can be taken down once and no more (TKB-R55)", function()
			local ns = started(2)
			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()
			local posted = posts(ns)[1].id

			assert.is_true(ns.CanTakeDown(posted))
			ns.TakeDown(posted)

			local state = ns.State()
			local replacement = state.goals[state.pins.notices[4]]
			assert.is_true(replacement.reposted)
			assert.is_false(ns.CanTakeDown(replacement.id))
			assert.are.equal(1, state.ticketsSpent) -- no refund, no second spend
		end)
	end)

	describe("reporting the Refreshes spent (TKB-R63, REF-R2)", function()
		it("reports the total from done, even unchanged: one per applied post", function()
			local _, _, fake = started(
				nil,
				board.join(STARTED, {
					record("post", T + 300, "n;lure;3;20;25;"),
					record("post", T + 301, "e;haul;0;60;150;17"),
				})
			)

			assert.are.same({ { "TackleBoard", 2 } }, spentReports(fake))
		end)

		it("reports 0 from a done before Start", function()
			local ns, _, fake = started(nil, {})

			assert.is_false(ns.IsStarted())
			assert.are.same({ { "TackleBoard", 0 } }, spentReports(fake))
		end)

		it("reports a total with no post in the log, so a lost PagleDB is filled in again", function()
			local _, _, fake = started()

			assert.are.same({ { "TackleBoard", 0 } }, spentReports(fake))
		end)

		it("reports after each live post that changes it, and not for a post that is dropped (TKB-R57)", function()
			local ns, _, fake = started(5)

			ns.Post("e")
			ns.TakeDownConfirm().accept:Click()
			ns.Module:AppendRecord("post", "e;haul;0;60;150;17") -- no Expedition pin left: dropped
			ns.Module:AppendRecord("issue2", "e;haul;0;60;150;17") -- skipped (TKB-R80)

			assert.are.same({ { "TackleBoard", 0 }, { "TackleBoard", 1 } }, spentReports(fake))
		end)

		it("reports the same total from a rebuild's done as the live run did (TKB-R82)", function()
			local ns, _, fake = started(5)
			ns.Post("n")
			ns.TakeDownConfirm().accept:Click()
			ns.Post("e")
			ns.TakeDownConfirm().accept:Click()
			local liveTotal = spentReports(fake)[#spentReports(fake)][2]

			ns.projection:Rebuild()

			assert.are.equal(2, liveTotal)
			local reports = spentReports(fake)
			assert.are.same({ "TackleBoard", liveTotal }, reports[#reports])
			assert.are.equal(liveTotal, ns.State().ticketsSpent)
		end)

		it("reports 0 from a new dev log's rebuild, clearing the old log's total (TKB-R197, REF-R3)", function()
			local first = board.withHistory(board.join(STARTED, { record("post", T + 300, "n;lure;3;20;25;") }))
			local _, loaded = board.built(first)
			local fake = board.withHistory({ board.cast(T + 310, 14, { 6358 }) }) -- another logId (LOG-R72)
			fake.globals.PagleTackleBoardDB = { global = loaded.env.PagleTackleBoardDB.global }

			board.built(fake)

			assert.are.same({ { "TackleBoard", 1 } }, spentReports(first))
			assert.are.same({ { "TackleBoard", 0 } }, spentReports(fake))
		end)

		it("reports nothing after a live entry while the Module has no handle (CORE-R13)", function()
			local ns, _, fake = started(1)
			ns.Module = nil

			board.live(fake, record("post", T + 300, "n;lure;3;20;25;"))

			assert.are.same({ { "TackleBoard", 0 } }, spentReports(fake))
			assert.are.equal(1, ns.State().ticketsSpent)
		end)

		it("is the number the backend folds from the state alone (REF-R9)", function()
			local ns = started(nil, board.join(STARTED, { record("post", T + 300, "n;lure;3;20;25;") }))

			assert.are.equal(1, ns.TicketsSpent(ns.State()))
		end)
	end)
end)
