if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's book on the client (LED-R120–R123, LED-R125; ledger.md › UI): a leather frame with two parchment
-- pages, the gilt breadcrumbs and the search box's place on the leather above them, and the back link, drawing what
-- logic/Journal.lua's router says the pages show with adapter/JournalWidgets.lua's widgets. It makes no secure
-- frames, so it opens and works while restricted (LED-R121). The look follows prototypes/fish-journal/ variant E.

local L = ns.L
local LOOK = ns.JOURNAL_LOOK

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (LED-R120).
local FRAME_NAME = "PagleLedgerJournal"
local WIDTH, HEIGHT = 920, 600
-- The leather around the pages, and the strip above them for the crumbs and the search box.
local MARGIN, STRIP = 14, 40
local PAGE_WIDTH = (WIDTH - 2 * MARGIN) / 2
local PAGE_HEIGHT = HEIGHT - STRIP - MARGIN
-- A page body's inset from the paper's edges, and the room the back link takes under the left one.
local INSET, BACK_ROOM = 28, 30
-- The search box's width (LED-R148).
local SEARCH_WIDTH = 220
-- The spine's shadow: strips of fading shade at each page's inner edge.
local SPINE_STRIPS, SPINE_STRIP_WIDTH = 6, 5

---@class LedgerJournalCrumbView: LedgerJournalClickable
---@field label FontString
---@field separator FontString?

---@class LedgerJournalFrame: Frame
---@field close Button
---@field crumbs Frame                 -- the breadcrumbs' strip (LED-R125)
---@field crumbButtons LedgerJournalCrumbView[]
---@field search EditBox               -- the search box (LED-R148)
---@field searchDrop LedgerJournalSearchDrop -- its results (adapter/JournalSearch.lua)
---@field back LedgerJournalCrumbView  -- "☚ back", under the left page (LED-R125)
---@field left LedgerJournalPage
---@field right LedgerJournalPage
---@field plate LedgerJournalPlate     -- the brass plate on the cover (LED-R149)

---@class LedgerJournalPlate: Frame
---@field label FontString

--- The Fish Journal: its router, its frame once made, and what its pages and brass plate show as last drawn.
---@class LedgerJournal
---@field router LedgerJournalRouter
---@field frame LedgerJournalFrame?
---@field pages LedgerJournalPages?
---@field plate string?                -- the brass plate's words; nil while the projection updates (LED-R149)
---@field private redrawQueued boolean
---@field private drawnPlace LedgerJournalPlace?
local Journal = {}
Journal.__index = Journal

--- The Journal, on Home until it is first left (LED-R120): a login or `/reload` starts it afresh.
ns.journal = setmetatable({ router = ns.NewJournalRouter(ns.journalSpreads), redrawQueued = false }, Journal)

-- What the spreads read now (LED-R122, LED-R123): nothing of the state while the projection is updating.
---@return LedgerJournalContext
local function readContext()
	local projection = ns.projection
	local state = projection and not projection:IsUpdating() and projection:GetState() --[[@as LedgerState?]]
	if not state then
		return { updating = true, now = GetServerTime(), formatNumber = BreakUpLargeNumbers, text = ns.journalText }
	end
	return {
		updating = false,
		state = state,
		celebrated = ns.CelebratedSet(ns.db.global),
		now = GetServerTime(),
		formatNumber = BreakUpLargeNumbers,
		text = ns.journalText,
		world = ns.world,
		getItem = Pagle.GetItem,
		getArea = Pagle.GetArea,
		angler = Pagle.GetAngler(),
		openFieldReport = Pagle.OpenFieldReport,
	}
end

--- What the spreads, and the search box, read now (LED-R122, LED-R123, LED-R148).
---@return LedgerJournalContext
function Journal.Context()
	return readContext()
end

-- A thin rule in `color` along one edge of `frame`, `inset` in from it.
---@param frame Frame
---@param color number[]
---@param from FramePoint
---@param to FramePoint
---@param x number
---@param y number
---@param vertical boolean
local function rule(frame, color, from, to, x, y, vertical)
	local line = frame:CreateTexture(nil, "BORDER")
	ns.JournalPaint(line, color)
	line:SetPoint(from, x, y)
	line:SetPoint(to, vertical and x or -x, vertical and -y or y)
	if vertical then
		line:SetWidth(1)
	else
		line:SetHeight(1)
	end
end

-- The leather cover: its tint and grain, the dark outline and the gilt rule inside its edge.
---@param frame Frame
local function drawLeather(frame)
	ns.JournalSolid(frame, LOOK.leatherEdge, "BACKGROUND")
	local leather = ns.JournalSolid(frame, LOOK.leather, "BACKGROUND")
	leather:SetPoint("TOPLEFT", 2, -2)
	leather:SetPoint("BOTTOMRIGHT", -2, 2)
	local grain = frame:CreateTexture(nil, "BORDER")
	grain:SetTexture(ns.JOURNAL_TEXTURES.leather)
	grain:SetVertexColor(unpack(LOOK.leather))
	grain:SetAlpha(0.5)
	grain:SetPoint("TOPLEFT", 2, -2)
	grain:SetPoint("BOTTOMRIGHT", -2, 2)
	rule(frame, LOOK.giltRule, "TOPLEFT", "TOPRIGHT", 5, -5, false)
	rule(frame, LOOK.giltRule, "BOTTOMLEFT", "BOTTOMRIGHT", 5, 5, false)
	rule(frame, LOOK.giltRule, "TOPLEFT", "BOTTOMLEFT", 5, -5, true)
	rule(frame, LOOK.giltRule, "TOPRIGHT", "BOTTOMRIGHT", -5, -5, true)
end

-- One parchment page: the paper's tint and texture, and the spine's shadow at its inner edge.
---@param frame Frame
---@param side "left"|"right"
---@return Frame
local function drawPaper(frame, side)
	local paper = CreateFrame("Frame", nil, frame)
	paper:SetSize(PAGE_WIDTH, PAGE_HEIGHT)
	paper:SetPoint("BOTTOMLEFT", side == "left" and MARGIN or MARGIN + PAGE_WIDTH, MARGIN)
	ns.JournalSolid(paper, LOOK.paper, "BACKGROUND")
	local texture = paper:CreateTexture(nil, "BORDER")
	texture:SetTexture(ns.JOURNAL_TEXTURES.paper)
	texture:SetVertexColor(unpack(LOOK.paper))
	texture:SetAlpha(0.35)
	texture:SetAllPoints()
	local edge = side == "left" and "RIGHT" or "LEFT"
	for i = 1, SPINE_STRIPS do
		local strip = paper:CreateTexture(nil, "ARTWORK")
		ns.JournalPaint(strip, LOOK.spine, 0.4 * (SPINE_STRIPS - i + 1) / SPINE_STRIPS)
		strip:SetWidth(SPINE_STRIP_WIDTH)
		local x = (i - 1) * SPINE_STRIP_WIDTH * (side == "left" and -1 or 1)
		strip:SetPoint("TOP" .. edge, x, 0)
		strip:SetPoint("BOTTOM" .. edge, x, 0)
	end
	return paper
end

-- A page body on `paper`, inset from its edges, `bottom` up from its foot.
---@param paper Frame
---@param bottom number
---@return LedgerJournalPage
local function pageBody(paper, bottom)
	local page = ns.NewJournalPage(paper, PAGE_WIDTH - 2 * INSET)
	page:SetPoint("TOPLEFT", INSET, -INSET)
	page:SetPoint("BOTTOMRIGHT", -INSET, bottom)
	return page
end

-- A link on the book: text in `font` and `color` on a button sized to it, opening its place in `journal`.
---@param journal LedgerJournal
---@param parent Frame
---@param font Font
---@param color number[]
---@return LedgerJournalCrumbView
local function textButton(journal, parent, font, color)
	local button = CreateFrame("Button", nil, parent) --[[@as LedgerJournalCrumbView]]
	ns.JournalClickable(button)
	function button.open(place)
		journal:OpenPlace(place)
	end
	button.label = ns.JournalText(button, font, color)
	button.label:SetPoint("LEFT")
	return button
end

-- Sets a text button's text and sizes it to fit; returns its width.
---@param button LedgerJournalCrumbView
---@param text string
---@return number
local function setButtonText(button, text)
	button.label:SetText(text)
	local width = button.label:GetStringWidth() + 2
	button:SetSize(width, 20)
	return width
end

-- Builds the book, hidden: leather, two pages, the crumbs' strip, the search box, the back link and the close
-- button. Centred and not movable (ledger.md › UI); Esc hides it through UISpecialFrames.
---@param journal LedgerJournal
---@return LedgerJournalFrame
local function build(journal)
	local fonts = ns.JournalFonts()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as LedgerJournalFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	drawLeather(frame)

	frame.left = pageBody(drawPaper(frame, "left"), BACK_ROOM)
	frame.right = pageBody(drawPaper(frame, "right"), INSET)

	frame.crumbs = CreateFrame("Frame", nil, frame)
	frame.crumbs:SetPoint("TOPLEFT", MARGIN + 6, -10)
	frame.crumbs:SetSize(WIDTH - 2 * MARGIN - SEARCH_WIDTH - 60, 22)
	frame.crumbButtons = {}

	frame.search = CreateFrame("EditBox", nil, frame)
	frame.search:SetSize(SEARCH_WIDTH, 22)
	frame.search:SetPoint("TOPRIGHT", -(MARGIN + 30), -9)
	frame.search:SetAutoFocus(false)
	frame.search:SetFontObject(fonts.text)
	frame.search:SetTextColor(unpack(LOOK.ink))
	frame.search:SetTextInsets(8, 8, 0, 0)
	ns.JournalSolid(frame.search, LOOK.paper, "BACKGROUND")
	frame.search:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	frame.searchDrop = ns.AttachJournalSearch(journal, frame.search)

	local back = textButton(journal, frame, fonts.text, LOOK.red)
	back:SetPoint("BOTTOMLEFT", MARGIN + 16, MARGIN + 8)
	setButtonText(back, L.JOURNAL_BACK)
	frame.back = back

	-- The brass plate on the cover's lower corner, hanging over its edge as variant E's does (LED-R149), below the
	-- pages, so it covers only leather.
	local plate = CreateFrame("Frame", nil, frame) --[[@as LedgerJournalPlate]]
	plate:SetPoint("BOTTOMLEFT", -12, -14)
	ns.JournalSolid(plate, LOOK.brassEdge, "BACKGROUND")
	local brass = ns.JournalSolid(plate, LOOK.brass, "BORDER")
	brass:SetPoint("TOPLEFT", 1, -1)
	brass:SetPoint("BOTTOMRIGHT", -1, 1)
	plate.label = ns.JournalText(plate, fonts.plate, LOOK.brassText)
	plate.label:SetPoint("CENTER")
	frame.plate = plate

	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton") --[[@as Button]]
	frame.close:SetPoint("TOPRIGHT", -2, -2)
	frame.close:SetScript("OnClick", function()
		frame:Hide()
	end)

	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
	return frame
end

-- Crumb `i` of the strip, made on first use: its gilt label and, after the first, the ❧ before it.
---@param journal LedgerJournal
---@param i integer
---@return LedgerJournalCrumbView
local function crumbAt(journal, i)
	local frame = journal.frame --[[@as LedgerJournalFrame]]
	local crumb = frame.crumbButtons[i]
	if not crumb then
		local separator
		if i > 1 then
			separator = ns.JournalText(frame.crumbs, ns.JournalFonts().crumb, LOOK.giltRule)
			separator:SetText(L.JOURNAL_CRUMB_SEPARATOR)
		end
		crumb = textButton(journal, frame.crumbs, ns.JournalFonts().crumb, LOOK.gilt)
		crumb.separator = separator
		frame.crumbButtons[i] = crumb
	end
	return crumb
end

-- Lays the crumbs out along the strip, each opening its level (LED-R125).
---@param journal LedgerJournal
---@param crumbs LedgerCrumb[]
local function drawCrumbs(journal, crumbs)
	local frame = journal.frame --[[@as LedgerJournalFrame]]
	local x = 0
	for i, data in ipairs(crumbs) do
		local crumb = crumbAt(journal, i)
		local separator = crumb.separator
		if separator then
			separator:ClearAllPoints()
			separator:SetPoint("LEFT", x + 6, 0)
			separator:Show()
			x = x + separator:GetStringWidth() + 12
		end
		local width = setButtonText(crumb, data.label)
		crumb:ClearAllPoints()
		crumb:SetPoint("LEFT", x, 0)
		crumb.place = data.place
		crumb:Show()
		x = x + width
	end
	for i = #crumbs + 1, #frame.crumbButtons do
		local crumb = frame.crumbButtons[i]
		crumb:Hide()
		if crumb.separator then
			crumb.separator:Hide()
		end
	end
end

--- Whether the book is open.
---@return boolean
function Journal:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

--- Opens the book at the spread it was left on (Home at the first opening after a login or `/reload`), or closes it
--- (LED-R120). Every entry point calls it.
function Journal:Toggle()
	if self:IsShown() then
		(self.frame --[[@as LedgerJournalFrame]]):Hide()
	else
		self:Show()
	end
end

--- Opens the book, drawn as it stands now.
function Journal:Show()
	self.frame = self.frame or build(self)
	self.frame:Show()
	self:Draw()
end

--- Opens spread `id` with `args`, opening the book if it is closed (LED-R125). Does nothing, and returns false, when
--- no spread is registered as `id`.
---@param id string
---@param args table?
---@return boolean opened
function Journal:Open(id, args)
	if not self.router:Open(id, args) then
		return false
	end
	self:Show()
	return true
end

--- Opens `place`: its spread with its args (LED-R125). Every link, crumb, tile and search result opens through it.
---@param place LedgerJournalPlace
---@return boolean opened
function Journal:OpenPlace(place)
	return self:Open(place.id, place.args)
end

--- Draws both pages, the crumbs, the search box and the back link from the router now, if the book is open
--- (LED-R122, LED-R125).
function Journal:Draw()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end
	local context = readContext()
	local pages = self.router:Pages(context)
	self.pages = pages
	-- The brass plate shows on every spread; while the projection updates there is nothing yet to read (LED-R122).
	self.plate = not pages.updating and ns.BrassPlate(context --[[@as LedgerHomeContext]]) or nil
	frame.plate.label:SetText(self.plate or "")
	frame.plate:SetSize(frame.plate.label:GetStringWidth() + 20, 22)
	frame.plate:SetShown(self.plate ~= nil)
	local place = self.router:Place()
	local moved = place ~= self.drawnPlace
	self.drawnPlace = place
	frame.crumbs:SetShown(not pages.updating)
	frame.search:SetShown(not pages.updating)
	frame.back.place = pages.back
	frame.back:SetShown(pages.back ~= nil)
	drawCrumbs(self, pages.crumbs or {})
	local function open(target)
		self:OpenPlace(target)
	end
	ns.DrawJournalPage(frame.left, pages.left, open, moved)
	ns.DrawJournalPage(frame.right, pages.right, open, moved)
end

--- A live entry was applied (LED-R123): the open spread redraws on the next frame, once however many arrive in it,
--- keeping its place and selection.
function Journal:LiveApplied()
	self:QueueDraw()
end

--- The open spread redraws on the next frame, once however many ask in this one (LED-R123, LED-R126), keeping its
--- place and selection; nothing while the book is closed.
function Journal:QueueDraw()
	if self.redrawQueued or not self:IsShown() then
		return
	end
	self.redrawQueued = true
	C_Timer.After(0, function()
		self.redrawQueued = false
		self:Draw()
	end)
end

--- Opens or closes the Fish Journal: the view's `open` and `/pagle journal` (LED-R1).
function ns.ToggleJournal()
	ns.journal:Toggle()
end

--- `def` with the Journal's redraws added (LED-R122, LED-R123): after each live entry, on the next frame, and as the
--- projection's catch-up or rebuild finishes, after its own `done`.
---@param def PagleProjectionDef
---@return PagleProjectionDef
function ns.WithJournalRedraws(def)
	local apply, done = def.apply, def.done
	def.apply = function(state, record, mode)
		apply(state, record, mode)
		if mode == "live" then
			ns.journal:LiveApplied()
		end
	end
	def.done = function(state, info)
		if done then
			done(state, info)
		end
		ns.journal:Draw()
	end
	return def
end
