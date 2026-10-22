---@meta _
-- FrameXML's key-binding helpers, as far as Core's key capture and binding field use them (SET-R20, ONB-R43,
-- adapter/KeyCapture.lua, adapter/GuideBindingField.lua), which Ketho's vscode-wow-api annotations (WOW_API_COMMIT,
-- scripts/tools.env) lack. Declarations for the types stage only: never loaded by the game, and excluded from luacheck.
-- Source: Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
-- Interface/AddOns/Blizzard_SharedXML/BindingUtil.lua.

--- A mouse button's name as a binding key ("MiddleButton" is "BUTTON3"); any other input as it is.
---@param keyOrButton string
---@return string
function GetConvertedKeyOrButton(keyOrButton) end

--- Whether a press of `key` can't be bound by itself: a modifier alone, UNKNOWN, or the left or right mouse button.
---@param key string
---@return boolean
function IsKeyPressIgnoredForBinding(key) end

--- `key` with the modifiers held now, as a binding key ("ALT-CTRL-SHIFT-META-<key>", in that order).
---@param key string
---@return string
function CreateKeyChordStringUsingMetaKeyState(key) end

--- A binding action's name in Key Bindings: its BINDING_NAME_<action> global, or the action itself without one.
---@param binding string
---@return string
function GetBindingName(binding) end
