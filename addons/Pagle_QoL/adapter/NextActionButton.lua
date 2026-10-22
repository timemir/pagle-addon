if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The next-action button (QOL-R70–R74): a small frame that shows what the next press will do, drawn from each of the
-- Fishing key's evaluations (adapter/FishingKey.lua) and decided by logic/NextActionButton.lua. It is display only and
-- not secure (QOL-R73): it changes only frames (QOL-R5), and what it reads, it uses only to show the next action
-- (QOL-R4). The secure button the Fishing key clicks is another, hidden one (PagleQoLActionButton, adapter/
-- FishingKey.lua), which this file never touches. The look is the field art kit's (adapter/FieldArt.lua): the icon
-- round in a brass bezel, the Fishing key on a brass key cap over the bezel's top left, the one-word label on a slip
-- of paper tucked under it, and a lacquer tooltip with a gilt hairline.

--- The button: the bezel's frame, with its parts under the keys Blizzard's action buttons use, so /fstack and the
--- specs find each part.
---@class PagleQoLNextActionButton: Frame
---@field Ring PagleSprite the brass bezel
---@field Icon Texture the next action's icon, round inside it
---@field HotKey FontString the Fishing key, on its key cap
---@field KeyCap PagleQoLKeyCap
---@field Label FontString the one-word label, on its slip of paper
---@field Paper PagleThreeSlice the slip, under the bezel
---@field Tooltip PagleQoLButtonTooltip

--- The lacquer tooltip: one line in gilt on a dark ground, in a gilt hairline.
---@class PagleQoLButtonTooltip: Frame
---@field Text FontString

-- The button, made the first time it shows; a plain frame, so combat never stops it.
local button ---@type PagleQoLNextActionButton?
local face ---@type PagleQoLButtonFace its face, made with it
local tooltip ---@type PagleQoLButtonTooltip
local lastIcon ---@type integer? the icon shown last, which *nothing* keeps (QOL-R71)
-- What the button shows now: the action, and the lure, the clam or the fishing set it names (QOL-R74).
local current = { action = "nothing" } ---@type { action: PagleQoLAction, lure: integer?, clam: integer?, setID: integer? }
local moving = false -- a Shift-drag is moving it (QOL-R73)
local hovering = false -- the mouse is over it, so its tooltip follows the next action (QOL-R74)
local waitingFor ---@type integer? the item whose data the tooltip waits for (QOL-R74)

-- Puts the button at its saved place, or the default (QOL-R73).
local function place()
	---@cast button PagleQoLNextActionButton
	local point = ns.ButtonPoint(ns.db.profile.indicator.point)
	button:ClearAllPoints()
	button:SetPoint(point.point, UIParent, point.relativePoint, point.x, point.y)
end

-- Ends a Shift-drag: the button stays where it was let go, saved relative to UIParent (QOL-R73).
local function stopMoving()
	if not moving then
		return
	end
	---@cast button PagleQoLNextActionButton
	moving = false
	button:StopMovingOrSizing()
	local point, _, relativePoint, x, y = button:GetPoint(1)
	ns.db.profile.indicator.point = ns.SavedButtonPoint(point, relativePoint, x, y)
	place()
end

-- The item the action shown uses: the lure for a lure, the clam for a clam; nil for any other action.
---@return integer?
local function currentItem()
	if current.action == "lure" then
		return current.lure
	elseif current.action == "clam" then
		return current.clam
	end
	return nil
end

-- The name the tooltip needs for the action shown: the fishing set's, or the lure's or the clam's from C_Item; nil for
-- none, or while the item's data hasn't loaded.
---@return string?
local function tooltipName()
	local item = currentItem()
	if current.action == "gear" and current.setID then
		return (C_EquipmentSet.GetEquipmentSetInfo(current.setID))
	elseif item then
		return C_Item.GetItemNameByID(item)
	end
	return nil
end

-- Shows the tooltip naming the next action (QOL-R74). A lure or clam whose name isn't cached is waited for with
-- Item:ContinueOnItemLoad; the tooltip shows once it loads, if the mouse is still over the button.
local function showTooltip()
	local text = ns.ButtonTooltip(current.action, tooltipName())
	if text then
		tooltip.Text:SetText(text)
		tooltip:SetSize(tooltip.Text:GetStringWidth() + 28, 34)
		tooltip:Show()
		return
	end
	-- Nothing to show yet: no tooltip of an earlier action stays up.
	tooltip:Hide()
	local item = currentItem()
	if item and waitingFor ~= item then
		waitingFor = item
		Item:CreateFromItemID(item):ContinueOnItemLoad(function()
			waitingFor = nil
			if hovering and currentItem() == item then
				showTooltip()
			end
		end)
	end
end

-- The lacquer tooltip (QOL-R74), beside the bezel: hidden until the mouse is over the button.
---@param frame PagleQoLNextActionButton
---@return PagleQoLButtonTooltip
local function newTooltip(frame)
	local made = CreateFrame("Frame", nil, frame) --[[@as PagleQoLButtonTooltip]]
	made:SetFrameStrata("TOOLTIP")
	made:SetClampedToScreen(true)
	made:SetPoint("LEFT", frame, "RIGHT", 12, 0)
	local inks = ns.FIELD_INKS
	local edge = made:CreateTexture(nil, "BACKGROUND", nil, 0)
	edge:SetColorTexture(inks.hairline[1], inks.hairline[2], inks.hairline[3], 1)
	edge:SetAllPoints()
	local ground = made:CreateTexture(nil, "BACKGROUND", nil, 1)
	ground:SetColorTexture(inks.lacquer[1], inks.lacquer[2], inks.lacquer[3], 1)
	ground:SetPoint("TOPLEFT", 1, -1)
	ground:SetPoint("BOTTOMRIGHT", -1, 1)
	made.Text = ns.ArtText(made, "Tip")
	made.Text:SetPoint("LEFT", 14, 0)
	made:Hide()
	return made
end

--- The button's face (QOL-R70, QOL-R71), as the next-action button and the Field guide's Casting step draw it: the
--- brass bezel, the icon round in it, the paper label under it and the key cap over its top left.
---@class PagleQoLButtonFace
---@field Ring PagleSprite the brass bezel
---@field Icon Texture the next action's icon, round inside it
---@field Paper PagleThreeSlice the label's slip, under the bezel
---@field Label FontString the one-word label
---@field KeyCap PagleQoLKeyCap the Fishing key's brass cap
---@field HotKey FontString the key on it

--- Draws the button's face on `frame`, a bezel's size (52 px), the field art kit's look (QOL-R70): the brass bezel
--- with the icon round in it and the gloss over it, the label's slip tucked 6 px under it and the key cap over its top
--- left, each in a frame a level above the last, as they hang over its edges.
---@param frame Frame
---@return PagleQoLButtonFace
function ns.DrawButtonFace(frame)
	frame:SetSize(ns.BUTTON_BEZEL, ns.BUTTON_BEZEL)
	local ring = ns.ArtSprite(frame, "Field", "bezel-52", "ARTWORK", 0)
	ns.CenterSprite(ring, frame)
	local icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	icon:SetSize(ns.BUTTON_SIZE, ns.BUTTON_SIZE)
	icon:SetPoint("CENTER")
	local mask = frame:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	local gloss = ns.ArtSprite(frame, "Field", "gloss-52", "ARTWORK", 2)
	ns.CenterSprite(gloss, frame)
	local paper = CreateFrame("Frame", nil, frame) --[[@as PagleThreeSlice]]
	paper:SetFrameLevel(frame:GetFrameLevel() + 1)
	paper:SetPoint("TOP", frame, "BOTTOM", 0, 6)
	local words = ns.ArtText(paper, "Label")
	words:SetJustifyH("CENTER")
	words:SetPoint("CENTER", paper, "CENTER", 0, 1)
	local keyCap = ns.NewKeyCap(frame, "Key")
	keyCap:SetFrameLevel(frame:GetFrameLevel() + 2)
	keyCap:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 4)
	return { Ring = ring, Icon = icon, Paper = paper, Label = words, KeyCap = keyCap, HotKey = keyCap.Text }
end

--- Shows `look` on a face (QOL-R71): its icon, *nothing* greying the brass with the icon as the kit's idle button,
--- the label on its slip or none, and `hotkey` on its key cap or no cap (QOL-R70).
---@param drawn PagleQoLButtonFace
---@param look PagleQoLButtonLook
---@param hotkey string?
function ns.SetButtonFace(drawn, look, hotkey)
	drawn.Icon:SetTexture(look.icon)
	local grey = look.desaturated and 0.75 or 1
	for _, region in ipairs({ drawn.Icon, drawn.Ring }) do
		region:SetDesaturated(look.desaturated)
		region:SetVertexColor(grey, grey, grey)
	end
	drawn.Label:SetText(look.label or "")
	drawn.Label:SetShown(look.label ~= nil)
	drawn.Paper:SetShown(look.label ~= nil)
	if look.label then
		ns.SetThreeSlice(drawn.Paper, "Field", "label", ns.LabelWidth(drawn.Label:GetStringWidth()), 8, "ARTWORK")
	end
	drawn.HotKey:SetShown(hotkey ~= nil)
	drawn.KeyCap:SetShown(hotkey ~= nil)
	if hotkey then
		drawn.HotKey:SetText(hotkey)
		ns.SetKeyCap(drawn.KeyCap, hotkey, ns.KeyCapWidth(drawn.HotKey:GetStringWidth()), 18)
	else
		drawn.HotKey:SetText("")
	end
end

-- Makes the button the first time it shows (QOL-R70): its face (ns.DrawButtonFace) and the tooltip. The mouse shows
-- the tooltip (QOL-R74) and Shift-drags it (QOL-R73); a click does nothing, as it has no click script. It has no
-- name, so it adds no global (QOL-R5) and the client's layout cache never keeps its place: QoL keeps that itself
-- (QOL-R73).
local function ensureButton()
	if button then
		return
	end
	local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleQoLNextActionButton]]
	button = frame
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	face = ns.DrawButtonFace(frame)
	frame.Ring, frame.Icon, frame.Paper, frame.KeyCap = face.Ring, face.Icon, face.Paper, face.KeyCap
	frame.HotKey, frame.Label = face.HotKey, face.Label
	tooltip = newTooltip(frame)
	frame.Tooltip = tooltip

	frame:SetScript("OnDragStart", function(self)
		if IsShiftKeyDown() and not Pagle.IsRestricted() then
			moving = true
			self:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", stopMoving)
	frame:SetScript("OnEnter", function()
		hovering = true
		showTooltip()
	end)
	frame:SetScript("OnLeave", function()
		hovering = false
		tooltip:Hide()
	end)
	place()
end

--- A bound key as action bars show it, in its short form (QOL-R70): the next-action button's key cap, and the Field
--- guide's samples of it.
---@param key string
---@return string
function ns.ShortKeyText(key)
	-- The second argument asks for the short form, as the game's action buttons pass it (Gethe/wow-ui-source branch
	-- forever, Blizzard_ActionBar/Shared/ActionButton.lua: `GetBindingText(key, 1)`).
	---@diagnostic disable-next-line: param-type-mismatch -- the annotations name it a prefix string
	return GetBindingText(key, true)
end

-- Hides the button, and its tooltip with it.
local function hide()
	if not button then
		return
	end
	stopMoving()
	button:Hide()
	tooltip:Hide()
	hovering = false
end

--- Shows the next action for an evaluation of the Fishing key (QOL-R70–R72), which calls it each time it evaluates,
--- restricted or not. `state` is the ladder state it evaluated, `{ armed = false }` while disarmed, so restricted it
--- shows *nothing*; then the pole and the gear step are read here, which has no side effect (QOL-R72).
---@param state PagleQoLLadderState
---@param keys string[] the Fishing key's bound keys
function ns.ShowNextAction(state, keys)
	local pole, gearReady = state.poleInHand == true, state.gearReady == true
	if not state.armed then
		pole = ns.PoleInHand()
		gearReady = ns.ReadGearStep(pole)
	end
	-- Restriction stops a Shift-drag where it got to (QOL-R73).
	if Pagle.IsRestricted() then
		stopMoving()
	end
	local visible = ns.ButtonShown({
		setting = ns.db.profile.indicator.shown,
		standingDown = ns.IsStandingDown(),
		stretch = ns.RunningStretch() ~= nil,
		poleInHand = pole,
		gearReady = gearReady,
	})
	if not visible then
		hide()
		return
	end
	ensureButton()
	---@cast button PagleQoLNextActionButton

	local action = ns.NextAction(state)
	local icons = { fishing = (C_Spell.GetSpellTexture(ns.FISHING_SPELL_ID)) }
	local setID
	if action == "gear" then
		setID = ns.FishingSetChoice()
		icons.set = select(2, C_EquipmentSet.GetEquipmentSetInfo(setID))
	elseif action == "lure" and state.lure then
		icons.item = C_Item.GetItemIconByID(state.lure)
	elseif action == "clam" and state.clam then
		icons.item = C_Item.GetItemIconByID(state.clam)
	end
	local look = ns.ButtonLook(action, icons, lastIcon)
	lastIcon = look.icon
	ns.SetButtonFace(face, look, ns.ButtonHotkey(ns.CurrentInput(), keys, ns.ShortKeyText))
	button:Show()

	-- The first Lure it shows explains itself with a Margin note, once per account (ONB-R52's qol.lure): asked at each
	-- turn to Lure, as Core shows it only the first time.
	if action == "lure" and current.action ~= "lure" then
		ns.NoteFirstLure(button)
	end
	current = { action = action, lure = state.lure, clam = state.clam, setID = setID }
	if hovering then
		showTooltip()
	end
end

--- The Button position row's Reset (QOL-R73): back to the default place, bottom centre 230 px up.
function ns.ResetNextActionButton()
	ns.db.profile.indicator.point = nil
	if button then
		place()
	end
end
