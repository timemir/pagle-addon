if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board on the client (HNT-R60, HNT-R61, HNT-R67, HNT-R68, HNT-R70): a two-page notebook in Core's binding
-- (Pagle.NewBookBinding, ADR 0015), with the leather's anchors above and beside the pages, drawing on each page what logic/Board.lua's router says the mode shown
-- puts there. The pages' contents are the renderers adapter/Timeline.lua, Entry.lua, Sets.lua and WagersSpread.lua
-- register; this file
-- draws only the notebook. It makes no secure frames, so it opens and stays open while restricted (HNT-R68). The look
-- is the books art kit's Hunts board (adapter/BoardWidgets.lua): its sizes, the pages' margins, the wax close button
-- on the corner and the set ribbons hanging from under the leather's foot. Its motion is the kit v2's
-- (adapter/BoardMotion.lua): it fades in and out with the book's sounds, shrinks to fit the screen, and turns the page
-- between spreads (the Board, the Pagle Wagers spread, each set's page, an entry opened from a set), each spread on
-- its own page frames.

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (HNT-R60).
local FRAME_NAME = "PagleHuntsBoard"
-- About 920 × 600 (Tunables): the leather round the pages, the gilt strip above them for the crumbs, the clock and
-- the checkbox, and the leather below.
local WIDTH, HEIGHT = 920, 600
local SIDE, STRIP, FOOT = 18, 38, 16
-- The strip's middle: halfway between the band's inner edge (the tiled leather starts 7 in) and the pages, where the
-- crumbs, the clock and the checkbox sit with even room above and below, as the Stats book's crumbs and search do.
local STRIP_MIDDLE = (7 + STRIP) / 2
-- The pages share the width as the kit's do, the timeline's page wider (1.45 to 1).
local LEFT_WIDTH = math.floor((WIDTH - 2 * SIDE) * 1.45 / 2.45 + 0.5)
local RIGHT_WIDTH = WIDTH - 2 * SIDE - LEFT_WIDTH
local PAGE_HEIGHT = HEIGHT - STRIP - FOOT
-- A page body's padding inside the paper, left, top, right, bottom: the timeline leaves room at its right for the
-- list's scroll rail, the entry hugs the outer edge.
local PADS = { left = { 22, 20, 36, 16 }, right = { 28, 20, 12, 16 } }
-- The "show completed" checkbox's room at the strip's right, the clock's before it.
local COMPLETED_WIDTH, CLOCK_WIDTH = 150, 280
-- Where the set ribbons hang from under the leather's foot, from its left.
local RIBBONS_LEFT = 176
-- How far above the screen's centre the board opens: half the ribbons' hang under it.
local RIBBONS_LIFT = 40
-- The board's whole extent, for fitting it to the screen: the wax close button over its corner and the nameplate past
-- its edge, and the chosen ribbon hanging under it.
local EXTENT_WIDTH = WIDTH + 26
local EXTENT_HEIGHT = HEIGHT + 10 + ns.BOARD_RIBBON.lengthChosen - ns.BOARD_RIBBON.tuck

--- The leather's anchors (HNT-R61), in drawing order: adapter/Timeline.lua fills the clock and the checkbox,
--- adapter/Sets.lua the crumbs, the nameplate and the ribbons.
---@alias BoardLeatherPart "crumbs"|"clock"|"completed"|"nameplate"|"ribbons"
local LEATHER_PARTS = { "crumbs", "clock", "completed", "nameplate", "ribbons" }
-- The anchors the binding's look inks (HNT-R70): the crumbs in its gilt, the nameplate in its metal.
local INKED = { crumbs = true, nameplate = true }
-- The binding's material on the frame's BACKGROUND layer, under the papers' own frames (BIND-R10).
local LEATHER_SUBLEVEL = 2

--- Draws one of the leather's anchors: `anchor` is its frame, `place` where the board is.
---@alias BoardLeatherRenderer fun(anchor: Frame, place: BoardPlace)

---@class BoardFrame: Frame
---@field close BoardCloseButton
---@field help BoardHelpButton                 -- the "?" beside it (ONB-R59)
---@field binding PagleBookBinding            -- the leather: Core's binding, the equipped one or the pinned one (HNT-R70)
---@field papers table<BoardSide, BoardParchmentView>
---@field paperFrames table<BoardSide, Frame>  -- each page's paper: the spreads' clip frames sit on it
---@field bodies table<BoardSide, Frame>       -- each page's body, inside its padding: the renderers' pages fill it
---@field anchors table<BoardLeatherPart, Frame>
---@field fold BoardFold                       -- the page turn's shade and shadow, over both papers

--- The Hunts board: its router, its frame once made, and each spread's page frames.
---@class HuntsBoard
---@field router BoardRouter
---@field frame BoardFrame?
---@field pinned string?                     -- the binding good the board wears in place of the equipped one (the
--- tour's binding stops), nil to follow the equipped one
---@field look PagleBindingLook?             -- the binding's look the board wears, once its frame is made
---@field pages table<string, BoardTurnPage> -- each spread's page, by "mode:set:side", made at its first draw
---@field shown string?                       -- the spread shown, "mode:set"
---@field turnFrom string?                    -- the spread shown when it was opened elsewhere: the next draw turns from it
---@field turning boolean                     -- a page turn is under way
---@field turnOwner table                     -- the page turn's motion runs on it
---@field closeOwner table                    -- the closing fade runs on it
---@field closing boolean                     -- the closing fade runs: the board counts as closed
---@field closeSounded boolean                -- this close's sound has played
---@field serial integer                      -- how many times it has drawn
---@field showing integer                     -- how many times it has closed: which showing this is
---@field leather table<BoardLeatherPart, BoardLeatherRenderer>
---@field private told boolean               -- whether the grouping was last told it shows
local Board = {}
Board.__index = Board

--- The board, on the Board mode until it is opened (HNT-R67).
ns.board = setmetatable({
	router = ns.NewBoardRouter(),
	pages = {},
	leather = {},
	told = false,
	turning = false,
	turnOwner = {},
	closeOwner = {},
	closing = false,
	closeSounded = false,
	serial = 0,
	showing = 0,
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
	local known = false
	for _, name in ipairs(LEATHER_PARTS) do
		known = known or name == part
	end
	assert(known, "the Hunts board's leather has no anchor " .. tostring(part))
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
	local frame = self.frame
	if frame then
		frame.binding:SetLook(goodID)
	end
end

--- The binding's look the board wears (HNT-R70), nil before its frame is made: its crumbs' gilt and its nameplate's
--- metal read it as they draw.
---@return PagleBindingLook?
function Board:Look()
	return self.look
end

-- A page on the frame: its parchment, its spine on the inner edge, and its body inside the padding. The paper takes
-- the mouse, so only the leather drags the board.
---@param frame BoardFrame
---@param side BoardSide
local function buildPage(frame, side)
	local width = side == "left" and LEFT_WIDTH or RIGHT_WIDTH
	local pad = PADS[side]
	local paper = CreateFrame("Frame", nil, frame)
	paper:SetSize(width, PAGE_HEIGHT)
	paper:SetPoint("BOTTOMLEFT", side == "left" and SIDE or SIDE + LEFT_WIDTH, FOOT)
	paper:EnableMouse(true)
	frame.paperFrames[side] = paper
	frame.papers[side] = ns.NewBoardParchment(paper, side == "left" and "RIGHT" or "LEFT")
	local body = CreateFrame("Frame", nil, paper)
	body:SetPoint("TOPLEFT", pad[1], -pad[2])
	body:SetPoint("BOTTOMRIGHT", -pad[3], pad[4])
	body:SetSize(width - pad[1] - pad[3], PAGE_HEIGHT - pad[2] - pad[4])
	frame.bodies[side] = body
end

-- The leather's anchors (HNT-R61): the crumbs at the strip's left, the clock and the checkbox at its right, the brass
-- nameplate over the cover's lower corner, above the band, and the ribbons' row hanging from under the leather's foot,
-- below the band, so their tops tuck under it.
---@param frame BoardFrame
local function buildAnchors(frame)
	local function anchor(width, height, ...)
		local made = CreateFrame("Frame", nil, frame)
		made:SetSize(width, height)
		made:SetPoint(...)
		return made
	end
	local strip = STRIP - 16
	frame.anchors = {
		crumbs = anchor(
			WIDTH - 2 * SIDE - COMPLETED_WIDTH - CLOCK_WIDTH,
			strip,
			"TOPLEFT",
			SIDE + 6,
			-(STRIP_MIDDLE - strip / 2)
		),
		clock = anchor(CLOCK_WIDTH, strip, "TOPRIGHT", -(SIDE + COMPLETED_WIDTH), -(STRIP_MIDDLE - strip / 2)),
		completed = anchor(COMPLETED_WIDTH, strip, "TOPRIGHT", -SIDE, -(STRIP_MIDDLE - strip / 2)),
		nameplate = anchor(200, 32, "BOTTOMLEFT", -12, -14),
		ribbons = anchor(
			WIDTH - RIBBONS_LEFT,
			ns.BOARD_RIBBON.lengthChosen,
			"TOPLEFT",
			frame,
			"TOPLEFT",
			RIBBONS_LEFT,
			-(HEIGHT - ns.BOARD_RIBBON.tuck)
		),
	}
	frame.anchors.nameplate:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.anchors.ribbons:SetFrameLevel(frame:GetFrameLevel() + 1)
end

-- Builds the notebook, hidden: the leather, two pages, the leather's anchors, the page turn's fold and the close
-- button. It drags by the leather and the client saves no position, so it opens centred each time (HNT-R60); Esc hides
-- it through UISpecialFrames.
---@param board HuntsBoard
---@return BoardFrame
local function build(board)
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as BoardFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	-- the ribbons hang under the leather: the clamp keeps them on screen too
	frame:SetClampRectInsets(0, 0, 0, -(ns.BOARD_RIBBON.lengthChosen - ns.BOARD_RIBBON.tuck))
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- A moved frame is user-placed, and the client would save where it was left: Blizzard_ChatFrameBase's
		-- FloatingChatFrame.xml does the same "So that we don't save the position".
		self:SetUserPlaced(false)
	end)
	frame.papers, frame.paperFrames, frame.bodies = {}, {}, {}
	buildPage(frame, "left")
	buildPage(frame, "right")
	buildAnchors(frame)
	-- the leather: Core's binding, under the papers and over the ribbons' tops (HNT-R70); Core dips it and plays the page
	-- turn when the equipped one changes (BIND-R20, BIND-R21), and the board inks its own parts from each look
	frame.binding = Pagle.NewBookBinding(frame, {
		pinned = board.pinned,
		sublevel = LEATHER_SUBLEVEL,
		onLook = function(look)
			board:Ink(frame, look)
		end,
	})
	-- the fold over both papers, above every spread's page, while a page turns
	local pages = CreateFrame("Frame", nil, frame)
	pages:SetPoint("TOPLEFT", SIDE, -STRIP)
	pages:SetPoint("BOTTOMRIGHT", -SIDE, FOOT)
	frame.fold = ns.NewBoardFold(pages)

	frame.close = ns.NewBoardClose(frame)
	frame.close:SetPoint("CENTER", frame, "TOPRIGHT", -3, -3)
	frame.close:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.close:SetScript("OnClick", function()
		board:Hide()
	end)
	-- the "?" beside it, in the same wax: the First look's notes again (ONB-R59, adapter/Look.lua); hidden on a Core
	-- without First looks (ONB-R90)
	frame.help = ns.NewBoardHelp(frame, ns.L.LOOK_AGAIN)
	frame.help:SetPoint("RIGHT", frame.close, "LEFT", -4, 0)
	frame.help:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.help:SetScript("OnClick", function()
		ns.ShowBoardLookAgain()
	end)
	frame.help:SetShown(ns.HasBoardLook())
	frame:SetScript("OnHide", function()
		board:Hidden()
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
	return frame
end

--- Whether the board is open: shown, and not fading out.
---@return boolean
function Board:IsShown()
	return self.frame ~= nil and self.frame:IsShown() and not self.closing
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
	return self.showing
end

--- Opens the board on the Board mode (HNT-R67), or closes it: every entry point calls it (HNT-R68).
function Board:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Open({ mode = "board" })
	end
end

--- Shows `place` (logic/Board.lua's BoardPlace), opening the board, centred and fitted to the screen, if it is closed;
--- open, it turns the page there.
---@param place BoardPlace
function Board:Open(place)
	local frame = self.frame or build(self)
	self.frame = frame
	if self:IsShown() then
		self.turnFrom = self.turnFrom or self.shown
	else
		self.turnFrom = nil
	end
	self.router:Open(place)
	if self.closing then
		-- opened again while it fades out: it stays
		self.closing = false
		Pagle.StopMotion(self.closeOwner)
		frame:SetAlpha(1)
	end
	local opening = not frame:IsShown()
	if opening then
		self.closeSounded = false
		frame:Show()
		ns.BoardSound("bookOpen")
		ns.FadeIn(frame)
	end
	if not self.told then
		self.told = true
		ns.SetViewShown("board", true)
	end
	self:Draw()
	if opening then
		-- up a little, so the ribbons hanging under it stay on screen, and no larger than the screen, the row of
		-- ribbons included once drawn: centred, its extent reaches as far past each side as they hang past the right
		local ribbons = frame.anchors.ribbons --[[@as { rowWidth: number? }]]
		local width = math.max(EXTENT_WIDTH, 2 * (RIBBONS_LEFT + (ribbons.rowWidth or 0)) - WIDTH)
		ns.FitBoard(frame, width, EXTENT_HEIGHT, RIBBONS_LIFT)
		-- drawn and fitted: the First evening list's item and, the first time, the First look (adapter/Look.lua)
		ns.BoardOpened()
	end
end

--- Ends a page turn under way at once, on the spread it turns to.
function Board:SettleTurn()
	if not self.turning then
		return
	end
	self.turning = false
	Pagle.StopMotion(self.turnOwner)
	if self.shown then
		self:ShowOnly(self.shown)
	end
end

--- Closes the board: it fades out (0.12 s) with the book's closing sound, then hides; at once with the motion off.
function Board:Hide()
	local frame = self.frame
	if frame and frame:IsShown() and not self.closing then
		self:SettleTurn()
		self.closeSounded = true
		ns.BoardSound("bookClose")
		if ns.MotionOn() then
			self.closing = true
			-- this close's end, once, by the fade or by the clock after the fade's time, whichever comes first, so it
			-- ends whether or not frames are drawn; a later open or close has its own
			local owner = {}
			self.closeOwner = owner
			local function finish()
				if self.closing and self.closeOwner == owner then
					Pagle.StopMotion(owner)
					self.closing = false
					frame:Hide()
					frame:SetAlpha(1)
				end
			end
			ns.FadeOut(frame, owner, finish)
			C_Timer.After(ns.CLOSE_FADE, finish)
		else
			frame:Hide()
		end
	end
	self:Hidden()
end

--- The board has closed, however it closed (its close button, Esc, a toggle): tells the grouping, once, plays the
--- book's closing sound if its close didn't (Esc hides it at once), and the next showing begins.
function Board:Hidden()
	local frame = self.frame
	if frame and not frame:IsShown() then
		self.showing = self.showing + 1
		self:SettleTurn()
		self.closing = false
		if not self.closeSounded then
			self.closeSounded = true
			ns.BoardSound("bookClose")
		end
	end
	if self.told then
		self.told = false
		ns.SetViewShown("board", false)
	end
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

-- Page `side` of `spread`'s own frame, in its clip frame on the paper, made at its first draw.
---@param board HuntsBoard
---@param spread string
---@param side BoardSide
---@return BoardTurnPage
local function pageOf(board, spread, side)
	local key = spread .. ":" .. side
	local page = board.pages[key]
	if not page then
		local frame = board.frame --[[@as BoardFrame]]
		page = ns.NewTurnPage(frame.paperFrames[side], frame.bodies[side])
		board.pages[key] = page
	end
	return page
end

--- The page frame `side` of the spread `place` shows, nil before its first draw: for a dev tool or a spec to read.
---@param place BoardPlace
---@param side BoardSide
---@return BoardTurnPage?
function Board:Page(place, side)
	return self.pages[spreadOf(place) .. ":" .. side]
end

-- Whether page `key` ("mode:set:side") belongs to `spread`; its side when it does.
---@param key string
---@param spread string
---@return BoardSide?
local function sideIn(key, spread)
	if key:sub(1, #spread + 1) == spread .. ":" then
		local side = key:sub(#spread + 2)
		if side == "left" or side == "right" then
			return side
		end
	end
	return nil
end

--- Shows only `spread`'s pages, whole, and no fold.
---@param spread string
function Board:ShowOnly(spread)
	local frame = self.frame --[[@as BoardFrame]]
	for key, page in pairs(self.pages) do
		local side = sideIn(key, spread)
		if side then
			ns.RevealPage(page, side == "left" and LEFT_WIDTH or RIGHT_WIDTH, 0, 1)
		else
			page.clip:Hide()
		end
	end
	frame.fold:Hide()
end

-- Draws the leather's anchors at `place`: all of them, or only those `only` names.
---@param board HuntsBoard
---@param place BoardPlace
---@param only table<string, boolean>?
local function drawLeather(board, place, only)
	local anchors = (board.frame --[[@as BoardFrame]]).anchors
	for _, part in ipairs(LEATHER_PARTS) do
		local renderer = board.leather[part]
		if renderer and (not only or only[part]) then
			renderer(anchors[part], place)
		end
	end
end

--- Inks the board's own parts from the binding's `look` on `frame` (HNT-R70, BIND-R3): the pages' paper tinted, and,
--- while it shows, the crumbs in the binding's gilt and the nameplate in its metal drawn again; closed, they take it at
--- the next draw.
---@param frame BoardFrame
---@param look PagleBindingLook
function Board:Ink(frame, look)
	self.look = look
	local tint = look.paperTint
	for _, paper in pairs(frame.papers) do
		paper.paper:SetVertexColor(tint[1], tint[2], tint[3])
	end
	if self:IsShown() then
		drawLeather(self, self.router:Place(), INKED)
	end
end

-- Every anchor but the crumbs, which change as the leaf passes the spine.
local NOT_CRUMBS = { clock = true, completed = true, nameplate = true, ribbons = true }

--- Draws the spread shown, if the board is open: each page with its mode's renderer, on the spread's own frames, a
--- page with none left blank; then the leather's anchors, which so see what the pages selected. Opened elsewhere while
--- open, it turns the page from the spread it showed (half a second, while things move), the crumbs changing halfway.
function Board:Draw()
	if not self:IsShown() then
		return
	end
	self.serial = self.serial + 1
	local place = self.router:Place()
	local spread = spreadOf(place)
	local from = self.turnFrom
	self.turnFrom = nil
	self:SettleTurn()
	for _, side in ipairs(ns.BOARD_SIDES) do
		local page = pageOf(self, spread, side)
		local renderer = self.router:Renderer(place.mode, side)
		if renderer then
			renderer(page, self.router:Place()) -- the left page may select the Hunt the right one draws
		end
	end
	self.shown = spread
	if not (from and from ~= spread and self.pages[from .. ":left"] and ns.MotionOn()) then
		self:ShowOnly(spread)
		drawLeather(self, self.router:Place())
		return
	end
	-- the turn: forward to a later ribbon, back to an earlier one
	ns.BoardSound("pageTurn")
	for key, page in pairs(self.pages) do
		if not (sideIn(key, spread) or sideIn(key, from)) then
			page.clip:Hide()
		end
	end
	drawLeather(self, self.router:Place(), NOT_CRUMBS)
	self.turning = true
	local frame = self.frame --[[@as BoardFrame]]
	ns.TurnPages(
		self.turnOwner,
		frame.fold,
		{ left = pageOf(self, from, "left"), right = pageOf(self, from, "right") },
		{ left = pageOf(self, spread, "left"), right = pageOf(self, spread, "right") },
		orderOf(spread) > orderOf(from),
		LEFT_WIDTH,
		RIGHT_WIDTH,
		function()
			drawLeather(self, self.router:Place(), { crumbs = true })
		end,
		function()
			self.turning = false
			self:ShowOnly(spread)
		end
	)
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
