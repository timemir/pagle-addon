if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board on the client (HNT-R60, HNT-R61, HNT-R67, HNT-R68, HNT-R70): Core's book shell (`Pagle.NewBook`,
-- core/book.md, ADR 0016), on which this file puts the board's own parts. The shell draws the window, its fades and
-- sounds, its saved place, the binding, the parchment pages, the crumbs, the nameplate, the wax close and "?", the
-- ribbons and the page turn; the board gives it its 1.45:1 pages, its words (the crumbs, the nameplate, a ribbon per
-- set), the clock and the "show completed" box as leather anchors, and draws on each page what logic/Board.lua's
-- router says the mode shown puts there. The pages' contents are the renderers adapter/Timeline.lua, Entry.lua,
-- Sets.lua and WagersSpread.lua register. It makes no secure frames, so it opens and stays open while restricted
-- (HNT-R68).
--
-- The board's router (logic/Board.lua) is where the board is: a renderer may select the Hunt the next page draws
-- (HNT-R67), which the shell's place never hears of. The shell's place is the board's mode as its page, with the set,
-- Hunt and run, and a `visit` the board stamps on each place it opens: a place the shell opens by itself (a crumb) has
-- another, and the router follows it there.

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (HNT-R60).
local FRAME_NAME = "PagleHuntsBoard"
-- About 920 × 600 (Tunables), the timeline's page wider (1.45 to 1).
local WIDTH, HEIGHT, SPLIT = 920, 600, 1.45
-- The shell's padding round each page's body, and each page's own inside it, left and right: the timeline leaves room
-- at its right for the list's scroll rail, the entry hugs the outer edge. Each page's top is 20 down, its foot 16 up.
local PAD = { x = 12, top = 20, bottom = 16 }
local INSETS = { left = { 10, 24 }, right = { 16, 0 } }
-- The strip's middle (halfway between the band's inner edge, 7 in, and the pages, 38 down), where the clock and the
-- checkbox sit with even room above and below; their room at the strip's right, the checkbox's at its end.
local ANCHOR_HEIGHT = 22
local ANCHOR_Y = -((7 + 38) / 2 - ANCHOR_HEIGHT / 2)
local SIDE, COMPLETED_WIDTH, CLOCK_WIDTH = 18, 150, 280
-- Where the ribbons hang from under the leather's foot, from its left; the nameplate's top left on the cover's corner.
local RIBBONS_LEFT = 176
local PLATE = { x = -12, y = HEIGHT - 18 }

--- The leather's anchors the board draws (HNT-R61): adapter/Timeline.lua fills the clock and the checkbox. The crumbs,
--- the nameplate and the ribbons are the shell's, in the board's words (adapter/Sets.lua).
---@alias BoardLeatherPart "clock"|"completed"
local ANCHORS = {
	clock = {
		point = "TOPRIGHT",
		x = -(SIDE + COMPLETED_WIDTH),
		y = ANCHOR_Y,
		width = CLOCK_WIDTH,
		height = ANCHOR_HEIGHT,
	},
	completed = { point = "TOPRIGHT", x = -SIDE, y = ANCHOR_Y, width = COMPLETED_WIDTH, height = ANCHOR_HEIGHT },
}

--- Draws one of the leather's anchors: `anchor` is its frame, `place` where the board is.
---@alias BoardLeatherRenderer fun(anchor: Frame, place: BoardPlace)

--- The Hunts board: its router, Core's book once opened, and each spread's page frames.
---@class HuntsBoard
---@field router BoardRouter
---@field book PagleBook?                    -- the shell, made at the first opening
---@field frame PagleBookFrame?              -- the book's frame, once made
---@field pinned string?                     -- the binding good the board wears in place of the equipped one (the
--- tour's binding stops), nil to follow the equipped one
---@field pages table<string, Frame>         -- each spread's page last drawn, by "mode:set:side"
---@field onContent table<Frame, table<string, Frame>> -- the spreads' pages on each of the shell's content frames
---@field shown string?                      -- the spread shown, "mode:set"
---@field visit integer                      -- the last visit stamped on a place
---@field given integer?                     -- the visit of the place the router is at
---@field serial integer                     -- how many times it has drawn
---@field ribbonWords string?                -- the ribbons last handed the book, as words
---@field leather table<BoardLeatherPart, BoardLeatherRenderer>
---@field private told boolean               -- whether the grouping was last told it shows
local Board = {}
-- `frame` is the book's, once made.
Board.__index = function(board, key)
	if key == "frame" then
		local book = rawget(board, "book")
		return book and book.frame
	end
	return Board[key]
end

--- The board, on the Board mode until it is opened (HNT-R67).
ns.board = setmetatable({
	router = ns.NewBoardRouter(),
	pages = {},
	onContent = {},
	leather = {},
	told = false,
	visit = 0,
	serial = 0,
}, Board)

--- Registers `renderer` to draw page `side` of mode `mode` (logic/Board.lua lists the modes and who draws what); a later
--- registration replaces it. The page renderers' files call it when they load.
---@param mode BoardMode
---@param side BoardSide
---@param renderer BoardRenderer
function Board:RegisterPage(mode, side, renderer)
	self.router:Register(mode, side, renderer)
end

--- Registers `renderer` to draw the leather's anchor `part` (HNT-R61) at every draw, after both pages; a later
--- registration replaces it. Raises on an anchor the leather doesn't have.
---@param part BoardLeatherPart
---@param renderer BoardLeatherRenderer
function Board:RegisterLeather(part, renderer)
	assert(ANCHORS[part], "the Hunts board's leather has no anchor " .. tostring(part))
	assert(type(renderer) == "function", "a leather anchor's renderer is a function")
	self.leather[part] = renderer
end

--- Selects `huntID` in the mode shown without drawing (HNT-R67): for the timeline, as it picks the Hunt to show; or
--- on the Board the run `runKey` in its place (HNT-R161).
---@param huntID string?
---@param runKey string?
function Board:Select(huntID, runKey)
	self.router:Select(huntID, runKey)
end

--- The breadcrumb trail where the board is (HNT-R61): logic/Board.lua's router's.
---@return BoardCrumb[]
function Board:Trail()
	return self.router:Trail()
end

--- Pins the board's binding to `goodID`'s (BIND-R2), or with nil lets it follow the equipped binding again (HNT-R70):
--- the tour's binding stops show each binding on it. Kept for a board not yet made, which is made wearing it.
---@param goodID string?
function Board:SetBinding(goodID)
	self.pinned = goodID
	local book = self.book
	if book and book.binding then
		book.binding:SetLook(goodID)
	end
end

--- The binding's look the board wears (HNT-R70), nil before its frame is made.
---@return PagleBindingLook?
function Board:Look()
	return self.book and self.book:Look()
end

-- The spread a place shows: its mode, and its set (a set's page and an entry opened from it have their own pages).
---@param place BoardPlace
---@return string
local function spreadOf(place)
	return place.mode .. ":" .. (place.mode ~= "board" and place.set or "")
end

-- Where a spread stands among the ribbons, for which way the page turns: the Board first, then Pagle Wagers, then each
-- set in Hunt list order, an entry opened from a set just after its set's page.
---@param spread string
---@return number
local function orderOf(spread)
	local mode, set = spread:match("^([^:]*):(.*)$")
	if mode == "wagers" then
		return 0.5 -- its ribbon hangs between the Board's and the sets' (HNT-R162)
	elseif mode == "board" or set == "" then
		return 0
	end
	for i, data in ipairs(ns.hunts:Sets()) do
		if data.id == set then
			return i + (mode == "set" and 0 or 0.5)
		end
	end
	return 0
end

--- `place` as the shell's, stamped with `visit`.
---@param place BoardPlace
---@param visit integer
---@return PagleBookPlace
local function toBook(place, visit)
	return { page = place.mode, set = place.set, hunt = place.hunt, run = place.run, visit = visit }
end

--- A visit no place has had: a crumb's, or a place the board opens.
---@return integer
function Board:NextVisit()
	self.visit = self.visit + 1
	return self.visit
end

--- Follows the shell to `place` when it went there by itself (a crumb), so the router is where the shell is.
---@param place PagleBookPlace
function Board:Follow(place)
	if place.visit ~= self.given then
		local mode = place.page --[[@as BoardMode]]
		self.router:Open({ mode = mode, set = place.set, hunt = place.hunt, run = place.run })
		self.given = place.visit
		self.shown = spreadOf(self.router:Place())
	end
end

-- Page `side` of `spread`'s own frame on the shell's `content` frame (a page turning to another set's draws on its
-- other leaf, BOOK-R30), made at its first draw there, inset to the page's own padding; the other spreads' frames on
-- that content hide.
---@param board HuntsBoard
---@param content Frame
---@param spread string
---@param side BoardSide
---@return Frame
local function pageOf(board, content, spread, side)
	local key = spread .. ":" .. side
	local own = board.onContent[content] or {}
	board.onContent[content] = own
	local page = own[key]
	if not page then
		local inset = INSETS[side]
		local body = (board.frame --[[@as PagleBookFrame]]).bodies[side]
		page = CreateFrame("Frame", nil, content)
		page:SetPoint("TOPLEFT", content, "TOPLEFT", inset[1], 0)
		page:SetSize(body:GetWidth() - inset[1] - inset[2], body:GetHeight())
		own[key] = page
	end
	for other, frame in pairs(own) do
		frame:SetShown(other == key)
	end
	board.pages[key] = page
	return page
end

--- The page frame `side` of the spread `place` shows, nil before its first draw: for a dev tool or a spec to read.
---@param place BoardPlace
---@param side BoardSide
---@return Frame?
function Board:Page(place, side)
	return self.pages[spreadOf(place) .. ":" .. side]
end

-- The crumbs where the board is (HNT-R61), each going back up.
---@param board HuntsBoard
---@return PagleBookCrumb[]
local function trail(board)
	local crumbs = {}
	for i, data in ipairs(ns.BoardCrumbs()) do
		crumbs[i] = { text = data.text, target = data.place and toBook(data.place, board:NextVisit()) }
	end
	return crumbs
end

-- The ribbons where the board is (HNT-R61, HNT-R162): Board, Pagle Wagers with "{n} on" under its name, then each
-- set's in its colour, each opening its place; and what tells one list from another, its places aside.
---@param board HuntsBoard
---@return PagleBookRibbon[]
---@return string
local function ribbons(board)
	local LOOK = ns.BOARD_LOOK
	local list, words = {}, {}
	for i, data in ipairs(ns.BoardRibbons(board.router:Place())) do
		local ribbon = {
			id = data.set or (data.wagers and "wagers") or "board",
			text = data.name or data.text,
			color = data.set and ns.BoardRibbonColor(data.index --[[@as integer]]) or data.wagers and LOOK.oxblood or LOOK.boardRibbon,
			count = data.count,
			tooltip = { data.name or data.text },
			target = function()
				return toBook(data.place, board:NextVisit())
			end,
		}
		list[i] = ribbon
		words[i] = table.concat({ ribbon.id, ribbon.text, ribbon.count or "", table.concat(ribbon.color, ",") }, "|")
	end
	return list, table.concat(words, "\n")
end

-- The chosen ribbon's id where the board is: the one of the mode shown.
---@param board HuntsBoard
---@return string?
local function chosenRibbon(board)
	for _, ribbon in ipairs(ns.BoardRibbons(board.router:Place())) do
		if ribbon.chosen then
			return ribbon.set or (ribbon.wagers and "wagers") or "board"
		end
	end
	return nil
end

-- Writes the nameplate (HNT-R61): its words, and each earned title with its full date in its tooltip.
---@param book PagleBook
local function plate(book)
	local data = ns.BoardNameplate()
	book:SetPlate(data.text, #data.titles > 0 and { data.text, unpack(data.titles) } or nil)
end

-- Makes the board's book, at its first opening: Core's shell with the board's pages, anchors and words.
---@param board HuntsBoard
---@return PagleBook
local function build(board)
	local pages = {}
	local keeps = { "set", "hunt", "run", "visit" }
	for mode, order in pairs({ board = 0, wagers = 0.5, set = 1, entry = 1.5, retired = 1.5 }) do
		pages[mode] = { keeps = keeps, order = order }
	end
	pages.set.needs = "set"
	pages.entry.needs, pages.retired.needs = "hunt", "hunt"
	local book = Pagle.NewBook({
		id = "hunts",
		name = FRAME_NAME,
		width = WIDTH,
		height = HEIGHT,
		pages = pages,
		home = { page = "board" },
		pinned = board.pinned,
		split = SPLIT,
		pad = PAD,
		stripRoom = COMPLETED_WIDTH + CLOCK_WIDTH,
		plate = PLATE,
		help = {
			tooltip = ns.L.LOOK_AGAIN,
			onClick = function()
				ns.ShowBoardLookAgain()
			end,
		},
		anchors = ANCHORS,
		ribbonsLeft = RIBBONS_LEFT,
		how = function(from, to)
			return Board.How(from, to)
		end,
		trail = function(place)
			board:Follow(place)
			return trail(board)
		end,
		chosenRibbon = function(place)
			board:Follow(place)
			return chosenRibbon(board)
		end,
		onDraw = function(place)
			board:Follow(place)
			board.serial = board.serial + 1
			local book = board.book --[[@as PagleBook]]
			-- the ribbons again only when they changed, so a change of the chosen one runs on (BOOK-R17)
			local list, words = ribbons(board)
			if words ~= board.ribbonWords then
				board.ribbonWords = words
				book:SetRibbons(list)
			end
			plate(book)
		end,
		onShow = function()
			local book = board.book --[[@as PagleBook]]
			book:SetHelpShown(ns.HasBoardLook())
			board:Told(true)
			-- drawn and fitted: the First evening list's item and, the first time, the First look (adapter/Look.lua)
			ns.BoardOpened()
		end,
		onHide = function()
			board:Told(false)
		end,
	})
	for _, mode in ipairs(ns.BOARD_MODES) do
		for _, side in ipairs(ns.BOARD_SIDES) do
			book:RegisterPage(mode, side, function(content, place)
				board:Follow(place)
				local renderer = board.router:Renderer(mode, side)
				if renderer then
					-- the router's place, as the left page may select the Hunt the right one draws
					renderer(pageOf(board, content, spreadOf(board.router:Place()), side), board.router:Place())
				end
				return nil
			end)
		end
	end
	for part in pairs(ANCHORS) do
		book:RegisterLeather(part, function(anchor, place)
			board:Follow(place)
			local renderer = board.leather[part]
			if renderer then
				renderer(anchor, board.router:Place())
			end
		end)
	end
	return book
end

--- Tells the grouping the board shows or hides, once each (HNT-R42's refresh).
---@param shown boolean
function Board:Told(shown)
	if self.told ~= shown then
		self.told = shown
		ns.SetViewShown("board", shown)
	end
end

--- Whether the board is open: shown, and not fading out.
---@return boolean
function Board:IsShown()
	-- the shell's IsShown leaves out a book fading out, as the board's Toggle does (BOOK-R23)
	local book = self.book --[[@as PagleBook?]]
	return book ~= nil and book:IsShown()
end

--- How many times the board has drawn. A page whose last draw was the draw before this one has been on show since, so
--- what changed on it may move into place (adapter/Timeline.lua's rows sliding to a new group).
---@return integer
function Board:Serial()
	return self.serial
end

--- Which showing of the board this is: it changes each time the board closes. A page drawn earlier in the same showing
--- has been on show since; one drawn before the board last closed draws settled, as what changed while it was closed
--- was never seen (HNT-R62: the timeline is live "while it shows"; adapter/Entry.lua's ink bar).
---@return integer
function Board:Showing()
	return self.book and self.book:Showing() or 0
end

--- Opens the board on the Board mode (HNT-R67), or closes it: every entry point calls it (HNT-R68).
function Board:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Open({ mode = "board" })
	end
end

--- Shows `place` (logic/Board.lua's BoardPlace), opening the board if it is closed; open, it turns the page there,
--- forward to a later ribbon or back to an earlier one, or with `motion` "still" goes there at once.
---@param place BoardPlace
---@param motion "still"?
function Board:Open(place, motion)
	self.book = self.book or build(self)
	self.router:Open(place)
	self.given = self:NextVisit()
	self.shown = spreadOf(self.router:Place())
	self.book:Open(toBook(self.router:Place(), self.given), motion and { motion = motion } or nil)
end

--- How the book moves from `from` to `to` when an Open gives no how (BOOK-R34): a page turn when the spread changes,
--- forward to a later ribbon or back to an earlier one, even between two sets' pages; in place on the same spread.
---@param from PagleBookPlace
---@param to PagleBookPlace
---@return PagleBookOpenHow
function Board.How(from, to)
	local fromSpread = from.page .. ":" .. (from.page ~= "board" and from.set or "")
	local toSpread = to.page .. ":" .. (to.page ~= "board" and to.set or "")
	if fromSpread == toSpread then
		return { motion = "still" }
	end
	return { motion = "turn", forward = orderOf(toSpread) > orderOf(fromSpread) }
end

--- Closes the board: the shell fades it out with the book's closing sound (BOOK-R4).
function Board:Hide()
	if self.book then
		self.book:Close()
	end
end

--- Draws the spread shown, if the board is open, in place.
function Board:Draw()
	if self:IsShown() then
		(self.book --[[@as PagleBook]]):Draw()
	end
end

-- The board's entry points (logic/Seams.lua lists them); every caller calls them through ns at call time.

--- Opens or closes the Hunts board (HNT-R68): Registration's view, `/pagle hunts` and so the compartment's "Hunts"
--- and the status button's "Open Hunts" call it.
function ns.ToggleBoard()
	ns.board:Toggle()
end

--- Opens the board on the Board mode, asking the timeline to select a Hunt (HNT-R67, HNT-R77) or a run (HNT-R164):
--- `target` is a Hunt's ID, or `{ hunt = huntID }` or `{ run = runKey }`; open, it turns there and never closes. A run
--- the board no longer shows (ended, HNT-R143) selects the Hunt HNT-R67 picks.
---@param target (string|{ hunt: string?, run: string? })?
function ns.OpenBoard(target)
	if type(target) == "table" then
		ns.board:Open({ mode = "board", hunt = target.hunt, run = target.run })
	else
		ns.board:Open({ mode = "board", hunt = target })
	end
end

-- The board redraws the mode shown at every redraw while open (HNT-R42).
ns.OnRedraw(function()
	ns.board:Draw()
end)
