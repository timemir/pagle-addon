if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's pins and its overflow strip on the client (TKB-R44, TKB-R55, TKB-R101, TKB-R102, TKB-R104, TKB-R105,
-- TKB-R108, TKB-R109, TKB-R121): the "pins" and "overflow" parts of adapter/Board.lua, drawing what logic/Pins.lua
-- decides in the board art kit's look (PagleArtBoard's Board.lua: P.Notice, P.Poster, P.EmptyPin; Parts.lua's
-- overflow strip). Each pin's slot holds a Notice's paper or an Expedition's poster, an empty pin and a highlight ring,
-- made once and shown as the layout says; each slot hangs where logic/Pins.lua places it, its paper leaning (straight
-- under the mouse, or always with `/pagle board lean` off). While the board is open its pins redraw on the redraw bus
-- (adapter/Board.lua: the live step's at each reset moves a day-bound goal's displayed progress, TKB-R104), on
-- ConditionsChanged with "area" (TKB-R121), and every 60 s for the empty pins' countdown (TKB-R105).

-- The owner of the Core callbacks the pins listen to.
local OWNER = "Pagle_TackleBoard pins"
-- How often the empty pins' times are read again while the board is open (TKB-R105), and how long the highlight
-- lasts (TKB-R109, tackle-board.md › Tunables), in seconds.
local REFRESH, HIGHLIGHT = 60, 2

-- A Notice's paper (236 × 116) and an Expedition's poster (360 × 156), as the kit lays them out: the left margin, where
-- the goal's words start, the right edge of its words, where its foot sits, and how wide its words wrap.
local NOTICE = { left = 13, top = 34, right = 223, foot = 93, wrap = 210, barDown = 4 }
local POSTER = { left = 22, top = 36, right = 338, foot = 131, wrap = 300, barDown = 6 }
-- An empty pin's outline inside its slot: a Notice's, and an Expedition's.
local EMPTY_NOTICE, EMPTY_EXPEDITION = { 232, 108 }, { 352, 146 }
-- The overflow strip: at most 4 chips along its twine, the last one "+N more" when more wait; a chip's padding, its
-- kind's icon and the gap between chips.
local CHIPS, CHIP_GAP, CHIP_ICON = 4, 22, 13

---@class TackleGoalSlipView: Frame
---@field poster boolean
---@field paper TackleSprite
---@field icon TackleSprite        -- its kind (a Notice's ink icon, an Expedition's light badge)
---@field kicker FontString        -- its kind, in small caps (a poster's: "EXPEDITION · KIND", spaced)
---@field text FontString
---@field progress FontString      -- handwritten (TKB-R104)
---@field bar TackleBarView
---@field where FontString         -- where it can be worked
---@field here FontString          -- "I'm here", green, by hand (TKB-R121)
---@field herePin TackleSprite
---@field stranded FontString      -- "no longer catchable" (TKB-R44)
---@field pay FontString           -- a Notice's "pays" by its coin; a poster's "pays 60 Coins"
---@field coin TackleCoinView?     -- a Notice's coin, its pay on it
---@field takeDown TackleTakeDownButton
---@field stamp TackleStampView    -- RE-POSTED (TKB-R55)
---@field seal { wax: TackleSprite, label: FontString }?   -- an Expedition's wax seal: its pay
---@field lean number              -- its paper's lean on its pin
---@field leanNow number?          -- its lean now, moving to or from straight under the mouse
---@field lift number?             -- how far it is lifted now
---@field view TacklePinView?      -- what it shows now, for its hover

---@class TacklePinSlot: Frame
---@field goal TackleGoalSlipView
---@field empty TackleEmptyPinView
---@field highlight TackleHighlightView
---@field goalID string?             -- the goal on it now, if any

---@class TackleOverflowChip: Frame
---@field face TackleThreeSlice
---@field icon TackleSprite
---@field clip TackleSprite
---@field label FontString
---@field count FontString
---@field view TacklePinView?

---@class TackleOverflowFrame: Frame
---@field chips TackleOverflowChip[]
---@field highlights TackleHighlightView[]

-- The goal highlighted now (TKB-R109), and the opening that set it: a later opening's timer wins.
local highlighted, opening = nil, 0
-- The 60 s refresh while the board is open, and whether the Core callbacks are registered.
local ticker, listening = nil, false

-- The hover of a goal (TKB-R102): the realm date and time it was posted, the note, and a Variety Expedition's Species,
-- a tick by each caught one and an empty mark by the rest. `lines` come first.
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
	ns.BoardHover(owner, all, { species = view.species })
end

-- Lays the paper on its pin, leaning by `lean` (straight while hovered).
---@param slip TackleGoalSlipView
---@param lean number
local function layPaper(slip, lean)
	slip.leanNow = lean
	ns.LeanSprite(slip.paper, slip, 0, 0, lean)
end

-- A goal's paper, or an Expedition's poster, on `slot` (TKB-R102), as the kit draws P.Notice and P.Poster: its kind's
-- icon and kicker, its text, its progress by hand over a bar, where it is worked or "I'm here" or "no longer
-- catchable", its pay (a coin on a Notice, a wax seal and words on a poster) and "take it down", or the RE-POSTED
-- stamp. Hovering lifts it above its neighbours, straightens it and shows its hover.
---@param slot Frame
---@param poster boolean
---@return TackleGoalSlipView
local function newGoalSlip(slot, poster)
	local L = ns.L
	local box = poster and POSTER or NOTICE
	local slip = CreateFrame("Frame", nil, slot) --[[@as TackleGoalSlipView]]
	slip:SetAllPoints()
	slip:EnableMouse(true)
	slip.poster, slip.lean = poster, 0
	slip.paper = ns.ArtSprite(slip, "Board", poster and "poster" or "notice", "BACKGROUND")

	if poster then
		slip.icon = ns.ArtSprite(slip, "Board", "b-haul", "ARTWORK")
		ns.PlaceSprite(slip.icon, slip, 22, 6)
		slip.kicker = ns.ArtText(slip, "PosterKind")
		slip.kicker:SetPoint("TOPLEFT", 44, -8)
	else
		slip.icon = ns.ArtSprite(slip, "Board", "k-haul", "ARTWORK")
		ns.PlaceSprite(slip.icon, slip, 13, 13)
		slip.kicker = ns.ArtText(slip, "Kind")
		slip.kicker:SetPoint("TOPLEFT", 32, -15)
		slip.coin = ns.NewBoardCoin(slip, 206, 12)
	end
	slip.text = ns.ArtWrap(slip, poster and "PosterGoal" or "Goal", box.wrap, poster and 2 or 1.5)
	slip.text:SetPoint("TOPLEFT", box.left, -box.top)
	slip.progress = ns.ArtText(slip, poster and "PosterProgress" or "Progress")
	slip.progress:SetPoint("TOPLEFT", slip.text, "BOTTOMLEFT", 0, -4)
	slip.bar = ns.NewBoardBar(slip)

	-- Its foot: where it is worked, "I'm here" or "no longer catchable"; one of the three shows.
	slip.where = ns.ArtText(slip, "Where")
	slip.where:SetPoint("TOPLEFT", box.left, -(box.foot + 3))
	slip.herePin = ns.ArtSprite(slip, "Board", "here", "ARTWORK", 2)
	ns.PlaceSprite(slip.herePin, slip, box.left, box.foot + 4)
	slip.here = ns.ArtText(slip, "Here")
	slip.here:SetPoint("TOPLEFT", box.left + 15, -box.foot)
	slip.here:SetText(L.IM_HERE)
	slip.stranded = ns.ArtText(slip, "Stranded")
	slip.stranded:SetPoint("TOPLEFT", box.left, -(box.foot + 1))

	local button = ns.NewTakeDownLink(slip, L.TAKE_IT_DOWN)
	button:SetPoint("TOPRIGHT", slip, "TOPLEFT", box.right, -(poster and 132 or 94))
	button:SetScript("OnClick", function(self)
		-- Through ns at click time (logic/Seams.lua), and never while updating (TKB-R108); the reroll's ticket checks
		-- TKB-R55's conditions again and confirms (TKB-R56).
		if self.goalID and not ns.board:IsUpdating() then
			ns.TakeDown(self.goalID)
		end
	end)
	slip.takeDown = button

	slip.stamp = ns.NewBoardStamp(slip, L.REPOSTED)
	slip.stamp:SetFrameLevel(slip:GetFrameLevel() + 2)
	slip.stamp:SetPoint("CENTER", slip, "TOPLEFT", poster and 290 or 170, -(poster and 132 or 98))
	if poster then
		slip.pay = ns.ArtText(slip, "PosterPays")
		slip.pay:SetJustifyH("RIGHT")
		local wax = ns.ArtSprite(slip, "Board", "seal", "ARTWORK", 7)
		ns.PlaceSprite(wax, slip, 306, -18)
		local label = ns.ArtText(slip, "Seal", "OVERLAY")
		label:SetJustifyH("CENTER")
		label:SetPoint("CENTER", slip, "TOPLEFT", 343, -19)
		slip.seal = { wax = wax, label = label }
		ns.PlaceSprite(ns.NewBoardTack(slip), slip, 8, 5)
		ns.PlaceSprite(ns.NewBoardTack(slip), slip, 337, 5)
	else
		slip.pay = ns.ArtText(slip, "Pays")
		slip.pay:SetJustifyH("RIGHT")
		slip.pay:SetPoint("TOPRIGHT", slip, "TOPLEFT", 202, -15)
		ns.PlaceSprite(ns.NewBoardTack(slip), slip, 110.5, -5)
	end

	-- Under the mouse it straightens (TKB-R102) and lifts, above its neighbours (adapter/BoardMotion.lua).
	local level = slip:GetFrameLevel()
	slip:SetScript("OnEnter", function(self)
		self:SetFrameLevel(level + 10)
		ns.PinHover(self, self.paper, 0, 2)
		if self.view then
			showHover(self, self.view)
		end
	end)
	slip:SetScript("OnLeave", function(self)
		self:SetFrameLevel(level)
		ns.PinHover(self, self.paper, self.lean, 0)
		ns.BoardHoverHide()
	end)
	return slip
end

-- A slot's paper, empty pin and highlight ring, made on its first draw.
---@param slot TacklePinSlot
---@param poster boolean
local function buildSlot(slot, poster)
	slot.goal = newGoalSlip(slot, poster)
	local size = poster and EMPTY_EXPEDITION or EMPTY_NOTICE
	slot.empty = ns.NewBoardEmptyPin(slot, size[1], size[2])
	slot.empty:SetPoint("CENTER")
	slot.highlight = ns.NewBoardHighlight(slot, poster)
	slot.highlight:SetFrameLevel(slot:GetFrameLevel())
end

-- Draws one goal's lines on its paper (TKB-R102), and lays it on its pin at `lean`.
---@param slip TackleGoalSlipView
---@param goal TackleGoal
---@param view TacklePinView
---@param lean number
local function drawGoal(slip, goal, view, lean)
	local box = slip.poster and POSTER or NOTICE
	slip.view = view
	slip.lean = lean
	layPaper(slip, lean)
	ns.SetSprite(slip.icon, "Board", (slip.poster and "b-" or "k-") .. goal.kind)
	ns.PlaceSprite(slip.icon, slip, slip.poster and 22 or 13, slip.poster and 6 or 13)
	if slip.poster then
		slip.kicker:SetText(ns.Spaced(ns.L.EXPEDITION) .. "   ·   " .. ns.Spaced(view.kicker))
	else
		slip.kicker:SetText(view.kicker:upper())
	end
	slip.text:SetText(view.text)
	slip.progress:SetText(view.progress)
	local barLeft = box.left + slip.progress:GetStringWidth() + 9
	slip.bar:SetBar(box.right - barLeft, view.fill)
	slip.bar:ClearAllPoints()
	slip.bar:SetPoint("TOPLEFT", slip.progress, "TOPRIGHT", 9, -box.barDown)
	slip.where:SetText(view.where)
	slip.stranded:SetText(view.stranded or "")
	slip.stranded:SetShown(view.stranded ~= nil)
	local here = view.stranded == nil and view.here
	slip.here:SetShown(here)
	slip.herePin:SetShown(here)
	slip.where:SetShown(view.stranded == nil and not view.here)
	slip.stamp:SetShown(view.stamp)
	slip.takeDown.goalID = goal.id
	slip.takeDown:SetShown(view.takeDown ~= "hidden")
	slip.takeDown:SetUsable(view.takeDown == "enabled")
	if slip.poster then
		local seal = slip.seal --[[@as { wax: TackleSprite, label: FontString }]]
		seal.label:SetText(view.seal or "")
		slip.pay:SetText(view.pay)
		slip.pay:ClearAllPoints()
		if view.takeDown == "hidden" then
			slip.pay:SetPoint("TOPRIGHT", slip, "TOPLEFT", box.right, -135)
		else
			slip.pay:SetPoint("TOPRIGHT", slip.takeDown.label, "TOPLEFT", -14, -3)
		end
	else
		local coin = slip.coin --[[@as TackleCoinView]]
		slip.pay:SetText(ns.L.PAYS_WORD)
		coin.label:SetText(tostring(goal.pay))
	end
end

-- What a view knows besides each goal (TKB-R104, TKB-R108, TKB-R121), read now.
---@param draw TackleBoardDraw
---@return fun(goal: TackleGoal): TacklePinView
local function viewer(draw)
	local today, zone = ns.State().day, ns.CurrentZone()
	return function(goal)
		return ns.PinView(goal, {
			today = today,
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

-- The "pins" part (TKB-R101, TKB-R102, TKB-R105, TKB-R109): each pin in its place, its goal on its paper or poster, or
-- its empty pin.
---@param frame TacklePinsFrame
---@param draw TackleBoardDraw
local function drawPins(frame, draw)
	listen()
	refreshEveryMinute()
	local state = ns.State()
	updateHighlight(draw, state)
	local layout = ns.PinLayout(state, ns.api)
	local places = ns.PinPlaces(#layout.overflow > 0)
	local view = viewer(draw)
	for _, row in ipairs({ { "expeditions", true }, { "notices", false } }) do
		local name, poster = row[1], row[2]
		for i, slot in ipairs(frame.slots[name]) do
			---@cast slot TacklePinSlot
			if not slot.goal then
				buildSlot(slot, poster)
			end
			local place = places[name][i]
			slot:ClearAllPoints()
			slot:SetPoint("TOPLEFT", frame, "TOPLEFT", place.x, -place.y)
			local pin = layout[name][i]
			local goal = pin.goal
			slot.goalID = goal and goal.id
			slot.goal:SetShown(goal ~= nil)
			slot.empty:SetShown(goal == nil)
			if goal then
				drawGoal(slot.goal, goal, view(goal), place.lean)
			else
				slot.empty:SetEmpty(pin.empty)
			end
			slot.highlight:SetShown(goal ~= nil and goal.id == highlighted)
		end
	end
end

-- The overflow strip's twine: two-tone dashes along it.
---@param strip Frame
local function twine(strip)
	for x = 0, strip:GetWidth() - 2, 6 do
		for _, piece in ipairs({ { 0, 4, "C8A878" }, { 4, 2, "8A6A40" } }) do
			local thread = ns.BoardSolid(strip, piece[3], 1, "BACKGROUND")
			thread:ClearAllPoints()
			thread:SetSize(piece[2], 2)
			thread:SetPoint("TOPLEFT", x + piece[1], -10)
		end
	end
end

-- A chip on the overflow strip (TKB-R101): a paper clipped to the twine with its kind's icon, its text and its count
-- by hand; its hover shows the rest.
---@param strip TackleOverflowFrame
---@param i integer
---@return TackleOverflowChip
local function newChip(strip, i)
	local chip = CreateFrame("Frame", nil, strip) --[[@as TackleOverflowChip]]
	chip:EnableMouse(true)
	chip.face = CreateFrame("Frame", nil, chip) --[[@as TackleThreeSlice]]
	chip.face:SetPoint("TOPLEFT")
	chip.icon = ns.ArtSprite(chip, "Board", "k-haul", "OVERLAY")
	chip.label = ns.ArtText(chip, "Chip")
	chip.label:SetPoint("TOPLEFT", 10 + CHIP_ICON + 6, -11)
	chip.count = ns.ArtText(chip, "ChipCount")
	chip.count:SetPoint("LEFT", chip.label, "RIGHT", 6, 0)
	chip.clip = ns.ArtSprite(chip, "Board", "chip-clip", "OVERLAY", 2)
	chip:SetScript("OnEnter", function(self)
		local view = self.view
		if view then
			local where = view.stranded or (view.here and ns.L.IM_HERE or view.where)
			showHover(self, view, { view.text, view.progress, where, view.pay })
		end
	end)
	chip:SetScript("OnLeave", ns.BoardHoverHide)
	local ring = ns.NewBoardHighlight(chip, false)
	ring:SetFrameLevel(chip:GetFrameLevel())
	strip.highlights[i] = ring
	return chip
end

-- Sizes `chip` to its words and lays its paper, icon and clip: a chip with a goal shows its kind's icon, the last one
-- "+N more" only its words.
---@param chip TackleOverflowChip
---@param kind string? the goal's kind, nil for "+N more"
---@return number width
local function layChip(chip, kind)
	local width
	chip.icon:SetShown(kind ~= nil)
	chip.count:SetShown(kind ~= nil)
	chip.label:ClearAllPoints()
	if kind then
		ns.SetSprite(chip.icon, "Board", "k-" .. kind)
		ns.SizeSprite(chip.icon, CHIP_ICON)
		ns.PlaceSprite(chip.icon, chip, 10, 11)
		ns.SetArtFont(chip.label, "Chip")
		chip.label:SetPoint("TOPLEFT", 10 + CHIP_ICON + 6, -11)
		width = 10 + CHIP_ICON + 6 + chip.label:GetStringWidth() + 6 + chip.count:GetStringWidth() + 12
	else
		ns.SetArtFont(chip.label, "ChipMore")
		chip.label:SetPoint("TOPLEFT", 10, -8)
		width = chip.label:GetStringWidth() + 22
	end
	ns.SetThreeSlice(chip.face, "Board", "chip", width, 10, "ARTWORK")
	chip:SetSize(width, chip.face:GetHeight())
	ns.PlaceSprite(chip.clip, chip, width / 2 - 3.5, -7)
	return width
end

-- The "overflow" part (TKB-R101): the open goals with no pin, by seq, clipped to a twine under the Notice rows; past
-- 4, the last chip counts the rest.
---@param frame TackleOverflowFrame
---@param draw TackleBoardDraw
local function drawOverflow(frame, draw)
	if not frame.chips then
		frame.chips, frame.highlights = {}, {}
		twine(frame)
	end
	local goals = ns.PinLayout(ns.State(), ns.api).overflow
	local view = viewer(draw)
	local shown = #goals > CHIPS and CHIPS - 1 or #goals
	local x = 20
	for i = 1, math.max(#frame.chips, math.min(#goals, CHIPS)) do
		local chip = frame.chips[i] or newChip(frame, i)
		frame.chips[i] = chip
		local goal = goals[i]
		chip:SetShown(goal ~= nil)
		frame.highlights[i]:SetShown(false)
		if goal and i <= shown then
			local pinView = view(goal)
			chip.view = pinView
			chip.label:SetText(pinView.text)
			chip.count:SetText(pinView.progress)
			frame.highlights[i]:SetShown(goal.id == highlighted)
		elseif goal then
			chip.view = nil
			chip.label:SetText(ns.OverflowMore(#goals - shown))
		end
		if goal then
			local width = layChip(chip, chip.view and goal.kind or nil)
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", x, -4)
			x = x + width + CHIP_GAP
		end
	end
end

ns.board:RegisterPart("pins", drawPins)
ns.board:RegisterPart("overflow", drawOverflow)
