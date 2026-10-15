if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book on the client (STA-R70–R75; stats.md › UI): a leather binding with two parchment pages, the gilt
-- breadcrumbs, the live line and the search box's anchor on the leather above them, the nameplate on its lower corner
-- and the ribbons hanging from its right edge, drawing on each page what logic/Book.lua's router says the page shown
-- puts there. The pages' contents are the page tickets' renderers (#212–#217); this file draws only the book. It makes
-- no secure frames, so it opens and works in combat and while restricted (STA-R71, STA-R93). The look follows
-- prototypes/stats-window/ variant D, in adapter/BookWidgets.lua's art.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (STA-R70).
local FRAME_NAME = "PagleStatsBook"
-- About 980 × 640 (Tunables), as variant D: the leather at the sides and foot, the strip above the pages for the
-- crumbs, the live line and the search box.
local WIDTH, HEIGHT = 980, 640
local SIDE, STRIP, FOOT = 18, 38, 16
local PAGE_WIDTH = (WIDTH - 2 * SIDE) / 2
local PAGE_HEIGHT = HEIGHT - STRIP - FOOT
-- A page body's padding inside the paper (variant D: 22px 28px 34px).
local PAD_X, PAD_TOP, PAD_BOTTOM = 28, 22, 34
local BODY_WIDTH, BODY_HEIGHT = PAGE_WIDTH - 2 * PAD_X, PAGE_HEIGHT - PAD_TOP - PAD_BOTTOM
-- The search box's room at the strip's right (variant D: 250px), and the gap before the live line.
local SEARCH_WIDTH, LIVE_GAP = 250, 14
-- The ribbons' column outside the leather's right edge, from below the strip, and the gap between ribbons.
local RIBBONS_TOP, RIBBON_GAP = 50, 6
-- How far a mouse wheel notch scrolls a page body.
local WHEEL_STEP = 40
-- The live-line tick, in seconds (Tunables: Live-line tick).
ns.LIVE_LINE_TICK = 30

-- The owner of the book's Core callbacks and WoW event registrations (CORE-R23).
local OWNER = "Pagle_Stats book"

--- The leather's anchors the page tickets draw into: the search box (#215).
---@alias StatsBookLeatherPart "search"
local LEATHER_PARTS = { "search" }

--- Draws one of the leather's anchors: `anchor` is its frame, `place` where the book is, `updating` whether the
--- projection is updating (STA-R72: search is then disabled).
---@alias StatsBookLeatherRenderer fun(anchor: Frame, place: StatsBookTarget, updating: boolean)

---@class StatsBookCrumbView: Button
---@field label FontString
---@field fleuron Texture?        -- the fleuron before every crumb but the first

---@class StatsBookLiveView: Button
---@field dot Texture
---@field label FontString

---@class StatsBookRibbonButton: StatsBookRibbonView
---@field id "here"|"session"|"lifetime"|"sessions"
---@field words string

---@class StatsBookFrame: Frame
---@field close Button
---@field leather StatsBookLeatherView
---@field papers table<StatsBookSide, StatsBookParchmentView>
---@field bodies table<StatsBookSide, Frame>          -- each page's body, inside its padding
---@field updating table<StatsBookSide, FontString>   -- "Updating my records…" on each body (STA-R72)
---@field crumbs Frame
---@field crumbButtons StatsBookCrumbView[]
---@field live StatsBookLiveView
---@field plate StatsBookPlateView
---@field ribbons StatsBookRibbonButton[]
---@field anchors table<StatsBookLeatherPart, Frame>

--- One side of one page: its scroll frame on the side's body, and the content the renderer draws on.
---@class StatsBookPageView
---@field scroll ScrollFrame
---@field content Frame

--- The Stats book: its router, its frame once made, and each page's sides.
---@class StatsBook
---@field router StatsBookRouter
---@field frame StatsBookFrame?
---@field pages table<string, StatsBookPageView>   -- by "page:side", made at their first draw
---@field private leatherRenderers table<StatsBookLeatherPart, StatsBookLeatherRenderer>
---@field private drawnKey string?                 -- the place last drawn, to keep its scroll on a redraw
---@field private drawNextFrame fun()              -- QueueDraw's redraw, once per frame (ns.OncePerFrame)
---@field private ticker table?                    -- the live-line tick, while open
---@field listening boolean                        -- Core's events are subscribed
---@field private requestItem fun(itemID: integer) -- the book's item loader (ns.NewItemLoader)
local Book = {}
Book.__index = Book

--- The book, on the home spread until it is first left: a login or `/reload` starts it afresh (STA-R70).
ns.book = setmetatable({
	router = ns.NewBookRouter(),
	pages = {},
	leatherRenderers = {},
	listening = false,
}, Book)
ns.book.drawNextFrame = ns.OncePerFrame(function()
	ns.book:Draw()
end)
ns.book.requestItem = ns.NewItemLoader(OWNER, function()
	ns.book:QueueDraw()
end)

--- Registers `renderer` to draw side `side` of page `page` (logic/Book.lua lists the pages and who draws them); a
--- later registration replaces it. The page tickets call it when their files load (after this one in the TOC).
---@param page StatsBookPage
---@param side StatsBookSide
---@param renderer StatsBookRenderer
function Book:RegisterPage(page, side, renderer)
	self.router:Register(page, side, renderer)
end

--- Registers `renderer` to draw the leather's anchor `part` at every draw, after both pages; a later registration
--- replaces it. Raises on an anchor the leather doesn't have.
---@param part StatsBookLeatherPart
---@param renderer StatsBookLeatherRenderer
function Book:RegisterLeather(part, renderer)
	local known = false
	for _, name in ipairs(LEATHER_PARTS) do
		known = known or name == part
	end
	assert(known, "the Stats book's leather has no anchor " .. tostring(part))
	assert(type(renderer) == "function", "a leather anchor's renderer is a function")
	self.leatherRenderers[part] = renderer
end

--- Whether the projection is updating (STA-R72): the page bodies then read "Updating my records…", and search (#215)
--- and the watch toggle (#214) are disabled.
---@return boolean
function Book.IsUpdating()
	return ns.IsUpdating()
end

--- Asks the client for `itemID`'s data through the book's item loader (ns.NewItemLoader), once while it is on its way;
--- when it loads, the open page redraws on the next frame, once however many load in that frame (STA-R73). Call it for
--- an item ns.Item reports not loaded.
---@param itemID integer
function Book:RequestItem(itemID)
	self.requestItem(itemID)
end

--- An item's name and icon for a page (ns.Item: "Item {id}" and the question mark until the client has it), asking
--- the client for one it hasn't loaded, so the page redraws when it arrives (STA-R59, STA-R73).
---@param itemID integer
---@return string name
---@return integer|string icon
function Book:Item(itemID)
	local name, icon, loaded = ns.Item(itemID)
	if not loaded then
		self:RequestItem(itemID)
	end
	return name, icon
end

-- Places the frame where profile.window says, or centred while it is nil (STA-R71).
---@param frame StatsBookFrame
local function position(frame)
	local window = ns.db and ns.db.profile.window
	frame:ClearAllPoints()
	if window then
		frame:SetPoint(window[1], UIParent, window[2], window[3], window[4])
	else
		frame:SetPoint("CENTER")
	end
end

-- A page on the frame: its parchment, its spine on the inner edge, its body inside the padding and the body's
-- "Updating my records…". The paper takes the mouse, so only the leather drags the book.
---@param frame StatsBookFrame
---@param side StatsBookSide
local function buildPage(frame, side)
	local paper = CreateFrame("Frame", nil, frame)
	paper:SetSize(PAGE_WIDTH, PAGE_HEIGHT)
	paper:SetPoint("BOTTOMLEFT", side == "left" and SIDE or SIDE + PAGE_WIDTH, FOOT)
	paper:EnableMouse(true)
	frame.papers[side] = ns.NewBookParchment(paper, side == "left" and "RIGHT" or "LEFT")
	local body = CreateFrame("Frame", nil, paper)
	body:SetPoint("TOPLEFT", PAD_X, -PAD_TOP)
	body:SetPoint("BOTTOMRIGHT", -PAD_X, PAD_BOTTOM)
	body:SetSize(BODY_WIDTH, BODY_HEIGHT)
	frame.bodies[side] = body
	local updating = ns.NewBookHand(body)
	updating:SetPoint("TOPLEFT")
	updating:SetWidth(BODY_WIDTH)
	updating:SetText(L.BOOK_UPDATING)
	updating:Hide()
	frame.updating[side] = updating
end

-- The live line (STA-R75): the gilt dot and its words, opening This Session.
---@param book StatsBook
---@param frame StatsBookFrame
local function buildLive(book, frame)
	local live = CreateFrame("Button", nil, frame) --[[@as StatsBookLiveView]]
	live:SetHeight(20)
	live:SetPoint("RIGHT", frame.anchors.search, "LEFT", -LIVE_GAP, 0)
	live.dot = ns.NewBookDot(live, 8)
	live.dot:SetPoint("LEFT", 0, 0)
	live.label = ns.BookText(live, ns.BookFonts().crumb, LOOK.gilt)
	live.label:SetPoint("LEFT", live.dot, "RIGHT", 5, 0)
	live:SetScript("OnClick", function()
		book:Open({ page = "session" })
	end)
	live:Hide()
	frame.live = live
end

-- The ribbons (STA-R74), top to bottom down the leather's right edge, each opening its page.
---@param book StatsBook
---@param frame StatsBookFrame
local function buildRibbons(book, frame)
	local words = {
		here = L.BOOK_WHERE_I_AM,
		session = L.BOOK_THIS_SESSION,
		lifetime = L.BOOK_LIFETIME,
		sessions = L.BOOK_SESSIONS,
	}
	frame.ribbons = {}
	local y = -RIBBONS_TOP
	for i, data in ipairs(ns.BOOK_RIBBONS) do
		local ribbon = ns.NewBookRibbon(frame) --[[@as StatsBookRibbonButton]]
		ribbon.id, ribbon.words = data.id, words[data.id]
		ribbon:SetRibbon(ribbon.words, data.green, false)
		ribbon:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, y)
		y = y - ribbon:GetHeight() - RIBBON_GAP
		ribbon:SetScript("OnClick", function()
			if data.page then
				book:Open({ page = data.page })
			else
				book:Open(ns.WhereIAm(Pagle.GetConditions()))
			end
		end)
		frame.ribbons[i] = ribbon
	end
end

-- Builds the book, hidden: the leather, two pages, the strip's crumbs, live line and search anchor, the nameplate,
-- the ribbons and the close button. It drags by the leather and saves where it was left in profile.window (STA-R71);
-- Esc hides it through UISpecialFrames (STA-R70).
---@param book StatsBook
---@return StatsBookFrame
local function build(book)
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as StatsBookFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- The book keeps its own position; a user-placed frame would also be saved by the client in its layout cache.
		self:SetUserPlaced(false)
		local point, _, relativePoint, x, y = self:GetPoint(1)
		if point and ns.db then
			ns.db.profile.window = { point, relativePoint, x, y }
		end
	end)
	frame.leather = ns.NewBookLeather(frame)
	frame.papers, frame.bodies, frame.updating = {}, {}, {}
	buildPage(frame, "left")
	buildPage(frame, "right")

	frame.crumbs = CreateFrame("Frame", nil, frame)
	frame.crumbs:SetPoint("TOPLEFT", SIDE + 6, -9)
	frame.crumbs:SetSize(WIDTH - 2 * SIDE - SEARCH_WIDTH - 40, 20)
	frame.crumbButtons = {}
	local search = CreateFrame("Frame", nil, frame)
	search:SetSize(SEARCH_WIDTH, 22)
	search:SetPoint("TOPRIGHT", -(SIDE + 16), -8)
	frame.anchors = { search = search }
	buildLive(book, frame)

	frame.plate = ns.NewBookPlate(frame)
	frame.plate:SetPoint("BOTTOMLEFT", -12, -14)
	buildRibbons(book, frame)

	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton") --[[@as Button]]
	frame.close:SetPoint("TOPRIGHT", 6, 6)
	frame.close:SetScript("OnClick", function()
		book:Hide()
	end)
	frame:SetScript("OnHide", function()
		book:Hidden()
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
	return frame
end

-- Subscribes the book to what redraws it while open (STA-R73), once, at its first opening: so an inert Stats, which
-- never opens it, listens to nothing (CORE-R13).
---@param book StatsBook
local function listen(book)
	if book.listening then
		return
	end
	book.listening = true
	local function queue()
		book:QueueDraw()
	end
	Pagle.RegisterCallback(OWNER, "CastEnded", function(_, outcome)
		if outcome ~= "interrupted" then
			queue()
		end
	end)
	Pagle.RegisterCallback(OWNER, "SessionEnded", queue)
	Pagle.RegisterCallback(OWNER, "ConditionsChanged", function(_, changedKeys)
		for _, key in ipairs(changedKeys) do
			if key == "area" or key == "skill" then
				queue()
				return
			end
		end
	end)
end

--- Whether the book is open.
---@return boolean
function Book:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

--- Opens the book where it was left (the home spread at the first opening after a login or `/reload`), or closes it
--- (STA-R70). Every entry point calls it.
function Book:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Open()
	end
end

--- Shows `target` (a StatsBookTarget), or where the book was left with none, opening the book if it is closed: where
--- profile.window says, or centred (STA-R71). Open, it turns there in place and never closes.
---@param target StatsBookTarget?
function Book:Open(target)
	if target then
		self.router:Open(target)
	end
	local frame = self.frame or build(self)
	self.frame = frame
	if not frame:IsShown() then
		listen(self)
		position(frame)
		frame:Show()
		self.ticker = C_Timer.NewTicker(ns.LIVE_LINE_TICK, function()
			self:Tick()
		end)
	end
	self:Draw()
end

--- Closes the book.
function Book:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self:Hidden()
end

--- The book has closed, however it closed (its close button, Esc, a toggle): the tick stops.
function Book:Hidden()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

--- The open page redraws on the next frame, once however many ask in this one (STA-R73), keeping its place, choice and
--- scroll; nothing while the book is closed.
function Book:QueueDraw()
	if self:IsShown() then
		self.drawNextFrame()
	end
end

--- The live-line tick (STA-R73): the live line refreshes, and the whole home spread when it shows.
function Book:Tick()
	if not self:IsShown() then
		return
	end
	if self.router:Place().page == "home" then
		self:Draw()
	else
		self:DrawLive()
	end
end

-- Side `side` of page `page`: its scroll frame and content on the side's body, made at its first draw. The content
-- scrolls with the mouse wheel when the renderer draws more than the body holds (STA-R70).
---@param book StatsBook
---@param page StatsBookPage
---@param side StatsBookSide
---@return StatsBookPageView
local function pageOf(book, page, side)
	local key = page .. ":" .. side
	local view = book.pages[key]
	if not view then
		local body = (book.frame --[[@as StatsBookFrame]]).bodies[side]
		local scroll = CreateFrame("ScrollFrame", nil, body) --[[@as ScrollFrame]]
		scroll:SetAllPoints()
		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(BODY_WIDTH, BODY_HEIGHT)
		scroll:SetScrollChild(content)
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local offset = self:GetVerticalScroll() - delta * WHEEL_STEP
			self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
		end)
		view = { scroll = scroll, content = content }
		book.pages[key] = view
	end
	return view
end

-- A place as a key, to tell a redraw of the same place from a new one.
---@param place StatsBookTarget
---@return string
local function keyOf(place)
	return table.concat({
		place.page,
		tostring(place.area),
		tostring(place.item),
		tostring(place.session),
		tostring(place.ledgerPage),
	}, ":")
end

-- The zone an area is in, for the breadcrumbs: Core's catalogue, else the projection's record of it, else the live
-- conditions when it is the current subzone; an area none of them knows reads as a zone.
---@param area integer
---@return integer
local function zoneOf(area)
	local zone = Pagle.GetZoneOf(area)
	if zone then
		return zone
	end
	local record = not ns.IsUpdating() and ns.State().places[area]
	if record then
		return record.zone
	end
	local conditions = Pagle.GetConditions()
	if conditions.subzone == area and conditions.zone ~= 0 then
		return conditions.zone
	end
	return area
end

-- The kicker of the Session ribbon page: "My last Session" with no Session open and one on record, else "This
-- Session" (STA-R74, STA-R32).
---@return string
local function sessionKicker()
	local sessions = ns.IsUpdating() and {} or ns.State().sessions
	local shown = ns.CurrentSession(sessions, Pagle.GetSession())
	return (shown and shown.kind == "last") and L.BOOK_LAST_SESSION or L.BOOK_THIS_SESSION
end

-- A crumb's words.
---@param book StatsBook
---@param crumb StatsBookCrumb
---@return string
local function crumbWords(book, crumb)
	local kind = crumb.kind
	if kind == "stats" then
		return L.BOOK_ROOT
	elseif kind == "zone" or kind == "subzone" then
		return ns.AreaName(crumb.id --[[@as integer]])
	elseif kind == "item" then
		return (
			book:Item(crumb.id --[[@as integer]])
		)
	elseif crumb.id == "session" then
		return sessionKicker()
	end
	return crumb.id == "lifetime" and L.BOOK_LIFETIME or L.BOOK_SESSIONS
end

-- Crumb `i` of the strip, made on first use: its gilt words and, after the first, the fleuron before them.
---@param frame StatsBookFrame
---@param i integer
---@return StatsBookCrumbView
local function crumbAt(frame, i)
	local crumb = frame.crumbButtons[i]
	if not crumb then
		crumb = CreateFrame("Button", nil, frame.crumbs) --[[@as StatsBookCrumbView]]
		if i > 1 then
			crumb.fleuron = ns.NewBookMark(crumb, "fleuron", 12)
			crumb.fleuron:SetPoint("LEFT", 4, 0)
		end
		crumb.label = ns.BookText(crumb, ns.BookFonts().crumb, LOOK.gilt)
		crumb.label:SetPoint("LEFT", i > 1 and 22 or 0, 0)
		crumb:SetScript("OnEnter", function(self)
			if self:GetScript("OnClick") then
				self.label:SetTextColor(LOOK.giltBright[1], LOOK.giltBright[2], LOOK.giltBright[3])
			end
		end)
		crumb:SetScript("OnLeave", function(self)
			self.label:SetTextColor(LOOK.gilt[1], LOOK.gilt[2], LOOK.gilt[3])
		end)
		frame.crumbButtons[i] = crumb
	end
	return crumb
end

-- Lays the breadcrumbs along the strip (STA-R74), each opening what it names but the one that names the page itself
-- on a place page.
---@param book StatsBook
local function drawCrumbs(book)
	local frame = book.frame --[[@as StatsBookFrame]]
	local trail = book.router:Trail(zoneOf)
	local x = 0
	for i, data in ipairs(trail) do
		local crumb = crumbAt(frame, i)
		crumb.label:SetText(crumbWords(book, data))
		crumb.label:SetTextColor(LOOK.gilt[1], LOOK.gilt[2], LOOK.gilt[3])
		local width = crumb.label:GetStringWidth() + (i > 1 and 24 or 2)
		crumb:SetSize(width, 20)
		crumb:ClearAllPoints()
		crumb:SetPoint("LEFT", x, 0)
		local target = data.target
		crumb:SetScript("OnClick", target and function()
			book:Open(target)
		end or nil)
		crumb:Show()
		x = x + width
	end
	for i = #trail + 1, #frame.crumbButtons do
		frame.crumbButtons[i]:Hide()
	end
end

-- The nameplate (stats.md › UI › On the leather): the lifetime Casts, the Sessions and the first Cast's date, "No
-- Casts yet" with none, or "Updating my records…" while the projection updates (STA-R72).
---@param frame StatsBookFrame
---@param updating boolean
local function drawPlate(frame, updating)
	local text
	if updating then
		text = L.BOOK_UPDATING
	else
		local state = ns.State()
		local casts = state.totals.casts
		if casts == 0 then
			text = L.BOOK_NO_CASTS
		else
			local sessions = ns.Count(#state.sessions, "Sessions")
			local first = ns.FirstCastTime(state.sessions)
			text = first and L.BOOK_NAMEPLATE:format(ns.Count(casts, "Casts"), sessions, ns.Date(first))
				or L.BOOK_NAMEPLATE_UNDATED:format(ns.Count(casts, "Casts"), sessions)
		end
	end
	frame.plate:SetPlate(text)
end

--- Draws the live line (STA-R75): during a current Session, its Casts, Catches and time so far; from Core's Session
--- alone while the projection updates or has no record of it yet (STA-R72).
function Book:DrawLive()
	local frame = self.frame
	if not frame then
		return
	end
	local live = Pagle.GetSession()
	if live == nil then
		frame.live:Hide()
		return
	end
	local session = live ---@type StatsSession|PagleSession
	if not ns.IsUpdating() then
		local shown = ns.CurrentSession(ns.State().sessions, live)
		if shown and shown.kind == "current" then
			session = shown.record --[[@as StatsSession]]
		end
	end
	frame.live.label:SetText(
		L.BOOK_LIVE_LINE:format(
			ns.Count(session.casts, "Casts"),
			ns.Count(session.catches, "Catches"),
			ns.Duration(ns.TimeFished(session, GetServerTime()))
		)
	)
	frame.live:SetWidth(frame.live.label:GetStringWidth() + 15)
	frame.live:Show()
end

--- Draws the page shown, if the book is open: each side with its renderer, on its own scrolling frame, a side with
--- none left blank, or "Updating my records…" on both while the projection updates (STA-R72); then the leather: the
--- breadcrumbs, the ribbons, the nameplate, the live line and the anchors, which so see what the pages chose.
function Book:Draw()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end
	local place = self.router:Place()
	local updating = ns.IsUpdating()
	local key = keyOf(place)
	local moved = key ~= self.drawnKey
	self.drawnKey = key
	for _, view in pairs(self.pages) do
		view.scroll:Hide()
	end
	for _, side in ipairs(ns.BOOK_SIDES) do
		frame.updating[side]:SetShown(updating)
		local renderer = not updating and self.router:Renderer(place.page, side)
		if renderer then
			local view = pageOf(self, place.page, side)
			view.scroll:Show()
			local height = renderer(view.content, self.router:Place())
			view.content:SetHeight(math.max(1, height or BODY_HEIGHT))
			if moved then
				view.scroll:SetVerticalScroll(0)
			end
		end
	end
	drawCrumbs(self)
	local chosen = ns.ChosenRibbon(place, ns.CurrentPlace(Pagle.GetConditions()))
	for i, ribbon in ipairs(frame.ribbons) do
		ribbon:SetRibbon(ribbon.words, ns.BOOK_RIBBONS[i].green, ribbon.id == chosen)
	end
	drawPlate(frame, updating)
	self:DrawLive()
	for _, part in ipairs(LEATHER_PARTS) do
		local renderer = self.leatherRenderers[part]
		if renderer then
			renderer(frame.anchors[part], self.router:Place(), updating)
		end
	end
end

-- The book's entry points (logic/Seams.lua lists them); every caller calls them through ns at call time.

--- Opens or closes the Stats book (STA-R70): Registration's view and `/pagle stats`, so the compartment's "Stats" and
--- the status button's "Open Stats" too (STA-R4), and the tracker header (#218).
function ns.ToggleBook()
	ns.book:Toggle()
end

--- Opens the Stats book on `target`, or where it was left with none (STA-R70); open, it turns there and never closes.
---@param target StatsBookTarget?
function ns.OpenBook(target)
	ns.book:Open(target)
end

-- The book redraws its page at every redraw while open (STA-R73): the projection's and the watches'.
ns.OnRedraw(function()
	ns.book:QueueDraw()
end)
