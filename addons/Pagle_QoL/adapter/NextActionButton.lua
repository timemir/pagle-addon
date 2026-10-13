if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The next-action button (QOL-R70–R74): a small frame in the action-button look that shows what the next press will
-- do, drawn from each of the Fishing key's evaluations (adapter/FishingKey.lua) and decided by
-- logic/NextActionButton.lua. It is display only and not secure (QOL-R73): it changes only frames (QOL-R5), and what
-- it reads, it uses only to show the next action (QOL-R4).

-- The border Blizzard's action buttons draw round a 36 px icon (ActionButtonTemplate's NormalTexture, 66 px).
local BORDER = "Interface\\Buttons\\UI-Quickslot2"
local BORDER_SIZE = 66

-- The button, made the first time it shows; a plain frame, so combat never stops it.
local button ---@type Frame?
local icon ---@type Texture
local hotKey ---@type FontString
local label ---@type FontString
local lastIcon ---@type integer? the icon shown last, which *nothing* keeps (QOL-R71)
-- What the button shows now: the action, and the lure or the fishing set it names (QOL-R74).
local current = { action = "nothing" } ---@type { action: PagleQoLAction, lure: integer?, setID: integer? }
local moving = false -- a Shift-drag is moving it (QOL-R73)
local hovering = false -- the mouse is over it, so its tooltip follows the next action (QOL-R74)
local waitingFor ---@type integer? the item whose data the tooltip waits for (QOL-R74)

-- Puts the button at its saved place, or the default (QOL-R73).
local function place()
	---@cast button Frame
	local point = ns.ButtonPoint(ns.db.profile.indicator.point)
	button:ClearAllPoints()
	button:SetPoint(point.point, UIParent, point.relativePoint, point.x, point.y)
end

-- Ends a Shift-drag: the button stays where it was let go, saved relative to UIParent (QOL-R73).
local function stopMoving()
	if not moving then
		return
	end
	---@cast button Frame
	moving = false
	button:StopMovingOrSizing()
	local point, _, relativePoint, x, y = button:GetPoint(1)
	ns.db.profile.indicator.point = ns.SavedButtonPoint(point, relativePoint, x, y)
	place()
end

-- The name the tooltip needs for the action shown: the fishing set's, or the lure's from C_Item; nil for none, or
-- while the lure's data hasn't loaded.
---@return string?
local function tooltipName()
	if current.action == "gear" and current.setID then
		return (C_EquipmentSet.GetEquipmentSetInfo(current.setID))
	elseif current.action == "lure" and current.lure then
		return C_Item.GetItemNameByID(current.lure)
	end
	return nil
end

-- Shows the tooltip naming the next action (QOL-R74). A lure whose name isn't cached is waited for with
-- Item:ContinueOnItemLoad; the tooltip shows once it loads, if the mouse is still over the button.
local function showTooltip()
	---@cast button Frame
	local text = ns.ButtonTooltip(current.action, tooltipName())
	if text then
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(text)
		GameTooltip:Show()
		return
	end
	-- Nothing to show yet: no tooltip of an earlier action stays up.
	if GameTooltip:IsOwned(button) then
		GameTooltip:Hide()
	end
	local lure = current.lure
	if current.action == "lure" and lure and waitingFor ~= lure then
		waitingFor = lure
		Item:CreateFromItemID(lure):ContinueOnItemLoad(function()
			waitingFor = nil
			if hovering and current.action == "lure" and current.lure == lure then
				showTooltip()
			end
		end)
	end
end

-- Makes the button the first time it shows (QOL-R70): the icon, the action-button border, the hotkey text at its top
-- right and the label under it. The mouse shows the tooltip (QOL-R74) and Shift-drags it (QOL-R73); a click does
-- nothing, as it has no click script. It has no name, so it adds no global (QOL-R5) and the client's layout cache
-- never keeps its place: QoL keeps that itself (QOL-R73).
local function ensureButton()
	if button then
		return
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	button = frame
	frame:SetSize(ns.BUTTON_SIZE, ns.BUTTON_SIZE)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	local border = frame:CreateTexture(nil, "OVERLAY")
	border:SetTexture(BORDER)
	border:SetSize(BORDER_SIZE, BORDER_SIZE)
	border:SetPoint("CENTER", 0, -1)
	hotKey = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	hotKey:SetPoint("TOPRIGHT", -2, -3)
	label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", frame, "BOTTOM", 0, -2)
	-- The parent keys Blizzard's action buttons use, so /fstack and the specs find each part.
	frame.Icon, frame.HotKey, frame.Label = icon, hotKey, label

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
	frame:SetScript("OnLeave", function(self)
		hovering = false
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	place()
end

-- The Fishing key's first bound key as action bars show it (QOL-R70).
---@param key string
---@return string
local function shortText(key)
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
	if hovering and GameTooltip:IsOwned(button) then
		GameTooltip:Hide()
	end
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
	---@cast button Frame

	local action = ns.NextAction(state)
	local icons = { fishing = (C_Spell.GetSpellTexture(ns.FISHING_SPELL_ID)) }
	local setID
	if action == "gear" then
		setID = ns.FishingSetChoice()
		icons.set = select(2, C_EquipmentSet.GetEquipmentSetInfo(setID))
	elseif action == "lure" and state.lure then
		icons.item = C_Item.GetItemIconByID(state.lure)
	end
	local look = ns.ButtonLook(action, icons, lastIcon)
	lastIcon = look.icon
	icon:SetTexture(look.icon)
	icon:SetDesaturated(look.desaturated)
	label:SetText(look.label or "")
	label:SetShown(look.label ~= nil)
	local hotkey = ns.ButtonHotkey(ns.CurrentInput(), keys, shortText)
	hotKey:SetText(hotkey or "")
	hotKey:SetShown(hotkey ~= nil)
	button:Show()

	current = { action = action, lure = state.lure, setID = setID }
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
