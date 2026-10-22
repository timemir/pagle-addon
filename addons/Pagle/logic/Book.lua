---@class PagleNS
local ns = select(2, ...)

-- The book shell's pure logic (core/book.md, ADR 0016): the types of `Pagle.NewBook`, its options and its handle, and
-- the page router every book routes with. adapter/Book.lua draws the shell on the client and publishes
-- Pagle.NewBook; FakePagle builds the same on the widget fake (CORE-R18).

---@alias PagleBookSide "left"|"right"

--- A place in a book: its page and what that page keeps (BOOK-R20). The book's own fields, besides `page`.
---@class PagleBookPlace
---@field page string

--- One page of a book (BOOK-R20).
---@class PagleBookPageDef
---@field keeps? string[]   -- the place's fields it keeps besides `page` ({})
---@field needs? string     -- a field it can't do without
---@field order? number     -- its place in the turn order (0)

--- One crumb (BOOK-R24).
---@class PagleBookCrumb
---@field text string
---@field target? PagleBookPlace     -- nil: it does nothing (the page itself)

--- One ribbon (BOOK-R17, BOOK-R18).
---@class PagleBookRibbon
---@field id string
---@field text string
---@field color number[]                                  -- { r, g, b }, 0 to 1
---@field target PagleBookPlace|fun(): PagleBookPlace
---@field count? string                                   -- words under its name, in the hand (BOOK-R19)
---@field tooltip? string[]                               -- tooltip lines on hover (BOOK-R19)

--- A leather anchor's place (BOOK-R16): its `point` on the frame, `x`, `y` from that point, and its size.
---@class PagleBookAnchorDef
---@field point FramePoint
---@field x number
---@field y number
---@field width number
---@field height number

--- One side of one page as the shell draws it (BOOK-R21, BOOK-R33).
---@class PagleBookSideView
---@field clip Frame          -- on the side's paper, the page turn narrows it
---@field scroll ScrollFrame  -- over the body
---@field content Frame       -- what the renderer draws on
---@field paper Frame         -- the side's paper

---@class PagleBookTurn
---@field from table<PagleBookSide, PagleBookSideView?>
---@field to table<PagleBookSide, PagleBookSideView?>
---@field forward boolean
---@field papers table<PagleBookSide, Frame>

---@alias PagleBookTurnPhase "start"|"lift"|"midway"|"land"|"done"

---@class PagleBookOpenHow
---@field motion? "auto"|"turn"|"fade"|"still"   -- BOOK-R30 ("auto")
---@field forward? boolean                        -- a turn's direction, in place of the pages' order

---@class PagleBookOptions
---@field id string                        -- the book's key, unique: its saved position (BOOK-R5)
---@field name string                      -- the frame's global name, for UISpecialFrames (BOOK-R2)
---@field width number
---@field height number
---@field pages table<string, PagleBookPageDef>
---@field home PagleBookPlace              -- the first opening's place (BOOK-R20)
---@field strata? FrameStrata              -- ("HIGH")
---@field fixed? boolean                   -- never moves, never saved (BOOK-R6)
---@field dim? number                      -- the world's dim behind it, an alpha (BOOK-R6)
---@field pinned? string                   -- a binding good to wear always (BIND-R1)
---@field side? number                     -- the leather at the sides (18)
---@field strip? number                    -- the strip above the pages (38)
---@field foot? number                     -- the band below them (16)
---@field split? number                    -- the left page's width over the right's (1)
---@field pad? { x: number, top: number, bottom: number } -- a body's padding ({ x = 28, top = 22, bottom = 20 })
---@field stripRoom? number                -- the strip's room kept at its right, past the crumbs (0)
---@field trail? fun(place: PagleBookPlace): PagleBookCrumb[]   -- the crumbs (none)
---@field back? { text: string, target: fun(place: PagleBookPlace): PagleBookPlace? } -- the back link (BOOK-R13)
---@field plate? { x: number, y: number }  -- the nameplate's top left (BOOK-R14)
---@field help? { tooltip: string, onClick: fun() } -- the "?" (BOOK-R15)
---@field anchors? table<string, PagleBookAnchorDef> -- the leather anchors (BOOK-R16)
---@field ribbons? PagleBookRibbon[]       -- (BOOK-R18)
---@field ribbonsLeft? number              -- the first ribbon's left (40)
---@field chosenRibbon? fun(place: PagleBookPlace): string? -- the chosen ribbon's id (BOOK-R18)
---@field notice? fun(): string?           -- words both pages show in place of their renderers (BOOK-R22)
---@field onLook? fun(look: PagleBindingLook)  -- after the shell inks its own parts (BOOK-R10)
---@field onDraw? fun(place: PagleBookPlace, notice: string?) -- last at each draw (BOOK-R21)
---@field onTurn? fun(turn: PagleBookTurn, phase: PagleBookTurnPhase, k: number?) -- the turn's hook (BOOK-R33)
---@field how? fun(from: PagleBookPlace, to: PagleBookPlace): PagleBookOpenHow? -- an Open's how when it gives none (BOOK-R34)
---@field onShow? fun()
---@field onHide? fun()

---@class PagleBookFrame: Frame
---@field papers table<PagleBookSide, Frame>    -- each page's paper
---@field bodies table<PagleBookSide, Frame>    -- each page's body, inside its padding

---@class PagleBook
---@field frame PagleBookFrame?                       -- nil until the first opening (BOOK-R1)
---@field binding PagleBookBinding?                   -- Core's renderer, from the first opening (BOOK-R10)
---@field anchors table<string, Frame>                -- the leather anchors, from the first opening (BOOK-R16)
---@field RegisterPage fun(self, page: string, side: PagleBookSide, renderer: fun(content: Frame, place: PagleBookPlace): number?)
---@field RegisterLeather fun(self, name: string, renderer: fun(anchor: Frame, place: PagleBookPlace, notice: string?))
---@field Open fun(self, place: PagleBookPlace?, how: PagleBookOpenHow?)
---@field Close fun(self)
---@field Settle fun(self)                            -- ends every motion at once (BOOK-R35)
---@field Toggle fun(self)
---@field IsShown fun(self): boolean
---@field Showing fun(self): integer
---@field Place fun(self): PagleBookPlace
---@field Draw fun(self)
---@field QueueDraw fun(self)
---@field SetRibbons fun(self, ribbons: PagleBookRibbon[])
---@field SetPlate fun(self, text: string, tooltip: string[]?)
---@field RibbonFrame fun(self, id: string): Button?
---@field SetStripText fun(self, text: string?)
---@field SetHelpShown fun(self, shown: boolean)
---@field Look fun(self): PagleBindingLook?           -- the look it wears now, nil before the first opening

--- What a book's router keeps: the pages it knows, where it is, and what draws each side.
---@class PagleBookRouter
---@field private pages table<string, PagleBookPageDef>
---@field private place PagleBookPlace
---@field private renderers table<string, fun(content: Frame, place: PagleBookPlace): number?> -- by "page:side"
local Router = {}
Router.__index = Router

-- A copy of `place` with only what its page keeps.
---@param pages table<string, PagleBookPageDef>
---@param place PagleBookPlace
---@return PagleBookPlace
local function copy(pages, place)
	local kept = { page = place.page }
	for _, field in ipairs(pages[place.page].keeps or {}) do
		kept[field] = place[field]
	end
	return kept
end

-- Raises unless `place` is one of `pages`' with what its page needs (BOOK-R20).
---@param pages table<string, PagleBookPageDef>
---@param place PagleBookPlace
local function check(pages, place)
	assert(type(place) == "table", "a book's place is a table")
	local page = pages[place.page]
	assert(page, "the book has no page " .. tostring(place.page))
	assert(not page.needs or place[page.needs] ~= nil, "a " .. place.page .. " page needs its " .. tostring(page.needs))
end

--- A router over `pages`, at `home` (BOOK-R20). Raises on a home its pages refuse.
---@param pages table<string, PagleBookPageDef>
---@param home PagleBookPlace
---@return PagleBookRouter
function ns.NewBookRouter(pages, home)
	assert(type(pages) == "table" and next(pages) ~= nil, "a book needs its pages")
	check(pages, home)
	return setmetatable({ pages = pages, place = copy(pages, home), renderers = {} }, Router)
end

--- Registers what draws side `side` of `page`; a later one replaces it (BOOK-R21).
---@param page string
---@param side PagleBookSide
---@param renderer fun(content: Frame, place: PagleBookPlace): number?
function Router:Register(page, side, renderer)
	assert(self.pages[page], "the book has no page " .. tostring(page))
	assert(side == "left" or side == "right", "a book page's side is left or right, not " .. tostring(side))
	assert(type(renderer) == "function", "a book page's renderer is a function")
	self.renderers[page .. ":" .. side] = renderer
end

--- What draws side `side` of `page`, nil for a blank side.
---@param page string
---@param side PagleBookSide
---@return (fun(content: Frame, place: PagleBookPlace): number?)?
function Router:Renderer(page, side)
	return self.renderers[page .. ":" .. side]
end

--- Goes to `place`, keeping what its page keeps; raises (and stays) on a place its pages refuse (BOOK-R20).
---@param place PagleBookPlace
function Router:Open(place)
	check(self.pages, place)
	self.place = copy(self.pages, place)
end

--- Where the book is, as a copy.
---@return PagleBookPlace
function Router:Place()
	return copy(self.pages, self.place)
end

--- Whether a turn from page `from` to page `to` goes forward: the new page's order above the old one's (BOOK-R31).
---@param from string
---@param to string
---@return boolean
function Router:Forward(from, to)
	local a, b = self.pages[from], self.pages[to]
	return ((b and b.order) or 0) > ((a and a.order) or 0)
end

--- A place as a key, to tell a redraw of the same place from a new one (BOOK-R21).
---@param place PagleBookPlace
---@return string
function ns.BookPlaceKey(place)
	local fields = {}
	for field in pairs(place) do
		fields[#fields + 1] = field
	end
	table.sort(fields)
	local parts = {}
	for i, field in ipairs(fields) do
		parts[i] = field .. "=" .. tostring(place[field])
	end
	return table.concat(parts, ";")
end

--- The ribbons' one geometry (BOOK-R17): width, gap, how long each hangs (longer chosen), how much of its top tucks
--- under the band, how much brighter the chosen one or one under the mouse turns, and how long a change of choice runs.
ns.BOOK_RIBBON = { width = 96, gap = 12, length = 75, lengthChosen = 86, tuck = 2, lift = 1.13, ease = 0.2 }

--- The shell's measures (core/book.md › Tunables).
ns.BOOK_SHELL = {
	side = 18,
	strip = 38,
	foot = 16,
	pad = { x = 28, top = 22, bottom = 20 },
	ribbonsLeft = 40,
	lift = 40,
	extentX = 30,
	extentY = 100,
	openFade = 0.16,
	closeFade = 0.12,
	crossfade = 0.2,
	sounds = { open = 829, close = 830, turn = 836 },
}

--- The pages' rectangles in a book of `options` (BOOK-R11): each page's left and width, from the frame's left, and
--- their height and foot.
---@param options PagleBookOptions
---@return { left: number, width: number }, { left: number, width: number }, number height, number foot
function ns.BookPageRects(options)
	local side = options.side or ns.BOOK_SHELL.side
	local strip = options.strip or ns.BOOK_SHELL.strip
	local foot = options.foot or ns.BOOK_SHELL.foot
	local split = options.split or 1
	local room = options.width - 2 * side
	local leftWidth = room * split / (split + 1)
	return { left = side, width = leftWidth },
		{ left = side + leftWidth, width = room - leftWidth },
		options.height - strip - foot,
		foot
end

--- A saved position (BOOK-R5) if it can be read: `{ point, relativePoint, x, y }`; nil otherwise (BOOK-R90).
---@param saved any
---@return table?
function ns.BookSavedPoint(saved)
	local points = {
		TOPLEFT = true,
		TOP = true,
		TOPRIGHT = true,
		LEFT = true,
		CENTER = true,
		RIGHT = true,
		BOTTOMLEFT = true,
		BOTTOM = true,
		BOTTOMRIGHT = true,
	}
	if
		type(saved) ~= "table"
		or not points[saved[1]]
		or not points[saved[2]]
		or type(saved[3]) ~= "number"
		or type(saved[4]) ~= "number"
	then
		return nil
	end
	return saved
end
