-- The Tackle Board's tracker on FakePagle (TKB-R2, TKB-R109, TKB-R120–R124, TKB-R193; CORE-R17, CORE-R70–R73;
-- SET-R70): the block it docks in Core's dock below fixture trackers at orders 10 and 20, when it shows, its lines over
-- a started board's log (its Module records appended with fake.catchLog:Append, as the live step appends them) and
-- Casts played through Core's real Cast state machine over the fixture catalogue, its clicks, the "Complete" flash,
-- its frame, its updating state and its redraws. Every form of its lines is in logic/Tracker_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")
local record, idAt = board.record, board.idAt
---@diagnostic disable-next-line: undefined-global -- as above
local newWidget = dofile("spec/support/widgets.lua").newWidget

local W = board.WEEK0 -- Tuesday 6 October 2026 15:00 UTC: this week's weekly reset
local D = board.DAILY_RESET -- Sunday 11 October 15:00 UTC: today's daily reset, 15 minutes before the fake's clock
local DUROTAR, DARKSHORE = 14, 148
local BLACKMOUTH = 6358 -- a Darkshore fish of the fixture
local SLOT, CORKBOARD = "tackleboard.trackerframe", "tackleboard.trackerframe.corkboard"

-- Goal payloads (tackle-board.md › Data). Today's three Notices and this week's Expedition, so the live step owes
-- nothing (TKB-R20).
local HAUL_HERE = "n;haul;2;15;30;148" -- 30 Catches in Darkshore, the fake's zone
local HAUL_DUROTAR = "n;haul;2;15;30;14"
local LURE = "n;lure;3;20;25;"
local ONE_HERE = "n;haul;1;10;1;148" -- done by one Catch in Darkshore
local EXPEDITION = "e;size;0;60;1;4"

-- The start record's time, today; its goals follow one second apart.
local T = D + 60

-- A board started today: the start record, then an `issue` record for each payload, one second apart.
local function startedLog(...)
	local records = { record("start", T, D .. ";" .. W) }
	for i, payload in ipairs({ ... }) do
		records[#records + 1] = record("issue", T + i, payload)
	end
	return records
end

-- The full board of today: an Expedition anywhere, a Haul Notice here, one in Durotar and a Lure Notice.
local FULL = { EXPEDITION, HAUL_HERE, HAUL_DUROTAR, LURE }

-- Docks a fixture tracker for a Module named `name`: a plain frame, 220 × 40, at `order` (CORE-R70).
local function dockFixture(fake, name, order)
	local module = fake.Pagle.RegisterModule({ name = name, title = name, order = order })
	local frame = newWidget("Frame")
	frame:SetSize(220, 40)
	module:RegisterTracker({ id = name:lower(), order = order, frame = frame })
	return frame
end

-- Pagle_TackleBoard on a fake whose log holds `records` (none: an unstarted board), with fixture trackers at 10 and
-- 20 docked, its client knowing the fixture's names, logged in and (unless `options.updating`) its projection built.
-- `options.saved` is an earlier session's PagleTackleBoardDB.
---@param records table[]?
---@param options { updating: boolean?, saved: table?, fake: table? }?
local function ready(records, options)
	options = options or {}
	local fake = options.fake or newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, entry in ipairs(records or {}) do
		fake.catchLog:Append(entry)
	end
	dockFixture(fake, "Hunts", 10)
	dockFixture(fake, "Stats", 20)
	fake.globals.PagleTackleBoardDB = options.saved
	local loaded = board.load(fake)
	loaded.client.areaNames[DUROTAR] = "Durotar"
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	fake.login()
	board.readSkill(fake)
	if not options.updating then
		fake.enterWorld()
	end
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

-- The tracker as the player reads it, each shown row: "<title> | <right>" for the header ("(flame) " before the right
-- text while the flame shows), "<text> | <count> | <where>" for a goal, "<text> | <count>" for one flashing, a plain
-- line's text.
local function read(ns)
	local out = {}
	for _, row in ipairs(ns.tracker.block.rows) do
		if row:IsShown() then
			local line = row.line
			if line.kind == "header" then
				local right = row.right:IsShown() and row.right:GetText() or ""
				out[#out + 1] = row.text:GetText() .. " | " .. (row.flame:IsShown() and "(flame) " or "") .. right
			elseif row.sub:IsShown() then
				out[#out + 1] = ("%s | %s | %s"):format(row.text:GetText(), row.right:GetText(), row.sub:GetText())
			elseif line.kind == "goal" then
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

-- A copy of the fake's conditions in another zone, for fake.setConditions (it fires ConditionsChanged "area").
local function moveTo(fake, zone)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	conditions.zone, conditions.subzone = zone, 0
	fake.setConditions(conditions)
end

-- The lines of a full board read in Darkshore with no fire lit.
local FULL_HERE = {
	"Tackle Board | 4 open",
	"Expedition: A Whopper-or-better Catch | 0/1 | anywhere",
	"30 Catches in Darkshore | 0/30 | Darkshore · here",
	"25 Catches with a lure on | 0/25 | anywhere",
	"+1 more on the board (elsewhere)",
}

describe("the Tackle Board's tracker in the dock (TKB-R120, TKB-R2, CORE-R70, CORE-R72)", function()
	it("docks once at order 30, but shows nothing before Start; after Start it stacks third", function()
		local loaded, fake, ns = ready()

		local trackers = {}
		for _, tracker in ipairs(fake.ns.dock:Trackers()) do
			trackers[#trackers + 1] = { tracker.id, tracker.order, tracker.module }
		end
		assert.are.same(
			{ { "hunts", 10, "Hunts" }, { "stats", 20, "Stats" }, { "tackleboard", 30, "TackleBoard" } },
			trackers
		)
		assert.are.same({ "hunts", "stats" }, docked(fake)) -- TKB-R2: nothing before Start
		assert.is_false(ns.tracker.block:IsShown())

		ns.Start()

		assert.is_true(ns.IsStarted())
		assert.are.same({ "hunts", "stats", "tackleboard" }, docked(fake))
		local stack = fake.dock.stack()
		assert.are.equal(ns.tracker.block, stack[3].frame)
		assert.are.equal(-96, stack[3].y) -- two 40 px trackers above, 8 px apart (CORE-R70)
		assert.are.equal("Tackle Board", read(ns)[1]:match("^(.-) |"))
		assert.is_nil(loaded.ns.tracker.block.rows[1].line.goalID)
	end)

	it("waits for the projection's first update this login, then shows a started board", function()
		local loaded, fake, ns = ready(startedLog(unpack(FULL)), { updating = true })
		ns.Redraw("step")

		assert.is_true(ns.IsUpdating())
		assert.are.same({ "hunts", "stats" }, docked(fake))

		fake.enterWorld()
		loaded.client.runTimers()

		assert.are.same({ "hunts", "stats", "tackleboard" }, docked(fake))
		assert.are.same(FULL_HERE, read(ns))
	end)

	it("hides when its setting is turned off, so the dock reflows, and shows again when on (TKB-R120)", function()
		local _, fake, ns = ready(startedLog(unpack(FULL)))
		local checkbox
		for _, row in ipairs(assert(fake.settingsPage("trackers"), "no Trackers page")) do
			if row.label == "Show goals workable here" then
				checkbox = row.setting
			end
		end

		checkbox.set(false)

		assert.is_false(ns.tracker.block:IsShown())
		assert.are.same({ "hunts", "stats" }, docked(fake))

		checkbox.set(true)

		assert.are.same({ "hunts", "stats", "tackleboard" }, docked(fake))
	end)

	it("isn't in the dock while the Tackle Board is disabled: it registers nothing (CORE-R17)", function()
		local fake = newFakePagle()
		dockFixture(fake, "Hunts", 10)
		dockFixture(fake, "Stats", 20)

		fake.login()

		assert.are.same({ "hunts", "stats" }, docked(fake))
		assert.are.equal(2, #fake.ns.dock:Trackers())
	end)
end)

describe("its lines (TKB-R121, TKB-R122)", function()
	it('lists the goals workable here with their counts, then "+N more", and follows a zone change', function()
		local _, fake, ns = ready(startedLog(unpack(FULL)))

		assert.are.same(FULL_HERE, read(ns))

		moveTo(fake, DUROTAR)

		assert.are.same({
			"Tackle Board | 4 open",
			"Expedition: A Whopper-or-better Catch | 0/1 | anywhere",
			"30 Catches in Durotar | 0/30 | Durotar · here",
			"25 Catches with a lure on | 0/25 | anywhere",
			"+1 more on the board (elsewhere)",
		}, read(ns))
	end)

	it("counts a Catch here at once", function()
		local _, fake, ns = ready(startedLog(unpack(FULL)))

		fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })

		assert.are.equal("30 Catches in Darkshore | 1/30 | Darkshore · here", read(ns)[3])
	end)

	it('reads "All done. Fresh Notices at reset." with nothing open', function()
		local _, _, ns = ready(startedLog())

		assert.are.same({ "Tackle Board | 0 open", "All done. Fresh Notices at reset." }, read(ns))
	end)

	it("resizes the block to its lines, so the dock reflows (CORE-R70)", function()
		local _, fake, ns = ready(startedLog(unpack(FULL)))
		local here = ns.tracker.block:GetHeight()

		moveTo(fake, 0) -- only the always-workable goals (TKB-R121)

		assert.is_true(ns.tracker.block:GetHeight() < here)
		assert.are.equal(ns.tracker.block:GetHeight(), fake.dock.stack()[3].frame:GetHeight())
	end)
end)

describe("its header (TKB-R122, SET-R70)", function()
	it("shows the flame with the Campfire's days and the open goals", function()
		-- A Notice completed by a Cast in history lights today (TKB-R70): a Campfire of 1.
		local records = startedLog(EXPEDITION, ONE_HERE, HAUL_DUROTAR, LURE)
		local conditions = { minute = 600, zone = DARKSHORE, subzone = 0, skillRank = 150, skillMod = 0 }
		conditions.events, conditions.auras = {}, {}
		records[#records + 1] = {
			kind = "cast",
			char = 1,
			time = T + 30,
			outcome = "caught",
			conditions = conditions,
			items = { { itemID = BLACKMOUTH, quantity = 1 } },
		}
		local _, _, ns = ready(records)

		assert.are.equal("Tackle Board | (flame) 1 · 3 open", read(ns)[1])
	end)

	it("collapses and expands the block from its header, saved, and still collapsed after a reload", function()
		local loaded, fake, ns = ready(startedLog(unpack(FULL)))
		local expanded = ns.tracker.block:GetHeight()

		rowReading(ns, "Tackle Board"):Click()

		assert.are.same({ "Tackle Board | 4 open" }, read(ns))
		assert.is_true(ns.db.profile.trackerCollapsed)
		assert.is_true(ns.tracker.block:GetHeight() < expanded)
		assert.are.same({ "hunts", "stats", "tackleboard" }, docked(fake)) -- the header stays in the dock
		assert.is_true(ns.tracker.block.rows[1].line.collapsed)

		-- The next session, over what this one saved.
		local _, _, next = ready(startedLog(unpack(FULL)), { saved = loaded.env.PagleTackleBoardDB })
		assert.are.same({ "Tackle Board | 4 open" }, read(next))

		rowReading(next, "Tackle Board"):Click()

		assert.is_false(next.db.profile.trackerCollapsed)
		assert.are.same(FULL_HERE, read(next))
	end)
end)

describe("its clicks and the flash (TKB-R123, TKB-R109, CORE-R71)", function()
	it("opens the board on a goal clicked, with its pin highlighted", function()
		local _, _, ns = ready(startedLog(unpack(FULL)))

		rowReading(ns, "30 Catches in Darkshore"):Click()

		local frame = ns.board.frame
		assert.is_true(frame:IsShown())
		assert.is_true(frame.parts.pins.slots.notices[1].highlight:IsShown()) -- HAUL_HERE's pin, the first
		assert.is_false(frame.parts.pins.slots.notices[3].highlight:IsShown())
	end)

	it('opens the board from "+N more", with nothing highlighted', function()
		local _, _, ns = ready(startedLog(unpack(FULL)))

		rowReading(ns, "+1 more on the board (elsewhere)"):Click()

		local frame = ns.board.frame
		assert.is_true(frame:IsShown())
		for i = 1, 3 do
			assert.is_false(frame.parts.pins.slots.notices[i].highlight:IsShown())
		end
	end)

	it('flashes a goal completed live green "Complete" for 3 s, then drops its line', function()
		local loaded, fake, ns = ready(startedLog(EXPEDITION, ONE_HERE, HAUL_DUROTAR, LURE))
		assert.are.equal("1 Catch in Darkshore | 0/1 | Darkshore · here", read(ns)[3])

		fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })

		assert.are.same({
			"Tackle Board | (flame) 1 · 3 open",
			"1 Catch in Darkshore | Complete",
			"Expedition: A Whopper-or-better Catch | 0/1 | anywhere",
			"25 Catches with a lure on | 1/25 | anywhere", -- the fake fishes with a lure on
			"+1 more on the board (elsewhere)",
		}, read(ns))
		local flashing = rowReading(ns, "1 Catch in Darkshore")
		assert.are.same(ns.TRACKER_INKS.complete, { unpack(flashing.right.textColor, 1, 3) })
		assert.are.equal(idAt(T + 2), flashing.line.goalID)

		loaded.client.advance(2.9)
		assert.are.equal("1 Catch in Darkshore | Complete", read(ns)[2])
		loaded.client.advance(0.1)

		assert.are.equal("Expedition: A Whopper-or-better Catch | 0/1 | anywhere", read(ns)[2])
		for _, line in ipairs(read(ns)) do
			assert.is_nil(line:find("1 Catch in Darkshore", 1, true))
		end
	end)

	it("hands a drag on any line to the docked block, so Core's Shift-drag moves the dock (CORE-R71)", function()
		local _, _, ns = ready(startedLog(unpack(FULL)))
		local block = ns.tracker.block
		local started, stopped = {}, {}
		block:SetScript("OnDragStart", function(frame, button)
			started[#started + 1] = { frame, button }
		end)
		block:SetScript("OnDragStop", function(frame)
			stopped[#stopped + 1] = frame
		end)

		for _, text in ipairs({ "Tackle Board", "30 Catches in Darkshore", "+1 more on the board (elsewhere)" }) do
			local row = rowReading(ns, text)
			row:GetScript("OnDragStart")(row, "LeftButton")
			row:GetScript("OnDragStop")(row)
		end

		assert.are.same({ { block, "LeftButton" }, { block, "LeftButton" }, { block, "LeftButton" } }, started)
		assert.are.same({ block, block, block }, stopped)
	end)

	it("keeps drawing and taking clicks in combat: nothing in it is secure (TKB-R193)", function()
		local _, fake, ns = ready(startedLog(unpack(FULL)))
		fake.setRestricted(true) -- combat (CORE-R30)

		moveTo(fake, DUROTAR)
		rowReading(ns, "30 Catches in Durotar"):Click()

		assert.are.equal("30 Catches in Durotar | 0/30 | Durotar · here", read(ns)[3])
		assert.is_true(ns.board.frame:IsShown())
	end)
end)

describe("its frame and updating state (TKB-R124)", function()
	it("is the plain native block, and redraws in Corkboard when it is equipped", function()
		local _, fake, ns = ready(startedLog(unpack(FULL)))
		local view = ns.tracker.block.frame
		assert.is_false(view.backing:IsShown())

		fake.setPurchased({ [CORKBOARD] = true })
		assert.is_true(fake.Pagle.SetEquipped(SLOT, CORKBOARD))

		local cork = ns.TRACKER_FRAMES[CORKBOARD]
		assert.is_true(view.backing:IsShown())
		assert.are.same(cork.base, { unpack(view.backing.color, 1, 3) })
		local ink = rowReading(ns, "Tackle Board").text.textColor
		assert.are.same(cork.ink.header, { ink[1], ink[2], ink[3] })
	end)

	it('shows only its header and "Updating…" while the projection rebuilds, then its lines again', function()
		local loaded, fake, ns = ready(startedLog(unpack(FULL)))
		board.updating(fake, true) -- the rebuild runs in chunks on later frames

		ns.projection:Rebuild()
		ns.Redraw("step")

		assert.is_true(ns.IsUpdating())
		assert.are.same({ "Tackle Board | ", "Updating…" }, read(ns))
		assert.are.same({ "hunts", "stats", "tackleboard" }, docked(fake))

		board.updating(fake, false)
		for _ = 1, 10 do
			fake.nextFrame()
		end
		loaded.client.runTimers()

		assert.is_false(ns.IsUpdating())
		assert.are.same(FULL_HERE, read(ns))
	end)
end)
