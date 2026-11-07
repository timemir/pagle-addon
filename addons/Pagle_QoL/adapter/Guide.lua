if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- QoL's two steps in Core's Field guide (core/onboarding.md › The steps): Casting (ONB-R32, ONB-R100) and Fishing
-- clothes (ONB-R33, ONB-R105), registered with `M:RegisterGuideStep` (ONB-R21) and drawn on the pages Core hands
-- their builds. A step's page contents are QoL's (ONB-R92), so they are drawn with QoL's own art where it has it: the
-- next-action button's face (adapter/NextActionButton.lua), the leather button and the type of the field art kit
-- (adapter/FieldArt.lua) and the swap-back Nudge's strip (adapter/Nudge.lua). The rest is Core's, through the step's
-- nav (Contracts): the choice cards, the binding fields, the illustrative note, and the guide atlas's sprites and
-- panels. QoL sees Core only through its handle and that nav (ADR 0001). Every control calls QoL's own action, the one
-- its Settings row, `/pagle qol` or Swap gear calls: the guide is a second door to settings that already exist.
-- Positions are the onboarding kit's (prototypes/onboarding-kit, PagleArtGuide's Guide.lua, boards 4 and 5): UI units
-- from a page's top left, y down.

-- The owner of the guide pages' registrations: they redraw what they show when the bindings, the sets or restriction
-- change while they are built.
local OWNER = "Pagle_QoL guide"

-- A page's text column: from 30 to 412 on a 442-unit page (the kit's W).
local COLUMN_X, COLUMN = 30, 382

-- The items whose icons the Casting step's sample faces show when the game has nothing better: the Fishing Pole for
-- Gear while no fishing set is chosen. The lure shown is the one chosen on the Fishing page (QOL-R50).
local SAMPLE_POLE = 6256

-- The drawn slots of a set that doesn't exist yet (ONB-R33), one per ns.GUIDE_SET_SLOTS slot, as the kit draws them,
-- tinted as it tints them.
local PREVIOUS_PLACEHOLDERS = {
	"Interface\\Icons\\INV_Helmet_01",
	"Interface\\Icons\\INV_Chest_Chain_05",
	"Interface\\Icons\\INV_Gauntlets_04",
	"Interface\\Icons\\INV_Sword_04",
}
local FISHING_PLACEHOLDERS = {
	"Interface\\Icons\\INV_Misc_Bandana_03",
	"Interface\\Icons\\INV_Shirt_05",
	"Interface\\Icons\\INV_Gauntlets_05",
	"Interface\\Icons\\INV_Fishingpole_02",
}

-- The check and uncheck foley (the kit's SOUND.md, the books' own), on the SFX channel: IG_MAINMENU_OPTION for the
-- leather button and the field, IG_MAINMENU_OPTION_CHECKBOX_ON and _OFF for the checkbox.
local SOUND_CLICK, SOUND_CHECK, SOUND_UNCHECK = 852, 856, 857

-- An ink from its hex, as { r, g, b }.
---@param hex string
---@return number[]
local function rgb(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

-- The guide's inks on paper, by role, from the onboarding kit's guide.css (PagleArtGuide's Kit.lua).
local INKS = {
	kicker = rgb("8A5A2A"), -- the small-caps kicker over a title
	title = rgb("3E220C"), -- titles, a set card's name
	body = rgb("3A2614"), -- printed paragraphs
	small = rgb("5A4028"), -- small print
	note = rgb("7A5A30"), -- italic notes
	line = rgb("6A4A28"), -- italic lines and captions
	hand = rgb("23407A"), -- the Angler's pencil
	red = rgb("9A2A1A"), -- the red pencil: the resting line, Save's message
}

-- Puts `region`'s top left `x`, `y` from `relativeTo`'s top left (y grows downward), the kit's P.At.
---@param region Region
---@param relativeTo Region
---@param x number
---@param y number
local function at(region, relativeTo, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, -y)
end

-- Puts a sprite of the guide's atlas so its drawn element's top left is `x`, `y` from `relativeTo`'s top left: nav.Part
-- gives the element's place in its sprite as `box`.
---@param part Texture
---@param relativeTo Region
---@param x number
---@param y number
local function place(part, relativeTo, x, y)
	local box = (part --[[@as PagleSprite]]).box or { 0, 0 }
	at(part, relativeTo, x - box[1], y - box[2])
end

--- How a line of type is set (the kit's P.T): wrapped to `width`, or centred on its `x`.
---@class PagleQoLGuideTextOptions
---@field width number?
---@field centre boolean?

-- A font string on `parent` in the kit's `face` at `size`, in ink `ink`, reading `words`: its line box `lead` tall (the
-- kit's line height) with its top at `y` and its left at `x` (its centre, with `centre`), wrapped to `width` when
-- given, `lead` apart.
---@param parent Frame
---@param face string
---@param size number
---@param ink string
---@param words string
---@param x number
---@param y number
---@param lead number
---@param options PagleQoLGuideTextOptions?
---@return FontString
local function write(parent, face, size, ink, words, x, y, lead, options)
	options = options or {}
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(ns.FaceFont(face, size))
	local color = INKS[ink]
	text:SetTextColor(color[1], color[2], color[3])
	text:SetJustifyH(options.centre and "CENTER" or "LEFT")
	text:SetWordWrap(options.width ~= nil)
	if options.width then
		text:SetWidth(options.width)
		text:SetSpacing(lead - size)
	end
	text:SetText(words)
	text:SetPoint(options.centre and "TOP" or "TOPLEFT", parent, "TOPLEFT", x, -(y + (lead - size) / 2))
	return text
end

-- How small a line held to its room may be set, as a share of its size: past that it wraps, or the client cuts it
-- short with "...".
local FIT_FLOOR = 0.75

-- A text's width on one line, measured unbounded (its width set after).
---@param text FontString
---@return number
local function natural(text)
	text:SetWidth(0)
	return text:GetStringWidth()
end

-- Holds a one-line `text` in the kit's `face` at `size`, in ink `ink`, to `room`: a text too wide is set smaller, in
-- half-unit steps down to FIT_FLOOR of its size, and then held to `room`, so one still too wide is cut short by the
-- client's "..." instead of running into what is beside it; its ink set again. Returns whether it fits whole.
---@param text FontString
---@param face string
---@param size number
---@param ink string
---@param room number
---@return boolean
local function fit(text, face, size, ink, room)
	local width = natural(text)
	if width > room then
		local floor = math.ceil(size * FIT_FLOOR * 2) / 2
		text:SetFontObject(ns.FaceFont(face, math.max(floor, math.floor(size * room / width * 2) / 2)))
	end
	-- its ink again, as a font object set on it (here, or by its caller) brings its own
	local color = INKS[ink]
	text:SetTextColor(color[1], color[2], color[3])
	text:SetWidth(room)
	return width * FIT_FLOOR <= room
end

-- Where a text `write` set at `y` in a line box `lead` tall at `size` ends: its measured height as the client wraps it
-- and the half-leading above its first line and below its last. What follows a text that can wrap is laid from this,
-- so a longer translation pushes it down instead of running into it.
---@param text FontString
---@param y number
---@param size number
---@param lead number
---@return number
local function below(text, y, size, lead)
	return y + text:GetStringHeight() + (lead - size)
end

-- A page's kicker and title (the kit's kicker and title): small caps over IM Fell English at `size` (29, the right
-- page's 25), each on one line across the column, set smaller when longer (fit), never into the spine.
---@param page Frame
---@param kicker string
---@param title string
---@param size number?
local function heading(page, kicker, title, size)
	size = size or 29
	fit(write(page, "sc", 14, "kicker", kicker, COLUMN_X, 24, 14), "sc", 14, "kicker", COLUMN)
	fit(write(page, "print", size, "title", title, COLUMN_X, 41, size * 1.05), "print", size, "title", COLUMN)
end

-- A paragraph of the body (15 on 20.7) or of small print (13.5 on 18.225) across the column, its top at `y`.
---@param page Frame
---@param words string
---@param y number
---@param small boolean?
---@return FontString
local function paragraph(page, words, y, small)
	if small then
		return write(page, "print", 13.5, "small", words, COLUMN_X, y, 18.225, { width = COLUMN })
	end
	return write(page, "print", 15, "body", words, COLUMN_X, y, 20.7, { width = COLUMN })
end

-- Greys a control while it can't act: disabled, at half strength.
---@param control Button
---@param enabled boolean
local function setLive(control, enabled)
	control:SetEnabled(enabled)
	control:SetAlpha(enabled and 1 or 0.5)
end

-- ---------------------------------------------------------------- Casting (ONB-R32, board 4)

--- The Casting step's pages, once built.
---@class PagleQoLCastingPages
---@field faces { face: PagleQoLButtonFace, action: PagleQoLAction }[] the next-action sequence, Gear » Lure » Cast » Reel
---@field cards { card: Button, input: PagleQoLInput }[] the Input cards
---@field field Frame the Fishing key's binding field (nav.BindingField)
---@field check { on: Texture, off: Texture } the next-action button checkbox's two states
---@field resting FontString the resting line (ONB-R100)
---@field body Frame the right page's controls, under the resting line

local casting ---@type PagleQoLCastingPages?

-- The icons the sample faces show (QOL-R71): the Fishing spell's for Cast and Reel, the fishing set's for Gear (the
-- Fishing Pole's while none is chosen), the chosen lure's for Lure.
---@return PagleQoLButtonIcons
local function sampleIcons()
	local setID = ns.FishingSetChoice()
	local setIcon = setID ~= ns.NO_FISHING_SET and select(2, C_EquipmentSet.GetEquipmentSetInfo(setID)) or nil
	return {
		fishing = (C_Spell.GetSpellTexture(ns.FISHING_SPELL_ID)),
		set = setIcon or C_Item.GetItemIconByID(SAMPLE_POLE),
		item = C_Item.GetItemIconByID(ns.db.profile.lures.item),
	}
end

-- The sample faces' pitch on the Casting step's left page, and the least room between two faces' label slips.
local FACE_PITCH, SLIP_GAP = 97.6, 8

-- Holds a sample face's label to its share of the row (FACE_PITCH less SLIP_GAP, its slip's ends included): a longer
-- one is set smaller, then cut short, and its slip drawn to it, so two faces' labels never run together.
---@param face PagleQoLButtonFace
local function fitFaceLabel(face)
	local label = face.Label
	if not label:IsShown() then
		return
	end
	local room = math.floor(FACE_PITCH - SLIP_GAP - ns.LabelWidth(0))
	-- the face's Label type (FieldArt's: Caveat SemiBold 18 in ink), at its size again before it is measured
	local size, ink = 18, ns.FIELD_INKS.ink
	label:SetFontObject(ns.FaceFont("handSemi", size))
	label:SetTextColor(ink[1], ink[2], ink[3])
	local width = natural(label)
	if width > room then
		size = math.max(math.ceil(size * FIT_FLOOR * 2) / 2, math.floor(size * room / width * 2) / 2)
		label:SetFontObject(ns.FaceFont("handSemi", size))
		label:SetTextColor(ink[1], ink[2], ink[3])
		width = math.min(room, natural(label))
	end
	label:SetWidth(room)
	ns.SetThreeSlice(face.Paper, "Field", "label", ns.LabelWidth(math.ceil(width)), 8, "ARTWORK")
end

-- Draws the Casting step as things are now: the sequence with the Fishing key's first key on its caps as the button
-- shows it under this Input (QOL-R70), the chosen Input's card, the Fishing key field greyed under Double right-click
-- or while QoL stands down, with the resting line then (ONB-R100), and the checkbox.
local function refreshCasting()
	local pages = casting
	if not pages then
		return
	end
	local input = ns.CurrentInput()
	local hotkey = ns.ButtonHotkey(input, { GetBindingKey("PAGLE_FISHING_KEY") }, ns.ShortKeyText)
	local icons = sampleIcons()
	for _, sample in ipairs(pages.faces) do
		ns.SetButtonFace(sample.face, ns.ButtonLook(sample.action, icons, nil), hotkey)
		fitFaceLabel(sample.face)
	end
	for _, choice in ipairs(pages.cards) do
		(choice.card --[[@as PagleGuideChoiceCard]]):SetChosen(choice.input == input)
	end
	local standingDown = ns.IsStandingDown()
	local field = pages.field --[[@as PagleGuideBindingField]]
	field:SetGreyed(ns.FishingKeyFieldGreyed(input, standingDown))
	local resting = ns.RestingLine(ns.StandingDownFor())
	pages.resting:SetText(resting or "")
	pages.resting:SetShown(resting ~= nil)
	-- The resting line takes the room under the title; the cards and what's under them move down by it.
	at(
		pages.body,
		pages.body:GetParent() --[[@as Region]],
		0,
		resting and math.ceil(pages.resting:GetStringHeight()) + 8 or 0
	)
	local shown = ns.db.profile.indicator.shown
	pages.check.on:SetShown(shown)
	pages.check.off:SetShown(not shown)
end

-- The checkbox Show the next-action button, as the Fishing page's row: its tooltip as the line under it (ONB-R32). A
-- click changes the setting, which re-evaluates and so shows or hides the button at once (QOL-R25).
---@param parent Frame
---@param nav PagleGuideNav
---@param y number its top on `parent`, under the binding field
---@return { on: Texture, off: Texture }
local function buttonCheck(parent, nav, y)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(COLUMN, 36)
	at(row, parent, COLUMN_X, y)
	local check = { on = nav.Part(row, "check"), off = nav.Part(row, "check-off") }
	place(check.on, row, 0, 2)
	place(check.off, row, 0, 2)
	-- each on one line across the row from its words' start, set smaller when longer, never past the page (#592); a
	-- line too long even at its smallest wraps at its own size onto a second line instead
	local room = COLUMN - 25
	fit(write(row, "print", 15.5, "title", ns.L.SETTINGS_SHOW_BUTTON, 25, 0, 18.6), "print", 15.5, "title", room)
	local tip = write(row, "italic", 13, "line", ns.L.SETTINGS_SHOW_BUTTON_TOOLTIP, 25, 18.6, 16.9)
	if not fit(tip, "italic", 13, "line", room) then
		tip:SetFontObject(ns.FaceFont("italic", 13))
		tip:SetTextColor(INKS.line[1], INKS.line[2], INKS.line[3])
		tip:SetWordWrap(true)
		tip:SetMaxLines(2)
		tip:SetSpacing(16.9 - 13)
	end
	row:SetScript("OnClick", function()
		ns.db.profile.indicator.shown = not ns.db.profile.indicator.shown
		PlaySound(ns.db.profile.indicator.shown and SOUND_CHECK or SOUND_UNCHECK, "SFX")
		ns.EvaluateFishingKey()
		refreshCasting()
	end)
	return check
end

-- Draws the Casting step's two pages, once (ONB-R32). Left: the next-action sequence on the button's own face, each
-- press with its caption, and the note about the double right-click. Right: the three Input cards, each setting Input
-- as `/pagle qol input` does, printing nothing (QOL-R17); the Fishing key's binding field; the checkbox.
---@param left Frame
---@param right Frame
---@param nav PagleGuideNav
local function buildCasting(left, right, nav)
	local L = ns.L
	heading(left, L.GUIDE_CASTING_KICKER, L.GUIDE_CASTING_TITLE)
	paragraph(left, L.GUIDE_CASTING_BODY, 85.4)
	local faces = {}
	local sequence = ns.GuideSequence()
	-- the small print starts under the lowest caption, and the note under it, when they wrap longer than the art's
	local under = 0
	for i, press in ipairs(sequence) do
		local x = 34 + (i - 1) * FACE_PITCH
		local frame = CreateFrame("Frame", nil, left)
		frame:SetFrameLevel(left:GetFrameLevel() + 3)
		faces[i] = { face = ns.DrawButtonFace(frame), action = press.action }
		at(frame, left, x + 13, 173.5)
		local caption =
			write(left, "italic", 12.5, "line", press.caption, x + 39, 263.5, 15.625, { width = 78, centre = true })
		under = math.max(under, below(caption, 263.5, 12.5, 15.625))
		if i < #sequence then
			write(left, "hand", 26, "kicker", L.GUIDE_CASTING_THEN, x + 87.8, 191.5, 33, { centre = true })
		end
	end
	local smallY = math.max(320.8, under + 12)
	local small = paragraph(left, L.GUIDE_CASTING_SMALL, smallY, true)
	nav.Note(left, L.GUIDE_CASTING_NOTE, 56, math.max(400, below(small, smallY, 13.5, 18.225) + 14), 300)

	heading(right, L.GUIDE_CHOICE_KICKER, L.GUIDE_CHOICE_TITLE, 25)
	local resting = write(right, "italic", 13.5, "red", "", COLUMN_X, 70, 18, { width = COLUMN })
	resting:Hide()
	local body = CreateFrame("Frame", nil, right)
	body:SetSize(right:GetWidth(), right:GetHeight())
	at(body, right, 0, 0)
	local cards = {}
	-- the art's tops for cards 61.8 tall; a card grown to a line that wraps longer moves the rest down, the binding
	-- field and the checkbox with them
	local tops, grown = { 81.3, 151, 220.8 }, 0
	for i, choice in ipairs(ns.InputCards()) do
		local card = nav.ChoiceCard(body, choice.title, choice.line, choice.tag)
		card:SetSize(COLUMN, 61.8)
		at(card, body, COLUMN_X, tops[i] + grown)
		-- Core's card fits its line at once (nav.ChoiceCard's Fit); an older Core's card keeps the art's height
		local fits = card --[[@as { Fit: (fun(self: Button): number)? }]]
		local height = fits.Fit and fits.Fit(card) or card:GetHeight()
		grown = grown + math.max(0, height - 61.8)
		card:HookScript("OnClick", function()
			ns.SetInput(choice.input)
			refreshCasting()
		end)
		cards[i] = { card = card, input = choice.input }
	end
	local field = nav.BindingField(body, "PAGLE_FISHING_KEY", L.SETTINGS_FISHING_KEY)
	at(field, body, COLUMN_X, 298.5 + grown)
	casting = {
		faces = faces,
		cards = cards,
		field = field,
		check = buttonCheck(body, nav, 374.5 + grown),
		resting = resting,
		body = body,
	}
	refreshCasting()
end

-- ---------------------------------------------------------------- Fishing clothes (ONB-R33, board 5)

--- One set card on the Fishing clothes step: its name and four slots.
---@class PagleQoLSetCard
---@field frame Frame its panel
---@field name FontString
---@field icons Texture[]
---@field placeholders string[]
---@field tint number[] the placeholders' tint
---@field default string the name it shows while the set doesn't exist

--- The Fishing clothes step's pages, once built.
---@class PagleQoLClothesPages
---@field previous PagleQoLSetCard
---@field fishing PagleQoLSetCard
---@field save PagleQoLNoteButton Save what I'm wearing as my fishing set
---@field message FontString Save's message, in red, while it couldn't (ONB-R105)
---@field lower Frame what's under the message, moved down by it
---@field lowerY number how far down the paragraph over Save, wrapped longer than the art's, puts Save and all under it
---@field dropdown Button the Fishing set field
---@field choice FontString the set it shows
---@field list PagleQoLSetList the field's list, open under it after a click
---@field field Frame the Swap gear binding field (nav.BindingField)
---@field nudge Frame the swap-back Nudge's sample strip
---@field nudgeMore Frame its second strip, when its line is drawn on two
---@field nudgeY number where the strip's top sits on `lower`

local clothes ---@type PagleQoLClothesPages?
-- The room "or use a set you made" has left of the Fishing set field (at 139.2), 8 short of it.
local OR_ROOM = 139.2 - 8 - COLUMN_X
-- Save's message while it shows: kept until the step is left (ONB-R105).
local saveMessage ---@type string?
-- Opens the Fishing set field's list, filled as things are now (below, after refreshClothes, which it calls).
local openList ---@type fun(list: PagleQoLSetList)

-- The room a set card's name and line keep inside its 166-unit panel.
local CARD_TEXT = 166 - 16

-- A set card on `page` at `x` (the kit's kit()): the guide's card panel, the set's name in small caps, four slots
-- (each an icon in the atlas's slot ring) and its line in italic.
---@param page Frame
---@param nav PagleGuideNav
---@param x number
---@param y number
---@param default string
---@param line string
---@param placeholders string[]
---@param tint number[]
---@return PagleQoLSetCard
local function setCard(page, nav, x, y, default, line, placeholders, tint)
	local frame = CreateFrame("Frame", nil, page)
	frame:SetSize(166, 108.6)
	at(frame, page, x, y)
	frame:SetFrameLevel(page:GetFrameLevel() + 1)
	nav.Panel(frame, "card", 6)
	local card = {
		name = write(frame, "sc", 15, "title", default, 83, 11, 19, { centre = true }),
		frame = frame,
		icons = {},
		placeholders = placeholders,
		tint = tint,
		default = default,
	}
	for i = 1, #ns.GUIDE_SET_SLOTS do
		local x0 = 7.5 + (i - 1) * 39
		local icon = frame:CreateTexture(nil, "ARTWORK", nil, 0)
		icon:SetSize(32, 32)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		at(icon, frame, x0 + 1, 39)
		card.icons[i] = icon
		place(nav.Part(frame, "slot"), frame, x0, 38)
	end
	fit(write(frame, "italic", 12.5, "line", line, 83, 80, 15.6, { centre = true }), "italic", 12.5, "line", CARD_TEXT)
	return card
end

-- Shows a set on its card (ONB-R33): its name and real items, an empty slot showing none, or the drawn placeholders
-- while it doesn't exist.
---@param card PagleQoLSetCard
---@param set PagleQoLGuideSet?
local function showSet(card, set)
	card.name:SetText(set and set.name or card.default)
	card.name:SetFontObject(ns.FaceFont("sc", 15))
	fit(card.name, "sc", 15, "title", CARD_TEXT)
	local slots = ns.SetCardSlots(set and set.items, function(itemID)
		return C_Item.GetItemIconByID(itemID)
	end, card.placeholders)
	for i, slot in ipairs(slots) do
		local icon = card.icons[i]
		icon:SetTexture(slot.icon)
		icon:SetShown(slot.icon ~= nil)
		local tint = slot.placeholder and card.tint or { 1, 1, 1 }
		icon:SetVertexColor(tint[1], tint[2], tint[3])
	end
end

-- The Fishing set field's words: the chosen set's name, or None (QOL-R40), as the Fishing page's dropdown reads it.
---@return string
local function choiceLabel()
	local chosen = ns.FishingSetChoice()
	for _, option in ipairs(ns.ReadFishingSetOptions()) do
		if option.value == chosen then
			return option.label
		end
	end
	return ns.L.SETTINGS_FISHING_SET_NONE
end

-- The least scale the swap-back sample is drawn at on one strip, and the room between its two strips when it takes two
-- (ONB-R33); a strip is 26 tall.
local SAMPLE_FLOOR, SAMPLE_GAP, STRIP_HEIGHT = 0.5, 4, 26

-- `parts` split at the `n`th place a line can break: between two pieces, or at a space inside a piece of words. Nil
-- past the last such place.
---@param parts PagleQoLNudgePart[]
---@param n integer
---@return PagleQoLNudgePart[]? first
---@return PagleQoLNudgePart[]? second
local function splitAt(parts, n)
	local seen = 0
	for i, part in ipairs(parts) do
		if i > 1 then
			seen = seen + 1
			if seen == n then
				return { unpack(parts, 1, i - 1) }, { unpack(parts, i) }
			end
		end
		if type(part) == "string" then
			for space in part:gmatch("() ") do
				seen = seen + 1
				if seen == n then
					local first, second = { unpack(parts, 1, i - 1) }, { part:sub(space + 1):match("^%s*(.-)$") }
					first[#first + 1] = part:sub(1, space - 1):match("^(.-)%s*$")
					for j = i + 1, #parts do
						second[#second + 1] = parts[j]
					end
					return first, second
				end
			end
		end
	end
	return nil
end

-- Draws the swap-back Nudge as a sample (ONB-R33, QOL-R77) on its strip, drawn smaller, as the whole strip, when its
-- line is too long for the column. Smaller than SAMPLE_FLOOR, it is drawn on two strips instead, one under the other,
-- split where the longer of the two is shortest (between pieces or at a space), both at the one scale that fits it.
---@param pages PagleQoLClothesPages
local function drawSample(pages)
	local key = GetBindingKey("PAGLE_SWAP_GEAR")
	local parts = ns.SwapBackNudge(key and ns.ShortKeyText(key))
	local nudge, more = pages.nudge, pages.nudgeMore
	nudge:SetScale(1)
	more:SetScale(1)
	more:Hide()
	ns.DrawNudge(nudge, parts)
	local scale = ns.FitScale(nudge:GetWidth(), COLUMN)
	if scale < SAMPLE_FLOOR then
		local best, widest
		local n = 1
		local first, second = splitAt(parts, n)
		while first and second do
			if #first > 0 and #second > 0 and first[#first] ~= "" and second[1] ~= "" then
				ns.DrawNudge(nudge, first)
				ns.DrawNudge(more, second)
				local width = math.max(nudge:GetWidth(), more:GetWidth())
				if not widest or width < widest then
					best, widest = n, width
				end
			end
			n = n + 1
			first, second = splitAt(parts, n)
		end
		if best then
			first, second = splitAt(parts, best)
			ns.DrawNudge(nudge, first --[[@as PagleQoLNudgePart[] ]])
			ns.DrawNudge(more, second --[[@as PagleQoLNudgePart[] ]])
			scale = ns.FitScale(widest, COLUMN)
			more:SetScale(scale)
			local y = pages.nudgeY + (STRIP_HEIGHT + SAMPLE_GAP) * scale
			at(more, more:GetParent() --[[@as Region]], COLUMN_X / scale, y / scale)
			more:Show()
		else
			ns.DrawNudge(nudge, parts)
		end
	end
	nudge:SetScale(scale)
	at(nudge, nudge:GetParent() --[[@as Region]], COLUMN_X / scale, pages.nudgeY / scale)
end

-- Draws the Fishing clothes step as things are now: the two sets, Save and the field live unless restricted
-- (QOL-R41, ONB-R25), the chosen set, Save's message, and the sample Nudge with Swap gear's first key on its cap, or
-- its unbound line (QOL-R77).
local function refreshClothes()
	local pages = clothes
	if not pages then
		return
	end
	local sets = ns.ReadGuideSets()
	showSet(pages.previous, sets.previous)
	showSet(pages.fishing, sets.fishing)
	local live = ns.CanEditGear()
	setLive(pages.save, live)
	setLive(pages.dropdown, live)
	-- An open list closes as the field greys, and lists the sets as they are now.
	if not live then
		pages.list:Hide()
	elseif pages.list:IsShown() then
		openList(pages.list)
	end
	pages.choice:SetText(choiceLabel())
	pages.message:SetText(saveMessage or "")
	pages.message:SetShown(saveMessage ~= nil)
	at(
		pages.lower,
		pages.lower:GetParent() --[[@as Region]],
		0,
		pages.lowerY + (saveMessage and math.ceil(pages.message:GetStringHeight()) or 0)
	)
	drawSample(pages)
end

--- The Fishing set field's list: the field's paper, opened under it, a row per choice. It is the page's own, drawn as
--- the field promises, not the game's context menu, which is a dark tooltip box hung off the field's side.
---@class PagleQoLSetList: Frame
---@field field Button the field it opens under
---@field nav PagleGuideNav
---@field paper Texture the page's parchment under the field's panel, so nothing on the page shows through
---@field rows PagleQoLSetRow[] every row made, reused each time it opens

--- One choice in the list: a wash under the mouse, the choice cards' radio, and the set's name in the field's type.
---@class PagleQoLSetRow: Button
---@field wash Texture
---@field radio Texture
---@field radioOn Texture
---@field label FontString
---@field value integer the set ID it chooses, or ns.NO_FISHING_SET

-- The list's measures: a row's height, the paper's edge around the rows, the gap under the field, where a row's words
-- start (after its radio) and the room kept right of them.
local ROW_H, LIST_EDGE, LIST_GAP, ROW_TEXT_X, ROW_TEXT_END = 26, 3, 2, 32, 12
-- The page's parchment, which the list's paper is cut from (Core's media, as the fonts and the Field atlas are).
local PARCHMENT = "Interface\\AddOns\\Pagle\\media\\books\\Parchment"
-- A row under the mouse: the Journal search drop-down's wash, a warm brown at 12%.
local WASH = rgb("784614")
-- The owner of the list's watch on the mouse while it is open (a click outside it closes it).
local LIST_OWNER = "Pagle_QoL guide set list"

-- Shows a row at rest or under the mouse: the wash, and its words in the red pencil (as the guide's links go).
---@param row PagleQoLSetRow
---@param over boolean
local function paintRow(row, over)
	row.wash:SetShown(over)
	local ink = over and INKS.red or INKS.title
	row.label:SetTextColor(ink[1], ink[2], ink[3])
end

-- A text's full width, however wide the font string is set.
---@param text FontString
---@return number
local function fullWidth(text)
	if text.GetUnboundedStringWidth then
		return text:GetUnboundedStringWidth()
	end
	return text:GetStringWidth()
end

-- Row `i` of `list`: made the first time, reused after. A click chooses its set as the Fishing page's dropdown does
-- (QOL-R40, QOL-R42) and closes the list.
---@param list PagleQoLSetList
---@param i integer
---@return PagleQoLSetRow
local function rowOf(list, i)
	local row = list.rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, list) --[[@as PagleQoLSetRow]]
	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetColorTexture(WASH[1], WASH[2], WASH[3], 0.12)
	row.wash:SetAllPoints()
	row.radio = list.nav.Part(row, "radio")
	place(row.radio, row, 10.8, (ROW_H - 12) / 2)
	row.radioOn = list.nav.Part(row, "radio-on")
	place(row.radioOn, row, 10.8, (ROW_H - 12) / 2)
	row.label = write(row, "print", 14.5, "title", "", ROW_TEXT_X, (ROW_H - 18) / 2, 18)
	row:SetScript("OnEnter", function(self)
		paintRow(self, true)
	end)
	row:SetScript("OnLeave", function(self)
		paintRow(self, false)
	end)
	row:SetScript("OnClick", function(self)
		PlaySound(SOUND_CHECK, "SFX")
		list:Hide()
		ns.ChooseFishingSet(self.value)
		refreshClothes()
	end)
	list.rows[i] = row
	return row
end

-- Whether the mouse is over `list` or its field: the topmost frame under it is one of theirs.
---@param list PagleQoLSetList
---@return boolean
local function mouseOnList(list)
	local region = GetMouseFoci()[1]
	while region and not (region.IsForbidden and region:IsForbidden()) do
		if region == list or region == list.field then
			return true
		end
		region = region:GetParent()
	end
	return false
end

-- Fills the list with None and the character's sets, except *Pagle Previous* (QOL-R40), the chosen one's radio
-- filled, and opens it under its field: left-aligned with it and as wide, or wider to the left when a name needs it,
-- up to the column, so it never leaves the page (the field ends at the column's right edge). A name too long even then
-- is cut. While it is open, a click anywhere but on it or its field closes it.
function openList(list)
	local field = list.field
	local options = ns.ReadFishingSetOptions()
	local chosen = ns.FishingSetChoice()
	local widest = 0
	for i, option in ipairs(options) do
		local row = rowOf(list, i)
		row.value = option.value
		row.label:SetWidth(0)
		row.label:SetText(option.label)
		widest = math.max(widest, fullWidth(row.label))
		row.radio:SetShown(option.value ~= chosen)
		row.radioOn:SetShown(option.value == chosen)
		paintRow(row, false)
		row:Show()
	end
	for i = #options + 1, #list.rows do
		list.rows[i]:Hide()
	end
	local fieldWidth = field:GetWidth()
	local width = math.max(fieldWidth, math.ceil(widest) + ROW_TEXT_X + ROW_TEXT_END + 2 * LIST_EDGE)
	width = math.min(width, COLUMN)
	local height = #options * ROW_H + 2 * LIST_EDGE
	list:SetSize(width, height)
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", field, "BOTTOMLEFT", fieldWidth - width, -LIST_GAP)
	list.paper:SetTexCoord(0.05, 0.05 + width / 442, 0.3, math.min(1, 0.3 + height / 546))
	for i = 1, #options do
		local row = list.rows[i]
		row:SetSize(width - 2 * LIST_EDGE, ROW_H)
		at(row, list, LIST_EDGE, LIST_EDGE + (i - 1) * ROW_H)
		row.label:SetWidth(width - 2 * LIST_EDGE - ROW_TEXT_X - ROW_TEXT_END)
	end
	if not InCombatLockdown() then
		list:SetPropagateKeyboardInput(true)
	end
	list:Show()
	Pagle.RegisterEvent(LIST_OWNER, "GLOBAL_MOUSE_DOWN", function()
		if not mouseOnList(list) then
			list:Hide()
		end
	end)
end

-- The Fishing set field's list (see openList), on `parent` above the page's other controls, closed. Esc closes it and
-- goes no further; every other key goes on to the game. It closes as the page hides, so it is shut when the step
-- shows again.
---@param parent Frame
---@param field Button
---@param nav PagleGuideNav
---@return PagleQoLSetList
local function setList(parent, field, nav)
	local list = CreateFrame("Frame", nil, parent) --[[@as PagleQoLSetList]]
	list.field, list.nav, list.rows = field, nav, {}
	list:SetFrameLevel(parent:GetFrameLevel() + 30)
	list:EnableMouse(true)
	-- A shadow a little down and right, the page's parchment, and the field's panel over it.
	local shadow = list:CreateTexture(nil, "BACKGROUND", nil, -8)
	shadow:SetColorTexture(0.16, 0.09, 0.03, 0.22)
	shadow:SetPoint("TOPLEFT", 2, -3)
	shadow:SetPoint("BOTTOMRIGHT", 2, -3)
	list.paper = list:CreateTexture(nil, "BACKGROUND", nil, -7)
	list.paper:SetTexture(PARCHMENT)
	list.paper:SetAllPoints()
	nav.Panel(list, "field", 6)
	list:EnableKeyboard(true)
	list:SetScript("OnKeyDown", function(self, key)
		-- Only Esc stops here; the client blocks the call in combat, when the field is greyed and the list shut anyway.
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(key ~= "ESCAPE")
		end
		if key == "ESCAPE" then
			self:Hide()
		end
	end)
	list:SetScript("OnHide", function(self)
		Pagle.UnregisterEvent(LIST_OWNER, "GLOBAL_MOUSE_DOWN")
		-- Hidden with the page, it is shut too.
		self:Hide()
	end)
	list:Hide()
	return list
end

-- The Fishing set field (QOL-R40): the guide's field panel with the set's name and a caret; a click opens its list
-- under it (setList), or closes it.
---@param parent Frame
---@param nav PagleGuideNav
---@param y number its top on `parent`
---@return Button dropdown
---@return FontString choice
---@return PagleQoLSetList list
local function setField(parent, nav, y)
	local dropdown = CreateFrame("Button", nil, parent)
	dropdown:SetSize(272.8, 32)
	at(dropdown, parent, 139.2, y)
	nav.Panel(dropdown, "field", 6)
	local choice = write(dropdown, "print", 14.5, "title", "", 10.8, 7, 18)
	place(nav.Part(dropdown, "caret"), dropdown, 254.8, 9.3)
	local list = setList(parent, dropdown, nav)
	dropdown:SetScript("OnClick", function()
		PlaySound(SOUND_CLICK, "SFX")
		if list:IsShown() then
			list:Hide()
		else
			openList(list)
		end
	end)
	return dropdown, choice, list
end

-- Draws the Fishing clothes step's two pages, once (ONB-R33). Left: the two sets as cards, the arrows between them.
-- Right: Save what I'm wearing (QOL-R41) with its message under it (ONB-R105), the Fishing set field, the Swap gear
-- binding field, the slot note and the swap-back Nudge as a sample, on its own strip.
---@param left Frame
---@param right Frame
---@param nav PagleGuideNav
local function buildClothes(left, right, nav)
	local L = ns.L
	heading(left, L.GUIDE_CLOTHES_KICKER, L.GUIDE_CLOTHES_TITLE)
	local body = paragraph(left, L.GUIDE_CLOTHES_BODY, 85.4)
	-- the cards, the arrows and the line under them move down together when the paragraph wraps longer than the art's
	local down = math.max(0, below(body, 85.4, 15, 20.7) + 12 - 171.5)
	local previous = setCard(
		left,
		nav,
		36,
		171.5 + down,
		ns.PREVIOUS_SET_NAME,
		L.GUIDE_CLOTHES_PREVIOUS,
		PREVIOUS_PLACEHOLDERS,
		{ 0.85, 0.88, 0.95 }
	)
	local fishing = setCard(
		left,
		nav,
		268,
		171.5 + down,
		ns.FISHING_SET_NAME,
		L.GUIDE_CLOTHES_FISHING,
		FISHING_PLACEHOLDERS,
		{ 0.85, 1, 0.95 }
	)
	place(nav.Part(left, "arrows"), left, 212, 203 + down)
	write(left, "hand", 17, "hand", L.GUIDE_CLOTHES_ONE_KEY, 235, 233 + down, 17, { centre = true })
	paragraph(left, L.GUIDE_CLOTHES_SMALL, 302.1 + down, true)

	heading(right, L.GUIDE_SAVE_KICKER, L.GUIDE_SAVE_TITLE, 25)
	local small = paragraph(right, L.GUIDE_SAVE_SMALL, 75.3, true)
	-- Save, its message and all under it move down together when the paragraph wraps longer than the art's
	local lowerY = math.max(0, below(small, 75.3, 13.5, 18.225) + 8 - 126.7)
	local save = ns.NewNoteButton(right, L.GUIDE_SAVE, false, COLUMN)
	at(save, right, COLUMN_X, 126.7 + lowerY)
	save:SetScript("OnClick", function()
		PlaySound(SOUND_CLICK, "SFX")
		saveMessage = ns.SaveFishingSet()
		refreshClothes()
	end)
	local message = write(right, "italic", 13.5, "red", "", COLUMN_X, 174 + lowerY, 18, { width = COLUMN })
	message:Hide()
	local lower = CreateFrame("Frame", nil, right)
	lower:SetSize(right:GetWidth(), right:GetHeight())
	at(lower, right, 0, lowerY)
	-- "or use a set you made" sits left of the Fishing set field, set smaller when it is longer; when even that
	-- won't fit, it takes the column's width on its own and the field goes under it, and what follows moves down
	local orY, fieldY, shift = 189, 181.7, 0
	local orLine = write(lower, "italic", 13.5, "line", L.GUIDE_SAVE_OR, COLUMN_X, orY, 18)
	if not fit(orLine, "italic", 13.5, "line", OR_ROOM) then
		orLine:SetFontObject(ns.FaceFont("italic", 13.5))
		orLine:SetTextColor(INKS.line[1], INKS.line[2], INKS.line[3])
		orLine:SetWordWrap(true)
		orLine:SetWidth(COLUMN)
		orLine:SetSpacing(18 - 13.5)
		orY = 181.7
		at(orLine, lower, COLUMN_X, orY + (18 - 13.5) / 2)
		fieldY = below(orLine, orY, 13.5, 18) + 4
		shift = fieldY - 181.7
	end
	local dropdown, choice, list = setField(lower, nav, fieldY)
	local field = nav.BindingField(lower, "PAGLE_SWAP_GEAR", L.SETTINGS_SWAP_GEAR)
	at(field, lower, COLUMN_X, 231.7 + shift)
	local slotsY = 307.7 + shift
	local slots = write(lower, "italic", 13, "note", L.GUIDE_SAVE_SLOTS, COLUMN_X, slotsY, 17.55, { width = COLUMN })
	local kickerY = math.max(370 + shift, below(slots, slotsY, 13, 17.55) + 12)
	fit(write(lower, "sc", 14, "kicker", L.GUIDE_NUDGE_KICKER, COLUMN_X, kickerY, 14), "sc", 14, "kicker", COLUMN)
	local nudge = CreateFrame("Frame", nil, lower)
	nudge:SetFrameLevel(lower:GetFrameLevel() + 1)
	local nudgeMore = CreateFrame("Frame", nil, lower)
	nudgeMore:SetFrameLevel(lower:GetFrameLevel() + 1)
	nudgeMore:Hide()
	clothes = {
		previous = previous,
		fishing = fishing,
		save = save,
		message = message,
		lower = lower,
		lowerY = lowerY,
		dropdown = dropdown,
		choice = choice,
		list = list,
		field = field,
		nudge = nudge,
		nudgeMore = nudgeMore,
		nudgeY = kickerY + 20.8,
	}
	refreshClothes()
end

-- ---------------------------------------------------------------- registering

--- Registers QoL's two Field guide steps (ONB-R21): Casting at 30 and Fishing clothes at 40, whose skip link, "I don’t
--- keep fishing clothes", goes on to the next step (ONB-R33). Each shown step re-reads what may have changed since
--- (the bindings, Input, the sets; ONB-R44), and Fishing clothes drops Save's message as it is shown again: the message
--- stays only until the step is left (ONB-R105). While either is built, the bindings, the sets and restriction redraw
--- them. Called from OnInitialize only when `M.RegisterGuideStep` exists (ONB-R90); a QoL that is off registers
--- nothing, so neither step exists (ONB-R101).
---@param M PagleModuleHandle
function ns.RegisterGuideSteps(M)
	local L = ns.L
	M:RegisterGuideStep({
		id = "casting",
		order = ns.GUIDE_CASTING_ORDER,
		ribbon = L.GUIDE_CASTING_RIBBON,
		build = buildCasting,
		onShow = function()
			if casting then
				(casting.field --[[@as PagleGuideBindingField]]):Refresh()
			end
			refreshCasting()
		end,
	})
	M:RegisterGuideStep({
		id = "clothes",
		order = ns.GUIDE_CLOTHES_ORDER,
		ribbon = L.GUIDE_CLOTHES_RIBBON,
		skipLabel = L.GUIDE_CLOTHES_SKIP,
		skipTo = "next",
		build = buildClothes,
		onShow = function()
			saveMessage = nil
			if clothes then
				-- The step shows with its list shut.
				clothes.list:Hide()
				local field = clothes.field --[[@as PagleGuideBindingField]]
				field:Refresh()
			end
			refreshClothes()
		end,
	})
	local function refresh()
		refreshCasting()
		refreshClothes()
	end
	Pagle.RegisterEvent(OWNER, "UPDATE_BINDINGS", refresh)
	Pagle.RegisterEvent(OWNER, "EQUIPMENT_SETS_CHANGED", refreshClothes)
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", refreshClothes)
end

--- The Margin note the next-action button's first Lure shows (ONB-R52's `qol.lure`), on the button: Core shows it once
--- per account, and only on a Core with Margin notes (ONB-R90).
---@param target Region the next-action button
function ns.NoteFirstLure(target)
	local M = ns.Module
	if M and M.ShowMarginNote then
		M:ShowMarginNote({ id = "qol.lure", text = ns.L.NOTE_LURE, target = target })
	end
end
