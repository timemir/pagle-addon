if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Pagle Wagers spread (HNT-R162), the board's "wagers" mode (logic/Board.lua): gathers logic/WagersSpread.lua's
-- left page from the runs the board shows, the projection and the runs that ended while the board was open, and draws
-- it: the closing note, the hint slip, the wager tickets, the rows ahead and the ladder's rail on the left page, the
-- chosen run's entry on the right (adapter/WagersEntry.lua's ns.DrawRunEntry). Its ribbon is adapter/Sets.lua's,
-- counting the runs on through ns.BoardRunsOn. Defines ns.OpenWagers (logic/Seams.lua).
--
-- The look is the Wagers redesign's variant A, the Bookmaker's Ledger (data/art/wagers/art.json, the Wagers atlas,
-- adapter/WagersArt.lua's inks): each run on a perforated ticket with its time dial in the stub and its event mark, a
-- settled one stamped SETTLED; each run ahead a dashed row; the ladder a rail with its posts and the Angler's token.
-- Two things move, only with Animations on: the stamp pressed as a run settles while its ticket shows, and the token
-- sliding as the settled count changes while the spread shows (HNT-R162's motion). The dial never does (HNT-R167).

local LOOK = ns.BOARD_LOOK

-- Runs that ended while the board was open (HNT-R143, HNT-R162) ---------------------------------------------------------

-- The runs on seen this showing of the board (ns.board:Showing()), by run key: a run among them that has ended since
-- shows as a closed ticket until the board closes.
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

--- The Pagle Wagers spread's left page (HNT-R162) as data, `runKey` the run chosen (BoardPlace.run).
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
		hint = input.hint and input.hint.lines, -- the hint slip's, while the hint applies (HNT-R170)
	})
end

--- Opens the board on the Pagle Wagers spread (HNT-R162), with run `runKey` chosen if given; open, it turns there and
--- never closes. A run the spread no longer shows chooses the first run's.
---@param runKey string?
function ns.OpenWagers(runKey)
	ns.board:Open({ mode = "wagers", run = runKey })
end

-- The left page ------------------------------------------------------------------------------------------------------

-- The page's measures (data/art/wagers/art.json › left), in UI units down its body: the kicker, the title, the
-- closing note's place from the right and its width, its arrow's, and the note.
local KICKER_Y, TITLE_Y, CLOSING_R, CLOSING_Y, CLOSING_W = 0, 17, 1, 1.5, 172
local ARROW_R, ARROW_Y, ARROW_W, NOTE_Y = 65, 35.6, 60, 48.3
-- A section's heading: the gap above, its height and the gap below; its label's, count's, rule's and caption's places.
local SECTION_GAP, SECTION_H, SECTION_BELOW, LABEL_Y, COUNT_GAP, RULE_GAP, RULE_Y, CAPTION_Y = 9, 16, 5, 3, 7, 7, 7.5, 5
-- A ticket's step and height, a row ahead's; the hint slip's gaps; the empty box's gap above, height and parts.
local TICKET_STEP, TICKET_H, AHEAD_STEP, AHEAD_H, HINT_ABOVE, HINT_BELOW = 57, 52, 42, 38, 10, 2
local EMPTY_GAP, EMPTY_H, EMPTY_MARK, EMPTY_MARK_SIZE, EMPTY_TEXT_X, EMPTY_TEXT_R = 16, 88, 17, 54, 85, 17
-- "+{n} more on the table": its height; rows stop this far above the ladder.
local MORE_H, LADDER_ROOM = 20, 6
-- The ticket: its three-slice's caps; its stub's width; its dial's place and size; its mark's; its words' left and
-- the room they leave at the right; the holiday tag's gap, top, height, padding and caps; its line's top, the source
-- mark's size, gap and drop, and the gap before "needs skill"; the pips' and marks' places from the right; the stamp's
-- centre from the right and its size; a closed ticket's alpha and the strike's drop under the name's top.
local TICKET_CAP_L, TICKET_CAP_R, STUB_W = 62, 12, 50
local DIAL_X, DIAL_Y, DIAL_SIZE, MARK_X, MARK_Y, MARK_SIZE = 4, 5, 42, 58, 9, 34
local WORDS_X, WORDS_RROOM, NAME_Y = 102, 102, 9
local TAG_GAP, TAG_Y, TAG_H, TAG_PAD, TAG_CAP = 7, 8, 18, 8, 3
local LINE_Y, SRC_SIZE, SRC_GAP, SRC_Y, NEED_GAP, NEED_Y = 28, 12, 4, 1.5, 8, 0.5
local PIPS_R, PIPS_Y, PIP, PIP_GAP, MARKS_R, MARKS_Y = 11.5, 14, 8, 5, 10, 27.5
local STAMP_R, STAMP_CY, STAMP_W, CLOSED_ALPHA, STRIKE_Y = 60, 26, 96, 0.5, 9.5
-- A row ahead: its mark, its words' left and room at the right, its lines' tops, the gap before "needs skill", and
-- its right column's place from the right.
local AHEAD_MARK, AHEAD_MARK_SIZE, AHEAD_X, AHEAD_RROOM, AHEAD_NAME_Y, AHEAD_ZONES_Y = 7, 24, 41, 101, 3.5, 19.5
local AHEAD_NEED_GAP, AHEAD_R, AHEAD_OPENS_Y = 4, 9, 4.5
-- The hint slip: its source mark's place and size, its words' left and right, the gap before its second line, its
-- buttons' left and the gap above them, its padding at the foot.
local HINT_SRC, HINT_SRC_SIZE, HINT_X, HINT_R, HINT_SMALL_GAP, HINT_BUTTONS_GAP, HINT_BUTTONS_H, HINT_PAD =
	11, 18, 41, 11, 3, 4, 25, 10
-- The ladder: its top above the page's foot; its line's height; the rail's place and length; the posts' centre, size,
-- and their titles' top and width; the token's centre and size.
local LADDER_UP, LADDER_LINE_H, LABEL_LADDER_Y, LADDER_LABEL_GAP = 65.5, 17.5, 4, 10
local RAIL_X, RAIL_Y, RAIL_W, POST_CY, POST, POST_TITLE_Y, POST_TITLE_W, TOKEN_CY, TOKEN =
	6, 31.5, 445, 34.5, 20, 48.5, 120, 33.5, 24
-- Motion (HNT-R162's motion, data/art/wagers/art.json › motion): the stamp pressed from 1.6 times its size, in 0.22 s,
-- then the ticket nudged a unit down and back in 0.12 s; the token sliding to its new share in 0.45 s.
local THUMP_FROM, THUMP_DUR, NUDGE, NUDGE_DUR, SLIDE_DUR = 1.6, 0.22, 1, 0.12, 0.45

-- CSS's ease-in, near enough: slow from rest, quick into the paper.
---@param t number
---@return number
local function easeIn(t)
	return t * t * t
end

---@class WagerTicketPip: Frame
---@field pip true
---@field inked boolean
---@field mark HuntsSpriteTexture

---@class WagerTicketView: Button
---@field ticketRun string     -- its run key: a click chooses it
---@field closed boolean
---@field selected boolean
---@field settled boolean
---@field paper HuntsThreeSlice
---@field dial WagerDialView
---@field left WagerText
---@field mark WagerMarkView
---@field name WagerText
---@field strike Texture
---@field tag HuntsThreeSlice
---@field tagText WagerText
---@field src HuntsSpriteTexture
---@field srcSeal HuntsSpriteTexture
---@field line WagerText
---@field need WagerText
---@field pips WagerTicketPip[]
---@field marks WagerText
---@field stampFrame Frame
---@field stamp HuntsSpriteTexture
---@field top number           -- where it sits down the page

---@class WagerAheadView: Button
---@field aheadRun string
---@field selected boolean
---@field outline BoardOutline
---@field mark WagerMarkView
---@field name WagerText
---@field zones WagerText
---@field need WagerText
---@field opens WagerText
---@field length WagerText

---@class WagerSectionView
---@field label WagerText
---@field count WagerText
---@field rule Texture
---@field caption WagerText

---@class WagersLadderView: Frame
---@field label WagerText
---@field line WagerText[]  -- its runs of words, left to right
---@field track HuntsSpriteTexture
---@field fill Texture            -- the rail-fill sprite, cropped to the share
---@field posts HuntsSpriteTexture[]
---@field numbers WagerText[]
---@field titles WagerText[]
---@field token HuntsSpriteTexture
---@field share number?        -- where the token stands now

---@class WagersSpreadView
---@field kicker WagerText
---@field title WagerText
---@field note WagerText
---@field closing WagerText
---@field arrow HuntsSpriteTexture
---@field hint Frame
---@field hintPaper Texture
---@field hintOutline BoardOutline
---@field hintSrc HuntsSpriteTexture
---@field hintSeal HuntsSpriteTexture
---@field hintLines WagerText[]
---@field hintButtons CompanionHintButtons   -- Get it and Dismiss, at the hint slip's foot (HNT-R170)
---@field onNow WagerSectionView
---@field ahead WagerSectionView
---@field tickets WagerTicketView[]
---@field aheadRows WagerAheadView[]
---@field more WagerText
---@field empty Frame
---@field emptyOutline BoardOutline
---@field emptyMark WagerMarkView
---@field emptyText WagerText
---@field ladder WagersLadderView

---@class WagersSpreadPage: Frame
---@field spread WagersSpreadView?

-- Desaturates every texture of `ticket` (a closed ticket greys out), or gives them their colour back.
---@param ticket WagerTicketView
---@param grey boolean
local function greyOut(ticket, grey)
	local paper, tag = ticket.paper, ticket.tag
	local textures = { paper.left, paper.middle, paper.right, ticket.dial.face, ticket.dial.fill, ticket.src }
	for _, texture in ipairs({ ticket.srcSeal, ticket.stamp, tag.left, tag.middle, tag.right }) do
		textures[#textures + 1] = texture
	end
	for _, layer in ipairs(ticket.mark.layers) do
		textures[#textures + 1] = layer
	end
	for _, pip in ipairs(ticket.pips) do
		textures[#textures + 1] = pip.mark
	end
	for _, texture in pairs(textures) do
		texture:SetDesaturated(grey)
	end
end

-- A section's heading on `page`: its label, its count, its rule fading out and, for "Ahead", its caption.
---@param page Frame
---@param ahead boolean
---@return WagerSectionView
local function newSection(page, ahead)
	local section = {
		label = ns.NewWagerText(page, ahead and "secLabelAhead" or "secLabel"),
		count = ns.NewWagerText(page, ahead and "secCountAhead" or "secCount"),
		rule = page:CreateTexture(nil, "ARTWORK"),
		caption = ns.NewWagerText(page, "secCaption"),
	}
	local rule = LOOK.secRule
	section.rule:SetColorTexture(1, 1, 1, 1)
	section.rule:SetGradient(
		"HORIZONTAL",
		CreateColor(rule[1], rule[2], rule[3], 1),
		CreateColor(rule[1], rule[2], rule[3], 0)
	)
	section.rule:SetHeight(1)
	return section
end

-- Lays a section's heading at `y`, or hides it with no data.
---@param page Frame
---@param section WagerSectionView
---@param data WagersSection?
---@param y number
local function laySection(page, section, data, y)
	if not data then
		for _, widget in ipairs({ section.label, section.count, section.rule, section.caption }) do
			widget:Hide()
		end
		return
	end
	local width = page:GetWidth()
	ns.SetWagerWords(section.label, data.label)
	section.label:SetWidth(0)
	ns.PlaceWagerText(section.label, page, 0, y + LABEL_Y)
	local x = math.ceil(section.label:GetStringWidth()) + COUNT_GAP
	ns.SetWagerWords(section.count, tostring(data.count))
	section.count:SetWidth(0)
	ns.PlaceWagerText(section.count, page, x, y)
	x = x + math.ceil(section.count:GetStringWidth()) + RULE_GAP
	local right = 0
	if data.caption then
		right = ns.FitWagerText(section.caption, data.caption, width - x - 8) + 8
		ns.PlaceWagerText(section.caption, page, 0, y + CAPTION_Y, true)
	else
		section.caption:Hide()
	end
	section.rule:ClearAllPoints()
	section.rule:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(y + RULE_Y))
	section.rule:SetWidth(math.max(1, width - x - right))
	section.rule:Show()
end

-- A ticket's widgets on `page`, `width` wide.
---@param page Frame
---@param width number
---@return WagerTicketView
local function newTicket(page, width)
	local ticket = CreateFrame("Button", nil, page) --[[@as WagerTicketView]]
	ticket:SetSize(width, TICKET_H)
	ticket.paper = CreateFrame("Frame", nil, ticket) --[[@as HuntsThreeSlice]]
	ticket.paper:SetPoint("TOPLEFT")
	-- under the ticket's own words and marks, which a frame at its level might draw beneath
	ticket.paper:SetFrameLevel(math.max(0, ticket:GetFrameLevel() - 1))
	ticket.dial = ns.NewWagerDial(ticket, DIAL_SIZE)
	ticket.dial:SetPoint("TOPLEFT", DIAL_X, -DIAL_Y)
	ticket.left = ns.NewWagerText(ticket.dial, "dialText")
	ticket.left:SetJustifyH("CENTER")
	ticket.left:SetPoint("CENTER", ticket, "TOPLEFT", STUB_W / 2, -TICKET_H / 2)
	ticket.mark = ns.NewEventMark(ticket, MARK_SIZE)
	ticket.mark:SetPoint("TOPLEFT", MARK_X, -MARK_Y)
	ticket.name = ns.NewWagerText(ticket, "tkName")
	ticket.strike = ticket:CreateTexture(nil, "OVERLAY")
	ns.FillWager(ticket.strike, LOOK.strike)
	ticket.strike:SetHeight(1)
	ticket.tag = CreateFrame("Frame", nil, ticket) --[[@as HuntsThreeSlice]]
	ticket.tagText = ns.NewWagerText(ticket.tag, "tag")
	ticket.tagText:SetJustifyH("CENTER")
	ticket.tagText:SetPoint("CENTER")
	ticket.src = ns.WagerSprite(ticket, "src-rotation", SRC_SIZE)
	ticket.srcSeal = ns.WagerSprite(ticket, "src-companion-seal", SRC_SIZE, "ARTWORK", 1)
	ticket.line = ns.NewWagerText(ticket, "tkLine")
	ticket.need = ns.NewWagerText(ticket, "need")
	ticket.pips = {}
	ticket.marks = ns.NewWagerText(ticket, "tkMarks")
	ticket.stampFrame = CreateFrame("Frame", nil, ticket)
	ticket.stampFrame:SetSize(1, 1)
	ticket.stampFrame:SetPoint("CENTER", ticket, "TOPRIGHT", -STAMP_R, -STAMP_CY)
	ticket.stamp = ns.WagerSprite(ticket.stampFrame, "stamp-settled", STAMP_W, "OVERLAY")
	ticket:SetScript("OnClick", function(self)
		if not self.closed then
			ns.OpenWagers(self.ticketRun)
		end
	end)
	return ticket
end

-- Runs that showed unsettled this showing, by run key, with the showing: one settled since presses its stamp (HNT-R162's
-- motion).
---@type table<string, integer>
local unsettledSeen = {}

-- Presses the SETTLED stamp: from 1.6 times its size and clear to its size, then the ticket nudged down and back
-- (HNT-R162's motion); with Animations off, at once.
---@param ticket WagerTicketView
local function thump(ticket)
	local function size(k)
		ns.SetSprite(ticket.stamp, "Wagers", "stamp-settled", STAMP_W * k)
		ns.CenterSprite(ticket.stamp, ticket.stampFrame)
	end
	Pagle.StopMotion(ticket)
	Pagle.Animate(ticket, {
		{
			dur = THUMP_DUR,
			ease = easeIn,
			keys = { { 0, { THUMP_FROM, 0 } }, { 1, { 1, 1 } } },
			apply = function(v)
				size(v[1])
				ticket.stamp:SetAlpha(v[2])
			end,
		},
		{
			dur = NUDGE_DUR,
			delay = THUMP_DUR,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 0 } }, { 0.5, { NUDGE } }, { 1, { 0 } } },
			apply = function(v)
				ticket:ClearAllPoints()
				ticket:SetPoint("TOPLEFT", ticket:GetParent(), "TOPLEFT", 0, -(ticket.top + v[1]))
			end,
		},
	})
end

-- Fills `ticket` from `data` (HNT-R162): its paper (the chosen one's rim), its stub's dial and words, its mark, its
-- name with a holiday's tag after it, its line, "needs skill", and the pips with the first marks or the stamp.
---@param ticket WagerTicketView
---@param data WagerTicket
local function fillTicket(ticket, data)
	local width = ticket:GetWidth()
	local wasRun, wasSettled = ticket.ticketRun, ticket.settled
	ticket.ticketRun, ticket.closed, ticket.selected, ticket.settled =
		data.run, data.closed, data.selected, data.settled
	local chosen = data.selected and not data.closed
	ns.SetThreeSliceAt(
		ticket.paper,
		"Wagers",
		chosen and "ticket-sel" or "ticket",
		width,
		TICKET_H,
		TICKET_CAP_L,
		TICKET_CAP_R,
		"BACKGROUND"
	)
	ticket.dial:SetDial(data.dial)
	ns.SetWagerInk(ticket.left, data.dial.urgent and "dialTextUrgent" or "dialText")
	ns.SetWagerWords(ticket.left, data.dial.left or "")
	ticket.left:SetShown(data.dial.left ~= nil)
	ticket.mark:SetMark(data.mark)
	-- the name, cut before the holiday's tag is
	local room = width - WORDS_X - WORDS_RROOM
	local tagWidth = 0
	if data.holiday then
		ns.SetWagerWords(ticket.tagText, data.holiday)
		ticket.tagText:SetWidth(0)
		tagWidth = math.ceil(ticket.tagText:GetStringWidth()) + 2 * TAG_PAD
		ns.SetThreeSliceAt(ticket.tag, "Wagers", "tag-holiday", tagWidth, TAG_H, TAG_CAP, TAG_CAP, "ARTWORK")
	end
	local nameWidth = ns.FitWagerText(ticket.name, data.name, room - (tagWidth > 0 and tagWidth + TAG_GAP or 0))
	ns.PlaceWagerText(ticket.name, ticket, WORDS_X, NAME_Y)
	if data.holiday then
		ticket.tag:ClearAllPoints()
		ticket.tag:SetPoint("TOPLEFT", ticket, "TOPLEFT", WORDS_X + nameWidth + TAG_GAP, -TAG_Y)
		ticket.tag:Show()
	else
		ticket.tag:Hide()
	end
	ticket.strike:ClearAllPoints()
	ticket.strike:SetPoint("TOPLEFT", ticket, "TOPLEFT", WORDS_X, -(NAME_Y + STRIKE_Y))
	ticket.strike:SetWidth(nameWidth)
	ticket.strike:SetShown(data.closed)
	-- the line: its source mark, its zones and end, then "needs skill {n}" in pencil
	ns.SetSprite(ticket.src, "Wagers", data.source == "companion" and "src-companion" or "src-rotation", SRC_SIZE)
	ns.PlaceSprite(ticket.src, ticket, WORDS_X, LINE_Y + SRC_Y)
	ns.TintWager(ticket.src, LOOK.note)
	ns.PlaceSprite(ticket.srcSeal, ticket, WORDS_X, LINE_Y + SRC_Y)
	ticket.srcSeal:SetShown(data.source == "companion")
	local lineX = WORDS_X + SRC_SIZE + SRC_GAP
	local lineRoom = width - lineX - WORDS_RROOM
	local needWidth = 0
	if data.need then
		ns.SetWagerWords(ticket.need, data.need)
		ticket.need:SetWidth(0)
		needWidth = math.ceil(ticket.need:GetStringWidth()) + NEED_GAP
	end
	local lineWidth = ns.FitWagerText(ticket.line, data.line, lineRoom - needWidth)
	ns.PlaceWagerText(ticket.line, ticket, lineX, LINE_Y)
	if data.need then
		ns.PlaceWagerText(ticket.need, ticket, lineX + lineWidth + NEED_GAP, LINE_Y + NEED_Y)
	else
		ticket.need:Hide()
	end
	-- at the right: the pips over the first marks, or the stamp once settled
	local pips = data.pips or {}
	for i, inked in ipairs(pips) do
		local pip = ns.BoardPooled(ticket.pips, i, function()
			local made = CreateFrame("Frame", nil, ticket) --[[@as WagerTicketPip]]
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
			ticket,
			"TOPLEFT",
			width - PIPS_R - (#pips - i + 1) * PIP - (#pips - i) * PIP_GAP,
			-PIPS_Y
		)
	end
	ns.BoardHideFrom(ticket.pips, #pips)
	if data.marks then
		ns.SetWagerWords(ticket.marks, data.marks)
		ticket.marks:SetWidth(0)
		ns.PlaceWagerText(ticket.marks, ticket, MARKS_R, MARKS_Y, true)
	else
		ticket.marks:Hide()
	end
	local showing = ns.board:Showing()
	if data.settled then
		ticket.stampFrame:Show()
		if wasRun == data.run and wasSettled == false and unsettledSeen[data.run] == showing then
			unsettledSeen[data.run] = nil
			thump(ticket)
		else
			ns.SetSprite(ticket.stamp, "Wagers", "stamp-settled", STAMP_W)
			ns.CenterSprite(ticket.stamp, ticket.stampFrame)
			ticket.stamp:SetAlpha(1)
		end
	else
		ticket.stampFrame:Hide()
		if not data.closed then
			unsettledSeen[data.run] = showing
		end
	end
	ticket:SetAlpha(data.closed and CLOSED_ALPHA or 1)
	greyOut(ticket, data.closed)
end

-- A row ahead's widgets on `page`, `width` wide.
---@param page Frame
---@param width number
---@return WagerAheadView
local function newAhead(page, width)
	local row = CreateFrame("Button", nil, page) --[[@as WagerAheadView]]
	row:SetSize(width, AHEAD_H)
	row.outline = ns.BoardOutline(row, 0, "BORDER")
	row.mark = ns.NewEventMark(row, AHEAD_MARK_SIZE)
	row.mark:SetPoint("TOPLEFT", AHEAD_MARK, -AHEAD_MARK)
	row.name = ns.NewWagerText(row, "ahName")
	row.zones = ns.NewWagerText(row, "ahZones")
	row.need = ns.NewWagerText(row, "need")
	row.opens = ns.NewWagerText(row, "ahOpens")
	row.length = ns.NewWagerText(row, "ahFor")
	row:SetScript("OnClick", function(self)
		ns.OpenWagers(self.aheadRun)
	end)
	return row
end

-- Fills a row ahead from `data` (HNT-R162): dashed, its mark, name, zones and "needs skill", and at its right when it
-- opens over its length; the chosen one's dashes in oxblood.
---@param row WagerAheadView
---@param data WagerAheadRow
local function fillAhead(row, data)
	local width = row:GetWidth()
	row.aheadRun, row.selected = data.run, data.selected
	row.outline:Dashed(data.selected and LOOK.hintDash or LOOK.aheadDash, width, AHEAD_H)
	for _, dash in ipairs(row.outline.dashes) do
		dash:SetAlpha((data.selected and LOOK.hintDash or LOOK.aheadDash)[4])
	end
	row.mark:SetMark(data.mark)
	local room = width - AHEAD_X - AHEAD_RROOM
	ns.FitWagerText(row.name, data.name, room)
	ns.PlaceWagerText(row.name, row, AHEAD_X, AHEAD_NAME_Y)
	local needWidth = 0
	if data.need then
		ns.SetWagerWords(row.need, data.need)
		row.need:SetWidth(0)
		needWidth = math.ceil(row.need:GetStringWidth()) + AHEAD_NEED_GAP
	end
	local zonesWidth = ns.FitWagerText(row.zones, data.zones, room - needWidth)
	ns.PlaceWagerText(row.zones, row, AHEAD_X, AHEAD_ZONES_Y)
	if data.need then
		ns.PlaceWagerText(row.need, row, AHEAD_X + zonesWidth + AHEAD_NEED_GAP, AHEAD_ZONES_Y)
	else
		row.need:Hide()
	end
	ns.FitWagerText(row.opens, data.opens, AHEAD_RROOM - AHEAD_R)
	ns.PlaceWagerText(row.opens, row, AHEAD_R, AHEAD_OPENS_Y, true)
	ns.FitWagerText(row.length, data.length, AHEAD_RROOM - AHEAD_R)
	ns.PlaceWagerText(row.length, row, AHEAD_R, AHEAD_ZONES_Y, true)
end

-- The ladder's widgets on `page`.
---@param page Frame
---@return WagersLadderView
local function newLadder(page)
	local ladder = CreateFrame("Frame", nil, page) --[[@as WagersLadderView]]
	ladder:SetSize(page:GetWidth(), 1)
	ladder.label = ns.NewWagerText(ladder, "ladLabel")
	ladder.line = {}
	ladder.track = ns.WagerSprite(ladder, "rail-track", RAIL_W, "ARTWORK", 0)
	ladder.fill = ladder:CreateTexture(nil, "ARTWORK", nil, 1)
	ladder.posts, ladder.numbers, ladder.titles = {}, {}, {}
	for i in ipairs(ns.LADDER_STEPS) do
		ladder.posts[i] = ns.WagerSprite(ladder, "post", POST, "ARTWORK", 2)
		ladder.numbers[i] = ns.NewWagerText(ladder, "postNum")
		ladder.numbers[i]:SetJustifyH("CENTER")
		ladder.titles[i] = ns.NewWagerText(ladder, "postTitle")
	end
	ladder.token = ns.WagerSprite(ladder, "token", TOKEN, "ARTWORK", 3)
	return ladder
end

-- Puts the token and the rail's fill at `share` of the rail (HNT-R162).
---@param ladder WagersLadderView
---@param share number
local function setShare(ladder, share)
	ladder.share = share
	local length = RAIL_W * share
	if length > 0 then
		ns.PlaceSprite(ns.SetCrop(ladder.fill, "Wagers", "rail-fill", length), ladder, RAIL_X, RAIL_Y)
		ladder.fill:Show()
	else
		ladder.fill:Hide()
	end
	ns.SetSprite(ladder.token, "Wagers", "token", TOKEN)
	ns.PlaceSprite(ladder.token, ladder, RAIL_X + length - TOKEN / 2, TOKEN_CY - TOKEN / 2)
	ladder.token:Show()
end

-- The settled count the ladder last showed, and in which showing: a change while the spread shows slides the token.
---@type { showing: integer?, settled: integer? }
local ladderSeen = {}

-- Lays the ladder at the page's foot (HNT-R162): "The ladder" and its line in three inks, set right to left, over the
-- rail with its fill, its posts (pressed once reached, their titles under them) and the Angler's token at the count.
---@param page Frame
---@param ladder WagersLadderView
---@param data WagersLadder
---@param settled integer
local function layLadder(page, ladder, data, settled)
	local top = page:GetHeight() - LADDER_UP
	ladder:SetWidth(page:GetWidth())
	ladder:ClearAllPoints()
	ladder:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -top)
	ladder:Show()
	ns.SetWagerWords(ladder.label, data.label)
	ns.PlaceWagerText(ladder.label, ladder, 0, LABEL_LADDER_Y)
	-- the line, right to left, each run of words in its ink, centred on the line's height; past the room the label
	-- leaves, the title is cut short (or, with none, the words)
	local inks = { count = "ladCount", line = "ladLine", title = "ladTitle" }
	local widths, total, cut = {}, 0, nil
	for i, run in ipairs(data.runs) do
		local text = ladder.line[i] or ns.NewWagerText(ladder, "ladLine")
		ladder.line[i] = text
		ns.SetWagerInk(text, inks[run.ink])
		ns.SetWagerWords(text, run.text)
		text:SetWidth(0)
		widths[i] = math.ceil(text:GetStringWidth())
		total = total + widths[i]
		if run.ink == "title" or (run.ink == "line" and not cut) then
			cut = i
		end
	end
	local room = ladder:GetWidth() - math.ceil(ladder.label:GetStringWidth()) - LADDER_LABEL_GAP
	if total > room and cut then
		widths[cut] = ns.FitWagerText(ladder.line[cut], data.runs[cut].text, math.max(1, room - (total - widths[cut])))
	end
	local right = 0
	for i = #data.runs, 1, -1 do
		local text = ladder.line[i]
		local ink = ns.WAGER_INKS[text.ink]
		text:ClearAllPoints()
		text:SetJustifyH("RIGHT")
		text:SetPoint("TOPRIGHT", ladder, "TOPRIGHT", -right, -(LADDER_LINE_H - ink.size) / 2)
		text:Show()
		right = right + widths[i]
	end
	ns.BoardHideFrom(ladder.line, #data.runs)
	-- the rail and its posts
	ns.PlaceSprite(ladder.track, ladder, RAIL_X, RAIL_Y)
	for i, mark in ipairs(data.marks) do
		local cx = RAIL_X + RAIL_W * mark.at
		local post = ladder.posts[i]
		ns.SetSprite(post, "Wagers", mark.reached and "post-got" or "post", POST)
		ns.PlaceSprite(post, ladder, cx - POST / 2, POST_CY - POST / 2)
		local number = ladder.numbers[i]
		ns.SetWagerInk(number, mark.reached and "postNumGot" or "postNum")
		ns.SetWagerWords(number, tostring(mark.step))
		number:ClearAllPoints()
		number:SetPoint("CENTER", ladder, "TOPLEFT", cx, -POST_CY)
		number:Show()
		local title = ladder.titles[i]
		ns.FitWagerText(title, mark.title, POST_TITLE_W)
		local last = i == #data.marks
		if last then
			ns.PlaceWagerText(title, ladder, 0, POST_TITLE_Y, true)
		else
			title:SetJustifyH("CENTER")
			title:SetWidth(POST_TITLE_W)
			title:ClearAllPoints()
			title:SetPoint("TOP", ladder, "TOPLEFT", cx, -(POST_TITLE_Y + (ns.WagerLineHeight("postTitle") - 11.5) / 2))
			title:Show()
		end
	end
	-- the token and the fill: none while updating; sliding to a new count while the spread shows (HNT-R162's motion)
	local showing = ns.board:Showing()
	local from = ladder.share
	local moved = data.share and from and ladderSeen.showing == showing and ladderSeen.settled ~= settled
	ladderSeen.showing, ladderSeen.settled = showing, data.share and settled or nil
	Pagle.StopMotion(ladder)
	if not data.share then
		ladder.share = nil
		ladder.fill:Hide()
		ladder.token:Hide()
	elseif moved and from ~= data.share then
		local to = data.share
		Pagle.Animate(ladder, {
			{
				dur = SLIDE_DUR,
				ease = Pagle.EASE.out,
				keys = { { 0, { from } }, { 1, { to } } },
				apply = function(v)
					setShare(ladder, v[1])
				end,
			},
		})
	else
		setShare(ladder, data.share)
	end
end

-- The hint slip's widgets.
---@param page Frame
---@param view WagersSpreadView
local function newHint(page, view)
	view.hint = CreateFrame("Frame", nil, page)
	view.hintPaper = view.hint:CreateTexture(nil, "BACKGROUND")
	view.hintPaper:SetAllPoints()
	ns.FillWager(view.hintPaper, LOOK.hintPaper)
	view.hintOutline = ns.BoardOutline(view.hint, 0, "BORDER")
	view.hintSrc = ns.WagerSprite(view.hint, "src-companion", HINT_SRC_SIZE, "ARTWORK", 0)
	ns.PlaceSprite(view.hintSrc, view.hint, HINT_SRC, HINT_SRC)
	ns.TintWager(view.hintSrc, LOOK.oxblood)
	view.hintSeal = ns.WagerSprite(view.hint, "src-companion-seal", HINT_SRC_SIZE, "ARTWORK", 1)
	ns.PlaceSprite(view.hintSeal, view.hint, HINT_SRC, HINT_SRC)
	view.hintLines = {}
	view.hintButtons = ns.NewHintButtons(view.hint)
end

-- Lays the companion hint's slip at `y` (HNT-R162, HNT-R170): dashed in oxblood on paler paper, the companion's mark,
-- its first line in the hand and any second in small italic, then Get it and Dismiss at its foot; hidden for none.
-- Returns the room it takes down the page.
---@param page Frame
---@param view WagersSpreadView
---@param lines string[]?
---@param y number
---@return number
local function layHint(page, view, lines, y)
	if not lines then
		view.hint:Hide()
		ns.HideHintButtons(view.hintButtons)
		return 0
	end
	local width = page:GetWidth()
	local at = HINT_SRC
	for i, words in ipairs(lines) do
		local line = ns.BoardPooled(view.hintLines, i, function()
			local made = ns.NewWagerText(view.hint, "hint")
			made:SetWordWrap(true)
			return made
		end)
		ns.SetWagerInk(line, i == 1 and "hint" or "hintSmall")
		ns.SetWagerWords(line, words)
		line:SetWidth(width - HINT_X - HINT_R)
		if i > 1 then
			at = at + HINT_SMALL_GAP
		end
		ns.PlaceWagerText(line, view.hint, HINT_X, at)
		at = at + math.max(ns.WagerLineHeight(line.ink), math.ceil(line:GetStringHeight()))
	end
	ns.BoardHideFrom(view.hintLines, #lines)
	at = at + HINT_BUTTONS_GAP
	local buttons = ns.PlaceHintButtons(view.hintButtons, view.hint, 0, at)
	ns.PlaceHintButtons(view.hintButtons, view.hint, width - HINT_X - buttons, at)
	local height = at + HINT_BUTTONS_H + HINT_PAD
	view.hint:ClearAllPoints()
	view.hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
	view.hint:SetSize(width, height)
	view.hintOutline:Dashed(LOOK.hintDash, width, height)
	view.hint:Show()
	return HINT_ABOVE + height + HINT_BELOW
end

-- The spread's widgets on `page`, made once.
---@param page WagersSpreadPage
---@return WagersSpreadView
local function viewOf(page)
	if page.spread then
		return page.spread
	end
	local view = {
		kicker = ns.NewWagerText(page, "kicker"),
		title = ns.NewWagerText(page, "title"),
		note = ns.NewWagerText(page, "note"),
		closing = ns.NewWagerText(page, "margin"),
		arrow = ns.WagerSprite(page, "arrow", ARROW_W),
		onNow = newSection(page, false),
		ahead = newSection(page, true),
		tickets = {},
		aheadRows = {},
		more = ns.NewWagerText(page, "more"),
		empty = CreateFrame("Frame", nil, page),
		ladder = newLadder(page),
	}
	view.note:SetWordWrap(true)
	view.closing:SetWordWrap(true)
	view.closing:SetWidth(CLOSING_W)
	view.emptyOutline = ns.BoardOutline(view.empty, 0, "BORDER")
	view.emptyMark = ns.NewEventMark(view.empty, EMPTY_MARK_SIZE)
	view.emptyMark:SetPoint("TOPLEFT", EMPTY_MARK, -EMPTY_MARK)
	view.emptyText = ns.NewWagerText(view.empty, "empty")
	view.emptyText:SetWordWrap(true)
	newHint(page, view)
	page.spread = view
	return view
end

-- One row of the left page's list: a ticket or a row ahead, with its section's heading before the first of each.
---@class WagersListItem
---@field kind "ticket"|"ahead"
---@field data WagerTicket|WagerAheadRow

-- The spread's left page (HNT-R162): kicker, title, the closing note and its arrow, the note; the hint slip; "On now"
-- and a ticket per run on, "Ahead" and a dashed row per run ahead, as many as fit above the ladder, then "+{n} more on
-- the table" in the last one's place; the empty box with neither; the ladder at the foot. Clicking an open ticket or a
-- row ahead chooses it.
---@param page WagersSpreadPage
---@param place BoardPlace
local function drawSpread(page, place)
	local view = viewOf(page)
	local data = ns.BoardWagersSpread(place.run)
	local width = page:GetWidth()
	ns.SetWagerWords(view.kicker, data.kicker)
	ns.PlaceWagerText(view.kicker, page, 0, KICKER_Y)
	ns.SetWagerWords(view.title, data.title)
	ns.PlaceWagerText(view.title, page, 0, TITLE_Y)
	if data.closing then
		ns.SetWagerWords(view.closing, data.closing)
		ns.PlaceWagerText(view.closing, page, CLOSING_R, CLOSING_Y, true)
		ns.PlaceSprite(view.arrow, page, width - ARROW_R - ARROW_W, ARROW_Y)
		view.arrow:Show()
	else
		view.closing:Hide()
		view.arrow:Hide()
	end
	ns.SetWagerWords(view.note, data.note)
	view.note:SetWidth(width)
	ns.PlaceWagerText(view.note, page, 0, NOTE_Y)
	local y = NOTE_Y + math.max(ns.WagerLineHeight("note"), math.ceil(view.note:GetStringHeight()))
	if data.hint then
		y = y + layHint(page, view, data.hint, y + HINT_ABOVE)
	else
		layHint(page, view, nil, y)
	end
	-- the list, top down: a row's place, and whether it fits above the ladder
	local limit = page:GetHeight() - LADDER_UP - LADDER_ROOM
	---@type WagersListItem[]
	local items = {}
	for _, ticket in ipairs(data.tickets) do
		items[#items + 1] = { kind = "ticket", data = ticket }
	end
	for _, row in ipairs(data.aheadRows) do
		items[#items + 1] = { kind = "ahead", data = row }
	end
	-- Where each row would sit: the sections' headings before the first of each kind.
	local tops, at = {}, y
	for i, item in ipairs(items) do
		local previous = items[i - 1]
		if not previous or previous.kind ~= item.kind then
			if previous then
				at = at - (TICKET_STEP - TICKET_H)
			end
			at = at + SECTION_GAP + SECTION_H + SECTION_BELOW + (item.kind == "ahead" and 0.5 or 0)
		end
		tops[i] = at
		at = at + (item.kind == "ticket" and TICKET_STEP or AHEAD_STEP)
	end
	local shown = #items
	for i, item in ipairs(items) do
		if tops[i] + (item.kind == "ticket" and TICKET_H or AHEAD_H) > limit then
			shown = math.max(0, i - 2) -- "+{n} more on the table" takes the last row that fits
			break
		end
	end
	local tickets, aheads = 0, 0
	for i = 1, shown do
		local item = items[i]
		if item.kind == "ticket" then
			tickets = tickets + 1
			local ticket = ns.BoardPooled(view.tickets, tickets, function()
				return newTicket(page, width)
			end)
			ticket.top = tops[i]
			ticket:ClearAllPoints()
			ticket:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -tops[i])
			fillTicket(ticket, item.data --[[@as WagerTicket]])
		else
			aheads = aheads + 1
			local row = ns.BoardPooled(view.aheadRows, aheads, function()
				return newAhead(page, width)
			end)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -tops[i])
			fillAhead(row, item.data --[[@as WagerAheadRow]])
		end
	end
	ns.BoardHideFrom(view.tickets, tickets)
	ns.BoardHideFrom(view.aheadRows, aheads)
	-- the headings, over the first shown row of each kind
	local onNowTop, aheadTop
	for i = 1, shown do
		local kind = items[i].kind
		if kind == "ticket" and not onNowTop then
			onNowTop = tops[i] - SECTION_H - SECTION_BELOW
		elseif kind == "ahead" and not aheadTop then
			aheadTop = tops[i] - SECTION_H - SECTION_BELOW - 0.5
		end
	end
	laySection(page, view.onNow, onNowTop and data.onNow or nil, onNowTop or 0)
	laySection(page, view.ahead, aheadTop and data.ahead or nil, aheadTop or 0)
	if shown < #items then
		ns.FitWagerText(view.more, ns.L.STRIP_MORE:format(#items - shown), width)
		ns.PlaceWagerText(view.more, page, 0, tops[shown + 1] + (MORE_H - ns.WagerLineHeight("more")) / 2)
	else
		view.more:Hide()
	end
	-- with no ticket and no row ahead, the empty box and its plain, faded mark
	if data.empty then
		local top = y + EMPTY_GAP
		view.empty:ClearAllPoints()
		view.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -top)
		view.empty:SetSize(width, EMPTY_H)
		view.emptyOutline:Dashed(LOOK.aheadDash, width, EMPTY_H)
		for _, dash in ipairs(view.emptyOutline.dashes) do
			dash:SetAlpha(LOOK.aheadDash[4])
		end
		view.emptyMark:SetMark(ns.EventMarkLayers({}), true)
		ns.SetWagerWords(view.emptyText, data.empty)
		view.emptyText:SetWidth(width - EMPTY_TEXT_X - EMPTY_TEXT_R)
		view.emptyText:ClearAllPoints()
		view.emptyText:SetPoint("LEFT", view.empty, "LEFT", EMPTY_TEXT_X, 0)
		view.emptyText:Show()
		view.empty:Show()
	else
		view.empty:Hide()
	end
	local state = ns.State()
	layLadder(page, view.ladder, data.ladder, state.settled or 0)
end

-- The spread's right page: the chosen run's entry (HNT-R163), or with no run on or ahead its own words.
---@param page Frame
---@param place BoardPlace
local function drawEntry(page, place)
	local selected = ns.BoardWagersSpread(place.run).selected
	if not (selected and ns.DrawRunEntry(page, selected)) then
		ns.DrawNoRunEntry(page)
	end
end

ns.board:RegisterPage("wagers", "left", drawSpread)
ns.board:RegisterPage("wagers", "right", drawEntry)
