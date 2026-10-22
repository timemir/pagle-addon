---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The onboarding art kit on the client (core/onboarding.md › UI): the guide's inks, type set at the kit's sizes, and
-- the widgets every onboarding piece draws with, from the GuideParts atlas (data/GuideArt.lua) through Core's art
-- helpers (adapter/Art.lua: ns.ArtSprite, ns.SetThreeSlice, ns.NewNineSlice, ns.ArtFaceFont): a page's kicker and
-- title, the leather button, the foot's skip link and « back, a choice card, an illustrative note, a part of the
-- atlas, the binding field's slot and the step ribbons. Positions are the onboarding kit's (prototypes/onboarding-kit,
-- PagleArtGuide's GuideKit.lua and Guide.lua): the canvas's CSS pixels, UI units, from a page's top left, y down. A
-- step's build reaches the widgets through its nav (logic/Guide.lua's ns.NewGuideNav); later onboarding pieces (the
-- Letter, Margin notes, First looks, the First evening list) call them here.

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
	gilt = rgb("EFD286"), -- a ribbon's words
	giltOn = rgb("FFF0BC"), -- the current ribbon's
	wax = rgb("F4DFA8"), -- the leather button's words
	crumb = rgb("E8C96A"), -- the strip's crumbs
	count = rgb("C9B27A"), -- "{n} of {m}" on the strip
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
	ns.GuideAt(kicker, page, COLUMN_X, 24)
	return kicker
end

--- A page's title, under its kicker: IM Fell English at `size` (29, the right page's 25).
---@param page Frame
---@param text string
---@param size number?
---@return FontString
function ns.NewGuideTitle(page, text, size)
	size = size or 29
	local title = ns.GuideText(page, "print", size, "title", text)
	-- the kit's line box is 1.05 of the size; the text sits in its middle
	ns.GuideAt(title, page, COLUMN_X, 41 + size * 0.025)
	return title
end

--- The guide's sounds (the kit's SOUND.md; the books' own): sound kit ids on the SFX channel, and whether each goes
--- with the motion (with Animations off the page turns without a sound, as the books do).
---@type table<string, { id: integer, motion: boolean }>
ns.GUIDE_SOUNDS = {
	bookOpen = { id = 829, motion = false }, -- IG_SPELLBOOK_OPEN
	bookClose = { id = 830, motion = false }, -- IG_SPELLBOOK_CLOSE
	pageTurn = { id = 836, motion = true }, -- IG_ABILITY_PAGE_TURN: Next, back, a ribbon
	click = { id = 852, motion = false }, -- IG_MAINMENU_OPTION: a button, a skip link
	check = { id = 856, motion = false }, -- IG_MAINMENU_OPTION_CHECKBOX_ON: a choice card picked
	uncheck = { id = 857, motion = false }, -- IG_MAINMENU_OPTION_CHECKBOX_OFF
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

---@param parent Frame
---@param text string
---@param onClick fun()
---@return PagleGuideLink
function ns.NewGuideLink(parent, text, onClick)
	local link = CreateFrame("Button", nil, parent) --[[@as PagleGuideLink]]
	link.label = ns.GuideText(link, "italic", 14, "note", text)
	link.label:SetPoint("TOPLEFT", 0, -2.5)
	local width = math.ceil(link.label:GetStringWidth())
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
--- places (30, 497.5 and right-aligned to 412, 490). Either may be left out.
---@param page Frame
---@param skipLabel string?
---@param onSkip fun()
---@param nextLabel string?
---@param onNext fun()
---@return PagleGuideLink? skip
---@return PagleGuideButton? next
function ns.NewGuideFoot(page, skipLabel, onSkip, nextLabel, onNext)
	local skip, nextButton
	if skipLabel then
		skip = ns.NewGuideLink(page, skipLabel, onSkip)
		ns.GuideAt(skip, page, COLUMN_X, 497.5)
	end
	if nextLabel then
		nextButton = ns.NewGuideButton(page, nextLabel, onNext)
		nextButton:SetWidth(math.max(77, nextButton:GetWidth()))
		nextButton:ClearAllPoints()
		nextButton:SetPoint("TOPRIGHT", page, "TOPLEFT", COLUMN_X + COLUMN_WIDTH, -490)
	end
	return skip, nextButton
end

--- A choice card (the kit's g-opt, Contracts' nav.ChoiceCard): its paper at rest, under the mouse and chosen, a radio,
--- its title, an italic line and an optional pencilled tag. Its parent sizes and places it (SetSize, SetPoint); the
--- paper follows. Clicking it plays `check`; a step adds what it does with HookScript("OnClick", …) and shows the
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

-- Shows a card's paper for its state: chosen, under the mouse, or at rest.
---@param card PagleGuideChoiceCard
local function paintCard(card)
	local over = card.over and not card.chosen
	card.on:SetShown(card.chosen)
	card.radioOn:SetShown(card.chosen)
	card.hover:SetShown(over)
	card.rest:SetShown(not card.chosen and not over)
end

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
		card.line = ns.GuideText(card, "italic", 13.5, "line", line, { wrap = true, spacing = 4.7 })
		ns.GuideAt(card.line, card, 37, 32.5 + 2.35)
	end
	if tag then
		card.tag = ns.GuideText(card, "hand", 16, "green", tag, { justify = "RIGHT" })
		card.tag:SetPoint("TOPRIGHT", card, "TOPLEFT", 0, 0)
	end
	-- the line wraps to the card's width, leaving the tag its room
	local function fit(self, width)
		if self.line then
			self.line:SetWidth(math.max(1, width - 49 - (self.tag and 40 or 0)))
		end
		if self.tag then
			self.tag:ClearAllPoints()
			self.tag:SetPoint("TOPRIGHT", self, "TOPLEFT", width - 9, -(5.7 + 3.25))
		end
	end
	card:SetScript("OnSizeChanged", fit)
	fit(card, card:GetWidth())
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
--- badge when `n` is given. Its pencil arrow to `target` is Margin notes' (#325, ns.DrawNoteArrow); until that lands,
--- the paper shows alone. It is part of the page, so it always shows (ONB-R50).
---@class PagleGuideNote: Frame
---@field paper PagleNineSlice
---@field text FontString
---@field badge Texture?
---@field number FontString?
---@field arrow Frame?

--- `text` with each *term* in the red pencil (the canvas's <b>): one font string has one face, so it keeps the hand.
---@param text string
---@return string
function ns.GuideRedPencil(text)
	return (text:gsub("%*(.-)%*", "|cff9a2a1a%1|r"))
end

--- What draws a note's pencil arrow to its target (#325's Line-drawn arrow and ring): nil until Margin notes land.
---@type (fun(note: Frame, target: Region): Frame)?
ns.DrawNoteArrow = nil

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
	note.text = ns.GuideText(note, "hand", 19, "hand", ns.GuideRedPencil(text), {
		wrap = true,
		width = w - 28,
		spacing = 2.3,
	})
	note.text:SetPoint("TOPLEFT", note, "TOPLEFT", 15, -10)
	note:SetSize(w, math.floor(note.text:GetStringHeight() + 21 + 0.5))
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

--- A binding field (ONB-R40–R44, Contracts' nav.BindingField), #324's widget: until it lands, its paper and its label
--- alone, the field's size (382 x 62), binding nothing. #324 replaces this maker.
---@param parent Frame
---@param action string PAGLE_FISHING_KEY or PAGLE_SWAP_GEAR
---@param label string
---@return Frame
function ns.NewGuideBindingField(parent, action, label)
	local field = CreateFrame("Frame", nil, parent)
	field:SetSize(COLUMN_WIDTH, 62)
	field:SetFrameLevel(parent:GetFrameLevel() + 2)
	ns.NewNineSlice(field, "GuideParts", "bind", 8)
	local words = ns.GuideText(field, "print", 15, "body", label)
	ns.GuideAt(words, field, 13, 21.5 + 2)
	field.action = action
	return field
end

--- The widgets a step's nav hands its build (logic/Guide.lua's ns.NewGuideNav), each looked up when called, so a later
--- piece that replaces one (#324's binding field, #325's arrow) reaches every step.
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
}

-- The step ribbons (ONB-R24): one per step under the book's foot, 98 wide with an 8-unit gap, each hanging 92 units,
-- the current one 110 and brighter, a seen one ticked in full colour, one not yet seen dimmed (the sprites carry the
-- tick and the 82%). Each label is its step's ribbon text in gilt, 28 units above its end.

--- The ribbons' measures (Tunables): width, gap, how long each hangs, the current one's length, how much of each top
--- tucks under the book's band, and how long a change of current takes (MOTION.md: 0.2 s, ease-out).
ns.GUIDE_RIBBON = { width = 98, gap = 8, length = 92, lengthCurrent = 110, tuck = 14, ease = 0.2 }
local RIBBON = ns.GUIDE_RIBBON

--- One step ribbon.
---@class PagleGuideRibbonView: Button
---@field body Texture
---@field label FontString
---@field state "plain"|"done"|"on"
---@field length number how long it hangs now: eased toward its state's length
---@field hover boolean
---@field SetRibbon fun(self: PagleGuideRibbonView, ribbon: PagleGuideRibbon, animate: boolean?)

-- Each state's sprite: not yet seen, seen (ticked), current.
local RIBBON_SPRITES = { plain = "rib", done = "rib-done", on = "rib-on" }

-- Hangs `ribbon` `length` long: the bottom `length` units of its state's sprite (its swallowtail always shows) from its
-- top; while it hangs longer than that sprite (the old current drawing up), the current one's sprite.
---@param ribbon PagleGuideRibbonView
---@param length number
local function hangRibbon(ribbon, length)
	ribbon.length = length
	local name = RIBBON_SPRITES[ribbon.state]
	local atlas = ns.ATLASES.GuideParts
	if length > atlas.sprites[name].box[4] + 0.01 then
		name = RIBBON_SPRITES.on
	end
	local sprite = atlas.sprites[name]
	local dropped = (sprite.box[4] - length) * atlas.scale
	local body = ribbon.body
	body:SetTexture(atlas.file)
	body:SetTexCoord(
		sprite.x / atlas.width,
		(sprite.x + sprite.w) / atlas.width,
		(sprite.y + dropped) / atlas.height,
		(sprite.y + sprite.h) / atlas.height
	)
	body:SetSize(sprite.w / atlas.scale, sprite.h / atlas.scale - sprite.box[4] + length)
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", ribbon, "TOPLEFT", -sprite.box[1], 0)
	ribbon:SetSize(RIBBON.width, length)
	ribbon.label:ClearAllPoints()
	ribbon.label:SetPoint("BOTTOM", ribbon, "TOPLEFT", RIBBON.width / 2, -(length - 28))
	local brighter = ribbon.hover and ribbon.state ~= "on" and (ribbon.state == "done" and 1.12 or 1.15) or 1
	body:SetVertexColor(brighter, brighter, brighter)
end

--- A step ribbon on `parent` (the book), clicked to turn to its step.
---@param parent Frame
---@return PagleGuideRibbonView
function ns.NewGuideRibbon(parent)
	local ribbon = CreateFrame("Button", nil, parent) --[[@as PagleGuideRibbonView]]
	ribbon.body = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK"))
	ribbon.label = ns.GuideText(ribbon, "gilt", 12, "gilt", "", {
		shadow = true,
		wrap = true,
		width = 82,
		spacing = 1.8,
		justify = "CENTER",
	})
	ribbon.state, ribbon.hover = "plain", false
	ribbon:SetScript("OnEnter", function(self)
		self.hover = true
		hangRibbon(self, self.length)
	end)
	ribbon:SetScript("OnLeave", function(self)
		self.hover = false
		hangRibbon(self, self.length)
	end)
	hangRibbon(ribbon, RIBBON.length)
	function ribbon.SetRibbon(self, data, animate)
		self.label:SetText(data.label)
		self.state = data.current and "on" or (data.seen and "done" or "plain")
		local ink = data.current and INKS.giltOn or INKS.gilt
		self.label:SetTextColor(ink[1], ink[2], ink[3])
		self.label:SetAlpha((data.current or data.seen) and 1 or 0.85)
		local to = data.current and RIBBON.lengthCurrent or RIBBON.length
		Pagle.StopMotion(self)
		if animate and to ~= self.length then
			-- the new current drops as the old one draws up (MOTION.md: 0.2 s, ease-out); settled with Animations off
			Pagle.Animate(self, {
				{
					dur = RIBBON.ease,
					ease = Pagle.EASE.out,
					keys = { { 0, { self.length } }, { 1, { to } } },
					apply = function(v)
						hangRibbon(self, v[1])
					end,
				},
			})
		else
			hangRibbon(self, to)
		end
	end
	return ribbon
end
