---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- A Module's keybinding row (SET-R20, SET-R5, SET-R6, #120). Blizzard's KeyBindingFrameBindingTemplate can't grey
-- out: its mixin isn't a SettingsListElementMixin, so it never reads modify predicates and never hears its parent's
-- changes (Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57, "1.60.1 (70338)",
-- Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Keybindings.lua, KeyBindingFrameBindingTemplateMixin:Init). So
-- Core draws the row itself on its own template (adapter/Settings.xml, PagleSettingsKeyRowTemplate): the row's label,
-- then its first two keys as Blizzard's row shows them, greyed out while its isEnabled returns false or while
-- restricted, read at each draw. Its frames are Core's, so Core redraws them at once when a value changes through a
-- Module's row (adapter/Settings.lua calls ns.RedrawKeyRows), at UPDATE_BINDINGS and at RestrictionChanged. It writes
-- nothing onto Blizzard's initializers or settings (SET-R6).
--
-- A click on a key waits for the next key press, which that key button takes through its own keyboard input, and
-- binds it in that slot, through Core's key capture (adapter/KeyCapture.lua), which the Field guide's binding field
-- shares: the slot's key replaced, the key taken from whatever action had it, without asking, as Blizzard's rows do,
-- then the binding set saved. Core runs none of Blizzard's Settings code for this (SET-R6). SetBinding is refused to
-- addons in combat (warcraft.wiki.gg, API SetBinding: "nocombat"), so the keys take no click while restricted. Its
-- own owner on Core's bus.
local OWNER = "Pagle key binding rows"
local L = ns.L

-- The template of a keybinding row (adapter/Settings.xml).
local TEMPLATE = "PagleSettingsKeyRowTemplate"
-- Blizzard's row layout: the label 37 pixels in, 15 more under a parent (Blizzard_SettingControls.lua's indentSize),
-- and two key buttons of 160 by 22, the first from 80 left of the middle (Blizzard_Keybindings.xml).
local LABEL_X, INDENT = 37, 15
local KEY_WIDTH, KEY_HEIGHT, KEY_X = 160, 22, -80
-- The keys a row shows and binds, as Blizzard's: an action's first two (ns.BindKey's).
local SLOTS = 2

---@class PagleKeyRow the data of a keybinding row's initializer, which Core made and reads
---@field name string the row's label, which the settings search shows
---@field binding string the Bindings.xml action
---@field tooltip string?
---@field isEnabled (fun(): boolean)?
---@field indented boolean whether it hangs under a parent row (SET-R2)

---@class PagleKeyRowWidgets
---@field label FontString
---@field keys Button[]

-- Core's widgets on a row frame, and the row each frame shows now (nil once released). Weak, as the panel's list owns
-- the frames.
---@type table<Frame, PagleKeyRowWidgets>
local widgetsOf = setmetatable({}, { __mode = "k" })
---@type table<Frame, PagleKeyRow>
local rowOf = setmetatable({}, { __mode = "k" })

-- Whether slot `slot` of `frame` waits for a key press (Core's key capture waits for one thing at a time).
---@param frame Frame
---@param slot integer
---@return boolean
local function isWaiting(frame, slot)
	local owner = ns.KeyCaptureOwner()
	return type(owner) == "table" and owner.keyRow == frame and owner.slot == slot
end

-- Whether a slot of `frame` waits for a key press.
---@param frame Frame
---@return boolean
local function waitsOn(frame)
	local owner = ns.KeyCaptureOwner()
	return type(owner) == "table" and owner.keyRow == frame
end

-- Whether `row` is drawn live: its isEnabled holds (a Module's isEnabled that raises reads as false) and nothing is
-- restricted.
---@param row PagleKeyRow
---@return boolean
local function isLive(row)
	if Pagle.IsRestricted() then
		return false
	end
	return not row.isEnabled or securecallfunction(row.isEnabled) == true
end

-- Draws the row `frame` shows: its label, indented under a parent, and each key slot's key, "Not Bound" or, while it
-- waits, "Press a key"; all greyed out unless the row is live. A greyed-out row stops waiting.
---@param frame Frame
local function draw(frame)
	local row, own = rowOf[frame], widgetsOf[frame]
	if not (row and own) then
		return
	end
	local live = isLive(row)
	if not live and waitsOn(frame) then
		ns.StopKeyCapture() -- draws it again, waiting no more
		return
	end
	own.label:SetFontObject(live and "GameFontNormal" or "GameFontDisable")
	own.label:ClearAllPoints()
	own.label:SetPoint("LEFT", LABEL_X + (row.indented and INDENT or 0), 0)
	own.label:SetText(row.name)
	local keys = { GetBindingKey(row.binding) }
	for slot = 1, SLOTS do
		local button = own.keys[slot]
		local key = keys[slot]
		if isWaiting(frame, slot) then
			button:SetText(L.SETTINGS_KEY_WAITING)
			button:LockHighlight()
		else
			button:SetText(key and GetBindingText(key) or L.SETTINGS_KEY_NOT_BOUND)
			button:UnlockHighlight()
		end
		button:SetEnabled(live)
	end
end

--- Redraws every keybinding row the panel shows now, at once (SET-R61): adapter/Settings.lua calls it after a value
--- changes or a button is pressed through a Module's row.
function ns.RedrawKeyRows()
	for frame in pairs(rowOf) do
		draw(frame)
	end
end

-- Slot `slot` of `frame` waits for a key press, which its key button takes before any binding does: a key, or a mouse
-- button clicked on it, binds in that slot while the row is live; whatever stops it waiting redraws the row.
---@param frame Frame
---@param slot integer
local function startWaiting(frame, slot)
	ns.StartKeyCapture({
		owner = { keyRow = frame, slot = slot },
		frame = widgetsOf[frame].keys[slot],
		onKey = function(key)
			local row = rowOf[frame]
			if row and isLive(row) then
				ns.BindKey(row.binding, slot, key)
				draw(frame)
			end
		end,
		onStop = function()
			draw(frame)
		end,
	})
	draw(frame)
end

-- A click on slot `slot`'s key (Blizzard's row's OnClick): the left button starts it waiting, or stops it at a
-- second click; the right button unbinds its key; any other mouse button is the waiting slot's key press.
---@param frame Frame
---@param slot integer
---@param mouseButton string
local function clicked(frame, slot, mouseButton)
	local row = rowOf[frame]
	if not (row and isLive(row)) then
		return
	end
	if mouseButton == "LeftButton" then
		local again = isWaiting(frame, slot)
		ns.StopKeyCapture()
		if not again then
			startWaiting(frame, slot)
		end
	elseif mouseButton == "RightButton" then
		ns.StopKeyCapture()
		local key = select(slot, GetBindingKey(row.binding))
		if key then
			SetBinding(key)
			SaveBindings(GetCurrentBindingSet())
		end
		draw(frame)
	else
		ns.PressKeyCapture(mouseButton)
	end
end

-- The row's label and tooltip over a key, if it has a tooltip (SET-R2).
---@param frame Frame
---@param button Button
local function showTooltip(frame, button)
	local row = rowOf[frame]
	if not (row and row.tooltip) then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText(row.name)
	GameTooltip:AddLine(row.tooltip, 1, 1, 1, true)
	GameTooltip:Show()
end

-- Core's widgets on `frame`, made the first time a keybinding row draws on it: the label, and the two key buttons
-- beside it, which take any mouse button. A row that hides (the panel closing) stops waiting.
---@param frame Frame
---@return PagleKeyRowWidgets
local function widgets(frame)
	local own = widgetsOf[frame]
	if own then
		return own
	end
	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetJustifyH("LEFT")
	own = { label = label, keys = {} }
	for slot = 1, SLOTS do
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
		button:SetSize(KEY_WIDTH, KEY_HEIGHT)
		if slot == 1 then
			button:SetPoint("LEFT", frame, "CENTER", KEY_X, 0)
		else
			button:SetPoint("LEFT", own.keys[slot - 1], "RIGHT", 0, 0)
		end
		button:RegisterForClicks("AnyUp")
		button:SetScript("OnClick", function(_, mouseButton)
			clicked(frame, slot, mouseButton)
		end)
		button:SetScript("OnEnter", function()
			showTooltip(frame, button)
		end)
		button:SetScript("OnLeave", function()
			if GameTooltip:IsOwned(button) then
				GameTooltip:Hide()
			end
		end)
		own.keys[slot] = button
	end
	frame:SetScript("OnHide", function()
		if waitsOn(frame) then
			ns.StopKeyCapture()
		end
	end)
	widgetsOf[frame] = own
	return own
end

--- The mixin of a keybinding row's frames (adapter/Settings.xml, SET-R5, SET-R6). The panel's list draws one through
--- Blizzard's stock InitFrame, which calls its Init, and releases it through the stock Resetter, which calls its
--- Release, each under securecallfunction.
---@class PagleSettingsKeyRowMixin : Frame
PagleSettingsKeyRowMixin = {}

--- Draws the row Core put in its initializer's data.
---@param initializer SettingsInitializer
function PagleSettingsKeyRowMixin:Init(initializer)
	widgets(self)
	rowOf[self] = initializer:GetData()
	draw(self)
end

--- The frame shows no row any more: it stops waiting, and redraws leave it alone.
function PagleSettingsKeyRowMixin:Release()
	if waitsOn(self) then
		ns.StopKeyCapture()
	end
	rowOf[self] = nil
end

--- A Module's keybinding row for `setting` (SET-R20): found in the settings search by its label, indented when it
--- hangs under a parent row. Its isEnabled is read at each draw; Blizzard's modify predicates aren't, so it adds none.
---@param setting PagleSetting
---@param indented boolean
---@return SettingsInitializer
function ns.KeyBindingRow(setting, indented)
	---@type PagleKeyRow
	local row = {
		name = setting.label,
		binding = setting.binding --[[@as string]],
		tooltip = setting.tooltip,
		isEnabled = setting.isEnabled,
		indented = indented,
	}
	local initializer = Settings.CreateElementInitializer(TEMPLATE, row)
	initializer:AddSearchTags(setting.label)
	return initializer
end

-- A binding changed, through a row or anywhere else: each row shows its keys now (SET-R20).
Pagle.RegisterEvent(OWNER, "UPDATE_BINDINGS", function()
	ns.RedrawKeyRows()
end)

-- Combat starts or ends: a waiting slot stops, and the keys grey out or come back (SET-R93, CORE-R32).
Pagle.RegisterCallback(OWNER, "RestrictionChanged", function()
	ns.StopKeyCapture()
	ns.RedrawKeyRows()
end)
