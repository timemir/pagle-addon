if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board on the client (TKB-R100, TKB-R107, TKB-R108, TKB-R193): a wooden frame with a brass plaque round a
-- cork board, with a ledge below, drawing what logic/Board.lua decides: the empty slip and its Start button before
-- Start, "Updating…" while the projection updates, and each part's renderer once started. The parts' contents are the
-- pins' and the ledge's (adapter/Pins.lua, adapter/Ledge.lua); this file draws only the board. It makes no secure
-- frames, so it opens and works while restricted (TKB-R193). The look follows prototypes/tackle-board/ variant C, in
-- adapter/BoardWidgets.lua's art.

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (TKB-R100).
local FRAME_NAME = "PagleTackleBoard"
-- Variant C's board: 1000 × 660, the cork inside the wood's padding (34 top, 26 at the sides, 92 below for the ledge),
-- the ledge 86 high along the bottom.
local WIDTH, HEIGHT = 1000, 660
local PAD_TOP, PAD_SIDE, PAD_BOTTOM, LEDGE_HEIGHT = 34, 26, 92, 86
local CORK_WIDTH, CORK_HEIGHT = WIDTH - 2 * PAD_SIDE, HEIGHT - PAD_TOP - PAD_BOTTOM

-- Each part's place, from the cork's top left (variant C's `renderC`): the pins over the left of the cork, the
-- overflow strip under the Notice rows, the spike down the right; the ledge part fills the ledge.
local PINS_WIDTH, PINS_HEIGHT = 700, 494
local OVERFLOW_X, OVERFLOW_Y, OVERFLOW_WIDTH, OVERFLOW_HEIGHT = 16, 496, 676, 34
local SPIKE_RIGHT, SPIKE_TOP, SPIKE_WIDTH = 14, 26, 130

-- The pins, as variant C pins them: each pin's top left on the cork, and its size: an Expedition's poster, a Notice's
-- slip (TKB-R101: 2 Expedition pins on the top row, 3 Notice pins on each of the two rows below).
local EXPEDITION_PINS = { { 16, 12 }, { 306, 8 } }
local NOTICE_PINS = { { 16, 198 }, { 228, 192 }, { 440, 200 }, { 16, 368 }, { 228, 372 }, { 440, 366 } }
local POSTER_WIDTH, POSTER_HEIGHT = 250, 150
local SLIP_WIDTH, SLIP_HEIGHT = 196, 118

-- The empty board's slip (TKB-R107): 340 wide, centred across the cork 44% of the way down, its words above the
-- Start button.
local EMPTY_WIDTH, EMPTY_HEIGHT, EMPTY_PAD = 340, 200, 24
local EMPTY_Y = math.floor(CORK_HEIGHT * (0.5 - 0.44) + 0.5)

---@class TacklePinsFrame: Frame
---@field slots { expeditions: Frame[], notices: Frame[] }   -- one frame per pin, in board order (TKB-R101)

---@class TackleUpdatingFrame: Frame
---@field label FontString

---@class TackleBoardFrame: Frame
---@field close Button
---@field plaque TacklePlaqueView
---@field cork Frame
---@field ledge Frame
---@field empty TackleSlipView                     -- the empty board's slip (TKB-R107)
---@field slipText FontString
---@field start TackleButtonView                   -- Start my board (TKB-R5)
---@field updating TackleUpdatingFrame             -- "Updating…" over the cork (TKB-R108)
---@field parts table<TackleBoardPart, Frame>      -- each part's frame, in its place

--- The Tackle Board: its parts' renderers, and its frame once made.
---@class TackleBoard
---@field parts TackleBoardParts
---@field frame TackleBoardFrame?
local Board = {}
Board.__index = Board

--- The board, closed until opened.
ns.board = setmetatable({ parts = ns.NewBoardParts() }, Board)

--- Registers `renderer` to draw `part` (logic/Board.lua lists the parts and who draws each) at every draw of a started
--- board; a later registration replaces it. The pins' and the ledge's tickets call it when their files load.
---@param part TackleBoardPart
---@param renderer TackleBoardRenderer
function Board:RegisterPart(part, renderer)
	self.parts:Register(part, renderer)
end

--- Whether the projection is updating (TKB-R108): the pins disable every "take it down" while it is. Call it as
--- `ns.board:IsUpdating()`.
---@return boolean
function Board.IsUpdating()
	return ns.IsUpdating()
end

-- A frame on `parent` of `width` × `height` at `x`, `y` from its `point`.
---@return Frame
local function placed(parent, width, height, point, x, y)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(width, height)
	frame:SetPoint(point, parent, point, x, y)
	return frame
end

-- The parts' frames on the cork and the ledge, and the pins' slots.
---@param frame TackleBoardFrame
local function buildParts(frame)
	local cork = frame.cork
	local pins = placed(cork, PINS_WIDTH, PINS_HEIGHT, "TOPLEFT", 0, 0) --[[@as TacklePinsFrame]]
	pins.slots = { expeditions = {}, notices = {} }
	for i, at in ipairs(EXPEDITION_PINS) do
		pins.slots.expeditions[i] = placed(pins, POSTER_WIDTH, POSTER_HEIGHT, "TOPLEFT", at[1], -at[2])
	end
	for i, at in ipairs(NOTICE_PINS) do
		pins.slots.notices[i] = placed(pins, SLIP_WIDTH, SLIP_HEIGHT, "TOPLEFT", at[1], -at[2])
	end
	frame.parts = {
		pins = pins,
		overflow = placed(cork, OVERFLOW_WIDTH, OVERFLOW_HEIGHT, "TOPLEFT", OVERFLOW_X, -OVERFLOW_Y),
		spike = placed(cork, SPIKE_WIDTH, CORK_HEIGHT - SPIKE_TOP - 10, "TOPRIGHT", -SPIKE_RIGHT, -SPIKE_TOP),
		ledge = placed(frame.ledge, WIDTH, LEDGE_HEIGHT, "TOPLEFT", 0, 0),
	}
end

-- The empty board's slip with its words and Start my board below them (TKB-R107, TKB-R5).
---@param board TackleBoard
---@param frame TackleBoardFrame
local function buildEmpty(board, frame)
	local slip = ns.NewBoardSlip(frame.cork, EMPTY_WIDTH, EMPTY_HEIGHT)
	slip:SetPoint("CENTER", frame.cork, "CENTER", 0, EMPTY_Y)
	frame.empty = slip
	frame.slipText = ns.NewBoardPrinted(slip)
	frame.slipText:SetJustifyH("CENTER")
	frame.slipText:SetWidth(EMPTY_WIDTH - 2 * EMPTY_PAD)
	frame.slipText:SetPoint("TOP", 0, -28)
	frame.slipText:SetText(ns.L.EMPTY_SLIP)
	frame.start = ns.NewBoardButton(slip, ns.L.START_MY_BOARD, function()
		board:Start()
	end)
	frame.start:SetPoint("BOTTOM", 0, 18)
end

-- "Updating…" over the cork (TKB-R108): a dark wash and the words, above the slip and the parts. It takes no mouse,
-- so the slips under it still show their tooltips.
---@param frame TackleBoardFrame
local function buildUpdating(frame)
	local cover = CreateFrame("Frame", nil, frame.cork) --[[@as TackleUpdatingFrame]]
	cover:SetAllPoints()
	cover:SetFrameLevel(frame.cork:GetFrameLevel() + 20)
	ns.BoardSolid(cover, ns.BOARD_LOOK.shade, "BACKGROUND", 0.3)
	local label = ns.BoardText(cover, ns.BoardFonts().updating, ns.BOARD_LOOK.sealText)
	label:SetPoint("CENTER")
	label:SetText(ns.L.UPDATING)
	cover.label = label
	frame.updating = cover
end

-- Builds the board, hidden: the wood, the plaque, the cork, the ledge, the parts' frames, the empty slip, the updating
-- cover and the close button. It drags by any part that takes no mouse of its own and the client saves no position,
-- so it opens centred each time (TKB-R100); Esc hides it through UISpecialFrames.
---@param board TackleBoard
---@return TackleBoardFrame
local function build(board)
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as TackleBoardFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
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
	ns.NewBoardWood(frame, WIDTH, HEIGHT)

	frame.ledge = CreateFrame("Frame", nil, frame)
	frame.ledge:SetSize(WIDTH, LEDGE_HEIGHT)
	frame.ledge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	ns.NewBoardLedge(frame.ledge)

	frame.cork = CreateFrame("Frame", nil, frame)
	frame.cork:SetSize(CORK_WIDTH, CORK_HEIGHT)
	frame.cork:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_SIDE, -PAD_TOP)
	ns.NewBoardCork(frame.cork, CORK_WIDTH, CORK_HEIGHT)

	frame.plaque = ns.NewBoardPlaque(frame)
	frame.plaque:SetPoint("TOP", 0, -5)
	frame.plaque:SetPlaque(ns.L.TITLE)

	buildParts(frame)
	buildEmpty(board, frame)
	buildUpdating(frame)

	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton") --[[@as Button]]
	frame.close:SetPoint("TOPRIGHT", 6, 6)
	frame.close:SetScript("OnClick", function()
		board:Hide()
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

--- Opens the board, or closes it: Registration's view, the compartment and `/pagle board` (TKB-R1).
function Board:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Open()
	end
end

--- Opens the board, centred if it was closed (TKB-R100), and draws it, handing `goalID` to the parts for the pins'
--- highlight (TKB-R109). Open, it stays where it is and never closes.
---@param goalID string?
function Board:Open(goalID)
	local frame = self.frame or build(self)
	self.frame = frame
	if not frame:IsShown() then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER")
		frame:Show()
	end
	self:Draw("open", nil, goalID)
end

--- Closes the board.
function Board:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

--- Start my board (TKB-R5): starts the board through ns.Start(), unless the projection is updating, then redraws.
function Board:Start()
	if ns.BoardShows(ns.KnownStarted(), ns.IsUpdating(), ns.IsStarted()).startEnabled then
		ns.Start()
	end
	self:Draw("start")
end

--- Draws the board, if it is open: the empty slip and its Start button, "Updating…", and each part logic/Board.lua
--- says is drawn, with its renderer on its own frame (a part with none left bare).
---@param reason string why: "open", "start" or ns.Redraw's reason
---@param detail any ns.Redraw's detail
---@param highlight string? the goal ID ns.OpenBoard was given
function Board:Draw(reason, detail, highlight)
	if not self:IsShown() then
		return
	end
	local frame = self.frame --[[@as TackleBoardFrame]]
	local shows = ns.BoardShows(ns.KnownStarted(), ns.IsUpdating(), ns.IsStarted())
	frame.empty:SetShown(shows.empty)
	frame.start:SetUsable(shows.startEnabled)
	frame.updating:SetShown(shows.updating)
	local drawn = {}
	for _, part in ipairs(shows.parts) do
		drawn[part] = true
	end
	---@type TackleBoardDraw
	local draw = { updating = shows.updating, highlight = highlight, reason = reason, detail = detail }
	for _, part in ipairs(ns.BOARD_PARTS) do
		local partFrame = frame.parts[part]
		partFrame:SetShown(drawn[part] == true)
		local renderer = self.parts:Renderer(part)
		if drawn[part] and renderer then
			renderer(partFrame, draw)
		end
	end
end

-- The board's entry points (logic/Seams.lua lists them); every caller calls them through ns at call time.

--- Opens or closes the Tackle Board (TKB-R1): Registration's view, `/pagle board` and so the compartment's "Tackle
--- Board" call it.
function ns.ToggleBoard()
	ns.board:Toggle()
end

--- Opens the board, highlighting `goalID`'s pin (TKB-R109, drawn by the pins' ticket); open, it stays open. The status
--- button ("Start my board", "Open Tackle Board") and the tracker's lines call it.
---@param goalID string?
function ns.OpenBoard(goalID)
	ns.board:Open(goalID)
end

-- While open, the board redraws at every redraw: the projection, names, completions and live steps.
ns.OnRedraw(function(reason, detail)
	ns.board:Draw(reason, detail)
end)
