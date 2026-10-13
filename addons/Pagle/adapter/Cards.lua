---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The cards on the client (announcements.md › Session summary, › Write-up, › UI): logic/Cards.lua over
-- PagleDB.global, the projection machinery's idle hook and the lanes' empty state, drawing each card centre-screen
-- in the Timber style (ANN-R80), closed with its button or Esc. The look follows prototypes/catch-feedback/
-- (variant A)'s session summary.
local L = ns.L

-- The card frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleCard"
-- Timber's card colours (ANN-R80): the toast's planks and brass, gold headings, a darker well for the numbers.
local TIMBER = {
	wood = { 0.11, 0.09, 0.07, 0.96 },
	edge = { 0.54, 0.48, 0.37, 1 },
	band = { 0.18, 0.15, 0.12, 1 },
	well = { 0, 0, 0, 0.42 },
	gold = { 1, 0.82, 0 },
	dim = { 0.66, 0.62, 0.55 },
}
local WIDTH = 520
-- The numbers grid (ANN-R53): Casts, Catches, got away, time fished.
local NUMBERS = { "casts", "catches", "gotAway", "seconds" }
local NUMBER_LABELS = { L.CARD_CASTS, L.CARD_CATCHES, L.CARD_GOT_AWAY, L.CARD_TIME }
local ROW_HEIGHT = 22
-- Rows shown before the list scrolls with the mouse wheel.
local ROWS_SHOWN = 14
-- Trade_Fishing, for a moment with no icon.
local DEFAULT_ICON = 136245

---@class PagleCardRowView: Frame
---@field kind "heading"|"line"|"moment"
---@field icon Texture
---@field text FontString
---@field detail FontString

---@class PagleCardNumber
---@field value FontString
---@field label FontString

---@class PagleCardFrame: Frame
---@field card PagleCard? the card on screen
---@field title FontString
---@field numbers PagleCardNumber[]
---@field numbersBox Frame
---@field scroll ScrollFrame
---@field content Frame
---@field rows PagleCardRowView[]
---@field close Button

--- The card frame, made the first time a card shows.
---@type PagleCardFrame?
ns.cardFrame = nil

-- A solid texture on `frame`, filling it.
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@return Texture
local function solid(frame, color, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetColorTexture(color[1], color[2], color[3], color[4])
	texture:SetAllPoints()
	return texture
end

---@param frame Frame
---@param template string
---@param color number[]?
---@return FontString
local function text(frame, template, color)
	local fontString = frame:CreateFontString(nil, "OVERLAY", template)
	if color then
		fontString:SetTextColor(color[1], color[2], color[3])
	end
	return fontString
end

-- A moment's icon as a texture (announcements.md › Contracts), as the Announcement frames show it.
---@param icon integer|string|nil
---@return integer|string
local function textureOf(icon)
	if type(icon) == "number" then
		local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
		return fileID or icon
	end
	return icon or DEFAULT_ICON
end

-- The player closed the card on screen, with the button or Esc: logic/Cards.lua removes it and shows the next.
---@param frame PagleCardFrame
local function closed(frame)
	local card = frame.card
	if card then
		frame.card = nil
		frame:Hide()
		ns.cards:Close(card)
	end
end

-- Row `i` of the list, made on first use: an icon, the text and, on the right, a moment's own text.
---@param frame PagleCardFrame
---@param i integer
---@return PagleCardRowView
local function rowAt(frame, i)
	local row = frame.rows[i]
	if not row then
		row = CreateFrame("Frame", nil, frame.content) --[[@as PagleCardRowView]]
		row:SetSize(WIDTH - 40, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18)
		row.icon:SetPoint("LEFT")
		row.text = text(row, "GameFontHighlight")
		row.detail = text(row, "GameFontHighlightSmall", TIMBER.dim)
		row.detail:SetPoint("RIGHT")
		row.detail:SetJustifyH("RIGHT")
		frame.rows[i] = row
	end
	return row
end

-- Fills row `row` from a card row: a heading in gold, a line, or a moment with its icon and its own text.
---@param row PagleCardRowView
---@param data PagleCardRow
local function fillRow(row, data)
	row.kind = data.kind
	row.text:ClearAllPoints()
	row.text:SetText(data.text)
	row.detail:SetText(data.detail or "")
	if data.kind == "heading" then
		row.text:SetFontObject("GameFontNormal")
		row.text:SetPoint("BOTTOMLEFT", 0, 3)
		row.icon:Hide()
	elseif data.kind == "moment" then
		row.text:SetFontObject("GameFontHighlight")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.icon:SetTexture(textureOf(data.icon))
		row.icon:Show()
	else
		row.text:SetFontObject("GameFontHighlight")
		row.text:SetPoint("LEFT", 4, 0)
		row.icon:Hide()
	end
	row:Show()
end

-- The card frame: a title band, the numbers grid, the rows in a list that scrolls with the mouse wheel, and the
-- close button. Esc hides it through UISpecialFrames.
---@return PagleCardFrame
local function build()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as PagleCardFrame]]
	frame:SetPoint("CENTER")
	frame:SetWidth(WIDTH)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	solid(frame, TIMBER.wood)
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
		local line = frame:CreateTexture(nil, "BORDER")
		line:SetColorTexture(TIMBER.edge[1], TIMBER.edge[2], TIMBER.edge[3], TIMBER.edge[4])
		line:SetPoint(side[1])
		line:SetPoint(side[2])
		line:SetHeight(2)
	end
	local band = CreateFrame("Frame", nil, frame)
	band:SetPoint("TOPLEFT", 2, -2)
	band:SetPoint("TOPRIGHT", -2, -2)
	band:SetHeight(28)
	solid(band, TIMBER.band, "ARTWORK")
	frame.title = text(band, "GameFontNormalLarge", TIMBER.gold)
	frame.title:SetPoint("CENTER")

	frame.numbersBox = CreateFrame("Frame", nil, frame)
	frame.numbersBox:SetPoint("TOPLEFT", 16, -40)
	frame.numbersBox:SetPoint("TOPRIGHT", -16, -40)
	frame.numbersBox:SetHeight(44)
	frame.numbers = {}
	local cellWidth = (WIDTH - 32 - 3 * 6) / 4
	for i in ipairs(NUMBERS) do
		local cell = CreateFrame("Frame", nil, frame.numbersBox)
		cell:SetSize(cellWidth, 44)
		cell:SetPoint("TOPLEFT", (i - 1) * (cellWidth + 6), 0)
		solid(cell, TIMBER.well, "ARTWORK")
		local value = text(cell, "GameFontHighlightLarge")
		value:SetPoint("TOP", 0, -6)
		local label = text(cell, "GameFontHighlightSmall", TIMBER.dim)
		label:SetPoint("BOTTOM", 0, 6)
		label:SetText(NUMBER_LABELS[i])
		frame.numbers[i] = { value = value, label = label }
	end

	frame.scroll = CreateFrame("ScrollFrame", nil, frame)
	frame.scroll:SetPoint("BOTTOMLEFT", 20, 48)
	frame.scroll:SetPoint("BOTTOMRIGHT", -20, 48)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetWidth(WIDTH - 40)
	frame.scroll:SetScrollChild(frame.content)
	frame.scroll:EnableMouseWheel(true)
	frame.scroll:SetScript("OnMouseWheel", function(self, delta)
		local scroll = self:GetVerticalScroll() - delta * ROW_HEIGHT * 3
		self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
	end)
	frame.rows = {}

	frame.close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
	frame.close:SetSize(100, 22)
	frame.close:SetPoint("BOTTOM", 0, 14)
	frame.close:SetText(L.CARD_CLOSE)
	frame.close:SetScript("OnClick", function()
		closed(frame)
	end)
	-- Esc hides it (CloseSpecialWindows). Hiding UIParent (Alt-Z, a cinematic) also runs OnHide but leaves it shown:
	-- that isn't the player closing it.
	frame:SetScript("OnHide", function(self)
		if not self:IsShown() then
			closed(self)
		end
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
	return frame
end

-- logic/Cards.lua's show: the card drawn in the frame, made on first use, and on screen (announcements.md › UI).
---@param card PagleCard
local function show(card)
	local frame = ns.cardFrame
	if not frame then
		frame = build()
		ns.cardFrame = frame
	end
	frame.card = card
	frame.title:SetText(card.title)
	local numbers = card.numbers
	frame.numbersBox:SetShown(numbers ~= nil)
	if numbers then
		for i, key in ipairs(NUMBERS) do
			local value = key == "seconds" and ns.CardDuration(numbers.seconds) or BreakUpLargeNumbers(numbers[key])
			frame.numbers[i].value:SetText(value)
		end
	end
	local rows = ns.CardRows(card, BreakUpLargeNumbers)
	for i, data in ipairs(rows) do
		fillRow(rowAt(frame, i), data)
	end
	for i = #rows + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	frame.content:SetHeight(math.max(1, #rows) * ROW_HEIGHT)
	frame.scroll:SetVerticalScroll(0)
	local listHeight = math.min(#rows, ROWS_SHOWN) * ROW_HEIGHT
	frame.scroll:SetHeight(math.max(1, listHeight))
	frame:SetHeight(40 + (numbers and 54 or 0) + listHeight + 56)
	frame:Show()
	-- A Session summary showing ends the compartment's waiting count (ANN-R42).
	if numbers then
		ns.summary:SummaryShown()
	end
end

-- logic/Cards.lua's hide, for the combat hold (ANN-R35): off screen without closing it, so it shows again after.
---@param card PagleCard
local function hide(card)
	local frame = ns.cardFrame
	if frame and frame.card == card then
		frame.card = nil
		frame:Hide()
	end
end

--- Core's cards (ANN-R21, ANN-R54, ANN-R61): they wait for the projections' idle hook from load, then show whenever
--- the toast and big lanes are empty and not held through combat (ANN-R55).
---@type PagleCards
ns.cards = ns.NewCards({
	global = function()
		return ns.db.global
	end,
	mode = function()
		return ns.projections:Mode()
	end,
	whenIdle = function(fn)
		ns.projections:WhenIdle(fn)
	end,
	nextFrame = function(step)
		C_Timer.After(0, step)
	end,
	lanesEmpty = function()
		return ns.lanes:IsEmpty()
	end,
	held = function()
		return ns.lanes:IsHeld()
	end,
	cozy = function()
		return ns.db.profile.announcements.cozy
	end,
	show = show,
	hide = hide,
})
ns.cards:Start()

---@class PagleModuleHandle
local ModuleHandle = ns.ModuleHandle

--- Raises a Write-up section from a projection's done (ANN-R60): see ns.RaiseWriteUpMethod. Raises an error outside
--- a done, or for a section without a heading or with lines that aren't strings.
ModuleHandle.RaiseWriteUp = ns.RaiseWriteUpMethod(ns.Modules, ns.cards)
