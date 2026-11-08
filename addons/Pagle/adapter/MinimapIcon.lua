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
-- opens the compartment's menu, owned by the icon while its parent is the one Pagle gave it, else by nothing
-- (CORE-R54); the mouse over it shows the menu's tooltip. The player drags it round the edge, by angle
-- (logic/MinimapIcon.lua), never while restricted; its angle and shown state are kept in PagleDB.global.minimap.
-- From 1.5, "Detach from the minimap" moves it onto UIParent, where a plain left-drag takes it anywhere on the screen,
-- kept whole on it; its spot is kept there too, as fractions of the screen (`point`). Its own owner on the event
-- frames, so no other Core file's registration replaces it.
local OWNER = "Pagle minimap icon"

-- From 1.5.1 the icon is drawn in one of three styles the player picks (CORE-R53, SET-R10 row 10b), at 80% to 150%
-- of its size (row 10c). Both are kept in PagleDB.global.minimap, `style` and `scale`, with no default there: nil, as
-- an unreadable value, means ns.MINIMAP_ICON_STYLE_DEFAULT at 100% (logic/Migrations.lua is hashed, so a 1.5.x patch
-- adds no default to it).

--- The style the icon is drawn in while the player hasn't picked one (PagleDB.global.minimap.style nil, CORE-R53): the
--- one place the default lives. Classic is 1.5.0's look, so a player from before 1.5.1 sees no change.
ns.MINIMAP_ICON_STYLE_DEFAULT = "classic"

--- The styles, in the style row's order (SET-R10 row 10b).
ns.MINIMAP_ICON_STYLES = { "classic", "ledger", "bobber" }

--- The size row's range and step, in percent of the button's own size (SET-R10 row 10c). Nothing picked is 100%.
ns.MINIMAP_ICON_SIZE_MIN, ns.MINIMAP_ICON_SIZE_MAX, ns.MINIMAP_ICON_SIZE_STEP = 80, 150, 10

-- Classic, 1.5.0's look, from the client's own minimap-button textures, each listed in build 70338's
-- ManifestInterfaceData (CORE-R9): the round mask the favicon is drawn through (130924,
-- Interface\CHARACTERFRAME\TempPortraitAlphaMask.blp), the tracking-border ring round it (136430,
-- Interface\MINIMAP\minimap-trackingborder.blp), the dark disc behind it (136467,
-- Interface\MINIMAP\UI-Minimap-Background.blp) and the glow while the mouse is over it (136477,
-- Interface\MINIMAP\UI-Minimap-ZoomButton-Highlight.blp).
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- The Ledger and the Bobber, Pagle's own art, each in three textures stacked on the button, each the same square
-- centred on it: the frame (the disc and its gilt ring; nothing goes between the two, so they are one texture), the
-- art over it, its own texture so a press can push it in, and the glow. Each is a lossless BLP with its mip chain
-- (scripts/encode-blp.py --raw): the frame and the art 128 x 128, the glow 64 x 64. The Bobber's are
-- scripts/bobber-art.py's.
local MEDIA = "Interface\\AddOns\\Pagle\\media\\minimap\\"

-- The button's sizes at 100%, in the minimap's units: the button, which takes the clicks, and the Ledger's and the
-- Bobber's square, centred on it. The ring's outside is 33 across, about as wide as Classic's ring.
local SIZE = 31
local ART_SIZE = 34
-- How far a press pushes the art in: right and down, a unit each.
local PRESS = 1
-- How far past the minimap's edge the button's centre sits.
local OUTSIDE = 5

-- Each style's textures under the glow, in the order they are made, each `size` square at 100% in draw layer `layer`,
-- centred on the button unless it hangs from the corner `from`; `mask` is drawn through, and `pressed` is pushed in
-- by a press. Then its glow, in the HIGHLIGHT layer the client shows while the mouse is over the button or
-- LockHighlight holds it, added on (ADD): `size` square and centred, or over the whole button without one.
---@type table<string, { layers: { file: string, layer: string, size: number, from: string?, mask: string?, pressed: boolean? }[], glow: { file: string, size: number? } }>
local STYLES = {
	-- 1.5.0's: the dark disc, the favicon through the round mask over it, the ring over both, hanging from the
	-- button's top left (the ring fills the top left of its square texture), and the client's glow, as
	-- SetHighlightTexture drew it: over the whole button, added on.
	classic = {
		layers = {
			{ file = BACKGROUND, layer = "BACKGROUND", size = 24 },
			{ file = ns.PAGLE_ICON, layer = "ARTWORK", size = 18, mask = MASK },
			{ file = RING, layer = "OVERLAY", size = 50, from = "TOPLEFT" },
		},
		glow = { file = HIGHLIGHT },
	},
	-- The Ledger: a leather-bound book with a gilt "P", on night water in a gilt-bronze ring.
	ledger = {
		layers = {
			{ file = MEDIA .. "Ledger-Frame", layer = "BACKGROUND", size = ART_SIZE },
			{ file = MEDIA .. "Ledger-Book", layer = "ARTWORK", size = ART_SIZE, pressed = true },
		},
		glow = { file = MEDIA .. "Ledger-Glow", size = ART_SIZE },
	},
	-- The Bobber, the Pagle Companion's: a red and cream bobber with a gilt band, on night water in a thin gilt ring.
	bobber = {
		layers = {
			{ file = MEDIA .. "Bobber-Frame", layer = "BACKGROUND", size = ART_SIZE },
			{ file = MEDIA .. "Bobber-Emblem", layer = "ARTWORK", size = ART_SIZE, pressed = true },
		},
		glow = { file = MEDIA .. "Bobber-Glow", size = ART_SIZE },
	},
}

---@type table?
local button

-- The size the button is drawn at now, as a fraction of its own (1 is 100%): the picked size, once it could be applied
-- (ns.SetMinimapIconSize).
local sized = 1

-- The textures made for each style the button has been drawn in, by style, in STYLES' order; only the style's own
-- show. And the one glow every style shares, retextured as the style changes, so the HIGHLIGHT layer never holds a
-- hidden texture.
---@type table<string, table[]>
local drawn = {}
---@type table?
local glow

-- The detached button's centre minus the cursor's as a drag of it starts, in UIParent's units, so it moves with the
-- spot it was gripped by; nil for a drag round the minimap's edge.
---@type { x: number, y: number }?
local grip

-- Whether the press now on the button has started a drag, so its release opens no menu (CORE-R54). The client calls
-- no OnClick after a drag; this keeps it so should one come. Each press clears it.
local dragging = false

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

-- The cursor's position now in UIParent's units, at any UI scale.
---@return number x
---@return number y
local function cursorOnScreen()
	local scale = UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	return x / scale, y / scale
end

-- Puts the detached button with its centre at `x`, `y` on the screen, in UIParent's units from its bottom left.
---@param x number
---@param y number
local function placeOnScreen(x, y)
	assert(button)
	button:ClearAllPoints()
	button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- Where the saved spot (PagleDB.global.minimap.point) puts the detached button's centre on the screen as it is now,
-- kept whole on it at the size it is drawn at; nil with no spot saved.
---@return number? x
---@return number? y
local function savedSpot()
	return ns.DetachedIconCenter(ns.db.global.minimap.point, UIParent:GetWidth(), UIParent:GetHeight(), SIZE * sized)
end

-- Saves the spot of a detached button whose centre is at `x`, `y` on the screen, kept whole on it at the size it is
-- drawn at.
---@param x number
---@param y number
local function saveSpot(x, y)
	local size = SIZE * sized
	ns.db.global.minimap.point = ns.DetachedIconPoint(x, y, UIParent:GetWidth(), UIParent:GetHeight(), size)
end

-- Where the button's centre is on the screen now, in UIParent's units: read from the button, else from its angle
-- round the minimap, else the screen's middle.
---@return number x
---@return number y
local function centerOnScreen()
	assert(button)
	local scale = UIParent:GetEffectiveScale()
	local x, y = button:GetCenter()
	if x and y then
		local own = button:GetEffectiveScale()
		return x * own / scale, y * own / scale
	end
	local minimapX, minimapY = Minimap:GetCenter()
	if minimapX and minimapY then
		local offsetX, offsetY = ns.MinimapIconOffset(ns.db.global.minimap.angle, Minimap:GetWidth() / 2 + OUTSIDE)
		local own = Minimap:GetEffectiveScale()
		return (minimapX + offsetX) * own / scale, (minimapY + offsetY) * own / scale
	end
	return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
end

-- Whether the button is where "Detach from the minimap" put it: detached, on UIParent.
---@return boolean
local function isOnScreen()
	assert(button)
	return ns.db.global.minimap.detached == true and button:GetParent() == UIParent
end

-- The UI scale or the window changed: the detached button goes back to its spot, the same spot on the screen in
-- UIParent's new units, kept whole on it (CORE-R53). Listened for only while it is detached, so on the minimap's edge
-- the icon adds no registration (Fit's pair stays the only one until a window is fitted).
local function screenChanged()
	if button and isOnScreen() then
		local x, y = savedSpot()
		if x and y then
			placeOnScreen(x, y)
		end
	end
end

-- Gives the button its parent and puts it where PagleDB.global.minimap says (CORE-R53): detached, on UIParent at its
-- saved spot, or, with none saved, where it is on the screen now, which is saved; else on the minimap's edge at its
-- angle, the spot forgotten. Its strata and level stay the same on either parent.
local function applyMode()
	assert(button)
	local saved = ns.db.global.minimap
	if saved.detached then
		if not savedSpot() then
			saveSpot(centerOnScreen())
		end
		button:SetParent(UIParent)
		button:SetClampedToScreen(true)
		placeOnScreen(assert(savedSpot()))
		Pagle.RegisterEvent(OWNER, "UI_SCALE_CHANGED", screenChanged)
		Pagle.RegisterEvent(OWNER, "DISPLAY_SIZE_CHANGED", screenChanged)
	else
		saved.point = nil
		button:SetParent(Minimap)
		button:SetClampedToScreen(false)
		place(saved.angle)
		Pagle.UnregisterEvent(OWNER, "UI_SCALE_CHANGED")
		Pagle.UnregisterEvent(OWNER, "DISPLAY_SIZE_CHANGED")
	end
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
end

-- The style the button is drawn in: the picked one, else the default (CORE-R53).
---@return string
local function styleOf()
	local stored = ns.db.global.minimap.style
	return STYLES[stored] and stored or ns.MINIMAP_ICON_STYLE_DEFAULT
end

-- The size picked, in percent, to the nearest step of the size row (SET-R10 row 10c); 100 while none is picked, or for
-- one that isn't a number in the row's range (CORE-R53).
---@return number
local function sizeOf()
	local stored = ns.db.global.minimap.scale
	local percent = type(stored) == "number" and stored * 100
	if not percent or not (percent >= ns.MINIMAP_ICON_SIZE_MIN and percent <= ns.MINIMAP_ICON_SIZE_MAX) then
		return 100
	end
	local step = ns.MINIMAP_ICON_SIZE_STEP
	return math.floor(percent / step + 0.5) * step
end

-- Puts a texture of the style's (a STYLES layer) on the button at the size it is drawn at, `offset` right and down.
---@param texture table
---@param layer { size: number, from: string? }
---@param offset number
local function anchor(texture, layer, offset)
	local from = layer.from or "CENTER"
	texture:SetSize(layer.size * sized, layer.size * sized)
	texture:ClearAllPoints()
	texture:SetPoint(from, button, from, offset, -offset)
end

-- Pushes the style's art in while the mouse is down on the button, or lets it up (CORE-R53). Classic has none.
---@param pressed boolean
local function press(pressed)
	local style = styleOf()
	for n, layer in ipairs(STYLES[style].layers) do
		local texture = drawn[style] and drawn[style][n]
		if layer.pressed and texture then
			anchor(texture, layer, pressed and PRESS or 0)
		end
	end
end

-- Draws the button in its style at the size it is drawn at (CORE-R53): the style's textures, made the first time it is
-- drawn in it, show and every other style's hide; the shared glow takes the style's file and place. The art is up.
local function draw()
	assert(button)
	local style = styleOf()
	button:SetSize(SIZE * sized, SIZE * sized)
	for other, textures in pairs(drawn) do
		if other ~= style then
			for _, texture in ipairs(textures) do
				texture:Hide()
			end
		end
	end
	if not drawn[style] then
		local textures = {}
		for n, layer in ipairs(STYLES[style].layers) do
			local texture = button:CreateTexture(nil, layer.layer)
			texture:SetTexture(layer.file)
			if layer.mask then
				local mask = button:CreateMaskTexture()
				mask:SetTexture(layer.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				mask:SetAllPoints(texture)
				texture:AddMaskTexture(mask)
			end
			textures[n] = texture
		end
		drawn[style] = textures
	end
	for n, layer in ipairs(STYLES[style].layers) do
		local texture = drawn[style][n]
		anchor(texture, layer, 0)
		texture:Show()
	end
	local shine = STYLES[style].glow
	if not glow then
		glow = button:CreateTexture(nil, "HIGHLIGHT")
	end
	glow:SetTexture(shine.file)
	glow:SetBlendMode("ADD")
	if shine.size then
		anchor(glow, { size = shine.size }, 0)
	else
		glow:ClearAllPoints()
		glow:SetAllPoints(button)
	end
end

-- Ends a drag: the button stops following the cursor, and keeps the place it was last put at. The art comes up.
---@param self table the button
local function stopDragging(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
	press(false)
end

-- Each frame of a drag: the button follows the cursor and saves where it is, round the edge or, detached, anywhere on
-- the screen, kept whole on it. Restriction starting mid-drag ends the drag where the button is (CORE-R53).
---@param self table the button
local function followCursor(self)
	if Pagle.IsRestricted() then
		stopDragging(self)
		return
	end
	if grip then
		local x, y = cursorOnScreen()
		saveSpot(x + grip.x, y + grip.y)
		placeOnScreen(assert(savedSpot()))
		return
	end
	local angle = cursorAngle()
	ns.db.global.minimap.angle = angle
	place(angle)
end

-- A left-button drag starts: never while restricted (CORE-R53). The tooltip goes while it is dragged. Detached, the
-- button keeps the spot the cursor gripped it by.
---@param self table the button
local function startDragging(self)
	dragging = true
	ns.HideMenuTooltip(self)
	if Pagle.IsRestricted() then
		return
	end
	grip = nil
	if isOnScreen() then
		local x, y = assert(savedSpot())
		local cursorX, cursorY = cursorOnScreen()
		grip = { x = x - cursorX, y = y - cursorY }
	end
	self:LockHighlight()
	self:SetScript("OnUpdate", followCursor)
end

-- A left click opens Pagle's menu at once, at the cursor; other buttons do nothing (CORE-R54). While its parent is the
-- one Pagle gave it (Minimap, or UIParent detached) the icon owns the menu, so hiding the icon closes it. Once another
-- addon has moved it (EllesmereUI's flyout hides at any outside press, the menu's included), the menu belongs to
-- nothing, as the compartment's does. The parent is read at each click. Unlike the compartment's, no menu of the
-- client's closes after the click. It opens while restricted too, as the compartment's does. The release that ends a
-- drag opens nothing.
---@param self table the button
---@param mouseButton string
local function onClick(self, mouseButton)
	if dragging then
		dragging = false
		return
	end
	if mouseButton == "LeftButton" then
		local owned = self:GetParent() == Minimap or isOnScreen()
		ns.OpenMenu(owned and self or nil)
	end
end

-- The button, drawn in its style at its size (CORE-R53): its textures, and the glow while the mouse is over it.
---@return table
local function makeButton()
	local made = CreateFrame("Button", "PagleMinimapButton", Minimap)
	made:SetSize(SIZE * sized, SIZE * sized)
	made:SetFrameStrata("MEDIUM")
	made:SetFrameLevel(8)
	made:RegisterForClicks("AnyUp")
	made:RegisterForDrag("LeftButton")

	made:SetScript("OnMouseDown", function()
		dragging = false
		press(true)
	end)
	made:SetScript("OnMouseUp", function()
		press(false)
	end)
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
	sized = sizeOf() / 100
	button = makeButton()
	draw()
	local saved = ns.db.global.minimap
	place(saved.angle)
	applyMode()
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

--- Whether Detach from the minimap is on (CORE-R53, SET-R10 row 10a): PagleDB.global.minimap.detached.
---@return boolean
function ns.IsMinimapIconDetached()
	return ns.db.global.minimap.detached == true
end

--- Detaches the minimap icon from the minimap's edge or puts it back, keeping the choice in PagleDB.global.minimap
--- (CORE-R53). Detached, it stays where it is on the screen until dragged; put back, it snaps to the edge at its saved
--- angle. The choice is kept at once; the icon moves only outside restriction, so ticked while restricted it moves
--- once restriction ends (ns.RunWhenUnrestricted). It works while the icon is hidden too, which then shows as chosen.
---@param detached boolean
function ns.SetMinimapIconDetached(detached)
	local saved = ns.db.global.minimap
	saved.detached = detached
	saved.point = nil
	if button then
		ns.RunWhenUnrestricted(applyMode)
	end
end

--- The style the minimap icon is drawn in (CORE-R53, SET-R10 row 10b): PagleDB.global.minimap.style, or
--- ns.MINIMAP_ICON_STYLE_DEFAULT while none is picked or the one kept isn't a style.
---@return string
function ns.MinimapIconStyle()
	return styleOf()
end

--- Draws the minimap icon in `style` (one of ns.MINIMAP_ICON_STYLES) at once and keeps the pick in
--- PagleDB.global.minimap.style (CORE-R53). It only changes how the icon looks, so it applies while restricted too,
--- and while the icon is hidden, which then shows in it. The pick is kept even when it is the default, so a later
--- default changes only the icons of players who never picked.
---@param style string
function ns.SetMinimapIconStyle(style)
	if not STYLES[style] then
		return
	end
	ns.db.global.minimap.style = style
	if button then
		draw()
	end
end

--- The minimap icon's size in percent (CORE-R53, SET-R10 row 10c): PagleDB.global.minimap.scale, as a percentage to
--- the nearest of the row's steps, or 100 while none is picked or the one kept is outside the row's range.
---@return number
function ns.MinimapIconSize()
	return sizeOf()
end

--- Sizes the minimap icon to `percent` (80 to 150) and keeps it in PagleDB.global.minimap.scale as a fraction (1.2
--- for 120) (CORE-R53). The button and its art grow or shrink about its centre: on the minimap's edge it stays on the
--- same circle; detached it stays at its spot, kept whole on the screen at its new size. The pick is kept at once; the
--- button changes only outside restriction, as it may move, so picked while restricted it changes once restriction
--- ends (ns.RunWhenUnrestricted).
---@param percent number
function ns.SetMinimapIconSize(percent)
	ns.db.global.minimap.scale = percent / 100
	if button then
		ns.RunWhenUnrestricted(function()
			sized = sizeOf() / 100
			draw()
			if isOnScreen() then
				placeOnScreen(assert(savedSpot()))
			end
		end)
	end
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
