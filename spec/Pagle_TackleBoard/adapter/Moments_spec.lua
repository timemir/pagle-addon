-- The Tackle Board's moments (TKB-R2, TKB-R83–R87, TKB-R190–R192; ANN-R4, ANN-R10, ANN-R11, ANN-R23, ANN-R51,
-- ANN-R60–R63; LOG-R76) on FakePagle over the fixture catalogue: a history of the board's own records and Casts
-- appended with fake.catchLog:Append, then login, the first build and the live step, then live entries through
-- fake.live and days passing on the fake's clock. What the Angler would be told is read from what Core would show
-- (fake.announcements), keep (fake.summarized, fake.writeUps) and print on the Session summary (its lines). Every
-- expected value is worked out by hand from the rules.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, idAt, join, withHistory = board.record, board.idAt, board.join, board.withHistory

local DAY, WEEK = board.DAY, board.WEEK
local NOW = SERVER_TIME -- Sunday 11 October 2026 15:15 UTC: board day 6 below began at board.DAILY_RESET
local TODAY = board.DAILY_RESET -- Sunday 11 October 15:00 UTC: the board day NOW is in
local D0 = TODAY - 6 * DAY -- Monday 5 October 15:00 UTC: board day 0 of a board started 6 days ago
local W0 = board.WEEKLY_RESET - 2 * WEEK -- Tuesday 29 September 15:00 UTC: the week day 0 is in
local DUROTAR = 14
local BLACKMOUTH = 6358 -- Oily Blackmouth; the fixture lists it in Darkshore, The Barrens and Westfall, but a Haul goal
-- counts a Catch of any item in its zone

-- Goal payloads (Data): a Notice and an Expedition done by one Catch in Durotar, and fillers for every pin that no
-- Durotar Catch counts toward, so nothing is ever owed and the live step issues nothing.
local ONE = "n;haul;1;10;1;14"
local ONE_E = "e;haul;0;60;1;14"
local N_FILLER = "n;haul;2;15;30;17"
local E_FILLER = "e;haul;0;60;100;17"

-- A Cast record in Durotar: `items` are item IDs (none: got away).
local function cast(time, items)
	local slots = {}
	for i, itemID in ipairs(items or {}) do
		slots[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = items and "caught" or "gotAway",
		conditions = {
			minute = 600,
			zone = DUROTAR,
			subzone = 0,
			skillRank = 150,
			skillMod = 0,
			events = {},
			auras = {},
		},
		items = slots,
	}
end

-- A Catch of a Blackmouth in Durotar at `time`.
local function catch(time)
	return cast(time, { BLACKMOUTH })
end

-- The start of a board started at `start`, on board day 0 beginning at `dayStart`, with every pin filled: the
-- Angler's skill, the start record, two Expedition and six Notice fillers.
local function started(dayStart, start)
	local out = {
		board.skill(start - 3600),
		record("start", start, dayStart .. ";" .. W0),
	}
	for i = 1, 2 do
		out[#out + 1] = record("issue", start + i, E_FILLER)
	end
	for i = 1, 6 do
		out[#out + 1] = record("issue", start + 2 + i, N_FILLER)
	end
	return out
end

-- A Notice done on each of board days `first`..`last`: its issue record half an hour into the day, its Catch an hour
-- in.
local function doneEachDay(first, last)
	local out = {}
	for k = first, last do
		out[#out + 1] = record("issue", D0 + k * DAY + 1800, ONE)
		out[#out + 1] = catch(D0 + k * DAY + 3600)
	end
	return out
end

-- The Tackle Board loaded on `fake` (Durotar named in the client), logged in, its first build over, then the live
-- step the build's done schedules and the frames after it run.
---@return PagleTackleBoardNS ns
---@return LoadedAddon loaded
local function ready(fake, options)
	local loaded = board.load(fake, options)
	loaded.client.areaNames[DUROTAR] = "Durotar"
	fake.login()
	fake.enterWorld()
	loaded.client.runTimers()
	fake.nextFrame()
	fake.nextFrame()
	return loaded.ns, loaded
end

-- Appends `entry` to `fake`'s log and hands it to the projections live (LOG-R73), then runs the frame after it.
local function live(fake, entry)
	fake.live(fake.catchLog:Append(entry))
	fake.nextFrame()
end

-- The icon of fly pattern `id` (Data).
local function flyIcon(ns, id)
	for _, pattern in ipairs(ns.FLY_PATTERNS) do
		if pattern.id == id then
			return pattern.icon
		end
	end
end

-- The moments' fields a spec reads, as raised.
local function shown(moment)
	return {
		kind = moment.kind,
		rung = moment.rung,
		order = moment.order,
		title = moment.title,
		text = moment.text,
		icon = moment.icon,
		stamp = moment.stamp,
		cast = moment.cast,
		coins = moment.coins,
		summaryOnly = moment.summaryOnly,
	}
end

describe("the Tackle Board's moments", function()
	describe("a live completion (TKB-R86, ANN-R10, ANN-R11, ANN-R23)", function()
		it("raises one Notice complete toast with its text, its fly, its stamp, its pay and its Cast", function()
			local fake = withHistory(join(started(TODAY, TODAY + 60), { record("issue", TODAY + 120, ONE) }))
			local ns, loaded = ready(fake)
			local goal = idAt(TODAY + 120)

			live(fake, catch(NOW + 10))

			local fly = ns.State().goals[goal].fly
			assert.is_not_nil(fly)
			assert.are.equal(1, #fake.announcements)
			local announcement = fake.announcements[1]
			assert.are.same({ rung = "toast.low", stamps = {}, coins = 10 }, {
				rung = announcement.rung,
				stamps = announcement.stamps,
				coins = announcement.coins,
			})
			assert.are.same({
				kind = "noticeDone",
				rung = "toast.low",
				title = "Notice complete",
				text = "1 Catch in Durotar. Tied for your Fly Box: " .. fly,
				icon = flyIcon(ns, fly),
				stamp = "Notice done",
				cast = idAt(NOW + 10),
				coins = 10,
			}, shown(announcement.headline))
			-- TKB-R83: raised, so celebrated
			assert.is_true(loaded.env.PagleTackleBoardDB.global.celebrated.goals[goal])
		end)

		it("raises an Expedition complete toast with its pay, stamp and rare fly", function()
			local fake = withHistory(join(started(TODAY, TODAY + 60), { record("issue", TODAY + 120, ONE_E) }))
			local ns = ready(fake)

			live(fake, catch(NOW + 10))

			local fly = ns.State().goals[idAt(TODAY + 120)].fly
			assert.are.equal(1, #fake.announcements)
			assert.are.same({
				kind = "expeditionDone",
				rung = "toast",
				title = "Expedition complete",
				text = "1 Catch in Durotar. Tied for your Fly Box: " .. fly,
				icon = flyIcon(ns, fly),
				stamp = "Expedition done",
				cast = idAt(NOW + 10),
				coins = 60,
			}, shown(fake.announcements[1].headline))
		end)

		-- A board started 6 days ago with a Notice done on each of days 0–5 (a 6-day Campfire), and a Notice issued
		-- today (day 6).
		local SIX_DAYS = join(started(D0, D0 + 60), doneEachDay(0, 5), { record("issue", TODAY + 120, ONE) })

		it(
			"raises the 7th lit day's Campfire banner and the Notice's toast as the Cast's two Announcements, each with its own Coins",
			function()
				local fake = withHistory(SIX_DAYS)
				local _, loaded = ready(fake)

				live(fake, catch(NOW + 10))

				-- ANN-R10, ANN-R11 (#249): the big side first, the banner, then the Notice's toast; ANN-R23: each one's
				-- Coins stamp sums its own moments, 25 and 10.
				assert.are.equal(2, #fake.announcements)
				local banner, toast = fake.announcements[1], fake.announcements[2]
				assert.are.same({ rung = "banner", stamps = {}, coins = 25 }, {
					rung = banner.rung,
					stamps = banner.stamps,
					coins = banner.coins,
				})
				assert.are.same({
					kind = "campfireMilestone",
					rung = "banner",
					order = 10,
					title = "Campfire: 7 days",
					text = "Title: campfire_7", -- the ID: the support leaves the shipped lore out (TKB-R130)
					icon = loaded.ns.REWARD_ICONS.campfire,
					cast = idAt(NOW + 10),
					coins = 25,
				}, shown(banner.headline))
				assert.are.same(
					{ "noticeDone", "toast.low", idAt(NOW + 10), 10 },
					{ toast.headline.kind, toast.rung, toast.headline.cast, toast.coins }
				)
				assert.is_true(loaded.env.PagleTackleBoardDB.global.celebrated.titles.campfire_7)
			end
		)

		it(
			"raises nothing for a celebrated goal or title, which still pay: the milestone's Coins only in the total (TKB-R83)",
			function()
				local goal = idAt(TODAY + 120)
				local fake = withHistory(SIX_DAYS)
				local ns = ready(fake, {
					prepare = function(loaded)
						loaded.env.PagleTackleBoardDB = {
							global = { celebrated = { goals = {}, titles = { campfire_7 = true } } },
						}
					end,
				})
				local coins = ns.State().coins

				live(fake, catch(NOW + 10))

				assert.are.equal(1, #fake.announcements)
				assert.are.same(
					{ "noticeDone", 10, {} },
					{ fake.announcements[1].headline.kind, fake.announcements[1].coins, fake.announcements[1].stamps }
				)
				assert.are.equal(coins + 35, ns.State().coins)
				assert.is_true(ns.db.global.celebrated.goals[goal])
			end
		)
	end)

	describe("the Campfire nods (TKB-R86)", function()
		-- A Notice done on days 0–4 of a board started 6 days ago: day 5 went by without a goal.
		local MISSED_ONE = join(started(D0, D0 + 60), doneEachDay(0, 4))

		-- The nods Core would show, as { kind, text }.
		local function nods(fake)
			local out = {}
			for _, announcement in ipairs(fake.announcements) do
				local moment = announcement.headline
				assert.are.same({ "nod", nil, nil }, { moment.rung, moment.cast, announcement.cast })
				out[#out + 1] = { moment.kind, moment.title }
			end
			return out
		end

		it(
			"words a Kindling burned at login for while away, at a reset while logged in for a day without a goal, "
				.. "and the fire going out without (TKB-R72)",
			function()
				local fake = withHistory(MISSED_ONE)
				local loaded = board.load(fake)
				fake.login()
				fake.enterWorld()
				loaded.client.runTimers() -- the login's live step: days 4 (lit) and 5 (Kindling 2 -> 1) close
				fake.nextFrame()
				local atLogin = nods(fake)

				-- Each reset passes while logged in: day 6 burns the last Kindling, day 7 puts the fire out.
				for _ = 1, 2 do
					fake.wait(DAY)
					loaded.client.advance(DAY)
					fake.nextFrame()
				end

				assert.are.same({
					{
						"kindlingBurned",
						"Your Campfire kept burning while you were away: 1 Kindling used, still 5 days.",
					},
				}, atLogin)
				assert.are.same({
					atLogin[1],
					{ "kindlingBurned", "A day went by without a goal: 1 Kindling used. Campfire still 5 days." },
					{
						"fireOut",
						"Your Campfire went out. Your longest, 5 days, is kept for good. "
							.. "Any goal lights a new one, with 2 fresh Kindling.",
					},
				}, nods(fake))
			end
		)

		it("words the fire going out at login for while away", function()
			-- days 0 and 1 lit, then days 2 and 3 burn both Kindling and day 4 puts it out
			local fake = withHistory(join(started(D0, D0 + 60), doneEachDay(0, 1)))
			ready(fake)

			assert.are.same({
				{
					"fireOut",
					"Your Campfire went out while you were away. Your longest, 2 days, is kept for good. "
						.. "Any goal lights a new one, with 2 fresh Kindling.",
				},
			}, nods(fake))
		end)

		it("raises none for days the first build closes (TKB-R84)", function()
			-- the history's Casts close day 5 (Kindling burned) on the way to day 6, lit at login's step
			local fake = withHistory(join(MISSED_ONE, { record("issue", TODAY + 60, ONE), catch(TODAY + 120) }))
			ready(fake)

			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.summarized)
		end)
	end)

	-- Each Write-up section the Tackle Board raised, as its heading followed by its lines.
	local function writeUps(fake)
		local sections = {}
		for i, section in ipairs(fake.writeUps) do
			assert.are.equal("TackleBoard", section.module)
			sections[i] = { section.heading, unpack(section.lines) }
		end
		return sections
	end

	describe("a first build (TKB-R84, TKB-R85, TKB-R192, LOG-R76)", function()
		it("over a history with a start record raises one Write-up section and no moment, and marks all", function()
			-- day 0 began yesterday: a Cast before the start record, a Notice done on day 0 and one today, and a Cast
			-- that got away: 3 Casts since the start record
			local yesterday = TODAY - DAY
			local fake = withHistory(join({ catch(yesterday + 10) }, started(yesterday, yesterday + 60), {
				record("issue", yesterday + 120, ONE),
				catch(yesterday + 3600),
				record("issue", TODAY + 60, ONE),
				catch(TODAY + 120),
				cast(TODAY + 180),
			}))
			local _, loaded = ready(fake)

			assert.are.same({
				{
					"Your Tackle Board was written up from 3 Casts",
					"2 Notices done",
					"Pagle Coins +20",
					"2 flies tied for your Fly Box",
					"Campfire 2 days",
				},
			}, writeUps(fake))
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.summarized)
			assert.are.same(
				{ goals = { [idAt(yesterday + 120)] = true, [idAt(TODAY + 60)] = true }, titles = {} },
				loaded.env.PagleTackleBoardDB.global.celebrated
			)
		end)

		it("lists the titles, Kindling burned and both goal types, singular forms included", function()
			-- a Notice done on each of days 0–5, then an Expedition today: day 6 lit, the 7th
			local fake = withHistory(join(
				started(D0, D0 + 60),
				doneEachDay(0, 4),
				{ record("issue", D0 + 5 * DAY + 60, ONE), catch(TODAY - 600) }, -- day 5 lit too
				{ record("issue", TODAY + 60, ONE_E), catch(TODAY + 120) }
			))
			local _, loaded = ready(fake)

			assert.are.same({
				{
					"Your Tackle Board was written up from 7 Casts",
					"6 Notices and 1 Expedition done",
					"Pagle Coins +145", -- 6 x 10 + 60 + the 7-day milestone's 25
					"7 flies tied for your Fly Box",
					"Title: campfire_7",
					"Campfire 7 days",
				},
			}, writeUps(fake))
			assert.is_true(loaded.env.PagleTackleBoardDB.global.celebrated.titles.campfire_7)
		end)

		it("raises nothing, and sets no summary line, without a start record (TKB-R2, TKB-R192)", function()
			local fake = withHistory({ catch(TODAY + 10), catch(TODAY + 20) })
			local _, loaded = ready(fake)

			assert.are.same({}, fake.writeUps)
			assert.are.same({}, fake.announcements)
			assert.are.same({}, fake.summarized)
			assert.is_nil(fake.global.summary.lines.TackleBoard)
			assert.are.same({ goals = {}, titles = {} }, loaded.env.PagleTackleBoardDB.global.celebrated)
		end)
	end)

	-- A second login over `first`'s Catch log and saved PagleTackleBoardDB (`loaded`'s), with `records` appended
	-- meanwhile and `seconds` gone by: the board's projection catches up, or rebuilds if `prepare(saved)` makes it.
	local function secondLogin(first, loaded, records, seconds, prepare)
		local fake = newFakePagle()
		fake.catchLog.data = first.catchLog.data
		for _, entry in ipairs(records) do
			fake.catchLog:Append(entry)
		end
		local saved = loaded.env.PagleTackleBoardDB
		if prepare then
			prepare(saved)
		end
		fake.wait(seconds)
		return fake, ready(fake, {
			prepare = function(second)
				second.env.PagleTackleBoardDB = saved
			end,
		})
	end

	describe("a catch-up (TKB-R84, TKB-R190)", function()
		it(
			"writes up what the replayed Casts earned in one While Tackle Board was off section, raising no moment",
			function()
				local goal = idAt(TODAY + 120)
				local first = withHistory(join(started(TODAY, TODAY + 60), { record("issue", TODAY + 120, ONE) }))
				local _, loaded = ready(first)

				-- off: the Notice done today, then a Cast that got away two days later (day 1 burns a Kindling)
				local fake, ns = secondLogin(first, loaded, { catch(NOW + 100), cast(NOW + 2 * DAY) }, 2 * DAY + 200)

				assert.are.same({
					{
						"While Tackle Board was off",
						"1 Notice done",
						"Pagle Coins +10",
						"1 fly tied for your Fly Box",
						"Campfire 1 day, 1 Kindling burned",
					},
				}, writeUps(fake))
				assert.are.same({}, fake.announcements)
				assert.are.same({}, fake.summarized)
				assert.is_true(ns.db.global.celebrated.goals[goal])
			end
		)

		it("writes up nothing when the replayed entries earned nothing", function()
			local first = withHistory(join(started(TODAY, TODAY + 60), { record("issue", TODAY + 120, ONE) }))
			local _, loaded = ready(first)

			local fake = secondLogin(first, loaded, { cast(NOW + 100) }, 200)

			assert.are.same({}, fake.writeUps)
		end)
	end)

	describe("a rebuild that isn't a first build (TKB-R84, TKB-R191, ANN-R63)", function()
		it("raises each goal done and not celebrated summary-only on its Cast, and never a celebrated one", function()
			local celebratedGoal, newGoal = idAt(TODAY + 120), idAt(NOW + 100)
			local first =
				withHistory(join(started(TODAY, TODAY + 60), { record("issue", TODAY + 120, ONE), catch(TODAY + 130) }))
			local _, loaded = ready(first)

			local fake, ns = secondLogin(
				first,
				loaded,
				{ record("issue", NOW + 100, ONE), catch(NOW + 110) },
				200,
				function(saved)
					saved.global.board.rulesVersion = 0 -- LOG-R72: rebuilt from seq 0
				end
			)

			assert.are.same({}, fake.writeUps)
			assert.are.same({}, fake.announcements)
			assert.are.equal(1, #fake.summarized)
			local fly = ns.State().goals[newGoal].fly
			assert.are.same({
				kind = "noticeDone",
				rung = "toast.low",
				title = "Notice complete",
				text = "1 Catch in Durotar. Tied for your Fly Box: " .. fly,
				icon = flyIcon(ns, fly),
				stamp = "Notice done",
				cast = idAt(NOW + 110),
				coins = 10,
				summaryOnly = true,
			}, shown(fake.summarized[1]))
			assert.are.same(
				{ goals = { [celebratedGoal] = true, [newGoal] = true }, titles = {} },
				ns.db.global.celebrated
			)
		end)
	end)

	describe("the summary line (TKB-R87, TKB-R2)", function()
		-- The board's line on the Session summary.
		local function line(fake)
			local lines = fake.global.summary.lines.TackleBoard
			return lines and lines.lines.board
		end

		it("reads Campfire not lit after the login step, then the goal done today and the 1-day Campfire", function()
			local fake = withHistory(join(started(TODAY, TODAY + 60), { record("issue", TODAY + 120, ONE) }))
			ready(fake)
			local afterStep = line(fake)

			live(fake, catch(NOW + 10))

			assert.are.equal("Tackle Board: Campfire not lit", afterStep)
			assert.are.equal("Tackle Board: 1 done today, Campfire 1 day", line(fake))
		end)

		it("leaves out the goals done when none was done today, after each step", function()
			local fake = withHistory(join(started(D0, D0 + 60), doneEachDay(0, 5)))
			local loaded = board.load(fake)
			fake.login()
			fake.enterWorld()
			loaded.client.runTimers()

			assert.are.equal("Tackle Board: Campfire 6 days", line(fake))
		end)

		it("is set by Start's step, and never before it", function()
			local loaded, fake = board.load()
			fake.login()
			fake.enterWorld()
			board.readSkill(fake)
			loaded.client.runTimers()
			local before = line(fake)

			loaded.ns.Start()

			assert.is_nil(before)
			assert.are.equal("Tackle Board: Campfire not lit", line(fake))
		end)
	end)
end)
