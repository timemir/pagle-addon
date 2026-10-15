---@meta _
-- FrameXML's minimap cluster, as far as Core's tracker dock uses it (CORE-R70: the dock sits under it), which Ketho's
-- vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never
-- loaded by the game, and excluded from luacheck. The pinned forever dump lists the frame (Frames.lua, BIR_COMMIT).

--- The minimap and the buttons around it (Blizzard_Minimap), the frame the tracker dock hangs under by default.
---@type Frame
MinimapCluster = {}
