---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Core's key capture (SET-R20, ONB-R41): what waits for the next key press and binds it, shared by the Settings key
-- rows (adapter/KeyBindingRow.lua) and the Field guide's binding field (adapter/GuideBindingField.lua). One capture
-- waits at a time. Its frame takes the press through its own keyboard input, and the press is taken as Blizzard's
-- KeybindListener:ProcessInput takes it (Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57, "1.60.1 (70338)", Interface/AddOns/Blizzard_Settings_Shared/
-- Blizzard_Keybindings.lua): a modifier alone, UNKNOWN and the two main mouse buttons keep it waiting, Escape stops it
-- binding nothing, and any other is the key with the modifiers held. A key binds as ProcessInput binds it, then the
-- binding set is saved, as KeybindListener:Commit does. Core runs none of Blizzard's Settings code for this (SET-R6):
-- only the client's binding API (SetBinding, SaveBindings, GetCurrentBindingSet, GetBindingKey) and FrameXML's helpers
-- in Blizzard_SharedXML/BindingUtil.lua (GetConvertedKeyOrButton, IsKeyPressIgnoredForBinding,
-- CreateKeyChordStringUsingMetaKeyState), which only read the modifier keys. SetBinding is refused to addons in combat
-- (warcraft.wiki.gg, API SetBinding: "nocombat"), so each caller starts a capture and binds only while unrestricted.

-- The keys an action shows and binds, as Blizzard's Key Bindings rows: its first two.
local SLOTS = 2

--- A capture waiting for a key press.
---@class PagleKeyCapture
---@field owner any         -- who waits, for the caller to compare (a row's frame and slot, a binding field)
---@field frame Frame       -- what takes the key press through its keyboard input while it waits
---@field onKey fun(key: string) -- a bindable press, with the modifiers held ("SHIFT-F"), after it stopped waiting
---@field onStop fun()      -- it stopped waiting, whatever stopped it: a press, Escape, another capture, its caller

---@type PagleKeyCapture?
local waiting

--- Who waits for a key press now (the owner its caller gave), or nil.
---@return any
function ns.KeyCaptureOwner()
	return waiting and waiting.owner
end

--- No capture waits any more: its frame gives up the keyboard, then its onStop runs.
function ns.StopKeyCapture()
	local now = waiting
	if not now then
		return
	end
	waiting = nil
	now.frame:EnableKeyboard(false)
	now.frame:SetScript("OnKeyDown", nil)
	now.onStop()
end

--- The waiting capture's key press or mouse button, as KeybindListener:ProcessInput takes it: a modifier alone keeps
--- it waiting, Escape stops it binding nothing, and any other stops it and hands its onKey the key with the modifiers
--- held. With nothing waiting, nothing happens.
---@param input string a key ("F", "LSHIFT", "ESCAPE") or a mouse button ("Button4")
function ns.PressKeyCapture(input)
	local now = waiting
	if not now then
		return
	end
	local key = GetConvertedKeyOrButton(input)
	if IsKeyPressIgnoredForBinding(key) then
		return
	end
	ns.StopKeyCapture()
	if key ~= "ESCAPE" then
		now.onKey(CreateKeyChordStringUsingMetaKeyState(key))
	end
end

--- `capture` waits for the next key press, which its frame takes before any binding does; any other capture stops
--- first.
---@param capture PagleKeyCapture
function ns.StartKeyCapture(capture)
	ns.StopKeyCapture()
	waiting = capture
	capture.frame:EnableKeyboard(true)
	capture.frame:SetScript("OnKeyDown", function(_, input)
		ns.PressKeyCapture(input)
	end)
end

--- Binds `key` to `action` in its slot `slot` (1 or 2), as KeybindListener:ProcessInput does: the action's first two
--- keys unbound, `key` taken from whatever action had it, the two bound again in order with `key` in its slot (the
--- other slot's key kept), then the binding set saved (KeybindListener:Commit).
---@param action string a Bindings.xml action
---@param slot integer
---@param key string
function ns.BindKey(action, slot, key)
	local keys = { GetBindingKey(action) }
	for i = 1, SLOTS do
		if keys[i] then
			SetBinding(keys[i])
		end
	end
	SetBinding(key)
	keys[slot] = key
	for i = 1, SLOTS do
		if keys[i] then
			SetBinding(keys[i], action)
		end
	end
	SaveBindings(GetCurrentBindingSet())
end
