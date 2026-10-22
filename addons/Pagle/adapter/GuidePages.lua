---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's own four guide pages on the client (core/onboarding.md › The steps): Welcome (ONB-R30, board 2), What's in
-- the box (ONB-R31, board 3), Moments (ONB-R34, ONB-R35, board 6) and Off you go (ONB-R38, board 9), each a build that
-- draws its two pages once and an onShow that re-reads what can change while the guide is closed (the menu's labels,
-- the Announcement settings, the samples' toast style, the First evening list's ticks). What they say and set is
-- logic/GuidePages.lua's. Places are the kit's (prototypes/onboarding-kit, PagleArtGuide's Guide.lua): UI units from
-- a page's top left, y down, a text's y the top of its line box `lh` tall, as the kit's P.T sets it. The samples are
-- the real display frames standing still (adapter/Announcements.lua's ns.DrawStillAnnouncement) with /pagle dev
-- preview's sample moments; the menu is drawn from the real menu's entries (logic/Menu.lua's ns.CoreCompartmentMenu).
-- adapter/Guide.lua hands ns.GUIDE_CORE_STEPS to the guide, which looks each step's drawing up as it first draws.

local L = ns.L
local rgb = ns.Rgb

-- A page's text column: from 30, 382 wide (the kit's W).
local X, W = 30, 382

--- Colours the kit gives outside the guide's inks (ns.GUIDE_INKS): the menu's, the rules', the list's.
local HUES = {
	menuHead = rgb("FFD100"),
	menuRow = rgb("F2F2F2"),
	menuRule = rgb("3A3A3A"),
	rule = rgb("C4A874"),
	item = rgb("2E1C0C"),
	itemDone = rgb("6A5A48"),
	strike = rgb("2A6A2A"),
	window = rgb("0F0C09"),
}

-- Recolours a font string in one of HUES.
---@param fontString FontString
---@param name string
local function hue(fontString, name)
	local color = HUES[name]
	fontString:SetTextColor(color[1], color[2], color[3])
end

--- A text on `parent` as the kit sets it (its P.T): in `face` at `size`, in ink `ink`, its line box `lh` tall with its
--- top at `x`, `y`; with `right` or `center`, `x` is its right edge or its middle. Wrapped text spaces its lines by
--- the line box.
---@class PagleGuidePageText: PagleGuideTextOptions
---@field right? boolean
---@field center? boolean

---@param parent Frame
---@param face PagleArtFace
---@param size number
---@param ink string
---@param words string
---@param x number
---@param y number
---@param lh number?
---@param options PagleGuidePageText?
---@return FontString
local function text(parent, face, size, ink, words, x, y, lh, options)
	options = options or {}
	lh = lh or size
	if options.wrap and not options.spacing then
		options.spacing = math.max(0, lh - size)
	end
	if options.right then
		options.justify = "RIGHT"
	elseif options.center then
		options.justify = "CENTER"
	end
	local fontString = ns.GuideText(parent, face, size, ink, words, options)
	local top = -(y + (lh - size) / 2)
	fontString:ClearAllPoints()
	if options.right then
		fontString:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, top)
	elseif options.center then
		fontString:SetPoint("TOP", parent, "TOPLEFT", x, top)
	else
		fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, top)
	end
	return fontString
end

-- A printed paragraph across the column (the kit's body), and its small print and italic note.
---@param page Frame
---@param words string
---@param y number
---@return FontString
local function body(page, words, y)
	return text(page, "print", 15, "body", words, X, y, 20.7, { wrap = true, width = W })
end
---@param page Frame
---@param words string
---@param y number
---@return FontString
local function small(page, words, y)
	return text(page, "print", 13.5, "small", words, X, y, 18.225, { wrap = true, width = W })
end
---@param page Frame
---@param words string
---@param y number
---@return FontString
local function note(page, words, y)
	return text(page, "italic", 13, "note", words, X, y, 17.55, { wrap = true, width = W })
end

-- A rule of `width` at `x`, `y` on `parent`, in HUES[`name`] at `alpha`.
---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param name string
---@param alpha number
---@return Texture
local function rule(parent, x, y, width, name, alpha)
	local line = parent:CreateTexture(nil, "ARTWORK")
	local color = HUES[name]
	line:SetColorTexture(color[1], color[2], color[3], alpha)
	line:SetSize(width, 1)
	ns.GuideAt(line, parent, x, y)
	return line
end

-- A part of the guide's atlas on `parent`, its drawn element's top left at `x`, `y`.
---@param parent Frame
---@param sprite string
---@param x number
---@param y number
---@return PagleSprite
local function part(parent, sprite, x, y)
	local made = ns.GuidePart(parent, sprite)
	ns.PlaceSprite(made, parent, x, y)
	return made
end

-- ---------------------------------------------------------------------------------------------------- the samples

--- A sample window on a page (the kit's framed sample): a dark well `w` x `h` at `x`, `y`, clipping what it holds,
--- under the "win" rim, holding one Announcement of `form` drawn standing still.
---@class PagleGuideSampleWindow: Frame
---@field form "toast"|"nod"|"banner"
---@field sample PagleAnnouncementFrame?

-- How much of a banner the window shows, in the banner's own units (the kit's cut of the canvas's banner): its middle,
-- seal, words and labels.
local BANNER_CUT = { width = 695, height = 290 }

---@param page Frame
---@param form "toast"|"nod"|"banner"
---@param x number
---@param y number
---@param w number
---@param h number
---@return PagleGuideSampleWindow
local function sampleWindow(page, form, x, y, w, h)
	local window = CreateFrame("Frame", nil, page) --[[@as PagleGuideSampleWindow]]
	window:SetSize(w, h)
	ns.GuideAt(window, page, x, y)
	window:SetClipsChildren(true)
	local well = window:CreateTexture(nil, "BACKGROUND")
	well:SetAllPoints()
	well:SetColorTexture(HUES.window[1], HUES.window[2], HUES.window[3], 1)
	-- the rim over the sample: its own frame, above every level the sample's layers take
	local rim = CreateFrame("Frame", nil, window)
	rim:SetAllPoints()
	rim:SetFrameLevel(window:GetFrameLevel() + 12)
	ns.NewNineSlice(rim, "GuideParts", "win", 6, "OVERLAY")
	window.form = form
	return window
end

--- Draws a window's sample: /pagle dev preview's moment of its form (logic/Dev.lua) in the real frame, standing still
--- (ONB-R34), in the equipped toast style, scaled to fit the window whole (a banner, its middle) and centred in it.
---@param window PagleGuideSampleWindow
---@return PagleAnnouncementFrame
local function drawSample(window)
	local form = window.form
	local announcement = ns.DevPreviewAnnouncement(form, L.GUIDE_MOMENTS_SAMPLE_TEXT) --[[@as PagleAnnouncement]]
	local frame = ns.DrawStillAnnouncement(window, form, announcement)
	local w, h = window:GetWidth() - 8, window:GetHeight() - 4
	local width, height = frame:GetWidth(), frame:GetHeight()
	if form == "banner" then
		width, height = BANNER_CUT.width, BANNER_CUT.height
	end
	local scale = math.min(w / width, h / height)
	frame:SetScale(scale)
	frame:ClearAllPoints()
	if form == "banner" then
		frame:SetPoint("TOP", window, "TOP", 0, -((window:GetHeight() - height * scale) / 2) / scale)
	else
		frame:SetPoint("CENTER", window, "CENTER", 0, 0)
	end
	window.sample = frame
	return frame
end

-- ---------------------------------------------------------------------------------------------------- Welcome

-- The letter's paragraphs' places, and the three promises' first (each 85.8 under the last).
local LETTER_Y = { 87.4, 183.6, 279.7 }
local PROMISE_Y, PROMISE_STEP = 89.3, 85.8

--- Welcome (ONB-R30, board 2): the letter in the hand, signed, with the foot line; the three promises beside their
--- wax discs, the third naming the roster's size. Core's foot carries "I’ll find my own way" and "Show me around »".
---@type PagleCoreGuideStepDrawing
local WELCOME = {
	build = function(left, right)
		ns.NewGuideKicker(left, L.GUIDE_WELCOME_KICKER)
		ns.NewGuideTitle(left, L.GUIDE_WELCOME_TITLE)
		for i, words in ipairs(L.GUIDE_WELCOME_LETTER) do
			text(left, "hand", 23, "hand", words, X, LETTER_Y[i], 28.06, { wrap = true, width = W })
		end
		text(left, "handBold", 30, "body", L.GUIDE_WELCOME_SIGNED, X, 345.8, 30)
		text(left, "italic", 13, "note", L.GUIDE_WELCOME_FOOT, X, 505.8, 18.2)

		ns.NewGuideKicker(right, L.GUIDE_WELCOME_RIGHT_KICKER)
		ns.NewGuideTitle(right, L.GUIDE_WELCOME_RIGHT_TITLE, 25)
		for i, promise in ipairs(L.GUIDE_WELCOME_PROMISES) do
			local y = PROMISE_Y + (i - 1) * PROMISE_STEP
			part(right, "disc", X, y)
			text(right, "gilt", 15, "wax", promise[1], 53, y + 13.5, 19, { center = true, shadow = true })
			text(right, "print", 19, "title", promise[2], 90, y + 4, 21.85)
			local line = promise[3] or ns.GuidePartsLine(#ns.MODULE_ROSTER)
			text(right, "print", 14.5, "small", line, 90, y + 27.8, 20.01, { wrap = true, width = 322 })
		end
	end,
}

-- ---------------------------------------------------------------------------------------------------- What's in the box

--- The drawing of the Pagle menu (CORE-R50): its header, then a row per entry as the real menu reads now.
---@class PagleGuideMenuDrawing: Frame
---@field rows FontString[]        -- every row's words made, reused as the menu is drawn again
---@field balance FontString       -- the Curio Shop's balance, at the row's right
---@field coin PagleSprite
---@field highlight Texture        -- the first row's wash, which the margin note points at
---@field separator Texture

-- The menu's rows: 23 units each from 31 down, a rule 4 under the Modules' entries taking 9.
local MENU_TOP, MENU_ROW, MENU_GAP, MENU_WIDTH = 31, 23, 9, 214

---@param left Frame
---@return PagleGuideMenuDrawing
local function newMenu(left)
	local menu = CreateFrame("Frame", nil, left) --[[@as PagleGuideMenuDrawing]]
	menu:SetSize(MENU_WIDTH, 230)
	ns.GuideAt(menu, left, 56, 169.5)
	menu:SetFrameLevel(left:GetFrameLevel() + 2)
	ns.NewNineSlice(menu, "GuideParts", "menu", 8)
	hue(text(menu, "gilt", 13, "title", L.GUIDE_BOX_MENU, 14, 12, 13), "menuHead")
	local highlight = menu:CreateTexture(nil, "ARTWORK")
	highlight:SetColorTexture(1, 1, 1, 1)
	highlight:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0.22), CreateColor(1, 0.82, 0, 0))
	highlight:SetSize(MENU_WIDTH, MENU_ROW)
	ns.GuideAt(highlight, menu, 0, MENU_TOP)
	menu.highlight = highlight
	menu.separator = rule(menu, 10, 0, 194, "menuRule", 1)
	menu.balance = text(menu, "gilt", 13, "title", "", 183, 0, 13, { right = true })
	hue(menu.balance, "menuRow")
	menu.coin = ns.GuidePart(menu, "coin")
	menu.rows = {}
	return menu
end

-- Row `i`'s words on `menu`, `label` at `y`: made the first time, reused after.
---@param menu PagleGuideMenuDrawing
---@param i integer
---@param label string
---@param y number
local function menuRow(menu, i, label, y)
	local row = menu.rows[i]
	if not row then
		row = text(menu, "gilt", 13, "title", "", 14, 0, 13)
		hue(row, "menuRow")
		menu.rows[i] = row
	end
	row:SetText(label)
	ns.GuideAt(row, menu, 14, y + 5)
	row:Show()
end

--- Draws the menu as the real one reads now (CORE-R50, CORE-R52): each registered Module's views and entries, a rule,
--- "Curio Shop" with the balance and a coin, "Help chart the waters" (with its count) and "Settings". The first row
--- has the wash under it, as the pointer's row on the canvas.
---@param menu PagleGuideMenuDrawing
local function drawMenu(menu)
	local entries =
		ns.CoreCompartmentMenu(Pagle, ns.coreSubcommands, ns.Modules:Modules(), BreakUpLargeNumbers, securecallfunction)
	local core = #entries - 3
	local y, n = MENU_TOP, 0
	for i = 1, core do
		n = n + 1
		menuRow(menu, n, entries[i].label, y)
		y = y + MENU_ROW
	end
	menu.separator:SetShown(core > 0)
	if core > 0 then
		ns.GuideAt(menu.separator, menu, 10, y + 4)
		y = y + MENU_GAP
	end
	n = n + 1
	menuRow(menu, n, L.GUIDE_BOX_SHOP, y)
	menu.balance:SetText(BreakUpLargeNumbers(Pagle.GetBalance().balance))
	menu.balance:ClearAllPoints()
	menu.balance:SetPoint("TOPRIGHT", menu, "TOPLEFT", 183, -(y + 5))
	ns.PlaceSprite(menu.coin, menu, 189, y + 6)
	y = y + MENU_ROW
	for i = core + 2, #entries do
		n = n + 1
		menuRow(menu, n, entries[i].label, y)
		y = y + MENU_ROW
	end
	for i = n + 1, #menu.rows do
		menu.rows[i]:Hide()
	end
	menu:SetHeight(y + 6)
end

-- The right page's rows: from 55, 73.98 apart, a rule 66 under each but the last.
local ROW_TOP, ROW_STEP = 55, 73.98

--- One row as drawn: its icon, which sprite that is.
---@class PagleGuideBoxRowView
---@field icon PagleSprite
---@field sprite string

--- A preset's card as drawn: the kit's choice card with its pencilled line.
---@class PagleGuidePresetCard: PagleGuideChoiceCard
---@field what FontString
---@field preset string

--- The First evening list as it will look (ONB-R38, board 9): the tracker paper, its header and count, and a line per
--- item, ticked once done.
---@class PagleGuideEveningView: Frame
---@field count FontString
---@field rows { id: string, done: boolean, box: PagleSprite, tick: PagleSprite, words: FontString, strike: Texture }[]

--- What Core's pages drew, for their onShow to redraw: made at each step's first showing, one guide a session.
---@class PagleGuidePages
---@field menu PagleGuideMenuDrawing?           -- What's in the box's drawing of the Pagle menu
---@field rows PagleGuideBoxRowView[]?          -- What's in the box's rows, in order
---@field samples table<string, PagleAnnouncementFrame> -- Moments' still samples, by form
---@field windows PagleGuideSampleWindow[]      -- Moments' sample windows
---@field cards PagleGuidePresetCard[]?         -- Moments' preset cards, in ONB-R35's order
---@field ownMix FontString?                    -- "Your own mix, kept as it is."
---@field presetNote FontString?                -- the note under the cards
---@field presetPage Frame?                     -- the page they're on
---@field offWindow PagleGuideSampleWindow?     -- Off you go's sample Nod's window
---@field offSample PagleAnnouncementFrame?
---@field evening PagleGuideEveningView?        -- the First evening list as it will look
---@field offButton PagleGuideButton?           -- Off to the water
local pages = { samples = {}, windows = {} }
ns.guidePages = pages

--- What's in the box (ONB-R31, board 3): the paragraph and the drawing of the Pagle menu with its note on the left;
--- on the right, a row per registered Module in def.order, then the Curio Shop's (ONB-R91), and ONB-R103's line when
--- every Module is off. The menu is drawn again each time the step shows, so it reads as the real menu does then.
---@type PagleCoreGuideStepDrawing
local BOX = {
	build = function(left, right, nav)
		ns.NewGuideKicker(left, L.GUIDE_BOX_KICKER)
		ns.NewGuideTitle(left, L.GUIDE_BOX_TITLE)
		body(left, L.GUIDE_BOX_TEXT, 85.4)
		local menu = newMenu(left)
		drawMenu(menu)
		pages.menu = menu
		nav.Note(left, L.GUIDE_BOX_MENU_NOTE, 292, 196, 136, menu.highlight)

		local modules = ns.Modules:Modules()
		ns.NewGuideKicker(right, ns.GuideBoxKicker(#modules))
		local rows = ns.GuideBoxRows(modules)
		pages.rows = {}
		for i, row in ipairs(rows) do
			local y = ROW_TOP + (i - 1) * ROW_STEP
			pages.rows[i] = { icon = part(right, row.sprite, X, y), sprite = row.sprite }
			text(right, "print", 17, "title", row.title, 79, y, 19.55)
			if row.blurb then
				text(right, "print", 13.5, "small", row.blurb, 79, y + 21.5, 18.225, { wrap = true, width = 333 })
			end
			if i < #rows then
				rule(right, X, y + 66, W, "rule", 0.6)
			end
		end
		if #modules == 0 then
			note(right, L.GUIDE_BOX_NONE, ROW_TOP + ROW_STEP)
		end
	end,
	onShow = function()
		if pages.menu then
			drawMenu(pages.menu)
		end
	end,
}

-- ---------------------------------------------------------------------------------------------------- Moments

-- The samples' windows and their names' places (board 6): x, y, w, h, and the name's y.
local SAMPLES = {
	{ form = "nod", x = X, y = 137.6, w = 214, h = 30, name = 125.9 },
	{ form = "toast", x = X, y = 189.3, w = 214, h = 62, name = 193.6 },
	{ form = "banner", x = X, y = 261.3, w = 214, h = 104, name = 286.6 },
}

-- The preset cards' places and heights, and how many lines each card's italic line takes.
local CARDS = {
	lively = { y = 81.3, h = 83.4, lines = 1 },
	quieter = { y = 172.6, h = 101.6, lines = 2 },
	cozy = { y = 282.2, h = 101.6, lines = 2 },
}
-- "Your own mix" under the cards, and the note under it, which steps down when it shows.
local OWN_Y, NOTE_Y, NOTE_Y_OWN = 391, 397.8, 418

-- Chooses the card the settings match (ONB-R35), or none, with Your own mix in its place.
local function choose()
	local cards, page = pages.cards, pages.presetPage
	if not (cards and page and pages.ownMix and pages.presetNote) then
		return
	end
	local chosen = ns.GuidePresetOf(ns.db.profile.announcements)
	for _, card in ipairs(cards) do
		card:SetChosen(card.preset == chosen)
	end
	pages.ownMix:SetShown(chosen == nil)
	-- the note's line box is 17.55 tall at 13, as note() sets it
	ns.GuideAt(pages.presetNote, page, X, (chosen == nil and NOTE_Y_OWN or NOTE_Y) + (17.55 - 13) / 2)
end

--- Moments (ONB-R34, ONB-R35, board 6): on the left, a Nod, a toast and a banner drawn by the real display frames,
--- standing still, each named, and the budget paragraph; on the right, the three presets as choice cards, the one the
--- settings match chosen (else "Your own mix, kept as it is."), and the note. Each time it shows, the chosen card
--- follows the settings as they stand and the samples the toast style equipped.
---@type PagleCoreGuideStepDrawing
local MOMENTS = {
	build = function(left, right, nav)
		ns.NewGuideKicker(left, L.GUIDE_MOMENTS_KICKER)
		ns.NewGuideTitle(left, L.GUIDE_MOMENTS_TITLE)
		small(left, L.GUIDE_MOMENTS_TEXT, 79.4)
		for _, at in ipairs(SAMPLES) do
			local window = sampleWindow(left, at.form, at.x, at.y, at.w, at.h)
			pages.windows[#pages.windows + 1] = window
			pages.samples[at.form] = drawSample(window)
			local words = L.GUIDE_MOMENTS_SAMPLES[at.form]
			text(left, "sc", 16, "title", words[1], 256, at.name, 17.6)
			text(left, "italic", 13, "line", words[2], 256, at.name + 19.6, 16.9, { wrap = true, width = 156 })
		end
		local lively = ns.GUIDE_PRESETS[1].budget --[[@as table]]
		small(left, L.GUIDE_MOMENTS_BUDGET:format(lively.count, lively.window / 60), 377.3)

		ns.NewGuideKicker(right, L.GUIDE_MOMENTS_RIGHT_KICKER)
		ns.NewGuideTitle(right, L.GUIDE_MOMENTS_RIGHT_TITLE, 25)
		local cards = {}
		for _, preset in ipairs(ns.GUIDE_PRESETS) do
			local words, at = L.GUIDE_PRESETS[preset.id], CARDS[preset.id]
			local card = nav.ChoiceCard(right, words[1], words[2], words[3]) --[[@as PagleGuidePresetCard]]
			card:SetSize(W, at.h)
			ns.GuideAt(card, right, X, at.y)
			card.preset = preset.id
			local what = ns.GuidePresetWhat(preset)
			card.what = text(card, "hand", 16, "hand", what, 37, 32.5 + at.lines * 18.2 + 4, 17.6)
			card:HookScript("OnClick", function()
				ns.ApplyGuidePreset(ns.db.profile.announcements, preset.id)
				choose()
			end)
			cards[#cards + 1] = card
		end
		pages.cards, pages.presetPage = cards, right
		pages.ownMix = text(right, "hand", 17, "hand", L.GUIDE_PRESET_OWN, X, OWN_Y, 20)
		pages.presetNote = note(right, L.GUIDE_MOMENTS_NOTE, NOTE_Y)
		choose()
	end,
	onShow = function()
		choose()
		for _, window in ipairs(pages.windows) do
			drawSample(window)
		end
	end,
}

-- ---------------------------------------------------------------------------------------------------- Off you go

-- The list's width, its rows' heights with and without a hint, and where its first row starts.
local LIST_WIDTH, ROW_HINTED, ROW_PLAIN, LIST_TOP = 274, 34.6, 21.6, 30

---@param right Frame
---@return PagleGuideEveningView
local function newEvening(right)
	local list = CreateFrame("Frame", nil, right) --[[@as PagleGuideEveningView]]
	ns.GuideAt(list, right, 84, 124)
	list:SetFrameLevel(right:GetFrameLevel() + 2)
	text(list, "sc", 15, "title", L.GUIDE_EVENING_TITLE, 24, 8, 20)
	list.count = text(list, "italic", 12.5, "kicker", "", LIST_WIDTH - 8, 10, 17, { right = true })
	list.rows = {}
	local y = LIST_TOP
	for _, item in ipairs(ns.GuideEveningPreview(ns.Modules:Modules())) do
		local words = text(list, "print", 13.5, "body", item.text, 43, y + 2, 17.6)
		local strike = rule(list, 43, y + 11, math.max(1, math.ceil(words:GetStringWidth())), "strike", 0.6)
		strike:SetDrawLayer("OVERLAY")
		list.rows[#list.rows + 1] = {
			id = item.id,
			done = false,
			box = part(list, "li-box", 24, y + 4),
			tick = part(list, "li-done", 24, y + 4),
			words = words,
			strike = strike,
		}
		if item.hint then
			text(list, "italic", 12.5, "small", item.hint, 43, y + 19.6, 16.3)
		end
		y = y + (item.hint and ROW_HINTED or ROW_PLAIN)
	end
	list:SetSize(LIST_WIDTH, y + 12)
	ns.NewNineSlice(list, "GuideParts", "trk", 8)
	return list
end

-- Ticks each item done so far (ONB-R61: one done before the list docks shows ticked) and counts them.
---@param list PagleGuideEveningView
local function tickEvening(list)
	local onboarding = ns.onboarding
	local known = onboarding ~= nil and onboarding:State() ~= nil
	local done = 0
	for _, row in ipairs(list.rows) do
		row.done = known and onboarding:IsEveningItemDone(row.id)
		done = done + (row.done and 1 or 0)
		row.box:SetShown(not row.done)
		row.tick:SetShown(row.done)
		row.strike:SetShown(row.done)
		hue(row.words, row.done and "itemDone" or "item")
	end
	list.count:SetText(L.GUIDE_EVENING_COUNT:format(done, #list.rows))
end

--- Off you go (ONB-R38, board 9): the paragraph, the sample Nod with margin note 1, the margin-notes paragraph naming
--- the windows with First looks; on the right, the First evening list as it will look and Off to the water, which
--- finishes the guide (guideDone, closing it, then the hook that docks the list, #328).
---@type PagleCoreGuideStepDrawing
local OFF = {
	build = function(left, right, nav)
		ns.NewGuideKicker(left, L.GUIDE_OFF_KICKER)
		ns.NewGuideTitle(left, L.GUIDE_OFF_TITLE)
		body(left, L.GUIDE_OFF_TEXT, 85.4)
		local window = sampleWindow(left, "nod", 40, 191.5, 214, 30)
		pages.offWindow, pages.offSample = window, drawSample(window)
		nav.Note(left, L.GUIDE_OFF_NOD_NOTE, 226, 222, 216, window, 1)
		small(left, ns.GuideLooksLine(ns.GuideLookWindows(ns.Modules:Modules(), ns.firstLooks:List())), 317.5)

		ns.NewGuideKicker(right, L.GUIDE_OFF_RIGHT_KICKER)
		ns.NewGuideTitle(right, L.GUIDE_OFF_RIGHT_TITLE, 25)
		small(right, L.GUIDE_OFF_LIST_TEXT, 73.3)
		local evening = newEvening(right)
		pages.evening = evening
		tickEvening(evening)
		-- Off to the water (ONB-R38): the kit's big leather button, and the line under it
		local button = ns.NewGuideButton(right, L.GUIDE_OFF, nav.Finish, W, 46, 18)
		ns.GuideAt(button, right, X, 359.7)
		pages.offButton = button
		text(right, "italic", 13, "note", L.GUIDE_OFF_AGAIN, 221, 415.7, 17.55, { center = true })
	end,
	onShow = function()
		if pages.evening then
			tickEvening(pages.evening)
		end
		if pages.offWindow then
			pages.offSample = drawSample(pages.offWindow)
		end
	end,
}

--- What draws each of Core's own steps, by id (logic/Guide.lua's ns.CoreGuideSteps), looked up as each step first
--- draws (ONB-R30, ONB-R31, ONB-R34, ONB-R38).
---@type table<string, PagleCoreGuideStepDrawing>
ns.GUIDE_CORE_STEPS = { welcome = WELCOME, box = BOX, moments = MOMENTS, off = OFF }
