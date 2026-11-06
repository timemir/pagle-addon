if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- A Hunt's entry on the board's right page (HNT-R3, HNT-R64–R67, HNT-R69, HNT-R80): the renderer of the Board, entry
-- and retired modes (logic/Board.lua). What each line says is logic/Entry.lua's; this file reads the client, Core and
-- the seams for it and draws it top to bottom as the books art kit's Hunts board lays it out (adapter/BoardWidgets.lua's
-- art): the kicker, name and target line with the "Pinned" pill under them and the wax seal at the top right, the
-- window line in the hand, the conditions, the chips, the tier ladder with the ink bar, the effort in the hand, and the
-- set line under a rule at the page's foot.

local LOOK = ns.BOARD_LOOK

-- The seal's size and where its centre sits from the page's top right, and the room the heading leaves it. The kicker,
-- on the first line, leaves it less: the wax is round, and at the kicker's foot (18 units down) it reaches 66.7 units
-- in from the page's right (the seal sprite's opaque edge), so the kicker keeps to 71 from it, 4 clear of the wax; a
-- language's longer kicker ("HEIMISCHE GEWÄSSER · AUFERLEGT") then reads whole where the full 96 cut it short. Past
-- that it is set a size down at a time, to KICKER_FLOOR, and only then cut.
local SEAL_SIZE, SEAL_RIGHT, SEAL_DOWN, HEADING_ROOM, KICKER_ROOM, KICKER_FLOOR = 88, 38.5, 39.5, 96, 71, 10
-- The pin pill's height, its pin's place and its words' place.
local PILL_HEIGHT, PILL_CAP, PIN_X, PIN_Y, PIN_WORDS_X = 30, 15, 6, 7, 28
-- The heading's measures down the page: the kicker, the name, the gap before the pill, and the least room the heading
-- and the seal take before the window line.
local KICKER_Y, NAME_Y, PILL_GAP, HEAD_ROOM = 3, 19, 6, 120
-- Gaps between blocks; a chip's height, its words' padding, the gap across and the step down.
local GAP, CHIP_HEIGHT, CHIP_PAD, CHIP_GAP, CHIP_STEP = 8, 22, 8, 5, 27
-- A tight entry's (draw's third step, a language's longer lines running it past the page's foot): the gaps between
-- its blocks, the room under the chips (14 as the kit lays it), and the least size its name is set at to keep to one
-- line.
local GAP_TIGHT, CHIPS_FOOT, CHIPS_FOOT_TIGHT, NAME_FLOOR = 4, 14, 8, 22
-- A conditions line's step down (its 13.5 and its 4 of spacing), to count its lines.
local CONDITIONS_LINE = 17.5
-- A ladder step's height, its mark's size and place, its threshold's and its date's places, and the ink bar's width.
local STEP_HEIGHT, MARK_SIZE, MARK_X, THRESHOLD_X, WHEN_X, BAR_WIDTH = 23, 12, 2.5, 24, 60, 261
-- The set line's rule from the page's foot at the least, and its words under the rule.
local SET_RULE_Y, SET_WORDS_GAP = 484, 8
-- The pointing hand before "back to {set}".
local HAND_SIZE = 16

-- Gives `frame` a tooltip of `frame.tooltip`'s lines, when it has some.
---@param frame Frame
local function withTooltip(frame)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(self)
		if self.tooltip then
			ns.BoardTooltip(self, self.tooltip)
		end
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Sets a font string's colour from a tint.
---@param text FontString
---@param color number[]
local function inkText(text, color)
	text:SetTextColor(color[1], color[2], color[3])
end

--- A chip (HNT-R65): the kit's paper chip, three-sliced to its words (green-edged for the zone I'm in, red short of
--- skill, dashed unconfirmed), and the "you're here" badge after them.
---@class EntryChipView: Frame
---@field face HuntsThreeSlice
---@field label FontString
---@field badge FontString
---@field tooltip string[]?

---@param parent Frame
---@return EntryChipView
local function newChip(parent)
	local fonts = ns.BoardFonts()
	local chip = CreateFrame("Frame", nil, parent) --[[@as EntryChipView]]
	chip:SetHeight(CHIP_HEIGHT)
	chip.face = CreateFrame("Frame", nil, chip) --[[@as HuntsThreeSlice]]
	chip.face:SetPoint("TOPLEFT")
	chip.face:SetFrameLevel(chip:GetFrameLevel())
	chip.label = ns.BoardText(chip.face, fonts.small, LOOK.chipText)
	chip.label:SetPoint("LEFT", CHIP_PAD, 0)
	chip.label:SetWordWrap(false)
	chip.badge = ns.BoardText(chip.face, ns.ArtFont("hand", 16), LOOK.here)
	chip.badge:SetPoint("LEFT", chip.label, "RIGHT", 6, 0)
	withTooltip(chip)
	return chip
end

-- The smallest a chip's words shrink to before they are cut short.
local CHIP_FLOOR = 11

-- Dresses `chip` as `data` says, and sizes it to its words, no wider than `room` (the page's width): longer words
-- shrink, then are cut short with an ellipsis, with the full words in its tooltip. Returns its width.
---@param chip EntryChipView
---@param data HuntEntryChip
---@param room number
---@return number
local function setChip(chip, data, room)
	local unconfirmed = data.kind == "unconfirmed"
	local ink = data.short and LOOK.red or unconfirmed and LOOK.unconfirmed or LOOK.chipText
	chip.label:SetFontObject(unconfirmed and ns.BoardFonts().note or ns.BoardFonts().small)
	chip.label:SetText(data.text)
	inkText(chip.label, ink)
	chip.badge:SetText(data.badge or "")
	chip.badge:SetShown(data.badge ~= nil)
	local badge = data.badge and math.ceil(chip.badge:GetStringWidth()) + 6 or 0
	local words = room - 2 * CHIP_PAD - badge
	local fitted = math.ceil(chip.label:GetStringWidth()) > words
	if fitted then
		ns.FitText(
			chip.label,
			unconfirmed and "italic" or "print",
			unconfirmed and 13 or 13.5,
			words,
			CHIP_FLOOR,
			false,
			ink
		)
	else
		chip.label:SetWidth(0)
	end
	chip.tooltip = data.tooltip or (fitted and { data.text } or nil)
	local width = math.min(math.ceil(chip.label:GetStringWidth()), words) + 2 * CHIP_PAD + badge
	local face = data.badge and "chip-here" or data.short and "chip-red" or unconfirmed and "chip-unc" or "chip"
	ns.SetThreeSlice(chip.face, "Parts", face, width, 11, "BACKGROUND")
	chip:SetWidth(width)
	return width
end

--- A chip on `parent` (HNT-R65), and its dressing: a run's entry draws its zone chips with them (adapter/Wagers.lua).
ns.NewEntryChip, ns.SetEntryChip = newChip, setChip

--- The pin toggle (HNT-R80): the kit's paper pill with its red pin and "Pinned" in the hand, faint ("Pin") until
--- pinned; a click pins or unpins the Hunt shown.
---@class EntryPinView: Button
---@field pill HuntsThreeSlice
---@field head HuntsSpriteTexture
---@field label FontString
---@field pinned boolean
---@field huntID string?
---@field tooltip string[]

---@param parent Frame
---@return EntryPinView
local function newPin(parent)
	local pin = CreateFrame("Button", nil, parent) --[[@as EntryPinView]]
	pin:SetHeight(PILL_HEIGHT)
	pin.pill = CreateFrame("Frame", nil, pin) --[[@as HuntsThreeSlice]]
	pin.pill:SetPoint("TOPLEFT")
	pin.pill:SetFrameLevel(pin:GetFrameLevel())
	pin.head = ns.ArtSprite(pin.pill, "Parts", "pin-glyph", "OVERLAY")
	ns.PlaceSprite(pin.head, pin, PIN_X, PIN_Y)
	pin.label = ns.BoardText(pin.pill, ns.BoardFonts().pin, LOOK.red)
	pin.label:SetPoint("TOPLEFT", PIN_WORDS_X, -6)
	pin.pinned = false
	pin:SetScript("OnClick", function(self)
		if self.huntID then
			ns.SetPinned(self.huntID, not self.pinned)
		end
	end)
	withTooltip(pin)
	return pin
end

-- Sets the pin toggle's words and pill to whether the Hunt is pinned.
---@param pin EntryPinView
---@param pinned boolean
local function setPin(pin, pinned)
	local L = ns.L
	pin.pinned = pinned
	pin.label:SetText(pinned and L.ENTRY_PINNED or L.ENTRY_PIN_WORD)
	local width = PIN_WORDS_X + math.ceil(pin.label:GetStringWidth()) + 12
	ns.SetThreeSlice(pin.pill, "Parts", "pill", width, PILL_CAP, "BACKGROUND")
	pin:SetWidth(width)
	pin:SetAlpha(pinned and 1 or 0.55)
	pin.tooltip = { pinned and L.ENTRY_UNPIN or L.ENTRY_PIN }
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
---@field rule Texture
---@field setLine FontString
---@field empty FontString
---@field shown string?   -- the Hunt it last drew
---@field showing integer? -- the board's showing it last drew in (ns.board:Showing())

---@param page Frame
---@return EntryView
local function newView(page)
	local fonts = ns.BoardFonts()
	local width = page:GetWidth()
	local function text(font, color, wrapWidth, spacing)
		local made = ns.BoardText(page, font, color)
		if wrapWidth then
			ns.BoardWrap(made, wrapWidth, spacing)
		end
		return made
	end
	local view = { page = page, chips = {}, diamonds = {}, thresholds = {}, whens = {} }
	view.back = CreateFrame("Button", nil, page) --[[@as EntryBackView]]
	view.back:SetSize(200, HAND_SIZE + 4)
	view.hand = ns.NewBoardHand(view.back, HAND_SIZE)
	view.hand:SetPoint("LEFT")
	view.back.label = ns.BoardText(view.back, fonts.pin, LOOK.red)
	view.back.label:SetPoint("LEFT", view.hand, "RIGHT", 4, 0)
	view.back.label:SetWidth(width - HAND_SIZE - 4)
	view.back.label:SetWordWrap(false)
	view.back:SetScript("OnClick", function(self)
		if self.set then
			ns.board:Open({ mode = "set", set = self.set })
		end
	end)
	local heading = width - HEADING_ROOM
	view.kicker = text(fonts.kicker, LOOK.kicker)
	view.kicker:SetWidth(heading)
	view.kicker:SetWordWrap(false)
	view.name = text(fonts.title, LOOK.title, heading, 2)
	view.target = text(fonts.small, LOOK.small, heading, 4)
	view.retired = text(fonts.hand, LOOK.red, heading, 2)
	view.seal = ns.NewBoardSeal(page, SEAL_SIZE)
	view.pin = newPin(page)
	view.window = text(fonts.handLarge, LOOK.hand, width, 2)
	view.conditions = text(fonts.small, LOOK.small, width, 4)
	view.bar = ns.NewBoardInkBar(page, BAR_WIDTH, width)
	view.ladderUpdating = text(fonts.hand, LOOK.note, width, 2)
	view.effort = text(fonts.hand, LOOK.ink, width, 2)
	view.odds = text(fonts.note, ns.BoardTint("7a5a30"), width, 4)
	view.rule = ns.BoardSolid(page, LOOK.rule, "ARTWORK")
	view.rule:ClearAllPoints()
	view.rule:SetSize(width, 1)
	view.setLine = text(fonts.small, LOOK.small, width, 4)
	view.empty = text(fonts.text, LOOK.note, width, 4)
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
		view.rule,
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

-- Lays out a text at the page's left `y` down, if it has words; returns the y below it, `after` further down.
---@param text FontString
---@param words string?
---@param y number
---@param after number?
---@return number
local function line(text, words, y, after)
	if not words then
		return y
	end
	text:SetText(words)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", 0, -y)
	text:Show()
	return y + text:GetStringHeight() + (after or 2)
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
		local chip = ns.BoardPooled(view.chips, i, function()
			return newChip(view.page)
		end)
		local chipWidth = setChip(chip, data, width)
		if x > 0 and x + chipWidth > width then
			x, y = 0, y + CHIP_STEP
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, -y)
		x = x + chipWidth + CHIP_GAP
	end
	return y + CHIP_HEIGHT
end

-- Lays out the tier ladder from `y` down (HNT-R64, HNT-R18): each tier's mark in its trim's ink, filled once
-- reached, its threshold in gilt and its date and zone (or "not yet" in italic), then the ink bar with its words; or
-- the updating line (HNT-R69). Returns the y below it.
---@param view EntryView
---@param ladder HuntEntryLadder
---@param y number
---@param same boolean the same Hunt's bar as at the view's last draw: a count that grew runs its ink on
---@param again boolean? laid again in this draw, tighter (draw): the bar keeps what the first lay set it running
---@return number
local function layLadder(view, ladder, y, same, again)
	if ladder.updating then
		return line(view.ladderUpdating, ladder.updating, y)
	end
	local page, fonts = view.page, ns.BoardFonts()
	for k, step in ipairs(ladder.tiers or {}) do
		local mark = ns.BoardPooled(view.diamonds, k, function()
			return ns.NewBoardDiamond(page, MARK_SIZE)
		end)
		mark:SetDiamond(ns.Trim(step.tier), step.reached)
		mark:ClearAllPoints()
		mark:SetPoint("TOPLEFT", MARK_X, -(y + 3.5))
		local threshold = ns.BoardPooled(view.thresholds, k, function()
			return ns.BoardText(page, fonts.tier, LOOK.title)
		end)
		threshold:SetText(tostring(step.threshold))
		inkText(threshold, step.reached and LOOK.title or LOOK.note)
		threshold:ClearAllPoints()
		threshold:SetPoint("TOPLEFT", THRESHOLD_X, -(y + 1))
		local when = ns.BoardPooled(view.whens, k, function()
			local made = ns.BoardText(page, fonts.small, LOOK.small)
			made:SetWidth(page:GetWidth() - WHEN_X)
			made:SetWordWrap(false)
			return made
		end)
		when:SetFontObject(step.when and fonts.small or fonts.note)
		when:SetText(step.when or ns.L.LADDER_NOT_YET)
		inkText(when, step.when and LOOK.small or LOOK.note)
		when:ClearAllPoints()
		when:SetPoint("TOPLEFT", WHEN_X, -(y + 2))
		y = y + STEP_HEIGHT
	end
	local bar = ladder.bar
	if bar then
		local grew = not again and same and bar.fill > view.bar.value
		if not again then
			view.bar:SetBar(bar.fill, bar.label, grew)
		end
		if grew and view.bar:IsVisible() and ns.MotionOn() then
			-- a catch is written in: its Casts line fades up with the count (MOTION.md › Counts and readings)
			ns.BoardSound("write")
			Pagle.StopMotion(view.effort)
			Pagle.Animate(view.effort, {
				{
					dur = 0.3,
					ease = Pagle.EASE.out,
					keys = { { 0, { 0.3 } }, { 1, { 1 } } },
					apply = function(v)
						view.effort:SetAlpha(v[1])
					end,
				},
			})
		end
		view.bar:ClearAllPoints()
		view.bar:SetPoint("TOPLEFT", 0, -(y + 6))
		view.bar:Show()
		y = y + 6 + 23
	end
	return y
end

-- Lays out the entry's foot from `y` down: the effort counter, the pointer to Stats and the set line under its rule;
-- returns the y under the last. `compact` (the entry would end past the page's foot, as a language's longer lines run
-- it, and the page cuts what passes it) leaves the pointer out and sets the counter small, in the note's italic.
---@param view EntryView
---@param entry HuntEntry
---@param y number
---@param compact boolean
---@return number
local function layFoot(view, entry, y, compact)
	local fonts = ns.BoardFonts()
	view.effort:SetFontObject(compact and fonts.note or fonts.hand)
	inkText(view.effort, LOOK.ink)
	y = line(view.effort, entry.effort.text, y, 3)
	view.odds:Hide()
	if not compact then
		y = line(view.odds, entry.effort.odds, y)
	end
	if entry.setLine then
		-- at the kit's place, or higher where its words wrap past the page's foot, but never over what is above it
		view.setLine:SetText(entry.setLine)
		local foot = view.page:GetHeight() - SET_WORDS_GAP - view.setLine:GetStringHeight()
		local ruleY = math.max(math.min(SET_RULE_Y, foot), y + 12)
		view.rule:ClearAllPoints()
		view.rule:SetPoint("TOPLEFT", 0, -ruleY)
		view.rule:Show()
		y = line(view.setLine, entry.setLine, ruleY + SET_WORDS_GAP, 0) -- its words' foot, on the page's at the most
	end
	return y
end

-- Lays out `entry` (logic/Entry.lua's HuntEntry) of Hunt `huntID` on its page from the top to the ladder; `tight`
-- keeps a long name to one line a size down, sets the window line a size down and the gaps between blocks closer.
-- Returns the y under the ladder.
---@param view EntryView
---@param entry HuntEntry
---@param huntID string
---@param same boolean
---@param again boolean laid again in this draw (layLadder)
---@param tight boolean
---@return number
local function layBody(view, entry, huntID, same, again, tight)
	hideAll(view)
	local width = view.page:GetWidth()
	local top = 0
	if entry.back then
		view.back.label:SetText(entry.back)
		view.back.set = entry.backSet
		view.back:ClearAllPoints()
		view.back:SetPoint("TOPLEFT", 0, 0)
		view.back:Show()
		top = HAND_SIZE + 8
	end
	view.seal:SetSeal(entry.seal.text, entry.seal.filled, entry.seal.lines)
	view.seal:ClearAllPoints()
	view.seal:SetPoint("CENTER", view.page, "TOPLEFT", width - SEAL_RIGHT, -(top + SEAL_DOWN))
	view.seal:Show()
	local kicker = entry.kicker and ns.BoardSmallCaps(entry.kicker)
	if kicker then
		view.kicker:SetText(kicker)
		ns.FitText(view.kicker, "print", 12, width - KICKER_ROOM, KICKER_FLOOR, nil, LOOK.kicker)
	end
	local y = line(view.kicker, kicker, top + KICKER_Y, 0)
	-- tight, a name that would wrap is set a size down at a time to keep to one line, to NAME_FLOOR
	view.name:SetFontObject(ns.BoardFonts().title)
	inkText(view.name, LOOK.title)
	view.name:SetWidth(width - HEADING_ROOM)
	if tight and entry.name then
		view.name:SetText(entry.name)
		ns.FitText(view.name, "print", 29, width - HEADING_ROOM, NAME_FLOOR, nil, LOOK.title)
	end
	y = line(view.name, entry.name, math.max(y, top + NAME_Y), 0)
	y = line(view.target, entry.target, y + 2)
	y = line(view.retired, entry.retiredLine, y)
	if entry.pin then
		setPin(view.pin, entry.pin.pinned)
		view.pin.huntID = huntID
		view.pin:ClearAllPoints()
		view.pin:SetPoint("TOPLEFT", 0, -(y + PILL_GAP))
		view.pin:Show()
		y = y + PILL_GAP + PILL_HEIGHT
	end
	local gap = tight and GAP_TIGHT or GAP
	y = math.max(y + gap, top + HEAD_ROOM)
	view.window:SetFontObject(tight and ns.BoardFonts().hand or ns.BoardFonts().handLarge)
	inkText(view.window, LOOK.hand)
	y = line(view.window, entry.window, y, 4)
	y = line(view.conditions, entry.conditions, y)
	y = layChips(view, entry.chips, y + gap, width) + (tight and CHIPS_FOOT_TIGHT or CHIPS_FOOT)
	return layLadder(view, entry.ladder, y, same, again) + gap
end

-- Draws `entry` of Hunt `huntID` on its page, top to bottom, as the kit lays it; where a language's longer lines run
-- it past the page's foot (the page's frame cuts what passes it, the set line first), a step tighter at a time until
-- it ends on the page: its foot compact (layFoot), then its body tight (layBody), then the conditions line kept to
-- fewer lines, the client ending it with an ellipsis (its zones are the chips' too, the rest in "+N more"'s tooltip).
---@param view EntryView
---@param entry HuntEntry
---@param huntID string
local function draw(view, entry, huntID)
	-- the same Hunt's ink bar, drawn last time too with the board open since, may run on; a Catch made while the board
	-- was closed draws settled
	local showing = ns.board:Showing()
	local same = view.shown == huntID and view.showing == showing and view.bar:IsShown()
	view.shown, view.showing = huntID, showing
	local height = view.page:GetHeight()
	view.conditions:SetMaxLines(0)
	if layFoot(view, entry, layBody(view, entry, huntID, same, false, false), false) <= height then
		return
	end
	if layFoot(view, entry, layBody(view, entry, huntID, same, true, false), true) <= height then
		return
	end
	local ends = layFoot(view, entry, layBody(view, entry, huntID, same, true, true), true)
	if ends <= height or not entry.conditions then
		return
	end
	local lines = math.floor(view.conditions:GetStringHeight() / CONDITIONS_LINE + 0.5)
	for most = lines - 1, 1, -1 do
		view.conditions:SetMaxLines(most)
		if layFoot(view, entry, layBody(view, entry, huntID, same, true, true), true) <= height then
			return
		end
	end
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
	-- a run selected on the Board shows its run's entry in place of a Hunt's (HNT-R161, HNT-R163)
	if place.mode == "board" and place.run and ns.DrawRunEntry(page, place.run) then
		hideAll(view)
		return
	end
	ns.HideRunEntry(page)
	local now = GetServerTime()
	local hunt, shown = shownAt(place, now)
	if not hunt then
		hideAll(view)
		local grouping = ns.groups:Grouping()
		local empty = place.mode == "board"
			and ns.EntryEmptyLine(grouping and #grouping.rows or 0, #ns.groups:Rows({ filtered = true }))
		line(view.empty, empty or nil, 0)
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
		now = ns.ViewNow(), -- the countdowns count from now, frozen while the grouping is paused (HNT-R43)
		snapshot = Pagle.GetConditions(),
		best = Pagle.GetAngler().bestBaseSkill,
		sources = ns.names,
	})
	draw(view, entry, hunt.id)
end

ns.board:RegisterPage("board", "right", render)
ns.board:RegisterPage("entry", "right", render)
ns.board:RegisterPage("retired", "right", render)
