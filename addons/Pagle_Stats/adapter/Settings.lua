if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' watches on the client (STA-R60–R63) and Stats' section on the Trackers page (stats.md › Settings, SET-R42):
-- the "Show the live tracker" checkbox and the Watched Dry spells row, added with M:AddSetting before ModulesChanged
-- (CORE-R42). Core draws the checkbox natively; the row is Stats' own, on its XML template (adapter/Settings.xml),
-- drawn in its mixin's Init and cleared in its Release, so Stats writes no field onto anything Blizzard's Settings code
-- made and calls none of it beyond creating the initializer (SET-R5). The row's frame is Stats', so it redraws at once
-- whenever a watch changes (SET-R62), within the template's height.
local L = ns.L
local OWNER = "Pagle_Stats settings"

ns.WireWatches({
	Profile = function()
		return ns.db.profile
	end,
	UIError = function(text, r, g, b)
		UIErrorsFrame:AddMessage(text, r, g, b)
	end,
	Print = function(line)
		print(line)
	end,
})

-- The Watched Dry spells row's template, which names PagleStatsWatchedRowMixin.
local TEMPLATE = "PagleStatsWatchedRowTemplate"
-- A line's height in the row, as Blizzard's controls; the row's label and count sit on its first line, each watch on
-- the next ones. The label is indented as a row with a parent (SET-R42); the values start left of the row's middle.
local LINE = 26
local LABEL_X = 52
local VALUE_X = -80
local BUTTON_X = 140

---@class StatsWatchedRowWidgets
---@field label FontString
---@field count FontString
---@field none FontString
---@field lines { text: FontString, button: Button }[]

-- The row's widgets on each frame it was drawn on, made the first time. Weak, as the panel owns the frames.
---@type table<Frame, StatsWatchedRowWidgets>
local widgetsOf = setmetatable({}, { __mode = "k" })
-- The frames showing the row now: Init adds one, Release drops it.
---@type table<Frame, true>
local drawn = setmetatable({}, { __mode = "k" })

---@param frame Frame
---@param template string
---@return FontString
local function fontString(frame, template)
	local text = frame:CreateFontString(nil, "OVERLAY", template)
	text:SetJustifyH("LEFT")
	return text
end

-- The row's widgets on `frame`, all hidden.
---@param frame Frame
---@return StatsWatchedRowWidgets
local function widgets(frame)
	local own = widgetsOf[frame]
	if not own then
		own = {
			label = fontString(frame, "GameFontNormal"),
			count = fontString(frame, "GameFontHighlight"),
			none = fontString(frame, "GameFontHighlight"),
			lines = {},
		}
		own.label:SetPoint("TOPLEFT", LABEL_X, -6)
		own.count:SetPoint("TOPLEFT", frame, "TOP", VALUE_X, -6)
		own.none:SetPoint("TOPLEFT", frame, "TOP", VALUE_X, -6 - LINE)
		own.none:SetPoint("RIGHT", -20, 0)
		own.none:SetWordWrap(true)
		for i = 1, ns.MAX_WATCHES do
			local text = fontString(frame, "GameFontHighlight")
			text:SetPoint("TOPLEFT", frame, "TOP", VALUE_X, -6 - i * LINE)
			local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
			button:SetPoint("TOPLEFT", frame, "TOP", BUTTON_X, -2 - i * LINE)
			button:SetSize(120, 22)
			own.lines[i] = { text = text, button = button }
		end
		widgetsOf[frame] = own
	end
	own.label:Hide()
	own.count:Hide()
	own.none:Hide()
	for _, line in ipairs(own.lines) do
		line.text:Hide()
		line.button:Hide()
	end
	return own
end

-- Asks the client for a watched item's name; every shown row redraws once it has loaded.
local requestItem = ns.NewItemLoader(OWNER, function()
	for frame in pairs(drawn) do
		frame--[[@as PagleStatsWatchedRowMixin]]:Draw()
	end
end)

-- A watched item's name; an item the client hasn't loaded reads "Item {id}" and is asked for, and the row redraws
-- when it loads (STA-R59).
---@param itemID integer
---@return string
local function itemName(itemID)
	local name, _, loaded = ns.Item(itemID)
	if not loaded then
		requestItem(itemID)
	end
	return name
end

--- The Watched Dry spells row's frames (adapter/Settings.xml, SET-R5): the panel's list draws one through Blizzard's
--- stock InitFrame, which calls Init, and gives it back through the stock Resetter, which calls Release.
---@class PagleStatsWatchedRowMixin : Frame
PagleStatsWatchedRowMixin = {}

--- Draws the row and keeps it drawn while it shows: a watch added or stopped redraws it at once. It reads nothing from
--- its initializer: the row is the same wherever it is drawn.
function PagleStatsWatchedRowMixin:Init()
	drawn[self] = true
	self:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.SETTINGS_WATCHED)
		GameTooltip:AddLine(L.SETTINGS_WATCHED_TOOLTIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	self:Draw()
end

--- Hides the row's widgets, so the frame comes back empty for the next row.
function PagleStatsWatchedRowMixin:Release()
	drawn[self] = nil
	widgets(self)
end

--- The row now (stats.md › Settings): "{n} of 3", then each watch oldest first, "{item}, {place}" by the watched
--- area's own name, with its "Stop watching" button; with none, the line saying where to watch from. No projection
--- numbers.
function PagleStatsWatchedRowMixin:Draw()
	local own = widgets(self)
	local watches = ns.Watches()
	own.label:SetText(L.SETTINGS_WATCHED)
	own.label:Show()
	own.count:SetText(L.SETTINGS_WATCHED_COUNT:format(#watches, ns.MAX_WATCHES))
	own.count:Show()
	if #watches == 0 then
		own.none:SetText(L.SETTINGS_WATCHED_NONE)
		own.none:Show()
	end
	for i, watch in ipairs(watches) do
		local line = own.lines[i]
		if line then
			local item, area = watch.item, watch.area
			line.text:SetText(L.SETTINGS_WATCHED_LINE:format(itemName(item), ns.AreaName(area)))
			line.text:Show()
			line.button:SetText(L.SETTINGS_STOP_WATCHING)
			line.button:SetScript("OnClick", function()
				ns.StopWatching(item, area)
			end)
			line.button:Show()
		end
	end
end

-- A watch added or stopped redraws every shown row at once (SET-R62).
ns.OnRedraw(function(reason)
	if reason == "watches" then
		for frame in pairs(drawn) do
			frame--[[@as PagleStatsWatchedRowMixin]]:Draw()
		end
	end
end)

--- Adds Stats' section to the Trackers page (SET-R42, CORE-R42): Core puts it under a "Stats" header. The checkbox
--- holds profile.tracker, off by default, which the page's Defaults button restores (SET-R45); the Watched Dry spells
--- row hangs under it, is never greyed out and has no value, so Defaults leaves the watches alone (SET-R60). Core then
--- ends the section with Stats' tracker frame dropdown, once its slot is registered (SET-R44).
---@param M PagleModuleHandle
function ns.AddSettings(M)
	M:AddSetting("trackers", {
		kind = "checkbox",
		id = "tracker",
		label = L.SETTINGS_TRACKER,
		tooltip = L.SETTINGS_TRACKER_TOOLTIP,
		default = false,
		get = function()
			return ns.db.profile.tracker
		end,
		set = function(value)
			ns.db.profile.tracker = value
			ns.Redraw("tracker") -- the live tracker shows or hides at once (STA-R81)
		end,
	})
	M:AddSetting("trackers", {
		kind = "custom",
		id = "watched",
		parent = "tracker",
		label = L.SETTINGS_WATCHED,
		tooltip = L.SETTINGS_WATCHED_TOOLTIP,
		init = function()
			local initializer = Settings.CreateElementInitializer(TEMPLATE, { name = L.SETTINGS_WATCHED })
			initializer:AddSearchTags(L.SETTINGS_WATCHED)
			return initializer
		end,
	})
end
