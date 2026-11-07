---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The onboarding art kit on the client (core/onboarding.md › UI): the guide's inks, type set at the kit's sizes, and
-- the widgets every onboarding piece draws with, from the GuideParts atlas (data/GuideArt.lua) through Core's art
-- helpers (adapter/Art.lua: ns.ArtSprite, ns.SetThreeSlice, ns.NewNineSlice, ns.ArtFaceFont): a page's kicker and
-- title, the leather button, the foot's skip link and « back, a choice card, an illustrative note and a part of the
-- atlas (the binding field is adapter/GuideBindingField.lua's; the step ribbons are the book shell's, GuideBook.lua). Positions are the onboarding
-- kit's (prototypes/onboarding-kit, PagleArtGuide's GuideKit.lua and Guide.lua): the canvas's CSS pixels, UI units,
-- from a page's top left, y down. A step's build reaches the widgets through its nav (logic/Guide.lua's
-- ns.NewGuideNav); later onboarding pieces (the Letter, Margin notes, First looks, the First evening list) call them
-- here.

local rgb = ns.Rgb

--- The guide's inks, by role, from the kit's guide.css (PagleArtGuide's Kit.lua, LedgerKit.lua and GuideKit.lua).
---@type table<string, number[]>
ns.GUIDE_INKS = {
	kicker = rgb("8A5A2A"), -- the small-caps kicker over a title
	title = rgb("3E220C"), -- titles, a choice card's title
	body = rgb("3A2614"), -- printed paragraphs
	small = rgb("5A4028"), -- small print
	note = rgb("7A5A30"), -- italic notes, the skip link
	line = rgb("6A4A28"), -- a choice card's italic line, captions
	hand = rgb("23407A"), -- the Angler's pencil (notes, the Letter)
	red = rgb("9A2A1A"), -- the red pencil: a note's key term and badge, a link under the mouse
	green = rgb("2A6A2A"), -- a pencilled tag ("the usual"), "Bound"
	brown = rgb("7A3A10"), -- « back
	wax = rgb("F4DFA8"), -- the leather button's words
	crumb = rgb("E8C96A"), -- a First look coach bar's title
	count = rgb("C9B27A"), -- its count and "done"
}
local INKS = ns.GUIDE_INKS

--- How a font string is laid: wrapped to `width` (with `spacing` between lines, the kit's line height less the size),
--- justified, with a shadow (on leather), on a layer.
---@class PagleGuideTextOptions
---@field wrap? boolean
---@field width? number
---@field spacing? number
---@field justify? "LEFT"|"CENTER"|"RIGHT"
---@field shadow? boolean
---@field layer? DrawLayer

--- A font string on `parent` in the art's `face` at `size`, in ink `ink` (a role of ns.GUIDE_INKS), reading `text`.
---@param parent Frame
---@param face PagleArtFace
---@param size number
---@param ink string
---@param text string?
---@param options PagleGuideTextOptions?
---@return FontString
function ns.GuideText(parent, face, size, ink, text, options)
	options = options or {}
	local fontString = parent:CreateFontString(nil, options.layer or "OVERLAY")
	fontString:SetFontObject(ns.ArtFaceFont(face, size, options.shadow))
	local color = INKS[ink]
	fontString:SetTextColor(color[1], color[2], color[3])
	fontString:SetJustifyH(options.justify or "LEFT")
	fontString:SetWordWrap(options.wrap == true)
	if options.width then
		fontString:SetWidth(options.width)
	end
	if options.spacing then
		fontString:SetSpacing(options.spacing)
	end
	fontString:SetText(text or "")
	return fontString
end

-- How small a fitted line may be set, as a share of its size: past that the client cuts it short with "...".
local FIT_FLOOR = 0.75

--- Holds a one-line `fontString` in the art's `face` at `size` to `width` (its text already set): measured unbounded,
--- a text too wide is set smaller, in half-unit steps, down to FIT_FLOOR of its size, and its width is then held to
--- `width`, so one still too wide is cut short by the client's "..." instead of running past it. Its ink is set again
--- (`ink`, a role of ns.GUIDE_INKS), as a new font can bring its own. Returns the size it is set at.
---@param fontString FontString
---@param face PagleArtFace
---@param size number
---@param ink string
---@param width number
---@param shadow boolean?
---@return number
function ns.FitGuideText(fontString, face, size, ink, width, shadow)
	fontString:SetWidth(0)
	fontString:SetFontObject(ns.ArtFaceFont(face, size, shadow))
	local natural = fontString:GetStringWidth()
	local at = size
	if natural > width then
		local floor = math.ceil(size * FIT_FLOOR * 2) / 2
		at = math.max(floor, math.floor(size * width / natural * 2) / 2)
		fontString:SetFontObject(ns.ArtFaceFont(face, at, shadow))
	end
	local color = INKS[ink]
	fontString:SetTextColor(color[1], color[2], color[3])
	fontString:SetWidth(width)
	return at
end

--- Puts `region`'s top left `x`, `y` from `relativeTo`'s top left (y grows downward), the kit's P.At.
---@param region Region
---@param relativeTo Region
---@param x number
---@param y number
function ns.GuideAt(region, relativeTo, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, -y)
end

-- A page's text column: from 30 to 412 on a 442-unit page (the kit's W).
local COLUMN_X, COLUMN_WIDTH = 30, 382
-- The least room between the foot's skip link and Next ».
local FOOT_GAP = 16

--- A page's kicker: the small-caps line over its title, at the kit's place (ONB-R30's "A letter, left on the dock").
---@param page Frame
---@param text string
---@return FontString
function ns.NewGuideKicker(page, text)
	local kicker = page:CreateFontString(nil, "OVERLAY")
	kicker:SetFontObject(ns.ART_SMALL_CAPS)
	kicker:SetJustifyH("LEFT")
	kicker:SetWordWrap(false)
	kicker:SetText(text)
	-- held to the column: a longer one is cut short, never into the spine
	kicker:SetWidth(COLUMN_WIDTH)
	ns.GuideAt(kicker, page, COLUMN_X, 24)
	return kicker
end

--- A page's title, under its kicker: IM Fell English at `size` (29, the right page's 25), on one line across the
--- column, set smaller when it is longer (ns.FitGuideText), so it never runs into the spine or off the page.
---@param page Frame
---@param text string
---@param size number?
---@return FontString
function ns.NewGuideTitle(page, text, size)
	size = size or 29
	local title = ns.GuideText(page, "print", size, "title", text)
	local at = ns.FitGuideText(title, "print", size, "title", COLUMN_WIDTH)
	-- the kit's line box is 1.05 of the size; the text sits in its middle, a smaller one too
	ns.GuideAt(title, page, COLUMN_X, 41 + size * 0.025 + (size - at) / 2)
	return title
end

--- The guide's sounds (the kit's SOUND.md): sound kit ids on the SFX channel, and whether each goes with the motion
--- (played only while things move). The book's own (open, close, the page turn) are the shell's (BOOK-R4, BOOK-R31).
---@type table<string, { id: integer, motion: boolean }>
ns.GUIDE_SOUNDS = {
	click = { id = 852, motion = false }, -- IG_MAINMENU_OPTION: a button, a skip link
	check = { id = 856, motion = false }, -- IG_MAINMENU_OPTION_CHECKBOX_ON: a choice card picked
	uncheck = { id = 857, motion = false }, -- IG_MAINMENU_OPTION_CHECKBOX_OFF
	noteIn = { id = 827, motion = false }, -- IG_CHAT_SCROLL_DOWN: a Margin note, or a First look's set, appears
}

--- Plays the guide's sound `name` on the SFX channel; one that goes with the motion only while things move.
---@param name string
function ns.GuideSound(name)
	local sound = assert(ns.GUIDE_SOUNDS[name], "the guide has no sound " .. tostring(name))
	if sound.motion and not Pagle.IsAnimationsOn() then
		return
	end
	PlaySound(sound.id, "SFX")
end

--- The leather button (the kit's LButton): three-sliced leather with its words in gilt, warmer under the mouse.
---@class PagleGuideButton: Button
---@field rest PagleNineSlice
---@field hover PagleNineSlice
---@field label FontString

--- A leather button on `parent`, `width` wide (its words' width and 36 when nil) and `height` tall (34), its words in
--- Marcellus at `size` (15). Its leather follows its size. Clicking it plays `click` and calls `onClick`.
---@param parent Frame
---@param text string
---@param onClick fun()
---@param width number?
---@param height number?
---@param size number?
---@return PagleGuideButton
function ns.NewGuideButton(parent, text, onClick, width, height, size)
	local button = CreateFrame("Button", nil, parent) --[[@as PagleGuideButton]]
	-- the leather under the words, on the button itself, its rounded ends kept
	button.rest = ns.NewNineSlice(button, "GuideParts", "button", { 10, 8 })
	button.hover = ns.NewNineSlice(button, "GuideParts", "button-hover", { 10, 8 })
	button.label = ns.GuideText(button, "gilt", size or 15, "wax", text, { shadow = true, justify = "CENTER" })
	button:SetSize(width or math.ceil(button.label:GetStringWidth()) + 36, height or 34)
	button.hover:Hide()
	button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetScript("OnEnter", function(self)
		self.hover:Show()
		self.rest:Hide()
	end)
	button:SetScript("OnLeave", function(self)
		self.hover:Hide()
		self.rest:Show()
	end)
	button:SetScript("OnClick", function()
		ns.GuideSound("click")
		onClick()
	end)
	return button
end

--- A link in italic over a dotted rule, red under the mouse (the foot's skip link): `click` and `onClick`.
---@class PagleGuideLink: Button
---@field label FontString
---@field dots Texture[]

--- Held to `room` when given (ns.FitGuideText), its dots as long as its words.
---@param parent Frame
---@param text string
---@param onClick fun()
---@param room number?
---@return PagleGuideLink
function ns.NewGuideLink(parent, text, onClick, room)
	local link = CreateFrame("Button", nil, parent) --[[@as PagleGuideLink]]
	link.label = ns.GuideText(link, "italic", 14, "note", text)
	link.label:SetPoint("TOPLEFT", 0, -2.5)
	local width = math.ceil(link.label:GetStringWidth())
	if room and width > room then
		ns.FitGuideText(link.label, "italic", 14, "note", room)
		link.label:SetWidth(0)
		width = math.min(room, math.ceil(link.label:GetStringWidth()))
		link.label:SetWidth(room)
	end
	link:SetSize(math.max(1, width), 19)
	-- the canvas's dotted underline: a dot every 2 units, 18 down
	link.dots = {}
	for i = 0, math.floor((width - 1) / 2) do
		local dot = link:CreateTexture(nil, "ARTWORK")
		local ink = INKS.note
		dot:SetColorTexture(ink[1], ink[2], ink[3], 0.6)
		dot:SetSize(1, 1)
		ns.GuideAt(dot, link, i * 2, 18)
		link.dots[#link.dots + 1] = dot
	end
	link:SetScript("OnEnter", function(self)
		self.label:SetTextColor(INKS.red[1], INKS.red[2], INKS.red[3])
	end)
	link:SetScript("OnLeave", function(self)
		self.label:SetTextColor(INKS.note[1], INKS.note[2], INKS.note[3])
	end)
	link:SetScript("OnClick", function()
		ns.GuideSound("click")
		onClick()
	end)
	return link
end

--- « back at a left page's foot (ONB-R23), in the Angler's brown hand, red under the mouse.
---@param page Frame
---@param onClick fun()
---@return Button
function ns.NewGuideBack(page, onClick)
	local back = CreateFrame("Button", nil, page)
	back:SetSize(48, 24)
	ns.GuideAt(back, page, COLUMN_X, 508)
	local label = ns.GuideText(back, "hand", 19, "brown", ns.L.GUIDE_BACK)
	ns.GuideAt(label, back, 0, 2.5)
	back:SetScript("OnEnter", function()
		label:SetTextColor(INKS.red[1], INKS.red[2], INKS.red[3])
	end)
	back:SetScript("OnLeave", function()
		label:SetTextColor(INKS.brown[1], INKS.brown[2], INKS.brown[3])
	end)
	back:SetScript("OnClick", function()
		onClick()
	end)
	return back
end

--- The right page's foot (ONB-R23): the skip link on the left and the leather Next » on the right, at the kit's
--- places (30, 497.5 and right-aligned to 412, 490). Either may be left out. The skip link keeps clear of Next: a
--- longer one is set smaller, then cut short (ns.FitGuideText), never under it.
---@param page Frame
---@param skipLabel string?
---@param onSkip fun()
---@param nextLabel string?
---@param onNext fun()
---@return PagleGuideLink? skip
---@return PagleGuideButton? next
function ns.NewGuideFoot(page, skipLabel, onSkip, nextLabel, onNext)
	local skip, nextButton
	local room = COLUMN_WIDTH
	if nextLabel then
		nextButton = ns.NewGuideButton(page, nextLabel, onNext)
		nextButton:SetWidth(math.max(77, nextButton:GetWidth()))
		nextButton:ClearAllPoints()
		nextButton:SetPoint("TOPRIGHT", page, "TOPLEFT", COLUMN_X + COLUMN_WIDTH, -490)
		room = COLUMN_WIDTH - nextButton:GetWidth() - FOOT_GAP
	end
	if skipLabel then
		skip = ns.NewGuideLink(page, skipLabel, onSkip, room)
		ns.GuideAt(skip, page, COLUMN_X, 497.5)
	end
	return skip, nextButton
end

--- A choice card (the kit's g-opt, Contracts' nav.ChoiceCard): its paper at rest, under the mouse and chosen, a radio,
--- its title, an italic line and an optional pencilled tag. Its parent sizes and places it (SetSize, SetPoint); the
--- paper follows. A line that wraps longer than the parent's height holds grows the card to it, its last line box
--- CARD_FOOT over the card's foot as the art's one line is, so a parent stacking cards reads each one's GetHeight. Clicking it plays `check`; a step adds what it does with HookScript("OnClick", …) and shows the
--- choice with SetChosen.
---@class PagleGuideChoiceCard: Button
---@field rest PagleNineSlice
---@field hover PagleNineSlice
---@field on PagleNineSlice
---@field radio Texture
---@field radioOn Texture
---@field title FontString
---@field line FontString?
---@field tag FontString?
---@field chosen boolean
---@field over boolean    -- under the mouse
---@field SetChosen fun(self: PagleGuideChoiceCard, chosen: boolean)
---@field Fit fun(self: PagleGuideChoiceCard): number fits its line to its width now, growing to it; returns its height

-- Shows a card's paper for its state: chosen, under the mouse, or at rest.
---@param card PagleGuideChoiceCard
local function paintCard(card)
	local over = card.over and not card.chosen
	card.on:SetShown(card.chosen)
	card.radioOn:SetShown(card.chosen)
	card.hover:SetShown(over)
	card.rest:SetShown(not card.chosen and not over)
end

-- A card's italic line: where its first line box starts, its size and line box, and the room under its last line box
-- (the art's 61.8-unit card holds one line).
local CARD_LINE_Y, CARD_LINE_SIZE, CARD_LINE_LH, CARD_FOOT = 32.5, 13.5, 18.2, 11.1

---@param parent Frame
---@param title string
---@param line string?
---@param tag string?
---@return PagleGuideChoiceCard
function ns.NewGuideChoiceCard(parent, title, line, tag)
	local card = CreateFrame("Button", nil, parent) --[[@as PagleGuideChoiceCard]]
	card:SetSize(COLUMN_WIDTH, 61.8)
	card.rest = ns.NewNineSlice(card, "GuideParts", "opt", 6)
	card.hover = ns.NewNineSlice(card, "GuideParts", "opt-hover", 6)
	card.on = ns.NewNineSlice(card, "GuideParts", "opt-on", 6)
	card.radio = ns.ArtSprite(card, "GuideParts", "radio", "ARTWORK", 0) --[[@as Texture]]
	ns.PlaceSprite(card.radio --[[@as PagleSprite]], card, 13, 15)
	card.radioOn = ns.ArtSprite(card, "GuideParts", "radio-on", "ARTWORK", 1) --[[@as Texture]]
	ns.PlaceSprite(card.radioOn --[[@as PagleSprite]], card, 13, 15)
	card.title = ns.GuideText(card, "print", 17, "title", title)
	ns.GuideAt(card.title, card, 37, 11 + 1.275)
	if line then
		card.line = ns.GuideText(
			card,
			"italic",
			CARD_LINE_SIZE,
			"line",
			line,
			{ wrap = true, spacing = CARD_LINE_LH - CARD_LINE_SIZE }
		)
		ns.GuideAt(card.line, card, 37, CARD_LINE_Y + (CARD_LINE_LH - CARD_LINE_SIZE) / 2)
	end
	if tag then
		card.tag = ns.GuideText(card, "hand", 16, "green", tag, { justify = "RIGHT" })
		card.tag:SetPoint("TOPRIGHT", card, "TOPLEFT", 0, 0)
	end
	-- the line wraps to the card's width, leaving the tag its room
	local function fit(self, width)
		if self.line then
			self.line:SetWidth(math.max(1, width - 49 - (self.tag and 40 or 0)))
			-- its lines as the client wraps them, counted from its height, so a line measured a little taller than its
			-- size still counts one
			local spacing = CARD_LINE_LH - CARD_LINE_SIZE
			local lines = math.max(1, math.floor((self.line:GetStringHeight() + spacing) / CARD_LINE_LH + 0.5))
			local need = CARD_LINE_Y + lines * CARD_LINE_LH + CARD_FOOT
			if self:GetHeight() < need - 1e-6 then
				self:SetHeight(need)
			end
		end
		if self.tag then
			self.tag:ClearAllPoints()
			self.tag:SetPoint("TOPRIGHT", self, "TOPLEFT", width - 9, -(5.7 + 3.25))
		end
	end
	card:SetScript("OnSizeChanged", fit)
	fit(card, card:GetWidth())
	-- the client may run OnSizeChanged only once the card is laid out: a parent stacking cards fits each at once
	function card.Fit(self)
		fit(self, self:GetWidth())
		return self:GetHeight()
	end
	card.chosen, card.over = false, false
	function card.SetChosen(self, chosen)
		self.chosen = chosen
		paintCard(self)
	end
	card:SetScript("OnEnter", function(self)
		self.over = true
		paintCard(self)
	end)
	card:SetScript("OnLeave", function(self)
		self.over = false
		paintCard(self)
	end)
	card:SetScript("OnClick", function()
		ns.GuideSound("check")
	end)
	card:SetChosen(false)
	return card
end

--- An illustrative note on a page (Contracts' nav.Note): a slip of paper in the Angler's pencil, `w` wide and as tall
--- as its text, its top left at `x`, `y` of `parent`, a key term between *asterisks* in red, and its red-pencil number
--- badge when `n` is given. Its pencil arrow to `target` is Margin notes' (ns.DrawNoteArrow, adapter/MarginNotes.lua). It
--- is part of the page, so it always shows (ONB-R50).
---@class PagleGuideNote: Frame
---@field paper PagleNineSlice
---@field text FontString
---@field badge Texture?
---@field number FontString?
---@field arrow Frame?
---@field FitAbove fun(self: PagleGuideNote, bottom: number, top: number?)
---@field fitted true? whether FitAbove set its words smaller or cut them
---@field size number the size its words are set at, the hand's 19 unless one word is wider than its room (1.3.5)

-- A note's words: the hand at 19, their lines 2.3 apart, and the paper's room round them (10 over, 11 under), which
-- makes the note as tall as its words and 21.
local NOTE_SIZE, NOTE_SPACING, NOTE_PAD = 19, 2.3, 21
-- The most lines a note held over what is under it keeps when too tall even at its smallest (FitAbove).
local NOTE_MOST_LINES = 6

--- `text` with each *term* in the red pencil (the canvas's <b>): one font string has one face, so it keeps the hand.
---@param text string
---@return string
function ns.GuideRedPencil(text)
	return (text:gsub("%*(.-)%*", "|cff9a2a1a%1|r"))
end

--- What draws a note's pencil arrow to its target: adapter/MarginNotes.lua, a later file, sets it to its Line-drawn
--- arrow and ring (#325); it is looked up as each note is made.
---@type (fun(note: Frame, target: Region): Frame)?
ns.DrawNoteArrow = nil

-- The widest of `words`' words (split at spaces) in its font now, measured unbounded; its text and `room` set again.
---@param words FontString
---@param room number
---@return number
local function widestWord(words, room)
	local text, widest = words:GetText() or "", 0
	words:SetWidth(0)
	for word in text:gmatch("%S+") do
		words:SetText(word)
		widest = math.max(widest, words:GetStringWidth())
	end
	words:SetText(text)
	words:SetWidth(room)
	return widest
end

-- Sets a note's words smaller when one of them is wider than its `room`, in half-unit steps down to FIT_FLOOR of their
-- size, so the client needn't break a word across lines (1.3.5: ruRU's "открывает" beside the drawn Pagle menu).
-- Returns the size they are set at.
---@param words FontString
---@param room number
---@return number
local function fitWords(words, room)
	local size = NOTE_SIZE
	if widestWord(words, room) <= room then
		return size
	end
	local floor = math.ceil(NOTE_SIZE * FIT_FLOOR * 2) / 2
	repeat
		size = size - 0.5
		words:SetFontObject(ns.ArtFaceFont("hand", size))
		words:SetSpacing(NOTE_SPACING)
	until size - 0.5 < floor or widestWord(words, room) <= room
	local color = INKS.hand
	words:SetTextColor(color[1], color[2], color[3])
	return size
end

---@param parent Frame
---@param text string
---@param x number
---@param y number
---@param w number
---@param target Region?
---@param n integer?
---@return PagleGuideNote
function ns.NewGuideNote(parent, text, x, y, w, target, n)
	local note = CreateFrame("Frame", nil, parent) --[[@as PagleGuideNote]]
	note:SetFrameLevel(parent:GetFrameLevel() + 20)
	note.text = ns.GuideText(note, "hand", NOTE_SIZE, "hand", ns.GuideRedPencil(text), {
		wrap = true,
		width = w - 28,
		spacing = NOTE_SPACING,
	})
	note.text:SetPoint("TOPLEFT", note, "TOPLEFT", 15, -10)
	note.size = fitWords(note.text, w - 28)
	note:SetSize(w, math.floor(note.text:GetStringHeight() + NOTE_PAD + 0.5))
	ns.GuideAt(note, parent, x, y)
	note.paper = ns.NewNineSlice(note, "GuideParts", "note", 6)
	if n then
		local badge = ns.ArtSprite(note, "GuideParts", "note-badge", "OVERLAY", 1)
		ns.PlaceSprite(badge, note, -12, -12)
		note.badge = badge
		note.number = ns.GuideText(note, "handBold", 17, "red", tostring(n), { justify = "CENTER" })
		note.number:SetDrawLayer("OVERLAY", 3)
		note.number:SetPoint("CENTER", note, "TOPLEFT", 1, -1)
	end
	if target and ns.DrawNoteArrow then
		note.arrow = ns.DrawNoteArrow(note, target)
	end

	--- Holds the note's paper above `bottom` on its parent, such as « back at the left page's foot (#605): a note that
	--- ends there is left as drawn; a longer one's words are set smaller, in half-unit steps down to FIT_FLOOR of their
	--- size, and one too tall even then keeps the lines that fit (one at least), the client cutting the last with
	--- "...". The paper follows its words. For a note with no arrow: one drawn to a target isn't drawn again. `top`,
	--- from 1.3.5, is where the note now starts on its parent, for one a page moves after making it (the Ledger's
	--- Your Ledger note); the place it was made at when nil. Called again, it fits the note from its own size again.
	---@param self PagleGuideNote
	---@param bottom number
	---@param top number?
	function note.FitAbove(self, bottom, top)
		local words = self.text
		if self.fitted then
			self.fitted = nil
			words:SetMaxLines(0)
			words:SetFontObject(ns.ArtFaceFont("hand", self.size))
			words:SetSpacing(NOTE_SPACING)
			local color = INKS.hand
			words:SetTextColor(color[1], color[2], color[3])
			self:SetHeight(math.floor(words:GetStringHeight() + NOTE_PAD + 0.5))
		end
		local room = bottom - (top or y) - NOTE_PAD
		if words:GetStringHeight() <= room then
			return
		end
		self.fitted = true
		local size, floor = self.size, math.ceil(NOTE_SIZE * FIT_FLOOR * 2) / 2
		while words:GetStringHeight() > room and size - 0.5 >= floor do
			size = size - 0.5
			words:SetFontObject(ns.ArtFaceFont("hand", size))
			words:SetSpacing(NOTE_SPACING)
		end
		if words:GetStringHeight() > room then
			for lines = NOTE_MOST_LINES, 1, -1 do
				words:SetMaxLines(lines)
				if words:GetStringHeight() <= room then
					break
				end
			end
		end
		-- its ink again, as a new font object can bring its own
		local color = INKS.hand
		words:SetTextColor(color[1], color[2], color[3])
		self:SetHeight(math.floor(words:GetStringHeight() + NOTE_PAD + 0.5))
	end
	return note
end

--- A sprite of the guide's atlas on `parent` (Contracts' nav.Part), at its designed size: its `box` is where its drawn
--- element sits in it, for a step to place it by.
---@param parent Frame
---@param sprite string a GuideParts sprite: "disc", "ic-journal", "slot", "arrows", …
---@return PagleSprite
function ns.GuidePart(parent, sprite)
	return ns.ArtSprite(parent, "GuideParts", sprite, "ARTWORK")
end

--- The widgets a step's nav hands its build (logic/Guide.lua's ns.NewGuideNav), each looked up when called, so a later
--- piece that replaces one (#325's arrow) reaches every step. The binding field is adapter/GuideBindingField.lua's.
---@type PagleGuideWidgets
ns.GUIDE_WIDGETS = {
	BindingField = function(...)
		return ns.NewGuideBindingField(...)
	end,
	ChoiceCard = function(...)
		return ns.NewGuideChoiceCard(...)
	end,
	Note = function(...)
		return ns.NewGuideNote(...)
	end,
	Part = function(...)
		return ns.GuidePart(...)
	end,
	-- A GuideParts sprite nine-sliced on a frame of the step's, which keeps `cap` units at each corner and follows the
	-- frame's size: for a panel a Module's page draws at its own size, such as QoL's set cards (ONB-R33).
	Panel = function(frame, sprite, cap)
		return ns.NewNineSlice(frame, "GuideParts", sprite, cap)
	end,
}
