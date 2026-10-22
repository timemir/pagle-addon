if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Pagle Wagers spread (HNT-R162), the board's "wagers" mode (logic/Board.lua): gathers logic/Wagers.lua's spread
-- from the runs the board shows, the projection and the runs that ended while the board was open, and draws it: the
-- wager slips and the ladder on the left page, the chosen run's entry on the right (adapter/Wagers.lua's
-- ns.DrawRunEntry). Its ribbon is adapter/Sets.lua's, counting the runs on through ns.BoardRunsOn. Defines
-- ns.OpenWagers (logic/Seams.lua).
--
-- The look is the books art kit's, after prototype variant A (prototypes/hunts-board/wagers/ on branch
-- prototype/hunts-wagers): each slip a slip of paper pinned on the page with an oxblood edge, its pips the kit's tier
-- marks as on the wager strip, a settled slip stamped in red; the ladder under a rule at the page's foot, its marks'
-- numbers over their titles and the kit's ink bar. Nothing here moves but the page turn to and from the spread (HNT-R60).

local LOOK = ns.BOARD_LOOK

-- Runs that ended while the board was open (HNT-R143, HNT-R162) ---------------------------------------------------------

-- The runs on seen this showing of the board (ns.board:Showing()), by run key: a run among them that has ended since
-- shows as a closed slip until the board closes.
---@type { showing: integer?, runs: table<string, HuntsShownRun> }
local seen = { showing = nil, runs = {} }

-- The runs seen, begun again for a new showing.
---@return table<string, HuntsShownRun>
local function seenRuns()
	local showing = ns.board:Showing()
	if seen.showing ~= showing then
		seen.showing, seen.runs = showing, {}
	end
	return seen.runs
end

--- How many runs are on (HNT-R162's "{n} on"). While the board shows, it notes them as seen this showing: the
--- ribbons draw at every board draw, so every run on while the board is open is noted.
---@return integer
function ns.BoardRunsOn()
	local shown = ns.board:IsShown()
	local runs = shown and seenRuns() or nil
	local on = 0
	for _, run in ipairs(ns.BoardWagersInput().runs) do
		if run.on then
			on = on + 1
			if runs then
				runs[run.key] = run
			end
		end
	end
	return on
end

-- The runs seen on this showing that have ended by `now`, with their progress as the projection now holds it.
---@param now integer
---@return HuntsShownRun[]
local function endedThisShowing(now)
	local state = ns.State()
	local ended = {}
	for key, shown in pairs(seenRuns()) do
		local run = state.runs and state.runs[key] or shown.run
		if run.end_ <= now then
			ended[#ended + 1] = { key = key, run = run, event = shown.event, on = false }
		end
	end
	return ended
end

--- The Pagle Wagers spread's left page (HNT-R162) as data, `runKey` the slip chosen (BoardPlace.run).
---@param runKey string?
---@return WagersSpread
function ns.BoardWagersSpread(runKey)
	local input = ns.BoardWagersInput()
	local state = ns.State()
	return ns.BuildWagersSpread(input, {
		settled = state.settled or 0,
		ladder = state.ladder or {},
		ended = endedThisShowing(input.now),
		run = runKey,
		-- hint: the companion hint's lines for the placeholder slip (HNT-R170), #305's to fill
	})
end

--- Opens the board on the Pagle Wagers spread (HNT-R162), with run `runKey`'s slip chosen if given; open, it turns
--- there and never closes. A run the spread no longer shows chooses the first slip's.
---@param runKey string?
function ns.OpenWagers(runKey)
	ns.board:Open({ mode = "wagers", run = runKey })
end

-- The left page ------------------------------------------------------------------------------------------------------

-- The page's measures, in UI units down its body: the kicker, the title and the note; where the slips start, a slip's
-- height and the gap after it, its words' inset, rows and the pips' size and step; the ladder's height at the foot.
local KICKER_Y, TITLE_Y, NOTE_Y, SLIPS_Y = 3, 19, 54, 82
local SLIP_HEIGHT, SLIP_GAP, EDGE, INSET, GAP = 58, 8, 4, 14, 10
local NAME_ROW, WHERE_ROW, MARKS_ROW, PIP, PIP_STEP = 7, 26, 41, 10, 13
local STAMP_HEIGHT, HINT_LINE = 22, 16
local LADDER_HEIGHT, LADDER_NUMBER_Y, LADDER_TITLE_Y, LADDER_BAR_Y, LADDER_LINE_Y = 84, 9, 27, 48, 63

---@class WagerSlipView: Button
---@field slipRun string      -- its run key: a click chooses it
---@field closed boolean
---@field selected boolean
---@field edge Texture
---@field outline BoardOutline
---@field name FontString
---@field when FontString
---@field where FontString
---@field marks FontString
---@field tag FontString
---@field stamp Frame
---@field stampText FontString
---@field stampOutline BoardOutline
---@field pips WagerPip[]

---@class WagersSpreadView
---@field kicker FontString
---@field title FontString
---@field note FontString
---@field empty FontString
---@field more FontString
---@field slips WagerSlipView[]
---@field hint Frame
---@field hintOutline BoardOutline
---@field hintLines FontString[]
---@field rule Texture
---@field numbers FontString[]
---@field titles FontString[]
---@field bar BoardInkBarView
---@field line FontString

---@class WagersSpreadPage: Frame
---@field spread WagersSpreadView?

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

-- A one-line text on `parent` in `font` and `color`.
---@param parent Frame
---@param font Font
---@param color number[]
---@return FontString
local function text(parent, font, color)
	local made = ns.BoardText(parent, font, color)
	made:SetWordWrap(false)
	return made
end

-- A slip's widgets on `page`, `width` wide.
---@param page Frame
---@param width number
---@return WagerSlipView
local function newSlip(page, width)
	local fonts = ns.BoardFonts()
	local slip = CreateFrame("Button", nil, page) --[[@as WagerSlipView]]
	slip:SetSize(width, SLIP_HEIGHT)
	ns.BoardSolid(slip, LOOK.stripPaper, "BACKGROUND")
	slip.edge = ns.BoardSolid(slip, LOOK.oxblood, "BORDER")
	slip.edge:ClearAllPoints()
	slip.edge:SetPoint("TOPLEFT")
	slip.edge:SetSize(EDGE, SLIP_HEIGHT)
	slip.outline = ns.BoardOutline(slip, 0, "BORDER", 1)
	slip.name = text(slip, ns.ArtFont("print", 16), LOOK.title)
	slip.name:SetPoint("TOPLEFT", INSET, -NAME_ROW)
	slip.when = text(slip, fonts.count, LOOK.red)
	slip.when:SetJustifyH("RIGHT")
	slip.when:SetPoint("TOPRIGHT", -GAP, -(NAME_ROW - 3))
	slip.where = text(slip, fonts.note, LOOK.small)
	slip.where:SetPoint("TOPLEFT", INSET, -WHERE_ROW)
	slip.marks = text(slip, ns.ArtFont("italic", 12), LOOK.legend)
	slip.tag = text(slip, ns.ArtFont("italic", 12), LOOK.setName)
	slip.tag:SetJustifyH("RIGHT")
	slip.tag:SetPoint("TOPRIGHT", -GAP, -MARKS_ROW)
	-- the stamp: "SETTLED" in red inside a red rule, at the slip's top right
	slip.stamp = CreateFrame("Frame", nil, slip)
	slip.stamp:SetPoint("TOPRIGHT", -GAP, -GAP)
	slip.stampOutline = ns.BoardOutline(slip.stamp, 0, "BORDER")
	slip.stampOutline:Solid(LOOK.red, 1, 2)
	slip.stampText = text(slip.stamp, ns.BoardFonts().tier, LOOK.red)
	slip.stampText:SetPoint("CENTER", 0, 0)
	slip.pips = {}
	slip:SetScript("OnClick", function(self)
		if not self.closed then
			ns.OpenWagers(self.slipRun)
		end
	end)
	return slip
end

-- Fills `slip` from `data`.
---@param slip WagerSlipView
---@param data WagerSlip
local function fillSlip(slip, data)
	local width = slip:GetWidth()
	local room = width - INSET - GAP
	slip.slipRun, slip.closed, slip.selected = data.run, data.closed, data.selected
	slip:SetAlpha(data.closed and 0.6 or 1)
	local edge = data.closed and LOOK.faded or LOOK.oxblood
	slip.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
	if data.selected then
		slip.outline:Solid(LOOK.oxblood, 0.8, 1.5)
	else
		slip.outline:Hide()
	end
	local ink = data.closed and LOOK.faded or LOOK.title
	slip.name:SetTextColor(ink[1], ink[2], ink[3])
	-- the name's row: the countdown (or "opens …", "closed") or the stamp at its right, the name in the room left
	local right = 0
	if data.when then
		local tone = data.tone == "red" and LOOK.red or data.tone == "note" and LOOK.note or LOOK.faded
		slip.when:SetTextColor(tone[1], tone[2], tone[3])
		right = fit(slip.when, data.when, room / 2)
	else
		slip.when:Hide()
	end
	if data.settled then
		slip.stampText:SetText(ns.BoardSmallCaps(data.settled))
		local stampWidth = math.ceil(slip.stampText:GetStringWidth()) + 12
		slip.stamp:SetSize(stampWidth, STAMP_HEIGHT)
		slip.stamp:Show()
		right = math.max(right, stampWidth)
	else
		slip.stamp:Hide()
	end
	fit(slip.name, data.name, room - (right > 0 and right + GAP or 0))
	fit(slip.where, data.where, room - (data.settled and right + GAP or 0))
	-- the marks' row: the pips, "{done} of {n} first marks", and a holiday tag in the margin at its right
	local pips = data.pips or {}
	for i, inked in ipairs(pips) do
		local pip = ns.BoardPooled(slip.pips, i, function()
			local made = ns.NewBoardDiamond(slip, PIP) --[[@as WagerPip]]
			made.pip = true
			return made
		end)
		pip.inked = inked
		pip:SetDiamond("bronze", inked)
		pip:ClearAllPoints()
		pip:SetPoint("TOPLEFT", INSET + (i - 1) * PIP_STEP, -(MARKS_ROW + 1))
	end
	ns.BoardHideFrom(slip.pips, #pips)
	local marksX = INSET + (#pips > 0 and #pips * PIP_STEP + 4 or 0)
	local tagWidth = data.tag and fit(slip.tag, data.tag, room / 2) or 0
	if not data.tag then
		slip.tag:Hide()
	end
	slip.marks:ClearAllPoints()
	slip.marks:SetPoint("TOPLEFT", marksX, -MARKS_ROW)
	fit(slip.marks, data.marks, width - marksX - GAP - (tagWidth > 0 and tagWidth + GAP or 0))
end

-- The spread's widgets on `page`, made once.
---@param page WagersSpreadPage
---@return WagersSpreadView
local function viewOf(page)
	if page.spread then
		return page.spread
	end
	local fonts, width = ns.BoardFonts(), page:GetWidth()
	local view = {
		kicker = text(page, fonts.kicker, LOOK.kicker),
		title = text(page, fonts.title, LOOK.title),
		note = ns.BoardText(page, fonts.note, LOOK.note),
		empty = ns.BoardText(page, fonts.note, LOOK.note),
		more = text(page, fonts.note, LOOK.note),
		slips = {},
		hint = CreateFrame("Frame", nil, page),
		hintLines = {},
		rule = ns.BoardSolid(page, LOOK.rule, "ARTWORK"),
		numbers = {},
		titles = {},
		bar = ns.NewBoardInkBar(page, width),
		line = text(page, fonts.note, LOOK.count),
	}
	view.kicker:SetPoint("TOPLEFT", 0, -KICKER_Y)
	view.kicker:SetWidth(width)
	view.title:SetPoint("TOPLEFT", 0, -TITLE_Y)
	view.title:SetWidth(width)
	view.note:SetPoint("TOPLEFT", 0, -NOTE_Y)
	ns.BoardWrap(view.note, width, 2)
	ns.BoardWrap(view.empty, width, 2)
	view.more:SetWidth(width)
	view.hint:SetSize(width, SLIP_HEIGHT)
	view.hintOutline = ns.BoardOutline(view.hint, 0, "BORDER")
	view.rule:ClearAllPoints()
	view.rule:SetSize(width, 1)
	view.line:SetWidth(width)
	local column = width / #ns.LADDER_STEPS
	for i in ipairs(ns.LADDER_STEPS) do
		local number = text(page, ns.ArtFont("print", 15), LOOK.title)
		local title = text(page, ns.ArtFont("italic", 11.5), LOOK.count)
		for _, words in ipairs({ number, title }) do
			words:SetJustifyH("CENTER")
			words:SetWidth(column - 8)
		end
		view.numbers[i], view.titles[i] = number, title
	end
	page.spread = view
	return view
end

-- Lays the ladder at the page's foot (HNT-R162): a rule, three marks with their numbers over their titles (an earned
-- one's number in red), the ink bar toward the next mark, and its line.
---@param page Frame
---@param view WagersSpreadView
---@param ladder WagersLadder
local function layLadder(page, view, ladder)
	local width = page:GetWidth()
	local top = page:GetHeight() - LADDER_HEIGHT
	view.rule:SetPoint("TOPLEFT", 0, -top)
	view.rule:Show()
	local column = width / #ladder.marks
	for i, mark in ipairs(ladder.marks) do
		local number, title = view.numbers[i], view.titles[i]
		local ink = mark.reached and LOOK.red or LOOK.title
		number:SetTextColor(ink[1], ink[2], ink[3])
		number:SetText(tostring(mark.step))
		number:ClearAllPoints()
		number:SetPoint("TOPLEFT", (i - 1) * column + 4, -(top + LADDER_NUMBER_Y))
		number:Show()
		title:SetText(mark.title)
		title:ClearAllPoints()
		title:SetPoint("TOPLEFT", (i - 1) * column + 4, -(top + LADDER_TITLE_Y))
		title:Show()
	end
	view.bar:ClearAllPoints()
	view.bar:SetPoint("TOPLEFT", 0, -(top + LADDER_BAR_Y))
	view.bar:SetBar(ladder.fill)
	view.bar:Show()
	view.line:SetText(ladder.line)
	view.line:ClearAllPoints()
	view.line:SetPoint("TOPLEFT", 0, -(top + LADDER_LINE_Y))
	view.line:Show()
end

-- Lays the companion hint's dashed placeholder slip (HNT-R170) at `y`, #305's lines in it; returns the y below it.
---@param page Frame
---@param view WagersSpreadView
---@param lines string[]?
---@param y number
---@return number
local function layHint(page, view, lines, y)
	if not lines then
		view.hint:Hide()
		ns.BoardHideFrom(view.hintLines, 0)
		return y
	end
	local width = page:GetWidth()
	local height = 2 * GAP + #lines * HINT_LINE
	view.hint:SetSize(width, height)
	view.hint:ClearAllPoints()
	view.hint:SetPoint("TOPLEFT", 0, -y)
	view.hintOutline:Dashed(LOOK.note, width, height)
	view.hint:Show()
	for i, words in ipairs(lines) do
		local line = ns.BoardPooled(view.hintLines, i, function()
			return text(view.hint, ns.BoardFonts().note, LOOK.note)
		end)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", INSET, -(GAP + (i - 1) * HINT_LINE))
		fit(line, words, width - 2 * INSET)
	end
	ns.BoardHideFrom(view.hintLines, #lines)
	return y + height + SLIP_GAP
end

-- The spread's left page (HNT-R162): kicker, title and note; a slip per run, as many as fit above the ladder, then
-- "+{n} more on the table" for the rest; the hint's placeholder slip; HNT-R204's line with none; the ladder at the
-- foot. Clicking an open slip chooses it.
---@param page WagersSpreadPage
---@param place BoardPlace
local function drawSpread(page, place)
	local view = viewOf(page)
	local data = ns.BoardWagersSpread(place.run)
	view.kicker:SetText(ns.BoardSmallCaps(data.kicker))
	view.title:SetText(data.title)
	view.note:SetText(data.note)
	local width = page:GetWidth()
	local room = page:GetHeight() - LADDER_HEIGHT - SLIP_GAP - SLIPS_Y
	local hintRoom = data.hint and (2 * GAP + #data.hint * HINT_LINE + SLIP_GAP) or 0
	local fits = math.max(0, math.floor((room - hintRoom + SLIP_GAP) / (SLIP_HEIGHT + SLIP_GAP)))
	local shown = #data.slips
	if shown > fits then
		shown = math.max(0, fits - 1) -- the last slot reads "+{n} more on the table"
	end
	local y = SLIPS_Y
	for i = 1, shown do
		local slip = ns.BoardPooled(view.slips, i, function()
			return newSlip(page, width)
		end)
		slip:ClearAllPoints()
		slip:SetPoint("TOPLEFT", 0, -y)
		fillSlip(slip, data.slips[i])
		y = y + SLIP_HEIGHT + SLIP_GAP
	end
	ns.BoardHideFrom(view.slips, shown)
	if shown < #data.slips then
		view.more:SetText(ns.L.STRIP_MORE:format(#data.slips - shown))
		view.more:ClearAllPoints()
		view.more:SetPoint("TOPLEFT", INSET, -y)
		view.more:Show()
		y = y + SLIP_HEIGHT + SLIP_GAP
	else
		view.more:Hide()
	end
	if data.empty then
		view.empty:SetText(data.empty)
		view.empty:ClearAllPoints()
		view.empty:SetPoint("TOPLEFT", 0, -y)
		view.empty:Show()
		y = y + view.empty:GetStringHeight() + SLIP_GAP
	else
		view.empty:Hide()
	end
	layHint(page, view, data.hint, y)
	layLadder(page, view, data.ladder)
end

-- The spread's right page: the chosen run's entry (HNT-R163), or nothing with no slip.
---@param page Frame
---@param place BoardPlace
local function drawEntry(page, place)
	local selected = ns.BoardWagersSpread(place.run).selected
	if not (selected and ns.DrawRunEntry(page, selected)) then
		ns.HideRunEntry(page)
	end
end

ns.board:RegisterPage("wagers", "left", drawSpread)
ns.board:RegisterPage("wagers", "right", drawEntry)
