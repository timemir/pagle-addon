if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board on the client (TKB-R100, TKB-R107, TKB-R108, TKB-R193): a leather frame with a brass plaque reading
-- "Tackle Board" round a cork board, with a ledge below, drawing what logic/Board.lua decides: the welcome slip and its
-- Start button before Start, "Updating…" while the projection updates, and each part's renderer once started. The
-- parts' contents are the pins' and the ledge's (adapter/Pins.lua, adapter/Ledge.lua); this file draws only the board.
-- It makes no secure frames, so it opens and works while restricted (TKB-R193). The look is the board art kit's
-- (PagleArtBoard's Board.lua and Overlays.lua), through adapter/BoardArt.lua; its textures load when the board first
-- opens.

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists (TKB-R100).
local FRAME_NAME = "PagleTackleBoard"
-- The kit's board: 1000 × 660, the cork 952 × 466 inside the frame's leather, the ledge under it from 500 down.
local WIDTH, HEIGHT = 1000, 660
local CORK_X, CORK_Y, CORK_WIDTH, CORK_HEIGHT = 24, 34, 952, 466
local LEDGE_Y = 500
local LEDGE_HEIGHT = HEIGHT - LEDGE_Y

-- Each part's place on the cork (the kit's): the pins over the left of it (logic/Pins.lua places each pin), the
-- overflow strip under the Notice rows, the spike down the right; the ledge part fills the ledge.
local OVERFLOW_WIDTH, OVERFLOW_HEIGHT = 760, 42
local SPIKE_X, SPIKE_Y, SPIKE_WIDTH, SPIKE_HEIGHT = 792, 14, 150, 440
-- A Notice's paper and an Expedition's poster.
local NOTICE_WIDTH, NOTICE_HEIGHT = 236, 116
local POSTER_WIDTH, POSTER_HEIGHT = 360, 156

-- The welcome slip (TKB-R107): 300 × 150 on the cork, leaning a little, Start my board under it.
local WELCOME_X, WELCOME_Y, WELCOME_WIDTH, WELCOME_HEIGHT, WELCOME_LEAN = 326, 112, 300, 150, -1.2
local START_X, START_Y, START_WIDTH = 385, 318, 182
-- The "Updating…" note (TKB-R108), and how dark the cork goes under it.
local NOTE_WIDTH, NOTE_HEIGHT, NOTE_LEAN, UPDATING_DIM = 340, 112, -1.5, 0.55
-- The fire's glow over the cork: faint on the empty board, by the Campfire's brightness while it burns.
local GLOW_EMPTY = 0.25

---@class TacklePinsFrame: Frame
---@field slots { expeditions: Frame[], notices: Frame[] }   -- one frame per pin, in board order (TKB-R101)

---@class TackleUpdatingFrame: Frame
---@field note Frame          -- the pinned note
---@field paper TackleSprite
---@field label FontString
---@field reason FontString

---@class TackleWelcomeFrame: Frame
---@field paper TackleSprite

---@class TacklePlaque
---@field label FontString

---@class TackleBoardFrame: Frame
---@field close Button
---@field art TackleSprite                         -- the frame: leather, brass corners, the plaque and the ledge
---@field plaque TacklePlaque
---@field cork Frame
---@field glow TackleSprite                        -- the Campfire's light over the cork
---@field ledge Frame
---@field empty TackleWelcomeFrame                 -- the welcome slip (TKB-R107)
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

-- A frame on `parent` of `width` × `height`, its top left `x`, `y` from `parent`'s (y down).
---@return Frame
local function placed(parent, width, height, x, y)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(width, height)
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	return frame
end

-- The parts' frames on the cork and the ledge, and the pins' slots (adapter/Pins.lua moves each to its place).
---@param frame TackleBoardFrame
local function buildParts(frame)
	local cork = frame.cork
	local pins = placed(cork, CORK_WIDTH, CORK_HEIGHT, 0, 0) --[[@as TacklePinsFrame]]
	pins.slots = { expeditions = {}, notices = {} }
	local places = ns.PinPlaces(false)
	for i, at in ipairs(places.expeditions) do
		pins.slots.expeditions[i] = placed(pins, POSTER_WIDTH, POSTER_HEIGHT, at.x, at.y)
	end
	for i, at in ipairs(places.notices) do
		pins.slots.notices[i] = placed(pins, NOTICE_WIDTH, NOTICE_HEIGHT, at.x, at.y)
	end
	local strip = ns.PinPlaces(true).overflow --[[@as { x: number, y: number }]]
	frame.parts = {
		pins = pins,
		overflow = placed(cork, OVERFLOW_WIDTH, OVERFLOW_HEIGHT, strip.x, strip.y),
		spike = placed(cork, SPIKE_WIDTH, SPIKE_HEIGHT, SPIKE_X, SPIKE_Y),
		ledge = placed(frame.ledge, WIDTH, LEDGE_HEIGHT, 0, 0),
	}
end

-- The cork (TKB-R100): one tile repeated across it, shaded at its edges, and the Campfire's glow added over it.
---@param frame TackleBoardFrame
local function buildCork(frame)
	local cork = placed(frame, CORK_WIDTH, CORK_HEIGHT, CORK_X, CORK_Y)
	local tile = cork:CreateTexture(nil, "BACKGROUND", nil, -8)
	tile:SetTexture(ns.CORK_TEXTURE, "REPEAT", "REPEAT")
	tile:SetAllPoints()
	tile:SetTexCoord(0, CORK_WIDTH / ns.CORK_TILE, 0, CORK_HEIGHT / ns.CORK_TILE)
	local shade = ns.ArtSprite(cork, "Glow", "cork-shade", "BACKGROUND", -7)
	shade:SetAllPoints()
	frame.glow = ns.ArtSprite(cork, "Glow", "cork-glow", "BACKGROUND", -6)
	frame.glow:SetAllPoints()
	frame.glow:SetBlendMode("ADD")
	frame.cork = cork
end

-- The welcome slip with its words, and Start my board under it (TKB-R107, TKB-R5).
---@param board TackleBoard
---@param frame TackleBoardFrame
local function buildWelcome(board, frame)
	local slip = placed(frame.cork, WELCOME_WIDTH, WELCOME_HEIGHT, WELCOME_X, WELCOME_Y) --[[@as TackleWelcomeFrame]]
	slip:EnableMouse(true)
	slip.paper = ns.ArtSprite(slip, "Board", "welcome", "BACKGROUND")
	frame.slipText = ns.ArtWrap(slip, "Welcome", 256, 4.8)
	frame.slipText:SetPoint("TOPLEFT", 22, -22)
	frame.slipText:SetText(ns.L.EMPTY_SLIP)
	ns.PlaceSprite(ns.NewBoardTack(slip), slip, 142.5, -5)
	frame.empty = slip
	frame.start = ns.NewBoardButton(slip, ns.L.START_MY_BOARD, START_WIDTH, "Button", function()
		board:Start()
	end)
	frame.start:SetPoint("TOPLEFT", slip, "TOPLEFT", START_X - WELCOME_X, -(START_Y - WELCOME_Y))
end

-- "Updating…" over the cork (TKB-R108): the cork darkened, and a pinned note with the words and why, above the slip and
-- the parts. It takes no mouse, so the papers under it still show their tooltips.
---@param frame TackleBoardFrame
local function buildUpdating(frame)
	local cover = CreateFrame("Frame", nil, frame.cork) --[[@as TackleUpdatingFrame]]
	cover:SetAllPoints()
	cover:SetFrameLevel(frame.cork:GetFrameLevel() + 20)
	ns.BoardSolid(cover, "1C0E04", UPDATING_DIM, "BACKGROUND")
	local note = CreateFrame("Frame", nil, cover)
	note:SetSize(NOTE_WIDTH, NOTE_HEIGHT)
	note:SetPoint("CENTER")
	cover.note = note
	cover.paper = ns.ArtSprite(note, "Board", "cover-note", "BORDER")
	cover.label = ns.ArtText(note, "Updating")
	cover.label:SetJustifyH("CENTER")
	cover.label:SetPoint("TOP", 0, -22)
	cover.label:SetText(ns.L.UPDATING)
	cover.reason = ns.ArtWrap(note, "UpdatingNote", 300, 4)
	cover.reason:SetJustifyH("CENTER")
	cover.reason:SetPoint("TOP", 0, -58)
	cover.reason:SetText(ns.L.UPDATING_NOTE)
	ns.PlaceSprite(ns.NewBoardTack(note), note, 163, -5)
	frame.updating = cover
end

-- Builds the board, hidden: the cork, the frame's art with its plaque and close mark, the ledge, the parts' frames, the
-- welcome slip and the updating cover. It drags by any part that takes no mouse of its own and the client saves no
-- position, so it opens centred each time (TKB-R100); Esc hides it through UISpecialFrames.
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

	buildCork(frame)
	frame.art = ns.ArtSprite(frame, "Frame", "frame", "BORDER")
	ns.PlaceSprite(frame.art, frame, 0, 0)
	local title = ns.ArtText(frame, "Title")
	title:SetJustifyH("CENTER")
	title:SetPoint("CENTER", frame, "TOP", 0, -2)
	title:SetText(ns.Spaced(ns.L.TITLE))
	frame.plaque = { label = title }

	frame.ledge = placed(frame, WIDTH, LEDGE_HEIGHT, 0, LEDGE_Y)
	frame.ledge:SetFrameLevel(frame:GetFrameLevel() + 3)

	buildParts(frame)
	buildWelcome(board, frame)
	buildUpdating(frame)

	frame.close = CreateFrame("Button", nil, frame) --[[@as Button]]
	frame.close:SetSize(26, 26)
	frame.close:SetPoint("TOPLEFT", frame, "TOPLEFT", 958, -15)
	frame.close:SetFrameLevel(frame:GetFrameLevel() + 20)
	ns.ArtSprite(frame.close, "Board", "close", "ARTWORK"):SetAllPoints()
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
	ns.LeanSprite(frame.empty.paper, frame.empty, 0, 0, WELCOME_LEAN)
	ns.LeanSprite(frame.updating.paper, frame.updating.note, 0, 0, NOTE_LEAN)
	-- The fire's glow over the cork: faint before Start, by the Campfire's brightness while it burns, none without one.
	local glow = shows.empty and GLOW_EMPTY or nil
	if #shows.parts > 0 then
		local fire = ns.CampfireView(ns.State().fire)
		glow = fire.state == "lit" and 0.75 + 0.25 * fire.bright or nil
	end
	frame.glow:SetShown(glow ~= nil)
	frame.glow:SetAlpha(glow or 0)
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
