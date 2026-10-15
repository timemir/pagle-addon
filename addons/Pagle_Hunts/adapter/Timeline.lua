if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The board's left page on the client (HNT-R61–R63, HNT-R66's left page, HNT-R67, HNT-R69): ns.BoardTimeline gathers
-- logic/Timeline.lua's inputs from the grouping, the projection, the names and Core, and this file draws the result
-- on the left page of every mode (the Board, a set's page, an entry opened from it), and the realm clock and the "show
-- completed" checkbox on the leather. On the Board it selects the Hunt HNT-R67 picks before the right page draws; the
-- entry's renderer (adapter/Entry.lua) draws that Hunt, or HNT-R67's line when none is. The look is the books art
-- kit's Hunts board (adapter/BoardWidgets.lua's art): the kicker and title, the ruler with its hours, the washes and
-- the now line, each group under its dot, name, note and count, the rows with their medallions, bars and margin
-- labels, the scroll rail in the margin, and the legend drawn with the bars' own strokes.
--
-- It is live (the kit v2's MOTION.md): the grouping refreshes on every realm minute while the board shows (HNT-R42), so
-- the now line stays put while the hours, the night wash and the bars drift left and the countdowns are rewritten. When
-- a regroup moves a Hunt to another group, the groups restack and each row slides to its new place (0.4 s); a Hunt that
-- has just opened flashes green under its row and the board plays its sound.
--
-- An aura's expiry is C_UnitAuras.GetPlayerAuraBySpellID's `expirationTime`, on GetTime's clock (HNT-R63).

local LOOK = ns.BOARD_LOOK

-- The page's layout, in UI units down the page's body (the kit's canvas): the kicker and title, the ruler's hour
-- labels, its ticks, its rule and "Realm time", the list scrolling under it, and the legend at the foot.
local KICKER_Y, TITLE_Y = 1, 17
local HOUR_Y, TICK_Y, MINOR_Y, RULE_Y, REALM_Y, NEXT_Y = 53, 69, 74, 82.5, 65, 58
local LIST_Y, LIST_HEIGHT, LEGEND_Y = 84, 368, 498
-- The now line runs up through the ruler from here.
local NOW_Y = 44
-- Each row's columns: the medallion, the name, the track (190 units for the ruler's 24 hours), and the margin label
-- right-aligned at the list's edge.
local NAME_X, NAME_WIDTH, TRACK_X, TRACK_WIDTH, MARGIN_INSET = 31, 140, 178, 190, 3
local ROW_HEIGHT, HEADING_GAP, HEADING_HEIGHT = 26, 10, 24
-- A row's slide to its new place, and a Hunt just opened's flash under its row: up to 22% by 0.35 s, gone by 1.4 s.
local SLIDE, FLASH, FLASH_PEAK = 0.4, 1.4, 0.22
local ICON_SIZE, RING_SIZE = 19, 22
-- The scroll rail, this far right of the list's edge, and how far a wheel notch scrolls.
local RAIL_GAP, RAIL_WIDTH, WHEEL_STEP = 10, 4, 40
-- The legend's bars and the gaps after each bar and each item.
local LEGEND_BAR, LEGEND_GAP, LEGEND_ITEM_GAP = 18, 5, 14

-- An aura's expiry in server time (HNT-R63): `GetServerTime() + (expirationTime - GetTime())`, read for display only;
-- nil when the call or the aura is missing, `expirationTime` is 0, or it is secret.
---@param spellID integer
---@return integer?
local function auraExpiry(spellID)
	local auras = C_UnitAuras
	local aura = auras and auras.GetPlayerAuraBySpellID and auras.GetPlayerAuraBySpellID(spellID)
	local expires = aura and aura.expirationTime
	if not expires or issecretvalue(expires) or expires == 0 then
		return nil
	end
	return GetServerTime() + math.floor(expires - GetTime())
end

--- The timeline the left page of `place` draws (logic/Timeline.lua): the Board's, or a set's when the place has one
--- and isn't the Board (HNT-R66), at ns.ViewNow() (frozen while the grouping is paused, HNT-R43), with the saved
--- "show completed" filter (HNT-R82; while updating it hides nothing, HNT-R69).
---@param place BoardPlace
---@return HuntsTimeline
function ns.BoardTimeline(place)
	local now = ns.ViewNow()
	local setID = place.mode ~= "board" and place.set or nil
	local updating = ns.IsUpdating()
	local state = ns.State()
	local set
	if setID then
		set = {
			name = ns.hunts:SetName(setID),
			title = ns.hunts:SetTitle(setID),
			earned = not updating and state.sets[setID] ~= nil,
		}
	end
	local current = {}
	for _, hunt in ipairs(ns.hunts:Current(now)) do
		current[hunt.id] = true
	end
	return ns.BuildTimeline({
		rows = ns.groups:Rows({ filtered = true, set = setID }),
		current = current,
		now = now,
		snapshot = Pagle.GetConditions(),
		where = ns.where,
		list = ns.hunts,
		sources = ns.names,
		nightSpec = Pagle.GetWindowSpec("night"),
		progress = state.hunts,
		updating = updating,
		auraExpiry = auraExpiry,
		set = set,
		selected = place.hunt,
		pick = place.mode == "board",
	})
end

-- A row is clicked (HNT-R67): on the Board it selects that Hunt, whose entry the right page shows; on a set's page or
-- an entry opened from it, it opens that Hunt's entry with "back to {set}".
---@param place BoardPlace
---@param huntID string
local function clicked(place, huntID)
	if place.mode == "board" or not place.set then
		ns.board:Select(huntID)
		ns.board:Draw()
	else
		ns.board:Open({ mode = "entry", set = place.set, hunt = huntID })
	end
end

---@class TimelineRowView: Button
---@field shade Texture
---@field flash Texture
---@field y number?        -- where it sits down the list, as it slides
---@field dashes BoardOutline
---@field icon BoardIconView
---@field pin HuntsSpriteTexture
---@field name FontString
---@field track Frame
---@field bars BoardTimelineBarView[]
---@field note FontString
---@field margin FontString
---@field huntID string

---@class TimelineHeadingView: Frame
---@field y number?
---@field dot BoardDotView
---@field label FontString
---@field note FontString
---@field count FontString

---@class TimelinePageView
---@field kicker FontString
---@field title FontString
---@field ruler Frame             -- the ruler's labels, ticks and rule
---@field ticks { mark: Texture, label: FontString }[]
---@field nowLine Texture
---@field column Frame            -- the track's column behind the list, for the washes
---@field washes Texture[]
---@field scroll ScrollFrame
---@field content Frame
---@field rail Texture
---@field thumb Texture
---@field rows table<string, TimelineRowView>          -- by Hunt, so a row keeps its frame as it moves
---@field headings table<HuntGroup, TimelineHeadingView>
---@field groupOf table<string, HuntGroup>             -- each row's group at the last draw
---@field serial integer?                               -- the board's draw it last drew at (ns.board:Serial())
---@field legend Frame
---@field legendBars BoardTimelineBarView[]
---@field legendTexts FontString[]
---@field empty FontString
---@field width number
---@field place BoardPlace
---@field placeThumb fun()       -- sizes and places the rail's thumb for the list's scroll

-- A row: the medallion with its pin, the name, the track with its bars, the margin label, and the selected row's shade
-- and dashed outline.
---@param view TimelinePageView
---@return TimelineRowView
local function newRow(view)
	local fonts = ns.BoardFonts()
	local row = CreateFrame("Button", nil, view.content) --[[@as TimelineRowView]]
	row:SetSize(view.width, ROW_HEIGHT)
	row.shade = ns.BoardSolid(row, LOOK.shade, "BACKGROUND", LOOK.shadeAlpha)
	row.flash = ns.BoardSolid(row, LOOK.paperGroups.now, "BACKGROUND")
	row.flash:SetAlpha(0)
	row.dashes = ns.BoardOutline(row, 0, "BORDER")
	row.icon = ns.NewBoardIcon(row, ICON_SIZE, RING_SIZE)
	row.icon:SetPoint("TOPLEFT", 1.5, -3.5)
	-- The pin mark: the kit's red pin over the medallion's corner.
	row.pin = ns.ArtSprite(row, "Parts", "ic-pin", "OVERLAY")
	ns.PlaceSprite(row.pin, row, 15, -4)
	row.name = ns.BoardText(row, fonts.text, LOOK.ink)
	row.name:SetPoint("TOPLEFT", NAME_X, -4)
	row.name:SetWidth(NAME_WIDTH)
	row.name:SetWordWrap(false)
	row.track = CreateFrame("Frame", nil, row)
	row.track:SetSize(TRACK_WIDTH, ROW_HEIGHT)
	row.track:SetPoint("TOPLEFT", TRACK_X, 0)
	row.bars = {}
	row.note = ns.BoardText(row.track, fonts.note, LOOK.note)
	row.note:SetPoint("TOPLEFT", 4, -4)
	row.margin = ns.BoardText(row, fonts.margin, LOOK.red)
	row.margin:SetPoint("TOPRIGHT", -MARGIN_INSET, -4)
	row.margin:SetWidth(view.width - TRACK_X - TRACK_WIDTH - 4 - MARGIN_INSET) -- from the track's end to the edge
	row.margin:SetWordWrap(false)
	row.margin:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		clicked(view.place, self.huntID)
	end)
	return row
end

-- A group's heading: its dot, its name in small caps, its note in italic, and its row count in the margin.
---@param view TimelinePageView
---@return TimelineHeadingView
local function newHeading(view)
	local fonts = ns.BoardFonts()
	local heading = CreateFrame("Frame", nil, view.content) --[[@as TimelineHeadingView]]
	heading:SetSize(view.width, HEADING_GAP + HEADING_HEIGHT)
	heading.dot = ns.NewBoardDot(heading, 9)
	heading.dot:SetPoint("TOPLEFT", 0, -(HEADING_GAP + 6))
	heading.label = ns.BoardText(heading, fonts.kicker, LOOK.group)
	heading.label:SetPoint("TOPLEFT", 17, -(HEADING_GAP + 4))
	heading.note = ns.BoardText(heading, fonts.note, LOOK.note)
	heading.note:SetWordWrap(false)
	heading.note:SetPoint("LEFT", heading.label, "RIGHT", 8, 0)
	heading.count = ns.BoardText(heading, fonts.count, LOOK.count)
	heading.count:SetPoint("TOPRIGHT", 0, -HEADING_GAP)
	heading.count:SetJustifyH("RIGHT")
	return heading
end

-- Places `region`'s top left `x`, `y` down `page`.
---@param region Region
---@param page Frame
---@param x number
---@param y number
local function at(region, page, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
end

-- The ruler's fixed parts: "Realm time" at its left, "next 22h" in the hand at its right, its minor ticks each hour
-- and its rule; the hours' labels and ticks come with each draw.
---@param page Frame
---@param width number
---@return Frame
local function buildRuler(page, width)
	local fonts = ns.BoardFonts()
	local ruler = CreateFrame("Frame", nil, page)
	ruler:SetAllPoints()
	local realm = ns.BoardText(ruler, ns.ArtFont("print", 11), LOOK.kicker)
	realm:SetText(ns.BoardSmallCaps(ns.L.RULER_REALM_TIME))
	at(realm, page, 0, REALM_Y)
	local ahead = ns.BoardText(ruler, fonts.count, LOOK.red)
	ahead:SetJustifyH("RIGHT")
	ahead:SetText(ns.L.RULER_NEXT:format(math.floor(ns.RULER_AFTER / 3600)))
	ahead:SetPoint("TOPRIGHT", page, "TOPLEFT", width, -NEXT_Y)
	local rule = ns.BoardSolid(ruler, LOOK.group, "ARTWORK")
	rule:SetSize(width, 1.5)
	at(rule, page, 0, RULE_Y)
	return ruler
end

-- The page's frames, made at its first draw: the kicker and title, the ruler, the washes' column, the scrolling list
-- with its rail, the now line over them, the legend, and the line that stands alone when no Hunt is current.
---@param page Frame
---@return TimelinePageView
local function build(page)
	local width = page:GetWidth()
	local fonts = ns.BoardFonts()

	local kicker = ns.BoardText(page, fonts.kicker, LOOK.kicker)
	kicker:SetText(ns.BoardSmallCaps(ns.L.TIMELINE_KICKER))
	at(kicker, page, 0, KICKER_Y)
	local title = ns.BoardText(page, fonts.heading, LOOK.title)
	at(title, page, 0, TITLE_Y)
	title:SetWidth(width)
	title:SetWordWrap(false)

	local ruler = buildRuler(page, width)

	local column = CreateFrame("Frame", nil, page)
	at(column, page, TRACK_X, LIST_Y)
	column:SetSize(TRACK_WIDTH, LIST_HEIGHT)

	local scroll = CreateFrame("ScrollFrame", nil, page) --[[@as ScrollFrame]]
	at(scroll, page, 0, LIST_Y)
	scroll:SetSize(width, LIST_HEIGHT)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width, 1)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)

	local rail = ns.BoardSolid(page, LOOK.rail, "ARTWORK", 0.15)
	rail:ClearAllPoints()
	rail:SetSize(RAIL_WIDTH, LIST_HEIGHT)
	at(rail, page, width + RAIL_GAP, LIST_Y)
	local thumb = ns.BoardSolid(page, LOOK.thumb, "ARTWORK", 1)
	thumb:ClearAllPoints()
	thumb:SetWidth(RAIL_WIDTH)

	-- The now line runs up through the ruler, over the list: on its own frame above the scroll.
	local over = CreateFrame("Frame", nil, page)
	over:SetAllPoints()
	over:SetFrameLevel(scroll:GetFrameLevel() + 5)
	local nowLine = ns.BoardSolid(over, LOOK.nowLine, "OVERLAY")
	nowLine:ClearAllPoints()
	nowLine:SetSize(2, LIST_Y + LIST_HEIGHT - NOW_Y)

	local legend = CreateFrame("Frame", nil, page)
	legend:SetAllPoints()

	local empty = ns.BoardText(page, fonts.hand, LOOK.hand)
	at(empty, page, 0, NOW_Y)
	empty:SetWidth(width)

	---@type TimelinePageView
	local view = {
		kicker = kicker,
		title = title,
		ruler = ruler,
		ticks = {},
		nowLine = nowLine,
		column = column,
		washes = {},
		scroll = scroll,
		content = content,
		rail = rail,
		thumb = thumb,
		rows = {},
		headings = {},
		groupOf = {},
		legend = legend,
		legendBars = {},
		legendTexts = {},
		empty = empty,
		width = width,
		place = { mode = "board" },
		placeThumb = function() end, -- below
	}
	local function placeThumb()
		local range = scroll:GetVerticalScrollRange()
		local shown = range > 0
		rail:SetShown(shown)
		thumb:SetShown(shown)
		if shown then
			local share = LIST_HEIGHT / (LIST_HEIGHT + range)
			local height = math.max(12, LIST_HEIGHT * share)
			thumb:SetHeight(height)
			at(thumb, page, width + RAIL_GAP, LIST_Y + (LIST_HEIGHT - height) * scroll:GetVerticalScroll() / range)
		end
	end
	view.placeThumb = placeThumb
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local offset = self:GetVerticalScroll() - delta * WHEEL_STEP
		self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
		placeThumb()
	end)
	return view
end

-- Draws the ruler (HNT-R62): its hours' labels and ticks, a minor tick each hour, and the now line.
---@param view TimelinePageView
---@param page Frame
---@param ruler TimelineRuler
local function drawRuler(view, page, ruler)
	local fonts = ns.BoardFonts()
	for i, tick in ipairs(ruler.ticks) do
		local drawn = view.ticks[i]
		if not drawn then
			drawn = {
				mark = view.ruler:CreateTexture(nil, "ARTWORK"),
				label = ns.BoardText(view.ruler, fonts.tick, LOOK.group),
			}
			drawn.label:SetJustifyH("CENTER")
			view.ticks[i] = drawn
		end
		local x = TRACK_X + tick.x * TRACK_WIDTH
		local labelled = tick.label ~= nil
		drawn.mark:SetColorTexture(LOOK.group[1], LOOK.group[2], LOOK.group[3], labelled and 0.85 or 0.55)
		drawn.mark:SetSize(1, labelled and 11 or 6)
		at(drawn.mark, page, x - 0.5, labelled and TICK_Y or MINOR_Y)
		drawn.mark:Show()
		drawn.label:SetText(tick.label or "")
		drawn.label:ClearAllPoints()
		drawn.label:SetPoint("TOP", page, "TOPLEFT", x, -HOUR_Y)
		drawn.label:SetShown(labelled)
	end
	for i = #ruler.ticks + 1, #view.ticks do
		view.ticks[i].mark:Hide()
		view.ticks[i].label:Hide()
	end
	at(view.nowLine, page, TRACK_X + ruler.now * TRACK_WIDTH - 1, NOW_Y)
end

-- Draws the washes behind the list (HNT-R62): the next 3 hours (Soon) faintly amber, the night faintly blue.
---@param view TimelinePageView
---@param washes { kind: "soon"|"night", from: number, to: number }[]
local function drawWashes(view, washes)
	for i, wash in ipairs(washes) do
		local texture = ns.BoardPooled(view.washes, i, function()
			return view.column:CreateTexture(nil, "BACKGROUND")
		end)
		local soon = wash.kind == "soon"
		local color = soon and LOOK.soonWash or LOOK.nightWash
		texture:SetColorTexture(color[1], color[2], color[3], soon and LOOK.soonAlpha or LOOK.nightAlpha)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", wash.from * TRACK_WIDTH, 0)
		texture:SetPoint("BOTTOMLEFT", wash.from * TRACK_WIDTH, 0)
		texture:SetWidth(math.max(1, (wash.to - wash.from) * TRACK_WIDTH))
	end
	ns.BoardHideFrom(view.washes, #washes)
end

-- The margin label's ink by its case: red for Now, Soon and short of skill, faded for Later, blue for On demand.
local MARGIN_INK = { now = LOOK.red, soon = LOOK.red, short = LOOK.red, later = LOOK.faded, onDemand = LOOK.hand }

-- Places a row or a heading `y` down the list: it slides there (0.4 s, ease-in-out) from where it showed with
-- `slide`, else it is put there.
---@param region TimelineRowView|TimelineHeadingView
---@param y number
---@param slide boolean
local function moveTo(region, y, slide)
	local was = region:IsShown() and region.y
	region:Show()
	ns.StopMotion(region)
	if slide and was and was ~= y then
		ns.Animate(region, {
			{
				dur = SLIDE,
				ease = ns.Ease.inOut,
				keys = { { 0, { was } }, { 1, { y } } },
				apply = function(v)
					region.y = v[1]
					region:ClearAllPoints()
					region:SetPoint("TOPLEFT", 0, -v[1])
				end,
			},
		})
		return
	end
	region.y = y
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", 0, -y)
end

-- Flashes a row green: the Hunt has just opened.
---@param drawn TimelineRowView
local function flash(drawn)
	ns.StopMotion(drawn.flash)
	ns.Animate(drawn.flash, {
		{
			dur = FLASH,
			ease = ns.Ease.inOut,
			keys = { { 0, { 0 } }, { 0.25, { FLASH_PEAK } }, { 1, { 0 } } },
			apply = function(v)
				drawn.flash:SetAlpha(v[1])
			end,
		},
	})
end

-- Draws one Hunt's row (HNT-R63) at `y` down the list, sliding there with `slide`.
---@param view TimelinePageView
---@param drawn TimelineRowView
---@param row TimelineRow
---@param y number
---@param slide boolean
local function drawRow(view, drawn, row, y, slide)
	drawn.huntID = row.id
	moveTo(drawn, y, slide)
	drawn.shade:SetShown(row.selected)
	if row.selected then
		drawn.dashes:Dashed(LOOK.kicker, view.width, ROW_HEIGHT)
	else
		drawn.dashes:Hide()
	end
	drawn.icon:SetIcon(row.icon or ns.TRADE_FISHING, row.tint)
	drawn.icon:SetTrim(row.trim)
	drawn.pin:SetShown(row.pinned)
	drawn.name:SetText(row.name)
	for i, bar in ipairs(row.bars) do
		local barView = ns.BoardPooled(drawn.bars, i, function()
			return ns.NewBoardTimelineBar(drawn.track)
		end)
		barView:ClearAllPoints()
		barView:SetPoint("TOPLEFT", bar.from * TRACK_WIDTH, -7)
		barView:SetBar(bar.style, math.max(2, (bar.to - bar.from) * TRACK_WIDTH))
	end
	ns.BoardHideFrom(drawn.bars, #row.bars)
	drawn.note:SetText(row.note or "")
	drawn.note:SetShown(row.note ~= nil)
	drawn.margin:SetText(row.margin)
	local ink = MARGIN_INK[row.tone]
	drawn.margin:SetTextColor(ink[1], ink[2], ink[3])
end

-- Draws the groups down the list: each heading with its count, then its rows; hides what is left over. A list drawn at
-- the board's draw before this one has been on show since: its rows and headings slide to their new places, and a Hunt
-- that has moved into Now flashes, with the board's sound (MOTION.md › The live Hunts timeline).
---@param view TimelinePageView
---@param timeline HuntsTimeline
local function drawList(view, timeline)
	local serial = ns.board:Serial()
	local live = view.serial == serial - 1
	view.serial = serial
	local slide = live and ns.motion == true
	local y = 0
	local groupOf, headingsUsed, opened = {}, {}, false
	for _, group in ipairs(timeline.groups) do
		local heading = view.headings[group.group] or newHeading(view)
		view.headings[group.group] = heading
		headingsUsed[group.group] = true
		moveTo(heading, y, slide)
		heading.dot:SetGroup(group.group, true)
		heading.label:SetText(ns.BoardSmallCaps(group.name))
		heading.note:SetText(group.note)
		heading.count:SetText(tostring(group.count))
		-- the note stops before the count (measured unbounded)
		heading.note:SetWidth(0)
		local room = view.width - 17 - heading.label:GetStringWidth() - 8 - heading.count:GetStringWidth() - 8
		heading.note:SetWidth(math.max(1, math.min(heading.note:GetStringWidth() + 1, room)))
		y = y + HEADING_GAP + HEADING_HEIGHT
		for _, row in ipairs(group.rows) do
			local drawn = view.rows[row.id] or newRow(view)
			view.rows[row.id] = drawn
			local was = view.groupOf[row.id]
			groupOf[row.id] = group.group
			drawRow(view, drawn, row, y, slide)
			if live and was and was ~= "now" and group.group == "now" then
				opened = true
				if ns.motion then
					flash(drawn)
				end
			end
			y = y + ROW_HEIGHT
		end
	end
	for key, heading in pairs(view.headings) do
		if not headingsUsed[key] then
			heading:Hide()
		end
	end
	for huntID, drawn in pairs(view.rows) do
		if not groupOf[huntID] then
			ns.StopMotion(drawn)
			drawn:Hide()
		end
	end
	view.groupOf = groupOf
	view.content:SetHeight(math.max(1, y))
	view.placeThumb()
	if opened then
		ns.BoardSound("huntOpens")
	end
end

-- Draws the legend at the page's foot (HNT-R62): each bar style's own stroke, then its words in italic.
---@param view TimelinePageView
---@param page Frame
---@param items { style: BoardBarStyle, text: string }[]
local function drawLegend(view, page, items)
	local x = 0
	for i, item in ipairs(items) do
		local bar = ns.BoardPooled(view.legendBars, i, function()
			return ns.NewBoardTimelineBar(view.legend)
		end)
		bar:SetBar(item.style, LEGEND_BAR)
		at(bar, page, x, LEGEND_Y)
		local text = ns.BoardPooled(view.legendTexts, i, function()
			return ns.BoardText(view.legend, ns.BoardFonts().legend, LOOK.legend)
		end)
		text:SetText(item.text)
		at(text, page, x + LEGEND_BAR + LEGEND_GAP, LEGEND_Y - 1)
		x = x + LEGEND_BAR + LEGEND_GAP + text:GetStringWidth() + LEGEND_ITEM_GAP
	end
	ns.BoardHideFrom(view.legendBars, #items)
	ns.BoardHideFrom(view.legendTexts, #items)
end

-- Each left page's view, by its page frame: each mode has its own page (adapter/Board.lua).
---@type table<Frame, TimelinePageView>
local views = {}

--- Draws the timeline of `place` on `page` (a left page's renderer, ns.board:RegisterPage): on the Board it selects
--- the Hunt the timeline picks (HNT-R67) before the right page draws.
---@param page Frame
---@param place BoardPlace
local function drawPage(page, place)
	local view = views[page]
	if not view then
		view = build(page)
		views[page] = view
	end
	view.place = place
	local timeline = ns.BoardTimeline(place)
	if place.mode == "board" then
		ns.board:Select(timeline.selected)
	end
	local none = timeline.empty == "noHunts"
	view.title:SetText(timeline.title)
	view.kicker:SetText(
		ns.BoardSmallCaps(place.mode ~= "board" and place.set and ns.L.SET_KICKER or ns.L.TIMELINE_KICKER)
	)
	for _, part in ipairs({ view.ruler, view.column, view.scroll, view.legend, view.nowLine }) do
		part:SetShown(not none)
	end
	view.empty:SetText(none and ns.L.NO_HUNTS or "")
	view.empty:SetShown(none)
	if none then
		view.rail:Hide()
		view.thumb:Hide()
		view.serial = ns.board:Serial()
		view.groupOf = {}
		return
	end
	drawRuler(view, page, timeline.ruler)
	drawWashes(view, timeline.washes)
	drawList(view, timeline)
	drawLegend(view, page, timeline.legendItems)
end

for _, mode in ipairs(ns.BOARD_MODES) do
	ns.board:RegisterPage(mode, "left", drawPage)
end

-- The leather's realm clock (HNT-R61): the grouping's time, so it freezes with it in combat (HNT-R43), its date and
-- season from the live conditions, and "(paused in combat)" while the grouping is paused, in gilt.
---@type FontString?
local clockText

ns.board:RegisterLeather("clock", function(anchor)
	if not clockText then
		clockText = ns.BoardText(anchor, ns.BoardFonts().clock, LOOK.clock)
		clockText:SetPoint("RIGHT", -8, 0)
		clockText:SetJustifyH("RIGHT")
		clockText:SetWidth(anchor:GetWidth())
	end
	local snapshot = Pagle.GetConditions()
	local season = ns.SeasonNow(snapshot, Pagle.GetWindowSpec, Pagle.MatchesConditions)
	clockText:SetText(ns.TimelineClock(ns.ViewNow(), snapshot, season, ns.groups:IsPaused()))
end)

-- The leather's "show completed" box (HNT-R61, HNT-R82): the saved filter, which a click saves and redraws.
---@type BoardCheckButton?
local completed

ns.board:RegisterLeather("completed", function(anchor)
	if not completed then
		completed = ns.NewBoardCheck(anchor)
		completed:SetPoint("LEFT", 0, 0)
		completed.Text:SetText(ns.L.SHOW_COMPLETED)
		completed:SetScript("OnClick", function(self)
			self:Sync()
			local on = self:GetChecked() == true
			ns.BoardSound(on and "check" or "uncheck")
			ns.SetShowCompleted(on)
		end)
	end
	completed:SetChecked(ns.db.profile.showCompleted)
	completed:Sync()
end)
