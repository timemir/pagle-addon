if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Pagle Wagers on the Board spread (HNT-R160, HNT-R161, HNT-R163, HNT-R164): gathers logic/Wagers.lua's inputs from
-- the runs the board shows (ns.RunsShown), the projection, the names and Core, and draws two of its pieces: the wager
-- strip, which adapter/Timeline.lua places above the timeline's ruler on the Board, and a run's entry, which
-- adapter/Entry.lua draws on the Board's right page while a run is selected. The WAGERS group's rows are the
-- timeline's own (adapter/Timeline.lua). The Pagle Wagers spread (#303) reuses the run's entry through
-- ns.DrawRunEntry and the strip's data through ns.BoardTimeline.
--
-- The look is the books art kit's, after prototype variant B (prototypes/hunts-board/wagers/ on branch
-- prototype/hunts-wagers): the strip a pinned slip of paper with an oxblood edge, its pips the kit's tier marks; the
-- entry set in the Hunt entry's parts (the wax seal, the zone chips, the tier marks). Nothing here moves: the strip and
-- the entry settle at once, and the rows slide with the timeline's own motion (HNT-R60, HNT-R62).

local LOOK = ns.BOARD_LOOK

--- logic/Wagers.lua's inputs, read now: the runs on and ahead at ns.ViewNow() (frozen while the grouping is paused,
--- HNT-R43), the live conditions, and whether the projection is updating (HNT-R69).
---@return WagersInput
function ns.BoardWagersInput()
	local now = ns.ViewNow()
	return {
		runs = ns.RunsShown(ns.State(), now),
		now = now,
		snapshot = Pagle.GetConditions(),
		updating = ns.IsUpdating(),
		list = ns.hunts,
		sources = ns.names,
	}
end

-- The run `runKey` among the runs `input` shows, or nil.
---@param input WagersInput
---@param runKey string
---@return HuntsShownRun?
local function shownRun(input, runKey)
	for _, shown in ipairs(input.runs) do
		if shown.key == runKey then
			return shown
		end
	end
	return nil
end

--- A run's entry (HNT-R163) as data, for one of the runs the board shows; nil for a run it doesn't (ended, HNT-R143).
---@param runKey string
---@return RunEntry?
function ns.BoardRunEntry(runKey)
	local input = ns.BoardWagersInput()
	local shown = shownRun(input, runKey)
	return shown and ns.BuildRunEntry(input, shown) or nil
end

--- A run's event's name, for the breadcrumbs (HNT-R164): from the runs the board shows, else the event ID in its key.
---@param runKey string
---@return string
function ns.BoardRunName(runKey)
	local shown = shownRun(ns.BoardWagersInput(), runKey)
	if shown and ns.events then
		return ns.events:EventName(shown.event)
	end
	return runKey:match("^(.-)@") or runKey
end

-- The wager strip ----------------------------------------------------------------------------------------------------

-- The strip's measures, in UI units down the timeline's page: its top under the title, its height, its oxblood edge,
-- its words' inset and rows, a pip's size and step, and the room the companion hint's line takes under it.
local STRIP_Y, STRIP_HEIGHT, EDGE, INSET, KICKER_ROW, NAME_ROW = 47, 38, 4, 14, 5, 19
local PIP, PIP_STEP, GAP, HINT_HEIGHT = 10, 13, 10, 18
--- How far the strip pushes the ruler and the list down the page, with the hint's line under it or not.
ns.WAGER_STRIP_ROOM, ns.WAGER_HINT_ROOM = STRIP_HEIGHT + 8, HINT_HEIGHT

---@class WagerPip: BoardDiamondView
---@field pip true
---@field inked boolean

---@class WagerStripButton: Button
---@field stripRun string?   -- the run it names: a click opens the Pagle Wagers spread on it

---@class WagerStripView
---@field button WagerStripButton
---@field kicker FontString
---@field more FontString
---@field name FontString
---@field closes FontString
---@field updating FontString
---@field pips WagerPip[]
---@field hint FontString
---@field width number

-- The strip's widgets on `page`, made at its first draw.
---@param page Frame
---@return WagerStripView
local function newStrip(page)
	local fonts, width = ns.BoardFonts(), page:GetWidth()
	local button = CreateFrame("Button", nil, page) --[[@as WagerStripButton]]
	button:SetSize(width, STRIP_HEIGHT)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -STRIP_Y)
	ns.BoardSolid(button, LOOK.stripPaper, "BACKGROUND")
	local edge = ns.BoardSolid(button, LOOK.oxblood, "BORDER")
	edge:ClearAllPoints()
	edge:SetPoint("TOPLEFT")
	edge:SetSize(EDGE, STRIP_HEIGHT)
	button:SetScript("OnClick", function(self)
		ns.OpenWagers(self.stripRun)
	end)
	local function text(font, color, x, y, right)
		local made = ns.BoardText(button, font, color)
		made:SetWordWrap(false)
		if right then
			made:SetJustifyH("RIGHT")
			made:SetPoint("TOPRIGHT", button, "TOPRIGHT", -x, -y)
		else
			made:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
		end
		return made
	end
	local view = {
		button = button,
		kicker = text(fonts.kicker, LOOK.kicker, INSET, KICKER_ROW),
		more = text(fonts.note, LOOK.note, GAP, KICKER_ROW - 2, true),
		name = text(fonts.text, LOOK.title, INSET, NAME_ROW),
		closes = text(fonts.count, LOOK.red, GAP, NAME_ROW - 3, true),
		updating = text(fonts.note, LOOK.note, GAP, NAME_ROW, true),
		pips = {},
		hint = ns.BoardText(page, fonts.note, LOOK.note),
		width = width,
	}
	view.hint:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, -(STRIP_Y + STRIP_HEIGHT + 3))
	view.hint:SetWidth(width - INSET)
	view.hint:SetWordWrap(false)
	return view
end

-- Each timeline page's strip, by its page frame.
---@type table<Frame, WagerStripView>
local strips = {}

-- Sets `text` to `words` and keeps it within `room`, cut short with an ellipsis past it; returns the width it takes.
---@param text FontString
---@param words string
---@param room number
---@return number
local function fit(text, words, room)
	text:SetText(words)
	text:SetWidth(0)
	local width = math.max(1, math.min(math.ceil(text:GetStringWidth()) + 1, room))
	text:SetWidth(width)
	text:Show()
	return width
end

--- Draws the wager strip (HNT-R161) on the timeline's page `page`, or hides it with none (HNT-R204), and returns how
--- far it pushes the ruler down: none without a strip, more with the companion hint's line under it (#305 fills it).
---@param page Frame
---@param strip WagerStrip?
---@return number
function ns.DrawWagerStrip(page, strip)
	local view = strips[page]
	if not strip then
		if view then
			view.button:Hide()
			view.hint:Hide()
		end
		return 0
	end
	if not view then
		view = newStrip(page)
		strips[page] = view
	end
	local L = ns.L
	view.button:Show()
	view.button.stripRun = strip.run
	view.kicker:SetText(ns.BoardSmallCaps(strip.kicker))
	local room = view.width - INSET - GAP
	-- the kicker's row: "+{n} more on the table" at its right
	local kickerWidth = math.ceil(view.kicker:GetStringWidth())
	if strip.more then
		fit(view.more, strip.more, room - kickerWidth - GAP)
	else
		view.more:Hide()
	end
	-- the name's row: the pips (or the updating line) and the countdown at its right, the name in the room left
	local right = 0
	if strip.closes then
		right = fit(view.closes, strip.closes, room / 3)
	else
		view.closes:Hide()
	end
	local pips = strip.pips or {}
	for i, inked in ipairs(pips) do
		local pip = ns.BoardPooled(view.pips, i, function()
			local made = ns.NewBoardDiamond(view.button, PIP) --[[@as WagerPip]]
			made.pip = true
			return made
		end)
		pip.inked = inked
		pip:SetDiamond("bronze", inked)
		pip:ClearAllPoints()
		pip:SetPoint(
			"TOPRIGHT",
			view.button,
			"TOPRIGHT",
			-(GAP + right + GAP + (#pips - i) * PIP_STEP),
			-(NAME_ROW + 3)
		)
		pip:Show()
	end
	ns.BoardHideFrom(view.pips, #pips)
	if #pips > 0 then
		right = right + GAP + #pips * PIP_STEP
	end
	if strip.updating then
		view.updating:ClearAllPoints()
		view.updating:SetPoint("TOPRIGHT", view.button, "TOPRIGHT", -(GAP + right + GAP), -NAME_ROW)
		right = right + GAP + fit(view.updating, strip.updating, room / 2)
	else
		view.updating:Hide()
	end
	local words = strip.next or L.STRIP_NAME:format(strip.name or "", strip.zones or "")
	fit(view.name, words, room - right - GAP)
	if strip.hint then
		view.hint:SetText(strip.hint)
		view.hint:Show()
		return ns.WAGER_STRIP_ROOM + ns.WAGER_HINT_ROOM
	end
	view.hint:Hide()
	return ns.WAGER_STRIP_ROOM
end

-- A run's entry ----------------------------------------------------------------------------------------------------

-- The entry's measures down the right page (as adapter/Entry.lua's): the kicker and the name, the seal's size and
-- where its centre sits from the page's top right, the room the heading leaves it and the least room the heading
-- takes; a Hunt's block (its name row, its line, its marks' row), a mark's size and step, and the gaps.
local KICKER_Y, NAME_Y, SEAL_SIZE, SEAL_RIGHT, SEAL_DOWN, HEADING_ROOM, HEAD_ROOM = 3, 19, 88, 38.5, 39.5, 96, 92
local HUNT_GAP, MARK, MARK_STEP, THRESHOLD_X, PROGRESS_WIDTH, CHIP_GAP, CHIP_HEIGHT = 7, 12, 40, 16, 80, 5, 22

---@class RunEntryHuntView
---@field name FontString
---@field progress FontString
---@field line FontString
---@field updating FontString
---@field marks BoardDiamondView[]
---@field thresholds FontString[]

---@class RunEntryView
---@field page Frame
---@field kicker FontString
---@field name FontString
---@field until_ FontString
---@field seal BoardSealView
---@field chips EntryChipView[]
---@field note FontString
---@field hunts RunEntryHuntView[]
---@field casts FontString
---@field soFar FontString
---@field payRule FontString
---@field shown boolean

-- Each right page's run entry, by its page frame.
---@type table<Frame, RunEntryView>
local entries = {}

-- The run entry's widgets on `page`, made at its first draw.
---@param page Frame
---@return RunEntryView
local function newEntry(page)
	local fonts, width = ns.BoardFonts(), page:GetWidth()
	local function text(font, color, wrapWidth, spacing)
		local made = ns.BoardText(page, font, color)
		if wrapWidth then
			ns.BoardWrap(made, wrapWidth, spacing or 2)
		end
		return made
	end
	local heading = width - HEADING_ROOM
	local view = {
		page = page,
		kicker = text(fonts.kicker, LOOK.kicker),
		name = text(fonts.title, LOOK.title, heading, 2),
		until_ = text(fonts.hand, LOOK.red, heading, 2),
		seal = ns.NewBoardSeal(page, SEAL_SIZE),
		chips = {},
		note = text(fonts.hand, LOOK.hand, width, 2),
		hunts = {},
		casts = text(fonts.note, LOOK.count, width, 4),
		soFar = text(fonts.small, LOOK.red, width, 4),
		payRule = text(ns.ArtFont("italic", 11.5), LOOK.note, width, 3),
		shown = false,
	}
	view.kicker:SetWidth(heading)
	view.kicker:SetWordWrap(false)
	view.seal:SetPoint("CENTER", page, "TOPLEFT", width - SEAL_RIGHT, -SEAL_DOWN)
	return view
end

-- A Hunt's block in the entry: its name and its "{count} / {next}" at the right, its shape and target line, its marks.
---@param view RunEntryView
---@return RunEntryHuntView
local function newHunt(view)
	local fonts, page, width = ns.BoardFonts(), view.page, view.page:GetWidth()
	local hunt = {
		name = ns.BoardText(page, fonts.text, LOOK.title),
		progress = ns.BoardText(page, fonts.count, LOOK.hand),
		line = ns.BoardText(page, fonts.note, LOOK.small),
		updating = ns.BoardText(page, fonts.note, LOOK.note),
		marks = {},
		thresholds = {},
	}
	hunt.name:SetWidth(width - PROGRESS_WIDTH - 6)
	hunt.name:SetWordWrap(false)
	hunt.progress:SetWidth(PROGRESS_WIDTH)
	hunt.progress:SetJustifyH("RIGHT")
	hunt.progress:SetWordWrap(false)
	for _, line in ipairs({ hunt.line, hunt.updating }) do
		line:SetWidth(width)
		line:SetWordWrap(false)
	end
	return hunt
end

-- Every widget of the entry, and its pools'.
---@param view RunEntryView
---@return Region[]
local function widgetsOf(view)
	---@type Region[]
	local all = { view.kicker, view.name, view.until_, view.seal, view.note, view.casts, view.soFar, view.payRule }
	for _, chip in ipairs(view.chips) do
		all[#all + 1] = chip
	end
	for _, hunt in ipairs(view.hunts) do
		for _, widget in ipairs({ hunt.name, hunt.progress, hunt.line, hunt.updating }) do
			all[#all + 1] = widget
		end
		for _, pool in ipairs({ hunt.marks, hunt.thresholds }) do
			for _, widget in ipairs(pool) do
				all[#all + 1] = widget
			end
		end
	end
	return all
end

--- Hides the run's entry on `page`, if it has one: the right page shows a Hunt's entry instead.
---@param page Frame
function ns.HideRunEntry(page)
	local view = entries[page]
	if view and view.shown then
		view.shown = false
		for _, widget in ipairs(widgetsOf(view)) do
			widget:Hide()
		end
	end
end

-- Lays a text at the page's left `x`, `y` down with its words; returns the y below it, `after` further down.
---@param text FontString
---@param words string?
---@param y number
---@param after number?
---@param x number?
---@return number
local function line(text, words, y, after, x)
	if not words then
		text:Hide()
		return y
	end
	text:SetText(words)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", x or 0, -y)
	text:Show()
	return y + text:GetStringHeight() + (after or 2)
end

-- Lays a Hunt's block from `y` down (HNT-R163): its name with its count toward the next mark at the right, its line,
-- then its tier marks with their thresholds, filled once reached (HNT-R64, HNT-R18); or the updating line (HNT-R69).
---@param view RunEntryView
---@param i integer
---@param data RunEntryHunt
---@param y number
---@return number
local function layHunt(view, i, data, y)
	local hunt = view.hunts[i] or newHunt(view)
	view.hunts[i] = hunt
	local ladder = data.ladder
	line(hunt.progress, ladder.bar and ladder.bar.label, y, 0, view.page:GetWidth() - PROGRESS_WIDTH)
	y = line(hunt.name, data.name, y, 1)
	y = line(hunt.line, data.line, y, 3)
	if ladder.updating then
		ns.BoardHideFrom(hunt.marks, 0)
		ns.BoardHideFrom(hunt.thresholds, 0)
		return line(hunt.updating, ladder.updating, y, HUNT_GAP)
	end
	hunt.updating:Hide()
	local fonts = ns.BoardFonts()
	for k, step in ipairs(ladder.tiers or {}) do
		local mark = ns.BoardPooled(hunt.marks, k, function()
			return ns.NewBoardDiamond(view.page, MARK)
		end)
		mark:SetDiamond(ns.Trim(step.tier), step.reached)
		mark:ClearAllPoints()
		mark:SetPoint("TOPLEFT", (k - 1) * MARK_STEP, -y)
		mark:Show()
		local threshold = ns.BoardPooled(hunt.thresholds, k, function()
			return ns.BoardText(view.page, fonts.small, LOOK.title)
		end)
		local ink = step.reached and LOOK.title or LOOK.note
		threshold:SetTextColor(ink[1], ink[2], ink[3])
		line(threshold, tostring(step.threshold), y - 1, 0, (k - 1) * MARK_STEP + THRESHOLD_X)
	end
	ns.BoardHideFrom(hunt.marks, #(ladder.tiers or {}))
	ns.BoardHideFrom(hunt.thresholds, #(ladder.tiers or {}))
	return y + MARK + HUNT_GAP
end

-- Lays the zone chips in a row from `y`; returns the y below them.
---@param view RunEntryView
---@param chips HuntEntryChip[]
---@param y number
---@return number
local function layChips(view, chips, y)
	local width, x = view.page:GetWidth(), 0
	for i, data in ipairs(chips) do
		local chip = ns.BoardPooled(view.chips, i, function()
			return ns.NewEntryChip(view.page)
		end)
		local chipWidth = ns.SetEntryChip(chip, data, width)
		if x > 0 and x + chipWidth > width then
			x, y = 0, y + CHIP_HEIGHT + CHIP_GAP
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, -y)
		chip:Show()
		x = x + chipWidth + CHIP_GAP
	end
	ns.BoardHideFrom(view.chips, #chips)
	return #chips > 0 and y + CHIP_HEIGHT or y
end

--- Draws run `runKey`'s entry (HNT-R163) on the right page `page`, top to bottom, as adapter/Entry.lua lays a Hunt's:
--- the kicker, the name, "until …" in the hand and the seal at the top right, the zone chips, the note in the hand,
--- each Hunt's block, the Casts, the sums and the pay rule in small italic. No pin toggle and no set line. Returns
--- false, drawing nothing, for a run the board doesn't show.
---@param page Frame
---@param runKey string
---@return boolean
function ns.DrawRunEntry(page, runKey)
	local entry = ns.BoardRunEntry(runKey)
	if not entry then
		ns.HideRunEntry(page)
		return false
	end
	local view = entries[page]
	if not view then
		view = newEntry(page)
		entries[page] = view
	end
	view.shown = true
	view.seal:SetSeal(entry.seal.text, entry.seal.filled)
	view.seal:Show()
	local y = line(view.kicker, ns.BoardSmallCaps(entry.kicker), KICKER_Y, 0)
	y = line(view.name, entry.name, math.max(y, NAME_Y), 2)
	y = line(view.until_, entry.until_, y, 4)
	y = layChips(view, entry.chips, math.max(y, HEAD_ROOM)) + 8
	y = line(view.note, entry.note, y, 8)
	for i, hunt in ipairs(entry.hunts) do
		y = layHunt(view, i, hunt, y)
	end
	for i = #entry.hunts + 1, #view.hunts do
		local hunt = view.hunts[i]
		for _, widget in ipairs({ hunt.name, hunt.progress, hunt.line, hunt.updating }) do
			widget:Hide()
		end
		ns.BoardHideFrom(hunt.marks, 0)
		ns.BoardHideFrom(hunt.thresholds, 0)
	end
	y = line(view.casts, entry.casts, y + 2, 2)
	y = line(view.soFar, entry.soFar, y, 6)
	line(view.payRule, entry.payRule, y)
	return true
end
