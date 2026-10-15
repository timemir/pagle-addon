if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Lifetime ribbon's spread on the Stats book (stats.md › UI › Lifetime), as logic/Lifetime.lua words it: on the
-- left, the totals, the bests, got away by skill and the characters; on the right, the two-column index of every fish,
-- each item's first and last Catch on hover and its item page (adapter/Item.lua) on a click. With no Casts both pages read "No
-- Sessions yet." (STA-R97). Each side draws on its own content frame (adapter/Book.lua), reusing the pieces it made
-- at earlier draws; every piece sits by its top left on the page.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Heights: the kicker above the title, the title, a figure line, a heading, an index entry; and gaps: after the
-- title, before a heading, after the right page's note, and between the index's columns.
local KICKER, TITLE, LINE, HEADING, ENTRY = 16, 30, 18, 20, 18
local AFTER_TITLE, BEFORE_HEADING, AFTER_NOTE, COLUMN_GAP = 8, 10, 6, 20
-- An index entry's room for its count.
local COUNT_WIDTH = 44

---@class StatsLifetimeEntryView: Button
---@field label FontString
---@field count FontString
---@field item integer
---@field hover string

-- One side's pieces, made at its first draw and reused. `used*` count what the current draw has laid out.
---@class StatsLifetimePageView
---@field kicker FontString
---@field title FontString
---@field hand FontString         -- "No Sessions yet."
---@field note FontString         -- the right page's note
---@field figures StatsBookFigureView[]
---@field headings StatsBookHeadingView[]
---@field entries StatsLifetimeEntryView[]
---@field used { figures: integer, headings: integer, entries: integer }

---@type table<Frame, StatsLifetimePageView>
local views = setmetatable({}, { __mode = "k" })

-- The view on `content`, made at its first draw.
---@param content Frame
---@return StatsLifetimePageView
local function viewOf(content)
	local view = views[content]
	if not view then
		view = {
			kicker = ns.NewBookKicker(content),
			title = ns.NewBookTitle(content),
			hand = ns.NewBookNoSessions(content),
			note = ns.BookText(content, ns.BookFonts().note, LOOK.note),
			figures = {},
			headings = {},
			entries = {},
			used = { figures = 0, headings = 0, entries = 0 },
		}
		view.kicker:SetPoint("TOPLEFT", 0, 0)
		view.title:SetPoint("TOPLEFT", 0, -KICKER)
		view.note:SetWidth(content:GetWidth())
		view.note:SetWordWrap(true)
		view.note:SetText(L.LIFETIME_INDEX_NOTE)
		views[content] = view
	end
	return view
end

-- Starts a draw of `view`: its kicker and title, every other piece put away until laid out again, and "No Sessions
-- yet." under the title with no Casts. Returns the height below the title.
---@param view StatsLifetimePageView
---@param kicker string
---@param title string
---@param empty boolean
---@return number
local function begin(view, kicker, title, empty)
	view.kicker:SetText(kicker)
	view.title:SetText(title)
	view.used.figures, view.used.headings, view.used.entries = 0, 0, 0
	view.note:Hide()
	local y = KICKER + TITLE + AFTER_TITLE
	view.hand:SetShown(empty)
	view.hand:SetPoint("TOPLEFT", 0, -y)
	return y
end

-- Ends a draw: hides the pieces it didn't lay out.
---@param view StatsLifetimePageView
local function finish(view)
	for kind, used in pairs(view.used) do
		local pieces = view[kind] ---@type Frame[]
		for i = used + 1, #pieces do
			pieces[i]:Hide()
		end
	end
end

-- The next piece of `kind` on `view`, made by `make` the first time it is needed.
---@generic T
---@param view StatsLifetimePageView
---@param kind "figures"|"headings"|"entries"
---@param make fun(): T
---@return T
local function nextPiece(view, kind, make)
	local used = view.used[kind] + 1
	view.used[kind] = used
	local pieces = view[kind]
	pieces[used] = pieces[used] or make()
	pieces[used]:Show()
	return pieces[used]
end

-- A figure line at `y` (ns.NewBookFigure), its number in the title's ink.
---@param content Frame
---@param view StatsLifetimePageView
---@param figure StatsFigure
---@param y number
---@return number y below it
local function drawFigure(content, view, figure, y)
	local line = nextPiece(view, "figures", function()
		return ns.NewBookFigure(content, content:GetWidth(), LINE)
	end) --[[@as StatsBookFigureView]]
	line:SetFigure({ label = figure.label, value = figure.value, valueInk = LOOK.title })
	line:SetPoint("TOPLEFT", 0, -y)
	return y + LINE
end

-- A group's heading at `y`, after a gap: its words in small caps, its small note at the right.
---@param content Frame
---@param view StatsLifetimePageView
---@param group StatsFigureGroup
---@param y number
---@return number y below it
local function drawHeading(content, view, group, y)
	local heading = nextPiece(view, "headings", function()
		return ns.NewBookHeading(content, content:GetWidth())
	end) --[[@as StatsBookHeadingView]]
	y = y + BEFORE_HEADING
	heading:SetHeading(group.heading, group.note)
	heading:SetPoint("TOPLEFT", 0, -y)
	return y + HEADING + 2
end

-- The left page (stats.md › UI › Lifetime): the totals, then the bests, got away by skill and the characters.
---@param content Frame
---@return number height
local function drawLeft(content)
	local view = viewOf(content)
	local spread = ns.Lifetime(ns.State())
	local y = begin(view, L.BOOK_LIFETIME, L.LIFETIME_TITLE, spread == nil)
	if spread then
		for _, figure in ipairs(spread.totals) do
			y = drawFigure(content, view, figure, y)
		end
		for _, group in ipairs(spread.groups) do
			y = drawHeading(content, view, group, y)
			for _, figure in ipairs(group.figures) do
				y = drawFigure(content, view, figure, y)
			end
		end
	else
		y = y + LINE
	end
	finish(view)
	return y
end

-- Hovering an index entry: its first and last Catch in the tooltip, its name in red as variant D's hover.
---@param entry StatsLifetimeEntryView
local function enter(entry)
	entry.label:SetTextColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	GameTooltip:SetOwner(entry, "ANCHOR_RIGHT")
	GameTooltip:SetText(entry.hover)
	GameTooltip:Show()
end

---@param entry StatsLifetimeEntryView
local function leave(entry)
	entry.label:SetTextColor(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3])
	GameTooltip:Hide()
end

-- An index entry at `x`, `y`: the item's name (asked of the client until it loads, STA-R73) and its count.
---@param content Frame
---@param view StatsLifetimePageView
---@param data StatsIndexEntry
---@param x number
---@param y number
---@param width number
local function drawEntry(content, view, data, x, y, width)
	local entry = nextPiece(view, "entries", function()
		local entry = CreateFrame("Button", nil, content) --[[@as StatsLifetimeEntryView]]
		entry:SetSize(width, ENTRY)
		local faces = ns.BookFonts()
		entry.label = ns.BookText(entry, faces.small, LOOK.ink)
		entry.label:SetPoint("LEFT", 2, 0)
		entry.label:SetWidth(width - COUNT_WIDTH - 4)
		entry.label:SetWordWrap(false)
		entry.count = ns.BookText(entry, faces.small, LOOK.note)
		entry.count:SetPoint("RIGHT", -2, 0)
		entry.count:SetWidth(COUNT_WIDTH)
		entry.count:SetJustifyH("RIGHT")
		entry:SetScript("OnEnter", enter)
		entry:SetScript("OnLeave", leave)
		entry:SetScript("OnClick", function(self)
			ns.OpenBook({ page = "item", item = self.item })
		end)
		return entry
	end) --[[@as StatsLifetimeEntryView]]
	entry.item, entry.hover = data.item, data.hover
	entry.label:SetText((ns.book:Item(data.item)))
	entry.count:SetText(data.count)
	entry:SetPoint("TOPLEFT", x, -y)
end

-- The right page (stats.md › UI › Lifetime): the note, then the index of every fish in two columns, down the first
-- and then the second. Its height is the index's, so a long one scrolls (STA-R70).
---@param content Frame
---@return number height
local function drawRight(content)
	local view = viewOf(content)
	local spread = ns.Lifetime(ns.State())
	local y = begin(view, L.LIFETIME_CATCH_KICKER, L.LIFETIME_EVERY_FISH, spread == nil)
	if spread then
		view.note:SetPoint("TOPLEFT", 0, -y)
		view.note:Show()
		y = y + view.note:GetStringHeight() + AFTER_NOTE
		local width = (content:GetWidth() - COLUMN_GAP) / 2
		local rows = math.ceil(#spread.index / 2)
		for i, data in ipairs(spread.index) do
			local column, row = math.floor((i - 1) / rows), (i - 1) % rows
			drawEntry(content, view, data, column * (width + COLUMN_GAP), y + row * ENTRY, width)
		end
		y = y + rows * ENTRY
	else
		y = y + LINE
	end
	finish(view)
	return y
end

ns.book:RegisterPage("lifetime", "left", drawLeft)
ns.book:RegisterPage("lifetime", "right", drawRight)
