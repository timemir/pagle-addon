if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts tracker on the client (HNT-R75–R79, HNT-R175–R177, CORE-R73, SET-R41): a native objective-tracker-style
-- block in Core's tracker dock, its collapsible "Hunts" header over the pinned Hunts' lines, and above it while any
-- run is on the collapsible "Pagle Wagers" block over the runs' lines (logic/Tracker.lua), both in the equipped
-- tracker frame (adapter/Goods.lua's looks). Core only stacks it (CORE-R72): Hunts shows it while its setting is on,
-- and sizes it to both blocks' lines with SetHeight, so the dock reflows. It makes no secure frames (HNT-R193).

-- The owner of the tracker's bus registrations.
local OWNER = "Pagle_Hunts tracker"

---@class PagleHuntsNS
---@field tracker HuntsTrackerView?   -- made by ns.StartTracker

-- The tracker's saved state, profile.tracker (hunts.md › Data): the Hunts block's and the Pagle Wagers block's
-- collapsed states apart (HNT-R77, HNT-R177).
---@return { shown: boolean, collapsed: boolean, wagersCollapsed: boolean }
local function saved()
	return ns.db.profile.tracker
end

-- The Pagle Wagers block's content (HNT-R175, HNT-R177) from the runs the board shows, read as the board reads them
-- (ns.BoardWagersInput: at ns.ViewNow(), so its countdowns freeze with the board's while restricted, HNT-R43), with
-- each run's key on its lines; with no run on, the companion hint's line while it applies (HNT-R176), else nil.
---@param view HuntsTrackerView
---@return HuntsTrackerWagersContent?
local function wagersContent(view)
	local input = ns.BoardWagersInput() --[[@as HuntsTrackerWagersInput]] -- the fields of it the block reads
	local lines = ns.TrackerWagerLines(input, ns.State())
	if not lines then
		return nil
	end
	local collapsed = saved().wagersCollapsed
	local runs = {}
	for i, run in ipairs(collapsed and {} or lines.runs) do
		runs[i] = { name = run.name, label = run.label, second = run.second, dial = run.dial, urgent = run.urgent }
		view.wagers.lines[i].runKey = run.key
	end
	return {
		runs = runs,
		more = not collapsed and lines.more > 0 and ns.TrackerWagersMore(lines.more) or nil,
		hint = not collapsed and lines.hint or nil,
		collapsed = collapsed,
	}
end

-- Tells the grouping whether lines on the tracker that count down show, for the refresh of their countdowns
-- (HNT-R42), when that changes: from the first draw, then as a block collapses or expands, the Pagle Wagers block comes
-- or goes, or the setting hides it.
---@param view HuntsTrackerView
---@param shown boolean
local function counting(view, shown)
	if view.counting ~= shown then
		view.counting = shown
		ns.SetViewShown("tracker", shown)
	end
end

-- Draws both blocks from the grouping, the runs, the projection and the equipped frame's look (adapter/Goods.lua's
-- ns.DrawTrackerBlock sizes the block to what shows), and tells the grouping whether lines that count down show: the
-- Hunts block expanded, or the Pagle Wagers block shown and expanded with runs on (its hint line counts nothing down).
---@param view HuntsTrackerView
local function draw(view)
	local look = ns.TrackerLook(view.wearing or Pagle.GetEquipped(ns.TRACKER_FRAME_SLOT))
	local collapsed = saved().collapsed
	local conditions = Pagle.GetConditions()
	local lines = ns.TrackerLines({
		rows = ns.groups:Grouping() and ns.groups:Rows({ pinnedOnly = true }) or nil,
		anyPinned = next(ns.db.profile.pins) ~= nil,
		time = ns.ViewNow(),
		snapshot = conditions,
		zone = conditions.zone,
		updating = ns.IsUpdating(),
		state = ns.State(),
		list = ns.hunts,
		where = ns.where,
		sources = ns.names,
	})
	local hunts = {}
	for i, hunt in ipairs(collapsed and {} or lines.hunts) do
		hunts[i] = { dot = hunt.dot, name = hunt.name, label = hunt.label, second = hunt.second }
		view.lines[i].huntID = hunt.id
	end
	local wagers = wagersContent(view)
	ns.DrawTrackerBlock(view, look, {
		hunts = hunts,
		more = not collapsed and lines.more > 0 and ns.L.TRACKER_MORE:format(lines.more) or nil,
		empty = not collapsed and lines.empty,
		collapsed = collapsed,
		wagers = wagers,
	})
	counting(view, not collapsed or (wagers ~= nil and #wagers.runs > 0))
end

-- Shows the block while its setting is on, drawn; hidden, nothing on it counts down (HNT-R42).
---@param view HuntsTrackerView
local function show(view)
	local tracker = saved()
	view.frame:SetShown(tracker.shown)
	if tracker.shown then
		draw(view)
	else
		counting(view, false)
	end
end

--- Makes the Hunts tracker and docks it (HNT-R75), from OnInitialize after RegisterModule: Core's dock stacks it at
--- order 10 (CORE-R70). Adds "Show the Hunts tracker" to the Trackers page (SET-R41; Core adds the frame's dropdown
--- after it, SET-R44), which shows or hides both blocks (HNT-R177), and redraws at every ns.Redraw while shown (so a
--- run that ends leaves the Pagle Wagers block at the regroup its end sets, HNT-R42, HNT-R143), at ModulesChanged
--- (the equipped frame is Core's by then, SHOP-R33) and at each AppearanceChanged for the tracker frame slot (HNT-R79).
---@param module PagleModuleHandle
function ns.StartTracker(module)
	local L = ns.L
	local view = ns.NewTrackerBlock(UIParent)
	ns.tracker = view
	for _, line in ipairs(view.lines) do
		line:SetScript("OnClick", function(self)
			ns.OpenBoard(self.huntID)
		end)
	end
	view.more:SetScript("OnClick", function()
		ns.OpenBoard()
	end)
	view.header:SetScript("OnClick", function()
		saved().collapsed = not saved().collapsed
		show(view)
	end)
	-- The Pagle Wagers block: a run's lines open the board with that run selected (HNT-R164), "+{n} more" the Pagle
	-- Wagers spread (HNT-R162), and its header collapses or expands it alone (HNT-R177).
	for _, line in ipairs(view.wagers.lines) do
		line:SetScript("OnClick", function(self)
			ns.OpenBoard({ run = self.runKey })
		end)
	end
	view.wagers.more:SetScript("OnClick", function()
		ns.OpenWagers()
	end)
	-- The companion hint's "why?" opens the Pagle Wagers spread too (HNT-R176).
	view.wagers.hint.why:SetScript("OnClick", function()
		ns.OpenWagers()
	end)
	view.wagers.header:SetScript("OnClick", function()
		saved().wagersCollapsed = not saved().wagersCollapsed
		show(view)
	end)
	-- Shown or not from the start, so the dock stacks it as it is; its first draw waits for ModulesChanged.
	view.frame:SetShown(saved().shown)
	counting(view, saved().shown and not saved().collapsed)
	module:RegisterTracker({ id = "hunts", order = 10, frame = view.frame })
	module:AddSetting("trackers", {
		kind = "checkbox",
		label = L.SETTING_SHOW_TRACKER,
		tooltip = L.SETTING_SHOW_TRACKER_TOOLTIP,
		default = true,
		get = function()
			return saved().shown
		end,
		set = function(value)
			saved().shown = value and true or false
			show(view)
		end,
	})
	ns.OnRedraw(function()
		if view.frame:IsShown() then
			draw(view)
		end
	end)
	Pagle.RegisterCallback(OWNER, "ModulesChanged", function()
		show(view)
	end)
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.TRACKER_FRAME_SLOT and view.frame:IsShown() then
			draw(view)
		end
	end)
end
