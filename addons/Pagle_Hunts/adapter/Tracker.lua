if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts tracker on the client (HNT-R75–R79, CORE-R73, SET-R41): a native objective-tracker-style block in Core's
-- tracker dock, its collapsible "Hunts" header over the pinned Hunts' lines (logic/Tracker.lua), in the equipped
-- tracker frame (adapter/Goods.lua's looks). Core only stacks it (CORE-R72): Hunts shows it while its setting is on,
-- and sizes it to its lines with SetHeight, so the dock reflows. It makes no secure frames (HNT-R193).

-- The block (ns.NewTrackerBlock, adapter/Goods.lua, which the Curio Shop's sample shares) and its sizes.
local BLOCK = ns.TRACKER_BLOCK
local HEADER_HEIGHT, LINE_HEIGHT, DOT_SIZE, PAD = BLOCK.headerHeight, BLOCK.lineHeight, BLOCK.dotSize, BLOCK.pad
local HUNT_HEIGHT = BLOCK.huntHeight

-- The owner of the tracker's bus registrations.
local OWNER = "Pagle_Hunts tracker"

---@class PagleHuntsNS
---@field tracker HuntsTrackerView?   -- made by ns.StartTracker

-- The tracker's saved state, profile.tracker (hunts.md › Data).
---@return { shown: boolean, collapsed: boolean }
local function saved()
	return ns.db.profile.tracker
end

-- Draws the block from the grouping, the projection and the equipped frame, and sizes it to what shows.
---@param view HuntsTrackerView
local function draw(view)
	local look = ns.TRACKER_FRAMES[Pagle.GetEquipped(ns.TRACKER_FRAME_SLOT)]
	view.look:SetFrame(look)
	local collapsed = saved().collapsed
	view.mark:SetTexture(collapsed and BLOCK.collapsedMark or BLOCK.expandedMark)
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
	local height = HEADER_HEIGHT
	for i, line in ipairs(view.lines) do
		local hunt = not collapsed and lines.hunts[i] or nil
		line:SetShown(hunt ~= nil)
		if hunt then
			line.huntID = hunt.id
			line.dot:SetGroup(hunt.dot)
			line.first:SetText(hunt.first)
			line.second:SetText(hunt.second)
			height = height + HUNT_HEIGHT
		end
	end
	local more = not collapsed and lines.more > 0
	view.more:SetShown(more)
	if more then
		view.more.text:SetText(ns.L.TRACKER_MORE:format(lines.more))
		view.more:ClearAllPoints()
		view.more:SetPoint("TOPLEFT", 0, -height)
		height = height + LINE_HEIGHT
	end
	local empty = not collapsed and lines.empty
	view.empty:SetShown(empty)
	if empty then
		view.empty:ClearAllPoints()
		view.empty:SetPoint("TOPLEFT", DOT_SIZE + 6, -height)
		height = height + LINE_HEIGHT
	end
	ns.InkTrackerWords(view.words, look)
	view.frame:SetHeight(height == HEADER_HEIGHT and height or height + PAD)
end

-- Shows the block while its setting is on, drawn, and tells the grouping whether its lines show, for the refresh of
-- their countdowns (HNT-R42): not while collapsed.
---@param view HuntsTrackerView
local function show(view)
	local tracker = saved()
	view.frame:SetShown(tracker.shown)
	if tracker.shown then
		draw(view)
	end
	ns.SetViewShown("tracker", tracker.shown and not tracker.collapsed)
end

--- Makes the Hunts tracker and docks it (HNT-R75), from OnInitialize after RegisterModule: Core's dock stacks it at
--- order 10 (CORE-R70). Adds "Show the Hunts tracker" to the Trackers page (SET-R41; Core adds the frame's dropdown
--- after it, SET-R44), and redraws at every ns.Redraw while shown, at ModulesChanged (the equipped frame is Core's by
--- then, SHOP-R33) and at each AppearanceChanged for the tracker frame slot (HNT-R79).
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
	-- Shown or not from the start, so the dock stacks it as it is; its first draw waits for ModulesChanged.
	view.frame:SetShown(saved().shown)
	ns.SetViewShown("tracker", saved().shown and not saved().collapsed)
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
