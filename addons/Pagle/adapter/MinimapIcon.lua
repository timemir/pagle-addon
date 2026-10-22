---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Pagle's minimap icon (CORE-R53–R56): Core's own round button on the minimap's edge, PagleMinimapButton, beside the
-- compartment entry (adapter/Menu.lua). Together they are Pagle's menu. It embeds no library (CORE-R6). A left click
-- opens the compartment's menu, owned by the icon; the mouse over it shows the menu's tooltip. The player drags it
-- round the edge, by angle (logic/MinimapIcon.lua), never while restricted; its angle and shown state are kept in
-- PagleDB.global.minimap. Its own owner on the event frames, so no other Core file's registration replaces it.
local OWNER = "Pagle minimap icon"

-- The favicon, a gilt "P" on parchment: pagle-backend's favicon.ico, its 48 px image at 64 x 64
-- (scripts/encode-blp.py --raw).
local ICON = "Interface\\AddOns\\Pagle\\media\\minimap\\Pagle"
-- The usual minimap-button look, from the client's own textures, each listed in build 70338's ManifestInterfaceData
-- (CORE-R9): the round mask the icon is drawn through (130924, Interface\CHARACTERFRAME\TempPortraitAlphaMask.blp),
-- the tracking-border ring round it (136430, Interface\MINIMAP\minimap-trackingborder.blp), the dark disc behind
-- it (136467, Interface\MINIMAP\UI-Minimap-Background.blp) and the glow while the mouse is over it (136477,
-- Interface\MINIMAP\UI-Minimap-ZoomButton-Highlight.blp).
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- Its sizes, in the minimap's units: the button, the ring's texture (the ring fills the top left of its square
-- texture, so the texture hangs from the button's top left), and the disc and the icon, both centred.
local SIZE = 31
local RING_SIZE = 50
local BACKGROUND_SIZE = 24
local ICON_SIZE = 18
-- How far past the minimap's edge the button's centre sits.
local OUTSIDE = 5

---@type table?
local button

-- Puts the button at `angle` round the minimap's edge (CORE-R53).
---@param angle number
local function place(angle)
	assert(button)
	local x, y = ns.MinimapIconOffset(angle, Minimap:GetWidth() / 2 + OUTSIDE)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- The angle round the minimap's centre the cursor is at now, in the minimap's units at any UI scale.
---@return number
local function cursorAngle()
	local scale = Minimap:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local centerX, centerY = Minimap:GetCenter()
	return ns.MinimapAngle(cursorX / scale, cursorY / scale, centerX, centerY)
end

-- Ends a drag: the button stops following the cursor, and keeps the angle it was last put at.
---@param self table the button
local function stopDragging(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end

-- Each frame of a drag: the button follows the cursor round the edge and saves where it is. Restriction starting
-- mid-drag ends the drag where the button is (CORE-R53).
---@param self table the button
local function followCursor(self)
	if Pagle.IsRestricted() then
		stopDragging(self)
		return
	end
	local angle = cursorAngle()
	ns.db.global.minimap.angle = angle
	place(angle)
end

-- A left-button drag starts: never while restricted (CORE-R53). The tooltip goes while it is dragged.
---@param self table the button
local function startDragging(self)
	ns.HideMenuTooltip(self)
	if Pagle.IsRestricted() then
		return
	end
	self:LockHighlight()
	self:SetScript("OnUpdate", followCursor)
end

-- A left click opens Pagle's menu at once, owned by the icon, so hiding the icon closes it; other buttons do nothing
-- (CORE-R54). Unlike the compartment's, no menu of the client's closes after the click. It opens while restricted
-- too, as the compartment's does.
---@param self table the button
---@param mouseButton string
local function onClick(self, mouseButton)
	if mouseButton == "LeftButton" then
		ns.OpenMenu(self)
	end
end

-- The button in the usual minimap-button look: the dark disc, the favicon through the round mask, the ring over
-- both, and the glow while the mouse is over it (CORE-R53).
---@return table
local function makeButton()
	local made = CreateFrame("Button", "PagleMinimapButton", Minimap)
	made:SetSize(SIZE, SIZE)
	made:SetFrameStrata("MEDIUM")
	made:SetFrameLevel(8)
	made:RegisterForClicks("AnyUp")
	made:RegisterForDrag("LeftButton")
	made:SetHighlightTexture(HIGHLIGHT)

	local background = made:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(BACKGROUND)
	background:SetSize(BACKGROUND_SIZE, BACKGROUND_SIZE)
	background:SetPoint("CENTER")

	local icon = made:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("CENTER")
	local mask = made:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)

	local ring = made:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING)
	ring:SetSize(RING_SIZE, RING_SIZE)
	ring:SetPoint("TOPLEFT")

	made:SetScript("OnClick", onClick)
	made:SetScript("OnDragStart", startDragging)
	made:SetScript("OnDragStop", stopDragging)
	made:SetScript("OnEnter", function(self)
		ns.ShowMenuTooltip(self, "ANCHOR_LEFT")
	end)
	made:SetScript("OnLeave", ns.HideMenuTooltip)
	return made
end

-- At login, once, with PagleDB open: the button, placed and shown or hidden as PagleDB.global.minimap says
-- (CORE-R53, CORE-R56).
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	button = makeButton()
	local saved = ns.db.global.minimap
	place(saved.angle)
	button:SetShown(not saved.hide)
end)

--- Whether Show the minimap icon is on (CORE-R56, SET-R10 row 10): PagleDB.global.minimap.hide is off.
---@return boolean
function ns.IsMinimapIconShown()
	return not ns.db.global.minimap.hide
end

--- Shows or hides the minimap icon at once and keeps the choice in PagleDB.global.minimap (CORE-R56). Nothing else
--- changes: the compartment entry stays. Pagle's menu button changes with it, so ns.MenuButtonChanged is called.
---@param shown boolean
function ns.SetMinimapIconShown(shown)
	ns.db.global.minimap.hide = not shown
	if button then
		button:SetShown(shown)
	end
	ns.MenuButtonChanged()
end

--- Pagle's menu button (ONB-R52), what a note meant for Pagle's menu points at: the minimap icon's button while it
--- shows (CORE-R53), else the Addon Compartment's button (ONB-R108), as before login. Read it each time a note is
--- placed: Show the minimap icon changes it.
---@return table
function ns.MenuButton()
	if button and button:IsShown() then
		return button
	end
	return AddonCompartmentFrame
end

--- Called each time Show the minimap icon changes Pagle's menu button (ONB-R108). Does nothing until Margin notes
--- exist: their file (#325) replaces this function with one that moves the arrow of a note meant for the menu button,
--- if one shows (ONB-R56).
function ns.MenuButtonChanged() end
