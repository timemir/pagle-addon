-- Start my board and the live step (TKB-R2, TKB-R5, TKB-R13, TKB-R14, TKB-R20, TKB-R21, TKB-R80, TKB-R86, TKB-R193,
-- TKB-R195; LOG-R40, LOG-R74) on FakePagle over the fixture catalogue, with the injected reset API (following the
-- fake's server time) and random source, and the fake client's timers: the board's records are read back from the
-- Catch log, and every expected value is worked out by hand from the rules.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, pass = board.record, board.pass

local DAY = board.DAY
local NOW = SERVER_TIME -- Sunday 11 October 2026 15:15 UTC: board day began at board.DAILY_RESET, 15 minutes ago
local WEEK_START = board.WEEK0 -- Tuesday 6 October 15:00 UTC: the week NOW is in

-- The Tackle Board's own records in the Catch log, in order, as "kind payload".
local function boardRecords(fake)
	local out = {}
	for entry in fake.catchLog:Iterate(0, "TackleBoard") do
		if entry.kind == "module" then
			out[#out + 1] = entry.recordKind .. " " .. entry.payload
		end
	end
	return out
end

-- The goal types of `records`' issue records, in order ("e" or "n").
local function issuedTypes(records)
	local types = {}
	for _, text in ipairs(records) do
		local goalType = text:match("^issue (%a);")
		if goalType then
			types[#types + 1] = goalType
		end
	end
	return types
end

-- The seconds of every reset timer the board arms (C_Timer.NewTicker on the load's client), in order.
local function watchTimers(loaded)
	local armed = {}
	local timer = loaded.env.C_Timer
	local newTicker = timer.NewTicker
	timer.NewTicker = function(seconds, callback, iterations)
		armed[#armed + 1] = seconds
		return newTicker(seconds, callback, iterations)
	end
	return armed
end

-- The Tackle Board on `fake` (a new FakePagle if nil, whose Angler's skill is read once the build is over) with its
-- first build over: logged in, the projection caught up and the frame after `done` run.
---@return PagleTackleBoardNS ns
---@return LoadedAddon loaded
---@return table fake
---@return number[] armed the reset timers' seconds, in the order armed
local function ready(fake, options)
	local fresh = fake == nil
	local loaded
	loaded, fake = board.load(fake, options)
	local armed = watchTimers(loaded)
	fake.login()
	fake.enterWorld()
	if fresh then
		board.readSkill(fake)
	end
	loaded.client.runTimers()
	return loaded.ns, loaded, fake, armed
end

-- A new FakePagle whose log has the player's character, the Angler's skill (board.SKILL, read an hour before NOW),
-- then a board started at NOW with its first four goals, as Start leaves it; then `days` days go by.
local function startedDaysAgo(days)
	local fake = board.withHistory({
		board.skill(NOW - 3600),
		record("start", NOW, board.DAILY_RESET .. ";" .. WEEK_START),
		record("issue", NOW + 1, "e;size;0;60;1;4"),
		record("issue", NOW + 2, "n;haul;2;15;30;14"),
		record("issue", NOW + 3, "n;quality;1;10;3;2"),
		record("issue", NOW + 4, "n;lure;3;20;25;"),
	})
	fake.wait(days * DAY)
	return fake
end

-- The open goals of each type.
local function openCounts(ns)
	local counts = { n = 0, e = 0 }
	for _, goal in pairs(ns.State().goals) do
		if goal.doneDay == nil then
			counts[goal.type] = counts[goal.type] + 1
		end
	end
	return counts
end

describe("Start my board (TKB-R5)", function()
	it("appends a start record, then issues an Expedition and three Notices, and arms the reset timer", function()
		local ns, _, fake, armed = ready()

		ns.Start()

		local records = boardRecords(fake)
		-- TKB-R5, TKB-R10: today's and this week's starts
		assert.are.equal("start " .. board.DAILY_RESET .. ";" .. WEEK_START, records[1])
		-- TKB-R20, TKB-R21: 1 Expedition, then 3 Notices
		assert.are.same({ "e", "n", "n", "n" }, issuedTypes(records))
		assert.are.equal(5, #records)
		-- TKB-R13: the next daily reset is 23 h 45 min away, plus the 2 s delay
		assert.are.same({ DAY - 900 + 2 }, armed)
		assert.is_true(ns.IsStarted())
		assert.are.same({ notices = 0, expeditions = 0 }, ns.State().owed)
	end)

	it("appends nothing, and arms no timer, while the projection is updating (TKB-R5, LOG-R74)", function()
		local loaded, fake = board.load()
		local armed = watchTimers(loaded)
		fake.login()

		loaded.ns.Start()

		assert.is_true(loaded.ns.IsUpdating())
		assert.are.same({}, boardRecords(fake))
		assert.are.same({}, armed)
	end)

	it("appends nothing once the board is started (TKB-R5, TKB-R6)", function()
		local ns, _, fake, armed = ready()
		ns.Start()

		ns.Start()

		assert.are.equal(5, #boardRecords(fake))
		assert.are.equal(1, #armed)
	end)

	it("only opens the board from the root's Start my board while the projection is updating (TKB-R1)", function()
		local loaded, fake = board.load()
		fake.login()

		loaded.ns.ModuleDef().settingsAction.onClick()

		assert.are.same({}, boardRecords(fake))
		assert.is_true(loaded.ns.board:IsShown())
	end)

	it("starts and opens the board from the root's Start my board once the build is over (TKB-R1)", function()
		local ns, _, fake = ready()

		ns.ModuleDef().settingsAction.onClick()

		assert.are.equal(5, #boardRecords(fake))
		assert.is_true(ns.board:IsShown())
	end)

	it("starts the board while restricted: no secure code (TKB-R193)", function()
		local ns, _, fake, armed = ready()
		fake.setRestricted(true)

		ns.Start()

		assert.are.equal(5, #boardRecords(fake))
		assert.are.equal(1, #armed)
	end)
end)

describe("the live step (TKB-R13)", function()
	it("never runs before Start: logging in and the resets append nothing and arm no timer (TKB-R2)", function()
		local ns, loaded, fake, armed = ready()

		pass(loaded, fake, 3 * DAY)

		assert.are.same({}, boardRecords(fake))
		assert.are.same({}, armed)
		assert.is_false(ns.IsStarted())
	end)

	it("at a login three days on, advances, appends a day record and issues what's owed, up to the caps", function()
		-- TKB-R13, TKB-R14, TKB-R20, TKB-R21, TKB-R195: days 0–2 close; closing day 0 owes 3 Notices (6 − 3 open),
		-- days 1 and 2 none (the cap); day 2 is the first of week 1 (the weekly reset was Tuesday 13 October), so 1
		-- Expedition more (2 − 1 open).
		local ns, _, fake = ready(startedDaysAgo(3))

		local records = boardRecords(fake)
		assert.are.equal(10, #records)
		assert.are.equal("day " .. (board.DAILY_RESET + 3 * DAY) .. ";" .. board.WEEKLY_RESET, records[6])
		assert.are.same({ "e", "n", "n", "n" }, issuedTypes({ unpack(records, 7) }))
		assert.are.same({ n = 6, e = 2 }, openCounts(ns))
		local state = ns.State()
		assert.are.same({ 3, 1, 3, 1 }, { state.day, state.week, state.boundary.day, state.boundary.week })
		assert.are.same({ notices = 0, expeditions = 0 }, state.owed)
	end)

	it(
		"at a chunked login build with a costly done, still issues every goal owed: 10 records, 6 Notices and 2"
			.. " Expeditions open, nothing owed (TKB-R13, TKB-R21, LOG-R74)",
		function()
			-- Every step costs 3 ms of the 4 ms budget, so Core reads back the records the step appends in later frames
			-- than done's; the board's timers run first on each frame, as C_Timer.After(0) does after a done.
			local loaded, fake = board.load(startedDaysAgo(3))
			board.updating(fake, true, 3)
			fake.login()
			fake.enterWorld()
			for _ = 1, 50 do
				loaded.client.runTimers()
				fake.nextFrame()
			end

			local records = boardRecords(fake)
			assert.are.equal(10, #records)
			assert.are.same({ "e", "n", "n", "n" }, issuedTypes({ unpack(records, 7) }))
			assert.are.same({ n = 6, e = 2 }, openCounts(loaded.ns))
			assert.are.same({ notices = 0, expeditions = 0 }, loaded.ns.State().owed)
			assert.are.same({}, fake.reported)
		end
	)

	it(
		"does nothing at Start between a chunked build's done and the end of its live phase (TKB-R5, LOG-R74)",
		function()
			-- A Cast appended during the build, which Core reads back as live after done (LOG-R74).
			local loaded, fake = board.load(board.withHistory({ board.skill(NOW - 3600) }))
			board.updating(fake, true, 3)
			fake.login()
			fake.enterWorld()
			board.live(fake, board.cast(NOW + 60, 14, { 6358 }))
			local inLivePhase
			for _ = 1, 50 do
				fake.nextFrame()
				-- done has run (finish wrote the rules version) and Core is still reading back the live entries
				local stored = loaded.env.PagleTackleBoardDB.global.board
				if stored and stored.rulesVersion and loaded.ns.IsUpdating() then
					inLivePhase = true
					break
				end
			end

			loaded.ns.Start()

			assert.is_true(inLivePhase)
			assert.are.same({}, boardRecords(fake))
			assert.is_false(loaded.ns.IsStarted())
		end
	)

	it("runs on the frame after done, never in it: Core's append errors never fire (LOG-R40, TKB-R80)", function()
		local loaded, fake = board.load(startedDaysAgo(3))
		fake.login()

		fake.enterWorld()
		local before = #boardRecords(fake)
		loaded.client.runTimers()

		assert.are.equal(5, before)
		assert.are.equal(10, #boardRecords(fake))
		assert.are.same({}, fake.reported)
	end)

	it("appends nothing at a second step the same day (TKB-R195)", function()
		local ns, loaded, fake = ready(startedDaysAgo(3))

		ns.ScheduleLiveStep()
		ns.ScheduleLiveStep()
		loaded.client.runTimers()

		assert.are.equal(10, #boardRecords(fake))
	end)

	it("updates the summary line, then redraws, once per step (TKB-R13, TKB-R87)", function()
		local calls = {}
		local ns, loaded = ready(startedDaysAgo(1), {
			prepare = function(loading)
				loading.ns.outlets.Stepped = function()
					calls[#calls + 1] = "Stepped"
				end
				loading.ns.OnRedraw(function(reason)
					if reason == "step" then
						calls[#calls + 1] = "Redraw step"
					end
				end)
			end,
		})

		ns.ScheduleLiveStep()
		ns.ScheduleLiveStep() -- the same frame: one step
		loaded.client.runTimers()

		assert.are.same({ "Stepped", "Redraw step", "Stepped", "Redraw step" }, calls)
	end)

	it("runs at the reset, through the timer: a day record and the Notices owed (TKB-R13, TKB-R195)", function()
		local ns, loaded, fake, armed = ready()
		ns.Start()

		pass(loaded, fake, DAY - 900 + 1)
		local before = #boardRecords(fake)
		pass(loaded, fake, 1)

		assert.are.equal(5, before)
		local records = boardRecords(fake)
		assert.are.equal("day " .. (board.DAILY_RESET + DAY) .. ";" .. WEEK_START, records[6])
		assert.are.same({ "e", "n", "n", "n", "n", "n", "n" }, issuedTypes(records))
		assert.are.equal(9, #records)
		-- re-armed 2 s after the reset: the next is a day away less those 2 s, plus the 2 s delay
		assert.are.same({ DAY - 900 + 2, DAY }, armed)
	end)

	it("keeps one reset timer: re-arming cancels the earlier one, so the reset runs one step (TKB-R13)", function()
		local steps = 0
		local ns, loaded, fake, armed = ready(nil, {
			prepare = function(loading)
				loading.ns.outlets.Stepped = function()
					steps = steps + 1
				end
			end,
		})
		ns.Start()
		pass(loaded, fake, 3600)
		ns.ScheduleLiveStep()
		loaded.client.runTimers()

		pass(loaded, fake, DAY - 900 + 2 - 3600) -- to 2 s after the reset, when both timers were due

		assert.are.same({ DAY - 900 + 2, DAY - 900 + 2 - 3600, DAY }, armed)
		assert.are.equal(3, steps) -- Start's, the scheduled one and the reset's
		assert.are.equal(9, #boardRecords(fake))
	end)

	it("does nothing when the timer fires while updating; the next done runs it (TKB-R195, LOG-R74)", function()
		local ns, loaded, fake = ready()
		ns.Start()
		board.updating(fake, true) -- the rebuild runs over later frames
		ns.projection:Rebuild()

		pass(loaded, fake, DAY)
		local whileUpdating = { ns.IsUpdating(), #boardRecords(fake) }
		local frames = 0
		while ns.IsUpdating() and frames < 10 do
			fake.nextFrame()
			frames = frames + 1
		end
		local afterDone = #boardRecords(fake)
		loaded.client.runTimers()

		assert.are.same({ true, 5 }, whileUpdating)
		assert.are.equal(5, afterDone)
		local records = boardRecords(fake)
		assert.are.equal(9, #records)
		assert.are.equal("day " .. (board.DAILY_RESET + DAY) .. ";" .. WEEK_START, records[6])
	end)

	it("runs at the reset while restricted (TKB-R193)", function()
		local ns, loaded, fake = ready()
		ns.Start()
		fake.setRestricted(true)

		pass(loaded, fake, DAY)

		assert.are.equal(9, #boardRecords(fake))
	end)
end)

describe("the login window (TKB-R86)", function()
	it("is open from login until the login's first live step ends; that step's advance is live, at login", function()
		local advances = {}
		local loaded, fake = board.load(startedDaysAgo(3), {
			prepare = function(loading)
				loading.ns.outlets.Advanced = function(result, mode)
					advances[#advances + 1] = { result.from, result.to, mode, loading.ns.InLoginWindow() }
				end
			end,
		})
		local ns = loaded.ns
		local windows = { ns.InLoginWindow() }
		fake.login()
		fake.enterWorld()
		windows[2] = ns.InLoginWindow()

		loaded.client.runTimers()
		windows[3] = ns.InLoginWindow()
		pass(loaded, fake, DAY)

		assert.are.same({ true, true, false }, windows)
		assert.are.same({ { 0, 3, "live", true }, { 3, 4, "live", false } }, advances)
	end)
end)
