if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- An item's entry on a place's right page (stats.md › UI › Place spread, the item's entry): the watch toggle, Your
-- odds in large ink with its range and scope line (or the learning bar, or the unseen bound) and the extra sentences,
-- the Dry spell with its luck wording and luck ruler, *In my records*, and the link to the item page. The words are
-- logic/Entry.lua's; this file lays them out as the books art kit's Stats book does (adapter/BookWidgets.lua's art),
-- on the frame adapter/Place.lua gives it (ns.RegisterPlaceEntry): the "watching" pill at the top right, the item's
-- medallion by its name, "about" in the hand before the odds in large handwriting, the ruler with the kit's "me" mark,
-- and the records two to a line. Every line is anchored by its top left at its depth down the page.
--
-- Its readings move as the books kit v2's MOTION.md has them, when a Cast changes the entry shown (the same item on the
-- same place): each rewritten line's ink fades up from 30% (0.3 s); the "me" mark slides along the luck ruler to the
-- new reading (0.6 s, ease-out); a catch that resets the Dry spell fades the ruler out (0.3 s, easing in), keeping
-- its room until the next Cast brings it back, fading in, and writes itself in with the "write" sound.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- The kit's measures: the title's line under the kicker, the large ink's line, the learning bar, and the gaps down the
-- page.
local KICKER_GAP, TITLE_HEIGHT, BIG_HEIGHT, BAR_HEIGHT = 20, 44, 50, 10
local PARA_GAP, GROUP_GAP, HEADING_HEIGHT, LINE_HEIGHT = 6, 14, 21, 23
-- "about" before the odds: how far across the odds start, and how far down "about" sits by them.
local ABOUT_ROOM, ABOUT_DROP = 53, 17
-- The luck ruler's inset from each side.
local RULER_INSET = 4
-- The records two to a line, and the gap between the two.
local RECORD_COLUMNS, RECORD_GAP = 2, 18

-- The watch toggle: the kit's paper pill, its star and its word, faded until it watches, faded further while it can't
-- be pressed.
local TOGGLE_HEIGHT, TOGGLE_CAP, STAR_X, STAR_Y, WORD_X = 30, 15, 8, 8, 29
local TOGGLE_FADED, TOGGLE_DISABLED = 0.6, 0.35
-- What the kicker leaves at its right for the toggle ("watching" and its star).
local KICKER_ROOM = 110
-- The readings' motion (the kit's MOTION.md): the mark's slide, and the ruler's fade out and back in.
local MARK_SLIDE, RULER_FADE = 0.6, 0.3

---@class StatsEntryToggleView: Button
---@field pill StatsThreeSlice
---@field star Texture
---@field label FontString

---@class StatsEntryView
---@field toggle StatsEntryToggleView
---@field kicker FontString
---@field name StatsBookItemTitleView
---@field about FontString
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
---@field last StatsEntryShown?      -- what the entry last showed, to move its readings when a Cast changes them
---@field rulerResting boolean       -- the ruler faded out at a catch, keeping its room until the next Cast

--- What an entry showed at its last draw: its item and place, its lines' words, its Dry spell and its luck reading.
---@class StatsEntryShown
---@field key string
---@field texts table<FontString, string>
---@field since integer
---@field luck number?

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

-- The watch toggle (STA-R61): the paper pill with the red star and "watch" in the hand.
---@param frame Frame
---@return StatsEntryToggleView
local function newToggle(frame)
	local toggle = CreateFrame("Button", nil, frame) --[[@as StatsEntryToggleView]]
	toggle.pill = CreateFrame("Frame", nil, toggle) --[[@as StatsThreeSlice]]
	toggle.pill:SetPoint("TOPLEFT")
	toggle.pill:SetFrameLevel(toggle:GetFrameLevel())
	toggle.star = ns.NewBookMark(toggle.pill, "star", 15)
	toggle.star:SetPoint("TOPLEFT", STAR_X, -STAR_Y)
	toggle.label = ns.BookText(toggle.pill, ns.ArtFont("hand", 18), LOOK.note)
	toggle.label:SetPoint("TOPLEFT", WORD_X, -6)
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
	local enabled = not ns.IsUpdating()
	toggle:SetEnabled(enabled)
	toggle:SetAlpha(not enabled and TOGGLE_DISABLED or watched and 1 or TOGGLE_FADED)
	local toggleWidth = WORD_X + math.ceil(toggle.label:GetStringWidth()) + 12
	ns.SetThreeSlice(toggle.pill, "Parts", "watch", toggleWidth, TOGGLE_CAP, "BACKGROUND")
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
	put(toggle, -4, width - toggleWidth)
end

-- The entry's widgets on `frame`, made at its first draw.
---@param frame StatsEntryFrame
---@return StatsEntryView
local function viewOf(frame)
	if frame.entryView then
		return frame.entryView
	end
	local width, faces = frame:GetWidth(), ns.BookFonts()
	local function text(font, color, spacing)
		local line = ns.BookText(frame, font, color)
		line:SetWidth(width)
		line:SetWordWrap(true)
		line:SetSpacing(spacing or 4)
		return line
	end
	local recordWidth = (width - RECORD_GAP * (RECORD_COLUMNS - 1)) / RECORD_COLUMNS
	local view = {
		toggle = newToggle(frame),
		kicker = ns.NewBookKicker(frame, width - KICKER_ROOM), -- leaving the toggle its room at the top right
		name = ns.NewBookItemTitle(frame, width),
		about = ns.BookText(frame, faces.about, LOOK.small),
		headline = text(faces.big, LOOK.big, 0),
		bar = ns.NewBookInkBar(frame, width),
		range = text(faces.note, LOOK.small),
		sentence = text(faces.text, LOOK.ink),
		notes = text(faces.note, LOOK.note),
		dryHeading = ns.NewBookHeading(frame, width),
		dryFirst = text(faces.hand, LOOK.ink, 2),
		dryAfter = text(faces.hand, LOOK.red, 2),
		ruler = ns.NewBookRuler(frame, width - 2 * RULER_INSET),
		recordsHeading = ns.NewBookHeading(frame, width),
		records = {},
		link = ns.NewBookLink(frame),
	}
	for i = 1, 4 do
		view.records[i] = ns.NewBookLine(frame, recordWidth)
	end
	view.about:SetText(L.ODDS_ABOUT)
	frame.entryView = view
	return view
end

-- Your odds in large ink (UI › Place spread): a known reading as "about" in the hand before "1 in N" in large
-- handwriting, as the kit sets it; learning and unseen whole, learning in the hand's blue. Returns the depth under it.
---@param view StatsEntryView
---@param data StatsEntry
---@param y number
---@return number
local function drawHeadline(view, data, y)
	local learning = data.bar ~= nil
	local headline = data.headline
	local lead = L.ODDS_ABOUT .. " "
	local about = not learning and headline:sub(1, #lead) == lead
	view.about:SetShown(about)
	if about then
		headline = headline:sub(#lead + 1)
		put(view.about, y + ABOUT_DROP)
	end
	local ink = learning and LOOK.hand or LOOK.big
	view.headline:SetTextColor(ink[1], ink[2], ink[3])
	view.headline:SetText(headline)
	put(view.headline, y, about and ABOUT_ROOM or 0)
	y = y + BIG_HEIGHT
	if learning then
		view.bar:SetBar(data.bar)
		put(view.bar, y + 2)
		y = y + BAR_HEIGHT + 2 + PARA_GAP
	else
		view.bar:Hide()
	end
	return y
end

-- The luck ruler at depth `y` with a luck reading `luck`, or none: when a Cast moved the reading on the entry shown,
-- the "me" mark slides there from the last one; when it comes back after a catch, it fades in; at a catch it fades
-- out where it was, its room kept until the next Cast. Returns the depth under it.
---@param view StatsEntryView
---@param luck number?
---@param last StatsEntryShown? what the same entry showed last, nil for another entry
---@param caught boolean
---@param since integer the Dry spell now
---@param y number
---@return number
local function drawRuler(view, luck, last, caught, since, y)
	local ruler = view.ruler
	ns.SyncMotion()
	if luck then
		local resting = view.rulerResting
		view.rulerResting = false
		put(ruler, y, RULER_INSET)
		ns.StopMotion(ruler)
		local to = ns.RulerPosition(luck)
		if last and last.luck then
			local from = ruler.position
			ruler:SetAlpha(1)
			ns.Animate(ruler, {
				{
					dur = MARK_SLIDE,
					ease = ns.Ease.out,
					keys = { { 0, { from } }, { 1, { to } } },
					apply = function(v)
						ruler:SetMark(v[1])
					end,
				},
			})
		else
			ruler:SetMark(to)
			if last and resting then
				ns.Animate(ruler, {
					{
						dur = RULER_FADE,
						ease = ns.Ease.out,
						keys = { { 0, { 0 } }, { 1, { 1 } } },
						apply = function(v)
							ruler:SetAlpha(v[1])
						end,
					},
				})
			else
				ruler:SetAlpha(1)
			end
		end
		return y + ruler:GetHeight() + PARA_GAP
	end
	if caught and last and last.luck and ns.motion then
		-- it fades out where it was, keeping its room
		view.rulerResting = true
		ns.StopMotion(ruler)
		put(ruler, y, RULER_INSET)
		ns.Animate(ruler, {
			{
				dur = RULER_FADE,
				ease = ns.Bezier(0.42, 0, 1, 1),
				keys = { { 0, { 1 } }, { 1, { 0 } } },
				apply = function(v)
					ruler:SetAlpha(v[1])
				end,
			},
		}, function()
			ruler:Hide()
			ruler:SetAlpha(1)
		end)
		return y + ruler:GetHeight() + PARA_GAP
	end
	if view.rulerResting and last and since == 0 then
		-- still resting since the catch: its room stays until the next Cast
		return y + ruler:GetHeight() + PARA_GAP
	end
	view.rulerResting = false
	ns.StopMotion(ruler)
	ruler:Hide()
	ruler:SetAlpha(1)
	return y
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
	local width = frame:GetWidth()
	local key = item .. ":" .. area
	local last = view.last
	local same = last ~= nil and last.key == key
	local since = ns.DrySpell(data.reading).since
	-- a catch of it here: the Dry spell resets
	local caught = same and last.since > 0 and since == 0
	if not same then
		view.rulerResting = false
	end

	drawToggle(view.toggle, item, area, width)
	view.kicker:SetText(data.kicker)
	put(view.kicker, 3)
	view.name:SetItem(item, KICKER_GAP)
	local y = KICKER_GAP + TITLE_HEIGHT + PARA_GAP

	-- Your odds, then its range, scope line and extra sentences.
	y = drawHeadline(view, data, y)
	y = paragraph(view.range, data.range, y)
	y = paragraph(view.sentence, data.sentence, y)
	y = paragraph(view.notes, data.notes, y)

	-- The Dry spell: its first sentence in the hand, then the luck wording in red when it is unlucky, and the ruler with
	-- a luck reading; the learning line as a note.
	y = y + GROUP_GAP
	view.dryHeading:SetHeading(L.ENTRY_DRY, L.ENTRY_DRY_NOTE)
	put(view.dryHeading, y)
	y = y + HEADING_HEIGHT + PARA_GAP
	y = paragraph(view.dryFirst, data.dryFirst, y)
	local luck = data.luck
	local faces = ns.BookFonts()
	view.dryAfter:SetFontObject(luck and faces.hand or faces.note)
	local after = LOOK.note
	if luck then
		after = ns.Band(luck) == "normal" and LOOK.hand or LOOK.red
	end
	view.dryAfter:SetTextColor(after[1], after[2], after[3])
	y = paragraph(view.dryAfter, data.dryAfter, y)
	y = drawRuler(view, luck, same and last --[[@as StatsEntryShown]] or nil, caught, since, y)

	-- In my records two to a line, then the link to the item's page.
	y = y + GROUP_GAP
	view.recordsHeading:SetHeading(L.ENTRY_RECORDS)
	put(view.recordsHeading, y)
	y = y + HEADING_HEIGHT + PARA_GAP
	local recordWidth = (width - RECORD_GAP * (RECORD_COLUMNS - 1)) / RECORD_COLUMNS
	for i, record in ipairs(data.records) do
		local line = view.records[i]
		line:SetLine(record)
		local column, row = (i - 1) % RECORD_COLUMNS, math.floor((i - 1) / RECORD_COLUMNS)
		put(line, y + row * LINE_HEIGHT, column * (recordWidth + RECORD_GAP))
	end
	y = y + math.ceil(#data.records / RECORD_COLUMNS) * LINE_HEIGHT + GROUP_GAP
	local target = data.link
	view.link:SetLink(L.ENTRY_ITEM_PAGE, function()
		ns.OpenBook(target)
	end)
	put(view.link, y)

	-- the lines a Cast rewrote fade up; a catch writes itself in
	local texts = {}
	for _, line in ipairs({ view.headline, view.range, view.sentence, view.notes, view.dryFirst, view.dryAfter }) do
		texts[line] = line:IsShown() and line:GetText() or ""
	end
	for _, line in ipairs(view.records) do
		texts[line.value] = line.value:GetText() or ""
	end
	if same then
		for line, text in pairs(texts) do
			if text ~= "" and text ~= last.texts[line] then
				ns.InkIn(line)
			end
		end
	end
	if caught then
		ns.BookSound("write")
	end
	view.last = { key = key, texts = texts, since = since, luck = luck }
	return y + view.link:GetHeight() + PARA_GAP
end

ns.RegisterPlaceEntry(drawEntry)
