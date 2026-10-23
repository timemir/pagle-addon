if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Pagle Wagers on the Board spread (HNT-R160, HNT-R161, HNT-R163, HNT-R164): gathers logic/Wagers.lua's inputs from
-- the runs the board shows (ns.RunsShown), the projection, the names and Core, and draws the wager strip, which
-- adapter/Timeline.lua places above the timeline's ruler on the Board. A run's entry, which adapter/Entry.lua draws on
-- the Board's right page while a run is selected and the Pagle Wagers spread on its own, is adapter/WagersEntry.lua's
-- ns.DrawRunEntry, from ns.BoardRunEntry here. The WAGERS group's rows are the timeline's own (adapter/Timeline.lua).
--
-- The strip's look is the books art kit's, after prototype variant B (prototypes/hunts-board/wagers/ on branch
-- prototype/hunts-wagers): a pinned slip of paper with an oxblood edge, its pips the kit's tier marks. Nothing here
-- moves: the strip settles at once, and the rows slide with the timeline's own motion (HNT-R60, HNT-R62).

local LOOK = ns.BOARD_LOOK

--- logic/Wagers.lua's inputs, read now: the runs on and ahead at ns.ViewNow() (frozen while the grouping is paused,
--- HNT-R43), the live conditions, whether the projection is updating (HNT-R69), the companion hint while it applies
--- (HNT-R170, adapter/Companion.lua), and the Angler's best skill for "needs skill {n}" (HNT-R156).
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
		hint = ns.CompanionHintNow(),
		best = Pagle.GetAngler().bestBaseSkill,
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
-- its words' inset and rows, a pip's size and step; the companion hint's gap under it and between its lines.
local STRIP_Y, STRIP_HEIGHT, EDGE, INSET, KICKER_ROW, NAME_ROW = 47, 38, 4, 14, 5, 19
local PIP, PIP_STEP, GAP, HINT_TOP, HINT_SPACING = 10, 13, 10, 3, 2
--- How far the strip pushes the ruler and the list down the page, and the least room the companion hint takes under
--- it beside: its lines' heights and spacing are added to it (HNT-R161, HNT-R170).
ns.WAGER_STRIP_ROOM, ns.WAGER_HINT_ROOM = STRIP_HEIGHT + 8, 4

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
---@field hint Frame                    -- the companion hint under the strip (HNT-R170)
---@field hintLines FontString[]
---@field hintButtons CompanionHintButtons -- Get it and Dismiss, at its first line's right
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
		hint = CreateFrame("Frame", nil, page),
		hintLines = {},
		width = width,
	}
	view.hint:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, -(STRIP_Y + STRIP_HEIGHT + HINT_TOP))
	view.hint:SetSize(width - INSET, 1)
	view.hint:Hide()
	view.hintButtons = ns.NewHintButtons(view.hint)
	return view
end

-- Each timeline page's strip, by its page frame.
---@type table<Frame, WagerStripView>
local strips = {}

-- Draws the companion hint's `lines` under the strip (HNT-R161, HNT-R170), each wrapping in the room Get it and
-- Dismiss leave at its first line's right, or hides it for none; returns the room it takes down the page.
---@param view WagerStripView
---@param lines string[]?
---@return number
local function drawHint(view, lines)
	if not lines then
		view.hint:Hide()
		ns.HideHintButtons(view.hintButtons)
		return 0
	end
	local width = view.width - INSET
	view.hint:Show()
	local buttons = ns.PlaceHintButtons(view.hintButtons, view.hint, GAP, 0)
	local y = 0
	for i, words in ipairs(lines) do
		local line = ns.BoardPooled(view.hintLines, i, function()
			return ns.BoardText(view.hint, ns.BoardFonts().note, LOOK.note)
		end)
		line:SetText(words)
		ns.BoardWrap(line, width - GAP - buttons - GAP, 0)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", 0, -y)
		line:Show()
		y = y + math.ceil(line:GetStringHeight()) + HINT_SPACING
	end
	ns.BoardHideFrom(view.hintLines, #lines)
	view.hint:SetHeight(math.max(1, y))
	return y + ns.WAGER_HINT_ROOM
end

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
--- far it pushes the ruler down: none without a strip, more with the companion hint's lines under it (HNT-R170).
---@param page Frame
---@param strip WagerStrip?
---@return number
function ns.DrawWagerStrip(page, strip)
	local view = strips[page]
	if not strip then
		if view then
			view.button:Hide()
			drawHint(view, nil)
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
	return ns.WAGER_STRIP_ROOM + drawHint(view, strip.hint)
end
