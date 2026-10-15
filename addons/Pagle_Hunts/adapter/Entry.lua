if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- A Hunt's entry on the board's right page (HNT-R3, HNT-R64–R67, HNT-R69, HNT-R80): the renderer of the Board, entry
-- and retired modes (logic/Board.lua). What each line says is logic/Entry.lua's; this file reads the client, Core and
-- the seams for it and draws it top to bottom in the board's art (adapter/BoardWidgets.lua), as variant E lays it out:
-- the seal and the pin toggle at the top right, beside the heading.

local LOOK = ns.BOARD_LOOK

-- The seal's size, the pin toggle's, and the room the heading leaves them at its right (variant E's .entry padding).
local SEAL_SIZE, PIN_SIZE, HEADING_ROOM = 72, 22, 110
-- Gaps between blocks, a chip's height, padding and gap, a ladder step's height, its diamond, and the ink bar.
local GAP, CHIP_HEIGHT, CHIP_PAD, CHIP_GAP = 8, 18, 6, 4
local STEP_HEIGHT, DIAMOND_SIZE, THRESHOLD_WIDTH = 18, 14, 90
local BAR_WIDTH, BAR_HEIGHT = 160, 10
-- The pointing hand before "back to {set}".
local HAND_SIZE = 16

-- Variant E's chip tints (`.vE .chip`): the face rgba(255,250,235,.35), the edge rgba(106,74,32,.45), "you're here"
-- #2a6a2a, the unconfirmed chip's #6a3a8a.
local CHIP_FACE, CHIP_FACE_ALPHA = { 1, 250 / 255, 235 / 255 }, 0.35
local CHIP_EDGE, CHIP_EDGE_ALPHA = { 106 / 255, 74 / 255, 32 / 255 }, 0.45
local HERE = { 42 / 255, 106 / 255, 42 / 255 }
local UNCONFIRMED = { 106 / 255, 58 / 255, 138 / 255 }

-- Shows `lines` in the game tooltip over `owner`, one per line.
---@param owner Frame
---@param lines string[]
local function showTooltip(owner, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	GameTooltip:SetText(lines[1])
	for i = 2, #lines do
		GameTooltip:AddLine(lines[i])
	end
	GameTooltip:Show()
end

-- Gives `frame` a tooltip of `frame.tooltip`'s lines, when it has some.
---@param frame Frame
local function withTooltip(frame)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(self)
		if self.tooltip then
			showTooltip(self, self.tooltip)
		end
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Sets a font string's colour from a tint.
---@param text FontString
---@param color number[]
local function tint(text, color)
	text:SetTextColor(color[1], color[2], color[3])
end

--- A chip (HNT-R65): its words on a faint face in a thin edge, and the "you're here" badge after them.
---@class EntryChipView: Frame
---@field edges Texture[]
---@field label FontString
---@field badge FontString
---@field tooltip string[]?

---@param parent Frame
---@return EntryChipView
local function newChip(parent)
	local chip = CreateFrame("Frame", nil, parent) --[[@as EntryChipView]]
	chip:SetHeight(CHIP_HEIGHT)
	ns.BoardSolid(chip, CHIP_FACE, "BACKGROUND", CHIP_FACE_ALPHA)
	chip.edges = {}
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" },
		{ "TOPRIGHT", "BOTTOMRIGHT" },
	}) do
		local edge = chip:CreateTexture(nil, "BORDER")
		edge:SetPoint(points[1])
		edge:SetPoint(points[2])
		if i <= 2 then
			edge:SetHeight(1)
		else
			edge:SetWidth(1)
		end
		chip.edges[i] = edge
	end
	chip.label = ns.BoardText(chip, ns.BoardFonts().small, LOOK.small)
	chip.label:SetPoint("LEFT", CHIP_PAD, 0)
	chip.badge = ns.BoardText(chip, ns.BoardFonts().small, HERE)
	chip.badge:SetPoint("LEFT", chip.label, "RIGHT", CHIP_PAD, 0)
	withTooltip(chip)
	return chip
end

-- Dresses `chip` as `data` says, and sizes it to its words; returns its width.
---@param chip EntryChipView
---@param data HuntEntryChip
---@return number
local function setChip(chip, data)
	chip.label:SetText(data.text)
	local color = data.short and LOOK.red or data.kind == "unconfirmed" and UNCONFIRMED or LOOK.small
	tint(chip.label, color)
	local edge = (data.short and LOOK.red) or (data.kind == "unconfirmed" and UNCONFIRMED) or CHIP_EDGE
	for _, line in ipairs(chip.edges) do
		line:SetColorTexture(edge[1], edge[2], edge[3], CHIP_EDGE_ALPHA)
	end
	chip.badge:SetText(data.badge or "")
	chip.badge:SetShown(data.badge ~= nil)
	chip.tooltip = data.tooltip
	local width = chip.label:GetStringWidth() + 2 * CHIP_PAD
	if data.badge then
		width = width + chip.badge:GetStringWidth() + CHIP_PAD
	end
	chip:SetWidth(width)
	return width
end

--- The pin toggle (HNT-R80): a pin's head and needle, faint until pinned; a click pins or unpins the Hunt shown.
---@class EntryPinView: Button
---@field head Texture
---@field needle Texture
---@field pinned boolean
---@field huntID string?
---@field tooltip string[]

---@param parent Frame
---@return EntryPinView
local function newPin(parent)
	local pin = CreateFrame("Button", nil, parent) --[[@as EntryPinView]]
	pin:SetSize(PIN_SIZE, PIN_SIZE)
	pin.head = pin:CreateTexture(nil, "ARTWORK", nil, 1)
	pin.head:SetTexture(ns.BOARD_TEXTURES.disc)
	pin.head:SetVertexColor(LOOK.red[1], LOOK.red[2], LOOK.red[3])
	pin.head:SetSize(12, 12)
	pin.head:SetPoint("TOP", 0, -1)
	pin.needle = pin:CreateTexture(nil, "ARTWORK")
	pin.needle:SetColorTexture(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3], 1)
	pin.needle:SetSize(2, 10)
	pin.needle:SetPoint("TOP", pin.head, "BOTTOM", 0, 2)
	pin.pinned = false
	pin:SetScript("OnClick", function(self)
		if self.huntID then
			ns.SetPinned(self.huntID, not self.pinned)
		end
	end)
	withTooltip(pin)
	return pin
end

--- "back to {set}" with the pointing hand before it (HNT-R66): a click opens the set's page.
---@class EntryBackView: Button
---@field label FontString
---@field set string?

--- A right page that holds its entry's widgets.
---@class EntryPage: Frame
---@field entry EntryView?

--- The entry's widgets on its page, made at its first draw and kept, the variable ones in pools.
---@class EntryView
---@field page Frame
---@field back EntryBackView
---@field hand Texture
---@field kicker FontString
---@field name FontString
---@field target FontString
---@field retired FontString
---@field seal BoardSealView
---@field pin EntryPinView
---@field window FontString
---@field conditions FontString
---@field chips EntryChipView[]
---@field diamonds BoardDiamondView[]
---@field thresholds FontString[]
---@field whens FontString[]
---@field bar BoardInkBarView
---@field ladderUpdating FontString
---@field effort FontString
---@field odds FontString
---@field setLine FontString
---@field empty FontString

---@param page Frame
---@return EntryView
local function newView(page)
	local fonts = ns.BoardFonts()
	local function text(font, color)
		return ns.BoardText(page, font, color)
	end
	local view = { page = page, chips = {}, diamonds = {}, thresholds = {}, whens = {} }
	view.back = CreateFrame("Button", nil, page) --[[@as EntryBackView]]
	view.back:SetSize(200, HAND_SIZE + 4)
	view.hand = ns.NewBoardMark(view.back, "hand", HAND_SIZE)
	view.hand:SetPoint("LEFT")
	view.back.label = ns.BoardText(view.back, fonts.hand, LOOK.red)
	view.back.label:SetPoint("LEFT", view.hand, "RIGHT", 4, 0)
	view.back:SetScript("OnClick", function(self)
		if self.set then
			ns.board:Open({ mode = "set", set = self.set })
		end
	end)
	view.kicker = text(fonts.kicker, LOOK.kicker)
	view.name = text(fonts.title, LOOK.title)
	view.target = text(fonts.small, LOOK.small)
	view.retired = text(fonts.hand, LOOK.red)
	view.seal = ns.NewBoardSeal(page, SEAL_SIZE)
	view.pin = newPin(page)
	view.window = text(fonts.hand, LOOK.hand)
	view.conditions = text(fonts.small, LOOK.small)
	view.bar = ns.NewBoardInkBar(page, BAR_WIDTH, BAR_HEIGHT)
	view.ladderUpdating = text(fonts.hand, LOOK.note)
	view.effort = text(fonts.hand, LOOK.hand)
	view.odds = text(fonts.small, LOOK.note)
	view.setLine = text(fonts.small, LOOK.small)
	view.empty = text(fonts.text, LOOK.note)
	return view
end

-- Hides every widget of the view, before a draw shows those it uses.
---@param view EntryView
local function hideAll(view)
	for _, widget in ipairs({
		view.back,
		view.kicker,
		view.name,
		view.target,
		view.retired,
		view.seal,
		view.pin,
		view.window,
		view.conditions,
		view.bar,
		view.ladderUpdating,
		view.effort,
		view.odds,
		view.setLine,
		view.empty,
	}) do
		widget:Hide()
	end
	for _, pool in ipairs({ view.chips, view.diamonds, view.thresholds, view.whens }) do
		for _, widget in ipairs(pool) do
			widget:Hide()
		end
	end
end

-- The `i`th of a pool, made with `make` the first time.
---@generic T
---@param pool T[]
---@param i integer
---@param make fun(): T
---@return T
local function pooled(pool, i, make)
	if not pool[i] then
		pool[i] = make()
	end
	return pool[i]
end

-- Lays out a text at the page's left `y` pixels down, `width` wide, if it has words; returns the y below it.
---@param text FontString
---@param words string?
---@param y number
---@param width number
---@return number
local function line(text, words, y, width)
	if not words then
		return y
	end
	text:SetText(words)
	text:SetWidth(width)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", 0, -y)
	text:Show()
	return y + text:GetStringHeight() + 2
end

-- Lays out the chips in rows across `width`, from `y` down; returns the y below them.
---@param view EntryView
---@param chips HuntEntryChip[]
---@param y number
---@param width number
---@return number
local function layChips(view, chips, y, width)
	if #chips == 0 then
		return y
	end
	local x = 0
	for i, data in ipairs(chips) do
		local chip = pooled(view.chips, i, function()
			return newChip(view.page)
		end)
		local chipWidth = setChip(chip, data)
		if x > 0 and x + chipWidth > width then
			x, y = 0, y + CHIP_HEIGHT + CHIP_GAP
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, -y)
		chip:Show()
		x = x + chipWidth + CHIP_GAP
	end
	return y + CHIP_HEIGHT + CHIP_GAP
end

-- Lays out the tier ladder from `y` down (HNT-R64, HNT-R18): a diamond in its tier's trim, its threshold and its
-- date and zone per step, then the ink bar; or the updating line (HNT-R69). Returns the y below it.
---@param view EntryView
---@param ladder HuntEntryLadder
---@param y number
---@param width number
---@return number
local function layLadder(view, ladder, y, width)
	if ladder.updating then
		return line(view.ladderUpdating, ladder.updating, y, width)
	end
	local page, fonts = view.page, ns.BoardFonts()
	for k, step in ipairs(ladder.tiers or {}) do
		local diamond = pooled(view.diamonds, k, function()
			return ns.NewBoardDiamond(page, DIAMOND_SIZE)
		end)
		diamond:SetDiamond(step.tier, step.reached)
		diamond:ClearAllPoints()
		diamond:SetPoint("TOPLEFT", 0, -y)
		diamond:Show()
		local threshold = pooled(view.thresholds, k, function()
			return ns.BoardText(page, fonts.text, LOOK.ink)
		end)
		threshold:SetText(ns.L.LADDER_TIER:format(step.tier, step.threshold))
		threshold:ClearAllPoints()
		threshold:SetPoint("LEFT", diamond, "RIGHT", 6, 0)
		threshold:Show()
		local when = pooled(view.whens, k, function()
			return ns.BoardText(page, fonts.small, LOOK.note)
		end)
		when:SetText(step.when or "")
		when:ClearAllPoints()
		when:SetPoint("LEFT", diamond, "RIGHT", 6 + THRESHOLD_WIDTH, 0)
		when:SetShown(step.when ~= nil)
		y = y + STEP_HEIGHT
	end
	local bar = ladder.bar
	if bar then
		view.bar:SetBar(bar.fill, bar.label)
		view.bar:ClearAllPoints()
		view.bar:SetPoint("TOPLEFT", 0, -(y + 3))
		view.bar:Show()
		y = y + STEP_HEIGHT
	end
	return y
end

-- Draws `entry` (logic/Entry.lua's HuntEntry) of Hunt `huntID` on its page, top to bottom.
---@param view EntryView
---@param entry HuntEntry
---@param huntID string
local function draw(view, entry, huntID)
	hideAll(view)
	local width = view.page:GetWidth()
	local heading = width - HEADING_ROOM
	local y = 0
	if entry.back then
		view.back.label:SetText(entry.back)
		view.back.set = entry.backSet
		view.back:ClearAllPoints()
		view.back:SetPoint("TOPLEFT", 0, 0)
		view.back:Show()
		y = HAND_SIZE + 6
	end
	local top = y
	view.seal:SetSeal(entry.seal.text, entry.seal.filled)
	view.seal:ClearAllPoints()
	view.seal:SetPoint("TOPRIGHT", 0, -top)
	view.seal:Show()
	if entry.pin then
		local pin, L = view.pin, ns.L
		pin.huntID, pin.pinned = huntID, entry.pin.pinned
		pin:SetAlpha(entry.pin.pinned and 1 or 0.45)
		pin.tooltip = { entry.pin.pinned and L.ENTRY_UNPIN or L.ENTRY_PIN }
		pin:ClearAllPoints()
		pin:SetPoint("TOPRIGHT", -(SEAL_SIZE + 10), -(top + 4))
		pin:Show()
	end
	y = line(view.kicker, entry.kicker and ns.BoardSmallCaps(entry.kicker), y, heading)
	y = line(view.name, entry.name, y, heading)
	y = line(view.target, entry.target, y, heading)
	y = line(view.retired, entry.retiredLine, y, heading)
	y = math.max(y, top + SEAL_SIZE) + GAP
	y = line(view.window, entry.window, y, width)
	y = line(view.conditions, entry.conditions, y, width)
	y = layChips(view, entry.chips, y + 2, width) + GAP
	y = layLadder(view, entry.ladder, y, width) + GAP
	y = line(view.effort, entry.effort.text, y, width)
	y = line(view.odds, entry.effort.odds, y, width) + GAP
	line(view.setLine, entry.setLine, y, width)
end

-- What the right page shows for `place`: "entry" or "retired" for a Hunt that has one there, nil for none. On the
-- Board only a current Hunt has one (HNT-R3); from a set's page a Retired Hunt opens its retired entry.
---@param place BoardPlace
---@param now integer
---@return HuntDef?
---@return ("entry"|"retired")?
local function shownAt(place, now)
	local hunt = place.hunt and ns.hunts:Hunt(place.hunt)
	if not hunt then
		return nil
	elseif ns.IsCurrent(hunt, now) then
		return hunt, "entry"
	elseif place.mode ~= "board" and ns.IsRetired(hunt, now) then
		return hunt, "retired"
	end
	return nil
end

-- The board's right page in the Board, entry and retired modes (logic/Board.lua): the Hunt's entry, its retired entry,
-- or on the Board with none HNT-R67's line.
---@param page Frame
---@param place BoardPlace
local function render(page, place)
	local held = page --[[@as EntryPage]]
	local view = held.entry or newView(page)
	held.entry = view
	local now = GetServerTime()
	local hunt, shown = shownAt(place, now)
	if not hunt then
		hideAll(view)
		local grouping = ns.groups:Grouping()
		local empty = place.mode == "board"
			and ns.EntryEmptyLine(grouping and #grouping.rows or 0, #ns.groups:Rows({ filtered = true }))
		line(view.empty, empty or nil, 0, page:GetWidth())
		return
	end
	local row = ns.groups:Row(hunt.id)
	local entry = ns.HuntEntry({
		hunt = hunt,
		list = ns.hunts,
		where = ns.where[hunt.id],
		state = ns.State(),
		updating = ns.IsUpdating(),
		retired = shown == "retired",
		row = row,
		unconfirmed = ns.Unconfirmed(hunt, row and row.window),
		pinned = ns.IsPinned(hunt.id),
		fromSet = place.mode ~= "board" and place.set or nil,
		now = ns.TimelineNow(), -- the countdowns count from now, frozen while the grouping is paused (HNT-R43)
		snapshot = Pagle.GetConditions(),
		best = Pagle.GetAngler().bestBaseSkill,
		sources = ns.names,
	})
	draw(view, entry, hunt.id)
end

ns.board:RegisterPage("board", "right", render)
ns.board:RegisterPage("entry", "right", render)
ns.board:RegisterPage("retired", "right", render)
