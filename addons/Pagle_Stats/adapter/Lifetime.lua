if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Lifetime ribbon's spread on the Stats book (stats.md › UI › Lifetime), as logic/Lifetime.lua words it: on the
-- left, the totals, the bests, got away by skill and the characters; on the right, the two-column index of every fish,
-- each item's first and last Catch on hover and its item page (adapter/Item.lua) on a click. The index is the books kit
-- v2's: each fish's medallion, its name, a dotted leader and its count in the hand, and on hover the kit's dark slip
-- ruled in brass under it. With no Casts both pages
-- read "No Sessions yet." (STA-R97). Each side draws on its own content frame (adapter/Book.lua), reusing the pieces it
-- made at earlier draws; every piece sits by its top left on the page.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Heights: the kicker above the title, the title, a figure line, a heading, an index entry; and gaps: after the
-- title, before a heading, after the right page's note, and between the index's columns.
local KICKER, TITLE, LINE, HEADING, ENTRY = 16, 30, 18, 20, 23
local AFTER_TITLE, BEFORE_HEADING, AFTER_NOTE, COLUMN_GAP = 8, 10, 6, 20
-- An index entry's room for its count, its medallion's size, and where its name starts.
local COUNT_WIDTH, ENTRY_ICON, NAME_X = 44, 16, 25
-- The dark slip: its height, its brass ends kept when it stretches, its words' inset, and where it hangs under the
-- entry.
local TIP_HEIGHT, TIP_CAP, TIP_PAD, TIP_X, TIP_Y = 33, 10, 12, 30, 2

---@class StatsLifetimeEntryView: Button
---@field icon StatsBookIconView
---@field label FontString
---@field count FontString
---@field dots StatsBookDotsView
---@field item integer
---@field hover string

--- The kit's dark tooltip slip: its brass-ruled paper three-sliced to its words.
---@class StatsLifetimeTipView: Frame
---@field slip StatsThreeSlice
---@field text FontString

-- One side's pieces, made at its first draw and reused. `used*` count what the current draw has laid out.
---@class StatsLifetimePageView
---@field kicker FontString
---@field title FontString
---@field hand FontString         -- "No Sessions yet."
---@field note FontString         -- the right page's note
---@field figures StatsBookFigureView[]
---@field headings StatsBookHeadingView[]
---@field entries StatsLifetimeEntryView[]
---@field tip StatsLifetimeTipView
---@field used { figures: integer, headings: integer, entries: integer }

---@type table<Frame, StatsLifetimePageView>
local views = setmetatable({}, { __mode = "k" })

-- The dark slip on `content`, made once, hidden until an entry is hovered; above the entries.
---@param content Frame
---@return StatsLifetimeTipView
local function newTip(content)
	local tip = CreateFrame("Frame", nil, content) --[[@as StatsLifetimeTipView]]
	tip:SetFrameLevel(content:GetFrameLevel() + 20)
	tip.slip = CreateFrame("Frame", nil, tip) --[[@as StatsThreeSlice]]
	tip.slip:SetPoint("TOPLEFT")
	-- on the slip's own frame, which draws over the tip's: the words over the paper
	tip.text = ns.BookText(tip.slip, ns.BookFonts().tip, LOOK.tipText)
	tip.text:SetWordWrap(false)
	tip.text:SetPoint("LEFT", tip, "LEFT", TIP_PAD, 0)
	tip:Hide()
	return tip
end

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
			tip = newTip(content),
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

-- Hovering an index entry: its first and last Catch on the kit's dark slip under it, within the page's width, its name
-- in red as the kit's hover.
---@param entry StatsLifetimeEntryView
local function enter(entry)
	entry.label:SetTextColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	local content = entry:GetParent() --[[@as Frame]]
	local view = views[content]
	if not view then
		return
	end
	local tip = view.tip
	tip.text:SetText(entry.hover)
	local x = select(4, entry:GetPoint(1)) or 0
	local room = content:GetWidth() - x - TIP_X
	ns.BookBound(tip.text, room - 2 * TIP_PAD)
	local width = math.ceil(tip.text:GetWidth()) + 2 * TIP_PAD
	ns.SetThreeSlice(tip.slip, "Stats", "tip", width, TIP_CAP, "BACKGROUND")
	tip:SetSize(width, TIP_HEIGHT)
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", entry, "BOTTOMLEFT", TIP_X, TIP_Y)
	tip:Show()
end

---@param entry StatsLifetimeEntryView
local function leave(entry)
	entry.label:SetTextColor(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3])
	local view = views[entry:GetParent()]
	if view then
		view.tip:Hide()
	end
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
		entry.icon = ns.NewBookIcon(entry, ENTRY_ICON)
		entry.icon:SetPoint("LEFT", 1, 0)
		entry.label = ns.BookText(entry, faces.text, LOOK.ink)
		entry.label:SetPoint("LEFT", NAME_X, 0)
		entry.label:SetWordWrap(false)
		entry.count = ns.BookText(entry, faces.count, LOOK.small)
		entry.count:SetPoint("RIGHT", -2, 0)
		entry.count:SetJustifyH("RIGHT")
		entry.dots = ns.NewBookDots(entry, LOOK.indexDots, 1)
		entry:SetScript("OnEnter", enter)
		entry:SetScript("OnLeave", leave)
		entry:SetScript("OnClick", function(self)
			ns.OpenBook({ page = "item", item = self.item })
		end)
		return entry
	end) --[[@as StatsLifetimeEntryView]]
	entry.item, entry.hover = data.item, data.hover
	local name, icon = ns.book:Item(data.item)
	entry.icon:SetIcon(icon)
	entry.count:SetText(data.count)
	ns.BookBound(entry.count, COUNT_WIDTH)
	entry.label:SetText(name)
	-- the name stops before its count, cut short with an ellipsis; the dots run between
	local room = width - NAME_X - entry.count:GetWidth() - 2 - 14
	ns.BookBound(entry.label, room)
	entry.dots:SetDots(NAME_X + entry.label:GetWidth() + 7, width - entry.count:GetWidth() - 9, 6)
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
