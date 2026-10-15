if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The board's left page on the client (HNT-R61–R63, HNT-R66's left page, HNT-R67, HNT-R69): ns.BoardTimeline gathers
-- logic/Timeline.lua's inputs from the grouping, the projection, the names and Core, and this file draws the result
-- on the left page of every mode (the Board, a set's page, an entry opened from it), and the realm clock and the "show
-- completed" checkbox on the leather. On the Board it selects the Hunt HNT-R67 picks before the right page draws; the
-- entry's renderer (adapter/Entry.lua, #194) draws that Hunt, or HNT-R67's line when none is. The look follows
-- prototypes/hunts-board/ variant E in adapter/BoardWidgets.lua's art.
--
-- The checkbox is FrameXML's UICheckButtonTemplate (Gethe/wow-ui-source branch forever,
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/Shared/Button/
-- CheckButtonTemplates.xml, its label `Text`), as Core's Curio Shop uses it. An aura's expiry is
-- C_UnitAuras.GetPlayerAuraBySpellID's `expirationTime`, on GetTime's clock (HNT-R63).

local LOOK = ns.BOARD_LOOK

-- The page's layout, in pixels: the title, the ruler under it, the list scrolling under the ruler, the legend at the
-- foot; and each row's columns, as variant E's grid: name 172 px, the track, the margin label 66 px (narrower here,
-- the page being the board's own size).
local TITLE_HEIGHT, RULER_HEIGHT, LEGEND_HEIGHT = 30, 22, 30
local NAME_WIDTH, MARGIN_WIDTH, GAP = 150, 74, 6
local ROW_HEIGHT, HEADING_HEIGHT, BAR_HEIGHT, ICON_SIZE = 26, 22, 12, 18
-- Bars made with each row before its now line, so the line draws over them.
local BARS_AHEAD = 3
-- The trims' tiers on a board icon (HNT-R18).
local TRIM_TIER = { bronze = 1, silver = 2, gold = 3 }

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

--- The time the timeline, the clock, the entry, a set's page and the tracker draw at: now, or while the grouping is
--- paused the grouping's time, so they freeze with it (HNT-R43). Between regroups a grouping's windows stand (it regroups at every edge, HNT-R42), so
--- now's countdowns and ruler read right from it however long ago it was made.
---@return integer
function ns.TimelineNow()
	local grouped = ns.groups:Time()
	if grouped and ns.groups:IsPaused() then
		return grouped
	end
	return GetServerTime()
end

--- The timeline the left page of `place` draws (logic/Timeline.lua): the Board's, or a set's when the place has one
--- and isn't the Board (HNT-R66), at ns.TimelineNow() (frozen while the grouping is paused, HNT-R43), with the saved
--- "show completed" filter (HNT-R82; while updating it hides nothing, HNT-R69).
---@param place BoardPlace
---@return HuntsTimeline
function ns.BoardTimeline(place)
	local now = ns.TimelineNow()
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
		best = Pagle.GetAngler().bestBaseSkill,
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
---@field highlight Texture
---@field icon BoardIconView
---@field pin Texture
---@field name FontString
---@field track Frame
---@field bars BoardTimelineBarView[]
---@field note FontString
---@field nowLine Texture
---@field margin FontString
---@field huntID string

---@class TimelineHeadingView: Frame
---@field label FontString
---@field count FontString
---@field rule Texture

---@class TimelinePageView
---@field title FontString
---@field ruler Frame
---@field ticks { mark: Texture, label: FontString }[]
---@field nowLabel FontString
---@field nowLine Texture
---@field column Frame          -- the track's column behind the list, for the washes
---@field washes Texture[]
---@field scroll ScrollFrame
---@field content Frame
---@field rows TimelineRowView[]
---@field headings TimelineHeadingView[]
---@field legend FontString
---@field empty FontString
---@field width number
---@field trackLeft number
---@field trackWidth number
---@field place BoardPlace

-- A row: the icon with its trim and pin mark, the name, the track with its bars and the now line, the margin label.
---@param view TimelinePageView
---@return TimelineRowView
local function newRow(view)
	local row = CreateFrame("Button", nil, view.content) --[[@as TimelineRowView]]
	row:SetSize(view.width, ROW_HEIGHT)
	row.highlight = ns.BoardSolid(row, LOOK.barFill, "BACKGROUND", 0.14)
	row.icon = ns.NewBoardIcon(row, ICON_SIZE)
	row.icon:SetPoint("LEFT", 6, 0)
	-- The pin mark: a red-ink pin head over the icon's corner.
	row.pin = row:CreateTexture(nil, "OVERLAY")
	row.pin:SetTexture(ns.BOARD_TEXTURES.disc)
	row.pin:SetVertexColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	row.pin:SetSize(8, 8)
	row.pin:SetPoint("CENTER", row.icon, "TOPLEFT", 0, 0)
	row.name = ns.BoardText(row, ns.BoardFonts().text, LOOK.title)
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.name:SetWidth(NAME_WIDTH - ICON_SIZE - 16)
	row.name:SetWordWrap(false)
	row.track = CreateFrame("Frame", nil, row)
	row.track:SetSize(view.trackWidth, ROW_HEIGHT)
	row.track:SetPoint("LEFT", view.trackLeft, 0)
	row.bars = {}
	for i = 1, BARS_AHEAD do
		row.bars[i] = ns.NewBoardTimelineBar(row.track, BAR_HEIGHT)
	end
	row.note = ns.BoardText(row.track, ns.BoardFonts().small, LOOK.faded)
	row.note:SetPoint("LEFT", 4, 0)
	local over = CreateFrame("Frame", nil, row.track)
	over:SetAllPoints()
	row.nowLine = ns.BoardSolid(over, LOOK.red, "OVERLAY", 0.85)
	row.nowLine:SetWidth(2)
	row.margin = ns.BoardText(row, ns.BoardFonts().margin, LOOK.red)
	row.margin:SetPoint("RIGHT", -2, 0)
	row.margin:SetWidth(MARGIN_WIDTH)
	row.margin:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		clicked(view.place, self.huntID)
	end)
	return row
end

-- A group's heading: its words, its row count at the right, and a rule under it.
---@param view TimelinePageView
---@return TimelineHeadingView
local function newHeading(view)
	local heading = CreateFrame("Frame", nil, view.content) --[[@as TimelineHeadingView]]
	heading:SetSize(view.width, HEADING_HEIGHT)
	heading.label = ns.BoardText(heading, ns.BoardFonts().small, LOOK.kicker)
	heading.label:SetPoint("BOTTOMLEFT", 2, 4)
	heading.count = ns.BoardText(heading, ns.BoardFonts().small, LOOK.faded)
	heading.count:SetPoint("BOTTOMRIGHT", -2, 4)
	heading.count:SetJustifyH("RIGHT")
	heading.rule = heading:CreateTexture(nil, "BORDER")
	heading.rule:SetColorTexture(LOOK.note[1], LOOK.note[2], LOOK.note[3], 0.5)
	heading.rule:SetHeight(1)
	heading.rule:SetPoint("BOTTOMLEFT", 0, 1)
	heading.rule:SetPoint("BOTTOMRIGHT", 0, 1)
	return heading
end

-- The page's frames, made at its first draw: the title, the ruler, the washes' column, the scrolling list, the legend,
-- and the line that stands alone when no Hunt is current.
---@param page Frame
---@return TimelinePageView
local function build(page)
	local width = page:GetWidth()
	local fonts = ns.BoardFonts()
	local trackLeft = NAME_WIDTH + GAP
	local trackWidth = width - NAME_WIDTH - MARGIN_WIDTH - 2 * GAP

	local title = ns.BoardText(page, fonts.title, LOOK.title)
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetWidth(width)

	local ruler = CreateFrame("Frame", nil, page)
	ruler:SetSize(trackWidth, RULER_HEIGHT)
	ruler:SetPoint("TOPLEFT", trackLeft, -TITLE_HEIGHT)
	local base = ruler:CreateTexture(nil, "BORDER")
	base:SetColorTexture(LOOK.kicker[1], LOOK.kicker[2], LOOK.kicker[3], 1)
	base:SetHeight(2)
	base:SetPoint("BOTTOMLEFT")
	base:SetPoint("BOTTOMRIGHT")
	local nowLine = ns.BoardSolid(ruler, LOOK.red, "ARTWORK", 0.85)
	nowLine:SetSize(2, RULER_HEIGHT)
	local nowLabel = ns.BoardText(ruler, fonts.margin, LOOK.red)
	nowLabel:SetText(ns.L.RULER_NOW)

	local listTop = TITLE_HEIGHT + RULER_HEIGHT + 2
	local column = CreateFrame("Frame", nil, page)
	column:SetPoint("TOPLEFT", trackLeft, -listTop)
	column:SetPoint("BOTTOMLEFT", trackLeft, LEGEND_HEIGHT)
	column:SetSize(trackWidth, page:GetHeight() - listTop - LEGEND_HEIGHT)

	local scroll = CreateFrame("ScrollFrame", nil, page) --[[@as ScrollFrame]]
	scroll:SetPoint("TOPLEFT", 0, -listTop)
	scroll:SetPoint("BOTTOMRIGHT", 0, LEGEND_HEIGHT)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width, 1)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local offset = self:GetVerticalScroll() - delta * 40
		self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
	end)

	local legend = ns.BoardText(page, fonts.small, LOOK.note)
	legend:SetPoint("BOTTOMLEFT", 0, 0)
	legend:SetWidth(width)
	legend:SetHeight(LEGEND_HEIGHT - 4)
	legend:SetText(ns.L.TIMELINE_LEGEND)

	local empty = ns.BoardText(page, fonts.hand, LOOK.hand)
	empty:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
	empty:SetWidth(width)

	---@type TimelinePageView
	return {
		title = title,
		ruler = ruler,
		ticks = {},
		nowLabel = nowLabel,
		nowLine = nowLine,
		column = column,
		washes = {},
		scroll = scroll,
		content = content,
		rows = {},
		headings = {},
		legend = legend,
		empty = empty,
		width = width,
		trackLeft = trackLeft,
		trackWidth = trackWidth,
		place = { mode = "board" },
	}
end

-- Draws the ruler (HNT-R62): its hour ticks, the labelled ones' times, and the now line with "now" over it.
---@param view TimelinePageView
---@param ruler TimelineRuler
local function drawRuler(view, ruler)
	local width = view.trackWidth
	for i, tick in ipairs(ruler.ticks) do
		local drawn = view.ticks[i]
		if not drawn then
			drawn = {
				mark = view.ruler:CreateTexture(nil, "BORDER"),
				label = ns.BoardText(view.ruler, ns.BoardFonts().small, LOOK.note),
			}
			drawn.mark:SetColorTexture(LOOK.note[1], LOOK.note[2], LOOK.note[3], 1)
			drawn.label:SetJustifyH("CENTER")
			view.ticks[i] = drawn
		end
		drawn.mark:ClearAllPoints()
		drawn.mark:SetPoint("BOTTOMLEFT", tick.x * width, 0)
		drawn.mark:SetSize(1, tick.label and 6 or 3)
		drawn.mark:Show()
		drawn.label:ClearAllPoints()
		drawn.label:SetPoint("BOTTOM", view.ruler, "BOTTOMLEFT", tick.x * width, 6)
		drawn.label:SetText(tick.label or "")
		drawn.label:SetShown(tick.label ~= nil)
	end
	for i = #ruler.ticks + 1, #view.ticks do
		view.ticks[i].mark:Hide()
		view.ticks[i].label:Hide()
	end
	view.nowLine:ClearAllPoints()
	view.nowLine:SetPoint("BOTTOMLEFT", ruler.now * width - 1, 0)
	view.nowLabel:ClearAllPoints()
	view.nowLabel:SetPoint("BOTTOM", view.ruler, "BOTTOMLEFT", ruler.now * width, 2)
end

-- Draws the washes behind the list (HNT-R62): the Soon wash in red ink, the night's in blue, both faint.
---@param view TimelinePageView
---@param washes { kind: "soon"|"night", from: number, to: number }[]
local function drawWashes(view, washes)
	local width = view.trackWidth
	for i, wash in ipairs(washes) do
		local texture = view.washes[i]
		if not texture then
			texture = view.column:CreateTexture(nil, "BACKGROUND")
			view.washes[i] = texture
		end
		local color = wash.kind == "soon" and LOOK.soonWash or LOOK.nightWash
		texture:SetColorTexture(color[1], color[2], color[3], LOOK.washAlpha)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", wash.from * width, 0)
		texture:SetPoint("BOTTOMLEFT", wash.from * width, 0)
		texture:SetWidth(math.max(1, (wash.to - wash.from) * width))
		texture:Show()
	end
	for i = #washes + 1, #view.washes do
		view.washes[i]:Hide()
	end
end

-- The margin label's ink by its case (variant E): red for Now, Soon and short of skill, faded for Later, blue for On
-- demand.
local MARGIN_INK = { now = LOOK.red, soon = LOOK.red, short = LOOK.red, later = LOOK.faded, onDemand = LOOK.hand }

-- Draws one Hunt's row (HNT-R63) at `y` down the list.
---@param view TimelinePageView
---@param drawn TimelineRowView
---@param row TimelineRow
---@param nowX number
---@param y number
local function drawRow(view, drawn, row, nowX, y)
	drawn.huntID = row.id
	drawn:ClearAllPoints()
	drawn:SetPoint("TOPLEFT", 0, -y)
	drawn.highlight:SetShown(row.selected)
	local tint = row.tint and { row.tint.r, row.tint.g, row.tint.b }
	drawn.icon:SetIcon(row.icon or "Interface\\Icons\\Trade_Fishing", tint)
	drawn.icon:SetTrim(row.trim and TRIM_TIER[row.trim])
	drawn.pin:SetShown(row.pinned)
	drawn.name:SetText(row.name)
	local width = view.trackWidth
	for i, bar in ipairs(row.bars) do
		local barView = drawn.bars[i]
		if not barView then
			barView = ns.NewBoardTimelineBar(drawn.track, BAR_HEIGHT)
			drawn.bars[i] = barView
		end
		barView:ClearAllPoints()
		barView:SetPoint("LEFT", bar.from * width, 0)
		barView:SetBar(bar.style, math.max(2, (bar.to - bar.from) * width))
		barView:Show()
	end
	for i = #row.bars + 1, #drawn.bars do
		drawn.bars[i]:Hide()
	end
	drawn.note:SetText(row.note or "")
	drawn.note:SetShown(row.note ~= nil)
	drawn.nowLine:ClearAllPoints()
	drawn.nowLine:SetPoint("TOPLEFT", nowX * width - 1, 0)
	drawn.nowLine:SetPoint("BOTTOMLEFT", nowX * width - 1, 0)
	drawn.margin:SetText(row.margin)
	local ink = MARGIN_INK[row.tone]
	drawn.margin:SetTextColor(ink[1], ink[2], ink[3])
	drawn:Show()
end

-- Draws the groups down the list: each heading with its count, then its rows; hides what is left over.
---@param view TimelinePageView
---@param timeline HuntsTimeline
local function drawList(view, timeline)
	local y, rowsUsed = 0, 0
	for i, group in ipairs(timeline.groups) do
		local heading = view.headings[i] or newHeading(view)
		view.headings[i] = heading
		heading:ClearAllPoints()
		heading:SetPoint("TOPLEFT", 0, -y)
		heading.label:SetText(group.heading)
		heading.count:SetText(tostring(group.count))
		heading:Show()
		y = y + HEADING_HEIGHT
		for _, row in ipairs(group.rows) do
			rowsUsed = rowsUsed + 1
			local drawn = view.rows[rowsUsed] or newRow(view)
			view.rows[rowsUsed] = drawn
			drawRow(view, drawn, row, timeline.ruler.now, y)
			y = y + ROW_HEIGHT
		end
	end
	for i = #timeline.groups + 1, #view.headings do
		view.headings[i]:Hide()
	end
	for i = rowsUsed + 1, #view.rows do
		view.rows[i]:Hide()
	end
	view.content:SetHeight(math.max(1, y))
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
	view.ruler:SetShown(not none)
	view.column:SetShown(not none)
	view.scroll:SetShown(not none)
	view.legend:SetShown(not none)
	view.empty:SetText(none and ns.L.NO_HUNTS or "")
	view.empty:SetShown(none)
	if none then
		return
	end
	drawRuler(view, timeline.ruler)
	drawWashes(view, timeline.washes)
	drawList(view, timeline)
end

for _, mode in ipairs(ns.BOARD_MODES) do
	ns.board:RegisterPage(mode, "left", drawPage)
end

-- The leather's realm clock (HNT-R61): the grouping's time, so it freezes with it in combat (HNT-R43), its date and
-- season from the live conditions, and "(paused in combat)" while the grouping is paused.
---@type FontString?
local clockText

ns.board:RegisterLeather("clock", function(anchor)
	if not clockText then
		clockText = ns.BoardText(anchor, ns.BoardFonts().clock, LOOK.gilt)
		clockText:SetPoint("RIGHT", -8, 0)
		clockText:SetJustifyH("RIGHT")
		clockText:SetWidth(anchor:GetWidth())
	end
	local snapshot = Pagle.GetConditions()
	local season = ns.SeasonNow(snapshot, Pagle.GetWindowSpec, Pagle.MatchesConditions)
	clockText:SetText(ns.TimelineClock(ns.TimelineNow(), snapshot, season, ns.groups:IsPaused()))
end)

-- The leather's "show completed" checkbox (HNT-R61, HNT-R82): the saved filter, which a click saves and redraws.
---@class TimelineCheckButton: CheckButton
---@field Text FontString UICheckButtonTemplate's label

---@type TimelineCheckButton?
local completed

ns.board:RegisterLeather("completed", function(anchor)
	if not completed then
		completed = CreateFrame("CheckButton", nil, anchor, "UICheckButtonTemplate") --[[@as TimelineCheckButton]]
		completed:SetSize(22, 22)
		completed:SetPoint("LEFT", 0, 0)
		completed.Text:SetFontObject(ns.BoardFonts().clock)
		completed.Text:SetTextColor(LOOK.gilt[1], LOOK.gilt[2], LOOK.gilt[3])
		completed.Text:SetPoint("LEFT", completed, "RIGHT", 2, 0)
		completed.Text:SetText(ns.L.SHOW_COMPLETED)
		completed:SetScript("OnClick", function(self)
			ns.SetShowCompleted(self:GetChecked() == true)
		end)
	end
	completed:SetChecked(ns.db.profile.showCompleted)
end)
