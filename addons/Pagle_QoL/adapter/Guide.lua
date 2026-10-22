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

-- A page's kicker and title (the kit's kicker and title): small caps over IM Fell English at `size` (29, the right
-- page's 25).
---@param page Frame
---@param kicker string
---@param title string
---@param size number?
local function heading(page, kicker, title, size)
	size = size or 29
	write(page, "sc", 14, "kicker", kicker, COLUMN_X, 24, 14)
	write(page, "print", size, "title", title, COLUMN_X, 41, size * 1.05)
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
---@return { on: Texture, off: Texture }
local function buttonCheck(parent, nav)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(COLUMN, 36)
	at(row, parent, COLUMN_X, 374.5)
	local check = { on = nav.Part(row, "check"), off = nav.Part(row, "check-off") }
	place(check.on, row, 0, 2)
	place(check.off, row, 0, 2)
	write(row, "print", 15.5, "title", ns.L.SETTINGS_SHOW_BUTTON, 25, 0, 18.6)
	write(row, "italic", 13, "line", ns.L.SETTINGS_SHOW_BUTTON_TOOLTIP, 25, 18.6, 16.9)
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
	for i, press in ipairs(sequence) do
		local x = 34 + (i - 1) * 97.6
		local frame = CreateFrame("Frame", nil, left)
		frame:SetFrameLevel(left:GetFrameLevel() + 3)
		faces[i] = { face = ns.DrawButtonFace(frame), action = press.action }
		at(frame, left, x + 13, 173.5)
		write(left, "italic", 12.5, "line", press.caption, x + 39, 263.5, 15.625, { width = 78, centre = true })
		if i < #sequence then
			write(left, "hand", 26, "kicker", L.GUIDE_CASTING_THEN, x + 87.8, 191.5, 33, { centre = true })
		end
	end
	paragraph(left, L.GUIDE_CASTING_SMALL, 320.8, true)
	nav.Note(left, L.GUIDE_CASTING_NOTE, 56, 400, 300)

	heading(right, L.GUIDE_CHOICE_KICKER, L.GUIDE_CHOICE_TITLE, 25)
	local resting = write(right, "italic", 13.5, "red", "", COLUMN_X, 70, 18, { width = COLUMN })
	resting:Hide()
	local body = CreateFrame("Frame", nil, right)
	body:SetSize(right:GetWidth(), right:GetHeight())
	at(body, right, 0, 0)
	local cards = {}
	local tops = { 81.3, 151, 220.8 }
	for i, choice in ipairs(ns.InputCards()) do
		local card = nav.ChoiceCard(body, choice.title, choice.line, choice.tag)
		card:SetSize(COLUMN, 61.8)
		at(card, body, COLUMN_X, tops[i])
		card:HookScript("OnClick", function()
			ns.SetInput(choice.input)
			refreshCasting()
		end)
		cards[i] = { card = card, input = choice.input }
	end
	local field = nav.BindingField(body, "PAGLE_FISHING_KEY", L.SETTINGS_FISHING_KEY)
	at(field, body, COLUMN_X, 298.5)
	casting = {
		faces = faces,
		cards = cards,
		field = field,
		check = buttonCheck(body, nav),
		resting = resting,
		body = body,
	}
	refreshCasting()
end

-- ---------------------------------------------------------------- Fishing clothes (ONB-R33, board 5)

--- One set card on the Fishing clothes step: its name and four slots.
---@class PagleQoLSetCard
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
---@field dropdown Button the Fishing set field
---@field choice FontString the set it shows
---@field field Frame the Swap gear binding field (nav.BindingField)
---@field nudge Frame the swap-back Nudge's sample strip

local clothes ---@type PagleQoLClothesPages?
-- Save's message while it shows: kept until the step is left (ONB-R105).
local saveMessage ---@type string?

-- A set card on `page` at `x` (the kit's kit()): the guide's card panel, the set's name in small caps, four slots
-- (each an icon in the atlas's slot ring) and its line in italic.
---@param page Frame
---@param nav PagleGuideNav
---@param x number
---@param default string
---@param line string
---@param placeholders string[]
---@param tint number[]
---@return PagleQoLSetCard
local function setCard(page, nav, x, default, line, placeholders, tint)
	local frame = CreateFrame("Frame", nil, page)
	frame:SetSize(166, 108.6)
	at(frame, page, x, 171.5)
	frame:SetFrameLevel(page:GetFrameLevel() + 1)
	nav.Panel(frame, "card", 6)
	local card = {
		name = write(frame, "sc", 15, "title", default, 83, 11, 19, { centre = true }),
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
	write(frame, "italic", 12.5, "line", line, 83, 80, 15.6, { centre = true })
	return card
end

-- Shows a set on its card (ONB-R33): its name and real items, an empty slot showing none, or the drawn placeholders
-- while it doesn't exist.
---@param card PagleQoLSetCard
---@param set PagleQoLGuideSet?
local function showSet(card, set)
	card.name:SetText(set and set.name or card.default)
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
	pages.choice:SetText(choiceLabel())
	pages.message:SetText(saveMessage or "")
	pages.message:SetShown(saveMessage ~= nil)
	at(
		pages.lower,
		pages.lower:GetParent() --[[@as Region]],
		0,
		saveMessage and math.ceil(pages.message:GetStringHeight()) or 0
	)
	local key = GetBindingKey("PAGLE_SWAP_GEAR")
	local nudge = pages.nudge
	nudge:SetScale(1)
	ns.DrawNudge(nudge, ns.SwapBackNudge(key and ns.ShortKeyText(key)))
	-- A line too long for the column is drawn smaller, as the whole strip.
	local scale = ns.FitScale(nudge:GetWidth(), COLUMN)
	nudge:SetScale(scale)
	at(nudge, nudge:GetParent() --[[@as Region]], COLUMN_X / scale, 390.8 / scale)
end

-- The Fishing set field (QOL-R40): the guide's field panel with the set's name and a caret; a click lists None and the
-- character's sets, except *Pagle Previous*, and a pick chooses it as the Fishing page's dropdown does (QOL-R42).
---@param parent Frame
---@param nav PagleGuideNav
---@return Button dropdown
---@return FontString choice
local function setField(parent, nav)
	local dropdown = CreateFrame("Button", nil, parent)
	dropdown:SetSize(272.8, 32)
	at(dropdown, parent, 139.2, 181.7)
	nav.Panel(dropdown, "field", 6)
	local choice = write(dropdown, "print", 14.5, "title", "", 10.8, 7, 18)
	place(nav.Part(dropdown, "caret"), dropdown, 254.8, 9.3)
	dropdown:SetScript("OnClick", function(self)
		PlaySound(SOUND_CLICK, "SFX")
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, option in ipairs(ns.ReadFishingSetOptions()) do
				root:CreateButton(option.label, function()
					ns.ChooseFishingSet(option.value)
					refreshClothes()
				end)
			end
		end)
	end)
	return dropdown, choice
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
	paragraph(left, L.GUIDE_CLOTHES_BODY, 85.4)
	local previous = setCard(
		left,
		nav,
		36,
		ns.PREVIOUS_SET_NAME,
		L.GUIDE_CLOTHES_PREVIOUS,
		PREVIOUS_PLACEHOLDERS,
		{ 0.85, 0.88, 0.95 }
	)
	local fishing =
		setCard(left, nav, 268, ns.FISHING_SET_NAME, L.GUIDE_CLOTHES_FISHING, FISHING_PLACEHOLDERS, { 0.85, 1, 0.95 })
	place(nav.Part(left, "arrows"), left, 212, 203)
	write(left, "hand", 17, "hand", L.GUIDE_CLOTHES_ONE_KEY, 235, 233, 17, { centre = true })
	paragraph(left, L.GUIDE_CLOTHES_SMALL, 302.1, true)

	heading(right, L.GUIDE_SAVE_KICKER, L.GUIDE_SAVE_TITLE, 25)
	paragraph(right, L.GUIDE_SAVE_SMALL, 75.3, true)
	local save = ns.NewNoteButton(right, L.GUIDE_SAVE, false, COLUMN)
	at(save, right, COLUMN_X, 126.7)
	save:SetScript("OnClick", function()
		PlaySound(SOUND_CLICK, "SFX")
		saveMessage = ns.SaveFishingSet()
		refreshClothes()
	end)
	local message = write(right, "italic", 13.5, "red", "", COLUMN_X, 174, 18, { width = COLUMN })
	message:Hide()
	local lower = CreateFrame("Frame", nil, right)
	lower:SetSize(right:GetWidth(), right:GetHeight())
	at(lower, right, 0, 0)
	write(lower, "italic", 13.5, "line", L.GUIDE_SAVE_OR, COLUMN_X, 189, 18)
	local dropdown, choice = setField(lower, nav)
	local field = nav.BindingField(lower, "PAGLE_SWAP_GEAR", L.SETTINGS_SWAP_GEAR)
	at(field, lower, COLUMN_X, 231.7)
	write(lower, "italic", 13, "note", L.GUIDE_SAVE_SLOTS, COLUMN_X, 307.7, 17.55, { width = COLUMN })
	write(lower, "sc", 14, "kicker", L.GUIDE_NUDGE_KICKER, COLUMN_X, 370, 14)
	local nudge = CreateFrame("Frame", nil, lower)
	nudge:SetFrameLevel(lower:GetFrameLevel() + 1)
	clothes = {
		previous = previous,
		fishing = fishing,
		save = save,
		message = message,
		lower = lower,
		dropdown = dropdown,
		choice = choice,
		field = field,
		nudge = nudge,
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
				(clothes.field --[[@as PagleGuideBindingField]]):Refresh()
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
