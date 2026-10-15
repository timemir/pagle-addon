if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The tracker's lines (TKB-R2, TKB-R104, TKB-R120–R124; tackle-board.md › UI, the tracker): whether it shows, its
-- header, the goals workable here in board order, the "+N more" or "All done" line, the collapsed and updating states
-- and the "Complete" flash, as data for the tracker block (adapter/TrackerBlock.lua). Pure logic over the projection's
-- state and the board's words (logic/Words.lua), Core through ns.api.pagle, and progress (logic/Progress.lua);
-- adapter/Tracker.lua docks the block, reads what comes in and draws what this returns.

--- How long a goal completed live flashes "Complete" on the tracker before its line leaves, in seconds (TKB-R123;
--- tackle-board.md › Tunables).
ns.TRACKER_FLASH = 3

--- What the tracker is drawn from, read at each draw.
---@class TackleTrackerInput
---@field on boolean                -- "Show goals workable here", PagleTackleBoardDB.profile.tracker (TKB-R120)
---@field built boolean             -- the projection has finished its first update this login (TKB-R120)
---@field started boolean           -- the board is started (TKB-R2, TKB-R6), as last read while not updating
---@field updating boolean          -- ns.IsUpdating() (TKB-R124)
---@field collapsed boolean         -- PagleTackleBoardDB.profile.trackerCollapsed (TKB-R122)
---@field state TackleBoardState    -- ns.State()
---@field zone integer              -- the current zone, ns.CurrentZone() (TKB-R121)
---@field flashing string[]         -- the IDs of goals completed live still flashing "Complete", oldest first (TKB-R123)

--- The tracker as drawn now.
---@class TackleTrackerView
---@field shown boolean             -- TKB-R120
---@field lines TackleTrackerLine[] -- top to bottom (TKB-R122)

-- A goal's text on the tracker (TKB-R122): "Expedition: " first for an Expedition.
---@param goal TackleGoal
---@return string
local function goalText(goal)
	local text = ns.GoalText(goal)
	if goal.type == "e" then
		return ns.Fill(ns.L.TRACKER_EXPEDITION, { text = text })
	end
	return text
end

-- A workable goal's line (TKB-R122): its text, its displayed progress over its need (TKB-R104), then where, with
-- " · here" for a goal tied to a place (it is workable here).
---@param goal TackleGoal
---@param input TackleTrackerInput
---@return TackleTrackerLine
local function goalLine(goal, input)
	return {
		kind = "goal",
		text = goalText(goal),
		count = ns.TrackerCount(ns.DisplayedProgress(goal, input.state.day), ns.GoalNeed(goal, ns.api.pagle)),
		where = ns.TrackerWhere(goal, true),
		expedition = goal.type == "e" or nil,
		goalID = goal.id,
	}
end

-- A goal completed live, flashing (TKB-R123): its text and "Complete" in green, with no where line.
---@param goal TackleGoal
---@return TackleTrackerLine
local function flashLine(goal)
	return {
		kind = "goal",
		text = goalText(goal),
		count = ns.L.TRACKER_COMPLETE,
		complete = true,
		expedition = goal.type == "e" or nil,
		goalID = goal.id,
	}
end

--- What the tracker shows (TKB-R120–R124): shown once the board is started, the projection's first update this login
--- is done and the setting is on (nothing before Start, TKB-R2). The header reads the title, the flame with the
--- Campfire's days while it burns and the open goals. Collapsed, nothing more. While updating, "Updating…" alone
--- under a header with no counts (TKB-R124). Otherwise the goals flashing "Complete" (TKB-R123), then each open goal
--- workable here (TKB-R121) in board order (TKB-R101), then "+N more on the board (elsewhere)" for the N open goals
--- that aren't, or "All done. Fresh Notices at reset." with none open.
---@param input TackleTrackerInput
---@return TackleTrackerView
function ns.TrackerView(input)
	local L, state = ns.L, input.state
	local view = { shown = input.on and input.built and input.started, lines = {} }
	if not view.shown then
		return view
	end
	local header = { kind = "header", text = L.TITLE, collapsed = input.collapsed }
	local lines = { header }
	view.lines = lines
	if input.updating then
		-- The state is mid-fold: no counts until it is done.
		if not input.collapsed then
			lines[2] = { kind = "line", text = L.UPDATING }
		end
		return view
	end
	local open = ns.BoardOrder(state)
	local fire = state.fire.count
	header.right = ns.TrackerHeaderRight(fire > 0 and fire or nil, #open)
	header.fire = fire > 0
	if input.collapsed then
		return view
	end
	for _, id in ipairs(input.flashing) do
		local goal = state.goals[id]
		if goal then
			lines[#lines + 1] = flashLine(goal)
		end
	end
	local elsewhere = 0
	for _, goal in ipairs(open) do
		if ns.IsWorkableHere(goal, input.zone) then
			lines[#lines + 1] = goalLine(goal, input)
		else
			elsewhere = elsewhere + 1
		end
	end
	if #open == 0 then
		lines[#lines + 1] = { kind = "line", text = L.TRACKER_ALL_DONE }
	elseif elsewhere > 0 then
		lines[#lines + 1] = { kind = "line", text = ns.Fill(L.TRACKER_MORE, { n = elsewhere }), board = true }
	end
	return view
end
