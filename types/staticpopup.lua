---@meta _
-- Blizzard's StaticPopup, as far as QoL's conflict popup uses it (QOL-R81), which Ketho's vscode-wow-api annotations
-- (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never loaded by the game, and
-- excluded from luacheck. Source: Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua and
-- Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua.

--- A dialog definition. StaticPopup_OnClick runs OnAccept for button 1, OnAlt for button 3 and OnCancel for any
--- other; Esc (StaticPopup_EscapePressed, with hideOnEscape) runs OnEscape, else OnCancel.
---@class StaticPopupDialogInfo
---@field text string
---@field button1 string?
---@field button2 string?
---@field button3 string?
---@field OnAccept fun(dialog: table, data: any, data2: any)?
---@field OnCancel fun(dialog: table?, data: any, reason: string)?
---@field OnAlt fun(dialog: table, data: any, reason: string)?
---@field OnEscape fun(dialog: table, data: any, reason: string)?
---@field timeout number?
---@field whileDead boolean?
---@field hideOnEscape boolean?

--- The dialog definitions, by name.
---@type table<string, StaticPopupDialogInfo>
StaticPopupDialogs = {}

--- Shows the dialog `which`; returns the dialog frame, or nil if none was free.
---@param which string
---@param text_arg1 any?
---@param text_arg2 any?
---@param data any?
---@return table?
function StaticPopup_Show(which, text_arg1, text_arg2, data) end
