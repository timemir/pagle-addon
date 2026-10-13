---@meta _
-- Forever-only client globals that Ketho's vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack.
-- Declarations for the types stage only: never loaded by the game, and excluded from luacheck.

-- The Forever client's project ID, which WOW_PROJECT_ID equals there (CORE-R4).
-- Ketho/BlizzardInterfaceResources README.md on branch forever at BIR_COMMIT: "WOW_PROJECT_ID => WOW_PROJECT_CAMELOT (18)".
---@type integer
WOW_PROJECT_CAMELOT = 18

-- The text the client shows when a hooked fish escapes (LOG-R6). Ketho/BlizzardInterfaceResources branch forever at
-- BIR_COMMIT, Resources/GlobalStrings/enUS.lua: ERR_FISH_ESCAPED = "Your fish got away!".
---@type string
ERR_FISH_ESCAPED = "Your fish got away!"

-- The frame that shows the game's error text, which a Nudge sits below (QOL-R75). Not Forever-only, but the
-- annotations lack it; the forever dump lists it: Ketho/BlizzardInterfaceResources branch forever at BIR_COMMIT,
-- Resources/Frames.lua.
---@type MessageFrame
UIErrorsFrame = {}

-- The game world's frame, the one under the mouse when no UI is (QOL-R13). Not Forever-only, but the annotations lack
-- it; the forever dump lists it: Ketho/BlizzardInterfaceResources branch forever at BIR_COMMIT, Resources/Frames.lua.
---@type Frame
WorldFrame = {}
