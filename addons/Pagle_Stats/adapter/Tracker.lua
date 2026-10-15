if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The live tracker on the client (STA-R80–R86; stats.md › UI › Live tracker): the tracker block (adapter/TrackerBlock.lua)
-- docked in Core's dock at order 20, drawn from logic/Tracker.lua's lines in the equipped tracker frame
-- (adapter/Goods.lua's looks). Core only stacks and moves it (CORE-R71, CORE-R72): Stats shows it while it has
-- something to show, and the block sizes itself to its lines with SetHeight, so the dock reflows. It makes no secure
-- frames, so it keeps working in combat (STA-R86, STA-R93).

-- The owner of the tracker's Core callbacks and WoW event registrations (CORE-R23).
local OWNER = "Pagle_Stats tracker"

--- The live tracker: its block, the tick while a Session is current, and the items it asked the client for.
---@class StatsTracker
---@field block StatsTrackerBlock
---@field ticker table?                  -- the live-line tick (STA-R86), while shown with a Session current
---@field requestItem fun(itemID: integer) -- asks for a watched item's name (ns.NewItemLoader); it redraws on load

---@class PagleStatsNS
---@field tracker StatsTracker?          -- made by ns.StartTracker

-- What the tracker is drawn from now (logic/Tracker.lua).
---@return StatsTrackerInput
local function input()
	return {
		on = ns.db.profile.tracker,
		state = ns.State(),
		live = Pagle.GetSession(),
		watched = ns.Watches(),
		updating = ns.IsUpdating(),
		skill = ns.EffectiveSkill(Pagle.GetConditions()),
		now = GetServerTime(),
	}
end

-- Lets a Shift-drag that starts on `row` move the dock: a mouse-enabled row takes the drag, so it hands it to the
-- docked block, whose drag scripts Core hooked (CORE-R71).
---@param row StatsTrackerRow
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

-- A watch's hover (STA-R83): its Dry spell and Your odds text, worked out when the mouse comes onto it.
---@param row StatsTrackerRow
local function hover(row)
	local line = row.line
	local watch = {
		item = line.item --[[@as integer]],
		area = line.area --[[@as integer]],
	}
	local title, lines = ns.TrackerHover(input(), watch)
	GameTooltip:SetOwner(row, "ANCHOR_LEFT")
	GameTooltip:SetText(title)
	for _, text in ipairs(lines) do
		GameTooltip:AddLine(text, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- Gives `row` its mouse: the header toggles the book, a watch opens its entry on the watched place's page and shows
-- its hover, and every line hands drags to the block (STA-R83, CORE-R71). Each reads the row's line when it runs, so
-- a pooled row does what its line now says.
---@param row StatsTrackerRow
---@param block Frame
local function wire(row, block)
	row:EnableMouse(true)
	passDrags(row, block)
	row:SetScript("OnClick", function(self)
		local line = self.line
		if line.kind == "header" then
			ns.ToggleBook()
		elseif line.kind == "watch" then
			-- The watched place's page with the item's entry chosen, even if it has left the place's rows (STA-R60).
			ns.OpenBook({ page = "place", area = line.area, item = line.item })
		end
	end)
	row:SetScript("OnEnter", function(self)
		if self.line.kind == "watch" then
			hover(self)
		end
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Starts or stops the live-line tick: it runs while the tracker shows with a Session current (STA-R86).
---@param tracker StatsTracker
---@param ticking boolean
local function tick(tracker, ticking)
	if ticking and not tracker.ticker then
		tracker.ticker = C_Timer.NewTicker(ns.LIVE_LINE_TICK, function()
			ns.DrawTracker()
		end)
	elseif not ticking and tracker.ticker then
		tracker.ticker:Cancel()
		tracker.ticker = nil
	end
end

--- Draws the live tracker now (STA-R81–R85): shown while on with a current Session or a watch, its lines in the
--- equipped frame, sized to them so the dock reflows; hidden otherwise. Nothing before ns.StartTracker.
function ns.DrawTracker()
	local tracker = ns.tracker
	if not tracker then
		return
	end
	local block = tracker.block
	local view = ns.TrackerLines(input())
	tick(tracker, view.shown and view.ticking)
	if not view.shown then
		block:Hide()
		return
	end
	for _, itemID in ipairs(view.pending) do
		tracker.requestItem(itemID)
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

--- Makes the live tracker and docks it (STA-R80), from OnInitialize after RegisterModule: Core's dock stacks it at
--- order 20, below Hunts' (CORE-R70). It redraws on STA-R73's events, at every ns.Redraw, at SessionStarted, at
--- ModulesChanged (the equipped frame is Core's by then, SHOP-R33), at AppearanceChanged for its frame slot (STA-R84)
--- and on its tick (STA-R86).
---@param module PagleModuleHandle
function ns.StartTracker(module)
	local block = ns.NewTrackerBlock(UIParent)
	block:Hide()
	-- A watched item's name loading redraws the tracker on the next frame, once however many load in it (STA-R59,
	-- STA-R73).
	local redraw = ns.OncePerFrame(function()
		ns.DrawTracker()
	end)
	ns.tracker = { block = block, requestItem = ns.NewItemLoader(OWNER, redraw) }
	module:RegisterTracker({ id = "stats", order = 20, frame = block })

	local function draw()
		ns.DrawTracker()
	end
	ns.OnRedraw(draw)
	Pagle.RegisterCallback(OWNER, "ModulesChanged", draw)
	Pagle.RegisterCallback(OWNER, "SessionStarted", draw)
	ns.OnReadingsMove(OWNER, draw)
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.TRACKER_FRAME_SLOT then
			draw()
		end
	end)
end
