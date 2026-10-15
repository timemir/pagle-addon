if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts tracker on the client (HNT-R75–R79, CORE-R73, SET-R41): a native objective-tracker-style block in Core's
-- tracker dock, its collapsible "Hunts" header over the pinned Hunts' lines (logic/Tracker.lua), in the equipped
-- tracker frame (adapter/Goods.lua's looks). Core only stacks it (CORE-R72): Hunts shows it while its setting is on,
-- and sizes it to its lines with SetHeight, so the dock reflows. It makes no secure frames (HNT-R193).

-- The block's width (the shop's sample tracker's), its header, and each Hunt's two lines.
local WIDTH, HEADER_HEIGHT, LINE_HEIGHT, DOT_SIZE, PAD = 220, 18, 14, 8, 4
local HUNT_HEIGHT = 2 * LINE_HEIGHT + 2
-- The header's collapse mark: minus while expanded, plus while collapsed, as the client's own collapsible lists.
local EXPANDED_MARK = "Interface\\Buttons\\UI-MinusButton-Up"
local COLLAPSED_MARK = "Interface\\Buttons\\UI-PlusButton-Up"

-- The owner of the tracker's bus registrations.
local OWNER = "Pagle_Hunts tracker"

--- The tracker's widgets, for its draws (and specs that read them).
---@class HuntsTrackerView
---@field frame Frame            -- the block Core docks
---@field look HuntsTrackerFrameView   -- the tracker frame it wears (HNT-R79)
---@field header Button          -- collapses and expands it (HNT-R77)
---@field title FontString       -- "Hunts"
---@field mark Texture           -- the collapse mark
---@field lines HuntsTrackerLineButton[]   -- one per shown Hunt, ns.TRACKER_SHOWN of them
---@field more HuntsTrackerMoreButton   -- "+N more", opens the board (HNT-R77)
---@field empty FontString       -- "Pin a Hunt to keep it here."
---@field words { text: FontString, font: string }[]   -- every word, for the frame's ink
---@field wearing string?      -- a tracker frame's good ID the dev tour dresses it in (adapter/Tour.lua); nil: the
--- equipped one

---@class HuntsTrackerLineButton: Button
---@field dot BoardDotView
---@field first FontString
---@field second FontString
---@field huntID string?

---@class HuntsTrackerMoreButton: Button
---@field text FontString

---@class PagleHuntsNS
---@field tracker HuntsTrackerView?   -- made by ns.StartTracker

-- Lets a Shift-drag that starts on `child` move the dock: a mouse-enabled child takes the drag, so it hands it to the
-- docked block, whose drag scripts Core hooked (CORE-R71).
---@param child Frame
---@param block Frame
local function passDrags(child, block)
	child:RegisterForDrag("LeftButton")
	for _, script in ipairs({ "OnDragStart", "OnDragStop" }) do
		child:SetScript(script, function()
			local fn = block:GetScript(script)
			if fn then
				fn(block, "LeftButton")
			end
		end)
	end
end

-- A font string on `parent` in the native font object `font`, listed in `words` for the frame's ink.
---@param parent Frame
---@param font string
---@param words { text: FontString, font: string }[]
---@return FontString
local function word(parent, font, words)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	words[#words + 1] = { text = text, font = font }
	return text
end

-- The header: "Hunts" in the native header font over a faint gold rule, with the collapse mark at its right.
---@param block Frame
---@param words { text: FontString, font: string }[]
---@return Button header
---@return FontString title
---@return Texture mark
local function buildHeader(block, words)
	local header = CreateFrame("Button", nil, block)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	local title = word(header, "GameFontNormal", words)
	title:SetPoint("LEFT", 2, 0)
	title:SetText(ns.L.TITLE)
	local mark = header:CreateTexture(nil, "ARTWORK")
	mark:SetSize(14, 14)
	mark:SetPoint("RIGHT", -2, 0)
	local rule = header:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(1, 0.82, 0, 0.35) -- the native header's faint gold rule, as the shop's sample
	rule:SetPoint("BOTTOMLEFT", 0, 1)
	rule:SetPoint("BOTTOMRIGHT", 0, 1)
	rule:SetHeight(1)
	passDrags(header, block)
	return header, title, mark
end

-- Hunt `i`'s two lines, a button that opens the board on its Hunt (HNT-R77): its dot, then the name and label, then
-- the target line and progress under them.
---@param block Frame
---@param i integer
---@param words { text: FontString, font: string }[]
---@return HuntsTrackerLineButton
local function buildLine(block, i, words)
	local line = CreateFrame("Button", nil, block) --[[@as HuntsTrackerLineButton]]
	line:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT - (i - 1) * HUNT_HEIGHT)
	line:SetSize(WIDTH, HUNT_HEIGHT)
	line.dot = ns.NewBoardDot(line, DOT_SIZE)
	line.dot:SetPoint("TOPLEFT", 2, -3)
	line.first = word(line, "GameFontHighlightSmall", words)
	line.first:SetPoint("TOPLEFT", DOT_SIZE + 6, 0)
	line.first:SetPoint("TOPRIGHT", 0, 0)
	line.second = word(line, "GameFontDisableSmall", words)
	line.second:SetPoint("TOPLEFT", DOT_SIZE + 12, -LINE_HEIGHT)
	line.second:SetPoint("TOPRIGHT", 0, -LINE_HEIGHT)
	line:SetScript("OnClick", function(self)
		ns.OpenBoard(self.huntID)
	end)
	passDrags(line, block)
	line:Hide()
	return line
end

-- Builds the block: the header, the Hunts' line buttons, "+N more" and the empty line, all hidden until drawn.
---@return HuntsTrackerView
local function build()
	local block = CreateFrame("Frame", nil, UIParent)
	block:SetSize(WIDTH, HEADER_HEIGHT)
	local words = {}
	local look = ns.NewTrackerFrame(block)
	local header, title, mark = buildHeader(block, words)
	local lines = {}
	for i = 1, ns.TRACKER_SHOWN do
		lines[i] = buildLine(block, i, words)
	end

	local more = CreateFrame("Button", nil, block) --[[@as HuntsTrackerMoreButton]]
	more:SetSize(WIDTH, LINE_HEIGHT)
	more.text = word(more, "GameFontNormalSmall", words)
	more.text:SetPoint("LEFT", DOT_SIZE + 6, 0)
	more:SetScript("OnClick", function()
		ns.OpenBoard()
	end)
	passDrags(more, block)
	more:Hide()

	local empty = word(block, "GameFontDisableSmall", words)
	empty:SetText(ns.L.TRACKER_EMPTY)
	empty:Hide()
	---@type HuntsTrackerView
	return {
		frame = block,
		look = look,
		header = header,
		title = title,
		mark = mark,
		lines = lines,
		more = more,
		empty = empty,
		words = words,
	}
end

-- The tracker's saved state, profile.tracker (hunts.md › Data).
---@return { shown: boolean, collapsed: boolean }
local function saved()
	return ns.db.profile.tracker
end

-- Draws the block from the grouping, the projection and the equipped frame, and sizes it to what shows.
---@param view HuntsTrackerView
local function draw(view)
	local look = ns.TRACKER_FRAMES[view.wearing or Pagle.GetEquipped(ns.TRACKER_FRAME_SLOT)]
	view.look:SetFrame(look)
	local collapsed = saved().collapsed
	view.mark:SetTexture(collapsed and COLLAPSED_MARK or EXPANDED_MARK)
	local conditions = Pagle.GetConditions()
	local lines = ns.TrackerLines({
		rows = ns.groups:Grouping() and ns.groups:Rows({ pinnedOnly = true }) or nil,
		anyPinned = next(ns.db.profile.pins) ~= nil,
		time = ns.TimelineNow(),
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
	local view = build()
	ns.tracker = view
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
