if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book on the client (STA-R70–R75; stats.md › UI), built on Core's book shell (Pagle.NewBook,
-- core/book.md, ADR 0016): Core draws the window, the binding, the two parchment pages, the crumbs, the nameplate, the
-- wax close and "?", the ribbons, and routes and turns between the pages logic/Book.lua names. This file hands the
-- shell the Stats book's pages, crumbs and ribbons, writes the nameplate, and draws what is the Stats book's own on
-- the leather: the search box's anchor on the strip and the live line on the foot band. The pages' contents are the
-- page files' renderers (adapter/Home.lua to Lifetime.lua). It makes no secure frames, so it opens and works in
-- combat and while restricted (STA-R71, STA-R93).

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (STA-R70).
local FRAME_NAME = "PagleStatsBook"
-- About 980 × 640 (Tunables), as the kit's: the leather at the sides, the strip above the pages for the crumbs and the
-- search box, and the foot band below them for the nameplate and the live line.
local WIDTH, HEIGHT = 980, 640
local SIDE, STRIP, FOOT = 18, 38, 36
-- The search box's room at the strip's right (the kit's 250).
local SEARCH_WIDTH, SEARCH_HEIGHT = 250, 26
-- The strip's middle: halfway between the band's inner edge (the tiled leather starts 7 in) and the pages, where the
-- crumbs and the search slip sit with even room above and below.
local STRIP_MIDDLE = (7 + STRIP) / 2
-- Where the ribbons hang from under the leather's foot, from its left.
local RIBBONS_LEFT = 456
-- The nameplate's place on the foot band, and the live line's right end and foot.
local PLATE_X, PLATE_Y, LIVE_RIGHT, LIVE_FOOT = 30, 605, 30, 9
-- The live dot's glow breathes between these, each way in this long (the kit's StatsBreathe).
local BREATHE_LOW, BREATHE_HIGH, BREATHE = 0.35, 0.8, 1.2

-- The owner of the book's Core callbacks and WoW event registrations (CORE-R23).
local OWNER = "Pagle_Stats book"

--- The leather's anchors the page files draw into: the search box (adapter/Search.lua).
---@alias StatsBookLeatherPart "search"

--- Draws one of the leather's anchors: `anchor` is its frame, `place` where the book is, `updating` whether the
--- projection is updating (STA-R72: search is then disabled).
---@alias StatsBookLeatherRenderer fun(anchor: Frame, place: StatsBookTarget, updating: boolean)

---@class StatsBookFrame: PagleBookFrame
---@field live StatsBookLiveView?

---@class StatsBookLiveView: Button
---@field dot Texture
---@field glow Texture
---@field label FontString

--- The Stats book: Core's shell under it, and the live line it draws on the leather.
---@class StatsBook
---@field shell PagleBook
---@field frame StatsBookFrame?                      -- the shell's frame, from the first opening
---@field router PagleBookRouter                   -- the shell's router
---@field pages table<string, PagleBookSideView>   -- each page's side as the shell draws it, by "page:side"
---@field private breathing boolean                  -- the live dot breathes
---@field private liveCasts integer?                 -- the live line's Casts when last drawn
---@field private ticker table?                      -- the live-line tick, while open
---@field listening boolean                          -- Core's events are subscribed
---@field private requestItem fun(itemID: integer)   -- the book's item loader (ns.NewItemLoader)
local Book = {}
-- The shell's parts a spec or a probe reads through the book: its frame, its router (`router:Place()`), and each
-- page's side as it draws it (`pages["place:right"].content`).
Book.__index = function(book, key)
	local shell = rawget(book, "shell")
	if key == "frame" then
		return shell.frame
	elseif key == "router" then
		return shell.router
	elseif key == "pages" then
		return setmetatable({}, {
			__index = function(_, page)
				return shell.views[page .. ":1"]
			end,
		})
	end
	return Book[key]
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
---@param crumb StatsBookCrumb
---@return string
local function crumbWords(crumb)
	local kind = crumb.kind
	if kind == "stats" then
		return L.BOOK_ROOT
	elseif kind == "zone" or kind == "subzone" then
		return ns.AreaName(crumb.id --[[@as integer]])
	elseif kind == "item" then
		return (
			ns.book:Item(crumb.id --[[@as integer]])
		)
	elseif crumb.id == "session" then
		return sessionKicker()
	end
	return crumb.id == "lifetime" and L.BOOK_LIFETIME or L.BOOK_SESSIONS
end

-- The ribbons as the shell hangs them (STA-R74): each opens its page, Where I am the current place.
---@return PagleBookRibbon[]
local function ribbons()
	local words = {
		here = L.BOOK_WHERE_I_AM,
		session = L.BOOK_THIS_SESSION,
		lifetime = L.BOOK_LIFETIME,
		sessions = L.BOOK_SESSIONS,
	}
	local list = {}
	for i, data in ipairs(ns.BOOK_RIBBONS) do
		list[i] = {
			id = data.id,
			text = words[data.id],
			color = LOOK.ribbons[data.id],
			target = data.page and { page = data.page } or function()
				return ns.WhereIAm(Pagle.GetConditions())
			end,
		}
	end
	return list
end

-- The nameplate (stats.md › UI › On the leather): the lifetime Casts, the Sessions and the first Cast's date, "No
-- Casts yet" with none, or "Updating my records…" while the projection updates (STA-R72).
---@param updating boolean
---@return string
local function plateWords(updating)
	if updating then
		return L.BOOK_UPDATING
	end
	local state = ns.State()
	local casts = state.totals.casts
	if casts == 0 then
		return L.BOOK_NO_CASTS
	end
	local sessions = ns.Count(#state.sessions, "Sessions")
	local first = ns.FirstCastTime(state.sessions)
	return first and L.BOOK_NAMEPLATE:format(ns.Count(casts, "Casts"), sessions, ns.Date(first))
		or L.BOOK_NAMEPLATE_UNDATED:format(ns.Count(casts, "Casts"), sessions)
end

-- The live line (STA-R75): the glowing green dot and its gilt words at the foot band's right, opening This Session.
---@param frame Frame
---@return StatsBookLiveView
local function buildLive(frame)
	local live = CreateFrame("Button", nil, frame) --[[@as StatsBookLiveView]]
	live:SetHeight(20)
	live:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LIVE_RIGHT, LIVE_FOOT)
	live:SetFrameLevel(frame:GetFrameLevel() + 10)
	live.glow = ns.NewBookDot(live, 14)
	live.glow:SetAlpha(0.35)
	live.glow:SetPoint("LEFT", 0, 0)
	live.dot = ns.NewBookDot(live, 8)
	live.dot:SetPoint("CENTER", live.glow, "CENTER")
	live.label = ns.BookText(live, ns.BookFonts().crumb, LOOK.live)
	live.label:SetPoint("LEFT", live.glow, "RIGHT", 4, 0)
	live:SetScript("OnClick", function()
		ns.book:Open({ page = "session" })
	end)
	live:Hide()
	return live
end

--- The book, on the home spread until it is first left: a login or `/reload` starts it afresh (STA-R70).
ns.book = setmetatable({
	listening = false,
	breathing = false,
	requestItem = ns.NewItemLoader(OWNER, function()
		ns.book:QueueDraw()
	end),
}, Book)

ns.book.shell = Pagle.NewBook({
	id = "stats",
	name = FRAME_NAME,
	width = WIDTH,
	height = HEIGHT,
	side = SIDE,
	strip = STRIP,
	foot = FOOT,
	pages = ns.BOOK_PAGES,
	home = { page = "home" },
	stripRoom = SEARCH_WIDTH + 28,
	plate = { x = PLATE_X, y = PLATE_Y },
	anchors = {
		search = {
			point = "TOPRIGHT",
			x = -(SIDE + 6),
			y = -(STRIP_MIDDLE - SEARCH_HEIGHT / 2),
			width = SEARCH_WIDTH,
			height = SEARCH_HEIGHT,
		},
	},
	ribbons = ribbons(),
	ribbonsLeft = RIBBONS_LEFT,
	-- the "?": the First look's notes again (ONB-R59, adapter/Look.lua); none on a Core without First looks (ONB-R90)
	help = {
		tooltip = L.LOOK_AGAIN,
		onClick = function()
			ns.ShowBookLookAgain()
		end,
	},
	trail = function(place)
		local trail, target = {}, place --[[@as StatsBookTarget]]
		for i, crumb in ipairs(ns.BookTrail(target, zoneOf)) do
			trail[i] = { text = crumbWords(crumb), target = crumb.target }
		end
		return trail
	end,
	chosenRibbon = function(place)
		return ns.ChosenRibbon(place --[[@as StatsBookTarget]], ns.CurrentPlace(Pagle.GetConditions()))
	end,
	notice = function()
		return ns.IsUpdating() and L.BOOK_UPDATING or nil
	end,
	onDraw = function(_, notice)
		ns.book.shell:SetPlate(plateWords(notice ~= nil))
		ns.book:DrawLive()
	end,
	onShow = function()
		ns.book.ticker = C_Timer.NewTicker(ns.LIVE_LINE_TICK, function()
			ns.book:Tick()
		end)
		-- its First look the first time it opens, once the spread it points at is drawn (ONB-R55, adapter/Look.lua)
		ns.ShowBookLook()
	end,
	onHide = function()
		ns.book:Hidden()
	end,
})

--- Registers `renderer` to draw side `side` of page `page` (logic/Book.lua lists the pages and who draws them); a
--- later registration replaces it. The page files call it when they load (after this one in the TOC).
---@param page StatsBookPage
---@param side StatsBookSide
---@param renderer StatsBookRenderer
function Book:RegisterPage(page, side, renderer)
	self.shell:RegisterPage(page, side, renderer)
end

--- Registers `renderer` to draw the leather's anchor `part` at every draw, after both pages; a later registration
--- replaces it. Raises on an anchor the leather doesn't have.
---@param part StatsBookLeatherPart
---@param renderer StatsBookLeatherRenderer
function Book:RegisterLeather(part, renderer)
	self.shell:RegisterLeather(part, function(anchor, place, notice)
		renderer(anchor, place --[[@as StatsBookTarget]], notice ~= nil)
	end)
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

-- Subscribes the book to what redraws it while open (STA-R73), once, at its first opening: so an inert Stats, which
-- never opens it, listens to nothing (CORE-R13).
---@param book StatsBook
local function listen(book)
	if book.listening then
		return
	end
	book.listening = true
	ns.OnReadingsMove(OWNER, function()
		book:QueueDraw()
	end)
end

--- Whether the book is open.
---@return boolean
function Book:IsShown()
	return self.shell:IsShown()
end

--- Where the book is, as a copy.
---@return StatsBookTarget
function Book:Place()
	return self.shell:Place() --[[@as StatsBookTarget]]
end

--- Opens the book where it was left (the home spread at the first opening after a login or `/reload`), or closes it
--- (STA-R70). Every entry point calls it.
function Book:Toggle()
	self.shell:SetHelpShown(ns.HasBookLook())
	listen(self)
	self.shell:Toggle()
end

--- Shows `target` (a StatsBookTarget), or where the book was left with none, opening the book if it is closed: where
--- it was left, or centred (STA-R71, BOOK-R5). Open, it turns there in place and never closes; `how` is the shell's
--- (BOOK-R30).
---@param target StatsBookTarget?
---@param how PagleBookOpenHow?
function Book:Open(target, how)
	self.shell:SetHelpShown(ns.HasBookLook())
	listen(self)
	self.shell:Open(target, how)
end

--- Closes the book: it fades out, then hides (BOOK-R4).
function Book:Hide()
	self.shell:Close()
end

--- Which showing of the book this is: it changes each time the book closes. A page drawn earlier in the same showing
--- has been on show since, so what changed on it may move into place; one drawn before the book last closed draws
--- settled, as what changed while it was closed was never seen (adapter/Entry.lua's readings).
---@return integer
function Book:Showing()
	return self.shell:Showing()
end

--- The side view drawn now on side `side`, while page `page` shows (BOOK-R21): its content frame is what the page's
--- renderer drew on. Nil otherwise.
---@param page StatsBookPage
---@param side StatsBookSide
---@return PagleBookSideView?
function Book:Drawn(page, side)
	local shell = self.shell
	if shell.drawnPage ~= page then
		return nil
	end
	return shell.drawnSides[side]
end

--- The book has closed, however it closed (its close button, Esc, a toggle): the tick stops and the live dot rests.
function Book:Hidden()
	local frame = self.frame
	if self.breathing and frame and frame.live then
		Pagle.StopMotion(frame.live.glow)
	end
	self.breathing = false
	self.liveCasts = nil -- the Casts made while it was closed were never seen: the line draws settled on opening
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

--- The open page redraws on the next frame, once however many ask in this one (STA-R73), keeping its place, choice and
--- scroll; nothing while the book is closed.
function Book:QueueDraw()
	self.shell:QueueDraw()
end

--- Draws the open page now (BOOK-R21).
function Book:Draw()
	self.shell:Draw()
end

--- The live-line tick (STA-R73): the live line refreshes, and the whole home spread when it shows.
function Book:Tick()
	if not self:IsShown() then
		return
	end
	if self:Place().page == "home" then
		self:Draw()
	else
		self:DrawLive()
	end
end

--- Draws the live line (STA-R75): during a current Session, its Casts, Catches and time so far; from Core's Session
--- alone while the projection updates or has no record of it yet (STA-R72).
function Book:DrawLive()
	local frame = self.frame
	if not frame then
		return
	end
	frame.live = frame.live or buildLive(frame)
	local line = frame.live --[[@as StatsBookLiveView]]
	local live = Pagle.GetSession()
	if live == nil then
		line:Hide()
		if self.breathing then
			Pagle.StopMotion(line.glow)
			self.breathing = false
		end
		self.liveCasts = nil
		return
	end
	local session = live ---@type StatsSession|PagleSession
	if not ns.IsUpdating() then
		local shown = ns.CurrentSession(ns.State().sessions, live)
		if shown and shown.kind == "current" then
			session = shown.record --[[@as StatsSession]]
		end
	end
	line.label:SetText(
		L.BOOK_LIVE_LINE:format(
			ns.Count(session.casts, "Casts"),
			ns.Count(session.catches, "Catches"),
			ns.Duration(ns.TimeFished(session, GetServerTime()))
		)
	)
	line:SetWidth(line.label:GetStringWidth() + 18)
	line:Show()
	-- a Cast rewrites the line, its ink fading up (the kit's MOTION.md)
	if self.liveCasts and self.liveCasts ~= session.casts then
		ns.InkIn(line.label)
	end
	self.liveCasts = session.casts
	-- the dot breathes for as long as the book is open in a Session: its glow 35% to 80%, 1.2 s each way
	if not self.breathing then
		self.breathing = true
		local glow = line.glow
		Pagle.Animate(glow, {
			{
				dur = BREATHE,
				ease = Pagle.EASE.inOut,
				iter = "infinite",
				dir = "alternate",
				keys = { { 0, { BREATHE_LOW } }, { 1, { BREATHE_HIGH } } },
				apply = function(v)
					glow:SetAlpha(v[1])
				end,
			},
		})
	end
end

-- The book's entry points (logic/Seams.lua lists them); every caller calls them through ns at call time.

--- Opens or closes the Stats book (STA-R70): Registration's view and `/pagle stats`, so the compartment's "Stats" and
--- the status button's "Open Stats" too (STA-R4), and the tracker header (adapter/Tracker.lua).
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
