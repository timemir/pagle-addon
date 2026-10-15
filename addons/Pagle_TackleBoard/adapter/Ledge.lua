if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The spike and the ledge on the client (TKB-R64, TKB-R103, TKB-R106, TKB-R193; SHOP-R41; ADR 0009): the "spike" and
-- "ledge" parts of adapter/Board.lua, drawing what logic/Ledge.lua decides in adapter/BoardWidgets.lua's art. The
-- spike hangs today's done goals on a nail down the right of the cork. The ledge holds, left to right, the Campfire
-- (clicking it opens the Campfire card), the Fly Box (clicking it opens its drawer), the brass tally plate (it opens
-- the card too) and the shop link, which calls Pagle.OpenShop() and so prints Core's line while restricted. The card
-- and the drawer lie over the cork, one at a time; each closes with its button, and both are closed when the board
-- opens. The board never shows the Coins balance (ADR 0009). Every symbol is a texture, never a glyph (CORE-R9).

-- The spike (variant C's `.spike`): the nail 26 high, done slips 104 × 64 stacked down it, each 24 below the last, or
-- closer to keep the stack inside 400 pixels; the label under the stack.
local NAIL, SPIKED_WIDTH, SPIKED_HEIGHT, SPIKED_STEP, STACK = 26, 104, 64, 24, 400
-- The ledge's pieces (variant C's `.ledge .fire`, `.box`, `.brass`, `.shop`): the Campfire's box 76 square, the Fly
-- Box 200 × 62, the plate 24 in from the right and the link under it.
local FLAME, BOX_WIDTH, BOX_HEIGHT, POINTER = 76, 200, 62, 16
-- The Campfire card (variant C's `.card2`) and the Fly Box drawer (`.drawer`, `.felt`): their sizes, the card's day
-- cells (7 across, 4 weeks) and the drawer's compartments (6 × 5).
local CARD_WIDTH, CARD_HEIGHT, DAY_WIDTH, DAY_HEIGHT, DAY_GAP = 520, 480, 40, 24, 4
local TITLE_ROW, TITLE_INDENT = 18, 40
local DRAWER_WIDTH, DRAWER_HEIGHT, CELL_WIDTH, CELL_HEIGHT, CELL_GAP = 630, 470, 94, 70, 6
-- How far over the cork the card and the drawer lie: above the parts and the "Updating..." cover (adapter/Board.lua).
local OVERLAY_LEVEL = 40

---@class TackleSpikedSlip: TackleSlipView
---@field label FontString
---@field view TackleSpikeGoal?

---@class TackleSpikeFrame: Frame
---@field nail Texture
---@field head TackleTackView
---@field slips TackleSpikedSlip[]
---@field label FontString

---@class TackleCampfireButton: Button
---@field flame TackleFlameView
---@field text FontString
---@field sticks TackleSticksView
---@field longest FontString

---@class TackleFlyBoxButton: Button
---@field title FontString
---@field count FontString

---@class TackleTallyPlate: Button
---@field face Texture
---@field counts FontString
---@field latest FontString

---@class TackleShopLink: Button
---@field label FontString
---@field pointer Texture

---@class TackleCardDayCell: Frame
---@field edges Texture[]
---@field glow Texture
---@field shade Texture
---@field number FontString
---@field view TackleCardDay?

---@class TackleCardTitleRow: Frame
---@field tick Texture
---@field name FontString
---@field need FontString

---@class TackleCampfireCardFrame: TackleSlipView
---@field heading FontString
---@field fire FontString
---@field heads FontString[]
---@field days TackleCardDayCell[]
---@field rows { milestones: TackleCardTitleRow[], tally: TackleCardTitleRow[], flybox: TackleCardTitleRow[] }
---@field close Button

---@class TackleDrawerFrame: Frame
---@field title FontString
---@field cells TackleFeltCellView[]
---@field note FontString
---@field close Button

---@class TackleLedgeFrame: Frame
---@field fire TackleCampfireButton
---@field box TackleFlyBoxButton
---@field plate TackleTallyPlate
---@field shop TackleShopLink
---@field card TackleCampfireCardFrame
---@field drawer TackleDrawerFrame

-- The celebrated set's titles (TKB-R64, TKB-R83): those already shown, which the card keeps shown as earned.
---@return { [string]: true }
local function celebratedTitles()
	local set = ns.Celebrated()
	return set and set.titles or {}
end

-- The spike (TKB-R103).

-- A done goal's slip on the spike: paper pierced by the nail, its text, its hover.
---@param spike TackleSpikeFrame
---@param i integer
---@return TackleSpikedSlip
local function newSpikedSlip(spike, i)
	local look = ns.BOARD_LOOK
	local slip = ns.NewBoardSlip(spike, SPIKED_WIDTH, SPIKED_HEIGHT) --[[@as TackleSpikedSlip]]
	slip.paper:SetColorTexture(look.spiked[1], look.spiked[2], look.spiked[3], 1)
	slip:SetFrameLevel(spike:GetFrameLevel() + 2 * i)
	slip.label = ns.BoardText(slip, ns.BoardFonts().small, look.ink)
	slip.label:SetWordWrap(true)
	slip.label:SetWidth(SPIKED_WIDTH - 12)
	slip.label:SetPoint("TOPLEFT", 6, -18)
	slip:SetScript("OnEnter", function(self)
		if self.view then
			ns.BoardHover(self, self.view.hover)
		end
	end)
	slip:SetScript("OnLeave", ns.BoardHoverHide)
	return slip
end

-- The spike's nail and its label, made on its first draw.
---@param spike TackleSpikeFrame
local function buildSpike(spike)
	local look = ns.BOARD_LOOK
	spike.slips = {}
	spike.nail = ns.BoardSolid(spike, look.nail, "ARTWORK")
	spike.nail:ClearAllPoints()
	spike.nail:SetSize(4, NAIL)
	spike.nail:SetPoint("TOP", 0, 0)
	spike.head = ns.NewBoardTack(spike, 10)
	spike.head:SetPoint("TOP", 0, 4)
	spike.label = ns.NewBoardHand(spike, look.title)
	spike.label:SetJustifyH("CENTER")
	spike.label:SetWordWrap(true)
	spike.label:SetWidth(spike:GetWidth() - 6)
end

-- The "spike" part (TKB-R103): today's done goals stacked down the nail in completion order, the label under them.
---@param spike TackleSpikeFrame
local function drawSpike(spike)
	if not spike.slips then
		buildSpike(spike)
	end
	local view = ns.SpikeView(ns.State())
	local n = #view.goals
	local step = n > 1 and math.min(SPIKED_STEP, math.floor((STACK - SPIKED_HEIGHT) / (n - 1))) or 0
	for i = 1, math.max(n, #spike.slips) do
		local slip = spike.slips[i] or newSpikedSlip(spike, i)
		spike.slips[i] = slip
		local goal = view.goals[i]
		slip:SetShown(goal ~= nil)
		slip.view = goal
		if goal then
			slip:ClearAllPoints()
			slip:SetPoint("TOP", 0, -(NAIL - 6 + (i - 1) * step))
			slip.label:SetText(goal.text)
		end
	end
	local stack = n > 0 and SPIKED_HEIGHT + (n - 1) * step - 6 or 0
	spike.label:ClearAllPoints()
	spike.label:SetPoint("TOP", 0, -(NAIL + stack + 8))
	spike.label:SetText(view.label)
end

-- The Campfire card (TKB-R106, TKB-R64).

-- A day of the card's four-week log: its box, its day of the month, a glow when lit, a shade when Kindling burned;
-- its hover reads its realm date and what it was.
---@param card TackleCampfireCardFrame
---@return TackleCardDayCell
local function newDayCell(card)
	local look = ns.BOARD_LOOK
	local cell = CreateFrame("Frame", nil, card) --[[@as TackleCardDayCell]]
	cell:SetSize(DAY_WIDTH, DAY_HEIGHT)
	cell:EnableMouse(true)
	cell.shade = ns.BoardSolid(cell, look.burned, "BACKGROUND", 0.3, 2)
	cell.glow = cell:CreateTexture(nil, "BORDER")
	cell.glow:SetTexture(ns.BOARD_TEXTURES.disc)
	cell.glow:SetVertexColor(look.lit[1], look.lit[2], look.lit[3])
	cell.glow:SetSize(DAY_HEIGHT - 2, DAY_HEIGHT - 2)
	cell.glow:SetPoint("CENTER")
	cell.edges = ns.BoardOutline(cell, look.cardLine, 1, "BORDER")
	cell.number = ns.BoardText(cell, ns.BoardFonts().small, look.kicker)
	cell.number:SetJustifyH("CENTER")
	cell.number:SetPoint("CENTER")
	cell:SetScript("OnEnter", function(self)
		if self.view then
			ns.BoardHover(self, { self.view.date, self.view.text })
		end
	end)
	cell:SetScript("OnLeave", ns.BoardHoverHide)
	return cell
end

-- A title's row on the card: a tick once earned, its name, and what it needs at the right.
---@param card TackleCampfireCardFrame
---@return TackleCardTitleRow
local function newTitleRow(card)
	local look, fonts = ns.BOARD_LOOK, ns.BoardFonts()
	local row = CreateFrame("Frame", nil, card) --[[@as TackleCardTitleRow]]
	row:SetSize(CARD_WIDTH - 2 * TITLE_INDENT, TITLE_ROW)
	row.tick = row:CreateTexture(nil, "ARTWORK")
	row.tick:SetTexture(ns.BOARD_TEXTURES.tick)
	row.tick:SetSize(16, 16)
	row.tick:SetPoint("LEFT", 0, 0)
	row.name = ns.BoardText(row, fonts.text, look.ink)
	row.name:SetPoint("LEFT", 20, 0)
	row.need = ns.BoardText(row, fonts.small, look.where)
	row.need:SetJustifyH("RIGHT")
	row.need:SetPoint("RIGHT", 0, 0)
	return row
end

-- The card's frame, over the cork, made on its first opening: its heading, the fire's line, the weekdays, the 28 day
-- cells, the title sections and its close button.
---@param ledge TackleLedgeFrame
---@return TackleCampfireCardFrame
local function buildCard(ledge)
	local board = ns.board.frame --[[@as TackleBoardFrame]]
	local look, fonts = ns.BOARD_LOOK, ns.BoardFonts()
	local card = ns.NewBoardSlip(board, CARD_WIDTH, CARD_HEIGHT) --[[@as TackleCampfireCardFrame]]
	card:SetPoint("CENTER", board.cork, "CENTER", 0, 0)
	card:SetFrameLevel(board.cork:GetFrameLevel() + OVERLAY_LEVEL)
	card.heading = ns.NewBoardPrinted(card, true)
	card.heading:SetJustifyH("CENTER")
	card.heading:SetPoint("TOP", 0, -22)
	card.heading:SetText(ns.L.CARD_TITLE)
	card.fire = ns.NewBoardHand(card)
	card.fire:SetPoint("TOP", 0, -46)
	local left = (CARD_WIDTH - 7 * DAY_WIDTH - 6 * DAY_GAP) / 2
	card.heads, card.days = {}, {}
	for column = 1, 7 do
		local head = ns.BoardText(card, fonts.kicker, look.kicker)
		head:SetJustifyH("CENTER")
		head:SetWidth(DAY_WIDTH)
		head:SetPoint("TOPLEFT", left + (column - 1) * (DAY_WIDTH + DAY_GAP), -78)
		card.heads[column] = head
	end
	for i = 1, ns.KEPT_DAYS do
		local cell = newDayCell(card)
		local column, week = (i - 1) % 7, math.floor((i - 1) / 7)
		cell:SetPoint("TOPLEFT", left + column * (DAY_WIDTH + DAY_GAP), -94 - week * (DAY_HEIGHT + DAY_GAP))
		card.days[i] = cell
	end
	card.rows = { milestones = {}, tally = {}, flybox = {} }
	local y = -94 - 4 * (DAY_HEIGHT + DAY_GAP) - 10
	for _, section in ipairs({
		{ "milestones", ns.L.CARD_MILESTONES, #ns.CAMPFIRE_MILESTONES },
		{ "tally", ns.L.CARD_TALLY, 3 },
		{ "flybox", ns.L.CARD_FLY_BOX, 1 },
	}) do
		local kicker = ns.NewBoardKicker(card)
		kicker:SetPoint("TOPLEFT", TITLE_INDENT, y)
		kicker:SetKicker(section[2])
		y = y - 16
		for i = 1, section[3] do
			local row = newTitleRow(card)
			row:SetPoint("TOPLEFT", TITLE_INDENT, y)
			card.rows[section[1]][i] = row
			y = y - TITLE_ROW
		end
		y = y - 6
	end
	card.close = CreateFrame("Button", nil, card, "UIPanelCloseButton") --[[@as Button]]
	card.close:SetPoint("TOPRIGHT", 4, 4)
	card.close:SetScript("OnClick", function()
		card:Hide()
	end)
	card:Hide()
	ledge.card = card
	return card
end

-- Draws a day of the log: lit days glow, a day that burned Kindling is shaded, the day it went out is red, the days
-- before the board are faint, and today is ringed in ink.
---@param cell TackleCardDayCell
---@param day TackleCardDay
local function drawDay(cell, day)
	local look = ns.BOARD_LOOK
	cell.view = day
	cell.number:SetText(tostring(day.number))
	cell.glow:SetShown(day.status == "lit")
	cell.shade:SetShown(day.status == "burned")
	local ink = day.status == "out" and look.red or look.kicker
	cell.number:SetTextColor(ink[1], ink[2], ink[3])
	local edge = (day.status == "today" or day.day == ns.State().day) and look.hand or look.cardLine
	for _, texture in ipairs(cell.edges) do
		texture:SetColorTexture(edge[1], edge[2], edge[3], 1)
	end
	cell:SetAlpha(day.status == "before" and 0.4 or 1)
end

-- Draws a title's row: earned, ticked and in ink; not yet, greyed with what it needs.
---@param row TackleCardTitleRow
---@param title TackleCardTitle
local function drawTitle(row, title)
	local look = ns.BOARD_LOOK
	row.name:SetText(title.name)
	row.need:SetText(
		title.coins and ns.Fill(ns.L.CARD_NEED_COINS, { need = title.need, coins = title.coins }) or title.need
	)
	row.tick:SetShown(title.earned)
	local ink = title.earned and look.ink or look.cardMuted
	row.name:SetTextColor(ink[1], ink[2], ink[3])
	row:SetAlpha(title.earned and 1 or 0.6)
end

-- Draws the card's contents (TKB-R106).
---@param card TackleCampfireCardFrame
local function drawCard(card)
	local state = ns.State()
	local fire = ns.CampfireView(state.fire)
	card.fire:SetText(ns.Fill(ns.L.CARD_FIRE, { fire = fire.text, longest = fire.longest }))
	local view = ns.CampfireCard(state, celebratedTitles())
	for i, head in ipairs(card.heads) do
		head:SetText(view.heads[i])
	end
	for i, cell in ipairs(card.days) do
		drawDay(cell, view.days[i])
	end
	for section, rows in pairs(card.rows) do
		for i, row in ipairs(rows) do
			drawTitle(row, view[section][i])
		end
	end
end

-- The Fly Box drawer (TKB-R106).

-- The drawer's frame, over the cork, made on its first opening: a wooden box, its heading, 30 felt compartments
-- (6 × 5), its note and its close button.
---@param ledge TackleLedgeFrame
---@return TackleDrawerFrame
local function buildDrawer(ledge)
	local board = ns.board.frame --[[@as TackleBoardFrame]]
	local look, fonts = ns.BOARD_LOOK, ns.BoardFonts()
	local drawer = CreateFrame("Frame", nil, board) --[[@as TackleDrawerFrame]]
	drawer:SetSize(DRAWER_WIDTH, DRAWER_HEIGHT)
	drawer:SetPoint("CENTER", board.cork, "CENTER", 0, 0)
	drawer:SetFrameLevel(board.cork:GetFrameLevel() + OVERLAY_LEVEL)
	drawer:EnableMouse(true)
	ns.NewBoardWood(drawer, DRAWER_WIDTH, DRAWER_HEIGHT)
	drawer.title = ns.BoardText(drawer, fonts.title, look.sealText)
	drawer.title:SetJustifyH("CENTER")
	drawer.title:SetPoint("TOP", 0, -16)
	drawer.cells = {}
	for i = 1, #ns.FLY_PATTERNS do
		local cell = ns.NewBoardFeltCell(drawer, CELL_WIDTH, CELL_HEIGHT)
		cell:SetScript("OnEnter", function(self)
			if self.cell then
				ns.BoardHover(self, self.cell.hover)
			end
		end)
		cell:SetScript("OnLeave", ns.BoardHoverHide)
		drawer.cells[i] = cell
	end
	drawer.note = ns.NewBoardHand(drawer, look.boxSmall)
	drawer.note:SetJustifyH("CENTER")
	drawer.note:SetPoint("BOTTOM", 0, 12)
	drawer.note:SetText(ns.L.DRAWER_NOTE)
	drawer.close = CreateFrame("Button", nil, drawer, "UIPanelCloseButton") --[[@as Button]]
	drawer.close:SetPoint("TOPRIGHT", 4, 4)
	drawer.close:SetScript("OnClick", function()
		drawer:Hide()
	end)
	drawer:Hide()
	ledge.drawer = drawer
	return drawer
end

-- Draws the drawer's compartments, each in its row and column (logic/Ledge.lua fills them in pattern order).
---@param drawer TackleDrawerFrame
local function drawDrawer(drawer)
	local view = ns.FlyBoxView(ns.State().flies)
	drawer.title:SetText(ns.Fill(ns.L.DRAWER_TITLE, { label = view.label }))
	local left = (DRAWER_WIDTH - 6 * CELL_WIDTH - 5 * CELL_GAP) / 2
	for i, cell in ipairs(drawer.cells) do
		local felt = view.cells[i]
		cell:ClearAllPoints()
		cell:SetPoint(
			"TOPLEFT",
			left + (felt.column - 1) * (CELL_WIDTH + CELL_GAP),
			-48 - (felt.row - 1) * (CELL_HEIGHT + CELL_GAP)
		)
		cell:SetCell(felt)
	end
end

-- The ledge (TKB-R106).

-- Opens `overlay` ("card" or "drawer") and closes the other, or closes `overlay` if it is open.
---@param ledge TackleLedgeFrame
---@param overlay "card"|"drawer"
local function toggle(ledge, overlay)
	local other = overlay == "card" and ledge.drawer or ledge.card
	local shown = ledge[overlay]
	other:Hide()
	if shown:IsShown() then
		shown:Hide()
		return
	end
	shown:Show()
	if overlay == "card" then
		drawCard(ledge.card)
	else
		drawDrawer(ledge.drawer)
	end
end

-- The Campfire on the ledge: the flame, its words, the Kindling as sticks and the longest; a click opens the card.
---@param ledge TackleLedgeFrame
local function buildFire(ledge)
	local look, fonts = ns.BOARD_LOOK, ns.BoardFonts()
	local fire = CreateFrame("Button", nil, ledge) --[[@as TackleCampfireButton]]
	fire:SetSize(260, 80)
	fire:SetPoint("BOTTOMLEFT", 24, 4)
	fire.flame = ns.NewBoardFlame(fire, FLAME)
	fire.flame:SetPoint("BOTTOMLEFT", 0, 0)
	fire.text = ns.BoardText(fire, fonts.updating, look.fireText)
	fire.text:SetPoint("BOTTOMLEFT", fire.flame, "BOTTOMRIGHT", 8, 30)
	fire.sticks = ns.NewBoardSticks(fire, ns.KINDLING_CAP)
	fire.sticks:SetPoint("BOTTOMLEFT", fire.flame, "BOTTOMRIGHT", 8, 12)
	fire.longest = ns.BoardText(fire, fonts.hand, look.fireSmall)
	fire.longest:SetPoint("LEFT", fire.sticks, "RIGHT", 6, 0)
	fire:SetScript("OnClick", function()
		toggle(ledge, "card")
	end)
	ledge.fire = fire
end

-- The Fly Box on the ledge: a wooden box with its count; a click opens its drawer.
---@param ledge TackleLedgeFrame
local function buildBox(ledge)
	local look, fonts = ns.BOARD_LOOK, ns.BoardFonts()
	local box = CreateFrame("Button", nil, ledge) --[[@as TackleFlyBoxButton]]
	box:SetSize(BOX_WIDTH, BOX_HEIGHT)
	box:SetPoint("BOTTOM", 0, 10)
	ns.NewBoardFace(box, look.woodInner, look.button, 2)
	box.title = ns.BoardText(box, fonts.button, look.sealText)
	box.title:SetPoint("TOP", 0, -10)
	box.title:SetText(ns.L.FLY_BOX)
	box.count = ns.BoardText(box, fonts.hand, look.boxSmall)
	box.count:SetPoint("BOTTOM", 0, 8)
	box:SetScript("OnClick", function()
		toggle(ledge, "drawer")
	end)
	ledge.box = box
end

-- The brass tally plate: the counts and the latest title; a click opens the card, where the titles are.
---@param ledge TackleLedgeFrame
local function buildPlate(ledge)
	local look, fonts = ns.BOARD_LOOK, ns.BoardFonts()
	local plate = CreateFrame("Button", nil, ledge) --[[@as TackleTallyPlate]]
	plate:SetPoint("BOTTOMRIGHT", -24, 24)
	plate.face = ns.NewBoardFace(plate, look.brassEdge, look.brass, 1)
	plate.counts = ns.BoardText(plate, fonts.small, look.brassText)
	plate.counts:SetJustifyH("CENTER")
	plate.counts:SetPoint("TOP", 0, -5)
	plate.latest = ns.BoardText(plate, fonts.small, look.brassText)
	plate.latest:SetJustifyH("CENTER")
	plate.latest:SetPoint("TOP", plate.counts, "BOTTOM", 0, -2)
	plate:SetScript("OnClick", function()
		toggle(ledge, "card")
	end)
	ledge.plate = plate
end

-- The shop link: its words and a pointing hand; a click calls Pagle.OpenShop(), which prints Core's line instead while
-- restricted (SHOP-R41, TKB-R193).
---@param ledge TackleLedgeFrame
local function buildShop(ledge)
	local look = ns.BOARD_LOOK
	local shop = CreateFrame("Button", nil, ledge) --[[@as TackleShopLink]]
	shop.label = ns.BoardText(shop, ns.BoardFonts().small, look.boxSmall)
	shop.label:SetPoint("LEFT", 0, 0)
	shop.label:SetText(ns.L.SHOP_LINK)
	shop.pointer = ns.NewBoardPointer(shop, POINTER)
	shop.pointer:SetPoint("LEFT", shop.label, "RIGHT", 4, 0)
	shop:SetSize(shop.label:GetStringWidth() + 4 + POINTER, POINTER)
	shop:SetPoint("BOTTOMRIGHT", -28, 4)
	shop:SetScript("OnClick", function()
		Pagle.OpenShop()
	end)
	ledge.shop = shop
end

-- The "ledge" part (TKB-R106): the Campfire, the Fly Box, the tally plate and the shop link, and the card or the
-- drawer while one is open. The board's opening closes them.
---@param ledge TackleLedgeFrame
---@param draw TackleBoardDraw
local function drawLedge(ledge, draw)
	if not ledge.fire then
		buildFire(ledge)
		buildBox(ledge)
		buildPlate(ledge)
		buildShop(ledge)
		buildCard(ledge)
		buildDrawer(ledge)
	end
	if draw.reason == "open" then
		ledge.card:Hide()
		ledge.drawer:Hide()
	end
	local state = ns.State()
	local fire = ns.CampfireView(state.fire)
	ledge.fire.flame:SetFire(fire)
	ledge.fire.text:SetText(fire.text)
	ledge.fire.sticks:SetSticks(fire.kindling)
	ledge.fire.longest:SetText(fire.longest)
	ledge.box.count:SetText(ns.FlyBoxView(state.flies).label)
	local tally = ns.TallyView(state)
	local plate = ledge.plate
	plate.counts:SetText(tally.counts)
	plate.latest:SetText(tally.latest or "")
	plate.latest:SetShown(tally.latest ~= nil)
	local width = math.max(plate.counts:GetStringWidth(), tally.latest and plate.latest:GetStringWidth() or 0)
	plate:SetSize(width + 24, tally.latest and 34 or 20)
	if ledge.card:IsShown() then
		drawCard(ledge.card)
	end
	if ledge.drawer:IsShown() then
		drawDrawer(ledge.drawer)
	end
end

ns.board:RegisterPart("spike", function(frame)
	drawSpike(frame --[[@as TackleSpikeFrame]])
end)
ns.board:RegisterPart("ledge", function(frame, draw)
	drawLedge(frame --[[@as TackleLedgeFrame]], draw)
end)
