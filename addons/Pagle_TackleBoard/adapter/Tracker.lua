if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's tracker on the client (TKB-R120–R124; tackle-board.md › UI, the tracker): the tracker block
-- (adapter/TrackerBlock.lua) docked in Core's dock at order 30, drawn from logic/Tracker.lua's lines in the equipped
-- tracker frame (adapter/Goods.lua's looks). Core only stacks and moves it (CORE-R71, CORE-R72): the Tackle Board shows
-- it once the board is started and the projection's first update this login is done, and the block sizes itself to
-- its lines with SetHeight, so the dock reflows. It makes no secure frames, so it keeps working in combat (TKB-R193).

-- The owner of the tracker's Core callbacks (CORE-R23).
local OWNER = "Pagle_TackleBoard tracker"

--- The live tracker: its block and what it remembers between draws.
---@class TackleTracker
---@field block TackleTrackerBlock
---@field built boolean          -- the projection has finished its first update this login (TKB-R120)
---@field flashing string[]      -- goals completed live still flashing "Complete", oldest first (TKB-R123)

---@class PagleTackleBoardNS
---@field tracker TackleTracker?  -- made by ns.StartTracker

-- What the tracker is drawn from now (logic/Tracker.lua). A rebuild empties the projection's state while it runs
-- (LOG-R72), so whether the board is started is ns.KnownStarted.
---@param tracker TackleTracker
---@return TackleTrackerInput
local function input(tracker)
	local updating = ns.IsUpdating()
	if not updating then
		tracker.built = true
	end
	return {
		on = ns.db.profile.tracker,
		built = tracker.built,
		started = ns.KnownStarted(),
		updating = updating,
		collapsed = ns.db.profile.trackerCollapsed,
		state = ns.State(),
		zone = ns.CurrentZone(),
		flashing = tracker.flashing,
	}
end

-- Lets a Shift-drag that starts on `row` move the dock: a mouse-enabled row takes the drag, so it hands it to the
-- docked block, whose drag scripts Core hooked (CORE-R71).
---@param row TackleTrackerRow
---@param block Frame
local function passDrags(row, block)
	row:RegisterForDrag("LeftButton")
	for _, script in ipairs({ "OnDragStart", "OnDragStop" }) do
		row:SetScript(script, function()
			local fn = block:GetScript(script)
			if fn then
				fn(block, "LeftButton")
			end
		end)
	end
end

-- Gives `row` its mouse: the header collapses or expands the block (saved, TKB-R122), a goal opens the board on it
-- (TKB-R123, TKB-R109), "+N more" opens the board, and every line hands drags to the block (CORE-R71). Each reads the
-- row's line when it runs, so a pooled row does what its line now says.
---@param row TackleTrackerRow
---@param block Frame
local function wire(row, block)
	row:EnableMouse(true)
	passDrags(row, block)
	row:SetScript("OnClick", function(self)
		local line = self.line
		if line.kind == "header" then
			ns.db.profile.trackerCollapsed = not ns.db.profile.trackerCollapsed
			ns.DrawTracker()
		elseif line.kind == "goal" then
			ns.OpenBoard(line.goalID)
		elseif line.board then
			ns.OpenBoard()
		end
	end)
end

--- Draws the tracker now (TKB-R120–R124): shown once the board is started, the projection's first update this login
--- is done and the setting is on, its lines in the equipped frame, sized to them so the dock reflows; hidden
--- otherwise. Nothing before ns.StartTracker.
function ns.DrawTracker()
	local tracker = ns.tracker
	if not tracker then
		return
	end
	local block = tracker.block
	local view = ns.TrackerView(input(tracker))
	if not view.shown then
		block:Hide()
		return
	end
	block:SetLines(view.lines)
	for _, row in ipairs(block.rows) do
		if not row:GetScript("OnClick") then
			wire(row, block)
		end
	end
	block:SetFrame(ns.TRACKER_FRAMES[Pagle.GetEquipped(ns.TRACKER_FRAME_SLOT)])
	block:Show()
end

-- Flashes a goal completed live for ns.TRACKER_FLASH seconds, then drops its line (TKB-R123).
---@param tracker TackleTracker
---@param goalID string
local function flash(tracker, goalID)
	local flashing = tracker.flashing
	flashing[#flashing + 1] = goalID
	C_Timer.After(ns.TRACKER_FLASH, function()
		for i, id in ipairs(flashing) do
			if id == goalID then
				table.remove(flashing, i)
				break
			end
		end
		ns.DrawTracker()
	end)
end

--- Makes the tracker and docks it (TKB-R120), from OnInitialize after the projection is made: Core's dock stacks it at
--- order 30, below Hunts' and Stats' (CORE-R70). It redraws at every ns.Redraw (the projection, names, completed goals,
--- which it flashes, live steps, whose advance at each reset moves a day-bound goal's count, TKB-R104, and its
--- setting), on ConditionsChanged with "area" (TKB-R121), at ModulesChanged (the equipped frame is Core's by then,
--- SHOP-R33) and at
--- AppearanceChanged for its frame slot (TKB-R124).
---@param module PagleModuleHandle
function ns.StartTracker(module)
	local block = ns.NewTrackerBlock(UIParent)
	block:Hide()
	local tracker = { block = block, built = false, flashing = {} }
	ns.tracker = tracker
	module:RegisterTracker({ id = "tackleboard", order = 30, frame = block })

	local function draw()
		ns.DrawTracker()
	end
	ns.OnRedraw(function(reason, detail)
		if reason == "completed" then
			flash(tracker, detail)
		end
		draw()
	end)
	Pagle.RegisterCallback(OWNER, "ModulesChanged", draw)
	Pagle.RegisterCallback(OWNER, "ConditionsChanged", function(_, changedKeys)
		for _, key in ipairs(changedKeys) do
			if key == "area" then
				draw()
				return
			end
		end
	end)
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.TRACKER_FRAME_SLOT then
			draw()
		end
	end)
end
