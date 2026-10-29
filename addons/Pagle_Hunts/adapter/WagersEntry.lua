if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- A run's entry on the board's right page (HNT-R163), the Wagers redesign's variant A: what logic/Wagers.lua's
-- ns.BuildRunEntry says, drawn top down from data/art/wagers/art.json's `entry` in the kit's inks (adapter/WagersArt.lua):
-- the kicker with its source mark, the name, the event mark at the top right with the wax seal pressed over it once
-- settled, the time block with its dial, the chips, the note in the hand, a row per Hunt (its shape glyph, name, count,
-- line, diamonds, ink bar and a Timed Hunt's window), the Casts line, the two pay boxes and the pay rule. The Pagle
-- Wagers spread draws it on its right page (adapter/WagersSpread.lua), and the Board on its own while a run is selected
-- (adapter/Entry.lua). The entry never scrolls: it tightens with five Hunts and keeps to the page by HNT-R163's fit
-- rule (ns.RunEntryFit). Nothing here moves (HNT-R167's dial steps at each draw).

local LOOK = ns.BOARD_LOOK
local L = ns.L

-- The measures (art.json › entry), in UI units down the right page: the source mark's size and the gap after it; the
-- name's top, width and most lines; the event mark's size and its place from the page's top right; the seal's place
-- (its right edge from the page's right, and its top), its size and tilt, and its words' offsets from its centre. The
-- kit drew the seal's left at 272.9 of a 321-unit page, which put its right edge 18 units past the page and the mark's
-- 4 past it too: the page's frame clips there, cutting the wax and its words ("SETTLEI / 29 Oc"). Here both stay on
-- the page: the seal keeps the kit's height and its place at the mark's lower right (8 units right of the mark's left,
-- where the kit's was 14), so the mark moved 14 units in and the name's width came in with it.
local SRC_MARK, SRC_GAP, NAME_Y, NAME_W, NAME_LINES = 13, 5, 17, 237, 3
local MARK_SIZE, MARK_R, MARK_Y = 66, 10, -2
local SEAL_R, SEAL_Y, SEAL_SIZE, SEAL_TILT, SEAL_WORD_Y, SEAL_DATE_Y = 2, 30.1, 66, -12, -8, 4
-- The heading's least height, and the gap under it (tighter with five Hunts); the time block's height, its dial's size
-- and its words' places.
local TOP_MIN, TOP_GAP, TOP_GAP_TIGHT = 70, 8, 5
local TIME_HEIGHT, DIAL, HAND_X, HAND_Y, SMALL_Y = 40, 40, 49, 0.2, 22.9
-- The chips: the gap above, their height, the gap between, the words' padding, the caps, the badge's gap.
local CHIPS_GAP, CHIP_H, CHIP_GAP, CHIP_PAD, CHIP_CAP, BADGE_GAP = 7, 20, 4, 7, 10, 5
-- The gaps above the note and the rows; the updating line's room.
local NOTE_GAP, HUNTS_GAP, UPDATING_ROOM = 6, 7, 29
-- A row: its padding, its glyph, its words' left, its line's place, its diamonds, its bar and its window line, and its
-- heights (plain, with a window line, tight).
local ROW_PAD, ROW_PAD_TIGHT, GLYPH, GLYPH_Y, WORDS_X, LINE_Y = 5, 3, 16, 1, 26, 16
local DIAMOND, DIAMOND_GAP, DIAMOND_R, DIAMOND_Y = 7.5, 4.5, 1.2, 19.1
local BAR_Y, BAR_Y_TIGHT, BAR_H, WINDOW_Y = 33.8, 32.8, 5, 41.8
local ROW_PLAIN, ROW_TIMED, ROW_TIGHT = 49.8, 66.6, 44.8
-- The Casts line's gap; the pay boxes' gap above, height, gap between and words' places; the pay rule's gap above.
local CASTS_GAP, PAY_GAP, PAY_H, PAY_BETWEEN, PAY_X, PAY_LABEL_Y, PAY_AMOUNT_Y, RULE_GAP = 6, 6, 40, 6, 7, 5, 19, 5
-- The Refreshes a box pays sit on the label row, at the right of the box (HNT-R117).
local PAY_REFRESH_Y = 4
-- With no run: the title's and the hand's tops.
local NONE_TITLE_Y, NONE_HAND_Y = 17, 55
-- How far below its drawable area the entry may end (HNT-R163's fit rule): the kit's 512 on its 500-unit area, half
-- the page's 24-unit bottom margin; the board's right page frame is 510 high, with 16 more of the shell's under it.
local FIT_SLACK = 2

-- Each shape's glyph in the Wagers atlas (HNT-R163).
---@type table<EventHuntShape, string>
local GLYPHS = {
	timed = "shape-timed",
	big = "shape-bigones",
	quality = "shape-quality",
	haul = "shape-haul",
	named = "shape-namedfish",
}

-- Each chip kind's sprite and ink (art.json › entry.chips.kinds).
local CHIPS = {
	zone = { atlas = "Parts", sprite = "chip", ink = "chip" },
	here = { atlas = "Parts", sprite = "chip-here", ink = "chip" },
	skill = { atlas = "Wagers", sprite = "chip-pencil", ink = "chipPencil" },
	holiday = { atlas = "Wagers", sprite = "chip-holiday", ink = "chipHoliday" },
}

---@class RunEntryChipView: Frame
---@field face HuntsThreeSlice
---@field label WagerText
---@field badge WagerText
---@field kind string

---@class RunEntryRowView
---@field glyph HuntsSpriteTexture
---@field name WagerText
---@field count WagerText
---@field rest WagerText
---@field line WagerText
---@field diamonds HuntsSpriteTexture[]
---@field track Texture
---@field edge BoardOutline
---@field trackFrame Frame
---@field fill Texture
---@field window WagerText
---@field rule Texture

---@class RunEntryPayView: Frame
---@field wash Texture
---@field ring BoardOutline
---@field label WagerText
---@field amount WagerText
---@field refresh WagerText   -- the Refreshes the box pays, at the label's right (HNT-R117)
---@field tooltip string[]?

---@class RunEntryView
---@field page Frame
---@field root Frame              -- holds every part, so hiding it hides the entry
---@field srcMark HuntsSpriteTexture
---@field srcSeal HuntsSpriteTexture
---@field kicker WagerText
---@field name WagerText
---@field mark WagerMarkView
---@field seal Frame
---@field sealWax HuntsSpriteTexture
---@field sealWord WagerText
---@field sealDate WagerText
---@field dial WagerDialView
---@field hand WagerText
---@field small WagerText
---@field chips RunEntryChipView[]
---@field note WagerText
---@field rule Texture
---@field updating WagerText
---@field rows RunEntryRowView[]
---@field casts WagerText
---@field pay RunEntryPayView[]
---@field payRule WagerText
---@field none { kicker: WagerText, title: WagerText, hand: WagerText, rule: WagerText }
---@field dropped { rule: boolean, casts: boolean, windows: boolean }  -- what the fit rule left out at the last draw
---@field shown boolean

-- Each right page's run entry, by its page frame.
---@type table<Frame, RunEntryView>
local entries = {}

-- A wrapping font string on `parent` in ink `ink`, `width` wide.
---@param parent Frame
---@param ink string
---@param width number
---@return WagerText
local function wrapped(parent, ink, width)
	local text = ns.NewWagerText(parent, ink)
	text:SetWordWrap(true)
	text:SetWidth(width)
	return text
end

-- A pay box on `parent`: its oxblood wash and rim, its label over its amount, its tooltip the pay rule when the fit
-- rule left the rule out.
---@param parent Frame
---@return RunEntryPayView
local function newPay(parent)
	local box = CreateFrame("Frame", nil, parent) --[[@as RunEntryPayView]]
	box.wash = box:CreateTexture(nil, "BACKGROUND")
	box.wash:SetAllPoints()
	ns.FillWager(box.wash, LOOK.oxbloodWash)
	box.ring = ns.BoardOutline(box, 0, "BORDER")
	box.ring:Solid(LOOK.oxbloodRing, LOOK.oxbloodRing[4])
	box.label = ns.NewWagerText(box, "payLabel")
	box.amount = ns.NewWagerText(box, "payAmount")
	box.refresh = ns.NewWagerText(box, "payRefresh")
	box:EnableMouse(true)
	box:SetScript("OnEnter", function(self)
		if self.tooltip then
			ns.BoardTooltip(self, self.tooltip)
		end
	end)
	box:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return box
end

-- The entry's widgets on `page`, made at its first draw.
---@param page Frame
---@return RunEntryView
local function newEntry(page)
	local width = page:GetWidth()
	local root = CreateFrame("Frame", nil, page)
	root:SetAllPoints()
	local view = {
		page = page,
		root = root,
		srcMark = ns.WagerSprite(root, "src-rotation", SRC_MARK),
		srcSeal = ns.WagerSprite(root, "src-companion-seal", SRC_MARK, "ARTWORK", 1),
		kicker = ns.NewWagerText(root, "src"),
		name = wrapped(root, "evName", NAME_W),
		mark = ns.NewEventMark(root, MARK_SIZE),
		seal = CreateFrame("Frame", nil, root),
		dial = ns.NewWagerDial(root, DIAL),
		hand = ns.NewWagerText(root, "timeHand"),
		small = ns.NewWagerText(root, "timeSmall"),
		chips = {},
		note = wrapped(root, "evNote", width),
		rule = root:CreateTexture(nil, "ARTWORK"),
		updating = ns.NewWagerText(root, "updating"),
		rows = {},
		casts = ns.NewWagerText(root, "casts"),
		pay = { newPay(root), newPay(root) },
		payRule = wrapped(root, "payRule", width),
		none = {
			kicker = ns.NewWagerText(root, "kicker"),
			title = ns.NewWagerText(root, "emptyTitle"),
			hand = wrapped(root, "emptyHand", width),
			rule = wrapped(root, "payRule", width),
		},
		dropped = { rule = false, casts = false, windows = false },
		shown = false,
	}
	view.name:SetMaxLines(NAME_LINES)
	ns.FillWager(view.rule, LOOK.huntsRule)
	view.rule:SetHeight(1)
	-- the seal over the mark's lower right: Core's wax, tilted, its word over its date
	view.seal:SetSize(SEAL_SIZE, SEAL_SIZE)
	view.seal:SetFrameLevel(view.mark:GetFrameLevel() + 1)
	view.sealWax = ns.ArtSprite(view.seal, "Book", "seal", "ARTWORK", 0, SEAL_SIZE)
	view.sealWax:SetAllPoints()
	view.sealWax:SetRotation(math.rad(SEAL_TILT))
	view.sealWord = ns.NewWagerText(view.seal, "sealWord")
	view.sealDate = ns.NewWagerText(view.seal, "sealDate")
	for _, text in ipairs({ view.sealWord, view.sealDate }) do
		text:SetJustifyH("CENTER")
	end
	view.sealWord:SetPoint("CENTER", 0, -SEAL_WORD_Y)
	view.sealDate:SetPoint("CENTER", 0, -SEAL_DATE_Y)
	return view
end

-- A Hunt's row's widgets.
---@param view RunEntryView
---@return RunEntryRowView
local function newRow(view)
	local root = view.root
	local row = {
		glyph = ns.WagerSprite(root, "shape-haul", GLYPH),
		name = ns.NewWagerText(root, "huntName"),
		count = ns.NewWagerText(root, "huntCount"),
		rest = ns.NewWagerText(root, "huntNext"),
		line = ns.NewWagerText(root, "huntLine"),
		diamonds = {},
		trackFrame = CreateFrame("Frame", nil, root),
		window = ns.NewWagerText(root, "window"),
		rule = root:CreateTexture(nil, "ARTWORK"),
	}
	row.track = row.trackFrame:CreateTexture(nil, "BACKGROUND")
	row.track:SetAllPoints()
	ns.FillWager(row.track, LOOK.barTrack)
	row.edge = ns.BoardOutline(row.trackFrame, 0, "BORDER")
	row.edge:Solid(LOOK.barEdge, LOOK.barEdge[4])
	row.fill = row.trackFrame:CreateTexture(nil, "ARTWORK")
	row.fill:SetPoint("TOPLEFT")
	ns.FillWager(row.rule, LOOK.rowRule)
	row.rule:SetHeight(1)
	return row
end

-- Every widget of a row.
---@param row RunEntryRowView
---@return Region[]
local function rowWidgets(row)
	local all = { row.glyph, row.name, row.count, row.rest, row.line, row.trackFrame, row.window, row.rule }
	for _, diamond in ipairs(row.diamonds) do
		all[#all + 1] = diamond
	end
	return all
end

-- Hides the widgets a draw shows only for some entries, so each draw shows what it lays.
---@param view RunEntryView
local function hideParts(view)
	for _, widget in ipairs({
		view.srcMark,
		view.srcSeal,
		view.kicker,
		view.name,
		view.mark,
		view.seal,
		view.dial,
		view.hand,
		view.small,
		view.note,
		view.rule,
		view.updating,
		view.casts,
		view.pay[1],
		view.pay[2],
		view.payRule,
		view.none.kicker,
		view.none.title,
		view.none.hand,
		view.none.rule,
	}) do
		widget:Hide()
	end
	ns.BoardHideFrom(view.chips, 0)
	for _, row in ipairs(view.rows) do
		for _, widget in ipairs(rowWidgets(row)) do
			widget:Hide()
		end
	end
end

--- Hides the run's entry on `page`, if it has one: the right page shows a Hunt's entry instead.
---@param page Frame
function ns.HideRunEntry(page)
	local view = entries[page]
	if view and view.shown then
		view.shown = false
		view.root:Hide()
	end
end

-- Sets wrapped `text` to `words` at `y`, its left `x`; returns its height.
---@param text WagerText
---@param words string
---@param x number
---@param y number
---@param relative Region
---@return number
local function layWrapped(text, words, x, y, relative)
	ns.SetWagerWords(text, words)
	ns.PlaceWagerText(text, relative, x, y)
	return math.max(ns.WagerLineHeight(text.ink), math.ceil(text:GetStringHeight()))
end

-- Lays the chips in rows from `y` (HNT-R163): each its sprite three-sliced to its words, a zone chip for the live zone
-- with "you're here" after them; returns the y under them.
---@param view RunEntryView
---@param chips HuntEntryChip[]
---@param y number
---@return number
local function layChips(view, chips, y)
	local width, x = view.page:GetWidth(), 0
	for i, data in ipairs(chips) do
		local chip = ns.BoardPooled(view.chips, i, function()
			local made = CreateFrame("Frame", nil, view.root) --[[@as RunEntryChipView]]
			made.face = CreateFrame("Frame", nil, made) --[[@as HuntsThreeSlice]]
			made.face:SetPoint("TOPLEFT")
			made.face:SetFrameLevel(made:GetFrameLevel())
			made.label = ns.NewWagerText(made.face, "chip")
			made.label:SetPoint("LEFT", CHIP_PAD, 0)
			made.badge = ns.NewWagerText(made.face, "chipHere")
			made.badge:SetPoint("LEFT", made.label, "RIGHT", BADGE_GAP, 0)
			return made
		end)
		local kind = data.here and "here" or CHIPS[data.kind] and data.kind or "zone"
		local look = CHIPS[kind]
		chip.kind = kind
		ns.SetWagerInk(chip.label, look.ink)
		local badge = 0
		if data.badge then
			ns.SetWagerWords(chip.badge, data.badge)
			chip.badge:Show()
			badge = math.ceil(chip.badge:GetStringWidth()) + BADGE_GAP
		else
			chip.badge:Hide()
		end
		local words = ns.FitWagerText(chip.label, data.text, width - 2 * CHIP_PAD - badge)
		local chipWidth = words + 2 * CHIP_PAD + badge
		ns.SetThreeSliceAt(chip.face, look.atlas, look.sprite, chipWidth, CHIP_H, CHIP_CAP, CHIP_CAP, "BACKGROUND")
		chip:SetSize(chipWidth, CHIP_H)
		if x > 0 and x + chipWidth > width then
			x, y = 0, y + CHIP_H + CHIP_GAP
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", view.root, "TOPLEFT", x, -y)
		x = x + chipWidth + CHIP_GAP
	end
	ns.BoardHideFrom(view.chips, #chips)
	return #chips > 0 and y + CHIP_H or y
end

-- Lays Hunt `data`'s row from `y` (HNT-R163); returns its height and the room its window line took.
---@param view RunEntryView
---@param i integer
---@param data RunEntryHunt
---@param y number
---@param entry RunEntry
---@param dropWindows boolean
---@return number height
---@return number window
local function layRow(view, i, data, y, entry, dropWindows)
	local width, root = view.page:GetWidth(), view.root
	local row = view.rows[i] or newRow(view)
	view.rows[i] = row
	local tight, faded = entry.tight, entry.updating ~= nil
	local ry = y + (tight and ROW_PAD_TIGHT or ROW_PAD)
	local alpha = faded and 0.45 or 1
	ns.SetSprite(row.glyph, "Wagers", GLYPHS[data.shape] or GLYPHS.named, GLYPH)
	ns.PlaceSprite(row.glyph, root, 0, ry + GLYPH_Y)
	ns.TintWager(row.glyph, data.got and LOOK.oxblood or LOOK.legend, alpha)
	row.glyph:Show()
	-- the count at the right, the count in the hand and the rest after it
	local right = 0
	if data.count then
		ns.SetWagerWords(row.rest, data.count.rest)
		row.rest:SetWidth(0)
		ns.PlaceWagerText(row.rest, root, 0, ry, true)
		local restWidth = math.ceil(row.rest:GetStringWidth())
		ns.SetWagerWords(row.count, data.count.count)
		row.count:SetWidth(0)
		ns.PlaceWagerText(row.count, root, restWidth, ry, true)
		right = restWidth + math.ceil(row.count:GetStringWidth())
	else
		row.count:Hide()
		row.rest:Hide()
	end
	ns.FitWagerText(row.name, data.name, width - WORDS_X - (right > 0 and right + 6 or 0))
	ns.PlaceWagerText(row.name, root, WORDS_X, ry)
	-- the diamonds at the right of the line, each in its trim once reached
	local tiers = data.tiers or {}
	for k, tier in ipairs(tiers) do
		local diamond = ns.BoardPooled(row.diamonds, k, function()
			return ns.ArtSprite(root, "Parts", "tier-off", "ARTWORK", 0, DIAMOND)
		end)
		ns.SetSprite(diamond, "Parts", tier.reached and "tier-on" or "tier-off", DIAMOND)
		local x = width - DIAMOND_R - (#tiers - k + 1) * DIAMOND - (#tiers - k) * DIAMOND_GAP
		ns.PlaceSprite(diamond, root, x, ry + DIAMOND_Y)
		ns.TintWager(diamond, tier.reached and LOOK.tierInks[tier.trim] or LOOK.note, alpha)
	end
	ns.BoardHideFrom(row.diamonds, #tiers)
	local diamonds = #tiers > 0 and #tiers * (DIAMOND + DIAMOND_GAP) - DIAMOND_GAP + 6 or 0
	ns.FitWagerText(row.line, data.line, width - WORDS_X - diamonds)
	ns.PlaceWagerText(row.line, root, WORDS_X, ry + LINE_Y)
	for _, text in ipairs({ row.name, row.count, row.rest, row.line }) do
		text:SetAlpha(alpha)
	end
	-- the ink bar toward the next threshold, oxblood once it has its first mark
	if data.fill then
		local barWidth = width - WORDS_X
		row.trackFrame:ClearAllPoints()
		row.trackFrame:SetPoint("TOPLEFT", root, "TOPLEFT", WORDS_X, -(ry + (tight and BAR_Y_TIGHT or BAR_Y)))
		row.trackFrame:SetSize(barWidth, BAR_H)
		row.fill:SetSize(math.max(0.01, barWidth * data.fill), BAR_H)
		ns.FillWager(row.fill, data.got and LOOK.barInkGot or LOOK.barInk)
		row.fill:SetShown(data.fill > 0)
		row.trackFrame:Show()
	else
		row.trackFrame:Hide()
	end
	-- a Timed Hunt's window line, left out when tight or by the fit rule
	local height, window = tight and ROW_TIGHT or ROW_PLAIN, 0
	if data.window and not tight then
		window = ROW_TIMED - ROW_PLAIN
		if not dropWindows then
			ns.SetWagerInk(row.window, data.window.open and "windowOpen" or "window")
			ns.FitWagerText(row.window, data.window.text, width - WORDS_X)
			ns.PlaceWagerText(row.window, root, WORDS_X, ry + WINDOW_Y)
			row.window:SetAlpha(alpha)
			height = ROW_TIMED
		else
			row.window:Hide()
		end
	else
		row.window:Hide()
	end
	row.rule:ClearAllPoints()
	row.rule:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -(y + height - 1))
	row.rule:SetWidth(width)
	row.rule:Show()
	return height, window
end

-- Lays `entry` top down on `view`, leaving out what `drop` says (HNT-R163's fit rule); returns where it ends and the
-- room each part the fit rule weighs takes.
---@param view RunEntryView
---@param entry RunEntry
---@param drop { rule: boolean, casts: boolean, windows: boolean }
---@return RunEntrySizes
local function lay(view, entry, drop)
	hideParts(view)
	local width, root = view.page:GetWidth(), view.root
	-- the kicker with its source mark, the name, the event mark and, once settled, the seal over it
	ns.SetSprite(view.srcMark, "Wagers", entry.source == "companion" and "src-companion" or "src-rotation", SRC_MARK)
	ns.PlaceSprite(view.srcMark, root, 0, 0)
	ns.TintWager(view.srcMark, LOOK.kicker)
	view.srcMark:Show()
	if entry.source == "companion" then
		ns.PlaceSprite(view.srcSeal, root, 0, 0)
		view.srcSeal:Show()
	end
	ns.FitWagerText(view.kicker, entry.kicker, NAME_W - SRC_MARK - SRC_GAP)
	ns.PlaceWagerText(view.kicker, root, SRC_MARK + SRC_GAP, 0)
	local nameHeight = layWrapped(view.name, entry.name, 0, NAME_Y, root)
	view.mark:ClearAllPoints()
	view.mark:SetPoint("TOPLEFT", root, "TOPLEFT", width - MARK_SIZE - MARK_R, -MARK_Y)
	view.mark:SetMark(entry.mark)
	view.mark:Show()
	if entry.seal then
		view.seal:ClearAllPoints()
		view.seal:SetPoint("TOPLEFT", root, "TOPLEFT", width - SEAL_SIZE - SEAL_R, -SEAL_Y)
		ns.SetWagerWords(view.sealWord, entry.seal.word)
		ns.SetWagerWords(view.sealDate, entry.seal.date)
		view.sealWord:Show()
		view.sealDate:Show()
		view.seal:Show()
	end
	local y = math.max(TOP_MIN, NAME_Y + nameHeight) + (entry.tight and TOP_GAP_TIGHT or TOP_GAP)
	-- the time block
	local time = entry.time
	view.dial:ClearAllPoints()
	view.dial:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
	view.dial:SetDial(time.dial)
	view.dial:Show()
	ns.SetWagerInk(view.hand, time.ahead and "timeHandAhead" or "timeHand")
	ns.FitWagerText(view.hand, time.hand, width - HAND_X)
	ns.PlaceWagerText(view.hand, root, HAND_X, y + HAND_Y)
	ns.FitWagerText(view.small, time.small, width - HAND_X)
	ns.PlaceWagerText(view.small, root, HAND_X, y + SMALL_Y)
	y = y + TIME_HEIGHT + CHIPS_GAP
	-- the chips, the note, the rule over the rows and, while updating, its line
	y = layChips(view, entry.chips, y) + NOTE_GAP
	if entry.note then
		ns.SetWagerInk(view.note, entry.tight and "evNoteTight" or "evNote")
		y = y + layWrapped(view.note, entry.note, 0, y, root)
	end
	y = y + HUNTS_GAP
	view.rule:ClearAllPoints()
	view.rule:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
	view.rule:SetWidth(width)
	view.rule:Show()
	y = y + 1
	if entry.updating then
		ns.FitWagerText(view.updating, entry.updating, width)
		ns.PlaceWagerText(view.updating, root, 0, y + 2)
		y = y + UPDATING_ROOM
	end
	-- the rows
	local windows = 0
	for i, hunt in ipairs(entry.hunts) do
		local height, window = layRow(view, i, hunt, y, entry, drop.windows)
		y, windows = y + height, windows + window
	end
	-- the Casts line, the pay boxes and the pay rule
	local sizes = { rule = 0, casts = 0, windows = windows }
	if entry.casts then
		sizes.casts = CASTS_GAP - 1 + ns.WagerLineHeight("casts")
		if not drop.casts then
			ns.FitWagerText(view.casts, entry.casts, width)
			ns.PlaceWagerText(view.casts, root, 0, y + CASTS_GAP - 1)
			y = y + sizes.casts
		end
	end
	if entry.pay then
		y = y + PAY_GAP
		local boxWidth = (width - PAY_BETWEEN) / 2
		for i, data in ipairs(entry.pay) do
			local box = view.pay[i]
			box:ClearAllPoints()
			box:SetPoint("TOPLEFT", root, "TOPLEFT", (i - 1) * (boxWidth + PAY_BETWEEN), -y)
			box:SetSize(boxWidth, PAY_H)
			ns.FitWagerText(box.label, data.label, boxWidth - 2 * PAY_X)
			ns.PlaceWagerText(box.label, box, PAY_X, PAY_LABEL_Y)
			ns.FitWagerText(box.amount, data.amount, boxWidth - 2 * PAY_X)
			ns.PlaceWagerText(box.amount, box, PAY_X, PAY_AMOUNT_Y)
			if data.refresh then
				ns.FitWagerText(box.refresh, data.refresh, boxWidth - 2 * PAY_X)
				ns.PlaceWagerText(box.refresh, box, PAY_X, PAY_REFRESH_Y, true)
			else
				box.refresh:Hide()
			end
			box.tooltip = drop.rule and { data.label, entry.payRule } or nil
			box:Show()
		end
		y = y + PAY_H
	end
	sizes.rule = RULE_GAP + layWrapped(view.payRule, entry.payRule, 0, y + RULE_GAP, root)
	if drop.rule then
		view.payRule:Hide()
	else
		y = y + sizes.rule
	end
	sizes.ends = y
	return sizes
end

-- Draws the right page with no run at all (HNT-R163): "Nothing to read yet", the hand's line, then the pay rule.
---@param view RunEntryView
local function layNone(view)
	hideParts(view)
	local none, root = view.none, view.root
	ns.SetWagerWords(none.kicker, L.WAGERS_KICKER)
	ns.PlaceWagerText(none.kicker, root, 0, 0)
	ns.FitWagerText(none.title, L.ENTRY_NONE_TITLE, view.page:GetWidth())
	ns.PlaceWagerText(none.title, root, 0, NONE_TITLE_Y)
	local y = NONE_HAND_Y + layWrapped(none.hand, L.ENTRY_NONE_HAND, 0, NONE_HAND_Y, root)
	layWrapped(none.rule, ns.RunPayRule(), 0, y + RULE_GAP, root)
end

-- The entry's view on `page`, made at its first draw, shown.
---@param page Frame
---@return RunEntryView
local function viewOn(page)
	local view = entries[page]
	if not view then
		view = newEntry(page)
		entries[page] = view
	end
	view.shown = true
	view.root:Show()
	return view
end

--- Draws run `runKey`'s entry (HNT-R163) on the right page `page`, top to bottom, fitted to the page by HNT-R163's
--- rule: laid with everything first, then again leaving out the pay rule, the Casts line and the window lines as
--- ns.RunEntryFit says. No pin toggle and no set line. Returns false, drawing nothing, for a run the board doesn't show.
---@param page Frame
---@param runKey string
---@return boolean
function ns.DrawRunEntry(page, runKey)
	local entry = ns.BoardRunEntry(runKey)
	if not entry then
		ns.HideRunEntry(page)
		return false
	end
	local view = viewOn(page)
	local none = { rule = false, casts = false, windows = false }
	local drop = ns.RunEntryFit(lay(view, entry, none), page:GetHeight() + FIT_SLACK)
	if drop.rule or drop.casts or drop.windows then
		lay(view, entry, drop)
	end
	view.dropped = drop
	return true
end

--- Draws the Pagle Wagers spread's right page with no run on or ahead (HNT-R163's last line).
---@param page Frame
function ns.DrawNoRunEntry(page)
	layNone(viewOn(page))
end

--- The run's entry drawn on `page`, nil before its first draw: for a spec to read.
---@param page Frame
---@return RunEntryView?
function ns.RunEntryView(page)
	return entries[page]
end
