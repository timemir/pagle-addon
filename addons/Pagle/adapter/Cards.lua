---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The cards on the client (announcements.md › Session summary, › Write-up, › UI): logic/Cards.lua over
-- PagleDB.global, the projection machinery's idle hook and the lanes' empty state, drawing each card centre-screen,
-- closed with its button, its corner's close mark or Esc. The look is the announcements art kit's session card
-- (adapter/Art.lua), the same in every toast style: a page torn from the ledger under a leather head with the gilt
-- title, Core's numbers in the Angler's hand, then the rows on the page's ruled lines.
local L = ns.L

-- The card frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleCard"
local textureOf = ns.TextureOf
-- The card's width, its leather head's and torn foot's heights, and its ruled lines' spacing, as the art draws them.
local WIDTH, HEAD, FOOT, LINE = 580, 62, 40, 30
-- The page's left margin, where the rows start; the body art repeats every 120 units.
local MARGIN, BODY_TILE = 62, 120
-- The numbers grid (ANN-R53): Casts, Catches, got away, time fished.
local NUMBERS = { "casts", "catches", "gotAway", "seconds" }
local NUMBER_LABELS = { L.CARD_CASTS, L.CARD_CATCHES, L.CARD_GOT_AWAY, L.CARD_TIME }
local NUMBERS_HEIGHT = 90
-- The close button's bottom, above the card's.
local CLOSE_BOTTOM = 20
-- Ruled lines shown before the list scrolls with the mouse wheel.
local ROWS_SHOWN = 12
-- A row's width, the page's past its margin; a moment's title's indent past its icon, and the least gap between the
-- title and its own text beside it.
local ROW_WIDTH, INDENT, GAP = WIDTH - MARGIN - 30, 28, 16
-- The size of the hand a moment's own text is in (adapter/Art.lua's CardDetail).
local DETAIL_SIZE = 20

---@class PagleCardRowView: Frame
---@field kind "heading"|"line"|"moment"|"link"
---@field icon Texture
---@field text FontString
---@field detail FontString
---@field link Button? over a link row's words, made at the first: its Module in `module`
---@field module string?

---@class PagleCardNumber
---@field value FontString
---@field label FontString

---@class PagleCardFrame: Frame
---@field card PagleCard? the card on screen
---@field title FontString
---@field numbers PagleCardNumber[]
---@field numbersBox Frame
---@field body Frame the ruled page, its art tiled down it
---@field tiles PagleSprite[]
---@field foot Frame
---@field scroll ScrollFrame
---@field content Frame
---@field rows PagleCardRowView[]
---@field close Button

--- The card frame, made the first time a card shows.
---@type PagleCardFrame?
ns.cardFrame = nil

-- The player closed the card on screen, with a button or Esc: logic/Cards.lua removes it and shows the next.
---@param frame PagleCardFrame
local function closed(frame)
	local card = frame.card
	if card then
		frame.card = nil
		frame:Hide()
		ns.cards:Close(card)
	end
end

--- Closes `card` as the player would, if it is the card on screen: a `/pagle dev tour` stop's hide (CORE-R68).
---@param card PagleCard
function ns.CloseCardOnScreen(card)
	local frame = ns.cardFrame
	if frame and frame.card == card then
		closed(frame)
	end
end

-- Row `i` of the list, made on first use: an icon, the text and a moment's own text in the Angler's hand. show places
-- it, on as many ruled lines as fillRow says it takes.
---@param frame PagleCardFrame
---@param i integer
---@return PagleCardRowView
local function rowAt(frame, i)
	local row = frame.rows[i]
	if not row then
		row = CreateFrame("Frame", nil, frame.content) --[[@as PagleCardRowView]]
		row:SetSize(ROW_WIDTH, LINE)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(20, 20)
		-- On the row's first line, 5 above its rule.
		row.icon:SetPoint("TOPLEFT", 0, 25 - LINE)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- the icon's own border off
		row.text = ns.ArtText(row, "CardLine")
		row.detail = ns.ArtText(row, "CardDetail")
		frame.rows[i] = row
	end
	return row
end

-- Places a moment's own text, already in row.detail, on its row (#314): at the right of the title's line when the two
-- fit there side by side; else on the lines under the title, from its left, wrapped to the row and LINE apart, so each
-- line sits on a rule as the title's does. Returns the lines it takes under the title.
---@param row PagleCardRowView
---@return integer
local function placeDetail(row)
	local detail = row.detail
	detail:ClearAllPoints()
	detail:SetWidth(0) -- measured unbounded
	detail:SetWordWrap(false)
	detail:SetSpacing(0)
	local width = detail:GetStringWidth()
	if width == 0 or INDENT + row.text:GetStringWidth() + GAP + width <= ROW_WIDTH then
		detail:SetJustifyH("RIGHT")
		detail:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 4 - LINE)
		return 0
	end
	detail:SetJustifyH("LEFT")
	detail:SetWordWrap(true)
	detail:SetWidth(ROW_WIDTH - INDENT)
	detail:SetSpacing(LINE - DETAIL_SIZE)
	-- Its last line on the row's last rule, the lines above it LINE apart: n lines are n LINEs less the spacing tall.
	detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", INDENT, 4)
	return math.max(1, math.ceil(detail:GetStringHeight() / LINE))
end

-- The ink of a Write-up section's Show me around » (ANN-R64), and its ink under the mouse.
local LINK_INK, LINK_HOVER = { 0x7a / 255, 0x2a / 255, 0x14 / 255 }, { 0xb4 / 255, 0x28 / 255, 0x1a / 255 }

-- A link row's button over its words, made on first use: it closes the card, as the player would, then opens the
-- Field guide at the row's Module's first step (ANN-R64, ONB-R82).
---@param frame PagleCardFrame
---@param row PagleCardRowView
---@return Button
local function linkOf(frame, row)
	local link = row.link
	if not link then
		link = CreateFrame("Button", nil, row)
		link:SetPoint("BOTTOMLEFT", row.text, "BOTTOMLEFT", 0, -2)
		link:SetPoint("TOPRIGHT", row.text, "TOPRIGHT", 0, 2)
		link:SetScript("OnEnter", function()
			row.text:SetTextColor(LINK_HOVER[1], LINK_HOVER[2], LINK_HOVER[3])
		end)
		link:SetScript("OnLeave", function()
			row.text:SetTextColor(LINK_INK[1], LINK_INK[2], LINK_INK[3])
		end)
		link:SetScript("OnClick", function()
			local module = row.module
			closed(frame)
			if module then
				ns.guide:OpenModule(module)
			end
		end)
		row.link = link
	end
	return link
end

-- Fills row `row` from a card row: a heading printed in red, a line, a moment with its icon and its own text, or a
-- Write-up section's Show me around » link. Each sits on its line, a moment's own text maybe on more under it: returns
-- the ruled lines the row takes.
---@param frame PagleCardFrame
---@param row PagleCardRowView
---@param data PagleCardRow
---@return integer
local function fillRow(frame, row, data)
	local lines = 1
	row.kind = data.kind
	row.module = data.module
	row.text:ClearAllPoints()
	row.text:SetText(data.text)
	row.detail:SetText(data.detail or "")
	if row.link then
		row.link:SetShown(data.kind == "link")
	end
	if data.kind == "link" then
		ns.SetArtFont(row.text, "CardLine")
		row.text:SetTextColor(LINK_INK[1], LINK_INK[2], LINK_INK[3])
		row.text:SetPoint("BOTTOMLEFT", 0, 7)
		row.icon:Hide()
		linkOf(frame, row):Show()
	elseif data.kind == "heading" then
		ns.SetArtFont(row.text, "CardGroup")
		row.text:SetPoint("BOTTOMLEFT", 0, 4)
		row.icon:Hide()
	elseif data.kind == "moment" then
		ns.SetArtFont(row.text, "CardLine")
		row.text:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
		row.icon:SetTexture(textureOf(data.icon))
		row.icon:Show()
		lines = lines + placeDetail(row)
	else
		ns.SetArtFont(row.text, "CardLine")
		row.text:SetPoint("BOTTOMLEFT", 0, 7)
		row.icon:Hide()
	end
	row:SetHeight(lines * LINE)
	row:Show()
	return lines
end

-- The gilt close button on `parent`: the art's three-sliced button with its words, brighter under the mouse.
---@param parent Frame
---@param onClick fun()
---@return Button
local function giltButton(parent, onClick)
	local button = CreateFrame("Button", nil, parent) --[[@as Button]]
	local face = CreateFrame("Frame", nil, button)
	face:SetPoint("TOPLEFT")
	-- On the face's own frame, which draws over the button's.
	local label = ns.ArtText(face, "Button")
	label:SetText(L.CARD_CLOSE)
	label:SetPoint("CENTER", button, "CENTER")
	local width = label:GetStringWidth() + 68
	ns.SetThreeSlice(face, "Announce", "button", width, 12, "ARTWORK")
	button:SetSize(width, 44)
	button:SetScript("OnEnter", function()
		label:SetTextColor(1, 0.96, 0.78)
	end)
	button:SetScript("OnLeave", function()
		ns.Ink(label, "gilt")
	end)
	button:SetScript("OnClick", onClick)
	return button
end

-- The card frame: the leather head with the title and a close mark, the ruled body with the numbers grid and the
-- rows in a list that scrolls with the mouse wheel, the gilt close button, and the torn foot. Esc hides it through
-- UISpecialFrames.
---@return PagleCardFrame
local function build()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as PagleCardFrame]]
	frame:SetPoint("CENTER")
	frame:SetWidth(WIDTH)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	local function close()
		closed(frame)
	end
	local head = CreateFrame("Frame", nil, frame)
	head:SetSize(WIDTH, HEAD)
	head:SetPoint("TOPLEFT")
	ns.PlaceSprite(ns.ArtSprite(head, "Announce", "card-head", "BACKGROUND", 1), head, 0, 0)
	frame.title = ns.ArtText(head, "CardTitle")
	frame.title:SetPoint("LEFT", head, "LEFT", 26, 0)
	local corner = CreateFrame("Button", nil, head)
	corner:SetSize(44, 44)
	corner:SetPoint("RIGHT", head, "RIGHT", -10, 0)
	ns.PlaceSprite(ns.ArtSprite(corner, "Announce", "close", "ARTWORK"), corner, 0, 0)
	corner:SetScript("OnClick", close)

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetWidth(WIDTH)
	frame.body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
	frame.body:SetClipsChildren(true)
	frame.tiles = {}
	frame.foot = CreateFrame("Frame", nil, frame)
	frame.foot:SetSize(WIDTH, FOOT)
	frame.foot:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT")
	ns.PlaceSprite(ns.ArtSprite(frame.foot, "Announce", "card-foot", "BACKGROUND"), frame.foot, 0, 0)

	frame.numbersBox = CreateFrame("Frame", nil, frame.body)
	frame.numbersBox:SetPoint("TOPLEFT", 0, -14)
	frame.numbersBox:SetSize(WIDTH, NUMBERS_HEIGHT)
	frame.numbers = {}
	local column = (WIDTH - MARGIN - 10) / #NUMBERS
	for i in ipairs(NUMBERS) do
		local value = ns.ArtText(frame.numbersBox, "CardNum")
		value:SetPoint("CENTER", frame.numbersBox, "TOPLEFT", MARGIN - 20 + column * (i - 0.5), -38)
		local label = ns.ArtText(frame.numbersBox, "CardNumLabel")
		label:SetPoint("TOP", value, "BOTTOM", 0, -2)
		label:SetText(ns.Capitals(NUMBER_LABELS[i]))
		if i > 1 then
			-- A red rule between the numbers, as the margin line is ruled.
			local rule = frame.numbersBox:CreateTexture(nil, "ARTWORK")
			rule:SetColorTexture(0.706, 0.157, 0.102, 0.45)
			rule:SetSize(1, 70)
			rule:SetPoint("CENTER", frame.numbersBox, "TOPLEFT", MARGIN - 20 + column * (i - 1), -45)
		end
		frame.numbers[i] = { value = value, label = label }
	end

	frame.scroll = CreateFrame("ScrollFrame", nil, frame.body)
	frame.scroll:SetWidth(WIDTH - MARGIN - 30)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetWidth(WIDTH - MARGIN - 30)
	frame.scroll:SetScrollChild(frame.content)
	frame.scroll:EnableMouseWheel(true)
	-- By whole lines, so the rows stay on the page's rules.
	frame.scroll:SetScript("OnMouseWheel", function(self, delta)
		local scroll = self:GetVerticalScroll() - delta * LINE * 3
		self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
	end)
	frame.rows = {}
	-- At the page's foot, whatever the rows: on the card itself, as the body clips what runs past it.
	frame.close = giltButton(frame, close)
	frame.close:SetPoint("BOTTOM", frame, "BOTTOM", 0, CLOSE_BOTTOM)
	frame.close:SetFrameLevel(frame.foot:GetFrameLevel() + 2)

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

-- Sizes the body to `height` and tiles the ruled page down it.
---@param frame PagleCardFrame
---@param height number
local function layBody(frame, height)
	frame.body:SetHeight(height)
	local tiles = math.ceil(height / BODY_TILE)
	for i = 1, tiles do
		local tile = frame.tiles[i]
		if not tile then
			tile = ns.ArtSprite(frame.body, "Announce", "card-body", "BACKGROUND")
			ns.PlaceSprite(tile, frame.body, 0, (i - 1) * BODY_TILE)
			frame.tiles[i] = tile
		end
		-- The last tile cut to the body's foot, so it doesn't run over the torn edge.
		local shown = math.min(BODY_TILE, height - (i - 1) * BODY_TILE)
		local atlas = ns.ATLASES.Announce
		local sprite = atlas.sprites["card-body"]
		tile:SetTexCoord(
			sprite.x / atlas.width,
			(sprite.x + sprite.w) / atlas.width,
			sprite.y / atlas.height,
			(sprite.y + sprite.h * shown / BODY_TILE) / atlas.height
		)
		tile:SetHeight(shown)
		tile:Show()
	end
	for i = tiles + 1, #frame.tiles do
		frame.tiles[i]:Hide()
	end
end

-- logic/Cards.lua's show: the card drawn in the frame, made on first use, and on screen (announcements.md › UI). The
-- body is a whole number of ruled lines, so the torn foot meets them in step.
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
	-- ANN-R64: a section from a Module with a Field guide step ends with Show me around »
	local rows = ns.CardRows(card, BreakUpLargeNumbers, function(module)
		return ns.guideSteps ~= nil and ns.guideSteps:FirstOf(module) ~= nil
	end)
	-- Each row on the ruled line under the last row's last.
	local lines = 0
	for i, data in ipairs(rows) do
		local row = rowAt(frame, i)
		row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -lines * LINE)
		lines = lines + fillRow(frame, row, data)
	end
	for i = #rows + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	frame.content:SetHeight(math.max(1, lines) * LINE)
	frame.scroll:SetVerticalScroll(0)
	local listTop = 14 + (numbers and NUMBERS_HEIGHT or 0)
	local listHeight = math.min(lines, ROWS_SHOWN) * LINE
	frame.scroll:ClearAllPoints()
	frame.scroll:SetPoint("TOPLEFT", frame.body, "TOPLEFT", MARGIN, -listTop)
	frame.scroll:SetHeight(math.max(1, listHeight))
	-- The page, a whole number of lines, holds the rows, a gap, then the close button at its foot.
	local page = math.ceil((listTop + listHeight + 14 + 44 + CLOSE_BOTTOM) / LINE) * LINE
	local body = page - FOOT
	layBody(frame, body)
	frame:SetHeight(HEAD + body + FOOT)
	frame:Show()
	-- ONB-R52: the first Session summary's Margin note, adapter/MarginNotes.lua's, looked up when called.
	if ns.NoteCard then
		securecallfunction(ns.NoteCard, card, frame)
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

--- Core's cards, as ns.cards, with M:RaiseWriteUp on every Module handle (logic/Wiring.lua; ANN-R21, ANN-R54,
--- ANN-R61): they wait for the projections' idle hook from load, then show in the card frame whenever no toast, banner
--- or splash shows or waits and the lanes aren't held for any reason (ANN-R38, ANN-R55).
ns.WireCards(ns.host, {
	show = show,
	hide = hide,
	lanesEmpty = function()
		return ns.lanes:IsEmpty()
	end,
	held = function()
		return ns.lanes:IsHeld()
	end,
})
