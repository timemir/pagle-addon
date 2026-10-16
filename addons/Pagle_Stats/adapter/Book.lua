if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book on the client (STA-R70–R75; stats.md › UI): a leather binding with two parchment pages, the gilt
-- breadcrumbs and the search box's anchor on the strip above them, the brass nameplate and the live line on the
-- leather's foot band below them, brass corners, and the ribbons hanging from under its foot, drawing on each page what
-- logic/Book.lua's router says the page shown puts there. The pages' contents are the page files' renderers
-- (adapter/Home.lua to Lifetime.lua); this file draws only the book. It makes no secure frames, so it opens and works
-- in combat and while restricted (STA-R71, STA-R93). The look is the books art kit's Stats book, in
-- adapter/BookWidgets.lua's art.

local L = ns.L
local LOOK = ns.BOOK_LOOK

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (STA-R70).
local FRAME_NAME = "PagleStatsBook"
-- About 980 × 640 (Tunables), as the kit's: the leather at the sides, the strip above the pages for the crumbs and the
-- search box, and the foot band below them for the nameplate and the live line.
local WIDTH, HEIGHT = 980, 640
local SIDE, STRIP, FOOT = 18, 38, 36
local PAGE_WIDTH = (WIDTH - 2 * SIDE) / 2
local PAGE_HEIGHT = HEIGHT - STRIP - FOOT
-- A page body's padding inside the paper.
local PAD_X, PAD_TOP, PAD_BOTTOM = 28, 22, 20
local BODY_WIDTH, BODY_HEIGHT = PAGE_WIDTH - 2 * PAD_X, PAGE_HEIGHT - PAD_TOP - PAD_BOTTOM
-- The search box's room at the strip's right (the kit's 250).
local SEARCH_WIDTH, SEARCH_HEIGHT = 250, 26
-- The strip's middle: halfway between the band's inner edge (the tiled leather starts 7 in) and the pages, where the
-- crumbs and the search slip sit with even room above and below.
local STRIP_MIDDLE = (7 + STRIP) / 2
-- Where the ribbons hang from under the leather's foot, from its left.
local RIBBONS_LEFT = 456
-- How far above the screen's centre the book opens: half the ribbons' hang under it.
local RIBBONS_LIFT = 40
-- The nameplate's place on the foot band, and the live line's right end and foot.
local PLATE_X, PLATE_Y, LIVE_RIGHT, LIVE_FOOT = 30, 605, 30, 9
-- How far a mouse wheel notch scrolls a page body.
local WHEEL_STEP = 40
-- The book's whole extent in its own units, for fitting it to the screen (adapter/Fit.lua): the wax close button
-- reaches past its top right, the chosen ribbon hangs 84 under its foot.
local EXTENT_WIDTH, EXTENT_HEIGHT = WIDTH + 30, HEIGHT + 100
-- The order of the spreads, for a page turn's direction: the ribbons' order, the home spread first, an item's page
-- after a place's.
local TURN_ORDER = { home = 0, place = 1, item = 1.5, session = 2, lifetime = 3, sessions = 4 }
-- Opening fades in, closing fades out (the kit's MOTION.md), in seconds.
local OPEN_FADE, CLOSE_FADE = 0.16, 0.12
-- The live dot's glow breathes between these, each way in this long (the kit's StatsBreathe).
local BREATHE_LOW, BREATHE_HIGH, BREATHE = 0.35, 0.8, 1.2

-- The owner of the book's Core callbacks and WoW event registrations (CORE-R23).
local OWNER = "Pagle_Stats book"

--- The leather's anchors the page files draw into: the search box (adapter/Search.lua).
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
---@field glow Texture
---@field label FontString

---@class StatsBookRibbonButton: StatsBookRibbonView
---@field id "here"|"session"|"lifetime"|"sessions"
---@field words string

---@class StatsBookFrame: Frame
---@field close StatsBookCloseButton
---@field leather StatsBookLeatherView
---@field corners Texture[]
---@field papers table<StatsBookSide, StatsBookParchmentView>
---@field paperFrames table<StatsBookSide, Frame>     -- each page's paper, which a turn's wipes measure
---@field turnFold Frame?                             -- the page turn's fold (adapter/BookMotion.lua)
---@field bodies table<StatsBookSide, Frame>          -- each page's body, inside its padding
---@field updating table<StatsBookSide, FontString>   -- "Updating my records…" on each body (STA-R72)
---@field crumbs Frame
---@field crumbButtons StatsBookCrumbView[]
---@field live StatsBookLiveView
---@field plate StatsBookPlateView
---@field ribbons StatsBookRibbonButton[]
---@field anchors table<StatsBookLeatherPart, Frame>

--- One side of one page: the clip frame on the side's paper that a page turn narrows (adapter/BookMotion.lua), its
--- scroll frame over the side's body, and the content the renderer draws on.
---@class StatsBookPageView: StatsTurnSide
---@field scroll ScrollFrame
---@field content Frame

--- A page turn under way: the sides it turns from and to, and the owner its motion plays on.
---@class StatsBookTurning
---@field from table<StatsBookSide, StatsBookPageView>
---@field to table<StatsBookSide, StatsBookPageView>
---@field owner table?

--- The Stats book: its router, its frame once made, and each page's sides.
---@class StatsBook
---@field router StatsBookRouter
---@field frame StatsBookFrame?
---@field pages table<string, StatsBookPageView>   -- by "page:side", made at their first draw
---@field private leatherRenderers table<StatsBookLeatherPart, StatsBookLeatherRenderer>
---@field private drawnKey string?                 -- the place last drawn, to keep its scroll on a redraw
---@field private drawnPage StatsBookPage?          -- the page last drawn, which a turn turns from
---@field drawnSides table<StatsBookSide, StatsBookPageView> -- its sides
---@field turning StatsBookTurning?          -- the page turn under way
---@field closing table?                             -- the close fading out now: its owner, which the fade runs on
---@field private breathing boolean                  -- the live dot breathes
---@field private liveCasts integer?                 -- the live line's Casts when last drawn
---@field private drawNextFrame fun()              -- QueueDraw's redraw, once per frame (ns.OncePerFrame)
---@field private ticker table?                    -- the live-line tick, while open
---@field listening boolean                        -- Core's events are subscribed
---@field private showing integer                  -- how many times it has closed: which showing this is
---@field private requestItem fun(itemID: integer) -- the book's item loader (ns.NewItemLoader)
local Book = {}
Book.__index = Book

--- The book, on the home spread until it is first left: a login or `/reload` starts it afresh (STA-R70).
ns.book = setmetatable({
	router = ns.NewBookRouter(),
	pages = {},
	leatherRenderers = {},
	listening = false,
	showing = 0,
	drawnSides = {},
	breathing = false,
	drawNextFrame = ns.OncePerFrame(function()
		ns.book:Draw()
	end),
	requestItem = ns.NewItemLoader(OWNER, function()
		ns.book:QueueDraw()
	end),
}, Book)

--- Registers `renderer` to draw side `side` of page `page` (logic/Book.lua lists the pages and who draws them); a
--- later registration replaces it. The page files call it when they load (after this one in the TOC).
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
		frame:SetPoint("CENTER", 0, RIBBONS_LIFT) -- up a little, so the ribbons hanging under it stay on screen
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
	frame.paperFrames[side] = paper
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

-- The live line (STA-R75): the glowing green dot and its gilt words at the foot band's right, opening This Session.
---@param book StatsBook
---@param frame StatsBookFrame
local function buildLive(book, frame)
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
		book:Open({ page = "session" })
	end)
	live:Hide()
	frame.live = live
end

-- The ribbons (STA-R74), left to right under the leather's foot, their tops tucked under its band, each opening its
-- page.
---@param book StatsBook
---@param frame StatsBookFrame
local function buildRibbons(book, frame)
	local words = {
		here = L.BOOK_WHERE_I_AM,
		session = L.BOOK_THIS_SESSION,
		lifetime = L.BOOK_LIFETIME,
		sessions = L.BOOK_SESSIONS,
	}
	local sizes = ns.BOOK_RIBBON
	frame.ribbons = {}
	for i, data in ipairs(ns.BOOK_RIBBONS) do
		local ribbon = ns.NewBookRibbon(frame) --[[@as StatsBookRibbonButton]]
		ribbon:SetFrameLevel(frame:GetFrameLevel() + 1) -- under the band, 6 levels up: its tucked top hides
		ribbon.id, ribbon.words = data.id, words[data.id]
		ribbon:SetRibbon(ribbon.words, LOOK.ribbons[data.id], false)
		ribbon:SetPoint(
			"TOPLEFT",
			frame,
			"TOPLEFT",
			RIBBONS_LEFT + (i - 1) * (sizes.width + sizes.gap),
			-(HEIGHT - sizes.tuck)
		)
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
	-- the ribbons hang under the leather: the clamp keeps them on screen too
	frame:SetClampRectInsets(0, 0, 0, -(ns.BOOK_RIBBON.lengthChosen - ns.BOOK_RIBBON.tuck))
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
	frame.corners = ns.NewBookCorners(frame)
	frame.papers, frame.paperFrames, frame.bodies, frame.updating = {}, {}, {}, {}
	buildPage(frame, "left")
	buildPage(frame, "right")

	frame.crumbs = CreateFrame("Frame", nil, frame)
	frame.crumbs:SetPoint("TOPLEFT", SIDE + 6, -(STRIP_MIDDLE - 10))
	frame.crumbs:SetSize(WIDTH - 2 * SIDE - SEARCH_WIDTH - 40, 20)
	frame.crumbButtons = {}
	local search = CreateFrame("Frame", nil, frame)
	search:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
	search:SetPoint("TOPRIGHT", -(SIDE + 6), -(STRIP_MIDDLE - SEARCH_HEIGHT / 2))
	frame.anchors = { search = search }
	buildLive(book, frame)

	frame.plate = ns.NewBookPlate(frame)
	frame.plate:SetPoint("TOPLEFT", frame, "TOPLEFT", PLATE_X, -PLATE_Y)
	frame.plate:SetFrameLevel(frame:GetFrameLevel() + 10)
	buildRibbons(book, frame)

	frame.close = ns.NewBookClose(frame)
	frame.close:SetPoint("CENTER", frame, "TOPRIGHT", -3, -3)
	frame.close:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.close:SetScript("OnClick", function()
		book:Hide()
	end)
	-- hidden before it hears its OnHide: the close sound is for a book that was open
	frame:Hide()
	frame:SetScript("OnHide", function()
		book:Hidden()
		ns.BookSound("close")
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
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
	ns.OnReadingsMove(OWNER, function()
		book:QueueDraw()
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
	if self:IsShown() and not self.closing then
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
	local turnable = frame:IsShown() and not self.closing
	if self.closing then
		-- opened again while fading out: it stays, whole
		ns.StopMotion(self.closing)
		self.closing = nil
		frame:SetAlpha(1)
	end
	if not frame:IsShown() then
		listen(self)
		position(frame)
		ns.FitToScreen(frame, EXTENT_WIDTH, EXTENT_HEIGHT)
		frame:Show()
		ns.BookSound("open")
		-- it fades in (0.16 s, ease-out), the kit's OpenBook
		ns.SyncMotion()
		ns.Animate(frame, {
			{
				dur = OPEN_FADE,
				ease = ns.Ease.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					frame:SetAlpha(v[1])
				end,
			},
		})
		self.ticker = C_Timer.NewTicker(ns.LIVE_LINE_TICK, function()
			self:Tick()
		end)
	end
	self:Draw(turnable)
end

--- Closes the book: it fades out (0.12 s, easing in), the kit's CloseBook, then hides; at once with the motion off.
--- The fade runs on an owner of its own, never the frame, which the driver would drop unfinished were the frame to stop
--- showing mid-fade (UIParent hidden), stranding the close; and the close ends on the clock too, after the fade's
--- time, so it ends whether or not frames are drawn.
function Book:Hide()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		self:Hidden()
		return
	end
	if self.closing then
		return
	end
	if not ns.SyncMotion() then
		frame:Hide()
		self:Hidden()
		return
	end
	local closing = {}
	self.closing = closing
	ns.StopMotion(frame) -- an opening fade still running gives way
	-- this close's end, once: a later open or close has its own
	local function finish()
		if self.closing == closing then
			ns.StopMotion(closing)
			self.closing = nil
			frame:Hide()
			frame:SetAlpha(1)
		end
	end
	ns.Animate(closing, {
		{
			dur = CLOSE_FADE,
			ease = ns.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	}, finish)
	C_Timer.After(CLOSE_FADE, finish)
end

-- Settles the page turn under way, if any, at once: its new spread whole, its old one gone.
---@param book StatsBook
local function settleTurn(book)
	local turning = book.turning
	if not turning then
		return
	end
	book.turning = nil
	if turning.owner then
		ns.StopMotion(turning.owner)
	end
	for _, view in pairs(turning.from) do
		view.clip:Hide()
	end
	for _, view in pairs(book.drawnSides) do
		ns.RevealSide(view, 0, 1)
	end
	local fold = book.frame and book.frame.turnFold
	if fold then
		fold:Hide()
	end
end

--- Which showing of the book this is: it changes each time the book closes. A page drawn earlier in the same showing
--- has been on show since, so what changed on it may move into place; one drawn before the book last closed draws
--- settled, as what changed while it was closed was never seen (adapter/Entry.lua's readings).
---@return integer
function Book:Showing()
	return self.showing
end

--- The book has closed, however it closed (its close button, Esc, a toggle): the tick stops, a turn under way
--- settles, the live dot rests, and the next showing begins.
function Book:Hidden()
	self.showing = self.showing + 1
	if self.closing then
		ns.StopMotion(self.closing)
		self.closing = nil
	end
	settleTurn(self)
	local frame = self.frame
	if frame then
		frame:SetAlpha(1)
		if self.breathing then
			ns.StopMotion(frame.live.glow)
		end
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

-- Side `side` of page `page`: its clip frame on the side's paper, and its scroll frame and content over the side's
-- body, made at its first draw. The content scrolls with the mouse wheel when the renderer draws more than the body
-- holds (STA-R70); the clip, the paper's whole width, is what a page turn narrows.
---@param book StatsBook
---@param page StatsBookPage
---@param side StatsBookSide
---@return StatsBookPageView
local function pageOf(book, page, side)
	local key = page .. ":" .. side
	local view = book.pages[key]
	if not view then
		local frame = book.frame --[[@as StatsBookFrame]]
		local body, paper = frame.bodies[side], frame.paperFrames[side]
		local clip = CreateFrame("Frame", nil, paper)
		clip:SetClipsChildren(true)
		clip:SetAllPoints()
		local scroll = CreateFrame("ScrollFrame", nil, clip) --[[@as ScrollFrame]]
		scroll:SetAllPoints(body)
		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(BODY_WIDTH, BODY_HEIGHT)
		scroll:SetScrollChild(content)
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local offset = self:GetVerticalScroll() - delta * WHEEL_STEP
			self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
		end)
		view = { clip = clip, paper = paper, scroll = scroll, content = content }
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
			crumb.fleuron = ns.NewBookMark(crumb, "fleuron", 16)
			crumb.fleuron:SetPoint("LEFT", 8, 0)
		end
		crumb.label = ns.BookText(crumb, ns.BookFonts().crumb, LOOK.gilt)
		crumb.label:SetPoint("LEFT", i > 1 and 32 or 0, 0)
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
		-- the last crumbs are cut short, never past the strip's room before the search slip
		local lead = i > 1 and 34 or 2
		ns.BookBound(crumb.label, frame.crumbs:GetWidth() - x - lead)
		local width = crumb.label:GetWidth() + lead
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
		if self.breathing then
			ns.StopMotion(frame.live.glow)
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
	frame.live.label:SetText(
		L.BOOK_LIVE_LINE:format(
			ns.Count(session.casts, "Casts"),
			ns.Count(session.catches, "Catches"),
			ns.Duration(ns.TimeFished(session, GetServerTime()))
		)
	)
	frame.live:SetWidth(frame.live.label:GetStringWidth() + 18)
	frame.live:Show()
	-- a Cast rewrites the line, its ink fading up (the kit's MOTION.md)
	if self.liveCasts and self.liveCasts ~= session.casts then
		ns.InkIn(frame.live.label)
	end
	self.liveCasts = session.casts
	-- the dot breathes for as long as the book is open in a Session: its glow 35% to 80%, 1.2 s each way
	if not self.breathing then
		self.breathing = true
		local glow = frame.live.glow
		ns.SyncMotion()
		ns.Animate(glow, {
			{
				dur = BREATHE,
				ease = ns.Ease.inOut,
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

--- Draws the page shown, if the book is open: each side with its renderer, on its own scrolling frame, a side with
--- none left blank, or "Updating my records…" on both while the projection updates (STA-R72); then the leather: the
--- breadcrumbs, the ribbons, the nameplate, the live line and the anchors, which so see what the pages chose. With
--- `turnable` (the book was open and is asked somewhere else), a new spread comes in by the page turn
--- (adapter/BookMotion.lua): forward to a later ribbon, backward to an earlier one, the crumbs changing as the leaf
--- passes the spine, the ribbons' lengths easing.
---@param turnable boolean?
function Book:Draw(turnable)
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end
	local place = self.router:Place()
	local updating = ns.IsUpdating()
	local key = keyOf(place)
	local moved = key ~= self.drawnKey
	self.drawnKey = key
	local fromPage, fromSides = self.drawnPage, self.drawnSides
	local turn = turnable and not updating and fromPage ~= nil and fromPage ~= place.page
	if turn then
		settleTurn(self)
	end
	-- what a turn shows besides the page drawn: the spread it turns from
	local keep = {}
	local turning = self.turning
	for _, sides in ipairs({ turning and turning.from or {}, turning and turning.to or {}, turn and fromSides or {} }) do
		for _, view in pairs(sides) do
			keep[view] = true
		end
	end
	for _, view in pairs(self.pages) do
		if not keep[view] then
			view.clip:Hide()
		end
	end
	local sides = {}
	for _, side in ipairs(ns.BOOK_SIDES) do
		frame.updating[side]:SetShown(updating)
		local renderer = not updating and self.router:Renderer(place.page, side)
		if renderer then
			local view = pageOf(self, place.page, side)
			if not keep[view] then
				ns.RevealSide(view, 0, 1)
			end
			local height = renderer(view.content, self.router:Place())
			view.content:SetHeight(math.max(1, height or BODY_HEIGHT))
			if moved then
				view.scroll:SetVerticalScroll(0)
			end
			sides[side] = view
		end
	end
	self.drawnPage = not updating and place.page or nil
	self.drawnSides = sides
	if turn then
		---@type StatsBookTurning
		local turnNow = { from = fromSides, to = sides }
		self.turning = turnNow
		turnNow.owner = ns.PlayTurn(frame, {
			from = fromSides,
			to = sides,
			forward = (TURN_ORDER[place.page] or 0) > (TURN_ORDER[fromPage] or 0),
			papers = frame.paperFrames,
			midway = function()
				drawCrumbs(self)
			end,
			done = function()
				if self.turning == turnNow then
					settleTurn(self)
				end
			end,
		})
	else
		drawCrumbs(self)
	end
	local chosen = ns.ChosenRibbon(place, ns.CurrentPlace(Pagle.GetConditions()))
	for _, ribbon in ipairs(frame.ribbons) do
		ribbon:SetRibbon(ribbon.words, LOOK.ribbons[ribbon.id], ribbon.id == chosen, turnable)
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
