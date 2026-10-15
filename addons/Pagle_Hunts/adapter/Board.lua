if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board on the client (HNT-R60, HNT-R61, HNT-R67, HNT-R68, HNT-R70): a two-page notebook in leather, with the
-- leather's anchors above and beside the pages, drawing on each page what logic/Board.lua's router says the mode shown
-- puts there. The pages' contents are the renderers adapter/Timeline.lua, Entry.lua and Sets.lua register; this file
-- draws only the notebook. It makes no secure frames, so it opens and stays open while restricted (HNT-R68). The look
-- is the books art kit's Hunts board (adapter/BoardWidgets.lua): its sizes, the pages' margins, the wax close button
-- on the corner and the set ribbons hanging from under the leather's foot.

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

--- The leather's anchors (HNT-R61), in drawing order: adapter/Timeline.lua fills the clock and the checkbox,
--- adapter/Sets.lua the crumbs, the nameplate and the ribbons.
---@alias BoardLeatherPart "crumbs"|"clock"|"completed"|"nameplate"|"ribbons"
local LEATHER_PARTS = { "crumbs", "clock", "completed", "nameplate", "ribbons" }

--- Draws one of the leather's anchors: `anchor` is its frame, `place` where the board is.
---@alias BoardLeatherRenderer fun(anchor: Frame, place: BoardPlace)

---@class BoardFrame: Frame
---@field close BoardCloseButton
---@field cover BoardLeatherView               -- the leather, in the cover it wears (HNT-R70)
---@field papers table<BoardSide, BoardParchmentView>
---@field bodies table<BoardSide, Frame>       -- each page's body, inside its padding: the renderers' pages sit on it
---@field anchors table<BoardLeatherPart, Frame>

--- The Hunts board: its router, its frame once made, and each mode's page frames.
---@class HuntsBoard
---@field router BoardRouter
---@field frame BoardFrame?
---@field cover BoardCoverLook?              -- the cover set, nil for the default leather
---@field pages table<string, Frame>           -- each renderer's page, by "mode:side", made at its first draw
---@field private leather table<BoardLeatherPart, BoardLeatherRenderer>
---@field private told boolean               -- whether the grouping was last told it shows
local Board = {}
Board.__index = Board

--- The board, on the Board mode until it is opened (HNT-R67).
ns.board = setmetatable({ router = ns.NewBoardRouter(), pages = {}, leather = {}, told = false }, Board)

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

--- Selects `huntID` in the mode shown without drawing (HNT-R67): for the timeline, as it picks the Hunt to show.
---@param huntID string?
function Board:Select(huntID)
	self.router:Select(huntID)
end

--- The breadcrumb trail where the board is (HNT-R61): logic/Board.lua's router's.
---@return BoardCrumb[]
function Board:Trail()
	return self.router:Trail()
end

-- How much of a ribbon's top tucks under the leather's foot: under the kit's band, or none on an old cover, which
-- has no band to hide it.
---@param cover BoardCover
---@return number
local function tuckOf(cover)
	return cover.kit and ns.BOARD_RIBBON.tuck or 0
end

-- The fields of `look` over the default cover's.
---@param look BoardCoverLook?
---@return BoardCover
local function coverOf(look)
	local merged = {}
	for key, value in pairs(ns.BOARD_COVER) do
		if look and look[key] ~= nil then
			merged[key] = look[key]
		else
			merged[key] = value
		end
	end
	return merged --[[@as BoardCover]] -- every field, from ns.BOARD_COVER
end

--- Dresses the leather in `look` (HNT-R70), or in the default leather with nil. adapter/Goods.lua calls it
--- with the equipped cover, at load and at `AppearanceChanged`.
---@param look BoardCoverLook?
function Board:SetCover(look)
	self.cover = look
	local frame = self.frame
	if frame then
		local cover = coverOf(look)
		frame.cover:SetCover(cover)
		frame.anchors.ribbons:SetPoint("TOPLEFT", frame, "TOPLEFT", RIBBONS_LEFT, -(HEIGHT - tuckOf(cover)))
	end
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
---@param cover BoardCover
local function buildAnchors(frame, cover)
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
			-(HEIGHT - tuckOf(cover))
		),
	}
	frame.anchors.nameplate:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.anchors.ribbons:SetFrameLevel(frame:GetFrameLevel() + 1)
end

-- Builds the notebook, hidden: the leather, two pages, the leather's anchors and the close button. It drags by the
-- leather and the client saves no position, so it opens centred each time (HNT-R60); Esc hides it through
-- UISpecialFrames.
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
	local cover = coverOf(board.cover)
	frame.cover = ns.NewBoardLeather(frame)
	frame.cover:SetCover(cover)
	frame.papers, frame.bodies = {}, {}
	buildPage(frame, "left")
	buildPage(frame, "right")
	buildAnchors(frame, cover)

	frame.close = ns.NewBoardClose(frame)
	frame.close:SetPoint("CENTER", frame, "TOPRIGHT", -3, -3)
	frame.close:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.close:SetScript("OnClick", function()
		board:Hide()
	end)
	frame:SetScript("OnHide", function()
		board:Hidden()
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
	return frame
end

--- Whether the board is open.
---@return boolean
function Board:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

--- Opens the board on the Board mode (HNT-R67), or closes it: every entry point calls it (HNT-R68).
function Board:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Open({ mode = "board" })
	end
end

--- Shows `place` (logic/Board.lua's BoardPlace), opening the board, centred, if it is closed; open, it turns there in
--- place.
---@param place BoardPlace
function Board:Open(place)
	self.router:Open(place)
	local frame = self.frame or build(self)
	self.frame = frame
	if not frame:IsShown() then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", 0, RIBBONS_LIFT) -- up a little, so the ribbons hanging under it stay on screen
		frame:Show()
	end
	if not self.told then
		self.told = true
		ns.SetViewShown("board", true)
	end
	self:Draw()
end

--- Closes the board.
function Board:Hide()
	if self.frame then
		self.frame:Hide()
	end
	self:Hidden()
end

--- The board has closed, however it closed (its close button, Esc, a toggle): tells the grouping, once.
function Board:Hidden()
	if self.told then
		self.told = false
		ns.SetViewShown("board", false)
	end
end

-- Page `side` of mode `mode`'s own frame on its page body, made at its first draw.
---@param board HuntsBoard
---@param mode BoardMode
---@param side BoardSide
---@return Frame
local function pageOf(board, mode, side)
	local key = mode .. ":" .. side
	local page = board.pages[key]
	if not page then
		local body = (board.frame --[[@as BoardFrame]]).bodies[side]
		page = CreateFrame("Frame", nil, body)
		page:SetAllPoints()
		page:SetSize(body:GetWidth(), body:GetHeight())
		board.pages[key] = page
	end
	return page
end

--- Draws the mode shown, if the board is open: each page with its renderer, on its own frame, a page with none left
--- blank; then the leather's anchors, which so see what the pages selected.
function Board:Draw()
	if not self:IsShown() then
		return
	end
	local mode = self.router:Place().mode
	for _, page in pairs(self.pages) do
		page:Hide()
	end
	for _, side in ipairs(ns.BOARD_SIDES) do
		local renderer = self.router:Renderer(mode, side)
		if renderer then
			local page = pageOf(self, mode, side)
			page:Show()
			renderer(page, self.router:Place())
		end
	end
	local anchors = (self.frame --[[@as BoardFrame]]).anchors
	for _, part in ipairs(LEATHER_PARTS) do
		local renderer = self.leather[part]
		if renderer then
			renderer(anchors[part], self.router:Place())
		end
	end
end

-- The board's entry points (logic/Seams.lua lists them); every caller calls them through ns at call time.

--- Opens or closes the Hunts board (HNT-R68): Registration's view, `/pagle hunts` and so the compartment's "Hunts"
--- and the status button's "Open Hunts" call it.
function ns.ToggleBoard()
	ns.board:Toggle()
end

--- Opens the board on the Board mode, asking the timeline to select `huntID` (HNT-R67, HNT-R77); open, it turns there
--- and never closes.
---@param huntID string?
function ns.OpenBoard(huntID)
	ns.board:Open({ mode = "board", hunt = huntID })
end

-- The board redraws the mode shown at every redraw while open (HNT-R42).
ns.OnRedraw(function()
	ns.board:Draw()
end)
