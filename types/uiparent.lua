---@meta _
-- FrameXML's UIParent panel manager, as far as Core's card frame uses it (announcements.md › UI: a card closes with
-- Esc), which Ketho's vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types
-- stage only: never loaded by the game, and excluded from luacheck. Source: Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
-- Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua.

--- The names of the frames Esc hides: CloseSpecialWindows hides each one that is shown.
---@type string[]
UISpecialFrames = {}
