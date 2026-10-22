if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The companion hint at runtime (HNT-R170–R172, HNT-R176, SET-R32): whether it applies now, read from the hint switch,
-- Core's companion state (PUSH-R15) and the saved profile; Get it's box with the companion's address; Dismiss; the
-- weekly Nod at login; and the Settings row that brings a dismissed hint back. Its lines and the Nod are
-- logic/Companion.lua's. The wager strip (adapter/Wagers.lua), the placeholder slip (adapter/WagersSpread.lua) and the
-- tracker's line (adapter/Tracker.lua, adapter/Goods.lua) draw it, with Get it and Dismiss made here.
--
-- With the switch off (ns.COMPANION_HINT_ON, on at 1.0, HNT-R172) the hint never applies, so nothing draws it, and
-- ns.StartCompanionHint adds no row and raises no Nod.

local OWNER = "Pagle_Hunts companion hint"
local LOOK = ns.BOARD_LOOK

--- The companion hint as it applies now (HNT-R170), or nil: the switch, Core's companion state, and whether the player
--- dismissed it.
---@return CompanionHint?
function ns.CompanionHintNow()
	return ns.CompanionHint(ns.COMPANION_HINT_ON, Pagle.GetCompanionState(), ns.db.profile.companionHint)
end

-- Get it's box (HNT-R170) --------------------------------------------------------------------------------------------

-- The box's measures: its size, its words' inset, and the rows down it (the kicker, the address, the copy note).
local BOX_WIDTH, BOX_HEIGHT, BOX_INSET, BOX_EDGE = 340, 96, 16, 4
local KICKER_Y, ADDRESS_Y, ADDRESS_HEIGHT, COPY_Y = 12, 32, 22, 66

---@class CompanionAddressBox: Frame
---@field kicker FontString
---@field address EditBox     -- the companion's address, read-only and selected (as the Field report's link, REP-R40)
---@field copy FontString     -- "Ctrl+C to copy"
---@field close Button

---@type CompanionAddressBox?
local box

-- Puts the address back and selects it all: whatever the player types is undone, so Ctrl+C copies it whole.
---@param address EditBox
local function selectAddress(address)
	address:SetText(ns.COMPANION_URL)
	address:SetCursorPosition(0) -- from "https://", not scrolled to its end
	address:HighlightText()
end

-- A word button in the board's red ink: "Get it", "Dismiss", "Close". `role` names it for the specs.
---@param parent Frame
---@param words string
---@param role string
---@param onClick fun()
---@return Button
local function wordButton(parent, words, role, onClick)
	local button = CreateFrame("Button", nil, parent)
	local label = ns.BoardText(button, ns.BoardFonts().kicker, LOOK.red)
	label:SetText(words)
	label:SetPoint("LEFT")
	button:SetSize(math.ceil(label:GetStringWidth()) + 2, 16)
	button:SetScript("OnClick", onClick)
	button.label, button.hintRole = label, role
	button:Hide()
	return button
end

-- Builds the box on the board, hidden: a pinned paper slip with the wagers' oxblood edge, over the pages.
---@param parent Frame
---@return CompanionAddressBox
local function buildBox(parent)
	local L, fonts = ns.L, ns.BoardFonts()
	local frame = CreateFrame("Frame", nil, parent) --[[@as CompanionAddressBox]]
	frame:SetSize(BOX_WIDTH, BOX_HEIGHT)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 40)
	frame:SetFrameLevel(parent:GetFrameLevel() + 30)
	frame:EnableMouse(true)
	ns.BoardSolid(frame, LOOK.stripPaper, "BACKGROUND")
	ns.BoardOutline(frame, 0, "BORDER"):Solid(LOOK.rule)
	local edge = ns.BoardSolid(frame, LOOK.oxblood, "BORDER")
	edge:ClearAllPoints()
	edge:SetPoint("TOPLEFT")
	edge:SetSize(BOX_EDGE, BOX_HEIGHT)
	frame.kicker = ns.BoardText(frame, fonts.kicker, LOOK.kicker)
	frame.kicker:SetText(ns.BoardSmallCaps(L.HINT_ADDRESS_KICKER))
	frame.kicker:SetPoint("TOPLEFT", BOX_INSET, -KICKER_Y)
	local address = CreateFrame("EditBox", nil, frame) --[[@as EditBox]]
	address:SetFontObject(fonts.small)
	address:SetTextColor(LOOK.ink[1], LOOK.ink[2], LOOK.ink[3])
	address:SetHighlightColor(0.275, 0.47, 0.745, 0.28)
	address:SetAutoFocus(false)
	address:SetSize(BOX_WIDTH - 2 * BOX_INSET, ADDRESS_HEIGHT)
	address:SetPoint("TOPLEFT", BOX_INSET, -ADDRESS_Y)
	ns.BoardSolid(address, LOOK.paper, "BACKGROUND", 0.5)
	address:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			selectAddress(self)
		end
	end)
	address:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	-- A focused edit box takes Esc before UISpecialFrames does: Esc closes the box, then the board.
	address:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	address:SetScript("OnEnterPressed", function()
		frame:Hide()
	end)
	frame.address = address
	frame.copy = ns.BoardText(frame, fonts.note, LOOK.note)
	frame.copy:SetText(L.HINT_ADDRESS_COPY)
	frame.copy:SetPoint("TOPLEFT", BOX_INSET, -COPY_Y)
	frame.close = wordButton(frame, L.HINT_ADDRESS_CLOSE, "close", function()
		frame:Hide()
	end)
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -BOX_INSET, -COPY_Y)
	frame.close:Show()
	frame:SetScript("OnHide", function()
		address:ClearFocus()
	end)
	frame:Hide()
	return frame
end

--- Get it (HNT-R170): shows the companion's address (ns.COMPANION_URL, Tunables) over the board in a read-only edit
--- box, selected and focused, so Ctrl+C copies it, as the Field report's link (REP-R40). It closes with Esc, Enter or
--- Close, and with the board.
function ns.ShowCompanionAddress()
	local parent = ns.board.frame
	if not parent then
		return
	end
	box = box or buildBox(parent)
	box:Show()
	selectAddress(box.address)
	box.address:SetFocus()
end

--- Get it's box, nil before it was first shown.
---@return CompanionAddressBox?
function ns.CompanionAddressBox()
	return box
end

--- Dismiss (HNT-R170): turns "Remind me about the Pagle companion" off (`profile.companionHint`), which hides the hint
--- everywhere and stops the Nod until the Settings row turns it back on.
function ns.DismissCompanionHint()
	ns.db.profile.companionHint = false
	if box then
		box:Hide()
	end
	ns.Redraw("companion")
end

-- Get it and Dismiss -------------------------------------------------------------------------------------------------

--- The hint's two buttons on one piece of the board.
---@class CompanionHintButtons
---@field getIt Button
---@field dismiss Button

-- The room between the two buttons.
local BUTTON_GAP = 10

--- Get it and Dismiss (HNT-R170) on `parent`, hidden until placed: the wager strip's hint and the placeholder slip each
--- have a pair. Their clicks go through ns at call time.
---@param parent Frame
---@return CompanionHintButtons
function ns.NewHintButtons(parent)
	local L = ns.L
	return {
		getIt = wordButton(parent, L.HINT_GET_IT, "getIt", function()
			ns.ShowCompanionAddress()
		end),
		dismiss = wordButton(parent, L.HINT_DISMISS, "dismiss", function()
			ns.DismissCompanionHint()
		end),
	}
end

--- Shows the pair on one row, Dismiss's right edge `right` in from `relative`'s right and their tops `y` down from its
--- top, Get it before it; returns the width they take.
---@param buttons CompanionHintButtons
---@param relative Frame
---@param right number
---@param y number
---@return number
function ns.PlaceHintButtons(buttons, relative, right, y)
	local dismiss, getIt = buttons.dismiss, buttons.getIt
	dismiss:ClearAllPoints()
	dismiss:SetPoint("TOPRIGHT", relative, "TOPRIGHT", -right, -y)
	getIt:ClearAllPoints()
	getIt:SetPoint("TOPRIGHT", dismiss, "TOPLEFT", -BUTTON_GAP, 0)
	dismiss:Show()
	getIt:Show()
	return getIt:GetWidth() + BUTTON_GAP + dismiss:GetWidth()
end

--- Hides the pair.
---@param buttons CompanionHintButtons
function ns.HideHintButtons(buttons)
	buttons.getIt:Hide()
	buttons.dismiss:Hide()
end

-- The Nod and the Settings row ---------------------------------------------------------------------------------------

--- Starts the hint, from OnInitialize after the window moments' row (SET-R32's order), only while the switch is on
--- (HNT-R172): adds "Remind me about the Pagle companion" to the Announcements page under Hunts' header, with no
--- isEnabled (not greyed in Cozy mode, as SET-R32's row), and waits for the weekly Nod (HNT-R171): at the first
--- PLAYER_ENTERING_WORLD of the login once PushedContentReady has fired, whichever comes second, it raises the Nod if
--- the hint applies and the Nod interval has passed since `profile.lastHintNod`, then stores the time. At
--- PushedContentReady the views redraw, as the companion state is known from then (PUSH-R16).
function ns.StartCompanionHint()
	if not ns.COMPANION_HINT_ON then
		return
	end
	local L = ns.L
	ns.Module:AddSetting("announcements", {
		kind = "checkbox",
		label = L.COMPANION_HINT_SETTING,
		tooltip = L.COMPANION_HINT_TOOLTIP,
		get = function()
			return ns.db.profile.companionHint
		end,
		set = function(value)
			ns.db.profile.companionHint = value and true or false
			ns.Redraw("companion")
		end,
		default = true,
	})

	local ready, entered, looked = false, false, false
	local function nodOnce()
		if looked or not (ready and entered) then
			return
		end
		looked = true
		local now = GetServerTime()
		local hint = ns.CompanionHintNow()
		if hint and ns.HintNodDue(hint, ns.db.profile.lastHintNod, now) then
			ns.Module:RaiseMoment(ns.HintNod(hint, function()
				ns.OpenWagers()
			end))
			ns.db.profile.lastHintNod = now
		end
	end
	Pagle.RegisterCallback(OWNER, "PushedContentReady", function()
		ready = true
		ns.Redraw("companion")
		nodOnce()
	end)
	Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
		Pagle.UnregisterEvent(OWNER, "PLAYER_ENTERING_WORLD")
		entered = true
		nodOnce()
	end)
end
