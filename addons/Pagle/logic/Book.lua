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
---@field Toggle fun(self)
---@field IsShown fun(self): boolean
---@field Showing fun(self): integer
---@field Place fun(self): PagleBookPlace
---@field Draw fun(self)
---@field QueueDraw fun(self)
---@field SetRibbons fun(self, ribbons: PagleBookRibbon[])
---@field SetPlate fun(self, text: string)
---@field SetStripText fun(self, text: string?)
---@field SetHelpShown fun(self, shown: boolean)
---@field Look fun(self): PagleBindingLook?           -- the look it wears now, nil before the first opening
