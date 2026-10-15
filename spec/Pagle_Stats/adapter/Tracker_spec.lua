-- The live tracker on FakePagle (STA-R80–R86, STA-R90; CORE-R17, CORE-R70–R73): the block Stats docks in Core's
-- dock below a fixture tracker at order 10, when it shows, its lines from Casts played through Core's real Cast state
-- machine over the fixture catalogue, its hover and clicks, its frame, its updating state and its redraws. The lines'
-- every form is in spec/Pagle_Stats/logic/Tracker_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local newWidget = dofile("spec/support/widgets.lua").newWidget

local I = stats.IDS
local DARKSHORE, AUBERDINE = I.DARKSHORE, I.AUBERDINE
local MACKEREL, BLACKMOUTH, NIGHTFIN = I.MACKEREL, I.BLACKMOUTH, I.NIGHTFIN
local fish = stats.fish
local SLOT, LOGBOOK = "stats.trackerframe", "stats.trackerframe.logbook"

-- Docks a fixture tracker as Hunts would: a plain frame, 220 × 40, at order 10 (CORE-R70).
---@param fake table
---@return table frame
local function dockHunts(fake)
	local hunts = fake.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
	local frame = newWidget("Frame")
	frame:SetSize(220, 40)
	hunts:RegisterTracker({ id = "hunts", order = 10, frame = frame })
	return frame
end

-- Pagle_Stats on a fake with the fixture tracker docked, logged in and its projection built (unless `options.updating`),
-- fishing Auberdine with Fishing 86 + 25 = 111 (below Darkshore's line, 170), the areas, Mackerel and Blackmouth
-- named. `options.fake` is a fake set up first.
---@param options { updating: boolean?, fake: table? }?
local function ready(options)
	options = options or {}
	local fake = options.fake or newFakePagle()
	dockHunts(fake)
	local loaded = stats.start({
		fake = fake,
		items = { MACKEREL, BLACKMOUTH },
		updating = options.updating,
		at = { zone = DARKSHORE, subzone = AUBERDINE },
	})
	return loaded, fake, loaded.ns
end

-- The ids of the trackers the dock shows, top to bottom (CORE-R70, CORE-R72).
local function docked(fake)
	local ids = {}
	for i, tracker in ipairs(fake.dock.stack()) do
		ids[i] = tracker.id
	end
	return ids
end

-- A band by its dot's colour (ns.BAND_DOT_COLORS), "grey" for none.
local function bandOf(ns, dot)
	local color = dot.vertexColor
	for band, tint in pairs(ns.BAND_DOT_COLORS) do
		if tint[1] == color[1] and tint[2] == color[2] and tint[3] == color[3] then
			return band == "none" and "grey" or band
		end
	end
	error("a dot in no band's colour")
end

-- The tracker as the player reads it, each shown row: "<title> | <right>" for the header, the text of a plain line,
-- "<band> <name> | <count> | <sub>" for a watch.
local function read(ns)
	local out = {}
	for _, row in ipairs(ns.tracker.block.rows) do
		if row:IsShown() then
			if row.sub:IsShown() then
				out[#out + 1] = ("%s %s | %s | %s"):format(
					bandOf(ns, row.dot),
					row.text:GetText(),
					row.right:GetText(),
					row.sub:GetText()
				)
			elseif row.rule:IsShown() then
				out[#out + 1] = row.text:GetText() .. " | " .. row.right:GetText()
			else
				out[#out + 1] = row.text:GetText()
			end
		end
	end
	return out
end

-- The shown row whose text is `text`.
local function rowReading(ns, text)
	for _, row in ipairs(ns.tracker.block.rows) do
		if row:IsShown() and row.text:GetText() == text then
			return row
		end
	end
	error("no row " .. text)
end

describe("the live tracker", function()
	describe("in the dock (STA-R80, STA-R81, CORE-R70, CORE-R72)", function()
		it("docks once at order 20, and with the setting off shows nothing, even during a Session", function()
			local loaded, fake = ready()
			fish(fake, 2, MACKEREL)

			local stats_ = {}
			for _, tracker in ipairs(fake.ns.dock:Trackers()) do
				stats_[#stats_ + 1] = { tracker.id, tracker.order, tracker.module }
			end
			assert.are.same({ { "hunts", 10, "Hunts" }, { "stats", 20, "Stats" } }, stats_)
			assert.are.same({ "hunts" }, docked(fake))
			assert.is_false(loaded.ns.tracker.block:IsShown())
		end)

		it("stays hidden while on with no Session and no watch (STA-R81, STA-R97)", function()
			local loaded, fake = ready()

			fake.settingsPage("trackers")[2].setting.set(true)

			assert.is_true(loaded.ns.db.profile.tracker)
			assert.are.same({ "hunts" }, docked(fake))
		end)

		it("shows below the order-10 tracker once a Session starts, and goes when it ends", function()
			local loaded, fake = ready()
			loaded.ns.db.profile.tracker = true

			fish(fake, 1, MACKEREL)

			assert.are.same({ "hunts", "stats" }, docked(fake))
			local stack = fake.dock.stack()
			assert.are.equal(loaded.ns.tracker.block, stack[2].frame)
			assert.are.equal(-48, stack[2].y) -- the 40 px tracker above, then 8 px (CORE-R70)

			fake.wait(900) -- 15 minutes without a Cast end the Session (LOG-R62)

			assert.are.same({ "hunts" }, docked(fake))
		end)

		it("shows for a watch, which turns it on (STA-R62), and goes when the setting is turned off", function()
			local loaded, fake, ns = ready()

			ns.Watch(MACKEREL, AUBERDINE)

			assert.are.same({ "hunts", "stats" }, docked(fake))
			fake.settingsPage("trackers")[2].setting.set(false)
			assert.are.same({ "hunts" }, docked(fake))
			assert.is_false(loaded.ns.tracker.block:IsShown())
		end)

		it("isn't in the dock while Stats is disabled: it registers nothing (STA-R90, CORE-R17)", function()
			local fake = newFakePagle()
			dockHunts(fake)
			fake.profile.tracker = true

			fake.login()

			assert.are.same({ "hunts" }, docked(fake))
			assert.are.equal(1, #fake.ns.dock:Trackers())
		end)
	end)

	describe("its lines (STA-R82)", function()
		it("reads the header with the Session's length, its counts and its per hour with skill +0", function()
			local _, fake, ns = ready()
			ns.db.profile.tracker = true
			fish(fake, 2, MACKEREL)
			fish(fake, 1)
			fake.wait(300)
			fish(fake, 1, MACKEREL)

			-- 3 Catches over 300 s: 36 per hour (STA-R33)
			assert.are.same(
				{ "Stats | Session · 5m", "4 Casts · 3 Catches · 1 got away", "36 per hour · skill +0" },
				read(ns)
			)
		end)

		it('reads "no Session" with none open, then each watch with its dot, count and sub-line', function()
			local _, fake, ns = ready()
			fish(fake, 3, MACKEREL)
			fake.wait(900)

			ns.Watch(MACKEREL, AUBERDINE)
			ns.Watch(BLACKMOUTH, DARKSHORE)

			-- Fishing 111 is below Darkshore's line (170): the lo side, under 100 Casts, so learning (STA-R43)
			assert.are.same({
				"Stats | no Session",
				"grey Raw Mackerel | just now | Auberdine · learning 3/100",
				"grey Oily Blackmouth | 3 | Darkshore · learning 3/100",
			}, read(ns))
		end)

		it("resizes the block to its lines, so the dock reflows (STA-R86)", function()
			local _, fake, ns = ready()
			ns.Watch(MACKEREL, AUBERDINE)
			local alone = ns.tracker.block:GetHeight()

			ns.Watch(BLACKMOUTH, DARKSHORE)

			assert.is_true(ns.tracker.block:GetHeight() > alone)
			assert.are.equal(ns.tracker.block:GetHeight(), fake.dock.stack()[2].frame:GetHeight())
		end)

		it("names an item the client hasn't loaded by its ID, asks for it and redraws when it loads", function()
			local loaded, _, ns = ready()

			ns.Watch(NIGHTFIN, DARKSHORE)
			assert.are.equal("grey Item 13759 | 0 | Darkshore · by night · learning 0/100", read(ns)[2])
			assert.are.same({ NIGHTFIN }, loaded.client.itemRequests)

			stats.loadItem(loaded, NIGHTFIN)
			loaded.client.runTimers()

			assert.are.equal("grey Raw Nightfin Snapper | 0 | Darkshore · by night · learning 0/100", read(ns)[2])
		end)
	end)

	describe("its hover and clicks (STA-R83, CORE-R71)", function()
		it("shows a watch's Dry spell and Your odds text on hover, and hides it after", function()
			local loaded, fake, ns = ready()
			fish(fake, 2, MACKEREL)
			fish(fake, 1)
			ns.Watch(MACKEREL, AUBERDINE)
			local row = rowReading(ns, "Raw Mackerel")

			row:GetScript("OnEnter")(row)

			local tooltip = loaded.client.gameTooltip
			assert.is_true(tooltip.shown)
			assert.are.equal(row, tooltip.owner)
			assert.are.same({
				"Raw Mackerel",
				"1 Cast since my last Raw Mackerel.",
				"A luck reading comes once Your odds have a number.",
				"3 of the 100 Casts I need across Darkshore, below 170 skill before Your odds show a number.",
			}, tooltip.lines)
			row:GetScript("OnLeave")(row)
			assert.is_false(tooltip.shown)
		end)

		it("opens a watch's entry on the watched place's page, opening the book if closed", function()
			local _, _, ns = ready()
			ns.Watch(BLACKMOUTH, AUBERDINE)

			rowReading(ns, "Oily Blackmouth"):Click()

			assert.is_true(ns.book:IsShown())
			assert.are.same({ page = "place", area = AUBERDINE, item = BLACKMOUTH }, ns.book.router:Place())
		end)

		it("toggles the book from the header", function()
			local _, _, ns = ready()
			ns.Watch(BLACKMOUTH, AUBERDINE)
			local header = rowReading(ns, "Stats")

			header:Click()
			assert.is_true(ns.book:IsShown())
			header:Click()
			assert.is_false(ns.book:IsShown())
		end)

		it("hands a drag on any line to the docked block, so Core's Shift-drag moves the dock (CORE-R71)", function()
			local _, fake, ns = ready()
			ns.db.profile.tracker = true
			fish(fake, 1, MACKEREL)
			ns.Watch(BLACKMOUTH, AUBERDINE)
			local block = ns.tracker.block
			local started, stopped = {}, {}
			block:SetScript("OnDragStart", function(frame, button)
				started[#started + 1] = { frame, button }
			end)
			block:SetScript("OnDragStop", function(frame)
				stopped[#stopped + 1] = frame
			end)

			for _, text in ipairs({ "Stats", "1 Cast · 1 Catch · 0 got away", "Oily Blackmouth" }) do
				local row = rowReading(ns, text)
				row:GetScript("OnDragStart")(row, "LeftButton")
				row:GetScript("OnDragStop")(row)
			end

			assert.are.same({ { block, "LeftButton" }, { block, "LeftButton" }, { block, "LeftButton" } }, started)
			assert.are.same({ block, block, block }, stopped)
		end)
	end)

	describe("its frame (STA-R84, CORE-R73)", function()
		it("is the plain native block with no frame, and redraws in Logbook when it is equipped", function()
			local _, fake, ns = ready()
			ns.Watch(MACKEREL, AUBERDINE)
			local view = ns.tracker.block.frame
			assert.is_false(view.backing:IsShown())

			fake.setPurchased({ [LOGBOOK] = true })
			assert.is_true(fake.Pagle.SetEquipped(SLOT, LOGBOOK))

			local logbook = ns.TRACKER_FRAMES[LOGBOOK]
			assert.is_true(view.backing:IsShown())
			assert.are.equal(logbook.backing, view.backing.texture)
			local ink = rowReading(ns, "Stats").text.textColor
			assert.are.same(logbook.ink.header, { ink[1], ink[2], ink[3] })
		end)

		it("wears the frame equipped at an earlier login from this login on (SHOP-R32)", function()
			local fake = newFakePagle()
			fake.setPurchased({ [LOGBOOK] = true })
			fake.profile.appearance[SLOT] = LOGBOOK

			-- Before PLAYER_ENTERING_WORLD: the fake's wallet projection would rebuild the purchased set from no Coins.
			local _, _, ns = ready({ fake = fake, updating = true })
			ns.Watch(MACKEREL, AUBERDINE)

			assert.are.equal(ns.TRACKER_FRAMES[LOGBOOK].backing, ns.tracker.block.frame.backing.texture)
			assert.is_true(ns.tracker.block.frame.backing:IsShown())
		end)
	end)

	describe("while the projection is updating (STA-R85)", function()
		it("reads the Session lines from Pagle.GetSession() alone and each watch as updating", function()
			local loaded, fake, ns = ready({ updating = true })
			local live = { id = "S-live", startTime = SERVER_TIME - 125, endTime = SERVER_TIME - 5 }
			live.casts, live.catches, live.gotAway = 4, 3, 1
			fake.Pagle.GetSession = function()
				return live
			end
			ns.db.profile.tracker = true
			ns.db.profile.watched = { { item = BLACKMOUTH, area = AUBERDINE } }

			ns.Redraw("projection")

			assert.is_true(ns.IsUpdating())
			assert.are.same({
				"Stats | Session · 2m",
				"4 Casts · 3 Catches · 1 got away",
				"grey Oily Blackmouth | updating | Auberdine",
			}, read(ns))

			fake.enterWorld()
			loaded.client.runTimers()
			assert.is_false(ns.IsUpdating())
			assert.are.equal("grey Oily Blackmouth | 0 | Auberdine · learning 0/100", read(ns)[3])
		end)
	end)

	describe("its redraws (STA-R86)", function()
		it("refreshes the Session's length on the 30 s tick while a Session is current", function()
			local loaded, fake, ns = ready()
			ns.db.profile.tracker = true
			fish(fake, 1, MACKEREL)
			assert.are.equal("Stats | Session · under 1m", read(ns)[1])

			fake.wait(120)
			loaded.client.advance(30)

			assert.are.equal("Stats | Session · 2m", read(ns)[1])
		end)

		it("redraws a watch when the skill moves it to the other side of the line", function()
			local _, fake, ns = ready()
			fish(fake, 2, MACKEREL)
			ns.Watch(MACKEREL, DARKSHORE)
			assert.are.equal("grey Raw Mackerel | just now | Darkshore · learning 2/100", read(ns)[4])

			fake.readSkill(200, 225, 25) -- 225 is past the line: the hi side has no Casts yet

			assert.are.equal("grey Raw Mackerel | 0 | Darkshore · learning 0/100", read(ns)[4])
		end)
	end)
end)
