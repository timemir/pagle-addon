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

-- The Ledger, Pagle's own art (CORE-R53), in three textures stacked on the button, each the same square centred on
-- it: the frame (night water in a gilt-bronze ring; nothing goes between the two, so they are one texture), the book
-- over it (a leather-bound Ledger with a gilt "P", its own texture so a press can push it in) and, in the HIGHLIGHT
-- layer the client shows while the mouse is over the button or LockHighlight holds it, the glow, added on (ADD).
-- Each is a lossless BLP with its mip chain (scripts/encode-blp.py --raw): the frame and the book 128 x 128, the glow
-- 64 x 64.
local FRAME = "Interface\\AddOns\\Pagle\\media\\minimap\\Ledger-Frame"
local BOOK = "Interface\\AddOns\\Pagle\\media\\minimap\\Ledger-Book"
local GLOW = "Interface\\AddOns\\Pagle\\media\\minimap\\Ledger-Glow"

-- Its sizes, in the minimap's units: the button, which takes the clicks, and the art's square, centred on it. The
-- ring's outside is 33 across, about as wide as the client's tracking-border ring on its own buttons.
local SIZE = 31
local ART_SIZE = 34
-- How far a press pushes the book: right and down, a unit each.
local PRESS = 1
-- How far past the minimap's edge the button's centre sits.
local OUTSIDE = 5

---@type table?
local button

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
-- kept whole on it; nil with no spot saved.
---@return number? x
---@return number? y
local function savedSpot()
	return ns.DetachedIconCenter(ns.db.global.minimap.point, UIParent:GetWidth(), UIParent:GetHeight(), SIZE)
end

-- Saves the spot of a detached button whose centre is at `x`, `y` on the screen, kept whole on it.
---@param x number
---@param y number
local function saveSpot(x, y)
	ns.db.global.minimap.point = ns.DetachedIconPoint(x, y, UIParent:GetWidth(), UIParent:GetHeight(), SIZE)
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

-- The book texture, made with the button.
---@type table?
local book

-- Pushes the book in while the mouse is down on the button, or lets it up (CORE-R53).
---@param pressed boolean
local function press(pressed)
	if book then
		local offset = pressed and PRESS or 0
		book:SetPoint("CENTER", button, "CENTER", offset, -offset)
	end
end

-- Ends a drag: the button stops following the cursor, and keeps the place it was last put at. The book comes up.
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

-- A texture of the Ledger's art (FRAME, BOOK or GLOW) on `made`, in draw layer `layer`, the art's square centred on it.
---@param made table the button
---@param file string
---@param layer string
---@return table
local function art(made, file, layer)
	local texture = made:CreateTexture(nil, layer)
	texture:SetTexture(file)
	texture:SetSize(ART_SIZE, ART_SIZE)
	texture:SetPoint("CENTER", made, "CENTER", 0, 0)
	return texture
end

-- The button, drawn as the Ledger: the frame, the book on it, and the glow while the mouse is over it (CORE-R53).
---@return table
local function makeButton()
	local made = CreateFrame("Button", "PagleMinimapButton", Minimap)
	made:SetSize(SIZE, SIZE)
	made:SetFrameStrata("MEDIUM")
	made:SetFrameLevel(8)
	made:RegisterForClicks("AnyUp")
	made:RegisterForDrag("LeftButton")

	art(made, FRAME, "BACKGROUND")
	book = art(made, BOOK, "ARTWORK")
	art(made, GLOW, "HIGHLIGHT"):SetBlendMode("ADD")

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
	button = makeButton()
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
