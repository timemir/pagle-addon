if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The spike and the ledge on the client (TKB-R64, TKB-R103, TKB-R106, TKB-R193; SHOP-R41; ADR 0009): the "spike" and
-- "ledge" parts of adapter/Board.lua, drawing what logic/Ledge.lua decides in the board art kit's look (PagleArtBoard's
-- Board.lua and Overlays.lua). The spike hangs today's done slips on one nail down the right of the cork, each swung
-- its own way, the later over the earlier. The ledge holds, left to right, the Campfire (clicking it opens the Campfire
-- card), the Fly Box (clicking it opens its drawer), the brass tally plate (it opens the card too) and the shop card,
-- which calls Pagle.OpenShop() and so prints Core's line while restricted. The card and the drawer lie over the
-- darkened cork, one at a time; each is made at its first opening, so their textures (Card, Flies) load then; each
-- closes with its mark, and both are closed when the board opens. The board never shows the Coins balance (ADR 0009).
-- Every symbol is a texture, never a glyph (CORE-R9).

-- The spike (the kit's): its slips hang from the nail's hole at 68, 12 of a slip whose top left is 7, 38; the label sits
-- 20 under the stack, which reaches at most 250 below the first slip.
local SLIP_X, SLIP_Y, SLIP_WIDTH, SLIP_HEIGHT, HOLE_X, HOLE_Y, STACK_ROOM = 7, 38, 136, 92, 68, 12, 250
-- The lines of a done slip, from its top left, in the places it can set them (#471). The kit's: the kicker at 22, the goal
-- text from 36 and the note at 68, all x 11 to 125 (114 wide). The roomier one, which the paper's art allows: the kicker
-- at 18, under the nail's hole (it ends at 17), the goal text right under the kicker, the note down to 89 (the torn
-- edge's top), and x 7 to 129 (122 wide), the paper being straight to 0 and 136. The goal text takes the first of these
-- layouts and fonts whose height fits between the kicker and the note.
local SLIP_LAYOUTS = {
	{ x = 11, width = 114, kickerY = 22, goalY = 36, gap = 2, noteY = 68, bottom = 88 },
	{ x = 7, width = 122, kickerY = 18, gap = 1, bottom = 89 },
}
-- Each candidate: the layout, then the goal text's font. The kit's look while the text fits in it at 13.
local SLIP_FITS = {
	{ 1, "DoneGoal" },
	{ 2, "DoneGoal" },
	{ 2, "DoneGoalSmall" },
	{ 2, "DoneGoalTiny" },
}
local GOAL_SPACING, GOAL_MOST_LINES = 1.3, 8
-- The Campfire card and the Fly Box drawer: their top left on the cork and their size, and how dark the cork goes
-- under them. They and the veil lie at their layers (ns.BOARD_LAYERS), over the parts, the nail and "Updating…".
local CARD_X, CARD_Y, CARD_WIDTH, CARD_HEIGHT, CARD_LEAN = 76, 16, 800, 434, -0.5
local DRAWER_X, DRAWER_Y, DRAWER_WIDTH, DRAWER_HEIGHT = 92, 6, 768, 474
local VEIL_ALPHA = 0.45
-- The most done slips stacked one level apart on the spike before they share its top level: they stay inside the
-- spike's layer, under the nail's.
local SLIP_LEVELS = 40
-- The card's day cells: 38 square, 42 apart, from 84, 138; its weeks' rows 42 apart.
local DAY_X, DAY_Y, DAY_STEP, DAY_SIZE = 84, 138, 42, 38
-- The drawer's compartments: 6 across its 700 units, 74 high, 78 apart.
local CELL_COLUMNS, CELL_X, CELL_Y, CELL_HEIGHT, CELL_ROW = 6, 24, 44, 74, 78
local CELL_WIDTH = (728 - 8 - 20) / CELL_COLUMNS
-- The Refresh ticket's icon beside the count of Refreshes held: its height in UI units, its width following (#466).
local REFRESH_ICON = 16
-- The Campfire on the ledge: its clickable box from the ledge's top left, holding the fire, its words and its sticks.
local FIRE_X, FIRE_Y, FIRE_WIDTH, FIRE_HEIGHT = 20, 10, 290, 120
-- The Campfire's stage (adapter/BoardMotion.lua's layers) by its flame's step (logic/Ledge.lua's CampfireView: 1 below
-- 7 days, then one more at 7, 30, 100 and 365), or by its state with no flame.
local FIRE_STEPS = { "3", "7", "30", "100", "365" }
local FIRE_STATES = { out = "out", unlit = "none" }
-- The flame layers, brightened within their step.
local FLAME_LAYERS = { "-fl1", "-fl2", "-fl3" }
-- A day cell's sprite and icon by the day's status.
local DAY_CELLS = { lit = "day-lit", before = "day-pre", burned = "day", out = "day", unlit = "day", today = "day" }
local DAY_ICONS = { lit = "d-flame", burned = "d-burn", out = "d-out", unlit = "d-unlit" }

---@class TackleSpikedSlip: Frame
---@field paper TackleSprite
---@field kicker FontString
---@field label FontString
---@field note FontString
---@field view TackleSpikeGoal?
---@field hangX number      -- where it hangs on the spike (its top left) and its swing, in degrees
---@field hangY number
---@field swing number

---@class TackleSpikeFrame: Frame
---@field head FontString
---@field top Frame            -- the nail's frame, at its layer
---@field nail TackleSprite
---@field slips TackleSpikedSlip[]
---@field label FontString
---@field at { x: number, y: number }   -- where it hangs on the cork (adapter/Board.lua)
---@field held string?                 -- its label as it was, held while a goal done flies to it (adapter/BoardChanges.lua)

---@class TackleCampfireButton: Button
---@field glow TackleSprite
---@field burning TackleBoardFire   -- the fire in its layers (adapter/BoardMotion.lua)
---@field days FontString
---@field word FontString
---@field text FontString            -- "Gone out" or "Not lit yet"
---@field sticks TackleSprite[]
---@field longest FontString
---@field glowAt number[]            -- where its glow sits
---@field view TackleCampfireView?   -- what it shows now
---@field ghost TackleBoardFire?     -- the fire as it was, while it crosses to the fire as it is (adapter/BoardChanges.lua)
---@field ghostMotion Frame?
---@field held boolean?             -- its words held as they were while it goes out

---@class TackleFlyBoxButton: Button
---@field title FontString
---@field count FontString
---@field at number[]     -- its top left on the ledge
---@field tied integer?   -- the flies tied, as its count shows
---@field held string?    -- its count as it was, held until it hops

---@class TackleTallyPlate: Button
---@field counts FontString
---@field latest FontString
---@field held string?    -- its counts as they were, held until a goal done lands on the spike

---@class TackleShopLink: Button
---@field card TackleSprite
---@field label FontString
---@field pointer TackleSprite

---@class TackleRefreshCount: Frame
---@field label FontString   -- "3 Refreshes held"

---@class TackleCardDayCell: Frame
---@field cell TackleSprite
---@field icon TackleSprite
---@field ring Texture[]
---@field today FontString
---@field view TackleCardDay?

---@class TackleCardTitleRow: Frame
---@field mark TackleSprite
---@field label FontString
---@field name FontString
---@field more FontString
---@field coin TackleSprite
---@field coins FontString

---@class TackleCampfireCardFrame: Frame
---@field paper TackleSprite
---@field heading FontString
---@field fire FontString
---@field heads FontString[]
---@field weeks FontString[]
---@field days TackleCardDayCell[]
---@field rows { milestones: TackleCardTitleRow[], tally: TackleCardTitleRow[], flybox: TackleCardTitleRow[] }
---@field close Button

---@class TackleFlyCellView: Frame
---@field rare TackleSprite?
---@field fly TackleSprite
---@field label FontString
---@field edge Texture[]
---@field cell TackleFlyCell?
---@field flyAt number[]          -- where its fly sits
---@field glow TackleSprite?      -- its ring glowing as a fly is tied (adapter/BoardChanges.lua)

---@class TackleDrawerFrame: Frame
---@field title FontString
---@field count FontString
---@field cells TackleFlyCellView[]
---@field close Button

---@class TackleLedgeFrame: Frame
---@field fire TackleCampfireButton
---@field box TackleFlyBoxButton
---@field plate TackleTallyPlate
---@field shop TackleShopLink
---@field refresh TackleRefreshCount
---@field veil Frame?
---@field card TackleCampfireCardFrame?
---@field drawer TackleDrawerFrame?

--- The Campfire's stage for ns.SetBoardFire (adapter/BoardMotion.lua): its flame's step while it burns, else "out" or
--- "none". The ledge's fire and the Field guide's sample (adapter/GuidePage.lua) draw by it.
---@param view TackleCampfireView
---@return string
function ns.CampfireStage(view)
	return view.state == "lit" and FIRE_STEPS[view.step] or FIRE_STATES[view.state]
end

-- The celebrated set's titles (TKB-R64, TKB-R83): those already shown, which the card keeps shown as earned.
---@return { [string]: true }
local function celebratedTitles()
	local set = ns.Celebrated()
	return set and set.titles or {}
end

-- The spike (TKB-R103).

-- A done goal's slip on the spike: its paper, "NOTICE DONE", its text and its note by hand, all swung together about
-- the nail; its hover. Each slip is its own frame, above the one before, so the later covers the earlier.
---@param spike TackleSpikeFrame
---@param i integer
---@return TackleSpikedSlip
local function newSpikedSlip(spike, i)
	local slip = CreateFrame("Frame", nil, spike) --[[@as TackleSpikedSlip]]
	slip:SetSize(SLIP_WIDTH, SLIP_HEIGHT)
	slip:SetFrameLevel(spike:GetFrameLevel() + math.min(i, SLIP_LEVELS))
	slip:EnableMouse(true)
	slip.paper = ns.ArtSprite(slip, "Board", "done", "ARTWORK")
	slip.kicker = ns.ArtText(slip, "DoneKind")
	slip.kicker:SetWidth(SLIP_LAYOUTS[1].width)
	slip.label = ns.ArtWrap(slip, SLIP_FITS[1][2], SLIP_LAYOUTS[1].width, GOAL_SPACING)
	slip.note = ns.ArtText(slip, "DoneNote")
	slip.note:SetWidth(SLIP_LAYOUTS[1].width)
	slip:SetScript("OnEnter", function(self)
		if self.view then
			ns.BoardHover(self, self.view.hover, { fly = self.view.fly })
		end
	end)
	slip:SetScript("OnLeave", ns.BoardHoverHide)
	return slip
end

-- Lays out the lines of `slip`, its texts set (#471): where each line's top is on the paper and how far across it runs, so
-- that the goal text never runs over the kicker above it or the note below it, or past the paper, and is never cut.
-- It takes the first of SLIP_FITS whose goal text, wrapped to the layout's width and measured as the client sets it,
-- is no taller than the room between the kicker and the note; so any text fits as far as the smallest font can make it.
-- Only a text that fits in none (none the generator can write does, spec/Pagle_TackleBoard/adapter/Ledge_spec.lua) is
-- cut by lines with an ellipsis at the smallest, the hover having the whole of it.
---@param slip TackleSpikedSlip
---@return number[] tops   -- the kicker's, the goal text's and the note's
---@return number x        -- where the lines start, and how wide they are
---@return number width
local function layoutSlip(slip)
	local label = slip.label
	label:SetMaxLines(0)
	local tops, layout
	for _, fit in ipairs(SLIP_FITS) do
		layout = SLIP_LAYOUTS[fit[1]]
		slip.kicker:SetWidth(layout.width)
		slip.note:SetWidth(layout.width)
		label:SetWidth(layout.width)
		ns.SetArtFont(label, fit[2])
		local goalY = math.max(layout.goalY or 0, layout.kickerY + slip.kicker:GetStringHeight() + layout.gap)
		local noteY = math.min(layout.noteY or math.huge, layout.bottom - slip.note:GetStringHeight())
		tops = { layout.kickerY, goalY, noteY }
		if label:GetStringHeight() <= noteY - goalY then
			return tops, layout.x, layout.width
		end
	end
	for lines = GOAL_MOST_LINES, 1, -1 do
		if label:GetStringHeight() <= tops[3] - tops[2] then
			break
		end
		label:SetMaxLines(lines)
	end
	return tops, layout.x, layout.width
end

-- Hangs `slip` at `y` on the spike, swung by `swing` degrees about the nail's hole.
---@param spike TackleSpikeFrame
---@param slip TackleSpikedSlip
---@param y number
---@param swing number
local function hang(spike, slip, y, swing)
	local px, py = SLIP_X + HOLE_X, y + HOLE_Y
	slip.hangX, slip.hangY, slip.swing = SLIP_X, y, swing
	slip:ClearAllPoints()
	slip:SetPoint("TOPLEFT", spike, "TOPLEFT", SLIP_X, -y)
	local box = slip.paper.box
	local width, height = slip.paper:GetSize()
	local pivot = { px, py }
	ns.Swing(slip.paper, spike, { SLIP_X - box[1], y - box[2], width, height }, swing, pivot)
	local tops, x, lineWidth = layoutSlip(slip)
	for i, fontString in ipairs({ slip.kicker, slip.label, slip.note }) do
		local lineBox = { SLIP_X + x, y + tops[i], lineWidth, fontString:GetStringHeight() }
		ns.Swing(fontString, spike, lineBox, swing, pivot)
	end
end

-- The spike's heading, nail and label, made on its first draw.
---@param spike TackleSpikeFrame
local function buildSpike(spike)
	spike.slips = {}
	spike.head = ns.ArtText(spike, "SpikeHead")
	spike.head:SetJustifyH("CENTER")
	spike.head:SetPoint("TOP", 0, 0)
	spike.head:SetText((ns.Spaced(ns.L.SPIKE_HEAD):gsub("   ", "  ")))
	-- The nail on its own frame, above every slip and below every overlay (ns.BOARD_LAYERS).
	local board = ns.board.frame --[[@as TackleBoardFrame]]
	local top = CreateFrame("Frame", nil, spike)
	top:SetAllPoints()
	top:SetFrameLevel(board:GetFrameLevel() + ns.BoardLayer("nail"))
	spike.top = top
	spike.nail = ns.ArtSprite(top, "Board", "nail", "OVERLAY", 5)
	ns.PlaceSprite(spike.nail, top, 60, 32)
	spike.label = ns.ArtWrap(spike, "SpikeLabel", 162, 1)
	spike.label:SetJustifyH("CENTER")
end

-- The "spike" part (TKB-R103): today's done goals hung on the nail in completion order, the label under them.
---@param spike TackleSpikeFrame
local function drawSpike(spike)
	if not spike.slips then
		buildSpike(spike)
	end
	local view = ns.SpikeView(ns.State())
	local n = #view.goals
	local swings, step = ns.SpikeHang(n, STACK_ROOM)
	for i = 1, math.max(n, #spike.slips) do
		local slip = spike.slips[i] or newSpikedSlip(spike, i)
		spike.slips[i] = slip
		local goal = view.goals[i]
		slip:SetShown(goal ~= nil)
		slip.view = goal
		if goal then
			slip.kicker:SetText(goal.kicker:upper())
			slip.label:SetText(goal.text)
			slip.note:SetText(goal.note)
			hang(spike, slip, SLIP_Y + (i - 1) * step, swings[i])
		end
	end
	local below = n > 0 and SLIP_Y + SLIP_HEIGHT + (n - 1) * step + 20 or SLIP_Y + 22
	spike.label:ClearAllPoints()
	spike.label:SetPoint("TOP", spike, "TOP", 0, -below)
	spike.label:SetText(spike.held or view.label)
end

-- The veil over the cork while the card or the drawer is open: the cork darkened, and the clicks under it caught.
---@param ledge TackleLedgeFrame
---@return Frame
local function veil(ledge)
	if not ledge.veil then
		local board = ns.board.frame --[[@as TackleBoardFrame]]
		local frame = CreateFrame("Frame", nil, board.cork)
		frame:SetAllPoints()
		frame:SetFrameLevel(board:GetFrameLevel() + ns.BoardLayer("veil"))
		frame:EnableMouse(true)
		ns.BoardSolid(frame, "140902", VEIL_ALPHA, "BACKGROUND")
		frame:Hide()
		ledge.veil = frame
	end
	return ledge.veil --[[@as Frame]]
end

-- Shows the veil while the card or the drawer shows.
---@param ledge TackleLedgeFrame
local function updateVeil(ledge)
	local open = (ledge.card and ledge.card:IsShown()) or (ledge.drawer and ledge.drawer:IsShown())
	veil(ledge):SetShown(open == true)
end

-- An overlay's frame on the board, over the cork at `x`, `y` (y down), `width` × `height`, hidden, and the veil kept with
-- it.
---@param ledge TackleLedgeFrame
---@return Frame
local function overlay(ledge, x, y, width, height)
	local board = ns.board.frame --[[@as TackleBoardFrame]]
	local frame = CreateFrame("Frame", nil, board)
	frame:SetSize(width, height)
	frame:SetPoint("TOPLEFT", board.cork, "TOPLEFT", x, -y)
	frame:SetFrameLevel(board:GetFrameLevel() + ns.BoardLayer("overlay"))
	frame:EnableMouse(true)
	frame:SetScript("OnShow", function()
		updateVeil(ledge)
	end)
	frame:SetScript("OnHide", function()
		updateVeil(ledge)
	end)
	frame:Hide()
	return frame
end

-- The Campfire card (TKB-R106, TKB-R64).

-- A section's heading on the card: its words in small caps, a note at its right in italics, and a rule under both.
---@param card Frame
local function cardHeading(card, x, y, width, title, note)
	local head = ns.ArtText(card, "CardHead")
	head:SetPoint("TOPLEFT", x, -(y + 3))
	head:SetText(title:upper())
	local small = ns.ArtText(card, "CardNote")
	small:SetJustifyH("RIGHT")
	small:SetPoint("TOPRIGHT", card, "TOPLEFT", x + width, -(y + 2))
	small:SetText(note)
	local rule = ns.BoardSolid(card, "C4A874", 1, "ARTWORK")
	rule:ClearAllPoints()
	rule:SetSize(width, 1)
	rule:SetPoint("TOPLEFT", x, -(y + 20))
end

-- A day of the card's four-week log: its cell and its icon; today ringed in ink and named under it; its hover reads
-- its realm date and what it was.
---@param card TackleCampfireCardFrame
---@param x number
---@param y number
---@return TackleCardDayCell
local function newDayCell(card, x, y)
	local cell = CreateFrame("Frame", nil, card) --[[@as TackleCardDayCell]]
	cell:SetSize(DAY_SIZE, DAY_SIZE)
	cell:SetPoint("TOPLEFT", x, -y)
	cell:EnableMouse(true)
	cell.cell = ns.ArtSprite(cell, "Board", "day", "ARTWORK")
	ns.PlaceSprite(cell.cell, cell, 0, 0)
	cell.icon = ns.ArtSprite(cell, "Board", "d-flame", "ARTWORK", 1)
	ns.PlaceSprite(cell.icon, cell, 6, 6)
	cell.ring = {}
	local edges = {
		{ 0, 0, DAY_SIZE, 2 },
		{ 0, DAY_SIZE - 2, DAY_SIZE, 2 },
		{ 0, 0, 2, DAY_SIZE },
		{ DAY_SIZE - 2, 0, 2, DAY_SIZE },
	}
	for i, edge in ipairs(edges) do
		local line = ns.BoardSolid(cell, "23407A", 1, "ARTWORK", 2)
		line:ClearAllPoints()
		line:SetSize(edge[3], edge[4])
		line:SetPoint("TOPLEFT", edge[1], -edge[2])
		cell.ring[i] = line
	end
	cell.today = ns.ArtText(cell, "CardToday")
	cell.today:SetJustifyH("CENTER")
	cell.today:SetPoint("TOP", cell, "BOTTOM", 0, -1)
	cell.today:SetText(ns.L.CARD_DAYS.today)
	cell:SetScript("OnEnter", function(self)
		if self.view then
			ns.BoardHover(self, { self.view.date, self.view.text })
		end
	end)
	cell:SetScript("OnLeave", ns.BoardHoverHide)
	return cell
end

-- A title's row on the card: its mark (won or not), its threshold, its name in italics, what is still to go by hand,
-- and a milestone's Coins at the right.
---@param card TackleCampfireCardFrame
---@param x number
---@param y number
---@return TackleCardTitleRow
local function newTitleRow(card, x, y)
	local row = CreateFrame("Frame", nil, card) --[[@as TackleCardTitleRow]]
	row:SetSize(364, 28)
	row:SetPoint("TOPLEFT", x, -y)
	row.mark = ns.ArtSprite(row, "Board", "mile-no", "ARTWORK")
	ns.PlaceSprite(row.mark, row, 0, 3)
	row.label = ns.ArtText(row, "CardLabel")
	row.label:SetPoint("TOPLEFT", 30, -6)
	row.name = ns.ArtText(row, "CardEarned")
	row.name:SetPoint("TOPLEFT", 104, -4)
	row.more = ns.ArtText(row, "CardMore")
	row.more:SetPoint("LEFT", row.name, "RIGHT", 7, 0)
	row.coin = ns.ArtSprite(row, "Board", "coin", "ARTWORK")
	ns.PlaceSprite(row.coin, row, 364 - 17, 5)
	row.coins = ns.ArtText(row, "CardCoins")
	row.coins:SetJustifyH("RIGHT")
	row.coins:SetPoint("RIGHT", row.coin, "LEFT", 2, 0)
	for i = 0, 362, 3 do
		local dot = ns.BoardSolid(row, "8C6432", 0.4, "ARTWORK")
		dot:ClearAllPoints()
		dot:SetSize(1, 1)
		dot:SetPoint("TOPLEFT", i, -28)
	end
	return row
end

-- The card, over the cork, made on its first opening: its paper and tacks, its heading and the fire's line, the
-- four-week log with its weekdays, week dates and key, the milestones and the titles, and its close mark.
---@param ledge TackleLedgeFrame
---@return TackleCampfireCardFrame
local function buildCard(ledge)
	local L = ns.L
	local card = overlay(ledge, CARD_X, CARD_Y, CARD_WIDTH, CARD_HEIGHT) --[[@as TackleCampfireCardFrame]]
	card.paper = ns.ArtSprite(card, "Card", "card", "BACKGROUND")
	for _, x in ipairs({ 16, 769 }) do
		ns.PlaceSprite(ns.NewBoardTack(card), card, x, 8)
	end
	card.close = ns.NewBoardCloseMark(card, card, "CardClose")
	card.close:SetPoint("TOPLEFT", 740, -10)
	card.heading = ns.ArtText(card, "CardTitle")
	card.heading:SetPoint("TOPLEFT", 30, -26)
	card.heading:SetText(L.CARD_TITLE)
	card.fire = ns.ArtText(card, "CardFire")
	card.fire:SetPoint("TOPLEFT", 30, -61)

	cardHeading(card, 30, 96, 344, L.CARD_WEEKS, L.CARD_WEEKS_NOTE)
	card.heads, card.weeks, card.days = {}, {}, {}
	for column = 1, 7 do
		local head = ns.ArtText(card, "CardWeekday")
		head:SetJustifyH("CENTER")
		head:SetPoint("TOP", card, "TOPLEFT", DAY_X + (column - 1) * DAY_STEP + DAY_SIZE / 2, -123)
		card.heads[column] = head
	end
	for row = 0, 3 do
		local week = ns.ArtText(card, "CardWeek")
		week:SetPoint("TOPLEFT", 30, -(151 + row * DAY_STEP))
		card.weeks[row + 1] = week
		for column = 0, 6 do
			local x, y = DAY_X + column * DAY_STEP, DAY_Y + row * DAY_STEP
			card.days[#card.days + 1] = newDayCell(card, x, y)
		end
	end
	-- The key under the log.
	for _, key in ipairs({ { "d-flame", "lit", 30 }, { "d-burn", "burned", 77 }, { "d-out", "out", 202 } }) do
		local icon = ns.ArtSprite(card, "Board", key[1], "ARTWORK")
		ns.SizeSprite(icon, 18)
		ns.PlaceSprite(icon, card, key[3], 322)
		local words = ns.ArtText(card, "CardLegend")
		words:SetPoint("TOPLEFT", key[3] + 22, -324)
		words:SetText(L.CARD_DAYS[key[2]])
	end
	local unlit = ns.ArtSprite(card, "Board", "d-unlit", "ARTWORK")
	ns.SizeSprite(unlit, 18)
	ns.PlaceSprite(unlit, card, 285, 322)
	local unlitWords = ns.ArtText(card, "CardLegend")
	unlitWords:SetPoint("TOPLEFT", 307, -324)
	unlitWords:SetText(L.CARD_DAYS.unlit)
	local before = ns.ArtSprite(card, "Board", "day-pre", "ARTWORK")
	ns.SizeSprite(before, 16, 14)
	ns.PlaceSprite(before, card, 30, 344)
	local beforeWords = ns.ArtText(card, "CardLegend")
	beforeWords:SetPoint("TOPLEFT", 50, -345)
	beforeWords:SetText(L.CARD_DAYS.before)

	card.rows = { milestones = {}, tally = {}, flybox = {} }
	cardHeading(card, 406, 42, 364, L.CARD_MILESTONES, L.CARD_MILESTONES_NOTE)
	for i = 1, #ns.CAMPFIRE_MILESTONES do
		card.rows.milestones[i] = newTitleRow(card, 406, 68 + (i - 1) * 28)
	end
	cardHeading(card, 406, 196, 364, L.CARD_TITLES, L.CARD_TITLES_NOTE)
	for i = 1, 3 do
		card.rows.tally[i] = newTitleRow(card, 406, 222 + (i - 1) * 28)
	end
	card.rows.flybox[1] = newTitleRow(card, 406, 306)
	ledge.card = card
	return card
end

-- Draws a day of the log: its cell and icon by what it was, today ringed and named.
---@param cell TackleCardDayCell
---@param day TackleCardDay
---@param today boolean
local function drawDay(cell, day, today)
	cell.view = day
	ns.SetSprite(cell.cell, "Board", DAY_CELLS[day.status])
	ns.PlaceSprite(cell.cell, cell, 0, 0)
	local icon = DAY_ICONS[day.status]
	cell.icon:SetShown(icon ~= nil)
	if icon then
		ns.SetSprite(cell.icon, "Board", icon)
		ns.PlaceSprite(cell.icon, cell, 6, 6)
	end
	for _, line in ipairs(cell.ring) do
		line:SetShown(today)
	end
	cell.today:SetShown(today)
end

-- Draws a title's row: won or not, its threshold, its name, what is still to go, and a milestone's Coins.
---@param row TackleCardTitleRow
---@param title TackleCardTitle
---@param mark TackleCardMark
local function drawTitle(row, title, mark)
	ns.SetSprite(row.mark, "Board", title.earned and "mile-won" or "mile-no")
	ns.PlaceSprite(row.mark, row, 0, 3)
	row.label:SetText(mark.label)
	row.name:SetText(title.name)
	ns.SetArtFont(row.name, title.earned and "CardEarned" or "CardNotEarned")
	row.more:SetText(mark.more or "")
	row.more:SetShown(mark.more ~= nil)
	row.coin:SetShown(mark.paid ~= nil)
	row.coins:SetShown(mark.paid ~= nil)
	row.coins:SetText(mark.paid and tostring(mark.paid) or "")
end

-- Draws the card's contents (TKB-R106).
---@param card TackleCampfireCardFrame
local function drawCard(card)
	local state = ns.State()
	local fire = ns.CampfireView(state.fire)
	ns.LeanSprite(card.paper, card, 0, 0, CARD_LEAN)
	card.fire:SetText(ns.Fill(ns.L.CARD_FIRE, {
		fire = fire.text,
		longest = fire.longest,
		kindling = ns.Plural(fire.kindling, "KINDLING"),
	}))
	local view = ns.CampfireCard(state, celebratedTitles())
	for i, head in ipairs(card.heads) do
		head:SetText(view.heads[i]:upper())
	end
	for i, week in ipairs(card.weeks) do
		week:SetText(view.weeks[i])
	end
	for i, cell in ipairs(card.days) do
		drawDay(cell, view.days[i], view.days[i].day == state.day)
	end
	for section, rows in pairs(card.rows) do
		for i, row in ipairs(rows) do
			local title = view[section][i]
			drawTitle(row, title, view.marks[title.id])
		end
	end
end

-- The Fly Box drawer (TKB-R106).

-- A felt compartment of the drawer: a gilt edge for a rare pattern, the fly (faint and grey until tied), its name or
-- "not tied yet" under it, and a gilt outline under the mouse with its hover.
---@param drawer TackleDrawerFrame
---@param i integer
---@return TackleFlyCellView
local function newFlyCell(drawer, i)
	local column, row = (i - 1) % CELL_COLUMNS, math.floor((i - 1) / CELL_COLUMNS)
	local cell = CreateFrame("Frame", nil, drawer) --[[@as TackleFlyCellView]]
	cell:SetSize(CELL_WIDTH, CELL_HEIGHT)
	cell:SetPoint("TOPLEFT", CELL_X + column * (CELL_WIDTH + 4), -(CELL_Y + row * CELL_ROW))
	cell:EnableMouse(true)
	if ns.FLY_PATTERNS[i].rare then
		cell.rare = ns.ArtSprite(cell, "Board", "cell-rare", "BORDER")
		ns.SizeSprite(cell.rare, CELL_WIDTH, CELL_HEIGHT)
		ns.PlaceSprite(cell.rare, cell, 0, 0)
	end
	cell.fly = ns.ArtSprite(cell, "Flies", "fly-" .. ns.FLY_PATTERNS[i].id, "ARTWORK")
	cell.flyAt = { (CELL_WIDTH - 80) / 2, 4 }
	ns.PlaceSprite(cell.fly, cell, cell.flyAt[1], cell.flyAt[2])
	cell.label = ns.ArtText(cell, "FlyName")
	cell.label:SetJustifyH("CENTER")
	cell.label:SetWidth(CELL_WIDTH - 4)
	cell.label:SetPoint("TOP", 0, -51)
	cell.edge = {}
	for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = ns.BoardSolid(cell, "F0D27A", 1, "OVERLAY")
		line:ClearAllPoints()
		if edge == "TOP" or edge == "BOTTOM" then
			line:SetPoint(edge .. "LEFT")
			line:SetPoint(edge .. "RIGHT")
			line:SetHeight(2)
		else
			line:SetPoint("TOP" .. edge)
			line:SetPoint("BOTTOM" .. edge)
			line:SetWidth(2)
		end
		line:Hide()
		cell.edge[#cell.edge + 1] = line
	end
	local function outline(shown)
		for _, line in ipairs(cell.edge) do
			line:SetShown(shown)
		end
	end
	cell:SetScript("OnEnter", function(self)
		outline(true)
		if self.cell then
			ns.BoardHover(self, self.cell.hover)
		end
	end)
	cell:SetScript("OnLeave", function()
		outline(false)
		ns.BoardHoverHide()
	end)
	return cell
end

-- The drawer, over the cork, made on its first opening: its wooden box with its heading and count, its close mark and
-- 30 compartments (6 × 5).
---@param ledge TackleLedgeFrame
---@return TackleDrawerFrame
local function buildDrawer(ledge)
	local drawer = overlay(ledge, DRAWER_X, DRAWER_Y, DRAWER_WIDTH, DRAWER_HEIGHT) --[[@as TackleDrawerFrame]]
	ns.PlaceSprite(ns.ArtSprite(drawer, "Card", "drawer", "BACKGROUND"), drawer, 0, 0)
	drawer.title = ns.ArtText(drawer, "DrawerTitle")
	drawer.title:SetPoint("TOPLEFT", 22, -13)
	drawer.title:SetText(ns.Spaced(ns.L.FLY_BOX))
	drawer.count = ns.ArtText(drawer, "DrawerCount")
	drawer.count:SetPoint("BOTTOMLEFT", drawer.title, "BOTTOMRIGHT", 12, -2)
	drawer.close = ns.NewBoardCloseMark(drawer, drawer, "DrawerClose")
	drawer.close:SetPoint("TOPLEFT", 723, -8)
	drawer.close:HookScript("OnClick", function()
		ns.BoardSound("drawerClose")
	end)
	drawer.cells = {}
	for i = 1, #ns.FLY_PATTERNS do
		drawer.cells[i] = newFlyCell(drawer, i)
	end
	ledge.drawer = drawer
	return drawer
end

-- Draws the drawer's compartments, in pattern order (logic/Ledge.lua): a tied fly in full with its name, an untied one
-- faint and grey over "not tied yet", or "tied only by Expeditions" for a rare one.
---@param drawer TackleDrawerFrame
local function drawDrawer(drawer)
	local view = ns.FlyBoxView(ns.State().flies)
	drawer.count:SetText(view.label)
	for i, cell in ipairs(drawer.cells) do
		local felt = view.cells[i]
		cell.cell = felt
		cell.fly:SetAlpha(felt.tied and 1 or 0.22)
		cell.fly:SetDesaturated(not felt.tied)
		local untied = felt.rare and "FlyUntiedRare" or "FlyUntied"
		ns.SetArtFont(cell.label, felt.tied and (felt.rare and "FlyNameRare" or "FlyName") or untied)
		cell.label:SetText(felt.tied and felt.text or (felt.rare and ns.L.FLY_RARE or felt.text))
	end
end

-- The ledge (TKB-R106).

-- Opens `name` ("card" or "drawer"), made at its first opening, and closes the other, or closes `name` if it is open.
---@param ledge TackleLedgeFrame
---@param name "card"|"drawer"
local function toggle(ledge, name)
	-- The other of the two (not `and`/`or`: with no drawer made yet that would name the card itself, and hide it before
	-- the check below, so a second click on the Campfire would open it again, with its sound, instead of closing it).
	---@type Frame?
	local other = ledge.drawer
	if name == "drawer" then
		other = ledge.card
	end
	if other then
		other:Hide()
	end
	local shown = ledge[name]
	if shown and shown:IsShown() then
		shown:Hide()
		if name == "drawer" then
			ns.BoardSound("drawerClose")
		end
		return
	end
	if name == "card" then
		local card = ledge.card or buildCard(ledge)
		card:Show()
		ns.BoardSound("campfire")
		drawCard(card)
	else
		local drawer = ledge.drawer or buildDrawer(ledge)
		drawer:Show()
		drawDrawer(drawer)
		ns.BoardSound("drawerOpen")
	end
end

-- Closes the card and the drawer, if made.
---@param ledge TackleLedgeFrame
local function closeOverlays(ledge)
	if ledge.card then
		ledge.card:Hide()
	end
	if ledge.drawer then
		ledge.drawer:Hide()
	end
end

-- The Campfire on the ledge: its glow, the fire by its step, its days (or "Gone out", "Not lit yet"), three sticks of
-- Kindling and the longest; a click opens the card.
---@param ledge TackleLedgeFrame
local function buildFire(ledge)
	local fire = CreateFrame("Button", nil, ledge) --[[@as TackleCampfireButton]]
	fire:SetSize(FIRE_WIDTH, FIRE_HEIGHT)
	fire:SetPoint("TOPLEFT", FIRE_X, -FIRE_Y)
	fire.glow = ns.ArtSprite(fire, "Fire", "fire-glow", "BACKGROUND")
	fire.glowAt = { 20 - FIRE_X, 54 - FIRE_Y }
	ns.PlaceSprite(fire.glow, fire, fire.glowAt[1], fire.glowAt[2])
	fire.burning = ns.NewBoardFire(fire, 30 - FIRE_X, 14 - FIRE_Y)
	fire.days = ns.ArtText(fire, "FireDays")
	fire.days:SetPoint("TOPLEFT", 176 - FIRE_X, -(48 - FIRE_Y))
	fire.word = ns.ArtText(fire, "FireWord")
	fire.word:SetPoint("BOTTOMLEFT", fire.days, "BOTTOMRIGHT", 5, 2)
	fire.text = ns.ArtText(fire, "FireState")
	fire.text:SetPoint("TOPLEFT", 176 - FIRE_X, -(51 - FIRE_Y))
	fire.sticks = {}
	for i = 1, ns.KINDLING_CAP do
		local stick = ns.ArtSprite(fire, "Board", "kindling", "ARTWORK")
		ns.PlaceSprite(stick, fire, 176 - FIRE_X + (i - 1) * 44, 79 - FIRE_Y)
		fire.sticks[i] = stick
	end
	fire.longest = ns.ArtText(fire, "Longest")
	fire.longest:SetPoint("TOPLEFT", 176 - FIRE_X, -(98 - FIRE_Y))
	fire:SetScript("OnClick", function()
		toggle(ledge, "card")
	end)
	ledge.fire = fire
end

-- Draws the Campfire (TKB-R106): the fire's layers by its step (or embers, or bare logs), its flames brighter within
-- their step, its glow while it burns, its days, its Kindling and its longest. The board moves it (adapter/Board.lua).
---@param fire TackleCampfireButton
---@param view TackleCampfireView
---@param count integer the Campfire's days
local function drawFire(fire, view, count)
	local lit = view.state == "lit"
	fire.view = view
	local stage = ns.CampfireStage(view)
	if fire.burning.stage ~= stage then
		ns.SetBoardFire(fire.burning, stage)
	end
	local light = lit and math.min(1, 0.8 + 0.4 * view.bright) or 1
	for _, suffix in ipairs(FLAME_LAYERS) do
		local flame = fire.burning.layers[suffix]
		if flame then
			flame:SetVertexColor(light, light, light)
		end
	end
	fire.glow:SetShown(lit)
	fire.glow:SetAlpha(lit and 0.6 + 0.4 * view.bright or 0)
	if not fire.held then
		fire.days:SetShown(lit)
		fire.word:SetShown(lit)
		fire.text:SetShown(not lit)
	end
	if lit then
		fire.days:SetText(tostring(count))
		fire.word:SetText(ns.Plural(count, "DAYS_WORD"))
	end
	fire.text:SetText(view.text)
	for i, stick in ipairs(fire.sticks) do
		stick:SetAlpha(i <= view.kindling and 1 or 0.28)
	end
	fire.longest:SetText(view.longest)
end

-- The Fly Box on the ledge: the kit's box, its name in gilt and its count by hand; a click opens its drawer.
---@param ledge TackleLedgeFrame
local function buildBox(ledge)
	local box = CreateFrame("Button", nil, ledge) --[[@as TackleFlyBoxButton]]
	box:SetSize(214, 100)
	box.at = { 322, 30 }
	box:SetPoint("TOPLEFT", box.at[1], -box.at[2])
	ns.PlaceSprite(ns.ArtSprite(box, "Board", "flybox", "ARTWORK"), box, 0, 0)
	box.title = ns.ArtText(box, "BoxLabel")
	box.title:SetJustifyH("CENTER")
	box.title:SetPoint("TOP", box, "TOPLEFT", 107, -35)
	box.title:SetText(ns.Spaced(ns.L.FLY_BOX))
	box.count = ns.ArtText(box, "BoxCount")
	box.count:SetJustifyH("CENTER")
	box.count:SetPoint("TOP", box, "TOPLEFT", 107, -50)
	box:SetScript("OnClick", function()
		toggle(ledge, "drawer")
	end)
	ledge.box = box
end

-- The brass tally plate: the counts in gilt and the latest title in italics, or "no title yet"; a click opens the card,
-- where the titles are.
---@param ledge TackleLedgeFrame
local function buildPlate(ledge)
	local plate = CreateFrame("Button", nil, ledge) --[[@as TackleTallyPlate]]
	plate:SetSize(232, 70)
	plate:SetPoint("TOPLEFT", 576, -46)
	ns.PlaceSprite(ns.ArtSprite(plate, "Board", "tally", "ARTWORK"), plate, 0, 0)
	plate.counts = ns.ArtText(plate, "Tally")
	plate.counts:SetJustifyH("CENTER")
	plate.counts:SetPoint("TOP", plate, "TOPLEFT", 116, -20)
	plate.latest = ns.ArtText(plate, "TallyTitle")
	plate.latest:SetJustifyH("CENTER")
	plate.latest:SetPoint("TOP", plate, "TOPLEFT", 116, -43)
	plate:SetScript("OnClick", function()
		toggle(ledge, "card")
	end)
	ledge.plate = plate
end

-- The shop card: a card pinned to the ledge with its words and a pointing hand; a click calls Pagle.OpenShop(), which
-- prints Core's line instead while restricted (SHOP-R41, TKB-R193).
---@param ledge TackleLedgeFrame
local function buildShop(ledge)
	local shop = CreateFrame("Button", nil, ledge) --[[@as TackleShopLink]]
	shop:SetSize(128, 66)
	shop:SetPoint("TOPLEFT", 836, -48)
	shop.card = ns.ArtSprite(shop, "Board", "shopcard", "ARTWORK")
	shop.label = ns.ArtWrap(shop, "Shop", 112, 2)
	shop.label:SetJustifyH("CENTER")
	shop.label:SetPoint("TOP", 0, -9)
	shop.label:SetText(ns.L.SHOP_LINK)
	shop.pointer = ns.ArtSprite(shop, "Board", "hand", "ARTWORK", 2)
	ns.PlaceSprite(ns.NewBoardTack(shop), shop, 58, -6)
	shop:SetScript("OnClick", function()
		Pagle.OpenShop()
	end)
	ledge.shop = shop
end

-- The Refresh count (TKB-R58, TKB-R106): the Refreshes held, the Refresh ticket's icon before them (#466), in the ledge's light italics under the shop card, with a
-- hover saying what they are for. Core's count (REF-R5), redrawn when it changes (adapter/Pins.lua listens).
---@param ledge TackleLedgeFrame
local function buildRefresh(ledge)
	local refresh = CreateFrame("Frame", nil, ledge) --[[@as TackleRefreshCount]]
	refresh:SetSize(128, 24)
	refresh:SetPoint("TOPLEFT", 836, -120)
	refresh:EnableMouse(true)
	refresh.label = ns.ArtText(refresh, "Longest")
	refresh.label:SetJustifyH("CENTER")
	refresh.label:SetPoint("CENTER")
	refresh:SetScript("OnEnter", function(self)
		ns.BoardHover(self, { ns.L.REFRESH_TIP_TITLE, ns.L.REFRESH_TIP, ns.L.REFRESH_TIP_SOURCE }, { cursor = true })
	end)
	refresh:SetScript("OnLeave", ns.BoardHoverHide)
	ledge.refresh = refresh
end

-- The "ledge" part (TKB-R106): the Campfire, the Fly Box, the tally plate and the shop card with the Refresh count under
-- it, and the card or the drawer while one is open. The board's opening closes them.
---@param ledge TackleLedgeFrame
---@param draw TackleBoardDraw
local function drawLedge(ledge, draw)
	if not ledge.fire then
		buildFire(ledge)
		buildBox(ledge)
		buildPlate(ledge)
		buildShop(ledge)
		buildRefresh(ledge)
		-- The card and the drawer lie on the board, not the ledge: they close with it, as when a rebuild leaves the
		-- cork bare (TKB-R108).
		ledge:SetScript("OnHide", function()
			closeOverlays(ledge)
		end)
	end
	if draw.reason == "open" or draw.updating then
		closeOverlays(ledge)
	end
	local state = ns.State()
	drawFire(ledge.fire, ns.CampfireView(state.fire), state.fire.count)
	local flies = ns.FlyBoxView(state.flies)
	ledge.box.count:SetText(ledge.box.held or flies.label)
	ledge.box.tied = 0
	for _, cell in ipairs(flies.cells) do
		ledge.box.tied = ledge.box.tied + (cell.tied and 1 or 0)
	end
	local tally = ns.TallyView(state)
	local plate = ledge.plate
	plate.counts:SetText(plate.held or tally.counts)
	plate.latest:SetText(tally.latest or ns.L.TALLY_NO_TITLE)
	ns.SetArtFont(plate.latest, tally.latest and "TallyTitle" or "TallyNone")
	ns.LeanSprite(ledge.shop.card, ledge.shop, 0, 0, 2.5)
	ns.LeanSprite(ledge.shop.pointer, ledge.shop, 77, 27, 2.5)
	ledge.refresh.label:SetText(ns.TicketMarkup(REFRESH_ICON) .. " " .. ns.Plural(ns.RefreshesHeld(), "REFRESHES_HELD"))
	if ledge.card and ledge.card:IsShown() then
		drawCard(ledge.card)
	end
	if ledge.drawer and ledge.drawer:IsShown() then
		drawDrawer(ledge.drawer)
	end
end

ns.board:RegisterPart("spike", function(frame)
	drawSpike(frame --[[@as TackleSpikeFrame]])
end)
ns.board:RegisterPart("ledge", function(frame, draw)
	drawLedge(frame --[[@as TackleLedgeFrame]], draw)
end)
