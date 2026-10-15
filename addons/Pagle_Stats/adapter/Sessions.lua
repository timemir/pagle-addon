if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Session pages of the Stats book (stats.md › UI › This Session, Sessions): *This Session*, the current Session's
-- entry (or My last Session's, STA-R32) beside a ruled ledger of the Sessions before it, and *Sessions*, every Session
-- in a ruled ledger, 16 to a page, beside the chosen one's entry. One entry renderer draws a Session on both pages:
-- its date heading by its start (STA-R59, STA-R95), its span and figures (STA-R33, "so far" and "now" for the current
-- one), its Catches by quality, its zones and characters. With no Sessions every side reads "No Sessions yet."
-- (STA-R97). The book never calls these while the projection is updating: it writes its own line then (STA-R72).
-- The look follows prototypes/stats-window/ variant D, in adapter/BookWidgets.lua's art.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- Heights and gaps, in pixels: the kicker and the title above an entry, the span line, a figure line, a heading and
-- the space above it, the gap above a ledger, the pager and a link.
local KICKER, TITLE, SPAN, LINE = 18, 32, 22, 20
local HEADING, HEADING_GAP = 20, 10
local NOTE, LEDGER_GAP, PAGER, LINK = 18, 6, 22, 24

-- A figure's label in the paper's ink when its quality colour is this light or lighter (Common's white): the game's
-- colours are made for dark frames.
local PALE = 0.75

-- The ruled ledgers' columns (stats.md › UI › This Session), "Where" taking what the others leave.
local STARTED_WIDTH, LENGTH_WIDTH, COUNT_WIDTH = 120, 60, 56

---@class StatsSessionEntryView
---@field frame Frame
---@field kicker FontString
---@field title FontString
---@field span FontString
---@field quality StatsBookHeadingView
---@field where StatsBookHeadingView
---@field lines StatsBookFigureView[]
---@field width number

---@class StatsSessionPagerView: Frame
---@field later Button
---@field laterLabel FontString
---@field page FontString
---@field earlier StatsBookLinkView

---@class StatsSessionLedgerPageView
---@field frame Frame
---@field kicker FontString
---@field title FontString
---@field note FontString
---@field ledger StatsBookLedgerView
---@field link StatsBookLinkView?
---@field pager StatsSessionPagerView?

-- What each page side drew on its content frame, made at its first draw: its "No Sessions yet." and its view.
---@type table<Frame, { empty: FontString, view: table }>
local drawn = setmetatable({}, { __mode = "k" })

-- Places `region` on its parent's top left, `y` pixels down.
---@param region Region
---@param y number
local function at(region, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", 0, -y)
end

-- The side's "No Sessions yet." and its view, made by `make` at its first draw; shows the one or the other.
---@param content Frame
---@param make fun(frame: Frame, width: number): table
---@param empty boolean
---@return table? view nil when there are no Sessions
local function sideOf(content, make, empty)
	local side = drawn[content]
	if not side then
		local text = ns.NewBookNoSessions(content)
		at(text, 0)
		local frame = CreateFrame("Frame", nil, content)
		frame:SetAllPoints()
		side = { empty = text, view = make(frame, content:GetWidth()) }
		drawn[content] = side
	end
	side.empty:SetShown(empty)
	side.view.frame:SetShown(not empty)
	return not empty and side.view or nil
end

-- The kicker and title every page side opens with.
---@param frame Frame
---@return FontString kicker
---@return FontString title
local function heads(frame)
	local kicker, title = ns.NewBookKicker(frame), ns.NewBookTitle(frame)
	at(kicker, 0)
	at(title, KICKER)
	return kicker, title
end

---@param frame Frame
---@param width number
---@return StatsSessionEntryView
local function newEntry(frame, width)
	local kicker, title = heads(frame)
	local span = ns.NewBookHand(frame)
	span:SetWidth(width)
	return {
		frame = frame,
		kicker = kicker,
		title = title,
		span = span,
		quality = ns.NewBookHeading(frame, width),
		where = ns.NewBookHeading(frame, width),
		lines = {},
		width = width,
	}
end

-- The `i`th figure line of `view` (ns.NewBookFigure), made on first use, at `y` with its words, its label coloured
-- `color` (ink by default) and opening `onClick` if given: a zone's line opens its place page.
---@param view StatsSessionEntryView
---@param i integer
---@param y number
---@param label string
---@param value string
---@param color number[]?
---@param onClick fun()?
local function lineAt(view, i, y, label, value, color, onClick)
	local line = view.lines[i]
	if not line then
		line = ns.NewBookFigure(view.frame, view.width, LINE)
		view.lines[i] = line
	end
	at(line, y)
	line:SetFigure({ label = label, value = value, ink = color, onClick = onClick })
	line:Show()
end

-- An item quality's colour on the paper: the game's own (STA-R59), or the ink for one too pale to read on it.
---@param quality integer
---@return number[]
local function qualityInk(quality)
	local r, g, b = ns.QualityColor(quality)
	if 0.299 * r + 0.587 * g + 0.114 * b >= PALE then
		return LOOK.ink
	end
	return { r, g, b }
end

-- Where Catches by quality reads an item's quality (STA-R33): Core's catalogue, else the client.
---@type StatsQualityLookups
local QUALITY_LOOKUPS = {
	GetItem = function(itemID)
		return Pagle.GetItem(itemID)
	end,
	GetItemQualityByID = function(itemID)
		return C_Item.GetItemQualityByID(itemID)
	end,
}

-- Draws Session `record`'s entry (stats.md › UI › This Session, left page) under `kicker`: to now and so far when it
-- is the current Session (`live`). An item whose quality isn't loaded is asked for; the book redraws when it loads.
---@param view StatsSessionEntryView
---@param record StatsSession
---@param kicker string
---@param live boolean
---@return number height
local function drawEntry(view, record, kicker, live)
	local now = live and GetServerTime() or nil
	view.kicker:SetText(kicker)
	view.title:SetText(ns.SessionHeading(ns.SessionDate(record)))
	view.span:SetText(
		L.SESSION_SPAN:format(
			ns.Time(record.startTime),
			live and L.SESSION_NOW or ns.Time(record.endTime),
			ns.Duration(ns.TimeFished(record, now))
		)
	)
	local y = KICKER + TITLE
	at(view.span, y)
	y = y + math.max(SPAN, view.span:GetStringHeight() + 4)

	local n = 0
	local function line(label, value, color, onClick)
		n = n + 1
		lineAt(view, n, y, label, value, color, onClick)
		y = y + LINE
	end
	line(L.SESSION_CASTS, ns.Number(record.casts))
	line(L.SESSION_CATCHES, ns.Number(record.catches))
	line(L.SESSION_GOT_AWAY, L.SESSION_GOT_AWAY_VALUE:format(ns.Number(record.gotAway), ns.GotAwayRate(record) or 0))
	line(L.SESSION_PER_HOUR, ns.Number(ns.CatchesPerHour(record, now)))
	line(L.SESSION_SKILL, L.SESSION_SKILL_VALUE:format(ns.Number(record.skill)))

	local function heading(headingView, text)
		y = y + HEADING_GAP
		headingView:SetHeading(text)
		at(headingView, y)
		y = y + HEADING
	end
	heading(view.quality, L.SESSION_BY_QUALITY)
	local qualities, pending = ns.CatchesByQuality(record.items, QUALITY_LOOKUPS)
	for _, itemID in ipairs(pending) do
		ns.book:RequestItem(itemID)
	end
	for _, count in ipairs(qualities) do
		line(ns.QualityName(count.quality), ns.Number(count.catches), qualityInk(count.quality))
	end

	heading(view.where, L.SESSION_WHERE_AND_WHO)
	for _, zone in ipairs(ns.ZonesByCasts(record.zones)) do
		line(ns.AreaName(zone.zone), ns.Number(zone.casts), nil, function()
			ns.OpenBook({ page = "place", area = zone.zone })
		end)
	end
	for _, char in ipairs(ns.CharactersByName(record.chars, ns.CharacterName)) do
		line(char.name, ns.Number(char.casts))
	end
	for i = n + 1, #view.lines do
		view.lines[i]:Hide()
	end
	return y
end

-- The Session records, and which is current (its index) or My last Session (STA-R32). Core's Session with no record
-- of its own (in practice only while the projection updates, when nothing here draws) leaves the last record as My
-- last Session.
---@return StatsSession[] sessions
---@return StatsShownSession? shown
local function sessionsNow()
	local sessions = ns.State().sessions
	local shown = ns.CurrentSession(sessions, Pagle.GetSession())
	if shown and shown.kind == "mismatched" then
		shown = #sessions > 0 and { kind = "last", record = sessions[#sessions], index = #sessions } or nil
	end
	return sessions, shown
end

-- The index of the current Session's record, if one is open and recorded.
---@param shown StatsShownSession?
---@return integer?
local function currentIndex(shown)
	return shown and shown.kind == "current" and shown.index or nil
end

-- One row of a ruled ledger (stats.md › UI › This Session): started (date and time), where (zones by Casts), length
-- (so far for the current Session), Casts and Catches; clicking it opens `target`.
---@param record StatsSession
---@param live boolean
---@param target StatsBookTarget
---@return StatsBookLedgerRow
local function ledgerRow(record, live, target)
	local zones = {}
	for i, zone in ipairs(ns.ZonesByCasts(record.zones)) do
		zones[i] = ns.AreaName(zone.zone)
	end
	return {
		cells = {
			L.SESSIONS_STARTED_AT:format(ns.Date(record.startTime), ns.Time(record.startTime)),
			table.concat(zones, L.SESSIONS_WHERE_JOIN),
			ns.Duration(ns.TimeFished(record, live and GetServerTime() or nil)),
			ns.Number(record.casts),
			ns.Number(record.catches),
		},
		onClick = function()
			ns.OpenBook(target)
		end,
	}
end

-- A ledger page side: kicker, title, a note line when `noted`, and the ruled ledger.
---@param frame Frame
---@param width number
---@param noted boolean
---@return StatsSessionLedgerPageView
local function newLedgerPage(frame, width, noted)
	local kicker, title = heads(frame)
	local note = ns.BookText(frame, ns.BookFonts().note, LOOK.note)
	note:SetWidth(width)
	at(note, KICKER + TITLE)
	note:SetShown(noted)
	local columns = {
		{ label = L.SESSIONS_STARTED, width = STARTED_WIDTH },
		{ label = L.SESSIONS_WHERE, width = width - STARTED_WIDTH - LENGTH_WIDTH - 2 * COUNT_WIDTH },
		{ label = L.SESSIONS_LENGTH, width = LENGTH_WIDTH, align = "RIGHT" },
		{ label = L.SESSIONS_CASTS, width = COUNT_WIDTH, align = "RIGHT" },
		{ label = L.SESSIONS_CATCHES, width = COUNT_WIDTH, align = "RIGHT" },
	}
	local ledger = ns.NewBookLedger(frame, width, columns)
	at(ledger, KICKER + TITLE + (noted and NOTE or 0) + LEDGER_GAP)
	return { frame = frame, kicker = kicker, title = title, note = note, ledger = ledger }
end

-- This Session's right page: "Before that", "Earlier Sessions", their ledger and "Every Session ☛".
---@param frame Frame
---@param width number
---@return StatsSessionLedgerPageView
local function newEarlier(frame, width)
	local view = newLedgerPage(frame, width, false)
	view.kicker:SetText(L.SESSIONS_BEFORE_THAT)
	view.title:SetText(L.SESSIONS_EARLIER)
	view.link = ns.NewBookLink(frame)
	view.link:SetLink(L.SESSIONS_EVERY, function()
		ns.OpenBook({ page = "sessions" })
	end)
	return view
end

-- The Sessions page's left side, with its pager under the ledger: "☚ later", "page X of Y", "earlier ☛".
---@param frame Frame
---@param width number
---@return StatsSessionLedgerPageView
local function newSessionsLedger(frame, width)
	local view = newLedgerPage(frame, width, true)
	view.kicker:SetText(L.BOOK_SESSIONS)
	view.note:SetText(L.SESSIONS_NOTE:format(math.floor(ns.SESSION_GAP / 60)))
	local pager = CreateFrame("Frame", nil, frame) --[[@as StatsSessionPagerView]]
	pager:SetSize(width, PAGER)
	pager.later = CreateFrame("Button", nil, pager) --[[@as Button]]
	pager.later:SetPoint("LEFT")
	local mark = ns.NewBookMark(pager.later, "handLeft", 16)
	mark:SetPoint("LEFT")
	pager.laterLabel = ns.BookText(pager.later, ns.BookFonts().hand, LOOK.hand)
	pager.laterLabel:SetPoint("LEFT", mark, "RIGHT", 4, 0)
	pager.laterLabel:SetText(L.SESSIONS_LATER)
	pager.later:SetSize(pager.laterLabel:GetStringWidth() + 22, PAGER)
	pager.page = ns.BookText(pager, ns.BookFonts().note, LOOK.note)
	pager.page:SetPoint("CENTER")
	pager.earlier = ns.NewBookLink(pager)
	pager.earlier:SetPoint("RIGHT")
	view.pager = pager
	return view
end

-- This Session (stats.md › UI › This Session): the current Session's entry, or My last Session's.
ns.book:RegisterPage("session", "left", function(content)
	local _, shown = sessionsNow()
	local view = sideOf(content, newEntry, shown == nil) --[[@as StatsSessionEntryView?]]
	if not view or not shown then
		return nil
	end
	local kicker = shown.kind == "current" and L.BOOK_THIS_SESSION or L.BOOK_LAST_SESSION
	return drawEntry(view, shown.record --[[@as StatsSession]], kicker, shown.kind == "current")
end)

-- This Session's right page: the 10 Sessions before the one shown, newest first; a row opens it on Sessions.
ns.book:RegisterPage("session", "right", function(content)
	local sessions, shown = sessionsNow()
	local view = sideOf(content, newEarlier, shown == nil) --[[@as StatsSessionLedgerPageView?]]
	if not view or not shown then
		return nil
	end
	local rows = {}
	local earlier = ns.EarlierSessions(shown.index --[[@as integer]])
	for i, index in ipairs(earlier) do
		local record = sessions[index]
		rows[i] = ledgerRow(record, false, {
			page = "sessions",
			session = record.id,
			ledgerPage = ns.LedgerPageOf(#sessions, index),
		})
	end
	local y = KICKER + TITLE + LEDGER_GAP + view.ledger:SetRows(rows, nil)
	local link = view.link --[[@as StatsBookLinkView]]
	at(link, y + 6)
	return y + 6 + LINK
end)

-- Sessions' left page (stats.md › UI › Sessions): every Session in the ruled ledger, 16 to a page, newest first, the
-- chosen one shaded, and the pager, each arrow hidden at its end.
ns.book:RegisterPage("sessions", "left", function(content, place)
	local sessions, shown = sessionsNow()
	local count = #sessions
	local view = sideOf(content, newSessionsLedger, count == 0) --[[@as StatsSessionLedgerPageView?]]
	if not view then
		return nil
	end
	local chosen = ns.FindSession(sessions, place.session) or count
	local live = currentIndex(shown)
	local ledger = ns.SessionLedger(count, place.ledgerPage)
	view.title:SetText(ns.Count(count, "Sessions"))
	local rows, chosenRow = {}, nil
	for i, index in ipairs(ledger.indices) do
		local record = sessions[index]
		rows[i] = ledgerRow(record, index == live, { page = "sessions", session = record.id, ledgerPage = ledger.page })
		if index == chosen then
			chosenRow = i
		end
	end
	local y = KICKER + TITLE + NOTE + LEDGER_GAP + view.ledger:SetRows(rows, chosenRow)
	local pager = view.pager --[[@as StatsSessionPagerView]]
	at(pager, y + 6)
	pager.later:SetShown(ledger.later)
	pager.later:SetScript("OnClick", function()
		ns.OpenBook({ page = "sessions", session = place.session, ledgerPage = ledger.page - 1 })
	end)
	pager.page:SetText(L.SESSIONS_PAGE:format(ledger.page, ledger.pages))
	pager.earlier:SetLink(L.SESSIONS_EARLIER_PAGE, function()
		ns.OpenBook({ page = "sessions", session = place.session, ledgerPage = ledger.page + 1 })
	end)
	pager.earlier:SetShown(ledger.earlier)
	return y + 6 + PAGER
end)

-- Sessions' right page: the chosen Session's entry, the newest by default, as "Session {n}" from the oldest.
ns.book:RegisterPage("sessions", "right", function(content, place)
	local sessions, shown = sessionsNow()
	local view = sideOf(content, newEntry, #sessions == 0) --[[@as StatsSessionEntryView?]]
	if not view then
		return nil
	end
	local index = ns.FindSession(sessions, place.session) or #sessions
	local kicker = L.SESSION_NUMBERED:format(ns.Number(index))
	return drawEntry(view, sessions[index], kicker, index == currentIndex(shown))
end)
