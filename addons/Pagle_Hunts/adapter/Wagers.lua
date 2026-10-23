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
-- The strip's look is the Pagle Wagers kit's (data/art/wagers/art.json, the Wagers atlas, adapter/WagersArt.lua's
-- inks), as #375's prototype laid it on one line (version A2): the spread's wager ticket at the strip's height, its
-- stub's time dial without words, the event mark, the name and its zones, the pips or the SETTLED stamp, and "closes
-- in …" in the hand; a run ahead the spread's dashed row. Nothing here moves: the strip settles at once, and the rows
-- slide with the timeline's own motion (HNT-R60, HNT-R62, HNT-R167).

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

-- The strip's measures, in UI units down the timeline's page: its top under the title and its height; the companion
-- hint's inset, its gap under the strip and between its lines, and the gap before Get it and Dismiss.
local STRIP_Y, STRIP_HEIGHT, INSET, GAP, HINT_TOP, HINT_SPACING = 47, 38, 14, 10, 3, 2
-- The ticket (data/art/wagers/art.json › ticket), drawn at the strip's height: its measures are the spread's ticket's
-- (52 high) times K, as #375's prototype laid it (version A2). Its three-slice's caps, in the sprite's own units; the
-- stub's dial (its left, and its size); the event mark's left and size; the name's left.
local K = STRIP_HEIGHT / 52
local CAP_L, CAP_R, DIAL_X, DIAL_SIZE, MARK_X, MARK_SIZE, NAME_X = 62, 12, 4 * K, 42 * K, 58 * K, 26, 102 * K
-- From the right: "closes in …" at the pips' inset and the gap before the pips; a pip's size and gap; the stamp's
-- width; the gap before "+{n} more"; the room kept before what sits at the right; the gap before the zones and the
-- zones' drop under the name's line.
local RIGHT, CLOSES_GAP, PIP, PIP_GAP, STAMP_W, MORE_GAP, NAME_GAP, ZONES_GAP, ZONES_DROP =
	11.5, 10, 8, 5, 96 * K, 10, 12, 8, 1
--- How far the strip pushes the ruler and the list down the page, and the least room the companion hint takes under
--- it beside: its lines' heights and spacing are added to it (HNT-R161, HNT-R170).
ns.WAGER_STRIP_ROOM, ns.WAGER_HINT_ROOM = STRIP_HEIGHT + 8, 4

---@class WagerPip: Frame
---@field pip true
---@field inked boolean
---@field mark HuntsSpriteTexture

---@class WagerStripButton: Button
---@field stripRun string?   -- the run it names: a click opens the Pagle Wagers spread on it
---@field settled boolean?   -- the SETTLED stamp shows
---@field urgent boolean?    -- "closes in …" in the now line's red

---@class WagerStripView
---@field button WagerStripButton         -- a run on: the one-line ticket
---@field paper HuntsThreeSlice
---@field dial WagerDialView
---@field mark WagerMarkView
---@field name WagerText
---@field zones WagerText
---@field more WagerText
---@field closes FontString
---@field updating WagerText
---@field pips WagerPip[]
---@field stampFrame Frame
---@field stamp HuntsSpriteTexture
---@field ahead WagerAheadView?           -- none on: the spread's dashed row for the first run ahead, made at need
---@field hint Frame                    -- the companion hint under the strip (HNT-R170)
---@field hintLines FontString[]
---@field hintButtons CompanionHintButtons -- Get it and Dismiss, at its first line's right
---@field width number

-- The strip's widgets on `page`, made at its first draw.
---@param page Frame
---@return WagerStripView
local function newStrip(page)
	local width = page:GetWidth()
	local button = CreateFrame("Button", nil, page) --[[@as WagerStripButton]]
	button:SetSize(width, STRIP_HEIGHT)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -STRIP_Y)
	button:SetScript("OnClick", function(self)
		ns.OpenWagers(self.stripRun)
	end)
	local paper = CreateFrame("Frame", nil, button) --[[@as HuntsThreeSlice]]
	paper:SetPoint("TOPLEFT")
	-- under the ticket's own words and marks, which a frame at its level might draw beneath
	paper:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
	ns.SetThreeSliceAt(paper, "Wagers", "ticket", width, STRIP_HEIGHT, CAP_L, CAP_R, "BACKGROUND")
	local dial = ns.NewWagerDial(button, DIAL_SIZE)
	dial:SetPoint("TOPLEFT", DIAL_X, -(STRIP_HEIGHT - DIAL_SIZE) / 2)
	local mark = ns.NewEventMark(button, MARK_SIZE)
	mark:SetPoint("TOPLEFT", MARK_X, -(STRIP_HEIGHT - MARK_SIZE) / 2)
	local closes = ns.BoardText(button, ns.BoardFonts().count, LOOK.red)
	closes:SetWordWrap(false)
	closes:SetJustifyH("RIGHT")
	local stampFrame = CreateFrame("Frame", nil, button)
	stampFrame:SetSize(1, 1)
	local view = {
		button = button,
		paper = paper,
		dial = dial,
		mark = mark,
		name = ns.NewWagerText(button, "tkName"),
		zones = ns.NewWagerText(button, "tkLine"),
		more = ns.NewWagerText(button, "secCaption"),
		closes = closes,
		updating = ns.NewWagerText(button, "tkMarks"),
		pips = {},
		stampFrame = stampFrame,
		stamp = ns.WagerSprite(stampFrame, "stamp-settled", STAMP_W, "OVERLAY"),
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

-- The width `text` takes with `words` in it, at no limit.
---@param text WagerText
---@param words string
---@return number
local function natural(text, words)
	ns.SetWagerWords(text, words)
	text:SetWidth(0)
	return math.ceil(text:GetStringWidth()) + 1
end

-- Puts a one-line wager text with its line's middle on the strip's, its left `x` in (or with `right` its right),
-- `drop` lower.
---@param text WagerText
---@param button Frame
---@param x number
---@param right boolean?
---@param drop number?
local function centred(text, button, x, right, drop)
	ns.PlaceWagerText(text, button, x, (STRIP_HEIGHT - ns.WagerLineHeight(text.ink)) / 2 + (drop or 0), right)
end

-- Draws the right of the ticket (HNT-R161): "closes in …" in the hand, then before it the pips over nothing, the
-- SETTLED stamp, or "updating…". Returns how far in from the strip's right they reach.
---@param view WagerStripView
---@param strip WagerStrip
---@return number
local function drawRight(view, strip)
	local button, width = view.button, view.width
	local closes = view.closes
	closes:SetText(strip.closes or "")
	closes:SetWidth(0)
	local closesWidth = math.min(math.ceil(closes:GetStringWidth()) + 1, width / 3)
	closes:SetWidth(closesWidth)
	local ink = strip.urgent and LOOK.nowLine or LOOK.red
	closes:SetTextColor(ink[1], ink[2], ink[3])
	closes:ClearAllPoints()
	closes:SetPoint("RIGHT", button, "TOPRIGHT", -RIGHT, -STRIP_HEIGHT / 2)
	closes:Show()
	button.urgent = strip.urgent
	local right = RIGHT + closesWidth + CLOSES_GAP
	-- the pips, inked bronze at a first mark
	local pips = strip.pips or {}
	for i, inked in ipairs(pips) do
		local pip = ns.BoardPooled(view.pips, i, function()
			local made = CreateFrame("Frame", nil, button) --[[@as WagerPip]]
			made:SetSize(PIP, PIP)
			made.pip = true
			made.mark = ns.ArtSprite(made, "Parts", "tier-off", "ARTWORK", 0, PIP)
			return made
		end)
		pip.inked = inked
		ns.SetSprite(pip.mark, "Parts", inked and "tier-on" or "tier-off", PIP)
		ns.PlaceSprite(pip.mark, pip, 0, 0)
		ns.TintWager(pip.mark, inked and LOOK.tierInks.bronze or LOOK.note)
		pip:ClearAllPoints()
		pip:SetPoint(
			"TOPLEFT",
			button,
			"TOPLEFT",
			width - right - (#pips - i + 1) * PIP - (#pips - i) * PIP_GAP,
			-(STRIP_HEIGHT - PIP) / 2
		)
		pip:Show()
	end
	ns.BoardHideFrom(view.pips, #pips)
	local used = #pips > 0 and #pips * PIP + (#pips - 1) * PIP_GAP or 0
	-- or the SETTLED stamp, red
	button.settled = strip.settled == true
	if strip.settled then
		view.stampFrame:ClearAllPoints()
		view.stampFrame:SetPoint("CENTER", button, "TOPRIGHT", -(right + STAMP_W / 2), -STRIP_HEIGHT / 2)
		ns.SetSprite(view.stamp, "Wagers", "stamp-settled", STAMP_W)
		ns.CenterSprite(view.stamp, view.stampFrame)
		view.stampFrame:Show()
		used = STAMP_W + 2
	else
		view.stampFrame:Hide()
	end
	-- or, while the projection updates, its word
	if strip.updating then
		used = ns.FitWagerText(view.updating, strip.updating, width / 3)
		centred(view.updating, button, right, true)
	else
		view.updating:Hide()
	end
	return right + used
end

-- Draws a run on's one-line ticket (HNT-R161): the paper, the stub's wordless dial, the mark, and on its line the name,
-- then the zones and "+{n} more on the table" as the fit rule leaves room for them (ns.WagerStripFit).
---@param view WagerStripView
---@param strip WagerStrip
local function drawTicket(view, strip)
	local button = view.button
	button:Show()
	button.stripRun = strip.run
	view.dial:SetDial(strip.dial --[[@as WagerDial]])
	view.mark:SetMark(strip.mark --[[@as string[] ]])
	local right = drawRight(view, strip)
	local room = view.width - right - NAME_GAP - NAME_X
	local fit = ns.WagerStripFit({
		room = room,
		name = natural(view.name, strip.name or ""),
		more = strip.more and natural(view.more, strip.more) + MORE_GAP or 0,
		zones = strip.zones and natural(view.zones, strip.zones) + ZONES_GAP or 0,
	})
	local nameWidth = ns.FitWagerText(view.name, strip.name or "", fit.name)
	centred(view.name, button, NAME_X)
	if fit.zones then
		ns.FitWagerText(view.zones, strip.zones --[[@as string]], fit.zones - ZONES_GAP)
		centred(view.zones, button, NAME_X + nameWidth + ZONES_GAP, false, ZONES_DROP)
	else
		view.zones:Hide()
	end
	if fit.more then
		ns.FitWagerText(view.more, strip.more --[[@as string]], room)
		centred(view.more, button, right + MORE_GAP, true)
	else
		view.more:Hide()
	end
end

--- Draws the wager strip (HNT-R161) on the timeline's page `page`, or hides it with none (HNT-R204), and returns how
--- far it pushes the ruler down: none without a strip, more with the companion hint's lines under it (HNT-R170). A run
--- on is the Pagle Wagers kit's ticket on one line; with none on, the first run ahead is the spread's dashed row
--- (adapter/WagersSpread.lua's). Nothing on it moves (HNT-R167).
---@param page Frame
---@param strip WagerStrip?
---@return number
function ns.DrawWagerStrip(page, strip)
	local view = strips[page]
	if not strip then
		if view then
			view.button:Hide()
			if view.ahead then
				view.ahead:Hide()
			end
			drawHint(view, nil)
		end
		return 0
	end
	if not view then
		view = newStrip(page)
		strips[page] = view
	end
	if strip.ahead then
		view.button:Hide()
		if not view.ahead then
			view.ahead = ns.NewWagerAheadRow(page, view.width)
			view.ahead:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -STRIP_Y)
		end
		ns.FillWagerAheadRow(view.ahead, strip.ahead)
		view.ahead:Show()
	else
		if view.ahead then
			view.ahead:Hide()
		end
		drawTicket(view, strip)
	end
	return ns.WAGER_STRIP_ROOM + drawHint(view, strip.hint)
end
