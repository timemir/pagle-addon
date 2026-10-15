if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- An item's entry on a place's right page (stats.md › UI › Place spread, the item's entry): the watch toggle, Your
-- odds in large ink with its range and scope line (or the learning bar, or the unseen bound) and the extra sentences,
-- the Dry spell with its luck wording and luck ruler, *In my records*, and the link to the item page. The words are
-- logic/Entry.lua's; this file lays them out in adapter/BookWidgets.lua's art, after prototypes/stats-window/ variant
-- D, on the frame adapter/Place.lua gives it (ns.RegisterPlaceEntry). Every line is anchored by its top left at its
-- depth down the page.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Variant D's measures: the large ink's line, the learning bar, and the gaps down the page.
local KICKER_GAP, TITLE_HEIGHT, BIG_HEIGHT, BAR_HEIGHT = 18, 34, 36, 10
local PARA_GAP, GROUP_GAP, HEADING_HEIGHT, LINE_HEIGHT = 6, 14, 20, 20
-- The luck ruler's inset from each side, room for the half of its end labels that reaches past its scale.
local RULER_INSET = 22

-- The watch toggle: the star and its word, faded until it watches, faded further while it can't be pressed.
local TOGGLE_HEIGHT, TOGGLE_STAR = 20, 16
local TOGGLE_FADED, TOGGLE_DISABLED = 0.6, 0.35
-- What the kicker leaves at its right for the toggle ("watching" and its star).
local KICKER_ROOM = 100

---@class StatsEntryToggleView: Button
---@field star Texture
---@field label FontString

---@class StatsEntryView
---@field toggle StatsEntryToggleView
---@field kicker FontString
---@field name StatsBookItemTitleView
---@field headline FontString
---@field bar StatsBookInkBarView
---@field range FontString
---@field sentence FontString
---@field notes FontString
---@field dryHeading StatsBookHeadingView
---@field dryFirst FontString
---@field dryAfter FontString
---@field ruler StatsBookRulerView
---@field recordsHeading StatsBookHeadingView
---@field records StatsBookLineView[]
---@field link StatsBookLinkView

---@class StatsEntryFrame: Frame
---@field entryView StatsEntryView?

-- Shows `region` at depth `y` down its page, `x` across.
---@param region Region
---@param y number
---@param x number?
local function put(region, y, x)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", x or 0, -y)
	region:Show()
end

-- Writes `text` into `line` and shows it at depth `y`, or hides it for nil; returns the depth under it.
---@param line FontString
---@param text string?
---@param y number
---@return number
local function paragraph(line, text, y)
	if not text then
		line:Hide()
		return y
	end
	line:SetText(text)
	put(line, y)
	return y + line:GetStringHeight() + PARA_GAP
end

-- The watch toggle (STA-R61): the red star and "watch" in the hand's large size.
---@param frame Frame
---@return StatsEntryToggleView
local function newToggle(frame)
	local toggle = CreateFrame("Button", nil, frame) --[[@as StatsEntryToggleView]]
	toggle.star = ns.NewBookMark(toggle, "star", TOGGLE_STAR)
	toggle.star:SetPoint("LEFT", 0, 0)
	toggle.label = ns.BookText(toggle, ns.BookFonts().hand, LOOK.note)
	toggle.label:SetPoint("LEFT", toggle.star, "RIGHT", 4, 0)
	return toggle
end

-- Draws the toggle for `item` watched from `area` at the top right of a page `width` wide: "watching" in red when
-- watched, "watch" faded when not; pressing it watches or stops (logic/Watches.lua's rules: the cap's UI error and
-- the tracker's chat line are ns.Watch's). Never pressed while the projection is updating (STA-R72).
---@param toggle StatsEntryToggleView
---@param item integer
---@param area integer
---@param width number
local function drawToggle(toggle, item, area, width)
	local watched = ns.IsWatched(item, area)
	local ink = watched and LOOK.red or LOOK.note
	toggle.label:SetText(watched and L.ENTRY_WATCHING or L.ENTRY_WATCH)
	toggle.label:SetTextColor(ink[1], ink[2], ink[3])
	toggle.star:SetVertexColor(ink[1], ink[2], ink[3])
	local enabled = not ns.IsUpdating()
	toggle:SetEnabled(enabled)
	toggle:SetAlpha(not enabled and TOGGLE_DISABLED or watched and 1 or TOGGLE_FADED)
	local toggleWidth = TOGGLE_STAR + 4 + toggle.label:GetStringWidth()
	toggle:SetSize(toggleWidth, TOGGLE_HEIGHT)
	toggle:SetScript("OnClick", function()
		if ns.IsUpdating() then
			return
		elseif ns.IsWatched(item, area) then
			ns.StopWatching(item, area)
		else
			ns.Watch(item, area)
		end
	end)
	put(toggle, 0, width - toggleWidth)
end

-- The entry's widgets on `frame`, made at its first draw.
---@param frame StatsEntryFrame
---@return StatsEntryView
local function viewOf(frame)
	if frame.entryView then
		return frame.entryView
	end
	local width, faces = frame:GetWidth(), ns.BookFonts()
	local function text(font, color)
		local line = ns.BookText(frame, font, color)
		line:SetWidth(width)
		line:SetWordWrap(true)
		return line
	end
	local view = {
		toggle = newToggle(frame),
		kicker = ns.NewBookKicker(frame),
		name = ns.NewBookItemTitle(frame, width),
		headline = text(faces.big, LOOK.title),
		bar = ns.NewBookInkBar(frame, width, BAR_HEIGHT),
		range = text(faces.small, LOOK.small),
		sentence = text(faces.small, LOOK.small),
		notes = text(faces.note, LOOK.note),
		dryHeading = ns.NewBookHeading(frame, width),
		dryFirst = text(faces.hand, LOOK.hand),
		dryAfter = text(faces.small, LOOK.small),
		ruler = ns.NewBookRuler(frame, width - 2 * RULER_INSET),
		recordsHeading = ns.NewBookHeading(frame, width),
		records = {},
		link = ns.NewBookLink(frame),
	}
	for i = 1, 4 do
		view.records[i] = ns.NewBookLine(frame, width)
	end
	-- the kicker leaves the toggle its room at the top right
	view.kicker:SetWidth(width - KICKER_ROOM)
	view.kicker:SetWordWrap(false)
	frame.entryView = view
	return view
end

--- Draws the entry of `place.item` on `place.area`'s page into `frame` (UI › Place spread).
---@param frame StatsEntryFrame
---@param place StatsBookTarget
---@return number height
local function drawEntry(frame, place)
	local item = place.item --[[@as integer]]
	local area = place.area --[[@as integer]]
	local view = viewOf(frame)
	local data = ns.Entry(ns.State(), item, area, ns.EffectiveSkill(Pagle.GetConditions()))
	local faces = ns.BookFonts()

	drawToggle(view.toggle, item, area, frame:GetWidth())
	view.kicker:SetText(data.kicker)
	put(view.kicker, 0)
	view.name:SetItem(item, KICKER_GAP)
	local y = KICKER_GAP + TITLE_HEIGHT + PARA_GAP

	-- Your odds: learning in the hand's large ink, the others in printed large ink.
	local learning = data.bar ~= nil
	view.headline:SetFontObject(learning and faces.title or faces.big)
	local ink = learning and LOOK.hand or LOOK.title
	view.headline:SetTextColor(ink[1], ink[2], ink[3])
	view.headline:SetText(data.headline)
	put(view.headline, y)
	y = y + BIG_HEIGHT
	if learning then
		view.bar:SetBar(data.bar)
		put(view.bar, y + 2)
		y = y + BAR_HEIGHT + 2 + PARA_GAP
	else
		view.bar:Hide()
	end
	y = paragraph(view.range, data.range, y)
	y = paragraph(view.sentence, data.sentence, y)
	y = paragraph(view.notes, data.notes, y)

	-- The Dry spell: its first sentence in handwriting, then the luck wording and the ruler with a luck reading, or
	-- the learning line as a note.
	y = y + GROUP_GAP
	view.dryHeading:SetHeading(L.ENTRY_DRY, L.ENTRY_DRY_NOTE)
	put(view.dryHeading, y)
	y = y + HEADING_HEIGHT + PARA_GAP
	y = paragraph(view.dryFirst, data.dryFirst, y)
	local luck = data.luck
	view.dryAfter:SetFontObject(luck and faces.small or faces.note)
	local after = luck and LOOK.small or LOOK.note
	view.dryAfter:SetTextColor(after[1], after[2], after[3])
	y = paragraph(view.dryAfter, data.dryAfter, y)
	if luck then
		view.ruler:SetRuler(luck)
		put(view.ruler, y, RULER_INSET)
		y = y + view.ruler:GetHeight() + PARA_GAP
	else
		view.ruler:Hide()
	end

	-- In my records, then the link to the item's page.
	y = y + GROUP_GAP
	view.recordsHeading:SetHeading(L.ENTRY_RECORDS)
	put(view.recordsHeading, y)
	y = y + HEADING_HEIGHT + PARA_GAP
	for i, record in ipairs(data.records) do
		local line = view.records[i]
		line:SetLine(record)
		put(line, y)
		y = y + LINE_HEIGHT
	end
	y = y + GROUP_GAP
	local target = data.link
	view.link:SetLink(L.ENTRY_ITEM_PAGE, function()
		ns.OpenBook(target)
	end)
	put(view.link, y)
	return y + view.link:GetHeight() + PARA_GAP
end

ns.RegisterPlaceEntry(drawEntry)
