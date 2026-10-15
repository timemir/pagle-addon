if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's pins and its overflow strip on the client (TKB-R44, TKB-R55, TKB-R101, TKB-R102, TKB-R104, TKB-R105,
-- TKB-R108, TKB-R109, TKB-R121): the "pins" and "overflow" parts of adapter/Board.lua, drawing what logic/Pins.lua
-- decides in adapter/BoardWidgets.lua's art. Each pin's slot holds a slip (a Notice's) or a poster (an Expedition's),
-- an empty pin and a highlight ring, made once and shown as the layout says. While the board is open its pins redraw
-- on the redraw bus (adapter/Board.lua), on ConditionsChanged with "area" (TKB-R121), on SessionStarted and
-- SessionEnded (TKB-R104), and every 60 s for the empty pins' countdown (TKB-R105).

-- The owner of the Core callbacks the pins listen to.
local OWNER = "Pagle_TackleBoard pins"
-- How often the empty pins' times are read again while the board is open (TKB-R105), and how long the highlight
-- lasts (TKB-R109, tackle-board.md › Tunables), in seconds.
local REFRESH, HIGHLIGHT = 60, 2

-- Inside a slip (variant C's `.slip`): 12 pixels at the sides, the lines from 16 below its top (22 below a poster's,
-- under its red edge), the foot 8 above its bottom; an ink bar 9 high; the seal 40 across, over the top right corner.
local PAD, TOP, POSTER_TOP, FOOT, BAR_HEIGHT, SEAL = 12, 16, 22, 8, 9, 40
-- An empty pin's outline inside its slot: variant C's 150 × 96 for a Notice, 190 × 120 for an Expedition.
local EMPTY_NOTICE, EMPTY_EXPEDITION = { 150, 96 }, { 190, 120 }
-- The overflow strip's chips: at most 4 across its 676 pixels, the last one "+N more" when more wait.
local CHIPS, CHIP_WIDTH, CHIP_GAP = 4, 163, 8

---@class TackleGoalSlipView: TackleSlipView
---@field kicker TackleKickerView
---@field text FontString
---@field progress FontString       -- handwritten (TKB-R104)
---@field bar TackleInkBarView
---@field where FontString          -- where it can be worked
---@field here FontString           -- "I'm here", green, by hand (TKB-R121)
---@field stranded FontString       -- "no longer catchable" (TKB-R44)
---@field pay FontString
---@field takeDown TackleTakeDownButton
---@field stamp TackleStampView     -- RE-POSTED (TKB-R55)
---@field seal TackleSealView?      -- an Expedition's pay
---@field view TacklePinView?       -- what it shows now, for its hover

---@class TackleTakeDownButton: Button
---@field label FontString
---@field goalID string?

---@class TacklePinSlot: Frame
---@field goal TackleGoalSlipView
---@field empty TackleEmptyPinView
---@field highlight TackleHighlightView
---@field goalID string?             -- the goal on it now, if any

---@class TackleOverflowChip: Frame
---@field label FontString
---@field view TacklePinView?

---@class TackleOverflowFrame: Frame
---@field chips TackleOverflowChip[]
---@field highlights TackleHighlightView[]

-- The goal highlighted now (TKB-R109), and the opening that set it: a later opening's timer wins.
local highlighted, opening = nil, 0
-- The 60 s refresh while the board is open, and whether the Core callbacks are registered.
local ticker, listening = nil, false

-- The hover of a goal (TKB-R102): the realm date and time it was posted, the note, and a Variety Expedition's Species,
-- a tick by each caught one and an empty box by the rest. `lines` come first.
---@param owner Frame
---@param view TacklePinView
---@param lines string[]?
local function showHover(owner, view, lines)
	local all = {}
	for _, line in ipairs(lines or {}) do
		all[#all + 1] = line
	end
	for _, line in ipairs(view.hover) do
		all[#all + 1] = line
	end
	for _, species in ipairs(view.species or {}) do
		local icon = species.caught and ns.BOARD_TEXTURES.tick or ns.BOARD_TEXTURES.box
		all[#all + 1] = "|T" .. icon .. ":0|t " .. species.name
	end
	ns.BoardHover(owner, all)
end

-- Places `line` under `above`, `gap` pixels down, `width` wide (a slip's inside).
---@param line Region
---@param above Region
---@param gap number
---@param width number
local function under(line, above, gap, width)
	line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
	line:SetWidth(width)
end

-- A goal's slip, or an Expedition's poster, on `slot` (TKB-R102): its kicker, text, progress over an ink bar, where
-- or "I'm here" or "no longer catchable", pay and "take it down" at its foot, the RE-POSTED stamp, and a poster's
-- seal. Hovering lifts it above its neighbours and shows its hover.
---@param slot Frame
---@param width number
---@param height number
---@param poster boolean
---@return TackleGoalSlipView
local function newGoalSlip(slot, width, height, poster)
	local look = ns.BOARD_LOOK
	local fonts = ns.BoardFonts()
	local inner = width - 2 * PAD
	local slip = ns.NewBoardSlip(slot, width, height, poster) --[[@as TackleGoalSlipView]]
	slip:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)

	slip.kicker = ns.NewBoardKicker(slip)
	slip.kicker:SetPoint("TOPLEFT", PAD, -(poster and POSTER_TOP or TOP))
	slip.text = ns.NewBoardPrinted(slip, poster)
	under(slip.text, slip.kicker, 2, inner)
	slip.progress = ns.NewBoardHand(slip)
	under(slip.progress, slip.text, 3, inner)
	slip.bar = ns.NewBoardInkBar(slip, inner, BAR_HEIGHT)
	under(slip.bar, slip.progress, 2, inner)
	-- Where it is worked, "I'm here" or "no longer catchable": one of the three shows, under the bar.
	slip.where = ns.BoardText(slip, fonts.small, look.where)
	under(slip.where, slip.bar, 3, inner)
	slip.here = ns.NewBoardHand(slip, look.here)
	under(slip.here, slip.bar, 2, inner)
	slip.here:SetText(ns.L.IM_HERE)
	slip.stranded = ns.BoardText(slip, fonts.small, look.red)
	under(slip.stranded, slip.bar, 3, inner)

	slip.pay = ns.NewBoardHand(slip, look.pay)
	slip.pay:SetPoint("BOTTOMLEFT", PAD, FOOT)
	local button = CreateFrame("Button", nil, slip) --[[@as TackleTakeDownButton]]
	button.label = ns.NewBoardHand(button, look.red)
	button.label:SetPoint("CENTER")
	button.label:SetText(ns.L.TAKE_IT_DOWN)
	button:SetSize(button.label:GetStringWidth() + 8, 20)
	button:SetPoint("BOTTOMRIGHT", -PAD + 4, FOOT - 4)
	button:SetScript("OnClick", function(self)
		-- Through ns at click time (logic/Seams.lua), and never while updating (TKB-R108); the reroll's ticket checks
		-- TKB-R55's conditions again and confirms (TKB-R56).
		if self.goalID and not ns.board:IsUpdating() then
			ns.TakeDown(self.goalID)
		end
	end)
	slip.takeDown = button

	slip.stamp = ns.NewBoardStamp(slip)
	slip.stamp:SetStamp(ns.L.REPOSTED)
	slip.stamp:SetPoint("TOPRIGHT", -6, poster and -(POSTER_TOP + 24) or -(TOP + 6))
	slip.stamp:SetFrameLevel(slip:GetFrameLevel() + 2)
	if poster then
		slip.seal = ns.NewBoardSeal(slip, SEAL)
		slip.seal:SetPoint("CENTER", slip, "TOPRIGHT", -6, -6)
	end

	-- Variant C tilts a slip and straightens it under the mouse; frames can't rotate, so it lifts instead: above its
	-- neighbours and two pixels up.
	local level = slip:GetFrameLevel()
	slip:SetScript("OnEnter", function(self)
		self:SetFrameLevel(level + 10)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 2)
		if self.view then
			showHover(self, self.view)
		end
	end)
	slip:SetScript("OnLeave", function(self)
		self:SetFrameLevel(level)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
		ns.BoardHoverHide()
	end)
	return slip
end

-- A slot's slip, empty pin and highlight ring, made on its first draw.
---@param slot TacklePinSlot
---@param poster boolean
local function buildSlot(slot, poster)
	local width, height = slot:GetWidth(), slot:GetHeight()
	slot.goal = newGoalSlip(slot, width, height, poster)
	local size = poster and EMPTY_EXPEDITION or EMPTY_NOTICE
	slot.empty = ns.NewBoardEmptyPin(slot, size[1], size[2])
	slot.empty:SetPoint("CENTER")
	slot.highlight = ns.NewBoardHighlight(slot)
	slot.highlight:SetPoint("TOPLEFT", -5, 5)
	slot.highlight:SetPoint("BOTTOMRIGHT", 5, -5)
	slot.highlight:SetFrameLevel(slot:GetFrameLevel() + 30)
end

-- Draws one goal's lines on its slip (TKB-R102).
---@param slip TackleGoalSlipView
---@param goal TackleGoal
---@param view TacklePinView
local function drawGoal(slip, goal, view)
	slip.view = view
	slip.kicker:SetKicker(view.kicker)
	slip.text:SetText(view.text)
	slip.progress:SetText(view.progress)
	slip.bar:SetBar(view.fill)
	slip.where:SetText(view.where)
	slip.stranded:SetText(view.stranded or "")
	slip.stranded:SetShown(view.stranded ~= nil)
	slip.here:SetShown(view.stranded == nil and view.here)
	slip.where:SetShown(view.stranded == nil and not view.here)
	slip.pay:SetText(view.pay)
	slip.stamp:SetShown(view.stamp)
	slip.takeDown.goalID = goal.id
	slip.takeDown:SetShown(view.takeDown ~= "hidden")
	slip.takeDown:SetEnabled(view.takeDown == "enabled")
	slip.takeDown:SetAlpha(view.takeDown == "enabled" and 1 or 0.5)
	if slip.seal then
		slip.seal:SetSeal(view.seal or "")
	end
end

-- What a view knows besides each goal (TKB-R104, TKB-R108, TKB-R121), read now.
---@param draw TackleBoardDraw
---@return fun(goal: TackleGoal): TacklePinView
local function viewer(draw)
	local session, zone = Pagle.GetSession(), ns.CurrentZone()
	return function(goal)
		return ns.PinView(goal, {
			session = session,
			zone = zone,
			updating = draw.updating,
			canTakeDown = ns.CanTakeDown(goal.id),
		})
	end
end

-- Registers the Core callbacks the pins redraw on, once, at the first draw: only a started board's open view listens,
-- so an inert board never does (CORE-R13). Each redraws the board if it is open (adapter/Board.lua's Draw).
local function listen()
	if listening then
		return
	end
	listening = true
	Pagle.RegisterCallback(OWNER, "ConditionsChanged", function(_, keys)
		for _, key in ipairs(keys or {}) do
			if key == "area" then
				ns.board:Draw("area")
				return
			end
		end
	end)
	Pagle.RegisterCallback(OWNER, "SessionStarted", function()
		ns.board:Draw("session")
	end)
	Pagle.RegisterCallback(OWNER, "SessionEnded", function()
		ns.board:Draw("session")
	end)
end

-- Reads the empty pins' times again every 60 s while the board is open (TKB-R105); it stops once the board is closed
-- and starts again at the next draw.
local function refreshEveryMinute()
	if ticker then
		return
	end
	ticker = C_Timer.NewTicker(REFRESH, function(self)
		if not ns.board:IsShown() then
			self:Cancel()
			ticker = nil
			return
		end
		ns.board:Draw("minute")
	end)
end

-- The highlight (TKB-R109): the drawing that opened the board highlights its goal, while it is open, for 2 s; an
-- opening with none, or with a goal no longer open, highlights nothing.
---@param draw TackleBoardDraw
---@param state TackleBoardState
local function updateHighlight(draw, state)
	if draw.reason ~= "open" then
		return
	end
	opening = opening + 1
	highlighted = ns.HighlightedGoal(state, draw.highlight)
	if highlighted then
		local this = opening
		C_Timer.After(HIGHLIGHT, function()
			if opening == this then
				highlighted = nil
				ns.board:Draw("highlight")
			end
		end)
	end
end

-- The "pins" part (TKB-R101, TKB-R102, TKB-R105, TKB-R109): each pin's goal on its slip or poster, or its empty pin.
---@param frame TacklePinsFrame
---@param draw TackleBoardDraw
local function drawPins(frame, draw)
	listen()
	refreshEveryMinute()
	local state = ns.State()
	updateHighlight(draw, state)
	local layout = ns.PinLayout(state, ns.api)
	local view = viewer(draw)
	for _, row in ipairs({ { "expeditions", true }, { "notices", false } }) do
		local name, poster = row[1], row[2]
		for i, slot in ipairs(frame.slots[name]) do
			---@cast slot TacklePinSlot
			if not slot.goal then
				buildSlot(slot, poster)
			end
			local pin = layout[name][i]
			local goal = pin.goal
			slot.goalID = goal and goal.id
			slot.goal:SetShown(goal ~= nil)
			slot.empty:SetShown(goal == nil)
			if goal then
				drawGoal(slot.goal, goal, view(goal))
			else
				slot.empty:SetEmpty(pin.empty)
			end
			slot.highlight:SetShown(goal ~= nil and goal.id == highlighted)
		end
	end
end

-- A chip in the overflow strip (TKB-R101): a scrap of paper with the goal's kind and text; its hover shows the rest.
---@param strip TackleOverflowFrame
---@param i integer
---@return TackleOverflowChip
local function newChip(strip, i)
	local look = ns.BOARD_LOOK
	local chip = CreateFrame("Frame", nil, strip) --[[@as TackleOverflowChip]]
	chip:SetSize(CHIP_WIDTH, strip:GetHeight() - 4)
	chip:SetPoint("TOPLEFT", (i - 1) * (CHIP_WIDTH + CHIP_GAP), -2)
	chip:EnableMouse(true)
	ns.BoardScrap(chip)
	chip.label = ns.BoardText(chip, ns.BoardFonts().small, look.ink)
	chip.label:SetWordWrap(false)
	chip.label:SetWidth(CHIP_WIDTH - 12)
	chip.label:SetPoint("LEFT", 6, 1)
	chip:SetScript("OnEnter", function(self)
		local view = self.view
		if view then
			local where = view.stranded or (view.here and ns.L.IM_HERE or view.where)
			showHover(self, view, { view.text, view.progress, where, view.pay })
		end
	end)
	chip:SetScript("OnLeave", ns.BoardHoverHide)
	local ring = ns.NewBoardHighlight(strip)
	ring:SetPoint("TOPLEFT", chip, "TOPLEFT", -3, 3)
	ring:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 3, -3)
	strip.highlights[i] = ring
	return chip
end

-- The "overflow" part (TKB-R101): the open goals with no pin, by seq, under the Notice rows; past 4, the last chip
-- counts the rest.
---@param frame TackleOverflowFrame
---@param draw TackleBoardDraw
local function drawOverflow(frame, draw)
	frame.chips = frame.chips or {}
	frame.highlights = frame.highlights or {}
	local goals = ns.PinLayout(ns.State(), ns.api).overflow
	local view = viewer(draw)
	local shown = #goals > CHIPS and CHIPS - 1 or #goals
	for i = 1, math.max(#frame.chips, math.min(#goals, CHIPS)) do
		local chip = frame.chips[i] or newChip(frame, i)
		frame.chips[i] = chip
		local goal = goals[i]
		chip:SetShown(goal ~= nil)
		frame.highlights[i]:SetShown(false)
		if goal and i <= shown then
			local pinView = view(goal)
			chip.view = pinView
			chip.label:SetText(pinView.chip)
			frame.highlights[i]:SetShown(goal.id == highlighted)
		elseif goal then
			chip.view = nil
			chip.label:SetText(ns.OverflowMore(#goals - shown))
		end
	end
end

ns.board:RegisterPart("pins", drawPins)
ns.board:RegisterPart("overflow", drawOverflow)
